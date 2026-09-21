extends Node

## Маршрут перемещения (этап Ф3, ADR-0013): читает ввод, смотрит настройки, двигает тело игрока.
##
## **Стики принадлежат меню, пока шар открыт.** Левый стик вращает шар, правый листает панель
## (input/controller_source.gd) — если бы перемещение слушало их всегда, прокрутка спорила бы с
## ходьбой. Поэтому перемещение работает только при закрытом шаре; телепорт руками — тоже.
##
## Сами механики — чистая математика в соседних файлах; здесь только ввод, физика и настройки.

signal moved(kind: String, detail: String)

const Teleport := preload("res://locomotion/teleport.gd")
const Turn := preload("res://locomotion/turn.gd")
const Continuous := preload("res://locomotion/continuous.gd")
const Climb := preload("res://locomotion/climb.gd")
const Mantle := preload("res://locomotion/mantle.gd")
const VignetteMath := preload("res://locomotion/vignette.gd")
const VignetteNode := preload("res://locomotion/vignette_node.gd")
const PlayerBody := preload("res://locomotion/player_body.gd")
const Menu := preload("res://menu/sphere_menu.gd")

## Досягаемость зацепа рукой, м.
const REACH_M := 0.45
## Насколько площадка должна быть выше ног, чтобы перевал имел смысл, м.
const MANTLE_RISE_MIN := 0.6
## Во сколько раз одна ось стика должна превосходить другую, чтобы вторая замолчала («обе руки»).
const AXIS_LOCK := 1.6

var body: PlayerBody
var origin: XROrigin3D
var head: Node3D
var menu: Menu
var left: XRController3D
var right: XRController3D
var teleport: Teleport = Teleport.new()
var turn: Turn = Turn.new()
var climb: Climb = Climb.new()
var vignette_math: VignetteMath = VignetteMath.new()
var vignette: VignetteNode
## Дуга телепорта на экране.
var arc_line: MeshInstance3D
var aiming := false
var last_turn_deg := 0.0
## Учёт непрерывного движения и лазанья: прибор обязан свидетельствовать о КАЖДОЙ механике.
## Сессия 17: телепорт, повороты и захват зацепа в журнале есть, а ходьба по взгляду и по руке —
## нет ни одной строки, хотя в этих режимах провели около двухсот секунд; доказать, что они
## работали, было нечем. Теперь путь копится и уходит в журнал одной строкой на каждый отрезок.
var _walk_from := Vector3.ZERO
var _walk_ms := 0
var _walking := false
var _climb_from := Vector3.ZERO
var _climb_ms := 0
## Перевал через край: {from, to, t} пока идёт, иначе пусто.
var _mantle: Dictionary = {}
## Фальсификатор «menustick»: перемещение слушает стики и при открытом шаре — спорит с меню.
var falsify_ignore_menu := false
## Фальсификатор «walkquiet»: непрерывное движение снова не пишет в журнал (слепота сессии 17).
var falsify_quiet_walk := false
## Фальсификатор «aimturn»: поворот работает и во время прицеливания — человек крутится, вместо
## того чтобы задать курс приземления.
var falsify_aim_turn := false
## Фальсификатор «axisfree»: оси стика не глушат друг друга — поворот снова тащит человека вперёд.
var falsify_no_axis_lock := false
## Фальсификатор «mantlefloor»: перевал срабатывает и у стоящего на полу — дефект сессии 23, когда
## захват нижнего зацепа мгновенно уносил наверх.
var falsify_mantle_eager_floor := false
## Фальсификатор «mantlesolid»: столкновения на время перевала не снимаются — капсула цепляется за
## угол кромки.
var falsify_mantle_solid := false
## Сколько человек держится у кромки и где была кисть ведущей руки — для распознавания намерения.
var _ledge_held := 0.0
var _hand_y_was := 0.0
## Фальсификатор «mantlephys»: физика тела во время перевала не выключается — человека роняет и
## тянет обратно к стене (дефект сессии 20).
var falsify_mantle_phys := false
## Фальсификатор «onehand»: настройки руки не действуют — всё как было прибито, движение левым,
## поворот правым.
var falsify_fixed_hands := false


func setup(p_body: PlayerBody, p_origin: XROrigin3D, p_head: Node3D, p_menu: Menu,
		p_left: XRController3D, p_right: XRController3D) -> void:
	body = p_body
	origin = p_origin
	head = p_head
	menu = p_menu
	left = p_left
	right = p_right
	vignette = VignetteNode.new()
	vignette.setup(head)
	arc_line = MeshInstance3D.new()
	arc_line.name = "TeleportArc"
	arc_line.visible = false
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.8, 1.0)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	arc_line.material_override = mat
	origin.add_child(arc_line)


func settings_value(id: String) -> Variant:
	return menu.settings.get_value(id)


## Ввод разрешён перемещению: шар закрыт (стики принадлежат меню, пока он открыт).
func input_free() -> bool:
	return falsify_ignore_menu or not menu.is_open()


func _physics_process(dt: float) -> void:
	if body == null or not is_instance_valid(left):
		return
	if not _mantle.is_empty():
		_mantle_tick(dt)
		return
	var res := teleport.tick(dt)
	if teleport.phase != "":
		if res["done"] or teleport.phase == "fade_in":
			body.teleport_to(res["pos"], teleport.yaw_deg)
		vignette.apply(res["fade"])
		return
	if not input_free():
		vignette.apply(vignette_math.update(0.0, 0.0, settings_value("move_vignette"), dt))
		arc_line.visible = false
		return
	# Пока целишься телепортом, стик вбок задаёт КУРС после переноса, а не крутит на месте
	# (сессия 20: «поворот стика поворачивает сразу, а не после телепортации»).
	if not aiming or falsify_aim_turn:
		_turn(dt)
	_move(dt)
	_climb(dt)
	_crouch()
	var speed := Vector2(body.velocity.x, body.velocity.z).length()
	vignette.apply(vignette_math.update(speed, last_turn_deg / maxf(dt, 0.001), settings_value("move_vignette"), dt))
	last_turn_deg = 0.0


## Откуда берётся стик руки. Отдельным полем, потому что без трекинга XRController3D отдаёт ноль, и
## настольно проверить выбор руки иначе нечем: подменяется в проверках.
var stick_source: Callable = func(who: String) -> Vector2:
	return (left if who == "left" else right).get_vector2("primary")


## Стик выбранной руки. Настройка «обе» складывает стики: при обеих «обе» поворот забирает ось X,
## движение — ось Y, иначе одна рука спорила бы сама с собой.
func hand_stick(setting_id: String, fallback: String) -> Vector2:
	var who: String = fallback if falsify_fixed_hands else str(settings_value(setting_id))
	if who == "left" or who == "right":
		return stick_source.call(who)
	var sum: Vector2 = stick_source.call("left") + stick_source.call("right")
	sum = Vector2(clampf(sum.x, -1.0, 1.0), clampf(sum.y, -1.0, 1.0))
	# ДОМИНИРУЮЩАЯ ОСЬ. При «обе» один и тот же стик кормит и поворот (X), и ход (Y), а палец редко
	# ведёт строго по оси: сессия 24 — каждый поворот сопровождался отрезком ходьбы по 5–15 см
	# («при повороте происходит и движение»). Явно преобладающая ось глушит вторую.
	if not falsify_no_axis_lock:
		if absf(sum.x) > absf(sum.y) * AXIS_LOCK:
			sum.y = 0.0
		elif absf(sum.y) > absf(sum.x) * AXIS_LOCK:
			sum.x = 0.0
	return sum


## Рука, из которой летит дуга телепорта: та, чей стик отклонён сильнее (при «обе» — любая).
func aiming_hand() -> XRController3D:
	var who: String = "left" if falsify_fixed_hands else str(settings_value("move_hand"))
	if who == "right":
		return right
	if who == "left":
		return left
	return right if absf(stick_source.call("right").y) > absf(stick_source.call("left").y) else left


func _turn(dt: float) -> void:
	var x: float = hand_stick("turn_hand", "right").x
	var deg := 0.0
	if settings_value("turn_mode") == "snap":
		deg = turn.snap(x, float(settings_value("snap_angle")), dt)
	else:
		deg = Turn.smooth(x, float(settings_value("turn_speed")), dt)
	if is_zero_approx(deg):
		return
	# Поворот вокруг ГОЛОВЫ, а не начала координат: иначе человека уносит по дуге.
	# Стик вправо — взгляд вправо, то есть тело поворачивается на -deg вокруг вертикали.
	var pivot := head.global_position
	var rot := Basis(Vector3.UP, deg_to_rad(-deg))
	var t := body.global_transform
	t.origin = pivot + rot * (t.origin - pivot)
	t.basis = rot * t.basis
	body.global_transform = t
	last_turn_deg = deg
	# Смещение головы за поворот — в журнал: поворот вокруг головы обязан оставлять её на месте, и
	# «при повороте происходит и движение» (сессия 23) должно подтверждаться числом, а не ощущением.
	var drift := Vector2(head.global_position.x - pivot.x, head.global_position.z - pivot.z).length()
	moved.emit("поворот", "%s %.0f°, голова ушла %.3f м" % [settings_value("turn_mode"), deg, drift])


func _move(dt: float) -> void:
	var stick: Vector2 = hand_stick("move_hand", "left")
	var hand: XRController3D = aiming_hand()
	var mode: String = settings_value("move_mode")
	if mode in ["head", "hand"]:
		var basis: Basis = head.global_basis if mode == "head" else hand.global_basis
		var v := Continuous.velocity(stick, basis, float(settings_value("move_speed")))
		body.velocity.x = v.x
		body.velocity.z = v.z
		_track_walk(mode, v.length() > 0.01)
		return
	_track_walk(mode, false)
	body.velocity.x = 0.0
	body.velocity.z = 0.0
	# Телепорт: пока стик вперёд — дуга, отпустили — перенос.
	if stick.y > 0.6:
		aiming = true
		_draw_arc(hand.global_position, -hand.global_basis.z)
	elif aiming:
		aiming = false
		arc_line.visible = false
		# Курс после переноса — из отклонения стика вбок при прицеливании (HL:A, перечень Meta).
		var yaw := NAN
		if bool(settings_value("teleport_turn")):
			yaw = Teleport.aim_yaw(stick.x, rad_to_deg(head.global_rotation.y))
		_do_teleport(hand.global_position, -hand.global_basis.z, mode, yaw)


## Дуга и её конец: луч физики ищет площадку.
func _aim(from: Vector3, dir: Vector3) -> Dictionary:
	var pts := Teleport.arc(from, dir, float(settings_value("teleport_range")))
	var space := get_viewport().world_3d.direct_space_state
	for i in range(1, pts.size()):
		var q := PhysicsRayQueryParameters3D.create(pts[i - 1], pts[i])
		q.exclude = [body.get_rid()]
		var hit := space.intersect_ray(q)
		if not hit.is_empty():
			return {"points": pts.slice(0, i + 1), "hit": true, "pos": hit["position"], "normal": hit["normal"]}
	return {"points": pts, "hit": false, "pos": pts[pts.size() - 1], "normal": Vector3.ZERO}


func _draw_arc(from: Vector3, dir: Vector3) -> void:
	var aim := _aim(from, dir)
	var ok: bool = aim["hit"] and Teleport.landing_ok(aim["normal"])
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for p in aim["points"]:
		im.surface_add_vertex(origin.to_local(p))
	im.surface_end()
	arc_line.mesh = im
	(arc_line.material_override as StandardMaterial3D).albedo_color = Color(0.3, 0.9, 0.5) if ok else Color(0.9, 0.3, 0.3)
	arc_line.visible = true


func _do_teleport(from: Vector3, dir: Vector3, mode: String, yaw := NAN) -> void:
	var aim := _aim(from, dir)
	if not aim["hit"] or not Teleport.landing_ok(aim["normal"]):
		moved.emit("телепорт", "площадка не годится")
		return
	teleport.start(head.global_position, aim["pos"], mode, yaw)
	moved.emit("телепорт", "%s на %.1f м%s" % [mode, head.global_position.distance_to(aim["pos"]),
			"" if is_nan(yaw) else ", курс %.0f°" % yaw])


## Присесть кнопкой A (правая рука): нажата — взгляд опускается, отпущена — возвращается.
## Было на нажатии стика — владелец приседа не нашёл вовсе (сессия 21): нажать стик случайно легко,
## а нарочно трудно, и нигде про это не было написано.
func _crouch() -> void:
	var depth := float(settings_value("crouch_m"))
	var down: bool = right.is_button_pressed("ax_button")
	var want := depth if down and depth > 0.0 else 0.0
	if not is_equal_approx(want, body.crouch):
		body.set_crouch(want)
		moved.emit("присед", "%.2f м" % want)


## Лазанье: грип у поверхности с меткой climb. Точка захвата фиксируется на самом ЗАЦЕПЕ, а не на
## руке: иначе хват «плывёт» и подъёма не получается (сессия 17 — двенадцать захватов и ноль
## сантиметров вверх). Ведёт последняя схватившая рука; ушла далеко от зацепа — срыв.
func _climb(dt: float) -> void:
	var positions := {}
	for pair in [["left", left], ["right", right]]:
		var hand: String = pair[0]
		var ctrl: XRController3D = pair[1]
		positions[hand] = ctrl.global_position
		var holding: bool = ctrl.is_button_pressed("grip_click")
		var hold_node := _climbable_near(ctrl.global_position)
		if holding and not climb.hands.has(hand) and hold_node != null:
			if not climb.active:
				_climb_from = body.global_position
				_climb_ms = Time.get_ticks_msec()
			# Точка захвата — там, где рука, а НЕ центр бруска: иначе первый же кадр рывком
			# подтягивает человека к зацепу на всю дистанцию до него, и этот рывок уходит в окно
			# скорости (сессия 19: «полёт 21 м/с» при каждом отпускании). Смысл фиксации не в
			# привязке к центру, а в том, что точка не плывёт за рукой по кадрам.
			climb.grab(hand, ctrl.global_position)
			moved.emit("лазанье", "взялся %s за %s%s" % [hand, hold_node.name,
					" (ведёт он)" if climb.hands.size() > 1 else ""])
		elif not holding and climb.hands.has(hand):
			_release_climb(hand, "отпустил")
	# Рука ушла от зацепа дальше предела — срыв, как у настоящей руки.
	for hand in climb.overreached(positions):
		_release_climb(hand, "сорвался")
	if climb.active:
		# Через коллизию: у кинематики лазанья это единственная защита от проноса капсулы сквозь
		# стену (замечание владельца о минусах кинематического подхода).
		body.climb_shift(climb.update(positions, dt))
		body.velocity = Vector3.ZERO
		_try_mantle(dt, positions)
	elif climb.velocity.length() > 0.1:
		body.velocity = climb.release_velocity(-head.global_basis.z)
		climb.velocity = Vector3.ZERO


## Долез до верха — перевалиться (Assisted Mantle, схема владельца). Сначала ищем РАЗМЕЧЕННУЮ
## кромку (тип `ledge` в данных уровня): у неё есть точка приземления, и гадать не приходится.
## Где разметки нет — прежний поиск площадки лучом.
##
## Намерение: держится за зацеп + глаза выше кромки + либо рывок рукой вниз, либо удержание.
## Сессия 21: прежний порог требовал поднять глаза на 15 см выше кромки, то есть подтянуться почти
## на полный рост, — и до верха стены владелец так и не перевалился.
func _try_mantle(dt: float, positions: Dictionary) -> void:
	# Стоящего на полу наверх не тянем. Сессия 23: человек взялся за нижний зацеп, стоя на земле, а
	# луч нашёл площадку перед ним — и перевал сработал в тот же миг. Перевал — про висящего.
	if body.is_on_floor() and not falsify_mantle_eager_floor:
		_ledge_held = 0.0
		return
	var head_pos := head.global_position
	var look := -head.global_basis.z
	var spot := Vector3.ZERO
	var target := Vector3.ZERO
	var found := false
	# 1. Размеченная кромка: рука держащей руки внутри зоны.
	for node in get_tree().get_nodes_in_group("ledge"):
		var area := node as Area3D
		if area == null:
			continue
		var shape := (area.get_child(0) as CollisionShape3D).shape as BoxShape3D
		var half := shape.size * 0.5
		var hand_in := false
		for hand in climb.hands:
			if not positions.has(hand):
				continue
			var local: Vector3 = area.to_local(positions[hand])
			if absf(local.x) <= half.x and absf(local.y) <= half.y and absf(local.z) <= half.z:
				hand_in = true
		if not hand_in:
			continue
		spot = area.global_position
		target = area.get_meta("target", area.global_position)
		found = true
		break
	# 2. Без разметки — луч вниз перед головой, как раньше.
	if not found:
		var ahead := look
		ahead.y = 0.0
		if ahead.length() < 0.01:
			_ledge_held = 0.0
			return
		var probe := head_pos + ahead.normalized() * Mantle.PROBE_AHEAD_M
		var space := get_viewport().world_3d.direct_space_state
		var q := PhysicsRayQueryParameters3D.create(probe + Vector3.UP * 0.05, probe - Vector3.UP * 1.2)
		q.exclude = [body.get_rid()]
		var hit := space.intersect_ray(q)
		if hit.is_empty() or not Mantle.fits(head_pos.y, (hit["position"] as Vector3).y, hit["normal"]):
			_ledge_held = 0.0
			return
		spot = hit["position"]
		target = Mantle.landing(spot, look)
	# Площадка должна быть выше НОГ: иначе «перевалом» окажется всё, на что человек смотрит сверху.
	if spot.y - body.global_position.y < MANTLE_RISE_MIN and not falsify_mantle_eager_floor:
		_ledge_held = 0.0
		return
	# Намерение: копим время у кромки и смотрим на рывок кисти вниз.
	_ledge_held += dt
	var hand_v_y := 0.0
	if climb.dominant != "" and positions.has(climb.dominant):
		var now: Vector3 = positions[climb.dominant]
		hand_v_y = (now.y - float(_hand_y_was)) / maxf(dt, 0.001)
		_hand_y_was = now.y
	if not Mantle.intent(head_pos.y, spot.y, hand_v_y, _ledge_held):
		return
	_ledge_held = 0.0
	# СШИВКА перед переносом. Пока человек лез, origin копил смещение от компенсации следования за
	# головой — к верху стены это метры. Обнулять его в конце нельзя: вид скачком уезжает вбок ровно
	# на накопленное («телепортировало куда-то далеко в сторону», сессия 22). Переносим смещение в
	# позицию тела: тело и origin компенсируют друг друга, и картинка не меняется вовсе.
	var carry := Vector3(origin.position.x, 0.0, origin.position.z)
	body.global_position += carry
	origin.position -= carry
	# Цель — так, чтобы над точкой приземления оказалась ГОЛОВА: под ней и встанет капсула.
	var head_off := head.global_position - body.global_position
	_mantle = {"from": body.global_position,
			"to": target - Vector3(head_off.x, 0.0, head_off.z), "t": 0.0}
	# Пока идёт перевал, телом распоряжаемся только мы: иначе тяготение и следование за головой
	# спорят с переносом, и человек оказывается на площадке полулёжа (сессия 20).
	body.mantling = not falsify_mantle_phys
	# И снимаем столкновения: капсула иначе цепляется за угол кромки (шаг из схемы владельца).
	if not falsify_mantle_solid:
		body.hold_collisions()
	for hand in climb.hands.keys():
		climb.release(hand)
	climb.velocity = Vector3.ZERO
	body.velocity = Vector3.ZERO
	moved.emit("перевал", "на площадку %.2f м (голова была на %.2f)" % [target.y, head_pos.y])


## Кадр перевала: тело идёт «вверх и вперёд». Пока идёт, остальное перемещение молчит.
func _mantle_tick(dt: float) -> void:
	_mantle["t"] = float(_mantle["t"]) + dt / Mantle.RISE_S
	var t := float(_mantle["t"])
	body.global_position = Mantle.rise_point(_mantle["from"], _mantle["to"], t)
	body.velocity = Vector3.ZERO
	if t < 1.0:
		return
	_mantle.clear()
	body.mantling = false
	body.release_collisions()
	# origin НЕ трогаем: сшивка сделана до переноса, и любое движение здесь было бы скачком вида.
	moved.emit("перевал", "встал на площадке, глаза на %.2f м (%.1f, %.1f)" % [
			head.global_position.y, head.global_position.x, head.global_position.z])


## Отпустить рукой и, если это был последний хват, записать пройденное.
func _release_climb(hand: String, why: String) -> void:
	climb.release(hand)
	if climb.active:
		moved.emit("лазанье", "%s %s, ведёт %s" % [why, hand, climb.dominant])
		return
	var way := body.global_position - _climb_from
	moved.emit("лазанье", "%s %s: %.2f м (вверх %.2f) за %.1f с, полёт %.2f м/с" % [
			why, hand, way.length(), way.y, (Time.get_ticks_msec() - _climb_ms) / 1000.0,
			climb.release_velocity(-head.global_basis.z).length()])


## Ближайший зацеп в досягаемости руки или null. Радиус поднят с 0.35 до 0.45 м: на шлеме рука
## попадала в брусок не всегда (сессия 17).
func _climbable_near(pos: Vector3) -> Node3D:
	var best: Node3D = null
	var best_d := REACH_M
	for node in get_tree().get_nodes_in_group("climb"):
		var d: float = (node as Node3D).global_position.distance_to(pos)
		if d < best_d:
			best_d = d
			best = node
	return best


## Отрезок непрерывного движения: строка в журнал на старте и на остановке. Событие на каждый кадр
## залило бы журнал (90 строк в секунду), а молчание — лишило бы свидетеля вовсе.
func _track_walk(mode: String, moving: bool) -> void:
	if falsify_quiet_walk:
		return
	if moving and not _walking:
		_walking = true
		_walk_from = body.global_position
		_walk_ms = Time.get_ticks_msec()
		moved.emit("ходьба", "пошёл: %s" % mode)
	elif _walking and not moving:
		_walking = false
		var way := body.global_position - _walk_from
		var secs := (Time.get_ticks_msec() - _walk_ms) / 1000.0
		way.y = 0.0
		moved.emit("ходьба", "встал: %s, %.2f м за %.1f с, средняя %.2f м/с" % [
				mode, way.length(), secs, way.length() / maxf(secs, 0.001)])
