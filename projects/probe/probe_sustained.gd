extends RefCounted
class_name ProbeSustained

const ProbeReport := preload("res://probe_report.gd")
const ProbeStats := preload("res://probe_stats.gd")
const ProbeBudget := preload("res://probe_budget.gd")
const ProbeHwStat := preload("res://probe_hwstat.gd")

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
## Четверти прогона: по ним считается дрейф. Одна общая статистика дрейф
## СКРЫВАЕТ — среднее не различает ровный расход и направленный рост (§3.3).
var gpu_quarters: Array[ProbeStats] = []
## Частота GPU по четвертям. Прямой сигнал троттлинга: при перегреве ядро
## сбрасывает клок, и это видно числом, а не через косвенный дрейф времени
## кадра. Дрейф остаётся — но теперь у него есть напарник с известным смыслом.
var clk_quarters: Array[ProbeStats] = []
var clk_overall: ProbeStats
var residency_start: PackedInt64Array = PackedInt64Array()


func expected_checks() -> int:
	# нагрузка 1, прогон дошёл до конца 1, вердикт по частоте 1, бюджет 1,
	# дрейф времени кадра 1, набор доступных частот 1, просадка клока GPU 1,
	# резиденция за прогон 1
	return 8


func setup(host: Node, container_parent: Node) -> void:
	_host = host
	_container = Node3D.new()
	_container.position = Vector3(0, 0, -2)
	container_parent.add_child(_container)
	_viewport_rid = host.get_viewport().get_viewport_rid()
	cpu_overall = ProbeStats.new()
	gpu_overall = ProbeStats.new()
	clk_overall = ProbeStats.new()
	for _i in 4:
		gpu_quarters.append(ProbeStats.new())
		clk_quarters.append(ProbeStats.new())


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
	start_refresh = ProbeBudget.current_hz()
	var budget_ms := ProbeBudget.ms_for_hz(start_refresh)
	planned_seconds = minutes * 60.0
	load_n = _pick_load(sweep, budget_ms)

	r.note("")
	r.note("--- E. Длинный прогон: троттлинг ---")
	r.note("план: %.0f минут, выборка раз в %.0f с, нагрузка N=%d (~%d%% бюджета)" % [
			minutes, SAMPLE_PERIOD_S, load_n, int(LOAD_FRACTION * 100)])
	r.note("частота на старте: %.1f Гц, бюджет %.2f мс" % [start_refresh, budget_ms])
	_report_available_rates(r)
	r.note("ТРЕБУЕТСЯ НАДЕТЫЙ ШЛЕМ: иначе датчик присутствия усыпит сессию")
	r.note("")

	if load_n > 0:
		_spawn(load_n)
		r.pass_("нагрузка подобрана из свипа: N=%d" % load_n)
	else:
		r.unkn("нагрузка не подобрана (свип пуст или частота неизвестна) — прогон идёт без нагрузки")

	var f := FileAccess.open(_log_path, FileAccess.WRITE)
	if f != null:
		f.store_line("# секунда\tчастота\tCPU мс\tGPU мс\tdraw calls\tклок GPU Гц")

	residency_start = ProbeHwStat.clock_stats()
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
		if calls > 0:
			# Пустые выборки (ноль отрисовок) в дрейф не берём: они занизили бы
			# четверть, в которую попали. На прогоне 2026-09-12 таких было 9.
			var q := clampi(int(ran_seconds / maxf(planned_seconds / 4.0, 1.0)), 0, 3)
			gpu_quarters[q].add(gpu)

		var clk := ProbeHwStat.gpu_clock_hz()
		if clk > 0:
			clk_overall.add(float(clk))
			var qc := clampi(int(ran_seconds / maxf(planned_seconds / 4.0, 1.0)), 0, 3)
			clk_quarters[qc].add(float(clk))

		var hz := ProbeBudget.current_hz()
		if first_drop_s < 0.0 and hz > 1.0 and start_refresh > 1.0 and not ProbeBudget.same_hz(hz, start_refresh):
			first_drop_s = ran_seconds
			first_drop_to = hz
			# Момент смены — то самое искомое число. В лог немедленно.
			r.note("!!! СМЕНА ЧАСТОТЫ на %.0f с: %.1f → %.1f Гц" % [ran_seconds, start_refresh, hz])
		current_refresh = hz

		var line := "%.0f\t%.1f\t%.3f\t%.3f\t%d\t%d" % [ran_seconds, hz, cpu, gpu, calls, clk]
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
	_check_drift(r)
	_check_clock_drop(r)
	_check_residency(r)


## Набор доступных частот. Без него нельзя судить, чего стоит слежение за
## сменой частоты: если прогон идёт на САМОЙ НИЗКОЙ доступной, сбрасывать
## некуда, и проверка «частота не менялась» близка к пустой.
##
## Именно это и случилось в первом длинном прогоне: он шёл на 72 Гц, а вывод
## «троттлинг не наблюдался» опирался на смену частоты. Настоящим сигналом
## оказался дрейф времени кадра — см. _check_drift().
func _report_available_rates(r: ProbeReport) -> void:
	if not ProbeBudget.has_rate_api():
		r.unkn("доступные частоты: API недоступен, судить о запасе вниз нельзя")
		return
	var rates: Array = ProbeBudget.available_hz()
	if rates.is_empty():
		r.unkn("доступные частоты: рантайм вернул пустой список")
		return
	var lo := INF
	for v in rates:
		lo = minf(lo, float(v))
	r.note("доступные частоты: %s" % str(rates))
	if start_refresh > 1.0 and ProbeBudget.same_hz(start_refresh, lo):
		# Не отказ проекта, а ограничение измерения — но назвать обязательно.
		r.pass_("запас вниз: прогон идёт на САМОЙ НИЗКОЙ доступной частоте %.1f Гц — слежение за сменой частоты почти ничего не покажет, вывод строится на дрейфе времени кадра" % lo)
	else:
		r.pass_("запас вниз: есть, минимальная доступная %.1f Гц против текущей %.1f Гц" % [lo, start_refresh])


## Дрейф времени кадра — ПРЯМОЙ признак троттлинга тактовых частот: та же
## нагрузка начинает считаться дольше. Сравниваются первая и последняя четверти
## прогона, чтобы направленный рост отличался от шума (PRACTICES §3.5).
func _check_drift(r: ProbeReport) -> void:
	var n := gpu_quarters.size()
	if n < 4 or gpu_quarters[0].count() == 0 or gpu_quarters[3].count() == 0:
		r.unkn("дрейф времени кадра: выборок на четверти не хватило")
		return
	var first: float = gpu_quarters[0].mean()
	var last: float = gpu_quarters[3].mean()

	# Сравнивается ХУДШАЯ четверть с первой, а не последняя с первой.
	#
	# Первая версия смотрела first→last и на прогоне 18:05 дала +2.2% при
	# фактической форме 10.588 → 10.991 → 11.047 → 10.817: рост в первые
	# семь минут, плато, затем спад. Метрика по концам такой горб НЕ ВИДИТ, и
	# её вердикт зависит от того, где прогон случайно закончился — обрыв на
	# 14-й минуте дал бы +3.3%. Худшая четверть отвечает на правильный вопрос:
	# «становилось ли хуже», а не «хуже ли стало к концу».
	var worst: float = first
	for q in gpu_quarters:
		worst = maxf(worst, q.mean())
	var rel := (worst - first) / maxf(first, 0.0001) * 100.0
	var rel_end := (last - first) / maxf(first, 0.0001) * 100.0

	r.note("дрейф по четвертям, GPU сред: %.3f → %.3f → %.3f → %.3f мс" % [
			gpu_quarters[0].mean(), gpu_quarters[1].mean(),
			gpu_quarters[2].mean(), gpu_quarters[3].mean()])
	r.note("    худшая четверть против первой: %+.1f%%; конец против начала: %+.1f%%" % [rel, rel_end])

	# Порог 5%. Измеренные значения: прогон 15:36 дал +0.2% по концам,
	# прогон 18:05 — +2.2% по концам и +4.3% по худшей четверти. То есть запас
	# до порога НЕ велик, и утверждать обратное нельзя: порог назначен по двум
	# прогонам, а не выведен из природы явления (PRACTICES §3.1).
	if rel < 5.0:
		r.pass_("дрейф времени кадра: худшая четверть %+.1f%% от первой — направленного роста нет, троттлинга тактовых частот не видно" % rel)
	else:
		r.fail("дрейф времени кадра: худшая четверть %+.1f%% от первой — нагрузка стала считаться дольше, ПОХОЖЕ НА ТРОТТЛИНГ" % rel)


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
		r.pass_("смена частоты НЕ зафиксирована за %.1f мин при N=%d. Слабый сигнал: если прогон шёл на минимальной доступной частоте, сбрасывать было некуда — судить по дрейфу времени кадра ниже" % [
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


## Просадка частоты GPU — ПРЯМОЙ признак троттлинга, в отличие от дрейфа
## времени кадра, который признак косвенный.
##
## Долг, который эта проверка закрывает: метрика дрейфа ни разу не краснела,
## её различающая способность не подтверждена, а порог 5% назначен по двум
## прогонам. У клока порог не назначается вовсе: сброс ступени виден сам.
func _check_clock_drop(r: ProbeReport) -> void:
	if clk_overall == null or clk_overall.count() == 0:
		r.unkn("клок GPU: ни одной выборки — sysfs недоступен, судить о троттлинге по частоте нечем")
		return
	if clk_quarters[0].count() == 0:
		r.unkn("клок GPU: первая четверть пуста, сравнивать не с чем")
		return

	var first := clk_quarters[0].mean()
	var worst := first
	var parts: Array[String] = []
	for q in clk_quarters:
		if q.count() > 0:
			worst = minf(worst, q.mean())
			parts.append("%.0f" % (q.mean() / 1000000.0))
		else:
			parts.append("—")
	var rel := (worst - first) / maxf(first, 1.0) * 100.0
	r.note("клок GPU по четвертям, МГц: %s (мин за прогон %.0f, макс %.0f)" % [
			" → ".join(parts), clk_overall.minimum() / 1000000.0, clk_overall.maximum() / 1000000.0])

	# Сравнивается ХУДШАЯ четверть с первой — по той же причине, что и в дрейфе:
	# вердикт не должен зависеть от того, где прогон случайно кончился.
	if rel > -5.0:
		r.pass_("клок GPU: худшая четверть %+.1f%% от первой — устойчивого сброса частоты нет" % rel)
	else:
		r.fail("клок GPU: худшая четверть %+.1f%% от первой (%.0f → %.0f МГц) — частота сброшена, ЭТО ТРОТТЛИНГ" % [
				rel, first / 1000000.0, worst / 1000000.0])


## Где прогон реально провёл время по ступеням частоты. Один сброс на дне в
## конце и ровная работа на потолке дают одинаковое среднее (§3.3).
func _check_residency(r: ProbeReport) -> void:
	var after := ProbeHwStat.clock_stats()
	var d := ProbeHwStat.residency_delta(residency_start, after)
	if not d.get("ok", false) or d["sum"] <= 0:
		r.unkn("резиденция частот за прогон: счётчики недоступны или не сдвинулись")
		return
	var hz := ProbeHwStat.available_hz()
	var t := ProbeHwStat.time_like_factor(d["sum"], ran_seconds * 1000.0)
	r.note("резиденция за прогон: %s" % ProbeHwStat.residency_brief(d["delta"], hz, d["sum"]))
	if not t["plausible"]:
		r.unkn("резиденция частот за прогон: шкала счётчика не времяподобна (%.1f на мс) — доли недостоверны" % t["per_ms"])
		return
	var w := ProbeHwStat.weighted_hz(d["delta"], hz, d["sum"])
	var top := float(hz[0]) if not hz.is_empty() else NAN
	for v in hz:
		top = maxf(top, float(v))
	r.pass_("резиденция за прогон: средневзвешенно %.0f МГц из потолка %.0f (%.0f%%), шкала в %s" % [
			w / 1000000.0, top / 1000000.0, w / maxf(top, 1.0) * 100.0, t["unit"]])
