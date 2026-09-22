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
const Room := preload("res://world/room.gd")
const LevelLoader := preload("res://world/level_loader.gd")
const LevelStream := preload("res://world/level_stream.gd")
const Layers := preload("res://world/layers.gd")
const Visibility := preload("res://world/visibility.gd")
const SignFace := preload("res://world/sign_face.gd")
const Locomotion := preload("res://locomotion/locomotion.gd")
const Grab := preload("res://world/grab.gd")
const Pull := preload("res://world/pull.gd")
const PullView := preload("res://world/pull_view.gd")
const Screenshot := preload("res://session/screenshot.gd")
const Scenario := preload("res://session/scenario.gd")
## Сколько висит сообщение о скриншоте, мс.
const NOTICE_MS := 4000
const Journal := preload("res://session/journal.gd")
const HelpText := preload("res://session/help_text.gd")
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

@onready var player: CharacterBody3D = $Player
@onready var origin: XROrigin3D = $Player/XROrigin3D
@onready var camera: XRCamera3D = $Player/XROrigin3D/XRCamera3D
@onready var left: XRController3D = $Player/XROrigin3D/LeftHand
## Прицельная поза левой руки: у LeftHand поза grip (шар лежит в ладони), и её −Z смотрит вдоль
## рукоятки вниз — призывать предмет ею нельзя, луч уходит в пол (сессия 19).
@onready var left_aim: XRController3D = $Player/XROrigin3D/LeftAim
@onready var right: XRController3D = $Player/XROrigin3D/RightHand

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
## Пространственные данные шлема: комната, пол, столы (этап Ф3).
var room: Room = Room.new()
## Стартовая локация, перемещение и предметы в руке (этап Ф3).
var level: Node3D
var locomotion: Locomotion
var grab: Grab = Grab.new()
## Призыв предметов: рука → подсвеченная цель, рука → летящий предмет, где была кисть в прошлом кадре.
var _pull_aimed: Dictionary = {}
var _flying: Dictionary = {}
var _hand_was: Dictionary = {}
## файл уровня → его записи для учёта видимости
var _vis_nodes: Dictionary = {}
## Снимок видимости, снятый при входе в режим игры.
var _play_snapshot: Dictionary = {}
## Предметы группы «grab» этого кадра: один обход вместо трёх.
var _grabbable: Array = []
## Фальсификатор «grabthrice»: группа обходится трижды за кадр — цена этой правки не измерялась.
var falsify_grab_thrice := false
## Предмет, к которому нить тянется принудительно: только для замера её цены самопроверкой.
var _pull_probe: Node3D = null
var pull_view: PullView = PullView.new()
## Учёт загруженных частей уровня и отложенной выгрузки (world/level_stream.gd).
var stream: LevelStream = LevelStream.new()
## Кому что видно: слои маской камеры, группы и объекты — своим флагом (world/visibility.gd).
var vis: Visibility = Visibility.new()
## Куда возвращает «в стартовую точку» и падение: положение И поворот при загрузке уровня.
var spawn_xf := Transform3D()
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
## Ширина подсказки перед лицом, пикселей текста (pixel_size 0.001 → метры). 1.3 м на 1.5 м от глаз —
## около 50° по горизонтали, влезает в поле зрения и в снимок (сессия 14: строка обрезалась).
const TASK_WIDTH_PX := 1300.0
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
	# Сетка — в МИРЕ, не под origin: с появлением тела игрока origin поехал вместе с человеком, и
	# сетка уезжала с ним, в том числе вверх на платформы (сессия 17).
	floor_grid.setup(self, camera)
	room.setup(origin)
	# Видимая связь при призыве: подсветка предмета и нить от ладони к нему (world/pull_view.gd).
	pull_view.setup(self)
	level = Node3D.new()
	level.name = "Level"
	add_child(level)
	player.setup(origin, camera)
	locomotion = Locomotion.new()
	add_child(locomotion)

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
	space.reset_done.connect(func(detail: String):
		journal.log("пространство_сброс", menu.params(), "", "", -1, detail)
		_scenario_event("space_reset", {}))
	room.room_known.connect(func(detail: String): journal.log("комната", menu.params(), "", "", -1, detail))
	profile_ui.room_key = room.place_key
	# Уровень — ПОСЛЕ меню и журнала: запись о загрузке просит у меню параметры (сессия 15: уровень
	# грузился раньше, и запись обращалась к пустому меню).
	_load_level("res://world/levels/start_location.json")
	locomotion.setup(player, origin, camera, menu, left, right)
	# Кто, кроме шара, держит ввод. Спрашиваем СОСТОЯНИЕ у владельцев, а не копим флаги по сигналам:
	# «показана» без парной «скрыта» заперла перемещение на весь прогон (сессия 30).
	locomotion.input_hold = func() -> String:
		return Locomotion.hold_reason(profile_ui.active(), menu.panel_locked, panel.is_text_open())
	locomotion.moved.connect(func(kind: String, detail: String):
		journal.log("перемещение", menu.params(), "", "", -1, "%s: %s" % [kind, detail])
		if kind == "перевал":
			_scenario_event("mantle", {}))
	# Упал со сцены (сессия 17: за краем площадки можно падать вечно) — возврат в стартовую точку.
	player.fell.connect(func(depth: float): respawn("падение с %.0f м" % depth))
	profile_ui.eye_rejected.connect(func(): _scenario_event("eye_rejected", {}))
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
	# Билборд: сообщение ставится один раз и держится лицом к человеку, сколько бы он ни
	# поворачивался (сессия 17: подсказку видно было с изнанки, текст читался зеркально).
	notice.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	notice.visible = false
	add_child(notice)

	task_label = Label3D.new()
	task_label.font_size = 48
	task_label.pixel_size = 0.001
	task_label.outline_size = 12
	task_label.no_depth_test = true
	# Подсказка висит в мире и за головой не следует. Сессия 17: человек повернулся (125 поворотов
	# щелчком) и увидел её изнанку — текст зеркальный. Билборд по вертикали держит её лицом к
	# человеку, не заваливая строки при наклоне головы.
	task_label.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	task_label.modulate = Color(1, 1, 0.7)
	# Перенос по словам: в сессии 14 длинная подсказка уходила за край кадра. Ширина — в пикселях
	# текста, при pixel_size 0.001 это метры сцены.
	task_label.width = TASK_WIDTH_PX
	task_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(task_label)
	task_label.text = "Самопроверка…"
	_place_task_label()

	journal.open()
	_apply_world()
	journal.log("профиль_открыт", menu.params(), "", "", -1, "%s%s%s" % [profiles.profile.name,
			("; создан, перенесено %s" % [boot["migrated"]]) if boot["created"] != "" else "",
			("; отвергнуто %s" % [rejected]) if not rejected.is_empty() else ""])
	_prepare_tasks()

	# Зона с полом — до всего остального: в «сидячей» зоне высота головы считается от точки старта,
	# и человек оказывается глазами на уровне земли (сессия 32, зона пришла 2 = SITTING).
	var area: int = await space.ensure_floor_wait(self)
	journal.log("пространство", menu.params(), "", "PASS" if Space.has_floor(area) else "FAIL", -1,
			"режим игровой зоны при запуске: %d (%s)" % [area,
					"с полом" if Space.has_floor(area) else "БЕЗ пола — высота головы не от земли"])
	print("зона при запуске: %d (%s)" % [area, "с полом" if Space.has_floor(area) else "БЕЗ пола"])
	# Запасной путь: система не дала зону с полом (сидячий режим Quest). Высота головы считается от
	# точки старта, и без поправки человек оказывается глазами в земле. Поднимаем origin на рост:
	# камера, дающая ноль в позе старта, окажется на высоте глаз, а присядет человек — опустится.
	if not Space.has_floor(area):
		var eye: float = profiles.profile.eye_m if profiles.profile.eye_m > 0.0 else 1.6
		origin.position.y = eye
		journal.log("пространство", menu.params(), "", "", -1,
				"зона без пола: origin поднят на рост %.2f м" % eye)
		print("зона без пола: origin поднят на %.2f м" % eye)
	await _warm_in_xr()
	var res: Dictionary = await ProbeBudget.request_target(self)
	print("частота: запрошено %.0f, получено %.1f (%s)" % [res["requested"], res["got"], res["outcome"]])
	for _i in 10:
		await get_tree().process_frame
	var saved := menu.settings.values.duplicate()
	var check := SelfCheck.new()
	# Замеры окнами идут только по требованию: из-за них запуск молчал 154 секунды, и человек в
	# шлеме не мог понять, сломалось или надо ждать (сессия 31). Маркер — для прогонов без рук.
	check.full = FileAccess.file_exists("user://selfcheck_full")
	check.step.connect(_on_check_step)
	task_label.text = "Проверка 0/%d…" % SelfCheck.plan(check.full).size()
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
	player.set_eye_height(profiles.profile.eye_m if profiles.profile.eye_m > 0.0 else 1.6)
	if had_settings:
		_show_help()
	else:
		start_wizard()


## Подсказка пересобирается при каждом переключении шара: при открытом шаре перемещение заперто
## (ADR-0013 п. 6), и человеку надо сказать, что для ходьбы шар закрывают (сессия 16 — текст этого
## не говорил, и перемещение не испытали за всю сессию).
func _show_help() -> void:
	if scenario.active or _task_id != "":
		return
	task_label.text = HelpText.text(router.current() == Arbiter.HANDS, menu.is_open(),
			str(menu.settings.get_value("move_mode")), str(menu.settings.get_value("turn_mode")),
			float(menu.settings.get_value("snap_angle")), float(menu.settings.get_value("turn_speed")))
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


## Подпись пункта «Запуск теста»: по переключателю не видно, идёт тест или нет, и в сессии 20
## владелец выключил его вторым нажатием, не заметив, — дальше ни один шаг не засчитывался.
func _refresh_tasks_item() -> void:
	var it: Item = menu.catalog.items.get("set_tasks", null)
	if it == null:
		return
	it.title = scenario.menu_title()
	it.short = "Тест %d/%d" % [scenario.result.size(), Scenario.STEPS.size()] if scenario.active else "Тест"
	menu.refresh_list()


## Сообщение перед лицом на NOTICE_MS: скриншот, возврат в стартовую точку и прочее, о чём человек
## должен узнать, даже когда шар закрыт.
##
## Над меню, а не посреди взгляда: в сессии 8 надпись пересекалась с шаром и панелью. 0.55 м вверх
## на 1.5 м — около 20° над осью взгляда; шар и панель держат ниже неё.
func _show_notice(text: String, color: Color) -> void:
	notice.text = text
	notice.modulate = color
	var fwd := -camera.global_basis.z
	notice.global_position = camera.global_position + fwd * 1.5 + camera.global_basis.y * 0.55
	notice.visible = true
	_notice_until = Time.get_ticks_msec() + NOTICE_MS


## Скриншот: снимок — до сообщения, чтобы сообщение не попало в кадр.
func _take_screenshot() -> void:
	if _shooting:
		return
	_shooting = true
	notice.visible = false
	var dir := Screenshot.folder(OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS))
	var res: Dictionary = await Screenshot.capture(self, camera.global_transform, dir)
	_shooting = false
	_show_notice(Screenshot.notice(res),
			Color(1.0, 0.55, 0.45) if res["over_limit"] or not res["ok"] else Color(0.8, 1.0, 0.8))
	journal.log("скриншот", menu.params(), "", "да" if res["ok"] else "нет", -1,
			"%s, %d×%d, %d байт, всего %d (%s), %d мс%s%s" % [res["name"], res["width"], res["height"], res["bytes"],
			res["total_bytes"], res["how"], res["ms"], ", ПРЕДЕЛ" if res["over_limit"] else "",
			(", ошибка: " + res["error"]) if res["error"] != "" else ""])
	print("скриншот: %s" % Screenshot.notice(res).replace("\n", " | "))
	_scenario_event("screenshot", {"ok": res["ok"]})


func _process(_delta: float) -> void:
	floor_grid.follow()
	SignFace.face_all(get_tree().get_nodes_in_group("sign"), camera.global_position)
	if _pull_probe != null and is_instance_valid(_pull_probe):
		pull_view.show_link("right", _pull_probe, right.global_position, false)
	_unload_frame(_delta)
	_grab_frame(_delta)
	_watch_sink()
	profile_ui.tick_eye(_delta)
	if notice != null and notice.visible and Time.get_ticks_msec() > _notice_until:
		notice.visible = false
	if scenario.active and task_label != null:
		var fwd := -camera.global_basis.z
		fwd.y = 0.0
		fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3.FORWARD
		var target := camera.global_position + fwd * 1.5 + Vector3(0, 0.3, 0)
		task_label.global_position = task_label.global_position.lerp(target, TASK_FOLLOW)


func _place_task_label() -> void:
	var fwd := -camera.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3.FORWARD
	task_label.global_position = camera.global_position + fwd * 1.5 + Vector3(0, 0.25, 0)


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


## Загрузить уровень или его часть из данных (world/level_loader.gd). Файл, уже загруженный,
## второй раз не строится: триггер помещения срабатывает при каждом входе.
func _load_level(path: String) -> Dictionary:
	if stream.is_loaded(path):
		return {}
	var res := LevelLoader.parse(FileAccess.get_file_as_string(path))
	if not res["ok"]:
		journal.log("уровень", menu.params(), "", "FAIL", -1, "%s: %s" % [path, res["error"]])
		push_warning("уровень %s: %s" % [path, res["error"]])
		return {}
	var built := LevelLoader.build(level, res["data"])
	stream.add(path, built["nodes"])
	for entry in built["index"]:
		vis.register(entry)
	_vis_nodes[path] = built["index"]
	menu.catalog.set_groups(vis.group_names(), vis.group_on)
	_apply_visibility()
	# Появились новые таблички — развернуть их, не дожидаясь, когда человек сдвинется.
	SignFace.forget()
	for t in built["triggers"]:
		var file: String = t["file"]
		var area := t["area"] as Area3D
		area.body_entered.connect(func(node: Node3D):
			if node != player:
				return
			# Вернулся раньше, чем истёк отсчёт, — выгрузку отменяем.
			stream.enter(file)
			var more := _load_level(file)
			if not more.is_empty():
				journal.log("уровень", menu.params(), "", "", -1,
						"подгружено по триггеру: %s, узлов %d" % [file.get_file(), more["nodes"].size()]))
		# Выход из зоны — отсчёт, а не выгрузка сразу: шаг туда-обратно у проёма иначе давал бы
		# мигание загрузки (сессия 17: интерьер не выгружался вовсе, body_exited не был подключён).
		area.body_exited.connect(func(node: Node3D):
			if node == player:
				stream.exit(file))
	journal.log("уровень", menu.params(), "", "", -1, "%s: узлов %d, материалов %d" % [path.get_file(),
			built["nodes"].size(), built["colors"]])
	if built["spawn"] != Transform3D():
		spawn_xf = built["spawn"]
		_place_at_spawn("старт")
	return built


## Откуда целится рука: у левой поза grip смотрит вдоль рукоятки, поэтому берём её прицельную позу.
func _aim_of(hand: String) -> XRController3D:
	return left_aim if hand == "left" else right


## Призыв предмета (world/pull.gd): «гравиперчатки». Прицеливание — когда рука пуста и грип не
## нажат: ближайший к оси ладони предмет подсвечивается.
func _pull_aim(hand: String, ctrl: XRController3D) -> void:
	if str(menu.settings.get_value("pull_mode")) == "off":
		_pull_aimed[hand] = null
		pull_view.show_link(hand, null, Vector3.ZERO, false)
		return
	var aim_node := _aim_of(hand)
	var target := Pull.target(_grabbable, aim_node.global_position, -aim_node.global_basis.z)
	_pull_aimed[hand] = target
	pull_view.show_link(hand, target, aim_node.global_position, ctrl.is_button_pressed("grip_click"))


## Грип зажат на пустой руке: «сразу» тянет цель тут же, «жестом» ждёт рывка кистью к себе.
func _pull_frame(hand: String, ctrl: XRController3D, dt: float) -> void:
	var mode := str(menu.settings.get_value("pull_mode"))
	# Занятая рука не призывает: вторая защита рядом с той, что в _grab_frame. Одной мало — сюда
	# ведут два пути, и следующий, кто добавит третий, пройдёт мимо проверки наверху.
	if mode == "off" or _flying.has(hand) or grab.held.has(hand):
		return
	var aim: Node3D = _pull_aimed.get(hand, null)
	if aim == null or not is_instance_valid(aim):
		_pull_aim(hand, ctrl)
		aim = _pull_aimed.get(hand, null)
		if aim == null:
			return
	# Скорость кисти по окну: один кадр дрожи не должен считаться рывком.
	var prev: Vector3 = _hand_was.get(hand, ctrl.global_position)
	var hand_v := (ctrl.global_position - prev) / maxf(dt, 0.001)
	_hand_was[hand] = ctrl.global_position
	if mode == "instant" or Pull.is_flick(hand_v, camera.global_position - ctrl.global_position):
		_pull_aimed[hand] = null
		pull_view.show_link(hand, null, Vector3.ZERO, false)
		_flying[hand] = {"node": aim, "from": aim.global_position, "t": 0.0}
		if aim is RigidBody3D:
			(aim as RigidBody3D).freeze = true
		journal.log("предмет", menu.params(), "", "", -1, "призван %s рукой %s (%s)" % [aim.name, hand, mode])
		_scenario_event("pull", {"mode": mode})


## Кадр полёта: предмет идёт по дуге в ладонь, у ладони переходит в обычное взятие.
func _pull_fly(dt: float) -> void:
	for hand in _flying.keys():
		var f: Dictionary = _flying[hand]
		var node := f["node"] as Node3D
		var ctrl: XRController3D = left if hand == "left" else right
		if not is_instance_valid(node):
			_flying.erase(hand)
			continue
		f["t"] = float(f["t"]) + dt / Pull.FLY_S
		node.global_position = Pull.fly_point(f["from"], ctrl.global_position, f["t"])
		# Нить тянется за летящим предметом и гаснет, когда он оказался в руке.
		pull_view.show_link(hand, node, ctrl.global_position, true)
		if f["t"] < 1.0:
			continue
		# Прилетел — ждёт у ладони: после рывка кистью грип успевает разжаться, и требовать его
		# ровно в момент прилёта значит терять две трети призывов (сессия 20).
		f["wait"] = float(f.get("wait", 0.0)) + dt
		node.global_position = ctrl.global_position
		if ctrl.is_button_pressed("grip_click"):
			_flying.erase(hand)
			pull_view.show_link(hand, null, Vector3.ZERO, false)
			# Если рука всё-таки занята, предмет ОТПУСКАЕТСЯ, а не остаётся замороженным висеть в
			# воздухе: прежде взятие молча не удавалось, предмет терял и полёт, и руку, а журнал
			# писал «прилетел» — то есть врал (сессия 31).
			if grab.grab(hand, node, ctrl.global_transform):
				journal.log("предмет", menu.params(), "", "", -1, "прилетел в руку %s: %s" % [hand, node.name])
				_scenario_event("pull_catch", {})
			else:
				if node is RigidBody3D:
					(node as RigidBody3D).freeze = false
				journal.log("предмет", menu.params(), "", "", -1,
						"рука %s занята — %s отпущен" % [hand, node.name])
		elif float(f["wait"]) > Pull.CATCH_WINDOW_S:
			_flying.erase(hand)
			pull_view.show_link(hand, null, Vector3.ZERO, false)
			if node is RigidBody3D:
				(node as RigidBody3D).freeze = false
			journal.log("предмет", menu.params(), "", "", -1, "не пойман рукой %s: %s" % [hand, node.name])


## Показать то, что должно быть видно: слои — маской камеры (узлы не трогаются, физика цела),
## группы и отдельные объекты — флагом у видимой части.
func _apply_visibility() -> void:
	vis.apply_to(camera, _vis_nodes)


## Режим игры: показать только то, что видит игрок, и вернуть всё как было на выходе.
func set_play(on: bool) -> void:
	if on == vis.playing:
		return
	if on:
		_play_snapshot = vis.enter_play()
	else:
		vis.exit_play(_play_snapshot)
		_play_snapshot = {}
	_apply_visibility()
	journal.log("слои", menu.params(), "", "", -1,
			"режим игры: %s, маска %d" % ["вход" if on else "выход", vis.camera_mask()])


## Кадр выгрузки: файл, из зоны которого человек вышел и не вернулся, снимается со сцены.
func _unload_frame(dt: float) -> void:
	for file in stream.tick(dt):
		var gone: Array = []
		for entry in _vis_nodes.get(file, []):
			gone.append(str(entry["uuid"]))
		vis.forget(gone)
		_vis_nodes.erase(file)
		var nodes: Array = stream.take(file)
		for n in nodes:
			if is_instance_valid(n):
				(n as Node).queue_free()
		journal.log("уровень", menu.params(), "", "", -1,
				"выгружено по триггеру: %s, узлов %d" % [file.get_file(), nodes.size()])


## Вернуть человека в стартовую точку уровня — положение И поворот (пункт меню, падение со сцены).
## Поставить человека в точку старта ПО ГЕОМЕТРИИ: точка из данных говорит где, а высоту и посадку
## считает уровень (решение владельца 2026-09-22). Курс берётся из точки, место — из-под неё.
func _place_at_spawn(why: String) -> void:
	player.global_transform = spawn_xf
	player.velocity = Vector3.ZERO
	var res := player.drop_to_ground(spawn_xf.origin)
	journal.log("перемещение", menu.params(), "", "PASS" if res["ok"] else "FAIL", -1,
			"%s: точка %s → ноги %.2f (%s), маска %d" % [why, spawn_xf.origin.snappedf(0.01),
					player.global_position.y, res["why"], player.collision_mask])
	_print_pose(why)


func respawn(why: String) -> void:
	if spawn_xf == Transform3D():
		return
	var was := camera.global_position.y
	_place_at_spawn("возврат")
	# origin внутри тела мог уехать от компенсации следования — возвращаем и его.
	origin.transform = Transform3D()
	# И приседание: иначе тело «помнит» его и держит взгляд ниже (сессия 23 — «респавн не сбросил
	# высоту, всё ещё глаза на уровне пола»).
	player.set_crouch(0.0)
	player.mantling = false
	player.release_collisions()
	# Числа, которых не хватило в сессии 32, когда человек проваливался сквозь пол четыре раза
	# подряд: по одной высоте глаз не отличить «провалился» от «присел».
	journal.log("перемещение", menu.params(), "", "", -1,
			"возврат в стартовую точку: %s, глаза %.2f → %.2f м, ноги %.2f, маска %d, origin %.2f" % [
					why, was, camera.global_position.y, player.global_position.y,
					player.collision_mask, origin.position.y])
	# Молча переносить человека нельзя: он не понимает, что произошло (просьба владельца, сессия 18).
	_show_notice("Вы в стартовой точке уровня — %s" % why, Color(0.8, 1.0, 0.8))


## Замер цены нити (самопроверка): связь строится принудительно, без наведения рукой.
func set_pull_probe(node: Node3D) -> void:
	_pull_probe = node
	if node == null:
		pull_view.show_link("right", null, Vector3.ZERO, false)


## Кадр предметов в руке: грип контроллера берёт и отпускает куб из группы «grab».
func _grab_frame(dt: float) -> void:
	if locomotion == null or not locomotion.input_free():
		return
	# Группа «grab» обходилась до трёх раз за кадр (наведение каждой руки плюс ближнее взятие).
	# Один обход, дальше список передаётся (сессия 24, цена кадра).
	_grabbable = get_tree().get_nodes_in_group("grab")
	if falsify_grab_thrice:
		# Как было до сессии 25: группа обходилась на каждое наведение и на ближнее взятие.
		_grabbable = get_tree().get_nodes_in_group("grab")
		_grabbable = get_tree().get_nodes_in_group("grab")
	for pair in [["left", left], ["right", right]]:
		var hand: String = pair[0]
		var ctrl: XRController3D = pair[1]
		var holding: bool = ctrl.is_button_pressed("grip_click")
		if holding and not grab.held.has(hand):
			var near := Grab.nearest(_grabbable, ctrl.global_position)
			if near != null:
				if grab.grab(hand, near, ctrl.global_transform):
					journal.log("предмет", menu.params(), "", "", -1, "взят %s рукой %s" % [near.name, hand])
			else:
				_pull_frame(hand, ctrl, dt)
		elif holding:
			grab.update(hand, ctrl.global_transform, dt)
			# Призыв ЗАНЯТОЙ рукой не начинается: рука, которая уже держит, занята (решение
			# владельца 2026-09-22). Раньше призыв тикал и здесь, поэтому предметы притягивались
			# один за другим, не выпуская прежний.
		elif grab.held.has(hand):
			var v := grab.release(hand)
			journal.log("предмет", menu.params(), "", "", -1, "отпущен, скорость %.2f м/с" % v.length())
		else:
			_pull_aim(hand, ctrl)
	_pull_fly(dt)


## Где сейчас человек — в logcat, чтобы числа были видны СРАЗУ, не дожидаясь выгрузки журнала:
## прерванная сессия журнал не пишет, а «ниже пола» без чисел не отличить от «присел» и от
## «система дала другой пол» (сессия 32).
## Тело уехало вниз само, без падения и без команды: печатаем ОДИН раз, чтобы не залить лог.
var _sank := false


func _watch_sink() -> void:
	if _sank or player == null or spawn_xf == Transform3D():
		return
	if player.global_position.y < spawn_xf.origin.y - 0.5:
		_sank = true
		_print_pose("ушёл вниз")


func _print_pose(why: String) -> void:
	var iface := XRServer.find_interface("OpenXR")
	var area := -1
	if iface != null:
		area = int(iface.get_play_area_mode())
	print("ПОЗА[%s]: ноги %.2f, глаза %.2f, камера в origin %.2f, origin %.2f, маска %d, присед %.2f, зона %d, рост профиля %.2f" % [
			why, player.global_position.y, camera.global_position.y, camera.position.y,
			origin.position.y, player.collision_mask, player.crouch, area,
			profiles.profile.eye_m])


## Полный прогон замеров по требованию (пункт меню «Прогнать замеры»). Шлем должен быть надет:
## окна меряют доставку кадров, и уснувший шлем портит числа.
func _run_bench() -> void:
	var check := SelfCheck.new()
	check.full = true
	check.step.connect(_on_check_step)
	menu.close()
	var saved := menu.settings.values.duplicate()
	var ok: bool = await check.run(self, menu)
	menu.settings.values = saved
	menu.apply_settings()
	selfcheck_lines = check.r.lines.duplicate()
	journal.log("самопроверка", menu.params(), "", "PASS" if ok else "FAIL", -1, str(check.results))
	task_label.text = ""
	_show_notice("Замеры закончены: %s" % ("всё в бюджете" if ok else "есть отказы, смотрите журнал"),
			Color(0.8, 1.0, 0.8) if ok else Color(1.0, 0.85, 0.7))


## Настройки пространства и света применяются к миру: они общие для пользователя (scope «user»).
func _apply_world() -> void:
	world_env.apply(menu.settings)
	floor_grid.apply(menu.settings)


func _on_space_action(action: String) -> void:
	# Аргумент действия — после двоеточия: «space_group:зацепы». Без разбора `match` сравнивал бы
	# строку целиком и молча не находил ветку (ловушка 41 — действие, адресованное не туда).
	var arg := action.get_slice(":", 1) if action.contains(":") else ""
	match action.get_slice(":", 0):
		"space_reset":
			var detail := space.reset(profile_ui.measure_eye)
			menu.nav.message = "Пространство сброшено к системным значениям"
			print("пространство: %s" % detail)
		"space_group":
			# Имя группы — в аргументе; пункт меню уже переключил своё состояние.
			var shown := not bool(vis.group_on.get(arg, true))
			vis.group_on[arg] = shown
			_apply_visibility()
			menu.nav.message = "Группа «%s»: %s" % [arg, "показана" if shown else "скрыта"]
			journal.log("слои", menu.params(), "", "", -1,
					"группа %s: %s" % [arg, "показана" if shown else "скрыта"])
		"space_bench":
			menu.nav.message = "Замеры идут — держите шлем надетым, около двух минут"
			_run_bench()
		"space_play":
			set_play(not vis.playing)
			menu.nav.message = "Режим игры включён" if vis.playing else "Режим игры выключен"
		"space_respawn":
			respawn("пункт меню")
			menu.nav.message = "Вы в стартовой точке уровня"
		"space_capture":
			var asked := room.request_capture()
			menu.nav.message = "Открываю разметку пространства" if asked else "Шлем не отдаёт разметку: %s" % room.brief()
			journal.log("комната", menu.params(), "", "", -1, "запрос разметки: %s, %s" % [asked, room.brief()])


## Что сейчас проверяется — перед глазами. Молчащая надпись «Самопроверка…» не отличает работу от
## поломки: на шлеме это две с половиной минуты неизвестности.
func _on_check_step(index: int, total: int, name: String) -> void:
	task_label.text = "Проверка %d/%d: %s" % [index, total, name]


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
	_refresh_tasks_item()
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
		# Человек должен видеть, что шаг зачтён: иначе непонятно, засчиталось ли сделанное.
		_show_notice("Шаг пройден: %d из %d" % [scenario.result.size(), Scenario.STEPS.size()],
				Color(0.8, 1.0, 0.8))
		_refresh_tasks_item()
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
	if data.get("setting", "") in Settings.LAYERS:
		vis.layer_on["editor"] = bool(menu.settings.get_value("layer_editor"))
		vis.layer_on["debug"] = bool(menu.settings.get_value("layer_debug"))
		_apply_visibility()
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
	# Шар переключили или поправили способ перемещения — подсказка пересобирается под новое
	# состояние: она называет текущий способ и угол поворота.
	if name == "toggle" or data.get("setting", "") in Settings.MOVE:
		_show_help()
	if name == "active" and _task_id == "":
		return
	journal.log(name, menu.params(), _task_id, hit, since, str(data))
