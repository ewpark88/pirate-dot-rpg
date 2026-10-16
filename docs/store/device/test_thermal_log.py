"""thermal_log 파서 단위 테스트 (기기 없이): python -I -B docs/store/device/test_thermal_log.py"""

from __future__ import annotations

import sys
import unittest
from pathlib import Path

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parent))
from thermal_log import app_cpu, app_pss_mb, battery, refresh_hz, thermal_status  # noqa: E402


class ThermalLogTest(unittest.TestCase):
    def test_battery(self) -> None:
        self.assertEqual(battery("  level: 83\n  temperature: 452\n"), (45.2, 83))

    def test_thermal(self) -> None:
        self.assertEqual(thermal_status("IsStatusOverride: false\nThermal Status: 3\n"), 3)

    def test_cpu(self) -> None:
        top = (
            "  PID USER         PR  NI VIRT  RES  SHR S[%CPU] %MEM     TIME+ ARGS\n"
            "12345 u0_a321      10 -10  20G 900M 200M S 184.0  7.5   9:01.23 repo.dot.pirate\n"
        )
        self.assertEqual(app_cpu(top), 184.0)

    def test_pss(self) -> None:
        self.assertEqual(app_pss_mb("        TOTAL PSS:   524288   TOTAL RSS: 1"), 512.0)

    def test_refresh(self) -> None:
        self.assertEqual(refresh_hz("mActiveSfDisplayMode=DisplayMode{id=1, width=1080, height=2340, fps=60.0, x}"), 60.0)


if __name__ == "__main__":
    unittest.main()
