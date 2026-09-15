# Паспорт железа — сырой вывод прибора

- дата: 2026-09-15T06:48:59
- устройство: Adreno (TM) 740
- вендор: Qualcomm
- Vulkan API: 1.3.295
- OpenXR активен: true
- частота: 90.0 Гц, кадровый бюджет: 11.11 мс

## Измеренные числа
```
мкс на draw call (небатченый):  не измерено
мкс на инстанс:                 не измерено
цена разогрева PSO, мс:         не измерено (пик N=100 фазы C–D; компиляцией не подтверждён — см. W)
старт до _ready, мс:            1576 (baker выкл)
W: компиляций DRAW новый/повтор: 1 / 1, пик 6.738 мс
разброс прогонов, мс:           не измерено
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
не измерялась
```

## Вердикт
```
=== ПАСПОРТ ЖЕЛЕЗА ===
frame synthesis: расширение активно — синтез ВЫКЛЮЧЕН для штатных фаз
ожидается исполненных проверок: 54

  PASS  XR-вьюпорт: включён, рендер идёт в шлем

--- B0. Частота кадров (ADR-0007: цель 90, минимум 72 Гц) ---
доступные частоты: [72.0, 80.0, 90.0, 120.0] (перечисление НЕисчерпывающе по замыслу вендора)
бюджет кадра: 11.11 мс при 90.0 Гц — ВСЕ числа ниже относятся к этой частоте
  PASS  частота: запрошена цель 90.0 Гц — получено 90.0 (было 72.0), ждали 42 мс
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
  PASS  xr_ext: XR_EXT_hand_interaction
  PASS  xr_ext: XR_FB_hand_tracking_mesh
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

--- W. Компиляция конвейеров (PSO) ---
сборка: shader baker выкл (res://.godot/shader_cache в пакете)
  PASS  W старт: 1576 мс от запуска движка до _ready; компиляций к этому моменту { "canvas": 0, "mesh": 0, "surface": 0, "draw": 0, "specialization": 0 }; baker выкл
  PASS  W новый вариант: компиляции за 30 кадров { "canvas": 0, "mesh": 0, "surface": 2, "draw": 1, "specialization": 1 } (позже ещё { "canvas": 0, "mesh": 0, "surface": 0, "draw": 0, "specialization": 0 }); пик CPU 6.884 / GPU 4.483 против установившихся 0.146 / 3.256 мс — цена 6.738 мс
  FAIL  W контроль повтора: пик 5.509 мс против 6.738 в первый раз — кэш не снял цену, пик первого эпизода НЕ подтверждён как компиляция; счётчики { "canvas": 0, "mesh": 0, "surface": 2, "draw": 1, "specialization": 1 }
  ????  W2 предзагрузка: контроль B без пика компиляции — кэш тёплый, сравнивать нечего. A (.tres на поверхности, предзагружен): пик 5.448 мс, компиляции { "canvas": 0, "mesh": 0, "surface": 0, "draw": 1, "specialization": 1 }; B (override из .tres, без предзагрузки): пик 5.746 мс, компиляции { "canvas": 0, "mesh": 0, "surface": 4, "draw": 1, "specialization": 1 }; baker выкл

фаза C–D пропущена (маркер user://skip_draws)

фаза M пропущена (маркер user://skip_matrix)

фаза P пропущена (маркер user://skip_fill)

фаза L пропущена (маркер user://skip_layers)

фаза L4 пропущена (маркер user://skip_msaa_sweep)

--- S. Frame synthesis (XR_EXT_frame_synthesis, ADR-0003 открыто) ---
частота 90.0 Гц, бюджет 11.11 мс; режимы ["выкл", "вкл", "вкл+relax"] в порядке ["выкл", "вкл", "вкл+relax", "вкл+relax", "вкл", "выкл"]; точки [0, 1600]
  PASS  S доступность: расширение активно (is_available=true)
  режим выкл (повтор 1):
    N=0     отрисовок 0     GPU 3.279  CPU 0.128 мс; доставлено 135 кадров за 1501 мс = 89.9 к/с из 90 (100%); промахов по бюджету нет
    N=1600  отрисовок 1600  GPU 9.473  CPU 1.891 мс; доставлено 135 кадров за 1500 мс = 90.0 к/с из 90 (100%); промахов по бюджету нет
  режим вкл (повтор 1):
    N=0     отрисовок 0     GPU 2.808  CPU 0.119 мс; доставлено 135 кадров за 1501 мс = 89.9 к/с из 90 (100%); промахов по бюджету нет
    N=1600  отрисовок 1600  GPU 12.979  CPU 2.158 мс; доставлено 115 кадров за 1502 мс = 76.6 к/с из 90 (85%); сверх бюджета 115 (100.0%), самая длинная серия 115 подряд
  режим вкл+relax (повтор 1):
    N=0     отрисовок 0     GPU 3.635  CPU 0.208 мс; доставлено 68 кадров за 1511 мс = 45.0 к/с из 90 (50%); промахов по бюджету нет
    N=1600  отрисовок 1600  GPU 17.539  CPU 2.849 мс; доставлено 68 кадров за 1509 мс = 45.1 к/с из 90 (50%); сверх бюджета 68 (100.0%), самая длинная серия 68 подряд
  режим вкл+relax (повтор 2):
    N=0     отрисовок 0     GPU 3.648  CPU 0.173 мс; доставлено 68 кадров за 1511 мс = 45.0 к/с из 90 (50%); промахов по бюджету нет
    N=1600  отрисовок 1600  GPU 17.483  CPU 2.891 мс; доставлено 68 кадров за 1511 мс = 45.0 к/с из 90 (50%); сверх бюджета 68 (100.0%), самая длинная серия 68 подряд
  режим вкл (повтор 2):
    N=0     отрисовок 0     GPU 2.806  CPU 0.118 мс; доставлено 135 кадров за 1500 мс = 90.0 к/с из 90 (100%); промахов по бюджету нет
    N=1600  отрисовок 1600  GPU 13.136  CPU 2.537 мс; доставлено 114 кадров за 1500 мс = 76.0 к/с из 90 (84%); сверх бюджета 114 (100.0%), самая длинная серия 114 подряд
  режим выкл (повтор 2):
    N=0     отрисовок 0     GPU 2.633  CPU 0.105 мс; доставлено 135 кадров за 1500 мс = 90.0 к/с из 90 (100%); промахов по бюджету нет
    N=1600  отрисовок 1600  GPU 8.943  CPU 1.863 мс; доставлено 135 кадров за 1500 мс = 90.0 к/с из 90 (100%); промахов по бюджету нет
окна фазы: /data/data/org.flamti.vrge.probe/files/synthesis.tsv — свод с VrApi: tools/join_windows.py --vrapi
  PASS  S гейт состояния: enabled и relax вставали в каждый режим
  PASS  S гейт счётчика: все точки дали ровно N отрисовок
  PASS  S контроль порядка: «выкл» в начале и в конце на N=1600 расходятся на 5.9% — в пределах дрейфа 15%
  PASS  S доставка: выкл 90.0 к/с (100%); вкл 83.1 к/с (92%); вкл+relax 45.0 к/с (50%) — пониженная частота приложения в режимах ["вкл+relax"] — синтез работает
  PASS  S цена на кадр приложения (GPU против «выкл», порог — два разброса «выкл»): N=0 вкл -0.149 мс в шуме; N=0 вкл+relax +0.686 мс в шуме; N=1600 вкл +3.850 мс ЗНАЧИМО; N=1600 вкл+relax +8.303 мс ЗНАЧИМО

S визуально v2: 40 с, режим каждые 5 с. Квадрат слева ЗЕЛЁНЫЙ — синтез relax (45 к/с приложения), КРАСНЫЙ — без синтеза (90)
    0 с (unix 1789436900.0): СИНТЕЗ relax (зелёный)
    5 с (unix 1789436904.6): БЕЗ синтеза (красный)
    10 с (unix 1789436909.6): СИНТЕЗ relax (зелёный)
    15 с (unix 1789436914.6): БЕЗ синтеза (красный)
    20 с (unix 1789436919.6): СИНТЕЗ relax (зелёный)
    25 с (unix 1789436924.6): БЕЗ синтеза (красный)
    30 с (unix 1789436929.6): СИНТЕЗ relax (зелёный)
    35 с (unix 1789436934.6): БЕЗ синтеза (красный)

фаза E пропущена (маркер user://skip_sustained или флаг)

passed=46 failed=3 unknown=5
пол: исполнено 54/54 проверок
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
