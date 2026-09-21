extends RefCounted

## Разворот табличек лицом к человеку (сессия 18).
##
## Билборд Godot (`BILLBOARD_FIXED_Y`) держит надпись параллельно **плоскости экрана**, то есть
## поворачивает её вместе с поворотом шлема: табличка сбоку от взгляда оказывается повёрнутой не к
## человеку, а «как экран». Владелец после сессии 18: «вращаются в соответствии с вращением шлема,
## а должны всегда смотреть лицевой стороной к шлему».
##
## Отсюда — свой разворот: каждая табличка смотрит на ТОЧКУ, где сейчас голова, а не на плоскость
## взгляда. Вертикаль при этом не заваливается: наклон головы на надпись не переносится.
##
## Место таблички остаётся фиксированным — поворачивается только лицевая сторона.

## Фальсификатор «signbillboard»: возвращается билборд Godot — таблички снова следуют за поворотом
## шлема, а не смотрят на него.
static var falsify_billboard := false


## Поворот таблички, стоящей в `at`, лицом к голове в `head`. Вертикаль мира сохраняется.
## Лицевая сторона Label3D — это +Z узла, поэтому смотрим «затылком» по направлению от головы.
static func basis_towards(at: Vector3, head: Vector3) -> Basis:
	var to_head := head - at
	to_head.y = 0.0
	if to_head.length() < 0.001:
		# Голова ровно над табличкой: поворачивать не к чему, оставляем как есть.
		return Basis()
	var z := to_head.normalized()
	var x := Vector3.UP.cross(z).normalized()
	return Basis(x, Vector3.UP, z)


## Развернуть все таблички. Узлы — из группы «sign»; те, что уже не в дереве, пропускаются.
static func face_all(signs: Array, head: Vector3) -> int:
	if falsify_billboard:
		return 0
	var n := 0
	for s in signs:
		var node := s as Node3D
		if node == null or not is_instance_valid(node):
			continue
		node.global_basis = basis_towards(node.global_position, head)
		n += 1
	return n
