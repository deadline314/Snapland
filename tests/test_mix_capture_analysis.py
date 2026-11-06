"""Mix-capture analysis parses the BS.1770 meter and applies the cited limits."""
from __future__ import annotations

import subprocess
import unittest
from pathlib import Path
from unittest import mock

from tools import analyze_mix_capture as mix

LOG = """[Parsed_ebur128_0 @ 0x1] t: 0.4  TARGET:-23 LUFS    M: -30.2 S:-120.7     I: -30.2 LUFS       LRA:   0.0 LU  FTPK: -20.1 dBFS
[Parsed_ebur128_0 @ 0x1] t: 0.5  TARGET:-23 LUFS    M: -18.4 S:-120.7     I: -25.0 LUFS       LRA:   0.0 LU  FTPK: -9.0 dBFS
[Parsed_ebur128_0 @ 0x1] Summary:

  Integrated loudness:
    I:         -22.4 LUFS
    Threshold: -32.4 LUFS

  Loudness range:
    LRA:         6.1 LU

  True peak:
    Peak:       -4.2 dBFS
"""


class MixCaptureAnalysisTests(unittest.TestCase):
    def test_meter_reads_momentary_maximum_integrated_range_and_peak(self) -> None:
        with mock.patch.object(mix.subprocess, "run", return_value=subprocess.CompletedProcess([], 0, "", LOG)):
            reading = mix.meter(Path("capture.wav"))
        self.assertEqual(reading, {"momentary_max": -18.4, "integrated": -22.4, "true_peak": -4.2, "loudness_range": 6.1})

    def test_full_slider_offset_adds_master_and_the_louder_bus(self) -> None:
        self.assertAlmostEqual(mix.full_slider_offset_db({"master": 1.0, "music": 1.0, "sfx": 1.0}), 0.0)
        self.assertAlmostEqual(mix.full_slider_offset_db({"master": 0.5, "music": 0.5, "sfx": 1.0}), 12.04, places=2)

    def test_limits_match_the_cited_guidance(self) -> None:
        self.assertEqual(mix.REFERENCE_LUFS, -23.0)
        self.assertEqual(mix.REFERENCE_TOLERANCE_LU, 2.0)
        self.assertEqual(mix.TRUE_PEAK_LIMIT_DBTP, -1.0)
        self.assertEqual(mix.MAX_LOUDNESS_RANGE_LU, 20.0)


if __name__ == "__main__":
    unittest.main()
