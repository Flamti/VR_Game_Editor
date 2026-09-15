extends RefCounted

## Самопроверка на шлеме при запуске (Ф2, шаги 1б–1в). ~40 с, ШЛЕМ НА ГОЛОВЕ: без
## присутствия шлем засыпает, рендер встаёт, и проверка зависает (запуск 2026-09-15).
##
## Проверяет укладку, а не бюджет: число из паспорта сюда не переносится,
## проверяется, что прототип в худшей раскладке помещается в 11.11 мс на 90 Гц.
## Пол — по числу исполненных проверок (PRACTICES §1.2).
##
## Время скриптов меряется отдельно (Performance.TIME_PROCESS): измеренное время
## рендера вьюпорта не включает GDScript. Связывающее ограничение (CLAUDE.md,
## правило 2) — это три числа: GPU, CPU рендера и скрипты.

const Report := preload("res://probe_report.gd")
const ProbeBudget := preload("res://probe_budget.gd")
const ProbeWindow := preload("res://probe_window.gd")
const ProbeStats := preload("res://probe_stats.gd")
const Menu := preload("res://menu/sphere_menu.gd")
const Settings := preload("res://menu/settings.gd")
const SettingEdit := preload("res://menu/setting_edit.gd")
const UiPanel := preload("res://menu/ui_panel.gd")

## Прогрев судится по счётчику компиляций поверхности (урок фазы W прибора):
## счётчики считают запросы, эталон W2 — прогретый путь даёт surface 0, draw 1.
const COUNTERS := {
	"surface": Performance.PIPELINE_COMPILATIONS_SURFACE,
	"draw": Performance.PIPELINE_COMPILATIONS_DRAW,
	"specialization": Performance.PIPELINE_COMPILATIONS_SPECIALIZATION,
}
## Скорость вращения для худшего случая, рад/с: активная меняется часто.
const WORST_SPIN := 1.5

var r: Report = Report.new()
var expected := 0
var results := {}


func run(host: Node, menu: Menu) -> bool:
	var checks := ["xr", "частота", "msaa", "прогрев", "глобус худший", "глобус крупный", "линза худшая",
			"атлас", "панель", "панель лучом", "пропуск перерисовки"]
	expected = checks.size()
	r.note("=== САМОПРОВЕРКА ШАР-МЕНЮ ===")
	r.note("ожидается исполненных проверок: %d" % expected)
	var vp := host.get_viewport()
	var rid := vp.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(rid, true)

	var iface := XRServer.find_interface("OpenXR")
	if iface != null and iface.is_initialized() and vp.use_xr:
		r.pass_("XR: интерфейс поднят, вьюпорт в шлем")
	else:
		r.fail("XR: интерфейс %s, use_xr=%s" % ["нет" if iface == null else "не поднят", vp.use_xr])

	var hz := ProbeBudget.current_hz()
	if ProbeBudget.same_hz(hz, ProbeBudget.TARGET_HZ):
		r.pass_("частота %.1f Гц — цель ADR-0007" % hz)
	else:
		r.fail("частота %.1f Гц вместо %.0f" % [hz, ProbeBudget.TARGET_HZ])
	var budget := ProbeBudget.ms_for_hz(hz if hz > 1.0 else ProbeBudget.TARGET_HZ)

	if vp.msaa_3d == Viewport.MSAA_2X:
		r.pass_("MSAA 2x на XR-вьюпорте (ADR-0003 п. 6)")
	else:
		r.fail("MSAA %d вместо 2x" % vp.msaa_3d)

	# Худший глобус: самый большой радиус и самая мелкая ячейка — потолок частоты.
	var st: Settings = menu.settings
	st.values["surface"] = "globe"
	st.values["radius_cm"] = Settings.SPEC["radius_cm"]["max"]
	st.values["cell_cm"] = Settings.SPEC["cell_cm"]["min"]
	menu.apply_settings()
	var before := _counters()
	menu.toggle()
	var first := ProbeStats.new()
	for _i in 30:
		await host.get_tree().process_frame
		first.add(RenderingServer.viewport_get_measured_render_time_cpu(rid)
				+ Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
	var compiled := _delta(before, _counters())
	if compiled["surface"] == 0:
		r.pass_("прогрев: за 30 кадров первого открытия (ячейки, панель, луч) surface 0 %s; пик CPU+скрипты %.1f мс" % [str(compiled), first.maximum()])
	else:
		r.fail("прогрев: за 30 кадров первого открытия %s — конвейер собирался в кадре; пик CPU+скрипты %.1f мс" % [str(compiled), first.maximum()])

	menu.debug_spin = WORST_SPIN
	var g: Dictionary = await _measure(host, rid, budget)
	_budget_check("глобус уровень %d, %d ячеек, вращение" % [st.globe_frequency(), menu.renderer.drawn], g, budget)

	# Крупный глобус (шаг 1в, до ~7 ячеек на виду): ячеек мало, но каждая — большой
	# квад во весь шар; связывать может заполнение, а не вызовы.
	st.values["cell_cm"] = Settings.SPEC["cell_cm"]["max"]
	menu.apply_settings()
	await ProbeWindow.settle(host, 0.5)
	var big: Dictionary = await _measure(host, rid, budget)
	_budget_check("глобус крупный: уровень %d, %d ячеек, радиус %s см, вращение" % [st.globe_frequency(), menu.renderer.drawn, st.get_value("radius_cm")], big, budget)
	st.values["cell_cm"] = Settings.SPEC["cell_cm"]["min"]

	st.values["surface"] = "lens"
	menu.apply_settings()
	await ProbeWindow.settle(host, 0.5)
	var l: Dictionary = await _measure(host, rid, budget)
	_budget_check("линза α=%.3f, %d ячеек, вращение" % [st.lens_alpha(), menu.renderer.drawn], l, budget)
	menu.debug_spin = 0.0

	var tex := menu.atlas.texture()
	var icon_ok: bool = menu.atlas.icon("folder") != null and menu.atlas.icon("delete") != null
	if tex != null and tex.get_width() == menu.atlas.viewport.size.x and menu.atlas.renders > 0 and icon_ok:
		r.pass_("атлас: %dx%d, перерисован %d раз, иконки загружаются" % [tex.get_width(), tex.get_height(), menu.atlas.renders])
	else:
		r.fail("атлас: текстура %s, перерисовок %d, иконки %s" % [tex, menu.atlas.renders, icon_ok])

	var pnl = menu.panel
	var img: Texture2D = pnl.preview_of(menu.catalog.items["img_map"]) if pnl != null else null
	if pnl != null and pnl.renders > 0 and img != null and pnl.viewport.get_texture() != null:
		r.pass_("панель: перерисована %d раз, предпросмотр изображения %dx%d" % [pnl.renders, img.get_width(), img.get_height()])
	else:
		r.fail("панель: %s, перерисовок %s, предпросмотр %s" % [pnl, pnl.renders if pnl != null else -1, img])

	# Панель лучом: правка открыта, луч из точки перед панелью на ползунок, нажатие и
	# перетаскивание — значение меняется, панель перерисована. Проверяет путь
	# push_input в XR-сборке, а не в безголовом прогоне.
	if pnl != null and pnl.has_method("open_editor"):
		var saved_r: Variant = st.get_value("radius_cm")
		st.values["radius_cm"] = 11.0
		pnl.visible = true
		pnl.open_editor(SettingEdit.new(st, "radius_cm"), "самопроверка", ["done"])
		for _i in 3:
			await host.get_tree().process_frame
		var rect: Rect2 = pnl._slider.get_global_rect()
		var renders0: int = pnl.renders
		var a: Variant = _aim(pnl, rect.position + Vector2(rect.size.x * 0.2, rect.size.y * 0.5))
		var b: Variant = _aim(pnl, rect.position + Vector2(rect.size.x * 0.8, rect.size.y * 0.5))
		pnl.pointer_update(a, false)
		pnl.pointer_update(a, true)
		await host.get_tree().process_frame
		pnl.pointer_update(b, true)
		await host.get_tree().process_frame
		pnl.pointer_update(b, false)
		pnl.pointer_update(null, false)
		var got := float(st.get_value("radius_cm"))
		var drawn_n: int = pnl.renders - renders0
		pnl.close_editor()
		st.values["radius_cm"] = saved_r
		menu.apply_settings()
		if a != null and b != null and got > 15.0 and drawn_n > 0:
			r.pass_("панель лучом: ползунок 20%% → 80%%, радиус 11 → %s см, панель перерисована %d раз" % [got, drawn_n])
		else:
			r.fail("панель лучом: попадания %s/%s, радиус %s, перерисовок %d" % [a, b, got, drawn_n])
	else:
		r.fail("панель лучом: панель без правки (%s)" % pnl)

	# Пропуск перерисовки: неподвижный глобус не пересчитывается, скрипты падают.
	st.values["surface"] = "globe"
	menu.apply_settings()
	await ProbeWindow.settle(host, 0.8)
	var redraws0: int = menu.renderer.redraws
	var still: Dictionary = await _measure(host, rid, budget)
	var redrawn: int = menu.renderer.redraws - redraws0
	var still_proc: float = (still["process"] as ProbeStats).percentile(0.95)
	var spin_proc: float = results.values()[0]["proc95"] if not results.is_empty() else NAN
	if redrawn <= 2 and still_proc < spin_proc:
		r.pass_("пропуск перерисовки: неподвижный глобус пересчитан %d раз, скрипты p95 %.2f мс против %.2f при вращении" % [redrawn, still_proc, spin_proc])
	else:
		r.fail("пропуск перерисовки: пересчётов %d, скрипты p95 %.2f мс против %.2f при вращении" % [redrawn, still_proc, spin_proc])

	menu.close()
	return _verdict()


## Луч из точки перед панелью в пиксель её вьюпорта.
static func _aim(pnl: Node3D, px: Vector2) -> Variant:
	var local := Vector3((px.x / UiPanel.VIEW_SIZE.x - 0.5) * UiPanel.QUAD.x, (0.5 - px.y / UiPanel.VIEW_SIZE.y) * UiPanel.QUAD.y, 0.0)
	var world: Vector3 = pnl.global_transform * local
	var origin: Vector3 = world + pnl.global_basis.z * 0.3
	return pnl.pointer_ray(origin, (world - origin).normalized())


func _measure(host: Node, rid: RID, budget: float) -> Dictionary:
	var proc := ProbeStats.new()
	var m: Dictionary = await ProbeWindow.measure(host, rid, budget)
	# Время скриптов снимается СЛЕДОМ за окном, столько же кадров: ProbeWindow —
	# побайтовая копия прибора, её не расширяем. Режим тот же, кадры другие.
	for _i in int(m["frames"]):
		await host.get_tree().process_frame
		proc.add(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
	m["process"] = proc
	return m


func _budget_check(label: String, m: Dictionary, budget: float) -> void:
	var gpu: ProbeStats = m["gpu"]
	var cpu: ProbeStats = m["cpu"]
	var proc: ProbeStats = m["process"]
	var g95 := gpu.percentile(0.95)
	var c95 := cpu.percentile(0.95) + proc.percentile(0.95)
	var binding := "GPU" if g95 >= c95 else "CPU (рендер %.2f + скрипты %.2f)" % [cpu.percentile(0.95), proc.percentile(0.95)]
	results[label] = {"gpu95": g95, "cpu95": cpu.percentile(0.95), "proc95": proc.percentile(0.95), "over": m["over"]}
	var msg := "%s: p95 GPU %.2f / CPU рендера+скриптов %.2f мс из %.2f, связывает %s; %s" % [
			label, g95, c95, budget, binding, ProbeWindow.delivery_brief(m, 1000.0 / budget)]
	if maxf(g95, c95) <= budget and int(m["over"]) == 0:
		r.pass_(msg)
	else:
		r.fail(msg)


func _verdict() -> bool:
	var total := r.executed()
	r.note("passed=%d failed=%d unknown=%d" % [r.passed, r.failed, r.unknown])
	if total != expected:
		r.note("ОТКАЗ ПРИБОРА: исполнено %d проверок из %d" % [total, expected])
		return false
	r.note("пол: исполнено %d/%d проверок" % [total, expected])
	return r.failed == 0


static func _counters() -> Dictionary:
	var d := {}
	for k in COUNTERS:
		d[k] = int(Performance.get_monitor(COUNTERS[k]))
	return d


static func _delta(a: Dictionary, b: Dictionary) -> Dictionary:
	var d := {}
	for k in COUNTERS:
		d[k] = int(b[k]) - int(a[k])
	return d
