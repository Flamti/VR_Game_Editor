extends Node3D

## Сетка пола (этап Ф3, просьба владельца после сессии 13): линии на уровне НАСТОЯЩЕГО пола.
##
## Пространство отсчёта у нас stage (умолчание Godot), значит пол — это нулевая высота
## `XROrigin3D`, и сетка на этой плоскости совпадает с полом без подгонки. Квад висит на y=0
## пространства XR и едет за человеком по горизонтали; линии шейдер рисует в мировых координатах,
## поэтому сетка на месте не «скользит».
##
## Сетка живёт в МИРЕ, а не под `XROrigin3D`. До этапа Ф3 origin стоял на месте и разницы не было;
## с появлением тела игрока origin поехал вместе с человеком — и сетка уезжала с ним, в том числе
## ВВЕРХ на платформы (сессия 17: «при перемещении сетка перемещается тоже, сетка должна быть
## зафиксирована»). Плоскость пола от этого переставала совпадать с полом уровня.
##
## Две сетки: «вокруг меня» (круг видимости едет за головой, сами линии стоят) и «в начале
## координат» (привязана к нулю мира) — обе включаются настройками. «Рентген» — материал без проверки глубины: сетка видна сквозь
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
## Насколько сетка приподнята над нулём уровня, м.
##
## Пол стартовой локации кладёт свою ВЕРХНЮЮ грань ровно на Y = 0.000 (`start_location.json`: floor
## pos −0.1, size 0.2), и плоскость сетки лежала там же. Две копланарные поверхности на 100×100 м —
## это совпадение глубины бит в бит, и кто из них окажется ближе, решает точность вычислений, а в
## шлеме ещё и своя матрица на каждый глаз: сетка мерцала (владелец, 2026-09-23).
##
## Это форма, а не измерение: миллиметры выбраны так, чтобы уйти от копланарности и не дать сетке
## «висеть» над полом заметно для глаза. Отвергнуто: рентген (`grid_xray`) — он снимает проверку
## глубины насовсем, и сетка становится видна сквозь дома, а это отдельный режим осмотра, а не
## обычный вид; и сетка по геометрии пола — она отложена в `docs/design/space-and-light.md` §3 и
## требует своего замера.
const LIFT_M := 0.004
## Фальсификатор «gridflush»: подъёма нет — сетка снова ложится ровно на верхнюю грань пола, и
## возвращается мерцание.
static var falsify_flush := false

## Насколько сетка стоит выше нуля уровня сейчас. Отдельной функцией, чтобы «подъём есть» можно было
## опровергнуть: константу фальсификатором не подменить.
static func lift() -> float:
	return 0.0 if falsify_flush else LIFT_M


var around: MeshInstance3D
var origin_grid: MeshInstance3D
## За кем едет сетка «вокруг меня» (XRCamera3D).
var head: Node3D
## Фальсификатор «gridfollow»: сетка не едет за человеком — у края обрывается пустотой.
var falsify_no_follow := false
## Фальсификатор «gridride»: сетка снова берёт ЛОКАЛЬНУЮ позицию головы, то есть едет вместе с
## origin (дефект сессии 17) — на платформе она уходит вверх вместе с человеком.
var falsify_ride := false
## Текущий вид сетки: «fixed» не даёт ей ехать вовсе.
var _mode := "around"


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
	_mode = mode
	var radius := float(settings.get_value("grid_radius_m"))
	var scene_wide := mode == "scene"
	around.visible = mode != "off"
	# «На месте»: квад стоит на нуле уровня и круг видимости не двигается — сетка как инструмент
	# редактора, который не ходит за человеком.
	if mode == "fixed":
		around.position = Vector3(0.0, lift(), 0.0)
		(around.material_override as ShaderMaterial).set_shader_parameter("center", Vector3.ZERO)
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
		# Свечение сетки — своя настройка: сетка это инструмент редактора, и атмосфера сцены
		# (свечение, будущие эффекты уровня) на неё не влияет (решение владельца, сессия 14).
		mat.set_shader_parameter("emission_boost", 1.0 if bool(settings.get_value("grid_glow")) else 0.0)
		mat.shader = SHADER_XRAY if bool(settings.get_value("grid_xray")) else SHADER
	origin_grid.position = Vector3(0.0, lift(), 0.0)
	(origin_grid.material_override as ShaderMaterial).set_shader_parameter("center", Vector3.ZERO)


## Кадр: у сетки «вокруг меня» за головой едет круг видимости. Позиция берётся МИРОВАЯ: локальная
## (в origin) не меняется при ходьбе тела, и сетка вместо этого ездила вместе с человеком.
## Высота — ноль уровня всегда (плюс `LIFT_M`): на платформе сетка остаётся на полу, а не
## поднимается с ним. Центр затухания считается по плоскости нуля — подъём на него не влияет.
func follow() -> void:
	if head == null or not around.visible or falsify_no_follow or _mode == "fixed":
		return
	var p := head.global_position if not falsify_ride else head.position
	around.global_position = Vector3(p.x, lift(), p.z)
	(around.material_override as ShaderMaterial).set_shader_parameter("center", around.global_position)


## Где сейчас центр затухания — для проверок. Параметр не задан (сетка ещё не ехала) — начало
## координат: шейдер в этом случае берёт своё умолчание, тоже ноль.
func center_of(mi: MeshInstance3D) -> Vector3:
	var v: Variant = (mi.material_override as ShaderMaterial).get_shader_parameter("center")
	return v if v is Vector3 else Vector3.ZERO
