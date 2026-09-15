extends RefCounted

## Правка одной настройки на панели (Ф2, шаг 1в): ползунок, −/+, цифровая
## клавиатура, «По умолчанию». Чистая логика — интерфейс (menu/ui_panel.gd) только
## передаёт нажатия и рисует text()/value.
##
## Каждое изменение сразу пишется в настройки: шар применяет его на ходу, человек
## видит эффект, пока двигает ползунок. Ввод с клавиатуры применяется по OK: иначе
## «1» на пути к «13» на мгновение сделало бы шар радиусом 6 см (упор в минимум).

const Settings := preload("res://menu/settings.gd")

## Клавиши клавиатуры: цифры, десятичный знак, стереть, очистить, принять.
const KEYS := ["7", "8", "9", "⌫", "4", "5", "6", ",", "1", "2", "3", "C", "0", "OK"]
const MAX_TYPED := 7

var settings: Settings
var id := ""
## Набранное с клавиатуры; пусто — показывается текущее значение.
var typed := ""
## Последнее сообщение (ограничение пределом, отказ ввода).
var message := ""
## Растёт при каждом изменении значения — меню применяет настройки по нему.
var changes := 0


func _init(p_settings: Settings, p_id: String) -> void:
	settings = p_settings
	id = p_id


func is_number() -> bool:
	return Settings.is_number(id)


func value() -> Variant:
	return settings.get_value(id)


func spec() -> Dictionary:
	return Settings.SPEC[id]


## Строка поля ввода: набираемое с курсором или подпись значения.
func text() -> String:
	if typed != "":
		return typed + "_"
	return settings.label(id)


func slider(v: float) -> void:
	typed = ""
	_apply(v)


func nudge(delta: int) -> void:
	typed = ""
	_apply(float(value()) + Settings.nudge(id) * delta)


func choose(index: int) -> void:
	var opts: Array = spec()["options"]
	if index < 0 or index >= opts.size():
		return
	settings.values[id] = opts[index][0]
	message = ""
	changes += 1


func default() -> void:
	typed = ""
	settings.values[id] = spec()["default"]
	message = "По умолчанию: %s" % settings.label(id)
	changes += 1


## Нажатие клавиши клавиатуры. Возвращает true, если значение изменилось.
func key(k: String) -> bool:
	message = ""
	match k:
		"⌫":
			typed = typed.substr(0, maxi(0, typed.length() - 1))
		"C":
			typed = ""
		",", ".":
			if not typed.contains(",") and float(spec()["round"]) < 1.0:
				typed = ("0" if typed == "" else typed) + ","
		"OK":
			if typed == "" or typed == ",":
				typed = ""
				return false
			var x := typed.replace(",", ".").to_float()
			typed = ""
			return _apply(x)
		_:
			if k.length() == 1 and k >= "0" and k <= "9" and typed.length() < MAX_TYPED:
				typed += k
	return false


func _apply(x: float) -> bool:
	var before: Variant = value()
	var clamped := settings.set_value(id, x)
	var s := spec()
	if clamped:
		message = "Допустимо от %s до %s %s — поставлено %s" % [
				Settings.format_number(id, float(s["min"])), Settings.format_number(id, float(s["max"])),
				s["unit"], Settings.format_number(id, float(value()))]
	else:
		message = ""
	if value() != before:
		changes += 1
		return true
	return false
