# Паспорт железа — сырой вывод прибора

- дата: 2026-09-15T07:12:52
- устройство: Adreno (TM) 740
- вендор: Qualcomm
- Vulkan API: 1.3.295
- OpenXR активен: true
- частота: 90.0 Гц, кадровый бюджет: 11.11 мс

## Измеренные числа
```
мкс на draw call (небатченый):  1.125
мкс на инстанс:                 0.023
цена разогрева PSO, мс:         5.719 (пик N=100 фазы C–D; компиляцией не подтверждён — см. W)
старт до _ready, мс:            1515 (baker выкл)
W: компиляций DRAW новый/повтор: 1 / 1, пик 7.435 мс
разброс прогонов, мс:           0.001
буфер глаза:                    1680x1760
фовеация (уровень/динамика):    0 / false
троттлинг, секунда сброса:      не наблюдался
прогон фазы E, с:               1080 из 1080
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
frame synthesis: расширение не запрошено или не поддержано — синтеза нет
ожидается исполненных проверок: 65

  PASS  XR-вьюпорт: включён, рендер идёт в шлем

--- B0. Частота кадров (ADR-0007: цель 90, минимум 72 Гц) ---
доступные частоты: [72.0, 80.0, 90.0, 120.0] (перечисление НЕисчерпывающе по замыслу вендора)
бюджет кадра: 11.11 мс при 90.0 Гц — ВСЕ числа ниже относятся к этой частоте
  PASS  частота: запрошена цель 90.0 Гц — получено 90.0 (было 72.0), ждали 37 мс
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
  PASS  W старт: 1515 мс от запуска движка до _ready; компиляций к этому моменту { "canvas": 0, "mesh": 0, "surface": 0, "draw": 0, "specialization": 0 }; baker выкл
  PASS  W новый вариант: компиляции за 30 кадров { "canvas": 0, "mesh": 0, "surface": 2, "draw": 1, "specialization": 1 } (позже ещё { "canvas": 0, "mesh": 0, "surface": 0, "draw": 0, "specialization": 0 }); пик CPU 7.589 / GPU 4.671 против установившихся 0.154 / 3.334 мс — цена 7.435 мс
  FAIL  W контроль повтора: пик 4.827 мс против 7.435 в первый раз — кэш не снял цену, пик первого эпизода НЕ подтверждён как компиляция; счётчики { "canvas": 0, "mesh": 0, "surface": 2, "draw": 1, "specialization": 1 }
  ????  W2 предзагрузка: контроль B без пика компиляции — кэш тёплый, сравнивать нечего. A (.tres на поверхности, предзагружен): пик 5.190 мс, компиляции { "canvas": 0, "mesh": 0, "surface": 0, "draw": 1, "specialization": 1 }; B (override из .tres, без предзагрузки): пик 7.497 мс, компиляции { "canvas": 0, "mesh": 0, "surface": 4, "draw": 1, "specialization": 1 }; baker выкл

--- C–D. Стоимость отрисовки ---
частота обновления: 90.0 Гц, кадровый бюджет: 11.11 мс
окно: 1.0 с разогрева + 1.5 с замера по стенным часам (число кадров — результат, не настройка)

свип «небатченый»:
    N=0     draw calls движка=0      CPU n=135  сред=0.124  мед=0.121  p95=0.150  макс=0.178 мс
                          GPU n=135  сред=2.982  мед=2.926  p95=3.406  макс=3.715 мс
                          доставлено 135 кадров за 1501 мс = 89.9 к/с из 90 (100%); промахов по бюджету нет
    N=50    draw calls движка=50     CPU n=135  сред=0.248  мед=0.202  p95=0.587  макс=1.086 мс
                          GPU n=135  сред=3.445  мед=3.341  p95=4.328  макс=4.627 мс
                          доставлено 135 кадров за 1501 мс = 89.9 к/с из 90 (100%); промахов по бюджету нет
    N=100   draw calls движка=100    CPU n=135  сред=0.360  мед=0.264  p95=0.977  макс=1.089 мс
                          GPU n=135  сред=3.574  мед=3.525  p95=4.232  макс=4.817 мс
                          доставлено 135 кадров за 1501 мс = 89.9 к/с из 90 (100%); промахов по бюджету нет
    N=200   draw calls движка=200    CPU n=135  сред=0.676  мед=0.453  p95=1.170  макс=1.574 мс
                          GPU n=135  сред=3.883  мед=3.857  p95=4.445  макс=5.182 мс
                          доставлено 135 кадров за 1500 мс = 90.0 к/с из 90 (100%); промахов по бюджету нет
    N=400   draw calls движка=400    CPU n=135  сред=0.659  мед=0.586  p95=1.019  макс=1.259 мс
                          GPU n=135  сред=4.096  мед=4.169  p95=4.314  макс=4.670 мс
                          доставлено 135 кадров за 1500 мс = 90.0 к/с из 90 (100%); промахов по бюджету нет
    N=800   draw calls движка=800    CPU n=136  сред=0.841  мед=0.824  p95=0.982  макс=1.594 мс
                          GPU n=136  сред=7.007  мед=6.842  p95=8.158  макс=8.501 мс
                          доставлено 136 кадров за 1510 мс = 90.1 к/с из 90 (100%); промахов по бюджету нет
    N=1600  draw calls движка=1600   CPU n=135  сред=1.912  мед=1.921  p95=2.165  макс=2.956 мс
                          GPU n=135  сред=9.040  мед=8.987  p95=9.520  макс=9.939 мс
                          доставлено 135 кадров за 1502 мс = 89.9 к/с из 90 (100%); промахов по бюджету нет
свип «инстансы»:
    N=0     draw calls движка=0      CPU n=135  сред=0.105  мед=0.101  p95=0.137  макс=0.204 мс
                          GPU n=135  сред=2.259  мед=2.202  p95=2.512  макс=2.792 мс
                          доставлено 135 кадров за 1500 мс = 90.0 к/с из 90 (100%); промахов по бюджету нет
    N=50    draw calls движка=1      CPU n=135  сред=0.129  мед=0.125  p95=0.158  макс=0.235 мс
                          GPU n=135  сред=2.683  мед=2.644  p95=2.890  макс=3.097 мс
                          доставлено 135 кадров за 1501 мс = 89.9 к/с из 90 (100%); промахов по бюджету нет
    N=100   draw calls движка=1      CPU n=135  сред=0.200  мед=0.146  p95=0.536  макс=1.079 мс
                          GPU n=135  сред=3.320  мед=3.183  p95=4.168  макс=4.670 мс
                          доставлено 135 кадров за 1500 мс = 90.0 к/с из 90 (100%); промахов по бюджету нет
    N=200   draw calls движка=1      CPU n=135  сред=0.144  мед=0.137  p95=0.183  макс=0.227 мс
                          GPU n=135  сред=2.999  мед=2.920  p95=3.436  макс=3.680 мс
                          доставлено 135 кадров за 1500 мс = 90.0 к/с из 90 (100%); промахов по бюджету нет
    N=400   draw calls движка=1      CPU n=135  сред=0.143  мед=0.138  p95=0.177  макс=0.273 мс
                          GPU n=135  сред=3.061  мед=2.996  p95=3.503  макс=3.898 мс
                          доставлено 135 кадров за 1500 мс = 90.0 к/с из 90 (100%); промахов по бюджету нет
    N=800   draw calls движка=1      CPU n=135  сред=0.143  мед=0.136  p95=0.182  макс=0.228 мс
                          GPU n=135  сред=3.031  мед=2.959  p95=3.526  макс=3.762 мс
                          доставлено 135 кадров за 1500 мс = 90.0 к/с из 90 (100%); промахов по бюджету нет
    N=1600  draw calls движка=1      CPU n=135  сред=0.140  мед=0.138  p95=0.164  макс=0.171 мс
                          GPU n=135  сред=3.043  мед=2.969  p95=3.461  макс=3.744 мс
                          доставлено 135 кадров за 1500 мс = 90.0 к/с из 90 (100%); промахов по бюджету нет

разброс двух прогонов на N=100: 0.001 мс (0.247 против 0.246)
  PASS  разрешение свипа: разброс 0.001 мс меньше шага 1.800 мс (в 1800 раз) — наклону можно верить
  PASS  нулевой контроль: пустая сцена CPU 0.121 / GPU 2.926 мс, связывает GPU — 26% бюджета 11.11 мс, запас есть
  PASS  гейт «небатченый»: ΔN=1600 → Δdraw calls=1600 (1.00 на объект), все точки сошлись с N — случай задевает гейт
  PASS  гейт «инстансы»: ΔN=1600, Δdraw calls=1 — инстансинг работает, режимы различаются
  PASS  частота устойчива: 90.0 Гц от начала до конца свипов
  PASS  разогрев PSO: пик первых 91 кадров выше установившегося на 5.719 мс (макс 5.983 против мед 0.264)
  PASS  наклон «небатченый»: CPU 1.125 мкс/ед., GPU 3.788 мкс/ед. — связывает GPU (Δ на ΔN=1600)
  PASS  наклон «инстансы»: CPU 0.023 мкс/ед., GPU 0.479 мкс/ед. — связывает GPU (Δ на ΔN=1600)

фаза M пропущена (маркер user://skip_matrix)

фаза P пропущена (маркер user://skip_fill)

фаза L пропущена (маркер user://skip_layers)

фаза L4 пропущена (маркер user://skip_msaa_sweep)

возврат на целевую частоту перед фазой E: 90.0 Гц

--- E. Длинный прогон: троттлинг ---
план: 18 минут, выборка раз в 1 с, нагрузка N=800 (~75% бюджета)
частота на старте: 90.0 Гц, бюджет 11.11 мс
доступные частоты: [72.0, 80.0, 90.0, 120.0]
  PASS  запас вниз: есть, минимальная доступная 72.0 Гц против текущей 90.0 Гц
ТРЕБУЕТСЯ НАДЕТЫЙ ШЛЕМ: иначе датчик присутствия усыпит сессию

  PASS  нагрузка подобрана из свипа: N=800
    0	90.0	0.911	6.978	800	-1	1789437292.833
    15	90.0	0.701	7.492	800	-1	1789437307.868
    30	90.0	0.848	7.846	800	-1	1789437322.902
    45	90.0	0.880	8.001	800	-1	1789437337.927
    60	90.0	0.782	8.211	800	-1	1789437352.927
    75	90.0	0.850	6.675	800	-1	1789437367.951
    90	90.0	0.841	8.049	800	-1	1789437383.007
    105	90.0	0.849	6.842	800	-1	1789437398.053
    120	90.0	0.759	7.723	800	-1	1789437413.110
    135	90.0	0.864	8.151	800	-1	1789437428.132
    150	90.0	0.907	6.647	800	-1	1789437443.135
    165	90.0	0.956	6.831	800	-1	1789437458.147
    180	90.0	0.822	6.480	800	-1	1789437473.159
    195	90.0	0.837	6.470	800	-1	1789437488.193
    210	90.0	0.803	6.445	800	-1	1789437503.207
    225	90.0	1.256	6.876	800	-1	1789437518.229
    240	90.0	0.866	6.502	800	-1	1789437533.242
    255	90.0	1.031	6.795	800	-1	1789437548.276
    271	90.0	0.780	6.805	800	-1	1789437563.333
    286	90.0	0.814	6.780	800	-1	1789437578.357
    301	90.0	0.827	6.777	800	-1	1789437593.391
    316	90.0	1.304	6.950	800	-1	1789437608.426
    331	90.0	1.267	6.846	800	-1	1789437623.438
    346	90.0	0.673	6.496	800	-1	1789437638.439
    361	90.0	0.805	6.778	800	-1	1789437653.473
    376	90.0	0.836	6.483	800	-1	1789437668.486
    391	90.0	0.836	6.760	800	-1	1789437683.520
    406	90.0	0.882	6.916	800	-1	1789437698.543
    421	90.0	0.725	6.820	800	-1	1789437713.556
    436	90.0	0.766	6.452	800	-1	1789437728.569
    451	90.0	0.847	6.594	800	-1	1789437743.625
    466	90.0	1.279	6.912	800	-1	1789437758.626
    481	90.0	0.806	6.750	800	-1	1789437773.639
    496	90.0	0.767	6.491	800	-1	1789437788.695
    511	90.0	0.792	6.459	800	-1	1789437803.730
    526	90.0	0.826	6.472	800	-1	1789437818.775
    541	90.0	0.866	6.780	800	-1	1789437833.798
    556	90.0	0.737	6.474	800	-1	1789437848.811
    570	90.0	0.855	6.837	800	-1	1789437862.835
    585	90.0	0.789	6.471	800	-1	1789437877.858
    600	90.0	0.867	6.679	800	-1	1789437892.870
    615	90.0	0.799	6.555	800	-1	1789437907.906
    630	90.0	0.773	6.453	800	-1	1789437922.928
    645	90.0	0.926	6.881	800	-1	1789437937.962
    660	90.0	0.792	6.460	800	-1	1789437952.975
    675	90.0	0.833	6.461	800	-1	1789437968.009
    690	90.0	0.928	6.595	800	-1	1789437983.033
    705	90.0	0.815	6.461	800	-1	1789437998.056
    720	90.0	1.010	6.775	800	-1	1789438013.090
    735	90.0	0.959	6.499	800	-1	1789438028.102
    750	90.0	0.801	7.908	800	-1	1789438043.125
    765	90.0	0.777	6.476	800	-1	1789438058.139
    780	90.0	0.716	7.702	800	-1	1789438073.172
    795	90.0	0.858	6.779	800	-1	1789438088.185
    810	90.0	0.835	6.447	800	-1	1789438103.209
    825	90.0	0.766	6.467	800	-1	1789438118.221
    840	90.0	1.043	6.826	800	-1	1789438133.244
    855	90.0	1.320	7.012	800	-1	1789438148.256
    870	90.0	0.697	6.505	800	-1	1789438163.291
    885	90.0	0.962	6.807	800	-1	1789438178.303
    900	90.0	0.901	6.635	800	-1	1789438193.316
    916	90.0	1.315	6.867	800	-1	1789438208.328
    931	90.0	0.793	6.458	800	-1	1789438223.373
    946	90.0	0.729	6.517	800	-1	1789438238.386
    961	90.0	0.680	6.462	800	-1	1789438253.409
    976	90.0	0.885	6.596	800	-1	1789438268.432
    991	90.0	0.842	6.622	800	-1	1789438283.478
    1006	90.0	0.850	6.723	800	-1	1789438298.512
    1021	90.0	0.767	6.722	800	-1	1789438313.513
    1036	90.0	0.781	6.449	800	-1	1789438328.537
    1051	90.0	0.865	6.807	800	-1	1789438343.560
    1066	90.0	0.841	6.450	800	-1	1789438358.573
  PASS  полнота выборок: все 1079 выборок видели ровно N=800 отрисовок

итог прогона: 1080 с из 1080 запланированных
CPU за прогон: n=1079  сред=0.853  мед=0.821  p95=1.160  макс=1.603 мс
GPU за прогон: n=1079  сред=6.789  мед=6.619  p95=8.044  макс=8.719 мс
  PASS  прогон дошёл до конца: 1080 с
  PASS  смена частоты НЕ зафиксирована за 18.0 мин при N=800. Слабый сигнал: если прогон шёл на минимальной доступной частоте, сбрасывать было некуда — судить по дрейфу времени кадра ниже
  PASS  бюджет удержан: p95 CPU 1.160 / GPU 8.044 мс, связывает GPU — 72% бюджета 11.11 мс
дрейф по четвертям, GPU сред: 7.077 → 6.670 → 6.681 → 6.729 мс
    худшая четверть против первой: +0.0%; конец против начала: -4.9%
  PASS  дрейф времени кадра: худшая четверть +0.0% от первой — направленного роста нет, троттлинга тактовых частот не видно
  ????  клок GPU: ни одной выборки — sysfs недоступен, судить о троттлинге по частоте нечем
  ????  резиденция частот за прогон: счётчики недоступны или не сдвинулись

passed=55 failed=3 unknown=7
пол: исполнено 65/65 проверок
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
