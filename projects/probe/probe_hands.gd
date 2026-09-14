extends RefCounted
class_name ProbeHands

## Фаза R v3: жесты ПО СИГНАЛУ, ладонь к лицу / от лица, пороги прогона 13.
##
## ИНТЕРАКТИВНАЯ: жесты делает человек в шлеме по подсказкам. Включается только
## маркером user://hands — иначе любой прогон ждал бы жестов.
##
## Что изменилось после прогона 13 (v2) и почему.
##
## 1. **Эталон — сигнал, а не счёт человека.** Владелец не уверен, сколько
##    щипков сделал (детектор дал 2 и 5 при просьбе «ровно 3»). Теперь надпись
##    командует «ЩИПОК 1/3» в заданный момент, и каждый сигнал — слот. Вердикт:
##    в каждом слоте ровно одно срабатывание нужного класса, вне слотов — ни
##    одного. Пропуск и лишнее срабатывание называются поимённо.
## 2. **Щипки прогоняются несколько раз** — три повтора по три сигнала на руку:
##    запас порога щипка ≈ 5 мм держался на 7 эпизодах.
## 3. **Ладонь к лицу / от лица — по сигналу.** Признак нормали по векторам
##    суставов в v2 не различил позы. Пишутся два кандидата (probe_hand_features.gd),
##    а независимым свидетелем позы левой служит вход FB aim menu_gesture.
## 4. **Надписи на 2 м, закреплены в мире**, появляются перед лицом в начале
##    каждого окна и не вращаются с головой (замечание владельца). Угловой размер
##    прежний.
## 5. **Классификатор на порогах прогона 13**, не на заглушках. Тычок — касание
##    кончиком по геометрии.

const ProbeReport := preload("res://probe_report.gd")
const ProbeHandFeatures := preload("res://probe_hand_features.gd")
const ProbeHandView := preload("res://probe_hand_view.gd")

const HAND_TRACKERS := {"L": "/user/hand_tracker/left", "R": "/user/hand_tracker/right"}
const CONTROLLER_TRACKERS := {"L": "left_hand", "R": "right_hand"}
const AIM_TRACKERS := {"L": "/user/fbhandaim/left", "R": "/user/fbhandaim/right"}
const HAND_PROFILE := "/interaction_profiles/ext/hand_interaction_ext"

## Сырые каналы: имя → [тип трекера, вход левой, вход правой]. Только в TSV и
## в матрицу отчёта, без вердикта: их перекрытие установлено прогоном 12.
const RAW := {
	"hi_pinch": ["controller", "trigger_click", "trigger_click"],
	"hi_grasp": ["controller", "grip_click", "grip_click"],
	"aim_pinch": ["aim", "index_pinch", "index_pinch"],
	"aim_menu": ["aim", "menu_pressed", ""],
	"aim_pose": ["aim", "menu_gesture", "system_gesture"],
}

const LABEL_DISTANCE := 2.0
## Прежний угловой размер при 0.7 м: pixel_size растёт пропорционально дистанции.
const LABEL_PIXEL := 0.0012 / 0.7 * LABEL_DISTANCE

## Окна. kind: free — без сигналов; cued — сигнал жеста class на руке hand,
## reps сигналов по on_s с паузой off_s; palm — чередование «к лицу» и «от лица».
const STEPS := [
	{"id": "rest", "kind": "free", "s": 8.0,
		"text": "Обе руки перед собой.\nЛадони раскрыты, пальцами НЕ шевелить."},
	{"id": "wrist_L", "kind": "free", "s": 10.0,
		"text": "ЛЕВАЯ рука: медленно вращайте кистью.\nПальцы НЕ сжимать."},
	{"id": "palm_L", "kind": "palm", "hand": "L", "reps": 3, "on_s": 2.5, "off_s": 2.5,
		"text": "ЛЕВАЯ рука, пальцы раскрыты, НЕ щипать"},
	{"id": "palm_R", "kind": "palm", "hand": "R", "reps": 3, "on_s": 2.5, "off_s": 2.5,
		"text": "ПРАВАЯ рука, пальцы раскрыты, НЕ щипать"},
	{"id": "pinch_R1", "kind": "cued", "hand": "R", "class": "pinch", "reps": 3, "on_s": 1.5, "off_s": 1.5,
		"text": "ПРАВАЯ, ладонь ОТ лица: щипок по сигналу"},
	{"id": "pinch_L1", "kind": "cued", "hand": "L", "class": "pinch", "reps": 3, "on_s": 1.5, "off_s": 1.5,
		"text": "ЛЕВАЯ, ладонь ОТ лица: щипок по сигналу"},
	{"id": "pinch_R2", "kind": "cued", "hand": "R", "class": "pinch", "reps": 3, "on_s": 1.5, "off_s": 1.5,
		"text": "ПРАВАЯ, ладонь ОТ лица: щипок по сигналу"},
	{"id": "pinch_L2", "kind": "cued", "hand": "L", "class": "pinch", "reps": 3, "on_s": 1.5, "off_s": 1.5,
		"text": "ЛЕВАЯ, ладонь ОТ лица: щипок по сигналу"},
	{"id": "pinch_R3", "kind": "cued", "hand": "R", "class": "pinch", "reps": 3, "on_s": 1.5, "off_s": 1.5,
		"text": "ПРАВАЯ, ладонь ОТ лица: щипок по сигналу"},
	{"id": "pinch_L3", "kind": "cued", "hand": "L", "class": "pinch", "reps": 3, "on_s": 1.5, "off_s": 1.5,
		"text": "ЛЕВАЯ, ладонь ОТ лица: щипок по сигналу"},
	{"id": "fist_L", "kind": "cued", "hand": "L", "class": "fist", "reps": 4, "on_s": 1.5, "off_s": 1.5,
		"text": "ЛЕВАЯ: кулак по сигналу"},
	{"id": "poke_R", "kind": "free", "s": 12.0,
		"text": "ПРАВАЯ: коснитесь синего шарика\nуказательным пальцем РОВНО 3 раза"},
]
const GESTURE_NAMES := {"pinch": "ЩИПОК", "fist": "КУЛАК"}
const PAUSE_S := 3.0
## Срабатывание засчитывается слоту, если начинается не позже on_s + GRACE_S
## от сигнала: реакция человека на команду не мгновенна.
const GRACE_S := 0.6
const POKE_REQUESTED := 3

const POKE_RADIUS := 0.02
const POKE_TOUCH := 0.01
const POKE_RELEASE := 0.03

const TSV_PATH := "user://hands_features.tsv"

var _host: Node
var _origin: Node3D
var _camera: XRCamera3D
var _label: Label3D
var _target: MeshInstance3D
var _view: ProbeHandView = ProbeHandView.new()
var _tsv: FileAccess
var _rows := 0

var _step := ""
var _slot := ""                       # метка слота для TSV: "cue1", "to2", "away3", ""
var _prev_cls: Dictionary = {"L": "", "R": ""}
## Момент, с которого сырой класс отличается от удерживаемого: рука → мкс или -1.
var _release_since: Dictionary = {"L": -1, "R": -1}
## Срабатывания классификатора: [{step, hand, class, t}] — t в секундах от начала окна.
var _events: Array[Dictionary] = []
## Слоты окон: step → [{kind, t0, t1, idx}]
var _slots: Dictionary = {}
## Признаки ладони по слотам: step → "to"|"away" → {"palm_head": [], "palm_y_head": [], "aim_pose": n, "frames": n}
var _palm: Dictionary = {}
var _tracked: Dictionary = {}
var _joints_R: Array[int] = []
var _profiles: Dictionary = {}
var _poke_hits := 0
var _poke_inside := false
var _step_t0 := 0


func expected_checks() -> int:
	# контроль 1; трекинг L/R 2; суставы 1; фальсификаторы 2; ладонь L/R 2;
	# свидетель позы левой 1; щипок R/L 2; кулак 1; касания 1; перекрёстные 1;
	# TSV 1; сетка руки 1
	return 1 + 2 + 1 + 2 + 2 + 1 + 2 + 1 + 1 + 1 + 1 + 1


func setup(host: Node) -> void:
	_host = host
	_camera = host.get_viewport().get_camera_3d() as XRCamera3D
	_origin = host.get_node_or_null("XROrigin3D") as Node3D
	_label = Label3D.new()
	_label.font_size = 40
	_label.pixel_size = LABEL_PIXEL
	_label.outline_size = 12
	_label.modulate = Color(1, 1, 0.6)
	_label.no_depth_test = true
	host.add_child(_label)
	_place_label()
	if _origin != null:
		_view.setup(_origin)


## Надпись закреплена в мире: ставится перед лицом по горизонтальному
## направлению взгляда и дальше не следует за головой.
func _place_label() -> void:
	if _camera == null:
		return
	var cam := _camera.global_transform
	var fwd := -cam.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3.FORWARD
	_label.global_position = cam.origin + fwd * LABEL_DISTANCE
	# Label3D читается со стороны +Z: -Z надписи смотрит от человека.
	_label.look_at(_label.global_position + fwd, Vector3.UP)


func run(r: ProbeReport) -> void:
	r.note("")
	r.note("--- R v3. Руки: жесты по сигналу, ладонь к лицу/от лица (интерактивная, ADR-0008) ---")
	r.note("пороги: кулак вход %.2f / выход %.2f по min-сгибу; щипок вход %.4f / выход %.3f м при не-кулаке; отпускание %.0f мс" % [
			ProbeHandFeatures.FIST_ENTER, ProbeHandFeatures.FIST_EXIT,
			ProbeHandFeatures.PINCH_ENTER, ProbeHandFeatures.PINCH_EXIT, ProbeHandFeatures.RELEASE_S * 1000.0])
	for s in STEPS:
		_slots[s["id"]] = []
		_tracked[s["id"]] = {"L": [0, 0], "R": [0, 0]}

	_open_tsv()
	_label.text = "Фаза R: руки.\nКонтроллеры отложите.\nНачинаем через 5 с"
	await _wait(5.0)

	for s in STEPS:
		_place_label()
		_label.text = "Приготовьтесь…\n\n" + s["text"]
		await _wait(PAUSE_S)
		if s["id"] == "poke_R":
			_place_target()
		_step = s["id"]
		_prev_cls = {"L": "", "R": ""}
		_release_since = {"L": -1, "R": -1}
		_step_t0 = Time.get_ticks_msec()
		match s["kind"]:
			"free":
				await _run_free(s)
			"cued":
				await _run_cued(s)
			"palm":
				await _run_palm(s)
		_step = ""
		_slot = ""
		if _target != null:
			_target.queue_free()
			_target = null

	if _tsv != null:
		_tsv.close()
	_label.text = "Фаза R закончена.\nСпасибо."
	_report(r)
	await _wait(2.0)
	_label.queue_free()


func _elapsed() -> float:
	return float(Time.get_ticks_msec() - _step_t0) / 1000.0


func _run_free(s: Dictionary) -> void:
	while _elapsed() < s["s"]:
		_label.text = "%s\n\nосталось %d с" % [s["text"], ceili(s["s"] - _elapsed())]
		_frame()
		await _host.get_tree().process_frame


func _run_cued(s: Dictionary) -> void:
	var name: String = GESTURE_NAMES[s["class"]]
	for i in s["reps"]:
		var t0 := _elapsed()
		_slots[s["id"]].append({"kind": "cue", "idx": i + 1, "t0": t0, "t1": t0 + s["on_s"] + GRACE_S})
		_slot = "cue%d" % (i + 1)
		while _elapsed() < t0 + s["on_s"]:
			_label.text = "%s\n\n>>> %s %d/%d <<<" % [s["text"], name, i + 1, s["reps"]]
			_frame()
			await _host.get_tree().process_frame
		_slot = ""
		while _elapsed() < t0 + s["on_s"] + s["off_s"]:
			_label.text = "%s\n\nраскрыть руку" % s["text"]
			_frame()
			await _host.get_tree().process_frame


func _run_palm(s: Dictionary) -> void:
	var id: String = s["id"]
	_palm[id] = {}
	for pose in ["to", "away"]:
		_palm[id][pose] = {"palm_head": [], "palm_y_head": [], "aim_pose": 0, "aim_on": [], "frames": 0}
	for i in s["reps"]:
		for pose in ["to", "away"]:
			var t0 := _elapsed()
			var dur: float = s["on_s"] if pose == "to" else s["off_s"]
			_slot = "%s%d" % [pose, i + 1]
			while _elapsed() < t0 + dur:
				# «От лица» уточнено после прогона 14: команду левой рукой в двух из трёх
				# слотов не выполнили — рантайм тоже видел ладонь к лицу.
				var cmd := "ЛАДОНЬ К ЛИЦУ" if pose == "to" else "ЛАДОНЬ ОТ СЕБЯ, ВПЕРЁД"
				_label.text = "%s\n\n>>> %s %d/%d <<<" % [s["text"], cmd, i + 1, s["reps"]]
				var d := _frame()
				# Первые 0.8 с после команды — поворот руки, не поза: не считаются.
				if _elapsed() > t0 + 0.8 and d[s["hand"]].get("tracked", false):
					var acc: Dictionary = _palm[id][pose]
					acc["palm_head"].append(d[s["hand"]]["palm_head"])
					acc["palm_y_head"].append(d[s["hand"]]["palm_y_head"])
					acc["frames"] += 1
					var on := _raw_value(s["hand"], "aim_pose")
					acc["aim_on"].append(on)
					if on:
						acc["aim_pose"] += 1
				await _host.get_tree().process_frame
	_slot = ""


func _wait(seconds: float) -> void:
	var t0 := Time.get_ticks_msec()
	while float(Time.get_ticks_msec() - t0) < seconds * 1000.0:
		_view.update()
		await _host.get_tree().process_frame


## Кадр: признаки обеих рук, классификатор, TSV. Возвращает признаки по рукам.
func _frame() -> Dictionary:
	_view.update()
	var head := _camera.global_position if _camera != null else Vector3.ZERO
	var now := Time.get_unix_time_from_system()
	var out := {}
	for hand in ["L", "R"]:
		var ht := XRServer.get_tracker(HAND_TRACKERS[hand]) as XRHandTracker
		var d := ProbeHandFeatures.sample(ht, hand == "L", head)
		out[hand] = d
		_tracked[_step][hand][1] += 1
		if d["tracked"]:
			_tracked[_step][hand][0] += 1
		if _step == "rest":
			if hand == "R" and ht != null and ht.has_tracking_data:
				var n := 0
				for j in XRHandTracker.HAND_JOINT_MAX:
					if ht.get_hand_joint_flags(j) & XRHandTracker.HAND_JOINT_FLAG_POSITION_TRACKED:
						n += 1
				_joints_R.append(n)
			var ct := XRServer.get_tracker(CONTROLLER_TRACKERS[hand]) as XRPositionalTracker
			if ct != null and ct.profile != "":
				_profiles[hand] = ct.profile
		var cls := _debounced(hand, ProbeHandFeatures.classify(d, _prev_cls[hand]))
		if cls != "" and cls != _prev_cls[hand]:
			_events.append({"step": _step, "hand": hand, "class": cls, "t": _elapsed()})
		_prev_cls[hand] = cls
		_write_row(now, hand, d, cls)
	if _step == "poke_R":
		_sample_poke()
	return out


## Отпускание удерживаемого класса — только если сырой класс отличается дольше
## RELEASE_S (одиночные выбросы расстояния щипка, прогон 14). Вход не задержан:
## задержка входа добавила бы лаг к каждому жесту.
func _debounced(hand: String, raw: String) -> String:
	var held: String = _prev_cls[hand]
	if held == "" or raw == held:
		_release_since[hand] = -1
		return raw
	var now := Time.get_ticks_usec()
	if _release_since[hand] < 0:
		_release_since[hand] = now
	if float(now - _release_since[hand]) / 1000000.0 < ProbeHandFeatures.RELEASE_S:
		return held
	_release_since[hand] = -1
	return raw


func _raw_value(hand: String, ch: String) -> bool:
	var spec: Array = RAW[ch]
	var input: String = spec[1] if hand == "L" else spec[2]
	if input == "":
		return false
	var name: String = CONTROLLER_TRACKERS[hand] if spec[0] == "controller" else AIM_TRACKERS[hand]
	var t := XRServer.get_tracker(name) as XRPositionalTracker
	if t == null:
		return false
	var v = t.get_input(input)
	return (v is bool and v) or (v is float and v > 0.5)


func _open_tsv() -> void:
	_tsv = FileAccess.open(TSV_PATH, FileAccess.WRITE)
	if _tsv == null:
		return
	var cols := PackedStringArray(["unix_t", "window", "slot", "hand", "tracked"])
	for f in ProbeHandFeatures.FINGERS:
		cols.append("curl_" + f)
	cols.append_array(["pinch_m", "palm_head", "palm_y_head", "cls"])
	for ch in RAW:
		cols.append(ch)
	_tsv.store_line("\t".join(cols))


func _write_row(now: float, hand: String, d: Dictionary, cls: String) -> void:
	if _tsv == null:
		return
	var tr: bool = d["tracked"]
	var row := PackedStringArray(["%.4f" % now, _step, _slot, hand, "1" if tr else "0"])
	for f in ProbeHandFeatures.FINGERS:
		row.append("%.4f" % d["curl_" + f] if tr else "")
	for k in ["pinch_m", "palm_head", "palm_y_head"]:
		row.append("%.4f" % d[k] if tr else "")
	row.append(cls)
	for ch in RAW:
		row.append("1" if _raw_value(hand, ch) else "0")
	_tsv.store_line("\t".join(row))
	_rows += 1


func _place_target() -> void:
	if _camera == null:
		return
	var cam := _camera.global_transform
	var fwd := -cam.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3.FORWARD
	var right := fwd.cross(Vector3.UP).normalized()
	_target = MeshInstance3D.new()
	var m := SphereMesh.new()
	m.radius = POKE_RADIUS
	m.height = POKE_RADIUS * 2.0
	_target.mesh = m
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.5, 1.0)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_target.material_override = mat
	_host.add_child(_target)
	_target.global_position = cam.origin + fwd * 0.35 + right * 0.12 + Vector3(0, -0.15, 0)
	_poke_inside = false


func _sample_poke() -> void:
	var ht := XRServer.get_tracker(HAND_TRACKERS["R"]) as XRHandTracker
	if ht == null or _target == null or not ht.has_tracking_data:
		return
	var j := XRHandTracker.HAND_JOINT_INDEX_FINGER_TIP
	if not (ht.get_hand_joint_flags(j) & XRHandTracker.HAND_JOINT_FLAG_POSITION_TRACKED):
		return
	var d := ht.get_hand_joint_transform(j).origin.distance_to(_target.global_position)
	if not _poke_inside and d < POKE_RADIUS + POKE_TOUCH:
		_poke_inside = true
		_poke_hits += 1
	elif _poke_inside and d > POKE_RADIUS + POKE_RELEASE:
		_poke_inside = false


# --- отчёт ------------------------------------------------------------------

func _share(step: String, hand: String) -> float:
	var t: Array = _tracked[step][hand]
	return float(t[0]) / float(t[1]) if t[1] > 0 else 0.0


func _events_of(step: String, hand: String = "", cls: String = "") -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e in _events:
		if e["step"] == step and (hand == "" or e["hand"] == hand) and (cls == "" or e["class"] == cls):
			out.append(e)
	return out


static func _median(a: Array) -> float:
	if a.is_empty():
		return NAN
	var s := a.duplicate()
	s.sort()
	return s[s.size() / 2]


func _report(r: ProbeReport) -> void:
	r.note("  срабатывания классификатора по окнам (рука:класс@секунда):")
	for s in STEPS:
		var parts: PackedStringArray = []
		for e in _events_of(s["id"]):
			parts.append("%s:%s@%.1f" % [e["hand"], e["class"], e["t"]])
		r.note("    %-8s трекинг L %3.0f%% R %3.0f%%  %s" % [s["id"], _share(s["id"], "L") * 100.0,
				_share(s["id"], "R") * 100.0, " ".join(parts) if not parts.is_empty() else "нет"])
	r.note("  касаний шарика %d; строк TSV %d; сетка руки %s" % [_poke_hits, _rows, str(_view.mesh_state)])

	var prof_ok: bool = _profiles.get("L", "") == HAND_PROFILE and _profiles.get("R", "") == HAND_PROFILE
	if prof_ok:
		r.pass_("R контроль: обе руки ведёт профиль %s" % HAND_PROFILE)
	else:
		r.fail("R контроль: профили %s, а не %s" % [str(_profiles), HAND_PROFILE])

	for hand in ["L", "R"]:
		var sh := _share("rest", hand)
		if sh > 0.0:
			r.pass_("R трекинг %s: все 26 суставов в %.0f%% кадров окна покоя" % [hand, sh * 100.0])
		else:
			r.fail("R трекинг %s: ни одного кадра со всеми суставами" % hand)

	if _joints_R.is_empty():
		r.unkn("R суставы правой: кадров с данными нет")
	else:
		var med: int = int(_median(_joints_R))
		if med == XRHandTracker.HAND_JOINT_MAX:
			r.pass_("R суставы правой: медиана %d из %d" % [med, XRHandTracker.HAND_JOINT_MAX])
		else:
			r.fail("R суставы правой: медиана %d из %d" % [med, XRHandTracker.HAND_JOINT_MAX])

	_falsifier(r, "rest", "фальсификатор 1 (покой)")
	_falsifier(r, "wrist_L", "фальсификатор 2 (вращение левой кистью)")

	for s in STEPS:
		if s["kind"] == "palm":
			_palm_check(r, s)
	_palm_witness(r)

	_cued_check(r, "pinch", "R")
	_cued_check(r, "pinch", "L")
	_cued_check(r, "fist", "L")

	if _share("poke_R", "R") == 0.0:
		r.unkn("R касания шарика: правая не отслеживалась")
	elif _poke_hits == POKE_REQUESTED:
		r.pass_("R касания шарика: ровно %d" % _poke_hits)
	else:
		r.fail("R касания шарика: %d вместо %d" % [_poke_hits, POKE_REQUESTED])

	_cross_talk(r)

	if _rows > 0:
		r.pass_("R лог признаков: %d строк" % _rows)
	else:
		r.fail("R лог признаков: пуст")

	var states: Array = _view.mesh_state.values()
	if states.all(func(v): return v == "ready"):
		r.pass_("R сетка руки: модель обеих рук от рантайма")
	elif states.any(func(v): return v == "unavailable" or v == "нет класса"):
		r.fail("R сетка руки: %s" % str(_view.mesh_state))
	else:
		r.unkn("R сетка руки: сигнал готовности не пришёл: %s" % str(_view.mesh_state))


func _falsifier(r: ProbeReport, step: String, label: String) -> void:
	if _share(step, "L") == 0.0 and _share(step, "R") == 0.0:
		r.unkn("R %s: руки не отслеживались" % label)
		return
	var ev := _events_of(step)
	if ev.is_empty():
		r.pass_("R %s: классификатор молчит" % label)
	else:
		r.fail("R %s: %d срабатываний, первое %s:%s" % [label, ev.size(), ev[0]["hand"], ev[0]["class"]])


## Какой кандидат нормали разделяет «к лицу» и «от лица». Разделяет, если
## медианы поз разного знака и отстоят больше чем на 1.0 (из диапазона −1…1).
## Порог 1.0 назначен, а не измерен: он требует лишь, чтобы позы легли по
## разные стороны нуля с запасом, и в выводы о пороге для шара не идёт.
func _palm_check(r: ProbeReport, s: Dictionary) -> void:
	var id: String = s["id"]
	var hand: String = s["hand"]
	if _share(id, hand) == 0.0:
		r.unkn("R ладонь %s: рука не отслеживалась" % hand)
		return
	var parts: PackedStringArray = []
	var winners: PackedStringArray = []
	for k in ["palm_head", "palm_y_head"]:
		var to := _median(_palm[id]["to"][k])
		var away := _median(_palm[id]["away"][k])
		parts.append("%s: к лицу %+.2f, от лица %+.2f" % [k, to, away])
		if not is_nan(to) and not is_nan(away) and signf(to) != signf(away) and absf(to - away) > 1.0:
			winners.append(k)
	if winners.is_empty():
		r.fail("R ладонь %s: ни один кандидат не разделяет позы — %s" % [hand, "; ".join(parts)])
	else:
		r.pass_("R ладонь %s: разделяет %s — %s" % [hand, ", ".join(winners), "; ".join(parts)])


## Согласие признака palm_head с независимым свидетелем рантайма (FB aim
## menu_gesture левой) по КАДРАМ, а не по командам: прогон 14 показал, что
## команду «от лица» человек выполняет не всегда, и сравнение по командам
## обвиняло признак в том, чего не делал человек. Признак согласен со свидетелем,
## если при palm_head < −0.5 свидетель не горит почти никогда, а при > +0.5 —
## горит в большинстве кадров. Пороги ±0.5 и доли назначены: проверяется
## направление связи, а не её сила.
func _palm_witness(r: ProbeReport) -> void:
	if not _palm.has("palm_L"):
		r.unkn("R свидетель позы левой: окна нет")
		return
	var hi := 0
	var hi_on := 0
	var lo := 0
	var lo_on := 0
	for pose in ["to", "away"]:
		var acc: Dictionary = _palm["palm_L"][pose]
		var v: Array = acc["palm_head"]
		var on: Array = acc["aim_on"]
		for i in v.size():
			if v[i] > 0.5:
				hi += 1
				hi_on += int(on[i])
			elif v[i] < -0.5:
				lo += 1
				lo_on += int(on[i])
	if hi == 0 or lo == 0:
		r.unkn("R ладонь L против свидетеля: нет кадров одной из поз (к лицу %d, от себя %d)" % [hi, lo])
		return
	var hi_share := float(hi_on) / hi
	var lo_share := float(lo_on) / lo
	var msg := "menu_gesture горит в %.0f%% кадров palm_head > +0.5 (%d) и в %.0f%% кадров < −0.5 (%d)" % [
			hi_share * 100.0, hi, lo_share * 100.0, lo]
	if hi_share > 0.5 and lo_share < 0.05:
		r.pass_("R ладонь L против свидетеля: %s — признак согласен с рантаймом" % msg)
	else:
		r.fail("R ладонь L против свидетеля: %s — признак расходится с рантаймом" % msg)


## Жесты по сигналу: в каждом слоте ровно одно срабатывание целевого класса
## на целевой руке; срабатывания целевого класса вне слотов — лишние.
func _cued_check(r: ProbeReport, cls: String, hand: String) -> void:
	var hits := 0
	var slots_total := 0
	var misses: PackedStringArray = []
	var doubles: PackedStringArray = []
	var extras: PackedStringArray = []
	var tracked := false
	for s in STEPS:
		if s["kind"] != "cued" or s["class"] != cls or s["hand"] != hand:
			continue
		var id: String = s["id"]
		if _share(id, hand) > 0.0:
			tracked = true
		var ev := _events_of(id, hand, cls)
		var used: Array[bool] = []
		used.resize(ev.size())
		used.fill(false)
		for slot in _slots[id]:
			slots_total += 1
			var n := 0
			for i in ev.size():
				if ev[i]["t"] >= slot["t0"] and ev[i]["t"] <= slot["t1"]:
					n += 1
					used[i] = true
			if n == 1:
				hits += 1
			elif n == 0:
				misses.append("%s#%d" % [id, slot["idx"]])
			else:
				doubles.append("%s#%d×%d" % [id, slot["idx"], n])
		for i in ev.size():
			if not used[i]:
				extras.append("%s@%.1f" % [id, ev[i]["t"]])
	var label := "%s %s по сигналу" % [cls, hand]
	if not tracked:
		r.unkn("R %s: рука не отслеживалась" % label)
	elif hits == slots_total and extras.is_empty():
		r.pass_("R %s: %d из %d сигналов, лишних нет" % [label, hits, slots_total])
	else:
		r.fail("R %s: %d из %d; пропуски %s; двойные %s; лишние %s" % [label, hits, slots_total,
				str(misses), str(doubles), str(extras)])


## Перекрёстные срабатывания: классы на НЕцелевой руке или НЕцелевого класса в
## окнах сигналов, любые срабатывания в окнах ладони и тычка.
func _cross_talk(r: ProbeReport) -> void:
	var bad: PackedStringArray = []
	for s in STEPS:
		var id: String = s["id"]
		if id == "rest" or id == "wrist_L":
			continue
		for e in _events_of(id):
			var ok: bool = s["kind"] == "cued" and e["hand"] == s["hand"] and e["class"] == s["class"]
			if not ok:
				bad.append("%s/%s:%s@%.1f" % [id, e["hand"], e["class"], e["t"]])
	if bad.is_empty():
		r.pass_("R перекрёстные срабатывания: нет")
	else:
		r.fail("R перекрёстные срабатывания: %s" % ", ".join(bad))
