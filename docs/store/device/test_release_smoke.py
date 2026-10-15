"""release_smoke.py 테스트 (기기 없이). python -I -B -m unittest discover -s docs/store/device"""

from __future__ import annotations

import sys
import unittest
from pathlib import Path

sys.dont_write_bytecode = True
for _s in (sys.stdout, sys.stderr):
    if hasattr(_s, "reconfigure"):
        _s.reconfigure(encoding="utf-8")
sys.path.insert(0, str(Path(__file__).resolve().parent))
import release_smoke as rs  # noqa: E402

FRONT = "  mCurrentFocus=Window{1 u0 repo.dot.pirate/repo.dot.pirate.MainActivity}\n"
CRASH = (
    "10-15 14:59:44.428 E AndroidRuntime: FATAL EXCEPTION: main\n"
    "10-15 14:59:44.428 E AndroidRuntime: Process: repo.dot.pirate, PID: 11388\n"
    "10-15 14:59:44.428 E AndroidRuntime: Caused by: java.lang.RuntimeException: Failed to create an instance of androidx.work.impl.WorkDatabase\n"
)


def runner(window: str, crash: str, pid: str):
    calls = []

    def run(*args: str) -> str:
        calls.append(args)
        if args[:3] == ("shell", "dumpsys", "window"):
            return window
        if args[:3] == ("logcat", "-d", "-b"):
            return crash
        if args[:2] == ("shell", "pidof"):
            return pid
        return ""

    return run, calls


class ReleaseSmokeTest(unittest.TestCase):
    def test_pass(self):
        run, calls = runner(FRONT, "", "1234\n")
        ok, msg = rs.smoke(run, wait=3, sleep=lambda _: None)
        self.assertTrue(ok, msg)
        self.assertFalse([c for c in calls if c[:2] == ("shell", "input")])  # 입력 없음

    def test_crash_on_launch_fails(self):  # 2026-10-15 사고 재현
        run, _ = runner("  mCurrentFocus=Window{2 u0 Application Error: repo.dot.pirate}\n", CRASH, "")
        ok, msg = rs.smoke(run, wait=3, sleep=lambda _: None)
        self.assertFalse(ok)
        self.assertIn("크래시", msg)

    def test_not_front_fails(self):
        run, _ = runner("  mCurrentFocus=Window{3 u0 com.sec.android.app.launcher/x}\n", "", "1234")
        ok, msg = rs.smoke(run, wait=2, sleep=lambda _: None)
        self.assertFalse(ok)
        self.assertIn("앞에", msg)


if __name__ == "__main__":
    unittest.main()
