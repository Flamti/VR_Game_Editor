extends "res://menu/info_panel.gd"

## Интерактивная панель (Ф2, шаг 1в): правка настройки ползунком, −/+, цифровой
## клавиатурой; кнопки мастера и демонстрации.
##
## Способ — как в официальном демо Godot «GUI in 3D»: 2D-интерфейс живёт в
## SubViewport на кваде, луч (или кончик контроллера) пересекает квад, точка
## переводится в пиксели вьюпорта и отдаётся InputEventMouseMotion/Button через
## Viewport.push_input(event, true) — координаты уже во вьюпорте. Вьюпорт вне
## SubViewportContainer, поэтому вход и выход указателя сообщаются сами
## (notify_mouse_entered/exited, doc/classes/Viewport.xml).
## Отвергнуто: свои 3D-кнопки с попаданием по AABB — пришлось бы заново писать
## ползунок, перетаскивание и подсветку, которые у Control уже есть.
##
## Крупные цели (кнопка ≥ 56 px ≈ 19 мм на кваде) — по рекомендациям Meta к
## размерам целей в VR; числа — выбор, не измерение.

signal edit_changed
signal button(name: String)
## Текст ввода поиска изменился — с системной клавиатуры или с раскладки панели.
signal text_changed(text: String)
## Системная клавиатура: «show»/«hide» — запрошен показ или скрытие; «unavailable» — у
## платформы её нет (настольный прогон), ввод только раскладкой панели.
signal keyboard(state: String)

const SettingEdit := preload("res://menu/setting_edit.gd")
const Settings := preload("res://menu/settings.gd")

const BUTTON_TITLES := {"back": "Назад", "default": "Умолч.", "demo": "Демо", "next": "Далее",
		"done": "Готово", "save": "Сохранить", "keyboard": "Клавиатура", "cancel": "Отмена", "unpin": "Снять PIN",
		"other": "Другой", "check": "Проверить", "disconnect": "Отключить", "import": "Из файла"}
## Раскладка поиска на панели — одно из двух значений настройки «Клавиатура поиска» (второе —
## системная клавиатура Quest, ADR-0009). Обе сразу мешали (сессия 7).
const TEXT_KEYS := ["Й", "Ц", "У", "К", "Е", "Н", "Г", "Ш", "Щ", "З", "Х", "Ъ", "Ф", "Ы", "В", "А", "П", "Р",
		"О", "Л", "Д", "Ж", "Э", "Я", "Ч", "С", "М", "И", "Т", "Ь", "Б", "Ю", "Ё", "␣", "⌫", "C"]
## Цифры — для PIN и чисел профиля (рост); всегда на панели, не системной клавиатурой: вид системной
## клавиатуры с маской на Quest не проверен, а PIN виден тому, кто стоит рядом со шлемом, только
## звёздочками.
const DIGIT_KEYS := ["1", "2", "3", "4", "5", "6", "7", "8", "9", "⌫", "0", "C"]
## Кончик у панели: расстояние до плоскости квада, м.
const TIP_GAP := 0.02
## Полоса содержимого правки: окно прокрутки 480 минус полоса прокрутки, px.
## Кнопки ▲/▼ ушли в нижнюю строку, и колонка справа больше ширину не отнимает.
const EDIT_WIDTH := 468.0
## Ползунок между кнопками −/+ (по 72 px по краям полосы, зазор 8).
const SLIDER_WIDTH := 308.0

var edit: SettingEdit = null
## Строка под значением (например, фактический размер ячейки глобуса).
var note_fn: Callable
var _editor: Control
var _info_nodes: Array[CanvasItem] = []
var _e_title: Label
var _e_value: Label
## Сколько нашёл поиск. Сессия 10: владелец набрал слово, которого в каталоге нет, и по
## пустому шару не отличил «не нашлось» от «поиск не работает».
var _e_found: Label
var _e_hint: Label
var _number_box: Control
var _e_scroll: ScrollContainer
var _e_box: VBoxContainer
## Фальсификатор «editscroll» дымового прогона: в окне прокрутки остаётся одно пояснение,
## как было в шаге 1д, — остальное содержимое правки снова стоит на месте.
var falsify_hint_only := false
var _slider: HSlider
var _marks_box: Control
var _choice_box: VBoxContainer
var _buttons_box: HBoxContainer
var _text_box: GridContainer
var _digit_box: GridContainer
## Ввод текста: звёздочки вместо символов, предел длины, цифры вместо букв (open_text, opts).
var _masked := false
var _max_len := 40
var _digits := false
## Регистр набранного сохраняется (ключи API); иначе — нижний, как в поиске.
var _keep_case := false
## Фальсификатор «keylower»: регистр не сохраняется — ключ API с заглавными ломается при вводе.
var falsify_lower_always := false
## Набранный текст поиска.
var text := ""
## Длина запроса поиска — одна на обе клавиатуры.
const TEXT_MAX := 40
## Сколько раз запрошен показ системной клавиатуры — для дымового прогона.
var keyboard_requests := 0
## Фальсификатор «imekey» дымового прогона: ввод системной клавиатуры не принимается.
var falsify_no_ime := false
## Фальсификатор «enterclose»: «Готово» системной клавиатуры снова закрывает поиск (как в сессии 7).
var falsify_enter_closes := false
## Фальсификатор «found»: строка «найдено» молчит, как до сессии 10.
var falsify_found_mute := false
## Запрос показа считается, но системная клавиатура не зовётся: самопроверка сессии 7 показывала
## её посреди замеров.
var keyboard_dry_run := false
## Ввод поиска открыт и каким способом: «system» — системная клавиатура, «panel» — раскладка.
var _text_mode := ""
## Одно «Готово» системной клавиатуры приходит несколькими ENTER за 20 мс (журнал сессии 8: три
## пары hide/enter) — повторы в этом окне отбрасываются.
const ENTER_REPEAT_MS := 150
var _last_enter_ms := -100000
var _syncing := false
var _pointer_in := false
var _pointer_down := false
var _pointer_px := Vector2(-1, -1)
## Курок зажат до входа на панель: нажатием не считается, пока не отпустят.
var _await_release := false
## Панелью управляет проверка: указатель контроллера (source «user») игнорируется. Самопроверка
## сессии 2: между её нажатием и перетаскиванием обычный ввод увидел настоящий луч мимо панели
## и отпустил кнопку — ползунок не доехал, проверка покраснела на рабочей панели.
var synthetic_lock := false
## Пиксель, куда пришёлся последний указатель, — для самопроверки и дымового прогона.
var last_pointer: Variant = null


func _ready() -> void:
	super._ready()
	for c in viewport.get_children():
		# кнопки прокрутки не принадлежат режиму информации: они обслуживают и итог
		# мастера, а их видимость считает _sync_scroll_ui по активному окну
		if c is CanvasItem and not (c is Panel) and c != _up_btn and c != _down_btn:
			_info_nodes.append(c)
	_build_editor()


func interactive() -> bool:
	return _editor != null and _editor.visible


## Окно прокрутки: в правке и итоге мастера — своё, иначе содержимое панели.
func active_scroll() -> ScrollContainer:
	return _e_scroll if interactive() else super.active_scroll()


## Панель берёт указатель: правка открыта либо содержимое не влезло и его надо
## прокрутить. Пока прокручивать нечего, луч в режиме информации проходит мимо
## панели к ячейкам шара под ней.
func pointer_active() -> bool:
	return visible and (interactive() or scrollable())


## Кнопка указателя зажата на панели (перетаскивание ползунка ушло за край квада).
func pointer_held() -> bool:
	return _pointer_down


# --- содержимое ---------------------------------------------------------------------

## Правка настройки. buttons — имена из BUTTON_TITLES по порядку слева направо.
func open_editor(p_edit: SettingEdit, title: String, buttons: Array, p_note: Callable = Callable()) -> void:
	# Фальсификатор «editscroll»: ползунок с цифрами снова живёт вне окна прокрутки —
	# ровно как в шаге 1д, где ехало одно пояснение.
	if falsify_hint_only and _number_box.get_parent() == _e_box:
		_e_box.remove_child(_number_box)
		_editor.add_child(_number_box)
		_number_box.position = Vector2(50, 240)
	edit = p_edit
	note_fn = p_note
	_set_info_visible(false)
	_editor.visible = true
	_e_title.text = title
	var spec := edit.spec()
	var is_num := edit.is_number()
	_number_box.visible = is_num
	_choice_box.visible = not is_num
	_text_box.visible = false
	_digit_box.visible = false
	if is_num:
		_syncing = true
		_slider.min_value = float(spec["min"])
		_slider.max_value = float(spec["max"])
		_slider.step = float(spec["round"])
		_slider.value = float(edit.value())
		_syncing = false
		_build_marks(spec)
	else:
		for c in _choice_box.get_children():
			c.queue_free()
		var opts: Array = spec["options"]
		for i in opts.size():
			var b := _button(str(opts[i][1]), Vector2(464, 64), 26)
			b.toggle_mode = true
			b.pressed.connect(_on_choice.bind(i))
			_choice_box.add_child(b)
	_set_buttons(buttons)
	refresh()


## Итог мастера: строки и кнопки, без правки.
func open_summary(title: String, lines: PackedStringArray, buttons: Array) -> void:
	edit = null
	_set_info_visible(false)
	_editor.visible = true
	_e_title.text = title
	_e_value.text = ""
	_e_hint.text = "\n".join(lines)
	scroll_reset()
	_number_box.visible = false
	_choice_box.visible = false
	_text_box.visible = false
	_digit_box.visible = false
	_set_buttons(buttons)
	_last_key = ""
	_dirty()


## Ввод текста. mode «system» — системная клавиатура Quest, на панели только поле и
## кнопки «Клавиатура» (показать снова) и «Готово»; «panel» — русская раскладка лучом.
## opts — для полей, кроме поиска: hint (подсказка), digits (цифровая клавиатура, всегда на панели),
## masked (звёздочки), max (предел длины), text (начальное значение), keep_case (не приводить к нижнему
## регистру — ключи API). Без opts — поиск, как был.
func open_text(title: String, buttons: Array, mode: String = "system", opts: Dictionary = {}) -> void:
	edit = null
	_digits = opts.get("digits", false)
	_masked = opts.get("masked", false)
	_max_len = int(opts.get("max", TEXT_MAX))
	_keep_case = opts.get("keep_case", false) and not falsify_lower_always
	if _digits:
		mode = "panel"
	text = str(opts.get("text", ""))
	_text_mode = mode
	_set_info_visible(false)
	_editor.visible = true
	_e_title.text = title
	_e_value.text = _shown() + "_"
	_e_found.text = ""
	# Сессия 10: прежняя подсказка «„Готово“ на клавиатуре — ...» прочиталась как «наберите слово
	# Готово», владелец так и сделал дважды и ничего не нашёл. Первым словом — действие, а не кавычки.
	if opts.has("hint"):
		_e_hint.text = opts["hint"]
	elif mode == "system":
		_e_hint.text = "наберите часть имени; выбрать найденное на шаре можно, спрятав клавиатуру («Готово» на ней)"
	else:
		_e_hint.text = "наберите часть имени лучом; кнопка «Готово» на панели закрывает поиск"
	scroll_reset()
	_number_box.visible = false
	_choice_box.visible = false
	_text_box.visible = mode == "panel" and not _digits
	_digit_box.visible = _digits
	_set_buttons((["keyboard"] + buttons) if mode == "system" else buttons)
	_last_key = ""
	_dirty()
	if mode == "system":
		_keyboard_show()


## Сколько нашёл поиск: показывается под набранным словом, пока ввод открыт. Пустой запрос ничего
## не ищет, поэтому и строки нет (иначе «ничего не найдено» висело бы до первой буквы).
func set_found(n: int) -> void:
	if _text_mode == "" or falsify_found_mute:
		return
	if text == "":
		_e_found.text = ""
	elif n <= 0:
		_e_found.text = "ничего не найдено"
	else:
		_e_found.text = "найдено: %d" % n
	_dirty()


## Подсказка под полем ввода — сообщения профиля («неверный PIN», «подождите»).
func set_hint(t: String) -> void:
	_e_hint.text = t
	_dirty()


func hint_text() -> String:
	return _e_hint.text


## Очистить набранное (после неверного PIN).
func clear_text() -> void:
	text = ""
	_text_changed()


func found_text() -> String:
	return _e_found.text


func is_text_open() -> bool:
	return interactive() and _text_mode != ""


func text_mode() -> String:
	return _text_mode


## Кнопка «Клавиатура»: показать системную снова с набранным текстом.
func keyboard_again() -> void:
	if _text_mode == "system":
		_keyboard_show()


func close_editor() -> void:
	if _text_mode == "system":
		_keyboard_hide()
	_text_mode = ""
	edit = null
	if _editor != null:
		_editor.visible = false
	_set_info_visible(true)
	_pointer_release()
	_last_key = ""
	_dirty()


## Перечитать значение после изменения снаружи (умолчание, мастер назад).
func refresh() -> void:
	if edit == null:
		return
	scroll_reset()
	_e_value.text = edit.text()
	var hint: String = edit.spec()["hint"]
	var note: String = note_fn.call() if note_fn.is_valid() else ""
	var lines := PackedStringArray()
	if note != "":
		lines.append(note)
	lines.append(edit.message if edit.message != "" else hint)
	_e_hint.text = "\n".join(lines)
	if edit.is_number():
		_syncing = true
		_slider.value = float(edit.value())
		_syncing = false
	else:
		var idx: int = edit.settings.option_index(edit.id)
		var kids := _choice_box.get_children()
		for i in kids.size():
			(kids[i] as Button).set_pressed_no_signal(i == idx)
	_last_key = ""
	_dirty()


# --- указатель ------------------------------------------------------------------------

## Точка пересечения луча с квадом в пикселях вьюпорта; null — мимо.
func pointer_ray(origin: Vector3, dir: Vector3) -> Variant:
	var inv := global_transform.affine_inverse()
	var o := inv * origin
	var d := inv.basis * dir
	if absf(d.z) < 1e-6:
		return null
	var t := -o.z / d.z
	if t < 0.0:
		return null
	return _to_px(o + d * t)


## Кончик контроллера у квада (ближе TIP_GAP к плоскости) — пиксели; иначе null.
func pointer_tip(tip: Vector3) -> Variant:
	var p := global_transform.affine_inverse() * tip
	if absf(p.z) > TIP_GAP:
		return null
	return _to_px(p)


func _to_px(p: Vector3) -> Variant:
	if absf(p.x) > QUAD.x * 0.5 or absf(p.y) > QUAD.y * 0.5:
		return null
	return Vector2((p.x / QUAD.x + 0.5) * VIEW_SIZE.x, (0.5 - p.y / QUAD.y) * VIEW_SIZE.y)


## Указатель в пикселях (null — вне панели) и состояние кнопки. Зовётся каждый кадр.
## source — кто ведёт указатель: «user» (контроллер) или имя проверки.
func pointer_update(px: Variant, pressed: bool, source: String = "user") -> void:
	if synthetic_lock and source == "user":
		return
	if px == null or not pointer_active():
		_pointer_release()
		return
	last_pointer = px
	if not _pointer_in:
		viewport.notify_mouse_entered()
		_pointer_in = true
		_await_release = pressed
	if _await_release:
		if pressed:
			pressed = false
		else:
			_await_release = false
	var pos: Vector2 = px
	# Перетаскивание содержимого лучом (режим информации): указатель ведёт панель за
	# собой 1:1. Отвергнуто: штатное touch-перетаскивание ScrollContainer через
	# InputEventScreenTouch/Drag — оно зависит от эмуляции касаний во вьюпорте, тогда
	# как мышиный путь push_input уже отлажен на ползунке; колесо мыши даёт ступени,
	# а не ход за рукой.
	if not interactive() and _pointer_down and _pointer_px.x >= 0.0 and not over_scroll_button(pos):
		scroll_how = "drag"
		scroll_by(_pointer_px.y - pos.y)
	if pos != _pointer_px:
		var mm := InputEventMouseMotion.new()
		mm.position = pos
		mm.global_position = pos
		mm.relative = pos - _pointer_px if _pointer_px.x >= 0.0 else Vector2.ZERO
		mm.button_mask = MOUSE_BUTTON_MASK_LEFT if _pointer_down else 0
		viewport.push_input(mm, true)
		_pointer_px = pos
		_dirty()
	if pressed != _pointer_down:
		var mb := InputEventMouseButton.new()
		mb.position = pos
		mb.global_position = pos
		mb.button_index = MOUSE_BUTTON_LEFT
		mb.pressed = pressed
		mb.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		_pointer_down = pressed
		viewport.push_input(mb, true)
		_dirty()


func _pointer_release() -> void:
	if _pointer_down and viewport != null:
		var mb := InputEventMouseButton.new()
		mb.position = _pointer_px
		mb.global_position = _pointer_px
		mb.button_index = MOUSE_BUTTON_LEFT
		mb.pressed = false
		viewport.push_input(mb, true)
		_pointer_down = false
	if _pointer_in and viewport != null:
		viewport.notify_mouse_exited()
		_pointer_in = false
		_pointer_px = Vector2(-1, -1)
		_dirty()


# --- построение ---------------------------------------------------------------------

## Содержимое режима информации ↔ содержимое правки. Заодно решает судьбу самой
## панели: правка, мастер и поиск — это сценарий, панель им нужна, даже когда шар
## закрыт (иначе «Готово» пропало бы). Когда правка закрывается, слово снова за
## меню: _update_panel в том же кадре покажет панель, если есть что показывать.
func _set_info_visible(on: bool) -> void:
	for n in _info_nodes:
		n.visible = on
	visible = not on
	scroll_reset()


func _build_editor() -> void:
	_editor = Control.new()
	_editor.size = Vector2(VIEW_SIZE)
	_editor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_editor.visible = false
	viewport.add_child(_editor)

	# Всё содержимое правки — в том же окне прокрутки, что и режим информации
	# (отзыв сессии 4: ехало только пояснение, а ползунок, цифры и варианты стояли).
	# Вне прокрутки остаётся одна строка кнопок: «Готово» и «Далее» обязаны быть под
	# рукой всегда, докручивать до них нечестно.
	_e_scroll = make_scroll(SCROLL_RECT)
	_editor.add_child(_e_scroll)
	_e_box = VBoxContainer.new()
	_e_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_e_box.add_theme_constant_override("separation", 8)
	_e_box.sort_children.connect(_dirty)    # раскладка отложена на кадр — см. info_panel
	_e_scroll.add_child(_e_box)

	_e_title = _elabel(30, Color.WHITE)
	_e_value = _elabel(34, Color(1.0, 0.85, 0.35))
	_e_found = _elabel(22, Color(0.62, 0.84, 0.66))
	_e_hint = _elabel(19, Color(0.80, 0.84, 0.90))

	_number_box = Control.new()
	_number_box.custom_minimum_size = Vector2(EDIT_WIDTH, 370)
	_number_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_e_box.add_child(_number_box)
	var minus := _button("−", Vector2(72, 64), 36)
	minus.position = Vector2(0, 0)
	minus.pressed.connect(func(): _on_nudge(-1))
	_number_box.add_child(minus)
	var plus := _button("+", Vector2(72, 64), 36)
	plus.position = Vector2(EDIT_WIDTH - 72, 0)
	plus.pressed.connect(func(): _on_nudge(1))
	_number_box.add_child(plus)
	_slider = HSlider.new()
	_slider.position = Vector2(80, 0)
	_slider.size = Vector2(SLIDER_WIDTH, 64)
	_slider.focus_mode = Control.FOCUS_NONE
	_slider.add_theme_icon_override("grabber", _disc(36, Color(1.0, 0.85, 0.35)))
	_slider.add_theme_icon_override("grabber_highlight", _disc(40, Color(1.0, 0.95, 0.6)))
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.30, 0.34, 0.42)
	track.content_margin_top = 6
	track.content_margin_bottom = 6
	track.set_corner_radius_all(6)
	_slider.add_theme_stylebox_override("slider", track)
	var fill := track.duplicate() as StyleBoxFlat
	fill.bg_color = Color(0.55, 0.65, 0.85)
	_slider.add_theme_stylebox_override("grabber_area", fill)
	_slider.add_theme_stylebox_override("grabber_area_highlight", fill)
	_slider.value_changed.connect(_on_slider)
	_number_box.add_child(_slider)
	_marks_box = Control.new()
	_marks_box.position = Vector2(80, 66)
	_marks_box.size = Vector2(SLIDER_WIDTH, 28)
	_marks_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_number_box.add_child(_marks_box)
	var grid := GridContainer.new()
	grid.columns = 4
	# 4 колонки по 72 с зазором 8 — 312 px, по центру полосы
	grid.position = Vector2((EDIT_WIDTH - 312) * 0.5, 104)
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	for k in SettingEdit.KEYS:
		var kb := _button(k, Vector2(152 if k == "OK" else 72, 56), 28)
		kb.pressed.connect(_on_key.bind(k))
		grid.add_child(kb)
	_number_box.add_child(grid)

	# Клавиша снова 70 px (24 мм на кваде): в полосу 468 шесть колонок по 70 с зазором 6
	# входят — сужение до 62 в шаге 1е было следствием колонки кнопок справа.
	_text_box = GridContainer.new()
	_text_box.columns = 6
	_text_box.add_theme_constant_override("h_separation", 6)
	_text_box.add_theme_constant_override("v_separation", 6)
	_text_box.visible = false
	for k in TEXT_KEYS:
		var tb := _button(k, Vector2(70, 56), 28)
		tb.pressed.connect(_on_text_key.bind(k))
		_text_box.add_child(tb)
	_e_box.add_child(_text_box)
	_digit_box = GridContainer.new()
	_digit_box.columns = 3
	_digit_box.add_theme_constant_override("h_separation", 8)
	_digit_box.add_theme_constant_override("v_separation", 8)
	_digit_box.visible = false
	for k in DIGIT_KEYS:
		var db := _button(k, Vector2(110, 64), 32)
		db.pressed.connect(_on_text_key.bind(k))
		_digit_box.add_child(db)
	_e_box.add_child(_digit_box)

	_choice_box = VBoxContainer.new()
	_choice_box.custom_minimum_size = Vector2(EDIT_WIDTH, 0)
	_choice_box.add_theme_constant_override("separation", 12)
	_e_box.add_child(_choice_box)

	_buttons_box = HBoxContainer.new()
	_buttons_box.position = Vector2(16, 566)
	_buttons_box.size = Vector2(360, 60)    # правее — кнопки ▲/▼
	_buttons_box.add_theme_constant_override("separation", 8)
	_buttons_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_editor.add_child(_buttons_box)


func _elabel(font: int, color: Color) -> Label:
	var l := Label.new()
	l.custom_minimum_size = Vector2(EDIT_WIDTH, 0)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	l.clip_text = false
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", font)
	l.add_theme_color_override("font_color", color)
	_e_box.add_child(l)
	return l


func _button(text: String, size: Vector2, font: int) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = size
	b.size = size
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", font)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.20, 0.23, 0.30)
	normal.set_corner_radius_all(10)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.32, 0.38, 0.52)
	var down := normal.duplicate() as StyleBoxFlat
	down.bg_color = Color(0.55, 0.45, 0.20)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", down)
	b.add_theme_stylebox_override("hover_pressed", down)
	return b


func _set_buttons(names: Array) -> void:
	# Кнопки пересобираются из обработчика нажатия одной из них («Далее»): убирать из
	# дерева посреди её же ввода нельзя — скрыть (контейнер скрытые не раскладывает)
	# и освободить отложенно.
	for c in _buttons_box.get_children():
		(c as Control).visible = false
		c.queue_free()
	var w := (_buttons_box.size.x - 8.0 * (names.size() - 1)) / maxf(1.0, names.size())
	for n in names:
		var b := _button(BUTTON_TITLES.get(n, n), Vector2(w, 60), 22)
		b.pressed.connect(func(): button.emit(n))
		_buttons_box.add_child(b)


func _build_marks(spec: Dictionary) -> void:
	for c in _marks_box.get_children():
		c.queue_free()
	var span := float(spec["max"]) - float(spec["min"])
	for m in spec.get("marks", []):
		var l := Label.new()
		l.text = str(m[1])
		l.add_theme_font_size_override("font_size", 16)
		l.add_theme_color_override("font_color", Color(0.65, 0.72, 0.85))
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var x := (float(m[0]) - float(spec["min"])) / span * 304.0
		l.size = Vector2(110, 24)
		l.position = Vector2(clampf(x - 55.0, -40.0, 304.0 - 70.0), 0)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_marks_box.add_child(l)


## Круглый ползунок: крупная цель вместо стандартной иконки 16 px.
static func _disc(d: int, color: Color) -> ImageTexture:
	var img := Image.create(d, d, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var r := d * 0.5
	for y in d:
		var dy := y + 0.5 - r
		var half := sqrt(maxf(0.0, r * r - dy * dy))
		img.fill_rect(Rect2i(int(r - half), y, int(half * 2.0), 1), color)
	return ImageTexture.create_from_image(img)


# --- обработчики ------------------------------------------------------------------------

func _changed() -> void:
	refresh()
	edit_changed.emit()


func _on_slider(v: float) -> void:
	if _syncing or edit == null:
		return
	var n := edit.changes
	edit.slider(v)
	if edit.changes != n:
		_changed()


func _on_nudge(d: int) -> void:
	if edit == null:
		return
	edit.nudge(d)
	_changed()


func _on_key(k: String) -> void:
	if edit == null:
		return
	if edit.key(k):
		_changed()
	else:
		refresh()


func _on_text_key(k: String) -> void:
	match k:
		"⌫":
			text = text.substr(0, maxi(0, text.length() - 1))
		"C":
			text = ""
		"␣":
			text += " "
		_:
			if text.length() < _max_len:
				text += k if _keep_case else k.to_lower()
	_text_changed()


## Что видно в поле: набранное или звёздочки.
func _shown() -> String:
	return "•".repeat(text.length()) if _masked else text


func _text_changed() -> void:
	_e_value.text = _shown() + "_"
	_last_key = ""
	_dirty()
	text_changed.emit(text)


func _on_choice(i: int) -> void:
	if edit == null:
		return
	edit.choose(i)
	_changed()


# --- системная клавиатура ---------------------------------------------------------------

## Системная клавиатура Quest поверх приложения: Godot поднимает Android IME
## (DisplayServer.virtual_keyboard_show → GodotEditText.showSoftInput), оболочка рисует его
## поверх сцены, если в манифесте oculus.software.overlay_keyboard (пресет
## meta_xr_features/use_overlay_keyboard). Отвергнут свой модуль на XR_META_virtual_keyboard:
## Meta объявила Virtual Keyboard устаревшим в пользу этой клавиатуры (ADR-0009).
func _keyboard_show() -> void:
	if not keyboard_dry_run and not DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		keyboard.emit("unavailable")
		return
	keyboard_requests += 1
	if not keyboard_dry_run:
		DisplayServer.virtual_keyboard_show(text, Rect2(), DisplayServer.KEYBOARD_TYPE_DEFAULT, TEXT_MAX)
	keyboard.emit("show")


func _keyboard_hide() -> void:
	if keyboard_dry_run or not DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		return
	DisplayServer.virtual_keyboard_hide()
	keyboard.emit("hide")


## IME приходит событиями клавиш (GodotTextInputWrapper.java): символ — keycode 0 и unicode,
## стирание — KEY_BACKSPACE, «Готово» клавиатуры — KEY_ENTER. В _input, а не в
## _unhandled_input: панель — не Control, фокуса у неё нет, и перехватить событие некому.
func _input(event: InputEvent) -> void:
	if falsify_no_ime or _text_mode != "system" or not interactive():
		return
	var k := event as InputEventKey
	if k == null or not k.pressed:
		return
	match k.keycode:
		KEY_BACKSPACE:
			text = text.substr(0, maxi(0, text.length() - 1))
		KEY_ENTER, KEY_KP_ENTER:
			# «Готово» системной клавиатуры только прячет её: пока она открыта, приложение без
			# фокуса ввода, и выбрать найденное можно лишь после. Сессия 7: ENTER закрывал
			# поиск кнопкой done — слово сбрасывалось, найденное пропадало.
			get_viewport().set_input_as_handled()
			var now_ms := Time.get_ticks_msec()
			if now_ms - _last_enter_ms < ENTER_REPEAT_MS:
				return
			_last_enter_ms = now_ms
			if falsify_enter_closes:
				button.emit("done")
				return
			_keyboard_hide()
			keyboard.emit("enter")
			return
		_:
			if k.unicode < 32 or text.length() >= _max_len:
				return
			var ch := String.chr(k.unicode)
			text += ch if _keep_case else ch.to_lower()
	get_viewport().set_input_as_handled()
	_text_changed()
