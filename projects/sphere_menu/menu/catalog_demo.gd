extends "res://menu/source.gd"

## Синтетический каталог для прототипа (решения владельца 2026-09-15).
##
## Только объекты: папки, сцены, изображения, ассеты, скрипты логики, настройки.
## Команды редактора (Сохранить, Отменить…) — действия папки, а не пункты списка.
## Каталог изменяемый: копирование, перемещение, удаление, дублирование, новая
## папка — в памяти, со снимками для отмены. Изображения — настоящие PNG в
## res://content/images, для проверки предпросмотра.
##
## Имена различимы на слух — задание сессии «найдите пункт» задаётся словом.
##
## Шаг 1г (решение владельца после сессии 2): корень — основа меню, файловый менеджер —
## пункт «Файлы». Корень: Файлы, Настройки, Поиск, Запуск теста, избранное, «+», Выход.
## Избранное — ссылки на объекты, хранится здесь же, чтобы снимок отмены возвращал и его.

const Item := preload("res://menu/item.gd")
const Settings := preload("res://menu/settings.gd")
const Projects := preload("res://profile/projects.gd")
const K := Item.Kind
const P := Item.Policy

## id → Item
var items: Dictionary = {}
## папка → Array[id], порядок хранения (сортировка — в представлении)
var children_of: Dictionary = {}
## id → папка
var parent_of: Dictionary = {}
## id избранных объектов в порядке добавления (показываются на корне)
var favorites: Array = []
## Порядок корня: разделы до избранного и после него.
const HOME_HEAD := ["files", "settings", "home_search", "set_tasks"]
const HOME_TAIL := ["home_plus", "home_exit"]
const FAVORITES_PATH := "user://favorites.cfg"
## Большая папка: проверка отображения папки, где пунктов больше, чем подписей в атласе.
const BULK_FOLDER := "bulk"
const BULK_COUNT := 128
var _next_id := 0
## Фальсификатор настольных проверок «favorite»: удаление не чистит избранное.
var prune_favorites_disabled := false


func _init() -> void:
	children_of[ROOT] = []
	_folder(ROOT, "files", "Файлы")
	_folder(ROOT, "settings", "Настройки", "Настр.")
	var search: Item = Item.make("home_search", "Поиск", K.ACTION, P.STAY)
	search.action = "search"
	search.icon = "search"
	_add(ROOT, search)
	# «Запуск теста»: пока — режим заданий, позже — запуск проекта (решение владельца)
	var tasks: Item = Item.make("set_tasks", "Запуск теста", K.TOGGLE, P.STAY, "Тест")
	tasks.icon = "play"
	_add(ROOT, tasks)
	var plus: Item = Item.make("home_plus", "Добавить в меню", K.ACTION, P.STAY, "+")
	plus.action = "pick"
	plus.icon = "plus"
	_add(ROOT, plus)
	var quit: Item = Item.make("home_exit", "Выход", K.ACTION, P.CLOSE)
	quit.action = "exit"
	quit.icon = "exit"
	quit.danger = true
	_add(ROOT, quit)
	_folder("files", "scenes", "Сцены")
	_folder("files", "assets", "Ассеты")
	_folder("files", "images", "Изображения", "Изображ.")
	_folder("files", "logic", "Логика")

	var scenes := [["scene_forest", "Лес", 18400, "2026-09-02"], ["scene_castle", "Замок", 42100, "2026-09-11"],
			["scene_cave", "Пещера", 9800, "2026-08-21"], ["scene_harbor", "Гавань", 27300, "2026-09-14"],
			["scene_desert", "Пустыня", 12600, "2026-07-30"], ["scene_tower", "Башня", 15200, "2026-09-09"]]
	for s in scenes:
		_object("scenes", s[0], s[1], K.SCENE, "сцена", s[2], s[3], "gen:scene")
	_folder("scenes", "drafts", "Черновики")
	_object("drafts", "scene_draft1", "Набросок моста", K.SCENE, "сцена", 2100, "2026-09-13", "gen:scene", "Набросок")
	_object("drafts", "scene_draft2", "Проба света", K.SCENE, "сцена", 1800, "2026-09-12", "gen:scene", "Проба")

	_folder("assets", "trees", "Деревья")
	for t in [["tree_oak", "Дуб"], ["tree_pine", "Сосна"], ["tree_birch", "Берёза"], ["tree_palm", "Пальма"], ["tree_bush", "Куст"]]:
		_object("trees", t[0], t[1], K.ASSET, "ассет", 640, "2026-08-10", "gen:asset")
	for a in [["asset_stones", "Камни"], ["asset_house", "Дом"], ["asset_bridge", "Мост"], ["asset_fence", "Забор"],
			["asset_barrel", "Бочка"], ["asset_lantern", "Фонарь"]]:
		_object("assets", a[0], a[1], K.ASSET, "ассет", 1200, "2026-08-18", "gen:asset")

	for im in [["img_sunset", "Закат", "sunset"], ["img_mountains", "Горы", "mountains"], ["img_ocean", "Океан", "ocean"],
			["img_map", "Карта", "map"], ["img_stone", "Текстура камня", "stone", "Камень"],
			["img_sketch", "Эскиз замка", "sketch", "Эскиз"], ["img_sky", "Небо", "sky"]]:
		_object("images", im[0], im[1], K.IMAGE, "изображение", 256, "2026-09-05",
				"res://content/images/%s.png" % im[2], im[3] if im.size() > 3 else "")

	for l in [["logic_trigger", "Триггер"], ["logic_timer", "Таймер"], ["logic_door", "Дверь"],
			["logic_dialog", "Диалог"], ["logic_quest", "Квест"]]:
		_object("logic", l[0], l[1], K.FILE, "скрипт", 4, "2026-09-10", "")

	# Папка на 128 файлов (просьба владельца 2026-09-17): как меню показывает большую папку.
	# Пустые скрипты, номер в имени с нулями — сортировка по имени совпадает с порядком.
	_folder("files", BULK_FOLDER, "Много файлов", "Много")
	for i in BULK_COUNT:
		_object(BULK_FOLDER, "bulk_%03d" % (i + 1), "Файл %03d" % (i + 1), K.FILE, "файл", 0, "2026-09-17", "")

	_folder("settings", "settings_sphere", "Шар-меню")
	for sid in Settings.MAIN:
		_setting_item("settings_sphere", sid)
	_folder("settings_sphere", "settings_sphere_adv", "Дополнительно")
	for sid in Settings.ADVANCED:
		_setting_item("settings_sphere_adv", sid)
	# Пространство: свет и сетка пола (этап Ф3). «Сброс к системным» — действие, его исполняет
	# world/space.gd: вернуть режим зоны и положение к тому, что даёт система шлема.
	_folder("settings", "settings_space", "Пространство", "Простр.")
	for sid in Settings.SPACE:
		_setting_item("settings_space", sid)
	var reset_it: Item = Item.make("space_reset", "Сброс к системным значениям", K.ACTION, P.STAY, "Сброс")
	reset_it.action = "space_reset"
	reset_it.type_label = "действие"
	_add("settings_space", reset_it)
	# Разметка пространства (world/room.gd): системный сканер Quest. Пункт есть всегда — он же и
	# сообщает, что шлем разметки не отдаёт.
	var capture_it: Item = Item.make("space_capture", "Разметка пространства шлема", K.ACTION, P.STAY, "Разметка")
	capture_it.action = "space_capture"
	capture_it.type_label = "действие"
	_add("settings_space", capture_it)
	_folder("settings", "settings_move", "Перемещение", "Движ.")
	for sid in Settings.MOVE:
		_setting_item("settings_move", sid)
	# Возврат в стартовую точку уровня: сессия 17 — за край площадки можно уйти в пустоту, а из
	# дальнего угла локации возвращаться пешком долго.
	# Имя действия — с префиксом «space_»: навигатор рассылает действия ПО ПРЕФИКСУ, и пункт с чужим
	# именем молча не делает ничего (сессии 18–20: в журнале нет ни одного возврата из меню).
	var home_it: Item = Item.make("move_respawn", "Вернуться в стартовую точку", K.ACTION, P.CLOSE, "Старт")
	home_it.action = "space_respawn"
	home_it.type_label = "действие"
	_add("settings_move", home_it)
	# Слои объектов: кому что видно (ADR о слоях, 2026-09-21).
	_folder("settings", "settings_layers", "Слои", "Слои")
	for sid in Settings.LAYERS:
		_setting_item("settings_layers", sid)
	# Группы объектов уровня. Пусты до загрузки уровня: имена групп приходят из данных, а не из
	# каталога (set_groups), — поэтому папка строится, а наполняется на ходу.
	_folder("settings_layers", "settings_groups", "Группы", "Группы")
	# Замеры производительности: при запуске они больше не идут (154 секунды молчания, сессия 31),
	# и прогнать их можно отсюда. Имя действия — с префиксом «space_»: навигатор рассылает по
	# префиксу, пункт с чужим именем молча ничего не делает (ловушка 41).
	var bench_it: Item = Item.make("space_bench", "Прогнать замеры", K.ACTION, P.CLOSE, "Замеры")
	bench_it.action = "space_bench"
	bench_it.type_label = "действие"
	_add("settings_space", bench_it)
	var play_it: Item = Item.make("layers_play", "Режим игры", K.ACTION, P.CLOSE, "Игра")
	play_it.action = "space_play"
	play_it.type_label = "действие"
	_add("settings_layers", play_it)
	var wiz: Item = Item.make("set_wizard", "Мастер настройки", K.ACTION, P.CLOSE, "Мастер")
	wiz.action = "wizard"
	wiz.icon = "wizard"
	_add("settings_sphere", wiz)
	for o in [["set_sound", "Звук", K.OPTION], ["set_language", "Язык", K.OPTION], ["set_vignette", "Виньетка", K.TOGGLE]]:
		var so: Item = Item.make(o[0], o[1], o[2], P.STAY)
		so.type_label = "настройка"
		_add("settings", so)


## Папка «Профиль: <имя>» в настройках (ADR-0010) — собирается заново при каждом изменении профиля:
## в подписях видны имя, рост, высота глаз, число мест. Пункты — действия «profile_<что>», их исполняет
## profile/profile_ui.gd. Аккаунты и проекты появятся здесь с этапами D и E: пункт, который ничего не
## делает, хуже отсутствующего (ловушка 17). accounts — [{service, title}] с готовой подписью статуса;
## пусто — папки аккаунтов нет.
var _profile_ids: Array = []


func apply_profile(names: Array, active_id: String, p: RefCounted, accounts: Array = []) -> void:
	for id in _profile_ids:
		items.erase(id)
		parent_of.erase(id)
		children_of.erase(id)
	_profile_ids = []
	(children_of["settings"] as Array).erase("profile")
	var folder: Item = Item.make("profile", "Профиль: %s" % p.name, K.FOLDER, P.STAY, "Профиль")
	folder.type_label = "папка"
	items["profile"] = folder
	parent_of["profile"] = "settings"
	children_of["profile"] = []
	(children_of["settings"] as Array).insert(0, "profile")
	_profile_ids.append("profile")
	_profile_folder("profile", "profile_switch", "Сменить профиль", "Сменить")
	for row in names:
		var mark := " (сейчас)" if row["id"] == active_id else (" · PIN" if row["has_pin"] else "")
		_profile_action("profile_switch", "pf_open_" + row["id"], "%s%s" % [row["name"], mark],
				"profile_open:" + row["id"])
	_profile_action("profile_switch", "pf_new", "Новый профиль", "profile_new", "Новый")
	_profile_action("profile", "pf_name", "Имя: %s" % p.name, "profile_name", "Имя")
	_profile_action("profile", "pf_height", "Рост: %s" % ("%d см" % int(p.height_cm) if p.height_cm > 0.0 else "не задан"),
			"profile_height", "Рост")
	_profile_action("profile", "pf_eye", ("Высота глаз: %s м — измерить заново" % String.num(p.eye_m, 2).replace(".", ","))
			if p.eye_m > 0.0 else "Измерить высоту глаз (встаньте прямо)", "profile_eye", "Глаза")
	_profile_action("profile", "pf_place", "Запомнить это место (мест: %d)" % p.places.size(), "profile_place", "Место")
	_profile_action("profile", "pf_pin", "PIN: сменить или снять" if p.has_pin() else "PIN: задать", "profile_pin", "PIN")
	# Проекты: только ссылки (profile/projects.gd). Формата проекта нет, открыть их нечем — поэтому
	# пункты без действия, а пустая папка говорит почему, а не молчит.
	_profile_folder("profile", "profile_projects", "Проекты (%d)" % p.projects.size(), "Проекты")
	if p.projects.is_empty():
		_profile_info("profile_projects", "pf_projects_none", "Проектов нет: формат проекта ещё не принят (ADR)")
	for ref in Projects.recent(p.projects):
		_profile_info("profile_projects", "pf_project_" + ref["id"], ref["title"],
				"проект, открыт %s" % Time.get_date_string_from_unix_time(int(ref["opened_unix"])))
	if not accounts.is_empty():
		_profile_folder("profile", "profile_accounts", "Аккаунты", "Аккаунты")
		for a in accounts:
			_profile_action("profile_accounts", "pf_acc_" + a["service"], a["title"],
					"profile_account:" + a["service"], a["short"])
	if names.size() > 1:
		var del := _profile_action("profile", "pf_delete", "Удалить профиль «%s»" % p.name, "profile_delete", "Удалить")
		del.danger = true


func _profile_info(parent: String, id: String, title: String, type_label: String = "справка") -> void:
	var it: Item = Item.make(id, title, K.OPTION, P.STAY)
	it.type_label = type_label
	_add(parent, it)
	_profile_ids.append(id)


func _profile_folder(parent: String, id: String, title: String, short: String) -> void:
	_folder(parent, id, title, short)
	_profile_ids.append(id)


func _profile_action(parent: String, id: String, title: String, action: String, short: String = "") -> Item:
	var it: Item = Item.make(id, title, K.ACTION, P.STAY, short)
	it.action = action
	it.type_label = "профиль"
	_add(parent, it)
	_profile_ids.append(id)
	return it


## Папка настроек — по способу ввода этих значений (profile/input_settings.gd): в заголовке видно,
## чей набор правится, а настройки, к вводу не относящиеся (у рук — стик и вибро), скрыты.
## Пункты остаются в items — при возврате ввода они встают на прежние места.
func apply_input(st: Settings) -> void:
	var hands := st.input == "hands"
	var folder: Item = items["settings_sphere"]
	folder.title = "Шар-меню — руки" if hands else "Шар-меню — контроллеры"
	folder.short = "Шар·руки" if hands else "Шар·контр."
	var main: Array = Settings.MAIN.filter(func(sid: String): return st.applies(sid)) \
			.map(func(sid: String): return "set_" + sid)
	children_of["settings_sphere"] = main + ["settings_sphere_adv", "set_wizard"]
	children_of["settings_sphere_adv"] = Settings.ADVANCED.filter(func(sid: String): return st.applies(sid)) \
			.map(func(sid: String): return "set_" + sid)


func _setting_item(parent: String, sid: String) -> void:
	var it: Item = Item.make("set_" + sid, Settings.SPEC[sid]["title"], K.OPTION, P.STAY)
	it.setting = sid
	it.type_label = "настройка"
	_add(parent, it)


func _folder(parent: String, id: String, title: String, short: String = "") -> void:
	var it: Item = Item.make(id, title, K.FOLDER, P.STAY, short)
	it.type_label = "папка"
	_add(parent, it)
	children_of[id] = []


func _object(parent: String, id: String, title: String, kind: int, type_label: String,
		size_kb: int, modified: String, preview: String, short: String = "") -> void:
	var it: Item = Item.make(id, title, kind, P.CLOSE, short)
	it.type_label = type_label
	it.size_kb = size_kb
	it.modified = modified
	it.preview = preview
	_add(parent, it)


## Пересобрать папку групп по именам из уровня. Состояние «показана» приходит снимком, чтобы
## пункты не забывали скрытые группы при подгрузке новой части уровня.
func set_groups(names: Array, shown: Dictionary) -> void:
	for id in (children_of.get("settings_groups", []) as Array):
		items.erase(id)
		parent_of.erase(id)
	children_of["settings_groups"] = []
	for n in names:
		var name := str(n)
		var it: Item = Item.make("group_" + name, name, K.TOGGLE, P.STAY, name)
		it.on = bool(shown.get(name, true))
		it.action = "space_group:" + name
		it.type_label = "группа"
		_add("settings_groups", it)


func _add(parent: String, it: Item) -> void:
	items[it.id] = it
	parent_of[it.id] = parent
	(children_of[parent] as Array).append(it.id)


# --- контракт источника ------------------------------------------------------------

func count(folder_id: String) -> int:
	return (children_of.get(folder_id, []) as Array).size()


func children(folder_id: String, offset: int, limit: int) -> Array:
	var src: Array = children_of.get(folder_id, [])
	var out: Array = []
	for i in range(offset, mini(offset + limit, src.size())):
		out.append(items[src[i]])
	return out


## Корень в фиксированном порядке: разделы, избранное, «+», «Выход». Не сортируется —
## место пункта на шаре запоминается рукой.
func home_view() -> Array:
	var out: Array = []
	for id in HOME_HEAD:
		out.append(items[id])
	for id in favorites:
		if items.has(id):
			out.append(items[id])
	for id in HOME_TAIL:
		out.append(items[id])
	return out


## Служебные пункты корня — не объекты: их нельзя копировать, удалять и добавлять в избранное.
func is_home_entry(id: String) -> bool:
	return id in HOME_HEAD or id in HOME_TAIL


func is_favorite(id: String) -> bool:
	return favorites.has(id)


func set_favorite(id: String, on: bool) -> void:
	if on and not favorites.has(id) and items.has(id) and not is_home_entry(id):
		favorites.append(id)
	elif not on:
		favorites.erase(id)


func save_favorites(path: String = FAVORITES_PATH) -> Error:
	var cf := ConfigFile.new()
	cf.set_value("menu", "favorites", favorites)
	return cf.save(path)


## Загрузка избранного; исчезнувшие объекты отбрасываются. Файла нет — избранное пусто: при смене
## пользователя чужое не должно остаться.
func load_favorites(path: String = FAVORITES_PATH) -> void:
	favorites = []
	var cf := ConfigFile.new()
	if cf.load(path) != OK:
		return
	for id in cf.get_value("menu", "favorites", []):
		if items.has(str(id)) and not is_home_entry(str(id)):
			favorites.append(str(id))


## Поиск по названию: подстрока без регистра, служебные пункты корня не ищутся.
func search(query: String, limit: int = 60) -> Array:
	var q := query.strip_edges().to_lower()
	if q == "":
		return []
	var out: Array = []
	for id in items:
		var it: Item = items[id]
		if is_home_entry(id) or not it.title.to_lower().contains(q):
			continue
		out.append(it)
	out.sort_custom(func(a, b): return [not a.title.to_lower().begins_with(q), a.title.to_lower()] < [not b.title.to_lower().begins_with(q), b.title.to_lower()])
	return out.slice(0, limit)


func folder_title(folder_id: String) -> String:
	return "Меню" if folder_id == ROOT else (items[folder_id].title if items.has(folder_id) else folder_id)


func all_ids() -> PackedStringArray:
	return PackedStringArray(items.keys())


func path_to(item_id: String) -> Variant:
	if not parent_of.has(item_id):
		return null
	var out: Array = []
	var p: String = parent_of[item_id]
	while p != ROOT:
		out.push_front(p)
		p = parent_of[p]
	return out


# --- представление папки --------------------------------------------------------------

## Порядок показа: недавние объекты папки (до recent_limit) — первыми, по свежести;
## остальные — по сортировке. Фильтр оставляет только указанный вид (папки видны всегда).
func view(folder_id: String, sort: String, filter_kind: int, recent: Array, recent_limit: int = 6) -> Array:
	var src: Array = children(folder_id, 0, count(folder_id))
	if filter_kind >= 0:
		src = src.filter(func(it): return it.kind == filter_kind or it.kind == K.FOLDER)
	var rest := src.duplicate()
	rest.sort_custom(_comparator(sort))
	var head: Array = []
	for rid in recent:
		if head.size() >= recent_limit:
			break
		for it in rest:
			if it.id == rid:
				head.append(it)
				break
	for it in head:
		rest.erase(it)
	return head + rest


func _comparator(sort: String) -> Callable:
	match sort:
		"type":
			return func(a, b): return [a.kind != K.FOLDER, a.type_label, a.title.to_lower()] < [b.kind != K.FOLDER, b.type_label, b.title.to_lower()]
		"date":
			return func(a, b): return [a.kind != K.FOLDER, b.modified, a.title.to_lower()] < [b.kind != K.FOLDER, a.modified, b.title.to_lower()]
	return func(a, b): return [a.kind != K.FOLDER, a.title.to_lower()] < [b.kind != K.FOLDER, b.title.to_lower()]


# --- изменения и отмена ----------------------------------------------------------------

## Снимок — для отмены. Пункты копируются: переключатель и имя тоже откатываются.
func snapshot() -> Dictionary:
	var its := {}
	for id in items:
		its[id] = items[id].duplicate_item(id)
	return {"items": its, "children": children_of.duplicate(true), "parents": parent_of.duplicate(), "next": _next_id,
			"favorites": favorites.duplicate()}


func restore(s: Dictionary) -> void:
	items = {}
	for id in s["items"]:
		items[id] = s["items"][id].duplicate_item(id)
	children_of = (s["children"] as Dictionary).duplicate(true)
	parent_of = (s["parents"] as Dictionary).duplicate()
	_next_id = s["next"]
	favorites = (s.get("favorites", []) as Array).duplicate()


## Отпечаток состояния — проверка «отмена вернула каталог полностью».
func fingerprint() -> String:
	var parts := PackedStringArray()
	var ids := items.keys()
	ids.sort()
	for id in ids:
		var it: Item = items[id]
		parts.append("%s|%s|%s|%d|%s|%s" % [id, it.title, parent_of[id], it.kind, it.on, it.short])
	var folders := children_of.keys()
	folders.sort()
	for f in folders:
		parts.append("%s>%s" % [f, ",".join(children_of[f])])
	parts.append("fav>%s" % ",".join(favorites))
	return "\n".join(parts)


func is_inside(id: String, folder_id: String) -> bool:
	var p := folder_id
	while p != ROOT:
		if p == id:
			return true
		p = parent_of.get(p, ROOT)
	return id == folder_id


func _new_id(base: String) -> String:
	_next_id += 1
	return "%s_c%d" % [base, _next_id]


## Глубокая копия поддерева в папку target. Возвращает id копии.
func copy_to(id: String, target: String) -> String:
	var src: Item = items[id]
	var nid := _new_id(id)
	var it: Item = src.duplicate_item(nid)
	if (children_of[target] as Array).any(func(cid): return items[cid].title == src.title):
		it.title = src.title + " (копия)"
		it.short = ""
	_add(target, it)
	if src.kind == K.FOLDER:
		children_of[nid] = []
		for cid in (children_of[id] as Array).duplicate():
			copy_to(cid, nid)
	return nid


## Перемещение. Отказ — перенос папки в саму себя или в своего потомка.
func move_to(id: String, target: String) -> bool:
	if is_inside(id, target):
		return false
	(children_of[parent_of[id]] as Array).erase(id)
	parent_of[id] = target
	(children_of[target] as Array).append(id)
	return true


func remove(id: String) -> void:
	if items[id].kind == K.FOLDER:
		for cid in (children_of[id] as Array).duplicate():
			remove(cid)
		children_of.erase(id)
	(children_of[parent_of[id]] as Array).erase(id)
	parent_of.erase(id)
	items.erase(id)
	# удалённый объект уходит из избранного; отмена вернёт его вместе со снимком
	if not prune_favorites_disabled:
		favorites.erase(id)


func new_folder(target: String) -> String:
	var nid := _new_id("folder")
	var n := 1
	var title := "Новая папка"
	while (children_of[target] as Array).any(func(cid): return items[cid].title == title):
		n += 1
		title = "Новая папка %d" % n
	_folder(target, nid, title)
	return nid
