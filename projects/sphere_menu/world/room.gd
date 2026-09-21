extends Node3D

## Пространственные данные шлема (этап Ф3): комната, которую человек разметил в системе Quest.
##
## Берём их у рантайма, а не выдумываем: `OpenXRFbSceneManager` плагина вендоров
## (`xr/openxr/extensions/meta/scene_api`) отдаёт размеченные сущности — пол, стены, двери, столы,
## а на Quest 3 и общую сетку пространства. Для нас важны две вещи:
##
##   - **пол**: подтверждение, что нулевая высота XR-пространства совпадает с полом комнаты;
##   - **опознание места**: у сущностей есть устойчивые UUID, и место профиля привязывается к UUID
##     пола или комнаты, а не к форме игровой зоны. Сессия 14 показала, почему это нужно: зона у
##     владельца не отдаётся вовсе («вершин 0»), и места стали неразличимы.
##
## Если человек не проходил настройку пространства, приходит сигнал «данных нет» — тогда предлагаем
## запустить её системным запросом (request_scene_capture), но НЕ делаем этого сами: запрос ставит
## приложение на паузу и открывает системный сканер.

## Данные комнаты пришли (или не пришли): detail — строка для журнала.
signal room_known(detail: String)

const MANAGER_CLASS := "OpenXRFbSceneManager"

## Узел менеджера сцен — Node, а НЕ Node3D (проверено ClassDB: OpenXRFbSceneManager → Node).
## Неверный тип уронил запуск на шлеме в сессии 15.
var manager: Node
## uuid → {"type": строка, "position": Vector3}. Пусто — данных нет.
var entities: Dictionary = {}
## Устойчивый ключ комнаты: UUID пола, иначе — первой сущности по алфавиту.
var room_id := ""
var floor_y := NAN
## "нет класса" | "ждём" | "есть" | "нет данных"
var state := "нет класса"


func setup(origin: Node3D) -> void:
	if not ClassDB.class_exists(MANAGER_CLASS):
		state = "нет класса"
		return
	manager = ClassDB.instantiate(MANAGER_CLASS)
	manager.name = "SceneManager"
	origin.add_child(manager)
	state = "ждём"
	if manager.has_signal("openxr_fb_scene_anchor_created"):
		manager.connect("openxr_fb_scene_anchor_created", _on_anchor)
	if manager.has_signal("openxr_fb_scene_data_missing"):
		manager.connect("openxr_fb_scene_data_missing", func():
			state = "нет данных"
			room_known.emit("разметки пространства нет — предложите «Настроить пространство»"))


## Запросить системную разметку пространства. Приложение уходит на паузу, человек сканирует комнату.
func request_capture() -> bool:
	if manager == null or not manager.has_method("request_scene_capture"):
		return false
	manager.request_scene_capture()
	return true


func _on_anchor(entity: Variant, node: Variant) -> void:
	var uuid := ""
	var type_name := ""
	if entity != null and entity.has_method("get_uuid"):
		uuid = str(entity.get_uuid())
	if entity != null and entity.has_method("get_semantic_labels"):
		type_name = str(entity.get_semantic_labels())
	var pos := Vector3.ZERO
	if node is Node3D:
		pos = (node as Node3D).global_position
	entities[uuid] = {"type": type_name, "position": pos}
	if type_name.to_lower().contains("floor"):
		room_id = uuid
		floor_y = pos.y
	elif room_id == "":
		room_id = uuid
	state = "есть"
	room_known.emit("сущностей %d, комната %s, пол на %.2f м" % [entities.size(), room_id.substr(0, 8),
			floor_y if not is_nan(floor_y) else 0.0])


## Опознание места: UUID комнаты, если он есть. Пусто — опознавать нечем.
func place_key() -> String:
	return room_id


func brief() -> String:
	return "%s: сущностей %d, комната %s" % [state, entities.size(), room_id.substr(0, 8) if room_id != "" else "—"]
