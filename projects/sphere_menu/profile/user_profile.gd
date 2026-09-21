extends RefCounted

## Профиль пользователя (ADR-0010, `docs/design/user-profiles.md` §3): личное, тело, места, PIN,
## ссылки на проекты и метаданные аккаунтов. Настройки по способу ввода и избранное — отдельные файлы в
## каталоге профиля (profile/input_settings.gd, catalog_demo.gd); секреты аккаунтов — `secrets.enc`.

const Pin := preload("res://profile/pin.gd")

const FILE := "profile.cfg"
## Цвета значка профиля — набор, из которого выбирает пользователь.
const COLORS := ["#4f8fe6", "#e6804f", "#5fbf6a", "#c95fbf", "#d9c24a", "#5fbfbf"]
## Совпадение игровой зоны с местом: каждая вершина ближе этого, м. НЕ ИЗМЕРЕНО: одна и та же граница
## Quest должна отдавать те же вершины; число — запас на пересохранение границы, сверяется на шлеме.
const PLACE_TOLERANCE_M := 0.10

var id := ""
var name := ""
var color := COLORS[0]
var lang := "ru"
## Тело: 0 — не задано.
var height_cm := 0.0
var eye_m := 0.0
var stance := "stand"
## Хранится, в интерфейсе не показывается, пока меню не умеет жить в правой руке (ADR-0010 п. 8).
var dominant := "right"
## PIN: итерации 0 — PIN нет.
var pin_salt := PackedByteArray()
var pin_hash := PackedByteArray()
var pin_iterations := 0
var pin_fails := 0
var pin_fail_unix_ms := 0
## Корень ключа секретов после верного PIN (или при его задании) — только в памяти, не сохраняется.
var unlocked_root := PackedByteArray()
## Места: {name, area: PackedVector2Array (x, z игровой зоны в stage), work: Transform3D, desk_m,
## room: ключ комнаты от шлема (UUID пола, world/room.gd) — надёжнее зоны, anchors: Array}.
var places: Array = []
## Проекты (этап E) и аккаунты (этап D) — метаданные, без секретов.
var projects: Array = []
var accounts: Array = []
## Фальсификатор «placeany»: место узнаётся по числу вершин, без допуска — любая зона той же формы.
static var falsify_place_any := false


func has_pin() -> bool:
	return pin_iterations > 0


func set_pin(pin: String, iterations: int = Pin.ITERATIONS) -> bool:
	if not Pin.valid(pin):
		return false
	pin_salt = Pin.make_salt()
	pin_iterations = iterations
	var m := Pin.master(pin, pin_salt, iterations)
	pin_hash = Pin.verifier(m)
	unlocked_root = Pin.secret_root(m)
	pin_fails = 0
	return true


func clear_pin() -> void:
	pin_salt = PackedByteArray()
	pin_hash = PackedByteArray()
	pin_iterations = 0
	pin_fails = 0


## Проверить PIN. now_unix_ms — время системы: задержка должна пережить перезапуск приложения.
## Возвращает "ok" | "wrong" | "wait" (задержка после ошибок не истекла).
func check_pin(pin: String, now_unix_ms: int) -> String:
	if not has_pin():
		return "ok"
	if now_unix_ms - pin_fail_unix_ms < Pin.delay_ms(pin_fails):
		return "wait"
	var m := Pin.master(pin, pin_salt, pin_iterations)
	if Pin.same(Pin.verifier(m), pin_hash):
		pin_fails = 0
		unlocked_root = Pin.secret_root(m)
		return "ok"
	pin_fails += 1
	pin_fail_unix_ms = now_unix_ms
	return "wrong"


## Сколько ещё ждать до следующей попытки, мс.
func pin_wait_ms(now_unix_ms: int) -> int:
	return maxi(0, Pin.delay_ms(pin_fails) - (now_unix_ms - pin_fail_unix_ms))


## Запомнить место. area — вершины игровой зоны (XRInterface.get_play_area(), координаты stage).
func remember_place(place_name: String, area: PackedVector3Array, work: Transform3D, desk_m: float = 0.0,
		room: String = "") -> int:
	var flat := PackedVector2Array()
	for p in area:
		flat.append(Vector2(p.x, p.z))
	var i := find_place(area, room)
	var rec := {"name": place_name, "area": flat, "work": work, "desk_m": desk_m, "room": room, "anchors": []}
	if i >= 0:
		rec["anchors"] = places[i].get("anchors", [])
		places[i] = rec
		return i
	places.append(rec)
	return places.size() - 1


## Место этой комнаты. Сначала — по ключу комнаты от шлема (UUID пола): он устойчив и не зависит от
## того, отдаёт ли рантайм игровую зону. Потом — по форме зоны. Ни того, ни другого нет (сессия 14:
## «вершин 0») — берётся ПОСЛЕДНЕЕ место: иначе каждое нажатие плодило бы копию.
func find_place(area: PackedVector3Array, room: String = "") -> int:
	if room != "":
		for i in places.size():
			if places[i].get("room", "") == room:
				return i
		# Комната названа, но такой ещё нет — это НОВОЕ место. Иначе «Кухня» затирала бы «Кабинет».
		return -1
	if area.is_empty():
		return places.size() - 1 if not places.is_empty() else -1
	for i in places.size():
		var pts: PackedVector2Array = places[i]["area"]
		if pts.size() != area.size():
			continue
		var same := true
		for k in pts.size():
			if pts[k].distance_to(Vector2(area[k].x, area[k].z)) > PLACE_TOLERANCE_M and not falsify_place_any:
				same = false
				break
		if same:
			return i
	return -1


func save(dir: String) -> Error:
	var cf := ConfigFile.new()
	cf.set_value("profile", "id", id)
	cf.set_value("profile", "name", name)
	cf.set_value("profile", "color", color)
	cf.set_value("profile", "lang", lang)
	cf.set_value("body", "height_cm", height_cm)
	cf.set_value("body", "eye_m", eye_m)
	cf.set_value("body", "stance", stance)
	cf.set_value("body", "dominant", dominant)
	cf.set_value("pin", "salt", pin_salt)
	cf.set_value("pin", "hash", pin_hash)
	cf.set_value("pin", "iterations", pin_iterations)
	cf.set_value("pin", "fails", pin_fails)
	cf.set_value("pin", "fail_unix_ms", pin_fail_unix_ms)
	cf.set_value("places", "list", places)
	cf.set_value("projects", "list", projects)
	cf.set_value("accounts", "list", accounts)
	return cf.save(dir.path_join(FILE))


func load_from(dir: String) -> bool:
	var cf := ConfigFile.new()
	if cf.load(dir.path_join(FILE)) != OK:
		return false
	id = cf.get_value("profile", "id", id)
	name = cf.get_value("profile", "name", name)
	color = cf.get_value("profile", "color", color)
	lang = cf.get_value("profile", "lang", lang)
	height_cm = float(cf.get_value("body", "height_cm", 0.0))
	eye_m = float(cf.get_value("body", "eye_m", 0.0))
	stance = cf.get_value("body", "stance", stance)
	dominant = cf.get_value("body", "dominant", dominant)
	pin_salt = cf.get_value("pin", "salt", PackedByteArray())
	pin_hash = cf.get_value("pin", "hash", PackedByteArray())
	pin_iterations = int(cf.get_value("pin", "iterations", 0))
	pin_fails = int(cf.get_value("pin", "fails", 0))
	pin_fail_unix_ms = int(cf.get_value("pin", "fail_unix_ms", 0))
	places = cf.get_value("places", "list", [])
	projects = cf.get_value("projects", "list", [])
	accounts = cf.get_value("accounts", "list", [])
	return true
