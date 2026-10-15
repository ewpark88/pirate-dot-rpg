"""배 부품 외형 단계 (사용자 지시 '부품 업그레이드 때 디자인이 바뀌게') — 등급 배 위에 얹는 덧그림 시트. OWN.

    python -I tools/art/gen_ship_parts.py            # apps/game/assets/ship/ 에 쓴다
    python -I tools/art/gen_ship_parts.py --check    # 쓰지 않고, 결과가 지금 파일과 다르면 실패

부품(S2 ship_parts.json visualStages): hull 7 · sail 5 · crowsnest 6 · cargo 7 단계 → 등급(t1~t4)마다 가로 시트
`ship/part_t<n>_<part>.png` (프레임 = 그 등급 배 그림과 같은 크기, 프레임 i = 단계 i+1). 렌더는 배 그림과 같은 상자에 겹친다.
대포(cannon 7단계)는 등급과 무관한 따로 레이어 `ship/part_cannon.png` (프레임 18×10, 포구 끝 = 오른쪽 끝·세로 가운데 줄 4) —
렌더가 뱃머리에 얹고 발사 때 반동시킨다. 디자인은 PB 배 모듈(망루 crowsnest·포문 gunport·화물)을 도트로 다시 그렸다.
자리는 배 그림에서 찾는다: 선체 색 칸, 돛 색 칸, 가장 오른쪽 돛대 꼭대기, 갑판 줄, 고물 선실 오른쪽 끝. 같은 입력이면 같은 바이트.
"""

from __future__ import annotations

import importlib.util
import json
import sys
from pathlib import Path

sys.dont_write_bytecode = True

HERE = Path(__file__).resolve().parent
ASSETS = HERE.parents[1] / "apps" / "game" / "assets"
SOURCE = "Pirate Busters v0.24 자체 IP(배 모듈 디자인) → tools/art/gen_ship_parts.py 픽셀 격자"

_spec = importlib.util.spec_from_file_location("gen_bosses", HERE / "gen_bosses.py")
_b = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_b)

K = (27, 23, 38)
HULLS = {(140, 90, 50), (95, 58, 32), (78, 66, 92), (56, 46, 70)}
MASTS = {(70, 44, 26), (44, 36, 56)}
SAILS = {(240, 232, 210), (47, 98, 196), (110, 220, 205), (60, 150, 160)}
WINDOWS = {(255, 214, 102), (120, 255, 200)}
IRON, IRON_HI = (90, 96, 112), (174, 182, 196)
COPPER, COPPER_HI = (200, 116, 58), (232, 154, 90)
GOLD, GOLD_HI = (242, 201, 76), (255, 240, 170)
WOOD, WOOD_D, WOOD_L = (150, 96, 52), (104, 64, 34), (196, 150, 96)
RED, WHITE, PATCH = (220, 70, 60), (250, 250, 250), (214, 200, 166)
BRASS, LAMP = (214, 168, 70), (255, 236, 140)
STAGES = {"hull": 7, "sail": 5, "crowsnest": 6, "cargo": 7}


def tier(n: int):
    return _b.read_png(ASSETS / "ship" / f"ship_t{n}.png")


def rgb(c):
    return None if c is None else tuple(c[:3])


class Ship:
    """배 그림에서 자리 찾기."""

    def __init__(self, px):
        self.px, self.h, self.w = px, len(px), len(px[0])
        rows = [sum(1 for c in r if rgb(c) in HULLS) for r in px]
        self.deck = next(y for y, n in enumerate(rows) if n > self.w // 2)
        self.bottom = max(y for y, r in enumerate(px) if any(c is not None for c in r))
        self.hull = [(x, y) for y in range(self.deck + 1, self.h) for x in range(self.w) if rgb(px[y][x]) in HULLS]
        self.sail = [(x, y) for y in range(self.h) for x in range(self.w) if rgb(px[y][x]) in SAILS]
        masts = sorted({x for y in range(self.deck) for x in range(self.w) if rgb(px[y][x]) in MASTS})
        self.mast_x = max(x for x in masts if rgb(px[self.deck - 2][x]) in MASTS or x == masts[-1])
        self.mast_top = min(y for y in range(self.h) if rgb(px[y][self.mast_x]) in MASTS)
        row = px[self.deck]
        self.stern = min(x for x, c in enumerate(row) if c is not None and c != K)
        # 고물 선실 창(돛대보다 한참 왼쪽, 갑판 위) — 유령선 포문·깃발의 초록은 빼고.
        win = [x for y in range(self.deck) for x in range(self.mast_x - 12) if rgb(px[y][x]) in WINDOWS]
        self.ghost = any(rgb(px[y][x]) == (78, 66, 92) for x, y in self.hull)
        self.cargo_x = (max(win) + 4) if win else self.stern + 5

    def blank(self):
        return [[None] * self.w for _ in range(self.h)]


def put(px, x, y, c):
    if 0 <= y < len(px) and 0 <= x < len(px[0]):
        px[y][x] = c


def draw(px, x0, y0, art: list[str], pal: dict):
    for dy, line in enumerate(art):
        for dx, ch in enumerate(line):
            if ch in pal:
                put(px, x0 + dx, y0 + dy, pal[ch])


# ---------- 선체: 쇠 띠 → 구리 바닥 → 금 테 → 마호가니 ----------
def hull(s: Ship, stage: int):
    px = s.blank()
    xs = sorted({x for x, _ in s.hull})
    left, right = xs[0], xs[-1]
    mine = set(s.hull)
    if stage >= 7:  # 마호가니(진한 붉은 나무) 판자
        for x, y in s.hull:
            if s.ghost:  # 유령선은 깊은 보라 판자
                px[y][x] = (72, 46, 112) if (y - s.deck) % 3 else (50, 30, 84)
            else:
                px[y][x] = (122, 58, 42) if (y - s.deck) % 3 else (90, 40, 30)
    if stage >= 2:  # 세로 쇠 띠 + 리벳
        n = 3 if stage < 4 else 5
        for i in range(n):
            bx = left + (right - left) * (i + 1) // (n + 1)
            for y in range(s.deck + 1, s.bottom):
                if (bx, y) in mine:
                    px[y][bx] = IRON
            put(px, bx, s.deck + 1, IRON_HI)
    if stage >= 3:  # 물 닿는 줄 위 가로 쇠 띠
        y = s.bottom - 3
        for x in range(left, right + 1):
            if (x, y) in mine:
                px[y][x] = IRON if x % 4 else IRON_HI
    if stage >= 4:  # 구리 바닥 2줄
        for x, y in s.hull:
            if y >= s.bottom - 1:
                px[y][x] = COPPER_HI if (x + y) % 5 == 0 else COPPER
    if stage >= 5:  # 갑판 아래 금 테
        for x, y in s.hull:
            if y == s.deck + 1:
                px[y][x] = GOLD if x % 3 else GOLD_HI
    if stage >= 6:  # 고물 금 문장(마름모) + 가운데 금 줄
        cx, cy = left + 6, s.deck + 4
        draw(px, cx - 2, cy - 2, ["..g..", ".gwg.", "gwrwg", ".gwg.", "..g.."], {"g": GOLD, "w": GOLD_HI, "r": RED})
        for x, y in s.hull:
            if y == s.bottom - 5 and x % 2:
                px[y][x] = GOLD
    return px


# ---------- 돛: 기운 자국 → 깨끗 → 빨간 겹줄 → 해골 문장 → 금 테 ----------
def sail(s: Ship, stage: int):
    px = s.blank()
    mine = set(s.sail)
    main = [(x, y) for x, y in s.sail if abs(x - s.mast_x) < 14]
    xs = [x for x, _ in main]
    ys = [y for _, y in main]
    cx, cy = (min(xs) + max(xs)) // 2, (min(ys) + max(ys)) // 2 + 2
    if stage == 1:  # 기운 천 조각 셋
        for px0, py0 in ((cx - 7, cy - 4), (cx + 4, cy + 2), (cx - 2, cy + 5)):
            for dx in range(3):
                for dy in range(3):
                    if (px0 + dx, py0 + dy) in mine:
                        px[py0 + dy][px0 + dx] = PATCH if (dx + dy) % 2 else (190, 176, 140)
    if stage >= 3:  # 빨간 겹줄: 기존 줄 두 칸 아래
        stripe = [(x, y) for x, y in s.sail if rgb(s.px[y][x]) in ((47, 98, 196), (60, 150, 160))]
        for x, y in stripe:
            if (x, y + 2) in mine:
                px[y + 2][x] = RED
    if stage >= 4:  # 해골 문장 (주돛 가운데)
        col = GOLD if stage >= 5 else WHITE
        sx = s.mast_x - 10  # 돛대 왼쪽 빈 돛 위
        draw(px, sx, cy - 4, _b.SKULL, {"w": col, "k": K})
    if stage >= 5:  # 돛 가장자리 금 테
        for x, y in s.sail:
            if any((nx, ny) not in mine for nx, ny in ((x + 1, y), (x - 1, y), (x, y - 1), (x, y + 1))):
                px[y][x] = GOLD
    return px


# ---------- 망루(가장 오른쪽 돛대 꼭대기 아래) ----------
def crowsnest(s: Ship, stage: int):
    px = s.blank()
    x, y = s.mast_x, s.mast_top + 4
    rim = GOLD if stage >= 6 else WOOD_D
    half = 2 if stage == 1 else 3
    for dx in range(-half, half + 2):
        put(px, x + dx, y, rim)
        put(px, x + dx, y + 1, WOOD)
        put(px, x + dx, y + 2, WOOD_D if dx in (-half, half + 1) else WOOD)
    for dx in range(-half + 1, half + 1):
        put(px, x + dx, y + 3, WOOD_D)
    if stage >= 2:  # 난간 기둥
        for dx in (-half, half + 1):
            put(px, x + dx, y - 1, WOOD_D)
    if stage >= 3:  # 노란 삼각 깃발(돛대 꼭대기)
        draw(px, x + 2, s.mast_top, ["yyyy", "yyy.", "yy.."], {"y": (255, 206, 60)})
    if stage >= 4:  # 망원경(놋쇠 + 반짝)
        draw(px, x + half + 2, y - 1, ["bbbw"], {"b": BRASS, "w": WHITE})
    if stage >= 5:  # 등불
        draw(px, x - half - 2, y - 1, [".l.", "lLl", ".l."], {"l": (255, 190, 60), "L": LAMP})
    if stage >= 6:  # 큰 금 깃발
        draw(px, x + 2, s.mast_top, ["ggggg", "gwwgg", "gggg.", "ggg.."], {"g": GOLD, "w": GOLD_HI})
    _b.outline(px)
    return px


# ---------- 화물(고물 쪽 갑판 위) ----------
BARREL = ["kkk", "bib", "bbb", "bib", "kkk"]
CRATE = ["kkkk", "lxxl", "lxxl", "kkkk"]
CHEST = ["kkkkk", "wwgww", "wgGgw", "wwwww"]
OPEN_CHEST = [".GgG.", "gGgGg", "wwgww", "wwwww"]
PILE = ["..G..", ".GgG.", "GgrgG", "gGgGg"]


def cargo(s: Ship, stage: int):
    px = s.blank()
    pal = {"k": K, "b": WOOD, "i": IRON, "l": WOOD_L, "x": WOOD_D, "w": WOOD, "g": GOLD, "G": GOLD_HI, "r": RED}
    base = s.deck - 1
    items = [("barrel", 0)]
    if stage >= 2:
        items.append(("barrel", 4))
    if stage >= 3:
        items.append(("crate", 8))
    if stage >= 4:
        items.append(("crate_top", 8))
    if stage >= 5:
        items.append(("chest" if stage == 5 else "open", 13))
    if stage >= 7:
        items.append(("pile", 19))
    for kind, dx in items:
        art = {"barrel": BARREL, "crate": CRATE, "crate_top": CRATE, "chest": CHEST, "open": OPEN_CHEST, "pile": PILE}[kind]
        lift = 4 if kind == "crate_top" else 0
        draw(px, s.cargo_x + dx, base - len(art) + 1 - lift, art, pal)
    return px


# ---------- 대포(뱃머리 따로 레이어, 18×10, 포구 끝 = 오른쪽 끝·줄 4) ----------
CW, CH, CY = 18, 10, 4


def cannon(stage: int):
    px = [[None] * CW for _ in range(CH)]
    metal, hi = {1: (IRON, IRON_HI), 2: (IRON, IRON_HI), 3: (BRASS, GOLD_HI), 4: (BRASS, GOLD_HI)}.get(
        stage, ((120, 132, 156), (210, 220, 236)) if stage < 7 else (GOLD, GOLD_HI)
    )
    length = {1: 8, 2: 10, 3: 10, 4: 12, 5: 13, 6: 13, 7: 14}[stage]
    barrels = [CY] if stage != 6 else [CY - 2, CY + 1]
    for by in barrels:
        x0 = CW - 1 - length
        for x in range(x0, CW - 1):
            put(px, x, by - 1, hi if x > x0 + 1 else metal)
            put(px, x, by, metal)
            put(px, x, by + 1, metal if stage < 3 else (metal if x % 4 else hi))
        for dy in (-2, -1, 0, 1, 2):  # 포구 고리
            put(px, CW - 2, by + dy, hi if dy == -2 else metal)
        if stage >= 4:
            for bx in (x0 + 3, x0 + 7):
                for dy in (-2, -1, 0, 1, 2):
                    put(px, bx, by + dy, metal)
    if stage >= 7:  # 용 입 고리 + 보석
        put(px, CW - 2, CY - 2, RED)
        put(px, CW - 3, CY - 3, GOLD_HI)
        put(px, 4, CY, RED)
    # 받침: 나무 받침(1~4) → 바퀴 포가(5~)
    for x in range(2, 9):
        put(px, x, CH - 3, WOOD)
        put(px, x, CH - 2, WOOD_D)
    if stage >= 5:
        for wx in (3, 7):
            draw(px, wx - 1, CH - 3, ["kik", "iIi", "kik"], {"k": K, "i": IRON, "I": IRON_HI})
    _b.outline(px)
    return px


def sheet(frames) -> list[list]:
    h = len(frames[0])
    return [sum((f[y] for f in frames), []) for y in range(h)]


def files() -> dict[str, list[list]]:
    out = {}
    for n in (1, 2, 3, 4):
        s = Ship(tier(n))
        for part, count in STAGES.items():
            make = {"hull": hull, "sail": sail, "crowsnest": crowsnest, "cargo": cargo}[part]
            out[f"ship/part_t{n}_{part}.png"] = sheet([make(s, i) for i in range(1, count + 1)])
    out["ship/part_cannon.png"] = sheet([cannon(i) for i in range(1, 8)])
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
        print("✓ 배 부품 외형이 격자와 같다")
        return 0
    print(f"✓ {len(changed)}개 갱신")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
