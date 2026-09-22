extends RefCounted

## Учёт видимости: слои, группы и отдельные объекты (решение владельца 2026-09-21).
##
## Здесь только состояние и арифметика — узлов этот файл не знает вовсе, поэтому проверяется
## настольно. Кто прячет узлы, решает вызывающий: слои — маской камеры (`world/layers.gd`), группы
## и объекты — `visible` у видимой части, чтобы коллайдер остался на месте.
##
## **Режим игры** снимает снимок и показывает только то, что видит игрок; выход возвращает ровно
## то, что было, включая объекты, скрытые поимённо до запуска. В настройки режим не пишет: на диске
## остаются редакторские значения, и аварийное закрытие в режиме игры ничего не теряет.

const Layers := preload("res://world/layers.gd")

## Фальсификатор «grouporany»: объект видим, если видима ХОТЬ ОДНА его группа. Тогда скрытие группы
## не работает для объектов, состоящих сразу в двух.
var falsify_group_or := false
## Фальсификатор «playmask»: маска камеры не смотрит на режим игры — игрок видит инструментарий.
var falsify_play_mask := false
## Фальсификатор «groupfree»: скрытие группы гасит и столкновения — сквозь спрятанный объект можно
## пройти, и уровень в редакторе перестаёт держать человека.
var falsify_group_free := false
## Фальсификатор «snapshotref»: снимок держит ссылки на живые словари вместо копий — «возврат»
## возвращает то, что уже изменено, то есть ничего.
var falsify_snapshot_ref := false

## Слой → показан ли. Бит игры включён всегда (world/layers.gd), тут его нет.
var layer_on := {"editor": true, "debug": false}
## Имя группы → показана ли. Нет ключа — показана.
var group_on: Dictionary = {}
## uuid объекта → показан ли. Нет ключа — показан.
var object_on: Dictionary = {}
## uuid → {layer, groups}
var index: Dictionary = {}
var playing := false


## Запомнить объект уровня: {uuid, layer, groups}.
func register(entry: Dictionary) -> void:
	var uuid := str(entry.get("uuid", ""))
	if uuid == "":
		return
	index[uuid] = {"layer": str(entry.get("layer", Layers.DEFAULT)),
			"groups": (entry.get("groups", []) as Array).duplicate()}


## Забыть объекты выгруженной части уровня.
func forget(uuids: Array) -> void:
	for uuid in uuids:
		index.erase(uuid)


## Все группы уровня, по одному разу, по алфавиту.
func group_names() -> Array:
	var seen := {}
	for uuid in index:
		for g in index[uuid]["groups"]:
			seen[str(g)] = true
	var out := seen.keys()
	out.sort()
	return out


## Видим ли объект: он сам не скрыт И ни одна его группа не скрыта.
## «Скрыта любая» — потому что скрытие это запрет: спрятал «пивоты», значит пивот не должен
## всплывать оттого, что он ещё и «реквизит».
func is_visible(uuid: String) -> bool:
	if not bool(object_on.get(uuid, true)):
		return false
	var groups: Array = index.get(uuid, {}).get("groups", [])
	if groups.is_empty():
		return true
	if falsify_group_or:
		for g in groups:
			if bool(group_on.get(str(g), true)):
				return true
		return false
	for g in groups:
		if not bool(group_on.get(str(g), true)):
			return false
	return true


## Маска камеры для нынешнего состояния.
func camera_mask() -> int:
	if playing and not falsify_play_mask:
		return Layers.play_mask()
	return Layers.mask(layer_on)


## Применить нынешнее состояние к сцене: маска — камере, `visible` — узлам объектов.
## Возвращает, сколько узлов скрыто.
##
## Живёт здесь, а не в main.gd, чтобы прибор проверял тот же код, которым пользуется приложение.
## Скрывается ТОЛЬКО видимая часть: коллайдер остаётся на месте, иначе уровень в редакторе
## переставал бы держать человека там, где он спрятал группу.
func apply_to(cam: Camera3D, files: Dictionary) -> int:
	if cam != null and is_instance_valid(cam):
		cam.cull_mask = camera_mask()
	var hidden := 0
	for file in files:
		for entry in files[file]:
			var node: Node = entry.get("node", null)
			if node == null or not is_instance_valid(node) or not (node is Node3D):
				continue
			var on := is_visible(str(entry["uuid"]))
			(node as Node3D).visible = on
			if falsify_group_free and node is CollisionObject3D:
				(node as CollisionObject3D).collision_layer = 1 if on else 0
			if not on:
				hidden += 1
	return hidden


## Снимок состояния — копиями, а не ссылками.
func snapshot() -> Dictionary:
	if falsify_snapshot_ref:
		return {"layers": layer_on, "groups": group_on, "objects": object_on}
	return {"layers": layer_on.duplicate(true), "groups": group_on.duplicate(true),
			"objects": object_on.duplicate(true)}


func restore(snap: Dictionary) -> void:
	layer_on = (snap.get("layers", {}) as Dictionary).duplicate(true)
	group_on = (snap.get("groups", {}) as Dictionary).duplicate(true)
	object_on = (snap.get("objects", {}) as Dictionary).duplicate(true)


## Войти в режим игры: вернуть снимок, показать всё игровое.
func enter_play() -> Dictionary:
	var snap := snapshot()
	playing = true
	# Инструментарий автора игроку не нужен, а вот объекты игры он должен видеть все: скрытое в
	# редакторе — это заметки автора, а не часть уровня.
	for uuid in index:
		if index[uuid]["layer"] == Layers.DEFAULT:
			object_on.erase(uuid)
	for g in group_on.keys():
		group_on[g] = true
	return snap


func exit_play(snap: Dictionary) -> void:
	playing = false
	restore(snap)
