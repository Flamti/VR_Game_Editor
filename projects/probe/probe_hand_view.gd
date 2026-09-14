extends RefCounted
class_name ProbeHandView

## Визуализация рук для фазы R.
##
## В иммерсивном приложении Quest сам руки не рисует — без этого человек в шлеме
## жестикулирует вслепую (замечание владельца по прогону 12). Два слоя:
##
##   суставы — 26 шариков на руку из XRHandTracker. Ассетов не требует и
##             показывает ровно то, что видит прибор: если шарик серый, сустав
##             не отслеживается, и признаки по нему недостоверны;
##   сетка   — модель руки от рантайма Meta: OpenXRFbHandTrackingMesh плагина +
##             XRHandModifier3D Godot, схема узлов по образцу плагина 5.1.0
##             (samples/meta-hand-tracking-sample/main.tscn). Требует
##             xr/openxr/extensions/meta/hand_tracking_mesh. Если расширения нет,
##             остаются суставы, и это называется в отчёте.

const HAND_TRACKERS := ["/user/hand_tracker/left", "/user/hand_tracker/right"]
const JOINT_RADIUS := 0.004
const COLOR_TRACKED := Color(0.3, 1.0, 0.5)
const COLOR_LOST := Color(0.5, 0.5, 0.5)

var _joints: Array[MultiMeshInstance3D] = []
## рука → "ready" | "unavailable" | "" (сигнал ещё не пришёл) | "нет класса"
var mesh_state: Dictionary = {}


func setup(origin: Node3D) -> void:
	for h in HAND_TRACKERS.size():
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		var sphere := SphereMesh.new()
		sphere.radius = JOINT_RADIUS
		sphere.height = JOINT_RADIUS * 2.0
		sphere.radial_segments = 8
		sphere.rings = 4
		mm.mesh = sphere
		mm.instance_count = XRHandTracker.HAND_JOINT_MAX
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		var mat := StandardMaterial3D.new()
		mat.vertex_color_use_as_albedo = true
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mmi.material_override = mat
		# Суставы трекера — в пространстве XROrigin3D, значит и шарики — его дети.
		origin.add_child(mmi)
		_joints.append(mmi)
		_add_mesh(origin, h)


func _add_mesh(origin: Node3D, hand: int) -> void:
	var key := "L" if hand == 0 else "R"
	if not ClassDB.class_exists("OpenXRFbHandTrackingMesh"):
		mesh_state[key] = "нет класса"
		return
	mesh_state[key] = ""
	var node := XRNode3D.new()
	node.tracker = HAND_TRACKERS[hand]
	origin.add_child(node)
	var mesh: Node3D = ClassDB.instantiate("OpenXRFbHandTrackingMesh")
	mesh.set("hand", hand)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.8, 0.7, 0.6)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.set("material", mat)
	if mesh.has_signal("openxr_fb_hand_tracking_mesh_ready"):
		mesh.connect("openxr_fb_hand_tracking_mesh_ready", func(): mesh_state[key] = "ready")
	if mesh.has_signal("openxr_fb_hand_tracking_mesh_unavailable"):
		mesh.connect("openxr_fb_hand_tracking_mesh_unavailable", func(): mesh_state[key] = "unavailable")
	node.add_child(mesh)
	var mod := XRHandModifier3D.new()
	mod.hand_tracker = HAND_TRACKERS[hand]
	mesh.add_child(mod)


func update() -> void:
	for h in HAND_TRACKERS.size():
		var ht := XRServer.get_tracker(HAND_TRACKERS[h]) as XRHandTracker
		var mmi := _joints[h]
		var has := ht != null and ht.has_tracking_data
		mmi.visible = has
		if not has:
			continue
		var mm := mmi.multimesh
		for j in XRHandTracker.HAND_JOINT_MAX:
			mm.set_instance_transform(j, Transform3D(Basis(), ht.get_hand_joint_transform(j).origin))
			var tracked: bool = ht.get_hand_joint_flags(j) & XRHandTracker.HAND_JOINT_FLAG_POSITION_TRACKED
			mm.set_instance_color(j, COLOR_TRACKED if tracked else COLOR_LOST)


func cleanup() -> void:
	for mmi in _joints:
		mmi.queue_free()
	_joints.clear()
