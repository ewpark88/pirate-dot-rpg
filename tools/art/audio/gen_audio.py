"""자작(OWN) 칩튠 효과음·배경음 미리 듣기 생성 (docs/store/audio-candidates.md 비교용).

    python -I -B tools/art/audio/gen_audio.py            # 전부 (약 1~2분)
    python -I -B tools/art/audio/gen_audio.py --only sfx # 효과음만

출력: tools/art/audio/preview/ (wav, 커밋 안 함 — 같은 입력이면 같은 바이트라 언제든 다시 굽는다)
    sfx/<id>_<n>.wav   fx_map.json sfx id 12종 × 3 (n=0..2; hit·hit_crit는 게임 변형 그대로, 나머지는 고를 후보 3개) + 추가 후보 cannon·coin
    bgm/<id>.wav       regions.json bgm 6종, 이음매 없는 루프 (4채널: 펄스 2 · 삼각 · 노이즈)
    mix/battle_coral.wav  전투 10초 모의 믹스(겹침 상한 규칙 적용) — 귀 피로 판단용
    index.html         브라우저로 열어 바로 듣기

음량 설계: 자주 겹치는 소리(hit·pop·cannon)는 작게, 드문 소리(보스·팡파르·궁극기)는 크게 미리 맞춰 둔다.
"""

from __future__ import annotations

import argparse
import random
import sys
from pathlib import Path

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parent))
from chipsynth import Buf, adsr_note, echo, highpass, hz, lowpass, midi, tone  # noqa: E402

OUT = Path(__file__).resolve().parent / "preview"
SFX_SR = 44100
BGM_SR = 22050


# ───────────────────────── 효과음 ─────────────────────────

def _b(sr=SFX_SR) -> Buf:
    return Buf(sr)


def _finish(b: Buf, peak: float, fade_out: float = 0.006) -> Buf:
    """마무리: NES 출력단처럼 11kHz 위를 살짝 깎아 높은 음의 앨리어싱 거친 소리를 줄이고, 끝을 페이드, 피크 맞춤."""
    b.d = lowpass(b.d, b.sr, 11000)
    return b.fade(fade_out=fade_out).normalize(peak)


def sfx_hit(v: int) -> Buf:
    """일반 타격: 둔탁한 펄스 낙하 + 짧은 노이즈. 6개가 겹쳐도 귀가 안 아프게 작고 짧게(약 0.1초)."""
    p = (1.0, 0.9, 1.1)[v]
    sr = SFX_SR
    b = _b()
    b.mix(tone(sr, 0.012, 1100 * p, 600 * p, duty=0.5, decay_pow=1, vol=0.25))
    b.mix(tone(sr, 0.095, 190 * p, 70 * p, duty=0.5, duty_end=0.25, decay_pow=2.2, vol=0.75))
    b.mix(lowpass(tone(sr, 0.06, 0, kind="noise", noise_hz=9000, decay_pow=3, seed=11 + v, vol=0.55), sr, 3200))
    b.d = lowpass(b.d, sr, 5200)
    return _finish(b, 0.32)


def sfx_hit_crit(v: int) -> Buf:
    """치명타: 높은 딸깍 + 큰 낙하 + 거친 노이즈 + 저음 쿵 (약 0.17초)."""
    p = (1.0, 0.94, 1.06)[v]
    sr = SFX_SR
    b = _b()
    b.mix(tone(sr, 0.016, 1900 * p, 900 * p, duty=0.25, vol=0.4))
    b.mix(tone(sr, 0.16, 280 * p, 55 * p, duty=0.5, decay_pow=1.6, vol=0.8))
    b.mix(lowpass(tone(sr, 0.14, 0, kind="noise", noise_hz=7000, decay_pow=2.2, seed=21 + v, vol=0.75),
                  sr, lambda u: 6500 - 5000 * u))
    b.mix(tone(sr, 0.12, 95 * p, 38 * p, kind="sine", decay_pow=1.5, vol=0.7))
    return _finish(b, 0.5)


def sfx_pop(v: int) -> Buf:
    """처치: 위로 튀는 블립 + 작은 터짐 (약 0.11초)."""
    p = (1.0, 1.12, 0.9)[v]
    sr = SFX_SR
    b = _b()
    b.mix(tone(sr, 0.05, 520 * p, 1350 * p, duty=0.25, decay_pow=1, vol=0.5))
    b.mix(lowpass(tone(sr, 0.09, 0, kind="noise", noise_hz=5000, decay_pow=2, seed=31 + v, vol=0.45), sr, 2600), at=0.015)
    return _finish(b, 0.38)


def _notes(sr, seq, *, kind="square", duty=0.25, a=0.003, d=0.05, s=0.55, r=0.04, vol=0.5, vib=(0, 0)) -> Buf:
    """[(시작초, 음, 길이초)] → 버퍼."""
    b = Buf(sr)
    for at, n, dur in seq:
        b.mix(adsr_note(sr, dur, hz(n), kind=kind, duty=duty, a=a, d=d, s=s, r=r, vol=vol,
                        vib_hz=vib[0], vib_depth=vib[1]), at=at)
    return b


def _shift(note: str, semis: int) -> int:
    return midi(note) + semis


def sfx_combo(v: int) -> Buf:
    """연속 처치: 빠른 상승 아르페지오 + 메아리 (약 0.35초)."""
    k = (0, 2, 4)[v]
    sr = SFX_SR
    seq = [(i * 0.045, _shift(n, k), 0.06) for i, n in enumerate(["C6", "E6", "G6"])]
    seq.append((0.135, _shift("C7", k), 0.13))
    b = _notes(sr, seq, duty=0.25, s=0.4, vol=0.5)
    b.d = echo(b.d, sr, 0.06, 0.32, taps=2)
    return _finish(b, 0.5)


def sfx_skill(v: int) -> Buf:
    """선원 스킬: 올라가는 잽 + 휙 하는 바람 (약 0.3초)."""
    p = (1.0, 0.85, 1.18)[v]
    sr = SFX_SR
    b = _b()
    b.mix(tone(sr, 0.2, 300 * p, 1400 * p, duty=0.125, duty_end=0.5, decay_pow=1.2, vib_hz=28, vib_depth=0.03, vol=0.45))
    whoosh = tone(sr, 0.3, 0, kind="noise", noise_hz=14000, attack=0.08, decay_pow=1.5, seed=41 + v, vol=0.55)
    b.mix(lowpass(whoosh, sr, lambda u: 500 + 5000 * (1 - abs(2 * u - 0.6))))
    return _finish(b, 0.52)


def sfx_ultimate(v: int) -> Buf:
    """궁극기: 모으는 상승음 → 큰 폭발(노이즈 + 저음 + 거친 펄스) (약 1초)."""
    p = (1.0, 0.9, 1.1)[v]
    sr = SFX_SR
    b = _b()
    b.mix(tone(sr, 0.24, 200 * p, 1000 * p, duty=0.25, attack=0.18, decay_pow=0.5, vib_hz=40, vib_depth=0.02, vol=0.35))
    hit = 0.22
    boom = tone(sr, 0.75, 4200, 260, kind="noise", decay_pow=1.8, seed=51 + v, vol=0.9)
    b.mix(lowpass(boom, sr, lambda u: 5000 - 4300 * u), at=hit)
    b.mix(tone(sr, 0.55, 130 * p, 32 * p, kind="sine", decay_pow=1.3, vol=0.85), at=hit)
    b.mix(tone(sr, 0.35, 160 * p, 40 * p, duty=0.5, decay_pow=1.6, vol=0.35), at=hit)
    return _finish(b, 0.8, 0.03)


def sfx_boss_horn(v: int) -> Buf:
    """보스 등장: 해적 뿔나팔 두 번(짧게·길게) + 낮은 우르릉 (약 1.3초)."""
    k = (0, -2, 3)[v]
    sr = SFX_SR
    root = hz(midi("A2") + k)
    b = _b()

    def blast(dur):
        x = Buf(sr)
        x.mix(tone(sr, dur, root * 0.95, root, kind="saw", attack=0.06, hold=dur * 0.55, decay_pow=1.2,
                   vib_hz=5.5, vib_depth=0.012, vib_delay=0.1, slide="lin", vol=0.6))
        x.mix(tone(sr, dur, root * 1.5 * 0.95, root * 1.5, kind="saw", attack=0.07, hold=dur * 0.55, decay_pow=1.2,
                   vib_hz=5.5, vib_depth=0.012, vib_delay=0.1, slide="lin", vol=0.35))
        x.mix(tone(sr, dur, root * 2, root * 2, duty=0.5, attack=0.05, hold=dur * 0.5, decay_pow=1.4, vol=0.15))
        x.d = lowpass(x.d, sr, 1900)
        return x

    b.mix(blast(0.32))
    b.mix(blast(0.85), at=0.42)
    rumble = lowpass(tone(sr, 1.25, 0, kind="noise", noise_hz=3000, attack=0.3, decay_pow=1.5, seed=61 + v, vol=0.5), sr, 350)
    b.mix(rumble)
    return _finish(b, 0.7, 0.04)


def sfx_boss_clear(v: int) -> Buf:
    """보스 격파: 짧은 승리 징글 (약 1초)."""
    k = (0, 2, 5)[v]
    sr = SFX_SR
    lead = [(0.0, "G5", 0.08), (0.09, "C6", 0.08), (0.18, "E6", 0.08), (0.27, "G6", 0.18),
            (0.48, "E6", 0.08), (0.58, "G6", 0.36)]
    harm = [(0.27, "E6", 0.18), (0.48, "C6", 0.08), (0.58, "E6", 0.36)]
    bass = [(0.0, "C4", 0.24), (0.27, "G3", 0.18), (0.48, "C4", 0.46)]
    b = _b()
    b.mix(_notes(sr, [(t, _shift(n, k), d) for t, n, d in lead], duty=0.25, vol=0.5, vib=(6, 0.006)))
    b.mix(_notes(sr, [(t, _shift(n, k) - 3, d) for t, n, d in harm], duty=0.5, vol=0.2))
    b.mix(_notes(sr, [(t, _shift(n, k), d) for t, n, d in bass], kind="triangle", s=0.8, vol=0.55))
    b.d = echo(b.d, sr, 0.09, 0.25, taps=2)
    return _finish(b, 0.7, 0.03)


def sfx_fail(v: int) -> Buf:
    """보스 시간 초과: 부드럽게 내려가는 짧은 소리 — 벌주는 느낌 없이 (약 0.8초)."""
    sr = SFX_SR
    seqs = [
        [(0.0, "G5", 0.12), (0.14, "E5", 0.12), (0.28, "C5", 0.12)],
        [(0.0, "G5", 0.12), (0.14, "EB5", 0.12), (0.28, "C5", 0.12)],
        [(0.0, "E5", 0.1), (0.12, "C5", 0.1), (0.24, "A4", 0.1)],
    ]
    last = ("B4", "B4", "G#4")[v]
    b = _notes(sr, seqs[v], duty=0.5, s=0.6, vol=0.42)
    b.mix(adsr_note(sr, 0.32, hz(last) * 0.94, kind="square", duty=0.5, s=0.7, r=0.12, vol=0.42,
                    slide_from=hz(last), slide_time=0.3, vib_hz=6, vib_depth=0.01), at=0.42)
    b.mix(_notes(sr, [(0.0, "C3" if v < 2 else "A2", 0.62)], kind="triangle", s=0.7, vol=0.45))
    b.d = lowpass(b.d, sr, 3200)
    return _finish(b, 0.5, 0.04)


def _drum(sr, kind: str, seed: int = 0) -> list[float]:
    if kind == "kick":
        x = tone(sr, 0.13, 160, 45, kind="sine", decay_pow=2, vol=1.0)
        click = tone(sr, 0.01, 420, 150, duty=0.5, vol=0.3)
        return [a + (click[i] if i < len(click) else 0) for i, a in enumerate(x)]
    if kind == "snare":
        n = highpass(tone(sr, 0.12, 0, kind="noise", noise_hz=min(10000, sr / 2), decay_pow=2.5, seed=seed, vol=0.75), sr, 700)
        t = tone(sr, 0.05, 230, 180, duty=0.5, decay_pow=1.5, vol=0.3)
        return [a + (t[i] if i < len(t) else 0) for i, a in enumerate(n)]
    if kind == "hat":
        return highpass(tone(sr, 0.03, 0, kind="noise", noise_hz=sr / 2, decay_pow=3, seed=seed, vol=0.45), sr, 5000)
    if kind == "ohat":
        return highpass(tone(sr, 0.12, 0, kind="noise", noise_hz=sr / 2, decay_pow=2, seed=seed, vol=0.35), sr, 4500)
    raise ValueError(kind)


def sfx_fanfare(v: int) -> Buf:
    """배 등급 상승: 큰 팡파르 '따-따-따-따안 → 장식 → 따안' (약 1.7초)."""
    k = (0, 2, 5)[v]
    sr = SFX_SR
    T = 0.1
    lead = [(0, "G5", T * 0.8), (T, "G5", T * 0.8), (2 * T, "G5", T * 0.8), (3 * T, "C6", 0.42),
            (0.78, "E6", 0.09), (0.88, "G6", 0.09), (0.98, "C7", 0.6)]
    harm = [(0, "E5", T * 0.8), (T, "E5", T * 0.8), (2 * T, "E5", T * 0.8), (3 * T, "G5", 0.42),
            (0.78, "C6", 0.09), (0.88, "E6", 0.09), (0.98, "G6", 0.6)]
    bass = [(0, "C3", 0.28), (3 * T, "G2", 0.42), (0.78, "C3", 0.18), (0.98, "C3", 0.6)]
    b = _b()
    b.mix(_notes(sr, [(t, _shift(n, k), d) for t, n, d in lead], duty=0.25, vol=0.5, vib=(6, 0.007)))
    b.mix(_notes(sr, [(t, _shift(n, k), d) for t, n, d in harm], duty=0.5, vol=0.25))
    b.mix(_notes(sr, [(t, _shift(n, k), d) for t, n, d in bass], kind="triangle", s=0.85, vol=0.6))
    for i, at in enumerate([0, T, 2 * T, 3 * T, 0.98]):
        b.mix(_drum(sr, "snare", seed=70 + i), at=at, gain=0.35)
    for i in range(6):  # 마지막 음 앞 스네어 롤
        b.mix(_drum(sr, "snare", seed=80 + i), at=0.7 + i * 0.045, gain=0.15 + i * 0.03)
    b.mix(_drum(sr, "kick"), at=0.98, gain=0.5)
    b.mix(_drum(sr, "ohat", seed=90), at=0.98, gain=0.4)
    return _finish(b, 0.75, 0.05)


def sfx_fanfare_small(v: int) -> Buf:
    """부품 마일스톤: 작은 징글 (약 0.45초)."""
    k = (0, 2, 5)[v]
    sr = SFX_SR
    lead = [(0.0, "E6", 0.06), (0.065, "G6", 0.06), (0.13, "C7", 0.2)]
    b = _notes(sr, [(t, _shift(n, k), d) for t, n, d in lead], duty=0.25, vol=0.5)
    b.mix(_notes(sr, [(0.13, _shift("C5", k), 0.22)], kind="triangle", s=0.8, vol=0.4))
    b.d = echo(b.d, sr, 0.07, 0.3, taps=2)
    return _finish(b, 0.58, 0.03)


def sfx_promote(v: int) -> Buf:
    """선원 승급: 반짝이는 상승 아르페지오 + 높은 반짝임 (약 0.75초)."""
    k = (0, 2, 4)[v]
    sr = SFX_SR
    run = ["C5", "E5", "G5", "C6", "E6", "G6", "C7"]
    b = _notes(sr, [(i * 0.035, _shift(n, k), 0.06) for i, n in enumerate(run)], duty=0.125, s=0.5, vol=0.42)
    top = hz(_shift("C7", k))
    b.mix(tone(sr, 0.32, top, top, duty=0.25, attack=0.005, decay_pow=1.6, arp=[(0, 1.0), (0.25, 1.5), (0.5, 2.0), (0.75, 1.5)],
               vib_hz=12, vib_depth=0.01, vol=0.28), at=0.245)
    b.d = echo(b.d, sr, 0.075, 0.38, taps=3)
    return _finish(b, 0.7, 0.04)


def sfx_cannon(v: int) -> Buf:
    """[추가 후보] 대포 발사 — fx_map에 이벤트 없음(render 요청 필요). 자주 울리므로 작게."""
    p = (1.0, 0.9, 1.12)[v]
    sr = SFX_SR
    b = _b()
    b.mix(lowpass(tone(sr, 0.14, 0, kind="noise", noise_hz=6000, decay_pow=2.4, seed=101 + v, vol=0.8), sr,
                  lambda u: 2600 - 2000 * u))
    b.mix(tone(sr, 0.1, 140 * p, 48 * p, duty=0.5, decay_pow=2, vol=0.55))
    return _finish(b, 0.3)


def sfx_coin(v: int) -> Buf:
    """[추가 후보] 코인 — sfxr 고전 2음 아르페지오. 지금 fx_map엔 없음(골드 획득 연출이 생기면)."""
    k = (0, 2, -3)[v]
    sr = SFX_SR
    f = hz(_shift("B5", k))
    b = _b()
    b.mix(tone(sr, 0.26, f, f, duty=0.5, attack=0.002, hold=0.05, decay_pow=1.4, arp=[(0, 1.0), (0.22, 2 ** (5 / 12))], vol=0.5))
    return _finish(b, 0.32)


SFX = {
    "hit": sfx_hit, "hit_crit": sfx_hit_crit, "pop": sfx_pop, "combo": sfx_combo, "skill": sfx_skill,
    "ultimate": sfx_ultimate, "boss_horn": sfx_boss_horn, "boss_clear": sfx_boss_clear, "fail": sfx_fail,
    "fanfare": sfx_fanfare, "fanfare_small": sfx_fanfare_small, "promote": sfx_promote,
}
EXTRA_SFX = {"cannon": sfx_cannon, "coin": sfx_coin}
VARIANT_IDS = {"hit", "hit_crit"}  # sound_director: damage·critHit만 변형 0..hitVariants-1


# ───────────────────────── 배경음 ─────────────────────────

QUAL = {"": [0, 4, 7], "m": [0, 3, 7], "7": [0, 4, 7, 10], "maj7": [0, 4, 7, 11], "m7": [0, 3, 7, 10]}


def chord_tones(name: str) -> list[int]:
    """'Am' → [57, 60, 64] (근음 옥타브 3). 'Bb' 'C#m' 'Em7' 'Cmaj7' 'B7'."""
    root = name[0].upper()
    rest = name[1:]
    if rest[:1] in ("b", "#"):
        root += rest[0].replace("b", "B")
        rest = rest[1:]
    q = rest if rest in QUAL else ""
    base = midi(root + "3")
    return [base + i for i in QUAL[q]]


# 곡 정의. melody = 마디별 [(음 | 'r', 16분 칸 수)], 한 마디 칸 수 = beats*4.
SONGS = {
    "bgm_coral": dict(
        bpm=132, beats=4, lead_duty=(0.25, 0.5), lead_vib=(5.5, 0.006),
        chords=["C", "G", "Am", "F", "C", "G", "F", "G"],
        melody=[
            [("E5", 4), ("G5", 2), ("C6", 2), ("B5", 2), ("G5", 2), ("E5", 4)],
            [("D5", 4), ("G5", 2), ("B5", 2), ("A5", 2), ("G5", 2), ("D5", 4)],
            [("C5", 2), ("E5", 2), ("A5", 4), ("G5", 2), ("E5", 2), ("C5", 4)],
            [("F5", 4), ("A5", 2), ("C6", 2), ("A5", 2), ("F5", 2), ("G5", 4)],
            [("E5", 2), ("G5", 2), ("C6", 4), ("D6", 2), ("C6", 2), ("G5", 4)],
            [("B5", 4), ("D6", 2), ("B5", 2), ("A5", 2), ("G5", 2), ("D5", 4)],
            [("A5", 2), ("C6", 2), ("F6", 4), ("E6", 2), ("C6", 2), ("A5", 4)],
            [("G5", 4), ("B5", 2), ("D6", 2), ("r", 2), ("B5", 2), ("G5", 2), ("D5", 2)],
        ],
        bass="R.R.F.R.R.R.F.O.", arp="up16", arp_oct=1,
        drums=dict(kick="x.......x.......", snare="....x.......x...", hat="x.x.x.x.x.x.x.x.", ohat="..............x."),
    ),
    "bgm_storm": dict(
        bpm=150, beats=4, lead_duty=(0.5, 0.25), lead_vib=(6.5, 0.01),
        chords=["Dm", "Bb", "C", "Dm", "Dm", "Bb", "C", "A"],
        melody=[
            [("D5", 2), ("F5", 2), ("A5", 2), ("D6", 4), ("C6", 2), ("A5", 2), ("F5", 2)],
            [("D5", 2), ("F5", 2), ("BB5", 4), ("A5", 2), ("F5", 2), ("D5", 4)],
            [("E5", 2), ("G5", 2), ("C6", 4), ("BB5", 2), ("G5", 2), ("E5", 4)],
            [("F5", 2), ("E5", 2), ("D5", 8), ("r", 4)],
            [("A5", 2), ("A5", 2), ("D6", 2), ("A5", 2), ("F6", 4), ("E6", 2), ("D6", 2)],
            [("D6", 4), ("BB5", 2), ("F5", 2), ("D6", 4), ("C6", 2), ("BB5", 2)],
            [("C6", 4), ("G5", 2), ("E5", 2), ("C6", 2), ("D6", 2), ("E6", 4)],
            [("C#6", 4), ("A5", 2), ("E5", 2), ("C#5", 4), ("E5", 4)],
        ],
        bass="RORORORORORORORO", arp="updown16", arp_oct=1,
        drums=dict(kick="x.....x.x.....x.", snare="....x.......x...", hat="xxxxxxxxxxxxxxxx", ohat="........"),
    ),
    "bgm_glacier": dict(
        bpm=92, beats=4, lead_kind="triangle", lead_duty=(0.5, 0.5), lead_vib=(4.5, 0.008), lead_echo=True,
        chords=["Em7", "Cmaj7", "G", "D", "Em7", "Cmaj7", "G", "D"],
        melody=[
            [("B5", 8), ("G5", 4), ("F#5", 4)],
            [("E5", 12), ("D5", 4)],
            [("D5", 4), ("G5", 4), ("B5", 4), ("D6", 4)],
            [("A5", 12), ("F#5", 4)],
            [("G5", 6), ("F#5", 2), ("E5", 4), ("B5", 4)],
            [("C6", 8), ("B5", 4), ("G5", 4)],
            [("B5", 4), ("A5", 4), ("G5", 4), ("D5", 4)],
            [("F#5", 12), ("r", 4)],
        ],
        bass="R...............", arp="up16", arp_oct=2, arp_echo=True,
        drums=dict(kick="x...............", snare="................", hat="....x.......x...", ohat="........x......."),
    ),
    "bgm_volcano": dict(
        bpm=138, beats=4, lead_duty=(0.5, 0.25), lead_vib=(7, 0.012), lead_oct=-1,
        chords=["Cm", "Db", "Cm", "Bb", "Cm", "Db", "Ab", "G"],
        melody=[
            [("C5", 2), ("C5", 2), ("EB5", 2), ("G5", 4), ("F5", 2), ("EB5", 2), ("D5", 2)],
            [("DB5", 4), ("F5", 2), ("AB5", 4), ("G5", 2), ("F5", 4)],
            [("EB5", 2), ("G5", 2), ("C6", 4), ("BB5", 2), ("G5", 2), ("EB5", 4)],
            [("D5", 4), ("F5", 4), ("BB5", 4), ("AB5", 2), ("G5", 2)],
            [("G5", 4), ("AB5", 2), ("G5", 2), ("F5", 2), ("EB5", 2), ("C5", 4)],
            [("DB6", 4), ("C6", 2), ("AB5", 2), ("F5", 4), ("AB5", 4)],
            [("C6", 4), ("EB6", 4), ("C6", 2), ("AB5", 2), ("EB5", 4)],
            [("D6", 4), ("B5", 4), ("G5", 4), ("F5", 2), ("D5", 2)],
        ],
        bass="RRRORRRORRRORROR", arp="power8", arp_oct=0,
        drums=dict(kick="x..x....x..x....", snare="....x.......x...", hat="x.x.x.x.x.x.x.x.", ohat="................"),
    ),
    "bgm_abyss": dict(
        bpm=80, beats=4, lead_duty=(0.125, 0.25), lead_vib=(3.5, 0.012), lead_oct=0, lead_echo=True,
        chords=["Am", "F", "Dm", "E", "Am", "F", "Dm", "E"],
        melody=[
            [("A4", 8), ("C5", 4), ("B4", 4)],
            [("A4", 12), ("r", 4)],
            [("F4", 4), ("A4", 4), ("D5", 4), ("C5", 4)],
            [("B4", 8), ("G#4", 8)],
            [("E5", 8), ("D5", 4), ("C5", 4)],
            [("C5", 8), ("A4", 8)],
            [("D5", 4), ("F5", 4), ("E5", 4), ("D5", 4)],
            [("E5", 12), ("r", 4)],
        ],
        bass="R.......R.......", arp="up8", arp_oct=0,
        drums=dict(kick="x...............", snare="................", hat="........x.......", ohat="................"),
    ),
    "bgm_phantom": dict(
        bpm=116, beats=3, lead_duty=(0.5, 0.25), lead_vib=(6, 0.02), lead_echo=True,
        chords=["Em", "Am", "B7", "Em", "C", "Am", "B7", "B7"],
        melody=[
            [("E5", 4), ("G5", 4), ("B5", 4)],
            [("C6", 6), ("B5", 2), ("A5", 4)],
            [("B5", 4), ("A5", 2), ("G5", 2), ("F#5", 4)],
            [("E5", 8), ("r", 4)],
            [("G5", 4), ("C6", 4), ("E6", 4)],
            [("E6", 6), ("D6", 2), ("C6", 4)],
            [("B5", 4), ("D#6", 4), ("F#6", 4)],
            [("D#6", 8), ("B5", 4)],
        ],
        bass="R...C...C...", arp="waltz", arp_oct=1,
        drums=dict(kick="x...........", snare="................", hat="....x...x...", ohat="................"),
    ),
    # 피버 전용(사용자 피드백 #23 '피버 음악이 색다르지 않다'): 168 BPM, E장조 → 2회차 G장조(조 바꿈 +3), 4박 킥·강한 드럼,
    # 2옥타브 위 반짝이 아르페지오(메아리) — 해역 곡들(80~150 BPM)과 확실히 다르게. 10초 피버 동안 1회차가 거의 다 지나간다.
    "bgm_fever": dict(
        bpm=168, beats=4, lead_duty=(0.25, 0.125), lead_vib=(7, 0.008), lead_oct=-1, pass_transpose=(0, 3), drum_gain=0.62,
        chords=["E", "B", "C#m", "A", "E", "B", "A", "B"],
        melody=[
            [("B5", 2), ("E6", 2), ("G#6", 2), ("B6", 2), ("G#6", 2), ("E6", 2), ("B5", 2), ("E6", 2)],
            [("D#6", 2), ("F#6", 2), ("B6", 4), ("A#6", 2), ("F#6", 2), ("D#6", 4)],
            [("E6", 2), ("G#6", 2), ("C#7", 4), ("B6", 2), ("G#6", 2), ("E6", 4)],
            [("C#6", 4), ("E6", 2), ("A6", 2), ("G#6", 2), ("F#6", 2), ("E6", 4)],
            [("G#6", 2), ("G#6", 2), ("B6", 2), ("G#6", 2), ("E7", 4), ("D#7", 2), ("B6", 2)],
            [("F#6", 4), ("D#6", 2), ("B5", 2), ("F#6", 4), ("A#6", 4)],
            [("A6", 2), ("G#6", 2), ("F#6", 2), ("E6", 2), ("C#6", 4), ("E6", 4)],
            [("D#6", 4), ("F#6", 4), ("B6", 4), ("r", 4)],
        ],
        bass="RORORORORORORORO", arp="up16", arp_oct=2, arp_echo=True,
        drums=dict(kick="x...x...x...x...", snare="....x.......x...", hat="xxxxxxxxxxxxxxxx", ohat="..x...x...x...x."),
    ),
}


def render_song(name: str, spec: dict, sr: int = BGM_SR) -> Buf:
    bpm, beats = spec["bpm"], spec["beats"]
    steps = beats * 4
    step = 60 / bpm / 4
    bar_len = steps * step
    chords = spec["chords"]
    passes = 2
    total = bar_len * len(chords) * passes
    lead, harm, bass, drums = Buf(sr), Buf(sr), Buf(sr), Buf(sr)
    lead_kind = spec.get("lead_kind", "square")
    oct_shift = 12 * spec.get("lead_oct", 0)
    rng = random.Random(name)

    for ps in range(passes):
        for bi, ch in enumerate(chords):
            t0 = (ps * len(chords) + bi) * bar_len
            tr = spec.get("pass_transpose", (0, 0))[ps]  # 회차마다 조 바꿈(반음 수)
            tones = [x + tr for x in chord_tones(ch)]
            # 멜로디 (2회차는 음색을 바꿔 덜 질리게)
            pos = 0
            for n, ln in spec["melody"][bi]:
                if n != "r":
                    dur = ln * step * 0.9
                    lead.mix(adsr_note(sr, dur, hz(midi(n) + oct_shift + tr), kind=lead_kind, duty=spec["lead_duty"][ps],
                                       a=0.004, d=0.06, s=0.65, r=0.05, vib_hz=spec["lead_vib"][0],
                                       vib_depth=spec["lead_vib"][1], vib_delay=0.14, vol=1.0), at=t0 + pos * step)
                pos += ln
            # 반주 (펄스 2)
            arp = spec["arp"]
            ao = 12 * spec["arp_oct"]
            if arp in ("up16", "updown16"):
                seq = tones + [tones[0] + 12]
                if arp == "updown16":
                    seq = seq + seq[-2:0:-1]
                for s in range(steps):
                    harm.mix(adsr_note(sr, step * 0.7, hz(seq[s % len(seq)] + ao), duty=0.125, a=0.002, d=0.04, s=0.4,
                                       r=0.02), at=t0 + s * step)
            elif arp == "up8":
                for s in range(0, steps, 2):
                    harm.mix(adsr_note(sr, step * 1.6, hz(tones[(s // 2) % len(tones)] + ao), duty=0.25, a=0.01, d=0.1,
                                       s=0.4, r=0.08), at=t0 + s * step)
            elif arp == "power8":
                for s in range(0, steps, 2):
                    for iv in (0, 7):
                        harm.mix(adsr_note(sr, step * 1.5, hz(tones[0] + iv + ao), duty=0.5, a=0.002, d=0.05, s=0.5,
                                           r=0.02, vol=0.7), at=t0 + s * step)
            elif arp == "waltz":
                for beat in (1, 2):
                    for tn in tones[1:]:
                        harm.mix(adsr_note(sr, step * 3, hz(tn + ao), duty=0.25, a=0.003, d=0.08, s=0.3, r=0.05, vol=0.6),
                                 at=t0 + beat * 4 * step)
            # 베이스 (삼각): R 근음 · F 5도 · O 옥타브 · C 화음(왈츠는 R만) · . 쉼
            root = tones[0] - 12
            pat = spec["bass"]
            for s, c in enumerate(pat[:steps]):
                if c == ".":
                    continue
                if c == "C":
                    continue
                n = {"R": root, "F": root + 7, "O": root + 12}[c]
                ln = 1
                while s + ln < steps and pat[s + ln] == ".":
                    ln += 1
                bass.mix(adsr_note(sr, ln * step * 0.92, hz(n), kind="triangle", a=0.003, d=0.05, s=0.85, r=0.03),
                         at=t0 + s * step)
            # 드럼 (노이즈) — 2회차 마지막 마디는 스네어 채우기
            last = ps == passes - 1 and bi == len(chords) - 1
            for inst, gain in (("kick", 0.9), ("snare", 0.55), ("hat", 0.22), ("ohat", 0.2)):
                pat = spec["drums"].get(inst, "")
                for s, c in enumerate(pat[:steps]):
                    if c == "x":
                        drums.mix(_drum(sr, inst, seed=rng.randrange(1 << 16)), at=t0 + s * step, gain=gain)
            if last and spec["drums"]["snare"].count("x"):
                for s in range(steps - 4, steps):
                    drums.mix(_drum(sr, "snare", seed=rng.randrange(1 << 16)), at=t0 + s * step, gain=0.3 + 0.08 * (s - steps + 4))

    if spec.get("lead_echo"):
        lead.d = echo(lead.d, sr, step * 3, 0.3, taps=2)
    if spec.get("arp_echo"):
        harm.d = echo(harm.d, sr, step * 2, 0.35, taps=2)
    # 펄스는 부드럽게 (도트 톤 유지하되 귀 피로 줄이기)
    lead.d = lowpass(lead.d, sr, 5200)
    harm.d = lowpass(harm.d, sr, 4200)

    mix = Buf(sr)
    mix.mix(lead, gain=0.26)
    mix.mix(harm, gain=0.11)
    mix.mix(bass, gain=0.42)
    mix.mix(drums, gain=spec.get("drum_gain", 0.45))
    # 이음매 없는 루프: 끝을 넘친 꼬리를 앞에 더한다
    n = int(round(total * sr))
    tail = mix.d[n:]
    mix.d = mix.d[:n] + [0.0] * max(0, n - len(mix.d))
    for i, v in enumerate(tail[:n]):
        mix.d[i] += v
    # 곡마다 체감 크기를 비슷하게: RMS 맞춘 뒤 피크 제한
    r = mix.rms()
    if r > 0:
        mix.scale(0.11 / r)
    if mix.peak() > 0.9:
        mix.normalize(0.9)
    return mix


# ───────────────────────── 전투 모의 믹스 ─────────────────────────

def battle_mix(bgm: Buf, sfx: dict[str, list[Buf]], seconds: float = 10.0) -> Buf:
    """fx_map 상한(같은 id 40ms 간격, 프레임당 6개)을 지키며 전투 10초를 흉내 낸다."""
    sr = SFX_SR
    out = Buf(sr, seconds)
    # 배경음 22050 → 44100 (선형 보간), 실제 게임 기본 볼륨처럼 낮게
    src = bgm.d
    for i in range(len(out.d)):
        x = i * BGM_SR / sr
        j = int(x) % len(src)
        f = x - int(x)
        out.d[i] = (src[j] * (1 - f) + src[(j + 1) % len(src)] * f) * 0.55
    rng = random.Random(7)
    last: dict[str, float] = {}
    frame = 1 / 60

    def play(sid: str, t: float, per_frame: dict[int, int]) -> None:
        fr = int(t / frame)
        if t - last.get(sid, -1) < 0.04 or per_frame.get(fr, 0) >= 6:
            return
        last[sid] = t
        per_frame[fr] = per_frame.get(fr, 0) + 1
        out.mix(rng.choice(sfx[sid]), at=t)

    per_frame: dict[int, int] = {}
    t = 0.3
    while t < seconds - 1.2:
        n = rng.randint(3, 8)  # 범위 폭발 한 번에 맞는 적 수
        for k in range(n):
            play("hit_crit" if rng.random() < 0.12 else "hit", t + k * 0.012, per_frame)
        kills = rng.randint(0, 3)
        for k in range(kills):
            play("pop", t + 0.06 + k * 0.05, per_frame)
        if kills >= 3:
            play("combo", t + 0.22, per_frame)
        t += rng.uniform(0.35, 0.6)
    play("skill", 3.0, per_frame)
    play("ultimate", 6.2, per_frame)
    play("fanfare_small", 8.4, per_frame)
    peak = out.peak()
    if peak > 0.98:
        out.scale(0.98 / peak)
    return out.fade(fade_out=0.3)


# ───────────────────────── 출력 ─────────────────────────

INDEX_HEAD = """<!doctype html><meta charset="utf-8"><title>Audio Preview</title>
<style>body{font:14px system-ui,sans-serif;margin:16px;background:#14202b;color:#e8eef3}
h2{margin-top:28px}table{border-collapse:collapse}td{padding:4px 10px;border-bottom:1px solid #2b3b4a}
audio{height:30px;vertical-align:middle}.note{color:#9fb3c4}</style>
<h1>자작 칩튠 미리 듣기 (OWN)</h1><p class="note">gen_audio.py가 만든 파일. 비교표: docs/store/audio-candidates.md</p>
"""


def write_index(groups: list[tuple[str, list[tuple[str, str, str]]]]) -> None:
    html = [INDEX_HEAD]
    for title, rows in groups:
        html.append(f"<h2>{title}</h2><table>")
        for label, rel, note in rows:
            html.append(f'<tr><td>{label}</td><td><audio controls preload="none" src="{rel}"></audio></td>'
                        f'<td class="note">{note}</td></tr>')
        html.append("</table>")
    (OUT / "index.html").write_text("\n".join(html), encoding="utf-8", newline="\n")


def main(argv: list[str] | None = None) -> int:
    global OUT
    for stream in (sys.stdout, sys.stderr):
        if hasattr(stream, "reconfigure"):
            stream.reconfigure(encoding="utf-8")
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", choices=["sfx", "bgm", "mix"])
    ap.add_argument("--out", type=Path, default=OUT)
    a = ap.parse_args(argv)
    OUT = a.out
    groups = []
    sfx_bufs: dict[str, list[Buf]] = {}
    if a.only in (None, "sfx", "mix"):
        rows = []
        for sid, fn in {**SFX, **EXTRA_SFX}.items():
            sfx_bufs[sid] = []
            for v in range(3):
                b = fn(v)
                sfx_bufs[sid].append(b)
                if a.only != "mix":
                    # 게임 규칙(audio_adapter): hit·hit_crit는 변형 <id>_0..2를 모두 쓴다. 나머지는 <id>.ogg 하나 → 셋 중 하나를 고른다.
                    rel = f"sfx/{sid}_{v}.wav"
                    b.write(OUT / rel)
                    role = "변형(3개 모두 사용)" if sid in VARIANT_IDS else "후보(하나 고름)"
                    extra = " · fx_map에 없음, 추가 후보" if sid in EXTRA_SFX else ""
                    rows.append((f"{sid}_{v}", rel, f"{len(b) / SFX_SR:.2f}초 · 피크 {b.peak():.2f} · {role}{extra}"))
            print(f"sfx {sid}: {', '.join(f'{len(b) / SFX_SR:.2f}s' for b in sfx_bufs[sid])}")
        groups.append(("효과음 (id_변형)", rows))
    coral = None
    if a.only in (None, "bgm", "mix"):
        rows = []
        for name, spec in SONGS.items():
            if a.only == "mix" and name != "bgm_coral":
                continue
            b = render_song(name, spec)
            if name == "bgm_coral":
                coral = b
            if a.only != "mix":
                rel = f"bgm/{name}.wav"
                b.write(OUT / rel)
                rows.append((name, rel, f"{len(b) / BGM_SR:.1f}초 루프 · {spec['bpm']} BPM · {spec['beats']}/4 · 반복 재생으로 이음매 확인"))
            print(f"bgm {name}: {len(b) / BGM_SR:.1f}s")
        groups.append(("배경음 (해역별 루프)", rows))
    if a.only in (None, "mix") and coral is not None:
        m = battle_mix(coral, sfx_bufs)
        m.write(OUT / "mix" / "battle_coral.wav")
        groups.append(("전투 모의 믹스 (10초)", [("battle_coral", "mix/battle_coral.wav",
                                                   "산호해 배경음 + 타격·처치·콤보·스킬·궁극기 — 겹침 상한 적용, 귀 피로 판단용")]))
        print("mix battle_coral: 10.0s")
    if a.only is None:
        write_index(groups)
        print(f"완료 → {OUT / 'index.html'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
