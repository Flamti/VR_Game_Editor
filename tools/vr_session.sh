#!/usr/bin/env bash
# Прогон шар-меню на шлеме одной командой: отметка журнала, запуск, сбор и отчёт.
#
#   tools/vr_session.sh mark    запомнить длину журнала на шлеме, ничего не запуская
#   tools/vr_session.sh start   mark + logcat -c + запуск приложения + проверка старта
#   tools/vr_session.sh pull    забрать журнал С ОТМЕТКИ, logcat и выгрузку; собрать отчёт
#
# `start` запускает приложение — только по команде владельца (PRACTICES §7.3, CLAUDE.md: прогоны
# со шлемом на голове). `mark` и `pull` ничего не запускают.
#
# Почему журнал, а не logcat: logcat за несколько минут вытесняется шумом системы (сессия 35:
# из 403 строк журнала logcat сохранил 6). Журнал пишется в шлеме по ходу, все сессии подряд, —
# «эта сессия» есть всё после отметки.

. "$(dirname "${BASH_SOURCE[0]}")/env.sh"

PKG="org.flamti.vrge.sphere"
ACT="$PKG/com.godot.game.GodotAppLauncher"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIR="$ROOT/build/sessions"
MARK="$DIR/.mark"

require_cmd adb "сессия шлема" || exit 1
mkdir -p "$DIR"

device() {
    local d
    d="$(adb devices | awk 'NR>1 && $2=="device" {print $1}')"
    if [ -z "$d" ]; then
        echo "ОТКАЗ  шлем не в состоянии 'device' — включён ли, разрешена ли отладка, data-кабель?" >&2
        adb devices -l >&2
        return 1
    fi
}

journal_lines() {
    adb shell run-as "$PKG" wc -l files/sphere_session.tsv 2>/dev/null | awk '{print $1}'
}

do_mark() {
    local n
    n="$(journal_lines)"
    # Журнала ещё нет (первый запуск после установки начисто) — отметка 0, а не отказ.
    n="${n:-0}"
    printf '%s\t%s\n' "$n" "$(date +%Y-%m-%dT%H:%M:%S)" > "$MARK"
    echo "отметка: в журнале $n строк, эта сессия — с $((n + 1))-й"
}

case "${1:-}" in
mark)
    device || exit 1
    do_mark
    ;;
start)
    device || exit 1
    do_mark
    adb logcat -c
    adb shell am start -n "$ACT" >/dev/null
    echo "запущено; жду старта 10 с"
    sleep 10
    # Ловушка 13: оболочка перехватывает запуск при неактивных контроллерах — ни лога, ни журнала.
    if adb logcat -d | grep -q RequiresControllersLaunchInterceptor; then
        echo "ОТКАЗ  оболочка перехватила запуск (RequiresControllersLaunchInterceptor): включите контроллеры" >&2
        exit 1
    fi
    started="$(adb logcat -d -s godot:V | grep -E "зона при запуске|старт через|SCRIPT ERROR|Parse Error" || true)"
    if [ -z "$started" ]; then
        echo "ВНИМАНИЕ  строк старта в logcat нет — посмотреть logcat целиком" >&2
    else
        echo "$started"
    fi
    ;;
pull)
    device || exit 1
    [ -f "$MARK" ] || { echo "ОТКАЗ  отметки нет — сначала tools/vr_session.sh mark|start" >&2; exit 1; }
    from=$(( $(cut -f1 "$MARK") + 1 ))
    out="$DIR/$(date +%Y-%m-%d_%H-%M-%S)"
    mkdir -p "$out"
    adb shell run-as "$PKG" cat files/sphere_session.tsv > "$out/journal_all.tsv"
    adb logcat -d -s godot:V > "$out/logcat.txt"
    # Перехват оболочкой пишется не тегом godot — отдельно (ловушка 13).
    adb logcat -d | grep RequiresControllersLaunchInterceptor >> "$out/logcat.txt" || true
    # Выгрузка при «Выходе» (session/export.gd): последняя папка, если она новее отметки.
    last="$(adb shell ls /sdcard/Download/VRGE 2>/dev/null | tr -d '\r' | grep -E '^[0-9]{4}-' | sort | tail -1 || true)"
    if [ -n "$last" ] && [[ "$last" > "$(cut -f2 "$MARK" | tr 'T:' '_-')" ]]; then
        adb pull "/sdcard/Download/VRGE/$last" "$out/export" >/dev/null && echo "выгрузка: $last"
    fi
    # Трассы движений (session/trace.gd), записанные после отметки: имя начинается временем записи.
    since="$(cut -f2 "$MARK" | tr ':' '-')"
    n_tr=0
    for f in $(adb shell run-as "$PKG" ls files/traces 2>/dev/null | tr -d '\r' || true); do
        [[ "$f" > "$since" ]] || continue
        mkdir -p "$out/traces"
        adb shell run-as "$PKG" cat "files/traces/$f" > "$out/traces/$f"
        n_tr=$((n_tr + 1))
    done
    echo "трасс: $n_tr"
    if [ "$n_tr" -gt 0 ]; then
        echo "  воспроизвести: godot/bin/godot.linuxbsd.editor.x86_64 --headless --path projects/sphere_menu \\"
        echo "      --script res://tests/replay.gd -- --trace=$out/traces/<файл>"
    fi
    # Скриншоты (оба стика или метка): session/screenshot.gd кладёт их в общую папку шлема.
    shot_since="screenshot_$(cut -f2 "$MARK" | tr 'T:' '_-')"
    n_sh=0
    for f in $(adb shell ls /sdcard/Download/VRGE/screenshots 2>/dev/null | tr -d '\r' || true); do
        [[ "$f" > "$shot_since" ]] || continue
        mkdir -p "$out/screenshots"
        adb pull "/sdcard/Download/VRGE/screenshots/$f" "$out/screenshots/" >/dev/null
        n_sh=$((n_sh + 1))
    done
    echo "скриншотов: $n_sh"
    python3 "$ROOT/tools/session_report.py" "$out/journal_all.tsv" --from-line "$from" \
        --logcat "$out/logcat.txt" --out "$out/report.md"
    echo "строк журнала с отметки: $(tail -n +"$from" "$out/journal_all.tsv" | wc -l)"
    ;;
*)
    sed -n '2,12p' "$0"
    exit 2
    ;;
esac
