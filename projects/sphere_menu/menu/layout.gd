extends RefCounted

## Раскладка пунктов на шестиугольной решётке (слой 3, docs/design/sphere-menu.md §3).
##
## Осевые координаты (q, r), «заострённый верх» — по Red Blob Games
## (redblobgames.com/grids/hexagons). Пункты кладутся спиралью от центра:
## первые пункты папки ближе всего к активной ячейке. Служебная «назад» —
## фиксированный сосед центра, и спираль её пропускает.

## Шесть направлений осевых координат, по часовой от «востока».
const DIRS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1),
	Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1),
]
## «Назад» — западный сосед центра: слева от активной, куда тянется рука к
## шару в левой руке. Позиция фиксирована, чтобы искать её не приходилось.
const BACK_CELL := Vector2i(-1, 0)


static func distance(a: Vector2i, b: Vector2i) -> int:
	var d := a - b
	return (absi(d.x) + absi(d.x + d.y) + absi(d.y)) / 2


static func neighbors(c: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for d in DIRS:
		out.append(c + d)
	return out


## Кольцо радиуса k вокруг центра, по кругу.
static func ring(k: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if k == 0:
		out.append(Vector2i.ZERO)
		return out
	var c: Vector2i = DIRS[4] * k
	for side in 6:
		for _step in k:
			out.append(c)
			c += DIRS[side]
	return out


## Ячейки для n пунктов: спираль от центра, без служебной «назад».
static func spiral(n: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var k := 0
	while out.size() < n:
		for c in ring(k):
			if c == BACK_CELL:
				continue
			out.append(c)
			if out.size() == n:
				break
		k += 1
	return out


## Центр ячейки на плоскости, в единицах радиуса ячейки (центр → вершина).
static func to_plane(c: Vector2i) -> Vector2:
	return Vector2(sqrt(3.0) * (c.x + c.y * 0.5), 1.5 * c.y)


## Ближайшая ячейка к точке плоскости — через кубическое округление.
static func from_plane(p: Vector2) -> Vector2i:
	var q := (sqrt(3.0) / 3.0 * p.x - 1.0 / 3.0 * p.y)
	var r := (2.0 / 3.0 * p.y)
	var s := -q - r
	var rq := roundf(q)
	var rr := roundf(r)
	var rs := roundf(s)
	var dq := absf(rq - q)
	var dr := absf(rr - r)
	var ds := absf(rs - s)
	if dq > dr and dq > ds:
		rq = -rr - rs
	elif dr > ds:
		rr = -rq - rs
	return Vector2i(int(rq), int(rr))
