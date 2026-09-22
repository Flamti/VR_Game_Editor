extends RefCounted

## Слои объектов: кому объект показывается (решение владельца 2026-09-21).
##
## У объекта **ровно один** слой — «игра», «редактор» или «отладка». Это не то же самое, что
## `tags`: теги говорят, что объект умеет (climb, grab, teleport_target), слой — кому его видно.
##
## Прячется слой **маской камеры** (`VisualInstance3D.layers` + `Camera3D.cull_mask`), а не
## `visible`: узлы остаются в сцене нетронутыми, физика и триггеры работают, а отсечение идёт **до**
## формирования вызовов отрисовки — скрытый слой не стоит ничего (цена вызова измерена: 4.04 мкс,
## паспорт). Скрытая зона триггера продолжает грузить интерьер — ровно этого владелец и хотел.
##
## Бит «игра» совпадает с умолчанием Godot намеренно: ни один неразмеченный узел — меню, руки,
## панели, виньетка — не может случайно пропасть. Плата: переключателя «слой игры» нет, он погасил
## бы и меню тоже; он появится, когда интерфейс переедет на свой бит из резерва.

## Имена слоёв в данных уровня. Порядок задаёт номера битов.
const NAMES := ["game", "editor", "debug"]
## Слой по умолчанию: поля нет — объект принадлежит игре.
const DEFAULT := "game"

## Фальсификатор «layerany»: неизвестное имя слоя молча становится «game» вместо отказа разбора.
static var falsify_any := false


## Бит слоя: game = 1, editor = 2, debug = 4. Неизвестное имя — бит игры (но `check` такого не
## пропустит, и до сюда оно не дойдёт).
static func bit(layer: String) -> int:
	var i := NAMES.find(layer)
	return 1 << (0 if i < 0 else i)


## Маска камеры из того, какие слои показаны. Бит игры включён всегда: на нём живёт всё, что не
## размечено, и погасив его, человек ослеп бы вместе с меню.
static func mask(shown: Dictionary) -> int:
	var m := bit("game")
	for name in NAMES:
		if name != "game" and bool(shown.get(name, false)):
			m |= bit(name)
	return m


## Маска режима игры: только то, что видит игрок.
static func play_mask() -> int:
	return bit("game")


## Слой объекта из данных уровня.
static func of(obj: Dictionary) -> String:
	var name := str(obj.get("layer", DEFAULT))
	return name if name in NAMES else DEFAULT


## Проверка поля при разборе уровня: "" — годится, иначе текст отказа.
## Неизвестное имя — именно отказ, а не тихая подмена: объект, уехавший не на тот слой, исчезает
## из виду без единого сообщения, и искать это потом негде.
static func check(obj: Dictionary) -> String:
	if not obj.has("layer") or falsify_any:
		return ""
	var name := str(obj["layer"])
	if name in NAMES:
		return ""
	return "неизвестный слой «%s» у объекта «%s» (есть: %s)" % [name, str(obj.get("uuid", "")),
			", ".join(NAMES)]


## Проставить бит слоя всем видимым потомкам узла. Возвращает, скольким проставили.
##
## Трогаются только `GeometryInstance3D`: у `Light3D` поле `layers` значит совсем другое (какие
## объекты этот свет освещает), и снимать там биты — молча погасить освещение половины сцены.
static func apply(node: Node, bits: int) -> int:
	var n := 0
	if node is Light3D:
		return 0
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).layers = bits
		n += 1
	for child in node.get_children():
		n += apply(child, bits)
	return n
