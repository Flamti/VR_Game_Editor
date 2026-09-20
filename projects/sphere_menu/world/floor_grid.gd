extends Node3D

## Сетка пола (этап Ф3, просьба владельца после сессии 13): линии на уровне НАСТОЯЩЕГО пола.
##
## Пространство отсчёта у нас stage (умолчание Godot), значит пол — это нулевая высота
## `XROrigin3D`, и сетка на этой плоскости совпадает с полом без подгонки. Квад висит на y=0
## пространства XR и едет за человеком по горизонтали; линии шейдер рисует в мировых координатах,
## поэтому сетка на месте не «скользит».
##
## Две сетки: «вокруг меня» (следует за головой) и «в начале координат» (привязана к нулю мира) —
## обе включаются настройками. «Рентген» — материал без проверки глубины: сетка видна сквозь
## платформы, чтобы судить о совпадении с полом.
##
## Сетка «по геометрии пола» (повторяет неровности) — этап 2, когда в сцене появится сам пол:
## настройки, которая ничего не делает, здесь нет намеренно (ловушка 17).

const Settings := preload("res://menu/settings.gd")
const SHADER := preload("res://world/floor_grid.gdshader")
## «Рентген» — отдельный шейдер: режим проверки глубины задан в коде шейдера и в рантайме не меняется
## (у ShaderMaterial нет no_depth_test — это свойство обычных материалов).
const SHADER_XRAY := preload("res://world/floor_grid_xray.gdshader")
## Запас квада поверх радиуса: затухание кончается раньше края.
const MARGIN := 1.3
## «Вся сцена» — квад такого размера, м.
const SCENE_SIZE := 60.0

var around: MeshInstance3D
var origin_grid: MeshInstance3D
## За кем едет сетка «вокруг меня» (XRCamera3D).
var head: Node3D
## Фальсификатор «gridfollow»: сетка не едет за человеком — у края обрывается пустотой.
var falsify_no_follow := false


func setup(parent: Node3D, p_head: Node3D) -> void:
	head = p_head
	around = _make("FloorGridAround")
	origin_grid = _make("FloorGridOrigin")
	parent.add_child(around)
	parent.add_child(origin_grid)


func _make(name_: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name_
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	quad.orientation = PlaneMesh.FACE_Y
	mi.mesh = quad
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visible = false
	return mi


## Применить настройки: вид, размеры, цвет, прозрачность, «рентген», свечение.
func apply(settings: Settings) -> void:
	var mode: String = settings.get_value("grid_mode")
	var radius := float(settings.get_value("grid_radius_m"))
	var scene_wide := mode == "scene"
	around.visible = mode != "off"
	origin_grid.visible = mode != "off" and bool(settings.get_value("grid_origin"))
	var side := SCENE_SIZE if scene_wide else radius * 2.0 * MARGIN
	for mi in [around, origin_grid]:
		mi.scale = Vector3(side, 1.0, side)
		var mat: ShaderMaterial = mi.material_override
		mat.set_shader_parameter("line_color", Settings.GRID_COLORS[settings.get_value("grid_color")])
		mat.set_shader_parameter("cell_m", float(settings.get_value("grid_cell_cm")) / 100.0)
		mat.set_shader_parameter("thickness_m", float(settings.get_value("grid_thickness_mm")) / 1000.0)
		mat.set_shader_parameter("alpha", float(settings.get_value("grid_alpha")))
		mat.set_shader_parameter("radius_m", SCENE_SIZE * 0.5 if scene_wide else radius)
		mat.set_shader_parameter("emission_boost", 1.0 if bool(settings.get_value("space_glow")) else 0.0)
		mat.shader = SHADER_XRAY if bool(settings.get_value("grid_xray")) else SHADER
	origin_grid.position = Vector3.ZERO
	(origin_grid.material_override as ShaderMaterial).set_shader_parameter("center", Vector3.ZERO)


## Кадр: сетка «вокруг меня» едет за головой по горизонтали, оставаясь на полу.
func follow() -> void:
	if head == null or not around.visible or falsify_no_follow:
		return
	var p := head.position
	around.position = Vector3(p.x, 0.0, p.z)
	(around.material_override as ShaderMaterial).set_shader_parameter("center", around.global_position)


## Где сейчас центр затухания — для проверок. Параметр не задан (сетка ещё не ехала) — начало
## координат: шейдер в этом случае берёт своё умолчание, тоже ноль.
func center_of(mi: MeshInstance3D) -> Vector3:
	var v: Variant = (mi.material_override as ShaderMaterial).get_shader_parameter("center")
	return v if v is Vector3 else Vector3.ZERO
