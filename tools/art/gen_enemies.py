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
    "t": (82, 74, 80),  # 용암 거북 등딱지(현무암)
    "T": (60, 54, 60),
    "L": (255, 140, 40),  # 용암 빛
    "g": (190, 160, 112),  # 거북 머리·다리 (어두운 바다 위에서 보이게 밝게)
    "G": (140, 112, 78),
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


# 용암 거북 (화산, 단단함): 프레임 20×12, 머리 왼쪽, 현무암 등딱지에 용암 금. 프레임 2는 다리를 바꾼다.
LAVATURTLE = [
    [
        "....................",
        "......tttttttt......",
        "....ttTtLttTtttt....",
        "...tttLtttLtttLttt..",
        "..ttTttttLttttTtttt.",
        ".ggtLtttTtttLttttTt.",
        "gekgTTTTTTTTTTTTTTT.",
        "ggggggGGGGGGGGGGGgg.",
        ".gggg.............g.",
        "..GG...GG....GG..GG.",
        "..GG...GG....GG..GG.",
        "....................",
    ],
    [
        "....................",
        "......tttttttt......",
        "....ttTtLttTtttt....",
        "...tttLtttLtttLttt..",
        "..ttTttttLttttTtttt.",
        ".ggtLtttTtttLttttTt.",
        "gekgTTTTTTTTTTTTTTT.",
        "ggggggGGGGGGGGGGGgg.",
        ".gggg.............g.",
        "...GG...GG....GG..G.",
        "....GG...GG....GG...",
        "....................",
    ],
]


def star_frames(size: int, outer: float, inner: float, rots: tuple[float, ...], body, shade, dot, eyes: bool):
    """다섯 팔 불가사리: 다각형 안쪽 칠하기, 오른쪽 아래 그늘, 점무늬, 가운데 눈. 프레임마다 조금 돌린다."""
    import math

    frames = []
    for rot in rots:
        pts = []
        for i in range(10):
            a = math.radians(-90 + rot + i * 36)
            r = outer if i % 2 == 0 else inner
            pts.append((size / 2 + r * math.cos(a), size / 2 + 0.5 + r * math.sin(a)))
        rows = []
        for y in range(size):
            row = ""
            for x in range(size):
                if _b._in_poly(x + 0.5, y + 0.5, pts):
                    dx, dy = x + 0.5 - size / 2, y + 0.5 - size / 2
                    row += "2" if dx + dy > outer * 0.5 else ("3" if (x * 7 + y * 3) % 11 == 0 else "1")
                else:
                    row += "."
            rows.append(row)
        if eyes:
            c = size // 2
            rows[c - 1] = rows[c - 1][: c - 2] + "ek.ek"[0:2] + rows[c - 1][c:c + 1] + "ek" + rows[c - 1][c + 3 :]
        frames.append(rows)
    return frames, {"1": body, "2": shade, "3": dot}


STAR_COLORS = ((255, 190, 90), (220, 120, 60), (255, 236, 170))


# ---- 묶음 5 심연 (모두 수중 → 렌더가 어둡게 칠하니 밝은 몸 + 빛나는 부분) ----
ABYSS_COLORS = {
    "a": (150, 136, 192),  # 아귀 몸 (심연 바다 위에서 보이게 밝게)
    "b": (112, 100, 152),
    "s": (130, 140, 170),  # 초롱 줄기
    "L": (255, 240, 140),  # 빛나는 초롱
    "t": (30, 20, 30),  # 입 안
    "W": (245, 245, 250),  # 이빨
    "f": (92, 110, 152),  # 지느러미
    "p": (235, 120, 155),  # 오징어
    "P": (175, 70, 115),
}

# 아귀 (부활): 프레임 18×12, 머리 왼쪽, 초롱이 흔들린다.
ANGLER = [
    [
        "..LL..............",
        "..LLs.............",
        "....s.............",
        ".....saaaaaa......",
        "...aaaaaaaaaaa..ff",
        "..aeakaaaaaaaaaff.",
        ".aaaaaaaaaaaaaff..",
        ".tWtWtbbbbbbbbff..",
        "..tWtWbbbbbbbbbff.",
        "...bbbbbbbbbbb.ff.",
        ".....bbbbbbb......",
        "..................",
    ],
    [
        "...LL.............",
        "...LLs............",
        ".....s............",
        ".....saaaaaa......",
        "...aaaaaaaaaaa.ff.",
        "..aeakaaaaaaaaaff.",
        ".aaaaaaaaaaaaaff..",
        ".tttWtbbbbbbbbff..",
        "..tWtWbbbbbbbbbff.",
        "...bbbbbbbbbbb..ff",
        ".....bbbbbbb......",
        "..................",
    ],
]

# 오징어: 프레임 17×11, 몸통 오른쪽·다리 왼쪽(앞으로 헤엄), 다리를 오므렸다 편다.
SQUID = [
    [
        ".................",
        "..........ppp....",
        "........ppppppP..",
        ".....ppppppppppP.",
        "...peppppppppppP.",
        "..pkppppppppppP..",
        ".ppppppppppppP...",
        "PPpPPpPP.........",
        "P.P.P.P..........",
        ".P..P..P.........",
        ".................",
    ],
    [
        ".................",
        "..........ppp....",
        "........ppppppP..",
        ".....ppppppppppP.",
        "...peppppppppppP.",
        "..pkppppppppppP..",
        ".ppppppppppppP...",
        ".PPPPPPP.........",
        "PP.PP.PP.........",
        "P..P..P..........",
        ".................",
    ],
]


def siphon_frames() -> tuple[list[list[str]], dict]:
    """관해파리(부활): 빛나는 청록 구슬 셋이 줄기로 이어져 물결친다. 프레임 17×10."""
    import math

    frames = []
    for phase in (0, 1):
        g = [["."] * 17 for _ in range(10)]
        for x in range(1, 16):
            y = round(5 + math.sin(x * 0.45 + phase * math.pi) * 1)
            g[y][x] = "m"
        for i, cx in enumerate((3.5, 8.5, 13.5)):
            cy = 5 + math.sin(cx * 0.45 + phase * math.pi) * 1
            r = 2.6 if i == 0 else 2.2
            for y in range(10):
                for x in range(17):
                    d = math.hypot(x + 0.5 - cx, y + 0.5 - cy)
                    if d <= r:
                        g[y][x] = "h" if (x + 0.5 - cx) + (y + 0.5 - cy) < -1.2 else "o"
        frames.append(["".join(r) for r in g])
    return frames, {"o": (120, 230, 220), "h": (220, 255, 250), "m": (60, 150, 160)}


def eel_frames() -> tuple[list[list[str]], dict]:
    """곰치(빠름): 머리 왼쪽, 몸이 사인 곡선으로 굽이친다. 프레임 24×10, 위상 반 바퀴."""
    import math

    frames = []
    for phase in (0, math.pi):
        g = [["."] * 24 for _ in range(10)]
        for x in range(1, 23):
            cy = 4.5 + 1.4 * math.sin(x * 0.5 + phase) * min(1, x / 6)
            half = 2.1 if x < 6 else max(1.0, 2.0 - (x - 6) * 0.06)
            for y in range(10):
                if abs(y + 0.5 - cy) <= half:
                    g[y][x] = "G" if y + 0.5 > cy + half * 0.3 else "g"
        hy = round(4.5 + 1.4 * math.sin(3 * 0.5 + phase) * 0.5 - 1)
        g[hy][3] = "e"
        frames.append(["".join(r) for r in g])
    return frames, {"g": (90, 190, 150), "G": (55, 130, 105), "e": (255, 240, 140)}

# 팔레트 바꿈 변형: 팩 적 → 색 표 (외곽선 (27,23,38)은 그대로).
RECOLORS = {
    "icecrab": ("crab", {(220, 70, 60): (205, 232, 250), (150, 40, 40): (95, 150, 205)}),  # 서리 흰빛 + 얼음 파랑 그늘(바다 위 대비)
    "snowgull": ("gull", {(245, 245, 250): (215, 235, 255), (250, 150, 60): (120, 200, 240)}),  # 눈빛 + 얼음 부리
    "lavacrab": ("crab", {(220, 70, 60): (120, 108, 112), (150, 40, 40): (255, 140, 40)}),  # 현무암 + 아래 용암 빛
    "firebird": ("gull", {(245, 245, 250): (255, 225, 120), (250, 150, 60): (230, 70, 40)}),  # 달아오른 노랑(주황 하늘 위 대비) + 붉은 부리
    "stormgull": ("gull", {(245, 245, 250): (196, 204, 226), (250, 150, 60): (250, 210, 70)}),  # 푸른 잿빛(폭풍 하늘 위에서도 보이게) + 노란 부리
}


def from_grid(frames: list[list[str]], colors: dict | None = None) -> list[list]:
    pal = {**COLORS, **(colors or {})}
    out: list[list] = [[] for _ in frames[0]]
    for rows in frames:
        assert all(len(r) == len(rows[0]) for r in rows), f"행 길이가 다름: {rows}"
        px = [[None if ch == "." else pal[ch] for ch in r] for r in rows]
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
        "enemies/lavacrab_small.png": from_grid(ICECRAB_SMALL, {"a": (120, 108, 112), "A": (255, 140, 40)}),
        "enemies/lavaturtle.png": from_grid(LAVATURTLE),
    }
    big, pal = star_frames(15, 7.2, 3.0, (0, 9), *STAR_COLORS, eyes=True)
    files["enemies/starfish.png"] = from_grid(big, pal)
    small, pal = star_frames(11, 5.2, 2.2, (0, 9), *STAR_COLORS, eyes=False)
    files["enemies/starfish_small.png"] = from_grid(small, pal)
    files["enemies/angler.png"] = from_grid(ANGLER, ABYSS_COLORS)
    files["enemies/squid.png"] = from_grid(SQUID, ABYSS_COLORS)
    frames, pal = siphon_frames()
    files["enemies/siphon.png"] = from_grid(frames, pal)
    frames, pal = eel_frames()
    files["enemies/eel.png"] = from_grid(frames, pal)
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
