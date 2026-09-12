/**************************************************************************/
/*  vrge_probe.h                                                          */
/*                                                                        */
/*  Прибор: паспорт железа. Отвечает НА ОДИН ВОПРОС ЧИСЛОМ или именем,    */
/*  а не «работает ли». См. PRACTICES.md §1.                              */
/*                                                                        */
/*  Принципы, заложенные в API:                                           */
/*   - §1.6 прибор не восстанавливает предмет измерения: версия Vulkan и  */
/*     имя устройства СПРАШИВАЮТСЯ у RenderingDevice, а список расширений */
/*     — у того самого VkPhysicalDevice, который использует движок, а не  */
/*     у своего временного инстанса.                                      */
/*   - §3.2 пустой знаменатель — не отказ: запросы расширений возвращают  */
/*     троичное значение, где -1 означает «спросить было негде», а не     */
/*     «нет». Это РАЗНЫЕ состояния отчёта.                                */
/**************************************************************************/

#ifndef VRGE_PROBE_H
#define VRGE_PROBE_H

#include "core/object/object.h"
#include "core/variant/dictionary.h"
#include "core/variant/typed_array.h"

class VRGEProbe : public Object {
	GDCLASS(VRGEProbe, Object);

	static VRGEProbe *singleton;

protected:
	static void _bind_methods();

public:
	// Троичный результат опроса. НЕ сводить к bool: «нет расширения» и
	// «некого было спросить» требуют разных строк в отчёте (PRACTICES §3.2).
	enum Availability {
		AVAILABILITY_ABSENT = 0,
		AVAILABILITY_PRESENT = 1,
		AVAILABILITY_UNKNOWN = -1,
	};

	static VRGEProbe *get_singleton();

	// --- Vulkan: спрашиваем у движка, не пересчитываем ---
	String get_vulkan_api_version() const;
	String get_device_name() const;
	String get_vendor_name() const;

	// Полный список расширений физического устройства. Пустой массив при
	// невозможности опроса неотличим от «расширений нет», поэтому для
	// решений использовать has_vulkan_device_extension(), а этот метод —
	// для приложения к отчёту.
	PackedStringArray list_vulkan_device_extensions() const;
	int has_vulkan_device_extension(const String &p_name) const;

	// --- OpenXR ---
	int has_openxr_extension(const String &p_name) const;
	bool is_openxr_running() const;

	// --- Вердикты самого движка ---
	//
	// Нужны потому, что «расширение доступно драйверу» и «движок его включил и
	// станет использовать» — РАЗНЫЕ утверждения, и опираться в архитектуре можно
	// только на второе.
	//
	// Почему через модуль, а не из GDScript: метод RenderingDevice.has_feature()
	// привязан к скриптам, но константы самых нужных фич — нет. Из скрипта
	// доступны только RAY_QUERY, RAYTRACING_PIPELINE, BUFFER_DEVICE_ADDRESS,
	// IMAGE_ATOMIC_32_BIT, HDR_OUTPUT; SUPPORTS_MULTIVIEW, ATTACHMENT_VRS и
	// FRAMEBUFFER_DEPTH_RESOLVE не биндятся (rendering_device.cpp:9760-9772).
	// Обращаться к ним сырыми числами отвергнуто: при смене порядка enum в
	// upstream прибор молча спросил бы не то (PRACTICES §4.4). Здесь имена
	// проверяет компилятор.
	Dictionary get_engine_features() const;

	// --- Свойства системы OpenXR ---
	//
	// Главное здесь — maxLayerCount: лимит числа composition layers, которые
	// рантайм примет за кадр. От него зависит, возможен ли отдельный слой на
	// каждую ячейку шар-меню или шар обязан быть ОДНИМ слоем с нарисованной
	// текстурой. Это разные подходы к вёрстке, хит-тесту и обновлению.
	//
	// Godot читает эти свойства в graphics_properties, но наружу не отдаёт:
	// поле приватно (openxr_api.h:153). Зато get_instance() и get_system_id()
	// публичны, поэтому модуль спрашивает рантайм напрямую тем же вызовом,
	// что и сам движок (PRACTICES §1.6 — спрашивать, а не восстанавливать).
	Dictionary get_openxr_system_properties() const;

	// Сводка для записи в docs/hardware-profile.md.
	Dictionary get_summary() const;

	VRGEProbe();
	~VRGEProbe();
};

VARIANT_ENUM_CAST(VRGEProbe::Availability);

#endif // VRGE_PROBE_H
