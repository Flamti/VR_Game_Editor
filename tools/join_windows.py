#!/usr/bin/env python3
"""Свод окон прибора с хостовыми сэмплерами по unix-времени.

Окно прибора — строка TSV с колонками unix_начало и unix_конец (фаза K,
user://curve.tsv). К каждому окну добавляется то, что хост снял за это время:

  --clock   tools/gpu_sampler.sh   медиана клока GPU, МГц; загрузка, %
  --mem     tools/gpu_mem.sh       vk_devicememory и texture, МБ (среднее)
  --stages  tools/gpu_stages.sh    режимы рендера и размеры бинов поверхностей
  --vrapi   tools/vrapi_log.sh     кадры приложения/дисплея, Stale, ASW, Preempt, температура

Почему по окну, а не по концам лестницы: прогон 11 сравнивал наклоны по
концам при разном клоке, и вывод ничего не решал (ADR-0003, «Открыто»).

Контроль (PRACTICES §2.3): окно без единой выборки сэмплера печатается как
«—» и считается; если пустых окон больше половины, скрипт завершается с
кодом 2 — часы хоста и шлема разошлись или сэмплер писал другой прогон.

Использование:
  tools/join_windows.py curve.tsv --clock clock.tsv [--mem mem.tsv] [--stages stages.txt]
"""

import argparse
import re
import statistics
import sys


def read_windows(path):
    rows = []
    with open(path, encoding="utf-8") as f:
        header = None
        for line in f:
            line = line.rstrip("\n")
            if line.startswith("#"):
                header = line.lstrip("# ").split("\t")
                continue
            if not line:
                continue
            parts = line.split("\t")
            try:
                t0, t1 = float(parts[0]), float(parts[1])
            except (ValueError, IndexError):
                continue
            rows.append((t0, t1, parts))
    return header, rows


def read_clock(path):
    out = []
    with open(path, encoding="utf-8") as f:
        for line in f:
            if line.startswith("#"):
                continue
            p = line.rstrip("\n").split("\t")
            if len(p) < 2 or not p[1].strip().isdigit():
                continue
            busy = float(p[2]) if len(p) > 2 and p[2].strip().replace(".", "", 1).isdigit() else float("nan")
            out.append((float(p[0]), int(p[1]), busy))
    return out


def read_mem(path):
    out = []
    with open(path, encoding="utf-8") as f:
        for line in f:
            if line.startswith("#"):
                continue
            p = line.rstrip("\n").split("\t")
            if len(p) < 3 or not p[2].isdigit():
                continue
            out.append((float(p[0]), p[1], int(p[2])))
    return out


def read_vrapi(path):
    out = []
    with open(path, encoding="utf-8") as f:
        for line in f:
            if line.startswith("#"):
                continue
            p = line.rstrip("\n").split("\t")
            if len(p) < 11 or not p[1].isdigit():
                continue
            num = lambda x: float(x) if x else float("nan")
            out.append((float(p[0]), int(p[1]), int(p[2]), int(p[3] or 0), p[4], num(p[8]), num(p[9])))
    return out


MODE_RE = re.compile(r"\b(Direct|HwBinning|SwBinning|HwDirect)\b")
BINS_RE = re.compile(r"(\d+)\s+(\d+)x(\d+)\s+bins")


def read_stages(path):
    """Блоки «### unix» с сырым текстом трассы. Формат трассы на прошивке не
    зафиксирован, поэтому берутся только устойчивые признаки из документации
    Meta: «N WxH bins» и имя режима."""
    out = []
    t = None
    buf = []
    with open(path, encoding="utf-8", errors="replace") as f:
        for line in f:
            if line.startswith("### "):
                if t is not None:
                    out.append((t, "".join(buf)))
                try:
                    t = float(line[4:].strip())
                except ValueError:
                    # Битый заголовок (обрыв записи) — блок пропускается и
                    # считается, а не роняет весь свод.
                    print("# трасса с битым заголовком пропущена: %r" % line.strip(), file=sys.stderr)
                    t = None
                buf = []
            elif t is not None:
                buf.append(line)
    if t is not None:
        out.append((t, "".join(buf)))
    return out


def within(samples, t0, t1):
    return [s for s in samples if t0 <= s[0] <= t1]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("windows")
    ap.add_argument("--clock")
    ap.add_argument("--mem")
    ap.add_argument("--stages")
    ap.add_argument("--vrapi")
    a = ap.parse_args()

    header, rows = read_windows(a.windows)
    clock = read_clock(a.clock) if a.clock else None
    mem = read_mem(a.mem) if a.mem else None
    stages = read_stages(a.stages) if a.stages else None
    vrapi = read_vrapi(a.vrapi) if a.vrapi else None

    cols = list(header or [])
    if clock is not None:
        cols += ["клок_мед_МГц", "клок_мин_МГц", "клок_n", "загрузка_%"]
    if mem is not None:
        cols += ["vk_devicememory_МБ", "texture_МБ", "mem_n"]
    if stages is not None:
        cols += ["режимы", "бины", "трасс"]
    if vrapi is not None:
        cols += ["FPS_прил", "FPS_дисплей", "Stale_сумма", "ASW", "Preempt_мед", "Temp_C", "vrapi_n"]
    print("\t".join(cols))

    empty = 0
    checked = 0
    for t0, t1, parts in rows:
        out = list(parts)
        miss = False
        if clock is not None:
            w = within(clock, t0, t1)
            checked += 1
            if w:
                hz = [s[1] for s in w]
                busy = [s[2] for s in w if s[2] == s[2]]
                out += ["%.0f" % (statistics.median(hz) / 1e6), "%.0f" % (min(hz) / 1e6), str(len(w)),
                        "%.0f" % statistics.mean(busy) if busy else "—"]
            else:
                out += ["—"] * 4
                miss = True
        if mem is not None:
            w = within(mem, t0, t1)
            vk = [s[2] for s in w if s[1] == "vk_devicememory"]
            tex = [s[2] for s in w if s[1] == "texture"]
            out += ["%.1f" % (statistics.mean(vk) / 1024) if vk else "—",
                    "%.1f" % (statistics.mean(tex) / 1024) if tex else "—", str(len(vk))]
            if not vk:
                miss = True
        if stages is not None:
            # Трасса начинается в t и длится окно сэмплера; берём начатые внутри окна.
            w = within(stages, t0, t1)
            modes = sorted({m for _, txt in w for m in MODE_RE.findall(txt)})
            bins = sorted({"%sx%sx%s" % b for _, txt in w for b in BINS_RE.findall(txt)})
            out += [",".join(modes) or "—", ",".join(bins) or "—", str(len(w))]
            if not w:
                miss = True
        if vrapi is not None:
            # Строка VrApi описывает прошедшую секунду: берём строки внутри окна.
            w = within(vrapi, t0, t1)
            if w:
                out += ["%.0f" % statistics.median([x[1] for x in w]), "%.0f" % statistics.median([x[2] for x in w]),
                        str(sum(x[3] for x in w)), ",".join(sorted({x[4] for x in w if x[4]})) or "—",
                        "%.0f" % statistics.median([x[5] for x in w]), "%.1f" % max(x[6] for x in w), str(len(w))]
            else:
                out += ["—"] * 7
                miss = True
        empty += 1 if miss else 0
        print("\t".join(out))

    total = len(rows)
    print("# окон %d, без выборок хотя бы одного сэмплера %d" % (total, empty), file=sys.stderr)
    if total == 0:
        print("# ОТКАЗ: в файле окон нет ни одной строки с unix_начало/unix_конец", file=sys.stderr)
        return 2
    if empty * 2 > total:
        print("# ОТКАЗ: больше половины окон пусты — часы разошлись или сэмплер писал другой прогон", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
