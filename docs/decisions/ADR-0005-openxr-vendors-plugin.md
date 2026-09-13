# ADR-0005: загрузчик OpenXR для Android даёт плагин, а не Godot

- **Дата:** 2026-09-12
- **Статус:** принято

## Контекст

Первый экспорт APK прошёл успешно и дал подписанный файл. Проверка **содержимым** показала,
что в нём нет ни `libopenxr_loader.so`, ни записей OpenXR в манифесте:

```
=== libopenxr_loader в APK? ===
НЕТ — загрузчика OpenXR в APK нет
=== OpenXR в манифесте ===
(пусто: ни IMMERSIVE_HMD, ни android.hardware.vr.headtracking)
```

Такой APK **устанавливается** на Quest и **запускается** — но как плоское Android-приложение.
OpenXR не поднимается. Симптом на шлеме выглядел бы как «приложение открылось окном, шлем не
переключился в VR», и искать причину стали бы в коде движка.

## Корень

В Godot 4.7 опция экспорта `xr_features/xr_mode=1` (OpenXR) влияет **только на командную строку
движка** — `export_plugin.cpp:3246-3252` добавляет `--xr_mode_openxr`. Манифест она не трогает.

Записи манифеста (`org.khronos.openxr.permission.OPENXR`, провайдер runtime_broker,
`IMMERSIVE_HMD`, `android.hardware.vr.headtracking`) и сам Android-загрузчик OpenXR приходят из
**отдельного плагина** `GodotVR/godot_openxr_vendors`. В штатном шаблоне приложения их нет:
`org.khronos.openxr:openxr_loader_for_android` подключается только в сборке **редактора**
(`platform/android/java/editor/build.gradle:212`), но не приложения.

Формулировка «Godot 4.6 даёт универсальный OpenXR APK» относится к тому, что плагин версии 4+
кладёт **один Khronos-загрузчик** вместо вендорских — а не к тому, что он встроен в движок.

## Решение

1. В проекты, которые экспортируются на автономный шлем, ставится плагин
   `godot_openxr_vendors` (`addons/godotopenxrvendors/`), пин **5.1.0-stable**
   (`compatibility_minimum = "4.6"`, с 4.7 совместим).
2. Плагин поставляет `.aar`, а `.aar` вливается **только gradle-сборкой**. Поэтому в пресете
   обязательно `gradle_build/use_gradle_build=true`, и проекту нужен Android Build Template
   (`--install-android-build-template`).
3. Для Quest включается вендор Meta: `xr_features/enable_meta_plugin=true`. Именно он даёт
   расширения `XR_FB_*` и `XR_META_*`, которые проверяет прибор.

   **Поправка 2026-09-12.** Здесь стояло ещё `xr_features/quest_3_support=true` — **такой опции
   не существует**. Вендорские фичи плагин регистрирует под префиксом `meta_xr_features/`, а
   Godot из `xr_features/` знает только `xr_mode` (`export_plugin.cpp:2257`). Ключ молча
   игнорировался всё время. Ущерба не было по случайности: `quest3` и так входит в умолчание
   плагина — манифест собранного APK показывает
   `com.oculus.supportedDevices="quest2|quest3|quest3s|questpro"`. Проверено `aapt2 dump
   xmltree`, а не чтением пресета. В пресете ключи исправлены на `meta_xr_features/*`.

## Отвергнутая альтернатива

**`enable_khronos_plugin` вместо `enable_meta_plugin`.** Khronos-загрузчик универсален и даёт
один APK на все шлемы — но вендорские расширения Meta (space warp, environment depth, foveation)
через него не появятся. Для этапа снятия паспорта железа нужен именно Meta. К универсальному APK
имеет смысл вернуться, когда появится вторая целевая платформа.

## Урок, который дороже самого решения

Экспорт **завершился успешно** и выдал подписанный APK. Код возврата был 0. Дефект нашёлся
только потому, что артефакт проверяли содержимым: наличием `libopenxr_loader.so` и записей в
манифесте. Это ровно PRACTICES §4.5 — «дата артефакта не равна его содержанию», и §1.3 —
«мерить исполнением, а не текстом».

## Когда пересматривать

- Godot начал включать Android-загрузчик OpenXR в штатный шаблон приложения.
- Появилась вторая целевая платформа — перейти на `enable_khronos_plugin`.
- Вышла новая версия плагина: сверить `compatibility_minimum` и пин.
- Понадобилась вендорская фича из `meta_xr_features/*`: проверять её действие **манифестом
  собранного APK** (`aapt2 dump xmltree`), а не наличием строки в пресете. Опция
  `meta_xr_features/hand_tracking=1` записана, но в манифест ничего не добавляет, и причина
  не установлена — см. `docs/context.md`.

  **Поправка 2026-09-13: причина установлена.** Плагин пишет запись о руках только по настройке
  проекта `xr/openxr/extensions/hand_tracking` (`meta_export_plugin.cpp:375`); опция пресета
  лишь выбирает Optional/Required. После `openxr/extensions/hand_tracking=true` в
  `project.godot` манифест содержит `com.oculus.permission.HAND_TRACKING` и
  `oculus.software.handtracking` — проверено `aapt2`. Ловушка 20 в `CLAUDE.md`.
