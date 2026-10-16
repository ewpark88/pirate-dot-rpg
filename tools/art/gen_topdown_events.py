"""탑다운 돌발 이벤트 그림 (지루함 해소 — S2 계약 c5193fa: EnemyView.eventKind·SeaEventView). 위에서 본 도트, 머리가 위, 2프레임. OWN.

    python -I tools/art/gen_topdown_events.py            # apps/game/assets/fx/td_event_<id>.png 에 쓴다
    python -I tools/art/gen_topdown_events.py --check    # 쓰지 않고, 결과가 지금 파일과 다르면 실패

goldfish(황금 물고기 — 탭해서 잡는 반짝이는 금붕어, 16칸) · sea_serpent(습격 바다뱀, 32칸 긴 몸) ·
merchant_ship(상인선 — 탑다운 배 그리기 팔레트: 초록 돛·흰 테·상자 짐) · bottle(떠다니는 편지 유리병, 16칸).
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
SOURCE = "자체 디자인 → tools/art/gen_topdown_events.py 위에서 본 픽셀 격자"


def _load(name):
    spec = importlib.util.spec_from_file_location(name, HERE / f"{name}.py")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


_b = _load("gen_bosses")
_e = _load("gen_topdown_enemies")
_s = _load("gen_topdown_ships")
Grid = _e.Grid
W = (250, 250, 255)
GOLD, GOLD_D, GOLD_L = (250, 196, 50), (214, 140, 30), (255, 238, 150)


def goldfish(f):
    px = _e.fish(16, GOLD, GOLD_L, GOLD_D, f, length=0.95, width=1.1)
    # 반짝임 별 두 개(프레임마다 자리 바뀜)
    for x, y in ((2, 3), (13, 11)) if f else ((13, 2), (2, 12)):
        for dx, dy in ((0, 0), (1, 0), (-1, 0), (0, 1), (0, -1)):
            if 0 <= x + dx < 16 and 0 <= y + dy < 16 and px[y + dy][x + dx] is None:
                px[y + dy][x + dx] = W
    return px


def sea_serpent(f):
    g = Grid(32)
    body, belly, fin = (60, 130, 110), (130, 200, 160), (220, 90, 70)
    ph = 0 if f else math.pi
    for k in range(40):
        t = k / 39
        y = 3 + t * 27
        x = 16 + math.sin(t * 6 + ph) * 6 * (0.3 + t)
        r = 3.6 - 2.2 * t
        g.ellipse(x, y, r, r, body if k % 5 else belly)
        if k % 6 == 3:  # 등지느러미 가시
            g.put(x, y - r, fin)
    g.ellipse(16, 4, 4.2, 3.6, body, belly)  # 머리
    for side in (-1, 1):
        g.put(16 + side * 2, 3, (255, 230, 90))
        g.put(16 + side * 3, 1, fin)  # 뿔
    return g.done()


def merchant_ship(f):
    pal = {_s.RIM: (220, 220, 210), _s.RIM_D: (170, 170, 160), _s.DECK: (196, 160, 110), _s.DECK_L: (214, 180, 130),
           _s.SEAM: (160, 126, 82), _s.MAST: (90, 60, 34), _s.YARD: (110, 74, 40), _s.SAIL: (90, 180, 110),
           _s.SAIL_D: (60, 140, 80), _s.SAIL_L: (140, 220, 150)}
    _s.GHOST = pal
    s = _s.Ship(1)
    s.t = dict(s.t, ghost=True)
    px = s.blank()
    for layer in (_s.hull(s, 1), _s.cargo(s, 4 if f else 3), _s.sail(s, 2)):
        for y in range(s.h):
            for x in range(s.w):
                if layer[y][x] is not None:
                    px[y][x] = layer[y][x]
    # 앞 돛에 금화 표시
    _s.art(px, s.cx - 2, s.mast_y[0] + 2, [".yyy.", "yyYyy", ".yyy."], {"y": GOLD, "Y": GOLD_L})
    return px


def bottle(f):
    g = Grid(16)
    glass, glass_l, cork, paper = (120, 200, 220), (200, 240, 250), (170, 120, 70), (245, 235, 200)
    tilt = 0.5 if f else -0.5
    for k in range(10):
        y = 4 + k
        x = 8 + tilt * (k - 5) * 0.3
        r = 2.6 if k > 2 else 1.4
        g.ellipse(x, y, r, 1, glass)
    g.line(8 + tilt * -1.5, 6, 8 + tilt * 1.2, 11, paper)  # 둘둘 만 편지
    g.put(8 - tilt * 1.5, 2, cork)
    g.put(8 - tilt * 1.5, 3, cork)
    g.put(7, 7, glass_l)
    px = g.done()
    for k in range(16):  # 물결 반짝임
        a = k / 16 * 2 * math.pi
        if (k + (1 if f else 0)) % 4 == 0:
            x, y = int(8 + math.cos(a) * 7), int(9 + math.sin(a) * 5)
            if 0 <= x < 16 and 0 <= y < 16 and px[y][x] is None:
                px[y][x] = (236, 248, 255)
    return px


def chest(f):
    """떠내려온 보물상자(위에서 비스듬히): 나무 상자·금 띠·자물쇠, 둘째 프레임은 뚜껑 틈 금빛과 반짝임. 물결 거품 테."""
    g = Grid(24)
    wood, wood_d, wood_l = (150, 96, 50), (104, 64, 34), (186, 128, 72)
    g.poly([(4, 9), (19, 9), (19, 19), (4, 19)], wood_d)  # 몸통(앞면)
    g.poly([(5, 10), (18, 10), (18, 18), (5, 18)], wood)
    g.poly([(4, 4), (19, 4), (20, 9), (3, 9)], wood_d)  # 뚜껑(윗면)
    g.poly([(5, 5), (18, 5), (19, 8), (4, 8)], wood_l)
    for x in (7, 16):  # 금 띠
        g.line(x, 4, x, 19, GOLD_D)
        g.line(x, 5, x, 18, GOLD)
    g.line(3, 9, 20, 9, GOLD_D)
    if f:  # 뚜껑 틈 금빛
        g.line(5, 9, 18, 9, GOLD_L)
    g.ellipse(11.5, 11, 1.6, 1.6, GOLD, GOLD_L)  # 자물쇠
    g.put(11.5, 12, wood_d)
    px = g.done()
    for x, y in ((3, 2), (20, 14)) if f else ((19, 2), (2, 15)):  # 반짝임
        for dx, dy in ((0, 0), (1, 0), (-1, 0), (0, 1), (0, -1)):
            if 0 <= x + dx < 24 and 0 <= y + dy < 24 and px[y + dy][x + dx] is None:
                px[y + dy][x + dx] = GOLD_L
    for k in range(24):  # 물가 거품
        a = k / 24 * 2 * math.pi
        if (k + (1 if f else 0)) % 3:
            x, y = int(12 + math.cos(a) * 11), int(13 + math.sin(a) * 9)
            if 0 <= x < 24 and 0 <= y < 24 and px[y][x] is None:
                px[y][x] = (236, 248, 255)
    return px


EVENTS = {"goldfish": goldfish, "sea_serpent": sea_serpent, "merchant_ship": merchant_ship, "bottle": bottle, "chest": chest}


def files():
    return {f"fx/td_event_{k}.png": [ra + rb for ra, rb in zip(m(False), m(True))] for k, m in EVENTS.items()}


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
        print("✓ 탑다운 이벤트 그림이 격자와 같다")
        return 0
    print(f"✓ {len(changed)}개 갱신 ({len(made)}종)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
