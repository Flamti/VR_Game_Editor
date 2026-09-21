extends RefCounted

## Подгрузка и выгрузка частей уровня по триггерам (этап Ф3, сессия 17).
##
## Сессия 17: интерьер помещения подгружался при входе и **не выгружался никогда** — `body_exited` не
## был подключён нигде в проекте. Дальше таких зон станет много, и уровень будет только расти.
##
## Выгрузка отложенная: человек, шагнувший через проём туда-обратно, иначе получал бы мигание
## загрузки. Пока идёт отсчёт, возвращение его отменяет.
##
## Здесь только учёт: какие файлы загружены, чьи узлы, кому пора уходить. Сами узлы строит
## `world/level_loader.gd`, а удаляет вызывающий — так учёт проверяется настольно, без сцены.

## Сколько ждать после выхода из зоны, прежде чем выгружать, с. Не измерение, а форма поведения:
## меньше секунды — мигание на пороге, больше трёх — память держится зря.
const UNLOAD_DELAY_S := 2.0

## Фальсификатор «keeploaded»: выход из зоны не начинает отсчёт — интерьер остаётся навсегда
## (поведение сессии 17).
var falsify_never_unload := false

## файл → узлы, которые он построил
var loaded: Dictionary = {}
## файл → сколько секунд осталось до выгрузки
var _timers: Dictionary = {}


func is_loaded(file: String) -> bool:
	return loaded.has(file)


func add(file: String, nodes: Array) -> void:
	loaded[file] = nodes
	_timers.erase(file)


## Человек вошёл в зону: отсчёт выгрузки отменяется (если шёл).
func enter(file: String) -> void:
	_timers.erase(file)


## Человек вышел из зоны: пошёл отсчёт. Файл не загружен — считать нечего.
func exit(file: String) -> void:
	if falsify_never_unload or not loaded.has(file):
		return
	_timers[file] = UNLOAD_DELAY_S


## Кадр. Возвращает список файлов, чьи узлы пора снять со сцены; их записи из учёта уже убраны.
func tick(dt: float) -> Array:
	var due: Array = []
	for file in _timers.keys():
		_timers[file] = float(_timers[file]) - dt
		if _timers[file] <= 0.0:
			due.append(file)
	for file in due:
		_timers.erase(file)
	return due


## Узлы файла и запись о нём — вызывающему на удаление.
func take(file: String) -> Array:
	var nodes: Array = loaded.get(file, [])
	loaded.erase(file)
	return nodes
