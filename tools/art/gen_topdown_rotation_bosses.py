"""도감 v2 보통 보스 23종 (해역 보스 4종 순환, docs/specs/platform-bestiary-v2-regions.draft.json). 위에서 본 도트, 머리가 위, 2프레임. OWN.

    python -I tools/art/gen_topdown_rotation_bosses.py            # assets/bosses/td_<id>.png + <id>.png(컷인 초상)
    python -I tools/art/gen_topdown_rotation_bosses.py --check

해적선 4종(storm_raider·frost_pirate·blaze_pirate·wraith_ship)은 gen_topdown_bosses의 배 그리기를 팔레트·문장만 바꾸고,
hunter_sub는 deep_sub 색 바꿈, 나머지 18종은 td_shade(입체 음영)로 새로 그린다. 프레임 64×64(대보스 88보다 작고 보통 보스 56보다 큼).
"""

from __future__ import annotations

import importlib.util
import json
import math
import sys
from pathlib import Path

sys.dont_write_bytecode = True

HERE = Path(__file__).resolve().parent
ASSETS = HERE.parents[1] / "apps" / "game" / "assets"
SOURCE = "자작(코드) — tools/art/gen_topdown_rotation_bosses.py 위에서 본 픽셀 격자(입체 음영·배는 gen_topdown_bosses 재색칠)"
N = 64
C = N / 2


def _load(name):
    spec = importlib.util.spec_from_file_location(name, HERE / f"{name}.py")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


_b = _load("gen_bosses")
_t = _load("td_shade")
_tb = _load("gen_topdown_bosses")
Can, ramp, mix = _t.Can, _t.ramp, _t.mix
OUT = _b.OUTLINE
W, K = (250, 248, 236), (20, 14, 26)
GOLD = ramp((236, 182, 52))


def crown(g, x, y, w=10):
    """작은 금관(보스 표시)."""
    for dx in range(-w // 2, w // 2 + 1, 3):
        g.spike(x + dx, y + 2, x + dx, y - 3, 1.4, GOLD)
    g.blob(x, y + 2, w / 2 + 1, 1.6, GOLD, sep=False)


# ---------- 산호 ----------
def hermit_conch(f):
    g = Can(N)
    shell, claw = ramp((236, 150, 170)), ramp((220, 90, 70))
    leg = 2 if f else -2
    for side in (-1, 1):
        for i in range(3):
            g.chain([(C + side * 8, 30 + i * 5), (C + side * 17, 28 + i * 5 + leg * side)], [2.2, 1.6], claw)
        g.blob(C + side * 10, 14 + (1 if f and side > 0 else 0), 5.5, 4.5, claw)
    g.blob(C, 20, 7, 5, claw)
    for side in (-1, 1):
        g.eye(C + side * 3, 16, 1.4, (250, 230, 120))
    g.blob(C, 38, 15, 17, shell)
    for k in range(60):  # 소라 나선
        t = k / 60 * 4.4 * math.pi
        r = 1 + t * 0.95
        g.put(C + math.cos(t) * r, 38 + math.sin(t) * r, shell[0])
    for a in range(0, 360, 45):
        x, y = C + math.cos(math.radians(a)) * 15, 38 + math.sin(math.radians(a)) * 17
        g.spike(x, y, x + math.cos(math.radians(a)) * 4, y + math.sin(math.radians(a)) * 4, 1.6, shell)
    return g.outline(OUT)


def jelly_queen(f):
    g = Can(N)
    bell = [(200, 110, 220, 230), (220, 140, 235, 225), (240, 180, 245, 220), (250, 215, 250, 215), (255, 240, 255, 230)]
    for i in range(8):
        a = math.pi / 2 + (i - 3.5) * 0.32
        pts = [(C + math.cos(a) * (10 + k * 3) + math.sin(k * 0.7 + i + (1.2 if f else 0)) * 2, 28 + math.sin(a) * (10 + k * 3)) for k in range(10)]
        g.chain(pts, [2.2 - k * 0.15 for k in range(10)], ramp((210, 130, 230)))
    g.blob(C, 26, 18, 16, bell, sep=False)
    g.blob(C, 26, 10, 8, [(255, 200, 250, 200), (255, 220, 255, 200), (255, 240, 255, 200)], sep=False)
    crown(g, C, 9, 12)
    for side in (-1, 1):
        g.eye(C + side * 5, 25, 1.6, (90, 30, 120))
    return g.outline(OUT)


def hammer_shark(f):
    g = Can(N)
    body, belly = ramp((96, 120, 150)), ramp((180, 196, 210))
    sw = 3 if f else -3
    g.chain([(C, 36), (C + sw * 0.4, 46), (C + sw, 56)], [7, 4.5, 2.4], body)
    g.blob(C + sw, 58, 6, 2.2, body, ang=0.4 * (1 if f else -1))
    for side in (-1, 1):
        g.blob(C + side * 12, 30, 9, 3, body, ang=side * 0.6)
    g.blob(C, 28, 8, 14, body)
    g.blob(C, 12, 17, 4, body)  # 망치 머리
    g.spike(C, 22, C, 30, 3, body)  # 등지느러미 쪽 볼록
    for side in (-1, 1):
        g.eye(C + side * 15, 12, 1.5, (250, 220, 90))
    for k in range(3):
        g.line(C - 4, 20 + k * 2, C + 4, 20 + k * 2, body[0])
    return g.outline(OUT)


# ---------- 폭풍 ----------
def thunder_ray_pup(f):
    g = Can(N)
    body, bolt = ramp((90, 96, 150)), (250, 214, 70)
    flap = 3 if f else 0
    g.poly([(C, 10), (C + 22, C + flap), (C + 6, C + 10), (C, C + 14), (C - 6, C + 10), (C - 22, C + flap)], None, body)
    g.line(C, C + 14, C, 58, body[0])
    g.blob(C, C, 8, 10, body, lift=0.1)
    for pts in (((C - 15, C - 1), (C - 10, C + 2), (C - 12, C + 4), (C - 7, C + 7)), ((C + 15, C - 1), (C + 10, C + 2), (C + 12, C + 4), (C + 7, C + 7))):
        for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
            g.line(x0, y0, x1, y1, bolt)
    for side in (-1, 1):
        g.eye(C + side * 3, 16, 1.4, bolt)
    g.put(C, 57 + (1 if f else 0), bolt)
    return g.outline(OUT)


def great_serpent(f):
    g = Can(N)
    scale, belly = ramp((50, 150, 120)), ramp((220, 210, 120))
    ph = 1.2 if f else 0
    pts, rad = [], []
    for k in range(34):
        t = k / 33
        pts.append((C + math.sin(t * 6 + ph) * 16 * (0.4 + 0.6 * t), 16 + t * 46))
        rad.append(6.5 - 4.5 * t)
    g.chain(pts, rad, scale)
    for k in range(2, 32, 3):
        x, y = pts[k]
        g.spike(x, y, x, y - 3 - rad[k] * 0.3, 1.4, ramp((200, 80, 60)))
    hx, hy = pts[0]
    g.blob(hx, hy - 3, 7, 8, scale)
    for side in (-1, 1):
        g.eye(hx + side * 4, hy - 5, 1.5, (250, 60, 50))
        g.line(hx + side * 1.5, hy - 11, hx + side * 3, hy - 15, (230, 80, 90))  # 갈래 혀
    return g.outline(OUT)


def twister_dolphin(f):
    g = Can(N)
    body = ramp((110, 150, 200))
    sw = 3 if f else -3
    for k in range(18):  # 회오리
        a = k * 0.7 + (0.6 if f else 0)
        r = 22 - k
        g.put(C + math.cos(a) * r, 34 + math.sin(a) * r * 0.7, (200, 230, 250))
    g.chain([(C, 40), (C + sw * 0.5, 50)], [5, 3], body)
    for side in (-1, 1):
        g.blob(C + sw * 0.5 + side * 5, 54, 5, 2, body, ang=side * 0.5)
        g.blob(C + side * 9, 30, 6, 2.4, body, ang=side * 0.7)
    g.blob(C, 28, 7, 13, body)
    g.blob(C, 13, 3, 4, body)  # 주둥이
    g.spike(C, 30, C, 22, 2.6, ramp((80, 110, 160)))
    for side in (-1, 1):
        g.eye(C + side * 4, 20, 1.3, (30, 40, 60))
    return g.outline(OUT)


# ---------- 빙하 ----------
def seal_chief(f):
    g = Can(N)
    fur, helm = ramp((150, 160, 175)), ramp((200, 210, 225))
    flip = 2 if f else -2
    for side in (-1, 1):
        g.blob(C + side * 13, 34 + flip * side, 7, 3, fur, ang=side * 0.5)
    g.chain([(C, 44), (C, 54)], [8, 4], fur)
    for side in (-1, 1):
        g.blob(C + side * 4, 58, 5, 2, fur, ang=side * 0.6)
    g.blob(C, 34, 12, 14, fur)
    g.blob(C, 18, 9, 8, fur, lift=0.05)
    g.blob(C, 13, 9, 4, helm)  # 투구
    g.spike(C, 11, C, 4, 2, helm)
    for side in (-1, 1):
        g.eye(C + side * 4, 18, 1.5, K)
        g.line(C + side * 2, 22, C + side * 8, 21, W)  # 수염
    return g.outline(OUT)


def giant_squid(f):
    g = Can(N)
    body = ramp((235, 200, 205))
    for i in range(8):
        a = math.pi / 2 + (i - 3.5) * 0.3
        pts = [(C + math.cos(a) * (4 + k * 3.3) + math.sin(k * 0.6 + i + (1.4 if f else 0)) * 2.2, 36 + math.sin(a) * (4 + k * 3.3)) for k in range(8)]
        g.chain(pts, [2.4 - k * 0.2 for k in range(8)], body)
    for side in (-1, 1):  # 긴 촉완 둘
        pts = [(C + side * (3 + k * 1.3 + math.sin(k * 0.5 + (1 if f else 0)) * 2), 38 + k * 2.6) for k in range(10)]
        g.chain(pts, [1.6] * 9 + [2.6], body)
    g.blob(C, 22, 8, 18, body)
    g.poly([(C - 9, 8), (C + 9, 8), (C, -1)], None, body)  # 지느러미
    for side in (-1, 1):
        g.eye(C + side * 7, 36, 2.4, (40, 90, 160), glow=(200, 230, 250))
    return g.outline(OUT)


def icecrab_chief(f):
    g = Can(N)
    shell, claw = ramp((120, 190, 235)), ramp((150, 210, 245))
    leg = 2 if f else -2
    for side in (-1, 1):
        for i in range(3):
            g.chain([(C + side * 10, 32 + i * 5), (C + side * 22, 30 + i * 6 + leg * side)], [2.2, 1.5], shell)
        g.chain([(C + side * 9, 26), (C + side * 16, 18)], [2.6, 2.4], shell)
        g.blob(C + side * 17, 13, 6, 5, claw)
        g.put(C + side * (14 if f else 16), 8, None)
    g.blob(C, 34, 15, 12, shell)
    for k in range(4):  # 얼음 가시 등
        g.spike(C - 9 + k * 6, 30, C - 9 + k * 6, 24, 1.8, ramp((230, 245, 255)))
    crown(g, C, 21, 10)
    for side in (-1, 1):
        g.eye(C + side * 5, 27, 1.5, K)
    return g.outline(OUT)


# ---------- 화산 ----------
def lava_tortoise(f):
    g = Can(N)
    shell, skin, lava = ramp((70, 60, 64)), ramp((140, 100, 70)), ramp((255, 120, 30))
    step = 3 if f else -3
    for sx, sy in ((-1, -1), (1, -1), (-1, 1), (1, 1)):
        g.blob(C + sx * 15, 32 + sy * 11 + (step if sx * sy > 0 else -step) * 0.5, 4.5, 4, skin)
    g.blob(C, 12, 6, 6, skin)
    g.blob(C, 32, 17, 18, shell)
    for (x0, y0, x1, y1) in ((-8, 22, 0, 28), (0, 28, 8, 22), (-10, 36, 0, 30), (0, 30, 10, 38), (0, 30, 0, 42)):
        g.line(C + x0, y0, C + x1, y1, lava[3])
    for side in (-1, 1):
        g.eye(C + side * 3, 10, 1.2, lava[4])
    g.put(C, 31, lava[4])
    return g.outline(OUT)


def flame_eel(f):
    g = Can(N)
    body, fire = ramp((220, 90, 40)), ramp((255, 200, 60))
    ph = 1.4 if f else 0
    pts = [(C + math.sin(k / 30 * 7 + ph) * 12 * (0.3 + 0.7 * k / 30), 12 + k * 1.6) for k in range(31)]
    g.chain(pts, [5 - 3.4 * k / 30 for k in range(31)], body)
    for k in range(2, 30, 2):  # 불꽃 등지느러미
        x, y = pts[k]
        g.spike(x, y, x + math.sin(k + ph) * 2, y - 4, 1.4, fire)
    hx, hy = pts[0]
    g.blob(hx, hy - 2, 5.5, 6, body)
    for side in (-1, 1):
        g.eye(hx + side * 2.5, hy - 3, 1.2, fire[4])
    return g.outline(OUT)


def lava_slime(f):
    g = Can(N)
    jelly = [(150, 40, 20, 235), (200, 70, 30, 230), (240, 120, 40, 225), (255, 170, 70, 220), (255, 220, 140, 230)]
    wob = 2.5 if f else -2.5
    g.blob(C, 40, 26 + wob, 18 - wob * 0.6, jelly, sep=False)
    g.blob(C, 42, 9, 7, [(90, 20, 10, 235), (130, 30, 15, 235)], sep=False)
    for (dx, dy) in ((-14, 44), (12, 48), (4, 34)):
        g.blob(C + dx, dy, 2.6, 2, ramp((60, 50, 56)), sep=False)  # 돌덩이
    for side in (-1, 1):
        g.blob(C + side * 7, 34, 3, 3.6, None, flat=(40, 10, 10), sep=False)
        g.put(C + side * 7 - 1, 33, (255, 230, 160))
    for k in range(5):  # 끓는 거품
        g.blob(C - 12 + k * 6, 24 - (k % 2) * 3 + (1 if f else 0), 1.6, 1.6, ramp((255, 200, 80)), sep=False)
    return g.outline(OUT)


# ---------- 심해 ----------
def angler_king(f):
    g = Can(N)
    body = ramp((70, 60, 100))
    glow = (150, 255, 220)
    sw = 3 if f else -3
    g.chain([(C, 42), (C + sw, 54)], [7, 3], body)
    g.blob(C + sw, 57, 6, 2.4, body)
    for side in (-1, 1):
        g.blob(C + side * 14, 34, 6, 3, body, ang=side * 0.6)
    g.blob(C, 32, 15, 15, body)
    g.blob(C, 22, 12, 6, ramp((40, 30, 60)))  # 큰 입
    for k in range(7):
        g.spike(C - 9 + k * 3, 20, C - 9 + k * 3, 24, 1, ramp((240, 240, 230)))
    g.line(C, 18, C + 2, 6, body[1])  # 초롱 줄
    g.blob(C + 3, 5, 3, 3, None, flat=glow, sep=False)
    g.blob(C + 3, 5, 5, 5, None, flat=(150, 255, 220, 90), sep=False)
    crown(g, C, 13, 8)
    for side in (-1, 1):
        g.eye(C + side * 8, 28, 1.8, (250, 230, 120))
    return g.outline(OUT)


def deep_octopus(f):
    g = Can(N)
    body, spot = ramp((60, 90, 170)), (150, 230, 255)
    for i in range(8):
        a = i * math.pi / 4 + math.pi / 8
        pts = [(C + math.cos(a + math.sin(k * 0.4 + i + (1.5 if f else 0)) * 0.35) * (9 + k * 2.5), 32 + math.sin(a + math.sin(k * 0.4 + i + (1.5 if f else 0)) * 0.35) * (9 + k * 2.5)) for k in range(9)]
        g.chain(pts, [3 - k * 0.27 for k in range(9)], body)
    g.blob(C, 28, 11, 13, body)
    for (dx, dy) in ((-5, 22), (4, 24), (0, 18), (-3, 30), (5, 31)):
        g.put(C + dx, dy, spot)
    for side in (-1, 1):
        g.eye(C + side * 5, 32, 2, (250, 200, 60))
    return g.outline(OUT)


def phantom_jelly(f):
    g = Can(N)
    bell = [(60, 160, 150, 170), (90, 200, 190, 165), (140, 235, 220, 160), (200, 255, 245, 160), (240, 255, 250, 180)]
    for i in range(6):
        pts = [(C - 10 + i * 4 + math.sin(k * 0.6 + i + (1.3 if f else 0)) * 2.4, 30 + k * 3) for k in range(9)]
        g.chain(pts, [1.6 - k * 0.1 for k in range(9)], [(120, 230, 210, 140), (170, 250, 235, 140), (220, 255, 250, 150)])
    g.blob(C, 26, 15, 12, bell, sep=False)
    for side in (-1, 1):
        g.blob(C + side * 5, 25, 2.2, 3, None, flat=(20, 50, 60, 220), sep=False)
    g.line(C - 3, 31, C + 3, 31, (20, 50, 60, 220))
    return g.outline(OUT)


# ---------- 유령 ----------
def skeleton_captain(f):
    g = Can(N)
    bone, coat, hat = ramp((230, 225, 205)), ramp((80, 40, 60)), ramp((40, 32, 48))
    arm = 3 if f else -2
    g.line(C + 12, 30, C + 22, 20 + arm, (210, 215, 225), w=1.6)  # 칼
    g.chain([(C + 9, 32), (C + 13, 30)], [2, 1.6], bone)
    g.chain([(C - 9, 32), (C - 14, 38 - arm)], [2, 1.6], bone)
    g.blob(C, 36, 11, 10, coat)
    for k in range(3):  # 갈비뼈
        g.line(C - 5, 32 + k * 3, C + 5, 32 + k * 3, bone[3])
    g.blob(C, 22, 8, 8, bone)
    for side in (-1, 1):
        g.blob(C + side * 3, 21, 2, 2.2, None, flat=K, sep=False)
        g.put(C + side * 3, 21, (140, 255, 170))
    g.poly([(C - 14, 18), (C + 14, 18), (C, 6)], None, hat)  # 삼각 모자
    g.line(C - 12, 18, C + 12, 18, GOLD[2])
    g.blob(C, 13, 2, 2, None, flat=W, sep=False)
    return g.outline(OUT)


def cursegull_leader(f):
    g = Can(N)
    feather, dark = ramp((150, 110, 170)), ramp((80, 50, 100))
    flap = 4 if f else -2
    for side in (-1, 1):
        g.poly([(C + side * 4, 26), (C + side * 30, 22 + flap), (C + side * 26, 32 + flap), (C + side * 6, 36)], None, feather)
        for k in range(4):
            g.line(C + side * (10 + k * 5), 28 + flap * k / 4, C + side * (12 + k * 5), 34 + flap * k / 4, dark[0])
    g.blob(C, 32, 6, 13, feather)
    g.poly([(C - 5, 44), (C + 5, 44), (C, 54)], None, dark)
    g.blob(C, 18, 5, 5, feather, lift=0.05)
    g.spike(C, 14, C, 8, 1.8, ramp((240, 190, 60)))
    for side in (-1, 1):
        g.eye(C + side * 2.5, 17, 1.2, (255, 80, 200))
    crown(g, C, 12, 8)
    return g.outline(OUT)


def specter(f):
    g = Can(N)
    mist = [(70, 90, 140, 170), (110, 140, 200, 170), (160, 190, 240, 170), (210, 225, 255, 180), (245, 250, 255, 200)]
    for k in range(10):
        g.blob(C + math.sin(k * 0.9 + (1.4 if f else 0)) * 4, 34 + k * 2.6, 11 - k, 3, mist, sep=False)
    g.blob(C, 26, 13, 14, mist, sep=False)
    for side in (-1, 1):  # 팔
        g.chain([(C + side * 10, 28), (C + side * 20, 22 + (3 if f else 0)), (C + side * 24, 16)], [3, 2.4, 1.6], mist)
    for side in (-1, 1):
        g.blob(C + side * 5, 24, 2.6, 3.6, None, flat=(20, 20, 50, 230), sep=False)
        g.put(C + side * 5, 23, (140, 255, 240))
    g.blob(C, 32, 3, 2.2, None, flat=(20, 20, 50, 230), sep=False)
    return g.outline(OUT)


# ---------- 배·잠수함 ----------
SHIP_PALS = {
    "storm_raider": (dict(rim=(60, 66, 90), rim_d=(40, 44, 64), deck=(110, 116, 140), deck_l=(130, 136, 160), seam=(80, 86, 110),
                          sail=(40, 44, 70), sail_d=(28, 30, 50), sail_l=(70, 76, 110)), "bolt"),
    "frost_pirate": (dict(rim=(80, 120, 160), rim_d=(60, 96, 136), deck=(150, 190, 220), deck_l=(176, 210, 236), seam=(120, 160, 196),
                          sail=(70, 140, 200), sail_d=(50, 110, 170), sail_l=(120, 180, 230)), "flake"),
    "blaze_pirate": (dict(rim=(90, 30, 24), rim_d=(64, 20, 16), deck=(130, 70, 50), deck_l=(150, 86, 62), seam=(100, 50, 36),
                          sail=(40, 30, 30), sail_d=(26, 18, 18), sail_l=(70, 50, 46)), "flame"),
    "wraith_ship": (dict(rim=(40, 70, 64), rim_d=(28, 52, 48), deck=(70, 110, 100), deck_l=(90, 130, 118), seam=(50, 86, 78),
                         sail=(120, 210, 180), sail_d=(80, 170, 140), sail_l=(170, 240, 215), mast=(30, 44, 40), yard=(40, 60, 54)), "ghost"),
}


def ship(kind):
    pal, emblem = SHIP_PALS[kind]
    _tb.SHIPS[kind] = (_tb._pal(**pal), emblem)
    return lambda f: _tb.ship_boss(kind, 1 if f else 0)


def hunter_sub(f):
    px = _tb.deep_sub(f)
    swap = {(240, 196, 50): (170, 40, 40), (255, 230, 120): (220, 80, 70), (190, 140, 30): (110, 24, 28), (120, 220, 240): (255, 200, 80)}
    return [[swap.get(c, c) if c is not None else None for c in row] for row in px]


BOSSES = {
    "hermit_conch": hermit_conch, "jelly_queen": jelly_queen, "hammer_shark": hammer_shark,
    "storm_raider": ship("storm_raider"), "thunder_ray_pup": thunder_ray_pup, "great_serpent": great_serpent,
    "twister_dolphin": twister_dolphin,
    "frost_pirate": ship("frost_pirate"), "seal_chief": seal_chief, "giant_squid": giant_squid, "icecrab_chief": icecrab_chief,
    "blaze_pirate": ship("blaze_pirate"), "lava_tortoise": lava_tortoise, "flame_eel": flame_eel, "lava_slime": lava_slime,
    "hunter_sub": hunter_sub, "angler_king": angler_king, "deep_octopus": deep_octopus, "phantom_jelly": phantom_jelly,
    "wraith_ship": ship("wraith_ship"), "skeleton_captain": skeleton_captain, "cursegull_leader": cursegull_leader,
    "specter": specter,
}


def files():
    out = {}
    for kind, make in BOSSES.items():
        a, b = make(False), make(True)
        out[f"bosses/td_{kind}.png"] = [ra + rb for ra, rb in zip(a, b)]
        out[f"bosses/{kind}.png"] = a
    return out


def main(argv: list[str]) -> int:
    for stream in (sys.stdout, sys.stderr):
        stream.reconfigure(encoding="utf-8")
    check = "--check" in argv
    changed = []
    made = files()
    for rel, px in made.items():
        data = _b.write_png(px)
        target = ASSETS / rel
        if target.is_file() and target.read_bytes() == data:
            continue
        changed.append(rel)
        if not check:
            target.write_bytes(data)
    lic_path = ASSETS / "LICENSES.json"
    lic = json.loads(lic_path.read_text(encoding="utf-8"))
    lic_files = dict(lic.get("files", {}))
    for rel in made:
        lic_files[rel] = {"source": SOURCE, "license": "OWN"}
    text = json.dumps({**lic, "files": dict(sorted(lic_files.items()))}, ensure_ascii=False, indent=2) + "\n"
    if lic_path.read_text(encoding="utf-8") != text:
        changed.append("LICENSES.json")
        if not check:
            lic_path.write_text(text, encoding="utf-8", newline="\n")
    if check:
        if changed:
            print("✗ 다시 굽기 결과가 다름: " + ", ".join(changed), file=sys.stderr)
            return 1
        print("✓ 보통 보스가 격자와 같다")
        return 0
    print(f"✓ {len(changed)}개 갱신 ({len(BOSSES)}종)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
