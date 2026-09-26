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
##   --falsify=imekey      панель не принимает клавиши системной клавиатуры — краснеют «системная
##                         клавиатура» и «аккаунт: ключ Claude» (ключ API набирается той же клавиатурой);
##   --falsify=enterclose  «Готово» системной клавиатуры закрывает поиск, как в сессии 7, —
##                         краснеет только «системная клавиатура»;
##   --falsify=found       строка «найдено» молчит, как до сессии 10, — краснеет только
##                         «строка найденного»;
##   --falsify=handspace   суставы рук берутся как мировые, мимо XROrigin3D, — краснеет только
##                         «руки: кулак и касание» (касание не находит шар);
##   --falsify=dragselect  протяжка не отменяет выбор — краснеет только «руки: протяжка и перенос»;
##   --falsify=nocolumns   в строке журнала нет ввода и профиля, как в сессии 11, — краснеет только
##                         «журнал»;
##   --falsify=earlyinput  источник берёт меню до конца самопроверки, как в сессии 11, — краснеет
##                         только «ввод после самопроверки»;
##   --falsify=meshstays   силуэт рук не прячется при взятых контроллерах, как в сессии 11, —
##                         краснеет только «видно того, кто ведёт»;
##   --falsify=fallbacknow запасная модель контроллеров — без ожидания, как в сессии 12, — краснеет
##                         только «видно того, кто ведёт»;
##   --falsify=fallbackstays пришедшая модель рантайма не прячет запасную — краснеет только «видно
##                         того, кто ведёт»;
##   --falsify=jointsstay  точки суставов поверх готовой сетки рук — краснеет только «видно того, кто
##                         ведёт»;
##   --falsify=noswitch    смена источника не меняет набор настроек — краснеет только «настройки
##                         того, кто ведёт»;
##   --falsify=staleprofile при смене пользователя остаются настройки и избранное прежнего —
##                         краснеет только «смена пользователя»;
##   --falsify=nolock      пока спрашивают PIN при запуске, шар не заперт — краснеет только «профиль:
##                         PIN при запуске»;
##   --falsify=eyeworld    высота глаз от нуля мира, а не от пола XR-пространства — краснеет только
##                         «профиль: рост, глаза, место»;
##   --falsify=keylower    ключ API приводится к нижнему регистру, как текст поиска, — краснеет только
##                         «аккаунт: ключ Claude»;
##   --falsify=plainsecret ключ пишется и в profile.cfg открытым текстом — краснеет только «аккаунт:
##                         ключ Claude»;
##   --falsify=noreseal    при смене и снятии PIN секреты не перешифровываются — краснеет только
##                         «аккаунт: PIN перешифровывает»;
##   --falsify=nolight     свет и ambient выключены, как в пустой сцене сессии 13, — краснеет только
##                         «свет сцены»;
##   --falsify=gridfollow  сетка не едет за человеком — краснеет только «сетка пола»;
##   --falsify=gridride    сетка снова берёт ЛОКАЛЬНУЮ позицию головы и едет вместе с origin (дефект
##                         сессии 17) — краснеет только «сетка не едет с человеком»;
##   --falsify=levelflat   у каждого объекта свой материал (вызовов отрисовки больше) — краснеет
##                         только «уровень из данных»;
##   --falsify=menustick   перемещение слушает стики и при открытом шаре — краснеет только «стики
##                         принадлежат меню»;
##   --falsify=walkquiet   непрерывное движение молчит в журнале (слепота сессии 17: двести секунд
##                         ходьбы и ни одной строки) — краснеет только «журнал ходьбы»;
##   --falsify=axisfree    приоритет поворота снят — поворот снова тащит вперёд (дефект
##                         сессии 24); краснеет только «рука движения и поворота»;
##   --falsify=onehand     настройки руки не действуют: движение прибито к левому стику, поворот к
##                         правому — краснеет только «рука движения и поворота»;
##   --falsify=nofall      падение со сцены не ловится — краснеет только «падение и возврат в старт»;
##   --falsify=headchase   origin не компенсирует шаг тела — тело гонится за собственной головой и
##                         уносит человека (дефект сессии 15); краснеет только «тело игрока: голова
##                         на месте»;
##   --falsify=nostep      тело не пробует шаг вверх — краснеет только «тело игрока: ступень»;
##   --falsify=ghost       тело перестаёт быть сплошным — краснеет только «тело игрока: стена»;
##   --falsify=mantlefloor перевал срабатывает и у стоящего на полу — дефект сессии 23, когда захват
##                         нижнего зацепа мгновенно уносил наверх; краснеет только «перевал не
##                         хватает стоящего»;
##   --falsify=mantlejump  origin обнуляется в конце перевала — вид скачком уезжает вбок на всё
##                         накопленное смещение (дефект сессии 22); краснеет только «перевал без
##                         скачка вида»;
##   --falsify=mantlephys  физика тела во время перевала не выключается — человека роняет и тянет
##                         обратно к стене (дефект сессии 20); краснеет только «перевал ставит в
##                         полный рост»;
##   --falsify=spawnblind посадка по геометрии не считается — тело ставится ровно в точку из данных
##                         и висит или тонет вместе с ней; краснеет только «посадка считается
##                         геометрией»;
##   --falsify=climbpush   возврат остатка работает и во время лазанья: origin уезжает от стены,
##                         кисть уходит от зацепа, тело дожимается в стену и хват рвётся сам
##                         (дефект сессии 31) — краснеет только «лазанье у стены»;
##   --falsify=climbdrift  точка захвата снова плывёт за рукой — подъёма не получается (дефект
##                         сессии 17); краснеет только «лазанье поднимает»;
##   --falsify=pushlean    наклон у препятствия снова выталкивает человека (дефект сессии 17: «когда
##                         наклоняюсь у стола, весь передвигаюсь от препятствия») — краснеет только
##                         «тело игрока: наклон у стены»;
##   --falsify=handgreedy  занятая рука берёт ещё один предмет — краснеет только «предмет в руке»;
##   --falsify=heldsolid   предмет в руке остаётся препятствием и выталкивает человека (дефект
##                         сессии 31) — краснеет только «предмет в руке»;
##   --falsify=grabstick   предмет не отпускается — краснеет только «предмет в руке»;
##   --falsify=pullnoline  нить от ладони к предмету не строится — краснеет только «связь при призыве»;
##   --falsify=pullnohl    предмет не выделяется накладкой — краснеет только «связь при призыве»;
##   --falsify=applyball   правка на панели применяет только шар, как до 2026-09-23, — свет и сетка
##                         ждут повторного открытия пункта меню; краснеет только «правка на панели
##                         доходит до мира»;
##   --falsify=handdrops   обход выгрузки не считает занятым ничего — предмет выгружается прямо из
##                         руки человека; краснеет только «предмет из комнаты остаётся в руке при
##                         выгрузке»;
##   --falsify=yawlate     курс телепорта читается на кадре отпускания, где палец уже у центра, —
##                         краснеет только «телепорт по видимой дуге»;
##   --falsify=aimtwice    на отпускании прицел считается заново из дёрнувшейся руки — краснеет
##                         только «телепорт по видимой дуге»;
##   --falsify=arcrebuild  дуга — лучи и новый меш — каждый кадр при неподвижной руке; краснеет
##                         только «телепорт по видимой дуге»;
##   --falsify=aimside     «поворот главнее» действует и при прицеливании — курс вбок обрывает
##                         прицел переносом; краснеет только «курс не обрывает прицел»;
##   --falsify=aimturn     поворот работает и при прицеливании — человек крутится вместо курса;
##                         краснеет только «курс не обрывает прицел»;
##   --falsify=mantlesticks отмена перевала ничего не отменяет — тело уносит обратно на траекторию;
##                         краснеет только «возврат отменяет перевал»;
##   --falsify=turnspam    плавный поворот пишет строку на каждый такт — краснеет только «плавный
##                         поворот отрезками»;
##   --falsify=walkjitter  отрезок ходьбы заявляется любым дёрганьем стика — краснеет только
##                         «короткие рывки ходьбы»;
##   --falsify=transferdumb переносы не помечают себя — сторож рывка снова тратит лимит на телепорты;
##                        краснеет только «наши переносы помечают себя»;
##   --falsify=mantlespot  высота приземления перевала берётся из найденной точки (верх зацепа), а не
##                         с поверхности под точкой приземления — краснеет только «перевал ставит на
##                         площадку, а не на зацеп»;
##   --falsify=triggergame коробка зоны подгрузки строится на слое игры — игрок видит разметку
##                         автора; краснеет только «зона видна и работает скрытой»;
##   --falsify=playmask    маска камеры не смотрит на режим игры — краснеет только «режим игры
##                         прячет и возвращает»;
##   --falsify=groupfree   скрытие группы гасит и столкновения — краснеет только «скрытая группа
##                         держит»;
##   --falsify=holdstuck   удержание ввода копится флагом и не снимается — перемещение выключено
##                         насовсем (дефект сессии 30); краснеет только «перехват ввода
##                         останавливает движение»;
##   --falsify=lockdrift   перехват ввода не гасит начатое движение — человек продолжает ехать,
##                         пока вводит PIN (дефект сессии 29); краснеет только «перехват ввода
##                         останавливает движение»;
##   --falsify=groupmenu   папка групп строится из каталога, а не из уровня, и действие пункта
##                         адресовано не сессии — краснеет только «меню групп из уровня»;
##   --falsify=handoff     отдача управления не бросает начатое касание — краснеет только
##                         «руки: отдача управления» (контроллер отпускает курок — выбор).
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
const Hands := preload("res://input/hand_source.gd")
const Router := preload("res://input/input_router.gd")
const Arbiter := preload("res://input/input_arbiter.gd")
const InputSettings := preload("res://profile/input_settings.gd")
const ProfileStore := preload("res://profile/profile_store.gd")
const ProfileSession := preload("res://profile/profile_session.gd")
const ProfileUI := preload("res://profile/profile_ui.gd")
const AccountService := preload("res://accounts/account_service.gd")
const SecretBox := preload("res://accounts/secret_box.gd")
const FloorGrid := preload("res://world/floor_grid.gd")
const WorldEnv := preload("res://world/environment.gd")
const LevelLoader := preload("res://world/level_loader.gd")
const PlayerBody := preload("res://locomotion/player_body.gd")
const PullViewRes := preload("res://world/pull_view.gd")
const MantleRes := preload("res://locomotion/mantle.gd")
const GrabRes := preload("res://world/grab.gd")
const RoomItems := preload("res://world/room_items.gd")
const LevelStreamRes := preload("res://world/level_stream.gd")
const SettingsApply := preload("res://session/settings_apply.gd")
const LocomotionRes := preload("res://locomotion/locomotion.gd")
const RoomRes := preload("res://world/room.gd")
const SpaceRes := preload("res://world/space.gd")
const LayersRes := preload("res://world/layers.gd")
const VisibilityRes := preload("res://world/visibility.gd")
const TriggerViewRes := preload("res://world/trigger_view.gd")
const ItemRes := preload("res://menu/item.gd")
const SynthHand := preload("res://tests/synth_hand.gd")

const STEPS := ["открыть", "войти коротким", "действия удержанием", "копировать", "вставить",
		"удалить удержанием", "отменить", "линза и захват", "панель и атлас", "мастер",
		"вращение рукой", "правка открыта", "ползунок лучом", "клавиатура лучом", "демонстрация доводки", "журнал", "назад на корне", "замок панели",
		"поиск на панели", "системная клавиатура", "строка найденного", "плюс", "прокрутка панели", "прокрутка правки", "раскладка панели",
		"панель по делу", "страницы", "подписи большой папки", "жест возврата", "встряхивание",
		"руки: кулак и касание", "руки: протяжка и перенос", "руки: отдача управления",
		"ввод после самопроверки", "видно того, кто ведёт", "настройки того, кто ведёт", "смена пользователя",
		"профиль: новый с именем", "профиль: PIN при запуске", "профиль: рост, глаза, место",
		"аккаунт: ключ Claude", "аккаунт: Google по коду", "аккаунт: PIN перешифровывает",
		"свет сцены", "сетка пола", "сетка не едет с человеком", "уровень из данных", "тело игрока: голова на месте",
		"тело игрока: ступень", "тело игрока: стена",
		"тело игрока: наклон у стены", "лазанье поднимает", "перевал ставит в полный рост",
		"перевал без скачка вида", "перевал не хватает стоящего", "предмет в руке", "связь при призыве", "стики принадлежат меню", "журнал ходьбы", "рука движения и поворота",
		"падение и возврат в старт", "комната от шлема",
		"перехват ввода останавливает движение", "предмет в руке не преграждает путь",
		"лазанье у стены: хват держится, мир не едет", "старт стоит на полу",
		"зона с полом: смена асинхронна", "посадка считается геометрией",
		"зона видна и работает скрытой", "режим игры прячет и возвращает", "скрытая группа держит",
		"правка на панели доходит до мира",
		"предмет из комнаты остаётся в руке при выгрузке",
		"телепорт по видимой дуге", "курс не обрывает прицел", "возврат отменяет перевал", "наши переносы помечают себя",
		"плавный поворот отрезками", "короткие рывки ходьбы", "догон головы не двигает вид по вертикали",
		"перевал ставит на площадку, а не на зацеп",
		"меню групп из уровня",
		"раскладки", "выход удержанием"]

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
	# Минимум сессии: правка на панели применяет ВСЁ — шар, свет, сетку, слои. Раньше здесь стояло
	# `menu.apply_settings`, то есть обвязка прибора повторяла дефект приложения и потому не могла
	# его увидеть: она подтверждала собственную копию ошибки (урок ловушки 33).
	_applier_grid = FloorGrid.new()
	_applier_grid.setup(root3d, head)
	_applier.menu = menu
	_applier.floor_grid = _applier_grid
	_applier.falsify_ball_only = falsify == "applyball"
	panel.edit_changed.connect(_applier.apply_all)
	menu.search_requested.connect(func(): panel.open_text("Поиск", ["done"], menu.settings.get_value("search_keyboard")))
	menu.search_closed.connect(func(): if panel.is_text_open(): panel.close_editor())
	panel.text_changed.connect(menu.set_search_query)
	panel.falsify_no_ime = falsify == "imekey"
	panel.falsify_enter_closes = falsify == "enterclose"
	panel.falsify_found_mute = falsify == "found"
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
		[284, _found_open], [285, _found],
		[285, _scroll_prep], [288, _scroll_read], [291, _scroll_check],
		[293, _edit_scroll_open], [296, _edit_scroll_move], [299, _edit_scroll_check],
		[301, _panel_layout_open], [304, _panel_layout], [307, _panel_show], [307, _pages], [307, _big_folder_labels], [306, _gesture_choice], [308, _shake_root],
		[309, _hands_fist_touch], [309, _hands_drag], [309, _hands_handoff],
		[309, _router_ready], [309, _router_visuals], [309, _router_settings], [309, _router_done], [309, _profile_switch], [309, _pui_new], [309, _pui_pin], [309, _pui_body], [309, _acc_key], [309, _acc_google], [309, _acc_pin], [309, _pui_done], [310, _world_light], [310, _world_grid], [310, _grid_fixed], [310, _apply_now], [311, _level_build], [312, _phys_setup],
		[330, _phys_head_prep], [360, _phys_head_check], [380, _phys_step], [470, _phys_wall], [500, _lean_prep], [520, _mantle_floor_check], [545, _lean_check], [556, _mantle_floor_result], [558, _climb_prep], [570, _climb_check], [572, _mantle_prep], [563, _spawn_prep], [568, _spawn_check], [573, _climb_wall_prep], [576, _climb_wall_check], [577, _drop_check], [577, _held_ghost_prep], [579, _held_ghost_check], [580, _grab_check], [580, _pull_link], [581, _stick_owner], [581, _walk_log], [581, _hand_choice], [582, _fall_home], [592, _fall_check], [600, _mantle_check], [601, _mantle_view_check], [582, _room_node],
		[582, _input_lock], [583, _zone_prep], [615, _zone_check], [616, _play_mode], [617, _group_solid], [618, _group_menu], [620, _area_wait_prep], [640, _area_wait_check],
		[642, _carry_prep], [646, _carry_check],
		[650, _tp_prep], [654, _tp_seen], [655, _tp_side], [656, _mantle_cancel], [656, _transfer_marks], [657, _turn_segments],
		[658, _walk_jitter], [660, _follow_y_prep], [664, _follow_y_jump], [720, _follow_y_check],
		[722, _mantle_top_prep], [728, _mantle_top_check],
		[310, _layouts], [314, _exit_hold], [320, _finish],
	]


## Предел кадров: ошибка в сборке (скрипт не скомпилировался, шаг упал) не должна
## вешать прогон навсегда — 2026-09-15 он простоял 300 с на ошибке разбора.
const MAX_FRAMES := 1200


func _process(_delta: float) -> bool:
	_frame += 1
	# Человек ИДЁТ, а не толкается раз: при столкновении скорость гасится, и шаг вверх пробуется,
	# только пока движение продолжается (как и в приложении, где стик держат).
	# Приземление копим по КАДРАМ, а не читаем в один момент: число физических тиков между шагами
	# прибора не постоянно, и проверка «упало на пол» краснела примерно в каждом третьем прогоне,
	# хотя код был верен (§2.7 — плавающая проверка хуже отсутствующей).
	if _player != null and is_instance_valid(_player) and _phys.get("landing", false):
		if _player.is_on_floor():
			_phys["landed"] = true
		_phys["floor_y"] = minf(float(_phys.get("floor_y", 9.0)), absf(_player.global_position.y))
	# Стенд «перевал не хватает стоящего»: тактуем поиск перевала, пока тело стоит на полу.
	if not _floor_t.is_empty() and is_instance_valid(_floor_t["body"]):
		(_floor_t["loco"] as LocomotionRes)._try_mantle(1.0 / 90.0, {"right": _floor_t["hand"]})
		_floor_t["ticks"] = int(_floor_t.get("ticks", 0)) + 1
	# Перевал идёт кадрами, как в приложении: locomotion двигает тело, физика тела молчит.
	if not _mantle_t.is_empty() and is_instance_valid(_mantle_t["body"]):
		var mb: PlayerBody = _mantle_t["body"]
		var mt: float = float(_mantle_t.get("t", 0.0)) + (1.0 / 90.0) / MantleRes.RISE_S
		_mantle_t["t"] = mt
		# Переносим, только пока тело отдано нам. Если физику не выключили (фальсификатор), телом
		# распоряжается она: тяготение роняет, следование тянет назад — ровно дефект сессии 20.
		if mb.mantling:
			mb.global_position = MantleRes.rise_point(_mantle_t["from"], _mantle_t["to"], mt)
			_mantle_t_view.append((_mantle_t["head"] as Node3D).global_position)
			if mt >= 1.0:
				mb.mantling = false
				mb.release_collisions()
				# Дефект сессии 22: обнуление origin в конце — скачок вида на всё накопленное.
				if falsify == "mantlejump":
					(_mantle_t["origin"] as Node3D).position = Vector3(0, 0, 0)
				_mantle_t_view.append((_mantle_t["head"] as Node3D).global_position)
	if _player != null and is_instance_valid(_player) and _phys.get("walk", "") != "":
		_player.velocity.z = -1.2 if _phys["walk"] == "stairs" else 1.5
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
	# Ввод и профиль — в каждой строке (сессия 11: источник восстанавливали по строкам «источник»).
	Journal.falsify_old_keys = falsify == "nocolumns"
	var was := [menu.input_source, menu.profile_id]
	menu.input_source = "hands"
	menu.profile_id = "p_test"
	var line := Journal.row("проверка", menu.params(), "", "", -1, "x")
	menu.input_source = was[0]
	menu.profile_id = was[1]
	Journal.falsify_old_keys = false
	var cells := line.split("\t")
	var radius_col := Journal.COLUMNS.find("радиус_см")
	if cells.size() == Journal.COLUMNS.size() and cells[radius_col] == str(menu.settings.get_value("radius_cm")) \
			and cells[Journal.COLUMNS.find("поверхность")] != "" and cells[Journal.COLUMNS.find("ввод")] == "hands" \
			and cells[Journal.COLUMNS.find("профиль")] == "p_test":
		r.pass_("журнал: %d колонок, радиус %s, поверхность %s, ввод и профиль в строке" % [cells.size(), cells[radius_col], cells[2]])
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


## Строка «найдено: N» под словом (сессия 10): владелец набрал слово, которого в каталоге нет,
## и по пустому шару не отличил «не нашлось» от «поиск не работает». Пустой запрос строки не
## показывает — иначе «ничего не найдено» висело бы до первой буквы.
##
## Набор — раскладкой лучом, а не системной клавиатурой: счёт живёт в общем пути
## SphereMenu.set_search_query, и шаг не должен падать заодно с «imekey».
func _found_open() -> void:
	menu.settings.values["search_keyboard"] = "panel"
	_to_root_open()
	_tap(_key_of(_slot_of("home_search")))


func _found() -> void:
	var p: Panel3D = menu.panel
	var at_open := p.found_text()
	_type_keys(p, ["М", "О", "С", "Т"])
	var hit := p.found_text()
	var n: int = menu.found_count()
	_type_keys(p, ["Щ"])
	var miss := p.found_text()
	_type_keys(p, ["C"])
	var cleared := p.found_text()
	p.pointer_update(null, false)
	menu.back()
	if at_open == "" and n >= 1 and hit == "найдено: %d" % n and miss == "ничего не найдено" and cleared == "":
		r.pass_("строка найденного: при открытии пусто, «мост» → «%s» (пунктов на шаре %d), «мостщ» → «%s», очистка гасит строку" % [hit, n, miss])
	else:
		r.fail("строка найденного: при открытии «%s», «мост» → «%s» при %d пунктах, «мостщ» → «%s», после очистки «%s»" % [
				at_open, hit, n, miss, cleared])


## Нажать лучом клавиши панельной раскладки по их подписям.
func _type_keys(p: Panel3D, keys: Array) -> void:
	for k in keys:
		var btn: Button = null
		for c in p._text_box.get_children():
			if (c as Button).text == k:
				btn = c
		if btn == null:
			continue
		var px: Variant = _aim(_center_px(btn))
		p.pointer_update(px, false)
		p.pointer_update(px, true)
		p.pointer_update(px, false)


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


# --- руки (шаг 1к) ---------------------------------------------------------------
#
# Источник рук целиком — input/hand_source.gd над настоящим меню; вместо трекеров шлема —
# синтетические (tests/synth_hand.gd). Трекер повёрнут и сдвинут относительно мира, как
# XROrigin3D на шлеме: суставы приходят в его пространстве, и перевод в мир проверяется.

var hands: Hands
var _lt := XRHandTracker.new()
var _rt := XRHandTracker.new()
var _oxf := Transform3D(Basis(Vector3.UP, 0.4), Vector3(0.3, 0.0, -0.2))
var _hand_us := 0
var _gest: Array = []
## Левая рука ладонью вверх, пальцы вперёд, в мире.
var _left_wrist := Vector3.ZERO


func _hands_ready() -> void:
	if hands != null:
		return
	var root3d := head.get_parent()
	hands = Hands.new()
	root3d.add_child(hands)
	hands.setup(root3d, menu, root3d)
	# step() кормится вручную: _process источника молчит, пока enabled = false.
	hands.enabled = false
	hands.falsify_drag_selects = falsify == "dragselect"
	hands.falsify_keep_on_release = falsify == "handoff"
	hands.gesture.connect(func(n: String, d: Dictionary): _gest.append([n, d]))
	menu.hand = hands.anchor
	menu.hand_offset = Vector3(0, 0.06, -0.1)
	menu.settings.values["hand_rotation"] = "ball"
	menu.settings.values["hand_smoothing"] = 0.0
	menu.apply_settings()
	_left_wrist = head.global_position + Vector3(0, -0.45, -0.25)
	_hand_us = _t * 1000


func _set_left(curl: float) -> void:
	var inv := _oxf.affine_inverse()
	SynthHand.pose(_lt, true, inv * _left_wrist, inv.basis * Vector3.FORWARD, inv.basis * Vector3.UP,
			SynthHand.curls(curl))


## Кончик правого указательного — в точку мира, палец смотрит в центр шара.
func _set_right_tip(world_tip: Vector3) -> void:
	var inv := _oxf.affine_inverse()
	var fwd := (menu.global_position - world_tip).normalized()
	var up := Vector3.UP if absf(fwd.y) < 0.9 else Vector3.BACK
	SynthHand.point_at(_rt, inv * world_tip, inv.basis * fwd, inv.basis * up)


## Точка на расстоянии off от поверхности шара над ячейкой key, в мире.
## Ключа нет (шаг раньше не вошёл в папку) — точка далеко от шара: касания не будет, шаг
## краснеет своим отказом, а не ошибкой выполнения.
func _over(key: Variant, off: float) -> Vector3:
	if key == null:
		return menu.global_position + Vector3(0.5, 0, 0)
	return menu.global_transform * (menu.surface().direction_of(key) * (menu.radius() + off))


func _hand_frame() -> void:
	hands.step(_lt, _rt, _oxf, head.global_transform, _hand_us, 1.0 / 90.0)
	menu._process(1.0 / 90.0)
	_hand_us += 11111
	_t = _hand_us / 1000


## Тычок кончиком в ячейку: подход с 5 см, 4 кадра на поверхности, отход.
func _hand_poke(key: Variant) -> void:
	for off in [0.05, 0.04, 0.03, 0.02, 0.01, 0.004, 0.003, 0.003, 0.004, 0.01, 0.02, 0.04, 0.05]:
		_set_right_tip(_over(key, off))
		_hand_frame()


func _gest_count(name: String) -> int:
	return _gest.filter(func(g: Array): return g[0] == name).size()


## Кулак левой открывает шар; касаниями правой — «Файлы» → «Ассеты».
func _hands_fist_touch() -> void:
	_hands_ready()
	_gest.clear()
	# Перевод из пространства трекера — механика всех трёх шагов; фальсификатор бьёт только здесь.
	hands.falsify_world_space = falsify == "handspace"
	menu.close()
	_set_right_tip(_left_wrist + Vector3(0.3, 0, 0))
	for c in [0.02, 0.62, 0.02]:
		_set_left(c)
		for _i in 10:
			_hand_frame()
	var opened := menu.is_open()
	_hand_poke(_key_of(_slot_of("files")))
	var after_files := menu.nav.state.folder()
	_hand_poke(_key_of(_slot_of("assets")))
	var folder := menu.nav.state.folder()
	if opened and _gest_count("fist") == 1 and after_files == "files" and folder == "assets" \
			and _gest_count("touch") == 2 and _gest_count("drag") == 0:
		r.pass_("руки: кулак открыл шар, касания вошли в «Файлы» → «Ассеты» (трекер повёрнут и сдвинут от мира)")
	else:
		r.fail("руки: открыт %s, после «Файлов» «%s», итог «%s», жесты %s" % [opened, after_files, folder, _gest])
	hands.falsify_world_space = false


## Протяжка 5 см по поверхности, начатая на «Файлах», вращает шар и не выбирает (коротким
## «Файлы» открылись бы — так отказ виден, в отличие от пустой ячейки); кончик в 4 см от шара, пока его
## несут вместе с рукой, — ни одного касания.
func _hands_drag() -> void:
	_hands_ready()
	_gest.clear()
	_to_root_open()
	_set_left(0.02)
	for _i in 3:
		_hand_frame()
	var folder := menu.nav.state.folder()
	var key: Variant = _key_of(_slot_of("files"))
	var basis0: Basis = menu.surface().render_basis()
	var local0: Vector3 = menu.surface().direction_of(key)
	var axis: Vector3 = local0.cross(Vector3.UP).normalized()
	var arc := 0.05 / menu.radius()
	for off in [0.05, 0.03, 0.01, 0.004]:
		_set_right_tip(menu.global_transform * (local0 * (menu.radius() + off)))
		_hand_frame()
	# Палец ведёт по неподвижным мировым точкам: шар поворачивается под ним.
	var start_world: Vector3 = menu.global_transform.basis * local0
	for i in 25:
		var d: Vector3 = start_world.rotated(axis, arc * float(i + 1) / 25.0)
		_set_right_tip(menu.global_position + d * (menu.radius() + 0.004))
		_hand_frame()
	var last_world: Vector3 = start_world.rotated(axis, arc)
	_set_right_tip(menu.global_position + last_world * (menu.radius() + 0.05))
	_hand_frame()
	var turned: float = menu.surface().render_basis().get_rotation_quaternion().angle_to(basis0.get_rotation_quaternion())
	var dragged := _gest_count("drag")
	var selected := menu.nav.state.folder() != folder or _gest_count("touch") > 0
	# Перенос: шар несут на 15 см, правая рука идёт рядом в 4 см от поверхности с дрожью 3 мм.
	var touches_before := _gest.size()
	var wrist0 := _left_wrist
	for i in 90:
		_left_wrist = wrist0 + Vector3(0.15 * i / 90.0, 0.03 * sin(i * 0.1), 0)
		_set_left(0.02)
		var d := (head.global_position - menu.global_position).normalized()
		_set_right_tip(menu.global_position + d * (menu.radius() + 0.04 + 0.003 * sin(i * 1.7)))
		_hand_frame()
	_left_wrist = wrist0
	var carry_touches := _gest.size() - touches_before
	if dragged == 1 and not selected and turned > 0.2 and carry_touches == 0 and menu.nav.state.folder() == folder:
		r.pass_("руки: протяжка 5 см повернула шар на %.2f рад без выбора; перенос с кончиком в 4 см — ни одного касания" % turned)
	else:
		r.fail("руки: протяжек %d, выбор %s, поворот %.2f рад, касаний при переносе %d, жесты %s" % [
				dragged, selected, turned, carry_touches, _gest])


## Управление забирают посреди касания: начатое бросается без события. Контроллер после
## этого отпускает курок каждый кадр (controller_source.gd) — выбора быть не должно.
func _hands_handoff() -> void:
	_hands_ready()
	_gest.clear()
	_to_root_open()
	_set_left(0.02)
	var key: Variant = _key_of(_slot_of("files"))
	for off in [0.05, 0.02, 0.004, 0.003, 0.003]:
		_set_right_tip(_over(key, off))
		_hand_frame()
	var was_down := menu.press_right.is_down()
	hands.release()
	for _i in 5:
		menu.press_key(null, false, _t)
		_t += 11
	var folder := menu.nav.state.folder()
	var clean := not menu.press_right.is_down() and not hands.touch.inside
	menu.hand = null
	if was_down and folder == "" and clean:
		r.pass_("руки: отдача посреди касания — нажатие брошено, контроллер отпустил курок без выбора")
	else:
		r.fail("руки: нажатие было %s, папка после отдачи «%s», чисто %s" % [was_down, folder, clean])


# --- роутер ввода (input/input_router.gd) ------------------------------------------
#
# Свидетели — синтетические, как в настольной проверке арбитра: роутер не спрашивает XRServer.

var router: Router
var _rt_ms := 0


func _witness(profile: String, pose: bool, hand_ok: bool) -> Dictionary:
	return {"profile": {"left": profile, "right": profile}, "ctrl_pose": {"left": pose, "right": pose},
			"ctrl_in": {}, "hand_ok": {"left": hand_ok, "right": hand_ok}, "hand_src": {}}


## Кормить роутер свидетелем ms миллисекунд шагами по 11 мс.
func _router_feed(w: Dictionary, ms: int) -> void:
	var end := _rt_ms + ms
	while _rt_ms < end:
		router.feed(_rt_ms, w)
		_rt_ms += 11


func _router_make() -> void:
	if router != null:
		return
	var root3d := head.get_parent()
	var l := XRController3D.new()
	l.tracker = &"left_hand"
	root3d.add_child(l)
	var rr := XRController3D.new()
	rr.tracker = &"right_hand"
	root3d.add_child(rr)
	router = Router.new()
	router.auto_observe = false
	router.falsify_ignore_ready = falsify == "earlyinput"
	root3d.add_child(router)
	router.setup(root3d, l, rr, menu, menu.panel, root3d)
	router.hand_view.falsify_mesh_stays = falsify == "meshstays"


## До готовности (идёт самопроверка) арбитр видит руки, их видно, но ни один источник меню не
## трогает; после готовности управление получают руки.
func _router_ready() -> void:
	_router_make()
	_router_feed(_witness(Arbiter.HAND_PROFILE, true, true), 600)
	var before := [router.current(), router.hands.enabled, router.controllers.enabled, router.hand_view.active]
	router.set_ready()
	var after := [router.hands.enabled, router.controllers.enabled, menu.hand == router.hands.anchor]
	if before == [Arbiter.HANDS, false, false, true] and after == [true, false, true]:
		r.pass_("ввод после самопроверки: до готовности руки видны, но меню не трогают; после — ведут руки, шар на их якоре")
	else:
		r.fail("ввод после самопроверки: до готовности [источник, руки, контроллеры, руки видны] = %s, после [руки, контроллеры, шар на якоре] = %s" % [before, after])


## Взяли контроллеры — суставы и силуэт рук пропадают, даже когда движок сам показывает узел руки
## при смене трекинга; модели контроллеров появляются. Модель рантайма не пришла за FALLBACK_MS от
## взятия контроллеров — запасная, но не раньше; пришла позже — запасная прячется. Положили
## контроллеры — руки: при готовой сетке рук точек суставов нет.
func _router_visuals() -> void:
	_router_make()
	var cv := router.controller_view
	var hv := router.hand_view
	cv.falsify_since_zero = falsify == "fallbacknow"
	cv.falsify_fallback_stays = falsify == "fallbackstays"
	hv.falsify_joints_stay = falsify == "jointsstay"
	var bad: Array[String] = []
	_router_feed(_witness("/interaction_profiles/oculus/touch_controller", true, false), 22)
	var t0 := Time.get_ticks_msec()
	if router.current() != Arbiter.CONTROLLERS:
		bad.append("источник %s" % router.current())
	# Движок показывает узел руки с show_when_tracked при смене трекинга (xr_nodes.cpp:466).
	for holder in hv.meshes:
		(holder.get_parent() as Node3D).visible = true
	if hv.anything_visible():
		bad.append("при контроллерах видно руки (силуэтов %d)" % hv.meshes.size())
	if cv.fb_models.is_empty() or not cv.anything_visible():
		bad.append("моделей контроллеров нет: FB %d, видно %s" % [cv.fb_models.size(), cv.anything_visible()])
	var early := cv.update(t0 + cv.FALLBACK_MS - 100)
	if early != "" or cv.fallback_visible():
		bad.append("запасная раньше срока: «%s» за %d мс" % [early, cv.FALLBACK_MS - 100])
	var late := cv.update(t0 + cv.FALLBACK_MS + 1)
	if late != "запасные" or not cv.fallback_visible():
		bad.append("без модели рантайма через %d мс: «%s», запасная видна %s" % [cv.FALLBACK_MS, late, cv.fallback_visible()])
	cv.on_runtime_loaded("FB")
	var upgrade := cv.update(t0 + cv.FALLBACK_MS + 50)
	if upgrade != "запасные → FB" or cv.fallback_visible():
		bad.append("модель рантайма пришла позже: «%s», запасная видна %s" % [upgrade, cv.fallback_visible()])
	for key in ["L", "R"]:
		hv.on_mesh_ready(key)
	_router_feed(_witness(Arbiter.HAND_PROFILE, true, true), 600)
	var joints_seen := hv.joints.any(func(m: MultiMeshInstance3D): return m.visible)
	if cv.anything_visible() or not hv.anything_visible() or joints_seen:
		bad.append("руки снова: контроллеры видны %s, руки видны %s, точки суставов %s" % [cv.anything_visible(),
				hv.anything_visible(), joints_seen])
	if bad.is_empty():
		r.pass_("видно того, кто ведёт: контроллеры — руки спрятаны и при показе движком (силуэтов %d), модели Meta %d, запасная ровно через %d мс и уходит, когда пришла модель рантайма; руки — сетка без точек" % [
				hv.meshes.size(), cv.fb_models.size(), cv.FALLBACK_MS])
	else:
		r.fail("видно того, кто ведёт: %s" % "; ".join(bad))


## Смена источника через роутер меняет набор настроек настоящего меню: радиус шара, заголовок папки
## настроек, стик в ней. Наборы — во временном каталоге; настройки прогона потом возвращаются.
func _router_settings() -> void:
	_router_make()
	var dir := "user://smoke_input_settings"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var saved := [menu.settings.values.duplicate(), menu.settings.path, menu.settings.common_path, menu.settings.input]
	for pair in [["controllers", 9.0], ["hands", 16.0]]:
		var cf := ConfigFile.new()
		cf.set_value("sphere", "radius_cm", pair[1])
		cf.save(dir.path_join("settings_%s.cfg" % pair[0]))
	var ins := InputSettings.new(menu.settings, dir)
	ins.current = router.current()
	ins.load_current()
	menu.apply_settings()
	router.input_settings = ins
	router.falsify_no_switch = falsify == "noswitch"
	_to_root_open()
	var got := {}
	for step in [["/interaction_profiles/oculus/touch_controller", false, "контроллеры"],
			[Arbiter.HAND_PROFILE, true, "руки"]]:
		_router_feed(_witness(step[0], true, step[1]), 600)
		var folder = menu.catalog.items["settings_sphere"]
		got[step[2]] = [snappedf(menu.radius() * 100.0, 0.1), folder.title,
				"set_stick_speed" in (menu.catalog.children_of["settings_sphere"] as Array)]
	router.input_settings = null
	menu.settings.values = saved[0]
	menu.settings.path = saved[1]
	menu.settings.common_path = saved[2]
	menu.settings.input = saved[3]
	menu.apply_settings()
	menu.catalog.apply_input(menu.settings)
	for f in ["settings_controllers.cfg", "settings_hands.cfg", "settings_common.cfg"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(dir.path_join(f)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(dir))
	var want := {"контроллеры": [9.0, "Шар-меню — контроллеры", true], "руки": [16.0, "Шар-меню — руки", false]}
	if got == want:
		r.pass_("настройки того, кто ведёт: контроллеры — шар 9 см, руки — 16 см, папка настроек по вводу, стик только у контроллеров")
	else:
		r.fail("настройки того, кто ведёт: %s, ожидалось %s" % [got, want])


## Роутер больше не нужен: его источники не должны трогать меню в следующих шагах.
func _router_done() -> void:
	router.hands.release()
	router.controllers.release()
	router.set_process(false)
	menu.hand = null


## Смена пользователя меняет всё пользовательское в живом меню: радиус шара (набор настроек
## активного ввода) и избранное; второй профиль без избранного не наследует чужое. Хранилище — во
## временном каталоге; настройки и избранное прогона потом возвращаются.
func _profile_switch() -> void:
	var root := "user://smoke_profiles"
	var saved := [menu.settings.values.duplicate(), menu.settings.path, menu.settings.common_path,
			menu.settings.input, menu.catalog.favorites.duplicate(), menu.profile_id]
	var store := ProfileStore.new(root)
	store.load_index()
	var a := store.create("Аня")
	var b := store.create("Борис")
	# «Лес» — обычный объект: пункты корня («Файлы») избранным не бывают (catalog.load_favorites).
	for pair in [[a, 9.0, ["scene_forest"]], [b, 16.0, []]]:
		var cf := ConfigFile.new()
		cf.set_value("sphere", "radius_cm", pair[1])
		cf.save(store.dir_of(pair[0]).path_join("settings_controllers.cfg"))
		if not (pair[2] as Array).is_empty():
			var fav := ConfigFile.new()
			fav.set_value("menu", "favorites", pair[2])
			fav.save(store.dir_of(pair[0]).path_join("favorites.cfg"))
	var ps := ProfileSession.new(store, menu)
	ps.falsify_stale = falsify == "staleprofile"
	var got := {}
	for id in [a, b]:
		ps.open(id, "controllers")
		got[store.index[id]["name"]] = [snappedf(menu.radius() * 100.0, 0.1), menu.catalog.favorites.duplicate(),
				menu.profile_id == id]
	# Вернуть прогону его настройки и избранное; хранилище — убрать.
	menu.settings.values = saved[0]
	menu.settings.path = saved[1]
	menu.settings.common_path = saved[2]
	menu.settings.input = saved[3]
	menu.catalog.favorites = saved[4]
	menu.profile_id = saved[5]
	menu.apply_settings()
	_rm_tree(root)
	var want := {"Аня": [9.0, ["scene_forest"], true], "Борис": [16.0, [], true]}
	if got == want:
		r.pass_("смена пользователя: Аня — шар 9 см и «Лес» в избранном, Борис — 16 см и пустое избранное, id профиля в журнале сменился")
	else:
		r.fail("смена пользователя: %s, ожидалось %s" % [got, want])


# --- интерфейс профиля (profile/profile_ui.gd) ---------------------------------------
#
# Настоящее меню и панель; хранилище — во временном каталоге. XR-пространство поднято над миром
# на 0.5 м: высота глаз обязана считаться от его пола.

var pui: ProfileUI
var _pui_saved: Array = []
var _pui_root := "user://smoke_profiles_ui"


func _pui_make() -> void:
	if pui != null:
		return
	_pui_saved = [menu.settings.values.duplicate(), menu.settings.path, menu.settings.common_path,
			menu.settings.input, menu.catalog.favorites.duplicate(), menu.profile_id]
	_rm_tree(_pui_root)
	var store := ProfileStore.new(_pui_root)
	store.ensure_default()
	var ps := ProfileSession.new(store, menu)
	ps.open(store.startup_id(), "controllers")
	menu.settings.values["search_keyboard"] = "panel"
	pui = ProfileUI.new(ps, menu, menu.panel)
	var root3d := head.get_parent()
	var xr_origin := Node3D.new()
	xr_origin.position = Vector3(0, 0.5, 0)
	root3d.add_child(xr_origin)
	var xr_head := Node3D.new()
	xr_head.position = Vector3(0.1, 1.62, 0.2)
	xr_origin.add_child(xr_head)
	pui.origin = xr_origin
	pui.head = xr_head
	pui.play_area = func() -> PackedVector3Array:
		return PackedVector3Array([Vector3(-1, 0, -1), Vector3(1, 0, -1), Vector3(1, 0, 1), Vector3(-1, 0, 1)])
	pui.falsify_no_lock = falsify == "nolock"
	pui.falsify_eye_world = falsify == "eyeworld"
	menu.profile_action.connect(pui.on_action)
	pui.rebuild()


## Набрать на панели и нажать «Готово» — как лучом по кнопкам раскладки.
func _pui_type(t: String) -> void:
	for c in t:
		menu.panel._on_text_key(c)
	pui.on_button("done")


## «Новый профиль» — касанием пункта в папке профиля (путь навигатор → сигнал меню → действие),
## имя набрано на панели; новый профиль стал активным, и папка называется его именем.
func _pui_new() -> void:
	_pui_make()
	_to_root_open()
	_tap(_key_of(_slot_of("settings")))
	_tap(_key_of(_slot_of("profile")))
	_tap(_key_of(_slot_of("profile_switch")))
	_tap(_key_of(_slot_of("pf_new")))
	var asked := pui.purpose
	_pui_type("МИР")
	var st := pui.profiles.store
	var folder = menu.catalog.items.get("profile", null)
	var title: String = folder.title if folder != null else ""
	if asked == "new" and st.order.size() == 2 and pui.profiles.profile.name == "Мир" and title == "Профиль: Мир" \
			and st.startup_id() == pui.profiles.profile.id:
		r.pass_("профиль: новый с именем — касанием «Новый профиль», набрано «МИР», стал активным «Мир», папка «Профиль: Мир»")
	else:
		r.fail("профиль: новый с именем: спрошено «%s», профилей %d, активный «%s», папка «%s»" % [asked, st.order.size(),
				pui.profiles.profile.name, title])


## PIN при запуске: ввод включён сразу (иначе PIN не набрать), шар заперт — не закрывается и не
## нажимается; неверный PIN не пускает и очищает поле, верный — отпирает.
func _pui_pin() -> void:
	_pui_make()
	var p = pui.profiles.profile
	p.set_pin("2468", 100)
	pui.profiles.store.save_profile(p)
	menu.close()
	var ready_called := [false]
	pui.start(func(): ready_called[0] = true)
	var locked_open := [menu.is_open(), menu.locked, pui.purpose]
	menu.toggle()
	var still_open := menu.is_open()
	var folder_before := menu.nav.state.folder()
	_tap(_key_of(_slot_of("files")))
	var pressed_through := menu.nav.state.folder() != folder_before
	_pui_type("1111")
	var after_wrong := [menu.locked, menu.panel.hint_text(), menu.panel.text]
	_pui_type("2468")
	var after_right := [menu.locked, pui.purpose]
	if ready_called[0] and locked_open == [true, true, "pin_check"] and still_open and not pressed_through \
			and after_wrong == [true, "Неверный PIN", ""] and after_right == [false, ""]:
		r.pass_("профиль: PIN при запуске — ввод включён, шар заперт (не закрылся, «Файлы» не открылись), неверный PIN не пустил, верный отпер")
	else:
		r.fail("профиль: PIN при запуске: готов %s, [открыт, заперт, ввод] %s, после попытки закрыть %s, нажатие прошло %s, после неверного %s, после верного %s" % [
				ready_called[0], locked_open, still_open, pressed_through, after_wrong, after_right])


## Рост цифрами, высота глаз — от пола XR-пространства (поднятого над миром на 0.5 м), место — по
## игровой зоне, повторно — то же место; удаление профиля возвращает к оставшемуся.
func _pui_body() -> void:
	_pui_make()
	pui.on_action("profile_height", "")
	_pui_type("180")
	pui.on_action("profile_eye", "")
	# Замер высоты глаз идёт окном (world/eye_measure.gd): кормим кадрами, как main.gd.
	for _i in 200:
		if not pui.tick_eye(1.0 / 90.0):
			break
	pui.on_action("profile_place", "")
	pui.on_action("profile_place", "")
	# Граница выключена (сессии 13–14): зоны нет. Место запоминается, а повтор обновляет его, а не
	# плодит копии.
	pui.play_area = func() -> PackedVector3Array: return PackedVector3Array()
	pui.play_area_mode = func() -> int: return 0
	pui.on_action("profile_place", "")
	pui.on_action("profile_place", "")
	var p = pui.profiles.profile
	var got := [p.height_cm, p.eye_m, p.places.size(), menu.catalog.items["pf_height"].title,
			menu.catalog.items["pf_place"].title]
	# Папка проектов: пустая — одна строка «почему пусто»; со ссылкой — ссылка, без выдуманных пунктов.
	var empty_kids: Array = (menu.catalog.children_of.get("profile_projects", []) as Array).duplicate()
	p.projects = [{"id": "jtest", "title": "Замок", "path": "castle", "opened_unix": 0, "state": {}}]
	pui.rebuild()
	var one_kids: Array = (menu.catalog.children_of.get("profile_projects", []) as Array).duplicate()
	var proj_title: String = menu.catalog.items["profile_projects"].title
	p.projects = []
	pui.rebuild()
	got.append_array([empty_kids, one_kids, proj_title])
	var deleted_name: String = p.name
	pui.on_action("profile_delete", "")
	var left := [pui.profiles.store.order.size(), pui.profiles.profile.name]
	var want := [180.0, 1.62, 1, "Рост: 180 см", "Запомнить это место (мест: 1)", ["pf_projects_none"],
			["pf_project_jtest"], "Проекты (1)"]
	if got == want and left == [1, "Основной"]:
		r.pass_("профиль: рост, глаза, место — 180 см, глаза 1,62 м от пола XR-пространства, место одно после двух «запомнить» и повторов без границы, папка проектов честная; удалён «%s», активен «Основной»" % deleted_name)
	else:
		r.fail("профиль: рост, глаза, место: %s, ожидалось %s; после удаления %s" % [got, want, left])


# --- аккаунты (accounts/account_service.gd) — сеть подменена готовыми ответами --------

const GOOD_KEY := "sk-ant-Api03-GoodKEY-xyz"
var acc: AccountService
var _requests: Array = []
var _token_polls := 0
var _fake_ms := 0


## Готовые ответы вместо сети: Anthropic признаёт только GOOD_KEY в x-api-key; Google — код, одно
## «ждём», затем токены; about — адрес.
func _fake_transport(req: Dictionary) -> Dictionary:
	_requests.append(req)
	var url: String = req["url"]
	var headers: PackedStringArray = req["headers"]
	if url == "https://api.anthropic.com/v1/models":
		if ("x-api-key: " + GOOD_KEY) in headers:
			return {"code": 200, "body": '{"data":[{"id":"a"},{"id":"b"},{"id":"c"}]}', "error": OK}
		return {"code": 401, "body": '{"type":"error"}', "error": OK}
	if url == "https://oauth2.googleapis.com/device/code":
		return {"code": 200, "error": OK, "body": '{"device_code":"DC","user_code":"WXYZ-1234","verification_url":"https://www.google.com/device","expires_in":1800,"interval":5}'}
	if url == "https://oauth2.googleapis.com/token":
		var body: String = req["body"]
		if body.contains("grant_type=refresh_token"):
			return {"code": 200, "error": OK, "body": '{"access_token":"AT2","expires_in":3599}'}
		_token_polls += 1
		if _token_polls == 1:
			return {"code": 428, "error": OK, "body": '{"error":"authorization_pending"}'}
		return {"code": 200, "error": OK, "body": '{"access_token":"AT","refresh_token":"1//RT","expires_in":3599}'}
	if url.begins_with("https://www.googleapis.com/drive/v3/about"):
		return {"code": 200, "error": OK, "body": '{"user":{"emailAddress":"owner@example.com"}}'}
	return {"code": 404, "body": "", "error": OK}


func _acc_make() -> void:
	if acc != null:
		return
	_pui_make()
	acc = AccountService.new(pui.profiles, _fake_transport)
	acc.now_ms = func() -> int: return _fake_ms
	acc.oauth = {"google": {"client_id": "cid", "client_secret": "csec"}}
	acc.falsify_plain = falsify == "plainsecret"
	acc.changed.connect(pui.on_accounts_changed)
	pui.accounts = acc
	pui.falsify_no_reseal = falsify == "noreseal"
	menu.panel.falsify_lower_always = falsify == "keylower"
	pui.rebuild()


## Ключ Claude набран системной клавиатурой (события IME, как на шлеме), регистр сохранён; проверка
## прошла; ключ лежит только в secrets.enc — не в profile.cfg и не в журнале.
func _acc_key() -> void:
	_acc_make()
	menu.settings.values["search_keyboard"] = "system"
	var logs: Array = []
	acc.logged.connect(func(ev: String, d: String): logs.append(d))
	pui.on_action("profile_account", "claude")
	for c in GOOD_KEY:
		var ev := InputEventKey.new()
		ev.pressed = true
		ev.unicode = c.unicode_at(0)
		menu.panel._input(ev)
	var typed_ok: bool = menu.panel.text == GOOD_KEY
	pui.on_button("done")
	var st: String = acc.status_text("claude")
	var cfg := FileAccess.get_file_as_string(pui.profiles.dir().path_join("profile.cfg"))
	var sealed: Variant = SecretBox.load_from(pui.profiles.dir(), pui.profiles.secret_root())
	var in_box: bool = sealed is Dictionary and (sealed as Dictionary).get("claude", {}).get("key", "") == GOOD_KEY
	var leaked := cfg.contains(GOOD_KEY) or logs.any(func(d: String): return d.contains(GOOD_KEY))
	var title: String = menu.catalog.items["pf_acc_claude"].title
	menu.settings.values["search_keyboard"] = "panel"
	if typed_ok and st.begins_with("подключён") and in_box and not leaked and title.contains("подключён"):
		r.pass_("аккаунт: ключ Claude — набран IME с заглавными, «%s», в secrets.enc — да, в profile.cfg и журнале — нет" % st)
	else:
		r.fail("аккаунт: ключ Claude: набрано верно %s («%s»), статус «%s», в secrets.enc %s, утёк %s, пункт «%s»" % [
				typed_ok, menu.panel.text, st, in_box, leaked, title])


## Google: код и адрес на панели, опрос не раньше интервала, «ждём» — ждём, затем вход; токен
## обновления — в секретах, адрес — из Drive.
func _acc_google() -> void:
	_acc_make()
	_fake_ms = 0
	pui.on_action("profile_account", "google")
	var shown: Array = [acc.flow != null and acc.flow.state == "waiting", acc.flow.user_code if acc.flow != null else ""]
	var polls_before := _token_polls
	_fake_ms = 2000
	acc.tick()
	var early_polls := _token_polls - polls_before
	_fake_ms = 5000
	acc.tick()
	_fake_ms = 10000
	acc.tick()
	var st: String = acc.status_text("google")
	var has_rt: bool = pui.profiles.secrets.get("google", {}).get("refresh_token", "") == "1//RT"
	if shown == [true, "WXYZ-1234"] and early_polls == 0 and _token_polls - polls_before == 2 and has_rt \
			and st == "подключён — owner@example.com" and acc.flow == null:
		r.pass_("аккаунт: Google по коду — код WXYZ-1234 на панели, опрос не раньше 5 с, «ждём» и вход, токен обновления в секретах, «%s»" % st)
	else:
		r.fail("аккаунт: Google по коду: показано %s, опросов раньше срока %d, всего %d, токен %s, статус «%s»" % [
				shown, early_polls, _token_polls - polls_before, has_rt, st])
	pui.on_button("cancel")


## Задать PIN — секреты перешифрованы ключом от PIN (ключ устройства их больше не открывает); снять —
## снова ключом устройства. Аккаунты при этом не теряются.
func _acc_pin() -> void:
	_acc_make()
	var ps := pui.profiles
	# Секреты — свои, не от предыдущих шагов: иначе поломка ввода ключа (imekey) каскадом валила бы и
	# этот шаг (PRACTICES §2.2).
	ps.secrets["claude"] = {"key": GOOD_KEY}
	ps.secrets["google"] = {"refresh_token": "1//RT"}
	ps.save_secrets()
	var dev_root := SecretBox.root_without_pin(ps.store.device_secret(), ps.profile.id)
	pui.on_action("profile_pin", "")
	_pui_type("1357")
	var with_pin: Variant = SecretBox.load_from(ps.dir(), ps.secret_root())
	var dev_opens: Variant = SecretBox.load_from(ps.dir(), dev_root)
	pui.on_action("profile_pin", "")
	_pui_type("1357")
	pui.on_button("unpin")
	var after_unpin: Variant = SecretBox.load_from(ps.dir(), dev_root)
	var ok_pin: bool = with_pin is Dictionary and (with_pin as Dictionary).has("claude") and dev_opens == null
	var ok_unpin: bool = after_unpin is Dictionary and (after_unpin as Dictionary).has("google") and not ps.profile.has_pin()
	if ok_pin and ok_unpin:
		r.pass_("аккаунт: PIN перешифровывает — с PIN секреты открывает только ключ от PIN, после снятия — снова ключ устройства; Claude и Google на месте")
	else:
		r.fail("аккаунт: PIN перешифровывает: с PIN %s (ключ устройства открыл %s), после снятия %s, PIN остался %s" % [
				with_pin, dev_opens != null, after_unpin, ps.profile.has_pin()])


## Вернуть прогону его настройки и избранное; папку профиля — убрать из настроек, хранилище — стереть.
func _pui_done() -> void:
	menu.profile_action.disconnect(pui.on_action)
	menu.panel.falsify_lower_always = false
	menu.locked = false
	menu.settings.values = _pui_saved[0]
	menu.settings.path = _pui_saved[1]
	menu.settings.common_path = _pui_saved[2]
	menu.settings.input = _pui_saved[3]
	menu.catalog.favorites = _pui_saved[4]
	menu.profile_id = _pui_saved[5]
	(menu.catalog.children_of["settings"] as Array).erase("profile")
	menu.apply_settings()
	_rm_tree(_pui_root)


func _rm_tree(dir: String) -> void:
	var abs := ProjectSettings.globalize_path(dir)
	var d := DirAccess.open(abs)
	if d == null:
		return
	for sub in d.get_directories():
		_rm_tree(dir.path_join(sub))
	for f in d.get_files():
		d.remove(f)
	DirAccess.remove_absolute(abs)


# --- мир: свет и сетка пола (этап Ф3) ------------------------------------------------

## Свет: три режима настройки дают разную яркость, и ни в одном сцена не тёмная (сессия 13: кнопок
## на контроллерах не было видно).
func _world_light() -> void:
	var env := WorldEnv.new()
	env.falsify_dark = falsify == "nolight"
	env.setup(head.get_parent())
	var seen := {}
	for level in ["dim", "studio", "bright"]:
		menu.settings.values["space_light"] = level
		env.apply(menu.settings)
		seen[level] = [snappedf(env.light.light_energy, 0.01), snappedf(env.world.environment.ambient_light_energy, 0.01)]
	menu.settings.values["space_glow"] = true
	env.apply(menu.settings)
	var glow_on: bool = env.world.environment.glow_enabled
	menu.settings.values["space_glow"] = false
	env.apply(menu.settings)
	var glow_off: bool = env.world.environment.glow_enabled
	var lit: bool = seen["dim"][0] > 0.0 and seen["studio"][0] > seen["dim"][0] and seen["bright"][0] > seen["studio"][0]
	env.world.queue_free()
	env.light.queue_free()
	if lit and glow_on and not glow_off:
		r.pass_("свет сцены: приглушённое %s, студия %s, яркое %s (свет, ambient); свечение включается настройкой" % [
				seen["dim"], seen["studio"], seen["bright"]])
	else:
		r.fail("свет сцены: %s, свечение вкл %s / выкл %s" % [seen, glow_on, glow_off])


## Сетка: настройки доходят до шейдера, сетка едет за человеком (линии при этом на месте — они в
## мировых координатах), «вся сцена» и «в начале координат» работают, «рентген» снимает проверку глубины.
func _world_grid() -> void:
	var root3d := head.get_parent()
	var grid := FloorGrid.new()
	grid.falsify_no_follow = falsify == "gridfollow"
	grid.setup(root3d, head)
	var st := menu.settings
	st.values["grid_mode"] = "around"
	st.values["grid_origin"] = true
	st.values["grid_cell_cm"] = 50.0
	st.values["grid_radius_m"] = 6.0
	st.values["grid_thickness_mm"] = 4.0
	st.values["grid_alpha"] = 0.35
	st.values["grid_color"] = "cyan"
	st.values["grid_xray"] = true
	grid.apply(st)
	var mat: ShaderMaterial = grid.around.material_override
	var uniforms := [mat.get_shader_parameter("cell_m"), mat.get_shader_parameter("thickness_m"),
			mat.get_shader_parameter("alpha"), mat.get_shader_parameter("radius_m"),
			mat.shader == FloorGrid.SHADER_XRAY]
	head.position = Vector3(3.0, 1.6, -2.0)
	grid.follow()
	var pos := grid.around.position
	var center: Vector3 = grid.center_of(grid.around)
	var both_visible: bool = grid.around.visible and grid.origin_grid.visible
	st.values["grid_mode"] = "off"
	grid.apply(st)
	var hidden: bool = not grid.around.visible and not grid.origin_grid.visible
	st.values["grid_mode"] = "scene"
	st.values["grid_origin"] = false
	grid.apply(st)
	var scene_side: float = grid.around.scale.x
	head.position = Vector3(0, 0, 0.4)
	grid.around.queue_free()
	grid.origin_grid.queue_free()
	# Высота — НЕ ноль: сетка приподнята на FloorGrid.LIFT_M над полом уровня, иначе она копланарна
	# его верхней грани (обе на Y=0) и мерцает в шлеме (владелец, 2026-09-23).
	var follows: bool = is_equal_approx(pos.x, 3.0) and is_equal_approx(pos.z, -2.0) \
			and is_equal_approx(pos.y, FloorGrid.LIFT_M) \
			and center.distance_to(Vector3(3.0, 0.0, -2.0)) < 0.01
	if uniforms == [0.5, 0.004, 0.35, 6.0, true] and follows and both_visible and hidden \
			and scene_side > 50.0:
		r.pass_("сетка пола: ячейка 50 см, линия 4 мм, прозрачность 0.35, радиус 6 м, рентген; едет за человеком на пол (%.1f, %.1f), «выкл» прячет обе, «вся сцена» — квад %.0f м" % [pos.x, pos.z, scene_side])
	else:
		r.fail("сетка пола: параметры %s, следование %s (%s, центр %s), обе видны %s, выкл %s, сцена %s" % [
				uniforms, follows, pos, center, both_visible, hidden, scene_side])


# --- уровень, тело игрока, предметы (этап Ф3, часть 2) --------------------------------

var _level_root: Node3D
var _level_built: Dictionary = {}
var _level_data: Dictionary = {}
var _player: PlayerBody
var _fake_head: Node3D
var _fake_origin: XROrigin3D
var _phys: Dictionary = {}
var _fall: Dictionary = {}
var _lean: Dictionary = {}
var _climb: Dictionary = {}
var _mantle_t: Dictionary = {}
## Где была голова на каждом кадре перевала — ищем скачок вида.
var _mantle_t_view: Array = []
## Высота площадки, на которую ведёт кромка, — из данных уровня.
var _mantle_t_top := 0.0
var _floor_t: Dictionary = {}


## Стартовая локация строится из своих данных: узлы, материалы на цвет, точка старта, группы.
func _level_build() -> void:
	LevelLoader.falsify_per_object_material = falsify == "levelflat"
	_level_root = Node3D.new()
	head.get_parent().add_child(_level_root)
	var res := LevelLoader.parse(FileAccess.get_file_as_string("res://world/levels/start_location.json"))
	if not res["ok"]:
		r.fail("уровень из данных: %s" % res["error"])
		return
	_level_data = res["data"]
	_level_built = LevelLoader.build(_level_root, res["data"])
	var nodes: int = (_level_built["nodes"] as Array).size()
	var colors: int = _level_built["colors"]
	var climb: int = get_nodes_in_group("climb").size()
	var grabbable: int = get_nodes_in_group("grab").size()
	var targets: int = get_nodes_in_group("teleport_target").size()
	var spawn: Transform3D = _level_built["spawn"]
	var triggers: int = (_level_built["triggers"] as Array).size()
	# Материалов должно быть заметно меньше, чем объектов: цена отрисовки у нас по вызовам.
	if nodes > 40 and colors <= 10 and colors < nodes / 3 and climb >= 3 and grabbable >= 5 \
			and targets >= 3 and triggers >= 1 and spawn != Transform3D():
		r.pass_("уровень из данных: %d узлов на %d материалов, зацепов %d, предметов в руку %d, целей телепорта %d, триггер подгрузки %d, точка старта есть" % [
				nodes, colors, climb, grabbable, targets, triggers])
	else:
		r.fail("уровень из данных: узлов %d, материалов %d, зацепов %d, предметов %d, целей %d, триггеров %d, старт %s" % [
				nodes, colors, climb, grabbable, targets, triggers, spawn])


## Объект уровня по имени. Стенды опираются на данные сцены, а не на числа в своём коде: улицу
## перестроили 2026-09-22, и пять шагов, знавших координаты наизусть, покраснели на верном коде.
func _obj(uuid: String) -> Dictionary:
	for o in _level_data.get("objects", []):
		if str((o as Dictionary).get("uuid", "")) == uuid:
			return o
	return {}


func _obj_pos(uuid: String) -> Vector3:
	var o := _obj(uuid)
	var a: Variant = o.get("pos", null)
	if not a is Array:
		return Vector3.ZERO
	return Vector3(float(a[0]), float(a[1]), float(a[2]))


## Тело игрока над полом; дальше кадры физики делают своё дело.
func _phys_setup() -> void:
	_fake_origin = XROrigin3D.new()
	_fake_head = Node3D.new()
	_fake_head.position = Vector3(0, 1.6, 0)
	_player = PlayerBody.new()
	_player.falsify_no_step = falsify == "nostep"
	_player.falsify_ghost = falsify == "ghost"
	_player.falsify_head_chase = falsify == "headchase"
	head.get_parent().add_child(_player)
	_player.add_child(_fake_origin)
	_fake_origin.add_child(_fake_head)
	_player.setup(_fake_origin, _fake_head)
	_player.set_eye_height(1.6)
	# Над ровной площадкой стартовой локации, подальше от построек. Высота небольшая: падение с
	# метра занимает почти полсекунды, и при плотном прогоне тактов физики до замера не хватало —
	# проверка краснела на верном коде (плавающий отказ, §2.7).
	_player.global_position = Vector3(0, 0.35, 8.0)
	_phys["landing"] = true
	_phys["landed"] = false
	_phys["floor_y"] = 9.0


## Человек физически шагнул в сторону: голова сместилась внутри origin. Тело обязано встать под неё
## и ОСТАНОВИТЬСЯ. Сессия 15: тело гналось за собственной головой (origin — его ребёнок, шаг тела
## уносил голову с собой), расстояние не сокращалось, и человека уносило со сцены. Прежний шаг этого
## не видел: фальшивая голова стояла ровно над телом, и смещение было нулевым.
func _phys_head_prep() -> void:
	_phys["head_from"] = _fake_head.global_position
	_phys["body_from"] = _player.global_position
	_fake_head.position = Vector3(0.4, 1.6, 0.0)


func _phys_head_check() -> void:
	var head_from: Vector3 = _phys["head_from"]
	var head_now: Vector3 = _fake_head.global_position
	# Голова осталась там, где человек физически стоит (сдвиг на 0.4 задан вручную и в мир не идёт).
	var head_drift := Vector2(head_now.x - head_from.x - 0.4, head_now.z - head_from.z).length()
	# Тело встаёт не под глаза, а на EYE_FORWARD_OFFSET позади них: иначе наклон к столу выталкивает
	# человека от препятствия (сессия 17). Значит цель следования — точка за головой.
	var back: Vector3 = _fake_head.global_basis.z
	back.y = 0.0
	var want := head_now + back.normalized() * PlayerBody.EYE_FORWARD_OFFSET
	var under := Vector2(_player.global_position.x - want.x, _player.global_position.z - want.z).length()
	var body_run := Vector2(_player.global_position.x - (_phys["body_from"] as Vector3).x,
			_player.global_position.z - (_phys["body_from"] as Vector3).z).length()
	if head_drift < 0.05 and under < 0.05 and body_run < 0.6:
		r.pass_("тело игрока: голова на месте — шаг 0.4 м, голова не уплыла (%.3f м), тело встало под точку за глазами (%.3f м) и прошло %.2f м" % [
				head_drift, under, body_run])
	else:
		r.fail("тело игрока: голова на месте — голова уплыла на %.2f м, тело в %.2f м от неё, прошло %.2f м за 30 кадров" % [
				head_drift, under, body_run])
	# Вернуть исходное расположение, иначе фальсификатор утащит и следующие шаги.
	_fake_origin.position = Vector3.ZERO
	_fake_head.position = Vector3(0, 1.6, 0)


## Через кадры физики: тело стоит на полу; голова уходит на ступень — тело поднимается.
func _phys_step() -> void:
	_phys["on_floor"] = bool(_phys.get("landed", false))
	_phys["landing"] = false
	# Лесенка улицы: подходим к нижней ступени (высота 0.18) и «идём» на неё. Ступени растут в −Z,
	# туда же идёт стенд.
	var st := _obj_pos("stairs")
	var st_size: Array = _obj("stairs").get("size", [2.0, 1.8, 0.3])
	_player.global_position = Vector3(st.x - float(st_size[0]) * 0.35, 0.05, st.z + 0.7)
	_fake_head.position = Vector3(0, 1.6, 0)
	_phys["walk"] = "stairs"


func _phys_wall() -> void:
	_phys["step_y"] = _player.global_position.y
	# Стена дома: идём в неё, тело не должно пройти насквозь.
	var wall := _obj_pos("hstair_side1")
	_player.global_position = Vector3(wall.x, 0.05, wall.z - 1.9)
	_phys["walk"] = "wall"
	_phys["wall_from"] = _player.global_position.z
	# Куда тело не должно дойти: плоскость стены минус полкапсулы. Порог из данных, а не число в
	# коде: со старым числом (6.3) проверка была истинной всегда и не краснела даже на «ghost».
	_phys["wall_stop"] = wall.z - 0.3


## Человек наклоняется к препятствию: голова уходит вперёд, капсула лезет в стену. Тело при этом
## обязано остаться на месте — сессия 17: «когда наклоняюсь у стола или столба, весь передвигаюсь от
## препятствия». Свидетель — МИРОВАЯ позиция головы: компенсация origin удерживает её там, где
## человек физически стоит, а выталкивание её увозит.
func _lean_prep() -> void:
	# СВОЁ тело, а не общее: иначе «ghost» и «headchase» — фальсификаторы соседних шагов — роняли бы
	# и этот, и ни один отказ не был бы точечным (§2.2).
	var body := PlayerBody.new()
	var origin := XROrigin3D.new()
	var lean_head := Node3D.new()
	head.get_parent().add_child(body)
	body.add_child(origin)
	origin.add_child(lean_head)
	body.falsify_push_lean = falsify == "pushlean"
	body.setup(origin, lean_head)
	body.set_eye_height(1.6)
	# Вплотную к торцу дальнего дома, лицом к нему: «позади глаз» считается по взгляду, и голова,
	# смотрящая в другую сторону, дала бы смещение В стену вместо от неё. Дом дальний намеренно —
	# два тела в одной точке расталкиваются физикой, и этот сдвиг выглядел бы как выталкивание.
	var lean_wall := _obj_pos("hbeam_side1")
	body.global_position = Vector3(lean_wall.x, 0.05, lean_wall.z - 0.55)
	lean_head.rotation = Vector3(0, PI, 0)
	# Наклон: голова уходит на четверть метра вперёд, в стену.
	lean_head.position = Vector3(0, 1.4, 0.25)
	_lean = {"body": body, "head": lean_head, "from": lean_head.global_position}


func _lean_check() -> void:
	var lean_head: Node3D = _lean["head"]
	var from: Vector3 = _lean["from"]
	var now: Vector3 = lean_head.global_position
	var drift := Vector2(now.x - from.x, now.z - from.z).length()
	_lean["body_end"] = (_lean["body"] as Node3D).global_position
	_lean["origin_end"] = (lean_head.get_parent() as Node3D).position
	(_lean["body"] as Node).queue_free()
	if drift < 0.03:
		r.pass_("тело игрока: наклон у стены — голова осталась на месте (%.3f м за 45 кадров), человека не вытолкнуло" % drift)
	else:
		r.fail("тело игрока: наклон у стены — человека увезло от препятствия на %.2f м (тело %s, origin %s)" % [
				drift, (_lean["body_end"] as Vector3), (_lean["origin_end"] as Vector3)])


## Проверка ступени и стены — и заодно предмет в руке.
func _grab_check() -> void:
	var stepped: bool = float(_phys.get("step_y", 0.0)) > 0.12
	var wall_z: float = _player.global_position.z
	var wall_stop: float = float(_phys.get("wall_stop", 0.0))
	var blocked: bool = wall_z < wall_stop
	var landed: bool = bool(_phys.get("on_floor", false)) and absf(float(_phys.get("floor_y", 9.0))) < 0.05
	if landed and stepped:
		r.pass_("тело игрока: ступень — упало на пол (y %.2f) и поднялось на ступень 18 см (y %.2f)" % [
				_phys.get("floor_y", 0.0), _phys.get("step_y", 0.0)])
	else:
		r.fail("тело игрока: ступень — на полу %s (y %.2f), после ступени y %.2f" % [landed,
				_phys.get("floor_y", 9.0), _phys.get("step_y", 0.0)])
	if blocked:
		r.pass_("тело игрока: стена — не прошло насквозь (остановилось на z %.2f, стена не ближе %.2f)" % [
				wall_z, wall_stop])
	else:
		r.fail("тело игрока: стена — прошло насквозь до z %.2f" % wall_z)

	_phys["walk"] = ""
	var grab := GrabRes.new()
	grab.falsify_sticky = falsify == "grabstick"
	grab.falsify_greedy = falsify == "handgreedy"
	grab.falsify_held_solid = falsify == "heldsolid"
	var cubes: Array = get_nodes_in_group("grab")
	var cube: Node3D = GrabRes.nearest(cubes, (cubes[0] as Node3D).global_position + Vector3(0.05, 0, 0))
	var hand := Transform3D(Basis(), (cubes[0] as Node3D).global_position)
	grab.grab("right", cube, hand)
	var held_frozen: bool = cube is RigidBody3D and (cube as RigidBody3D).freeze
	for i in 9:
		hand.origin += Vector3(0.02, 0, 0)
		grab.update("right", hand, 1.0 / 90.0)
	var moved_with_hand: bool = cube.global_position.distance_to(hand.origin) < 0.02
	# Рука ЗАНЯТА: второй предмет она не берёт (решение владельца 2026-09-22). Раньше отказ был
	# молчаливым, и вызывающий писал в журнал «взят», когда ничего не произошло.
	var second: Node3D = null
	for c in cubes:
		if c != cube:
			second = c
			break
	var took_second: bool = grab.grab("right", second, hand)
	var still_first: bool = (grab.held["right"] as Dictionary)["node"] == cube
	var thrown := grab.release("right")
	var layer_back: bool = cube is CollisionObject3D and (cube as CollisionObject3D).collision_layer != 0
	var released: bool = not grab.held.has("right") and cube is RigidBody3D and not (cube as RigidBody3D).freeze
	_level_root.queue_free()
	_player.queue_free()
	if held_frozen and moved_with_hand and released and thrown.length() > 0.5 \
			and not took_second and still_first and layer_back:
		r.pass_("предмет в руке: взят (физика приостановлена), едет за рукой, отпущен со скоростью %.2f м/с; занятая рука второй не берёт; после отпускания снова осязаем" % [
				thrown.length()])
	else:
		r.fail("предмет в руке: заморожен %s, едет за рукой %s, отпущен %s, бросок %.2f, взял второй %s, держит первый %s, слой вернулся %s" % [
				held_frozen, moved_with_hand, released, thrown.length(), took_second, still_first,
				layer_back])


## Пока шар открыт, стики принадлежат меню (левый вращает шар, правый листает панель) — иначе
## прокрутка спорила бы с ходьбой.
func _stick_owner() -> void:
	var loco := LocomotionRes.new()
	loco.menu = menu
	loco.falsify_ignore_menu = falsify == "menustick"
	_to_root_open()
	var while_open := loco.input_free()
	menu.close()
	var while_closed := loco.input_free()
	loco.free()
	if not while_open and while_closed:
		r.pass_("стики принадлежат меню: при открытом шаре перемещение молчит, при закрытом — работает")
	else:
		r.fail("стики принадлежат меню: открыт — ввод свободен %s, закрыт — %s" % [while_open, while_closed])


## Узел пространственных данных создаётся без ошибок типов: на шлеме в сессии 15 запуск уронило
## присваивание OpenXRFbSceneManager (это Node, не Node3D). Класс есть и в редакторе — значит,
## проверка ловит это на столе.
func _room_node() -> void:
	var root3d := head.get_parent()
	var rm := RoomRes.new()
	rm.setup(root3d)
	var made: bool = rm.manager != null
	var state: String = rm.state
	var key_empty: bool = rm.place_key() == ""
	if rm.manager != null:
		rm.manager.queue_free()
	if made and state == "ждём" and key_empty:
		r.pass_("комната от шлема: узел менеджера создан, состояние «%s», ключ комнаты пуст до ответа рантайма" % state)
	else:
		r.fail("комната от шлема: узел %s, состояние «%s», ключ пуст %s" % [made, state, key_empty])


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


## Непрерывное движение обязано оставлять след в журнале: строку на старте и строку на остановке, с
## пройденным путём. Сессия 17: телепорт и повороты записаны, а ходьба по взгляду и по руке — нет,
## и работала ли она, сказать было нечем.
func _walk_log() -> void:
	var loco := LocomotionRes.new()
	loco.falsify_quiet_walk = falsify == "walkquiet"
	var b := PlayerBody.new()
	head.get_parent().add_child(b)
	b.global_position = Vector3.ZERO
	loco.body = b
	var got: Array = []
	loco.moved.connect(func(kind: String, detail: String): got.append("%s|%s" % [kind, detail]))
	loco._track_walk("head", true)
	b.global_position = Vector3(3.0, 0.0, 4.0)
	loco._track_walk("head", true)
	loco._track_walk("head", false)
	loco._track_walk("head", false)
	b.queue_free()
	loco.free()
	var two: bool = got.size() == 2
	var started: bool = two and got[0] == "ходьба|пошёл: head"
	var stopped: bool = two and got[1].begins_with("ходьба|встал: head, 5.00 м")
	if started and stopped:
		r.pass_("журнал ходьбы: две строки на отрезок — «%s» и «%s»" % [got[0], got[1]])
	else:
		r.fail("журнал ходьбы: строк %d %s" % [got.size(), got])


## Сетка не ездит вместе с человеком. Сессия 17: сетка была ребёнком XROrigin3D, тело игрока начало
## двигать origin — и сетка поехала с человеком, поднимаясь с ним на платформы, то есть переставая
## совпадать с полом уровня. Шаг ставит голову ВНУТРЬ смещённого origin: локальная позиция головы при
## этом не меняется, и только мировая показывает, где человек на самом деле.
func _grid_fixed() -> void:
	var world := Node3D.new()
	var origin := Node3D.new()
	var fake_head := Node3D.new()
	head.get_parent().add_child(world)
	world.add_child(origin)
	origin.add_child(fake_head)
	fake_head.position = Vector3(0.3, 1.6, 0.4)
	# Человек ушёл на 5 м и забрался на платформу 1.6 м — origin уехал вместе с телом.
	origin.position = Vector3(5.0, 1.6, 0.0)
	var grid := FloorGrid.new()
	grid.falsify_ride = falsify == "gridride"
	grid.setup(world, fake_head)
	var st := SettingsRes.new()
	st.reset()
	st.values["grid_mode"] = "fixed"
	grid.apply(st)
	grid.follow()
	var bad: Array = []
	if not grid.around.global_position.is_equal_approx(Vector3(0.0, FloorGrid.LIFT_M, 0.0)):
		bad.append("вид «на месте» уехал в %s" % grid.around.global_position)
	st.values["grid_mode"] = "around"
	grid.apply(st)
	grid.follow()
	var c := grid.around.global_position
	if not is_equal_approx(c.x, 5.3) or not is_equal_approx(c.y, FloorGrid.LIFT_M) or not is_equal_approx(c.z, 0.4):
		bad.append("вид «вокруг меня»: центр %s, ожидался (5.3, 0, 0.4)" % c)
	if not grid.center_of(grid.around).is_equal_approx(c):
		bad.append("центр затухания разошёлся с квадом")
	world.queue_free()
	if bad.is_empty():
		r.pass_("сетка не едет с человеком: «на месте» стоит на нуле уровня, «вокруг меня» считает центр по миру (5.3, 0, 0.4) и не поднимается на платформу")
	else:
		r.fail("сетка не едет с человеком: %s" % "; ".join(bad))


## Какой рукой идти и поворачиваться — настройка (просьба владельца, сессия 17). «Обе» складывает
## стики: поворот забирает ось X, движение — ось Y, иначе одна рука спорила бы сама с собой.
func _hand_choice() -> void:
	var loco := LocomotionRes.new()
	loco.falsify_fixed_hands = falsify == "onehand"
	loco.falsify_no_turn_first = falsify == "axisfree"
	loco.menu = menu
	var l := XRController3D.new()
	var rr := XRController3D.new()
	head.get_parent().add_child(l)
	head.get_parent().add_child(rr)
	loco.left = l
	loco.right = rr
	var st := menu.settings
	var bad: Array = []
	# Стиков без трекинга нет, поэтому берём подменённые значения через сам узел: XRController3D
	# отдаёт ноль, и проверка смотрит НЕ величину, а какую руку спросили.
	var asked: Array = []
	loco.stick_source = func(who: String) -> Vector2:
		asked.append(who)
		return Vector2(0.5 if who == "right" else 0.25, 0.75 if who == "left" else 0.1)
	for pair in [["left", ["left"]], ["right", ["right"]], ["both", ["left", "right"]]]:
		st.values["move_hand"] = pair[0]
		asked.clear()
		var v: Vector2 = loco.hand_stick("move_hand", "left")
		if asked != pair[1]:
			bad.append("move_hand=%s спросил %s" % [pair[0], asked])
		if pair[0] == "both" and not (is_equal_approx(v.x, 0.75) and is_equal_approx(v.y, 0.85)):
			bad.append("«обе» сложила стики в %s, ожидалось (0.75, 0.85)" % v)
	# ПОВОРОТ ГЛАВНЕЕ ДВИЖЕНИЯ, когда обе механики читают один стик (решение владельца 2026-09-22).
	# Прежнее правило глушило «преобладающую ось» по отношению 1.6 и молчало ровно на тех
	# отклонениях, которые человек даёт чаще всего: (0.8, 0.5) и (0.7, 0.7) вели и поворот, и ход.
	st.values["move_hand"] = "both"
	st.values["turn_hand"] = "both"
	if not loco.same_stick():
		bad.append("«обе»/«обе» — это один стик на две механики, а проверка считает иначе")
	for probe in [[Vector2(0.9, 0.25), true], [Vector2(0.8, 0.5), true], [Vector2(0.7, 0.7), true],
			[Vector2(0.2, 0.95), false], [Vector2(0.5, 0.5), false]]:
		var v: Vector2 = probe[0]
		loco.stick_source = func(who: String) -> Vector2:
			return v if who == "right" else Vector2.ZERO
		var f := loco.frame_sticks()
		var moves: bool = (f["move"] as Vector2).length() > 0.01
		var turns: bool = absf((f["turn"] as Vector2).x) >= 0.6
		if bool(probe[1]) and moves:
			bad.append("стик %s: поворот тащит вперёд (ход %s)" % [v, f["move"]])
		if not bool(probe[1]) and not moves:
			bad.append("стик %s: ход подавлен, хотя поворота нет" % v)
		if bool(probe[1]) and not turns:
			bad.append("стик %s: поворот не сработал" % v)
	# Разные стики — правило не действует вовсе: стрейф на ходу остаётся.
	st.values["move_hand"] = "left"
	st.values["turn_hand"] = "right"
	if loco.same_stick():
		bad.append("«левая»/«правая» сочтены одним стиком")
	loco.stick_source = func(who: String) -> Vector2:
		return Vector2(0.8, 0.5) if who == "left" else Vector2(0.9, 0.1)
	var split := loco.frame_sticks()
	if (split["move"] as Vector2).length() < 0.5:
		bad.append("при разных стиках ход подавлен: %s" % split["move"])
	loco.stick_source = func(who: String) -> Vector2:
		asked.append(who)
		return Vector2(0.5 if who == "right" else 0.25, 0.75 if who == "left" else 0.1)
	st.values["turn_hand"] = "left"
	asked.clear()
	loco.hand_stick("turn_hand", "right")
	if asked != ["left"]:
		bad.append("turn_hand=left спросил %s" % [asked])
	st.values["move_hand"] = "right"
	var aim := loco.aiming_hand()
	if aim != rr:
		bad.append("телепорт целит не из правой руки")
	l.queue_free()
	rr.queue_free()
	loco.free()
	if bad.is_empty():
		r.pass_("рука движения и поворота: «левая», «правая» и «обе» спрашивают тот стик, который названы; при одном стике на обе механики поворот главнее хода (0.9/0.25, 0.8/0.5 и 0.7/0.7 не везут), при разных стиках стрейф цел; телепорт целит из выбранной руки")
	else:
		r.fail("рука движения и поворота: %s" % "; ".join(bad))


## Упал со сцены — возвращают в стартовую точку. Сессия 17: за краем площадки можно падать вечно.
func _fall_home() -> void:
	var body := PlayerBody.new()
	var origin := XROrigin3D.new()
	var fake_head := Node3D.new()
	head.get_parent().add_child(body)
	body.add_child(origin)
	origin.add_child(fake_head)
	fake_head.position = Vector3(0, 1.6, 0)
	body.falsify_no_fall = falsify == "nofall"
	body.collision_mask = 0
	body.setup(origin, fake_head)
	var depth := [0.0]
	body.fell.connect(func(d: float): depth[0] = d)
	body.global_position = Vector3(0, PlayerBody.FALL_Y - 1.0, 0)
	_fall = {"body": body, "depth": depth}


## Сигнал падения приходит из _physics_process, поэтому проверка — на другом кадре (та же
## отложенность, что у ловушки 26).
func _fall_check() -> void:
	var body: PlayerBody = _fall["body"]
	var depth: Array = _fall["depth"]
	var got: float = depth[0]
	body.queue_free()
	if got < PlayerBody.FALL_Y:
		r.pass_("падение и возврат в старт: ниже %.0f м тело сообщило о падении (с %.0f м) — вызывающий вернёт в стартовую точку" % [PlayerBody.FALL_Y, got])
	else:
		r.fail("падение и возврат в старт: тело молчит, глубина %.0f при пороге %.0f" % [got, PlayerBody.FALL_Y])


## Лазанье действительно поднимает. Сессия 17: двенадцать захватов и «вверх −0.00» в каждой строке —
## мир ехал за дельтой руки, и подъёма не получалось. Шаг тянет руку вниз от зафиксированного
## зацепа: человек при этом обязан подняться.
func _climb_prep() -> void:
	var loco := LocomotionRes.new()
	var body := PlayerBody.new()
	var origin := XROrigin3D.new()
	var climb_head := Node3D.new()
	head.get_parent().add_child(body)
	body.add_child(origin)
	origin.add_child(climb_head)
	climb_head.position = Vector3(0, 1.6, 0)
	body.setup(origin, climb_head)
	body.set_eye_height(1.6)
	# У стены для лазанья (зацепы на x 3.85 и 5.15, z −4.55), на полу.
	body.global_position = Vector3(3.85, 0.05, -4.0)
	loco.climb.falsify_drift = falsify == "climbdrift"
	# Хват за нижний зацеп; рука пошла вниз — человек лезет вверх.
	loco.climb.grab("right", Vector3(3.85, 0.95, -4.55))
	_climb = {"body": body, "loco": loco, "from": body.global_position.y}


func _climb_check() -> void:
	var body: PlayerBody = _climb["body"]
	var loco: LocomotionRes = _climb["loco"]
	# Двадцать кадров: рука опускается на 4 см за кадр — обычный темп подтягивания. Рука едет вместе
	# с телом (в жизни она внутри origin, а origin — ребёнок тела), иначе смещение копится и стенд
	# показывает подъём в разы больше настоящего.
	var hand := Vector3(3.85, 0.95, -4.55)
	for i in 20:
		var was := body.global_position
		hand.y -= 0.04
		body.climb_shift(loco.climb.update({"right": hand}, 1.0 / 90.0))
		hand += body.global_position - was
	var rise: float = body.global_position.y - float(_climb["from"])
	body.queue_free()
	loco.free()
	# Подъём равен ходу руки: в этом и смысл фиксированного зацепа — рука «приклеена» к бруску.
	if rise > 0.7 and rise < 0.9:
		r.pass_("лазанье поднимает: рука опустилась на 0.80 м — человек поднялся на %.2f м" % rise)
	else:
		r.fail("лазанье поднимает: рука опустилась на 0.80 м, а человек поднялся на %.2f м" % rise)


## Видимая связь при призыве: предмет выделен накладкой, от ладони к нему идёт нить, и всё это
## снимается, когда цель ушла. Сессия 20: владелец просил визуализацию — её не было вовсе.
func _pull_link() -> void:
	var view := PullViewRes.new()
	PullViewRes.falsify_no_line = falsify == "pullnoline"
	PullViewRes.falsify_no_highlight = falsify == "pullnohl"
	view.setup(head.get_parent())
	var target := MeshInstance3D.new()
	target.mesh = BoxMesh.new()
	head.get_parent().add_child(target)
	target.global_position = Vector3(0, 1.2, -2.0)
	var bad: Array = []
	view.show_link("right", target, Vector3(0.2, 1.3, 0), false)
	if view.linked("right") != target:
		bad.append("связь не запомнена")
	if target.material_overlay == null:
		bad.append("предмет не выделен")
	var lines := 0
	for ch in head.get_parent().get_children():
		if ch is MeshInstance3D and (ch as MeshInstance3D).mesh is ImmediateMesh:
			lines += 1
	if lines < 1:
		bad.append("нити нет")
	view.show_link("right", null, Vector3.ZERO, false)
	if target.material_overlay != null or view.linked("right") != null:
		bad.append("связь не снялась: выделение %s" % target.material_overlay)
	target.queue_free()
	PullViewRes.falsify_no_line = false
	PullViewRes.falsify_no_highlight = false
	if bad.is_empty():
		r.pass_("связь при призыве: предмет выделен накладкой, от ладони идёт нить, при потере цели снимается и то и другое")
	else:
		r.fail("связь при призыве: %s" % "; ".join(bad))


## Перевал ставит человека НА площадку в полный рост. Сессия 20: «оказался низко — как будто на
## коленях», потому что во время переноса физика тела продолжала работать: тяготение роняло, а
## следование за головой тянуло обратно к стене.
func _mantle_prep() -> void:
	var loco := LocomotionRes.new()
	var body := PlayerBody.new()
	var origin := XROrigin3D.new()
	var m_head := Node3D.new()
	head.get_parent().add_child(body)
	body.add_child(origin)
	origin.add_child(m_head)
	m_head.position = Vector3(0, 1.6, 0)
	body.setup(origin, m_head)
	body.set_eye_height(1.6)
	loco.body = body
	loco.head = m_head
	loco.origin = origin
	loco.falsify_mantle_phys = falsify == "mantlephys"
	# Кромка размечена в данных (тип ledge): точка приземления — её target, а «наружу» — сторона,
	# противоположная ей: именно там висит человек, держась за карниз.
	var ledge_pos := _obj_pos("ledge_roof")
	var target := ledge_pos
	for node in get_nodes_in_group("ledge"):
		target = (node as Area3D).get_meta("target", target)
	var out := (ledge_pos - target)
	out.y = 0.0
	out = out.normalized() if out.length() > 0.01 else Vector3.FORWARD
	# Человек висит у стены снаружи, головой чуть ниже карниза.
	body.global_position = ledge_pos + out * 0.4 + Vector3(0, -0.1, 0)
	# Origin уехал на 1.4 м, как после подъёма по стене: компенсация следования копит смещение.
	origin.position = Vector3(1.4, 0.0, 0.6)
	_mantle_t_view = [m_head.global_position]
	body.mantling = not loco.falsify_mantle_phys
	_mantle_t_top = target.y
	body.hold_collisions()
	_mantle_t = {"body": body, "loco": loco, "head": m_head, "origin": origin, "to": target,
			"from": body.global_position}


## Кадры перевала идут из _process — здесь только итог: тело на площадке, глаза на рост выше.
func _mantle_check() -> void:
	var body: PlayerBody = _mantle_t["body"]
	var m_head: Node3D = _mantle_t["head"]
	var eyes := m_head.global_position.y
	var feet := body.global_position.y
	(_mantle_t["loco"] as Node).free()
	body.queue_free()
	var stands: bool = absf(eyes - feet - 1.6) < 0.05
	var on_top: bool = absf(feet - _mantle_t_top) < 0.1
	# Столкновения на время переноса снимались и вернулись: иначе капсула цепляется за угол кромки.
	var solid: bool = body.collision_mask != 0
	if stands and on_top and solid:
		r.pass_("перевал ставит в полный рост: ноги на площадке (%.2f м), глаза на %.2f м — ровно рост выше, столкновения вернулись" % [feet, eyes])
	else:
		r.fail("перевал ставит в полный рост: ноги %.2f (ждали %.2f), глаза %.2f — над ногами %.2f вместо 1.60, маска %d" % [
				feet, _mantle_t_top, eyes, eyes - feet, body.collision_mask])


## Вид во время перевала не прыгает. Сессия 22: в конце переноса origin обнулялся по горизонтали, и
## человека швыряло вбок ровно на смещение, накопленное за подъём, — «телепортировало куда-то
## далеко в сторону от верха лестницы». Свидетель — мировая позиция головы по кадрам: между
## соседними кадрами она не должна прыгать больше, чем идёт сам перенос.
func _mantle_view_check() -> void:
	var worst := 0.0
	var at := 0
	for i in range(1, _mantle_t_view.size()):
		var step: float = (_mantle_t_view[i] as Vector3).distance_to(_mantle_t_view[i - 1])
		if step > worst:
			worst = step
			at = i
	# Шаг переноса за кадр: вся дорога (около 1.5 м) за RISE_S при 90 кадрах — сантиметры.
	if worst < 0.25:
		r.pass_("перевал без скачка вида: голова идёт ровно, худший шаг за кадр %.3f м" % worst)
	else:
		r.fail("перевал без скачка вида: на кадре %d голову бросило на %.2f м" % [at, worst])


## Перевал не хватает того, кто стоит на полу. Сессия 23: человек взялся за нижний зацеп, стоя на
## земле, и его мгновенно унесло «на площадку 1.44» — луч нашёл платформу перед ним, а условий
## «висит» и «площадка выше ног» не было вовсе.
##
## Стенд ставит тело на пол перед платформой 0.9 м и держит хват: площадка находится лучом и выше
## ног, то есть единственное, что должно удержать перевал, — «стоит на полу».
func _mantle_floor_check() -> void:
	if get_nodes_in_group("climb").is_empty():
		r.fail("перевал не хватает стоящего: уровня в сцене нет — проверять нечего")
		return
	var loco := LocomotionRes.new()
	var body := PlayerBody.new()
	var origin := XROrigin3D.new()
	var m_head := Node3D.new()
	head.get_parent().add_child(body)
	body.add_child(origin)
	origin.add_child(m_head)
	m_head.position = Vector3(0, 1.6, 0)
	body.setup(origin, m_head)
	body.set_eye_height(1.6)
	loco.body = body
	loco.head = m_head
	loco.origin = origin
	loco.falsify_mantle_eager_floor = falsify == "mantlefloor"
	# Узел маршрута — в дерево: вне его `get_tree()` внутри поиска кромки равен null, и проверка
	# молча ничего не проверяла бы. Свой такт ему не нужен — тактуем вручную из _process.
	head.get_parent().add_child(loco)
	loco.set_physics_process(false)
	# Перед помостом в конце улицы (верх 1.2 м), лицом к нему. Именно помост, а не крыльцо: перед
	# крыльцом лежит пандус — стенд вставал на него, поднимался вместе с ним, и луч поиска уходил
	# ВЫШЕ площадки. Подступ к площадке для такого стенда обязан быть ровным.
	var deck := _obj_pos("end_deck")
	var deck_size: Array = _obj("end_deck").get("size", [8.0, 1.2, 2.4])
	var near_z: float = deck.z + float(deck_size[2]) * 0.5
	# Вплотную к краю: луч поиска площадки смотрит вперёд всего на PROBE_AHEAD_M (0.45 м), и
	# отойди стенд дальше — он бы ничего не нашёл и молча «доказал» отсутствие перевала.
	body.global_position = Vector3(deck.x, 0.4, near_z + MantleRes.PROBE_AHEAD_M - 0.1)
	# Опираем тело на пол прямо сейчас: в headless кадры рендера идут много быстрее тактов физики,
	# и ждать падения пришлось бы сотнями кадров (проверка краснела бы на верном коде).
	for i in 20:
		body.velocity = Vector3(0, -2.0, 0)
		body.move_and_slide()
	m_head.rotation = Vector3.ZERO
	var hand := Vector3(deck.x, 1.2, near_z - 0.05)
	loco.climb.grab("right", hand)
	_floor_t = {"body": body, "loco": loco, "hand": hand, "hit": false}
	loco.moved.connect(func(kind: String, _d: String):
		if kind == "перевал":
			_floor_t["hit"] = true)


## Итог: за два десятка тактов физики стоящего на полу наверх не утащило.
func _mantle_floor_result() -> void:
	var hit: bool = bool(_floor_t.get("hit", false))
	var body: PlayerBody = _floor_t["body"]
	var loco: LocomotionRes = _floor_t["loco"]
	var ticks := int(_floor_t.get("ticks", 0))
	var held: float = loco._ledge_held
	var on_floor: bool = body.is_on_floor()
	# Видит ли стенд площадку вообще — иначе «перевал не начался» ничего не доказывает.
	var space := body.get_world_3d().direct_space_state
	var probe := body.global_position + Vector3(0, 1.6, 0) + Vector3(0, 0, -MantleRes.PROBE_AHEAD_M)
	var q := PhysicsRayQueryParameters3D.create(probe + Vector3.UP * 0.05, probe - Vector3.UP * 1.2)
	q.exclude = [body.get_rid()]
	var sees := not space.intersect_ray(q).is_empty()
	loco.free()
	body.queue_free()
	_floor_t.clear()
	if not sees:
		r.fail("перевал не хватает стоящего: луч из %s вниз не находит площадку — стенд ничего не проверил (тело %s, на полу %s)" % [
				probe.snappedf(0.01), body.global_position.snappedf(0.01), on_floor])
	elif ticks < 30:
		r.fail("перевал не хватает стоящего: тактов всего %d — стенд не успел ничего проверить" % ticks)
	elif not on_floor:
		r.fail("перевал не хватает стоящего: тело в %s не встало на пол — стенд ничего не проверил" % body.global_position.snappedf(0.01))
	elif not hit:
		r.pass_("перевал не хватает стоящего: %d тактов у площадки 1.2 м (накоплено %.2f с) — стоящего на полу наверх не унесло" % [ticks, held])
	else:
		r.fail("перевал не хватает стоящего: стоящего на полу унесло наверх")


# --- слои, группы и режим игры (этап Е2) ----------------------------------------------

var _zone: Dictionary = {}


## Зона подгрузки: её видно на слое отладки — и она продолжает грузить интерьер скрытой.
## Скрывается маской камеры, а маска отсекает отрисовку, а не физику; проверяем это телом,
## а не рассуждением: тело кладётся в зону, и сигнал обязан прийти.
func _zone_prep() -> void:
	TriggerViewRes.falsify_game_layer = falsify == "triggergame"
	var res := LevelLoader.parse(FileAccess.get_file_as_string("res://world/levels/start_location.json"))
	var root := Node3D.new()
	root.position = Vector3(0, -400, 0)  # подальше от стенда тела игрока: чужая физика не мешает
	head.get_parent().add_child(root)
	var built := LevelLoader.build(root, res["data"])
	var area: Area3D = (built["triggers"][0] as Dictionary)["area"]
	# Камера с маской режима игры: зону человек не увидит.
	var cam := Camera3D.new()
	cam.cull_mask = LayersRes.play_mask()
	root.add_child(cam)
	var box: MeshInstance3D = null
	for c in area.get_children():
		if c is MeshInstance3D:
			box = c
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(0.3, 0.3, 0.3)
	cs.shape = sh
	body.add_child(cs)
	root.add_child(body)
	# ПОСЛЕ добавления и в мировых осях: стенд отнесён на 400 м вниз, и локальная позиция зоны
	# положила бы тело мимо неё (мировые координаты вне дерева — ловушка 37).
	body.global_position = area.global_position
	# Стенд общий на три шага Е2: уровень прогона сносится раньше, в шаге «предмет в руке».
	_zone = {"root": root, "area": area, "box": box, "cam": cam, "fired": false, "built": built}
	area.body_entered.connect(func(_b: Node3D): _zone["fired"] = true)


func _zone_check() -> void:
	var box: MeshInstance3D = _zone.get("box", null)
	var bad: Array[String] = []
	if box == null:
		bad.append("у зоны нет видимой коробки — разметить её можно только по числам в JSON")
	else:
		if box.layers != LayersRes.bit("debug"):
			bad.append("коробка зоны на слое %d, а не отладки (%d)" % [box.layers, LayersRes.bit("debug")])
		if (box.layers & int(_zone["cam"].cull_mask)) != 0:
			bad.append("игрок видит разметку зоны")
		if box.mesh == null or (box.mesh as BoxMesh).size == Vector3.ZERO:
			bad.append("коробка нулевого размера")
	if not bool(_zone.get("fired", false)):
		bad.append("тело внутри зоны не дало body_entered — интерьер не загрузился бы")
	if bad.is_empty():
		r.pass_("зона видна и работает скрытой: коробка %s м на слое отладки, игроку не видна, тело внутри дало body_entered" % [(box.mesh as BoxMesh).size])
	else:
		r.fail("зона видна и работает скрытой: %s" % "; ".join(bad))


## Режим игры на реальном уровне: маска, спрятанное автором и возврат ровно как было.
func _play_mode() -> void:
	var bad: Array[String] = []
	var vis: VisibilityRes = VisibilityRes.new()
	vis.falsify_play_mask = falsify == "playmask"
	var index: Array = (_zone["built"] as Dictionary)["index"]
	var files := {"start": index}
	for e in index:
		vis.register(e)
	var cam := Camera3D.new()
	head.get_parent().add_child(cam)
	# Автор спрятал группу предметов и включил отладку.
	vis.group_on["предметы"] = false
	vis.layer_on["debug"] = true
	vis.apply_to(cam, files)
	var props_hidden := _vis_count(files, "предметы", false)
	if props_hidden == 0:
		bad.append("скрытая группа не спрятала ни одного узла из %d в группе (всего записей %d, группы уровня: %s)" % [
				_vis_count(files, "предметы", true) + props_hidden, index.size(), vis.group_names()])
	var snap := vis.enter_play()
	vis.apply_to(cam, files)
	if cam.cull_mask != LayersRes.play_mask():
		bad.append("маска камеры в игре %d — игрок видит инструментарий" % cam.cull_mask)
	if _vis_count(files, "предметы", false) != 0:
		bad.append("игрок не видит предметы, спрятанные автором")
	# Разметка мест уровня лежит на слое редактора: узлы остаются, но маска их не пускает.
	var marks := 0
	for e in index:
		if str(e["layer"]) == "editor":
			marks += 1
	if marks == 0:
		bad.append("в уровне нет ни одного объекта редактора — проверять нечего")
	vis.exit_play(snap)
	vis.apply_to(cam, files)
	if cam.cull_mask != LayersRes.mask({"editor": true, "debug": true}):
		bad.append("после выхода маска %d" % cam.cull_mask)
	if _vis_count(files, "предметы", false) != props_hidden:
		bad.append("после выхода скрытие группы не вернулось")
	cam.queue_free()
	if bad.is_empty():
		r.pass_("режим игры прячет и возвращает: %d объектов редактора мимо маски, %d предметов спрятано автором и показано игроку, выход вернул и маску, и скрытия" % [marks, props_hidden])
	else:
		r.fail("режим игры прячет и возвращает: %s" % "; ".join(bad))


## Сколько узлов группы сейчас в заданном состоянии видимости.
func _vis_count(files: Dictionary, group: String, want: bool) -> int:
	var n := 0
	for file in files:
		for e in files[file]:
			if not (group in (e["groups"] as Array)):
				continue
			var node: Node = e.get("node", null)
			if node is Node3D and (node as Node3D).visible == want:
				n += 1
	return n


## Скрытая группа прячет вид, но НЕ коллайдер: человек не должен проваливаться туда, где автор
## спрятал постройки. Свидетель — луч физики, а не поле `visible`.
func _group_solid() -> void:
	var bad: Array[String] = []
	var vis: VisibilityRes = VisibilityRes.new()
	vis.falsify_group_free = falsify == "groupfree"
	var index: Array = (_zone["built"] as Dictionary)["index"]
	var files := {"start": index}
	for e in index:
		vis.register(e)
	var floor_node: Node3D = null
	for e in index:
		if str(e["uuid"]) == "floor":
			floor_node = e["node"]
	if floor_node == null:
		r.fail("скрытая группа держит: в уровне нет пола")
		(_zone["root"] as Node3D).queue_free()
		return
	vis.group_on["площадки"] = false
	vis.apply_to(null, files)
	if floor_node.visible:
		bad.append("пол не спрятался")
	var space := floor_node.get_world_3d().direct_space_state
	var from := floor_node.global_position + Vector3(0, 3.0, 0)
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 6.0)
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		bad.append("луч прошёл насквозь: спрятанный пол перестал держать")
	vis.group_on["площадки"] = true
	vis.apply_to(null, files)
	if not floor_node.visible:
		bad.append("показ группы не вернул вид")
	(_zone["root"] as Node3D).queue_free()
	if bad.is_empty():
		r.pass_("скрытая группа держит: пол скрыт видом, луч сверху всё так же попадает в него на %.2f м" % [from.y - float(hit.get("position", Vector3.ZERO).y)])
	else:
		r.fail("скрытая группа держит: %s" % "; ".join(bad))


## Папка «Группы» в меню наполняется именами из УРОВНЯ, а переключение пункта доходит до сессии
## действием «space_group:<имя>» (ловушка 41: действие, адресованное не туда, молчит).
func _group_menu() -> void:
	var bad: Array[String] = []
	var vis: VisibilityRes = VisibilityRes.new()
	for e in ((_zone["built"] as Dictionary)["index"] as Array):
		vis.register(e)
	var names := vis.group_names()
	if falsify == "groupmenu":
		names = []
	menu.catalog.set_groups(names, {"зацепы": false})
	var ids: Array = menu.catalog.children_of.get("settings_groups", [])
	if ids.size() != names.size() or names.is_empty():
		bad.append("в папке %d пунктов на %d групп уровня" % [ids.size(), names.size()])
	var seen: Array = []
	var routed := ""
	for id in ids:
		var it = menu.catalog.items[id]
		seen.append(it.title)
		if it.kind != ItemRes.Kind.TOGGLE:
			bad.append("пункт «%s» не переключатель" % it.title)
		if not str(it.action).begins_with("space_group:"):
			bad.append("пункт «%s» не адресован сессии: «%s»" % [it.title, it.action])
		elif it.title == "зацепы":
			routed = str(it.action)
			if it.on:
				bad.append("скрытая группа пришла в меню включённой")
	if routed != "space_group:зацепы":
		bad.append("нет пункта скрытой группы: %s" % [seen])
	# Пересборка не плодит пунктов: подгрузка части уровня зовёт set_groups снова.
	menu.catalog.set_groups(names, {})
	if (menu.catalog.children_of.get("settings_groups", []) as Array).size() != names.size():
		bad.append("после пересборки пунктов стало %d" % (menu.catalog.children_of["settings_groups"] as Array).size())
	if bad.is_empty():
		r.pass_("меню групп из уровня: %d переключателей (%s), скрытая пришла выключенной, действие «%s» адресовано сессии, пересборка не двоит" % [
				names.size(), ", ".join(names), routed])
	else:
		r.fail("меню групп из уровня: %s" % "; ".join(bad))


## Перехват ввода останавливает начатое движение. Сессия 29: после самопроверки открывается шар с
## запросом PIN, и человек, который в этот момент шёл, ехал всё время ввода — «пока не введу PIN и
## не уберу меню».
##
## Корень был в порядке строк: такт перемещения выходил при занятом вводе РАНЬШЕ, чем обнулял
## скорость, а заданная в прошлом такте скорость живёт в теле сама. Ждать остановки от «отпустили
## стик» нельзя: пока ввод перехвачен, события отпускания не приходят (ловушка 29).
func _input_lock() -> void:
	var bad: Array[String] = []
	var loco := LocomotionRes.new()
	var body := PlayerBody.new()
	var origin := XROrigin3D.new()
	var lk_head := Node3D.new()
	head.get_parent().add_child(body)
	body.add_child(origin)
	origin.add_child(lk_head)
	lk_head.position = Vector3(0, 1.6, 0)
	body.setup(origin, lk_head)
	body.set_eye_height(1.6)
	body.global_position = Vector3(20.0, 0.1, 20.0)  # пустой угол площади, подальше от чужих стендов
	loco.body = body
	loco.head = lk_head
	loco.origin = origin
	loco.menu = menu
	loco.falsify_no_suspend = falsify == "lockdrift"
	LocomotionRes.falsify_hold_stuck = falsify == "holdstuck"
	LocomotionRes._stuck = false
	var breaks: Array[String] = []
	loco.moved.connect(func(kind: String, why: String):
		if kind == "перемещение прервано":
			breaks.append(why))
	# Человек идёт: скорость задана прошлым тактом, как при зажатом стике.
	body.velocity = Vector3(1.4, 0.0, 0.0)
	loco.aiming = true
	# Ввод забирают: шар открыт (так и появляется запрос PIN).
	_to_root_open()
	if loco.input_free():
		bad.append("при открытом шаре ввод считается свободным")
	loco.suspend("ввод занят")
	var speed := Vector2(body.velocity.x, body.velocity.z).length()
	if speed > 0.01:
		bad.append("скорость осталась %.2f м/с — человек продолжает ехать" % speed)
	if loco.aiming:
		bad.append("прицел телепорта не брошен: отпускание стика после ввода PIN швырнёт человека")
	if breaks.size() != 1:
		bad.append("в журнале %d записей о прерывании вместо одной" % breaks.size())
	# Повторные такты молчат: запись о прерывании одна на отрезок, а не 90 в секунду.
	loco.suspend("ввод занят")
	loco.suspend("ввод занят")
	if breaks.size() > 1:
		bad.append("прерывание записано %d раз за три такта" % breaks.size())
	# И отдельно: ввод держит не только шар. Закрываем его, но PIN всё ещё спрашивают.
	menu.close()
	# Состояние — в словаре: лямбда GDScript захватывает ЗНАЧЕНИЕ локальной переменной, и снятый
	# позже флаг до неё бы не дошёл (проверка краснела бы на верном коде).
	var pin := {"waiting": true}
	loco.input_hold = func() -> String: return "ждём PIN" if bool(pin["waiting"]) else ""
	if loco.input_free():
		bad.append("при закрытом шаре, но ожидании PIN ввод считается свободным")
	pin["waiting"] = false
	if not loco.input_free():
		bad.append("после ввода PIN управление не вернулось")
	# Признак «ввод занят» берётся ОПРОСОМ состояния, а не флагом по сигналам. Сессия 30: системная
	# клавиатура прислала «показана» без парной «скрыта», флаг залип, и перемещение было выключено
	# весь прогон — человек мог двигаться только ногами по комнате.
	var pan: Panel3D = menu.panel
	pan.open_text("PIN", ["done"], "panel", {"digits": true, "masked": true})
	# Правило берётся ИЗ ПРИЛОЖЕНИЯ (тот же вызов, что в main.gd), а не переписывается здесь.
	var hold_while_text := LocomotionRes.hold_reason(false, menu.panel_locked, pan.is_text_open())
	pan.close_editor()
	var hold_after_text := LocomotionRes.hold_reason(false, menu.panel_locked, pan.is_text_open())
	if hold_while_text == "":
		bad.append("открытый ввод текста не держит перемещение")
	if hold_after_text != "":
		bad.append("после закрытия ввода текста перемещение осталось заперто: «%s»" % hold_after_text)
	# И причина обязана быть названа словами: иначе в журнале не видно, кто держит.
	if not hold_while_text.contains("текст"):
		bad.append("причина удержания не названа: «%s»" % hold_while_text)
	LocomotionRes.falsify_hold_stuck = false
	body.queue_free()
	loco.free()
	if bad.is_empty():
		r.pass_("перехват ввода останавливает движение: скорость обнулена, прицел брошен, прерывание записано один раз; ввод держат и шар, и ожидание PIN, и после него возвращается")
	else:
		r.fail("перехват ввода: %s" % "; ".join(bad))


var _ghost: Dictionary = {}


## Предмет в руке не преграждает путь человеку. Замороженное тело — статическое препятствие, и
## оказавшись в капсуле, оно её выталкивает: два предмета в двух руках мотали человека туда-сюда
## (сессия 31). Свидетель — ПРОЕЗД: капсула идёт сквозь место предмета.
##
## Подготовка и замер разнесены на кадры: смена `collision_layer` доходит до физического мира не
## в том же кадре, и проверка, сделанная подряд, оставалась зелёной даже с фальсификатором.
func _held_ghost_prep() -> void:
	var grab := GrabRes.new()
	grab.falsify_held_solid = falsify == "heldsolid"
	var cubes: Array = get_nodes_in_group("grab")
	if cubes.is_empty():
		_ghost = {}
		return
	var cube: Node3D = cubes[0]
	# Подальше от чужих стендов и над землёй, чтобы капсула ехала по прямой.
	cube.global_position = Vector3(18.0, 0.9, 18.0)
	grab.grab("right", cube, Transform3D(Basis(), cube.global_position))
	var bump := PlayerBody.new()
	var b_origin := XROrigin3D.new()
	var b_head := Node3D.new()
	head.get_parent().add_child(bump)
	bump.add_child(b_origin)
	b_origin.add_child(b_head)
	b_head.position = Vector3(0, 1.6, 0)
	# Без setup у тела нет формы вовсе, и оно проезжает сквозь что угодно: первый вариант стенда
	# показывал одинаковый путь и с предметом, и без — спас контрольный случай.
	bump.setup(b_origin, b_head)
	bump.set_eye_height(1.6)
	bump.set_physics_process(false)
	bump.global_position = Vector3(18.0, 0.0, 17.0)
	_ghost = {"grab": grab, "cube": cube, "bump": bump, "from": bump.global_position}


func _held_ghost_check() -> void:
	if _ghost.is_empty():
		r.fail("предмет в руке не преграждает путь: в уровне нет предметов — проверять нечего")
		return
	var bump: PlayerBody = _ghost["bump"]
	var cube: Node3D = _ghost["cube"]
	var grab: GrabRes = _ghost["grab"]
	var from: Vector3 = _ghost["from"]
	for i in 12:
		bump.move_and_collide(Vector3(0, 0, 0.1))
	var way := bump.global_position.distance_to(from)
	# Контроль: тот же проезд, но предмет УЖЕ отпущен — путь обязан быть перекрыт, иначе проверка
	# доказывала бы пустоту (капсула могла просто не задевать предмет).
	grab.release("right")
	bump.global_position = from
	for i in 12:
		bump.move_and_collide(Vector3(0, 0, 0.1))
	var way_solid := bump.global_position.distance_to(from)
	bump.queue_free()
	cube.queue_free()
	_ghost.clear()
	if way > 1.0 and way_solid < way - 0.1:
		r.pass_("предмет в руке не преграждает путь: сквозь него человек проходит %.2f м, а отпущенный предмет останавливает его на %.2f м" % [way, way_solid])
	else:
		r.fail("предмет в руке не преграждает путь: сквозь держимый прошёл %.2f м, сквозь отпущенный %.2f м (контроль требует, чтобы второе было заметно меньше)" % [way, way_solid])


var _climb_w: Dictionary = {}


## Лазанье у НАСТОЯЩЕЙ стены, полным тактом: `player_body` и `locomotion` вместе, как в приложении.
##
## Прежний стенд звал `climb_shift` напрямую и потому не видел главного: во время лазанья
## `_follow_head` отодвигал origin от стены (человек прижат к ней, тело упирается, остаток гасится
## сдвигом origin со скоростью 1.2 м/с). Origin несёт кисти, а лазанье считает смещение от точки
## захвата, ЗАФИКСИРОВАННОЙ в мире, — уехавшая кисть требовала сдвинуть тело обратно в стену, и так
## каждый такт. Человека вдавливало в геометрию, а хват срывался сам (сессия 31).
func _climb_wall_prep() -> void:
	var face := _obj_pos("hclimb_face")
	var face_size: Array = _obj("hclimb_face").get("size", [0.25, 3.4, 8.0])
	var hold := _obj_pos("climb3")
	if hold == Vector3.ZERO or face == Vector3.ZERO:
		_climb_w = {}
		return
	# Наружу от фасада — туда, где висит человек.
	var out := signf(hold.x - face.x)
	var face_x: float = face.x + out * float(face_size[0]) * 0.5
	var body := PlayerBody.new()
	var origin := XROrigin3D.new()
	var c_head := Node3D.new()
	var l_ctrl := XRController3D.new()
	var r_ctrl := XRController3D.new()
	head.get_parent().add_child(body)
	body.add_child(origin)
	origin.add_child(c_head)
	origin.add_child(l_ctrl)
	origin.add_child(r_ctrl)
	body.setup(origin, c_head)
	body.set_eye_height(1.6)
	body.global_position = Vector3(face_x + out * PlayerBody.RADIUS, hold.y - 1.0, hold.z)
	# Голова ФИЗИЧЕСКИ зашла за плоскость стены: капсула туда встать не может, и остаток следования
	# выходит за PUSH_MIN. Без этого возврат остатка не включается и стенд ничего не доказывает.
	c_head.global_position = Vector3(face_x - out * 0.15, body.global_position.y + 1.6, hold.z)
	r_ctrl.global_position = hold
	l_ctrl.global_position = hold + Vector3(0, -0.5, 0)
	var loco := LocomotionRes.new()
	head.get_parent().add_child(loco)
	loco.setup(body, origin, c_head, menu, l_ctrl, r_ctrl)
	loco.set_physics_process(false)
	body.set_physics_process(false)
	loco.grip_source = func(who: String) -> bool: return who == "right"
	# Шар закрыт: при открытом перемещение молчит целиком, и стенд проверял бы пустоту.
	menu.close()
	PlayerBody.falsify_climb_push = falsify == "climbpush"
	var slips: Array[String] = []
	loco.moved.connect(func(kind: String, why: String):
		if kind == "лазанье" and why.begins_with("сорвался"):
			slips.append(why))
	_climb_w = {"body": body, "loco": loco, "r": r_ctrl, "origin": origin, "head": c_head,
			"from_y": body.global_position.y, "o_from": origin.position, "slips": slips,
			"face_x": face_x, "out": out, "hold": hold}


func _climb_wall_check() -> void:
	if _climb_w.is_empty():
		r.fail("лазанье у стены: в уровне нет стены лазанья — проверять нечего")
		return
	var body: PlayerBody = _climb_w["body"]
	var loco: LocomotionRes = _climb_w["loco"]
	var r_ctrl: XRController3D = _climb_w["r"]
	var origin: Node3D = _climb_w["origin"]
	var head_node: Node3D = _climb_w["head"]
	var dt := 1.0 / 90.0
	# Контроль: случай действительно задевает возврат остатка — иначе стенд доказывал бы пустоту.
	var gate: float = Vector2(head_node.global_position.x - body.global_position.x,
			head_node.global_position.z - body.global_position.z).length()
	var bad: Array[String] = []
	if not loco.input_free():
		bad.append("ввод занят — перемещение молчит, стенд ничего не проверяет")
	# Порядок как в приложении: узел Player стоит в сцене раньше, чем добавляется locomotion.
	var took := false
	for i in 40:
		r_ctrl.position.y -= 0.005          # подтягивается: 0.45 м/с
		body._physics_process(dt)
		loco._physics_process(dt)
		took = took or loco.climb.active
	var rise: float = body.global_position.y - float(_climb_w["from_y"])
	# Свидетель — НЕ смещение origin: оно законно компенсирует ход тела, иначе голова уехала бы
	# вместе с ним (сессия 15). Важно другое: далеко ли кисть от зацепа (петля уводит её) и не
	# зашла ли капсула за плоскость стены.
	var face_x: float = _climb_w["face_x"]
	var out: float = _climb_w["out"]
	var bite: float = PlayerBody.RADIUS - (body.global_position.x - face_x) * out
	var hand_off: float = r_ctrl.global_position.distance_to(_climb_w["hold"] as Vector3)
	var held: bool = loco.climb.active
	var slips: Array = _climb_w["slips"]
	if gate <= PlayerBody.PUSH_MIN:
		bad.append("стенд не задевает возврат остатка (%.2f м при пороге %.2f) — проверять нечего" % [
				gate, PlayerBody.PUSH_MIN])
	if not took:
		bad.append("хват не состоялся ни разу — стенд не дотянулся до зацепа")
	elif not held:
		bad.append("хват сорвался сам: %s" % [slips])
	if rise < 0.15:
		bad.append("подъём %.2f м за 0.2 м хода руки — тело не идёт вверх" % rise)
	if bite > 0.02:
		bad.append("капсула вошла в стену на %.2f м" % bite)
	# Рука опускается на 0.20 м нарочно; всё, что сверх этого, — увод кисти петлёй.
	if hand_off > 0.25:
		bad.append("кисть ушла от зацепа на %.2f м (рука опустилась на 0.20)" % hand_off)
	PlayerBody.falsify_climb_push = false
	loco.free()
	body.queue_free()
	_climb_w.clear()
	if bad.is_empty():
		r.pass_("лазанье у стены: хват держится 40 тактов, подъём %.2f м за 0.20 м хода руки, капсула не входит в стену (%.3f м), кисть у зацепа (%.2f м); голова за плоскостью стены на %.2f м при пороге выталкивания %.2f" % [
				rise, maxf(0.0, bite), hand_off, gate, PlayerBody.PUSH_MIN])
	else:
		r.fail("лазанье у стены: %s" % "; ".join(bad))


var _spawn_t: Dictionary = {}


## Точка старта держит человека на полу. Сессия 32: «в самом начале спавнюсь ниже пола и при сбросе
## положения на стартовую точку проваливаюсь сквозь пол». Ставим тело ровно туда, куда его ставит
## сессия (`spawn` из данных уровня), и тактуем физику: оно обязано остаться на поверхности.
func _spawn_prep() -> void:
	var spawn: Transform3D = _level_built.get("spawn", Transform3D())
	if spawn == Transform3D():
		_spawn_t = {}
		return
	var body := PlayerBody.new()
	var origin := XROrigin3D.new()
	var s_head := Node3D.new()
	head.get_parent().add_child(body)
	body.add_child(origin)
	origin.add_child(s_head)
	s_head.position = Vector3(0, 1.6, 0)
	body.setup(origin, s_head)
	body.set_eye_height(1.6)
	body.set_physics_process(false)
	body.global_transform = spawn
	_spawn_t = {"body": body, "y": spawn.origin.y, "head": s_head}


func _spawn_check() -> void:
	if _spawn_t.is_empty():
		r.fail("старт стоит на полу: в уровне нет точки старта — проверять нечего")
		return
	var body: PlayerBody = _spawn_t["body"]
	var s_head: Node3D = _spawn_t["head"]
	var want: float = _spawn_t["y"]
	var dt := 1.0 / 90.0
	# Тактуем столько же, сколько человек стоит, пока читает подсказку.
	for i in 90:
		body._physics_process(dt)
	var feet := body.global_position.y
	var eyes := s_head.global_position.y
	var on_floor := body.is_on_floor()
	var mask := body.collision_mask
	body.queue_free()
	_spawn_t.clear()
	if absf(feet - want) < 0.05 and on_floor and eyes > want + 1.0:
		r.pass_("старт стоит на полу: за 90 тактов ноги остались на %.2f м (старт %.2f), глаза на %.2f м, тело опирается на пол" % [
				feet, want, eyes])
	else:
		r.fail("старт стоит на полу: ноги ушли на %.2f м (старт %.2f), глаза %.2f, на полу %s, маска столкновений %d" % [
				feet, want, eyes, on_floor, mask])


var _area_w: Dictionary = {}


## Смена игровой зоны АСИНХРОННА: `set_play_area_mode` лишь помечает пространство «грязным»
## (`openxr_api.cpp:1590`), а новое создаётся кадром позже. Читать режим сразу после запроса —
## значит получить старый и объявить успех отказом; ровно та же ловушка, что с частотой кадров.
##
## Сессия 32: система отдала сидячую зону, запрос на stage ушёл, а чтение подряд вернуло 2 — и
## приложение решило, что пола нет, хотя он уже был на подходе.
func _area_wait_prep() -> void:
	var sp := SpaceRes.new()
	var reads := [0]
	var mode := [int(XRInterface.XR_PLAY_AREA_SITTING)]
	sp.set_play_area = func(_m: int) -> bool: return true
	sp.play_area_mode = func() -> int:
		reads[0] += 1
		# Применяется поздно — позже, чем успевает сам запрос: иначе ожидание не понадобится, и
		# проверка не заметила бы, что его убрали.
		if reads[0] > 8:
			mode[0] = int(XRInterface.XR_PLAY_AREA_STAGE)
		return mode[0]
	_area_w = {"sp": sp, "got": -1}
	_area_w["got"] = await sp.ensure_floor_wait(head, 30)


func _area_wait_check() -> void:
	var got := int(_area_w.get("got", -1))
	var sp: SpaceRes = _area_w.get("sp", null)
	# Контроль: без ожидания тот же стенд даёт зону без пола — иначе проверка ничего не значит.
	var now := int(sp.ensure_floor()) if sp != null else -1
	_area_w.clear()
	if SpaceRes.has_floor(got):
		r.pass_("зона с полом: смена асинхронна — ожидание дождалось режима %d, а чтение сразу после запроса давало %d" % [got, int(XRInterface.XR_PLAY_AREA_SITTING)])
	else:
		r.fail("зона с полом: ожидание вернуло %d (без пола), чтение подряд — %d" % [got, now])


## Точка старта говорит ГДЕ, а высоту и посадку считает геометрия уровня (решение владельца
## 2026-09-22). Проверяем на настоящем уровне и на заведомо плохих точках: высоко над землёй,
## глубоко под ней и внутри тела.
func _drop_check() -> void:
	var bad: Array[String] = []
	var body := PlayerBody.new()
	var origin := XROrigin3D.new()
	var d_head := Node3D.new()
	head.get_parent().add_child(body)
	body.add_child(origin)
	origin.add_child(d_head)
	d_head.position = Vector3(0, 1.6, 0)
	body.setup(origin, d_head)
	body.set_eye_height(1.6)
	body.set_physics_process(false)
	PlayerBody.falsify_spawn_blind = falsify == "spawnblind"
	var spawn: Transform3D = _level_built.get("spawn", Transform3D())
	var ground: float = spawn.origin.y
	# 1. Сама точка старта: ноги садятся на землю.
	var at_spawn := body.drop_to_ground(spawn.origin)
	if not bool(at_spawn["ok"]):
		bad.append("в точке старта опора не найдена: %s" % at_spawn["why"])
	elif absf(body.global_position.y - ground) > 0.05:
		bad.append("в точке старта ноги на %.2f вместо %.2f (%s)" % [
				body.global_position.y, ground, at_spawn["why"]])
	# 2. Та же точка, но задана на 5 м выше: человек обязан оказаться на земле, а не парить.
	body.drop_to_ground(spawn.origin + Vector3(0, 5.0, 0))
	if absf(body.global_position.y - ground) > 0.05:
		bad.append("точка на 5 м выше оставила ноги на %.2f" % body.global_position.y)
	# 3. Точка УТОПЛЕНА в землю на метр: тело обязано подняться на поверхность, а не провалиться.
	body.drop_to_ground(spawn.origin - Vector3(0, 1.0, 0))
	if absf(body.global_position.y - ground) > 0.05:
		bad.append("утопленная точка оставила ноги на %.2f" % body.global_position.y)
	# 4. На крыльце: посадка идёт на ближайшую поверхность СВЕРХУ, а не на землю под ним.
	var porch := _obj_pos("porch")
	var porch_size: Array = _obj("porch").get("size", [2.6, 0.9, 3.0])
	if porch != Vector3.ZERO:
		var top: float = porch.y + float(porch_size[1]) * 0.5
		body.drop_to_ground(Vector3(porch.x, top + 0.2, porch.z))
		if absf(body.global_position.y - top) > 0.06:
			bad.append("на крыльце ноги на %.2f вместо %.2f" % [body.global_position.y, top])
	# 5. Над пустотой: честный отказ, а не тихое «поставили как есть».
	var void_res := body.drop_to_ground(Vector3(2000.0, 5.0, 2000.0))
	if bool(void_res["ok"]):
		bad.append("над пустотой посадка доложила успех")
	PlayerBody.falsify_spawn_blind = false
	body.queue_free()
	if bad.is_empty():
		r.pass_("посадка считается геометрией: в точке старта, на 5 м выше и на метр ниже ноги встают на землю %.2f; на крыльце — на его верх; над пустотой — честный отказ" % ground)
	else:
		r.fail("посадка: %s" % "; ".join(bad))


## Предмет, взятый в комнате, остаётся в руке при её выгрузке; вынесенный на улицу — не пропадает
## (решение владельца 2026-09-23).
##
## РЕШЕНИЕ о том, кого выгружать, — чистая функция `RoomItems.unload_plan`, и её свидетельствуют
## настольные проверки. Здесь свидетельствуется ЖИВОЕ, чего на столе не бывает: ящик зоны на
## настоящем `Area3D`, выживание узла и свободная рука. Прежде такой предмет освобождали прямо из
## руки, `grab.update` падал на мёртвом узле и ОСТАВЛЯЛ запись — рука была занята до конца сессии
## (проверено исполнением 2026-09-23).
##
## Подготовка и проверка разнесены по кадрам: `queue_free` освобождает узел только в конце кадра, и
## проверка, сделанная подряд, зеленела бы и с фальсификатором.
var _carry: Dictionary = {}


func _carry_prep() -> void:
	RoomItems.falsify_hand_drops = falsify == "handdrops"
	var room := "res://world/levels/start_interior.json"
	var street := "res://world/levels/start_location.json"
	var res := LevelLoader.parse(FileAccess.get_file_as_string(room))
	var street_res := LevelLoader.parse(FileAccess.get_file_as_string(street))
	if not res["ok"] or not street_res["ok"]:
		_carry = {"error": "уровень не разобран"}
		return
	# Свой корень: общий (_level_root) освобождается раньше, на шаге «предмет в руке».
	var root := Node3D.new()
	head.get_parent().add_child(root)
	# Зона берётся из ДАННЫХ улицы, а не задаётся числами в стенде: стенд, знающий координаты
	# наизусть, краснеет на верном коде при первой же перестройке уровня (сессия 21).
	var only_zone := {"objects": []}
	for o in (street_res["data"] as Dictionary).get("objects", []):
		if str((o as Dictionary).get("type", "")) == "trigger":
			(only_zone["objects"] as Array).append(o)
	var zone_built := LevelLoader.build(root, only_zone)
	var zone: Area3D = null
	for t in zone_built["triggers"]:
		if str((t as Dictionary)["file"]) == room:
			zone = (t as Dictionary)["area"] as Area3D
	var rooms: RoomItems = RoomItems.new()
	var stream: LevelStreamRes = LevelStreamRes.new()
	var built := LevelLoader.build(root, res["data"])
	var entries: Array = built["index"]
	stream.add(street, [])
	stream.add(room, (built["nodes"] as Array).duplicate())
	for entry in entries:
		rooms.register(room, entry)
	var cubes: Array = []
	for entry in entries:
		var node := (entry as Dictionary).get("node", null) as Node3D
		if node != null and node.is_in_group("grab"):
			cubes.append(node)
	if cubes.size() < 3 or zone == null:
		_carry = {"error": "кубов %d, зона %s" % [cubes.size(), zone]}
		return
	# Один взят в руку, второй вынесен на улицу и оставлен там, третий остался в комнате.
	var in_hand: Node3D = cubes[0]
	var carried_out: Node3D = cubes[1]
	var stayed: Node3D = cubes[2]
	var grab := GrabRes.new()
	grab.grab("right", in_hand, in_hand.global_transform)
	carried_out.global_position = Vector3(0.0, 0.5, 4.0)
	var items := RoomItems.survey(entries, zone, func(n: Node3D) -> bool:
		return (grab.held.get("right", {}) as Dictionary).get("node", null) == n)
	var seen := {}
	for it in items:
		seen[str((it as Dictionary)["uuid"])] = it
	var plan := rooms.unload_plan(room, street, items)
	# Та же сантехника, что в сессии: спасённые переходят улице, остальные освобождаются.
	var spared := {}
	for uuid in plan["keep"]:
		spared[str(uuid)] = true
	for n in stream.take(room):
		var node := n as Node3D
		if node != null and is_instance_valid(node) and not spared.has(str(node.get_meta("uuid", ""))):
			node.queue_free()
	_carry = {"grab": grab, "rooms": rooms, "street": street, "root": root,
			"hand": in_hand, "out": carried_out, "stayed": stayed,
			"seen": seen, "keep": plan["keep"], "free": plan["free"],
			"hand_uuid": str(in_hand.get_meta("uuid", "")),
			"out_uuid": str(carried_out.get_meta("uuid", "")),
			"stayed_uuid": str(stayed.get_meta("uuid", ""))}


func _carry_check() -> void:
	var bad: Array[String] = []
	if _carry.has("error"):
		r.fail("предмет из комнаты остаётся в руке при выгрузке: %s" % _carry["error"])
		_carry.clear()
		return
	var seen: Dictionary = _carry["seen"]
	var hand_uuid := str(_carry["hand_uuid"])
	var out_uuid := str(_carry["out_uuid"])
	var stayed_uuid := str(_carry["stayed_uuid"])
	# Живое свидетельство ящика зоны: оставшийся в комнате внутри, вынесенный на улицу — снаружи.
	if not bool((seen.get(stayed_uuid, {}) as Dictionary).get("inside", false)):
		bad.append("оставшийся в комнате куб не признан внутри зоны")
	if bool((seen.get(out_uuid, {}) as Dictionary).get("inside", true)):
		bad.append("вынесенный на улицу куб признан внутри зоны")
	if not bool((seen.get(hand_uuid, {}) as Dictionary).get("busy", false)):
		bad.append("куб в руке не признан занятым")
	var keep: Array = _carry["keep"]
	if not keep.has(hand_uuid) or not keep.has(out_uuid) or keep.has(stayed_uuid):
		bad.append("план выгрузки спас %s" % [keep])
	# Узлы: спасённые живы, оставшийся в комнате ушёл вместе с ней.
	var hand_node: Variant = _carry["hand"]
	var out_node: Variant = _carry["out"]
	var stayed_node: Variant = _carry["stayed"]
	if not is_instance_valid(hand_node) or not is_instance_valid(out_node):
		bad.append("спасённый узел освобождён: в руке %s, на улице %s" % [
				is_instance_valid(hand_node), is_instance_valid(out_node)])
	if is_instance_valid(stayed_node):
		bad.append("оставшийся в комнате не выгрузился")
	# И главное: рука. Кадр удержания на живом узле её не освобождает.
	var grab: GrabRes = _carry["grab"]
	grab.update("right", Transform3D(), 1.0 / 90.0)
	var still_holds: bool = grab.held.has("right")
	var rooms: RoomItems = _carry["rooms"]
	if rooms.owner_of(hand_uuid) != str(_carry["street"]):
		bad.append("владелец спасённого %s" % rooms.owner_of(hand_uuid))
	if not still_holds:
		bad.append("рука опустела")
	var root: Node3D = _carry.get("root", null)
	if root != null and is_instance_valid(root):
		root.queue_free()
	_carry.clear()
	RoomItems.falsify_hand_drops = false
	if bad.is_empty():
		r.pass_("предмет из комнаты остаётся в руке при выгрузке: взятый и вынесенный спасены и перешли улице, оставшийся ушёл с комнатой, рука цела")
	else:
		r.fail("предмет из комнаты остаётся в руке при выгрузке: %s" % "; ".join(bad))


## Правка настройки на панели применяется СРАЗУ, а не при повторном открытии пункта меню.
##
## Жалоба владельца 2026-09-23: «настройки применяются при повторном открытии этих настроек, а не
## сразу». Правка доходила только до шара, а свет, сетка пола и слои применялись в обработчике
## события меню — а событие это порождало ОТКРЫТИЕ пункта. Задеты были все тринадцать настроек из
## `Settings.SPACE` и `Settings.LAYERS`.
##
## Свидетель — шейдер сетки: значение правится тем же путём, что и у человека (редактор панели), и
## уния обязана измениться, пока пункт открыт, без второго захода.
var _applier: SettingsApply = SettingsApply.new()
var _applier_grid: FloorGrid


func _apply_now() -> void:
	var st := menu.settings
	st.values["grid_mode"] = "fixed"
	st.values["grid_cell_cm"] = 50.0
	# Исходное состояние ставится напрямую: иначе фальсификатор, который не доводит настройки до
	# сетки, оставил бы материал несозданным, и шаг упал бы вместо точечного покраснения.
	_applier_grid.apply(st)
	var mat: ShaderMaterial = _applier_grid.around.material_override
	var before := float(mat.get_shader_parameter("cell_m"))
	# Правим так же, как человек: открываем редактор и двигаем ползунок. Присваивание в настройки
	# прошло бы мимо всей проводки, и проверка ничего бы не значила.
	var p3 := menu.panel
	p3.open_editor(SettingEdit.new(st, "grid_cell_cm"), "правка", ["done"])
	var edit: SettingEdit = p3.edit
	var bad: Array[String] = []
	if edit == null:
		bad.append("редактор не открылся")
	else:
		edit.slider(1.0)                 # до верхнего предела настройки
		p3.edit_changed.emit()
	var after := float(mat.get_shader_parameter("cell_m"))
	var want := float(st.get_value("grid_cell_cm")) / 100.0
	p3.close_editor()
	if not is_equal_approx(before, 0.5):
		bad.append("до правки в шейдере %.3f вместо 0.5" % before)
	if not is_equal_approx(after, want):
		bad.append("после правки в шейдере %.3f, а в настройках %.3f — значение ждёт повторного открытия" % [after, want])
	if is_equal_approx(after, before):
		bad.append("шейдер не заметил правки вовсе")
	if bad.is_empty():
		r.pass_("правка на панели доходит до мира: ползунок сдвинул ячейку сетки %.2f → %.2f м прямо в шейдере, без повторного открытия пункта" % [before, after])
	else:
		r.fail("правка на панели доходит до мира: %s" % "; ".join(bad))



## Стенд перемещения с настоящей физикой: пол в пустом углу площади (ловушка 38), тело, origin,
## голова и руки — как в приложении, через `Locomotion.setup`. Собственная обработка locomotion
## выключена: такты даёт шаг прибора, иначе движок гонял бы их вперемешку (ловушка 28).
## Пол строится за кадры до замера: запрос к физике должен видеть уже зарегистрированную форму.
var _tp: Dictionary = {}

func _tp_prep() -> void:
	var at := Vector3(-40.0, 0.0, 40.0)
	var holder := Node3D.new()
	head.get_parent().add_child(holder)
	var ground := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(20.0, 0.2, 20.0)
	shape.shape = box
	ground.add_child(shape)
	holder.add_child(ground)
	ground.global_position = at + Vector3(0.0, -0.1, 0.0)
	var body := PlayerBody.new()
	var origin := XROrigin3D.new()
	var lk_head := Node3D.new()
	holder.add_child(body)
	body.add_child(origin)
	origin.add_child(lk_head)
	lk_head.position = Vector3(0, 1.6, 0)
	body.global_position = at
	var l := XRController3D.new()
	var rr := XRController3D.new()
	holder.add_child(l)
	holder.add_child(rr)
	# Рука на высоте 1.2 м смотрит вперёд (−Z): дуга ложится на пол примерно в 3.6 м.
	l.global_position = at + Vector3(0.0, 1.2, 0.0)
	rr.global_position = at + Vector3(0.3, 1.2, 0.0)
	var loco := LocomotionRes.new()
	holder.add_child(loco)
	loco.set_physics_process(false)
	loco.setup(body, origin, lk_head, menu, l, rr)
	loco.falsify_yaw_late = falsify == "yawlate"
	loco.falsify_aim_twice = falsify == "aimtwice"
	loco.falsify_arc_every = falsify == "arcrebuild"
	loco.falsify_aim_side = falsify == "aimside"
	loco.falsify_mantle_sticks = falsify == "mantlesticks"
	loco.falsify_turn_spam = falsify == "turnspam"
	loco.falsify_walk_jitter = falsify == "walkjitter"
	var st := menu.settings
	var keep := {}
	for k in ["move_mode", "move_hand", "turn_hand", "turn_mode", "teleport_turn"]:
		keep[k] = st.values.get(k, null)
	st.values["move_mode"] = "blink"
	st.values["move_hand"] = "left"
	st.values["turn_hand"] = "right"
	st.values["teleport_turn"] = true
	var stick := {"left": Vector2.ZERO, "right": Vector2.ZERO}
	loco.stick_source = func(who: String) -> Vector2: return stick[who]
	loco.grip_source = func(_who: String) -> bool: return false
	var log: Array = []
	loco.moved.connect(func(kind: String, detail: String): log.append("%s|%s" % [kind, detail]))
	_tp = {"holder": holder, "loco": loco, "body": body, "left": l, "stick": stick, "log": log,
			"keep": keep, "at": at}


## Телепорт идёт по дуге, которую человек ВИДЕЛ, с курсом, который он ЗАДАЛ.
##
## Три дефекта одного места (аудит 2026-09-23): курс читался на кадре отпускания, где палец уже у
## центра, — ноль; прицел на отпускании считался заново из позы руки, которая в этот миг дёрнулась, —
## переносило не туда, куда показывала дуга; и дуга каждый кадр строила новый меш и пускала 12 лучей
## при неподвижной руке (ловушка 48). Стенд держит руку, потом отпускает стик с рывком руки вбок.
func _tp_seen() -> void:
	var bad: Array[String] = []
	if _tp.is_empty():
		r.fail("телепорт по видимой дуге: стенд не собран")
		return
	var loco: LocomotionRes = _tp["loco"]
	var l: XRController3D = _tp["left"]
	var stick: Dictionary = _tp["stick"]
	var dt := 1.0 / 90.0
	stick["left"] = Vector2(0.7, 0.7)
	for i in 4:
		loco._move(dt, {"move": stick["left"]})
	var seen: Dictionary = loco._last_aim
	# Стенд обязан доказать, что видит пол (ловушка 45): иначе «перенесло не туда» ничего не значит.
	if seen.is_empty() or not bool(seen.get("hit", false)):
		bad.append("дуга не нашла пол стенда — проверять нечего")
	var mesh_id := loco.arc_line.mesh.get_instance_id() if loco.arc_line.mesh != null else 0
	var still_rebuilds := loco.arc_rebuilds
	if still_rebuilds != 1:
		bad.append("рука стоит 4 кадра, а дуга считалась %d раз" % still_rebuilds)
	# Рука сдвинулась — дуга обязана пересчитаться, а меш — остаться тем же.
	l.global_position += Vector3(0.02, 0.0, 0.0)
	loco._move(dt, {"move": stick["left"]})
	seen = loco._last_aim
	if loco.arc_rebuilds != still_rebuilds + 1:
		bad.append("рука сдвинулась на 2 см, а дуга не пересчиталась")
	if loco.arc_line.mesh == null or loco.arc_line.mesh.get_instance_id() != mesh_id:
		bad.append("меш дуги создан заново")
	# Отпускание: палец уходит к центру, рука в этот же миг дёргается влево на 90°.
	l.global_basis = Basis(Vector3.UP, deg_to_rad(90.0))
	stick["left"] = Vector2(0.05, 0.1)
	loco._move(dt, {"move": stick["left"]})
	var tp: Variant = loco.teleport
	var want_yaw := LocomotionRes.Teleport.aim_yaw(0.7, 0.0)
	if tp.phase == "":
		bad.append("перенос не начался: %s" % [(_tp["log"] as Array).back() if not (_tp["log"] as Array).is_empty() else "журнал пуст"])
	else:
		if not seen.is_empty() and (tp.target as Vector3).distance_to(seen["pos"]) > 0.01:
			bad.append("перенесло в %s, а дуга показывала %s" % [(tp.target as Vector3).snappedf(0.01), (seen["pos"] as Vector3).snappedf(0.01)])
		if is_nan(tp.yaw_deg) or not is_equal_approx(tp.yaw_deg, want_yaw):
			bad.append("курс %s°, а при прицеливании задан %.0f°" % [tp.yaw_deg, want_yaw])
	tp.phase = ""
	if bad.is_empty():
		r.pass_("телепорт по видимой дуге: 4 неподвижных кадра — 1 расчёт, сдвиг руки — пересчёт в тот же меш; рывок руки на отпускании не увёл перенос с %s, курс %.0f° из прицела" % [
				(seen["pos"] as Vector3).snappedf(0.01), want_yaw])
	else:
		r.fail("телепорт по видимой дуге: %s" % "; ".join(bad))


## Курс вбок при прицеливании не обрывает прицел, когда ход и поворот на одном стике.
## «Поворот главнее» (решение владельца 2026-09-22) обнулял ход при |x| ≥ 0.6, а обнулённый ход
## читался как отпускание: человек, задававший курс, переносился посреди прицеливания.
func _tp_side() -> void:
	if _tp.is_empty():
		r.fail("курс не обрывает прицел: стенд не собран")
		return
	var loco: LocomotionRes = _tp["loco"]
	var l: XRController3D = _tp["left"]
	var stick: Dictionary = _tp["stick"]
	var st := menu.settings
	st.values["move_hand"] = "both"
	st.values["turn_hand"] = "both"
	l.global_basis = Basis()
	loco.aiming = false
	loco.teleport.phase = ""
	var bad: Array[String] = []
	var dt := 1.0 / 90.0
	stick["right"] = Vector2(0.2, 0.9)
	loco._move(dt, loco.frame_sticks())
	if not loco.aiming:
		bad.append("прицел не начался от (0.2, 0.9)")
	stick["right"] = Vector2(0.75, 0.65)
	loco._move(dt, loco.frame_sticks())
	if not loco.aiming or loco.teleport.phase != "":
		bad.append("курс (0.75, 0.65) оборвал прицел: прицел %s, перенос «%s»" % [loco.aiming, loco.teleport.phase])
	# И через настоящий такт: отклонение вбок при прицеливании — курс, тело не поворачивается.
	# Фальсификатор `aimturn` был объявлен в locomotion и не проверялся ни одним прибором.
	var body: PlayerBody = _tp["body"]
	loco.falsify_aim_turn = falsify == "aimturn"
	var yaw0 := body.global_rotation.y
	for i in 3:
		loco._physics_process(dt)
	loco.falsify_aim_turn = false
	if not loco.input_free():
		bad.append("стенд: ввод занят (%s) — такт не дошёл до механик" % loco._hold_reason())
	elif not loco.aiming:
		bad.append("в такте прицел оборвался")
	elif absf(rad_to_deg(body.global_rotation.y - yaw0)) > 0.1:
		bad.append("при прицеливании тело повернулось на %.0f° — стик вбок крутит, а не задаёт курс" % rad_to_deg(body.global_rotation.y - yaw0))
	# Без прицела то же отклонение — поворот, и ход от него не идёт: правило владельца цело.
	loco.aiming = false
	loco.teleport.phase = ""
	var f := loco.frame_sticks()
	if (f["move"] as Vector2).length() > 0.01:
		bad.append("без прицела «поворот главнее» больше не действует: ход %s" % f["move"])
	stick["right"] = Vector2.ZERO
	st.values["move_hand"] = "left"
	st.values["turn_hand"] = "right"
	if bad.is_empty():
		r.pass_("курс не обрывает прицел: один стик на обе механики, (0.75, 0.65) держит прицел и 3 такта не поворачивает тело; без прицела то же отклонение — поворот без хода")
	else:
		r.fail("курс не обрывает прицел: %s" % "; ".join(bad))


## Возврат в стартовую точку во время перевала — перевал бросается. Состояние перевала живёт в
## locomotion (`_mantle`), и снятый у тела `mantling` его не трогал: следующий такт уносил тело
## обратно на траекторию (окно Mantle.RISE_S). Свидетель — место тела после такта, а не флаг.
## `main.gd:respawn` зовёт `cancel_mantle` той же строкой; стенд гоняет её и настоящий такт.
func _mantle_cancel() -> void:
	if _tp.is_empty():
		r.fail("возврат отменяет перевал: стенд не собран")
		return
	var loco: LocomotionRes = _tp["loco"]
	var body: PlayerBody = _tp["body"]
	var at: Vector3 = _tp["at"]
	loco._mantle = {"from": at + Vector3(5.0, 0.0, -5.0), "to": at + Vector3(5.0, 1.5, -5.5), "t": 0.2}
	body.mantling = true
	# Ровно то, что делает respawn: отмена, флаг тела, место старта.
	loco.cancel_mantle()
	body.mantling = false
	body.global_position = at
	loco._physics_process(1.0 / 90.0)
	var gone := body.global_position.distance_to(at)
	loco._mantle = {}
	if gone < 0.01:
		r.pass_("возврат отменяет перевал: после такта тело на месте старта (ушло %.3f м)" % gone)
	else:
		r.fail("возврат отменяет перевал: такт унёс тело на %.2f м — обратно на траекторию перевала" % gone)



## Наши переносы помечают себя на теле — иначе сторож рывка не отличит их от дефекта и потратит на
## них лимит строк (сессия 24: к 17:52:39 десять строк съели телепорты и перевал). Через настоящий
## такт locomotion: телепорт и перевал — ноги, присед — origin.
func _transfer_marks() -> void:
	if _tp.is_empty():
		r.fail("наши переносы помечают себя: стенд не собран")
		return
	PlayerBody.falsify_unmarked = falsify == "transferdumb"
	# Свой стенд, в стороне от тел соседних шагов (ловушка 38): у тела стенда `_tp` нет головы.
	var holder: Node = _tp["holder"]
	var at := Vector3(60.0, 0.0, -60.0)
	var body := PlayerBody.new()
	var m_origin := XROrigin3D.new()
	var m_head := Node3D.new()
	holder.add_child(body)
	body.add_child(m_origin)
	m_origin.add_child(m_head)
	m_head.position = Vector3(0, 1.6, 0)
	body.setup(m_origin, m_head)
	body.global_position = at
	body.set_physics_process(false)
	var loco := LocomotionRes.new()
	holder.add_child(loco)
	loco.set_physics_process(false)
	loco.setup(body, m_origin, m_head, menu, _tp["left"], _tp["left"])
	var dt := 1.0 / 90.0
	var bad: Array[String] = []
	var got: Array[String] = []
	var seq := body.transfer_seq
	loco.teleport.start(loco.head.global_position, at + Vector3(2.0, 0.0, -2.0), "blink")
	for i in 200:
		if loco.teleport.phase == "":
			break
		loco._physics_process(dt)
	var moved := body.global_position.distance_to(at)
	# Стенд обязан доказать, что перенос был (ловушка 45): иначе «не помечен» ничего не значит.
	if moved < 1.0:
		bad.append("телепорт не перенёс тело (%.2f м) — проверять нечего" % moved)
	elif body.transfer_seq == seq or body.transfer_label != "телепорт" or body.transfer_parts != ["body"]:
		bad.append("телепорт на %.1f м: пометка «%s» %s, номер %d → %d" % [moved, body.transfer_label, body.transfer_parts, seq, body.transfer_seq])
	else:
		got.append("телепорт %.1f м" % moved)
	seq = body.transfer_seq
	loco._mantle = {"from": body.global_position, "to": body.global_position + Vector3(0.0, 1.0, -0.5), "t": 0.0}
	body.mantling = true
	loco._physics_process(dt)
	if body.transfer_seq == seq or body.transfer_label != "перевал" or body.transfer_parts != ["body"]:
		bad.append("перевал: пометка «%s» %s, номер %d → %d" % [body.transfer_label, body.transfer_parts, seq, body.transfer_seq])
	else:
		got.append("перевал")
	loco.cancel_mantle()
	body.mantling = false
	body.global_position = at
	seq = body.transfer_seq
	body.set_crouch(0.3)
	if body.transfer_seq == seq or body.transfer_label != "присед" or body.transfer_parts != ["origin"]:
		bad.append("присед: пометка «%s» %s, номер %d → %d" % [body.transfer_label, body.transfer_parts, seq, body.transfer_seq])
	else:
		got.append("присед")
	body.set_crouch(0.0)
	PlayerBody.falsify_unmarked = false
	loco.queue_free()
	body.queue_free()
	if bad.is_empty():
		r.pass_("наши переносы помечают себя: %s" % ", ".join(got))
	else:
		r.fail("наши переносы помечают себя: %s" % "; ".join(bad))

## Плавный поворот пишется отрезком: строка на начало и строка на конец с суммой. Прежде — строка
## на каждый такт выше мёртвой зоны, 90 строк в секунду.
func _turn_segments() -> void:
	if _tp.is_empty():
		r.fail("плавный поворот отрезками: стенд не собран")
		return
	var loco: LocomotionRes = _tp["loco"]
	var log: Array = _tp["log"]
	var st := menu.settings
	st.values["turn_mode"] = "smooth"
	log.clear()
	var dt := 1.0 / 90.0
	for i in 45:
		loco._turn(dt, {"turn": Vector2(1.0, 0.0)})
	loco._turn(dt, {"turn": Vector2.ZERO})
	loco._turn(dt, {"turn": Vector2.ZERO})
	var turns := log.filter(func(x: String) -> bool: return x.begins_with("поворот|"))
	var want := float(st.get_value("turn_speed")) * 45.0 * dt
	var ok: bool = turns.size() == 2 and str(turns[1]).begins_with("поворот|плавный %.0f°" % want)
	st.values["turn_mode"] = "snap"
	if ok:
		r.pass_("плавный поворот отрезками: 45 тактов — две строки, «%s»" % str(turns[1]).get_slice("|", 1))
	else:
		r.fail("плавный поворот отрезками: строк %d за 45 тактов, ожидались 2 с суммой %.0f°: %s" % [
				turns.size(), want, turns.slice(0, 3)])


## Дёрганье стика не заливает журнал: отрезок ходьбы короче WALK_CLAIM_M не пишет ни «пошёл», ни
## «встал», но и не пропадает — число коротких уходит в строку ближайшего настоящего отрезка.
## В журнале сессии 21:15 из 846 отрезков 529 были короче 30 см.
func _walk_jitter() -> void:
	if _tp.is_empty():
		r.fail("короткие рывки ходьбы: стенд не собран")
		return
	var loco: LocomotionRes = _tp["loco"]
	var body: PlayerBody = _tp["body"]
	var log: Array = _tp["log"]
	log.clear()
	var p := body.global_position
	for i in 5:
		loco._track_walk("head", true)
		p += Vector3(0.1, 0.0, 0.0)
		body.global_position = p
		loco._track_walk("head", true)
		loco._track_walk("head", false)
	var after_jitter := log.size()
	loco._track_walk("head", true)
	body.global_position = p + Vector3(0.0, 0.0, -2.0)
	loco._track_walk("head", true)
	loco._track_walk("head", false)
	var ok: bool = after_jitter == 0 and log.size() == 2 and str(log[0]) == "ходьба|пошёл: head" \
			and str(log[1]).begins_with("ходьба|встал: head, 2.00 м") and str(log[1]).ends_with("коротких рывков 5")
	# Стенд отработал последним — вернуть настройки и убрать узлы.
	var st := menu.settings
	for k in (_tp["keep"] as Dictionary):
		if _tp["keep"][k] == null:
			st.values.erase(k)
		else:
			st.values[k] = _tp["keep"][k]
	(_tp["holder"] as Node).queue_free()
	_tp = {}
	if ok:
		r.pass_("короткие рывки ходьбы: 5 рывков по 10 см — ни строки, отрезок 2 м — «%s»" % str(log[1]).get_slice("|", 1))
	else:
		r.fail("короткие рывки ходьбы: после рывков строк %d, всего %d: %s" % [after_jitter, log.size(), log.slice(0, 4)])



## Догон головы не двигает вид по вертикали.
##
## Тело догоняет голову по горизонтали, а origin отъезжает назад ровно на пройденное — чтобы голова
## осталась там, где человек стоит. Если в «пройденное» попадает ВЕРТИКАЛЬ (скруглённое дно капсулы
## наехало на ребро бордюра, депенетрация), origin уезжает вниз на неё, а обратный ход тела —
## тяготением — уже не компенсируется: вид опускается и остаётся ниже. Кандидат на «рывок вниз и
## стоп» при появлении (2026-09-26) и на глаза −0.8…−1.0 м в сессиях 2026-09-22. Голова скачет так,
## как при смене пространства отсчёта: разом на метры.
##
## Свидетель — высота глаз НАД НОГАМИ: `head.y − body.y` обязана остаться ростом, чем бы ни кончился
## догон. Два случая: через бордюр 12 см (ниже радиуса капсулы 0.22) и по ровному полу на 2 м.
var _fy: Dictionary = {}

func _follow_y_prep() -> void:
	var at := Vector3(40.0, 0.0, -40.0)
	var holder := Node3D.new()
	head.get_parent().add_child(holder)
	var mk := func(center: Vector3, size: Vector3) -> void:
		var b := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		cs.shape = box
		b.add_child(cs)
		holder.add_child(b)
		b.global_position = center
	mk.call(at + Vector3(0.0, -0.1, 0.0), Vector3(20.0, 0.2, 20.0))
	# Бордюр: верх 0.12, ребро в 0.6 м справа от тела.
	mk.call(at + Vector3(1.6, 0.06, 0.0), Vector3(2.0, 0.12, 4.0))
	var bodies: Array = []
	for i in 2:
		var b := PlayerBody.new()
		var o := XROrigin3D.new()
		var h := Node3D.new()
		holder.add_child(b)
		b.add_child(o)
		o.add_child(h)
		h.position = Vector3(0, 1.6, 0)
		b.setup(o, h)
		b.set_eye_height(1.6)
		b.falsify_follow_y = falsify == "followy"
		# Тела разведены по месту (ловушка 38): второе — на ровном полу в 6 м.
		b.global_position = at + Vector3(0.0, 0.0, 6.0 * i)
		bodies.append({"body": b, "origin": o, "head": h})
	_fy = {"holder": holder, "bodies": bodies}


func _follow_y_jump() -> void:
	if _fy.is_empty():
		return
	# Через бордюр — на 1.2 м вправо; по ровному полу — на 2 м вперёд. Как при смене пространства.
	var jumps := [Vector3(1.2, 1.6, 0.0), Vector3(0.0, 1.6, -2.0)]
	for i in 2:
		var rec: Dictionary = _fy["bodies"][i]
		rec["eye_over_feet_before"] = (rec["head"] as Node3D).global_position.y - (rec["body"] as Node3D).global_position.y
		(rec["head"] as Node3D).position = jumps[i]


func _follow_y_check() -> void:
	if _fy.is_empty():
		r.fail("догон головы не двигает вид по вертикали: стенд не собран")
		return
	var bad: Array[String] = []
	var got: Array[String] = []
	var names := ["через бордюр", "по ровному полу"]
	for i in 2:
		var rec: Dictionary = _fy["bodies"][i]
		var b: PlayerBody = rec["body"]
		var h: Node3D = rec["head"]
		var o: Node3D = rec["origin"]
		var over := h.global_position.y - b.global_position.y
		var was: float = rec["eye_over_feet_before"]
		got.append("%s: глаза над ногами %.3f → %.3f, origin.y %.3f, ноги %.3f" % [names[i], was, over, o.position.y, b.global_position.y])
		if absf(over - was) > 0.02:
			bad.append("%s — глаза над ногами %.3f вместо %.3f (origin ушёл по вертикали на %.3f)" % [names[i], over, was, o.position.y])
	(_fy["holder"] as Node).queue_free()
	_fy = {}
	if bad.is_empty():
		r.pass_("догон головы не двигает вид по вертикали: %s" % "; ".join(got))
	else:
		r.fail("догон головы не двигает вид по вертикали: %s" % "; ".join(bad))



## Перевал ставит НА ПЛОЩАДКУ: ноги на её поверхности, глаза выше на рост (владелец, 2026-09-26).
##
## Шлем 2026-09-26 17:51: «перевал: на площадку 3.05 м» у крыши высотой 3.60, и через кадр тело
## вытолкнуло на +0.55. Рука держала зацеп climb7 (верх 3.04) — ниже зоны размеченной кромки, и
## сработал запасной луч вниз перед головой: он упал на ТОРЧАЩИЙ из стены зацеп и принял его за
## площадку. Прежний стенд перевала этого не видел: он задавал перенос сразу, с целью из данных, и
## `_try_mantle` не вызывал вовсе.
##
## Геометрия — настоящая улица из данных; такты намерения идут через `_try_mantle`, перенос — через
## `_mantle_tick`, потом физика тела. Два случая: рука на climb7 (луч) и рука в зоне кромки (данные).
var _mt: Dictionary = {}

func _mantle_top_prep() -> void:
	var street := "res://world/levels/start_location.json"
	var res := LevelLoader.parse(FileAccess.get_file_as_string(street))
	if not res["ok"]:
		return
	var root := Node3D.new()
	head.get_parent().add_child(root)
	LevelLoader.build(root, res["data"])
	_mt = {"root": root}


func _mantle_top_case(hold_uuid: String, head_y: float) -> Dictionary:
	var loco := LocomotionRes.new()
	var body := PlayerBody.new()
	var origin := XROrigin3D.new()
	var m_head := Node3D.new()
	(_mt["root"] as Node).add_child(body)
	body.add_child(origin)
	origin.add_child(m_head)
	m_head.position = Vector3(0, 1.6, 0)
	body.setup(origin, m_head)
	body.set_eye_height(1.6)
	loco.body = body
	loco.head = m_head
	loco.origin = origin
	loco.falsify_mantle_spot = falsify == "mantlespot"
	(_mt["root"] as Node).add_child(loco)
	loco.set_physics_process(false)
	# Висит снаружи стены лицом к ней (стена — в −X), глаза на head_y. Голова так, чтобы луч поиска
	# (PROBE_AHEAD_M перед ней) пришёлся на торчащий зацеп — как на шлеме.
	var hold := _obj_pos(hold_uuid)
	body.global_position = Vector3(hold.x + MantleRes.PROBE_AHEAD_M, head_y - 1.6, hold.z)
	m_head.rotation = Vector3(0.0, deg_to_rad(90.0), 0.0)
	loco.climb.grab("right", hold)
	var said: Array = []
	loco.moved.connect(func(kind: String, d: String):
		if kind == "перевал":
			said.append(d))
	var dt := 1.0 / 90.0
	for i in 60:
		if not loco._mantle.is_empty():
			break
		loco._try_mantle(dt, {"right": hold})
	var started := not loco._mantle.is_empty()
	for i in 60:
		if loco._mantle.is_empty():
			break
		loco._mantle_tick(dt)
	var feet_after_mantle := body.global_position.y
	# Физика тела после переноса: вытолкнет ли из геометрии.
	body.set_physics_process(false)
	for i in 20:
		body.velocity = Vector3(0, -1.0, 0)
		body.move_and_slide()
	var out := {"started": started, "said": said, "feet_mantle": feet_after_mantle,
			"feet": body.global_position.y, "eyes": m_head.global_position.y}
	loco.queue_free()
	body.queue_free()
	return out


func _mantle_top_check() -> void:
	if _mt.is_empty():
		r.fail("перевал ставит на площадку, а не на зацеп: уровень не собран")
		return
	var roof_top := _obj_pos("hclimb_roof").y + float((_obj("hclimb_roof").get("size", [0, 0.2, 0]) as Array)[1]) * 0.5
	var ledge := _obj("ledge_roof")
	var ledge_y := float((ledge.get("pos") as Array)[1])
	var cases := [["рука на climb7, под кромкой (луч)", "climb7", 3.98], ["рука на climb8, в зоне кромки (данные)", "climb8", ledge_y + 0.3]]
	var bad: Array[String] = []
	var got: Array[String] = []
	for c in cases:
		var o: Dictionary = _mantle_top_case(c[1], c[2])
		var feet: float = o["feet"]
		var line := "%s: перенос до %.2f, после физики ноги %.2f, глаза над ногами %.2f" % [c[0], o["feet_mantle"], feet, float(o["eyes"]) - feet]
		got.append(line)
		if not o["started"]:
			bad.append("%s — перевал не начался" % c[0])
		elif absf(float(o["feet_mantle"]) - roof_top) > 0.05 or absf(feet - roof_top) > 0.05 or absf(float(o["eyes"]) - feet - 1.6) > 0.05:
			bad.append("%s — крыша на %.2f (%s)" % [line, roof_top, "; ".join(o["said"])])
	(_mt["root"] as Node).queue_free()
	_mt = {}
	if bad.is_empty():
		r.pass_("перевал ставит на площадку, а не на зацеп: крыша %.2f — %s" % [roof_top, "; ".join(got)])
	else:
		r.fail("перевал ставит на площадку, а не на зацеп: %s" % "; ".join(bad))
