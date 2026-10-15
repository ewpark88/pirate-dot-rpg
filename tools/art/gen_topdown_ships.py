"""탑다운 내 배 (사용자 결정 '탑다운 전환, 배는 가운데·크게 — 외형이 바뀌면 알아보게', T2). 위에서 내려다본 도트, 뱃머리가 위. OWN.

    python -I tools/art/gen_topdown_ships.py            # apps/game/assets/ship/td_*.png 에 쓴다
    python -I tools/art/gen_topdown_ships.py --check    # 쓰지 않고, 결과가 지금 파일과 다르면 실패

등급(t1 dinghy · t2 sloop · t3 warship · t4 ghost)마다 같은 크기 프레임의 층 시트 6장 — 렌더가 이 순서로 겹친다:
  td_t<n>_base.png (1)       선체 테두리·갑판 판자·돛대 밑동·뱃머리 막대
  td_t<n>_hull.png (7)       쇠 징 → 쇠 띠 → 충각(뱃머리 쇠판) → 금 테 → 고물 문장 → 마호가니 갑판
  td_t<n>_cargo.png (7)      고물 갑판 위 통 → 통 둘 → 상자 → 상자 더미 → 보물상자 → 열린 금상자 → 금 더미
  td_t<n>_cannon.png (7)     옆으로 내민 포: 쇠 1쌍 → 2쌍 → 청동 → 청동 3쌍 → 강철 + 뱃머리 포 → 쌍포 → 금 용
  td_t<n>_sail.png (5)       돛(위에서 본 가로 활대 + 부푼 천): 기운 자국 → 깨끗 → 빨간 줄 → 해골 → 금 테
  td_t<n>_crowsnest.png (6)  큰 돛대 위 망루: 바구니 → 난간 → 깃발 → 망원경 → 등불 → 금
S24(화면 180도트, 1도트 ≈ 2.1dp)에서 t1 폭 약 50도트 ≈ 105dp. 디자인은 PB 배 모듈(망루·포문·화물)을 위에서 본 도트로 다시 그렸다.
환생 스킨은 렌더가 팔레트를 바꿔 쓴다(여기 색 표 그대로). 같은 입력이면 같은 바이트.
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
SOURCE = "Pirate Busters v0.24 자체 IP(배 모듈 디자인) → tools/art/gen_topdown_ships.py 위에서 본 픽셀 격자"

_spec = importlib.util.spec_from_file_location("gen_bosses", HERE / "gen_bosses.py")
_b = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_b)

K = (27, 23, 38)
RIM, RIM_D = (122, 76, 40), (92, 56, 30)
DECK, DECK_L, SEAM = (196, 146, 92), (214, 168, 112), (160, 112, 66)
MAST = (74, 48, 28)
SAIL, SAIL_D, SAIL_L = (240, 232, 210), (206, 194, 164), (252, 248, 236)
YARD = (96, 62, 34)
IRON, IRON_HI = (90, 96, 112), (174, 182, 196)
BRASS, BRASS_HI = (200, 150, 60), (246, 214, 130)
STEEL, STEEL_HI = (120, 132, 156), (214, 222, 236)
GOLD, GOLD_HI = (242, 201, 76), (255, 240, 170)
RED, WHITE, PATCH, PATCH_D = (214, 64, 56), (250, 250, 250), (218, 204, 168), (186, 170, 132)
WOOD, WOOD_D, WOOD_L = (150, 96, 52), (104, 64, 34), (196, 150, 96)
LAMP, LAMP_D = (255, 236, 140), (255, 180, 60)
MAHOG, MAHOG_D = (130, 60, 44), (98, 42, 32)
GHOST = {RIM: (78, 66, 92), RIM_D: (56, 46, 70), DECK: (104, 92, 120), DECK_L: (122, 110, 140), SEAM: (84, 72, 100),
         MAST: (44, 36, 56), YARD: (56, 46, 70), SAIL: (110, 220, 205), SAIL_D: (70, 170, 165), SAIL_L: (170, 245, 230),
         MAHOG: (72, 46, 112), MAHOG_D: (50, 30, 84)}

# 등급: 프레임 폭·높이, 선체 반폭, 선체 길이(위 여백 뒤), 돛대 자리(선체 길이 비율), 고물 선실, 유령
TIERS = {
    1: dict(w=56, h=96, hw=17, top=10, length=80, masts=[0.42], cabin=False, ghost=False, jib=False),
    2: dict(w=60, h=106, hw=18, top=12, length=88, masts=[0.30, 0.56], cabin=False, ghost=False, jib=True),
    3: dict(w=66, h=118, hw=20, top=12, length=100, masts=[0.24, 0.46, 0.66], cabin=True, ghost=False, jib=True),
    4: dict(w=66, h=118, hw=20, top=12, length=100, masts=[0.24, 0.46, 0.66], cabin=True, ghost=True, jib=True),
}
STAGES = {"hull": 7, "cargo": 7, "cannon": 7, "sail": 5, "crowsnest": 6}


class Ship:
    def __init__(self, n: int):
        t = TIERS[n]
        self.n, self.t = n, t
        self.w, self.h = t["w"], t["h"]
        self.cx = t["w"] // 2
        self.top, self.len, self.hw = t["top"], t["length"], t["hw"]
        self.bottom = self.top + self.len
        self.mast_y = [self.top + round(self.len * f) for f in t["masts"]]
        self.main = self.mast_y[-1] if len(self.mast_y) < 3 else self.mast_y[1]
        self.cargo_y = self.bottom - (22 if t["cabin"] else 14)

    def half(self, y: int) -> float:
        """선체 반폭: 뱃머리(위 35%)는 둥글게 뾰족, 가운데 꽉, 고물(아래 10%)은 조금 좁고 평평."""
        u = (y - self.top) / self.len
        if u < 0 or u > 1:
            return -1
        if u < 0.4:
            return self.hw * math.sin(math.pi / 2 * u / 0.4) ** 1.35
        if u > 0.9:
            return self.hw * (1 - (u - 0.9) * 1.4)
        return self.hw

    def inside(self, x: int, y: int) -> bool:
        return abs(x + 0.5 - self.cx) <= self.half(y)

    def blank(self):
        return [[None] * self.w for _ in range(self.h)]

    def color(self, c):
        return GHOST.get(c, c) if self.t["ghost"] else c


def put(px, x, y, c):
    if 0 <= y < len(px) and 0 <= x < len(px[0]):
        px[y][x] = c


def rect(px, x0, y0, w, h, c):
    for y in range(y0, y0 + h):
        for x in range(x0, x0 + w):
            put(px, x, y, c)


def art(px, x0, y0, rows: list[str], pal: dict):
    for dy, line in enumerate(rows):
        for dx, ch in enumerate(line):
            if ch in pal:
                put(px, x0 + dx, y0 + dy, pal[ch])


def outline(px):
    _b.outline(px)


# ---------- 바탕: 선체 테두리 + 갑판 판자 + 돛대 밑동 + 뱃머리 막대 ----------
def base(s: Ship):
    px = s.blank()
    c = s.color
    for y in range(s.h):
        for x in range(s.w):
            if not s.inside(x, y):
                continue
            edge = not (s.inside(x - 2, y) and s.inside(x + 2, y) and s.inside(x, y - 2) and s.inside(x, y + 2))
            if edge:
                px[y][x] = c(RIM_D) if not (s.inside(x - 1, y) and s.inside(x + 1, y) and s.inside(x, y - 1)) else c(RIM)
            else:
                col = (x - s.cx) // 4
                plank = (x - s.cx) % 4 == 0
                joint = (y + col * 7) % 14 == 0
                shade = not (s.inside(x - 3, y) and s.inside(x + 3, y))
                if plank or joint:
                    px[y][x] = c(SEAM)
                elif shade:
                    px[y][x] = c(SEAM)
                else:
                    px[y][x] = c(DECK_L) if (col + (y + col * 7) // 14) % 3 == 0 else c(DECK)
    # 뱃머리 막대(바우스프릿)
    for y in range(s.top - 8, s.top + 2):
        put(px, s.cx, y, c(MAST))
    # 고물 선실 지붕
    if s.t["cabin"]:
        y0 = s.bottom - 14
        rect(px, s.cx - 9, y0, 18, 9, c(RIM_D))
        rect(px, s.cx - 8, y0 + 1, 16, 7, c(RIM))
        for x in range(s.cx - 7, s.cx + 7, 3):
            put(px, x, y0 + 4, c(LAMP) if not s.t["ghost"] else (120, 255, 200))
    # 격자 승강구(돛대 사이)
    gy = (s.mast_y[0] + s.mast_y[-1]) // 2 if len(s.mast_y) > 1 else s.mast_y[0] + 14
    rect(px, s.cx - 4, gy - 3, 9, 7, c(RIM_D))
    for yy in range(gy - 2, gy + 3):
        for xx in range(s.cx - 3, s.cx + 4):
            put(px, xx, yy, c(SEAM) if (xx + yy) % 2 else c(RIM))
    # 돛대 밑동
    for my in s.mast_y:
        rect(px, s.cx - 1, my - 1, 3, 3, c(MAST))
    outline(px)
    return px


# ---------- 선체 단계 ----------
def hull(s: Ship, stage: int):
    px = s.blank()
    c = s.color
    rim = [(x, y) for y in range(s.h) for x in range(s.w) if s.inside(x, y) and not (s.inside(x - 2, y) and s.inside(x + 2, y))]
    if stage >= 7:  # 마호가니 갑판
        for y in range(s.h):
            for x in range(s.w):
                if s.inside(x - 2, y) and s.inside(x + 2, y) and s.inside(x, y - 2) and s.inside(x, y + 2):
                    px[y][x] = c(MAHOG_D) if (x - s.cx) % 4 == 0 else c(MAHOG)
    if stage >= 2:  # 테두리 쇠 징
        for x, y in rim:
            if y % 6 == 0:
                px[y][x] = IRON_HI
    if stage >= 3:  # 가로 쇠 띠(테두리를 감는 줄) 4개
        for i in range(1, 5):
            y = s.top + s.len * i // 5
            for x in range(s.w):
                if s.inside(x, y) and not (s.inside(x - 2, y) and s.inside(x + 2, y)):
                    px[y][x] = IRON
    if stage >= 4:  # 충각: 뱃머리 쇠판
        for y in range(s.top, s.top + 8):
            for x in range(s.w):
                if s.inside(x, y):
                    px[y][x] = STEEL_HI if (x + y) % 3 == 0 else STEEL
    if stage >= 5:  # 금 테(테두리 바깥 줄)
        for x, y in rim:
            if not (s.inside(x - 1, y) and s.inside(x + 1, y)):
                px[y][x] = GOLD if y % 3 else GOLD_HI
    if stage >= 6:  # 고물 금 문장
        y0 = s.bottom - 6
        art(px, s.cx - 3, y0 - 3, ["...g...", "..gGg..", ".gGrGg.", "..gGg..", "...g..."],
            {"g": GOLD, "G": GOLD_HI, "r": RED})
    return px


# ---------- 화물(고물 갑판, 돛 아래 가리지 않는 자리) ----------
BARREL = [".kkkk.", "kbbbbk", "kbiibk", "kbiibk", "kbbbbk", ".kkkk."]
CRATE = ["kkkkkkk", "kllxllk", "klxlxlk", "kxlllxk", "klxlxlk", "kllxllk", "kkkkkkk"]
CHEST = ["kkkkkkkkk", "kwwwgwwwk", "kxxxGxxxk", "kwwwwwwwk", "kwwwwwwwk", "kkkkkkkkk"]
OPEN = ["kkkkkkkkk", "kGgGgGgGk", "kgGrGgGgk", "kGgGgbGgk", "kwwwwwwwk", "kkkkkkkkk"]
PILE = ["..kkk..", ".kGgGk.", "kGgGgGk", "kgGrGgk", "kGgGgGk", ".kgGgk.", "..kkk.."]


def cargo(s: Ship, stage: int):
    px = s.blank()
    pal = {"k": K, "b": WOOD, "i": IRON, "I": IRON_HI, "l": WOOD_L, "x": WOOD_D, "w": WOOD, "g": GOLD, "G": GOLD_HI,
           "r": RED}
    pal["b"] = (128, 200, 255)  # 열린 금상자 안 보석(파랑) — 통은 아래에서 다시
    y = s.cargo_y
    slots = [(-14, 0, BARREL), (-7, 0, BARREL), (1, 0, CRATE), (1, -8, CRATE), (-12, -8, CHEST), (-12, -8, OPEN),
             (9, -6, PILE)]
    use = {1: [0], 2: [0, 1], 3: [0, 1, 2], 4: [0, 1, 2, 3], 5: [0, 1, 2, 3, 4], 6: [0, 1, 2, 3, 5],
           7: [0, 1, 2, 3, 5, 6]}[stage]
    for i in use:
        dx, dy, a = slots[i]
        p2 = dict(pal)
        if a is BARREL:
            p2["b"] = WOOD
        art(px, s.cx + dx, y + dy, a, p2)
    return px


# ---------- 대포(옆으로 내민 포, 돛 사이 자리) ----------
def cannon(s: Ship, stage: int):
    px = s.blank()
    metal, hi = {1: (IRON, IRON_HI), 2: (IRON, IRON_HI), 3: (BRASS, BRASS_HI), 4: (BRASS, BRASS_HI),
                 5: (STEEL, STEEL_HI), 6: (STEEL, STEEL_HI), 7: (GOLD, GOLD_HI)}[stage]
    pairs = {1: 1, 2: 2, 3: 2, 4: 3, 5: 3, 6: 3, 7: 4}[stage]
    length = 5 if stage < 5 else 6
    # 돛 줄(돛대 ±4)을 피한 자리를 위에서부터 고른다.
    free = [y for y in range(s.top + s.len // 3, s.bottom - 8, 2)
            if all(abs(y - my) > 5 for my in s.mast_y) and abs(y - s.cargo_y) > 6]
    step = max(1, len(free) // (pairs + 1))
    rows = [free[min(len(free) - 1, step * (i + 1))] for i in range(pairs)]
    for y in rows:
        for side in (-1, 1):
            x_edge = s.cx + side * round(s.half(y))
            for k in range(length):
                x = x_edge + side * (k - 1)
                put(px, x, y, hi if k > 1 else metal)
                put(px, x, y + 1, metal)
                if stage == 6:  # 쌍포: 한 줄 더
                    put(px, x, y + 3, hi if k > 1 else metal)
                    put(px, x, y + 4, metal)
            mouth = x_edge + side * (length - 1)
            put(px, mouth, y - 1 if stage >= 4 else y, hi)
            if stage == 7:
                put(px, mouth, y + 2, RED)
    if stage >= 5:  # 뱃머리 포(앞으로)
        for k in range(6):
            put(px, s.cx, s.top - 2 + k, hi if k < 2 else metal)
            put(px, s.cx + 1, s.top - 2 + k, metal)
    outline(px)
    return px


# ---------- 돛(위에서 본 가로 활대 + 부푼 천) ----------
def sail(s: Ship, stage: int):
    px = s.blank()
    c = s.color
    for i, my in enumerate(s.mast_y):
        main = my == s.main
        half = s.hw + (7 if main else 4) - (2 if i == 0 and len(s.mast_y) > 1 else 0)
        depth = 9 if main else 7
        for x in range(s.cx - half, s.cx + half + 1):
            d = abs(x - s.cx) / half
            belly = round(depth * (1 - d ** 2.2)) + 2  # 가운데가 바람에 불룩
            put(px, x, my - 1, c(YARD))  # 활대
            put(px, x, my - 2, c(YARD) if abs(x - s.cx) == half else None)
            for k in range(belly):
                t = k / max(1, belly - 1)
                col = c(SAIL_L) if t < 0.25 else (c(SAIL_D) if t > 0.8 else c(SAIL))
                if d > 0.85 and t > 0.5:
                    col = c(SAIL_D)
                if s.t["ghost"] and k == belly - 1 and x % 3 == 0:
                    col = None  # 찢긴 끝
                if col:
                    put(px, x, my + k, col)
            if stage == 1 and x % 10 == 5 and belly > 5:  # 기운 천 조각
                for k in range(2, 5):
                    for xx in (x, x + 1, x + 2):
                        put(px, xx, my + k, PATCH_D if (k + xx) % 2 else PATCH)
            if stage >= 3:  # 빨간 줄 두 줄
                put(px, x, my + max(1, belly // 3), RED)
                if belly > 6:
                    put(px, x, my + belly // 3 + 2, RED)
        put(px, s.cx, my, c(MAST))
    if stage >= 4:  # 해골 문장(큰 돛, 돛대 왼쪽)
        col = GOLD if stage >= 5 else WHITE
        # 맨 뒤 돛(t1은 하나뿐 → 돛대 왼쪽) 가운데에 큰 해골 — 망루와 겹치지 않게.
        sy = s.mast_y[-1] + 1
        sx = s.cx - 4 if s.mast_y[-1] != s.main else s.cx - 15
        art(px, sx, sy, ["..wwwww..", ".wwwwwww.", "wwkkwkkww", "wwkkwkkww", "wwwwkwwww", ".wwwwwww.", "..w.w.w.."],
            {"w": col, "k": K})
    if stage >= 5:  # 금 테
        for y in range(s.h):
            for x in range(s.w):
                if px[y][x] in (c(SAIL), c(SAIL_L), c(SAIL_D), RED):
                    if any(not (0 <= y + dy < s.h and 0 <= x + dx < s.w) or px[y + dy][x + dx] is None
                           for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                        px[y][x] = GOLD
    # 뱃머리 삼각돛(지브)
    if s.t["jib"]:
        for k in range(8):
            for x in range(s.cx - k // 2, s.cx + k // 2 + 1):
                put(px, x, s.top - 8 + k, c(SAIL_D) if x == s.cx + k // 2 else c(SAIL))
    outline(px)
    return px


# ---------- 망루(큰 돛대 위, 돛 위에 겹침) ----------
def crowsnest(s: Ship, stage: int):
    px = s.blank()
    y, x = s.main + 2, s.cx
    r = 3 if stage == 1 else 4
    rim = GOLD if stage >= 6 else WOOD_D
    for dy in range(-r, r + 1):
        for dx in range(-r, r + 1):
            d = math.hypot(dx, dy)
            if d <= r + 0.3:
                put(px, x + dx, y + dy, rim if d > r - 1.2 else WOOD)
    put(px, x, y, MAST)
    if stage >= 2:  # 난간 기둥 네 점
        for dx, dy in ((-r, 0), (r, 0), (0, -r), (0, r)):
            put(px, x + dx, y + dy, WOOD_L if stage < 6 else GOLD_HI)
    if stage >= 3:  # 깃발(옆으로 날림)
        art(px, x + 1, y - r - 4, ["yyyy", "yyy.", "yy.."], {"y": (255, 206, 60) if stage < 6 else GOLD})
    if stage >= 4:  # 망원경
        art(px, x - r - 3, y - 1, ["bbbw"], {"b": BRASS, "w": WHITE})
    if stage >= 5:  # 등불
        art(px, x + r, y + 1, [".l.", "lLl", ".l."], {"l": LAMP_D, "L": LAMP})
    outline(px)
    return px


def sheet(frames):
    return [sum((f[y] for f in frames), []) for y in range(len(frames[0]))]


def files() -> dict[str, list[list]]:
    out = {}
    for n in TIERS:
        s = Ship(n)
        out[f"ship/td_t{n}_base.png"] = base(s)
        for part, count in STAGES.items():
            make = {"hull": hull, "cargo": cargo, "cannon": cannon, "sail": sail, "crowsnest": crowsnest}[part]
            out[f"ship/td_t{n}_{part}.png"] = sheet([make(s, i) for i in range(1, count + 1)])
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
        print("✓ 탑다운 배가 격자와 같다")
        return 0
    print(f"✓ {len(changed)}개 갱신")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
