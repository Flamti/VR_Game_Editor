extends RefCounted

## Захват шара правым контроллером: трекбол и инерция (решение владельца 2026-09-15:
## касание + грип).
##
## По образцу Meta ISDK One Grab Rotate: поворот — разница направления точки
## захвата от момента захвата до текущего. Здесь без ограничения оси: шар
## вращается как настоящий, точка касания следует за контроллером.
##
## Всё в локальных координатах шара, единичные направления из центра. Чистая
## математика — проверяется на десктопе.

## Затухание инерции, 1/с: скорость падает как exp(−friction·t). Параметр мастера.
var friction := 4.0
## Ниже этой угловой скорости инерция гаснет и включается детент, рад/с.
const STOP_SPEED := 0.05

var active := false
var _last_dir := Vector3.ZERO
## Угловая скорость: ось · рад/с (локально).
var angular_velocity := Vector3.ZERO


## Начало захвата: dir — направление из центра шара на кончик контроллера.
func begin(dir: Vector3) -> void:
	active = true
	_last_dir = dir.normalized()
	angular_velocity = Vector3.ZERO


## Кадр захвата. Возвращает поворот, который надо применить к шару, чтобы точка,
## бывшая под кончиком, оказалась под ним снова.
func update(dir: Vector3, dt: float) -> Quaternion:
	if not active:
		return Quaternion.IDENTITY
	var d := dir.normalized()
	if d.angle_to(_last_dir) < 1e-6:
		angular_velocity = angular_velocity.lerp(Vector3.ZERO, clampf(dt * 10.0, 0.0, 1.0))
		return Quaternion.IDENTITY
	var q := Quaternion(_last_dir, d)
	if dt > 0.0:
		var v := q.get_axis() * (q.get_angle() / dt)
		# сглаживание скорости по кадрам: отпускание на дрожащем кадре не должно
		# давать рывок инерции
		angular_velocity = angular_velocity.lerp(v, 0.5)
	_last_dir = d
	return q


func end() -> void:
	active = false


## Кадр инерции после отпускания. Возвращает поворот; IDENTITY — инерция погасла.
func coast(dt: float) -> Quaternion:
	if active:
		return Quaternion.IDENTITY
	var speed := angular_velocity.length()
	if speed < STOP_SPEED:
		angular_velocity = Vector3.ZERO
		return Quaternion.IDENTITY
	var q := Quaternion(angular_velocity / speed, speed * dt)
	angular_velocity *= exp(-friction * dt)
	return q


func coasting() -> bool:
	return not active and angular_velocity.length() >= STOP_SPEED
