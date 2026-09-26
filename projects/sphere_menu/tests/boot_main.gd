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
##   --falsify=loadopen   экран загрузки не закрывается — краснеет только «экран загрузки закрывает
##                        мир до старта»;
##   --falsify=spawnhead  голова не ставится над точкой старта — краснеет только «старт: голова над
##                        точкой, тело на полу».
##
## Контрольный случай — нарочная ошибка скрипта в самом приборе: она обязана попасть в журнал при
## любом состоянии `main.gd`. Не попала — слеп прибор, а не исправен код (PRACTICES §1.5).

const Report := preload("res://probe_report.gd")

## Сколько кадров живёт сцена: запуск, мастер или профиль, первые такты перемещения. Время модели,
## а не часов (PRACTICES §1.9): безголовый цикл идёт без ограничения частоты.
const FRAMES := 300
const CHECKS := ["прибор видит ошибки скрипта", "основная сцена поднялась со своим скриптом",
		"основная сцена без ошибок скрипта", "экран загрузки закрывает мир до старта",
		"старт: голова над точкой, тело на полу"]
## Где человек стоит в своей комнате относительно origin в момент старта: в стороне и с поворотом.
## На столе XRCamera3D никто не двигает, и без этого голова была бы над точкой и без правки (§2.5).
const ROOM_HEAD := Vector3(0.7, 1.6, -0.4)
const ROOM_YAW_DEG := 40.0


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
var _early: Dictionary = {}
const LoadingViewRes := preload("res://session/loading_view.gd")


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
	LoadingViewRes.falsify_open = falsify == "loadopen"
	if script != null:
		(script as GDScript).set("falsify_spawn_head", falsify == "spawnhead")
	_main = packed.instantiate()
	root.add_child(_main)
	# Старт ждёт такта физики — голова ставится в комнате до него.
	var cam: Node3D = _main.get("camera")
	if cam != null:
		cam.position = ROOM_HEAD
		cam.rotation = Vector3(0.0, deg_to_rad(ROOM_YAW_DEG), 0.0)
	# До старта мир закрыт: снимок в том же кадре, что и сцена поднялась.
	var lv: Variant = _main.get("loading")
	_early = {"shown": lv != null and (lv as Object).call("is_shown"), "spawned": bool(_main.get("_spawned"))}


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
	_spawn_checks()
	if _main != null:
		_main.queue_free()
	var total := r.executed()
	r.note("passed=%d failed=%d unknown=%d" % [r.passed, r.failed, r.unknown])
	if total != CHECKS.size():
		r.note("ОТКАЗ ПРИБОРА: исполнено %d проверок из %d" % [total, CHECKS.size()])
	else:
		r.note("пол: исполнено %d/%d проверок" % [total, CHECKS.size()])


func _spawn_checks() -> void:
	if _early.is_empty() or _main == null or _main.get_script() == null:
		r.fail("экран загрузки закрывает мир до старта: сцена не поднялась")
		r.fail("старт: голова над точкой, тело на полу: сцена не поднялась")
		return
	var lv: Object = _main.get("loading")
	if bool(_early["shown"]) and not bool(_early["spawned"]) and lv != null and not lv.call("is_shown"):
		r.pass_("экран загрузки закрывает мир до старта: закрыт при подъёме сцены, открыт после старта")
	else:
		r.fail("экран загрузки закрывает мир до старта: при подъёме закрыт %s (старт уже был %s), после старта закрыт %s" % [
				_early["shown"], _early["spawned"], lv.call("is_shown") if lv != null else "?"])
	var bad: Array[String] = []
	var spawn: Transform3D = _main.get("spawn_xf")
	var player: Node3D = _main.get("player")
	var cam: Node3D = _main.get("camera")
	if not bool(_main.get("_spawned")):
		bad.append("старт не состоялся")
	var off := Vector2(cam.global_position.x - spawn.origin.x, cam.global_position.z - spawn.origin.z).length()
	# Тело встаёт на EYE_FORWARD_OFFSET позади глаз, голова остаётся на точке.
	if off > 0.05:
		bad.append("голова в %.2f м от точки старта" % off)
	var fwd := -cam.global_basis.z
	var want := -spawn.basis.z
	var yaw_err := rad_to_deg(Vector2(fwd.x, fwd.z).angle_to(Vector2(want.x, want.z)))
	if absf(yaw_err) > 2.0:
		bad.append("курс взгляда разошёлся с точкой на %.0f°" % yaw_err)
	var feet := player.global_position.y
	var over := cam.global_position.y - feet
	# Без XR зона «без пола», и запасной путь поднимает origin на рост: глаза над ногами — поза
	# головы в origin плюс этот подъём. Подъём спрашиваем у сцены, а не считаем здесь (§1.6).
	var lift := float(_main.get("_origin_lift"))
	if absf(feet - spawn.origin.y) > 0.02 or absf(over - ROOM_HEAD.y - lift) > 0.02:
		bad.append("ноги %.3f (точка %.3f), глаза над ногами %.3f вместо %.2f (+ подъём %.2f)" % [
				feet, spawn.origin.y, over, ROOM_HEAD.y + lift, lift])
	if bad.is_empty():
		r.pass_("старт: голова над точкой, тело на полу: человек стоял в комнате в %.1f м от origin с поворотом %.0f° — голова в %.3f м от точки, курс %.1f°, ноги %.2f, глаза над ногами %.2f (подъём зоны без пола %.2f)" % [
				Vector2(ROOM_HEAD.x, ROOM_HEAD.z).length(), ROOM_YAW_DEG, off, yaw_err, feet, over, lift])
	else:
		r.fail("старт: голова над точкой, тело на полу: %s" % "; ".join(bad))
