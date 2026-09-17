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
## B — пропустить первый оставшийся шаг (в журнал «пропущен»).
## Чистая логика: события подаёт main.gd, ctx — {folder} на момент события.

## Смен активной ячейки в большой папке — «покрутил шар».
const ROTATE_ACTIVE := 15

const STEPS := [
	{"id": "labels", "text": "Много файлов: покрутите шар — читаются ли подписи"},
	{"id": "pages", "text": "Много файлов, ячейка от 4 см: «Дальше», затем «Раньше»"},
	{"id": "search", "text": "Поиск: слово, «Готово» на клавиатуре, выбрать найденное"},
	{"id": "screenshot", "text": "Скриншот: оба стика"},
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


## Текст перед лицом: сколько пройдено и оставшиеся шаги, по строке на шаг.
func text() -> String:
	if not active or done():
		return ""
	var lines := PackedStringArray(["Сценарий теста %d/%d · B — пропустить первый" % [result.size(), STEPS.size()]])
	for s in remaining():
		lines.append("• " + s["text"])
	return "\n".join(lines)


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
