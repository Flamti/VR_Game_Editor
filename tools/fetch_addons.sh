#!/usr/bin/env bash
# Установка сторонних аддонов, которые НЕ хранятся в репозитории.
#
# Почему не в git: godot_openxr_vendors — 82 МБ бинарников под пять платформ.
# Плюс правило *.so в .gitignore отфильтровало бы 8 файлов из 36, и в
# репозиторий попал бы сломанный плагин. Подробности — ADR-0005.

. "$(dirname "${BASH_SOURCE[0]}")/env.sh"

# Пин версии. compatibility_minimum = "4.6", с Godot 4.7.2 совместим.
VENDORS_TAG="5.1.0-stable"
VENDORS_URL="https://github.com/GodotVR/godot_openxr_vendors/releases/download/${VENDORS_TAG}/godotopenxrvendorsaddon.zip"

PROJECT="${1:-probe}"
DEST="$VRGE_ROOT/projects/$PROJECT/addons"

require_cmd curl "загрузка"
require_cmd unzip "распаковка"
require_dir "$VRGE_ROOT/projects/$PROJECT" "проект $PROJECT"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

echo "качаю godot_openxr_vendors $VENDORS_TAG ..."
curl -fsSL -o "$tmp/vendors.zip" "$VENDORS_URL"
unzip -q "$tmp/vendors.zip" -d "$tmp/x"

src="$tmp/x/asset/addons/godotopenxrvendors"
[ -d "$src" ] || { echo "ОТКАЗ  структура архива изменилась: нет $src" >&2; exit 1; }

mkdir -p "$DEST"
rm -rf "$DEST/godotopenxrvendors"
cp -r "$src" "$DEST/"

# Проверка СОДЕРЖАНИЕМ, а не фактом успешной распаковки (PRACTICES §4.5).
fails=0
for f in plugin.gdextension .bin/android/template_release/arm64/libgodotopenxrvendors.so; do
    if [ -e "$DEST/godotopenxrvendors/$f" ]; then
        echo "  PASS  $f"
    else
        echo "  FAIL  отсутствует: $f" >&2
        fails=$((fails+1))
    fi
done
ver="$(grep -o 'compatibility_minimum = "[^"]*"' "$DEST/godotopenxrvendors/plugin.gdextension" 2>/dev/null || true)"
echo "  ${ver:-compatibility_minimum не найден}"
[ "$fails" -eq 0 ] || exit 1
echo "установлено в $DEST/godotopenxrvendors"
