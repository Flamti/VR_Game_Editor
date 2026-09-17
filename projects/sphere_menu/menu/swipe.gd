extends RefCounted

## Резкий взмах рукой влево — возврат на верхний уровень (решение владельца 2026-09-16,
## отзыв сессии 5: встряхивание слишком долгое, нужен жест в одно движение).
##
## Сигнал тот же, что у встряхивания (menu/shake.gd): вектор «от головы к руке» в
## МИРОВЫХ осях — ходьба двигает голову и руку вместе и в разности гасится.
##
## «Влево» задаёт курс головы, но **замороженный в момент начала взмаха**: если брать
## его каждый кадр, поворот головы посреди движения переопределяет направление, и
## поворот корпуса читается как взмах.
##
## Жест: смещение вдоль «влево» не меньше порога за время не больше окна, пиковая
## скорость выше порога и доля движения по этой оси не ниже LATERAL_SHARE — иначе это
## перенос руки, а не взмах. Числа — выбор для человека (настройка «Размах жеста»),
## не измерения.

## Окно взмаха, с: дольше — это уже перенос руки.
const WINDOW := 0.35
## Пиковая скорость, м/с.
const SPEED := 0.8
## Доля пути по оси «влево» от всего пройденного за окно.
const LATERAL_SHARE := 0.7
## Пауза после срабатывания, с.
const COOLDOWN := 0.7
## Скорость, ниже которой взмах считается не начавшимся, м/с.
const START_SPEED := 0.25

## Порог смещения вдоль «влево», м.
var distance := 0.18
var enabled := true
## Фальсификатор «swipe»: направление не проверяется — годится любая сторона.
var falsify_any_direction := false

var _t := 0.0
var _fire_t := -100.0
var _prev := Vector3.ZERO
var _started := false
## Ось «влево» в мире, замороженная на время взмаха.
var _axis := Vector3.ZERO
var _from := Vector3.ZERO
var _from_t := 0.0
var _peak := 0.0
var _path := 0.0


func reset() -> void:
	_started = false
	_axis = Vector3.ZERO
	_peak = 0.0
	_path = 0.0


## Кадр. hand и head — в мире, head_basis — поза шлема (из неё берётся «влево»).
## true — жест распознан.
func feed(hand: Vector3, head: Vector3, head_basis: Basis, dt: float) -> bool:
	if not enabled or dt <= 0.0:
		return false
	_t += dt
	var pos := hand - head
	if not _started:
		_prev = pos
		_from = pos
		_from_t = _t
		_started = true
		return false
	var step := pos - _prev
	var speed := step.length() / dt
	_prev = pos
	if _t - _fire_t < COOLDOWN:
		_restart(pos)
		return false
	# Взмах начинается там, где рука пошла быстро: до этого копить нечего.
	if _axis == Vector3.ZERO:
		if speed < START_SPEED:
			_from = pos
			_from_t = _t
			return false
		_axis = left_of(head_basis)
		_from = pos
		_from_t = _t
		_peak = 0.0
		_path = 0.0
	_peak = maxf(_peak, speed)
	_path += step.length()
	if _t - _from_t > WINDOW:
		_restart(pos)
		return false
	var moved := pos - _from
	var along := moved.dot(_axis)
	if falsify_any_direction:
		along = absf(along)
	if along < distance or _peak < SPEED:
		return false
	if _path > 1e-6 and along / _path < LATERAL_SHARE:
		return false
	_fire_t = _t
	_restart(pos)
	return true


func _restart(pos: Vector3) -> void:
	_axis = Vector3.ZERO
	_from = pos
	_from_t = _t
	_peak = 0.0
	_path = 0.0


## Единичное «влево» зрителя в мире по горизонту: −X позы шлема, спроецированный на
## плоскость земли. Смотреть строго вниз для взмаха не надо, но проекция обязана
## остаться определённой.
static func left_of(head_basis: Basis) -> Vector3:
	var left := -head_basis.x
	left.y = 0.0
	if left.length_squared() < 1e-6:
		left = -head_basis.z    # шлем смотрит вертикально: «влево» берём от взгляда
		left.y = 0.0
	return left.normalized() if left.length_squared() > 1e-6 else Vector3.LEFT
