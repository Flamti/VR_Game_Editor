extends RefCounted

## Сторож рывка высоты глаз: кто сдвинул вид по вертикали за один кадр.
##
## «Рывок вниз и стоп» при появлении (2026-09-26) без чисел неотличим от «присел» и «провалился» —
## ровно урок ловушки 57. Высота глаз в мире складывается из трёх слагаемых, и у каждого свой хозяин:
## ноги тела (физика), origin (наш код: догон головы, присед, возврат) и поза камеры внутри origin
## (рантайм: пространство отсчёта, перецентровка). Сторож называет, КОТОРОЕ из них сдвинулось.
##
## Переносы, которые делаем мы сами (телепорт, перевал, возврат в старт), — законные скачки. Прежде
## они шли в общий лимит строк, и к 17:52:39 сессии 24 сторож замолчал: десять строк съели
## телепорты. Теперь такие скачки считаются отдельно и лимит не тратят — но только если сдвинулось
## то слагаемое, которое двигал перенос: телепорт двигает ноги и не объясняет скачок origin.
##
## Классификация — чистая функция на значениях, счёт — в экземпляре: и то и другое проверяется
## настольно, без шлема, а `main.gd` только подаёт снимки.

## Скачок меньше этого — дыхание, наклон, шаг: не рывок, м.
const JUMP_M := 0.10
## Слагаемое считается сдвинувшимся от этого, м.
const PART_M := 0.02
## Сколько необъяснённых рывков печатать — чтобы не залить лог.
const JUMPS_MAX := 10

const NAMES := {"body": "ноги", "origin": "origin", "cam": "камера в origin"}

## Фальсификатор «watchblind» (tests/run_tests.gd): origin не называется виновником — сторож
## молчит ровно о том слагаемом, которое двигает наш код.
static var falsify_blind_origin := false
## Фальсификатор «watchours»: наши переносы идут в общий лимит, как до сессии 25.
static var falsify_ours_counted := false
## Фальсификатор «watchcover»: наш перенос объясняет любой скачок, какое бы слагаемое ни сдвинулось.
static var falsify_ours_cover := false

## Прошлый снимок.
var was: Dictionary = {}
## Напечатано необъяснённых рывков.
var jumps := 0
## Скачки от наших переносов: имя переноса → сколько кадров со скачком.
var ours: Dictionary = {}
## Номер последнего переноса, который сторож уже видел (`PlayerBody.transfer_seq`).
var _seen_seq := 0


## Снимок слагаемых: ноги, origin и камера — по вертикали, м.
static func sample(body_y: float, origin_y: float, cam_local_y: float) -> Dictionary:
	return {"body": body_y, "origin": origin_y, "cam": cam_local_y, "eye": body_y + origin_y + cam_local_y}


## Какие слагаемые сдвинулись между снимками.
static func moved_parts(p_was: Dictionary, now: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for k in ["body", "origin", "cam"]:
		if absf(float(now[k]) - float(p_was[k])) >= PART_M:
			out.append(k)
	return out


## Пусто — рывка нет; иначе строка «глаза A → B: кто и насколько».
static func classify(p_was: Dictionary, now: Dictionary) -> String:
	if p_was.is_empty() or absf(float(now["eye"]) - float(p_was["eye"])) <= JUMP_M:
		return ""
	var who: Array[String] = []
	for k in moved_parts(p_was, now):
		if k == "origin" and falsify_blind_origin:
			continue
		var d := float(now[k]) - float(p_was[k])
		who.append("%s %+.2f (%.2f → %.2f)" % [NAMES[k], d, float(p_was[k]), float(now[k])])
	return "глаза %.2f → %.2f: %s" % [float(p_was["eye"]), float(now["eye"]),
			", ".join(who) if not who.is_empty() else "слагаемые по отдельности не сдвинулись"]


## Скачок объяснён нашим переносом: всё сдвинувшееся — из того, что перенос двигал. Если не
## сдвинулось ни одно слагаемое по отдельности, объяснять нечем — рывок остаётся рывком.
static func explained(p_was: Dictionary, now: Dictionary, parts: Array) -> bool:
	var moved := moved_parts(p_was, now)
	if moved.is_empty():
		return false
	if falsify_ours_cover:
		return true
	for k in moved:
		if not parts.has(k):
			return false
	return true


## Кадр сторожа. `seq`, `label`, `parts` — последний наш перенос (`PlayerBody.transfer_*`): если его
## номер сменился со прошлого кадра, перенос был между снимками. Возвращает строку для лога или "".
func step(now: Dictionary, seq: int, label: String, parts: Array) -> String:
	var line := ""
	var msg := classify(was, now)
	var ours_now := seq != _seen_seq
	_seen_seq = seq
	if msg != "":
		if ours_now and not falsify_ours_counted and explained(was, now, parts):
			ours[label] = int(ours.get(label, 0)) + 1
		elif jumps < JUMPS_MAX:
			jumps += 1
			line = "ПОЗА[рывок %d] %s%s%s" % [jumps, msg,
					", во время переноса «%s», который его не объясняет" % label if ours_now else "",
					"; наших скачков до него: %s" % ours_text() if not ours.is_empty() else ""]
	was = now
	return line


## «телепорт 5, перевал 2» — сколько КАДРОВ со скачком от наших переносов не пошло в лимит (перевал
## длится много кадров, и один перевал даёт несколько).
func ours_text() -> String:
	var out: Array[String] = []
	for k in ours:
		out.append("%s %d" % [k, int(ours[k])])
	return ", ".join(out)
