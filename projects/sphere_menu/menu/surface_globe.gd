extends "res://menu/surface.gd"

## Глобус: объекты прибиты к ячейкам многогранника Гольдберга и вращаются вместе
## с шаром; полный оборот возвращает те же объекты; 12 пятиугольников видны
## (ADR-0008, «Не решено»).

const Goldberg := preload("res://menu/goldberg.gd")

var g: RefCounted
## Поворот шара: локальная ячейка i смотрит в orientation * centers[i].
var orientation := Quaternion.IDENTITY
## ячейка → слот
var _slots: PackedInt32Array = PackedInt32Array()
## Меняется при смене слотов (раздача, прокрутка папки), но не при повороте.
var _slot_version := 0
var _local_cells: Array = []
var _local_version := -1


## Размер каждой ячейки по её контуру: доля угла до вершин контура от опорного
## (угол ячейки по медиане соседей, до вершины). Рендер рисует опорный размер
## (settings.actual_cell_cm), умноженный на эту долю. Один размер на все ячейки
## давал перекрытие соседей на 642 ячейках и зазор 1.2% расстояния на 42
## (замер 2026-09-15; по контуру — без перекрытий, зазор 3.9–15.3%).
var _scales: PackedFloat32Array = PackedFloat32Array()


func _init(lvl: int = 3) -> void:
	g = Goldberg.build(lvl)
	_slots.resize(g.centers.size())
	_slots.fill(SLOT_EMPTY)
	var ref: float = g.cell_angle() * 2.0 / sqrt(3.0)
	_scales.resize(g.centers.size())
	for i in g.centers.size():
		_scales[i] = g.vertex_angle(i) / ref


## Уровень ряда Goldberg.LEVELS.
func frequency() -> int:
	return g.level


## Пункты — спиралью BFS от активной ячейки. «Назад» — сосед активной, ближайший
## к направлению «влево» от переда (как у линзы: слева от центра).
func assign(item_count: int) -> void:
	_slots.fill(SLOT_EMPTY)
	var start: int = cell_at_direction(front)
	var left := up.cross(front).normalized() * -1.0
	var back := -1
	var best := -INF
	for j in g.neighbors[start]:
		var d: float = (orientation * g.centers[j] - orientation * g.centers[start]).normalized().dot(left)
		if d > best:
			best = d
			back = j
	_slots[back] = SLOT_BACK
	version += 1
	_slot_version += 1
	var queue: Array[int] = [start]
	var seen := {start: true, back: true}
	var next := 0
	while not queue.is_empty() and next < item_count:
		var c: int = queue.pop_front()
		_slots[c] = next
		next += 1
		for j in g.neighbors[c]:
			if not seen.has(j):
				seen[j] = true
				queue.append(j)


func visible_cells() -> Array:
	var out: Array = []
	for i in g.centers.size():
		var dir: Vector3 = orientation * g.centers[i]
		out.append({"key": i, "slot": _slots[i], "dir": dir,
				"sides": (g.neighbors[i] as Array).size(), "scale": _scales[i],
				"spin": _spin(i)})
	return out


## Ячейки в неповёрнутой системе шара — считаются один раз на раздачу.
func render_cells() -> Array:
	if _local_version != _slot_version:
		var saved := orientation
		orientation = Quaternion.IDENTITY
		_local_cells = visible_cells()
		orientation = saved
		_local_version = _slot_version
	return _local_cells


func render_basis() -> Basis:
	return Basis(orientation)


func render_version() -> int:
	return _slot_version


func cell_at_direction(dir: Vector3) -> Variant:
	var local := orientation.inverse() * dir.normalized()
	var best := 0
	var best_dot := -INF
	for i in g.centers.size():
		var d: float = g.centers[i].dot(local)
		if d > best_dot:
			best_dot = d
			best = i
	return best


func direction_of(key: Variant) -> Vector3:
	return orientation * g.centers[int(key)]


func slot_of(key: Variant) -> int:
	return _slots[int(key)]


func apply_rotation(q: Quaternion) -> void:
	if q.is_equal_approx(Quaternion.IDENTITY):
		return
	orientation = (q * orientation).normalized()
	version += 1


func snap_error() -> float:
	return direction_of(cell_at_direction(front)).angle_to(front)


func snap_rotation() -> Quaternion:
	var d := direction_of(cell_at_direction(front))
	return Quaternion(d, front) if d.angle_to(front) > 1e-6 else Quaternion.IDENTITY


func cell_angle() -> float:
	return g.cell_angle()


func get_scroll() -> Variant:
	return {"orientation": orientation, "slots": _slots.duplicate()}


func set_scroll(v: Variant) -> void:
	if v is Dictionary:
		orientation = v["orientation"]
		_slots = v["slots"]
		version += 1
		_slot_version += 1


## Поворот контура вокруг нормали: угол от касательной оси рендера до первой
## вершины контура. Считается в ПОВЁРНУТЫХ координатах: касательная ось рендера
## привязана к мировому «вверх» и с шаром не вращается. Первая версия считала в
## неповёрнутых и расходилась с рендером на 1 рад (проверка «ориентация контура»).
func _spin(i: int) -> float:
	var c: Vector3 = orientation * g.centers[i]
	var o: Vector3 = orientation * (g.outlines[i] as PackedVector3Array)[0]
	var ref := _tangent_ref(c)
	var p := (o - c * o.dot(c)).normalized()
	return atan2(c.dot(ref.cross(p)), ref.dot(p))


## Устойчивая касательная ось в точке сферы — общая для рендера и контура.
static func _tangent_ref(n: Vector3) -> Vector3:
	var a := Vector3.UP if absf(n.y) < 0.9 else Vector3.RIGHT
	return (a - n * a.dot(n)).normalized()
