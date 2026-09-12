extends RefCounted
class_name ProbeFreqMatrix

## Фаза M: одна и та же нагрузка на чередующихся частотах, внутри ОДНОГО прогона.
##
## Зачем именно так. Прогон 5 дал: на 120 Гц один draw call для GPU стоит
## 2.831 мкс против 5.34 на 72 Гц, но база пустой сцены при этом подорожала
## (2.500 → 3.130 мс), а CPU замедлился. Соблазн объявить это свойством частоты
## велик — и он неправомерен: числа 72 Гц сняты в прогонах 2–3, числа 120 Гц в
## прогоне 5. Разные сессии, разное тепловое состояние. А прогон 4 показал
## ИЗМЕРЕННЫЙ разогрев +6% за первые семь минут — эффект того же порядка.
##
## Матрица разделяет два объяснения тем, что проходит частоты ДВАЖДЫ в порядке
## 72 → 120 → 72 → 120:
##
##   от частоты — разница переворачивается вместе с порядком ступеней;
##   от прогрева — разница монотонна по времени и порядку не подчиняется.
##
## Плюс «канарейка»: одна и та же фиксированная нагрузка на каждой ступени.
## Она даёт дрейф отдельно от свипа — если поехала канарейка, поехало всё.
##
## Значимость не объявляется на глаз: две ступени на каждую частоту дают
## разброс ВНУТРИ частоты, и разница между частотами сравнивается с ним (§3.5).

const ProbeReport := preload("res://probe_report.gd")
const ProbeStats := preload("res://probe_stats.gd")
const ProbeBudget := preload("res://probe_budget.gd")
const ProbeWindow := preload("res://probe_window.gd")
const ProbeState := preload("res://probe_state.gd")
const ProbeHwStat := preload("res://probe_hwstat.gd")

## Ступени. Порядок с повтором — суть прибора, менять его нельзя, не поняв выше.
const STEPS := [72.0, 120.0, 72.0, 120.0]

## Точки свипа: концы дают наклон, середина показывает, что он прямой.
const SWEEP_POINTS := [0, 400, 1600]

## Канарейка — неизменная нагрузка на всех ступенях.
const CANARY_N := 400

## Частота, которой у устройства нет. Фальсификатор запроса: прибор обязан
## УВИДЕТЬ отказ, а не принять неизменившуюся частоту за успех.
##
## Здесь стояло 144 Гц — и обкатка показала, что это НЕ невозможная частота:
## рантайм её дал, и доставка подтвердила 143.8 к/с. Значит перечисление
## xrEnumerateDisplayRefreshRatesFB занижает потолок устройства (см. _check_ceiling).
## Фальсификатору нужна величина, которой заведомо нет.
const IMPOSSIBLE_HZ := 240.0

## Частота выше перечисленного потолка, работоспособность которой ИЗМЕРЕНА.
const BEYOND_LIST_HZ := 144.0

var _host: Node
var _container: Node3D
var _vp: RID
var _log_path := "user://freq_matrix.tsv"

## Результаты по ступеням: по записи на каждую.
var steps: Array[Dictionary] = []
var falsifier_seen := false


func expected_checks() -> int:
	# фальсификатор частоты 1, потолок против перечисления 1, ступени дали
	# запрошенное 1, заявленная частота подтверждена доставкой 1, состояние не
	# менялось 1, живость резиденции 1, значимость разницы 1, принадлежность
	# эффекта 1, канарейка 1
	return 9


func setup(host: Node, parent: Node) -> void:
	_host = host
	_container = Node3D.new()
	_container.position = Vector3(0, 0, -2)
	parent.add_child(_container)
	_vp = host.get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(_vp, true)


func _clear() -> void:
	for c in _container.get_children():
		c.queue_free()


## Та же геометрия, что в фазе C–D: крошечные квады с уникальным материалом.
## Крошечные намеренно — меряется подача геометрии, а не филлрейт.
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


func run(r: ProbeReport) -> void:
	r.note("")
	r.note("--- M. Частотная матрица ---")
	r.note("ступени: %s Гц; свип %s; канарейка N=%d" % [str(STEPS), str(SWEEP_POINTS), CANARY_N])
	r.note("порядок с повтором отделяет частоту от прогрева: эффект частоты переворачивается, эффект прогрева — нет")

	await _falsifier(r)
	await _check_ceiling(r)

	var f := FileAccess.open(_log_path, FileAccess.WRITE)
	if f != null:
		# unix-время первой колонкой: по нему этот TSV сводится с выводом
		# tools/gpu_sampler.sh, который снимает клок с хоста (изнутри
		# приложения /sys не открыть — см. probe_hwstat.gd).
		f.store_line("# unix_время\tступень\tзапрошено\tполучено\tN\tCPU мед\tGPU мед\tкадров\tк/с\tсверх бюджета\tdraw calls\tклок Гц\tбуфер")

	var denied := 0
	for idx in STEPS.size():
		var want: float = STEPS[idx]
		var res: Dictionary = await ProbeBudget.request_hz(_host, want)
		var got: float = res["got"]
		if res["outcome"] != "ok":
			denied += 1
		var budget := ProbeBudget.ms_for_hz(got)
		# Первое окно после переключения испорчено — см. ProbeWindow.settle().
		await ProbeWindow.settle(_host)

		var state := ProbeState.snapshot(_host.get_viewport())
		var res_before := ProbeHwStat.clock_stats()

		var sweep := {}
		for n in SWEEP_POINTS:
			_clear()
			await _host.get_tree().process_frame
			_spawn(n)
			var m: Dictionary = await ProbeWindow.measure(_host, _vp, budget)
			sweep[n] = m
			var cpu: ProbeStats = m["cpu"]
			var gpu: ProbeStats = m["gpu"]
			if f != null:
				f.store_line("%.3f\t%d\t%.1f\t%.1f\t%d\t%.3f\t%.3f\t%d\t%.1f\t%d\t%d\t%d\t%s" % [
						Time.get_unix_time_from_system(),
						idx, want, got, n, cpu.median(), gpu.median(), m["frames"], m["fps"],
						m["over"], m["calls"], ProbeHwStat.gpu_clock_hz(),
						state.get("render_target_size", "?")])
				f.flush()

		# Канарейка меряется последней на ступени: к этому моменту ступень
		# прогрета так же, как была прогрета предыдущая, и сравнение честное.
		_clear()
		await _host.get_tree().process_frame
		_spawn(CANARY_N)
		var canary: Dictionary = await ProbeWindow.measure(_host, _vp, budget)
		_clear()

		var res_after := ProbeHwStat.clock_stats()
		var delta := ProbeHwStat.residency_delta(res_before, res_after)

		var rec := {
			"idx": idx, "want": want, "got": got, "budget": budget,
			"sweep": sweep, "canary": canary, "state": state,
			"residency": delta,
		}
		steps.append(rec)
		_report_step(r, rec)

	if f != null:
		f.close()
	r.note("сырые ступени: %s" % ProjectSettings.globalize_path(_log_path))

	_check_steps_granted(r, denied)
	_check_hz_vs_delivery(r)
	_check_state_stable(r)
	_check_residency_alive(r)
	_check_significance(r)
	_check_attribution(r)
	_check_canary(r)


## Фальсификатор запроса частоты: просим то, чего у устройства нет.
##
## Без него «все ступени дали запрошенное» ничего не стоит: прибор, который
## всегда говорит «получено», неотличим от прибора, который не смотрит.
##
## Обкатка 2026-09-13 показала, что он был нужен не зря: рантайм доложил УСПЕХ
## на 144 Гц, которых нет в его же перечислении, и без единой жалобы в логе.
## Значит слову рантайма о частоте верить нельзя, и проверять надо ДОСТАВКОЙ:
## сколько кадров реально пришло за секунду.
func _falsifier(r: ProbeReport) -> void:
	var res: Dictionary = await ProbeBudget.request_hz(_host, IMPOSSIBLE_HZ)
	var claimed: float = res["got"]

	if res["outcome"] == "denied":
		falsifier_seen = true
		r.pass_("фальсификатор частоты: %.0f Гц нет в лестнице → отказ замечен, работаем на %.1f" % [
				IMPOSSIBLE_HZ, claimed])
	elif res["outcome"] == "ok":
		# Рантайм согласился. Спрашиваем не его, а кадры.
		_clear()
		await _host.get_tree().process_frame
		var m: Dictionary = await ProbeWindow.measure(_host, _vp, NAN)
		var fps: float = m["fps"]
		if not is_nan(fps) and absf(fps - claimed) > claimed * 0.15:
			falsifier_seen = true
			r.pass_("фальсификатор частоты: рантайм ПОДТВЕРДИЛ %.0f Гц, которых нет в лестнице, но доставка %.1f к/с его опровергает — слову рантайма о частоте верить нельзя, только доставке" % [
					IMPOSSIBLE_HZ, fps])
		else:
			r.fail("фальсификатор частоты: рантайм доложил %.0f Гц И доставка это подтверждает (%.1f к/с) — либо частота настоящая, либо фальсификатор выбран неудачно" % [
					claimed, fps])
	else:
		r.unkn("фальсификатор частоты: %s" % res["reason"])


## Потолок устройства против его же перечисления.
##
## xrEnumerateDisplayRefreshRatesFB отдаёт [72, 80, 90, 120], и ADR-0006
## строится на «просить максимум из лестницы». Обкатка 2026-09-13 показала, что
## лестница НЕ полна: 144 Гц запрашиваются, даются и подтверждаются доставкой
## 143.8 к/с. Значит «максимум доступного» вычислен не из того списка, а бюджет
## на настоящем потолке — 6.94 мс, а не 8.33.
##
## Проверка не ищет потолок лестницей вверх: перебирать неизвестные режимы на
## чужом шлеме — не дело прибора. Она проверяет ровно один измеренный факт.
func _check_ceiling(r: ProbeReport) -> void:
	var listed := ProbeBudget.max_available_hz()
	var res: Dictionary = await ProbeBudget.request_hz(_host, BEYOND_LIST_HZ)
	var claimed: float = res["got"]
	if res["outcome"] != "ok":
		r.pass_("потолок: %.0f Гц выше перечисленного максимума %.0f и НЕ даются — перечисление полно" % [
				BEYOND_LIST_HZ, listed])
		return

	await ProbeWindow.settle(_host)
	_clear()
	await _host.get_tree().process_frame
	var m: Dictionary = await ProbeWindow.measure(_host, _vp, NAN)
	var fps: float = m["fps"]
	if not is_nan(fps) and absf(fps - BEYOND_LIST_HZ) <= BEYOND_LIST_HZ * 0.15:
		# Это не отказ прибора и не поломка: это факт о платформе, который
		# опровергает посылку ADR-0006 о том, что потолок берётся из лестницы.
		r.fail("потолок: перечисление отдаёт максимум %.0f Гц, но %.0f Гц работают и подтверждены доставкой %.1f к/с — лестница ЗАНИЖАЕТ потолок, бюджет на нём %.2f мс" % [
				listed, BEYOND_LIST_HZ, fps, ProbeBudget.ms_for_hz(BEYOND_LIST_HZ)])
	else:
		r.pass_("потолок: рантайм согласился на %.0f Гц, но доставка %.1f к/с это не подтверждает — перечисление можно считать полным" % [
				BEYOND_LIST_HZ, fps])


func _report_step(r: ProbeReport, rec: Dictionary) -> void:
	var sweep: Dictionary = rec["sweep"]
	var hi: Dictionary = sweep[SWEEP_POINTS[SWEEP_POINTS.size() - 1]]
	var lo: Dictionary = sweep[SWEEP_POINTS[0]]
	var gpu_hi: ProbeStats = hi["gpu"]
	var gpu_lo: ProbeStats = lo["gpu"]
	var cpu_hi: ProbeStats = hi["cpu"]
	r.note("")
	r.note("ступень %d: запрошено %.0f, получено %.1f Гц, бюджет %.2f мс" % [
			rec["idx"], rec["want"], rec["got"], rec["budget"]])
	r.note("    база GPU %.3f мс, при N=%d GPU %.3f / CPU %.3f мс, мкс на вызов %.3f" % [
			gpu_lo.median(), SWEEP_POINTS[SWEEP_POINTS.size() - 1], gpu_hi.median(),
			cpu_hi.median(), slope_us(rec)])
	r.note("    %s" % ProbeWindow.delivery_brief(hi, rec["got"]))
	var d: Dictionary = rec["residency"]
	if d.get("ok", false):
		var t := ProbeHwStat.time_like_factor(d["sum"], _step_wall_ms(rec))
		r.note("    клок: %s%s" % [
				ProbeHwStat.residency_brief(d["delta"], ProbeHwStat.available_hz(), d["sum"]),
				"" if t["plausible"] else " (шкала счётчика не времяподобна — доли недостоверны)"])
	else:
		r.note("    клок: резиденция недоступна")


## Наклон: цена одного draw call для GPU на этой ступени, мкс.
## Публичный: его читает и отчёт в probe_main.gd.
func slope_us(rec: Dictionary) -> float:
	var sweep: Dictionary = rec["sweep"]
	var n_hi: int = SWEEP_POINTS[SWEEP_POINTS.size() - 1]
	var n_lo: int = SWEEP_POINTS[0]
	if not sweep.has(n_hi) or not sweep.has(n_lo) or n_hi == n_lo:
		return NAN
	var hi: ProbeStats = sweep[n_hi]["gpu"]
	var lo: ProbeStats = sweep[n_lo]["gpu"]
	return (hi.median() - lo.median()) * 1000.0 / float(n_hi - n_lo)


func _step_wall_ms(rec: Dictionary) -> float:
	var total := 0.0
	for n in rec["sweep"]:
		total += float(rec["sweep"][n]["wall_ms"])
	total += float(rec["canary"]["wall_ms"])
	return total


func _check_steps_granted(r: ProbeReport, denied: int) -> void:
	if denied == 0:
		r.pass_("все %d ступеней дали запрошенную частоту" % STEPS.size())
	else:
		# Не отказ прибора: это факт о платформе, но матрица от него слепнет.
		r.fail("ступеней с неудовлетворённым запросом: %d из %d — сравнивать частоты нельзя, часть ступеней шла не на той" % [
				denied, STEPS.size()])


## Главная проверка гипотез про фовеацию и разрешение.
func _check_state_stable(r: ProbeReport) -> void:
	if steps.size() < 2:
		r.unkn("состояние рендера: ступеней меньше двух, сравнивать нечего")
		return
	var base: Dictionary = steps[0]["state"]
	var diffs: Array[String] = []
	for i in range(1, steps.size()):
		for line in ProbeState.diff(base, steps[i]["state"]):
			diffs.append("ступень %d: %s" % [i, line])
	if diffs.is_empty():
		r.pass_("состояние рендера НЕ менялось между ступенями — объяснения аномалии через фовеацию и через разрешение буфера ИСКЛЮЧЕНЫ")
	else:
		r.fail("состояние рендера менялось: %s — вот и объяснение, искать дальше не нужно" % "; ".join(diffs))


## Живость счётчика резиденции. Непрогнанная в красное проверка ничего не
## доказывает (§2.4): если счётчик не двигается под нагрузкой, вывод «клок не
## менялся» — это слепота прибора, а не факт о железе. Ровно эта ошибка уже
## была с троттлингом на минимальной частоте.
func _check_residency_alive(r: ProbeReport) -> void:
	var moved := 0
	var plausible := 0
	for rec in steps:
		var d: Dictionary = rec["residency"]
		if d.get("ok", false) and d["sum"] > 0:
			moved += 1
			if ProbeHwStat.time_like_factor(d["sum"], _step_wall_ms(rec))["plausible"]:
				plausible += 1
	if moved == 0:
		r.unkn("резиденция частот: ни один счётчик не сдвинулся — прибор слеп, судить о разгоне нечем")
	elif plausible == 0:
		r.fail("резиденция частот: счётчики двигаются, но сумма не времяподобна — шкала не время, доли окна считать нельзя")
	else:
		r.pass_("резиденция частот: счётчики живы на %d ступенях из %d, шкала времяподобна на %d" % [
				moved, steps.size(), plausible])


## Заявленная частота против фактической доставки.
##
## Рантайму верить нельзя: обкатка показала, что он подтверждает даже частоту,
## которой нет в его собственном перечислении. Единственный независимый
## свидетель — кадры. Сверяется точка N=0, где нагрузка минимальна и падение
## доставки нельзя списать на то, что мы не успели отрисовать.
func _check_hz_vs_delivery(r: ProbeReport) -> void:
	var bad: Array[String] = []
	var checked := 0
	for rec in steps:
		var m: Dictionary = rec["sweep"].get(SWEEP_POINTS[0], {})
		if m.is_empty():
			continue
		var fps: float = m["fps"]
		var got: float = rec["got"]
		if is_nan(fps) or got <= 1.0:
			continue
		checked += 1
		# 15%: доставка всегда чуть ниже номинала из-за границ окна.
		if absf(fps - got) > got * 0.15:
			bad.append("ступень %d: заявлено %.1f Гц, доставлено %.1f к/с" % [rec["idx"], got, fps])
	if checked == 0:
		r.unkn("частота против доставки: сверить не на чем")
	elif bad.is_empty():
		r.pass_("частота против доставки: на всех %d ступенях кадры подтверждают заявленную частоту" % checked)
	else:
		r.fail("частота против доставки: %s — заявленная частота не подтверждается кадрами, бюджеты этих ступеней посчитаны не от той величины" % "; ".join(bad))


## Значима ли разница между частотами. Порог не назначается: им служит разброс
## между двумя ступенями ОДНОЙ частоты, измеренный в этом же прогоне.
func _check_significance(r: ProbeReport) -> void:
	var v := _slopes()
	if v.is_empty():
		r.unkn("значимость разницы: наклон посчитан не на всех ступенях")
		return
	var m72: float = (v["s72"][0] + v["s72"][1]) / 2.0
	var m120: float = (v["s120"][0] + v["s120"][1]) / 2.0
	var spread: float = maxf(absf(v["s72"][0] - v["s72"][1]), absf(v["s120"][0] - v["s120"][1]))
	var diff: float = absf(m72 - m120)

	r.note("")
	r.note("наклон по ступеням, мкс на вызов: 72 Гц %.3f и %.3f; 120 Гц %.3f и %.3f" % [
			v["s72"][0], v["s72"][1], v["s120"][0], v["s120"][1]])
	r.note("    среднее 72 Гц %.3f, 120 Гц %.3f, разница %.3f; разброс внутри частоты %.3f" % [
			m72, m120, diff, spread])

	if diff > spread * 2.0:
		r.pass_("значимость: разница между частотами %.3f мкс вдвое превышает разброс внутри частоты %.3f — разница настоящая" % [diff, spread])
	else:
		r.fail("значимость: разница между частотами %.3f мкс НЕ превышает вдвое разброс внутри частоты %.3f — на этих данных удвоение цены draw call не воспроизводится" % [diff, spread])


## Кому принадлежит эффект: частоте или времени.
##
## Это НЕ то же, что значимость, и считается по-другому. Ступени идут
## 72 → 120 → 72 → 120. Если дело в частоте, ряд наклонов пилообразный: знак
## приращения меняется на каждом шаге. Если дело в прогреве, ряд монотонен и
## частоте не подчиняется. Разброс внутри частоты этого различить не может —
## он одинаков в обоих случаях.
func _check_attribution(r: ProbeReport) -> void:
	if steps.size() < 4:
		r.unkn("принадлежность эффекта: ступеней меньше четырёх")
		return
	var seq: Array[float] = []
	for rec in steps:
		seq.append(slope_us(rec))
	for x in seq:
		if is_nan(x):
			r.unkn("принадлежность эффекта: наклон посчитан не на всех ступенях")
			return

	var d1 := seq[1] - seq[0]
	var d2 := seq[2] - seq[1]
	var d3 := seq[3] - seq[2]
	var zigzag := (d1 > 0.0) != (d2 > 0.0) and (d2 > 0.0) != (d3 > 0.0)
	var monotone := ((d1 > 0.0) == (d2 > 0.0)) and ((d2 > 0.0) == (d3 > 0.0))
	r.note("    приращения по ряду ступеней: %+.3f, %+.3f, %+.3f" % [d1, d2, d3])

	if zigzag:
		r.pass_("принадлежность: ряд пилообразный, знак меняется на каждой смене частоты — эффект принадлежит ЧАСТОТЕ, а не времени")
	elif monotone:
		r.fail("принадлежность: ряд монотонен по времени и частоте не подчиняется — это ДРЕЙФ, а не эффект частоты")
	else:
		r.fail("принадлежность: ряд ни пилообразный, ни монотонный — частота и дрейф смешаны, разделить на этих данных нельзя")


## Наклоны по частотам; пустой словарь, если посчитать удалось не всё.
func _slopes() -> Dictionary:
	if steps.size() < 4:
		return {}
	var s72: Array[float] = [slope_us(steps[0]), slope_us(steps[2])]
	var s120: Array[float] = [slope_us(steps[1]), slope_us(steps[3])]
	for x in s72 + s120:
		if is_nan(x):
			return {}
	return {"s72": s72, "s120": s120}


## Канарейка: одинаковая нагрузка на всех ступенях. Её ход по времени — дрейф
## как таковой, без примеси свипа.
func _check_canary(r: ProbeReport) -> void:
	if steps.size() < 2:
		r.unkn("канарейка: ступеней меньше двух")
		return
	var vals: Array[float] = []
	var line: Array[String] = []
	for rec in steps:
		var g: ProbeStats = rec["canary"]["gpu"]
		vals.append(g.median())
		line.append("%.3f@%.0fГц" % [g.median(), rec["got"]])
	r.note("канарейка N=%d, GPU мед по ступеням: %s мс" % [CANARY_N, ", ".join(line)])

	var first := vals[0]
	var worst := first
	for v in vals:
		worst = maxf(worst, v)
	var rel := (worst - first) / maxf(first, 0.0001) * 100.0
	if rel < 10.0:
		r.pass_("канарейка: худшая ступень %+.1f%% от первой — прогрев за матрицу не съел сравнение" % rel)
	else:
		r.fail("канарейка: худшая ступень %+.1f%% от первой — за время матрицы условия уехали, ступени сравнивать опасно" % rel)
