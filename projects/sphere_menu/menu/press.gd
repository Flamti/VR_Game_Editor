extends RefCounted

## Нажатие курка: короткое, удержание, подтверждение удержанием (решение владельца
## 2026-09-15: короткое — действие по умолчанию, удержание — шар действий).
##
## Чистая логика по времени: время передаётся снаружи, поэтому проверяется на
## десктопе без контроллера. Одно нажатие даёт ровно одно событие:
##   "short" — отпущено раньше порога;
##   "hold"  — порог достигнут, пока курок держат (срабатывает сразу, не на отпускании:
##             шар действий должен появиться под пальцем, а не после);
##   ""      — ничего.
## Подтверждение опасного действия — то же удержание, но с другим порогом и без
## короткого: отпущено раньше — отмена, а не действие.

## Порог удержания, мс. Параметр мастера настройки.
var hold_ms := 500
## Порог подтверждения опасного действия, мс.
var confirm_ms := 600

var _down_ms := -1
var _fired := false
var _confirming := false


func is_down() -> bool:
	return _down_ms >= 0


## Доля пройденного порога 0…1 — для кольца прогресса на ячейке.
func progress(now_ms: int) -> float:
	if _down_ms < 0 or _fired:
		return 0.0
	var limit := confirm_ms if _confirming else hold_ms
	return clampf(float(now_ms - _down_ms) / float(limit), 0.0, 1.0)


## Кадр: pressed — состояние кнопки сейчас. Возвращает событие.
func update(pressed: bool, now_ms: int) -> String:
	if pressed:
		if _down_ms < 0:
			_down_ms = now_ms
			_fired = false
		var limit := confirm_ms if _confirming else hold_ms
		if not _fired and now_ms - _down_ms >= limit:
			_fired = true
			return "confirm" if _confirming else "hold"
		return ""
	if _down_ms < 0:
		return ""
	var was_fired := _fired
	_down_ms = -1
	_fired = false
	if was_fired:
		return ""
	return "cancel" if _confirming else "short"


## Бросить начатое нажатие БЕЗ события: касание пальцем перешло в протяжку по шару, и на
## отпускании не должно получиться короткого выбора. Отпускание само по себе всегда даёт "short"
## (см. update), отменить его иначе нечем.
func abort() -> void:
	_down_ms = -1
	_fired = false


## Следующее удержание — подтверждение опасного действия.
func arm_confirm() -> void:
	_confirming = true


func disarm_confirm() -> void:
	_confirming = false


func confirming() -> bool:
	return _confirming
