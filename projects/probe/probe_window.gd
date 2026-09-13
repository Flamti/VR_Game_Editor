extends RefCounted
class_name ProbeWindow

## Одно окно измерения. Общее для всех фаз, которые что-то меряют.
##
## Существует по двум причинам, и обе — дефекты, найденные при разборе
## аномалии 120 Гц.
##
## **Окно задаётся временем, а не кадрами.** Прежний замер брал 30 кадров
## разогрева и 60 кадров статистики. На 72 Гц это 1.25 с, на 120 Гц — 0.75 с.
## Сравнение частот шло при разной длительности окна, то есть при разном
## состоянии DVFS: часть наблюдаемой разницы могла быть просто «на 120 Гц GPU
## не успел выйти на режим». Теперь окно одинаково по стенным часам, а число
## кадров — результат измерения, а не его настройка.
##
## **Считается доставка, а не только время рендера.** Прибор судил «бюджет
## удержан» по p95 времени кадра и НИ РАЗУ не проверял, доехал ли кадр. На
## 120 Гц p95 занимает 96% бюджета, промахи по дедлайну вероятны и были бы
## невидимы. Одиночный выброс и устойчивый срыв — разные болезни, поэтому
## считается и доля промахов, и длина самой длинной серии подряд (§3.3).

const ProbeStats := preload("res://probe_stats.gd")

const WARMUP_S := 1.0
const MEASURE_S := 1.5

## Быстрый режим — ТОЛЬКО для обкатки прибора без надетого шлема.
##
## Укорачивает окна настолько, что числа перестают что-либо значить: за 0.2 с
## DVFS не успевает выйти на режим, а выборок не хватает на перцентиль. Режим
## существует, чтобы прогнать все ветки арифметики — наклоны, сравнения, пол —
## и поймать опечатку на земле, а не на четвёртой минуте с надетым шлемом.
##
## Прибор обязан кричать об этом режиме, иначе кто-нибудь прочтёт быстрые числа
## как измерение. Отчёт в этом режиме пишется в ДРУГОЙ файл (probe_main.gd).
static var quick := false
const QUICK_WARMUP_S := 0.2
const QUICK_MEASURE_S := 0.3


## Пауза после смены частоты, прежде чем мерить.
##
## Обкатка показала, что первое окно сразу после переключения испорчено: на
## 120 Гц точка «пустая сцена» дала 3.725 мс — БОЛЬШЕ, чем все нагруженные
## точки той же ступени, и весь наклон оси пикселей после этого стал
## бессмысленным. Композитор и DVFS перестраиваются не мгновенно.
static func settle(host: Node, seconds: float = 1.0) -> void:
	var s := QUICK_MEASURE_S if quick else seconds
	var t0 := Time.get_ticks_msec()
	while float(Time.get_ticks_msec() - t0) < s * 1000.0:
		await host.get_tree().process_frame


## Ждать, пока кадр станет ПУСТЫМ по счётчику отрисовок.
##
## Ожидания собственного контейнера мало: у каждой фазы он свой, а освобождение
## чужих узлов идёт параллельно. Прогон 8 показал последствия — на первой
## ступени матрицы счётчик дал 319 вызовов вместо 400, 1175 вместо 1600 и 176
## вместо 400 у канарейки, потому что фаза C–D в это время ещё освобождала свои
## 1600 объектов с уникальными материалами. Наклон той ступени считался по
## номинальному N и оказался занижен, а канарейка честно покраснела на +60.8%.
##
## Спрашивается не «пуст ли мой контейнер», а «пуст ли кадр» — то есть ровно
## то, что влияет на измерение.
static func wait_until_idle(host: Node, vp: RID, max_s: float = 5.0) -> bool:
	var t0 := Time.get_ticks_msec()
	while float(Time.get_ticks_msec() - t0) < max_s * 1000.0:
		await host.get_tree().process_frame
		if _calls(vp) == 0:
			return true
	return false


## Счётчик отрисовок берётся по RID НАШЕГО вьюпорта, а не из глобального
## Performance: глобальный считает всё, что рендерится в кадре.
static func _calls(vp: RID) -> int:
	return RenderingServer.viewport_get_render_info(vp,
			RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,
			RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)


static func _primitives(vp: RID) -> int:
	return RenderingServer.viewport_get_render_info(vp,
			RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,
			RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)


## Замер. budget_ms нужен для учёта промахов; NAN — промахи не считаются.
##
## aux — второй вьюпорт, который рендерится в том же кадре (SubViewport слоя
## или текстуры). Его время НЕ входит во время главного вьюпорта: у каждого
## вьюпорта свои метки. Без отдельного счёта SubViewport выглядел бы бесплатным.
## Промах по бюджету считается по сумме: кадр оплачивает оба.
static func measure(host: Node, vp: RID, budget_ms: float,
		warmup_s: float = WARMUP_S, measure_s: float = MEASURE_S,
		aux: RID = RID()) -> Dictionary:
	if quick:
		warmup_s = QUICK_WARMUP_S
		measure_s = QUICK_MEASURE_S

	var warm := ProbeStats.new()
	var t0 := Time.get_ticks_msec()
	var warm_frames := 0
	while float(Time.get_ticks_msec() - t0) < warmup_s * 1000.0:
		await host.get_tree().process_frame
		warm.add(RenderingServer.viewport_get_measured_render_time_cpu(vp))
		warm_frames += 1

	var cpu := ProbeStats.new()
	var gpu := ProbeStats.new()
	var aux_cpu := ProbeStats.new()
	var aux_gpu := ProbeStats.new()
	var calls_sum := 0
	var prims_sum := 0
	var frames := 0
	var over := 0
	var streak := 0
	var streak_max := 0

	var t1 := Time.get_ticks_msec()
	while float(Time.get_ticks_msec() - t1) < measure_s * 1000.0:
		await host.get_tree().process_frame
		var c := RenderingServer.viewport_get_measured_render_time_cpu(vp)
		var g := RenderingServer.viewport_get_measured_render_time_gpu(vp)
		cpu.add(c)
		gpu.add(g)
		if aux.is_valid():
			var ac := RenderingServer.viewport_get_measured_render_time_cpu(aux)
			var ag := RenderingServer.viewport_get_measured_render_time_gpu(aux)
			aux_cpu.add(ac)
			aux_gpu.add(ag)
			c += ac
			g += ag
		calls_sum += _calls(vp)
		prims_sum += _primitives(vp)
		frames += 1
		# Промах считается по СВЯЗЫВАЮЩЕМУ ограничению (CLAUDE.md, правило 2).
		if not is_nan(budget_ms) and maxf(c, g) > budget_ms:
			over += 1
			streak += 1
			streak_max = maxi(streak_max, streak)
		else:
			streak = 0
	var wall_ms := float(Time.get_ticks_msec() - t1)

	return {
		"cpu": cpu,
		"gpu": gpu,
		"aux_cpu": aux_cpu,
		"aux_gpu": aux_gpu,
		"warm": warm,
		"warm_frames": warm_frames,
		"calls": int(round(float(calls_sum) / maxi(frames, 1))),
		"primitives": int(round(float(prims_sum) / maxi(frames, 1))),
		"frames": frames,
		"wall_ms": wall_ms,
		"fps": (float(frames) / (wall_ms / 1000.0)) if wall_ms > 0.0 else NAN,
		"over": over,
		"over_share": (float(over) / float(frames) * 100.0) if frames > 0 else NAN,
		"streak": streak_max,
	}


## Строка о доставке: сколько кадров реально доехало против запрошенной частоты.
static func delivery_brief(m: Dictionary, target_hz: float) -> String:
	var fps: float = m.get("fps", NAN)
	var s := "доставлено %d кадров за %.0f мс = %.1f к/с" % [m.get("frames", 0), m.get("wall_ms", 0.0), fps]
	if target_hz > 1.0 and not is_nan(fps):
		s += " из %.0f (%.0f%%)" % [target_hz, fps / target_hz * 100.0]
	var over: int = m.get("over", 0)
	if over > 0:
		s += "; сверх бюджета %d (%.1f%%), самая длинная серия %d подряд" % [
				over, m.get("over_share", NAN), m.get("streak", 0)]
	else:
		s += "; промахов по бюджету нет"
	return s
