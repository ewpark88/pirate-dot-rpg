"""import_pack.py 테스트 (수용 기준 1·3). 실행: python -I tools/art/test_import_pack.py

진짜 팩 대신 크기만 맞춘 작은 PNG로 zip을 만들어 돌린다.
"""

import importlib.util
import json
import struct
import tempfile
import unittest
import zipfile
import zlib
from pathlib import Path

_spec = importlib.util.spec_from_file_location("import_pack", Path(__file__).with_name("import_pack.py"))
ip = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(ip)


def png(w: int, h: int, shade: int = 0) -> bytes:
    def chunk(kind: bytes, data: bytes) -> bytes:
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)

    raw = b"".join(b"\x00" + bytes([shade]) * w for _ in range(h))
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 0, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(raw)) + chunk(b"IEND", b"")


def fake_packs(tmp: Path, bad_portrait: bool = False) -> tuple[Path, Path]:
    dot, battle = tmp / "dot.zip", tmp / "battle.zip"
    with zipfile.ZipFile(dot, "w") as z:
        for crew in ip.load_json("crews.json")["crews"]:
            z.writestr(f"characters/{crew['id']}.png", png(31 if bad_portrait else 32, 32))
        for s in ip.load_json("fx_map.json")["fxSheets"]:
            z.writestr(f"fx/{s['id']}.png", png(s["w"] * s["frames"], s["h"]))
    with zipfile.ZipFile(battle, "w") as z:
        for sprite in ip.ENEMY_SPRITES:
            z.writestr(f"sprites/{sprite}.png", png(32, 12))
        for name in ["enemy_ship", "ship_t1", *ip.PROJECTILES]:
            z.writestr(f"sprites/{name}.png", png(8, 8))
        z.writestr("sprites/coin.png", png(12, 4))
    return dot, battle


class ImportPackTest(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.tmp = Path(self._tmp.name)
        self.assets = self.tmp / "assets"
        self.assets.mkdir()
        (self.assets / "LICENSES.json").write_text('{"files": {}}', encoding="utf-8")
        self._overrides = ip.OVERRIDES
        ip.OVERRIDES = self.tmp / "overrides"

    def tearDown(self):
        ip.OVERRIDES = self._overrides
        self._tmp.cleanup()

    def test_two_runs_same_result_and_all_licensed(self):
        dot, battle = fake_packs(self.tmp)
        first = ip.run(dot, battle, self.assets, check=False)
        self.assertIn("crews/octo.png", first)
        self.assertEqual(ip.run(dot, battle, self.assets, check=True), [])
        lic = json.loads((self.assets / "LICENSES.json").read_text(encoding="utf-8"))["files"]
        files = [p.relative_to(self.assets).as_posix() for p in self.assets.rglob("*.png")]
        self.assertEqual(sorted(files), sorted(lic))
        self.assertTrue(all(v["license"] == "OWN" for v in lic.values()))

    def test_override_wins(self):
        dot, battle = fake_packs(self.tmp)
        (ip.OVERRIDES / "crews").mkdir(parents=True)
        special = png(32, 32, shade=200)
        (ip.OVERRIDES / "crews" / "octo.png").write_bytes(special)
        ip.run(dot, battle, self.assets, check=False)
        self.assertEqual((self.assets / "crews" / "octo.png").read_bytes(), special)
        lic = json.loads((self.assets / "LICENSES.json").read_text(encoding="utf-8"))["files"]
        self.assertIn("overrides", lic["crews/octo.png"]["source"])

    def test_wrong_size_fails(self):
        dot, battle = fake_packs(self.tmp, bad_portrait=True)
        with self.assertRaises(ip.PackError):
            ip.run(dot, battle, self.assets, check=False)


if __name__ == "__main__":
    unittest.main()
