"""device_loop.py 테스트 (기기 없이). python -I -B -m unittest discover -s docs/store/device"""

from __future__ import annotations

import sys
import unittest
from pathlib import Path

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parent))
import device_loop as dl  # noqa: E402


class FocusTest(unittest.TestCase):
    def test_our_app(self):
        w = "  mCurrentFocus=Window{1a2b u0 repo.dot.pirate/repo.dot.pirate.MainActivity}\n"
        self.assertEqual(dl.focused_package(w), "repo.dot.pirate")

    def test_other_app_is_not_ours(self):
        w = "  mCurrentFocus=Window{9f u0 com.example.other/com.example.other.Main}\n"
        self.assertNotEqual(dl.focused_package(w), dl.PACKAGE)

    def test_no_focus(self):
        self.assertIsNone(dl.focused_package("mCurrentFocus=null"))


class IdleTest(unittest.TestCase):
    def test_s24_power_dump(self):
        p = "  mLastWakeTime=503945918 (399648 ms ago)\nlastUserActivityTime=503950415 (395186 ms ago)\n"
        self.assertAlmostEqual(dl.idle_seconds(p), 395.186)

    def test_unknown(self):
        self.assertIsNone(dl.idle_seconds("nothing"))


if __name__ == "__main__":
    unittest.main()
