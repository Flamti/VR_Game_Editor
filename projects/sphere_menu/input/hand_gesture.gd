extends RefCounted

## Класс жеста ОДНОЙ руки с задержкой отпускания.
##
## Перенос механики прибора (`projects/probe/probe_hands.gd:347` `_debounced`). Зачем она есть:
## внутри удерживаемого щипка расстояние на ОДИН кадр прыгало 21 → 35 → 9 мм и пересекало порог
## выхода — прогон 14 дал три двойных срабатывания. Держится последний класс, пока новый не
## продержится `RELEASE_S` (0.035 с, три кадра на 90 Гц).
##
## Вход мгновенный, задержано только отпускание: ответа на жест человек ждёт сразу, а вот
## «жест кончился» стоит перепроверить. Время — в микросекундах и снаружи, как у `press.gd`:
## иначе механику не проверить настольно.
##
## Сам классификатор не дублируется: он в `probe_hand_features.gd`, побайтовой копии прибора.

const Features := preload("res://probe_hand_features.gd")

## Класс прошлого кадра — он же вход гистерезиса классификатора.
var prev := ""
## Фальсификатор «handrelease»: отпускание без задержки, как до прогона 14.
var falsify_no_release := false
## Фальсификатор «handgate»: щипок без гейта контекста — свободная рука жмёт на панели.
var falsify_no_gate := false
var _since_us := -1
var _entered := false


## Скормить признаки кадра (`ProbeHandFeatures.sample`). Возвращает класс: "fist" | "pinch" | "".
## gated=false — классификатор без гейта контекста щипка, для сравнения (как v3 в приборе).
func update(d: Dictionary, now_us: int, gated: bool = true) -> String:
	var raw: String = Features.classify(d, prev, gated and not falsify_no_gate)
	var cls := _debounce(raw, now_us)
	_entered = cls != "" and cls != prev
	prev = cls
	return cls


## Жест начался именно в этом кадре — фронт для «открыть шар кулаком».
func entered(cls: String) -> bool:
	return _entered and prev == cls


func held(cls: String) -> bool:
	return prev == cls


func reset() -> void:
	prev = ""
	_since_us = -1
	_entered = false


func _debounce(raw: String, now_us: int) -> String:
	if prev == "" or raw == prev:
		_since_us = -1
		return raw
	if falsify_no_release:
		return raw
	if _since_us < 0:
		_since_us = now_us
	if float(now_us - _since_us) / 1000000.0 < Features.RELEASE_S:
		return prev
	_since_us = -1
	return raw
