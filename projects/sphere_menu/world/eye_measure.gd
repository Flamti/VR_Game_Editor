extends RefCounted

## Замер высоты глаз (этап Ф3): среднее за окно, а не мгновенный отсчёт.
##
## Сессия 13: два замера подряд дали 1.26 и 1.59 м — мгновенное значение ловит наклон головы.
## Здесь копится окно и берётся СРЕДИННОЕ значение (медиана): один взгляд под ноги не сдвинет её,
## в отличие от среднего арифметического.
##
## Чистая математика: проверяется настольно, без шлема.

## Сколько копить, с. Не измерение — столько человек спокойно стоит по просьбе «встаньте прямо».
const WINDOW_S := 2.0
## Размах окна больше этого — человек двигался, замер не годится, м.
const SPREAD_MAX_M := 0.25
## Размах считается по децилям, а не по крайним значениям: один кадр со взглядом под ноги (сессия 13)
## не должен перечёркивать ровную позу, а вот непрерывное движение сдвигает и децили.
const SPREAD_LOW := 0.1
const SPREAD_HIGH := 0.9

var active := false
var samples: PackedFloat32Array = PackedFloat32Array()
var elapsed := 0.0
## Фальсификатор «eyeinstant»: берётся последний отсчёт, как до этапа Ф3.
var falsify_instant := false


func start() -> void:
	active = true
	samples = PackedFloat32Array()
	elapsed = 0.0


## Отсчёт высоты головы над полом. Возвращает результат {"ok", "eye_m", "spread_m"} в кадре, когда
## окно набрано; иначе пустой словарь.
func add(y: float, dt: float) -> Dictionary:
	if not active:
		return {}
	samples.append(y)
	elapsed += dt
	if falsify_instant:
		active = false
		return {"ok": true, "eye_m": y, "spread_m": 0.0}
	if elapsed < WINDOW_S:
		return {}
	active = false
	var sorted := samples.duplicate()
	sorted.sort()
	var last := sorted.size() - 1
	var median: float = sorted[sorted.size() / 2]
	var spread: float = sorted[int(round(SPREAD_HIGH * last))] - sorted[int(round(SPREAD_LOW * last))]
	return {"ok": spread <= SPREAD_MAX_M, "eye_m": snappedf(median, 0.01), "spread_m": snappedf(spread, 0.01)}
