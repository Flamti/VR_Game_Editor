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
	"stick_speed": {"title": "Скорость стика", "kind": "number", "inputs": ["controllers"], "default": 2.5, "min": 0.5, "max": 6.0,
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
	"haptics": {"title": "Вибро", "kind": "choice", "default": true, "inputs": ["controllers"],
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
	# Сессия 7: обе клавиатуры сразу мешали. Системная перекрывает шар и забирает ввод, пока
	# открыта (журнал: session_visible до скрытия) — выбирать найденное после «Готово».
	"search_keyboard": {"title": "Клавиатура поиска", "kind": "choice", "default": "system",
		"options": [["system", "системная Quest"], ["panel", "на панели"]],
		"hint": "Системная — привычная клавиатура Quest; пока она открыта, шар закрыт ею и не отвечает: нажмите на ней «Готово» и выбирайте найденное. На панели — раскладка лучом, шар остаётся доступен."},
	# Шаг 1к. Выбор живёт до перезапуска («session»): выбранные руки при выключенном в системе
	# отслеживании рук заперли бы приложение — вернуть настройку было бы нечем, ни сейчас, ни
	# после перезапуска. Выход через системное меню Quest возвращает «авто».
	"input_source": {"title": "Источник ввода", "kind": "choice", "default": "auto", "scope": "session",
		"options": [["auto", "авто"], ["controllers", "контроллеры"], ["hands", "руки"]],
		"hint": "Авто — ведут контроллеры, пока они в руках; отложили — ведут руки. Выбор источника действует до перезапуска: если руки не отвечают, перезапустите приложение."},
	# Пространство и свет (этап Ф3). Область — «user»: от способа ввода они не зависят, значит общие
	# для пользователя и лежат в settings_common.cfg.
	"space_light": {"title": "Освещение", "kind": "choice", "default": "studio", "scope": "user",
		"options": [["studio", "студия"], ["dim", "приглушённое"], ["bright", "яркое"]],
		"hint": "Свет сцены. Без него не видно кнопок на моделях контроллеров (сессия 13). Фон от света не зависит: на ярком свете сетка не должна выцветать (сессия 14)."},
	"space_glow": {"title": "Свечение", "kind": "choice", "default": false, "scope": "user",
		"options": [[true, "вкл"], [false, "выкл"]],
		"hint": "Свечение ярких мест и сетки. На мобильном рендере стоит заполнения экрана — включать, глядя на кадр."},
	# Умолчание «на месте»: сетка — инструмент редактора и за человеком не ходит (сессия 17).
	"grid_mode": {"title": "Сетка пола", "kind": "choice", "default": "fixed", "scope": "user",
		"options": [["off", "выкл"], ["fixed", "на месте"], ["around", "вокруг меня"], ["scene", "вся сцена"]],
		"hint": "Сетка на уровне настоящего пола. «На месте» — стоит на нуле уровня; «вокруг меня» — круг видимости едет за вами."},
	"grid_origin": {"title": "Сетка в начале координат", "kind": "choice", "default": false, "scope": "user",
		"options": [[true, "вкл"], [false, "выкл"]],
		"hint": "Вторая сетка, привязанная к началу координат мира, а не к вам."},
	"grid_cell_cm": {"title": "Ячейка сетки", "kind": "number", "default": 50.0, "min": 10.0, "max": 200.0,
		"round": 5.0, "unit": "см", "scope": "user", "marks": [[25.0, "мелкая"], [50.0, "средняя"], [100.0, "крупная"]],
		"hint": "Сторона клетки."},
	"grid_radius_m": {"title": "Радиус сетки", "kind": "number", "default": 6.0, "min": 1.0, "max": 20.0,
		"round": 0.5, "unit": "м", "scope": "user", "marks": [[3.0, "близко"], [6.0, "средне"], [15.0, "далеко"]],
		"hint": "Докуда видна сетка вокруг вас; к краю она растворяется."},
	"grid_thickness_mm": {"title": "Толщина линий", "kind": "number", "default": 4.0, "min": 1.0, "max": 20.0,
		"round": 1.0, "unit": "мм", "scope": "user", "marks": [[2.0, "тонкие"], [6.0, "средние"], [14.0, "жирные"]],
		"hint": "Ширина линии сетки на полу."},
	"grid_alpha": {"title": "Прозрачность сетки", "kind": "number", "default": 0.35, "min": 0.05, "max": 1.0,
		"round": 0.05, "unit": "", "scope": "user", "marks": [[0.15, "едва"], [0.35, "средне"], [0.8, "ярко"]],
		"hint": "0 — не видно, 1 — плотная линия."},
	"grid_color": {"title": "Цвет сетки", "kind": "choice", "default": "cyan", "scope": "user",
		"options": [["cyan", "бирюзовый"], ["white", "белый"], ["green", "зелёный"], ["orange", "оранжевый"]],
		"hint": "Цвет линий."},
	"grid_glow": {"title": "Свечение сетки", "kind": "choice", "default": false, "scope": "user",
		"options": [[true, "вкл"], [false, "выкл"]],
		"hint": "Сетка — инструмент редактора: её яркость задаётся здесь и не зависит от свечения и атмосферы сцены."},
	# Перемещение (ADR-0013). Область «input»: у рук и контроллеров свои способы и скорости.
	# Умолчания — мигание и поворот щелчком: так советует руководство Meta по комфорту.
	"move_mode": {"title": "Способ перемещения", "kind": "choice", "default": "blink",
		"options": [["blink", "телепорт с миганием"], ["shift", "телепорт рывком"],
			["head", "непрерывно по взгляду"], ["hand", "непрерывно по руке"]],
		"hint": "Телепорт с миганием — перенос с коротким затемнением (мягче всего). Телепорт рывком — быстрый перелёт. Непрерывно — стик; направление берётся от головы или от руки."},
	"move_speed": {"title": "Скорость ходьбы", "kind": "number", "default": 1.4, "min": 0.5, "max": 3.0,
		"round": 0.1, "unit": "м/с", "marks": [[1.0, "медленно"], [1.4, "как пешком"], [2.5, "быстро"]],
		"hint": "Скорость непрерывного движения. 1,4 м/с — скорость обычной ходьбы (руководство Meta)."},
	"teleport_range": {"title": "Дальность телепорта", "kind": "number", "default": 8.0, "min": 2.0, "max": 20.0,
		"round": 0.5, "unit": "м", "marks": [[4.0, "близко"], [8.0, "средне"], [16.0, "далеко"]],
		"hint": "Докуда дотягивается дуга телепорта."},
	"turn_mode": {"title": "Поворот", "kind": "choice", "default": "snap",
		"options": [["snap", "щелчком"], ["smooth", "плавный"]],
		"hint": "Щелчком — мгновенный поворот на угол; плавный укачивает сильнее и включается по желанию."},
	"snap_angle": {"title": "Угол щелчка", "kind": "number", "default": 45.0, "min": 15.0, "max": 90.0,
		"round": 15.0, "unit": "°", "marks": [[15.0, "мелко"], [45.0, "средне"], [90.0, "четверть"]],
		"hint": "Кратность поворота щелчком."},
	"turn_speed": {"title": "Скорость плавного поворота", "kind": "number", "default": 90.0, "min": 30.0, "max": 180.0,
		"round": 10.0, "unit": "°/с", "marks": [[45.0, "медленно"], [90.0, "средне"], [150.0, "быстро"]],
		"hint": "Насколько быстро крутит плавный поворот."},
	# Какая рука ведёт (просьба владельца, сессия 17). Телепорт и непрерывное движение — один слот:
	# какой из них работает, решает move_mode, поэтому настройки две, а не три.
	"move_hand": {"title": "Рука движения", "kind": "choice", "default": "left",
		"options": [["left", "левая"], ["right", "правая"], ["both", "обе"]],
		"hint": "Каким стиком идти и целиться телепортом. «Обе» — вперёд-назад ведёт любой стик."},
	"turn_hand": {"title": "Рука поворота", "kind": "choice", "default": "right",
		"options": [["left", "левая"], ["right", "правая"], ["both", "обе"]],
		"hint": "Каким стиком поворачиваться. Если обе настройки стоят «обе», влево-вправо крутит, вперёд-назад ведёт."},
	# Призыв предмета (сессия 17, референс HL:A). Оба способа — решение владельца: что удобнее,
	# покажет шлем, а не рассуждение.
	"pull_mode": {"title": "Призыв предмета", "kind": "choice", "default": "gesture",
		"options": [["gesture", "жестом"], ["instant", "сразу"], ["off", "выкл"]],
		"hint": "Дотянуться до предмета издали: навести ладонь, зажать грип и дёрнуть кистью к себе. «Сразу» — без жеста, по нажатию."},
	"teleport_turn": {"title": "Курс при телепорте", "kind": "choice", "default": true,
		"options": [[true, "вкл"], [false, "выкл"]],
		"hint": "Пока целитесь дугой, стик вбок задаёт, куда смотреть после переноса (как в Half-Life: Alyx)."},
	"crouch_m": {"title": "Присесть кнопкой", "kind": "number", "default": 0.5, "min": 0.0, "max": 0.9,
		"round": 0.1, "unit": "м", "marks": [[0.0, "выкл"], [0.5, "полприседа"], [0.9, "на корточки"]],
		"hint": "Насколько опускает взгляд кнопка A: заглянуть под объект, не приседая физически. 0 — выключено."},
	# Слои объектов (ADR о слоях, 2026-09-21). Область «user»: от способа ввода не зависят.
	# Слоя «игра» среди переключателей нет намеренно: на нём живёт всё неразмеченное — меню, руки,
	# панели, — и погасив его, человек ослеп бы вместе с интерфейсом.
	"layer_editor": {"title": "Слой редактора", "kind": "choice", "default": true, "scope": "user",
		"options": [[true, "показывать"], [false, "скрыть"]],
		"hint": "Инструментарий автора: сетка пола и служебные объекты уровня."},
	"layer_debug": {"title": "Слой отладки", "kind": "choice", "default": false, "scope": "user",
		"options": [[true, "показывать"], [false, "скрыть"]],
		"hint": "Зоны триггеров и прочая отладочная графика. Скрытая зона продолжает работать: маска камеры отсекает отрисовку, а не физику."},
	"move_vignette": {"title": "Виньетка", "kind": "choice", "default": "light",
		"options": [["off", "выкл"], ["light", "лёгкая"], ["strong", "сильная"], ["accel", "по ускорению"]],
		"hint": "Затемнение краёв при движении и плавном повороте — первое средство от укачивания (руководство Meta). «По ускорению» темнеет только на разгоне и торможении, на ровном ходу не мешает."},
	"grid_xray": {"title": "Сетка сквозь объекты", "kind": "choice", "default": false, "scope": "user",
		"options": [[true, "вкл"], [false, "выкл"]],
		"hint": "«Рентген»: сетка видна поверх всего, даже за платформами. Помогает судить о совпадении с полом."},
}
## Основные — шаги мастера по порядку (решение владельца 2026-09-15: доводка с
## демонстрацией в мастере).
const MAIN := ["surface", "hand_rotation", "radius_cm", "cell_cm", "stick_speed", "detent",
		"hold_ms", "panel_side", "haptics"]
## «Дополнительно» — в настройках, не в мастере: владелец не понял, что они делают;
## у каждой — демонстрация.
const ADVANCED := ["grab_friction", "hysteresis", "return_gesture", "gesture_cm", "hand_smoothing",
		"search_keyboard", "input_source"]
## «Пространство» — свет, сетка пола; общие для пользователя (scope «user»).
const SPACE := ["space_light", "space_glow", "grid_mode", "grid_origin", "grid_cell_cm", "grid_radius_m",
		"grid_thickness_mm", "grid_alpha", "grid_color", "grid_glow", "grid_xray"]
## «Перемещение» — способы, скорость, повороты, комфорт (ADR-0013).
const MOVE := ["move_mode", "move_hand", "move_speed", "teleport_range", "teleport_turn",
		"turn_mode", "turn_hand", "snap_angle", "turn_speed", "crouch_m", "pull_mode", "move_vignette"]
## Слои объектов: что кому показывается.
const LAYERS := ["layer_editor", "layer_debug"]
const ORDER := MAIN + ADVANCED + SPACE + MOVE + LAYERS
## Цвета сетки пола: имя настройки → цвет.
const GRID_COLORS := {"cyan": Color(0.35, 0.85, 0.95), "white": Color(0.9, 0.92, 0.95),
		"green": Color(0.45, 0.9, 0.5), "orange": Color(0.95, 0.65, 0.3)}
## Поверхность → семейство сетки (menu/goldberg.gd). Линзы нет: у неё своя решётка.
const FAMILY := {"globe": "icosa", "globe_hex": "icosa", "octa": "octa", "rings": "rings", "fib": "fib"}

## Области действия (ADR-0010): "input" — своя у каждого способа ввода (умолчание; решение
## владельца 2026-09-19 — сейчас такие ВСЕ настройки меню), "user" — общая для пользователя,
## "session" — живёт до перезапуска. Поле "inputs" в SPEC — к каким способам ввода настройка
## относится вообще (у рук нет стика и вибро); без поля — ко всем.
const SCOPES := ["input", "user", "session"]
const INPUTS := ["controllers", "hands"]

var values: Dictionary = {}
## Файл настроек активного способа ввода и файл общих настроек пользователя. Пустой common_path —
## всё в одном файле (так было до профилей, так пишут проверки).
var path := PATH
var common_path := ""
## Способ ввода, чьи это значения (profile/input_settings.gd): по нему прячутся чужие настройки.
var input := "controllers"
## Переопределение области: id → scope. Механизм общих настроек проверяется, пока ни одна настройка
## не общая.
var scope_override: Dictionary = {}
## Фальсификатор «sessionsave»: настройка сессии пишется в файл и читается из него, как постоянная.
var falsify_save_session := false


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


## Сохранить: настройки способа ввода — в p (по умолчанию path), общие — в common_path, если он
## задан; иначе всё в p.
func save(p: String = "") -> Error:
	var target := p if p != "" else path
	var cf := ConfigFile.new()
	var common := ConfigFile.new()
	for id in ORDER:
		if is_session(id) and not falsify_save_session:
			continue
		if common_path != "" and scope(id) == "user":
			common.set_value("sphere", id, values[id])
		else:
			cf.set_value("sphere", id, values[id])
	if common_path != "":
		var err_common := common.save(common_path)
		if err_common != OK:
			return err_common
	return cf.save(target)


## Настройка только на время сессии: не сохраняется и не загружается.
static func is_session(id: String) -> bool:
	return SPEC[id].get("scope", "input") == "session"


## Область действия с учётом переопределения.
func scope(id: String) -> String:
	return scope_override.get(id, SPEC[id].get("scope", "input"))


## Относится ли настройка к способу ввода этих значений.
func applies(id: String) -> bool:
	return input in SPEC[id].get("inputs", INPUTS)


## Загрузка с проверкой: число вне пределов или не числом, вариант не из списка —
## берётся умолчание, а не мусор. Возвращает список отвергнутых ключей.
func load_from(p: String = "") -> Array[String]:
	var rejected: Array[String] = []
	_load_file(p if p != "" else path, rejected, false)
	if common_path != "":
		_load_file(common_path, rejected, true)
	return rejected


## only_common — из файла берутся только общие настройки (файл общих поверх файла ввода).
func _load_file(p: String, rejected: Array[String], only_common: bool) -> void:
	var cf := ConfigFile.new()
	if cf.load(p) != OK:
		return
	for id in ORDER:
		if only_common and scope(id) != "user":
			continue
		# Файл, записанный до того, как настройка стала сессионной, её тоже не навязывает.
		if not cf.has_section_key("sphere", id) or (is_session(id) and not falsify_save_session):
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


static func exists(p: String = PATH) -> bool:
	return FileAccess.file_exists(p)


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
