extends MeshInstance3D

## Квад виньетки перед камерой. Сила приходит из locomotion/vignette.gd (чистая математика).

const SHADER := preload("res://locomotion/vignette.gdshader")
## Насколько близко к глазам и какого размера квад: 0.3 м перед камерой перекрывает поле зрения.
const DISTANCE := 0.3
const SIZE := Vector2(1.2, 0.9)


func setup(camera: Node3D) -> void:
	var quad := QuadMesh.new()
	quad.size = SIZE
	mesh = quad
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	material_override = mat
	position = Vector3(0, 0, -DISTANCE)
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visible = false
	camera.add_child(self)


func apply(strength: float) -> void:
	visible = strength > 0.01
	if visible:
		(material_override as ShaderMaterial).set_shader_parameter("strength", strength)
