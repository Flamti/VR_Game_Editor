#!/usr/bin/env bash
# Проверка артефакта СОДЕРЖАНИЕМ, а не кодом возврата и не датой (PRACTICES §4.5).
#
# История этого файла — предостережение. Первая версия давала два ЛОЖНЫХ отказа:
#  1. искала символы через nm, но Godot линкует стрипнутый бинарь — nm слеп,
#     и «символов нет» было неотличимо от «посмотреть нечем» (PRACTICES §2.3:
#     слепой прибор опаснее сломанного кода);
#  2. `find -name '*.cpp' -o -name '*.h' -newer X` из-за приоритета операторов
#     применяла -newer ТОЛЬКО к *.h, и все .cpp считались новее всегда.
# Оба отказа стоили бы часов поиска несуществующей проблемы.

. "$(dirname "${BASH_SOURCE[0]}")/env.sh"

passed=0
failed=0
unknown=0
EXPECTED_CHECKS=4     # пол по числу ИСПОЛНЕННЫХ проверок (PRACTICES §1.2)

pass() { echo "  PASS  $1"; passed=$((passed+1)); }
fail() { echo "  FAIL  $1"; failed=$((failed+1)); }
unkn() { echo "  ????  $1"; unknown=$((unknown+1)); }

# Артефактом может быть и Android-библиотека, и Linux-исполняемый файл.
ARTIFACT="${1:-}"
if [ -z "$ARTIFACT" ]; then
    # Android: scons линкует .so в bin/, но затем ПЕРЕМЕЩАЕТ его в дерево gradle
    # (см. Move(...) в конце лога сборки). Искать только в bin/ — значит получить
    # «артефакт не найден» на совершенно исправной сборке.
    ANDROID_LIBS="$VRGE_GODOT/platform/android/java/lib/libs"
    # Самый СВЕЖИЙ, а не первый найденный: рядом лежат debug/ и release/, и
    # `-print -quit` отдавал старый release после сборки template_debug —
    # проверка краснела «свежестью» на исправной сборке (2026-09-13).
    ARTIFACT="$(find "$ANDROID_LIBS" -name 'libgodot_android.so' -type f -printf '%T@ %p\n' 2>/dev/null \
                | sort -nr | head -n 1 | cut -d' ' -f2- || true)"
    if [ -z "$ARTIFACT" ]; then
        ARTIFACT="$(find "$VRGE_BIN" \( -name 'libgodot.android.*.so' -o -name 'godot.linuxbsd.*' \) \
                    -type f -print -quit 2>/dev/null || true)"
    fi
fi

echo "проверка артефакта: ${ARTIFACT:-<не найден>}"

# --- 1. Артефакт существует ---
if [ -n "$ARTIFACT" ] && [ -f "$ARTIFACT" ]; then
    pass "артефакт: найден, $(du -h "$ARTIFACT" | cut -f1)"
else
    fail "артефакт: в $VRGE_BIN нет ни libgodot.android.*.so, ни godot.linuxbsd.*"
fi

# --- 2. Наш код ВНУТРИ артефакта ---
# Godot стрипует бинарь, поэтому nm тут не инструмент. Но имя класса,
# зарегистрированное через GDCLASS, и искажённое имя типа переживают стрип —
# это прямая улика присутствия кода, а не совпадение пути в отладочной строке.
if [ -n "$ARTIFACT" ] && [ -f "$ARTIFACT" ]; then
    if ! command -v strings >/dev/null; then
        unkn "код: strings недоступен — посмотреть нечем (это НЕ «кода нет»)"
    else
        # Ищем искажённое имя типа: '<длина>VRGEProbeXRExtension'. Путь к .cpp
        # в строках артефакта уликой НЕ считаем — он попадает туда и от мусора.
        # НЕ использовать `grep -q` в конвейере: он выходит по первому
        # совпадению, strings получает SIGPIPE, и при set -o pipefail
        # УСПЕШНОЕ совпадение делает конвейер неуспешным (код 141).
        # Прибор из-за этого давал ложный отказ на заведомо верной сборке.
        mangled="$(strings "$ARTIFACT" | grep -cE '[0-9]+VRGEProbe' || true)"
        plain="$(strings "$ARTIFACT" | grep -c 'VRGEProbe' || true)"
        if [ "${mangled:-0}" -gt 0 ]; then
            pass "код: искажённое имя типа VRGEProbe* найдено ($mangled шт.) — модуль слинкован"
        elif [ "${plain:-0}" -gt 0 ]; then
            pass "код: имя класса VRGEProbe найдено ($plain шт.; искажённого имени нет — слабее)"
        else
            fail "код: ни одного следа VRGEProbe в $ARTIFACT — модуль НЕ попал в сборку"
        fi
    fi
else
    unkn "код: проверка не исполнялась, артефакта нет"
fi

# --- 3. Артефакт не старше наших исходников ---
# Скобки обязательны: без них -newer относится только к последнему -name.
if [ -n "$ARTIFACT" ] && [ -f "$ARTIFACT" ] && [ -d "$VRGE_MODULES" ]; then
    newer="$(find "$VRGE_MODULES" \( -name '*.cpp' -o -name '*.h' \) -newer "$ARTIFACT" 2>/dev/null | head -5)"
    if [ -z "$newer" ]; then
        pass "свежесть: ни один исходник в modules/ не новее артефакта"
    else
        fail "свежесть: исходники новее артефакта — правка не собрана:"
        echo "$newer" | sed 's/^/          /'
    fi
else
    unkn "свежесть: проверка не исполнялась"
fi

# --- 4. Swappy слинкован (только для Android; ADR-0004) ---
# Проверяем СОДЕРЖИМОЕ артефакта, а не отсутствие предупреждения в логе:
# предупреждение исчезает от одного лишь наличия файлов, а нам нужен факт линковки.
case "$ARTIFACT" in
    *libgodot_android.so|*libgodot.android.*)
        swappy_refs="$(strings "$ARTIFACT" | grep -ci 'swappy' || true)"
        if [ "${swappy_refs:-0}" -gt 0 ]; then
            # НЕ писать «кадровый пейсинг на месте»: под OpenXR движок Swappy
            # принудительно отключает (ADR-0004), и такое сообщение врало бы
            # ровно про VR-путь — основной для проекта.
            pass "swappy: слинкован ($swappy_refs упоминаний). Под OpenXR будет отключён движком — значим только для не-XR сборок (ADR-0004)"
        else
            fail "swappy: НЕ слинкован — сборка гарантированно будет дёргаться (ADR-0004)"
        fi
        ;;
    *)
        unkn "swappy: не Android-артефакт, проверка неприменима"
        ;;
esac

total=$((passed + failed + unknown))
echo ""
echo "passed=$passed failed=$failed unknown=$unknown"
if [ "$total" -ne "$EXPECTED_CHECKS" ]; then
    echo "ОТКАЗ ПРИБОРА: исполнено $total проверок из $EXPECTED_CHECKS — ошибка оборвала функцию" >&2
    exit 2
fi
[ "$failed" -eq 0 ]
