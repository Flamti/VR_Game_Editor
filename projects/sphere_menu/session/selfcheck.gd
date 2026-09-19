extends RefCounted

## Самопроверка на шлеме при запуске (Ф2, шаги 1б–1в). ~85 с (40 до пар окон пропуска перерисовки, 10 — подписи), ШЛЕМ НА ГОЛОВЕ: без
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
const Pin := preload("res://profile/pin.gd")
## Вход по PIN — не дольше этого, мс (docs/design/user-profiles.md §8). Цель, а не измерение: столько
## человек ждёт после «Готово», не замечая задержки.
const PIN_TARGET_MS := 300.0

## Прогрев судится по счётчику компиляций поверхности (урок фазы W прибора):
## счётчики считают запросы, эталон W2 — прогретый путь даёт surface 0, draw 1.
const COUNTERS := {
	"surface": Performance.PIPELINE_COMPILATIONS_SURFACE,
	"draw": Performance.PIPELINE_COMPILATIONS_DRAW,
	"specialization": Performance.PIPELINE_COMPILATIONS_SPECIALIZATION,
}
## Скорость вращения для худшего случая, рад/с: активная меняется часто.
const WORST_SPIN := 1.5
## Пар окон «покой, вращение» подряд в проверке пропуска перерисовки. Чётное — медиана по
## двум средним.
const REDRAW_PAIRS := 4

var r: Report = Report.new()
var expected := 0
var results := {}


func run(host: Node, menu: Menu) -> bool:
	var checks := ["xr", "частота", "msaa", "прогрев", "глобус худший", "глобус крупный", "линза худшая",
			"раскладки худшие", "атлас", "панель", "панель лучом", "прокрутка панели", "пропуск перерисовки",
			"подписи", "клавиатура overlay", "PIN: время входа"]
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

	# Раскладки шага 1г в худшем уровне (самые мелкие ячейки при самом большом радиусе),
	# при вращении. Одна проверка: связывающее и худшая раскладка называются поимённо.
	var worst := ""
	var worst_ms := 0.0
	var over := PackedStringArray()
	var seen := PackedStringArray()
	for surf in ["globe_hex", "octa", "rings", "fib"]:
		st.values["surface"] = surf
		menu.apply_settings()
		await ProbeWindow.settle(host, 0.5)
		var m: Dictionary = await _measure(host, rid, budget)
		var g95: float = (m["gpu"] as ProbeStats).percentile(0.95)
		var c95: float = (m["cpu"] as ProbeStats).percentile(0.95) + (m["process"] as ProbeStats).percentile(0.95)
		var line := "%s %d ячеек: GPU %.2f / CPU+скрипты %.2f мс (%s)" % [surf, menu.renderer.drawn, g95, c95, "GPU" if g95 >= c95 else "CPU"]
		seen.append(line)
		if maxf(g95, c95) > worst_ms:
			worst_ms = maxf(g95, c95)
			worst = surf
		if maxf(g95, c95) > budget or int(m["over"]) > 0:
			over.append(line)
	if over.is_empty():
		r.pass_("раскладки худшие, вращение, бюджет %.2f мс: %s; худшая %s" % [budget, "; ".join(seen), worst])
	else:
		r.fail("раскладки худшие вне бюджета %.2f мс: %s (все: %s)" % [budget, "; ".join(over), "; ".join(seen)])
	menu.debug_spin = 0.0

	# Подписи шейдером: атлас глифов нарисован, иконки загружаются, строки данных собраны.
	var lt = menu.label_text
	var gtex: Texture2D = lt.glyph_texture()
	var icon_ok: bool = lt.icon("folder") != null and lt.icon("delete") != null
	if gtex != null and gtex.get_width() == lt.GLYPH_COLS * lt.GLYPH_CELL.x and lt.rebuilds > 0 and icon_ok:
		r.pass_("атлас: глифы %dx%d, строки данных собраны %d раз, иконки загружаются" % [gtex.get_width(), gtex.get_height(), lt.rebuilds])
	else:
		r.fail("атлас: глифы %s, сборок данных %d, иконки %s" % [gtex, lt.rebuilds, icon_ok])

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
		pnl.synthetic_lock = true
		pnl.open_editor(SettingEdit.new(st, "radius_cm"), "самопроверка", ["done"])
		for _i in 3:
			await host.get_tree().process_frame
		var rect: Rect2 = pnl._slider.get_global_rect()
		var renders0: int = pnl.renders
		var a: Variant = _aim(pnl, rect.position + Vector2(rect.size.x * 0.2, rect.size.y * 0.5))
		var b: Variant = _aim(pnl, rect.position + Vector2(rect.size.x * 0.8, rect.size.y * 0.5))
		pnl.pointer_update(a, false, "check")
		pnl.pointer_update(a, true, "check")
		await host.get_tree().process_frame
		pnl.pointer_update(b, true, "check")
		await host.get_tree().process_frame
		pnl.pointer_update(b, false, "check")
		pnl.pointer_update(null, false, "check")
		pnl.synthetic_lock = false
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

	# Прокрутка панели: длинное содержимое едет, и панель перерисовывается ТОЛЬКО на
	# кадрах, где она сдвинулась. Иначе SubViewport рисуется каждый кадр — цена
	# прокрутки была бы постоянной, а не за движение.
	if pnl != null and pnl.has_method("scroll_by"):
		menu.panel_locked = true
		var long := ""
		for i in 40:
			long += "строка %d описания объекта, которая должна уехать за нижний край панели\n" % i
		pnl.show_text("Прокрутка", "самопроверка", long, "подсказка")
		for _i in 3:
			await host.get_tree().process_frame
		var span: int = pnl.scroll_max()
		var moved := pnl.scroll_by(300.0)
		var at: int = pnl.scroll_pos()
		var renders_before: int = pnl.renders
		for _i in 5:
			pnl.scroll_by(0.0)          # кадры без движения
		var idle_renders: int = pnl.renders - renders_before
		pnl.scroll_by(-10000.0)
		var back_to: int = pnl.scroll_pos()
		pnl.show_text("", "", "", "")
		# Правка: едет ВСЁ содержимое, а не одно пояснение (отзыв сессии 4). Свидетель —
		# прямоугольник ползунка; строка кнопок обязана стоять. Кадры разные: и раскладка
		# контейнера, и сдвиг прокрутки доходят до детей отложенно.
		var ed := SettingEdit.new(st, "radius_cm")
		ed.message = "длинное пояснение, занимающее несколько строк подряд, ".repeat(14)
		pnl.open_editor(ed, "прокрутка правки", ["done"])
		for _i in 3:
			await host.get_tree().process_frame
		var e_span: int = pnl.scroll_max()
		var slider0: float = pnl._slider.get_global_rect().position.y
		var footer0: float = pnl._buttons_box.get_global_rect().position.y
		pnl.scroll_by(float(mini(200, e_span)))
		var e_at: int = pnl.scroll_pos()
		await host.get_tree().process_frame
		var slider_moved: float = slider0 - pnl._slider.get_global_rect().position.y
		var footer_moved: float = footer0 - pnl._buttons_box.get_global_rect().position.y
		pnl.close_editor()
		menu.panel_locked = false
		var edit_ok := e_span > 0 and e_at > 0 and is_equal_approx(slider_moved, float(e_at)) \
				and is_equal_approx(footer_moved, 0.0)
		if span > 0 and moved and at == 300 and idle_renders == 0 and back_to == 0 and edit_ok:
			r.pass_("прокрутка панели: ход %d px, стик сдвинул на %d, кадры без движения не перерисовывают, верх возвращается; в правке ход %d, ползунок уехал на %.0f вместе с содержимым, кнопки стоят" % [span, at, e_span, slider_moved])
		else:
			r.fail("прокрутка панели: ход %d px, сдвиг %s → %d, перерисовок без движения %d, возврат %d; правка: ход %d, окно %d, ползунок %.1f, кнопки %.1f" % [
					span, moved, at, idle_renders, back_to, e_span, e_at, slider_moved, footer_moved])
	else:
		r.fail("прокрутка панели: панель без прокрутки (%s)" % pnl)

	# Пропуск перерисовки: ни неподвижный, ни вращающийся глобус ячейки не пересчитывает —
	# вращение поворачивает узел. Отказ — только по МЕХАНИЗМУ (§3.10): сравнение скриптов
	# держится на структуре расходов и переворачивается молча. Прежняя версия сравнивала
	# неподвижный глобус в конце прогона с вращающимся в начале, и дрейф до 13% переворачивал
	# сравнение (сессия 6, §3.5). Теперь окна чередуются подряд, сравнение — числом рядом.
	st.values["surface"] = "globe"
	menu.apply_settings()
	await ProbeWindow.settle(host, 0.8)
	var redrawn := 0
	var diffs := PackedFloat32Array()
	var pairs := PackedStringArray()
	for _p in REDRAW_PAIRS:
		menu.debug_spin = 0.0
		await ProbeWindow.settle(host, 0.3)
		var redraws0: int = menu.renderer.redraws
		var still: Dictionary = await _measure(host, rid, budget)
		redrawn += menu.renderer.redraws - redraws0
		menu.debug_spin = WORST_SPIN
		await ProbeWindow.settle(host, 0.3)
		redraws0 = menu.renderer.redraws
		var spin: Dictionary = await _measure(host, rid, budget)
		redrawn += menu.renderer.redraws - redraws0
		var s95: float = (still["process"] as ProbeStats).percentile(0.95)
		var v95: float = (spin["process"] as ProbeStats).percentile(0.95)
		diffs.append(v95 - s95)
		pairs.append("%.2f/%.2f" % [s95, v95])
	menu.debug_spin = 0.0
	diffs.sort()
	var med: float = (diffs[diffs.size() / 2 - 1] + diffs[diffs.size() / 2]) * 0.5
	var cmp_line := "скрипты p95 неподвижно/вращение по парам подряд: %s; разность вращение − покой медиана %+.2f мс, разброс %+.2f…%+.2f" % [
			", ".join(pairs), med, diffs[0], diffs[diffs.size() - 1]]
	if redrawn <= 2:
		r.pass_("пропуск перерисовки: глобус за %d пар окон (покой и вращение) пересчитан %d раз; %s" % [REDRAW_PAIRS, redrawn, cmp_line])
	else:
		r.fail("пропуск перерисовки: глобус за %d пар окон пересчитан %d раз — вращение пересчитывает ячейки; %s" % [REDRAW_PAIRS, redrawn, cmp_line])

	# Подписи шейдером в большой папке: «Много файлов» (128 подписей сразу) на худшем глобусе и
	# худшей линзе при вращении. Сессия 9 выбрала этот режим: 3.03 мс CPU на глобусе, 8.22 на линзе.
	var lab_seen := PackedStringArray()
	var lab_over := PackedStringArray()
	for surf in ["globe", "lens"]:
		st.values["surface"] = surf
		st.values["radius_cm"] = Settings.SPEC["radius_cm"]["max"]
		st.values["cell_cm"] = Settings.SPEC["cell_cm"]["min"]
		menu.apply_settings()
		_open_folder(menu, ["files", "bulk"])
		menu.debug_spin = WORST_SPIN
		await ProbeWindow.settle(host, 0.5)
		var lm: Dictionary = await _measure(host, rid, budget)
		var lg95: float = (lm["gpu"] as ProbeStats).percentile(0.95)
		var lc95: float = (lm["cpu"] as ProbeStats).percentile(0.95) + (lm["process"] as ProbeStats).percentile(0.95)
		var line := "%s %d на странице: GPU %.2f / CPU+скрипты %.2f мс (%s), промахов %d" % [
				surf, menu.nav.items().size(), lg95, lc95, "GPU" if lg95 >= lc95 else "CPU", int(lm["over"])]
		lab_seen.append(line)
		if maxf(lg95, lc95) > budget or int(lm["over"]) > 0:
			lab_over.append(line)
	menu.debug_spin = 0.0
	st.values["surface"] = "globe"
	menu.apply_settings()
	_open_folder(menu, [])
	if lab_over.is_empty():
		r.pass_("подписи, бюджет %.2f мс: %s" % [budget, "; ".join(lab_seen)])
	else:
		r.fail("подписи вне бюджета %.2f мс: %s (все: %s)" % [budget, "; ".join(lab_over), "; ".join(lab_seen)])

	# Клавиатура overlay (ADR-0009, пересмотр 2026-09-17): платформа отдаёт виртуальную
	# клавиатуру, и открытие поиска запрашивает её показ. Слабая проверка: видна ли клавиатура
	# поверх сцены и доходит ли текст, изнутри не проверить — это интерактивная часть сессии.
	# Манифест (oculus.software.overlay_keyboard) проверяется aapt2 на хосте. Опрос расширений
	# XR_META_virtual_keyboard / render_model снят: модуль отвергнут, ответ больше не нужен.
	var has_vk := DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD)
	var req0: int = pnl.keyboard_requests if pnl != null else -1
	if pnl != null and pnl.has_method("open_text"):
		# Без настоящего показа: в сессии 7 клавиатура всплывала посреди замеров и забирала фокус.
		menu.panel_locked = true
		pnl.keyboard_dry_run = true
		pnl.open_text("самопроверка клавиатуры", ["done"], "system")
		await host.get_tree().process_frame
		pnl.close_editor()
		pnl.keyboard_dry_run = false
		menu.panel_locked = false
	var req: int = (pnl.keyboard_requests - req0) if pnl != null else -1
	if has_vk and req == 1:
		r.pass_("клавиатура overlay: платформа отдаёт виртуальную клавиатуру, открытие ввода запросило показ 1 раз (без показа)")
	else:
		r.fail("клавиатура overlay: FEATURE_VIRTUAL_KEYBOARD %s, запросов показа %d из 1" % [has_vk, req])

	menu.close()
	_pin_time()
	return _verdict()


## Открыть папку по пути id от корня (пустой путь — корень) через навигатор, как короткими нажатиями.
static func _open_folder(menu: Menu, path: Array) -> void:
	var guard := 0
	while (menu.nav.state.folder() != "" or menu.nav.view != "browse") and guard < 8:
		menu.back()
		guard += 1
	for id in path:
		var list: Array = menu.nav.items()
		for i in list.size():
			if list[i].id == id:
				menu._handle(menu.nav.short(i, menu._scroll()))
				break


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


## Время вывода ключа PIN на этом шлеме: PBKDF2 с Pin.ITERATIONS — число итераций измеряется здесь,
## а не выбирается на столе (CLAUDE.md, правило 1). Три замера, берётся худший.
func _pin_time() -> void:
	var worst := 0.0
	var salt := Pin.make_salt()
	for _i in 3:
		var t0 := Time.get_ticks_usec()
		Pin.hash_pin("2468", salt, Pin.ITERATIONS)
		worst = maxf(worst, (Time.get_ticks_usec() - t0) / 1000.0)
	results["pin_ms"] = worst
	var msg := "PIN: вывод ключа %d итераций — %.0f мс (худший из 3), цель ≤ %.0f мс" % [Pin.ITERATIONS, worst, PIN_TARGET_MS]
	if worst <= PIN_TARGET_MS:
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
