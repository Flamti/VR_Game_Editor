extends RefCounted

## Вход Google для устройств с ограниченным вводом — поток «код устройства» (ADR-0011 п. 1).
##
## Шлем показывает адрес и код, человек входит с телефона или ПК; шлем опрашивает эндпоинт токена.
## Здесь только конечный автомат: какие запросы слать и что значит ответ. Сеть и время — снаружи
## (accounts/account_service.gd), поэтому поток проверяется настольно на готовых ответах.
##
## Сверено с документацией Google 2026-09-19 (developers.google.com/identity/protocols/oauth2/
## limited-input-device): POST form-urlencoded; ответ кода — device_code, user_code,
## verification_url, expires_in, interval; опрос — grant_type
## urn:ietf:params:oauth:grant-type:device_code с client_secret; ошибки опроса:
## authorization_pending 428, slow_down 403, access_denied 403, invalid_client 401, invalid_grant 400.
## Отдельной ошибки об истечении кода в списке нет — истечение считается здесь по expires_in.
## Область — только drive.file: адрес почты даёт вызов Drive about.get (fields=user), openid не нужен.

const CODE_URL := "https://oauth2.googleapis.com/device/code"
const TOKEN_URL := "https://oauth2.googleapis.com/token"
const SCOPE := "https://www.googleapis.com/auth/drive.file"
const ABOUT_URL := "https://www.googleapis.com/drive/v3/about?fields=user"
const GRANT := "urn:ietf:params:oauth:grant-type:device_code"
## RFC 8628 §3.5: на slow_down интервал растёт на 5 с.
const SLOW_DOWN_S := 5

## "idle" | "code" (ждём ответа на запрос кода) | "waiting" (человек входит) | "done" | "failed"
var state := "idle"
var client_id := ""
var client_secret := ""
var device_code := ""
var user_code := ""
var url := ""
var interval_s := 5
var expires_at_ms := 0
var next_poll_ms := 0
var refresh_token := ""
var access_token := ""
var failure := ""
## Фальсификатор «noslowdown»: slow_down не увеличивает интервал — сервер продолжает отказывать.
var falsify_no_slowdown := false


func _init(p_client_id: String, p_client_secret: String) -> void:
	client_id = p_client_id
	client_secret = p_client_secret


static func _form(fields: Dictionary) -> String:
	var parts := PackedStringArray()
	for k in fields:
		parts.append("%s=%s" % [k, str(fields[k]).uri_encode()])
	return "&".join(parts)


static func _post(url_: String, fields: Dictionary) -> Dictionary:
	return {"method": HTTPClient.METHOD_POST, "url": url_, "body": _form(fields),
			"headers": PackedStringArray(["Content-Type: application/x-www-form-urlencoded"])}


func code_request() -> Dictionary:
	state = "code"
	return _post(CODE_URL, {"client_id": client_id, "scope": SCOPE})


func on_code(code: int, body: String, now_ms: int) -> void:
	var d: Variant = JSON.parse_string(body)
	if code != 200 or not d is Dictionary or not d.has("device_code"):
		_fail("запрос кода: %d %s" % [code, (d as Dictionary).get("error", "") if d is Dictionary else ""])
		return
	device_code = d["device_code"]
	user_code = d.get("user_code", "")
	url = d.get("verification_url", d.get("verification_uri", ""))
	interval_s = int(d.get("interval", 5))
	expires_at_ms = now_ms + int(d.get("expires_in", 1800)) * 1000
	next_poll_ms = now_ms + interval_s * 1000
	state = "waiting"


## Пора ли опрашивать. Истёк код — поток проваливается сам, без запроса.
func due(now_ms: int) -> bool:
	if state != "waiting":
		return false
	if now_ms >= expires_at_ms:
		_fail("код истёк — начните вход заново")
		return false
	return now_ms >= next_poll_ms


func poll_request() -> Dictionary:
	return _post(TOKEN_URL, {"client_id": client_id, "client_secret": client_secret,
			"device_code": device_code, "grant_type": GRANT})


func on_poll(code: int, body: String, now_ms: int) -> void:
	var d: Variant = JSON.parse_string(body)
	var dd: Dictionary = d if d is Dictionary else {}
	if code == 200 and dd.has("access_token"):
		access_token = dd["access_token"]
		refresh_token = dd.get("refresh_token", "")
		state = "done"
		return
	match str(dd.get("error", "")):
		"authorization_pending":
			pass
		"slow_down":
			if not falsify_no_slowdown:
				interval_s += SLOW_DOWN_S
		"access_denied":
			_fail("вход отклонён")
			return
		"expired_token", "invalid_grant":
			_fail("код истёк — начните вход заново")
			return
		_:
			_fail("ответ %d %s" % [code, dd.get("error", "")])
			return
	next_poll_ms = now_ms + interval_s * 1000


func _fail(why: String) -> void:
	state = "failed"
	failure = why


## Обновить токен доступа по токену обновления.
static func refresh_request(p_client_id: String, p_client_secret: String, p_refresh: String) -> Dictionary:
	return _post(TOKEN_URL, {"client_id": p_client_id, "client_secret": p_client_secret,
			"grant_type": "refresh_token", "refresh_token": p_refresh})


## Проверка: кто вошёл. Адрес — из about.get, fields=user.
static func about_request(p_access: String) -> Dictionary:
	return {"method": HTTPClient.METHOD_GET, "url": ABOUT_URL, "body": "",
			"headers": PackedStringArray(["Authorization: Bearer " + p_access])}


static func email_from_about(code: int, body: String) -> String:
	var d: Variant = JSON.parse_string(body)
	if code != 200 or not d is Dictionary:
		return ""
	return str((d as Dictionary).get("user", {}).get("emailAddress", ""))
