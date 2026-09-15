extends RefCounted
class_name ProbeSynthesis

## Фаза S: цена и поведение frame synthesis (XR_EXT_frame_synthesis) на 90 Гц.
##
## Вопрос из ADR-0003 «Открыто»: расширение на устройстве есть (прогон 10), но
## что оно даёт и чего стоит, прибор не мерил. По документации Meta (App
## SpaceWarp) приложение при синтезе отдаёт кадры реже, а рантайм достраивает
## остальные по векторам движения и глубине; вектора движения рисуются
## дополнительным проходом — это и есть цена.
##
## Три режима: выкл, вкл, вкл + relax_frame_interval (явная просьба к рантайму
## принимать кадры реже). Порядок ABCCBA — дрейф сокращается, как в L4.
##
## Слову рантайма не верим (ловушка 14): что синтез реально включился, видно
## только по доставке кадров приложением, а не по свойству enabled.
##
## Нужна сборка пресета «Quest synthesis» (тег vrge_synthesis): в штатной
## расширение не запрошено, и фаза докладывает UNKNOWN по всем проверкам.
## Включается маркером user://synthesis.
##
## Артефакты синтеза прибор не мерит — только глаз. В конце фазы идёт визуальный
## отрезок v2 (см. _visual). v1 (прогон 22) переключал «вкл» без relax на пустой
## сцене: приложение отдавало все 90 кадров, синтезировать было нечего, и «разницы
## нет» ничего не значило (§2.5). Это требует надетого шлема.
##
## Независимый свидетель — строка VrApi композитора (tools/vrapi_log.sh):
## FPS=приложение/дисплей, Stale, ASW. Окна фазы пишутся в user://synthesis.tsv
## с unix-временем для свода (tools/join_windows.py --vrapi).

const ProbeReport := preload("res://probe_report.gd")
const ProbeStats := preload("res://probe_stats.gd")
const ProbeBudget := preload("res://probe_budget.gd")
const ProbeWindow := preload("res://probe_window.gd")

const SINGLETON := "OpenXRFrameSynthesisExtension"
const MODES := ["выкл", "вкл", "вкл+relax"]
const ORDER := [0, 1, 2, 2, 1, 0]
const POINTS := [0, 1600]
## Дрейф прибора за прогон (как в L4 и K).
const DRIFT_TOLERANCE := 0.15
## Доля доставки, ниже которой считаем, что рантайм перевёл приложение на
## пониженную частоту: половина частоты даёт 50%, шум доставки — единицы процентов.
const HALVED_SHARE := 0.75
const VISUAL_S := 40.0
const VISUAL_TOGGLE_S := 5.0
const TSV_PATH := "user://synthesis.tsv"

var _host: Node
var _viewport: Viewport
var _vp: RID
var _container: Node3D
var _ext: Object = null
var _hz := NAN
var _budget := NAN
var _tsv: FileAccess

## режим → Array повторов; повтор = {N → {"gpu","cpu","fps","calls","over"}}
var reps: Dictionary = {}


func expected_checks() -> int:
	# доступность 1; гейт состояния 1; контроль порядка 1; доставка по режимам 1;
	# цена векторов движения 1; гейт счётчика 1
	return 6


func setup(host: Node, parent: Node) -> void:
	_host = host
	_viewport = host.get_viewport()
	_vp = _viewport.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(_vp, true)
	_container = Node3D.new()
	ProbeWindow.attach_load(host, parent, _container)
	if Engine.has_singleton(SINGLETON):
		_ext = Engine.get_singleton(SINGLETON)


## Штатные фазы обязаны идти без синтеза. Вызывается оркестратором ДО замеров:
## включённое расширение стартует с enabled=true.
static func disable_if_present() -> String:
	if not Engine.has_singleton(SINGLETON):
		return "синглтона нет"
	var ext: Object = Engine.get_singleton(SINGLETON)
	if not ext.is_available():
		return "расширение не запрошено или не поддержано — синтеза нет"
	ext.enabled = false
	ext.relax_frame_interval = false
	return "расширение активно — синтез ВЫКЛЮЧЕН для штатных фаз"


func _clear_and_wait() -> void:
	for c in _container.get_children():
		c.queue_free()
	var guard := 0
	while _container.get_child_count() > 0 and guard < 60:
		await _host.get_tree().process_frame
		guard += 1


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


func _apply(mode: int) -> void:
	_ext.enabled = mode != 0
	_ext.relax_frame_interval = mode == 2


func run(r: ProbeReport) -> void:
	r.note("")
	r.note("--- S. Frame synthesis (XR_EXT_frame_synthesis, ADR-0003 открыто) ---")
	if _ext == null or not _ext.is_available():
		var why := "синглтона %s нет" % SINGLETON if _ext == null else "is_available()=false — сборка без тега vrge_synthesis или рантайм отказал"
		for _i in expected_checks():
			r.unkn("S: %s" % why)
		return

	var res: Dictionary = await ProbeBudget.request_target(_host)
	_hz = res["got"]
	_budget = ProbeBudget.ms_for_hz(_hz)
	r.note("частота %.1f Гц, бюджет %.2f мс; режимы %s в порядке %s; точки %s" % [
			_hz, _budget, str(MODES), str(ORDER.map(func(i): return MODES[i])), str(POINTS)])
	r.pass_("S доступность: расширение активно (is_available=true)")

	for i in MODES.size():
		reps[i] = []
	var bad: Array[String] = []
	_tsv = FileAccess.open(TSV_PATH, FileAccess.WRITE)
	if _tsv != null:
		_tsv.store_line("# unix_начало\tunix_конец\tрежим\tповтор\tN\tотрисовок\tGPU мед\tCPU мед\tкадров\tк/с\tсверх бюджета")

	for idx in ORDER:
		_apply(idx)
		await _clear_and_wait()
		await ProbeWindow.settle(_host, 2.0)
		if _ext.enabled != (idx != 0) or _ext.relax_frame_interval != (idx == 2):
			bad.append("%s: enabled=%s relax=%s" % [MODES[idx], _ext.enabled, _ext.relax_frame_interval])
		var ladder := {}
		r.note("  режим %s (повтор %d):" % [MODES[idx], reps[idx].size() + 1])
		for n in POINTS:
			await _clear_and_wait()
			await ProbeWindow.wait_until_idle(_host, _vp)
			_spawn(n)
			await ProbeWindow.settle(_host, 0.5)
			var t0 := Time.get_unix_time_from_system()
			var m: Dictionary = await ProbeWindow.measure(_host, _vp, _budget)
			var t1 := Time.get_unix_time_from_system()
			var gpu: ProbeStats = m["gpu"]
			var cpu: ProbeStats = m["cpu"]
			ladder[n] = {"gpu": gpu.median(), "cpu": cpu.median(), "fps": m["fps"],
					"calls": m["calls"], "over": m["over"]}
			if _tsv != null:
				_tsv.store_line("%.3f\t%.3f\t%s\t%d\t%d\t%d\t%.3f\t%.3f\t%d\t%.1f\t%d" % [
						t0, t1, MODES[idx], reps[idx].size() + 1, n, m["calls"], gpu.median(), cpu.median(),
						m["frames"], m["fps"], m["over"]])
				_tsv.flush()
			r.note("    N=%-5d отрисовок %-5d GPU %.3f  CPU %.3f мс; %s" % [
					n, m["calls"], gpu.median(), cpu.median(), ProbeWindow.delivery_brief(m, _hz)])
		reps[idx].append(ladder)

	await _clear_and_wait()
	_apply(0)
	if _tsv != null:
		_tsv.close()
		r.note("окна фазы: %s — свод с VrApi: tools/join_windows.py --vrapi" % ProjectSettings.globalize_path(TSV_PATH))

	if bad.is_empty():
		r.pass_("S гейт состояния: enabled и relax вставали в каждый режим")
	else:
		r.fail("S гейт состояния: %s" % "; ".join(bad))
	_check_calls(r)
	_check_order(r)
	_delivery(r)
	_cost(r)

	await _visual(r)


func _check_calls(r: ProbeReport) -> void:
	var miss: Array[String] = []
	for i in MODES.size():
		for ladder in reps[i]:
			for n in POINTS:
				if int(ladder[n]["calls"]) != n:
					miss.append("%s N=%d→%d" % [MODES[i], n, ladder[n]["calls"]])
	if miss.is_empty():
		r.pass_("S гейт счётчика: все точки дали ровно N отрисовок")
	else:
		r.fail("S гейт счётчика: %s" % ", ".join(miss))


## Первый и последний повтор режима «выкл» обязаны совпасть: иначе сравнение
## режимов меряет дрейф, а не синтез.
func _check_order(r: ProbeReport) -> void:
	var a: Dictionary = reps[0][0]
	var b: Dictionary = reps[0][reps[0].size() - 1]
	var n_hi: int = POINTS[POINTS.size() - 1]
	var rel := absf(float(a[n_hi]["gpu"]) - float(b[n_hi]["gpu"])) / maxf(minf(a[n_hi]["gpu"], b[n_hi]["gpu"]), 0.001)
	if rel <= DRIFT_TOLERANCE:
		r.pass_("S контроль порядка: «выкл» в начале и в конце на N=%d расходятся на %.1f%% — в пределах дрейфа %.0f%%" % [
				n_hi, rel * 100.0, DRIFT_TOLERANCE * 100.0])
	else:
		r.fail("S контроль порядка: «выкл» в начале и в конце на N=%d расходятся на %.1f%% — больше дрейфа %.0f%%, сравнение режимов недостоверно" % [
				n_hi, rel * 100.0, DRIFT_TOLERANCE * 100.0])


## Доставка кадров приложением по режимам — единственный свидетель того, что
## синтез что-то сделал (ловушка 14).
func _delivery(r: ProbeReport) -> void:
	var parts: PackedStringArray = []
	var halved: Array[String] = []
	for i in MODES.size():
		var fps: Array[float] = []
		for ladder in reps[i]:
			for n in POINTS:
				fps.append(float(ladder[n]["fps"]))
		var share := _mean(fps) / _hz
		parts.append("%s %.1f к/с (%.0f%%)" % [MODES[i], _mean(fps), share * 100.0])
		if share < HALVED_SHARE:
			halved.append(MODES[i])
	var verdict: String
	if halved.is_empty():
		verdict = "ни в одном режиме приложение не перешло на пониженную частоту — синтез не проявился в доставке"
	elif halved.has(MODES[0]):
		verdict = "доставка просела и БЕЗ синтеза — фаза меряет перегрузку, а не синтез"
	else:
		verdict = "пониженная частота приложения в режимах %s — синтез работает" % str(halved)
	if halved.has(MODES[0]):
		r.fail("S доставка: %s — %s" % ["; ".join(parts), verdict])
	else:
		r.pass_("S доставка: %s — %s" % ["; ".join(parts), verdict])


## Цена векторов движения: GPU на кадр приложения, «вкл» против «выкл».
func _cost(r: ProbeReport) -> void:
	var parts: PackedStringArray = []
	for n in POINTS:
		var off := _mean(reps[0].map(func(l): return l[n]["gpu"]))
		var off_spread := absf(float(reps[0][0][n]["gpu"]) - float(reps[0][reps[0].size() - 1][n]["gpu"]))
		for i in [1, 2]:
			var on := _mean(reps[i].map(func(l): return l[n]["gpu"]))
			var d := on - off
			parts.append("N=%d %s %+.3f мс%s" % [n, MODES[i], d, " ЗНАЧИМО" if absf(d) > off_spread * 2.0 else " в шуме"])
	r.pass_("S цена на кадр приложения (GPU против «выкл», порог — два разброса «выкл»): %s" % "; ".join(parts))


## Визуальный отрезок v2: relax против выкл, сцена из известных источников
## артефактов App SpaceWarp (документация Meta): прозрачное поверх движущегося в
## другую сторону, быстрое вращение, объект вблизи лица, движущийся текст (как
## меню) — на однотонном фоне, где искажения заметнее всего. Режим меняется
## каждые 5 с; предметы цвет НЕ меняют — режим показывает квадрат-индикатор
## слева: ЗЕЛЁНЫЙ — синтез (relax, приложение 45 к/с), КРАСНЫЙ — без синтеза (90 к/с).
## Сравнение «синтезированные 90» против «настоящих 90» — то, что увидит пользователь.
func _visual(r: ProbeReport) -> void:
	r.note("")
	r.note("S визуально v2: %.0f с, режим каждые %.0f с. Квадрат слева ЗЕЛЁНЫЙ — синтез relax (45 к/с приложения), КРАСНЫЙ — без синтеза (90)" % [VISUAL_S, VISUAL_TOGGLE_S])
	var root := Node3D.new()
	_host.add_child(root)
	var cam := _viewport.get_camera_3d()
	if cam != null:
		var fwd := -cam.global_transform.basis.z
		fwd.y = 0.0
		root.global_transform = Transform3D(Basis.looking_at(fwd.normalized() if fwd.length() > 0.01 else Vector3.FORWARD), cam.global_position)

	var bar := _box(Vector3(0.05, 0.6, 0.05), Color(0.95, 0.95, 0.95), false)
	var glass := _box(Vector3(0.35, 0.25, 0.01), Color(0.2, 0.5, 1.0, 0.45), true)
	var cube := _box(Vector3(0.15, 0.15, 0.15), Color(0.9, 0.6, 0.1), false)
	var near := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.04
	sph.height = 0.08
	near.mesh = sph
	near.material_override = _mat(Color(0.8, 0.2, 0.8), false)
	var text := Label3D.new()
	text.text = "Меню: Открыть  Сохранить  Выход"
	text.font_size = 48
	text.pixel_size = 0.0015
	text.modulate = Color(1, 1, 1)
	var flag := _box(Vector3(0.08, 0.08, 0.01), Color(1, 0, 0), false)
	for n in [bar, glass, cube, near, text, flag]:
		root.add_child(n)
	flag.position = Vector3(-0.9, 0.35, -1.6)

	var t0 := Time.get_ticks_msec()
	var on := false
	var next_toggle := 0.0
	while true:
		await _host.get_tree().process_frame
		var s := (Time.get_ticks_msec() - t0) / 1000.0
		if s >= VISUAL_S:
			break
		if s >= next_toggle:
			on = not on
			_apply(2 if on else 0)
			(flag.material_override as StandardMaterial3D).albedo_color = Color(0.1, 0.9, 0.2) if on else Color(0.9, 0.1, 0.1)
			r.note("    %.0f с (unix %.1f): %s" % [s, Time.get_unix_time_from_system(), "СИНТЕЗ relax (зелёный)" if on else "БЕЗ синтеза (красный)"])
			next_toggle += VISUAL_TOGGLE_S
		bar.position = Vector3(sin(s * 2.0) * 0.6, 0.0, -1.5)
		glass.position = Vector3(-sin(s * 2.0) * 0.6, 0.0, -1.45)
		cube.position = Vector3(0.6, -0.3, -1.5)
		cube.rotation = Vector3(s * 3.0, s * 25.0, 0.0)
		near.position = Vector3(sin(s * 3.0) * 0.15, -0.1, -0.35)
		text.position = Vector3(sin(s * 1.5) * 0.4, 0.3, -1.5)
	root.queue_free()
	_apply(0)


func _mat(c: Color, transparent: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	if transparent:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


func _box(size: Vector3, c: Color, transparent: bool) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = _mat(c, transparent)
	return mi


static func _mean(a: Array) -> float:
	if a.is_empty():
		return NAN
	var s := 0.0
	for v in a:
		s += float(v)
	return s / a.size()
