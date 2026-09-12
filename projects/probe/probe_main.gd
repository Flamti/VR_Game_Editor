extends Node

## Оркестратор прибора «паспорт железа».
##
## Порядок фаз, пол по числу исполненных проверок, вердикт, запись отчёта.
## Сами измерения живут в отдельных файлах по принципу «один прибор — один
## вопрос»: probe_caps.gd, probe_drawcalls.gd, probe_sustained.gd.
##
## Пол (PRACTICES §1.2) — самое дорогое правило здесь. Ошибка времени
## исполнения обрывает ФУНКЦИЮ, а не прогон: оставшиеся проверки просто не
## исполнятся, счётчик отказов останется нулевым, и вердикт будет зелёным при
## сломанном коде. Поэтому сверяется не вердикт, а поимённое ЧИСЛО.

## Сколько минут держать нагрузку в фазе E. Решение владельца: 15–20.
## Переопределяется аргументом командной строки --vrge-minutes=N.
const SUSTAINED_MINUTES := 18.0

## Фазу E можно отключить: она требует надетого шлема на 18 минут.
## Аргумент --vrge-skip-sustained.
var _skip_sustained := false
var _minutes := SUSTAINED_MINUTES

# preload, а не опора на class_name: глобальный кэш классов может быть ещё не
# построен на первом импорте, и тогда парсинг падает «Identifier not declared».
# Явная загрузка снимает зависимость от порядка импорта.
const ProbeReport := preload("res://probe_report.gd")
const ProbeCaps := preload("res://probe_caps.gd")
const ProbeDrawCalls := preload("res://probe_drawcalls.gd")
const ProbeSustained := preload("res://probe_sustained.gd")

var _report: ProbeReport = ProbeReport.new()
var _caps: ProbeCaps = ProbeCaps.new()
var _draws: ProbeDrawCalls = ProbeDrawCalls.new()
var _sustained: ProbeSustained = ProbeSustained.new()
var _expected := 0
var _probe = null


func _ready() -> void:
	_parse_args()
	await _run_all()
	get_tree().quit(0 if _report.failed == 0 else 1)


## Управление прогоном.
##
## Аргументы командной строки на Android НЕ работают: попытка передать
## --vrge-skip-sustained через `adb shell am start --esa command_line_params`
## до приложения не дошла, и фаза E запустилась на 18 минут вопреки флагу.
## Поэтому основной механизм — файл-маркер в user://, который кладётся заранее:
##
##   adb shell run-as org.flamti.vrge.probe touch files/skip_sustained
##
## Файл детерминирован и проверяем: его наличие видно и с хоста, и из игры.
## Аргументы оставлены как второй путь для десктопа.
const SKIP_MARKER := "user://skip_sustained"
const MINUTES_MARKER := "user://sustained_minutes"


func _parse_args() -> void:
	if FileAccess.file_exists(SKIP_MARKER):
		_skip_sustained = true
	if FileAccess.file_exists(MINUTES_MARKER):
		var f := FileAccess.open(MINUTES_MARKER, FileAccess.READ)
		if f != null:
			_minutes = maxf(0.1, f.get_as_text().strip_edges().to_float())
	for a in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		if a == "--vrge-skip-sustained":
			_skip_sustained = true
		elif a.begins_with("--vrge-minutes="):
			_minutes = maxf(0.1, a.get_slice("=", 1).to_float())


func _run_all() -> void:
	_report.note("=== ПАСПОРТ ЖЕЛЕЗА ===")

	if not Engine.has_singleton("VRGEProbe"):
		_report.note("ОТКАЗ ПРИБОРА: синглтон VRGEProbe отсутствует — модуль не попал в сборку.")
		_report.failed += 1
		return
	_probe = Engine.get_singleton("VRGEProbe")

	# XR-вьюпорт. Без него рендера в шлем нет вообще, и все замеры времени
	# кадра меряли бы пустоту. Прошлый прогон именно этим и был испорчен.
	var xr_ok := _enable_xr()

	# Пол считается ДО проверок и выводится из тех же массивов, по которым идут
	# циклы, а не перечисляется рядом (PRACTICES §1.8).
	_expected = _caps.expected_checks(_probe) + _draws.expected_checks()
	if xr_ok and not _skip_sustained:
		_expected += _sustained.expected_checks()
	_expected += 1   # сама проверка XR-вьюпорта
	_report.note("ожидается исполненных проверок: %d" % _expected)
	_report.note("")

	if xr_ok:
		_report.pass_("XR-вьюпорт: включён, рендер идёт в шлем")
	else:
		_report.fail("XR-вьюпорт: НЕ включён — замеры времени кадра меряли бы пустоту")

	_caps.run(_probe, _report)

	if xr_ok:
		_draws.setup(self)
		await _draws.run(_report)
	else:
		for _i in _draws.expected_checks():
			_report.unkn("свипы: XR-вьюпорта нет, измерять нечего")

	if xr_ok and not _skip_sustained:
		_sustained.setup(self, self)
		await _sustained.run(_report, _draws.unbatched, _minutes)
	elif _skip_sustained:
		_report.note("")
		_report.note("фаза E пропущена (маркер %s или флаг)" % SKIP_MARKER)

	_verdict()


func _enable_xr() -> bool:
	var iface := XRServer.find_interface("OpenXR")
	if iface == null or not iface.is_initialized():
		return false
	get_viewport().use_xr = true
	return true


func _verdict() -> void:
	var total: int = _report.executed()
	_report.note("")
	_report.note("passed=%d failed=%d unknown=%d" % [_report.passed, _report.failed, _report.unknown])

	if total != _expected:
		_report.note("ОТКАЗ ПРИБОРА: исполнено %d проверок из %d — ошибка оборвала функцию" % [total, _expected])
		_report.failed += 1
	else:
		_report.note("пол: исполнено %d/%d проверок" % [total, _expected])

	_write_report()


func _write_report() -> void:
	var path := "user://hardware-profile.raw.md"
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		_report.note("отчёт: не удалось открыть %s" % path)
		return
	f.store_line("# Паспорт железа — сырой вывод прибора")
	f.store_line("")
	f.store_line("- дата: %s" % Time.get_datetime_string_from_system())
	f.store_line("- устройство: %s" % _probe.get_device_name())
	f.store_line("- вендор: %s" % _probe.get_vendor_name())
	f.store_line("- Vulkan API: %s" % _probe.get_vulkan_api_version())
	f.store_line("- OpenXR активен: %s" % _probe.is_openxr_running())
	f.store_line("")
	f.store_line("## Измеренные числа")
	f.store_line("```")
	f.store_line("мкс на draw call (небатченый):  %s" % _fmt(_draws.us_per_drawcall))
	f.store_line("мкс на инстанс:                 %s" % _fmt(_draws.us_per_instance))
	f.store_line("цена разогрева PSO, мс:         %s" % _fmt(_draws.warmup_cost_ms))
	f.store_line("разброс прогонов, мс:           %s" % _fmt(_draws.variance_ms))
	f.store_line("троттлинг, секунда сброса:      %s" % (
			"%.0f (%.1f Гц)" % [_sustained.first_drop_s, _sustained.first_drop_to]
			if _sustained.first_drop_s >= 0.0 else "не наблюдался"))
	f.store_line("прогон фазы E, с:               %.0f из %.0f%s" % [
			_sustained.ran_seconds, _sustained.planned_seconds,
			" (ПРЕРВАН)" if _sustained.interrupted else ""])
	f.store_line("```")
	f.store_line("")
	f.store_line("## Вердикт")
	f.store_line("```")
	for line in _report.lines:
		f.store_line(line)
	f.store_line("```")
	f.store_line("")
	var exts: PackedStringArray = _caps.all_extensions
	f.store_line("## Все расширения устройства (%d)" % exts.size())
	f.store_line("```")
	for e in exts:
		f.store_line(e)
	f.store_line("```")
	f.close()
	_report.note("отчёт: %s" % ProjectSettings.globalize_path(path))


func _fmt(v: float) -> String:
	return "не измерено" if is_nan(v) else "%.3f" % v
