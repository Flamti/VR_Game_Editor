extends RefCounted

## Выгрузка сессии при «Выходе» (решение владельца после сессии 2: журнал — в общую папку
## шлема, чтобы забирать без run-as — проводником Quest или adb pull).
##
## Куда: OS.get_system_dir(SYSTEM_DIR_DOWNLOADS)/VRGE/<дата-время>/. Godot 4.7.2 на Android 10+
## пишет в общее хранилище через MediaStore (platform/android/java/lib/.../io/file/
## MediaStoreData.kt, DataAccess.kt: StorageScope.SHARED) — разрешение для файлов, созданных
## самим приложением, не нужно. Что это работает именно на Quest, проверяется исполнением на
## шлеме: результат каждого файла пишется в журнал. Отвергнуто: MANAGE_EXTERNAL_STORAGE —
## широкое разрешение ради трёх файлов; сеть — владелец выбрал папку.

const FILES := ["sphere_session.tsv", "settings_controllers.cfg", "settings_hands.cfg", "settings_common.cfg",
		"favorites.cfg"]


## Скопировать файлы user:// и текст самопроверки в каталог. dst — корень выгрузки (на столе
## подменяется на user://). Возвращает {dir, ok: Array[имя], failed: Array["имя: ошибка"]}.
static func run(dst_root: String, selfcheck_lines: Array, stamp: String) -> Dictionary:
	var dir := dst_root.path_join("VRGE").path_join(stamp)
	var out := {"dir": dir, "ok": [], "failed": []}
	var mk := DirAccess.make_dir_recursive_absolute(dir)
	if mk != OK and not DirAccess.dir_exists_absolute(dir):
		out["failed"].append("каталог: %s" % error_string(mk))
		return out
	for name: String in FILES:
		var src := "user://" + name
		if not FileAccess.file_exists(src):
			continue
		var data := FileAccess.get_file_as_bytes(src)
		var f := FileAccess.open(dir.path_join(name), FileAccess.WRITE)
		if f == null:
			out["failed"].append("%s: %s" % [name, error_string(FileAccess.get_open_error())])
			continue
		f.store_buffer(data)
		f.close()
		out["ok"].append(name)
	if not selfcheck_lines.is_empty():
		var s := FileAccess.open(dir.path_join("selfcheck.txt"), FileAccess.WRITE)
		if s == null:
			out["failed"].append("selfcheck.txt: %s" % error_string(FileAccess.get_open_error()))
		else:
			s.store_string("\n".join(selfcheck_lines) + "\n")
			s.close()
			out["ok"].append("selfcheck.txt")
	return out


static func stamp_now() -> String:
	return Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
