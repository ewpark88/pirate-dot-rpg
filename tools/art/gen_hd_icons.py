"""HD 광택 아이콘 생성기 — 실행: python tools/art/gen_hd_icons.py (디자인 개편 ② — 쿵푸할매 서바이버 스타일, 코드 SVG → PNG).

스타일 규칙: viewBox 64, 굵은 검정 외곽선(OL = 4), 색은 위 밝음 → 아래 진함 그라디언트, 위쪽 흰 광택(반투명),
작은 반짝이 하나. 바탕 투명. resvg_py로 32·64·96px PNG.
"""
import io
import os
import sys

import resvg_py
from PIL import Image

OL = 4
INK = '#1b1626'


def grad(gid, top, bottom):
    return (f'<linearGradient id="{gid}" x1="0" y1="0" x2="0" y2="1">'
            f'<stop offset="0" stop-color="{top}"/><stop offset="1" stop-color="{bottom}"/></linearGradient>')


def rgrad(gid, inner, outer):
    return (f'<radialGradient id="{gid}" cx="0.4" cy="0.35" r="0.7">'
            f'<stop offset="0" stop-color="{inner}"/><stop offset="1" stop-color="{outer}"/></radialGradient>')


def svg(defs, body):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64"><defs>{defs}</defs>'
            f'<g stroke-linejoin="round" stroke-linecap="round">{body}</g></svg>')


def shine(x, y, rx=7, ry=4, rot=-30, a=0.75):
    return f'<ellipse cx="{x}" cy="{y}" rx="{rx}" ry="{ry}" transform="rotate({rot} {x} {y})" fill="#fff" opacity="{a}"/>'


def sparkle(x, y, s=5):
    return (f'<path d="M{x} {y-s} Q{x+1} {y-1} {x+s} {y} Q{x+1} {y+1} {x} {y+s} Q{x-1} {y+1} {x-s} {y} Q{x-1} {y-1} {x} {y-s}Z" '
            f'fill="#fff"/>')


def star_path(cx, cy, r1, r2, n=5, rot=-90):
    import math
    pts = []
    for i in range(n * 2):
        r = r1 if i % 2 == 0 else r2
        a = math.radians(rot + i * 180 / n)
        pts.append(f'{cx + r * math.cos(a):.2f} {cy + r * math.sin(a):.2f}')
    return 'M' + ' L'.join(pts) + 'Z'


ICONS = {}


def icon(fn):
    ICONS[fn.__name__] = fn
    return fn


@icon
def coin():
    return svg(grad('g', '#ffe066', '#e89a12'),
               f'<circle cx="32" cy="33" r="25" fill="#b86e00" stroke="{INK}" stroke-width="{OL}"/>'
               f'<circle cx="32" cy="30" r="24" fill="url(#g)" stroke="{INK}" stroke-width="{OL}"/>'
               f'<circle cx="32" cy="30" r="16" fill="none" stroke="#c77d00" stroke-width="3"/>'
               f'<path d="{star_path(32, 30, 10, 4.5)}" fill="#fff3b0" stroke="#c77d00" stroke-width="2"/>'
               + shine(21, 17, 8, 4) + sparkle(50, 13, 5))


@icon
def gem():
    return svg(grad('g', '#7ee8ff', '#1f6fe0'),
               f'<path d="M14 24 L24 12 H40 L50 24 L32 54 Z" fill="url(#g)" stroke="{INK}" stroke-width="{OL}"/>'
               f'<path d="M14 24 H50 M24 12 L28 24 L32 54 M40 12 L36 24 L32 54" fill="none" stroke="#1a4fa8" stroke-width="2"/>'
               f'<path d="M24 12 H40 L36 24 H28 Z" fill="#c9f6ff" opacity="0.9"/>'
               + shine(22, 20, 5, 3) + sparkle(50, 12, 5))


@icon
def star():
    return svg(grad('g', '#fff07a', '#f2a000'),
               f'<path d="{star_path(32, 34, 26, 12)}" fill="url(#g)" stroke="{INK}" stroke-width="{OL}"/>'
               + shine(26, 22, 6, 3.5) + sparkle(52, 12, 4))


@icon
def gear():
    import math
    teeth = []
    for i in range(8):
        a = math.radians(i * 45)
        x, y = 32 + 22 * math.cos(a), 32 + 22 * math.sin(a)
        teeth.append(f'<rect x="{x-6}" y="{y-6}" width="12" height="12" rx="3" transform="rotate({i*45} {x} {y})" '
                     f'fill="url(#g)" stroke="{INK}" stroke-width="{OL}"/>')
    return svg(grad('g', '#e6edf7', '#7d8ba3'),
               ''.join(teeth) +
               f'<circle cx="32" cy="32" r="19" fill="url(#g)" stroke="{INK}" stroke-width="{OL}"/>'
               f'<circle cx="32" cy="32" r="8" fill="#3a4258" stroke="{INK}" stroke-width="{OL}"/>'
               + shine(24, 22, 6, 3))


@icon
def quest():
    return svg(grad('g', '#ffe9b8', '#e2b56a') + grad('b', '#b97a3c', '#7a4a1e'),
               f'<rect x="12" y="10" width="40" height="48" rx="6" fill="url(#b)" stroke="{INK}" stroke-width="{OL}"/>'
               f'<rect x="17" y="16" width="30" height="37" rx="3" fill="url(#g)" stroke="{INK}" stroke-width="3"/>'
               f'<rect x="24" y="6" width="16" height="9" rx="3" fill="#c9d3e2" stroke="{INK}" stroke-width="3"/>'
               f'<path d="M22 35 L29 42 L43 25" fill="none" stroke="{INK}" stroke-width="9"/>'
               f'<path d="M22 35 L29 42 L43 25" fill="none" stroke="#4be07a" stroke-width="5"/>'
               + shine(18, 15, 4, 2.5))


@icon
def tab_map():
    return svg(grad('g', '#ffeec2', '#e3b26a'),
               f'<path d="M8 16 L22 10 L42 16 L56 10 V48 L42 54 L22 48 L8 54 Z" fill="url(#g)" stroke="{INK}" stroke-width="{OL}"/>'
               f'<path d="M22 10 V48 M42 16 V54" stroke="#b7863e" stroke-width="2"/>'
               f'<path d="M14 40 Q22 30 30 34 T44 26" fill="none" stroke="#8a5a26" stroke-width="2.5" stroke-dasharray="3 4"/>'
               f'<path d="M41 19 L51 29 M51 19 L41 29" stroke="{INK}" stroke-width="8"/>'
               f'<path d="M41 19 L51 29 M51 19 L41 29" stroke="#ff3b3b" stroke-width="4.5"/>'
               + shine(16, 18, 5, 2.5))


@icon
def chest():
    return svg(grad('g', '#c9843f', '#7a4318') + grad('m', '#fff07a', '#e39a00'),
               f'<path d="M8 28 Q8 10 32 10 Q56 10 56 28 Z" fill="url(#g)" stroke="{INK}" stroke-width="{OL}"/>'
               f'<rect x="8" y="28" width="48" height="26" rx="4" fill="url(#g)" stroke="{INK}" stroke-width="{OL}"/>'
               f'<path d="M8 28 H56" stroke="url(#m)" stroke-width="6"/>'
               f'<path d="M8 28 H56" stroke="{INK}" stroke-width="2" opacity="0.6"/>'
               f'<rect x="26" y="23" width="12" height="14" rx="3" fill="url(#m)" stroke="{INK}" stroke-width="3"/>'
               f'<circle cx="32" cy="30" r="2" fill="{INK}"/>'
               + shine(20, 17, 7, 3) + sparkle(52, 10, 5))


@icon
def lock():
    return svg(grad('g', '#ffe27a', '#d98a00'),
               f'<path d="M20 30 V22 Q20 10 32 10 Q44 10 44 22 V30" fill="none" stroke="{INK}" stroke-width="12"/>'
               f'<path d="M20 30 V22 Q20 10 32 10 Q44 10 44 22 V30" fill="none" stroke="#b9c3d4" stroke-width="5"/>'
               f'<rect x="12" y="28" width="40" height="28" rx="6" fill="url(#g)" stroke="{INK}" stroke-width="{OL}"/>'
               f'<path d="M32 38 V46" stroke="{INK}" stroke-width="6"/>'
               f'<circle cx="32" cy="38" r="4" fill="{INK}"/>'
               + shine(20, 33, 5, 2.5))


@icon
def tab_ship():
    return svg(grad('h', '#c9843f', '#6e3b14') + grad('s', '#ffffff', '#d7e2f2'),
               f'<path d="M31 8 V44" stroke="{INK}" stroke-width="7"/><path d="M31 8 V44" stroke="#8a5a26" stroke-width="3"/>'
               f'<path d="M33 10 Q50 22 33 40 Z" fill="url(#s)" stroke="{INK}" stroke-width="{OL}"/>'
               f'<path d="M29 14 Q16 26 29 40 Z" fill="url(#s)" stroke="{INK}" stroke-width="{OL}"/>'
               f'<path d="M30 4 L42 8 L30 12 Z" fill="#ff4b4b" stroke="{INK}" stroke-width="2.5"/>'
               f'<path d="M6 42 H58 L50 56 H14 Z" fill="url(#h)" stroke="{INK}" stroke-width="{OL}"/>'
               f'<path d="M12 48 H52" stroke="#4a2810" stroke-width="2"/>'
               + shine(38, 18, 4, 2.5))


@icon
def tab_crew():
    return svg(grad('h', '#3b3550', '#14111f'),
               f'<path d="M6 40 Q10 14 32 14 Q54 14 58 40 Q32 30 6 40 Z" fill="url(#h)" stroke="{INK}" stroke-width="{OL}"/>'
               f'<path d="M4 42 Q32 30 60 42 Q60 50 52 50 Q32 42 12 50 Q4 50 4 42 Z" fill="#2a2440" stroke="{INK}" stroke-width="{OL}"/>'
               f'<path d="M8 41 Q32 31 56 41" fill="none" stroke="#f2c14e" stroke-width="3"/>'
               f'<circle cx="32" cy="25" r="6" fill="#f4f1ea" stroke="{INK}" stroke-width="2"/>'
               f'<circle cx="29.5" cy="24.5" r="1.6" fill="{INK}"/><circle cx="34.5" cy="24.5" r="1.6" fill="{INK}"/>'
               f'<path d="M25 33 L39 29 M25 29 L39 33" stroke="#f4f1ea" stroke-width="2.5"/>'
               + shine(20, 22, 5, 2.5, a=0.35))


@icon
def tab_summon():
    return svg(grad('p', '#b57bff', '#5a1fc7') + grad('y', '#fff07a', '#f2a000'),
               f'<circle cx="32" cy="32" r="24" fill="url(#p)" stroke="{INK}" stroke-width="{OL}"/>'
               f'<circle cx="32" cy="32" r="17" fill="none" stroke="#d9b8ff" stroke-width="2" stroke-dasharray="4 3"/>'
               f'<path d="{star_path(32, 33, 15, 7)}" fill="url(#y)" stroke="{INK}" stroke-width="3"/>'
               + shine(22, 18, 6, 3) + sparkle(52, 12, 5) + sparkle(12, 50, 3.5))


def _swirl(d):
    return (f'<path d="{d}" fill="none" stroke="{INK}" stroke-width="10"/>'
            f'<path d="{d}" fill="none" stroke="url(#w)" stroke-width="5"/>')


@icon
def tailwind():
    return svg(grad('w', '#e6fbff', '#59c8f0'),
               _swirl('M8 22 H38 Q48 22 48 14 Q48 8 42 8 Q37 8 37 13')
               + _swirl('M6 34 H50 Q58 34 58 42 Q58 50 50 50 Q44 50 44 44') + _swirl('M14 46 H32'))


@icon
def flag():
    cells = ''.join(
        f'<rect x="{22 + (i % 4) * 8}" y="{10 + (i // 4) * 7}" width="8" height="7" '
        f'fill="{INK if (i % 4 + i // 4) % 2 == 0 else "#fff"}"/>' for i in range(16))
    return svg(grad('g', '#ffe27a', '#d98a00'),
               f'<path d="M18 8 V58" stroke="{INK}" stroke-width="8"/><path d="M18 8 V58" stroke="url(#g)" stroke-width="4"/>'
               + cells + f'<rect x="22" y="10" width="32" height="28" fill="none" stroke="{INK}" stroke-width="{OL}"/>'
               f'<circle cx="18" cy="7" r="4" fill="url(#g)" stroke="{INK}" stroke-width="2.5"/>')


@icon
def ad():
    return svg(grad('r', '#ff7a6b', '#d6182e'),
               f'<rect x="6" y="12" width="52" height="40" rx="10" fill="url(#r)" stroke="{INK}" stroke-width="{OL}"/>'
               f'<path d="M26 22 L42 32 L26 42 Z" fill="#fff" stroke="{INK}" stroke-width="3"/>'
               + shine(16, 19, 6, 2.5))


@icon
def farm():
    return svg(grad('b', '#d9a35a', '#8a5a26') + grad('c', '#ffe066', '#e89a12'),
               f'<path d="M20 20 Q10 34 12 46 Q14 58 32 58 Q50 58 52 46 Q54 34 44 20 Z" fill="url(#b)" stroke="{INK}" stroke-width="{OL}"/>'
               f'<path d="M24 20 Q20 10 28 8 L32 14 L36 8 Q44 10 40 20" fill="url(#b)" stroke="{INK}" stroke-width="3"/>'
               f'<path d="M22 20 H42" stroke="{INK}" stroke-width="7"/><path d="M22 20 H42" stroke="#c4302b" stroke-width="3"/>'
               f'<circle cx="32" cy="40" r="9" fill="url(#c)" stroke="{INK}" stroke-width="3"/>'
               f'<path d="M32 35 V45" stroke="#b86e00" stroke-width="2.5"/>'
               + shine(20, 32, 4, 6, 15, 0.45))


@icon
def rebirth():
    return svg(grad('g', '#ffeec2', '#e3b26a') + grad('c', '#e9f2ff', '#8fb3e0'),
               f'<path d="M6 18 L22 12 L42 18 L58 12 V50 L42 56 L22 50 L6 56 Z" fill="url(#g)" stroke="{INK}" stroke-width="{OL}"/>'
               f'<circle cx="32" cy="34" r="13" fill="url(#c)" stroke="{INK}" stroke-width="{OL}"/>'
               f'<path d="M32 24 L35 34 L32 44 L29 34 Z" fill="#ff3b3b" stroke="{INK}" stroke-width="2"/>'
               f'<path d="M32 34 L35 34 L32 44 L29 34 Z" fill="#fff"/>'
               + sparkle(52, 10, 5))


@icon
def moon():
    return svg(grad('m', '#fff6b0', '#f2b81e') + grad('n', '#4a3f8a', '#1c1640'),
               f'<circle cx="32" cy="32" r="27" fill="url(#n)" stroke="{INK}" stroke-width="{OL}"/>'
               f'<path d="M38 12 Q18 16 18 34 Q18 50 38 54 Q24 44 26 30 Q27 18 38 12 Z" fill="url(#m)" stroke="{INK}" stroke-width="3.5"/>'
               f'<path d="{star_path(44, 24, 6.5, 2.8)}" fill="url(#m)" stroke="{INK}" stroke-width="2"/>'
               f'<path d="{star_path(44, 42, 4.5, 2)}" fill="url(#m)" stroke="{INK}" stroke-width="1.8"/>'
               + shine(22, 24, 2.5, 5, 10, 0.6) + shine(22, 14, 6, 2.5, a=0.25))


@icon
def check():
    return svg(grad('g', '#7af0a0', '#16a34a'),
               f'<circle cx="32" cy="32" r="24" fill="url(#g)" stroke="{INK}" stroke-width="{OL}"/>'
               f'<path d="M20 33 L29 42 L45 23" fill="none" stroke="{INK}" stroke-width="10"/>'
               f'<path d="M20 33 L29 42 L45 23" fill="none" stroke="#fff" stroke-width="5"/>'
               + shine(22, 18, 6, 3))


@icon
def check_empty():
    return svg(rgrad('e', '#6a6296', '#2e2848'),
               f'<circle cx="32" cy="32" r="26" fill="url(#e)" stroke="{INK}" stroke-width="6"/>'
               f'<circle cx="32" cy="32" r="18" fill="none" stroke="#8a82b8" stroke-width="2.5" opacity="0.7"/>'
               + shine(22, 18, 7, 3, a=0.35))


@icon
def shard():
    return svg(grad('g', '#ffeec2', '#d9a35a'),
               f'<path d="M12 14 L36 8 L54 20 L48 50 L22 56 L10 36 Z" fill="url(#g)" stroke="{INK}" stroke-width="{OL}"/>'
               f'<path d="M18 40 Q28 30 36 34" fill="none" stroke="#8a5a26" stroke-width="2.5" stroke-dasharray="3 3"/>'
               f'<path d="M36 22 L46 32 M46 22 L36 32" stroke="{INK}" stroke-width="8"/>'
               f'<path d="M36 22 L46 32 M46 22 L36 32" stroke="#ff3b3b" stroke-width="4.5"/>'
               + shine(20, 18, 5, 2.5) + sparkle(54, 8, 4))


@icon
def hand():
    body = ('M26 34 V12 Q26 6 31 6 Q36 6 36 12 V28 Q42 26 46 30 Q52 30 54 36 V46 Q54 58 40 58 H32 '
            'Q22 58 16 48 L10 38 Q8 32 14 32 Q18 32 22 38 L26 42 Z')
    return svg(grad('w', '#ffffff', '#cfd8ea'),
               f'<path d="{body}" transform="translate(3 3)" fill="{INK}" opacity="0.35"/>'
               f'<path d="{body}" fill="url(#w)" stroke="{INK}" stroke-width="{OL}"/>'
               f'<path d="M36 28 V36 M46 30 V38" stroke="{INK}" stroke-width="2.5"/>'
               f'<path d="M27 50 Q36 54 46 50" fill="none" stroke="#aab6cc" stroke-width="2"/>'
               + shine(29, 12, 2, 4, 0, 0.9) + sparkle(14, 12, 5) + sparkle(50, 14, 3.5))


@icon
def part_cannon():
    return svg(grad('m', '#7d8ba3', '#262c3c') + grad('w', '#c9843f', '#6e3b14'),
               f'<rect x="8" y="22" width="40" height="18" rx="8" transform="rotate(-20 28 31)" fill="url(#m)" stroke="{INK}" stroke-width="{OL}"/>'
               f'<ellipse cx="50" cy="22" rx="5" ry="9" transform="rotate(-20 50 22)" fill="#11131b" stroke="{INK}" stroke-width="3"/>'
               f'<circle cx="24" cy="46" r="10" fill="url(#w)" stroke="{INK}" stroke-width="{OL}"/><circle cx="24" cy="46" r="3" fill="{INK}"/>'
               + shine(20, 27, 8, 2.5, -20, 0.6))


@icon
def part_cargo():
    return svg(grad('w', '#d9a35a', '#8a5a26'),
               f'<rect x="8" y="14" width="48" height="40" rx="4" fill="url(#w)"/>'
               f'<path d="M8 27 H56 M8 41 H56" stroke="#5a3412" stroke-width="2.5"/>'
               f'<path d="M12 18 L52 50 M52 18 L12 50" stroke="#5a3412" stroke-width="3"/>'
               f'<rect x="8" y="14" width="48" height="40" rx="4" fill="none" stroke="{INK}" stroke-width="{OL}"/>'
               + shine(18, 19, 6, 2.5))


@icon
def part_crowsnest():
    return svg(grad('w', '#c9843f', '#6e3b14'),
               f'<path d="M32 30 V60" stroke="{INK}" stroke-width="9"/><path d="M32 30 V60" stroke="#8a5a26" stroke-width="4"/>'
               f'<path d="M14 16 H50 L46 34 H18 Z" fill="url(#w)" stroke="{INK}" stroke-width="{OL}"/>'
               f'<path d="M16 24 H48" stroke="#4a2810" stroke-width="2"/>'
               f'<path d="M32 16 V4" stroke="{INK}" stroke-width="5"/>'
               f'<path d="M32 4 L44 8 L32 12 Z" fill="#ff4b4b" stroke="{INK}" stroke-width="2.5"/>'
               + shine(22, 20, 5, 2))


@icon
def part_hull():
    return svg(grad('w', '#c9843f', '#6e3b14'),
               f'<path d="M4 22 H60 L50 50 H14 Z" fill="url(#w)" stroke="{INK}" stroke-width="{OL}"/>'
               f'<path d="M8 32 H56 M11 41 H53" stroke="#4a2810" stroke-width="2.5"/>'
               f'<circle cx="22" cy="27" r="2" fill="{INK}"/><circle cx="42" cy="27" r="2" fill="{INK}"/>'
               + shine(16, 26, 7, 2))


@icon
def part_sail():
    return svg(grad('s', '#ffffff', '#cfdcee'),
               f'<path d="M30 6 V58" stroke="{INK}" stroke-width="7"/><path d="M30 6 V58" stroke="#8a5a26" stroke-width="3"/>'
               f'<path d="M12 10 Q32 6 52 10 Q58 28 52 46 Q32 42 12 46 Q18 28 12 10 Z" fill="url(#s)" stroke="{INK}" stroke-width="{OL}"/>'
               f'<path d="M14 22 Q32 18 50 22" fill="none" stroke="#c4302b" stroke-width="4"/>'
               + shine(22, 16, 6, 2.5))


@icon
def trophy():
    return svg(grad('g', '#fff07a', '#e39a00'),
               f'<path d="M18 10 H46 V24 Q46 40 32 42 Q18 40 18 24 Z" fill="url(#g)" stroke="{INK}" stroke-width="{OL}"/>'
               f'<path d="M18 16 H8 Q8 30 20 32 M46 16 H56 Q56 30 44 32" fill="none" stroke="{INK}" stroke-width="{OL}"/>'
               f'<path d="M28 42 V50 H36 V42" fill="url(#g)" stroke="{INK}" stroke-width="3"/>'
               f'<rect x="18" y="50" width="28" height="8" rx="2" fill="#8a5a26" stroke="{INK}" stroke-width="3"/>'
               f'<path d="{star_path(32, 24, 7, 3)}" fill="#fff6b0" stroke="#c77d00" stroke-width="1.5"/>'
               + shine(24, 16, 3, 5, 0, 0.7) + sparkle(52, 8, 4))


@icon
def shop():
    return svg(grad('r', '#ff7a6b', '#c4182e') + grad('g', '#ffe066', '#e89a12'),
               f'<path d="M22 22 V18 Q22 8 32 8 Q42 8 42 18 V22" fill="none" stroke="{INK}" stroke-width="8"/>'
               f'<path d="M22 22 V18 Q22 8 32 8 Q42 8 42 18 V22" fill="none" stroke="#e9c27a" stroke-width="3.5"/>'
               f'<path d="M10 22 H54 L50 56 H14 Z" fill="url(#r)" stroke="{INK}" stroke-width="{OL}"/>'
               f'<circle cx="32" cy="38" r="8" fill="url(#g)" stroke="{INK}" stroke-width="3"/>'
               + shine(18, 28, 5, 2.5))


@icon
def mail():
    return svg(grad('p', '#fffaf0', '#e6dcc4'),
               f'<rect x="6" y="14" width="50" height="38" rx="5" fill="url(#p)" stroke="{INK}" stroke-width="{OL}"/>'
               f'<path d="M8 17 L31 36 L54 17" fill="none" stroke="{INK}" stroke-width="3.5"/>'
               f'<circle cx="52" cy="14" r="8" fill="#ff3b3b" stroke="{INK}" stroke-width="3"/>'
               + shine(16, 22, 6, 2.5))


def _badge(top, bottom, inner):
    """계열 아이콘: 진한 원 바탕(등급색 칸 안에서도 읽힘) + 테두리 색 고리 + 안 그림."""
    return svg(grad('r', top, bottom) + grad('d', '#3a3456', '#16121f'),
               f'<circle cx="32" cy="32" r="27" fill="url(#d)" stroke="{INK}" stroke-width="{OL}"/>'
               f'<circle cx="32" cy="32" r="23" fill="none" stroke="url(#r)" stroke-width="4"/>' + inner
               + shine(20, 16, 6, 2.5, a=0.35))


@icon
def fam_lob():  # 투척 — 심지 폭탄
    return _badge('#ffb35a', '#e0601a',
                  f'<circle cx="30" cy="36" r="12" fill="#2b2f3d" stroke="{INK}" stroke-width="3"/>'
                  f'<path d="M37 26 Q42 18 48 18" fill="none" stroke="#c9843f" stroke-width="3"/>'
                  + sparkle(49, 17, 5) + shine(26, 31, 4, 2.5, a=0.6))


@icon
def fam_direct():  # 직사 — 포탄 + 속도선
    return _badge('#ff7a6b', '#c4182e',
                  f'<path d="M12 26 H24 M10 34 H22 M14 42 H24" stroke="#ffd2c8" stroke-width="3"/>'
                  f'<circle cx="38" cy="34" r="11" fill="#2b2f3d" stroke="{INK}" stroke-width="3"/>'
                  + shine(34, 29, 4, 2.5, a=0.6))


@icon
def fam_pierce():  # 관통 — 작살
    return _badge('#9ad8ff', '#2a7fd6',
                  f'<path d="M12 48 L46 18" stroke="{INK}" stroke-width="7"/><path d="M12 48 L46 18" stroke="#c9d3e2" stroke-width="3"/>'
                  f'<path d="M50 14 L38 18 L46 26 Z" fill="#e6edf7" stroke="{INK}" stroke-width="2.5"/>')


@icon
def fam_skip():  # 물수제비 — 돌 + 물결
    return _badge('#7af0e0', '#14a39a',
                  f'<ellipse cx="38" cy="26" rx="9" ry="6" fill="#9aa4b8" stroke="{INK}" stroke-width="3"/>'
                  f'<path d="M10 44 Q16 38 22 44 T34 44 T46 44 T56 44" fill="none" stroke="#7af0e0" stroke-width="3"/>'
                  f'<path d="M22 34 Q28 28 32 30" fill="none" stroke="#e6fbff" stroke-width="2" stroke-dasharray="2 3"/>')


@icon
def fam_underwater():  # 수중 — 어뢰
    return _badge('#7ab8ff', '#1f4fc4',
                  f'<rect x="14" y="27" width="32" height="12" rx="6" fill="#5a6a86" stroke="{INK}" stroke-width="3"/>'
                  f'<path d="M46 33 L54 26 V40 Z" fill="#3a4258" stroke="{INK}" stroke-width="2.5"/>'
                  f'<circle cx="18" cy="46" r="2.5" fill="#bfe6ff"/><circle cx="24" cy="50" r="1.8" fill="#bfe6ff"/>'
                  + shine(24, 30, 6, 1.6, 0, 0.6))


@icon
def fam_air():  # 공중 — 번개
    return _badge('#fff07a', '#e0a000',
                  f'<path d="M36 10 L20 36 H31 L26 54 L46 26 H35 Z" fill="#ffe24a" stroke="{INK}" stroke-width="3"/>')


@icon
def fam_assault():  # 강습 — 갈고리
    return _badge('#ff9ad0', '#c42a7a',
                  f'<path d="M26 12 V36 Q26 48 38 48 Q48 48 48 38" fill="none" stroke="{INK}" stroke-width="9"/>'
                  f'<path d="M26 12 V36 Q26 48 38 48 Q48 48 48 38" fill="none" stroke="#c9d3e2" stroke-width="4"/>'
                  f'<path d="M48 30 L44 40 L54 38 Z" fill="#e6edf7" stroke="{INK}" stroke-width="2.5"/>')


@icon
def fam_shock():  # 충격 — 동심 파동
    return _badge('#c9a0ff', '#6a2fd6',
                  f'<circle cx="32" cy="32" r="5" fill="#fff" stroke="{INK}" stroke-width="2.5"/>'
                  f'<path d="M20 22 A14 14 0 0 0 20 42 M44 22 A14 14 0 0 1 44 42" fill="none" stroke="#d9b8ff" stroke-width="3.5"/>'
                  f'<path d="M14 16 A22 22 0 0 0 14 48 M50 16 A22 22 0 0 1 50 48" fill="none" stroke="#a87cff" stroke-width="3"/>')


@icon
def fam_ring():  # 원형 — 사방 탄
    import math
    dots = ''.join(f'<circle cx="{32 + 15 * math.cos(math.radians(a)):.1f}" cy="{32 + 15 * math.sin(math.radians(a)):.1f}" '
                   f'r="4.5" fill="#ffe24a" stroke="{INK}" stroke-width="2"/>' for a in range(0, 360, 45))
    return _badge('#ffe27a', '#d98a00', f'<circle cx="32" cy="32" r="6" fill="#ff7a3a" stroke="{INK}" stroke-width="2.5"/>' + dots)


@icon
def fam_cluster():  # 집속 — 작은 폭탄 셋
    return _badge('#ff9a5a', '#d6481a',
                  ''.join(f'<circle cx="{x}" cy="{y}" r="8" fill="#2b2f3d" stroke="{INK}" stroke-width="2.5"/>'
                          f'<circle cx="{x-3}" cy="{y-3}" r="2" fill="#fff" opacity="0.7"/>'
                          for x, y in ((24, 26), (40, 26), (32, 40)))
                  + sparkle(48, 44, 4))


@icon
def fam_laser():  # 레이저 — 빔
    return _badge('#ff6bd0', '#a01a8a',
                  f'<path d="M10 40 L54 24" stroke="#ff6bd0" stroke-width="10" opacity="0.5"/>'
                  f'<path d="M10 40 L54 24" stroke="#fff" stroke-width="4"/>'
                  f'<circle cx="12" cy="40" r="6" fill="#ffd6f2" stroke="{INK}" stroke-width="2.5"/>')


# 칸 채움 비율(S1: 외곽 여백 같게, 칸의 85%). 아래 탭 아이콘은 더 크게(선택 시 노란 칸 위에서도 또렷하게).
FILL = 0.85
FILL_TAB = 0.94


def _raw(name, size):
    return Image.open(io.BytesIO(bytes(resvg_py.svg_to_bytes(svg_string=ICONS[name](), width=size, height=size)))).convert('RGBA')


def _outline(img, px):
    from PIL import ImageFilter
    pad = px + 2
    base = Image.new('RGBA', (img.width + pad * 2, img.height + pad * 2), (0, 0, 0, 0))
    base.paste(img, (pad, pad), img)
    a = base.getchannel('A').point(lambda v: 255 if v > 40 else 0).filter(ImageFilter.MaxFilter(px * 2 + 1))
    ring = Image.new('RGBA', base.size, (27, 22, 38, 255))
    ring.putalpha(a)
    ring.alpha_composite(base)
    return ring


def render(name, size):
    """크게 그려 투명 여백을 잘라내고, 긴 변이 칸의 FILL이 되게 맞춰 가운데에 둔다."""
    big = _raw(name, 512)
    box = big.getchannel('A').point(lambda a: 255 if a > 8 else 0).getbbox()
    art = big.crop(box)
    if name.startswith('tab_'):
        art = _outline(art, 14)  # 아래 탭: 바깥 검정 테를 한 겹 더(노란 선택 칸 위에서도 또렷하게)
    fill = FILL_TAB if name.startswith('tab_') else FILL
    k = size * fill / max(art.size)
    art = art.resize((max(1, round(art.width * k)), max(1, round(art.height * k))), Image.LANCZOS)
    out = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    out.paste(art, ((size - art.width) // 2, (size - art.height) // 2), art)
    return out

# 출력: apps/game/assets/ui/hd/<id>.png 1x 32 · 2.0x/ 64 · 3.0x/ 96 (Flutter가 화면 배율로 고른다) + LICENSES.json OWN.
SIZES = {'': 32, '2.0x': 64, '3.0x': 96}


def main():
    import json
    root = os.path.join(os.path.dirname(__file__), '..', '..', 'apps', 'game', 'assets')
    hd = os.path.join(root, 'ui', 'hd')
    for sub, px in SIZES.items():
        d = os.path.join(hd, sub)
        os.makedirs(d, exist_ok=True)
        for n in ICONS:
            render(n, px).save(os.path.join(d, f'{n}.png'), optimize=True)
    lic_path = os.path.join(root, 'LICENSES.json')
    lic = json.load(open(lic_path, encoding='utf-8'))
    for n in ICONS:
        for sub in SIZES:
            key = '/'.join(x for x in ('ui/hd', sub, f'{n}.png') if x)
            lic['files'][key] = {
                'source': 'tools/art/gen_hd_icons.py 코드 SVG(쿵푸할매 스타일 개편 HD 아이콘, PB 아이콘 모양 참고)',
                'license': 'OWN',
            }
    lic['files'] = dict(sorted(lic['files'].items()))
    with open(lic_path, 'w', encoding='utf-8', newline='\n') as f:
        json.dump(lic, f, ensure_ascii=False, indent=2)
        f.write('\n')
    print(len(ICONS), 'icons ×', len(SIZES), '→', hd)


if __name__ == '__main__':
    main()
