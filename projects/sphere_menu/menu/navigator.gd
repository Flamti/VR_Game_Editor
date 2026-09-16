extends RefCounted

## Навигатор шар-меню: режимы шара и намерения (решения владельца 2026-09-15).
##
## Объекты и действия разделены. Шар показывает одно из:
##   browse  — объекты папки (недавние — первым кольцом, дальше по сортировке);
##   actions — в центре объект (или группа), вокруг его действия;
##   letters — первые буквы объектов папки: выбор — прыжок к первому на эту букву;
##   path    — предки текущей папки: выбор — переход на уровень;
##   search  — в центре запрос, вокруг найденные объекты (шаг 1г).
## Корень — основа меню (Файлы, Настройки, Поиск, Запуск теста, избранное, «+», Выход),
## «Назад» на нём нет. «+» включает выбор: короткое на объекте в Файлах добавляет его на
## корень. «Выход» опасный — только удержанием до конца кольца.
## Слот 0 в actions/letters/path — центр с самим объектом, пункты — со слота 1.
## «Назад» (фиксированная ячейка слева от центра) в обзоре — вверх по папкам, в
## остальных шарах — «Отмена»: возврат к списку с той же прокруткой.
##
## Курок: короткое — действие по умолчанию, удержание — шар действий (menu/press.gd).
## Опасное действие исполняется только удержанием.
##
## Чистая логика: прокрутка передаётся снаружи и возвращается непрозрачной;
## ответ — словарь {do, …}, что сделать меню:
##   reload   — показать новый список; scroll — применить или null (раздать заново)
##   redraw   — тот же список, изменились пометки/значения
##   focus    — вернуться в обзор (scroll) и довернуть к слоту slot
##   default  — выполнено действие по умолчанию над объектом item
##   properties — показать свойства item на панели
##   wizard   — запустить мастер настройки
##   tasks    — режим заданий включён/выключен (on)
##   setting  — изменена настройка шара (id)
##   edit     — открыть правку настройки на панели (id; scroll — если вид сменился)
##   search   — открыт поиск: включить ввод текста; search_end — поиск закрыт
##   exit     — сохранить и выйти из приложения
##   close    — закрыть меню
##   need_hold — короткое на опасном действии: подсказка удерживать
##   none     — ничего

const Item := preload("res://menu/item.gd")
const State := preload("res://menu/state.gd")
const Catalog := preload("res://menu/catalog_demo.gd")
const Settings := preload("res://menu/settings.gd")
const K := Item.Kind

const SORTS := ["name", "type", "date"]
const SORT_TITLES := {"name": "по имени", "type": "по типу", "date": "по дате"}
const FILTERS := [-1, K.SCENE, K.IMAGE, K.ASSET]
const FILTER_TITLES := {-1: "все", K.SCENE: "сцены", K.IMAGE: "изображения", K.ASSET: "ассеты"}
const UNDO_LIMIT := 20
const RECENT_LIMIT := 20

var catalog: Catalog
var settings: Settings
var state: State = State.new()

var view := "browse"
var multi := false
## id отмеченных в множественном выборе
var marked: Dictionary = {}
## {op: "copy"|"cut", ids: Array}
var clipboard: Dictionary = {}
var recent: Array = []
var sort_of: Dictionary = {}
var filter_of: Dictionary = {}
var message := ""
var tasks_on := false
## Режим «+»: короткое на объекте добавляет его в избранное и возвращает на корень.
var picking := false
var search_query := ""

var _list: Array = []
## Недавние на момент входа в папку. Внутри папки порядок не меняется: открытый
## объект не должен переезжать под рукой в первое кольцо (прокрутка вернулась бы
## к другим пунктам). Обновляется при смене папки.
var _view_recent: Array = []
var _browse_scroll: Variant = null
## цель шара действий: Array id
var _targets: Array = []
var _undo: Array = []
var _redo: Array = []


func _init(p_catalog: Catalog, p_settings: Settings) -> void:
	catalog = p_catalog
	settings = p_settings
	_rebuild()


# --- что показывать ---------------------------------------------------------------

func items() -> Array:
	return _list


func item_at(slot: int) -> Item:
	return _list[slot] if slot >= 0 and slot < _list.size() else null


func is_danger(slot: int) -> bool:
	var it := item_at(slot)
	return it != null and it.danger and (view == "actions" or view == "browse")


func is_marked(slot: int) -> bool:
	var it := item_at(slot)
	return it != null and view == "browse" and marked.has(it.id)


func breadcrumbs() -> PackedStringArray:
	var out := PackedStringArray()
	for f in state.stack:
		out.append(catalog.folder_title(f))
	return out


func hint() -> String:
	match view:
		"actions":
			return "курок — действие, удержание — опасное; «Отмена» слева"
		"letters":
			return "выберите букву — прыжок; «Отмена» слева"
		"path":
			return "выберите уровень; «Отмена» слева"
		"search":
			return "найдено %d; курок — открыть, «Отмена» слева" % maxi(0, _list.size() - 1)
	if picking:
		return "выберите объект — он появится в меню; «Назад» — отмена"
	if state.folder() == State.ROOT:
		return "курок — открыть, удержание — действия; «Выход» — удержанием"
	if multi:
		return "курок — отметить (%d), удержание — действия группы; «Отмена» слева" % marked.size()
	return "курок — открыть, удержание — действия"


func folder_sort() -> String:
	return sort_of.get(state.folder(), "name")


func folder_filter() -> int:
	return filter_of.get(state.folder(), -1)


func can_undo() -> bool:
	return not _undo.is_empty()


func _rebuild() -> void:
	match view:
		"browse":
			if state.folder() == State.ROOT:
				_list = catalog.home_view()
			else:
				_list = catalog.view(state.folder(), folder_sort(), folder_filter(), _view_recent)
		"search":
			var c: Item = _center("search_center", "Поиск: %s" % search_query if search_query != "" else "Поиск", "search")
			_list = [c] + catalog.search(search_query)
		"actions":
			_list = [_center_for(_targets)] + _actions_for(_targets)
		"letters":
			_list = [_center("letters_center", "Буква", "letter")] + _letters()
		"path":
			_list = [_center("path_center", "Путь", "path")] + _ancestors()


func _center(id: String, title: String, icon: String) -> Item:
	var it: Item = Item.make(id, title, K.FILE)
	it.icon = icon
	return it


func _center_for(ids: Array) -> Item:
	if ids.size() == 1 and catalog.items.has(ids[0]):
		return catalog.items[ids[0]]
	if ids.is_empty():
		var f: Item = _center("folder_center", catalog.folder_title(state.folder()), "folder")
		f.kind = K.FOLDER
		return f
	return _center("group_center", "%d объектов" % ids.size(), "select")


func _action(id: String, title: String, icon: String, danger: bool = false) -> Item:
	var it: Item = Item.make("act_" + id, title, K.ACTION)
	it.action = id
	it.icon = icon
	it.danger = danger
	return it


func _actions_for(ids: Array) -> Array:
	if ids.is_empty() and state.folder() == State.ROOT:
		# на корне нет файлов: вставлять, сортировать и создавать папки некуда
		var home: Array = []
		if can_undo():
			home.append(_action("undo", "Отменить", "undo"))
		if not _redo.is_empty():
			home.append(_action("redo", "Повторить", "redo"))
		return home
	if ids.is_empty():
		var out: Array = []
		if not clipboard.is_empty():
			out.append(_action("paste", "Вставить (%d)" % (clipboard["ids"] as Array).size(), "paste"))
		out.append_array([
			_action("new_folder", "Новая папка", "folder"),
			_action("sort", "Сортировка: %s" % SORT_TITLES[folder_sort()], "sort"),
			_action("filter", "Фильтр: %s" % FILTER_TITLES[folder_filter()], "filter"),
			_action("letters", "Буква…", "letter"),
			_action("path", "Путь…", "path"),
			_action("multi", "Выбрать несколько", "select"),
			_action("save", "Сохранить", "save"),
		])
		if can_undo():
			out.append(_action("undo", "Отменить", "undo"))
		if not _redo.is_empty():
			out.append(_action("redo", "Повторить", "redo"))
		return out
	if ids.size() > 1:
		return [_action("copy", "Копировать", "copy"), _action("cut", "Вырезать", "cut"),
				_action("delete", "Удалить", "delete", true)]
	var it: Item = catalog.items[ids[0]]
	if catalog.is_home_entry(it.id):
		return [_action("open", "Открыть", "action"), _action("properties", "Свойства", "info")]
	var fav := _action("fav_remove", "Убрать из избранного", "star_off") if catalog.is_favorite(it.id) \
			else _action("fav_add", "Добавить в избранное", "star")
	var first: Array = []
	match it.kind:
		K.FOLDER: first = [_action("open", "Войти", "folder")]
		K.SCENE: first = [_action("open", "Открыть", "scene")]
		K.IMAGE: first = [_action("open", "Просмотр", "image")]
		K.ASSET: first = [_action("open", "Поставить", "asset")]
		K.OPTION:
			# «Больше/Меньше» ступенями сняты (шаг 1в): значение правится на панели
			first = [_action("open", "Изменить", "plus"), _action("reset_setting", "По умолчанию", "undo")]
			return first + [fav, _action("properties", "Свойства", "info")]
		K.TOGGLE, K.ACTION:
			return [_action("open", "Переключить" if it.kind == K.TOGGLE else "Выполнить", "action"),
					_action("properties", "Свойства", "info")]
		_: first = [_action("open", "Открыть", "file")]
	return first + [fav, _action("copy", "Копировать", "copy"), _action("cut", "Вырезать", "cut"),
			_action("duplicate", "Дублировать", "copy"), _action("delete", "Удалить", "delete", true),
			_action("properties", "Свойства", "info")]


func _letters() -> Array:
	var seen := {}
	var out: Array = []
	for it in catalog.view(state.folder(), folder_sort(), folder_filter(), [], 0):
		var ch: String = it.title.substr(0, 1).to_upper()
		if not seen.has(ch):
			seen[ch] = true
			out.append(ch)
	out.sort()
	return out.map(func(ch): return _action("letter:" + ch, ch, "letter"))


func _ancestors() -> Array:
	var out: Array = []
	for d in state.stack.size() - 1:
		out.append(_action("path:%d" % d, catalog.folder_title(state.stack[d]), "folder"))
	return out


# --- намерения -------------------------------------------------------------------

## Короткое нажатие на слоте.
func short(slot: int, scroll: Variant) -> Dictionary:
	var it := item_at(slot)
	if it == null:
		return {"do": "none"}
	if view == "search":
		return {"do": "none"} if slot == 0 else _open_found(it, scroll)
	if view != "browse":
		if slot == 0:
			if view == "actions" and _targets.size() == 1:
				return _run_action("open", scroll)
			return {"do": "none"}
		if it.danger:
			message = "Удерживайте курок: %s" % it.title.to_lower()
			return {"do": "need_hold"}
		return _run_action(it.action, scroll)
	if multi:
		if marked.has(it.id):
			marked.erase(it.id)
		else:
			marked[it.id] = true
		return {"do": "redraw"}
	if it.danger:
		message = "Удерживайте курок: %s" % it.title.to_lower()
		return {"do": "need_hold"}
	return _default(it, scroll)


## Удержание на слоте; slot < 0 — на пустой ячейке или «Назад»: действия папки.
func hold(slot: int, scroll: Variant) -> Dictionary:
	var it := item_at(slot)
	if view == "browse" and it != null and it.danger and not multi:
		# опасный пункт обзора («Выход») исполняется удержанием, а не открывает действия
		return _default(it, scroll)
	if view == "search":
		return short(slot, scroll)
	if view == "actions":
		if it != null and slot > 0:
			return _run_action(it.action, scroll)
		return {"do": "none"}
	if view != "browse":
		return short(slot, scroll)
	_browse_scroll = scroll
	if multi and not marked.is_empty():
		_targets = marked.keys()
	elif it == null:
		_targets = []
	else:
		_targets = [it.id]
	view = "actions"
	_rebuild()
	return {"do": "reload", "scroll": null}


## «Назад» / «Отмена».
func back(scroll: Variant) -> Dictionary:
	if view == "search":
		search_query = ""
		var r := _to_browse(true)
		r["search_end"] = true
		return r
	if view != "browse":
		return _to_browse(true)
	if picking and state.depth() <= 1:
		picking = false
		message = "Добавление отменено"
	if multi:
		multi = false
		marked.clear()
		message = "Выбор снят"
		return {"do": "redraw"}
	var res := state.back(scroll)
	if res["closed"]:
		return {"do": "close"}
	_view_recent = recent.duplicate()
	_rebuild()
	return {"do": "reload", "scroll": res["scroll"]}


func undo() -> Dictionary:
	if _undo.is_empty():
		message = "Нечего отменять"
		return {"do": "none"}
	_redo.append(catalog.snapshot())
	catalog.restore(_undo.pop_back())
	_after_mutation()
	message = "Отменено"
	return {"do": "reload", "scroll": null}


func redo() -> Dictionary:
	if _redo.is_empty():
		return {"do": "none"}
	_undo.append(catalog.snapshot())
	catalog.restore(_redo.pop_back())
	_after_mutation()
	message = "Повторено"
	return {"do": "reload", "scroll": null}


func open_root() -> void:
	view = "browse"
	multi = false
	picking = false
	search_query = ""
	marked.clear()
	_view_recent = recent.duplicate()
	_rebuild()


# --- исполнение -----------------------------------------------------------------

func _default(it: Item, scroll: Variant) -> Dictionary:
	match it.kind:
		K.FOLDER:
			var sc: Variant = state.enter(it.id, scroll)
			_view_recent = recent.duplicate()
			_rebuild()
			return {"do": "reload", "scroll": sc}
		K.TOGGLE:
			it.on = not it.on
			if it.id == "set_tasks":
				tasks_on = it.on
				return {"do": "tasks", "on": it.on}
			return {"do": "redraw"}
		K.OPTION:
			if it.setting != "":
				return {"do": "edit", "id": it.setting}
			return {"do": "redraw"}
		K.ACTION:
			match it.action:
				"wizard":
					return {"do": "wizard"}
				"search":
					_browse_scroll = scroll
					search_query = ""
					view = "search"
					_rebuild()
					return {"do": "search", "scroll": null}
				"pick":
					picking = true
					var sc: Variant = state.enter("files", scroll)
					_view_recent = recent.duplicate()
					_rebuild()
					message = "Выберите объект для меню"
					return {"do": "reload", "scroll": sc}
				"exit":
					return {"do": "exit"}
			return {"do": "none"}
	if picking:
		picking = false
		_checkpoint()
		catalog.set_favorite(it.id, true)
		state.jump(0, scroll)
		_rebuild()
		message = "В меню: %s" % it.title
		return {"do": "reload", "scroll": null}
	_touch(it.id)
	message = "%s: %s" % [{K.SCENE: "Открыта сцена", K.IMAGE: "Просмотр", K.ASSET: "Поставлен ассет"}.get(it.kind, "Открыт"), it.title]
	return {"do": "default", "item": it, "close": it.kind != K.IMAGE}


func _run_action(action: String, scroll: Variant) -> Dictionary:
	var ids := _targets.duplicate()
	if action.begins_with("letter:"):
		var ch := action.substr(7)
		var back_res := _to_browse(true)
		for i in _list.size():
			if (_list[i] as Item).title.substr(0, 1).to_upper() == ch:
				return {"do": "focus", "scroll": back_res["scroll"], "slot": i}
		return back_res
	if action.begins_with("path:"):
		var depth := int(action.substr(5))
		view = "browse"
		var sc: Variant = state.jump(depth, _browse_scroll)
		_view_recent = recent.duplicate()
		_rebuild()
		return {"do": "reload", "scroll": sc}
	match action:
		"open":
			var it: Item = catalog.items[ids[0]]
			view = "browse"
			_rebuild()
			var r := _default(it, _browse_scroll)
			if r["do"] == "redraw" or r["do"] == "setting":
				r = {"do": "reload", "scroll": _browse_scroll}
			elif r["do"] == "edit":
				r["scroll"] = _browse_scroll
			return r
		"fav_add", "fav_remove":
			_checkpoint()
			for id in ids:
				catalog.set_favorite(id, action == "fav_add")
			message = "%s: %s" % ["В избранном" if action == "fav_add" else "Убрано из избранного",
					", ".join(ids.map(func(x): return catalog.items[x].title))]
			return _after_change()
		"reset_setting":
			var opt: Item = catalog.items[ids[0]]
			if opt.setting != "":
				settings.values[opt.setting] = Settings.SPEC[opt.setting]["default"]
				message = "%s: %s" % [opt.title, settings.label(opt.setting)]
				return {"do": "setting", "id": opt.setting}
			return {"do": "none"}
		"properties":
			return {"do": "properties", "item": catalog.items[ids[0]] if ids.size() == 1 else null}
		"copy", "cut":
			clipboard = {"op": action, "ids": ids}
			message = "%s: %d" % ["Скопировано" if action == "copy" else "Вырезано", ids.size()]
			multi = false
			marked.clear()
			return _to_browse(true)
		"duplicate":
			_checkpoint()
			for id in ids:
				catalog.copy_to(id, catalog.parent_of[id])
			message = "Дублировано: %d" % ids.size()
			return _after_change()
		"delete":
			_checkpoint()
			var titles := PackedStringArray()
			for id in ids:
				if catalog.items.has(id):
					titles.append(catalog.items[id].title)
					catalog.remove(id)
			if not clipboard.is_empty():
				clipboard["ids"] = (clipboard["ids"] as Array).filter(func(x): return catalog.items.has(x))
				if (clipboard["ids"] as Array).is_empty():
					clipboard = {}
			recent = recent.filter(func(x): return catalog.items.has(x))
			message = "Удалено: %s — B отменить" % ", ".join(titles)
			multi = false
			marked.clear()
			return _after_change()
		"paste":
			if clipboard.is_empty():
				return {"do": "none"}
			_checkpoint()
			var target := state.folder()
			var done := 0
			var refused := 0
			for id in clipboard["ids"]:
				if not catalog.items.has(id):
					continue
				if clipboard["op"] == "copy":
					catalog.copy_to(id, target)
					done += 1
				elif catalog.move_to(id, target):
					done += 1
				else:
					refused += 1
			if clipboard["op"] == "cut":
				clipboard = {}
			message = "Вставлено: %d%s" % [done, (", отказано: %d (папка в саму себя)" % refused) if refused > 0 else ""]
			return _after_change()
		"new_folder":
			_checkpoint()
			catalog.new_folder(state.folder())
			message = "Создана папка"
			return _after_change()
		"sort":
			sort_of[state.folder()] = SORTS[(SORTS.find(folder_sort()) + 1) % SORTS.size()]
			message = "Сортировка: %s" % SORT_TITLES[folder_sort()]
			return _after_change()
		"filter":
			filter_of[state.folder()] = FILTERS[(FILTERS.find(folder_filter()) + 1) % FILTERS.size()]
			message = "Фильтр: %s" % FILTER_TITLES[folder_filter()]
			return _after_change()
		"letters", "path":
			view = action
			_rebuild()
			return {"do": "reload", "scroll": null}
		"multi":
			multi = true
			marked.clear()
			return _to_browse(true)
		"save":
			message = "Сохранено (прототип: без записи на диск)"
			return _to_browse(true)
		"undo":
			view = "browse"
			return undo()
		"redo":
			view = "browse"
			return redo()
	return {"do": "none"}


## Запрос поиска изменился: список найденного пересобирается.
func set_query(q: String) -> Dictionary:
	if view != "search":
		return {"do": "none"}
	search_query = q
	_rebuild()
	return {"do": "reload", "scroll": null}


## Открыть найденное: папка — переход по её пути, объект — действие по умолчанию из его папки.
func _open_found(it: Item, scroll: Variant) -> Dictionary:
	var path: Variant = catalog.path_to(it.id)
	search_query = ""
	view = "browse"
	state.jump(0, scroll)
	for f in (path if path != null else []):
		state.enter(f, null)
	if it.kind == K.FOLDER:
		state.enter(it.id, null)
		_view_recent = recent.duplicate()
		_rebuild()
		return {"do": "reload", "scroll": null, "search_end": true}
	_view_recent = recent.duplicate()
	_rebuild()
	var r := _default(it, null)
	if r["do"] in ["redraw", "setting", "none"]:
		r = {"do": "reload", "scroll": null}
	r["search_end"] = true
	r["reload"] = true
	return r


func _to_browse(restore_scroll: bool) -> Dictionary:
	view = "browse"
	_targets = []
	_rebuild()
	return {"do": "reload", "scroll": _browse_scroll if restore_scroll else null}


## После изменения каталога список другой: прокрутку не восстанавливать — пункты
## раздаются заново от активной ячейки.
func _after_change() -> Dictionary:
	_after_mutation()
	return {"do": "reload", "scroll": null}


func _after_mutation() -> void:
	view = "browse"
	_targets = []
	state.prune(func(f): return f == State.ROOT or catalog.children_of.has(f))
	for id in marked.keys():
		if not catalog.items.has(id):
			marked.erase(id)
	_rebuild()


func _checkpoint() -> void:
	_undo.append(catalog.snapshot())
	if _undo.size() > UNDO_LIMIT:
		_undo.pop_front()
	_redo.clear()


func _touch(id: String) -> void:
	recent.erase(id)
	recent.push_front(id)
	if recent.size() > RECENT_LIMIT:
		recent.resize(RECENT_LIMIT)
