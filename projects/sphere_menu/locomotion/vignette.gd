extends RefCounted

## Виньетка комфорта (ADR-0013): при непрерывном движении и плавном повороте края поля зрения
## затемняются — руководство Meta называет это первым средством от укачивания.
##
## Сила — от скорости и от угловой скорости поворота; в покое ноль, иначе виньетка мешала бы
## работать. Настройка «Виньетка»: выкл / лёгкая / сильная.

const LEVELS := {"off": 0.0, "light": 0.6, "strong": 1.0, "accel": 1.0}
## Ускорение, при котором виньетка «по ускорению» выходит на полную, м/с². Разгон до скорости ходьбы
## за четверть секунды — это 5.6 м/с²; берём близкое.
const FULL_ACCEL := 5.0
## Скорость, при которой виньетка выходит на полную, м/с (скорость ходьбы из руководства Meta).
const FULL_SPEED := 1.4
## То же для поворота, градусов в секунду.
const FULL_TURN := 90.0
## Насколько плавно виньетка приходит и уходит, с.
const EASE_S := 0.15

## Фальсификатор «vignettealways»: виньетка висит и в покое.
static var falsify_always := false
## Фальсификатор «vigspeed»: «по ускорению» считается по скорости — на ровном ходу край темнеет.
static var falsify_speed_not_accel := false

var value := 0.0
var _last_speed := 0.0


## Кадр. speed — м/с, turn_deg_s — градусов в секунду, level — настройка.
func update(speed: float, turn_deg_s: float, level: String, dt: float) -> float:
	# «По ускорению» (рекомендация Meta по комфорту): темнеет только на разгоне и торможении, на
	# ровном ходу край чист — в редакторе важно видеть сцену.
	var accel := absf(speed - _last_speed) / maxf(dt, 0.001)
	_last_speed = speed
	var from_move := speed / FULL_SPEED
	if level == "accel" and not falsify_speed_not_accel:
		from_move = accel / FULL_ACCEL
	var want: float = maxf(from_move, absf(turn_deg_s) / FULL_TURN)
	want = clampf(want, 0.0, 1.0) * float(LEVELS.get(level, 0.0))
	if falsify_always:
		want = float(LEVELS.get(level, 0.0))
	var k := clampf(dt / EASE_S, 0.0, 1.0)
	value = lerpf(value, want, k)
	return value
