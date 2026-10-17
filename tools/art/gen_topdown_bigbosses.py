"""도감 v2 대보스 6종 (10단위 벽, docs/specs/platform-bestiary-v2.md). 위에서 본 도트, 머리가 위, 프레임 2장. OWN.

    python -I tools/art/gen_topdown_bigbosses.py            # assets/bosses/td_<id>.png + <id>.png(컷인 초상)
    python -I tools/art/gen_topdown_bigbosses.py --check    # 쓰지 않고, 결과가 지금 파일과 다르면 실패

sea_croc(산호) · monster_whale(폭풍) · ice_slime(빙하) · leviathan(화산) · kraken_titan(심해) · poseidon(유령).
프레임 88×88(보통 보스 56의 약 1.6배). 음영은 td_shade(입체·디더·부위 구분선). 같은 입력이면 같은 바이트.
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
SOURCE = "자작(코드) — tools/art/gen_topdown_bigbosses.py 위에서 본 픽셀 격자(입체 음영)"
N = 88
C = N / 2


def _load(name):
    spec = importlib.util.spec_from_file_location(name, HERE / f"{name}.py")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


_b = _load("gen_bosses")
_t = _load("td_shade")
Can, ramp, mix = _t.Can, _t.ramp, _t.mix
OUT = _b.OUTLINE
WHITE, BONE, GOLD = (250, 248, 236), (236, 226, 196), ramp((236, 182, 52))


def croc(f):
    """바다 악어: 긴 주둥이(이빨), 등 비늘 줄, 네 다리, 휘는 꼬리."""
    g = Can(N)
    skin, scute, belly = ramp((74, 128, 66)), ramp((104, 150, 70)), ramp((196, 196, 120))
    sw = 1 if f else -1
    # 꼬리(아래로, 프레임마다 휨)
    pts, rad = [], []
    for k in range(26):
        t = k / 25
        pts.append((C + math.sin(t * 2.6 + 0.4) * 9 * t * sw, 52 + t * 34))
        rad.append(7.5 - 6.3 * t)
    g.chain(pts, rad, skin)
    for k in range(2, 24, 3):  # 꼬리 가시
        x, y = pts[k]
        g.spike(x, y, x, y - 3, 1.6, scute)
    # 다리(위 팔꿈치 → 아래 발, 발가락 셋)
    for side in (-1, 1):
        for (ly, fwd) in ((30, -1), (54, 1)):
            step = 3 if f == (side > 0) else -2
            ex, ey = C + side * 16, ly + fwd * 1
            kx, ky = C + side * 22, ly + fwd * (7 + step)
            g.chain([(C + side * 10, ly), (ex, ey), (kx, ky)], [3.4, 2.6, 2.4], skin)
            for d in (-1, 0, 1):
                g.line(kx, ky, kx + side * 2.5 + d * 1.6, ky + fwd * 3 - d * fwd * 0.5, skin[0])
    # 몸통
    g.blob(C, 42, 13, 20, skin)
    # 등 비늘 두 줄 + 가운데 줄
    for y in range(28, 62, 4):
        for dx in (-7, -3, 3, 7):
            g.blob(C + dx, y + (abs(dx) == 3) * 2, 1.6, 1.4, scute, sep=False, lift=0.1 if abs(dx) == 3 else -0.05)
    for y in range(27, 63, 2):
        g.put(C, y, skin[0])
    # 머리·주둥이(하나의 쐐기, 끝이 둥근) — 2프레임째 입을 벌려 붉은 속
    gap = 1.4 if f else 0.0
    g.blob(C, 21, 10.5, 8, skin)
    g.poly([(C - 7.5 - gap, 20), (C + 7.5 + gap, 20), (C + 5 + gap, 3), (C - 5 - gap, 3)], None, skin)
    g.blob(C, 4, 5 + gap, 3.4, skin, sep=False)
    if gap:
        g.poly([(C - 2.5, 5), (C + 2.5, 5), (C + 1.5, 17), (C - 1.5, 17)], (150, 36, 46))
    for y in range(3, 19, 2):  # 이빨(주둥이 가장자리)
        w = 5 + gap + (y - 3) * 2.5 / 16
        for side in (-1, 1):
            g.put(C + side * w, y + 0.5, WHITE)
    for k in range(4):  # 주둥이 등 돌기
        g.put(C - 1.5, 7 + k * 3, skin[3])
        g.put(C + 1.5, 8 + k * 3, skin[3])
    for side in (-1, 1):  # 콧구멍·눈(눈두덩이 볼록)
        g.put(C + side * 1.5, 2, skin[0])
        g.blob(C + side * 7, 22, 3.6, 3.2, skin, lift=0.15)
        g.eye(C + side * 7, 21.5, 2.0, (250, 214, 60), glow=(150, 60, 30))
    return g.outline(OUT)


def whale(f):
    """괴물 고래: 폭풍 먹구름 색, 따개비·흉터, 박힌 작살, 붉은 눈, 숨구멍 물보라."""
    g = Can(N)
    body, belly = ramp((70, 84, 118)), ramp((150, 160, 180))
    fl = 4 if f else -4
    # 꼬리 지느러미
    g.chain([(C, 64), (C, 72), (C + fl * 0.3, 78)], [9, 6, 4], body)
    for side in (-1, 1):
        g.blob(C + side * 12 + fl * 0.4, 82, 12, 4.2, body, ang=side * 0.35)
    # 가슴지느러미
    for side in (-1, 1):
        g.blob(C + side * 23, 40 + side * fl * 0.3, 13, 5, body, ang=side * (0.55 + (0.1 if f else 0)))
    g.blob(C, 38, 19, 31, body)
    g.blob(C, 18, 14, 13, body, lift=0.05)
    # 따개비·흉터
    for (dx, dy, r) in ((-9, 44, 2.2), (8, 52, 1.8), (-4, 58, 1.6), (11, 30, 1.7), (-12, 28, 1.4), (5, 40, 1.3)):
        g.blob(C + dx, dy, r, r, belly, sep=False, lift=0.2)
        g.put(C + dx, dy, belly[0])
    for (x0, y0, x1, y1) in ((-6, 32, 6, 38), (-2, 48, 9, 46), (-13, 50, -6, 56)):
        g.line(C + x0, y0, C + x1, y1, body[0])
        g.line(C + x0, y0 - 1, C + x1, y1 - 1, body[4])
    # 박힌 작살 셋(나무 자루·밧줄)
    for (dx, dy, ang) in ((10, 36, -0.6), (-11, 46, 0.7), (4, 60, -0.3)):
        x0, y0 = C + dx, dy
        x1, y1 = x0 + math.sin(ang) * 13, y0 - math.cos(ang) * 13
        g.line(x0, y0, x1, y1, (120, 80, 44), w=1.6)
        g.line(x1, y1, x1 + math.sin(ang + 0.5) * 2, y1 - math.cos(ang + 0.5) * 2, (200, 200, 210))
        g.put(x0, y0, (130, 30, 36))
    # 숨구멍 + 물보라(프레임마다)
    g.blob(C, 24, 2.4, 1.6, None, flat=body[0], sep=False)
    for k in range(5):
        y = 20 - k * 3 - (1 if f else 0)
        for side in (-1, 1):
            g.put(C + side * (1 + k * (0.9 if f else 0.6)), y, (200, 230, 250) if k % 2 else WHITE)
    # 붉은 눈(옆)
    for side in (-1, 1):
        g.eye(C + side * 12, 16, 2.0, (230, 60, 50), glow=(120, 30, 40))
    return g.outline(OUT)


def slime(f):
    """얼음 슬라임: 반투명 젤리 속 얼음 조각·얼어붙은 물고기, 머리 얼음 왕관, 출렁임."""
    g = Can(N)
    jelly = [(60, 130, 190, 230), (90, 170, 220, 215), (130, 204, 240, 205), (180, 230, 250, 200), (230, 248, 255, 220)]
    ice = ramp((190, 226, 246))
    wob = 2.2 if f else -2.2
    rx, ry = 31 + wob, 28 - wob * 0.7
    # 녹아 흐른 바닥 웅덩이
    g.blob(C, 50, rx + 6, ry * 0.75, None, flat=(90, 160, 210, 120), sep=False)
    ins = g.blob(C, 46, rx, ry, jelly, sep=False)
    # 속 핵
    g.blob(C, 50, 12 - wob * 0.3, 10, [(40, 90, 150, 230), (60, 120, 180, 230), (90, 150, 210, 230)], sep=False)
    # 갇힌 얼음 조각·물고기
    for (dx, dy, a) in ((-16, 52, 0.4), (15, 58, -0.7), (-4, 64, 1.2), (18, 40, 0.2)):
        g.blob(C + dx, dy, 3.4, 2.0, ice, ang=a, sep=False)
    g.blob(C - 12, 40, 4, 1.8, ramp((240, 150, 80)), ang=0.3, sep=False)  # 얼어붙은 물고기
    g.put(C - 16.5, 39, (250, 230, 120))
    # 얼음 왕관(가시)
    for k, (dx, h) in enumerate(((-14, 10), (-7, 14), (0, 17), (7, 14), (14, 10))):
        by = 46 - math.sqrt(max(0, 1 - (dx / rx) ** 2)) * ry + 3
        g.spike(C + dx, by, C + dx + (0.5 if k % 2 else -0.5), by - h, 3.2, ice)
    # 눈·입
    for side in (-1, 1):
        g.blob(C + side * 9, 38, 4.2, 5.2, None, flat=(20, 40, 70), sep=False)
        g.put(C + side * 9 - 1, 36, WHITE)
        g.put(C + side * 9 - 1, 37, WHITE)
    g.line(C - 5, 47 + (1 if f else 0), C + 5, 47 + (1 if f else 0), (20, 40, 70))
    # 표면 반짝
    for (dx, dy) in ((-20, 32), (-19, 33), (-22, 36), (12, 26)):
        g.put(C + dx, dy, (255, 255, 255))
    del ins
    return g.outline(OUT)


def leviathan(f):
    """레비아탄: S자로 휜 흑요석 바다용, 등가시, 용암 금, 뿔 달린 머리."""
    g = Can(N)
    scale, lava, spine = ramp((120, 40, 44)), ramp((255, 120, 30)), ramp((70, 60, 70))
    ph = 0.6 if f else 0.0
    pts, rad = [], []
    for k in range(40):
        t = k / 39
        pts.append((C + math.sin(t * 5.2 + ph) * 22 * (0.4 + 0.6 * t), 27 + t * 59))
        rad.append(9.5 - 6.5 * t)
    g.chain(pts, rad, scale)
    for k in range(3, 38, 3):  # 배 쪽 용암 금(몸 가운데 줄)
        x, y = pts[k]
        g.line(x - rad[k] * 0.45, y, x + rad[k] * 0.45, y + 1, lava[3 if k % 2 else 2])
        g.put(x, y, lava[4])
    for k in range(2, 36, 2):  # 등가시
        x, y = pts[k]
        nx, ny = pts[k + 1]
        g.spike(x, y, x + (x - nx) * 0.4, y - 4 - rad[k] * 0.25, 1.8, spine)
    # 지느러미(앞)
    for side in (-1, 1):
        x, y = pts[9]
        g.blob(x + side * 12, y + 4, 9, 3.4, scale, ang=side * 0.8)
        g.line(x + side * 5, y + 1, x + side * 18, y + 9, lava[2])
    # 머리: 긴 용 주둥이, 뒤로 휜 뿔, 이빨, 빛나는 눈
    hx, hy = pts[0]
    g.blob(hx, hy - 2, 10, 9, scale)
    g.poly([(hx - 7, hy - 4), (hx + 7, hy - 4), (hx + 4, hy - 20), (hx - 4, hy - 20)], None, scale)
    g.blob(hx, hy - 20, 4.4, 3, scale, sep=False)
    for side in (-1, 1):
        g.spike(hx + side * 6, hy - 3, hx + side * 13, hy + 4, 2.2, spine)  # 뒤로 휜 뿔
        g.eye(hx + side * 5, hy - 6, 1.8, lava[4], glow=lava[1])
    g.line(hx, hy - 21, hx, hy - 8, lava[3])  # 콧등 용암 줄
    for k in range(5):  # 콧김 불꽃
        g.put(hx + (k % 2) * (1 if f else -1), hy - 24 - k, lava[4 - k % 3])
    return g.outline(OUT)


def kraken_titan(f):
    """크라켄 대왕: 진홍 몸에 청록 발광점, 굵은 팔 8 + 긴 촉완 2(빨판), 금빛 큰 눈."""
    g = Can(N)
    body, glow = ramp((170, 40, 60)), (90, 240, 230)
    for i in range(8):
        a = math.pi / 2 + (i - 3.5) * 0.42 + (0.0 if i < 4 else 0.0)
        a = math.pi * 0.5 + (i - 3.5) * (math.pi * 1.55 / 7)
        pts, rad = [], []
        for k in range(22):
            t = k / 21
            bend = math.sin(t * 3.2 + i * 1.3 + (0.9 if f else 0)) * 0.42 * t
            r = 10 + t * 33
            pts.append((C + math.cos(a + bend) * r, 40 + math.sin(a + bend) * r))
            rad.append(4.8 - 3.6 * t)
        g.chain(pts, rad, body, sep=True)
        for k in range(3, 20, 3):  # 빨판
            x, y = pts[k]
            g.put(x, y, mix(body[4], WHITE, 0.4))
    for side in (-1, 1):  # 촉완(앞으로 길게, 끝 곤봉)
        pts, rad = [], []
        for k in range(24):
            t = k / 23
            a = -0.5 + t * 2.1 + (0.15 if f else 0)
            pts.append((C + side * (10 + math.sin(a) * 28), 30 - math.cos(a) * 24 + t * 6))
            rad.append(2.4 - 0.8 * t)
        g.chain(pts, rad, body)
        x, y = pts[-1]
        g.blob(x, y, 3.6, 4.6, body)
        g.put(x, y, glow)
    # 겉망토(머리 몸통, 위로 뾰족)
    g.blob(C, 30, 15, 21, body)
    g.blob(C, 14, 9, 10, body, lift=0.08)
    for side in (-1, 1):
        g.blob(C + side * 9, 8, 6, 3.4, body, ang=side * 0.6)  # 지느러미
    for (dx, dy) in ((-6, 22), (5, 26), (0, 16), (-9, 32), (8, 34), (-2, 38), (4, 12)):  # 발광점
        g.put(C + dx, dy, glow)
        if (dx + dy) % 2:
            g.put(C + dx + 1, dy, mix(glow, body[2], 0.5))
    for side in (-1, 1):
        g.eye(C + side * 10, 40, 3.2, (250, 200, 60), glow=(120, 30, 40))
    return g.outline(OUT)


def poseidon(f):
    """포세이돈(유령): 청록 망령 거인 — 금관·흰 수염·어깨, 앞으로 든 금 삼지창, 아래는 소용돌이 안개."""
    g = Can(N)
    skin, mist, cloth = ramp((90, 170, 160)), [(60, 110, 120, 150), (90, 160, 170, 170), (150, 220, 220, 190)], ramp((46, 70, 120))
    sw = 1 if f else 0
    # 소용돌이 안개 꼬리
    for k in range(30):
        t = k / 29
        a = t * 5.5 + sw * 0.6
        g.blob(C + math.cos(a) * (14 - t * 10), 60 + t * 24 + math.sin(a) * 3, 9 - t * 6, 3.2 - t * 1.5, mist, sep=False)
    # 몸·망토
    g.blob(C, 54, 15, 12, cloth)
    g.blob(C, 48, 17, 10, skin)  # 가슴
    g.line(C - 15, 56, C + 15, 56, GOLD[2], w=2)  # 금 허리띠
    g.blob(C, 56, 2.4, 2.0, GOLD, sep=False)
    for side in (-1, 1):
        g.line(C + side * 3, 46, C + side * 9, 50, skin[1])  # 가슴 근육 그늘
    # 팔: 오른팔(화면 오른쪽) 앞으로 삼지창, 왼팔 옆으로
    g.chain([(C + 16, 44), (C + 22, 36), (C + 24, 28)], [5, 4.4, 3.8], skin)
    g.chain([(C - 16, 44), (C - 25, 48 + sw), (C - 30, 54 + sw)], [5, 4.4, 3.6], skin)
    # 삼지창(금, 위로)
    tx = C + 24
    g.line(tx, 58, tx, 6, GOLD[1], w=2)
    g.line(tx - 0.6, 58, tx - 0.6, 6, GOLD[3])
    g.line(tx - 6, 10, tx + 6, 10, GOLD[2], w=2)
    for dx in (-6, 0, 6):
        g.spike(tx + dx, 10, tx + dx, 1 - (2 if dx == 0 else 0), 1.6, GOLD)
    for k in range(3):  # 삼지창 빛
        g.put(tx + (k - 1) * 6, 2 + (k % 2) * sw, (220, 255, 250))
    # 어깨·머리
    for side in (-1, 1):
        g.blob(C + side * 14, 42, 8, 6, skin)
        g.blob(C + side * 15, 41, 6, 4, GOLD, sep=False)  # 금 견갑
    g.blob(C, 33, 10, 10, skin)
    # 수염(흰빛 덩어리가 가슴으로 흘러내림)
    beard = [(150, 190, 200), (196, 222, 228), (230, 244, 246), (246, 252, 252), (255, 255, 255)]
    g.chain([(C, 37), (C + sw * 0.8, 44), (C - sw * 0.5, 50)], [6.5, 4.6, 2.2], beard)
    for side in (-1, 1):
        g.chain([(C + side * 7, 31), (C + side * 9, 38)], [2.4, 1.6], beard)
    g.line(C - 3, 36, C + 3, 36, (40, 90, 90))  # 입
    # 금관
    g.blob(C, 28, 9, 4, GOLD, sep=False)
    for dx in (-7, -3.5, 0, 3.5, 7):
        g.spike(C + dx, 27, C + dx * 1.15, 18 - (3 if dx == 0 else 0), 1.6, GOLD)
    g.put(C, 25, (90, 240, 230))
    for side in (-1, 1):
        g.eye(C + side * 4, 32, 1.4, (150, 255, 240), glow=(40, 120, 120))
    return g.outline(OUT)


BOSSES = {"sea_croc": croc, "monster_whale": whale, "ice_slime": slime, "leviathan": leviathan,
          "kraken_titan": kraken_titan, "poseidon": poseidon}


def files():
    out = {}
    for kind, make in BOSSES.items():
        a, b = make(False), make(True)
        out[f"bosses/td_{kind}.png"] = [ra + rb for ra, rb in zip(a, b)]
        out[f"bosses/{kind}.png"] = a  # 컷인 초상(위에서 본 첫 프레임)
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
        print("✓ 대보스가 격자와 같다")
        return 0
    print(f"✓ {len(changed)}개 갱신 ({len(BOSSES)}종)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
