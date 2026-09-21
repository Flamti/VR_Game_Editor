extends RefCounted

## Взять предмет рукой (этап Ф3): грип контроллера или щипок руки рядом с объектом из группы «grab».
##
## Пока держат, предмет ведётся за рукой кинематически (физика его не роняет); при отпускании ему
## отдаётся скорость руки — иначе предмет замирает в воздухе, а брошенный куб должен лететь.
##
## Скорость руки считается по окну, как при лазанье: один кадр дрожи не должен превращаться в бросок.

const REACH_M := 0.25
const RELEASE_WINDOW_S := 0.1
## Больше этого бросок не разгоняется, м/с: защита от скачка трекинга.
const MAX_THROW := 6.0

## Фальсификатор «grabstick»: предмет не отпускается — прилипает к руке навсегда.
var falsify_sticky := false

## рука → {node, offset: Transform3D, recent: Array}
var held: Dictionary = {}


## Ближайший предмет в досягаемости: узел группы «grab» или null.
static func nearest(nodes: Array, pos: Vector3) -> Node3D:
	var best: Node3D = null
	var best_d := REACH_M
	for n in nodes:
		var d: float = (n as Node3D).global_position.distance_to(pos)
		if d < best_d:
			best_d = d
			best = n
	return best


func grab(hand: String, node: Node3D, hand_xf: Transform3D) -> void:
	if node == null or held.has(hand):
		return
	if node is RigidBody3D:
		(node as RigidBody3D).freeze = true
	held[hand] = {"node": node, "offset": hand_xf.affine_inverse() * node.global_transform, "recent": []}


## Кадр удержания: предмет едет за рукой, копится скорость для броска.
func update(hand: String, hand_xf: Transform3D, dt: float) -> void:
	if not held.has(hand) or dt <= 0.0:
		return
	var rec: Dictionary = held[hand]
	var node: Node3D = rec["node"]
	var was := node.global_position
	node.global_transform = hand_xf * (rec["offset"] as Transform3D)
	var v := (node.global_position - was) / dt
	(rec["recent"] as Array).append(v)
	if (rec["recent"] as Array).size() > int(RELEASE_WINDOW_S * 90.0):
		(rec["recent"] as Array).pop_front()


## Отпустить: предмету отдаётся средняя скорость руки за окно.
func release(hand: String) -> Vector3:
	if not held.has(hand) or falsify_sticky:
		return Vector3.ZERO
	var rec: Dictionary = held[hand]
	var node: Node3D = rec["node"]
	var sum := Vector3.ZERO
	for v in rec["recent"]:
		sum += v
	var throw_v: Vector3 = (sum / maxf(1.0, float((rec["recent"] as Array).size()))).limit_length(MAX_THROW)
	if node is RigidBody3D:
		var rb: RigidBody3D = node
		rb.freeze = false
		rb.linear_velocity = throw_v
	held.erase(hand)
	return throw_v
