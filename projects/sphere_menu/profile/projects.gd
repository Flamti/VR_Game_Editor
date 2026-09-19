extends RefCounted

## Ссылки на проекты в профиле пользователя (ADR-0010, `docs/design/user-profiles.md` §3.6).
##
## Сами проекты лежат в общем каталоге устройства (ProfileStore.projects_dir): это место на диске,
## а не предпочтение, и у разных людей оно одно (§2). В профиле — только ссылки и своё состояние
## проекта: когда открывал, что было открыто. Формата проекта нет — по дорожной карте он требует ADR
## до первой строки кода, — поэтому содержимое проекта здесь не читается и не пишется.
##
## Ссылка: {id, title, path — относительно каталога проектов, opened_unix, state: Dictionary}.

## Фальсификатор «projectpath»: путь не проверяется — ссылка ведёт за пределы каталога проектов.
static var falsify_any_path := false


## Путь внутри каталога проектов: относительный, без «..», не пустой.
static func valid_path(path: String) -> bool:
	if falsify_any_path:
		return true
	if path == "" or path.is_absolute_path() or path.begins_with("/") or path.contains("://"):
		return false
	for part in path.split("/"):
		if part == ".." or part == "":
			return false
	return true


## Добавить ссылку. Возвращает id или "" (путь недопустим). Тот же путь — та же ссылка.
static func add(list: Array, title: String, path: String, now_unix: int) -> String:
	if not valid_path(path):
		return ""
	for p in list:
		if p["path"] == path:
			return p["id"]
	var id := "j" + Crypto.new().generate_random_bytes(5).hex_encode()
	list.append({"id": id, "title": title, "path": path, "opened_unix": now_unix, "state": {}})
	return id


static func find(list: Array, id: String) -> int:
	for i in list.size():
		if list[i]["id"] == id:
			return i
	return -1


## Отметить открытие и запомнить состояние проекта у этого пользователя (что было открыто).
static func touch(list: Array, id: String, now_unix: int, state: Dictionary = {}) -> bool:
	var i := find(list, id)
	if i < 0:
		return false
	list[i]["opened_unix"] = now_unix
	if not state.is_empty():
		list[i]["state"] = state
	return true


static func remove(list: Array, id: String) -> bool:
	var i := find(list, id)
	if i < 0:
		return false
	list.remove_at(i)
	return true


## Недавние сначала.
static func recent(list: Array) -> Array:
	var out := list.duplicate()
	out.sort_custom(func(a, b): return int(a["opened_unix"]) > int(b["opened_unix"]))
	return out
