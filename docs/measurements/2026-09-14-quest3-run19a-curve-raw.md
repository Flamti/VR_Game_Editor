# Паспорт железа — сырой вывод прибора

- дата: 2026-09-14T20:09:40
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
старт до _ready, мс:            1647 (baker выкл)
W: компиляций DRAW новый/повтор: 1 / 1, пик 6.194 мс
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
frame synthesis: расширение не запрошено или не поддержано — синтеза нет
ожидается исполненных проверок: 58

  PASS  XR-вьюпорт: включён, рендер идёт в шлем

--- B0. Частота кадров (ADR-0007: цель 90, минимум 72 Гц) ---
доступные частоты: [72.0, 80.0, 90.0, 120.0] (перечисление НЕисчерпывающе по замыслу вендора)
бюджет кадра: 11.11 мс при 90.0 Гц — ВСЕ числа ниже относятся к этой частоте
  PASS  частота: запрошена цель 90.0 Гц — получено 90.0 (было 72.0), ждали 465 мс
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
  PASS  W старт: 1647 мс от запуска движка до _ready; компиляций к этому моменту { "canvas": 0, "mesh": 0, "surface": 0, "draw": 0, "specialization": 0 }; baker выкл
  PASS  W новый вариант: компиляции за 30 кадров { "canvas": 0, "mesh": 0, "surface": 2, "draw": 1, "specialization": 1 } (позже ещё { "canvas": 0, "mesh": 0, "surface": 0, "draw": 0, "specialization": 0 }); пик CPU 6.345 / GPU 5.131 против установившихся 0.151 / 3.246 мс — цена 6.194 мс
  FAIL  W контроль повтора: пик 3.489 мс против 6.194 в первый раз — кэш не снял цену, пик первого эпизода НЕ подтверждён как компиляция; счётчики { "canvas": 0, "mesh": 0, "surface": 2, "draw": 1, "specialization": 1 }
  PASS  W2 предзагрузка СНИМАЕТ пик: A (.tres на поверхности, предзагружен): пик 4.173 мс, компиляции { "canvas": 0, "mesh": 0, "surface": 0, "draw": 1, "specialization": 1 }; B (override из .tres, без предзагрузки): пик 1171.541 мс, компиляции { "canvas": 0, "mesh": 0, "surface": 4, "draw": 1, "specialization": 1 }; baker выкл

фаза C–D пропущена (маркер user://skip_draws)

фаза M пропущена (маркер user://skip_matrix)

фаза P пропущена (маркер user://skip_fill)

фаза L пропущена (маркер user://skip_layers)

фаза L4 пропущена (маркер user://skip_msaa_sweep)

--- K. Форма кривой «время от числа вызовов» (ADR-0003, открыто) ---
частота 90.0 Гц, бюджет 11.11 мс; точек 18; порядок ["off↑", "2x↑", "2x↓", "off↓"]
  лестница MSAA off, проход 1 вверх:
    N=0     отрисовок 0     GPU 2.624  CPU 0.110 мс; доставлено 135 кадров за 1501 мс = 89.9 к/с из 90 (100%); промахов по бюджету нет
    N=100   отрисовок 100   GPU 2.973  CPU 0.218 мс; доставлено 135 кадров за 1500 мс = 90.0 к/с из 90 (100%); промахов по бюджету нет
    N=200   отрисовок 200   GPU 3.647  CPU 0.476 мс; доставлено 135 кадров за 1501 мс = 89.9 к/с из 90 (100%); промахов по бюджету нет
    N=300   отрисовок 300   GPU 3.919  CPU 0.674 мс; доставлено 135 кадров за 1500 мс = 90.0 к/с из 90 (100%); промахов по бюджету нет
    N=350   отрисовок 350   GPU 3.970  CPU 0.743 мс; доставлено 135 кадров за 1501 мс = 89.9 к/с из 90 (100%); промахов по бюджету нет
    N=400   отрисовок 400   GPU 5.505  CPU 0.835 мс; доставлено 135 кадров за 1500 мс = 90.0 к/с из 90 (100%); промахов по бюджету нет
    N=450   отрисовок 450   GPU 5.789  CPU 1.249 мс; доставлено 135 кадров за 1500 мс = 90.0 к/с из 90 (100%); промахов по бюджету нет
    N=500   отрисовок 500   GPU 5.645  CPU 0.748 мс; доставлено 136 кадров за 1510 мс = 90.1 к/с из 90 (100%); промахов по бюджету нет
    N=550   отрисовок 550   GPU 5.885  CPU 1.106 мс; доставлено 135 кадров за 1500 мс = 90.0 к/с из 90 (100%); промахов по бюджету нет
    N=600   отрисовок 600   GPU 6.095  CPU 1.070 мс; доставлено 135 кадров за 1500 мс = 90.0 к/с из 90 (100%); промахов по бюджету нет
    N=650   отрисовок 650   GPU 7.558  CPU 0.789 мс; доставлено 135 кадров за 1500 мс = 90.0 к/с из 90 (100%); промахов по бюджету нет
    N=700   отрисовок 700   GPU 7.255  CPU 0.820 мс; доставлено 135 кадров за 1500 мс = 90.0 к/с из 90 (100%); промахов по бюджету нет
    N=750   отрисовок 750   GPU 6.677  CPU 0.855 мс; доставлено 135 кадров за 1500 мс = 90.0 к/с из 90 (100%); промахов по бюджету нет
    N=800   отрисовок 800   GPU 6.686  CPU 0.868 мс; доставлено 135 кадров за 1501 мс = 89.9 к/с из 90 (100%); промахов по бюджету нет
    N=900   отрисовок 900   GPU 8.117  CPU 0.949 мс; доставлено 135 кадров за 1500 мс = 90.0 к/с из 90 (100%); промахов по бюджету нет
    N=1000  отрисовок 1000  GPU 8.493  CPU 1.059 мс; доставлено 136 кадров за 1511 мс = 90.0 к/с из 90 (100%); промахов по бюджету нет
    N=1200  отрисовок 1200  GPU 9.159  CPU 1.456 мс; доставлено 135 кадров за 1501 мс = 89.9 к/с из 90 (100%); промахов по бюджету нет
    N=1600  отрисовок 1600  GPU 9.390  CPU 1.908 мс; доставлено 136 кадров за 1510 мс = 90.1 к/с из 90 (100%); промахов по бюджету нет
  лестница MSAA 2x, проход 1 вверх:
    N=0     отрисовок 0     GPU 2.543  CPU 0.112 мс; доставлено 135 кадров за 1500 мс = 90.0 к/с из 90 (100%); промахов по бюджету нет
    N=100   отрисовок 100   GPU 1.994  CPU 0.247 мс; доставлено 135 кадров за 1500 мс = 90.0 к/с из 90 (100%); промахов по бюджету нет
    N=200   отрисовок 200   GPU 2.394  CPU 0.357 мс; доставлено 135 кадров за 1501 мс = 89.9 к/с из 90 (100%); промахов по бюджету нет
    N=300   отрисовок 300   GPU 2.791  CPU 0.466 мс; доставлено 135 кадров за 1500 мс = 90.0 к/с из 90 (100%); промахов по бюджету нет
    N=350   отрисовок 350   GPU 3.001  CPU 0.574 мс; доставлено 136 кадров за 1510 мс = 90.1 к/с из 90 (100%); промахов по бюджету нет
    N=400   отрисовок 400   GPU 3.192  CPU 0.759 мс; доставлено 135 кадров за 1501 мс = 89.9 к/с из 90 (100%); промахов по бюджету нет
    N=450   отрисовок 450   GPU 3.445  CPU 0.982 мс; доставлено 135 кадров за 1500 мс = 90.0 к/с из 90 (100%); промахов по бюджету нет
    N=500   отрисовок 500   GPU 3.617  CPU 1.197 мс; доставлено 135 кадров за 1501 мс = 89.9 к/с из 90 (100%); промахов по бюджету нет
    N=550   отрисовок 550   GPU 3.856  CPU 0.817 мс; доставлено 135 кадров за 1500 мс = 90.0 к/с из 90 (100%); промахов по бюджету нет
    N=600   отрисовок 600   GPU 3.963  CPU 0.796 мс; доставлено 136 кадров за 1511 мс = 90.0 к/с из 90 (100%); промахов по бюджету нет
    N=650   отрисовок 650   GPU 4.179  CPU 0.836 мс; доставлено 135 кадров за 1500 мс = 90.0 к/с из 90 (100%); промахов по бюджету нет
    N=700   отрисовок 700   GPU 5.691  CPU 1.540 мс; доставлено 135 кадров за 1501 мс = 89.9 к/с из 90 (100%); промахов по бюджету нет
    N=750   отрисовок 750   GPU 5.407  CPU 1.232 мс; доставлено 135 кадров за 1500 мс = 90.0 к/с из 90 (100%); промахов по бюджету нет
    N=800   отрисовок 800   GPU 5.740  CPU 1.379 мс; доставлено 135 кадров за 1500 мс = 90.0 к/с из 90 (100%); промахов по бюджету нет
    N=900   отрисовок 900   GPU 6.334  CPU 1.038 мс; доставлено 135 кадров за 1500 мс = 90.0 к/с из 90 (100%); промахов по бюджету нет
    N=1000  отрисовок 1000  GPU 7.882  CPU 1.087 мс; доставлено 135 кадров за 1501 мс = 89.9 к/с из 90 (100%); промахов по бюджету нет
    N=1200  отрисовок 1200  GPU 8.695  CPU 1.454 мс; доставлено 135 кадров за 1501 мс = 89.9 к/с из 90 (100%); промахов по бюджету нет
    N=1600  отрисовок 1600  GPU 8.706  CPU 2.103 мс; доставлено 135 кадров за 1501 мс = 89.9 к/с из 90 (100%); промахов по бюджету нет
  лестница MSAA 2x, проход 2 вниз:
    N=1600  отрисовок 1600  GPU 9.233  CPU 2.057 мс; доставлено 135 кадров за 1500 мс = 90.0 к/с из 90 (100%); промахов по бюджету нет
    N=1200  отрисовок 1200  GPU 8.564  CPU 1.498 мс; доставлено 136 кадров за 1511 мс = 90.0 к/с из 90 (100%); промахов по бюджету нет
    N=1000  отрисовок 1000  GPU 7.557  CPU 1.084 мс; доставлено 136 кадров за 1510 мс = 90.1 к/с из 90 (100%); промахов по бюджету нет
    N=900   отрисовок 900   GPU 6.341  CPU 1.012 мс; доставлено 135 кадров за 1500 мс = 90.0 к/с из 90 (100%); промахов по бюджету нет
    N=800   отрисовок 800   GPU 6.100  CPU 1.097 мс; доставлено 136 кадров за 1510 мс = 90.1 к/с из 90 (100%); промахов по бюджету нет
    N=750   отрисовок 750   GPU 5.638  CPU 1.303 мс; доставлено 135 кадров за 1500 мс = 90.0 к/с из 90 (100%); промахов по бюджету нет
    N=700   отрисовок 700   GPU 5.331  CPU 1.111 мс; доставлено 135 кадров за 1500 мс = 90.0 к/с из 90 (100%); промахов по бюджету нет
    N=650   отрисовок 650   GPU 5.259  CPU 0.991 мс; доставлено 136 кадров за 1511 мс = 90.0 к/с из 90 (100%); промахов по бюджету нет
    N=600   отрисовок 600   GPU 3.988  CPU 1.037 мс; доставлено 135 кадров за 1500 мс = 90.0 к/с из 90 (100%); промахов по бюджету нет
    N=550   отрисовок 550   GPU 3.792  CPU 1.075 мс; доставлено 135 кадров за 1500 мс = 90.0 к/с из 90 (100%); промахов по бюджету нет
    N=500   отрисовок 500   GPU 3.615  CPU 1.163 мс; доставлено 135 кадров за 1500 мс = 90.0 к/с из 90 (100%); промахов по бюджету нет
    N=450   отрисовок 450   GPU 3.406  CPU 1.212 мс; доставлено 135 кадров за 1501 мс = 89.9 к/с из 90 (100%); промахов по бюджету нет
    N=400   отрисовок 400   GPU 3.163  CPU 0.518 мс; доставлено 136 кадров за 1511 мс = 90.0 к/с из 90 (100%); промахов по бюджету нет
    N=350   отрисовок 350   GPU 2.969  CPU 0.475 мс; доставлено 135 кадров за 1501 мс = 89.9 к/с из 90 (100%); промахов по бюджету нет
    N=300   отрисовок 300   GPU 2.890  CPU 0.509 мс; доставлено 135 кадров за 1501 мс = 89.9 к/с из 90 (100%); промахов по бюджету нет
    N=200   отрисовок 200   GPU 2.389  CPU 0.348 мс; доставлено 135 кадров за 1500 мс = 90.0 к/с из 90 (100%); промахов по бюджету нет
    N=100   отрисовок 100   GPU 1.989  CPU 0.262 мс; доставлено 135 кадров за 1500 мс = 90.0 к/с из 90 (100%); промахов по бюджету нет
    N=0     отрисовок 0     GPU 2.855  CPU 0.125 мс; доставлено 135 кадров за 1500 мс = 90.0 к/с из 90 (100%); промахов по бюджету нет
  лестница MSAA off, проход 2 вниз:
    N=1600  отрисовок 1600  GPU 9.499  CPU 1.969 мс; доставлено 136 кадров за 1509 мс = 90.1 к/с из 90 (100%); промахов по бюджету нет
    N=1200  отрисовок 1200  GPU 8.506  CPU 1.415 мс; доставлено 135 кадров за 1500 мс = 90.0 к/с из 90 (100%); промахов по бюджету нет
    N=1000  отрисовок 1000  GPU 8.423  CPU 1.068 мс; доставлено 135 кадров за 1501 мс = 89.9 к/с из 90 (100%); промахов по бюджету нет
    N=900   отрисовок 900   GPU 8.054  CPU 0.964 мс; доставлено 135 кадров за 1501 мс = 89.9 к/с из 90 (100%); промахов по бюджету нет
    N=800   отрисовок 800   GPU 6.566  CPU 0.904 мс; доставлено 135 кадров за 1500 мс = 90.0 к/с из 90 (100%); промахов по бюджету нет
    N=750   отрисовок 750   GPU 6.664  CPU 0.855 мс; доставлено 135 кадров за 1500 мс = 90.0 к/с из 90 (100%); промахов по бюджету нет
    N=700   отрисовок 700   GPU 6.455  CPU 0.846 мс; доставлено 135 кадров за 1500 мс = 90.0 к/с из 90 (100%); промахов по бюджету нет
    N=650   отрисовок 650   GPU 6.429  CPU 0.824 мс; доставлено 135 кадров за 1500 мс = 90.0 к/с из 90 (100%); промахов по бюджету нет
    N=600   отрисовок 600   GPU 6.123  CPU 1.124 мс; доставлено 135 кадров за 1500 мс = 90.0 к/с из 90 (100%); промахов по бюджету нет
    N=550   отрисовок 550   GPU 6.096  CPU 0.753 мс; доставлено 135 кадров за 1500 мс = 90.0 к/с из 90 (100%); промахов по бюджету нет
    N=500   отрисовок 500   GPU 6.023  CPU 1.311 мс; доставлено 135 кадров за 1500 мс = 90.0 к/с из 90 (100%); промахов по бюджету нет
    N=450   отрисовок 450   GPU 5.415  CPU 0.587 мс; доставлено 135 кадров за 1500 мс = 90.0 к/с из 90 (100%); промахов по бюджету нет
    N=400   отрисовок 400   GPU 5.594  CPU 1.138 мс; доставлено 135 кадров за 1500 мс = 90.0 к/с из 90 (100%); промахов по бюджету нет
    N=350   отрисовок 350   GPU 3.992  CPU 0.741 мс; доставлено 135 кадров за 1500 мс = 90.0 к/с из 90 (100%); промахов по бюджету нет
    N=300   отрисовок 300   GPU 4.193  CPU 0.466 мс; доставлено 136 кадров за 1511 мс = 90.0 к/с из 90 (100%); промахов по бюджету нет
    N=200   отрисовок 200   GPU 4.224  CPU 0.408 мс; доставлено 136 кадров за 1511 мс = 90.0 к/с из 90 (100%); промахов по бюджету нет
    N=100   отрисовок 100   GPU 3.269  CPU 0.276 мс; доставлено 135 кадров за 1502 мс = 89.9 к/с из 90 (100%); промахов по бюджету нет
    N=0     отрисовок 0     GPU 2.899  CPU 0.124 мс; доставлено 135 кадров за 1500 мс = 90.0 к/с из 90 (100%); промахов по бюджету нет
  инстансы, проход вверх:
    N=0     отрисовок 0     GPU 2.906  CPU 0.127 мс; доставлено 135 кадров за 1500 мс = 90.0 к/с из 90 (100%); промахов по бюджету нет
    N=25    отрисовок 1     GPU 2.911  CPU 0.145 мс; доставлено 135 кадров за 1501 мс = 89.9 к/с из 90 (100%); промахов по бюджету нет
    N=50    отрисовок 1     GPU 2.884  CPU 0.137 мс; доставлено 135 кадров за 1500 мс = 90.0 к/с из 90 (100%); промахов по бюджету нет
    N=75    отрисовок 1     GPU 2.888  CPU 0.141 мс; доставлено 135 кадров за 1501 мс = 89.9 к/с из 90 (100%); промахов по бюджету нет
    N=100   отрисовок 1     GPU 2.901  CPU 0.141 мс; доставлено 135 кадров за 1501 мс = 89.9 к/с из 90 (100%); промахов по бюджету нет
    N=150   отрисовок 1     GPU 2.898  CPU 0.145 мс; доставлено 135 кадров за 1500 мс = 90.0 к/с из 90 (100%); промахов по бюджету нет
    N=200   отрисовок 1     GPU 2.894  CPU 0.141 мс; доставлено 135 кадров за 1501 мс = 89.9 к/с из 90 (100%); промахов по бюджету нет
    N=400   отрисовок 1     GPU 2.903  CPU 0.141 мс; доставлено 135 кадров за 1500 мс = 90.0 к/с из 90 (100%); промахов по бюджету нет
    N=800   отрисовок 1     GPU 2.907  CPU 0.139 мс; доставлено 135 кадров за 1500 мс = 90.0 к/с из 90 (100%); промахов по бюджету нет
    N=1600  отрисовок 1     GPU 2.944  CPU 0.141 мс; доставлено 135 кадров за 1501 мс = 89.9 к/с из 90 (100%); промахов по бюджету нет
  инстансы, проход вниз:
    N=1600  отрисовок 1     GPU 2.935  CPU 0.145 мс; доставлено 135 кадров за 1500 мс = 90.0 к/с из 90 (100%); промахов по бюджету нет
    N=800   отрисовок 1     GPU 2.858  CPU 0.134 мс; доставлено 135 кадров за 1500 мс = 90.0 к/с из 90 (100%); промахов по бюджету нет
    N=400   отрисовок 1     GPU 2.659  CPU 0.132 мс; доставлено 135 кадров за 1500 мс = 90.0 к/с из 90 (100%); промахов по бюджету нет
    N=200   отрисовок 1     GPU 2.909  CPU 0.139 мс; доставлено 135 кадров за 1500 мс = 90.0 к/с из 90 (100%); промахов по бюджету нет
    N=150   отрисовок 1     GPU 2.875  CPU 0.140 мс; доставлено 135 кадров за 1500 мс = 90.0 к/с из 90 (100%); промахов по бюджету нет
    N=100   отрисовок 1     GPU 2.882  CPU 0.140 мс; доставлено 135 кадров за 1501 мс = 89.9 к/с из 90 (100%); промахов по бюджету нет
    N=75    отрисовок 1     GPU 2.874  CPU 0.142 мс; доставлено 135 кадров за 1500 мс = 90.0 к/с из 90 (100%); промахов по бюджету нет
    N=50    отрисовок 1     GPU 2.915  CPU 0.141 мс; доставлено 136 кадров за 1510 мс = 90.1 к/с из 90 (100%); промахов по бюджету нет
    N=25    отрисовок 1     GPU 2.880  CPU 0.144 мс; доставлено 135 кадров за 1500 мс = 90.0 к/с из 90 (100%); промахов по бюджету нет
    N=0     отрисовок 0     GPU 2.881  CPU 0.125 мс; доставлено 135 кадров за 1500 мс = 90.0 к/с из 90 (100%); промахов по бюджету нет
сырые точки: /data/data/org.flamti.vrge.probe/files/curve.tsv — свод с хостом: tools/join_windows.py
  PASS  K гейт состояния: MSAA вставал в каждый режим, остальное состояние не менялось
  PASS  K гейт счётчика, MSAA off: все 36 точек дали ровно N отрисовок
  PASS  K гейт счётчика, MSAA 2x: все 36 точек дали ровно N отрисовок
  PASS  K гейт инстансов: при любом N>0 ровно 1 отрисовок — инстансинг работает
  PASS  K контроль порядка, MSAA off: вверх и вниз расходятся в среднем на 5.9% (худшая N=650, 17.6%) — в пределах дрейфа 15%, форма принадлежит N
  PASS  K контроль порядка, MSAA 2x: вверх и вниз расходятся в среднем на 4.3% (худшая N=650, 25.8%) — в пределах дрейфа 15%, форма принадлежит N
  PASS  K излом, MSAA off: лучшая ломаная с изломом на N=1000 — до 5.775, после 1.628 мкс/вызов (разброс проходов 0.733); SSE прямой 5.1614 против ломаной 2.1343 — ИЗЛОМ ЗНАЧИМ
  PASS  K излом, MSAA 2x: лучшая ломаная с изломом на N=650 — до 3.392, после 4.639 мкс/вызов (разброс проходов 0.392); SSE прямой 5.7137 против ломаной 3.2707 — ИЗЛОМ ЗНАЧИМ
  PASS  K инстансы на 90 Гц: наклон без нуля 0.0236 мкс/инстанс (проходы [0.02922918033643, 0.01798695410677], разброс 0.0112) — НАКЛОН ЗНАЧИМ; ступенька 0→25: 0.002 мс
  PASS  K доставка на N=1600: off: сверх бюджета 0; 2x: сверх бюджета 0 — промахов нет

фаза E пропущена (маркер user://skip_sustained или флаг)

passed=51 failed=3 unknown=4
пол: исполнено 58/58 проверок
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
