#!/usr/bin/env bash
# Общее окружение. Подключается всеми скриптами в tools/.
# Локальные пути (NDK, SDK) переопределяются в tools/local.env — он в .gitignore.

set -euo pipefail

VRGE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export VRGE_ROOT
export VRGE_GODOT="$VRGE_ROOT/godot"
export VRGE_MODULES="$VRGE_ROOT/modules"
export VRGE_BIN="$VRGE_GODOT/bin"

[ -f "$VRGE_ROOT/tools/local.env" ] && . "$VRGE_ROOT/tools/local.env"

# Каждая проверка называет виновника поимённо (PRACTICES §1.4).
require_dir() {
    [ -d "$1" ] || { echo "ОТКАЗ  $2: каталога нет — $1" >&2; return 1; }
}
require_cmd() {
    command -v "$1" >/dev/null || { echo "ОТКАЗ  $2: команда не найдена — $1" >&2; return 1; }
}
require_env() {
    [ -n "${!1:-}" ] || { echo "ОТКАЗ  $2: переменная не задана — $1 (задайте в tools/local.env)" >&2; return 1; }
}

preflight_android() {
    local fails=0
    require_cmd scons "сборка"            || fails=$((fails+1))
    require_cmd python3 "сборка"          || fails=$((fails+1))
    require_cmd java "gradle"             || fails=$((fails+1))
    require_env ANDROID_HOME "Android SDK" || fails=$((fails+1))
    require_env ANDROID_NDK_ROOT "Android NDK" || fails=$((fails+1))
    require_dir "$VRGE_GODOT" "исходники Godot" || fails=$((fails+1))
    if [ "$fails" -gt 0 ]; then
        echo "" >&2
        echo "предполётная проверка: $fails отказ(ов). Сборка не запускалась." >&2
        return 1
    fi
    echo "предполётная проверка: пройдена"
}
