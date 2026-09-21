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
## Ввод и профиль — с 2026-09-19: в сессии 11 источник ввода пришлось восстанавливать по строкам
## «источник», потому что в строки событий он не попадал.
const PARAM_KEYS := ["surface", "radius_cm", "cell_cm", "actual_cell_cm", "freq", "hand_rotation", "input", "profile"]
const COLUMNS := ["unix_время", "событие", "поверхность", "радиус_см", "ячейка_см", "ячейка_факт_см",
		"уровень_глобуса", "вращение_рукой", "ввод", "профиль", "папка", "задание", "попадание", "мс_от_задания",
		"подробности"]
## Фальсификатор «nocolumns»: ключи до 2026-09-19 — ввода и профиля в строке нет.
static var falsify_old_keys := false

var _f: FileAccess
var rows := 0
## Строки, записанные до open(). Журнал открывается в середине _ready, и всё, что случилось раньше,
## раньше пропадало молча: в сессии 15 так потерялась строка «уровень» — 44 объекта построились, а
## журнал о них не знал, и отсутствие записи выглядело как несостоявшаяся загрузка. Строка
## складывается в момент события (время в ней верное), на диск попадает при открытии.
var _pending := PackedStringArray()
## Фальсификатор «nobuffer»: ранние строки снова теряются молча.
static var falsify_drop_early := false


## Путь — аргументом, чтобы проверки писали в свой файл и не дописывали журнал сессии.
func open(path: String = PATH) -> bool:
	var exists := FileAccess.file_exists(path)
	_f = FileAccess.open(path, FileAccess.READ_WRITE if exists else FileAccess.WRITE)
	if _f == null:
		if _pending.size() > 0:
			push_warning("журнал: файл не открылся, потеряно ранних строк %d" % _pending.size())
		return false
	if exists:
		_f.seek_end()
	# заголовок в начале каждой сессии: колонки менялись, файл на шлеме дописывается
	_f.store_line("# " + "\t".join(COLUMNS))
	_f.store_line("# сессия %s" % Time.get_datetime_string_from_system())
	for line in _pending:
		_f.store_line(line)
	_pending.clear()
	_f.flush()
	return true


static func row(event: String, params: Dictionary, task: String = "", hit: String = "",
		ms_since_task: int = -1, detail: String = "") -> String:
	var cells := PackedStringArray(["%.3f" % Time.get_unix_time_from_system(), event])
	for k in PARAM_KEYS:
		cells.append("" if falsify_old_keys and k in ["input", "profile"] else str(params.get(k, "")))
	cells.append_array([str(params.get("folder", "")), task, hit,
			str(ms_since_task) if ms_since_task >= 0 else "", detail.replace("\t", " ")])
	return "\t".join(cells)


func log(event: String, params: Dictionary, task: String = "", hit: String = "",
		ms_since_task: int = -1, detail: String = "") -> void:
	var line := row(event, params, task, hit, ms_since_task, detail)
	if _f == null:
		if not falsify_drop_early:
			_pending.append(line)
		rows += 1
		return
	_f.store_line(line)
	_f.flush()
	rows += 1
