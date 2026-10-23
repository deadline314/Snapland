"""The PCM beep matcher finds synthetic beeps and rejects beeps without letters."""
from __future__ import annotations

import json
import tempfile
import unittest
import wave
from pathlib import Path

import numpy as np

from tools.analyze_dialogue_beeps import PITCH_HZ, main

RATE = 44100
FPS = 30.0


def write_capture(path: Path, beeps: list[tuple[float, str, float]], seconds: float = 3.0) -> None:
    samples = np.zeros(int(seconds * RATE))
    length = int(0.024 * RATE)
    t = np.arange(length) / RATE
    fade = np.minimum(1.0, np.minimum(t / 0.003, (0.024 - t) / 0.006))
    for time_s, speaker, gain in beeps:
        start = int(time_s * RATE)
        samples[start:start + length] += np.sin(2 * np.pi * PITCH_HZ[speaker] * t) * fade * 0.2 * gain
    pcm = (np.clip(samples, -1, 1) * 32767).astype(np.int16)
    with wave.open(str(path), "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(RATE)
        handle.writeframes(pcm.tobytes())


def glyph(frame: int, speaker: str, char: str, skipped: bool = False) -> dict:
    return {"frame": frame, "speaker": speaker, "glyph": char, "skipped": skipped}


class DialogueBeepAnalysisTests(unittest.TestCase):
    def run_case(self, beeps, glyphs, segments=()):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            write_capture(root / "a.wav", beeps)
            (root / "r.json").write_text(json.dumps({"glyphs": glyphs, "volume_segments": list(segments)}), encoding="utf-8")
            code = main(["x", str(root / "a.wav"), str(root / "r.json"), str(root / "o.json")])
            return code, json.loads((root / "o.json").read_text(encoding="utf-8"))

    def test_letters_match_their_speaker_pitch(self) -> None:
        beeps = [(f / FPS, "阿浪", 1.0) for f in (6, 8, 10)] + [(20 / FPS, "小角", 1.0)]
        glyphs = [glyph(6, "阿浪", "入"), glyph(7, "阿浪", "，"), glyph(8, "阿浪", "口"), glyph(10, "阿浪", "在"), glyph(20, "小角", "好")]
        code, result = self.run_case(beeps, glyphs)
        self.assertEqual(code, 0, result)
        self.assertEqual(result["beep_onsets"], 4)
        self.assertEqual(result["onsets_without_revealed_letter"], [])

    def test_beep_without_a_letter_or_with_wrong_pitch_fails(self) -> None:
        code, result = self.run_case([(40 / FPS, "票票", 1.0)], [glyph(6, "票票", "船")])
        self.assertEqual(code, 1)
        self.assertEqual(len(result["onsets_without_revealed_letter"]), 1)
        code, result = self.run_case([(6 / FPS, "小角", 1.0)], [glyph(6, "票票", "船")])
        self.assertEqual(code, 1)
        self.assertEqual(len(result["onsets_with_other_speaker_pitch"]), 1)

    def test_half_volume_halves_beep_peaks(self) -> None:
        beeps = [(f / FPS, "阿浪", 1.0) for f in (6, 9, 12)] + [(f / FPS, "阿浪", 0.5) for f in (40, 43, 46)]
        glyphs = [glyph(f, "阿浪", "字") for f in (6, 9, 12, 40, 43, 46)]
        segments = [{"sfx_volume": 1.0, "start_frame": 0, "end_frame": 30}, {"sfx_volume": 0.5, "start_frame": 35, "end_frame": 60}]
        code, result = self.run_case(beeps, glyphs, segments)
        self.assertEqual(code, 0, result)
        self.assertAlmostEqual(result["half_to_full_peak_ratio"], 0.5, delta=0.05)


if __name__ == "__main__":
    unittest.main()
