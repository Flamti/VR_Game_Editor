extends SceneTree

## Воспроизведение трассы со шлема на столе (`session/trace.gd`): настоящий уровень, настоящие
## `player_body` и `locomotion`, контроллеры — дети origin, как в приложении; позы, кнопки и стики —
## из записи, такт за тактом.
##
## Зачем. Дефект со шлема до сих пор переносился на стол угадыванием чисел: стенд перевала с рукой на
## 0.55 м выше глаз дал ложный зелёный, а на шлеме рука была на ~0.95 м выше (сессия 35). По трассе
## стенд идёт по записи настоящего человека, и фальсификатор можно гонять на ней.
##
## Что воспроизводится: тело и перемещение (ходьба, повороты, телепорт, лазанье, перевал, присед).
## Переносы, которые делает `main.gd` (посадка в старт, возврат, подъём зоны без пола), не
## повторяются: по смене номера переноса в записи (`seq`) тело пересаживается в записанное место, и
## число таких пересадок печатается.
## Что НЕТ: предметы в руках и призыв, меню и панель — они живут в `main.gd`; перемещение при
## открытом шаре тоже (шар здесь закрыт всегда). Сверка — положение тела с записанным на каждом такте:
## первое расхождение больше DIVERGE_M называется тактом и временем.
##
## Запуск:
##   godot … --headless --path projects/sphere_menu --script res://tests/replay.gd -- --trace=<файл>
##   godot … --headless --path projects/sphere_menu --script res://tests/replay.gd [-- --falsify=<имя>]
##
## Без --trace — самопроверка прибора:
##   «контроль: стоящий не сдвинулся» — трасса стояния на полу улицы; расхождение с записью — ноль;
##   «перевал по трассе виса у кромки» — синтетическая трасса: вис на climb8, рука вниз 0.9 м/с.
## Фальсификаторы:
##   --falsify=flickworld  рывок по мировой руке (дефект сессии 35) — краснеет только «перевал по
##                         трассе виса у кромки»;
##   --falsify=replaystart тело не ставится в записанную точку старта — краснеют все три случая: без
##                         места старта воспроизводить нечего; контроль называет это расхождением с
##                         первого такта;
##   --falsify=replayprocess воспроизведение идёт в `_process`, а не в кадре физики — краснеет только
##                         «ходьба по трассе идёт с записанной скоростью».
##
## Всё воспроизведение идёт в `_physics_process`: `move_and_slide` берёт шаг времени у движка, и вне
## кадра физики это шаг КАДРА (`character_body_3d.cpp:45`). Первая версия шла в `_process`: на
## настоящей трассе ходьба вышла «16 м за 0.0 с», расхождение 18.6 м на втором такте, а самопроверка
## этого не видела — в её случаях тело стояло или лезло (`move_and_collide` шага не берёт).

const Report := preload("res://probe_report.gd")
const LevelLoader := preload("res://world/level_loader.gd")
const Menu := preload("res://menu/sphere_menu.gd")
const LocomotionRes := preload("res://locomotion/locomotion.gd")
const PlayerBody := preload("res://locomotion/player_body.gd")
const Trace := preload("res://session/trace.gd")

const CHECKS := ["контроль: стоящий не сдвинулся", "перевал по трассе виса у кромки",
		"ходьба по трассе идёт с записанной скоростью"]
const STREET := "res://world/levels/start_location.json"
## Расхождение с записанным телом, начиная с которого воспроизведение «разошлось», м.
const DIVERGE_M := 0.05

var r: Report = Report.new()
var falsify := ""
var trace_path := ""
## Сколько первых тактов печатать подробно (--verbose=N): тело записанное и воспроизведённое.
var verbose := 0
var _frame := 0


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--falsify="):
			falsify = a.get_slice("=", 1)
		elif a.begins_with("--trace="):
			trace_path = a.get_slice("=", 1)
		elif a.begins_with("--verbose="):
			verbose = a.get_slice("=", 1).to_int()
	# Частота физики — как в записи: шаг `move_and_slide` берётся у движка (см. шапку).
	if trace_path != "":
		var parsed := Trace.parse(FileAccess.get_file_as_string(trace_path))
		if parsed["ok"]:
			Engine.physics_ticks_per_second = int((parsed["meta"] as Dictionary).get("tps", 60))


func _process(_delta: float) -> bool:
	if falsify == "replayprocess":
		return _step()
	return _done


func _physics_process(_delta: float) -> bool:
	if falsify == "replayprocess":
		return _done
	return _step()


var _done := false


func _step() -> bool:
	_frame += 1
	# Кадр на то, чтобы корень сцены был готов; дальше всё синхронно.
	if _frame < 2:
		return false
	if trace_path != "":
		_replay_file()
	else:
		_selftest()
	_done = true
	return true


## Воспроизвести трассу. `rows` — ряды `Trace.parse`, `meta` — её метаданные. `synthetic` — ряды без
## записанного тела: сверять не с чем. Возвращает {moved, max_div, diverged_at, body_end, ticks}.
func replay(meta: Dictionary, rows: Array, synthetic: bool) -> Dictionary:
	var root := Node3D.new()
	get_root().add_child(root)
	var levels: Array = meta.get("levels", [STREET])
	for path in levels:
		var res := LevelLoader.parse(FileAccess.get_file_as_string(str(path)))
		if res["ok"]:
			LevelLoader.build(root, res["data"])
	var m_head := Node3D.new()
	var menu := Menu.new()
	menu.head = m_head
	root.add_child(menu)
	for id in (meta.get("settings", {}) as Dictionary):
		menu.settings.values[id] = meta["settings"][id]
	var body := PlayerBody.new()
	var origin := XROrigin3D.new()
	var l := XRController3D.new()
	var rr := XRController3D.new()
	root.add_child(body)
	body.add_child(origin)
	origin.add_child(m_head)
	origin.add_child(l)
	origin.add_child(rr)
	body.setup(origin, m_head)
	body.set_eye_height(float(meta.get("eye_height", 1.6)))
	body.set_physics_process(false)
	var loco := LocomotionRes.new()
	root.add_child(loco)
	loco.set_physics_process(false)
	loco.setup(body, origin, m_head, menu, l, rr)
	loco.falsify_flick_world = falsify == "flickworld"
	var cur := {}
	loco.grip_source = func(who: String) -> bool: return float(cur.get(who[0] + "grip", 0.0)) > 0.5
	loco.stick_source = func(who: String) -> Vector2:
		return Vector2(float(cur.get(who[0] + "sx", 0.0)), float(cur.get(who[0] + "sy", 0.0)))
	var names := {"grip_click": "grip", "trigger_click": "trig", "ax_button": "ax", "by_button": "by"}
	loco.button_source = func(who: String, button: String) -> bool:
		return float(cur.get(who[0] + str(names.get(button, "?")), 0.0)) > 0.5
	var moved: Array[String] = []
	loco.moved.connect(func(kind: String, d: String): moved.append("%s: %s" % [kind, d]))
	var first: Dictionary = rows[0]
	if falsify != "replaystart":
		body.global_transform = Transform3D(Basis(Vector3.UP, deg_to_rad(float(first["byaw"]))),
				Vector3(float(first["bx"]), float(first["by"]), float(first["bz"])))
		origin.transform = _origin_xf(first)
		body.velocity = _velocity(first)
		# Трасса до версии 5 скорости не пишет — оценка по сдвигу тела между двумя первыми рядами.
		if not first.has("bvx") and rows.size() > 1:
			var second: Dictionary = rows[1]
			body.velocity = (Vector3(float(second["bx"]), float(second["by"]), float(second["bz"]))
					- Vector3(float(first["bx"]), float(first["by"]), float(first["bz"]))) * float(meta.get("tps", 60))
			print("скорость тела в трассе не записана (версия %s) — оценка по двум рядам: %s" % [
					meta.get("version", "?"), body.velocity.snappedf(0.01)])
	var dt := 1.0 / float(meta.get("tps", 60))
	var max_div := 0.0
	var diverged_at := -1
	var resyncs := 0
	# Номер переноса тела ДО прошлого такта: не изменился за такт — воспроизводимый код не переносил.
	var seq_seen := body.transfer_seq
	for k in rows.size():
		# Содержимое, а не переменная: лямбда источников захватила `cur` в миг создания, и
		# присваивание `cur = rows[k]` оставляло её смотреть на пустой словарь — кнопки не доходили.
		cur.clear()
		cur.merge(rows[k])
		# Перенос приложения между прошлым рядом и этим: номер в записи сменился, а воспроизводимый
		# код за прошлый такт сам ничего не переносил (его переносы двигают тот же номер у тела).
		if k > 0 and float(cur.get("seq", 0.0)) != float((rows[k - 1] as Dictionary).get("seq", 0.0)) \
				and body.transfer_seq == seq_seen:
			body.global_transform = Transform3D(Basis(Vector3.UP, deg_to_rad(float(cur["byaw"]))),
					Vector3(float(cur["bx"]), float(cur["by"]), float(cur["bz"])))
			origin.transform = _origin_xf(cur)
			body.velocity = _velocity(cur)
			resyncs += 1
		seq_seen = body.transfer_seq
		m_head.transform = Trace.xf(cur, "h")
		l.transform = Trace.xf(cur, "l")
		rr.transform = Trace.xf(cur, "r")
		# Такты — только те, что шли в приложении: до старта тело заморожено.
		if float(cur.get("bphys", 1.0)) > 0.5:
			body._physics_process(dt)
		if float(cur.get("lphys", 1.0)) > 0.5:
			loco._physics_process(dt)
		if synthetic or k + 1 >= rows.size():
			continue
		var nxt: Dictionary = rows[k + 1]
		if k < verbose:
			print("  такт %d: тело %s, в записи %s, скорость %s, режим %s" % [k, body.global_position.snappedf(0.01),
					Vector3(float(nxt["bx"]), float(nxt["by"]), float(nxt["bz"])).snappedf(0.01),
					body.velocity.snappedf(0.01), loco.mode()])
		# Следующий ряд уже после переноса приложения — сверять шаг не с чем: тело пересадится там.
		if float(nxt.get("seq", 0.0)) != float(cur.get("seq", 0.0)) and body.transfer_seq == seq_seen:
			continue
		var d := body.global_position.distance_to(Vector3(float(nxt["bx"]), float(nxt["by"]), float(nxt["bz"])))
		max_div = maxf(max_div, d)
		if d > DIVERGE_M and diverged_at < 0:
			diverged_at = k + 1
	var out := {"moved": moved, "max_div": max_div, "diverged_at": diverged_at, "resyncs": resyncs,
			"body_end": body.global_position, "eyes_end": m_head.global_position.y, "ticks": rows.size(), "dt": dt}
	root.queue_free()
	return out


func _replay_file() -> void:
	var parsed := Trace.parse(FileAccess.get_file_as_string(trace_path))
	if not parsed["ok"]:
		print("ОТКАЗ  трасса %s: %s" % [trace_path, parsed["error"]])
		quit(1)
		return
	var meta: Dictionary = parsed["meta"]
	var rows: Array = parsed["rows"]
	print("трасса: %s — %d рядов, %.1f с, причина «%s», уровни %s" % [trace_path.get_file(), rows.size(),
			float(rows.size()) / float(meta.get("tps", 60)), meta.get("why", ""), meta.get("levels", [])])
	var res := replay(meta, rows, false)
	for line in res["moved"]:
		print("  " + str(line))
	print("переносов приложения (пересадок по записи): %d" % res["resyncs"])
	if int(res["diverged_at"]) < 0:
		print("совпало с записью на всех %d тактах, худшее расхождение тела %.3f м" % [res["ticks"], res["max_div"]])
	else:
		var at: int = res["diverged_at"]
		print("РАЗОШЛОСЬ на такте %d (%.2f с от начала трассы): худшее расхождение тела %.3f м" % [
				at, float(at) * float(res["dt"]), res["max_div"]])
	quit(0)


func _selftest() -> void:
	r.note("=== ВОСПРОИЗВЕДЕНИЕ ТРАССЫ: САМОПРОВЕРКА ===")
	if falsify != "":
		r.note("!!! ФАЛЬСИФИКАТОР «%s»: ожидается точечный отказ !!!" % falsify)
	r.note("ожидается исполненных проверок: %d" % CHECKS.size())
	# Контроль: человек стоит у точки старта, руки опущены, кнопок нет. Тело записано на месте —
	# воспроизведение обязано остаться на месте и совпасть с записью (PRACTICES §1.5). Голова — на
	# EYE_FORWARD_OFFSET впереди тела (−Z): там тело держит её само, и сдвигаться ему незачем.
	var still: Array = []
	for k in 120:
		still.append(_row(float(k) / 60.0, Vector3(0.0, 1.6, -PlayerBody.EYE_FORWARD_OFFSET), Vector3(-0.2, 0.9, -0.1), Vector3(0.2, 0.9, -0.1),
				false, Vector3(0.0, 0.0, 8.0), 0.0))
	var a := replay({"levels": [STREET], "tps": 60}, still, false)
	var moved_by: float = (a["body_end"] as Vector3).distance_to(Vector3(0.0, 0.0, 8.0))
	if int(a["diverged_at"]) < 0 and moved_by < 0.01:
		r.pass_("контроль: стоящий не сдвинулся: 120 тактов, сдвиг %.3f м, худшее расхождение с записью %.3f м" % [moved_by, a["max_div"]])
	else:
		r.fail("контроль: стоящий не сдвинулся: сдвиг %.3f м, расхождение %.3f м с такта %d (%s)" % [
				moved_by, a["max_div"], a["diverged_at"], "; ".join(a["moved"])])
	# Вис на climb8 — как в стенде `_mantle_pull_case` дымового прогона, но через трассу: глаза 2.40,
	# рука на зацепе на 0.95 м выше глаз, тянет вниз 0.9 м/с на 0.7 м.
	var hold := _level_pos("climb8")
	var basis := Basis(Vector3.UP, deg_to_rad(90.0))
	var hand := Vector3(0.0, 2.55, -0.35)
	var body_at := hold - basis * hand
	var pull: Array = []
	var down := 0.0
	for k in 120:
		pull.append(_row(float(k) / 60.0, Vector3(0.0, 1.6, 0.0), Vector3(-0.3, 1.0, -0.2), hand - Vector3(0.0, down, 0.0),
				true, body_at, 90.0))
		down = minf(down + 0.9 / 60.0, 0.7)
	var b := replay({"levels": [STREET], "tps": 60}, pull, true)
	var said := "; ".join(b["moved"])
	var roof := _level_pos("hclimb_roof").y + 0.1
	if said.contains("перевал: на площадку") and absf((b["body_end"] as Vector3).y - roof) < 0.05:
		r.pass_("перевал по трассе виса у кромки: ноги %.2f на крыше %.2f — %s" % [(b["body_end"] as Vector3).y, roof, said])
	else:
		r.fail("перевал по трассе виса у кромки: ноги %.2f, крыша %.2f — %s" % [(b["body_end"] as Vector3).y, roof, said])
	# Ходьба: стик вперёд одну секунду при скорости 1.4 м/с. Тело обязано пройти около 1.4 м, а не
	# в разы больше: так видно, какой шаг времени берёт `move_and_slide`.
	var walk: Array = []
	for k in 60:
		var row := _row(float(k) / 60.0, Vector3(0.0, 1.6, -PlayerBody.EYE_FORWARD_OFFSET), Vector3(-0.2, 0.9, -0.1),
				Vector3(0.2, 0.9, -0.1), false, Vector3(0.0, 0.0, 8.0), 0.0)
		row["lsy"] = 1.0
		walk.append(row)
	var c := replay({"levels": [STREET], "tps": 60,
			"settings": {"move_mode": "head", "move_speed": 1.4, "move_hand": "left", "turn_hand": "right"}}, walk, true)
	var went: float = Vector2((c["body_end"] as Vector3).x, (c["body_end"] as Vector3).z - 8.0).length()
	if went > 1.0 and went < 1.6:
		r.pass_("ходьба по трассе идёт с записанной скоростью: 1 с стика вперёд при 1.4 м/с — %.2f м" % went)
	else:
		r.fail("ходьба по трассе идёт с записанной скоростью: 1 с стика вперёд при 1.4 м/с — %.2f м (%s)" % [went, "; ".join(c["moved"])])
	var total := r.executed()
	r.note("passed=%d failed=%d unknown=%d" % [r.passed, r.failed, r.unknown])
	if total != CHECKS.size():
		r.note("ОТКАЗ ПРИБОРА: исполнено %d проверок из %d" % [total, CHECKS.size()])
	else:
		r.note("пол: исполнено %d/%d проверок" % [total, CHECKS.size()])


## Ряд трассы из значений. Правый грип `grip` — для виса; тело — где записано.
func _row(t: float, head: Vector3, left: Vector3, right: Vector3, grip: bool, body: Vector3, yaw: float) -> Dictionary:
	var row := {"t": t, "hx": head.x, "hy": head.y, "hz": head.z, "hqx": 0.0, "hqy": 0.0, "hqz": 0.0, "hqw": 1.0,
			"lx": left.x, "ly": left.y, "lz": left.z, "lqx": 0.0, "lqy": 0.0, "lqz": 0.0, "lqw": 1.0,
			"rx": right.x, "ry": right.y, "rz": right.z, "rqx": 0.0, "rqy": 0.0, "rqz": 0.0, "rqw": 1.0,
			"rgrip": 1.0 if grip else 0.0,
			"bx": body.x, "by": body.y, "bz": body.z, "byaw": yaw, "ox": 0.0, "oy": 0.0, "oz": 0.0}
	return row


## Скорость тела из ряда: тело в такте движется со скоростью, заданной прошлым тактом перемещения.
func _velocity(row: Dictionary) -> Vector3:
	return Vector3(float(row.get("bvx", 0.0)), float(row.get("bvy", 0.0)), float(row.get("bvz", 0.0)))


## Origin из ряда: положение и курс (посадка в старт его поворачивает).
func _origin_xf(row: Dictionary) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, deg_to_rad(float(row.get("oyaw", 0.0)))),
			Vector3(float(row["ox"]), float(row["oy"]), float(row["oz"])))


func _level_pos(uuid: String) -> Vector3:
	var res := LevelLoader.parse(FileAccess.get_file_as_string(STREET))
	for o in (res["data"] as Dictionary).get("objects", []):
		if str((o as Dictionary).get("uuid", "")) == uuid:
			var p: Array = o["pos"]
			return Vector3(float(p[0]), float(p[1]), float(p[2]))
	return Vector3.ZERO
