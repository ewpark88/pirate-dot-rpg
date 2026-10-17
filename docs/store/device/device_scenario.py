"""실기기 시나리오(docs/store/release-regression.md 자동 부분): JSON 단계 목록을 device_loop 안전 규칙대로 차례로 돌린다.

    python -I -B docs/store/device/device_scenario.py docs/store/device/scenarios/smoke.json [--serial R3CX…]

단계(`steps`의 한 줄): {"do": "shot", "name": "01"} · {"do": "tap", "fx": 0.5, "fy": 0.9, "times": 1} · {"do": "swipe", "fx1": …,
"fy1": …, "fx2": …, "fy2": …, "ms": 300} · {"do": "back"} · {"do": "wait", "sec": 30} · {"do": "crash"} ·
{"do": "front", "expect": true|false}. 좌표는 화면 비율(0~1 — 기기마다 `wm size`로 픽셀로 바꾼다).
**안전**(DEVICE_LOOP 2절, device_loop.py 그대로): 입력마다 우리 앱이 맨 앞인지 보고, 아니면 그 자리에서 멈춘다(종료 3).
첫 입력 전엔 사용자가 60초 안에 폰을 만졌는지도 본다(플레이 중이면 멈춤). 입력은 우리 앱 화면 누르기·끌기·뒤로뿐 — 설치·실행·
다른 앱 조작 없음. 크래시 줄(우리 앱)이 새로 생기면 실패(종료 1). 결과는 build/device/loop/<세션>/scenario.md.
종료 코드: 0 통과 · 1 크래시/기대 어긋남 · 2 기기 문제 · 3 멈춤(앱이 맨 앞 아님·사용자 사용 중).
"""

from __future__ import annotations

import argparse
import json
import re
import sys
import time
from pathlib import Path

sys.dont_write_bytecode = True
sys.stdout.reconfigure(encoding="utf-8")
sys.path.insert(0, str(Path(__file__).resolve().parent))
from device_loop import KEYCODE_BACK, Device, session_dir  # noqa: E402
from device_shots import PACKAGE, DeviceError  # noqa: E402


def screen_size(wm: str) -> tuple[int, int]:
    """`wm size` 출력 → (폭, 높이). Override가 있으면 그것(마지막 줄)."""
    found = re.findall(r"(\d+)x(\d+)", wm)
    if not found:
        raise ValueError(f"wm size를 못 읽음: {wm!r}")
    w, h = found[-1]
    return int(w), int(h)


def px(size: tuple[int, int], fx: float, fy: float) -> tuple[int, int]:
    if not (0 <= fx <= 1 and 0 <= fy <= 1):
        raise ValueError(f"좌표는 화면 비율 0~1: {fx}, {fy}")
    return round(size[0] * fx), round(size[1] * fy)


def crash_lines(log: str) -> list[str]:
    return [ln for ln in log.splitlines() if PACKAGE in ln]


def run(steps: list[dict], d, log: list[str], sleep=time.sleep) -> int:
    """[d]는 Device(또는 시험용 가짜): sh·ours_front·idle·shot·guard. 결과 줄을 [log]에 쌓는다."""
    size = screen_size(d.sh("wm", "size"))
    seen = set(crash_lines(d.sh("logcat", "-b", "crash", "-d")))
    first_input = True
    for i, st in enumerate(steps, 1):
        kind = st["do"]
        try:
            if kind in ("tap", "swipe", "back"):
                d.guard(fresh=first_input)
                first_input = False
            if kind == "tap":
                x, y = px(size, st["fx"], st["fy"])
                times = int(st.get("times", 1))
                d.sh(f"input tap {x} {y}" + "".join(f"; sleep 0.15; input tap {x} {y}" for _ in range(times - 1)))
            elif kind == "swipe":
                x1, y1 = px(size, st["fx1"], st["fy1"])
                x2, y2 = px(size, st["fx2"], st["fy2"])
                d.sh("input", "swipe", str(x1), str(y1), str(x2), str(y2), str(st.get("ms", 300)))
            elif kind == "back":
                d.sh("input", "keyevent", KEYCODE_BACK)
            elif kind == "wait":
                sleep(float(st["sec"]))
            elif kind == "shot":
                d.shot(session_dir() / f"{st['name']}.png")
            elif kind == "front":
                if d.ours_front() != bool(st["expect"]):
                    log.append(f"{i}. front 기대 {st['expect']} — 어긋남")
                    return 1
            elif kind == "crash":
                new = [ln for ln in crash_lines(d.sh("logcat", "-b", "crash", "-d")) if ln not in seen]
                if new:
                    log.append(f"{i}. 크래시 {len(new)}줄")
                    log.extend(new[-20:])
                    return 1
            else:
                raise ValueError(f"모르는 단계 {kind}")
        except SystemExit as stop:  # device_loop.guard — 앱이 맨 앞 아님·사용자 사용 중
            log.append(f"{i}. {kind} 전에 멈춤")
            return int(stop.code or 3)
        log.append(f"{i}. {kind} ok {st.get('note', '')}".rstrip())
    return 0


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("scenario", type=Path)
    ap.add_argument("--serial")
    a = ap.parse_args(argv)
    spec = json.loads(a.scenario.read_text(encoding="utf-8"))
    try:
        d = Device(a.serial)
    except DeviceError as e:
        print(e)
        return 2
    log: list[str] = []
    code = run(spec["steps"], d, log)
    out = session_dir() / "scenario.md"
    out.parent.mkdir(parents=True, exist_ok=True)
    verdict = {0: "통과", 1: "실패", 3: "멈춤"}.get(code, str(code))
    out.write_text(f"# {spec.get('name', a.scenario.stem)} — {verdict}\n\n" + "\n".join(f"- {ln}" for ln in log) + "\n",
                   encoding="utf-8")
    print(out.read_text(encoding="utf-8"))
    return code


if __name__ == "__main__":
    sys.exit(main())
