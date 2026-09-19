extends Node

## Подключаемые аккаунты открытого профиля (ADR-0011): Claude и ChatGPT по ключу API, Google Drive
## входом по коду устройства. Подключить, проверить, отключить.
##
## Секреты (ключи, токен обновления) — только в ProfileSession.secrets и в secrets.enc; в профиле
## (profile.cfg) — метаданные: сервис, статус, подробности, время проверки. В журнал и на экран ключ
## целиком не попадает никогда.
##
## Сеть — transport ({method, url, headers, body} → {code, body, error}); на шлеме —
## accounts/http_transport.gd, в проверках — готовые ответы. Время — now_ms, по той же причине.

signal changed(service: String)
## Строка для журнала — без секретов.
signal logged(event: String, detail: String)

const ProfileSession := preload("res://profile/profile_session.gd")
const ApiKey := preload("res://accounts/api_key.gd")
const DeviceFlow := preload("res://accounts/device_flow.gd")

const SERVICES := ["google", "claude", "openai"]
const TITLES := {"google": "Google Drive", "claude": "Claude", "openai": "ChatGPT"}
## Идентификаторы OAuth-клиента — в APK, но не в git (ADR-0011 п. 5).
const OAUTH_PATH := "res://secrets/oauth_clients.cfg"
## Импорт ключа из файла: `adb push` в /data/local/tmp, затем `run-as <пакет> cp` сюда (отладочная
## сборка). Файл после импорта удаляется.
const IMPORT_DIR := "user://import"

var profiles: ProfileSession
var transport: Callable
var now_ms: Callable = func() -> int: return Time.get_ticks_msec()
var oauth := {}
var flow: DeviceFlow = null
## Токен доступа Google — только в памяти, живёт час.
var google_access := ""
var busy := {}
var _polling := false
## Фальсификатор «plainsecret»: ключ пишется и в метаданные профиля — открытым текстом в profile.cfg.
var falsify_plain := false


func _init(p_profiles: ProfileSession, p_transport: Callable) -> void:
	profiles = p_profiles
	transport = p_transport


func load_oauth(path: String = OAUTH_PATH) -> bool:
	var cf := ConfigFile.new()
	if cf.load(path) != OK:
		oauth = {}
		return false
	oauth = {"google": {"client_id": cf.get_value("google", "client_id", ""),
			"client_secret": cf.get_value("google", "client_secret", "")}}
	return oauth["google"]["client_id"] != ""


func meta(service: String) -> Dictionary:
	for a in profiles.profile.accounts:
		if a.get("service", "") == service:
			return a
	return {}


func connected(service: String) -> bool:
	return profiles.secrets.has(service)


## Подпись пункта: «Claude — подключён (моделей: 12)», «Google Drive — не подключён».
func status_text(service: String) -> String:
	if busy.get(service, false):
		return "проверяем…"
	if service == "google" and flow != null and flow.state == "waiting":
		return "ждём входа"
	if not profiles.secrets_open:
		return "заперт PIN"
	var m := meta(service)
	if not connected(service):
		return "не подключён" if m.is_empty() or m.get("status", "") == "" else m.get("detail", "не подключён")
	match m.get("status", ""):
		"connected":
			return "подключён — " + m.get("detail", "")
		"":
			return "не проверен"
	return m.get("detail", "ошибка")


func _set_meta(service: String, status: String, detail: String) -> void:
	var list: Array = profiles.profile.accounts.filter(func(a): return a.get("service", "") != service)
	var rec := {"service": service, "status": status, "detail": detail,
			"checked_unix": int(Time.get_unix_time_from_system())}
	if falsify_plain and profiles.secrets.has(service):
		rec["secret"] = profiles.secrets[service]
	if service == "claude":
		rec["model"] = ApiKey.CLAUDE_MODEL
	list.append(rec)
	profiles.profile.accounts = list
	profiles.store.save_profile(profiles.profile)


## Подключить сервис по ключу API и сразу проверить.
func connect_key(service: String, key: String) -> void:
	key = key.strip_edges()
	if key == "" or not profiles.secrets_open:
		return
	profiles.secrets[service] = {"key": key}
	profiles.save_secrets()
	logged.emit("аккаунт_ключ", "%s: %s" % [service, ApiKey.masked(key)])
	await check(service)


## Ключ из файла user://import/<сервис>.key; файл удаляется в любом случае. false — файла нет.
func import_key(service: String) -> bool:
	var path := IMPORT_DIR.path_join(service + ".key")
	if not FileAccess.file_exists(path):
		return false
	var key := FileAccess.get_file_as_string(path).strip_edges()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	logged.emit("аккаунт_импорт", "%s: файл прочитан и удалён" % service)
	await connect_key(service, key)
	return true


func disconnect_service(service: String) -> void:
	profiles.secrets.erase(service)
	profiles.save_secrets()
	if service == "google":
		google_access = ""
		flow = null
	profiles.profile.accounts = profiles.profile.accounts.filter(func(a): return a.get("service", "") != service)
	profiles.store.save_profile(profiles.profile)
	logged.emit("аккаунт_отключён", service)
	changed.emit(service)


## Проверить подключение: ключ — запросом списка моделей; Google — обновить токен и спросить адрес.
func check(service: String) -> void:
	if not connected(service):
		return
	busy[service] = true
	changed.emit(service)
	var res: Dictionary
	if service == "google":
		res = await _check_google()
	else:
		var r: Dictionary = await transport.call(ApiKey.check_request(service, profiles.secrets[service]["key"]))
		res = ApiKey.interpret(int(r.get("code", 0)), str(r.get("body", "")), int(r.get("error", OK)))
	busy.erase(service)
	_set_meta(service, res["status"], res["detail"])
	logged.emit("аккаунт_проверка", "%s: %s — %s" % [service, res["status"], res["detail"]])
	changed.emit(service)


func _check_google() -> Dictionary:
	var g: Dictionary = oauth.get("google", {})
	if g.is_empty():
		return {"status": "unavailable", "detail": "нет OAuth-клиента (secrets/oauth_clients.cfg)"}
	var r: Dictionary = await transport.call(DeviceFlow.refresh_request(g["client_id"], g["client_secret"],
			profiles.secrets["google"]["refresh_token"]))
	if int(r.get("error", OK)) != OK:
		return {"status": "offline", "detail": "нет сети"}
	var d: Variant = JSON.parse_string(str(r.get("body", "")))
	if int(r.get("code", 0)) != 200 or not d is Dictionary or not (d as Dictionary).has("access_token"):
		return {"status": "bad_key", "detail": "вход отозван — подключите заново"}
	google_access = d["access_token"]
	var a: Dictionary = await transport.call(DeviceFlow.about_request(google_access))
	var email := DeviceFlow.email_from_about(int(a.get("code", 0)), str(a.get("body", "")))
	if email == "":
		return {"status": "unavailable", "detail": "Drive ответил %d" % int(a.get("code", 0))}
	return {"status": "connected", "detail": email}


## Начать вход Google: запросить код. Код и адрес — в flow (user_code, url), их показывает панель.
func google_start() -> void:
	var g: Dictionary = oauth.get("google", {})
	if g.is_empty() or not profiles.secrets_open:
		_set_meta("google", "unavailable", "нет OAuth-клиента (secrets/oauth_clients.cfg)" if g.is_empty() else "заперт PIN")
		changed.emit("google")
		return
	flow = DeviceFlow.new(g["client_id"], g["client_secret"])
	var r: Dictionary = await transport.call(flow.code_request())
	if int(r.get("error", OK)) != OK:
		flow.on_code(0, "", now_ms.call())
	else:
		flow.on_code(int(r.get("code", 0)), str(r.get("body", "")), now_ms.call())
	logged.emit("аккаунт_google", "код: %s" % flow.state)
	changed.emit("google")


func cancel_google() -> void:
	flow = null
	changed.emit("google")


func _process(_delta: float) -> void:
	tick()


## Опросить эндпоинт токена, если пора. Проверки зовут напрямую.
func tick() -> void:
	if flow == null or _polling or not flow.due(now_ms.call()):
		if flow != null and flow.state == "failed":
			_google_failed()
		return
	_polling = true
	var r: Dictionary = await transport.call(flow.poll_request())
	_polling = false
	if flow == null:
		return
	flow.on_poll(int(r.get("code", 0)), str(r.get("body", "")), now_ms.call())
	match flow.state:
		"done":
			profiles.secrets["google"] = {"refresh_token": flow.refresh_token}
			profiles.save_secrets()
			google_access = flow.access_token
			flow = null
			logged.emit("аккаунт_google", "вход выполнен")
			await check("google")
		"failed":
			_google_failed()
		_:
			changed.emit("google")


func _google_failed() -> void:
	var why := flow.failure
	flow = null
	_set_meta("google", "", why)
	logged.emit("аккаунт_google", "провал: " + why)
	changed.emit("google")
