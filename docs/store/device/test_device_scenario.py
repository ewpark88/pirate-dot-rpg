"""device_scenario.py 테스트 (기기 없이). python -I -B -m unittest discover -s docs/store/device"""

from __future__ import annotations

import json
import sys
import unittest
from pathlib import Path

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parent))
import device_scenario as ds  # noqa: E402


class FakeDevice:
    def __init__(self, front=True, idle=999.0, crash_after=None):
        self.front = front
        self.idle_sec = idle
        self.sent: list[str] = []
        self.crash_after = crash_after
        self.shots: list[str] = []

    def sh(self, *cmd: str) -> str:
        line = " ".join(cmd)
        if line == "wm size":
            return "Physical size: 1080x2340\nOverride size: 720x1560"
        if line.startswith("logcat"):
            return "E AndroidRuntime: FATAL in repo.dot.pirate\n" if self.crash_after and len(self.sent) >= self.crash_after else ""
        self.sent.append(line)
        if line.endswith("keyevent 4") and len([s for s in self.sent if s.endswith("keyevent 4")]) >= 2:
            self.front = False  # 두 번째 뒤로 → 앱 종료
        return ""

    def ours_front(self) -> bool:
        return self.front

    def guard(self, fresh: bool = False) -> None:
        if not self.front:
            raise SystemExit(3)
        if fresh and self.idle_sec < 60:
            raise SystemExit(3)

    def shot(self, path) -> bool:
        self.shots.append(Path(path).name)
        return True


SMOKE = json.loads((Path(__file__).resolve().parent / "scenarios" / "smoke.json").read_text(encoding="utf-8"))["steps"]


class ScenarioTest(unittest.TestCase):
    def test_size_and_fraction(self):
        self.assertEqual(ds.screen_size("Physical size: 1080x2340\nOverride size: 720x1560"), (720, 1560))
        self.assertEqual(ds.px((720, 1560), 0.5, 0.9), (360, 1404))
        with self.assertRaises(ValueError):
            ds.px((720, 1560), 1.2, 0.5)

    def test_smoke_passes_on_healthy_app(self):
        d, log = FakeDevice(), []
        self.assertEqual(ds.run(SMOKE, d, log, sleep=lambda s: None), 0)
        self.assertEqual([s for s in d.sent if "keyevent" in s], ["input keyevent 4", "input keyevent 4"])
        self.assertEqual(d.shots, ["a01_battle.png", "a02_battle_60s.png", "a03_back_once.png"])

    def test_stops_when_not_front_or_user_playing(self):
        log = []
        self.assertEqual(ds.run([{"do": "tap", "fx": 0.5, "fy": 0.5}], FakeDevice(front=False), log, sleep=lambda s: None), 3)
        d = FakeDevice(idle=5)
        self.assertEqual(ds.run([{"do": "back"}], d, [], sleep=lambda s: None), 3)
        self.assertEqual(d.sent, [], "사용자가 방금 만졌으면 아무것도 보내지 않는다")

    def test_new_crash_fails(self):
        d, log = FakeDevice(crash_after=1), []
        steps = [{"do": "back"}, {"do": "crash"}]
        self.assertEqual(ds.run(steps, d, log, sleep=lambda s: None), 1)
        self.assertTrue(any("크래시" in ln for ln in log))


if __name__ == "__main__":
    unittest.main()
