extends RefCounted

## Сценарий теста (просьба владельца после сессии 8): «Запуск теста» сначала ведёт по проверкам,
## которые нужны на шлеме, и сам засчитывает каждую по событиям меню; потом — задания «найдите».
##
## Сессия 9 показала два дефекта первой версии, оба исправлены здесь:
## - шаги засчитывались строго по порядку: владелец сделал шаги 2–3 раньше первого, и события
##   ушли впустую. Теперь засчитывается любой оставшийся шаг, перед лицом — список оставшихся;
## - повторное включение «Запуска теста» начинало сценарий заново и стирало пройденное. Теперь
##   start() продолжает незавершённый сценарий; заново — только после полного прохождения.
##
## Сессия 10 добавила третий: текст шага «Поиск: слово, «Готово» на клавиатуре» прочитался как
## «наберите слово Готово». Владелец так и сделал дважды, ничего не нашёл и пропустил шаг. Текст
## шага называет действие первым и кавычки-имена кнопок в начало не ставит.
##
## B — пропустить первый оставшийся шаг (в журнал «пропущен»).
## Чистая логика: события подаёт main.gd, ctx — {folder} на момент события.

## Смен активной ячейки в большой папке — «покрутил шар».
const ROTATE_ACTIVE := 15

const STEPS := [
	{"id": "labels", "text": "Много файлов: покрутите шар — читаются ли подписи"},
	{"id": "pages", "text": "Много файлов, ячейка от 4 см: «Дальше», затем «Раньше»"},
	{"id": "search", "text": "Поиск: наберите часть имени файла, спрячьте клавиатуру, выберите найденное"},
	{"id": "screenshot", "text": "Скриншот: оба стика"},
	# Добавлено после сессии 14: оба шага владелец не сделал, и по журналу нельзя было отличить
	# «не нажимал» от «не работает».
	{"id": "space_reset", "text": "Пространство: нажмите «Сброс к системным значениям»"},
	{"id": "eye_move", "text": "Высота глаз: начните замер и подвигайтесь — замер должен отказаться"},
	# Добавлено после сессии 19: гравиперчатка и перевал через край не дали в журнале ни одной
	# строки, и отличить «не пробовал» от «не работает» было нечем.
	{"id": "pull_gesture", "text": "Гравиперчатка: наведите ладонь на дальний куб, зажмите грип и дёрните кистью к себе"},
	{"id": "pull_instant", "text": "Гравиперчатка: переключите «Призыв предмета» на «сразу» и притяните куб без жеста"},
	{"id": "pull_catch", "text": "Гравиперчатка: поймайте притянутый куб — он должен остаться в руке"},
	{"id": "mantle", "text": "Стена: долезьте до верха — наверх переваливает само"},
]

var active := false
## id → «да» (засчитан) | «пропущен»
var result: Dictionary = {}
## Фальсификатор «scenarioorder»: «Раньше» засчитывается без «Дальше».
var falsify_order := false
var _count := 0
var _paged := false
var _entered := false


## Включить. Незавершённый сценарий продолжается, пройденный — начинается заново.
## Возвращает true, если начат заново.
func start() -> bool:
	active = true
	if done() or result.is_empty():
		result.clear()
		_count = 0
		_paged = false
		_entered = false
		return true
	return false


func done() -> bool:
	return result.size() >= STEPS.size()


func remaining() -> Array:
	return STEPS.filter(func(s): return not result.has(s["id"]))


## Фальсификатор «scenariolist»: перед лицом снова весь список оставшихся шагов.
var falsify_list := false


## Текст перед лицом — ОДИН текущий шаг. Сессия 20: список всех оставшихся читался как сплошной
## перечень, и было непонятно, что делать сейчас. Зачёт при этом остаётся независимым от порядка
## (урок сессии 9), показывается просто первый оставшийся.
func text() -> String:
	if not active or done():
		return ""
	var rest := remaining()
	if falsify_list:
		var lines := PackedStringArray(["Сценарий теста %d/%d" % [result.size(), STEPS.size()]])
		for s in rest:
			lines.append("• " + s["text"])
		return "\n".join(lines)
	return "Шаг %d из %d · B — пропустить\n%s" % [result.size() + 1, STEPS.size(), rest[0]["text"]]


## Название текущего шага — для сообщения «шаг пройден» и для подписи пункта меню.
func current_id() -> String:
	var rest := remaining()
	return "" if rest.is_empty() else str(rest[0]["id"])


## Подпись пункта меню: по переключателю не было видно, идёт тест или нет, и в сессии 20 владелец
## выключил его вторым нажатием — дальше ни один шаг не засчитывался.
func menu_title() -> String:
	if not active:
		return "Запуск теста"
	return "Тест: идёт (%d/%d)" % [result.size(), STEPS.size()]


## Событие меню или сессии. Возвращает id засчитанного шага или "".
func event(name: String, data: Dictionary, ctx: Dictionary) -> String:
	if not active or done():
		return ""
	var hit := ""
	if not result.has("labels") and name == "active" and ctx.get("folder", "") == "bulk":
		_count += 1
		if _count >= ROTATE_ACTIVE:
			hit = "labels"
	if hit == "" and not result.has("pages") and name == "page":
		if int(data.get("page", 0)) == 2:
			_paged = true
		elif int(data.get("page", 0)) == 1 and (_paged or falsify_order):
			hit = "pages"
	if hit == "" and not result.has("search"):
		if name == "keyboard" and data.get("state", "") == "enter":
			_entered = true
		elif _entered and (name == "select" or (name == "folder" and data.get("view", "") == "browse" and data.get("folder", "") != "")):
			hit = "search"
	if hit == "" and not result.has("screenshot") and name == "screenshot" and data.get("ok", false):
		hit = "screenshot"
	if hit == "" and not result.has("space_reset") and name == "space_reset":
		hit = "space_reset"
	# Засчитывается именно ОТКАЗ замера: он и доказывает, что окно отбрасывает движение.
	if hit == "" and not result.has("eye_move") and name == "eye_rejected":
		hit = "eye_move"
	# Гравиперчатка: способ призыва берётся из самой строки журнала («жестом» / «сразу»).
	if hit == "" and name == "pull":
		var mode := str(data.get("mode", ""))
		if mode == "gesture" and not result.has("pull_gesture"):
			hit = "pull_gesture"
		elif mode == "instant" and not result.has("pull_instant"):
			hit = "pull_instant"
	if hit == "" and not result.has("pull_catch") and name == "pull_catch":
		hit = "pull_catch"
	if hit == "" and not result.has("mantle") and name == "mantle":
		hit = "mantle"
	if hit != "":
		result[hit] = "да"
		if done():
			active = false
	return hit


## B: пропустить первый оставшийся шаг. Возвращает его id или "".
func skip() -> String:
	var rest := remaining()
	if not active or rest.is_empty():
		return ""
	var id: String = rest[0]["id"]
	result[id] = "пропущен"
	if done():
		active = false
	return id
