extends Node

## Сеть для аккаунтов: один запрос — один HTTPRequest (TLS — Godot). Запрос —
## {method, url, headers, body}, ответ — {code, body, error}; error — HTTPRequest.Result.
## Проверки подменяют транспорт функцией с готовыми ответами (accounts/account_service.gd).

## Сколько ждать ответа, с. Не измерение — предел терпения на экране «проверяем».
const TIMEOUT_S := 20.0


func request(req: Dictionary) -> Dictionary:
	var h := HTTPRequest.new()
	h.timeout = TIMEOUT_S
	add_child(h)
	var err := h.request(req["url"], req["headers"], req["method"], req.get("body", ""))
	if err != OK:
		h.queue_free()
		return {"code": 0, "body": "", "error": HTTPRequest.RESULT_CANT_CONNECT}
	var res: Array = await h.request_completed
	h.queue_free()
	return {"code": int(res[1]), "body": (res[3] as PackedByteArray).get_string_from_utf8(), "error": int(res[0])}
