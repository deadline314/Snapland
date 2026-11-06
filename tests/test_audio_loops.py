"""Shipped music loops wrap without a click or a gap.

prepare_cc0_audio.py bakes a crossfade so each file ends on its own opening, then records
the measured seam in the catalog. The catalog hash check in test_audio_licenses ties these
numbers to the exact shipped bytes.
"""
from __future__ import annotations

import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / "assets/audio/cc0/catalog.json"
MAX_SAMPLE_JUMP = 0.012      # full scale; the old raw wraps reached 0.056
MAX_STEP_DIFFERENCE_DB = 1.0  # level change at the seam versus the music itself there


class AudioLoopTests(unittest.TestCase):
    def test_every_music_track_has_a_measured_seamless_loop(self) -> None:
        music = [asset for asset in json.loads(CATALOG.read_text(encoding="utf-8"))["assets"] if asset["kind"] == "music"]
        self.assertGreaterEqual(len(music), 13)
        for asset in music:
            with self.subTest(asset=asset["id"]):
                self.assertGreater(float(asset.get("loop_crossfade_seconds", 0)), 0, "music must bake a loop crossfade")
                seam = asset.get("loop_seam")
                self.assertIsInstance(seam, dict, "rerun tools/prepare_cc0_audio.py to measure the seam")
                self.assertLessEqual(seam["sample_jump"], MAX_SAMPLE_JUMP)
                self.assertLessEqual(abs(seam["seam_level_step_db"] - seam["source_level_step_db"]), MAX_STEP_DIFFERENCE_DB)
                self.assertEqual(seam["offset_seconds"], asset["loop_crossfade_seconds"])


if __name__ == "__main__":
    unittest.main()
