"""입체 음영 도트 캔버스 — 대보스(gen_topdown_bigbosses.py)용. 같은 입력이면 같은 픽셀.

빛은 왼쪽 위 앞에서. 타원 덩어리(blob)는 법선으로 밝기를 구해 색 사다리(ramp)의 칸을 4×4 바이어 디더로 고른다.
덩어리끼리 겹친 경계에는 사다리 가장 어두운 색으로 한 줄(부위 구분), 바깥 외곽선은 게임 공통 OUTLINE.
"""

from __future__ import annotations

import colorsys
import math

BAYER = ((0, 8, 2, 10), (12, 4, 14, 6), (3, 11, 1, 9), (15, 7, 13, 5))
LIGHT = (-0.48, -0.62, 0.62)
_ln = math.sqrt(sum(v * v for v in LIGHT))
LIGHT = tuple(v / _ln for v in LIGHT)


def ramp(base, n=5, spread=0.42):
    """기준 색 하나로 어둠→밝음 n단. 어두운 쪽은 푸른 보라로, 밝은 쪽은 노랑으로 색상을 민다(도트 관례)."""
    r, g, b = (v / 255 for v in base[:3])
    h, l, s = colorsys.rgb_to_hls(r, g, b)
    out = []
    for i in range(n):
        t = i / (n - 1) - 0.5  # -0.5 … 0.5
        hh = h + (-0.06 if t < 0 else -0.03) * t * 2 * (1 if 0.1 < h < 0.75 else -1)
        ll = min(0.94, max(0.06, l + t * spread * 2 * (0.9 if t > 0 else 1)))
        ss = min(1, max(0, s * (1 + 0.15 * -abs(t))))
        rr, gg, bb = colorsys.hls_to_rgb(hh % 1, ll, ss)
        out.append((round(rr * 255), round(gg * 255), round(bb * 255)))
    return out


def mix(a, b, t):
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


class Can:
    def __init__(self, w, h=None):
        self.w, self.h = w, h or w
        self.px = [[None] * self.w for _ in range(self.h)]

    # ---- 기본 ----
    def put(self, x, y, c):
        x, y = int(math.floor(x)), int(math.floor(y))
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[y][x] = c

    def get(self, x, y):
        return self.px[y][x] if 0 <= x < self.w and 0 <= y < self.h else None

    def _shade(self, x, y, b, rmp):
        """밝기 b(0~1) → 사다리 칸(디더)."""
        f = max(0.0, min(0.999, b)) * (len(rmp) - 1)
        i = int(f)
        frac = f - i
        if frac * 16 > BAYER[y % 4][x % 4] + 0.5 and i + 1 < len(rmp):
            i += 1
        return rmp[i]

    def blob(self, cx, cy, rx, ry, rmp, ang=0.0, sep=True, flat=None, lift=0.0):
        """회전 타원 덩어리. ang 라디안(0 = 세로 축 그대로). sep이면 이미 칠한 곳과 닿는 테두리를 가장 어두운 색으로.
        flat이 있으면 음영 없이 그 색. lift는 밝기 올림(-1~1)."""
        ca, sa = math.cos(ang), math.sin(ang)
        r = max(rx, ry) + 1
        mine = []
        for y in range(max(0, int(cy - r)), min(self.h, int(cy + r) + 1)):
            for x in range(max(0, int(cx - r)), min(self.w, int(cx + r) + 1)):
                dx, dy = x + 0.5 - cx, y + 0.5 - cy
                u = (dx * ca + dy * sa) / rx
                v = (-dx * sa + dy * ca) / ry
                d = u * u + v * v
                if d > 1:
                    continue
                if flat is not None:
                    c = flat
                else:
                    nz = math.sqrt(1 - d)
                    nx, ny = u * ca - v * sa, u * sa + v * ca
                    b = nx * LIGHT[0] + ny * LIGHT[1] + nz * LIGHT[2]
                    b = (b + 0.35) / 1.3 + lift
                    if d > 0.82:
                        b -= 0.18  # 가장자리 그늘
                    c = self._shade(x, y, b, rmp)
                mine.append((x, y, c))
        inside = {(x, y) for x, y, _ in mine}
        for x, y, c in mine:
            if sep and flat is None:
                for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                    if (nx, ny) not in inside and self.get(nx, ny) is not None:
                        c = rmp[0]
                        break
            self.px[y][x] = c
        return inside

    def chain(self, pts, radii, rmp, sep=False, lift=0.0):
        """점 줄을 따라 덩어리를 겹쳐 굵기가 변하는 몸(꼬리·촉수·뱀 몸). 뒤(끝)부터 칠해 앞이 위로.
        점 사이가 반지름보다 멀면 촘촘히 채운다(팔다리가 끊겨 보이지 않게)."""
        dense_p, dense_r = [pts[0]], [radii[0]]
        for (x0, y0), (x1, y1), r0, r1 in zip(pts, pts[1:], radii, radii[1:]):
            n = max(1, int(math.hypot(x1 - x0, y1 - y0) / max(0.8, min(r0, r1) * 0.6)))
            for k in range(1, n + 1):
                t = k / n
                dense_p.append((x0 + (x1 - x0) * t, y0 + (y1 - y0) * t))
                dense_r.append(r0 + (r1 - r0) * t)
        pts, radii = dense_p, dense_r
        for i in range(len(pts) - 1, -1, -1):
            x, y = pts[i]
            r = radii[i]
            self.blob(x, y, r, r, rmp, sep=sep and i % 6 == 0, lift=lift)

    def poly(self, pts, c, rmp=None):
        """다각형 채우기 — rmp가 있으면 위→아래로 밝음→어둠 (디더)."""
        ys = [p[1] for p in pts]
        y0, y1 = min(ys), max(ys)
        for y in range(max(0, int(y0)), min(self.h, int(y1) + 1)):
            for x in range(self.w):
                if _inside(x + 0.5, y + 0.5, pts):
                    if rmp:
                        t = 1 - (y + 0.5 - y0) / max(1, y1 - y0)
                        self.px[y][x] = self._shade(x, y, 0.15 + t * 0.8, rmp)
                    else:
                        self.px[y][x] = c

    def line(self, x0, y0, x1, y1, c, w=1.0):
        n = int(max(abs(x1 - x0), abs(y1 - y0)) * 2) + 1
        for i in range(n + 1):
            t = i / n
            x, y = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
            if w <= 1:
                self.put(x, y, c)
            else:
                rr = w / 2
                for yy in range(int(y - rr), int(y + rr) + 1):
                    for xx in range(int(x - rr), int(x + rr) + 1):
                        if (xx + 0.5 - x) ** 2 + (yy + 0.5 - y) ** 2 <= rr * rr:
                            self.put(xx, yy, c)

    def spike(self, bx, by, tx, ty, half, rmp):
        """밑변 가운데 (bx,by), 끝 (tx,ty), 밑변 반폭 half인 가시 — 왼쪽 면 밝게."""
        dx, dy = tx - bx, ty - by
        ln = math.hypot(dx, dy) or 1
        px_, py_ = -dy / ln * half, dx / ln * half
        self.poly([(bx + px_, by + py_), (tx, ty), (bx - px_, by - py_)], rmp[1])
        self.poly([(bx + px_ * (1 if px_ < 0 else 0), by + py_ * (1 if px_ < 0 else 0)), (tx, ty), (bx, by)], rmp[3])

    def eye(self, x, y, r, iris, glow=None):
        """빛나는 눈: 바깥 iris, 세로 동공, 왼쪽 위 반짝."""
        if glow:
            self.blob(x, y, r + 1.2, r + 1.2, None, flat=glow, sep=False)
        self.blob(x, y, r, r, None, flat=iris, sep=False)
        self.line(x, y - r + 0.8, x, y + r - 0.8, (20, 14, 26))
        self.put(x - r * 0.45, y - r * 0.45, (255, 255, 240))

    def outline(self, color):
        marks = []
        for y in range(self.h):
            for x in range(self.w):
                if self.px[y][x] is not None:
                    continue
                for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                    c = self.get(nx, ny)
                    if c is not None and c != color and (len(c) < 4 or c[3] > 160):
                        marks.append((x, y))
                        break
        for x, y in marks:
            self.px[y][x] = color
        return self.px


def _inside(x, y, pts):
    inside = False
    j = len(pts) - 1
    for i in range(len(pts)):
        xi, yi = pts[i]
        xj, yj = pts[j]
        if (yi > y) != (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi) + xi:
            inside = not inside
        j = i
    return inside
