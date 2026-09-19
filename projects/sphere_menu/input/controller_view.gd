extends RefCounted

## Модели контроллеров в шар-меню: видны, только пока меню ведут контроллеры.
##
## В иммерсивном приложении Quest сам контроллеры не рисует — это работа приложения, но модели отдаёт
## рантайм. Кандидаты, по порядку:
##   FB  — `XR_FB_render_model`, настоящие glTF-модели Meta: узел плагина вендоров
##         `OpenXRFbRenderModel` на позе grip. Манифест (разрешение и фича RENDER_MODEL) пишет плагин
##         по `xr/openxr/extensions/meta/render_model`; без них расширение не перечислялось (ADR-0009);
##   EXT — `XR_EXT_render_model` Khronos через `OpenXRRenderModelManager` Godot 4.7. Поддержка
##         рантаймом Meta не подтверждена.
## Если ни одна модель не пришла за FALLBACK_MS после того, как контроллеры взяли управление, видна
## запасная — рукоять с кольцом. Пришла позже — запасная прячется. Что видно — в журнал.
##
## Сессия 12 (2026-09-19): видна была только запасная, и включилась она сразу — отсчёт шёл от 0, а
## не от момента, когда контроллеры взяли управление.

## Сколько ждать модель рантайма, мс. Не измерение — терпение пользователя: дольше контроллер
## висит невидимым.
const FALLBACK_MS := 3000

var manager: Node3D
## Узлы на позе grip, по одному на руку: в каждом модель FB (если класс есть) и запасная.
var grips: Array[XRController3D] = []
var fb_models: Array[Node3D] = []
var fallback: Array[Node3D] = []
var active := false
## Какая модель рантайма пришла: "" | "FB" | "EXT".
var runtime_kind := ""
## Что показано: "" — ещё не решено; "FB" | "EXT" | "запасные".
var kind := ""
## Фальсификатор «fallbacknow»: отсчёт до запасной — от 0, как в сессии 12.
var falsify_since_zero := false
## Фальсификатор «fallbackstays»: пришедшая модель рантайма не прячет запасную.
var falsify_fallback_stays := false
var _since_ms := -1
var _events: Array[String] = []


func setup(origin: Node3D) -> void:
	if ClassDB.class_exists("OpenXRRenderModelManager"):
		manager = ClassDB.instantiate("OpenXRRenderModelManager")
		manager.name = "ControllerModelsExt"
		origin.add_child(manager)
		manager.connect("render_model_added", func(_m): on_runtime_loaded("EXT"))
	var has_fb := ClassDB.class_exists("OpenXRFbRenderModel")
	for side in ["left", "right"]:
		var c := XRController3D.new()
		c.tracker = side + "_hand"
		c.pose = &"grip"
		c.name = "ControllerModel_" + side
		origin.add_child(c)
		grips.append(c)
		if has_fb:
			var m: Node3D = ClassDB.instantiate("OpenXRFbRenderModel")
			m.set("render_model_type", ClassDB.class_get_integer_constant("OpenXRFbRenderModel",
					"MODEL_CONTROLLER_LEFT" if side == "left" else "MODEL_CONTROLLER_RIGHT"))
			m.connect("openxr_fb_render_model_loaded", func(): on_runtime_loaded("FB"))
			c.add_child(m)
			fb_models.append(m)
		var fb := _fallback_mesh()
		c.add_child(fb)
		fallback.append(fb)
	set_active(false, Time.get_ticks_msec())


## Рукоять и кольцо — чтобы было видно, где контроллер и куда он смотрит.
func _fallback_mesh() -> Node3D:
	var root := Node3D.new()
	root.name = "Fallback"
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.25, 0.27, 0.3)
	var grip := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.018
	cap.height = 0.11
	grip.mesh = cap
	grip.material_override = mat
	grip.rotation = Vector3(deg_to_rad(-60.0), 0, 0)
	root.add_child(grip)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.03
	torus.outer_radius = 0.038
	ring.mesh = torus
	ring.material_override = mat
	ring.position = Vector3(0, 0.03, -0.04)
	root.add_child(ring)
	return root


## Контроллеры взяли или отдали управление. now_ms — момент этого, от него отсчёт до запасной.
func set_active(on: bool, now_ms: int) -> void:
	active = on
	_since_ms = (0 if falsify_since_zero else now_ms) if on else -1
	if manager != null:
		manager.visible = on
	for m in fb_models:
		m.visible = on
	_show_fallback(on and kind == "запасные")


## Модель рантайма загрузилась (сигнал узла; проверки зовут напрямую). Была запасная — прячется.
func on_runtime_loaded(which: String) -> void:
	if runtime_kind != "":
		return
	runtime_kind = which
	if kind == "запасные":
		kind = which
		_events.append("запасные → " + which)
		if not falsify_fallback_stays:
			_show_fallback(false)


## Кадр: решить, что показывать. Возвращает запись для журнала в кадре, когда решение принято или
## сменилось, иначе "".
func update(now_ms: int) -> String:
	if not _events.is_empty():
		return _events.pop_front()
	if not active or kind != "":
		return ""
	if runtime_kind != "":
		kind = runtime_kind
		return kind
	if _since_ms >= 0 and now_ms - _since_ms >= FALLBACK_MS:
		kind = "запасные"
		_show_fallback(true)
		return kind
	return ""


func _show_fallback(on: bool) -> void:
	for f in fallback:
		f.visible = on


func fallback_visible() -> bool:
	for f in fallback:
		if f.visible:
			return true
	return false


func anything_visible() -> bool:
	if manager != null and manager.visible:
		return true
	for m in fb_models:
		if m.visible:
			return true
	return fallback_visible()
