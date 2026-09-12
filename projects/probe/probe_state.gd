extends RefCounted
class_name ProbeState

## Снимок всего, что могло измениться между частотами.
##
## Загадка прогона 5: на 120 Гц один draw call для GPU подешевел вдвое, а база
## пустой сцены при этом ПОДОРОЖАЛА. Прежде чем объяснять это разгоном или
## фовеацией, надо узнать, не поменялось ли под нами что-то более простое:
## разрешение буфера глаза, уровень фовеации, MSAA, масштаб рендера.
##
## Правило вердикта записано ДО прогона (PRACTICES §1.1): если ни одно из этих
## чисел между 72 и 120 Гц не изменилось — объяснения через фовеацию и через
## разрешение ИСКЛЮЧЕНЫ, и это утверждение, а не отсутствие данных.
##
## Побочно: разрешение буфера глаза нигде в проекте не записано, а без него
## цену пикселя не с чем соотносить.

const ProbeReport := preload("res://probe_report.gd")

## Ключи, по которым сравниваются два снимка. Список один на всё: и сравнение,
## и печать идут по нему, чтобы добавленное поле нельзя было забыть сравнить
## (PRACTICES §1.8).
const COMPARED := [
	"render_target_size",
	"render_target_multiplier",
	"foveation_supported",
	"foveation_level",
	"foveation_dynamic",
	"foveation_subsampled",
	"msaa_3d",
	"scaling_3d_scale",
	"vrs_mode",
	"viewport_size",
]


static func _iface() -> XRInterface:
	return XRServer.find_interface("OpenXR")


static func _prop(obj, prop: String, fallback):
	if obj == null:
		return fallback
	var v = obj.get(prop)
	return fallback if v == null else v


## Снимок. Всё, чего не удалось спросить, помечается строкой «неизвестно», а не
## нулём: ноль неотличим от настоящего нуля.
static func snapshot(viewport: Viewport) -> Dictionary:
	var d := {}
	var i := _iface()

	if i != null and i.has_method("get_render_target_size"):
		var s: Vector2 = i.get_render_target_size()
		d["render_target_size"] = "%dx%d" % [int(s.x), int(s.y)]
		d["render_target_px"] = int(s.x) * int(s.y)
	else:
		d["render_target_size"] = "неизвестно"
		d["render_target_px"] = 0

	d["render_target_multiplier"] = _prop(i, "render_target_size_multiplier", "неизвестно")
	d["foveation_supported"] = (i.is_foveation_supported()
			if i != null and i.has_method("is_foveation_supported") else "неизвестно")
	d["foveation_level"] = _prop(i, "foveation_level", "неизвестно")
	d["foveation_dynamic"] = _prop(i, "foveation_dynamic", "неизвестно")
	d["foveation_subsampled"] = _prop(i, "foveation_with_subsampled_images", "неизвестно")

	if viewport != null:
		d["msaa_3d"] = viewport.msaa_3d
		d["scaling_3d_scale"] = viewport.scaling_3d_scale
		d["vrs_mode"] = viewport.vrs_mode
		d["viewport_size"] = "%dx%d" % [int(viewport.size.x), int(viewport.size.y)]
	else:
		for k in ["msaa_3d", "scaling_3d_scale", "vrs_mode", "viewport_size"]:
			d[k] = "неизвестно"
	return d


## Чем два снимка отличаются. Пустой массив — не отличаются ничем.
static func diff(a: Dictionary, b: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for k in COMPARED:
		var va = a.get(k, "нет поля")
		var vb = b.get(k, "нет поля")
		if str(va) != str(vb):
			out.append("%s: %s → %s" % [k, va, vb])
	return out


static func brief(d: Dictionary) -> String:
	return "буфер глаза %s (%.2f Мпикс), множитель %s, фовеация %s/динамика %s, MSAA %s, масштаб %s, VRS %s" % [
			d.get("render_target_size", "?"),
			float(d.get("render_target_px", 0)) / 1000000.0,
			str(d.get("render_target_multiplier", "?")),
			str(d.get("foveation_level", "?")),
			str(d.get("foveation_dynamic", "?")),
			str(d.get("msaa_3d", "?")),
			str(d.get("scaling_3d_scale", "?")),
			str(d.get("vrs_mode", "?")),
	]


func expected_checks() -> int:
	# снимок получен 1, фовеация названа явно 1
	return 2


## Первичный снимок и разбор фовеации. Сравнение снимков между частотами делает
## фаза матрицы — здесь только исходное состояние.
func run(viewport: Viewport, r: ProbeReport) -> Dictionary:
	r.note("")
	r.note("--- S. Состояние рендера ---")
	var d := snapshot(viewport)
	r.note(brief(d))

	if d.get("render_target_px", 0) > 0:
		r.pass_("снимок состояния: получен, буфер глаза %s" % d["render_target_size"])
	else:
		r.unkn("снимок состояния: размер буфера глаза не получен, сравнивать ступени будет нечем")

	# Фовеация — не «не критично», а прямая проверка живой гипотезы, поэтому
	# формулируется утверждением, которое можно опровергнуть.
	var lvl = d.get("foveation_level", "неизвестно")
	var dyn = d.get("foveation_dynamic", "неизвестно")
	if lvl is int and lvl == 0 and dyn is bool and not dyn:
		r.pass_("фовеация ВЫКЛЮЧЕНА (уровень 0, динамика off) — объяснение аномалии 120 Гц через DFR отпадает, если так же на обеих ступенях")
	elif lvl is int:
		r.fail("фовеация ВКЛЮЧЕНА: уровень %d, динамика %s — она переменная измерения, и её надо зафиксировать" % [lvl, dyn])
	else:
		r.unkn("фовеация: состояние не прочитать")
	return d
