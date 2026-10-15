"""Pirate Busters(같은 자체 IP) 선원 그림·카드 테두리 가져오기 (스펙 docs/specs/render-art-crew-illust.md, 사용자 결정 2026-10-15).

    python -I tools/art/import_pb.py                 # apps/game/assets/crew_art/ · assets/ui/cards/ 에 쓴다
    python -I tools/art/import_pb.py --check         # 쓰지 않고, 결과가 지금 파일과 다르면 실패
    python -I tools/art/import_pb.py --src <pb art 폴더>   # 기본 D:/Projects/pirate-busters/art/pb_v0.24_main

- 선원 40명(crews.json id = PB 캐릭터 id, 우리 편 'blue'):
  crew_art/<id>_card.webp      카드 그림 창용 (PB png/characters/<id>/<id>_blue_card@2x.png, 355×480)
  crew_art/<id>_portrait.webp  얼굴 초상 (PB png/ui/portraits/<id>_blue@2x.png)
- 카드 테두리: ui/cards/card_<등급>_{back,front}.webp 5등급 + card_legend_rays · card_shine · card_sparkle, cards.json(그림 창·리본 자리 규칙).
- 무손실 WebP(Pillow)로 용량만 줄인다(그림은 같다). 카드 1장 150KB 이하 검사.
- PB 스크립트는 실행하지 않는다(이미지·json만 읽는다). LICENSES OWN, 출처 PB 경로.
같은 입력·같은 Pillow면 같은 바이트.
"""

from __future__ import annotations

import argparse
import io
import json
import sys
from pathlib import Path

from PIL import Image

sys.dont_write_bytecode = True

ROOT = Path(__file__).resolve().parents[2]
ASSETS = ROOT / "apps" / "game" / "assets"
TABLES = ROOT / "packages" / "game_data" / "tables"
DEFAULT_SRC = Path("D:/Projects/pirate-busters/art/pb_v0.24_main")
CREDIT = "Pirate Busters 자체 IP"
RARITIES = ["common", "rare", "hero", "legend", "mythic"]
MAX_BYTES = 150 * 1024
CARD_SIZE = (355, 480)
FRAME_SIZE = (504, 716)


class ImportError_(Exception):
    pass


def webp(src: Path, want: tuple[int, int] | None) -> bytes:
    im = Image.open(src)
    im.load()
    if want is not None and im.size != want:
        raise ImportError_(f"{src}: 크기 {im.size}, 기대 {want}")
    im = im.convert("RGBA")
    buf = io.BytesIO()
    im.save(buf, "WEBP", lossless=True, method=6, exact=True)
    data = buf.getvalue()
    if len(data) > MAX_BYTES:
        raise ImportError_(f"{src}: {len(data) // 1024}KB > 150KB")
    return data


def plan(src: Path) -> dict[str, tuple[bytes, str]]:
    out: dict[str, tuple[bytes, str]] = {}

    def take(rel: str, dest: str, want=None, raw=False):
        p = src / rel
        if not p.is_file():
            raise ImportError_(f"{p} 없음")
        data = p.read_bytes() if raw else webp(p, want)
        out[dest] = (data, f"{CREDIT} → art/pb_v0.24_main/{rel}")

    crews = json.loads((TABLES / "crews.json").read_text(encoding="utf-8"))["crews"]
    for c in crews:
        cid = c["id"]
        take(f"png/characters/{cid}/{cid}_blue_card@2x.png", f"crew_art/{cid}_card.webp", CARD_SIZE)
        take(f"png/ui/portraits/{cid}_blue@2x.png", f"crew_art/{cid}_portrait.webp")
    for r in RARITIES:
        for side in ("back", "front"):
            take(f"png/ui/cards/card_{r}_{side}@2x.png", f"ui/cards/card_{r}_{side}.webp", FRAME_SIZE)
    take("png/ui/cards/card_legend_rays@2x.png", "ui/cards/card_legend_rays.webp", FRAME_SIZE)
    take("png/ui/cards/card_shine@2x.png", "ui/cards/card_shine.webp")
    take("png/ui/cards/card_sparkle@2x.png", "ui/cards/card_sparkle.webp")
    take("ui/cards/cards.json", "ui/cards/cards.json", raw=True)
    return out


def main(argv: list[str]) -> int:
    for stream in (sys.stdout, sys.stderr):
        stream.reconfigure(encoding="utf-8")
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", type=Path, default=DEFAULT_SRC)
    ap.add_argument("--check", action="store_true")
    a = ap.parse_args(argv)
    try:
        files = plan(a.src)
    except ImportError_ as e:
        print(f"✗ {e}", file=sys.stderr)
        return 2
    lic_path = ASSETS / "LICENSES.json"
    lic = json.loads(lic_path.read_text(encoding="utf-8"))
    merged = dict(lic.get("files", {}))
    for dest, (_, source) in files.items():
        merged[dest] = {"source": source, "license": "OWN"}
    lic_text = json.dumps({**lic, "files": dict(sorted(merged.items()))}, ensure_ascii=False, indent=2) + "\n"
    changed = []
    for dest, (data, _) in sorted(files.items()):
        target = ASSETS / dest
        if target.is_file() and target.read_bytes() == data:
            continue
        changed.append(dest)
        if not a.check:
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(data)
    if lic_path.read_text(encoding="utf-8") != lic_text:
        changed.append("LICENSES.json")
        if not a.check:
            lic_path.write_text(lic_text, encoding="utf-8", newline="\n")
    total = sum(len(d) for d, _ in files.values())
    if a.check:
        if changed:
            print("✗ 다시 가져오기 결과가 다름: " + ", ".join(changed[:8]) + (" …" if len(changed) > 8 else ""), file=sys.stderr)
            return 1
        print(f"✓ PB 그림이 원본과 같다 ({len(files)}개, {total // 1024}KB)")
        return 0
    print(f"✓ {len(changed)}개 갱신 · 전체 {len(files)}개 {total // 1024}KB")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
