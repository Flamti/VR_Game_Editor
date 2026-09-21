extends RefCounted

## Повороты (ADR-0013): щелчком (умолчание, советует Meta) и плавный.
##
## Щелчок: угол кратен настройке, между щелчками пауза, и стик должен вернуться в середину —
## иначе удержание стика крутило бы без остановки. Плавный: угол в секунду.

## Пауза между щелчками, с. Не измерение — столько длится сам поворот у Meta в примерах.
const SNAP_COOLDOWN_S := 0.25
## Порог стика: меньше — ничего.
const DEADZONE := 0.6

## Фальсификатор «turnhold»: удержание стика щёлкает каждый кадр.
var falsify_repeat := false

var _armed := true
var _cooldown := 0.0


## Щелчок. x — отклонение стика, angle_deg — угол настройки. Возвращает угол поворота (со знаком),
## 0 — поворота нет.
func snap(x: float, angle_deg: float, dt: float) -> float:
	_cooldown = maxf(0.0, _cooldown - dt)
	if absf(x) < DEADZONE:
		_armed = true
		return 0.0
	if (not _armed and not falsify_repeat) or _cooldown > 0.0:
		return 0.0
	_armed = false
	_cooldown = SNAP_COOLDOWN_S
	return angle_deg * signf(x)


## Плавный поворот: угол за кадр.
static func smooth(x: float, speed_deg_s: float, dt: float) -> float:
	if absf(x) < DEADZONE * 0.5:
		return 0.0
	return speed_deg_s * dt * signf(x)
