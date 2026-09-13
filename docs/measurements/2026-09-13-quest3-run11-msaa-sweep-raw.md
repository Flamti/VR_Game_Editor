# Паспорт железа — сырой вывод прибора

- дата: 2026-09-13T19:55:01
- устройство: Adreno (TM) 740
- вендор: Qualcomm
- Vulkan API: 1.3.295
- OpenXR активен: true
- частота: 90.0 Гц, кадровый бюджет: 11.11 мс

## Измеренные числа
```
мкс на draw call (небатченый):  1.152
мкс на инстанс:                 не измерено
цена разогрева PSO, мс:         5.812
разброс прогонов, мс:           0.121
буфер глаза:                    1680x1760
фовеация (уровень/динамика):    0 / false
троттлинг, секунда сброса:      не наблюдался
прогон фазы E, с:               0 из 0
```

## Частотная матрица
```
не прогонялась
```

## Цена пикселя
```
не измерялась
```

## Ручки рендера и поверхности меню (фаза L)
```
не измерялись
```

## Цена draw call под MSAA (фаза L4)
```
MSAA	мкс/вызов GPU	мкс/вызов CPU	разброс	база GPU мс
off	4.158	1.104	0.404	2.770
2x	3.883	1.191	0.004	2.497
```

## Вердикт
```
=== ПАСПОРТ ЖЕЛЕЗА ===
ожидается исполненных проверок: 59

  PASS  XR-вьюпорт: включён, рендер идёт в шлем

--- B0. Частота кадров (ADR-0007: цель 90, минимум 72 Гц) ---
доступные частоты: [72.0, 80.0, 90.0, 120.0] (перечисление НЕисчерпывающе по замыслу вендора)
бюджет кадра: 11.11 мс при 90.0 Гц — ВСЕ числа ниже относятся к этой частоте
  PASS  частота: запрошена цель 90.0 Гц — получено 90.0 (было 72.0), ждали 39 мс
--- A. Возможности ---
устройство:   Adreno (TM) 740
вендор:       Qualcomm
Vulkan API:   1.3.295
OpenXR:       активен
расширений устройства (ДОСТУПНО драйверу): 137

  PASS  контроль vk: VK_KHR_swapchain — прибор видит расширения устройства
  PASS  контроль xr: XR_KHR_vulkan_enable2 — прибор видит расширения рантайма
  PASS  фальсификатор vk: несуществующее имя → ABSENT, прибор различает
  PASS  фальсификатор xr: несуществующее имя → ABSENT, прибор различает
  PASS  vk_ext: VK_KHR_multiview
  PASS  vk_ext: VK_KHR_dynamic_rendering
  FAIL  vk_ext: VK_KHR_dynamic_rendering_local_read — драйвер не экспортирует (Vulkan 1.3.295)
  PASS  vk_ext: VK_KHR_create_renderpass2
  PASS  фовеация: 3 из 4 — VK_EXT_fragment_density_map, VK_EXT_fragment_density_map2, VK_KHR_fragment_shading_rate
  PASS  тайловый набор: 8 из 8 — VK_QCOM_tile_properties, VK_QCOM_render_pass_store_ops, VK_EXT_load_store_op_none, VK_QCOM_render_pass_shader_resolve, VK_QCOM_render_pass_transform, VK_QCOM_multiview_per_view_viewports, VK_QCOM_multiview_per_view_render_areas, VK_QCOM_fragment_density_map_offset
  PASS  xr_ext: XR_KHR_composition_layer_cylinder
  PASS  xr_ext: XR_KHR_composition_layer_equirect2
  PASS  xr_ext: XR_KHR_composition_layer_depth
  PASS  xr_ext: XR_FB_space_warp
  PASS  xr_ext: XR_EXT_frame_synthesis
  PASS  xr_ext: XR_FB_foveation
  PASS  xr_ext: XR_FB_foveation_configuration
  FAIL  xr_ext: XR_META_environment_depth — рантайм не поддерживает
  PASS  xr_ext: XR_FB_display_refresh_rate
  PASS  openxr: рантайм активен
  PASS  список расширений: получен (137 шт.)
  PASS  движок: SUPPORTS_ATTACHMENT_VRS — включено (критично для VR)
  PASS  движок: SUPPORTS_BUFFER_DEVICE_ADDRESS — включено
  PASS  движок: SUPPORTS_FRAGMENT_SHADER_WITH_ONLY_SIDE_EFFECTS — включено
  PASS  движок: SUPPORTS_FRAMEBUFFER_DEPTH_RESOLVE — включено (критично для VR)
  PASS  движок: SUPPORTS_HALF_FLOAT — включено
  PASS  движок: SUPPORTS_HDR_OUTPUT — включено
  PASS  движок: SUPPORTS_IMAGE_ATOMIC_32_BIT — включено
  PASS  движок: SUPPORTS_MULTIVIEW — включено (критично для VR)
  PASS  движок: SUPPORTS_POINT_SIZE — включено
  PASS  движок: SUPPORTS_RAYTRACING_PIPELINE — не включено (не критично)
  PASS  движок: SUPPORTS_RAY_QUERY — не включено (не критично)
  PASS  движок: SUPPORTS_VULKAN_MEMORY_MODEL — включено

система OpenXR: Meta Quest 3 (vendor 0x2833)
    swapchain макс: 8192x8192
  PASS  лимит composition layers: **32** — определяет, возможен ли слой на ячейку (ADR-0003)

лимиты устройства:
    MAX_FRAMEBUFFER_WIDTH        16384
    MAX_FRAMEBUFFER_HEIGHT       16384
    MAX_TEXTURE_ARRAY_LAYERS     2048
    MAX_UNIFORM_BUFFER_SIZE      65536
    MAX_PUSH_CONSTANT_SIZE       256

--- S. Состояние рендера ---
буфер глаза 1680x1760 (2.96 Мпикс), множитель 1.0, фовеация 0/динамика false, MSAA 0, масштаб 1.0, VRS 0
  PASS  снимок состояния: получен, буфер глаза 1680x1760
  PASS  фовеация ВЫКЛЮЧЕНА (уровень 0, динамика off) — объяснение аномалии 120 Гц через DFR отпадает, если так же на обеих ступенях

--- H. Аппаратные счётчики ---
  ????  sysfs: /sys/class/kgsl/kgsl-3d0/gpuclk не открыть. На Android абсолютные пути идут через Java-слой (os_android.cpp:121), а не через FileAccessUnix — клок берётся с хоста, tools/gpu_sampler.sh
  ????  лестница частот GPU: не прочитать
  ????  резиденция частот: сверить длину не с чем
  ????  фальсификатор sysfs: не с чем сравнивать — не читается ни один путь, включая заведомо существующий

--- C–D. Стоимость отрисовки ---
частота обновления: 90.0 Гц, кадровый бюджет: 11.11 мс
окно: 1.0 с разогрева + 1.5 с замера по стенным часам (число кадров — результат, не настройка)

свип «небатченый»:
    N=0     draw calls движка=0      CPU n=135  сред=0.107  мед=0.105  p95=0.136  макс=0.191 мс
                          GPU n=135  сред=2.905  мед=2.996  p95=3.351  макс=3.761 мс
                          доставлено 135 кадров за 1500 мс = 90.0 к/с из 90 (100%); промахов по бюджету нет
    N=50    draw calls движка=50     CPU n=135  сред=0.198  мед=0.193  p95=0.227  макс=0.306 мс
                          GPU n=135  сред=3.135  мед=3.103  p95=3.451  макс=3.740 мс
                          доставлено 135 кадров за 1501 мс = 89.9 к/с из 90 (100%); промахов по бюджету нет
    N=100   draw calls движка=100    CPU n=135  сред=0.256  мед=0.244  p95=0.313  макс=0.684 мс
                          GPU n=135  сред=3.238  мед=3.217  p95=3.565  макс=4.085 мс
                          доставлено 135 кадров за 1500 мс = 90.0 к/с из 90 (100%); промахов по бюджету нет
    N=200   draw calls движка=200    CPU n=135  сред=0.535  мед=0.365  p95=1.039  макс=1.160 мс
                          GPU n=135  сред=3.697  мед=3.661  p95=4.076  макс=4.498 мс
                          доставлено 135 кадров за 1500 мс = 90.0 к/с из 90 (100%); промахов по бюджету нет
    N=400   draw calls движка=400    CPU n=135  сред=0.897  мед=0.688  p95=1.395  макс=1.546 мс
                          GPU n=135  сред=5.235  мед=5.009  p95=6.250  макс=6.567 мс
                          доставлено 135 кадров за 1500 мс = 90.0 к/с из 90 (100%); промахов по бюджету нет
    N=800   draw calls движка=800    CPU n=135  сред=0.835  мед=0.831  p95=0.929  макс=1.101 мс
                          GPU n=135  сред=7.954  мед=8.075  p95=8.615  макс=9.343 мс
                          доставлено 135 кадров за 1500 мс = 90.0 к/с из 90 (100%); промахов по бюджету нет
    N=1600  draw calls движка=1600   CPU n=135  сред=1.961  мед=1.948  p95=2.296  макс=3.148 мс
                          GPU n=135  сред=9.530  мед=9.538  p95=9.741  макс=9.889 мс
                          доставлено 135 кадров за 1500 мс = 90.0 к/с из 90 (100%); промахов по бюджету нет
свип «инстансы»:
    N=0     draw calls движка=0      CPU n=135  сред=0.113  мед=0.110  p95=0.127  макс=0.158 мс
                          GPU n=135  сред=2.642  мед=2.632  p95=2.889  макс=3.378 мс
                          доставлено 135 кадров за 1500 мс = 90.0 к/с из 90 (100%); промахов по бюджету нет
    N=50    draw calls движка=1      CPU n=135  сред=0.143  мед=0.138  p95=0.173  макс=0.220 мс
                          GPU n=135  сред=2.907  мед=2.867  p95=3.129  макс=3.784 мс
                          доставлено 135 кадров за 1500 мс = 90.0 к/с из 90 (100%); промахов по бюджету нет
    N=100   draw calls движка=1      CPU n=135  сред=0.141  мед=0.138  p95=0.160  макс=0.227 мс
                          GPU n=135  сред=2.925  мед=2.867  p95=3.221  макс=3.815 мс
                          доставлено 135 кадров за 1500 мс = 90.0 к/с из 90 (100%); промахов по бюджету нет
    N=200   draw calls движка=1      CPU n=135  сред=0.146  мед=0.143  p95=0.174  макс=0.310 мс
                          GPU n=135  сред=2.937  мед=2.888  p95=3.395  макс=3.847 мс
                          доставлено 135 кадров за 1500 мс = 90.0 к/с из 90 (100%); промахов по бюджету нет
    N=400   draw calls движка=1      CPU n=135  сред=0.148  мед=0.142  p95=0.176  макс=0.286 мс
                          GPU n=135  сред=3.258  мед=3.203  p95=3.556  макс=4.340 мс
                          доставлено 135 кадров за 1501 мс = 89.9 к/с из 90 (100%); промахов по бюджету нет
    N=800   draw calls движка=1      CPU n=135  сред=0.154  мед=0.147  p95=0.200  макс=0.281 мс
                          GPU n=135  сред=3.197  мед=3.176  p95=3.541  макс=4.424 мс
                          доставлено 135 кадров за 1500 мс = 90.0 к/с из 90 (100%); промахов по бюджету нет
    N=1600  draw calls движка=1      CPU n=135  сред=0.142  мед=0.136  p95=0.195  макс=0.266 мс
                          GPU n=135  сред=3.168  мед=3.189  p95=3.592  макс=4.283 мс
                          доставлено 135 кадров за 1501 мс = 89.9 к/с из 90 (100%); промахов по бюджету нет

разброс двух прогонов на N=100: 0.121 мс (0.131 против 0.252)
  PASS  разрешение свипа: разброс 0.121 мс меньше шага 1.843 мс (в 15 раз) — наклону можно верить
  PASS  нулевой контроль: пустая сцена CPU 0.105 / GPU 2.996 мс, связывает GPU — 27% бюджета 11.11 мс, запас есть
  PASS  гейт «небатченый»: ΔN=1600 → Δdraw calls=1600 (1.00 на объект) — случай задевает гейт
  PASS  гейт «инстансы»: ΔN=1600, Δdraw calls=1 — инстансинг работает, режимы различаются
  PASS  частота устойчива: 90.0 Гц от начала до конца свипов
  PASS  разогрев PSO: пик первых 90 кадров выше установившегося на 5.812 мс (макс 6.056 против мед 0.244)
  PASS  наклон «небатченый»: CPU 1.152 мкс/ед., GPU 4.089 мкс/ед. — связывает GPU (Δ на ΔN=1600)
  FAIL  наклон «инстансы»: разброс прогонов 0.121 мс БОЛЬШЕ роста по свипу 0.026 мс — разрешение ниже шума, число недостоверно

фаза M пропущена (маркер user://skip_matrix)

фаза P пропущена (маркер user://skip_fill)

фаза L пропущена (маркер user://skip_layers)

--- L4. Цена draw call под MSAA 2x против off (ADR-0003, условие пункта 6) ---
частота 90.0 Гц, бюджет 11.11 мс; точки [0, 200, 400, 800, 1600]; порядок режимов ["off", "2x", "2x", "off"]
  лестница MSAA off (повтор 1):
    N=0     отрисовок 0     GPU 3.114  CPU 0.124 мс; доставлено 135 кадров за 1500 мс = 90.0 к/с из 90 (100%); промахов по бюджету нет
    N=200   отрисовок 200   GPU 3.734  CPU 0.396 мс; доставлено 135 кадров за 1501 мс = 89.9 к/с из 90 (100%); промахов по бюджету нет
    N=400   отрисовок 400   GPU 4.497  CPU 0.639 мс; доставлено 135 кадров за 1500 мс = 90.0 к/с из 90 (100%); промахов по бюджету нет
    N=800   отрисовок 800   GPU 8.019  CPU 0.833 мс; доставлено 136 кадров за 1510 мс = 90.1 к/с из 90 (100%); промахов по бюджету нет
    N=1600  отрисовок 1600  GPU 9.444  CPU 1.874 мс; доставлено 136 кадров за 1510 мс = 90.1 к/с из 90 (100%); промахов по бюджету нет
  лестница MSAA 2x (повтор 1):
    N=0     отрисовок 0     GPU 2.494  CPU 0.109 мс; доставлено 135 кадров за 1501 мс = 89.9 к/с из 90 (100%); промахов по бюджету нет
    N=200   отрисовок 200   GPU 2.373  CPU 0.312 мс; доставлено 135 кадров за 1500 мс = 90.0 к/с из 90 (100%); промахов по бюджету нет
    N=400   отрисовок 400   GPU 3.165  CPU 0.493 мс; доставлено 135 кадров за 1500 мс = 90.0 к/с из 90 (100%); промахов по бюджету нет
    N=800   отрисовок 800   GPU 5.708  CPU 1.248 мс; доставлено 136 кадров за 1510 мс = 90.1 к/с из 90 (100%); промахов по бюджету нет
    N=1600  отрисовок 1600  GPU 8.704  CPU 2.019 мс; доставлено 135 кадров за 1501 мс = 89.9 к/с из 90 (100%); промахов по бюджету нет
  лестница MSAA 2x (повтор 2):
    N=0     отрисовок 0     GPU 2.501  CPU 0.112 мс; доставлено 135 кадров за 1500 мс = 90.0 к/с из 90 (100%); промахов по бюджету нет
    N=200   отрисовок 200   GPU 2.382  CPU 0.338 мс; доставлено 136 кадров за 1511 мс = 90.0 к/с из 90 (100%); промахов по бюджету нет
    N=400   отрисовок 400   GPU 3.186  CPU 1.096 мс; доставлено 135 кадров за 1500 мс = 90.0 к/с из 90 (100%); промахов по бюджету нет
    N=800   отрисовок 800   GPU 4.815  CPU 1.058 мс; доставлено 135 кадров за 1500 мс = 90.0 к/с из 90 (100%); промахов по бюджету нет
    N=1600  отрисовок 1600  GPU 8.717  CPU 2.013 мс; доставлено 135 кадров за 1501 мс = 89.9 к/с из 90 (100%); промахов по бюджету нет
  лестница MSAA off (повтор 2):
    N=0     отрисовок 0     GPU 2.426  CPU 0.103 мс; доставлено 135 кадров за 1500 мс = 90.0 к/с из 90 (100%); промахов по бюджету нет
    N=200   отрисовок 200   GPU 3.377  CPU 0.312 мс; доставлено 135 кадров за 1501 мс = 89.9 к/с из 90 (100%); промахов по бюджету нет
    N=400   отрисовок 400   GPU 4.542  CPU 0.721 мс; доставлено 136 кадров за 1509 мс = 90.1 к/с из 90 (100%); промахов по бюджету нет
    N=800   отрисовок 800   GPU 7.873  CPU 0.913 мс; доставлено 135 кадров за 1500 мс = 90.0 к/с из 90 (100%); промахов по бюджету нет
    N=1600  отрисовок 1600  GPU 9.403  CPU 1.887 мс; доставлено 135 кадров за 1500 мс = 90.0 к/с из 90 (100%); промахов по бюджету нет
  PASS  L4 гейт состояния: MSAA вставал в каждый режим, остальное состояние не менялось
  PASS  L4 гейт счётчика, MSAA off: все 10 точек дали ровно N отрисовок
  PASS  L4 гейт счётчика, MSAA 2x: все 10 точек дали ровно N отрисовок
  PASS  L4 наклон MSAA off: GPU **4.158 мкс/вызов** (повторы [3.9562501013279, 4.3606248497963], разброс 0.404), CPU 1.104 мкс/вызов — связывает GPU
  PASS  L4 наклон MSAA 2x: GPU **3.883 мкс/вызов** (повторы [3.88125032186508, 3.8850000500679], разброс 0.004), CPU 1.191 мкс/вызов — связывает GPU
  PASS  L4 база пустого кадра: off 2.770 мс, 2x 2.497 мс, разница -0.273 при разбросе 0.688 — в шуме
  PASS  L4 сравнение наклонов: off 4.158, 2x 3.883 мкс/вызов, разница -0.275 (отношение 0.93) при разбросе 0.404 — в шуме — цена вызова от MSAA не отличима
  PASS  L4 доставка на N=1600: off: [90.0662251655629, 90.0] к/с, сверх бюджета 0; 2x: [89.9400399733511, 89.9400399733511] к/с, сверх бюджета 0 — промахов нет
  PASS  L4 контроль с C–D: off 4.158 против C–D 4.089 мкс/вызов, расхождение 1.7% в пределах дрейфа 15% — фаза меряет то же, что C–D

фаза E пропущена (маркер user://skip_sustained или флаг)

passed=52 failed=3 unknown=4
пол: исполнено 59/59 проверок
```

## Все расширения устройства (137)
```
VK_KHR_incremental_present
VK_KHR_shared_presentable_image
VK_GOOGLE_display_timing
VK_EXT_swapchain_maintenance1
VK_EXT_subgroup_size_control
VK_KHR_external_memory
VK_EXT_pipeline_creation_feedback
VK_KHR_shader_float16_int8
VK_EXT_multisampled_render_to_single_sampled
VK_KHR_get_memory_requirements2
VK_KHR_copy_commands2
VK_KHR_deferred_host_operations
VK_KHR_spirv_1_4
VK_EXT_fragment_density_map
VK_KHR_external_semaphore_fd
VK_QCOM_render_pass_store_ops
VK_EXT_astc_decode_mode
VK_EXT_conservative_rasterization
VK_EXT_shader_stencil_export
VK_KHR_external_memory_fd
VK_QCOM_render_pass_shader_resolve
VK_KHR_maintenance1
VK_KHR_maintenance2
VK_KHR_maintenance3
VK_KHR_maintenance4
VK_KHR_maintenance5
VK_KHR_separate_depth_stencil_layouts
VK_EXT_image_robustness
VK_KHR_buffer_device_address
VK_EXT_extended_dynamic_state
VK_EXT_queue_family_foreign
VK_EXT_image_view_min_lod
VK_KHR_bind_memory2
VK_EXT_pipeline_protected_access
VK_KHR_external_semaphore
VK_KHR_shader_terminate_invocation
VK_QCOM_fragment_density_map_offset
VK_EXT_scalar_block_layout
VK_EXT_load_store_op_none
VK_KHR_sampler_ycbcr_conversion
VK_EXT_vertex_attribute_divisor
VK_KHR_variable_pointers
VK_QCOM_multiview_per_view_viewports
VK_KHR_ray_query
VK_KHR_push_descriptor
VK_KHR_timeline_semaphore
VK_EXT_device_memory_report
VK_KHR_imageless_framebuffer
VK_KHR_device_group
VK_EXT_device_fault
VK_KHR_relaxed_block_layout
VK_EXT_host_image_copy
VK_KHR_shader_atomic_int64
VK_KHR_external_fence
VK_KHR_shader_non_semantic_info
VK_EXT_shader_atomic_float
VK_EXT_custom_border_color
VK_EXT_host_query_reset
VK_KHR_pipeline_binary
VK_EXT_index_type_uint8
VK_KHR_multiview
VK_KHR_storage_buffer_storage_class
VK_EXT_fragment_density_map2
VK_KHR_workgroup_memory_explicit_layout
VK_QCOM_rotated_copy_commands
VK_KHR_shader_subgroup_extended_types
VK_EXT_external_memory_acquire_unmodified
VK_EXT_private_data
VK_EXT_pipeline_creation_cache_control
VK_EXT_robustness2
VK_KHR_shader_clock
VK_EXT_shader_module_identifier
VK_EXT_global_priority_query
VK_EXT_separate_stencil_usage
VK_EXT_border_color_swizzle
VK_EXT_vertex_input_dynamic_state
VK_IMG_filter_cubic
VK_EXT_filter_cubic
VK_EXT_shader_subgroup_vote
VK_EXT_device_address_binding_report
VK_NV_optical_flow
VK_QCOM_tile_properties
VK_EXT_pipeline_robustness
VK_KHR_image_format_list
VK_EXT_sampler_filter_minmax
VK_KHR_16bit_storage
VK_EXT_shader_viewport_index_layer
VK_KHR_pipeline_executable_properties
VK_EXT_shader_demote_to_helper_invocation
VK_EXT_color_write_enable
VK_QCOM_render_pass_transform
VK_KHR_create_renderpass2
VK_KHR_acceleration_structure
VK_EXT_depth_clip_control
VK_EXT_transform_feedback
VK_EXT_blend_operation_advanced
VK_EXT_provoking_vertex
VK_KHR_8bit_storage
VK_QCOM_multiview_per_view_render_areas
VK_EXT_inline_uniform_block
VK_EXT_shader_subgroup_ballot
VK_KHR_depth_stencil_resolve
VK_KHR_shader_float_controls
VK_EXT_texture_compression_astc_hdr
VK_EXT_global_priority
VK_EXT_4444_formats
VK_KHR_shader_draw_parameters
VK_KHR_vulkan_memory_model
VK_EXT_descriptor_indexing
VK_EXT_depth_clip_enable
VK_KHR_synchronization2
VK_KHR_shader_integer_dot_product
VK_EXT_line_rasterization
VK_QCOM_image_processing
VK_KHR_fragment_shading_rate
VK_KHR_descriptor_update_template
VK_KHR_draw_indirect_count
VK_KHR_driver_properties
VK_KHR_dynamic_rendering
VK_KHR_zero_initialize_workgroup_memory
VK_KHR_uniform_buffer_standard_layout
VK_EXT_depth_clamp_zero_one
VK_ANDROID_external_memory_android_hardware_buffer
VK_EXT_image_2d_view_of_3d
VK_EXT_extended_dynamic_state2
VK_KHR_dedicated_allocation
VK_EXT_texel_buffer_alignment
VK_EXT_primitive_topology_list_restart
VK_KHR_shader_subgroup_uniform_control_flow
VK_EXT_tooling_info
VK_KHR_format_feature_flags2
VK_KHR_global_priority
VK_EXT_sample_locations
VK_EXT_multi_draw
VK_KHR_swapchain
VK_KHR_sampler_mirror_clamp_to_edge
VK_KHR_external_fence_fd
```
