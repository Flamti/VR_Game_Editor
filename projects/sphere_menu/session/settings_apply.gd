extends RefCounted

## Что применять после правки настройки — ОДНИМ правилом на приложение и на прибор.
##
## Дефект, ради которого файл заведён (владелец, 2026-09-23): «настройки применяются при повторном
## открытии этих настроек, а не сразу». Правка на панели доходила только до шара
## (`menu.apply_settings()`), а свет, сетка пола и слои применялись в обработчике события меню — и
## событие это порождало **открытие** пункта настройки. Человек менял значение, эффекта не видел,
## закрывал, открывал снова — и эффект появлялся, причём сразу у всех накопленных правок.
## Задеты были все тринадцать настроек из `Settings.SPACE` и `Settings.LAYERS`.
##
## Почему отдельным файлом, а не функцией в `main.gd`. Дымовой прибор повторял ту же проводку в
## своей обвязке (`panel.edit_changed.connect(menu.apply_settings)`) и потому физически не мог
## поймать дефект: он подтверждал собственную копию ошибки. Это урок ловушки 33 — правило живёт в
## одном месте, и приложение с прибором зовут именно его.

const Settings := preload("res://menu/settings.gd")

## Фальсификатор «applyball»: применяется только шар, как было до правки, — свет, сетка и слои ждут
## повторного открытия пункта меню.
var falsify_ball_only := false

## Кого применять. Любой может быть null: обвязка прибора беднее сессии, и это нормально.
var menu: Object = null
var world_env: Object = null
var floor_grid: Object = null
var vis: Object = null
var camera: Camera3D = null
## Записи объектов уровня по файлам — их видимость перестраивается вместе со слоями.
var level_nodes: Dictionary = {}
## Что сделать после применения (пересобрать подсказку). Пусто — ничего.
var after: Callable = func() -> void: return


## Применить ВСЁ, что зависит от настроек. Зовётся на каждую правку значения, а не только при
## открытии пункта.
func apply_all() -> void:
	if menu != null:
		menu.apply_settings()
	if falsify_ball_only:
		return
	apply_world()
	apply_layers()
	after.call()


## Свет и сетка пола (`Settings.SPACE`).
func apply_world() -> void:
	if menu == null:
		return
	if world_env != null:
		world_env.apply(menu.settings)
	if floor_grid != null:
		floor_grid.apply(menu.settings)


## Слои объектов (`Settings.LAYERS`): настройка переносится в учёт видимости и сразу показывается.
## Перенос живёт здесь, а не инлайном в обработчике события: там его видел только один путь.
func apply_layers() -> void:
	if menu == null or vis == null:
		return
	vis.layer_on["editor"] = bool(menu.settings.get_value("layer_editor"))
	vis.layer_on["debug"] = bool(menu.settings.get_value("layer_debug"))
	vis.apply_to(camera, level_nodes)
