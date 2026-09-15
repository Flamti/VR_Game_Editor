extends RefCounted

## Мастер настройки шар-меню (решение владельца 2026-09-15): каждая настройка
## выставляется на живом шаре, подтверждается, переход к следующей.
##
## Шаги — Settings.MAIN плюс итог; «Дополнительно» (инерция, липкость, сглаживание
## руки) — только в папке настроек (шаг 1в: владелец не понял, что они делают).
## Значение правит редактор на панели (menu/setting_edit.gd); мастер — чистая
## логика переходов:
##   note_change() — записать изменение значения текущего шага в историю;
##   confirm()     — принять и дальше; на итоге — сохранить;
##   back()        — шаг назад, значения не теряются;
##   skip()        — поставить умолчание и дальше.
## На каждый переход — запись в history: из неё журнал сессии.

const Settings := preload("res://menu/settings.gd")

const SUMMARY := "summary"

var settings: Settings
var index := 0
var done := false
var saved := false
## [шаг, действие, значение]
var history: Array = []
## Какие шаги были подтверждены, а какие поставлены по умолчанию (для итога).
var outcome: Dictionary = {}


func _init(p_settings: Settings) -> void:
	settings = p_settings


func steps() -> Array:
	return Settings.MAIN + [SUMMARY]


func current() -> String:
	return steps()[index]


func note_change() -> void:
	if done or current() == SUMMARY:
		return
	history.append([current(), "change", settings.get_value(current())])


func confirm(save_path: String = Settings.PATH) -> void:
	if done:
		return
	if current() == SUMMARY:
		saved = settings.save(save_path) == OK
		done = true
		history.append([SUMMARY, "save", saved])
		return
	outcome[current()] = "подтверждено"
	history.append([current(), "confirm", settings.get_value(current())])
	index += 1


func skip() -> void:
	if done or current() == SUMMARY:
		return
	var id := current()
	settings.values[id] = Settings.SPEC[id]["default"]
	outcome[id] = "умолчание"
	history.append([id, "skip", settings.get_value(id)])
	index += 1


func back() -> void:
	if done or index == 0:
		return
	index -= 1
	history.append([current(), "back", settings.get_value(current())])


## Текст итога: каждая настройка мастера, её значение и как получено.
func summary_lines() -> PackedStringArray:
	var out := PackedStringArray()
	for id in Settings.MAIN:
		out.append("%s: %s (%s)" % [Settings.SPEC[id]["title"], settings.label(id), outcome.get(id, "не пройдено")])
	return out
