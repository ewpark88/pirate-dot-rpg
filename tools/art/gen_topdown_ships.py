"""탑다운 내 배 (사용자 결정 '탑다운 전환, 배는 가운데'·사용자 지시 '배를 키우는 재미 — 돛이 여러 개 생기고 외형·대포가 바뀌게').
위에서 내려다본 도트, 뱃머리가 위. OWN.

    python -I tools/art/gen_topdown_ships.py            # apps/game/assets/ship/td_*.png 에 쓴다
    python -I tools/art/gen_topdown_ships.py --check    # 쓰지 않고, 결과가 지금 파일과 다르면 실패

등급(t1 dinghy · t2 sloop · t3 warship · t4 ghost)마다 같은 크기 프레임의 층 시트 — 렌더가 이 순서로 겹친다:
  td_t<n>_base.png (1)       빈 프레임(크기 기준)
  td_t<n>_hull.png (7)       선체 전체: 단계마다 길이 +5%·폭 +3%, 뱃머리 뭉툭 → 뾰족 → 쇠 충각 → 금 선수상, 갑판·테두리 무늬
  td_t<n>_cargo.png (7)      고물 갑판 짐: 통 → 통 둘 → 상자 → 상자 더미 → 보물상자 → 열린 금상자 → 금 더미
  td_t<n>_sail.png (5)       돛대 수 = 단계(1 → 2 → 3 → 4), 5단계는 4 + 앞 삼각돛 + 금 테. 기운 자국 → 빨간 줄 → 해골
  td_t<n>_cannon.png (7)     한쪽 포 1 → 2 → 2(긴) → 3(청동) → 3(쌍포) → 4 + 앞 갑판 회전 포탑 → 4 금 용포 + 금 포탑
  td_t<n>_crowsnest.png (6)  큰 돛대 위 망루: 커지며 난간 → 깃발 → 망원경 → 등불 → 금
돛대 자리는 가장 짧은 선체(1단계) 기준으로 정해서 선체 단계와 돛 단계가 서로 어긋나지 않는다(큰 돛대는 늘 같은 자리 = 망루).
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
DECK_DARK = (176, 128, 80)
GHOST = {RIM: (78, 66, 92), RIM_D: (56, 46, 70), DECK: (104, 92, 120), DECK_L: (122, 110, 140), SEAM: (84, 72, 100),
         DECK_DARK: (92, 80, 108), MAST: (44, 36, 56), YARD: (56, 46, 70), SAIL: (110, 220, 205), SAIL_D: (70, 170, 165),
         SAIL_L: (170, 245, 230), MAHOG: (72, 46, 112), MAHOG_D: (50, 30, 84)}

# 등급: 1단계 선체 반폭·길이, 유령(팔레트·찢긴 돛)
TIERS = {
    1: dict(hw=13, length=62, ghost=False, jib=False),
    2: dict(hw=14, length=68, ghost=False, jib=True),
    3: dict(hw=16, length=76, ghost=False, jib=True),
    4: dict(hw=16, length=76, ghost=True, jib=True),
}
STAGES = {"hull": 7, "cargo": 7, "cannon": 7, "sail": 5, "crowsnest": 6}
HULL_GROW, HULL_WIDEN = 0.05, 0.03  # 선체 단계당 길이·폭
MAIN_AT = 0.45  # 큰 돛대(망루) — 1단계 선체 길이 비율, 늘 같은 자리
MASTS = {1: [MAIN_AT], 2: [0.24, MAIN_AT], 3: [0.24, MAIN_AT, 0.66], 4: [0.11, 0.27, MAIN_AT, 0.66]}
CANNON_AT = [0.36, 0.56, 0.76, 0.86]  # 옆 포 자리(1단계 선체 길이 비율)
SAIL_HANG = 9  # 돛이 선체 밖으로 나가는 폭(최대)
GUN_OUT = 9  # 포신이 선체 밖으로 나가는 길이(최대)


class Ship:
    """등급 하나의 프레임·좌표. 선체 단계마다 길이·폭·뱃머리가 바뀐다(`hull_at`)."""

    def __init__(self, n: int):
        t = TIERS[n]
        self.n, self.t = n, dict(t)
        self.hw, self.len = t["hw"], t["length"]
        max_len = self.len * (1 + HULL_GROW * 6)
        max_hw = self.hw * (1 + HULL_WIDEN * 6)
        self.w = int(2 * (max_hw + max(SAIL_HANG, GUN_OUT) + 3))
        self.w += self.w % 2
        bow_room = 14  # 바우스프릿·충각·선수상
        self.top = int(bow_room + (max_len - self.len) * 0.65)  # 1단계 선체 윗변
        self.bottom = self.top + self.len
        self.h = int(self.bottom + (max_len - self.len) * 0.35 + 4)
        self.cx = self.w // 2
        self.main = self.top + round(self.len * MAIN_AT)
        self.mast_y = self.masts(2)  # 보스(돛 2단계)와 같은 자리
        self.cargo_y = self.top + round(self.len * 0.86)

    def masts(self, count: int) -> list[int]:
        return [self.top + round(self.len * f) for f in MASTS[count]]

    def hull_at(self, stage: int):
        """선체 단계의 (윗변, 아랫변, 반폭)."""
        grow = self.len * HULL_GROW * (stage - 1)
        return self.top - grow * 0.65, self.bottom + grow * 0.35, self.hw * (1 + HULL_WIDEN * (stage - 1))

    def half(self, y: float, stage: int = 1) -> float:
        """선체 반폭 at y: 뱃머리는 단계에 따라 뭉툭(1~2) · 뾰족(3~), 고물은 조금 좁고 평평."""
        top, bottom, hw = self.hull_at(stage)
        u = (y - top) / (bottom - top)
        if u < 0 or u > 1:
            return -1
        bow = 0.28 if stage <= 2 else 0.42
        if u < bow:
            p = u / bow
            return hw * (math.sqrt(p) if stage <= 2 else math.sin(math.pi / 2 * p) ** 1.5)
        if u > 0.9:
            return hw * (1 - (u - 0.9) * 1.6)
        return hw

    def inside(self, x: int, y: int, stage: int = 1) -> bool:
        return abs(x + 0.5 - self.cx) <= self.half(y, stage)

    def blank(self):
        return [[None] * self.w for _ in range(self.h)]

    def color(self, c):
        return GHOST.get(c, c) if self.t["ghost"] else c


def put(px, x, y, c):
    x, y = int(round(x)), int(round(y))
    if 0 <= y < len(px) and 0 <= x < len(px[0]):
        px[y][x] = c


def rect(px, x0, y0, w, h, c):
    for y in range(int(y0), int(y0 + h)):
        for x in range(int(x0), int(x0 + w)):
            put(px, x, y, c)


def art(px, x0, y0, rows: list[str], pal: dict):
    for dy, line in enumerate(rows):
        for dx, ch in enumerate(line):
            if ch in pal:
                put(px, x0 + dx, y0 + dy, pal[ch])


def outline(px):
    _b.outline(px)


def base(s: Ship):
    """빈 프레임 — 크기 기준(선체·그림자는 hull 층)."""
    return s.blank()


# ---------- 선체(단계마다 길어지고 넓어지며 뱃머리·무늬가 바뀜) ----------
def hull(s: Ship, stage: int):
    px = s.blank()
    c = s.color
    top, bottom, _ = s.hull_at(stage)
    mahog = stage >= 7
    for y in range(s.h):
        for x in range(s.w):
            if not s.inside(x, y, stage):
                continue
            edge = not (s.inside(x - 2, y, stage) and s.inside(x + 2, y, stage) and s.inside(x, y - 2, stage)
                        and s.inside(x, y + 2, stage))
            if edge:
                outer = not (s.inside(x - 1, y, stage) and s.inside(x + 1, y, stage) and s.inside(x, y - 1, stage))
                col = c(RIM_D) if outer else c(RIM)
                if stage >= 2 and not outer and y % 5 == 0:
                    col = IRON_HI  # 쇠 징
                if stage >= 4 and outer:
                    col = BRASS if stage < 6 else GOLD  # 청동 → 금 테
                px[y][x] = col
                continue
            col_i = (x - s.cx) // 4
            plank = (x - s.cx) % 4 == 0
            joint = (y + col_i * 7) % 14 == 0
            shade = not (s.inside(x - 3, y, stage) and s.inside(x + 3, y, stage))
            if plank or joint or shade:
                px[y][x] = c(MAHOG_D) if mahog else c(SEAM)
            elif mahog:
                px[y][x] = c(MAHOG)
            elif stage >= 3 and col_i % 2:
                px[y][x] = c(DECK_DARK)  # 두 가지 색 판자
            else:
                px[y][x] = c(DECK_L) if (col_i + (y + col_i * 7) // 14) % 3 == 0 else c(DECK)
    if stage >= 3:  # 가로 쇠 띠
        for i in (1, 2, 3):
            y = int(top + (bottom - top) * i / 4)
            for x in range(s.w):
                if s.inside(x, y, stage) and not (s.inside(x - 3, y, stage) and s.inside(x + 3, y, stage)):
                    px[y][x] = IRON
    for y in range(int(top) - 7, int(top) + 2):  # 바우스프릿(뱃머리 막대)
        put(px, s.cx, y, c(MAST))
    if stage >= 5:  # 쇠 충각: 뱃머리 끝에서 앞으로 뾰족한 쇠
        for k in range(7):
            w = max(0, 2 - k // 3)
            for dx in range(-w, w + 1):
                put(px, s.cx + dx, top - 1 - k, STEEL_HI if dx == 0 else STEEL)
    if stage >= 6:  # 금 선수상(사자 머리) — 뱃머리 안쪽
        art(px, s.cx - 2, int(top) + 3, [".GgG.", "GgggG", "gkgkg", "GgggG", ".GgG."], {"G": GOLD_HI, "g": GOLD, "k": K})
    if stage >= 7:  # 고물 등불 둘
        for side in (-1, 1):
            put(px, s.cx + side * 4, int(bottom) - 3, LAMP)
            put(px, s.cx + side * 4, int(bottom) - 4, LAMP_D)
    outline(px)
    return px


# ---------- 화물(고물 갑판) ----------
BARREL = [".kkkk.", "kbbbbk", "kbiibk", "kbiibk", "kbbbbk", ".kkkk."]
CRATE = ["kkkkkk", "klxxlk", "kxllxk", "kxllxk", "klxxlk", "kkkkkk"]
CHEST = ["kkkkkkk", "kwwgwwk", "kxxGxxk", "kwwwwwk", "kkkkkkk"]
OPEN = ["kkkkkkk", "kGgGgGk", "kgGrGgk", "kwwwwwk", "kkkkkkk"]
PILE = ["..kkk..", ".kGgGk.", "kGgrgGk", "kgGgGgk", ".kkkkk."]


def cargo(s: Ship, stage: int):
    px = s.blank()
    pal = {"k": K, "b": WOOD, "i": IRON, "l": WOOD_L, "x": WOOD_D, "w": WOOD, "g": GOLD, "G": GOLD_HI, "r": RED}
    y = s.cargo_y - 3
    slots = [(-11, 0, BARREL), (-5, 0, BARREL), (1, 0, CRATE), (1, -6, CRATE), (-12, -6, CHEST), (-12, -6, OPEN),
             (7, -6, PILE)]
    use = {1: [0], 2: [0, 1], 3: [0, 1, 2], 4: [0, 1, 2, 3], 5: [0, 1, 2, 3, 4], 6: [0, 1, 2, 3, 5],
           7: [0, 1, 2, 3, 5, 6]}[stage]
    for i in use:
        dx, dy, a = slots[i]
        art(px, s.cx + dx, y + dy, a, pal)
    return px


# ---------- 대포(한쪽 1 → 4문, 모양 단계별, 앞 갑판 회전 포탑) ----------
def cannon(s: Ship, stage: int):
    px = s.blank()
    per_side = {1: 1, 2: 2, 3: 2, 4: 3, 5: 3, 6: 4, 7: 4}[stage]
    length = {1: 4, 2: 4, 3: 7, 4: 7, 5: 7, 6: 8, 7: 9}[stage]
    metal, hi = {1: (IRON, IRON_HI), 2: (IRON, IRON_HI), 3: (IRON, IRON_HI), 4: (BRASS, BRASS_HI),
                 5: (STEEL, STEEL_HI), 6: (STEEL, STEEL_HI), 7: (GOLD, GOLD_HI)}[stage]
    twin = stage >= 5
    for i in range(per_side):
        y = s.top + round(s.len * CANNON_AT[i])
        for side in (-1, 1):
            edge = s.cx + side * round(s.half(y, 1))
            rows = (y - 1, y + 2) if twin else (y,)
            for ry in rows:
                for k in range(length):
                    x = edge + side * k
                    put(px, x, ry, hi if k >= length - 2 else metal)
                    put(px, x, ry + 1, metal)
                mouth = edge + side * (length - 1)
                put(px, mouth, ry - 1, hi)
                if stage == 7:  # 금 용포: 빨간 입
                    put(px, mouth + side, ry, RED)
                    put(px, mouth + side, ry + 1, RED)
            put(px, edge - side, y, WOOD_D)  # 포가
    if stage >= 6:  # 앞 갑판 회전 포탑: 둥근 받침 + 앞으로 긴 포신
        ty = s.top + round(s.len * 0.2)
        ring = GOLD if stage >= 7 else STEEL
        for dy in range(-4, 5):
            for dx in range(-4, 5):
                d = math.hypot(dx, dy)
                if d <= 4.2:
                    put(px, s.cx + dx, ty + dy, ring if d > 3 else (GOLD_HI if stage >= 7 else STEEL_HI))
        for k in range(9):
            put(px, s.cx, ty - 3 - k, hi if k > 6 else metal)
            put(px, s.cx + 1, ty - 3 - k, metal)
    outline(px)
    return px


# ---------- 돛(돛대 수 = 단계, 위에서 본 활대 + 부푼 천) ----------
def sail(s: Ship, stage: int):
    px = s.blank()
    c = s.color
    masts = s.masts(min(stage, 4))
    for my in masts:
        main = my == s.main
        half = s.hw + (SAIL_HANG - 1 if main else SAIL_HANG - 4)
        depth = 9 if main else 7
        for x in range(s.cx - half, s.cx + half + 1):
            d = abs(x - s.cx) / half
            belly = round(depth * (1 - d ** 2.2)) + 2
            put(px, x, my - 1, c(YARD))
            for k in range(belly):
                t = k / max(1, belly - 1)
                col = c(SAIL_L) if t < 0.25 else (c(SAIL_D) if t > 0.8 else c(SAIL))
                if d > 0.85 and t > 0.5:
                    col = c(SAIL_D)
                if s.t["ghost"] and k == belly - 1 and x % 3 == 0:
                    col = None
                if col:
                    put(px, x, my + k, col)
            if stage == 1 and x % 10 == 5 and belly > 5:
                for k in range(2, 5):
                    for xx in (x, x + 1, x + 2):
                        put(px, xx, my + k, PATCH_D if (k + xx) % 2 else PATCH)
            if stage >= 3:
                put(px, x, my + max(1, belly // 3), RED)
                if belly > 6:
                    put(px, x, my + belly // 3 + 2, RED)
        put(px, s.cx, my, c(MAST))
    if stage >= 4:  # 해골: 맨 뒤 돛(큰 돛이 맨 뒤면 돛대 왼쪽)
        col = GOLD if stage >= 5 else WHITE
        aft = masts[-1]
        sx = s.cx - 4 if aft != s.main else s.cx - 14
        art(px, sx, aft + 1, ["..wwwww..", ".wwwwwww.", "wwkkwkkww", "wwkkwkkww", "wwwwkwwww", ".wwwwwww.", "..w.w.w.."],
            {"w": col, "k": K})
    if stage >= 5:  # 금 테
        for y in range(s.h):
            for x in range(s.w):
                if px[y][x] in (c(SAIL), c(SAIL_L), c(SAIL_D), RED):
                    if any(not (0 <= y + dy < s.h and 0 <= x + dx < s.w) or px[y + dy][x + dx] is None
                           for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                        px[y][x] = GOLD
    if stage >= 5 or (s.t["jib"] and stage >= 2):  # 앞 삼각돛(지브)
        for k in range(8):
            for x in range(s.cx - k // 2, s.cx + k // 2 + 1):
                put(px, x, s.top - 8 + k, c(SAIL_D) if x == s.cx + k // 2 else c(SAIL))
    outline(px)
    return px


# ---------- 망루(큰 돛대 위, 커지며 장식) ----------
def crowsnest(s: Ship, stage: int):
    px = s.blank()
    y, x = s.main + 2, s.cx
    r = {1: 3, 2: 4, 3: 4, 4: 5, 5: 5, 6: 6}[stage]
    rim = GOLD if stage >= 6 else WOOD_D
    for dy in range(-r, r + 1):
        for dx in range(-r, r + 1):
            d = math.hypot(dx, dy)
            if d <= r + 0.3:
                put(px, x + dx, y + dy, rim if d > r - 1.2 else WOOD)
    put(px, x, y, MAST)
    if stage >= 2:
        for dx, dy in ((-r, 0), (r, 0), (0, -r), (0, r)):
            put(px, x + dx, y + dy, WOOD_L if stage < 6 else GOLD_HI)
    if stage >= 3:
        art(px, x + 1, y - r - 4, ["yyyyy", "yyyy.", "yyy.."], {"y": (255, 206, 60) if stage < 6 else GOLD})
    if stage >= 4:
        art(px, x - r - 3, y - 1, ["bbbw"], {"b": BRASS, "w": WHITE})
    if stage >= 5:
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
