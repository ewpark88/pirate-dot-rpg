"""도트 아이콘·스플래시를 Android res/ 에 넣는다 (docs/store/icon.md 4절 3단계).

원본 격자 PNG를 밀도별 **정수 배율·최근접**으로 키워 넣고, 적응형 아이콘 XML·색·스플래시 테마를 쓴다.
보통 아이콘 생성기는 부드럽게 리샘플해서 도트가 뭉갠다 — 그래서 이 스크립트를 쓴다.

    python -I apps/game/android/icon/apply_icons.py --src <원본 폴더> --bg "#1B3A5C"
    python -I apps/game/android/icon/apply_icons.py --src <원본 폴더> --bg "#1B3A5C" --dry-run   # 검사만

원본 폴더 (파일 이름 고정, 없어도 되는 것은 [선택]):
    foreground.png  54×54  적응형 전경. 중요한 그림은 가운데 지름 33px 원 안
    background.png  54×54  [선택] 적응형 배경. 없으면 --bg 단색
    monochrome.png  54×54  [선택] Android 13 테마 아이콘. 한 가지 색 + 투명
    legacy.png      24×24  Android 7.x 예전 아이콘
    splash.png      48×48  [선택] Android 11 이하 스플래시 로고. 없으면 배경색만
    store.png       64×64  [선택] 스토어 512×512 (--store-out 에 쓴다, 앱에 안 들어감)

Pillow 필요. 같은 입력이면 같은 결과(다시 굽기 가능).
"""

from __future__ import annotations

import argparse
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path

from PIL import Image

HERE = Path(__file__).resolve().parent
RES = HERE.parent / "app" / "src" / "main" / "res"
ROOT = HERE.parents[2]
STORE_OUT = ROOT / "build" / "store" / "icon-512.png"

# 밀도 → 배율. 108dp 적응형 = 54px 격자 ×2(mdpi)…×8(xxxhdpi), 48dp 예전 = 24px 격자, 스플래시 48px 격자.
DENSITIES = {"mdpi": 2, "hdpi": 3, "xhdpi": 4, "xxhdpi": 6, "xxxhdpi": 8}
SIZES = {
    "foreground": 54,
    "background": 54,
    "monochrome": 54,
    "legacy": 24,
    "splash": 48,
    "store": 64,
}
REQUIRED = ("foreground", "legacy")
SAFE_RADIUS = 16.5  # 66dp / 108dp × 54px / 2
COLOR = re.compile(r"^#[0-9A-Fa-f]{6}$")

ADAPTIVE_XML = """<?xml version="1.0" encoding="utf-8"?>
<!-- apply_icons.py 가 만든 파일. 고치려면 원본 그림을 바꾸고 다시 돌린다. -->
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="{background}" />
    <foreground android:drawable="@mipmap/ic_launcher_foreground" />
{monochrome}</adaptive-icon>
"""

COLORS_XML = """<?xml version="1.0" encoding="utf-8"?>
<!-- apply_icons.py 가 만든 파일. -->
<resources>
    <color name="ic_launcher_background">{bg}</color>
    <color name="splash_background">{splash}</color>
</resources>
"""

LAUNCH_XML = """<?xml version="1.0" encoding="utf-8"?>
<!-- apply_icons.py 가 만든 파일. Android 11 이하 스플래시. filter=false = 최근접 확대(도트가 안 흐려진다). -->
<layer-list xmlns:android="http://schemas.android.com/apk/res/android">
    <item android:drawable="@color/splash_background" />
{logo}</layer-list>
"""

LOGO_ITEM = """    <item>
        <bitmap android:gravity="center" android:src="@drawable/splash_logo" android:filter="false" />
    </item>
"""

# Android 12+ 시스템 스플래시: 가운데는 런처 아이콘 전경(자동), 배경색만 정한다. NormalTheme은 values/ 것을 그대로 쓴다.
STYLES_V31 = """<?xml version="1.0" encoding="utf-8"?>
<!-- apply_icons.py 가 만든 파일. Android 12+ 시스템 스플래시 배경색. -->
<resources>
    <style name="LaunchTheme" parent="@android:style/Theme.{base}.NoTitleBar">
        <item name="android:windowBackground">@drawable/launch_background</item>
        <item name="android:windowSplashScreenBackground">@color/splash_background</item>
    </style>
</resources>
"""


@dataclass
class Plan:
    """쓸 파일(경로 → 바이트 또는 이미지)과 경고·오류."""

    images: dict[Path, Image.Image] = field(default_factory=dict)
    texts: dict[Path, str] = field(default_factory=dict)
    warnings: list[str] = field(default_factory=list)
    errors: list[str] = field(default_factory=list)


def _scale(img: Image.Image, k: int) -> Image.Image:
    return img.resize((img.width * k, img.height * k), Image.Resampling.NEAREST)


def _outside_safe_zone(img: Image.Image) -> int:
    """가운데 지름 33px 원 밖의 불투명 픽셀 수 (기기에 따라 잘릴 수 있다)."""
    c = (img.width - 1) / 2
    alpha = img.getchannel("A")
    n = 0
    for y in range(img.height):
        for x in range(img.width):
            if alpha.getpixel((x, y)) > 0 and (x - c) ** 2 + (y - c) ** 2 > SAFE_RADIUS**2:
                n += 1
    return n


def _opaque_colors(img: Image.Image) -> set[tuple[int, int, int]]:
    return {p[:3] for p in img.getdata() if p[3] > 0}


def load_sources(src: Path, plan: Plan) -> dict[str, Image.Image]:
    out: dict[str, Image.Image] = {}
    for name, size in SIZES.items():
        f = src / f"{name}.png"
        if not f.exists():
            if name in REQUIRED:
                plan.errors.append(f"{f.name}: 없음 (필수)")
            continue
        img = Image.open(f).convert("RGBA")
        if img.size != (size, size):
            plan.errors.append(f"{f.name}: {img.width}×{img.height} — {size}×{size} 격자여야 한다")
            continue
        out[name] = img
    return out


def build(src: Path, res: Path, bg: str, splash_bg: str, store_out: Path) -> Plan:
    plan = Plan()
    for label, c in (("--bg", bg), ("--splash-bg", splash_bg)):
        if not COLOR.match(c):
            plan.errors.append(f"{label} {c!r}: #RRGGBB 형식이어야 한다")
    imgs = load_sources(src, plan)
    if plan.errors:
        return plan

    fg = imgs["foreground"]
    if (n := _outside_safe_zone(fg)) > 0:
        plan.warnings.append(f"foreground.png: 안전 원(지름 33px) 밖에 불투명 픽셀 {n}개 — 원형 런처에서 잘릴 수 있다")
    if "monochrome" in imgs and len(_opaque_colors(imgs["monochrome"])) > 1:
        plan.errors.append("monochrome.png: 불투명 색이 2가지 이상 — 한 가지 색 + 투명이어야 한다")
        return plan
    if any(p[3] < 255 for p in imgs["legacy"].getdata()):
        plan.warnings.append("legacy.png: 투명 픽셀이 있다 — 예전 런처는 그대로 비쳐 보인다(의도면 무시)")

    for d, k in DENSITIES.items():
        mip = res / f"mipmap-{d}"
        plan.images[mip / "ic_launcher_foreground.png"] = _scale(fg, k)
        plan.images[mip / "ic_launcher.png"] = _scale(imgs["legacy"], k)
        if "background" in imgs:
            plan.images[mip / "ic_launcher_background.png"] = _scale(imgs["background"], k)
        if "monochrome" in imgs:
            plan.images[mip / "ic_launcher_monochrome.png"] = _scale(imgs["monochrome"], k)
        if "splash" in imgs:
            plan.images[res / f"drawable-{d}" / "splash_logo.png"] = _scale(imgs["splash"], k)

    background = "@mipmap/ic_launcher_background" if "background" in imgs else "@color/ic_launcher_background"
    mono = (
        '    <monochrome android:drawable="@mipmap/ic_launcher_monochrome" />\n' if "monochrome" in imgs else ""
    )
    plan.texts[res / "mipmap-anydpi-v26" / "ic_launcher.xml"] = ADAPTIVE_XML.format(
        background=background, monochrome=mono
    )
    plan.texts[res / "values" / "colors.xml"] = COLORS_XML.format(bg=bg.upper(), splash=splash_bg.upper())
    launch = LAUNCH_XML.format(logo=LOGO_ITEM if "splash" in imgs else "")
    plan.texts[res / "drawable" / "launch_background.xml"] = launch
    plan.texts[res / "drawable-v21" / "launch_background.xml"] = launch
    plan.texts[res / "values-v31" / "styles.xml"] = STYLES_V31.format(base="Light")
    plan.texts[res / "values-night-v31" / "styles.xml"] = STYLES_V31.format(base="Black")
    if "store" in imgs:
        plan.images[store_out] = _scale(imgs["store"], 8)
    return plan


def write(plan: Plan) -> None:
    for path, img in plan.images.items():
        path.parent.mkdir(parents=True, exist_ok=True)
        img.save(path, format="PNG")
    for path, text in plan.texts.items():
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8", newline="\n")


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--src", type=Path, required=True, help="원본 격자 PNG 폴더")
    ap.add_argument("--bg", required=True, help="적응형 배경 단색(#RRGGBB). background.png가 있어도 colors.xml에 쓴다")
    ap.add_argument("--splash-bg", help="스플래시 배경색(#RRGGBB). 기본 = --bg. 게임 첫 화면 색과 같게")
    ap.add_argument("--res", type=Path, default=RES, help="Android res 폴더 (테스트용)")
    ap.add_argument("--store-out", type=Path, default=STORE_OUT, help="스토어 512px 아이콘 출력 경로")
    ap.add_argument("--dry-run", action="store_true", help="검사하고 쓸 파일 목록만 출력")
    a = ap.parse_args(argv)

    plan = build(a.src, a.res, a.bg, a.splash_bg or a.bg, a.store_out)
    for w in plan.warnings:
        print(f"경고: {w}")
    if plan.errors:
        for e in plan.errors:
            print(f"오류: {e}", file=sys.stderr)
        return 1
    for p in sorted([*plan.images, *plan.texts]):
        print(("(쓰기 예정) " if a.dry_run else "") + str(p))
    if not a.dry_run:
        write(plan)
        print(f"완료: 이미지 {len(plan.images)}개, XML {len(plan.texts)}개. 다음: flutter build apk --debug → 실기기 확인(icon.md 4절)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
