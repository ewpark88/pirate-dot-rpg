"""device_watch.py 테스트 (기기 없이). python -I -B -m unittest discover -s docs/store/device"""

from __future__ import annotations

import sys
import unittest
from pathlib import Path

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parent))
import device_watch as dw  # noqa: E402

TIMELINE = """
Display Frame 1
  Layer - repo.dot.pirate/repo.dot.pirate.MainActivity
    Actual | 0 | 0 | 100.0
Display Frame 2
  Layer - com.example.other/Main
    Actual | 0 | 0 | 105.0
Display Frame 3
  Layer - repo.dot.pirate/repo.dot.pirate.MainActivity
    Actual | 0 | 0 | 116.7
Display Frame 4
  Layer - repo.dot.pirate/repo.dot.pirate.MainActivity
    Actual | 0 | 0 | 150.0
"""


class FrameTest(unittest.TestCase):
    def test_only_our_layer(self):
        self.assertEqual([round(x, 1) for x in dw.frame_intervals(TIMELINE)], [16.7, 33.3])

    def test_pct(self):
        self.assertEqual(dw.pct([], 0.5), 0.0)
        self.assertEqual(dw.pct([1, 2, 3, 4], 0.95), 4)


class CrashTest(unittest.TestCase):
    def test_only_our_lines(self):
        log = "E AndroidRuntime: Process: repo.dot.pirate, PID 1\nE AndroidRuntime: Process: com.secret.bank, PID 2\n"
        self.assertEqual(dw.crash_lines(log), ["E AndroidRuntime: Process: repo.dot.pirate, PID 1"])


class ReportTest(unittest.TestCase):
    def test_warnings_on_top(self):
        rows = [
            {"time": "10:00:00", "front": True, "fps": 60, "p50": 16.7, "p95": 30.0, "max": 50.0, "over": 5.0, "temp": 41.0,
             "thermal": 1, "cpu": 90.0, "pss": 450.0, "hz": 60.0, "crash": ["E ... repo.dot.pirate"]},
            {"time": "10:05:00", "front": False, "temp": 38.0, "thermal": 0, "crash": []},
        ]
        text = dw.report(rows, "20261018_1000")
        head = text.split("| 시각")[0]
        self.assertIn("크래시 1줄", head)
        self.assertIn("p95 30.0ms", head)
        self.assertIn("41.0℃", head)
        self.assertIn("건너뜀", text)
        self.assertNotIn("com.", text)

    def test_power_save_30hz_is_not_jank(self):
        row = {"time": "t", "front": True, "fps": 30, "p50": 33.3, "p95": 33.5, "max": 34.0, "over": 0.0, "hz": 30.0, "crash": []}
        self.assertEqual(dw.warnings_for(row), [])
        self.assertEqual(dw.frame_limit(60.0), 25.0)
        self.assertEqual(dw.frame_limit(30.0), 50.0)

    def test_no_warnings(self):
        rows = [{"time": "10:00:00", "front": True, "fps": 60, "p50": 16.7, "p95": 17.0, "max": 20.0, "over": 0.0, "temp": 33.0,
                 "thermal": 0, "cpu": 70.0, "pss": 430.0, "hz": 60.0, "crash": []}]
        self.assertIn("- 없음", dw.report(rows, "x"))


if __name__ == "__main__":
    unittest.main()
