"""UI 도트 아이콘 생성 (탭 바 16×16 4개 + 젬 8×8 3프레임 + 코인·별·배 부품 5개 16×16). 픽셀 격자 → PNG, LICENSES.json(OWN) 갱신.

    python -I tools/art/gen_ui_icons.py            # apps/game/assets/ui/ 에 쓴다
    python -I tools/art/gen_ui_icons.py --check    # 쓰지 않고, 결과가 지금 파일과 다르면 실패

외부 라이브러리 없음(zlib PNG). 팔레트는 도트 팩 v0.2·기준 장면(battle_ship.gif)의 색과 외곽선 (27,23,38).
같은 입력이면 같은 바이트(다시 굽기 가능).
"""

from __future__ import annotations

import json
import math
import struct
import sys
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ASSETS = ROOT / "apps" / "game" / "assets"
SOURCE = "Pirate Busters v0.24 자체 IP → tools/art/gen_ui_icons.py 픽셀 격자"

PALETTE = {
    ".": None,
    "k": (27, 23, 38),  # 외곽선
    "w": (245, 250, 255),
    "b": (139, 90, 43),  # 나무
    "d": (93, 58, 26),
    "r": (231, 76, 60),
    "y": (242, 201, 76),  # 코인 금색
    "Y": (255, 230, 140),
    "o": (255, 138, 31),
    "c": (95, 211, 243),  # 젬·물
    "C": (191, 243, 255),
    "B": (47, 143, 216),
    "N": (29, 79, 156),
    "s": (242, 194, 155),  # 피부
    "p": (233, 216, 166),  # 종이
    "P": (196, 170, 112),
    "g": (170, 175, 190),
    "G": (110, 115, 130),  # 쇠 (ship_t1 포)
    "S": (70, 74, 90),
    "W": (240, 232, 210),  # 돛 (ship_t1)
    "D": (70, 44, 26),  # 돛대
    "u": (47, 98, 196),
    "v": (110, 190, 90),  # 초록 (팩 piranha)
    "V": (60, 120, 60),
    "z": (214, 156, 120),  # 피부 그늘
    "R": (150, 40, 40),
}

SHIP = [
    "................",
    ".......kk.......",
    ".......krk......",
    ".......krrk.....",
    "....kk.kkkkk....",
    "...kwwkkwwwwk...",
    "..kwwwwkkwwwwk..",
    "..kwwwwkkwwwwk..",
    ".kwwwwwkkwwwwwk.",
    ".kkkkkkkkkkkkkk.",
    "kbbbbbbbbbbbbbbk",
    "kbdbbdbbdbbdbbk.",
    ".kbbbbbbbbbbbk..",
    "..kkkkkkkkkkk...",
    ".kBBcBBBcBBBcBk.",
    "................",
]
CREW = [
    "................",
    ".....kkkkkk.....",
    "...kkrrrrrrkk...",
    "..krrrwrrrrrrk..",
    "..krrrrrrrrrrkk.",
    "..kkkkkkkkkkkkrk",
    "..kssssssssssk.k",
    "..kskkssssskksk.",
    "..ksskssssksssk.",
    "..kssssssssssk..",
    "..kssskkkkssssk.",
    "...ksssssssssk..",
    "....kksssskk....",
    "...kbbkkkkbbk...",
    "..kbbbbbbbbbbk..",
    "................",
]
SUMMON = [
    ".......kk.......",
    "......kYYk......",
    "......kyyk......",
    ".....kyYYyk.....",
    "kkkkkkyYYykkkkkk",
    "kYYyyyyYYyyyyYYk",
    ".kyyYYYYYYYYyyk.",
    "..kkyyYYYYyykk..",
    "....kyyYYyyk....",
    "...kyykyykyyk...",
    "...kyk.kk.kyk...",
    "..kyk......kyk..",
    "..kk........kk..",
    "............kk..",
    "...........kCk..",
    "............kk..",
]
MAP = [
    "................",
    ".kkkkkkkkkkkkkk.",
    "kPppppppppppppPk",
    "kPpppBBpppppppPk",
    "kPppBBBBpppkpppk",
    "kPpppBBpppkpkppk",
    "kPppppppppprpppk",
    "kPpprpppppkpkppk",
    "kPpppppprpppkppk",
    "kPpppprppppppppk",
    "kPppppppprrrpppk",
    "kPpBBBppprkrpppk",
    "kPBBBBBpppppppPk",
    "kPppppppppppppPk",
    ".kkkkkkkkkkkkkk.",
    "................",
]
GEM = [
    [
        "..kkkk..",
        ".kCcccNk",
        "kCcccBNk",
        "kccccBNk",
        ".kcBBNk.",
        "..kBNk..",
        "...kk...",
        "........",
    ],
    [
        "..kkkk..",
        ".kcCccNk",
        "kcCccBNk",
        "kcccCBNk",
        ".kcBBNk.",
        "..kBNk..",
        "...kk...",
        "........",
    ],
    [
        "..kkkkw.",
        ".kccCwww",
        "kccccBwk",
        "kcccCBNk",
        ".kcBCNk.",
        "..kBNk..",
        "...kk...",
        "........",
    ],
]

# 아래 아이콘은 칠한 칸만 그린다 — outlined()가 바깥에 1px 외곽선 k를 붙인다(도트 팩 스타일).
STAR = [
    "................",
    "................",
    ".......YY.......",
    ".......Yy.......",
    "......YYyy......",
    "......Yyyy......",
    "..YYYYYyyyyyyy..",
    "...Yyyyyyyyyyo..",
    "....Yyyyyyyyo...",
    ".....yyyyyyo....",
    "....Yyyyyyyyo...",
    "....yyyyoyyyo...",
    "...Yyyo..oyyo...",
    "...yyo....yyo...",
    "................",
    "................",
]
PART_CANNON = [
    "................",
    "................",
    "............gg..",
    "...........gGGk.",
    ".........ggGGGS.",
    ".......ggGGGGS..",
    ".....ggGGGGSS...",
    "...ogGGGGGSS....",
    "...GGGGGSS......",
    "..dbbbbbbbd.....",
    "..dbbbbbbbbd....",
    "..ddddddddd.....",
    "..SggS..SggS....",
    "..SgSS..SgSS....",
    "...SS....SS.....",
    "................",
]
PART_HULL = [
    "................",
    "................",
    "................",
    "..............d.",
    ".............dd.",
    ".dddddddddddddd.",
    ".bbbbbbbbbbbbbb.",
    ".bbbkbbbbkbbbbb.",
    ".dddddddddddddd.",
    "..bbbbbbbbbbbbb.",
    "...bbbbbbbbbbb..",
    "...dddddddddd...",
    "....bbbbbbbbb...",
    "................",
    "................",
    "................",
]
PART_SAIL = [
    "................",
    ".......Drr......",
    "....WWWDWWWW....",
    "....WWWDWWWWW...",
    "...WWWWDWWWWW...",
    "...WWWWDWWWWWW..",
    "...uuuuDuuuuuu..",
    "..WWWWWDWWWWWW..",
    "..WWWWWDWWWWWWW.",
    "..WWWWWDWWWWWWW.",
    ".WWWWWWDWWWWWWW.",
    ".PPPPPPDPPPPPPP.",
    ".......D........",
    ".......D........",
    "................",
    "................",
]
PART_CROWSNEST = [
    "................",
    ".......D........",
    ".......Drr......",
    ".......Drrr.....",
    "...yyyY.D.......",
    "...dddddddddd...",
    "...bbbbbbbbbb...",
    "...bbbdbbdbbb...",
    "....bbbbbbbb....",
    ".......D........",
    ".......D........",
    ".......D........",
    ".......D........",
    ".......D........",
    "................",
    "................",
]
PART_CARGO = [
    "................",
    "................",
    "................",
    ".....yYy........",
    "...yYyyYyy......",
    "..bbbbbbbbbbbb..",
    "..dddddddddddd..",
    "..bdbbbbbbbbdb..",
    "..bdbbbbbbbbdb..",
    "..dddddddddddd..",
    "..bdbbbbbbbbdb..",
    "..bdbbbbbbbbdb..",
    "..dddddddddddd..",
    "................",
    "................",
    "................",
]


def coin16() -> list[str]:
    """16px 금화: 테두리 고리(왼쪽 위 밝고 오른쪽 아래 어둡게) + 안쪽 면 + 십자 각인 + 반짝임."""
    rows = []
    for y in range(16):
        row = ""
        for x in range(16):
            dx, dy = x + 0.5 - 8, y + 0.5 - 8
            d = (dx * dx + dy * dy) ** 0.5
            if d > 6.6:
                row += "."
            elif d > 5.0:
                row += "Y" if dx + dy < -3 else ("o" if dx + dy > 3 else "y")
            elif (x in (7, 8) and 5 <= y <= 10) or (y in (7, 8) and 5 <= x <= 10):
                row += "o"
            else:
                row += "Y" if dx + dy < -4 else "y"
        rows.append(row)
    rows[4] = rows[4][:5] + "w" + rows[4][6:]
    return rows


def outlined(rows: list[str]) -> list[str]:
    """투명 칸 중 상하좌우로 칠한 칸에 닿는 칸을 외곽선 k로."""
    h, w = len(rows), len(rows[0])
    out = [list(r) for r in rows]
    for y in range(h):
        for x in range(w):
            if rows[y][x] != ".":
                continue
            for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                if 0 <= nx < w and 0 <= ny < h and rows[ny][nx] not in ".k":
                    out[y][x] = "k"
                    break
    return ["".join(r) for r in out]


# ---- S4 요청 묶음 (2026-10-15): 남색 판 위에서 잘 보이게 흰·금 위주 ----
QUEST = [
    "................",
    ".....gggggg.....",
    "...bbgwwwwgbb...",
    "..bbbggggggbbb..",
    "..bppppppppppb..",
    "..bpppppppppvb..",
    "..bppppppppvvb..",
    "..bpvpppppvvpb..",
    "..bpvvpppvvppb..",
    "..bppvvpvvpppb..",
    "..bpppvvvppppb..",
    "..bppppvpppppb..",
    "..bppppppppppb..",
    "..bbbbbbbbbbbb..",
    "................",
    "................",
]
TAILWIND = [
    "................",
    ".......Drr......",
    ".......D........",
    ".......DWWWW....",
    "CCCC...DWWWWW...",
    ".......DWWWWWW..",
    "..CCCCCDWWWWWW..",
    ".......DWWWWWW..",
    "CCC....DWWWWW...",
    ".......DWWWW....",
    ".......DPPP.....",
    ".......D........",
    "..bbbbbbbbbbbb..",
    "...bbbbbbbbbb...",
    "................",
    "................",
]
AD = [
    "................",
    ".....g...g......",
    "......g.g.......",
    "..gggggggggggg..",
    "..gBBBBBBBBBBg..",
    "..gBBBwBBBBBBg..",
    "..gBBBwwBBBBBg..",
    "..gBBBwwwBBBBg..",
    "..gBBBwwwwBBBg..",
    "..gBBBwwwBBBBg..",
    "..gBBBwwBBBBBg..",
    "..gBBBwBBBBBBg..",
    "..gggggggggggg..",
    "...g........g...",
    "................",
    "................",
]
LOCK = [
    "................",
    ".....gggggg.....",
    "....gg....gg....",
    "....gg....gg....",
    "....gg....gg....",
    "....gg....gg....",
    "...YYYYYYYYYY...",
    "...Yyyyyyyyyy...",
    "...YyyyDDyyyy...",
    "...YyyyDDyyyy...",
    "...YyyyyDyyyy...",
    "...Yyyyyyyyyy...",
    "...oooooooooo...",
    "................",
    "................",
    "................",
]
HAND = [
    "................",
    "......ss........",
    "......ss........",
    "......ss........",
    "......sszsz.....",
    "......ssssssz...",
    "...ss.sssssss...",
    "...ssssssssss...",
    "....sssssssss...",
    "....zssssssss...",
    ".....sssssss....",
    ".....wwwwwww....",
    ".....wwwwwww....",
    "................",
    "................",
    "................",
]
BUBBLE = [
    "................",
    "................",
    "...wwwwwwwwww...",
    "..wwwwwwwwwwww..",
    "..wwwwwwwwwwww..",
    "..wwwSwwSwwSww..",
    "..wwwSwwSwwSww..",
    "..wwwwwwwwwwww..",
    "...wwwwwwwwww...",
    "...www..........",
    "...ww...........",
    "..w.............",
    "................",
    "................",
    "................",
    "................",
]
CHECK = [
    "........",
    ".vvvvvv.",
    ".vvvvvw.",
    ".vvvvwv.",
    ".vwvwvv.",
    ".vvwvvv.",
    ".vvvvvv.",
    "........",
]
CHECK_EMPTY = [
    "........",
    ".GGGGGG.",
    ".GSSSSG.",
    ".GSSSSG.",
    ".GSSSSG.",
    ".GSSSSG.",
    ".GGGGGG.",
    "........",
]
QMARK = [
    "..wwww..",
    ".wwwwww.",
    "ww....ww",
    "......ww",
    ".....ww.",
    "....ww..",
    "...ww...",
    "...ww...",
    "........",
    "...ww...",
    "...ww...",
]


def _blank(n: int) -> list[list[str]]:
    return [["."] * n for _ in range(n)]


def _rows(g: list[list[str]]) -> list[str]:
    return ["".join(r) for r in g]


def _polar(n: int):
    c = n / 2
    for y in range(n):
        for x in range(n):
            dx, dy = x + 0.5 - c, y + 0.5 - c
            yield x, y, dx, dy, (dx * dx + dy * dy) ** 0.5, math.degrees(math.atan2(dy, dx))


def gear16() -> list[str]:
    """톱니 8개 + 가운데 구멍. 왼쪽 위 밝고 오른쪽 아래 어둡게."""
    g = _blank(16)
    for x, y, dx, dy, d, a in _polar(16):
        tooth = abs((a + 360) % 45 - 22.5) > 12  # 45°마다 이(톱니)
        if d < 2.0:
            continue
        if d <= 4.8 or (d <= 6.8 and tooth):
            g[y][x] = "w" if dx + dy < -3 else ("G" if dx + dy > 3 else "g")
    return _rows(g)


def moon16() -> list[str]:
    """초승달: 큰 원에서 오른쪽 위로 비킨 원을 뺀다."""
    g = _blank(16)
    for x, y, dx, dy, d, _ in _polar(16):
        cut = ((dx - 2.6) ** 2 + (dy + 2.2) ** 2) ** 0.5
        if d <= 6.4 and cut > 5.2:
            g[y][x] = "Y" if dx + dy < -2 else ("o" if dy > 3.5 else "y")
    return _rows(g)


FARM = [
    "................",
    "................",
    ".....YYYYYY.....",
    "...YYY....YYY...",
    "..YY........YY..",
    "..YY........YY..",
    "..........YYYYY.",
    "...y.......YYY..",
    "..yyy.......Y...",
    ".yyyyy..........",
    "..yy........yy..",
    "..yy........yy..",
    "...yyy....yyy...",
    ".....yyyyyy.....",
    "................",
    "................",
]


def farm16() -> list[str]:
    """반복(자동 사냥): 시계 방향 두 갈래 화살표 (위 금빛 → 오른쪽 아래로, 아래 → 왼쪽 위로)."""
    return FARM


def flag16() -> list[str]:
    """목표 깃발: 체크무늬(흰·남색) 깃발 + 금 공 꼭지 + 막대."""
    g = _blank(16)
    g[1][4] = "Y"
    for y in range(2, 15):
        g[y][4] = "g"
    for y in range(2, 9):
        right = 12 + (1 if y in (4, 5) else 0) - (1 if y in (2, 8) else 0)
        for x in range(5, right + 1):
            g[y][x] = "w" if ((y - 2) // 2 + (x - 5) // 2) % 2 == 0 else "S"
    for x in range(2, 7):
        g[14][x] = "G"
    return _rows(g)


REBIRTH = [
    "................",
    ".......YYYYY....",
    ".....YYYYYYYY...",
    "....YY......YY..",
    "..YYYYYY....YY..",
    "...YYYY.....YY..",
    "....YY.....YY...",
    "..........YY....",
    ".ppppppppP......",
    ".pBBpppppP......",
    ".pBBBpprpr......",
    ".ppBpppprP......",
    ".pppppprpr......",
    ".ppppppppP......",
    "..pp.ppp.pP.....",
    "................",
]


def rebirth16() -> list[str]:
    """환생: 지도 조각(물·X 표시) + 위에서 왼쪽 아래로 도는 되돌이 화살표."""
    return REBIRTH


def card_back32() -> list[str]:
    """소환 카드 뒷면 32px: 금 테 + 남색 마름모 격자 + 가운데 흰 '?'(2배)."""
    g = _blank(32)
    for y in range(2, 30):
        for x in range(5, 27):
            if x in (5, 26) and y in (2, 29):
                continue
            if x in (5, 6, 25, 26) or y in (2, 3, 28, 29):
                g[y][x] = "Y" if (x <= 6 or y <= 3) else "o"
            else:
                g[y][x] = "B" if ((x + y) % 6 == 0 or (x - y) % 6 == 0) else "N"
    for qy, row in enumerate(QMARK):
        for qx, ch in enumerate(row):
            if ch == "w":
                for yy in (0, 1):
                    for xx in (0, 1):
                        g[5 + qy * 2 + yy][8 + qx * 2 + xx] = "w"
    return _rows(g)


def png(rows: list[str]) -> bytes:
    h = len(rows)
    w = len(rows[0])
    for r in rows:
        assert len(r) == w, f"행 길이가 다름: {r!r}"
    raw = bytearray()
    for r in rows:
        raw.append(0)
        for ch in r:
            col = PALETTE[ch]
            raw.extend((0, 0, 0, 0) if col is None else (*col, 255))

    def chunk(kind: bytes, data: bytes) -> bytes:
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)

    ihdr = struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0)
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", zlib.compress(bytes(raw), 9)) + chunk(b"IEND", b"")


def sheet(frames: list[list[str]]) -> list[str]:
    return ["".join(f[y] for f in frames) for y in range(len(frames[0]))]


FILES = {
    "ui/tab_ship.png": SHIP,
    "ui/tab_crew.png": CREW,
    "ui/tab_summon.png": SUMMON,
    "ui/tab_map.png": MAP,
    "ui/gem.png": sheet(GEM),  # 8×8 × 3프레임 가로 시트
    "ui/coin.png": outlined(coin16()),
    "ui/star.png": outlined(STAR),
    "ui/part_cannon.png": outlined(PART_CANNON),
    "ui/part_hull.png": outlined(PART_HULL),
    "ui/part_sail.png": outlined(PART_SAIL),
    "ui/part_crowsnest.png": outlined(PART_CROWSNEST),
    "ui/part_cargo.png": outlined(PART_CARGO),
    "ui/gear.png": outlined(gear16()),
    "ui/quest.png": outlined(QUEST),
    "ui/tailwind.png": outlined(TAILWIND),
    "ui/flag.png": outlined(flag16()),
    "ui/ad.png": outlined(AD),
    "ui/farm.png": outlined(farm16()),
    "ui/lock.png": outlined(LOCK),
    "ui/rebirth.png": outlined(rebirth16()),
    "ui/moon.png": outlined(moon16()),
    "ui/card_back.png": outlined(card_back32()),
    "ui/check.png": outlined(CHECK),
    "ui/check_empty.png": outlined(CHECK_EMPTY),
    "ui/hand.png": outlined(HAND),
    "ui/bubble.png": outlined(BUBBLE),
}


def main(argv: list[str]) -> int:
    for stream in (sys.stdout, sys.stderr):
        stream.reconfigure(encoding="utf-8")
    check = "--check" in argv
    changed = []
    for rel, rows in FILES.items():
        data = png(rows)
        target = ASSETS / rel
        if target.is_file() and target.read_bytes() == data:
            continue
        changed.append(rel)
        if not check:
            target.parent.mkdir(parents=True, exist_ok=True)
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
        print("✓ UI 아이콘이 격자와 같다")
        return 0
    print(f"✓ {len(changed)}개 갱신" + (": " + ", ".join(changed) if changed else ""))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
