"""Check a native music-loop capture for gaps, clicks and crossfade dropouts.

Reads the WAV and report written by game/tests/native_music_loop_review.gd:

* gap: no run of exact digital silence longer than MAX_GAP_SECONDS while music plays,
* click: the largest sample-to-sample step near the loop wrap is not an outlier compared
  with the same statistic across the rest of the capture,
* crossfade: while the two tracks overlap, the 50 ms level never falls more than
  CROSSFADE_DIP_DB below the quieter of the second before and the second after.

These are technical checks of the mix, not a listening verdict.
"""
from __future__ import annotations

import argparse
import json
import sys
import wave
from pathlib import Path

import numpy as np

MAX_GAP_SECONDS = 0.02
CLICK_WINDOW_SECONDS = 0.3
CLICK_OUTLIER_RATIO = 1.5
CROSSFADE_DIP_DB = 6.0
LEVEL_WINDOW_SECONDS = 0.05


def load(path: Path) -> tuple[np.ndarray, int]:
    with wave.open(str(path), "rb") as handle:
        rate, channels = handle.getframerate(), handle.getnchannels()
        data = np.frombuffer(handle.readframes(handle.getnframes()), dtype=np.int16).astype(np.float64) / 32768.0
    return data.reshape(-1, channels), rate


def longest_silence(frames: np.ndarray, rate: int) -> float:
    silent = np.all(frames == 0.0, axis=1).astype(np.int8)
    if not silent.any():
        return 0.0
    edges = np.diff(np.concatenate(([0], silent, [0])))
    starts, ends = np.nonzero(edges == 1)[0], np.nonzero(edges == -1)[0]
    return float((ends - starts).max()) / rate


def analyze(frames: np.ndarray, rate: int, wrap_seconds: float, switch_seconds: float, crossfade_seconds: float) -> dict:
    mono = frames.mean(axis=1)
    steps = np.abs(np.diff(mono))
    centre = int(wrap_seconds * rate)
    half = int(CLICK_WINDOW_SECONDS * rate)
    near = steps[max(0, centre - half):centre + half]
    elsewhere = np.concatenate((steps[:max(0, centre - half)], steps[centre + half:]))
    # Compare the peak step at the wrap with the typical worst steps of the music itself.
    reference = float(np.percentile(elsewhere, 99.99)) if elsewhere.size else 0.0
    window = int(LEVEL_WINDOW_SECONDS * rate)

    def levels(from_seconds: float, to_seconds: float) -> list[float]:
        first, last = max(0, int(from_seconds * rate)), min(mono.size, int(to_seconds * rate))
        return [20 * np.log10(np.sqrt(np.mean(mono[i:i + window] ** 2)) + 1e-12) for i in range(first, last - window, window)]

    def mean_level(values: list[float]) -> float:
        return float(10 * np.log10(np.mean(np.power(10.0, np.array(values) / 10.0)))) if values else -120.0

    before = mean_level(levels(switch_seconds - 1.0, switch_seconds))
    after = mean_level(levels(switch_seconds + crossfade_seconds + 0.2, switch_seconds + crossfade_seconds + 1.2))
    during = levels(switch_seconds, switch_seconds + crossfade_seconds)
    result = {
        "longest_silence_seconds": round(longest_silence(frames[: int((switch_seconds + crossfade_seconds + 1.0) * rate)], rate), 4),
        "wrap_peak_step": round(float(near.max()) if near.size else 0.0, 5),
        "music_reference_step": round(reference, 5),
        "level_before_db": round(before, 2), "level_after_db": round(after, 2),
        "crossfade_min_level_db": round(float(min(during)) if during else -120.0, 2),
    }
    result["gap_ok"] = result["longest_silence_seconds"] <= MAX_GAP_SECONDS
    result["click_ok"] = reference > 0 and result["wrap_peak_step"] <= reference * CLICK_OUTLIER_RATIO
    result["crossfade_ok"] = bool(during) and result["crossfade_min_level_db"] >= min(before, after) - CROSSFADE_DIP_DB
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("capture_dir", type=Path, help="folder holding music-loop-mix.wav and music-loop-report.json")
    args = parser.parse_args()
    report = json.loads((args.capture_dir / "music-loop-report.json").read_text(encoding="utf-8"))
    frames, rate = load(args.capture_dir / "music-loop-mix.wav")
    # The PCM clock can trail wall time slightly; scale wall timestamps onto the recording.
    scale = (frames.shape[0] / rate) / float(report["wall_seconds"])
    result = analyze(frames, rate, float(report["observed_wrap_seconds"]) * scale, float(report["switch_seconds"]) * scale,
                     float(report["crossfade_seconds"]))
    result["pcm_to_wall_scale"] = round(scale, 5)
    print(json.dumps(result, indent=2))
    return 0 if result["gap_ok"] and result["click_ok"] and result["crossfade_ok"] else 1


if __name__ == "__main__":
    sys.exit(main())
