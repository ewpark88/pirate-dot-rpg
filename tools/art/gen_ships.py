"""내 배 등급 도트 생성 (t2 sloop · t3 warship · t4 ghost). ship_t1.png(팩, OWN) 칸을 바탕으로 늘리고 덧그린다. LICENSES OWN.

    python -I tools/art/gen_ships.py            # apps/game/assets/ship/ 에 쓴다
    python -I tools/art/gen_ships.py --check    # 쓰지 않고, 결과가 지금 파일과 다르면 실패

규칙: 뱃머리(오른쪽)·물 닿는 줄(아래)은 t1과 같은 자리 — 렌더는 배를 오른쪽 아래 기준으로 그려 포구 화염·발사 위치가 등급마다 맞는다.
커지는 쪽은 고물(왼쪽)과 위(돛). 늘리기는 무늬 없는 세로 줄(x=24)을 끼워 넣는다(돛·선체가 함께 길어진다).
- t2 sloop: +8 길이, 윗돛(톱세일), 앞 삼각돛(지브), 긴 깃발 꼬리.
- t3 warship: +16 길이, 돛대 둘(앞 돛이 뒤 돛을 가림)과 윗돛, 고물 선실(불 켜진 창), 금 띠, 포문 한 줄 더.
- t4 ghost: t3 모양 + 보라 잿빛 선체, 반투명 청록 돛(찢긴 끝), 초록 빛 창·포문.
같은 입력이면 같은 바이트.
"""

from __future__ import annotations

import importlib.util
import json
import sys
from pathlib import Path

sys.dont_write_bytecode = True

HERE = Path(__file__).resolve().parent
ASSETS = HERE.parents[1] / "apps" / "game" / "assets"
SOURCE = "Pirate Busters v0.24 자체 IP → tools/art/gen_ships.py 픽셀 격자 (ship_t1 바탕)"

_spec = importlib.util.spec_from_file_location("gen_bosses", HERE / "gen_bosses.py")
_b = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_b)

K = (27, 23, 38)
SAIL = (240, 232, 210)
STRIPE = (47, 98, 196)
HULL = (140, 90, 50)
HULL_LINE = (95, 58, 32)
MAST = (70, 44, 26)
MAST_SIDE = (95, 58, 32)
RED = (220, 70, 60)
GOLD = (242, 201, 76)
WINDOW = (255, 214, 102)

SLICE_X = 24  # 무늬 없는 세로 줄 (돛 W·줄무늬 u·선체 판자)
MAST_X = 28  # t1 돛대 (28 = D, 29 = H)
HULL_TOP = 28  # 이 줄부터 선체
PAD_TOP = 10  # 윗돛 자리


def t1() -> list[list]:
    """ship_t1 칸 — 돛대 꼭대기 작은 깃발(2~5줄)은 지운다(윗돛·새 깃발이 그 자리를 쓴다)."""
    px = [[None if c is None else c[:3] for c in row] for row in _b.read_png(ASSETS / "ship" / "ship_t1.png")]
    for y in range(2, 6):
        for x in range(27, 37):
            if not (x in (MAST_X, MAST_X + 1) and y >= 4):
                px[y][x] = None
    return px


def widen(px, n: int, rows=None) -> list[list]:
    """x=SLICE_X 줄을 n번 끼워 넣는다 ([rows]만, 나머지 줄은 투명 칸을 끼워 넣어 폭을 맞춘다)."""
    out = []
    for y, row in enumerate(px):
        fill = [row[SLICE_X]] * n if rows is None or y in rows else [None] * n
        out.append(row[:SLICE_X] + fill + row[SLICE_X:])
    return out


def pad_top(px, n: int) -> list[list]:
    return [[None] * len(px[0]) for _ in range(n)] + [list(r) for r in px]


def put(px, x, y, c):
    if 0 <= y < len(px) and 0 <= x < len(px[0]):
        px[y][x] = c


def trapezoid(px, cx: float, top: int, bottom: int, half_top: int, half_bottom: int, c, stripe_row=None):
    """투명 칸만 칠하는 사다리꼴 돛 (위가 좁다)."""
    for y in range(top, bottom + 1):
        t = (y - top) / max(1, bottom - top)
        hw = round(half_top + (half_bottom - half_top) * t)
        for x in range(int(cx - hw), int(cx + hw) + 1):
            if px[y][x] is None:
                put(px, x, y, STRIPE if y == stripe_row else c)


def mast(px, x: int, top: int, bottom: int):
    for y in range(top, bottom + 1):
        px[y][x] = MAST
        px[y][x + 1] = MAST_SIDE


def pennant(px, x: int, y: int, length: int, c):
    """돛대 꼭대기 오른쪽으로 날리는 깃발 꼬리(두 갈래)."""
    for i in range(length):
        put(px, x + i, y + (i // 3) % 2, c)
        if i < length - 2:
            put(px, x + i, y + 1 + (i // 3) % 2, c)


def topsail(px, mx: int, sail_top: int):
    """돛대 위 윗돛: 주돛 바로 위 9줄, 위가 좁은 사다리꼴 + 파란 줄."""
    trapezoid(px, mx + 0.5, sail_top - 10, sail_top - 2, 5, 9, SAIL, stripe_row=sail_top - 5)


def sloop() -> list[list]:
    px = pad_top(widen(t1(), 8), PAD_TOP)
    mx = MAST_X  # 끼워 넣은 줄(24)보다 오른쪽 → +8
    mx += 8
    sail_top = PAD_TOP + 6
    topsail(px, mx, sail_top)
    # 앞 삼각돛(지브): 윗돛 오른쪽 꼭대기에서 뱃머리 끝으로 내려가는 빗변, 주돛 오른쪽 빈 곳만 칠한다.
    w = len(px[0])
    top_y, bottom_y = sail_top - 6, PAD_TOP + 26
    x0, x1 = mx + 3, w - 6
    for y in range(top_y, bottom_y + 1):
        t = (y - top_y) / (bottom_y - top_y)
        right = round(x0 + (x1 - x0) * t)
        for x in range(mx + 2, right + 1):
            if px[y][x] is None and any(px[y][xx] is not None for xx in range(mx + 2, x)):
                px[y][x] = SAIL
    mast(px, mx, 1, PAD_TOP + 4)
    pennant(px, mx + 2, 1, 9, RED)
    _b.outline(px)
    return px


PORTS: list[tuple[int, int]] = []


def warship_shape(sail_c, stripe_c, tatter: bool) -> list[list]:
    base = t1()
    hull = widen([row if y >= HULL_TOP else [None] * len(row) for y, row in enumerate(base)], 16)
    rig = [row if y < HULL_TOP else [None] * len(row) for y, row in enumerate(base)]
    w = len(hull[0])
    px = pad_top(hull, PAD_TOP)
    # 돛대 둘: 뒤(고물 쪽, x+0)를 먼저, 앞(x+18)을 위에 — 앞 돛이 뒤 돛을 가린다.
    for off in (0, 18):
        for y, row in enumerate(rig):
            for x, c in enumerate(row):
                if c is not None and 0 <= x + off < w:
                    if c == SAIL:
                        c = sail_c
                    elif c == STRIPE:
                        c = stripe_c
                    px[PAD_TOP + y][x + off] = c
        topsail(px, MAST_X + off, PAD_TOP + 6)
        mast(px, MAST_X + off, 1 + (4 if off == 0 else 0), PAD_TOP + 30)
    for y in range(len(px)):
        for x in range(w):
            if px[y][x] in (SAIL, STRIPE) and sail_c != SAIL:
                px[y][x] = sail_c if px[y][x] == SAIL else stripe_c
    pennant(px, MAST_X + 20, 1, 11, RED)
    # 고물 선실: 갑판 위 왼쪽 상자 + 불 켜진 창 2
    deck = PAD_TOP + 30
    for y in range(deck - 6, deck):
        for x in range(4, 15):
            px[y][x] = HULL if y > deck - 6 else HULL_LINE
    for x in (6, 7, 11, 12):
        px[deck - 4][x] = WINDOW
        px[deck - 3][x] = WINDOW
    # 금 띠 + 포문 한 줄 더 (선체 가운데 줄)
    for x in range(w):
        if px[PAD_TOP + 33][x] == HULL_LINE:
            px[PAD_TOP + 33][x] = GOLD
    PORTS.clear()
    for y in (PAD_TOP + 36, PAD_TOP + 37):  # t1 포문(2×2 외곽선 색)
        for x in range(1, w - 1):
            if px[y][x] == K and px[y][x - 1] in (HULL, HULL_LINE, K) and _inside(px, x, y):
                PORTS.append((x, y))
    for x in range(14, w - 14, 9):
        if px[PAD_TOP + 39][x] == HULL and px[PAD_TOP + 39][x + 1] == HULL:
            for dx in (0, 1):
                for dy in (0, 1):
                    px[PAD_TOP + 39 + dy][x + dx] = K
                    PORTS.append((x + dx, PAD_TOP + 39 + dy))
    if tatter:
        for x in range(w):
            ys = [y for y in range(len(px)) if px[y][x] == sail_c]
            if ys and x % 5 in (1, 2):
                for y in ys[-2:]:
                    px[y][x] = None
    _b.outline(px)
    return px


def warship() -> list[list]:
    return warship_shape(SAIL, STRIPE, tatter=False)


GHOST_SWAP = {
    HULL: (78, 66, 92),
    HULL_LINE: (56, 46, 70),
    MAST: (44, 36, 56),
    MAST_SIDE: (56, 46, 70),
    GOLD: (120, 255, 200),
    WINDOW: (120, 255, 200),
    RED: (120, 255, 200),
    (170, 175, 190): (140, 150, 170),
    (110, 115, 130): (90, 96, 116),
}
GHOST_SAIL = (110, 220, 205, 170)  # 반투명 청록
GHOST_STRIPE = (60, 150, 160, 200)


def ghost() -> list[list]:
    px = warship_shape(GHOST_SAIL, GHOST_STRIPE, tatter=True)
    out = []
    for row in px:
        r = []
        for c in row:
            if c is None or len(c) == 4:
                r.append(c)
            else:
                r.append(GHOST_SWAP.get(c, c))
        out.append(r)
    for x, y in PORTS:  # 포문도 초록 빛
        out[y][x] = (120, 255, 200)
    return out


def _inside(px, x, y) -> bool:
    row = px[y]
    return any(c is not None and c != K for c in row[:x]) and any(c is not None and c != K for c in row[x + 1 :])


FILES = {
    "ship/ship_t2.png": sloop,
    "ship/ship_t3.png": warship,
    "ship/ship_t4.png": ghost,
}


def main(argv: list[str]) -> int:
    for stream in (sys.stdout, sys.stderr):
        stream.reconfigure(encoding="utf-8")
    check = "--check" in argv
    changed = []
    for rel, make in FILES.items():
        data = _b.write_png(make())
        target = ASSETS / rel
        if target.is_file() and target.read_bytes() == data:
            continue
        changed.append(rel)
        if not check:
            target.write_bytes(data)
    lic_path = ASSETS / "LICENSES.json"
    lic = json.loads(lic_path.read_text(encoding="utf-8"))
    files = dict(lic.get("files", {}))
    for rel in FILES:
        files[rel] = {"source": SOURCE, "license": "OWN"}
    text = json.dumps({**lic, "files": dict(sorted(files.items()))}, ensure_ascii=False, indent=2) + "\n"
    if lic_path.read_text(encoding="utf-8") != text:
        changed.append("LICENSES.json")
        if not check:
            lic_path.write_text(text, encoding="utf-8", newline="\n")
    if check:
        if changed:
            print("✗ 다시 굽기 결과가 다름: " + ", ".join(changed), file=sys.stderr)
            return 1
        print("✓ 배 등급 도트가 격자와 같다")
        return 0
    print(f"✓ {len(changed)}개 갱신" + (": " + ", ".join(changed) if changed else ""))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
