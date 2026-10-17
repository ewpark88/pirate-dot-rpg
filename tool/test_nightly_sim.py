"""nightly_sim 단위 테스트 (sim 없이): python -I -B tool/test_nightly_sim.py"""

from __future__ import annotations

import sys
import unittest
from pathlib import Path

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parent))
from nightly_sim import note_on_top, off_target, pick_players, sim_args  # noqa: E402

REPORT = """<!-- game_cli sim --seed 1 --players 100 --days 30 --schedule daily — 생성물, 손으로 고치지 않는다 -->

# 밸런스 시뮬

| 지표 | 값 | 목표 | 판정 |
| --- | --- | --- | --- |
| 첫 보스 실패 | 2.65 분 | 1.00~3.00 | OK |
| 첫 전설 보유 | 4.00 일 | 1.00~4.00 | 벗어남 |
| 첫 신화 | 미도달 | 28.00~56.00 | 판정 안 함(시뮬 짧음) |
"""


class NightlySimTest(unittest.TestCase):
    def test_off_target(self) -> None:
        self.assertEqual(off_target(REPORT), ["첫 전설 보유"])

    def test_players(self) -> None:
        self.assertEqual(pick_players(100, 8.0, 4.0), (100, None))
        self.assertEqual(pick_players(100, None, 4.0), (100, None))
        n, note = pick_players(100, 2.5, 4.0)
        self.assertEqual(n, 50)
        self.assertIn("100명 → 50명", note or "")
        self.assertEqual(pick_players(12, 1.0, 4.0)[0], 10)

    def test_note_below_header(self) -> None:
        lines = note_on_top(REPORT, "메모").splitlines()
        self.assertTrue(lines[0].startswith("<!--"))
        self.assertEqual(lines[2], "> 메모")

    def test_args(self) -> None:
        a = sim_args(100, 30, Path("r.md"), 1)
        self.assertEqual(a[:1], ["sim"])
        self.assertIn("--schedule", a)
        self.assertEqual(a[a.index("--players") + 1], "100")


if __name__ == "__main__":
    unittest.main()
