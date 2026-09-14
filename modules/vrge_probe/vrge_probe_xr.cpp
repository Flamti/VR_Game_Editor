/**************************************************************************/
/*  vrge_probe_xr.cpp                                                     */
/**************************************************************************/

#include "vrge_probe_xr.h"

#ifdef MODULE_OPENXR_ENABLED

VRGEProbeXRExtension *VRGEProbeXRExtension::singleton = nullptr;

// Один перечень, из которого выводится и запрос, и отчёт: два независимых
// списка разошлись бы — один обновят, второй забудут (PRACTICES §1.8).
static const char *VRGE_PROBED_XR_EXTENSIONS[] = {
	// КОНТРОЛЬНЫЙ СЛУЧАЙ (PRACTICES §1.5). Godot помечает это расширение
	// "must be available" (openxr_vulkan_extension.cpp:43) — без него сессия
	// не могла бы рендерить через Vulkan. Если оно доступно, а прибор говорит
	// «нет», значит прибор СЛЕП, и всем остальным строкам верить нельзя.
	//
	// Без этого случая фальсификатор был ложно-зелёным: незарегистрированная
	// обёртка оставляет ВСЕ флаги false, и «несуществующее имя дало ABSENT»
	// выглядело как доказательство строгости прибора (PRACTICES §2.3).
	"XR_KHR_vulkan_enable2",
	"XR_KHR_composition_layer_cylinder",
	"XR_KHR_composition_layer_equirect2",
	"XR_KHR_composition_layer_depth",
	"XR_FB_space_warp",
	// Godot 4.7 синтезирует кадры через это расширение, а не через FB space
	// warp (openxr_frame_synthesis_extension.cpp:77). Второе есть — это ничего
	// не говорит о первом (ADR-0003, проверка L0).
	"XR_EXT_frame_synthesis",
	"XR_FB_foveation",
	"XR_FB_foveation_configuration",
	"XR_META_environment_depth",
	// Руки (ADR-0008): профиль жестов и модель руки от рантайма. Прогон 12
	// показал, что жесты доходят, но наличие расширений прибор не спрашивал.
	"XR_EXT_hand_interaction",
	"XR_FB_hand_tracking_mesh",
	"XR_FB_display_refresh_rate",
	// Фальсификатор: обязан остаться false (PRACTICES §2.2).
	"XR_VRGE_this_extension_does_not_exist",
	nullptr,
};

VRGEProbeXRExtension *VRGEProbeXRExtension::get_singleton() {
	return singleton;
}

VRGEProbeXRExtension::VRGEProbeXRExtension() {
	singleton = this;
	for (int i = 0; VRGE_PROBED_XR_EXTENSIONS[i] != nullptr; i++) {
		availability[String::utf8(VRGE_PROBED_XR_EXTENSIONS[i])] = false;
	}
}

VRGEProbeXRExtension::~VRGEProbeXRExtension() {
	if (singleton == this) {
		singleton = nullptr;
	}
}

PackedStringArray VRGEProbeXRExtension::get_probed_extension_names() {
	PackedStringArray out;
	for (int i = 0; VRGE_PROBED_XR_EXTENSIONS[i] != nullptr; i++) {
		out.push_back(String::utf8(VRGE_PROBED_XR_EXTENSIONS[i]));
	}
	return out;
}

HashMap<String, bool *> VRGEProbeXRExtension::get_requested_extensions(XrVersion p_xr_version) {
	HashMap<String, bool *> request;
	for (KeyValue<String, bool> &kv : availability) {
		request[kv.key] = &kv.value;
	}
	return request;
}

int VRGEProbeXRExtension::get_availability(const String &p_name) const {
	const bool *found = availability.getptr(p_name);
	if (found == nullptr) {
		// Имени нет в списке опрашиваемых — это «не спрашивали», а не «нет»
		// (PRACTICES §3.2).
		return -1;
	}
	return *found ? 1 : 0;
}

#endif // MODULE_OPENXR_ENABLED
