# Паспорт железа — сырой вывод прибора

- дата: 2026-09-13T10:13:20
- устройство: Adreno (TM) 740
- вендор: Qualcomm
- Vulkan API: 1.3.295
- OpenXR активен: true
- частота: 90.0 Гц, кадровый бюджет: 11.11 мс

## Измеренные числа
```
мкс на draw call (небатченый):  1.143
мкс на инстанс:                 0.016
цена разогрева PSO, мс:         5.539
разброс прогонов, мс:           0.016
буфер глаза:                    1680x1760
фовеация (уровень/динамика):    0 / false
троттлинг, секунда сброса:      не наблюдался
прогон фазы E, с:               0 из 0
```

## Частотная матрица
```
ступень	запрошено	получено	мкс/вызов GPU	база GPU мс	буфер
0	72	72.0	4.788	2.708	1680x1760
1	90	90.0	4.204	2.626	1680x1760
2	72	72.0	4.429	3.374	1680x1760
3	90	90.0	4.141	2.626	1680x1760
```

## Цена пикселя
```
72.0 Гц: -539.653 мкс на Мпиксель
90.0 Гц: 129.825 мкс на Мпиксель
```

## Вердикт
```
=== ПАСПОРТ ЖЕЛЕЗА ===
ожидается исполненных проверок: 62

  PASS  XR-вьюпорт: включён, рендер идёт в шлем

--- B0. Частота кадров (ADR-0007: цель 90, минимум 72 Гц) ---
доступные частоты: [72.0, 80.0, 90.0, 120.0] (перечисление НЕисчерпывающе по замыслу вендора)
бюджет кадра: 11.11 мс при 90.0 Гц — ВСЕ числа ниже относятся к этой частоте
  PASS  частота: запрошена цель 90.0 Гц — получено 90.0 (было 72.0), ждали 41 мс
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
    N=0     draw calls движка=0      CPU n=135  сред=0.105  мед=0.103  p95=0.132  макс=0.163 мс
                          GPU n=135  сред=2.751  мед=2.790  p95=3.241  макс=3.460 мс
                          доставлено 135 кадров за 1500 мс = 90.0 к/с из 90 (100%); промахов по бюджету нет
    N=50    draw calls движка=50     CPU n=135  сред=0.178  мед=0.169  p95=0.244  макс=0.261 мс
                          GPU n=135  сред=2.796  мед=2.774  p95=3.003  макс=3.143 мс
                          доставлено 135 кадров за 1501 мс = 89.9 к/с из 90 (100%); промахов по бюджету нет
    N=100   draw calls движка=100    CPU n=135  сред=0.252  мед=0.246  p95=0.293  макс=0.454 мс
                          GPU n=135  сред=3.229  мед=3.200  p95=3.582  макс=3.864 мс
                          доставлено 135 кадров за 1500 мс = 90.0 к/с из 90 (100%); промахов по бюджету нет
    N=200   draw calls движка=200    CPU n=135  сред=0.620  мед=0.503  p95=0.996  макс=1.207 мс
                          GPU n=135  сред=3.578  мед=3.530  p95=3.916  макс=4.173 мс
                          доставлено 135 кадров за 1500 мс = 90.0 к/с из 90 (100%); промахов по бюджету нет
    N=400   draw calls движка=400    CPU n=135  сред=0.566  мед=0.525  p95=0.723  макс=1.385 мс
                          GPU n=135  сред=4.332  мед=4.253  p95=4.822  макс=5.710 мс
                          доставлено 135 кадров за 1500 мс = 90.0 к/с из 90 (100%); промахов по бюджету нет
    N=800   draw calls движка=800    CPU n=135  сред=0.862  мед=0.861  p95=0.999  макс=1.113 мс
                          GPU n=135  сред=7.583  мед=7.906  p95=8.347  макс=8.508 мс
                          доставлено 135 кадров за 1500 мс = 90.0 к/с из 90 (100%); промахов по бюджету нет
    N=1600  draw calls движка=1600   CPU n=135  сред=1.924  мед=1.932  p95=2.150  макс=2.314 мс
                          GPU n=135  сред=9.301  мед=9.300  p95=9.556  макс=9.685 мс
                          доставлено 135 кадров за 1500 мс = 90.0 к/с из 90 (100%); промахов по бюджету нет
свип «инстансы»:
    N=0     draw calls движка=0      CPU n=135  сред=0.114  мед=0.109  p95=0.149  макс=0.210 мс
                          GPU n=135  сред=2.736  мед=2.694  p95=2.996  макс=3.789 мс
                          доставлено 135 кадров за 1501 мс = 89.9 к/с из 90 (100%); промахов по бюджету нет
    N=50    draw calls движка=1      CPU n=135  сред=0.139  мед=0.135  p95=0.159  макс=0.215 мс
                          GPU n=135  сред=2.918  мед=2.874  p95=3.200  макс=3.512 мс
                          доставлено 135 кадров за 1500 мс = 90.0 к/с из 90 (100%); промахов по бюджету нет
    N=100   draw calls движка=1      CPU n=135  сред=0.141  мед=0.137  p95=0.167  макс=0.214 мс
                          GPU n=135  сред=2.964  мед=2.915  p95=3.271  макс=4.220 мс
                          доставлено 135 кадров за 1500 мс = 90.0 к/с из 90 (100%); промахов по бюджету нет
    N=200   draw calls движка=1      CPU n=135  сред=0.143  мед=0.138  p95=0.181  макс=0.230 мс
                          GPU n=135  сред=2.947  мед=2.909  p95=3.201  макс=4.163 мс
                          доставлено 135 кадров за 1500 мс = 90.0 к/с из 90 (100%); промахов по бюджету нет
    N=400   draw calls движка=1      CPU n=135  сред=0.147  мед=0.141  p95=0.188  макс=0.258 мс
                          GPU n=135  сред=2.934  мед=2.899  p95=3.099  макс=3.425 мс
                          доставлено 135 кадров за 1500 мс = 90.0 к/с из 90 (100%); промахов по бюджету нет
    N=800   draw calls движка=1      CPU n=135  сред=0.144  мед=0.137  p95=0.181  макс=0.342 мс
                          GPU n=135  сред=2.961  мед=2.909  p95=3.245  макс=3.744 мс
                          доставлено 135 кадров за 1500 мс = 90.0 к/с из 90 (100%); промахов по бюджету нет
    N=1600  draw calls движка=1      CPU n=136  сред=0.141  мед=0.135  p95=0.176  макс=0.257 мс
                          GPU n=136  сред=2.984  мед=2.945  p95=3.215  макс=3.814 мс
                          доставлено 136 кадров за 1508 мс = 90.2 к/с из 90 (100%); промахов по бюджету нет

разброс двух прогонов на N=100: 0.016 мс (0.239 против 0.255)
  PASS  разрешение свипа: разброс 0.016 мс меньше шага 1.829 мс (в 114 раз) — наклону можно верить
  PASS  нулевой контроль: пустая сцена CPU 0.103 / GPU 2.790 мс, связывает GPU — 25% бюджета 11.11 мс, запас есть
  PASS  гейт «небатченый»: ΔN=1600 → Δdraw calls=1600 (1.00 на объект) — случай задевает гейт
  PASS  гейт «инстансы»: ΔN=1600, Δdraw calls=1 — инстансинг работает, режимы различаются
  PASS  частота устойчива: 90.0 Гц от начала до конца свипов
  PASS  разогрев PSO: пик первых 90 кадров выше установившегося на 5.539 мс (макс 5.785 против мед 0.246)
  PASS  наклон «небатченый»: CPU 1.143 мкс/ед., GPU 4.069 мкс/ед. — связывает GPU (Δ на ΔN=1600)
  PASS  наклон «инстансы»: CPU 0.016 мкс/ед., GPU 0.157 мкс/ед. — связывает GPU (Δ на ΔN=1600)

--- M. Частотная матрица ---
ступени: [72.0, 90.0, 72.0, 90.0] Гц; свип [0, 400, 1600]; канарейка N=400
порядок с повтором отделяет частоту от прогрева: эффект частоты переворачивается, эффект прогрева — нет
  PASS  фальсификатор частоты: 240 Гц нет в лестнице → отказ замечен, работаем на 90.0

ступень 0: запрошено 72, получено 72.0 Гц, бюджет 13.89 мс
    база GPU 2.708 мс, при N=1600 GPU 10.369 / CPU 1.708 мс, мкс на вызов 4.788
    доставлено 109 кадров за 1513 мс = 72.0 к/с из 72 (100%); промахов по бюджету нет
    клок: резиденция недоступна

ступень 1: запрошено 90, получено 90.0 Гц, бюджет 11.11 мс
    база GPU 2.626 мс, при N=1600 GPU 9.353 / CPU 1.908 мс, мкс на вызов 4.204
    доставлено 135 кадров за 1500 мс = 90.0 к/с из 90 (100%); промахов по бюджету нет
    клок: резиденция недоступна

ступень 2: запрошено 72, получено 72.0 Гц, бюджет 13.89 мс
    база GPU 3.374 мс, при N=1600 GPU 10.461 / CPU 1.733 мс, мкс на вызов 4.429
    доставлено 108 кадров за 1500 мс = 72.0 к/с из 72 (100%); промахов по бюджету нет
    клок: резиденция недоступна

ступень 3: запрошено 90, получено 90.0 Гц, бюджет 11.11 мс
    база GPU 2.626 мс, при N=1600 GPU 9.251 / CPU 1.897 мс, мкс на вызов 4.141
    доставлено 135 кадров за 1500 мс = 90.0 к/с из 90 (100%); промахов по бюджету нет
    клок: резиденция недоступна
сырые ступени: /data/data/org.flamti.vrge.probe/files/freq_matrix.tsv
  PASS  все 4 ступеней дали запрошенную частоту
  PASS  частота против доставки: на всех 4 ступенях кадры подтверждают заявленную частоту
  PASS  состояние рендера НЕ менялось между ступенями — объяснения аномалии через фовеацию и через разрешение буфера ИСКЛЮЧЕНЫ
  ????  резиденция частот: ни один счётчик не сдвинулся — прибор слеп, судить о разгоне нечем

наклон по ступеням, мкс на вызов: 72 Гц 4.788 и 4.429; 90 Гц 4.204 и 4.141
    среднее 72 Гц 4.609, 90 Гц 4.173, разница 0.436; разброс внутри частоты 0.359
  FAIL  значимость: разница между частотами 0.436 мкс НЕ превышает вдвое разброс внутри частоты 0.359 — на этих данных удвоение цены draw call не воспроизводится
    приращения по ряду ступеней: -0.584, +0.225, -0.289
  PASS  принадлежность: ряд пилообразный, знак меняется на каждой смене частоты — эффект принадлежит ЧАСТОТЕ, а не времени
канарейка N=400, GPU мед по ступеням: 3.880@72Гц, 3.941@90Гц, 3.900@72Гц, 3.913@90Гц мс
    дрейф между повторами одной частоты: 72 Гц +0.5%, 90 Гц -0.7%
  PASS  канарейка: наибольший дрейф между повторами одной частоты -0.7% (на 90 Гц) — условия за матрицу не уехали

--- P. Цена пикселя ---
вьюпорт 1680x1760 = 2.96 Мпикс; слоёв 8, тест глубины выключен

на 72.0 Гц (запрошено 72), бюджет 13.89 мс:
    размер 0.00 м → затеняется 0.00 Мпикс, GPU мед 3.399 мс
    размер 0.50 м → затеняется 0.02 Мпикс, GPU мед 2.741 мс
    размер 1.00 м → затеняется 0.06 Мпикс, GPU мед 2.750 мс
    размер 2.00 м → затеняется 0.25 Мпикс, GPU мед 2.784 мс
    размер 4.00 м → затеняется 1.02 Мпикс, GPU мед 2.851 мс

на 90.0 Гц (запрошено 90), бюджет 11.11 мс:
    размер 0.00 м → затеняется 0.00 Мпикс, GPU мед 2.909 мс
    размер 0.50 м → затеняется 0.02 Мпикс, GPU мед 2.926 мс
    размер 1.00 м → затеняется 0.06 Мпикс, GPU мед 2.943 мс
    размер 2.00 м → затеняется 0.25 Мпикс, GPU мед 2.957 мс
    размер 4.00 м → затеняется 1.00 Мпикс, GPU мед 3.039 мс
  PASS  гейт покрытия: затеняемых пикселей от 0.00 до 1.02 Мпикс (с обрезкой по вьюпорту и 8 слоями)
  FAIL  гейт роста GPU: 3.399 → 2.851 мс, рост меньше 20% — пиксели не связывают, цена пикселя недостоверна
  ????  цена пикселя на 72.0 Гц: гейт не пройден, наклон не докладываю
  ????  цена пикселя на 90.0 Гц: гейт не пройден, наклон не докладываю
  ????  цена пикселя между частотами: гейт не пройден, сравнивать нечего

фаза E пропущена (маркер user://skip_sustained или флаг)

passed=50 failed=4 unknown=8
пол: исполнено 62/62 проверок
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
