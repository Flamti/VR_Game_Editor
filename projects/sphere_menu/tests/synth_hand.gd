extends RefCounted

## Синтетическая рука для проверок без шлема (шаг 1к): настольных (run_tests.gd) и дымового
## прогона (smoke_menu.gd).
##
## Суставы, нужные признакам и позе, строятся из запястья, направления пальцев и нормали ладони.
## Сгиб каждого пальца подбирается бисекцией под заданное значение признака
## (ProbeHandFeatures.curl), так что трассы пишутся прямо в числах паспорта.

const Features := preload("res://probe_hand_features.gd")

const FLAGS := XRHandTracker.HAND_JOINT_FLAG_POSITION_VALID | XRHandTracker.HAND_JOINT_FLAG_POSITION_TRACKED \
		| XRHandTracker.HAND_JOINT_FLAG_ORIENTATION_VALID | XRHandTracker.HAND_JOINT_FLAG_ORIENTATION_TRACKED
const SEG := 0.025
const SIDE := {"index": 0.02, "middle": 0.005, "ring": -0.01, "pinky": -0.025}
## Кончик большого далеко от указательного — щипка нет.
const FAR := 0.06


static func curls(c: float = 0.02) -> Dictionary:
	return {"index": c, "middle": c, "ring": c, "pinky": c}


## Палец из трёх звеньев: каждое следующее повёрнуто к ладони на a больше предыдущего.
static func _finger(base: Vector3, fwd: Vector3, up: Vector3, a: float) -> Array:
	var axis := fwd.cross(up).normalized()
	var js := [base]
	var p := base + fwd * SEG
	js.append(p)
	for i in [1, 2]:
		p += fwd.rotated(axis, a * i) * SEG
		js.append(p)
	return js


static func _finger_for_curl(base: Vector3, fwd: Vector3, up: Vector3, c: float) -> Array:
	var lo := 0.0
	var hi := 1.6
	for _i in 40:
		var mid := (lo + hi) * 0.5
		var js := _finger(base, fwd, up, mid)
		if 1.0 - (js[0] as Vector3).distance_to(js[3]) / (SEG * 3.0) < c:
			lo = mid
		else:
			hi = mid
	return _finger(base, fwd, up, (lo + hi) * 0.5)


## c — сгиб по пальцам (index, middle, ring, pinky); pinch_m — кончик большого от кончика
## указательного. up — нормаль ладони наружу; fwd — вдоль пальцев. Всё в пространстве трекера.
static func pose(ht: XRHandTracker, is_left: bool, wrist: Vector3, fwd: Vector3, up: Vector3,
		c: Dictionary, pinch_m: float = FAR) -> void:
	fwd = fwd.normalized()
	up = (up - fwd * up.dot(fwd)).normalized()
	# От мизинца к указательному: у правой ладонью вверх — вправо, у левой — влево.
	var side := up.cross(fwd) if is_left else fwd.cross(up)
	ht.has_tracking_data = true
	for j in XRHandTracker.HAND_JOINT_MAX:
		ht.set_hand_joint_flags(j, FLAGS)
		ht.set_hand_joint_transform(j, Transform3D(Basis(), wrist))
	ht.set_hand_joint_transform(XRHandTracker.HAND_JOINT_PALM, Transform3D(Basis(), wrist + fwd * 0.04))
	for f in SIDE:
		var base: Vector3 = wrist + fwd * 0.08 + side * float(SIDE[f])
		var js := _finger_for_curl(base, fwd, up, float(c.get(f, 0.02)))
		var ids: Array = Features.FINGERS[f]
		for i in ids.size():
			ht.set_hand_joint_transform(ids[i], Transform3D(Basis(), js[i]))
	var itip := ht.get_hand_joint_transform(XRHandTracker.HAND_JOINT_INDEX_FINGER_TIP).origin
	ht.set_hand_joint_transform(XRHandTracker.HAND_JOINT_THUMB_TIP, Transform3D(Basis(), itip + side * pinch_m))


## Правая рука, вытянутая кончиком указательного в точку tip (пространство трекера): кисть
## целиком сдвинута так, чтобы кончик оказался там, пальцы — вдоль fwd.
static func point_at(ht: XRHandTracker, tip: Vector3, fwd: Vector3, up: Vector3) -> void:
	pose(ht, false, Vector3.ZERO, fwd, up, curls())
	var shift := tip - ht.get_hand_joint_transform(XRHandTracker.HAND_JOINT_INDEX_FINGER_TIP).origin
	for j in XRHandTracker.HAND_JOINT_MAX:
		ht.set_hand_joint_transform(j, Transform3D(Basis(), ht.get_hand_joint_transform(j).origin + shift))
