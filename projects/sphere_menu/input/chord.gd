extends RefCounted

## Аккорд двух кнопок (просьба владельца 2026-09-17: скриншот — оба стика сразу, не пункт шара).
##
## Срабатывает один раз, когда нажаты обе, и вторая нажата не позже WINDOW_MS после первой:
## иначе нажатие стика ради другого (и затем второго) давало бы снимок, которого не просили.
## Следующее срабатывание — только после отпускания обеих.

const WINDOW_MS := 250

## Фальсификатор «chordone»: хватает одной кнопки.
var falsify_one := false
var _down_ms := [-1, -1]
var _armed := true


## a, b — нажаты ли кнопки в этом кадре. true — аккорд сработал в этом кадре.
func update(a: bool, b: bool, now_ms: int) -> bool:
	var pressed := [a, b]
	for i in 2:
		if pressed[i] and _down_ms[i] < 0:
			_down_ms[i] = now_ms
		elif not pressed[i]:
			_down_ms[i] = -1
	if not a and not b:
		_armed = true
		return false
	if falsify_one and _armed:
		_armed = false
		return true
	if a and b and _armed and absi(_down_ms[0] - _down_ms[1]) <= WINDOW_MS:
		_armed = false
		return true
	return false
