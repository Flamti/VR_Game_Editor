extends RefCounted

## Сетка ячеек на сфере — загрузка запечённых раскладок (docs/design/sphere-menu.md §4).
##
## Геометрия запечена tools/bake_grids.py в menu/geo/*.json: центры ячеек, соседи и контуры
## Вороного, выровненные пружинами (кроме колец). Выравнивание — сотни итераций по сотням
## ячеек, в GDScript на шлеме это секунды на каждую смену размера, поэтому здесь только
## загрузка. Прежнее построение на лету давало «ячейки съезжают» (сессия 1, 2026-09-15).
##
## Семейства (решение владельца после сессии 2):
##   icosa — Гольдберг на икосаэдре, 12 пятиугольников (глобус и глобус со скрытыми дефектами);
##   octa  — Гольдберг на октаэдре, 6 квадратов;
##   rings — ряды по широтам кирпичной кладкой;
##   fib   — золотая спираль, дефекты рассеяны.
## Сфера только из шестиугольников невозможна: у сетки с тремя ячейками в вершине
## Σ(6 − сторон) = 12 (формула Эйлера) — дефекты можно лишь сменить, собрать или спрятать.
##
## Ряд уровней каждого семейства — menu/geo/index.json, его пишет запекатель: один перечень
## на запекатель и приложение (PRACTICES §1.8), уровни от крупных ячеек к мелким.

const GEO_DIR := "res://menu/geo/"
const FAMILIES := ["icosa", "octa", "rings", "fib"]

## Центры ячеек, единичные векторы.
var centers: PackedVector3Array = PackedVector3Array()
## ячейка → Array[int] соседей, упорядоченных по кругу вокруг центра
var neighbors: Array = []
## ячейка → PackedVector3Array контура на единичной сфере, по кругу
var outlines: Array = []
var family := "icosa"
## Уровень в ряду семейства.
var level := 0
var name := ""
## Метрики запекателя до и после выравнивания — для журнала, проверки считают свои.
var baked_metrics: Dictionary = {}

static var _cache: Dictionary = {}
static var _index: Dictionary = {}
var _cell_angle := -1.0


## Ряд семейства: Array [имя, ячеек], от крупных ячеек к мелким.
static func ladder(fam: String) -> Array:
	if _index.is_empty():
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(GEO_DIR + "index.json"))
		if data is Dictionary:
			_index = data
		else:
			push_error("goldberg: index.json не загружен (%s)" % FileAccess.get_open_error())
	return _index.get(fam, [])


static func level_count(fam: String) -> int:
	return ladder(fam).size()


static func cells_at(fam: String, lvl: int) -> int:
	var l := ladder(fam)
	return int(l[clampi(lvl, 0, l.size() - 1)][1]) if not l.is_empty() else 0


## Сетки общие (кэш): глобус пересоздаётся при каждой смене размера. Кто меняет данные
## сетки, берёт fresh — иначе порча утечёт во все глобусы этого уровня.
## raw — центры до выравнивания (фальсификатор настольных проверок), всегда fresh.
static func build(lvl: int, fam: String = "icosa", raw: bool = false, fresh: bool = false) -> RefCounted:
	lvl = clampi(lvl, 0, maxi(0, level_count(fam) - 1))
	var key := "%s:%d" % [fam, lvl]
	var shared := not raw and not fresh
	if shared and _cache.has(key):
		return _cache[key]
	var g = load("res://menu/goldberg.gd").new()
	g._load(fam, lvl, raw)
	if shared:
		_cache[key] = g
	return g


## Дефект сетки — ячейка не шестиугольная (пятиугольник, квадрат, семиугольник).
func is_defect(i: int) -> bool:
	return (neighbors[i] as Array).size() != 6


func is_pentagon(i: int) -> bool:
	return (neighbors[i] as Array).size() == 5


func pentagon_count() -> int:
	var n := 0
	for i in centers.size():
		if is_pentagon(i):
			n += 1
	return n


## Угловой радиус ячейки: половина медианного угла до соседа. Считается один раз:
## ползунок размера пересоздаёт глобус каждый кадр, а сортировка тысяч углов в GDScript —
## миллисекунды.
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


func _load(fam: String, lvl: int, raw: bool) -> void:
	family = fam
	level = lvl
	var l := ladder(fam)
	if l.is_empty():
		push_error("goldberg: нет ряда «%s»" % fam)
		return
	name = l[lvl][0]
	var path: String = GEO_DIR + name + ".json"
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (data is Dictionary) or int(data.get("cells", -1)) != int(l[lvl][1]):
		push_error("goldberg: %s не загружен или не того размера (%s)" % [path, FileAccess.get_open_error()])
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
