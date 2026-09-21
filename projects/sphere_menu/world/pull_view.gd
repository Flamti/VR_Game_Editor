extends RefCounted

## Видимая связь при призыве предмета (просьба владельца после сессии 20: «нужна визуализация при
## наведении на предмет, выделение предмета и нить-линия к контроллеру/руке»).
##
## Две вещи: накладка на самом предмете (он светится) и нить от ладони к нему. Без нити непонятно,
## какая рука держит цель, — а рук две, и целятся они по-разному.
##
## Узлы и материалы здесь; математика нити — в `world/pull.gd` (проверяется настольно).

const Pull := preload("res://world/pull.gd")

## Цвета: наведено и зацеплено (грип нажат, предмет вот-вот полетит).
const AIM_COLOR := Color(1.0, 0.85, 0.3)
const HELD_COLOR := Color(0.45, 1.0, 0.6)

## Фальсификатор «pullnoline»: нить не строится — видно только подсветку.
static var falsify_no_line := false
## Фальсификатор «pullnohl»: предмет не выделяется — видно только нить.
static var falsify_no_highlight := false
## Фальсификатор «pullevery»: нить перестраивается каждый кадр и на новом меше, как до сессии 24.
static var falsify_every_frame := false

## Насколько должны разойтись ладонь или предмет, чтобы нить перестраивалась, м.
const MOVE_EPS := 0.01

## рука → {line: MeshInstance3D, node: Node3D}
var _shown: Dictionary = {}
var _glow: StandardMaterial3D
var _parent: Node3D


func setup(parent: Node3D) -> void:
	_parent = parent
	_glow = StandardMaterial3D.new()
	_glow.albedo_color = Color(AIM_COLOR.r, AIM_COLOR.g, AIM_COLOR.b, 0.35)
	_glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	# Растяжение на пару миллиметров: накладка видна как ореол по контуру, а не как перекраска.
	_glow.grow = true
	_glow.grow_amount = 0.006


## Показать связь руки с предметом. node == null — убрать.
func show_link(hand: String, node: Node3D, palm: Vector3, held: bool) -> void:
	var was: Dictionary = _shown.get(hand, {})
	if node == null or not is_instance_valid(node):
		_clear(hand)
		return
	if was.get("node", null) != node:
		_clear(hand)
		if not falsify_no_highlight and node is GeometryInstance3D:
			(node as GeometryInstance3D).material_overlay = _glow
		_shown[hand] = {"node": node, "line": _line()}
	var link: Dictionary = _shown[hand]
	var line: MeshInstance3D = link.get("line", null)
	if line == null:
		return
	var color := HELD_COLOR if held else AIM_COLOR
	if link.get("held", null) != held:
		link["held"] = held
		(line.material_override as StandardMaterial3D).albedo_color = color
		_glow.albedo_color = Color(color.r, color.g, color.b, 0.35)
	# Перестраиваем, только когда ладонь или предмет РАЗОШЛИСЬ: раньше `ImmediateMesh` создавался
	# заново каждый кадр вместе с массивом точек (сессия 24 — CPU+скрипты вдвое против обычного).
	var to: Vector3 = node.global_position
	if not falsify_every_frame and palm.distance_to(link.get("palm", Vector3(9e9, 0, 0))) < MOVE_EPS \
			and to.distance_to(link.get("to", Vector3(9e9, 0, 0))) < MOVE_EPS:
		return
	link["palm"] = palm
	link["to"] = to
	# Меш один на всю жизнь связи: у ImmediateMesh для этого есть clear_surfaces().
	var im: ImmediateMesh = line.mesh
	if im == null or falsify_every_frame:
		im = ImmediateMesh.new()
		line.mesh = im
	else:
		im.clear_surfaces()
	im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for p in Pull.thread(palm, to):
		im.surface_add_vertex(line.to_local(p))
	im.surface_end()


func hide_all() -> void:
	for hand in _shown.keys():
		_clear(hand)


## Что сейчас показано этой рукой — для проверок.
func linked(hand: String) -> Node3D:
	return _shown.get(hand, {}).get("node", null)


func _line() -> MeshInstance3D:
	if falsify_no_line:
		return null
	var mi := MeshInstance3D.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = AIM_COLOR
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_parent.add_child(mi)
	return mi


func _clear(hand: String) -> void:
	var was: Dictionary = _shown.get(hand, {})
	var node: Node3D = was.get("node", null)
	if node != null and is_instance_valid(node) and node is GeometryInstance3D:
		(node as GeometryInstance3D).material_overlay = null
	var line: MeshInstance3D = was.get("line", null)
	if line != null and is_instance_valid(line):
		line.queue_free()
	_shown.erase(hand)
