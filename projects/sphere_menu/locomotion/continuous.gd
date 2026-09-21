extends RefCounted

## Непрерывное движение (ADR-0013): по взгляду (направление берётся от головы) и по руке
## (от контроллера). Скорость по умолчанию 1.4 м/с — скорость ходьбы человека из руководства Meta.
##
## Движение только по горизонтали: вверх ведут ступени, пандус и лазанье, а не стик.

const DEADZONE := 0.15

## Фальсификатор «movevertical»: направление берётся как есть, вместе с наклоном головы — стик
## поднимает и опускает человека.
static var falsify_vertical := false


## Скорость по миру. stick — отклонение (x вправо, y вперёд), basis — головы или руки.
static func velocity(stick: Vector2, basis: Basis, speed: float) -> Vector3:
	if stick.length() < DEADZONE:
		return Vector3.ZERO
	var fwd := -basis.z
	var side := basis.x
	if not falsify_vertical:
		fwd.y = 0.0
		side.y = 0.0
		if fwd.length() < 0.01:
			# смотрит строго вверх или вниз: направление берём от «верха» головы
			fwd = basis.y
			fwd.y = 0.0
		fwd = fwd.normalized()
		side = side.normalized()
	var dir := (fwd * stick.y + side * stick.x)
	if dir.length() > 1.0:
		dir = dir.normalized()
	return dir * speed
