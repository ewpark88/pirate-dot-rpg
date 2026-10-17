"""실기기 읽기 전용 감시(docs/DEVICE_LOOP.md #56 — 폰 입력 권한 없이 할 수 있는 몫): 앱이 맨 앞일 때만 주기적으로 재서 표로.

    python -I -B docs/store/device/device_watch.py                     # 60분 동안 5분마다 → build/device/watch/<시각>.md
    python -I -B docs/store/device/device_watch.py --minutes 120 --every 180 --serial R3CX90JQLEB

표본마다: 프레임(SurfaceFlinger frametimeline — 우리 앱 레이어, 최근 약 10초) p50·p95·최대·끊김 비율(그때 주사율 1.5주기 넘음), 배터리 온도, 발열 단계,
앱 CPU·PSS, 화면 주사율, logcat 크래시 버퍼의 우리 앱 줄(새로 생긴 것만). 크래시·p95가 끊김 기준(1.5주기, 최소 25ms)을 넘음·온도 > 40℃면 보고서 맨 위 '경고'에.
**입력(탭·키)·설치·실행·화면 캡처는 하지 않는다.** 우리 앱이 맨 앞이 아니면 그 표본은 '건너뜀'(다른 앱 이름은 남기지 않는다).
종료 코드: 0 끝까지 · 2 기기 문제.
"""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
import time
from datetime import datetime
from pathlib import Path

sys.dont_write_bytecode = True
sys.stdout.reconfigure(encoding="utf-8")
sys.path.insert(0, str(Path(__file__).resolve().parent))
from device_loop import focused_package  # noqa: E402
from device_shots import PACKAGE, DeviceError, find_adb, parse_devices, pick_device  # noqa: E402
from thermal_log import app_cpu, app_pss_mb, battery, refresh_hz, thermal_status  # noqa: E402

OUT = Path(__file__).resolve().parents[3] / "build" / "device" / "watch"
P95_WARN_MS = 25.0
TEMP_WARN_C = 40.0
PSS_GROWTH = 1.5  # 첫 표본보다 이만큼 커지면 누수 의심
PSS_FLOOR_MB = 100  # 막 켜진(재시작) 표본은 비교에서 뺀다


def frame_intervals(frametimeline: str, package: str = PACKAGE) -> list[float]:
    """dumpsys SurfaceFlinger --frametimeline -all → 우리 앱 레이어 실제 표시 시각 사이 간격(ms)."""
    pres: set[float] = set()
    for block in frametimeline.split("Display Frame ")[1:]:
        if package + "/" not in block:
            continue
        layer = block[block.index(package + "/"):]
        m = re.search(r"Actual\s*\|\s*\S+\s*\|\s*\S+\s*\|\s*([\d.]+)", layer)
        if m:
            pres.add(float(m.group(1)))
    p = sorted(pres)
    return [b - a for a, b in zip(p, p[1:])]


def pct(values: list[float], q: float) -> float:
    v = sorted(values)
    return v[min(len(v) - 1, int(q * len(v)))] if v else 0.0


MEM_PARTS = (("Java Heap", "java"), ("Native Heap", "native"), ("Graphics", "gfx"), ("Code", "code"))


def mem_parts(meminfo: str) -> dict[str, float]:
    """dumpsys meminfo <패키지>의 App Summary → 항목별 PSS(MB): java·native·gfx(텍스처·GL)·code. 어디서 느는지(누수) 본다."""
    out: dict[str, float] = {}
    for label, key in MEM_PARTS:
        m = re.search(rf"^\s*{label}:\s*(\d+)", meminfo, re.M)
        if m:
            out[key] = round(int(m.group(1)) / 1024, 1)
    return out


def crash_lines(log: str, package: str = PACKAGE) -> list[str]:
    """logcat -b crash 출력 중 우리 앱 줄(다른 앱 줄은 버린다 — 개인 정보)."""
    return [ln for ln in log.splitlines() if package in ln]


def frame_limit(hz: float | None) -> float:
    """끊김 기준(ms): 그때 주사율 한 주기의 1.5배와 25ms 중 큰 값 — 절전 30Hz(33ms 간격)를 끊김으로 잡지 않게."""
    return max(P95_WARN_MS, 1.5 * 1000 / hz) if hz else P95_WARN_MS


def warnings_for(row: dict) -> list[str]:
    out = []
    if row.get("crash"):
        out.append(f"{row['time']} 크래시 {len(row['crash'])}줄")
    limit = frame_limit(row.get("hz"))
    if row.get("p95") and row["p95"] > limit:
        out.append(f"{row['time']} 프레임 p95 {row['p95']:.1f}ms > {limit:.0f}")
    if row.get("temp") and row["temp"] > TEMP_WARN_C:
        out.append(f"{row['time']} 배터리 {row['temp']:.1f}℃ > {TEMP_WARN_C:.0f}")
    return out


def report(rows: list[dict], started: str) -> str:
    warns = [w for r in rows for w in warnings_for(r)]
    pss = [(r["time"], r["pss"]) for r in rows if r.get("front") and (r.get("pss") or 0) > PSS_FLOOR_MB]
    if len(pss) >= 2 and pss[-1][1] > pss[0][1] * PSS_GROWTH:
        warns.append(f"PSS {pss[0][1]:.0f} → {pss[-1][1]:.0f}MB ({pss[0][0]} → {pss[-1][0]}) — 누수 의심(항목별 열에서 느는 곳)")
    lines = [f"# 기기 감시 {started} (읽기 전용 — 입력·캡처 없음)", ""]
    lines += ["## 경고", *(f"- {w}" for w in warns)] if warns else ["## 경고", "- 없음"]
    lines += [
        "",
        "| 시각 | 앞 | fps | p50 / p95 / 최대 ms | 끊김(1.5주기+) | 온도 ℃ | 발열 | CPU % | PSS MB | java / native / gfx / code MB | Hz |",
        "| " + " | ".join(["---"] * 11) + " |",
    ]
    for r in rows:
        if not r.get("front"):
            lines.append(f"| {r['time']} | 건너뜀 | | | | {r.get('temp') or ''} | {r.get('thermal') if r.get('thermal') is not None else ''} | | | | |")
            continue
        lines.append(
            f"| {r['time']} | 우리 앱 | {r['fps']:.0f} | {r['p50']:.1f} / {r['p95']:.1f} / {r['max']:.1f} | {r['over']:.1f}% | "
            f"{r.get('temp') or ''} | {r.get('thermal') if r.get('thermal') is not None else ''} | {r.get('cpu') or ''} | {r.get('pss') or ''} | "
            f"{' / '.join(str(r.get('mem', {}).get(k, '')) for _, k in MEM_PARTS)} | {r.get('hz') or ''} |"
        )
    crashes = [ln for r in rows for ln in r.get("crash", [])]
    if crashes:
        lines += ["", "## 크래시(우리 앱 줄만)", "```", *crashes[-60:], "```"]
    return "\n".join(lines) + "\n"


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--minutes", type=float, default=60)
    ap.add_argument("--every", type=float, default=300, help="표본 간격(초)")
    ap.add_argument("--serial")
    a = ap.parse_args(argv)
    try:
        adb = find_adb()
        serial = pick_device(parse_devices(subprocess.run([adb, "devices", "-l"], capture_output=True, text=True).stdout), a.serial)
    except DeviceError as e:
        print(e)
        return 2

    def sh(*cmd: str) -> str:
        return subprocess.run([adb, "-s", serial, "shell", *cmd], capture_output=True, text=True, encoding="utf-8", errors="replace").stdout

    started = datetime.now().strftime("%Y%m%d_%H%M")
    path = OUT / f"{started}.md"
    path.parent.mkdir(parents=True, exist_ok=True)
    seen_crash = set(crash_lines(sh("logcat", "-b", "crash", "-d")))  # 시작 전 크래시는 빼고 새것만
    rows: list[dict] = []
    end = time.time() + a.minutes * 60
    while True:
        row: dict = {"time": datetime.now().strftime("%H:%M:%S")}
        temp, _ = battery(sh("dumpsys", "battery"))
        row["temp"] = temp
        row["thermal"] = thermal_status(sh("dumpsys", "thermalservice"))
        row["front"] = focused_package(sh("dumpsys", "window")) == PACKAGE
        if row["front"]:
            gaps: list[float] = []
            for _ in range(10):  # frametimeline은 최근 약 1초 — 10번 모은다
                gaps += frame_intervals(sh("dumpsys", "SurfaceFlinger", "--frametimeline", "-all"))
                time.sleep(1)
            p50 = pct(gaps, 0.5)
            row.update(
                fps=1000 / p50 if p50 else 0,
                p50=p50,
                p95=pct(gaps, 0.95),
                max=max(gaps) if gaps else 0,
                cpu=app_cpu(sh("top", "-b", "-n", "1")),
                pss=app_pss_mb(mem := sh("dumpsys", "meminfo", PACKAGE)),
                mem=mem_parts(mem),
                hz=refresh_hz(sh("dumpsys", "display")),
            )
            row["over"] = 100 * sum(g > frame_limit(row["hz"]) for g in gaps) / max(1, len(gaps))
        new = [ln for ln in crash_lines(sh("logcat", "-b", "crash", "-d")) if ln not in seen_crash]
        seen_crash.update(new)
        row["crash"] = new
        rows.append(row)
        path.write_text(report(rows, started), encoding="utf-8")
        print(f"{row['time']} {'우리 앱' if row['front'] else '건너뜀'} → {path}", flush=True)
        if time.time() + a.every > end:
            return 0
        time.sleep(a.every)


if __name__ == "__main__":
    sys.exit(main())
