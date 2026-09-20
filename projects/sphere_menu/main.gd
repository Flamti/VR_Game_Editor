extends Node3D

## Прототип шар-меню, Ф2 шаг 1в: запуск, самопроверка, мастер настройки, работа.
##
## Порядок: XR-вьюпорт → прогрев в XR-формате → 90 Гц → самопроверка → мастер
## (если настроек ещё нет) → работа. Всё пишется в user://sphere_session.tsv.

const ProbeBudget := preload("res://probe_budget.gd")
const Menu := preload("res://menu/sphere_menu.gd")
const Router := preload("res://input/input_router.gd")
const Arbiter := preload("res://input/input_arbiter.gd")
const ProfileStore := preload("res://profile/profile_store.gd")
const ProfileSession := preload("res://profile/profile_session.gd")
const ProfileUI := preload("res://profile/profile_ui.gd")
const AccountService := preload("res://accounts/account_service.gd")
const HttpTransport := preload("res://accounts/http_transport.gd")
const WorldEnv := preload("res://world/environment.gd")
const FloorGrid := preload("res://world/floor_grid.gd")
const Space := preload("res://world/space.gd")
const Screenshot := preload("res://session/screenshot.gd")
const Scenario := preload("res://session/scenario.gd")
## Сколько висит сообщение о скриншоте, мс.
const NOTICE_MS := 4000
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
## Задание найдено руками — следующее само через столько секунд: кнопки B у рук нет.
const HANDS_NEXT_S := 2.5
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
## Ввод: арбитр, контроллеры, руки и их видимость (input/input_router.gd).
var router: Router
## Активный профиль пользователя: настройки по способу ввода, избранное, личное (ADR-0010).
var profiles: ProfileSession
## Действия папки «Профиль»: имя, рост, глаза, место, PIN, смена и удаление профиля.
var profile_ui: ProfileUI
## Подключаемые аккаунты открытого профиля (ADR-0011).
var accounts: AccountService
## Свет, сетка пола и пространство XR (этап Ф3).
var world_env: WorldEnv = WorldEnv.new()
var floor_grid: FloorGrid = FloorGrid.new()
var space: Space = Space.new()
var journal: Journal = Journal.new()
var task_label: Label3D
## Сообщение о скриншоте перед лицом — видно и при закрытом шаре (тост панели — только при открытом).
var notice: Label3D
var _notice_until := 0
var _shooting := false
var scenario: Scenario = Scenario.new()
var _step_ms := 0
## Подсказка сценария следует за взглядом (сессия 9: поставленная один раз, она уходила из виду
## и срезалась сверху). Скорость догона — доля пути за кадр при 90 Гц.
const TASK_FOLLOW := 0.08
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

	# Свет и окружение — до меню: в сессии 13 сцена была пуста, и кнопок на контроллерах не было видно.
	world_env.setup(self)
	floor_grid.setup(origin, camera)

	menu = Menu.new()
	menu.head = camera
	menu.hand = left
	menu.hand_offset = BALL_OFFSET
	profiles = ProfileSession.new(ProfileStore.new("user://"), menu)
	# Первый запуск с профилями: файлы до профилей переезжают в «Основной» (ADR-0010 п. 7).
	var boot := profiles.store.ensure_default()
	# Не ребёнок контроллера: ориентацию задаёт следование за рукой (menu/hand_follow.gd).
	add_child(menu)
	# После add_child: открытие применяет настройки к готовому меню. Ввод до конца самопроверки — у
	# контроллеров (роутер ещё не готов), им и набор.
	var rejected := profiles.open(profiles.store.startup_id(), Arbiter.CONTROLLERS)
	var had_settings := profiles.input_settings.exists_any()
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
	panel.keyboard.connect(_on_keyboard)
	if iface != null:
		# Системная клавиатура забирает фокус ввода (Meta, «Enable Keyboard Overlay»). Идёт ли
		# при этом рендер и доходит ли ввод контроллеров — не измерено: журнал это и покажет.
		for sig in ["session_begun", "session_visible", "session_focussed", "session_stopping"]:
			iface.connect(sig, _on_xr_session.bind(sig))
	panel.edit_changed.connect(_on_edit_changed)
	panel.button.connect(_on_panel_button)

	router = Router.new()
	add_child(router)
	router.setup(origin, left, right, menu, panel, self)
	router.controllers.next_task.connect(_next_task)
	router.controllers.screenshot_requested.connect(_take_screenshot)
	router.source_changed.connect(_on_source)
	router.gesture.connect(_on_hand_gesture)
	router.controller_models.connect(_on_controller_models)
	router.input_settings = profiles.input_settings
	profile_ui = ProfileUI.new(profiles, menu, panel)
	profile_ui.head = camera
	profile_ui.origin = origin
	profile_ui.current_input = router.current
	profile_ui.logged.connect(func(ev: String, detail: String): journal.log(ev, menu.params(), "", "", -1, detail))
	menu.profile_action.connect(profile_ui.on_action)
	menu.space_action.connect(_on_space_action)
	space.reset_done.connect(func(detail: String): journal.log("пространство_сброс", menu.params(), "", "", -1, detail))
	_apply_world()
	var http := HttpTransport.new()
	add_child(http)
	accounts = AccountService.new(profiles, http.request)
	add_child(accounts)
	var has_oauth := accounts.load_oauth()
	accounts.changed.connect(profile_ui.on_accounts_changed)
	accounts.logged.connect(func(ev: String, detail: String): journal.log(ev, menu.params(), "", "", -1, detail))
	profile_ui.accounts = accounts
	print("аккаунты: OAuth-клиент Google %s" % ("есть" if has_oauth else "НЕТ (secrets/oauth_clients.cfg)"))
	router.settings_switched.connect(func(input: String):
		journal.log("настройки_ввода", menu.params(), "", "", -1, input))

	notice = Label3D.new()
	notice.font_size = 40
	notice.pixel_size = 0.001
	notice.outline_size = 10
	notice.no_depth_test = true
	notice.visible = false
	add_child(notice)

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
	_apply_world()
	journal.log("профиль_открыт", menu.params(), "", "", -1, "%s%s%s" % [profiles.profile.name,
			("; создан, перенесено %s" % [boot["migrated"]]) if boot["created"] != "" else "",
			("; отвергнуто %s" % [rejected]) if not rejected.is_empty() else ""])
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
	# Ввод — только теперь: в сессии 11 кулак закрыл шар посреди самопроверки.
	# Ввод включается здесь; если у профиля PIN — шар заперт до верного ввода (profile/profile_ui.gd).
	profile_ui.start(router.set_ready)
	journal.log("ввод_готов", menu.params(), "", "", -1, "%s%s" % [router.current(),
			", ждёт PIN" if profile_ui.active() else ""])
	if had_settings:
		_show_help()
	else:
		start_wizard()


func _show_help() -> void:
	if router.current() == Arbiter.HANDS:
		task_label.text = "руки: кулак левой — шар · коснуться ячейки кончиком правого — открыть · удержать касание — действия\nпровести пальцем по шару — вращать · щипок правой — нажать на панели лучом ладони · встряхнуть — верхний уровень\nвзять контроллер — управление вернётся к контроллерам"
		_place_task_label()
		return
	task_label.text = "Y — шар · курок — открыть · удержание — действия · X — назад · встряхнуть — верхний уровень · оба стика — скриншот\nправый: луч или касание + курок · касание + грип — вращать · B — отменить · стик — прокрутка панели\nнастройки — лучом по панели: ползунок, кнопки, цифры"
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
	router.controllers.ray.visible = true
	for _i in 6:
		var p := camera.global_position - camera.global_basis.z * 1.0
		warm.global_position = p
		panel.global_position = p + camera.global_basis.x * 0.02
		await get_tree().process_frame
	for mmi in [warm.get_node("Hex"), warm.get_node("Pent"), warm.get_node("Quad"), warm.get_node("Hept")]:
		(mmi as MultiMeshInstance3D).visible = false
	panel.close_editor()
	panel.visible = false
	router.controllers.ray.visible = false


## Скриншот: снимок — до сообщения, чтобы сообщение не попало в кадр.
func _take_screenshot() -> void:
	if _shooting:
		return
	_shooting = true
	notice.visible = false
	var dir := Screenshot.folder(OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS))
	var res: Dictionary = await Screenshot.capture(self, camera.global_transform, dir)
	_shooting = false
	notice.text = Screenshot.notice(res)
	notice.modulate = Color(1.0, 0.55, 0.45) if res["over_limit"] or not res["ok"] else Color(0.8, 1.0, 0.8)
	# Над меню, а не посреди взгляда: в сессии 8 надпись пересекалась с шаром и панелью. 0.55 м вверх
	# на 1.5 м — около 20° над осью взгляда; шар и панель держат ниже неё.
	var fwd := -camera.global_basis.z
	notice.global_position = camera.global_position + fwd * 1.5 + camera.global_basis.y * 0.55
	notice.look_at(notice.global_position + fwd, camera.global_basis.y)
	notice.visible = true
	_notice_until = Time.get_ticks_msec() + NOTICE_MS
	journal.log("скриншот", menu.params(), "", "да" if res["ok"] else "нет", -1,
			"%s, %d×%d, %d байт, всего %d (%s), %d мс%s%s" % [res["name"], res["width"], res["height"], res["bytes"],
			res["total_bytes"], res["how"], res["ms"], ", ПРЕДЕЛ" if res["over_limit"] else "",
			(", ошибка: " + res["error"]) if res["error"] != "" else ""])
	print("скриншот: %s" % Screenshot.notice(res).replace("\n", " | "))
	_scenario_event("screenshot", {"ok": res["ok"]})


func _process(_delta: float) -> void:
	floor_grid.follow()
	profile_ui.tick_eye(_delta)
	if notice != null and notice.visible and Time.get_ticks_msec() > _notice_until:
		notice.visible = false
	if scenario.active and task_label != null:
		var fwd := -camera.global_basis.z
		fwd.y = 0.0
		fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3.FORWARD
		var target := camera.global_position + fwd * 1.5 + Vector3(0, 0.3, 0)
		task_label.global_position = task_label.global_position.lerp(target, TASK_FOLLOW)
		task_label.look_at(task_label.global_position + fwd, Vector3.UP)


func _place_task_label() -> void:
	var fwd := -camera.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3.FORWARD
	task_label.global_position = camera.global_position + fwd * 1.5 + Vector3(0, 0.25, 0)
	task_label.look_at(task_label.global_position + fwd, Vector3.UP)


# --- источник ввода --------------------------------------------------------------

## Смена источника — передачу управления делает роутер; здесь подсказка и журнал.
func _on_source(src: String, why: String, witnesses: Dictionary) -> void:
	# Подсказка — того, кто ведёт; задание или сценарий на экране не затираются.
	if _task_id == "" and not scenario.active and not wizard_active():
		_show_help()
	journal.log("источник", menu.params(), "", "", -1, "%s: %s | %s" % [src, why, witnesses])
	print("источник ввода: %s (%s)" % [src, why])


func _on_hand_gesture(name: String, data: Dictionary) -> void:
	journal.log("рука_" + name, menu.params(), "", "", -1, str(data))


## Настройки пространства и света применяются к миру: они общие для пользователя (scope «user»).
func _apply_world() -> void:
	world_env.apply(menu.settings)
	floor_grid.apply(menu.settings)


func _on_space_action(action: String) -> void:
	if action == "space_reset":
		var detail := space.reset(profile_ui.measure_eye)
		menu.nav.message = "Пространство сброшено к системным значениям"
		print("пространство: %s" % detail)


func _on_controller_models(kind: String) -> void:
	journal.log("модели_контроллеров", menu.params(), "", "", -1, kind)
	print("модели контроллеров: %s" % kind)


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
	if profile_ui.on_button(name):
		journal.log("панель_кнопка", menu.params(), "", "", -1, "профиль: " + name)
		return
	journal.log("панель_кнопка", menu.params(), "", "", -1, name)
	if panel.is_text_open():
		if name == "done":
			menu.back()       # закрывает вид поиска; search_closed закроет ввод
			_on_search_closed()
		elif name == "keyboard":
			panel.keyboard_again()
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
	panel.open_text("Поиск", ["done"], menu.settings.get_value("search_keyboard"))
	journal.log("поиск_открыт", menu.params())


func _on_search_text(t: String) -> void:
	# Набор имени или PIN профиля — не поиск; PIN в журнал не пишется никогда.
	if profile_ui.active():
		return
	menu.set_search_query(t)
	journal.log("поиск_запрос", menu.params(), "", "", -1, "%s → %d" % [t, menu.found_count()])


func _on_keyboard(state: String) -> void:
	journal.log("клавиатура", menu.params(), "", "", -1, state)
	_scenario_event("keyboard", {"state": state})


func _on_xr_session(state: String) -> void:
	journal.log("сессия_openxr", menu.params(), "", "", -1, "%s кадр %d" % [state, Engine.get_process_frames()])


func _on_search_closed() -> void:
	if panel.is_text_open():
		panel.close_editor()
	if not wizard_active() and editing == null:
		menu.panel_locked = false


## «Выход» (удержанием): сохранить настройки и избранное, записать выход в журнал, выгрузить
## файлы в общую папку и выйти. Итог выгрузки — в журнал до копирования его самого, и в лог.
func _exit_app() -> void:
	profiles.save()
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
	router.controllers.tasks_on = on
	if on:
		var fresh := scenario.start()
		_step_ms = Time.get_ticks_msec()
		journal.log("сценарий_начат" if fresh else "сценарий_продолжен", menu.params(), "", "", -1,
				"%d шагов, осталось %d" % [Scenario.STEPS.size(), scenario.remaining().size()])
		_show_scenario()
	else:
		scenario.active = false
		task_label.text = ""
	_place_task_label()


func _scenario_ctx() -> Dictionary:
	return {"folder": menu.nav.state.folder()}


## Событие для сценария теста: шаг засчитан — в журнал и к следующему.
func _scenario_event(name: String, data: Dictionary) -> void:
	if not scenario.active:
		return
	var id: String = scenario.event(name, data, _scenario_ctx())
	if id != "":
		journal.log("сценарий_шаг", menu.params(), id, "да", Time.get_ticks_msec() - _step_ms)
		_step_ms = Time.get_ticks_msec()
		_show_scenario()


func _show_scenario() -> void:
	task_label.text = scenario.text() if scenario.active else "Сценарий пройден. Режим заданий: B — следующее задание"
	_place_task_label()


func _prepare_tasks() -> void:
	for id in menu.catalog.all_ids():
		var it: Item = menu.catalog.items[id]
		# 128 одинаковых «Файл NNN» заняли бы почти все задания «найдите»
		if menu.catalog.parent_of.get(id, "") == menu.catalog.BULK_FOLDER:
			continue
		if it.kind in [Item.Kind.SCENE, Item.Kind.IMAGE, Item.Kind.ASSET, Item.Kind.FILE]:
			_tasks.append([id, it.title])
	_tasks.shuffle()


## Следующее задание само — только если за паузу никто не взял следующее кнопкой B.
func _next_task_later(found_task_ms: int) -> void:
	await get_tree().create_timer(HANDS_NEXT_S).timeout
	if _task_id == "" and _task_ms == found_task_ms and not scenario.active and router.controllers.tasks_on:
		_next_task()


func _next_task() -> void:
	if scenario.active:
		var sid := scenario.skip()
		journal.log("сценарий_шаг", menu.params(), sid, "нет", Time.get_ticks_msec() - _step_ms, "пропущен")
		_step_ms = Time.get_ticks_msec()
		_show_scenario()
		return
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
	_scenario_event(name, data)
	# Настройка пространства или света изменилась — мир перестраивается сразу, как шар.
	if data.get("setting", "") in Settings.SPACE:
		_apply_world()
	var hit := ""
	var since := -1
	if _task_id != "":
		since = Time.get_ticks_msec() - _task_ms
		if name == "select" and data.get("item", "") == _task_id:
			hit = "да"
			var by_hands := router.current() == Arbiter.HANDS
			task_label.text = "Найдено: %s за %.1f с — %s" % [_task_title, since / 1000.0,
					"следующее через %.0f с" % HANDS_NEXT_S if by_hands else "B для следующего"]
			journal.log(name, menu.params(), _task_id, hit, since, str(data))
			_task_id = ""
			if by_hands:
				_next_task_later(_task_ms)
			return
		if name == "select":
			hit = "нет"
	if name == "active" and _task_id == "":
		return
	journal.log(name, menu.params(), _task_id, hit, since, str(data))
