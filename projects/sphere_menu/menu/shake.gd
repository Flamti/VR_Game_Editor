extends RefCounted

## Встряхивание шара возвращает меню на верхний уровень (решение владельца 2026-09-16).
## Шар при этом не закрывается: «Назад» ходит по одному уровню, а с глубины в четыре
## папки на корень возвращаться было нечем.
##
## Сигнал — не положение руки в мире, а вектор «от головы к руке» в МИРОВЫХ осях:
##   ходьба и наклоны двигают голову и руку вместе, и в разности гасятся;
##   повороты головы на сигнал не влияют вовсе (в системе головы они, наоборот,
##     раскачивали бы руку — взгляд вправо-влево читался бы как встряхивание).
## Поворот корпуса руку вокруг головы двигает, но в одну сторону: разворотов не даёт.
##
## Жест: скорость по преобладающей оси меняет знак нужное число раз подряд, и у
## каждого отрезка свои пороги пиковой скорости и пройденного пути — медленное
## перекладывание руки и дрожь не считаются. После срабатывания — пауза.
##
## Числа — пороги для выбора человеком (настройка «Размах жеста»), не измерения.

## Сколько разворотов скорости подряд считается встряхиванием. Два — это «туда-обратно
## один раз»: три были слишком долгими (отзыв сессии 5).
const TURNS := 2
## Окно, в котором эти развороты должны уложиться, с.
const WINDOW := 0.6
## Из размаха выводится порог скорости: v = 2π·f·A при f = 1.5 Гц. Одна ручка вместо
## таблицы уровней — иначе размах и скорость разъезжаются, и «слабее» перестаёт
## означать «слабее». Число f — выбор, не измерение.
const MIN_HZ := 1.5
## Пауза после срабатывания, с: одно встряхивание — один возврат.
const COOLDOWN := 0.7
## Постоянная сглаживания скорости, с: трекинг даёт выбросы на один кадр. Имя не TAU:
## так называется глобальная 2π, и локальная константа её затеняла — порог скорости
## выходил в двести раз меньше нужного.
const SMOOTH_TAU := 0.03
## Доля пороговой скорости, ниже которой смена знака не считается разворотом:
## у нуля скорости знак мигает от шума.
const SIGN_GATE := 0.25

## Размах — путь на отрезке между разворотами, м (настройка «Размах жеста»).
var travel := 0.06
var enabled := true
## Фальсификатор «shake»: отрезок засчитывается без порога пути — контроль (спокойный
## перенос руки, поворот корпуса) начинает срабатывать.
var falsify_no_travel := false

var _t := 0.0
var _fire_t := -100.0
var _prev := Vector3.ZERO
var _started := false
var _v := Vector3.ZERO
var _axis := Vector3.ZERO
var _leg_start := Vector3.ZERO
var _leg_peak := 0.0
var _leg_sign := 0
## Времена засчитанных разворотов.
var _turns: Array[float] = []


## Порог пиковой скорости отрезка, м/с — выводится из размаха.
func min_speed() -> float:
	return TAU * MIN_HZ * travel    # TAU здесь — глобальная 2π


func reset() -> void:
	_started = false
	_v = Vector3.ZERO
	_axis = Vector3.ZERO
	_leg_peak = 0.0
	_leg_sign = 0
	_turns.clear()


## Кадр. hand и head — в мире; true — жест распознан.
func feed(hand: Vector3, head: Vector3, dt: float) -> bool:
	if not enabled or dt <= 0.0:
		return false
	_t += dt
	var pos := hand - head
	if not _started:
		_prev = pos
		_leg_start = pos
		_started = true
		return false
	var inst := (pos - _prev) / dt
	_prev = pos
	_v = _v.lerp(inst, clampf(dt / (dt + SMOOTH_TAU), 0.0, 1.0))
	var v_min := min_speed()
	var window := WINDOW
	# Пауза после срабатывания: продолжение того же встряхивания не должно уводить
	# ещё на уровень выше (уходить уже некуда) и мигать сообщением.
	if _t - _fire_t < COOLDOWN:
		_turns.clear()
		_leg_sign = 0
		_leg_start = pos
		_leg_peak = 0.0
		return false
	if _axis == Vector3.ZERO:
		if _v.length() < v_min * SIGN_GATE:
			return false
		_axis = _v.normalized()
		_leg_start = pos
		_leg_sign = 0
	var s := _v.dot(_axis)
	_leg_peak = maxf(_leg_peak, absf(s))
	var sign_now := int(signf(s)) if absf(s) > v_min * SIGN_GATE else 0
	if sign_now == 0 or sign_now == _leg_sign:
		# отрезок затянулся дольше окна — счёт сбрасывается, гнать нечего
		if not _turns.is_empty() and _t - _turns[_turns.size() - 1] > window:
			_turns.clear()
		return false
	var leg_travel := (pos - _leg_start).length()
	var counted := _leg_sign != 0 and _leg_peak >= v_min and (falsify_no_travel or leg_travel >= travel)
	# ось уточняется по пройденному отрезку: тряхнули не строго вдоль первой оценки
	if counted and leg_travel > 1e-4:
		_axis = ((pos - _leg_start).normalized() * float(_leg_sign) + _axis * 2.0).normalized()
	_leg_sign = sign_now
	_leg_start = pos
	_leg_peak = absf(s)
	if not counted:
		_turns.clear()
		return false
	_turns.append(_t)
	while not _turns.is_empty() and _t - _turns[0] > window:
		_turns.remove_at(0)
	if _turns.size() < TURNS or _t - _fire_t < COOLDOWN:
		return false
	_fire_t = _t
	reset()
	_prev = pos
	_leg_start = pos
	_started = true
	return true
