extends RefCounted
class_name ProbeMsaaSweep

## Фаза L4: цена draw call под MSAA 2x против MSAA off в одной сессии.
##
## Прогон 10 показал, что MSAA 2x ДЕШЕВЛЕ выключенного: −2.117 мс GPU на сцене
## из 400 вызовов и −1.020 мс на 8 слоях во весь экран, при равном клоке 456 МГц.
## Подпись — при 2x цена вызова почти исчезает. Но это две точки, а не наклон.
## ADR-0003 (пункт 6) включает 2x только при условии, что формула бюджета
## перемерена под 2x. Эта фаза и есть условие.
##
## Почему не повтор фазы C–D с флагом MSAA. Сравнение двух отдельных запусков —
## тот межсессионный конфаунд, ради устранения которого делалась матрица:
## дрейф за прогон доходит до 13% на 90 Гц. Здесь обе лестницы идут в ОДНОЙ
## сессии в порядке ABBA — off, 2x, 2x, off: монотонный дрейф одинаково ложится
## на оба режима и в разности сокращается.
##
## Контроль: наклон «off» здесь обязан воспроизвести наклон фазы C–D того же
## прогона (там MSAA тоже off). Расходятся больше дрейфа — фаза меряет не то.
##
## Нагрузка крепится к камере, как в фазе L: число отрисовок не должно зависеть
## от того, куда смотрит шлем (обкатка 2026-09-13).

const ProbeReport := preload("res://probe_report.gd")
const ProbeStats := preload("res://probe_stats.gd")
const ProbeBudget := preload("res://probe_budget.gd")
const ProbeWindow := preload("res://probe_window.gd")
const ProbeState := preload("res://probe_state.gd")

const POINTS := [0, 200, 400, 800, 1600]
const MODES := [Viewport.MSAA_DISABLED, Viewport.MSAA_2X]
const NAMES := {Viewport.MSAA_DISABLED: "off", Viewport.MSAA_2X: "2x"}
## ABBA: индексы режимов по повторам.
const ORDER := [0, 1, 1, 0]

## Допуск контроля «off против C–D». Не назначен из головы: паспорт фиксирует
## расхождение абсолютных чисел между прогонами ≈15% (канарейка +13.1% на 90 Гц
## за сто секунд). Внутри одной сессии расхождение больше этого — уже не дрейф.
const CONTROL_TOLERANCE := 0.15

var _host: Node
var _viewport: Viewport
var _vp: RID
var _container: Node3D
var _budget := NAN

## режим → Array повторов; повтор = {N → {"gpu": float, "cpu": float, "calls": int, "over": int}}
var reps: Dictionary = {}
## режим → {"gpu_us": float, "cpu_us": float, "spread_us": float, "base_gpu": float}
var results: Dictionary = {}


func expected_checks() -> int:
	# гейт состояния 1; гейт счётчика на режим; наклон на режим; база 1;
	# сравнение наклонов 1; доставка на верхней точке 1; контроль с C–D 1
	return 1 + MODES.size() * 2 + 1 + 1 + 1 + 1


func setup(host: Node, parent: Node) -> void:
	_host = host
	_viewport = host.get_viewport()
	_vp = _viewport.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(_vp, true)
	_container = Node3D.new()
	_container.position = Vector3(0, 0, -2)
	var cam := _viewport.get_camera_3d()
	if cam != null:
		cam.add_child(_container)
	else:
		parent.add_child(_container)


func _clear_and_wait() -> void:
	for c in _container.get_children():
		c.queue_free()
	var guard := 0
	while _container.get_child_count() > 0 and guard < 60:
		await _host.get_tree().process_frame
		guard += 1


## Та же нагрузка, что в C–D: крошечные квады с уникальным материалом.
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


func run(r: ProbeReport, cd_gpu_us: float) -> void:
	r.note("")
	r.note("--- L4. Цена draw call под MSAA 2x против off (ADR-0003, условие пункта 6) ---")
	var res: Dictionary = await ProbeBudget.request_target(_host)
	var hz: float = res["got"]
	_budget = ProbeBudget.ms_for_hz(hz)
	r.note("частота %.1f Гц, бюджет %.2f мс; точки %s; порядок режимов %s" % [
			hz, _budget, str(POINTS), str(ORDER.map(func(i): return NAMES[MODES[i]]))])
	if not ProbeBudget.same_hz(hz, ProbeBudget.TARGET_HZ):
		r.note("ВНИМАНИЕ: фаза идёт НЕ на целевой частоте")

	for m in MODES:
		reps[m] = []
	var before := _viewport.msaa_3d
	_viewport.msaa_3d = MODES[0]
	await ProbeWindow.settle(_host)
	var base_snap := ProbeState.snapshot(_viewport)
	var bad: Array[String] = []

	await _clear_and_wait()
	await ProbeWindow.wait_until_idle(_host, _vp)

	for idx in ORDER:
		var mode = MODES[idx]
		_viewport.msaa_3d = mode
		await ProbeWindow.settle(_host)
		if _viewport.msaa_3d != mode:
			bad.append("MSAA %s не встал" % NAMES[mode])
		var d := ProbeState.diff(base_snap, ProbeState.snapshot(_viewport))
		if mode == MODES[0]:
			if not d.is_empty():
				bad.append("off: снимок изменился: %s" % str(d))
		elif d.size() != 1 or not d[0].begins_with("msaa_3d:"):
			bad.append("%s: снимок изменился не только в msaa_3d: %s" % [NAMES[mode], str(d)])

		var ladder := {}
		r.note("  лестница MSAA %s (повтор %d):" % [NAMES[mode], reps[mode].size() + 1])
		for n in POINTS:
			await _clear_and_wait()
			if not await ProbeWindow.wait_until_idle(_host, _vp):
				r.note("    ВНИМАНИЕ: перед N=%d кадр не опустел" % n)
			_spawn(n)
			await ProbeWindow.settle(_host, 0.5)
			var meas: Dictionary = await ProbeWindow.measure(_host, _vp, _budget)
			var gpu: ProbeStats = meas["gpu"]
			var cpu: ProbeStats = meas["cpu"]
			ladder[n] = {"gpu": gpu.median(), "cpu": cpu.median(), "calls": meas["calls"],
					"over": meas["over"], "fps": meas["fps"]}
			r.note("    N=%-5d отрисовок %-5d GPU %.3f  CPU %.3f мс; %s" % [
					n, meas["calls"], gpu.median(), cpu.median(),
					ProbeWindow.delivery_brief(meas, hz)])
		reps[mode].append(ladder)

	await _clear_and_wait()
	_viewport.msaa_3d = before

	_check_state(r, bad)
	var gates := {}
	for m in MODES:
		gates[m] = _check_calls(r, m)
	for m in MODES:
		_slope(r, m, gates[m])
	_check_base(r, gates)
	_compare(r, gates)
	_delivery(r)
	_control(r, gates, cd_gpu_us)


func _check_state(r: ProbeReport, bad: Array[String]) -> void:
	if bad.is_empty():
		r.pass_("L4 гейт состояния: MSAA вставал в каждый режим, остальное состояние не менялось")
	else:
		r.fail("L4 гейт состояния: %s" % "; ".join(bad))


## Каждая точка каждого повтора обязана дать ровно N отрисовок. Наклон по
## номинальному N при недоборе был бы занижен — прогон 8 этим и был испорчен.
func _check_calls(r: ProbeReport, mode) -> bool:
	var miss: Array[String] = []
	for ladder in reps[mode]:
		for n in POINTS:
			if int(ladder[n]["calls"]) != n:
				miss.append("N=%d→%d" % [n, ladder[n]["calls"]])
	if miss.is_empty():
		r.pass_("L4 гейт счётчика, MSAA %s: все %d точек дали ровно N отрисовок" % [
				NAMES[mode], POINTS.size() * reps[mode].size()])
		return true
	r.fail("L4 гейт счётчика, MSAA %s: расхождение %s — наклон недостоверен" % [NAMES[mode], ", ".join(miss)])
	return false


func _slope(r: ProbeReport, mode, gate_ok: bool) -> void:
	var n_hi: int = POINTS[POINTS.size() - 1]
	var gpu_us: Array[float] = []
	var cpu_us: Array[float] = []
	var base: Array[float] = []
	for ladder in reps[mode]:
		gpu_us.append((ladder[n_hi]["gpu"] - ladder[0]["gpu"]) * 1000.0 / n_hi)
		cpu_us.append((ladder[n_hi]["cpu"] - ladder[0]["cpu"]) * 1000.0 / n_hi)
		base.append(ladder[0]["gpu"])
	var g := _mean(gpu_us)
	var spread := absf(gpu_us[0] - gpu_us[1]) if gpu_us.size() >= 2 else NAN
	results[mode] = {"gpu_us": g, "cpu_us": _mean(cpu_us), "spread_us": spread,
			"base_gpu": _mean(base), "base_list": base}
	if not gate_ok:
		r.unkn("L4 наклон MSAA %s: гейт счётчика не пройден" % NAMES[mode])
		return
	r.pass_("L4 наклон MSAA %s: GPU **%.3f мкс/вызов** (повторы %s, разброс %.3f), CPU %.3f мкс/вызов — связывает %s" % [
			NAMES[mode], g, str(gpu_us), spread, results[mode]["cpu_us"],
			"GPU" if g >= results[mode]["cpu_us"] else "CPU"])


## База пустого кадра под каждым режимом. Прогон 10 не мерил пустой кадр с MSAA.
func _check_base(r: ProbeReport, gates: Dictionary) -> void:
	var a: Dictionary = results.get(MODES[0], {})
	var b: Dictionary = results.get(MODES[1], {})
	if a.is_empty() or b.is_empty():
		r.unkn("L4 база пустого кадра: не посчитана")
		return
	var spread := maxf(_range(a["base_list"]), _range(b["base_list"]))
	var diff: float = b["base_gpu"] - a["base_gpu"]
	r.pass_("L4 база пустого кадра: off %.3f мс, 2x %.3f мс, разница %+.3f при разбросе %.3f — %s" % [
			a["base_gpu"], b["base_gpu"], diff, spread,
			"ЗНАЧИМО" if absf(diff) > spread * 2.0 else "в шуме"])


## Главный вопрос: цена вызова под 2x отличается от off? Порог — вдвое больше
## разброса повторов, как во всех фазах.
func _compare(r: ProbeReport, gates: Dictionary) -> void:
	if not (gates[MODES[0]] and gates[MODES[1]]):
		r.unkn("L4 сравнение наклонов: гейт счётчика не пройден")
		return
	var a: Dictionary = results[MODES[0]]
	var b: Dictionary = results[MODES[1]]
	var spread := maxf(a["spread_us"], b["spread_us"])
	var diff: float = b["gpu_us"] - a["gpu_us"]
	var ratio: float = b["gpu_us"] / a["gpu_us"] if a["gpu_us"] > 0.0 else NAN
	var verdict: String
	if absf(diff) <= spread * 2.0:
		# Куда тогда делся эффект прогона 10 — не вывод этой строки: на то есть
		# отдельная проверка базы пустого кадра выше.
		verdict = "в шуме — цена вызова от MSAA не отличима"
	elif diff < 0.0:
		verdict = "ЗНАЧИМО ДЕШЕВЛЕ под 2x — удешевление вызова воспроизведено на лестнице"
	else:
		verdict = "ЗНАЧИМО ДОРОЖЕ под 2x — пункт 6 ADR-0003 пересматривается"
	r.pass_("L4 сравнение наклонов: off %.3f, 2x %.3f мкс/вызов, разница %+.3f (отношение %.2f) при разбросе %.3f — %s" % [
			a["gpu_us"], b["gpu_us"], diff, ratio, spread, verdict])


## Доставка на верхней точке: промахи по бюджету под каждым режимом.
func _delivery(r: ProbeReport) -> void:
	var n_hi: int = POINTS[POINTS.size() - 1]
	var parts: PackedStringArray = []
	var total_over := 0
	for m in MODES:
		var over := 0
		var fps: Array[float] = []
		for ladder in reps[m]:
			over += int(ladder[n_hi]["over"])
			fps.append(ladder[n_hi]["fps"])
		total_over += over
		parts.append("%s: %s к/с, сверх бюджета %d" % [NAMES[m], str(fps), over])
	if total_over == 0:
		r.pass_("L4 доставка на N=%d: %s — промахов нет" % [n_hi, "; ".join(parts)])
	else:
		r.fail("L4 доставка на N=%d: %s" % [n_hi, "; ".join(parts)])


## Контроль: наклон off обязан совпасть с наклоном C–D того же прогона.
func _control(r: ProbeReport, gates: Dictionary, cd_gpu_us: float) -> void:
	if not gates[MODES[0]]:
		r.unkn("L4 контроль с C–D: гейт счётчика off не пройден")
		return
	if is_nan(cd_gpu_us) or cd_gpu_us <= 0.0:
		r.unkn("L4 контроль с C–D: наклон C–D не посчитан")
		return
	var off_us: float = results[MODES[0]]["gpu_us"]
	var rel := absf(off_us - cd_gpu_us) / cd_gpu_us
	if rel <= CONTROL_TOLERANCE:
		r.pass_("L4 контроль с C–D: off %.3f против C–D %.3f мкс/вызов, расхождение %.1f%% в пределах дрейфа %.0f%% — фаза меряет то же, что C–D" % [
				off_us, cd_gpu_us, rel * 100.0, CONTROL_TOLERANCE * 100.0])
	else:
		r.fail("L4 контроль с C–D: off %.3f против C–D %.3f мкс/вызов, расхождение %.1f%% больше дрейфа %.0f%% — фаза меряет не то, что C–D" % [
				off_us, cd_gpu_us, rel * 100.0, CONTROL_TOLERANCE * 100.0])


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
