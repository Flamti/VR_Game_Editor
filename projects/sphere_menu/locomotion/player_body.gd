extends CharacterBody3D

## Тело игрока (этап Ф3, решение владельца: сплошное, с тяготением).
##
## `XROrigin3D` — ребёнок этого тела, поэтому движение тела несёт с собой всю XR-сцену. Голова
## внутри origin ходит свободно (комнатный масштаб), а капсула каждый кадр догоняет её по
## горизонтали: так стены не проходятся физическим шагом, а с платформы можно упасть.
##
## Ступени берутся пробной подвижкой вверх (STEP_MAX): `move_and_slide` сам по себе на ступень 18 см
## не поднимает.

## Тяготение и предел шага вверх — форма поведения, не измерения.
const GRAVITY := 9.8
const STEP_MAX := 0.25
const RADIUS := 0.22
## Насколько быстро origin возвращается, когда человек физически зашёл в стену, м/с.
const RETURN_SPEED := 1.2
## Ниже этой отметки человек считается упавшим со сцены и возвращается в стартовую точку. Число
## выбрано заведомо далёким от любой мыслимой геометрии уровня: сессия 17 — с края площадки можно
## уйти в пустоту и падать вечно, остановить нечем.
const FALL_Y := -999.0
## Отметка падения этого уровня: main.gd ставит её от низа геометрии (минус 5 м) при загрузке.
## Константа выше — только на случай, когда уровня нет (стенды).
var fall_y := FALL_Y
## Центр капсулы держится ПОЗАДИ глаз: голова наклонившегося человека уходит вперёд, и капсула,
## поставленная ровно под неё, лезет в стол, упирается и выталкивает человека от препятствия
## (сессия 17). У XR Tools то же самое называется eye_forward_offset.
const EYE_FORWARD_OFFSET := 0.10
## Смещение меньше этого тело не отрабатывает: наклон и дыхание не должны его возить.
const FOLLOW_DEADZONE := 0.08
## Остаток гасится сдвигом origin, только если человек зашёл в геометрию ГЛУБЖЕ этого — то есть
## действительно шагнул в стену, а не наклонился у стола.
const PUSH_MIN := 0.25

## Человек упал со сцены и возвращён в стартовую точку: глубина, с которой вернули.
signal fell(depth: float)

## Маска столкновений, снятая на время перевала (0 — не снята).
var _mask_was := 0
## Идёт перевал через край: телом распоряжается locomotion, физика молчит. Без этого тяготение
## роняет тело, а следование за головой тянет его обратно к стене, и человек оказывается на
## площадке «на коленях» (сессия 20).
var mantling := false

var origin: XROrigin3D
var head: Node3D
## Измеренная высота глаз профиля и текущее приседание, м.
var eye_height := 1.6
var crouch := 0.0
var capsule: CapsuleShape3D
## Узел капсулы держим сами: «нулевой ребёнок» — это XR-начало, а не форма (поймано дымовым прогоном).
var shape_node: CollisionShape3D
## Фальсификатор «nostep»: шаг вверх не пробуется — ступени становятся стеной.
var falsify_no_step := false
## Фальсификатор «ghost»: тело перестаёт быть сплошным — маска столкновений снимается, и стены
## проходятся насквозь (следование за головой при этом остаётся: ломать надо именно сплошность).
var falsify_ghost := false
## Кто может сказать, что человек сейчас ЛЕЗЕТ. Спрашиваем состояние каждый такт, а не копим флаг
## по событиям: флаг, поставленный событием без парного снятия, залипает насовсем (сессия 30).
var climbing: Callable = func() -> bool: return false

## Фальсификатор «spawnblind»: посадка по геометрии не считается — тело ставится ровно в точку из
## данных, как до сессии 32, и висит или тонет вместе с ней.
static var falsify_spawn_blind := false

## Фальсификатор «maskclimb»: страховка возврата маски стоит после раннего выхода лазанья и не
## срабатывает, пока человек лезет, — тело остаётся бесплотным и проваливается сквозь пол.
static var falsify_guard_late := false

## Фальсификатор «carryghost»: сшивка перед перевалом идёт присваиванием, без проверки
## столкновений, — накопленные за подъём метры разом вносят тело внутрь дома.
static var falsify_carry_ghost := false

## Фальсификатор «climbpush»: возврат остатка работает и во время лазанья — origin уезжает от
## стены, кисть уходит от зафиксированного зацепа, лазанье дожимает тело в стену и рвёт хват.
static var falsify_climb_push := false

## Фальсификатор «headchase»: origin не компенсирует шаг тела — возвращает дефект сессии 15, когда
## тело гналось за собственной головой и уносило человека со сцены.
var falsify_head_chase := false
## Фальсификатор «followy» (tests/smoke_menu.gd): origin компенсирует ход тела по всем трём осям,
## как до 2026-09-26 — вертикаль тела при догоне головы уходит в origin, и вид опускается.
var falsify_follow_y := false
## Фальсификатор «nofall»: падение не ловится — человек летит вниз бесконечно (дефект сессии 17).
var falsify_no_fall := false
## Фальсификатор «pushlean»: наклон снова выталкивает — мёртвой зоны и порога проникновения нет.
var falsify_push_lean := false


func setup(p_origin: XROrigin3D, p_head: Node3D) -> void:
	origin = p_origin
	head = p_head
	capsule = CapsuleShape3D.new()
	capsule.radius = RADIUS
	capsule.height = 1.6
	shape_node = CollisionShape3D.new()
	shape_node.shape = capsule
	shape_node.position = Vector3(0, 0.8, 0)
	add_child(shape_node)
	floor_max_angle = deg_to_rad(50.0)
	if falsify_ghost:
		collision_mask = 0


## Снять столкновения на время перевала: капсула иначе цепляется за угол кромки, и человек
## застревает (шаг из схемы Assisted Mantle).
func hold_collisions() -> void:
	if _mask_was == 0:
		_mask_was = collision_mask
		collision_mask = 0


func release_collisions() -> void:
	if _mask_was != 0:
		collision_mask = _mask_was
		_mask_was = 0


## Высота капсулы — от измеренной высоты глаз профиля (world/eye_measure.gd).
func set_eye_height(eye_m: float) -> void:
	eye_height = eye_m
	_apply_height()


func _apply_height() -> void:
	# Присев, человек становится ниже — капсула тоже: иначе присевший упирается макушкой в то, под
	# что заглядывает.
	capsule.height = clampf(eye_height - crouch + 0.12, 0.5, 2.2)
	shape_node.position = Vector3(0, capsule.height * 0.5, 0)


## Присесть кнопкой (просьба владельца, сессия 17: в редакторе надо заглядывать под объекты, а
## физически приседать каждый раз тяжело). Взгляд опускается на `depth`, капсула укорачивается.
func set_crouch(depth: float) -> void:
	depth = clampf(depth, 0.0, maxf(0.0, eye_height - 0.4))
	if is_equal_approx(depth, crouch):
		return
	var was := crouch
	crouch = depth
	_apply_height()
	# Опускаем именно голову: origin — ребёнок тела, поэтому смещение вниз идёт ему.
	if origin != null:
		origin.position.y -= crouch - was


## Перенести человека (телепорт): тело едет так, чтобы ГОЛОВА оказалась над точкой.
## `yaw_deg` — куда смотреть после переноса; NAN — курс не менять.
## Опустить тело на поверхность под точкой и вернуть, куда встали.
##
## Точка старта в данных уровня говорит ГДЕ человек появляется, а не на какой высоте: высоту и
## посадку считает геометрия (решение владельца 2026-09-22). Иначе всякая правка уровня — поднял
## тротуар, положил крыльцо — молча оставляет точку старта висеть или тонуть.
##
## Ищем сверху вниз настоящей капсулой, а не лучом: луч проходит там, где тело не помещается.
## Если под точкой пусто (яма, край сцены), остаёмся на месте и говорим об этом — молчаливое
## «поставили как есть» выглядит как провал сквозь пол.
func drop_to_ground(at: Vector3, up := 2.0, down := 40.0) -> Dictionary:
	if falsify_spawn_blind:
		global_position = at
		return {"ok": false, "pos": at, "why": "посадка не считалась"}
	var from := at + Vector3.UP * up
	global_position = from
	# Вверх тоже пробуем: точка могла оказаться в толще пола или в ступени.
	var stuck := move_and_collide(Vector3.ZERO, true) != null
	if stuck:
		for lift in [0.2, 0.5, 1.0, 2.0]:
			global_position = from + Vector3.UP * lift
			if move_and_collide(Vector3.ZERO, true) == null:
				break
	var hit := move_and_collide(Vector3.DOWN * (down + up))
	if hit == null:
		return {"ok": false, "pos": global_position, "why": "под точкой нет опоры на %.0f м" % down}
	# Дожать до поверхности. Одного `move_and_collide` мало: форму он останавливает с запасом, и
	# ноги повисают на 10–19 см — на глаз это «парит», а на лестнице ещё и ступенью выше.
	# Точка касания даёт саму поверхность; опускаемся к ней и проверяем, что не увязли.
	var surface := (hit.get_position() as Vector3).y
	var want := global_position
	want.y = surface
	var back := global_position
	global_position = want
	if move_and_collide(Vector3.ZERO, true) != null:
		# Увязли — значит запас был не лишним: возвращаемся на то, что дал движок.
		global_position = back
	return {"ok": true, "pos": global_position, "why": "опора на %.2f м" % global_position.y}


func teleport_to(point: Vector3, yaw_deg := NAN) -> void:
	if not is_nan(yaw_deg):
		# Поворот вокруг ГОЛОВЫ, а не начала координат: иначе человека уносит по дуге.
		var pivot := head.global_position
		var turn := deg_to_rad(yaw_deg) - head.global_rotation.y
		var rot := Basis(Vector3.UP, turn)
		var t := global_transform
		t.origin = pivot + rot * (t.origin - pivot)
		t.basis = rot * t.basis
		global_transform = t
	var head_offset := head.global_position - global_position
	global_position = point - Vector3(head_offset.x, 0.0, head_offset.z)
	velocity = Vector3.ZERO


## Сдвинуть мир под ногами (тяга мира): человек едет, тяготение на время отключено.
func shift(delta_pos: Vector3) -> void:
	global_position += delta_pos


## Сдвиг при лазанье — через столкновение. Кинематическое лазанье само по себе проносит капсулу
## сквозь стены (минус подхода, названный владельцем): рука тянет тело внутрь геометрии, и никакая
## физика этому не мешает. `move_and_collide` останавливает тело о поверхность, по которой лезут.
## Перенести накопленное origin-смещение в позицию тела — ПОДВИЖКОЙ, а не присваиванием.
## Возвращает пройденное на самом деле: непройденное обязано остаться в origin, иначе тело и origin
## разъедутся на разную величину и вид дёрнется (сессия 22 — обнуление origin швыряло вбок).
##
## Присваиванием сюда нельзя: к верху стены накапливаются метры, а следом с тела снимают маску
## столкновений — тело стартовало бы перевал изнутри дома.
func carry_shift(delta_pos: Vector3) -> Vector3:
	if delta_pos.length() < 0.0001:
		return Vector3.ZERO
	if falsify_carry_ghost:
		global_position += delta_pos
		return delta_pos
	var before := global_position
	move_and_collide(delta_pos)
	return global_position - before


func climb_shift(delta_pos: Vector3) -> void:
	if delta_pos.length() < 0.0001:
		return
	move_and_collide(delta_pos)


func _physics_process(dt: float) -> void:
	if origin == null or head == null or mantling:
		return
	# Страховка — первой после проверки перевала и до всех прочих ранних выходов. Перевал выходит
	# раньше НАРОЧНО: пока он идёт, маска снята им самим, и вернуть её здесь значило бы зацепить
	# капсулу за кромку посреди переноса. Страховка — для случая, когда перевал кончился, а
	# столкновения остались
	# снятыми — тело проваливается сквозь пол и летит вниз (сессия 24: глаза на −2.44 м). Маска
	# возвращается сама, как только перенос больше не идёт, чем бы он ни кончился.
	#
	# Ровно это и сломалось в сессии 32: ветка лазанья стояла выше и уходила в `return`, унося с
	# собой страховку. Перевал, начатый из лазанья и не дошедший до конца, оставлял маску нулевой —
	# человек проваливался сквозь пол сразу после возврата в стартовую точку, снова и снова.
	if _mask_was != 0 and not falsify_guard_late:
		release_collisions()
	# Пока человек лезет, телом распоряжается лазанье: тяготение и своя скорость ему только мешают
	# — оно роняет висящего, а шаг лазанья поднимает обратно, и кто кого, зависит от порядка узлов.
	if bool(climbing.call()):
		velocity = Vector3.ZERO
		_follow_head(dt)
		return
	# Фальсификатор «maskclimb»: страховка стоит ПОСЛЕ раннего выхода лазанья и потому до него не
	# доходит — ровно так маска и оставалась снятой (сессия 32).
	if _mask_was != 0 and falsify_guard_late:
		release_collisions()
	if global_position.y < fall_y and not falsify_no_fall:
		fell.emit(global_position.y)
		return
	_follow_head(dt)
	velocity.y -= GRAVITY * dt if not is_on_floor() else 0.0
	if is_on_floor() and velocity.y < 0.0:
		velocity.y = 0.0
	var before := global_position
	var want := Vector3(velocity.x, 0.0, velocity.z) * dt
	move_and_slide()
	# Условие шага — «иду, но не продвигаюсь», а НЕ is_on_wall(): капсула упирается в ребро низкой
	# ступени, и движок считает это полом (проверено стендом), поэтому стены он там не видит.
	var got := global_position - before
	got.y = 0.0
	if not falsify_no_step and want.length() > 0.0005 and got.length() < want.length() * 0.3:
		_try_step(want)


## Капсула встаёт под голову по горизонтали. Origin — РЕБЁНОК тела, поэтому шаг тела несёт голову
## с собой: без встречного сдвига origin расстояние до головы не сокращается никогда, и тело едет в
## одну сторону каждый кадр, набирая ход (сессия 15: человека унесло со сцены, остановить нечем).
## Поэтому на каждый пройденный отрезок origin отъезжает ровно на столько же назад — голова остаётся
## там, где человек физически стоит, а под ней оказывается капсула.
##
## Цель — не сами глаза, а точка ПОЗАДИ них (EYE_FORWARD_OFFSET): наклонившийся человек вытягивает
## голову вперёд, и капсула под самыми глазами лезет в стол. Сессия 17: «когда наклоняюсь у стола
## или столба, весь передвигаюсь от препятствия».
##
## Остаток (тело упёрлось) гасится сдвигом origin, только если проникновение глубже PUSH_MIN —
## человек действительно шагнул в стену телом. Наклон до этого порога не доходит, и его больше не
## выталкивает.
## На сколько origin отъезжает за такт, выталкивая человека из геометрии. `left` — остаток, который
## тело пройти не смогло.
##
## Ноль в двух случаях. Первый: проникновение мельче `push_min` — это наклон у стола, а не шаг в
## стену (сессия 17). Второй: человек ЛЕЗЕТ. Тело прижато к стене руками нарочно, а сдвиг origin
## уводит кисть от зацепа, зафиксированного в мире, — лазанье тут же требует сдвинуть тело обратно
## в стену, и на столько же каждый такт заново. Петля дожимает тело в геометрию и за доли секунды
## рвёт хват на ровном месте (сессия 31: «иногда просачиваешься внутрь стены»).
static func push_out(left: Vector3, is_climbing: bool, dt: float, push_min := PUSH_MIN) -> Vector3:
	if is_climbing and not falsify_climb_push:
		return Vector3.ZERO
	if left.length() <= push_min:
		return Vector3.ZERO
	return left.limit_length(RETURN_SPEED * dt)


func _follow_head(dt: float) -> void:
	var back := head.global_basis.z          # +Z у камеры смотрит НАЗАД, за спину
	back.y = 0.0
	if back.length() > 0.01 and not falsify_push_lean:
		back = back.normalized() * EYE_FORWARD_OFFSET
	else:
		back = Vector3.ZERO
	var to_head := head.global_position + back - global_position
	to_head.y = 0.0
	var dead := 0.0 if falsify_push_lean else FOLLOW_DEADZONE
	if to_head.length() < maxf(dead, 0.001):
		return
	var before := global_position
	# Сначала пробно: в препятствие тело не двигается ВОВСЕ. Иначе каждый кадр повторяется одно и то
	# же — шаг вперёд в стену, выталкивание обратно физикой, — и компенсируется только шаг вперёд;
	# разница копится, и наклонившегося человека уносит от препятствия (сессия 17).
	var col := move_and_collide(to_head, true)
	if col == null:
		move_and_collide(to_head)
	else:
		# Вдоль стены идти по-прежнему можно: остаётся касательная часть.
		var slide := to_head.slide(col.get_normal())
		if slide.length() > 0.0005:
			move_and_collide(slide)
	# Пройдено телом — и ровно на это голову унесло вместе с ним; возвращаем её на место.
	# ТОЛЬКО по горизонтали. Вертикаль хода — это то, что под ногами: скруглённое дно капсулы
	# наехало на ребро бордюра, депенетрация. Компенсируй её в origin — и вид опустится на неё, а
	# обратный ход тела (тяготением, в move_and_slide) уже не компенсируется: вид остаётся ниже.
	# Через бордюр 12 см так уходило 0.485 м (стенд «догон головы не двигает вид по вертикали»,
	# 2026-09-26) — «рывок вниз и стоп» при появлении и глаза на −0.8…−1.0 м в сессиях 2026-09-22.
	var moved := global_position - before
	if not falsify_follow_y:
		moved.y = 0.0
	if not falsify_head_chase:
		origin.global_position -= moved
	origin.global_position -= push_out(to_head - moved, bool(climbing.call()), dt,
			0.0 if falsify_push_lean else PUSH_MIN)


## Ступень: подняться на STEP_MAX, шагнуть вперёд, опуститься.
func _try_step(want: Vector3) -> void:
	var up := move_and_collide(Vector3.UP * STEP_MAX, true)
	if up != null:
		return
	global_position += Vector3.UP * STEP_MAX
	var fwd := move_and_collide(want, true)
	if fwd != null:
		global_position -= Vector3.UP * STEP_MAX
		return
	global_position += want
	var down := move_and_collide(Vector3.DOWN * STEP_MAX)
	if down == null:
		global_position -= Vector3.UP * STEP_MAX
