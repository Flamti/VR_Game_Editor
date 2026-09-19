extends Node

## Источник ввода: руки (слой 6, docs/design/sphere-menu.md §6). Ф2, шаг 1к.
##
## Тот же маршрут, что у контроллеров (input/controller_source.gd), жесты — по ADR-0008:
##   левая  кулак — открыть/закрыть (как Y); кисть — поза шара и вращение, как grip контроллера;
##          резкий взмах/встряхивание — верхний уровень, как у контроллера;
##   правая касание кончиком указательного — выбор ячейки (как курок у кончика), удержание
##          касания — действия; протяжка вдоль поверхности — вращение с инерцией, выбор
##          отменяется; щипок (с гейтом контекста) — нажатие на панели лучом ладони.
## «Назад» — ячейкой «Назад». Кнопок B и стиков у рук нет: следующее задание, отмена и скриншот
## остаются контроллерам.
##
## Вся механика — в step() над XRHandTracker, без XRServer: настольные проверки и дымовой прогон
## кормят её синтетическими трекерами, как прибор — ProbeHandFeatures.

## Жест распознан — в журнал: name "fist" | "touch" | "drag" | "pinch", подробности в data.
signal gesture(name: String, data: Dictionary)

const Menu := preload("res://menu/sphere_menu.gd")
const UiPanel := preload("res://menu/ui_panel.gd")
const Pose := preload("res://input/hand_pose.gd")
const Touch := preload("res://input/hand_touch.gd")
const Gesture := preload("res://input/hand_gesture.gd")
const Features := preload("res://probe_hand_features.gd")
const RAY_MAT := preload("res://menu/ray_material.tres")

const TRACKER_LEFT := "/user/hand_tracker/left"
const TRACKER_RIGHT := "/user/hand_tracker/right"
## Протяжка: касание стало вращением, когда кончик ушёл по поверхности дальше этой доли ячейки.
## Сессия 11 (путь каждого касания в журнале, travel_cm): касания обычно 0.03–0.31 ячейки, три — у
## самого прежнего порога 0.5 (0.47–0.50); протяжки 0.53–0.76 спорные, одна из них — неудавшееся
## касание (повторено через 2 с на той же ячейке); осознанные протяжки — от 1.34. Порог поставлен в
## зазор решением владельца 2026-09-19. Граница применимости — одна сессия одного человека.
const DRAG_CELLS := 0.8

var menu: Menu
var panel: UiPanel
var session: Node
## Пока false, источник ничего не делает: ведут контроллеры (input/input_arbiter.gd).
var enabled := false
## Поза левой руки для шара (menu.hand, пока ведут руки). Строится из суставов
## (Pose.pose): последняя известная держится, пока рука не отслежена, — шар не падает.
var anchor: Node3D
var ray: MeshInstance3D
var touch: Touch = Touch.new()
var fist: Gesture = Gesture.new()
var pinch: Gesture = Gesture.new()
## Фальсификаторы дымового прогона. «handspace»: суставы трекера берутся как мировые, мимо
## XROrigin3D. «dragselect»: протяжка не отменяет выбор — на отпускании срабатывает ячейка входа.
## «handoff»: отдача управления не бросает начатое касание.
var falsify_world_space := false
var falsify_drag_selects := false
var falsify_keep_on_release := false

var _origin: Node3D
var _touch_key: Variant = null
var _touch_ms := 0


func setup(p_origin: Node3D, p_menu: Menu, p_session: Node) -> void:
	_origin = p_origin
	menu = p_menu
	session = p_session
	anchor = Node3D.new()
	anchor.name = "HandAnchor"
	p_session.add_child(anchor)
	ray = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.002, 0.002, 1.0)
	box.material = RAY_MAT
	ray.mesh = box
	ray.visible = false
	p_session.add_child(ray)


## Взять управление. from — где шар сейчас: поза руки ещё может быть не получена,
## и шар не должен прыгнуть в начало координат.
func activate(from: Transform3D) -> void:
	anchor.global_transform = from
	enabled = true


## Отдать управление: начатое бросается без события — ни выбора, ни щелчка по панели.
func release() -> void:
	enabled = false
	if not falsify_keep_on_release:
		_end_touch_silent()
	fist.reset()
	pinch.reset()
	if menu != null:
		menu.hover_key = null
	if panel != null and panel.pointer_held():
		panel.pointer_update(null, false)
	if ray != null:
		ray.visible = false


func _process(delta: float) -> void:
	if not enabled or menu == null or _origin == null:
		return
	var head_xf := menu.head.global_transform if menu.head != null else Transform3D()
	step(XRServer.get_tracker(TRACKER_LEFT) as XRHandTracker, XRServer.get_tracker(TRACKER_RIGHT) as XRHandTracker,
			_origin.global_transform, head_xf, Time.get_ticks_usec(), delta)


## Кадр рук. Суставы трекеров — в пространстве XROrigin3D, origin_xf переводит их в мир.
func step(lt: XRHandTracker, rt: XRHandTracker, origin_xf: Transform3D, head_xf: Transform3D,
		now_us: int, delta: float) -> void:
	var now_ms := now_us / 1000
	var head_local := origin_xf.affine_inverse() * head_xf.origin
	_left(lt, origin_xf, head_xf, head_local, now_us, delta)
	_right(rt, origin_xf, head_local, now_us, now_ms, delta)


func _left(lt: XRHandTracker, origin_xf: Transform3D, head_xf: Transform3D, head_local: Vector3,
		now_us: int, delta: float) -> void:
	var pose: Variant = Pose.pose(lt, true)
	if pose != null:
		anchor.global_transform = origin_xf * (pose as Transform3D)
	var cls := fist.update(Features.sample(lt, true, head_local), now_us)
	if fist.entered("fist"):
		var was_open := menu.is_open()
		menu.toggle()
		gesture.emit("fist", {"open": not was_open})
	# Жест возврата — от ладони, как у контроллера от его позы: рывок в сглаженном шаре слабее.
	# В кулаке рука движется ради жеста открытия, не ради возврата.
	if pose != null and cls != "fist" and menu.head != null:
		menu.gesture_update(anchor.global_position, head_xf, delta)
	else:
		# Пропуск кадров — разрыв трассы: без сброса скачок позы через него читался бы взмахом.
		menu.shake.reset()
		menu.swipe.reset()


func _right(rt: XRHandTracker, origin_xf: Transform3D, head_local: Vector3, now_us: int, now_ms: int,
		delta: float) -> void:
	var was_pinch := pinch.held("pinch")
	pinch.update(Features.sample(rt, false, head_local), now_us)
	var pinching := pinch.held("pinch")
	if pinching and not was_pinch:
		gesture.emit("pinch", {})

	var r: Array = Pose.ray(rt, false)
	var ray_o := Vector3.ZERO
	var ray_d := Vector3.ZERO
	if not r.is_empty():
		ray_o = origin_xf * (r[0] as Vector3)
		ray_d = (origin_xf.basis * (r[1] as Vector3)).normalized()
	var on_panel := panel != null and panel.pointer_active()
	ray.visible = on_panel and not r.is_empty()
	if ray.visible:
		var up := Vector3.UP if absf(ray_d.y) < 0.99 else Vector3.FORWARD
		ray.global_transform = Transform3D(Basis.looking_at(ray_d, up), ray_o + ray_d * 0.5)

	# Касание или протяжка, начатые на шаре, доводятся на шаре — как нажатие контроллера.
	if on_panel and not touch.inside:
		var px: Variant = panel.pointer_ray(ray_o, ray_d) if not r.is_empty() else null
		panel.pointer_update(px, pinching)
		if px != null or panel.pointer_held():
			menu.hover_key = null
			return

	var tip_local: Variant = Pose.tip(rt)
	if tip_local == null or not menu.is_open():
		# Кончик потерян посреди касания: выбора по нему не будет, начатая протяжка
		# отпускается с инерцией.
		_end_touch_silent()
		menu.hover_key = null
		return
	var tip: Vector3 = (tip_local as Vector3) if falsify_world_space else origin_xf * (tip_local as Vector3)
	var local := menu.global_transform.affine_inverse() * tip
	var ev := touch.update(local.length() - menu.radius(), local, menu.radius(), drag_threshold())
	match ev:
		"enter":
			_touch_key = menu.key_at_tip(tip)
			_touch_ms = now_ms
			menu.press_key(_touch_key, true, now_ms)
		"drag":
			if not falsify_drag_selects:
				menu.press_abort("right")
			# Захват — с точки входа: путь до порога не теряется, точка под пальцем догоняет его.
			menu.grab.begin(touch.start_dir)
			menu.grab_update(tip, true, delta)
		"exit":
			if touch.dragging:
				menu.grab_update(tip, false, delta)
				if falsify_drag_selects:
					menu.press_key(_touch_key, false, now_ms)
			else:
				menu.press_key(_touch_key, false, now_ms)
			gesture.emit("drag" if touch.dragging else "touch", {"key": str(_touch_key),
					"travel_cm": snappedf(touch.travel * 100.0, 0.01), "ms": now_ms - _touch_ms})
			_touch_key = null
		_:
			if touch.inside and touch.dragging:
				menu.grab_update(tip, true, delta)
			elif touch.inside:
				menu.press_key(_touch_key, true, now_ms)
	menu.hover_key = _touch_key if touch.inside else menu.key_at_tip(tip)


## Путь кончика по поверхности, после которого касание — протяжка, метры.
func drag_threshold() -> float:
	return DRAG_CELLS * menu.settings.actual_cell_cm() / 100.0


func _end_touch_silent() -> void:
	if touch.inside and menu != null:
		if touch.dragging:
			menu.grab.end()
		else:
			menu.press_abort("right")
	touch.reset()
	_touch_key = null
