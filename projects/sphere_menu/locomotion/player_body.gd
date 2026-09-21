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
## Фальсификатор «headchase»: origin не компенсирует шаг тела — возвращает дефект сессии 15, когда
## тело гналось за собственной головой и уносило человека со сцены.
var falsify_head_chase := false
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
func climb_shift(delta_pos: Vector3) -> void:
	if delta_pos.length() < 0.0001:
		return
	move_and_collide(delta_pos)


func _physics_process(dt: float) -> void:
	if origin == null or head == null or mantling:
		return
	# Страховка: перевал кончился, а столкновения остались снятыми — тело проваливается сквозь пол
	# и летит вниз (сессия 24: глаза оказались на −2.44 м). Маска возвращается сама, как только
	# перенос больше не идёт, чем бы он ни кончился.
	if _mask_was != 0:
		release_collisions()
	if global_position.y < FALL_Y and not falsify_no_fall:
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
	var moved := global_position - before
	if not falsify_head_chase:
		origin.global_position -= moved
	var left := to_head - moved
	if left.length() > (0.0 if falsify_push_lean else PUSH_MIN):
		origin.global_position -= left.limit_length(RETURN_SPEED * dt)


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
