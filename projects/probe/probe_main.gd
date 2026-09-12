extends Node

## Стенд прибора «паспорт железа».
##
## Правила, по которым он написан (PRACTICES.md):
##  §1.2 пол по числу ИСПОЛНЕННЫХ проверок — ошибка в середине не даёт зелёный вердикт;
##  §1.4 каждая проверка называет виновника поимённо;
##  §1.5 контрольный случай, зелёный при любом состоянии кода, — смотрим на него первым;
##  §2   встроенный фальсификатор: заведомо несуществующее расширение ОБЯЗАНО дать ABSENT.
##       Если он даёт PRESENT — прибор врёт; если UNKNOWN — прибор слеп.
##  §3.2 «спросить было негде» (UNKNOWN) и «нет» (ABSENT) — разные строки отчёта.

# Расширения Vulkan, от которых зависят архитектурные решения.
# Первое — контрольный случай, оно обязано быть на любом Vulkan-устройстве.
const VULKAN_CONTROL := "VK_KHR_swapchain"
const VULKAN_REQUIRED := [
	"VK_KHR_multiview",
	"VK_KHR_dynamic_rendering",
	"VK_KHR_dynamic_rendering_local_read",
	"VK_KHR_create_renderpass2",
]

## Фовеация реализуется РАЗНЫМИ расширениями на разных архитектурах:
## тайловые GPU (Adreno, Mali) дают fragment_density_map, десктопные —
## fragment_shading_rate. Отсутствие одного члена семейства — не отказ,
## поэтому проверяется наличие ХОТЯ БЫ ОДНОГО, и отчёт называет, какого
## именно (PRACTICES §1.4, §3.2).
const VULKAN_FOVEATION_FAMILY := [
	"VK_EXT_fragment_density_map",
	"VK_EXT_fragment_density_map2",
	"VK_KHR_fragment_shading_rate",
	"VK_NV_shading_rate_image",
]

# Заведомо несуществующее имя. Фальсификатор прибора (PRACTICES §2.4):
# гоняем его ДО того, как верить зелёному.
const VULKAN_FALSIFIER := "VK_VRGE_this_extension_does_not_exist"

# Список расширений OpenXR НЕ дублируется здесь: он берётся у самого модуля
# (VRGE_PROBED_XR_EXTENSIONS в vrge_probe_xr.cpp). Два независимых перечня
# разошлись бы — один обновят, второй забудут (PRACTICES §1.8).
var _openxr_checks: PackedStringArray = PackedStringArray()

# Имя обязано совпадать с фальсификатором в vrge_probe_xr.cpp.
const OPENXR_FALSIFIER := "XR_VRGE_this_extension_does_not_exist"

## Контрольный случай для OpenXR. Должен совпадать с первым элементом
## VRGE_PROBED_XR_EXTENSIONS в vrge_probe_xr.cpp.
const OPENXR_CONTROL := "XR_KHR_vulkan_enable2"

# Сколько проверок ОБЯЗАНО исполниться.
#
# Выводится из тех же массивов, по которым идут циклы, а не перечисляется рядом:
# два независимых перечня разойдутся — один обновят, второй забудут (PRACTICES §1.8).
#
# Слагаемые, по одному на каждый _check_*:
#   _check_control_case          1
#   _check_falsifiers            2  (vk + xr)
#   _check_vulkan                VULKAN_REQUIRED.size()
#   _check_openxr                OPENXR_CHECKS.size()
#   _check_openxr_liveness       1
#   _check_extension_list_nonempty 1
var _expected_checks: int = 0


func _compute_expected_checks() -> int:
	# Семейство фовеации даёт ОДНУ проверку, а не по одной на член.
	return 1 + 1 + 2 + VULKAN_REQUIRED.size() + 1 + _openxr_checks.size() + 1 + 1

var _passed := 0
var _failed := 0
var _unknown := 0
var _lines: Array[String] = []


func _ready() -> void:
	run_probe()
	get_tree().quit(0 if _failed == 0 else 1)


func _pass(text: String) -> void:
	_passed += 1
	_emit("  PASS  %s" % text)


func _fail(text: String) -> void:
	_failed += 1
	_emit("  FAIL  %s" % text)


## UNKNOWN считается исполненной проверкой, но НЕ отказом: пустой знаменатель —
## это «не спрашивали», а не «сломано» (PRACTICES §3.2).
func _unknown_result(text: String) -> void:
	_unknown += 1
	_emit("  ????  %s" % text)


func _emit(text: String) -> void:
	_lines.append(text)
	print(text)


func run_probe() -> void:
	_emit("=== ПАСПОРТ ЖЕЛЕЗА ===")

	if not Engine.has_singleton("VRGEProbe"):
		_emit("ОТКАЗ ПРИБОРА: синглтон VRGEProbe отсутствует — модуль не попал в сборку.")
		_failed += 1
		return
	var probe := Engine.get_singleton("VRGEProbe")

	# Забираем перечень опрашиваемых имён у модуля и вычитаем фальсификатор:
	# он проверяется отдельно и не должен попасть в обычные строки отчёта.
	var summary: Dictionary = probe.get_summary()
	for name in summary.get("probed_openxr_extensions", PackedStringArray()):
		if name != OPENXR_FALSIFIER and name != OPENXR_CONTROL:
			_openxr_checks.append(name)

	_emit("устройство:   %s" % probe.get_device_name())
	_emit("вендор:       %s" % probe.get_vendor_name())
	_emit("Vulkan API:   %s" % probe.get_vulkan_api_version())
	_emit("OpenXR:       %s" % ("активен" if probe.is_openxr_running() else "НЕ активен"))
	var exts: PackedStringArray = probe.list_vulkan_device_extensions()
	_emit("расширений устройства: %d" % exts.size())
	_emit("")

	# Пол считается ПОСЛЕ получения списка от модуля, иначе ожидание и факт
	# занизятся разом и пол перестанет ловить обрыв (PRACTICES §1.2).
	_expected_checks = _compute_expected_checks()
	_emit("ожидается исполненных проверок: %d" % _expected_checks)
	_emit("")

	_check_control_case(probe)
	_check_openxr_control_case(probe)
	_check_falsifiers(probe)
	_check_vulkan(probe)
	_check_foveation_family(probe)
	_check_openxr(probe)
	_check_openxr_liveness(probe)
	_check_extension_list_nonempty(exts)

	_verdict(probe, exts)


## Контрольный случай. Смотреть на него ПЕРВЫМ: упал вместе со всеми —
## значит сломана фикстура, а не железо (PRACTICES §1.5).
func _check_control_case(probe) -> void:
	var r: int = probe.has_vulkan_device_extension(VULKAN_CONTROL)
	if r == 1:
		_pass("контроль: %s присутствует — прибор видит расширения" % VULKAN_CONTROL)
	elif r == -1:
		_fail("контроль: %s — спросить негде. Прибор СЛЕП, остальным строкам верить нельзя" % VULKAN_CONTROL)
	else:
		_fail("контроль: %s отсутствует — так не бывает на Vulkan. Сломана фикстура" % VULKAN_CONTROL)


## Контрольный случай OpenXR. Смотреть на него ВТОРЫМ, сразу за vk-контролем.
##
## Его отсутствие в первой версии прибора стоило целой половины паспорта:
## незарегистрированная обёртка оставляла все флаги false, фальсификатор
## («несуществующее имя → ABSENT») выглядел зелёным, а восемь настоящих
## расширений сообщались как «рантайм не поддерживает» — и это была ложь.
## Фальсификатор, зелёный по неверной причине, опаснее сломанного кода
## (PRACTICES §2.3).
func _check_openxr_control_case(probe) -> void:
	var running: bool = probe.is_openxr_running()
	var r: int = probe.has_openxr_extension(OPENXR_CONTROL)
	if not running:
		_unknown_result("контроль xr: рантайм не поднят — проверка не исполнялась")
	elif r == 1:
		_pass("контроль xr: %s доступно — прибор видит расширения рантайма" % OPENXR_CONTROL)
	else:
		_fail("контроль xr: %s недоступно при поднятом рантайме — ПРИБОР СЛЕП. Все строки xr_ext ниже недостоверны" % OPENXR_CONTROL)


## Фальсификаторы. Зелёный прибор без них не значит ничего (PRACTICES §2).
func _check_falsifiers(probe) -> void:
	var v: int = probe.has_vulkan_device_extension(VULKAN_FALSIFIER)
	if v == 0:
		_pass("фальсификатор vk: несуществующее имя дало ABSENT — прибор различает")
	elif v == 1:
		_fail("фальсификатор vk: несуществующее имя дало PRESENT — ПРИБОР ВРЁТ")
	else:
		_fail("фальсификатор vk: дало UNKNOWN — прибор слеп, а не строг")

	var x: int = probe.has_openxr_extension(OPENXR_FALSIFIER)
	if x == 0:
		_pass("фальсификатор xr: несуществующее имя дало ABSENT — прибор различает")
	elif x == 1:
		_fail("фальсификатор xr: несуществующее имя дало PRESENT — ПРИБОР ВРЁТ")
	else:
		_unknown_result("фальсификатор xr: UNKNOWN — OpenXR не запущен, проверка не исполнялась")


func _check_vulkan(probe) -> void:
	for ext in VULKAN_REQUIRED:
		var r: int = probe.has_vulkan_device_extension(ext)
		if r == 1:
			_pass("vk_ext: %s" % ext)
		elif r == 0:
			# Не отказ прибора — отказ ГИПОТЕЗЫ. Называем поимённо (§1.4).
			_fail("vk_ext: %s — драйвер не экспортирует (Vulkan %s)" % [ext, probe.get_vulkan_api_version()])
		else:
			_unknown_result("vk_ext: %s — спросить негде (бэкенд не Vulkan?)" % ext)


## Проверяет семейство целиком: важно не «есть ли FDM», а «каким механизмом
## на этом железе вообще делается фовеация».
func _check_foveation_family(probe) -> void:
	var found: Array[String] = []
	var unknown_count := 0
	for ext in VULKAN_FOVEATION_FAMILY:
		var r: int = probe.has_vulkan_device_extension(ext)
		if r == 1:
			found.append(ext)
		elif r == -1:
			unknown_count += 1
	if found.size() > 0:
		_pass("фовеация: доступно — %s" % ", ".join(found))
	elif unknown_count == VULKAN_FOVEATION_FAMILY.size():
		_unknown_result("фовеация: спросить негде (бэкенд не Vulkan?)")
	else:
		_fail("фовеация: НИ ОДНОГО из %s — аппаратной фовеации нет" % ", ".join(VULKAN_FOVEATION_FAMILY))


func _check_openxr(probe) -> void:
	for ext in _openxr_checks:
		var r: int = probe.has_openxr_extension(ext)
		if r == 1:
			_pass("xr_ext: %s" % ext)
		elif r == 0:
			_fail("xr_ext: %s — рантайм не поддерживает" % ext)
		else:
			_unknown_result("xr_ext: %s — OpenXR не запущен" % ext)


func _check_openxr_liveness(probe) -> void:
	if probe.is_openxr_running():
		_pass("openxr: рантайм активен")
	else:
		_unknown_result("openxr: рантайм не активен — все строки xr_ext недостоверны")


func _check_extension_list_nonempty(exts: PackedStringArray) -> void:
	if exts.size() > 0:
		_pass("список расширений: получен (%d шт.)" % exts.size())
	else:
		_fail("список расширений: пуст — опрос устройства не состоялся")


func _verdict(probe, exts: PackedStringArray) -> void:
	var total := _passed + _failed + _unknown
	_emit("")
	_emit("passed=%d failed=%d unknown=%d" % [_passed, _failed, _unknown])

	# Пол по числу ИСПОЛНЕННЫХ проверок (PRACTICES §1.2). Самое дорогое правило:
	# ошибка времени исполнения обрывает функцию, а не прогон, и вердикт
	# остаётся зелёным при потерянных проверках.
	if total != _expected_checks:
		_emit("ОТКАЗ ПРИБОРА: исполнено %d проверок из %d — ошибка оборвала функцию" % [total, _expected_checks])
		_failed += 1
	else:
		_emit("пол: исполнено %d/%d проверок" % [total, _expected_checks])

	_write_report(probe, exts)


func _write_report(probe, exts: PackedStringArray) -> void:
	var path := "user://hardware-profile.raw.md"
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		_emit("отчёт: не удалось открыть %s" % path)
		return
	f.store_line("# Паспорт железа — сырой вывод прибора")
	f.store_line("")
	f.store_line("- дата: %s" % Time.get_datetime_string_from_system())
	f.store_line("- устройство: %s" % probe.get_device_name())
	f.store_line("- вендор: %s" % probe.get_vendor_name())
	f.store_line("- Vulkan API: %s" % probe.get_vulkan_api_version())
	f.store_line("- OpenXR активен: %s" % probe.is_openxr_running())
	f.store_line("")
	f.store_line("## Вердикт")
	f.store_line("```")
	for line in _lines:
		f.store_line(line)
	f.store_line("```")
	f.store_line("")
	f.store_line("## Все расширения устройства (%d)" % exts.size())
	f.store_line("```")
	for e in exts:
		f.store_line(e)
	f.store_line("```")
	f.close()
	_emit("отчёт: %s" % ProjectSettings.globalize_path(path))
