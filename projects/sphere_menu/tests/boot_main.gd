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
##                        точкой, тело на полу»;
##   --falsify=transferdumb переносы не помечают себя (`PlayerBody.mark_transfer`) — краснеет только
##                        «сторож рывка молчит на старте»: подъём зоны без пола снова назван рывком;
##   --falsify=roomamnesia выгрузка не пишет память комнаты — краснеет только «комната помнит
##                        оставленное»: занесённого куба нет, переставленный вернулся на полку.
##
## Контрольный случай — нарочная ошибка скрипта в самом приборе: она обязана попасть в журнал при
## любом состоянии `main.gd`. Не попала — слеп прибор, а не исправен код (PRACTICES §1.5).

const Report := preload("res://probe_report.gd")

## Сколько кадров живёт сцена: запуск, мастер или профиль, первые такты перемещения. Время модели,
## а не часов (PRACTICES §1.9): безголовый цикл идёт без ограничения частоты.
const FRAMES := 300
const CHECKS := ["прибор видит ошибки скрипта", "основная сцена поднялась со своим скриптом",
		"основная сцена без ошибок скрипта", "экран загрузки закрывает мир до старта",
		"старт: голова над точкой, тело на полу", "сторож рывка молчит на старте",
		"комната помнит оставленное"]
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
	if ROOM_STEPS.has(_frame):
		call(ROOM_STEPS[_frame])
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
	(load("res://locomotion/player_body.gd") as GDScript).set("falsify_unmarked", falsify == "transferdumb")
	(load("res://world/room_items.gd") as GDScript).set("falsify_amnesia", falsify == "roomamnesia")
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
		r.fail("сторож рывка молчит на старте: сцена не поднялась")
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
	_watch_check()


## Сторож рывка молчит на старте: подъём зоны без пола и посадка в точку старта — наши переносы, и
## лимит строк сторожа на них не тратится. До сессии 25 прибор запуска печатал здесь «ПОЗА[рывок 1]
## глаза 1.60 → 3.20: origin +1.60» — подъём, сделанный нашим же кодом. Здесь же видно, что пометки,
## которые ставит `main.gd`, доходят до сторожа: дымовой прогон `main.gd` не поднимает.
func _watch_check() -> void:
	var w: Variant = _main.get("_pose_watch")
	if w == null:
		r.fail("сторож рывка молчит на старте: у сцены нет сторожа")
		return
	var jumps := int((w as Object).get("jumps"))
	var ours: Dictionary = (w as Object).get("ours")
	# Случай обязан задеть гейт (§2.5): наш скачок был и сторож его увидел — иначе молчание пусто.
	if jumps != 0:
		r.fail("сторож рывка молчит на старте: необъяснённых рывков %d, наших скачков %s" % [jumps, ours])
	elif ours.is_empty():
		r.fail("сторож рывка молчит на старте: сторож не видел ни одного нашего скачка — проверять нечего")
	else:
		r.pass_("сторож рывка молчит на старте: необъяснённых рывков 0, наши скачки учтены отдельно — %s" % (w as Object).call("ours_text"))


## Комната помнит оставленное — через НАСТОЯЩИЕ обработчики `main.gd` (решение владельца 2026-09-23).
##
## Настольная `shelfback` проверяет `RoomItems` на значениях, дымовой `_carry` — свою копию
## сантехники выгрузки. Ни одна не гоняет `_load_level` с памятью, `_settle` и `_unload_frame` из
## `main.gd` — а связь «память → постройка» живёт именно там (§1.10). Здесь вход и выход — сигналы
## той самой зоны, которые шлёт физика; перекрытие тел — поведение движка, от сигнала дальше — наш код.
##
## Случай: уличный куб занесён в дом и положен; свой куб дома переставлен внутри. Выгрузка, вход
## снова. Свидетель — узлы: занесённый стоит там, где его оставили, переставленный — на новом
## месте, ни один uuid не построен дважды, остальные кубы дома целы. Шаги разнесены по кадрам:
## `queue_free` освобождает узел в конце кадра (ловушка 26 о том же).
const ROOM_STEPS := {150: "_room_enter", 152: "_room_leave", 154: "_room_unload",
		156: "_room_back", 158: "_room_check"}
const ROOM_FILE := "res://world/levels/start_interior.json"
## Уличный куб и куб дома из данных уровня, и куда их кладут — внутри ящика зоны `home_enter`.
const STREET_CUBE := "grab0"
const ROOM_CUBE := "in_box00"
const STREET_CUBE_AT := Vector3(-7.5, 0.3, -6.8)
const ROOM_CUBE_AT := Vector3(-6.0, 0.3, -4.8)
var _room: Dictionary = {}


func _live(uuid: String) -> Array[Node3D]:
	var out: Array[Node3D] = []
	var lvl: Node = _main.get("level") if _main != null else null
	if lvl == null:
		return out
	var stack: Array[Node] = [lvl]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		if n is Node3D and str(n.get_meta("uuid", "")) == uuid and not n.is_queued_for_deletion():
			out.append(n as Node3D)
	return out


func _room_zone() -> Area3D:
	if _main == null or _main.get_script() == null:
		return null
	return (_main.get("_zones") as Dictionary).get(ROOM_FILE, null) as Area3D


func _room_enter() -> void:
	var zone := _room_zone()
	if zone == null:
		_room = {"error": "у сцены нет зоны %s" % ROOM_FILE.get_file()}
		return
	zone.body_entered.emit(_main.get("player"))
	var street := _live(STREET_CUBE)
	var own := _live(ROOM_CUBE)
	# Стенд обязан доказать, что видит искомое (ловушка 45): комната построилась, кубы есть.
	if street.size() != 1 or own.size() != 1:
		_room = {"error": "после входа уличных «%s» %d, кубов дома «%s» %d" % [STREET_CUBE, street.size(), ROOM_CUBE, own.size()]}
		return
	var cubes := 0
	for e in (_main.get("_vis_nodes") as Dictionary).get(ROOM_FILE, []):
		if ((e as Dictionary).get("node", null) as Node) != null and ((e as Dictionary)["node"] as Node).is_in_group("grab"):
			cubes += 1
	# Положили: так же, как отпущенный рукой предмет, — место, потом `_settle`.
	for pair in [[street[0], STREET_CUBE_AT], [own[0], ROOM_CUBE_AT]]:
		var rb := pair[0] as RigidBody3D
		rb.freeze = true
		rb.global_position = pair[1]
		_main.call("_settle", rb)
	var rooms: Object = _main.get("rooms")
	_room = {"cubes": cubes, "owner": str(rooms.call("owner_of", STREET_CUBE))}


func _room_leave() -> void:
	if _room.has("error"):
		return
	# Где лежат в миг выгрузки — локально, как их запомнит комната и построит загрузчик.
	_room["street_pos"] = _live(STREET_CUBE)[0].position
	_room["own_pos"] = _live(ROOM_CUBE)[0].position
	_room_zone().body_exited.emit(_main.get("player"))
	# Отсчёт выгрузки идёт временем кадра; ждать его настоящими секундами прибору незачем — тот же
	# `_unload_frame` с шагом больше задержки.
	_main.call("_unload_frame", 3.0)


func _room_unload() -> void:
	if _room.has("error"):
		return
	_room["gone"] = _live(STREET_CUBE).size() == 0 and _live(ROOM_CUBE).size() == 0
	_room["loaded_after_exit"] = (_main.get("stream") as Object).call("is_loaded", ROOM_FILE)


func _room_back() -> void:
	if _room.has("error"):
		return
	_room_zone().body_entered.emit(_main.get("player"))
	# Место — в том же кадре, что и постройка: дальше тело живёт физикой.
	var street := _live(STREET_CUBE)
	var own := _live(ROOM_CUBE)
	_room["street_back"] = street[0].position if street.size() == 1 else null
	_room["own_back"] = own[0].position if own.size() == 1 else null


func _room_check() -> void:
	if _room.is_empty():
		r.fail("комната помнит оставленное: шаги не исполнялись")
		return
	if _room.has("error"):
		r.fail("комната помнит оставленное: %s" % _room["error"])
		return
	var bad: Array[String] = []
	if str(_room["owner"]) != ROOM_FILE:
		bad.append("положенный в доме уличный куб достался «%s», а не дому" % str(_room["owner"]).get_file())
	if not bool(_room["gone"]) or bool(_room["loaded_after_exit"]):
		bad.append("дом не выгрузился (кубы ушли %s, файл загружен %s)" % [_room["gone"], _room["loaded_after_exit"]])
	for c in [["занесённый «%s»" % STREET_CUBE, "street_back", "street_pos", STREET_CUBE],
			["переставленный «%s»" % ROOM_CUBE, "own_back", "own_pos", ROOM_CUBE]]:
		var back: Variant = _room[c[1]]
		var want: Vector3 = _room[c[2]]
		var live := _live(c[3]).size()
		if back == null:
			bad.append("%s после возврата: экземпляров %d" % [c[0], live])
		elif (back as Vector3).distance_to(want) > 0.01:
			bad.append("%s стоит в %s, оставлен в %s" % [c[0], (back as Vector3).snappedf(0.01), want.snappedf(0.01)])
		elif live != 1:
			bad.append("%s построен %d раз" % [c[0], live])
	var cubes := 0
	for e in (_main.get("_vis_nodes") as Dictionary).get(ROOM_FILE, []):
		var n: Node = (e as Dictionary).get("node", null)
		if n != null and is_instance_valid(n) and not n.is_queued_for_deletion() and n.is_in_group("grab"):
			cubes += 1
	# Своих кубов дома было N, занесён один: стало N + 1.
	if cubes != int(_room["cubes"]) + 1:
		bad.append("кубов в доме %d, было %d и занесён один" % [cubes, _room["cubes"]])
	if bad.is_empty():
		r.pass_("комната помнит оставленное: занесённый «%s» и переставленный «%s» вернулись на свои места (%s, %s), по одному экземпляру; кубов в доме %d" % [
				STREET_CUBE, ROOM_CUBE, (_room["street_pos"] as Vector3).snappedf(0.01),
				(_room["own_pos"] as Vector3).snappedf(0.01), cubes])
	else:
		r.fail("комната помнит оставленное: %s" % "; ".join(bad))
