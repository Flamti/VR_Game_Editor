#!/usr/bin/env bash
# Установка APK на шлем и сбор лога.
# НЕ запускается автоматически: разворачивание на устройство — по команде владельца (PRACTICES §7.3).

. "$(dirname "${BASH_SOURCE[0]}")/env.sh"

APK="${1:?укажите путь к APK: tools/deploy_quest.sh <file.apk>}"
[ -f "$APK" ] || { echo "ОТКАЗ  деплой: файла нет — $APK" >&2; exit 1; }

require_cmd adb "деплой"

devices="$(adb devices | awk 'NR>1 && $2=="device" {print $1}')"
if [ -z "$devices" ]; then
    echo "ОТКАЗ  деплой: ни одного устройства в состоянии 'device'." >&2
    echo "       Проверьте: шлем включён, USB-отладка разрешена, кабель data (не только питание)." >&2
    adb devices -l >&2
    exit 1
fi
echo "устройство: $devices"

adb install -r "$APK"
echo "установлено. Запуск и сбор лога — отдельной командой, чтобы лог не смешался с установкой."
