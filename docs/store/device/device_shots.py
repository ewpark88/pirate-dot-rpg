"""실기기(USB) 화면 자동 캡처: 설치 → 실행 → 탭 4개 + 퀘스트 시트·설정 화면 → 스크린샷 → build/device/shots/.

    python -I -B docs/store/device/device_shots.py                     # 이미 설치된 앱으로 실행·캡처
    python -I -B docs/store/device/device_shots.py --apk build/app/outputs/flutter-apk/app-profile.apk
    python -I -B docs/store/device/device_shots.py --build             # flutter build apk --profile 후 설치·캡처
    python -I -B docs/store/device/device_shots.py --serial R5CT... --wait 8

안전 규칙: **잠금 해제·비밀번호·문자 입력은 절대 자동으로 하지 않는다.** 누르기·BACK 전에는 **매번 우리 앱이 맨 앞인지**
확인하고, 아니면 바로 멈춘다(2026-10-15 사고: 앱이 뒤에 있는데 눌러 홈의 전화 앱을 연 적이 있다 — 통화는 걸리지 않았다). 화면이 꺼져 있거나 잠겨 있으면 안내하고 끝낸다.
보내는 입력은 우리 앱 화면 누르기(input tap)와 설정 화면을 닫는 뒤로 키(KEYCODE_BACK) 하나뿐이다. 앱 데이터(세이브)를 지우는 일도 하지 않는다 —
서명이 달라 설치가 실패하면 지우고 다시 깔지 사람에게 묻는다(--reinstall을 줄 때만 adb uninstall).

탭·상단 바 위치: uiautomator 덤프에서 이름으로 찾고, 실패하면(Flame 게임은 늘 움직여 실기기에서 덤프가 실패한다)
앱 배치 규칙으로 계산한다 — 상태 바·내비게이션 바 틀(dumpsys window)과 화면 밀도(wm density)로 dp → px.
시작 직후 창(복귀 보상)이 떠 있으면 그림으로 알아채 '받기'를 누르고, 남으면 BACK 1회. 캡처가 앞 화면과 같으면 경고.
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
# 상단 바 버튼 (배치 v2) — 접근성 라벨 = ARB uiDailyTooltip·uiSettingsTitle. 못 찾으면 그 화면은 건너뛴다.
BUTTONS = [("quest", ("퀘스트·출석", "Quests & Attendance")), ("settings", ("설정", "Settings"))]
KEYCODE_BACK = "4"


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


def tab_centers(xml: str, targets=TABS, bottom: bool = True) -> dict[str, tuple[int, int]]:
    """uiautomator 덤프에서 이름이 든 노드의 가운데 좌표. 같은 이름이 여럿이면 [bottom]이면 맨 아래(탭 바), 아니면 맨 위(상단 바)."""
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
        for key, names in targets:
            if any(n in lines for n in names):
                c = ((x1 + x2) // 2, (y1 + y2) // 2)
                if key not in found or (c[1] > found[key][1]) == bottom:
                    found[key] = c
    return found


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


def parse_bars(window: str, height: int) -> tuple[int, int]:
    """dumpsys window의 statusBars·navigationBars 틀 → (상태 바 아래 y, 내비게이션 바 위 y). 못 읽으면 (0, height)."""
    top, bottom = 0, height
    m = re.search(r"statusBars[^\n]*?frame=\[\d+,\d+\]\[\d+,(\d+)\]", window)
    if m:
        top = int(m.group(1))
    m = re.search(r"navigationBars[^\n]*?frame=\[\d+,(\d+)\]\[\d+,\d+\]", window)
    if m:
        bottom = int(m.group(1))
    return top, bottom


def parse_dpr(out: str) -> float:
    """`wm density` → 논리 픽셀 배율 (Override가 있으면 그것)."""
    m = re.search(r"Override density: (\d+)", out) or re.search(r"Physical density: (\d+)", out)
    return int(m.group(1)) / 160 if m else 2.75


def layout_centers(width: int, dpr: float, status_bottom: int, nav_top: int, tab_y: int | None):
    """덤프가 없을 때 앱 배치 규칙(배치 v2)으로: 상단 바 48dp(상태 바 바로 아래, 오른쪽 끝 설정·그 왼쪽 퀘스트, 48dp씩),
    탭 바는 내비게이션 바 바로 위(탭 4등분, 가운데 높이 = 내비게이션 바 위 28dp)."""
    y = tab_y if tab_y is not None else nav_top - round(28 * dpr)
    tabs = {key: (round(width * (i + 0.5) / len(TABS)), y) for i, (key, _) in enumerate(TABS)}
    top = status_bottom + round(24 * dpr)
    buttons = {"settings": (width - round(24 * dpr), top), "quest": (width - round(72 * dpr), top)}
    return tabs, buttons


# 화면 판단은 그림으로 (Flame 게임은 계속 움직여 uiautomator 덤프가 "null root node"로 실패한다).
NAVY_DARK = (12, 15, 28)  # 상단 바 바탕 (ui PixelPalette.navyDark)
ACTION = (46, 120, 190)  # 기본(primary) 버튼 바탕 (PixelPalette.action)


def _image(png: bytes):
    try:
        import io

        from PIL import Image

        return Image.open(io.BytesIO(png)).convert("RGB")
    except Exception:  # noqa: BLE001 — 그림이 아니면 판단을 건너뛴다
        return None


def has_scrim(img, status_bottom: int, dpr: float) -> bool:
    """창이 떠 있으면 뒤 화면이 어두운 막에 덮여 상단 바 바탕(12,15,28)이 더 어두워진다(기본 막 54% 검정 → 약 (6,7,13))."""
    if img is None:
        return False
    y = status_bottom + round(3 * dpr)
    px = [img.getpixel((x, y)) for x in range(2, 14, 3)]
    blue = sorted(p[2] for p in px)[len(px) // 2]
    return blue <= 18  # 평소 27, 막이 덮으면 약 12


def is_action_blue(p) -> bool:
    """기본 버튼 파랑 (팔레트 action (46,120,190), 실기기 캡처 (67,118,185)). 막 아래로 어두워진 버튼(B≈85)·하늘색 하이라이트(G 194)는 아니다."""
    r, g, b = p
    return b >= 160 and b - r >= 90 and 90 <= g <= 150


def find_primary(img):
    """막 위로 밝게 남은 기본 버튼(파랑)의 가운데. 막 아래 버튼은 어두워져 안 걸린다. 없으면 None."""
    if img is None:
        return None
    pts = [(x, y) for y in range(0, img.height, 6) for x in range(0, img.width, 6) if is_action_blue(img.getpixel((x, y)))]
    if len(pts) < 20:
        return None
    xs, ys = sorted(p[0] for p in pts), sorted(p[1] for p in pts)
    return xs[len(xs) // 2], ys[len(ys) // 2]


def same_screen(a, b, top: int, bottom: int) -> bool:
    """탭 내용 영역(전장 아래 ~ 탭 바 위)이 거의 같으면 True — 누르기가 안 먹었을 수 있다. 전장은 늘 움직여 뺀다."""
    if a is None or b is None or a.size != b.size:
        return False
    box = (0, top, a.width, bottom)
    sa, sb = a.crop(box).convert("L").resize((54, 60)), b.crop(box).convert("L").resize((54, 60))
    diff = sum(abs(x - y) for x, y in zip(sa.tobytes(), sb.tobytes())) / (54 * 60)
    return diff < 2.0


def in_front(activities: str) -> bool:
    """`dumpsys activity activities`의 topResumedActivity가 우리 앱인가."""
    m = re.search(r"topResumedActivity=[^\n]*", activities)
    return bool(m) and PACKAGE + "/" in m.group(0)


def capture(adb: Adb, out_dir: Path, *, wait: float, tab_y: int | None, sleep=time.sleep) -> list[Path]:
    window = adb("shell", "dumpsys", "window")
    state = screen_state(adb("shell", "dumpsys", "power"), window)
    if state != "awake":
        raise DeviceError("폰 화면이 꺼져 있거나 잠겨 있다 — 사람이 잠금을 풀고 화면을 켠 뒤 다시 실행한다(자동 잠금 해제는 하지 않는다).")
    def front() -> bool:
        return in_front(adb("shell", "dumpsys", "activity", "activities", check=False))

    def launch() -> None:
        """우리 앱을 앞으로. [wait]+5초 안에 앞에 안 오면 멈춘다."""
        adb("shell", "am", "start", "-n", ACTIVITY)
        sleep(wait)
        for _ in range(10):
            if front():
                return
            sleep(0.5)
        raise DeviceError("우리 앱이 앞에 오지 않는다 — 멈춤(다른 앱을 누르지 않는다). 폰에서 앱을 직접 열고 다시 실행한다.")

    def tap(x: int, y: int) -> None:
        # 누르기 전에 매번 확인: 우리 앱이 앞에 없으면 절대 누르지 않는다(홈·전화 앱 등을 누르는 사고 방지).
        if not front():
            raise DeviceError("우리 앱이 앞에 없다 — 누르기를 멈춘다(다른 앱을 누르지 않는다).")
        adb("shell", "input", "tap", str(x), str(y))

    def back() -> None:
        if not front():
            raise DeviceError("우리 앱이 앞에 없다 — BACK을 보내지 않고 멈춘다.")
        adb("shell", "input", "keyevent", KEYCODE_BACK)

    launch()
    width, height = parse_size(adb("shell", "wm", "size"))
    dpr = parse_dpr(adb("shell", "wm", "density"))
    status_bottom, nav_top = parse_bars(window, height)
    adb("shell", "uiautomator", "dump", "/sdcard/pde_ui.xml", check=False)
    # 덤프는 우리 앱이 앞에 있을 때만 믿는다(아니면 런처의 '설정' 글자 같은 것을 잡는다)
    dump = adb("shell", "cat", "/sdcard/pde_ui.xml", check=False) if front() else ""
    adb("shell", "rm", "-f", "/sdcard/pde_ui.xml", check=False)
    found_tabs, found_buttons = tab_centers(dump), tab_centers(dump, BUTTONS, bottom=False)
    rule_tabs, rule_buttons = layout_centers(width, dpr, status_bottom, nav_top, tab_y)
    tabs = found_tabs if len(found_tabs) == len(TABS) else rule_tabs
    buttons = {k: found_buttons.get(k, rule_buttons[k]) for k, _ in BUTTONS}
    snap = lambda: adb("exec-out", "screencap", "-p", binary=True)  # noqa: E731

    out_dir.mkdir(parents=True, exist_ok=True)
    # 시작 화면은 00_start.png로 남겨 판단 근거를 확인할 수 있게 한다.
    (out_dir / "00_start.png").write_bytes(snap())

    def clear_dialog() -> None:
        """창(복귀 보상 등)이 떠 있으면: 밝은 기본 버튼(받기)을 누르고, 그래도 남으면 BACK 1회. 광고 버튼은 누르지 않는다.
        복귀 창은 앱이 1분 넘게 뒤에 있다 돌아오면 조금 늦게 뜨므로 **캡처마다** 확인한다."""
        for attempt in range(2):
            img = _image(snap())
            if not has_scrim(img, status_bottom, dpr):
                return
            target = find_primary(img) if attempt == 0 else None
            if target:
                print(f"창: 기본 버튼 누름 {target}")
                tap(*target)
            else:
                print("창: BACK")
                back()
                sleep(1.0)
                # 오판으로 BACK이 앱을 닫았으면 다시 연다 (세이브는 그대로)
                if not front():
                    print("앱이 뒤로 갔다 — 다시 연다")
                    launch()
            sleep(1.5)
        if has_scrim(_image(snap()), status_bottom, dpr):
            print("경고: 창이 아직 떠 있다 — 캡처가 가려질 수 있다")

    shots: list[Path] = []
    content = (round(height * 0.45), nav_top - round(64 * dpr))
    prev = None

    def save(name: str) -> bool:
        """캡처를 저장하고, 앞 화면에서 바뀌었는지 돌려준다(그림을 못 읽으면 바뀐 것으로 본다)."""
        nonlocal prev
        png = snap()
        path = out_dir / name
        path.write_bytes(png)
        shots.append(path)
        img = _image(png)
        same = same_screen(prev, img, *content)
        if same:
            print(f"경고: {name}이(가) 앞 화면과 같다 — 누르기가 안 먹었을 수 있다")
        prev = img
        return not same

    for i, (key, _) in enumerate(TABS):
        clear_dialog()
        tap(*tabs[key])
        sleep(1.2)
        save(f"{i + 1:02d}_{key}.png")
    tap(*tabs["voyage"])  # 항해로 돌려놓기
    sleep(1.0)
    # 상단 바: 퀘스트 시트(바깥 위쪽을 눌러 닫음) · 설정 화면(뒤로 키로 닫음 — 보내는 키는 BACK뿐)
    for i, (key, _) in enumerate(BUTTONS, start=len(TABS) + 1):
        clear_dialog()
        prev = _image(snap())  # 누르기 바로 전 화면과 비교
        tap(*buttons[key])
        sleep(1.2)
        if not save(f"{i:02d}_{key}.png"):
            # 열리지 않았는데 BACK을 보내면 첫 화면에서 앱이 닫힌다(2026-10-15 실기기) → 닫기 동작을 건너뛴다
            print(f"건너뜀: {key}이(가) 열리지 않아 닫기 동작을 보내지 않음")
            continue
        if key == "quest":
            tap(width // 2, status_bottom + round(80 * dpr))
        else:
            back()
        sleep(1.0)
    how = "덤프" if tabs is found_tabs else f"배치 규칙(dpr {dpr:.4g}, 상태 바 {status_bottom}, 내비 {nav_top})"
    print(f"탭 좌표: {how} {tabs} · 상단 바 {buttons}")
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
    ap.add_argument("--tab-y", type=int, help="탭을 누를 높이(px) — 배치 규칙 계산이 틀릴 때")
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
