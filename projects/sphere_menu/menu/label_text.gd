extends Node

## Подписи ячеек собирает шейдер (решение владельца после сессии 9, ADR-0008 п. 17).
##
## Прежний атлас «клетка на пункт» (SubViewport 8×8) ограничивал страницу 61 подписью (сессия 7), а
## «атлас по видимым» стоил на линзе 19.66 мс CPU (сессия 9) — оба удалены.
## Здесь нет клетки на пункт: статичный атлас глифов и статичный атлас иконок рисуются один раз,
## а на каждый пункт — строка текстуры данных: номер иконки и раскладка букв двух строк.
## Шейдер ячейки (menu/cell.gdshader, shader_label) по uv находит строку, букву и берёт один
## глиф. Число пунктов ограничено только высотой текстуры данных (ROWS).
##
## Геометрия клетки повторяет атлас: клетка 128 px, иконка 52 px с y = 10, подпись с y = 64,
## ширина 120 px, шрифт 19 px. Глифы нарисованы вдвое крупнее (GLYPH_PX) и сэмплируются с
## масштабом 0.5 — иначе буквы на ячейке выходили бы мыльнее, чем в атласе.

const TILE := 128.0
const TEXT_TOP := 64.0
const TEXT_WIDTH := 120.0
const LINE_H := 22.0
const FONT_PX := 19
const GLYPH_PX := 38
const GLYPH_CELL := Vector2i(48, 56)
const GLYPH_COLS := 16
const ICON_PX := 64
const ICON_COLS := 8
const ICON_ROWS := 6
## Букв в строке и строк подписи.
const LINE_CHARS := 16
const LINES := 2
## Столбцы строки данных: заголовок + буквы двух строк.
const COLS := 1 + LINE_CHARS * LINES
## Строк данных: пункты страницы; последние три — служебные.
const ROWS := 1024
const BACK_ROW := ROWS - 1
const NEXT_ROW := ROWS - 2
const PREV_ROW := ROWS - 3
const MAX_ITEMS := ROWS - 3

const CHARSET := " АБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯабвгдеёжзийклмнопрстуфхцчшщъыьэюяABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789.,:;!?-–—+=()[]«»\"'/\\…%№_#&*<>@"

var glyph_viewport: SubViewport
var data_image: Image
var data_texture: ImageTexture
var icon_image: Image
var icon_texture: ImageTexture
## символ → номер глифа
var _glyph: Dictionary = {}
## номер глифа → ширина в пикселях клетки (шрифт FONT_PX)
var _advance: PackedFloat32Array = PackedFloat32Array()
## имя иконки → номер в атласе иконок
var _icon_index: Dictionary = {}
var _font: Font
## имя → текстура иконки (res://icons), для атласа иконок и панели
var _icon_cache: Dictionary = {}
## Сколько раз пересобирались данные — для замера.
var rebuilds := 0
## Фальсификатор «glyphx»: начало буквы не сдвигается на ширину предыдущей.
var falsify_no_advance := false


func _init() -> void:
	_font = ThemeDB.fallback_font
	var i := 0
	for ch in CHARSET:
		if not _glyph.has(ch):
			_glyph[ch] = i
			_advance.append(_font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_PX).x)
			i += 1
	data_image = Image.create(COLS, ROWS, false, Image.FORMAT_RGBAF)
	data_image.fill(Color(-1, 0, 0, 0))
	data_texture = ImageTexture.create_from_image(data_image)
	icon_image = Image.create(ICON_COLS * ICON_PX, ICON_ROWS * ICON_PX, false, Image.FORMAT_RGBA8)
	icon_texture = ImageTexture.create_from_image(icon_image)


func _ready() -> void:
	# Атлас глифов рисуется один раз тем же шрифтом, что и атлас клеток.
	var rows := int(ceil(float(_glyph.size()) / GLYPH_COLS))
	glyph_viewport = SubViewport.new()
	glyph_viewport.size = Vector2i(GLYPH_COLS * GLYPH_CELL.x, rows * GLYPH_CELL.y)
	glyph_viewport.transparent_bg = true
	glyph_viewport.disable_3d = true
	glyph_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(glyph_viewport)
	var root := Control.new()
	root.size = Vector2(glyph_viewport.size)
	glyph_viewport.add_child(root)
	for ch in _glyph:
		var gi: int = _glyph[ch]
		var l := Label.new()
		l.text = ch
		l.position = Vector2((gi % GLYPH_COLS) * GLYPH_CELL.x, (gi / GLYPH_COLS) * GLYPH_CELL.y)
		l.size = Vector2(GLYPH_CELL)
		l.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		l.add_theme_font_size_override("font_size", GLYPH_PX)
		l.add_theme_color_override("font_color", Color.WHITE)
		root.add_child(l)


func glyph_texture() -> Texture2D:
	return glyph_viewport.get_texture() if glyph_viewport != null else null


func glyph_rows() -> int:
	return int(ceil(float(_glyph.size()) / GLYPH_COLS))


## Текстура иконки по имени (null — нет такой).
func icon(name: String) -> Texture2D:
	if name == "":
		return null
	if not _icon_cache.has(name):
		var path := "res://icons/%s.svg" % name
		_icon_cache[name] = load(path) if ResourceLoader.exists(path) else null
	return _icon_cache[name]


## Номер иконки; новая иконка дорисовывается в атлас иконок.
func icon_index(name: String) -> int:
	if name == "":
		return -1
	if _icon_index.has(name):
		return _icon_index[name]
	var tex: Texture2D = icon(name)
	if tex == null or _icon_index.size() >= ICON_COLS * ICON_ROWS:
		return -1
	var idx := _icon_index.size()
	_icon_index[name] = idx
	var img := tex.get_image()
	if img != null:
		img.convert(Image.FORMAT_RGBA8)
		if img.get_size() != Vector2i(ICON_PX, ICON_PX):
			img.resize(ICON_PX, ICON_PX)
		icon_image.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i((idx % ICON_COLS) * ICON_PX, (idx / ICON_COLS) * ICON_PX))
		icon_texture.update(icon_image)
	return idx


## Раскладка подписи: строки по словам в TEXT_WIDTH, не больше LINES, с многоточием.
## Возвращает [[ [глиф, x, ширина], … ] на строку] и ширины строк.
func layout(text: String) -> Dictionary:
	var lines: Array = []
	var words := text.split(" ", false)
	var cur := ""
	var wi := 0
	while wi < words.size():
		var w: String = words[wi]
		var trial := w if cur == "" else cur + " " + w
		if _width(trial) <= TEXT_WIDTH or cur == "":
			cur = trial
			wi += 1
		else:
			lines.append(cur)
			cur = ""
			if lines.size() == LINES:
				break
	if cur != "" and lines.size() < LINES:
		lines.append(cur)
	var truncated := wi < words.size()
	var out: Array = []
	var widths: Array = []
	for li in lines.size():
		var s: String = lines[li]
		if li == lines.size() - 1 and truncated:
			s += "…"
		while (_width(s) > TEXT_WIDTH or s.length() > LINE_CHARS) and s.length() > 2:
			s = s.substr(0, s.length() - 2) + "…"
		var chars: Array = []
		var x := 0.0
		for ch in s:
			var g: int = _glyph.get(ch, _glyph["?"])
			chars.append([g, x, _advance[g]])
			if not falsify_no_advance:
				x += _advance[g]
		out.append(chars)
		widths.append(x if not falsify_no_advance else _width(s))
	return {"lines": out, "widths": widths}


func _width(s: String) -> float:
	var x := 0.0
	for ch in s:
		x += _advance[_glyph.get(ch, _glyph["?"])]
	return x


## Строка данных пункта: заголовок (иконка, ширины двух строк, число строк) и буквы.
func set_row(row: int, text: String, icon: int) -> void:
	for c in COLS:
		data_image.set_pixel(c, row, Color(-1, 0, 0, 0))
	var lay := layout(text)
	var widths: Array = lay["widths"]
	data_image.set_pixel(0, row, Color(float(icon), widths[0] if widths.size() > 0 else 0.0,
			widths[1] if widths.size() > 1 else 0.0, float(widths.size())))
	var lines: Array = lay["lines"]
	for li in lines.size():
		var chars: Array = lines[li]
		for j in chars.size():
			var e: Array = chars[j]
			data_image.set_pixel(1 + li * LINE_CHARS + j, row, Color(float(e[0]), e[1], e[2], 1.0))


## Строки страницы и служебных ячеек; одна выгрузка текстуры.
func set_items(texts: Array, icons: Array, back_text: String) -> void:
	for i in mini(texts.size(), MAX_ITEMS):
		set_row(i, texts[i], icon_index(icons[i]))
	set_row(BACK_ROW, back_text, icon_index("back" if back_text == "Назад" else "cancel"))
	set_row(NEXT_ROW, "Дальше", icon_index("next"))
	set_row(PREV_ROW, "Раньше", icon_index("prev"))
	data_texture.update(data_image)
	rebuilds += 1
