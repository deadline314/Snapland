"""Check that the minigame mix stays controlled during dense feedback.

Reads game-audio-mix.wav and game-audio-timeline.json written by
game/tests/native_game_audio_review.gd. For each game it compares the burst segment
(rapid hits/misses, then the result jingle) with the moments just before it, using
ffmpeg's ITU-R BS.1770 meter (ebur128). Slider gains come from the capture; a --full-volume
capture needs no estimate:

* true peak of the burst stays at or below TRUE_PEAK_LIMIT_DBTP even with every volume
  slider at full (the capture's default slider gains are added back),
* the whole capture's integrated loudness at full sliders falls within the console
  reference of -23 LUFS +/- REFERENCE_TOLERANCE_LU (GANG IESD / Sony WWS guidance),
* its loudness range stays at or below MAX_LOUDNESS_RANGE_LU (Sony ASWG recommended maximum).

How far each burst rises above that game's music (spike_lu) is reported for review only:
quiet puzzle music makes the same feedback read as a larger rise without being loud.

A technical measurement, not a listening verdict.
"""
from __future__ import annotations

import argparse
import json
import math
import re
import subprocess
import sys
from pathlib import Path

TRUE_PEAK_LIMIT_DBTP = -1.0
MAX_LOUDNESS_RANGE_LU = 20.0
REFERENCE_LUFS = -23.0
REFERENCE_TOLERANCE_LU = 2.0
DEFAULT_GAINS = {"master": 0.7, "music": 0.6, "sfx": 0.8}


def meter(wav: Path, start: float | None = None, duration: float | None = None) -> dict:
    command = ["ffmpeg", "-hide_banner", "-nostats", "-v", "verbose"]
    if start is not None:
        command += ["-ss", f"{max(0.0, start):.3f}"]
    if duration is not None:
        command += ["-t", f"{duration:.3f}"]
    command += ["-i", str(wav), "-af", "ebur128=peak=true:framelog=verbose", "-f", "null", "-"]
    log = subprocess.run(command, capture_output=True, text=True, timeout=300).stderr
    momentary = [float(value) for value in re.findall(r"\bM:\s*(-?[\d.]+|-inf)", log) if value != "-inf"]
    integrated = re.findall(r"I:\s+(-?[\d.]+) LUFS", log)
    peak = re.findall(r"Peak:\s+(-?[\d.]+|-inf) dBFS", log)
    loudness_range = re.findall(r"LRA:\s+(-?[\d.]+) LU", log)
    return {"momentary_max": max(momentary) if momentary else -120.0,
            "integrated": float(integrated[-1]) if integrated else -120.0,
            "true_peak": float(peak[-1]) if peak and peak[-1] != "-inf" else -120.0,
            "loudness_range": float(loudness_range[-1]) if loudness_range else 0.0}


def full_slider_offset_db(gains: dict) -> float:
    """Worst-case boost from default sliders to full: master plus the louder bus."""
    loudest_bus = min(gains["music"], gains["sfx"])
    return -20 * math.log10(gains["master"]) - 20 * math.log10(loudest_bus)


def analyze(capture_dir: Path) -> dict:
    wav = capture_dir / "game-audio-mix.wav"
    timeline = json.loads((capture_dir / "game-audio-timeline.json").read_text(encoding="utf-8"))
    gains = timeline.get("volume_settings") or DEFAULT_GAINS
    duration = float(timeline["duration_seconds"])
    wav_seconds = float(subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", str(wav)],
                                       capture_output=True, text=True, timeout=60).stdout.strip())
    scale = wav_seconds / duration  # PCM clock can trail wall time slightly
    offset = full_slider_offset_db(gains)
    events = {}
    for event in timeline["events"]:
        events.setdefault(event["game"], {})[event["event"]] = float(event["seconds"]) * scale
    games = {}
    for game, marks in events.items():
        if "burst_start" not in marks or "music" not in marks:
            continue
        before = meter(wav, marks["music"] - 1.0, 1.0)
        burst = meter(wav, marks["burst_start"], marks["burst_end"] - marks["burst_start"])
        games[game] = {
            "music_momentary_max": before["momentary_max"], "burst_momentary_max": burst["momentary_max"],
            "burst_true_peak_captured": burst["true_peak"], "burst_true_peak_full_sliders": round(burst["true_peak"] + offset, 2),
            "spike_lu": round(burst["momentary_max"] - before["momentary_max"], 2),
        }
        games[game]["ok"] = games[game]["burst_true_peak_full_sliders"] <= TRUE_PEAK_LIMIT_DBTP
    overall = meter(wav)
    at_full = all(abs(float(gains[key]) - 1.0) < 1e-6 for key in ("master", "music", "sfx"))
    # Integrated loudness is judged only on a real full-volume capture; scaling a mix of
    # buses with different slider gains cannot reproduce it.
    reference_ok = abs(overall["integrated"] - REFERENCE_LUFS) <= REFERENCE_TOLERANCE_LU if at_full else None
    return {"games": games, "volume_settings": gains, "integrated_captured": overall["integrated"],
            "reference_ok": reference_ok,
            "loudness_range": overall["loudness_range"], "loudness_range_ok": overall["loudness_range"] <= MAX_LOUDNESS_RANGE_LU,
            "full_slider_peak_offset_db": round(offset, 2), "pcm_to_wall_scale": round(scale, 5)}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("capture_dir", type=Path)
    args = parser.parse_args()
    result = analyze(args.capture_dir)
    print(json.dumps(result, ensure_ascii=False, indent=2))
    ok = result["reference_ok"] is not False and result["loudness_range_ok"] and result["games"] and all(game["ok"] for game in result["games"].values())
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
