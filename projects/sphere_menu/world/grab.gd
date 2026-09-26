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
## Фальсификатор «handgreedy»: занятая рука берёт ещё один предмет — их становится два на руку.
var falsify_greedy := false
## Фальсификатор «deadhand»: узел пропал, но запись о нём в руке ОСТАЁТСЯ — рука занята мёртвым
## предметом навсегда. Нарочно не снимает `is_instance_valid`: сними проверку — и фальсифицированный
## прогон падал бы в движке вместо точечного покраснения.
var falsify_keep_dead := false
## Фальсификатор «heldsolid»: предмет в руке остаётся препятствием и выталкивает человека (дефект
## сессии 31: «они сталкиваются, из-за чего всего пользователя мотает туда-сюда»).
var falsify_held_solid := false

## рука → {node, offset: Transform3D, recent: Array, layer: int}
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


## Взять предмет. Возвращает, состоялось ли: рука, которая уже держит, ЗАНЯТА (решение владельца
## 2026-09-22). Раньше отказ был молчаливым — ни возврата, ни записи, и вызывающий писал в журнал
## «взят», когда ничего не произошло.
func grab(hand: String, node: Node3D, hand_xf: Transform3D) -> bool:
	if node == null:
		return false
	if held.has(hand) and not falsify_greedy:
		return false
	if node is RigidBody3D:
		(node as RigidBody3D).freeze = true
	# Предмет в руке НЕ участвует в столкновениях. Он ведётся присваиванием трансформа, то есть
	# протыкает всё на своём пути, а замороженное тело — статическое препятствие: оказавшись внутри
	# капсулы, оно выталкивает человека, и два предмета в двух руках мотают его вдвоём (сессия 31).
	# Отвергнуто: свой слой для тела игрока и выборочная маска — это правка всех тел сцены ради
	# одного случая; плата за нынешнее решение в том, что предмет в руке проходит сквозь стены.
	var layer := 0
	if node is CollisionObject3D and not falsify_held_solid:
		var co: CollisionObject3D = node
		layer = co.collision_layer
		co.collision_layer = 0
	held[hand] = {"node": node, "offset": hand_xf.affine_inverse() * node.global_transform,
			"recent": [], "layer": layer}
	return true


## Кадр удержания: предмет едет за рукой, копится скорость для броска.
func update(hand: String, hand_xf: Transform3D, dt: float) -> void:
	if not held.has(hand) or dt <= 0.0:
		return
	var rec: Dictionary = held[hand]
	if not _alive(rec):
		if not falsify_keep_dead:
			forget(hand)
		return
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
	if not _alive(rec):
		if not falsify_keep_dead:
			forget(hand)
		return Vector3.ZERO
	var node: Node3D = rec["node"]
	var sum := Vector3.ZERO
	for v in rec["recent"]:
		sum += v
	var throw_v: Vector3 = (sum / maxf(1.0, float((rec["recent"] as Array).size()))).limit_length(MAX_THROW)
	if node is RigidBody3D:
		var rb: RigidBody3D = node
		rb.freeze = false
		rb.linear_velocity = throw_v
	_restore_layer(rec)
	held.erase(hand)
	return throw_v


## Жив ли ещё предмет в руке. Узел могут освободить и помимо отпускания — выгрузили часть уровня,
## перестроили сцену. Прежде `update` и `release` трогали его без спроса, падали на
## «Trying to assign invalid previously freed instance» и **оставляли запись в `held`**: рука была
## занята мёртвым предметом до конца сессии и больше ничего не брала и не призывала.
##
## Выход — всегда через `forget`, а не через `held.erase`: у возврата слоя столкновений одна дорога,
## и вторая здесь развела бы её надвое.
static func _alive(rec: Dictionary) -> bool:
	var node: Variant = rec.get("node", null)
	return node != null and is_instance_valid(node)


## Вернуть предмету участие в столкновениях. Отдельно, потому что зовётся и из release, и из
## страховки: снятое состояние обязано возвращаться само, а не по событию (ловушка 46).
static func _restore_layer(rec: Dictionary) -> void:
	# Сначала жив ли, потом тип: освобождённый узел в типизированную переменную не положить вовсе.
	var node: Variant = rec.get("node", null)
	var layer := int(rec.get("layer", 0))
	if layer != 0 and node != null and is_instance_valid(node) and node is CollisionObject3D:
		(node as CollisionObject3D).collision_layer = layer


## Страховка: предмет, выпавший из руки не через release (узел освободили, уровень выгрузили),
## не должен остаться бесплотным.
func forget(hand: String) -> void:
	if not held.has(hand):
		return
	_restore_layer(held[hand])
	held.erase(hand)
