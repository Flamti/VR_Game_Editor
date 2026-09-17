extends SceneTree

## Скриншот КАРТИНКОЙ: session/screenshot.gd снимает тот же мир отдельной камерой. Headless не
## рисует, поэтому снимок проверяется здесь, с дисплеем: файл записан, 1920×1080, в кадре сцена.
##
## Запуск (нужен дисплей и Vulkan, НЕ --headless):
##   godot/bin/godot.linuxbsd.editor.x86_64 --path projects/sphere_menu --rendering-method mobile \
##       --script res://tests/render_screenshot.gd [-- --falsify=noworld]
## --falsify=noworld: вьюпорт снимка со своим пустым миром — кадр пуст, проверка обязана покраснеть.

const Renderer := preload("res://menu/cell_renderer.gd")
const Globe := preload("res://menu/surface_globe.gd")
const Screenshot := preload("res://session/screenshot.gd")

## Доля пикселей цвета ячеек (насыщенных), ниже которой сцены в кадре нет. Не «непустых»:
## пустой собственный мир даёт серое небо по умолчанию — 100% непустых (первая версия
## проверки, фальсификатор noworld остался зелёным). Замер 2026-09-17: сцена 3.5%, пустой мир 0.0%.
const MIN_LIT := 0.01
const DIR := "user://test_screenshot"

var renderer: Renderer
var globe: Globe
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
	renderer = Renderer.new()
	get_root().add_child(renderer)
	globe = Globe.new(2)
	globe.assign(20)


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame == 2:
		renderer.setup()
		var codes := PackedInt32Array()
		var marks := PackedByteArray()
		for i in 20:
			codes.append(i % 8)
			marks.append(0)
		renderer.draw(globe.render_cells(), 0.1, 0.02, codes, marks, ["shot"])
	if _frame == 6:
		_shoot()
	return false


func _shoot() -> void:
	var pose := Transform3D(Basis.IDENTITY, Vector3(0, 0, 0.35))
	var res: Dictionary = await Screenshot.capture(get_root(), pose, DIR, falsify == "noworld")
	var lit := 0
	var img := Image.load_from_file(ProjectSettings.globalize_path(res["path"])) if res["ok"] else null
	if img != null:
		for y in range(0, img.get_height(), 4):
			for x in range(0, img.get_width(), 4):
				var c := img.get_pixel(x, y)
				if c.s > 0.2 and c.v > 0.08:
					lit += 1
	var share := float(lit) / float((1920 / 4) * (1080 / 4))
	var ok: bool = res["ok"] and img != null and img.get_width() == 1920 and img.get_height() == 1080 and share >= MIN_LIT
	print("render_screenshot: %s — %s, %d×%d, %d байт, цвета ячеек %.1f%% (порог %.0f%%), %d мс; сообщение: %s" % [
			"СНИМОК ЕСТЬ" if ok else "ОТКАЗ", res["path"], res["width"], res["height"], res["bytes"], share * 100.0,
			MIN_LIT * 100.0, res["ms"], Screenshot.notice(res).replace("\n", " | ")])
	print("render_screenshot: файл %s" % ProjectSettings.globalize_path(res["path"]))
	quit(0 if ok else 1)
