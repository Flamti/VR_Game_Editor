extends RefCounted

## Кто ведёт меню сейчас: контроллеры или руки.
##
## Решение владельца: **контроллер приоритетнее**. Пока контроллер в руке — ведут контроллеры;
## руки берут управление, когда контроллеры отложены.
##
## Основной свидетель — ПРОФИЛЬ взаимодействия трекера (`XRPositionalTracker.profile`). Он один
## говорит, какое устройство рантайм привязал к `/user/hand/<сторона>`, и приходит событием
## (`openxr_api.cpp:3222`, `openxr_interface.cpp:550`). Сам Godot пишет там же
## (`openxr_interface.cpp:578`), что иного последовательного признака активности контроллера нет.
##
## Почему нельзя судить по кнопкам и позам. При профиле рук трекеры `left_hand`/`right_hand`
## ПРОДОЛЖАЮТ отдавать и позы, и `trigger_click`/`grip_click` — но от РУК: щипок приходит как
## нажатый курок (карта действий, профиль `/interaction_profiles/ext/hand_interaction_ext`).
## Прими мы это за контроллер — один щипок навсегда запер бы приложение в режиме контроллеров.
## Поэтому входы контроллера учитываются ТОЛЬКО когда профиль назван и он не рук.
##
## Доставка (поза контроллера, отслеживание рук) — резервный свидетель: он ведёт арбитраж, если
## профиль на Quest окажется неинформативным. Вердикт рантайма о происхождении руки
## (`get_hand_tracking_source`) — третий, справочный: в решение он НЕ входит, только считает
## расхождения. Слову рантайма верить нельзя, пока его не подтвердила доставка (ловушка 14).

signal changed(source: String, why: String)

const CONTROLLERS := "controllers"
const HANDS := "hands"
const HAND_PROFILE := "/interaction_profiles/ext/hand_interaction_ext"
## Профиль, который рантайм ставит, когда не привязано ничего (`openxr_interface.h:64`).
## Переход «контроллер отложен → руки» проходит через него, возможно не один кадр.
const NONE_PROFILE := "/interaction_profiles/none"

## Сколько кандидат «руки» обязан продержаться, прежде чем смена засчитана, мс.
## ПРОВИЗОРНО: подтверждается замером на шлеме (задержка и дребезг смены профиля). Возврат к
## контроллерам выдержки не требует — он приоритетный, и это та же несимметрия, что у отпускания
## жеста: вход мгновенный, выход с задержкой.
const SWITCH_MS := 400

## Настройка «Источник ввода»: auto | controllers | hands.
var mode := "auto"
var current := CONTROLLERS
## Сколько раз вердикт рантайма о происхождении руки разошёлся со сводом свидетелей.
var conflicts := 0
## Фальсификатор «armswitch»: смена засчитывается с первого кадра — дребезг профиля пролезает.
var falsify_no_hold := false
## Фальсификатор «armword»: вердикт рантайма переключает источник сам.
var falsify_trust_word := false

var _cand := ""
var _cand_since := -1
var _last: Dictionary = {}


## w — снимок свидетелей: {"profile": {"left","right"}, "ctrl_pose": {...}, "ctrl_in": {...},
## "hand_ok": {...}, "hand_src": {...}}. Возвращает действующий источник.
func feed(now_ms: int, w: Dictionary) -> String:
	_last = w
	if mode != "auto":
		_cand = ""
		_cand_since = -1
		_switch(mode, "ручной выбор")
		return current

	var votes: Array[String] = []
	var why := ""
	for side in ["left", "right"]:
		var v := _vote(side, w)
		if v != "":
			votes.append(v)
			if why == "":
				why = "профиль %s" % ("левой" if side == "left" else "правой")

	var cand := current
	if votes.has(CONTROLLERS):
		cand = CONTROLLERS
	elif votes.has(HANDS):
		cand = HANDS

	if falsify_trust_word:
		var word := _word(w)
		if word != "":
			cand = word
	elif _word(w) != "" and _word(w) != cand:
		conflicts += 1

	if cand == current:
		_cand = ""
		_cand_since = -1
		return current
	# Контроллер приоритетен — он забирает управление сразу; руки ждут выдержки, иначе пролёт
	# профиля через `/interaction_profiles/none` переключал бы источник туда-обратно.
	if cand == CONTROLLERS or falsify_no_hold:
		_switch(cand, why if why != "" else "доставка")
		return current
	if _cand != cand:
		_cand = cand
		_cand_since = now_ms
	if now_ms - _cand_since >= SWITCH_MS:
		_switch(cand, why if why != "" else "контроллеры отложены")
	return current


## Снимок свидетелей с живых трекеров — единственное место арбитра, где читается XRServer:
## feed() остаётся чистым и проверяется настольно.
static func observe(left: XRController3D, right: XRController3D) -> Dictionary:
	var w := {"profile": {}, "ctrl_pose": {}, "ctrl_in": {}, "hand_ok": {}, "hand_src": {}}
	for side in ["left", "right"]:
		var c: XRController3D = left if side == "left" else right
		var pt := XRServer.get_tracker(c.tracker) as XRPositionalTracker if c != null else null
		w["profile"][side] = pt.profile if pt != null else ""
		w["ctrl_pose"][side] = c != null and c.get_has_tracking_data()
		w["ctrl_in"][side] = c != null and (c.is_button_pressed("trigger_click") or c.is_button_pressed("grip_click")
				or c.is_button_pressed("ax_button") or c.is_button_pressed("by_button")
				or c.get_vector2("primary").length() > 0.2)
		var ht := XRServer.get_tracker("/user/hand_tracker/" + side) as XRHandTracker
		w["hand_ok"][side] = ht != null and ht.has_tracking_data
		w["hand_src"][side] = ht.hand_tracking_source if ht != null else XRHandTracker.HAND_TRACKING_SOURCE_UNKNOWN
	return w


func source() -> String:
	return current


## Последний снимок свидетелей — в журнал, чтобы арбитраж можно было пересчитать задним числом.
func witnesses() -> Dictionary:
	var d := _last.duplicate(true)
	d["conflicts"] = conflicts
	d["mode"] = mode
	return d


func _vote(side: String, w: Dictionary) -> String:
	var profile: String = str(w.get("profile", {}).get(side, ""))
	var pose: bool = bool(w.get("ctrl_pose", {}).get(side, false))
	var input: bool = bool(w.get("ctrl_in", {}).get(side, false))
	var hand_ok: bool = bool(w.get("hand_ok", {}).get(side, false))
	if profile == HAND_PROFILE:
		return HANDS
	if profile != "" and profile != NONE_PROFILE:
		# Профиль назван и он не рук — здесь кнопкам верить можно: их некому подделать.
		return CONTROLLERS if pose or input else ""
	# Профиль молчит: судит только доставка. Входы в этой ветке не в счёт — неизвестно, чьи они.
	if pose:
		return CONTROLLERS
	return HANDS if hand_ok else ""


## Вердикт рантайма о происхождении руки, если он вообще информативен.
func _word(w: Dictionary) -> String:
	var src: Dictionary = w.get("hand_src", {})
	for side in ["left", "right"]:
		var v: int = int(src.get(side, XRHandTracker.HAND_TRACKING_SOURCE_UNKNOWN))
		if v == XRHandTracker.HAND_TRACKING_SOURCE_UNOBSTRUCTED:
			return HANDS
		if v == XRHandTracker.HAND_TRACKING_SOURCE_CONTROLLER:
			return CONTROLLERS
	return ""


func _switch(src: String, why: String) -> void:
	_cand = ""
	_cand_since = -1
	if src == current:
		return
	current = src
	changed.emit(src, why)
