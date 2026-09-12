# Паспорт железа — сырой вывод прибора

- дата: 2026-09-12T15:54:49
- устройство: Adreno (TM) 740
- вендор: Qualcomm
- Vulkan API: 1.3.295
- OpenXR активен: true

## Измеренные числа
```
мкс на draw call (небатченый):  1.039
мкс на инстанс:                 0.019
цена разогрева PSO, мс:         3.593
разброс прогонов, мс:           0.004
троттлинг, секунда сброса:      не наблюдался
прогон фазы E, с:               1080 из 1080
```

## Вердикт
```
=== ПАСПОРТ ЖЕЛЕЗА ===
ожидается исполненных проверок: 45

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
  FAIL  движок: SUPPORTS_ATTACHMENT_VRS — НЕ включено, а это критично для VR-рендера. Доступность расширения тут не поможет
  PASS  движок: SUPPORTS_BUFFER_DEVICE_ADDRESS — включено
  PASS  движок: SUPPORTS_FRAGMENT_SHADER_WITH_ONLY_SIDE_EFFECTS — включено
  PASS  движок: SUPPORTS_FRAMEBUFFER_DEPTH_RESOLVE — включено (критично для VR)
  PASS  движок: SUPPORTS_HALF_FLOAT — включено
  PASS  движок: SUPPORTS_HDR_OUTPUT — включено
  PASS  движок: SUPPORTS_IMAGE_ATOMIC_32_BIT — включено
  FAIL  движок: SUPPORTS_MULTIVIEW — НЕ включено, а это критично для VR-рендера. Доступность расширения тут не поможет
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
    N=0     draw calls движка=0      CPU n=60  сред=0.108  мед=0.104  p95=0.136  макс=0.178 мс
                          GPU n=60  сред=2.645  мед=2.432  p95=3.882  макс=4.416 мс
    N=50    draw calls движка=50     CPU n=60  сред=0.191  мед=0.188  p95=0.221  макс=0.270 мс
                          GPU n=60  сред=3.099  мед=3.048  p95=3.261  макс=4.357 мс
    N=100   draw calls движка=100    CPU n=60  сред=0.224  мед=0.219  p95=0.294  макс=0.304 мс
                          GPU n=60  сред=2.778  мед=2.728  p95=3.188  макс=3.330 мс
    N=200   draw calls движка=200    CPU n=60  сред=0.313  мед=0.306  p95=0.361  макс=0.378 мс
                          GPU n=60  сред=3.241  мед=3.238  p95=3.268  макс=3.310 мс
    N=400   draw calls движка=400    CPU n=60  сред=0.465  мед=0.460  p95=0.530  макс=0.588 мс
                          GPU n=60  сред=3.922  мед=3.998  p95=4.130  макс=4.326 мс
    N=800   draw calls движка=658    CPU n=60  сред=1.032  мед=1.033  p95=1.512  макс=1.676 мс
                          GPU n=60  сред=4.781  мед=5.145  p95=5.775  макс=6.035 мс
    N=1600  draw calls движка=1600   CPU n=60  сред=1.803  мед=1.767  p95=2.187  макс=2.957 мс
                          GPU n=60  сред=10.495  мед=10.507  p95=11.182  макс=11.454 мс
свип «инстансы»:
    N=0     draw calls движка=0      CPU n=60  сред=0.105  мед=0.103  p95=0.126  макс=0.139 мс
                          GPU n=60  сред=2.657  мед=2.613  p95=2.665  макс=4.018 мс
    N=50    draw calls движка=1      CPU n=60  сред=0.139  мед=0.132  p95=0.161  макс=0.248 мс
                          GPU n=60  сред=2.717  мед=2.705  p95=2.848  макс=2.995 мс
    N=100   draw calls движка=1      CPU n=60  сред=0.189  мед=0.139  p95=0.172  макс=1.899 мс
                          GPU n=60  сред=2.733  мед=2.708  p95=2.903  макс=2.991 мс
    N=200   draw calls движка=1      CPU n=60  сред=0.199  мед=0.140  p95=0.178  макс=3.452 мс
                          GPU n=60  сред=2.726  мед=2.692  p95=2.897  макс=3.052 мс
    N=400   draw calls движка=1      CPU n=60  сред=0.146  мед=0.141  p95=0.191  макс=0.206 мс
                          GPU n=60  сред=2.732  мед=2.708  p95=2.831  макс=3.047 мс
    N=800   draw calls движка=1      CPU n=60  сред=0.144  мед=0.140  p95=0.175  макс=0.214 мс
                          GPU n=60  сред=2.740  мед=2.715  p95=2.909  макс=3.073 мс
    N=1600  draw calls движка=1      CPU n=60  сред=0.141  мед=0.133  p95=0.171  макс=0.275 мс
                          GPU n=60  сред=2.984  мед=2.918  p95=3.353  макс=3.908 мс

разброс двух прогонов на N=100: 0.004 мс (0.241 против 0.245)
  PASS  нулевой контроль: пустая сцена 0.104 мс — меньше половины бюджета, запас есть
  PASS  гейт «небатченый»: ΔN=1600 → Δdraw calls=1600 (1.00 на объект) — случай задевает гейт
  PASS  гейт «инстансы»: ΔN=1600, Δdraw calls=1 — инстансинг работает, режимы различаются
  PASS  частота устойчива: 72.0 Гц от начала до конца свипов
  PASS  разогрев PSO: пик первых 30 кадров выше установившегося на 3.593 мс (макс 3.812 против мед 0.219)
  PASS  наклон «небатченый»: 1.039 мкс на единицу (Δ1.663 мс на ΔN=1600, CPU)
  PASS  наклон «инстансы»: 0.019 мкс на единицу (Δ0.030 мс на ΔN=1600, CPU)

--- E. Длинный прогон: троттлинг ---
план: 18 минут, выборка раз в 1 с, нагрузка N=1600 (~75% бюджета)
частота на старте: 72.0 Гц, бюджет 13.89 мс
ТРЕБУЕТСЯ НАДЕТЫЙ ШЛЕМ: иначе датчик присутствия усыпит сессию

  PASS  нагрузка подобрана из свипа: N=1600
    0	72.0	0.236	3.029	1600
    15	72.0	1.611	11.178	1600
    30	72.0	1.648	10.573	1600
    45	72.0	1.647	10.650	1600
    60	72.0	1.693	10.849	1600
    75	72.0	1.660	10.680	1600
    90	72.0	1.630	10.414	1600
    105	72.0	1.603	10.809	1600
    120	72.0	1.597	10.625	1600
    135	72.0	1.607	10.655	1600
    150	72.0	1.708	10.640	1600
    165	72.0	1.601	10.488	1600
    180	72.0	1.649	10.766	1600
    195	72.0	1.900	11.076	1600
    210	72.0	1.712	11.038	1600
    225	72.0	1.726	10.906	1600
    240	72.0	1.610	10.630	1600
    255	72.0	1.655	10.535	1600
    270	72.0	1.722	10.387	1600
    286	72.0	1.752	11.327	1600
    301	72.0	1.663	10.894	1600
    316	72.0	1.625	10.677	1600
    331	72.0	1.542	10.674	1600
    346	72.0	1.633	10.380	1600
    361	72.0	1.658	10.351	1600
    376	72.0	1.647	11.242	1600
    391	72.0	1.662	10.427	1600
    406	72.0	1.662	10.539	1600
    421	72.0	1.623	10.207	1600
    436	72.0	1.659	10.416	1600
    451	72.0	1.578	10.878	1600
    466	72.0	1.739	10.956	1600
    481	72.0	1.572	10.475	1600
    496	72.0	1.518	10.596	1600
    511	72.0	1.608	10.769	1600
    526	72.0	1.641	10.764	1600
    541	72.0	1.624	10.654	1600
    556	72.0	1.633	10.578	1600
    570	72.0	1.652	10.349	1600
    585	72.0	1.601	11.139	1600
    600	72.0	1.570	10.371	1600
    615	72.0	1.760	10.457	1600
    630	72.0	1.573	10.702	1600
    645	72.0	1.706	10.337	1600
    660	72.0	1.722	10.400	1600
    675	72.0	1.648	10.513	1600
    690	72.0	1.722	10.797	1600
    705	72.0	1.683	10.941	1600
    720	72.0	1.663	10.816	1600
    735	72.0	1.615	10.953	1600
    750	72.0	1.568	10.456	1600
    765	72.0	1.595	10.585	1600
    780	72.0	1.553	10.532	1600
    795	72.0	1.608	11.106	1600
    810	72.0	1.674	10.545	1600
    825	72.0	1.822	11.016	1600
    840	72.0	1.632	11.073	1600
    855	72.0	1.650	10.757	1600
    870	72.0	1.741	10.534	1600
    885	72.0	1.230	10.489	1600
    900	72.0	1.688	10.752	1600
    915	72.0	1.611	10.524	1600
    930	72.0	1.575	10.232	1600
    945	72.0	1.602	10.796	1600
    961	72.0	1.551	11.016	1600
    976	72.0	1.685	10.831	1600
    991	72.0	1.668	10.844	1600
    1006	72.0	1.538	10.687	1600
    1021	72.0	0.209	2.608	0
    1036	72.0	1.578	10.358	1600
    1051	72.0	1.591	10.949	1600
    1066	72.0	1.663	10.604	1600

итог прогона: 1080 с из 1080 запланированных
CPU за прогон: n=1079  сред=1.632  мед=1.637  p95=1.770  макс=2.300 мс
GPU за прогон: n=1079  сред=10.593  мед=10.648  p95=11.169  макс=11.448 мс
  PASS  прогон дошёл до конца: 1080 с
  PASS  троттлинг НЕ НАБЛЮДАЛСЯ за 18.0 мин при N=1600. Это не значит, что его нет — только что за это время и под этой нагрузкой он не наступил
  PASS  бюджет удержан: p95 CPU 1.770 мс не превысил 13.89 мс

passed=40 failed=4 unknown=0
ОТКАЗ ПРИБОРА: исполнено 44 проверок из 45 — ошибка оборвала функцию
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
