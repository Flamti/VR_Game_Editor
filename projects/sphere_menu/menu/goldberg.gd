extends RefCounted

## Многогранник Гольдберга — ячейки глобуса (docs/design/sphere-menu.md §4).
##
## Геометрия запечена tools/bake_goldberg.py в menu/geo/*.json: двойственная к
## геодезической сфере сетка, выровненная пружинами на равные расстояния между
## соседями. Выравнивание — сотни итераций по 642 ячейкам, в GDScript на шлеме это
## секунды на каждую смену размера, поэтому здесь только загрузка. Прежнее
## построение на лету (планарные барицентрические точки + нормировка) давало
## разброс расстояний до соседей до 1.38 и площадей до 2.33 — на шлеме «ячейки
## съезжают» (сессия 2026-09-15). Почему пружины, а не площади — в заголовке
## запекателя (замер).
##
## Ряд размеров (уровни): GP(1,0) икосаэдр, GP(1,1), GP(2,0)…GP(8,0) —
## 12, 32, 42, 92, 162, 252, 362, 492, 642 ячейки. Пятиугольников всегда 12
## (Goldberg 1937; en.wikipedia.org/wiki/Goldberg_polyhedron). Крупные уровни —
## по отзыву владельца «вплоть до ~7 ячеек на лицевой стороне».

## Уровень → имя файла и число ячеек. Число — проверка загрузки, а не справка.
const LEVELS := [["gp1_0", 12], ["gp1_1", 32], ["gp2_0", 42], ["gp3_0", 92], ["gp4_0", 162],
		["gp5_0", 252], ["gp6_0", 362], ["gp7_0", 492], ["gp8_0", 642]]
const GEO_DIR := "res://menu/geo/"

## Центры ячеек, единичные векторы.
var centers: PackedVector3Array = PackedVector3Array()
## ячейка → Array[int] соседей, упорядоченных по кругу вокруг центра
var neighbors: Array = []
## ячейка → PackedVector3Array контура на единичной сфере, по кругу
var outlines: Array = []
## Уровень ряда LEVELS.
var level := 0
## Метрики запекателя до и после выравнивания — для журнала, проверки считают свои.
var baked_metrics: Dictionary = {}

static var _cache: Dictionary = {}
var _cell_angle := -1.0


## Сетки общие (кэш): глобус пересоздаётся при каждой смене размера. Кто меняет
## данные сетки, берёт fresh — иначе порча утечёт во все глобусы этого уровня.
## raw — центры до выравнивания (фальсификатор настольных проверок), всегда fresh.
## Контуры и соседство те же: выравнивание не меняет топологию.
static func build(lvl: int, raw: bool = false, fresh: bool = false) -> RefCounted:
	lvl = clampi(lvl, 0, LEVELS.size() - 1)
	var shared := not raw and not fresh
	if shared and _cache.has(lvl):
		return _cache[lvl]
	var g = load("res://menu/goldberg.gd").new()
	g._load(lvl, raw)
	if shared:
		_cache[lvl] = g
	return g


static func cells_at(lvl: int) -> int:
	return int(LEVELS[clampi(lvl, 0, LEVELS.size() - 1)][1])


func is_pentagon(i: int) -> bool:
	return (neighbors[i] as Array).size() == 5


func pentagon_count() -> int:
	var n := 0
	for i in centers.size():
		if is_pentagon(i):
			n += 1
	return n


## Угловой радиус ячейки: половина медианного угла до соседа.
## Считается один раз: ползунок размера пересоздаёт глобус каждый кадр, а сортировка
## 3852 углов в GDScript — миллисекунды.
func cell_angle() -> float:
	if _cell_angle >= 0.0:
		return _cell_angle
	var angles: Array[float] = []
	for i in centers.size():
		for j in neighbors[i]:
			angles.append(centers[i].angle_to(centers[j]))
	angles.sort()
	_cell_angle = angles[angles.size() / 2] * 0.5
	return _cell_angle


## Угол от центра ячейки до вершин её контура, среднее по вершинам.
func vertex_angle(i: int) -> float:
	var s := 0.0
	var o: PackedVector3Array = outlines[i]
	for v in o:
		s += centers[i].angle_to(v)
	return s / float(o.size())


func _load(lvl: int, raw: bool) -> void:
	level = lvl
	var path: String = GEO_DIR + LEVELS[lvl][0] + ".json"
	var text := FileAccess.get_file_as_string(path)
	var data: Variant = JSON.parse_string(text)
	if not (data is Dictionary) or int(data.get("cells", -1)) != int(LEVELS[lvl][1]):
		push_error("goldberg: %s не загружен или не той частоты (%s)" % [path, FileAccess.get_open_error()])
		return
	baked_metrics = {"before": data["metrics_before"], "after": data["metrics_after"]}
	for c in data["centers_raw" if raw else "centers"]:
		centers.append(Vector3(c[0], c[1], c[2]).normalized())
	for nb in data["neighbors"]:
		var a: Array = []
		for j in nb:
			a.append(int(j))
		neighbors.append(a)
	for ring in data["outlines"]:
		var o := PackedVector3Array()
		for v in ring:
			o.append(Vector3(v[0], v[1], v[2]).normalized())
		outlines.append(o)
