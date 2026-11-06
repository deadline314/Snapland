"""Every shipped feedback set keeps its sounds measurably distinct."""
from __future__ import annotations

import math
import tempfile
import unittest
import wave
from pathlib import Path

import numpy as np

from tools import audio_feedback_report as report


def _tone(path: Path, start_hz: float, end_hz: float, seconds: float, rate: int = 22050) -> None:
    t = np.arange(int(seconds * rate)) / rate
    freq = np.linspace(start_hz, end_hz, t.size)
    phase = 2 * math.pi * np.cumsum(freq) / rate
    data = (np.sin(phase) * 0.4 * 32767).astype(np.int16)
    with wave.open(str(path), "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(rate)
        handle.writeframes(data.tobytes())


class FeedbackDistinctTests(unittest.TestCase):
    def test_shipped_sets_are_distinct(self) -> None:
        data = report.report()
        self.assertIn("shared", data)
        self.assertGreaterEqual(len(data), 11, "shared set plus every profiled game")
        for name, entry in data.items():
            with self.subTest(set=name):
                self.assertEqual([], entry["indistinct"])

    def test_identical_sounds_are_not_distinct_and_each_cue_is_detected(self) -> None:
        with tempfile.TemporaryDirectory() as folder:
            folder = Path(folder)
            _tone(folder / "a.wav", 600, 600, 0.3)
            _tone(folder / "b.wav", 600, 600, 0.3)
            _tone(folder / "bright.wav", 1800, 1800, 0.3)
            _tone(folder / "long.wav", 600, 600, 0.6)
            _tone(folder / "rise.wav", 400, 1000, 0.3)
            base = report.features(folder / "a.wav")
            self.assertEqual([], report.distinct(base, report.features(folder / "b.wav")))
            self.assertIn("brightness", report.distinct(base, report.features(folder / "bright.wav")))
            self.assertIn("length", report.distinct(base, report.features(folder / "long.wav")))
            self.assertIn("contour", report.distinct(base, report.features(folder / "rise.wav")))


if __name__ == "__main__":
    unittest.main()
