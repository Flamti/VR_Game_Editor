extends Node3D

## Шар-меню: сборка слоёв (docs/design/sphere-menu.md, ADR-0008). Компакт, Ф2 шаг 1б.
##
## Положение шара — от левого контроллера (hand + hand_offset), ориентация — от
## menu/hand_follow.gd по режиму «Вращение рукой» и через сглаживание: прямое
## крепление к контроллеру передавало каждый рывок кисти (сессия 2026-09-15,
## «резкое вращение сбивает фокус»). Глобус получает поворот даром — ячейки
## прибиты к шару, активная — та, что смотрит на голову. Линза держит
## неискажённую середину напротив лица, поэтому смена «переда» в системе шара
## переводится в обратный поворот содержимого.
##
## Что показывать и что делать решает навигатор (menu/navigator.gd); здесь —
## поверхности, рендер, нажатия, захват, панель. Ввод приходит намерениями.

signal event(name: String, data: Dictionary)
signal haptic(hand: String, strength: float)
signal wizard_requested
signal tasks_changed(on: bool)
## Открыть правку настройки на панели (пункт настроек, короткое нажатие или «Изменить»).
signal edit_requested(id: String)

const Item := preload("res://menu/item.gd")
const State := preload("res://menu/state.gd")
const Catalog := preload("res://menu/catalog_demo.gd")
const Globe := preload("res://menu/surface_globe.gd")
const Lens := preload("res://menu/surface_lens.gd")
const Surface := preload("res://menu/surface.gd")
const Active := preload("res://menu/active_cell.gd")
const Spring := preload("res://menu/spring.gd")
const Atlas := preload("res://menu/label_atlas.gd")
const Renderer := preload("res://menu/cell_renderer.gd")
const Navigator := preload("res://menu/navigator.gd")
const Settings := preload("res://menu/settings.gd")
const Press := preload("res://menu/press.gd")
const Grab := preload("res://menu/grab.gd")
const Panel3D := preload("res://menu/info_panel.gd")
const HandFollow := preload("res://menu/hand_follow.gd")
const Stick := preload("res://menu/stick.gd")
const Demo := preload("res://menu/demo.gd")

## Сколько без ввода вращения до включения детента.
const DETENT_IDLE_MS := 150
## Касание кончиком контроллера: зазор до поверхности шара, м.
const TOUCH_GAP := 0.03
## Непрерывное вращение для самопроверки худшего случая, рад/с; 0 — выкл.
var debug_spin := 0.0

var head: Node3D
## Рука, за которой следует шар; null — шар стоит, где поставили (дымовой прогон).
var hand: Node3D
## Положение шара в системе руки.
var hand_offset := Vector3.ZERO
var follow: HandFollow = HandFollow.new()
var demo: Demo = Demo.new()
var _demo_progress := -1.0
var panel: Panel3D
## Панель занята другим содержимым (шаг мастера): меню её не перезаписывает.
var panel_locked := false
var settings: Settings = Settings.new()
var catalog: Catalog = Catalog.new()
var nav: Navigator
var active: Active = Active.new()
var spring: Spring = Spring.new()
var press_left: Press = Press.new()
var press_right: Press = Press.new()
var grab: Grab = Grab.new()
var atlas: Atlas
var renderer: Renderer

var globe: RefCounted
var lens: RefCounted
var hover_key: Variant = null
var touching := false
var _surface_sig := ""
var _list_version := 0
var _codes := PackedInt32Array()
var _marks := PackedByteArray()
var _last_rotate_ms := -100000
var _pressed_key: Variant = null
var _pressed_hand := ""


func _ready() -> void:
	nav = Navigator.new(catalog, settings)
	atlas = Atlas.new()
	add_child(atlas)
	renderer = Renderer.new()
	add_child(renderer)
	renderer.setup(atlas.texture())
	apply_settings()
	visible = false


func surface() -> RefCounted:
	return globe if settings.get_value("surface") == "globe" else lens


func radius() -> float:
	return float(settings.get_value("radius_cm")) / 100.0


func is_open() -> bool:
	return nav.state.mode != State.Mode.CLOSED


func params() -> Dictionary:
	var d := settings.values.duplicate()
	d["folder"] = nav.state.folder()
	d["view"] = nav.view
	d["freq"] = settings.globe_frequency()
	d["actual_cell_cm"] = snappedf(settings.actual_cell_cm(), 0.01)
	return d


## Применить настройки: поверхности перестраиваются только при смене того, что
## меняет геометрию, иначе прокрутка терялась бы на каждой ступени мастера.
func apply_settings() -> void:
	press_left.hold_ms = int(settings.get_value("hold_ms"))
	press_right.hold_ms = press_left.hold_ms
	grab.friction = float(settings.get_value("grab_friction"))
	spring.omega = float(settings.get_value("detent"))
	active.hysteresis = float(settings.get_value("hysteresis"))
	if follow.mode != settings.get_value("hand_rotation"):
		follow.reset()
	follow.mode = settings.get_value("hand_rotation")
	follow.smoothing = float(settings.get_value("hand_smoothing"))
	var sig := "%s|%s|%s" % [settings.get_value("surface"), settings.get_value("radius_cm"), settings.get_value("cell_cm")]
	if sig != _surface_sig:
		_surface_sig = sig
		globe = Globe.new(settings.globe_frequency())
		lens = Lens.new(settings.lens_alpha())
		active.reset()
		if is_open():
			_update_front()
			surface().assign(nav.items().size())
		_list_version += 1


## Прокрутка для навигатора — с подписью геометрии: прокрутку глобуса m=3 нельзя
## применить к глобусу m=5 или к линзе.
func _scroll() -> Dictionary:
	return {"__sig": _surface_sig, "v": surface().get_scroll()}


# --- намерения ------------------------------------------------------------------

func toggle() -> void:
	nav.state.toggle()
	if is_open():
		nav.open_root()
		_update_front()
		active.reset()
		_load_list(null)
	visible = is_open()
	if panel != null:
		panel.visible = is_open()
	if not is_open():
		renderer.clear()
	event.emit("toggle", {"open": is_open()})


func close() -> void:
	if is_open():
		toggle()


## Стик: вращение в экранных осях зрителя (menu/stick.gd). angle — рад за кадр.
func rotate_stick(stick: Vector2, angle: float) -> void:
	if not is_open():
		return
	var sf := surface()
	var view_up: Vector3 = sf.up
	if head != null:
		view_up = global_basis.inverse() * head.global_basis.y
	rotate_local(Stick.rotation(sf.front, view_up, stick, angle))


## Поворот шара в его локальных координатах.
func rotate_local(q: Quaternion) -> void:
	if not is_open():
		return
	surface().apply_rotation(q)
	_last_rotate_ms = Time.get_ticks_msec()


func back() -> void:
	if is_open():
		_handle(nav.back(_scroll()))


func undo() -> void:
	if is_open():
		_handle(nav.undo())


## Левый курок — на активной ячейке. pressed — состояние кнопки в этом кадре.
func press_active(pressed: bool, now_ms: int) -> void:
	_press(press_left, "left", active.key, pressed, now_ms)


## Правый курок — на ячейке под лучом или под кончиком.
func press_key(key: Variant, pressed: bool, now_ms: int) -> void:
	_press(press_right, "right", key, pressed, now_ms)


## Цель нажатия фиксируется в момент нажатия: пока держат курок, шар может
## провернуться, но удерживается та ячейка, на которой начали.
func _press(p: Press, hand: String, key: Variant, pressed: bool, now_ms: int) -> void:
	if not is_open():
		p.update(false, now_ms)
		return
	if pressed and not p.is_down():
		_pressed_key = key
		_pressed_hand = hand
		var slot: int = surface().slot_of(key) if key != null else Surface.SLOT_EMPTY
		if nav.is_danger(slot):
			p.arm_confirm()
		else:
			p.disarm_confirm()
	var target: Variant = _pressed_key if _pressed_hand == hand else key
	var ev := p.update(pressed, now_ms)
	if not p.is_down() and _pressed_hand == hand:
		_pressed_key = null
	if ev == "":
		return
	var tslot: int = surface().slot_of(target) if target != null else Surface.SLOT_EMPTY
	match ev:
		"short":
			if tslot == Surface.SLOT_BACK:
				_handle(nav.back(_scroll()))
			else:
				_handle(nav.short(tslot, _scroll()))
		"hold", "confirm":
			_handle(nav.hold(tslot if tslot >= 0 else -1, _scroll()))
		"cancel":
			nav.message = "Отменено: удерживайте до конца кольца"
	p.disarm_confirm()


## Захват правым контроллером: tip — кончик в мире, grip — зажат ли грип.
func grab_update(tip: Vector3, grip: bool, delta: float) -> void:
	if not is_open():
		grab.end()
		touching = false
		return
	var local := global_transform.affine_inverse() * tip
	var near := absf(local.length() - radius()) < TOUCH_GAP
	if near and not touching and settings.get_value("haptics"):
		haptic.emit("right", 0.25)
	touching = near
	if grip and not grab.active and near:
		grab.begin(local.normalized())
	elif grip and grab.active:
		var q := grab.update(local.normalized(), delta)
		if q != Quaternion.IDENTITY:
			surface().apply_rotation(q)
			_last_rotate_ms = Time.get_ticks_msec()
	elif not grip and grab.active:
		grab.end()


## Ключ ячейки под кончиком, если кончик у поверхности; иначе null.
func key_at_tip(tip: Vector3) -> Variant:
	if not is_open():
		return null
	var local := global_transform.affine_inverse() * tip
	if absf(local.length() - radius()) > TOUCH_GAP:
		return null
	return surface().cell_at_direction(local.normalized())


## Ключ ячейки под мировым лучом; null — мимо шара.
func key_at_ray(origin: Vector3, dir: Vector3) -> Variant:
	if not is_open():
		return null
	var c := global_position
	var r := radius()
	var oc := origin - c
	var b := oc.dot(dir)
	var disc := b * b - (oc.length_squared() - r * r)
	if disc < 0.0:
		return null
	var t := -b - sqrt(disc)
	if t < 0.0:
		return null
	var local := (global_transform.affine_inverse() * (origin + dir * t)).normalized()
	return surface().cell_at_direction(local)


# --- кадр ------------------------------------------------------------------------

func _process(delta: float) -> void:
	if not is_open():
		follow.reset()
		return
	_follow_hand(delta)
	var now := Time.get_ticks_msec()
	# кисть вращается — доводка молчит, иначе тянет активную навстречу руке
	if follow.rotating():
		_last_rotate_ms = now
	_update_front()
	_demo_step(delta, now)
	var sf := surface()
	if debug_spin > 0.0:
		rotate_local(Quaternion(sf.up, debug_spin * delta))
	var coast := grab.coast(delta)
	if coast != Quaternion.IDENTITY:
		sf.apply_rotation(coast)
		_last_rotate_ms = now
	if active.update(sf, now):
		if settings.get_value("haptics"):
			haptic.emit("left", 0.15)
		event.emit("active", {"key": str(active.key), "slot": sf.slot_of(active.key)})
	_detent(delta)

	var sig := [settings.get_value("surface"), sf.render_version(), _surface_sig, _list_version]
	if renderer.needs_redraw(sig):
		var cell_r: float = settings.actual_cell_cm() * 0.5 / 100.0
		renderer.draw(sf.render_cells(), radius(), cell_r, _codes, _marks, sig)
	renderer.transform.basis = sf.render_basis()
	var prog := maxf(press_left.progress(now), press_right.progress(now))
	if _demo_progress >= 0.0:
		renderer.set_state(active.key, hover_key, active.key, _demo_progress)
	else:
		renderer.set_state(active.key, hover_key, _pressed_key, prog)
	_update_panel(now)


## Показать настройку циклом (menu/demo.gd). false — у настройки нет демонстрации.
func start_demo(id: String) -> bool:
	if not is_open():
		return false
	return demo.start(id, surface().cell_angle(), float(settings.get_value("stick_speed")),
			float(settings.get_value("hold_ms")))


func _demo_step(delta: float, now: int) -> void:
	_demo_progress = -1.0
	follow.demo_offset = Quaternion.IDENTITY
	if not demo.running():
		return
	var d := demo.update(delta)
	if d.has("stick"):
		rotate_stick(d["stick"], float(d["angle"]))
	if d.get("no_detent", false):
		_last_rotate_ms = now
	if d.get("fling", false):
		var sf := surface()
		var view_up: Vector3 = sf.up
		if head != null:
			view_up = global_basis.inverse() * head.global_basis.y
		var front: Vector3 = sf.front
		var up: Vector3 = (view_up - front * view_up.dot(front)).normalized()
		grab.end()
		grab.angular_velocity = up * Demo.FLING
		_last_rotate_ms = now
	if d.has("progress"):
		_demo_progress = float(d["progress"])
	if d.has("hand"):
		follow.demo_offset = d["hand"]


func _follow_hand(delta: float) -> void:
	if hand == null:
		return
	var hx := hand.global_transform
	var pos := hx * hand_offset
	var head_pos := head.global_position if head != null else pos + Vector3.BACK
	var q := follow.update(hx.basis.get_rotation_quaternion(), pos, head_pos, delta)
	global_transform = Transform3D(Basis(q), pos)


func _update_panel(now: int) -> void:
	if panel == null:
		return
	if head != null:
		panel.place(global_position, radius(), head.global_transform, settings.get_value("panel_side"))
	panel.toast(nav.message, now)
	nav.message = ""
	panel.tick(now)
	if panel_locked:
		return
	var key: Variant = hover_key if hover_key != null else active.key
	var slot: int = surface().slot_of(key) if key != null else Surface.SLOT_EMPTY
	var it: Item = nav.item_at(slot)
	var extra := ""
	if slot == Surface.SLOT_BACK:
		extra = "Назад" if nav.view == "browse" and not nav.multi else "Отмена"
	elif it != null and it.setting != "":
		extra = settings.label(it.setting)
	elif it != null and it.kind == Item.Kind.TOGGLE:
		extra = "вкл" if it.on else "выкл"
	var icon := atlas.icon(it.icon) if it != null else atlas.icon("back" if extra == "Назад" else "cancel")
	panel.show_item(it, icon, nav.breadcrumbs(), nav.hint(), extra)


## «Перёд» — направление из центра шара на голову, в координатах шара.
func _update_front() -> void:
	if head == null:
		return
	var new_front := (global_transform.affine_inverse() * head.global_position).normalized()
	if settings.get_value("surface") == "lens":
		var old: Vector3 = lens.front
		lens.front = new_front
		if old.angle_to(new_front) > 1e-5:
			# содержимое, бывшее в старом переде, остаётся там же на шаре
			lens.apply_rotation(Quaternion(new_front, old))
	else:
		lens.front = new_front
	globe.front = new_front


func _detent(delta: float) -> void:
	var sf := surface()
	var err: float = sf.snap_error()
	if spring.omega <= 0.0 or grab.active or grab.coasting() \
			or Time.get_ticks_msec() - _last_rotate_ms < DETENT_IDLE_MS or err < 1e-4:
		spring.value = err
		spring.velocity = 0.0
		return
	var next := spring.step(0.0, delta)
	var part := clampf((err - next) / err, 0.0, 1.0)
	sf.apply_rotation(Quaternion.IDENTITY.slerp(sf.snap_rotation(), part))


# --- результаты навигатора ---------------------------------------------------------

func _handle(res: Dictionary) -> void:
	var data := {"do": res.get("do", ""), "view": nav.view, "folder": nav.state.folder()}
	match res.get("do", ""):
		"reload":
			_load_list(res.get("scroll", null))
		"redraw":
			_refresh_codes()
		"focus":
			_load_list(res.get("scroll", null))
			_focus_slot(int(res["slot"]))
		"default":
			var it: Item = res["item"]
			data["item"] = it.id
			data["title"] = it.title
			event.emit("select", data)
			if res.get("close", false):
				close()
			return
		"properties":
			var pit: Item = res.get("item", null)
			if pit != null:
				nav.message = "%s: %s, %d КБ, изменён %s" % [pit.title, pit.type_label, pit.size_kb, pit.modified]
		"wizard":
			close()
			wizard_requested.emit()
		"tasks":
			tasks_changed.emit(bool(res["on"]))
			_refresh_codes()
		"setting":
			apply_settings()
			settings.save()
			_refresh_codes()
			data["setting"] = res["id"]
			data["value"] = settings.get_value(res["id"])
		"close":
			close()
		"edit":
			if res.has("scroll"):
				_load_list(res["scroll"])
			data["setting"] = res["id"]
			edit_requested.emit(res["id"])
	event.emit("intent", data)


func _load_list(scroll: Variant) -> void:
	var list: Array = nav.items()
	var texts: Array = []
	var icons: Array = []
	for it in list:
		texts.append(it.label())
		icons.append(it.icon)
	atlas.set_cells(texts, icons, "Назад" if nav.view == "browse" and not nav.multi else "Отмена")
	_refresh_codes()
	active.reset()
	var sf := surface()
	if scroll is Dictionary and scroll.get("__sig", "") == _surface_sig:
		sf.set_scroll(scroll["v"])
	else:
		sf.assign(list.size())
	event.emit("folder", {"folder": nav.state.folder(), "view": nav.view, "items": list.size()})


func _refresh_codes() -> void:
	var list: Array = nav.items()
	_codes.resize(list.size())
	_marks.resize(list.size())
	for i in list.size():
		var it: Item = list[i]
		_codes[i] = 10 if it.danger else int(it.kind)
		_marks[i] = 1 if nav.is_marked(i) else 0
	_list_version += 1


## Довернуть шар так, чтобы ячейка слота стала активной.
func _focus_slot(slot: int) -> void:
	var sf := surface()
	for c in sf.visible_cells():
		if int(c["slot"]) == slot:
			sf.apply_rotation(Quaternion(c["dir"], sf.front))
			active.reset()
			return
