"""보스 도트 생성 (스펙 render-art-enemies, 묶음 1 산호초: raider_ship · giant_hermit). 격자 → PNG, LICENSES OWN.

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
            raw.extend((0, 0, 0, 0) if c is None else (*c[:3], 255))

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


def raider_ship() -> list[list]:
    src = read_png(ASSETS / "bosses" / "enemy_ship.png")
    px = [[None if c is None else RAIDER_SWAP.get(c[:3], c[:3]) for c in row] for row in src]
    h, w = len(px), len(px[0])
    # 원래 작은 문양(돛 위 외곽선 칸) 지우기 → 돛 색
    for y in range(h):
        for x in range(w):
            if px[y][x] == OUTLINE and 0 < x < w - 1 and px[y][x - 1] == SAIL and px[y][x + 1] in (SAIL, OUTLINE):
                if px[y - 1][x] in (SAIL, OUTLINE) and px[y + 1][x] in (SAIL, OUTLINE) and _inside_sail(px, x, y):
                    px[y][x] = SAIL
    # 찢긴 돛 끝: 돛 맨 아래 칸을 6칸마다 2칸씩 한 줄 올린다.
    for x in range(w):
        ys = [y for y in range(h) if px[y][x] == SAIL]
        if not ys or x % 6 not in (1, 2):
            continue
        bottom = max(ys)
        if px[bottom + 1][x] == OUTLINE:
            px[bottom + 1][x] = None
            px[bottom][x] = OUTLINE
    # 돛 아래쪽 그늘 2줄
    for x in range(w):
        ys = [y for y in range(h) if px[y][x] == SAIL]
        for y in ys[-2:]:
            px[y][x] = SAIL_SHADE
    # 해골 (돛대 왼쪽 돛 가운데, 줄무늬 위)
    sx, sy = 21, 8
    for dy, row in enumerate(SKULL):
        for dx, ch in enumerate(row):
            if ch == "w":
                px[sy + dy][sx + dx] = BONE
            elif ch == "k":
                px[sy + dy][sx + dx] = OUTLINE
    # 깃발 꼬리: 깃발 오른쪽으로 갈라진 빨간 띠
    for x, y in ((34, 2), (35, 2), (36, 3), (37, 3), (34, 4), (35, 4), (36, 5)):
        if px[y][x] is None:
            px[y][x] = STREAMER
    outline(px)
    return px


def _inside_sail(px, x, y) -> bool:
    row = px[y]
    return any(c == SAIL for c in row[:x]) and any(c == SAIL for c in row[x + 1 :])


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
    for x, y in ((OX + 0, 26), (OX + 1, 26), (OX + 2, 26), (OX + 0, 27), (OX + 1, 27)):
        block(x, y, None)
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


FILES = {
    "bosses/raider_ship.png": raider_ship,
    "bosses/giant_hermit.png": giant_hermit,
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
