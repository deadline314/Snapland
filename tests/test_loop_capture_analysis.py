"""The loop-capture checks catch real gaps, clicks and crossfade holes."""
from __future__ import annotations

import unittest

import numpy as np

from tools import analyze_loop_capture as loop

RATE = 22050


def _music(seconds: float, seed: int = 3) -> np.ndarray:
    rng = np.random.default_rng(seed)
    t = np.arange(int(seconds * RATE)) / RATE
    tone = 0.2 * np.sin(2 * np.pi * 330 * t) + 0.05 * rng.standard_normal(t.size)
    return np.stack([tone, tone], axis=1)


class LoopCaptureAnalysisTests(unittest.TestCase):
    def test_clean_capture_passes(self) -> None:
        result = loop.analyze(_music(10), RATE, wrap_seconds=4.0, switch_seconds=7.0, crossfade_seconds=0.85)
        self.assertTrue(result["gap_ok"] and result["click_ok"] and result["crossfade_ok"], result)

    def test_click_at_the_wrap_is_detected(self) -> None:
        frames = _music(10)
        frames[int(4.0 * RATE)] = 0.95
        self.assertFalse(loop.analyze(frames, RATE, 4.0, 7.0, 0.85)["click_ok"])

    def test_silence_gap_is_detected(self) -> None:
        frames = _music(10)
        frames[int(3.0 * RATE):int(3.1 * RATE)] = 0.0
        self.assertFalse(loop.analyze(frames, RATE, 4.0, 7.0, 0.85)["gap_ok"])

    def test_crossfade_hole_is_detected(self) -> None:
        frames = _music(10)
        frames[int(7.2 * RATE):int(7.6 * RATE)] *= 0.01
        self.assertFalse(loop.analyze(frames, RATE, 4.0, 7.0, 0.85)["crossfade_ok"])


if __name__ == "__main__":
    unittest.main()
