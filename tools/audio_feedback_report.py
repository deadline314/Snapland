"""Measure whether each set of feedback sounds can be told apart.

For every feedback set (the shared island/game set and each game's own set) this reads
the shipped WAVs and reports duration above -40 dBFS, spectral centroid (brightness),
and pitch direction (centroid of the second half versus the first). Two sounds in a set
count as distinct when at least one cue differs clearly:

* brightness: at least half an octave apart (|log2 ratio| >= 0.5),
* length: one is at least 1.5x the other,
* contour: their pitch glides differ by at least half an octave (a rising chirp
  against a steady or falling tone).

These are measurable cues, not a listening verdict. Run with --json for the full table.
"""
from __future__ import annotations

import argparse
import itertools
import json
import math
import wave
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
PROFILES = ROOT / "game/data/game_audio.json"
SHARED_SET = {
    "interact": "assets/audio/ui_click.wav",
    "success": "assets/audio/cc0/game_hit.wav",
    "miss": "assets/audio/soft_error.wav",
    "shutter": "assets/audio/photo_shutter.wav",
    "result": "assets/audio/quest_complete.wav",
}
SILENCE_DB = -40.0
BRIGHTNESS_OCTAVES = 0.5
LENGTH_RATIO = 1.5
CONTOUR_GAP_OCTAVES = 0.5


def _samples(path: Path) -> tuple[np.ndarray, int]:
    with wave.open(str(path), "rb") as handle:
        rate, channels, width = handle.getframerate(), handle.getnchannels(), handle.getsampwidth()
        if width != 2:
            raise ValueError(f"{path}: expected 16-bit PCM")
        data = np.frombuffer(handle.readframes(handle.getnframes()), dtype=np.int16).astype(np.float64) / 32768.0
    return data.reshape(-1, channels).mean(axis=1), rate


def _centroid(segment: np.ndarray, rate: int) -> float:
    if segment.size < 32:
        return 0.0
    spectrum = np.abs(np.fft.rfft(segment * np.hanning(segment.size)))
    freqs = np.fft.rfftfreq(segment.size, 1.0 / rate)
    total = spectrum.sum()
    return float((freqs * spectrum).sum() / total) if total > 0 else 0.0


def features(path: Path) -> dict:
    mono, rate = _samples(path)
    peak = float(np.abs(mono).max()) if mono.size else 0.0
    threshold = peak * 10 ** (SILENCE_DB / 20.0)
    audible = np.nonzero(np.abs(mono) > threshold)[0]
    if audible.size == 0:
        return {"duration_s": 0.0, "centroid_hz": 0.0, "direction_octaves": 0.0}
    body = mono[audible[0]:audible[-1] + 1]
    half = body.size // 2
    first, second = _centroid(body[:half], rate), _centroid(body[half:], rate)
    direction = math.log2(second / first) if first > 0 and second > 0 else 0.0
    return {"duration_s": round(body.size / rate, 3), "centroid_hz": round(_centroid(body, rate), 1),
            "direction_octaves": round(direction, 3)}


def distinct(a: dict, b: dict) -> list[str]:
    cues = []
    if a["centroid_hz"] > 0 and b["centroid_hz"] > 0 and abs(math.log2(a["centroid_hz"] / b["centroid_hz"])) >= BRIGHTNESS_OCTAVES:
        cues.append("brightness")
    short, long = sorted([a["duration_s"], b["duration_s"]])
    if short > 0 and long / short >= LENGTH_RATIO:
        cues.append("length")
    if abs(a["direction_octaves"] - b["direction_octaves"]) >= CONTOUR_GAP_OCTAVES:
        cues.append("contour")
    return cues


def feedback_sets() -> dict[str, dict[str, str]]:
    sets = {"shared": dict(SHARED_SET)}
    for game_id, profile in json.loads(PROFILES.read_text(encoding="utf-8"))["games"].items():
        sets[game_id] = {kind: path.removeprefix("res://") for kind, path in profile.get("sfx", {}).items()}
    return sets


def report() -> dict:
    result = {}
    for name, members in feedback_sets().items():
        measured = {kind: features(ROOT / path) for kind, path in members.items()}
        pairs = {f"{x}/{y}": distinct(measured[x], measured[y]) for x, y in itertools.combinations(sorted(measured), 2)}
        result[name] = {"sounds": measured, "pairs": pairs, "indistinct": [pair for pair, cues in pairs.items() if not cues]}
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--json", action="store_true", help="print the full measurement table")
    args = parser.parse_args()
    data = report()
    if args.json:
        print(json.dumps(data, ensure_ascii=False, indent=2))
    else:
        for name, entry in data.items():
            print(f"{name}: {'all distinct' if not entry['indistinct'] else 'indistinct ' + ', '.join(entry['indistinct'])}")
    return 0 if all(not entry["indistinct"] for entry in data.values()) else 1


if __name__ == "__main__":
    raise SystemExit(main())
