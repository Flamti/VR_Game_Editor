extends RefCounted

## Скриншот (просьба владельца 2026-09-17): оба стика — снимок, сообщение о нём, файл
## screenshot_<время>.png в общей папке Download/VRGE/screenshots рядом с выгрузкой журнала
## (session/export.gd): владелец видит его в «Файлах» Quest, разработчик забирает adb pull.
##
## Кадр шлема прочитать нельзя: XR-вьюпорт рисует прямо в swapchain OpenXR
## (renderer_viewport.cpp:882, render_target_set_override), а swapchain создан без TRANSFER_SRC
## (openxr_api.cpp:1320) — get_image() данных не отдаст, патч godot/ запрещён без ADR. Поэтому
## снимок — отдельный рендер того же мира камерой в позе головы: один SubViewport на один кадр.
## Отвергнуто: системный снимок Quest (Meta + курок) — своя папка и имя, без сообщения и журнала.

const DIR_NAME := "screenshots"
const PREFIX := "screenshot_"
## Порог владельца, не измерение: 100 МиБ.
const LIMIT_BYTES := 100 * 1024 * 1024
const SIZE := Vector2i(1920, 1080)
## Вертикальный угол обзора снимка, градусы: у XR-камеры угол задаёт рантайм, а не fov узла.
## 70° по вертикали на 16:9 дают ≈102° по горизонтали — близко к полю зрения глаза Quest 3.
const FOV := 70.0
## Запасной учёт размеров, если общая папка не листается (MediaStore).
const INDEX_PATH := "user://screenshots.cfg"

## Фальсификатор «shotlimit»: порог сравнивается в мегабайтах, а сумма — в байтах.
static var falsify_limit_units := false


static func folder(downloads: String) -> String:
	return downloads.path_join("VRGE").path_join(DIR_NAME)


## screenshot_2026-09-17_20-31-05.123.png — локальное время с миллисекундами, без двоеточий.
static func file_name(unix_time: float) -> String:
	var bias: int = Time.get_time_zone_from_system()["bias"]
	# целые миллисекунды округлением: floor от дробной части double давал .506 вместо .507
	var total_ms := roundi((unix_time + bias * 60.0) * 1000.0)
	var d := Time.get_datetime_dict_from_unix_time(floori(total_ms / 1000.0))
	var ms := posmod(total_ms, 1000)
	return "%s%04d-%02d-%02d_%02d-%02d-%02d.%03d.png" % [PREFIX, d["year"], d["month"], d["day"],
			d["hour"], d["minute"], d["second"], ms]


## Сумма размеров screenshot_*.png в папке. {bytes, how}: how — «листинг» или «учёт» (папка не
## открылась, берётся учёт размеров записанных нами файлов).
static func folder_bytes(dir: String) -> Dictionary:
	var da := DirAccess.open(dir)
	if da == null:
		var cfg := ConfigFile.new()
		var total := 0
		if cfg.load(INDEX_PATH) == OK:
			for k in cfg.get_section_keys("sizes") if cfg.has_section("sizes") else PackedStringArray():
				total += int(cfg.get_value("sizes", k, 0))
		return {"bytes": total, "how": "учёт"}
	var sum := 0
	for f in da.get_files():
		if f.begins_with(PREFIX) and f.ends_with(".png"):
			var fa := FileAccess.open(dir.path_join(f), FileAccess.READ)
			if fa != null:
				sum += fa.get_length()
	return {"bytes": sum, "how": "листинг"}


static func over_limit(bytes: int) -> bool:
	if falsify_limit_units:
		return bytes / (1024 * 1024) > LIMIT_BYTES
	return bytes > LIMIT_BYTES


static func _remember(name: String, bytes: int) -> void:
	var cfg := ConfigFile.new()
	cfg.load(INDEX_PATH)
	cfg.set_value("sizes", name, bytes)
	cfg.save(INDEX_PATH)


## Снять кадр камерой в позе pose и записать в dir. Возвращает
## {ok, path, name, width, height, bytes, total_bytes, how, over_limit, ms, error}.
static func capture(host: Node, pose: Transform3D, dir: String, own_world := false) -> Dictionary:
	var t0 := Time.get_ticks_msec()
	var name := file_name(Time.get_unix_time_from_system())
	var out := {"ok": false, "path": dir.path_join(name), "name": name, "width": 0, "height": 0,
			"bytes": 0, "total_bytes": 0, "how": "", "over_limit": false, "ms": 0, "error": ""}
	var vp := SubViewport.new()
	vp.size = SIZE
	vp.msaa_3d = Viewport.MSAA_2X
	# тот же мир, что у шлема; own_world — только для фальсификатора «noworld» картинкой
	vp.own_world_3d = own_world
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var cam := Camera3D.new()
	cam.fov = FOV
	cam.current = true
	vp.add_child(cam)
	host.add_child(vp)
	cam.global_transform = pose
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	vp.queue_free()
	if img == null or img.is_empty():
		out["error"] = "кадр пуст"
		out["ms"] = Time.get_ticks_msec() - t0
		return out
	out["width"] = img.get_width()
	out["height"] = img.get_height()
	var mk := DirAccess.make_dir_recursive_absolute(dir)
	if mk != OK and not DirAccess.dir_exists_absolute(dir):
		out["error"] = "папка: %s" % error_string(mk)
		out["ms"] = Time.get_ticks_msec() - t0
		return out
	var err := img.save_png(out["path"])
	if err != OK:
		out["error"] = "запись: %s" % error_string(err)
		out["ms"] = Time.get_ticks_msec() - t0
		return out
	var fa := FileAccess.open(out["path"], FileAccess.READ)
	out["bytes"] = fa.get_length() if fa != null else 0
	_remember(name, out["bytes"])
	var total := folder_bytes(dir)
	out["total_bytes"] = total["bytes"]
	out["how"] = total["how"]
	out["over_limit"] = over_limit(total["bytes"])
	out["ok"] = true
	out["ms"] = Time.get_ticks_msec() - t0
	return out


## Текст сообщения: строка о снимке и, при переполнении, строка о месте.
static func notice(res: Dictionary) -> String:
	if not res["ok"]:
		return "Скриншот не сохранён: %s" % res["error"]
	var line := "Скриншот: %s\n%d×%d · %s · всего %s · Download/VRGE/%s" % [res["name"], res["width"],
			res["height"], mb(res["bytes"]), mb(res["total_bytes"]), DIR_NAME]
	if res["over_limit"]:
		line += "\nСкриншоты заняли %s — освободите место" % mb(res["total_bytes"])
	return line


static func mb(bytes: int) -> String:
	return ("%.1f МБ" % (bytes / 1048576.0)).replace(".", ",")
