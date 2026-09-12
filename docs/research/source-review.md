# Разбор исходного исследования: что в нём неверно

Проверка `/home/flamti/Downloads/VR_Game_Editor_Research.pdf` от 2026-09-12.

**Природа источника.** PDF создан 2026-09-12 (`Producer: Skia/PDF`, `HeadlessChrome`) — это экспорт
веб-страницы. Внутри три слоя: ТЗ владельца (стр. 1–2), «Советы Perplexity» (стр. 2–7), «Исследование
Gemini» (стр. 8–24). **Это выводы LLM, а не спецификация вендора.** Поэтому проверка выявила не
устаревание, а фактические ошибки.

Файл существует, чтобы ошибки не вернулись в проект через полгода, когда PDF перечитают заново.

---

## Ошибки: не использовать

| № | Утверждение PDF | Как на самом деле | Стр. |
|---|---|---|---|
| 1 | Dynamic foveated rendering по eye tracking; «<12 мс для eye tracking» | **У Quest 3 нет eye tracking.** ETFR только на Quest Pro. «Dynamic FR» на Quest 3 меняет *уровень* фовеации по загрузке GPU, область высокого разрешения за взглядом НЕ движется | 3, 6 |
| 2 | OpenXR покрывает «Quest 3, Vision Pro, PICO, Index, Vive» | **Vision Pro не поддерживает OpenXR.** visionOS — CompositorServices/RealityKit/Metal. Это отдельный порт, а не «платформенный оверрайд» | 4, 5 |
| 3 | `VK_NVX_multiview_per_view_attributes` | `NVX` — вендорский префикс **NVIDIA**, на Adreno отсутствует. Нужно **`VK_KHR_multiview`**, core с Vulkan 1.1. Описание механизма при этом верное | 11 |
| 4 | `XR_FB_composition_layer_quad`, `XR_FB_composition_layer_cylinder` | **Обоих не существует.** Quad — core OpenXR (`XrCompositionLayerQuad`); цилиндр — `XR_KHR_composition_layer_cylinder` (`XrCompositionLayerCylinderKHR`) | 17 |
| 5 | Vulkan 1.4 как база; `VK_KHR_dynamic_rendering_local_read` | Драйверы Quest 3 сообщают **Vulkan 1.3.295**. Расширение вошло в core в 1.4; на 1.3 доступно только если драйвер его экспортирует. **Не проверено** — вопрос №1 к прибору | 11, 22 |
| 6 | Azure / Google Cloud Anchors | **Azure Spatial Anchors выключены Microsoft 20.11.2024** | 3 |
| 7 | «Присмотреться к языку Jai» | На 09.2026 — **закрытая бета по инвайтам** (0.2.026, февраль 2026). Публичного релиза нет, Android-таргета нет | 7 |
| 8 | «C# (IL2CPP для Quest)» | **IL2CPP — внутренняя технология Unity**, отдельно не поставляется | 7 |
| 9 | Draw calls: «<800 (желательно <500)» и «**< 200**» | Документ противоречит сам себе в 4 раза. Числа 500–1000, которые всплывают в поиске, — из **PC SDK (Rift)** guidelines Meta, к мобильному Quest не относятся. Мерить прибором (PRACTICES §3.1) | 2, 9 |
| 10 | «Meta XR SDK» как нативный путь | Устаревшая формулировка: VrApi снят, нативный путь — OpenXR + вендорские расширения Meta | 1 |
| 11 | Adreno как классический TBDR | У Adreno «FlexRender»: драйвер переключается между биннингом и прямым рендером. На выводы про `loadOp`/`storeOp` не влияет, но формулировка неточна | 10 |
| 12 | AppSW: экономия только через отказ от Z (RG16f вместо RGBA16f) | Расширение названо по смыслу верно (`XR_FB_space_warp`), но **главная экономия пропущена**: буфер векторов движения рендерится в сильно пониженном разрешении (у Quest 2 — 368×400 против eye buffer 1440×1584) | 14 |
| 13 | Niantic Spatial SDK | В 2025 игровое подразделение продано Scopely; VPS живёт под брендом Niantic Spatial. Не мёртв, но это уже не то, что описано | 19 |

## Чего в PDF нет, а надо знать

- **Android XR / Samsung Galaxy XR** (октябрь 2025, SDK в Developer Preview 4, OpenXR 1.0/1.1) — вторая
  реальная автономная мишень помимо Quest. В документе отсутствует полностью.
- **Godot 4.7** (июнь 2026, стабильный 4.7.2 от 18.08.2026): OpenXR 1.1 с фоллбэком на 1.0, Spatial
  Entities, frame synthesis, универсальный APK на Quest/PICO/Galaxy XR/Steam Frame, Vulkan subsampled
  images для фовеации, улучшенные composition layers, стабильный GABE. Редактор Godot уже запускается
  нативно на Quest 3. Документ этого не учитывает и молча предполагает разработку с нуля.

## Внутреннее противоречие документа

Цель владельца (стр. 1): редактор, работающий **внутри VR на автономном шлеме**.
Вывод документа (стр. 7): «Редактор: кастомный на **Qt/ImGui** с превью в real-time».

Qt/ImGui — десктопный 2D-тулинг, на Quest как VR-редактор не запустится. Раздел «идеальный стек»
отвечает на вопрос «как сделать движок», а не «как сделать VR-редактор». Сигнатурная идея владельца —
шар с гексагональной сеткой и прокруткой с обратной стороны — в стеке не учтена вообще.

Второе умолчание: **экспорт проекта как отдельного приложения** (стр. 1). На автономном шлеме это
значит либо кодогенерацию с APK-упаковкой на устройстве, либо рантайм-интерпретацию данных проекта.
Архитектуры разные, и выбор определяет формат сцен, логики и ассетов. Открытый вопрос, нужен ADR.

---

## Что в документе держится

Ядро исследования здравое, и это стоит сказать отдельно:

- **Clustered Forward + MSAA вместо Deferred** на мобильном GPU — верно, обоснование через размер
  G-Buffer против объёма SRAM корректно.
- **Явное управление `loadOp`/`storeOp`, `LAZILY_ALLOCATED` для MSAA-вложений** — реальный и главный
  рычаг экономии пропускной способности на тайловой архитектуре.
- **CPU как узкое место** XR2 Gen 2 (2 больших + 4 малых ядра, TDP 4–6 Вт), отсюда DOD/ECS — верно.
- **Jolt Physics** — жив, 5.6 (2026), Data-Oriented, свой Job System, NEON на arm64.
- **Flecs** — жив, C/C++, кэш-локальность.
- **Yoga** (Flexbox на C++) и **MSDF** для текста — обе технологии реальны и уместны для spatial UI.
- **Late Latching** — реален, требует Multiview + Vulkan, вносит рассинхрон физики и картинки
  (документ это честно называет).
- **Термальный троттлинг со сбросом на 72 Гц** — реален, движок обязан адаптироваться на лету.
- **Вывод UI через OpenXR composition layers** вместо мирового буфера — правильно (имена расширений
  в документе при этом неверны, см. №4).

---

## Источники проверки

- Eye tracking / ETFR: developers.meta.com/horizon/documentation/unreal/unreal-eye-tracked-foveated-rendering/
- Vision Pro и OpenXR: uploadvr.com/godot-now-supports-visionos-apple-vision-pro/
- Multiview: developers.meta.com/horizon/documentation/unity/enable-multiview/
- Composition layers: registry.khronos.org/OpenXR/specs/1.1/man/html/XrCompositionLayerCylinderKHR.html
- AppSW: developers.meta.com/horizon/documentation/unity/unity-asw/
- Late Latching: developers.meta.com/horizon/documentation/unity/enable-late-latching/
- Azure Spatial Anchors: learn.microsoft.com/en-us/lifecycle/products/azure-spatial-anchors
- Jai: mrphilgames.com/blog/jai-in-2026
- Godot 4.7 XR: vr.org/articles/godot-4-7-xr-steam-frame-android-xr-open-source-2026
- Godot регрессия OpenXR/Vulkan: github.com/godotengine/godot/issues/115924 (закрыта PR #116226)
- Meta PC perf guidelines: developers.meta.com/horizon/documentation/native/pc/dg-performance-guidelines/

## Что прибор уже уточнил (2026-09-12, десктоп)

Целевого железа это не касается, но одну формулировку исследования уже поправило:

- Фовеация реализуется **разными расширениями на разных архитектурах**. Исследование называет только
  тайловый путь; на десктопной NVIDIA `VK_EXT_fragment_density_map` отсутствует, а фовеация идёт
  через `VK_KHR_fragment_shading_rate` / `VK_NV_shading_rate_image`. Прибор поэтому проверяет
  **семейство целиком** и называет, какой механизм найден, а не считает отсутствие FDM отказом.
- `VK_KHR_dynamic_rendering_local_read` на десктопной NVIDIA есть — но там Vulkan **1.4.341**, где
  расширение вошло в core. Для Adreno 740 при Vulkan 1.3 это **ничего не доказывает**. Пункт 5
  остаётся открытым.

## Что НЕ проверено

**Ни одно утверждение этого файла не проверено на реальном железе.** Всё — сверка с вендорскими и
Khronos-источниками. Наличие `VK_KHR_dynamic_rendering_local_read` на Adreno 740 не подтверждено ни
в одну сторону: публичных данных нет, это первый вопрос к прибору (`modules/vrge_probe/`).

## Когда обновлять этот файл

- Прибор снял паспорт железа — перенести подтверждённое/опровергнутое, особенно пункты 5 и 9.
- Появилась новая версия исходного исследования или новый источник рекомендаций.
- Вышла версия Horizon OS, меняющая версию Vulkan или набор расширений.
- Godot сменил мажорную/минорную версию с изменениями в XR.
- Кто-то предложил вернуть технологию из списка ошибок — дописать, почему снова нет.
