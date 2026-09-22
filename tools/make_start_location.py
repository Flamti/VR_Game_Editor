#!/usr/bin/env python3
"""Сборка стартовой локации и её интерьера (просьба владельца 2026-09-22: улица с домами, 100 м).

Почему генератор, а не правка JSON руками: улица — это повторяющаяся конструкция (дом = пять-шесть
стен, тротуар = лента, ряд зацепов = арифметическая прогрессия), и координаты стыков обязаны
сходиться до сантиметра. Руками такое расходится молча — в прежней локации лестница на две ступени
сидела в площадке, а верхняя площадка висела консолью 2.5 м, и никто этого не видел два месяца.

Здесь каждый стык считается из размеров соседа, а намерение (что с чем срастается, что за что
держится) пишется в данные полями `join` и `mounted_on` — их проверяет `world/level_check.gd`.

Запуск:  tools/make_start_location.py   — переписывает оба файла уровня.
"""

import json
import math
import pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
LEVELS = ROOT / "projects/sphere_menu/world/levels"

# --- размеры мира ----------------------------------------------------------------------
# Пол 100×100 (решение владельца). Улица уходит в −Z: туда же смотрит человек в точке старта.
FLOOR = 100.0
STREET_HALF = 2.0        # половина ширины проезжей части, м
WALK_W = 1.4             # тротуар, м
WALK_H = 0.12            # высота бордюра, м
FACADE = STREET_HALF + WALK_W        # x фасадов: 3.4 → между фасадами 6.8 м, улица узкая
WALL = 0.25              # толщина стены дома, м
STREET_FAR = -34.0       # дальний конец улицы
STREET_NEAR = 10.0       # площадь перед улицей

# Палитра: материалы общие на цвет, и число цветов — это число вызовов отрисовки (паспорт).
C_GROUND = "#6c7280"
C_WALK = "#7f8792"
C_WALL_A = "#8d7f6a"
C_WALL_B = "#6f7a82"
C_ROOF = "#5c5148"
C_WOOD = "#9a7b52"
C_STONE = "#8a93a6"
C_MARK = "#c4693f"
C_PALE = "#d8d2c0"

objects = []


def add(**o):
    objects.append(o)
    return o


def box(uuid, pos, size, color, **rest):
    return add(uuid=uuid, type="box", pos=[round(v, 3) for v in pos],
               size=[round(v, 3) for v in size], color=color, **rest)


def sign(uuid, pos, text, **rest):
    return add(uuid=uuid, type="sign", pos=[round(v, 3) for v in pos], text=text,
               size=0.1, groups=["подсказки"], **rest)


# --- земля и улица ---------------------------------------------------------------------

box("floor", [0, -0.1, 0], [FLOOR, 0.2, FLOOR], C_GROUND, groups=["площадки"])

street_len = STREET_NEAR - STREET_FAR
street_mid = (STREET_NEAR + STREET_FAR) / 2.0
# Тротуары — две ленты вдоль фасадов. Бордюр 12 см: ступенька, которую тело берёт шагом вверх
# (порог шага измерен в player_body.gd), а не препятствие.
for side, sx in (("l", -1), ("r", 1)):
    box(f"walk_{side}", [sx * (STREET_HALF + WALK_W / 2), WALK_H / 2, street_mid],
        [WALK_W, WALK_H, street_len], C_WALK, groups=["улица"])


def house(name, side, z0, z1, depth, height, color, door=None, roof_target=False):
    """Дом: четыре стены и крыша. Фасад стоит на линии застройки, торцы уходят от улицы.

    `door` — ширина проёма в фасаде (None — глухой). Проём делается двумя простенками, а не
    вычитанием: формат уровня знает только коробки.
    Возвращает словарь с координатами, чтобы к дому можно было пристроить крыльцо или стенд.
    """
    z0, z1 = min(z0, z1), max(z0, z1)          # порядок пары не важен вызывающему
    sx = -1 if side == "l" else 1
    x_face = sx * FACADE                       # плоскость фасада
    x_back = sx * (FACADE + depth)             # задняя стена
    x_mid = (x_face + x_back) / 2.0
    zc = (z0 + z1) / 2.0
    zlen = abs(z1 - z0)
    parts = []
    # Фасад: либо целиком, либо два простенка по краям проёма.
    if door is None:
        parts.append(box(f"{name}_face", [x_face + sx * WALL / 2, height / 2, zc],
                         [WALL, height, zlen], color, groups=["дома"]))
    else:
        side_w = (zlen - door) / 2.0
        for i, zz in enumerate((z0 + side_w / 2, z1 - side_w / 2)):
            parts.append(box(f"{name}_face{i}", [x_face + sx * WALL / 2, height / 2, zz],
                             [WALL, height, side_w], color, groups=["дома"]))
        # Перемычка над проёмом: 2.1 м — высота двери.
        parts.append(box(f"{name}_lintel", [x_face + sx * WALL / 2, (2.1 + height) / 2, zc],
                         [WALL, height - 2.1, door], color, groups=["дома"],
                         mounted_on=f"{name}_face0"))
    parts.append(box(f"{name}_back", [x_back - sx * WALL / 2, height / 2, zc],
                     [WALL, height, zlen], color, groups=["дома"]))
    for i, zz in enumerate((z0 + WALL / 2, z1 - WALL / 2)):
        parts.append(box(f"{name}_side{i}", [x_mid, height / 2, zz],
                         [depth, height, WALL], color, groups=["дома"]))
    roof = box(f"{name}_roof", [x_mid, height + 0.1, zc], [depth, 0.2, zlen], C_ROOF,
               groups=["дома"], tags=["teleport_target"] if roof_target else [])
    parts.append(roof)
    # Стены дома срастаются углами, крыша садится на стены — это замысел, а не врезка.
    ids = [p["uuid"] for p in parts]
    for p in parts:
        p["join"] = [i for i in ids if i != p["uuid"]]
    return {"name": name, "sx": sx, "x_face": x_face, "x_back": x_back, "x_mid": x_mid,
            "z0": min(z0, z1), "z1": max(z0, z1), "zc": zc, "height": height,
            "roof_y": height + 0.2, "parts": ids}


# Левый ряд: жилой дом с интерьером, дом с крыльцом и пандусом, дом со стеной лазанья.
h_home = house("home", "l", -2.0, -10.0, 7.0, 3.0, C_WALL_A, door=1.6)
h_ramp = house("hramp", "l", -12.5, -20.5, 6.0, 4.2, C_WALL_B)
h_climb = house("hclimb", "l", -23.0, -31.0, 6.5, 3.4, C_WALL_A, roof_target=True)
# Правый ряд: дом с лестницей на балкон, глухой высокий, дом с балкой-уступом.
h_stair = house("hstair", "r", -2.0, -11.0, 7.0, 5.6, C_WALL_B)
h_tall = house("htall", "r", -13.5, -21.5, 6.0, 7.0, C_WALL_A)
h_beam = house("hbeam", "r", -24.0, -31.0, 6.0, 4.0, C_WALL_B, roof_target=True)

# --- площадь перед улицей: старт, верстак, метки, пятачки телепорта --------------------

# yaw=0: в Godot «вперёд» — это −Z, куда и уходит улица. Прежние данные несли yaw=180, и человек
# в точке старта оказывался спиной ко всей сцене (видно только снимком, tests/render_level.gd).
add(uuid="spawn", type="spawn", pos=[0, 0, 8], yaw=0)
sign("sign_street", [0, 2.4, 2.0], "Улица уходит на север\nдома по обе стороны")

# Верстак: столешница садится на ножки — опора входит в неё, и это записано в join.
TABLE_Y = 0.74
box("table", [-4.6, TABLE_Y - 0.04, 7.0], [1.8, 0.08, 0.8], C_WOOD,
    groups=["постройки"], join=["leg0", "leg1"])
for i, xx in enumerate((-5.3, -3.9)):
    box(f"leg{i}", [xx, (TABLE_Y - 0.08) / 2, 7.0], [0.08, TABLE_Y - 0.08, 0.08], C_WOOD,
        groups=["постройки"], join=["table"])
sign("sign_table", [-4.6, 1.5, 7.0], "Верстак 0.74 м\nкубы берутся грипом")
for i in range(6):
    box(f"grab{i}", [-5.25 + i * 0.26, TABLE_Y + 0.06, 7.0], [0.12, 0.12, 0.12], C_MARK,
        body="grab", groups=["предметы"])

# Столбы-метки масштаба 1 и 2 м и разметка высот на них (слой редактора).
for i, (xx, hh) in enumerate(((4.2, 1.0), (4.6, 2.0))):
    box(f"post{i}", [xx, hh / 2, 6.6], [0.1, hh, 0.1], C_PALE, groups=["постройки"])
sign("sign_posts", [4.4, 2.5, 6.6], "Столбы 1 и 2 м — метки масштаба")
for i in range(4):
    box(f"mark{i}", [4.2, 0.5 + i * 0.5, 6.6], [0.16, 0.02, 0.16], C_MARK,
        body="none", layer="editor", groups=["разметка"], mounted_on="post0")

# Пятачки телепорта на площади: цель для луча, лежат прямо на земле.
for i, (xx, zz) in enumerate(((-2.0, 11.5), (0.0, 13.0), (2.0, 11.5))):
    box(f"pad{i}", [xx, 0.02, zz], [1.0, 0.04, 1.0], "#3f7fc4",
        tags=["teleport_target"], groups=["площадки"])

# --- дом с интерьером: проём, порог, триггер подгрузки ---------------------------------

door_z = h_home["zc"]
# Порог вровень с тротуаром: вход не должен требовать шага вверх в 0.12 после бордюра.
# Порог заходит под дверную коробку — вмурован, а не приставлен.
box("home_step", [h_home["x_face"] - 0.5, WALK_H / 2, door_z], [1.0, WALK_H, 1.8], C_WALK,
    groups=["улица"], join=["walk_l", "home_face0", "home_face1"])
add(uuid="home_enter", type="trigger",
    pos=[round(h_home["x_mid"], 3), 1.2, round(door_z, 3)],
    # Дом левого ряда уходит в −X, и разность граней там отрицательная: размер берётся по модулю,
    # иначе зона выходит с отрицательной стороной и загрузчик отвергает уровень целиком.
    size=[round(abs(h_home["x_back"] - h_home["x_face"]) - 2 * WALL, 3), 2.2,
          round(abs(h_home["z1"] - h_home["z0"]) - 2 * WALL, 3)],
    loads="res://world/levels/start_interior.json", groups=["дома"])
sign("sign_home", [h_home["x_face"] - 0.6, 2.5, door_z],
     "Жилой дом: интерьер грузится при входе\nи выгружается при выходе")

# --- пандус на крыльцо второго дома ----------------------------------------------------

PORCH_Y = 0.9
porch_z0, porch_z1 = h_ramp["z0"] + 1.0, h_ramp["z0"] + 4.0
porch_x1 = h_ramp["x_face"]                       # крыльцо прижато к фасаду
porch_x0 = porch_x1 + 2.6                         # и выступает на улицу (x растёт к центру)
box("porch", [(porch_x0 + porch_x1) / 2, PORCH_Y / 2, (porch_z0 + porch_z1) / 2],
    [abs(porch_x1 - porch_x0), PORCH_Y, porch_z1 - porch_z0], C_STONE,
    tags=["teleport_target"], groups=["площадки"], join=["hramp_face", "walk_l"])
# Пандус — наклонная плита: подъём 0.9 м на 5.1 м длины, это 10°. Наклон вокруг оси X, поэтому
# длина плиты берётся по гипотенузе, иначе верхний край не достанет до крыльца.
RAMP_RUN = 5.1
RAMP_T = 0.14
ramp_len = (RAMP_RUN ** 2 + PORCH_Y ** 2) ** 0.5
ramp_angle = 10.0
_ra = math.radians(ramp_angle)
# Высота коробки вокруг наклонной плиты: подъём плюс толщина, развёрнутая наклоном. Центр ставится
# так, чтобы нижний угол лёг ровно на землю, — иначе пандус либо утоплен в грунт, либо парит.
ramp_h = ramp_len * math.sin(_ra) + RAMP_T * math.cos(_ra)
# Положительный угол вокруг X опускает конец +Z: высокий край выходит со стороны −Z, где крыльцо.
box("ramp", [(porch_x0 + porch_x1) / 2, ramp_h / 2, porch_z1 + RAMP_RUN / 2],
    [abs(porch_x1 - porch_x0), RAMP_T, ramp_len], C_WOOD,
    rot=[ramp_angle, 0, 0], groups=["площадки"], leads_to="porch", join=["porch", "walk_l"])
sign("sign_ramp", [(porch_x0 + porch_x1) / 2, 1.9, porch_z1 + RAMP_RUN / 2],
     "Пандус 10°\nпройти ногами и телепортом")

# --- лестница на балкон дома напротив ---------------------------------------------------

BALCONY_Y = 1.8
bal_z0, bal_z1 = h_stair["z0"] + 1.2, h_stair["z0"] + 4.2
bal_x0 = h_stair["x_face"]                        # у фасада
bal_x1 = bal_x0 - 2.4                             # выступает на улицу (x убывает к центру)
box("balcony", [(bal_x0 + bal_x1) / 2, BALCONY_Y - 0.15, (bal_z0 + bal_z1) / 2],
    [abs(bal_x1 - bal_x0), 0.3, bal_z1 - bal_z0], C_STONE,
    tags=["teleport_target"], groups=["площадки"],
    join=["hstair_face0", "hstair_face1", "balcony_post"])
box("balcony_post", [bal_x1 + 0.15, (BALCONY_Y - 0.3) / 2, bal_z0 + 0.2],
    [0.18, BALCONY_Y - 0.3, 0.18], C_STONE, groups=["постройки"],
    join=["balcony", "walk_r"])
# Лесенка: rise 0.18, и число ступеней считается загрузчиком как round(size.y / rise). Ступени
# уходят в −Z от точки, поэтому лестницу ставят у дальнего края балкона и ведут к нему.
STAIR_RISE = 0.18
stair_steps = round(BALCONY_Y / STAIR_RISE)
stair_run = 0.3
# Загрузчик кладёт ступень i в (pos.x, rise*(i+0.5), pos.z − run*i): лестница РАСТЁТ в сторону −Z.
# Поэтому точка отсчёта — нижняя ступень, и стоит она с той стороны балкона, что ближе к площади.
stair_top_z = bal_z1 + stair_run / 2
add(uuid="stairs", type="stairs",
    pos=[round((bal_x0 + bal_x1) / 2, 3), 0.0,
         round(stair_top_z + stair_run * (stair_steps - 1), 3)],
    size=[abs(bal_x1 - bal_x0) - 0.4, round(stair_steps * STAIR_RISE, 3), stair_run],
    rise=STAIR_RISE, run=stair_run, color=C_STONE, groups=["площадки"],
    leads_to="balcony", join=["balcony", "walk_r"])
sign("sign_stairs", [(bal_x0 + bal_x1) / 2, 2.4, bal_z1 + 1.2],
     "Ступени 0.18 м\nтело поднимается само")

# --- стена лазанья на торце третьего дома и перевал на крышу ---------------------------

wall_face_x = h_climb["x_face"]
wall_z = h_climb["z0"] + 3.0
CLIMB_TOP = h_climb["height"]          # лезем до карниза
# Зацепы в шахматном порядке: сосед по высоте не дальше вытянутой руки, иначе перехват срывается.
# Наружу — это ПРОТИВ sx: у левого ряда дом лежит в −X, и брус со смещением по sx утапливается
# в стену заподлицо. Сессия 29: стена простояла гладкой, лазанья не случилось ни разу.
out_x = -h_climb["sx"]
holds = []
step_y, off_z = 0.35, 0.25
n_holds = int((CLIMB_TOP - 0.55) / step_y) + 1
for i in range(n_holds):
    y = 0.55 + i * step_y
    z = wall_z + (off_z if i % 2 else -off_z)
    # Брус входит в стену на треть и торчит наружу: за то, что торчит, и берётся рука.
    holds.append(box(f"climb{i}", [wall_face_x + out_x * 0.04, y, z], [0.12, 0.09, 0.5], C_WOOD,
                     tags=["climb"], groups=["зацепы"], mounted_on="hclimb_face"))
sign("sign_climb", [wall_face_x + out_x * 0.7, CLIMB_TOP + 0.5, wall_z],
     "Стена %.1f м — грип у бруска, перехват руками" % CLIMB_TOP)
# Кромка перевала: зона у карниза, точка приземления — на крыше, в полуметре от края.
_in = h_climb["sx"]          # к дому: у левого ряда это −X
add(uuid="ledge_roof", type="ledge",
    pos=[round(wall_face_x + _in * 0.2, 3), round(h_climb["roof_y"], 3), round(wall_z, 3)],
    size=[0.8, 0.5, 2.4],
    target=[round(wall_face_x + _in * 1.0, 3), round(h_climb["roof_y"], 3), round(wall_z, 3)],
    layer="editor", groups=["кромки"])
sign("sign_roof", [wall_face_x + _in * 1.2, h_climb["roof_y"] + 1.0, wall_z],
     "Крыша: долез — подтянись и перевались")

# --- узкий уступ: балка над переулком ---------------------------------------------------

beam_z = h_beam["z0"] + 1.5
box("beam", [h_beam["x_face"] - 3.0, h_beam["height"] - 0.3, beam_z], [6.0, 0.35, 0.5], C_WOOD,
    tags=["teleport_target"], groups=["площадки"], mounted_on="hbeam_face")
sign("sign_beam", [h_beam["x_face"] - 3.0, h_beam["height"] + 0.4, beam_z],
     "Узкий уступ — точность луча")

# --- тупик улицы: помост, с которого видно всю улицу -----------------------------------

END_Z = STREET_FAR + 1.3
box("end_deck", [0, 0.6, END_Z], [8.0, 1.2, 2.4], C_STONE,
    tags=["teleport_target"], groups=["площадки"], join=["walk_l", "walk_r"])
sign("sign_end", [0, 2.2, END_Z], "Конец улицы")

location = {"format": 1, "name": "Стартовая локация: улица", "objects": objects}

# --- интерьер жилого дома ---------------------------------------------------------------
# Строится по координатам самого дома: подвинулся дом — подвинулась обстановка. Раньше интерьер
# держал мировые координаты своими числами, и любая правка улицы расставила бы мебель по стенам.

ix0, ix1 = h_home["x_face"], h_home["x_back"]
ix_mid = h_home["x_mid"]
iz0, iz1 = h_home["z0"] + WALL, h_home["z1"] - WALL
inner = []


def iadd(**o):
    inner.append(o)
    return o


def ibox(uuid, pos, size, color, **rest):
    return iadd(uuid=uuid, type="box", pos=[round(v, 3) for v in pos],
                size=[round(v, 3) for v in size], color=color, **rest)


IT_Y = 0.74
ibox("in_table", [ix_mid, IT_Y - 0.04, iz0 + 1.2], [1.4, 0.08, 0.7], C_WOOD,
     groups=["постройки"], join=["in_leg0", "in_leg1"])
for i, dx in enumerate((-0.6, 0.6)):
    ibox(f"in_leg{i}", [ix_mid + dx, (IT_Y - 0.08) / 2, iz0 + 1.2],
         [0.08, IT_Y - 0.08, 0.08], C_WOOD, groups=["постройки"], join=["in_table"])
# Полки на задней стене: держатся за неё, а не стоят на полу. Внутрь дома — это В СТОРОНУ ФАСАДА,
# то есть против sx: у левого ряда sx = −1, и прибавка со знаком sx унесла бы полки за стену, на
# улицу. Проверка связности этого не ловит: хозяин крепления лежит в другом файле.
shelf_x = ix1 - h_home["sx"] * (WALL + 0.2)
for i in range(3):
    y = 0.8 + i * 0.5
    ibox(f"in_shelf{i}", [shelf_x, y, (iz0 + iz1) / 2], [0.4, 0.06, 2.4], C_WOOD,
         groups=["постройки"], mounted_on="home_back")
    for j in range(2):
        ibox(f"in_box{i}{j}", [shelf_x, y + 0.14, (iz0 + iz1) / 2 - 0.5 + j * 1.0],
             [0.22, 0.22, 0.22], C_MARK, body="grab", groups=["предметы"])
ibox("in_lamp", [ix_mid, h_home["height"] - 0.35, (iz0 + iz1) / 2], [0.5, 0.12, 0.5], "#ffe9a8",
     body="none", groups=["постройки"])
iadd(uuid="in_sign", type="sign", pos=[round(ix_mid, 3), 1.9, round(iz0 + 1.2, 3)],
     text="Интерьер подгружен по входу", size=0.08, groups=["подсказки"])

interior = {"format": 1, "name": "Интерьер жилого дома", "part": True, "objects": inner}

for path, data in ((LEVELS / "start_location.json", location),
                   (LEVELS / "start_interior.json", interior)):
    path.write_text(json.dumps(data, ensure_ascii=False, indent="\t") + "\n", encoding="utf-8")
    print(f"{path.name}: {len(data['objects'])} объектов")
