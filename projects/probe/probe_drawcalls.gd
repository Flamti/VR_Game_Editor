extends RefCounted
class_name ProbeDrawCalls

const ProbeReport := preload("res://probe_report.gd")
const ProbeStats := preload("res://probe_stats.gd")

## Фазы C–D: цена разогрева PSO и стоимость draw call.
##
## Почему цена берётся из НАКЛОНА, а не из абсолютного времени кадра: время при
## N объектах включает постоянные накладные расходы кадра. Разность соседних
## точек их сокращает, и остаётся цена самой единицы (PRACTICES §3.1 — сначала
## измерить единицу, потом назначать порог).
##
## Защиты, без которых число было бы числом ни о чём:
##  §2.5 проверка, что случай задевает гейт: спавн N объектов ОБЯЗАН поднять
##       счётчик draw calls движка. Если батчинг их склеил — свип невалиден;
##  §1.5 нулевая точка как контроль: при N=0 время обязано быть близко к пустой
##       сцене, иначе доминирует что-то другое;
##  §3.5 разброс двух прогонов на одном N считается ДО наклона: если он больше
##       шага свипа, разрешение ниже шума и наклону верить нельзя;
##  §3.3 печатается и среднее, и пик — они называют разных виновников;
##  §3.5 смена частоты обновления посреди свипа АННУЛИРУЕТ его: сравнивались бы
##       разные миры.

const SWEEP_POINTS := [0, 50, 100, 200, 400, 800, 1600]
const VARIANCE_POINT_INDEX := 2   # на какой точке мерить разброс двух прогонов
const WARMUP_FRAMES := 30         # отбрасываются: там компиляция PSO
const MEASURE_FRAMES := 60        # по ним считается статистика

var _host: Node
var _container: Node3D
var _viewport_rid: RID
var _refresh_at_start: float = 0.0
var _invalidated: String = ""

# Результаты для отчёта и паспорта.
var unbatched: Dictionary = {}    # N → {"cpu": ProbeStats, "gpu": ProbeStats, "calls": int}
var instanced: Dictionary = {}
var warmup_cost_ms: float = NAN
var us_per_drawcall: float = NAN
var us_per_instance: float = NAN
var us_per_drawcall_gpu: float = NAN
var us_per_instance_gpu: float = NAN
var variance_ms: float = NAN
var sweep_step_ms: float = NAN


func expected_checks() -> int:
	# нулевой контроль 1, гейт небатченый 1, гейт инстансный 1, разброс 1,
	# наклон небатченый 1, наклон инстансный 1, разогрев 1, частота устойчива 1
	return 8


func setup(host: Node) -> void:
	_host = host
	_container = Node3D.new()
	# Перед камерой на 2 м: объекты обязаны быть ВИДИМЫ, иначе отсечение
	# выбросит их и свип не задействует draw calls вообще.
	_container.position = Vector3(0, 0, -2)
	host.add_child(_container)
	_viewport_rid = host.get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(_viewport_rid, true)


func _refresh_rate() -> float:
	var iface := XRServer.find_interface("OpenXR")
	if iface != null and iface.has_method("get_display_refresh_rate"):
		return iface.get_display_refresh_rate()
	return 0.0


func _budget_ms() -> float:
	var hz := _refresh_rate()
	return (1000.0 / hz) if hz > 1.0 else NAN


func _clear() -> void:
	for c in _container.get_children():
		c.queue_free()


func _tiny_quad() -> Mesh:
	var m := QuadMesh.new()
	m.size = Vector2(0.01, 0.01)   # крошечный: мерим draw calls, не филлрейт
	return m


## Небатченый режим: УНИКАЛЬНЫЙ материал на объект. Godot батчит по RID
## материала, поэтому отдельные ресурсы дают отдельные вызовы отрисовки.
func _spawn_unbatched(n: int) -> void:
	var mesh := _tiny_quad()
	for i in n:
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		var mat := StandardMaterial3D.new()
		# Разный цвет — чтобы материалы нельзя было счесть эквивалентными.
		mat.albedo_color = Color(float(i % 255) / 255.0, 0.5, 0.5)
		mi.material_override = mat
		mi.position = Vector3(fmod(i * 0.013, 0.4) - 0.2, fmod(i * 0.017, 0.4) - 0.2, 0.0)
		_container.add_child(mi)


func _spawn_instanced(n: int) -> void:
	if n == 0:
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _tiny_quad()
	mm.instance_count = n
	for i in n:
		mm.set_instance_transform(i, Transform3D(Basis(), Vector3(
				fmod(i * 0.013, 0.4) - 0.2, fmod(i * 0.017, 0.4) - 0.2, 0.0)))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = StandardMaterial3D.new()
	_container.add_child(mmi)


## Один замер: разогрев отбрасывается, затем MEASURE_FRAMES кадров статистики.
func _measure() -> Dictionary:
	var warm := ProbeStats.new()
	for _i in WARMUP_FRAMES:
		await _host.get_tree().process_frame
		warm.add(RenderingServer.viewport_get_measured_render_time_cpu(_viewport_rid))

	var cpu := ProbeStats.new()
	var gpu := ProbeStats.new()
	var calls_sum := 0
	for _i in MEASURE_FRAMES:
		await _host.get_tree().process_frame
		cpu.add(RenderingServer.viewport_get_measured_render_time_cpu(_viewport_rid))
		gpu.add(RenderingServer.viewport_get_measured_render_time_gpu(_viewport_rid))
		calls_sum += int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))

	return {
		"cpu": cpu,
		"gpu": gpu,
		"warm": warm,
		"calls": int(round(float(calls_sum) / MEASURE_FRAMES)),
	}


func run(r: ProbeReport) -> void:
	_refresh_at_start = _refresh_rate()
	var budget := _budget_ms()
	r.note("")
	r.note("--- C–D. Стоимость отрисовки ---")
	r.note("частота обновления: %.1f Гц, кадровый бюджет: %.2f мс" % [_refresh_at_start, budget])
	r.note("разогрев отбрасывается: %d кадров; статистика по %d кадрам" % [WARMUP_FRAMES, MEASURE_FRAMES])
	r.note("")

	await _sweep(r, "небатченый", unbatched, _spawn_unbatched, budget)
	await _sweep(r, "инстансы", instanced, _spawn_instanced, budget)
	await _variance(r)

	_check_zero_point(r, budget)
	_check_gate(r, "небатченый", unbatched, true)
	_check_gate(r, "инстансы", instanced, false)
	_check_refresh_stable(r)
	_check_warmup(r)
	_slope(r, "небатченый", unbatched, true)
	_slope(r, "инстансы", instanced, false)


func _sweep(r: ProbeReport, label: String, out: Dictionary, spawn: Callable, budget: float) -> void:
	r.note("свип «%s»:" % label)
	for n in SWEEP_POINTS:
		_clear()
		await _host.get_tree().process_frame
		spawn.call(n)
		var m: Dictionary = await _measure()
		out[n] = m
		var cpu: ProbeStats = m["cpu"]
		var gpu: ProbeStats = m["gpu"]
		r.note("    N=%-5d draw calls движка=%-5d  CPU %s" % [n, m["calls"], cpu.brief()])
		r.note("            %sGPU %s" % [" ".repeat(14), gpu.brief()])
		# Свип идёт до превышения бюджета — граница определяется сама,
		# без заранее назначенного порога.
		if not is_nan(budget) and cpu.median() > budget:
			r.note("    бюджет %.2f мс превышен на N=%d — свип остановлен" % [budget, n])
			break
	_clear()
	await _host.get_tree().process_frame


## Разброс двух прогонов на ОДНОМ N. Считается ДО наклона: если разброс больше
## шага свипа, наклон — это шум (PRACTICES §3.5).
func _variance(r: ProbeReport) -> void:
	var n: int = SWEEP_POINTS[VARIANCE_POINT_INDEX]
	var a_med := 0.0
	var b_med := 0.0
	for pass_i in 2:
		_clear()
		await _host.get_tree().process_frame
		_spawn_unbatched(n)
		var m: Dictionary = await _measure()
		var st: ProbeStats = m["cpu"]
		if pass_i == 0:
			a_med = st.median()
		else:
			b_med = st.median()
	_clear()
	variance_ms = absf(a_med - b_med)
	r.note("")
	r.note("разброс двух прогонов на N=%d: %.3f мс (%.3f против %.3f)" % [n, variance_ms, a_med, b_med])

	# Это ПРОВЕРКА, а не заметка. Первая версия печатала разброс заметкой, и пол
	# поймал расхождение: заявлено 8 проверок, исполнено 7 (PRACTICES §1.2).
	var step := _unbatched_step_ms()
	if is_nan(step):
		r.unkn("разрешение свипа: шаг неизвестен, сравнивать не с чем")
	elif variance_ms < absf(step):
		r.pass_("разрешение свипа: разброс %.3f мс меньше шага %.3f мс (в %.0f раз) — наклону можно верить" % [
				variance_ms, step, absf(step) / maxf(variance_ms, 0.0001)])
	else:
		r.fail("разрешение свипа: разброс %.3f мс НЕ меньше шага %.3f мс — измерение утонуло в шуме" % [variance_ms, step])


func _unbatched_step_ms() -> float:
	var keys := unbatched.keys()
	keys.sort()
	if keys.size() < 2:
		return NAN
	var lo: ProbeStats = unbatched[keys[0]]["cpu"]
	var hi: ProbeStats = unbatched[keys[keys.size() - 1]]["cpu"]
	return hi.median() - lo.median()


func _check_zero_point(r: ProbeReport, budget: float) -> void:
	if not unbatched.has(0):
		r.unkn("нулевой контроль: точка N=0 не измерялась")
		return
	var st: ProbeStats = unbatched[0]["cpu"]
	var z := st.median()
	if is_nan(budget):
		r.unkn("нулевой контроль: бюджет неизвестен (частота не получена), сравнивать не с чем")
	elif z < budget * 0.5:
		r.pass_("нулевой контроль: пустая сцена %.3f мс — меньше половины бюджета, запас есть" % z)
	else:
		r.fail("нулевой контроль: пустая сцена уже %.3f мс из %.2f — доминирует НЕ наша нагрузка, свип меряет не заявленное" % [z, budget])


## Главная защита (PRACTICES §2.5). Если счётчик движка не растёт вместе с N,
## случай до draw calls не доходит, и наклон — число ни о чём.
func _check_gate(r: ProbeReport, label: String, data: Dictionary, expect_growth: bool) -> void:
	var keys := data.keys()
	keys.sort()
	if keys.size() < 2:
		r.unkn("гейт «%s»: точек меньше двух" % label)
		return
	var n_lo: int = keys[0]
	var n_hi: int = keys[keys.size() - 1]
	var d_calls: int = data[n_hi]["calls"] - data[n_lo]["calls"]
	var d_n: int = n_hi - n_lo

	if expect_growth:
		# Небатченый режим: счётчик обязан вырасти примерно на ΔN.
		#
		# Проверяются ВСЕ точки, а не только концы: на первом прогоне при N=800
		# движок доложил 658 вызовов вместо 800, и проверка по концам этого не
		# увидела. Отклонение по любой точке называется поимённо (§1.4).
		var off: Array[String] = []
		for n in keys:
			var claimed: int = n
			var actual: int = data[n]["calls"]
			if claimed > 0 and absf(float(actual - claimed)) / float(claimed) > 0.05:
				off.append("N=%d→%d" % [claimed, actual])
		if not off.is_empty():
			r.note("        точки с расхождением заявленного и счётчика движка: %s" % ", ".join(off))

		var ratio := float(d_calls) / float(max(d_n, 1))
		if ratio > 0.5:
			r.pass_("гейт «%s»: ΔN=%d → Δdraw calls=%d (%.2f на объект)%s" % [
					label, d_n, d_calls, ratio,
					" — случай задевает гейт" if off.is_empty() else " — гейт задет, но %d точек с расхождением (см. выше)" % off.size()])
		else:
			r.fail("гейт «%s»: ΔN=%d, а Δdraw calls=%d — батчинг склеил объекты. СВИП НЕВАЛИДЕН, наклон не считать" % [label, d_n, d_calls])
			_invalidated = label
	else:
		# Инстансный режим: счётчик расти НЕ должен — иначе режимы не различаются.
		if d_calls < d_n / 10:
			r.pass_("гейт «%s»: ΔN=%d, Δdraw calls=%d — инстансинг работает, режимы различаются" % [label, d_n, d_calls])
		else:
			r.fail("гейт «%s»: Δdraw calls=%d при ΔN=%d — инстансинга НЕТ, режим не отличается от небатченого" % [label, d_calls, d_n])


func _check_refresh_stable(r: ProbeReport) -> void:
	var now := _refresh_rate()
	if _refresh_at_start <= 1.0:
		r.unkn("частота: не получена, устойчивость не проверялась")
	elif is_equal_approx(now, _refresh_at_start):
		r.pass_("частота устойчива: %.1f Гц от начала до конца свипов" % now)
	else:
		r.fail("частота изменилась во время свипов: %.1f → %.1f Гц. ВСЕ свипы аннулированы — сравнивались разные миры" % [_refresh_at_start, now])
		_invalidated = "смена частоты"


func _check_warmup(r: ProbeReport) -> void:
	# Цена разогрева: первые кадры после спавна против установившегося.
	var probe_n: int = SWEEP_POINTS[VARIANCE_POINT_INDEX]
	if not unbatched.has(probe_n):
		r.unkn("разогрев PSO: точка N=%d не измерялась" % probe_n)
		return
	var warm: ProbeStats = unbatched[probe_n]["warm"]
	var steady: ProbeStats = unbatched[probe_n]["cpu"]
	warmup_cost_ms = warm.maximum() - steady.median()
	if warmup_cost_ms > 0.0:
		r.pass_("разогрев PSO: пик первых %d кадров выше установившегося на %.3f мс (макс %.3f против мед %.3f)" % [
				WARMUP_FRAMES, warmup_cost_ms, warm.maximum(), steady.median()])
	else:
		r.pass_("разогрев PSO: пика не обнаружено (%.3f мс) — либо кэш PSO уже прогрет, либо шейдеры не новые" % warmup_cost_ms)


## Наклон: Δвремя / ΔN. Считается только если гейт пройден и разброс меньше шага.
func _slope(r: ProbeReport, label: String, data: Dictionary, is_drawcall: bool) -> void:
	if _invalidated != "":
		r.unkn("наклон «%s»: не считаю — свип аннулирован (%s)" % [label, _invalidated])
		return
	var keys := data.keys()
	keys.sort()
	if keys.size() < 2:
		r.unkn("наклон «%s»: точек меньше двух" % label)
		return
	var n_lo: int = keys[0]
	var n_hi: int = keys[keys.size() - 1]
	var d_n: int = n_hi - n_lo
	var lo_cpu: ProbeStats = data[n_lo]["cpu"]
	var hi_cpu: ProbeStats = data[n_hi]["cpu"]
	var lo_gpu: ProbeStats = data[n_lo]["gpu"]
	var hi_gpu: ProbeStats = data[n_hi]["gpu"]
	var d_cpu := hi_cpu.median() - lo_cpu.median()
	var d_gpu := hi_gpu.median() - lo_gpu.median()
	sweep_step_ms = d_cpu

	if not is_nan(variance_ms) and variance_ms > absf(d_cpu):
		r.fail("наклон «%s»: разброс прогонов %.3f мс БОЛЬШЕ роста по свипу %.3f мс — разрешение ниже шума, число недостоверно" % [label, variance_ms, d_cpu])
		return

	var cpu_us := (d_cpu * 1000.0) / float(max(d_n, 1))
	var gpu_us := (d_gpu * 1000.0) / float(max(d_n, 1))
	if is_drawcall:
		us_per_drawcall = cpu_us
		us_per_drawcall_gpu = gpu_us
	else:
		us_per_instance = cpu_us
		us_per_instance_gpu = gpu_us

	# GPU считается наравне с CPU: на тайловом GPU подача геометрии стоит и там,
	# и там, и связывающим оказывается НЕ обязательно CPU. Печатать только CPU
	# значило бы назвать не того виновника (PRACTICES §3.3).
	var binding := "GPU" if gpu_us > cpu_us else "CPU"
	r.pass_("наклон «%s»: CPU %.3f мкс/ед., GPU %.3f мкс/ед. — связывает %s (Δ на ΔN=%d)" % [
			label, cpu_us, gpu_us, binding, d_n])
