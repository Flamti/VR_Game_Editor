extends RefCounted

## Телепорт (ADR-0013): «мигание» — перенос с коротким затемнением, «рывок» — быстрый перелёт.
## Умолчание — мигание: так советует руководство Meta по комфорту.
##
## Дуга — баллистическая: точка бросается из руки со скоростью SPEED и падает с ускорением GRAVITY.
## Сама дуга и проверка площадки — чистая математика; пересечение с миром даёт вызывающий (луч
## физики), поэтому проверяется настольно.

## Скорость броска и тяготение дуги — не измерения, а форма дуги: при 8 м/с и 12 м/с² дуга ложится
## примерно на 5 м вперёд при горизонтальной руке.
const SPEED := 8.0
const GRAVITY := 12.0
## Сегментов дуги ДЛЯ ЛУЧЕЙ: каждый — запрос к физике, и всё это каждый такт прицеливания.
## Двенадцать: прореживание с 24 до 12 измеримого выигрыша не дало (сессия 28, медиана в пределах
## разброса), но и вреда нет, а запросов вдвое меньше.
const STEPS := 12
const STEP_S := 0.12
## Во сколько раз чаще ставятся точки ЛИНИИ. Дуга из 12 отрезков на семи метрах заметно угловата,
## а лишние точки — чистая арифметика без единого запроса к физике: считать их нечем дорого.
const DRAW_SUBDIV := 2
## Как было до сессии 25 — вдвое мельче. Цена этой правки не измерялась, и фальсификатор нужен,
## чтобы прибор назвал её числом, а не чтобы поверить на слово.
const STEPS_FINE := 24
const STEP_S_FINE := 0.06

## Режим сравнения «как было»: дуга из 24 сегментов. Не порча данных, а вторая точка отсчёта —
## самопроверка меряет им цену прореживания, а настольная проверка сверяет форму.
static var falsify_fine_arc := false
## Фальсификатор «arccoarse»: линия рисуется теми же редкими точками, что идут на лучи, — дуга
## становится угловатой.
static var falsify_coarse_line := false
## Фальсификатор «arcstep»: точка снова считается сложением шагов (метод Эйлера). Траектория тогда
## зависит от числа сегментов — сессия 25: прореживание увело середину дуги на полметра.
static var falsify_step_sum := false
## Площадка считается пригодной, если наклон не круче этого, градусы.
const MAX_SLOPE_DEG := 40.0
## Затемнение мигания и длительность рывка, с.
const BLINK_S := 0.12
const SHIFT_S := 0.25

## Фальсификатор «teleportslope»: наклон площадки не проверяется — переносит на стену и потолок.
static var falsify_any_slope := false

## Курс при прицеливании: мёртвая зона стика и наибольший доворот, градусы. 150° позволяют и
## развернуться почти назад, и довернуть на десяток градусов.
const AIM_DEADZONE := 0.25
const MAX_AIM_TURN := 150.0

## Фаза: "" | "fade_out" | "move" | "fade_in".
var phase := ""
## Куда человек будет смотреть после переноса, градусы вокруг вертикали; NAN — курс не менять.
var yaw_deg := NAN
var elapsed := 0.0
var target := Vector3.ZERO
var from := Vector3.ZERO
var mode := "blink"


## Точки дуги от origin в направлении dir. Последняя точка — конец дальности.
static func arc(origin: Vector3, dir: Vector3, max_range: float) -> PackedVector3Array:
	var pts := PackedVector3Array()
	var v0 := dir.normalized() * SPEED
	var steps := STEPS_FINE if falsify_fine_arc else STEPS
	var step_s := STEP_S_FINE if falsify_fine_arc else STEP_S
	# Точка считается ТОЧНОЙ формулой броска, а не сложением шагов. Пошаговое сложение (метод
	# Эйлера) при вдвое большем шаге даёт другую траекторию: сессия 25 — прореживание дуги с 24
	# сегментов до 12 увело середину на 0.52 м, и «стало дешевле» означало «стало другое».
	# Теперь число сегментов влияет только на гладкость линии.
	var walk := origin
	var walk_v := v0
	for i in steps + 1:
		var t := float(i) * step_s
		var p := origin + v0 * t + Vector3.DOWN * (0.5 * GRAVITY * t * t)
		if falsify_step_sum:
			p = walk
			walk += walk_v * step_s
			walk_v.y -= GRAVITY * step_s
		if p.distance_to(origin) > max_range:
			# Последняя точка — ровно на границе дальности: иначе дуга выходит за настройку, и
			# «дальность телепорта» перестаёт значить сказанное.
			pts.append(origin + (p - origin).normalized() * max_range)
			return pts
		pts.append(p)
	return pts


## Годится ли площадка: нормаль вверх и наклон не круче MAX_SLOPE_DEG.
static func landing_ok(normal: Vector3) -> bool:
	if falsify_any_slope:
		return true
	return normal.length() > 0.5 and rad_to_deg(normal.angle_to(Vector3.UP)) <= MAX_SLOPE_DEG


## Начать перенос. mode — "blink" (затемнение) или "shift" (перелёт).
func start(p_from: Vector3, p_target: Vector3, p_mode: String, p_yaw := NAN) -> void:
	from = p_from
	target = p_target
	mode = p_mode
	yaw_deg = p_yaw
	elapsed = 0.0
	phase = "fade_out" if mode == "blink" else "move"


## Курс из отклонения стика вбок при прицеливании: HL:A и перечень Meta («orientation on teleport»).
## Отклонения нет — курс не меняется, и человек попадает туда, куда смотрел.
##
## Угол ПРОПОРЦИОНАЛЕН отклонению, до MAX_AIM_TURN: первая версия давала ровно ±90° на любое
## касание стика, и довернуть слегка было нечем, а развернуться назад — невозможно.
static func aim_yaw(stick_x: float, head_yaw_deg: float) -> float:
	if absf(stick_x) < AIM_DEADZONE:
		return NAN
	var k := (absf(stick_x) - AIM_DEADZONE) / (1.0 - AIM_DEADZONE)
	return head_yaw_deg + MAX_AIM_TURN * signf(stick_x) * clampf(k, 0.0, 1.0)


## Кадр переноса. Возвращает {"pos": где человек сейчас, "fade": 0..1 затемнение, "done": bool}.
func tick(dt: float) -> Dictionary:
	if phase == "":
		return {"pos": target, "fade": 0.0, "done": true}
	elapsed += dt
	match phase:
		"fade_out":
			var k := clampf(elapsed / BLINK_S, 0.0, 1.0)
			if k >= 1.0:
				phase = "fade_in"
				elapsed = 0.0
				return {"pos": target, "fade": 1.0, "done": false}
			return {"pos": from, "fade": k, "done": false}
		"fade_in":
			var k2 := clampf(elapsed / BLINK_S, 0.0, 1.0)
			if k2 >= 1.0:
				phase = ""
				return {"pos": target, "fade": 0.0, "done": true}
			return {"pos": target, "fade": 1.0 - k2, "done": false}
		"move":
			var k3 := clampf(elapsed / SHIFT_S, 0.0, 1.0)
			if k3 >= 1.0:
				phase = ""
				return {"pos": target, "fade": 0.0, "done": true}
			# сглаженный разгон и торможение: рывок не должен дёргать в начале и конце
			return {"pos": from.lerp(target, smoothstep(0.0, 1.0, k3)), "fade": 0.0, "done": false}
	return {"pos": target, "fade": 0.0, "done": true}


## Точки для ЛИНИИ: та же дуга, но гуще. Лучи физики по ним не пускаются, поэтому гладкость
## достаётся даром — форма считается точной формулой и от числа точек не зависит.
static func arc_line(origin: Vector3, dir: Vector3, max_range: float) -> PackedVector3Array:
	var sub := 1 if falsify_coarse_line else DRAW_SUBDIV
	var pts := PackedVector3Array()
	var v0 := dir.normalized() * SPEED
	var steps := (STEPS_FINE if falsify_fine_arc else STEPS) * sub
	var step_s := (STEP_S_FINE if falsify_fine_arc else STEP_S) / float(sub)
	for i in steps + 1:
		var t := float(i) * step_s
		var p := origin + v0 * t + Vector3.DOWN * (0.5 * GRAVITY * t * t)
		if p.distance_to(origin) > max_range:
			pts.append(origin + (p - origin).normalized() * max_range)
			return pts
		pts.append(p)
	return pts
