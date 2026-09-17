extends SceneTree

## Сверка шейдерной проекции линзы с CPU-путём КАРТИНКОЙ (шаг 1з). Настольные проверки видят
## только GDScript-близнеца шейдера: GLSL headless не компилируется и не исполняется. Здесь одна
## и та же линза рисуется дважды — прежним путём (visible_cells → трансформы экземпляров) и
## шейдером (lens_mode) — и кадры сравниваются попиксельно.
##
## Запуск (нужен дисплей и Vulkan, НЕ --headless):
##   godot/bin/godot.linuxbsd.editor.x86_64 --path projects/sphere_menu --rendering-method mobile \
##       --script res://tests/render_lens.gd [-- --falsify=glsl]
## --falsify=glsl: у шейдера закрутка с обратным знаком — сверка обязана покраснеть.
## Код возврата 0 — совпало, 1 — расходится или шейдер не собрался.

const Renderer := preload("res://menu/cell_renderer.gd")
const Lens := preload("res://menu/surface_lens.gd")
const LabelText := preload("res://menu/label_text.gd")

## Доля несовпавших пикселей, при которой кадры считаются разными. Растеризация одних и тех же
## треугольников, посчитанных в float32 на GPU и в double на CPU, расходится по краям ячеек.
const MAX_DIFF := 0.01
const SIZE := Vector2i(640, 640)

var renderer: Renderer
var text: LabelText
var lens: Lens
var codes := PackedInt32Array()
var marks := PackedByteArray()
var _frame := 0
var _cpu: Image
var falsify := ""


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--falsify="):
			falsify = a.get_slice("=", 1)
	get_root().size = SIZE
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color.BLACK
	get_root().add_child(env)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 0, 0.45)
	cam.fov = 40.0
	get_root().add_child(cam)
	renderer = Renderer.new()
	get_root().add_child(renderer)
	# Настоящие подписи на каждой ячейке: без них угол подписи (text_angle) в сверку не попадал бы —
	# пустая ячейка одинакова при любом угле. Первая версия рисовала несимметричные метки в атласе
	# клеток; атлас удалён после сессии 9, подписи собирает шейдер (menu/label_text.gd).
	text = LabelText.new()
	get_root().add_child(text)
	renderer.setup()
	lens = Lens.new(0.09)
	lens.assign(60)
	lens.apply_rotation(Quaternion(Vector3(0.4, 1.0, 0.1).normalized(), 0.37))
	lens.apply_rotation(Quaternion(lens.front, 0.6))
	codes.resize(60)
	marks.resize(60)
	for i in 60:
		codes[i] = i % 8
		marks[i] = 1 if i % 7 == 0 else 0


func _process(_delta: float) -> bool:
	_frame += 1
	var radius := 0.1
	var cell_r := lens.alpha * radius
	match _frame:
		1:
			renderer.set_label_text(text)
			var names: Array = []
			var icons: Array = []
			for i in 60:
				names.append("Файл %03d" % (i + 1))
				icons.append("file")
			text.set_items(names, icons, "Назад")
		2:
			renderer.set_lens(null, radius, cell_r)
			renderer.draw(lens.visible_cells(), radius, cell_r, codes, marks, ["cpu"])
		8:
			_cpu = get_root().get_texture().get_image()
			renderer.draw_lens(lens, codes, marks, ["gpu"])
			renderer.set_lens(lens, radius, cell_r)
			if falsify == "glsl":
				(Renderer.HEX.material as ShaderMaterial).set_shader_parameter("lens_twist", -lens.twist)
		14:
			var gpu := get_root().get_texture().get_image()
			var dir := OS.get_user_data_dir()
			_cpu.save_png(dir.path_join("lens_cpu.png"))
			gpu.save_png(dir.path_join("lens_gpu.png"))
			var diff := 0
			var lit := 0
			for y in gpu.get_height():
				for x in gpu.get_width():
					var a := _cpu.get_pixel(x, y)
					var b := gpu.get_pixel(x, y)
					if a.get_luminance() > 0.02 or b.get_luminance() > 0.02:
						lit += 1
					if absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) > 0.1:
						diff += 1
			var share := float(diff) / maxf(1.0, float(lit))
			var ok := lit > 1000 and share <= MAX_DIFF
			print("render_lens: %s — закрашено %d px, расходится %d (%.2f%% закрашенного, порог %.1f%%); снимки %s" % [
					"СОВПАЛО" if ok else "РАСХОДИТСЯ", lit, diff, share * 100.0, MAX_DIFF * 100.0, dir])
			quit(0 if ok else 1)
	return false
