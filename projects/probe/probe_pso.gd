extends RefCounted
class_name ProbePso

## Фаза W: компиляция конвейеров (PSO) — сколько, когда и во что обходится кадру.
##
## Зачем отдельно от C–D. Прежнее «+5.192 мс разогрева PSO» (прогон 10) — пик
## первых кадров точки N=100. Но конвейер этого материала уже скомпилирован на
## точке N=50: пик N=100 компиляцией быть не обязан. Число стояло без свидетеля.
##
## Свидетель — счётчики движка Performance.PIPELINE_COMPILATIONS_* (Godot 4.4+,
## docs.godotengine.org/en/4.5/tutorials/performance/pipeline_compilations.html):
## DRAW — компиляции прямо во время отрисовки, то есть заикание; MESH, SURFACE,
## CANVAS, SPECIALIZATION — компиляции при загрузке. Shader baker (пресет
## «Quest baker») переносит компиляцию шейдеров на экспорт; какие из счётчиков
## и время старта это меняет — вопрос прогона, а не документации.
##
## Схема: новый, ни разу не виденный вариант материала → первые кадры против
## установившихся и приращение счётчиков. Контроль: тот же вариант повторно после
## очистки — пик обязан исчезнуть (кэш). Счётчики при повторе растут снова: они
## считают запросы на создание конвейера, а не компиляции с нуля (обкатка 2026-09-14).
##
## Кэш конвейеров Godot живёт на устройстве после первого запуска. Холодный
## кэш — только после `adb shell pm clear org.flamti.vrge.probe`; сравнивать
## baker вкл/выкл имеет смысл лишь на холодном.

const ProbeReport := preload("res://probe_report.gd")
const ProbeStats := preload("res://probe_stats.gd")
const ProbeBudget := preload("res://probe_budget.gd")
const ProbeWindow := preload("res://probe_window.gd")

const COUNTERS := {
	"canvas": Performance.PIPELINE_COMPILATIONS_CANVAS,
	"mesh": Performance.PIPELINE_COMPILATIONS_MESH,
	"surface": Performance.PIPELINE_COMPILATIONS_SURFACE,
	"draw": Performance.PIPELINE_COMPILATIONS_DRAW,
	"specialization": Performance.PIPELINE_COMPILATIONS_SPECIALIZATION,
}
const MESH_A := preload("res://pso_mesh_a.tres")
const MAT_B := preload("res://pso_mat_b.tres")
const FIRST_FRAMES := 30
const STEADY_S := 2.0

var _host: Node
var _vp: RID
var _container: Node3D
var startup_ms := -1
var at_start: Dictionary = {}
var first_spike_ms := NAN
var first_draw_compiles := -1
var repeat_draw_compiles := -1
## W2: пик первого появления варианта A (предзагружен) и B (override без предзагрузки).
var spike_a_ms := NAN
var spike_b_ms := NAN


func expected_checks() -> int:
	# старт и счётчики при загрузке 1; новый вариант 1; контроль повтора 1;
	# W2 предзагрузка .tres против override 1
	return 4


## Вызывается первым делом в _ready оркестратора: время от старта движка.
func capture_startup() -> void:
	startup_ms = Time.get_ticks_msec()
	at_start = _read()


func setup(host: Node, parent: Node) -> void:
	_host = host
	_vp = host.get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(_vp, true)
	_container = Node3D.new()
	ProbeWindow.attach_load(host, parent, _container)


## Признак baker — запечённый кэш в пакете, а не OS.has_feature("shader_baker"):
## признак экспорта в project.binary не попадает (проверено по APK 2026-09-14,
## в baker-сборке 45 файлов .godot/shader_cache/*.vulkan.cache, строки признака нет).
static func has_baked_shaders() -> bool:
	return DirAccess.dir_exists_absolute("res://.godot/shader_cache")


static func _read() -> Dictionary:
	var d := {}
	for k in COUNTERS:
		d[k] = int(Performance.get_monitor(COUNTERS[k]))
	return d


static func _delta(a: Dictionary, b: Dictionary) -> Dictionary:
	var d := {}
	for k in COUNTERS:
		d[k] = int(b.get(k, 0)) - int(a.get(k, 0))
	return d


## Вариант, которого нет ни в одной фазе: прозрачность, эмиссия, римлайт и
## двусторонность дают отдельную специализацию шейдера StandardMaterial3D.
func _spawn_variant() -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 0.05
	mesh.height = 0.1
	for i in 16:
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(0.2, 0.6, 1.0, 0.5)
		mat.emission_enabled = true
		mat.emission = Color(0.1, 0.1, 0.4)
		mat.rim_enabled = true
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mi.material_override = mat
		mi.position = Vector3((i % 4) * 0.12 - 0.18, (i / 4) * 0.12 - 0.18, 0.0)
		_container.add_child(mi)


func _clear_and_wait() -> void:
	for c in _container.get_children():
		c.queue_free()
	var guard := 0
	while _container.get_child_count() > 0 and guard < 60:
		await _host.get_tree().process_frame
		guard += 1


## W2, эпизод A: меш из .tres, материал на поверхности, вариант предзагружен
## невидимым узлом pso_warm.tscn в main.tscn.
func _spawn_a() -> void:
	for i in 16:
		var mi := MeshInstance3D.new()
		mi.mesh = MESH_A
		mi.position = Vector3((i % 4) * 0.12 - 0.18, (i / 4) * 0.12 - 0.18, 0.0)
		_container.add_child(mi)


## W2, эпизод B: material_override из .tres, без предзагрузки.
func _spawn_b() -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 0.05
	mesh.height = 0.1
	for i in 16:
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = MAT_B
		mi.position = Vector3((i % 4) * 0.12 - 0.18, (i / 4) * 0.12 - 0.18, 0.0)
		_container.add_child(mi)


## Первые кадры после появления варианта: макс CPU и GPU, приращение счётчиков.
func _episode(spawn: Callable = Callable()) -> Dictionary:
	var before := _read()
	if spawn.is_valid():
		spawn.call()
	else:
		_spawn_variant()
	var cpu := ProbeStats.new()
	var gpu := ProbeStats.new()
	for _i in FIRST_FRAMES:
		await _host.get_tree().process_frame
		cpu.add(RenderingServer.viewport_get_measured_render_time_cpu(_vp))
		gpu.add(RenderingServer.viewport_get_measured_render_time_gpu(_vp))
	var mid := _read()
	var steady: Dictionary = await ProbeWindow.measure(_host, _vp, NAN, 0.5, STEADY_S)
	var s_cpu: ProbeStats = steady["cpu"]
	var s_gpu: ProbeStats = steady["gpu"]
	return {
		"compiles": _delta(before, mid),
		"late": _delta(mid, _read()),
		"cpu_peak": cpu.maximum(), "gpu_peak": gpu.maximum(),
		"cpu_steady": s_cpu.median(), "gpu_steady": s_gpu.median(),
	}


func run(r: ProbeReport) -> void:
	r.note("")
	r.note("--- W. Компиляция конвейеров (PSO) ---")
	var baker := has_baked_shaders()
	r.note("сборка: shader baker %s (res://.godot/shader_cache в пакете)" % ("ВКЛ" if baker else "выкл"))

	if startup_ms < 0:
		r.unkn("W старт: capture_startup() не вызван")
	else:
		r.pass_("W старт: %d мс от запуска движка до _ready; компиляций к этому моменту %s; baker %s" % [
				startup_ms, str(at_start), "вкл" if baker else "выкл"])

	await _clear_and_wait()
	await ProbeWindow.wait_until_idle(_host, _vp)
	await ProbeWindow.settle(_host)
	var first: Dictionary = await _episode()
	await _clear_and_wait()
	await ProbeWindow.settle(_host)
	var again: Dictionary = await _episode()
	await _clear_and_wait()
	await ProbeWindow.settle(_host)
	var ep_a: Dictionary = await _episode(_spawn_a)
	await _clear_and_wait()
	await ProbeWindow.settle(_host)
	var ep_b: Dictionary = await _episode(_spawn_b)
	await _clear_and_wait()
	spike_a_ms = maxf(ep_a["cpu_peak"] - ep_a["cpu_steady"], ep_a["gpu_peak"] - ep_a["gpu_steady"])
	spike_b_ms = maxf(ep_b["cpu_peak"] - ep_b["cpu_steady"], ep_b["gpu_peak"] - ep_b["gpu_steady"])

	first_draw_compiles = first["compiles"]["draw"]
	repeat_draw_compiles = again["compiles"]["draw"]
	var peak := maxf(first["cpu_peak"] - first["cpu_steady"], first["gpu_peak"] - first["gpu_steady"])
	first_spike_ms = peak
	r.pass_("W новый вариант: компиляции за %d кадров %s (позже ещё %s); пик CPU %.3f / GPU %.3f против установившихся %.3f / %.3f мс — цена %.3f мс" % [
			FIRST_FRAMES, str(first["compiles"]), str(first["late"]),
			first["cpu_peak"], first["gpu_peak"], first["cpu_steady"], first["gpu_steady"], peak])

	# Контроль — по ЦЕНЕ, а не по счётчику. Обкатка 2026-09-14 показала: повтор
	# того же варианта снова даёт surface 2, draw 1, specialization 1, но пик
	# 5.7 мс против 959 мс в первый раз. Счётчик Godot считает запросы на создание
	# конвейера, а повтор попадает в кэш драйвера. Кэш работает, если повтор
	# дешевле первого эпизода хотя бы вдесятеро; иначе пик первого эпизода —
	# не компиляция, и цену PSO из него брать нельзя.
	var again_peak := maxf(again["cpu_peak"] - again["cpu_steady"], again["gpu_peak"] - again["gpu_steady"])
	# Порог 100 мс — как у контроля W2: компиляция с нуля стоила 889–1101 мс
	# (прогоны 18, 20), а при тёплом кэше появление стоит 4–8 мс. Ниже порога
	# компилировать было нечего — это UNKNOWN, а не отказ (прогон 24 покраснел
	# на 7.4 против 4.8 мс при тёплом кэше).
	if first_spike_ms <= 100.0:
		r.unkn("W контроль повтора: в первом эпизоде компиляции с нуля нет (пик %.3f мс) — кэш тёплый, сравнивать нечего; повтор %.3f мс, счётчики %s" % [
				first_spike_ms, again_peak, str(again["compiles"])])
	elif again_peak * 10.0 < first_spike_ms:
		r.pass_("W контроль повтора: пик %.3f мс против %.3f в первый раз (в %.0f раз меньше) — первый пик был компиляцией, кэш её снял; счётчики повтора %s — это запросы, а не компиляции с нуля" % [
				again_peak, first_spike_ms, first_spike_ms / maxf(again_peak, 0.001), str(again["compiles"])])
	else:
		r.fail("W контроль повтора: пик %.3f мс против %.3f в первый раз — кэш не снял цену, пик первого эпизода НЕ подтверждён как компиляция; счётчики %s" % [
				again_peak, first_spike_ms, str(again["compiles"])])

	_preload_check(r, ep_a, ep_b)


## W2: снимает ли предзагрузка варианта (материал на меше, сцена инстанцирована
## при загрузке) пик первого появления. Контроль — эпизод B: на холодном кэше
## он обязан дать пик компиляции; без него (тёплый кэш) сравнение ничего не
## решает и вердикт — UNKNOWN. Порог «вдесятеро» — тот же, что у контроля повтора.
func _preload_check(r: ProbeReport, a: Dictionary, b: Dictionary) -> void:
	var msg := "A (.tres на поверхности, предзагружен): пик %.3f мс, компиляции %s; B (override из .tres, без предзагрузки): пик %.3f мс, компиляции %s; baker %s" % [
			spike_a_ms, str(a["compiles"]), spike_b_ms, str(b["compiles"]),
			"вкл" if has_baked_shaders() else "выкл"]
	if spike_b_ms <= 100.0:
		r.unkn("W2 предзагрузка: контроль B без пика компиляции — кэш тёплый, сравнивать нечего. %s" % msg)
	elif spike_a_ms * 10.0 < spike_b_ms:
		r.pass_("W2 предзагрузка СНИМАЕТ пик: %s" % msg)
	else:
		r.pass_("W2 предзагрузка НЕ снимает пик: %s" % msg)
