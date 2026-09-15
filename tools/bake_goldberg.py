#!/usr/bin/env python3
"""Запекание равномерных многогранников Гольдберга для шар-меню (Ф2, шаг 1в).

Зачем. Разбиение икосаэдра с простой нормировкой на сферу даёт ячейки разной
площади: max/min до 2.33 на m=8 (с учётом пятиугольников). На шлеме владелец
увидел это как «ячейки съезжают» (сессия 2026-09-15). Выравнивание площадей —
сотни итераций по 642 ячейкам: в GDScript на шлеме это секунды на каждую смену
размера ячейки. Поэтому геометрия считается здесь один раз и кладётся в
projects/sphere_menu/menu/geo/*.json; приложение её загружает, настольные
проверки проверяют загруженное.

Выравнивание — пружины. Пятиугольники (вершины икосаэдра) неподвижны; каждый
шестиугольник смещается так, чтобы угловые расстояния до соседей стремились к
среднему. Глаз видит сетку по расстояниям между центрами и по форме ячеек, а не
по площадям. Замер 2026-09-15 (разброс расстояний до соседей max/min, вытянутость
ячейки — max/min расстояния от центра до углов контура):

  m=8, 642 ячейки   исходная 1.38 / 1.17   площади 1.69 / 1.67   пружины 1.22 / 1.11
  m=5, 252 ячейки   исходная 1.32 / 1.13   площади 1.79 / 2.08   пружины 1.19 / 1.09

Отвергнуто: выравнивание площадей (шестиугольник к большему соседу) — площади
выходят 1.00–1.12, но ячейки вытягиваются до 2.08, и сетка «съезжает» заметнее
исходной. Ллойд (центр → центроид ячейки) — на m=8 шестиугольники по площади
1.53 → 1.35, форму не чинит. Остаток пружин (1.14–1.22) неустраним итерациями:
100 и 1500 итераций дают одно и то же, это кривизна у пятиугольников. Разницу
площадей компенсирует размер каждой ячейки по её контуру в рендере.

Использование:
  tools/bake_goldberg.py [каталог_вывода]
"""

import json
import math
import os
import sys

OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(
    os.path.dirname(__file__), "..", "projects", "sphere_menu", "menu", "geo")

T = (1 + 5 ** 0.5) / 2
ICO = [(-1, T, 0), (1, T, 0), (-1, -T, 0), (1, -T, 0), (0, -1, T), (0, 1, T), (0, -1, -T), (0, 1, -T),
       (T, 0, -1), (T, 0, 1), (-T, 0, -1), (-T, 0, 1)]
FACES = [(0, 11, 5), (0, 5, 1), (0, 1, 7), (0, 7, 10), (0, 10, 11), (1, 5, 9), (5, 11, 4), (11, 10, 2),
         (10, 7, 6), (7, 1, 8), (3, 9, 4), (3, 4, 2), (3, 2, 6), (3, 6, 8), (3, 8, 9), (4, 9, 5),
         (2, 4, 11), (6, 2, 10), (8, 6, 7), (9, 8, 1)]


def norm(v):
    l = math.sqrt(v[0] * v[0] + v[1] * v[1] + v[2] * v[2])
    return [v[0] / l, v[1] / l, v[2] / l]


def add(a, b, s=1.0):
    return [a[0] + b[0] * s, a[1] + b[1] * s, a[2] + b[2] * s]


def dot(a, b):
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


def cross(a, b):
    return [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]]


ICO = [norm(v) for v in ICO]


def build_gp_m0(m):
    idx, pts, tris = {}, [], []

    def vtx(p):
        key = tuple(round(x, 6) for x in p)
        if key not in idx:
            idx[key] = len(pts)
            pts.append(p)
        return idx[key]

    for f in FACES:
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


def build_gp11():
    """GP(1,1), 32 ячейки: пятиугольники в вершинах икосаэдра, шестиугольники в центрах граней.
    Треугольники: на каждое ребро икосаэдра (a,b) с гранями F,G — (a,F,G) и (b,G,F)."""
    pts = [list(v) for v in ICO]
    centers = []
    for f in FACES:
        centers.append(len(pts))
        pts.append(norm(add(add(ICO[f[0]], ICO[f[1]]), ICO[f[2]])))
    edge_faces = {}
    for fi, f in enumerate(FACES):
        for k in range(3):
            e = tuple(sorted((f[k], f[(k + 1) % 3])))
            edge_faces.setdefault(e, []).append(fi)
    tris = []
    for (a, b), fs in edge_faces.items():
        F, G = centers[fs[0]], centers[fs[1]]
        tris.append((a, F, G))
        tris.append((b, G, F))
    return pts, tris


def incident(pts, tris):
    inc = [[] for _ in pts]
    for ti, tr in enumerate(tris):
        for x in tr:
            inc[x].append(ti)
    return inc


def sph_area(p, q, r):
    return 2 * math.atan2(abs(dot(p, cross(q, r))), 1 + dot(p, q) + dot(q, r) + dot(r, p))


def cells(pts, tris, inc):
    """Контур каждой ячейки — центроиды прилегающих треугольников по кругу; площадь — сумма
    сферических треугольников центр–ребро контура."""
    cent = [norm(add(add(pts[a], pts[b]), pts[c])) for a, b, c in tris]
    areas, rings = [], []
    for i, p in enumerate(pts):
        r0 = cent[inc[i][0]]
        ref = norm(add(r0, p, -dot(r0, p)))
        ref2 = cross(p, ref)
        ring = sorted(inc[i], key=lambda ti: math.atan2(dot(cent[ti], ref2), dot(cent[ti], ref)))
        a = 0.0
        for k in range(len(ring)):
            a += sph_area(p, cent[ring[k]], cent[ring[(k + 1) % len(ring)]])
        areas.append(a)
        rings.append([cent[ti] for ti in ring])
    return areas, rings


def neighbor_sets(pts, tris):
    nb = [set() for _ in pts]
    for a, b, c in tris:
        nb[a] |= {b, c}
        nb[b] |= {a, c}
        nb[c] |= {a, b}
    return nb


def arc(p, q):
    return math.acos(max(-1.0, min(1.0, dot(p, q))))


def metrics(pts, tris):
    """Разброс площадей (шести/все), разброс расстояний до соседей, худшая вытянутость."""
    inc = incident(pts, tris)
    deg = [len(x) for x in inc]
    areas, rings = cells(pts, tris, inc)
    hexes = [a for a, d in zip(areas, deg) if d == 6] or areas
    nb = neighbor_sets(pts, tris)
    d = [arc(pts[i], pts[j]) for i in range(len(pts)) for j in nb[i]]
    el = 1.0
    for i, ring in enumerate(rings):
        r = [arc(pts[i], v) for v in ring]
        el = max(el, max(r) / min(r))
    return {"area_hex": max(hexes) / min(hexes), "area_all": max(areas) / min(areas),
            "neighbor": max(d) / min(d), "elongation": el}


def relax(pts, tris, max_iter=1000, k=0.2):
    inc = incident(pts, tris)
    deg = [len(x) for x in inc]
    nb = neighbor_sets(pts, tris)
    it = 0
    for it in range(1, max_iter + 1):
        mean = sum(arc(pts[i], pts[j]) for i in range(len(pts)) for j in nb[i]) / sum(len(x) for x in nb)
        new, moved = [], 0.0
        for i, p in enumerate(pts):
            if deg[i] == 5:
                new.append(p)
                continue
            g = [0.0, 0.0, 0.0]
            for j in nb[i]:
                dd = arc(p, pts[j])
                g = add(g, add(pts[j], p, -1), (dd - mean) / max(dd, 1e-9) * k)
            q = norm(add(p, add(g, p, -dot(g, p))))
            moved = max(moved, arc(p, q))
            new.append(q)
        pts = new
        if moved < 1e-9:
            break
    return pts, it


def ordered_neighbors(pts, tris, inc, i):
    nb = set()
    for ti in inc[i]:
        nb.update(x for x in tris[ti] if x != i)
    p = pts[i]
    first = pts[next(iter(nb))]
    ref = norm(add(first, p, -dot(first, p)))
    ref2 = cross(p, ref)
    return sorted(nb, key=lambda x: math.atan2(dot(pts[x], ref2), dot(pts[x], ref)))


def bake(name, pts, tris):
    raw = pts
    before = metrics(pts, tris)
    pts, iters = relax(pts, tris)
    after = metrics(pts, tris)
    inc = incident(pts, tris)
    _, rings = cells(pts, tris, inc)
    r4 = lambda m: {k: round(v, 4) for k, v in m.items()}
    data = {
        "name": name,
        "cells": len(pts),
        "metrics_before": r4(before),
        "metrics_after": r4(after),
        "iterations": iters,
        "centers": [[round(c, 7) for c in p] for p in pts],
        # Центры до выравнивания — для фальсификатора настольных проверок «релаксация выключена».
        "centers_raw": [[round(c, 7) for c in p] for p in raw],
        "neighbors": [ordered_neighbors(pts, tris, inc, i) for i in range(len(pts))],
        "outlines": [[[round(c, 7) for c in v] for v in ring] for ring in rings],
    }
    os.makedirs(OUT, exist_ok=True)
    with open(os.path.join(OUT, name + ".json"), "w", encoding="utf-8") as f:
        json.dump(data, f, separators=(",", ":"))
    print("%-6s ячеек %4d, итераций %4d: соседи %.3f → %.3f, вытянутость %.3f → %.3f, площади %.3f → %.3f"
          % (name, len(pts), iters, before["neighbor"], after["neighbor"], before["elongation"],
             after["elongation"], before["area_all"], after["area_all"]))


def main():
    bake("gp1_0", *build_gp_m0(1))
    bake("gp1_1", *build_gp11())
    for m in range(2, 9):
        bake("gp%d_0" % m, *build_gp_m0(m))


if __name__ == "__main__":
    main()
