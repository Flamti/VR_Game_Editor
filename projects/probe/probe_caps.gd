extends RefCounted
class_name ProbeCaps

const ProbeReport := preload("res://probe_report.gd")

## Фаза A: что железо и движок УМЕЮТ.
##
## Важное различие, которое прибор раньше смешивал:
##   vkEnumerateDeviceExtensionProperties  → «расширение ДОСТУПНО драйверу»;
##   RenderingDevice.has_feature()         → «движок его ВКЛЮЧИЛ и станет использовать».
## Второе — то, на что можно опираться в архитектуре. Первое — лишь потенциал.
## В отчёте они называются разными словами намеренно.

const VULKAN_CONTROL := "VK_KHR_swapchain"
const VULKAN_REQUIRED := [
	"VK_KHR_multiview",
	"VK_KHR_dynamic_rendering",
	"VK_KHR_dynamic_rendering_local_read",
	"VK_KHR_create_renderpass2",
]

## Фовеация реализуется РАЗНЫМИ расширениями на разных архитектурах: тайловые
## GPU дают fragment_density_map, десктопные — fragment_shading_rate.
## Отсутствие одного члена семейства — не отказ, поэтому проверяется наличие
## ХОТЯ БЫ ОДНОГО с указанием, какого именно (PRACTICES §1.4, §3.2).
const VULKAN_FOVEATION_FAMILY := [
	"VK_EXT_fragment_density_map",
	"VK_EXT_fragment_density_map2",
	"VK_KHR_fragment_shading_rate",
	"VK_NV_shading_rate_image",
]

## Вендорский тайловый набор Adreno. Обнаружен прибором 2026-09-12 и оказался
## тем, мимо чего прошло исходное исследование: оно поставило на отсутствующий
## VK_KHR_dynamic_rendering_local_read. Проверяется семейством — важно не
## «есть ли конкретное», а «каким набором вообще располагаем».
const VULKAN_TILE_FAMILY := [
	"VK_QCOM_tile_properties",
	"VK_QCOM_render_pass_store_ops",
	"VK_EXT_load_store_op_none",
	"VK_QCOM_render_pass_shader_resolve",
	"VK_QCOM_render_pass_transform",
	"VK_QCOM_multiview_per_view_viewports",
	"VK_QCOM_multiview_per_view_render_areas",
	"VK_QCOM_fragment_density_map_offset",
]

const VULKAN_FALSIFIER := "VK_VRGE_this_extension_does_not_exist"
const OPENXR_FALSIFIER := "XR_VRGE_this_extension_does_not_exist"
const OPENXR_CONTROL := "XR_KHR_vulkan_enable2"

## Вердикты движка приходят из модуля (VRGEProbe.get_engine_features()), а не
## из RenderingDevice напрямую: метод has_feature() привязан к скриптам, но
## константы самых нужных фич — нет (rendering_device.cpp:9760-9772 биндит
## только RAY_QUERY, RAYTRACING_PIPELINE, BUFFER_DEVICE_ADDRESS,
## IMAGE_ATOMIC_32_BIT, HDR_OUTPUT). Сырые числа вместо имён отвергнуты: при
## смене порядка enum в upstream прибор молча спросил бы не то (§4.4).
##
## Какие из них критичны для VR-рендера — отмечено здесь, чтобы отказ было
## видно как отказ, а не как строку в списке.
const FEATURES_CRITICAL := [
	"SUPPORTS_MULTIVIEW",                  # стерео одним проходом
	"SUPPORTS_ATTACHMENT_VRS",             # фовеация через attachment
	"SUPPORTS_FRAMEBUFFER_DEPTH_RESOLVE",  # resolve глубины на тайле
]

const DEVICE_LIMITS := {
	"MAX_FRAMEBUFFER_WIDTH": RenderingDevice.LIMIT_MAX_FRAMEBUFFER_WIDTH,
	"MAX_FRAMEBUFFER_HEIGHT": RenderingDevice.LIMIT_MAX_FRAMEBUFFER_HEIGHT,
	"MAX_TEXTURE_ARRAY_LAYERS": RenderingDevice.LIMIT_MAX_TEXTURE_ARRAY_LAYERS,
	"MAX_UNIFORM_BUFFER_SIZE": RenderingDevice.LIMIT_MAX_UNIFORM_BUFFER_SIZE,
	"MAX_PUSH_CONSTANT_SIZE": RenderingDevice.LIMIT_MAX_PUSH_CONSTANT_SIZE,
}

var _xr_checks: PackedStringArray = PackedStringArray()
var all_extensions: PackedStringArray = PackedStringArray()


## Пол выводится из тех же массивов, по которым идут циклы (PRACTICES §1.8).
##   контроль vk 1, контроль xr 1, фальсификаторы 2, семейство фовеации 1,
##   семейство тайлов 1, рантайм активен 1, список непуст 1
func expected_checks(probe) -> int:
	_collect_xr_names(probe)
	# +1 — лимит composition layers (свойства системы OpenXR).
	return (1 + 1 + 2 + 1 + 1 + 1 + 1 + 1
			+ VULKAN_REQUIRED.size()
			+ _xr_checks.size()
			+ _engine_feature_count(probe))


## Число фич берётся у модуля, а не перечисляется здесь: иначе пол разойдётся
## с фактическим числом проверок при добавлении фичи в C++ (§1.8).
func _engine_feature_count(probe) -> int:
	if not probe.has_method("get_engine_features"):
		return 1   # одна строка «недоступно»
	var f: Dictionary = probe.get_engine_features()
	return maxi(f.size(), 1)


func _collect_xr_names(probe) -> void:
	if not _xr_checks.is_empty():
		return
	var summary: Dictionary = probe.get_summary()
	for name in summary.get("probed_openxr_extensions", PackedStringArray()):
		if name != OPENXR_FALSIFIER and name != OPENXR_CONTROL:
			_xr_checks.append(name)


func run(probe, r: ProbeReport) -> void:
	_collect_xr_names(probe)
	all_extensions = probe.list_vulkan_device_extensions()

	r.note("--- A. Возможности ---")
	r.note("устройство:   %s" % probe.get_device_name())
	r.note("вендор:       %s" % probe.get_vendor_name())
	r.note("Vulkan API:   %s" % probe.get_vulkan_api_version())
	r.note("OpenXR:       %s" % ("активен" if probe.is_openxr_running() else "НЕ активен"))
	r.note("расширений устройства (ДОСТУПНО драйверу): %d" % all_extensions.size())
	r.note("")

	_control_cases(probe, r)
	_falsifiers(probe, r)
	_vulkan_required(probe, r)
	_family(probe, r, "фовеация", VULKAN_FOVEATION_FAMILY)
	_family(probe, r, "тайловый набор", VULKAN_TILE_FAMILY)
	_openxr(probe, r)
	_engine_features(probe, r)
	_system_properties(probe, r)
	_limits(r)


## Контрольные случаи. Смотреть на них ПЕРВЫМИ: упали вместе со всеми — сломана
## фикстура, а не железо (PRACTICES §1.5).
func _control_cases(probe, r: ProbeReport) -> void:
	var v: int = probe.has_vulkan_device_extension(VULKAN_CONTROL)
	if v == 1:
		r.pass_("контроль vk: %s — прибор видит расширения устройства" % VULKAN_CONTROL)
	elif v == -1:
		r.fail("контроль vk: %s — спросить негде. ПРИБОР СЛЕП" % VULKAN_CONTROL)
	else:
		r.fail("контроль vk: %s отсутствует — на Vulkan так не бывает, сломана фикстура" % VULKAN_CONTROL)

	if not probe.is_openxr_running():
		r.unkn("контроль xr: рантайм не поднят — проверка не исполнялась")
		return
	var x: int = probe.has_openxr_extension(OPENXR_CONTROL)
	if x == 1:
		r.pass_("контроль xr: %s — прибор видит расширения рантайма" % OPENXR_CONTROL)
	else:
		r.fail("контроль xr: %s недоступно при поднятом рантайме — ПРИБОР СЛЕП, строки xr_ext недостоверны" % OPENXR_CONTROL)


## Фальсификаторы. Зелёный прибор без них не значит ничего (PRACTICES §2).
func _falsifiers(probe, r: ProbeReport) -> void:
	var v: int = probe.has_vulkan_device_extension(VULKAN_FALSIFIER)
	if v == 0:
		r.pass_("фальсификатор vk: несуществующее имя → ABSENT, прибор различает")
	elif v == 1:
		r.fail("фальсификатор vk: несуществующее имя → PRESENT. ПРИБОР ВРЁТ")
	else:
		r.fail("фальсификатор vk: → UNKNOWN, прибор слеп, а не строг")

	var x: int = probe.has_openxr_extension(OPENXR_FALSIFIER)
	if x == 0:
		r.pass_("фальсификатор xr: несуществующее имя → ABSENT, прибор различает")
	elif x == 1:
		r.fail("фальсификатор xr: несуществующее имя → PRESENT. ПРИБОР ВРЁТ")
	else:
		r.unkn("фальсификатор xr: → UNKNOWN, OpenXR не запущен")


func _vulkan_required(probe, r: ProbeReport) -> void:
	for ext in VULKAN_REQUIRED:
		var v: int = probe.has_vulkan_device_extension(ext)
		if v == 1:
			r.pass_("vk_ext: %s" % ext)
		elif v == 0:
			r.fail("vk_ext: %s — драйвер не экспортирует (Vulkan %s)" % [ext, probe.get_vulkan_api_version()])
		else:
			r.unkn("vk_ext: %s — спросить негде" % ext)


## Проверяет семейство целиком: важно не «есть ли конкретное», а «каким набором
## вообще располагаем» — и отчёт называет состав поимённо (PRACTICES §1.4).
func _family(probe, r: ProbeReport, label: String, family: Array) -> void:
	var found: Array[String] = []
	var unknown_count := 0
	for ext in family:
		var v: int = probe.has_vulkan_device_extension(ext)
		if v == 1:
			found.append(ext)
		elif v == -1:
			unknown_count += 1
	if not found.is_empty():
		r.pass_("%s: %d из %d — %s" % [label, found.size(), family.size(), ", ".join(found)])
	elif unknown_count == family.size():
		r.unkn("%s: спросить негде" % label)
	else:
		r.fail("%s: НИ ОДНОГО из %s" % [label, ", ".join(family)])


func _openxr(probe, r: ProbeReport) -> void:
	for ext in _xr_checks:
		var x: int = probe.has_openxr_extension(ext)
		if x == 1:
			r.pass_("xr_ext: %s" % ext)
		elif x == 0:
			r.fail("xr_ext: %s — рантайм не поддерживает" % ext)
		else:
			r.unkn("xr_ext: %s — OpenXR не запущен" % ext)

	if probe.is_openxr_running():
		r.pass_("openxr: рантайм активен")
	else:
		r.unkn("openxr: рантайм не активен — строки xr_ext недостоверны")

	if all_extensions.size() > 0:
		r.pass_("список расширений: получен (%d шт.)" % all_extensions.size())
	else:
		r.fail("список расширений: пуст — опрос устройства не состоялся")


## Вердикты САМОГО ДВИЖКА. Это не дубль проверок расширений: движок может не
## включить доступное расширение, и тогда опираться на него нельзя (§1.6).
func _engine_features(probe, r: ProbeReport) -> void:
	if not probe.has_method("get_engine_features"):
		r.unkn("движок: вердикты недоступны — модуль собран без get_engine_features()")
		return
	var f: Dictionary = probe.get_engine_features()
	if f.is_empty():
		r.unkn("движок: вердикты пусты — RenderingDevice или драйвер недоступны")
		return
	var names := f.keys()
	names.sort()
	for name in names:
		var critical: bool = name in FEATURES_CRITICAL
		if f[name]:
			r.pass_("движок: %s — включено%s" % [name, " (критично для VR)" if critical else ""])
		elif critical:
			r.fail("движок: %s — НЕ включено, а это критично для VR-рендера. Доступность расширения тут не поможет" % name)
		else:
			# Не критично: отсутствие — факт, а не отказ проекта.
			r.pass_("движок: %s — не включено (не критично)" % name)


## Свойства системы OpenXR. Главное — maxLayerCount: от него зависит, возможен
## ли отдельный composition layer на каждую ячейку шар-меню (ADR-0003).
func _system_properties(probe, r: ProbeReport) -> void:
	if not probe.has_method("get_openxr_system_properties"):
		r.unkn("свойства системы: модуль собран без get_openxr_system_properties()")
		return
	var d: Dictionary = probe.get_openxr_system_properties()
	if d.is_empty():
		# «Спросить не удалось» ≠ «лимитов нет» (PRACTICES §3.2).
		r.unkn("свойства системы: опрос не удался (рантайм не поднят или xrGetSystemProperties отказал)")
		return
	r.note("")
	r.note("система OpenXR: %s (vendor 0x%x)" % [d.get("system_name", "?"), d.get("vendor_id", 0)])
	r.note("    swapchain макс: %dx%d" % [d.get("max_swapchain_width", 0), d.get("max_swapchain_height", 0)])
	var layers: int = d.get("max_layer_count", 0)
	# Это не отказ и не успех сам по себе — это ЧИСЛО, от которого зависит
	# архитектура шар-меню. Проверка фиксирует, что оно получено и осмысленно.
	if layers > 0:
		r.pass_("лимит composition layers: **%d** — определяет, возможен ли слой на ячейку (ADR-0003)" % layers)
	else:
		r.fail("лимит composition layers: рантайм вернул %d — либо слои не поддерживаются, либо опрос соврал" % layers)


## Лимиты — контекст, а не проверки: у них нет «правильного» значения.
func _limits(r: ProbeReport) -> void:
	var rd := RenderingServer.get_rendering_device()
	r.note("")
	if rd == null:
		r.note("лимиты устройства: RenderingDevice недоступен")
		return
	r.note("лимиты устройства:")
	for name in DEVICE_LIMITS:
		r.note("    %-28s %d" % [name, rd.limit_get(DEVICE_LIMITS[name])])
