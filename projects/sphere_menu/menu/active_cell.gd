extends RefCounted

## Активная ячейка (слой 5, docs/design/sphere-menu.md §5).
##
## Кандидат — ячейка под «передом». Смена только с запасом: кандидат обязан
## быть ближе к переду, чем текущая, на долю углового радиуса ячейки. Иначе
## дрожь трекинга на границе двух ячеек мигала бы активной и щёлкала детентом.
##
## Запас — параметр сессии, а не измеренное число: подбирается на шлеме и
## пишется в журнал вместе с выбором.

## Доля углового радиуса ячейки.
var hysteresis := 0.15
var key: Variant = null
## [мс, ключ] за последние HISTORY_MS — для заморозки выбора (шаг 2, кулак/тычок).
var history: Array = []
const HISTORY_MS := 300


## true — активная сменилась.
func update(surface: RefCounted, now_ms: int) -> bool:
	var cand: Variant = surface.cell_at_direction(surface.front)
	var changed := false
	if key == null:
		key = cand
		changed = true
	elif cand != key:
		var cur: float = surface.direction_of(key).angle_to(surface.front)
		var new: float = surface.direction_of(cand).angle_to(surface.front)
		if cur - new > hysteresis * surface.cell_angle():
			key = cand
			changed = true
	history.append([now_ms, key])
	while not history.is_empty() and now_ms - int(history[0][0]) > HISTORY_MS:
		history.pop_front()
	return changed


## Активная ms_ago миллисекунд назад (из буфера); нет записи — текущая.
func key_at(now_ms: int, ms_ago: int) -> Variant:
	for i in range(history.size() - 1, -1, -1):
		if now_ms - int(history[i][0]) >= ms_ago:
			return history[i][1]
	return key


func reset() -> void:
	key = null
	history.clear()
