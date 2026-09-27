#!/usr/bin/env python3
"""Отчёт по журналу сессии шар-меню (files/sphere_session.tsv со шлема).

Журнал на шлеме — все сессии подряд, и формат строк менялся: колонки ввода и профиля появились
2026-09-19, поэтому у старых сессий 11 и 13 колонок, у новых 15. Имена колонок берутся из
заголовка «# unix_время…» перед каждой сессией, а не по номеру.

Отчёт — то, что до сих пор собиралось руками awk'ом после каждого прогона: счёты по механикам,
лента значимых событий (перевал, рывки, лазанье, телепорты, подгрузка, пространство) и ошибки из
logcat. Разбор — чистые функции на тексте: их проверяет tools/test_session_report.py на готовых
журналах.

Использование:
  tools/session_report.py журнал.tsv [--from-line N] [--logcat файл] [--out report.md]

  --from-line N  разбирать с N-й строки (1 — первая): «эта сессия» — всё после длины журнала,
                 запомненной перед запуском (tools/vr_session.sh start).
"""
import re
import sys
import time

# Фальсификатор прибора (tools/test_session_report.py): nosplit | bycolumn | nomark.
FALSIFY = ""

DETAILS = "подробности"

# Счёты: имя → (событие или None, образец в подробностях). Образцы — те же строки, что пишет
# приложение (locomotion.gd, main.gd); сменилась строка там — сменить здесь.
COUNTS = {
    "climbs": (None, re.compile(r"^лазанье: (отпустил|сорвался) \w+: ")),
    "mantles": (None, re.compile(r"^перевал: на площадку")),
    "mantle_refused": (None, re.compile(r"^перевал: не начат")),
    "jumps": (None, re.compile(r"ПОЗА\[рывок")),
    "loads": (None, re.compile(r"подгружено по триггеру")),
    "unloads": (None, re.compile(r"выгружено по триггеру")),
    "item_moves": (None, re.compile(r" перешёл: ")),
    "teleports": (None, re.compile(r"^телепорт: ")),
    "respawns": (None, re.compile(r"^возврат в стартовую точку")),
    "recenters": (None, re.compile(r"pose_recentered")),
    "exits": ("выход", None),
    "marks": ("метка", None),
}

COUNT_NAMES = {
    "climbs": "подъёмов (последняя рука отпустила)", "mantles": "перевалов",
    "mantle_refused": "отказов перевала у кромки", "jumps": "рывков сторожа",
    "loads": "подгрузок комнат", "unloads": "выгрузок комнат", "item_moves": "переходов предметов",
    "teleports": "телепортов", "respawns": "возвратов в старт", "recenters": "перецентровок",
    "exits": "выходов с выгрузкой", "marks": "меток владельца",
}

# Лента: что из подробностей стоит показать. Остальное (ходьба, повороты, меню) — только счётом.
NOTABLE = re.compile(r"^(перевал|лазанье: (отпустил|сорвался) \w+:|телепорт|возврат|ПОЗА|перемещение прервано)"
                     r"|ПОЗА\[| перешёл: |рука \w+ занята|не пойман|по триггеру|pose_recentered"
                     r"|перецентровка|зона|старт через|самопроверка")
NOTABLE_EVENTS = {"уровень", "пространство", "выход", "самопроверка", "метка", "скриншот"}


def parse(text, from_line=1):
    """Сессии журнала: [{name, header: [колонки], rows: [{колонка: значение}], skipped}].

    `skipped` — строки данных без заголовка перед ними: их некуда разложить, и молча терять их
    нельзя — отчёт называет их число."""
    sessions = []
    header = []
    current = None
    skipped = 0
    for i, line in enumerate(text.splitlines(), start=1):
        if i < from_line and FALSIFY != "nomark":
            continue
        if line.startswith("# unix"):
            header = line[2:].split("\t")
            continue
        if line.startswith("# сессия"):
            if current is not None and FALSIFY == "nosplit":
                continue
            current = {"name": line[len("# сессия"):].strip(), "header": header, "rows": [],
                       "skipped": 0}
            sessions.append(current)
            continue
        if not line or line.startswith("#"):
            continue
        cols = line.split("\t")
        if current is None or not header:
            skipped += 1
            continue
        if FALSIFY == "bycolumn":
            row = dict(zip(header, cols))
            row[DETAILS] = cols[14] if len(cols) > 14 else ""
        else:
            # Подробности — последняя колонка и могут содержать что угодно: всё, что правее
            # предпоследнего имени, склеивается обратно.
            n = len(header)
            if len(cols) > n:
                cols = cols[:n - 1] + ["\t".join(cols[n - 1:])]
            row = dict(zip(header, cols))
        current["rows"].append(row)
    if sessions:
        sessions[0]["skipped"] += skipped
    return sessions


def summarize(session):
    """Счёты по механикам и по событиям."""
    out = {k: 0 for k in COUNTS}
    events = {}
    for r in session["rows"]:
        ev = r.get("событие", "")
        det = r.get(DETAILS, "")
        events[ev] = events.get(ev, 0) + 1
        for k, (want_ev, rx) in COUNTS.items():
            if want_ev is not None and ev != want_ev:
                continue
            if rx is not None and not rx.search(det):
                continue
            out[k] += 1
    out["events"] = events
    return out


def _clock(unix):
    try:
        return time.strftime("%H:%M:%S", time.localtime(float(unix)))
    except ValueError:
        return "?"


def render(sessions, logcat=""):
    """Отчёт в markdown."""
    out = ["# Отчёт по журналу сессии", ""]
    if not sessions:
        out.append("**В журнале с отметки нет ни одной сессии** — приложение не стартовало или журнал"
                   " не тот (ловушка 13: перехват оболочкой при неактивных контроллерах).")
    for s in sessions:
        sm = summarize(s)
        rows = s["rows"]
        span = ""
        if rows:
            span = " — %s…%s" % (_clock(rows[0].get("unix_время", "")), _clock(rows[-1].get("unix_время", "")))
        out += ["## Сессия %s%s" % (s["name"], span), "",
                "Строк %d, колонок в заголовке %d%s." % (len(rows), len(s["header"]),
                ", **без заголовка отброшено %d**" % s["skipped"] if s["skipped"] else ""), "",
                "| механика | число |", "|---|---|"]
        for k in COUNTS:
            out.append("| %s | %d |" % (COUNT_NAMES[k], sm[k]))
        out += ["", "События: " + ", ".join("%s %d" % (k, v) for k, v in
                                             sorted(sm["events"].items(), key=lambda kv: -kv[1])), "",
                "### Лента", "", "```"]
        for r in rows:
            ev = r.get("событие", "")
            det = r.get(DETAILS, "")
            if ev in NOTABLE_EVENTS or NOTABLE.search(det):
                out.append("%s  %-12s %s" % (_clock(r.get("unix_время", "")), ev, det[:220]))
        out += ["```", ""]
    errs = [ln for ln in logcat.splitlines()
            if re.search(r"SCRIPT ERROR|Parse Error|ERROR:|FATAL|RequiresControllersLaunchInterceptor", ln)]
    out += ["## logcat", "", "Строк %d, ошибок и перехватов %d." % (len(logcat.splitlines()), len(errs))]
    if errs:
        out += ["", "```"] + errs[:60] + ["```"]
    out.append("")
    return "\n".join(out)


def main(argv):
    if len(argv) < 2:
        print(__doc__)
        return 2
    path = argv[1]
    from_line = 1
    logcat = ""
    dst = None
    i = 2
    while i < len(argv):
        if argv[i] == "--from-line":
            from_line = int(argv[i + 1])
            i += 2
        elif argv[i] == "--logcat":
            logcat = open(argv[i + 1], encoding="utf-8", errors="replace").read()
            i += 2
        elif argv[i] == "--out":
            dst = argv[i + 1]
            i += 2
        else:
            print("незнакомый аргумент: %s" % argv[i])
            return 2
    text = open(path, encoding="utf-8", errors="replace").read()
    rep = render(parse(text, from_line), logcat)
    if dst:
        open(dst, "w", encoding="utf-8").write(rep)
        print("отчёт: %s" % dst)
    else:
        print(rep)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
