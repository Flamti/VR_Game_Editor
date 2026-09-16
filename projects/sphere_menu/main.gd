extends Node3D

## Прототип шар-меню, Ф2 шаг 1в: запуск, самопроверка, мастер настройки, работа.
##
## Порядок: XR-вьюпорт → прогрев в XR-формате → 90 Гц → самопроверка → мастер
## (если настроек ещё нет) → работа. Всё пишется в user://sphere_session.tsv.

const ProbeBudget := preload("res://probe_budget.gd")
const Menu := preload("res://menu/sphere_menu.gd")
const Controllers := preload("res://input/controller_source.gd")
const Journal := preload("res://session/journal.gd")
const SelfCheck := preload("res://session/selfcheck.gd")
const Item := preload("res://menu/item.gd")
const Settings := preload("res://menu/settings.gd")
const Wizard := preload("res://menu/wizard.gd")
const UiPanel := preload("res://menu/ui_panel.gd")
const SettingEdit := preload("res://menu/setting_edit.gd")
const Demo := preload("res://menu/demo.gd")
const Goldberg := preload("res://menu/goldberg.gd")
const Export := preload("res://session/export.gd")

## Шар над ладонью левого контроллера, в его координатах (поза grip).
const BALL_OFFSET := Vector3(0.0, 0.06, -0.10)
## Задания мастера: на каждом шаге — что найти, чтобы почувствовать настройку.
const WIZARD_TASKS := ["Дуб", "Карта", "Замок", "Фонарь", "Таймер", "Небо", "Пещера", "Мост", "Горы", "Дверь"]

@onready var origin: XROrigin3D = $XROrigin3D
@onready var camera: XRCamera3D = $XROrigin3D/XRCamera3D
@onready var left: XRController3D = $XROrigin3D/LeftHand
@onready var right: XRController3D = $XROrigin3D/RightHand

var menu: Menu
var panel: UiPanel
## Правка настройки из папки настроек (не мастер); null — не идёт.
var editing: SettingEdit = null
## Строки последней самопроверки — в выгрузку при выходе.
var selfcheck_lines: Array = []
var controllers: Controllers
var journal: Journal = Journal.new()
var task_label: Label3D
var wizard: Wizard = null
var _tasks: Array = []
var _task_id := ""
var _task_title := ""
var _task_ms := 0


func _ready() -> void:
	var vp := get_viewport()
	var iface := XRServer.find_interface("OpenXR")
	if iface != null and iface.is_initialized():
		vp.use_xr = true
	# MSAA 2x задан в project.godot (формат кадра при загрузке); здесь только проверка.
	if vp.msaa_3d != Viewport.MSAA_2X:
		push_warning("MSAA 3D = %d, ожидался 2x из project.godot" % vp.msaa_3d)

	menu = Menu.new()
	menu.head = camera
	menu.hand = left
	menu.hand_offset = BALL_OFFSET
	var had_settings := Settings.exists()
	menu.settings.load_from()
	# Не ребёнок контроллера: ориентацию задаёт следование за рукой (menu/hand_follow.gd).
	add_child(menu)
	panel = UiPanel.new()
	add_child(panel)
	panel.visible = false
	menu.panel = panel
	menu.event.connect(_on_menu_event)
	menu.wizard_requested.connect(start_wizard)
	menu.tasks_changed.connect(_on_tasks)
	menu.edit_requested.connect(start_edit)
	menu.search_requested.connect(_on_search_requested)
	menu.search_closed.connect(_on_search_closed)
	menu.exit_requested.connect(_exit_app)
	panel.text_changed.connect(_on_search_text)
	menu.catalog.load_favorites()
	panel.edit_changed.connect(_on_edit_changed)
	panel.button.connect(_on_panel_button)

	controllers = Controllers.new()
	add_child(controllers)
	controllers.setup(left, right, menu, self)
	controllers.panel = panel
	controllers.next_task.connect(_next_task)

	task_label = Label3D.new()
	task_label.font_size = 48
	task_label.pixel_size = 0.001
	task_label.outline_size = 12
	task_label.no_depth_test = true
	task_label.modulate = Color(1, 1, 0.7)
	add_child(task_label)
	task_label.text = "Самопроверка…"
	_place_task_label()

	journal.open()
	_prepare_tasks()

	await _warm_in_xr()
	var res: Dictionary = await ProbeBudget.request_target(self)
	print("частота: запрошено %.0f, получено %.1f (%s)" % [res["requested"], res["got"], res["outcome"]])
	for _i in 10:
		await get_tree().process_frame
	var saved := menu.settings.values.duplicate()
	var check := SelfCheck.new()
	var ok: bool = await check.run(self, menu)
	journal.log("самопроверка", menu.params(), "", "PASS" if ok else "FAIL", -1, str(check.results))
	selfcheck_lines = check.r.lines.duplicate()
	# Самопроверка гоняет худшие раскладки — возвращаются настройки человека.
	menu.settings.values = saved
	menu.apply_settings()
	if had_settings:
		_show_help()
	else:
		start_wizard()


func _show_help() -> void:
	task_label.text = "Y — шар · курок — открыть · удержание — действия · X — назад · встряхнуть — верхний уровень\nправый: луч или касание + курок · касание + грип — вращать · B — отменить · стик — прокрутка панели\nнастройки — лучом по панели: ползунок, кнопки, цифры"
	_place_task_label()


## Прогрев в том формате кадра, которым рисуется меню: XR-вьюпорт с multiview и
## MSAA. На несколько кадров перед лицом — ячейки, панель и луч: у луча и плашки
## материалы раньше создавались в коде и компилировались в кадре первого
## открытия (самопроверка 2026-09-15, surface 2).
func _warm_in_xr() -> void:
	var warm: Node3D = $CellWarm
	for mmi in [warm.get_node("Hex"), warm.get_node("Pent"), warm.get_node("Quad"), warm.get_node("Hept")]:
		(mmi as MultiMeshInstance3D).multimesh.set_instance_transform(0,
				Transform3D(Basis().scaled(Vector3.ONE * 0.01), Vector3.ZERO))
		(mmi as MultiMeshInstance3D).visible = true
	panel.visible = true
	# редактор панели (ползунок, кнопки, клавиатура) — свои 2D-материалы вьюпорта
	panel.open_editor(SettingEdit.new(menu.settings, "radius_cm"), "", ["back", "default", "demo", "next"])
	controllers.ray.visible = true
	for _i in 6:
		var p := camera.global_position - camera.global_basis.z * 1.0
		warm.global_position = p
		panel.global_position = p + camera.global_basis.x * 0.02
		await get_tree().process_frame
	for mmi in [warm.get_node("Hex"), warm.get_node("Pent"), warm.get_node("Quad"), warm.get_node("Hept")]:
		(mmi as MultiMeshInstance3D).visible = false
	panel.close_editor()
	panel.visible = false
	controllers.ray.visible = false


func _place_task_label() -> void:
	var fwd := -camera.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3.FORWARD
	task_label.global_position = camera.global_position + fwd * 1.5 + Vector3(0, 0.25, 0)
	task_label.look_at(task_label.global_position + fwd, Vector3.UP)


# --- мастер и правка настроек ---------------------------------------------------
#
# Значения меняются только на панели (шаг 1в): ползунок, −/+, цифры, варианты.
# Шар живой — изменение применяется на ходу, демонстрация показывает эффект.

func wizard_active() -> bool:
	return wizard != null and not wizard.done


func start_wizard() -> void:
	if editing != null:
		_finish_edit()
	wizard = Wizard.new(menu.settings)
	menu.panel_locked = true
	if not menu.is_open():
		menu.toggle()
	task_label.text = "Мастер настройки: лучом правого контроллера по панели — ползунок, кнопки, цифры"
	_place_task_label()
	journal.log("мастер_старт", menu.params())
	_wizard_show()


func _wizard_show() -> void:
	var steps := wizard.steps()
	var id := wizard.current()
	var n := "%d/%d" % [wizard.index + 1, steps.size()]
	if id == Wizard.SUMMARY:
		panel.open_summary("Мастер %s — итог" % n, wizard.summary_lines(), ["back", "save"])
		return
	var buttons := ["back", "default"]
	if Demo.supports(id):
		buttons.append("demo")
	buttons.append("next")
	panel.open_editor(SettingEdit.new(menu.settings, id), "Мастер %s — %s" % [n, Settings.SPEC[id]["title"]],
			buttons, _note_for.bind(id))
	if Demo.supports(id):
		menu.start_demo(id)


## Пояснение под значением: у размера ячейки глобуса — фактический размер сетки,
## у сглаживания в режиме «лицом к шлему» — что рука шар не вращает.
func _note_for(id: String) -> String:
	var st := menu.settings
	match id:
		"cell_cm":
			if not st.is_lens():
				return "у сетки: %s см, %d ячеек" % [Settings.format_number("cell_cm", st.actual_cell_cm()),
						Goldberg.cells_at(st.family(), st.globe_frequency())]
			if not is_equal_approx(st.actual_cell_cm(), float(st.get_value("cell_cm"))):
				return "у линзы предел: %s см" % Settings.format_number("cell_cm", st.actual_cell_cm())
		"hand_smoothing":
			if st.get_value("hand_rotation") == "face":
				return "в режиме «лицом к шлему» рука шар не вращает — сглаживать нечего"
	return ""


func start_edit(id: String) -> void:
	if wizard_active():
		return
	editing = SettingEdit.new(menu.settings, id)
	menu.panel_locked = true
	var buttons := ["default"]
	if Demo.supports(id):
		buttons.append("demo")
	buttons.append("done")
	panel.open_editor(editing, Settings.SPEC[id]["title"], buttons, _note_for.bind(id))
	journal.log("настройка_открыта", menu.params(), "", "", -1, id)


func _finish_edit() -> void:
	var id := editing.id
	editing = null
	menu.settings.save()
	menu.demo.stop()
	panel.close_editor()
	menu.panel_locked = false
	journal.log("настройка_сохранена", menu.params(), "", "", -1, "%s=%s" % [id, menu.settings.get_value(id)])


func _on_edit_changed() -> void:
	menu.apply_settings()
	var e: SettingEdit = panel.edit
	if e == null:
		return
	if wizard_active():
		wizard.note_change()
		journal.log("мастер_значение", menu.params(), "", "", -1, "%s=%s" % [e.id, e.value()])
	else:
		journal.log("настройка_значение", menu.params(), "", "", -1, "%s=%s" % [e.id, e.value()])
	# новое значение — сразу видно: доводка, липкость, удержание показываются заново
	if Demo.supports(e.id) and not menu.demo.running():
		menu.start_demo(e.id)
	panel.refresh()


func _on_panel_button(name: String) -> void:
	journal.log("панель_кнопка", menu.params(), "", "", -1, name)
	if panel.is_text_open():
		if name == "done":
			menu.back()       # закрывает вид поиска; search_closed закроет ввод
			_on_search_closed()
		return
	if wizard_active():
		match name:
			"next", "save":
				var step := wizard.current()
				wizard.confirm()
				journal.log("мастер_сохранено" if step == Wizard.SUMMARY else "мастер_подтверждено", menu.params(), "", "", -1, step)
				if wizard.done:
					_wizard_done()
					return
			"back":
				wizard.back()
				journal.log("мастер_назад", menu.params(), "", "", -1, wizard.current())
			"default":
				var e: SettingEdit = panel.edit
				if e != null:
					e.default()
					menu.apply_settings()
					wizard.note_change()
					panel.refresh()
				return
			"demo":
				menu.start_demo(wizard.current())
				return
		menu.demo.stop()
		menu.apply_settings()
		_wizard_show()
		return
	if editing == null:
		return
	match name:
		"default":
			editing.default()
			menu.apply_settings()
			panel.refresh()
		"demo":
			menu.start_demo(editing.id)
		"done":
			_finish_edit()


func _wizard_done() -> void:
	menu.demo.stop()
	panel.close_editor()
	menu.panel_locked = false
	task_label.text = "Настройки сохранены" if wizard.saved else "Не удалось сохранить настройки"
	menu.apply_settings()
	_show_help()


# --- поиск и выход ---------------------------------------------------------------

func _on_search_requested() -> void:
	menu.panel_locked = true
	panel.open_text("Поиск", ["done"])
	journal.log("поиск_открыт", menu.params())


func _on_search_text(t: String) -> void:
	menu.set_search_query(t)
	journal.log("поиск_запрос", menu.params(), "", "", -1, "%s → %d" % [t, maxi(0, menu.nav.items().size() - 1)])


func _on_search_closed() -> void:
	if panel.is_text_open():
		panel.close_editor()
	if not wizard_active() and editing == null:
		menu.panel_locked = false


## «Выход» (удержанием): сохранить настройки и избранное, записать выход в журнал, выгрузить
## файлы в общую папку и выйти. Итог выгрузки — в журнал до копирования его самого, и в лог.
func _exit_app() -> void:
	menu.settings.save()
	menu.catalog.save_favorites()
	var dst := OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS)
	var stamp := Export.stamp_now()
	journal.log("выход", menu.params(), "", "", -1, "выгрузка в %s" % dst.path_join("VRGE").path_join(stamp))
	var res: Dictionary = Export.run(dst, selfcheck_lines, stamp)
	print("выход: выгрузка %s — записано %s, отказ %s" % [res["dir"], res["ok"], res["failed"]])
	task_label.text = "Выход: журнал в %s" % res["dir"]
	await get_tree().create_timer(0.5).timeout
	get_tree().quit()


# --- задания ---------------------------------------------------------------------

func _on_tasks(on: bool) -> void:
	controllers.tasks_on = on
	task_label.text = "Режим заданий: B — следующее задание" if on else ""
	_place_task_label()


func _prepare_tasks() -> void:
	for id in menu.catalog.all_ids():
		var it: Item = menu.catalog.items[id]
		if it.kind in [Item.Kind.SCENE, Item.Kind.IMAGE, Item.Kind.ASSET, Item.Kind.FILE]:
			_tasks.append([id, it.title])
	_tasks.shuffle()


func _next_task() -> void:
	if _tasks.is_empty():
		task_label.text = "Задания закончились"
		return
	var t: Array = _tasks.pop_back()
	_task_id = t[0]
	_task_title = t[1]
	_task_ms = Time.get_ticks_msec()
	task_label.text = "Найдите: %s" % _task_title
	_place_task_label()
	journal.log("задание", menu.params(), _task_id)


func _on_menu_event(name: String, data: Dictionary) -> void:
	var hit := ""
	var since := -1
	if _task_id != "":
		since = Time.get_ticks_msec() - _task_ms
		if name == "select" and data.get("item", "") == _task_id:
			hit = "да"
			task_label.text = "Найдено: %s за %.1f с — B для следующего" % [_task_title, since / 1000.0]
			journal.log(name, menu.params(), _task_id, hit, since, str(data))
			_task_id = ""
			return
		if name == "select":
			hit = "нет"
	if name == "active" and _task_id == "":
		return
	journal.log(name, menu.params(), _task_id, hit, since, str(data))
