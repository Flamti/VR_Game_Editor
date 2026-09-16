# ADR-0009: ввод текста — системная клавиатура Meta через свой модуль-обёртку OpenXR

- **Дата:** 2026-09-16
- **Статус:** **предложено**. Решение владельца о клавиатуре принято; код модуля — после замера
  доступности расширений на шлеме (самопроверка шар-меню, проверка «клавиатура meta»).
- **Решает:** владелец проекта.
- **Связан с:** ADR-0002 (политика форка: наш код — в `modules/`, внутрь `godot/` не пишем),
  ADR-0005 (плагин вендоров), ADR-0008 (шар-меню: «Поиск» на верхнем уровне).

## Контекст

После сессии 2 шар-меню владелец переработал верхний уровень: «Поиск» стал его пунктом. Поиску нужен
ввод текста в VR. Варианты владельцу показаны 2026-09-16, выбрана **системная клавиатура Meta**.

Сверка (правило 8 и правило 4 `CLAUDE.md`):

- Расширение **`XR_META_virtual_keyboard`** (spec version 1) — имя и функции сверены с заголовком
  Khronos OpenXR 1.1.54 в `godot/thirdparty/openxr/include/openxr/openxr.h`:
  `xrCreateVirtualKeyboardMETA`, `xrCreateVirtualKeyboardSpaceMETA`,
  `xrSuggestVirtualKeyboardLocationMETA`, `xrSetVirtualKeyboardModelVisibilityMETA`,
  `xrGetVirtualKeyboardModelAnimationStatesMETA`, `xrGetVirtualKeyboardDirtyTexturesMETA`,
  `xrGetVirtualKeyboardTextureDataMETA`, `xrSendVirtualKeyboardInputMETA`,
  `xrChangeVirtualKeyboardTextContextMETA`; события `XR_TYPE_EVENT_DATA_VIRTUAL_KEYBOARD_COMMIT_TEXT_META`,
  `…_BACKSPACE_META`, `…_ENTER_META`, `…_SHOWN_META`, `…_HIDDEN_META`.
- Модель клавиатуры грузится через **`XR_FB_render_model`** (spec version 4) — так в документации
  Meta «Virtual Keyboard Native Integration»; руки — через `XR_EXT_hand_tracking` (необязательно).
- В godot_openxr_vendors 5.1.0 **обёртки клавиатуры нет** (поиск по сборке плагина; issue #77
  плагина — «нужна обёртка»), обёртка `XR_FB_render_model` для моделей контроллеров есть, но она в
  GDExtension и не отдаёт модель клавиатуры.

## Решение

1. **Свой модуль `modules/vrge_keyboard/`** — `OpenXRExtensionWrapper` на уровне CORE (ловушка 6),
   как `vrge_probe_xr`: запрашивает `XR_META_virtual_keyboard` и `XR_FB_render_model`, создаёт
   клавиатуру и её пространство после создания сессии, отдаёт в GDScript:
   - показать/скрыть над шаром (`xrSuggestVirtualKeyboardLocationMETA` в позе панели);
   - модель: путь из `xrEnumerateRenderModelPathsFB`, glTF из `xrLoadRenderModelFB` →
     `GLTFDocument` → узел сцены; анимации и «грязные» текстуры — каждый кадр;
   - ввод: луч и касание правого контроллера → `xrSendVirtualKeyboardInputMETA`;
   - события COMMIT_TEXT / BACKSPACE / ENTER / HIDDEN → сигналы; текст поиска держит GDScript и
     сообщает клавиатуре `xrChangeVirtualKeyboardTextContextMETA`.
2. **До готовности модуля** поиск вводится временной русской раскладкой на интерактивной панели
   (`menu/ui_panel.gd`, помечена «временно»). Она удаляется, когда модуль пройдёт сессию на шлеме.
3. **Сначала замер**: доступность обоих расширений у рантайма Quest печатает самопроверка
   (контроль — `XR_KHR_vulkan_enable2`). Нет расширения — ADR пересматривается до кода.

## Отвергнутые альтернативы

- **Панельная клавиатура насовсем** — готова и проверена лучом, но владелец выбрал системную:
  привычная раскладка Quest, свайп, касание руками.
- **Ждать обёртку в плагине вендоров** — сроков нет; поиск нужен в этапе 1.
- **Патч внутрь `godot/`** — запрещён без отдельного ADR (ADR-0002); модуль даёт то же без патча.
- **Android-клавиатура (IME) через `DisplayServer.virtual_keyboard_show`** — в иммерсивной сессии
  OpenXR системный IME 2D-оболочки не виден пользователю; не проверялось на шлеме, и выбор
  владельца делает проверку ненужной.

## Последствия, которые надо принять

- Сборка `.so` и четыре шага цепочки до APK на каждую правку модуля (минуты, не секунды GDScript).
- Модель клавиатуры рисуется нашим рендером: MSAA 2x, прогрев материалов glTF (ADR-0003 п. 9) —
  иначе первый показ клавиатуры даст кадр ≈1 с на холодном кэше.
- Зависимость от расширения Meta: на PCVR и других шлемах поиск останется на временном вводе.

## Когда пересматривать

- Самопроверка на шлеме показала, что `XR_META_virtual_keyboard` или `XR_FB_render_model` недоступны.
- В godot_openxr_vendors появилась обёртка клавиатуры — сравнить со своим модулем.
- Цена первого показа или кадра с клавиатурой выходит за бюджет 90 Гц (ADR-0007).
