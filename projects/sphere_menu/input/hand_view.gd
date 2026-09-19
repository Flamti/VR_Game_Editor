extends RefCounted

## Визуализация рук в шар-меню: суставы и силуэт, видимые только пока меню ведут руки.
##
## Устроена как `projects/probe/probe_hand_view.gd` (там — прибор, фаза R), но своя: сессия 11
## (2026-09-19) показала, что при взятом контроллере точки суставов прятались, а силуэт — нет. У
## копии прибора узлы силуэта никто не держит, спрятать их снаружи нечем, а править прибор ради
## меню нельзя — копия побайтовая (SHARED_COPIES настольных проверок).
##
## Два слоя: суставы — 26 шариков на руку из XRHandTracker (серые — сустав не отслежен, признаки по
## нему недостоверны); силуэт — модель руки от рантайма Meta (OpenXRFbHandTrackingMesh плагина +
## XRHandModifier3D Godot), если класс есть.

const HAND_TRACKERS := ["/user/hand_tracker/left", "/user/hand_tracker/right"]
const JOINT_RADIUS := 0.004
const COLOR_TRACKED := Color(0.3, 1.0, 0.5)
const COLOR_LOST := Color(0.5, 0.5, 0.5)

var joints: Array[MultiMeshInstance3D] = []
## Узлы силуэта (XRNode3D на трекер руки) — их прячет set_active.
var meshes: Array[Node3D] = []
## рука → "ready" | "unavailable" | "" (сигнал ещё не пришёл) | "нет класса"
var mesh_state: Dictionary = {}
var active := false
## Фальсификатор «meshstays»: силуэт не прячется, как в сессии 11.
var falsify_mesh_stays := false


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
		joints.append(mmi)
		_add_mesh(origin, h)
	set_active(false)


func _add_mesh(origin: Node3D, hand: int) -> void:
	var key := "L" if hand == 0 else "R"
	if not ClassDB.class_exists("OpenXRFbHandTrackingMesh"):
		mesh_state[key] = "нет класса"
		return
	mesh_state[key] = ""
	var node := XRNode3D.new()
	node.tracker = HAND_TRACKERS[hand]
	# Без этого узел остаётся видимым в последней позе, когда трекер перестал отдавать данные.
	node.show_when_tracked = true
	origin.add_child(node)
	meshes.append(node)
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


## Руки ведут меню — видно всё; нет — ни суставов, ни силуэта.
func set_active(on: bool) -> void:
	active = on
	for mmi in joints:
		mmi.visible = on
	for node in meshes:
		node.visible = on or falsify_mesh_stays


## Видит ли пользователь хоть что-то от рук — для проверок.
func anything_visible() -> bool:
	for mmi in joints:
		if mmi.visible:
			return true
	for node in meshes:
		if node.visible:
			return true
	return false


func update() -> void:
	if not active:
		return
	for h in HAND_TRACKERS.size():
		var ht := XRServer.get_tracker(HAND_TRACKERS[h]) as XRHandTracker
		var mmi := joints[h]
		var has := ht != null and ht.has_tracking_data
		mmi.visible = has
		if not has:
			continue
		var mm := mmi.multimesh
		for j in XRHandTracker.HAND_JOINT_MAX:
			mm.set_instance_transform(j, Transform3D(Basis(), ht.get_hand_joint_transform(j).origin))
			var tracked: bool = ht.get_hand_joint_flags(j) & XRHandTracker.HAND_JOINT_FLAG_POSITION_TRACKED
			mm.set_instance_color(j, COLOR_TRACKED if tracked else COLOR_LOST)
