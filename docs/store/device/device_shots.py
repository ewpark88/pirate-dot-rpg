"""실기기(USB) 화면 자동 캡처: 설치 → 실행 → 탭 4개 이동 → 스크린샷 → build/device/shots/.

    python -I -B docs/store/device/device_shots.py                     # 이미 설치된 앱으로 실행·캡처
    python -I -B docs/store/device/device_shots.py --apk build/app/outputs/flutter-apk/app-profile.apk
    python -I -B docs/store/device/device_shots.py --build             # flutter build apk --profile 후 설치·캡처
    python -I -B docs/store/device/device_shots.py --serial R5CT... --wait 8

안전 규칙: **잠금 해제·비밀번호·문자 입력은 절대 자동으로 하지 않는다.** 화면이 꺼져 있거나 잠겨 있으면 안내하고 끝낸다.
보내는 입력은 우리 앱 화면의 탭 버튼 누르기(input tap)뿐이다. 앱 데이터(세이브)를 지우는 일도 하지 않는다 —
서명이 달라 설치가 실패하면 지우고 다시 깔지 사람에게 묻는다(--reinstall을 줄 때만 adb uninstall).

탭 위치: uiautomator 화면 덤프에서 탭 이름(항해·배·선원·소환 / Voyage·Ship·Crew·Summon)의 좌표를 찾는다.
못 찾으면 화면 아래쪽 탭 줄을 4등분한 자리(--tab-y로 높이 지정 가능)를 누른다.
"""

from __future__ import annotations

import argparse
import datetime as dt
import os
import re
import shutil
import subprocess
import sys
import time
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
APP = ROOT / "apps" / "game"
OUT = ROOT / "build" / "device" / "shots"
PACKAGE = "repo.dot.pirate"
ACTIVITY = f"{PACKAGE}/.MainActivity"
TABS = [("voyage", ("항해", "Voyage")), ("ship", ("배", "Ship")), ("crew", ("선원", "Crew")), ("summon", ("소환", "Summon"))]


class DeviceError(Exception):
    """사람이 할 일이 있는 상태 (안내 문구를 담는다)."""


def find_adb(env: dict[str, str] | None = None, which=shutil.which) -> str:
    """PATH → ANDROID_HOME/ANDROID_SDK_ROOT → %LOCALAPPDATA%\\Android\\Sdk 순서."""
    env = os.environ if env is None else env
    found = which("adb")
    if found:
        return found
    exe = "adb.exe" if os.name == "nt" else "adb"
    roots = [env.get("ANDROID_HOME"), env.get("ANDROID_SDK_ROOT")]
    if env.get("LOCALAPPDATA"):
        roots.append(str(Path(env["LOCALAPPDATA"]) / "Android" / "Sdk"))
    for r in roots:
        if r and (Path(r) / "platform-tools" / exe).exists():
            return str(Path(r) / "platform-tools" / exe)
    raise DeviceError("adb를 찾지 못했다 — Android SDK platform-tools를 설치하거나 PATH에 넣는다.")


def parse_devices(out: str) -> list[tuple[str, str]]:
    """`adb devices -l` → [(serial, state)]."""
    rows = []
    for line in out.splitlines()[1:]:
        parts = line.split()
        if len(parts) >= 2:
            rows.append((parts[0], parts[1]))
    return rows


def pick_device(rows: list[tuple[str, str]], serial: str | None) -> str:
    if serial:
        rows = [r for r in rows if r[0] == serial]
    if not rows:
        raise DeviceError("연결된 기기가 없다 — USB 연결, 개발자 옵션의 USB 디버깅을 켠다.")
    ready = [s for s, st in rows if st == "device"]
    if any(st == "unauthorized" for _, st in rows) and not ready:
        raise DeviceError("기기가 이 PC를 아직 허용하지 않았다 — 폰 화면의 'USB 디버깅 허용'을 사람이 누른다.")
    if not ready:
        raise DeviceError(f"기기 상태가 준비되지 않았다: {rows}")
    if len(ready) > 1:
        raise DeviceError(f"기기가 여러 대다 — --serial로 고른다: {ready}")
    return ready[0]


def screen_state(power: str, window: str) -> str:
    """'awake' | 'asleep' | 'locked'. dumpsys power·window 출력으로 판단(입력 없이 읽기만)."""
    m = re.search(r"mWakefulness=(\w+)", power)
    if m and m.group(1) != "Awake":
        return "asleep"
    locked = re.search(r"(mShowingLockscreen|mDreamingLockscreen|isKeyguardShowing|mKeyguardShowing|KeyguardShowing)=true", window)
    return "locked" if locked else "awake"


def tab_centers(xml: str) -> dict[str, tuple[int, int]]:
    """uiautomator 덤프에서 탭 이름이 든 노드의 가운데 좌표. 같은 이름이 여럿이면 화면 맨 아래 것(탭 바)."""
    found: dict[str, tuple[int, int]] = {}
    try:
        root = ET.fromstring(xml)
    except ET.ParseError:
        return found
    for node in root.iter("node"):
        # Flutter 탭은 content-desc가 "항해⏎탭 1/4" 꼴 — 줄 단위로 정확히 같은 이름만('배 등급' 같은 글자를 안 잡게).
        text = (node.get("text") or "") + "\n" + (node.get("content-desc") or "")
        lines = {ln.strip() for ln in text.splitlines()}
        m = re.match(r"\[(\d+),(\d+)\]\[(\d+),(\d+)\]", node.get("bounds") or "")
        if not m:
            continue
        x1, y1, x2, y2 = map(int, m.groups())
        for key, names in TABS:
            if any(n in lines for n in names):
                c = ((x1 + x2) // 2, (y1 + y2) // 2)
                if key not in found or c[1] > found[key][1]:
                    found[key] = c
    return found


def fallback_centers(width: int, height: int, tab_y: int | None) -> dict[str, tuple[int, int]]:
    """탭 줄을 4등분. 기본 높이: 화면 아래에서 9%(내비게이션 바 위의 탭 바 가운데쯤)."""
    y = tab_y if tab_y is not None else round(height * 0.91)
    return {key: (round(width * (i + 0.5) / len(TABS)), y) for i, (key, _) in enumerate(TABS)}


def parse_size(out: str) -> tuple[int, int]:
    m = re.search(r"(?:Override|Physical) size: (\d+)x(\d+)", out)
    if not m:
        raise DeviceError(f"화면 크기를 못 읽었다: {out!r}")
    return int(m.group(1)), int(m.group(2))


class Adb:
    def __init__(self, exe: str, serial: str, run=subprocess.run):
        self.exe, self.serial, self._run = exe, serial, run

    def __call__(self, *args: str, binary: bool = False, check: bool = True):
        r = self._run([self.exe, "-s", self.serial, *args], capture_output=True, check=False)
        if check and r.returncode != 0:
            raise DeviceError(f"adb {' '.join(args)} 실패: {(r.stderr or b'').decode(errors='replace').strip()}")
        return r.stdout if binary else (r.stdout or b"").decode("utf-8", errors="replace")


def capture(adb: Adb, out_dir: Path, *, wait: float, tab_y: int | None, sleep=time.sleep) -> list[Path]:
    state = screen_state(adb("shell", "dumpsys", "power"), adb("shell", "dumpsys", "window"))
    if state != "awake":
        raise DeviceError("폰 화면이 꺼져 있거나 잠겨 있다 — 사람이 잠금을 풀고 화면을 켠 뒤 다시 실행한다(자동 잠금 해제는 하지 않는다).")
    adb("shell", "am", "start", "-n", ACTIVITY)
    sleep(wait)
    width, height = parse_size(adb("shell", "wm", "size"))
    adb("shell", "uiautomator", "dump", "/sdcard/pde_ui.xml", check=False)
    centers = tab_centers(adb("shell", "cat", "/sdcard/pde_ui.xml", check=False))
    adb("shell", "rm", "-f", "/sdcard/pde_ui.xml", check=False)
    fb = fallback_centers(width, height, tab_y)
    out_dir.mkdir(parents=True, exist_ok=True)
    shots = []
    for i, (key, _) in enumerate(TABS):
        x, y = centers.get(key, fb[key])
        adb("shell", "input", "tap", str(x), str(y))
        sleep(1.2)
        path = out_dir / f"{i + 1:02d}_{key}.png"
        path.write_bytes(adb("exec-out", "screencap", "-p", binary=True))
        shots.append(path)
    adb("shell", "input", "tap", *map(str, centers.get("voyage", fb["voyage"])))  # 항해로 돌려놓기
    print(f"탭 좌표: {'덤프' if len(centers) == len(TABS) else '4등분 대체'} {centers or fb}")
    return shots


def main(argv: list[str] | None = None) -> int:
    for stream in (sys.stdout, sys.stderr):
        if hasattr(stream, "reconfigure"):
            stream.reconfigure(encoding="utf-8")
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--serial")
    ap.add_argument("--apk", type=Path, help="설치할 apk (없으면 이미 설치된 앱)")
    ap.add_argument("--build", action="store_true", help="flutter build apk --profile 후 그 apk 설치")
    ap.add_argument("--operator", action="store_true", help="--build 때 운영자 빌드(--dart-define=OPERATOR=true)")
    ap.add_argument("--reinstall", action="store_true", help="서명이 달라 설치가 실패하면 지우고 다시(세이브 삭제됨)")
    ap.add_argument("--wait", type=float, default=6.0, help="실행 뒤 첫 화면까지 기다릴 초")
    ap.add_argument("--tab-y", type=int, help="탭 바 높이(px) — 덤프에서 못 찾을 때")
    ap.add_argument("--out", type=Path, default=OUT)
    a = ap.parse_args(argv)
    try:
        exe = find_adb()
        serial = pick_device(parse_devices(subprocess.run([exe, "devices", "-l"], capture_output=True, text=True).stdout), a.serial)
        adb = Adb(exe, serial)
        apk = a.apk
        if a.build:
            cmd = ["flutter", "build", "apk", "--profile"] + (["--dart-define=OPERATOR=true"] if a.operator else [])
            subprocess.run(cmd, cwd=APP, check=True, shell=os.name == "nt")
            apk = APP / "build" / "app" / "outputs" / "flutter-apk" / "app-profile.apk"
        if apk:
            r = subprocess.run([exe, "-s", serial, "install", "-r", str(apk)], capture_output=True, text=True)
            if r.returncode != 0 or "Failure" in r.stdout:
                msg = (r.stdout + r.stderr).strip()
                if "INSTALL_FAILED_UPDATE_INCOMPATIBLE" in msg and a.reinstall:
                    adb("uninstall", PACKAGE)
                    adb("install", str(apk))
                else:
                    raise DeviceError(f"설치 실패: {msg}\n  서명이 다르면(디버그↔릴리스) --reinstall로 지우고 다시 깐다 — 기기의 세이브가 지워진다.")
        stamp = dt.datetime.now().strftime("%Y%m%d-%H%M%S")
        shots = capture(adb, a.out / stamp, wait=a.wait, tab_y=a.tab_y)
        latest = a.out / "latest"
        shutil.rmtree(latest, ignore_errors=True)
        shutil.copytree(a.out / stamp, latest)
        for p in shots:
            print(p)
        print(f"완료 → {a.out / stamp} (복사본 {latest})")
        return 0
    except DeviceError as e:
        print(f"멈춤: {e}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
