"""device_shots.py 테스트 (기기 없이). python -I -B -m unittest discover -s docs/store/device"""

from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parent))
import device_shots as ds  # noqa: E402

DUMP = """<?xml version='1.0' encoding='UTF-8' standalone='yes' ?>
<hierarchy rotation="0">
  <node text="" content-desc="배 등급 강화" bounds="[0,900][540,960]" />
  <node text="" content-desc="항해&#10;탭 1/4" bounds="[0,2100][270,2220]" />
  <node text="" content-desc="배&#10;탭 2/4" bounds="[270,2100][540,2220]" />
  <node text="" content-desc="선원&#10;탭 3/4" bounds="[540,2100][810,2220]" />
  <node text="Summon" content-desc="" bounds="[810,2100][1080,2220]" />
  <node text="" content-desc="퀘스트·출석" bounds="[900,100][1000,200]" />
  <node text="" content-desc="설정" bounds="[1000,100][1080,200]" />
</hierarchy>"""


class Run:
    """adb 가짜: 명령 → 출력. 보낸 명령을 기록한다."""

    def __init__(self, outputs):
        self.outputs, self.calls = outputs, []

    def __call__(self, cmd, capture_output=True, check=False):
        self.calls.append(cmd[3:])
        key = " ".join(cmd[3:])
        out = next((v for k, v in self.outputs.items() if key.startswith(k)), b"")
        return type("R", (), {"returncode": 0, "stdout": out if isinstance(out, bytes) else out.encode(), "stderr": b""})()


AWAKE = {"shell dumpsys power": "mWakefulness=Awake", "shell dumpsys window": "mShowingLockscreen=false",
         "shell wm size": "Physical size: 1080x2340", "shell cat": DUMP, "exec-out screencap": b"\x89PNG"}


class DeviceShotsTest(unittest.TestCase):
    def test_find_adb_from_localappdata(self):
        with tempfile.TemporaryDirectory() as d:
            pt = Path(d) / "Android" / "Sdk" / "platform-tools"
            pt.mkdir(parents=True)
            exe = pt / ("adb.exe" if ds.os.name == "nt" else "adb")
            exe.write_text("")
            self.assertEqual(ds.find_adb({"LOCALAPPDATA": d}, which=lambda _: None), str(exe))
        with self.assertRaises(ds.DeviceError):
            ds.find_adb({}, which=lambda _: None)

    def test_pick_device(self):
        rows = ds.parse_devices("List of devices attached\nR5CT1 device usb:1 model:SM_S921N\n")
        self.assertEqual(ds.pick_device(rows, None), "R5CT1")
        with self.assertRaisesRegex(ds.DeviceError, "허용"):
            ds.pick_device(ds.parse_devices("List\nX unauthorized usb:1\n"), None)
        with self.assertRaisesRegex(ds.DeviceError, "없다"):
            ds.pick_device([], None)
        with self.assertRaisesRegex(ds.DeviceError, "여러"):
            ds.pick_device([("A", "device"), ("B", "device")], None)
        self.assertEqual(ds.pick_device([("A", "device"), ("B", "device")], "B"), "B")

    def test_screen_state(self):
        self.assertEqual(ds.screen_state("mWakefulness=Asleep", ""), "asleep")
        self.assertEqual(ds.screen_state("mWakefulness=Awake", "isKeyguardShowing=true"), "locked")
        self.assertEqual(ds.screen_state("mWakefulness=Awake", "mShowingLockscreen=false"), "awake")

    def test_tab_centers_exact_lines_bottom_most(self):
        c = ds.tab_centers(DUMP)
        self.assertEqual(c, {"voyage": (135, 2160), "ship": (405, 2160), "crew": (675, 2160), "summon": (945, 2160)})
        self.assertEqual(ds.tab_centers("<broken"), {})
        # 탭 바가 아닌 '배 등급 강화' 같은 글자는 탭으로 잡지 않는다(줄 단위 정확히 일치)
        self.assertEqual(ds.tab_centers('<hierarchy><node text="" content-desc="배 등급 강화" bounds="[0,900][540,960]"/></hierarchy>'), {})

    def test_fallback(self):
        self.assertEqual(ds.fallback_centers(1080, 2340, None)["crew"], (675, 2129))
        self.assertEqual(ds.fallback_centers(1080, 2340, 2000)["voyage"], (135, 2000))

    def test_capture_taps_tabs_and_saves(self):
        run = Run(AWAKE)
        with tempfile.TemporaryDirectory() as d:
            shots = ds.capture(ds.Adb("adb", "S", run), Path(d), wait=0, tab_y=None, sleep=lambda _: None)
            self.assertEqual([p.name for p in shots], ["01_voyage.png", "02_ship.png", "03_crew.png", "04_summon.png",
                                                       "05_quest.png", "06_settings.png"])
            self.assertEqual(shots[0].read_bytes(), b"\x89PNG")
        taps = [c[3:] for c in run.calls if c[:3] == ["shell", "input", "tap"]]
        self.assertEqual(taps[:4], [["135", "2160"], ["405", "2160"], ["675", "2160"], ["945", "2160"]])
        self.assertIn(["950", "150"], taps)  # 퀘스트
        self.assertIn(["1040", "150"], taps)  # 설정
        # 입력은 누르기와 BACK 키뿐 — 문자 입력·다른 키(전원·잠금 해제 등)는 보내지 않는다
        self.assertFalse([c for c in run.calls if c[:3] == ["shell", "input", "text"]])
        keys = [c[3:] for c in run.calls if c[:3] == ["shell", "input", "keyevent"]]
        self.assertEqual(keys, [["4"]])

    def test_missing_top_buttons_are_skipped(self):
        run = Run({**AWAKE, "shell cat": DUMP.replace("퀘스트·출석", "x").replace('content-desc="설정"', 'content-desc="y"')})
        with tempfile.TemporaryDirectory() as d:
            shots = ds.capture(ds.Adb("adb", "S", run), Path(d), wait=0, tab_y=None, sleep=lambda _: None)
        self.assertEqual(len(shots), 4)
        self.assertFalse([c for c in run.calls if c[:3] == ["shell", "input", "keyevent"]])

    def test_locked_stops_without_input(self):
        run = Run({**AWAKE, "shell dumpsys window": "isKeyguardShowing=true"})
        with tempfile.TemporaryDirectory() as d, self.assertRaisesRegex(ds.DeviceError, "잠겨"):
            ds.capture(ds.Adb("adb", "S", run), Path(d), wait=0, tab_y=None, sleep=lambda _: None)
        self.assertFalse([c for c in run.calls if c[:2] == ["shell", "input"] or c[:2] == ["shell", "am"]])


if __name__ == "__main__":
    unittest.main()
