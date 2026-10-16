"""장시간 발열·배터리·CPU 기록 (읽기 전용 — 폰에 입력을 보내지 않는다).

    python -I -B docs/store/device/thermal_log.py                          # 30분 동안 1분마다 → build/thermal/<시각>.csv
    python -I -B docs/store/device/thermal_log.py --minutes 60 --every 30 --serial <기기>

왜: 2026-10-17 실기기 S24 — 10분 만에 배터리 45℃·발열 SEVERE, 앱 CPU 184% + 오디오 56%, 120Hz.
60Hz 요청·오디오 상한·발열 절전(review/thermal) 전후를 같은 방법으로 비교한다.
기록: 시각(초), 배터리 온도(℃), 배터리(%), 발열 단계(0~6), 앱 CPU(%), 앱 PSS(MB), 화면 주사율(Hz, 알 수 있으면).
**입력(탭·키)·설치·실행은 하지 않는다** — 사용자가 앱을 앞에 두고 놓아둔 동안 읽기만. 앱이 안 떠 있으면 CPU·PSS는 빈칸.
종료 코드: 0 끝까지 · 2 기기 문제.
"""

from __future__ import annotations

import argparse
import csv
import re
import subprocess
import sys
import time
from datetime import datetime
from pathlib import Path

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parent))
from device_shots import PACKAGE, DeviceError, find_adb, parse_devices, pick_device  # noqa: E402

OUT = Path(__file__).resolve().parents[3] / "build" / "thermal"


def battery(text: str) -> tuple[float | None, int | None]:
    """dumpsys battery → (온도 ℃, 잔량 %). 온도는 0.1℃ 단위."""
    t = re.search(r"^\s*temperature:\s*(\d+)", text, re.M)
    lvl = re.search(r"^\s*level:\s*(\d+)", text, re.M)
    return (int(t.group(1)) / 10 if t else None, int(lvl.group(1)) if lvl else None)


def thermal_status(text: str) -> int | None:
    """dumpsys thermalservice → 'Thermal Status: n'."""
    m = re.search(r"Thermal Status:\s*(\d+)", text)
    return int(m.group(1)) if m else None


def app_cpu(top: str) -> float | None:
    """top -b -n 1 줄 중 우리 패키지의 %CPU(9번째 칸 근처 — 헤더의 %CPU 위치로 찾는다)."""
    lines = top.splitlines()
    header = next((ln for ln in lines if "%CPU" in ln), None)
    if header is None:
        return None
    cols = header.split()
    idx = next((i for i, c in enumerate(cols) if "%CPU" in c), None)
    if idx is not None and cols[idx].startswith("S["):
        idx += 1  # Android top 헤더는 상태 칸과 %CPU가 붙어 있다('S[%CPU]') — 줄에서는 두 칸
    for ln in lines:
        if PACKAGE in ln and idx is not None:
            parts = ln.split()
            try:
                return float(parts[idx].rstrip("%"))
            except (IndexError, ValueError):
                return None
    return None


def app_pss_mb(meminfo: str) -> float | None:
    """dumpsys meminfo <패키지> → TOTAL PSS(kB) → MB."""
    m = re.search(r"TOTAL PSS:\s*(\d+)", meminfo) or re.search(r"^\s*TOTAL\s+(\d+)", meminfo, re.M)
    return round(int(m.group(1)) / 1024, 1) if m else None


def refresh_hz(display: str) -> float | None:
    """dumpsys display → 지금 모드의 fps(예 'fps=60.0')."""
    m = re.search(r"mActiveSfDisplayMode=.*?fps=([\d.]+)", display) or re.search(r"renderFrameRate\s*=?\s*([\d.]+)", display)
    return float(m.group(1)) if m else None


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--minutes", type=float, default=30)
    ap.add_argument("--every", type=float, default=60, help="기록 간격(초)")
    ap.add_argument("--serial")
    args = ap.parse_args()
    try:
        adb = find_adb()
        serial = pick_device(parse_devices(subprocess.run([adb, "devices"], capture_output=True, text=True).stdout), args.serial)
    except DeviceError as e:
        print(f"기기 문제: {e}", file=sys.stderr)
        return 2

    def sh(*cmd: str) -> str:
        r = subprocess.run([adb, "-s", serial, "shell", *cmd], capture_output=True, text=True, encoding="utf-8", errors="replace")
        return r.stdout

    OUT.mkdir(parents=True, exist_ok=True)
    path = OUT / f"thermal_{datetime.now():%Y%m%d_%H%M}.csv"
    start = time.monotonic()
    end = start + args.minutes * 60
    with path.open("w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["sec", "battery_c", "battery_pct", "thermal", "app_cpu_pct", "app_pss_mb", "refresh_hz"])
        while True:
            temp, pct = battery(sh("dumpsys", "battery"))
            row = [
                round(time.monotonic() - start),
                temp,
                pct,
                thermal_status(sh("dumpsys", "thermalservice")),
                app_cpu(sh("top", "-b", "-n", "1")),
                app_pss_mb(sh("dumpsys", "meminfo", PACKAGE)),
                refresh_hz(sh("dumpsys", "display")),
            ]
            w.writerow(row)
            f.flush()
            print(" · ".join(str(x) for x in row))
            if time.monotonic() + args.every > end:
                break
            time.sleep(args.every)
    print(f"기록: {path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
