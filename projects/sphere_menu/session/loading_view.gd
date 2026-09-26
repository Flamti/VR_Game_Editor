extends Node3D

## Экран загрузки: чёрное вокруг головы и «Загрузка» по центру взгляда (решение владельца
## 2026-09-26). Пока старт не готов — уровень не в физике, голова не трекается, пространство не
## устоялось, — человек не должен видеть мир: любой перескок позы в это время был бы виден как рывок.
## Так делает и Godot XR Tools: старт — «when the scene is loaded, but before it becomes visible».
##
## Своя сфера, а не виньетка (`locomotion/vignette_node.gd`): та — квад 1.2×0.9 м в 0.3 м перед
## глазами и затемняет края, а не весь вид; при повороте головы за её край был бы виден мир.

## Радиус сферы и расстояние до надписи, м: надпись внутри сферы, на удобной для чтения дистанции.
const RADIUS := 2.0
const TEXT_AT := 1.2
## Открытие — той же длительности, что затемнение телепорта.
const FADE_S := 0.12

## Фальсификатор «loadopen» (tests/boot_main.gd): экран не закрывается вовсе — мир виден до старта.
static var falsify_open := false

var _shell: MeshInstance3D
var _mat: StandardMaterial3D
var _label: Label3D
var _shown := false


func setup(camera: Node3D) -> void:
	name = "LoadingView"
	var sphere := SphereMesh.new()
	sphere.radius = RADIUS
	sphere.height = RADIUS * 2.0
	sphere.flip_faces = true
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.albedo_color = Color(0, 0, 0, 1)
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.no_depth_test = true
	_mat.render_priority = 100
	_shell = MeshInstance3D.new()
	_shell.mesh = sphere
	_shell.material_override = _mat
	_shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_shell)
	_label = Label3D.new()
	_label.text = "Загрузка"
	_label.font_size = 64
	_label.pixel_size = 0.0012
	_label.outline_size = 0
	_label.no_depth_test = true
	_label.render_priority = 101
	_label.position = Vector3(0, 0, -TEXT_AT)
	add_child(_label)
	visible = false
	camera.add_child(self)


func show_now() -> void:
	if falsify_open:
		return
	_shown = true
	_mat.albedo_color.a = 1.0
	_label.modulate.a = 1.0
	visible = true


## Плавно открыть мир. Без дерева (стенд) — сразу.
func hide_soft() -> void:
	_shown = false
	if not is_inside_tree():
		visible = false
		return
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_mat, "albedo_color:a", 0.0, FADE_S)
	tw.tween_property(_label, "modulate:a", 0.0, FADE_S)
	tw.chain().tween_callback(func() -> void: visible = _shown)


func is_shown() -> bool:
	return _shown
