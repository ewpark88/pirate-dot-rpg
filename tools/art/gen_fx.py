"""이펙트 보정본 생성 → tools/art/overrides/ (import_pack.py가 이것을 assets에 쓴다). OWN.

    python -I tools/art/gen_fx.py            # tools/art/overrides/ 에 쓴다
    python -I tools/art/gen_fx.py --check    # 쓰지 않고, 결과가 지금 파일과 다르면 실패
    python -I tools/art/import_pack.py --dot <도트 v0.2 zip> --battle <전투 v0.3 zip>   # 그다음 assets·LICENSES 반영

- fx/explosion_aoe.png 64×64 × 8프레임 (fx_map fxSheets와 같은 크기): 팩 원본 앞 프레임이 무늬 없는 노란 원이라
  실기기에서 임시 그림처럼 보였다(S1 지적) → 번쩍 별 → 울퉁불퉁한 불덩이(흰 심·노랑·주황·붉은 테, 심은 왼쪽 위) →
  충격파 고리·연기 덩이·불티 → 흩어지는 연기. 모든 덩어리에 1px 외곽선 (27,23,38).
- projectiles/cannonball.png 7×7: 쇠 포탄(왼쪽 위 반짝임, 오른쪽 아래 그늘) — 팩 4×4는 너무 작았다.
같은 입력이면 같은 바이트.
"""

from __future__ import annotations

import importlib.util
import math
import sys
from pathlib import Path

sys.dont_write_bytecode = True

HERE = Path(__file__).resolve().parent
OUT = HERE / "overrides"

_spec = importlib.util.spec_from_file_location("gen_bosses", HERE / "gen_bosses.py")
_b = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_b)

K = (27, 23, 38)
WHITE = (255, 250, 222)
YELLOW = (255, 214, 90)
ORANGE = (255, 140, 40)
RED = (210, 62, 30)
DARK_RED = (140, 40, 28)
SMOKE = (106, 100, 114)
SMOKE_LIGHT = (150, 144, 158)
SMOKE_DARK = (72, 66, 82)
RING = (255, 220, 110)
EMBER = (255, 170, 60)
SIZE = 64


def _blank(n=SIZE):
    return [[None] * n for _ in range(n)]


def _fireball(px, r, *, bands=(0.32, 0.58, 0.82), cold=False, seed=0.0):
    """울퉁불퉁한 불덩이: 반지름이 각도에 따라 흔들리고, 심(흰·노랑)은 왼쪽 위로 치우친다."""
    c = SIZE / 2
    for y in range(SIZE):
        for x in range(SIZE):
            dx, dy = x + 0.5 - c, y + 0.5 - c
            a = math.atan2(dy, dx)
            rr = r * (1 + 0.07 * math.sin(3 * a + seed) + 0.08 * math.sin(7 * a + seed * 2) + 0.05 * math.sin(11 * a + seed * 3))
            d = math.hypot(dx + r * 0.18, dy + r * 0.18) / rr  # 심을 왼쪽 위로
            if math.hypot(dx, dy) > rr:
                continue
            if cold:
                px[y][x] = RED if d < 0.55 else DARK_RED
            elif d < bands[0]:
                px[y][x] = WHITE
            elif d < bands[1]:
                px[y][x] = YELLOW
            elif d < bands[2]:
                px[y][x] = ORANGE
            else:
                px[y][x] = RED


def _puff(px, cx, cy, r):
    """연기 덩이: 위 왼쪽 밝게, 아래 오른쪽 어둡게."""
    for y in range(SIZE):
        for x in range(SIZE):
            dx, dy = x + 0.5 - cx, y + 0.5 - cy
            if dx * dx + dy * dy <= r * r:
                px[y][x] = SMOKE_LIGHT if dx + dy < -r * 0.6 else (SMOKE_DARK if dx + dy > r * 0.7 else SMOKE)


def _ring(px, r, width=1.0, gaps=0):
    c = SIZE / 2
    for y in range(SIZE):
        for x in range(SIZE):
            d = math.hypot(x + 0.5 - c, y + 0.5 - c)
            if abs(d - r) <= width / 2 + 0.25:
                a = (math.degrees(math.atan2(y + 0.5 - c, x + 0.5 - c)) + 360) % 360
                if gaps and (a // (360 / (gaps * 2))) % 2:
                    continue
                px[y][x] = RING


def _sparks(px, n, r0, r1, seed, color=EMBER):
    for i in range(n):
        a = i * 2.39996 + seed
        for t in (0.0, 0.5):
            rr = r0 + (r1 - r0) * ((i * 37 % 10) / 10 + t * 0.1)
            x = round(SIZE / 2 + math.cos(a) * rr)
            y = round(SIZE / 2 + math.sin(a) * rr)
            if 0 <= x < SIZE and 0 <= y < SIZE:
                px[y][x] = color


def _star(px, core, arm, diag):
    c = SIZE // 2
    for d in range(-arm, arm + 1):
        for x, y in ((c + d, c), (c, c + d)):
            px[y][x] = WHITE if abs(d) <= core else YELLOW
    for d in range(-diag, diag + 1):
        for x, y in ((c + d, c + d), (c + d, c - d)):
            px[y][x] = WHITE if abs(d) <= core else YELLOW
    _b._ellipse(px, c + 0.5, c + 0.5, core + 0.6, core + 0.6, lambda *_: WHITE)


def _puff_ring(px, n, dist, r, seed, lift=0.0):
    for i in range(n):
        a = i * (2 * math.pi / n) + seed
        _puff(px, SIZE / 2 + math.cos(a) * dist, SIZE / 2 + math.sin(a) * dist - lift, r)


def explosion_frames() -> list[list[list]]:
    frames = []
    # 0 번쩍 별
    f = _blank()
    _star(f, 2, 9, 5)
    frames.append(f)
    # 1 작은 불덩이 + 불티
    f = _blank()
    _fireball(f, 11, seed=0.3)
    _sparks(f, 8, 14, 18, 0.2)
    frames.append(f)
    # 2 큰 불덩이
    f = _blank()
    _fireball(f, 17, bands=(0.26, 0.52, 0.8), seed=1.1)
    _sparks(f, 10, 19, 24, 0.9)
    frames.append(f)
    # 3 가장 큼 + 충격파 고리 + 연기 시작
    f = _blank()
    _ring(f, 27, 1.5)
    _puff_ring(f, 5, 17, 5, 0.4)
    _fireball(f, 18, bands=(0.18, 0.42, 0.72), seed=2.0)
    _sparks(f, 12, 22, 28, 1.7)
    frames.append(f)
    # 4 불이 식으며 연기 고리
    f = _blank()
    _ring(f, 29, 1.0, gaps=6)
    _puff_ring(f, 6, 18, 6, 0.1)
    _fireball(f, 12, bands=(0.0, 0.3, 0.65), seed=2.8)
    _sparks(f, 10, 24, 30, 2.4)
    frames.append(f)
    # 5 붉은 잔불 + 연기
    f = _blank()
    _puff_ring(f, 6, 20, 6, 0.35, lift=1)
    _fireball(f, 8, cold=True, seed=3.3)
    _sparks(f, 8, 22, 30, 3.1)
    frames.append(f)
    # 6 연기 흩어짐
    f = _blank()
    _puff_ring(f, 6, 22, 5, 0.6, lift=3)
    _sparks(f, 6, 24, 30, 3.9, SMOKE_LIGHT)
    frames.append(f)
    # 7 마지막 연기 몇 점
    f = _blank()
    _puff_ring(f, 5, 24, 3, 0.9, lift=5)
    frames.append(f)
    for f in frames:
        _b.outline(f)
    return frames


def explosion() -> list[list]:
    frames = explosion_frames()
    return [sum((f[y] for f in frames), []) for y in range(SIZE)]


def cannonball() -> list[list]:
    px = [[None] * 7 for _ in range(7)]
    _b._ellipse(px, 3.5, 3.5, 2.6, 2.6, lambda x, y, dx, dy: (52, 54, 66) if dx + dy > 0.6 else (92, 96, 112))
    _b.outline(px)
    px[2][2] = (200, 205, 220)  # 반짝임
    return px


FILES = {
    "fx/explosion_aoe.png": explosion,
    "projectiles/cannonball.png": cannonball,
}


def main(argv: list[str]) -> int:
    for stream in (sys.stdout, sys.stderr):
        stream.reconfigure(encoding="utf-8")
    check = "--check" in argv
    changed = []
    for rel, make in FILES.items():
        data = _b.write_png(make())
        target = OUT / rel
        if target.is_file() and target.read_bytes() == data:
            continue
        changed.append(rel)
        if not check:
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(data)
    if check:
        if changed:
            print("✗ 다시 굽기 결과가 다름: " + ", ".join(changed), file=sys.stderr)
            return 1
        print("✓ 이펙트 보정본이 격자와 같다")
        return 0
    print(f"✓ {len(changed)}개 갱신 → {OUT}" + (" — 이어서 import_pack.py로 assets 반영" if changed else ""))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
