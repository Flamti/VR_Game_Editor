extends SceneTree

## Запуск основной сцены без ошибок скрипта — то, чего не видит ни один другой прибор.
##
## Настольные проверки и дымовой прогон собирают систему сами, из частей, и `main.tscn` целиком не
## поднимают никогда. 2026-09-26 на шлем уехал `main.gd`, который не разбирался вовсе (вывод типа из
## метода, которого у `CharacterBody3D` нет), — сцена встала без скрипта, XR-вывод не включился, и
## человек увидел чёрное. Оба прибора при этом были зелёными. Следом за ней пряталась вторая ошибка:
## применение настроек звало подсказку из `_ready` раньше, чем создана её надпись.
##
## Ошибки ловятся штатным `Logger` (Godot 4.5+, `OS.add_logger`), а не грепом вывода: греп прошлой
## проверки взял три строки ошибок OpenXR-загрузчика и не дошёл до ошибки разбора.
##
## Запуск:
##   godot/bin/godot.linuxbsd.editor.x86_64 --headless --path projects/sphere_menu \
##       --script res://tests/boot_main.gd [-- --falsify=helpearly]
##
## Фальсификаторы:
##   --falsify=helpearly  подсказка снова зовётся раньше своей надписи (`main.gd:_show_help`) —
##                        краснеет только «основная сцена без ошибок скрипта», с именем файла и
##                        строки.
##   --falsify=bootblind  журнал прибора не принимает ошибок скрипта — краснеет только контрольный
##                        случай «прибор видит ошибки скрипта»: без него зелёный итог ничего не значит.
##
## Контрольный случай — нарочная ошибка скрипта в самом приборе: она обязана попасть в журнал при
## любом состоянии `main.gd`. Не попала — слеп прибор, а не исправен код (PRACTICES §1.5).

const Report := preload("res://probe_report.gd")

## Сколько кадров живёт сцена: запуск, мастер или профиль, первые такты перемещения. Время модели,
## а не часов (PRACTICES §1.9): безголовый цикл идёт без ограничения частоты.
const FRAMES := 300
const CHECKS := ["прибор видит ошибки скрипта", "основная сцена поднялась со своим скриптом",
		"основная сцена без ошибок скрипта"]


class Catch extends Logger:
	var lock := Mutex.new()
	var script_errors: Array[String] = []
	var other_errors := 0
	var blind := false

	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		lock.lock()
		if error_type == ERROR_TYPE_SCRIPT and not blind:
			# Текст ошибки скрипта Godot кладёт в `code`, `rationale` у неё пуст (проверено исполнением).
			script_errors.append("%s:%d %s — %s" % [file, line, function, rationale if rationale != "" else code])
		elif error_type == ERROR_TYPE_ERROR:
			# Ошибки движка (OpenXR без шлема и т.п.) не наши — считаются, но не валят проверку.
			other_errors += 1
		lock.unlock()

	func _log_message(_message: String, _error: bool) -> void:
		pass

	func taken() -> Array[String]:
		lock.lock()
		var out := script_errors.duplicate()
		lock.unlock()
		return out


var r: Report = Report.new()
var falsify := ""
var catch := Catch.new()
var _frame := 0
var _main: Node = null
var _before := 0
var _done := false


func _init() -> void:
	# Как можно раньше: ошибка разбора случается при загрузке сцены, и журнал должен уже слушать.
	OS.add_logger(catch)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--falsify="):
			falsify = a.get_slice("=", 1)
	catch.blind = falsify == "bootblind"
	r.note("=== ЗАПУСК ОСНОВНОЙ СЦЕНЫ ===")
	if falsify != "":
		r.note("!!! ФАЛЬСИФИКАТОР «%s»: ожидается точечный отказ !!!" % falsify)
	r.note("ожидается исполненных проверок: %d" % CHECKS.size())
	_control()


## Нарочная ошибка скрипта: обращение к свойству пустого узла. Обрывает только лямбду.
func _control() -> void:
	var was := catch.taken().size()
	var poke := func() -> void:
		var n: Node = null
		n.name = "контроль"
	poke.call()
	var got := catch.taken()
	if got.size() == was + 1:
		r.pass_("прибор видит ошибки скрипта: нарочная ошибка попала в журнал — «%s»" % got.back())
	else:
		r.fail("прибор видит ошибки скрипта: нарочная ошибка не попала в журнал — зелёный итог ниже ничего не значит")
	_before = got.size()


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame == 1:
		_boot()
	if _frame >= FRAMES and not _done:
		_finish()
		return true
	return _done


func _boot() -> void:
	# `load`, а не `preload`: не разобравшийся main.gd иначе уронил бы разбор самого прибора, и итога
	# не было бы вовсе.
	var script: Variant = load("res://main.gd")
	if falsify == "helpearly" and script != null:
		(script as GDScript).set("falsify_help_early", true)
	var packed := load("res://main.tscn") as PackedScene
	if packed == null:
		return
	_main = packed.instantiate()
	root.add_child(_main)


func _finish() -> void:
	_done = true
	# Поднялась ли сцена СО СКРИПТОМ и дошёл ли её `_ready` до конца: надпись подсказки создаётся в
	# его середине, профиль — в конце. Узел без скрипта (разбор не прошёл) — ровно чёрный экран шлема.
	var has_script: bool = _main != null and _main.get_script() != null
	var label_ok: bool = has_script and _main.get("task_label") != null
	if has_script and label_ok:
		r.pass_("основная сцена поднялась со своим скриптом: %s, надпись подсказки создана" % (_main.get_script() as Script).resource_path)
	elif _main == null:
		r.fail("основная сцена поднялась со своим скриптом: main.tscn не загрузилась")
	else:
		r.fail("основная сцена поднялась со своим скриптом: %s" % (
				"узел без скрипта — main.gd не разобрался" if not has_script else "`_ready` оборвался до надписи подсказки"))
	var errs := catch.taken().slice(_before)
	if errs.is_empty():
		r.pass_("основная сцена без ошибок скрипта: %d кадров, ошибок скрипта 0, ошибок движка после старта %d" % [
				FRAMES, catch.other_errors])
	else:
		r.fail("основная сцена без ошибок скрипта: %d за %d кадров — %s" % [errs.size(), FRAMES, "; ".join(errs.slice(0, 5))])
	if _main != null:
		_main.queue_free()
	var total := r.executed()
	r.note("passed=%d failed=%d unknown=%d" % [r.passed, r.failed, r.unknown])
	if total != CHECKS.size():
		r.note("ОТКАЗ ПРИБОРА: исполнено %d проверок из %d" % [total, CHECKS.size()])
	else:
		r.note("пол: исполнено %d/%d проверок" % [total, CHECKS.size()])
