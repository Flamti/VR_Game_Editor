extends RefCounted

## Хранилище профилей пользователей (ADR-0010, `docs/design/user-profiles.md` §5).
##
##   <root>/device.cfg                 устройство: секрет, последний активный профиль
##   <root>/profiles/index.cfg         список профилей: id, имя, цвет, есть ли PIN
##   <root>/profiles/<id>/profile.cfg  профиль (profile/user_profile.gd)
##   <root>/profiles/<id>/settings_*.cfg, favorites.cfg, secrets.enc
##
## Профиль адресуется случайным id, не именем: имя меняется, а ссылки (журнал, последний активный)
## рваться не должны. device.cfg хранит секрет устройства — в выгрузку он не попадает, как и
## secrets.enc (session/export.gd).

const UserProfile := preload("res://profile/user_profile.gd")

const DEFAULT_NAME := "Основной"
## Файлы до профилей в корне user:// — переезжают в первый профиль. sphere_settings.cfg — формат до
## профилей настроек по вводу: становится набором контроллеров, если набора ещё нет.
const LEGACY_FILES := ["settings_controllers.cfg", "settings_hands.cfg", "settings_common.cfg", "favorites.cfg"]
const LEGACY_SETTINGS := "sphere_settings.cfg"

var root := "user://"
## id → {name, color, has_pin}; порядок — order.
var index: Dictionary = {}
var order: Array = []
var last_active := ""
## Фальсификатор «nomigrate»: первый профиль создаётся пустым, старые файлы остаются лежать.
var falsify_no_migrate := false
## Фальсификатор «removelast»: удаляется и последний профиль — приложение остаётся без профиля.
var falsify_remove_last := false


func _init(p_root: String = "user://") -> void:
	root = p_root


func profiles_dir() -> String:
	return root.path_join("profiles")


## Общий каталог проектов устройства: у разных людей он один, в профиле — только ссылки
## (profile/projects.gd).
func projects_dir() -> String:
	return root.path_join("projects")


func dir_of(id: String) -> String:
	return profiles_dir().path_join(id)


func load_index() -> void:
	index = {}
	order = []
	var cf := ConfigFile.new()
	if cf.load(profiles_dir().path_join("index.cfg")) == OK:
		order = cf.get_value("index", "order", [])
		for id in order:
			index[id] = cf.get_value("profiles", id, {})
	var dev := ConfigFile.new()
	if dev.load(root.path_join("device.cfg")) == OK:
		last_active = dev.get_value("device", "last_active", "")


func save_index() -> Error:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(profiles_dir()))
	var cf := ConfigFile.new()
	cf.set_value("index", "order", order)
	for id in order:
		cf.set_value("profiles", id, index[id])
	return cf.save(profiles_dir().path_join("index.cfg"))


func _save_device(key: String, value: Variant) -> void:
	var dev := ConfigFile.new()
	dev.load(root.path_join("device.cfg"))
	dev.set_value("device", key, value)
	dev.save(root.path_join("device.cfg"))


## Секрет устройства — корень ключа для секретов профилей без PIN (ADR-0011 п. 3).
func device_secret() -> PackedByteArray:
	var dev := ConfigFile.new()
	dev.load(root.path_join("device.cfg"))
	var s: PackedByteArray = dev.get_value("device", "secret", PackedByteArray())
	if s.size() != 32:
		s = Crypto.new().generate_random_bytes(32)
		dev.set_value("device", "secret", s)
		dev.save(root.path_join("device.cfg"))
	return s


func create(profile_name: String, color: String = "") -> String:
	var id := "p" + Crypto.new().generate_random_bytes(6).hex_encode()
	var p := UserProfile.new()
	p.id = id
	p.name = profile_name
	p.color = color if color != "" else UserProfile.COLORS[order.size() % UserProfile.COLORS.size()]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir_of(id)))
	p.save(dir_of(id))
	order.append(id)
	_index_row(p)
	save_index()
	return id


func get_profile(id: String) -> UserProfile:
	var p := UserProfile.new()
	if not p.load_from(dir_of(id)):
		return null
	return p


## Сохранить профиль и его строку в списке (имя, цвет, PIN видны в выборе профиля без загрузки).
func save_profile(p: UserProfile) -> Error:
	var err := p.save(dir_of(p.id))
	_index_row(p)
	save_index()
	return err


func _index_row(p: UserProfile) -> void:
	index[p.id] = {"name": p.name, "color": p.color, "has_pin": p.has_pin()}


func set_active(id: String) -> void:
	last_active = id
	_save_device("last_active", id)


## Профиль при запуске: последний активный, если он есть, иначе первый.
func startup_id() -> String:
	if last_active in order:
		return last_active
	return order[0] if not order.is_empty() else ""


## Удалить профиль с его каталогом. Последний профиль не удаляется: приложение без профиля не живёт.
func remove(id: String) -> bool:
	if not id in order or (order.size() <= 1 and not falsify_remove_last):
		return false
	_remove_tree(dir_of(id))
	order.erase(id)
	index.erase(id)
	save_index()
	if last_active == id:
		set_active(order[0] if not order.is_empty() else "")
	return true


func _remove_tree(dir: String) -> void:
	var abs := ProjectSettings.globalize_path(dir)
	var d := DirAccess.open(abs)
	if d == null:
		return
	for sub in d.get_directories():
		_remove_tree(dir.path_join(sub))
	for f in d.get_files():
		d.remove(f)
	DirAccess.remove_absolute(abs)


## Первый запуск с профилями: список пуст — создать «Основной» и перенести в него файлы, лежавшие в
## корне до профилей. Старые файлы переименовываются в *.migrated, не удаляются. Возвращает
## {created: id или "", migrated: [имена]}.
func ensure_default() -> Dictionary:
	load_index()
	var out := {"created": "", "migrated": []}
	if not order.is_empty():
		return out
	var id := create(DEFAULT_NAME)
	out["created"] = id
	set_active(id)
	if falsify_no_migrate:
		return out
	for f in LEGACY_FILES:
		if _move_legacy(f, f):
			out["migrated"].append(f)
	if not FileAccess.file_exists(dir_of(id).path_join("settings_controllers.cfg")) \
			and _move_legacy(LEGACY_SETTINGS, "settings_controllers.cfg"):
		out["migrated"].append(LEGACY_SETTINGS)
	return out


func _move_legacy(src_name: String, dst_name: String) -> bool:
	var src := root.path_join(src_name)
	if not FileAccess.file_exists(src):
		return false
	var data := FileAccess.get_file_as_bytes(src)
	var f := FileAccess.open(dir_of(startup_id()).path_join(dst_name), FileAccess.WRITE)
	if f == null:
		return false
	f.store_buffer(data)
	f.close()
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(src),
			ProjectSettings.globalize_path(src + ".migrated")) == OK
