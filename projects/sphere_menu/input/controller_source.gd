extends Node

## Источник ввода: контроллеры (слой 6, docs/design/sphere-menu.md §6). Ф2, шаг 1б.
##
## Схема (ADR-0008 и решения владельца 2026-09-15):
##   левый  Y — открыть/закрыть; X — назад/отмена; стик — вращение;
##          курок — активная ячейка: короткое — действие по умолчанию, удержание — действия;
##   правый луч + курок — то же для ячейки под лучом; кончик у шара + курок — касанием;
##          кончик у шара + грип — захват и вращение; B — отменить последнее
##          (в режиме заданий — следующее задание); стик — прокрутка панели.
## Панель в режиме правки (настройка, мастер) принимает правый луч или кончик + курок
## как мышь (menu/ui_panel.gd); пока указатель на панели, шар его не получает. В режиме
## информации панель берёт луч, только когда содержимое не влезло (решение владельца
## 2026-09-16: прокрутка стиком, кнопками ▲/▼ и перетаскиванием).
## В мастере шар живой, как в работе: значения меняются только на панели (шаг 1в —
## стик неточен на шкале).
##
## Действия — из стандартной карты Godot (openxr_action_map.tres).

signal next_task
## Оба стика нажаты разом — скриншот (не пункт шара, просьба владельца 2026-09-17).
signal screenshot_requested

const Menu := preload("res://menu/sphere_menu.gd")
const Chord := preload("res://input/chord.gd")
const UiPanel := preload("res://menu/ui_panel.gd")
const RAY_MAT := preload("res://menu/ray_material.tres")

const DEADZONE := 0.2
## Кончик контроллера вперёд от позы aim, м.
const TIP := 0.03
## Прокрутка панели правым стиком, пикселей вьюпорта в секунду при полном отклонении.
const SCROLL_SPEED := 900.0

var left: XRController3D
var right: XRController3D
var menu: Menu
var panel: UiPanel
## Мастер и режим заданий — у сессии (main.gd); здесь только маршрут ввода.
var session: Node
var ray: MeshInstance3D
var tasks_on := false

var _prev := {}
var _chord: Chord = Chord.new()


func setup(p_left: XRController3D, p_right: XRController3D, p_menu: Menu, p_session: Node) -> void:
	left = p_left
	right = p_right
	menu = p_menu
	session = p_session
	ray = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.002, 0.002, 1.0)
	box.material = RAY_MAT
	ray.mesh = box
	ray.position = Vector3(0, 0, -0.5)
	right.add_child(ray)
	menu.haptic.connect(_on_haptic)


func _on_haptic(hand: String, strength: float) -> void:
	var c := left if hand == "left" else right
	if c != null:
		c.trigger_haptic_pulse("haptic", 0.0, strength, 0.02, 0.0)


func _pressed_edge(ctrl: XRController3D, action: String) -> bool:
	var key := "%s/%s" % [ctrl.tracker, action]
	var now := ctrl.is_button_pressed(action)
	var was: bool = _prev.get(key, false)
	_prev[key] = now
	return now and not was


func tip_position() -> Vector3:
	return right.global_position - right.global_basis.z.normalized() * TIP


func _process(delta: float) -> void:
	if left == null or right == null or menu == null:
		return
	var now := Time.get_ticks_msec()

	if _chord.update(left.is_button_pressed("primary_click"), right.is_button_pressed("primary_click"), now):
		screenshot_requested.emit()

	if _pressed_edge(left, "by_button"):
		menu.toggle()
	if _pressed_edge(left, "ax_button"):
		menu.back()

	var stick: Vector2 = left.get_vector2("primary")
	if stick.length() > DEADZONE:
		menu.rotate_stick(stick, float(menu.settings.get_value("stick_speed")) * delta)

	# Жест возврата — на верхний уровень. Сигнал берётся от самой руки, а не от шара:
	# положение шара сглажено следованием, и рывок в нём заметно слабее.
	if menu.head != null:
		menu.gesture_update(left.global_position, menu.head.global_transform, delta)

	menu.press_active(left.is_button_pressed("trigger_click"), now)

	ray.visible = menu.is_open() or (panel != null and panel.interactive())
	var tip := tip_position()
	var trig := right.is_button_pressed("trigger_click")
	# Правый стик — прокрутка панели: он свободен, и прокрутка не требует прицеливания
	# лучом, пока панель висит на шаре в другой руке.
	if panel != null and panel.visible:
		var rs: Vector2 = right.get_vector2("primary")
		if absf(rs.y) > DEADZONE:
			panel.scroll_how = "stick"
			panel.scroll_by(-rs.y * SCROLL_SPEED * delta)
	# Нажатие или захват, начатые на шаре, доводятся на шаре: иначе увод луча на
	# панель отпускал бы курок на ячейке и срабатывал короткий выбор.
	var menu_busy: bool = menu.press_right.is_down() or menu.grab.active
	if panel != null and panel.pointer_active() and not menu_busy:
		var px: Variant = panel.pointer_tip(tip)
		if px == null:
			px = panel.pointer_ray(right.global_position, -right.global_basis.z.normalized())
		panel.pointer_update(px, trig)
		if px != null or panel.pointer_held():
			menu.hover_key = null
			menu.press_key(null, false, now)
			menu.grab_update(tip, false, delta)
			_after_right()
			return
	menu.grab_update(tip, right.is_button_pressed("grip_click"), delta)
	var hover: Variant = null
	if menu.is_open():
		hover = menu.key_at_tip(tip)
		if hover == null:
			hover = menu.key_at_ray(right.global_position, -right.global_basis.z.normalized())
	menu.hover_key = hover
	menu.press_key(hover, trig and not menu.grab.active, now)
	_after_right()


func _after_right() -> void:
	if _pressed_edge(right, "by_button"):
		if tasks_on:
			next_task.emit()
		else:
			menu.undo()
