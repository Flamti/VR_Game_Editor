extends Node

## Маршрут ввода: кто ведёт меню, что при этом видно и когда ввод вообще разрешён.
##
## Держит арбитр (input/input_arbiter.gd), оба источника (контроллеры, руки) и их визуализацию.
## Живёт отдельно от main.gd, потому что дымовой прогон собирает меню мимо оркестратора: логика в
## main.gd была бы ему не видна (PRACTICES §1.10).
##
## Ввод — только после ready. Сессия 11 (2026-09-19): кулак закрыл и открыл шар в 5.1 и 6.3 с, пока
## шла самопроверка. До ready арбитр наблюдает и визуализация следует за источником, но ни один
## источник меню не трогает.

## Источник сменился: src — новый, why — по какому свидетелю, witnesses — снимок для журнала.
signal source_changed(src: String, why: String, witnesses: Dictionary)
## Жест руки распознан — в журнал.
signal gesture(name: String, data: Dictionary)
## Решено, какие модели контроллеров видны: "рантайм" | "запасные".
signal controller_models(kind: String)
## Меню перешло на набор настроек этого способа ввода.
signal settings_switched(input: String)

const Menu := preload("res://menu/sphere_menu.gd")
const UiPanel := preload("res://menu/ui_panel.gd")
const Controllers := preload("res://input/controller_source.gd")
const Hands := preload("res://input/hand_source.gd")
const Arbiter := preload("res://input/input_arbiter.gd")
const HandView := preload("res://input/hand_view.gd")
const ControllerView := preload("res://input/controller_view.gd")
const InputSettings := preload("res://profile/input_settings.gd")

var arbiter: Arbiter = Arbiter.new()
var controllers: Controllers
var hands: Hands
var hand_view: HandView = HandView.new()
var controller_view: ControllerView = ControllerView.new()
## Наборы настроек по способу ввода; null — один набор (дымовые шаги рук, собранные без профиля).
var input_settings: InputSettings
var menu: Menu
var left: XRController3D
var right: XRController3D
## Ввод разрешён: самопроверка кончилась, профиль загружен.
var input_ready := false
## Каждый кадр спрашивать трекеры XRServer. Дымовой прогон выключает и кормит feed() сам.
var auto_observe := true
## Фальсификатор «earlyinput»: источник берёт меню сразу, не дожидаясь ready.
var falsify_ignore_ready := false
## Фальсификатор «noswitch»: смена источника не меняет набор настроек, как до профилей.
var falsify_no_switch := false


func setup(origin: Node3D, p_left: XRController3D, p_right: XRController3D, p_menu: Menu,
		panel: UiPanel, session: Node) -> void:
	left = p_left
	right = p_right
	menu = p_menu
	controllers = Controllers.new()
	# Источники ходят после роутера: кадр ведёт тот, кого выбрали в этом же кадре.
	controllers.process_priority = 1
	add_child(controllers)
	controllers.setup(left, right, menu, session)
	controllers.panel = panel
	controllers.enabled = false
	hands = Hands.new()
	hands.process_priority = 1
	add_child(hands)
	hands.setup(origin, menu, session)
	hands.panel = panel
	hands.gesture.connect(func(n: String, d: Dictionary): gesture.emit(n, d))
	hand_view.setup(origin)
	controller_view.setup(origin)
	arbiter.changed.connect(_on_source)
	menu.input_source = arbiter.current
	_show(arbiter.current, Time.get_ticks_msec())


func current() -> String:
	return arbiter.current


func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	if auto_observe and menu != null:
		arbiter.mode = menu.settings.get_value("input_source")
		arbiter.feed(now, Arbiter.observe(left, right))
	hand_view.update()
	var kind := controller_view.update(now)
	if kind != "":
		controller_models.emit(kind)


## Снимок свидетелей — от шлема (_process) или от проверки.
func feed(now_ms: int, w: Dictionary) -> void:
	arbiter.feed(now_ms, w)


## Самопроверка кончилась и профиль загружен — управление получает текущий источник.
func set_ready() -> void:
	input_ready = true
	_take(arbiter.current)


func _on_source(src: String, why: String) -> void:
	menu.input_source = src
	_show(src, Time.get_ticks_msec())
	if input_ready or falsify_ignore_ready:
		_take(src)
	source_changed.emit(src, why, arbiter.witnesses())


## Видимость — сразу, даже до ready: видеть свою руку безопасно, трогать меню — нет.
func _show(src: String, now_ms: int) -> void:
	hand_view.set_active(src == Arbiter.HANDS)
	controller_view.set_active(src == Arbiter.CONTROLLERS, now_ms)


## Передача управления: уходящий источник бросает начатое без события, шар переезжает на руку
## нового.
func _take(src: String) -> void:
	if src == Arbiter.HANDS:
		controllers.release()
		# Пока поза руки не пришла, шар стоит там, где его держал контроллер.
		hands.activate(left.global_transform)
		menu.hand = hands.anchor
	else:
		hands.release()
		controllers.enabled = true
		menu.hand = left
	# Настройки — того, кто ведёт. Только здесь, после ready: самопроверка меняет и возвращает
	# значения сама, и смена набора посреди неё записала бы её раскладки в профиль.
	if input_settings != null and not falsify_no_switch and input_settings.switch(src):
		menu.apply_settings()
		menu.catalog.apply_input(menu.settings)
		menu.refresh_list()
		settings_switched.emit(src)
