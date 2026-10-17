"""실기기 상시 확인 도구(docs/DEVICE_LOOP.md) — 한 동작씩: 캡처·누르기·끌기·뒤로·상태.

    python -I -B docs/store/device/device_loop.py status                  # 맨 앞 앱이 우리 앱인지·마지막 사용자 입력 몇 초 전·화면
    python -I -B docs/store/device/device_loop.py shot 01_start            # build/device/loop/<세션>/01_start.png
    python -I -B docs/store/device/device_loop.py tap 540 1200 [--times 5 --gap 0.15]
    python -I -B docs/store/device/device_loop.py swipe 540 1600 540 900 [--ms 300]
    python -I -B docs/store/device/device_loop.py back
    python -I -B docs/store/device/device_loop.py crash                    # logcat -b crash 최근(우리 앱 줄만)

안전 규칙(DEVICE_LOOP 2절): 입력 직전마다 우리 앱이 맨 앞인지 확인하고, 아니면 아무것도 보내지 않고 종료 코드 3.
보내는 입력은 우리 앱 화면 누르기·끌기·뒤로 키뿐. 캡처 뒤에도 맨 앞을 다시 보고, 그 사이 다른 앱이 앞으로 왔으면 파일을 지운다.
`--fresh`: 사용자가 [IDLE_SEC]초 안에 폰을 만졌으면 입력하지 않는다(사용자가 플레이 중) — 한 묶음의 첫 입력에 준다.
세션 폴더는 환경 변수 LOOP_SESSION(없으면 오늘 시각)으로 정한다.
종료 코드: 0 성공 · 2 기기 문제 · 3 앱이 맨 앞 아님/사용자 사용 중(아무것도 안 함).
"""

from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys
import time
from datetime import datetime
from pathlib import Path

sys.dont_write_bytecode = True
sys.stdout.reconfigure(encoding="utf-8")  # 윈도 콘솔에서 한글이 깨지지 않게
sys.path.insert(0, str(Path(__file__).resolve().parent))
from device_shots import PACKAGE, DeviceError, find_adb, parse_devices, pick_device  # noqa: E402

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "build" / "device" / "loop"
IDLE_SEC = 60
KEYCODE_BACK = "4"


def focused_package(window: str) -> str | None:
    """dumpsys window → 맨 앞 창의 패키지(mCurrentFocus). 다른 앱 이름은 비교에만 쓰고 출력하지 않는다."""
    m = re.search(r"mCurrentFocus=Window\{\S+ \S+ ([\w.]+)/", window)
    return m.group(1) if m else None


def idle_seconds(power: str) -> float | None:
    """dumpsys power → 마지막 사용자 입력 뒤 지난 초(`lastUserActivityTime=… (n ms ago)`)."""
    m = re.search(r"lastUserActivityTime=\d+ \((\d+) ms ago\)", power)  # S24(Android 14+) 꼴
    return int(m.group(1)) / 1000 if m else None


class Device:
    def __init__(self, serial: str | None):
        self.adb = find_adb()
        out = subprocess.run([self.adb, "devices", "-l"], capture_output=True, text=True).stdout
        self.serial = pick_device(parse_devices(out), serial)

    def sh(self, *cmd: str) -> str:
        r = subprocess.run([self.adb, "-s", self.serial, "shell", *cmd], capture_output=True, text=True,
                           encoding="utf-8", errors="replace")
        return r.stdout

    def ours_front(self) -> bool:
        return focused_package(self.sh("dumpsys", "window")) == PACKAGE

    def idle(self) -> float | None:
        return idle_seconds(self.sh("dumpsys", "power"))

    def guard(self, fresh: bool = False) -> None:
        if not self.ours_front():
            raise SystemExit(_stop("우리 앱이 맨 앞이 아니다 — 아무것도 보내지 않았다"))
        if fresh:
            idle = self.idle()
            if idle is not None and idle < IDLE_SEC:
                raise SystemExit(_stop(f"사용자가 {idle:.0f}초 전에 폰을 만졌다 — 플레이 중으로 보고 기다린다"))

    def shot(self, path: Path) -> bool:
        if not self.ours_front():
            print("캡처 안 함 — 우리 앱이 맨 앞이 아니다")
            return False
        path.parent.mkdir(parents=True, exist_ok=True)
        png = subprocess.run([self.adb, "-s", self.serial, "exec-out", "screencap", "-p"], capture_output=True).stdout
        path.write_bytes(png)
        if not self.ours_front():  # 찍는 사이 다른 앱이 앞으로 — 개인 정보라 바로 지운다.
            path.unlink(missing_ok=True)
            print("캡처 지움 — 찍는 사이 다른 앱이 앞으로 왔다")
            return False
        print(path)
        return True


def _stop(msg: str) -> int:
    print(msg)
    return 3


def session_dir() -> Path:
    return OUT / os.environ.get("LOOP_SESSION", datetime.now().strftime("%Y%m%d_%H%M"))


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--serial")
    ap.add_argument("--fresh", action="store_true", help=f"사용자가 {IDLE_SEC}초 안에 만졌으면 입력 안 함")
    sub = ap.add_subparsers(dest="cmd", required=True)
    sub.add_parser("status")
    s = sub.add_parser("shot")
    s.add_argument("name")
    t = sub.add_parser("tap")
    t.add_argument("x", type=int)
    t.add_argument("y", type=int)
    t.add_argument("--times", type=int, default=1)
    t.add_argument("--gap", type=float, default=0.15)
    w = sub.add_parser("swipe")
    for k in ("x1", "y1", "x2", "y2"):
        w.add_argument(k, type=int)
    w.add_argument("--ms", type=int, default=300)
    sub.add_parser("back")
    sub.add_parser("crash")
    a = ap.parse_args(argv)
    try:
        d = Device(a.serial)
    except DeviceError as e:
        print(e)
        return 2
    if a.cmd == "status":
        size = d.sh("wm", "size").strip().splitlines()[-1:]
        idle = d.idle()
        print(f"우리 앱 맨 앞: {d.ours_front()} · 마지막 입력 {idle if idle is None else round(idle)}초 전 · {size}")
        return 0
    if a.cmd == "shot":
        return 0 if d.shot(session_dir() / f"{a.name}.png") else 3
    if a.cmd == "crash":
        log = d.sh("logcat", "-b", "crash", "-d", "-t", "200")
        lines = [ln for ln in log.splitlines() if PACKAGE in ln or "FATAL" in ln]
        print("\n".join(lines[-40:]) or "크래시 기록 없음")
        return 0
    d.guard(fresh=a.fresh)
    if a.cmd == "tap":
        # 여러 번(운영자 패널 = 골드 5번/2초)은 한 셸 명령으로 — adb 왕복 지연 없이.
        cmd = f"input tap {a.x} {a.y}" + "".join(f"; sleep {a.gap}; input tap {a.x} {a.y}" for _ in range(a.times - 1))
        d.sh(cmd)
    elif a.cmd == "swipe":
        d.sh("input", "swipe", str(a.x1), str(a.y1), str(a.x2), str(a.y2), str(a.ms))
    elif a.cmd == "back":
        d.sh("input", "keyevent", KEYCODE_BACK)
    return 0


if __name__ == "__main__":
    sys.exit(main())
