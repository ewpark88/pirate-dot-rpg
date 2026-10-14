"""아트 팩 v0.2 가져오기 (docs/specs/render-art-pack-v02.md 규칙 1~3).

원본 팩 zip 두 개에서 이미지·json만 읽어 apps/game/assets/ 에 복사하고, 크기를 검증하고,
apps/game/assets/LICENSES.json 을 갱신한다. zip 안의 스크립트는 실행하지 않는다.
tools/art/overrides/<같은 경로> 가 있으면 그 파일을 쓴다(수작업 보정본 우선).

    python -I tools/art/import_pack.py --dot <pirate_dot_v0.2_32px.zip> --battle <pirate_battle_v0.3.zip>
    python -I tools/art/import_pack.py ... --check     # 쓰지 않고, 결과가 지금 파일과 다르면 실패

외부 라이브러리 없이 PNG 헤더(IHDR)로 크기를 읽는다. 같은 입력이면 결과 바이트가 같다(다시 굽기 가능).
"""

from __future__ import annotations

import argparse
import json
import struct
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TABLES = ROOT / "packages" / "game_data" / "tables"
ASSETS = ROOT / "apps" / "game" / "assets"
OVERRIDES = Path(__file__).resolve().parent / "overrides"

LICENSE = "OWN"
CREDIT = "Pirate Busters v0.24 자체 IP"

# 전투 v0.3 sprites/ → assets 경로. 적은 가로 2프레임 시트.
ENEMY_SPRITES = {"crab": "crab", "jelly": "jelly", "fish": "piranha", "puffer": "puffer", "urchin": "urchin", "gull": "gull"}
PROJECTILES = ["cannonball", "bullet", "harpoon", "stone", "torpedo"]
ENEMY_FRAMES = 2
ENEMY_MAX_FRAME_PX = 17  # 팩 규격: 적 9~17px
COIN_FRAMES = 3
PORTRAIT_PX = 32


class PackError(Exception):
    pass


def png_size(data: bytes, where: str) -> tuple[int, int]:
    if data[:8] != b"\x89PNG\r\n\x1a\n" or data[12:16] != b"IHDR":
        raise PackError(f"{where}: PNG가 아님")
    return struct.unpack(">II", data[16:24])


def load_json(name: str):
    return json.loads((TABLES / name).read_text(encoding="utf-8"))


def plan(dot: zipfile.ZipFile, battle: zipfile.ZipFile) -> dict[str, tuple[bytes, str]]:
    """assets 아래 경로 → (바이트, 출처 설명). 크기 검증까지."""
    out: dict[str, tuple[bytes, str]] = {}
    dot_name = Path(dot.filename or "dot.zip").name
    battle_name = Path(battle.filename or "battle.zip").name

    def take(zf: zipfile.ZipFile, zname: str, inner: str, dest: str) -> bytes:
        try:
            data = zf.read(inner)
        except KeyError as e:
            raise PackError(f"{zname}에 {inner} 없음") from e
        out[dest] = (data, f"{CREDIT} → {zname}:{inner}")
        return data

    for crew in load_json("crews.json")["crews"]:
        dest = crew["portrait"]
        data = take(dot, dot_name, f"characters/{crew['id']}.png", dest)
        if png_size(data, dest) != (PORTRAIT_PX, PORTRAIT_PX):
            raise PackError(f"{dest}: 초상은 {PORTRAIT_PX}×{PORTRAIT_PX}이어야 함 ({png_size(data, dest)})")

    for sheet in load_json("fx_map.json")["fxSheets"]:
        dest = f"fx/{sheet['id']}.png"
        data = take(dot, dot_name, f"fx/{sheet['id']}.png", dest)
        want = (sheet["w"] * sheet["frames"], sheet["h"])
        if png_size(data, dest) != want:
            raise PackError(f"{dest}: fx_map 크기 {want}와 다름 ({png_size(data, dest)})")

    kinds = {e["id"] for e in load_json("regions.json")["enemies"]}
    for sprite, kind in ENEMY_SPRITES.items():
        if kind not in kinds:
            continue
        dest = f"enemies/{kind}.png"
        data = take(battle, battle_name, f"sprites/{sprite}.png", dest)
        w, h = png_size(data, dest)
        if w % ENEMY_FRAMES or w // ENEMY_FRAMES > ENEMY_MAX_FRAME_PX or h > ENEMY_MAX_FRAME_PX:
            raise PackError(f"{dest}: 적은 가로 {ENEMY_FRAMES}프레임, 한 장 {ENEMY_MAX_FRAME_PX}px 이하 ({w}×{h})")

    take(battle, battle_name, "sprites/enemy_ship.png", "bosses/enemy_ship.png")
    take(battle, battle_name, "sprites/ship_t1.png", "ship/ship_t1.png")
    for name in PROJECTILES:
        take(battle, battle_name, f"sprites/{name}.png", f"projectiles/{name}.png")
    coin = take(battle, battle_name, "sprites/coin.png", "coin.png")
    cw, ch = png_size(coin, "coin.png")
    if cw != ch * COIN_FRAMES:
        raise PackError(f"coin.png: 정사각 {COIN_FRAMES}프레임이어야 함 ({cw}×{ch})")

    # 수작업 보정본이 있으면 그것을 쓴다(크기 규칙은 같다고 본다).
    for dest in list(out):
        override = OVERRIDES / dest
        if override.is_file():
            data = override.read_bytes()
            png_size(data, f"overrides/{dest}")
            out[dest] = (data, f"{CREDIT} 수작업 보정 → tools/art/overrides/{dest}")
    return out


def licenses_text(current: dict, files: dict[str, tuple[bytes, str]]) -> str:
    merged = dict(current.get("files", {}))
    for dest, (_, source) in files.items():
        merged[dest] = {"source": source, "license": LICENSE}
    body = {**current, "files": dict(sorted(merged.items()))}
    return json.dumps(body, ensure_ascii=False, indent=2) + "\n"


def run(dot_path: Path, battle_path: Path, assets: Path, check: bool) -> list[str]:
    """바뀌는(또는 --check에서 다른) 경로 목록을 돌려준다."""
    with zipfile.ZipFile(dot_path) as dot, zipfile.ZipFile(battle_path) as battle:
        files = plan(dot, battle)
    lic_path = assets / "LICENSES.json"
    current = json.loads(lic_path.read_text(encoding="utf-8")) if lic_path.is_file() else {"files": {}}
    writes = {dest: data for dest, (data, _) in files.items()}
    writes["LICENSES.json"] = licenses_text(current, files).encode("utf-8")
    changed = []
    for dest, data in sorted(writes.items()):
        target = assets / dest
        if target.is_file() and target.read_bytes() == data:
            continue
        changed.append(dest)
        if not check:
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(data)
    return changed


def main(argv: list[str]) -> int:
    for stream in (sys.stdout, sys.stderr):
        stream.reconfigure(encoding="utf-8")  # Windows 콘솔(cp949)에서도 ✓·한글 출력
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--dot", type=Path, required=True, help="pirate_dot_v0.2_32px.zip")
    ap.add_argument("--battle", type=Path, required=True, help="pirate_battle_v0.3.zip")
    ap.add_argument("--assets", type=Path, default=ASSETS)
    ap.add_argument("--check", action="store_true", help="쓰지 않고 차이만 확인")
    a = ap.parse_args(argv)
    try:
        changed = run(a.dot, a.battle, a.assets, a.check)
    except PackError as e:
        print(f"✗ {e}", file=sys.stderr)
        return 2
    if a.check:
        if changed:
            print("✗ 다시 굽기 결과가 다름: " + ", ".join(changed), file=sys.stderr)
            return 1
        print("✓ 에셋이 팩과 같다")
        return 0
    print(f"✓ {len(changed)}개 갱신" + (": " + ", ".join(changed) if changed else ""))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
