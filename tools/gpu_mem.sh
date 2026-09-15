#!/usr/bin/env bash
# Память GPU процесса прибора на время прогона: vk_devicememory, texture и др.
#
# Зачем. Вложения MSAA в Godot не ленивые (TODO render_scene_buffers_rd.cpp:188),
# и сколько VRAM стоит 2x, изнутри приложения не видно. gpumeminfo — штатный
# инструмент Quest (developers.meta.com/horizon/documentation/unity/ts-gpumeminfo),
# считает по процессу.
#
# Использование:
#   tools/gpu_mem.sh [файл] [период_с] [пакет]
#   Ctrl-C — остановить.
#
# Формат строки TSV: unix_время  тип  total_KB  mapped_KB  count

set -u
OUT="${1:-docs/measurements/gpu-mem-$(date +%Y%m%d-%H%M%S).tsv}"
PERIOD="${2:-1}"
PKG="${3:-org.flamti.vrge.probe}"

if ! adb get-state >/dev/null 2>&1; then
    echo "устройство не на связи: adb get-state не отвечает" >&2
    exit 1
fi

# Контроль ДО записи: процесс жив и gpumeminfo отдаёт по нему vk_devicememory.
# Без процесса gpumeminfo молча печатает пустоту, и TSV выглядел бы прогоном.
pid="$(adb shell pidof "$PKG" | tr -d '\r')"
if [ -z "$pid" ]; then
    echo "процесс $PKG не запущен" >&2
    exit 1
fi
if ! adb shell gpumeminfo -p "$pid" -o 2>&1 | grep -q vk_devicememory; then
    echo "gpumeminfo не отдаёт vk_devicememory для PID $pid" >&2
    exit 1
fi
echo "контроль: PID $pid, vk_devicememory читается"

mkdir -p "$(dirname "$OUT")"
{
    echo "# память GPU процесса $PKG (PID $pid), период ${PERIOD} с"
    printf '# unix_время\tтип\ttotal_KB\tmapped_KB\tcount\n'
} > "$OUT"
echo "пишу в $OUT; остановить — Ctrl-C"

# Цикл на устройстве, разбор на хосте: строки вида
#   vk_devicememory: total  470456 KB ( 459 MB) mapped  387324 KB ( 378 MB) count:350
# разбираются по ключевым словам, а не по позиции — при 1000+ МБ скобка
# слипается с числом «(1172 MB)», и позиционный разбор съезжает.
# fflush на каждой строке: буферизующий фильтр теряет хвост при Ctrl-C
# (так в gpu_sampler.sh пропали шесть секунд данных).
# Смерть процесса завершает цикл — иначе хвост заполнился бы пустыми выборками.
adb exec-out "while [ -d /proc/$pid ]; do
    echo \"### \$(date +%s.%N)\"
    gpumeminfo -p $pid -o 2>/dev/null
    sleep $PERIOD
done" | awk -f "$(dirname "$0")/gpu_mem_parse.awk" >> "$OUT"
echo "процесс $pid завершился — запись остановлена" >&2
