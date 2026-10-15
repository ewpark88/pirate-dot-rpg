"""gen_audio.py 품질 기준 테스트. python -I -B -m unittest discover -s tools/art/audio"""

from __future__ import annotations

import sys
import unittest
from pathlib import Path

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parent))
import gen_audio  # noqa: E402


def _mean(d):
    return sum(d) / len(d)


class SfxTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.bufs = {sid: [fn(v) for v in range(3)] for sid, fn in {**gen_audio.SFX, **gen_audio.EXTRA_SFX}.items()}

    def test_all_fx_map_ids_covered(self):
        import json
        root = Path(__file__).resolve().parents[3]
        fx = json.loads((root / "packages/game_data/tables/fx_map.json").read_text(encoding="utf-8"))
        ids = {e["sfx"] for e in fx["events"].values() if isinstance(e, dict) and e.get("sfx")}
        self.assertEqual(ids - set(gen_audio.SFX), set())

    def test_frequent_sounds_are_short_and_quiet(self):
        # 자주 겹치는 소리: 0.2초 이하, 피크 0.5 이하 (sfxMaxPerFrame 6개가 겹쳐도 덜 뭉개지게)
        for sid in ("hit", "hit_crit", "pop", "cannon"):
            for b in self.bufs[sid]:
                self.assertLessEqual(len(b) / b.sr, 0.2, sid)
                self.assertLessEqual(b.peak(), 0.5 + 1e-6, sid)

    def test_no_dc_no_clip_silent_edges(self):
        for sid, bs in self.bufs.items():
            for b in bs:
                self.assertLess(abs(_mean(b.d)), 0.005, sid)
                self.assertLess(b.peak(), 0.99, sid)
                self.assertLess(abs(b.d[0]), 0.01, sid)
                self.assertLess(abs(b.d[-1]), 0.01, sid)

    def test_variants_differ(self):
        for sid, bs in self.bufs.items():
            self.assertNotEqual(bs[0].d, bs[1].d, sid)

    def test_deterministic(self):
        self.assertEqual(gen_audio.sfx_hit(0).d, gen_audio.sfx_hit(0).d)
        self.assertEqual(gen_audio.sfx_ultimate(1).d, gen_audio.sfx_ultimate(1).d)


class BgmTest(unittest.TestCase):
    def test_every_region_has_song_with_full_bars(self):
        import json
        root = Path(__file__).resolve().parents[3]
        regions = json.loads((root / "packages/game_data/tables/regions.json").read_text(encoding="utf-8"))["regions"]
        self.assertEqual({r["bgm"] for r in regions} - set(gen_audio.SONGS), set())
        for name, spec in gen_audio.SONGS.items():
            steps = spec["beats"] * 4
            self.assertEqual(len(spec["melody"]), len(spec["chords"]), name)
            for i, bar in enumerate(spec["melody"]):
                self.assertEqual(sum(n for _, n in bar), steps, f"{name} 마디 {i + 1}")

    def test_loop_seam_and_level(self):
        b = gen_audio.render_song("bgm_phantom", gen_audio.SONGS["bgm_phantom"])
        spec = gen_audio.SONGS["bgm_phantom"]
        expect = 60 / spec["bpm"] / 4 * spec["beats"] * 4 * len(spec["chords"]) * 2
        self.assertAlmostEqual(len(b) / b.sr, expect, places=2)
        self.assertLess(abs(b.d[-1] - b.d[0]), 0.08)  # 이음매에서 튀지 않음
        self.assertAlmostEqual(b.rms(), 0.11, places=2)
        self.assertLessEqual(b.peak(), 0.9 + 1e-6)
        self.assertLess(abs(_mean(b.d)), 0.005)


if __name__ == "__main__":
    unittest.main()
