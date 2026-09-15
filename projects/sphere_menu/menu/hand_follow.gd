extends RefCounted

## Ориентация шара от руки (Ф2, шаг 1в; отзыв владельца 2026-09-15).
##
## Режимы — параметр hand_rotation:
##   ball  — как шар: поворот кисти вращает шар целиком;
##   stand — как глобус на подставке: берётся только курс — куда по горизонту
##           указывает контроллер (−Z); собственные наклон и крен кисти курс не
##           меняют. Отвергнуто: закрутка вокруг вертикали (swing-twist) — у
##           наклона с креном она ненулевая (0.077 рад на 0.5 и 0.3 рад, проверка
##           «вращение рукой»), и шар поворачивался бы от наклона руки. Когда
##           контроллер смотрит почти вертикально, курс вырожден: его изменение
##           гасится, пока горизонтальная доля направления меньше STAND_HOLD;
##   face  — лицом к шлему: рука задаёт только положение, шар повёрнут к голове,
##           активная ячейка не меняется, крутят стиком и захватом.
##
## Сглаживание — фильтр one-euro (Casiez, Roussel, Vogel, CHI 2012,
## gery.casiez.net/1euro): частота среза растёт со скоростью, поэтому медленное
## движение гасит дрожь, а быстрое идёт без запаздывания. Применён к кватерниону
## через slerp с долей alpha. Отвергнуто: постоянная экспонента — либо дрожь на
## медленном, либо «резина» на быстром; владелец жаловался на резкость, а не на
## задержку, но задержка фокуса на повороте кисти — тот же сбой фокуса.
##
## Числа фильтра — варианты для выбора человеком (параметр «Сглаживание руки»),
## не измерения.

const MODES := ["ball", "stand", "face"]
## Частота среза на покое при сглаживании 0 и 1, Гц; между ними — геометрически
## (линейно середина шкалы давала 15 Гц — почти без сглаживания). Ровно 0 — фильтра нет.
const CUTOFF_AT_ZERO := 30.0
const CUTOFF_AT_ONE := 0.6
## Прирост частоты среза на рад/с скорости руки (beta one-euro).
const BETA := 0.6
## Частота среза для оценки скорости, Гц (d_cutoff one-euro).
const D_CUTOFF := 1.0
## Кисть «вращается», пока сглаженная угловая скорость выше порога, рад/с: доводка
## в это время молчит, иначе тянет активную к центру навстречу руке («резкость»).
const ROTATING := 0.6
## Горизонтальная доля направления контроллера, ниже которой курс держится, и выше
## которой следует полностью (между — плавно).
const STAND_HOLD := Vector2(0.2, 0.5)

var mode := "ball"
## Добавка к руке для демонстрации сглаживания (рывок), в мировых осях.
var demo_offset := Quaternion.IDENTITY
## 0…1: 0 — без сглаживания, 1 — самое сильное.
var smoothing := 0.5

var _q := Quaternion.IDENTITY
var _raw_prev := Quaternion.IDENTITY
var _speed := 0.0
var _started := false
var _yaw := 0.0
var _yaw_started := false


func reset() -> void:
	_started = false
	_yaw_started = false
	_speed = 0.0


func angular_speed() -> float:
	return _speed


func rotating() -> bool:
	return _speed > ROTATING


## hand — ориентация руки в мире; ball_pos, head_pos — положения в мире.
## Возвращает ориентацию шара в мире.
func update(hand: Quaternion, ball_pos: Vector3, head_pos: Vector3, dt: float) -> Quaternion:
	var raw := target(demo_offset * hand, ball_pos, head_pos)
	if not _started or dt <= 0.0:
		_q = raw
		_raw_prev = raw
		_started = true
		_speed = 0.0
		return _q
	var inst := _raw_prev.angle_to(raw) / dt
	_raw_prev = raw
	_speed = lerpf(_speed, inst, _alpha(D_CUTOFF, dt))
	if smoothing <= 0.0:
		_q = raw
		return _q
	var cutoff := CUTOFF_AT_ZERO * pow(CUTOFF_AT_ONE / CUTOFF_AT_ZERO, clampf(smoothing, 0.0, 1.0)) + BETA * _speed
	var a := _alpha(cutoff, dt)
	# кратчайший путь: q и −q — один поворот
	var to := raw if _q.dot(raw) >= 0.0 else -raw
	_q = _q.slerp(to, a).normalized()
	return _q


## Ориентация без сглаживания.
func target(hand: Quaternion, ball_pos: Vector3, head_pos: Vector3) -> Quaternion:
	match mode:
		"stand":
			return Quaternion(Vector3.UP, _heading(hand))
		"face":
			var to_head := head_pos - ball_pos
			if to_head.length_squared() < 1e-8:
				return _q
			to_head = to_head.normalized()
			# голова строго над шаром: мировой верх вырожден, держим прежний верх шара
			var up := Vector3.UP if absf(to_head.y) < 0.98 else _q * Vector3.UP
			# +Z шара — на голову, как «перёд» поверхностей по умолчанию
			return Basis.looking_at(-to_head, up).get_rotation_quaternion()
	return hand


## Курс контроллера вокруг мировой вертикали, рад; 0 — указывает на −Z мира.
func _heading(hand: Quaternion) -> float:
	var f := hand * Vector3.FORWARD
	var h := Vector2(f.x, f.z)
	var yaw := atan2(-h.x, -h.y)
	var share := smoothstep(STAND_HOLD.x, STAND_HOLD.y, h.length())
	if not _yaw_started:
		_yaw = yaw if share > 0.0 else 0.0
		_yaw_started = true
	else:
		_yaw += wrapf(yaw - _yaw, -PI, PI) * share
	return _yaw


static func _alpha(cutoff: float, dt: float) -> float:
	var tau := 1.0 / (TAU * cutoff)
	return 1.0 / (1.0 + tau / dt)
