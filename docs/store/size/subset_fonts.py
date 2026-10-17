"""폰트 서브셋(docs/store/app-size.md 2절): 게임이 쓰는 글자 + 한국어 일상 글자(KS X 1001 완성형 2,350자) + 라틴 확장만 남긴다.

    python -I -B docs/store/size/subset_fonts.py --src <원본 폴더> --out apps/game/assets/fonts    # 서브셋 만들기(S3 — 에셋 담당)
    python -I -B docs/store/size/subset_fonts.py --check                                           # 지금 번들 폰트가 쓰는 글자를 다 덮나

'쓰는 글자' = apps/game/lib/l10n/merged/*.arb 값 + packages/game_data/tables/*.json + apps/game/lib/**/*.dart(그리는 기호 문자열).
--check는 새 문구가 서브셋 밖 글자를 쓰면 종료 1과 그 글자 목록 — 그때 원본에서 다시 서브셋한다(원본은 S3가 tools/art/fonts_src/에 보관).
도구: fontTools(무료, `pip install fonttools`). 종료 코드: 0 통과 · 1 빠진 글자 있음.
"""

from __future__ import annotations

import argparse
import glob
import json
import subprocess
import sys
from pathlib import Path

sys.dont_write_bytecode = True
sys.stdout.reconfigure(encoding="utf-8")
ROOT = Path(__file__).resolve().parents[3]
FONTS = ("Galmuri11.ttf", "Galmuri11-Bold.ttf", "Jua-Regular.ttf")


def used_chars(root: Path = ROOT) -> set[str]:
    chars = {chr(c) for c in range(0x20, 0x7F)}
    for f in glob.glob(str(root / "apps/game/lib/l10n/merged/*.arb")):
        for k, v in json.loads(Path(f).read_text(encoding="utf-8")).items():
            if not k.startswith("@") and isinstance(v, str):
                chars.update(v)
    for pattern in ("packages/game_data/tables/*.json", "apps/game/lib/**/*.dart"):
        for f in glob.glob(str(root / pattern), recursive=True):
            chars.update(Path(f).read_text(encoding="utf-8"))
    return {c for c in chars if c.isprintable() or c == " "}


def common_korean() -> set[str]:
    """KS X 1001 완성형 한글 2,350자(EUC-KR 0xB0A1~0xC8FE) — 앞으로 들어올 흔한 글자 여유."""
    out = set()
    for hi in range(0xB0, 0xC9):
        for lo in range(0xA1, 0xFF):
            try:
                out.add(bytes([hi, lo]).decode("euc-kr"))
            except UnicodeDecodeError:
                pass
    return out


def keep_set(root: Path = ROOT) -> set[str]:
    return used_chars(root) | common_korean() | {chr(c) for c in range(0xA0, 0x180)}


def missing(font: Path, chars: set[str]) -> list[str]:
    from fontTools.ttLib import TTFont

    cmap = TTFont(str(font)).getBestCmap()
    return sorted(c for c in chars if ord(c) not in cmap and not c.isspace() and not _emoji(c))


def _emoji(c: str) -> bool:
    """기호·이모지(⚓⚔⚡ 등) — 원본 글꼴에도 없고 시스템 이모지 글꼴이 그린다."""
    o = ord(c)
    return 0x2600 <= o <= 0x27BF or 0x2B00 <= o <= 0x2BFF or o >= 0x1F000 or 0xFE00 <= o <= 0xFE0F


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--src", type=Path, help="원본 폰트 폴더")
    ap.add_argument("--out", type=Path, default=ROOT / "apps/game/assets/fonts")
    ap.add_argument("--check", action="store_true")
    a = ap.parse_args(argv)
    if a.check:
        used = used_chars()
        bad = {name: missing(a.out / name, used) for name in FONTS[:1]}  # 본문 글꼴(Galmuri11)이 다 덮어야 한다
        holes = [c for cs in bad.values() for c in cs]
        if holes:
            print(f"서브셋 밖 글자 {len(holes)}개: {''.join(holes[:80])}")
            return 1
        print(f"쓰는 글자 {len(used)}개 모두 있음")
        return 0
    if a.src is None:
        ap.error("--src(원본 폴더) 또는 --check")
    text = a.out.parent / "_subset_chars.txt"
    text.write_text("".join(sorted(keep_set())), encoding="utf-8")
    try:
        for name in FONTS:
            subprocess.run(
                [sys.executable, "-m", "fontTools.subset", str(a.src / name), f"--text-file={text}",
                 f"--output-file={a.out / name}", "--layout-features=*"],  # 힌팅은 남긴다 — 글자 래스터(골든) 그대로
                check=True,
            )
            print(f"{name}: {(a.src / name).stat().st_size // 1024}KB → {(a.out / name).stat().st_size // 1024}KB")
    finally:
        text.unlink(missing_ok=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
