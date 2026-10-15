"""보스 도트 생성 (스펙 render-art-enemies, 묶음 1 산호초: raider_ship · giant_hermit / 묶음 2 폭풍해: storm_pirate · thunder_ray / 묶음 3 빙하: icebreaker · iceberg_walrus). 격자 → PNG, LICENSES OWN.

    python -I tools/art/gen_bosses.py            # apps/game/assets/bosses/ 에 쓴다
    python -I tools/art/gen_bosses.py --check    # 쓰지 않고, 결과가 지금 파일과 다르면 실패

- raider_ship: enemy_ship.png(팩, OWN)의 칸을 읽어 핏빛 돛·검은 줄·찢긴 돛 끝·큰 해골·어두운 선체·깃발 꼬리로 바꾼다.
- giant_hermit: 칠한 도형(소라 껍데기 나선·게 몸·눈자루·큰 집게·다리) → 자동 1px 외곽선. 색은 팩 crab(220,70,60)/(150,40,40)·흰 눈.
외부 라이브러리 없음(zlib PNG 읽기·쓰기). 같은 입력이면 같은 바이트.
"""

from __future__ import annotations

import importlib.util
import json
import math
import struct
import sys
import zlib
from pathlib import Path

sys.dont_write_bytecode = True

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
ASSETS = ROOT / "apps" / "game" / "assets"
SOURCE = "Pirate Busters v0.24 자체 IP → tools/art/gen_bosses.py 픽셀 격자"

_spec = importlib.util.spec_from_file_location("gen_ui_icons", HERE / "gen_ui_icons.py")
_ui = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_ui)

OUTLINE = (27, 23, 38)


def read_png(path: Path) -> list[list[tuple[int, int, int, int] | None]]:
    """8비트 RGBA/RGB, 인터레이스 없는 PNG만 (팩 스프라이트 형식)."""
    data = path.read_bytes()
    pos, idat, w = 8, b"", 0
    while pos < len(data):
        n = struct.unpack(">I", data[pos : pos + 4])[0]
        kind = data[pos + 4 : pos + 8]
        body = data[pos + 8 : pos + 8 + n]
        if kind == b"IHDR":
            w, h, depth, ctype, _, _, inter = struct.unpack(">IIBBBBB", body)
            assert depth == 8 and ctype in (2, 6) and inter == 0, f"{path}: 지원 안 하는 PNG"
            bpp = 4 if ctype == 6 else 3
        elif kind == b"IDAT":
            idat += body
        pos += 12 + n
    raw = zlib.decompress(idat)
    stride = w * bpp
    rows, prev = [], bytearray(stride)
    i = 0
    for _ in range(h):
        f = raw[i]
        line = bytearray(raw[i + 1 : i + 1 + stride])
        i += 1 + stride
        for x in range(stride):
            a = line[x - bpp] if x >= bpp else 0
            b = prev[x]
            c = prev[x - bpp] if x >= bpp else 0
            if f == 1:
                line[x] = (line[x] + a) & 0xFF
            elif f == 2:
                line[x] = (line[x] + b) & 0xFF
            elif f == 3:
                line[x] = (line[x] + (a + b) // 2) & 0xFF
            elif f == 4:
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                line[x] = (line[x] + (a if pa <= pb and pa <= pc else b if pb <= pc else c)) & 0xFF
        prev = line
        row = []
        for x in range(w):
            px = tuple(line[x * bpp : x * bpp + bpp]) + ((255,) if bpp == 3 else ())
            row.append(px if px[3] else None)
        rows.append(row)
    return rows


def write_png(px: list[list[tuple[int, int, int] | None]]) -> bytes:
    h, w = len(px), len(px[0])
    raw = bytearray()
    for row in px:
        raw.append(0)
        for c in row:
            raw.extend((0, 0, 0, 0) if c is None else (*c[:3], c[3] if len(c) > 3 else 255))

    def chunk(kind: bytes, data: bytes) -> bytes:
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)

    ihdr = struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0)
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", zlib.compress(bytes(raw), 9)) + chunk(b"IEND", b"")


def outline(px):
    """투명 칸 중 상하좌우로 칠한 칸에 닿는 칸을 외곽선으로."""
    h, w = len(px), len(px[0])
    marks = []
    for y in range(h):
        for x in range(w):
            if px[y][x] is not None:
                continue
            for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                if 0 <= nx < w and 0 <= ny < h and px[ny][nx] not in (None, OUTLINE):
                    marks.append((x, y))
                    break
    for x, y in marks:
        px[y][x] = OUTLINE


# ---------- raider_ship ----------
RAIDER_SWAP = {
    (60, 50, 60): (123, 36, 28),  # 돛: 검정 → 핏빛
    (179, 48, 43): (40, 30, 40),  # 줄무늬: 빨강 → 검정
    (140, 90, 50): (96, 62, 40),  # 선체 어둡게
    (95, 58, 32): (64, 40, 24),
    (70, 44, 26): (46, 30, 20),
}
SAIL = (123, 36, 28)
SAIL_SHADE = (92, 26, 22)
BONE = (245, 245, 250)
STREAMER = (220, 70, 60)

SKULL = [
    ".wwwww.",
    "wwwwwww",
    "wkkwkkw",
    "wkkwkkw",
    "wwwkwww",
    ".wwwww.",
    ".w.w.w.",
]


def ship_variant(swap, sail, sail_shade, emblem, emblem_colors, emblem_at, tatter, streamer) -> list[list]:
    """enemy_ship 칸 바꿈: 색 바꿈 → 원래 작은 문양 지움 → (찢긴 돛 끝) → 돛 아래 그늘 2줄 → 문양 → 깃발 꼬리 → 외곽선."""
    src = read_png(ASSETS / "bosses" / "enemy_ship.png")
    px = [[None if c is None else swap.get(c[:3], c[:3]) for c in row] for row in src]
    h, w = len(px), len(px[0])
    for y in range(h):
        for x in range(w):
            if px[y][x] == OUTLINE and 0 < x < w - 1 and px[y][x - 1] == sail and px[y][x + 1] in (sail, OUTLINE):
                if px[y - 1][x] in (sail, OUTLINE) and px[y + 1][x] in (sail, OUTLINE) and _inside_sail(px, x, y, sail):
                    px[y][x] = sail
    if tatter:  # 돛 맨 아래 칸을 6칸마다 2칸씩 한 줄 올린다.
        for x in range(w):
            ys = [y for y in range(h) if px[y][x] == sail]
            if not ys or x % 6 not in (1, 2):
                continue
            bottom = max(ys)
            if px[bottom + 1][x] == OUTLINE:
                px[bottom + 1][x] = None
                px[bottom][x] = OUTLINE
    for x in range(w):
        ys = [y for y in range(h) if px[y][x] == sail]
        for y in ys[-2:]:
            px[y][x] = sail_shade
    sx, sy = emblem_at
    for dy, row in enumerate(emblem):
        for dx, ch in enumerate(row):
            if ch in emblem_colors:
                px[sy + dy][sx + dx] = emblem_colors[ch]
    for x, y in ((34, 2), (35, 2), (36, 3), (37, 3), (34, 4), (35, 4), (36, 5)):
        if px[y][x] is None:
            px[y][x] = streamer
    outline(px)
    return px


def raider_ship() -> list[list]:
    """핏빛 돛·검은 줄·찢긴 돛 끝·해골·어두운 선체·빨간 깃발 꼬리."""
    return ship_variant(RAIDER_SWAP, SAIL, SAIL_SHADE, SKULL, {"w": BONE, "k": OUTLINE}, (21, 8), True, STREAMER)


STORM_SWAP = {
    (60, 50, 60): (70, 82, 112),  # 돛: 먹구름 남회색
    (179, 48, 43): (250, 210, 70),  # 줄무늬: 번개 노랑
    (140, 90, 50): (118, 96, 78),  # 비바람에 바랜 선체
    (95, 58, 32): (80, 64, 52),
    (70, 44, 26): (56, 44, 36),
    (220, 70, 60): (250, 210, 70),  # 꼭대기 깃발도 노랑
}
BOLT = [
    "...kkkk",
    "..kyyyk",
    "..kyyk.",
    ".kyyk..",
    "kyyyyyk",
    "kkkyyk.",
    "..kyk..",
    ".kyk...",
    ".kk....",
]


def storm_pirate() -> list[list]:
    """먹구름 돛·노란 줄·번개 문양·바랜 선체·노란 깃발 꼬리 (폭풍해 중간 보스)."""
    return ship_variant(
        STORM_SWAP, (70, 82, 112), (52, 60, 86), BOLT, {"y": (250, 210, 70), "k": OUTLINE}, (21, 6), False, (250, 210, 70)
    )


def _inside_sail(px, x, y, sail) -> bool:
    row = px[y]
    return any(c == sail for c in row[:x]) and any(c == sail for c in row[x + 1 :])


# ---------- giant_hermit ----------
SHELL = (233, 216, 166)
SHELL_MID = (196, 170, 112)
SHELL_DARK = (150, 116, 72)
BODY = (220, 70, 60)
BODY_SHADE = (150, 40, 40)
K = 1.25  # 해역 보스는 중간 보스(raider_ship 62×48)보다 커 보여야 한다
W, H, OX = 64, 52, 2


def giant_hermit() -> list[list]:
    """도형 좌표는 50×42 설계 기준, K배로 칠한다(칸 단위 도형이라 깨지지 않는다)."""
    px = [[None] * W for _ in range(H)]

    def put(x, y, c):
        x, y = int(x), int(y)
        if 0 <= x < W and 0 <= y < H:
            px[y][x] = c

    def block(x, y, c):
        """설계 1칸 → K배 칸."""
        for yy in range(int(y * K), int((y + 1) * K)):
            for xx in range(int(x * K), int((x + 1) * K)):
                put(xx, yy, c)

    def ellipse(cx, cy, rx, ry, color_at):
        cx, cy, rx, ry = cx * K, cy * K, rx * K, ry * K
        for y in range(H):
            for x in range(W):
                dx, dy = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
                if dx * dx + dy * dy <= 1:
                    c = color_at(x, y, dx, dy)
                    if c is not None:
                        px[y][x] = c

    # 다리 3쌍 (몸 아래, 왼쪽으로 꺾인 발)
    for lx in (12, 18, 24):
        for y in range(34, 39):
            block(OX + lx, y, BODY_SHADE)
        block(OX + lx - 1, 38, BODY_SHADE)
        block(OX + lx - 2, 38, BODY_SHADE)
    # 소라 껍데기: 왼쪽 위 밝고 오른쪽 아래 어둡게 + 아르키메데스 나선 줄
    def shell(x, y, dx, dy):
        r = math.hypot(dx, dy)
        a = (math.atan2(dy, dx) + math.pi) / (2 * math.pi)  # 0~1
        for k in range(3):
            if abs(r - (0.18 + 0.27 * (a + k))) < 0.06:
                return SHELL_DARK
        if dx + dy > 0.7:
            return SHELL_MID
        return SHELL
    ellipse(OX + 30.5, 18.5, 16.5, 16, shell)
    # 껍데기 끝 뾰족 (오른쪽 위)
    for i in range(5):
        for j in range(5 - i):
            block(OX + 42 + i, 5 + j - i // 2, SHELL_MID if j > 1 else SHELL)
    # 게 몸: 껍데기 입구에서 왼쪽 아래로 나온다
    def body(x, y, dx, dy):
        return BODY_SHADE if dy > 0.35 else BODY
    ellipse(OX + 14.5, 28.5, 11, 7, body)
    # 큰 집게 (앞 왼쪽) + 벌어진 틈
    ellipse(OX + 4.5, 27.5, 4.5, 5.5, body)
    for x, y in ((OX - 2, 26), (OX - 1, 26), (OX + 0, 26), (OX + 1, 26),
                 (OX - 2, 27), (OX - 1, 27), (OX + 0, 27), (OX + 1, 27), (OX + 2, 27), (OX + 3, 27),
                 (OX - 2, 28), (OX - 1, 28), (OX + 0, 28), (OX + 1, 28)):
        block(x, y, None)  # 집게 갈라짐: 위·아래 턱 사이 쐐기(가운데 줄이 가장 깊다)
    # 작은 집게 (몸 오른쪽 아래)
    ellipse(OX + 22.5, 33.5, 3, 2.5, body)
    # 눈자루 + 눈 (흰자, 동공은 왼쪽 = 배 쪽을 본다)
    for ex in (10, 15):
        for y in range(17, 22):
            put((OX + ex + 1) * K, y * K, BODY_SHADE)
            put((OX + ex + 1) * K, y * K + 1, BODY_SHADE)
        for dy in range(4):
            for dx in range(4):
                put((OX + ex) * K + dx, 13 * K + dy, BONE)
        put((OX + ex) * K, 13 * K + 1, OUTLINE)
        put((OX + ex) * K, 13 * K + 2, OUTLINE)
        put((OX + ex) * K + 1, 13 * K + 1, OUTLINE)
        put((OX + ex) * K + 1, 13 * K + 2, OUTLINE)
    outline(px)
    # 몸 위 주름 (외곽선 뒤에 그려 선과 겹치지 않게)
    for x in range(OX + 8, OX + 20, 3):
        block(x, 25, BODY_SHADE)
    return px


# ---------- thunder_ray ----------
RAY = (64, 72, 130)
RAY_LIGHT = (100, 112, 175)
RAY_DARK = (44, 50, 96)
BOLT_Y = (250, 210, 70)
GLOW = (255, 240, 140)
# 위에서 본 가오리, 머리가 왼쪽(배 쪽). 날개 끝이 위·아래, 꼬리는 오른쪽.
RAY_POLY = [(12, 23), (16, 16), (23, 9), (31, 4), (39, 1), (40, 7), (42, 13), (46, 18), (51, 23),
            (46, 28), (42, 33), (40, 39), (39, 45), (31, 42), (23, 37), (16, 30)]


def _in_poly(x: float, y: float, poly) -> bool:
    inside = False
    for i in range(len(poly)):
        x1, y1 = poly[i]
        x2, y2 = poly[(i + 1) % len(poly)]
        if (y1 > y) != (y2 > y) and x < x1 + (y - y1) * (x2 - x1) / (y2 - y1):
            inside = not inside
    return inside


def _line(px, pts, c):
    for (x1, y1), (x2, y2) in zip(pts, pts[1:]):
        n = max(abs(x2 - x1), abs(y2 - y1))
        for i in range(n + 1):
            px[round(y1 + (y2 - y1) * i / n)][round(x1 + (x2 - x1) * i / n)] = c


def thunder_ray() -> list[list]:
    """번개 가오리 64×47: 남색 몸(위 밝고 아래 날개 어둡게)·날개 번개 줄·빛나는 눈·머리 지느러미·꼬리 끝 불꽃."""
    w, h = 64, 47
    px = [[None] * w for _ in range(h)]
    for y in range(h):
        for x in range(w):
            if _in_poly(x + 0.5, y + 0.5, RAY_POLY):
                px[y][x] = RAY_LIGHT if y < 11 else (RAY_DARK if y > 33 or (y > 23 and x > 40) else RAY)
    for y in range(h):  # 등뼈 융기: 머리에서 꼬리까지 밝은 타원
        for x in range(w):
            if px[y][x] is not None and ((x + 0.5 - 32) / 17) ** 2 + ((y + 0.5 - 23) / 3.6) ** 2 <= 1:
                px[y][x] = RAY_LIGHT
    _line(px, [(51, 23), (60, 23)], RAY_DARK)  # 꼬리
    _line(px, [(30, 19), (34, 14), (31, 12), (36, 6)], BOLT_Y)  # 위 날개 번개
    _line(px, [(30, 27), (34, 32), (31, 34), (36, 40)], BOLT_Y)  # 아래 날개 번개
    for x, y in ((9, 19), (10, 19), (10, 20), (11, 20), (9, 27), (10, 27), (10, 26), (11, 26)):
        px[y][x] = RAY  # 머리 지느러미(뿔)
    for x, y in ((16, 20), (17, 20), (16, 26), (17, 26)):
        px[y][x] = GLOW  # 빛나는 눈
    for x, y in ((61, 22), (61, 24), (62, 23), (60, 21), (60, 25)):
        px[y][x] = BOLT_Y  # 꼬리 끝 불꽃
    outline(px)
    return px


# ---------- 묶음 3 빙하: icebreaker · iceberg_walrus ----------
ICE_SWAP = {
    (60, 50, 60): (185, 215, 235),  # 돛: 얼음빛
    (179, 48, 43): (245, 250, 255),  # 줄무늬: 흰색
    (140, 90, 50): (110, 120, 135),  # 강철 선체
    (95, 58, 32): (80, 88, 102),
    (70, 44, 26): (56, 62, 74),
    (220, 70, 60): (120, 200, 240),  # 꼭대기 깃발: 얼음 파랑
}
SNOWFLAKE = [
    "...w...",
    ".w.w.w.",
    "..www..",
    "wwwwwww",
    "..www..",
    ".w.w.w.",
    "...w...",
]
ICE = (225, 240, 250)
ICE_MID = (170, 210, 235)
ICE_DARK = (130, 180, 215)


def icebreaker() -> list[list]:
    """얼음빛 돛·흰 줄·눈꽃 문양·강철 선체 + 뱃머리 아래 얼음 고드름 (빙하 중간 보스)."""
    px = ship_variant(ICE_SWAP, (185, 215, 235), (150, 185, 210), SNOWFLAKE, {"w": (60, 120, 190)}, (21, 9), False, (120, 200, 240))
    # 선체 밑 고드름: 바닥 외곽선 아래로 3칸마다 1~2칸
    h, w = len(px), len(px[0])
    for x in range(w):
        ys = [y for y in range(h) if px[y][x] is not None]
        if not ys or x % 3:
            continue
        bottom = max(ys)
        if bottom + 2 < h and px[bottom - 1][x] is not None and px[bottom - 1][x] != OUTLINE:
            continue
        for dy in range(1, 2 + (x // 3) % 2 + 1):
            if bottom + dy < h:
                px[bottom + dy][x] = ICE_MID if dy == 1 else ICE
    return px


WALRUS = (156, 110, 82)
WALRUS_SHADE = (120, 82, 60)
MUZZLE = (196, 156, 124)


def iceberg_walrus() -> list[list]:
    """빙산 위에 앉은 바다코끼리 64×52: 엄니·수염 주둥이·눈·앞 지느러미, 등에 서리. 머리 왼쪽(배 쪽)."""
    w, h = 64, 52
    px = [[None] * w for _ in range(h)]

    def ellipse(cx, cy, rx, ry, color_at):
        for y in range(h):
            for x in range(w):
                dx, dy = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
                if dx * dx + dy * dy <= 1:
                    c = color_at(x, y, dx, dy)
                    if c is not None:
                        px[y][x] = c

    floe = [(3, 40), (12, 35), (28, 37), (44, 33), (60, 38), (58, 47), (42, 50), (18, 50), (5, 46)]
    for y in range(h):
        for x in range(w):
            if _in_poly(x + 0.5, y + 0.5, floe):
                px[y][x] = ICE_MID if y > 45 else ICE
    _line(px, [(20, 41), (24, 44), (23, 47)], ICE_DARK)  # 빙산 금
    _line(px, [(46, 39), (49, 43)], ICE_DARK)
    ellipse(37, 24, 19, 14, lambda x, y, dx, dy: WALRUS_SHADE if dy > 0.45 else WALRUS)  # 몸
    ellipse(17, 19, 10, 9, lambda x, y, dx, dy: WALRUS)  # 머리
    ellipse(12, 25, 7, 4.5, lambda x, y, dx, dy: MUZZLE)  # 주둥이
    ellipse(25, 35, 6, 3, lambda x, y, dx, dy: WALRUS_SHADE)  # 앞 지느러미
    for tx in (9, 14):  # 엄니
        for y in range(28, 38):
            px[y][tx] = BONE
            px[y][tx + 1] = BONE if y < 36 else None
    outline(px)
    for x, y in ((8, 24), (11, 23), (14, 24), (9, 26), (12, 26), (15, 26)):
        px[y][x] = WALRUS_SHADE  # 수염 자리
    _line(px, [(26, 10), (28, 18), (26, 27)], WALRUS_SHADE)  # 목 주름: 머리와 몸을 가른다
    for x, y in ((12, 14), (19, 14)):  # 눈 2×2 + 반짝임
        for dx in (0, 1):
            for dy in (0, 1):
                px[y + dy][x + dx] = OUTLINE
        px[y][x] = BONE
    for x, y in ((34, 12), (35, 12), (42, 13), (28, 14), (47, 17), (40, 11)):
        px[y][x] = ICE  # 등에 서리
    return px


FILES = {
    "bosses/raider_ship.png": raider_ship,
    "bosses/giant_hermit.png": giant_hermit,
    "bosses/storm_pirate.png": storm_pirate,
    "bosses/thunder_ray.png": thunder_ray,
    "bosses/icebreaker.png": icebreaker,
    "bosses/iceberg_walrus.png": iceberg_walrus,
}


def main(argv: list[str]) -> int:
    for stream in (sys.stdout, sys.stderr):
        stream.reconfigure(encoding="utf-8")
    check = "--check" in argv
    changed = []
    for rel, make in FILES.items():
        data = write_png(make())
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
        print("✓ 보스 도트가 격자와 같다")
        return 0
    print(f"✓ {len(changed)}개 갱신" + (": " + ", ".join(changed) if changed else ""))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
