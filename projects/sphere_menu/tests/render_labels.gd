extends SceneTree

## Сверка подписей шейдером КАРТИНКОЙ с эталоном tests/golden/labels_shader.png. Настольные
## проверки видят только раскладку букв в GDScript; собирается ли подпись в GLSL и стоит ли на
## месте — видно только в кадре. Эталон снят 2026-09-17 и тогда же сверен с прежним атласом
## «клетка на пункт» (тем же шрифтом Godot Label): белые пиксели совпали на 96% в обе стороны.
## Атлас удалён после сессии 9, эталон остаётся свидетелем. 20 пунктов на крупном глобусе,
## белые пиксели подписей сравниваются с допуском в 1 пиксель.
##
## Запуск (нужен дисплей и Vulkan, НЕ --headless):
##   godot/bin/godot.linuxbsd.editor.x86_64 --path projects/sphere_menu --rendering-method mobile \
##       --script res://tests/render_labels.gd [-- --falsify=nolabel]
## --falsify=nolabel: данные подписей пусты — сверка обязана покраснеть.
## Код возврата 0 — белые пиксели подписей совпали с эталоном не меньше чем на MIN_OVERLAP в обе стороны.
## Эталон меняется только сознательно: после правки вида подписей — новый снимок глазами и копия сюда.

const Renderer := preload("res://menu/cell_renderer.gd")
const LabelText := preload("res://menu/label_text.gd")
const Globe := preload("res://menu/surface_globe.gd")

## Доля белых пикселей подписи одного кадра, у которых в другом кадре в пределах 1 px тоже белый.
## Порог — для отличия «те же буквы на тех же местах» от «ничего/не там»; с атласом было 96%.
const MIN_OVERLAP := 0.9
const GOLDEN := "res://tests/golden/labels_shader.png"

var renderer: Renderer
var text: LabelText
var globe: Globe
var texts: Array = []
var icons: Array = []
var codes := PackedInt32Array()
var marks := PackedByteArray()
var _frame := 0
var falsify := ""


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--falsify="):
			falsify = a.get_slice("=", 1)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color.BLACK
	get_root().add_child(env)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 0, 0.24)
	cam.fov = 40.0
	get_root().add_child(cam)
	text = LabelText.new()
	get_root().add_child(text)
	renderer = Renderer.new()
	get_root().add_child(renderer)
	globe = Globe.new(2)
	globe.assign(20)
	var names := ["Файл 001", "Лес", "Замок", "Пещера", "Гавань", "Пустыня", "Башня", "Набросок моста",
			"Дуб", "Сосна", "Берёза", "Мост", "Забор", "Бочка", "Фонарь", "Закат", "Горы", "Океан",
			"Текстура камня", "Диалог"]
	for i in 20:
		texts.append(names[i])
		icons.append("file" if i % 2 == 0 else "folder")
		codes.append(i % 8)
		marks.append(0)


func _process(_delta: float) -> bool:
	_frame += 1
	var radius := 0.1
	var cell_r: float = globe.g.cell_angle() * 2.0 / sqrt(3.0) * radius
	match _frame:
		1:
			# глифы собираются в _ready — текстуры есть только кадром позже
			renderer.setup()
			renderer.set_label_text(text)
		2:
			if falsify != "nolabel":
				text.set_items(texts, icons, "Назад")
			renderer.draw(globe.render_cells(), radius, cell_r, codes, marks, ["shader"])
		10:
			var shot := get_root().get_texture().get_image()
			var dir := OS.get_user_data_dir()
			shot.save_png(dir.path_join("labels_shader.png"))
			var golden := Image.load_from_file(ProjectSettings.globalize_path(GOLDEN))
			if golden == null or golden.get_size() != shot.get_size():
				print("render_labels: ОТКАЗ ПРИБОРА — эталон %s, размер %s против кадра %s" % [GOLDEN, golden.get_size() if golden != null else "нет", shot.get_size()])
				quit(1)
				return false
			var a := _white(golden)
			var b := _white(shot)
			var ab := _overlap(a, b, shot.get_width(), shot.get_height())
			var ba := _overlap(b, a, shot.get_width(), shot.get_height())
			var ok := a.size() > 500 and b.size() > 500 and ab >= MIN_OVERLAP and ba >= MIN_OVERLAP
			print("render_labels: %s — белых пикселей эталон %d, кадр %d; совпало эталон→кадр %.0f%%, кадр→эталон %.0f%% (порог %.0f%%); снимок %s" % [
					"СОВПАЛО" if ok else "РАСХОДИТСЯ", a.size(), b.size(), ab * 100.0, ba * 100.0, MIN_OVERLAP * 100.0, dir])
			quit(0 if ok else 1)
	return false


static func _white(img: Image) -> Dictionary:
	var out := {}
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.r > 0.75 and c.g > 0.75 and c.b > 0.75:
				out[Vector2i(x, y)] = true
	return out


static func _overlap(a: Dictionary, b: Dictionary, w: int, h: int) -> float:
	if a.is_empty():
		return 0.0
	var hit := 0
	for p in a:
		var found := false
		for dy in [-1, 0, 1]:
			for dx in [-1, 0, 1]:
				if b.has(p + Vector2i(dx, dy)):
					found = true
		if found:
			hit += 1
	return float(hit) / float(a.size())
