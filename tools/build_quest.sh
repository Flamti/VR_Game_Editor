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
scons platform=android arch=arm64 target="$TARGET" \
      custom_modules="$VRGE_MODULES" \
      -j"$JOBS"

echo "scons завершён. Код возврата НЕ является доказательством."
echo "Проверьте артефакт содержанием: tools/verify_artifact.sh"
