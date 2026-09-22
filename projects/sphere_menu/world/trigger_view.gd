extends RefCounted

## Видимая зона триггера — первое, что появляется на слое отладки.
##
## Сейчас `Area3D` строится вовсе без меша: зон подгрузки не видно, и разметить их можно было только
## по числам в JSON. При этом зона работает — скрытая маской камеры, она продолжает грузить
## интерьер, потому что маска отсекает отрисовку, а не физику.
##
## Материал **один на все зоны** и кэшируется на классе: принцип проекта — материалы общие, не на
## объект (цена отрисовки измерена по вызовам). В счётчик `colors` загрузчика он не попадает,
## иначе фальсификатор «levelflat», который следит за числом материалов, перестал бы быть точечным.

const Layers := preload("res://world/layers.gd")

## Цвет зоны: голубоватая прозрачная коробка. Не измерение, а выбор — лишь бы отличалась от
## геометрии уровня и читалась изнутри.
const COLOR := Color(0.25, 0.85, 1.0, 0.18)

## Фальсификатор «triggergame»: коробка зоны строится на слое игры — игрок видит разметку автора.
static var falsify_game_layer := false

static var _mat: StandardMaterial3D = null


static func material() -> StandardMaterial3D:
	if _mat != null:
		return _mat
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = COLOR
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	# Зона видна и изнутри: человек чаще всего стоит в ней, когда разбирается, почему она сработала.
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat.no_depth_test = false
	return _mat


## Коробка по размеру зоны, уже на слое отладки.
static func build(size: Vector3) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.name = "TriggerView"
	mi.mesh = mesh
	mi.material_override = material()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.layers = Layers.bit("game" if falsify_game_layer else "debug")
	return mi
