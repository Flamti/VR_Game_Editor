extends RefCounted
class_name ProbeFill

## Фаза P: цена пикселя. Свип по РАЗМЕРУ квада при одном объекте.
##
## Две задачи сразу.
##
## Первая: филлрейт числится в паспорте как «не измерено». Все свипы мерили
## крошечные квады специально, чтобы исключить пиксели, — и цена пикселя так
## и осталась неизвестной, хотя бюджет без неё не построить.
##
## Вторая, ради загадки 120 Гц: это ДИСКРИМИНАТОР. Если удешевление draw call
## на 120 Гц пиксельное по природе — оно обязано быть видно здесь, на оси
## пикселей, и сильнее, чем на геометрической. Если цена пикселя от частоты не
## зависит, а цена вызова зависит, механизм лежит в подаче геометрии и
## биннинге, а не в затенении.
##
## Покрытие не считается по формуле FOV, а СПРАШИВАЕТСЯ у камеры через
## unproject_position(): та же проекция, которой рендерит движок. Своя
## тригонометрия здесь была бы вторым источником истины (PRACTICES §1.6).

const ProbeReport := preload("res://probe_report.gd")
const ProbeStats := preload("res://probe_stats.gd")
const ProbeBudget := preload("res://probe_budget.gd")
const ProbeWindow := preload("res://probe_window.gd")

## Размеры квада в метрах на расстоянии 2 м. Ноль — контрольная точка.
##
## Верхняя граница поднята после обкатки: на 3 м рост времени GPU составил 16%
## и гейт «пиксели связывают» не сработал — сигнал тонул в базе. Квад должен
## закрывать заметную долю поля зрения, иначе меряется не филлрейт.
const SIZES := [0.0, 1.0, 2.5, 5.0, 9.0]

## Частоты, на которых повторяется вся ось. Ровно те же, что у матрицы.
const FREQS := [72.0, 120.0]

var _host: Node
var _container: Node3D
var _camera: Camera3D
var _vp: RID

## Гц → {"us_per_mpx": float, "points": Array}
var by_freq: Dictionary = {}


func expected_checks() -> int:
	# гейт покрытия 1, гейт роста GPU 1, сравнение частот 1, наклон на частоту
	return 3 + FREQS.size()


func setup(host: Node, parent: Node) -> void:
	_host = host
	_container = Node3D.new()
	_container.position = Vector3(0, 0, -2)
	parent.add_child(_container)
	_vp = host.get_viewport().get_viewport_rid()
	_camera = host.get_viewport().get_camera_3d()


func _clear() -> void:
	for c in _container.get_children():
		c.queue_free()


## Один непрозрачный квад по центру. Один, а не пачка: перекрывающиеся
## непрозрачные квады отсекаются ранним Z, и «покрытие» перестало бы
## соответствовать затенённым пикселям.
func _spawn(size: float) -> void:
	if size <= 0.0:
		return
	var mesh := QuadMesh.new()
	mesh.size = Vector2(size, size)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.4, 0.6, 0.8)
	mi.material_override = mat
	_container.add_child(mi)


## Покрытие в пикселях: углы квада прогоняются через проекцию камеры.
## NAN — камеры нет, спросить не у кого.
func _coverage_px(size: float) -> float:
	if _camera == null:
		return NAN
	if size <= 0.0:
		return 0.0
	var c := _container.global_position
	var half := size * 0.5
	var a := _camera.unproject_position(c + Vector3(-half, -half, 0.0))
	var b := _camera.unproject_position(c + Vector3(half, half, 0.0))
	return absf(b.x - a.x) * absf(b.y - a.y)


func run(r: ProbeReport) -> void:
	r.note("")
	r.note("--- P. Цена пикселя ---")
	if _camera == null:
		r.unkn("покрытие: камеры нет, посчитать пиксели нечем")
		for _i in expected_checks() - 1:
			r.unkn("цена пикселя: без покрытия измерять нечего")
		return

	for hz in FREQS:
		var res: Dictionary = await ProbeBudget.request_hz(_host, hz)
		var got: float = res["got"]
		var budget := ProbeBudget.ms_for_hz(got)
		# Без этого первая точка ряда завышена и наклон бессмыслен: на обкатке
		# «пустая сцена» на 120 Гц дала больше, чем все нагруженные точки.
		await ProbeWindow.settle(_host)
		var points: Array[Dictionary] = []
		r.note("")
		r.note("на %.1f Гц (запрошено %.0f), бюджет %.2f мс:" % [got, hz, budget])

		for size in SIZES:
			_clear()
			await _host.get_tree().process_frame
			_spawn(size)
			await _host.get_tree().process_frame
			var px := _coverage_px(size)
			var m: Dictionary = await ProbeWindow.measure(_host, _vp, budget)
			var gpu: ProbeStats = m["gpu"]
			points.append({"size": size, "px": px, "gpu": gpu.median(), "m": m})
			r.note("    размер %.2f м → покрытие %.3f Мпикс, GPU мед %.3f мс" % [
					size, px / 1000000.0, gpu.median()])
		_clear()
		by_freq[got] = {"points": points, "us_per_mpx": _slope(points)}
		var slope: float = by_freq[got]["us_per_mpx"]
		if is_nan(slope):
			r.unkn("цена пикселя на %.1f Гц: наклон не посчитан" % got)
		else:
			r.pass_("цена пикселя на %.1f Гц: **%.1f мкс на Мпиксель**" % [got, slope])

	_check_coverage_gate(r)
	_check_growth_gate(r)
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


## Гейт §2.5: покрытие обязано расти вместе с размером. Если проекция вернула
## одно и то же, ось меряет не то, что заявлено.
func _check_coverage_gate(r: ProbeReport) -> void:
	var any := by_freq.values()
	if any.is_empty():
		r.unkn("гейт покрытия: точек нет")
		return
	var points: Array = any[0]["points"]
	var ok := true
	for i in range(1, points.size()):
		if not (points[i]["px"] > points[i - 1]["px"]):
			ok = false
	if ok:
		r.pass_("гейт покрытия: пиксели растут вместе с размером, от %.3f до %.3f Мпикс" % [
				points[0]["px"] / 1000000.0, points[points.size() - 1]["px"] / 1000000.0])
	else:
		r.fail("гейт покрытия: покрытие НЕ растёт монотонно — проекция даёт не то, ось недействительна")


## Гейт §2.5: время GPU обязано отзываться на покрытие. Если не отзывается,
## случай до филлрейта не доходит, и наклон — число ни о чём.
func _check_growth_gate(r: ProbeReport) -> void:
	var any := by_freq.values()
	if any.is_empty():
		r.unkn("гейт роста GPU: точек нет")
		return
	var points: Array = any[0]["points"]
	var lo: float = points[0]["gpu"]
	var hi: float = points[points.size() - 1]["gpu"]
	if hi > lo * 1.2:
		r.pass_("гейт роста GPU: от %.3f до %.3f мс — случай задевает филлрейт" % [lo, hi])
	else:
		r.fail("гейт роста GPU: %.3f → %.3f мс, рост меньше 20%% — пиксели не связывают, цена пикселя недостоверна" % [lo, hi])


## Дискриминатор. Сравнивает цену пикселя между частотами с ценой вызова.
func _check_across_freq(r: ProbeReport) -> void:
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
	# Утверждение формулируется так, чтобы его можно было опровергнуть.
	if ratio > 0.8 and ratio < 1.25:
		r.pass_("цена пикселя от частоты НЕ зависит (отношение %.2f) — если цена вызова зависит, механизм в подаче геометрии, а не в затенении" % ratio)
	else:
		r.fail("цена пикселя зависит от частоты (отношение %.2f) — затенение тоже переменная, версия «только геометрия» не проходит" % ratio)
