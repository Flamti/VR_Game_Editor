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

## Ступени: минимум и цель (ADR-0007). Порядок с повтором — суть прибора,
## менять его нельзя, не поняв объяснение выше.
##
## Было [72, 120]: тогда 120 Гц считались рабочей частотой по правилу «просить
## максимум». Правило снято, рабочий диапазон теперь 72–90, и сравнивать надо
## внутри него. Данные по паре 72/120 сохранены в docs/hardware-profile.md и
## остаются верными для своих частот — интерполировать их на 90 нельзя.
const STEPS := [ProbeBudget.FLOOR_HZ, ProbeBudget.TARGET_HZ, ProbeBudget.FLOOR_HZ, ProbeBudget.TARGET_HZ]

## Точки свипа: концы дают наклон, середина показывает, что он прямой.
const SWEEP_POINTS := [0, 400, 1600]

## Канарейка — неизменная нагрузка на всех ступенях.
const CANARY_N := 400

## Частота, которой у устройства нет без специальных свойств. Фальсификатор
## запроса: прибор обязан УВИДЕТЬ отказ, а не принять неизменившуюся частоту
## за успех.
##
## Здесь стояло 144 Гц — и обкатка показала, что это НЕ невозможная частота:
## рантайм её дал, доставка подтвердила 143.8 к/с. Причина потом нашлась в
## документации Meta: 72–207 Гц доступны без настройки, а перечисление
## неисчерпывающе по замыслу. 240 Гц требуют debug.oculus.forceDisplayScaling,
## которого мы не ставим, — и потому годятся в фальсификаторы.
const IMPOSSIBLE_HZ := 240.0

var _host: Node
var _container: Node3D
var _vp: RID
var _log_path := "user://freq_matrix.tsv"

## Результаты по ступеням: по записи на каждую.
var steps: Array[Dictionary] = []
var falsifier_seen := false
## Прошла ли проверка значимости. Атрибуция без неё бессмысленна.
var _significant := false


func expected_checks() -> int:
	# фальсификатор частоты 1, ступени дали запрошенное 1, заявленная частота
	# подтверждена доставкой 1, счётчик отрисовок сошёлся с N 1, состояние не
	# менялось 1, живость резиденции 1, значимость разницы 1, принадлежность
	# эффекта 1, канарейка 1
	#
	# Проверки потолка здесь больше нет. Она подтверждала, что 144 Гц работают
	# вопреки перечислению; вопрос закрыт документацией вендора и записан в
	# ADR-0006 с поправкой. Держать её значило бы гонять дисплей на 144 Гц в
	# каждом прогоне ради факта, который уже установлен.
	return 9


func setup(host: Node, parent: Node) -> void:
	_host = host
	_container = Node3D.new()
	ProbeWindow.attach_load(host, parent, _container)
	_vp = host.get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(_vp, true)


func _clear() -> void:
	for c in _container.get_children():
		c.queue_free()


## Очистка с ОЖИДАНИЕМ освобождения.
##
## queue_free() освобождает узлы в конце кадра, а после сотен объектов это
## занимает не один кадр. Прогон 7 показал цену: нулевая точка ступени 2 дала
## 3.374 мс против 2.708 на ступени 0 — первое окно поймало хвост уборки
## предыдущей ступени. Через наклон (Δ/1600) это даёт 0.42 мкс на вызов, то
## есть ровно тот масштаб, который проверка значимости приняла за шум и из-за
## которого разница между 72 и 90 Гц не подтвердилась.
func _clear_and_wait() -> void:
	_clear()
	var guard := 0
	while _container.get_child_count() > 0 and guard < 60:
		await _host.get_tree().process_frame
		guard += 1


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

	# Кадр обязан быть пуст ДО первого измерения: предыдущая фаза ещё
	# освобождает свои объекты, и первые окна ловят её, а не нашу нагрузку.
	if not await ProbeWindow.wait_until_idle(_host, _vp):
		r.note("ВНИМАНИЕ: кадр не опустел за отведённое время — первые точки могут быть загрязнены")

	await _falsifier(r)

	var f := FileAccess.open(_log_path, FileAccess.WRITE)
	if f != null:
		# unix-время первой колонкой: по нему этот TSV сводится с выводом
		# tools/gpu_sampler.sh, который снимает клок с хоста (изнутри
		# приложения /sys не открыть — см. probe_hwstat.gd).
		f.store_line("# unix_время\tтип\tступень\tзапрошено\tполучено\tN\tCPU мед\tGPU мед\tкадров\tк/с\tсверх бюджета\tdraw calls\tбуфер")

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
			await _clear_and_wait()
			_spawn(n)
			var m: Dictionary = await ProbeWindow.measure(_host, _vp, budget)
			sweep[n] = m
			var cpu: ProbeStats = m["cpu"]
			var gpu: ProbeStats = m["gpu"]
			if f != null:
				_write_row(f, "свип", idx, want, got, n, m, state)

		# Канарейка меряется последней на ступени: к этому моменту ступень
		# прогрета так же, как была прогрета предыдущая, и сравнение честное.
		await _clear_and_wait()
		_spawn(CANARY_N)
		var canary: Dictionary = await ProbeWindow.measure(_host, _vp, budget)
		_write_row(f, "канарейка", idx, want, got, CANARY_N, canary, state)
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
	_check_calls_match(r)
	_check_state_stable(r)
	_check_residency_alive(r)
	_check_significance(r)
	_check_attribution(r)
	_check_canary(r)


## Одна строка данных. Общая для свипа и канарейки: раньше канарейка в файл не
## попадала вовсе, и её всплеск на последней ступени нечем было сопоставить ни
## со временем, ни с клоком.
func _write_row(f: FileAccess, kind: String, idx: int, want: float, got: float,
		n: int, m: Dictionary, state: Dictionary) -> void:
	if f == null:
		return
	var cpu: ProbeStats = m["cpu"]
	var gpu: ProbeStats = m["gpu"]
	f.store_line("%.3f\t%s\t%d\t%.1f\t%.1f\t%d\t%.3f\t%.3f\t%d\t%.1f\t%d\t%d\t%s" % [
			Time.get_unix_time_from_system(), kind, idx, want, got, n,
			cpu.median(), gpu.median(), m["frames"], m["fps"], m["over"], m["calls"],
			state.get("render_target_size", "?")])
	f.flush()


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
		await _clear_and_wait()
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


## Счётчик отрисовок обязан сойтись с числом заявленных объектов.
##
## Гейт §2.5, которого у матрицы не было, хотя у фазы C–D он есть с самого
## начала. Прогон 8 показал, чем это кончается: первая ступень мерила 1175
## вызовов вместо 1600, наклон считался по номинальному N и был занижен, а
## увидеть это можно было только вручную в TSV. Теперь несовпадение называется
## поимённо и красит прогон.
func _check_calls_match(r: ProbeReport) -> void:
	var off: Array[String] = []
	var checked := 0
	for rec in steps:
		for n in rec["sweep"]:
			if n <= 0:
				continue
			checked += 1
			var actual: int = rec["sweep"][n]["calls"]
			if absf(float(actual - n)) / float(n) > 0.05:
				off.append("ступень %d N=%d→%d" % [rec["idx"], n, actual])
		var c: int = rec["canary"]["calls"]
		checked += 1
		if absf(float(c - CANARY_N)) / float(CANARY_N) > 0.05:
			off.append("ступень %d канарейка %d→%d" % [rec["idx"], CANARY_N, c])
	if checked == 0:
		r.unkn("счётчик отрисовок: точек нет")
	elif off.is_empty():
		r.pass_("счётчик отрисовок: сошёлся с заявленным на всех %d точках — наклоны считаются по настоящей нагрузке" % checked)
	else:
		r.fail("счётчик отрисовок НЕ сошёлся: %s — на этих точках наклон считался по номинальному N и занижен, ступени недействительны" % ", ".join(off))


## Значима ли разница между частотами. Порог не назначается: им служит разброс
## между двумя ступенями ОДНОЙ частоты, измеренный в этом же прогоне.
func _check_significance(r: ProbeReport) -> void:
	var v := _slopes()
	if v.is_empty():
		r.unkn("значимость разницы: наклон посчитан не на всех ступенях")
		return
	var m_lo: float = (v["lo"][0] + v["lo"][1]) / 2.0
	var m_hi: float = (v["hi"][0] + v["hi"][1]) / 2.0
	var spread: float = maxf(absf(v["lo"][0] - v["lo"][1]), absf(v["hi"][0] - v["hi"][1]))
	var diff: float = absf(m_lo - m_hi)
	# Подписи берутся из ФАКТИЧЕСКИ полученных частот, а не из констант: если
	# рантайм дал не то, что просили, отчёт обязан назвать реальные ступени.
	var hz_lo: float = steps[0]["got"]
	var hz_hi: float = steps[1]["got"]

	r.note("")
	r.note("наклон по ступеням, мкс на вызов: %.0f Гц %.3f и %.3f; %.0f Гц %.3f и %.3f" % [
			hz_lo, v["lo"][0], v["lo"][1], hz_hi, v["hi"][0], v["hi"][1]])
	r.note("    среднее %.0f Гц %.3f, %.0f Гц %.3f, разница %.3f; разброс внутри частоты %.3f" % [
			hz_lo, m_lo, hz_hi, m_hi, diff, spread])

	if diff > spread * 2.0:
		_significant = true
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
	# Если значимость не прошла, атрибутировать нечего: форма ряда из четырёх
	# точек, укладывающихся в шум, ничего не значит. Прогон 7 показал, зачем
	# это нужно: значимость упала (0.436 против разброса 0.359), а атрибуция
	# рядом отрапортовала «эффект принадлежит частоте» — и прочитать это можно
	# было как подтверждение эффекта. Тот же дефект, что «наклон при
	# непройденном гейте» в фазе P.
	if not _significant:
		r.unkn("принадлежность эффекта: значимость не подтверждена, атрибутировать нечего")
		return
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
	var lo: Array[float] = [slope_us(steps[0]), slope_us(steps[2])]
	var hi: Array[float] = [slope_us(steps[1]), slope_us(steps[3])]
	for x in lo + hi:
		if is_nan(x):
			return {}
	return {"lo": lo, "hi": hi}


## Канарейка: одинаковая нагрузка, сравниваемая ВНУТРИ одной частоты.
##
## Дефект, найденный прогоном 6. Прежняя версия брала худшую ступень против
## первой поперёк всех четырёх и выдала «+50.2%» — но ступени идут на разных
## частотах, а цена кадра от частоты зависит, и это ровно тот эффект, который
## матрица измеряет. Канарейка мерила его же и называла дрейфом.
##
## Правильное сравнение — повтор той же частоты: 72 против 72, 90 против 90.
## На данных прогона 6 это давало 72 Гц +4.2% против 120 Гц +49.9%: дрейф был,
## но он жил на одной частоте, и прежняя формулировка это скрывала.
func _check_canary(r: ProbeReport) -> void:
	if steps.size() < 4:
		r.unkn("канарейка: ступеней меньше четырёх, повторов частоты нет")
		return

	var line: Array[String] = []
	for rec in steps:
		var g: ProbeStats = rec["canary"]["gpu"]
		line.append("%.3f@%.0fГц" % [g.median(), rec["got"]])
	r.note("канарейка N=%d, GPU мед по ступеням: %s мс" % [CANARY_N, ", ".join(line)])

	var worst_hz := 0.0
	var worst_rel := 0.0
	var parts: Array[String] = []
	# Пары повторов одной частоты: (0,2) и (1,3) — так устроен порядок STEPS.
	for pair in [[0, 2], [1, 3]]:
		var a: ProbeStats = steps[pair[0]]["canary"]["gpu"]
		var b: ProbeStats = steps[pair[1]]["canary"]["gpu"]
		var hz: float = steps[pair[0]]["got"]
		var rel := (b.median() - a.median()) / maxf(a.median(), 0.0001) * 100.0
		parts.append("%.0f Гц %+.1f%%" % [hz, rel])
		if absf(rel) > absf(worst_rel):
			worst_rel = rel
			worst_hz = hz
	r.note("    дрейф между повторами одной частоты: %s" % ", ".join(parts))

	if absf(worst_rel) < 10.0:
		r.pass_("канарейка: наибольший дрейф между повторами одной частоты %+.1f%% (на %.0f Гц) — условия за матрицу не уехали" % [
				worst_rel, worst_hz])
	else:
		r.fail("канарейка: между повторами %.0f Гц нагрузка изменилась на %+.1f%% — условия уехали ВНУТРИ одной частоты, сравнение ступеней ненадёжно" % [
				worst_hz, worst_rel])
