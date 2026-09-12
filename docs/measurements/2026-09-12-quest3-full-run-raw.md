# Паспорт железа — сырой вывод прибора

- дата: 2026-09-12T18:05:36
- устройство: Adreno (TM) 740
- вендор: Qualcomm
- Vulkan API: 1.3.295
- OpenXR активен: true

## Измеренные числа
```
мкс на draw call (небатченый):  1.006
мкс на инстанс:                 0.023
цена разогрева PSO, мс:         3.451
разброс прогонов, мс:           0.022
троттлинг, секунда сброса:      не наблюдался
прогон фазы E, с:               1080 из 1080
```

## Вердикт
```
=== ПАСПОРТ ЖЕЛЕЗА ===
ожидается исполненных проверок: 47

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
    N=0     draw calls движка=0      CPU n=60  сред=0.103  мед=0.099  p95=0.134  макс=0.174 мс
                          GPU n=60  сред=2.500  мед=2.566  p95=2.995  макс=3.173 мс
    N=50    draw calls движка=50     CPU n=60  сред=0.179  мед=0.175  p95=0.212  макс=0.230 мс
                          GPU n=60  сред=3.164  мед=3.270  p95=3.818  макс=3.908 мс
    N=100   draw calls движка=100    CPU n=60  сред=0.241  мед=0.237  p95=0.285  макс=0.394 мс
                          GPU n=60  сред=3.163  мед=3.123  p95=3.551  макс=3.682 мс
    N=200   draw calls движка=200    CPU n=60  сред=0.351  мед=0.349  p95=0.405  макс=0.454 мс
                          GPU n=60  сред=3.517  мед=3.485  p95=3.696  макс=3.918 мс
    N=400   draw calls движка=400    CPU n=60  сред=0.564  мед=0.559  p95=0.650  макс=0.795 мс
                          GPU n=60  сред=4.408  мед=4.380  p95=4.658  макс=5.262 мс
    N=800   draw calls движка=800    CPU n=60  сред=1.278  мед=1.056  p95=1.874  макс=1.953 мс
                          GPU n=60  сред=5.808  мед=5.769  p95=6.055  макс=6.550 мс
    N=1600  draw calls движка=1600   CPU n=60  сред=1.725  мед=1.708  p95=1.875  макс=2.070 мс
                          GPU n=60  сред=9.910  мед=9.997  p95=10.433  макс=10.488 мс
свип «инстансы»:
    N=0     draw calls движка=0      CPU n=60  сред=0.100  мед=0.098  p95=0.122  макс=0.142 мс
                          GPU n=60  сред=2.631  мед=2.608  p95=2.614  макс=3.912 мс
    N=50    draw calls движка=1      CPU n=60  сред=0.132  мед=0.130  p95=0.151  макс=0.194 мс
                          GPU n=60  сред=2.746  мед=2.703  p95=2.970  макс=3.284 мс
    N=100   draw calls движка=1      CPU n=60  сред=0.139  мед=0.134  p95=0.166  макс=0.187 мс
                          GPU n=60  сред=2.748  мед=2.716  p95=3.017  макс=3.240 мс
    N=200   draw calls движка=1      CPU n=60  сред=0.139  мед=0.136  p95=0.167  макс=0.172 мс
                          GPU n=60  сред=2.774  мед=2.729  p95=3.111  макс=3.438 мс
    N=400   draw calls движка=1      CPU n=60  сред=0.143  мед=0.139  p95=0.187  макс=0.228 мс
                          GPU n=60  сред=2.750  мед=2.727  p95=2.965  макс=3.289 мс
    N=800   draw calls движка=1      CPU n=60  сред=0.137  мед=0.132  p95=0.171  макс=0.184 мс
                          GPU n=60  сред=2.748  мед=2.732  p95=2.856  макс=3.085 мс
    N=1600  draw calls движка=1      CPU n=60  сред=0.138  мед=0.135  p95=0.162  макс=0.186 мс
                          GPU n=60  сред=2.836  мед=2.778  p95=2.963  макс=4.812 мс

разброс двух прогонов на N=100: 0.022 мс (0.256 против 0.234)
  PASS  разрешение свипа: разброс 0.022 мс меньше шага 1.609 мс (в 73 раз) — наклону можно верить
  PASS  нулевой контроль: пустая сцена 0.099 мс — меньше половины бюджета, запас есть
  PASS  гейт «небатченый»: ΔN=1600 → Δdraw calls=1600 (1.00 на объект) — случай задевает гейт
  PASS  гейт «инстансы»: ΔN=1600, Δdraw calls=1 — инстансинг работает, режимы различаются
  PASS  частота устойчива: 72.0 Гц от начала до конца свипов
  PASS  разогрев PSO: пик первых 30 кадров выше установившегося на 3.451 мс (макс 3.688 против мед 0.237)
  PASS  наклон «небатченый»: CPU 1.006 мкс/ед., GPU 4.644 мкс/ед. — связывает GPU (Δ на ΔN=1600)
  PASS  наклон «инстансы»: CPU 0.023 мкс/ед., GPU 0.106 мкс/ед. — связывает GPU (Δ на ΔN=1600)

--- E. Длинный прогон: троттлинг ---
план: 18 минут, выборка раз в 1 с, нагрузка N=1600 (~75% бюджета)
частота на старте: 72.0 Гц, бюджет 13.89 мс
доступные частоты: [72.0, 80.0, 90.0, 120.0]
  PASS  запас вниз: прогон идёт на САМОЙ НИЗКОЙ доступной частоте 72.0 Гц — слежение за сменой частоты почти ничего не покажет, вывод строится на дрейфе времени кадра
ТРЕБУЕТСЯ НАДЕТЫЙ ШЛЕМ: иначе датчик присутствия усыпит сессию

  PASS  нагрузка подобрана из свипа: N=1600
    0	72.0	0.266	3.035	1600
    15	72.0	1.800	10.859	1600
    30	72.0	1.605	10.562	1600
    45	72.0	1.593	10.631	1600
    60	72.0	1.811	11.303	1600
    75	72.0	1.755	11.054	1600
    90	72.0	1.625	11.003	1600
    105	72.0	1.853	11.446	1600
    120	72.0	1.740	11.218	1600
    135	72.0	1.859	11.134	1600
    150	72.0	1.812	11.373	1600
    166	72.0	1.617	10.911	1600
    181	72.0	1.632	11.005	1600
    196	72.0	1.825	10.950	1600
    211	72.0	1.595	10.471	1600
    226	72.0	0.529	3.223	196
    241	72.0	1.614	11.034	1600
    256	72.0	1.627	11.021	1600
    271	72.0	1.623	10.819	1600
    286	72.0	1.649	11.424	1600
    301	72.0	1.629	11.050	1600
    316	72.0	1.717	10.986	1600
    330	72.0	1.852	10.948	1600
    345	72.0	1.626	10.939	1600
    360	72.0	1.279	10.966	1600
    375	72.0	1.614	10.929	1600
    390	72.0	1.640	11.047	1600
    405	72.0	1.671	11.150	1600
    420	72.0	1.687	11.292	1600
    435	72.0	1.636	10.954	1600
    450	72.0	1.637	10.878	1600
    465	72.0	1.782	10.885	1600
    480	72.0	1.637	10.970	1600
    495	72.0	1.627	11.048	1600
    510	72.0	1.738	11.410	1600
    525	72.0	1.684	9.337	1457
    540	72.0	1.710	10.941	1600
    555	72.0	1.675	11.007	1600
    570	72.0	1.579	11.353	1600
    585	72.0	1.654	11.343	1600
    600	72.0	1.673	11.145	1600
    615	72.0	1.749	10.961	1600
    630	72.0	1.712	10.897	1600
    646	72.0	1.728	10.962	1600
    661	72.0	1.577	11.409	1600
    676	72.0	1.615	11.044	1600
    691	72.0	1.603	10.986	1600
    706	72.0	1.591	11.059	1600
    721	72.0	1.632	11.088	1600
    736	72.0	1.616	11.058	1600
    751	72.0	1.798	11.482	1600
    766	72.0	1.957	11.182	1600
    781	72.0	1.626	11.082	1600
    796	72.0	1.626	10.949	1600
    811	72.0	1.749	11.428	1600
    826	72.0	1.658	10.988	1600
    841	72.0	1.740	11.049	1600
    856	72.0	1.613	11.004	1600
    871	72.0	1.725	11.009	1600
    886	72.0	1.786	11.299	1600
    901	72.0	0.922	4.484	604
    916	72.0	1.750	11.394	1600
    931	72.0	0.408	2.872	60
    945	72.0	1.928	11.040	1600
    960	72.0	1.673	11.133	1600
    975	72.0	1.595	11.001	1600
    990	72.0	1.830	11.187	1600
    1005	72.0	1.652	10.750	1600
    1020	72.0	1.535	10.286	1600
    1035	72.0	1.617	10.683	1600
    1050	72.0	1.600	10.313	1600
    1065	72.0	1.701	10.626	1600

итог прогона: 1080 с из 1080 запланированных
CPU за прогон: n=1078  сред=1.670  мед=1.683  p95=1.852  макс=6.164 мс
GPU за прогон: n=1078  сред=10.778  мед=11.009  p95=11.416  макс=11.672 мс
  PASS  прогон дошёл до конца: 1080 с
  PASS  смена частоты НЕ зафиксирована за 18.0 мин при N=1600. Слабый сигнал: если прогон шёл на минимальной доступной частоте, сбрасывать было некуда — судить по дрейфу времени кадра ниже
  PASS  бюджет удержан: p95 CPU 1.852 / GPU 11.416 мс, связывает GPU — 82% бюджета 13.89 мс
дрейф по четвертям, GPU сред: 10.588 → 10.991 → 11.047 → 10.817 мс
  PASS  дрейф времени кадра: +2.2% за прогон — та же нагрузка считается столько же, троттлинга тактовых частот нет

passed=45 failed=2 unknown=0
пол: исполнено 47/47 проверок
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
