extends RefCounted

## Настройки шар-меню (решения владельца 2026-09-15: отдельный пункт настроек и мастер;
## шаг 1в — ползунок и ввод числа на панели вместо ступеней стиком).
##
## Один список описаний — источник и для папки «Настройки → Шар-меню», и для шагов
## мастера, и для сохранения (PRACTICES §1.8: три перечня разошлись бы).
##
## Два вида:
##   choice — варианты с подписями (кнопки на панели);
##   number — непрерывное значение: min, max, округление, единица и «человеческие»
##            метки над шкалой (marks), чтобы число читалось как смысл.
## Ступени шага 1б сняты: стик неточен на шкале (сессия 2026-09-15), шесть ступеней
## не давали выставить промежуточное значение.
##
## Ни одно число здесь не бюджет и не измерение — это пределы для выбора человеком.

const Goldberg := preload("res://menu/goldberg.gd")

const PATH := "user://sphere_settings.cfg"

## Предел угла ячейки линзы, рад: крупнее — ячейка захватывает полшара, и
## равноугольная проекция линзы теряет смысл «неискажённой середины».
const LENS_ALPHA_MAX := 0.5

const SPEC := {
	"surface": {"title": "Поверхность", "kind": "choice", "default": "globe",
		"options": [["globe", "глобус"], ["lens", "линза"], ["globe_hex", "глобус без пятиугольников"],
			["octa", "октаэдр"], ["rings", "кольца"], ["fib", "спираль"]],
		"hint": "Глобус — пункты прибиты к шару, 12 пятиугольников. Линза — середина всегда напротив лица. Без пятиугольников — они пустые. Октаэдр — 6 квадратов, крупные ячейки. Кольца — ряды по широтам. Спираль — любой размер, неровности рассеяны."},
	"hand_rotation": {"title": "Вращение рукой", "kind": "choice", "default": "ball",
		"options": [["ball", "как шар"], ["stand", "как глобус на подставке"], ["face", "лицом к шлему"]],
		"hint": "Как шар — поворот кисти вращает шар. На подставке — только поворот вокруг вертикали. Лицом к шлему — рука шар не вращает, активная всегда напротив."},
	"radius_cm": {"title": "Радиус шара", "kind": "number", "default": 11.0, "min": 6.0, "max": 20.0,
		"round": 0.5, "unit": "см", "marks": [[7.0, "маленький"], [11.0, "средний"], [18.0, "большой"]],
		"hint": "Размер шара в руке."},
	"cell_cm": {"title": "Размер ячейки", "kind": "number", "default": 2.5, "min": 1.5, "max": 15.0,
		"round": 0.1, "unit": "см", "marks": [[2.0, "мелкие"], [5.0, "крупные"], [13.0, "~7 на виду"]],
		"hint": "Сколько пунктов видно сразу и насколько они крупные. У глобуса размер округляется до ближайшей сетки."},
	"stick_speed": {"title": "Скорость стика", "kind": "number", "default": 2.5, "min": 0.5, "max": 6.0,
		"round": 0.1, "unit": "рад/с", "marks": [[1.0, "медленно"], [2.5, "средне"], [5.0, "быстро"]],
		"hint": "Вращение левым стиком, одинаковое по горизонтали и вертикали."},
	"detent": {"title": "Доводка к ячейке", "kind": "number", "default": 14.0, "min": 0.0, "max": 25.0,
		"round": 1.0, "unit": "", "marks": [[0.0, "нет"], [8.0, "мягкая"], [20.0, "жёсткая"]],
		"hint": "Как быстро шар сам ставит ближайшую ячейку в центр, когда его отпустили. 0 — не ставит."},
	"hold_ms": {"title": "Время удержания", "kind": "number", "default": 500.0, "min": 200.0, "max": 1200.0,
		"round": 10.0, "unit": "мс", "marks": [[300.0, "быстро"], [500.0, "средне"], [900.0, "долго"]],
		"hint": "Удержание курка открывает действия объекта."},
	"panel_side": {"title": "Сторона панели", "kind": "choice", "default": "top",
		"options": [["top", "над шаром"], ["left_top", "слева-сверху"], ["right", "справа"]],
		"hint": "Где висит панель информации об активном объекте."},
	"haptics": {"title": "Вибро", "kind": "choice", "default": true,
		"options": [[true, "вкл"], [false, "выкл"]],
		"hint": "Тик при касании шара и смене активной ячейки."},
	"grab_friction": {"title": "Инерция захвата", "kind": "number", "default": 4.0, "min": 1.0, "max": 15.0,
		"round": 0.5, "unit": "", "marks": [[1.5, "долгая"], [4.0, "средняя"], [12.0, "короткая"]],
		"hint": "Отпустили шар на ходу — сколько он докручивается. Меньше число — дольше крутится."},
	"hysteresis": {"title": "Липкость активной", "kind": "number", "default": 0.15, "min": 0.0, "max": 0.5,
		"round": 0.01, "unit": "", "marks": [[0.05, "слабая"], [0.2, "средняя"], [0.4, "сильная"]],
		"hint": "Насколько надо довернуть за границу ячейки, чтобы активной стала соседняя: у границы активная не мигает."},
	"return_gesture": {"title": "Жест возврата", "kind": "choice", "default": "both",
		"options": [["off", "выкл"], ["shake", "встряхивание"], ["swipe", "взмах влево"], ["both", "оба"]],
		"hint": "Как вернуться на верхний уровень, не закрывая шар: тряхнуть им туда-обратно или резко махнуть рукой влево."},
	"gesture_cm": {"title": "Размах жеста", "kind": "number", "default": 6.0, "min": 3.0, "max": 15.0,
		"round": 0.5, "unit": "см", "marks": [[4.0, "короткий"], [6.0, "средний"], [12.0, "широкий"]],
		"hint": "Насколько размашисто делать жест. Взмах влево требует втрое большего хода, чем встряхивание."},
	"hand_smoothing": {"title": "Сглаживание руки", "kind": "number", "default": 0.5, "min": 0.0, "max": 1.0,
		"round": 0.05, "unit": "", "marks": [[0.0, "нет"], [0.5, "среднее"], [1.0, "сильное"]],
		"hint": "Гасит дрожь и рывки кисти. 0 — шар повторяет руку в точности."},
}
## Основные — шаги мастера по порядку (решение владельца 2026-09-15: доводка с
## демонстрацией в мастере).
const MAIN := ["surface", "hand_rotation", "radius_cm", "cell_cm", "stick_speed", "detent",
		"hold_ms", "panel_side", "haptics"]
## «Дополнительно» — в настройках, не в мастере: владелец не понял, что они делают;
## у каждой — демонстрация.
const ADVANCED := ["grab_friction", "hysteresis", "return_gesture", "gesture_cm", "hand_smoothing"]
const ORDER := MAIN + ADVANCED
## Поверхность → семейство сетки (menu/goldberg.gd). Линзы нет: у неё своя решётка.
const FAMILY := {"globe": "icosa", "globe_hex": "icosa", "octa": "octa", "rings": "rings", "fib": "fib"}

var values: Dictionary = {}


func _init() -> void:
	reset()


func reset() -> void:
	for id in ORDER:
		values[id] = SPEC[id]["default"]


func get_value(id: String) -> Variant:
	return values[id]


static func is_number(id: String) -> bool:
	return SPEC[id]["kind"] == "number"


## Округление и пределы; для выбора — только значения из вариантов.
## Возвращает [значение, было ли ограничено].
static func normalize(id: String, v: Variant) -> Array:
	var spec: Dictionary = SPEC[id]
	if spec["kind"] == "choice":
		for o in spec["options"]:
			if typeof(o[0]) == typeof(v) and o[0] == v:
				return [v, false]
		return [spec["default"], true]
	var rnd := float(spec["round"])
	var r := _snap(id, float(v))
	var c := _snap(id, clampf(r, float(spec["min"]), float(spec["max"])))
	return [c, not is_equal_approx(c, r)]


## Округление через десятичную строку: snappedf(0.35, 0.05) = 0.35000000000000003, и
## значение после загрузки не совпадало с сохранённым (проверка «настройки»).
static func _snap(id: String, x: float) -> float:
	return String.num(snappedf(x, float(SPEC[id]["round"])), _decimals(id)).to_float()


static func _decimals(id: String) -> int:
	var rnd := float(SPEC[id]["round"])
	var decimals := 0
	while decimals < 4 and not is_equal_approx(snappedf(rnd, pow(10.0, -decimals)), rnd):
		decimals += 1
	return decimals


## Установить с нормализацией. Возвращает true, если значение пришлось ограничить.
func set_value(id: String, v: Variant) -> bool:
	var n := normalize(id, v)
	values[id] = n[0]
	return n[1]


## Ступень вперёд/назад: у чисел — 1/20 шкалы (не мельче округления), у выбора —
## следующий вариант с упором в край (край ощущается как край).
func step(id: String, delta: int) -> Variant:
	var spec: Dictionary = SPEC[id]
	if spec["kind"] == "number":
		set_value(id, float(values[id]) + nudge(id) * delta)
		return values[id]
	var opts: Array = spec["options"]
	values[id] = opts[clampi(option_index(id) + delta, 0, opts.size() - 1)][0]
	return values[id]


static func nudge(id: String) -> float:
	var spec: Dictionary = SPEC[id]
	var rnd := float(spec["round"])
	return maxf(rnd, snappedf((float(spec["max"]) - float(spec["min"])) / 20.0, rnd))


func option_index(id: String) -> int:
	var opts: Array = SPEC[id]["options"]
	for i in opts.size():
		if typeof(opts[i][0]) == typeof(values[id]) and opts[i][0] == values[id]:
			return i
	return 0


## Число для подписи: знаков после запятой — как у округления, запятая — десятичный знак.
static func format_number(id: String, x: float) -> String:
	return String.num(x, _decimals(id)).replace(".", ",")


## Ближайшая «человеческая» метка шкалы.
static func mark_of(id: String, x: float) -> String:
	var best := ""
	var best_d := INF
	for m in SPEC[id].get("marks", []):
		var d := absf(float(m[0]) - x)
		if d < best_d:
			best_d = d
			best = m[1]
	return best


func label(id: String) -> String:
	var spec: Dictionary = SPEC[id]
	if spec["kind"] == "choice":
		return spec["options"][option_index(id)][1]
	var x := float(values[id])
	var s := ("%s %s" % [format_number(id, x), spec["unit"]]).strip_edges()
	var m := mark_of(id, x)
	return "%s — %s" % [s, m] if m != "" else s


func save(path: String = PATH) -> Error:
	var cf := ConfigFile.new()
	for id in ORDER:
		cf.set_value("sphere", id, values[id])
	return cf.save(path)


## Загрузка с проверкой: число вне пределов или не числом, вариант не из списка —
## берётся умолчание, а не мусор. Возвращает список отвергнутых ключей.
func load_from(path: String = PATH) -> Array[String]:
	var rejected: Array[String] = []
	var cf := ConfigFile.new()
	if cf.load(path) != OK:
		return rejected
	for id in ORDER:
		if not cf.has_section_key("sphere", id):
			continue
		var v: Variant = cf.get_value("sphere", id)
		if is_number(id):
			if typeof(v) in [TYPE_INT, TYPE_FLOAT] and float(v) >= float(SPEC[id]["min"]) \
					and float(v) <= float(SPEC[id]["max"]):
				set_value(id, v)
			else:
				rejected.append(id)
		elif normalize(id, v)[1]:
			rejected.append(id)
		else:
			values[id] = v
	return rejected


static func exists(path: String = PATH) -> bool:
	return FileAccess.file_exists(path)


## Угловой радиус ячейки линзы (центр → вершина) из размера ячейки и радиуса шара.
## Размер ячейки — поперечник (вершина — вершина), значит радиус ячейки — половина.
func lens_alpha() -> float:
	return minf((float(values["cell_cm"]) * 0.5) / float(values["radius_cm"]), LENS_ALPHA_MAX)


func is_lens() -> bool:
	return values["surface"] == "lens"


## Семейство сетки текущей поверхности; у линзы — икосаэдр (для подписи уровня в журнале).
func family() -> String:
	return FAMILY.get(values["surface"], "icosa")


## Уровень сетки своего семейства (menu/geo/index.json, от крупных к мелким), дающий ячейку,
## ближайшую к заданному размеру. Перебор по загруженным сеткам точен и дёшев (кэш на классе).
static var _angle_cache: Dictionary = {}


func globe_frequency() -> int:
	var want_cm := float(values["cell_cm"])
	var r := float(values["radius_cm"])
	var fam := family()
	var best := 0
	var best_err := INF
	for m in Goldberg.level_count(fam):
		# ошибка в логарифме: ряд размеров почти геометрический, в сантиметрах
		# крупные ступени перетягивали бы выбор
		var err := absf(log(globe_cell_cm(m, r, fam) / want_cm))
		if err < best_err:
			best_err = err
			best = m
	return best


## Фактический поперечник ячейки текущей поверхности, см. У линзы — заданный с
## пределом угла, у глобуса — ближайший достижимый: сетки идут рядом, и при большом
## радиусе мелкие ячейки упираются в потолок (642 ячейки).
func actual_cell_cm() -> float:
	if is_lens():
		return lens_alpha() * 2.0 * float(values["radius_cm"])
	return globe_cell_cm(globe_frequency(), float(values["radius_cm"]), family())


## Поперечник ячейки глобуса уровня m на шаре радиуса r, см: угловой радиус
## по вписанной окружности × 2/√3 до вершины × 2 на поперечник.
static func globe_cell_cm(m: int, r_cm: float, fam: String = "icosa") -> float:
	var key := "%s:%d" % [fam, m]
	if not _angle_cache.has(key):
		_angle_cache[key] = Goldberg.build(m, fam).cell_angle()
	return r_cm * float(_angle_cache[key]) * (2.0 / sqrt(3.0)) * 2.0
