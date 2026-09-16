extends "res://menu/surface.gd"

## Линза: решётка — бесконечная плоскость, видимый участок проецируется на
## сферу азимутальной равнопромежуточной проекцией от «переда» (ADR-0008,
## docs/design/sphere-menu.md §4). Спереди ячейки ровные и равные, к задней
## стороне сжимаются и пропадают; список бесконечен, пятиугольников нет.
##
## Проекция: точка плоскости на расстоянии d от центра смотрит под углом
## θ = d · α от переда, где α — угловой радиус ячейки на единицу радиуса
## ячейки. Поворот шара на угол ячейки сдвигает содержимое ровно на ячейку —
## видимое движение как у настоящего шара.

const Layout := preload("res://menu/layout.gd")

## Угловой радиус ячейки, рад (центр → вершина). Параметр сессии: чем меньше,
## тем больше ячеек видно и тем они мельче.
var alpha := 0.22
## Сдвиг плоскости, единицы радиуса ячейки: центр переда смотрит в точку offset.
var offset := Vector2.ZERO
## Закрутка плоскости вокруг переда, рад.
var twist := 0.0
## Граница видимости по углу от переда: дальше ячейки не рисуются.
var max_theta := PI * 0.85
var _item_count := 0
## ячейка решётки → слот; всё, чего нет, — пусто
var _slots: Dictionary = {}


func _init(p_alpha: float = 0.22) -> void:
	alpha = p_alpha


func assign(item_count: int, with_back: bool = true) -> void:
	_item_count = item_count
	_slots.clear()
	# Раскладка от центра переда: активная ячейка получает первый пункт.
	var origin := Layout.from_plane(offset)
	if with_back:
		_slots[origin + Layout.BACK_CELL] = SLOT_BACK
	var sp: Array[Vector2i] = Layout.spiral(item_count)
	for i in sp.size():
		_slots[origin + sp[i]] = i
	version += 1


## Базис касательной плоскости в переде: right, up_t.
func _basis() -> Array:
	var u := (up - front * up.dot(front))
	if u.length() < 1e-4:
		u = Vector3.RIGHT - front * front.x
	u = u.normalized()
	var right := u.cross(front).normalized()
	return [right, u]


## Базис переда кэшируется на время одного visible_cells(): без кэша он считался
## дважды на каждую ячейку (центр и вершина) — часть скриптов 8.4 мс.
var _basis_cache: Array = []


func _plane_to_dir(p: Vector2) -> Dictionary:
	var v := (p - offset).rotated(twist)
	var theta := v.length() * alpha
	var b := _basis_cache if not _basis_cache.is_empty() else _basis()
	if theta < 1e-6:
		return {"dir": front, "theta": 0.0}
	var t: Vector3 = (b[0] * v.x + b[1] * v.y) / v.length()
	return {"dir": (front * cos(theta) + t * sin(theta)).normalized(), "theta": theta}


func _dir_to_plane(dir: Vector3) -> Vector2:
	var d := dir.normalized()
	var theta := front.angle_to(d)
	if theta < 1e-6:
		return offset
	var b := _basis()
	var t := d - front * d.dot(front)
	var v := Vector2(t.dot(b[0]), t.dot(b[1])).normalized() * (theta / alpha)
	return offset + v.rotated(-twist)


func visible_cells() -> Array:
	_basis_cache = _basis()
	var out: Array = []
	var center := Layout.from_plane(offset)
	var rings := int(ceil(max_theta / (alpha * sqrt(3.0)))) + 1
	for k in rings + 1:
		for c in Layout.ring(k):
			var cell: Vector2i = center + c
			var pr := _plane_to_dir(Layout.to_plane(cell))
			var theta: float = pr["theta"]
			if theta > max_theta:
				continue
			# Азимутальная равнопромежуточная проекция сохраняет расстояние по
			# радиусу и сжимает поперёк в sin θ / θ — это и есть видимое сжатие.
			var squeeze := 1.0 if theta < 1e-4 else sin(theta) / theta
			out.append({"key": cell, "slot": slot_of(cell), "dir": pr["dir"],
					"sides": 6, "scale": clampf(squeeze, 0.0, 1.0), "spin": _spin_of(cell, pr["dir"])})
	_basis_cache = []
	return out


func cell_at_direction(dir: Vector3) -> Variant:
	return Layout.from_plane(_dir_to_plane(dir))


func direction_of(key: Variant) -> Vector3:
	return _plane_to_dir(Layout.to_plane(key))["dir"]


func slot_of(key: Variant) -> int:
	return _slots.get(key, SLOT_EMPTY)


## Поворот шара переводится в сдвиг и закрутку плоскости: содержимое, что было
## в переде, должно оказаться в направлении q·перёд (как у настоящего шара), а
## составляющая вращения вокруг переда закручивает плоскость.
##
## Вывод: точка плоскости P смотрит в направление по v = (P − offset)·rot(twist).
## Нужно, чтобы P0 = offset (перёд) после поворота смотрела в q·перёд. При старых
## offset и twist эту точку даёт P* = _dir_to_plane(q·перёд). С новой закруткой
## twist + Δ условие (P0 − offset')·rot(twist + Δ) = (P* − offset)·rot(twist) даёт
## offset' = offset − (P* − offset)·rot(−Δ). Базис (right, up, front) правый, так что
## поворот вокруг переда на ω — это Vector2.rotated(ω). Разложение на закрутку по
## проекции оси точно для поворота без составляющей вокруг переда и приближённо
## для смешанного — меню подаёт малые покадровые приращения.
func apply_rotation(q: Quaternion) -> void:
	var p_star := _dir_to_plane(q * front)
	var angle := q.get_angle()
	var axis := q.get_axis() if angle > 1e-9 else Vector3.ZERO
	if angle > PI:
		angle -= TAU
	var delta := angle * axis.dot(front)
	offset -= (p_star - offset).rotated(-delta)
	twist += delta
	version += 1


func snap_error() -> float:
	var c := Layout.from_plane(offset)
	return (Layout.to_plane(c) - offset).length() * alpha


## Поворот к детенту: переносит центр ближайшей ячейки в перёд.
func snap_rotation() -> Quaternion:
	var d := direction_of(Layout.from_plane(offset))
	return Quaternion(d, front) if d.angle_to(front) > 1e-6 else Quaternion.IDENTITY


func cell_angle() -> float:
	return alpha


func get_scroll() -> Variant:
	return {"offset": offset, "twist": twist, "slots": _slots.duplicate(), "count": _item_count}


func set_scroll(v: Variant) -> void:
	if v is Dictionary:
		offset = v["offset"]
		twist = v["twist"]
		_slots = v["slots"]
		_item_count = v["count"]
		version += 1


## Поворот шестиугольника вокруг нормали: угол от касательной оси рендера до
## вершины ячейки. Решётка «заострённым верхом» — вершина в (0, 1) плоскости, а
## закрутка вращает решётку на +twist (правый базис right, up, front). Считается
## по самой проекции вершины, а не формулой, — так вблизи задней стороны, где
## проекция поворачивает касательные, вершина остаётся на месте.
func _spin_of(cell: Vector2i, dir: Vector3) -> float:
	var vtx: Vector3 = _plane_to_dir(Layout.to_plane(cell) + Vector2(0.0, 0.3))["dir"]
	var ref := _tangent_ref(dir)
	var p := (vtx - dir * vtx.dot(dir)).normalized()
	return atan2(dir.dot(ref.cross(p)), ref.dot(p))


func _spin(dir: Vector3) -> float:
	return _spin_of(cell_at_direction(dir), dir)


static func _tangent_ref(n: Vector3) -> Vector3:
	var a := Vector3.UP if absf(n.y) < 0.9 else Vector3.RIGHT
	return (a - n * a.dot(n)).normalized()
