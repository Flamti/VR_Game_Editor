#!/usr/bin/env python3
"""Запекание сеток ячеек шар-меню (Ф2, шаги 1в–1г).

Раскладки (решения владельца 2026-09-15):
  icosa — многогранники Гольдберга GP(a,b) на икосаэдре, все T = a²+ab+b² ≤ 64,
          ячеек 10T+2, 12 пятиугольников;
  octa  — то же на октаэдре, ячеек 4T+2, 6 квадратов вместо пятиугольников;
  rings — центры по широтам кирпичной кладкой (кольца со сдвигом на полъячейки);
  fib   — N центров по золотой спирали, любое N, дефекты рассеяны.
«Глобус со скрытыми дефектами» — сетки icosa, пропуск пятиугольников делает рантайм.

Общий путь для всех: центры → выпуклая оболочка (на сфере это триангуляция Делоне) →
двойственная сетка Вороного (вершины контура — центры описанных окружностей
треугольников, соседи — ячейки с общим ребром контура ненулевой длины) → выравнивание
пружинами → JSON. Своя оболочка: scipy на машине нет, а 650 точек инкрементальный
алгоритм считает за доли секунды.

Почему центры описанных окружностей, а не центроиды треугольников (как в шаге 1в):
у колец и у точек на одной окружности несколько треугольников делят одну вершину
Вороного, центроиды её разносят — у ячейки появляются рёбра нулевой длины и ложные
соседи по диагонали. Центр описанной окружности у таких треугольников один.

Почему пружины (расстояния до соседей), а не площади — замер шага 1в: площади сходятся,
но ячейки вытягиваются до 2.08; см. docs/practices.md §3.9.

Контроль оболочки: для GP(m,0) топология через оболочку обязана совпасть с решёточной
триангуляцией (прежний способ). Печатается при каждом запуске, расхождение — отказ.

Использование:
  tools/bake_grids.py [каталог_вывода]
"""

import json
import math
import os
import sys

OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(
    os.path.dirname(__file__), "..", "projects", "sphere_menu", "menu", "geo")

T_MAX = 64
# Соседние уровни ряда ближе этого по поперечнику ячейки — дубль, пропускается
# (сессия 2: 32 и 42 ячейки дали 8.7 и 8.3 см, ползунок перескакивал между ними).
MIN_STEP = 1.05


def norm(v):
    l = math.sqrt(v[0] * v[0] + v[1] * v[1] + v[2] * v[2])
    return [v[0] / l, v[1] / l, v[2] / l]


def add(a, b, s=1.0):
    return [a[0] + b[0] * s, a[1] + b[1] * s, a[2] + b[2] * s]


def dot(a, b):
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


def cross(a, b):
    return [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]]


def arc(p, q):
    return math.acos(max(-1.0, min(1.0, dot(p, q))))


T = (1 + 5 ** 0.5) / 2
ICO = [norm(v) for v in [(-1, T, 0), (1, T, 0), (-1, -T, 0), (1, -T, 0), (0, -1, T), (0, 1, T), (0, -1, -T),
                          (0, 1, -T), (T, 0, -1), (T, 0, 1), (-T, 0, -1), (-T, 0, 1)]]
ICO_FACES = [(0, 11, 5), (0, 5, 1), (0, 1, 7), (0, 7, 10), (0, 10, 11), (1, 5, 9), (5, 11, 4), (11, 10, 2),
             (10, 7, 6), (7, 1, 8), (3, 9, 4), (3, 4, 2), (3, 2, 6), (3, 6, 8), (3, 8, 9), (4, 9, 5),
             (2, 4, 11), (6, 2, 10), (8, 6, 7), (9, 8, 1)]
OCT = [[1, 0, 0], [-1, 0, 0], [0, 1, 0], [0, -1, 0], [0, 0, 1], [0, 0, -1]]
OCT_FACES = [(0, 2, 4), (2, 1, 4), (1, 3, 4), (3, 0, 4), (2, 0, 5), (1, 2, 5), (3, 1, 5), (0, 3, 5)]


# --- генераторы центров -------------------------------------------------------------

def lattice_points(verts, faces, a, b):
    """Точки треугольной решётки (a,b) на гранях многогранника, на сфере, без дублей.
    Большой треугольник решётки: P0 = 0, P1 = a·e1 + b·e2, P2 = P1 повёрнут на 60°;
    точка решётки внутри него переносится на грань барицентрическими координатами."""
    e1 = (1.0, 0.0)
    e2 = (0.5, math.sqrt(3) / 2)
    p1 = (a * e1[0] + b * e2[0], a * e1[1] + b * e2[1])
    c, s = math.cos(math.pi / 3), math.sin(math.pi / 3)
    p2 = (p1[0] * c - p1[1] * s, p1[0] * s + p1[1] * c)
    det = p1[0] * p2[1] - p1[1] * p2[0]
    idx, pts = {}, []
    r = a + b + 1
    for f in faces:
        A, B, C = [verts[x] for x in f]
        for i in range(-r, 2 * r):
            for j in range(-r, 2 * r):
                q = (i * e1[0] + j * e2[0], i * e1[1] + j * e2[1])
                w1 = (q[0] * p2[1] - q[1] * p2[0]) / det
                w2 = (p1[0] * q[1] - p1[1] * q[0]) / det
                w0 = 1.0 - w1 - w2
                if min(w0, w1, w2) < -1e-9:
                    continue
                p = norm([A[k] * w0 + B[k] * w1 + C[k] * w2 for k in range(3)])
                key = tuple(round(x, 6) for x in p)
                if key not in idx:
                    idx[key] = len(pts)
                    pts.append(p)
    return pts


def fibonacci_points(n):
    ga = math.pi * (3 - math.sqrt(5))
    pts = []
    for i in range(n):
        z = 1 - (2 * i + 1) / n
        rr = math.sqrt(max(0.0, 1 - z * z))
        pts.append([rr * math.cos(ga * i), z, rr * math.sin(ga * i)])
    return pts


def ring_points(step):
    """Кольца по широтам: step — угловой шаг, соседние кольца со сдвигом на полъячейки.
    Микросдвиг по долготе от номера кольца: точки одной широты лежат в одной плоскости, и
    четвёрки соседей двух колец — вписанные трапеции; без сдвига оболочка выбирала бы
    диагональ произвольно."""
    n_r = max(2, round(math.pi / step))
    pts = []
    for k in range(n_r):
        lat = -math.pi / 2 + (k + 0.5) * math.pi / n_r
        cnt = max(3, round(2 * math.pi * math.cos(lat) / step))
        off = (0.5 if k % 2 else 0.0) + 1e-4 * k
        for i in range(cnt):
            lon = 2 * math.pi * (i + off) / cnt
            pts.append([math.cos(lat) * math.cos(lon), math.sin(lat), math.cos(lat) * math.sin(lon)])
    return pts


# --- оболочка и двойственная сетка ----------------------------------------------------

def hull(pts):
    """Инкрементальная выпуклая оболочка точек на сфере. Грани — (i,j,k) против часовой
    стрелки снаружи. Все точки единичные, значит все — вершины оболочки."""
    n = len(pts)
    # начальный тетраэдр: 0, самая далёкая от 0, самая далёкая от прямой, от плоскости
    i0 = 0
    i1 = max(range(n), key=lambda i: arc(pts[i], pts[i0]))
    d01 = add(pts[i1], pts[i0], -1)
    i2 = max(range(n), key=lambda i: sum(x * x for x in cross(d01, add(pts[i], pts[i0], -1))))
    nrm = cross(d01, add(pts[i2], pts[i0], -1))
    i3 = max(range(n), key=lambda i: abs(dot(nrm, add(pts[i], pts[i0], -1))))
    faces = []
    # внутренняя точка тетраэдра, а не центр сферы: центр может лежать вне тетраэдра
    inner = [sum(pts[i][k] for i in (i0, i1, i2, i3)) / 4 for k in range(3)]

    def make(a, b, c):
        nn = cross(add(pts[b], pts[a], -1), add(pts[c], pts[a], -1))
        if dot(nn, add(pts[a], inner, -1)) < 0:
            b, c = c, b
        return (a, b, c)

    for f in [(i0, i1, i2), (i0, i1, i3), (i0, i2, i3), (i1, i2, i3)]:
        faces.append(make(*f))
    done = {i0, i1, i2, i3}
    for p in range(n):
        if p in done:
            continue
        dist = []
        for (a, b, c) in faces:
            nn = cross(add(pts[b], pts[a], -1), add(pts[c], pts[a], -1))
            dist.append(dot(nn, add(pts[p], pts[a], -1)))
        vis = [fi for fi, d in enumerate(dist) if d > 1e-12]
        if not vis:
            # точка в плоскости грани (четыре точки на одной окружности): на сфере она не
            # может быть внутри — грань в её плоскости считается видимой
            vis = [fi for fi, d in enumerate(dist) if d > -1e-10]
        if not vis:
            raise RuntimeError("оболочка: точка %d внутри — точки не на сфере или дубль" % p)
        edges = {}
        for fi in vis:
            a, b, c = faces[fi]
            for e in ((a, b), (b, c), (c, a)):
                edges[e] = edges.get(e, 0) + 1
        horizon = [e for e in edges if (e[1], e[0]) not in edges]
        vis_set = set(vis)
        faces = [f for i, f in enumerate(faces) if i not in vis_set]
        for (a, b) in horizon:
            faces.append((a, b, p))
        done.add(p)
    return faces


def circumcenter(a, b, c):
    return norm(cross(add(b, a, -1), add(c, a, -1)))


def dual(pts, faces, eps=1e-7):
    """Ячейки Вороного из триангуляции: контур — центры описанных окружностей
    прилегающих треугольников по кругу, совпадающие вершины слиты; соседи — по рёбрам
    контура ненулевой длины, в порядке контура."""
    inc = [[] for _ in pts]
    for fi, f in enumerate(faces):
        for x in f:
            inc[x].append(fi)
    cc = [circumcenter(pts[a], pts[b], pts[c]) for a, b, c in faces]
    outlines, neighbors = [], []
    for i, p in enumerate(pts):
        r0 = cc[inc[i][0]]
        ref = norm(add(r0, p, -dot(r0, p)))
        ref2 = cross(p, ref)
        ring = sorted(inc[i], key=lambda fi: math.atan2(dot(cc[fi], ref2), dot(cc[fi], ref)))
        # вершины контура и сосед на ребре между соседними треугольниками кольца
        verts, nbs = [], []
        for k in range(len(ring)):
            f_a, f_b = ring[k], ring[(k + 1) % len(ring)]
            shared = (set(faces[f_a]) & set(faces[f_b])) - {i}
            if not verts or arc(verts[-1], cc[f_a]) > eps:
                verts.append(cc[f_a])
            if arc(cc[f_a], cc[f_b]) > eps and shared:
                nbs.append(shared.pop())
        if len(verts) > 1 and arc(verts[0], verts[-1]) <= eps:
            verts.pop()
        outlines.append(verts)
        neighbors.append(nbs)
    return neighbors, outlines


def relax(pts, neighbors, pinned, max_iter=1500, k=0.2):
    """Пружины: расстояния до соседей к среднему; pinned — неподвижные (дефекты
    симметричных сеток держат симметрию)."""
    it = 0
    for it in range(1, max_iter + 1):
        cnt = sum(len(x) for x in neighbors)
        mean = sum(arc(pts[i], pts[j]) for i in range(len(pts)) for j in neighbors[i]) / cnt
        new, moved = [], 0.0
        for i, p in enumerate(pts):
            if i in pinned:
                new.append(p)
                continue
            g = [0.0, 0.0, 0.0]
            for j in neighbors[i]:
                dd = arc(p, pts[j])
                g = add(g, add(pts[j], p, -1), (dd - mean) / max(dd, 1e-9) * k)
            q = norm(add(p, add(g, p, -dot(g, p))))
            moved = max(moved, arc(p, q))
            new.append(q)
        pts = new
        if moved < 1e-9:
            break
    return pts, it


def metrics(pts, neighbors, outlines):
    d = [arc(pts[i], pts[j]) for i in range(len(pts)) for j in neighbors[i]]
    el = 1.0
    for i, o in enumerate(outlines):
        r = [arc(pts[i], v) for v in o]
        el = max(el, max(r) / min(r))
    deg = [len(x) for x in neighbors]
    hist = {}
    for x in deg:
        hist[x] = hist.get(x, 0) + 1
    return {"neighbor": max(d) / min(d), "elongation": el, "euler": sum(6 - x for x in deg),
            "sides": {str(k): v for k, v in sorted(hist.items())}}


def cell_size(pts, neighbors):
    """Поперечник ячейки на единичной сфере — как settings.globe_cell_cm при r=1:
    медиана расстояния до соседа / 2 × 2/√3 × 2."""
    d = sorted(arc(pts[i], pts[j]) for i in range(len(pts)) for j in neighbors[i])
    return d[len(d) // 2] * 0.5 * (2 / math.sqrt(3)) * 2


# --- сборка ------------------------------------------------------------------------------

def build(family, param):
    if family == "icosa":
        pts = lattice_points(ICO, ICO_FACES, *param)
    elif family == "octa":
        pts = lattice_points(OCT, OCT_FACES, *param)
    elif family == "fib":
        pts = fibonacci_points(param)
    else:
        pts = ring_points(param)
    faces = hull(pts)
    nbs, outs = dual(pts, faces)
    return pts, nbs, outs


def bake_one(family, name, param, expected_cells=None):
    raw, nbs, outs = build(family, param)
    if expected_cells is not None and len(raw) != expected_cells:
        raise RuntimeError("%s: ячеек %d вместо %d" % (name, len(raw), expected_cells))
    before = metrics(raw, nbs, outs)
    # дефекты симметричных сеток неподвижны; у колец и спирали двигаются все
    pinned = {i for i, x in enumerate(nbs) if len(x) != 6} if family in ("icosa", "octa") else set()
    if family == "rings":
        # Кольца не выравниваются: смысл раскладки — ряды по широтам, а пружины уводят точки
        # с широт (первый запуск: после выравнивания рядов не осталось, раскладка стала
        # похожа на спираль Фибоначчи).
        pts, nbs2, iters = raw, nbs, 0
        outs = outs
    elif family in ("icosa", "octa"):
        pts, iters = relax(raw, nbs, pinned)
        # после выравнивания триангуляция могла смениться — пересчёт, топология обязана устоять
        nbs2, outs = dual(pts, hull(pts))
        if [sorted(x) for x in nbs2] != [sorted(x) for x in nbs]:
            raise RuntimeError("%s: выравнивание сменило топологию" % name)
    else:
        # У свободных раскладок выравнивание двигает точки через границы Делоне: чередуем
        # выравнивание на текущей топологии и пересчёт, пока топология не устоится
        # (первый запуск: у fib_12 топология сменилась за одно выравнивание).
        pts, nbs2, iters = raw, nbs, 0
        for _round in range(30):
            pts, it = relax(pts, nbs2, pinned, max_iter=1000)
            iters += it
            nxt, outs = dual(pts, hull(pts))
            if [sorted(x) for x in nxt] == [sorted(x) for x in nbs2]:
                nbs2 = nxt
                break
            nbs2 = nxt
        else:
            raise RuntimeError("%s: топология не устоялась за 30 кругов" % name)
    after = metrics(pts, nbs2, outs)
    r4 = lambda m: {k: (round(v, 4) if isinstance(v, float) else v) for k, v in m.items()}
    data = {
        "name": name, "family": family, "param": param, "cells": len(pts),
        "metrics_before": r4(before), "metrics_after": r4(after), "iterations": iters,
        "cell_size": round(cell_size(pts, nbs2), 6),
        "centers": [[round(c, 7) for c in p] for p in pts],
        "centers_raw": [[round(c, 7) for c in p] for p in raw],
        "neighbors": nbs2,
        "outlines": [[[round(c, 7) for c in v] for v in o] for o in outs],
    }
    return data


def lattice_ladder(t_max):
    out = []
    for a in range(1, 9):
        for b in range(0, a + 1):
            t = a * a + a * b + b * b
            if t <= t_max:
                out.append((t, a, b))
    return sorted(out)


def lattice_gp_m0(m):
    """Прежнее построение шага 1в: разбиение граней икосаэдра решёткой, треугольники известны."""
    idx, pts, tris = {}, [], []

    def vtx(p):
        key = tuple(round(x, 6) for x in p)
        if key not in idx:
            idx[key] = len(pts)
            pts.append(p)
        return idx[key]

    for f in ICO_FACES:
        a, b, c = [ICO[x] for x in f]
        g = {}
        for i in range(m + 1):
            for j in range(m + 1 - i):
                g[(i, j)] = vtx(norm([a[k] * (m - i - j) / m + b[k] * i / m + c[k] * j / m for k in range(3)]))
        for i in range(m):
            for j in range(m - i):
                tris.append((g[(i, j)], g[(i + 1, j)], g[(i, j + 1)]))
                if i + j < m - 1:
                    tris.append((g[(i + 1, j)], g[(i + 1, j + 1)], g[(i, j + 1)]))
    return pts, tris


def gp_topology_control():
    """Контроль оболочки: GP(m,0) решёткой (прежний способ шага 1в) и оболочкой — один граф."""
    bad = []
    for m in range(2, 6):
        lp, ltris = lattice_gp_m0(m)
        key = lambda p: tuple(round(x, 5) for x in p)
        lg = {}
        for a, b, c in ltris:
            for u, v in ((a, b), (b, c), (c, a)):
                lg.setdefault(key(lp[u]), set()).add(key(lp[v]))
                lg.setdefault(key(lp[v]), set()).add(key(lp[u]))
        pts, nbs, _ = build("icosa", (m, 0))
        hg = {key(pts[i]): {key(pts[j]) for j in nbs[i]} for i in range(len(pts))}
        if hg != lg:
            bad.append(m)
    return bad


def main():
    os.makedirs(OUT, exist_ok=True)
    bad = gp_topology_control()
    print("контроль оболочки GP(m,0), m=2..5: %s" % ("совпало с решёткой" if not bad else "РАСХОЖДЕНИЕ m=%s" % bad))
    if bad:
        sys.exit(2)
    index = {}
    plans = {
        "icosa": [("icosa_%d_%d" % (a, b), (a, b), 10 * t + 2) for t, a, b in lattice_ladder(T_MAX)],
        "octa": [("octa_%d_%d" % (a, b), (a, b), 4 * t + 2) for t, a, b in lattice_ladder(160)],
        "fib": [("fib_%d" % n, n, n) for n in
                sorted({int(round(12 * (642 / 12) ** (i / 29))) for i in range(30)})],
        "rings": [("rings_%d" % i, 2.2 * (0.12 / 2.2) ** (i / 24), None) for i in range(25)],
    }
    for family, items in plans.items():
        ladder, last_size = [], None
        baked = [bake_one(family, name, param, expect) for name, param, expect in items]
        # ряд — по размеру ячейки от крупных к мелким, а не по T: у октаэдра 18 ячеек крупнее 14
        baked.sort(key=lambda d: -d["cell_size"])
        for data in baked:
            name = data["name"]
            if data["cells"] > 700:
                continue
            if last_size is not None and last_size / data["cell_size"] < MIN_STEP:
                print("  %-12s %4d ячеек — дубль по размеру (%.4f против %.4f), пропуск"
                      % (name, data["cells"], data["cell_size"], last_size))
                continue
            last_size = data["cell_size"]
            with open(os.path.join(OUT, name + ".json"), "w", encoding="utf-8") as f:
                json.dump(data, f, separators=(",", ":"))
            ladder.append([name, data["cells"]])
            ma = data["metrics_after"]
            print("%-12s %4d ячеек, итераций %4d: соседи %.3f → %.3f, вытянутость %.3f → %.3f, стороны %s, Эйлер %d"
                  % (name, data["cells"], data["iterations"], data["metrics_before"]["neighbor"], ma["neighbor"],
                     data["metrics_before"]["elongation"], ma["elongation"], ma["sides"], ma["euler"]))
        index[family] = ladder
    with open(os.path.join(OUT, "index.json"), "w", encoding="utf-8") as f:
        json.dump(index, f, ensure_ascii=False, indent=1)


if __name__ == "__main__":
    main()
