#!/usr/bin/env bash
# Сборка Android-шаблона Godot с нашими модулями.
# Запускать ФОНОМ (PRACTICES §5.4): сборка Godot — это десятки минут.
# Успех проверяется НЕ кодом возврата, а tools/verify_artifact.sh (PRACTICES §4.5).

. "$(dirname "${BASH_SOURCE[0]}")/env.sh"

TARGET="${1:-template_release}"
JOBS="${VRGE_JOBS:-$(nproc)}"

preflight_android

echo "сборка: platform=android arch=arm64 target=$TARGET jobs=$JOBS"
echo "модули: $VRGE_MODULES"

cd "$VRGE_GODOT"

# swappy=yes — это УТВЕРЖДЕНИЕ, а не переключатель.
#
# Godot линкует Swappy по НАЛИЧИЮ файлов в thirdparty/swappy-frame-pacing
# (platform/android/detect.py:230-245, ветки по arch добавляют LIBPATH при
# has_swappy). Флаг swappy=yes влияет только на одно: при отсутствии файлов
# сборка падает с ошибкой вместо предупреждения (detect.py:222).
#
# Для VR это обязательно. Без Swappy кадровый пейсинг гарантированно рвётся,
# а симптом на шлеме выглядит как необъяснимое дёрганье — и его будут искать
# в своём коде. Молчаливая деградация до такой сборки недопустима.
scons platform=android arch=arm64 target="$TARGET" \
      custom_modules="$VRGE_MODULES" \
      swappy=yes \
      -j"$JOBS"

echo "scons завершён. Код возврата НЕ является доказательством."
echo "Проверьте артефакт содержанием: tools/verify_artifact.sh"
