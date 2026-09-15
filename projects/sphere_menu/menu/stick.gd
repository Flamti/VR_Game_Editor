extends RefCounted

## Вращение шара стиком в экранных осях зрителя (Ф2, шаг 1в).
##
## Сессия 2026-09-15, владелец: «вверх-вниз быстрее, чем вправо-влево». Причина —
## горизонталь крутила вокруг «верха» шара, а перёд (направление на голову) к нему
## наклонён: точка напротив лица едет со скоростью speed·sin(угла между ними).
## Вертикаль шла вокруг оси ⟂ переду — в полную силу. Здесь обе оси
## перпендикулярны переду, и видимая скорость точки напротив лица одна.

## front — направление на голову, view_up — «верх» зрителя (всё в системе шара).
## stick.x > 0 — содержимое едет влево (как рукой по глобусу), stick.y > 0 — вниз.
static func rotation(front: Vector3, view_up: Vector3, stick: Vector2, angle: float) -> Quaternion:
	var f := front.normalized()
	var up := view_up - f * view_up.dot(f)
	if up.length_squared() < 1e-8:
		# смотрят строго сверху или снизу: верх зрителя вырожден, берём любую ⟂ ось
		up = Vector3.RIGHT if absf(f.x) < 0.9 else Vector3.FORWARD
		up = up - f * up.dot(f)
	up = up.normalized()
	var right := up.cross(f).normalized()
	return Quaternion(up, -stick.x * angle) * Quaternion(right, stick.y * angle)


## Прежняя формула — только для фальсификатора настольных проверок.
static func rotation_old(front: Vector3, ball_up: Vector3, stick: Vector2, angle: float) -> Quaternion:
	var right := ball_up.cross(front).normalized()
	return Quaternion(ball_up, -stick.x * angle) * Quaternion(right, stick.y * angle)
