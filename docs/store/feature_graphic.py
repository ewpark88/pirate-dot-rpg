"""Play 그래픽 이미지 1024×500 — 앱 아이콘의 배 + 전투 장면, 글자 없음 (docs/store/listing.ko.md 그래픽 규격).

    python -I -B docs/store/feature_graphic.py     → build/store/feature_graphic.png (24비트 PNG, 알파 없음)

256×125 도트 캔버스를 그린 뒤 **정수 4배·최근접**으로 키운다(도트가 뭉개지지 않게).
그림은 전부 게임 에셋과 아이콘 원본에서 온다(새로 그린 픽셀은 바다 물결 점선·구름뿐). 바다·하늘 색은 실제 전장(산호해) 렌더에서 뽑았다.
같은 입력이면 같은 바이트(무작위 없음).
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
ASSETS = ROOT / "apps" / "game" / "assets"
ICON = ROOT / "tools" / "art" / "icon"
OUT = ROOT / "build" / "store" / "feature_graphic.png"

W, H, SCALE = 256, 125, 4  # 256·4 = 1024, 125·4 = 500

# 산호해 전장 색 (스크린샷 03에서 행별로 뽑음, 위 → 아래)
SKY = [(0, (90, 169, 230)), (14, (98, 174, 224)), (30, (125, 190, 229)), (42, (168, 220, 248)), (52, (205, 238, 252))]
SEA = [(62, (47, 143, 216)), (76, (47, 140, 208)), (80, (39, 120, 188)), (96, (35, 98, 169)), (108, (29, 79, 156))]
WAVE = (126, 196, 240)
CLOUD, CLOUD_SHADE = (255, 255, 255), (214, 236, 250)
HORIZON = 62


def _fx_sheets() -> tuple[dict, dict]:
    fx = json.loads((ROOT / "packages" / "game_data" / "tables" / "fx_map.json").read_text(encoding="utf-8"))
    sheets = {s["id"]: s for s in fx["fxSheets"]}
    colors = {k: tuple(int(v[i : i + 2], 16) for i in (1, 3, 5)) for k, v in fx["sheetColors"].items()}
    return sheets, colors


def frame(path: Path, w: int, h: int, index: int) -> Image.Image:
    sheet = Image.open(path).convert("RGBA")
    return sheet.crop((index * w, 0, index * w + w, h))


def tint(img: Image.Image, color: tuple[int, int, int]) -> Image.Image:
    """흰 마스크 시트에 색을 입힌다(게임의 sheetColors와 같게): 밝기 × 색."""
    out = img.copy()
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = px[x, y]
            if a:
                lum = max(r, g, b) / 255
                px[x, y] = (round(color[0] * lum), round(color[1] * lum), round(color[2] * lum), a)
    return out


def backdrop() -> Image.Image:
    img = Image.new("RGB", (W, H))
    px = img.load()
    bands = SKY + SEA
    for y in range(H):
        color = [c for top, c in bands if top <= y][-1]
        for x in range(W):
            px[x, y] = color
    # 물결 점선: 행마다 간격·위치를 엇갈리게 (게임 바다처럼)
    for i, y in enumerate(range(HORIZON + 6, H, 7)):
        period, dash = 18 + (i % 3) * 4, 4 + (i % 2) * 2
        for x0 in range((i * 7) % period - period, W, period):
            for x in range(max(0, x0), min(W, x0 + dash)):
                px[x, y] = WAVE
    return img


def cloud(img: Image.Image, x: int, y: int, w: int) -> None:
    """층층이 쌓인 도트 구름 (아래 한 줄은 그늘)."""
    px = img.load()
    rows = [(w // 4, w // 2), (w // 8, w * 7 // 8), (0, w), (w // 16, w * 15 // 16)]
    for dy, (a, b) in enumerate(rows):
        for dx in range(a, b):
            if 0 <= x + dx < W and 0 <= y + dy < H:
                px[x + dx, y + dy] = CLOUD_SHADE if dy == len(rows) - 1 else CLOUD


def paste(canvas: Image.Image, sprite: Image.Image, x: int, y: int) -> None:
    canvas.paste(sprite, (x, y), sprite)


def build() -> Image.Image:
    sheets, colors = _fx_sheets()

    def fx(name: str, index: int) -> Image.Image:
        s = sheets[name]
        return tint(frame(ASSETS / "fx" / f"{name}.png", s["w"], s["h"], index), colors[name])

    def enemy(kind: str, index: int = 0) -> Image.Image:
        sheet = Image.open(ASSETS / "enemies" / f"{kind}.png").convert("RGBA")
        w = sheet.width // 2  # enemyFrames 2
        return sheet.crop((index * w, 0, index * w + w, sheet.height))

    img = backdrop()
    for x, y, w in [(22, 8, 30), (118, 18, 22), (196, 6, 36)]:
        cloud(img, x, y, w)
    canvas = img.convert("RGBA")

    # 하늘: 갈매기
    for x, y, i in [(150, 26, 0), (172, 20, 1), (232, 30, 0)]:
        paste(canvas, enemy("gull", i), x, y)

    # 해역 보스(대왕 소라게)가 무리 뒤에서
    paste(canvas, Image.open(ASSETS / "bosses" / "giant_hermit.png").convert("RGBA"), 186, 40)

    # 무리 (뒤 → 앞, y가 클수록 앞)
    crowd = [
        ("jelly", 150, 66, 0), ("crab", 170, 70, 1), ("piranha", 212, 68, 0), ("puffer", 236, 72, 1),
        ("urchin", 140, 76, 1), ("crab", 196, 80, 0), ("jelly", 224, 84, 1), ("piranha", 160, 86, 1),
        ("crab", 236, 92, 0), ("puffer", 182, 94, 0), ("urchin", 208, 98, 0), ("crab", 150, 100, 1),
    ]
    for kind, x, y, i in crowd:
        paste(canvas, enemy(kind, i), x, y)

    # 주인공: 앱 아이콘의 배(54×54) — 물 위에 띄운다
    paste(canvas, Image.open(ICON / "foreground.png").convert("RGBA"), 10, 30)

    # 포격: 포구 불꽃(작은 첫 프레임), 연기 꼬리를 단 포탄 셋(포물선), 범위 폭발(고리·파편), 타격 불꽃, 코인 분수(코인 스프라이트 호)
    paste(canvas, fx("muzzle", 0), 48, 54)
    ball = Image.open(ASSETS / "projectiles" / "cannonball.png").convert("RGBA")
    smoke = canvas.load()
    for x, y in [(88, 46), (108, 41), (128, 43)]:
        for k in range(1, 4):  # 뒤쪽으로 옅어지는 연기 점
            sx, sy = x - k * 4, y + (2 if x < 100 else 1) * k // 2 + 1
            smoke[sx, sy] = (232, 240, 246, 255 - k * 50)
        paste(canvas, ball, x, y)
    paste(canvas, fx("explosion_aoe", 4), 146, 54)
    for x, y, i in [(196, 70, 1), (226, 80, 2), (174, 88, 1)]:
        paste(canvas, fx("hit_spark", i), x, y)
    coins = Image.open(ASSETS / "coin.png").convert("RGBA")
    for x, y, i in [(150, 50, 0), (158, 42, 1), (170, 38, 2), (182, 40, 0), (192, 47, 1)]:
        paste(canvas, coins.crop((i * 4, 0, i * 4 + 4, 4)), x, y)

    flat = Image.new("RGB", canvas.size)
    flat.paste(canvas, mask=canvas.getchannel("A"))
    return flat.resize((W * SCALE, H * SCALE), Image.Resampling.NEAREST)


def main() -> int:
    img = build()
    OUT.parent.mkdir(parents=True, exist_ok=True)
    img.save(OUT, format="PNG")
    print(f"{OUT} {img.size[0]}×{img.size[1]} {img.mode}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
