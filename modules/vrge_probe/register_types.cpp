/**************************************************************************/
/*  register_types.cpp                                                    */
/**************************************************************************/

#include "register_types.h"

#include "vrge_probe.h"

#include "vrge_probe_xr.h"

#include "core/config/engine.h"
#include "core/string/print_string.h"
#include "core/variant/variant_utility.h"
#include "core/object/class_db.h"

#ifdef MODULE_OPENXR_ENABLED
#include "modules/openxr/openxr_api.h"
#endif

static VRGEProbe *vrge_probe_singleton = nullptr;

void initialize_vrge_probe_module(ModuleInitializationLevel p_level) {
	// Обёртка расширений обязана зарегистрироваться ДО создания инстанса OpenXR.
	//
	// SERVERS НЕ ГОДИТСЯ, хотя сам модуль openxr регистрирует свои обёртки
	// именно там (modules/openxr/register_types.cpp:154): на этом же уровне он
	// и СОЗДАЁТ инстанс, а модули внутри уровня инициализируются по алфавиту —
	// "openxr" раньше "vrge_probe". К нашей регистрации инстанс уже есть, и
	// register_extension_wrapper() отвергает её (openxr_api.cpp:1846).
	//
	// Под Linux это не всплыло: там OpenXR-рантайма не было, инстанс не
	// создавался, и регистрация проходила. Ошибка ждала реального шлема.
	//
	// CORE исполняется до SERVERS — там инстанса ещё нет ни при каком порядке.
#ifdef MODULE_OPENXR_ENABLED
	// Маркер уровня инициализации оставлен ОДНОЙ строкой и только на CORE.
	//
	// Он уже отработал: именно им был разрешён спор «не тот уровень» против
	// «не доехал бинарь» (PRACTICES §4.6), когда регистрация падала на SERVERS.
	// Строка уникальна, чтобы её нельзя было спутать со словами движка при
	// грепе (§4.2) — и она же служит доказательством, что в сборке новый .so.
	if (p_level == MODULE_INITIALIZATION_LEVEL_CORE) {
		print_line(vformat("VRGE_PROBE_MARK_B: регистрирую обёртку на CORE, openxr_api=%s",
				OpenXRAPI::get_singleton() ? "есть" : "нет"));
		OpenXRAPI::register_extension_wrapper(memnew(VRGEProbeXRExtension));
	}
#endif
	if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
		return;
	}
	GDREGISTER_CLASS(VRGEProbe);
	vrge_probe_singleton = memnew(VRGEProbe);
	Engine::get_singleton()->add_singleton(Engine::Singleton("VRGEProbe", VRGEProbe::get_singleton()));
}

void uninitialize_vrge_probe_module(ModuleInitializationLevel p_level) {
	if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
		return;
	}
	if (vrge_probe_singleton) {
		Engine::get_singleton()->remove_singleton("VRGEProbe");
		memdelete(vrge_probe_singleton);
		vrge_probe_singleton = nullptr;
	}
}
