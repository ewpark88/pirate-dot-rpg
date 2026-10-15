"""적 도트 생성 (스펙 render-art-enemies). 2프레임 가로 시트(팩과 같은 형식), LICENSES OWN.

    python -I tools/art/gen_enemies.py            # apps/game/assets/enemies/ 에 쓴다
    python -I tools/art/gen_enemies.py --check    # 쓰지 않고, 결과가 지금 파일과 다르면 실패

- 새 실루엣: 칠한 칸 격자(프레임마다) → 프레임별 자동 1px 외곽선 (27,23,38).
- 변형: 팩 적(OWN)의 칸을 읽어 색만 바꾼다(외곽선·흰 눈은 그대로).
같은 입력이면 같은 바이트.
"""

from __future__ import annotations

import importlib.util
import json
import sys
from pathlib import Path

sys.dont_write_bytecode = True

HERE = Path(__file__).resolve().parent
ASSETS = HERE.parents[1] / "apps" / "game" / "assets"
SOURCE = "Pirate Busters v0.24 자체 IP → tools/art/gen_enemies.py 픽셀 격자"

_spec = importlib.util.spec_from_file_location("gen_bosses", HERE / "gen_bosses.py")
_b = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_b)

COLORS = {
    "b": (50, 100, 180),  # 날치 등
    "w": (220, 232, 245),  # 은빛 배
    "f": (150, 220, 250),  # 날개 지느러미
    "F": (60, 120, 190),  # 꼬리·지느러미 그늘
    "e": (245, 245, 250),  # 눈 (팩과 같은 흰색)
    "k": (27, 23, 38),  # 눈동자
    "a": (205, 232, 250),  # 얼음 게 (icecrab과 같은 색)
    "A": (95, 150, 205),
    "n": (40, 44, 60),  # 펭귄 검은 털
    "o": (250, 150, 60),  # 부리·발
    "s": (150, 155, 170),  # 물범
    "S": (105, 110, 128),
    "d": (40, 40, 50),
}

# 날치 (폭풍해, 수면·빠름): 머리 왼쪽, 프레임 1 날개 위 · 프레임 2 날개 펼침. 프레임 17×10 (팩 piranha와 같은 크기).
FLYINGFISH = [
    [
        ".................",
        "........ff.......",
        ".......fffF......",
        "...bbbbffFbb..F..",
        "..bbbbbbbbbbbbFF.",
        ".bebbbbbbbbbbbF..",
        ".bbwwwwwwwwwbbF..",
        "..wwwwwwwwwwwwFF.",
        "...wwwwwwwww..F..",
        ".................",
    ],
    [
        ".................",
        ".................",
        ".................",
        "...bbbbbbbbb..F..",
        "..bbbbffffbbbbFF.",
        ".bebbbfffffFbbF..",
        ".bbwwwwfffwwbbF..",
        "..wwwwwwwwwwwwFF.",
        "...wwwwwwwww..F..",
        ".................",
    ],
]


# 작은 얼음 게 (icecrab 분열): 프레임 11×8, 집게 위로, 다리 번갈아.
ICECRAB_SMALL = [
    [
        "...........",
        ".a.......a.",
        ".aa.....aa.",
        "..aaaaaaa..",
        "..aekaekaa.",
        "..AAAAAAA..",
        ".A.A...A.A.",
        "...........",
    ],
    [
        "...........",
        ".a.......a.",
        ".aa.....aa.",
        "..aaaaaaa..",
        "..aekaekaa.",
        "..AAAAAAA..",
        "..A.A.A.A..",
        "...........",
    ],
]

# 펭귄 (빙하, 빠름): 프레임 13×13, 머리 왼쪽(부리), 뒤뚱 걸음.
PENGUIN = [
    [
        ".............",
        "....nnnn.....",
        "...nnnnnn....",
        "..nkennnnn...",
        ".oonnnnnnn...",
        "..nwwwwnnnn..",
        "..wwwwwwnnnn.",
        "..wwwwwwnnnn.",
        "..wwwwwwnnn..",
        "..wwwwwwnnn..",
        "...wwwwwnn...",
        "...oo..oo....",
        ".............",
    ],
    [
        ".............",
        ".............",
        "....nnnn.....",
        "...nnnnnn....",
        "..nkennnnn...",
        ".oonnnnnnnn..",
        "..nwwwwnnnnn.",
        "..wwwwwwnnnn.",
        "..wwwwwwnnn..",
        "..wwwwwwnnn..",
        "...wwwwwnn...",
        "..oo....oo...",
        ".............",
    ],
]

# 물범 (빙하, 단단함): 프레임 20×11, 엎드림, 머리 왼쪽. 프레임 2는 꼬리 지느러미를 든다.
SEAL = [
    [
        "....................",
        "....................",
        "...ssss.............",
        "..sessss............",
        ".skssssss...........",
        ".dsssssssssss.......",
        "..ssssssssssssss....",
        "..SSssssssssssssss..",
        "...SSSSSSSSSSSSSSsS.",
        "........S.S......SS.",
        "....................",
    ],
    [
        "....................",
        "....................",
        "...ssss.............",
        "..sessss............",
        ".skssssss...........",
        ".dsssssssssss.......",
        "..ssssssssssssss..S.",
        "..SSsssssssssssssSS.",
        "...SSSSSSSSSSSSSS...",
        ".......S.S..........",
        "....................",
    ],
]

# 팔레트 바꿈 변형: 팩 적 → 색 표 (외곽선 (27,23,38)은 그대로).
RECOLORS = {
    "icecrab": ("crab", {(220, 70, 60): (205, 232, 250), (150, 40, 40): (95, 150, 205)}),  # 서리 흰빛 + 얼음 파랑 그늘(바다 위 대비)
    "snowgull": ("gull", {(245, 245, 250): (215, 235, 255), (250, 150, 60): (120, 200, 240)}),  # 눈빛 + 얼음 부리
    "stormgull": ("gull", {(245, 245, 250): (196, 204, 226), (250, 150, 60): (250, 210, 70)}),  # 푸른 잿빛(폭풍 하늘 위에서도 보이게) + 노란 부리
}


def from_grid(frames: list[list[str]]) -> list[list]:
    out: list[list] = [[] for _ in frames[0]]
    for rows in frames:
        assert all(len(r) == len(rows[0]) for r in rows), f"행 길이가 다름: {rows}"
        px = [[None if ch == "." else COLORS[ch] for ch in r] for r in rows]
        _b.outline(px)
        for y, row in enumerate(px):
            out[y].extend(row)
    return out


def recolor(base: str, table: dict) -> list[list]:
    src = _b.read_png(ASSETS / "enemies" / f"{base}.png")
    return [[None if c is None else table.get(c[:3], c[:3]) for c in row] for row in src]


def build() -> dict[str, list[list]]:
    files = {
        "enemies/flyingfish.png": from_grid(FLYINGFISH),
        "enemies/icecrab_small.png": from_grid(ICECRAB_SMALL),
        "enemies/penguin.png": from_grid(PENGUIN),
        "enemies/seal.png": from_grid(SEAL),
    }
    for name, (base, table) in RECOLORS.items():
        files[f"enemies/{name}.png"] = recolor(base, table)
    return files


def main(argv: list[str]) -> int:
    for stream in (sys.stdout, sys.stderr):
        stream.reconfigure(encoding="utf-8")
    check = "--check" in argv
    changed = []
    built = build()
    for rel, px in built.items():
        data = _b.write_png(px)
        target = ASSETS / rel
        if target.is_file() and target.read_bytes() == data:
            continue
        changed.append(rel)
        if not check:
            target.write_bytes(data)
    lic_path = ASSETS / "LICENSES.json"
    lic = json.loads(lic_path.read_text(encoding="utf-8"))
    files = dict(lic.get("files", {}))
    for rel in built:
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
        print("✓ 적 도트가 격자와 같다")
        return 0
    print(f"✓ {len(changed)}개 갱신" + (": " + ", ".join(changed) if changed else ""))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
