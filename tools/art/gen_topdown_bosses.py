"""탑다운 보스 13종 (T2). 위에서 내려다본 도트, 머리(뱃머리)가 위. 프레임 2장. OWN.

    python -I tools/art/gen_topdown_bosses.py            # apps/game/assets/bosses/td_<kind>.png 에 쓴다
    python -I tools/art/gen_topdown_bosses.py --check    # 쓰지 않고, 결과가 지금 파일과 다르면 실패

해적선 6종(enemy_ship·raider_ship·storm_pirate·icebreaker·fire_pirate·ghost_ship)은 탑다운 내 배 그리기
(gen_topdown_ships.py, 돛대 둘)를 팔레트만 바꿔 쓰고 큰 돛에 문장(해골·번개·눈송이·불꽃·초록 해골·빨간 띠)을 얹는다.
생물 7종(giant_hermit·iceberg_walrus·thunder_ray·lava_whale·kraken·kraken_tentacle·ghost_admiral)과 deep_sub는 새로 그린다.
옆모습 보스(assets/bosses/<kind>.png)와 같은 색·특징. 같은 입력이면 같은 바이트.
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
SOURCE = "Pirate Busters v0.24 자체 IP(보스 디자인) → tools/art/gen_topdown_bosses.py 위에서 본 픽셀 격자"


def _load(name):
    spec = importlib.util.spec_from_file_location(name, HERE / f"{name}.py")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


_b = _load("gen_bosses")
_s = _load("gen_topdown_ships")
_e = _load("gen_topdown_enemies")
Grid = _e.Grid
K, W = (27, 23, 38), (245, 245, 250)


# ---------- 해적선 ----------
def _pal(rim, rim_d, deck, deck_l, seam, sail, sail_d, sail_l, mast=(56, 36, 22), yard=(70, 46, 26)):
    return {_s.RIM: rim, _s.RIM_D: rim_d, _s.DECK: deck, _s.DECK_L: deck_l, _s.SEAM: seam, _s.MAST: mast, _s.YARD: yard,
            _s.SAIL: sail, _s.SAIL_D: sail_d, _s.SAIL_L: sail_l}


DARK_WOOD = dict(rim=(96, 60, 34), rim_d=(70, 42, 24), deck=(150, 104, 64), deck_l=(168, 120, 78), seam=(116, 78, 46))
SHIPS = {
    "enemy_ship": (_pal(**DARK_WOOD, sail=(60, 50, 60), sail_d=(40, 32, 42), sail_l=(84, 72, 84)), "band"),
    "raider_ship": (_pal(**DARK_WOOD, sail=(150, 40, 34), sail_d=(110, 28, 24), sail_l=(186, 64, 54)), "skull"),
    "storm_pirate": (_pal(**DARK_WOOD, sail=(70, 76, 96), sail_d=(50, 54, 72), sail_l=(96, 104, 126)), "bolt"),
    "icebreaker": (_pal(rim=(120, 130, 150), rim_d=(90, 100, 120), deck=(170, 180, 196), deck_l=(196, 206, 220),
                        seam=(140, 150, 168), sail=(220, 236, 250), sail_d=(170, 200, 230), sail_l=(245, 250, 255)), "flake"),
    "fire_pirate": (_pal(rim=(56, 44, 40), rim_d=(36, 28, 26), deck=(96, 76, 66), deck_l=(116, 92, 80), seam=(72, 56, 48),
                         sail=(230, 110, 40), sail_d=(180, 70, 30), sail_l=(255, 170, 70)), "flame"),
    "ghost_ship": (_pal(rim=(78, 66, 92), rim_d=(56, 46, 70), deck=(104, 92, 120), deck_l=(122, 110, 140),
                        seam=(84, 72, 100), sail=(160, 180, 210), sail_d=(120, 140, 176), sail_l=(200, 216, 236),
                        mast=(44, 36, 56), yard=(56, 46, 70)), "ghost"),
}
EMBLEMS = {
    "skull": (["..www..", ".wwwww.", "wwkwkww", "wwwwwww", ".wwkww.", "..w.w.."], {"w": W, "k": K}),
    "bolt": (["...yy", "..yy.", ".yyyy", "..yy.", ".yy..", "yy..."], {"y": (250, 214, 70)}),
    "flake": (["..b..", "b.b.b", ".bbb.", "bbbbb", ".bbb.", "b.b.b", "..b.."], {"b": (80, 150, 230)}),
    "flame": (["..y..", ".yry.", ".yrry", "yrrry", "yrrry", ".yyy."], {"y": (255, 220, 90), "r": (220, 60, 30)}),
    "ghost": (["..ggg..", ".ggggg.", "ggkgkgg", "ggggggg", ".ggkgg.", "..g.g.."], {"g": (140, 240, 170), "k": K}),
    "band": ([], {}),
}


def ship_boss(kind: str, frame: int):
    pal, emblem = SHIPS[kind]
    _s.GHOST = pal
    s = _s.Ship(2)
    s.t = dict(s.t, ghost=True, jib=True)
    layers = [_s.base(s), _s.hull(s, 3 if kind == "icebreaker" else 2), _s.cargo(s, 2), _s.cannon(s, 4),
              _s.sail(s, 2), _s.crowsnest(s, 2)]
    px = s.blank()
    for layer in layers:
        for y in range(s.h):
            for x in range(s.w):
                if layer[y][x] is not None:
                    px[y][x] = layer[y][x]
    if emblem == "band":  # 검은 돛에 빨간 띠
        for y in range(s.h):
            for x in range(s.w):
                if px[y][x] == pal[_s.SAIL] and (y - s.main) % 5 == 2:
                    px[y][x] = (200, 50, 44)
    else:
        rows, p = EMBLEMS[emblem]
        # 앞 돛 가운데(큰 돛대 위 망루를 피해서)
        _s.art(px, s.cx - len(rows[0]) // 2, s.mast_y[0] + 1, rows, p)
    if kind == "icebreaker":  # 뱃머리 얼음 깨는 쇠 뿔
        for k in range(6):
            _s.put(px, s.cx, s.top - 3 + k, (220, 230, 245))
            _s.put(px, s.cx - 1, s.top + k, (170, 182, 200))
            _s.put(px, s.cx + 1, s.top + k, (170, 182, 200))
    if frame:  # 둘째 프레임: 돛 밝은 줄과 보통 줄을 바꿔 바람에 펄럭이는 듯
        light, mid = pal[_s.SAIL_L], pal[_s.SAIL]
        for y in range(s.h):
            for x in range(s.w):
                if px[y][x] == light:
                    px[y][x] = mid
                elif px[y][x] == mid and px[y - 1][x] == pal[_s.YARD]:
                    px[y][x] = light
    return px


# ---------- 생물 ----------
def giant_hermit(f):
    g = Grid(56)
    c = 28
    shell, ring, claw, claw_d = (230, 206, 150), (180, 150, 96), (220, 70, 60), (150, 40, 40)
    leg = 1 if f else -1
    for side in (-1, 1):
        for i in range(3):
            g.line(c + side * 8, c - 6 + i * 4, c + side * 16, c - 8 + i * 4 + leg * 2, claw_d)
        g.ellipse(c + side * 9, c - 18, 6, 5, claw)
        g.put(c + side * (6 if f else 4), c - 22, None)
    g.ellipse(c, c - 12, 7, 5, claw)
    for side in (-1, 1):
        g.ellipse(c + side * 3, c - 17, 1.6, 1.6, W)
        g.put(c + side * 3, c - 17, K)
    g.ellipse(c, c + 6, 15, 16, shell)
    for k in range(70):  # 나선
        t = k / 70 * 4.2 * math.pi
        r = 1 + t * 1.0
        g.put(c + math.cos(t) * r, c + 6 + math.sin(t) * r, ring)
    return g.done()


def iceberg_walrus(f):
    g = Grid(56)
    c = 28
    ice, ice_d, fur, fur_d = (230, 242, 252), (176, 206, 232), (150, 104, 74), (110, 74, 52)
    g.poly([(6, 18), (20, 6), (40, 8), (52, 22), (48, 44), (30, 52), (10, 44)], ice_d)
    g.poly([(8, 19), (21, 8), (39, 10), (49, 23), (46, 42), (30, 49), (12, 43)], ice)
    flip = 1 if f else -1
    for side in (-1, 1):
        g.ellipse(c + side * 10, c + 2 + flip * side, 4, 2.4, fur_d)
    g.ellipse(c, c + 4, 10, 13, fur, (176, 126, 92))
    g.ellipse(c, c - 9, 6.5, 5.5, fur)
    for side in (-1, 1):
        g.line(c + side * 2, c - 10, c + side * 3, c - 17, W)  # 엄니
        g.put(c + side * 3, c - 11, K)
    return g.done()


def thunder_ray(f):
    g = Grid(56)
    c = 28
    body, belly, bolt = (70, 76, 130), (100, 106, 170), (250, 214, 70)
    flap = 3 if f else 0
    g.poly([(c, 6), (c + 26, c + flap), (c + 6, c + 12), (c, c + 18), (c - 6, c + 12), (c - 26, c + flap)], body)
    g.poly([(c, 12), (c + 10, c + 2), (c, c + 12), (c - 10, c + 2)], belly)
    g.line(c, c + 18, c, 54, (50, 54, 96))
    g.line(c - 2, 52, c + 2, 52, bolt)
    for pts in (((c - 18, c - 2), (c - 12, c + 2), (c - 15, c + 4), (c - 9, c + 8)),
                ((c + 18, c - 2), (c + 12, c + 2), (c + 15, c + 4), (c + 9, c + 8))):
        for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
            g.line(x0, y0, x1, y1, bolt)
    for side in (-1, 1):
        g.put(c + side * 3, 11, W)
    return g.done()


def lava_whale(f):
    g = Grid(56)
    c = 28
    body, hi, lava = (64, 60, 66), (96, 90, 96), (255, 130, 40)
    sway = 2 if f else -2
    g.poly([(c + sway - 10, 54), (c + sway + 10, 54), (c + sway, 46)], body)  # 꼬리
    for side in (-1, 1):
        g.poly([(c + side * 8, c - 2), (c + side * 18, c + 6), (c + side * 8, c + 6)], body)
    g.ellipse(c, c - 2, 10, 22, body, hi)
    for dx, dy in ((-3, -6), (2, -2), (-2, 4), (3, 9), (0, 14)):
        g.line(c + dx, c + dy, c + dx + 2, c + dy + 2, lava)
    g.ellipse(c, c - 16, 1.5, 1.5, K)  # 숨구멍
    for k in range(4):  # 불꽃 물줄기
        g.put(c + (k % 2) * (1 if f else -1), c - 18 - k, lava if k % 2 else (255, 220, 90))
    for side in (-1, 1):
        g.put(c + side * 7, c - 14, (255, 220, 90))
    return g.done()


def kraken(f):
    g = Grid(56)
    c = 28
    body, hi, spot = (130, 70, 170), (170, 110, 210), (190, 140, 230)
    for i in range(8):
        a = i * math.pi / 4 + math.pi / 8
        for k in range(22):
            t = k / 21
            r = 9 + t * 17
            bend = math.sin(t * 3 + i + (1 if f else 0)) * 0.35
            x = c + math.cos(a + bend) * r
            y = c + 2 + math.sin(a + bend) * r
            g.ellipse(x, y, (2.6 - 1.6 * t), (2.6 - 1.6 * t), body if k % 4 else spot)
    g.ellipse(c, c, 12, 12, body, hi)
    for side in (-1, 1):
        g.ellipse(c + side * 5, c - 2, 3, 3, (250, 214, 70))
        g.ellipse(c + side * 5, c - 2, 1, 2, K)
    for dx, dy in ((-6, 6), (5, 7), (0, 9)):
        g.put(c + dx, c + dy, spot)
    return g.done()


def kraken_tentacle(f):
    g = Grid(32)
    body, spot = (130, 70, 170), (190, 140, 230)
    for k in range(30):
        t = k / 29
        x = 16 + math.sin(t * 3.2 + (0.8 if f else 0)) * 5 * t
        y = 30 - t * 28
        g.ellipse(x, y, 3.6 - 2.6 * t, 3.6 - 2.6 * t, body)
        if k % 4 == 0:
            g.put(x, y, spot)
    return g.done()


def ghost_admiral(f):
    g = Grid(56)
    c = 28
    coat, coat_d, mist, hat, gold = (60, 56, 96), (40, 36, 70), (170, 236, 230), (36, 32, 48), (242, 201, 76)
    for k in range(10):  # 안개 꼬리
        x = c + math.sin(k * 0.8 + (1.2 if f else 0)) * 3
        g.ellipse(x, c + 8 + k * 2, 9 - k * 0.7, 2.2, mist)
    arm = 2 if f else -1
    g.line(c + 10, c - 2, c + 20, c - 8 + arm, (200, 210, 220))  # 칼
    g.line(c - 10, c, c - 16, c + 6, coat_d)
    g.ellipse(c, c + 2, 11, 9, coat, (84, 80, 124))
    for dy in (-2, 2, 6):
        g.put(c, c + dy, gold)
    g.poly([(c - 15, c - 6), (c + 15, c - 6), (c, c - 22)], hat)  # 삼각 모자(위에서)
    g.poly([(c - 12, c - 7), (c + 12, c - 7), (c, c - 19)], (54, 48, 70))
    g.ellipse(c, c - 12, 2, 2, W)
    g.line(c - 14, c - 6, c + 14, c - 6, gold)
    return g.done()


def deep_sub(f):
    g = Grid(56)
    c = 28
    body, hi, dark, glass = (240, 196, 50), (255, 230, 120), (190, 140, 30), (120, 220, 240)
    for side in (-1, 1):  # 꼬리 날개
        g.poly([(c, c + 16), (c + side * 13, c + 25), (c, c + 25)], dark)
    blade = 3 if f else -3
    g.line(c - blade, c + 26, c + blade, c + 26, (120, 120, 130))
    g.ellipse(c, c, 12, 25, body, hi)
    g.ellipse(c, c - 2, 5, 8, dark)  # 망루
    g.ellipse(c, c - 3, 3.4, 6, body)
    g.line(c, c - 10, c, c - 14, (90, 90, 100))
    for dy in (-16, 8, 15):
        g.ellipse(c, c + dy, 2.2, 2.2, glass)
    return g.done()


CREATURES = {"giant_hermit": giant_hermit, "iceberg_walrus": iceberg_walrus, "thunder_ray": thunder_ray,
             "lava_whale": lava_whale, "kraken": kraken, "kraken_tentacle": kraken_tentacle,
             "ghost_admiral": ghost_admiral, "deep_sub": deep_sub}


def files():
    out = {}
    for kind in SHIPS:
        a, b = ship_boss(kind, 0), ship_boss(kind, 1)
        out[f"bosses/td_{kind}.png"] = [ra + rb for ra, rb in zip(a, b)]
    for kind, make in CREATURES.items():
        a, b = make(False), make(True)
        out[f"bosses/td_{kind}.png"] = [ra + rb for ra, rb in zip(a, b)]
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
        print("✓ 탑다운 보스가 격자와 같다")
        return 0
    print(f"✓ {len(changed)}개 갱신 ({len(made)}종)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
