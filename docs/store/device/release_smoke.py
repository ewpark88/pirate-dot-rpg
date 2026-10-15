"""릴리스 빌드 실기기 실행 점검: 설치 → 실행 → 10초 안에 죽지 않고 우리 화면이 앞인지.

    python -I -B docs/store/device/release_smoke.py                       # apps/game/build/app/outputs/flutter-apk/app-release.apk
    python -I -B docs/store/device/release_smoke.py --apk <경로> --serial <기기>

왜: 2026-10-15 release apk가 실행 즉시 종료(R8이 WorkManager Room 구현 클래스를 지움). 빌드만 하는 release_check는 못 잡았다.
**입력(탭·키)은 보내지 않는다** — 설치·실행·읽기만. 기기의 기존 앱을 이 apk로 덮어 설치하므로(세이브는 유지), 다른 사람이 그 기기로
확인 중일 때는 돌리지 않는다.
종료 코드: 0 통과 · 1 실패(크래시·앞에 안 옴) · 2 기기 문제.
"""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
import time
from pathlib import Path

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parent))
from device_shots import ACTIVITY, PACKAGE, DeviceError, find_adb, in_front, parse_devices, pick_device  # noqa: E402

APK = Path(__file__).resolve().parents[3] / "apps" / "game" / "build" / "app" / "outputs" / "flutter-apk" / "app-release.apk"


def crashed(crash_log: str) -> list[str]:
    """crash 버퍼에서 우리 프로세스의 FATAL 줄."""
    return [ln for ln in crash_log.splitlines() if "FATAL EXCEPTION" in ln or ("Process: " + PACKAGE) in ln]


def smoke(run, wait: float = 10.0, sleep=time.sleep) -> tuple[bool, str]:
    """[run](*adb 인자) → stdout. 설치 뒤 호출."""
    run("logcat", "-b", "crash", "-c")
    run("shell", "am", "start", "-a", "android.intent.action.MAIN", "-c", "android.intent.category.LAUNCHER", "-n", ACTIVITY)
    deadline = wait
    front = False
    while deadline > 0:
        sleep(1.0)
        deadline -= 1.0
        if in_front(run("shell", "dumpsys", "window")):
            front = True
            break
    sleep(3.0)  # 첫 화면 뒤 바로 죽는 경우까지
    fatal = crashed(run("logcat", "-d", "-b", "crash"))
    alive = bool(run("shell", "pidof", PACKAGE).strip())
    if fatal:
        return False, "크래시:\n  " + "\n  ".join(fatal[:6])
    if not front:
        return False, f"{wait:.0f}초 안에 우리 화면이 앞에 오지 않음"
    if not alive:
        return False, "프로세스가 사라짐"
    return True, "통과 — 실행·앞 화면·프로세스 유지, 크래시 0"


def main(argv: list[str] | None = None) -> int:
    for s in (sys.stdout, sys.stderr):
        if hasattr(s, "reconfigure"):
            s.reconfigure(encoding="utf-8")
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--apk", type=Path, default=APK)
    ap.add_argument("--serial")
    ap.add_argument("--wait", type=float, default=10.0)
    a = ap.parse_args(argv)
    try:
        exe = find_adb()
        serial = pick_device(parse_devices(subprocess.run([exe, "devices", "-l"], capture_output=True, text=True).stdout), a.serial)
        if not a.apk.exists():
            raise DeviceError(f"apk 없음: {a.apk} — 먼저 flutter build apk --release")
        r = subprocess.run([exe, "-s", serial, "install", "-r", str(a.apk)], capture_output=True, text=True)
        if r.returncode != 0 or "Failure" in r.stdout:
            raise DeviceError(f"설치 실패: {(r.stdout + r.stderr).strip()}")

        def run(*args: str) -> str:
            out = subprocess.run([exe, "-s", serial, *args], capture_output=True)
            return out.stdout.decode("utf-8", "replace")

        ok, msg = smoke(run, a.wait)
        print(("✓ " if ok else "✗ ") + msg)
        return 0 if ok else 1
    except DeviceError as e:
        print(f"멈춤: {e}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
