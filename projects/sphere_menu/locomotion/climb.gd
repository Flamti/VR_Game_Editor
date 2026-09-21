extends RefCounted

## Лазанье и тяга мира (ADR-0013, переписано после сессии 17).
##
## **Почему переписано.** Первая версия двигала мир за *дельтой* руки за кадр и обновляла точку
## захвата каждый кадр, а при двух руках брала среднее. Получалось мягко и вдвое слабее одной руки:
## в сессии 17 человек двенадцать раз брался за зацепы и не поднялся **ни на сантиметр** — во всех
## строках журнала «вверх −0.00».
##
## **Как теперь** (кинематическая модель, она же у Godot XR Tools и в HL:A):
##   - точка захвата `handle` фиксируется в МИРЕ в момент хвата и больше не меняется;
##   - смещение человека за кадр — не дельта руки, а `−(рука − зацеп)` целиком: после такого шага
##     рука снова оказывается на зацепе, потому что тело уносит с собой всю XR-сцену;
##   - ведёт **последняя схватившая** рука; отпустил её — ведение возвращается второй, если та ещё
##     держит. Так лазают по-настоящему, перехватываясь;
##   - рука ушла от зацепа дальше `BREAK_M` — хват срывается сам (реальная рука не резиновая);
##   - при отпускании остаётся инерция (`FLING`) плюс отталкивание по взгляду (`FORWARD_PUSH`),
##     иначе с уступа нельзя оттолкнуться.
##
## **Тяга мира** (`kind = "pull"`, для рук без контроллеров) — по-прежнему среднее по рукам: там
## держатся «за воздух» двумя руками сразу, и ведущая рука смысла не имеет.
##
## Чистая математика: проверяется настольно.

## Скорость при отпускании — среднее за это окно, с (сглаживает дрожь последнего кадра).
const RELEASE_WINDOW_S := 0.1
## Больше этого рука за кадр не сдвигает (защита от скачка трекинга), м.
const MAX_STEP_M := 0.35
## Дальше этого от зацепа хват срывается, м.
const BREAK_M := 0.45
## Во сколько раз скорость руки переходит в полёт при отпускании.
const FLING := 1.0
## Отталкивание по взгляду при отпускании, м/с.
const FORWARD_PUSH := 1.0
## Быстрее этого человек с уступа не улетает, м/с. Та же защита, что у броска предмета: один
## дёрганый кадр не должен превращаться в выстрел (сессия 19: 21 м/с при каждом отпускании).
const MAX_FLING_MS := 6.0

## Фальсификатор «climbjump»: скачок трекинга не отсекается — рука дёргает человека через полкомнаты.
var falsify_no_clamp := false
## Фальсификатор «climbdrift»: точка захвата снова плывёт по кадрам — мир едет за дельтой руки, а
## не за смещением от зацепа (нечувствительность сессии 17).
var falsify_drift := false
## Фальсификатор «nobreak»: хват не срывается, как бы далеко рука ни ушла от зацепа.
var falsify_no_break := false

var active := false
## рука → {handle: Vector3 (мир, фиксирована), kind: "climb"|"pull"}
var hands: Dictionary = {}
## Кто ведёт: последняя схватившая рука.
var dominant := ""
var velocity := Vector3.ZERO
var _recent: Array = []


## Взяться рукой (hand — "left"/"right"), handle — точка захвата в мире.
## kind: «climb» — за поверхность (ведёт одна рука), «pull» — тяга мира за воздух (среднее).
func grab(hand: String, handle: Vector3, kind := "climb") -> void:
	hands[hand] = {"handle": handle, "kind": kind}
	dominant = hand
	active = true
	velocity = Vector3.ZERO
	_recent.clear()


## Отпустить. Ведение переходит второй руке, если она ещё держит.
func release(hand: String) -> void:
	hands.erase(hand)
	if dominant == hand:
		dominant = "" if hands.is_empty() else str(hands.keys()[0])
	if hands.is_empty():
		active = false
		velocity = _release_velocity()


## Хват сорвался: рука ушла от своего зацепа дальше BREAK_M. Возвращает сорвавшиеся руки.
func overreached(positions: Dictionary) -> Array:
	var out: Array = []
	if falsify_no_break:
		return out
	for hand in hands:
		if not positions.has(hand):
			continue
		if (positions[hand] as Vector3).distance_to(hands[hand]["handle"]) > BREAK_M:
			out.append(hand)
	return out


## Кадр: новые положения рук в мире. Возвращает смещение человека.
func update(positions: Dictionary, dt: float) -> Vector3:
	if not active or dt <= 0.0:
		return Vector3.ZERO
	var move := _pull_move(positions) if _all_pull() else _climb_move(positions)
	if move == Vector3.ZERO:
		return Vector3.ZERO
	if not falsify_no_clamp and move.length() > MAX_STEP_M:
		move = move.normalized() * MAX_STEP_M
	_recent.append({"v": move / dt, "t": dt})
	var total := 0.0
	for i in range(_recent.size() - 1, -1, -1):
		total += _recent[i]["t"]
		if total > RELEASE_WINDOW_S:
			_recent = _recent.slice(i)
			break
	return move


## Лазанье: ведёт одна рука, смещение — от ФИКСИРОВАННОЙ точки захвата, а не от прошлого кадра.
## После такого шага рука снова на зацепе: тело уносит с собой всю XR-сцену.
func _climb_move(positions: Dictionary) -> Vector3:
	if dominant == "" or not positions.has(dominant):
		return Vector3.ZERO
	var handle: Vector3 = hands[dominant]["handle"]
	var move := handle - (positions[dominant] as Vector3)
	if falsify_drift:
		# Дефект сессии 17: точка захвата съезжает за рукой, и от неё остаётся только дельта кадра.
		hands[dominant]["handle"] = positions[dominant]
	return move


## Тяга мира: держатся «за воздух» обеими руками — берём среднее, иначе одна спорит с другой.
func _pull_move(positions: Dictionary) -> Vector3:
	var sum := Vector3.ZERO
	var n := 0
	for hand in hands:
		if not positions.has(hand):
			continue
		sum += hands[hand]["handle"] - (positions[hand] as Vector3)
		if falsify_drift:
			hands[hand]["handle"] = positions[hand]
		n += 1
	return Vector3.ZERO if n == 0 else sum / float(n)


func _all_pull() -> bool:
	for hand in hands:
		if hands[hand]["kind"] != "pull":
			return false
	return not hands.is_empty()


## Полёт после отпускания: инерция руки плюс отталкивание по взгляду. Без отталкивания с уступа не
## оттолкнуться — человек просто сползает вниз по стене.
func release_velocity(look_dir := Vector3.ZERO) -> Vector3:
	var v := (velocity * FLING).limit_length(MAX_FLING_MS)
	if look_dir.length() > 0.01:
		v += look_dir.normalized() * FORWARD_PUSH
	return v


func _release_velocity() -> Vector3:
	if _recent.is_empty():
		return Vector3.ZERO
	var sum := Vector3.ZERO
	for r in _recent:
		sum += r["v"]
	return sum / float(_recent.size())
