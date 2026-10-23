"""The stored hero stride calibration must match the walk artwork it was measured from."""
from __future__ import annotations

import hashlib
import json
import unittest
from pathlib import Path

from tools import walk_stride_calibration as calibration

ROOT = Path(__file__).resolve().parents[1]


class WalkStrideCalibrationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.stored = json.loads(calibration.OUTPUT.read_text(encoding="utf-8"))
        cls.metadata = json.loads(calibration.REGIONS.read_text(encoding="utf-8"))

    def test_calibration_tracks_current_artwork(self) -> None:
        self.assertEqual(self.stored["regions_sha256"], hashlib.sha256(calibration.REGIONS.read_bytes()).hexdigest(),
                         "walk regions changed: rerun tools/walk_stride_calibration.py --write")
        for path, digest in self.stored["atlas_sha256"].items():
            self.assertEqual(digest, hashlib.sha256((ROOT / path).read_bytes()).hexdigest(), f"{path} changed: recalibrate")

    def test_stored_values_equal_a_fresh_measurement(self) -> None:
        fresh = calibration.measure(self.metadata)
        self.assertEqual(fresh["directions"], self.stored["directions"])
        self.assertEqual(set(self.stored["directions"]), set(self.metadata["directions"]))

    def test_measured_strides_are_consistent_and_far_below_the_old_constant(self) -> None:
        strides = [entry["stride_world"] for entry in self.stored["directions"].values()]
        self.assertLessEqual(max(strides) / min(strides), 1.25, "one character's legs give similar strides in every view")
        self.assertLess(max(strides), 2.8 / 2, "the old 2.8 unit cycle made the body outrun the drawn feet")

    def test_two_separate_boots_are_required_for_a_sample(self) -> None:
        import numpy as np
        alpha = np.zeros((60, 120), dtype=bool)
        alpha[20:60, 10:30] = True
        alpha[30:60, 70:95] = True
        self.assertEqual(len(calibration.foot_points(alpha, 59)), 2)
        alpha[40:45, 30:70] = True  # joined legs are a passing pose, not a measurable step
        self.assertEqual(calibration.foot_points(alpha, 59), [])


if __name__ == "__main__":
    unittest.main()
