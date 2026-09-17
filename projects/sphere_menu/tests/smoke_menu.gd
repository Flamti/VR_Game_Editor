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
##       --script res://tests/smoke_menu.gd [-- --falsify=scroll]
##
## Фальсификаторы:
##   --falsify=scroll      прокрутка панели теряет остаток доли пикселя — краснеет только
##                         «прокрутка панели» (медленный стик перестаёт двигать содержимое);
##   --falsify=editscroll  в окне прокрутки правки остаётся одно пояснение, как в шаге 1д, —
##                         краснеет только «прокрутка правки» (ползунок стоит на месте);
##   --falsify=panelshow   пустая ячейка считается содержимым (панель висит всегда) —
##                         краснеет только «панель по делу»;
##   --falsify=arrows      кнопки ▲/▼ возвращаются колонкой справа, поверх содержимого, —
##                         краснеет только «раскладка панели»;
##   --falsify=gestureboth настройка «Жест возврата» не слушается, живут оба детектора, —
##                         краснеет только «жест возврата»;
##   --falsify=imekey      панель не принимает клавиши системной клавиатуры — краснеет только
##                         «системная клавиатура»;
##   --falsify=enterclose  «Готово» системной клавиатуры закрывает поиск, как в сессии 7, —
##                         краснеет только «системная клавиатура».
## Пол — по числу исполненных шагов; ошибки выполнения печатаются движком, их
## ищет вызывающий по «SCRIPT ERROR».

const Report := preload("res://probe_report.gd")
const Menu := preload("res://menu/sphere_menu.gd")
const Panel3D := preload("res://menu/ui_panel.gd")
const SettingEdit := preload("res://menu/setting_edit.gd")
const Journal := preload("res://session/journal.gd")
const SettingsRes := preload("res://menu/settings.gd")
const Surface := preload("res://menu/surface.gd")
const Wizard := preload("res://menu/wizard.gd")

const STEPS := ["открыть", "войти коротким", "действия удержанием", "копировать", "вставить",
		"удалить удержанием", "отменить", "линза и захват", "панель и атлас", "мастер",
		"вращение рукой", "правка открыта", "ползунок лучом", "клавиатура лучом", "демонстрация доводки", "журнал", "назад на корне", "замок панели",
		"поиск на панели", "системная клавиатура", "плюс", "прокрутка панели", "прокрутка правки", "раскладка панели",
		"панель по делу", "страницы", "подписи большой папки", "жест возврата", "встряхивание", "раскладки", "выход удержанием"]

var r: Report = Report.new()
## Фальсификатор дымового прогона: --falsify=scroll снимает ограничение хода прокрутки.
var falsify := ""
var menu: Menu
var head: Node3D
var _frame := 0
var _t := 0
var _script: Array = []
var _done := false
var _demo_started := false
var _exit_asked := false
var _panel_buttons: Array[String] = []


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--falsify="):
			falsify = a.get_slice("=", 1)
	r.note("=== ДЫМОВОЙ ПРОГОН ШАР-МЕНЮ ===")
	if falsify != "":
		r.note("!!! ФАЛЬСИФИКАТОР «%s»: ожидается точечный отказ !!!" % falsify)
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
	menu.search_requested.connect(func(): panel.open_text("Поиск", ["done"], menu.settings.get_value("search_keyboard")))
	menu.search_closed.connect(func(): if panel.is_text_open(): panel.close_editor())
	panel.text_changed.connect(menu.set_search_query)
	panel.falsify_no_ime = falsify == "imekey"
	panel.falsify_enter_closes = falsify == "enterclose"
	panel.keyboard_dry_run = true       # в headless клавиатуры нет — считаем запросы
	panel.button.connect(func(n: String):
		_panel_buttons.append(n)
		# минимум main.gd: «Готово» закрывает поиск, «Клавиатура» показывает системную снова
		if panel.is_text_open() and n == "keyboard":
			panel.keyboard_again()
		elif panel.is_text_open() and n == "done":
			menu.back())
	menu.exit_requested.connect(func(): _exit_asked = true)
	_script = [
		[5, _open], [10, _enter], [20, _hold_actions], [60, _copy], [70, _paste],
		[90, _delete_hold], [140, _undo], [150, _lens_grab], [200, _panel_atlas], [210, _wizard], [215, _hand_modes], [220, _edit_open], [230, _edit_slider],
		[240, _edit_keypad], [250, _demo_start], [260, _demo_check], [265, _journal], [268, _root_back],
		[270, _panel_lock_open], [273, _panel_lock_a], [276, _panel_lock_b],
		[278, _search_open], [281, _search], [282, _ime_open], [283, _ime], [283, _plus],
		[285, _scroll_prep], [288, _scroll_read], [291, _scroll_check],
		[293, _edit_scroll_open], [296, _edit_scroll_move], [299, _edit_scroll_check],
		[301, _panel_layout_open], [304, _panel_layout], [307, _panel_show], [307, _pages], [307, _big_folder_labels], [306, _gesture_choice], [308, _shake_root],
		[310, _layouts], [314, _exit_hold], [320, _finish],
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
	if menu.is_open() and menu.nav.items().size() == 6 and menu.renderer.drawn >= 0:
		r.pass_("открыть: корень, %d объектов" % menu.nav.items().size())
	else:
		r.fail("открыть: открыт %s, объектов %d" % [menu.is_open(), menu.nav.items().size()])


func _enter() -> void:
	_tap(_key_of(_slot_of("files")))
	_tap(_key_of(_slot_of("assets")))
	if menu.nav.state.folder() == "assets":
		r.pass_("войти коротким: Файлы → «Ассеты»")
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
	var lt = menu.label_text
	if p.renders > 0 and lt.rebuilds > 0 and lt.icon("folder") != null:
		r.pass_("панель и атлас: панель перерисована %d, строки подписей собраны %d, иконки загружаются" % [p.renders, lt.rebuilds])
	else:
		r.fail("панель и атлас: панель %d, сборок подписей %d, иконка %s" % [p.renders, lt.rebuilds, lt.icon("folder")])


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


## «Назад» на корне закрывает шар целиком: не только состояние, но и вид. Сессия 2 на шлеме:
## состояние закрывалось, шар оставался висеть без обработки — прогон проверял is_open().
func _root_back() -> void:
	if not menu.is_open():
		menu.toggle()
	var guard := 0
	while menu.nav.state.folder() != "" and guard < 8:
		menu.back()
		guard += 1
	var back_cells := 0
	for c in menu.surface().render_cells():
		if int(c["slot"]) == Surface.SLOT_BACK:
			back_cells += 1
	menu.back()
	if back_cells == 0 and not menu.is_open() and not menu.visible and menu.renderer.drawn == 0 and not menu.panel.visible:
		r.pass_("назад на корне: ячейки «Назад» на корне нет; X закрывает — состояние, шар и панель скрыты, ячейки не рисуются")
	else:
		r.fail("назад на корне: ячеек «Назад» %d, открыто %s, шар виден %s, ячеек %d, панель видна %s" % [back_cells, menu.is_open(), menu.visible, menu.renderer.drawn, menu.panel.visible])


## Замок панели: помеха контроллера (указатель мимо панели) между нажатием и перетаскиванием
## проверки. Без замка ползунок обязан НЕ доехать — контроль, что помеха воспроизведена; с
## замком — доехать. Без контроля зелёный «с замком» ничего бы не доказывал (§1.5).
## Замок панели — три кадра: содержимое правки живёт в контейнере, а он раскладывает
## детей отложенно, и в кадре открытия прямоугольник ползунка ещё нулевой (тот же урок,
## что с клавиатурой поиска в сессии 11).
var _lock_got: Array[float] = []


func _panel_lock_open() -> void:
	menu.settings.values["radius_cm"] = 11.0
	menu.panel.open_editor(SettingEdit.new(menu.settings, "radius_cm"), "замок", ["done"])


## Перетаскивание ползунка лучом с помехой контроллера посередине.
func _lock_drag(lock: bool) -> float:
	var p: Panel3D = menu.panel
	menu.settings.values["radius_cm"] = 11.0
	p.synthetic_lock = lock
	var rect: Rect2 = p._slider.get_global_rect()
	var a: Variant = _aim(rect.position + Vector2(rect.size.x * 0.2, rect.size.y * 0.5))
	var b: Variant = _aim(rect.position + Vector2(rect.size.x * 0.8, rect.size.y * 0.5))
	p.pointer_update(a, false, "check")
	p.pointer_update(a, true, "check")
	p.pointer_update(null, false)          # кадр контроллера: луч мимо панели
	p.pointer_update(b, true, "check")
	p.pointer_update(b, false, "check")
	p.pointer_update(null, false, "check")
	p.synthetic_lock = false
	var got := float(menu.settings.get_value("radius_cm"))
	p.close_editor()
	return got


func _panel_lock_a() -> void:
	_lock_got.append(_lock_drag(false))
	menu.panel.open_editor(SettingEdit.new(menu.settings, "radius_cm"), "замок", ["done"])


func _panel_lock_b() -> void:
	_lock_got.append(_lock_drag(true))
	if _lock_got[0] < 15.0 and _lock_got[1] > 15.0:
		r.pass_("замок панели: без замка помеха контроллера сорвала перетаскивание (%s см), с замком — доехал (%s см)" % [_lock_got[0], _lock_got[1]])
	else:
		r.fail("замок панели: без замка %s см (помеха не воспроизведена, если > 15), с замком %s см" % [_lock_got[0], _lock_got[1]])


func _to_root_open() -> void:
	if not menu.is_open():
		menu.toggle()
	var guard := 0
	while (menu.nav.state.folder() != "" or menu.nav.view != "browse") and guard < 8:
		menu.back()
		guard += 1
	if not menu.is_open():
		menu.toggle()


## Поиск: короткое на «Поиск» открывает ввод на панели; «М», «О», «С», «Т» лучом —
## на шаре найденное; «Готово» закрывает поиск и ввод.
## Открытие — кадром раньше набора: клавиатура была скрыта, контейнер раскладывает кнопки
## отложенно, и в кадре открытия их прямоугольники ещё нулевые (первая версия шага
## попадала лучом «в панель», но не в кнопки).
func _search_open() -> void:
	menu.settings.values["search_keyboard"] = "panel"
	_to_root_open()
	_tap(_key_of(_slot_of("home_search")))


func _search() -> void:
	var p: Panel3D = menu.panel
	var opened: bool = p.is_text_open() and menu.nav.view == "search"
	var hits := []
	for k in ["М", "О", "С", "Т"]:
		var btn: Button = null
		for c in p._text_box.get_children():
			if (c as Button).text == k:
				btn = c
		var px: Variant = _aim(_center_px(btn))
		p.pointer_update(px, false)
		p.pointer_update(px, true)
		p.pointer_update(px, false)
		hits.append(px != null)
	p.pointer_update(null, false)
	var found: Array = menu.nav.items().slice(1).map(func(x): return x.id)
	menu.back()
	if opened and not hits.has(false) and found.size() >= 2 and found[0] == "asset_bridge" and not p.is_text_open() and menu.nav.view == "browse":
		r.pass_("поиск на панели: ввод открыт, «мост» лучом → %s, «Назад» закрыл поиск и ввод" % [found])
	else:
		r.fail("поиск на панели: открыт %s, попадания %s, найдено %s, ввод открыт %s, вид %s" % [opened, hits, found, p.is_text_open(), menu.nav.view])


## Подписи большой папки: «Много файлов» (128) на мелком глобусе — страниц нет, подпись у каждого
## пункта, номер строки данных = слот.
func _big_folder_labels() -> void:
	var saved: Dictionary = menu.settings.values.duplicate()
	menu.settings.values["surface"] = "globe"
	menu.settings.values["cell_cm"] = 1.5
	menu.apply_settings()
	_to_root_open()
	_tap(_key_of(_slot_of("files")))
	_tap(_key_of(_slot_of("bulk")))
	for _i in 5:
		menu._process(1.0 / 90.0)
	var labeled := 0
	var item_cells := 0
	var slot_rows := true
	for key in menu.renderer._where:
		var w: Array = menu.renderer._where[key]
		if int(w[3]) < 0:
			continue
		item_cells += 1
		var lr: float = (w[2] as Color).r
		if lr >= 0.0:
			labeled += 1
		if not is_equal_approx(lr, float(w[3])):
			slot_rows = false
	var pages: int = menu.nav.page_info()["pages"]
	menu.settings.values = saved
	menu.apply_settings()
	_to_root_open()
	if item_cells == 128 and labeled == 128 and slot_rows and pages == 1:
		r.pass_("подписи большой папки: 128 пунктов, у всех подпись, строка данных = слот, страниц 1")
	else:
		r.fail("подписи большой папки: пунктов %d, с подписью %d, строки = слоты %s, страниц %d" % [item_cells, labeled, slot_rows, pages])


## Страницы: «Много файлов» на глобусе радиуса 11 см с ячейкой 5 см (91 ячейка) — не помещается; «Дальше» открывает
## следующие пункты, «Раньше» возвращает первую страницу, панель на «Дальше» говорит, какие.
func _pages() -> void:
	var saved: Dictionary = menu.settings.values.duplicate()
	# Размеры явно: страниц делает только нехватка ячеек (подписей шейдером хватает на 1021), а
	# радиус 19.5 см от шага ползунка вмещал бы все 128 пунктов.
	menu.settings.values["surface"] = "globe"
	menu.settings.values["radius_cm"] = 11.0
	menu.settings.values["cell_cm"] = 5.0
	menu.apply_settings()
	_to_root_open()
	_tap(_key_of(_slot_of("files")))
	_tap(_key_of(_slot_of("bulk")))
	var p1: Array = menu.nav.items().map(func(x): return x.id)
	var had_next: bool = menu.nav.has_next()
	var next_key: Variant = _key_of(Surface.SLOT_NEXT)
	var text := menu.page_text(true)
	_tap(next_key)
	var p2: Array = menu.nav.items().map(func(x): return x.id)
	var prev_key: Variant = _key_of(Surface.SLOT_PREV)
	_tap(prev_key)
	var back1: Array = menu.nav.items().map(func(x): return x.id)
	var full: Array = menu.nav.full_items().map(func(x): return x.id)
	menu.settings.values = saved
	menu.apply_settings()
	_to_root_open()
	var ok: bool = had_next and next_key != null and prev_key != null and p1.size() < 128 \
			and p2.size() > 0 and p2[0] == full[p1.size()] and back1 == p1
	if ok:
		r.pass_("страницы: «Много файлов» на ячейке 5 см — на первой %d, «Дальше» → с «%s» (%d пунктов), «Раньше» вернула первую; панель: «%s»" % [p1.size(), p2[0], p2.size(), text])
	else:
		r.fail("страницы: «Дальше» было %s, ключи %s/%s, первая %d, вторая %s, возврат %s" % [had_next, next_key, prev_key, p1.size(), p2.slice(0, 2), back1 == p1])


## Системная клавиатура: IME приходит событиями клавиш в корневой вьюпорт
## (GodotTextInputWrapper.java) — символ unicode, стирание KEY_BACKSPACE, «Готово» KEY_ENTER.
## Набор «мостх», стирание, «Готово» — запрос «мост», на шаре «мост», панель отдала «done».
func _ime_open() -> void:
	menu.settings.values["search_keyboard"] = "system"
	_to_root_open()
	_tap(_key_of(_slot_of("home_search")))


func _ime() -> void:
	var p: Panel3D = menu.panel
	var opened: bool = p.is_text_open() and menu.nav.view == "search"
	# системный режим: раскладки на панели нет, есть «Клавиатура» и «Готово»
	var grid_hidden: bool = not p._text_box.visible
	var buttons: Array = p._buttons_box.get_children().filter(func(b): return (b as Button).visible).map(func(b): return (b as Button).text)
	for ch in "МОСТХ":
		var ev := InputEventKey.new()
		ev.pressed = true
		ev.unicode = ch.unicode_at(0)
		get_root().push_input(ev)
	var bs := InputEventKey.new()
	bs.pressed = true
	bs.keycode = KEY_BACKSPACE
	get_root().push_input(bs)
	_panel_buttons.clear()
	var enter := InputEventKey.new()
	enter.pressed = true
	enter.keycode = KEY_ENTER
	get_root().push_input(enter)
	# «Готово» клавиатуры: поиск, запрос и найденное остаются — выбирать после
	var still_open: bool = p.is_text_open() and menu.nav.view == "search"
	var query: String = menu.nav.search_query
	var found: Array = menu.nav.items().slice(1).map(func(x): return x.id)
	var after_enter := _panel_buttons.duplicate()
	var req0: int = p.keyboard_requests
	p.button.emit("keyboard")
	var again: int = p.keyboard_requests - req0
	if menu.nav.view == "search":
		menu.back()
	if opened and grid_hidden and buttons == ["Клавиатура", "Готово"] and still_open and query == "мост" \
			and found.size() >= 1 and found[0] == "asset_bridge" and after_enter.is_empty() and again == 1 and not p.is_text_open():
		r.pass_("системная клавиатура: раскладки нет, кнопки %s; «МОСТХ» и стирание → «%s», «Готово» клавиатуры оставил поиск и найденное %s; «Клавиатура» показала снова" % [buttons, query, found])
	else:
		r.fail("системная клавиатура: открыт %s, раскладка скрыта %s, кнопки %s, после «Готово» открыт %s, запрос «%s», найдено %s, кнопки панели %s, повторный показ %d" % [
				opened, grid_hidden, buttons, still_open, query, found, after_enter, again])


## «+» → Сцены → Лес: объект на корне перед «+».
func _plus() -> void:
	_to_root_open()
	_tap(_key_of(_slot_of("home_plus")))
	_tap(_key_of(_slot_of("scenes")))
	_tap(_key_of(_slot_of("scene_forest")))
	var home: Array = menu.nav.items().map(func(x): return x.id)
	if menu.nav.state.folder() == "" and home.find("scene_forest") == home.find("home_plus") - 1 and menu.renderer.drawn > 0:
		r.pass_("плюс: «+» → Сцены → Лес — на корне перед «+», шар перерисован")
	else:
		r.fail("плюс: папка «%s», корень %s" % [menu.nav.state.folder(), home])


## Каждая раскладка: применить, открыть, нарисовать — без ошибок, ячейки есть, «Назад» на корне нет.
func _layouts() -> void:
	_to_root_open()
	var out := []
	var ok := true
	for o in SettingsRes.SPEC["surface"]["options"]:
		menu.settings.values["surface"] = o[0]
		menu.settings.values["cell_cm"] = 4.0
		menu.apply_settings()
		menu.close()
		menu.toggle()
		menu._process(1.0 / 90.0)
		var cells: int = menu.renderer.drawn
		out.append("%s %d" % [o[0], cells])
		if cells <= 0:
			ok = false
	menu.settings.values["surface"] = "globe"
	menu.apply_settings()
	if ok:
		r.pass_("раскладки: %s" % ", ".join(out))
	else:
		r.fail("раскладки: %s" % ", ".join(out))


## Прокрутка панели тремя способами (решение владельца 2026-09-16). Содержимое задаётся
## напрямую: у демо-каталога длина подписи случайна, а проверке нужен заведомо длинный
## и заведомо короткий случай. Раскладка контейнера доходит до полос прокрутки не в
## кадре смены содержимого — отсюда три шага на разных кадрах.
var _scroll_short := {}


func _scroll_prep() -> void:
	menu.panel_locked = true
	menu.falsify_panel_always = falsify == "panelshow"
	menu.panel.falsify_no_frac = falsify == "scroll"
	menu.panel.show_text("Короткая", "", "одна строка", "")


func _scroll_read() -> void:
	var p: Panel3D = menu.panel
	_scroll_short = {"scrollable": p.scrollable(), "pointer": p.pointer_active(), "max": p.scroll_max()}
	var long := ""
	for i in 40:
		long += "строка %d описания объекта, которая должна уехать за нижний край панели\n" % i
	p.show_text("Длинная", "значение", long, "подсказка режима")


func _scroll_check() -> void:
	var p: Panel3D = menu.panel
	var top := p.scroll_max()
	# медленный стик: доли пикселя за кадр обязаны копиться, иначе панель не поедет вовсе
	for _i in 10:
		p.scroll_by(0.4)
	var slow := p.scroll_pos()
	var by_stick := p.scroll_by(300.0)
	var after_stick := p.scroll_pos()
	var by_page := p.scroll_page(1)
	var after_page := p.scroll_pos()
	# перетаскивание лучом: указатель ведёт содержимое за собой
	var a: Variant = _aim(Vector2(200, 420))
	var b: Variant = _aim(Vector2(200, 300))
	p.pointer_update(a, false)
	p.pointer_update(a, true)
	p.pointer_update(b, true)
	var after_drag := p.scroll_pos()
	p.pointer_update(b, false)
	p.pointer_update(null, false)
	p.scroll_by(10000.0)
	var at_end := p.scroll_pos()
	p.scroll_by(-10000.0)
	var at_start := p.scroll_pos()
	p.scroll_by(500.0)
	p.show_text("Другая", "", "смена содержимого", "")
	var after_change := p.scroll_pos()
	menu.panel.falsify_no_frac = false
	menu.panel_locked = false
	var bad: Array[String] = []
	if bool(_scroll_short["scrollable"]) or bool(_scroll_short["pointer"]):
		bad.append("короткое содержимое: прокрутка %s, указатель %s" % [_scroll_short["scrollable"], _scroll_short["pointer"]])
	if top <= 0:
		bad.append("длинное содержимое не прокручивается (ход %d)" % top)
	if slow < 3:
		bad.append("медленный стик: 10 шагов по 0,4 px дали %d px" % slow)
	if not by_stick or after_stick != slow + 300:
		bad.append("стик: сдвиг %s, положение %d при %d до него" % [by_stick, after_stick, slow])
	if not by_page or after_page <= after_stick:
		bad.append("кнопка ▼: сдвиг %s, положение %d" % [by_page, after_page])
	if after_drag <= after_page:
		bad.append("перетаскивание: %d → %d (попадания %s / %s)" % [after_page, after_drag, a, b])
	if at_end != top or at_start != 0:
		bad.append("края: низ %d при ходе %d, верх %d" % [at_end, top, at_start])
	if after_change != 0:
		bad.append("смена содержимого не сбросила прокрутку (%d)" % after_change)
	if bad.is_empty():
		r.pass_("прокрутка панели: ход %d px; медленный стик копит доли (%d px), стик → %d, кнопка ▼ → %d, перетаскивание → %d; упирается в оба края; смена содержимого сбрасывает; короткое содержимое указатель не берёт" % [
				top, slow, after_stick, after_page, after_drag])
	else:
		r.fail("прокрутка панели: %s" % "; ".join(bad))


## Прокрутка правки: едет ВСЁ содержимое, а не одно пояснение (отзыв сессии 4).
## Свидетель — прямоугольник ползунка: он обязан уехать ровно на ту же величину, на
## которую прокрутилось окно, а строка кнопок обязана остаться на месте. Кадры разные:
## и раскладка контейнера, и сдвиг прокрутки доходят до детей отложенно.
var _edit_before := {}


func _edit_scroll_open() -> void:
	var p: Panel3D = menu.panel
	p.falsify_hint_only = falsify == "editscroll"
	menu.panel_locked = true
	var e := SettingEdit.new(menu.settings, "radius_cm")
	# Длинное пояснение задаётся нарочно, и с запасом: у штатных подсказок длина на грани
	# высоты окна, а фальсификатору editscroll нужно, чтобы окно всё равно прокручивалось —
	# иначе он покраснел бы «ход 0», а не «ползунок стоит», то есть мерил бы не тот
	# сигнал (PRACTICES §2.6).
	e.message = "длинное пояснение, занимающее несколько строк подряд, ".repeat(14)
	p.open_editor(e, "прокрутка правки", ["default", "done"])


func _edit_scroll_move() -> void:
	var p: Panel3D = menu.panel
	_edit_before = {
		"span": p.scroll_max(),
		"slider": p._slider.get_global_rect().position,
		"footer": p._buttons_box.get_global_rect().position,
		"moved": p.scroll_by(float(mini(200, p.scroll_max()))),
		"at": 0,
	}
	_edit_before["at"] = p.scroll_pos()


func _edit_scroll_check() -> void:
	var p: Panel3D = menu.panel
	var at := int(_edit_before["at"])
	var slider_moved: float = float(_edit_before["slider"].y) - p._slider.get_global_rect().position.y
	var footer_moved: float = float(_edit_before["footer"].y) - p._buttons_box.get_global_rect().position.y
	var buttons_seen := p._up_btn.visible and p._down_btn.visible
	p.close_editor()
	menu.panel_locked = false
	var bad: Array[String] = []
	if int(_edit_before["span"]) <= 0:
		bad.append("правка не прокручивается (ход %d)" % int(_edit_before["span"]))
	if not bool(_edit_before["moved"]) or at <= 0:
		bad.append("прокрутка не сдвинулась (%s, %d)" % [_edit_before["moved"], at])
	if not is_equal_approx(slider_moved, float(at)):
		bad.append("ползунок уехал на %.1f px вместо %d — едет не всё содержимое" % [slider_moved, at])
	if not is_equal_approx(footer_moved, 0.0):
		bad.append("строка кнопок уехала на %.1f px — она обязана быть закреплена" % footer_moved)
	if not buttons_seen:
		bad.append("кнопки ▲/▼ в правке не показались")
	if bad.is_empty():
		r.pass_("прокрутка правки: ход %d px, окно на %d — ползунок уехал вместе с содержимым, строка кнопок закреплена, ▲/▼ видны" % [int(_edit_before["span"]), at])
	else:
		r.fail("прокрутка правки: %s" % "; ".join(bad))


## Раскладка панели (отзыв сессии 5: стрелки и подсказки перекрывали содержимое).
## Свидетели — прямоугольники: окно прокрутки во всю ширину, кнопки ▲/▼ с ним не
## пересекаются ни в одном режиме, подсказки выключены, стрелка у края погашена.
func _panel_layout_open() -> void:
	var p: Panel3D = menu.panel
	p.falsify_arrow_column = falsify == "arrows"
	menu.panel_locked = true
	var long := ""
	for i in 40:
		long += "строка %d описания объекта, которая должна уехать за нижний край панели\n" % i
	p.show_text("Раскладка", "значение", long, "подсказка")


## Мерится кадром позже: контейнер раскладывает детей отложенно, и в кадре смены
## содержимого ход прокрутки ещё нулевой — обе стрелки выглядели бы погашенными.
func _panel_layout() -> void:
	var p: Panel3D = menu.panel
	p.scroll_tick()
	var sc: ScrollContainer = p.active_scroll()
	var win := Rect2(sc.position, sc.size)
	var up := Rect2(p._up_btn.position, p._up_btn.size)
	var down := Rect2(p._down_btn.position, p._down_btn.size)
	var hints: int = sc.scroll_hint_mode
	var at_top := [p._up_btn.disabled, p._down_btn.disabled]
	p.scroll_by(200.0)
	p.scroll_tick()
	var middle := [p._up_btn.disabled, p._down_btn.disabled]
	p.scroll_by(10000.0)
	p.scroll_tick()
	var at_end := [p._up_btn.disabled, p._down_btn.disabled]
	p.show_text("", "", "", "")
	menu.panel_locked = false
	p.falsify_arrow_column = false
	var bad: Array[String] = []
	if win.intersects(up) or win.intersects(down):
		bad.append("кнопки лезут на содержимое: окно %s, ▲ %s, ▼ %s" % [win, up, down])
	if not is_equal_approx(win.size.x, 480.0):
		bad.append("окно не во всю ширину: %.0f px" % win.size.x)
	if hints != ScrollContainer.SCROLL_HINT_MODE_DISABLED:
		bad.append("подсказки поверх содержимого включены (режим %d)" % hints)
	if at_top != [true, false] or middle != [false, false] or at_end != [false, true]:
		bad.append("гашение стрелок: наверху %s, посередине %s, внизу %s" % [at_top, middle, at_end])
	if bad.is_empty():
		r.pass_("раскладка панели: окно %.0f×%.0f, кнопки ▲ %s и ▼ %s вне его, подсказки выключены, у краёв гаснет своя стрелка" % [
				win.size.x, win.size.y, up.position, down.position])
	else:
		r.fail("раскладка панели: %s" % "; ".join(bad))


## Настройка «Жест возврата» выбирает, какие детекторы живут.
func _gesture_choice() -> void:
	menu.falsify_gestures_always = falsify == "gestureboth"
	var got := {}
	for mode in ["off", "shake", "swipe", "both"]:
		menu.settings.values["return_gesture"] = mode
		menu.apply_settings()
		got[mode] = [menu.shake.enabled, menu.swipe.enabled]
	menu.settings.values["gesture_cm"] = 10.0
	menu.apply_settings()
	var span := [menu.shake.travel, menu.swipe.distance]
	menu.settings.values["return_gesture"] = "both"
	menu.settings.values["gesture_cm"] = SettingsRes.SPEC["gesture_cm"]["default"]
	menu.falsify_gestures_always = false
	menu.apply_settings()
	var want := {"off": [false, false], "shake": [true, false], "swipe": [false, true], "both": [true, true]}
	var bad: Array[String] = []
	for mode in want:
		if got[mode] != want[mode]:
			bad.append("«%s» дал %s вместо %s" % [mode, got[mode], want[mode]])
	if not is_equal_approx(span[0], 0.10) or not is_equal_approx(span[1], 0.30):
		bad.append("размах 10 см дал встряхивание %.3f м и взмах %.3f м" % [span[0], span[1]])
	if bad.is_empty():
		r.pass_("жест возврата: выкл — ни одного, встряхивание и взмах — только свой, оба — оба; размах 10 см → путь 0,10 м и взмах 0,30 м (упор)")
	else:
		r.fail("жест возврата: %s" % "; ".join(bad))


## Панель появляется, только когда есть что показывать (решение владельца, сессия 4).
func _panel_show() -> void:
	var p: Panel3D = menu.panel
	_to_root_open()
	var slot := _slot_of("files")
	var on_item := _panel_state(_key_of(slot))
	var empty_key: Variant = _empty_key()
	var on_empty_now := _panel_state(empty_key)
	# удержание: сразу после ухода объекта панель ещё видна, после PANEL_HOLD_MS — нет
	var on_empty_later := _panel_state(empty_key, Menu.PANEL_HOLD_MS + 50)
	var pointer_hidden := p.pointer_active()
	menu.panel_locked = true
	p.open_editor(SettingEdit.new(menu.settings, "radius_cm"), "сценарий", ["done"])
	var in_editor := _panel_state(empty_key)
	p.close_editor()
	menu.panel_locked = false
	menu.close()
	menu._update_panel(_t)
	var when_closed := p.visible
	menu.toggle()
	var bad: Array[String] = []
	if not on_item:
		bad.append("на объекте панель скрыта")
	if not on_empty_now:
		bad.append("панель погасла сразу, без удержания")
	if on_empty_later:
		bad.append("панель не погасла на пустой ячейке через %d мс" % Menu.PANEL_HOLD_MS)
	if pointer_hidden:
		bad.append("спрятанная панель берёт указатель")
	if not in_editor:
		bad.append("в правке панель скрыта")
	if when_closed:
		bad.append("при закрытом шаре панель видна")
	if bad.is_empty():
		r.pass_("панель по делу: на объекте видна, на пустой ячейке держится %d мс и гаснет, указатель не берёт; в правке видна; закрытый шар гасит" % Menu.PANEL_HOLD_MS)
	else:
		r.fail("панель по делу: %s" % "; ".join(bad))


## Ключ пустой ячейки (без пункта) среди видимых.
func _empty_key() -> Variant:
	for c in menu.surface().render_cells():
		if int(c["slot"]) == Surface.SLOT_EMPTY:
			return c["key"]
	return null


## Навести на ключ, прокрутить время на ms и вернуть видимость панели.
func _panel_state(key: Variant, ms: int = 0) -> bool:
	menu.hover_key = key
	menu._update_panel(_t)
	_t += ms
	menu.hover_key = key
	menu._update_panel(_t)
	return menu.panel.visible


## Встряхивание шара из вложенной папки: меню возвращается на верхний уровень и
## остаётся открытым. Контроль — то же расстояние, пройденное ровно, без разворотов.
func _shake_root() -> void:
	_to_root_open()
	_tap(_key_of(_slot_of("files")))
	_tap(_key_of(_slot_of("assets")))
	var deep := menu.nav.state.folder()
	var head := menu.head.global_position
	var calm := _shake_trace(head, 1.0, 0.0, 0.0, 0.25)
	var after_calm := menu.nav.state.folder()
	var shaken := _shake_trace(head, 1.2, 0.09, 3.0, 0.0)
	if deep == "assets" and after_calm == "assets" and menu.nav.state.folder() == "" \
			and menu.is_open() and shaken and not calm:
		r.pass_("встряхивание: из «assets» шар вернулся на верхний уровень и остался открыт; ровный перенос руки — нет")
	else:
		r.fail("встряхивание: было %s, после переноса %s, после встряхивания %s, открыт %s (жест: перенос %s, тряска %s)" % [
				deep, after_calm, menu.nav.state.folder(), menu.is_open(), calm, shaken])


## Кормит детектор трассой руки; true — жест сработал хотя бы раз.
func _shake_trace(head: Vector3, seconds: float, amp: float, freq: float, carry: float) -> bool:
	var dt := 1.0 / 90.0
	var fired := false
	var before := menu.nav.state.folder()
	for i in int(seconds / dt):
		var t := i * dt
		var win := clampf(minf(t / 0.15, (seconds - t) / 0.15), 0.0, 1.0)
		var x := carry * t + amp * sin(TAU * freq * t) * win
		menu.gesture_update(head + Vector3(0.10 + x, -0.45, -0.25), Transform3D(Basis(), head), dt)
		if menu.nav.state.folder() != before:
			fired = true
	return fired


## «Выход»: короткое не выходит, удержание до конца кольца — сигнал выхода.
func _exit_hold() -> void:
	_to_root_open()
	var key: Variant = _key_of(_slot_of("home_exit"))
	_tap(key)
	var after_short := _exit_asked
	_hold(key, 800)
	if not after_short and _exit_asked:
		r.pass_("выход удержанием: короткое не выходит, удержание — запрос выхода")
	else:
		r.fail("выход удержанием: после короткого %s, после удержания %s" % [after_short, _exit_asked])


func _finish() -> void:
	var total := r.executed()
	r.note("passed=%d failed=%d unknown=%d" % [r.passed, r.failed, r.unknown])
	if total != STEPS.size():
		r.note("ОТКАЗ ПРИБОРА: исполнено %d шагов из %d" % [total, STEPS.size()])
	else:
		r.note("пол: исполнено %d/%d шагов" % [total, STEPS.size()])
	_done = true
