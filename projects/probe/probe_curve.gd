extends RefCounted
class_name ProbeCurve

## Фаза K: форма кривой «время кадра от числа вызовов» на 90 Гц.
##
## Вопрос из ADR-0003 «Открыто». Прогон 11 показал, что кривая нелинейна: излом
## между 400 и 800 при MSAA off, а 2x удешевляет середину. По пяти точкам не
## видно, ГДЕ излом, и концы лестницы сравнивали разный клок. Здесь — плотная
## лестница, каждая точка с unix-временем окна, чтобы с хоста к ней свести:
##   клок GPU            tools/gpu_sampler.sh
##   режим рендера, бины tools/gpu_stages.sh  (детальный режим — отдельный прогон)
##   память GPU          tools/gpu_mem.sh     (цена вложений MSAA)
## Сводит tools/join_windows.py.
##
## Порядок против дрейфа. Режимы идут ABBA (off, 2x, 2x, off), направление
## лестницы — вверх в первой половине и вниз во второй: у каждого режима один
## проход вверх и один вниз. Монотонный дрейф ложится на проходы с разным
## знаком и в среднем сокращается, а расхождение проходов меряет его величину.
##
## Контроль: вверх и вниз обязаны совпасть в пределах дрейфа прибора (15%). Не
## совпали — форма кривой принадлежит времени, а не N.
##
## Включается маркером user://curve: фаза исследовательская, ~6 минут, и
## штатный прогон ею не удлиняется.

const ProbeReport := preload("res://probe_report.gd")
const ProbeStats := preload("res://probe_stats.gd")
const ProbeBudget := preload("res://probe_budget.gd")
const ProbeWindow := preload("res://probe_window.gd")
const ProbeState := preload("res://probe_state.gd")

## Гуще там, где прогон 11 видел излом. 1600 — верх штатных лестниц, для
## сопоставимости с C–D и L4.
const POINTS := [0, 100, 200, 300, 350, 400, 450, 500, 550, 600, 650, 700, 750, 800, 900, 1000, 1200, 1600]
const MODES := [Viewport.MSAA_DISABLED, Viewport.MSAA_2X]
const NAMES := {Viewport.MSAA_DISABLED: "off", Viewport.MSAA_2X: "2x"}
const ORDER := [0, 1, 1, 0]
const ASCENDING := [true, true, false, false]

## Инстансы: ступенька при N=50 в прогоне 10 вместо наклона. Гуще у нуля.
const INST_POINTS := [0, 25, 50, 75, 100, 150, 200, 400, 800, 1600]

## Та же константа, что в L4: дрейф абсолютных чисел за прогон ≈15%.
const DRIFT_TOLERANCE := 0.15

## Паузы между сменой режима и замером, на плато памяти.
const MODE_PLATEAU_S := 4.0

var _host: Node
var _viewport: Viewport
var _vp: RID
var _container: Node3D
var _budget := NAN
var _hz := NAN
var _tsv: FileAccess
var _log_path := "user://curve.tsv"

## режим → Array проходов; проход = {"asc": bool, "pts": {N → {"gpu","cpu","calls","over","fps"}}}
var passes: Dictionary = {}
## Array проходов инстансов, та же форма.
var inst_passes: Array = []
## режим → {"break": int, "before_us": float, "after_us": float, "spread_us": float, "significant": bool}
var knees: Dictionary = {}


func expected_checks() -> int:
	# гейт состояния 1; гейт счётчика на режим 2; гейт инстансов 1;
	# контроль «вверх = вниз» на режим 2; излом на режим 2;
	# инстансы — ступенька или наклон 1; доставка на верхней точке 1
	return 1 + MODES.size() + 1 + MODES.size() + MODES.size() + 1 + 1


func setup(host: Node, parent: Node) -> void:
	_host = host
	_viewport = host.get_viewport()
	_vp = _viewport.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(_vp, true)
	_container = Node3D.new()
	ProbeWindow.attach_load(host, parent, _container)


func _clear_and_wait() -> void:
	for c in _container.get_children():
		c.queue_free()
	var guard := 0
	while _container.get_child_count() > 0 and guard < 60:
		await _host.get_tree().process_frame
		guard += 1


## Та же нагрузка, что в C–D и L4: крошечные квады с уникальным материалом.
func _spawn(n: int) -> void:
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.01, 0.01)
	for i in n:
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(float(i % 255) / 255.0, 0.5, 0.5)
		mi.material_override = mat
		mi.position = Vector3(fmod(i * 0.013, 0.4) - 0.2, fmod(i * 0.017, 0.4) - 0.2, 0.0)
		_container.add_child(mi)


func _spawn_instanced(n: int) -> void:
	if n == 0:
		return
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.01, 0.01)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = n
	for i in n:
		mm.set_instance_transform(i, Transform3D(Basis(), Vector3(
				fmod(i * 0.013, 0.4) - 0.2, fmod(i * 0.017, 0.4) - 0.2, 0.0)))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = StandardMaterial3D.new()
	_container.add_child(mmi)


func run(r: ProbeReport) -> void:
	r.note("")
	r.note("--- K. Форма кривой «время от числа вызовов» (ADR-0003, открыто) ---")
	var res: Dictionary = await ProbeBudget.request_target(_host)
	_hz = res["got"]
	_budget = ProbeBudget.ms_for_hz(_hz)
	r.note("частота %.1f Гц, бюджет %.2f мс; точек %d; порядок %s" % [
			_hz, _budget, POINTS.size(),
			str(range(ORDER.size()).map(func(i): return "%s%s" % [NAMES[MODES[ORDER[i]]], "↑" if ASCENDING[i] else "↓"]))])
	if not ProbeBudget.same_hz(_hz, ProbeBudget.TARGET_HZ):
		r.note("ВНИМАНИЕ: фаза идёт НЕ на целевой частоте")

	_tsv = FileAccess.open(_log_path, FileAccess.WRITE)
	if _tsv != null:
		# Окно точки — [начало, конец] по unix-времени: по нему свод с хостом.
		_tsv.store_line("# unix_начало\tunix_конец\tсерия\tрежим\tпроход\tнаправление\tN\tотрисовок\tGPU мед\tCPU мед\tкадров\tк/с\tсверх бюджета")

	for m in MODES:
		passes[m] = []
	var before := _viewport.msaa_3d
	_viewport.msaa_3d = MODES[0]
	await ProbeWindow.settle(_host)
	var base_snap := ProbeState.snapshot(_viewport)
	var bad: Array[String] = []

	for i in ORDER.size():
		var mode = MODES[ORDER[i]]
		_viewport.msaa_3d = mode
		await _clear_and_wait()
		await ProbeWindow.settle(_host, MODE_PLATEAU_S)
		# Отметка плато режима на пустой сцене — окно для свода с gpu_mem.sh:
		# разность памяти off/2x читается здесь, без нагрузки поверх.
		_mark("плато_" + NAMES[mode], i)
		if _viewport.msaa_3d != mode:
			bad.append("MSAA %s не встал" % NAMES[mode])
		var d := ProbeState.diff(base_snap, ProbeState.snapshot(_viewport))
		if mode == MODES[0]:
			if not d.is_empty():
				bad.append("off: снимок изменился: %s" % str(d))
		elif d.size() != 1 or not d[0].begins_with("msaa_3d:"):
			bad.append("%s: снимок изменился не только в msaa_3d: %s" % [NAMES[mode], str(d)])

		var pts := POINTS.duplicate()
		if not ASCENDING[i]:
			pts.reverse()
		r.note("  лестница MSAA %s, проход %d %s:" % [NAMES[mode], passes[mode].size() + 1, "вверх" if ASCENDING[i] else "вниз"])
		var ladder: Dictionary = await _ladder(r, "вызовы", NAMES[mode], passes[mode].size(), ASCENDING[i], pts, _spawn)
		passes[mode].append({"asc": ASCENDING[i], "pts": ladder})

	# Инстансы — под off, вверх и вниз.
	_viewport.msaa_3d = MODES[0]
	await _clear_and_wait()
	await ProbeWindow.settle(_host)
	for asc in [true, false]:
		var pts := INST_POINTS.duplicate()
		if not asc:
			pts.reverse()
		r.note("  инстансы, проход %s:" % ("вверх" if asc else "вниз"))
		var ladder: Dictionary = await _ladder(r, "инстансы", "off", inst_passes.size(), asc, pts, _spawn_instanced)
		inst_passes.append({"asc": asc, "pts": ladder})

	await _clear_and_wait()
	_viewport.msaa_3d = before
	if _tsv != null:
		_tsv.close()
	r.note("сырые точки: %s — свод с хостом: tools/join_windows.py" % ProjectSettings.globalize_path(_log_path))

	_check_state(r, bad)
	for m in MODES:
		_check_calls(r, m)
	_check_instanced_calls(r)
	for m in MODES:
		_check_order(r, m)
	for m in MODES:
		_knee(r, m)
	_instanced_shape(r)
	_delivery(r)


func _ladder(r: ProbeReport, series: String, mode_name: String, pass_idx: int, asc: bool,
		pts: Array, spawn: Callable) -> Dictionary:
	var ladder := {}
	for n in pts:
		await _clear_and_wait()
		if not await ProbeWindow.wait_until_idle(_host, _vp):
			r.note("    ВНИМАНИЕ: перед N=%d кадр не опустел" % n)
		spawn.call(n)
		await ProbeWindow.settle(_host, 0.5)
		var t0 := Time.get_unix_time_from_system()
		var meas: Dictionary = await ProbeWindow.measure(_host, _vp, _budget)
		var t1 := Time.get_unix_time_from_system()
		var gpu: ProbeStats = meas["gpu"]
		var cpu: ProbeStats = meas["cpu"]
		ladder[n] = {"gpu": gpu.median(), "cpu": cpu.median(), "calls": meas["calls"],
				"over": meas["over"], "fps": meas["fps"]}
		r.note("    N=%-5d отрисовок %-5d GPU %.3f  CPU %.3f мс; %s" % [
				n, meas["calls"], gpu.median(), cpu.median(), ProbeWindow.delivery_brief(meas, _hz)])
		if _tsv != null:
			_tsv.store_line("%.3f\t%.3f\t%s\t%s\t%d\t%s\t%d\t%d\t%.3f\t%.3f\t%d\t%.1f\t%d" % [
					t0, t1, series, mode_name, pass_idx, "вверх" if asc else "вниз", n,
					meas["calls"], gpu.median(), cpu.median(), meas["frames"], meas["fps"], meas["over"]])
			_tsv.flush()
	return ladder


func _mark(label: String, idx: int) -> void:
	if _tsv == null:
		return
	var t := Time.get_unix_time_from_system()
	_tsv.store_line("%.3f\t%.3f\t%s\t-\t%d\t-\t0\t%d\t-\t-\t-\t-\t-" % [
			t - MODE_PLATEAU_S * 0.5, t, label, idx, ProbeWindow._calls(_vp)])
	_tsv.flush()


func _check_state(r: ProbeReport, bad: Array[String]) -> void:
	if bad.is_empty():
		r.pass_("K гейт состояния: MSAA вставал в каждый режим, остальное состояние не менялось")
	else:
		r.fail("K гейт состояния: %s" % "; ".join(bad))


## Каждая точка каждого прохода обязана дать ровно N отрисовок.
func _check_calls(r: ProbeReport, mode) -> void:
	var miss: Array[String] = []
	for p in passes[mode]:
		for n in POINTS:
			if int(p["pts"][n]["calls"]) != n:
				miss.append("N=%d→%d" % [n, p["pts"][n]["calls"]])
	if miss.is_empty():
		r.pass_("K гейт счётчика, MSAA %s: все %d точек дали ровно N отрисовок" % [
				NAMES[mode], POINTS.size() * passes[mode].size()])
	else:
		r.fail("K гейт счётчика, MSAA %s: расхождение %s — форма кривой недостоверна" % [NAMES[mode], ", ".join(miss)])


## Инстансы обязаны давать постоянный счётчик при любом N > 0: иначе режим не
## отличается от небатченого и «цена инстанса» — это цена вызова.
func _check_instanced_calls(r: ProbeReport) -> void:
	var seen := {}
	for p in inst_passes:
		for n in INST_POINTS:
			if n > 0:
				seen[int(p["pts"][n]["calls"])] = true
	if seen.size() == 1 and seen.keys()[0] <= 2:
		r.pass_("K гейт инстансов: при любом N>0 ровно %d отрисовок — инстансинг работает" % seen.keys()[0])
	else:
		r.fail("K гейт инстансов: счётчик при N>0 принимал значения %s — режимы не различаются" % str(seen.keys()))


## Контроль «вверх = вниз»: одна точка в двух проходах, среднее расхождение.
func _check_order(r: ProbeReport, mode) -> void:
	var up: Dictionary = {}
	var down: Dictionary = {}
	for p in passes[mode]:
		if p["asc"]:
			up = p["pts"]
		else:
			down = p["pts"]
	if up.is_empty() or down.is_empty():
		r.unkn("K контроль порядка, MSAA %s: нет пары проходов" % NAMES[mode])
		return
	var worst_rel := 0.0
	var worst_n := 0
	var sum_rel := 0.0
	for n in POINTS:
		var a: float = up[n]["gpu"]
		var b: float = down[n]["gpu"]
		var rel := absf(a - b) / maxf(minf(a, b), 0.001)
		sum_rel += rel
		if rel > worst_rel:
			worst_rel = rel
			worst_n = n
	var mean_rel := sum_rel / POINTS.size()
	if mean_rel <= DRIFT_TOLERANCE:
		r.pass_("K контроль порядка, MSAA %s: вверх и вниз расходятся в среднем на %.1f%% (худшая N=%d, %.1f%%) — в пределах дрейфа %.0f%%, форма принадлежит N" % [
				NAMES[mode], mean_rel * 100.0, worst_n, worst_rel * 100.0, DRIFT_TOLERANCE * 100.0])
	else:
		r.fail("K контроль порядка, MSAA %s: вверх и вниз расходятся в среднем на %.1f%% (худшая N=%d, %.1f%%) — больше дрейфа %.0f%%, форма принадлежит ВРЕМЕНИ" % [
				NAMES[mode], mean_rel * 100.0, worst_n, worst_rel * 100.0, DRIFT_TOLERANCE * 100.0])


## Излом: кусочно-линейная подгонка с перебором точки излома по внутренним
## точкам. Наклоны до и после считаются по КАЖДОМУ проходу отдельно — их
## расхождение и есть разброс. Излом значим, если наклоны до и после разошлись
## больше чем вдвое против разброса (как во всех фазах).
func _knee(r: ProbeReport, mode) -> void:
	if passes[mode].size() < 2:
		r.unkn("K излом, MSAA %s: проходов меньше двух" % NAMES[mode])
		return
	var mean_pts := {}
	for n in POINTS:
		var s := 0.0
		for p in passes[mode]:
			s += float(p["pts"][n]["gpu"])
		mean_pts[n] = s / passes[mode].size()

	var line := _fit(POINTS, mean_pts)
	var best_b := -1
	var best_sse: float = line["sse"]
	for bi in range(2, POINTS.size() - 2):
		var b: int = POINTS[bi]
		var lo := _fit(POINTS.slice(0, bi + 1), mean_pts)
		var hi := _fit(POINTS.slice(bi), mean_pts)
		var sse: float = lo["sse"] + hi["sse"]
		if sse < best_sse:
			best_sse = sse
			best_b = b
	if best_b < 0:
		knees[mode] = {"break": -1, "significant": false}
		r.pass_("K излом, MSAA %s: одна прямая не хуже любой ломаной — %.3f мкс/вызов, излома нет" % [
				NAMES[mode], line["slope"] * 1000.0])
		return

	var bi_best := POINTS.find(best_b)
	var before: Array[float] = []
	var after: Array[float] = []
	for p in passes[mode]:
		before.append(_fit(POINTS.slice(0, bi_best + 1), p["pts"], "gpu")["slope"] * 1000.0)
		after.append(_fit(POINTS.slice(bi_best), p["pts"], "gpu")["slope"] * 1000.0)
	var b_us := _mean(before)
	var a_us := _mean(after)
	var spread := maxf(_range(before), _range(after))
	var significant := absf(a_us - b_us) > spread * 2.0
	knees[mode] = {"break": best_b, "before_us": b_us, "after_us": a_us, "spread_us": spread,
			"significant": significant, "sse_line": line["sse"], "sse_knee": best_sse}
	r.pass_("K излом, MSAA %s: лучшая ломаная с изломом на N=%d — до %.3f, после %.3f мкс/вызов (разброс проходов %.3f); SSE прямой %.4f против ломаной %.4f — %s" % [
			NAMES[mode], best_b, b_us, a_us, spread, line["sse"], best_sse,
			"ИЗЛОМ ЗНАЧИМ" if significant else "разница наклонов в шуме"])


## Инстансы: наклон по всей лестнице против ступеньки на первой ненулевой точке.
func _instanced_shape(r: ProbeReport) -> void:
	if inst_passes.size() < 2:
		r.unkn("K инстансы: проходов меньше двух")
		return
	var no_zero := INST_POINTS.slice(1)
	var slopes: Array[float] = []
	var steps: Array[float] = []
	for p in inst_passes:
		slopes.append(_fit(no_zero, p["pts"], "gpu")["slope"] * 1000.0)
		steps.append(float(p["pts"][INST_POINTS[1]]["gpu"]) - float(p["pts"][0]["gpu"]))
	var s_us := _mean(slopes)
	var spread := _range(slopes)
	var grows := s_us > spread * 2.0
	r.pass_("K инстансы на %.0f Гц: наклон без нуля %.4f мкс/инстанс (проходы %s, разброс %.4f) — %s; ступенька 0→%d: %.3f мс" % [
			_hz, s_us, str(slopes), spread,
			"НАКЛОН ЗНАЧИМ" if grows else "наклон в шуме, цена инстанса ниже разрешения",
			INST_POINTS[1], _mean(steps)])


func _delivery(r: ProbeReport) -> void:
	var n_hi: int = POINTS[POINTS.size() - 1]
	var parts: PackedStringArray = []
	var total := 0
	for m in MODES:
		var over := 0
		for p in passes[m]:
			over += int(p["pts"][n_hi]["over"])
		total += over
		parts.append("%s: сверх бюджета %d" % [NAMES[m], over])
	if total == 0:
		r.pass_("K доставка на N=%d: %s — промахов нет" % [n_hi, "; ".join(parts)])
	else:
		r.fail("K доставка на N=%d: %s" % [n_hi, "; ".join(parts)])


## Наименьшие квадраты y = a + b·N по точкам ns. data: N → значение или N → {key: значение}.
static func _fit(ns: Array, data: Dictionary, key: String = "") -> Dictionary:
	var k := float(ns.size())
	var sx := 0.0
	var sy := 0.0
	var sxx := 0.0
	var sxy := 0.0
	for n in ns:
		var x := float(n)
		var y: float = float(data[n][key]) if key != "" else float(data[n])
		sx += x
		sy += y
		sxx += x * x
		sxy += x * y
	var den := k * sxx - sx * sx
	if absf(den) < 0.000001:
		return {"slope": NAN, "icpt": NAN, "sse": INF}
	var b := (k * sxy - sx * sy) / den
	var a := (sy - b * sx) / k
	var sse := 0.0
	for n in ns:
		var y: float = float(data[n][key]) if key != "" else float(data[n])
		var e := y - (a + b * float(n))
		sse += e * e
	return {"slope": b, "icpt": a, "sse": sse}


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
