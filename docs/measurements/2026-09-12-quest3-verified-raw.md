# Паспорт железа — сырой вывод прибора

- дата: 2026-09-12T16:27:47
- устройство: Adreno (TM) 740
- вендор: Qualcomm
- Vulkan API: 1.3.295
- OpenXR активен: true

## Измеренные числа
```
мкс на draw call (небатченый):  1.051
мкс на инстанс:                 0.019
цена разогрева PSO, мс:         7.049
разброс прогонов, мс:           0.007
троттлинг, секунда сброса:      не наблюдался
прогон фазы E, с:               0 из 0
```

## Вердикт
```
=== ПАСПОРТ ЖЕЛЕЗА ===
ожидается исполненных проверок: 41

  PASS  XR-вьюпорт: включён, рендер идёт в шлем
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

лимиты устройства:
    MAX_FRAMEBUFFER_WIDTH        16384
    MAX_FRAMEBUFFER_HEIGHT       16384
    MAX_TEXTURE_ARRAY_LAYERS     2048
    MAX_UNIFORM_BUFFER_SIZE      65536
    MAX_PUSH_CONSTANT_SIZE       256

--- C–D. Стоимость отрисовки ---
частота обновления: 72.0 Гц, кадровый бюджет: 13.89 мс
разогрев отбрасывается: 30 кадров; статистика по 60 кадрам

свип «небатченый»:
    N=0     draw calls движка=0      CPU n=60  сред=0.108  мед=0.101  p95=0.149  макс=0.191 мс
                          GPU n=60  сред=2.376  мед=2.390  p95=2.719  макс=3.425 мс
    N=50    draw calls движка=50     CPU n=60  сред=0.178  мед=0.174  p95=0.208  макс=0.281 мс
                          GPU n=60  сред=2.842  мед=2.889  p95=3.290  макс=3.526 мс
    N=100   draw calls движка=100    CPU n=60  сред=0.231  мед=0.226  p95=0.273  макс=0.347 мс
                          GPU n=60  сред=3.026  мед=2.936  p95=3.465  макс=3.663 мс
    N=200   draw calls движка=200    CPU n=60  сред=0.349  мед=0.342  p95=0.421  макс=0.500 мс
                          GPU n=60  сред=3.603  мед=3.558  p95=4.065  макс=4.360 мс
    N=400   draw calls движка=400    CPU n=60  сред=0.546  мед=0.538  p95=0.603  макс=1.003 мс
                          GPU n=60  сред=4.412  мед=4.362  p95=4.808  макс=5.369 мс
    N=800   draw calls движка=800    CPU n=60  сред=1.224  мед=1.209  p95=1.749  макс=3.786 мс
                          GPU n=60  сред=5.699  мед=5.423  p95=6.405  макс=7.388 мс
    N=1600  draw calls движка=1600   CPU n=60  сред=1.799  мед=1.783  p95=2.016  макс=2.289 мс
                          GPU n=60  сред=10.675  мед=10.931  p95=11.191  макс=11.490 мс
свип «инстансы»:
    N=0     draw calls движка=0      CPU n=60  сред=0.112  мед=0.109  p95=0.132  макс=0.163 мс
                          GPU n=60  сред=2.628  мед=2.619  p95=2.669  макс=2.806 мс
    N=50    draw calls движка=1      CPU n=60  сред=0.140  мед=0.136  p95=0.168  макс=0.200 мс
                          GPU n=60  сред=2.725  мед=2.705  p95=2.864  макс=2.955 мс
    N=100   draw calls движка=1      CPU n=60  сред=0.144  мед=0.140  p95=0.164  макс=0.259 мс
                          GPU n=60  сред=2.787  мед=2.703  p95=2.988  макс=4.864 мс
    N=200   draw calls движка=1      CPU n=60  сред=0.147  мед=0.140  p95=0.177  макс=0.218 мс
                          GPU n=60  сред=2.755  мед=2.733  p95=3.041  макс=3.139 мс
    N=400   draw calls движка=1      CPU n=60  сред=0.146  мед=0.143  p95=0.179  макс=0.238 мс
                          GPU n=60  сред=2.760  мед=2.716  p95=2.917  макс=3.297 мс
    N=800   draw calls движка=1      CPU n=60  сред=0.142  мед=0.138  p95=0.164  макс=0.180 мс
                          GPU n=60  сред=2.800  мед=2.730  p95=2.969  макс=4.662 мс
    N=1600  draw calls движка=1      CPU n=60  сред=0.147  мед=0.140  p95=0.188  макс=0.232 мс
                          GPU n=60  сред=2.794  мед=2.750  p95=3.139  макс=3.292 мс

разброс двух прогонов на N=100: 0.007 мс (0.255 против 0.248)
  PASS  разрешение свипа: разброс 0.007 мс меньше шага 1.682 мс (в 240 раз) — наклону можно верить
  PASS  нулевой контроль: пустая сцена 0.101 мс — меньше половины бюджета, запас есть
  PASS  гейт «небатченый»: ΔN=1600 → Δdraw calls=1600 (1.00 на объект) — случай задевает гейт
  PASS  гейт «инстансы»: ΔN=1600, Δdraw calls=1 — инстансинг работает, режимы различаются
  PASS  частота устойчива: 72.0 Гц от начала до конца свипов
  PASS  разогрев PSO: пик первых 30 кадров выше установившегося на 7.049 мс (макс 7.275 против мед 0.226)
  PASS  наклон «небатченый»: CPU 1.051 мкс/ед., GPU 5.338 мкс/ед. — связывает GPU (Δ на ΔN=1600)
  PASS  наклон «инстансы»: CPU 0.019 мкс/ед., GPU 0.082 мкс/ед. — связывает GPU (Δ на ΔN=1600)

фаза E пропущена (маркер user://skip_sustained или флаг)

passed=39 failed=2 unknown=0
пол: исполнено 41/41 проверок
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
