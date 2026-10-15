"""탑다운 적 27종 (T2, 사용자 결정 '탑다운 전환'). 위에서 내려다본 도트, 머리가 위(렌더가 진행 방향으로 돌린다). OWN.

    python -I tools/art/gen_topdown_enemies.py            # apps/game/assets/enemies/td_<kind>.png 에 쓴다
    python -I tools/art/gen_topdown_enemies.py --check    # 쓰지 않고, 결과가 지금 파일과 다르면 실패

옆모습 적(assets/enemies/<kind>.png)과 같은 색·특징을 위에서 본 모양으로: 게(집게·다리), 해파리(종 + 뒤로 끌리는 촉수),
물고기(몸·꼬리·지느러미), 갈매기(펼친 날개), 펭귄·물개·거북·오징어·불가사리·성게·해골·유령. 프레임 2장(헤엄·날갯짓),
크기 = 일반 16도트 칸(몸 약 12, 전장 반경 6), 작은 변종 12칸. 굵은 외곽선. 같은 입력이면 같은 바이트.
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
SOURCE = "Pirate Busters v0.24 자체 IP(적 디자인) → tools/art/gen_topdown_enemies.py 위에서 본 픽셀 격자"

_spec = importlib.util.spec_from_file_location("gen_bosses", HERE / "gen_bosses.py")
_b = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_b)

K = (27, 23, 38)
W = (245, 245, 250)


class Grid:
    def __init__(self, n: int):
        self.n = n
        self.px = [[None] * n for _ in range(n)]

    def put(self, x, y, c):
        x, y = int(math.floor(x)), int(math.floor(y))
        if 0 <= x < self.n and 0 <= y < self.n:
            self.px[y][x] = c

    def ellipse(self, cx, cy, rx, ry, c, c2=None):
        """채운 타원 (c2가 있으면 위쪽 절반을 밝게)."""
        for y in range(self.n):
            for x in range(self.n):
                dx, dy = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
                if dx * dx + dy * dy <= 1:
                    self.px[y][x] = c2 if c2 and dy < -0.25 and dx < 0.3 else c

    def line(self, x0, y0, x1, y1, c):
        n = int(max(abs(x1 - x0), abs(y1 - y0)) * 2) + 1
        for i in range(n + 1):
            t = i / n
            self.put(x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, c)

    def poly(self, pts, c):
        for y in range(self.n):
            for x in range(self.n):
                if _in(x + 0.5, y + 0.5, pts):
                    self.px[y][x] = c

    def done(self):
        _b.outline(self.px)
        return self.px


def _in(x, y, pts):
    inside = False
    j = len(pts) - 1
    for i in range(len(pts)):
        xi, yi = pts[i]
        xj, yj = pts[j]
        if (yi > y) != (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi) + xi:
            inside = not inside
        j = i
    return inside


# ---------- 모양 ----------
def crab(n, body, dark, f, extra=None):
    g = Grid(n)
    c = n / 2
    s = n / 16
    leg = 1 if f else -1
    for side in (-1, 1):
        for i in range(3):  # 다리 셋
            y = c + (i - 0.5) * 2.2 * s
            g.line(c + side * 4 * s, y, c + side * 7 * s, y + leg * (0.8 + i * 0.3) * s, dark)
        # 집게(앞, 벌렸다 오므림)
        cx, cy = c + side * 4.2 * s, c - 5.2 * s
        g.ellipse(cx, cy, 2.1 * s, 1.8 * s, body)
        g.put(cx + side * (0.5 if f else 1.2) * s, cy - 1.6 * s, None)
    g.ellipse(c, c + 0.4 * s, 4.6 * s, 3.6 * s, body, extra.get("hi") if extra else None)
    for side in (-1, 1):  # 눈자루: 몸 앞 테두리 위로 튀어나온 흰 눈 + 검은 눈동자
        g.ellipse(c + side * 1.6 * s, c - 3.6 * s, 0.9 * s, 0.9 * s, W)
        g.put(c + side * 1.6 * s, c - 3.4 * s, K)
    if extra and extra.get("mark"):
        mk, col = extra["mark"], extra["markc"]
        for dx, dy in mk:
            g.put(c + dx * s, c + dy * s, col)
    return g.done()


def jelly(n, bell, light, f, ghost=False):
    g = Grid(n)
    c = n / 2
    s = n / 16
    r = (4.6 if f else 5.2) * s
    for i in range(5):  # 뒤로 끌리는 촉수
        x0 = c + (i - 2) * 1.7 * s
        for k in range(6):
            wob = math.sin(k * 1.1 + i + (1.5 if f else 0)) * 0.9 * s
            g.put(x0 + wob, c + r * 0.6 + k * s, light if k % 2 else bell)
    g.ellipse(c, c - 1.2 * s, r, r * 0.95, bell)
    g.ellipse(c, c - 1.6 * s, r * 0.55, r * 0.5, light)
    if ghost:
        for side in (-1, 1):
            g.put(c + side * 1.6 * s, c - 1.4 * s, K)
    else:
        for a in range(4):
            ang = a * math.pi / 2 + 0.6
            g.put(c + math.cos(ang) * r * 0.75, c - 1.2 * s + math.sin(ang) * r * 0.75, W)
    return g.done()


def fish(n, body, belly, fin, f, length=1.0, width=1.0, wings=False, lure=None, spiky=False):
    g = Grid(n)
    c = n / 2
    s = n / 16
    sway = (0.9 if f else -0.9) * s
    # 꼬리(뒤, 흔들림)
    g.poly([(c + sway - 2.6 * s, c + 7.6 * s * length), (c + sway + 2.6 * s, c + 7.6 * s * length),
            (c + sway * 0.5, c + 4.2 * s * length)], fin)
    if wings:  # 날치: 옆으로 펼친 긴 가슴지느러미
        span = 7.6 if f else 6.6
        for side in (-1, 1):
            g.poly([(c + side * 1.5 * s, c - 1.0 * s), (c + side * span * s, c + 0.5 * s),
                    (c + side * 1.5 * s, c + 2.6 * s)], fin)
    else:
        for side in (-1, 1):
            g.poly([(c + side * 2.4 * s * width, c), (c + side * 4.6 * s * width, c + 1.6 * s),
                    (c + side * 2.4 * s * width, c + 2.2 * s)], fin)
    g.ellipse(c, c - 0.6 * s, 3.2 * s * width, 5.6 * s * length, body, belly)
    for side in (-1, 1):
        g.put(c + side * 1.6 * s * width, c - 4.0 * s * length, W)
    if lure:  # 아귀: 앞으로 뻗은 등불
        g.line(c, c - 5.6 * s * length, c + 1.2 * s, c - 7.4 * s, K)
        g.ellipse(c + 1.2 * s, c - 7.6 * s, 1.1 * s, 1.1 * s, lure)
    if spiky:
        for a in range(10):
            ang = a * math.pi / 5 + (0.3 if f else 0)
            g.put(c + math.cos(ang) * 6.2 * s, c - 0.4 * s + math.sin(ang) * 6.2 * s, fin)
    return g.done()


def eel(n, body, belly, f):
    g = Grid(n)
    c = n / 2
    s = n / 16
    ph = 0 if f else math.pi
    for k in range(26):
        t = k / 25
        y = c - 6.8 * s + t * 14 * s
        x = c + math.sin(t * 5 + ph) * 2.2 * s * t
        rad = (2.8 - 1.4 * t) * s
        g.ellipse(x, y, rad, rad, body if k > 3 else belly)
    g.put(c - 0.7 * s, c - 6.2 * s, W)
    g.put(c + 0.7 * s, c - 6.2 * s, W)
    return g.done()


def bird(n, body, wing, tip, f, beak=(250, 170, 60), flame=None):
    g = Grid(n)
    c = n / 2
    s = n / 16
    span = 7.6 if f else 5.4
    lift = -1.2 if f else 1.4
    for side in (-1, 1):
        g.poly([(c + side * 1.2 * s, c - 1.6 * s), (c + side * span * s, c + lift * s),
                (c + side * (span - 1.4) * s, c + (lift + 1.8) * s), (c + side * 1.2 * s, c + 1.8 * s)], wing)
        g.line(c + side * (span - 1.6) * s, c + (lift + 0.4) * s, c + side * span * s, c + lift * s, tip)
    g.poly([(c - 1.6 * s, c + 3.6 * s), (c + 1.6 * s, c + 3.6 * s), (c, c + 6.2 * s)], tip)  # 꽁지
    g.ellipse(c, c, 1.9 * s, 3.8 * s, body)
    g.ellipse(c, c - 3.4 * s, 1.5 * s, 1.5 * s, body)
    g.put(c, c - 5.2 * s, beak)
    g.put(c, c - 5.8 * s, beak)
    if flame:
        for k in range(4):
            g.put(c + (k % 2 - 0.5) * 1.4 * s, c + (6.6 + k * 0.8) * s, flame if (k + (1 if f else 0)) % 2 else beak)
    return g.done()


def penguin(n, f):
    g = Grid(n)
    c = n / 2
    s = n / 16
    fl = 0.8 if f else -0.8
    for side in (-1, 1):
        g.poly([(c + side * 3.4 * s, c - 1.0 * s), (c + side * 6.0 * s, c + (2.6 + fl) * s), (c + side * 3.4 * s, c + 3.0 * s)],
               (40, 40, 56))
    g.ellipse(c, c + 0.6 * s, 4.0 * s, 5.8 * s, (40, 40, 56), (70, 70, 92))
    g.ellipse(c, c - 3.8 * s, 2.6 * s, 2.2 * s, (40, 40, 56))
    g.put(c - 1.0 * s, c - 4.2 * s, W)
    g.put(c + 1.0 * s, c - 4.2 * s, W)
    g.put(c, c - 6.2 * s, (250, 170, 60))
    for side in (-1, 1):
        g.put(c + side * 1.8 * s, c + 6.2 * s, (250, 170, 60))
    return g.done()


def seal(n, f):
    g = Grid(n)
    c = n / 2
    s = n / 16
    body, hi = (130, 136, 150), (170, 176, 190)
    fl = 0.7 if f else -0.7
    for side in (-1, 1):
        g.poly([(c + side * 3.0 * s, c), (c + side * 5.8 * s, c + (1.6 + fl) * s), (c + side * 3.0 * s, c + 2.4 * s)], body)
    g.poly([(c - 2.6 * s, c + 7.6 * s), (c + 2.6 * s, c + 7.6 * s), (c, c + 4.6 * s)], body)
    g.ellipse(c, c + 0.6 * s, 3.4 * s, 5.4 * s, body, hi)
    g.ellipse(c, c - 4.4 * s, 2.4 * s, 2.0 * s, body, hi)
    g.put(c - 1.0 * s, c - 4.8 * s, K)
    g.put(c + 1.0 * s, c - 4.8 * s, K)
    for side in (-1, 1):
        g.put(c + side * 2.6 * s, c - 5.6 * s, W)
    return g.done()


def squid(n, f):
    g = Grid(n)
    c = n / 2
    s = n / 16
    body, hi, dark = (220, 110, 150), (250, 160, 190), (170, 70, 110)
    for i in range(6):
        x0 = c + (i - 2.5) * 1.1 * s
        for k in range(5):
            g.put(x0 + math.sin(k + i + (1 if f else 0)) * 0.6 * s, c + 2.4 * s + k * s, dark)
    g.ellipse(c, c - 1.6 * s, 2.8 * s, 5.0 * s, body, hi)
    g.poly([(c - 3.8 * s, c - 5.2 * s), (c + 3.8 * s, c - 5.2 * s), (c, c - 7.8 * s)], body)
    for side in (-1, 1):
        g.put(c + side * 1.6 * s, c + 1.6 * s, W)
    return g.done()


def star(n, body, hi, f):
    g = Grid(n)
    c = n / 2
    s = n / 16
    rot = (0.18 if f else 0) - math.pi / 2
    pts = []
    for i in range(10):
        r = (7.2 if i % 2 == 0 else 3.0) * s
        a = rot + i * math.pi / 5
        pts.append((c + math.cos(a) * r, c + math.sin(a) * r))
    g.poly(pts, body)
    g.ellipse(c, c, 2.2 * s, 2.2 * s, hi)
    for i in range(5):
        a = rot + i * 2 * math.pi / 5
        g.put(c + math.cos(a) * 4.4 * s, c + math.sin(a) * 4.4 * s, hi)
    return g.done()


def urchin(n, f):
    g = Grid(n)
    c = n / 2
    s = n / 16
    body, spike = (150, 80, 190), (90, 40, 130)
    for a in range(12):
        ang = a * math.pi / 6 + (math.pi / 12 if f else 0)
        g.line(c + math.cos(ang) * 3.6 * s, c + math.sin(ang) * 3.6 * s, c + math.cos(ang) * 7.2 * s,
               c + math.sin(ang) * 7.2 * s, spike)
    g.ellipse(c, c, 4.2 * s, 4.2 * s, body, (190, 120, 230))
    g.put(c - 1.2 * s, c - 0.8 * s, W)
    g.put(c + 1.2 * s, c - 0.8 * s, W)
    return g.done()


def turtle(n, f):
    g = Grid(n)
    c = n / 2
    s = n / 16
    shell, plate, lava, skin = (70, 60, 58), (100, 88, 80), (255, 120, 40), (120, 96, 70)
    fl = 0.8 if f else -0.8
    for sx, sy in ((-1, -1), (1, -1), (-1, 1), (1, 1)):
        g.ellipse(c + sx * 4.8 * s, c + sy * (3.4 + (fl if sy < 0 else -fl) * 0.5) * s, 1.8 * s, 1.3 * s, skin)
    g.ellipse(c, c - 6.0 * s, 1.8 * s, 1.8 * s, skin)
    g.ellipse(c, c, 4.8 * s, 5.6 * s, shell)
    for dx, dy in ((0, -2.4), (-2.2, 0), (2.2, 0), (0, 2.4), (0, 0)):
        g.ellipse(c + dx * s, c + dy * s, 1.3 * s, 1.3 * s, plate)
    for dx, dy in ((-1.1, -1.2), (1.1, 1.2), (1.1, -1.2), (-1.1, 1.2)):
        g.put(c + dx * s, c + dy * s, lava if (f or dx > 0) else (255, 200, 80))
    g.put(c - 0.6 * s, c - 6.6 * s, K)
    g.put(c + 0.6 * s, c - 6.6 * s, K)
    return g.done()


def skeleton(n, f):
    g = Grid(n)
    c = n / 2
    s = n / 16
    bone, dark = (236, 228, 204), (150, 140, 120)
    arm = 1.2 if f else -0.6
    for side in (-1, 1):
        g.line(c + side * 1.6 * s, c - 1.6 * s, c + side * 5.6 * s, c + arm * s, bone)
        g.line(c + side * 1.0 * s, c + 3.0 * s, c + side * 2.6 * s, c + 7.0 * s, bone)
    for k in range(4):  # 갈비
        g.line(c - 2.0 * s, c - 1.0 * s + k * 1.1 * s, c + 2.0 * s, c - 1.0 * s + k * 1.1 * s, bone if k % 2 == 0 else dark)
    g.line(c, c - 2.0 * s, c, c + 3.4 * s, bone)
    g.ellipse(c, c - 4.6 * s, 2.6 * s, 2.4 * s, bone)
    g.put(c - 1.0 * s, c - 4.6 * s, K)
    g.put(c + 1.0 * s, c - 4.6 * s, K)
    g.put(c + 3.0 * s, c - 6.2 * s, (220, 70, 60))  # 두건 꼬리
    return g.done()


def wraith(n, f):
    g = Grid(n)
    c = n / 2
    s = n / 16
    body, hi = (170, 236, 220), (215, 252, 244)
    for k in range(7):  # 흐느적 꼬리
        x = c + math.sin(k * 0.9 + (1.4 if f else 0)) * 1.6 * s
        g.ellipse(x, c + 2.4 * s + k * 0.8 * s, (2.6 - k * 0.3) * s, 1.0 * s, body)
    g.ellipse(c, c - 1.6 * s, 4.4 * s, 4.6 * s, body, hi)
    for side in (-1, 1):
        g.ellipse(c + side * 1.7 * s, c - 2.0 * s, 0.9 * s, 1.2 * s, K)
        g.put(c + side * 1.7 * s, c - 2.2 * s, (120, 255, 200))
    return g.done()


def siphon(n, f):
    """수정 물고기(청록 결정 몸, 각진 지느러미)."""
    g = Grid(n)
    c = n / 2
    s = n / 16
    body, hi, fin = (120, 220, 230), (200, 250, 255), (60, 160, 190)
    sway = 0.8 * s if f else -0.8 * s
    g.poly([(c + sway - 2.4 * s, c + 7.4 * s), (c + sway + 2.4 * s, c + 7.4 * s), (c, c + 3.6 * s)], fin)
    g.poly([(c, c - 7.2 * s), (c + 3.4 * s, c - 0.6 * s), (c, c + 4.4 * s), (c - 3.4 * s, c - 0.6 * s)], body)
    g.poly([(c, c - 5.6 * s), (c + 1.6 * s, c - 1.0 * s), (c, c + 1.0 * s)], hi)
    for side in (-1, 1):
        g.poly([(c + side * 2.6 * s, c - 1.4 * s), (c + side * 5.6 * s, c + 1.6 * s), (c + side * 2.4 * s, c + 1.4 * s)], fin)
    return g.done()


RED, RED_D = (220, 70, 60), (150, 40, 40)
KINDS = {
    "crab": (16, lambda f: crab(16, RED, RED_D, f)),
    "icecrab": (16, lambda f: crab(16, (200, 230, 250), (120, 160, 200), f,
                                  {"hi": (240, 250, 255), "mark": [(-2, 0), (2, 0), (0, 2)], "markc": (90, 150, 220)})),
    "icecrab_small": (12, lambda f: crab(12, (200, 230, 250), (120, 160, 200), f, {"hi": (240, 250, 255)})),
    "lavacrab": (16, lambda f: crab(16, (70, 62, 64), (40, 36, 40), f,
                                   {"mark": [(-2, 1), (0, 0), (2, 1), (-1, 2), (1, 2)], "markc": (255, 130, 40)})),
    "lavacrab_small": (12, lambda f: crab(12, (70, 62, 64), (40, 36, 40), f,
                                         {"mark": [(0, 0), (-1, 1), (1, 1)], "markc": (255, 130, 40)})),
    "jelly": (16, lambda f: jelly(16, (240, 140, 200), (255, 200, 230), f)),
    "ghostjelly": (16, lambda f: jelly(16, (150, 236, 214), (210, 252, 240), f, ghost=True)),
    "piranha": (16, lambda f: fish(16, (70, 150, 70), (110, 190, 90), (50, 110, 50), f, width=1.15)),
    "flyingfish": (16, lambda f: fish(16, (70, 120, 200), (200, 220, 245), (150, 190, 240), f, length=0.95, wings=True)),
    "angler": (16, lambda f: fish(16, (96, 84, 130), (130, 116, 170), (70, 60, 100), f, width=1.35, lure=(255, 230, 120))),
    "puffer": (16, lambda f: fish(16, (240, 200, 70), (255, 236, 150), (200, 150, 40), f, length=0.75, width=1.6,
                                  spiky=True)),
    "eel": (16, lambda f: eel(16, (60, 150, 120), (110, 200, 160), f)),
    "siphon": (16, lambda f: siphon(16, f)),
    "gull": (16, lambda f: bird(16, (240, 240, 245), (225, 228, 235), (60, 60, 70), f)),
    "cursegull": (16, lambda f: bird(16, (150, 200, 120), (120, 180, 100), (60, 90, 50), f, beak=(200, 230, 90))),
    "snowgull": (16, lambda f: bird(16, (235, 245, 255), (210, 230, 250), (120, 160, 210), f)),
    "stormgull": (16, lambda f: bird(16, (150, 156, 170), (120, 126, 142), (60, 64, 80), f, beak=(250, 230, 90))),
    "firebird": (16, lambda f: bird(16, (250, 190, 60), (250, 150, 40), (220, 70, 40), f, beak=(255, 236, 140),
                                    flame=(255, 90, 40))),
    "penguin": (16, lambda f: penguin(16, f)),
    "seal": (16, lambda f: seal(16, f)),
    "squid": (16, lambda f: squid(16, f)),
    "starfish": (16, lambda f: star(16, (240, 160, 70), (255, 210, 120), f)),
    "starfish_small": (12, lambda f: star(12, (240, 160, 70), (255, 210, 120), f)),
    "urchin": (16, lambda f: urchin(16, f)),
    "lavaturtle": (16, lambda f: turtle(16, f)),
    "skeleton": (16, lambda f: skeleton(16, f)),
    "wraith": (16, lambda f: wraith(16, f)),
}


def files():
    out = {}
    for kind, (n, make) in KINDS.items():
        a, b = make(False), make(True)
        out[f"enemies/td_{kind}.png"] = [ra + rb for ra, rb in zip(a, b)]
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
        print("✓ 탑다운 적이 격자와 같다")
        return 0
    print(f"✓ {len(changed)}개 갱신 ({len(made)}종)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
