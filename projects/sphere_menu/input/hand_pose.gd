extends RefCounted

## Геометрия руки для меню: кончик пальца, нормаль ладони, поза шара, луч ладони.
##
## Только статические функции над `XRHandTracker` — как `probe_hand_features.gd`, и по той же
## причине: так механика проверяется настольно синтетическим трекером, без узлов и без шлема.
##
## Конвенцию базиса суставов OpenXR здесь НЕ используем: она в проекте нигде не проверена, а
## отвергнутый признак `palm_y_to_head` (ось Y сустава ладони) прогон 14 уже поймал на том, что
## осям сустава верить нельзя. Все направления строятся из ПОЛОЖЕНИЙ суставов — той же формулой,
## что сверена с рантаймом в прогоне 14 (`probe_hand_features.palm_to_head`).

const Features := preload("res://probe_hand_features.gd")

## Фальсификатор «handmirror»: знак нормали ладони не по руке — шар встаёт под ладонь.
static var falsify_mirror := false


## Положение сустава, если оно отслежено; иначе null — кадр пропускается целиком.
static func joint(ht: XRHandTracker, j: int) -> Variant:
	if ht == null or not ht.has_tracking_data:
		return null
	if not (ht.get_hand_joint_flags(j) & XRHandTracker.HAND_JOINT_FLAG_POSITION_TRACKED):
		return null
	return ht.get_hand_joint_transform(j).origin


## Кончик указательного — им выбирают ячейку (ADR-0008 п. 4).
static func tip(ht: XRHandTracker) -> Variant:
	return joint(ht, XRHandTracker.HAND_JOINT_INDEX_FINGER_TIP)


## Нормаль ладони наружу от неё. Формула и знак для левой руки — из `palm_to_head`,
## проверенного свидетелем рантайма: при значении < −0.5 флаг menu_gesture не загорелся ни в
## одном из 4793 кадров прогона 14.
static func palm_normal(ht: XRHandTracker, is_left: bool) -> Variant:
	var index: Variant = joint(ht, XRHandTracker.HAND_JOINT_INDEX_FINGER_PHALANX_PROXIMAL)
	var pinky: Variant = joint(ht, XRHandTracker.HAND_JOINT_PINKY_FINGER_PHALANX_PROXIMAL)
	var middle: Variant = joint(ht, XRHandTracker.HAND_JOINT_MIDDLE_FINGER_PHALANX_PROXIMAL)
	var wrist: Variant = joint(ht, XRHandTracker.HAND_JOINT_WRIST)
	if index == null or pinky == null or middle == null or wrist == null:
		return null
	var n: Vector3 = (index - pinky).cross(middle - wrist)
	if n.length() < 1e-6:
		return null
	n = n.normalized()
	return -n if is_left != falsify_mirror else n


## Поза для шара: начало — ладонь, «вперёд» (−Z) вдоль пальцев, «вверх» (+Y) — нормаль ладони.
## Запасной путь к grip-позе трекера: если рантайм отдаёт её от руки, узел сцены уже годится,
## и эта функция не нужна. Что из двух работает на Quest — решает сессия, не догадка.
static func pose(ht: XRHandTracker, is_left: bool) -> Variant:
	var palm: Variant = joint(ht, XRHandTracker.HAND_JOINT_PALM)
	var wrist: Variant = joint(ht, XRHandTracker.HAND_JOINT_WRIST)
	var middle: Variant = joint(ht, XRHandTracker.HAND_JOINT_MIDDLE_FINGER_PHALANX_PROXIMAL)
	var up: Variant = palm_normal(ht, is_left)
	if palm == null or wrist == null or middle == null or up == null:
		return null
	var fwd: Vector3 = (middle - wrist)
	if fwd.length() < 1e-6:
		return null
	fwd = fwd.normalized()
	# Ортогонализация: нормаль ладони и направление пальцев перпендикулярны лишь примерно.
	var side: Vector3 = fwd.cross(up)
	if side.length() < 1e-6:
		return null
	side = side.normalized()
	var up_o: Vector3 = side.cross(fwd).normalized()
	return Transform3D(Basis(side, up_o, -fwd), palm)


## Луч ладони для панели: из ладони вдоль оси кисти. Курка у руки нет, поэтому лучом по шару не
## целятся вовсе — он служит только панели, а по шару работает касание.
static func ray(ht: XRHandTracker, _is_left: bool) -> Array:
	var palm: Variant = joint(ht, XRHandTracker.HAND_JOINT_PALM)
	var wrist: Variant = joint(ht, XRHandTracker.HAND_JOINT_WRIST)
	if palm == null or wrist == null:
		return []
	var dir: Vector3 = (palm - wrist)
	if dir.length() < 1e-6:
		return []
	return [palm, dir.normalized()]


## Все ли 26 суставов отслежены — тот же вопрос, что задаёт прибор перед классификацией.
static func all_tracked(ht: XRHandTracker) -> bool:
	return ht != null and Features.all_tracked(ht)
