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
## Прицел последнего кадра: {points, hit, pos, normal, ok}. Перенос идёт ПО НЕМУ — по дуге, которую
## человек видел, — а не по прицелу, посчитанному заново на кадре отпускания: тот стоит ещё 12 лучей
## и берётся из позы руки, которая в момент отпускания уже дёрнулась.
var _last_aim: Dictionary = {}
## Откуда брошен `_last_aim`: [рука, направление, поза origin]. Пока они не разошлись, дуга не
## пересчитывается — ни лучи, ни меш (ловушка 48: работа — когда что-то сдвинулось).
var _aim_key: Array = []
## Отклонение стика вбок на ПОСЛЕДНЕМ кадре прицеливания — из него курс после переноса. На кадре
## отпускания палец уже возвращается к центру, и `x` там около нуля: курс, который человек задавал,
## терялся (открытый дефект сессии 22).
var _aim_x := 0.0
## Сколько раз дуга считалась по-настоящему (лучи и меш) — свидетель для прибора.
var arc_rebuilds := 0
## Насколько должны разойтись рука или origin, чтобы дугу пересчитать: м и радианы (~0.3°). Форма,
## а не измерение: меньше, чем видно глазом на конце семиметровой дуги.
const ARC_MOVE_EPS := 0.005
const ARC_TURN_EPS := 0.005
## Плавный поворот идёт отрезком, как ходьба: сумма градусов и наибольший уход головы.
var _turning := false
var _turn_sum := 0.0
var _turn_drift := 0.0
## Отрезок ходьбы заявляется в журнал, только пройдя столько, м. Форма: дёрганье стика давало
## отрезки по 5–15 см — в журнале сессии 21:15 из 846 отрезков 529 короче 30 см.
const WALK_CLAIM_M := 0.3
var _walk_claimed := false
## Сколько коротких отрезков набралось до ближайшего заявленного: они не пропадают, а уходят числом
## в его строку «встал» — иначе свидетель слеп к дёрганью вовсе.
var _walk_short := 0
## Фальсификатор «yawlate»: курс снова читается на кадре отпускания — около нуля.
var falsify_yaw_late := false
## Фальсификатор «aimside»: «поворот главнее» действует и при прицеливании — отклонение вбок
## обнуляет ход, и прицел обрывается переносом.
var falsify_aim_side := false
## Фальсификатор «aimtwice»: на отпускании прицел считается заново из позы руки.
var falsify_aim_twice := false
## Фальсификатор «arcrebuild»: дуга — лучи и новый меш — каждый кадр, как до правки.
var falsify_arc_every := false
## Фальсификатор «turnspam»: плавный поворот пишет строку на каждый такт.
var falsify_turn_spam := false
## Фальсификатор «walkjitter»: отрезок ходьбы заявляется с первого такта, любым дёрганьем.
var falsify_walk_jitter := false
## Фальсификатор «mantlesticks»: отмена перевала ничего не отменяет.
## Фальсификатор «mantlespot» (tests/smoke_menu.gd): высота приземления — из найденной точки (верх
## зацепа или кромки), а не с поверхности под точкой приземления, как до 2026-09-26.
var falsify_mantle_spot := false
var falsify_mantle_sticks := false
## Фальсификатор «menustick»: перемещение слушает стики и при открытом шаре — спорит с меню.
var falsify_ignore_menu := false
## Фальсификатор «walkquiet»: непрерывное движение снова не пишет в журнал (слепота сессии 17).
var falsify_quiet_walk := false
## Фальсификатор «holdstuck»: удержание ввода копится флагом и не снимается — перемещение
## выключается насовсем после первого же показа клавиатуры (дефект сессии 30).
static var falsify_hold_stuck := false
static var _stuck := false
## Фальсификатор «lockdrift»: перехват ввода не гасит начатое движение — возвращается дефект
## сессии 29, когда человек ехал всё время, пока вводил PIN.
var falsify_no_suspend := false
## Уже сообщили в журнал о прерывании этого отрезка.
var _suspended := false
## Фальсификатор «aimturn»: поворот работает и во время прицеливания — человек крутится, вместо
## того чтобы задать курс приземления.
var falsify_aim_turn := false
## Фальсификатор «climbevery»: зацеп ищется каждый такт на каждую руку, даже с отпущенным грипом —
## как было до сессии 25 (обход группы из 14 брусков дважды за такт).
var falsify_climb_every := false
## Принудительное прицеливание для замера цены дуги: рисуется каждый такт из позы руки.
var probe_aim := false
## Фальсификатор «axisfree»: приоритет поворота снят — поворот снова тащит человека вперёд, как до
## сессии 31 («при вращении стиком так же работает движение этим же стиком»).
var falsify_no_turn_first := false
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
	# Тело спрашивает состояние лазанья само, каждый такт: флага, который кто-то обязан снять,
	# здесь быть не должно (сессия 30).
	body.climbing = func() -> bool: return climb.active
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


## Кто ещё держит ввод, кроме шара: ожидание PIN, замок панели, открытый ввод текста. Возвращает
## ПРИЧИНУ (пустая строка — ввод свободен): по ней видно в журнале, кто держит, и не приходится
## гадать. Задаёт сессия (main.gd) — перемещение не должно знать про профили и клавиатуры.
##
## Спрашивать надо состояние, а не копить флаг по сигналам «показана/скрыта»: сессия 30 —
## системная клавиатура прислала «show», а «hide» не прислала (PIN набрали панелью), флаг залип, и
## перемещение выключилось совсем на весь прогон.
var input_hold: Callable = func() -> String: return ""


## Ввод разрешён перемещению: шар закрыт (стики принадлежат меню, пока он открыт) И никто другой
## ввод не держит. PIN спрашивают в открытом шаре, но замок панели и системная клавиатура могут
## держать ввод и при закрытом — а событие «отпустили стик» в это время не приходит вовсе.
func input_free() -> bool:
	if falsify_ignore_menu:
		return true
	return not menu.is_open() and str(input_hold.call()) == ""


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
		# Ввод забрали (шар открыт, спрашивают PIN, показана системная клавиатура) — начатое
		# движение обязано ОСТАНОВИТЬСЯ здесь же. Раньше выход стоял до обнуления скорости, и
		# заданная в прошлом такте скорость жила дальше: человек уезжал всё время, пока вводил PIN
		# (сессия 29). Остановку нельзя ждать от «отпустили стик»: пока ввод перехвачен, события
		# отпускания не приходят вовсе (ловушка 29 — при системной клавиатуре контроллеры до
		# приложения не доходят).
		suspend(_hold_reason())
		vignette.apply(vignette_math.update(0.0, 0.0, settings_value("move_vignette"), dt))
		return
	# Ввод снова наш: следующее прерывание опять попадёт в журнал.
	_suspended = false
	# Принудительное прицеливание — только для замера цены дуги самопроверкой.
	# Мерит ВЕРХНЮЮ границу (ловушка 49): дуга пересчитывается каждый такт, даже если рука стоит.
	if probe_aim:
		_draw_arc(right.global_position, -right.global_basis.z, true)
	# Пока целишься телепортом, стик вбок задаёт КУРС после переноса, а не крутит на месте
	# (сессия 20: «поворот стика поворачивает сразу, а не после телепортации»).
	# Стики читаются один раз на такт: поворот главнее движения, и решение об отклонении должно быть
	# у обеих механик одно (locomotion.turn_first).
	var sticks := frame_sticks()
	if not aiming or falsify_aim_turn:
		_turn(dt, sticks)
	else:
		_end_smooth_turn()
	_move(dt, sticks)
	_climb(dt)
	_crouch()
	var speed := Vector2(body.velocity.x, body.velocity.z).length()
	vignette.apply(vignette_math.update(speed, last_turn_deg / maxf(dt, 0.001), settings_value("move_vignette"), dt))
	last_turn_deg = 0.0


## Откуда берётся стик руки. Отдельным полем, потому что без трекинга XRController3D отдаёт ноль, и
## настольно проверить выбор руки иначе нечем: подменяется в проверках.
var stick_source: Callable = func(who: String) -> Vector2:
	return (left if who == "left" else right).get_vector2("primary")

## Откуда берётся грип. Отдельным полем по той же причине, что и стик: без трекинга XRController3D
## отдаёт false, и проверить лазанье через настоящий такт иначе нечем.
var grip_source: Callable = func(who: String) -> bool:
	return (left if who == "left" else right).is_button_pressed("grip_click")


## Стик выбранной руки. Настройка «обе» складывает стики: любой из них ведёт.
func hand_stick(setting_id: String, fallback: String) -> Vector2:
	var who: String = fallback if falsify_fixed_hands else str(settings_value(setting_id))
	if who == "left" or who == "right":
		return stick_source.call(who)
	var sum: Vector2 = stick_source.call("left") + stick_source.call("right")
	return Vector2(clampf(sum.x, -1.0, 1.0), clampf(sum.y, -1.0, 1.0))


## Читают ли поворот и движение ОДИН И ТОТ ЖЕ физический стик. «Обе» включает оба, поэтому
## пересекается с чем угодно.
func same_stick() -> bool:
	var m: String = "left" if falsify_fixed_hands else str(settings_value("move_hand"))
	var t: String = "right" if falsify_fixed_hands else str(settings_value("turn_hand"))
	return m == t or m == "both" or t == "both"


## ПОВОРОТ ГЛАВНЕЕ ДВИЖЕНИЯ (решение владельца 2026-09-22). Пока стик уведён вбок выше порога
## поворота, движение и прицел телепорта от ЭТОГО ЖЕ стика не работают.
##
## До этого глушилась «явно преобладающая ось» по отношению 1.6, и правило молчало ровно там, где
## палец бывает чаще всего: при (0.8, 0.5) и (0.7, 0.7) срабатывали обе механики сразу — сектор
## около 30° из 90°. Пороги у механик разные (поворот 0.6, движение 0.15), поэтому отношение осей
## их и не разводило. Одно сравнение с одним порогом объяснимо человеку и проверяемо числом.
##
## Когда стики разные, правило не применяется вовсе: стрейф на ходу сохраняется.
static func turn_first(turn: Vector2, move: Vector2, one_stick: bool) -> Dictionary:
	if one_stick and absf(turn.x) >= Turn.DEADZONE:
		return {"turn": turn, "move": Vector2.ZERO}
	return {"turn": turn, "move": move}


## Отклонения стиков на этот такт. Считаются ОДИН раз и раздаются обеим механикам: два независимых
## чтения могли дать разные решения об одном и том же отклонении.
func frame_sticks() -> Dictionary:
	var turn := hand_stick("turn_hand", "right")
	var move := hand_stick("move_hand", "left")
	# Пока целишься, отклонение вбок — это КУРС после переноса, а не поворот (поворот при прицеле и
	# так не работает). Примени здесь «поворот главнее» — и при одном стике на обе механики курс
	# сильнее 0.6 обнулял бы ход, а обнулённый ход читается как отпускание: человека переносило
	# посреди прицеливания.
	# Решение владельца 2026-09-26, сверено с Meta: «users can tilt the forward pushed thumbstick to
	# the side to rotate their target orientation» (Locomotion user preferences), а в раскладке
	# Interaction SDK телепорт и поворот живут на одном стике. Отвергнуто: «поворот главнее» и при
	# прицеле — курс сильнее 0.6 недостижим, попытка его задать переносит.
	if falsify_no_turn_first or (aiming and not falsify_aim_side):
		return {"turn": turn, "move": move}
	return turn_first(turn, move, same_stick())


## Рука, из которой летит дуга телепорта: та, чей стик отклонён сильнее (при «обе» — любая).
func aiming_hand() -> XRController3D:
	var who: String = "left" if falsify_fixed_hands else str(settings_value("move_hand"))
	if who == "right":
		return right
	if who == "left":
		return left
	return right if absf(stick_source.call("right").y) > absf(stick_source.call("left").y) else left


func _turn(dt: float, sticks: Dictionary = {}) -> void:
	var x: float = (sticks["turn"] as Vector2).x if sticks.has("turn") else hand_stick("turn_hand", "right").x
	var deg := 0.0
	if settings_value("turn_mode") == "snap":
		deg = turn.snap(x, float(settings_value("snap_angle")), dt)
	else:
		deg = Turn.smooth(x, float(settings_value("turn_speed")), dt)
	if is_zero_approx(deg):
		_end_smooth_turn()
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
	# Щелчок — событие, строка на щелчок. Плавный поворот ненулевой КАЖДЫЙ такт выше мёртвой зоны,
	# и строка на такт — это 90 строк в секунду, ровно то, что запрещено ходьбе (`_track_walk`).
	# Поэтому он пишется отрезком: начало и конец с суммой градусов.
	if settings_value("turn_mode") == "snap" or falsify_turn_spam:
		moved.emit("поворот", "%s %.0f°, голова ушла %.3f м" % [settings_value("turn_mode"), deg, drift])
		return
	if not _turning:
		_turning = true
		_turn_sum = 0.0
		_turn_drift = 0.0
		moved.emit("поворот", "плавный: начат")
	_turn_sum += deg
	_turn_drift = maxf(_turn_drift, drift)


## Конец отрезка плавного поворота: одна строка с суммой. Молчит, если отрезка не было.
func _end_smooth_turn() -> void:
	if not _turning:
		return
	_turning = false
	moved.emit("поворот", "плавный %.0f°, голова ушла до %.3f м" % [_turn_sum, _turn_drift])


func _move(dt: float, sticks: Dictionary = {}) -> void:
	var stick: Vector2 = (sticks["move"] as Vector2) if sticks.has("move") else hand_stick("move_hand", "left")
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
		_aim_x = stick.x
		_draw_arc(hand.global_position, -hand.global_basis.z)
	elif aiming:
		aiming = false
		arc_line.visible = false
		# Курс после переноса — из отклонения стика вбок при прицеливании (HL:A, перечень Meta), и
		# именно ПРИ ПРИЦЕЛИВАНИИ: здесь, на отпускании, палец уже у центра.
		var yaw := NAN
		if bool(settings_value("teleport_turn")):
			yaw = Teleport.aim_yaw(stick.x if falsify_yaw_late else _aim_x, rad_to_deg(head.global_rotation.y))
		var aim: Dictionary = _last_aim
		if falsify_aim_twice or aim.is_empty():
			aim = _aim(hand.global_position, -hand.global_basis.z)
		_last_aim = {}
		_aim_key = []
		_do_teleport(aim, mode, yaw)


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


## Совпадает ли поза прицела с той, из которой считана `_last_aim`. Мир при этом считается
## неподвижным: площадка, уехавшая из-под неподвижной руки, увидится, как только рука дрогнет.
func _aim_same(key: Array) -> bool:
	if _aim_key.size() != 3 or _last_aim.is_empty():
		return false
	var o: Transform3D = key[2]
	var was: Transform3D = _aim_key[2]
	return (key[0] as Vector3).distance_to(_aim_key[0]) < ARC_MOVE_EPS \
			and (key[1] as Vector3).angle_to(_aim_key[1]) < ARC_TURN_EPS \
			and o.origin.distance_to(was.origin) < ARC_MOVE_EPS \
			and o.basis.z.angle_to(was.basis.z) < ARC_TURN_EPS


## `force` — пересчитать, даже если рука стоит: так мерится верхняя граница цены дуги.
func _draw_arc(from: Vector3, dir: Vector3, force := false) -> void:
	var key := [from, dir, origin.global_transform]
	if not force and not falsify_arc_every and _aim_same(key):
		arc_line.visible = true
		return
	_aim_key = key
	var aim := _aim(from, dir)
	var ok: bool = aim["hit"] and Teleport.landing_ok(aim["normal"])
	aim["ok"] = ok
	_last_aim = aim
	arc_rebuilds += 1
	# Линия рисуется гуще, чем идут лучи: точки — чистая арифметика, а запросы к физике дороги.
	# Если дуга упёрлась, показываем ровно её пройденную часть, иначе линия уходила бы сквозь стену.
	var line_pts: PackedVector3Array = aim["points"] if aim["hit"] else Teleport.arc_line(from, dir, float(settings_value("teleport_range")))
	# Меш один на всю жизнь дуги: у ImmediateMesh для этого есть clear_surfaces() (ловушка 48, тот же
	# приём, что у нити призыва в world/pull_view.gd). Раньше — новый меш и новый RID каждый кадр.
	var im := arc_line.mesh as ImmediateMesh
	if im == null or falsify_arc_every:
		im = ImmediateMesh.new()
		arc_line.mesh = im
	else:
		im.clear_surfaces()
	im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for p in line_pts:
		im.surface_add_vertex(origin.to_local(p))
	im.surface_end()
	(arc_line.material_override as StandardMaterial3D).albedo_color = Color(0.3, 0.9, 0.5) if ok else Color(0.9, 0.3, 0.3)
	arc_line.visible = true


## Перенос по готовому прицелу — тому, что человек видел последним кадром.
func _do_teleport(aim: Dictionary, mode: String, yaw := NAN) -> void:
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
		var holding: bool = grip_source.call(hand)
		# Зацеп ищем только с нажатым грипом: обход группы из 14 брусков на каждую руку каждый такт
		# шёл и тогда, когда человек просто шёл мимо (сессия 24, цена кадра).
		var hold_node: Node3D = _climbable_near(ctrl.global_position) if (holding or falsify_climb_every) else null
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
		var space := get_viewport().world_3d.direct_space_state
		# Лесенкой вперёд: первая годная площадка. Одной пробы на PROBE_AHEAD_M мало — край крыши
		# может кончаться раньше, чем выступает зацеп, и под пробой оказывается пустота (стена
		# лазанья улицы: зацепы торчат за край крыши на 4 см), и человек с глазами над крышей не
		# мог на неё забраться.
		var hit := {}
		var steps := [Mantle.PROBE_AHEAD_M] if falsify_mantle_spot else Mantle.PROBE_STEPS
		for d in steps:
			var probe := head_pos + ahead.normalized() * float(d)
			var q := PhysicsRayQueryParameters3D.create(probe + Vector3.UP * 0.05, probe - Vector3.UP * 1.2)
			# Зацепы площадкой не бывают: они торчат из стены, и луч, упавший на верх зацепа,
			# принимал его за край крыши (шлем 2026-09-26: «на площадку 3.05» у крыши 3.60).
			q.exclude = [body.get_rid()] if falsify_mantle_spot else _not_ground()
			var h := space.intersect_ray(q)
			if not h.is_empty() and Mantle.fits(head_pos.y, (h["position"] as Vector3).y, h["normal"]):
				hit = h
				break
		if hit.is_empty():
			_ledge_held = 0.0
			return
		spot = hit["position"]
		target = Mantle.landing(spot, look)
	# Приземление — НА ПОВЕРХНОСТЬ под точкой приземления (владелец 2026-09-26: «на площадку, на рост
	# пользователя»). Найденная точка говорит, ГДЕ кромка, но её высота — не высота площадки: зацеп
	# под кромкой, выступ стены, верх бордюра. Тело, поставленное на неё, оказывалось внутри
	# площадки, и физика выталкивала его рывком (+0.55 м на шлеме).
	if not falsify_mantle_spot:
		var ground := _ground_under(target)
		if is_nan(ground):
			_ledge_held = 0.0
			return
		target.y = ground
	# Площадка должна быть выше НОГ: иначе «перевалом» окажется всё, на что человек смотрит сверху.
	if target.y - body.global_position.y < MANTLE_RISE_MIN and not falsify_mantle_eager_floor:
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
	# Сколько тело прошло — столько и снимаем с origin: непройденное остаётся в нём и разойдётся
	# само обычным следованием за головой уже на площадке.
	var done := body.carry_shift(carry)
	origin.position -= Vector3(done.x, 0.0, done.z)
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


## Поверхность, на которую встанут ноги в точке `at`: луч сверху вниз, мимо тела и зацепов. NAN —
## опоры нет (под точкой пустота или только зацепы).
func _ground_under(at: Vector3) -> float:
	var q := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 1.0, at - Vector3.UP * 2.0)
	q.exclude = _not_ground()
	var hit := get_viewport().world_3d.direct_space_state.intersect_ray(q)
	return NAN if hit.is_empty() else (hit["position"] as Vector3).y


## Что опорой для ног не считается: само тело и зацепы лазанья.
func _not_ground() -> Array[RID]:
	var out: Array[RID] = [body.get_rid()]
	for node in get_tree().get_nodes_in_group("climb"):
		if node is CollisionObject3D:
			out.append((node as CollisionObject3D).get_rid())
	return out


## Бросить начатый перевал. Состояние перевала живёт ЗДЕСЬ, в `_mantle`, а не в теле: возврат в
## стартовую точку снимал `body.mantling`, но словарь оставался, и следующий же такт `_mantle_tick`
## возвращал тело на траекторию перевала — возврат отменялся (окно Mantle.RISE_S, аудит 2026-09-23).
## Маску столкновений возвращает вызывающий (`release_collisions`), как и при обычном конце.
func cancel_mantle() -> void:
	if falsify_mantle_sticks or _mantle.is_empty():
		return
	_mantle.clear()
	moved.emit("перевал", "отменён")


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


## Кто держит ввод, кроме шара, — одним правилом на приложение и на прибор. Раньше правило жило
## только в main.gd, и проверка могла подтвердить лишь свою копию: копия осталась бы зелёной, даже
## если бы приложение спрашивало залипший флаг (сессия 30).
static func hold_reason(pin_waiting: bool, panel_locked: bool, text_open: bool) -> String:
	if falsify_hold_stuck:
		# Признак копится флагом по сигналам «показана/скрыта»: «показана» пришла, парная «скрыта» —
		# нет, и удержание не снимается уже никогда (сессия 30).
		_stuck = _stuck or text_open
		if _stuck:
			return "открыт ввод текста"
	if pin_waiting:
		return "ждём PIN"
	if panel_locked:
		return "панель заперта"
	if text_open:
		return "открыт ввод текста"
	return ""


## Кто сейчас держит ввод — словами, для журнала.
func _hold_reason() -> String:
	var why := str(input_hold.call())
	if why != "":
		return why
	return "шар открыт" if menu != null and menu.is_open() else "ввод занят"


## Остановить всё начатое перемещение: скорость, прицел телепорта, запись отрезка ходьбы.
##
## Зовётся каждый такт, пока ввод занят, поэтому обязана быть идемпотентной — и сообщать в журнал
## ровно один раз, на первом такте остановки.
func suspend(why: String) -> void:
	if falsify_no_suspend:
		return
	var was_moving: bool = _walking or aiming \
			or Vector2(body.velocity.x, body.velocity.z).length() > 0.01
	# Сначала само движение, и только потом узлы: любая ошибка ниже (в стенде дуги ещё нет, в
	# приложении её может не быть до setup) оборвала бы остановку на полпути, а скорость живёт
	# в теле сама — ровно этим дефект и был.
	body.velocity.x = 0.0
	body.velocity.z = 0.0
	# Прицел бросается, а не «доигрывается»: иначе отпускание стика после закрытия меню швырнуло бы
	# человека туда, куда он целился до того, как его прервали.
	aiming = false
	if arc_line != null and is_instance_valid(arc_line):
		arc_line.visible = false
	if menu != null:
		_track_walk(str(settings_value("move_mode")), false)
	_end_smooth_turn()
	if was_moving and not _suspended:
		moved.emit("перемещение прервано", why)
		_suspended = true


## Отрезок непрерывного движения: строка в журнал на старте и на остановке. Событие на каждый кадр
## залило бы журнал (90 строк в секунду), а молчание — лишило бы свидетеля вовсе.
##
## Отрезок заявляется, только когда себя доказал — прошёл WALK_CLAIM_M. Недоказавшийся не пишет ни
## «пошёл», ни «встал», а считается и уходит числом в ближайшую строку «встал».
func _track_walk(mode: String, moving: bool) -> void:
	if falsify_quiet_walk:
		return
	if moving and not _walking:
		_walking = true
		_walk_claimed = false
		_walk_from = body.global_position
		_walk_ms = Time.get_ticks_msec()
	if moving and not _walk_claimed:
		var gone := body.global_position - _walk_from
		gone.y = 0.0
		if falsify_walk_jitter or gone.length() >= WALK_CLAIM_M:
			_walk_claimed = true
			moved.emit("ходьба", "пошёл: %s" % mode)
	elif _walking and not moving:
		_walking = false
		if not _walk_claimed:
			_walk_short += 1
			return
		var way := body.global_position - _walk_from
		var secs := (Time.get_ticks_msec() - _walk_ms) / 1000.0
		way.y = 0.0
		var short := "" if _walk_short == 0 else ", перед этим коротких рывков %d" % _walk_short
		_walk_short = 0
		moved.emit("ходьба", "встал: %s, %.2f м за %.1f с, средняя %.2f м/с%s" % [
				mode, way.length(), secs, way.length() / maxf(secs, 0.001), short])
