#!/usr/bin/env bash
# Статистика композитора Quest (VrApi) раз в секунду, с unix-временем.
#
# Зачем. Это независимый от приложения свидетель: FPS=приложение/дисплей, Stale
# (кадры, которые композитор показал повторно), App и CPU&GPU мс, клок GPU,
# Preempt, температура, DVFS, а при синтезе — поле ASW. Приложение не видит, что
# доехало до дисплея; рантайм подтверждает даже частоты, которых нет (ловушка 14).
# Формат строки — документация Meta (App SpaceWarp: «FPS=36/72», «ASW=72, Type=App»).
#
# Использование:
#   tools/vrapi_log.sh [файл]     Ctrl-C — остановить
#
# Вывод — TSV: unix_время  FPS_прил  FPS_дисплей  Stale  ASW  GPU_МГц  App_мс
#               CPU&GPU_мс  Preempt  Temp_C  GPU%  строка_целиком

set -u
OUT="${1:-docs/measurements/vrapi-$(date +%Y%m%d-%H%M%S).tsv}"

if ! adb get-state >/dev/null 2>&1; then
    echo "устройство не на связи: adb get-state не отвечает" >&2
    exit 1
fi

# Контроль ДО записи: строка VrApi с FPS= должна быть в буфере — композитор
# пишет её всегда, даже в оболочке. Нет строки — формат прошивки сменился.
if ! adb logcat -d -s VrApi:I | grep -q 'FPS='; then
    echo "в logcat нет строк VrApi с FPS= — формат прошивки сменился или тег другой" >&2
    exit 1
fi
echo "контроль: строки VrApi с FPS= есть"

mkdir -p "$(dirname "$OUT")"
printf '# unix_время\tFPS_прил\tFPS_дисплей\tStale\tASW\tGPU_МГц\tApp_мс\tCPU&GPU_мс\tPreempt\tTemp_C\tGPU%%\tстрока\n' > "$OUT"
echo "пишу в $OUT; остановить — Ctrl-C"

# Шлем во сне VrApi не пишет — файл останется с одним заголовком.
# -T 1: начиная с текущего момента, без старого буфера. fflush — чтобы Ctrl-C
# не потерял хвост (так в gpu_sampler.sh пропали шесть секунд).
adb logcat -v epoch -T 1 -s VrApi:I | awk -f "$(dirname "$0")/vrapi_parse.awk" >> "$OUT"
