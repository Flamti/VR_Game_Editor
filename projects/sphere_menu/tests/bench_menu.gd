extends SceneTree

## Замер скриптов кадра меню при вращении (PRACTICES §3.7: оптимизация без замера до и после —
## долг). Не проверка: печатает числа, отказов нет.
##
## Запуск:
##   godot/bin/godot.linuxbsd.editor.x86_64 --headless --path projects/sphere_menu \
##       --script res://tests/bench_menu.gd
##
## Папка «Много файлов» (128), самые мелкие ячейки при самом большом радиусе, вращение 1.5 рад/с:
## глобус (632 ячейки) и линза (700), подписи шейдером. Меряется Menu._process целиком; рядом —
## пересчёты ячеек и сборки строк подписей. Настольный процессор не шлем:
## смысл — сравнение режимов и до/после. До шага 1з этот замер назывался bench_lens.gd.

const Menu := preload("res://menu/sphere_menu.gd")
const Panel3D := preload("res://menu/ui_panel.gd")
const Settings := preload("res://menu/settings.gd")

const FRAMES := 240
const WARMUP := 30
const SPIN := 1.5
const CASES := [["globe"], ["lens"]]

var menu: Menu
var _frame := -3      # меню собирается в _ready — настройка кадром позже
var _case := 0
var _times := PackedFloat64Array()
var _redraws0 := 0
var _rebuilds0 := 0


func _initialize() -> void:
	var root3d := Node3D.new()
	get_root().add_child(root3d)
	var head := Node3D.new()
	head.position = Vector3(0, 0, 0.4)
	root3d.add_child(head)
	menu = Menu.new()
	menu.head = head
	root3d.add_child(menu)
	var panel := Panel3D.new()
	root3d.add_child(panel)
	menu.panel = panel


func _setup(c: Array) -> void:
	var st: Settings = menu.settings
	st.values["surface"] = c[0]
	st.values["radius_cm"] = Settings.SPEC["radius_cm"]["max"]
	st.values["cell_cm"] = Settings.SPEC["cell_cm"]["min"]
	menu.apply_settings()
	if not menu.is_open():
		menu.toggle()
	# «Много файлов»: корень → Файлы → папка
	while menu.nav.state.folder() != "":
		menu.back()
	for id in ["files", "bulk"]:
		var list: Array = menu.nav.items()
		for i in list.size():
			if list[i].id == id:
				menu._handle(menu.nav.short(i, menu._scroll()))
				break
	menu.debug_spin = SPIN
	# Не в _initialize: на NOTIFICATION_READY Godot сам включает обработку узлу с _process, и
	# кадр меню шёл бы дважды — движком и замером (первый прогон: 481 пересчёт за 240 кадров).
	menu.set_process(false)
	_times.clear()
	_frame = 0


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame < 0:
		return false
	if _frame == 0:
		_setup(CASES[0])
		return false
	if _frame == WARMUP:
		_redraws0 = menu.renderer.redraws
		_rebuilds0 = menu.label_text.rebuilds
	var t0 := Time.get_ticks_usec()
	menu._process(1.0 / 90.0)
	var dt := float(Time.get_ticks_usec() - t0) / 1000.0
	if _frame > WARMUP:
		_times.append(dt)
	if _frame < WARMUP + FRAMES:
		return false
	var s := _times.duplicate()
	s.sort()
	var c: Array = CASES[_case]
	print("bench %s: папка %s, %d ячеек, пунктов на странице %d, Menu._process медиана %.3f мс, p95 %.3f мс; пересчётов ячеек %d, сборок подписей %d за %d кадров" % [
			c[0], menu.nav.state.folder(), menu.renderer.drawn, menu.nav.items().size(), s[s.size() / 2],
			s[int(s.size() * 0.95)], menu.renderer.redraws - _redraws0, menu.label_text.rebuilds - _rebuilds0, FRAMES])
	_case += 1
	if _case >= CASES.size():
		return true
	_setup(CASES[_case])
	return false
