"""apply_icons.py 테스트. python -I -B -m unittest discover -s apps/game/android/icon"""

from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path

from PIL import Image

sys.dont_write_bytecode = True  # 작업 트리에 __pycache__를 남기지 않는다
sys.path.insert(0, str(Path(__file__).resolve().parent))
import apply_icons  # noqa: E402


def _img(size: int, color=(200, 40, 40, 255), dot_at=None) -> Image.Image:
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0) if dot_at else color)
    if dot_at:
        img.putpixel(dot_at, color)
    return img


class ApplyIconsTest(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        base = Path(self._tmp.name)
        self.src, self.res, self.store = base / "src", base / "res", base / "store" / "icon-512.png"
        self.src.mkdir()

    def tearDown(self) -> None:
        self._tmp.cleanup()

    def _put(self, name: str, img: Image.Image) -> None:
        img.save(self.src / f"{name}.png")

    def _run(self, *extra: str) -> int:
        args = ["--src", str(self.src), "--res", str(self.res), "--store-out", str(self.store), "--bg", "#1b3a5c"]
        return apply_icons.main([*args, *extra])

    def _minimal(self) -> None:
        self._put("foreground", _img(54, dot_at=(27, 27)))
        self._put("legacy", _img(24))

    def test_nearest_integer_scale_per_density(self) -> None:
        self._minimal()
        self.assertEqual(self._run(), 0)
        for d, k in apply_icons.DENSITIES.items():
            fg = Image.open(self.res / f"mipmap-{d}" / "ic_launcher_foreground.png")
            self.assertEqual(fg.size, (54 * k, 54 * k))
            # 최근접: 한 도트가 k×k 블록 그대로, 경계에 중간색 없음
            colors = {p for p in fg.convert("RGBA").getdata()}
            self.assertEqual(colors, {(0, 0, 0, 0), (200, 40, 40, 255)})
            self.assertEqual(Image.open(self.res / f"mipmap-{d}" / "ic_launcher.png").size, (24 * k, 24 * k))

    def test_optional_layers_absent_use_color_and_no_logo(self) -> None:
        self._minimal()
        self.assertEqual(self._run(), 0)
        xml = (self.res / "mipmap-anydpi-v26" / "ic_launcher.xml").read_text(encoding="utf-8")
        self.assertIn("@color/ic_launcher_background", xml)
        self.assertNotIn("monochrome", xml)
        launch = (self.res / "drawable" / "launch_background.xml").read_text(encoding="utf-8")
        self.assertNotIn("splash_logo", launch)
        self.assertIn("#1B3A5C", (self.res / "values" / "colors.xml").read_text(encoding="utf-8"))
        self.assertFalse(self.store.exists())

    def test_all_layers(self) -> None:
        self._minimal()
        self._put("background", _img(54, (10, 20, 30, 255)))
        self._put("monochrome", _img(54, (255, 255, 255, 255), dot_at=(27, 27)))
        self._put("splash", _img(48))
        self._put("store", _img(64))
        self.assertEqual(self._run("--splash-bg", "#000000"), 0)
        xml = (self.res / "mipmap-anydpi-v26" / "ic_launcher.xml").read_text(encoding="utf-8")
        self.assertIn("@mipmap/ic_launcher_background", xml)
        self.assertIn("@mipmap/ic_launcher_monochrome", xml)
        self.assertEqual(Image.open(self.res / "drawable-xxxhdpi" / "splash_logo.png").size, (384, 384))
        launch = (self.res / "drawable-v21" / "launch_background.xml").read_text(encoding="utf-8")
        self.assertIn('android:filter="false"', launch)
        self.assertEqual(Image.open(self.store).size, (512, 512))
        self.assertIn("windowSplashScreenBackground", (self.res / "values-v31" / "styles.xml").read_text("utf-8"))
        self.assertIn("Theme.Black", (self.res / "values-night-v31" / "styles.xml").read_text("utf-8"))

    def test_wrong_size_fails_and_writes_nothing(self) -> None:
        self._put("foreground", _img(64))
        self._put("legacy", _img(24))
        self.assertEqual(self._run(), 1)
        self.assertFalse(self.res.exists())

    def test_missing_required_fails(self) -> None:
        self._put("foreground", _img(54, dot_at=(27, 27)))
        self.assertEqual(self._run(), 1)

    def test_bad_color_fails(self) -> None:
        self._minimal()
        self.assertEqual(self._run("--splash-bg", "blue"), 1)

    def test_multicolor_monochrome_fails(self) -> None:
        self._minimal()
        mono = _img(54, dot_at=(27, 27))
        mono.putpixel((26, 27), (0, 255, 0, 255))
        self._put("monochrome", mono)
        self.assertEqual(self._run(), 1)

    def test_outside_safe_zone_warns_only(self) -> None:
        self._put("foreground", _img(54, dot_at=(0, 0)))
        self._put("legacy", _img(24))
        plan = apply_icons.build(self.src, self.res, "#000000", "#000000", self.store)
        self.assertFalse(plan.errors)
        self.assertTrue(any("안전 원" in w for w in plan.warnings))

    def test_dry_run_writes_nothing(self) -> None:
        self._minimal()
        self.assertEqual(self._run("--dry-run"), 0)
        self.assertFalse(self.res.exists())

    def test_same_input_same_bytes(self) -> None:
        self._minimal()
        self._run()
        f = self.res / "mipmap-xhdpi" / "ic_launcher_foreground.png"
        first = f.read_bytes()
        self._run()
        self.assertEqual(f.read_bytes(), first)


if __name__ == "__main__":
    unittest.main()
