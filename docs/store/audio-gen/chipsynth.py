"""칩튠 합성 핵심 (sfxr 방식 + 4채널 트래커 느낌). 표준 라이브러리만.

물리 단위(초·Hz)로 쓴다. 모든 무작위는 시드 고정 → 같은 입력이면 같은 바이트.
"""

from __future__ import annotations

import math
import random
import struct
import wave
from pathlib import Path

TAU = 2 * math.pi

NOTE_INDEX = {"C": 0, "C#": 1, "DB": 1, "D": 2, "D#": 3, "EB": 3, "E": 4, "F": 5, "F#": 6, "GB": 6,
              "G": 7, "G#": 8, "AB": 8, "A": 9, "A#": 10, "BB": 10, "B": 11}


def midi(name: str) -> int:
    """'C5' → 72, 'Bb4' → 70."""
    name = name.upper()
    octave = int(name[-1])
    return 12 * (octave + 1) + NOTE_INDEX[name[:-1]]


def hz(n: int | str) -> float:
    if isinstance(n, str):
        n = midi(n)
    return 440.0 * 2 ** ((n - 69) / 12)


class Buf:
    """모노 float 버퍼 + 섞기·필터·쓰기."""

    def __init__(self, sr: int, seconds: float = 0.0, data: list[float] | None = None):
        self.sr = sr
        self.d = data if data is not None else [0.0] * int(round(seconds * sr))

    def __len__(self) -> int:
        return len(self.d)

    def mix(self, src: "Buf | list[float]", at: float = 0.0, gain: float = 1.0) -> "Buf":
        s = src.d if isinstance(src, Buf) else src
        o = int(round(at * self.sr))
        need = o + len(s)
        if need > len(self.d):
            self.d.extend([0.0] * (need - len(self.d)))
        d = self.d
        for i, v in enumerate(s):
            d[o + i] += v * gain
        return self

    def peak(self) -> float:
        return max((abs(v) for v in self.d), default=0.0)

    def rms(self) -> float:
        return math.sqrt(sum(v * v for v in self.d) / max(1, len(self.d)))

    def scale(self, g: float) -> "Buf":
        self.d = [v * g for v in self.d]
        return self

    def dc_block(self, cutoff: float = 15.0) -> "Buf":
        self.d = highpass(self.d, self.sr, cutoff)
        return self

    def normalize(self, peak: float) -> "Buf":
        self.dc_block()
        p = self.peak()
        return self.scale(peak / p) if p > 0 else self

    def fade(self, fade_in: float = 0.001, fade_out: float = 0.006) -> "Buf":
        n = len(self.d)
        a, b = int(fade_in * self.sr), int(fade_out * self.sr)
        for i in range(min(a, n)):
            self.d[i] *= i / a
        for i in range(min(b, n)):
            self.d[n - 1 - i] *= i / b
        return self

    def write(self, path: Path) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        frames = bytearray()
        for v in self.d:
            v = max(-1.0, min(1.0, v))
            frames += struct.pack("<h", int(round(v * 32767)))
        with wave.open(str(path), "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(self.sr)
            w.writeframes(bytes(frames))


def lowpass(x: list[float], sr: int, cutoff) -> list[float]:
    """1극 저역 통과. cutoff는 Hz 또는 t(0..1) → Hz 함수(쓸기)."""
    n = len(x)
    y, out = 0.0, [0.0] * n
    fixed = not callable(cutoff)
    k = 1 - math.exp(-TAU * cutoff / sr) if fixed else 0.0
    for i, v in enumerate(x):
        if not fixed:
            k = 1 - math.exp(-TAU * max(20.0, cutoff(i / n)) / sr)
        y += k * (v - y)
        out[i] = y
    return out


def highpass(x: list[float], sr: int, cutoff: float) -> list[float]:
    lp = lowpass(x, sr, cutoff)
    return [a - b for a, b in zip(x, lp)]


def echo(x: list[float], sr: int, delay: float, feedback: float, taps: int = 3) -> list[float]:
    d = int(delay * sr)
    out = x + [0.0] * (d * taps)
    g = 1.0
    for t in range(1, taps + 1):
        g *= feedback
        o = d * t
        for i, v in enumerate(x):
            out[o + i] += v * g
    return out


def tone(
    sr: int,
    dur: float,
    f0: float,
    f1: float | None = None,
    *,
    kind: str = "square",
    duty: float = 0.5,
    duty_end: float | None = None,
    attack: float = 0.002,
    hold: float = 0.0,
    decay_pow: float = 1.0,
    sustain: float = 0.0,
    vib_hz: float = 0.0,
    vib_depth: float = 0.0,
    vib_delay: float = 0.0,
    arp: list[tuple[float, float]] | None = None,
    noise_hz: float | None = None,
    seed: int = 0,
    slide: str = "exp",
    vol: float = 1.0,
) -> list[float]:
    """한 소리. 음높이 f0→f1(지수/직선 미끄럼), 엔벨로프 attack → hold → (sustain까지) 감쇠.

    kind: square(펄스, duty) · triangle · saw · sine · noise(샘플 앤 홀드, noise_hz = 갱신 빈도).
    arp: [(시작 비율 0..1, 주파수 배수)] — sfxr의 arpeggio(코인 소리 등).
    """
    n = max(1, int(round(dur * sr)))
    f1 = f0 if f1 is None else f1
    rng = random.Random(seed)
    out = [0.0] * n
    phase = 0.0
    nval = rng.uniform(-1, 1)
    nphase = 0.0
    d_end = duty if duty_end is None else duty_end
    body = max(1e-6, dur - attack - hold)
    for i in range(n):
        t = i / sr
        u = i / n
        if slide == "exp" and f0 > 0 and f1 > 0:
            f = f0 * (f1 / f0) ** u
        else:
            f = f0 + (f1 - f0) * u
        if arp:
            f *= next((m for s, m in reversed(arp) if u >= s), 1.0)
        if vib_depth and t >= vib_delay:
            f *= 1 + vib_depth * math.sin(TAU * vib_hz * (t - vib_delay))
        # 엔벨로프
        if t < attack:
            e = t / attack
        elif t < attack + hold:
            e = 1.0
        else:
            r = min(1.0, (t - attack - hold) / body)
            e = sustain + (1 - sustain) * (1 - r) ** decay_pow if sustain else (1 - r) ** decay_pow
        if kind == "noise":
            rate = noise_hz if noise_hz else f
            nphase += rate / sr
            if nphase >= 1:
                nphase -= int(nphase)
                nval = rng.uniform(-1, 1)
            v = nval
        else:
            phase = (phase + f / sr) % 1.0
            if kind == "square":
                dt = duty + (d_end - duty) * u
                # 0 평균 펄스(실제 칩의 AC 결합처럼) — 좁은 duty의 DC 치우침이 헤드룸을 먹고 '툭' 소리를 내지 않게
                v = (1.0 if phase < dt else -1.0) - (2 * dt - 1)
            elif kind == "triangle":
                # NES 삼각파 느낌: 16단 계단
                tri = 4 * abs(phase - 0.5) - 1
                v = round(tri * 7.5) / 7.5
            elif kind == "saw":
                v = 2 * phase - 1
            else:
                v = math.sin(TAU * phase)
        out[i] = v * e * vol
    return out


def adsr_note(sr: int, dur: float, freq: float, *, kind="square", duty=0.5, a=0.004, d=0.08, s=0.6, r=0.05,
              vib_hz=0.0, vib_depth=0.0, vib_delay=0.15, vol=1.0, slide_from: float | None = None,
              slide_time: float = 0.03) -> list[float]:
    """음악용 음표: 길이 dur 동안 ADSR, 뒤에 release r."""
    total = dur + r
    n = int(round(total * sr))
    out = [0.0] * n
    phase = 0.0
    for i in range(n):
        t = i / sr
        f = freq
        if slide_from and t < slide_time:
            f = slide_from * (freq / slide_from) ** (t / slide_time)
        if vib_depth and t > vib_delay:
            f *= 1 + vib_depth * math.sin(TAU * vib_hz * (t - vib_delay))
        if t < a:
            e = t / a
        elif t < a + d:
            e = 1 - (1 - s) * (t - a) / d
        else:
            e = s
        if t > dur:
            e *= max(0.0, 1 - (t - dur) / r)
        phase = (phase + f / sr) % 1.0
        if kind == "square":
            v = (1.0 if phase < duty else -1.0) - (2 * duty - 1)
        elif kind == "triangle":
            v = round((4 * abs(phase - 0.5) - 1) * 7.5) / 7.5
        elif kind == "saw":
            v = 2 * phase - 1
        else:
            v = math.sin(TAU * phase)
        out[i] = v * e * vol
    return out
