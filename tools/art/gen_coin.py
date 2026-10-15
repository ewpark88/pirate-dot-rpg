"""큰 금화 (사용자 지시 '돈이 금색 점처럼 들어와서 모르겠다') — PB 재화 아이콘(gold) 화풍의 매끈한 금화 4프레임 회전 시트. OWN.

    python -I tools/art/gen_coin.py            # apps/game/assets/fx/coin_hd.png 에 쓴다
    python -I tools/art/gen_coin.py --check    # 쓰지 않고, 결과가 지금 파일과 다르면 실패

프레임 96×96 × 4 (가로): 정면 → 비스듬 → 옆면(테 두께) → 비스듬. 굵은 어두운 외곽선, 금 몸, 안쪽 고리, 가로 줄 문양 3개(PB gold 아이콘),
왼쪽 위 하이라이트, 정면 프레임에 반짝 별. 4배 크기로 그려 줄여서(LANCZOS) 매끈하다. 같은 입력·같은 Pillow면 같은 바이트.
"""

from __future__ import annotations

import io
import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw

sys.dont_write_bytecode = True

ROOT = Path(__file__).resolve().parents[2]
ASSETS = ROOT / "apps" / "game" / "assets"
DEST = "fx/coin_hd.png"
SOURCE = "Pirate Busters 자체 IP 화풍 → tools/art/gen_coin.py 코드 그림"

F = 96  # 프레임 한 변
S = 4  # 슈퍼샘플 배율
OUTLINE = (27, 23, 38, 255)
BODY = (240, 178, 52, 255)
BODY_DARK = (205, 140, 32, 255)
RING = (181, 121, 28, 255)
LIGHT = (255, 226, 122, 255)
EDGE = (170, 110, 24, 255)
WHITE = (255, 255, 255, 255)
SQUASH = [1.0, 0.68, 0.22, 0.68]


def frame(i: int) -> Image.Image:
    n = F * S
    im = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    sx = SQUASH[i]
    r = n * 0.40
    cx = cy = n / 2
    rx = max(r * sx, r * 0.14)
    ow = n * 0.055
    # 옆면 두께(돌 때 보이는 테): 오른쪽으로 살짝 밀린 어두운 타원
    if sx < 1:
        th = r * 0.22 * (1 - sx)
        d.ellipse((cx - rx + th - ow, cy - r - ow, cx + rx + th + ow, cy + r + ow), fill=OUTLINE)
        d.ellipse((cx - rx + th, cy - r, cx + rx + th, cy + r), fill=EDGE)
    d.ellipse((cx - rx - ow, cy - r - ow, cx + rx + ow, cy + r + ow), fill=OUTLINE)
    d.ellipse((cx - rx, cy - r, cx + rx, cy + r), fill=BODY)
    # 아래 오른쪽 그늘(반달)
    d.chord((cx - rx, cy - r, cx + rx, cy + r), 20, 160, fill=BODY_DARK)
    d.ellipse((cx - rx * 0.92, cy - r * 0.92, cx + rx * 0.92, cy + r * 0.86), fill=BODY)
    if sx > 0.3:
        ir = 0.68
        w = n * 0.03
        d.ellipse((cx - rx * ir, cy - r * ir, cx + rx * ir, cy + r * ir), outline=RING, width=max(1, round(w)))
        for k in (-1, 0, 1):
            y = cy + k * r * 0.26
            hw = rx * 0.34
            d.rounded_rectangle((cx - hw, y - n * 0.022, cx + hw, y + n * 0.022), radius=n * 0.02, fill=OUTLINE)
    # 왼쪽 위 하이라이트 호
    d.arc((cx - rx * 0.8, cy - r * 0.8, cx + rx * 0.8, cy + r * 0.8), 200, 260, fill=LIGHT, width=max(2, round(n * 0.04)))
    if i == 0:
        sx0, sy0, a = cx + r * 0.62, cy - r * 0.66, n * 0.12
        d.polygon(
            [(sx0, sy0 - a), (sx0 + a * 0.22, sy0 - a * 0.22), (sx0 + a, sy0), (sx0 + a * 0.22, sy0 + a * 0.22),
             (sx0, sy0 + a), (sx0 - a * 0.22, sy0 + a * 0.22), (sx0 - a, sy0), (sx0 - a * 0.22, sy0 - a * 0.22)],
            fill=WHITE,
        )
    return im.resize((F, F), Image.LANCZOS)


def sheet() -> bytes:
    out = Image.new("RGBA", (F * len(SQUASH), F), (0, 0, 0, 0))
    for i in range(len(SQUASH)):
        out.alpha_composite(frame(i), (i * F, 0))
    buf = io.BytesIO()
    out.save(buf, "PNG", optimize=True)
    return buf.getvalue()


def main(argv: list[str]) -> int:
    for stream in (sys.stdout, sys.stderr):
        stream.reconfigure(encoding="utf-8")
    check = "--check" in argv
    data = sheet()
    target = ASSETS / DEST
    changed = not (target.is_file() and target.read_bytes() == data)
    lic_path = ASSETS / "LICENSES.json"
    lic = json.loads(lic_path.read_text(encoding="utf-8"))
    files = dict(lic.get("files", {}))
    files[DEST] = {"source": SOURCE, "license": "OWN"}
    text = json.dumps({**lic, "files": dict(sorted(files.items()))}, ensure_ascii=False, indent=2) + "\n"
    lic_changed = lic_path.read_text(encoding="utf-8") != text
    if check:
        if changed or lic_changed:
            print("✗ 금화 시트가 다름", file=sys.stderr)
            return 1
        print("✓ 금화 시트가 같다")
        return 0
    if changed:
        target.write_bytes(data)
    if lic_changed:
        lic_path.write_text(text, encoding="utf-8", newline="\n")
    print(f"✓ {DEST} {'갱신' if changed else '그대로'} ({len(data) // 1024}KB)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
