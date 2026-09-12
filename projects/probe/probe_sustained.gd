extends RefCounted
class_name ProbeSustained

const ProbeReport := preload("res://probe_report.gd")
const ProbeStats := preload("res://probe_stats.gd")

## Фаза E: сколько держится целевой кадровый бюджет до вмешательства ОС.
##
## Прогон длинный (по решению владельца 15–20 минут) и требует НАДЕТОГО шлема:
## датчик присутствия иначе усыпит сессию, и мерить будет нечего.
##
## Данные пишутся раз в секунду СРАЗУ в лог и в файл, а не отдаются в конце.
## Если сессию прервут на двенадцатой минуте, одиннадцать минут должны
## остаться. Прерванный прогон обязан выглядеть прерванным, а не «измеренным».
##
## §3.2: если частота не изменилась, вывод — «троттлинг не наблюдался за N
## минут», а НЕ «троттлинга нет». Это разные утверждения.

const DEFAULT_MINUTES := 18.0
const SAMPLE_PERIOD_S := 1.0
const LOAD_FRACTION := 0.75    # держим нагрузку на ~75% бюджета

var _host: Node
var _container: Node3D
var _viewport_rid: RID
var _log_path := "user://sustained.log"

var start_refresh: float = 0.0
var first_drop_s: float = -1.0
var first_drop_to: float = 0.0
var ran_seconds: float = 0.0
var planned_seconds: float = 0.0
var interrupted: bool = false
var load_n: int = 0
var cpu_overall: ProbeStats
var gpu_overall: ProbeStats


func expected_checks() -> int:
	# нагрузка подобрана 1, прогон дошёл до конца 1, вердикт по троттлингу 1,
	# бюджет удержан 1
	return 4


func setup(host: Node, container_parent: Node) -> void:
	_host = host
	_container = Node3D.new()
	_container.position = Vector3(0, 0, -2)
	container_parent.add_child(_container)
	_viewport_rid = host.get_viewport().get_viewport_rid()
	cpu_overall = ProbeStats.new()
	gpu_overall = ProbeStats.new()


func _refresh_rate() -> float:
	var iface := XRServer.find_interface("OpenXR")
	if iface != null and iface.has_method("get_display_refresh_rate"):
		return iface.get_display_refresh_rate()
	return 0.0


## Нагрузка берётся из свипа, а не назначается: N, дающее ~75% бюджета.
func _pick_load(sweep: Dictionary, budget_ms: float) -> int:
	if is_nan(budget_ms) or sweep.is_empty():
		return 0
	var target := budget_ms * LOAD_FRACTION
	var keys := sweep.keys()
	keys.sort()
	var best: int = keys[0]
	for n in keys:
		# Нагрузка подбирается по СВЯЗЫВАЮЩЕМУ ограничению, а не по CPU.
		# Первая версия смотрела только на CPU и чуть не выбрала N, где CPU
		# свободен, а GPU уже у потолка: нагрузка оказалась бы не 75% бюджета,
		# а на грани — и прогон мерил бы срыв, а не удержание.
		var cpu_st: ProbeStats = sweep[n]["cpu"]
		var gpu_st: ProbeStats = sweep[n]["gpu"]
		if maxf(cpu_st.median(), gpu_st.median()) <= target:
			best = n
	return best


func run(r: ProbeReport, sweep: Dictionary, minutes: float = DEFAULT_MINUTES) -> void:
	start_refresh = _refresh_rate()
	var budget_ms := (1000.0 / start_refresh) if start_refresh > 1.0 else NAN
	planned_seconds = minutes * 60.0
	load_n = _pick_load(sweep, budget_ms)

	r.note("")
	r.note("--- E. Длинный прогон: троттлинг ---")
	r.note("план: %.0f минут, выборка раз в %.0f с, нагрузка N=%d (~%d%% бюджета)" % [
			minutes, SAMPLE_PERIOD_S, load_n, int(LOAD_FRACTION * 100)])
	r.note("частота на старте: %.1f Гц, бюджет %.2f мс" % [start_refresh, budget_ms])
	r.note("ТРЕБУЕТСЯ НАДЕТЫЙ ШЛЕМ: иначе датчик присутствия усыпит сессию")
	r.note("")

	if load_n > 0:
		_spawn(load_n)
		r.pass_("нагрузка подобрана из свипа: N=%d" % load_n)
	else:
		r.unkn("нагрузка не подобрана (свип пуст или частота неизвестна) — прогон идёт без нагрузки")

	var f := FileAccess.open(_log_path, FileAccess.WRITE)
	if f != null:
		f.store_line("# секунда\tчастота\tCPU мс\tGPU мс\tdraw calls")

	var t0 := Time.get_ticks_msec()
	var next_sample := 0.0
	var current_refresh := start_refresh

	while true:
		await _host.get_tree().process_frame
		ran_seconds = (Time.get_ticks_msec() - t0) / 1000.0
		if ran_seconds >= planned_seconds:
			break
		if ran_seconds < next_sample:
			continue
		next_sample = ran_seconds + SAMPLE_PERIOD_S

		var cpu := RenderingServer.viewport_get_measured_render_time_cpu(_viewport_rid)
		var gpu := RenderingServer.viewport_get_measured_render_time_gpu(_viewport_rid)
		var calls := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		cpu_overall.add(cpu)
		gpu_overall.add(gpu)

		var hz := _refresh_rate()
		if first_drop_s < 0.0 and hz > 1.0 and start_refresh > 1.0 and not is_equal_approx(hz, start_refresh):
			first_drop_s = ran_seconds
			first_drop_to = hz
			# Момент смены — то самое искомое число. В лог немедленно.
			r.note("!!! СМЕНА ЧАСТОТЫ на %.0f с: %.1f → %.1f Гц" % [ran_seconds, start_refresh, hz])
		current_refresh = hz

		var line := "%.0f\t%.1f\t%.3f\t%.3f\t%d" % [ran_seconds, hz, cpu, gpu, calls]
		if f != null:
			f.store_line(line)
			f.flush()   # немедленно на диск: прерванный прогон не должен потерять данные
		# В лог — реже, чтобы не утопить logcat: каждые 15 с.
		if int(ran_seconds) % 15 == 0:
			r.note("    %s" % line)

	if f != null:
		f.close()

	interrupted = ran_seconds < planned_seconds * 0.98
	_verdict(r, budget_ms, current_refresh)


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


func _verdict(r: ProbeReport, budget_ms: float, final_refresh: float) -> void:
	r.note("")
	r.note("итог прогона: %.0f с из %.0f запланированных" % [ran_seconds, planned_seconds])
	r.note("CPU за прогон: %s" % cpu_overall.brief())
	r.note("GPU за прогон: %s" % gpu_overall.brief())

	if interrupted:
		r.fail("прогон ПРЕРВАН на %.0f с из %.0f — вывод о троттлинге делать нельзя (шлем сняли? сессия умерла?)" % [ran_seconds, planned_seconds])
	else:
		r.pass_("прогон дошёл до конца: %.0f с" % ran_seconds)

	if first_drop_s >= 0.0:
		r.pass_("троттлинг НАБЛЮДАЛСЯ: частота %.1f → %.1f Гц на %.0f-й секунде (%.1f мин)" % [
				start_refresh, first_drop_to, first_drop_s, first_drop_s / 60.0])
	elif interrupted:
		r.unkn("троттлинг: прогон прерван на %.0f с, вопрос открыт" % ran_seconds)
	else:
		# §3.2: «не наблюдался за N минут» — НЕ то же, что «его нет».
		r.pass_("троттлинг НЕ НАБЛЮДАЛСЯ за %.1f мин при N=%d. Это не значит, что его нет — только что за это время и под этой нагрузкой он не наступил" % [
				ran_seconds / 60.0, load_n])

	if is_nan(budget_ms):
		r.unkn("бюджет: частота неизвестна, удержание не проверить")
	elif cpu_overall.count() == 0:
		r.unkn("бюджет: ни одной выборки")
	else:
		# Смотреть надо на СВЯЗЫВАЮЩЕЕ ограничение. Первая версия сравнивала
		# только CPU и доложила бы «бюджет удержан» даже при GPU у потолка —
		# третий случай той же CPU-центричности за одну сессию.
		var p95_cpu := cpu_overall.percentile(0.95)
		var p95_gpu := gpu_overall.percentile(0.95)
		var binding := "GPU" if p95_gpu > p95_cpu else "CPU"
		var worst := maxf(p95_cpu, p95_gpu)
		if worst <= budget_ms:
			r.pass_("бюджет удержан: p95 CPU %.3f / GPU %.3f мс, связывает %s — %.0f%% бюджета %.2f мс" % [
					p95_cpu, p95_gpu, binding, worst / budget_ms * 100.0, budget_ms])
		else:
			r.fail("бюджет НЕ удержан: p95 %s %.3f мс против %.2f мс" % [binding, worst, budget_ms])
