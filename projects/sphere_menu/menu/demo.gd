extends RefCounted

## Живая демонстрация настройки (Ф2, шаг 1в; решение владельца 2026-09-15).
##
## Отзыв сессии 1: «инерция захвата — не понял, что делает», «липкость непонятна»,
## «доводку нужно несколько раз пробовать». Шар сам показывает эффект одним циклом
## с текущим значением; ползунок меняет значение на ходу, «Демо» — ещё цикл.
##
## Чистая логика по времени: update(dt) говорит меню, что сделать в этом кадре, —
## повернуть стиком (в экранных осях), бросить шар, показать кольцо удержания,
## дёрнуть «руку». Настройки применяет само меню, как в работе: демонстрация
## показывает настоящее поведение, а не его имитацию.

## Какие настройки показываются. Остальные видны сразу при изменении.
const IDS := ["detent", "stick_speed", "grab_friction", "hysteresis", "hold_ms", "hand_smoothing"]

## Доводка: сдвиг от центра, доля углового радиуса ячейки (внутри своей ячейки).
const DETENT_SHIFT := 0.6
## Инерция: скорость броска, рад/с.
const FLING := 3.0
## Липкость: качание у границы, доля углового радиуса ячейки, и частота, Гц.
const WOBBLE := 0.2
const WOBBLE_HZ := 2.0
## Сглаживание: рывок «руки», рад.
const JERK := 0.35

var id := ""
var t := 0.0
var duration := 0.0
var cell_angle := 0.1
var stick_speed := 2.5
var hold_s := 0.5
var _flung := false
var _moved := Vector2.ZERO


static func supports(setting: String) -> bool:
	return setting in IDS


func running() -> bool:
	return id != "" and t < duration


func start(p_id: String, p_cell_angle: float, p_stick_speed: float, p_hold_ms: float) -> bool:
	if not supports(p_id):
		id = ""
		return false
	id = p_id
	t = 0.0
	cell_angle = p_cell_angle
	stick_speed = p_stick_speed
	hold_s = p_hold_ms / 1000.0
	_flung = false
	_moved = Vector2.ZERO
	match id:
		"detent": duration = 2.3
		"stick_speed": duration = 2.0
		"grab_friction": duration = 3.0
		"hysteresis": duration = 2.4
		"hold_ms": duration = hold_s + 0.6
		"hand_smoothing": duration = 1.6
	return true


func stop() -> void:
	id = ""


## Кадр. Ключи результата (все необязательные):
##   stick    — Vector2 направления и angle — угол за кадр: повернуть как стиком;
##   no_detent — true: доводка молчит (липкость показывается без неё);
##   fling    — true: бросить шар вокруг вертикали зрителя со скоростью FLING;
##   progress — 0…1 кольцо удержания на активной;
##   hand     — Quaternion: добавка к ориентации руки (рывок), вокруг вертикали.
func update(dt: float) -> Dictionary:
	if not running():
		return {}
	t += dt
	var out := {}
	match id:
		"detent":
			# 0–0.3 с — увести на долю ячейки; дальше доводка текущей силы
			out = _move_to(Vector2(DETENT_SHIFT * cell_angle * clampf(t / 0.3, 0.0, 1.0), 0.0))
		"stick_speed":
			# вправо и обратно, вниз и обратно, по 0.5 с. Не квадрат: повороты на сфере
			# не коммутируют, квадрат со стороной 1 рад не замыкается (проверка
			# «демонстрации» — 0.89 рад мимо начала). Цель — функция времени, а не
			# «скорость × кадр по фазам»: иначе у фазы бывает лишний кадр (остаток 0.022 рад).
			var tt := clampf(t, 0.0, 2.0)
			var x := minf(tt, 0.5) - clampf(tt - 0.5, 0.0, 0.5)
			var y := clampf(tt - 1.0, 0.0, 0.5) - clampf(tt - 1.5, 0.0, 0.5)
			out = _move_to(Vector2(x, y) * stick_speed)
		"grab_friction":
			if not _flung:
				_flung = true
				out["fling"] = true
		"hysteresis":
			# 0.4 с к границе, 1.6 с качание у границы, 0.4 с обратно
			var target := 0.0
			if t < 0.4:
				target = cell_angle * t / 0.4
			elif t < 2.0:
				target = cell_angle + WOBBLE * cell_angle * sin(TAU * WOBBLE_HZ * (t - 0.4))
			else:
				target = cell_angle * clampf((2.4 - t) / 0.4, 0.0, 1.0)
			out = _move_to(Vector2(target, 0.0))
			out["no_detent"] = true
		"hold_ms":
			out["progress"] = clampf(t / hold_s, 0.0, 1.0) if t < hold_s + 0.3 else 0.0
		"hand_smoothing":
			# рывок на JERK за один кадр, 0.7 с держится, рывок обратно
			out["hand"] = Quaternion(Vector3.UP, JERK) if t >= 0.1 and t < 0.8 else Quaternion.IDENTITY
	return out


## Повернуть так, чтобы суммарный сдвиг (рад по осям стика) стал target.
func _move_to(target: Vector2) -> Dictionary:
	var d := target - _moved
	_moved = target
	if d.length() < 1e-7:
		return {}
	return {"stick": d.normalized(), "angle": d.length()}
