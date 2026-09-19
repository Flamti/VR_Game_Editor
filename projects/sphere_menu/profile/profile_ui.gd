extends RefCounted

## Действия профиля пользователя в меню (ADR-0010, `docs/design/user-profiles.md` §3, §6).
##
## Папка «Профиль: <имя>» в настройках (catalog_demo.apply_profile) шлёт действия profile_<что>;
## здесь они исполняются: новый профиль и имя (текстовый ввод панели), рост (цифры), высота глаз
## (замер), место (игровая зона), PIN (задать, сменить, снять, спросить при запуске), удаление.
##
## Отдельно от main.gd по той же причине, что роутер ввода: дымовой прогон собирает меню без
## оркестратора (PRACTICES §1.10).

## Строка для журнала: событие и подробности. Секретов здесь нет: PIN не пишется никогда.
signal logged(event: String, detail: String)

const ProfileSession := preload("res://profile/profile_session.gd")
const UserProfile := preload("res://profile/user_profile.gd")
const Pin := preload("res://profile/pin.gd")
const Menu := preload("res://menu/sphere_menu.gd")
const UiPanel := preload("res://menu/ui_panel.gd")
const AccountService := preload("res://accounts/account_service.gd")
const ApiKey := preload("res://accounts/api_key.gd")

const HEIGHT_MIN := 50
const HEIGHT_MAX := 250

var profiles: ProfileSession
var menu: Menu
var panel: UiPanel
## Аккаунты открытого профиля (этап D); null — папки аккаунтов нет.
var accounts: AccountService
## Сервис, с которым идёт работа на панели ("account_key", "account_view", "account_google").
var account := ""
## Голова (XRCamera3D) и начало XR-пространства (XROrigin3D): высота глаз — от пола этого
## пространства, не от нуля мира.
var head: Node3D
var origin: Node3D
## Вершины игровой зоны в пространстве stage. На шлеме — XRInterface.get_play_area(); в проверках
## подменяется.
var play_area: Callable = func() -> PackedVector3Array:
	var xr := XRServer.primary_interface
	return xr.get_play_area() if xr != null else PackedVector3Array()
## Кто ведёт меню сейчас — набор настроек открываемого профиля берётся для него.
var current_input: Callable = func() -> String: return "controllers"
## Время системы, мс: задержка после неверного PIN переживает перезапуск.
var now_unix_ms: Callable = func() -> int: return int(Time.get_unix_time_from_system() * 1000.0)
## Какой ввод идёт на панели: "" | "new" | "name" | "height" | "pin_set" | "pin_check".
var purpose := ""
## Проверка PIN: чей и что после успеха ("startup" | "open" | "change").
var pin_target := ""
var pin_next := ""
## Фальсификатор «nolock»: пока спрашивают PIN при запуске, шар не заперт.
var falsify_no_lock := false
## Фальсификатор «eyeworld»: высота глаз — от нуля мира, а не от пола XR-пространства.
var falsify_eye_world := false
## Фальсификатор «noreseal»: при смене или снятии PIN секреты не перешифровываются — файл остаётся
## под прежним ключом и больше не открывается.
var falsify_no_reseal := false


func _init(p_profiles: ProfileSession, p_menu: Menu, p_panel: UiPanel) -> void:
	profiles = p_profiles
	menu = p_menu
	panel = p_panel


func active() -> bool:
	return purpose != ""


func rows() -> Array:
	var out := []
	for id in profiles.store.order:
		var row: Dictionary = profiles.store.index[id]
		out.append({"id": id, "name": row.get("name", "?"), "has_pin": row.get("has_pin", false)})
	return out


## Пересобрать папку профиля: подписи показывают текущие значения.
func rebuild() -> void:
	var acc := []
	if accounts != null:
		for s in AccountService.SERVICES:
			acc.append({"service": s, "title": "%s — %s" % [AccountService.TITLES[s], accounts.status_text(s)],
					"short": AccountService.TITLES[s]})
	menu.catalog.apply_profile(rows(), profiles.profile.id, profiles.profile, acc)
	menu.refresh_list()


## Аккаунт сменил состояние (проверка, вход Google): подписи — заново, панель входа — обновить.
func on_accounts_changed(service: String) -> void:
	rebuild()
	if purpose == "account_google" and service == "google":
		_google_panel()
	elif purpose == "account_view" and service == account:
		_account_panel(service)


## Запуск после самопроверки. Ввод включается сразу (on_ready): без него PIN не набрать. Если у
## профиля PIN — шар заперт до верного ввода, открыта только панель.
func start(on_ready: Callable) -> void:
	rebuild()
	on_ready.call()
	if profiles.profile.has_pin():
		_ask_pin(profiles.profile.id, "startup")


func on_action(action: String, arg: String) -> void:
	var p := profiles.profile
	match action:
		"profile_open":
			if arg == p.id or not profiles.store.index.has(arg):
				return
			if profiles.store.index[arg].get("has_pin", false):
				_ask_pin(arg, "open")
			else:
				_open(arg)
		"profile_new":
			_text("new", "Новый профиль: имя", {"hint": "наберите имя; «Готово» — создать и перейти в профиль"})
		"profile_name":
			_text("name", "Имя профиля", {"text": p.name.to_lower(), "hint": "«Готово» — сохранить"})
		"profile_height":
			_text("height", "Рост, см", {"digits": true, "max": 3, "hint": "от %d до %d см" % [HEIGHT_MIN, HEIGHT_MAX]})
		"profile_eye":
			measure_eye()
		"profile_place":
			remember_place()
		"profile_pin":
			if p.has_pin():
				_ask_pin(p.id, "change")
			else:
				_text("pin_set", "Новый PIN", {"digits": true, "masked": true, "max": Pin.MAX_LEN,
						"hint": "%d–%d цифр; «Готово» — задать" % [Pin.MIN_LEN, Pin.MAX_LEN]})
		"profile_account":
			_account_action(arg)
		"profile_delete":
			var old := p.id
			var old_name := p.name
			if profiles.store.remove(old):
				profiles.profile = null
				_open(profiles.store.startup_id())
				logged.emit("профиль_удалён", old_name)


## Высота глаз стоя — высота головы над полом XR-пространства (stage), м.
func measure_eye() -> void:
	var y := head.global_position.y if falsify_eye_world else (origin.global_transform.affine_inverse() * head.global_position).y
	profiles.profile.eye_m = snappedf(y, 0.01)
	profiles.store.save_profile(profiles.profile)
	menu.nav.message = "Высота глаз: %s м" % String.num(profiles.profile.eye_m, 2).replace(".", ",")
	logged.emit("профиль_глаза", "%.2f м" % profiles.profile.eye_m)
	rebuild()


## Запомнить место: игровая зона и рабочая точка — где стоит голова, куда смотрит (по горизонту).
func remember_place() -> void:
	var area: PackedVector3Array = play_area.call()
	if area.is_empty():
		menu.nav.message = "Шлем не отдал игровую зону — место не запомнено"
		logged.emit("профиль_место", "зоны нет")
		return
	var p := profiles.profile
	var local := origin.global_transform.affine_inverse() * head.global_transform
	var fwd := -local.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3.FORWARD
	var work := Transform3D(Basis.looking_at(fwd, Vector3.UP), Vector3(local.origin.x, 0.0, local.origin.z))
	var known := p.find_place(area)
	var place_name: String = p.places[known]["name"] if known >= 0 else "Место %d" % (p.places.size() + 1)
	p.remember_place(place_name, area, work)
	profiles.store.save_profile(p)
	menu.nav.message = "%s: %s" % ["Место обновлено" if known >= 0 else "Место запомнено", place_name]
	logged.emit("профиль_место", "%s, вершин %d, %s" % [place_name, area.size(), "обновлено" if known >= 0 else "новое"])
	rebuild()


## Пункт аккаунта: подключённый — панель со статусом (проверить, отключить); нет — подключение:
## ключ набором или из файла, Google — вход по коду устройства.
func _account_action(service: String) -> void:
	if accounts == null:
		return
	account = service
	if not profiles.secrets_open:
		menu.nav.message = "Аккаунты заперты — войдите в профиль по PIN"
		return
	if accounts.connected(service):
		purpose = "account_view"
		menu.panel_locked = true
		_account_panel(service)
		accounts.check(service)
	elif service == "google":
		purpose = "account_google"
		menu.panel_locked = true
		_google_panel()
		accounts.google_start()
	else:
		_text("account_key", "Ключ API: %s" % AccountService.TITLES[service], {"masked": true, "max": 200,
				"keep_case": true, "hint": "наберите ключ или «Из файла»: user://import/%s.key" % service},
				["done", "import", "cancel"])


func _account_panel(service: String) -> void:
	var m := accounts.meta(service)
	var lines := PackedStringArray([accounts.status_text(service)])
	if service != "google" and accounts.connected(service):
		lines.append("ключ %s" % ApiKey.masked(profiles.secrets[service]["key"]))
	if m.has("checked_unix"):
		lines.append("проверено %s" % Time.get_datetime_string_from_unix_time(int(m["checked_unix"])).replace("T", " "))
	panel.open_summary(AccountService.TITLES[service], lines, ["check", "disconnect", "cancel"])


func _google_panel() -> void:
	var f := accounts.flow
	var lines := PackedStringArray()
	if f == null:
		lines.append(accounts.status_text("google"))
	elif f.state == "waiting":
		lines.append_array(["Откройте на телефоне или компьютере:", f.url, "и введите код:  %s" % f.user_code,
				"ждём входа… осталось %d мин" % ceili((f.expires_at_ms - int(accounts.now_ms.call())) / 60000.0)])
	else:
		lines.append("запрашиваем код…" if f.state == "code" else f.failure)
	panel.open_summary("Google Drive: вход", lines, ["cancel"])


func _open(id: String) -> void:
	profiles.open(id, current_input.call())
	rebuild()
	logged.emit("профиль_открыт", profiles.profile.name)


func _text(p_purpose: String, title: String, opts: Dictionary, buttons: Array = ["done", "cancel"]) -> void:
	purpose = p_purpose
	menu.panel_locked = true
	var mode: String = menu.settings.get_value("search_keyboard")
	panel.open_text(title, buttons, mode, opts)


func _ask_pin(id: String, next: String) -> void:
	pin_target = id
	pin_next = next
	var who: String = profiles.store.index[id].get("name", "?")
	var buttons := ["done", "other"] if next == "startup" else ["done", "cancel"]
	if next == "startup":
		# Шар заперт, открыта только панель: сначала открыть (иначе панели не видно), потом запереть.
		if not menu.is_open():
			menu.toggle()
		menu.locked = not falsify_no_lock
	_text("pin_check", "PIN профиля «%s»" % who, {"digits": true, "masked": true, "max": Pin.MAX_LEN,
			"hint": "«Готово» — войти" + ("; «Другой» — выбрать другой профиль" if next == "startup" else "")}, buttons)


## Открыть профиль, PIN которого только что проверен на другом экземпляре: корень секретов — тот.
func _open_with_root(id: String, root: PackedByteArray) -> void:
	profiles.open(id, current_input.call(), root)
	rebuild()
	logged.emit("профиль_открыт", profiles.profile.name)


func _close() -> void:
	if purpose == "account_google" and accounts != null and accounts.flow != null:
		accounts.cancel_google()
	purpose = ""
	account = ""
	panel.close_editor()
	menu.panel_locked = false


## Кнопка панели во время ввода профиля. true — нажатие было наше.
func on_button(name: String) -> bool:
	if purpose == "":
		return false
	match name:
		"cancel":
			_close()
		"other":
			_other_profile()
		"unpin":
			profiles.profile.clear_pin()
			profiles.store.save_profile(profiles.profile)
			# Корень секретов сменился на ключ устройства — секреты перешифровываются.
			if not falsify_no_reseal:
				profiles.save_secrets()
			logged.emit("профиль_pin", "снят")
			_close()
			rebuild()
		"done":
			_done()
		"import":
			# Без await: on_button обязан вернуть true сразу — main.gd по нему решает, чья кнопка.
			var s := account
			if not FileAccess.file_exists(AccountService.IMPORT_DIR.path_join(s + ".key")):
				panel.set_hint("файла %s/%s.key нет" % [AccountService.IMPORT_DIR, s])
				return true
			_close()
			accounts.import_key(s)
		"check":
			accounts.check(account)
		"disconnect":
			var s := account
			_close()
			accounts.disconnect_service(s)
	return true


## При запуске с PIN — следующий профиль по списку: без PIN открывается сразу, с PIN — спросит свой.
func _other_profile() -> void:
	var order: Array = profiles.store.order
	var next_id: String = order[(order.find(pin_target) + 1) % order.size()]
	if next_id == pin_target:
		return
	if profiles.store.index[next_id].get("has_pin", false):
		_ask_pin(next_id, "startup")
		return
	_close()
	menu.locked = false
	_open(next_id)


func _done() -> void:
	var t := panel.text.strip_edges()
	var p := profiles.profile
	match purpose:
		"new":
			if t == "":
				panel.set_hint("имя пустое — наберите хотя бы одну букву")
				return
			_close()
			var id := profiles.store.create(t.capitalize())
			_open(id)
			logged.emit("профиль_создан", profiles.profile.name)
		"name":
			if t == "":
				panel.set_hint("имя пустое — наберите хотя бы одну букву")
				return
			p.name = t.capitalize()
			profiles.store.save_profile(p)
			_close()
			logged.emit("профиль_имя", p.name)
			rebuild()
		"height":
			var v := t.to_int()
			if v < HEIGHT_MIN or v > HEIGHT_MAX:
				panel.set_hint("рост от %d до %d см" % [HEIGHT_MIN, HEIGHT_MAX])
				return
			p.height_cm = float(v)
			profiles.store.save_profile(p)
			_close()
			logged.emit("профиль_рост", "%d см" % v)
			rebuild()
		"pin_set":
			if not Pin.valid(t):
				panel.set_hint("PIN — от %d до %d цифр" % [Pin.MIN_LEN, Pin.MAX_LEN])
				panel.clear_text()
				return
			p.set_pin(t)
			profiles.store.save_profile(p)
			# Новый корень секретов — от нового PIN; содержимое то же, перешифровать.
			if not falsify_no_reseal:
				profiles.save_secrets()
			_close()
			logged.emit("профиль_pin", "задан")
			rebuild()
		"pin_check":
			_check_pin(t)
		"account_key":
			var s := account
			_close()
			accounts.connect_key(s, t)


func _check_pin(t: String) -> void:
	var target: UserProfile = profiles.profile if pin_target == profiles.profile.id else profiles.store.get_profile(pin_target)
	var now: int = now_unix_ms.call()
	var res := target.check_pin(t, now)
	profiles.store.save_profile(target)
	logged.emit("профиль_pin_проверка", "%s: %s" % [target.name, res])
	match res:
		"wrong":
			panel.clear_text()
			panel.set_hint("Неверный PIN")
		"wait":
			panel.clear_text()
			panel.set_hint("Подождите %d с" % ceili(target.pin_wait_ms(now) / 1000.0))
		"ok":
			match pin_next:
				"startup":
					_close()
					menu.locked = false
					if pin_target != profiles.profile.id:
						_open_with_root(pin_target, target.unlocked_root)
					else:
						profiles.unlock_secrets()
						rebuild()
				"open":
					_close()
					_open_with_root(pin_target, target.unlocked_root)
				"change":
					_text("pin_set", "Новый PIN", {"digits": true, "masked": true, "max": Pin.MAX_LEN,
							"hint": "%d–%d цифр; «Снять PIN» — входить без него" % [Pin.MIN_LEN, Pin.MAX_LEN]},
							["done", "unpin", "cancel"])
