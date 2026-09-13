# Паспорт железа — сырой вывод прибора

- дата: 2026-09-13T19:41:46
- устройство: Adreno (TM) 740
- вендор: Qualcomm
- Vulkan API: 1.3.295
- OpenXR активен: true
- частота: 90.0 Гц, кадровый бюджет: 11.11 мс

## Измеренные числа
```
мкс на draw call (небатченый):  1.123
мкс на инстанс:                 0.016
цена разогрева PSO, мс:         5.192
разброс прогонов, мс:           0.024
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
имя	ΔGPU мс	ΔCPU мс	разброс мс	значимо
msaa_2x_геометрия	-2.117	0.235	0.236	true
msaa_4x_геометрия	-1.849	0.501	0.236	true
msaa_2x_пиксели	-1.020	-0.076	0.011	true
msaa_4x_пиксели	-0.652	-0.073	0.011	true
vrs_геометрия	0.907	-0.024	0.729	false
vrs_пиксели	0.608	-0.009	0.430	false
surface_меши	0.156	0.042	0.026	true
surface_мультимеш	0.032	0.015	0.026	false
surface_атлас	0.102	0.135	0.026	true
surface_слой	0.030	0.095	0.026	false
```

## Вердикт
```
=== ПАСПОРТ ЖЕЛЕЗА ===
ожидается исполненных проверок: 74

  PASS  XR-вьюпорт: включён, рендер идёт в шлем

--- B0. Частота кадров (ADR-0007: цель 90, минимум 72 Гц) ---
доступные частоты: [72.0, 80.0, 90.0, 120.0] (перечисление НЕисчерпывающе по замыслу вендора)
бюджет кадра: 11.11 мс при 90.0 Гц — ВСЕ числа ниже относятся к этой частоте
  PASS  частота: запрошена цель 90.0 Гц — получено 90.0 (было 72.0), ждали 35 мс
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
    N=0     draw calls движка=0      CPU n=135  сред=0.106  мед=0.102  p95=0.131  макс=0.184 мс
                          GPU n=135  сред=2.661  мед=2.673  p95=3.219  макс=3.447 мс
                          доставлено 135 кадров за 1500 мс = 90.0 к/с из 90 (100%); промахов по бюджету нет
    N=50    draw calls движка=50     CPU n=135  сред=0.176  мед=0.172  p95=0.210  макс=0.247 мс
                          GPU n=135  сред=2.810  мед=2.789  p95=2.923  макс=3.078 мс
                          доставлено 135 кадров за 1501 мс = 89.9 к/с из 90 (100%); промахов по бюджету нет
    N=100   draw calls движка=94     CPU n=135  сред=0.243  мед=0.239  p95=0.276  макс=0.337 мс
                          GPU n=135  сред=3.217  мед=3.209  p95=3.428  макс=3.608 мс
                          доставлено 135 кадров за 1501 мс = 89.9 к/с из 90 (100%); промахов по бюджету нет
    N=200   draw calls движка=200    CPU n=135  сред=0.639  мед=0.585  p95=1.011  макс=1.039 мс
                          GPU n=135  сред=3.573  мед=3.580  p95=3.835  макс=4.083 мс
                          доставлено 135 кадров за 1500 мс = 90.0 к/с из 90 (100%); промахов по бюджету нет
    N=400   draw calls движка=400    CPU n=135  сред=1.104  мед=1.216  p95=1.401  макс=1.532 мс
                          GPU n=135  сред=5.595  мед=5.600  p95=5.850  макс=5.958 мс
                          доставлено 135 кадров за 1501 мс = 89.9 к/с из 90 (100%); промахов по бюджету нет
    N=800   draw calls движка=800    CPU n=135  сред=0.849  мед=0.835  p95=0.962  макс=1.340 мс
                          GPU n=135  сред=7.901  мед=8.008  p95=8.241  макс=8.373 мс
                          доставлено 135 кадров за 1501 мс = 89.9 к/с из 90 (100%); промахов по бюджету нет
    N=1600  draw calls движка=1600   CPU n=135  сред=1.911  мед=1.899  p95=2.096  макс=2.917 мс
                          GPU n=135  сред=9.498  мед=9.512  p95=9.745  макс=9.813 мс
                          доставлено 135 кадров за 1500 мс = 90.0 к/с из 90 (100%); промахов по бюджету нет
свип «инстансы»:
    N=0     draw calls движка=0      CPU n=135  сред=0.114  мед=0.111  p95=0.139  макс=0.167 мс
                          GPU n=135  сред=2.595  мед=2.598  p95=2.849  макс=3.114 мс
                          доставлено 135 кадров за 1500 мс = 90.0 к/с из 90 (100%); промахов по бюджету нет
    N=50    draw calls движка=1      CPU n=135  сред=0.142  мед=0.135  p95=0.176  макс=0.277 мс
                          GPU n=135  сред=2.862  мед=2.846  p95=3.052  макс=3.323 мс
                          доставлено 135 кадров за 1501 мс = 89.9 к/с из 90 (100%); промахов по бюджету нет
    N=100   draw calls движка=1      CPU n=135  сред=0.136  мед=0.134  p95=0.168  макс=0.186 мс
                          GPU n=135  сред=2.840  мед=2.842  p95=3.068  макс=3.363 мс
                          доставлено 135 кадров за 1501 мс = 89.9 к/с из 90 (100%); промахов по бюджету нет
    N=200   draw calls движка=1      CPU n=135  сред=0.141  мед=0.138  p95=0.158  макс=0.194 мс
                          GPU n=135  сред=2.915  мед=2.874  p95=3.168  макс=3.548 мс
                          доставлено 135 кадров за 1500 мс = 90.0 к/с из 90 (100%); промахов по бюджету нет
    N=400   draw calls движка=1      CPU n=135  сред=0.140  мед=0.137  p95=0.159  макс=0.190 мс
                          GPU n=135  сред=2.927  мед=2.892  p95=3.127  макс=3.405 мс
                          доставлено 135 кадров за 1500 мс = 90.0 к/с из 90 (100%); промахов по бюджету нет
    N=800   draw calls движка=1      CPU n=135  сред=0.142  мед=0.136  p95=0.190  макс=0.234 мс
                          GPU n=135  сред=2.945  мед=2.899  p95=3.150  макс=3.723 мс
                          доставлено 135 кадров за 1500 мс = 90.0 к/с из 90 (100%); промахов по бюджету нет
    N=1600  draw calls движка=1      CPU n=135  сред=0.146  мед=0.137  p95=0.186  макс=0.260 мс
                          GPU n=135  сред=2.955  мед=2.918  p95=3.203  макс=3.622 мс
                          доставлено 135 кадров за 1501 мс = 89.9 к/с из 90 (100%); промахов по бюджету нет

разброс двух прогонов на N=100: 0.024 мс (0.238 против 0.262)
  PASS  разрешение свипа: разброс 0.024 мс меньше шага 1.797 мс (в 75 раз) — наклону можно верить
  PASS  нулевой контроль: пустая сцена CPU 0.102 / GPU 2.673 мс, связывает GPU — 24% бюджета 11.11 мс, запас есть
        точки с расхождением заявленного и счётчика движка: N=100→94
  PASS  гейт «небатченый»: ΔN=1600 → Δdraw calls=1600 (1.00 на объект) — гейт задет, но 1 точек с расхождением (см. выше)
  PASS  гейт «инстансы»: ΔN=1600, Δdraw calls=1 — инстансинг работает, режимы различаются
  PASS  частота устойчива: 90.0 Гц от начала до конца свипов
  PASS  разогрев PSO: пик первых 90 кадров выше установившегося на 5.192 мс (макс 5.431 против мед 0.239)
  PASS  наклон «небатченый»: CPU 1.123 мкс/ед., GPU 4.274 мкс/ед. — связывает GPU (Δ на ΔN=1600)
  PASS  наклон «инстансы»: CPU 0.016 мкс/ед., GPU 0.200 мкс/ед. — связывает GPU (Δ на ΔN=1600)

фаза M пропущена (маркер user://skip_matrix)

фаза P пропущена (маркер user://skip_fill)

--- L. Ручки рендера и поверхности меню (ADR-0003) ---
частота 90.0 Гц (запрошено 90), бюджет 11.11 мс — все числа фазы относятся к ней
повторов 2, порядок чередующийся; эффект значим, если вдвое больше разброса повторов

L1. MSAA на XR-вьюпорте: ["off", "2x", "4x"]
  сцена «геометрия»:
    off       GPU [5.21199989318848, 5.44799995422363]  CPU [0.61599999666214, 0.56400001049042]  сверх бюджета кадров 0
    2x        GPU [3.19400000572205, 3.23099994659424]  CPU [1.12399995326996, 0.52600002288818]  сверх бюджета кадров 0
    4x        GPU [3.47699999809265, 3.48499989509583]  CPU [1.09700000286102, 1.08599996566772]  сверх бюджета кадров 0
  PASS  L1 гейт состояния, «геометрия»: MSAA вставал в каждый режим, остальное состояние не менялось
  PASS  L1 MSAA 2x, «геометрия»: GPU -2.117 мс, CPU +0.235 мс, разброс 0.236 — ЗНАЧИМО; связывает GPU: 28.9% бюджета (GPU 3.212, CPU 0.825 мс)
  PASS  L1 MSAA 4x, «геометрия»: GPU -1.849 мс, CPU +0.501 мс, разброс 0.236 — ЗНАЧИМО; связывает GPU: 31.3% бюджета (GPU 3.481, CPU 1.091 мс)
  сцена «пиксели»:
    off       GPU [4.21000003814697, 4.21199989318848]  CPU [0.19499999284744, 0.22400000691414]  сверх бюджета кадров 0
    2x        GPU [3.19600009918213, 3.18499994277954]  CPU [0.13400000333786, 0.1330000013113]  сверх бюджета кадров 0
    4x        GPU [3.5550000667572, 3.56200003623962]  CPU [0.13400000333786, 0.13799999654293]  сверх бюджета кадров 0
  PASS  L1 гейт состояния, «пиксели»: MSAA вставал в каждый режим, остальное состояние не менялось
  PASS  L1 MSAA 2x, «пиксели»: GPU -1.020 мс, CPU -0.076 мс, разброс 0.011 — ЗНАЧИМО; связывает GPU: 28.7% бюджета (GPU 3.191, CPU 0.134 мс)
  PASS  L1 MSAA 4x, «пиксели»: GPU -0.652 мс, CPU -0.073 мс, разброс 0.011 — ЗНАЧИМО; связывает GPU: 32.0% бюджета (GPU 3.559, CPU 0.136 мс)
  фальсификатор: audio_listener_enable_3d true → false на сцене «пиксели»
    true      GPU [4.47100019454956, 4.45300006866455]  CPU [0.15199999511242, 0.15899999439716]  сверх бюджета кадров 0
    false     GPU [4.46600008010864, 4.42799997329712]  CPU [0.15600000321865, 0.15399999916553]  сверх бюджета кадров 0
  PASS  L1 фальсификатор: ручка без влияния на рендер дала -0.015 мс при разбросе 0.038 — в шуме, порог различает

L2. Фиксированная фовеация: vrs_mode DISABLED → VRS_XR
  интерфейс: vrs_strength 1.0, vrs_min_radius 20.0
  сцена «геометрия»:
    DISABLED  GPU [4.4850001335144, 4.43800020217896]  CPU [0.54799997806549, 0.53799998760223]  сверх бюджета кадров 0
    VRS_XR    GPU [5.73299980163574, 5.00400018692017]  CPU [0.51399999856949, 0.52399998903275]  сверх бюджета кадров 0
  сцена «пиксели»:
    DISABLED  GPU [4.44500017166138, 4.45699977874756]  CPU [0.1870000064373, 0.14699999988079]  сверх бюджета кадров 0
    VRS_XR    GPU [4.8439998626709, 5.27400016784668]  CPU [0.15600000321865, 0.15999999642372]  сверх бюджета кадров 0
  PASS  L2 гейт состояния: vrs_mode вставал, остальное состояние не менялось
  PASS  L2 VRS_XR, «геометрия»: GPU +0.907 мс, CPU -0.024 мс, разброс 0.729 — в шуме; связывает GPU: 48.3% бюджета (GPU 5.368, CPU 0.519 мс)
  PASS  L2 VRS_XR, «пиксели»: GPU +0.608 мс, CPU -0.009 мс, разброс 0.430 — в шуме; связывает GPU: 45.5% бюджета (GPU 5.059, CPU 0.158 мс)
  ????  L2 контроль: на пикселях выигрыша нет в пределах шума (+0.608 при разбросе 0.430) — сверять не с чем

L3. Поверхности меню: 42 ячеек на сфере 0.15 м, атлас 512x512
  время SubViewport считается отдельно и складывается с главным: кадр оплачивает оба
  пусто     сумма GPU [2.848, 2.853] (главный [2.848, 2.853] + SubViewport [0.000, 0.000]), CPU [0.119, 0.119], отрисовок [0, 0], к/с [90.000, 89.940], сверх бюджета 0
  меши      сумма GPU [3.020, 2.994] (главный [3.020, 2.994] + SubViewport [0.000, 0.000]), CPU [0.163, 0.159], отрисовок [42, 42], к/с [90.000, 90.000], сверх бюджета 0
  мультимеш сумма GPU [2.878, 2.887] (главный [2.878, 2.887] + SubViewport [0.000, 0.000]), CPU [0.134, 0.134], отрисовок [1, 1], к/с [90.000, 89.940], сверх бюджета 0
  атлас     сумма GPU [2.960, 2.944] (главный [2.926, 2.910] + SubViewport [0.034, 0.034]), CPU [0.253, 0.255], отрисовок [2, 2], к/с [90.000, 90.000], сверх бюджета 0
  слой      сумма GPU [2.868, 2.893] (главный [2.797, 2.820] + SubViewport [0.071, 0.073]), CPU [0.216, 0.213], отрисовок [0, 0], к/с [90.000, 90.000], сверх бюджета 0
  PASS  L3 гейт «пусто»: кадр пуст на всех повторах
  PASS  L3 гейт «меши»: прирост отрисовок [42, 42] = 42, как заявлено
  PASS  L3 гейт «мультимеш»: прирост отрисовок [1, 1] = 1, как заявлено
  PASS  L3 гейт «атлас»: прирост отрисовок [2, 2] = 2, как заявлено
  PASS  L3 гейт «атлас»: SubViewport рисует (1 отрисовок холста)
  PASS  L3 гейт «слой»: is_natively_supported() = true, рантайм принимает cylinder-слой
  PASS  L3 гейт «слой»: прирост отрисовок главного вьюпорта [0, 0] = 0 — подмены мешем нет
  PASS  L3 гейт «слой»: SubViewport рисует (1 отрисовок холста)
  PASS  L3 цена «меши»: GPU +0.156 мс (из них SubViewport 0.000), CPU +0.042 мс, разброс 0.026 — ЗНАЧИМО; связывает GPU: 27.1% бюджета (GPU 3.007, CPU 0.161 мс)
  PASS  L3 цена «мультимеш»: GPU +0.032 мс (из них SubViewport 0.000), CPU +0.015 мс, разброс 0.026 — в шуме; связывает GPU: 25.9% бюджета (GPU 2.883, CPU 0.134 мс)
  PASS  L3 цена «атлас»: GPU +0.102 мс (из них SubViewport 0.034), CPU +0.135 мс, разброс 0.026 — ЗНАЧИМО; связывает GPU: 26.6% бюджета (GPU 2.952, CPU 0.254 мс)
  PASS  L3 цена «слой»: GPU +0.030 мс (из них SubViewport 0.072), CPU +0.095 мс, разброс 0.026 — в шуме; связывает GPU: 25.9% бюджета (GPU 2.880, CPU 0.214 мс)
  доставка: пусто 90.0 к/с, слой 90.0 к/с, разброс 0.06; сверх бюджета при слое 0 кадров
  PASS  L3 доставка при слое: 90.0 к/с против 90.0 у пустого, в пределах шума — цены композитора в доставке не видно

фаза E пропущена (маркер user://skip_sustained или флаг)

passed=67 failed=2 unknown=5
пол: исполнено 74/74 проверок
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
