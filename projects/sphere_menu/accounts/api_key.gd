extends RefCounted

## Ключи API сервисов моделей (ADR-0011 п. 2): проверка без расхода токенов — запрос списка
## моделей. Только форма запроса и разбор ответа; сеть — accounts/account_service.gd.
##
## Сверено с документацией 2026-09-19 (правило 8):
##   Anthropic — GET https://api.anthropic.com/v1/models, заголовки x-api-key и
##               anthropic-version: 2023-06-01; 401 — неверный ключ, 403 — ключу запрещено;
##   OpenAI    — GET https://api.openai.com/v1/models, Authorization: Bearer <ключ>.
## Вход по подписке (Claude.ai, ChatGPT) сторонним приложениям не открыт — только ключи.

const SERVICES := {
	"claude": {"title": "Claude", "url": "https://api.anthropic.com/v1/models"},
	"openai": {"title": "ChatGPT (OpenAI)", "url": "https://api.openai.com/v1/models"},
}
const ANTHROPIC_VERSION := "2023-06-01"
## Модель Claude по умолчанию — хранится в профиле для будущих вызовов (ADR-0011 п. 2).
const CLAUDE_MODEL := "claude-opus-5"

## Фальсификатор «wrongheader»: ключ Anthropic уходит заголовком OpenAI — Authorization: Bearer.
static var falsify_wrong_header := false


## {method, url, headers} запроса проверки.
static func check_request(service: String, key: String) -> Dictionary:
	var headers: PackedStringArray
	if service == "claude" and not falsify_wrong_header:
		headers = PackedStringArray(["x-api-key: " + key, "anthropic-version: " + ANTHROPIC_VERSION])
	else:
		headers = PackedStringArray(["Authorization: Bearer " + key])
	return {"method": HTTPClient.METHOD_GET, "url": SERVICES[service]["url"], "headers": headers, "body": ""}


## Ответ → {status, detail}. status: "connected" | "bad_key" | "forbidden" | "unavailable" | "offline".
## error — ошибка транспорта (HTTPRequest.Result), OK — дошло.
static func interpret(code: int, body: String, error: int = OK) -> Dictionary:
	if error != OK:
		return {"status": "offline", "detail": "нет сети (ошибка %d)" % error}
	match code:
		200:
			var parsed: Variant = JSON.parse_string(body)
			var n: int = (parsed["data"] as Array).size() if parsed is Dictionary and parsed.get("data") is Array else 0
			return {"status": "connected", "detail": "моделей: %d" % n}
		401:
			return {"status": "bad_key", "detail": "неверный ключ"}
		403:
			return {"status": "forbidden", "detail": "ключу запрещён доступ"}
	return {"status": "unavailable", "detail": "сервис ответил %d" % code}


## Ключ на экране — только начало и конец: целиком он не показывается и в журнал не пишется.
static func masked(key: String) -> String:
	if key.length() <= 10:
		return "•••"
	return "%s…%s" % [key.substr(0, 6), key.substr(key.length() - 4)]
