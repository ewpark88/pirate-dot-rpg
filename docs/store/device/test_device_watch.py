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


MEMINFO = """
 App Summary
                       Pss(KB)                        Rss(KB)
                        ------                         ------
           Java Heap:    20480                          30000
         Native Heap:   307200                         310000
                Code:    51200                          90000
               Stack:     1024                           1024
            Graphics:   409600                         409600
           TOTAL PSS:   800000            TOTAL RSS:   900000
"""


class MemTest(unittest.TestCase):
    def test_parts(self):
        self.assertEqual(dw.mem_parts(MEMINFO), {"java": 20.0, "native": 300.0, "gfx": 400.0, "code": 50.0})

    def test_growth_warning(self):
        base = {"front": True, "fps": 60, "p50": 16.7, "p95": 17.0, "max": 20.0, "over": 0.0, "hz": 60.0, "crash": []}
        rows = [{**base, "time": "a", "pss": 600.0}, {**base, "time": "b", "pss": 12.0}, {**base, "time": "c", "pss": 950.0}]
        self.assertIn("누수 의심", dw.report(rows, "x").split("| 시각")[0])
        rows[-1]["pss"] = 700.0
        self.assertNotIn("누수 의심", dw.report(rows, "x"))


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
