# Паспорт железа — сырой вывод прибора

- дата: 2026-09-13T00:42:46
- устройство: Adreno (TM) 740
- вендор: Qualcomm
- Vulkan API: 1.3.295
- OpenXR активен: true
- частота: 120.0 Гц, кадровый бюджет: 8.33 мс

## Измеренные числа
```
мкс на draw call (небатченый):  1.106
мкс на инстанс:                 не измерено
цена разогрева PSO, мс:         5.971
разброс прогонов, мс:           0.219
буфер глаза:                    1680x1760
фовеация (уровень/динамика):    0 / false
троттлинг, секунда сброса:      не наблюдался
прогон фазы E, с:               0 из 0
```

## Частотная матрица
```
ступень	запрошено	получено	мкс/вызов GPU	база GPU мс	буфер
0	72	72.0	5.041	2.612	1680x1760
1	120	120.0	3.089	3.289	1680x1760
2	72	72.0	5.418	2.611	1680x1760
3	120	120.0	2.922	3.629	1680x1760
```

## Цена пикселя
```
72.0 Гц: 1.945 мкс на Мпиксель
120.0 Гц: 3.109 мкс на Мпиксель
```

## Вердикт
```
=== ПАСПОРТ ЖЕЛЕЗА ===
ожидается исполненных проверок: 63

  PASS  XR-вьюпорт: включён, рендер идёт в шлем

--- B0. Частота кадров (ADR-0006) ---
доступные частоты: [72.0, 80.0, 90.0, 120.0]
бюджет кадра: 8.33 мс при 120.0 Гц — ВСЕ числа ниже относятся к этой частоте
  PASS  частота: запрошен максимум 120.0 Гц — получено 120.0 (было 72.0), ждали 88 мс
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
частота обновления: 120.0 Гц, кадровый бюджет: 8.33 мс
окно: 1.0 с разогрева + 1.5 с замера по стенным часам (число кадров — результат, не настройка)

свип «небатченый»:
    N=0     draw calls движка=0      CPU n=180  сред=0.111  мед=0.099  p95=0.192  макс=0.243 мс
                          GPU n=180  сред=3.220  мед=3.148  p95=4.010  макс=5.501 мс
                          доставлено 180 кадров за 1502 мс = 119.8 к/с из 120 (100%); промахов по бюджету нет
    N=50    draw calls движка=50     CPU n=180  сред=0.188  мед=0.173  p95=0.292  макс=0.648 мс
                          GPU n=180  сред=3.360  мед=3.423  p95=3.821  макс=4.059 мс
                          доставлено 180 кадров за 1501 мс = 119.9 к/с из 120 (100%); промахов по бюджету нет
    N=100   draw calls движка=100    CPU n=180  сред=0.535  мед=0.409  p95=0.972  макс=1.035 мс
                          GPU n=180  сред=4.177  мед=4.125  p95=4.579  макс=5.386 мс
                          доставлено 180 кадров за 1501 мс = 119.9 к/с из 120 (100%); промахов по бюджету нет
    N=200   draw calls движка=200    CPU n=180  сред=0.334  мед=0.319  p95=0.410  макс=1.004 мс
                          GPU n=180  сред=5.120  мед=4.811  p95=6.056  макс=6.478 мс
                          доставлено 180 кадров за 1500 мс = 120.0 к/с из 120 (100%); промахов по бюджету нет
    N=400   draw calls движка=400    CPU n=181  сред=0.487  мед=0.460  p95=0.747  макс=0.978 мс
                          GPU n=181  сред=5.492  мед=5.895  p95=6.150  макс=6.278 мс
                          доставлено 181 кадров за 1507 мс = 120.1 к/с из 120 (100%); промахов по бюджету нет
    N=800   draw calls движка=800    CPU n=180  сред=0.826  мед=0.810  p95=0.990  макс=1.981 мс
                          GPU n=180  сред=6.444  мед=6.449  p95=6.700  макс=6.869 мс
                          доставлено 180 кадров за 1500 мс = 120.0 к/с из 120 (100%); промахов по бюджету нет
    N=1600  draw calls движка=1600   CPU n=180  сред=1.876  мед=1.869  p95=2.109  макс=2.360 мс
                          GPU n=180  сред=8.325  мед=8.316  p95=8.495  макс=8.642 мс
                          доставлено 180 кадров за 1501 мс = 119.9 к/с из 120 (100%); сверх бюджета 73 (40.6%), самая длинная серия 8 подряд
свип «инстансы»:
    N=0     draw calls движка=0      CPU n=181  сред=0.184  мед=0.114  p95=0.455  макс=0.554 мс
                          GPU n=181  сред=2.534  мед=2.377  p95=3.468  макс=3.792 мс
                          доставлено 181 кадров за 1507 мс = 120.1 к/с из 120 (100%); промахов по бюджету нет
    N=50    draw calls движка=1      CPU n=180  сред=0.135  мед=0.119  p95=0.296  макс=0.520 мс
                          GPU n=180  сред=3.047  мед=3.177  p95=3.631  макс=3.784 мс
                          доставлено 180 кадров за 1501 мс = 119.9 к/с из 120 (100%); промахов по бюджету нет
    N=100   draw calls движка=1      CPU n=180  сред=0.145  мед=0.136  p95=0.168  макс=0.867 мс
                          GPU n=180  сред=3.804  мед=3.776  p95=4.147  макс=4.393 мс
                          доставлено 180 кадров за 1500 мс = 120.0 к/с из 120 (100%); промахов по бюджету нет
    N=200   draw calls движка=1      CPU n=180  сред=0.149  мед=0.140  p95=0.196  макс=0.631 мс
                          GPU n=180  сред=3.762  мед=3.801  p95=4.183  макс=4.409 мс
                          доставлено 180 кадров за 1500 мс = 120.0 к/с из 120 (100%); промахов по бюджету нет
    N=400   draw calls движка=1      CPU n=180  сред=0.152  мед=0.142  p95=0.195  макс=0.753 мс
                          GPU n=180  сред=3.797  мед=3.773  p95=4.173  макс=4.437 мс
                          доставлено 180 кадров за 1502 мс = 119.8 к/с из 120 (100%); промахов по бюджету нет
    N=800   draw calls движка=1      CPU n=181  сред=0.164  мед=0.136  p95=0.373  макс=0.698 мс
                          GPU n=181  сред=3.527  мед=3.750  p95=4.211  макс=4.392 мс
                          доставлено 181 кадров за 1508 мс = 120.0 к/с из 120 (100%); промахов по бюджету нет
    N=1600  draw calls движка=1      CPU n=180  сред=0.160  мед=0.138  p95=0.197  макс=0.850 мс
                          GPU n=180  сред=3.912  мед=3.855  p95=4.285  макс=4.552 мс
                          доставлено 180 кадров за 1500 мс = 120.0 к/с из 120 (100%); промахов по бюджету нет

разброс двух прогонов на N=100: 0.219 мс (0.439 против 0.220)
  PASS  разрешение свипа: разброс 0.219 мс меньше шага 1.770 мс (в 8 раз) — наклону можно верить
  PASS  нулевой контроль: пустая сцена CPU 0.099 / GPU 3.148 мс, связывает GPU — 38% бюджета 8.33 мс, запас есть
  PASS  гейт «небатченый»: ΔN=1600 → Δdraw calls=1600 (1.00 на объект) — случай задевает гейт
  PASS  гейт «инстансы»: ΔN=1600, Δdraw calls=1 — инстансинг работает, режимы различаются
  PASS  частота устойчива: 120.0 Гц от начала до конца свипов
  PASS  разогрев PSO: пик первых 120 кадров выше установившегося на 5.971 мс (макс 6.380 против мед 0.409)
  PASS  наклон «небатченый»: CPU 1.106 мкс/ед., GPU 3.230 мкс/ед. — связывает GPU (Δ на ΔN=1600)
  FAIL  наклон «инстансы»: разброс прогонов 0.219 мс БОЛЬШЕ роста по свипу 0.024 мс — разрешение ниже шума, число недостоверно

--- M. Частотная матрица ---
ступени: [72.0, 120.0, 72.0, 120.0] Гц; свип [0, 400, 1600]; канарейка N=400
порядок с повтором отделяет частоту от прогрева: эффект частоты переворачивается, эффект прогрева — нет
  PASS  фальсификатор частоты: 240 Гц нет в лестнице → отказ замечен, работаем на 120.0
  FAIL  потолок: перечисление отдаёт максимум 120 Гц, но 144 Гц работают и подтверждены доставкой 144.1 к/с — лестница ЗАНИЖАЕТ потолок, бюджет на нём 6.94 мс

ступень 0: запрошено 72, получено 72.0 Гц, бюджет 13.89 мс
    база GPU 2.612 мс, при N=1600 GPU 10.678 / CPU 1.712 мс, мкс на вызов 5.041
    доставлено 108 кадров за 1500 мс = 72.0 к/с из 72 (100%); промахов по бюджету нет
    клок: резиденция недоступна

ступень 1: запрошено 120, получено 120.0 Гц, бюджет 8.33 мс
    база GPU 3.289 мс, при N=1600 GPU 8.232 / CPU 1.905 мс, мкс на вызов 3.089
    доставлено 180 кадров за 1504 мс = 119.7 к/с из 120 (100%); сверх бюджета 58 (32.2%), самая длинная серия 4 подряд
    клок: резиденция недоступна

ступень 2: запрошено 72, получено 72.0 Гц, бюджет 13.89 мс
    база GPU 2.611 мс, при N=1600 GPU 11.280 / CPU 1.764 мс, мкс на вызов 5.418
    доставлено 109 кадров за 1514 мс = 72.0 к/с из 72 (100%); промахов по бюджету нет
    клок: резиденция недоступна

ступень 3: запрошено 120, получено 120.0 Гц, бюджет 8.33 мс
    база GPU 3.629 мс, при N=1600 GPU 8.304 / CPU 1.796 мс, мкс на вызов 2.922
    доставлено 180 кадров за 1503 мс = 119.8 к/с из 120 (100%); сверх бюджета 73 (40.6%), самая длинная серия 22 подряд
    клок: резиденция недоступна
сырые ступени: /data/data/org.flamti.vrge.probe/files/freq_matrix.tsv
  PASS  все 4 ступеней дали запрошенную частоту
  PASS  частота против доставки: на всех 4 ступенях кадры подтверждают заявленную частоту
  PASS  состояние рендера НЕ менялось между ступенями — объяснения аномалии через фовеацию и через разрешение буфера ИСКЛЮЧЕНЫ
  ????  резиденция частот: ни один счётчик не сдвинулся — прибор слеп, судить о разгоне нечем

наклон по ступеням, мкс на вызов: 72 Гц 5.041 и 5.418; 120 Гц 3.089 и 2.922
    среднее 72 Гц 5.230, 120 Гц 3.006, разница 2.224; разброс внутри частоты 0.377
  PASS  значимость: разница между частотами 2.224 мкс вдвое превышает разброс внутри частоты 0.377 — разница настоящая
    приращения по ряду ступеней: -1.952, +2.329, -2.496
  PASS  принадлежность: ряд пилообразный, знак меняется на каждой смене частоты — эффект принадлежит ЧАСТОТЕ, а не времени
канарейка N=400, GPU мед по ступеням: 4.148@72Гц, 4.157@120Гц, 4.321@72Гц, 6.231@120Гц мс
  FAIL  канарейка: худшая ступень +50.2% от первой — за время матрицы условия уехали, ступени сравнивать опасно

--- P. Цена пикселя ---

на 72.0 Гц (запрошено 72), бюджет 13.89 мс:
    размер 0.00 м → покрытие 0.000 Мпикс, GPU мед 3.207 мс
    размер 1.00 м → покрытие 0.103 Мпикс, GPU мед 2.976 мс
    размер 2.50 м → покрытие 0.712 Мпикс, GPU мед 3.057 мс
    размер 5.00 м → покрытие 3.886 Мпикс, GPU мед 3.295 мс
    размер 9.00 м → покрытие 63.757 Мпикс, GPU мед 3.331 мс
  PASS  цена пикселя на 72.0 Гц: **1.9 мкс на Мпиксель**

на 120.0 Гц (запрошено 120), бюджет 8.33 мс:
    размер 0.00 м → покрытие 0.000 Мпикс, GPU мед 3.784 мс
    размер 1.00 м → покрытие 0.101 Мпикс, GPU мед 3.768 мс
    размер 2.50 м → покрытие 0.697 Мпикс, GPU мед 3.817 мс
    размер 5.00 м → покрытие 3.806 Мпикс, GPU мед 3.942 мс
    размер 9.00 м → покрытие 62.720 Мпикс, GPU мед 3.979 мс
  PASS  цена пикселя на 120.0 Гц: **3.1 мкс на Мпиксель**
  PASS  гейт покрытия: пиксели растут вместе с размером, от 0.000 до 63.757 Мпикс
  FAIL  гейт роста GPU: 3.207 → 3.331 мс, рост меньше 20% — пиксели не связывают, цена пикселя недостоверна

цена пикселя: 1.9 мкс/Мпикс на 72 Гц против 3.1 на 120 Гц, отношение 1.60
  FAIL  цена пикселя зависит от частоты (отношение 1.60) — затенение тоже переменная, версия «только геометрия» не проходит

фаза E пропущена (маркер user://skip_sustained или флаг)

passed=51 failed=7 unknown=5
пол: исполнено 63/63 проверок
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
