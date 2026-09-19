extends RefCounted

## Активный профиль пользователя в работающем приложении (ADR-0010): открыть при запуске, сменить,
## сохранить. Держит хранилище, профиль, наборы настроек по вводу и избранное меню.
##
## Отдельно от main.gd: дымовой прогон собирает меню без оркестратора, и смену пользователя он должен
## видеть так же, как шлем (PRACTICES §1.10).

const ProfileStore := preload("res://profile/profile_store.gd")
const UserProfile := preload("res://profile/user_profile.gd")
const InputSettings := preload("res://profile/input_settings.gd")
const Menu := preload("res://menu/sphere_menu.gd")
const SecretBox := preload("res://accounts/secret_box.gd")

const FAVORITES := "favorites.cfg"

var store: ProfileStore
var profile: UserProfile
var input_settings: InputSettings
var menu: Menu
## Фальсификатор «staleprofile»: при смене пользователя остаются настройки и избранное прежнего.
var falsify_stale := false
## Секреты аккаунтов открытого профиля — только в памяти (ADR-0011): {сервис: {key | refresh_token}}.
var secrets: Dictionary = {}
## Секреты расшифрованы. false — профиль с PIN ещё не отперт, или файл не открылся (чужой ключ, подмена).
var secrets_open := false


func _init(p_store: ProfileStore, p_menu: Menu) -> void:
	store = p_store
	menu = p_menu
	input_settings = InputSettings.new(menu.settings, "user://")


func dir() -> String:
	return store.dir_of(profile.id)


## Открыть профиль id: настройки активного способа ввода, избранное, id в журнал. Прежний, если был,
## сначала сохраняется. input — кто ведёт меню сейчас. root — корень секретов, если PIN только что
## проверен на другом экземпляре профиля (profile_ui: смена на профиль с PIN). Возвращает отвергнутые
## ключи настроек.
func open(id: String, input: String, root: PackedByteArray = PackedByteArray()) -> Array[String]:
	if profile != null:
		save()
	var p := store.get_profile(id)
	if p == null:
		return []
	profile = p
	if not root.is_empty():
		profile.unlocked_root = root
	unlock_secrets()
	store.set_active(id)
	var rejected: Array[String] = []
	if not falsify_stale:
		rejected = input_settings.rebind(dir(), input)
		menu.catalog.load_favorites(dir().path_join(FAVORITES))
	menu.profile_id = profile.id
	menu.apply_settings()
	menu.catalog.apply_input(menu.settings)
	menu.refresh_list()
	return rejected


## Корень ключа секретов: у профиля с PIN — после верного PIN (иначе пусто), без PIN — от секрета
## устройства.
func secret_root() -> PackedByteArray:
	if profile.has_pin():
		return profile.unlocked_root
	return SecretBox.root_without_pin(store.device_secret(), profile.id)


## Расшифровать секреты профиля. false — заперт PIN или файл не открылся.
func unlock_secrets() -> bool:
	secrets = {}
	secrets_open = false
	var root := secret_root()
	if root.is_empty():
		return false
	var d: Variant = SecretBox.load_from(dir(), root)
	if d == null:
		return false
	secrets = d
	secrets_open = true
	return true


## Записать секреты текущим корнем — после правки аккаунтов и после смены или снятия PIN (корень
## сменился, содержимое то же).
func save_secrets() -> Error:
	if not secrets_open:
		return ERR_UNAUTHORIZED
	return SecretBox.save(dir(), secret_root(), secrets)


## Сохранить всё пользовательское: профиль, набор настроек активного ввода, избранное.
func save() -> void:
	if profile == null:
		return
	store.save_profile(profile)
	menu.settings.save()
	menu.catalog.save_favorites(dir().path_join(FAVORITES))
