extends RefCounted

## Кому принадлежит предмет и что комната помнит о своём содержимом (решение владельца 2026-09-23).
##
## Задача. Предмет, взятый в подгружаемой комнате и вынесенный наружу, не должен выгружаться вместе
## с ней; принесённый в комнату и оставленный там — должен. У каждой комнаты свой набор.
##
## И комната обязана ПОМНИТЬ содержимое. Без памяти она строится из JSON заново при каждом входе, и
## вынесенный куб появляется вторым — то есть перенос предметов без памяти хуже, чем его отсутствие.
##
## Здесь только строки, словари и координаты: узлов этот файл не знает вовсе — тот же довод, что у
## `world/level_stream.gd` и `world/visibility.gd`. Связь «uuid ↔ узел» держит вызывающий
## (`main.gd`), геометрию зоны считает `in_box` на значениях. Поэтому всё решение проверяется
## настольно, без сцены, и прибор гоняет тот самый код, которым пользуется приложение.
##
## **Память живёт сеанс.** Запись содержимого комнат в файл — это уже формат проекта, и он требует
## отдельного ADR (следующий свободный номер — 0014). Пока его нет, выход из приложения возвращает
## уровень к данным, и это сказано вслух, а не подразумевается.

## Фальсификатор «roomkeeps»: вынесенный предмет остаётся за комнатой — возвращается дефект, ради
## которого всё и делается.
var falsify_room_keeps := false
## Фальсификатор «roomlost»: принесённый в комнату предмет комнате не достаётся и с ней не уходит.
var falsify_room_lost := false
## Фальсификатор «onebucket»: у комнат один общий набор на всех — предмет, оставленный в одной,
## выгружается вместе с любой другой.
var falsify_one_bucket := false
## Фальсификатор «takenagain»: вынесенное не исключается из постройки — при возврате в комнату
## предмет появляется вторым.
var falsify_rebuild_taken := false
## Фальсификатор «shelfback»: комната отдаёт место из данных, а не запомненное, — оставленный на
## полу предмет возвращается на полку.
var falsify_shelf_back := false
## Фальсификатор «edgeout»: точка ровно на грани зоны считается снаружи.
static var falsify_edge_out := false
## Фальсификатор «handdrops»: обход не считает занятым ничего — предмет выгружается прямо из руки
## человека, и рука остаётся с мёртвым узлом.
static var falsify_hand_drops := false

## uuid → файл, который ОПРЕДЕЛЯЕТ объект в данных. Не меняется никогда: по нему решается, кого
## файл не должен строить заново.
var home: Dictionary = {}
## uuid → файл, который СЕЙЧАС его выгружает. Меняется при каждом «положили».
var owner: Dictionary = {}
## uuid → копия словаря объекта. Одна на сеанс: предмет кочует по комнатам, а описание у него одно.
var source: Dictionary = {}
## файл → {uuid → {"pos": Vector3, "rot": Vector3}} — что комната помнит о своём содержимом.
var memory: Dictionary = {}


## Ключ набора. Отдельной функцией ровно затем, чтобы «у каждой комнаты свой» имело фальсификатор:
## иначе это свойство нечем было бы опровергнуть.
func _bucket(file: String) -> String:
	return "ВСЕ" if falsify_one_bucket else file


## Запомнить объект, который построил файл. `entry` — запись из `LevelLoader.build().index`:
## нужны `uuid` и `obj`.
##
## `home` ставится только раз: комната, восстановившая принесённый чужой предмет, не становится его
## родиной — иначе вынесенный обратно предмет перестал бы строиться в своём исходном файле.
func register(file: String, entry: Dictionary) -> void:
	var uuid := str(entry.get("uuid", ""))
	if uuid == "":
		return
	if not home.has(uuid):
		home[uuid] = file
	owner[uuid] = file
	var obj: Variant = entry.get("obj", null)
	if obj is Dictionary and not source.has(uuid):
		source[uuid] = (obj as Dictionary).duplicate(true)


func owner_of(uuid: String) -> String:
	return str(owner.get(uuid, ""))


## Предмет положили. `zone_file` — комната, в зоне которой он оказался, или «» (ничья земля, то есть
## основная сцена). Единственное место, где владелец меняется по намерению человека.
##
## Возвращает {uuid, from, to, changed} — вызывающему надо знать, какие наборы править.
func settle(uuid: String, zone_file: String, main_file: String) -> Dictionary:
	var from := owner_of(uuid)
	var to := zone_file if zone_file != "" else main_file
	if falsify_room_keeps and from != main_file and to == main_file:
		to = from
	if falsify_room_lost and to != main_file:
		to = from
	if from == "" or to == from:
		return {"uuid": uuid, "from": from, "to": from, "changed": false}
	owner[uuid] = to
	return {"uuid": uuid, "from": from, "to": to, "changed": true}


## Кого файл определяет в данных, но уже не выгружает, — тех при постройке пропускать.
##
## Две причины попасть сюда, и обе обязаны быть: предмет вынесли (владеет другой файл) либо предмет
## лежит в памяти комнаты (его построит `recall`, и из данных он вышел бы вторым экземпляром).
func skipped(file: String) -> Dictionary:
	var out := {}
	if falsify_rebuild_taken:
		return out
	var kept: Dictionary = memory.get(_bucket(file), {})
	for uuid in home:
		if str(home[uuid]) != file:
			continue
		if owner_of(str(uuid)) != file or kept.has(uuid):
			out[uuid] = true
	return out


## Содержимое комнаты, которое надо построить сверх данных: и свои сдвинутые, и чужие принесённые.
## Описание берётся из `source`, место — из памяти.
func recall(file: String) -> Array:
	var out: Array = []
	var kept: Dictionary = memory.get(_bucket(file), {})
	for uuid in kept:
		if not source.has(uuid):
			continue
		var obj: Dictionary = (source[uuid] as Dictionary).duplicate(true)
		if not falsify_shelf_back:
			var where: Dictionary = kept[uuid]
			var p: Vector3 = where["pos"]
			var rot: Vector3 = where["rot"]
			obj["pos"] = [p.x, p.y, p.z]
			obj["rot"] = [rot.x, rot.y, rot.z]
		out.append(obj)
	return out


## Что делать с подвижным содержимым выгружаемой комнаты.
##
## `items` — по одному на предмет: {uuid, pos: Vector3, rot: Vector3, busy: bool, inside: bool}.
## `busy` — узел в руке или в полёте, `inside` — он внутри зоны этой комнаты.
##
## Решение целиком здесь, а не в вызывающем: тогда прибор проверяет тот самый код, которым
## пользуется приложение (довод `Visibility.apply_to`). Вызывающему остаётся сантехника.
##
## Занятый не выгружается НИКОГДА — правило сильнее геометрии. Человек, держащий предмет, стоя в
## дверях, не должен обнаружить пустую руку: ровно так `grab.update` и падал на освобождённом узле.
func unload_plan(file: String, main_file: String, items: Array) -> Dictionary:
	var keep: Array = []
	var free_list: Array = []
	var kept := {}
	for it in items:
		var rec: Dictionary = it
		var uuid := str(rec.get("uuid", ""))
		if uuid == "":
			continue
		if bool(rec.get("busy", false)) or not bool(rec.get("inside", true)):
			keep.append(uuid)
			owner[uuid] = main_file
			continue
		free_list.append(uuid)
		owner[uuid] = file
		kept[uuid] = {"pos": rec.get("pos", Vector3.ZERO), "rot": rec.get("rot", Vector3.ZERO)}
	# Память файла переписывается целиком: остатки прошлой выгрузки иначе воскресали бы предметы,
	# которых в комнате давно нет.
	memory[_bucket(file)] = kept
	return {"keep": keep, "free": free_list}


## Точка внутри коробки зоны. Чистая арифметика на значениях: узел вне дерева сцены отдаёт мировое
## (0,0,0) при любом положении (ловушка 37), и проверять геометрию через `Area3D` настольно нечем.
##
## Грань принадлежит КОМНАТЕ (сравнение нестрогое). Ящик зоны обведён по стенам, и куб, приставленный
## к стене, разумнее выгрузить вместе со стеной, чем оставить висеть в воздухе посреди улицы.
static func in_box(center: Vector3, size: Vector3, basis: Basis, point: Vector3) -> bool:
	var half := size * 0.5
	var local := basis.inverse() * (point - center)
	if falsify_edge_out:
		return absf(local.x) < half.x and absf(local.y) < half.y and absf(local.z) < half.z
	return absf(local.x) <= half.x and absf(local.y) <= half.y and absf(local.z) <= half.z


## Форма зоны — у ПЕРВОГО дочернего `CollisionShape3D`, а не у ребёнка с номером 0: у триггера
## вторым ребёнком висит видимая коробка (`world/trigger_view.gd`), и опора на номер сломалась бы
## от любой перестановки.
static func zone_has(area: Area3D, point: Vector3) -> bool:
	if area == null or not is_instance_valid(area):
		return false
	for child in area.get_children():
		var cs := child as CollisionShape3D
		if cs == null:
			continue
		var box := cs.shape as BoxShape3D
		if box == null:
			continue
		var xf := area.global_transform * cs.transform
		return in_box(xf.origin, box.size, xf.basis, point)
	return false


## Снять с ЖИВЫХ узлов ровно то, что нужно решению: где предмет, занят ли он человеком и внутри ли
## он зоны своей комнаты. `busy` — вопрос вызывающему: «этот в руке или в полёте?».
##
## Живёт здесь, а не в вызывающем, по той же причине, что и `unload_plan`: прибор обязан снимать
## показания тем же кодом, которым их снимает приложение. Иначе проверка подтверждала бы свою копию
## (урок ловушки 33).
##
## Место — ЛОКАЛЬНОЕ и в градусах: ровно в таком виде его кладёт загрузчик, и память обязана
## говорить с ним на одном языке. Зона спрашивается по МИРОВОЙ точке — она в мире и стоит.
static func survey(entries: Array, zone: Area3D, busy: Callable) -> Array:
	var out: Array = []
	for e in entries:
		var entry: Dictionary = e
		var node := entry.get("node", null) as Node3D
		if node == null or not is_instance_valid(node) or not node.is_in_group("grab"):
			continue
		out.append({"uuid": str(entry.get("uuid", "")), "node": node, "pos": node.position,
				"rot": node.rotation * (180.0 / PI),
				"busy": not falsify_hand_drops and bool(busy.call(node)),
				"inside": zone_has(zone, node.global_position)})
	return out


## В какой комнате точка. `zones` — {файл → Area3D}. «» — ни в какой, то есть основная сцена.
## Зоны перекрылись — побеждает первая по порядку: сегодня зона одна, и правило записано, чтобы
## следующий не гадал.
static func file_at(zones: Dictionary, point: Vector3) -> String:
	for file in zones:
		if zone_has(zones[file] as Area3D, point):
			return str(file)
	return ""
