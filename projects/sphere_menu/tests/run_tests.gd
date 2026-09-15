extends SceneTree

## Настольные проверки прототипа шар-меню (Ф2, шаг 1). Прибор пишется до сессии (PRACTICES §1.1).
##
## Запуск:
##   godot/bin/godot.linuxbsd.editor.x86_64 --headless --path projects/sphere_menu \
##       --script res://tests/run_tests.gd [-- --falsify=<имя>]
##
## Пол — по числу исполненных проверок, ожидаемое число выводится из тех же
## массивов, по которым идут циклы (§1.2, §1.8). Код возврата 0 — только при
## сошедшемся поле и нуле отказов.
##
## Фальсификаторы (§2.1–2.2) портят ДАННЫЕ, а не код, и обязаны покраснеть точечно:
##   --falsify=neighbors  у ячейки 0 глобуса m=3 одна связь заменена связью с чужой
##                        ячейкой — краснеет только симметрия соседства m=3;
##   --falsify=shift      поворот на две ячейки вместо одной — краснеет только
##                        проверка шага вращения (обе поверхности в одной проверке).
##                        Не полторы: активная попала бы на границу двух ячеек.
##   --falsify=mirror     формула подписи первой версии шейдера (отражённый текст на
##                        шлеме) — краснеет только ориентация подписи;
##   --falsify=undo       в проверке изменений каталога пропущена одна отмена —
##                        краснеет только «изменения и отмена»;
##   --falsify=grab       поворот трекбола применён с обратным знаком — краснеет
##                        только «трекбол»;
##   --falsify=press      порог удержания 0 мс — краснеет только «короткое и удержание»;
##   --falsify=relax      центры глобуса до выравнивания (из того же файла сетки) —
##                        краснеет только «равномерность» уровней 3–8 (у уровней 0–2
##                        выравнивать нечего: симметрия икосаэдра, 1 итерация);
##   --falsify=uniform    все ячейки глобуса одного размера — краснеет только «размер по контуру»;
##   --falsify=stick      прежняя формула стика (горизонталь вокруг «верха» шара) —
##                        краснеет только «стик»;
##   --falsify=smooth     сглаживание руки 0 в проверке фильтра — краснеет только
##                        «сглаживание руки»;
##   --falsify=keypad     «,» набирается как «.» не распознанной строкой — ввод «2,75»
##                        не даёт 2.75, краснеет только «правка значения»;
##   --falsify=demo       путь стика в демонстрации без последнего отрезка —
##                        краснеет только «демонстрации».

const Report := preload("res://probe_report.gd")
const Goldberg := preload("res://menu/goldberg.gd")
const Layout := preload("res://menu/layout.gd")
const State := preload("res://menu/state.gd")
const Item := preload("res://menu/item.gd")
const Catalog := preload("res://menu/catalog_demo.gd")
const Globe := preload("res://menu/surface_globe.gd")
const Lens := preload("res://menu/surface_lens.gd")
const Surface := preload("res://menu/surface.gd")
const Active := preload("res://menu/active_cell.gd")
const Spring := preload("res://menu/spring.gd")
const Press := preload("res://menu/press.gd")
const Grab := preload("res://menu/grab.gd")
const SettingsRes := preload("res://menu/settings.gd")
const Wizard := preload("res://menu/wizard.gd")
const Navigator := preload("res://menu/navigator.gd")
const Stick := preload("res://menu/stick.gd")
const HandFollow := preload("res://menu/hand_follow.gd")
const SettingEdit := preload("res://menu/setting_edit.gd")
const DemoRes := preload("res://menu/demo.gd")

## Уровни ряда Goldberg.LEVELS под проверкой топологии (уровень 0 — контроль).
const LEVELS := [1, 2, 3, 4, 5, 6, 7, 8]
## Уровни под проверками поверхностей: там O(n²) поиски, крупные ничего не добавляют.
const FREQS := [1, 2, 3, 4, 5]
const GOLDBERG_CHECKS := ["число ячеек", "пятиугольники", "степени", "симметрия", "контуры", "равномерность"]
## Порог разброса расстояний до соседей (max/min) по уровню — из замера запекателя
## 2026-09-15 после выравнивания (1.119, 1.135, 1.158, 1.168, 1.185, 1.194, 1.209,
## 1.218) с запасом ~1%: до выравнивания 1.185–1.379, фальсификатор relax.
const NEIGHBOR_MAX := {1: 1.13, 2: 1.15, 3: 1.17, 4: 1.18, 5: 1.20, 6: 1.21, 7: 1.22, 8: 1.23}
## Вытянутость ячейки (max/min угла до вершин контура): замер после выравнивания
## ≤ 1.108; выравнивание площадей, отвергнутое замером, давало до 2.08.
const ELONGATION_MAX := 1.12
## Зазор между соседними отрисованными ячейками, доля расстояния между центрами:
## замер 2026-09-15 по контуру 0.039–0.153; один размер на все — перекрытие 0.014
## на 642 ячейках и зазор 0.012 на 42.
const GAP_MIN := 0.03
const GAP_MAX := 0.16
const GAP_LEVELS := [0, 1, 2, 3, 5, 8]
const RING_RADII := [1, 2, 3, 4]
const STATE_CHECKS := ["стек и прокрутка", "назад на корне", "переход и обрезка"]
const CATALOG_CHECKS := ["состав", "представление"]
const MODEL_CHECKS := ["короткое и удержание", "трекбол", "настройки", "мастер", "шар действий",
		"действие по умолчанию", "изменения и отмена", "множественный выбор", "сортировка и переходы",
		"опасное без удержания", "стик", "вращение рукой", "сглаживание руки", "правка значения", "демонстрации"]
const SHARED_COPIES := ["probe_window.gd", "probe_stats.gd", "probe_report.gd", "probe_budget.gd"]

var r: Report = Report.new()
var falsify := ""
var _extra_expected := 0


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--falsify="):
			falsify = a.get_slice("=", 1)
	var expected := _expected()
	r.note("=== ПРОВЕРКИ ПРОТОТИПА ШАР-МЕНЮ ===")
	if falsify != "":
		r.note("!!! ФАЛЬСИФИКАТОР «%s»: ожидается точечный отказ !!!" % falsify)
	r.note("ожидается исполненных проверок: %d" % expected)

	_control()
	_goldberg()
	_layout()
	_state()
	_catalog()
	_copies()
	_extra()
	_model()

	var total := r.executed()
	r.note("")
	r.note("passed=%d failed=%d unknown=%d" % [r.passed, r.failed, r.unknown])
	var ok := true
	if total != expected:
		r.note("ОТКАЗ ПРИБОРА: исполнено %d проверок из %d — ошибка оборвала функцию" % [total, expected])
		ok = false
	else:
		r.note("пол: исполнено %d/%d проверок" % [total, expected])
	quit(0 if ok and r.failed == 0 else 1)


func _expected() -> int:
	return 1 \
		+ LEVELS.size() * GOLDBERG_CHECKS.size() \
		+ 3 \
		+ STATE_CHECKS.size() \
		+ CATALOG_CHECKS.size() \
		+ 1 \
		+ extra_expected() \
		+ MODEL_CHECKS.size()


const SURFACE_CHECKS := ["ячейка под направлением", "шаг вращения", "раздача глобуса",
		"детент", "гистерезис активной", "закрутка линзы", "ориентация контура", "ориентация подписи",
		"размер по контуру"]


func extra_expected() -> int:
	return SURFACE_CHECKS.size()


func _extra() -> void:
	_surfaces()


# --- контроль -----------------------------------------------------------------

## Зелёный при любом состоянии выравнивания: уровень 0 — сам икосаэдр, двигать
## нечего, он обязан дать 12 вершин и 12 пятиугольников. Покраснел — сломана
## загрузка сетки или проверочный механизм (§1.5).
func _control() -> void:
	var g = Goldberg.build(0)
	if g.centers.size() == 12 and g.pentagon_count() == 12:
		r.pass_("контроль: икосаэдр, уровень 0 — 12 вершин, 12 пятиугольников")
	else:
		r.fail("контроль: икосаэдр, уровень 0 — %d вершин, %d пятиугольников" % [g.centers.size(), g.pentagon_count()])


# --- Гольдберг ----------------------------------------------------------------

func _goldberg() -> void:
	r.note("")
	r.note("--- Гольдберг, запечённые сетки ---")
	for m in LEVELS:
		var g = Goldberg.build(m, falsify == "relax", falsify == "neighbors")
		var n: int = g.centers.size()
		# Равномерность: разброс расстояний до соседей и вытянутость ячеек — то, что
		# глаз видит как «съезжают» (сессия 2026-09-15). Считается по загруженным
		# данным, метрики из файла не используются.
		var dmin := INF
		var dmax := 0.0
		var elong := 1.0
		for i in n:
			for j in g.neighbors[i]:
				var dd: float = g.centers[i].angle_to(g.centers[j])
				dmin = minf(dmin, dd)
				dmax = maxf(dmax, dd)
			var vmin := INF
			var vmax := 0.0
			for v in g.outlines[i]:
				var va: float = g.centers[i].angle_to(v)
				vmin = minf(vmin, va)
				vmax = maxf(vmax, va)
			elong = maxf(elong, vmax / vmin)
		var spread := dmax / dmin
		# (равномерность считается ДО порчи соседства: иначе фальсификатор neighbors
		# краснел бы и в ней — не точечно)
		if falsify == "neighbors" and m == 3:
			# Связь заменяется связью с чужой ячейкой: степень и контур не меняются,
			# ломается только симметрия. Удаление связи (первая версия) меняло
			# степень и роняло ещё две проверки — фальсификатор был не точечным.
			var nb: Array = g.neighbors[0]
			for cand in range(g.centers.size() - 1, 0, -1):
				if not nb.has(cand):
					nb[nb.size() - 1] = cand
					break
		# GP(a,b) из имени файла: 10T + 2, T = a² + ab + b² — независимо от таблицы LEVELS.
		var nm: String = Goldberg.LEVELS[m][0]
		var ga := int(nm.substr(2, 1))
		var gb := int(nm.substr(4, 1))
		var want: int = 10 * (ga * ga + ga * gb + gb * gb) + 2
		if n == want:
			r.pass_("m=%d (%s) число ячеек: %d = 10T+2" % [m, nm, n])
		else:
			r.fail("m=%d (%s) число ячеек: %d вместо %d" % [m, nm, n, want])

		var pent: int = g.pentagon_count()
		if pent == 12:
			r.pass_("m=%d пятиугольников ровно 12" % m)
		else:
			r.fail("m=%d пятиугольников %d вместо 12" % [m, pent])

		var bad_deg: Array[String] = []
		for i in n:
			var d: int = (g.neighbors[i] as Array).size()
			if d != 5 and d != 6:
				bad_deg.append("%d:%d" % [i, d])
		if bad_deg.is_empty():
			r.pass_("m=%d у каждой ячейки 5 или 6 соседей" % m)
		else:
			r.fail("m=%d степени не 5/6: %s" % [m, ", ".join(bad_deg.slice(0, 8))])

		var asym: Array[String] = []
		for i in n:
			for j in g.neighbors[i]:
				if not (g.neighbors[j] as Array).has(i):
					asym.append("%d→%d" % [i, j])
		if asym.is_empty():
			r.pass_("m=%d соседство симметрично" % m)
		else:
			r.fail("m=%d соседство несимметрично: %s" % [m, ", ".join(asym.slice(0, 8))])

		# Контур ячейки: 5 или 6 вершин, и каждая вершина — угол СВОЕЙ ячейки. В
		# вершине сходятся ровно три ячейки, значит своя обязана быть среди трёх
		# ближайших центров. Без допусков: две прежние версии требовали «ближе к
		# своей» (центроид на неравномерной сфере не равноудалён — у пятиугольников
		# разница до 0.046 рад) и назначенный на глаз допуск 10% (§3.1). Зазор между
		# третьей и четвёртой ячейкой печатается — это запас проверки.
		var bad_out: Array[String] = []
		var min_gap := INF
		for i in n:
			var o: PackedVector3Array = g.outlines[i]
			if o.size() != 5 and o.size() != 6:
				bad_out.append("%d: %d вершин" % [i, o.size()])
				continue
			for p in o:
				# четыре ближайших центра без сортировки всех n: на 642 ячейках сортировка
				# 3852 раза по 642 — десятки секунд GDScript
				var best: Array = [[INF, -1], [INF, -1], [INF, -1], [INF, -1]]
				for k in n:
					var dk := p.dot(g.centers[k])
					var ak := -dk    # монотонно с углом, acos только для зазора
					if ak < best[3][0]:
						best[3] = [ak, k]
						best.sort_custom(func(x, y): return x[0] < y[0])
				if not (best[0][1] == i or best[1][1] == i or best[2][1] == i):
					bad_out.append("%d: вершина чужая" % i)
					break
				min_gap = minf(min_gap, acos(clampf(-best[3][0], -1.0, 1.0)) - acos(clampf(-best[2][0], -1.0, 1.0)))
		if bad_out.is_empty():
			r.pass_("m=%d контуры: 5–6 вершин, каждая среди трёх ближайших к своей ячейке (запас до четвёртой ≥ %.4f рад)" % [m, min_gap])
		else:
			r.fail("m=%d контуры: %s" % [m, ", ".join(bad_out.slice(0, 8))])

		if spread <= float(NEIGHBOR_MAX[m]) and elong <= ELONGATION_MAX:
			r.pass_("m=%d равномерность: соседи max/min %.3f ≤ %.2f, вытянутость %.3f ≤ %.2f" % [m, spread, NEIGHBOR_MAX[m], elong, ELONGATION_MAX])
		else:
			r.fail("m=%d равномерность: соседи max/min %.3f (порог %.2f), вытянутость %.3f (порог %.2f)" % [m, spread, NEIGHBOR_MAX[m], elong, ELONGATION_MAX])


# --- раскладка ----------------------------------------------------------------

func _layout() -> void:
	r.note("")
	r.note("--- Раскладка ---")
	var bad: Array[String] = []
	for k in RING_RADII:
		var ring: Array[Vector2i] = Layout.ring(k)
		if ring.size() != 6 * k:
			bad.append("k=%d: %d ячеек" % [k, ring.size()])
		for c in ring:
			if Layout.distance(c, Vector2i.ZERO) != k:
				bad.append("k=%d: %s на расстоянии %d" % [k, c, Layout.distance(c, Vector2i.ZERO)])
				break
	if bad.is_empty():
		r.pass_("кольца радиусов %s: 6k ячеек, все на расстоянии k" % str(RING_RADII))
	else:
		r.fail("кольца: %s" % "; ".join(bad))

	var sp: Array[Vector2i] = Layout.spiral(60)
	var issues: Array[String] = []
	var seen := {}
	var last := 0
	for c in sp:
		if c == Layout.BACK_CELL:
			issues.append("спираль заняла «назад»")
		if seen.has(c):
			issues.append("повтор %s" % c)
		seen[c] = true
		var d := Layout.distance(c, Vector2i.ZERO)
		if d < last:
			issues.append("расстояние убыло на %s" % c)
		last = d
	if sp.size() == 60 and issues.is_empty() and sp[0] == Vector2i.ZERO \
			and Layout.distance(Layout.BACK_CELL, Vector2i.ZERO) == 1:
		r.pass_("спираль 60: центр первым, расстояние не убывает, без повторов, «назад» — сосед центра и свободна")
	else:
		r.fail("спираль 60 (%d ячеек): %s" % [sp.size(), "; ".join(issues)])

	var round_bad: Array[String] = []
	for c in Layout.spiral(200):
		var back := Layout.from_plane(Layout.to_plane(c))
		if back != c:
			round_bad.append("%s→%s" % [c, back])
		# точка в 0.4 радиуса от центра остаётся в своей ячейке
		var jitter := Layout.from_plane(Layout.to_plane(c) + Vector2(0.4, -0.3))
		if jitter != c:
			round_bad.append("%s+шум→%s" % [c, jitter])
	if round_bad.is_empty():
		r.pass_("плоскость: центр и точка рядом возвращаются в свою ячейку для 200 ячеек")
	else:
		r.fail("плоскость: %s" % ", ".join(round_bad.slice(0, 8)))


# --- состояние ----------------------------------------------------------------

func _state() -> void:
	r.note("")
	r.note("--- Состояние ---")
	var s: State = State.new()
	s.toggle()
	var in1: Variant = s.enter("f1", "корень")
	var in2: Variant = s.enter("f2", "f1")
	var b1 := s.back("f2")
	var b2 := s.back("f1-2")
	var again: Variant = s.enter("f1", "корень-2")
	if in1 == null and in2 == null and b1["scroll"] == "f1" and b2["scroll"] == "корень" and again == "f1-2":
		r.pass_("стек: вход, выход и повторный вход возвращают прокрутку каждой папки")
	else:
		r.fail("стек: %s %s %s %s %s" % [in1, in2, b1, b2, again])

	s.back(null)
	var root := s.back(null)
	if root["closed"] and s.mode == State.Mode.CLOSED:
		r.pass_("«назад» на корне закрывает меню")
	else:
		r.fail("«назад» на корне: %s, режим %d" % [root, s.mode])

	var t: State = State.new()
	t.enter("a", "r0")
	t.enter("b", "a0")
	t.enter("c", "b0")
	var j: Variant = t.jump(1, "c0")
	var after_jump := t.folder()
	t.enter("gone", "a1")
	t.prune(func(f): return f != "gone")
	if after_jump == "a" and j == "a0" and t.folder() == "a":
		r.pass_("переход на уровень и обрезка исчезнувшей папки")
	else:
		r.fail("переход: папка %s прокрутка %s, после обрезки %s" % [after_jump, j, t.folder()])


# --- каталог ------------------------------------------------------------------

func _catalog() -> void:
	r.note("")
	r.note("--- Каталог ---")
	var c: Catalog = Catalog.new()
	var root_kinds := {}
	for it in c.children("", 0, 100):
		root_kinds[it.kind] = true
	var kinds := {}
	var images_ok := true
	var ids := c.all_ids()
	for id in ids:
		var it: Item = c.items[id]
		kinds[it.kind] = true
		if it.kind == Item.Kind.IMAGE and not ResourceLoader.exists(it.preview):
			images_ok = false
	var need := [Item.Kind.FOLDER, Item.Kind.SCENE, Item.Kind.IMAGE, Item.Kind.ASSET, Item.Kind.FILE, Item.Kind.OPTION, Item.Kind.TOGGLE]
	var missing := need.filter(func(k): return not kinds.has(k))
	if root_kinds.keys() == [Item.Kind.FOLDER] and missing.is_empty() and images_ok and ids.size() >= 50:
		r.pass_("каталог: %d пунктов, корень — только папки, есть все виды объектов, изображения загружаются" % ids.size())
	else:
		r.fail("каталог: корень %s, нет видов %s, изображения %s, пунктов %d" % [root_kinds.keys(), missing, images_ok, ids.size()])

	var by_name := c.view("images", "name", -1, []).map(func(x): return x.title)
	var sorted_names := by_name.duplicate()
	sorted_names.sort_custom(func(x, y): return x.to_lower() < y.to_lower())
	var by_date := c.view("scenes", "date", -1, []).filter(func(x): return x.kind != Item.Kind.FOLDER).map(func(x): return x.modified)
	var dates_desc := true
	for i in range(1, by_date.size()):
		if by_date[i] > by_date[i - 1]:
			dates_desc = false
	var only_scenes := c.view("scenes", "name", Item.Kind.SCENE, []).all(func(x): return x.kind in [Item.Kind.SCENE, Item.Kind.FOLDER])
	var recent_first: Array = c.view("images", "name", -1, ["img_sky", "img_map"])
	if by_name == sorted_names and dates_desc and only_scenes and recent_first[0].id == "img_sky" and recent_first[1].id == "img_map":
		r.pass_("представление: по имени, по дате (новые первыми), фильтр по виду, недавние первым кольцом")
	else:
		r.fail("представление: имя %s, даты %s, фильтр %s, недавние %s" % [by_name == sorted_names, by_date, only_scenes, recent_first.slice(0, 2).map(func(x): return x.id)])


# --- копии общего кода ----------------------------------------------------------

func _copies() -> void:
	r.note("")
	var probe_dir := ProjectSettings.globalize_path("res://").path_join("../probe")
	var bad: Array[String] = []
	for f in SHARED_COPIES:
		var a := FileAccess.get_file_as_bytes("res://" + f)
		var b := FileAccess.get_file_as_bytes(probe_dir.path_join(f))
		if b.is_empty():
			bad.append("%s: нет в projects/probe" % f)
		elif a != b:
			bad.append("%s: расходится с projects/probe" % f)
	if bad.is_empty():
		r.pass_("копии общего кода совпадают с projects/probe: %s" % ", ".join(SHARED_COPIES))
	else:
		r.fail("копии общего кода: %s" % "; ".join(bad))


# --- поверхности ----------------------------------------------------------------

func _surfaces() -> void:
	r.note("")
	r.note("--- Поверхности ---")
	var step_mult := 2.0 if falsify == "shift" else 1.0

	# 1. Ячейка под направлением своего центра — она сама, у обеих поверхностей,
	# при произвольном повороте глобуса и сдвиге с закруткой линзы.
	var bad: Array[String] = []
	for m in FREQS:
		var gl = Globe.new(m)
		gl.apply_rotation(Quaternion(Vector3(0.3, 1.0, 0.2).normalized(), 0.7))
		for i in gl.g.centers.size():
			if gl.cell_at_direction(gl.direction_of(i)) != i:
				bad.append("глобус m=%d ячейка %d" % [m, i])
				break
	var ln = Lens.new(0.22)
	ln.offset = Vector2(0.3, -0.2)
	ln.twist = 0.4
	var lens_cells := 0
	for c in Layout.spiral(60):
		var cell: Vector2i = Vector2i(c) + Layout.from_plane(ln.offset)
		if ln.direction_of(cell).angle_to(ln.front) > ln.max_theta:
			continue
		lens_cells += 1
		if ln.cell_at_direction(ln.direction_of(cell)) != cell:
			bad.append("линза %s→%s" % [cell, ln.cell_at_direction(ln.direction_of(cell))])
	if bad.is_empty():
		r.pass_("ячейка под направлением своего центра — она сама: глобус m=%s после поворота, линза %d ячеек со сдвигом и закруткой" % [str(FREQS), lens_cells])
	else:
		r.fail("ячейка под направлением: %s" % ", ".join(bad.slice(0, 8)))

	# 2. Шаг вращения: поворот на угол до соседа делает соседа активным.
	var step_bad: Array[String] = []
	var gl3 = Globe.new(3)
	gl3.apply_rotation(gl3.snap_rotation())
	var a: int = gl3.cell_at_direction(gl3.front)
	for nb in gl3.g.neighbors[a]:
		var probe = Globe.new(3)
		probe.orientation = gl3.orientation
		var q := Quaternion(probe.direction_of(nb), probe.front)
		probe.apply_rotation(Quaternion(q.get_axis(), q.get_angle() * step_mult) if q.get_angle() > 1e-6 else q)
		if probe.cell_at_direction(probe.front) != nb:
			step_bad.append("глобус %d→%d, стал %d" % [a, nb, probe.cell_at_direction(probe.front)])
	for d in Layout.DIRS:
		var l2 = Lens.new(0.22)
		var dir: Vector3 = l2.direction_of(d)
		var q2 := Quaternion(dir, l2.front)
		l2.apply_rotation(Quaternion(q2.get_axis(), q2.get_angle() * step_mult))
		if l2.cell_at_direction(l2.front) != d:
			step_bad.append("линза →%s, стала %s" % [d, l2.cell_at_direction(l2.front)])
	if step_bad.is_empty():
		r.pass_("шаг вращения: поворот на угол до соседа делает активным ровно соседа — глобус все %d соседей, линза все 6 направлений" % (gl3.g.neighbors[a] as Array).size())
	else:
		r.fail("шаг вращения: %s" % ", ".join(step_bad))

	# 3. Раздача глобуса: первый пункт — активная, «назад» — её сосед, пункты по
	# неубыванию расстояния в графе, каждый ровно один раз.
	var gl4 = Globe.new(3)
	gl4.assign(40)
	var act: int = gl4.cell_at_direction(gl4.front)
	var slot_cell := {}
	var backs: Array[int] = []
	for i in gl4.g.centers.size():
		var sl: int = gl4.slot_of(i)
		if sl == Surface.SLOT_BACK:
			backs.append(i)
		elif sl >= 0:
			slot_cell[sl] = i
	# Эталон расстояний — граф БЕЗ «назад»: пункты обходят её по спецификации.
	# Первая версия проверки мерила по полному графу и краснела на ячейках за
	# «назад», чьё расстояние в обходе на единицу больше.
	var dist := {act: 0}
	if not backs.is_empty():
		dist[backs[0]] = -1
	var queue: Array = [act]
	while not queue.is_empty():
		var c2: int = queue.pop_front()
		for j in gl4.g.neighbors[c2]:
			if not dist.has(j):
				dist[j] = dist[c2] + 1
				queue.append(j)
	var order_ok := true
	for sl in range(1, 40):
		if not slot_cell.has(sl) or dist[slot_cell[sl]] < dist[slot_cell[sl - 1]]:
			order_ok = false
	var lens_assign = Lens.new(0.22)
	lens_assign.assign(10)
	if gl4.slot_of(act) == 0 and backs.size() == 1 and (gl4.g.neighbors[act] as Array).has(backs[0]) \
			and slot_cell.size() == 40 and order_ok \
			and lens_assign.slot_of(Vector2i.ZERO) == 0 and lens_assign.slot_of(Layout.BACK_CELL) == Surface.SLOT_BACK:
		r.pass_("раздача: первый пункт в активной, одна «назад» у соседа, 40 пунктов по неубыванию расстояния в графе; линза — так же")
	else:
		r.fail("раздача: активная слот %d, «назад» %s, пунктов %d, порядок %s" % [gl4.slot_of(act), backs, slot_cell.size(), order_ok])

	# 4. Детент: пружина доводит центр активной до переда без перелёта — активная
	# за доводку не меняется, остаток монотонно убывает.
	var det_bad: Array[String] = []
	for kind in ["глобус", "линза"]:
		var sf = Globe.new(3) if kind == "глобус" else Lens.new(0.22)
		if kind == "глобус":
			sf.apply_rotation(sf.snap_rotation())
			sf.apply_rotation(Quaternion(Vector3.UP, sf.cell_angle() * 0.6))
		else:
			sf.offset = Vector2(0.35, 0.25)
		var start: Variant = sf.cell_at_direction(sf.front)
		var sp = Spring.new()
		sp.value = sf.snap_error()
		var prev: float = sf.snap_error()
		var frames := 0
		for _f in 90:
			frames += 1
			var err: float = sf.snap_error()
			if err < 1e-4:
				break
			var next: float = sp.step(0.0, 1.0 / 90.0)
			var part := clampf((err - next) / err, 0.0, 1.0)
			sf.apply_rotation(Quaternion.IDENTITY.slerp(sf.snap_rotation(), part))
			var now_err: float = sf.snap_error()
			if now_err > prev + 1e-5:
				det_bad.append("%s: остаток вырос %.4f→%.4f" % [kind, prev, now_err])
				break
			if sf.cell_at_direction(sf.front) != start:
				det_bad.append("%s: активная сменилась при доводке" % kind)
				break
			prev = now_err
		if sf.snap_error() > 1e-3:
			det_bad.append("%s: за %d кадров остаток %.4f рад" % [kind, frames, sf.snap_error()])
	if det_bad.is_empty():
		r.pass_("детент: глобус и линза доводятся к центру ячейки за ≤90 кадров без перелёта и смены активной")
	else:
		r.fail("детент: %s" % "; ".join(det_bad))

	# 5. Гистерезис: у границы двух ячеек активная не мигает, дальше запаса — меняется.
	var lh = Lens.new(0.22)
	var ac = Active.new()
	var boundary: float = Layout.to_plane(Vector2i(1, 0)).x * 0.5
	lh.offset = Vector2(boundary - 0.2, 0.0)
	ac.update(lh, 0)
	var first: Variant = ac.key
	lh.offset = Vector2(boundary + 0.03, 0.0)
	var flip_small := ac.update(lh, 16)
	lh.offset = Vector2(boundary - 0.03, 0.0)
	ac.update(lh, 32)
	lh.offset = Vector2(boundary + 0.2, 0.0)
	var flip_big := ac.update(lh, 48)
	var past: Variant = ac.key_at(48 + 0, 40)
	if first == Vector2i.ZERO and not flip_small and flip_big and ac.key == Vector2i(1, 0) and past == Vector2i.ZERO:
		r.pass_("гистерезис: дрожь ±0.03 у границы не меняет активную, сдвиг +0.2 меняет; буфер помнит прежнюю")
	else:
		r.fail("гистерезис: первая %s, мелкий сдвиг сменил=%s, крупный=%s, итог %s, 40 мс назад %s" % [first, flip_small, flip_big, ac.key, past])

	# 6. Закрутка линзы: поворот вокруг переда вращает содержимое вместе с шаром.
	var lt = Lens.new(0.22)
	var qt := Quaternion(lt.front, deg_to_rad(60.0))
	var twist_bad: Array[String] = []
	var before := {}
	for c3 in Layout.spiral(19):
		before[c3] = lt.direction_of(c3)
	lt.apply_rotation(qt)
	for c3 in before:
		var want_dir: Vector3 = qt * before[c3]
		if lt.cell_at_direction(want_dir) != c3:
			twist_bad.append("%s→%s" % [c3, lt.cell_at_direction(want_dir)])
	if twist_bad.is_empty():
		r.pass_("закрутка линзы: поворот на 60° вокруг переда уносит 19 ячеек ровно туда, куда повернулся шар")
	else:
		r.fail("закрутка линзы: %s" % ", ".join(twist_bad.slice(0, 8)))

	# 7. Ориентация контура для рендера: шестиугольник рисуется с вершиной, повёрнутой
	# на spin от касательной оси. Вершина, построенная по spin, обязана смотреть на
	# настоящую вершину ячейки: у глобуса — первую точку контура, у линзы — проекцию
	# вершины решётки. Ошибка знака закрутки (найдена при разборе рендера) краснеет здесь.
	var or_bad: Array[String] = []
	var go = Globe.new(3)
	go.apply_rotation(Quaternion(Vector3(1, 0.4, 0).normalized(), 0.9))
	for cell_d in go.visible_cells():
		var i: int = cell_d["key"]
		var n: Vector3 = cell_d["dir"]
		var drawn := _drawn_vertex(n, cell_d["spin"])
		var real_v: Vector3 = (go.orientation * go.g.outlines[i][0])
		var real_t := (real_v - n * real_v.dot(n)).normalized()
		if drawn.angle_to(real_t) > 0.05:
			or_bad.append("глобус %d: %.2f рад" % [i, drawn.angle_to(real_t)])
			break
	var lo = Lens.new(0.22)
	lo.offset = Vector2(0.4, 0.1)
	lo.twist = 0.5
	for cell_d in lo.visible_cells():
		var n2: Vector3 = cell_d["dir"]
		if n2.angle_to(lo.front) > PI * 0.5:
			continue
		var drawn2 := _drawn_vertex(n2, cell_d["spin"])
		var up_v: Vector3 = lo._plane_to_dir(Layout.to_plane(cell_d["key"]) + Vector2(0.0, 0.3))["dir"]
		var real2 := (up_v - n2 * up_v.dot(n2)).normalized()
		# у шестиугольника вершины через 60°: совпасть обязана любая из шести
		var best := INF
		for k in 6:
			best = minf(best, drawn2.rotated(n2, k * PI / 3.0).angle_to(real2))
		if best > 0.05:
			or_bad.append("линза %s: %.2f рад" % [cell_d["key"], best])
			break
	if or_bad.is_empty():
		r.pass_("ориентация контура: вершина по spin совпадает с вершиной ячейки — глобус 92 ячейки, линза передняя полусфера со сдвигом и закруткой")
	else:
		r.fail("ориентация контура: %s" % ", ".join(or_bad))


	# 8. Ориентация подписи: зритель снаружи шара, глядя на ячейку вдоль −n с «верхом»
	# мира, видит текст прямо — «вправо» текстуры смотрит вправо экрана, «вверх» —
	# вверх. СЛАБАЯ проверка: шейдер на десктопе не исполняется, и здесь повторена его
	# формула (menu/cell.gdshader, fragment). Ловит ошибку вывода, не ошибку переноса
	# в шейдер. Найденный на шлеме дефект (подписи отражены) краснеет здесь.
	var tex_bad: Array[String] = []
	var gt = Globe.new(3)
	gt.apply_rotation(Quaternion(Vector3(0.2, 1.0, 0.3).normalized(), 1.1))
	for cell_d in gt.visible_cells():
		var n3: Vector3 = cell_d["dir"]
		if absf(n3.y) > 0.8:
			continue    # у полюсов «верх» мира вырождается, подпись там любая
		var a3 := Vector3.UP if absf(n3.y) < 0.9 else Vector3.RIGHT
		var ref3 := (a3 - n3 * a3.dot(n3)).normalized()
		var z3 := ref3.rotated(n3, float(cell_d["spin"]))
		var x3 := n3.cross(z3)
		# vertex(): «верх» мира в осях ячейки (масштаб на угол не влияет)
		var ang := atan2(Vector3.UP.dot(x3), Vector3.UP.dot(z3))
		# fragment(): uv = (0.5 − q.x·k, 0.5 − q.y·k); направление в осях ячейки,
		# куда растёт u (вправо текстуры) и убывает v (вверх текстуры)
		# фальсификатор mirror — формула первой версии шейдера (uv.x = 0.5 + q.x·k),
		# давшая на шлеме отражённые подписи
		var right_q := Vector2(1, 0) if falsify == "mirror" else Vector2(-1, 0)
		var tex_right := _local_dir_for_q(right_q, ang, x3, z3)
		var tex_up := _local_dir_for_q(Vector2(0, 1), ang, x3, z3)
		var up_t := (Vector3.UP - n3 * Vector3.UP.dot(n3)).normalized()
		var screen_right := up_t.cross(n3).normalized()
		if tex_right.angle_to(screen_right) > 0.05 or tex_up.angle_to(up_t) > 0.05:
			tex_bad.append("ячейка %d: вправо %.2f рад, вверх %.2f рад" % [cell_d["key"], tex_right.angle_to(screen_right), tex_up.angle_to(up_t)])
			break
	if tex_bad.is_empty():
		r.pass_("ориентация подписи (формула шейдера повторена, слабая проверка): вправо и вверх текстуры совпадают с экраном зрителя снаружи")
	else:
		r.fail("ориентация подписи: %s" % ", ".join(tex_bad))

	# 9. Размер по контуру: соседние ячейки в том размере, в каком их ставит рендер
	# (cell_renderer.gd: опорный радиус × scale × GAP), не перекрываются и не
	# расходятся дальше замеренного. Вписанный радиус — вдоль ребра к соседу.
	var gap_bad: Array[String] = []
	var gap_lo := INF
	var gap_hi := 0.0
	const Renderer := preload("res://menu/cell_renderer.gd")
	for lvl in GAP_LEVELS:
		var gg = Globe.new(lvl)
		var gcells: Array = gg.visible_cells()
		var gref: float = gg.g.cell_angle() * 2.0 / sqrt(3.0)
		var inr := PackedFloat32Array()
		for cd in gcells:
			var gsc: float = 1.0 if falsify == "uniform" else float(cd["scale"])
			inr.append(gref * gsc * Renderer.GAP * cos(PI / float(cd["sides"])))
		var glo := INF
		var ghi := 0.0
		for i in gcells.size():
			for j in gg.g.neighbors[i]:
				var cdist: float = gg.g.centers[i].angle_to(gg.g.centers[j])
				var gp: float = (cdist - inr[i] - inr[j]) / cdist
				glo = minf(glo, gp)
				ghi = maxf(ghi, gp)
		gap_lo = minf(gap_lo, glo)
		gap_hi = maxf(gap_hi, ghi)
		if glo < GAP_MIN or ghi > GAP_MAX:
			gap_bad.append("%d ячеек: зазор %.3f…%.3f" % [gg.g.centers.size(), glo, ghi])
	if gap_bad.is_empty():
		r.pass_("размер по контуру: уровни %s — соседи без перекрытий, зазор %.3f…%.3f расстояния в пределах %.2f…%.2f" % [str(GAP_LEVELS), gap_lo, gap_hi, GAP_MIN, GAP_MAX])
	else:
		r.fail("размер по контуру (пределы %.2f…%.2f): %s" % [GAP_MIN, GAP_MAX, "; ".join(gap_bad)])


## Вершина многоугольника так, как её строит рендер: касательная ось, повёрнутая
## на spin вокруг нормали (см. menu/cell_renderer.gd).
static func _drawn_vertex(n: Vector3, spin: float) -> Vector3:
	var a := Vector3.UP if absf(n.y) < 0.9 else Vector3.RIGHT
	var ref := (a - n * a.dot(n)).normalized()
	return ref.rotated(n, spin)


## Направление в пространстве, где q (повёрнутые координаты шейдера) равно заданному.
## q = R(a)·p, p = (x, z) в осях ячейки; обратный поворот — R(−a).
static func _local_dir_for_q(q: Vector2, a: float, x: Vector3, z: Vector3) -> Vector3:
	var px := q.x * cos(a) + q.y * sin(a)
	var pz := -q.x * sin(a) + q.y * cos(a)
	return (x * px + z * pz).normalized()


# --- модель файлового менеджера -----------------------------------------------------

func _model() -> void:
	r.note("")
	r.note("--- Модель ---")

	# 1. Короткое и удержание: одно нажатие — одно событие.
	var pr = Press.new()
	pr.hold_ms = 0 if falsify == "press" else 500
	var ev := []
	ev.append(pr.update(true, 0))
	ev.append(pr.update(false, 200))
	var hold_ev := []
	for t in [1000, 1300, 1600, 1900]:
		hold_ev.append(pr.update(true, t))
	hold_ev.append(pr.update(false, 2000))
	pr.arm_confirm()
	var c_early := [pr.update(true, 3000), pr.update(false, 3200)]
	var c_full := [pr.update(true, 4000), pr.update(true, 4700), pr.update(false, 4800)]
	if ev == ["", "short"] and hold_ev == ["", "", "hold", "", ""] and c_early == ["", "cancel"] and c_full == ["", "confirm", ""]:
		r.pass_("короткое и удержание: короткое на отпускании, удержание ровно раз на пороге, подтверждение отпущенное раньше — отмена")
	else:
		r.fail("короткое и удержание: %s %s %s %s" % [ev, hold_ev, c_early, c_full])

	# 2. Трекбол: точка под кончиком следует за контроллером; инерция затухает.
	var gb = Grab.new()
	var ball := Quaternion.IDENTITY
	var d0 := Vector3(0.2, 0.1, 1).normalized()
	var grabbed_local := d0
	gb.begin(d0)
	var follow_bad := 0.0
	var path := [Vector3(0.4, 0.1, 0.9), Vector3(0.6, 0.3, 0.7), Vector3(0.7, 0.5, 0.5)]
	for p in path:
		var q: Quaternion = gb.update(p, 1.0 / 90.0)
		if falsify == "grab":
			q = q.inverse()
		ball = q * ball
		follow_bad = maxf(follow_bad, (ball * grabbed_local).angle_to(p.normalized()))
	gb.end()
	var speeds := []
	for _i in 200:
		gb.coast(1.0 / 90.0)
		speeds.append(gb.angular_velocity.length())
	var mono := true
	for i in range(1, speeds.size()):
		if speeds[i] > speeds[i - 1] + 1e-6:
			mono = false
	if follow_bad < 1e-3 and mono and not gb.coasting():
		r.pass_("трекбол: захваченная точка под кончиком (ошибка %.5f рад), инерция монотонно гаснет" % follow_bad)
	else:
		r.fail("трекбол: ошибка следования %.4f рад, затухание монотонно %s, всё ещё крутится %s" % [follow_bad, mono, gb.coasting()])

	# 3. Настройки: непрерывные пределы и округление, выбор — только из вариантов,
	# сохранение и загрузка, отказ от мусора, уровень глобуса по размеру.
	var st = SettingsRes.new()
	var clamp_hi: bool = st.set_value("radius_cm", 99.0)
	var top: Variant = st.get_value("radius_cm")
	var clamp_ok: bool = not st.set_value("cell_cm", 2.74)
	var rounded: Variant = st.get_value("cell_cm")
	st.step("surface", 1)
	st.set_value("hand_smoothing", 0.35)
	var path_cfg := "user://test_sphere_settings.cfg"
	st.save(path_cfg)
	var st2 = SettingsRes.new()
	var rej: Array = st2.load_from(path_cfg)
	var cf := ConfigFile.new()
	cf.load(path_cfg)
	cf.set_value("sphere", "cell_cm", 99.0)
	cf.set_value("sphere", "panel_side", "под столом")
	cf.save(path_cfg)
	var st3 = SettingsRes.new()
	var rej3: Array = st3.load_from(path_cfg)
	# Уровень глобуса не растёт с размером ячейки, а крупнейший размер даёт 12 ячеек.
	var freqs := []
	st3.values["radius_cm"] = 11.0
	for c in [1.5, 2.5, 4.0, 6.0, 9.0, 15.0]:
		st3.values["cell_cm"] = c
		freqs.append(st3.globe_frequency())
	var freq_mono := true
	for i in range(1, freqs.size()):
		if freqs[i] > freqs[i - 1]:
			freq_mono = false
	st3.values["cell_cm"] = 2.5
	var got_cm := SettingsRes.globe_cell_cm(st3.globe_frequency(), 11.0)
	st3.values["cell_cm"] = 15.0
	var lens_capped := is_equal_approx(st3.lens_alpha(), SettingsRes.LENS_ALPHA_MAX)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path_cfg))
	if clamp_hi and is_equal_approx(float(top), 20.0) and clamp_ok and is_equal_approx(float(rounded), 2.7) \
			and st2.values == st.values and rej.is_empty() and rej3 == ["cell_cm", "panel_side"] \
			and st3.values["surface"] == "lens" and freq_mono and freqs.back() == 0 and absf(got_cm - 2.5) < 1.0 \
			and lens_capped:
		r.pass_("настройки: предел и округление (99 → 20 см, 2,74 → 2,7), сохранение и загрузка, мусор отвергнут, уровень глобуса по размеру %s (2.5 см → %.2f см), линза с пределом угла" % [freqs, got_cm])
	else:
		r.fail("настройки: предел %s/%s, округление %s/%s, круг %s, отвергнуто %s/%s, уровни %s, 2.5 см → %.2f, линза %s" % [
				clamp_hi, top, clamp_ok, rounded, st2.values == st.values, rej, rej3, freqs, got_cm, lens_capped])

	# 4. Мастер: основные настройки по порядку, «Дополнительно» не в мастере, назад без
	# потери, умолчание, итог и сохранение.
	var ws = SettingsRes.new()
	var wz = Wizard.new(ws)
	var order_ok: bool = wz.steps().slice(0, SettingsRes.MAIN.size()) == SettingsRes.MAIN \
			and not wz.steps().any(func(x): return x in SettingsRes.ADVANCED)
	ws.values["surface"] = "lens"
	wz.note_change()
	wz.confirm()
	wz.confirm()
	ws.set_value("radius_cm", 14.5)
	wz.note_change()
	var r_val: Variant = ws.get_value("radius_cm")
	wz.confirm()
	wz.back()
	var back_at := wz.current()
	var kept: Variant = ws.get_value("radius_cm")
	wz.confirm()
	wz.skip()
	while wz.current() != Wizard.SUMMARY:
		wz.confirm()
	var lines := wz.summary_lines()
	var wpath := "user://test_wizard.cfg"
	wz.confirm(wpath)
	var check = SettingsRes.new()
	check.load_from(wpath)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(wpath))
	if order_ok and back_at == "radius_cm" and kept == r_val and ws.get_value("cell_cm") == SettingsRes.SPEC["cell_cm"]["default"] \
			and lines.size() == SettingsRes.MAIN.size() and wz.done and wz.saved and check.values == ws.values \
			and ws.get_value("surface") == "lens":
		r.pass_("мастер: %d шагов в порядке MAIN, «Дополнительно» не в мастере, назад сохраняет значение, умолчание, итог и сохранение" % SettingsRes.MAIN.size())
	else:
		r.fail("мастер: порядок %s, назад на %s, значение %s→%s, итог %d строк, сохранено %s, совпадает %s" % [order_ok, back_at, r_val, kept, lines.size(), wz.saved, check.values == ws.values])

	# 5. Шар действий: удержание на объекте — центр объект, действия вокруг; «Отмена» — назад со старой прокруткой.
	var nav = Navigator.new(Catalog.new(), SettingsRes.new())
	nav.short(_slot_of(nav, "images"), "прокрутка-корня")
	var slot_img := _slot_of(nav, "img_map")
	var h := nav.hold(slot_img, "прокрутка-изображений")
	var center_ok: bool = nav.view == "actions" and nav.item_at(0).id == "img_map" and nav.items().size() > 3 \
			and nav.items().slice(1).all(func(x): return x.kind == Item.Kind.ACTION)
	var cancel := nav.back("прокрутка-действий")
	var hold_empty := nav.hold(-1, "пр")
	var folder_actions: bool = nav.view == "actions" and nav.items().slice(1).any(func(x): return x.action == "sort")
	nav.back(null)
	if h["do"] == "reload" and center_ok and cancel["scroll"] == "прокрутка-изображений" and nav.view == "browse" and folder_actions:
		r.pass_("шар действий: удержание — объект в центре и только действия вокруг; «Отмена» возвращает прокрутку; удержание на пустом — действия папки")
	else:
		r.fail("шар действий: %s, центр %s, отмена %s, действия папки %s" % [h, center_ok, cancel, folder_actions])

	# 6. Действие по умолчанию: папка — вход, изображение — просмотр без закрытия, сцена — закрыть,
	# настройка — правка на панели (значение не меняется само).
	var nd = Navigator.new(Catalog.new(), SettingsRes.new())
	nd.short(_slot_of(nd, "images"), null)
	var img := nd.short(_slot_of(nd, "img_sky"), null)
	nd.back(null)
	nd.short(_slot_of(nd, "scenes"), null)
	var scn := nd.short(_slot_of(nd, "scene_cave"), null)
	nd.back(null)
	nd.short(_slot_of(nd, "settings"), null)
	nd.short(_slot_of(nd, "settings_sphere"), null)
	var before_r: Variant = nd.settings.get_value("radius_cm")
	var opt := nd.short(_slot_of(nd, "set_radius_cm"), null)
	if img["do"] == "default" and not img["close"] and scn["do"] == "default" and scn["close"] \
			and opt["do"] == "edit" and opt["id"] == "radius_cm" and nd.settings.get_value("radius_cm") == before_r:
		r.pass_("действие по умолчанию: изображение — просмотр без закрытия, сцена — открыть и закрыть, настройка — правка на панели")
	else:
		r.fail("действие по умолчанию: %s %s %s, радиус %s→%s" % [img, scn, opt, before_r, nd.settings.get_value("radius_cm")])

	# 7. Изменения и отмена: удалить, копировать-вставить, вырезать-вставить, дублировать, новая папка — отмена возвращает всё.
	var cat: Catalog = Catalog.new()
	var nm = Navigator.new(cat, SettingsRes.new())
	var orig := cat.fingerprint()
	nm.short(_slot_of(nm, "assets"), null)
	_do_action(nm, "asset_house", "delete")
	var deleted: bool = not cat.items.has("asset_house")
	_do_action(nm, "asset_bridge", "copy")
	nm.short(_slot_of(nm, "trees"), null)
	nm.hold(-1, null)
	nm.hold(_action_slot(nm, "paste"), null)
	var pasted: bool = (cat.children_of["trees"] as Array).size() == 6
	nm.back(null)
	_do_action(nm, "trees", "cut")
	nm.back(null)
	nm.short(_slot_of(nm, "scenes"), null)
	nm.hold(-1, null)
	nm.hold(_action_slot(nm, "paste"), null)
	var moved: bool = cat.parent_of.get("trees", "") == "scenes"
	_do_action(nm, "scene_tower", "duplicate")
	nm.hold(-1, null)
	nm.hold(_action_slot(nm, "new_folder"), null)
	var self_move := cat.move_to("scenes", "drafts")
	var undos := 5 if falsify != "undo" else 4
	for _i in undos:
		nm.undo()
	if deleted and pasted and moved and not self_move and cat.fingerprint() == orig:
		r.pass_("изменения и отмена: удаление, копирование, перемещение папки, дублирование, новая папка — %d отмен вернули каталог полностью; папка в своего потомка — отказ" % undos)
	else:
		r.fail("изменения и отмена: удалено %s, вставлено %s, перемещено %s, в себя %s, каталог совпал %s" % [deleted, pasted, moved, self_move, cat.fingerprint() == orig])

	# 8. Множественный выбор: отметки, действия группы, удаление группы, отмена.
	var cat2: Catalog = Catalog.new()
	var ms = Navigator.new(cat2, SettingsRes.new())
	var orig2 := cat2.fingerprint()
	ms.short(_slot_of(ms, "logic"), null)
	ms.hold(-1, null)
	ms.hold(_action_slot(ms, "multi"), null)
	ms.short(_slot_of(ms, "logic_door"), null)
	ms.short(_slot_of(ms, "logic_timer"), null)
	ms.short(_slot_of(ms, "logic_quest"), null)
	ms.short(_slot_of(ms, "logic_quest"), null)
	var marked_n: int = ms.marked.size()
	ms.hold(_slot_of(ms, "logic_door"), null)
	var group: bool = ms.item_at(0).id == "group_center" and ms.items().size() == 4
	ms.hold(_action_slot(ms, "delete"), null)
	var gone: bool = not cat2.items.has("logic_door") and not cat2.items.has("logic_timer") and cat2.items.has("logic_quest")
	ms.undo()
	if marked_n == 2 and group and gone and cat2.fingerprint() == orig2 and not ms.multi:
		r.pass_("множественный выбор: повторное нажатие снимает отметку, группа из 2 — три действия, удаление группы и отмена")
	else:
		r.fail("множественный выбор: отмечено %d, группа %s, удалены %s, отмена %s" % [marked_n, group, gone, cat2.fingerprint() == orig2])

	# 9. Сортировка, фильтр, буква, путь, недавние.
	var ns = Navigator.new(Catalog.new(), SettingsRes.new())
	ns.short(_slot_of(ns, "assets"), null)
	ns.short(_slot_of(ns, "trees"), null)
	ns.hold(-1, "tr")
	var letters_res := ns.hold(_action_slot(ns, "letters"), null)
	var letters: Array = ns.items().slice(1).map(func(x): return x.title)
	var focus := ns.short(ns.items().map(func(x): return x.title).find("П"), null)
	var focus_ok: bool = focus["do"] == "focus" and ns.item_at(focus["slot"]).title.begins_with("П")
	ns.hold(-1, null)
	ns.hold(_action_slot(ns, "path"), null)
	var to_root := ns.short(1, null)
	var at_root: bool = ns.state.folder() == "" and ns.view == "browse"
	ns.short(_slot_of(ns, "images"), null)
	ns.short(_slot_of(ns, "img_stone"), null)
	var same_folder_first: String = ns.item_at(0).id
	ns.back(null)
	ns.short(_slot_of(ns, "images"), null)
	var reentry_first: String = ns.item_at(0).id
	ns.hold(-1, null)
	ns.hold(_action_slot(ns, "filter"), null)
	var filtered: bool = ns.items().all(func(x): return x.kind in [Item.Kind.SCENE, Item.Kind.FOLDER])
	if letters_res["do"] == "reload" and letters == ["Б", "Д", "К", "П", "С"] and focus_ok and at_root \
			and same_folder_first != "img_stone" and reentry_first == "img_stone" and filtered:
		r.pass_("переходы: буквы %s и прыжок, путь в корень, недавний — первым только при новом входе, фильтр" % [letters])
	else:
		r.fail("переходы: буквы %s, прыжок %s, корень %s, первый %s/%s, фильтр %s" % [letters, focus, at_root, same_folder_first, reentry_first, filtered])

	# 10. Опасное действие коротким нажатием не исполняется.
	var cat3: Catalog = Catalog.new()
	var nh = Navigator.new(cat3, SettingsRes.new())
	nh.short(_slot_of(nh, "logic"), null)
	nh.hold(_slot_of(nh, "logic_door"), null)
	var del_slot := _action_slot(nh, "delete")
	var try := nh.short(del_slot, null)
	if try["do"] == "need_hold" and cat3.items.has("logic_door") and nh.is_danger(del_slot):
		r.pass_("опасное: короткое на «Удалить» — подсказка удерживать, объект на месте")
	else:
		r.fail("опасное: %s, объект %s" % [try, cat3.items.has("logic_door")])

	_hand_checks()


func _hand_checks() -> void:
	# Стик: точка напротив лица движется с одной угловой скоростью по горизонтали и
	# вертикали при любом наклоне переда к верху зрителя; направления — влево и вниз.
	var st_bad: Array[String] = []
	var ang := 0.01
	var view_up := Vector3.UP
	for tilt_deg in [0.0, 30.0, 60.0, 80.0]:
		var f := Vector3(0, 0, 1).rotated(Vector3.RIGHT, -deg_to_rad(tilt_deg))    # перёд наклонён к верху
		var right_v := view_up.cross(f).normalized()
		var up_t := (view_up - f * view_up.dot(f)).normalized()
		for sv in [Vector2(1, 0), Vector2(0, 1)]:
			var q: Quaternion = Stick.rotation_old(f, view_up, sv, ang) if falsify == "stick" else Stick.rotation(f, view_up, sv, ang)
			var moved: Vector3 = q * f
			var got := moved.angle_to(f)
			var dirn: float = (moved - f).dot(right_v) if sv.x > 0.0 else (moved - f).dot(up_t)
			if absf(got - ang) > ang * 0.01 or dirn >= 0.0:
				st_bad.append("наклон %.0f° стик %s: %.4f рад вместо %.4f, направление %s" % [tilt_deg, sv, got, ang, "верно" if dirn < 0.0 else "обратное"])
	if st_bad.is_empty():
		r.pass_("стик: наклон переда 0–80° — горизонталь и вертикаль двигают точку напротив лица на одинаковый угол, влево и вниз")
	else:
		r.fail("стик: %s" % "; ".join(st_bad))

	# Вращение рукой: «глобус на подставке» — наклон и крен кисти не меняют ориентацию,
	# поворот вокруг вертикали меняет ровно на свой угол; «лицом к шлему» — рука не
	# влияет, +Z шара на голову; «как шар» — ориентация руки.
	# Допуск 2e-3 рад: real_t — float32, angle_to у совпадающих кватернионов даёт
	# до 7e-4 (acos около 1).
	const QTOL := 0.002
	var hf = HandFollow.new()
	var ball := Vector3(0.1, 1.2, -0.3)
	var headp := Vector3(0.0, 1.6, 0.2)
	# собственные наклон (вокруг X кисти) и крен (вокруг её оси −Z)
	var tilt := Quaternion(Vector3.RIGHT, 0.5) * Quaternion(Vector3.BACK, 0.3)
	var yaw := Quaternion(Vector3.UP, 0.7)
	hf.mode = "stand"
	var stand_tilt: Quaternion = hf.target(tilt, ball, headp)
	var stand_yaw: Quaternion = hf.target(yaw * tilt, ball, headp)
	hf.mode = "face"
	var face_a: Quaternion = hf.target(tilt, ball, headp)
	var face_b: Quaternion = hf.target(yaw, ball, headp)
	var face_z: float = (face_a * Vector3.BACK).angle_to(headp - ball)
	hf.mode = "ball"
	var ball_t: Quaternion = hf.target(tilt, ball, headp)
	if stand_tilt.angle_to(Quaternion.IDENTITY) < QTOL and stand_yaw.angle_to(yaw) < QTOL \
			and face_a.angle_to(face_b) < QTOL and face_z < QTOL and ball_t.angle_to(tilt) < QTOL:
		r.pass_("вращение рукой: подставка — наклон с креном 0 рад, курс 0.7 при наклоне с креном; лицом к шлему — рука не влияет, +Z на голову; как шар — рука")
	else:
		r.fail("вращение рукой: подставка наклон %.4f, курс %.4f; лицом %.4f, на голову %.4f; шар %.4f" % [
				stand_tilt.angle_to(Quaternion.IDENTITY), stand_yaw.angle_to(yaw), face_a.angle_to(face_b), face_z, ball_t.angle_to(tilt)])

	# Сглаживание: рывок кисти на 1 рад — шар догоняет монотонно, без перелёта, не за
	# один кадр, и за секунду; «кисть вращается» поднят на рывке и снят после.
	var sm = HandFollow.new()
	sm.mode = "ball"
	sm.smoothing = 0.0 if falsify == "smooth" else 0.5
	var dt := 1.0 / 90.0
	sm.update(Quaternion.IDENTITY, ball, headp, dt)
	var goal := Quaternion(Vector3.UP, 1.0)
	var trace: Array[float] = []
	var rot_on := false
	for i in 90:
		var got_q: Quaternion = sm.update(goal, ball, headp, dt)
		trace.append(got_q.angle_to(Quaternion.IDENTITY))
		if i == 0:
			rot_on = sm.rotating()
	var mono := true
	for i in range(1, trace.size()):
		if trace[i] < trace[i - 1] - 1e-6:
			mono = false
	var over: bool = float(trace.max()) > 1.0 + 1e-4
	if mono and not over and trace[0] < 0.9 and absf(trace.back() - 1.0) < 0.01 and rot_on and not sm.rotating():
		r.pass_("сглаживание руки 0.5: рывок 1 рад — первый кадр %.3f, за 1 с %.4f, монотонно без перелёта; «вращается» на рывке и снят после" % [trace[0], trace.back()])
	else:
		r.fail("сглаживание руки: первый кадр %.3f (нужно < 0.9), за 1 с %.4f, монотонно %s, перелёт %s, вращается на рывке %s, после %s" % [
				trace[0], trace.back(), mono, over, rot_on, sm.rotating()])

	_edit_checks()


func _edit_checks() -> void:
	# Правка значения: клавиатура «2,75» → 2.75 по OK (до OK значение не меняется),
	# ⌫ стирает, ввод за пределом — ограничение и сообщение, ползунок и −/+ округляют,
	# выбор ставит вариант, «По умолчанию» — умолчание.
	var es = SettingsRes.new()
	es.values["radius_cm"] = 9.0
	var ed = SettingEdit.new(es, "radius_cm")
	var cell = SettingEdit.new(es, "cell_cm")
	for k in ["2", ",", "7", "9", "⌫"]:
		cell.key("," if k == "," else k)
	var typed_text: String = cell.text()
	var before_ok: Variant = es.get_value("cell_cm")
	if falsify == "keypad":
		cell.typed = cell.typed.replace(",", "x")
	var changed_ok: bool = cell.key("OK")
	var got_cell: float = float(es.get_value("cell_cm"))
	for k in ["4", "0", "OK"]:
		ed.key(k)
	var clamped_msg: String = ed.message
	var clamped_v: float = float(es.get_value("radius_cm"))
	ed.slider(12.26)
	var slid: float = float(es.get_value("radius_cm"))
	ed.nudge(-1)    # шаг радиуса: 1/20 шкалы 6…20 = 0,7 → округление 0,5
	var nudged: float = float(es.get_value("radius_cm"))
	var ch = SettingEdit.new(es, "hand_rotation")
	ch.choose(1)
	var chosen: Variant = es.get_value("hand_rotation")
	ed.default()
	if typed_text == "2,7_" and before_ok == SettingsRes.SPEC["cell_cm"]["default"] and changed_ok \
			and is_equal_approx(got_cell, 2.7) and is_equal_approx(clamped_v, 20.0) and clamped_msg.begins_with("Допустимо") \
			and is_equal_approx(slid, 12.5) and is_equal_approx(nudged, 12.0) and chosen == "stand" \
			and is_equal_approx(float(es.get_value("radius_cm")), 11.0):
		r.pass_("правка значения: «2,79⌫» → «2,7_», OK → 2,7; «40» → 20 с сообщением; ползунок 12,26 → 12,5; − → 12; выбор «на подставке»; умолчание 11")
	else:
		r.fail("правка значения: набор «%s», до OK %s, OK изменил %s → %s; «40» → %s («%s»); ползунок → %s; − → %s; выбор %s; умолчание %s" % [
				typed_text, before_ok, changed_ok, got_cell, clamped_v, clamped_msg, slid, nudged, chosen, es.get_value("radius_cm")])

	# Демонстрации: каждая поддержанная доходит до конца; стик рисует замкнутый
	# квадрат (шар вернулся), доводка уводит ровно на свою долю ячейки, липкость
	# возвращает шар, удержание доводит кольцо до 1, сглаживание дёргает руку.
	var demo_bad: Array[String] = []
	for id in DemoRes.IDS:
		var dm = DemoRes.new()
		dm.start(id, 0.2, 2.0, 400.0)
		var q := Quaternion.IDENTITY
		var f := Vector3(0, 0, 1)
		var max_shift := 0.0
		var max_prog := 0.0
		var jerked := false
		var flung := false
		var frames := 0
		while dm.running() and frames < 1000:
			frames += 1
			var d: Dictionary = dm.update(1.0 / 90.0)
			if falsify == "demo" and id == "stick_speed" and dm.t > 1.5:
				d = {}
			if d.has("stick"):
				# как у меню: перёд и верх неподвижны в системе шара, поворот копится
				# в ориентации ячеек (surface_globe.apply_rotation)
				q = (Stick.rotation(f, Vector3.UP, d["stick"], float(d["angle"])) * q).normalized()
			max_shift = maxf(max_shift, (q * f).angle_to(f))
			max_prog = maxf(max_prog, float(d.get("progress", 0.0)))
			jerked = jerked or (d.has("hand") and not (d["hand"] as Quaternion).is_equal_approx(Quaternion.IDENTITY))
			flung = flung or d.get("fling", false)
		var end_shift := (q * f).angle_to(f)
		match id:
			"stick_speed", "hysteresis":
				if end_shift > 0.01:
					demo_bad.append("%s: шар не вернулся, %.3f рад" % [id, end_shift])
			"detent":
				if absf(end_shift - DemoRes.DETENT_SHIFT * 0.2) > 0.002:
					demo_bad.append("detent: сдвиг %.4f вместо %.4f" % [end_shift, DemoRes.DETENT_SHIFT * 0.2])
			"hold_ms":
				if max_prog < 0.999:
					demo_bad.append("hold_ms: кольцо %.2f" % max_prog)
			"hand_smoothing":
				if not jerked:
					demo_bad.append("hand_smoothing: рывка нет")
			"grab_friction":
				if not flung:
					demo_bad.append("grab_friction: броска нет")
		if dm.running():
			demo_bad.append("%s: не закончилась за %d кадров" % [id, frames])
	if demo_bad.is_empty() and not DemoRes.supports("radius_cm"):
		r.pass_("демонстрации %s: доходят до конца; стик (вправо-обратно, вниз-обратно) и липкость возвращают шар, доводка уводит на 0,6 ячейки, кольцо до 1, рывок руки, бросок" % str(DemoRes.IDS))
	else:
		r.fail("демонстрации: %s" % "; ".join(demo_bad))


static func _slot_of(nav: RefCounted, id: String) -> int:
	var list: Array = nav.items()
	for i in list.size():
		if list[i].id == id:
			return i
	return -1


static func _action_slot(nav: RefCounted, action: String) -> int:
	var list: Array = nav.items()
	for i in list.size():
		if list[i].action == action:
			return i
	return -1


## Удержание на объекте → действие (опасное — удержанием, прочие — коротким).
static func _do_action(nav: RefCounted, id: String, action: String) -> void:
	nav.hold(_slot_of(nav, id), null)
	var s := _action_slot(nav, action)
	if nav.is_danger(s):
		nav.hold(s, null)
	else:
		nav.short(s, null)
