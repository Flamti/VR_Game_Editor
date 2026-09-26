extends RefCounted

## Сторож рывка высоты глаз: кто сдвинул вид по вертикали за один кадр.
##
## «Рывок вниз и стоп» при появлении (2026-09-26) без чисел неотличим от «присел» и «провалился» —
## ровно урок ловушки 57. Высота глаз в мире складывается из трёх слагаемых, и у каждого свой хозяин:
## ноги тела (физика), origin (наш код: догон головы, присед, возврат) и поза камеры внутри origin
## (рантайм: пространство отсчёта, перецентровка). Сторож называет, КОТОРОЕ из них сдвинулось.
##
## Чистая функция на значениях — чтобы классификацию можно было проверить настольно, без шлема.

## Скачок меньше этого — дыхание, наклон, шаг: не рывок, м.
const JUMP_M := 0.10
## Слагаемое считается сдвинувшимся от этого, м.
const PART_M := 0.02

## Фальсификатор «watchblind» (tests/run_tests.gd): origin не называется виновником — сторож
## молчит ровно о том слагаемом, которое двигает наш код.
static var falsify_blind_origin := false


## Снимок слагаемых: ноги, origin и камера — по вертикали, м.
static func sample(body_y: float, origin_y: float, cam_local_y: float) -> Dictionary:
	return {"body": body_y, "origin": origin_y, "cam": cam_local_y, "eye": body_y + origin_y + cam_local_y}


## Пусто — рывка нет; иначе строка «глаза A → B: кто и насколько».
static func classify(was: Dictionary, now: Dictionary) -> String:
	if was.is_empty() or absf(float(now["eye"]) - float(was["eye"])) <= JUMP_M:
		return ""
	var who: Array[String] = []
	var names := {"body": "ноги", "origin": "origin", "cam": "камера в origin"}
	for k in ["body", "origin", "cam"]:
		if k == "origin" and falsify_blind_origin:
			continue
		var d := float(now[k]) - float(was[k])
		if absf(d) >= PART_M:
			who.append("%s %+.2f (%.2f → %.2f)" % [names[k], d, float(was[k]), float(now[k])])
	return "глаза %.2f → %.2f: %s" % [float(was["eye"]), float(now["eye"]),
			", ".join(who) if not who.is_empty() else "слагаемые по отдельности не сдвинулись"]
