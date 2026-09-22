extends RefCounted

## Проверка связности уровня по ДАННЫМ (просьба владельца 2026-09-22: «расположи так, чтобы они
## правильно соединялись»).
##
## Смотреть на сцену глазами — не проверка: лестница, врезавшаяся в площадку на две ступени, и
## площадка, висящая консолью 2.5 м, простояли в стартовой локации с этапа Ф3 и ни разу не
## покраснели. Здесь геометрия разбирается арифметикой: что на чём стоит, что во что врезалось,
## сходятся ли подъёмы с площадками, дотягивается ли рука до следующего зацепа.
##
## Файл — чистая статика без узлов: работает на данных до постройки сцены, поэтому проверяется
## настольно и может звать его редактор уровня (этап 3), а не только прибор.
##
## Намерение автора записывается в самих данных, иначе прибор запрещал бы обычные конструкции:
##   `join: [uuid…]`   — с кем пересечение задумано (угол стены, столешница на ножках);
##   `mounted_on: uuid`— объект держится за тело сбоку (зацеп в стене, полка), а не стоит на нём;
##   `floating: true`  — висит намеренно (облако, подвес);
##   `"part": true` у файла — это фрагмент, который грузится внутрь другого уровня: пола, точки
##                    старта и границ у него нет, и требовать их бессмысленно.
##
## Что НЕ проверяется: проходимость (для неё нужен объём тела и навигация) и красота. Замечание —
## это «данные противоречат сами себе», а не «мне не нравится».

## Зазор, при котором объект считается стоящим на опоре, м. 5 см — заметно меньше ступени (0.18) и
## заведомо больше ошибки округления в JSON.
const SUPPORT_GAP := 0.05
## Какую долю своей высоты объект может «надеться» на опору: столешница садится на ножки, брус
## входит в паз. Больше — это уже не опора, а врезка.
const SUPPORT_BITE := 0.34
## Глубже этого пересечение двух тел считается врезкой, м.
const OVERLAP := 0.02
## Стык подъёма (лестница, пандус) с площадкой: расхождение по высоте, м.
const JOIN_STEP := 0.06
## Досягаемость следующего зацепа от предыдущего, м (рука человека на стене).
const REACH := 0.65
## Высота первого зацепа над опорой, м: выше — не с чего начать.
const FIRST_HOLD := 0.95
## Какую долю своего размера закреплённый объект обязан высунуть из хозяина. Утопленный заподлицо
## зацеп не видно и не за что взяться: сессия 29 — стена лазанья простояла гладкой, и ни одного
## события лазанья в журнале не случилось.
const STICK_OUT := 0.3

## Типы, у которых есть тело и объём.
const SOLID_TYPES := ["box", "stairs"]

## Фальсификатор «joinblind»: стыки и опоры не проверяются — возвращается поведение «на глаз»,
## при котором лестница в площадке и висящая консоль считались нормой.
static var falsify_blind := false


## Прямоугольник объекта в мире: [min, max]. Поворот учитывается по восьми углам — для наклонного
## пандуса это коробка вокруг него, чего для проверки стыков достаточно.
static func aabb(obj: Dictionary) -> Array:
	var pos := _v3(obj.get("pos"))
	var size := _v3(obj.get("size"), Vector3.ONE)
	var rot := _v3(obj.get("rot"))
	if rot == Vector3.ZERO:
		return [pos - size * 0.5, pos + size * 0.5]
	var basis := Basis.from_euler(rot * (PI / 180.0))
	var lo := Vector3(1e9, 1e9, 1e9)
	var hi := -lo
	for sx in [-0.5, 0.5]:
		for sy in [-0.5, 0.5]:
			for sz in [-0.5, 0.5]:
				var c: Vector3 = pos + basis * Vector3(size.x * sx, size.y * sy, size.z * sz)
				lo = lo.min(c)
				hi = hi.max(c)
	return [lo, hi]


## Объём лесенки как одного тела: ступени идут вниз-назад от pos, и общая коробка шире объявленной.
static func stairs_aabb(obj: Dictionary) -> Array:
	var pos := _v3(obj.get("pos"))
	var size := _v3(obj.get("size"), Vector3.ONE)
	var rise := float(obj.get("rise", 0.18))
	var run := float(obj.get("run", 0.30))
	var count: int = maxi(1, int(round(size.y / rise)))
	# Ступень i: центр (pos.x, rise*(i+0.5), pos.z - run*i), размер (size.x, rise, run).
	var lo := Vector3(pos.x - size.x * 0.5, 0.0, pos.z - run * (count - 1) - run * 0.5)
	var hi := Vector3(pos.x + size.x * 0.5, rise * count, pos.z + run * 0.5)
	return [lo + Vector3(0, pos.y, 0), hi + Vector3(0, pos.y, 0)]


static func box_of(obj: Dictionary) -> Array:
	if str(obj.get("type", "")) == "stairs":
		return stairs_aabb(obj)
	return aabb(obj)


## Верхняя площадка подъёма: куда человек приходит, поднявшись.
##
## У наклонной плиты верхний угол коробки — это НЕ поверхность, по которой идут: она ниже на
## толщину плиты, развёрнутую наклоном. Сравнивать с площадкой надо поверхность, иначе верный
## пандус выглядит промахнувшимся на свою толщину.
static func top_of(obj: Dictionary) -> Vector3:
	var b := box_of(obj)
	var lo: Vector3 = b[0]
	var hi: Vector3 = b[1]
	if str(obj.get("type", "")) == "stairs":
		# Последняя ступень — у дальнего края (ступени уходят в −Z).
		return Vector3((lo.x + hi.x) * 0.5, hi.y, lo.z)
	var top := hi.y
	var rot := _v3(obj.get("rot"))
	if rot != Vector3.ZERO:
		var thick := _v3(obj.get("size"), Vector3.ONE).y
		top -= thick * cos(deg_to_rad(maxf(absf(rot.x), absf(rot.z))))
	return Vector3((lo.x + hi.x) * 0.5, top, (lo.z + hi.z) * 0.5)


static func _v3(a: Variant, fallback := Vector3.ZERO) -> Vector3:
	if not a is Array or (a as Array).size() < 3:
		return fallback
	return Vector3(float(a[0]), float(a[1]), float(a[2]))


static func _by_uuid(objects: Array, uuid: String) -> Dictionary:
	for o in objects:
		if str((o as Dictionary).get("uuid", "")) == uuid:
			return o
	return {}


## Торчит ли объект из хозяина хотя бы на STICK_OUT своего размера — по любой оси.
static func _buried(a: Array, host: Array) -> bool:
	for axis in 3:
		var size: float = a[1][axis] - a[0][axis]
		if size <= 0.0:
			continue
		var out: float = maxf(host[0][axis] - a[0][axis], a[1][axis] - host[1][axis])
		if out >= size * STICK_OUT:
			return false
	return true


## Касаются ли две коробки (с запасом на стык).
static func _touches(a: Array, b: Array, slack := 0.05) -> bool:
	return a[0].x < b[1].x + slack and b[0].x < a[1].x + slack \
			and a[0].y < b[1].y + slack and b[0].y < a[1].y + slack \
			and a[0].z < b[1].z + slack and b[0].z < a[1].z + slack


static func _overlap_xz(a: Array, b: Array, slack := 0.0) -> bool:
	return a[0].x < b[1].x + slack and b[0].x < a[1].x + slack \
			and a[0].z < b[1].z + slack and b[0].z < a[1].z + slack


## Все замечания к уровню. Пустой список — уровень связен.
static func run(data: Dictionary) -> Array:
	var notes: Array[String] = []
	if falsify_blind:
		return notes
	var objects: Array = data.get("objects", [])
	var part := bool(data.get("part", false))
	var solids: Array = []
	var floor_box: Array = []
	var floor_obj: Dictionary = {}
	for o in objects:
		var obj: Dictionary = o
		if str(obj.get("type", "")) in SOLID_TYPES and str(obj.get("body", "static")) != "none":
			solids.append(obj)
			# Пол — самое большое тело, лежащее в нуле высоты.
			var b := box_of(obj)
			if floor_box.is_empty() or (b[1].x - b[0].x) * (b[1].z - b[0].z) > (floor_box[1].x - floor_box[0].x) * (floor_box[1].z - floor_box[0].z):
				floor_box = b
				floor_obj = obj
	if floor_box.is_empty() and not part:
		notes.append("в уровне нет пола")
		return notes

	# 1. Опора: каждое тело стоит на полу или на другом теле. Висящее в воздухе — либо забытый
	#    объект, либо консоль, которую в шлеме принимают за твердь и проваливаются мимо.
	for obj in solids:
		if obj == floor_obj or bool(obj.get("floating", false)):
			continue
		var b := box_of(obj)
		# Закреплённый сбоку не стоит ни на чём — но обязан касаться того, за что держится.
		var mount := str(obj.get("mounted_on", ""))
		if mount != "":
			var host: Dictionary = _by_uuid(objects, mount)
			if host.is_empty():
				# Фрагмент крепится к стенам того уровня, в который его грузят: проверить это
				# здесь нечем, и требовать нельзя.
				if not part:
					notes.append("«%s» закреплён на «%s», которого в уровне нет" % [obj.get("uuid", ""), mount])
			elif not _touches(b, box_of(host)):
				notes.append("«%s» закреплён на «%s», но не касается его" % [obj.get("uuid", ""), mount])
			elif _buried(b, box_of(host)):
				notes.append("«%s» утоплен в «%s» заподлицо — его не видно и не взяться" % [
						obj.get("uuid", ""), mount])
			continue
		var rest := ""
		for other in solids:
			if other == obj:
				continue
			var ob := box_of(other)
			if not _overlap_xz(b, ob):
				continue
			# Опора может входить в объект снизу (ножки в столешницу), но не сквозь него.
			var bite: float = (b[1].y - b[0].y) * SUPPORT_BITE
			if ob[1].y <= b[0].y + bite and ob[1].y >= b[0].y - SUPPORT_GAP:
				rest = str(other.get("uuid", ""))
				break
		# У фрагмента своего пола нет: стоящее на нуле стоит на полу принимающего уровня.
		if rest == "" and part and absf(b[0].y) <= SUPPORT_GAP:
			continue
		if rest == "":
			notes.append("«%s» висит в воздухе: низ на %.2f м, опоры под ним нет" % [
					obj.get("uuid", ""), b[0].y])

	# 2. Врезки: тела не входят друг в друга глубже допуска. Явное «join» — список uuid, с которыми
	#    пересечение задумано (косяк, закладная, вмурованный брус).
	for i in solids.size():
		for j in range(i + 1, solids.size()):
			var a: Dictionary = solids[i]
			var c: Dictionary = solids[j]
			var au := str(a.get("uuid", ""))
			var cu := str(c.get("uuid", ""))
			if cu in (a.get("join", []) as Array) or au in (c.get("join", []) as Array):
				continue
			# Закреплённый сбоку входит в свою опору по определению.
			if str(a.get("mounted_on", "")) == cu or str(c.get("mounted_on", "")) == au:
				continue
			var ab := box_of(a)
			var cb := box_of(c)
			var dx: float = minf(ab[1].x, cb[1].x) - maxf(ab[0].x, cb[0].x)
			var dy: float = minf(ab[1].y, cb[1].y) - maxf(ab[0].y, cb[0].y)
			var dz: float = minf(ab[1].z, cb[1].z) - maxf(ab[0].z, cb[0].z)
			var deep: float = minf(dx, minf(dy, dz))
			if deep > OVERLAP:
				notes.append("«%s» и «%s» врезаны друг в друга на %.2f м" % [au, cu, deep])

	# 3. Всё в пределах пола: за краем человек проваливается в бесконечность (сессия 17).
	for obj in (objects if not part else []):
		if not str(obj.get("type", "")) in SOLID_TYPES:
			continue
		var b := box_of(obj)
		if b[0].x < floor_box[0].x - OVERLAP or b[1].x > floor_box[1].x + OVERLAP \
				or b[0].z < floor_box[0].z - OVERLAP or b[1].z > floor_box[1].z + OVERLAP:
			notes.append("«%s» выходит за край пола" % obj.get("uuid", ""))

	# 4. Подъёмы сходятся с площадками: верх лестницы или пандуса должен совпадать по высоте с той
	#    площадкой, к которой он примыкает. Иначе подъём кончается ступенькой в воздух.
	for obj in objects:
		# Приводить строку к bool нельзя — конструктора нет, и ошибка исполнения обрывает разбор
		# молча: список замечаний возвращается ПУСТЫМ, то есть «уровень связен».
		var to := str(obj.get("leads_to", ""))
		if to == "":
			continue
		var target: Dictionary = {}
		for other in objects:
			if str(other.get("uuid", "")) == to:
				target = other
		if target.is_empty():
			notes.append("«%s» ведёт к «%s», которого в уровне нет" % [obj.get("uuid", ""), to])
			continue
		var top := top_of(obj)
		var tb := box_of(target)
		var dh: float = absf(top.y - tb[1].y)
		if dh > JOIN_STEP:
			notes.append("«%s» кончается на %.2f м, а площадка «%s» на %.2f м — расхождение %.2f м" % [
					obj.get("uuid", ""), top.y, to, tb[1].y, dh])
		if not _overlap_xz(box_of(obj), tb, SUPPORT_GAP):
			notes.append("«%s» не примыкает к площадке «%s»" % [obj.get("uuid", ""), to])

	# 5. Зацепы: до следующего надо дотянуться, а до первого — достать с опоры.
	var holds: Array = []
	for obj in objects:
		if "climb" in (obj.get("tags", []) as Array):
			holds.append(obj)
	if not holds.is_empty():
		holds.sort_custom(func(a, b): return _v3(a.get("pos")).y < _v3(b.get("pos")).y)
		var first := _v3(holds[0].get("pos"))
		var under := 0.0
		for obj in solids:
			var ob := box_of(obj)
			if ob[1].y <= first.y and _overlap_xz([first, first], ob, 0.6):
				under = maxf(under, ob[1].y)
		if first.y - under > FIRST_HOLD:
			notes.append("до первого зацепа «%s» %.2f м от опоры — не с чего начать" % [
					holds[0].get("uuid", ""), first.y - under])
		for i in range(1, holds.size()):
			var p := _v3(holds[i].get("pos"))
			var best := 1e9
			for j in i:
				best = minf(best, p.distance_to(_v3(holds[j].get("pos"))))
			if best > REACH:
				notes.append("от зацепа к «%s» %.2f м — рука не дотянется (предел %.2f)" % [
						holds[i].get("uuid", ""), best, REACH])

	# 5а. Подсказки читаются: табличка внутри дома или в толще стены невидима, а выглядит как
	#     «подпись забыли». Сессия 29: подпись стены лазанья стояла внутри дома, и две надписи
	#     наложились друг на друга.
	for obj in objects:
		if str(obj.get("type", "")) != "sign":
			continue
		var p := _v3(obj.get("pos"))
		for sol in solids:
			var sb := box_of(sol)
			if p.x > sb[0].x and p.x < sb[1].x and p.y > sb[0].y and p.y < sb[1].y \
					and p.z > sb[0].z and p.z < sb[1].z:
				notes.append("подсказка «%s» внутри «%s» — её не прочитать" % [
						obj.get("uuid", ""), sol.get("uuid", "")])
				break

	# 6. Кромка перевала: точка приземления обязана лежать НА площадке, иначе человека ставит в
	#    воздух (сессия 22 — «телепортировало куда-то далеко»).
	for obj in objects:
		if str(obj.get("type", "")) != "ledge":
			continue
		var t := _v3(obj.get("target"))
		var stands := ""
		for s in solids:
			var sb := box_of(s)
			if _overlap_xz([t, t], sb) and absf(sb[1].y - t.y) <= JOIN_STEP:
				stands = str(s.get("uuid", ""))
				break
		if stands == "":
			notes.append("кромка «%s»: точка приземления %s не лежит ни на одной площадке" % [
					obj.get("uuid", ""), t])

	# 7. Точка старта: на полу и не внутри тела.
	for obj in (objects if not part else []):
		if str(obj.get("type", "")) != "spawn":
			continue
		var p := _v3(obj.get("pos"))
		var inside := ""
		for s in solids:
			if s == floor_obj:
				continue
			var sb := box_of(s)
			if p.x > sb[0].x and p.x < sb[1].x and p.z > sb[0].z and p.z < sb[1].z \
					and sb[1].y > p.y + 0.1:
				inside = str(s.get("uuid", ""))
				break
		if inside != "":
			notes.append("точка старта внутри «%s»" % inside)
		if p.x < floor_box[0].x or p.x > floor_box[1].x or p.z < floor_box[0].z or p.z > floor_box[1].z:
			notes.append("точка старта за краем пола")

	return notes
