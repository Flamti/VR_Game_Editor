#!/usr/bin/env bash
# Сэмплер частоты GPU на время прогона прибора.
#
# Зачем отдельный инструмент. Изнутри приложения /sys/... не открыть: Godot на
# Android отдаёт ACCESS_FILESYSTEM Java-слою (platform/android/os_android.cpp:121),
# и абсолютные пути туда не доходят. При этом из adb shell те же файлы читаются.
# Поэтому клок снимается с хоста параллельно прогону и сводится с прибором по
# времени: прибор пишет unix-время в свой TSV, сэмплер — сюда.
#
# Цикл крутится НА УСТРОЙСТВЕ, а не на хосте: иначе каждая выборка стоила бы
# запуска adb (десятки миллисекунд) и период плыл бы.
#
# Использование:
#   tools/gpu_sampler.sh [файл] [период_с]
#   Ctrl-C — остановить. По остановке печатается сводка.

set -u
OUT="${1:-docs/measurements/gpu-clock-$(date +%Y%m%d-%H%M%S).tsv}"
PERIOD="${2:-0.25}"
KGSL=/sys/class/kgsl/kgsl-3d0

if ! adb get-state >/dev/null 2>&1; then
    echo "устройство не на связи: adb get-state не отвечает" >&2
    exit 1
fi

# Контроль ДО запуска: если файл не читается, писать пустой TSV бессмысленно
# (PRACTICES §2.3 — слепой прибор опаснее сломанного кода).
probe="$(adb shell cat $KGSL/gpuclk 2>&1 | tr -d '\r')"
case "$probe" in
    ''|*[!0-9]*) echo "gpuclk не читается с устройства: '$probe'" >&2; exit 1 ;;
esac
echo "контроль: gpuclk = $probe Гц — читается"

mkdir -p "$(dirname "$OUT")"
{
    echo "# сэмплер частоты GPU, период ${PERIOD} с"
    echo "# лестница: $(adb shell cat $KGSL/gpu_available_frequencies 2>/dev/null | tr -d '\r')"
    printf '# unix_время\tклок_Гц\tзагрузка_%%\tрезиденция_по_ступеням\n'
} > "$OUT"

echo "пишу в $OUT; остановить — Ctrl-C"

# exec-out, а не shell: shell выделяет pty, из-за чего строки приходят с \r и,
# что хуже, проходят через буферизующий tr — на первой проверке шесть секунд
# данных потерялись при остановке. exec-out отдаёт поток как есть.
# shellcheck disable=SC2016
adb exec-out "while true; do
    printf '%s\t%s\t%s\t%s\n' \
        \"\$(date +%s.%N)\" \
        \"\$(cat $KGSL/gpuclk 2>/dev/null)\" \
        \"\$(cat $KGSL/gpu_busy_percentage 2>/dev/null | tr -d ' %')\" \
        \"\$(cat $KGSL/gpu_clock_stats 2>/dev/null)\"
    sleep $PERIOD
done" >> "$OUT"
