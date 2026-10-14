"""UI 도트 아이콘 생성 (탭 바 16×16 4개 + 젬 8×8 3프레임). 픽셀 격자 → PNG, LICENSES.json(OWN) 갱신.

    python -I tools/art/gen_ui_icons.py            # apps/game/assets/ui/ 에 쓴다
    python -I tools/art/gen_ui_icons.py --check    # 쓰지 않고, 결과가 지금 파일과 다르면 실패

외부 라이브러리 없음(zlib PNG). 팔레트는 도트 팩 v0.2·기준 장면(battle_ship.gif)의 색과 외곽선 (27,23,38).
같은 입력이면 같은 바이트(다시 굽기 가능).
"""

from __future__ import annotations

import json
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
