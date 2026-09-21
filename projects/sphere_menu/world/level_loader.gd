extends RefCounted

## Загрузчик уровня из данных (этап Ф3). Схема — будущая `scenes/*.json` формата проекта (этап 3),
## поэтому переписывать загрузчик потом не придётся.
##
## Объект: uuid, тип, положение, поворот (градусы), размер, цвет, тело (static | grab | none) и метки
## (climb — за это лазают, interior — подгружается по триггеру). Из типа «stairs» строится лесенка,
## из «trigger» — зона подгрузки, «spawn» — точка старта.
##
## Материалы общие на ЦВЕТ, а не на объект: цена отрисовки измерена по вызовам (4.04 мкс на вызов,
## паспорт), и число материалов важнее числа кубов.

const TYPES := ["box", "stairs", "trigger", "spawn", "sign", "ledge"]
## Подсказка в мире: высота символов по умолчанию, м.
const SIGN_SIZE := 0.08
## Высота и глубина ступени по умолчанию, м.
const STEP_RISE := 0.18
const STEP_RUN := 0.30

## Фальсификатор «levelany»: незнакомые типы и битые размеры пропускаются — уровень строится из мусора.
static var falsify_any := false
## Фальсификатор «levelflat»: каждому объекту свой материал — число вызовов отрисовки растёт вместе
## с числом кубов (цена вызова измерена: 4.04 мкс, паспорт).
static var falsify_per_object_material := false


## Разобрать текст уровня. Возвращает {ok, error, data}.
static func parse(text: String) -> Dictionary:
	var d: Variant = JSON.parse_string(text)
	if not d is Dictionary:
		return {"ok": false, "error": "не JSON-объект", "data": {}}
	var data: Dictionary = d
	if int(data.get("format", 0)) != 1:
		return {"ok": false, "error": "версия формата %s, ожидалась 1" % data.get("format", "нет"), "data": {}}
	var objects: Variant = data.get("objects", null)
	if not objects is Array:
		return {"ok": false, "error": "нет списка объектов", "data": {}}
	for o in objects:
		var err := _check(o)
		if err != "" and not falsify_any:
			return {"ok": false, "error": err, "data": {}}
	return {"ok": true, "error": "", "data": data}


static func _check(o: Variant) -> String:
	if not o is Dictionary:
		return "объект не словарь"
	var obj: Dictionary = o
	var type_name := str(obj.get("type", ""))
	if not type_name in TYPES:
		return "неизвестный тип «%s»" % type_name
	if type_name == "spawn":
		return "" if obj.has("pos") else "у точки старта нет положения"
	if type_name == "ledge":
		# Кромка для перевала (Assisted Mantle): зона захвата и точка приземления. Без точки
		# приземления зона бесполезна — человека некуда ставить, поэтому это отказ, а не умолчание.
		if not obj.has("pos") or not obj.has("size"):
			return "у кромки нет положения или размера"
		if not obj.has("target") and not falsify_any:
			return "у кромки «%s» нет точки приземления (target)" % str(obj.get("uuid", ""))
		for v in obj["size"]:
			if float(v) <= 0.0:
				return "нулевой размер у кромки"
		return ""
	if type_name == "sign":
		if not obj.has("pos"):
			return "у подсказки нет положения"
		return "" if str(obj.get("text", "")) != "" else "у подсказки нет текста"
	if not obj.has("pos") or not obj.has("size"):
		return "у объекта «%s» нет положения или размера" % type_name
	for v in obj["size"]:
		if float(v) <= 0.0:
			return "нулевой размер у «%s»" % type_name
	return ""


static func _v3(a: Variant, fallback := Vector3.ZERO) -> Vector3:
	if not a is Array or (a as Array).size() < 3:
		return fallback
	return Vector3(float(a[0]), float(a[1]), float(a[2]))


## Построить уровень под parent. Возвращает {nodes, spawn: Transform3D, triggers: [{area, file}],
## colors: сколько материалов}.
static func build(parent: Node3D, data: Dictionary) -> Dictionary:
	var out := {"nodes": [], "spawn": Transform3D(), "triggers": [], "colors": 0}
	var materials := {}
	for o in data.get("objects", []):
		var obj: Dictionary = o
		match str(obj.get("type", "")):
			"spawn":
				var yaw := float(obj.get("yaw", 0.0))
				out["spawn"] = Transform3D(Basis(Vector3.UP, deg_to_rad(yaw)), _v3(obj.get("pos")))
			"trigger":
				var area := Area3D.new()
				area.name = "Trigger_" + str(obj.get("uuid", ""))
				area.position = _v3(obj.get("pos"))
				var cs := CollisionShape3D.new()
				var box := BoxShape3D.new()
				box.size = _v3(obj.get("size"), Vector3.ONE)
				cs.shape = box
				area.add_child(cs)
				parent.add_child(area)
				out["nodes"].append(area)
				out["triggers"].append({"area": area, "file": str(obj.get("loads", ""))})
			"ledge":
				out["nodes"].append(_ledge(parent, obj))
			"sign":
				out["nodes"].append(_sign(parent, obj))
			"stairs":
				_stairs(parent, obj, materials, out)
			_:
				out["nodes"].append(_box(parent, obj, _v3(obj.get("pos")), _v3(obj.get("size"), Vector3.ONE), materials))
	out["colors"] = materials.size()
	return out


## Лесенка из ступеней: подъём и глубина ступени постоянны, число — из размера.
static func _stairs(parent: Node3D, obj: Dictionary, materials: Dictionary, out: Dictionary) -> void:
	var size := _v3(obj.get("size"), Vector3.ONE)
	var pos := _v3(obj.get("pos"))
	var rise := float(obj.get("rise", STEP_RISE))
	var run := float(obj.get("run", STEP_RUN))
	var count := maxi(1, int(round(size.y / rise)))
	for i in count:
		var step_size := Vector3(size.x, rise, run)
		var step_pos := pos + Vector3(0.0, rise * (i + 0.5), -run * i)
		out["nodes"].append(_box(parent, obj, step_pos, step_size, materials))


static func _box(parent: Node3D, obj: Dictionary, pos: Vector3, size: Vector3, materials: Dictionary) -> Node3D:
	var color := str(obj.get("color", "#8899aa"))
	if falsify_per_object_material:
		color = "%s-%s" % [color, obj.get("uuid", "")]
	if not materials.has(color):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(color.get_slice("-", 0))
		mat.roughness = 0.85
		materials[color] = mat
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = materials[color]
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var body_kind := str(obj.get("body", "static"))
	var body: Node3D = mi
	if body_kind != "none":
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		shape.shape = box
		if body_kind == "grab":
			var rb := RigidBody3D.new()
			rb.add_child(mi)
			rb.add_child(shape)
			rb.add_to_group("grab")
			body = rb
		else:
			var sb := StaticBody3D.new()
			sb.add_child(mi)
			sb.add_child(shape)
			body = sb
	body.name = "Obj_" + str(obj.get("uuid", "")).substr(0, 8)
	body.position = pos
	body.rotation = _v3(obj.get("rot")) * (PI / 180.0)
	for tag in obj.get("tags", []):
		body.add_to_group(str(tag))
	parent.add_child(body)
	return body


## Подсказка в мире (просьба владельца, сессия 17): билборд с ФИКСИРОВАННЫМ местом — стоит у своей
## площадки и всегда повёрнут к человеку. Билборд по вертикали, а не полный: строки не заваливаются
## при наклоне головы.
static func _sign(parent: Node3D, obj: Dictionary) -> Label3D:
	var label := Label3D.new()
	label.name = "Sign_" + str(obj.get("uuid", ""))
	label.text = str(obj.get("text", ""))
	label.position = _v3(obj.get("pos"))
	label.pixel_size = float(obj.get("size", SIGN_SIZE)) / 100.0
	label.font_size = 100
	label.outline_size = 12
	# Разворот — свой (world/sign_face.gd): билборд Godot держит надпись параллельно ПЛОСКОСТИ
	# экрана, то есть крутит её вместе с поворотом шлема, а не поворачивает лицом к человеку
	# (сессия 18).
	label.add_to_group("sign")
	# Подсказка — инструмент, а не часть сцены: её не должен гасить свет уровня.
	label.shaded = false
	label.modulate = Color.html(str(obj.get("color", "#ffe9a8")))
	label.width = float(obj.get("width", 600.0))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label


## Кромка для перевала: зона захвата (Area3D) плюс точка приземления в метаданных.
## Группа «ledge» — по ней перемещение ищет размеченные кромки; зона невидима (её место — на слое
## отладки, когда появятся слои).
static func _ledge(parent: Node3D, obj: Dictionary) -> Area3D:
	var area := Area3D.new()
	area.name = "Ledge_" + str(obj.get("uuid", ""))
	area.position = _v3(obj.get("pos"))
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = _v3(obj.get("size"), Vector3.ONE)
	cs.shape = box
	area.add_child(cs)
	# Зона только для запросов «рука внутри?» — телами не интересуется.
	area.monitoring = false
	area.set_meta("target", _v3(obj.get("target")))
	area.add_to_group("ledge")
	parent.add_child(area)
	return area
