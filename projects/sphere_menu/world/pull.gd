extends RefCounted

## Дистанционный призыв предмета — «гравиперчатки» (просьба владельца после сессии 17, референс
## Half-Life: Alyx).
##
## Три шага, как у Valve: навести ладонь на предмет — он подсвечивается; зажать грип — «зацеплено»;
## **рывок кистью к себе** — предмет летит в руку по дуге. Valve в интервью объясняли, что одна и та
## же кнопка для ближнего взятия и для призыва оказалась понятнее всего, поэтому кнопка та же.
##
## Настройка «Призыв предмета»: `gesture` — жестом (умолчание), `instant` — сразу по грипу,
## `off` — выключено.
##
## Здесь только математика: выбор цели конусом, распознавание рывка, точка полёта. Кто цель и куда
## она летит — решает вызывающий; так всё проверяется настольно, без сцены.

## Дальность призыва, м.
const RANGE_M := 6.0
## Полуугол конуса наведения, градусы. Уже — не поймать мелкий куб на шести метрах, шире —
## притягивается не то, на что смотрели.
const CONE_DEG := 8.0
## Рывок: рука должна двигаться К СЕБЕ быстрее этого, м/с.
const FLICK_SPEED := 0.8
## Окно, по которому считается скорость кисти, с.
const FLICK_WINDOW_S := 0.15
## Сколько летит предмет, с.
const FLY_S := 0.4
## Насколько высоко дуга поднимается над прямой, доля расстояния.
const ARC_RISE := 0.25
## Насколько провисает нить наведения, доля расстояния.
const THREAD_SAG := 0.06
## Сколько предмет ждёт у ладони после прилёта, с. Сессия 20: жестом ловилось 3 раза из 10, «сразу»
## — 8 из 11. Разница не в полёте, а в кисти: после рывка человек разжимает грип, и в момент
## прилёта держать нечем. Предмет ждёт этот срок и ловится, если грип нажат хоть когда-то за него.
const CATCH_WINDOW_S := 0.5

## Фальсификатор «pullwide»: конус раскрывается до 90° — притягивается что попало, а не то, на что
## навели.
static var falsify_wide := false
## Фальсификатор «pullflick»: рывком считается любое движение кисти, даже медленное.
static var falsify_any_flick := false


## Кто под ладонью: номер ближайшего к оси предмета в конусе и в пределах дальности, или −1.
## Берёт ПОЗИЦИИ, а не узлы: так выбор цели — чистая математика и проверяется настольно (мировые
## координаты узла вне готового дерева сцены — нули, ловушка 36).
static func target_index(positions: Array, from: Vector3, dir: Vector3) -> int:
	if dir.length() < 0.001:
		return -1
	var axis := dir.normalized()
	var best := deg_to_rad(90.0 if falsify_wide else CONE_DEG)
	var found := -1
	for i in positions.size():
		var to_it: Vector3 = (positions[i] as Vector3) - from
		var dist := to_it.length()
		if dist < 0.001 or dist > RANGE_M:
			continue
		var angle := axis.angle_to(to_it.normalized())
		if angle < best:
			best = angle
			found = i
	return found


## То же для узлов сцены (группа «grab»): обёртка над `target_index`.
static func target(items: Array, from: Vector3, dir: Vector3) -> Node3D:
	var live: Array = []
	var positions: Array = []
	for it in items:
		var node := it as Node3D
		if node == null or not is_instance_valid(node):
			continue
		live.append(node)
		positions.append(node.global_position)
	var i := target_index(positions, from, dir)
	return null if i < 0 else live[i] as Node3D


## Рывок кистью «к себе»: скорость вдоль оси ладони, направленная НА человека, выше порога.
## `hand_velocity` — скорость кисти в мире, `to_head` — направление от кисти к голове.
static func is_flick(hand_velocity: Vector3, to_head: Vector3) -> bool:
	if to_head.length() < 0.001:
		return false
	if falsify_any_flick:
		return hand_velocity.length() > 0.01
	return hand_velocity.dot(to_head.normalized()) > FLICK_SPEED


## Точки нити от ладони к предмету: провисающая линия, а не прямая — прямую глаз читает как
## случайную, провисание сразу говорит «связь, за которую тянут» (сессия 20: владелец просил
## «выделение предмета и нить-линию к контроллеру/руке»).
static func thread(from: Vector3, to: Vector3, points := 12) -> PackedVector3Array:
	var out := PackedVector3Array()
	var sag := from.distance_to(to) * THREAD_SAG
	for i in points:
		var k := float(i) / float(points - 1)
		var p := from.lerp(to, k)
		p.y -= sag * (4.0 * k * (1.0 - k))
		out.append(p)
	return out


## Точка предмета в полёте: дуга от `from` к текущей ладони `to`, t от 0 до 1.
## Дуга, а не прямая: по прямой предмет «просачивается» сквозь пол и стол, а поднятая траектория
## читается глазом как бросок.
static func fly_point(from: Vector3, to: Vector3, t: float) -> Vector3:
	var k := clampf(t, 0.0, 1.0)
	var p := from.lerp(to, k)
	# Парабола: ноль на концах, максимум в середине.
	p.y += from.distance_to(to) * ARC_RISE * (4.0 * k * (1.0 - k))
	return p
