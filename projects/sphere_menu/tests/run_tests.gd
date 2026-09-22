extends SceneTree

## Настольные проверки прототипа шар-меню (Ф2, шаг 1). Прибор пишется до сессии (PRACTICES §1.1).
##
## Запуск:
##   godot/bin/godot.linuxbsd.editor.x86_64 --headless --path projects/sphere_menu \
##       --script res://tests/run_tests.gd [-- --falsify=<имя>]
##
## Пол — по числу исполненных проверок, ожидаемое число выводится из тех же
## массивов, по которым идут циклы (§1.2, §1.8). Код возврата 0 — только при
## сошедшемся поле и нуле отказов.
##
## Фальсификаторы (§2.1–2.2) портят ДАННЫЕ, а не код, и обязаны покраснеть точечно:
##   --falsify=neighbors  у ячейки 0 глобуса m=3 одна связь заменена связью с чужой
##                        ячейкой — краснеет только симметрия соседства m=3;
##   --falsify=shift      поворот на две ячейки вместо одной — краснеет только
##                        проверка шага вращения (обе поверхности в одной проверке).
##                        Не полторы: активная попала бы на границу двух ячеек.
##   --falsify=mirror     формула подписи первой версии шейдера (отражённый текст на
##                        шлеме) — краснеет только ориентация подписи;
##   --falsify=undo       в проверке изменений каталога пропущена одна отмена —
##                        краснеет только «изменения и отмена»;
##   --falsify=grab       поворот трекбола применён с обратным знаком — краснеет
##                        только «трекбол»;
##   --falsify=press      порог удержания 0 мс — краснеет только «короткое и удержание»;
##   --falsify=relax      центры сеток до выравнивания (из тех же файлов) — краснеют только
##                        «равномерность» и «контуры» семейств с выравниванием (icosa, octa,
##                        fib): контуры запечены по выровненным центрам и с сырыми не сходятся;
##                        кольца не выравниваются и остаются зелёными — контроль;
##   --falsify=uniform    все ячейки глобуса одного размера — краснеет только «размер по контуру»;
##   --falsify=stick      прежняя формула стика (горизонталь вокруг «верха» шара) —
##                        краснеет только «стик»;
##   --falsify=smooth     сглаживание руки 0 в проверке фильтра — краснеет только
##                        «сглаживание руки»;
##   --falsify=keypad     «,» набирается как «.» не распознанной строкой — ввод «2,75»
##                        не даёт 2.75, краснеет только «правка значения»;
##   --falsify=favorite   удаление объекта не чистит избранное — краснеет только «избранное»;
##   --falsify=rootback   на корне раздача с «Назад» — краснеет только «корень»;
##   --falsify=descend    спуск к ячейке ограничен одним шагом — краснеет только «поиск ячейки»;
##   --falsify=hexhide    глобус без пятиугольников раздаёт пункты и на них — краснеет только
##                        «скрытые дефекты»;
##   --falsify=demo       путь стика в демонстрации без последнего отрезка —
##                        краснеет только «демонстрации»;
##   --falsify=faceup     «лицом к шлему» строит шар от МИРОВОГО верха (как до сессии 3) —
##                        краснеет только «лицом к шлему устойчиво»;
##   --falsify=shake      отрезок встряхивания засчитывается без порога пройденного пути —
##                        краснеет только «встряхивание» (на контроле «дрожь 6 Гц»);
##   --falsify=panelshow  пустая ячейка считается содержимым панели (панель висит всегда,
##                        как до шага 1е) — краснеет только «видимость панели»;
##   --falsify=redraw     версия рендера линзы меняется на каждом повороте (как до шага 1з) —
##                        краснеет только «перерисовка по делу»;
##   --falsify=lenstwin   близнец шейдера линзы закручивает плоскость в обратную сторону —
##                        краснеет только «шейдер линзы»;
##   --falsify=pagegap    следующая страница начинается на пункт позже — краснеет только «страницы»;
##   --falsify=nextleft   «Дальше» глобуса встаёт слева, на место «Назад», — краснеет только
##                        «служебные ячейки»;
##   --falsify=glyphx     начало буквы не сдвигается на ширину предыдущей — краснеет только
##                        «раскладка подписи»;
##   --falsify=shotlimit  порог места сравнивается в мегабайтах, сумма — в байтах — краснеет только
##                        «место под скриншоты»;
##   --falsify=chordone   скриншот от одного стика — краснеет только «оба стика»;
##   --falsify=scenarioorder «Раньше» засчитывается без «Дальше» — краснеет только «сценарий теста»;
##   --falsify=nobuffer   строки, записанные до открытия журнала, снова теряются молча (в сессии 15
##                        так пропала запись «уровень») — краснеет только «журнал до открытия»;
##   --falsify=helpstale  подсказка не зависит от состояния шара (текст сессии 16, где про
##                        перемещение не сказано нигде) — краснеет только «подсказка по состоянию
##                        шара»;
##   --falsify=signblind  подсказка в мире принимается без текста — краснеет только «подсказка в мире»;
##   --falsify=onehand    настройки руки не действуют, движение прибито к левому стику, поворот к
##                        правому — краснеет «рука движения и поворота» в ДЫМОВОМ прогоне (здесь
##                        настольной проверки с таким именем нет: обещание висело зря);
##   --falsify=sitting    зона с полом при запуске не запрашивается — остаётся сидячая, и высота
##                        головы считается не от земли; краснеет только «зона с полом при запуске»;
##   --falsify=maskclimb  страховка возврата маски стоит после раннего выхода лазанья — краснеет
##                        только «столкновения возвращаются сами»;
##   --falsify=climbpush  возврат остатка работает и во время лазанья — краснеет только «возврат
##                        остатка не возит лезущего»;
##   --falsify=joinblind  связность уровня не проверяется — «на глаз», как до 2026-09-22, когда
##                        лестница сидела в площадке, а площадка висела консолью; краснеет только
##                        «связность уровня: прибор»;
##   --falsify=layerany   неизвестный слой молча становится «игрой» вместо отказа разбора —
##                        краснеет только «слои объектов»;
##   --falsify=grouporany объект виден, если видима ХОТЬ ОДНА его группа, — краснеет только
##                        «видимость групп»;
##   --falsify=snapshotref снимок режима игры держит ссылки вместо копий — краснеет только «снимок
##                        режима игры»;
##   --falsify=arccoarse  линия дуги рисуется редкими точками лучей — дуга угловатая; краснеет
##                        только «курс при телепорте»;
##   --falsify=arcstep    дуга снова считается сложением шагов, и её форма зависит от числа
##                        сегментов — краснеет только «курс при телепорте»;
##   --falsify=crouchquiet про присед в подсказке не сказано — краснеет только «подсказка по
##                        состоянию шара»;
##   --falsify=mantleease перевал снова идёт с ускорением (камера разгоняется — в VR запрещено) —
##                        краснеет только «перевал через край»;
##   --falsify=mantleeager намерение засчитывается без высоты головы — краснеет только «перевал
##                        через край»;
##   --falsify=ledgeany   кромка принимается без точки приземления — краснеет только «кромка в
##                        данных»;
##   --falsify=mantleany  перевал начинается при любой находке — человека затаскивает на наклонные
##                        стены и на то, что выше головы; краснеет только «перевал через край»;
##   --falsify=pullwide   конус призыва раскрыт до 90° — притягивается что попало; краснеет только
##                        «призыв предмета»;
##   --falsify=pullflick  рывком кисти считается любое движение — краснеет только «призыв предмета»;
##   --falsify=crouchtall капсула не укорачивается при приседании — краснеет только «присед и
##                        виньетка по ускорению»;
##   --falsify=vigspeed   виньетка «по ускорению» считается по скорости — краснеет только «присед и
##                        виньетка по ускорению»;
##   --falsify=scenariolist  сценарий снова показывает весь список оставшихся шагов вместо текущего —
##                        краснеет только «сценарий теста»;
##   --falsify=actionorphan  пункт-действие получает имя с неизвестным навигатору префиксом —
##                        краснеет только «действия меню адресованы»;
##   --falsify=signevery  разворот табличек считается каждый кадр (цена кадра сессии 24) — краснеет
##                        только «кадр: лишняя работа»;
##   --falsify=pullevery  нить призыва перестраивается каждый кадр на новом меше — краснеет только
##                        «кадр: лишняя работа»;
##   --falsify=climbdrift точка захвата снова плывёт за рукой — лазанье теряет силу (дефект
##                        сессии 17); краснеет только «лазанье»;
##   --falsify=nobreak    хват не срывается, как бы далеко рука ни ушла, — краснеет только «лазанье»;
##   --falsify=signbillboard таблички снова разворачиваются билбордом Godot, то есть следуют за
##                        поворотом шлема, а не смотрят на него — краснеет только «подсказка
##                        смотрит на человека»;
##   --falsify=keeploaded выход из зоны не начинает отсчёт выгрузки — часть уровня остаётся навсегда
##                        (поведение сессии 17); краснеет только «подгрузка и выгрузка по зоне».

const Report := preload("res://probe_report.gd")
const Goldberg := preload("res://menu/goldberg.gd")
const Layout := preload("res://menu/layout.gd")
const State := preload("res://menu/state.gd")
const Item := preload("res://menu/item.gd")
const Catalog := preload("res://menu/catalog_demo.gd")
const Globe := preload("res://menu/surface_globe.gd")
const Lens := preload("res://menu/surface_lens.gd")
const Surface := preload("res://menu/surface.gd")
const Active := preload("res://menu/active_cell.gd")
const Spring := preload("res://menu/spring.gd")
const Press := preload("res://menu/press.gd")
const Grab := preload("res://menu/grab.gd")
const SettingsRes := preload("res://menu/settings.gd")
const Wizard := preload("res://menu/wizard.gd")
const Navigator := preload("res://menu/navigator.gd")
const Stick := preload("res://menu/stick.gd")
const HandFollow := preload("res://menu/hand_follow.gd")
const MenuRes := preload("res://menu/sphere_menu.gd")
const ShakeRes := preload("res://menu/shake.gd")
const SwipeRes := preload("res://menu/swipe.gd")
## Разгон и торможение вспышки встряхивания в проверке, с.
const SHAKE_RAMP := 0.15
const SettingEdit := preload("res://menu/setting_edit.gd")
const DemoRes := preload("res://menu/demo.gd")
const ExportRes := preload("res://session/export.gd")
const LabelTextRes := preload("res://menu/label_text.gd")
const ScreenshotRes := preload("res://session/screenshot.gd")
const ChordRes := preload("res://input/chord.gd")
const ArbiterRes := preload("res://input/input_arbiter.gd")
const HandPoseRes := preload("res://input/hand_pose.gd")
const HandGestureRes := preload("res://input/hand_gesture.gd")
const HandTouchRes := preload("res://input/hand_touch.gd")
const HandSourceRes := preload("res://input/hand_source.gd")
const HandFeaturesRes := preload("res://probe_hand_features.gd")
const SynthHand := preload("res://tests/synth_hand.gd")
const InputSettingsRes := preload("res://profile/input_settings.gd")
const WizardRes := preload("res://menu/wizard.gd")
const PinRes := preload("res://profile/pin.gd")
const UserProfileRes := preload("res://profile/user_profile.gd")
const ProfileStoreRes := preload("res://profile/profile_store.gd")
## Этап C (ADR-0010): профили пользователей.
const PROFILE_CHECKS := ["PIN", "хранилище профилей", "перенос в профиль", "выгрузка без секретов", "места",
		"проекты"]
const SecretBoxRes := preload("res://accounts/secret_box.gd")
const ApiKeyRes := preload("res://accounts/api_key.gd")
const DeviceFlowRes := preload("res://accounts/device_flow.gd")
## Этап D (ADR-0011): аккаунты.
const ACCOUNT_CHECKS := ["секреты", "ключи API", "поток кода устройства"]
const EyeMeasureRes := preload("res://world/eye_measure.gd")
const SpaceRes := preload("res://world/space.gd")
## Этап Ф3: пространство.
const SPACE_CHECKS := ["высота глаз окном", "сброс пространства", "зона с полом при запуске"]
const TeleportRes := preload("res://locomotion/teleport.gd")
const TurnRes := preload("res://locomotion/turn.gd")
const PlayerBodyRes := preload("res://locomotion/player_body.gd")
const SelfCheckRes := preload("res://session/selfcheck.gd")
const ContinuousRes := preload("res://locomotion/continuous.gd")
const ClimbRes := preload("res://locomotion/climb.gd")
const VignetteRes := preload("res://locomotion/vignette.gd")
const LevelRes := preload("res://world/level_loader.gd")
const GrabRes := preload("res://world/grab.gd")
## Этап Ф3, часть 2: перемещение и уровень.
const MOVE_CHECKS := ["дуга телепорта", "перенос и рывок", "повороты", "непрерывное движение",
		"виньетка", "лазанье", "разбор уровня", "подсказка в мире",
		"подгрузка и выгрузка по зоне", "подсказка смотрит на человека",
		"призыв предмета", "курс при телепорте", "присед и виньетка по ускорению",
		"перевал через край", "кромка в данных", "столкновения возвращаются сами",
		"кадр: лишняя работа", "слои объектов", "видимость групп", "снимок режима игры",
		"связность уровня: прибор", "уровень улицы связен", "поворот главнее хода",
		"возврат остатка не возит лезущего", "самопроверка: быстрая и полная"]
const LayersRes := preload("res://world/layers.gd")
const LevelCheck := preload("res://world/level_check.gd")
const LocomotionRes := preload("res://locomotion/locomotion.gd")
const VisibilityRes := preload("res://world/visibility.gd")
const MantleRes := preload("res://locomotion/mantle.gd")
const PullRes := preload("res://world/pull.gd")
const SignFaceRes := preload("res://world/sign_face.gd")
const PullViewRes := preload("res://world/pull_view.gd")
const LevelStreamRes := preload("res://world/level_stream.gd")
const ProjectsRes := preload("res://profile/projects.gd")
const JournalRes := preload("res://session/journal.gd")
const HelpTextRes := preload("res://session/help_text.gd")
## Журнал сессии: строки до открытия файла; подсказка по состоянию шара.
const SESSION_CHECKS := ["журнал до открытия", "подсказка по состоянию шара"]
const ScenarioRes := preload("res://session/scenario.gd")

## Уровни икосаэдра под проверками поверхностей: там O(n²) поиски, крупные ничего не добавляют.
const FREQS := [1, 2, 3, 4, 5]
const GOLDBERG_CHECKS := ["число ячеек", "дефекты", "стороны", "симметрия", "контуры", "равномерность", "ряд размеров"]
## Пороги равномерности по семейству — замер запекателя 2026-09-16 после выравнивания, с запасом
## ~1%: худший разброс расстояний до соседей (max/min) и худшая вытянутость по всем уровням.
## icosa 1.230 / 1.071, octa 1.638 / 1.161, fib 1.639 / 1.184, rings 1.730 / 1.495 (кольца не
## выравниваются — у них это исходная раскладка). До выравнивания: icosa до 1.437 / 1.193,
## octa до 2.689 / 1.485, fib 1.693 / 1.325 — фальсификатор relax.
const UNIFORM_MAX := {"icosa": [1.24, 1.08], "octa": [1.65, 1.17], "fib": [1.66, 1.19], "rings": [1.74, 1.50]}
## Зазор между соседними отрисованными ячейками, доля расстояния между центрами:
## икосаэдр по контуру — замер 0.037…0.154; остальные семейства с ограничением половиной до
## ближайшего соседа — от 0.100, верх 0.363 (octa), 0.411 (fib), 0.457 (rings). Без ограничения
## у неровных — перекрытия до −0.179 (фальсификатор uniform — один размер на все).
const GAP_RANGE := {"icosa": [0.03, 0.16], "octa": [0.09, 0.37], "fib": [0.09, 0.42], "rings": [0.09, 0.47]}
## Шаг ряда размеров: запекатель отсеивает соседей ближе 5% (сессия 2: 32 и 42 почти дубли).
const LADDER_STEP_MIN := 1.049
const GAP_LEVELS := [0, 1, 2, 3, 5, 8]
const RING_RADII := [1, 2, 3, 4]
const STATE_CHECKS := ["стек и прокрутка", "назад на корне", "переход и обрезка"]
const CATALOG_CHECKS := ["состав", "представление"]
const MODEL_CHECKS := ["действия меню адресованы", "короткое и удержание", "трекбол", "настройки", "мастер", "шар действий",
		"действие по умолчанию", "изменения и отмена", "множественный выбор", "сортировка и переходы",
		"опасное без удержания", "стик", "видимость панели", "вращение рукой", "лицом к шлему устойчиво",
		"вращение и мир", "сглаживание руки", "встряхивание", "взмах влево", "правка значения", "демонстрации",
		"корень", "избранное", "плюс", "поиск", "выход", "страницы", "раскладка подписи",
		"имя скриншота", "место под скриншоты", "оба стика", "источник ввода", "сценарий теста"]
## Шаг 1к: руки на синтетических трассах суставов, до шлема.
const HAND_CHECKS := ["поза руки", "кулак и щипок", "задержка отпускания", "касание кончиком", "протяжка",
		"арбитр источника", "настройки по вводу"]
const SHARED_COPIES := ["probe_window.gd", "probe_stats.gd", "probe_report.gd", "probe_budget.gd",
		"probe_hand_features.gd"]

var r: Report = Report.new()
var falsify := ""
var _extra_expected := 0


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--falsify="):
			falsify = a.get_slice("=", 1)
	var expected := _expected()
	r.note("=== ПРОВЕРКИ ПРОТОТИПА ШАР-МЕНЮ ===")
	if falsify != "":
		r.note("!!! ФАЛЬСИФИКАТОР «%s»: ожидается точечный отказ !!!" % falsify)
	r.note("ожидается исполненных проверок: %d" % expected)

	_control()
	_goldberg()
	_layout()
	_state()
	_catalog()
	_copies()
	_extra()
	_model()
	_hands()
	_input_settings_check()
	_profile_checks()
	_projects_check()
	_account_checks()
	_space_checks()
	_move_checks()
	_session_checks()
	_help_text_check()
	_sign_face_check()
	_pull_checks()
	_teleport_extras_check()
	_crouch_vignette_check()
	_mantle_check()
	_ledge_check()
	_collision_guard_check()
	_frame_work_check()
	_turn_first_check()
	_push_out_check()
	_selfcheck_plan_check()
	_floor_area_check()
	_level_join_check()
	_level_real_check()
	_layers_check()
	_visibility_check()
	_play_mode_check()

	var total := r.executed()
	r.note("")
	r.note("passed=%d failed=%d unknown=%d" % [r.passed, r.failed, r.unknown])
	var ok := true
	if total != expected:
		r.note("ОТКАЗ ПРИБОРА: исполнено %d проверок из %d — ошибка оборвала функцию" % [total, expected])
		ok = false
	else:
		r.note("пол: исполнено %d/%d проверок" % [total, expected])
	quit(0 if ok and r.failed == 0 else 1)


func _expected() -> int:
	return 1 \
		+ Goldberg.FAMILIES.size() * GOLDBERG_CHECKS.size() \
		+ 3 \
		+ STATE_CHECKS.size() \
		+ CATALOG_CHECKS.size() \
		+ 1 \
		+ extra_expected() \
		+ MODEL_CHECKS.size() \
		+ HAND_CHECKS.size() \
		+ PROFILE_CHECKS.size() \
		+ ACCOUNT_CHECKS.size() \
		+ SPACE_CHECKS.size() \
		+ MOVE_CHECKS.size() \
		+ SESSION_CHECKS.size()


const SURFACE_CHECKS := ["ячейка под направлением", "шаг вращения", "раздача глобуса",
		"детент", "гистерезис активной", "закрутка линзы", "ориентация контура", "ориентация подписи",
		"размер по контуру", "скрытые дефекты", "поиск ячейки", "перерисовка по делу", "шейдер линзы", "служебные ячейки"]


func extra_expected() -> int:
	return SURFACE_CHECKS.size()


func _extra() -> void:
	_surfaces()


# --- контроль -----------------------------------------------------------------

## Зелёный при любом состоянии выравнивания: уровень 0 — сам икосаэдр, двигать
## нечего, он обязан дать 12 вершин и 12 пятиугольников. Покраснел — сломана
## загрузка сетки или проверочный механизм (§1.5).
func _control() -> void:
	var g = Goldberg.build(0)
	if g.centers.size() == 12 and g.pentagon_count() == 12:
		r.pass_("контроль: икосаэдр, уровень 0 — 12 вершин, 12 пятиугольников")
	else:
		r.fail("контроль: икосаэдр, уровень 0 — %d вершин, %d пятиугольников" % [g.centers.size(), g.pentagon_count()])


# --- сетки ячеек -----------------------------------------------------------------

## Все уровни всех семейств (menu/geo/index.json); по семейству — семь проверок с именем
## худшего уровня. Метрики из файлов не используются: считается по загруженным данным.
func _goldberg() -> void:
	r.note("")
	r.note("--- Сетки ячеек, запечённые ---")
	for fam in Goldberg.FAMILIES:
		var bad := {}
		for k in GOLDBERG_CHECKS:
			bad[k] = []
		var worst_u := [0.0, 1.0, ""]
		var levels := Goldberg.level_count(fam)
		var sizes: Array[float] = []
		for m in levels:
			var g = Goldberg.build(m, fam, falsify == "relax", falsify == "neighbors")
			var n: int = g.centers.size()
			var nm: String = g.name
			# равномерность — до порчи соседства (фальсификатор neighbors точечный)
			var dmin := INF
			var dmax := 0.0
			var elong := 1.0
			for i in n:
				for j in g.neighbors[i]:
					var dd: float = g.centers[i].angle_to(g.centers[j])
					dmin = minf(dmin, dd)
					dmax = maxf(dmax, dd)
				var vmin := INF
				var vmax := 0.0
				for v in g.outlines[i]:
					var va: float = g.centers[i].angle_to(v)
					vmin = minf(vmin, va)
					vmax = maxf(vmax, va)
				elong = maxf(elong, vmax / vmin)
			if dmax / dmin > float(worst_u[0]):
				worst_u = [dmax / dmin, elong, nm]
			if dmax / dmin > float(UNIFORM_MAX[fam][0]) or elong > float(UNIFORM_MAX[fam][1]):
				bad["равномерность"].append("%s %.3f/%.3f" % [nm, dmax / dmin, elong])
			sizes.append(SettingsRes.globe_cell_cm(m, 1.0, fam))
			if falsify == "neighbors" and fam == "icosa" and m == 3:
				# связь заменяется связью с чужой ячейкой: степень и контур те же, ломается симметрия
				var nb: Array = g.neighbors[0]
				for cand in range(n - 1, 0, -1):
					if not nb.has(cand):
						nb[nb.size() - 1] = cand
						break

			# число ячеек — из параметров в имени, независимо от индекса
			var parts := nm.split("_")
			var want := -1
			match fam:
				"icosa", "octa":
					var ga := int(parts[1])
					var gb := int(parts[2])
					want = (10 if fam == "icosa" else 4) * (ga * ga + ga * gb + gb * gb) + 2
				"fib":
					want = int(parts[1])
				"rings":
					want = Goldberg.cells_at(fam, m)
			if n != want or n != Goldberg.cells_at(fam, m):
				bad["число ячеек"].append("%s: %d вместо %d" % [nm, n, want])

			# дефекты: Σ(6 − сторон) = 12 (Эйлер), у икосаэдра — 12 пятиугольников, у октаэдра — 6 квадратов
			var euler := 0
			var hist := {}
			for i in n:
				var dg: int = (g.neighbors[i] as Array).size()
				euler += 6 - dg
				hist[dg] = int(hist.get(dg, 0)) + 1
			var defect_ok := euler == 12
			if fam == "icosa":
				defect_ok = defect_ok and int(hist.get(5, 0)) == 12 and hist.size() <= 2
			elif fam == "octa":
				defect_ok = defect_ok and int(hist.get(4, 0)) == 6 and hist.size() <= 2
			if not defect_ok:
				bad["дефекты"].append("%s: Σ=%d, %s" % [nm, euler, hist])

			# стороны 4…7 — на столько есть меши рендера
			for dg in hist:
				if int(dg) < 4 or int(dg) > 7:
					bad["стороны"].append("%s: %d сторон" % [nm, dg])

			for i in n:
				for j in g.neighbors[i]:
					if not (g.neighbors[j] as Array).has(i):
						bad["симметрия"].append("%s %d→%d" % [nm, i, j])
						break

			# Контур: вершина — центр описанной окружности, значит своя ячейка — среди
			# ближайших к ней центров (равноудалённых). Допуск 1e-5 рад: координаты в файле
			# округлены до 7 знаков.
			for i in n:
				var o: PackedVector3Array = g.outlines[i]
				if o.size() != (g.neighbors[i] as Array).size():
					bad["контуры"].append("%s %d: вершин %d, соседей %d" % [nm, i, o.size(), (g.neighbors[i] as Array).size()])
					break
				var off := false
				for p in o:
					var own: float = p.angle_to(g.centers[i])
					var best := own
					for j in g.neighbors[i]:
						best = minf(best, p.angle_to(g.centers[j]))
					if own - best > 1e-5:
						off = true
				if off:
					bad["контуры"].append("%s %d: вершина ближе к чужой ячейке" % [nm, i])
					break

		for k in range(1, sizes.size()):
			if sizes[k - 1] / sizes[k] < LADDER_STEP_MIN:
				bad["ряд размеров"].append("%d→%d: %.3f" % [k - 1, k, sizes[k - 1] / sizes[k]])

		var detail := {
			"число ячеек": "%d уровней, %d…%d ячеек" % [levels, Goldberg.cells_at(fam, 0), Goldberg.cells_at(fam, levels - 1)],
			"дефекты": "Σ(6 − сторон) = 12 на всех уровнях",
			"стороны": "4…7 сторон",
			"симметрия": "соседство симметрично",
			"контуры": "вершины контуров равноудалены от своих ячеек",
			"равномерность": "худший %s: соседи %.3f ≤ %.2f, вытянутость %.3f ≤ %.2f" % [worst_u[2], worst_u[0], UNIFORM_MAX[fam][0], worst_u[1], UNIFORM_MAX[fam][1]],
			"ряд размеров": "от крупных к мелким, шаг ≥ %.3f" % LADDER_STEP_MIN,
		}
		for k in GOLDBERG_CHECKS:
			if (bad[k] as Array).is_empty():
				r.pass_("%s %s: %s" % [fam, k, detail[k]])
			else:
				r.fail("%s %s: %s" % [fam, k, "; ".join((bad[k] as Array).slice(0, 6))])


# --- раскладка ----------------------------------------------------------------

func _layout() -> void:
	r.note("")
	r.note("--- Раскладка ---")
	var bad: Array[String] = []
	for k in RING_RADII:
		var ring: Array[Vector2i] = Layout.ring(k)
		if ring.size() != 6 * k:
			bad.append("k=%d: %d ячеек" % [k, ring.size()])
		for c in ring:
			if Layout.distance(c, Vector2i.ZERO) != k:
				bad.append("k=%d: %s на расстоянии %d" % [k, c, Layout.distance(c, Vector2i.ZERO)])
				break
	if bad.is_empty():
		r.pass_("кольца радиусов %s: 6k ячеек, все на расстоянии k" % str(RING_RADII))
	else:
		r.fail("кольца: %s" % "; ".join(bad))

	var sp: Array[Vector2i] = Layout.spiral(60)
	var issues: Array[String] = []
	var seen := {}
	var last := 0
	for c in sp:
		if c == Layout.BACK_CELL:
			issues.append("спираль заняла «назад»")
		if seen.has(c):
			issues.append("повтор %s" % c)
		seen[c] = true
		var d := Layout.distance(c, Vector2i.ZERO)
		if d < last:
			issues.append("расстояние убыло на %s" % c)
		last = d
	if sp.size() == 60 and issues.is_empty() and sp[0] == Vector2i.ZERO \
			and Layout.distance(Layout.BACK_CELL, Vector2i.ZERO) == 1:
		r.pass_("спираль 60: центр первым, расстояние не убывает, без повторов, «назад» — сосед центра и свободна")
	else:
		r.fail("спираль 60 (%d ячеек): %s" % [sp.size(), "; ".join(issues)])

	var round_bad: Array[String] = []
	for c in Layout.spiral(200):
		var back := Layout.from_plane(Layout.to_plane(c))
		if back != c:
			round_bad.append("%s→%s" % [c, back])
		# точка в 0.4 радиуса от центра остаётся в своей ячейке
		var jitter := Layout.from_plane(Layout.to_plane(c) + Vector2(0.4, -0.3))
		if jitter != c:
			round_bad.append("%s+шум→%s" % [c, jitter])
	if round_bad.is_empty():
		r.pass_("плоскость: центр и точка рядом возвращаются в свою ячейку для 200 ячеек")
	else:
		r.fail("плоскость: %s" % ", ".join(round_bad.slice(0, 8)))


# --- состояние ----------------------------------------------------------------

func _state() -> void:
	r.note("")
	r.note("--- Состояние ---")
	var s: State = State.new()
	s.toggle()
	var in1: Variant = s.enter("f1", "корень")
	var in2: Variant = s.enter("f2", "f1")
	var b1 := s.back("f2")
	var b2 := s.back("f1-2")
	var again: Variant = s.enter("f1", "корень-2")
	if in1 == null and in2 == null and b1["scroll"] == "f1" and b2["scroll"] == "корень" and again == "f1-2":
		r.pass_("стек: вход, выход и повторный вход возвращают прокрутку каждой папки")
	else:
		r.fail("стек: %s %s %s %s %s" % [in1, in2, b1, b2, again])

	s.back(null)
	var root := s.back(null)
	if root["closed"] and s.mode == State.Mode.CLOSED:
		r.pass_("«назад» на корне закрывает меню")
	else:
		r.fail("«назад» на корне: %s, режим %d" % [root, s.mode])

	var t: State = State.new()
	t.enter("a", "r0")
	t.enter("b", "a0")
	t.enter("c", "b0")
	var j: Variant = t.jump(1, "c0")
	var after_jump := t.folder()
	t.enter("gone", "a1")
	t.prune(func(f): return f != "gone")
	if after_jump == "a" and j == "a0" and t.folder() == "a":
		r.pass_("переход на уровень и обрезка исчезнувшей папки")
	else:
		r.fail("переход: папка %s прокрутка %s, после обрезки %s" % [after_jump, j, t.folder()])


# --- каталог ------------------------------------------------------------------

func _catalog() -> void:
	r.note("")
	r.note("--- Каталог ---")
	var c: Catalog = Catalog.new()
	var home_ids: Array = c.home_view().map(func(x): return x.id)
	var files_only_folders: bool = c.children("files", 0, 100).all(func(x): return x.kind == Item.Kind.FOLDER)
	var kinds := {}
	var images_ok := true
	var ids := c.all_ids()
	for id in ids:
		var it: Item = c.items[id]
		kinds[it.kind] = true
		if it.kind == Item.Kind.IMAGE and not ResourceLoader.exists(it.preview):
			images_ok = false
	var need := [Item.Kind.FOLDER, Item.Kind.SCENE, Item.Kind.IMAGE, Item.Kind.ASSET, Item.Kind.FILE, Item.Kind.OPTION, Item.Kind.TOGGLE]
	var missing := need.filter(func(k): return not kinds.has(k))
	var home_want := ["files", "settings", "home_search", "set_tasks", "home_plus", "home_exit"]
	if home_ids == home_want and files_only_folders and missing.is_empty() and images_ok and ids.size() >= 50:
		r.pass_("каталог: %d пунктов, корень — Файлы, Настройки, Поиск, Запуск теста, «+», Выход; в Файлах только папки; все виды объектов, изображения загружаются" % ids.size())
	else:
		r.fail("каталог: корень %s, в Файлах только папки %s, нет видов %s, изображения %s, пунктов %d" % [home_ids, files_only_folders, missing, images_ok, ids.size()])

	var by_name := c.view("images", "name", -1, []).map(func(x): return x.title)
	var sorted_names := by_name.duplicate()
	sorted_names.sort_custom(func(x, y): return x.to_lower() < y.to_lower())
	var by_date := c.view("scenes", "date", -1, []).filter(func(x): return x.kind != Item.Kind.FOLDER).map(func(x): return x.modified)
	var dates_desc := true
	for i in range(1, by_date.size()):
		if by_date[i] > by_date[i - 1]:
			dates_desc = false
	var only_scenes := c.view("scenes", "name", Item.Kind.SCENE, []).all(func(x): return x.kind in [Item.Kind.SCENE, Item.Kind.FOLDER])
	var recent_first: Array = c.view("images", "name", -1, ["img_sky", "img_map"])
	if by_name == sorted_names and dates_desc and only_scenes and recent_first[0].id == "img_sky" and recent_first[1].id == "img_map":
		r.pass_("представление: по имени, по дате (новые первыми), фильтр по виду, недавние первым кольцом")
	else:
		r.fail("представление: имя %s, даты %s, фильтр %s, недавние %s" % [by_name == sorted_names, by_date, only_scenes, recent_first.slice(0, 2).map(func(x): return x.id)])


# --- копии общего кода ----------------------------------------------------------

func _copies() -> void:
	r.note("")
	var probe_dir := ProjectSettings.globalize_path("res://").path_join("../probe")
	var bad: Array[String] = []
	for f in SHARED_COPIES:
		var a := FileAccess.get_file_as_bytes("res://" + f)
		var b := FileAccess.get_file_as_bytes(probe_dir.path_join(f))
		if b.is_empty():
			bad.append("%s: нет в projects/probe" % f)
		elif a != b:
			bad.append("%s: расходится с projects/probe" % f)
	if bad.is_empty():
		r.pass_("копии общего кода совпадают с projects/probe: %s" % ", ".join(SHARED_COPIES))
	else:
		r.fail("копии общего кода: %s" % "; ".join(bad))


# --- поверхности ----------------------------------------------------------------

func _surfaces() -> void:
	r.note("")
	r.note("--- Поверхности ---")
	var step_mult := 2.0 if falsify == "shift" else 1.0

	# 1. Ячейка под направлением своего центра — она сама, у обеих поверхностей,
	# при произвольном повороте глобуса и сдвиге с закруткой линзы.
	var bad: Array[String] = []
	for m in FREQS:
		var gl = Globe.new(m)
		gl.apply_rotation(Quaternion(Vector3(0.3, 1.0, 0.2).normalized(), 0.7))
		for i in gl.g.centers.size():
			if gl.cell_at_direction(gl.direction_of(i)) != i:
				bad.append("глобус m=%d ячейка %d" % [m, i])
				break
	var ln = Lens.new(0.22)
	ln.offset = Vector2(0.3, -0.2)
	ln.twist = 0.4
	var lens_cells := 0
	for c in Layout.spiral(60):
		var cell: Vector2i = Vector2i(c) + Layout.from_plane(ln.offset)
		if ln.direction_of(cell).angle_to(ln.front) > ln.max_theta:
			continue
		lens_cells += 1
		if ln.cell_at_direction(ln.direction_of(cell)) != cell:
			bad.append("линза %s→%s" % [cell, ln.cell_at_direction(ln.direction_of(cell))])
	if bad.is_empty():
		r.pass_("ячейка под направлением своего центра — она сама: глобус m=%s после поворота, линза %d ячеек со сдвигом и закруткой" % [str(FREQS), lens_cells])
	else:
		r.fail("ячейка под направлением: %s" % ", ".join(bad.slice(0, 8)))

	# 2. Шаг вращения: поворот на угол до соседа делает соседа активным.
	var step_bad: Array[String] = []
	var gl3 = Globe.new(3)
	gl3.apply_rotation(gl3.snap_rotation())
	var a: int = gl3.cell_at_direction(gl3.front)
	for nb in gl3.g.neighbors[a]:
		var probe = Globe.new(3)
		probe.orientation = gl3.orientation
		var q := Quaternion(probe.direction_of(nb), probe.front)
		probe.apply_rotation(Quaternion(q.get_axis(), q.get_angle() * step_mult) if q.get_angle() > 1e-6 else q)
		if probe.cell_at_direction(probe.front) != nb:
			step_bad.append("глобус %d→%d, стал %d" % [a, nb, probe.cell_at_direction(probe.front)])
	for d in Layout.DIRS:
		var l2 = Lens.new(0.22)
		var dir: Vector3 = l2.direction_of(d)
		var q2 := Quaternion(dir, l2.front)
		l2.apply_rotation(Quaternion(q2.get_axis(), q2.get_angle() * step_mult))
		if l2.cell_at_direction(l2.front) != d:
			step_bad.append("линза →%s, стала %s" % [d, l2.cell_at_direction(l2.front)])
	if step_bad.is_empty():
		r.pass_("шаг вращения: поворот на угол до соседа делает активным ровно соседа — глобус все %d соседей, линза все 6 направлений" % (gl3.g.neighbors[a] as Array).size())
	else:
		r.fail("шаг вращения: %s" % ", ".join(step_bad))

	# 3. Раздача глобуса: первый пункт — активная, «назад» — её сосед, пункты по
	# неубыванию расстояния в графе, каждый ровно один раз.
	var gl4 = Globe.new(3)
	gl4.assign(40)
	var act: int = gl4.cell_at_direction(gl4.front)
	var slot_cell := {}
	var backs: Array[int] = []
	for i in gl4.g.centers.size():
		var sl: int = gl4.slot_of(i)
		if sl == Surface.SLOT_BACK:
			backs.append(i)
		elif sl >= 0:
			slot_cell[sl] = i
	# Эталон расстояний — граф БЕЗ «назад»: пункты обходят её по спецификации.
	# Первая версия проверки мерила по полному графу и краснела на ячейках за
	# «назад», чьё расстояние в обходе на единицу больше.
	var dist := {act: 0}
	if not backs.is_empty():
		dist[backs[0]] = -1
	var queue: Array = [act]
	while not queue.is_empty():
		var c2: int = queue.pop_front()
		for j in gl4.g.neighbors[c2]:
			if not dist.has(j):
				dist[j] = dist[c2] + 1
				queue.append(j)
	var order_ok := true
	for sl in range(1, 40):
		if not slot_cell.has(sl) or dist[slot_cell[sl]] < dist[slot_cell[sl - 1]]:
			order_ok = false
	var lens_assign = Lens.new(0.22)
	lens_assign.assign(10)
	if gl4.slot_of(act) == 0 and backs.size() == 1 and (gl4.g.neighbors[act] as Array).has(backs[0]) \
			and slot_cell.size() == 40 and order_ok \
			and lens_assign.slot_of(Vector2i.ZERO) == 0 and lens_assign.slot_of(Layout.BACK_CELL) == Surface.SLOT_BACK:
		r.pass_("раздача: первый пункт в активной, одна «назад» у соседа, 40 пунктов по неубыванию расстояния в графе; линза — так же")
	else:
		r.fail("раздача: активная слот %d, «назад» %s, пунктов %d, порядок %s" % [gl4.slot_of(act), backs, slot_cell.size(), order_ok])

	# 4. Детент: пружина доводит центр активной до переда без перелёта — активная
	# за доводку не меняется, остаток монотонно убывает.
	var det_bad: Array[String] = []
	for kind in ["глобус", "линза"]:
		var sf = Globe.new(3) if kind == "глобус" else Lens.new(0.22)
		if kind == "глобус":
			sf.apply_rotation(sf.snap_rotation())
			sf.apply_rotation(Quaternion(Vector3.UP, sf.cell_angle() * 0.6))
		else:
			sf.offset = Vector2(0.35, 0.25)
		var start: Variant = sf.cell_at_direction(sf.front)
		var sp = Spring.new()
		sp.value = sf.snap_error()
		var prev: float = sf.snap_error()
		var frames := 0
		for _f in 90:
			frames += 1
			var err: float = sf.snap_error()
			if err < 1e-4:
				break
			var next: float = sp.step(0.0, 1.0 / 90.0)
			var part := clampf((err - next) / err, 0.0, 1.0)
			sf.apply_rotation(Quaternion.IDENTITY.slerp(sf.snap_rotation(), part))
			var now_err: float = sf.snap_error()
			if now_err > prev + 1e-5:
				det_bad.append("%s: остаток вырос %.4f→%.4f" % [kind, prev, now_err])
				break
			if sf.cell_at_direction(sf.front) != start:
				det_bad.append("%s: активная сменилась при доводке" % kind)
				break
			prev = now_err
		if sf.snap_error() > 1e-3:
			det_bad.append("%s: за %d кадров остаток %.4f рад" % [kind, frames, sf.snap_error()])
	if det_bad.is_empty():
		r.pass_("детент: глобус и линза доводятся к центру ячейки за ≤90 кадров без перелёта и смены активной")
	else:
		r.fail("детент: %s" % "; ".join(det_bad))

	# 5. Гистерезис: у границы двух ячеек активная не мигает, дальше запаса — меняется.
	var lh = Lens.new(0.22)
	var ac = Active.new()
	var boundary: float = Layout.to_plane(Vector2i(1, 0)).x * 0.5
	lh.offset = Vector2(boundary - 0.2, 0.0)
	ac.update(lh, 0)
	var first: Variant = ac.key
	lh.offset = Vector2(boundary + 0.03, 0.0)
	var flip_small := ac.update(lh, 16)
	lh.offset = Vector2(boundary - 0.03, 0.0)
	ac.update(lh, 32)
	lh.offset = Vector2(boundary + 0.2, 0.0)
	var flip_big := ac.update(lh, 48)
	var past: Variant = ac.key_at(48 + 0, 40)
	if first == Vector2i.ZERO and not flip_small and flip_big and ac.key == Vector2i(1, 0) and past == Vector2i.ZERO:
		r.pass_("гистерезис: дрожь ±0.03 у границы не меняет активную, сдвиг +0.2 меняет; буфер помнит прежнюю")
	else:
		r.fail("гистерезис: первая %s, мелкий сдвиг сменил=%s, крупный=%s, итог %s, 40 мс назад %s" % [first, flip_small, flip_big, ac.key, past])

	# 6. Закрутка линзы: поворот вокруг переда вращает содержимое вместе с шаром.
	var lt = Lens.new(0.22)
	var qt := Quaternion(lt.front, deg_to_rad(60.0))
	var twist_bad: Array[String] = []
	var before := {}
	for c3 in Layout.spiral(19):
		before[c3] = lt.direction_of(c3)
	lt.apply_rotation(qt)
	for c3 in before:
		var want_dir: Vector3 = qt * before[c3]
		if lt.cell_at_direction(want_dir) != c3:
			twist_bad.append("%s→%s" % [c3, lt.cell_at_direction(want_dir)])
	if twist_bad.is_empty():
		r.pass_("закрутка линзы: поворот на 60° вокруг переда уносит 19 ячеек ровно туда, куда повернулся шар")
	else:
		r.fail("закрутка линзы: %s" % ", ".join(twist_bad.slice(0, 8)))

	# 7. Ориентация контура для рендера: шестиугольник рисуется с вершиной, повёрнутой
	# на spin от касательной оси. Вершина, построенная по spin, обязана смотреть на
	# настоящую вершину ячейки: у глобуса — первую точку контура, у линзы — проекцию
	# вершины решётки. Ошибка знака закрутки (найдена при разборе рендера) краснеет здесь.
	var or_bad: Array[String] = []
	var go = Globe.new(3)
	go.apply_rotation(Quaternion(Vector3(1, 0.4, 0).normalized(), 0.9))
	for cell_d in go.visible_cells():
		var i: int = cell_d["key"]
		var n: Vector3 = cell_d["dir"]
		var drawn := _drawn_vertex(n, cell_d["spin"])
		var real_v: Vector3 = (go.orientation * go.g.outlines[i][0])
		var real_t := (real_v - n * real_v.dot(n)).normalized()
		if drawn.angle_to(real_t) > 0.05:
			or_bad.append("глобус %d: %.2f рад" % [i, drawn.angle_to(real_t)])
			break
	var lo = Lens.new(0.22)
	lo.offset = Vector2(0.4, 0.1)
	lo.twist = 0.5
	for cell_d in lo.visible_cells():
		var n2: Vector3 = cell_d["dir"]
		if n2.angle_to(lo.front) > PI * 0.5:
			continue
		var drawn2 := _drawn_vertex(n2, cell_d["spin"])
		var up_v: Vector3 = lo._plane_to_dir(Layout.to_plane(cell_d["key"]) + Vector2(0.0, 0.3))["dir"]
		var real2 := (up_v - n2 * up_v.dot(n2)).normalized()
		# у шестиугольника вершины через 60°: совпасть обязана любая из шести
		var best := INF
		for k in 6:
			best = minf(best, drawn2.rotated(n2, k * PI / 3.0).angle_to(real2))
		if best > 0.05:
			or_bad.append("линза %s: %.2f рад" % [cell_d["key"], best])
			break
	if or_bad.is_empty():
		r.pass_("ориентация контура: вершина по spin совпадает с вершиной ячейки — глобус 92 ячейки, линза передняя полусфера со сдвигом и закруткой")
	else:
		r.fail("ориентация контура: %s" % ", ".join(or_bad))


	# 8. Ориентация подписи: зритель снаружи шара, глядя на ячейку вдоль −n с «верхом»
	# мира, видит текст прямо — «вправо» текстуры смотрит вправо экрана, «вверх» —
	# вверх. СЛАБАЯ проверка: шейдер на десктопе не исполняется, и здесь повторена его
	# формула (menu/cell.gdshader, fragment). Ловит ошибку вывода, не ошибку переноса
	# в шейдер. Найденный на шлеме дефект (подписи отражены) краснеет здесь.
	var tex_bad: Array[String] = []
	var gt = Globe.new(3)
	gt.apply_rotation(Quaternion(Vector3(0.2, 1.0, 0.3).normalized(), 1.1))
	for cell_d in gt.visible_cells():
		var n3: Vector3 = cell_d["dir"]
		if absf(n3.y) > 0.8:
			continue    # у полюсов «верх» мира вырождается, подпись там любая
		var a3 := Vector3.UP if absf(n3.y) < 0.9 else Vector3.RIGHT
		var ref3 := (a3 - n3 * a3.dot(n3)).normalized()
		var z3 := ref3.rotated(n3, float(cell_d["spin"]))
		var x3 := n3.cross(z3)
		# vertex(): «верх» мира в осях ячейки (масштаб на угол не влияет)
		var ang := atan2(Vector3.UP.dot(x3), Vector3.UP.dot(z3))
		# fragment(): uv = (0.5 − q.x·k, 0.5 − q.y·k); направление в осях ячейки,
		# куда растёт u (вправо текстуры) и убывает v (вверх текстуры)
		# фальсификатор mirror — формула первой версии шейдера (uv.x = 0.5 + q.x·k),
		# давшая на шлеме отражённые подписи
		var right_q := Vector2(1, 0) if falsify == "mirror" else Vector2(-1, 0)
		var tex_right := _local_dir_for_q(right_q, ang, x3, z3)
		var tex_up := _local_dir_for_q(Vector2(0, 1), ang, x3, z3)
		var up_t := (Vector3.UP - n3 * Vector3.UP.dot(n3)).normalized()
		var screen_right := up_t.cross(n3).normalized()
		if tex_right.angle_to(screen_right) > 0.05 or tex_up.angle_to(up_t) > 0.05:
			tex_bad.append("ячейка %d: вправо %.2f рад, вверх %.2f рад" % [cell_d["key"], tex_right.angle_to(screen_right), tex_up.angle_to(up_t)])
			break
	if tex_bad.is_empty():
		r.pass_("ориентация подписи (формула шейдера повторена, слабая проверка): вправо и вверх текстуры совпадают с экраном зрителя снаружи")
	else:
		r.fail("ориентация подписи: %s" % ", ".join(tex_bad))

	# 9. Размер по контуру: соседние ячейки в том размере, в каком их ставит рендер
	# (cell_renderer.gd: опорный радиус × scale × GAP), не перекрываются и не расходятся
	# дальше замеренного. Вписанный радиус — вдоль ребра к соседу. Все уровни всех семейств.
	var gap_bad: Array[String] = []
	var gap_seen := PackedStringArray()
	const Renderer := preload("res://menu/cell_renderer.gd")
	for fam in Goldberg.FAMILIES:
		var flo := INF
		var fhi := 0.0
		for lvl in Goldberg.level_count(fam):
			var gg = Globe.new(lvl, fam)
			var gcells: Array = gg.visible_cells()
			var gref: float = gg.g.cell_angle() * 2.0 / sqrt(3.0)
			var inr := PackedFloat32Array()
			for cd in gcells:
				var gsc: float = 1.0 if falsify == "uniform" else float(cd["scale"])
				inr.append(gref * gsc * Renderer.GAP * cos(PI / float(cd["sides"])))
			for i in gcells.size():
				for j in gg.g.neighbors[i]:
					var cdist: float = gg.g.centers[i].angle_to(gg.g.centers[j])
					var gp: float = (cdist - inr[i] - inr[j]) / cdist
					flo = minf(flo, gp)
					fhi = maxf(fhi, gp)
		gap_seen.append("%s %.3f…%.3f" % [fam, flo, fhi])
		if flo < float(GAP_RANGE[fam][0]) or fhi > float(GAP_RANGE[fam][1]):
			gap_bad.append("%s: %.3f…%.3f вне %.2f…%.2f" % [fam, flo, fhi, GAP_RANGE[fam][0], GAP_RANGE[fam][1]])
	if gap_bad.is_empty():
		r.pass_("размер по контуру: все уровни — %s" % ", ".join(gap_seen))
	else:
		r.fail("размер по контуру: %s" % "; ".join(gap_bad))

	# 10. Поиск ячейки под направлением: спуск по соседям обязан давать то же, что полный
	# перебор, у всех семейств — и с холодной подсказки, и при движении маленькими шагами.
	# Спуск вместо перебора: 80 → 1.5 мкс на вызов (замер 2026-09-16), а зовётся он до трёх
	# раз в кадре (доводка и активная).
	var find_bad: Array[String] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for fam in Goldberg.FAMILIES:
		var lvl: int = Goldberg.level_count(fam) - 1
		var gf = Globe.new(lvl, fam)
		gf.falsify_one_step = falsify == "descend"
		gf.apply_rotation(Quaternion(Vector3(0.3, 1.0, 0.2).normalized(), 0.7))
		var dir := Vector3(0, 0, 1)
		for k in 200:
			if k % 2 == 0:
				dir = Vector3(rng.randfn(), rng.randfn(), rng.randfn()).normalized()
			else:
				dir = (dir + Vector3(0.02, 0.01, 0.0)).normalized()
			var got: int = gf.cell_at_direction(dir)
			var local: Vector3 = gf.orientation.inverse() * dir
			var want := 0
			var bd := -INF
			for i in gf.g.centers.size():
				var dd: float = gf.g.centers[i].dot(local)
				if dd > bd:
					bd = dd
					want = i
			if got != want:
				find_bad.append("%s: %d вместо %d" % [fam, got, want])
				break
	if find_bad.is_empty():
		r.pass_("поиск ячейки: спуск по соседям совпал с полным перебором — 200 направлений на каждом из %d семейств (худший уровень)" % Goldberg.FAMILIES.size())
	else:
		r.fail("поиск ячейки: %s" % "; ".join(find_bad))

	# 11. Скрытые дефекты: ни один пункт не на пятиугольнике; пятиугольник напротив лица —
	# активной и целью доводки становится шестиугольник.
	var hx = Globe.new(3, "icosa", falsify != "hexhide")
	hx.assign(70)
	var on_defect := 0
	for i in hx.g.centers.size():
		if hx.g.is_defect(i) and hx.slot_of(i) >= 0:
			on_defect += 1
	var hpent := -1
	for i in hx.g.centers.size():
		if hx.g.is_defect(i):
			hpent = i
			break
	hx.apply_rotation(Quaternion(hx.direction_of(hpent), hx.front))
	var hact: int = hx.active_at(hx.front)
	if on_defect == 0 and not hx.g.is_defect(hact) and hx.snap_error() > 1e-3:
		r.pass_("скрытые дефекты: 70 пунктов мимо 12 пятиугольников; пятиугольник напротив лица — активная и доводка на шестиугольнике (%.3f рад)" % hx.snap_error())
	else:
		r.fail("скрытые дефекты: пунктов на пятиугольниках %d, активная дефект %s, остаток доводки %.4f" % [on_defect, hx.g.is_defect(hact), hx.snap_error()])

	# 12. Перерисовка по делу: поворот не требует пересчёта ячеек — у глобуса вообще, у линзы
	# внутри ячейки; смена центральной ячейки линзы и новая раздача — требуют. Механизм, на
	# котором держится пропуск перерисовки самопроверки (§3.10).
	var rd_bad: Array[String] = []
	var rg = Globe.new(3)
	rg.assign(40)
	var rgv: int = rg.render_version()
	rg.apply_rotation(Quaternion(Vector3(0.3, 1.0, 0.2).normalized(), 0.7))
	if rg.render_version() != rgv:
		rd_bad.append("глобус: поворот сменил версию")
	var rl = Lens.new(0.22)
	rl.falsify_version_on_rotate = falsify == "redraw"
	rl.assign(40)
	var rlv: int = rl.render_version()
	# поворот на треть ячейки вокруг «верха»: центр остаётся прежним
	rl.apply_rotation(Quaternion(rl.up, rl.cell_angle() * 0.3))
	if rl.render_center() != Vector2i.ZERO or rl.render_version() != rlv:
		rd_bad.append("линза: поворот внутри ячейки (центр %s) сменил версию" % rl.render_center())
	rl.apply_rotation(Quaternion(rl.up, rl.cell_angle() * 1.5))
	if rl.render_center() == Vector2i.ZERO or rl.render_version() == rlv:
		rd_bad.append("линза: смена центра (%s) не сменила версию" % rl.render_center())
	var rlv2: int = rl.render_version()
	rl.assign(41)
	if rl.render_version() == rlv2:
		rd_bad.append("линза: новая раздача не сменила версию")
	if rd_bad.is_empty():
		r.pass_("перерисовка по делу: поворот глобуса и поворот линзы внутри ячейки версию рендера не меняют; смена центра линзы и раздача — меняют")
	else:
		r.fail("перерисовка по делу: %s" % "; ".join(rd_bad))

	# 13. Шейдер линзы: номер экземпляра даёт ячейку в порядке Layout.ring, а близнец
	# вершинного шейдера (surface_lens.shader_twin — те же шаги, что lens_mode в cell.gdshader)
	# ставит каждую видимую ячейку туда же, куда visible_cells: направление, сжатие и ось на
	# вершину. Сдвиг и закрутка произвольные. СЛАБАЯ в части GLSL: шейдер headless не
	# исполняется, проверяется близнец; перенос в GLSL видят глаза на шлеме.
	var sh_bad: Array[String] = []
	var ring_order: Array[Vector2i] = []
	for k in 16:
		ring_order.append_array(Layout.ring(k))
	for i in ring_order.size():
		if Lens.ring_cell(i) != ring_order[i]:
			sh_bad.append("ring_cell(%d) = %s вместо %s" % [i, Lens.ring_cell(i), ring_order[i]])
			break
	var ls = Lens.new(0.12)
	ls.falsify_twin_twist = falsify == "lenstwin"
	ls.assign(60)
	ls.apply_rotation(Quaternion(Vector3(0.4, 1.0, 0.1).normalized(), 2.3))
	ls.apply_rotation(Quaternion(ls.front, 0.8))
	var want := {}
	for cd in ls.visible_cells():
		want[cd["key"]] = cd
	var u: Dictionary = ls.render_uniforms()
	var n_cells: int = ls.render_count(700)
	var matched := 0
	for i in n_cells:
		var key: Vector2i = ls.render_center() + Lens.ring_cell(i)
		var tw: Dictionary = ls.shader_twin(i, u)
		var visible: bool = float(tw["theta"]) <= ls.max_theta
		if visible != want.has(key):
			sh_bad.append("%s: видимость близнеца %s, visible_cells %s" % [key, visible, want.has(key)])
			break
		if not visible:
			continue
		var cd: Dictionary = want[key]
		var z_ref := _drawn_vertex(cd["dir"], cd["spin"])
		if (tw["dir"] as Vector3).angle_to(cd["dir"]) > 1e-3 or absf(float(tw["scale"]) - float(cd["scale"])) > 1e-3 \
				or (tw["z"] as Vector3).angle_to(z_ref) > 1e-3:
			sh_bad.append("%s: направление %.4f рад, сжатие %.4f/%.4f, ось %.4f рад" % [key, (tw["dir"] as Vector3).angle_to(cd["dir"]),
					tw["scale"], cd["scale"], (tw["z"] as Vector3).angle_to(z_ref)])
			break
		matched += 1
	# 14. Служебные ячейки страниц: «Дальше» — сосед справа от активной, «Раньше» — рядом с
	# ним и выше, пунктов на них нет. Глобус и линза.
	var sv_bad: Array[String] = []
	var sg = Globe.new(3)
	sg.falsify_next_left = falsify == "nextleft"
	sg.assign(40, true, true, true)
	var start_i: int = sg.active_at(sg.front)
	var g_right: Vector3 = sg.up.cross(sg.front).normalized()
	var keys := {}
	var placed_n := 0
	for i in sg.g.centers.size():
		var sl: int = sg.slot_of(i)
		if sl < 0:
			keys[sl] = i
		else:
			placed_n += 1
	if not (keys.has(Surface.SLOT_NEXT) and keys.has(Surface.SLOT_PREV) and keys.has(Surface.SLOT_BACK)):
		sv_bad.append("глобус: служебные %s" % keys)
	else:
		var d0: Vector3 = sg.direction_of(start_i)
		var dn: Vector3 = sg.direction_of(keys[Surface.SLOT_NEXT])
		var dp: Vector3 = sg.direction_of(keys[Surface.SLOT_PREV])
		if (dn - d0).normalized().dot(g_right) < 0.7:
			sv_bad.append("глобус: «Дальше» не справа (%.2f)" % (dn - d0).normalized().dot(g_right))
		if (dp - dn).dot(sg.up) <= 0.0 or not (sg.g.neighbors[keys[Surface.SLOT_NEXT]] as Array).has(keys[Surface.SLOT_PREV]):
			sv_bad.append("глобус: «Раньше» не рядом с «Дальше» сверху")
	if placed_n != 40:
		sv_bad.append("глобус: пунктов %d из 40" % placed_n)
	var sl2 = Lens.new(0.22)
	sl2.assign(40, true, true, true)
	var l_right: Vector3 = sl2.up.cross(sl2.front).normalized()
	var ln_dir: Vector3 = sl2.direction_of(Layout.NEXT_CELL)
	var lp_dir: Vector3 = sl2.direction_of(Layout.PREV_CELL)
	if sl2.slot_of(Layout.NEXT_CELL) != Surface.SLOT_NEXT or sl2.slot_of(Layout.PREV_CELL) != Surface.SLOT_PREV:
		sv_bad.append("линза: служебные слоты %d/%d" % [sl2.slot_of(Layout.NEXT_CELL), sl2.slot_of(Layout.PREV_CELL)])
	if (ln_dir - sl2.front).normalized().dot(l_right) < 0.7 or (lp_dir - ln_dir).dot(sl2.up) <= 0.0:
		sv_bad.append("линза: «Дальше» справа %.2f, «Раньше» выше %.3f" % [(ln_dir - sl2.front).normalized().dot(l_right), (lp_dir - ln_dir).dot(sl2.up)])
	var sl3 = Lens.new(0.22)
	sl3.assign(40)
	if sl3.slot_of(Layout.NEXT_CELL) < 0:
		sv_bad.append("линза без страниц: ячейка справа пустая")
	if sv_bad.is_empty():
		r.pass_("служебные ячейки: «Дальше» справа от активной, «Раньше» рядом сверху, пункты мимо — глобус и линза; без страниц справа пункт")
	else:
		r.fail("служебные ячейки: %s" % "; ".join(sv_bad))

	if sh_bad.is_empty() and matched == want.size() and n_cells >= want.size():
		r.pass_("шейдер линзы (близнец, слабая в части GLSL): порядок колец %d ячеек; %d видимых ячеек из %d экземпляров совпали с visible_cells при сдвиге и закрутке" % [ring_order.size(), matched, n_cells])
	else:
		r.fail("шейдер линзы: %s (совпало %d из %d видимых, экземпляров %d)" % ["; ".join(sh_bad), matched, want.size(), n_cells])


static func _drawn_vertex(n: Vector3, spin: float) -> Vector3:
	var a := Vector3.UP if absf(n.y) < 0.9 else Vector3.RIGHT
	var ref := (a - n * a.dot(n)).normalized()
	return ref.rotated(n, spin)


## Направление в пространстве, где q (повёрнутые координаты шейдера) равно заданному.
## q = R(a)·p, p = (x, z) в осях ячейки; обратный поворот — R(−a).
static func _local_dir_for_q(q: Vector2, a: float, x: Vector3, z: Vector3) -> Vector3:
	var px := q.x * cos(a) + q.y * sin(a)
	var pz := -q.x * sin(a) + q.y * cos(a)
	return (x * px + z * pz).normalized()


# --- модель файлового менеджера -----------------------------------------------------

func _model() -> void:
	_menu_actions_check()
	r.note("")
	r.note("--- Модель ---")

	# 1. Короткое и удержание: одно нажатие — одно событие.
	var pr = Press.new()
	pr.hold_ms = 0 if falsify == "press" else 500
	var ev := []
	ev.append(pr.update(true, 0))
	ev.append(pr.update(false, 200))
	var hold_ev := []
	for t in [1000, 1300, 1600, 1900]:
		hold_ev.append(pr.update(true, t))
	hold_ev.append(pr.update(false, 2000))
	pr.arm_confirm()
	var c_early := [pr.update(true, 3000), pr.update(false, 3200)]
	var c_full := [pr.update(true, 4000), pr.update(true, 4700), pr.update(false, 4800)]
	if ev == ["", "short"] and hold_ev == ["", "", "hold", "", ""] and c_early == ["", "cancel"] and c_full == ["", "confirm", ""]:
		r.pass_("короткое и удержание: короткое на отпускании, удержание ровно раз на пороге, подтверждение отпущенное раньше — отмена")
	else:
		r.fail("короткое и удержание: %s %s %s %s" % [ev, hold_ev, c_early, c_full])

	# 2. Трекбол: точка под кончиком следует за контроллером; инерция затухает.
	var gb = Grab.new()
	var ball := Quaternion.IDENTITY
	var d0 := Vector3(0.2, 0.1, 1).normalized()
	var grabbed_local := d0
	gb.begin(d0)
	var follow_bad := 0.0
	var path := [Vector3(0.4, 0.1, 0.9), Vector3(0.6, 0.3, 0.7), Vector3(0.7, 0.5, 0.5)]
	for p in path:
		var q: Quaternion = gb.update(p, 1.0 / 90.0)
		if falsify == "grab":
			q = q.inverse()
		ball = q * ball
		follow_bad = maxf(follow_bad, (ball * grabbed_local).angle_to(p.normalized()))
	gb.end()
	var speeds := []
	for _i in 200:
		gb.coast(1.0 / 90.0)
		speeds.append(gb.angular_velocity.length())
	var mono := true
	for i in range(1, speeds.size()):
		if speeds[i] > speeds[i - 1] + 1e-6:
			mono = false
	if follow_bad < 1e-3 and mono and not gb.coasting():
		r.pass_("трекбол: захваченная точка под кончиком (ошибка %.5f рад), инерция монотонно гаснет" % follow_bad)
	else:
		r.fail("трекбол: ошибка следования %.4f рад, затухание монотонно %s, всё ещё крутится %s" % [follow_bad, mono, gb.coasting()])

	# 3. Настройки: непрерывные пределы и округление, выбор — только из вариантов,
	# сохранение и загрузка, отказ от мусора, уровень глобуса по размеру.
	var st = SettingsRes.new()
	var clamp_hi: bool = st.set_value("radius_cm", 99.0)
	var top: Variant = st.get_value("radius_cm")
	var clamp_ok: bool = not st.set_value("cell_cm", 2.74)
	var rounded: Variant = st.get_value("cell_cm")
	st.step("surface", 1)
	st.set_value("hand_smoothing", 0.35)
	var path_cfg := "user://test_sphere_settings.cfg"
	st.save(path_cfg)
	var st2 = SettingsRes.new()
	var rej: Array = st2.load_from(path_cfg)
	var cf := ConfigFile.new()
	cf.load(path_cfg)
	cf.set_value("sphere", "cell_cm", 99.0)
	cf.set_value("sphere", "panel_side", "под столом")
	cf.save(path_cfg)
	var st3 = SettingsRes.new()
	var rej3: Array = st3.load_from(path_cfg)
	# Уровень глобуса не растёт с размером ячейки, а крупнейший размер даёт 12 ячеек.
	var freqs := []
	st3.values["radius_cm"] = 11.0
	for c in [1.5, 2.5, 4.0, 6.0, 9.0, 15.0]:
		st3.values["cell_cm"] = c
		freqs.append(st3.globe_frequency())
	var freq_mono := true
	for i in range(1, freqs.size()):
		if freqs[i] > freqs[i - 1]:
			freq_mono = false
	st3.values["cell_cm"] = 2.5
	var got_cm := SettingsRes.globe_cell_cm(st3.globe_frequency(), 11.0)
	st3.values["cell_cm"] = 15.0
	var lens_capped := is_equal_approx(st3.lens_alpha(), SettingsRes.LENS_ALPHA_MAX)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path_cfg))
	if clamp_hi and is_equal_approx(float(top), 20.0) and clamp_ok and is_equal_approx(float(rounded), 2.7) \
			and st2.values == st.values and rej.is_empty() and rej3 == ["cell_cm", "panel_side"] \
			and st3.values["surface"] == "lens" and freq_mono and freqs.back() == 0 and absf(got_cm - 2.5) < 1.0 \
			and lens_capped:
		r.pass_("настройки: предел и округление (99 → 20 см, 2,74 → 2,7), сохранение и загрузка, мусор отвергнут, уровень глобуса по размеру %s (2.5 см → %.2f см), линза с пределом угла" % [freqs, got_cm])
	else:
		r.fail("настройки: предел %s/%s, округление %s/%s, круг %s, отвергнуто %s/%s, уровни %s, 2.5 см → %.2f, линза %s" % [
				clamp_hi, top, clamp_ok, rounded, st2.values == st.values, rej, rej3, freqs, got_cm, lens_capped])

	# 4. Мастер: основные настройки по порядку, «Дополнительно» не в мастере, назад без
	# потери, умолчание, итог и сохранение.
	var ws = SettingsRes.new()
	var wz = Wizard.new(ws)
	var order_ok: bool = wz.steps().slice(0, SettingsRes.MAIN.size()) == SettingsRes.MAIN \
			and not wz.steps().any(func(x): return x in SettingsRes.ADVANCED)
	ws.values["surface"] = "lens"
	wz.note_change()
	wz.confirm()
	wz.confirm()
	ws.set_value("radius_cm", 14.5)
	wz.note_change()
	var r_val: Variant = ws.get_value("radius_cm")
	wz.confirm()
	wz.back()
	var back_at := wz.current()
	var kept: Variant = ws.get_value("radius_cm")
	wz.confirm()
	wz.skip()
	while wz.current() != Wizard.SUMMARY:
		wz.confirm()
	var lines := wz.summary_lines()
	var wpath := "user://test_wizard.cfg"
	wz.confirm(wpath)
	var check = SettingsRes.new()
	check.load_from(wpath)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(wpath))
	if order_ok and back_at == "radius_cm" and kept == r_val and ws.get_value("cell_cm") == SettingsRes.SPEC["cell_cm"]["default"] \
			and lines.size() == SettingsRes.MAIN.size() and wz.done and wz.saved and check.values == ws.values \
			and ws.get_value("surface") == "lens":
		r.pass_("мастер: %d шагов в порядке MAIN, «Дополнительно» не в мастере, назад сохраняет значение, умолчание, итог и сохранение" % SettingsRes.MAIN.size())
	else:
		r.fail("мастер: порядок %s, назад на %s, значение %s→%s, итог %d строк, сохранено %s, совпадает %s" % [order_ok, back_at, r_val, kept, lines.size(), wz.saved, check.values == ws.values])

	# 5. Шар действий: удержание на объекте — центр объект, действия вокруг; «Отмена» — назад со старой прокруткой.
	var nav = Navigator.new(Catalog.new(), SettingsRes.new())
	nav.short(_slot_of(nav, "files"), "прокрутка-корня")
	nav.short(_slot_of(nav, "images"), "прокрутка-файлов")
	var slot_img := _slot_of(nav, "img_map")
	var h := nav.hold(slot_img, "прокрутка-изображений")
	var center_ok: bool = nav.view == "actions" and nav.item_at(0).id == "img_map" and nav.items().size() > 3 \
			and nav.items().slice(1).all(func(x): return x.kind == Item.Kind.ACTION)
	var cancel := nav.back("прокрутка-действий")
	var hold_empty := nav.hold(-1, "пр")
	var folder_actions: bool = nav.view == "actions" and nav.items().slice(1).any(func(x): return x.action == "sort")
	nav.back(null)
	if h["do"] == "reload" and center_ok and cancel["scroll"] == "прокрутка-изображений" and nav.view == "browse" and folder_actions:
		r.pass_("шар действий: удержание — объект в центре и только действия вокруг; «Отмена» возвращает прокрутку; удержание на пустом — действия папки")
	else:
		r.fail("шар действий: %s, центр %s, отмена %s, действия папки %s" % [h, center_ok, cancel, folder_actions])

	# 6. Действие по умолчанию: папка — вход, изображение — просмотр без закрытия, сцена — закрыть,
	# настройка — правка на панели (значение не меняется само).
	var nd = Navigator.new(Catalog.new(), SettingsRes.new())
	nd.short(_slot_of(nd, "files"), null)
	nd.short(_slot_of(nd, "images"), null)
	var img := nd.short(_slot_of(nd, "img_sky"), null)
	nd.back(null)
	nd.short(_slot_of(nd, "scenes"), null)
	var scn := nd.short(_slot_of(nd, "scene_cave"), null)
	nd.back(null)
	nd.back(null)
	nd.short(_slot_of(nd, "settings"), null)
	nd.short(_slot_of(nd, "settings_sphere"), null)
	var before_r: Variant = nd.settings.get_value("radius_cm")
	var opt := nd.short(_slot_of(nd, "set_radius_cm"), null)
	if img["do"] == "default" and not img["close"] and scn["do"] == "default" and scn["close"] \
			and opt["do"] == "edit" and opt["id"] == "radius_cm" and nd.settings.get_value("radius_cm") == before_r:
		r.pass_("действие по умолчанию: изображение — просмотр без закрытия, сцена — открыть и закрыть, настройка — правка на панели")
	else:
		r.fail("действие по умолчанию: %s %s %s, радиус %s→%s" % [img, scn, opt, before_r, nd.settings.get_value("radius_cm")])

	# 7. Изменения и отмена: удалить, копировать-вставить, вырезать-вставить, дублировать, новая папка — отмена возвращает всё.
	var cat: Catalog = Catalog.new()
	var nm = Navigator.new(cat, SettingsRes.new())
	var orig := cat.fingerprint()
	nm.short(_slot_of(nm, "files"), null)
	nm.short(_slot_of(nm, "assets"), null)
	_do_action(nm, "asset_house", "delete")
	var deleted: bool = not cat.items.has("asset_house")
	_do_action(nm, "asset_bridge", "copy")
	nm.short(_slot_of(nm, "trees"), null)
	nm.hold(-1, null)
	nm.hold(_action_slot(nm, "paste"), null)
	var pasted: bool = (cat.children_of["trees"] as Array).size() == 6
	nm.back(null)
	_do_action(nm, "trees", "cut")
	nm.back(null)
	nm.short(_slot_of(nm, "scenes"), null)
	nm.hold(-1, null)
	nm.hold(_action_slot(nm, "paste"), null)
	var moved: bool = cat.parent_of.get("trees", "") == "scenes"
	_do_action(nm, "scene_tower", "duplicate")
	nm.hold(-1, null)
	nm.hold(_action_slot(nm, "new_folder"), null)
	var self_move := cat.move_to("scenes", "drafts")
	var undos := 5 if falsify != "undo" else 4
	for _i in undos:
		nm.undo()
	if deleted and pasted and moved and not self_move and cat.fingerprint() == orig:
		r.pass_("изменения и отмена: удаление, копирование, перемещение папки, дублирование, новая папка — %d отмен вернули каталог полностью; папка в своего потомка — отказ" % undos)
	else:
		r.fail("изменения и отмена: удалено %s, вставлено %s, перемещено %s, в себя %s, каталог совпал %s" % [deleted, pasted, moved, self_move, cat.fingerprint() == orig])

	# 8. Множественный выбор: отметки, действия группы, удаление группы, отмена.
	var cat2: Catalog = Catalog.new()
	var ms = Navigator.new(cat2, SettingsRes.new())
	var orig2 := cat2.fingerprint()
	ms.short(_slot_of(ms, "files"), null)
	ms.short(_slot_of(ms, "logic"), null)
	ms.hold(-1, null)
	ms.hold(_action_slot(ms, "multi"), null)
	ms.short(_slot_of(ms, "logic_door"), null)
	ms.short(_slot_of(ms, "logic_timer"), null)
	ms.short(_slot_of(ms, "logic_quest"), null)
	ms.short(_slot_of(ms, "logic_quest"), null)
	var marked_n: int = ms.marked.size()
	ms.hold(_slot_of(ms, "logic_door"), null)
	var group: bool = ms.item_at(0).id == "group_center" and ms.items().size() == 4
	ms.hold(_action_slot(ms, "delete"), null)
	var gone: bool = not cat2.items.has("logic_door") and not cat2.items.has("logic_timer") and cat2.items.has("logic_quest")
	ms.undo()
	if marked_n == 2 and group and gone and cat2.fingerprint() == orig2 and not ms.multi:
		r.pass_("множественный выбор: повторное нажатие снимает отметку, группа из 2 — три действия, удаление группы и отмена")
	else:
		r.fail("множественный выбор: отмечено %d, группа %s, удалены %s, отмена %s" % [marked_n, group, gone, cat2.fingerprint() == orig2])

	# 9. Сортировка, фильтр, буква, путь, недавние.
	var ns = Navigator.new(Catalog.new(), SettingsRes.new())
	ns.short(_slot_of(ns, "files"), null)
	ns.short(_slot_of(ns, "assets"), null)
	ns.short(_slot_of(ns, "trees"), null)
	ns.hold(-1, "tr")
	var letters_res := ns.hold(_action_slot(ns, "letters"), null)
	var letters: Array = ns.items().slice(1).map(func(x): return x.title)
	var focus := ns.short(ns.items().map(func(x): return x.title).find("П"), null)
	var focus_ok: bool = focus["do"] == "focus" and ns.item_at(focus["slot"]).title.begins_with("П")
	ns.hold(-1, null)
	ns.hold(_action_slot(ns, "path"), null)
	var to_root := ns.short(1, null)
	var at_root: bool = ns.state.folder() == "" and ns.view == "browse"
	ns.short(_slot_of(ns, "files"), null)
	ns.short(_slot_of(ns, "images"), null)
	ns.short(_slot_of(ns, "img_stone"), null)
	var same_folder_first: String = ns.item_at(0).id
	ns.back(null)
	ns.short(_slot_of(ns, "images"), null)
	var reentry_first: String = ns.item_at(0).id
	ns.hold(-1, null)
	ns.hold(_action_slot(ns, "filter"), null)
	var filtered: bool = ns.items().all(func(x): return x.kind in [Item.Kind.SCENE, Item.Kind.FOLDER])
	if letters_res["do"] == "reload" and letters == ["Б", "Д", "К", "П", "С"] and focus_ok and at_root \
			and same_folder_first != "img_stone" and reentry_first == "img_stone" and filtered:
		r.pass_("переходы: буквы %s и прыжок, путь в корень, недавний — первым только при новом входе, фильтр" % [letters])
	else:
		r.fail("переходы: буквы %s, прыжок %s, корень %s, первый %s/%s, фильтр %s" % [letters, focus, at_root, same_folder_first, reentry_first, filtered])

	# 10. Опасное действие коротким нажатием не исполняется.
	var cat3: Catalog = Catalog.new()
	var nh = Navigator.new(cat3, SettingsRes.new())
	nh.short(_slot_of(nh, "files"), null)
	nh.short(_slot_of(nh, "logic"), null)
	nh.hold(_slot_of(nh, "logic_door"), null)
	var del_slot := _action_slot(nh, "delete")
	var try := nh.short(del_slot, null)
	if try["do"] == "need_hold" and cat3.items.has("logic_door") and nh.is_danger(del_slot):
		r.pass_("опасное: короткое на «Удалить» — подсказка удерживать, объект на месте")
	else:
		r.fail("опасное: %s, объект %s" % [try, cat3.items.has("logic_door")])

	_panel_visibility_checks()
	_hand_checks()


## Видимость панели (решение владельца, отзыв сессии 4: появляться только когда есть
## что показывать). Правило чистое — проверяется таблицей истинности, а не сценой.
func _panel_visibility_checks() -> void:
	var hold: int = MenuRes.PANEL_HOLD_MS
	var show := func(open: bool, scenario: bool, item: bool, toast: bool, since: int) -> bool:
		# фальсификатор: пустая ячейка тоже «содержимое» — панель висит всегда, как до шага 1е
		var has_item := true if falsify == "panelshow" else item
		return MenuRes.panel_should_show(open, scenario, has_item, toast, since)
	var bad: Array[String] = []
	# объект под активной ячейкой — видна сразу
	if not show.call(true, false, true, false, 0):
		bad.append("объект не показал панель")
	# объект ушёл: держится PANEL_HOLD_MS, потом гаснет
	if not show.call(true, false, false, false, hold - 1):
		bad.append("панель погасла раньше удержания (%d мс)" % hold)
	if show.call(true, false, false, false, hold):
		bad.append("панель не погасла после удержания (%d мс)" % hold)
	# пустая ячейка и «Назад» без сценария — нет (давно ушедший объект)
	if show.call(true, false, false, false, 100000):
		bad.append("пустая ячейка показала панель")
	# правка, мастер, поиск — видна даже на пустой ячейке
	if not show.call(true, true, false, false, 100000):
		bad.append("сценарий (правка, мастер, поиск) не показал панель")
	# сообщение — видна
	if not show.call(true, false, false, true, 100000):
		bad.append("сообщение не показало панель")
	# шар закрыт: панель гаснет, но сценарий сильнее — иначе «Готово» мастера пропало бы
	for it in [false, true]:
		for ts in [false, true]:
			if show.call(false, false, it, ts, 0):
				bad.append("закрытый шар показал панель (объект %s, тост %s)" % [it, ts])
			if not show.call(false, true, it, ts, 0):
				bad.append("закрытый шар отнял панель у мастера (объект %s, тост %s)" % [it, ts])
	if bad.is_empty():
		r.pass_("видимость панели: объект — сразу, после ухода держится %d мс и гаснет; пустая ячейка и «Назад» — нет; правка, мастер, поиск и сообщение — да; закрытый шар гасит её, но не отнимает у мастера и правки" % hold)
	else:
		r.fail("видимость панели: %s" % "; ".join(bad))


func _hand_checks() -> void:
	# Стик: точка напротив лица движется с одной угловой скоростью по горизонтали и
	# вертикали при любом наклоне переда к верху зрителя; направления — влево и вниз.
	var st_bad: Array[String] = []
	var ang := 0.01
	var view_up := Vector3.UP
	for tilt_deg in [0.0, 30.0, 60.0, 80.0]:
		var f := Vector3(0, 0, 1).rotated(Vector3.RIGHT, -deg_to_rad(tilt_deg))    # перёд наклонён к верху
		var right_v := view_up.cross(f).normalized()
		var up_t := (view_up - f * view_up.dot(f)).normalized()
		for sv in [Vector2(1, 0), Vector2(0, 1)]:
			var q: Quaternion = Stick.rotation_old(f, view_up, sv, ang) if falsify == "stick" else Stick.rotation(f, view_up, sv, ang)
			var moved: Vector3 = q * f
			var got := moved.angle_to(f)
			var dirn: float = (moved - f).dot(right_v) if sv.x > 0.0 else (moved - f).dot(up_t)
			if absf(got - ang) > ang * 0.01 or dirn >= 0.0:
				st_bad.append("наклон %.0f° стик %s: %.4f рад вместо %.4f, направление %s" % [tilt_deg, sv, got, ang, "верно" if dirn < 0.0 else "обратное"])
	if st_bad.is_empty():
		r.pass_("стик: наклон переда 0–80° — горизонталь и вертикаль двигают точку напротив лица на одинаковый угол, влево и вниз")
	else:
		r.fail("стик: %s" % "; ".join(st_bad))

	# Вращение рукой: «глобус на подставке» — наклон и крен кисти не меняют ориентацию,
	# поворот вокруг вертикали меняет ровно на свой угол; «лицом к шлему» — рука не
	# влияет, +Z шара на голову; «как шар» — ориентация руки.
	# Допуск 2e-3 рад: real_t — float32, angle_to у совпадающих кватернионов даёт
	# до 7e-4 (acos около 1).
	const QTOL := 0.002
	var hf = HandFollow.new()
	var ball := Vector3(0.1, 1.2, -0.3)
	var headp := Vector3(0.0, 1.6, 0.2)
	# Голова смотрит вниз на шар в руке: её верх завален вперёд, и «лицом к шлему»
	# берёт верх именно отсюда.
	var head_xf := Transform3D(Basis(Vector3.RIGHT, -deg_to_rad(40.0)), headp)
	# собственные наклон (вокруг X кисти) и крен (вокруг её оси −Z)
	var tilt := Quaternion(Vector3.RIGHT, 0.5) * Quaternion(Vector3.BACK, 0.3)
	var yaw := Quaternion(Vector3.UP, 0.7)
	hf.mode = "stand"
	var stand_tilt: Quaternion = hf.target(tilt, ball, head_xf)
	var stand_yaw: Quaternion = hf.target(yaw * tilt, ball, head_xf)
	hf.mode = "face"
	var face_a: Quaternion = hf.target(tilt, ball, head_xf)
	var face_b: Quaternion = hf.target(yaw, ball, head_xf)
	var face_z: float = (face_a * Vector3.BACK).angle_to(headp - ball)
	hf.mode = "ball"
	var ball_t: Quaternion = hf.target(tilt, ball, head_xf)
	if stand_tilt.angle_to(Quaternion.IDENTITY) < QTOL and stand_yaw.angle_to(yaw) < QTOL \
			and face_a.angle_to(face_b) < QTOL and face_z < QTOL and ball_t.angle_to(tilt) < QTOL:
		r.pass_("вращение рукой: подставка — наклон с креном 0 рад, курс 0.7 при наклоне с креном; лицом к шлему — рука не влияет, +Z на голову; как шар — рука")
	else:
		r.fail("вращение рукой: подставка наклон %.4f, курс %.4f; лицом %.4f, на голову %.4f; шар %.4f" % [
				stand_tilt.angle_to(Quaternion.IDENTITY), stand_yaw.angle_to(yaw), face_a.angle_to(face_b), face_z, ball_t.angle_to(tilt)])

	# Устойчивость «лицом к шлему»: рука ходит в рабочей позе — шар ниже и впереди
	# головы, сдвиги вбок ±10 см и дуга вперёд. Крен шара вокруг оси взгляда
	# относительно верха головы обязан стоять: содержимое линзы прибито к осям шара,
	# и любой крен — это вращение всего меню «само по себе» (отзыв сессии 3).
	# Контроль на той же траектории — прежняя формула с мировым верхом.
	var live = HandFollow.new()
	live.mode = "face"
	live.falsify_world_up = falsify == "faceup"
	var world_up_hf = HandFollow.new()
	world_up_hf.mode = "face"
	world_up_hf.falsify_world_up = true
	var live_roll: Array[float] = []
	var old_roll: Array[float] = []
	var front_err := 0.0
	for i in 61:
		var t := i / 60.0
		var hand_p := headp + Vector3(lerpf(-0.10, 0.10, t), -0.45, -0.25 - 0.08 * sin(t * PI))
		var ql: Quaternion = live.target(Quaternion.IDENTITY, hand_p, head_xf)
		live_roll.append(_roll_about_view(ql, head_xf.basis.y))
		old_roll.append(_roll_about_view(world_up_hf.target(Quaternion.IDENTITY, hand_p, head_xf), head_xf.basis.y))
		front_err = maxf(front_err, (ql * Vector3.BACK).angle_to(headp - hand_p))
	var live_span := _total_variation(live_roll)
	var old_span := _total_variation(old_roll)
	if live_span < 0.01 and front_err < QTOL and old_span > 0.2:
		r.pass_("лицом к шлему устойчиво: на ходе руки ±10 см крен шара %.4f рад, +Z на голову (%.4f); мировой верх на той же траектории — %.2f рад" % [live_span, front_err, old_span])
	else:
		r.fail("лицом к шлему устойчиво: крен %.4f рад (нужно < 0.01), +Z на голову %.4f, контроль с мировым верхом %.4f (нужно > 0.2)" % [live_span, front_err, old_span])

	# Поворот рукой обязан двигать содержимое в мире одинаково у глобуса и у линзы:
	# жалоба сессии 3 звучала как «линза крутится в обратную сторону». У линзы
	# содержимое хранится сдвигом плоскости, а «перёд» пересчитывается каждый кадр
	# (sphere_menu._update_front) — здесь та же математика без сцены.
	var wr_bad: Array[String] = []
	for axis in [Vector3.UP, Vector3.RIGHT, Vector3(1, 1, 0.5).normalized()]:
		var step := Quaternion(axis, 0.02)
		for lens_mode in [false, true]:
			var sf = Lens.new(0.22) if lens_mode else Globe.new(3, "icosa", false)
			_sim_front(sf, Basis(), ball, headp, lens_mode)
			sf.assign(20)
			var key = sf.cell_at_direction(sf.front)
			var b := Basis()
			var w0: Vector3 = b * sf.direction_of(key)
			var total := Quaternion.IDENTITY
			for _i in 15:
				b = Basis(step) * b
				total = step * total
				_sim_front(sf, b, ball, headp, lens_mode)
			var w1: Vector3 = b * sf.direction_of(key)
			var err: float = w1.angle_to(total * w0)
			if err > 0.02:
				wr_bad.append("%s ось %.2f,%.2f,%.2f: %.4f рад" % ["линза" if lens_mode else "глобус", axis.x, axis.y, axis.z, err])
	if wr_bad.is_empty():
		r.pass_("вращение и мир: поворот шара на 0.3 рад по трём осям — ячейка, бывшая в переде, уходит в мире ровно на поворот, и у глобуса, и у линзы")
	else:
		r.fail("вращение и мир: %s" % "; ".join(wr_bad))

	# Сглаживание: рывок кисти на 1 рад — шар догоняет монотонно, без перелёта, не за
	# один кадр, и за секунду; «кисть вращается» поднят на рывке и снят после.
	var sm = HandFollow.new()
	sm.mode = "ball"
	sm.smoothing = 0.0 if falsify == "smooth" else 0.5
	var dt := 1.0 / 90.0
	sm.update(Quaternion.IDENTITY, ball, head_xf, dt)
	var goal := Quaternion(Vector3.UP, 1.0)
	var trace: Array[float] = []
	var rot_on := false
	for i in 90:
		var got_q: Quaternion = sm.update(goal, ball, head_xf, dt)
		trace.append(got_q.angle_to(Quaternion.IDENTITY))
		if i == 0:
			rot_on = sm.rotating()
	var mono := true
	for i in range(1, trace.size()):
		if trace[i] < trace[i - 1] - 1e-6:
			mono = false
	var over: bool = float(trace.max()) > 1.0 + 1e-4
	if mono and not over and trace[0] < 0.9 and absf(trace.back() - 1.0) < 0.01 and rot_on and not sm.rotating():
		r.pass_("сглаживание руки 0.5: рывок 1 рад — первый кадр %.3f, за 1 с %.4f, монотонно без перелёта; «вращается» на рывке и снят после" % [trace[0], trace.back()])
	else:
		r.fail("сглаживание руки: первый кадр %.3f (нужно < 0.9), за 1 с %.4f, монотонно %s, перелёт %s, вращается на рывке %s, после %s" % [
				trace[0], trace.back(), mono, over, rot_on, sm.rotating()])

	_shake_checks()
	_swipe_checks()
	_edit_checks()


## Крен шара вокруг оси взгляда относительно верха головы, рад.
static func _roll_about_view(q: Quaternion, head_up: Vector3) -> float:
	var f: Vector3 = (q * Vector3.BACK).normalized()
	var ref := (head_up - f * head_up.dot(f)).normalized()
	var bu: Vector3 = q * Vector3.UP
	bu = (bu - f * bu.dot(f)).normalized()
	return atan2(f.dot(ref.cross(bu)), ref.dot(bu))


## Полный ход угла по ряду: сумма модулей приращений. Размах max−min соврал бы на
## переходе через ±π.
static func _total_variation(values: Array[float]) -> float:
	var sum := 0.0
	for i in range(1, values.size()):
		sum += absf(wrapf(values[i] - values[i - 1], -PI, PI))
	return sum


## «Перёд» поверхности по позе шара — те же две строки, что в sphere_menu._update_front:
## у линзы смена переда сопровождается обратным поворотом содержимого.
static func _sim_front(sf, b: Basis, ball_pos: Vector3, head_pos: Vector3, lens_mode: bool) -> void:
	var nf: Vector3 = (b.inverse() * (head_pos - ball_pos)).normalized()
	var old: Vector3 = sf.front
	sf.front = nf
	if lens_mode and old.angle_to(nf) > 1e-5:
		sf.apply_rotation(Quaternion(nf, old))


## Трасса руки: вспышки встряхивания вдоль X с трапециевидным окном (разгон, полка,
## торможение), снос руки относительно головы (carry, м/с) и общий перенос головы и
## руки (walk, м/с — ходьба: в разности hand−head он обязан гаситься).
func _shake_feed(sh, seconds: float, amp: float, freq: float, bursts: Array,
		carry: float = 0.0, walk: float = 0.0) -> Array[float]:
	var dt := 1.0 / 90.0
	var fires: Array[float] = []
	for i in int(seconds / dt):
		var t := i * dt
		var head := Vector3(0.0, 1.6, -walk * t)
		var x := carry * t
		for bst in bursts:
			var t0: float = bst[0]
			var dur: float = bst[1]
			if t >= t0 and t < t0 + dur:
				var u := t - t0
				var win := clampf(minf(u / SHAKE_RAMP, (dur - u) / SHAKE_RAMP), 0.0, 1.0)
				x += amp * sin(TAU * freq * u) * win
		var hand := head + Vector3(0.10 + x, -0.45, -0.25)
		if sh.feed(hand, head, dt):
			fires.append(snappedf(t, 0.01))
	return fires


func _new_shake(span_cm: float):
	var sh = ShakeRes.new()
	sh.travel = span_cm / 100.0
	sh.falsify_no_travel = falsify == "shake"
	return sh


func _new_swipe(span_cm: float):
	var sw = SwipeRes.new()
	sw.distance = clampf(span_cm / 100.0 * 3.0, 0.15, 0.30)
	sw.falsify_any_direction = falsify == "swipe"
	return sw


## Встряхивание шара — возврат на верхний уровень (menu/shake.gd). Проверяется вместе
## с контролем: обычные движения руки жест давать не должны, иначе меню будет
## прыгать на корень само.
## Трасса взмаха: рука едет вдоль dir на dist метров за dur секунд (плавный профиль),
## остальное время стоит; walk — общий перенос головы и руки.
func _swipe_feed(sw, seconds: float, dir: Vector3, dist: float, t0: float, dur: float,
		head_basis: Basis = Basis(), walk: float = 0.0) -> Array[float]:
	var dt := 1.0 / 90.0
	var fires: Array[float] = []
	for i in int(seconds / dt):
		var t := i * dt
		var head := Vector3(0.0, 1.6, -walk * t)
		var u := clampf((t - t0) / dur, 0.0, 1.0)
		var moved := dir * dist * smoothstep(0.0, 1.0, u)
		var hand := head + Vector3(0.10, -0.45, -0.25) + moved
		if sw.feed(hand, head, head_basis, dt):
			fires.append(snappedf(t, 0.01))
	return fires


## Резкий взмах влево — второй жест возврата (решение владельца, отзыв сессии 5:
## встряхивание слишком долгое). Проверяется вместе с контролем: обычные движения руки
## взмахом считаться не должны.
func _swipe_checks() -> void:
	var left := Vector3.LEFT      # шлем смотрит на −Z, его «влево» — мировое −X
	var fires: Array[float] = _swipe_feed(_new_swipe(6.0), 2.0, left, 0.20, 0.3, 0.25)
	var disabled = _new_swipe(6.0)
	disabled.enabled = false
	var off: Array[float] = _swipe_feed(disabled, 2.0, left, 0.20, 0.3, 0.25)
	# Поворот головы при неподвижной руке: сигнал — разность в мировых осях, она не
	# меняется вовсе. Проверка держит это свойство: в системе головы жест бы сработал.
	var turned := _swipe_feed(_new_swipe(6.0), 2.0, left, 0.0, 0.3, 0.25,
			Basis(Vector3.UP, 1.2))
	var controls := {
		"медленный перенос влево 0,4 м за 2 с": _swipe_feed(_new_swipe(6.0), 3.0, left, 0.40, 0.3, 2.0),
		"резкий взмах вправо": _swipe_feed(_new_swipe(6.0), 2.0, Vector3.RIGHT, 0.20, 0.3, 0.25),
		"резкий взмах вверх": _swipe_feed(_new_swipe(6.0), 2.0, Vector3.UP, 0.20, 0.3, 0.25),
		"ходьба 1,2 м/с": _swipe_feed(_new_swipe(6.0), 3.0, left, 0.0, 0.3, 0.25, Basis(), 1.2),
	}
	var bad: Array[String] = []
	if fires.size() != 1:
		bad.append("взмах 20 см за 0,25 с дал %d срабатываний (%s)" % [fires.size(), fires])
	if not off.is_empty():
		bad.append("выключенный взмах сработал %d раз" % off.size())
	if not turned.is_empty():
		bad.append("поворот головы при неподвижной руке дал %d срабатываний" % turned.size())
	for name in controls:
		var f: Array = controls[name]
		if not f.is_empty():
			bad.append("контроль «%s»: %d срабатываний (%s)" % [name, f.size(), f])
	if bad.is_empty():
		r.pass_("взмах влево: 20 см за 0,25 с — одно срабатывание (%s с); выключенный молчит; поворот головы при неподвижной руке, медленный перенос, взмахи вправо и вверх, ходьба — 0" % [fires])
	else:
		r.fail("взмах влево: %s" % "; ".join(bad))


func _shake_checks() -> void:
	var bursts := [[0.2, 0.6], [2.0, 0.6]]
	# Вспышка короче прежней: двух разворотов хватает, и 0.5 с достаточно.
	var fires: Array[float] = _shake_feed(_new_shake(6.0), 3.0, 0.07, 3.0, bursts)
	var disabled = _new_shake(6.0)
	disabled.enabled = false
	var off: Array[float] = _shake_feed(disabled, 3.0, 0.07, 3.0, bursts)
	var controls := {
		"перенос руки 0,2 м/с": _shake_feed(_new_shake(6.0), 3.0, 0.0, 0.0, [], 0.2),
		"покачивание 0,5 Гц ±10 см": _shake_feed(_new_shake(6.0), 3.0, 0.10, 0.5, [[0.0, 3.0]]),
		# Дрожь подобрана так, чтобы её держал ИМЕННО порог пути: сглаженная пиковая
		# скорость (0.66 м/с) выше порога 0.57, а путь за полупериод 5 см меньше размаха
		# 6 см. Иначе фальсификатор shake краснел бы не тем сигналом (PRACTICES §2.6).
		"дрожь 7 Гц ±2,5 см": _shake_feed(_new_shake(6.0), 3.0, 0.025, 7.0, [[0.0, 3.0]]),
		"ходьба 1,2 м/с с махом руки": _shake_feed(_new_shake(6.0), 3.0, 0.04, 1.0, [[0.0, 3.0]], 0.0, 1.2),
	}
	var bad: Array[String] = []
	if fires.size() != 2:
		bad.append("две вспышки дали %d срабатываний (%s)" % [fires.size(), fires])
	if not off.is_empty():
		bad.append("выключенный жест сработал %d раз" % off.size())
	for name in controls:
		var f: Array = controls[name]
		if not f.is_empty():
			bad.append("контроль «%s»: %d срабатываний (%s)" % [name, f.size(), f])
	if bad.is_empty():
		r.pass_("встряхивание: две вспышки ±7 см на 3 Гц — ровно 2 срабатывания (%s с), пауза держит; выключенный жест молчит; перенос, покачивание 0,5 Гц, дрожь 7 Гц ±2,5 см и ходьба с махом руки — 0" % [fires])
	else:
		r.fail("встряхивание: %s" % "; ".join(bad))



func _edit_checks() -> void:
	# Правка значения: клавиатура «2,75» → 2.75 по OK (до OK значение не меняется),
	# ⌫ стирает, ввод за пределом — ограничение и сообщение, ползунок и −/+ округляют,
	# выбор ставит вариант, «По умолчанию» — умолчание.
	var es = SettingsRes.new()
	es.values["radius_cm"] = 9.0
	var ed = SettingEdit.new(es, "radius_cm")
	var cell = SettingEdit.new(es, "cell_cm")
	for k in ["2", ",", "7", "9", "⌫"]:
		cell.key("," if k == "," else k)
	var typed_text: String = cell.text()
	var before_ok: Variant = es.get_value("cell_cm")
	if falsify == "keypad":
		cell.typed = cell.typed.replace(",", "x")
	var changed_ok: bool = cell.key("OK")
	var got_cell: float = float(es.get_value("cell_cm"))
	for k in ["4", "0", "OK"]:
		ed.key(k)
	var clamped_msg: String = ed.message
	var clamped_v: float = float(es.get_value("radius_cm"))
	ed.slider(12.26)
	var slid: float = float(es.get_value("radius_cm"))
	ed.nudge(-1)    # шаг радиуса: 1/20 шкалы 6…20 = 0,7 → округление 0,5
	var nudged: float = float(es.get_value("radius_cm"))
	var ch = SettingEdit.new(es, "hand_rotation")
	ch.choose(1)
	var chosen: Variant = es.get_value("hand_rotation")
	ed.default()
	if typed_text == "2,7_" and before_ok == SettingsRes.SPEC["cell_cm"]["default"] and changed_ok \
			and is_equal_approx(got_cell, 2.7) and is_equal_approx(clamped_v, 20.0) and clamped_msg.begins_with("Допустимо") \
			and is_equal_approx(slid, 12.5) and is_equal_approx(nudged, 12.0) and chosen == "stand" \
			and is_equal_approx(float(es.get_value("radius_cm")), 11.0):
		r.pass_("правка значения: «2,79⌫» → «2,7_», OK → 2,7; «40» → 20 с сообщением; ползунок 12,26 → 12,5; − → 12; выбор «на подставке»; умолчание 11")
	else:
		r.fail("правка значения: набор «%s», до OK %s, OK изменил %s → %s; «40» → %s («%s»); ползунок → %s; − → %s; выбор %s; умолчание %s" % [
				typed_text, before_ok, changed_ok, got_cell, clamped_v, clamped_msg, slid, nudged, chosen, es.get_value("radius_cm")])

	# Демонстрации: каждая поддержанная доходит до конца; стик рисует замкнутый
	# квадрат (шар вернулся), доводка уводит ровно на свою долю ячейки, липкость
	# возвращает шар, удержание доводит кольцо до 1, сглаживание дёргает руку.
	var demo_bad: Array[String] = []
	for id in DemoRes.IDS:
		var dm = DemoRes.new()
		dm.start(id, 0.2, 2.0, 400.0)
		var q := Quaternion.IDENTITY
		var f := Vector3(0, 0, 1)
		var max_shift := 0.0
		var max_prog := 0.0
		var jerked := false
		var flung := false
		var frames := 0
		while dm.running() and frames < 1000:
			frames += 1
			var d: Dictionary = dm.update(1.0 / 90.0)
			if falsify == "demo" and id == "stick_speed" and dm.t > 1.5:
				d = {}
			if d.has("stick"):
				# как у меню: перёд и верх неподвижны в системе шара, поворот копится
				# в ориентации ячеек (surface_globe.apply_rotation)
				q = (Stick.rotation(f, Vector3.UP, d["stick"], float(d["angle"])) * q).normalized()
			max_shift = maxf(max_shift, (q * f).angle_to(f))
			max_prog = maxf(max_prog, float(d.get("progress", 0.0)))
			jerked = jerked or (d.has("hand") and not (d["hand"] as Quaternion).is_equal_approx(Quaternion.IDENTITY))
			flung = flung or d.get("fling", false)
		var end_shift := (q * f).angle_to(f)
		match id:
			"stick_speed", "hysteresis":
				if end_shift > 0.01:
					demo_bad.append("%s: шар не вернулся, %.3f рад" % [id, end_shift])
			"detent":
				if absf(end_shift - DemoRes.DETENT_SHIFT * 0.2) > 0.002:
					demo_bad.append("detent: сдвиг %.4f вместо %.4f" % [end_shift, DemoRes.DETENT_SHIFT * 0.2])
			"hold_ms":
				if max_prog < 0.999:
					demo_bad.append("hold_ms: кольцо %.2f" % max_prog)
			"hand_smoothing":
				if not jerked:
					demo_bad.append("hand_smoothing: рывка нет")
			"grab_friction":
				if not flung:
					demo_bad.append("grab_friction: броска нет")
		if dm.running():
			demo_bad.append("%s: не закончилась за %d кадров" % [id, frames])
	if demo_bad.is_empty() and not DemoRes.supports("radius_cm"):
		r.pass_("демонстрации %s: доходят до конца; стик (вправо-обратно, вниз-обратно) и липкость возвращают шар, доводка уводит на 0,6 ячейки, кольцо до 1, рывок руки, бросок" % str(DemoRes.IDS))
	else:
		r.fail("демонстрации: %s" % "; ".join(demo_bad))

	_home_checks()


func _home_checks() -> void:
	# Корень: порядок разделов, действия на пустом — только отмена/повтор, «Назад» на корне
	# закрывает, раздача на корне без ячейки «Назад».
	var cr: Catalog = Catalog.new()
	var nr = Navigator.new(cr, SettingsRes.new())
	var order: Array = nr.items().map(func(x): return x.id)
	nr.hold(-1, null)
	var home_actions: Array = nr.items().slice(1).map(func(x): return x.action)
	nr.back(null)
	var closes: bool = nr.back(null)["do"] == "close"
	var gr = Globe.new(3)
	gr.assign(order.size(), falsify == "rootback")
	var backs := 0
	for c in gr.visible_cells():
		if int(c["slot"]) == Surface.SLOT_BACK:
			backs += 1
	if order == ["files", "settings", "home_search", "set_tasks", "home_plus", "home_exit"] \
			and not home_actions.has("sort") and not home_actions.has("paste") and not home_actions.has("new_folder") \
			and closes and backs == 0:
		r.pass_("корень: Файлы, Настройки, Поиск, Запуск теста, «+», Выход; на пустом — без сортировки и вставки; «Назад» закрывает; ячейки «Назад» нет")
	else:
		r.fail("корень: порядок %s, действия %s, закрывает %s, ячеек «Назад» %d" % [order, home_actions, closes, backs])

	# Избранное: добавить из действий → на корне между разделами и «+»; на корне — «Убрать»;
	# удаление объекта чистит избранное, отмена возвращает; сохранение и загрузка.
	var cf: Catalog = Catalog.new()
	cf.prune_favorites_disabled = falsify == "favorite"
	var nf = Navigator.new(cf, SettingsRes.new())
	nf.short(_slot_of(nf, "files"), null)
	nf.short(_slot_of(nf, "scenes"), null)
	_do_action(nf, "scene_cave", "fav_add")
	nf.state.jump(0, null)
	nf.open_root()
	var home: Array = nf.items().map(func(x): return x.id)
	var placed: bool = home.find("scene_cave") == home.find("set_tasks") + 1 and home.find("home_plus") == home.find("scene_cave") + 1
	nf.hold(_slot_of(nf, "scene_cave"), null)
	var has_remove: bool = _action_slot(nf, "fav_remove") > 0
	nf.back(null)
	nf.short(_slot_of(nf, "files"), null)
	nf.short(_slot_of(nf, "scenes"), null)
	_do_action(nf, "scene_cave", "delete")
	var pruned: bool = not cf.favorites.has("scene_cave")
	nf.undo()
	var restored: bool = cf.favorites.has("scene_cave")
	var fpath := "user://test_favorites.cfg"
	cf.save_favorites(fpath)
	var cf2: Catalog = Catalog.new()
	cf2.load_favorites(fpath)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(fpath))
	if placed and has_remove and pruned and restored and cf2.favorites == ["scene_cave"]:
		r.pass_("избранное: добавлено из действий — на корне перед «+»; на корне «Убрать из избранного»; удаление чистит, отмена возвращает; сохранение и загрузка")
	else:
		r.fail("избранное: место %s (%s), «Убрать» %s, удаление чистит %s, отмена вернула %s, загружено %s" % [placed, home, has_remove, pruned, restored, cf2.favorites])

	# «+»: выбор — вход в Файлы, папка открывается, объект добавляется и возвращает на корень;
	# «Назад» с первого уровня выбора — отмена без добавления.
	var cp: Catalog = Catalog.new()
	var np = Navigator.new(cp, SettingsRes.new())
	np.short(_slot_of(np, "home_plus"), null)
	var in_files: bool = np.state.folder() == "files" and np.picking
	np.short(_slot_of(np, "scenes"), null)
	var res_pick := np.short(_slot_of(np, "scene_forest"), null)
	var picked: bool = cp.favorites == ["scene_forest"] and np.state.folder() == "" and not np.picking and res_pick["do"] == "reload"
	np.short(_slot_of(np, "home_plus"), null)
	np.back(null)
	var cancelled: bool = not np.picking and np.state.folder() == "" and cp.favorites == ["scene_forest"]
	if in_files and picked and cancelled:
		r.pass_("плюс: вход в Файлы в режиме выбора, папка открывается, объект — в меню и возврат на корень; «Назад» — отмена")
	else:
		r.fail("плюс: в Файлах %s, выбран %s (%s), отмена %s" % [in_files, picked, cp.favorites, cancelled])

	# Поиск: подстрока без регистра, начинающиеся — первыми; папка — переход по пути,
	# объект — действие по умолчанию из своей папки; «Отмена» — на корень.
	var cs: Catalog = Catalog.new()
	var nsr = Navigator.new(cs, SettingsRes.new())
	var opened := nsr.short(_slot_of(nsr, "home_search"), null)
	nsr.set_query("МОСТ")
	var found: Array = nsr.items().slice(1).map(func(x): return x.id)
	nsr.set_query("дерев")
	var to_folder := nsr.short(_slot_of(nsr, "trees"), null)
	var folder_path: bool = nsr.state.stack == ["", "files", "assets", "trees"] and nsr.view == "browse"
	nsr.state.jump(0, null)
	nsr.open_root()
	nsr.short(_slot_of(nsr, "home_search"), null)
	nsr.set_query("башн")
	var to_obj := nsr.short(_slot_of(nsr, "scene_tower"), null)
	var obj_ok: bool = to_obj["do"] == "default" and nsr.state.folder() == "scenes" and to_obj.get("search_end", false)
	nsr.state.jump(0, null)
	nsr.open_root()
	nsr.short(_slot_of(nsr, "home_search"), null)
	var cancel_s := nsr.back(null)
	if opened["do"] == "search" and found.size() >= 2 and found[0] == "asset_bridge" and found.has("scene_draft1") \
			and folder_path and to_folder.get("search_end", false) and obj_ok and cancel_s.get("search_end", false) and nsr.view == "browse":
		r.pass_("поиск: «МОСТ» → %s (начинающиеся первыми), папка — по пути, объект — из своей папки, «Отмена» закрывает" % [found])
	else:
		r.fail("поиск: открыт %s, «МОСТ» → %s, папка %s (%s), объект %s, отмена %s" % [opened, found, folder_path, nsr.state.stack, obj_ok, cancel_s])

	# Выход: короткое — подсказка удерживать, удержание — выход; выгрузка пишет файлы.
	var cx: Catalog = Catalog.new()
	var nx = Navigator.new(cx, SettingsRes.new())
	var xs := nx.short(_slot_of(nx, "home_exit"), null)
	var xh := nx.hold(_slot_of(nx, "home_exit"), null)
	var ex: Dictionary = ExportRes.run("user://test_export", ["строка самопроверки"], "проверка")
	var written: bool = (ex["ok"] as Array).has("selfcheck.txt") and FileAccess.file_exists(String(ex["dir"]).path_join("selfcheck.txt")) \
			and (ex["failed"] as Array).is_empty()
	for f in DirAccess.get_files_at(ex["dir"]):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(String(ex["dir"]).path_join(f)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ex["dir"]))
	if xs["do"] == "need_hold" and xh["do"] == "exit" and nx.is_danger(_slot_of(nx, "home_exit")) and written:
		r.pass_("выход: короткое — подсказка удерживать, удержание — выход; выгрузка записала %s" % [ex["ok"]])
	else:
		r.fail("выход: короткое %s, удержание %s, выгрузка %s" % [xs, xh, ex])

	# Страницы (отзыв сессии 7): «Много файлов» (128) при 30 ячейках — каждый пункт ровно на одной
	# странице и по порядку; первая без «Раньше», последняя без «Дальше», на странице не больше
	# пунктов, чем ячеек за вычетом служебных; память страницы у папки; смена предела оставляет
	# на экране первый пункт прежней страницы; предел подписей режет так же.
	var pg_bad: Array[String] = []
	var npg = Navigator.new(Catalog.new(), SettingsRes.new())
	npg.falsify_page_gap = falsify == "pagegap"
	npg.short(_slot_of(npg, "files"), null)
	npg.short(_slot_of(npg, "bulk"), null)
	var full_ids: Array = npg.full_items().map(func(x): return x.id)
	npg.set_page_limits(30, 0)
	var seen_ids: Array = []
	var pages := 0
	while true:
		pages += 1
		var service := (1 if npg.has_next() else 0) + (1 if npg.has_prev() else 0)
		if npg.items().size() + service > 30:
			pg_bad.append("страница %d: %d пунктов + %d служебных > 30" % [pages, npg.items().size(), service])
		if pages == 1 and npg.has_prev():
			pg_bad.append("у первой страницы есть «Раньше»")
		seen_ids.append_array(npg.items().map(func(x): return x.id))
		if not npg.has_next() or pages > 20:
			break
		npg.page_next()
	if seen_ids != full_ids:
		pg_bad.append("страницы дали %d пунктов, порядок %s" % [seen_ids.size(), "совпал" if seen_ids == full_ids.slice(0, seen_ids.size()) else "сбит"])
	npg.page_prev()
	npg.page_prev()
	var remembered: int = npg.page_info()["page"]
	npg.back(null)
	npg.short(_slot_of(npg, "bulk"), null)
	if npg.page_info()["page"] != remembered:
		pg_bad.append("память страницы: вернулись на %d вместо %d" % [npg.page_info()["page"], remembered])
	var first_id: String = npg.items()[0].id
	npg.set_page_limits(50, 0)
	if not npg.items().map(func(x): return x.id).has(first_id):
		pg_bad.append("смена предела 30→50 потеряла пункт %s" % first_id)
	npg.set_page_limits(0, 61)
	var label_max := 0
	npg._page_of.clear()
	npg.set_page_limits(0, 60)
	npg.set_page_limits(0, 61)
	while true:
		label_max = maxi(label_max, npg.items().size())
		if not npg.has_next():
			break
		npg.page_next()
	if label_max > 61:
		pg_bad.append("предел подписей 61: страница на %d" % label_max)
	if pg_bad.is_empty():
		r.pass_("страницы: 128 пунктов при 30 ячейках — %d страниц, каждый пункт ровно раз и по порядку; память страницы; смена предела держит первый пункт; предел подписей 61" % pages)
	else:
		r.fail("страницы: %s" % "; ".join(pg_bad))

	# Раскладка подписи для шейдера: буквы идут подряд (начало — сумма ширин предыдущих), строка
	# не шире клетки, длинное имя переносится по словам и обрывается многоточием на второй строке.
	var lt_bad: Array[String] = []
	var lt = LabelTextRes.new()
	lt.falsify_no_advance = falsify == "glyphx"
	for text in ["Файл 001", "Очень длинное название объекта сцены"]:
		var lay: Dictionary = lt.layout(text)
		var lines: Array = lay["lines"]
		for li in lines.size():
			var x := 0.0
			for e in lines[li]:
				if absf(float(e[1]) - x) > 0.01:
					lt_bad.append("«%s» строка %d: буква с x %.1f вместо %.1f" % [text, li, e[1], x])
					break
				x += float(e[2])
			if absf(float(lay["widths"][li]) - x) > 0.01 or x > LabelTextRes.TEXT_WIDTH:
				lt_bad.append("«%s» строка %d: ширина %.1f, сумма %.1f" % [text, li, lay["widths"][li], x])
	var long_lay: Dictionary = lt.layout("Очень длинное название объекта сцены")
	var long_lines: Array = long_lay["lines"]
	if (lt.layout("Файл 001")["lines"] as Array).size() != 1 or long_lines.size() != 2:
		lt_bad.append("строк: короткое %d, длинное %d" % [(lt.layout("Файл 001")["lines"] as Array).size(), long_lines.size()])
	lt.free()
	if lt_bad.is_empty():
		r.pass_("раскладка подписи: буквы подряд, строка не шире %d px, длинное имя — две строки" % LabelTextRes.TEXT_WIDTH)
	else:
		r.fail("раскладка подписи: %s" % "; ".join(lt_bad.slice(0, 4)))

	# Имя скриншота: screenshot_ + локальное время с миллисекундами, без двоеточий; имена по
	# времени сортируются так же, как время.
	var sn_bad: Array[String] = []
	var t_base := 1789000000.5
	var names: Array = [ScreenshotRes.file_name(t_base + 61.25), ScreenshotRes.file_name(t_base), ScreenshotRes.file_name(t_base + 0.007)]
	var re := RegEx.create_from_string("^screenshot_\\d{4}-\\d{2}-\\d{2}_\\d{2}-\\d{2}-\\d{2}\\.\\d{3}\\.png$")
	for nm in names:
		if re.search(nm) == null or nm.contains(":"):
			sn_bad.append("формат «%s»" % nm)
	var sorted_names := names.duplicate()
	sorted_names.sort()
	if sorted_names != [names[1], names[2], names[0]]:
		sn_bad.append("порядок %s" % [sorted_names])
	if not names[1].ends_with(".500.png") or not names[2].ends_with(".507.png"):
		sn_bad.append("миллисекунды: %s, %s" % [names[1], names[2]])
	if sn_bad.is_empty():
		r.pass_("имя скриншота: %s — время с миллисекундами, без двоеточий, сортируется по времени" % names[1])
	else:
		r.fail("имя скриншота: %s" % "; ".join(sn_bad))

	# Место под скриншоты: сумма размеров только screenshot_*.png, предел 100 МиБ.
	ScreenshotRes.falsify_limit_units = falsify == "shotlimit"
	var sp_bad: Array[String] = []
	var tdir := "user://test_shots"
	DirAccess.make_dir_recursive_absolute(tdir)
	for f in DirAccess.get_files_at(tdir):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(tdir.path_join(f)))
	var mk_file := func(name: String, bytes: int) -> void:
		var fa := FileAccess.open(tdir.path_join(name), FileAccess.WRITE)
		fa.seek(bytes - 1)
		fa.store_8(0)
		fa.close()
	mk_file.call("screenshot_a.png", 60 * 1024 * 1024)
	mk_file.call("other.png", 70 * 1024 * 1024)
	var s60: Dictionary = ScreenshotRes.folder_bytes(tdir)
	var over60: bool = ScreenshotRes.over_limit(s60["bytes"])
	mk_file.call("screenshot_b.png", 50 * 1024 * 1024)
	var s110: Dictionary = ScreenshotRes.folder_bytes(tdir)
	var over110: bool = ScreenshotRes.over_limit(s110["bytes"])
	for f in DirAccess.get_files_at(tdir):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(tdir.path_join(f)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(tdir))
	ScreenshotRes.falsify_limit_units = false
	if s60["bytes"] != 60 * 1024 * 1024 or over60:
		sp_bad.append("60 МиБ: сумма %d, предел %s" % [s60["bytes"], over60])
	if s110["bytes"] != 110 * 1024 * 1024 or not over110:
		sp_bad.append("110 МиБ: сумма %d, предел %s" % [s110["bytes"], over110])
	var note: String = ScreenshotRes.notice({"ok": true, "name": "screenshot_x.png", "width": 1920, "height": 1080,
			"bytes": 2400000, "total_bytes": s110["bytes"], "over_limit": over110, "error": ""})
	if not note.contains("освободите место"):
		sp_bad.append("сообщение без просьбы освободить место: «%s»" % note)
	if sp_bad.is_empty():
		r.pass_("место под скриншоты: чужой файл не считается, 60 МиБ — без сообщения, 110 МиБ — «%s»" % note.get_slice("\n", 2))
	else:
		r.fail("место под скриншоты: %s" % "; ".join(sp_bad))

	# Оба стика: снимок только от двух нажатий почти разом, один раз на удержание.
	var ch := ChordRes.new()
	ch.falsify_one = falsify == "chordone"
	var shots := {}
	var run_trace := func(label: String, trace: Array) -> void:
		var c2 := ChordRes.new()
		c2.falsify_one = ch.falsify_one
		var n := 0
		for step in trace:
			if c2.update(step[0], step[1], step[2]):
				n += 1
		shots[label] = n
	run_trace.call("разом", [[true, true, 0], [true, true, 16], [false, false, 32]])
	run_trace.call("один стик", [[true, false, 0], [true, false, 500], [false, false, 600]])
	run_trace.call("второй через 400 мс", [[true, false, 0], [true, true, 400], [false, false, 500]])
	run_trace.call("второй через 100 мс", [[true, false, 0], [true, true, 100], [false, false, 200]])
	var hold: Array = []
	for t in range(0, 2000, 16):
		hold.append([true, true, t])
	hold.append([false, false, 2000])
	hold.append([true, true, 2100])
	run_trace.call("удержание и повтор", hold)
	var want_shots := {"разом": 1, "один стик": 0, "второй через 400 мс": 0, "второй через 100 мс": 1, "удержание и повтор": 2}
	if shots == want_shots:
		r.pass_("оба стика: %s" % str(shots))
	else:
		r.fail("оба стика: %s, ожидалось %s" % [shots, want_shots])

	# Источник ввода (шаг 1к): выбор живёт до перезапуска — в файл не пишется и из файла, даже
	# старого, не читается; арбитр подчиняется выбору сразу, «авто» возвращает свидетелей.
	var is_bad: Array[String] = []
	var ist := SettingsRes.new()
	ist.falsify_save_session = falsify == "sessionsave"
	ist.set_value("input_source", "hands")
	var is_path := "user://test_input_source.cfg"
	ist.save(is_path)
	var is_cf := ConfigFile.new()
	is_cf.load(is_path)
	if is_cf.has_section_key("sphere", "input_source"):
		is_bad.append("выбор записан в файл")
	is_cf.set_value("sphere", "input_source", "hands")
	is_cf.save(is_path)
	var ist2 := SettingsRes.new()
	ist2.falsify_save_session = ist.falsify_save_session
	var is_rej: Array = ist2.load_from(is_path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(is_path))
	if ist2.get_value("input_source") != "auto" or not is_rej.is_empty():
		is_bad.append("после перезапуска «%s», отвергнуто %s" % [ist2.get_value("input_source"), is_rej])
	if not "input_source" in SettingsRes.ADVANCED:
		is_bad.append("нет в «Дополнительно»")
	var arb := ArbiterRes.new()
	var ctrl_w := {"profile": {"left": "/interaction_profiles/meta/touch_controller_plus", "right": ""},
			"ctrl_pose": {"left": true}, "ctrl_in": {}, "hand_ok": {"left": true, "right": true}, "hand_src": {}}
	arb.mode = "hands"
	var got_manual := arb.feed(0, ctrl_w)
	arb.mode = "auto"
	var got_auto := arb.feed(16, ctrl_w)
	if got_manual != ArbiterRes.HANDS or got_auto != ArbiterRes.CONTROLLERS:
		is_bad.append("арбитр: руки → %s, авто при контроллере → %s" % [got_manual, got_auto])
	if is_bad.is_empty():
		r.pass_("источник ввода: выбор «руки» не пережил перезапуск (и из старого файла не читается), арбитр — сразу руки, «авто» при контроллере — контроллеры")
	else:
		r.fail("источник ввода: %s" % "; ".join(is_bad))

	# Сценарий теста: шаги засчитываются своими событиями в любом порядке (сессия 9: строгий порядок
	# терял сделанное); чужая папка и «Раньше» без «Дальше» шаг не закрывают; B пропускает первый
	# оставшийся; повторное включение продолжает, а не начинает заново.
	var sc_bad: Array[String] = []
	var sc = ScenarioRes.new()
	sc.falsify_order = falsify == "scenarioorder"
	if not sc.start():
		sc_bad.append("первое включение не начало сценарий")
	sc.event("screenshot", {"ok": true}, {"folder": ""})
	if sc.result.get("screenshot", "") != "да":
		sc_bad.append("скриншот раньше остальных не засчитан")
	for _i in ScenarioRes.ROTATE_ACTIVE:
		sc.event("active", {}, {"folder": "files"})
	if sc.result.has("labels"):
		sc_bad.append("вращение не в «Много файлов» засчитало подписи")
	sc.event("page", {"page": 1}, {"folder": "bulk"})
	if sc.result.has("pages"):
		sc_bad.append("«Раньше» без «Дальше» засчитало страницы")
	sc.active = false
	if sc.start() or sc.result.get("screenshot", "") != "да":
		sc_bad.append("повторное включение стёрло пройденное")
	sc.event("page", {"page": 2}, {"folder": "bulk"})
	sc.event("page", {"page": 1}, {"folder": "bulk"})
	sc.event("select", {}, {"folder": ""})
	if sc.result.has("search"):
		sc_bad.append("выбор без «Готово» клавиатуры засчитал поиск")
	sc.event("keyboard", {"state": "enter"}, {"folder": ""})
	sc.event("select", {}, {"folder": ""})
	# Шаги, добавленные после сессии 14: сброс пространства и ОТКАЗ замера высоты (именно отказ
	# доказывает, что окно отбрасывает движение).
	sc.event("space_reset", {}, {"folder": ""})
	sc.event("профиль_глаза", {}, {"folder": ""})
	if sc.result.has("eye_move"):
		sc_bad.append("шаг замера засчитан не отказом")
	sc.event("eye_rejected", {}, {"folder": ""})
	# Шаги, добавленные после сессии 19: гравиперчатка обоими способами, поимка и перевал через край.
	# Способ призыва различается по самой строке, иначе два шага засчитались бы одним действием.
	sc.event("pull", {"mode": "gesture"}, {"folder": ""})
	if sc.result.has("pull_instant"):
		sc_bad.append("призыв жестом засчитал и шаг «сразу»")
	sc.event("pull", {"mode": "instant"}, {"folder": ""})
	sc.event("pull_catch", {}, {"folder": ""})
	sc.event("mantle", {}, {"folder": ""})
	# Перед лицом — ОДИН текущий шаг, а не список: сессия 20, «как будто сплошной список».
	var sc_show := ScenarioRes.new()
	sc_show.falsify_list = falsify == "scenariolist"
	sc_show.start()
	var shown := sc_show.text()
	var bullets := shown.count("•")
	if bullets > 0 or not shown.contains(str(ScenarioRes.STEPS[0]["text"])):
		sc_bad.append("показан не один шаг: маркеров %d, текст «%s»" % [bullets, shown.replace("\n", " | ")])
	if not shown.begins_with("Шаг 1 из %d" % ScenarioRes.STEPS.size()):
		sc_bad.append("нет номера шага: «%s»" % shown.get_slice("\n", 0))
	# Подпись пункта меню говорит, идёт тест или нет.
	if sc_show.menu_title() == ScenarioRes.new().menu_title():
		sc_bad.append("подпись пункта одинакова при включённом и выключенном тесте")
	var skipped: String = sc.skip()
	var want_result := {"screenshot": "да", "pages": "да", "search": "да", "space_reset": "да",
			"eye_move": "да", "pull_gesture": "да", "pull_instant": "да", "pull_catch": "да",
			"mantle": "да", "labels": "пропущен"}
	if skipped != "labels" or not sc.done() or sc.active or sc.result != want_result:
		sc_bad.append("итог %s, пропущен «%s», завершён %s" % [sc.result, skipped, sc.done()])
	if not sc.start() or not sc.result.is_empty():
		sc_bad.append("после прохождения включение не начало заново")
	if sc_bad.is_empty():
		r.pass_("сценарий теста: %d шагов в любом порядке, чужая папка и «Раньше» без «Дальше» не засчитаны, повторное включение продолжает, B пропускает" % ScenarioRes.STEPS.size())
	else:
		r.fail("сценарий теста: %s" % "; ".join(sc_bad))


static func _slot_of(nav: RefCounted, id: String) -> int:
	var list: Array = nav.items()
	for i in list.size():
		if list[i].id == id:
			return i
	return -1


static func _action_slot(nav: RefCounted, action: String) -> int:
	var list: Array = nav.items()
	for i in list.size():
		if list[i].action == action:
			return i
	return -1


## Удержание на объекте → действие (опасное — удержанием, прочие — коротким).
static func _do_action(nav: RefCounted, id: String, action: String) -> void:
	nav.hold(_slot_of(nav, id), null)
	var s := _action_slot(nav, action)
	if nav.is_danger(s):
		nav.hold(s, null)
	else:
		nav.short(s, null)


# --- руки (шаг 1к) ---------------------------------------------------------------
#
# Рука — tests/synth_hand.gd, общая с дымовым прогоном.

const HAND_DT_US := 11111   # кадр 90 Гц


func _synth_hand(ht: XRHandTracker, is_left: bool, wrist: Vector3, fwd: Vector3, up: Vector3,
		curls: Dictionary, pinch_m: float) -> void:
	SynthHand.pose(ht, is_left, wrist, fwd, up, curls, pinch_m)


func _open_curls(c: float = 0.02) -> Dictionary:
	return SynthHand.curls(c)


## Прогнать трассу кадров через HandGesture. frames — массив [curls, pinch_m, wrist_fwd_angle].
## Возвращает число фронтов каждого класса и класс последнего кадра.
func _gesture_trace(g: RefCounted, is_left: bool, frames: Array) -> Dictionary:
	var ht := XRHandTracker.new()
	var fronts := {"fist": 0, "pinch": 0}
	var t := 0
	for fr in frames:
		var ang: float = fr[2] if fr.size() > 2 else 0.0
		var fwd := Vector3.FORWARD.rotated(Vector3.UP, ang)
		_synth_hand(ht, is_left, Vector3(0, 1, 0), fwd, Vector3.UP.rotated(fwd, ang * 0.5), fr[0], fr[1])
		var cls: String = g.update(HandFeaturesRes.sample(ht, is_left, Vector3(0, 1.6, 0.4)), t)
		for k in fronts:
			if g.entered(k):
				fronts[k] += 1
		t += HAND_DT_US
	fronts["last"] = g.prev
	return fronts


func _repeat(fr: Array, n: int) -> Array:
	var out := []
	for _i in n:
		out.append(fr)
	return out


func _hands() -> void:
	var OPEN := _open_curls()
	var FIST := _open_curls(0.62)
	const FAR := 0.06

	# 1. Поза руки: нормаль ладони наружу из ладони, базис шара ортонормирован, «вперёд» вдоль
	# пальцев, начало — в ладони. Знак нормали левой — тот, что сверен с рантаймом (прогон 14).
	HandPoseRes.falsify_mirror = falsify == "handmirror"
	var pose_bad: Array[String] = []
	var ht := XRHandTracker.new()
	for c in [[true, Vector3.UP], [false, Vector3.UP], [true, Vector3.DOWN], [false, Vector3(1, 1, 0)]]:
		_synth_hand(ht, c[0], Vector3(0, 1, 0), Vector3.FORWARD, c[1], OPEN, FAR)
		var want: Vector3 = (c[1] as Vector3).normalized()
		var n: Variant = HandPoseRes.palm_normal(ht, c[0])
		var ps: Variant = HandPoseRes.pose(ht, c[0])
		var name := "%s %s" % ["левая" if c[0] else "правая", c[1]]
		if n == null or (n as Vector3).dot(want) < 0.99:
			pose_bad.append("%s: нормаль %s" % [name, n])
			continue
		var b: Basis = (ps as Transform3D).basis
		var ortho := absf(b.x.dot(b.y)) < 1e-4 and absf(b.y.dot(b.z)) < 1e-4 and absf(b.determinant() - 1.0) < 1e-4
		var palm := ht.get_hand_joint_transform(XRHandTracker.HAND_JOINT_PALM).origin
		if not ortho or b.y.dot(want) < 0.99 or (-b.z).dot(Vector3.FORWARD) < 0.99 \
				or (ps as Transform3D).origin.distance_to(palm) > 1e-5:
			pose_bad.append("%s: поза %s" % [name, ps])
	ht.set_hand_joint_flags(XRHandTracker.HAND_JOINT_INDEX_FINGER_TIP, 0)
	if HandPoseRes.tip(ht) != null:
		pose_bad.append("кончик без отслеживания не отброшен")
	ht.has_tracking_data = false
	if HandPoseRes.pose(ht, true) != null or not HandPoseRes.ray(ht, true).is_empty():
		pose_bad.append("поза без данных не отброшена")
	HandPoseRes.falsify_mirror = false
	if pose_bad.is_empty():
		r.pass_("поза руки: нормаль ладони обеих рук вверх и вниз, базис шара ортонормирован, начало в ладони; неотслеженное отброшено")
	else:
		r.fail("поза руки: %s" % "; ".join(pose_bad))

	# 2. Кулак и щипок по паспорту: два кулака — два фронта; полусжатая рука (0.30, между
	# выходом и входом) кулак не начинает, но и не обрывает; щипок при вытянутых остальных —
	# есть, у свободной руки (остальные согнуты 0.12, прогоны 14–15) гейт его снимает.
	# Контроль: покой и вращение кистью — ни одного срабатывания.
	var cls_bad: Array[String] = []
	var tr := _repeat([OPEN, FAR], 20) + _repeat([FIST, FAR], 20) + _repeat([OPEN, FAR], 20) \
			+ _repeat([FIST, FAR], 20) + _repeat([_open_curls(0.30), FAR], 20) + _repeat([OPEN, FAR], 20)
	var got := _gesture_trace(HandGestureRes.new(), true, tr)
	if got["fist"] != 2 or got["pinch"] != 0:
		cls_bad.append("два кулака → %s" % got)
	got = _gesture_trace(HandGestureRes.new(), true, _repeat([OPEN, FAR], 20) + _repeat([_open_curls(0.30), FAR], 30))
	if got["fist"] != 0:
		cls_bad.append("полусжатая рука → кулак")
	got = _gesture_trace(HandGestureRes.new(), true, _repeat([FIST, FAR], 20) + _repeat([_open_curls(0.30), FAR], 30))
	if got["last"] != "fist":
		cls_bad.append("полусжатая после кулака оборвала его: %s" % got["last"])
	var pinch_curls := {"index": 0.10, "middle": 0.03, "ring": 0.04, "pinky": 0.05}
	var free_curls := {"index": 0.10, "middle": 0.12, "ring": 0.14, "pinky": 0.16}
	var gp := HandGestureRes.new()
	gp.falsify_no_gate = falsify == "handgate"
	got = _gesture_trace(gp, false, _repeat([pinch_curls, FAR], 10) + _repeat([pinch_curls, 0.009], 20)
			+ _repeat([pinch_curls, FAR], 20))
	if got["pinch"] != 1 or got["fist"] != 0:
		cls_bad.append("щипок → %s" % got)
	var gf := HandGestureRes.new()
	gf.falsify_no_gate = falsify == "handgate"
	got = _gesture_trace(gf, false, _repeat([free_curls, FAR], 10) + _repeat([free_curls, 0.005], 30)
			+ _repeat([free_curls, FAR], 10))
	if got["pinch"] != 0:
		cls_bad.append("свободная рука (остальные 0.12) → щипок %d" % got["pinch"])
	var rest := []
	for i in 270:
		rest.append([_open_curls(0.02 + 0.01 * sin(i * 0.3)), FAR, 0.6 * sin(i * 0.05)])
	got = _gesture_trace(HandGestureRes.new(), true, rest)
	if got["fist"] != 0 or got["pinch"] != 0:
		cls_bad.append("покой и вращение кистью → %s" % got)
	if cls_bad.is_empty():
		r.pass_("кулак и щипок: два кулака — 2, полусжатая не начинает и не обрывает, щипок — 1, свободную руку гейт снял, покой 3 с — 0")
	else:
		r.fail("кулак и щипок: %s" % "; ".join(cls_bad))

	# 3. Задержка отпускания (ловушка 21): выброс на один кадр внутри жеста не рвёт его — прогон 14,
	# щипок 21 → 35 → 9 мм; настоящее отпускание засчитывается.
	var rel_bad: Array[String] = []
	var no_rel := falsify == "handrelease"
	var gr := HandGestureRes.new()
	gr.falsify_no_release = no_rel
	got = _gesture_trace(gr, false, _repeat([pinch_curls, FAR], 5) + _repeat([pinch_curls, 0.009], 10)
			+ [[pinch_curls, 0.021], [pinch_curls, 0.035], [pinch_curls, 0.009]] + _repeat([pinch_curls, 0.009], 10)
			+ _repeat([pinch_curls, FAR], 10) + _repeat([pinch_curls, 0.009], 10) + _repeat([pinch_curls, FAR], 10))
	if got["pinch"] != 2:
		rel_bad.append("щипок с выбросом 35 мм и второй щипок → %d фронтов, ожидалось 2" % got["pinch"])
	var gk := HandGestureRes.new()
	gk.falsify_no_release = no_rel
	got = _gesture_trace(gk, true, _repeat([OPEN, FAR], 5) + _repeat([FIST, FAR], 15) + [[OPEN, FAR]]
			+ _repeat([FIST, FAR], 15) + _repeat([OPEN, FAR], 10))
	if got["fist"] != 1 or got["last"] != "":
		rel_bad.append("кулак с выбросом на кадр → %s" % got)
	if rel_bad.is_empty():
		r.pass_("задержка отпускания: выброс на кадр не рвёт ни щипок, ни кулак; настоящее отпускание засчитано")
	else:
		r.fail("задержка отпускания: %s" % "; ".join(rel_bad))

	# 4. Касание кончиком: дрожь у самой поверхности (8…15 мм, через порог входа туда-обратно) —
	# одно касание; кончик в 4 см с той же дрожью (перенос руки мимо шара) — ни одного. Расстояние
	# со знаком (сессия 11): тычок сквозь поверхность на 5 см внутрь и обратно — одно касание;
	# кончик, оказавшийся внутри шара, минуя внешнюю сторону, и дрейфующий к поверхности — ни одного.
	var R := 0.11
	var touch_bad: Array[String] = []
	var tc := HandTouchRes.new()
	tc.falsify_one_threshold = falsify == "handtouch"
	var enters := 0
	var exits := 0
	for i in 60:
		var d := 0.05 - 0.002 * i if i < 20 else 0.0115 + 0.0035 * sin(i * 1.7)
		var ev := tc.update(d, Vector3.BACK, R, 0.02)
		enters += int(ev == "enter")
		exits += int(ev == "exit")
	var last_ev := tc.update(0.05, Vector3.BACK, R, 0.02)
	exits += int(last_ev == "exit")
	if enters != 1 or exits != 1:
		touch_bad.append("дрожь у поверхности → входов %d, выходов %d" % [enters, exits])
	var tf := HandTouchRes.new()
	tf.falsify_one_threshold = tc.falsify_one_threshold
	var far_enters := 0
	for i in 180:
		var d := 0.04 + 0.004 * sin(i * 1.3)
		var dir := Vector3.BACK.rotated(Vector3.UP, 0.02 * i)
		far_enters += int(tf.update(d, dir, R, 0.02) == "enter")
	if far_enters != 0:
		touch_bad.append("кончик в 4 см при переносе руки → %d касаний" % far_enters)
	var poke_abs := falsify == "handpoke"
	var tp := HandTouchRes.new()
	tp.falsify_abs = poke_abs
	var poke_enters := 0
	# 78 мс туда-обратно на 90 Гц, как пары касаний сессии 11
	for d in [0.05, 0.02, 0.005, -0.02, -0.05, -0.02, 0.005, 0.02, 0.05]:
		poke_enters += int(tp.update(d, Vector3.BACK, R, 0.02) == "enter")
	if poke_enters != 1:
		touch_bad.append("сквозной тычок на 5 см → %d касаний" % poke_enters)
	var ti := HandTouchRes.new()
	ti.falsify_abs = poke_abs
	var inside_enters := 0
	for i in 30:
		inside_enters += int(ti.update(-0.05 + 0.0015 * i, Vector3.BACK, R, 0.02) == "enter")
	if inside_enters != 0:
		touch_bad.append("кончик внутри шара дрейфует к поверхности → %d касаний" % inside_enters)
	if touch_bad.is_empty():
		r.pass_("касание кончиком: дрожь 8…15 мм у поверхности — одно касание, кончик в 4 см при переносе — ни одного, сквозной тычок — одно, кончик изнутри — ни одного")
	else:
		r.fail("касание кончиком: %s" % "; ".join(touch_bad))

	# 5. Протяжка: тычок с дрожью кончика 3 мм вдоль поверхности — выбор, не протяжка; ход 0.6
	# ячейки (спорная зона сессии 11) — выбор; ход 5 см — одна протяжка; дрожь туда-обратно по 1 см
	# (сумма шагов большая, дуга малая) — не протяжка. Порог — DRAG_CELLS ячейки 4.17 см глобуса.
	var cell_m := 0.0417
	var drag_m := HandSourceRes.DRAG_CELLS * cell_m
	var drag_bad: Array[String] = []
	var no_drag := falsify == "handdrag"
	var run_touch := func(dirs: Array) -> Dictionary:
		var t2 := HandTouchRes.new()
		t2.falsify_no_drag = no_drag
		var drags := 0
		t2.update(0.05, dirs[0], R, drag_m)   # подход снаружи: вход только после него
		for dr in dirs:
			drags += int(t2.update(0.005, dr, R, drag_m) == "drag")
		t2.update(0.05, dirs.back(), R, drag_m)
		return {"drags": drags, "dragging": t2.dragging, "travel": t2.travel}
	var arc_dir := func(arc_m: float) -> Vector3:
		return Vector3.BACK.rotated(Vector3.UP, arc_m / R)
	var tap := []
	for i in 30:
		tap.append(arc_dir.call(0.003 * sin(i * 2.1)))
	var res_tap: Dictionary = run_touch.call(tap)
	if res_tap["drags"] != 0 or res_tap["dragging"]:
		drag_bad.append("тычок с дрожью 3 мм → %s" % res_tap)
	var near := []
	for i in 21:
		near.append(arc_dir.call(0.6 * cell_m * i / 20.0))
	var res_near: Dictionary = run_touch.call(near)
	if res_near["drags"] != 0:
		drag_bad.append("ход 0.6 ячейки → %s" % res_near)
	var slide := []
	for i in 51:
		slide.append(arc_dir.call(0.001 * i))
	var res_slide: Dictionary = run_touch.call(slide)
	if res_slide["drags"] != 1 or not res_slide["dragging"] or res_slide["travel"] < 0.049:
		drag_bad.append("ход 5 см → %s" % res_slide)
	var wiggle := []
	for i in 60:
		wiggle.append(arc_dir.call(0.01 * sin(i * 0.8)))
	var res_wig: Dictionary = run_touch.call(wiggle)
	if res_wig["drags"] != 0:
		drag_bad.append("дрожь ±1 см → %s" % res_wig)
	if drag_bad.is_empty():
		r.pass_("протяжка: порог %.2f ячейки = %.1f см; тычок с дрожью 3 мм — выбор, ход 0.6 ячейки — выбор, ход 5 см — одна протяжка (путь %.1f см), ±1 см на месте — выбор" % [HandSourceRes.DRAG_CELLS, drag_m * 100.0, res_slide["travel"] * 100.0])
	else:
		r.fail("протяжка: %s" % "; ".join(drag_bad))

	# 6. Арбитр источника: профиль — главный свидетель. Щипок при профиле рук приходит курком —
	# он не должен запереть контроллеры; пролёт профиля через none и мелькание рук на 200 мс
	# не переключают; контроллер забирает управление сразу; вердикт рантайма в решение не входит.
	var CTRL := "/interaction_profiles/meta/touch_controller_plus"
	var HANDP := ArbiterRes.HAND_PROFILE
	var NONE := ArbiterRes.NONE_PROFILE
	var mk := func(pl: String, pr: String, pose: bool, inp: bool, hand_ok: bool,
			src: int = XRHandTracker.HAND_TRACKING_SOURCE_UNKNOWN) -> Dictionary:
		return {"profile": {"left": pl, "right": pr}, "ctrl_pose": {"left": pose, "right": pose},
				"ctrl_in": {"left": inp, "right": inp}, "hand_ok": {"left": hand_ok, "right": hand_ok},
				"hand_src": {"left": src, "right": src}}
	var new_arb := func() -> RefCounted:
		var a := ArbiterRes.new()
		a.falsify_no_hold = falsify == "armswitch"
		a.falsify_trust_word = falsify == "armword"
		return a
	# Прогнать [длительность мс, снимок] шагами по 11 мс; вернуть источник в каждой контрольной точке.
	var run_arb := func(a: RefCounted, segs: Array) -> Array:
		var t := 0
		var marks := []
		for sg in segs:
			var end: int = t + int(sg[0])
			while t < end:
				a.feed(t, sg[1])
				t += 11
			marks.append(a.current)
		return marks
	var arb_bad: Array[String] = []
	var a1: RefCounted = new_arb.call()
	var m1: Array = run_arb.call(a1, [[300, mk.call(HANDP, HANDP, true, true, true)],
			[300, mk.call(HANDP, HANDP, true, true, true)], [2000, mk.call(HANDP, HANDP, true, true, true)]])
	if m1 != [ArbiterRes.CONTROLLERS, ArbiterRes.HANDS, ArbiterRes.HANDS]:
		arb_bad.append("профиль рук со щипком-курком → %s" % [m1])
	var m2: Array = run_arb.call(a1, [[11, mk.call(CTRL, CTRL, true, false, true)]])
	if m2 != [ArbiterRes.CONTROLLERS]:
		arb_bad.append("контроллер взят — не сразу: %s" % [m2])
	var a3: RefCounted = new_arb.call()
	var m3: Array = run_arb.call(a3, [[500, mk.call(CTRL, CTRL, true, false, true)],
			[200, mk.call(NONE, HANDP, false, false, true)], [500, mk.call(CTRL, CTRL, true, false, true)]])
	if m3 != [ArbiterRes.CONTROLLERS, ArbiterRes.CONTROLLERS, ArbiterRes.CONTROLLERS]:
		arb_bad.append("мелькание рук 200 мс → %s" % [m3])
	var a4: RefCounted = new_arb.call()
	var m4: Array = run_arb.call(a4, [[500, mk.call(CTRL, CTRL, true, false, true)],
			[100, mk.call(NONE, NONE, false, false, true)], [600, mk.call(HANDP, HANDP, true, false, true)]])
	if m4 != [ArbiterRes.CONTROLLERS, ArbiterRes.CONTROLLERS, ArbiterRes.HANDS]:
		arb_bad.append("контроллеры отложены через none → %s" % [m4])
	var a5: RefCounted = new_arb.call()
	var m5: Array = run_arb.call(a5, [[500, mk.call(CTRL, HANDP, true, false, true)]])
	if m5 != [ArbiterRes.CONTROLLERS]:
		arb_bad.append("контроллер в одной руке → %s" % [m5])
	var a6: RefCounted = new_arb.call()
	var m6: Array = run_arb.call(a6, [[500, mk.call("", "", true, false, false)],
			[600, mk.call("", "", false, true, true)]])
	if m6 != [ArbiterRes.CONTROLLERS, ArbiterRes.HANDS]:
		arb_bad.append("профиль молчит, судит доставка → %s" % [m6])
	var a7: RefCounted = new_arb.call()
	var m7: Array = run_arb.call(a7, [[600, mk.call(HANDP, HANDP, true, false, true)],
			[500, mk.call(HANDP, HANDP, true, false, true, XRHandTracker.HAND_TRACKING_SOURCE_CONTROLLER)]])
	if m7 != [ArbiterRes.HANDS, ArbiterRes.HANDS] or a7.conflicts == 0:
		arb_bad.append("вердикт рантайма «контроллер» против профиля рук → %s, расхождений %d" % [m7, a7.conflicts])
	if arb_bad.is_empty():
		r.pass_("арбитр источника: щипок-курок не запирает, контроллер — сразу, мелькание 200 мс и пролёт через none — без дребезга, одна рука с контроллером — контроллеры, без профиля — по доставке, вердикт рантайма только считается (%d)" % a7.conflicts)
	else:
		r.fail("арбитр источника: %s" % "; ".join(arb_bad))


# --- настройки по способу ввода (ADR-0010) ------------------------------------------

func _cfg_value(path: String, key: String) -> Variant:
	var cf := ConfigFile.new()
	if cf.load(path) != OK:
		return null
	return cf.get_value("sphere", key, null)


func _rm_dir(dir: String) -> void:
	var abs := ProjectSettings.globalize_path(dir)
	var d := DirAccess.open(abs)
	if d == null:
		return
	for f in d.get_files():
		d.remove(f)
	DirAccess.remove_absolute(abs)


## Руки при первом переключении — копия контроллеров; дальше у каждого своё, в своём файле, и
## после перезапуска руки читаются из файла, а не копируются заново. Общая настройка переходит
## при смене ввода. Стик и вибро рук не касаются. Перенос файлов до профилей — «перенос в профиль».
func _input_settings_check() -> void:
	var dir := "user://test_input_settings"
	_rm_dir(dir)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var bad: Array[String] = []
	var st := SettingsRes.new()
	var ins := InputSettingsRes.new(st, dir)
	ins.falsify_shared = falsify == "inputshare"
	ins.falsify_no_copy = falsify == "nocopy"
	ins.falsify_common_split = falsify == "commonsplit"
	ins.load_current()
	st.set_value("radius_cm", 10.0)
	st.save()
	ins.switch("hands")
	if float(st.get_value("radius_cm")) != 10.0:
		bad.append("руки при первом переключении: радиус %s, а у контроллеров 10" % st.get_value("radius_cm"))
	st.set_value("radius_cm", 15.0)
	st.save()
	ins.switch("controllers")
	var back_ctrl := float(st.get_value("radius_cm"))
	ins.switch("hands")
	var back_hands := float(st.get_value("radius_cm"))
	if back_ctrl != 10.0 or back_hands != 15.0:
		bad.append("после правки рук: контроллеры %s (ждали 10), руки %s (ждали 15)" % [back_ctrl, back_hands])
	var f_ctrl: Variant = _cfg_value(ins.path_for("controllers"), "radius_cm")
	var f_hands: Variant = _cfg_value(ins.path_for("hands"), "radius_cm")
	if f_ctrl != 10.0 or f_hands != 15.0:
		bad.append("файлы: контроллеры %s, руки %s" % [f_ctrl, f_hands])
	# Перезапуск: новый объект, руки читаются из файла.
	var st2 := SettingsRes.new()
	var ins2 := InputSettingsRes.new(st2, dir)
	ins2.falsify_shared = ins.falsify_shared
	ins2.falsify_no_copy = ins.falsify_no_copy
	ins2.falsify_common_split = ins.falsify_common_split
	ins2.load_current()
	var r_ctrl := float(st2.get_value("radius_cm"))
	ins2.switch("hands")
	if r_ctrl != 10.0 or float(st2.get_value("radius_cm")) != 15.0:
		bad.append("после перезапуска: контроллеры %s, руки %s" % [r_ctrl, st2.get_value("radius_cm")])
	# Общая настройка (переопределённая область): правка у рук видна у контроллеров.
	st2.scope_override = {"surface": "user"}
	st2.set_value("surface", "lens")
	st2.save()
	ins2.switch("controllers")
	var common_file: Variant = _cfg_value(ins2.common_path(), "surface")
	if st2.get_value("surface") != "lens" or common_file != "lens":
		bad.append("общая «поверхность»: у контроллеров %s, в общем файле %s" % [st2.get_value("surface"), common_file])
	# Стик и вибро рук не касаются — ни в папке, ни в мастере.
	ins2.switch("hands")
	var wz = WizardRes.new(st2)
	if st2.applies("stick_speed") or st2.applies("haptics") or "stick_speed" in wz.steps() or "haptics" in wz.steps():
		bad.append("у рук видны стик или вибро: шаги мастера %s" % [wz.steps()])
	_rm_dir(dir)
	if bad.is_empty():
		r.pass_("настройки по вводу: руки начались копией контроллеров и разошлись (10 / 15), каждый в своём файле и после перезапуска, общая настройка переходит, у рук нет стика и вибро")
	else:
		r.fail("настройки по вводу: %s" % "; ".join(bad))


# --- профили пользователей (этап C, ADR-0010) ----------------------------------------

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


func _write(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _profile_checks() -> void:
	PinRes.falsify_any = falsify == "pinany"
	# 1. PIN: PBKDF2 сверен с эталоном (hashlib.pbkdf2_hmac Python; RFC 7914 §11 — passwd/salt), верный
	# PIN проходит, неверный нет; после FREE_FAILS ошибок — задержка, и она переживает перезапуск.
	var pin_bad: Array[String] = []
	var vectors := [["password", "salt".to_utf8_buffer(), 1, "120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b"],
			["password", "salt".to_utf8_buffer(), 4096, "c5e478d59288c841aa530db6845c4c8d962893a001ce4e11a4963873aa98134a"],
			["passwd", "salt".to_utf8_buffer(), 1, "55ac046e56e3089fec1691c22544b605f94185216dde0465e68b9d57c20dacbc"]]
	var salt16 := PackedByteArray()
	for i in 16:
		salt16.append(i)
	vectors.append(["1234", salt16, PinRes.ITERATIONS, "91ea059bae0333a2969fc8ccd7c77851dda43f5adb96baeea246a624cdf489ec"])
	var t_pin := 0
	for v in vectors:
		var t0 := Time.get_ticks_usec()
		var got := PinRes.derive((v[0] as String).to_utf8_buffer(), v[1], v[2]).hex_encode()
		if v[2] == PinRes.ITERATIONS:
			t_pin = Time.get_ticks_usec() - t0
		if got != v[3]:
			pin_bad.append("PBKDF2(%s, %d) = %s…" % [v[0], v[2], got.substr(0, 12)])
	if not PinRes.valid("0000") or PinRes.valid("123") or PinRes.valid("123456789") or PinRes.valid("12a4"):
		pin_bad.append("проверка вида PIN")
	var up := UserProfileRes.new()
	up.set_pin("2468", 1000)
	var now := 1_000_000_000
	var seq := []
	for pin in ["1111", "2222", "3333", "2468"]:
		seq.append(up.check_pin(pin, now))
	var wait_ms := up.pin_wait_ms(now)
	var after := up.check_pin("2468", now + wait_ms)
	var dir := "user://test_profile_pin"
	_rm_tree(dir)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	up.check_pin("1111", now + wait_ms + 1)
	up.check_pin("1111", now + wait_ms + 2)
	up.check_pin("1111", now + wait_ms + 3)
	up.save(dir)
	var up2 := UserProfileRes.new()
	up2.load_from(dir)
	var after_restart := up2.check_pin("2468", now + wait_ms + 4)
	_rm_tree(dir)
	if seq != ["wrong", "wrong", "wrong", "wait"] or wait_ms != PinRes.DELAY_MS or after != "ok" or after_restart != "wait":
		pin_bad.append("попытки %s, ждать %d мс, после ожидания «%s», после перезапуска «%s»" % [seq, wait_ms, after, after_restart])
	PinRes.falsify_any = false
	if pin_bad.is_empty():
		r.pass_("PIN: PBKDF2-HMAC-SHA256 совпал с эталоном (4 вектора, %d итераций — %.0f мс на столе), три ошибки — задержка %d мс, она переживает перезапуск" % [
				PinRes.ITERATIONS, t_pin / 1000.0, PinRes.DELAY_MS])
	else:
		r.fail("PIN: %s" % "; ".join(pin_bad))

	# 2. Хранилище: создать два профиля, переименовать, перезапуск читает список и последний активный;
	# удалить активный — активным становится оставшийся; последний не удаляется.
	var root := "user://test_profiles_root"
	_rm_tree(root)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(root))
	var st_bad: Array[String] = []
	var ps := ProfileStoreRes.new(root)
	ps.load_index()
	var a := ps.create("Аня")
	var b := ps.create("Борис")
	var pa = ps.get_profile(a)
	pa.name = "Анна"
	pa.set_pin("1357", 100)
	ps.save_profile(pa)
	ps.set_active(b)
	var ps2 := ProfileStoreRes.new(root)
	ps2.falsify_remove_last = falsify == "removelast"
	ps2.load_index()
	if ps2.order != [a, b] or ps2.index[a]["name"] != "Анна" or not ps2.index[a]["has_pin"] or ps2.startup_id() != b:
		st_bad.append("после перезапуска: порядок %s, %s, запуск %s" % [ps2.order, ps2.index, ps2.startup_id()])
	var removed := ps2.remove(b)
	var last_kept := not ps2.remove(a)
	if not removed or DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(ps2.dir_of(b))) \
			or ps2.startup_id() != a or not last_kept:
		st_bad.append("удаление: %s, каталог остался %s, запуск %s, последний удалился %s" % [removed,
				DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(ps2.dir_of(b))), ps2.startup_id(), not last_kept])
	if st_bad.is_empty():
		r.pass_("хранилище профилей: два профиля, переименование и PIN видны в списке после перезапуска, удаление активного переводит на оставшийся, последний не удаляется")
	else:
		r.fail("хранилище профилей: %s" % "; ".join(st_bad))

	# 3. Перенос: файлы до профилей (наборы по вводу после сессии 12, избранное) уходят в «Основной»,
	# старые — в *.migrated; только sphere_settings.cfg — становится набором контроллеров.
	var mg_bad: Array[String] = []
	var root2 := "user://test_profiles_migrate"
	_rm_tree(root2)
	_write(root2.path_join("settings_controllers.cfg"), "[sphere]\nradius_cm=12.0\n")
	_write(root2.path_join("settings_hands.cfg"), "[sphere]\nradius_cm=16.0\n")
	_write(root2.path_join("favorites.cfg"), "[favorites]\nids=[\"files\"]\n")
	var pm := ProfileStoreRes.new(root2)
	pm.falsify_no_migrate = falsify == "nomigrate"
	var res := pm.ensure_default()
	var pdir: String = pm.dir_of(res["created"])
	for f in ["settings_controllers.cfg", "settings_hands.cfg", "favorites.cfg"]:
		if not FileAccess.file_exists(pdir.path_join(f)) or not FileAccess.file_exists(root2.path_join(f + ".migrated")):
			mg_bad.append("%s не перенесён" % f)
	var again := pm.ensure_default()
	if again["created"] != "":
		mg_bad.append("второй запуск создал ещё профиль")
	var root3 := "user://test_profiles_migrate_old"
	_rm_tree(root3)
	_write(root3.path_join("sphere_settings.cfg"), "[sphere]\nradius_cm=9.0\n")
	var po := ProfileStoreRes.new(root3)
	po.falsify_no_migrate = pm.falsify_no_migrate
	var res3 := po.ensure_default()
	if _cfg_value(po.dir_of(res3["created"]).path_join("settings_controllers.cfg"), "radius_cm") != 9.0:
		mg_bad.append("sphere_settings.cfg не стал набором контроллеров")
	_rm_tree(root2)
	_rm_tree(root3)
	if mg_bad.is_empty():
		r.pass_("перенос в профиль: наборы по вводу и избранное ушли в «Основной», старые файлы — *.migrated; файл до наборов стал набором контроллеров; второй запуск ничего не создал")
	else:
		r.fail("перенос в профиль: %s" % "; ".join(mg_bad))

	# 4. Выгрузка: дерево профилей уходит, секреты — нет (ни secrets.enc, ни секрет устройства).
	ExportRes.falsify_all = falsify == "exportsecret"
	var ex_src := "user://test_export_src"
	var ex_dst := "user://test_export_dst"
	_rm_tree(ex_src)
	_rm_tree(ex_dst)
	_write(ex_src.path_join("profiles/p1/profile.cfg"), "[profile]\n")
	_write(ex_src.path_join("profiles/p1/secrets.enc"), "SECRET")
	_write(ex_src.path_join("profiles/index.cfg"), "[index]\n")
	_write(ex_src.path_join("device.cfg"), "[device]\n")
	var ex_out := {"ok": [], "failed": []}
	ExportRes._copy_tree(ex_src, ex_dst, "profiles", ex_out)
	ExportRes.falsify_all = false
	var copied_profile := FileAccess.file_exists(ex_dst.path_join("profiles/p1/profile.cfg"))
	var leaked := FileAccess.file_exists(ex_dst.path_join("profiles/p1/secrets.enc")) \
			or FileAccess.file_exists(ex_dst.path_join("device.cfg"))
	_rm_tree(ex_src)
	_rm_tree(ex_dst)
	if copied_profile and not leaked and ex_out["failed"].is_empty():
		r.pass_("выгрузка без секретов: профили выгружены (%d файла), secrets.enc и device.cfg — нет" % ex_out["ok"].size())
	else:
		r.fail("выгрузка без секретов: профиль %s, секрет утёк %s, выгружено %s" % [copied_profile, leaked, ex_out["ok"]])

	# 5. Места: та же игровая зона с дрожью вершин 2 см узнаётся, другая — нет, пустая — ни с чем;
	# повторное «запомнить» обновляет место и не теряет якоря.
	var pl_bad: Array[String] = []
	UserProfileRes.falsify_place_any = falsify == "placeany"
	var upl := UserProfileRes.new()
	var room := PackedVector3Array([Vector3(-1, 0, -1), Vector3(1, 0, -1), Vector3(1, 0, 1.5), Vector3(-1, 0, 1.5)])
	upl.remember_place("Кабинет", room, Transform3D(Basis(), Vector3(0, 0, -0.5)), 0.74)
	upl.places[0]["anchors"] = ["uuid-1"]
	var jitter := PackedVector3Array()
	for p in room:
		jitter.append(p + Vector3(0.02, 0, -0.015))
	var other := PackedVector3Array([Vector3(-2, 0, -2), Vector3(2, 0, -2), Vector3(2, 0, 2), Vector3(-2, 0, 2)])
	# Пустая зона без ключа комнаты — «узнавать нечем»: берётся последнее место (иначе повтор плодил
	# бы копии, сессия 14).
	if upl.find_place(jitter) != 0 or upl.find_place(other) != -1 or upl.find_place(PackedVector3Array()) != 0:
		pl_bad.append("узнавание: та же %d, другая %d, пустая %d" % [upl.find_place(jitter), upl.find_place(other),
				upl.find_place(PackedVector3Array())])
	upl.remember_place("Кабинет у окна", jitter, Transform3D(), 0.72)
	if upl.places.size() != 1 or upl.places[0]["anchors"] != ["uuid-1"] or upl.places[0]["name"] != "Кабинет у окна":
		pl_bad.append("повтор: мест %d, %s" % [upl.places.size(), upl.places[0]])
	# Сессия 14: границы у владельца нет вовсе («вершин 0»), и каждое нажатие плодило новое место.
	# Без зоны и без ключа комнаты повтор ОБНОВЛЯЕТ последнее место.
	upl.remember_place("Без границы", PackedVector3Array(), Transform3D(Basis(), Vector3(0, 0, 1)))
	upl.remember_place("Без границы 2", PackedVector3Array(), Transform3D())
	if upl.places.size() != 1 or upl.places[0]["name"] != "Без границы 2":
		pl_bad.append("без зоны: мест %d, последнее %s" % [upl.places.size(), upl.places[0].get("name", "")])
	# Ключ комнаты от шлема (world/room.gd) узнаёт место и без зоны — и различает разные комнаты.
	var upr := UserProfileRes.new()
	upr.remember_place("Кабинет", PackedVector3Array(), Transform3D(), 0.0, "room-A")
	upr.remember_place("Кухня", PackedVector3Array(), Transform3D(), 0.0, "room-B")
	upr.remember_place("Кабинет снова", PackedVector3Array(), Transform3D(), 0.0, "room-A")
	if upr.places.size() != 2 or upr.find_place(PackedVector3Array(), "room-A") != 0 \
			or upr.places[0]["name"] != "Кабинет снова" or upr.find_place(PackedVector3Array(), "room-C") != -1:
		pl_bad.append("ключ комнаты: мест %d, %s" % [upr.places.size(), upr.places])
	UserProfileRes.falsify_place_any = false
	if pl_bad.is_empty():
		r.pass_("места: зона с дрожью вершин 2 см узнана (допуск %.2f м), другая — нет, повтор обновил место с якорями; без зоны повтор обновляет последнее, а ключ комнаты от шлема узнаёт место и различает комнаты" % UserProfileRes.PLACE_TOLERANCE_M)
	else:
		r.fail("места: %s" % "; ".join(pl_bad))


# --- аккаунты (этап D, ADR-0011) -----------------------------------------------------

func _account_checks() -> void:
	# 1. Секреты: запечатанное открывается тем же корнем; чужой корень и подменённый байт — null;
	# корень от PIN не совпадает с хранимым хешем PIN (иначе profile.cfg раскрыл бы ключ);
	# у профилей без PIN корни разные.
	SecretBoxRes.falsify_no_mac = falsify == "nomac"
	var sb_bad: Array[String] = []
	var up := UserProfileRes.new()
	up.set_pin("2468", 100)
	var root := up.unlocked_root
	var data := {"claude": {"key": "sk-ant-TEST"}, "google": {"refresh_token": "1//r"}}
	var blob := SecretBoxRes.seal(root, data)
	var back: Variant = SecretBoxRes.open(root, blob)
	if back != data:
		sb_bad.append("свой корень не открыл: %s" % [back])
	var other := up.unlocked_root.duplicate()
	other[0] = other[0] ^ 1
	if SecretBoxRes.open(other, blob) != null:
		sb_bad.append("чужой корень открыл")
	# Подмена бита в IV — атака на CBC без MAC: меняет ровно этот бит первого блока открытого текста,
	# и JSON остаётся разбираемым («claude» → «blaude»). Подмена в шифротексте дала бы мусор, который
	# отверг бы разбор JSON и без MAC — проверка была бы слепой (первая версия: nomac остался зелёным).
	var tampered := blob.duplicate()
	tampered[5 + 2] = tampered[5 + 2] ^ 0x01
	var forged: Variant = SecretBoxRes.open(root, tampered)
	if forged != null:
		sb_bad.append("подменённый бит IV открылся: %s" % [forged])
	if root == up.pin_hash or blob.get_string_from_ascii().contains("sk-ant-TEST"):
		sb_bad.append("ключ совпал с хешем PIN или секрет виден в файле")
	var dev := PackedByteArray()
	for i in 32:
		dev.append(i)
	if SecretBoxRes.root_without_pin(dev, "pA") == SecretBoxRes.root_without_pin(dev, "pB"):
		sb_bad.append("у профилей без PIN один корень")
	var up2 := UserProfileRes.new()
	up2.pin_salt = up.pin_salt
	up2.pin_hash = up.pin_hash
	up2.pin_iterations = up.pin_iterations
	up2.check_pin("2468", 0)
	if up2.unlocked_root != root:
		sb_bad.append("верный PIN дал другой корень")
	SecretBoxRes.falsify_no_mac = false
	if sb_bad.is_empty():
		r.pass_("секреты: AES-256-CBC + HMAC — свой корень открыл, чужой и подменённый бит IV (подделка «blaude») — нет; корень не равен хешу PIN, у профилей без PIN — разный, верный PIN восстанавливает корень")
	else:
		r.fail("секреты: %s" % "; ".join(sb_bad))

	# 2. Ключи API: форма запроса проверки (эндпоинт, заголовки — по документации) и разбор ответа.
	ApiKeyRes.falsify_wrong_header = falsify == "wrongheader"
	var ak_bad: Array[String] = []
	var rc := ApiKeyRes.check_request("claude", "sk-ant-X")
	var ro := ApiKeyRes.check_request("openai", "sk-X")
	if rc["url"] != "https://api.anthropic.com/v1/models" or rc["method"] != HTTPClient.METHOD_GET \
			or not "x-api-key: sk-ant-X" in rc["headers"] or not "anthropic-version: 2023-06-01" in rc["headers"] \
			or rc["headers"].size() != 2:
		ak_bad.append("Claude: %s" % [rc])
	if ro["url"] != "https://api.openai.com/v1/models" or not "Authorization: Bearer sk-X" in ro["headers"]:
		ak_bad.append("OpenAI: %s" % [ro])
	var st := [ApiKeyRes.interpret(200, '{"data":[{"id":"a"},{"id":"b"}]}')["status"],
			ApiKeyRes.interpret(401, "")["status"], ApiKeyRes.interpret(403, "")["status"],
			ApiKeyRes.interpret(529, "")["status"], ApiKeyRes.interpret(0, "", HTTPRequest.RESULT_CANT_CONNECT)["status"]]
	if st != ["connected", "bad_key", "forbidden", "unavailable", "offline"]:
		ak_bad.append("разбор ответов: %s" % [st])
	if ApiKeyRes.masked("sk-ant-api03-abcdefghijklmnop").contains("abcdefghij"):
		ak_bad.append("ключ на экране целиком")
	ApiKeyRes.falsify_wrong_header = false
	if ak_bad.is_empty():
		r.pass_("ключи API: Claude — GET /v1/models с x-api-key и anthropic-version, OpenAI — Bearer; 200/401/403/529/нет сети → подключён/неверный ключ/запрещено/недоступен/нет сети; ключ на экране замаскирован")
	else:
		r.fail("ключи API: %s" % "; ".join(ak_bad))

	# 3. Поток кода устройства на готовых ответах Google: ожидание (428), slow_down (+5 с к
	# интервалу), успех; отказ человека; истечение кода по времени без запроса.
	var df_bad: Array[String] = []
	var no_slow := falsify == "noslowdown"
	var df := DeviceFlowRes.new("cid", "csec")
	df.falsify_no_slowdown = no_slow
	var creq := df.code_request()
	if creq["url"] != DeviceFlowRes.CODE_URL or not (creq["body"] as String).contains("scope=https%3A%2F%2Fwww.googleapis.com%2Fauth%2Fdrive.file"):
		df_bad.append("запрос кода: %s" % [creq])
	df.on_code(200, '{"device_code":"DC","user_code":"ABCD-EFGH","verification_url":"https://www.google.com/device","expires_in":1800,"interval":5}', 0)
	var early := df.due(4000)
	var at5 := df.due(5000)
	df.on_poll(428, '{"error":"authorization_pending"}', 5000)
	df.on_poll(403, '{"error":"slow_down"}', 10000)
	var next_after_slow := df.next_poll_ms
	var preq := df.poll_request()
	if not (preq["body"] as String).contains("grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Adevice_code") \
			or not (preq["body"] as String).contains("client_secret=csec"):
		df_bad.append("запрос опроса: %s" % preq["body"])
	df.on_poll(200, '{"access_token":"AT","refresh_token":"RT","expires_in":3599,"token_type":"Bearer"}', 20000)
	if early or not at5 or df.user_code != "ABCD-EFGH" or df.url != "https://www.google.com/device" \
			or next_after_slow != 10000 + 10 * 1000 or df.state != "done" or df.refresh_token != "RT":
		df_bad.append("основной путь: рано %s, в 5 с %s, код %s, после slow_down следующий в %d, итог %s" % [early, at5,
				df.user_code, next_after_slow, df.state])
	var dd := DeviceFlowRes.new("cid", "csec")
	dd.code_request()
	dd.on_code(200, '{"device_code":"DC","user_code":"U","verification_url":"u","expires_in":600,"interval":5}', 0)
	dd.on_poll(403, '{"error":"access_denied"}', 5000)
	var de := DeviceFlowRes.new("cid", "csec")
	de.code_request()
	de.on_code(200, '{"device_code":"DC","user_code":"U","verification_url":"u","expires_in":60,"interval":5}', 0)
	var polled_after_expiry := de.due(61000)
	if dd.state != "failed" or not dd.failure.contains("отклонён") or de.state != "failed" or polled_after_expiry:
		df_bad.append("отказ: %s «%s»; истечение: %s, опрос после %s" % [dd.state, dd.failure, de.state, polled_after_expiry])
	if DeviceFlowRes.email_from_about(200, '{"user":{"emailAddress":"a@b.c","displayName":"A"}}') != "a@b.c":
		df_bad.append("адрес из about.get")
	if df_bad.is_empty():
		r.pass_("поток кода устройства: код и адрес показаны, опрос не раньше интервала, 428 — ждём, slow_down — интервал 5 → 10 с, успех даёт токен обновления; отказ и истечение кода (без запроса) — провал; адрес — из about.get")
	else:
		r.fail("поток кода устройства: %s" % "; ".join(df_bad))



## Ссылки на проекты: путь только внутри общего каталога проектов; тот же путь — та же ссылка;
## открытие поднимает проект в недавние и хранит состояние пользователя; всё переживает перезапуск.
func _projects_check() -> void:
	ProjectsRes.falsify_any_path = falsify == "projectpath"
	var bad: Array[String] = []
	var list: Array = []
	var a := ProjectsRes.add(list, "Замок", "castle", 100)
	var b := ProjectsRes.add(list, "Лес", "worlds/forest", 200)
	var again := ProjectsRes.add(list, "Замок (копия)", "castle", 300)
	var rejected := []
	for p in ["../etc", "/sdcard/x", "a//b", "user://x", "", "worlds/../../x"]:
		if ProjectsRes.add(list, "плохой", p, 0) != "":
			rejected.append(p)
	if a == "" or b == "" or again != a or list.size() != 2 or not rejected.is_empty():
		bad.append("добавление: %d ссылок, повтор той же %s, пропущены плохие пути %s" % [list.size(), again == a, rejected])
	ProjectsRes.touch(list, a, 500, {"open": ["башня.tscn"]})
	var order := ProjectsRes.recent(list).map(func(x): return x["title"])
	var up := UserProfileRes.new()
	up.projects = list
	var dir := "user://test_projects"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	up.save(dir)
	var up2 := UserProfileRes.new()
	up2.load_from(dir)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(dir.path_join("profile.cfg")))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(dir))
	var st: Dictionary = up2.projects[ProjectsRes.find(up2.projects, a)]["state"] if ProjectsRes.find(up2.projects, a) >= 0 else {}
	if order != ["Замок", "Лес"] or st.get("open", []) != ["башня.tscn"] or up2.projects.size() != 2:
		bad.append("недавние %s, состояние после перезапуска %s, ссылок %d" % [order, st, up2.projects.size()])
	ProjectsRes.remove(up2.projects, b)
	if up2.projects.size() != 1:
		bad.append("удаление ссылки")
	ProjectsRes.falsify_any_path = false
	if bad.is_empty():
		r.pass_("проекты: ссылка только внутри каталога проектов (6 плохих путей отвергнуты), тот же путь — та же ссылка, открытие — в недавние со своим состоянием, всё пережило перезапуск")
	else:
		r.fail("проекты: %s" % "; ".join(bad))


# --- пространство (этап Ф3) ----------------------------------------------------------

## Высота глаз берётся срединным значением окна: один взгляд под ноги её не сдвигает (сессия 13 дала
## 1.26 и 1.59 м подряд). Если голова гуляла шире SPREAD_MAX_M — замер отбрасывается.
func _space_checks() -> void:
	var eye_bad: Array[String] = []
	var dt := 1.0 / 90.0
	var em := EyeMeasureRes.new()
	em.falsify_instant = falsify == "eyeinstant"
	em.start()
	var res := {}
	var n := int(EyeMeasureRes.WINDOW_S / dt) + 2
	for i in n:
		# ровно стоящий человек: 1.62 ± 1 см, и один кадр «взгляд под ноги» в конце
		var y := 1.62 + 0.01 * sin(i * 0.7)
		if i == n - 2:
			y = 1.31
		var r2 := em.add(y, dt)
		if not r2.is_empty():
			res = r2
			break
	if res.get("ok", false) != true or absf(float(res.get("eye_m", 0.0)) - 1.62) > 0.02:
		eye_bad.append("ровная поза с одним наклоном → %s" % [res])
	var em2 := EyeMeasureRes.new()
	em2.falsify_instant = em.falsify_instant
	em2.start()
	var res2 := {}
	for i in n:
		var r3 := em2.add(1.2 + 0.01 * i, dt)   # человек встаёт: размах больше предела
		if not r3.is_empty():
			res2 = r3
			break
	if res2.get("ok", true) != false:
		eye_bad.append("человек двигался → %s" % [res2])
	if eye_bad.is_empty():
		r.pass_("высота глаз окном: %.0f с, срединное значение 1,62 м при наклоне головы в кадре; размах больше %.2f м — замер отброшен" % [
				EyeMeasureRes.WINDOW_S, EyeMeasureRes.SPREAD_MAX_M])
	else:
		r.fail("высота глаз окном: %s" % "; ".join(eye_bad))

	# Сброс пространства: режим зоны — stage, положение — заново от позы головы, высота глаз —
	# измеряется. Вызовы XR подменены.
	var sp_bad: Array[String] = []
	var sp := SpaceRes.new()
	sp.falsify_no_reset = falsify == "noreset"
	var calls := {"recenter": 0, "mode": -1, "measure": 0}
	var mode_now := [int(XRInterface.XR_PLAY_AREA_SITTING)]
	sp.recenter = func() -> void: calls["recenter"] += 1
	sp.set_play_area = func(m: int) -> bool:
		calls["mode"] = m
		mode_now[0] = m
		return true
	sp.play_area_mode = func() -> int: return mode_now[0]
	var detail := sp.reset(func() -> void: calls["measure"] += 1)
	if calls["recenter"] != 1 or calls["mode"] != int(XRInterface.XR_PLAY_AREA_STAGE) or calls["measure"] != 1 \
			or not detail.contains("режим зоны"):
		sp_bad.append("вызовы %s, строка «%s»" % [calls, detail])
	if sp_bad.is_empty():
		r.pass_("сброс пространства: режим зоны → stage, положение сброшено (center_on_hmd), высота глаз измеряется заново; в журнал — «%s»" % detail)

	else:
		r.fail("сброс пространства: %s" % "; ".join(sp_bad))


# --- перемещение и уровень (этап Ф3, часть 2) ----------------------------------------

func _move_checks() -> void:
	var dt := 1.0 / 90.0

	# 1. Дуга телепорта: падает вниз, не длиннее дальности, площадка годится по наклону.
	TeleportRes.falsify_any_slope = falsify == "teleportslope"
	var arc_bad: Array[String] = []
	var pts := TeleportRes.arc(Vector3(0, 1.2, 0), Vector3(0, 0, -1), 8.0)
	var falls: bool = pts[pts.size() - 1].y < pts[0].y
	var length: float = pts[0].distance_to(pts[pts.size() - 1])
	var short_arc := TeleportRes.arc(Vector3(0, 1.2, 0), Vector3(0, 0, -1), 3.0)
	if not falls or length > 8.6 or short_arc.size() >= pts.size():
		arc_bad.append("дуга: падает %s, длина %.1f, короткая %d из %d точек" % [falls, length, short_arc.size(), pts.size()])
	var slopes := [TeleportRes.landing_ok(Vector3.UP), TeleportRes.landing_ok(Vector3(0.5, 0.86, 0).normalized()),
			TeleportRes.landing_ok(Vector3(1, 0.2, 0).normalized()), TeleportRes.landing_ok(Vector3.DOWN)]
	if slopes != [true, true, false, false]:
		arc_bad.append("наклоны (0°, 30°, 79°, потолок): %s" % [slopes])
	TeleportRes.falsify_any_slope = false
	if arc_bad.is_empty():
		r.pass_("дуга телепорта: падает вниз, дальность держится, площадка до %.0f° годится, круче и потолок — нет" % TeleportRes.MAX_SLOPE_DEG)
	else:
		r.fail("дуга телепорта: %s" % "; ".join(arc_bad))

	# 2. Мигание: затемнение до конца, перенос в темноте, возврат света. Рывок: без затемнения,
	# путь за SHIFT_S.
	var tp_bad: Array[String] = []
	var tp := TeleportRes.new()
	var a := Vector3(0, 0, 0)
	var b := Vector3(4, 0, -3)
	tp.start(a, b, "blink")
	var mid := {}
	var moved_at_fade := false
	var steps := 0
	while tp.phase != "" and steps < 200:
		var res := tp.tick(dt)
		if res["fade"] > 0.99 and mid.is_empty():
			mid = res
		if res["fade"] < 0.5 and res["pos"].distance_to(b) < 0.01 and not moved_at_fade:
			moved_at_fade = res["done"]
		steps += 1
	if mid.is_empty() or mid["pos"].distance_to(b) > 0.01 or steps < 15:
		tp_bad.append("мигание: в темноте %s, кадров %d" % [mid, steps])
	var tp2 := TeleportRes.new()
	tp2.start(a, b, "shift")
	var max_fade := 0.0
	var frames := 0
	var last := a
	while tp2.phase != "" and frames < 200:
		var res2 := tp2.tick(dt)
		max_fade = maxf(max_fade, res2["fade"])
		last = res2["pos"]
		frames += 1
	var expect := int(TeleportRes.SHIFT_S / dt)
	if max_fade > 0.01 or last.distance_to(b) > 0.01 or absi(frames - expect) > 2:
		tp_bad.append("рывок: затемнение %.2f, конец %s, кадров %d вместо %d" % [max_fade, last, frames, expect])
	if tp_bad.is_empty():
		r.pass_("перенос и рывок: мигание переносит в темноте и возвращает свет (%d кадров), рывок — без затемнения за %.2f с" % [steps, TeleportRes.SHIFT_S])
	else:
		r.fail("перенос и рывок: %s" % "; ".join(tp_bad))

	# 3. Повороты: щелчок один на отклонение стика (удержание не крутит), угол кратен настройке,
	# пауза между щелчками; плавный — угол за секунду.
	var turn_bad: Array[String] = []
	var tn := TurnRes.new()
	tn.falsify_repeat = falsify == "turnhold"
	var snaps := 0
	for i in 90:
		if not is_zero_approx(tn.snap(1.0, 45.0, dt)):
			snaps += 1
	var after_release := 0
	tn.snap(0.0, 45.0, dt)
	for i in 30:
		if not is_zero_approx(tn.snap(1.0, 45.0, dt)):
			after_release += 1
	var angle := tn.snap(0.0, 45.0, dt)
	tn.snap(-1.0, 30.0, dt)
	var left_turn := tn.snap(-1.0, 30.0, 1.0)
	var smooth_deg := 0.0
	for i in 90:
		smooth_deg += TurnRes.smooth(1.0, 90.0, dt)
	if snaps != 1 or after_release != 1 or absf(smooth_deg - 90.0) > 1.0:
		turn_bad.append("щелчков за удержание %d, после отпускания %d, плавный за секунду %.1f°" % [snaps, after_release, smooth_deg])
	if not is_zero_approx(TurnRes.smooth(0.1, 90.0, dt)):
		turn_bad.append("плавный крутит от дрожи стика")
	if turn_bad.is_empty():
		r.pass_("повороты: удержание стика — один щелчок, после отпускания снова один, пауза %.2f с; плавный — 90°/с" % TurnRes.SNAP_COOLDOWN_S)
	else:
		r.fail("повороты: %s" % "; ".join(turn_bad))

	# 4. Непрерывное движение: только по горизонтали (наклон головы не поднимает), мёртвая зона,
	# скорость из настройки.
	ContinuousRes.falsify_vertical = falsify == "movevertical"
	var cont_bad: Array[String] = []
	var looking_down := Basis(Vector3.RIGHT, deg_to_rad(-60.0))
	var v := ContinuousRes.velocity(Vector2(0, 1), looking_down, 1.4)
	if absf(v.y) > 0.001 or absf(v.length() - 1.4) > 0.01:
		cont_bad.append("взгляд вниз: %s" % v)
	if ContinuousRes.velocity(Vector2(0.05, 0.05), Basis(), 1.4) != Vector3.ZERO:
		cont_bad.append("дрожь стика двигает")
	var side := ContinuousRes.velocity(Vector2(1, 0), Basis(), 1.4)
	if absf(side.x - 1.4) > 0.01:
		cont_bad.append("вбок: %s" % side)
	ContinuousRes.falsify_vertical = false
	if cont_bad.is_empty():
		r.pass_("непрерывное движение: взгляд вниз не поднимает, дрожь стика не двигает, скорость 1,4 м/с по горизонтали")
	else:
		r.fail("непрерывное движение: %s" % "; ".join(cont_bad))

	# 5. Виньетка: в покое ноль, на скорости ходьбы — полная по уровню настройки, выключенная — ноль.
	VignetteRes.falsify_always = falsify == "vignettealways"
	var vg_bad: Array[String] = []
	var vg := VignetteRes.new()
	for i in 60:
		vg.update(0.0, 0.0, "light", dt)
	var at_rest := vg.value
	for i in 60:
		vg.update(1.4, 0.0, "light", dt)
	var walking := vg.value
	var vg2 := VignetteRes.new()
	for i in 60:
		vg2.update(1.4, 0.0, "off", dt)
	var turning := VignetteRes.new()
	for i in 60:
		turning.update(0.0, 90.0, "strong", dt)
	if at_rest > 0.02 or absf(walking - VignetteRes.LEVELS["light"]) > 0.05 or vg2.value > 0.01 \
			or absf(turning.value - VignetteRes.LEVELS["strong"]) > 0.05:
		vg_bad.append("покой %.2f, ходьба %.2f, выкл %.2f, поворот %.2f" % [at_rest, walking, vg2.value, turning.value])
	VignetteRes.falsify_always = false
	if vg_bad.is_empty():
		r.pass_("виньетка: покой 0, ходьба 1,4 м/с — %.2f (лёгкая), поворот 90°/с — %.2f (сильная), «выкл» — ноль" % [walking, turning.value])
	else:
		r.fail("виньетка: %s" % "; ".join(vg_bad))

	# 6. Лазанье: точка захвата ФИКСИРОВАНА на зацепе, ведёт последняя схватившая рука, рука далеко
	# от зацепа — срыв, при отпускании инерция плюс отталкивание. Сессия 17: мир ехал за дельтой
	# руки, точка захвата плыла, и двенадцать захватов дали ноль сантиметров вверх.
	var cl_bad: Array[String] = []
	var cl := ClimbRes.new()
	cl.falsify_no_clamp = falsify == "climbjump"
	cl.falsify_drift = falsify == "climbdrift"
	cl.falsify_no_break = falsify == "nobreak"
	cl.grab("right", Vector3(0, 1.5, 0))
	var moved := cl.update({"right": Vector3(0, 1.8, 0)}, dt)
	if moved.distance_to(Vector3(0, -0.3, 0)) > 0.001:
		cl_bad.append("рука вверх на 30 см → %s (ждали −0.3 по Y)" % moved)
	# Рука осталась на месте, а тело ещё не двинулось: смещение обязано повториться целиком —
	# именно этим фиксированная точка отличается от «дельты за кадр», которая дала бы ноль.
	var again := cl.update({"right": Vector3(0, 1.8, 0)}, dt)
	if again.distance_to(Vector3(0, -0.3, 0)) > 0.001:
		cl_bad.append("точка захвата уехала за рукой: повтор дал %s вместо −0.3 по Y" % again)
	var jump := cl.update({"right": Vector3(0, 4.0, 0)}, dt)
	if jump.length() > ClimbRes.MAX_STEP_M + 0.001:
		cl_bad.append("скачок трекинга не отсечён: %s" % jump)
	# Срыв: рука ушла от зацепа дальше предела.
	var far := cl.overreached({"right": Vector3(0, 1.5 + ClimbRes.BREAK_M + 0.1, 0)})
	var near := cl.overreached({"right": Vector3(0, 1.5 + ClimbRes.BREAK_M - 0.1, 0)})
	if far != ["right"] or not near.is_empty():
		cl_bad.append("срыв: далеко %s, близко %s" % [far, near])
	cl.release("right")
	if cl.velocity.length() < 0.5 or cl.active:
		cl_bad.append("после отпускания скорость %s, держит %s" % [cl.velocity, cl.active])
	# Отталкивание по взгляду добавляется к инерции.
	var fly := cl.release_velocity(Vector3(0, 0, -1))
	if fly.z > -ClimbRes.FORWARD_PUSH * 0.9:
		cl_bad.append("нет отталкивания по взгляду: %s" % fly)
	# Полёт ограничен: сессия 19 дала 21 м/с при каждом отпускании — подтяжка первого кадра уходила
	# в окно скорости, и человека выстреливало со стены.
	var wild := ClimbRes.new()
	wild.grab("right", Vector3(0, 1.5, 0))
	wild.update({"right": Vector3(0, 1.5 + ClimbRes.MAX_STEP_M, 0)}, dt)
	wild.release("right")
	if wild.release_velocity(Vector3(0, 0, -1)).length() > ClimbRes.MAX_FLING_MS + ClimbRes.FORWARD_PUSH + 0.01:
		cl_bad.append("полёт не ограничен: %.1f м/с" % wild.release_velocity(Vector3(0, 0, -1)).length())
	# Ведёт последняя схватившая; отпустил её — ведение возвращается первой.
	var two := ClimbRes.new()
	two.grab("left", Vector3(-0.2, 1.4, 0))
	two.grab("right", Vector3(0.2, 1.4, 0))
	if two.dominant != "right":
		cl_bad.append("ведёт %s вместо последней схватившей" % two.dominant)
	var led := two.update({"left": Vector3(-0.2, 1.4, 1.0), "right": Vector3(0.2, 1.4, 0.3)}, dt)
	if absf(led.z + 0.3) > 0.001:
		cl_bad.append("ведущая рука не ведёт: %s (ждали −0.3 по Z от правой)" % led)
	two.release("right")
	if two.dominant != "left" or not two.active:
		cl_bad.append("после отпускания ведущей ведёт %s, держит %s" % [two.dominant, two.active])
	# Тяга мира «за воздух» обеими руками — среднее: там ведущей руки нет.
	var pull_two := ClimbRes.new()
	pull_two.grab("left", Vector3(-0.2, 1.4, 0), "pull")
	pull_two.grab("right", Vector3(0.2, 1.4, 0), "pull")
	var pull := pull_two.update({"left": Vector3(-0.2, 1.4, 0.1), "right": Vector3(0.2, 1.4, 0.3)}, dt)
	if absf(pull.z + 0.2) > 0.001:
		cl_bad.append("тяга двумя руками: %s (ждали среднее −0.2 по Z)" % pull)
	if cl_bad.is_empty():
		r.pass_("лазанье: точка захвата держится на зацепе, ведёт последняя схватившая рука, срыв дальше %.2f м, при отпускании инерция и отталкивание; тяга мира — среднее по рукам" % ClimbRes.BREAK_M)
	else:
		r.fail("лазанье: %s" % "; ".join(cl_bad))

	# 7. Разбор уровня: версия формата, неизвестный тип и нулевой размер отвергаются; стартовая
	# локация читается и содержит нужное.
	LevelRes.falsify_any = falsify == "levelany"
	var lv_bad: Array[String] = []
	var bad_cases := {
		"не JSON": "[1,2,3]",
		"версия": '{"format": 2, "objects": []}',
		"нет объектов": '{"format": 1}',
		"тип": '{"format": 1, "objects": [{"type": "dragon", "pos": [0,0,0], "size": [1,1,1]}]}',
		"размер": '{"format": 1, "objects": [{"type": "box", "pos": [0,0,0], "size": [1,0,1]}]}',
	}
	for name in bad_cases:
		if LevelRes.parse(bad_cases[name])["ok"]:
			lv_bad.append("принят битый случай «%s»" % name)
	var text := FileAccess.get_file_as_string("res://world/levels/start_location.json")
	var parsed := LevelRes.parse(text)
	if not parsed["ok"]:
		lv_bad.append("стартовая локация: %s" % parsed["error"])
	else:
		var types := {}
		var tags := {}
		for o in parsed["data"]["objects"]:
			types[o["type"]] = int(types.get(o["type"], 0)) + 1
			for t in o.get("tags", []):
				tags[t] = int(tags.get(t, 0)) + 1
		if types.get("spawn", 0) != 1 or types.get("stairs", 0) < 1 or types.get("trigger", 0) < 1 \
				or tags.get("climb", 0) < 3 or tags.get("teleport_target", 0) < 3:
			lv_bad.append("состав локации: типы %s, метки %s" % [types, tags])
	LevelRes.falsify_any = false
	if lv_bad.is_empty():
		r.pass_("разбор уровня: пять битых случаев отвергнуты; стартовая локация читается — точка старта, ступени, триггер, зацепы и цели телепорта на месте")
	else:
		r.fail("разбор уровня: %s" % "; ".join(lv_bad))

	# 8. Подсказка в мире (тип «sign», просьба владельца после сессии 17): билборд с фиксированным
	# местом. Текст обязателен — подсказка без текста это невидимый узел, который молча ничего не
	# делает; положение обязательно, иначе она встанет в нуле мира.
	LevelRes.falsify_any = falsify == "signblind"
	var sign_bad: Array[String] = []
	var good := LevelRes.parse('{"format":1,"objects":[{"uuid":"s1","type":"sign","pos":[1,1.5,2],"text":"Пандус"}]}')
	if not good["ok"]:
		sign_bad.append("правильная подсказка отвергнута: %s" % good["error"])
	for bad in [['{"format":1,"objects":[{"uuid":"s1","type":"sign","pos":[1,1.5,2]}]}', "без текста"],
			['{"format":1,"objects":[{"uuid":"s1","type":"sign","text":"Пандус"}]}', "без положения"]]:
		if LevelRes.parse(bad[0])["ok"]:
			sign_bad.append("принята подсказка %s" % bad[1])
	if good["ok"]:
		var root := Node3D.new()
		LevelRes.build(root, good["data"])
		var lbl := root.get_child(0) as Label3D
		# position, а не global_position: узел вне дерева сцены отдаёт мировое (0,0,0) при любом
		# положении, и проверка краснела бы на верном коде.
		# Группа «sign» — по ней таблички каждый кадр разворачиваются лицом к человеку
		# (world/sign_face.gd); билборда Godot у них нет намеренно (сессия 18).
		if lbl == null or lbl.text != "Пандус" or not lbl.is_in_group("sign") \
				or not lbl.position.is_equal_approx(Vector3(1, 1.5, 2)):
			sign_bad.append("построена не подсказка: %s" % ("нет узла" if lbl == null else
					"«%s», в группе %s, %s" % [lbl.text, lbl.is_in_group("sign"), lbl.position]))
		root.free()
	LevelRes.falsify_any = false
	if sign_bad.is_empty():
		r.pass_("подсказка в мире: текст и положение обязательны, строится на своём месте и попадает в группу разворота")
	else:
		r.fail("подсказка в мире: %s" % "; ".join(sign_bad))

	# 9. Подгрузка и выгрузка по зоне (world/level_stream.gd). Сессия 17: интерьер подгрузился и не
	# выгрузился — body_exited не был подключён нигде. Выгрузка отложенная: шаг через проём
	# туда-обратно не должен давать мигание загрузки.
	var stream: LevelStreamRes = LevelStreamRes.new()
	stream.falsify_never_unload = falsify == "keeploaded"
	var st_bad: Array[String] = []
	var file := "res://world/levels/start_interior.json"
	stream.add(file, [1, 2, 3])
	if not stream.is_loaded(file):
		st_bad.append("файл не считается загруженным")
	# Вышел и сразу вернулся — выгрузки быть не должно вовсе.
	stream.exit(file)
	stream.tick(LevelStreamRes.UNLOAD_DELAY_S * 0.5)
	stream.enter(file)
	if not stream.tick(LevelStreamRes.UNLOAD_DELAY_S * 2.0).is_empty():
		st_bad.append("возвращение не отменило отсчёт")
	# Вышел и не вернулся — выгрузка ровно по истечении задержки, не раньше.
	stream.exit(file)
	if not stream.tick(LevelStreamRes.UNLOAD_DELAY_S * 0.9).is_empty():
		st_bad.append("выгрузил раньше задержки")
	var due := stream.tick(LevelStreamRes.UNLOAD_DELAY_S * 0.2)
	if due != [file]:
		st_bad.append("после задержки к выгрузке %s" % [due])
	if stream.take(file) != [1, 2, 3] or stream.is_loaded(file):
		st_bad.append("узлы не отданы или учёт не очищен")
	# Незагруженный файл отсчёта не заводит.
	stream.exit("res://нет.json")
	if not stream.tick(LevelStreamRes.UNLOAD_DELAY_S * 2.0).is_empty():
		st_bad.append("завёл отсчёт на файл, который не грузился")
	if st_bad.is_empty():
		r.pass_("подгрузка и выгрузка по зоне: возвращение отменяет отсчёт, выгрузка ровно через %.1f с, узлы отданы вызывающему" % LevelStreamRes.UNLOAD_DELAY_S)
	else:
		r.fail("подгрузка и выгрузка по зоне: %s" % "; ".join(st_bad))


# --- журнал сессии ----------------------------------------------------------------

## Строка, записанная до открытия файла, обязана дойти до диска и встать ПЕРЕД более поздними.
## Сессия 15: `_load_level` звал журнал раньше `journal.open()`, запись молча пропадала, и
## отсутствие строки «уровень» выглядело как несостоявшаяся загрузка уровня — при 44 построенных
## объектах. Проверка пишет в свой файл, журнал сессии не трогает.
func _session_checks() -> void:
	var path := "user://test_journal.tsv"
	var abs_path := ProjectSettings.globalize_path(path)
	DirAccess.remove_absolute(abs_path)
	JournalRes.falsify_drop_early = falsify == "nobuffer"
	var j: JournalRes = JournalRes.new()
	j.log("уровень", {"input": "controllers"}, "", "", -1, "start_location.json: узлов 44")
	j.log("комната", {}, "", "", -1, "ранняя вторая")
	var opened: bool = j.open(path)
	j.log("ввод_готов", {}, "", "", -1, "поздняя")
	var text := FileAccess.get_file_as_string(path)
	DirAccess.remove_absolute(abs_path)
	JournalRes.falsify_drop_early = false
	var early := text.contains("узлов 44") and text.contains("ранняя вторая")
	var late := text.contains("поздняя")
	var order := early and late and text.find("узлов 44") < text.find("ранняя вторая") \
			and text.find("ранняя вторая") < text.find("поздняя")
	if opened and early and late and order and j.rows == 3:
		r.pass_("журнал до открытия: две строки до open() дошли до файла в своём порядке, перед поздней; строк %d" % j.rows)
	else:
		r.fail("журнал до открытия: открыт %s, ранние %s, поздняя %s, порядок %s, строк %d" % [
				opened, early, late, order, j.rows])


## Подсказка обязана говорить разное при открытом и закрытом шаре: при открытом — что шар надо
## закрыть, чтобы идти; при закрытом — чем именно идти, с текущими настройками по именам.
## Сессия 16: текст был один на оба состояния, шар простоял открытым 408 с, и перемещение не
## испытали ни разу, хотя все его настройки перебрали.
func _help_text_check() -> void:
	HelpTextRes.falsify_stale = falsify == "helpstale"
	HelpTextRes.falsify_no_crouch = falsify == "crouchquiet"
	var bad: Array = []
	for hands in [false, true]:
		var opened: String = HelpTextRes.text(hands, true, "blink", "snap", 45.0, 90.0)
		var closed: String = HelpTextRes.text(hands, false, "blink", "snap", 45.0, 90.0)
		var close_word: String = "кулак левой" if hands else "Y"
		if not opened.contains("закрыть шар"):
			bad.append("открытый шар (%s) не зовёт закрыть" % ("руки" if hands else "контроллеры"))
		if not opened.contains(close_word):
			bad.append("открытый шар (%s) не называет, чем закрыть" % ("руки" if hands else "контроллеры"))
		if not closed.contains("перемещение") or not closed.contains("телепорт"):
			bad.append("закрытый шар (%s) молчит о перемещении" % ("руки" if hands else "контроллеры"))
		if opened == closed:
			bad.append("текст одинаков в обоих состояниях (%s)" % ("руки" if hands else "контроллеры"))
	# Присед назван в подсказке: сессия 21 — кнопку никто не нашёл, потому что про неё нигде не
	# говорилось (и висела она на нажатии стика).
	if not HelpTextRes.text(false, false, "blink", "snap", 45.0, 90.0).contains("присесть"):
		bad.append("про присед в подсказке не сказано")
	# Настройки названы по имени: способ и угол щелчка меняются в тексте вместе со значением.
	var walk: String = HelpTextRes.text(false, false, "head", "smooth", 45.0, 120.0)
	if not walk.contains("по взгляду") or not walk.contains("120"):
		bad.append("закрытый шар не называет текущие настройки: «%s»" % walk)
	if HelpTextRes.text(false, false, "blink", "snap", 30.0, 90.0).contains("45"):
		bad.append("угол щелчка в тексте не следует за настройкой")
	HelpTextRes.falsify_stale = false
	HelpTextRes.falsify_no_crouch = false
	if bad.is_empty():
		r.pass_("подсказка по состоянию шара: открытый зовёт закрыть (Y и кулак левой), закрытый называет способ и угол — и у рук свой текст")
	else:
		r.fail("подсказка по состоянию шара: %s" % "; ".join(bad))



## Табличка смотрит НА ЧЕЛОВЕКА, а не вдоль его взгляда. Сессия 18: билборд Godot держит надпись
## параллельно плоскости экрана — табличка сбоку оказывалась повёрнутой «как экран», и владелец это
## увидел сразу: «вращаются в соответствии с вращением шлема, а должны всегда смотреть лицевой
## стороной к шлему». Вертикаль при развороте не заваливается.
func _sign_face_check() -> void:
	SignFaceRes.falsify_billboard = falsify == "signbillboard"
	var bad: Array[String] = []
	var at := Vector3(2.0, 1.5, 0.0)
	for head in [Vector3(0, 1.6, 0), Vector3(2.0, 1.6, 5.0), Vector3(-3.0, 1.6, -4.0)]:
		var b := SignFaceRes.basis_towards(at, head)
		# Лицевая сторона Label3D — +Z: она должна указывать на голову по горизонтали.
		var to_head: Vector3 = head - at
		to_head.y = 0.0
		var face := b.z
		if face.angle_to(to_head.normalized()) > deg_to_rad(0.5):
			bad.append("из %s лицо смотрит в %s вместо %s" % [head, face, to_head.normalized()])
		if absf(b.y.dot(Vector3.UP) - 1.0) > 0.001:
			bad.append("вертикаль завалилась: y = %s" % b.y)
	# Наклон головы на табличку не переносится: важна ТОЧКА, а не поза. Голова выше и ниже даёт
	# один и тот же разворот.
	var high := SignFaceRes.basis_towards(at, Vector3(0, 3.0, 0))
	var low := SignFaceRes.basis_towards(at, Vector3(0, 0.2, 0))
	if not high.z.is_equal_approx(low.z):
		bad.append("высота головы меняет разворот: %s против %s" % [high.z, low.z])
	# Разворачиваются все узлы группы и только живые.
	var signs: Array = []
	for i in 3:
		var n := Node3D.new()
		n.position = Vector3(float(i), 1.5, 0.0)
		signs.append(n)
	var faced := SignFaceRes.face_all(signs, Vector3(0, 1.6, 5.0))
	if faced != 3:
		bad.append("развёрнуто %d табличек из 3" % faced)
	for n in signs:
		(n as Node3D).free()
	SignFaceRes.falsify_billboard = false
	if bad.is_empty():
		r.pass_("подсказка смотрит на человека: лицо направлено в точку головы с любой стороны, вертикаль держится, наклон головы разворот не меняет")
	else:
		r.fail("подсказка смотрит на человека: %s" % "; ".join(bad))


## Призыв предмета — «гравиперчатки» (HL:A). Цель берётся узким конусом вокруг оси ладони, рывком
## считается только быстрое движение кисти К СЕБЕ, предмет летит по дуге и приходит точно в ладонь.
func _pull_checks() -> void:
	PullRes.falsify_wide = falsify == "pullwide"
	PullRes.falsify_any_flick = falsify == "pullflick"
	var bad: Array[String] = []
	var places := [Vector3(0, 1.2, -3.0), Vector3(1.5, 1.2, -3.0), Vector3(0, 1.2, -20.0)]
	var hand := Vector3(0, 1.4, 0)
	var aim := PullRes.target_index(places, hand, Vector3(0, -0.07, -1.0))
	if aim != 0:
		bad.append("наведение взяло предмет %d вместо того, на который навели" % aim)
	# Предмет в 27° от оси — мимо конуса; предмет за дальностью — тоже мимо.
	if PullRes.target_index([places[1]], hand, Vector3(0, -0.07, -1.0)) >= 0:
		bad.append("предмет вне конуса всё равно взят")
	if PullRes.target_index([places[2]], hand, Vector3(0, -0.01, -1.0)) >= 0:
		bad.append("предмет за дальностью %.0f м всё равно взят" % PullRes.RANGE_M)
	# Рывок: к себе быстро — да; к себе медленно и от себя быстро — нет.
	var to_head := Vector3(0, 0.2, 1.0)
	var quick := to_head.normalized() * (PullRes.FLICK_SPEED * 2.0)
	var slow := to_head.normalized() * (PullRes.FLICK_SPEED * 0.3)
	if not PullRes.is_flick(quick, to_head):
		bad.append("быстрый рывок к себе не распознан")
	if PullRes.is_flick(slow, to_head) or PullRes.is_flick(-quick, to_head):
		bad.append("медленное или обратное движение принято за рывок")
	# Полёт: начало и конец точные, середина поднята дугой.
	var from := Vector3(0, 0.1, -3.0)
	var to := Vector3(0, 1.4, 0.0)
	if not PullRes.fly_point(from, to, 0.0).is_equal_approx(from) or not PullRes.fly_point(from, to, 1.0).is_equal_approx(to):
		bad.append("полёт не начинается и не кончается в точке")
	var mid := PullRes.fly_point(from, to, 0.5)
	if mid.y <= from.lerp(to, 0.5).y + 0.05:
		bad.append("дуга не поднимается: середина %s" % mid)
	PullRes.falsify_wide = false
	PullRes.falsify_any_flick = false
	# Нить от ладони к предмету: провисает, начинается и кончается точно (сессия 20 — видимой связи
	# не было вовсе, и какая рука держит цель, понять было нельзя).
	var thread := PullRes.thread(Vector3(0, 1.2, 0), Vector3(0, 1.2, -3.0))
	if thread.size() < 6:
		bad.append("нить из %d точек" % thread.size())
	elif not thread[0].is_equal_approx(Vector3(0, 1.2, 0)) or not thread[thread.size() - 1].is_equal_approx(Vector3(0, 1.2, -3.0)):
		bad.append("нить не привязана к концам: %s → %s" % [thread[0], thread[thread.size() - 1]])
	else:
		var sag: float = 1.2 - thread[thread.size() / 2].y
		if sag < 0.05 or sag > 0.5:
			bad.append("провисание %.2f м — нить прямая или лежит на полу" % sag)
	if bad.is_empty():
		r.pass_("призыв предмета: конус %.0f° выбирает наведённое, дальше %.0f м не берёт, рывком считается только движение к себе быстрее %.1f м/с, полёт идёт дугой в ладонь, нить провисает" % [
				PullRes.CONE_DEG, PullRes.RANGE_M, PullRes.FLICK_SPEED])
	else:
		r.fail("призыв предмета: %s" % "; ".join(bad))


## Курс при телепорте: пока целишься дугой, стик вбок задаёт, куда смотреть после переноса
## (HL:A, «orientation on teleport» у Meta). Сессия 20: отклонение стика крутило человека НА МЕСТЕ,
## потому что поворот не знал о прицеливании, а сам угол был всегда ровно ±90°.
func _teleport_extras_check() -> void:
	var bad: Array[String] = []
	# Прореживание дуги не изменило её форму: 12 сегментов при вдвое большем шаге дают ту же
	# траекторию, что 24. Иначе «стало дешевле» означало бы «стало другое» (сессия 25).
	TeleportRes.falsify_step_sum = falsify == "arcstep"
	TeleportRes.falsify_fine_arc = false
	var coarse := TeleportRes.arc(Vector3(0, 1.4, 0), Vector3(0, -0.2, -1).normalized(), 8.0)
	TeleportRes.falsify_fine_arc = true
	var fine := TeleportRes.arc(Vector3(0, 1.4, 0), Vector3(0, -0.2, -1).normalized(), 8.0)
	TeleportRes.falsify_fine_arc = false
	TeleportRes.falsify_step_sum = false
	var tail_gap: float = coarse[coarse.size() - 1].distance_to(fine[fine.size() - 1])
	if tail_gap > 0.05:
		bad.append("дуга изменила форму: конец разошёлся на %.2f м" % tail_gap)
	# Сравнивать надо точки одного ВРЕМЕНИ, а не одного номера: шаг вдвое крупнее, значит точке k
	# грубой дуги соответствует точка 2k мелкой. Сравнение по номеру сравнивало бы разные места.
	var mid_gap := 0.0
	for k in coarse.size():
		if k * 2 >= fine.size():
			break
		mid_gap = maxf(mid_gap, coarse[k].distance_to(fine[k * 2]))
	if mid_gap > 0.05:
		bad.append("дуга изменила форму: точки одного времени разошлись на %.2f м" % mid_gap)
	# Линия гуще лучей: точки — арифметика, запросы к физике — нет. Форма при этом та же.
	TeleportRes.falsify_coarse_line = falsify == "arccoarse"
	var line := TeleportRes.arc_line(Vector3(0, 1.4, 0), Vector3(0, -0.2, -1).normalized(), 8.0)
	if line.size() < coarse.size() * 2 - 2:
		bad.append("линия не гуще лучей: %d точек против %d" % [line.size(), coarse.size()])
	# Точки, совпадающие по времени, должны лежать там же — гладкость не меняет траекторию.
	var line_gap := 0.0
	for k in coarse.size():
		if k * TeleportRes.DRAW_SUBDIV >= line.size():
			break
		line_gap = maxf(line_gap, coarse[k].distance_to(line[k * TeleportRes.DRAW_SUBDIV]))
	if line_gap > 0.01:
		bad.append("линия ушла с дуги на %.3f м" % line_gap)
	TeleportRes.falsify_coarse_line = false
	# Мёртвая зона: лёгкое касание стика курс не задаёт — человек смотрит туда же, куда смотрел.
	if not is_nan(TeleportRes.aim_yaw(TeleportRes.AIM_DEADZONE * 0.9, 30.0)):
		bad.append("касание стика в мёртвой зоне уже задаёт курс")
	# Угол пропорционален отклонению: до предела на краю и вдвое меньше на середине хода.
	var full := TeleportRes.aim_yaw(1.0, 30.0)
	var half := TeleportRes.aim_yaw((1.0 + TeleportRes.AIM_DEADZONE) * 0.5, 30.0)
	if not is_equal_approx(full, 30.0 + TeleportRes.MAX_AIM_TURN):
		bad.append("полное отклонение даёт %.0f вместо %.0f" % [full, 30.0 + TeleportRes.MAX_AIM_TURN])
	if absf(half - (30.0 + TeleportRes.MAX_AIM_TURN * 0.5)) > 1.0:
		bad.append("половина хода даёт %.0f вместо %.0f" % [half, 30.0 + TeleportRes.MAX_AIM_TURN * 0.5])
	# Влево — в другую сторону, на тот же угол.
	if not is_equal_approx(TeleportRes.aim_yaw(-1.0, 0.0), -TeleportRes.MAX_AIM_TURN):
		bad.append("влево курс не зеркален: %.0f" % TeleportRes.aim_yaw(-1.0, 0.0))
	# Курс считается ОТ взгляда: та же ручка при другом повороте головы даёт другой курс.
	if is_equal_approx(TeleportRes.aim_yaw(1.0, 0.0), TeleportRes.aim_yaw(1.0, 90.0)):
		bad.append("курс не зависит от того, куда смотрит человек")
	if bad.is_empty():
		r.pass_("курс при телепорте: мёртвая зона %.2f, угол пропорционален отклонению до %.0f°, считается от взгляда; дуга из %d сегментов совпадает с прежней из %d (конец %.3f м, худшая точка %.3f м)" % [
				TeleportRes.AIM_DEADZONE, TeleportRes.MAX_AIM_TURN, TeleportRes.STEPS, TeleportRes.STEPS_FINE,
				tail_gap, mid_gap])
	else:
		r.fail("курс при телепорте: %s" % "; ".join(bad))


## Присед кнопкой и виньетка «по ускорению». Присев, человек становится ниже — и капсула тоже,
## иначе он упрётся макушкой в то, подо что заглядывает. Виньетка «по ускорению» (рекомендация Meta)
## темнеет только на разгоне и торможении: на ровном ходу край чист, и сцену видно.
func _crouch_vignette_check() -> void:
	var bad: Array[String] = []
	var body: PlayerBodyRes = PlayerBodyRes.new()
	var origin := XROrigin3D.new()
	var head_node := Node3D.new()
	root.add_child(body)
	body.add_child(origin)
	origin.add_child(head_node)
	head_node.position = Vector3(0, 1.6, 0)
	body.setup(origin, head_node)
	body.set_eye_height(1.6)
	var tall := body.capsule.height
	body.set_crouch(0.5 if falsify != "crouchtall" else 0.0)
	if body.capsule.height > tall - 0.45:
		bad.append("капсула не укоротилась: %.2f при росте %.2f" % [body.capsule.height, tall])
	if absf(origin.position.y + 0.5) > 0.001 and falsify != "crouchtall":
		bad.append("взгляд не опустился: origin.y = %.2f" % origin.position.y)
	body.set_crouch(0.0)
	if absf(body.capsule.height - tall) > 0.001 or absf(origin.position.y) > 0.001:
		bad.append("встать обратно не получилось: высота %.2f, origin.y %.2f" % [body.capsule.height, origin.position.y])
	root.remove_child(body)
	body.free()

	VignetteRes.falsify_speed_not_accel = falsify == "vigspeed"
	var vg: VignetteRes = VignetteRes.new()
	var dt := 1.0 / 90.0
	# Разгон с нуля до скорости ходьбы за кадр — виньетка должна появиться...
	vg.update(0.0, 0.0, "accel", dt)
	var on_accel := vg.update(1.4, 0.0, "accel", dt)
	# ...а на ровном ходу (скорость та же кадр за кадром) — уйти.
	var steady := on_accel
	for i in 40:
		steady = vg.update(1.4, 0.0, "accel", dt)
	if on_accel < 0.05:
		bad.append("на разгоне виньетка не появилась: %.2f" % on_accel)
	if steady > 0.05:
		bad.append("на ровном ходу виньетка не ушла: %.2f" % steady)
	VignetteRes.falsify_speed_not_accel = false
	if bad.is_empty():
		r.pass_("присед и виньетка по ускорению: присед на 0.5 м опускает взгляд и укорачивает капсулу, встать возвращает; «по ускорению» темнеет на разгоне (%.2f) и чиста на ровном ходу (%.2f)" % [on_accel, steady])
	else:
		r.fail("присед и виньетка по ускорению: %s" % "; ".join(bad))


## Перевал через край — Assisted Mantle. Сессия 21: до верха стены владелец так и не перевалился
## («забрался наверх при помощи телепорта»), потому что прежний порог требовал поднять глаза на
## 15 см выше кромки — при верхнем зацепе на 3.2 и кромке на 3.4 это значит подтянуться почти на
## полный рост.
func _mantle_check() -> void:
	MantleRes.falsify_any = falsify == "mantleany"
	MantleRes.falsify_ease = falsify == "mantleease"
	MantleRes.falsify_eager = falsify == "mantleeager"
	var bad: Array[String] = []
	# Годится: горизонтальная площадка ниже головы. Не годится: выше головы, вровень, наклонная.
	if not MantleRes.fits(3.5, 3.0, Vector3.UP):
		bad.append("не берёт площадку под головой")
	if MantleRes.fits(3.0, 3.5, Vector3.UP):
		bad.append("берёт площадку ВЫШЕ головы")
	if MantleRes.fits(3.5, 3.0, Vector3(0.8, 0.6, 0).normalized()):
		bad.append("берёт наклонную поверхность")
	# Намерение: высота обязательна, а дальше — рывок ИЛИ удержание.
	var above := 3.4 + MantleRes.HEAD_ABOVE_M + 0.02
	if MantleRes.intent(3.40, 3.4, -1.0, 1.0):
		bad.append("перевал начинается, когда глаза на уровне кромки")
	if MantleRes.intent(above, 3.4, 0.0, MantleRes.INTENT_HOLD_S * 0.5):
		bad.append("перевал начинается без рывка и без удержания")
	if not MantleRes.intent(above, 3.4, -MantleRes.FLICK_DOWN_MS * 1.5, 0.0):
		bad.append("рывок рукой вниз не запускает перевал")
	if not MantleRes.intent(above, 3.4, 0.0, MantleRes.INTENT_HOLD_S + 0.01):
		bad.append("удержание у кромки не запускает перевал")
	# Траектория: строго линейно и в два этапа. Ускорение камеры в VR запрещено (схема владельца).
	var from := Vector3(0, 1.0, 0)
	var to := Vector3(0, 3.4, -1.0)
	var step := 0.05
	var ups: Array[float] = []
	var fwds: Array[float] = []
	var prev := MantleRes.rise_point(from, to, 0.0)
	var k := step
	while k <= 1.0001:
		var p := MantleRes.rise_point(from, to, k)
		# На подъёме высота только растёт; на выносе допустимо снижение на запас CLEAR_M — это
		# ноги опускаются на площадку, пройдя кромку.
		var allow: float = 0.001 if k <= MantleRes.UP_PART else MantleRes.CLEAR_M + 0.001
		if p.y < prev.y - allow:
			bad.append("высота убывает на t = %.2f" % k)
			break
		# Внутри своего этапа шаг постоянный: копим шаги подъёма и шаги выноса отдельно.
		if k <= MantleRes.UP_PART:
			ups.append(p.y - prev.y)
		elif k > MantleRes.UP_PART + 0.06:
			# Первый шаг после смены этапа сравнивать не с чем: он захватывает конец подъёма.
			fwds.append(absf(p.z - prev.z))
		prev = p
		k += step
	for pair in [["подъём", ups], ["вынос", fwds]]:
		var arr: Array[float] = pair[1]
		if arr.size() < 3:
			bad.append("%s: шагов %d — этап слишком короткий" % [pair[0], arr.size()])
			continue
		var lo: float = arr.min()
		var hi: float = arr.max()
		if hi > lo * 1.05 + 0.0005:
			bad.append("%s идёт с ускорением: шаг от %.4f до %.4f" % [pair[0], lo, hi])
	if not MantleRes.rise_point(from, to, 1.0).is_equal_approx(to):
		bad.append("конец траектории не в точке приземления")
	# Длительность — в окне комфорта 0.2…0.4 с.
	if MantleRes.RISE_S < 0.2 or MantleRes.RISE_S > 0.4:
		bad.append("перенос длится %.2f с — вне окна 0.2…0.4" % MantleRes.RISE_S)
	MantleRes.falsify_any = false
	MantleRes.falsify_ease = false
	MantleRes.falsify_eager = false
	if bad.is_empty():
		r.pass_("перевал через край: намерение — глаза выше кромки на %.2f м плюс рывок или удержание %.2f с; перенос %.2f с строго линейный, сначала вверх, потом вперёд" % [
				MantleRes.HEAD_ABOVE_M, MantleRes.INTENT_HOLD_S, MantleRes.RISE_S])
	else:
		r.fail("перевал через край: %s" % "; ".join(bad))


## Кромка в данных уровня (тип «ledge»): зона захвата и ТОЧКА ПРИЗЕМЛЕНИЯ. Без неё зона бесполезна —
## человека некуда ставить, поэтому это отказ разбора, а не умолчание.
func _ledge_check() -> void:
	LevelRes.falsify_any = falsify == "ledgeany"
	var bad: Array[String] = []
	var good := LevelRes.parse('{"format":1,"objects":[{"uuid":"l1","type":"ledge","pos":[4.5,3.4,-4.6],"size":[3,0.5,0.6],"target":[4.5,3.4,-5.4]}]}')
	if not good["ok"]:
		bad.append("правильная кромка отвергнута: %s" % good["error"])
	for case in [['{"format":1,"objects":[{"uuid":"l1","type":"ledge","pos":[0,3,0],"size":[3,0.5,0.6]}]}', "без точки приземления"],
			['{"format":1,"objects":[{"uuid":"l1","type":"ledge","size":[3,0.5,0.6],"target":[0,3,-1]}]}', "без положения"],
			['{"format":1,"objects":[{"uuid":"l1","type":"ledge","pos":[0,3,0],"size":[3,0,0.6],"target":[0,3,-1]}]}', "с нулевым размером"]]:
		if LevelRes.parse(case[0])["ok"]:
			bad.append("принята кромка %s" % case[1])
	if good["ok"]:
		var root := Node3D.new()
		LevelRes.build(root, good["data"])
		var area := root.get_child(0) as Area3D
		if area == null or not area.is_in_group("ledge"):
			bad.append("кромка построена не зоной или не в группе")
		elif not (area.get_meta("target") as Vector3).is_equal_approx(Vector3(4.5, 3.4, -5.4)):
			bad.append("точка приземления потерялась: %s" % area.get_meta("target"))
		root.free()
	LevelRes.falsify_any = false
	if bad.is_empty():
		r.pass_("кромка в данных: зона строится с точкой приземления в метаданных; без target, положения или размера — отказ разбора")
	else:
		r.fail("кромка в данных: %s" % "; ".join(bad))





## У каждого пункта-действия есть адресат. Навигатор рассылает действия ПО ПРЕФИКСУ
## (`profile_*`, `space_*`) плюс несколько имён разбирает сам; всё прочее уходит в `{"do": "none"}`
## и молча не делает ничего. Сессии 18–20: пункт «Вернуться в стартовую точку» назывался `respawn`,
## не подходил ни под один префикс, и в журнале нет ни одного возврата из меню — при том, что
## обработчик был на месте.
func _menu_actions_check() -> void:
	var known := ["wizard", "search", "pick", "exit"]
	var prefixes := ["profile_", "space_"]
	var cat := Catalog.new()
	var bad: Array[String] = []
	var seen := 0
	for id in cat.items:
		var it: Item = cat.items[id]
		if it.kind != Item.Kind.ACTION or it.action == "":
			continue
		seen += 1
		var name: String = it.action
		if falsify == "actionorphan" and id == "move_respawn":
			name = "respawn"
		var ok := name in known
		for p in prefixes:
			if name.begins_with(p):
				ok = true
		if not ok:
			bad.append("«%s» (%s) никому не адресовано" % [it.title, name])
	if seen < 5:
		bad.append("пунктов-действий найдено всего %d — каталог не построился" % seen)
	if bad.is_empty():
		r.pass_("действия меню адресованы: все %d пунктов-действий попадают навигатору — по имени или по префиксу" % seen)
	else:
		r.fail("действия меню адресованы: %s" % "; ".join(bad))


## Столкновения, снятые на время перевала, возвращаются САМИ, чем бы перенос ни кончился.
## Сессия 24: после перевала маска осталась нулевой, тело провалилось сквозь пол, и человек уехал
## на −2.44 м — «ушёл вниз, глаза на уровне пола». Возврат в стартовую точку это вылечил, но сам
## провал не должен был случиться.
func _collision_guard_check() -> void:
	var bad: Array[String] = []
	var body: PlayerBodyRes = PlayerBodyRes.new()
	var origin := XROrigin3D.new()
	var head_node := Node3D.new()
	root.add_child(body)
	body.add_child(origin)
	origin.add_child(head_node)
	head_node.position = Vector3(0, 1.6, 0)
	body.setup(origin, head_node)
	var mask := body.collision_mask
	if mask == 0:
		bad.append("у тела изначально нет маски столкновений — проверять нечего")
	body.hold_collisions()
	if body.collision_mask != 0:
		bad.append("маска не снялась на время перевала")
	# Перенос «прервался»: перевал больше не идёт, а release никто не позвал.
	body.mantling = false
	body._physics_process(1.0 / 60.0)
	if body.collision_mask != mask:
		bad.append("маска не вернулась сама: %d вместо %d" % [body.collision_mask, mask])
	# И ТО ЖЕ САМОЕ, пока человек лезет. Ранний выход ветки лазанья унёс с собой страховку, и маска
	# оставалась нулевой: человек проваливался сквозь пол сразу после возврата в стартовую точку,
	# четыре раза подряд (сессия 32). Страховка обязана стоять до любых ранних выходов.
	PlayerBodyRes.falsify_guard_late = falsify == "maskclimb"
	body.climbing = func() -> bool: return true
	body.hold_collisions()
	body.mantling = false
	body._physics_process(1.0 / 60.0)
	if body.collision_mask != mask:
		bad.append("во время лазанья маска не вернулась: %d вместо %d" % [body.collision_mask, mask])
	body.climbing = func() -> bool: return false
	PlayerBodyRes.falsify_guard_late = false
	# Повторное снятие и возврат не портят запомненное значение.
	body.hold_collisions()
	body.hold_collisions()
	body.release_collisions()
	if body.collision_mask != mask:
		bad.append("двойное снятие потеряло маску: %d вместо %d" % [body.collision_mask, mask])
	root.remove_child(body)
	body.free()
	if bad.is_empty():
		r.pass_("столкновения возвращаются сами: снятая на перевал маска восстанавливается первым же тактом после переноса — в том числе пока человек лезет; двойное снятие её не теряет")
	else:
		r.fail("столкновения возвращаются сами: %s" % "; ".join(bad))


## Кадр не делает лишней работы. Сессия 24: CPU+скрипты 6.40 мс против 2.92 в сессиях 18 и 20.
## Виновники были названы поимённо — разворот восьми табличек с записью `global_basis` каждый кадр
## и нить призыва, пересоздающая `ImmediateMesh` вместе с массивом точек. Здесь проверяется не
## время (его мерит прибор на шлеме), а сам факт: работа делается, только когда что-то сдвинулось.
func _frame_work_check() -> void:
	SignFaceRes.falsify_every_frame = falsify == "signevery"
	PullViewRes.falsify_every_frame = falsify == "pullevery"
	var bad: Array[String] = []
	# Таблички: первый кадр разворачивает, стоячие кадры — нет, сдвиг головы — снова да.
	var signs: Array = []
	for i in 8:
		var n := Node3D.new()
		n.position = Vector3(float(i), 1.5, 0.0)
		signs.append(n)
	SignFaceRes.forget()
	var head := Vector3(0, 1.6, 3.0)
	var first := SignFaceRes.face_all(signs, head)
	var still := SignFaceRes.face_all(signs, head)
	var tiny := SignFaceRes.face_all(signs, head + Vector3(SignFaceRes.HEAD_EPS * 0.4, 0, 0))
	var moved := SignFaceRes.face_all(signs, head + Vector3(0.5, 0, 0))
	if first != 8:
		bad.append("первый кадр развернул %d табличек из 8" % first)
	if still != 0 or tiny != 0:
		bad.append("стоящая голова всё равно крутит таблички: %d и %d" % [still, tiny])
	if moved != 8:
		bad.append("после шага головы таблички не развернулись: %d" % moved)
	for n in signs:
		(n as Node3D).free()
	# Нить: меш переиспользуется, а не создаётся заново на каждый кадр.
	var view: PullViewRes = PullViewRes.new()
	var holder := Node3D.new()
	root.add_child(holder)
	view.setup(holder)
	var target := MeshInstance3D.new()
	holder.add_child(target)
	target.position = Vector3(0, 1.2, -2.0)
	view.show_link("right", target, Vector3(0.2, 1.3, 0), false)
	var line: MeshInstance3D = null
	for ch in holder.get_children():
		if ch != target and ch is MeshInstance3D:
			line = ch
	if line == null:
		bad.append("нить не построилась")
	else:
		var mesh_first: Mesh = line.mesh
		view.show_link("right", target, Vector3(0.2, 1.3, 0), false)
		view.show_link("right", target, Vector3(0.2, 1.3, 0), false)
		if line.mesh != mesh_first:
			bad.append("нить пересоздаёт меш на стоячей руке")
		view.show_link("right", target, Vector3(0.5, 1.3, 0), false)
		if line.mesh != mesh_first:
			bad.append("нить пересоздаёт меш вместо перестройки поверхностей")
	view.hide_all()
	root.remove_child(holder)
	holder.free()
	SignFaceRes.falsify_every_frame = false
	PullViewRes.falsify_every_frame = false
	if bad.is_empty():
		r.pass_("кадр: лишняя работа — таблички разворачиваются только после шага головы на %.2f м, нить перестраивает поверхности одного меша" % SignFaceRes.HEAD_EPS)
	else:
		r.fail("кадр: лишняя работа — %s" % "; ".join(bad))


## Слои: биты, маска камеры и отказ на неизвестном имени. Слой — это «кому видно», в отличие от
## тегов, которые говорят «что объект умеет».
func _layers_check() -> void:
	LayersRes.falsify_any = falsify == "layerany"
	var bad: Array[String] = []
	if LayersRes.bit("game") != 1 or LayersRes.bit("editor") != 2 or LayersRes.bit("debug") != 4:
		bad.append("биты: %d, %d, %d" % [LayersRes.bit("game"), LayersRes.bit("editor"), LayersRes.bit("debug")])
	# Бит игры включён всегда: на нём живёт всё неразмеченное — меню, руки, панели.
	if LayersRes.mask({}) != 1:
		bad.append("при всех скрытых слоях маска %d, а игра обязана остаться" % LayersRes.mask({}))
	if LayersRes.mask({"editor": true, "debug": true}) != 7:
		bad.append("все слои дают маску %d вместо 7" % LayersRes.mask({"editor": true, "debug": true}))
	if LayersRes.mask({"editor": true}) != 3:
		bad.append("редактор без отладки даёт %d вместо 3" % LayersRes.mask({"editor": true}))
	if LayersRes.play_mask() != 1:
		bad.append("в режиме игры маска %d — игрок видел бы инструментарий" % LayersRes.play_mask())
	# Умолчание и отказ.
	if LayersRes.of({}) != "game":
		bad.append("объект без слоя не попал в игру")
	if LayersRes.of({"layer": "debug"}) != "debug":
		bad.append("слой из данных не прочитан")
	if LayersRes.check({"layer": "editor"}) != "":
		bad.append("правильный слой отвергнут")
	var err := LayersRes.check({"layer": "полный", "uuid": "obj1"})
	if err == "" or not err.contains("obj1"):
		bad.append("неизвестный слой принят или отказ без имени объекта: «%s»" % err)
	LayersRes.falsify_any = false
	if bad.is_empty():
		r.pass_("слои объектов: биты 1/2/4, бит игры в маске всегда, режим игры оставляет только его; неизвестное имя — отказ разбора с именем объекта")
	else:
		r.fail("слои объектов: %s" % "; ".join(bad))


## Видимость: объект скрыт, если скрыт сам ИЛИ скрыта любая его группа. «Любая» — потому что
## скрытие это запрет: спрятал «пивоты» — пивот не должен всплывать оттого, что он ещё и «реквизит».
func _visibility_check() -> void:
	var bad: Array[String] = []
	var vis: VisibilityRes = VisibilityRes.new()
	vis.falsify_group_or = falsify == "grouporany"
	vis.register({"uuid": "cube", "layer": "game", "groups": ["реквизит", "пивоты"]})
	vis.register({"uuid": "lone", "layer": "game", "groups": []})
	vis.register({"uuid": "zone", "layer": "debug", "groups": ["пивоты"]})
	if not vis.is_visible("cube") or not vis.is_visible("lone"):
		bad.append("без скрытий что-то уже не видно")
	vis.group_on["пивоты"] = false
	if vis.is_visible("cube"):
		bad.append("объект виден, хотя одна из его групп скрыта")
	if not vis.is_visible("lone"):
		bad.append("объект без групп пострадал от чужого скрытия")
	vis.group_on["пивоты"] = true
	vis.object_on["lone"] = false
	if vis.is_visible("lone"):
		bad.append("скрытый поимённо объект всё равно виден")
	# Список групп — по разу и по алфавиту.
	var names := vis.group_names()
	if names != ["пивоты", "реквизит"]:
		bad.append("группы уровня: %s" % [names])
	vis.forget(["zone"])
	if vis.group_names().size() != 2:
		bad.append("после выгрузки объекта группы посчитаны неверно")
	if bad.is_empty():
		r.pass_("видимость групп: скрыта любая группа — скрыт и объект; своё скрытие независимо; список групп собирается из уровня без повторов")
	else:
		r.fail("видимость групп: %s" % "; ".join(bad))


## Режим игры: показать игроку только игровое, а на выходе вернуть ровно то, что было — включая
## объекты, скрытые поимённо до запуска.
func _play_mode_check() -> void:
	var bad: Array[String] = []
	var vis: VisibilityRes = VisibilityRes.new()
	vis.falsify_snapshot_ref = falsify == "snapshotref"
	vis.register({"uuid": "prop", "layer": "game", "groups": ["реквизит"]})
	vis.register({"uuid": "gizmo", "layer": "editor", "groups": []})
	# Автор спрятал реквизит и группу до запуска.
	vis.object_on["prop"] = false
	vis.group_on["реквизит"] = false
	vis.layer_on["debug"] = true
	var snap := vis.enter_play()
	if vis.camera_mask() != LayersRes.play_mask():
		bad.append("в режиме игры маска %d" % vis.camera_mask())
	if not vis.is_visible("prop"):
		bad.append("игрок не видит игровой объект, спрятанный автором")
	# В режиме игры что-то поменяли — выход обязан это отменить.
	vis.group_on["реквизит"] = true
	vis.object_on["gizmo"] = false
	vis.layer_on["editor"] = false
	vis.exit_play(snap)
	if vis.playing:
		bad.append("режим игры не выключился")
	if vis.is_visible("prop"):
		bad.append("после выхода не вернулось скрытие объекта")
	if bool(vis.group_on.get("реквизит", true)):
		bad.append("после выхода не вернулось скрытие группы")
	if not bool(vis.layer_on.get("editor", false)) or not bool(vis.layer_on.get("debug", false)):
		bad.append("после выхода не вернулись слои: %s" % [vis.layer_on])
	if bad.is_empty():
		r.pass_("снимок режима игры: игрок видит только игровое, выход возвращает слои, группы и поимённые скрытия ровно как было")
	else:
		r.fail("снимок режима игры: %s" % "; ".join(bad))


## Прибор связности: на заведомо битом уровне он обязан назвать КАЖДЫЙ дефект поимённо.
## Контрольный случай тут главнее реального уровня: ошибка исполнения в GDScript возвращает пустой
## список, и «уровень связен» становится неотличимо от «проверка не работала» (так и случилось
## 2026-09-22: `bool("")` оборвал разбор, и 30 замечаний превратились в ноль).
func _level_join_check() -> void:
	LevelCheck.falsify_blind = falsify == "joinblind"
	var broken := {"format": 1, "objects": [
		{"uuid": "floor", "type": "box", "pos": [0, -0.1, 0], "size": [40, 0.2, 40]},
		# Висит: под ним пусто.
		{"uuid": "shelf", "type": "box", "pos": [5, 2.0, 0], "size": [2, 0.2, 2]},
		# Врезка: столб наполовину в стене.
		{"uuid": "wall", "type": "box", "pos": [0, 1.0, -5], "size": [4, 2, 0.4]},
		{"uuid": "post", "type": "box", "pos": [0, 1.0, -5.1], "size": [0.3, 2, 0.3]},
		# За краем пола.
		{"uuid": "far", "type": "box", "pos": [30, 0.5, 0], "size": [2, 1, 2]},
		# Подъём, не дотянувшийся до площадки.
		{"uuid": "plat", "type": "box", "pos": [-6, 0.5, -3], "size": [3, 1, 3]},
		{"uuid": "ramp", "type": "box", "pos": [-6, 0.3, 0], "size": [3, 0.2, 3],
				"leads_to": "plat"},
		# Кромка, роняющая человека в воздух.
		{"uuid": "edge", "type": "ledge", "pos": [-6, 1.0, -1.6], "size": [1, 0.5, 1],
				"target": [-6, 9.0, -3]},
		# Зацеп, до которого не дотянуться.
		{"uuid": "h0", "type": "box", "pos": [3, 0.6, -5], "size": [0.4, 0.1, 0.1],
				"tags": ["climb"], "mounted_on": "wall"},
		{"uuid": "h1", "type": "box", "pos": [3, 2.4, -5], "size": [0.4, 0.1, 0.1],
				"tags": ["climb"], "mounted_on": "wall"},
		# Старт внутри стены.
		{"uuid": "spawn", "type": "spawn", "pos": [0, 0, -5]},
	]}
	var notes: Array = LevelCheck.run(broken)
	var text := "\n".join(PackedStringArray(notes))
	# Ищем по тому, КАК прибор называет дефект: замечание о старте называет стену, в которую он
	# попал, а не сам старт.
	var want := {"висит в воздухе": "shelf", "врезаны": "post", "за край пола": "far",
			"расхождение": "ramp", "не лежит ни на одной площадке": "edge",
			"не дотянется": "h1", "точка старта внутри": "wall"}
	var missed: Array[String] = []
	for phrase in want:
		if not (text.contains(phrase) and text.contains(str(want[phrase]))):
			missed.append(str(want[phrase]))
	# И обратная сторона: верные конструкции молчат.
	var good := {"format": 1, "objects": [
		{"uuid": "floor", "type": "box", "pos": [0, -0.1, 0], "size": [40, 0.2, 40]},
		{"uuid": "legs", "type": "box", "pos": [0, 0.33, 0], "size": [0.1, 0.66, 0.1],
				"join": ["top"]},
		{"uuid": "top", "type": "box", "pos": [0, 0.7, 0], "size": [1, 0.08, 1], "join": ["legs"]},
	]}
	var noise: Array = LevelCheck.run(good)
	LevelCheck.falsify_blind = false
	if missed.is_empty() and noise.is_empty() and notes.size() >= want.size():
		r.pass_("связность уровня: прибор назвал все %d дефекта поимённо (висит, врезка, за краем, недобор высоты, кромка в воздух, недосягаемый зацеп, старт в стене) и промолчал на верном столе" % want.size())
	else:
		r.fail("связность уровня: не названы %s, ложных замечаний %d (%s), всего %d" % [
				missed, noise.size(), noise, notes.size()])


## Сами данные уровня: улица и её интерьер обязаны быть связны — это проверка не кода, а сцены.
func _level_real_check() -> void:
	var bad: Array[String] = []
	var total := 0
	for path in ["res://world/levels/start_location.json", "res://world/levels/start_interior.json"]:
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not data is Dictionary:
			bad.append("%s не читается" % path)
			continue
		var notes: Array = LevelCheck.run(data)
		total += (data["objects"] as Array).size()
		for n in notes:
			bad.append("%s: %s" % [path.get_file(), n])
	if bad.is_empty():
		r.pass_("уровень улицы связен: %d объектов в двух файлах, ни одного висящего, врезанного, недотянутого или выпавшего за край" % total)
	else:
		r.fail("уровень улицы: %s" % "; ".join(bad))


## Поворот главнее движения, когда обе механики читают ОДИН стик (решение владельца 2026-09-22).
##
## Прежнее правило глушило «преобладающую ось» по отношению 1.6 и молчало на целом секторе: при
## (0.8, 0.5) отношение ровно 1.6, при (0.7, 0.7) — единица, и в обоих случаях срабатывали сразу
## поворот и ход. Пороги механик при этом разные (поворот 0.6, ход 0.15), поэтому отношение осей их
## не разводило вовсе — «при вращении стиком так же работает движение» (сессия 31).
##
## Здесь проверяется чистая арифметика правила, без узлов и настроек.
func _turn_first_check() -> void:
	var bad: Array[String] = []
	# [отклонение, один ли стик, ждём ли ход]
	var cases := [
		[Vector2(0.9, 0.25), true, false],   # крутит вбок, палец задевает вертикаль
		[Vector2(0.8, 0.5), true, false],    # ровно на границе прежнего правила 1.6
		[Vector2(0.7, 0.7), true, false],    # чистая диагональ — прежнее правило молчало
		[Vector2(-0.75, 0.6), true, false],  # то же в другую сторону
		[Vector2(0.2, 0.95), true, true],    # идёт вперёд, лёгкий занос вбок — ход остаётся
		[Vector2(0.5, 0.5), true, true],     # вбок меньше порога поворота: стрейф цел
		[Vector2(0.9, 0.9), false, true],    # разные стики — правило не действует
	]
	for c in cases:
		var v: Vector2 = c[0]
		var res := LocomotionRes.turn_first(v, v, bool(c[1]))
		var moves: bool = (res["move"] as Vector2).length() > 0.01
		if moves != bool(c[2]):
			bad.append("%s (один стик %s): ход %s, ждали %s" % [v, c[1], moves, c[2]])
		# Поворот не трогается никогда: он главнее, а не «тоже приглушён».
		if res["turn"] != v:
			bad.append("%s: поворот изменён на %s" % [v, res["turn"]])
	# Порог — тот же, которым живёт сам поворот: два разных числа разошлись бы молча.
	var edge := LocomotionRes.turn_first(Vector2(TurnRes.DEADZONE - 0.01, 0.9),
			Vector2(TurnRes.DEADZONE - 0.01, 0.9), true)
	if (edge["move"] as Vector2).length() < 0.01:
		bad.append("чуть ниже порога поворота (%.2f) ход уже подавлен" % TurnRes.DEADZONE)
	if bad.is_empty():
		r.pass_("поворот главнее хода: при одном стике отклонение вбок от %.1f глушит ход целиком (проверено на 0.9/0.25, 0.8/0.5, 0.7/0.7), ниже порога стрейф цел, при разных стиках правило не действует" % TurnRes.DEADZONE)
	else:
		r.fail("поворот главнее хода: %s" % "; ".join(bad))


## Возврат остатка: человека, упёршегося телом в стену, отодвигают сдвигом origin — но НЕ пока он
## лезет. Origin несёт на себе кисти, а лазанье считает смещение от точки захвата, зафиксированной
## в мире: уехавшая кисть тут же требует сдвинуть тело обратно в стену, и так каждый такт. Петля
## дожимает тело в геометрию и рвёт хват (сессия 31).
func _push_out_check() -> void:
	PlayerBodyRes.falsify_climb_push = falsify == "climbpush"
	var dt := 1.0 / 90.0
	var step := PlayerBodyRes.RETURN_SPEED * dt
	var deep := Vector3(0, 0, 0.30)     # шагнул в стену телом
	var shallow := Vector3(0, 0, 0.20)  # наклонился у стола
	var bad: Array[String] = []
	var walk := PlayerBodyRes.push_out(deep, false, dt)
	if not is_equal_approx(walk.length(), step) or walk.normalized().dot(deep.normalized()) < 0.99:
		bad.append("при ходьбе остаток гасится на %.4f м вместо %.4f" % [walk.length(), step])
	if PlayerBodyRes.push_out(shallow, false, dt) != Vector3.ZERO:
		bad.append("наклон мельче порога %.2f м всё равно выталкивает" % PlayerBodyRes.PUSH_MIN)
	if PlayerBodyRes.push_out(deep, true, dt) != Vector3.ZERO:
		bad.append("лезущего везёт на %.4f м за такт" % PlayerBodyRes.push_out(deep, true, dt).length())
	# Контроль: случай наклона действительно задевает порог, иначе строка выше «доказывала» бы
	# пустоту — при нулевом пороге тот же остаток обязан гаситься.
	if PlayerBodyRes.push_out(shallow, false, dt, 0.0) == Vector3.ZERO:
		bad.append("контроль: при нулевом пороге наклон тоже не выталкивается — проверка пуста")
	PlayerBodyRes.falsify_climb_push = false
	if bad.is_empty():
		r.pass_("возврат остатка не возит лезущего: шагнувшего в стену отодвигает на %.4f м за такт, наклон мельче %.2f м не трогает вовсе, лезущего не трогает ни на сколько" % [
				step, PlayerBodyRes.PUSH_MIN])
	else:
		r.fail("возврат остатка: %s" % "; ".join(bad))


## Самопроверка делится надвое: исправность при каждом запуске, замеры — по требованию.
##
## На шлеме от картинки до запроса PIN проходило 154 секунды, и всё это время человек видел одну
## надпись «Самопроверка…»: «непонятно, всё сломалось или нужно ждать» (сессия 31). Замеры окнами —
## восемь проверок из девятнадцати, и именно они съедали время.
func _selfcheck_plan_check() -> void:
	var bad: Array[String] = []
	var quick := SelfCheckRes.plan(false)
	var full := SelfCheckRes.plan(true)
	if quick.size() != SelfCheckRes.HEALTH.size():
		bad.append("быстрый набор %d шагов вместо %d" % [quick.size(), SelfCheckRes.HEALTH.size()])
	if full.size() != SelfCheckRes.HEALTH.size() + SelfCheckRes.BENCH.size():
		bad.append("полный набор %d шагов" % full.size())
	# Ни один замер окнами не должен попасть в быстрый набор — иначе запуск снова замолчит.
	for name in SelfCheckRes.BENCH:
		if name in quick:
			bad.append("замер «%s» остался в быстром наборе" % name)
	# И наоборот: быстрый набор целиком входит в полный, порядок сохраняется.
	for i in quick.size():
		if full[i] != quick[i]:
			bad.append("порядок разошёлся на шаге %d: «%s» против «%s»" % [i, full[i], quick[i]])
	# Имена не повторяются: прогресс «шаг N из M» считает по этому списку.
	var seen := {}
	for name in full:
		if seen.has(name):
			bad.append("шаг «%s» назван дважды" % name)
		seen[name] = true
	if bad.is_empty():
		r.pass_("самопроверка: быстрая и полная — %d шагов исправности при каждом запуске, %d замеров окнами только по требованию, порядок и имена не расходятся" % [
				quick.size(), SelfCheckRes.BENCH.size()])
	else:
		r.fail("самопроверка: %s" % "; ".join(bad))


## Зона с полом запрашивается при КАЖДОМ запуске. Сессия 32: система отдала «сидячую» зону
## (режим 2), в ней высота головы считается от точки старта, а не от земли, — и человек оказывался
## глазами на уровне пола. Снаружи это выглядит как «спавнюсь ниже пола», хотя тело стоит верно:
## печать позы показала ноги 0.00, глаза 0.00, камера в origin 0.00, зона 2.
func _floor_area_check() -> void:
	var bad: Array[String] = []
	var sp := SpaceRes.new()
	sp.falsify_no_floor = falsify == "sitting"
	var asked: Array = []
	var now := [int(XRInterface.XR_PLAY_AREA_SITTING)]
	sp.set_play_area = func(m: int) -> bool:
		asked.append(m)
		now[0] = m
		return true
	sp.play_area_mode = func() -> int: return now[0]
	var got := sp.ensure_floor()
	if not SpaceRes.has_floor(got):
		bad.append("после запроса зона %d — без пола" % got)
	if asked.is_empty() or asked[0] != int(XRInterface.XR_PLAY_AREA_STAGE):
		bad.append("первой просят не stage: %s" % [asked])
	# Если stage не дают, берём roomscale: у него тоже есть пол.
	var sp2 := SpaceRes.new()
	var asked2: Array = []
	var now2 := [int(XRInterface.XR_PLAY_AREA_SITTING)]
	sp2.set_play_area = func(m: int) -> bool:
		asked2.append(m)
		if m == int(XRInterface.XR_PLAY_AREA_STAGE):
			return false
		now2[0] = m
		return true
	sp2.play_area_mode = func() -> int: return now2[0]
	if not SpaceRes.has_floor(sp2.ensure_floor()):
		bad.append("без stage не взяли roomscale: просили %s" % [asked2])
	# И сама таблица: какие режимы считаются «с полом».
	if SpaceRes.has_floor(int(XRInterface.XR_PLAY_AREA_SITTING)) \
			or SpaceRes.has_floor(int(XRInterface.XR_PLAY_AREA_3DOF)) \
			or not SpaceRes.has_floor(int(XRInterface.XR_PLAY_AREA_ROOMSCALE)):
		bad.append("режимы с полом определены неверно")
	if bad.is_empty():
		r.pass_("зона с полом при запуске: просим stage, не дали — roomscale; сидячая зона (%d) полом не считается, и её приход при запуске виден в журнале" % int(XRInterface.XR_PLAY_AREA_SITTING))
	else:
		r.fail("зона с полом при запуске: %s" % "; ".join(bad))
