"""야간 밸런스 sim 점검 — 가상 플레이어 100명 × 30일 리포트를 한 번에 (docs/balance/README.md 순서 그대로).

    python -I -B tool/nightly_sim.py                     # exe 컴파일 → sim → docs/balance/nightly-30d.md → 요약
    python -I -B tool/nightly_sim.py --players 50        # 메모리 부족할 때
    python -I -B tool/nightly_sim.py --dry-run           # 무엇을 돌릴지만 보여 준다

이 PC는 무거운 일(sim·check --full·flutter build)을 동시에 돌리면 메모리 부족으로 강제 종료된다 →
  - 잠금 파일(%TEMP%/pirate-dot-heavy.lock)이 있으면 시작하지 않는다(다른 세션이 무거운 일 중). 끝나면 지운다.
  - 남은 메모리가 --min-free-gb보다 적으면 플레이어 수를 반으로 줄이고 리포트 맨 위에 그 사실을 적는다.
기록: build/nightly/log.csv(시각·플레이어·일·걸린 분·종료 코드·벗어남 수). 종료 코드는 sim 그대로(0 목표 안 · 1 벗어남), 2 시작 못 함.
"""

from __future__ import annotations

import argparse
import csv
import ctypes
import os
import re
import subprocess
import sys
import tempfile
import time
from datetime import datetime
from pathlib import Path

sys.dont_write_bytecode = True

ROOT = Path(__file__).resolve().parents[1]
CLI = ROOT / "packages" / "game_cli"
LOCK = Path(tempfile.gettempdir()) / "pirate-dot-heavy.lock"
EXE = Path(tempfile.gettempdir()) / ("game_cli.exe" if os.name == "nt" else "game_cli")
LOG = ROOT / "build" / "nightly" / "log.csv"


def free_gb() -> float | None:
    """남은 물리 메모리(GB). Windows만, 모르면 None."""
    if os.name != "nt":
        return None

    class _Mem(ctypes.Structure):
        _fields_ = [
            ("dwLength", ctypes.c_ulong),
            ("dwMemoryLoad", ctypes.c_ulong),
            ("ullTotalPhys", ctypes.c_ulonglong),
            ("ullAvailPhys", ctypes.c_ulonglong),
            ("ullTotalPageFile", ctypes.c_ulonglong),
            ("ullAvailPageFile", ctypes.c_ulonglong),
            ("ullTotalVirtual", ctypes.c_ulonglong),
            ("ullAvailVirtual", ctypes.c_ulonglong),
            ("ullAvailExtendedVirtual", ctypes.c_ulonglong),
        ]

    m = _Mem()
    m.dwLength = ctypes.sizeof(_Mem)
    if not ctypes.windll.kernel32.GlobalMemoryStatusEx(ctypes.byref(m)):  # type: ignore[attr-defined]
        return None
    return m.ullAvailPhys / 1024**3


def pick_players(players: int, free: float | None, min_free: float) -> tuple[int, str | None]:
    """메모리가 모자라면 반으로(최소 10). (플레이어 수, 리포트에 적을 메모)."""
    if free is None or free >= min_free or players <= 10:
        return players, None
    n = max(10, players // 2)
    return n, f"메모리 부족(남은 {free:.1f}GB < {min_free:g}GB)으로 {players}명 → {n}명"


def off_target(report: str) -> list[str]:
    """리포트 표에서 판정이 '벗어남'인 지표 이름."""
    out = []
    for line in report.splitlines():
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if len(cells) >= 4 and cells[-1] == "벗어남":
            out.append(cells[0])
    return out


def note_on_top(report: str, note: str) -> str:
    """생성 주석 줄 바로 아래에 메모 한 줄(인용)을 넣는다."""
    lines = report.splitlines(keepends=True)
    at = 1 if lines and lines[0].startswith("<!--") else 0
    return "".join(lines[:at] + [f"\n> {note}\n"] + lines[at:])


def sim_args(players: int, days: int, report: Path, seed: int) -> list[str]:
    return [
        "sim",
        "--seed",
        str(seed),
        "--players",
        str(players),
        "--days",
        str(days),
        "--schedule",
        "daily",
        "--report",
        str(report),
    ]


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--players", type=int, default=100)
    ap.add_argument("--days", type=int, default=30)
    ap.add_argument("--seed", type=int, default=1)
    ap.add_argument("--report", type=Path, default=ROOT / "docs" / "balance" / "nightly-30d.md")
    ap.add_argument("--min-free-gb", type=float, default=4.0)
    ap.add_argument("--no-compile", action="store_true", help="이미 컴파일한 exe를 쓴다")
    ap.add_argument("--dry-run", action="store_true")
    a = ap.parse_args(argv)

    players, note = pick_players(a.players, free_gb(), a.min_free_gb)
    compile_cmd = ["dart", "compile", "exe", "bin/game_cli.dart", "-o", str(EXE)]
    run_cmd = [str(EXE), *sim_args(players, a.days, a.report, a.seed)]
    if a.dry_run:
        print("잠금:", LOCK, "(있음 — 시작 안 함)" if LOCK.exists() else "(없음)")
        if note:
            print(note)
        if not a.no_compile:
            print("(packages/game_cli)", " ".join(compile_cmd))
        print(" ".join(run_cmd))
        return 0
    if LOCK.exists():
        print(f"다른 무거운 일이 도는 중(잠금 {LOCK}: {LOCK.read_text(encoding='utf-8').strip()}) — 시작하지 않는다.")
        return 2
    LOCK.write_text(f"nightly_sim {datetime.now():%Y-%m-%d %H:%M} pid {os.getpid()}", encoding="utf-8")
    try:
        if not a.no_compile and subprocess.call(compile_cmd, cwd=CLI, shell=os.name == "nt") != 0:
            print("game_cli 컴파일 실패")
            return 2
        if note:
            print(note)
        start = time.monotonic()
        code = subprocess.call(run_cmd, cwd=ROOT)
        minutes = (time.monotonic() - start) / 60
    finally:
        LOCK.unlink(missing_ok=True)

    misses: list[str] = []
    if a.report.exists():
        text = a.report.read_text(encoding="utf-8")
        if note:
            a.report.write_text(note_on_top(text, note), encoding="utf-8", newline="\n")
        misses = off_target(text)
    LOG.parent.mkdir(parents=True, exist_ok=True)
    new = not LOG.exists()
    with LOG.open("a", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        if new:
            w.writerow(["time", "players", "days", "minutes", "exit", "off_target"])
        w.writerow([f"{datetime.now():%Y-%m-%d %H:%M}", players, a.days, f"{minutes:.1f}", code, len(misses)])
    print(f"끝: {minutes:.1f}분 · 종료 코드 {code} · 벗어남 {len(misses)}" + (f" — {', '.join(misses)}" if misses else ""))
    print(f"리포트 {a.report.relative_to(ROOT) if a.report.is_relative_to(ROOT) else a.report} · 기록 {LOG.relative_to(ROOT)}")
    return code


if __name__ == "__main__":
    sys.exit(main())
