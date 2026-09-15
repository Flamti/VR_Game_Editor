extends RefCounted

## Источник содержимого (слой 1, docs/design/sphere-menu.md §1).
##
## Контракт: дети папки постранично. Каталог ассетов бывает большим, поэтому
## страница, а не весь список; прототип отдаёт синхронно, но вызывающий код
## обязан уметь просить страницы — иначе переход на асинхронный источник
## потребует переписать меню.

## Корень — пустой id.
const ROOT := ""


## Число детей папки.
func count(_folder_id: String) -> int:
	return 0


## Дети папки [offset, offset + limit).
func children(_folder_id: String, _offset: int, _limit: int) -> Array:
	return []


## Имя папки для плашки; корень — имя всего меню.
func folder_title(_folder_id: String) -> String:
	return ""
