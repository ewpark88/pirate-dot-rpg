"""탑다운 지나가는 풍경 7종 (바다 분위기 탑다운판 — docs/specs/platform-fun-atmosphere.md §3). 위에서 내려다본 도트. OWN.

    python -I tools/art/gen_topdown_landmarks.py            # apps/game/assets/fx/td_land_<id>.png 에 쓴다
    python -I tools/art/gen_topdown_landmarks.py --check    # 쓰지 않고, 결과가 지금 파일과 다르면 실패

바다에 떠서 흐름과 함께 지나간다(배·적 아래 층). 시차 배경이라 디테일은 적게, 2~4색 덩어리. 프레임 2장(등대 불빛·고래 물 뿜기·
화산 불빛·유령선 흔들림, 나머지는 물결 테두리만 바뀜). island(야자섬) · lighthouse(등대 바위) · whale(고래) · wreck(난파선 잔해) ·
iceberg(빙산) · volcano_isle(화산섬) · ghost_ship_far(멀리 유령선, 반투명).
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
SOURCE = "자체 디자인 → tools/art/gen_topdown_landmarks.py 위에서 본 픽셀 격자"


def _load(name):
    spec = importlib.util.spec_from_file_location(name, HERE / f"{name}.py")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


_b = _load("gen_bosses")
_e = _load("gen_topdown_enemies")
Grid = _e.Grid
FOAM = (236, 248, 255)
SAND, SAND_D = (236, 214, 150), (204, 176, 110)
LEAF, LEAF_D = (70, 170, 80), (40, 120, 60)
ROCK, ROCK_D, ROCK_L = (110, 104, 100), (78, 72, 70), (146, 140, 134)


def _foam_ring(px, cx, cy, rx, ry, f):
    """물가 흰 거품 테두리(프레임마다 점 위치가 바뀜) — 외곽선 뒤에 얹어 검은 테가 생기지 않게. px를 돌려준다."""
    n = len(px)
    for k in range(48):
        a = k / 48 * 2 * math.pi
        if (k + (1 if f else 0)) % 3 == 0:
            continue
        x, y = int(cx + math.cos(a) * rx), int(cy + math.sin(a) * ry)
        if 0 <= x < n and 0 <= y < n and px[y][x] is None:
            px[y][x] = FOAM
    return px


def island(f):
    g = Grid(64)
    c = 32
    g.ellipse(c, c + 2, 25, 19, SAND_D)
    g.ellipse(c, c + 1, 23, 17, SAND)
    for dx, dy, r in ((-6, -2, 9), (7, 3, 8), (-1, 8, 6)):  # 야자 잎(위에서 본 별 모양 덩어리)
        for a in range(6):
            ang = a * math.pi / 3 + 0.3
            g.line(c + dx, c + dy, c + dx + math.cos(ang) * r, c + dy + math.sin(ang) * r, LEAF_D)
        g.ellipse(c + dx, c + dy, r * 0.55, r * 0.55, LEAF)
        g.put(c + dx, c + dy, (120, 80, 40))
    return _foam_ring(g.done(), c, c + 2, 27, 21, f)


def lighthouse(f):
    g = Grid(48)
    c = 24
    g.ellipse(c, c, 17, 15, ROCK_D)
    g.ellipse(c - 1, c - 1, 15, 13, ROCK)
    for dx, dy in ((-7, 4), (6, -5), (5, 7)):
        g.ellipse(c + dx, c + dy, 3, 2, ROCK_L)
    g.ellipse(c, c, 7, 7, (220, 60, 50))  # 탑(빨강·흰 고리)
    g.ellipse(c, c, 5, 5, (245, 245, 250))
    g.ellipse(c, c, 3, 3, (220, 60, 50))
    g.ellipse(c, c, 1.6, 1.6, (255, 236, 140) if f else (255, 200, 90))
    return _foam_ring(g.done(), c, c, 19, 17, f)


def whale(f):
    g = Grid(64)
    c = 32
    body, hi, belly = (60, 84, 120), (90, 118, 156), (150, 176, 200)
    sway = 2 if f else -2
    g.poly([(c + sway - 11, 60), (c + sway + 11, 60), (c + sway, 51)], body)  # 꼬리
    for side in (-1, 1):
        g.poly([(c + side * 8, c - 1), (c + side * 18, c + 8), (c + side * 8, c + 7)], body)
    g.ellipse(c, c, 10, 22, body, hi)
    g.ellipse(c, c + 4, 5, 12, belly)
    g.ellipse(c, c - 14, 1.4, 1.4, (30, 40, 60))  # 숨구멍
    if f:  # 물 뿜기(위에서 본 흰 물방울 꽃)
        for a in range(8):
            ang = a * math.pi / 4
            g.put(c + math.cos(ang) * 4, c - 14 + math.sin(ang) * 4, FOAM)
            g.put(c + math.cos(ang) * 6, c - 14 + math.sin(ang) * 6, (200, 230, 255))
    return g.done()


def wreck(f):
    g = Grid(56)
    c = 28
    wood, wood_d, sail = (120, 84, 54), (84, 58, 36), (196, 186, 160)
    g.poly([(c - 8, 6), (c + 2, 4), (c + 10, 30), (c + 4, 50), (c - 10, 48), (c - 12, 22)], wood_d)  # 기운 선체
    g.poly([(c - 6, 9), (c + 1, 8), (c + 7, 30), (c + 2, 46), (c - 8, 44), (c - 9, 22)], wood)
    for y in range(12, 44, 4):
        g.line(c - 8, y, c + 6, y + 1, wood_d)
    g.poly([(c + 8, 18), (c + 22, 24), (c + 14, 34)], sail)  # 찢긴 돛
    g.line(c - 2, 14, c + 18, 22, (70, 48, 30))  # 부러진 돛대
    for dx, dy in ((-18, 10), (16, 44), (-16, 40)):  # 떠다니는 판자
        g.line(c + dx, c - 28 + dy, c + dx + 5, c - 27 + dy + (1 if f else 0), wood)
    return g.done()


def iceberg(f):
    g = Grid(56)
    c = 28
    ice, ice_d, ice_l = (210, 236, 252), (150, 196, 230), (245, 252, 255)
    g.poly([(8, 20), (20, 6), (38, 8), (50, 22), (46, 42), (28, 50), (10, 40)], ice_d)
    g.poly([(11, 21), (21, 9), (37, 11), (47, 23), (43, 40), (28, 47), (13, 39)], ice)
    g.poly([(20, 14), (32, 12), (36, 24), (26, 30), (18, 24)], ice_l)
    g.line(22, 34, 34, 38, ice_d)
    return _foam_ring(g.done(), c, c, 25, 21, f)


def volcano_isle(f):
    g = Grid(64)
    c = 32
    g.ellipse(c, c, 25, 22, (60, 54, 56))
    g.ellipse(c, c, 19, 17, (84, 76, 76))
    g.ellipse(c, c, 12, 11, (104, 94, 92))
    g.ellipse(c, c, 6, 6, (40, 30, 30))
    g.ellipse(c, c, 4, 4, (255, 120, 40) if f else (255, 170, 60))
    for a in range(5):  # 용암 줄기
        ang = a * 1.25 + 0.4
        g.line(c + math.cos(ang) * 6, c + math.sin(ang) * 6, c + math.cos(ang) * 16, c + math.sin(ang) * 15, (230, 90, 30))
    return _foam_ring(g.done(), c, c, 27, 24, f)


def ghost_ship_far(f):
    spec = importlib.util.spec_from_file_location("gen_topdown_bosses", HERE / "gen_topdown_bosses.py")
    bosses = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(bosses)
    px = bosses.ship_boss("ghost_ship", 1 if f else 0)
    # 반투명(멀리 안개 속): 알파 110, 색은 그대로
    return [[None if p is None else (*p[:3], 110) for p in row] for row in px]


LANDMARKS = {"island": island, "lighthouse": lighthouse, "whale": whale, "wreck": wreck, "iceberg": iceberg,
             "volcano_isle": volcano_isle, "ghost_ship_far": ghost_ship_far}


def files():
    out = {}
    for name, make in LANDMARKS.items():
        a, b = make(False), make(True)
        out[f"fx/td_land_{name}.png"] = [ra + rb for ra, rb in zip(a, b)]
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
        print("✓ 탑다운 풍경이 격자와 같다")
        return 0
    print(f"✓ {len(changed)}개 갱신 ({len(made)}종)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
