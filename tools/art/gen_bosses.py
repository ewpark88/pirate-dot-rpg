"""보스 도트 생성 (스펙 render-art-enemies, 묶음 1 산호초: raider_ship · giant_hermit / 묶음 2 폭풍해: storm_pirate · thunder_ray / 묶음 3 빙하: icebreaker · iceberg_walrus / 묶음 4 화산: fire_pirate · lava_whale / 묶음 5 심연: deep_sub · kraken · kraken_tentacle / 묶음 6 유령해: ghost_ship · ghost_admiral). 격자 → PNG, LICENSES OWN.

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


# ---------- 묶음 4 화산: fire_pirate · lava_whale ----------
FIRE_SWAP = {
    (60, 50, 60): (205, 82, 36),  # 돛: 불꽃 주홍
    (179, 48, 43): (40, 30, 40),  # 줄무늬: 그을린 검정
    (140, 90, 50): (88, 64, 52),  # 그을린 선체
    (95, 58, 32): (62, 44, 36),
    (70, 44, 26): (44, 32, 28),
    (220, 70, 60): (255, 200, 80),  # 꼭대기 깃발: 불꽃 노랑
}
FLAME = [
    "...y...",
    "..yy...",
    "..yyo..",
    ".yyoo.y",
    ".yoooyy",
    "yoorooy",
    "yorrroy",
    ".orrro.",
    "..ooo..",
]


def fire_pirate() -> list[list]:
    """불꽃 주홍 돛(그을린 끝)·검은 줄·불꽃 문양·그을린 선체·노란 깃발 꼬리 (화산 중간 보스)."""
    return ship_variant(
        FIRE_SWAP,
        (205, 82, 36),
        (150, 52, 26),
        FLAME,
        {"y": (255, 220, 90), "o": (255, 150, 40), "r": (220, 60, 30)},
        (21, 6),
        True,
        (255, 200, 80),
    )


WHALE = (70, 64, 72)
WHALE_SHADE = (52, 46, 54)
WHALE_BELLY = (120, 108, 112)
LAVA = (255, 140, 40)
LAVA_HOT = (255, 220, 110)


def lava_whale() -> list[list]:
    """용암 고래 64×46: 현무암 몸·배 쪽 밝은 줄무늬·용암 금·빛나는 눈·숨구멍 용암 분수·꼬리. 머리 왼쪽(배 쪽)."""
    w, h = 64, 46
    px = [[None] * w for _ in range(h)]

    def ellipse(cx, cy, rx, ry, color_at):
        for y in range(h):
            for x in range(w):
                dx, dy = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
                if dx * dx + dy * dy <= 1:
                    c = color_at(x, y, dx, dy)
                    if c is not None:
                        px[y][x] = c

    def body(x, y, dx, dy):
        if dy > 0.55:
            return WHALE_SHADE if y % 3 == 0 else WHALE_BELLY  # 목 주름(가로 줄)
        return WHALE_SHADE if dy > 0.25 else WHALE

    ellipse(28, 30, 25, 12, body)  # 몸(머리 쪽이 크다)
    ellipse(46, 31, 12, 8, body)  # 몸 뒤
    tail = [(52, 30), (58, 24), (62, 20), (61, 27), (59, 31), (62, 38), (57, 36), (53, 33)]
    for y in range(h):
        for x in range(w):
            if _in_poly(x + 0.5, y + 0.5, tail):
                px[y][x] = WHALE
    ellipse(26, 40, 5, 2.5, lambda x, y, dx, dy: WHALE_SHADE)  # 앞 지느러미
    # 숨구멍 용암 분수: 기둥 + 위에서 퍼지는 물보라
    for y in range(12, 19):
        px[y][20] = LAVA
        px[y][21] = LAVA
    for y, (x0, x1) in ((11, (17, 24)), (10, (16, 25)), (9, (16, 18)), (9, (23, 25)), (8, (15, 16)), (8, (25, 26))):
        for x in range(x0, x1 + 1):
            px[y][x] = LAVA_HOT if y < 11 else LAVA
    outline(px)
    _line(px, [(12, 28), (24, 31), (34, 30)], OUTLINE)  # 입
    _line(px, [(30, 22), (33, 25), (31, 27), (35, 29)], LAVA)  # 용암 금
    _line(px, [(41, 24), (44, 27), (42, 30)], LAVA)
    _line(px, [(16, 21), (18, 23)], LAVA)
    for x, y in ((31, 24), (43, 26)):
        px[y][x] = LAVA_HOT
    for dx in (0, 1):  # 빛나는 눈
        for dy in (0, 1):
            px[24 + dy][10 + dx] = LAVA_HOT
    px[24][10] = BONE
    return px


# ---------- 묶음 5 심연: deep_sub · kraken · kraken_tentacle ----------
SUB = (212, 172, 13)
SUB_SHADE = (160, 124, 10)
SUB_LIGHT = (250, 214, 80)
STEEL = (140, 150, 170)
PORT = (150, 230, 250)


def _blank(w, h):
    return [[None] * w for _ in range(h)]


def _ellipse(px, cx, cy, rx, ry, color_at):
    h, w = len(px), len(px[0])
    for y in range(h):
        for x in range(w):
            dx, dy = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
            if dx * dx + dy * dy <= 1:
                c = color_at(x, y, dx, dy)
                if c is not None:
                    px[y][x] = c


def deep_sub() -> list[list]:
    """심해 잠수함 62×36 (심연 중간 보스): 노란 선체(위 밝고 아래 어둡게)·조종탑·잠망경·둥근 창 3·리벳·프로펠러. 앞(왼쪽)이 배 쪽."""
    px = _blank(62, 36)
    _ellipse(px, 30, 24, 27, 9, lambda x, y, dx, dy: SUB_LIGHT if dy < -0.55 else (SUB_SHADE if dy > 0.4 else SUB))
    for y in range(11, 18):  # 조종탑
        for x in range(26, 39):
            px[y][x] = SUB_LIGHT if y < 13 else SUB
    for y in range(4, 11):  # 잠망경
        px[y][34] = STEEL
    for x in range(30, 35):
        px[4][x] = STEEL
    for x0 in (56, 57, 58):  # 프로펠러 축
        px[24][x0] = STEEL
    for y in range(18, 31):
        if abs(y - 24) > 1:
            px[y][59] = STEEL
            px[y][60] = STEEL if abs(y - 24) < 6 else None
    outline(px)
    for cx in (14, 24, 34):  # 둥근 창: 테두리 외곽선 + 하늘빛 유리 + 반짝임
        _ellipse(px, cx, 23, 3, 3, lambda x, y, dx, dy: OUTLINE if dx * dx + dy * dy > 0.45 else PORT)
        px[22][cx - 1] = BONE
    for x in range(8, 52, 4):  # 리벳 줄
        if px[28][x] == SUB_SHADE:
            px[28][x] = SUB_LIGHT
    return px


KRAKEN = (128, 62, 150)
KRAKEN_SHADE = (92, 40, 112)
KRAKEN_LIGHT = (168, 98, 190)
SUCKER = (240, 150, 190)
EYE = (255, 220, 90)


def _tentacle(px, x0, y0, length, dir_x, phase, thick):
    """빨판 달린 촉수: 사인 곡선을 따라 굵기 thick → 1로 가늘어진다."""
    import math

    for i in range(length):
        t = i / length
        x = x0 + dir_x * i * 0.9
        y = y0 + i * 0.55 + math.sin(i * 0.35 + phase) * 3 * t
        r = thick * (1 - t) + 0.6
        for yy in range(int(y - r), int(y + r) + 1):
            for xx in range(int(x - r), int(x + r) + 1):
                if 0 <= yy < len(px) and 0 <= xx < len(px[0]) and (xx + 0.5 - x) ** 2 + (yy + 0.5 - y) ** 2 <= r * r:
                    px[yy][xx] = KRAKEN_SHADE if yy + 0.5 > y + r * 0.3 else KRAKEN
    return [(round(x0 + dir_x * i * 0.9), round(y0 + i * 0.55 + math.sin(i * 0.35 + phase) * 3 * i / length + thick * (1 - i / length) * 0.6)) for i in range(2, length - 4, 4)]


def kraken() -> list[list]:
    """크라켄 64×56 (심연 해역 보스): 보라 머리(위 밝게)·노란 큰 눈 둘(세로 동공)·앞으로 뻗은 촉수 6개(빨판)."""
    px = _blank(64, 56)
    suckers = []
    for x0, dx, ph, ln in ((24, -1, 0.0, 26), (30, -1, 1.5, 30), (36, -0.6, 3.0, 26), (40, 0.3, 0.7, 22), (46, 0.7, 2.2, 22), (50, 1, 4.0, 18)):
        suckers += _tentacle(px, x0, 30, ln, dx, ph, 3.2)
    _ellipse(px, 38, 18, 17, 16, lambda x, y, dx, dy: KRAKEN_LIGHT if dy < -0.55 and dx < 0.2 else (KRAKEN_SHADE if dy > 0.45 else KRAKEN))
    outline(px)
    for x, y in suckers:
        if 0 <= y < 56 and 0 <= x < 64 and px[y][x] in (KRAKEN, KRAKEN_SHADE):
            px[y][x] = SUCKER
    for cx in (30, 42):  # 큰 눈: 외곽선 고리 + 노랑 + 세로 동공 + 반짝임
        _ellipse(px, cx, 22, 4, 4, lambda x, y, dx, dy: OUTLINE if dx * dx + dy * dy > 0.55 else EYE)
        for y in range(20, 25):
            px[y][cx] = OUTLINE
        px[20][cx - 2] = BONE
    for x, y in ((36, 8), (44, 10), (32, 11), (48, 15)):  # 머리 점무늬
        px[y][x] = KRAKEN_SHADE
    return px


def kraken_tentacle() -> list[list]:
    """크라켄 촉수(보스 장치 '촉수' 칸) 12×28: 아래에서 솟아 끝이 말린다, 빨판."""
    px = _blank(12, 28)
    import math

    for i in range(26):
        y = 27 - i
        x = 6 + math.sin(i * 0.28) * 2.2 - (i > 20) * (i - 20) * 0.8
        r = 3.2 * (1 - i / 26) + 0.7
        for xx in range(12):
            if abs(xx + 0.5 - x) <= r:
                px[y][xx] = KRAKEN_SHADE if xx + 0.5 > x + r * 0.3 else KRAKEN
    outline(px)
    for i in range(3, 22, 4):
        y = 27 - i
        x = round(6 + math.sin(i * 0.28) * 2.2 - 1)
        if px[y][x] in (KRAKEN, KRAKEN_SHADE):
            px[y][x] = SUCKER
    return px


# ---------- 묶음 6 유령해: ghost_ship · ghost_admiral ----------
GHOST_SWAP = {
    (60, 50, 60): (214, 214, 228),  # 돛: 잿빛 흰 (반투명은 아래에서)
    (179, 48, 43): (60, 50, 80),  # 줄무늬: 검보라
    (140, 90, 50): (82, 70, 92),  # 썩은 선체
    (95, 58, 32): (60, 50, 70),
    (70, 44, 26): (44, 36, 54),
    (220, 70, 60): (130, 255, 170),  # 꼭대기 깃발: 초록 빛
}
GHOST_GLOW = (130, 255, 170)


def ghost_ship() -> list[list]:
    """유령선 (유령해 중간 보스): 찢긴 반투명 잿빛 돛·초록 해골 문양·썩은 선체·초록 빛 깃발 꼬리 (내 배 t4 청록 유령선과 다른 색)."""
    sail = (214, 214, 228)
    px = ship_variant(GHOST_SWAP, sail, (170, 168, 190), SKULL, {"w": GHOST_GLOW, "k": OUTLINE}, (21, 8), True, GHOST_GLOW)
    for row in px:  # 돛을 반투명으로
        for x, c in enumerate(row):
            if c in (sail, (170, 168, 190)):
                row[x] = (*c, 175)
    return px


COAT = (60, 56, 104)
COAT_SHADE = (44, 40, 80)
GOLD = (240, 200, 80)
SPECTRE = (170, 240, 230, 200)
SPECTRE_SHADE = (120, 200, 196, 170)
FACE = (205, 242, 232)
HAT = (40, 30, 52)
BLADE = (205, 210, 225)


def ghost_admiral() -> list[list]:
    """유령 제독 56×62 (유령해 해역 보스): 삼각 모자(금 테·해골)·창백한 얼굴(초록 빛 눈구멍)·금 단추 외투·견장,
    배 쪽(왼쪽)으로 내민 녹슨 칼, 다리 대신 흔들리는 반투명 유령 꼬리."""
    w, h = 56, 62
    px = [[None] * w for _ in range(h)]
    tail = [(14, 40), (42, 40), (44, 50), (39, 56), (34, 52), (30, 60), (25, 53), (20, 58), (16, 50)]
    coat = [(16, 24), (40, 24), (44, 44), (12, 44)]
    hat = [(13, 12), (43, 12), (38, 5), (28, 2), (18, 5)]
    for y in range(h):
        for x in range(w):
            pt = (x + 0.5, y + 0.5)
            if _in_poly(*pt, tail):
                px[y][x] = SPECTRE_SHADE if y > 50 else SPECTRE
            if _in_poly(*pt, coat):
                px[y][x] = COAT_SHADE if x > 34 or y > 40 else COAT
    _line(px, [(16, 27), (11, 31), (8, 33)], COAT)  # 칼 든 팔
    _line(px, [(17, 28), (12, 32), (9, 34)], COAT)
    for y in range(h):
        for x in range(w):
            dx, dy = (x + 0.5 - 28) / 7.5, (y + 0.5 - 17) / 7
            if dx * dx + dy * dy <= 1:
                px[y][x] = FACE
            if _in_poly(x + 0.5, y + 0.5, hat):
                px[y][x] = HAT
    _line(px, [(8, 32), (2, 22)], BLADE)  # 칼날
    _line(px, [(9, 32), (3, 22)], BLADE)
    px[33][7] = FACE  # 손
    px[33][8] = FACE
    outline(px)
    for x in range(14, 43):  # 모자 금 테 (모자 맨 아래 줄)
        if px[11][x] == HAT:
            px[11][x] = GOLD
    for x, y in ((27, 6), (28, 6), (29, 6), (27, 7), (29, 7), (28, 8)):  # 모자 해골
        px[y][x] = BONE
    for ex in (23, 30):  # 눈구멍 3×3 + 가운데 초록 빛
        for dx in range(3):
            for dy in range(3):
                px[15 + dy][ex + dx] = OUTLINE
        px[16][ex + 1] = GHOST_GLOW
    for x in range(25, 32):  # 입
        if x % 2:
            px[21][x] = OUTLINE
    for y in range(27, 44, 4):  # 금 단추
        px[y][28] = GOLD
    for x in range(15, 19):  # 견장
        px[24][x] = GOLD
        px[24][x + 23] = GOLD
    for y in range(25, 44):  # 외투 앞섶 금 테
        if px[y][27] in (COAT, COAT_SHADE):
            px[y][27] = GOLD
    return px


FILES = {
    "bosses/raider_ship.png": raider_ship,
    "bosses/giant_hermit.png": giant_hermit,
    "bosses/storm_pirate.png": storm_pirate,
    "bosses/thunder_ray.png": thunder_ray,
    "bosses/icebreaker.png": icebreaker,
    "bosses/iceberg_walrus.png": iceberg_walrus,
    "bosses/fire_pirate.png": fire_pirate,
    "bosses/lava_whale.png": lava_whale,
    "bosses/deep_sub.png": deep_sub,
    "bosses/kraken.png": kraken,
    "bosses/kraken_tentacle.png": kraken_tentacle,
    "bosses/ghost_ship.png": ghost_ship,
    "bosses/ghost_admiral.png": ghost_admiral,
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
