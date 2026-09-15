extends RefCounted

## Журнал сессии: TSV событий с unix-временем (прибор Ф2; в Ф4 — числа для
## критерия «вслепую из 40+»).
##
## Пишется сразу и сбрасывается на диск после каждой строки: прерванная сессия
## не должна терять уже сделанное (урок фазы E).

const PATH := "user://sphere_session.tsv"
## Параметры берутся из menu.params() по тем же ключам, что в Settings.SPEC. Первая
## версия читала «strategy/radius/alpha», которых меню не отдаёт: в журнале сессии 1
## (2026-09-15) колонки стратегии и радиуса пусты во всех строках.
const PARAM_KEYS := ["surface", "radius_cm", "cell_cm", "actual_cell_cm", "freq", "hand_rotation"]
const COLUMNS := ["unix_время", "событие", "поверхность", "радиус_см", "ячейка_см", "ячейка_факт_см",
		"уровень_глобуса", "вращение_рукой", "папка", "задание", "попадание", "мс_от_задания", "подробности"]

var _f: FileAccess
var rows := 0


func open() -> bool:
	var exists := FileAccess.file_exists(PATH)
	_f = FileAccess.open(PATH, FileAccess.READ_WRITE if exists else FileAccess.WRITE)
	if _f == null:
		return false
	if exists:
		_f.seek_end()
	# заголовок в начале каждой сессии: колонки менялись, файл на шлеме дописывается
	_f.store_line("# " + "\t".join(COLUMNS))
	_f.store_line("# сессия %s" % Time.get_datetime_string_from_system())
	_f.flush()
	return true


static func row(event: String, params: Dictionary, task: String = "", hit: String = "",
		ms_since_task: int = -1, detail: String = "") -> String:
	var cells := PackedStringArray(["%.3f" % Time.get_unix_time_from_system(), event])
	for k in PARAM_KEYS:
		cells.append(str(params.get(k, "")))
	cells.append_array([str(params.get("folder", "")), task, hit,
			str(ms_since_task) if ms_since_task >= 0 else "", detail.replace("\t", " ")])
	return "\t".join(cells)


func log(event: String, params: Dictionary, task: String = "", hit: String = "",
		ms_since_task: int = -1, detail: String = "") -> void:
	if _f == null:
		return
	_f.store_line(row(event, params, task, hit, ms_since_task, detail))
	_f.flush()
	rows += 1
