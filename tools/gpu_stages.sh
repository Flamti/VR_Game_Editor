#!/usr/bin/env bash
# Трасса стадий рендера Adreno на время прогона прибора: размер и число бинов,
# режим рендера поверхности (Direct / HwBinning / SwBinning / HwDirect), время
# стадий Binning / Render / Store.
#
# Зачем. Режим GMEM и размер тайла из приложения не спросить: Godot не включает
# VK_QCOM_tile_properties (rendering_device_driver_vulkan.cpp:557-571), а патч
# внутрь godot/ отвергнут — режима он не даёт вовсе. Штатный ovrgpuprofiler
# Quest отвечает на оба вопроса снаружи (developers.meta.com/horizon/
# documentation/unity/ts-ovrgpuprofiler).
#
# ОГРАНИЧЕНИЕ. Детальный режим драйвера действует только на приложения,
# запущенные ПОСЛЕ -e, и сам по себе может менять время кадра. Числа времени
# кадра из прогона с детальным режимом не смешивать с обычными: сравнивать
# режим и бины, а цену — только из прогона без режима (или проверить, что
# режим её не сдвигает, на контрольной точке).
#
# Использование:
#   tools/gpu_stages.sh enable [пакет]    включить детальный режим (до запуска!)
#   tools/gpu_stages.sh disable           выключить
#   tools/gpu_stages.sh [файл] [окно_с] [пауза_с]
#                                         писать трассы, Ctrl-C — остановить
#
# Вывод — сырой текст трасс, каждая с заголовком «### unix_время». Разбор —
# отдельно: формат трассы на этой прошивке не зафиксирован, а сырьё
# переживает ошибку разборщика.

set -u
PKG_DEFAULT=org.flamti.vrge.probe

if ! adb get-state >/dev/null 2>&1; then
    echo "устройство не на связи: adb get-state не отвечает" >&2
    exit 1
fi

case "${1:-}" in
    enable)
        adb shell ovrgpuprofiler -e "${2:-$PKG_DEFAULT}"
        adb shell ovrgpuprofiler -i
        echo "теперь ЗАПУСКАТЬ приложение: на уже запущенное режим не действует"
        exit 0 ;;
    disable)
        adb shell ovrgpuprofiler -d
        adb shell ovrgpuprofiler -i
        exit 0 ;;
esac

OUT="${1:-docs/measurements/gpu-stages-$(date +%Y%m%d-%H%M%S).txt}"
WINDOW="${2:-0.2}"
PAUSE="${3:-1}"

# Контроль ДО записи (PRACTICES §2.3): режим включён и трасса содержит бины.
# Иначе файл выглядел бы как прогон, а был бы пуст.
if ! adb shell ovrgpuprofiler -i 2>&1 | grep -qi enabled; then
    echo "детальный режим выключен: $0 enable, затем запустить приложение" >&2
    exit 1
fi
probe="$(adb exec-out ovrgpuprofiler -t"$WINDOW" 2>&1)"
if ! printf '%s' "$probe" | grep -q 'bins'; then
    echo "контрольная трасса без строк 'bins' — приложение не рендерит или запущено до enable:" >&2
    printf '%s\n' "$probe" | head -5 >&2
    exit 1
fi
echo "контроль: трасса содержит $(printf '%s' "$probe" | grep -c 'bins') строк с бинами"

mkdir -p "$(dirname "$OUT")"
{
    echo "# трассы стадий рендера, окно ${WINDOW} с, пауза ${PAUSE} с"
    echo "# детальный режим: $(adb shell ovrgpuprofiler -i | tr -d '\r')"
} > "$OUT"
echo "пишу в $OUT; остановить — Ctrl-C"

# Цикл на устройстве, как в gpu_sampler.sh: время ставится там же, где снята
# трасса, а не на хосте через задержку adb. Время — ДО трассы: трасса
# покрывает [время, время + окно].
adb exec-out "while true; do
    echo \"### \$(date +%s.%N)\"
    ovrgpuprofiler -t$WINDOW 2>&1
    sleep $PAUSE
done" >> "$OUT"
