"""device_shots.py 테스트 (기기 없이). python -I -B -m unittest discover -s docs/store/device"""

from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path

sys.dont_write_bytecode = True
for _s in (sys.stdout, sys.stderr):  # 스크립트가 찍는 안내(—·한글)가 cp949 콘솔에서 깨지지 않게
    if hasattr(_s, "reconfigure"):
        _s.reconfigure(encoding="utf-8")
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


BARS = (
    "mShowingLockscreen=false\n  statusBars frame=[0,0][1080,103] visible=true\n"
    "  navigationBars frame=[0,2205][1080,2340] visible=true\n"
)
WINDOW = BARS + "  mCurrentFocus=Window{b6ce7a9 u0 repo.dot.pirate/repo.dot.pirate.MainActivity}\n"
# Samsung 실측(2026-10-15): 런처가 앞인데 topResumedActivity는 우리 앱 — mCurrentFocus만 믿는다
LAUNCHER = (
    BARS + "  mCurrentFocus=Window{2e24385 u0 com.sec.android.app.launcher/com.sec.android.app.launcher.activities"
    ".LauncherActivity}\n  topResumedActivity=ActivityRecord{1 u0 repo.dot.pirate/.MainActivity t1}\n"
)
AWAKE = {"shell dumpsys power": "mWakefulness=Awake", "shell dumpsys window": WINDOW,
         "shell wm size": "Physical size: 1080x2340", "shell wm density": "Physical density: 480\nOverride density: 450",
         "shell cat": DUMP, "exec-out screencap": b"\x89PNG"}


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

    def test_layout_rule_matches_s24(self):
        # S24 실측(2026-10-15 캡처): 설정 (1010,170) · 퀘스트 (876,170) · 탭 바 y 2030~2200
        self.assertEqual(ds.parse_bars(WINDOW, 2340), (103, 2205))
        self.assertEqual(ds.parse_bars("", 2340), (0, 2340))
        self.assertEqual(ds.parse_dpr("Physical density: 480\nOverride density: 450"), 2.8125)
        tabs, buttons = ds.layout_centers(1080, 2.8125, 103, 2205, None)
        self.assertEqual(tabs["crew"], (675, 2126))
        self.assertEqual(buttons, {"settings": (1012, 171), "quest": (878, 171)})

    def test_scrim_and_primary_button_from_pixels(self):
        from PIL import Image

        normal = Image.new("RGB", (1080, 2340), ds.NAVY_DARK)
        self.assertFalse(ds.has_scrim(normal, 103, 2.8125))
        dim = Image.new("RGB", (1080, 2340), (6, 7, 13))
        self.assertTrue(ds.has_scrim(dim, 103, 2.8125))
        self.assertIsNone(ds.find_primary(dim))
        dim.paste(ds.ACTION, (700, 1300, 900, 1400))  # 막 위에 밝게 남은 '받기' 버튼
        x, y = ds.find_primary(dim)
        self.assertTrue(700 <= x <= 900 and 1300 <= y <= 1400)
        self.assertFalse(ds.has_scrim(None, 103, 2.8125))
        # 실기기(S24) 캡처의 '받기' 버튼 색 (67,118,185)도 잡고, 막 아래로 어두워진 버튼은 안 잡는다
        real = Image.new("RGB", (1080, 2340), (6, 7, 13))
        real.paste((67, 118, 185), (870, 1242, 981, 1350))
        real.paste((31, 54, 85), (100, 500, 600, 600))
        x, y = ds.find_primary(real)
        self.assertTrue(870 <= x <= 981 and 1242 <= y <= 1350)

    def test_same_screen(self):
        from PIL import Image

        a = Image.new("RGB", (1080, 2340), (20, 20, 40))
        b = a.copy()
        b.paste((200, 50, 50), (0, 0, 1080, 900))  # 전장만 다름 → 같은 화면
        self.assertTrue(ds.same_screen(a, b, 1053, 2025))
        b.paste((200, 200, 200), (0, 1200, 1080, 1800))  # 탭 내용이 바뀜
        self.assertFalse(ds.same_screen(a, b, 1053, 2025))
        self.assertFalse(ds.same_screen(None, b, 1053, 2025))

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

    def test_failed_dump_uses_layout_rule(self):
        run = Run({**AWAKE, "shell cat": ""})  # 실기기: uiautomator가 "null root node"로 실패
        with tempfile.TemporaryDirectory() as d:
            shots = ds.capture(ds.Adb("adb", "S", run), Path(d), wait=0, tab_y=None, sleep=lambda _: None)
        self.assertEqual(len(shots), 6)
        taps = [c[3:] for c in run.calls if c[:3] == ["shell", "input", "tap"]]
        self.assertEqual(taps[:4], [["135", "2126"], ["405", "2126"], ["675", "2126"], ["945", "2126"]])
        self.assertIn(["878", "171"], taps)
        self.assertIn(["1012", "171"], taps)

    def test_never_presses_when_app_not_in_front(self):
        # 2026-10-15 사고 재현: 앱이 뒤에 있고 런처가 앞 → 아무것도 누르지 않고 멈춘다
        run = Run({**AWAKE, "shell dumpsys window": LAUNCHER})
        with tempfile.TemporaryDirectory() as d, self.assertRaisesRegex(ds.DeviceError, "앞에"):
            ds.capture(ds.Adb("adb", "S", run), Path(d), wait=0, tab_y=None, sleep=lambda _: None)
        self.assertFalse([c for c in run.calls if c[:2] == ["shell", "input"]])

    def test_no_back_when_settings_did_not_open(self):
        # 버튼을 눌러도 화면이 그대로면 BACK을 보내지 않는다(첫 화면에서 BACK = 앱 닫힘)
        import io

        from PIL import Image

        buf = io.BytesIO()
        Image.new("RGB", (1080, 2340), (13, 15, 27)).save(buf, format="PNG")
        run = Run({**AWAKE, "shell cat": "", "exec-out screencap": buf.getvalue()})
        with tempfile.TemporaryDirectory() as d:
            ds.capture(ds.Adb("adb", "S", run), Path(d), wait=0, tab_y=None, sleep=lambda _: None)
        self.assertFalse([c for c in run.calls if c[:3] == ["shell", "input", "keyevent"]])

    def test_in_front(self):
        self.assertTrue(ds.in_front(WINDOW))
        self.assertFalse(ds.in_front(LAUNCHER))
        self.assertFalse(ds.in_front(BARS + "  mCurrentFocus=null\n"))
        self.assertFalse(ds.in_front(""))

    def test_locked_stops_without_input(self):
        run = Run({**AWAKE, "shell dumpsys window": "isKeyguardShowing=true"})
        with tempfile.TemporaryDirectory() as d, self.assertRaisesRegex(ds.DeviceError, "잠겨"):
            ds.capture(ds.Adb("adb", "S", run), Path(d), wait=0, tab_y=None, sleep=lambda _: None)
        self.assertFalse([c for c in run.calls if c[:2] == ["shell", "input"] or c[:2] == ["shell", "am"]])


if __name__ == "__main__":
    unittest.main()
