/**************************************************************************/
/*  vrge_probe.cpp                                                        */
/**************************************************************************/

#include "vrge_probe.h"

#include "core/object/class_db.h"
#include "core/os/os.h"
#include "servers/rendering/rendering_device.h"

#include "modules/modules_enabled.gen.h" // For openxr.

#ifdef VULKAN_ENABLED
#include "drivers/vulkan/rendering_context_driver_vulkan.h"
#endif

#ifdef MODULE_OPENXR_ENABLED
#include "modules/openxr/openxr_api.h"

#include "vrge_probe_xr.h"
#endif

VRGEProbe *VRGEProbe::singleton = nullptr;

VRGEProbe *VRGEProbe::get_singleton() {
	return singleton;
}

VRGEProbe::VRGEProbe() {
	ERR_FAIL_COND_MSG(singleton != nullptr, "VRGEProbe singleton already exists.");
	singleton = this;
}

VRGEProbe::~VRGEProbe() {
	if (singleton == this) {
		singleton = nullptr;
	}
}

// Спрашиваем у движка (PRACTICES §1.6). Своя копия разошлась бы с оригиналом.
String VRGEProbe::get_vulkan_api_version() const {
	RenderingDevice *rd = RenderingDevice::get_singleton();
	if (rd == nullptr) {
		return String();
	}
	return rd->get_device_api_version();
}

String VRGEProbe::get_device_name() const {
	RenderingDevice *rd = RenderingDevice::get_singleton();
	if (rd == nullptr) {
		return String();
	}
	return rd->get_device_name();
}

String VRGEProbe::get_vendor_name() const {
	RenderingDevice *rd = RenderingDevice::get_singleton();
	if (rd == nullptr) {
		return String();
	}
	return rd->get_device_vendor_name();
}

#ifdef VULKAN_ENABLED
// Берём ТОТ ЖЕ физический девайс, что использует движок, а не свой временный
// инстанс: иначе прибор мерил бы не то устройство, на котором идёт рендер.
static VkPhysicalDevice _vrge_get_engine_physical_device() {
	RenderingDevice *rd = RenderingDevice::get_singleton();
	if (rd == nullptr) {
		return VK_NULL_HANDLE;
	}
	RenderingContextDriver *ctx = rd->get_context_driver();
	if (ctx == nullptr) {
		return VK_NULL_HANDLE;
	}
	// Проверяем имя драйвера, а не тип: Godot собирается без опоры на RTTI,
	// и dynamic_cast здесь был бы чужеродным (отвергнуто осознанно).
	if (OS::get_singleton() == nullptr || OS::get_singleton()->get_current_rendering_driver_name() != "vulkan") {
		return VK_NULL_HANDLE; // Бэкенд не Vulkan — это UNKNOWN, а не ABSENT.
	}
	RenderingContextDriverVulkan *vk_ctx = static_cast<RenderingContextDriverVulkan *>(ctx);
	return vk_ctx->physical_device_get(0);
}
#endif

PackedStringArray VRGEProbe::list_vulkan_device_extensions() const {
	PackedStringArray out;
#ifdef VULKAN_ENABLED
	VkPhysicalDevice pd = _vrge_get_engine_physical_device();
	if (pd == VK_NULL_HANDLE) {
		return out;
	}
	uint32_t count = 0;
	if (vkEnumerateDeviceExtensionProperties(pd, nullptr, &count, nullptr) != VK_SUCCESS || count == 0) {
		return out;
	}
	LocalVector<VkExtensionProperties> props;
	props.resize(count);
	if (vkEnumerateDeviceExtensionProperties(pd, nullptr, &count, props.ptr()) != VK_SUCCESS) {
		return out;
	}
	for (uint32_t i = 0; i < count; i++) {
		out.push_back(String::utf8(props[i].extensionName));
	}
#endif
	return out;
}

int VRGEProbe::has_vulkan_device_extension(const String &p_name) const {
#ifdef VULKAN_ENABLED
	VkPhysicalDevice pd = _vrge_get_engine_physical_device();
	if (pd == VK_NULL_HANDLE) {
		// Спросить было негде. Это НЕ «расширения нет» (PRACTICES §3.2).
		return AVAILABILITY_UNKNOWN;
	}
	PackedStringArray all = list_vulkan_device_extensions();
	if (all.is_empty()) {
		return AVAILABILITY_UNKNOWN;
	}
	return all.has(p_name) ? AVAILABILITY_PRESENT : AVAILABILITY_ABSENT;
#else
	return AVAILABILITY_UNKNOWN;
#endif
}

bool VRGEProbe::is_openxr_running() const {
#ifdef MODULE_OPENXR_ENABLED
	return OpenXRAPI::get_singleton() != nullptr;
#else
	return false;
#endif
}

int VRGEProbe::has_openxr_extension(const String &p_name) const {
#ifdef MODULE_OPENXR_ENABLED
	// OpenXRAPI::is_extension_supported() приватный — тянуться к нему нельзя.
	// Спрашиваем штатную обёртку, которую заполнил сам рантайм (PRACTICES §1.6).
	if (OpenXRAPI::get_singleton() == nullptr) {
		return AVAILABILITY_UNKNOWN; // Рантайм не поднят — «не спрашивали».
	}
	VRGEProbeXRExtension *wrapper = VRGEProbeXRExtension::get_singleton();
	if (wrapper == nullptr) {
		return AVAILABILITY_UNKNOWN;
	}
	int r = wrapper->get_availability(p_name);
	if (r < 0) {
		return AVAILABILITY_UNKNOWN; // Имя не входит в опрашиваемый список.
	}
	return r == 1 ? AVAILABILITY_PRESENT : AVAILABILITY_ABSENT;
#else
	return AVAILABILITY_UNKNOWN;
#endif
}

Dictionary VRGEProbe::get_summary() const {
	Dictionary d;
	d["vulkan_api_version"] = get_vulkan_api_version();
	d["device_name"] = get_device_name();
	d["vendor_name"] = get_vendor_name();
	d["openxr_running"] = is_openxr_running();
	PackedStringArray exts = list_vulkan_device_extensions();
	d["vulkan_device_extension_count"] = exts.size();
	d["vulkan_device_extensions"] = exts;
#ifdef MODULE_OPENXR_ENABLED
	d["probed_openxr_extensions"] = VRGEProbeXRExtension::get_probed_extension_names();
#else
	d["probed_openxr_extensions"] = PackedStringArray();
#endif
	return d;
}

void VRGEProbe::_bind_methods() {
	ClassDB::bind_method(D_METHOD("get_vulkan_api_version"), &VRGEProbe::get_vulkan_api_version);
	ClassDB::bind_method(D_METHOD("get_device_name"), &VRGEProbe::get_device_name);
	ClassDB::bind_method(D_METHOD("get_vendor_name"), &VRGEProbe::get_vendor_name);
	ClassDB::bind_method(D_METHOD("list_vulkan_device_extensions"), &VRGEProbe::list_vulkan_device_extensions);
	ClassDB::bind_method(D_METHOD("has_vulkan_device_extension", "name"), &VRGEProbe::has_vulkan_device_extension);
	ClassDB::bind_method(D_METHOD("has_openxr_extension", "name"), &VRGEProbe::has_openxr_extension);
	ClassDB::bind_method(D_METHOD("is_openxr_running"), &VRGEProbe::is_openxr_running);
	ClassDB::bind_method(D_METHOD("get_summary"), &VRGEProbe::get_summary);

	BIND_ENUM_CONSTANT(AVAILABILITY_ABSENT);
	BIND_ENUM_CONSTANT(AVAILABILITY_PRESENT);
	BIND_ENUM_CONSTANT(AVAILABILITY_UNKNOWN);
}
