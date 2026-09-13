extends RefCounted
class_name ProbeLayers

## Фаза L: ручки рендера и поверхности меню. Вход в открытые пункты ADR-0003.
##
## Три вопроса, на которые рендер-путь не может ответить без числа:
##
##   L1. Сколько стоит MSAA. Godot НЕ делает MSAA-вложения ленивыми
##       (render_scene_buffers_rd.cpp:188 — TODO), значит довод исследования
##       «на тайловом GPU MSAA почти бесплатен» к нашей сборке не применим.
##   L2. Сколько экономит фиксированная фовеация vrs_mode = VRS_XR. На Mobile
##       это единственная ручка фовеации (ловушка 17).
##   L3. Сколько стоят кандидаты поверхности меню на 42 ячейки (40+ по
##       критерию этапа 1): отдельные меши, MultiMesh, MultiMesh с атласом
##       подписей в SubViewport, cylinder-слой композиции.
##
## Вся фаза идёт на ЦЕЛЕВОЙ частоте (ADR-0007): решения принимаются для 90 Гц.
##
## Порядок точек чередующийся — прямой, затем обратный. Канарейка показала
## дрейф +13% на 90 Гц за сто секунд, и монотонный порядок приписал бы дрейф
## последней ручке. Разброс между повторами одной точки служит порогом
## значимости: эффект настоящий, если вдвое больше разброса (как в фазе M).
##
## Ловушка слоя. OpenXRCompositionLayer молча создаёт обычный MeshInstance3D в
## мировом буфере, если тип слоя не поддержан (_should_use_fallback_node(),
## openxr_composition_layer.cpp:206). Точка «слой» тогда мерила бы меш. Гейты:
## is_natively_supported() и нулевой прирост отрисовок главного вьюпорта.
##
## Предел свидетельства слоя. Работу композитора приложение не видит: время
## GPU вьюпорта её не содержит. Единственный свидетель — доставка кадров.

const ProbeReport := preload("res://probe_report.gd")
const ProbeStats := preload("res://probe_stats.gd")
const ProbeBudget := preload("res://probe_budget.gd")
const ProbeWindow := preload("res://probe_window.gd")
const ProbeState := preload("res://probe_state.gd")

const REPEATS := 2

## Сцена «геометрия»: крошечные квады с уникальным материалом, как в фазе M.
## Пикселей почти нет — всё, что меняется здесь, меняется не в затенении.
const GEOMETRY_N := 400
## Сцена «пиксели»: слои во весь экран без теста глубины, как в фазе P.
const FILL_LAYERS := 8
const FILL_SIZE := 4.0
const SCENES := ["геометрия", "пиксели"]

const MSAA_MODES := [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X]
const MSAA_NAMES := {Viewport.MSAA_DISABLED: "off", Viewport.MSAA_2X: "2x", Viewport.MSAA_4X: "4x"}
const VRS_MODES := [Viewport.VRS_DISABLED, Viewport.VRS_XR]
const VRS_NAMES := {Viewport.VRS_DISABLED: "DISABLED", Viewport.VRS_XR: "VRS_XR"}

## Шар меню.
const CELLS := 42
const MENU_RADIUS := 0.15
const MENU_POS := Vector3(0, 0, -0.6)
const ATLAS_PX := 512
const ATLAS_COLS := 7

## Кандидаты поверхности и сколько гейтов у каждого. Пол выводится отсюда же.
##   пусто:    кадр пуст
##   меши:     прирост отрисовок = CELLS
##   мультимеш: прирост = 1
##   атлас:    прирост = 2 (мультимеш + сфера), SubViewport рисует
##   слой:     слой нативный, прирост = 0, SubViewport рисует
const SURFACES := ["пусто", "меши", "мультимеш", "атлас", "слой"]
const SURFACE_GATES := {"пусто": 1, "меши": 1, "мультимеш": 1, "атлас": 2, "слой": 3}

var _host: Node
var _parent: Node
var _viewport: Viewport
var _vp: RID
var _container: Node3D
var _budget := NAN
var _hz := 0.0

## Итоги для отчёта: имя → {"gpu_ms": float, "spread": float, "significant": bool}
var results: Dictionary = {}


func expected_checks() -> int:
	# L1: на каждую сцену гейт состояния + эффект каждого режима кроме базы;
	#     плюс фальсификатор.
	var n := SCENES.size() * (1 + MSAA_MODES.size() - 1) + 1
	# L2: гейт состояния, эффект на каждой сцене, контрольный случай.
	n += 1 + SCENES.size() + 1
	# L3: гейты кандидатов, цена каждого кандидата кроме пустого, доставка слоя.
	for s in SURFACES:
		n += SURFACE_GATES[s]
	n += SURFACES.size() - 1 + 1
	return n


## Контейнер крепится к КАМЕРЕ, а не к миру.
##
## Обкатка 2026-09-13 показала, почему: шлем лежал, и поза головы уводила шар
## из кадра. Отсечение дало прирост отрисовок [29, 0] вместо 42 и 0 вместо 1,
## то есть число зависело от того, куда смотрит шлем, а не от кандидата. Меню
## в руках всегда в кадре, значит и нагрузка фазы обязана быть в кадре при
## любой позе. Для слоя это означает позу POSE_HEAD_LOCKED — композитор его
## всё равно рисует, а цена и нужна.
func setup(host: Node, parent: Node) -> void:
	_host = host
	_parent = parent
	_viewport = host.get_viewport()
	_vp = _viewport.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(_vp, true)
	_container = Node3D.new()
	var cam := _viewport.get_camera_3d()
	if cam != null:
		cam.add_child(_container)
	else:
		parent.add_child(_container)


func run(r: ProbeReport) -> void:
	r.note("")
	r.note("--- L. Ручки рендера и поверхности меню (ADR-0003) ---")
	var res: Dictionary = await ProbeBudget.request_target(_host)
	_hz = res["got"]
	_budget = ProbeBudget.ms_for_hz(_hz)
	r.note("частота %.1f Гц (запрошено %.0f), бюджет %.2f мс — все числа фазы относятся к ней" % [
			_hz, ProbeBudget.TARGET_HZ, _budget])
	if not ProbeBudget.same_hz(_hz, ProbeBudget.TARGET_HZ):
		r.note("ВНИМАНИЕ: фаза идёт НЕ на целевой частоте, решения ADR-0003 по этим числам не принимаются")
	r.note("повторов %d, порядок чередующийся; эффект значим, если вдвое больше разброса повторов" % REPEATS)

	await _clear_and_wait()
	if not await ProbeWindow.wait_until_idle(_host, _vp):
		r.note("ВНИМАНИЕ: кадр не опустел за отведённое время — первые точки могут быть загрязнены")
	await ProbeWindow.settle(_host, 2.0)

	await _msaa(r)
	await _vrs(r)
	await _surfaces(r)
	await _clear_and_wait()


# --- общие части -------------------------------------------------------------

func _clear_and_wait() -> void:
	# Слой отвязывается от SubViewport и освобождается РАНЬШЕ неё. Иначе оба
	# уходят в одном кадре, и слой обращается к уже удалённому вьюпорту:
	# обкатка дала «Parameter "viewport" is null» в render_target_set_override.
	var layers := false
	for c in _container.get_children():
		if c.is_class("OpenXRCompositionLayer"):
			c.set("layer_viewport", null)
			c.queue_free()
			layers = true
	if layers:
		await _host.get_tree().process_frame
		await _host.get_tree().process_frame
	for c in _container.get_children():
		c.queue_free()
	var guard := 0
	while _container.get_child_count() > 0 and guard < 60:
		await _host.get_tree().process_frame
		guard += 1


func _spawn_scene(scene: String) -> void:
	_container.position = Vector3(0, 0, -2)
	if scene == "геометрия":
		var mesh := QuadMesh.new()
		mesh.size = Vector2(0.01, 0.01)
		for i in GEOMETRY_N:
			var mi := MeshInstance3D.new()
			mi.mesh = mesh
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(float(i % 255) / 255.0, 0.5, 0.5)
			mi.material_override = mat
			mi.position = Vector3(fmod(i * 0.013, 0.4) - 0.2, fmod(i * 0.017, 0.4) - 0.2, 0.0)
			_container.add_child(mi)
	else:
		var mesh := QuadMesh.new()
		mesh.size = Vector2(FILL_SIZE, FILL_SIZE)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.4, 0.6, 0.8)
		mat.no_depth_test = true
		for i in FILL_LAYERS:
			var mi := MeshInstance3D.new()
			mi.mesh = mesh
			mi.material_override = mat
			mi.position = Vector3(0, 0, float(i) * 0.001)
			_container.add_child(mi)


static func _mean(a: Array) -> float:
	if a.is_empty():
		return NAN
	var s := 0.0
	for v in a:
		s += float(v)
	return s / a.size()


static func _range(a: Array) -> float:
	if a.size() < 2:
		return NAN
	var lo := float(a[0])
	var hi := float(a[0])
	for v in a:
		lo = minf(lo, float(v))
		hi = maxf(hi, float(v))
	return hi - lo


## Прогон одной ручки по режимам с чередованием. На каждой точке проверяется,
## что ручка действительно встала (чтение обратно) и что снимок состояния
## изменился РОВНО в ожидаемом поле. compared_key пустой — ручка вне снимка,
## и снимок не должен измениться вовсе.
func _knob(modes: Array, setter: Callable, getter: Callable, compared_key: String) -> Dictionary:
	var base_mode = modes[0]
	setter.call(base_mode)
	await ProbeWindow.settle(_host)
	var base_snap := ProbeState.snapshot(_viewport)
	var points := {}
	for m in modes:
		points[m] = {"gpu": [], "cpu": [], "over": 0}
	var bad: Array[String] = []

	for rep in REPEATS:
		var order := modes.duplicate()
		if rep % 2 == 1:
			order.reverse()
		for m in order:
			setter.call(m)
			await ProbeWindow.settle(_host)
			if getter.call() != m:
				bad.append("режим %s не встал: прочитано %s" % [str(m), str(getter.call())])
			var d := ProbeState.diff(base_snap, ProbeState.snapshot(_viewport))
			var expect_change: bool = compared_key != "" and m != base_mode
			if expect_change:
				if d.size() != 1 or not d[0].begins_with(compared_key + ":"):
					bad.append("режим %s: снимок изменился не только в %s: %s" % [str(m), compared_key, str(d)])
			elif not d.is_empty():
				bad.append("режим %s: снимок изменился, хотя не должен: %s" % [str(m), str(d)])
			var meas: Dictionary = await ProbeWindow.measure(_host, _vp, _budget)
			var gpu: ProbeStats = meas["gpu"]
			var cpu: ProbeStats = meas["cpu"]
			points[m]["gpu"].append(gpu.median())
			points[m]["cpu"].append(cpu.median())
			points[m]["over"] += int(meas["over"])

	setter.call(base_mode)
	await ProbeWindow.settle(_host)
	return {"points": points, "bad": bad}


## Разброс повторов по всем режимам ручки — порог значимости для этой ручки.
static func _spread(points: Dictionary) -> float:
	var s := 0.0
	for m in points:
		var v := _range(points[m]["gpu"])
		if not is_nan(v):
			s = maxf(s, v)
	return s


## Эффект режима относительно базы: разница средних GPU и CPU, значимость.
static func _effect(points: Dictionary, mode, base_mode) -> Dictionary:
	var spread := _spread(points)
	var dg := _mean(points[mode]["gpu"]) - _mean(points[base_mode]["gpu"])
	var dc := _mean(points[mode]["cpu"]) - _mean(points[base_mode]["cpu"])
	return {
		"gpu": dg,
		"cpu": dc,
		"spread": spread,
		"significant": absf(dg) > spread * 2.0,
		"gpu_abs": _mean(points[mode]["gpu"]),
		"cpu_abs": _mean(points[mode]["cpu"]),
	}


func _binding(gpu_ms: float, cpu_ms: float) -> String:
	var which := "GPU" if gpu_ms >= cpu_ms else "CPU"
	return "связывает %s: %.1f%% бюджета (GPU %.3f, CPU %.3f мс)" % [
			which, maxf(gpu_ms, cpu_ms) / _budget * 100.0, gpu_ms, cpu_ms]


func _print_points(r: ProbeReport, names: Dictionary, points: Dictionary) -> void:
	for m in points:
		r.note("    %-9s GPU %s  CPU %s  сверх бюджета кадров %d" % [
				names.get(m, str(m)), str(points[m]["gpu"]), str(points[m]["cpu"]), points[m]["over"]])


# --- L1. MSAA -----------------------------------------------------------------

func _msaa(r: ProbeReport) -> void:
	r.note("")
	r.note("L1. MSAA на XR-вьюпорте: %s" % str(MSAA_NAMES.values()))
	var setter := func(m): _viewport.msaa_3d = m
	var getter := func(): return _viewport.msaa_3d

	for scene in SCENES:
		await _clear_and_wait()
		_spawn_scene(scene)
		await ProbeWindow.settle(_host)
		var k: Dictionary = await _knob(MSAA_MODES, setter, getter, "msaa_3d")
		var points: Dictionary = k["points"]
		var bad: Array = k["bad"]
		r.note("  сцена «%s»:" % scene)
		_print_points(r, MSAA_NAMES, points)

		var gate_ok := bad.is_empty()
		if gate_ok:
			r.pass_("L1 гейт состояния, «%s»: MSAA вставал в каждый режим, остальное состояние не менялось" % scene)
		else:
			r.fail("L1 гейт состояния, «%s»: %s — цена MSAA не докладывается" % [scene, "; ".join(bad)])

		for i in range(1, MSAA_MODES.size()):
			var m = MSAA_MODES[i]
			var label := "MSAA %s, «%s»" % [MSAA_NAMES[m], scene]
			if not gate_ok:
				r.unkn("L1 %s: гейт не пройден" % label)
				continue
			var e := _effect(points, m, MSAA_MODES[0])
			results["msaa_%s_%s" % [MSAA_NAMES[m], scene]] = e
			r.pass_("L1 %s: GPU %+.3f мс, CPU %+.3f мс, разброс %.3f — %s; %s" % [
					label, e["gpu"], e["cpu"], e["spread"],
					"ЗНАЧИМО" if e["significant"] else "в шуме, от выключенного не отличить",
					_binding(e["gpu_abs"], e["cpu_abs"])])

	await _falsifier(r)


## Фальсификатор L1. Ручка, которая рендер не трогает: 3D-слушатель звука. Та
## же схема повторов и тот же порог. Если здесь «значимый эффект», значит
## порог ловит дрейф и порядок, а не ручку, — и все эффекты L1–L2 под вопросом.
func _falsifier(r: ProbeReport) -> void:
	await _clear_and_wait()
	_spawn_scene("пиксели")
	await ProbeWindow.settle(_host)
	var setter := func(m): _viewport.audio_listener_enable_3d = m
	var getter := func(): return _viewport.audio_listener_enable_3d
	var before := _viewport.audio_listener_enable_3d
	var modes := [before, not before]
	var k: Dictionary = await _knob(modes, setter, getter, "")
	var points: Dictionary = k["points"]
	var bad: Array = k["bad"]
	r.note("  фальсификатор: audio_listener_enable_3d %s → %s на сцене «пиксели»" % [before, not before])
	_print_points(r, {}, points)
	if not bad.is_empty():
		r.unkn("L1 фальсификатор: ручка не встала или сдвинула состояние: %s" % "; ".join(bad))
		return
	var e := _effect(points, modes[1], modes[0])
	if e["significant"]:
		r.fail("L1 фальсификатор: ручка без влияния на рендер дала %+.3f мс при разбросе %.3f — порог ловит дрейф, эффекты L1–L2 недостоверны" % [
				e["gpu"], e["spread"]])
	else:
		r.pass_("L1 фальсификатор: ручка без влияния на рендер дала %+.3f мс при разбросе %.3f — в шуме, порог различает" % [
				e["gpu"], e["spread"]])


# --- L2. Фовеация -------------------------------------------------------------

func _vrs(r: ProbeReport) -> void:
	r.note("")
	r.note("L2. Фиксированная фовеация: vrs_mode DISABLED → VRS_XR")
	var iface := ProbeBudget.iface()
	if iface != null:
		r.note("  интерфейс: vrs_strength %s, vrs_min_radius %s" % [
				str(iface.get("vrs_strength")), str(iface.get("vrs_min_radius"))])
	var setter := func(m): _viewport.vrs_mode = m
	var getter := func(): return _viewport.vrs_mode

	var effects := {}
	var all_bad: Array[String] = []
	for scene in SCENES:
		await _clear_and_wait()
		_spawn_scene(scene)
		await ProbeWindow.settle(_host)
		var k: Dictionary = await _knob(VRS_MODES, setter, getter, "vrs_mode")
		var points: Dictionary = k["points"]
		r.note("  сцена «%s»:" % scene)
		_print_points(r, VRS_NAMES, points)
		for b in k["bad"]:
			all_bad.append("«%s»: %s" % [scene, b])
		effects[scene] = _effect(points, VRS_MODES[1], VRS_MODES[0])

	var gate_ok := all_bad.is_empty()
	if gate_ok:
		r.pass_("L2 гейт состояния: vrs_mode вставал, остальное состояние не менялось")
	else:
		r.fail("L2 гейт состояния: %s — выигрыш фовеации не докладывается" % "; ".join(all_bad))

	for scene in SCENES:
		if not gate_ok:
			r.unkn("L2 VRS_XR, «%s»: гейт не пройден" % scene)
			continue
		var e: Dictionary = effects[scene]
		results["vrs_%s" % scene] = e
		r.pass_("L2 VRS_XR, «%s»: GPU %+.3f мс, CPU %+.3f мс, разброс %.3f — %s; %s" % [
				scene, e["gpu"], e["cpu"], e["spread"],
				"ЗНАЧИМО" if e["significant"] else "в шуме",
				_binding(e["gpu_abs"], e["cpu_abs"])])

	# Контрольный случай. Фовеация снижает плотность ЗАТЕНЕНИЯ. Её выигрыш на
	# сцене пикселей обязан быть больше, чем на сцене геометрии, где пикселей
	# почти нет. Если не так — меряется не фовеация.
	if not gate_ok:
		r.unkn("L2 контроль: гейт не пройден")
		return
	var px: Dictionary = effects["пиксели"]
	var geo: Dictionary = effects["геометрия"]
	var save_px: float = -px["gpu"]
	var save_geo: float = -geo["gpu"]
	if not px["significant"]:
		r.unkn("L2 контроль: на пикселях выигрыша нет в пределах шума (%+.3f при разбросе %.3f) — сверять не с чем" % [
				px["gpu"], px["spread"]])
	elif not geo["significant"]:
		# Эффект на геометрии в шуме — это и есть ожидаемый исход. Сравнивать
		# его сырое значение со значимым было дефектом обкатки: 0.654 мс при
		# разбросе 2.0 объявлялись «выигрышем больше пиксельного».
		r.pass_("L2 контроль: на геометрии в шуме (%+.3f при разбросе %.3f), на пикселях значимо %.3f мс — эффект пиксельный, меряется фовеация" % [
				geo["gpu"], geo["spread"], save_px])
	elif save_px > save_geo:
		r.pass_("L2 контроль: выигрыш на пикселях %.3f мс больше, чем на геометрии %.3f — эффект пиксельный, меряется фовеация" % [
				save_px, save_geo])
	else:
		r.fail("L2 контроль: выигрыш на геометрии %.3f мс не меньше, чем на пикселях %.3f — эффект не пиксельный, это не фовеация" % [
				save_geo, save_px])


# --- L3. Поверхности меню -----------------------------------------------------

func _dirs() -> Array[Vector3]:
	# Сфера Фибоначчи: равномерные точки без полюсных сгущений.
	var out: Array[Vector3] = []
	var golden := PI * (3.0 - sqrt(5.0))
	for i in CELLS:
		var y := 1.0 - (float(i) + 0.5) / float(CELLS) * 2.0
		var rad := sqrt(1.0 - y * y)
		var th := golden * float(i)
		out.append(Vector3(cos(th) * rad, y, sin(th) * rad))
	return out


func _cell_mesh() -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = 0.02
	m.bottom_radius = 0.02
	m.height = 0.004
	m.radial_segments = 6
	m.rings = 0
	return m


func _cell_xform(dir: Vector3) -> Transform3D:
	return Transform3D(Basis(Quaternion(Vector3.UP, dir)), dir * MENU_RADIUS)


func _atlas() -> SubViewport:
	var sv := SubViewport.new()
	sv.size = Vector2i(ATLAS_PX, ATLAS_PX)
	sv.transparent_bg = true
	sv.disable_3d = true
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var step := float(ATLAS_PX) / float(ATLAS_COLS)
	for i in CELLS:
		var l := Label.new()
		# Латиница намеренно: кириллица могла бы уйти в резервный шрифт, и
		# точка мерила бы подгрузку шрифта, а не атлас.
		l.text = "item %d" % i
		l.position = Vector2(float(i % ATLAS_COLS) * step, floorf(float(i) / ATLAS_COLS) * step)
		sv.add_child(l)
	_container.add_child(sv)
	RenderingServer.viewport_set_measure_render_time(sv.get_viewport_rid(), true)
	return sv


## Строит кандидата. Возвращает {"aux": RID SubViewport или пустой, "layer": узел слоя или null}.
func _spawn_surface(s: String) -> Dictionary:
	_container.position = MENU_POS
	var out := {"aux": RID(), "layer": null, "sv": null}
	match s:
		"пусто":
			pass
		"меши":
			var mesh := _cell_mesh()
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(0.3, 0.7, 0.9)
			for d in _dirs():
				var mi := MeshInstance3D.new()
				mi.mesh = mesh
				mi.material_override = mat
				mi.transform = _cell_xform(d)
				_container.add_child(mi)
		"мультимеш", "атлас":
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = _cell_mesh()
			var dirs := _dirs()
			mm.instance_count = dirs.size()
			for i in dirs.size():
				mm.set_instance_transform(i, _cell_xform(dirs[i]))
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(0.3, 0.7, 0.9)
			mmi.material_override = mat
			_container.add_child(mmi)
			if s == "атлас":
				var sv := _atlas()
				var sphere := MeshInstance3D.new()
				var sm := SphereMesh.new()
				sm.radius = MENU_RADIUS * 0.95
				sm.height = MENU_RADIUS * 1.9
				sphere.mesh = sm
				var smat := StandardMaterial3D.new()
				smat.albedo_texture = sv.get_texture()
				smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				sphere.material_override = smat
				_container.add_child(sphere)
				out["aux"] = sv.get_viewport_rid()
				out["sv"] = sv
		"слой":
			var sv := _atlas()
			if ClassDB.class_exists("OpenXRCompositionLayerCylinder"):
				var layer: Node3D = ClassDB.instantiate("OpenXRCompositionLayerCylinder")
				# Поза слоя — центр цилиндра. Центр ставится в голову, иначе
				# поверхность окажется за спиной и композитор может её отсечь,
				# сделав точку бесплатной.
				layer.position = -MENU_POS
				# Сначала в дерево, потом свойства: сеттеры слоя пересчитывают
				# позу через get_global_transform(), а вне дерева это ошибка.
				_container.add_child(layer)
				layer.set("radius", 0.6)
				layer.set("aspect_ratio", 1.0)
				layer.set("central_angle", PI / 3.0)
				layer.set("layer_viewport", sv)
				out["layer"] = layer
			out["aux"] = sv.get_viewport_rid()
			out["sv"] = sv
	return out


static func _canvas_calls(vp: RID) -> int:
	return RenderingServer.viewport_get_render_info(vp,
			RenderingServer.VIEWPORT_RENDER_INFO_TYPE_CANVAS,
			RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)


func _surfaces(r: ProbeReport) -> void:
	r.note("")
	r.note("L3. Поверхности меню: %d ячеек на сфере %.2f м, атлас %dx%d" % [CELLS, MENU_RADIUS, ATLAS_PX, ATLAS_PX])
	r.note("  время SubViewport считается отдельно и складывается с главным: кадр оплачивает оба")

	var pts := {}
	for s in SURFACES:
		pts[s] = {"gpu": [], "cpu": [], "main_gpu": [], "aux_gpu": [], "calls": [], "fps": [],
				"over": 0, "canvas": 0, "native": null}

	for rep in REPEATS:
		var order := SURFACES.duplicate()
		if rep % 2 == 1:
			order.reverse()
		for s in order:
			await _clear_and_wait()
			if not await ProbeWindow.wait_until_idle(_host, _vp):
				r.note("  ВНИМАНИЕ: перед «%s» кадр не опустел" % s)
			var built := _spawn_surface(s)
			await ProbeWindow.settle(_host)
			var aux: RID = built["aux"]
			var meas: Dictionary = await ProbeWindow.measure(_host, _vp, _budget,
					ProbeWindow.WARMUP_S, ProbeWindow.MEASURE_S, aux)
			var gpu: ProbeStats = meas["gpu"]
			var cpu: ProbeStats = meas["cpu"]
			var ag: ProbeStats = meas["aux_gpu"]
			var ac: ProbeStats = meas["aux_cpu"]
			var aux_g := ag.median() if ag.count() > 0 else 0.0
			var aux_c := ac.median() if ac.count() > 0 else 0.0
			var p: Dictionary = pts[s]
			p["main_gpu"].append(gpu.median())
			p["aux_gpu"].append(aux_g)
			p["gpu"].append(gpu.median() + aux_g)
			p["cpu"].append(cpu.median() + aux_c)
			p["calls"].append(meas["calls"])
			p["fps"].append(meas["fps"])
			p["over"] += int(meas["over"])
			if aux.is_valid():
				p["canvas"] = maxi(p["canvas"], _canvas_calls(aux))
			if built["layer"] != null:
				p["native"] = built["layer"].call("is_natively_supported")
			elif s == "слой":
				p["native"] = false

	await _clear_and_wait()

	for s in SURFACES:
		var p: Dictionary = pts[s]
		r.note("  %-9s сумма GPU %s (главный %s + SubViewport %s), CPU %s, отрисовок %s, к/с %s, сверх бюджета %d" % [
				s, _fmt_list(p["gpu"]), _fmt_list(p["main_gpu"]), _fmt_list(p["aux_gpu"]),
				_fmt_list(p["cpu"]), str(p["calls"]), _fmt_list(p["fps"]), p["over"]])

	var gates := _surface_gates(r, pts)
	_surface_costs(r, pts, gates)
	_layer_delivery(r, pts, gates)


static func _fmt_list(a: Array) -> String:
	var parts: PackedStringArray = []
	for v in a:
		parts.append("%.3f" % float(v))
	return "[" + ", ".join(parts) + "]"


## Гейты кандидатов. Возвращает имя → прошли ли все гейты кандидата.
func _surface_gates(r: ProbeReport, pts: Dictionary) -> Dictionary:
	var ok := {}
	var base_calls: int = int(_mean(pts["пусто"]["calls"]))

	var empty_calls: Array = pts["пусто"]["calls"]
	var dirty := false
	for c in empty_calls:
		if int(c) != 0:
			dirty = true
	if dirty:
		r.fail("L3 гейт «пусто»: в пустом кадре отрисовки %s — все приросты отсчитываются от неверной базы" % str(empty_calls))
	else:
		r.pass_("L3 гейт «пусто»: кадр пуст на всех повторах")
	ok["пусто"] = not dirty

	var want := {"меши": CELLS, "мультимеш": 1, "атлас": 2, "слой": 0}
	for s in ["меши", "мультимеш", "атлас", "слой"]:
		var got: Array = []
		for c in pts[s]["calls"]:
			got.append(int(c) - base_calls)
		var match_all := true
		for g in got:
			if g != want[s]:
				match_all = false
		ok[s] = ok["пусто"] and match_all
		if s == "слой":
			# Порядок гейтов слоя: сначала нативность — без неё прирост 0 может
			# значить «нет даже подмены», и следующий гейт соврал бы зелёным.
			var native = pts[s]["native"]
			# `is bool` первым: сравнение null с bool в GDScript — ошибка
			# исполнения, она оборвала бы функцию, и пол бы не сошёлся.
			if native is bool and native:
				r.pass_("L3 гейт «слой»: is_natively_supported() = true, рантайм принимает cylinder-слой")
			else:
				r.fail("L3 гейт «слой»: is_natively_supported() = %s — слой не нативный, Godot рисует подмену мешем" % str(native))
				ok[s] = false
			if match_all:
				r.pass_("L3 гейт «слой»: прирост отрисовок главного вьюпорта %s = 0 — подмены мешем нет" % str(got))
			else:
				r.fail("L3 гейт «слой»: прирост отрисовок %s вместо 0 — в мировом буфере подмена, точка мерит меш, а не слой" % str(got))
		elif match_all:
			r.pass_("L3 гейт «%s»: прирост отрисовок %s = %d, как заявлено" % [s, str(got), want[s]])
		else:
			# Меньше заявленного — либо часть ячеек вне кадра, либо движок слил
			# вызовы. Прибор различить их не может и называет обе версии.
			var hint := " — часть ячеек отсечена или движок слил вызовы" if got.size() > 0 and int(got.min()) < want[s] else ""
			r.fail("L3 гейт «%s»: прирост отрисовок %s вместо %d%s; цена кандидата недостоверна" % [s, str(got), want[s], hint])

		if s == "атлас" or s == "слой":
			var canvas: int = pts[s]["canvas"]
			if canvas > 0:
				r.pass_("L3 гейт «%s»: SubViewport рисует (%d отрисовок холста)" % [s, canvas])
			else:
				r.fail("L3 гейт «%s»: SubViewport не рисует ни одной отрисовки — время атласа меряет пустоту" % s)
				ok[s] = false
	return ok


func _surface_costs(r: ProbeReport, pts: Dictionary, gates: Dictionary) -> void:
	var spread := 0.0
	for s in SURFACES:
		var v := _range(pts[s]["gpu"])
		if not is_nan(v):
			spread = maxf(spread, v)
	for s in SURFACES:
		if s == "пусто":
			continue
		if not gates.get(s, false):
			r.unkn("L3 цена «%s»: гейт не пройден" % s)
			continue
		var dg := _mean(pts[s]["gpu"]) - _mean(pts["пусто"]["gpu"])
		var dc := _mean(pts[s]["cpu"]) - _mean(pts["пусто"]["cpu"])
		var sig := absf(dg) > spread * 2.0
		results["surface_%s" % s] = {"gpu": dg, "cpu": dc, "spread": spread, "significant": sig}
		r.pass_("L3 цена «%s»: GPU %+.3f мс (из них SubViewport %.3f), CPU %+.3f мс, разброс %.3f — %s; %s" % [
				s, dg, _mean(pts[s]["aux_gpu"]), dc, spread,
				"ЗНАЧИМО" if sig else "в шуме",
				_binding(_mean(pts[s]["gpu"]), _mean(pts[s]["cpu"]))])


## Композитор приложению не виден, поэтому цена слоя сверх SubViewport
## проявляется только в доставке. Сравнивается с пустым кадром того же
## прогона, порог — разброс к/с пустого кадра между повторами.
func _layer_delivery(r: ProbeReport, pts: Dictionary, gates: Dictionary) -> void:
	if not gates.get("слой", false):
		r.unkn("L3 доставка при слое: гейт слоя не пройден")
		return
	var fps_layer := _mean(pts["слой"]["fps"])
	var fps_empty := _mean(pts["пусто"]["fps"])
	var spread := maxf(_range(pts["пусто"]["fps"]), _range(pts["слой"]["fps"]))
	var drop := fps_empty - fps_layer
	r.note("  доставка: пусто %.1f к/с, слой %.1f к/с, разброс %.2f; сверх бюджета при слое %d кадров" % [
			fps_empty, fps_layer, spread, pts["слой"]["over"]])
	if drop > spread * 2.0:
		r.fail("L3 доставка при слое: минус %.1f к/с против пустого кадра при разбросе %.2f — композитор со слоем не успевает" % [drop, spread])
	else:
		r.pass_("L3 доставка при слое: %.1f к/с против %.1f у пустого, в пределах шума — цены композитора в доставке не видно" % [
				fps_layer, fps_empty])
