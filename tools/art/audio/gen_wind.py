"""바람 환경음 루프(assets/audio/amb/wind.ogg, S5 playAmbient · 2배속 질풍): 코드 생성 — 0원·자체 제작.

핑크 노이즈를 한 극 저역 통과 필터에 통과시키되 차단 주파수를 5초 주기로 오르내려(필터 스윕) '휘이잉' 바람결을 만든다.
끝 1초를 처음 1초에 엇갈려 섞어(크로스페이드) 끊김 없이 되풀이되는 5초 루프. ffmpeg로 ogg(-24 LUFS, 32kHz 모노).

    python tools/art/audio/gen_wind.py
"""

import math
import random
import struct
import subprocess
import sys
import wave
from pathlib import Path

SR = 32000
LOOP = 5.0
XFADE = 1.0
ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "apps/game/assets/audio/amb/wind.ogg"


def pink(n: int, rng: random.Random) -> list[float]:
    # Paul Kellet 근사 핑크 노이즈
    b0 = b1 = b2 = b3 = b4 = b5 = b6 = 0.0
    out = []
    for _ in range(n):
        w = rng.uniform(-1, 1)
        b0 = 0.99886 * b0 + w * 0.0555179
        b1 = 0.99332 * b1 + w * 0.0750759
        b2 = 0.96900 * b2 + w * 0.1538520
        b3 = 0.86650 * b3 + w * 0.3104856
        b4 = 0.55000 * b4 + w * 0.5329522
        b5 = -0.7616 * b5 - w * 0.0168980
        out.append((b0 + b1 + b2 + b3 + b4 + b5 + b6 + w * 0.5362) * 0.11)
        b6 = w * 0.115926
    return out


def main() -> int:
    rng = random.Random(2026)
    total = int(SR * (LOOP + XFADE))
    src = pink(total, rng)
    out = []
    y = 0.0
    for i, x in enumerate(src):
        t = i / SR
        # 차단 주파수 250~1400Hz를 5초 주기로(두 겹 LFO — 돌풍 느낌), 세기도 같이 숨 쉬듯
        lfo = 0.5 + 0.35 * math.sin(2 * math.pi * t / LOOP) + 0.15 * math.sin(2 * math.pi * 3 * t / LOOP + 1.3)
        fc = 250 + 1150 * lfo
        a = 1 - math.exp(-2 * math.pi * fc / SR)
        y += a * (x - y)
        out.append(y * (0.55 + 0.45 * lfo))
    n = int(SR * LOOP)
    xf = int(SR * XFADE)
    loop = out[:n]
    for i in range(xf):  # 끝(n..n+xf)을 처음(0..xf)에 섞는다 → 이음매 없음
        k = i / xf
        loop[i] = loop[i] * k + out[n + i] * (1 - k)
    peak = max(abs(v) for v in loop) or 1
    pcm = b"".join(struct.pack("<h", int(v / peak * 0.8 * 32767)) for v in loop)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    tmp = OUT.with_suffix(".wav")
    with wave.open(str(tmp), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm)
    subprocess.run(
        ["ffmpeg", "-y", "-loglevel", "error", "-i", str(tmp), "-af", "loudnorm=I=-24:TP=-2", "-ar", str(SR),
         "-ac", "1", "-c:a", "libvorbis", "-q:a", "3", str(OUT)],
        check=True,
    )
    tmp.unlink()
    print(f"wrote {OUT} ({OUT.stat().st_size // 1024} KB)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
