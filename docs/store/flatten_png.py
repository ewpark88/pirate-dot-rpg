"""Play 업로드용으로 PNG를 24비트(알파 없음)로 바꾼다 — Play 스크린샷 규격 "JPEG or 24-bit PNG (no alpha)".

    python -I -B docs/store/flatten_png.py            # build/store/ 아래 모든 PNG (제자리)

Flutter의 toImage → PNG는 늘 RGBA라 스크린샷 도구 뒤에 한 번 돌린다. 이미 RGB면 건드리지 않는다.
"""

from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2] / "build" / "store"


def flatten(path: Path) -> bool:
    img = Image.open(path)
    if img.mode == "RGB":
        return False
    bg = Image.new("RGB", img.size, (0, 0, 0))
    rgba = img.convert("RGBA")
    bg.paste(rgba, mask=rgba.getchannel("A"))
    bg.save(path, format="PNG")
    return True


def main() -> int:
    for s in (sys.stdout, sys.stderr):
        if hasattr(s, "reconfigure"):
            s.reconfigure(encoding="utf-8")
    changed = [p for p in sorted(ROOT.rglob("*.png")) if flatten(p)]
    print(f"24비트로 바꿈 {len(changed)}개 (전체 {len(list(ROOT.rglob('*.png')))}개) — {ROOT}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
