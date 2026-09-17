extends Node3D

## Панель информации об активном объекте (решение владельца 2026-09-15).
##
## «Орнамент» шара по образцу visionOS: прикреплена к шару, лицом к пользователю,
## сторона — настройка (слева-сверху / справа / над шаром). Показывает иконку, имя,
## тип, размер и дату, путь, предпросмотр, подсказку режима, тост с отменой.
## В мастере настройки тот же вьюпорт показывает шаг мастера.
##
## Содержимое живёт в ScrollContainer: длинное имя, глубокий путь и подсказка не
## влезали и обрезались по clip_text (отзыв сессии 3). Прокрутка — три способа
## (решение владельца 2026-09-16): правый стик, кнопки ▲/▼ и перетаскивание лучом.
## Тост вне прокрутки: это уведомление, а не содержимое.
##
## Отрисовка — SubViewport на квад; перерисовка только при смене содержимого и на
## кадрах, где прокрутка сдвинулась.

const PANEL_MAT := preload("res://menu/panel_material.tres")
const Item := preload("res://menu/item.gd")
const K := Item.Kind

const VIEW_SIZE := Vector2i(512, 640)
## Размер квада, м: +15% к шагу 1б по отзыву владельца (сессия 2026-09-15), пропорция
## вьюпорта 512×640 сохранена.
const QUAD := Vector2(0.1725, 0.215625)
const TOAST_MS := 5000

## Окно прокрутки — во всю ширину панели: колонка кнопок справа съедала 80 px
## содержимого (отзыв сессии 5). Кнопки ▲/▼ переехали в нижнюю строку, в правый угол,
## и стоят там в обоих режимах; крупная цель ≥ 56 px ≈ 19 мм на кваде (Meta).
const SCROLL_RECT := Rect2(16, 14, 480, 548)
const SCROLL_BTN := Vector2(56, 56)
## Места кнопок ▲/▼ в нижней строке.
const UP_POS := Vector2(380, 566)
const DOWN_POS := Vector2(440, 566)
## Фальсификатор «arrows»: кнопки возвращаются колонкой справа, поверх содержимого.
const UP_POS_COLUMN := Vector2(440, 14)
const DOWN_POS_COLUMN := Vector2(440, 506)
## Доля окна, на которую двигает одна кнопка.
const PAGE_SHARE := 0.6

var viewport: SubViewport
var quad: MeshInstance3D
var _scroll: ScrollContainer
var _box: VBoxContainer
var _up_btn: Button
var _down_btn: Button
var _icon: TextureRect
var _title: Label
var _meta: Label
var _path: Label
var _preview: TextureRect
var _hint: Label
var _toast: Label
var _thumbs: Dictionary = {}
var _toast_until := 0
var _last_key := ""
## Остаток дробной прокрутки: scroll_vertical — целые пиксели, и медленный стик
## иначе не сдвигал бы панель вовсе.
var _scroll_frac := 0.0
## Фальсификатор «scroll» дымового прогона: остаток доли пикселя не копится — медленный
## стик перестаёт двигать панель вовсе.
var falsify_no_frac := false
## Фальсификатор «arrows»: кнопки снова колонкой справа, поверх содержимого.
var falsify_arrow_column := false
## Чем двигали панель в последний раз: «stick», «button» или «drag» — для журнала.
var scroll_how := ""
var renders := 0


func _ready() -> void:
	viewport = SubViewport.new()
	viewport.size = VIEW_SIZE
	viewport.transparent_bg = false
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(viewport)

	var bg := Panel.new()
	bg.size = Vector2(VIEW_SIZE)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.10, 0.13, 1)
	sb.set_corner_radius_all(24)
	sb.border_color = Color(0.35, 0.42, 0.55)
	sb.set_border_width_all(3)
	bg.add_theme_stylebox_override("panel", sb)
	viewport.add_child(bg)

	_scroll = make_scroll(SCROLL_RECT)
	viewport.add_child(_scroll)
	_box = VBoxContainer.new()
	_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_box.add_theme_constant_override("separation", 10)
	# Контейнер раскладывает детей ОТЛОЖЕННО, кадром позже смены содержимого. Без этой
	# связи панель рисовалась бы один раз — в кадре, где дети ещё в нуле, — и так и
	# висела бы сломанной: перерисовка идёт только по _dirty (UPDATE_ONCE).
	_box.sort_children.connect(_dirty)
	_scroll.add_child(_box)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	_box.add_child(head)
	_icon = _rect(Vector2(64, 64))
	head.add_child(_icon)
	_title = _label(34, Color.WHITE)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)

	_meta = _label(22, Color(0.75, 0.80, 0.90))
	_box.add_child(_meta)
	_path = _label(20, Color(0.60, 0.68, 0.80))
	_box.add_child(_path)
	_preview = _rect(Vector2(400, 300))
	_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_box.add_child(_preview)
	_hint = _label(20, Color(0.80, 0.80, 0.80))
	_box.add_child(_hint)

	_up_btn = _scroll_button("▲", -1)
	viewport.add_child(_up_btn)
	_down_btn = _scroll_button("▼", 1)
	viewport.add_child(_down_btn)

	_toast = Label.new()
	_toast.position = Vector2(24, 566)
	_toast.size = Vector2(352, 60)    # правее — кнопки ▲/▼
	_toast.autowrap_mode = TextServer.AUTOWRAP_WORD
	_toast.clip_text = true
	_toast.add_theme_font_size_override("font_size", 22)
	_toast.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	viewport.add_child(_toast)

	quad = MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = QUAD
	quad.mesh = qm
	add_child(quad)
	var mat: StandardMaterial3D = PANEL_MAT
	mat.albedo_texture = viewport.get_texture()
	qm.material = mat


## Окно прокрутки: без горизонтали, полоса прокрутки места содержимого не отнимает
## сверх своей ширины — ScrollContainer вычитает её из области детей
## (godot/scene/gui/scroll_container.cpp:400), поверх текста она не рисуется.
static func make_scroll(rect: Rect2) -> ScrollContainer:
	var sc := ScrollContainer.new()
	sc.position = rect.position
	sc.size = rect.size
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	# Штатные подсказки «дальше есть» выключены: это текстуры ПОВЕРХ верхней и нижней
	# полос содержимого (scroll_container.cpp:676) штатного чёрного цвета — они и
	# закрывали первые и последние строки (отзыв сессии 5). «Дальше есть» показывают
	# сами стрелки: та, в чью сторону ехать некуда, гаснет.
	sc.scroll_hint_mode = ScrollContainer.SCROLL_HINT_MODE_DISABLED
	sc.mouse_filter = Control.MOUSE_FILTER_PASS
	sc.get_v_scroll_bar().custom_minimum_size = Vector2(12, 0)
	return sc


func _rect(size: Vector2) -> TextureRect:
	var t := TextureRect.new()
	t.custom_minimum_size = size
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


## Метка содержимого: растёт по тексту (внутри прокрутки обрезать нечем).
func _label(font: int, color: Color) -> Label:
	var l := Label.new()
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	l.clip_text = false
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", font)
	l.add_theme_color_override("font_color", color)
	return l


func _scroll_button(text: String, dir: int) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = SCROLL_BTN
	b.size = SCROLL_BTN
	b.focus_mode = Control.FOCUS_NONE
	b.visible = false
	b.add_theme_font_size_override("font_size", 30)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.20, 0.23, 0.30)
	normal.set_corner_radius_all(10)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.32, 0.38, 0.52)
	var down := normal.duplicate() as StyleBoxFlat
	down.bg_color = Color(0.55, 0.45, 0.20)
	var off := normal.duplicate() as StyleBoxFlat
	off.bg_color = Color(0.14, 0.15, 0.18)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", down)
	b.add_theme_stylebox_override("hover_pressed", down)
	b.add_theme_stylebox_override("disabled", off)
	b.add_theme_color_override("font_disabled_color", Color(0.38, 0.41, 0.47))
	b.pressed.connect(func(): scroll_page(dir))
	return b


func _dirty() -> void:
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	renders += 1


# --- прокрутка ---------------------------------------------------------------------

## Окно, которое прокручивается сейчас. Редактор (menu/ui_panel.gd) подменяет своим.
func active_scroll() -> ScrollContainer:
	return _scroll


func scroll_max() -> int:
	var sc := active_scroll()
	if sc == null or not sc.visible:
		return 0
	var bar := sc.get_v_scroll_bar()
	return maxi(0, int(bar.max_value - bar.page))


func scroll_pos() -> int:
	var sc := active_scroll()
	return sc.scroll_vertical if sc != null else 0


func scrollable() -> bool:
	return scroll_max() > 0


## Сдвиг на px пикселей (вниз — положительные). true — положение изменилось.
func scroll_by(px: float) -> bool:
	var sc := active_scroll()
	if sc == null or not sc.visible:
		return false
	var top := scroll_pos()
	_scroll_frac += px
	var whole := int(_scroll_frac)
	_scroll_frac -= whole
	if falsify_no_frac:
		whole = int(px)
		_scroll_frac = 0.0
	if whole == 0:
		return false
	sc.scroll_vertical = clampi(top + whole, 0, scroll_max())
	if sc.scroll_vertical == top:
		return false
	_sync_scroll_ui()
	_dirty()
	return true


## Кнопка ▲/▼: dir −1 вверх, +1 вниз.
func scroll_page(dir: int) -> bool:
	_scroll_frac = 0.0
	scroll_how = "button"
	var sc := active_scroll()
	if sc == null:
		return false
	return scroll_by(signf(dir) * sc.size.y * PAGE_SHARE)


func scroll_reset() -> void:
	_scroll_frac = 0.0
	scroll_how = ""    # сброс не журналируется как прокрутка
	var sc := active_scroll()
	if sc != null and sc.scroll_vertical != 0:
		sc.scroll_vertical = 0
	_sync_scroll_ui()


## Кнопки видны только когда есть что прокручивать: иначе они занимали бы угол
## панели и перехватывали луч у ячеек шара под ней. Место — своей колонкой справа
## от активного окна (у информации и у итога мастера окна разные).
func _sync_scroll_ui() -> void:
	if _up_btn == null:
		return
	var sc := active_scroll()
	var on := sc != null and sc.visible and scroll_max() > 0
	var up_pos := UP_POS_COLUMN if falsify_arrow_column else UP_POS
	var down_pos := DOWN_POS_COLUMN if falsify_arrow_column else DOWN_POS
	if _up_btn.position != up_pos or _down_btn.position != down_pos:
		_up_btn.position = up_pos
		_down_btn.position = down_pos
		_dirty()
	# та стрелка, в чью сторону ехать некуда, гаснет — это и есть «дальше есть»
	var at := scroll_pos()
	var up_off := at <= 0
	var down_off := at >= scroll_max()
	if on != _up_btn.visible or up_off != _up_btn.disabled or down_off != _down_btn.disabled:
		_up_btn.visible = on
		_down_btn.visible = on
		_up_btn.disabled = up_off
		_down_btn.disabled = down_off
		_dirty()


## Зовётся кадром меню: раскладка контейнера доходит до полос прокрутки не в тот же
## кадр, что смена содержимого, поэтому видимость кнопок сверяется каждый кадр.
func scroll_tick() -> void:
	_sync_scroll_ui()


## Указатель на кнопке ▲/▼: нажатие на неё не должно ещё и тянуть содержимое.
func over_scroll_button(pos: Vector2) -> bool:
	if _up_btn == null or not _up_btn.visible:
		return false
	return Rect2(_up_btn.position, _up_btn.size).has_point(pos) \
			or Rect2(_down_btn.position, _down_btn.size).has_point(pos)


# --- содержимое --------------------------------------------------------------------

## Объект: item может быть null (пустая ячейка, «назад»).
func show_item(item: Item, icon: Texture2D, crumbs: PackedStringArray, hint: String, extra: String = "") -> void:
	var key := "%s|%s|%s|%s|%s" % [item.id if item != null else "", ">".join(crumbs), hint, extra, item.title if item != null else ""]
	if key == _last_key:
		return
	_last_key = key
	_icon.texture = icon
	_icon.visible = icon != null
	_path.text = " › ".join(crumbs)
	_hint.text = hint
	if item == null:
		_title.text = extra
		_meta.text = ""
		_preview.texture = null
	else:
		_title.text = item.title
		var meta := PackedStringArray()
		if item.type_label != "":
			meta.append(item.type_label)
		if item.size_kb > 0:
			meta.append("%.1f МБ" % (item.size_kb / 1024.0) if item.size_kb >= 1024 else "%d КБ" % item.size_kb)
		if item.modified != "":
			meta.append(item.modified)
		if extra != "":
			meta.append(extra)
		_meta.text = " · ".join(meta)
		_preview.texture = preview_of(item)
	_preview.visible = _preview.texture != null
	_meta.visible = _meta.text != ""
	scroll_reset()
	_dirty()


## Шаг мастера: заголовок, значение, пояснение, управление.
func show_text(title: String, value: String, body: String, hint: String) -> void:
	var key := "text|%s|%s|%s|%s" % [title, value, body, hint]
	if key == _last_key:
		return
	_last_key = key
	_icon.texture = null
	_icon.visible = false
	_title.text = title
	_meta.text = value
	_meta.visible = value != ""
	_path.text = ""
	_preview.texture = null
	_preview.visible = false
	_hint.text = body + "\n" + hint
	scroll_reset()
	_dirty()


func toast(text: String, now_ms: int) -> void:
	if text == "" or text == _toast.text:
		return
	_toast.text = text
	_toast_until = now_ms + TOAST_MS
	_dirty()


## Живёт ли сейчас сообщение: пока живёт, панель есть что показывать.
func has_toast(now_ms: int) -> bool:
	return _toast.text != "" and now_ms <= _toast_until


func tick(now_ms: int) -> void:
	if _toast.text != "" and now_ms > _toast_until:
		_toast.text = ""
		_dirty()


## Предпросмотр: изображение — сама картинка, сцена и ассет — миниатюра по id.
func preview_of(item: Item) -> Texture2D:
	if item.preview == "":
		return null
	if item.preview.begins_with("res://"):
		return load(item.preview) if ResourceLoader.exists(item.preview) else null
	if not _thumbs.has(item.id):
		_thumbs[item.id] = ImageTexture.create_from_image(_generate(item))
	return _thumbs[item.id]


## Процедурная миниатюра: у сцены — небо, земля и постройки, у ассета — фигура.
## Детерминирована по id — один объект всегда выглядит одинаково. Только заливки
## прямоугольниками: попиксельный цикл GDScript по 43 тысячам пикселей дал бы
## рывок кадра в момент, когда объект становится активным.
func _generate(item: Item) -> Image:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(item.id)
	var w := 240
	var h := 180
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	if item.kind == K.SCENE:
		var sky := Color.from_hsv(rng.randf_range(0.5, 0.65), 0.5, 0.9)
		var horizon := int(h * 0.65)
		for band in 8:
			img.fill_rect(Rect2i(0, band * horizon / 8, w, horizon / 8 + 1), sky.lerp(Color.WHITE, band / 16.0))
		img.fill_rect(Rect2i(0, horizon, w, h - horizon), Color.from_hsv(rng.randf_range(0.05, 0.35), 0.5, 0.45))
		for _i in 5:
			var bw := rng.randi_range(14, 40)
			var bh := rng.randi_range(20, 70)
			img.fill_rect(Rect2i(rng.randi_range(0, w - bw), horizon - bh, bw, bh), Color.from_hsv(rng.randf(), 0.3, 0.35))
	else:
		img.fill(Color(0.12, 0.13, 0.16))
		var col := Color.from_hsv(rng.randf(), 0.6, 0.85)
		var r := 60
		for dy in range(-r, r, 3):
			var half := int(sqrt(float(r * r - dy * dy)))
			img.fill_rect(Rect2i(w / 2 - half, h / 2 + dy, half * 2, 3), col.darkened(clampf(float(dy + r) / (2.5 * r), 0.0, 0.6)))
	return img


## Место панели относительно шара и головы: сторона из настроек, лицом к голове.
## «Верх» — из позы шлема, а не мировой: шар держат ниже головы, и на мировом верху
## базис вырождался — панель перекидывало вокруг шара от сдвига кисти (та же причина,
## что у режима «лицом к шлему», menu/hand_follow.gd).
func place(ball: Vector3, radius: float, head: Transform3D, side: String) -> void:
	var fwd := (ball - head.origin).normalized()
	var head_up := head.basis.y.normalized()
	if absf(fwd.dot(head_up)) > 0.98:
		head_up = Vector3.UP if absf(fwd.y) < 0.98 else -head.basis.z.normalized()
	var right := fwd.cross(head_up).normalized()
	var up := right.cross(fwd).normalized()
	var off: Vector3
	match side:
		"right":
			off = right * (radius + QUAD.x * 0.6) + up * 0.02
		"top":
			# по центру над шаром, нижний край чуть выше шара
			off = up * (radius + QUAD.y * 0.5 + 0.015)
		_:
			off = -right * (radius + QUAD.x * 0.5) + up * (radius * 0.6 + QUAD.y * 0.3)
	global_position = ball + off
	look_at(head.origin, up, true)
