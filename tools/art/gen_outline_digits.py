"""쿵푸할매식 테두리 숫자 아틀라스(디자인 개편 공용 부품, S1 지시 2026-10-17) — 흰·금·빨강·초록 글씨 + 굵은 검은 테 + 아래쪽 그림자. OWN.

    python -I tools/art/gen_outline_digits.py            # apps/game/assets/ui/digits/{,2.0x/,3.0x/}outline_digits.png + outline_digits.json
    python -I tools/art/gen_outline_digits.py --check    # 쓰지 않고, 결과가 지금 파일과 다르면 실패

글꼴: assets/fonts/Jua-Regular.ttf(OFL-1.1, 이미 등록 — 둥글고 굵다). 4배로 그려 줄여서(LANCZOS) 매끈하다.
아틀라스: 한 줄 = 한 색(COLORS 순서), 칸 높이 CELL_H, 글리프는 GLYPHS 순서로 왼쪽부터. 좌표는 **1x 기준**(json) —
2.0x·3.0x 파일은 같은 배치를 그 배율로 그린 것. 읽는 쪽(render/text/outline_digits.dart)은 실제 그림 폭 ÷ json width로 배율을 안다.
json: {width, height, cellHeight, baseline, colors: {이름: 줄 y}, glyphs: {글자: {x, w, advance}}} — advance는 다음 글자까지(테가 겹치게 w보다 작다).
"""

from __future__ import annotations

import io
import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

sys.dont_write_bytecode = True

ROOT = Path(__file__).resolve().parents[2]
ASSETS = ROOT / "apps" / "game" / "assets"
FONT = ASSETS / "fonts" / "Jua-Regular.ttf"
NAME = "ui/digits/outline_digits"
SOURCE = "Jua(OFL-1.1, assets/fonts) 글리프 → tools/art/gen_outline_digits.py 코드 그림(테두리·그림자·색)"
GLYPHS = "0123456789KMBT%/+×.,-:"
# (이름, 위 색, 아래 색) — 위에서 아래로 살짝 진해지는 광택. 흰색은 아래가 아주 옅은 회색.
COLORS = [
    ("white", (255, 255, 255), (226, 232, 240)),
    ("gold", (255, 236, 120), (255, 176, 32)),
    ("red", (255, 120, 104), (226, 52, 44)),
    ("green", (156, 240, 120), (64, 196, 72)),
]
OUTLINE = (20, 16, 28, 255)
SHADOW = (0, 0, 0, 120)
SIZE = 28  # 1x 글자 크기(px)
STROKE = 4  # 1x 테 두께
SHADOW_DY = 2  # 1x 그림자 아래로
PAD = 2
CELL_H = SIZE + STROKE * 2 + SHADOW_DY + PAD * 2
SCALES = {"": 1, "2.0x/": 2, "3.0x/": 3}
SS = 4


DRAWN = "×"  # Jua에 없는 글자 — '+' 크기로 직접 그린다(대각선 두 획)


def _metrics(font: ImageFont.FreeTypeFont, ch: str, k: int) -> tuple[int, int]:
    x0, _, x1, _ = font.getbbox("+" if ch in DRAWN else ch, stroke_width=STROKE * k)
    return x0, x1


def _glyph(d: ImageDraw.ImageDraw, font: ImageFont.FreeTypeFont, ch: str, xy: tuple[int, int], k: int, fill, stroke: int) -> None:
    """한 글자를 [fill]로(stroke > 0이면 그만큼 굵게 — 테·그림자). ×는 '+' 칸 안에 대각선 두 획."""
    if ch not in DRAWN:
        d.text(xy, ch, font=font, fill=fill, stroke_width=stroke, stroke_fill=fill)
        return
    x0, y0, x1, y1 = font.getbbox("+")
    cx, cy = xy[0] + (x0 + x1) / 2, xy[1] + (y0 + y1) / 2
    r = (x1 - x0) / 2 * 0.62
    w = round(SIZE * k * 0.16) + stroke * 2
    for a, b in (((-r, -r), (r, r)), ((-r, r), (r, -r))):
        d.line([(cx + a[0], cy + a[1]), (cx + b[0], cy + b[1])], fill=fill, width=w)
        for px, py in (a, b):  # 둥근 끝
            d.ellipse([cx + px - w / 2, cy + py - w / 2, cx + px + w / 2, cy + py + w / 2], fill=fill)


def layout() -> dict:
    """1x 배치(글리프 x·w·advance). 배율과 무관하게 같다(1x 글꼴로 잰다)."""
    font = ImageFont.truetype(str(FONT), SIZE * SS)
    glyphs = {}
    x = PAD
    for ch in GLYPHS:
        x0, x1 = _metrics(font, ch, SS)
        w = -(-(x1 - x0) // SS) + 1  # 올림 + 1px 여유
        adv = max(1, w - STROKE)  # 테가 이웃과 겹치게
        glyphs[ch] = {"x": x, "w": w, "advance": adv}
        x += w + PAD
    ascent, _ = font.getmetrics()
    return {
        "width": x,
        "height": CELL_H * len(COLORS),
        "cellHeight": CELL_H,
        "baseline": PAD + STROKE + round(ascent / SS),
        "colors": {name: i * CELL_H for i, (name, _, _) in enumerate(COLORS)},
        "glyphs": glyphs,
    }


def render(lay: dict, scale: int) -> bytes:
    k = scale * SS
    font = ImageFont.truetype(str(FONT), SIZE * k)
    w, h = lay["width"] * k, lay["height"] * k
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    for row, (_, top, bottom) in enumerate(COLORS):
        y0 = row * CELL_H * k
        for ch, g in lay["glyphs"].items():
            x0, _ = _metrics(font, ch, k)
            ox = g["x"] * k - x0
            oy = y0 + (PAD + STROKE) * k
            # 그림자(테째로 아래로) → 테 → 광택 채움
            sh = Image.new("RGBA", (w, h), (0, 0, 0, 0))
            _glyph(ImageDraw.Draw(sh), font, ch, (ox, oy + SHADOW_DY * k), k, SHADOW, STROKE * k)
            out.alpha_composite(sh)
            _glyph(ImageDraw.Draw(out), font, ch, (ox, oy), k, OUTLINE, STROKE * k)
            mask = Image.new("L", (w, h), 0)
            _glyph(ImageDraw.Draw(mask), font, ch, (ox, oy), k, 255, 0)
            grad = Image.new("RGBA", (w, h), (0, 0, 0, 0))
            gd = ImageDraw.Draw(grad)
            cell_top, cell_h = oy, SIZE * k
            for yy in range(cell_h + 1):
                u = yy / cell_h
                c = tuple(round(top[i] + (bottom[i] - top[i]) * u) for i in range(3))
                gd.line([(g["x"] * k, cell_top + yy), ((g["x"] + g["w"]) * k, cell_top + yy)], fill=(*c, 255))
            out.paste(grad, (0, 0), mask)
    img = out.resize((lay["width"] * scale, lay["height"] * scale), Image.LANCZOS)
    buf = io.BytesIO()
    img.save(buf, "PNG", optimize=True)
    return buf.getvalue()


def main(argv: list[str]) -> int:
    for stream in (sys.stdout, sys.stderr):
        stream.reconfigure(encoding="utf-8")
    check = "--check" in argv
    lay = layout()
    outputs = {f"ui/digits/{sub}outline_digits.png": render(lay, sc) for sub, sc in SCALES.items()}
    outputs[f"{NAME}.json"] = (json.dumps(lay, ensure_ascii=False, indent=1) + "\n").encode("utf-8")
    lic_path = ASSETS / "LICENSES.json"
    lic = json.loads(lic_path.read_text(encoding="utf-8"))
    files = dict(lic.get("files", {}))
    changed = []
    for rel, data in outputs.items():
        target = ASSETS / rel
        if not (target.is_file() and target.read_bytes() == data):
            changed.append(rel)
            if not check:
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(data)
        files[rel] = {"source": SOURCE, "license": "OWN"}
    text = json.dumps({**lic, "files": dict(sorted(files.items()))}, ensure_ascii=False, indent=2) + "\n"
    lic_changed = lic_path.read_text(encoding="utf-8") != text
    if check:
        if changed or lic_changed:
            print(f"✗ 테두리 숫자가 다름: {changed or 'LICENSES.json'}", file=sys.stderr)
            return 1
        print("✓ 테두리 숫자가 같다")
        return 0
    if lic_changed:
        lic_path.write_text(text, encoding="utf-8", newline="\n")
    print(f"✓ {NAME} {len(GLYPHS)}글자 × {len(COLORS)}색 × 3배율 — 바뀐 파일 {len(changed)}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
