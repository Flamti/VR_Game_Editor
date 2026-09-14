extends RefCounted
class_name ProbeHandFeatures

## Признаки жестов по суставам руки и предварительный классификатор.
##
## Зачем. Прогон 12 показал, что сырые каналы рантайма перекрываются: щипок и
## хват профиля XR_EXT_hand_interaction неразличимы, тычок профиль считает и
## щипком, и хватом, а жест меню — всегда ещё и щипок. Распознавать кулак,
## щипок и тычок для шар-меню придётся по суставам (ADR-0008).
##
## Пороги выведены из распределений признаков прогона 13 (docs/hardware-profile.md,
## раздел «Руки»), а не назначены: сначала лог, потом число (PRACTICES §3.1).
## Одна сессия одного человека — это их граница применимости.
##
## Только статические функции над XRHandTracker: файл переносится в прототип
## шара без правок.

const FINGERS := {
	"index": [XRHandTracker.HAND_JOINT_INDEX_FINGER_PHALANX_PROXIMAL,
			XRHandTracker.HAND_JOINT_INDEX_FINGER_PHALANX_INTERMEDIATE,
			XRHandTracker.HAND_JOINT_INDEX_FINGER_PHALANX_DISTAL,
			XRHandTracker.HAND_JOINT_INDEX_FINGER_TIP],
	"middle": [XRHandTracker.HAND_JOINT_MIDDLE_FINGER_PHALANX_PROXIMAL,
			XRHandTracker.HAND_JOINT_MIDDLE_FINGER_PHALANX_INTERMEDIATE,
			XRHandTracker.HAND_JOINT_MIDDLE_FINGER_PHALANX_DISTAL,
			XRHandTracker.HAND_JOINT_MIDDLE_FINGER_TIP],
	"ring": [XRHandTracker.HAND_JOINT_RING_FINGER_PHALANX_PROXIMAL,
			XRHandTracker.HAND_JOINT_RING_FINGER_PHALANX_INTERMEDIATE,
			XRHandTracker.HAND_JOINT_RING_FINGER_PHALANX_DISTAL,
			XRHandTracker.HAND_JOINT_RING_FINGER_TIP],
	"pinky": [XRHandTracker.HAND_JOINT_PINKY_FINGER_PHALANX_PROXIMAL,
			XRHandTracker.HAND_JOINT_PINKY_FINGER_PHALANX_INTERMEDIATE,
			XRHandTracker.HAND_JOINT_PINKY_FINGER_PHALANX_DISTAL,
			XRHandTracker.HAND_JOINT_PINKY_FINGER_TIP],
}

## Кулак: минимальный сгиб четырёх пальцев. Прогон 13: покой и вращение кистью
## ≤ 0.02, сжатие 0.61–0.66; любой вход от 0.20 до 0.55 давал ровно 3 эпизода в
## окне кулака и 0 в прочих. Взята середина; выход ниже входа — гистерезис.
const FIST_ENTER := 0.40
const FIST_EXIT := 0.24
## Щипок: расстояние кончиков большого и указательного ПРИ НЕ-КУЛАКЕ.
## Прогон 13: настоящие щипки 5.7–14.5 мм, ближайший ложный — 19.2 мм в окне
## тычка. Запас ≈ 5 мм по 7 эпизодам: узко, и прогон 14 его перепроверяет.
const PINCH_ENTER := 0.0165
const PINCH_EXIT := 0.030
## Отпускание класса засчитывается, только если держится дольше этого. Прогон 14:
## внутри щипка расстояние кончиков на ОДИН кадр прыгает до 31–35 мм (21 → 35 →
## 9 мм) и пересекает выход — три из четырёх двойных срабатываний правой были
## такими выбросами. Офлайн по логам прогонов 13 и 14: задержка в 3 кадра на
## 90 Гц убирает все три и не меняет ни одного другого срабатывания. Задано
## временем, чтобы не зависеть от частоты кадров.
const RELEASE_S := 0.035

## Тычка здесь нет намеренно: поза тычка по суставам не отделилась (1 эпизод из
## 3), а касание кончиком по геометрии дало 3 из 3 — тычок распознаётся касанием.
const CLASSES := ["fist", "pinch"]


static func _pos(ht: XRHandTracker, j: int) -> Vector3:
	return ht.get_hand_joint_transform(j).origin


## Все ли суставы, нужные признакам, отслеживаются в этом кадре. Признаки по
## суставам «valid, но не tracked» — это догадка рантайма, а не рука.
static func all_tracked(ht: XRHandTracker) -> bool:
	if ht == null or not ht.has_tracking_data:
		return false
	for j in XRHandTracker.HAND_JOINT_MAX:
		if not (ht.get_hand_joint_flags(j) & XRHandTracker.HAND_JOINT_FLAG_POSITION_TRACKED):
			return false
	return true


## Сгиб пальца: 1 − (расстояние от основания до кончика) / (длина цепочки).
## Прямой палец даёт ~0, согнутый — больше. Длина цепочки считается в том же
## кадре, поэтому признак не зависит от размера руки и от позы ладони.
static func curl(ht: XRHandTracker, finger: String) -> float:
	var js: Array = FINGERS[finger]
	var chain := 0.0
	for i in range(js.size() - 1):
		chain += _pos(ht, js[i]).distance_to(_pos(ht, js[i + 1]))
	if chain <= 0.0:
		return NAN
	return 1.0 - _pos(ht, js[0]).distance_to(_pos(ht, js[js.size() - 1])) / chain


## Расстояние кончик большого — кончик указательного, метры.
static func pinch_distance(ht: XRHandTracker) -> float:
	return _pos(ht, XRHandTracker.HAND_JOINT_THUMB_TIP).distance_to(
			_pos(ht, XRHandTracker.HAND_JOINT_INDEX_FINGER_TIP))


## Косинус между нормалью ладони и направлением от ладони на голову.
## Знак нормали для левой и правой руки — предположение: сверяется по окну
## покоя в логе (руки перед собой, ладони от лица → ожидается отрицательный).
static func palm_to_head(ht: XRHandTracker, is_left: bool, head: Vector3) -> float:
	var across := _pos(ht, XRHandTracker.HAND_JOINT_INDEX_FINGER_PHALANX_PROXIMAL) \
			- _pos(ht, XRHandTracker.HAND_JOINT_PINKY_FINGER_PHALANX_PROXIMAL)
	var along := _pos(ht, XRHandTracker.HAND_JOINT_MIDDLE_FINGER_PHALANX_PROXIMAL) \
			- _pos(ht, XRHandTracker.HAND_JOINT_WRIST)
	var n := across.cross(along)
	if n.length() < 1e-6:
		return NAN
	n = n.normalized()
	if is_left:
		n = -n
	var palm := _pos(ht, XRHandTracker.HAND_JOINT_PALM)
	var to_head := head - palm
	if to_head.length() < 1e-6:
		return NAN
	return n.dot(to_head.normalized())


## Второй кандидат нормали — ось Y сустава ладони, как её отдаёт рантайм
## (Godot передаёт позу без преобразований, openxr_hand_tracking_extension.cpp:296).
## ОТВЕРГНУТ прогоном 14: за 11 тысяч кадров ни разу не превысил +0.5 — это не
## нормаль ладони. Оставлен в логе как контроль.
##
## Рабочий признак — palm_to_head выше. Прогон 14: при palm_head < −0.5 флаг
## рантайма menu_gesture (ладонь к лицу) не загорелся ни в одном из 4793 кадров,
## при > +0.5 горит в 74%. В прогоне 13 он лишь казался неисправным: в
## естественной позе щипка ладонь смотрит к лицу, что подтверждал и рантайм.
static func palm_y_to_head(ht: XRHandTracker, head: Vector3) -> float:
	var t := ht.get_hand_joint_transform(XRHandTracker.HAND_JOINT_PALM)
	var to_head := head - t.origin
	if to_head.length() < 1e-6:
		return NAN
	return t.basis.y.normalized().dot(to_head.normalized())


static func min_curl(d: Dictionary) -> float:
	return minf(minf(d["curl_index"], d["curl_middle"]), minf(d["curl_ring"], d["curl_pinky"]))


## Все признаки кадра одним словарём — ровно то, что пишется в TSV.
static func sample(ht: XRHandTracker, is_left: bool, head: Vector3) -> Dictionary:
	var d := {"tracked": all_tracked(ht)}
	if not d["tracked"]:
		return d
	for f in FINGERS:
		d["curl_" + f] = curl(ht, f)
	d["pinch_m"] = pinch_distance(ht)
	d["palm_head"] = palm_to_head(ht, is_left, head)
	d["palm_y_head"] = palm_y_to_head(ht, head)
	return d


## Класс кадра с гистерезисом: prev — класс прошлого кадра той же руки.
## Кулак проверяется первым: в кулаке большой и указательный тоже близко
## (15.7–18.8 мм в прогоне 13), и без этого порядка кулак считался бы щипком.
static func classify(d: Dictionary, prev: String) -> String:
	if not d.get("tracked", false):
		return ""
	var mc := min_curl(d)
	if mc > (FIST_EXIT if prev == "fist" else FIST_ENTER):
		return "fist"
	if d["pinch_m"] < (PINCH_EXIT if prev == "pinch" else PINCH_ENTER):
		return "pinch"
	return ""
