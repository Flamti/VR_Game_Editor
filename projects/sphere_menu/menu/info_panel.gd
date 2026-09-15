extends Node3D

## Панель информации об активном объекте (решение владельца 2026-09-15).
##
## «Орнамент» шара по образцу visionOS: прикреплена к шару, лицом к пользователю,
## сторона — настройка (слева-сверху / справа / над шаром). Показывает иконку, имя,
## тип, размер и дату, путь, предпросмотр, подсказку режима, тост с отменой.
## В мастере настройки тот же вьюпорт показывает шаг мастера.
##
## Отрисовка — SubViewport на квад; перерисовка только при смене содержимого.

const PANEL_MAT := preload("res://menu/panel_material.tres")
const Item := preload("res://menu/item.gd")
const K := Item.Kind

const VIEW_SIZE := Vector2i(512, 640)
## Размер квада, м: +15% к шагу 1б по отзыву владельца (сессия 2026-09-15), пропорция
## вьюпорта 512×640 сохранена.
const QUAD := Vector2(0.1725, 0.215625)
const TOAST_MS := 5000

var viewport: SubViewport
var quad: MeshInstance3D
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

	_icon = _rect(Vector2(24, 24), Vector2(64, 64))
	_title = _label(Vector2(100, 18), Vector2(390, 80), 34, Color.WHITE)
	_meta = _label(Vector2(24, 100), Vector2(464, 36), 22, Color(0.75, 0.80, 0.90))
	_path = _label(Vector2(24, 136), Vector2(464, 36), 20, Color(0.60, 0.68, 0.80))
	_preview = _rect(Vector2(56, 184), Vector2(400, 300))
	_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_hint = _label(Vector2(24, 494), Vector2(464, 70), 20, Color(0.80, 0.80, 0.80))
	_toast = _label(Vector2(24, 566), Vector2(464, 60), 22, Color(1.0, 0.85, 0.35))

	quad = MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = QUAD
	quad.mesh = qm
	add_child(quad)
	var mat: StandardMaterial3D = PANEL_MAT
	mat.albedo_texture = viewport.get_texture()
	qm.material = mat


func _rect(pos: Vector2, size: Vector2) -> TextureRect:
	var t := TextureRect.new()
	t.position = pos
	t.size = size
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	viewport.add_child(t)
	return t


func _label(pos: Vector2, size: Vector2, font: int, color: Color) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = size
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	l.clip_text = true
	l.add_theme_font_size_override("font_size", font)
	l.add_theme_color_override("font_color", color)
	viewport.add_child(l)
	return l


func _dirty() -> void:
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	renders += 1


## Объект: item может быть null (пустая ячейка, «назад»).
func show_item(item: Item, icon: Texture2D, crumbs: PackedStringArray, hint: String, extra: String = "") -> void:
	var key := "%s|%s|%s|%s|%s" % [item.id if item != null else "", ">".join(crumbs), hint, extra, item.title if item != null else ""]
	if key == _last_key:
		return
	_last_key = key
	_icon.texture = icon
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
	_dirty()


## Шаг мастера: заголовок, значение, пояснение, управление.
func show_text(title: String, value: String, body: String, hint: String) -> void:
	var key := "text|%s|%s|%s|%s" % [title, value, body, hint]
	if key == _last_key:
		return
	_last_key = key
	_icon.texture = null
	_title.text = title
	_meta.text = value
	_path.text = ""
	_preview.texture = null
	_hint.text = body + "\n" + hint
	_dirty()


func toast(text: String, now_ms: int) -> void:
	if text == "" or text == _toast.text:
		return
	_toast.text = text
	_toast_until = now_ms + TOAST_MS
	_dirty()


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
func place(ball: Vector3, radius: float, head: Transform3D, side: String) -> void:
	var fwd := (ball - head.origin).normalized()
	var right := fwd.cross(Vector3.UP).normalized()
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
	look_at(head.origin, Vector3.UP, true)
