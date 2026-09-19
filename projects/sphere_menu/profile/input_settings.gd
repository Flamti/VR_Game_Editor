extends RefCounted

## Профили настроек шар-меню по способу ввода (ADR-0010, `docs/design/user-profiles.md` §3.4, §4).
##
## Отзыв владельца после сессии 11 (2026-09-19): у рук и контроллеров разная точность ввода, один
## набор настроек на двоих подходит обоим хуже. Здесь — наборы controllers и hands; активный
## подставляется в тот же объект Settings, которым пользуется меню (menu.settings), поэтому ни один
## потребитель настроек про профили не знает.
##
## Области — Settings.scope(): "input" у каждого своя, "user" общая (при смене ввода переносится
## из уходящего набора), "session" не сохраняется. Профиль рук при первом переключении — копия
## контроллеров (решение владельца): человек начинает с уже настроенного.

const Settings := preload("res://menu/settings.gd")

## Каталог файлов профиля: settings_<ввод>.cfg и settings_common.cfg.
var dir := "user://"
var settings: Settings
var current := "controllers"
## Сохранённые значения неактивных наборов: ввод → словарь значений.
var sets: Dictionary = {}
## Фальсификатор «inputshare»: один набор на двоих, как до профилей.
var falsify_shared := false
## Фальсификатор «nocopy»: руки стартуют с умолчаний, а не с настроенного у контроллеров.
var falsify_no_copy := false
## Фальсификатор «commonsplit»: общая настройка при смене ввода не переносится.
var falsify_common_split := false


func _init(p_settings: Settings, p_dir: String = "user://") -> void:
	settings = p_settings
	dir = p_dir


func path_for(input: String) -> String:
	return dir.path_join("settings_%s.cfg" % input)


func common_path() -> String:
	return dir.path_join("settings_common.cfg")


## Есть ли у пользователя хоть один сохранённый набор (иначе — мастер при первом запуске).
func exists_any() -> bool:
	for input in Settings.INPUTS:
		if FileAccess.file_exists(path_for(input)):
			return true
	return false


## Загрузить набор активного ввода в settings. Возвращает отвергнутые ключи.
func load_current() -> Array[String]:
	_bind(current)
	settings.reset()
	return settings.load_from()


## Сменить способ ввода. Уходящий набор сохраняется и запоминается; приходящий — из памяти, из
## файла или копией уходящего. Общие настройки переходят как есть. true — набор сменился.
func switch(input: String) -> bool:
	if input == current:
		return false
	var leaving := settings.values.duplicate()
	settings.save()
	sets[current] = leaving
	var incoming: Dictionary
	if falsify_shared:
		incoming = leaving.duplicate()
	elif sets.has(input):
		incoming = (sets[input] as Dictionary).duplicate()
	elif FileAccess.file_exists(path_for(input)):
		_bind(input)
		settings.reset()
		settings.load_from()
		incoming = settings.values.duplicate()
	elif falsify_no_copy:
		settings.reset()
		incoming = settings.values.duplicate()
	else:
		incoming = leaving.duplicate()
	if not falsify_common_split:
		for id in Settings.ORDER:
			if settings.scope(id) == "user" or Settings.is_session(id):
				incoming[id] = leaving[id]
	current = input
	_bind(input)
	settings.values = incoming
	# Новый набор — сразу на диск: копия контроллеров становится профилем рук, а не памятью сессии.
	settings.save()
	return true


## Файл настроек до профилей (user://sphere_settings.cfg) становится набором контроллеров — если
## наборов ещё нет. Сам файл переименовывается в *.migrated, не удаляется. true — перенесено.
func migrate_legacy(legacy_path: String) -> bool:
	if exists_any() or not FileAccess.file_exists(legacy_path):
		return false
	current = "controllers"
	_bind(current)
	settings.reset()
	settings.load_from(legacy_path)
	settings.save()
	return DirAccess.rename_absolute(legacy_path, legacy_path + ".migrated") == OK


func _bind(input: String) -> void:
	settings.input = input
	settings.path = path_for(input)
	settings.common_path = common_path()
