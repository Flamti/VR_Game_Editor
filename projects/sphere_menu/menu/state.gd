extends RefCounted

## Состояние меню (слой 2, docs/design/sphere-menu.md §2): стек папок, память
## прокрутки на каждую папку, режим «открыто/закрыто».
##
## Прокрутка — непрозрачное значение: у глобуса поворот, у линзы сдвиг и закрутка.
## Состояние хранит, но не толкует.
##
## С 2026-09-15 выбор, действия и их политики — в menu/navigator.gd; подтверждение
## повторным выбором снято (решение владельца — удержание курка).

const ROOT := ""

enum Mode { CLOSED, COMPACT }

var mode: Mode = Mode.CLOSED
var stack: Array[String] = [ROOT]
var _scroll: Dictionary = {}


func folder() -> String:
	return stack[stack.size() - 1]


func depth() -> int:
	return stack.size() - 1


func toggle() -> void:
	mode = Mode.COMPACT if mode == Mode.CLOSED else Mode.CLOSED


func close() -> void:
	mode = Mode.CLOSED


## Вход в папку. Возвращает сохранённую прокрутку папки или null.
func enter(folder_id: String, current_scroll: Variant) -> Variant:
	_scroll[folder()] = current_scroll
	stack.append(folder_id)
	return _scroll.get(folder_id, null)


## Назад. На корне — закрыть меню и вернуть {"closed": true}.
func back(current_scroll: Variant) -> Dictionary:
	if stack.size() <= 1:
		mode = Mode.CLOSED
		return {"closed": true, "scroll": null}
	_scroll[folder()] = current_scroll
	stack.pop_back()
	return {"closed": false, "scroll": _scroll.get(folder(), null)}


## Переход на уровень depth (0 — корень) — «Путь…». Прокрутка того уровня.
func jump(depth_index: int, current_scroll: Variant) -> Variant:
	_scroll[folder()] = current_scroll
	while stack.size() - 1 > maxi(depth_index, 0):
		stack.pop_back()
	return _scroll.get(folder(), null)


## Папка исчезла (удалена или перемещена) — выйти к ближайшему существующему предку.
func prune(exists: Callable) -> void:
	while stack.size() > 1 and not exists.call(folder()):
		stack.pop_back()
