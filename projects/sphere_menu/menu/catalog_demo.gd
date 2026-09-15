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

const Item := preload("res://menu/item.gd")
const Settings := preload("res://menu/settings.gd")
const K := Item.Kind
const P := Item.Policy

## id → Item
var items: Dictionary = {}
## папка → Array[id], порядок хранения (сортировка — в представлении)
var children_of: Dictionary = {}
## id → папка
var parent_of: Dictionary = {}
var _next_id := 0


func _init() -> void:
	children_of[ROOT] = []
	_folder(ROOT, "scenes", "Сцены")
	_folder(ROOT, "assets", "Ассеты")
	_folder(ROOT, "images", "Изображения", "Изображ.")
	_folder(ROOT, "logic", "Логика")
	_folder(ROOT, "settings", "Настройки", "Настр.")

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

	_folder("settings", "settings_sphere", "Шар-меню")
	for sid in Settings.MAIN:
		_setting_item("settings_sphere", sid)
	_folder("settings_sphere", "settings_sphere_adv", "Дополнительно")
	for sid in Settings.ADVANCED:
		_setting_item("settings_sphere_adv", sid)
	var wiz: Item = Item.make("set_wizard", "Мастер настройки", K.ACTION, P.CLOSE, "Мастер")
	wiz.action = "wizard"
	wiz.icon = "wizard"
	_add("settings_sphere", wiz)
	var tasks: Item = Item.make("set_tasks", "Режим заданий", K.TOGGLE, P.STAY, "Задания")
	_add("settings_sphere", tasks)
	for o in [["set_sound", "Звук", K.OPTION], ["set_language", "Язык", K.OPTION], ["set_vignette", "Виньетка", K.TOGGLE]]:
		var so: Item = Item.make(o[0], o[1], o[2], P.STAY)
		so.type_label = "настройка"
		_add("settings", so)


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
	return {"items": its, "children": children_of.duplicate(true), "parents": parent_of.duplicate(), "next": _next_id}


func restore(s: Dictionary) -> void:
	items = {}
	for id in s["items"]:
		items[id] = s["items"][id].duplicate_item(id)
	children_of = (s["children"] as Dictionary).duplicate(true)
	parent_of = (s["parents"] as Dictionary).duplicate()
	_next_id = s["next"]


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


func new_folder(target: String) -> String:
	var nid := _new_id("folder")
	var n := 1
	var title := "Новая папка"
	while (children_of[target] as Array).any(func(cid): return items[cid].title == title):
		n += 1
		title = "Новая папка %d" % n
	_folder(target, nid, title)
	return nid
