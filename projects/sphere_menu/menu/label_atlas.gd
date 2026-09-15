extends Node

## Атлас ячеек: иконка и подпись (слой 7, docs/design/sphere-menu.md §7).
##
## Один SubViewport с сеткой клеток рендерится один раз при смене списка, его
## текстура — вход шейдера ячеек. Все клетки — одна текстура и один MultiMesh:
## Label3D на ячейку дал бы вызов отрисовки на ячейку (ADR-0003 п. 2 и 8).
##
## Клетка: иконка сверху, подпись снизу. Перенос — только по пробелам: умный
## перенос рвал слова посреди («Сохранит / ь», запуск на шлеме 2026-09-15).

const GRID := 8
const TILE := 128
const ICON_PX := 52
## Последняя клетка атласа — служебная «назад» / «отмена».
const BACK_INDEX := GRID * GRID - 1
const MAX_ITEMS := BACK_INDEX

var viewport: SubViewport
var _labels: Array[Label] = []
var _icons: Array[TextureRect] = []
var _icon_cache: Dictionary = {}
## Сколько раз атлас перерисовывался — для самопроверки.
var renders := 0


func _ready() -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(GRID * TILE, GRID * TILE)
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(viewport)
	var root := Control.new()
	root.size = Vector2(viewport.size)
	viewport.add_child(root)
	for i in GRID * GRID:
		var origin := Vector2((i % GRID) * TILE, (i / GRID) * TILE)
		var ic := TextureRect.new()
		ic.position = origin + Vector2((TILE - ICON_PX) * 0.5, 10)
		ic.size = Vector2(ICON_PX, ICON_PX)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		root.add_child(ic)
		_icons.append(ic)
		var l := Label.new()
		l.position = origin + Vector2(4, 64)
		l.size = Vector2(TILE - 8, TILE - 66)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		l.autowrap_mode = TextServer.AUTOWRAP_WORD
		l.clip_text = true
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		l.add_theme_font_size_override("font_size", 19)
		l.add_theme_color_override("font_color", Color.WHITE)
		root.add_child(l)
		_labels.append(l)


func icon(name: String) -> Texture2D:
	if name == "":
		return null
	if not _icon_cache.has(name):
		var path := "res://icons/%s.svg" % name
		_icon_cache[name] = load(path) if ResourceLoader.exists(path) else null
	return _icon_cache[name]


## Клетки списка: индекс в массиве = индекс клетки атласа. back_text — надпись
## служебной ячейки: «Назад» в обзоре, «Отмена» в шарах действий.
func set_cells(texts: Array, icons: Array, back_text: String) -> void:
	for i in MAX_ITEMS:
		_labels[i].text = texts[i] if i < texts.size() else ""
		_icons[i].texture = icon(icons[i]) if i < icons.size() else null
	_labels[BACK_INDEX].text = back_text
	_icons[BACK_INDEX].texture = icon("back" if back_text == "Назад" else "cancel")
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	renders += 1


func texture() -> Texture2D:
	return viewport.get_texture()
