/**************************************************************************/
/*  register_types.cpp                                                    */
/**************************************************************************/

#include "register_types.h"

#include "vrge_probe.h"

#include "vrge_probe_xr.h"

#include "core/config/engine.h"
#include "core/object/class_db.h"

#ifdef MODULE_OPENXR_ENABLED
#include "modules/openxr/openxr_api.h"
#endif

static VRGEProbe *vrge_probe_singleton = nullptr;

void initialize_vrge_probe_module(ModuleInitializationLevel p_level) {
	// Обёртка расширений обязана зарегистрироваться ДО создания инстанса
	// OpenXR — то есть на уровне SERVERS, как это делает сам модуль openxr
	// (modules/openxr/register_types.cpp:154). На SCENE уже поздно: флаги
	// останутся false, и прибор молча соврёт «расширений нет».
#ifdef MODULE_OPENXR_ENABLED
	if (p_level == MODULE_INITIALIZATION_LEVEL_SERVERS) {
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
