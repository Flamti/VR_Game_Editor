extends Node3D

## Рендер ячеек (слой 7, docs/design/sphere-menu.md §7).
##
## MultiMeshInstance3D на каждое число сторон — 6, 5, 4, 7 (шаг 1г: октаэдр даёт квадраты,
## кольца и спираль — семиугольники); пустые не рисуются, у глобуса два вызова отрисовки. Меш и материал — ресурсы,
## прогретые при загрузке и в XR-формате (ADR-0003 п. 9).
##
## Базис ячейки: Y — нормаль шара, Z — касательная ось, повёрнутая на spin
## (там у меша вершина 0), X = Y × Z. Совпадение этой вершины с вершиной
## ячейки проверяет настольная проверка «ориентация контура». Угол подписи
## считает шейдер (menu/cell.gdshader).
##
## Полный пересчёт — только при смене списка, геометрии или радиуса. Подсветка
## активной, ячейки под лучом и прогресс удержания меняют custom data одной-двух
## ячеек по карте «ключ → экземпляр»: пересчёт 252 ячеек на каждую смену
## активной стоил скриптам 6.65 мс при вращении (самопроверка 2026-09-15).

const HEX := preload("res://menu/hex_mesh.tres")
const PENT := preload("res://menu/pent_mesh.tres")
const QUAD := preload("res://menu/quad_mesh.tres")
const HEPT := preload("res://menu/hept_mesh.tres")
const Surface := preload("res://menu/surface.gd")
const Atlas := preload("res://menu/label_atlas.gd")

## Зазор между ячейками: доля радиуса.
const GAP := 0.9
## Коды цвета (menu/cell.gdshader, KIND_COLORS): 0–7 — Item.Kind, дальше служебные.
const CODE_BACK := 8
const CODE_EMPTY := 9
const CODE_DANGER := 10
const MAX_CELLS := 700

## число сторон → MultiMeshInstance3D
var _by_sides: Dictionary = {}
var drawn := 0
## Сколько раз ячейки пересчитывались полностью — для самопроверки.
var redraws := 0
var _sig_hash := 0
## ключ ячейки → [multimesh, индекс экземпляра, базовый custom]
var _where: Dictionary = {}
var _active: Variant = null
var _hover: Variant = null
var _progress_key: Variant = null
var _progress := 0.0


func setup(atlas: Texture2D) -> void:
	# у спирали и колец дефектов больше двенадцати — ёмкость на все ячейки у каждого вида
	for pair in [[6, HEX], [5, PENT], [4, QUAD], [7, HEPT]]:
		_by_sides[pair[0]] = _make(pair[1], MAX_CELLS)
		((pair[1] as PrimitiveMesh).material as ShaderMaterial).set_shader_parameter("atlas", atlas)


func _make(mesh: Mesh, count: int) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = mesh
	mm.instance_count = count
	mm.visible_instance_count = 0
	# Границы всего шара: иначе отсечение считало бы их по нулевым трансформам.
	mm.custom_aabb = AABB(Vector3(-0.5, -0.5, -0.5), Vector3(1, 1, 1))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	add_child(mmi)
	return mmi


## Нужен ли полный пересчёт. Хэш, а не сравнение массивов: ключи ячеек разного
## типа у глобуса и линзы (int против Vector2i) роняли сравнение `!=` после
## переключения поверхности (самопроверка 2026-09-15, SCRIPT ERROR).
func needs_redraw(sig: Array) -> bool:
	return sig.hash() != _sig_hash


## cells — из surface.render_cells(); codes — слот → код цвета; marks — слот → 1, если отмечен.
func draw(cells: Array, radius: float, cell_radius: float, codes: PackedInt32Array,
		marks: PackedByteArray, sig: Array) -> void:
	_sig_hash = sig.hash()
	redraws += 1
	_where.clear()
	var used := {}
	for k in _by_sides:
		used[k] = 0
	for c in cells:
		var n: Vector3 = c["dir"]
		var s: float = cell_radius * float(c["scale"]) * GAP
		if s <= 0.0005:
			continue
		var a := Vector3.UP if absf(n.y) < 0.9 else Vector3.RIGHT
		var ref := (a - n * a.dot(n)).normalized()
		var z := ref.rotated(n, float(c["spin"]))
		var x := n.cross(z)
		var xf := Transform3D(Basis(x * s, n * s, z * s), n * radius)

		var slot: int = c["slot"]
		var cell := -1.0
		var code := CODE_EMPTY
		var mark := 0.0
		if slot >= 0 and slot < codes.size():
			cell = float(slot) if slot < Atlas.MAX_ITEMS else -1.0
			code = codes[slot]
			mark = 2.0 if slot < marks.size() and marks[slot] == 1 else 0.0
		elif slot == Surface.SLOT_BACK:
			cell = float(Atlas.BACK_INDEX)
			code = CODE_BACK
		var base := Color(cell, mark, float(code) / 20.0, 0.0)

		var sides: int = int(c["sides"])
		if not _by_sides.has(sides):
			sides = clampi(sides, 4, 7)
		var mm: MultiMesh = (_by_sides[sides] as MultiMeshInstance3D).multimesh
		var idx: int = used[sides]
		if idx >= mm.instance_count:
			continue
		used[sides] = idx + 1
		mm.set_instance_transform(idx, xf)
		_where[c["key"]] = [mm, idx, base]
		mm.set_instance_custom_data(idx, _with_state(c["key"], base))
	drawn = 0
	for k in _by_sides:
		(_by_sides[k] as MultiMeshInstance3D).multimesh.visible_instance_count = used[k]
		drawn += int(used[k])


func _with_state(key: Variant, base: Color) -> Color:
	var c := base
	if typeof(key) == typeof(_active) and key == _active:
		c.g += 1.0
	elif typeof(key) == typeof(_hover) and key == _hover:
		c.g += 0.5
	if typeof(key) == typeof(_progress_key) and key == _progress_key:
		c.a = _progress
	return c


func _refresh(key: Variant) -> void:
	if key == null or not _where.has(key):
		return
	var w: Array = _where[key]
	(w[0] as MultiMesh).set_instance_custom_data(w[1], _with_state(key, w[2]))


## Подсветка и прогресс без полного пересчёта.
func set_state(active_key: Variant, hover_key: Variant, progress_key: Variant, progress: float) -> void:
	var touched := [_active, _hover, _progress_key]
	_active = active_key
	_hover = hover_key
	_progress_key = progress_key
	_progress = progress
	touched.append_array([_active, _hover, _progress_key])
	var seen := {}
	for k in touched:
		if k == null:
			continue
		var hk: int = hash(k)
		if seen.has(hk):
			continue
		seen[hk] = true
		_refresh(k)


func clear() -> void:
	_sig_hash = 0
	_where.clear()
	for k in _by_sides:
		(_by_sides[k] as MultiMeshInstance3D).multimesh.visible_instance_count = 0
	drawn = 0
