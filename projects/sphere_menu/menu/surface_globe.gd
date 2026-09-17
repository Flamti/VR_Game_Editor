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
## Подсказка поиска: ячейка, найденная в прошлый раз. Спуск по соседям от неё вместо полного
## перебора — доводка и активная спрашивают ячейку под «передом» до трёх раз за кадр, а полный
## перебор 632 ячеек стоит 80 мкс на столе (замер 2026-09-16) и втрое дороже на шлеме:
## самопроверка сессии 3 показала у неподвижного шара 5.33 мс скриптов против 2.60 при вращении.
var _hint := 0
## Фальсификатор настольных проверок «descend»: спуск обрывается после первого шага.
var falsify_one_step := false


## Размер каждой ячейки по её контуру: доля угла до вершин контура от опорного
## (угол ячейки по медиане соседей, до вершины). Рендер рисует опорный размер
## (settings.actual_cell_cm), умноженный на эту долю. Один размер на все ячейки
## давал перекрытие соседей на 642 ячейках и зазор 1.2% расстояния на 42
## (замер 2026-09-15; по контуру — без перекрытий, зазор 3.9–15.3%).
var _scales: PackedFloat32Array = PackedFloat32Array()


## Скрыть дефекты сетки: пункты и активная — только на шестиугольниках (раскладка
## «глобус без пятиугольников», решение владельца после сессии 2).
var hide_defects := false


func _init(lvl: int = 3, fam: String = "icosa", p_hide_defects: bool = false) -> void:
	hide_defects = p_hide_defects
	g = Goldberg.build(lvl, fam)
	_slots.resize(g.centers.size())
	_slots.fill(SLOT_EMPTY)
	var ref: float = g.cell_angle() * 2.0 / sqrt(3.0)
	_scales.resize(g.centers.size())
	for i in g.centers.size():
		var va: float = g.vertex_angle(i)
		if fam != "icosa":
			# У неровных ячеек (октаэдр, кольца, спираль) правильный многоугольник по среднему
			# углу контура перекрывал соседа до 18% расстояния (замер 2026-09-16): вписанный
			# радиус ограничен половиной расстояния до ближайшего соседа. Икосаэдру не нужно —
			# там по контуру без перекрытий, а ограничение разводит ячейки (0.04→0.10).
			var nearest := INF
			for j in g.neighbors[i]:
				nearest = minf(nearest, g.centers[i].angle_to(g.centers[j]))
			var sides := float((g.neighbors[i] as Array).size())
			va = minf(va, nearest * 0.5 / cos(PI / sides))
		_scales[i] = va / ref


## Уровень в ряду семейства сетки (menu/geo/index.json).
func frequency() -> int:
	return g.level


## Пункты — спиралью BFS от активной ячейки. «Назад» — сосед активной, ближайший
## к направлению «влево» от переда (как у линзы: слева от центра).
func assign(item_count: int, with_back: bool = true, with_next: bool = false, with_prev: bool = false) -> void:
	_slots.fill(SLOT_EMPTY)
	var start: int = active_at(front)
	var right := up.cross(front).normalized()
	var back := _neighbor_toward(start, -right)
	var seen := {start: true}
	if with_back:
		_slots[back] = SLOT_BACK
		seen[back] = true
	# «Дальше» — сосед справа; «Раньше» — общий сосед активной и «Дальше», тот, что выше.
	var nxt := _neighbor_toward(start, _next_dir(right))
	if with_next or with_prev:
		if with_next:
			_slots[nxt] = SLOT_NEXT
			seen[nxt] = true
		if with_prev:
			var prv := -1
			var best_up := -INF
			var base: Vector3 = orientation * g.centers[start]
			for j in g.neighbors[start]:
				if j == nxt or j == back or not (g.neighbors[nxt] as Array).has(j):
					continue
				var d: float = (orientation * g.centers[j] - base).dot(up)
				if d > best_up:
					best_up = d
					prv = j
			if prv >= 0:
				_slots[prv] = SLOT_PREV
				seen[prv] = true
	version += 1
	_slot_version += 1
	var queue: Array[int] = [start]
	var next := 0
	while not queue.is_empty() and next < item_count:
		var c: int = queue.pop_front()
		# обход идёт и через дефекты (иначе они рвали бы спираль), пункты на них не ставятся
		if _slots[c] == SLOT_EMPTY and not (hide_defects and g.is_defect(c)):
			_slots[c] = next
			next += 1
		for j in g.neighbors[c]:
			if not seen.has(j):
				seen[j] = true
				queue.append(j)


## Фальсификатор «nextleft»: «Дальше» встаёт слева, где и «Назад».
var falsify_next_left := false


func _next_dir(right: Vector3) -> Vector3:
	return -right if falsify_next_left else right


## Сосед ячейки, чьё смещение от неё сильнее всего смотрит в направлении dir (в мире шара).
func _neighbor_toward(cell: int, dir: Vector3) -> int:
	var base: Vector3 = orientation * g.centers[cell]
	var out := -1
	var best := -INF
	for j in g.neighbors[cell]:
		var d: float = (orientation * g.centers[j] - base).normalized().dot(dir)
		if d > best:
			best = d
			out = j
	return out


func capacity(with_back: bool = true) -> int:
	var n: int = g.centers.size()
	if hide_defects:
		for i in n:
			if g.is_defect(i):
				n -= 1
	return n - (1 if with_back else 0)


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
	_hint = _descend(orientation.inverse() * dir.normalized(), _hint)
	return _hint


## Спуск по соседям: из ячейки start переходим к соседу, который ближе к направлению, пока
## такие есть. Ячейки Вороного выпуклы, поэтому локальный максимум — глобальный; совпадение
## с полным перебором проверяет настольная проверка «поиск ячейки».
func _descend(local: Vector3, start: int) -> int:
	var cur := clampi(start, 0, g.centers.size() - 1)
	var cur_dot: float = g.centers[cur].dot(local)
	var steps := 0
	while true:
		steps += 1
		if falsify_one_step and steps > 1:
			return cur
		var best := cur
		var best_dot := cur_dot
		for j in g.neighbors[cur]:
			var d: float = g.centers[j].dot(local)
			if d > best_dot:
				best_dot = d
				best = j
		if best == cur:
			return cur
		cur = best
		cur_dot = best_dot
	return cur


func active_at(dir: Vector3) -> Variant:
	var cell: int = cell_at_direction(dir)
	if not hide_defects or not g.is_defect(cell):
		return cell
	# ячейка-дефект пунктов не получает: активной становится ближайший к направлению сосед
	var local := orientation.inverse() * dir.normalized()
	var best := cell
	var best_dot := -INF
	for j in g.neighbors[cell]:
		if g.is_defect(j):
			continue
		var d: float = g.centers[j].dot(local)
		if d > best_dot:
			best_dot = d
			best = j
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
	return direction_of(active_at(front)).angle_to(front)


func snap_rotation() -> Quaternion:
	var d := direction_of(active_at(front))
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
