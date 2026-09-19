extends RefCounted

## Модели контроллеров в шар-меню: видны, только пока меню ведут контроллеры.
##
## Сессия 11 (2026-09-19): взятые контроллеры работали, но не были видны вовсе — в иммерсивном
## приложении Quest их сам не рисует. Модель берётся у рантайма: `OpenXRRenderModelManager` Godot 4.7
## (`XR_EXT_render_model`, настройка `xr/openxr/extensions/render_model`; манифест для Meta —
## `xr/openxr/extensions/meta/render_model`). Перечислит ли рантайм это расширение, не проверено:
## в сессиях 4–6 он не перечислил ни его, ни `XR_FB_render_model`, вероятно из-за манифеста
## (ADR-0009). Поэтому запасной вариант: если модель не пришла за FALLBACK_MS после того, как
## контроллеры взяли управление, показывается простая модель на позе grip. Какая показана — в журнал.

## Сколько ждать модель рантайма, мс. Не измерение — терпение пользователя: дольше контроллер
## висит невидимым.
const FALLBACK_MS := 3000

var manager: Node3D
var fallback: Array[XRController3D] = []
var active := false
## Сколько моделей отдал рантайм (сигнал render_model_added).
var runtime_models := 0
## "" — ещё не решено; "рантайм" | "запасные".
var kind := ""
var _since_ms := -1


func setup(origin: Node3D) -> void:
	if ClassDB.class_exists("OpenXRRenderModelManager"):
		manager = ClassDB.instantiate("OpenXRRenderModelManager")
		manager.name = "ControllerModels"
		origin.add_child(manager)
		manager.connect("render_model_added", func(_m): runtime_models += 1)
		manager.connect("render_model_removed", func(_m): runtime_models = maxi(runtime_models - 1, 0))
	for side in ["left_hand", "right_hand"]:
		var c := XRController3D.new()
		c.tracker = side
		c.pose = &"grip"
		c.name = "FallbackModel_" + side
		origin.add_child(c)
		c.add_child(_fallback_mesh())
		fallback.append(c)
	set_active(false, 0)


## Рукоять и кольцо — чтобы было видно, где контроллер и куда он смотрит.
func _fallback_mesh() -> Node3D:
	var root := Node3D.new()
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


func set_active(on: bool, now_ms: int) -> void:
	active = on
	_since_ms = now_ms if on else -1
	if manager != null:
		manager.visible = on
	_show_fallback(on and kind == "запасные")


## Кадр: решить, нужна ли запасная модель. Возвращает "рантайм" | "запасные" в кадре, когда
## решение принято (для журнала), иначе "".
func update(now_ms: int) -> String:
	if not active or kind != "":
		return ""
	if runtime_models > 0:
		kind = "рантайм"
		return kind
	if _since_ms >= 0 and now_ms - _since_ms >= FALLBACK_MS:
		kind = "запасные"
		_show_fallback(true)
		return kind
	return ""


func _show_fallback(on: bool) -> void:
	for c in fallback:
		c.visible = on


func anything_visible() -> bool:
	if manager != null and manager.visible:
		return true
	for c in fallback:
		if c.visible:
			return true
	return false
