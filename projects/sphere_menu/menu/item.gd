extends RefCounted

## Пункт шар-меню (слой 1, docs/design/sphere-menu.md §1).
##
## Меню не знает, что показывает: редактор и игра отдают пункты одного вида.
## С 2026-09-15 объекты и действия разделены (решение владельца): в обзоре шар
## показывает объекты, действия — отдельным шаром по удержанию курка. Действие —
## тоже пункт (kind ACTION), чтобы шар действий рисовался тем же рендером.

## Порядок значений — коды цвета в шейдере (menu/cell.gdshader, KIND_COLORS).
## Новые виды — только в конец.
enum Kind { ACTION, FOLDER, TOGGLE, OPTION, FILE, ASSET, IMAGE, SCENE }
## Что делать после действия по умолчанию (ADR-0008 п. 7).
enum Policy { CLOSE, STAY }

var id: String
## Полное имя — панель информации.
var title: String
## Короткая подпись ячейки — атлас. Пустая — берётся title.
var short: String
var kind: Kind = Kind.ACTION
var policy: Policy = Policy.STAY
var enabled := true
## Для TOGGLE — текущее значение.
var on := false
## Иконка: имя файла в res://icons без расширения.
var icon := ""
## Предпросмотр: res://-путь картинки или «gen:scene» / «gen:asset» — миниатюра рисуется.
var preview := ""
## Метаданные для панели.
var type_label := ""
var size_kb := 0
var modified := ""
## Для действия — опасное (подтверждается удержанием).
var danger := false
## Для действия — идентификатор операции навигатора; для объекта — пусто.
var action := ""
## Для OPTION — ключ настройки шара (menu/settings.gd), пусто — не настройка.
var setting := ""


static func make(p_id: String, p_title: String, p_kind: Kind = Kind.ACTION,
		p_policy: Policy = Policy.STAY, p_short: String = "") -> RefCounted:
	var it = load("res://menu/item.gd").new()
	it.id = p_id
	it.title = p_title
	it.kind = p_kind
	it.policy = p_policy
	it.short = p_short
	it.icon = default_icon(p_kind)
	return it


static func default_icon(k: Kind) -> String:
	match k:
		Kind.FOLDER: return "folder"
		Kind.SCENE: return "scene"
		Kind.IMAGE: return "image"
		Kind.ASSET: return "asset"
		Kind.FILE: return "file"
		Kind.TOGGLE: return "toggle"
		Kind.OPTION: return "option"
	return "action"


func label() -> String:
	return short if short != "" else title


func is_object() -> bool:
	return kind != Kind.ACTION


func duplicate_item(new_id: String) -> RefCounted:
	var it = load("res://menu/item.gd").new()
	for p in ["title", "short", "kind", "policy", "enabled", "on", "icon", "preview",
			"type_label", "size_kb", "modified", "danger", "action", "setting"]:
		it.set(p, get(p))
	it.id = new_id
	return it
