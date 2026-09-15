extends SceneTree

## Дымовой прогон интеграции шар-меню без XR (Ф2, шаг 1б).
##
## Настольные проверки (run_tests.gd) исполняют модель, но не сборку: меню,
## рендер, атлас, панель, нажатия, захват. Ошибки выполнения GDScript в сборке
## видны только при запуске — здесь они ловятся до шлема. Рендерер пустой
## (--headless), поэтому проверяется поведение и отсутствие ошибок, а не картинка.
##
## Запуск:
##   godot/bin/godot.linuxbsd.editor.x86_64 --headless --path projects/sphere_menu \
##       --script res://tests/smoke_menu.gd
## Пол — по числу исполненных шагов; ошибки выполнения печатаются движком, их
## ищет вызывающий по «SCRIPT ERROR».

const Report := preload("res://probe_report.gd")
const Menu := preload("res://menu/sphere_menu.gd")
const Panel3D := preload("res://menu/ui_panel.gd")
const SettingEdit := preload("res://menu/setting_edit.gd")
const Journal := preload("res://session/journal.gd")
const Surface := preload("res://menu/surface.gd")
const Wizard := preload("res://menu/wizard.gd")

const STEPS := ["открыть", "войти коротким", "действия удержанием", "копировать", "вставить",
		"удалить удержанием", "отменить", "линза и захват", "панель и атлас", "мастер",
		"вращение рукой", "правка открыта", "ползунок лучом", "клавиатура лучом", "демонстрация доводки", "журнал"]

var r: Report = Report.new()
var menu: Menu
var head: Node3D
var _frame := 0
var _t := 0
var _script: Array = []
var _done := false
var _demo_started := false


func _initialize() -> void:
	r.note("=== ДЫМОВОЙ ПРОГОН ШАР-МЕНЮ ===")
	r.note("ожидается шагов: %d" % STEPS.size())
	var root3d := Node3D.new()
	get_root().add_child(root3d)
	head = Node3D.new()
	head.position = Vector3(0, 0, 0.4)
	root3d.add_child(head)
	menu = Menu.new()
	menu.head = head
	# Настройки прогона — только в памяти: файл пользователя не трогаем.
	root3d.add_child(menu)
	var panel := Panel3D.new()
	root3d.add_child(panel)
	menu.panel = panel
	# Минимум сессии (main.gd): правка настройки на панели и применение на ходу.
	menu.edit_requested.connect(func(id: String):
		menu.panel_locked = true
		panel.open_editor(SettingEdit.new(menu.settings, id), id, ["default", "done"]))
	panel.edit_changed.connect(menu.apply_settings)
	_script = [
		[5, _open], [10, _enter], [20, _hold_actions], [60, _copy], [70, _paste],
		[90, _delete_hold], [140, _undo], [150, _lens_grab], [200, _panel_atlas], [210, _wizard], [215, _hand_modes], [220, _edit_open], [230, _edit_slider],
		[240, _edit_keypad], [250, _demo_start], [260, _demo_check], [265, _journal], [270, _finish],
	]


## Предел кадров: ошибка в сборке (скрипт не скомпилировался, шаг упал) не должна
## вешать прогон навсегда — 2026-09-15 он простоял 300 с на ошибке разбора.
const MAX_FRAMES := 1200


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame > MAX_FRAMES and not _done:
		r.note("ОТКАЗ ПРИБОРА: предел %d кадров, исполнено %d шагов из %d" % [MAX_FRAMES, r.executed(), STEPS.size()])
		_done = true
		return true
	_t += 16
	while not _script.is_empty() and _script[0][0] <= _frame:
		var step: Array = _script.pop_front()
		(step[1] as Callable).call()
	return _done


func _slot_of(id: String) -> int:
	var list: Array = menu.nav.items()
	for i in list.size():
		if list[i].id == id:
			return i
	return -1


func _action_slot(action: String) -> int:
	var list: Array = menu.nav.items()
	for i in list.size():
		if list[i].action == action:
			return i
	return -1


func _key_of(slot: int) -> Variant:
	for c in menu.surface().render_cells():
		if int(c["slot"]) == slot:
			return c["key"]
	return null


## Короткое нажатие правым курком на ключе.
func _tap(key: Variant) -> void:
	menu.press_key(key, true, _t)
	menu.press_key(key, false, _t + 100)
	_t += 200


## Удержание правым курком на ключе дольше порога.
func _hold(key: Variant, ms: int) -> void:
	for dt in range(0, ms + 50, 50):
		menu.press_key(key, true, _t + dt)
	menu.press_key(key, false, _t + ms + 100)
	_t += ms + 200


func _open() -> void:
	menu.toggle()
	if menu.is_open() and menu.nav.items().size() == 5 and menu.renderer.drawn >= 0:
		r.pass_("открыть: корень, %d объектов" % menu.nav.items().size())
	else:
		r.fail("открыть: открыт %s, объектов %d" % [menu.is_open(), menu.nav.items().size()])


func _enter() -> void:
	_tap(_key_of(_slot_of("assets")))
	if menu.nav.state.folder() == "assets":
		r.pass_("войти коротким: папка «Ассеты»")
	else:
		r.fail("войти коротким: папка «%s»" % menu.nav.state.folder())


func _hold_actions() -> void:
	_hold(_key_of(_slot_of("asset_bridge")), 600)
	if menu.nav.view == "actions" and menu.nav.item_at(0).id == "asset_bridge":
		r.pass_("действия удержанием: объект в центре, %d действий" % (menu.nav.items().size() - 1))
	else:
		r.fail("действия удержанием: вид %s" % menu.nav.view)


func _copy() -> void:
	_tap(_key_of(_action_slot("copy")))
	if menu.nav.view == "browse" and not menu.nav.clipboard.is_empty():
		r.pass_("копировать: в буфере, возврат к списку")
	else:
		r.fail("копировать: вид %s, буфер %s" % [menu.nav.view, menu.nav.clipboard])


func _paste() -> void:
	_hold(_key_of(Surface.SLOT_BACK), 600)   # удержание на «Назад» — действия папки
	var s := _action_slot("paste")
	var before: int = (menu.catalog.children_of["assets"] as Array).size()
	_tap(_key_of(s))
	var after: int = (menu.catalog.children_of["assets"] as Array).size()
	if s >= 0 and after == before + 1:
		r.pass_("вставить: удержание на «Назад» открыло действия папки, копия вставлена")
	else:
		r.fail("вставить: слот %d, объектов %d→%d, вид %s" % [s, before, after, menu.nav.view])


func _delete_hold() -> void:
	_hold(_key_of(_slot_of("asset_barrel")), 600)
	var ds := _action_slot("delete")
	_tap(_key_of(ds))
	var still: bool = menu.catalog.items.has("asset_barrel")
	_hold(_key_of(ds), 800)
	if still and not menu.catalog.items.has("asset_barrel"):
		r.pass_("удалить удержанием: короткое не удалило, удержание до конца кольца — удалило")
	else:
		r.fail("удалить удержанием: после короткого %s, после удержания %s" % [still, menu.catalog.items.has("asset_barrel")])


func _undo() -> void:
	menu.undo()
	if menu.catalog.items.has("asset_barrel"):
		r.pass_("отменить: «Бочка» вернулась")
	else:
		r.fail("отменить: «Бочки» нет")


func _lens_grab() -> void:
	menu.settings.values["surface"] = "lens"
	menu.apply_settings()
	var sf: RefCounted = menu.surface()
	var tip0: Vector3 = menu.global_transform * (sf.front * menu.radius())
	var before_offset: Vector2 = sf.offset
	menu.grab_update(tip0, true, 1.0 / 90.0)
	var tip1: Vector3 = menu.global_transform * ((sf.front + Vector3(0.3, 0, 0)).normalized() * menu.radius())
	menu.grab_update(tip1, true, 1.0 / 90.0)
	menu.grab_update(tip1, false, 1.0 / 90.0)
	if menu.touching and sf.offset != before_offset:
		r.pass_("линза и захват: касание распознано, захват сдвинул содержимое")
	else:
		r.fail("линза и захват: касание %s, сдвиг %s→%s" % [menu.touching, before_offset, sf.offset])


func _panel_atlas() -> void:
	var p: Panel3D = menu.panel
	if p.renders > 0 and menu.atlas.renders > 0 and menu.atlas.icon("folder") != null:
		r.pass_("панель и атлас: панель перерисована %d, атлас %d, иконки загружаются" % [p.renders, menu.atlas.renders])
	else:
		r.fail("панель и атлас: панель %d, атлас %d, иконка %s" % [p.renders, menu.atlas.renders, menu.atlas.icon("folder")])


func _wizard() -> void:
	var wz := Wizard.new(menu.settings)
	menu.settings.values["surface"] = "globe"
	wz.note_change()
	menu.apply_settings()
	wz.confirm()
	if wz.index == 1 and menu.is_open():
		r.pass_("мастер: шаг применён к живому шару без ошибок")
	else:
		r.fail("мастер: шаг %d, открыт %s" % [wz.index, menu.is_open()])


## Три режима вращения рукой на живом меню: кадры прогоняются вручную, рука —
## узел с наклоном (тангаж + крен), затем с поворотом вокруг вертикали.
func _hand_modes() -> void:
	var hand := Node3D.new()
	head.get_parent().add_child(hand)
	hand.position = Vector3(0, -0.2, 0)
	menu.hand = hand
	menu.hand_offset = Vector3(0, 0.06, -0.1)
	var out := {}
	for mode in ["ball", "stand", "face"]:
		menu.settings.values["hand_rotation"] = mode
		menu.settings.values["hand_smoothing"] = 0.5
		menu.apply_settings()
		hand.quaternion = Quaternion.IDENTITY
		menu._process(1.0 / 90.0)
		var q0: Quaternion = menu.global_basis.get_rotation_quaternion()
		hand.quaternion = Quaternion(Vector3.RIGHT, 0.5) * Quaternion(Vector3.BACK, 0.3)
		for _i in 90:
			menu._process(1.0 / 90.0)
		var tilt_d: float = menu.global_basis.get_rotation_quaternion().angle_to(q0)
		hand.quaternion = Quaternion(Vector3.UP, 0.7)
		for _i in 90:
			menu._process(1.0 / 90.0)
		var yaw_d: float = menu.global_basis.get_rotation_quaternion().angle_to(q0)
		var to_head: float = (menu.global_basis * Vector3.BACK).angle_to(head.global_position - menu.global_position)
		out[mode] = [tilt_d, yaw_d, to_head]
	menu.hand = null
	hand.queue_free()
	var b: Array = out["ball"]
	var st: Array = out["stand"]
	var fc: Array = out["face"]
	if b[0] > 0.4 and st[0] < 0.01 and absf(st[1] - 0.7) < 0.01 and fc[2] < 0.01:
		r.pass_("вращение рукой: шар повернулся за наклоном %.2f рад; подставка — наклон %.3f, курс %.3f; лицом к шлему — отклонение %.3f рад" % [b[0], st[0], st[1], fc[2]])
	else:
		r.fail("вращение рукой: %s" % str(out))


## Короткими нажатиями: Настройки → Шар-меню → Радиус — панель в режиме правки.
func _edit_open() -> void:
	# Меню открывается в последней папке; «Назад» на корне закрывает — идём назад до корня.
	if not menu.is_open():
		menu.toggle()
	var guard := 0
	while menu.nav.state.folder() != "" and guard < 8:
		menu.back()
		guard += 1
	for id in ["settings", "settings_sphere", "set_radius_cm"]:
		_tap(_key_of(_slot_of(id)))
	var p: Panel3D = menu.panel
	if p.interactive() and p.edit != null and p.edit.id == "radius_cm":
		r.pass_("правка открыта: короткое на «Радиус шара» открыло правку на панели")
	else:
		r.fail("правка открыта: панель %s, правка %s, папка %s" % [p.interactive(), p.edit.id if p.edit != null else null, menu.nav.state.folder()])


## Луч из точки перед панелью в пиксель вьюпорта.
func _aim(px: Vector2) -> Variant:
	var p: Panel3D = menu.panel
	var local := Vector3((px.x / Panel3D.VIEW_SIZE.x - 0.5) * Panel3D.QUAD.x, (0.5 - px.y / Panel3D.VIEW_SIZE.y) * Panel3D.QUAD.y, 0.0)
	var world := p.global_transform * local
	var origin := world + p.global_basis.z * 0.3
	return p.pointer_ray(origin, (world - origin).normalized())


func _center_px(c: Control) -> Vector2:
	return c.get_global_rect().get_center()


func _edit_slider() -> void:
	var p: Panel3D = menu.panel
	var before: float = float(menu.settings.get_value("radius_cm"))
	var rect: Rect2 = p._slider.get_global_rect()
	var a: Variant = _aim(rect.position + Vector2(rect.size.x * 0.3, rect.size.y * 0.5))
	var b: Variant = _aim(rect.position + Vector2(rect.size.x * 0.9, rect.size.y * 0.5))
	p.pointer_update(a, false)
	p.pointer_update(a, true)
	p.pointer_update(b, true)
	p.pointer_update(b, false)
	p.pointer_update(null, false)
	var after: float = float(menu.settings.get_value("radius_cm"))
	if a != null and b != null and after > 17.0 and not is_equal_approx(after, before) and is_equal_approx(menu.radius(), after / 100.0):
		r.pass_("ползунок лучом: перетаскивание 30%% → 90%% шкалы, радиус %.1f → %.1f см, шар применил" % [before, after])
	else:
		r.fail("ползунок лучом: пиксели %s → %s, радиус %.1f → %.1f, у шара %.3f м" % [a, b, before, after, menu.radius()])


func _edit_keypad() -> void:
	var p: Panel3D = menu.panel
	var pressed := []
	for k in ["1", "3", ",", "5", "OK"]:
		var btn: Button = null
		for c in p._number_box.get_child(p._number_box.get_child_count() - 1).get_children():
			if (c as Button).text == k:
				btn = c
		var px: Variant = _aim(_center_px(btn))
		p.pointer_update(px, false)
		p.pointer_update(px, true)
		p.pointer_update(px, false)
		pressed.append(px != null)
	p.pointer_update(null, false)
	var v: float = float(menu.settings.get_value("radius_cm"))
	if is_equal_approx(v, 13.5) and not pressed.has(false):
		r.pass_("клавиатура лучом: «13,5» OK → радиус 13,5 см")
	else:
		r.fail("клавиатура лучом: попадания %s, радиус %.2f, поле «%s»" % [pressed, v, p._e_value.text])


func _demo_start() -> void:
	menu.panel.close_editor()
	menu.panel_locked = false
	menu.settings.values["detent"] = 14.0
	menu.apply_settings()
	_demo_started = menu.start_demo("detent")


## 2.6 с кадров по 1/90 вручную: безголовый цикл идёт без ограничения частоты, и
## настоящий delta кадра — доли миллисекунды (первая версия ждала кадрами и не дождалась).
## Пауза перед доводкой (DETENT_IDLE_MS) меряется реальными часами — после увода шара
## (0.3 с демонстрации) выжидается по-настоящему.
func _demo_check() -> void:
	for _i in 30:
		menu._process(1.0 / 90.0)
	OS.delay_msec(Menu.DETENT_IDLE_MS + 50)
	for _i in 204:
		menu._process(1.0 / 90.0)
	var err: float = menu.surface().snap_error()
	if _demo_started and not menu.demo.running() and err < 0.01:
		r.pass_("демонстрация доводки: цикл закончен, остаток до центра ячейки %.4f рад" % err)
	else:
		r.fail("демонстрация доводки: запущена %s, идёт %s, остаток %.4f рад" % [_demo_started, menu.demo.running(), err])


## Строка журнала несёт параметры живого меню: колонки не пустые и по числу совпадают.
func _journal() -> void:
	var line := Journal.row("проверка", menu.params(), "", "", -1, "x")
	var cells := line.split("\t")
	var radius_col := Journal.COLUMNS.find("радиус_см")
	if cells.size() == Journal.COLUMNS.size() and cells[radius_col] == str(menu.settings.get_value("radius_cm")) \
			and cells[Journal.COLUMNS.find("поверхность")] != "":
		r.pass_("журнал: %d колонок, радиус %s, поверхность %s" % [cells.size(), cells[radius_col], cells[2]])
	else:
		r.fail("журнал: колонок %d из %d, строка «%s»" % [cells.size(), Journal.COLUMNS.size(), line])


func _finish() -> void:
	var total := r.executed()
	r.note("passed=%d failed=%d unknown=%d" % [r.passed, r.failed, r.unknown])
	if total != STEPS.size():
		r.note("ОТКАЗ ПРИБОРА: исполнено %d шагов из %d" % [total, STEPS.size()])
	else:
		r.note("пол: исполнено %d/%d шагов" % [total, STEPS.size()])
	_done = true
