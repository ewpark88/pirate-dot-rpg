"""PB UI 키트(쿵푸할매 스타일 개편, docs/plans/active/design-kungfu-style.md) — Pirate Busters 자체 IP SVG를 PNG @1x·2x·3x로. OWN.

    python -I tools/art/gen_ui_kit.py            # apps/game/assets/ui/kit/{,2.0x/,3.0x/}*.png 에 쓴다 + LICENSES.json
    python -I tools/art/gen_ui_kit.py --check    # 쓰지 않고, 결과가 지금 파일과 다르면 실패

원본: D:/Projects/pirate-busters/art/pb_v0.24_main/ui/kit/*.svg (없으면 저장소에 둔 사본 tools/art/pb_ui_kit/*.svg).
키트 SVG는 단순 도형(둥근 rect·circle·M/L/H/V/Q 경로·opacity)뿐이라 여기서 직접 그린다(cairo 없음).
숨은 요소(display none 글자·opacity 0 묶음 — PB의 상태별 레이어)는 그리지 않는다. 4배로 그려 줄여서(LANCZOS) 매끈하다.
Flutter 해상도 변형 규칙: kit/x.png(1x) · kit/2.0x/x.png · kit/3.0x/x.png — 화면은 Image.asset('assets/ui/kit/x.png') 하나로 쓴다.
9-slice(centerSlice) 기준은 KIT 표의 slice(1x 픽셀).
"""

from __future__ import annotations

import io
import json
import math
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

from PIL import Image, ImageDraw

sys.dont_write_bytecode = True

ROOT = Path(__file__).resolve().parents[2]
ASSETS = ROOT / "apps" / "game" / "assets"
PB = Path("D:/Projects/pirate-busters/art/pb_v0.24_main/ui/kit")
COPY = ROOT / "tools" / "art" / "pb_ui_kit"
SOURCE = "Pirate Busters v0.24 자체 IP ui/kit SVG → tools/art/gen_ui_kit.py 코드 래스터화"
NAMES = ["button_gold", "button_primary", "button_secondary", "panel", "tab_active", "tab_idle", "chip", "badge_frame"]
SCALES = {"": 1, "2.0x/": 2, "3.0x/": 3}
SS = 4  # 슈퍼샘플
NS = "{http://www.w3.org/2000/svg}"


def _color(v: str | None, alpha: float) -> tuple[int, int, int, int] | None:
    if v is None or v == "none":
        return None
    v = v.lstrip("#")
    if len(v) == 3:
        v = "".join(c * 2 for c in v)
    r, g, b = int(v[0:2], 16), int(v[2:4], 16), int(v[4:6], 16)
    return (r, g, b, round(255 * max(0.0, min(1.0, alpha))))


def _f(e: ET.Element, k: str, d: float = 0.0) -> float:
    v = e.get(k)
    return float(v) if v is not None else d


def _transform(t: str | None) -> tuple[float, float, float]:
    """translate(x y) / scale(s) 조합만(키트에 쓰인 것)."""
    tx = ty = 0.0
    s = 1.0
    for kind, args in re.findall(r"(translate|scale)\(([^)]*)\)", t or ""):
        n = [float(x) for x in re.split(r"[ ,]+", args.strip()) if x]
        if kind == "translate":
            tx += n[0] * s
            ty += (n[1] if len(n) > 1 else 0) * s
        else:
            s *= n[0]
    return tx, ty, s


def _path_points(d: str) -> list[list[tuple[float, float]]]:
    """M L H V Q(+소문자 상대) Z → 꺾은선(2차 곡선은 8조각). 하위 경로마다 한 목록."""
    toks = re.findall(r"[MLHVQZmlhvqz]|-?\d*\.?\d+(?:e-?\d+)?", d)
    out: list[list[tuple[float, float]]] = []
    cur: list[tuple[float, float]] = []
    x = y = 0.0
    i = 0
    cmd = ""
    while i < len(toks):
        if re.match(r"[A-Za-z]", toks[i]):
            cmd = toks[i]
            i += 1
            if cmd in "Zz":
                if cur:
                    out.append(cur)
                cur = []
                continue
        rel = cmd.islower()
        c = cmd.upper()

        def num() -> float:
            nonlocal i
            v = float(toks[i])
            i += 1
            return v

        if c == "M":
            if cur:
                out.append(cur)
            nx, ny = num(), num()
            x, y = (x + nx, y + ny) if rel else (nx, ny)
            cur = [(x, y)]
            cmd = "l" if rel else "L"
        elif c == "L":
            nx, ny = num(), num()
            x, y = (x + nx, y + ny) if rel else (nx, ny)
            cur.append((x, y))
        elif c == "H":
            n = num()
            x = x + n if rel else n
            cur.append((x, y))
        elif c == "V":
            n = num()
            y = y + n if rel else n
            cur.append((x, y))
        elif c == "Q":
            cx, cy, ex, ey = num(), num(), num(), num()
            if rel:
                cx, cy, ex, ey = x + cx, y + cy, x + ex, y + ey
            for k in range(1, 9):
                u = k / 8
                cur.append(((1 - u) ** 2 * x + 2 * (1 - u) * u * cx + u * u * ex, (1 - u) ** 2 * y + 2 * (1 - u) * u * cy + u * u * ey))
            x, y = ex, ey
        else:
            raise ValueError(f"키트에 없던 경로 명령 {cmd}")
    if cur:
        out.append(cur)
    return out


def _draw(el: ET.Element, img: Image.Image, k: float, ox: float, oy: float, s: float, op: float) -> None:
    tag = el.tag.replace(NS, "")
    if el.get("display") == "none" or tag in ("defs", "text", "clipPath", "filter"):
        return
    op *= _f(el, "opacity", 1.0)
    if op <= 0:
        return
    if tag in ("g", "svg"):
        tx, ty, ts = _transform(el.get("transform"))
        for c in el:
            _draw(c, img, k, ox + tx * s, oy + ty * s, s * ts, op)
        return
    fill = _color(el.get("fill", "#000"), op * _f(el, "fill-opacity", 1.0))
    stroke = _color(el.get("stroke"), op * _f(el, "stroke-opacity", 1.0))
    sw = _f(el, "stroke-width", 1.0) * s * k
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    P = lambda px, py: ((ox + px * s) * k, (oy + py * s) * k)  # noqa: E731
    if tag == "rect":
        x0, y0 = P(_f(el, "x"), _f(el, "y"))
        x1, y1 = P(_f(el, "x") + _f(el, "width"), _f(el, "y") + _f(el, "height"))
        rx = _f(el, "rx") * s * k
        d.rounded_rectangle([x0, y0, x1, y1], radius=rx, fill=fill, outline=stroke, width=max(1, round(sw)) if stroke else 0)
    elif tag == "circle":
        cx, cy = P(_f(el, "cx"), _f(el, "cy"))
        r = _f(el, "r") * s * k
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=fill, outline=stroke, width=max(1, round(sw)) if stroke else 0)
    elif tag == "path":
        subs = [[P(px, py) for px, py in sp] for sp in _path_points(el.get("d", ""))]
        closed = "z" in el.get("d", "").lower()
        for sp in subs:
            if closed and fill and len(sp) > 2:
                d.polygon(sp, fill=fill)
            if stroke:
                pts = sp + [sp[0]] if closed else sp
                d.line(pts, fill=stroke, width=max(1, round(sw)), joint="curve")
    else:
        return
    img.alpha_composite(layer)


def render(svg: str, scale: int) -> bytes:
    root = ET.fromstring(svg)
    w, h = round(_f(root, "width")), round(_f(root, "height"))
    k = scale * SS
    big = Image.new("RGBA", (w * k, h * k), (0, 0, 0, 0))
    for c in root:
        _draw(c, big, k, 0, 0, 1, 1.0)
    img = big.resize((w * scale, h * scale), Image.LANCZOS)
    buf = io.BytesIO()
    img.save(buf, "PNG", optimize=True)
    return buf.getvalue()


def main(argv: list[str]) -> int:
    for stream in (sys.stdout, sys.stderr):
        stream.reconfigure(encoding="utf-8")
    check = "--check" in argv
    src = PB if PB.is_dir() else COPY
    lic_path = ASSETS / "LICENSES.json"
    lic = json.loads(lic_path.read_text(encoding="utf-8"))
    files = dict(lic.get("files", {}))
    changed = []
    for name in NAMES:
        svg = (src / f"{name}.svg").read_text(encoding="utf-8")
        if src == PB:
            COPY.mkdir(parents=True, exist_ok=True)
            if not check:
                (COPY / f"{name}.svg").write_text(svg, encoding="utf-8", newline="\n")
        for sub, sc in SCALES.items():
            rel = f"ui/kit/{sub}{name}.png"
            data = render(svg, sc)
            target = ASSETS / rel
            if not (target.is_file() and target.read_bytes() == data):
                changed.append(rel)
                if not check:
                    target.parent.mkdir(parents=True, exist_ok=True)
                    target.write_bytes(data)
            files[rel] = {"source": SOURCE, "license": "OWN"}
    text = json.dumps({**lic, "files": dict(sorted(files.items()))}, ensure_ascii=False, indent=2) + "\n"
    lic_changed = lic_path.read_text(encoding="utf-8") != text
    if check:
        if changed or lic_changed:
            print(f"✗ UI 키트가 다름: {changed or 'LICENSES.json'}", file=sys.stderr)
            return 1
        print("✓ UI 키트가 같다")
        return 0
    if lic_changed:
        lic_path.write_text(text, encoding="utf-8", newline="\n")
    print(f"✓ ui/kit {len(NAMES)}종 × 3배율 — 바뀐 파일 {len(changed)}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
