#!/usr/bin/env python3
"""Прибор разбора журнала сессии (tools/session_report.py).

Ожидания сняты НЕЗАВИСИМО от разбора — грепом по фикстурам (2026-09-27), а не прогоном самого
разбора: иначе прибор подтверждал бы свой же вывод.

Фикстуры:
  testdata/journal_2026-09-26.tsv       — две сессии подряд (17:50 и 21:35), 15 колонок;
  testdata/journal_2026-09-19_13col.tsv — сессия старого формата, 13 колонок (колонки ввода и
                                          профиля появились 2026-09-19).

Запуск:
  tools/test_session_report.py [--falsify=nosplit|bycolumn|nomark]

Фальсификаторы:
  nosplit   сессии не делятся — всё уходит в первую; краснеют счёты по сессиям;
  bycolumn  подробности берутся 15-й колонкой, а не по имени из заголовка — краснеет только
            «старый формат читается по заголовку»;
  nomark    отметка «с какой строки» не соблюдается — краснеет только «разбор с отметки».

Контрольный случай — «фикстура читается»: число строк данных, посчитанное без разбора. Упал —
сломана фикстура, а не разбор (PRACTICES §1.5).
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import session_report as sr  # noqa: E402

CHECKS = ["фикстура читается", "сессии делятся по заголовку", "сессия 17:50 посчитана",
          "сессия 21:35 посчитана", "старый формат читается по заголовку", "разбор с отметки",
          "отчёт называет главное"]

# Сессия → (строк данных, счёты). Грепом, 2026-09-27.
WANT = {
    "2026-09-26T17:50:03": (523, {"climbs": 1, "mantles": 1, "mantle_refused": 0, "jumps": 10,
                                  "loads": 3, "unloads": 3, "item_moves": 3, "teleports": 20,
                                  "respawns": 1, "recenters": 1, "exits": 1}),
    "2026-09-26T21:35:30": (401, {"climbs": 3, "mantles": 0, "mantle_refused": 0, "jumps": 10,
                                  "loads": 3, "unloads": 3, "item_moves": 1, "teleports": 0,
                                  "respawns": 0, "recenters": 3, "exits": 1}),
}

passed = failed = 0


def check(name, ok, detail):
    global passed, failed
    if ok:
        passed += 1
        print("  PASS  %s: %s" % (name, detail))
    else:
        failed += 1
        print("  FAIL  %s: %s" % (name, detail))


def main():
    for a in sys.argv[1:]:
        if a.startswith("--falsify="):
            sr.FALSIFY = a.split("=", 1)[1]
            print("!!! ФАЛЬСИФИКАТОР «%s»: ожидается точечный отказ !!!" % sr.FALSIFY)
    print("ожидается исполненных проверок: %d" % len(CHECKS))
    big = open(os.path.join(HERE, "testdata/journal_2026-09-26.tsv"), encoding="utf-8").read()
    old = open(os.path.join(HERE, "testdata/journal_2026-09-19_13col.tsv"), encoding="utf-8").read()

    raw_rows = sum(1 for ln in big.splitlines() if ln[:1].isdigit())
    check("фикстура читается", raw_rows == 924, "строк данных %d (ждали 924)" % raw_rows)

    sessions = sr.parse(big)
    names = [s["name"] for s in sessions]
    check("сессии делятся по заголовку", names == list(WANT), "сессии %s" % names)

    for name, label in [("2026-09-26T17:50:03", "сессия 17:50 посчитана"),
                        ("2026-09-26T21:35:30", "сессия 21:35 посчитана")]:
        s = next((x for x in sessions if x["name"] == name), None)
        if s is None:
            check(label, False, "сессии нет")
            continue
        rows, want = WANT[name]
        got = sr.summarize(s)
        bad = ["%s %s вместо %s" % (k, got.get(k), v) for k, v in want.items() if got.get(k) != v]
        if len(s["rows"]) != rows:
            bad.insert(0, "строк %d вместо %d" % (len(s["rows"]), rows))
        check(label, not bad, "; ".join(bad) if bad else "строк %d, %s" % (rows, want))

    olds = sr.parse(old)
    drag = [r for s in olds for r in s["rows"] if r.get("событие") == "рука_drag"]
    ok = len(drag) == 1 and "travel_cm" in drag[0].get("подробности", "")
    check("старый формат читается по заголовку", ok,
          "подробности рука_drag: «%s»" % (drag[0].get("подробности", "") if drag else "строки нет"))

    # Отметка: журнал на шлеме дописывается, и «эта сессия» — всё после запомненной длины. 525 —
    # последняя строка сессии 17:50, дальше — заголовок и сессия 21:35.
    tail = sr.parse(big, from_line=526)
    tnames = [s["name"] for s in tail]
    check("разбор с отметки", tnames == ["2026-09-26T21:35:30"] and len(tail[0]["rows"]) == 401,
          "сессии %s, строк %s" % (tnames, [len(s["rows"]) for s in tail]))

    rep = sr.render(tail, logcat="")
    need = ["2026-09-26T21:35:30", "ПОЗА[рывок 10]", "лазанье: отпустил right: 2.46 м",
            "выгружено по триггеру"]
    miss = [n for n in need if n not in rep]
    check("отчёт называет главное", not miss, "нет в отчёте: %s" % miss if miss else "всё на месте")

    total = passed + failed
    print("passed=%d failed=%d" % (passed, failed))
    if total != len(CHECKS):
        print("ОТКАЗ ПРИБОРА: исполнено %d проверок из %d" % (total, len(CHECKS)))
        return 1
    print("пол: исполнено %d/%d проверок" % (total, len(CHECKS)))
    return 0 if failed == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
