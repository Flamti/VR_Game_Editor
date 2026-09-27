extends RefCounted

## Метка: человек в шлеме отмечает момент одним нажатием («≡» на левом контроллере), и в журнал
## уходит снимок состояния — где голова и кисти, что делает тело, что в руках, в какой комнате.
##
## Зачем. Ощущения владельца доходят словами без привязки: «предмет ловится рядом с контроллером,
## потом может передвинуться» (сессия 35) — ни времени, ни позы, ни картинки. С меткой он говорит
## «метка 3 — уплыл», и у разбора есть время, числа и скриншот того же мгновения.
##
## Кисти — ОТНОСИТЕЛЬНО ORIGIN, то есть так, как их двигает человек: в мире рука висящего стоит на
## зацепе (урок мёртвого рывка перевала, сессия 35). Голова — и в мире, и в origin.
##
## Чистые функции на узлах и значениях: собирает `main.gd`, проверяет `tests/boot_main.gd`.

## Фальсификатор «markblind» (tests/boot_main.gd): метка пишет строку без позы.
static var falsify_blind := false


static func _v(p: Vector3) -> String:
	return "(%.2f, %.2f, %.2f)" % [p.x, p.y, p.z]


## Снимок. `hands` — {"left": узел, "right": узел} (дети origin); `held`/`flying` — имена предметов
## по рукам; `room` — файл комнаты, в зоне которой голова, или «» (улица).
static func snapshot(head: Node3D, origin: Node3D, body: Node3D, hands: Dictionary, mode: String,
		held: Dictionary, flying: Dictionary, room: String) -> Dictionary:
	var out := {"mode": mode, "held": held, "flying": flying, "room": room}
	if falsify_blind:
		return out
	out["head"] = head.global_position
	out["head_local"] = head.position
	out["yaw"] = rad_to_deg(head.global_rotation.y)
	out["body"] = body.global_position
	out["origin"] = origin.position
	for side in hands:
		var h := hands[side] as Node3D
		if h != null:
			out[side] = h.position
			out[side + "_world"] = h.global_position
	return out


## Строка журнала: «МЕТКА n: …». Поля без значения пишутся «—», а не пропадают: их отсутствие
## иначе не отличить от формата старой версии.
static func line(n: int, s: Dictionary) -> String:
	var parts: Array[String] = []
	if s.has("head"):
		parts.append("голова %s, в origin %s, курс %.0f°" % [_v(s["head"]), _v(s["head_local"]), float(s["yaw"])])
		for side in ["left", "right"]:
			if s.has(side):
				parts.append("%s в origin %s, в мире %s" % ["левая" if side == "left" else "правая",
						_v(s[side]), _v(s[side + "_world"])])
		parts.append("ноги %s" % _v(s["body"]))
		parts.append("origin %s" % _v(s["origin"]))
	parts.append("режим %s" % s["mode"])
	parts.append("держит %s" % _names(s["held"]))
	parts.append("летит %s" % _names(s["flying"]))
	parts.append("комната %s" % (str(s["room"]).get_file() if str(s["room"]) != "" else "улица"))
	return "МЕТКА %d: %s" % [n, "; ".join(parts)]


static func _names(d: Dictionary) -> String:
	if d.is_empty():
		return "—"
	var out: Array[String] = []
	for k in d:
		out.append("%s %s" % [k, d[k]])
	return ", ".join(out)
