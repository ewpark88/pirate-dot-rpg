"""앱 아이콘 원본 격자 생성 (docs/store/icon.md 4절). 도형 → 문자 격자 → PNG, 자동 1px 외곽선 (27,23,38).

    python -I tools/art/gen_app_icon.py            # tools/art/icon/ 에 쓴다
    python -I tools/art/gen_app_icon.py --check    # 쓰지 않고, 결과가 지금 파일과 다르면 실패

만드는 것: foreground 54 · background 54 · monochrome 54 · legacy 24 · splash 48 · store 64.
적용은 platform(S5): python -I apps/game/android/icon/apply_icons.py --src tools/art/icon --bg "#5AA9E6" --splash-bg "#5AA9E6"
팔레트는 배 스프라이트 ship_t1·기준 장면(battle_ship.gif)의 색. 원본은 앱에 번들하지 않는다(라이선스 OWN, 이 스크립트가 원본).
같은 입력이면 같은 바이트(다시 굽기 가능).
"""

from __future__ import annotations

import importlib.util
import sys

sys.dont_write_bytecode = True
from pathlib import Path

HERE = Path(__file__).resolve().parent
OUT = HERE / "icon"

_spec = importlib.util.spec_from_file_location("gen_ui_icons", HERE / "gen_ui_icons.py")
_ui = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_ui)

PALETTE = {
    **_ui.PALETTE,
    "W": (240, 232, 210),  # 돛 (ship_t1)
    "h": (140, 90, 50),  # 선체
    "H": (95, 58, 32),  # 판자 줄
    "D": (70, 44, 26),  # 돛대
    "u": (47, 98, 196),  # 돛 줄무늬
    "K": (52, 46, 68),  # 해골 깃발 바탕
    "R": (220, 70, 60),
    "1": (90, 169, 230),  # 하늘 띠 (fx_map backgroundLayout)
    "2": (126, 196, 240),
    "3": (168, 220, 248),
    "4": (205, 238, 252),
    "5": (47, 143, 216),  # 바다 띠
    "6": (36, 112, 186),
    "7": (29, 79, 156),
    "8": (191, 243, 255),  # 물결
    "9": (95, 211, 243),
    "m": (255, 255, 255),  # 단색 아이콘
}
_ui.PALETTE = PALETTE

OUTLINE = "k"
BG_COLOR = "#5AA9E6"


def grid(w: int, h: int) -> list[list[str]]:
    return [["."] * w for _ in range(h)]


def rect(g, x0, y0, x1, y1, ch):
    for y in range(max(0, y0), min(len(g), y1 + 1)):
        for x in range(max(0, x0), min(len(g[0]), x1 + 1)):
            g[y][x] = ch


def outline(g):
    """투명 칸 중 상하좌우에 그림이 닿는 칸을 외곽선으로."""
    h, w = len(g), len(g[0])
    marks = []
    for y in range(h):
        for x in range(w):
            if g[y][x] != ".":
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and g[ny][nx] not in (".", OUTLINE):
                    marks.append((x, y))
                    break
    for x, y in marks:
        g[y][x] = OUTLINE


# 손으로 맞춘 줄별 칸: (행, 시작 x, 끝 x, 색). 외곽선은 outline()이 바깥에 1px 붙인다. ship_t1 비율(큰 돛·넓고 바닥 평평한 선체·뱃머리 오른쪽).
SHIP30 = [
    *[(r, 16, 22, "K") for r in range(1, 6)],
    (6, 9, 21, "W"), (7, 9, 21, "W"), (8, 8, 22, "W"), (9, 8, 22, "W"), (10, 8, 23, "W"),
    (11, 7, 23, "u"), (12, 7, 24, "u"), (13, 7, 24, "W"), (14, 7, 25, "W"), (15, 6, 25, "W"),
    (16, 6, 26, "W"), (17, 6, 26, "W"),
    (19, 22, 25, "g"), (19, 4, 4, "H"), (19, 8, 8, "H"), (19, 12, 12, "H"),
    (20, 1, 28, "H"), (21, 1, 28, "h"), (22, 2, 28, "h"), (23, 3, 27, "H"),
    (24, 4, 26, "h"), (25, 5, 25, "h"), (26, 6, 24, "H"), (27, 7, 23, "h"),
    *[(r, 15, 15, "D") for r in range(1, 20)],  # 돛대는 돛 위로 (ship_t1)
]
SHIP30_DETAIL = [
    (17, 2, "w"), (18, 2, "w"), (19, 2, "w"), (20, 2, "w"), (21, 2, "w"),
    (17, 3, "w"), (18, 3, "k"), (19, 3, "w"), (20, 3, "k"), (21, 3, "w"),
    (17, 4, "w"), (18, 4, "w"), (19, 4, "w"), (20, 4, "w"), (21, 4, "w"),
    (18, 5, "w"), (20, 5, "w"),
    (8, 22, "k"), (14, 22, "k"), (20, 22, "k"),
]
SHIP18 = [
    *[(r, 9, 13, "K") for r in range(1, 4)],
    (4, 5, 12, "W"), (5, 5, 12, "W"), (6, 4, 13, "u"), (7, 4, 13, "W"), (8, 4, 14, "W"),
    (9, 3, 14, "W"), (10, 3, 14, "W"),
    (12, 1, 16, "H"), (13, 1, 16, "h"), (14, 2, 15, "h"), (15, 3, 14, "H"), (16, 4, 13, "h"),
    *[(r, 8, 8, "D") for r in range(1, 12)],
]
SHIP18_DETAIL = [(10, 2, "w"), (11, 2, "w"), (12, 2, "w"), (11, 3, "w"), (5, 13, "k"), (9, 13, "k"), (8, 6, "D")]


def ship(spans, detail, size: int, scale: float = 1.0, skull_big: bool = False) -> list[list[str]]:
    """줄별 칸을 [scale]배로 칠하고(칸 단위라 모양이 깨지지 않음) 외곽선 → 세부(해골·포문)."""
    g = grid(size, size)
    for r, x0, x1, ch in spans:
        for y in range(int(r * scale), int((r + 1) * scale)):
            rect(g, round(x0 * scale), y, round((x1 + 1) * scale) - 1, y, ch)
    outline(g)
    for x, y, ch in detail:
        if skull_big and ch in "wk" and y < 6:
            continue
        for yy in range(int(y * scale), int((y + 1) * scale)):
            for xx in range(round(x * scale), round((x + 1) * scale)):
                g[yy][xx] = ch
    return g


SKULL_BIG = [".wwwww.", "wwwwwww", "wkkwkkw", "wkkwkkw", "wwwkwww", ".wwwww.", ".w.w.w."]


def paste(dst, src, ox, oy):
    for y, row in enumerate(src):
        for x, ch in enumerate(row):
            if ch != "." and 0 <= oy + y < len(dst) and 0 <= ox + x < len(dst[0]):
                dst[oy + y][ox + x] = ch


def sea_sky(size: int, horizon: int) -> list[list[str]]:
    """기준 장면 하늘 4단 + 바다 3단 + 물결 대시 (fx_map backgroundLayout 비율)."""
    g = grid(size, size)
    sky = ["1", "2", "3", "4"]
    for y in range(size):
        if y < horizon:
            band = sky[min(3, y * 4 // horizon)]
        else:
            k = (y - horizon) * 3 // max(1, size - horizon)
            band = "567"[min(2, k)]
        rect(g, 0, y, size - 1, y, band)
    gap = max(6, size // 6)
    for i, y in enumerate((horizon + 3, horizon + (size - horizon) * 2 // 3)):
        if y >= size:
            continue
        for x in range((i * gap) // 2, size, gap):
            rect(g, x, y, x + max(1, size // 18), y, "8" if i == 0 else "9")
    # 구름 하나 (왼쪽 위)
    cw = max(4, size // 6)
    cx, cy = size // 8, size // 7
    rect(g, cx, cy, cx + cw, cy + 1, "w")
    rect(g, cx + 1, cy - 1, cx + cw - 2, cy - 1, "w")
    return g


def to_rows(g) -> list[str]:
    return ["".join(r) for r in g]


def build() -> dict[str, list[str]]:
    s30 = ship(SHIP30, SHIP30_DETAIL, 30)
    fg = grid(54, 54)
    paste(fg, s30, 12, 12)
    mono = [["m" if ch != "." else "." for ch in row] for row in fg]
    bg = sea_sky(54, 35)  # 선체가 물에 반쯤 잠기게 (선체 33~39)

    legacy = sea_sky(24, 16)
    for y in range(24):  # 둥근 모서리
        for x in range(24):
            if min(x, 23 - x) + min(y, 23 - y) < 2:
                legacy[y][x] = "."
    paste(legacy, ship(SHIP18, SHIP18_DETAIL, 18), 3, 3)

    splash = grid(48, 48)
    paste(splash, s30, 9, 9)

    store = sea_sky(64, 42)
    big = ship(SHIP30, SHIP30_DETAIL, 46, 1.5, skull_big=True)
    for dy, row in enumerate(SKULL_BIG):  # 깃발(칸 24~34 × 1~8) 가운데
        for dx, ch in enumerate(row):
            if ch != ".":
                big[2 + dy][25 + dx] = ch
    paste(store, big, 9, 6)

    return {
        "foreground.png": to_rows(fg),
        "background.png": to_rows(bg),
        "monochrome.png": to_rows(mono),
        "legacy.png": to_rows(legacy),
        "splash.png": to_rows(splash),
        "store.png": to_rows(store),
    }


def main(argv: list[str]) -> int:
    for stream in (sys.stdout, sys.stderr):
        stream.reconfigure(encoding="utf-8")
    check = "--check" in argv
    changed = []
    for name, rows in build().items():
        data = _ui.png(rows)
        target = OUT / name
        if target.is_file() and target.read_bytes() == data:
            continue
        changed.append(name)
        if not check:
            OUT.mkdir(parents=True, exist_ok=True)
            target.write_bytes(data)
    if check:
        if changed:
            print("✗ 다시 굽기 결과가 다름: " + ", ".join(changed), file=sys.stderr)
            return 1
        print("✓ 앱 아이콘이 격자와 같다")
        return 0
    print(f"✓ {len(changed)}개 갱신 → {OUT}" + (" (배경색 " + BG_COLOR + ")" if changed else ""))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
