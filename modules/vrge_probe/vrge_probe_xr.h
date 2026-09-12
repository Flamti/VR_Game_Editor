/**************************************************************************/
/*  vrge_probe_xr.h                                                       */
/*                                                                        */
/*  Опрос расширений OpenXR ШТАТНЫМ механизмом Godot.                     */
/*                                                                        */
/*  Почему не OpenXRAPI::is_extension_supported(): он private. Попытка    */
/*  дотянуться до него не компилируется — и это правильно. Godot даёт для */
/*  этой задачи OpenXRExtensionWrapper: возвращаем карту «имя → bool*»,   */
/*  и рантайм сам проставляет флаги при создании инстанса.                */
/*                                                                        */
/*  ВАЖНО про смысл флага (PRACTICES §1.4, §3.2): true означает           */
/*  «расширение запрошено И доступно», а НЕ «рантайм его знает». Прибор   */
/*  обязан называть измеряемое своим именем, иначе отчёт соврёт.          */
/**************************************************************************/

#ifndef VRGE_PROBE_XR_H
#define VRGE_PROBE_XR_H

#include "modules/modules_enabled.gen.h"

#ifdef MODULE_OPENXR_ENABLED

#include "modules/openxr/extensions/openxr_extension_wrapper.h"

class VRGEProbeXRExtension : public OpenXRExtensionWrapper {
	static VRGEProbeXRExtension *singleton;

	// Флаги заполняет рантайм OpenXR. Хранилище должно пережить вызов
	// get_requested_extensions(), поэтому оно — член, а не локальная переменная.
	HashMap<String, bool> availability;

public:
	static VRGEProbeXRExtension *get_singleton();

	// Имена, которые прибор проверяет. Последнее — заведомо несуществующее:
	// встроенный фальсификатор (PRACTICES §2). Если рантайм пометит его
	// доступным, прибор врёт и всему остальному верить нельзя.
	static PackedStringArray get_probed_extension_names();

	virtual HashMap<String, bool *> get_requested_extensions(XrVersion p_xr_version) override;

	// 1 доступно, 0 недоступно, -1 имя не входит в список опрашиваемых.
	int get_availability(const String &p_name) const;

	VRGEProbeXRExtension();
	~VRGEProbeXRExtension();
};

#endif // MODULE_OPENXR_ENABLED
#endif // VRGE_PROBE_XR_H
