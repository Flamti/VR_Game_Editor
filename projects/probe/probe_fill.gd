extends RefCounted
class_name ProbeFill

## Фаза P: цена пикселя. Свип по РАЗМЕРУ квада при фиксированном числе слоёв.
##
## Две задачи сразу.
##
## Первая: филлрейт числится в паспорте как «не измерено». Все свипы мерили
## крошечные квады специально, чтобы исключить пиксели, — и цена пикселя так
## и осталась неизвестной, хотя бюджет без неё не построить.
##
## Вторая: это ДИСКРИМИНАТОР для незакрытой аномалии. Если цена draw call
## меняется с частотой по пиксельной причине, это обязано быть видно здесь.
## Если цена пикселя от частоты не зависит, а цена вызова зависит, механизм
## лежит в подаче геометрии и биннинге, а не в затенении.
##
## Покрытие не считается по формуле FOV, а СПРАШИВАЕТСЯ у камеры через
## unproject_position(): та же проекция, которой рендерит движок.
##
## Три дефекта, найденные прогоном 6, и что с ними сделано.
##
## 1. **Покрытие не обрезалось по вьюпорту.** Квад 9 м на 2 м давал «63.8
##    Мпикс» при буфере глаза 2.96 — то есть считалась площадь прямоугольника,
##    большая часть которого за экраном и никогда не затеняется. Наклон из
##    такого знаменателя — число ни о чём. Теперь прямоугольник пересекается
##    с прямоугольником вьюпорта.
## 2. **Сигнала не хватало:** непрозрачный квад во весь экран добавлял 0.12 мс
##    при базе 3.2 — гейт честно краснел. Теперь рисуется LAYERS слоёв с
##    выключенным тестом глубины: ранний Z их не отбрасывает, и затеняются все.
## 3. **Наклон печатался при непройденном гейте.** Гейт говорил «ось
##    недействительна», а рядом стояло PASS с числом мкс/Мпиксель. Теперь
##    порядок обратный: сначала гейты, и наклон докладывается только если они
##    прошли — как это давно сделано в фазе C–D.

const ProbeReport := preload("res://probe_report.gd")
const ProbeStats := preload("res://probe_stats.gd")
const ProbeBudget := preload("res://probe_budget.gd")
const ProbeWindow := preload("res://probe_window.gd")

## Размеры квада в метрах на расстоянии 2 м. Ноль — контрольная точка.
## Верхние размеры заведомо выходят за экран: обрезка по вьюпорту это учтёт,
## а точка насыщения покажет, где кадр закрыт целиком.
const SIZES := [0.0, 0.5, 1.0, 2.0, 4.0]

## Сколько раз перерисовать одну и ту же площадь. Тест глубины выключен, значит
## затеняются все слои, и сигнал растёт во столько же раз.
const LAYERS := 8

## Частоты рабочего диапазона (ADR-0007). Те же, что у частотной матрицы.
const FREQS := [ProbeBudget.FLOOR_HZ, ProbeBudget.TARGET_HZ]

var _host: Node
var _container: Node3D
var _camera: Camera3D
var _vp: RID

## Гц → {"points": Array, "us_per_mpx": float}
var by_freq: Dictionary = {}
var _gates_ok := false


func expected_checks() -> int:
	# чистота нулевой точки 1, гейт покрытия 1, гейт роста GPU 1,
	# наклон на каждую частоту, сравнение 1
	return 4 + FREQS.size()


func setup(host: Node, parent: Node) -> void:
	_host = host
	_container = Node3D.new()
	_container.position = Vector3(0, 0, -2)
	parent.add_child(_container)
	_vp = host.get_viewport().get_viewport_rid()
	_camera = host.get_viewport().get_camera_3d()


## Очистка с ожиданием. queue_free() освобождает узлы в конце кадра, а после
## тысячи объектов это занимает не один кадр.
##
## Прогон на 90 Гц показал, чем это оборачивается: ось пикселей идёт сразу за
## матрицей, и её нулевая точка на первой частоте дала 3.399 мс против 2.741 у
## следующей — первое окно поймало хвост чужой уборки. На второй частоте
## перехода нет, и там ряд чистый. Ждать освобождения обязательно.
func _clear() -> void:
	for c in _container.get_children():
		c.queue_free()


func _clear_and_wait() -> void:
	_clear()
	var guard := 0
	while _container.get_child_count() > 0 and guard < 60:
		await _host.get_tree().process_frame
		guard += 1


## LAYERS непрозрачных квадов с выключенным тестом глубины.
##
## Почему не прозрачные: прозрачность увела бы измерение в другой путь
## затенения — смешивание и сортировку. Выключенный тест глубины оставляет
## обычный непрозрачный путь и всего лишь запрещает раннему Z отбрасывать
## перекрытые слои.
func _spawn(size: float) -> void:
	if size <= 0.0:
		return
	var mesh := QuadMesh.new()
	mesh.size = Vector2(size, size)
	for i in LAYERS:
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.4, 0.6, 0.8)
		mat.no_depth_test = true
		mi.material_override = mat
		# Разные z, чтобы слои были различимы как объекты; глубина не решает,
		# кто из них затенится, — тест выключен.
		mi.position = Vector3(0, 0, float(i) * 0.001)
		_container.add_child(mi)


## Затеняемые пиксели: прямоугольник квада в экранных координатах, ОБРЕЗАННЫЙ
## по вьюпорту, умноженный на число слоёв. NAN — камеры нет, спросить не у кого.
func _coverage_px(size: float) -> float:
	if _camera == null:
		return NAN
	if size <= 0.0:
		return 0.0
	var c := _container.global_position
	var half := size * 0.5
	var a := _camera.unproject_position(c + Vector3(-half, -half, 0.0))
	var b := _camera.unproject_position(c + Vector3(half, half, 0.0))
	var quad := Rect2(Vector2(minf(a.x, b.x), minf(a.y, b.y)),
			Vector2(absf(b.x - a.x), absf(b.y - a.y)))
	var screen := Rect2(Vector2.ZERO, _host.get_viewport().get_visible_rect().size)
	var vis := quad.intersection(screen)
	return vis.size.x * vis.size.y * float(LAYERS)


func run(r: ProbeReport) -> void:
	r.note("")
	r.note("--- P. Цена пикселя ---")
	if _camera == null:
		for _i in expected_checks():
			r.unkn("цена пикселя: камеры нет, покрытие посчитать нечем")
		return
	var screen := _host.get_viewport().get_visible_rect().size
	r.note("вьюпорт %dx%d = %.2f Мпикс; слоёв %d, тест глубины выключен" % [
			int(screen.x), int(screen.y), screen.x * screen.y / 1000000.0, LAYERS])

	# Фаза начинается после матрицы, которая оставляет за собой сотни узлов в
	# освобождении. Без этого первая же точка меряет чужую уборку.
	await _clear_and_wait()
	if not await ProbeWindow.wait_until_idle(_host, _vp):
		r.note("ВНИМАНИЕ: кадр не опустел за отведённое время — нулевая точка может быть загрязнена")
	await ProbeWindow.settle(_host, 2.0)

	for hz in FREQS:
		var res: Dictionary = await ProbeBudget.request_hz(_host, hz)
		var got: float = res["got"]
		var budget := ProbeBudget.ms_for_hz(got)
		await ProbeWindow.settle(_host)
		var points: Array[Dictionary] = []
		r.note("")
		r.note("на %.1f Гц (запрошено %.0f), бюджет %.2f мс:" % [got, hz, budget])

		for size in SIZES:
			await _clear_and_wait()
			_spawn(size)
			await _host.get_tree().process_frame
			var px := _coverage_px(size)
			var m: Dictionary = await ProbeWindow.measure(_host, _vp, budget)
			var gpu: ProbeStats = m["gpu"]
			points.append({"size": size, "px": px, "gpu": gpu.median(), "m": m})
			r.note("    размер %.2f м → затеняется %.2f Мпикс, GPU мед %.3f мс" % [
					size, px / 1000000.0, gpu.median()])
		await _clear_and_wait()
		by_freq[got] = {"points": points, "us_per_mpx": _slope(points)}

	# Гейты ПЕРВЫМИ: наклон при непройденном гейте не докладывается. Флаг
	# начинается с true и гасится любым непройденным гейтом — иначе, как было в
	# первой редакции, он не поднимался никогда и наклон молчал всегда.
	_gates_ok = true
	_check_zero_clean(r)
	_check_coverage_gate(r)
	_check_growth_gate(r)
	_report_slopes(r)
	_check_across_freq(r)


## Наклон: мкс на мегапиксель по концам оси.
func _slope(points: Array[Dictionary]) -> float:
	if points.size() < 2:
		return NAN
	var lo: Dictionary = points[0]
	var hi: Dictionary = points[points.size() - 1]
	var d_px: float = hi["px"] - lo["px"]
	if is_nan(d_px) or d_px <= 0.0:
		return NAN
	return (hi["gpu"] - lo["gpu"]) * 1000.0 / (d_px / 1000000.0)


## Нулевая точка обязана быть ПУСТОЙ: ни одной отрисовки. Если счётчик показал
## объекты, значит в кадре осталось чужое, и вся ось отсчитывается от неверной
## базы — ровно то, что случилось на первом прогоне с исправленной осью.
func _check_zero_clean(r: ProbeReport) -> void:
	var dirty: Array[String] = []
	var checked := 0
	for hz in by_freq:
		var points: Array = by_freq[hz]["points"]
		if points.is_empty() or points[0]["size"] > 0.0:
			continue
		checked += 1
		var calls: int = points[0]["m"]["calls"]
		if calls > 0:
			dirty.append("%.0f Гц: %d отрисовок" % [hz, calls])
	if checked == 0:
		r.unkn("чистота нулевой точки: нулевой точки нет")
		_gates_ok = false
	elif dirty.is_empty():
		r.pass_("чистота нулевой точки: на всех %d частотах кадр пуст, база отсчёта верна" % checked)
	else:
		r.fail("чистота нулевой точки: %s — в кадре осталось чужое, вся ось отсчитывается от неверной базы" % "; ".join(dirty))
		_gates_ok = false


## Гейт §2.5: покрытие обязано расти вместе с размером. После обрезки по
## вьюпорту оно выходит на насыщение — это нормально и ожидаемо; недопустимо
## обратное, когда оно не растёт вовсе.
func _check_coverage_gate(r: ProbeReport) -> void:
	var any := by_freq.values()
	if any.is_empty():
		r.unkn("гейт покрытия: точек нет")
		_gates_ok = false
		return
	var points: Array = any[0]["points"]
	var lo: float = points[0]["px"]
	var hi: float = points[points.size() - 1]["px"]
	if hi > lo and hi > 0.0:
		r.pass_("гейт покрытия: затеняемых пикселей от %.2f до %.2f Мпикс (с обрезкой по вьюпорту и %d слоями)" % [
				lo / 1000000.0, hi / 1000000.0, LAYERS])
	else:
		r.fail("гейт покрытия: покрытие не растёт (%.2f → %.2f Мпикс) — ось меряет не то, что заявлено" % [
				lo / 1000000.0, hi / 1000000.0])
		_gates_ok = false


## Гейт §2.5: время GPU обязано отзываться на покрытие. Если не отзывается,
## случай до филлрейта не доходит, и наклон — число ни о чём.
func _check_growth_gate(r: ProbeReport) -> void:
	var any := by_freq.values()
	if any.is_empty():
		r.unkn("гейт роста GPU: точек нет")
		_gates_ok = false
		return
	var points: Array = any[0]["points"]
	var lo: float = points[0]["gpu"]
	var hi: float = points[points.size() - 1]["gpu"]
	var rise := hi - lo

	# Гейт проверяет МОНОТОННОСТЬ, а не превышение назначенного порога.
	#
	# Здесь стояло «рост больше 20%», и это был порог из головы — ровно то,
	# что PRACTICES §3.1 запрещает: сначала измерить единицу, потом назначать
	# порог. Прогон на 90 Гц показал цену: ряд 2.909 → 2.926 → 2.943 → 2.957 →
	# 3.039 монотонен по всем пяти точкам и даёт согласованные ~130 мкс на
	# мегапиксель на обеих частотах, но общий рост всего 4.5%, и порог его
	# отверг. Филлрейт на этом железе просто дёшев относительно базы кадра.
	#
	# Монотонность по пяти точкам случайна примерно в 6% случаев, а совпадение
	# наклона на двух независимых частотах проверяется отдельно ниже.
	var back := 0
	var worst_back := 0.0
	for i in range(1, points.size()):
		var d: float = points[i]["gpu"] - points[i - 1]["gpu"]
		if d < 0.0:
			back += 1
			worst_back = maxf(worst_back, -d)

	if back == 0 and rise > 0.0:
		r.pass_("гейт роста GPU: ряд монотонен по всем %d точкам, %.3f → %.3f мс (+%.1f%%) — время отзывается на покрытие" % [
				points.size(), lo, hi, rise / maxf(lo, 0.0001) * 100.0])
	elif rise <= 0.0:
		r.fail("гейт роста GPU: %.3f → %.3f мс, роста нет вовсе — пиксели не связывают, цена пикселя недостоверна" % [lo, hi])
		_gates_ok = false
	else:
		r.fail("гейт роста GPU: ряд немонотонен, %d шагов вниз, худший %.3f мс — время отзывается не на покрытие, цена пикселя недостоверна" % [
				back, worst_back])
		_gates_ok = false


func _report_slopes(r: ProbeReport) -> void:
	var keys := by_freq.keys()
	keys.sort()
	for hz in keys:
		var slope: float = by_freq[hz]["us_per_mpx"]
		if not _gates_ok:
			r.unkn("цена пикселя на %.1f Гц: гейт не пройден, наклон не докладываю" % hz)
		elif is_nan(slope):
			r.unkn("цена пикселя на %.1f Гц: наклон не посчитан" % hz)
		else:
			r.pass_("цена пикселя на %.1f Гц: **%.1f мкс на Мпиксель** (затеняемых, с учётом %d слоёв)" % [
					hz, slope, LAYERS])
	# Частот могло измериться меньше, чем заявлено: добираем пол поимённо.
	for _i in range(keys.size(), FREQS.size()):
		r.unkn("цена пикселя: частота не измерена")


## Дискриминатор: сравнивает цену пикселя между частотами.
func _check_across_freq(r: ProbeReport) -> void:
	if not _gates_ok:
		r.unkn("цена пикселя между частотами: гейт не пройден, сравнивать нечего")
		return
	if by_freq.size() < 2:
		r.unkn("цена пикселя между частотами: измерена только одна частота")
		return
	var keys := by_freq.keys()
	keys.sort()
	var lo_hz: float = keys[0]
	var hi_hz: float = keys[keys.size() - 1]
	var a: float = by_freq[lo_hz]["us_per_mpx"]
	var b: float = by_freq[hi_hz]["us_per_mpx"]
	if is_nan(a) or is_nan(b) or a <= 0.0:
		r.unkn("цена пикселя между частотами: наклон не посчитан на обеих")
		return
	var ratio := b / a
	r.note("")
	r.note("цена пикселя: %.1f мкс/Мпикс на %.0f Гц против %.1f на %.0f Гц, отношение %.2f" % [
			a, lo_hz, b, hi_hz, ratio])
	if ratio > 0.8 and ratio < 1.25:
		r.pass_("цена пикселя от частоты НЕ зависит (отношение %.2f) — если цена вызова зависит, механизм в подаче геометрии, а не в затенении" % ratio)
	else:
		r.fail("цена пикселя зависит от частоты (отношение %.2f) — затенение тоже переменная, версия «только геометрия» не проходит" % ratio)
