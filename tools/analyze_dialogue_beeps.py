"""Match dialogue beeps in a Movie Maker capture to the glyphs that were revealed.

Usage: python tools/analyze_dialogue_beeps.py <capture.wav> <island-flow-report.json> <out.json>

The WAV is the PCM track extracted from the review's .avi. Each speaker's beep is a
short sine at a known pitch (AudioDirector.DIALOGUE_BEEP_PITCH_HZ). The report lists
every revealed glyph with its engine frame. This is a technical PCM check, not a
listening test.
"""
from __future__ import annotations

import json
import sys
import wave
from pathlib import Path

import numpy as np

PITCH_HZ = {"票票": 760.0, "小角": 910.0, "阿浪": 620.0, "主角": 700.0}
INTERVAL_MS = {"票票": 54, "小角": 42, "阿浪": 50, "主角": 48}
PUNCTUATION = set("，。！？；：、…—,.!?;:·「」『』（）()《》〈〉“”‘’\"'～~・　 ")
NCC_THRESHOLD = 0.8
ENVIRONMENT_FRAMES = 6


def read_mono(path: Path) -> tuple[np.ndarray, int]:
    with wave.open(str(path), "rb") as handle:
        rate = handle.getframerate()
        channels = handle.getnchannels()
        width = handle.getsampwidth()
        raw = handle.readframes(handle.getnframes())
    dtype = {2: np.int16, 4: np.int32}[width]
    data = np.frombuffer(raw, dtype=dtype).astype(np.float64) / float(np.iinfo(dtype).max)
    if channels > 1:
        data = data.reshape(-1, channels).mean(axis=1)
    return data, rate


def beep_template(pitch: float, rate: int) -> np.ndarray:
    """The exact synthesized beep: 24 ms sine with a 3 ms attack and 6 ms release."""
    t = np.arange(int(0.024 * rate)) / rate
    fade = np.clip(np.minimum(t / 0.003, (0.024 - t) / 0.006), 0.0, 1.0)
    return np.sin(2 * np.pi * pitch * t) * fade


def detect_beeps(samples: np.ndarray, rate: int) -> list[dict]:
    """Matched filter per speaker: normalized correlation with the exact beep shape.

    A lone beep scores ~1; music or noise rarely exceeds the threshold because the
    template is a fixed pitch and envelope. Peaks closer than 30 ms are merged.
    """
    length = len(samples)
    size = 1 << int(np.ceil(np.log2(length + int(0.03 * rate))))
    spectrum = np.fft.rfft(samples, size)
    squared = np.concatenate(([0.0], np.cumsum(samples ** 2)))
    best = np.zeros(length)
    owner = np.full(length, -1)
    names = list(PITCH_HZ)
    for index, name in enumerate(names):
        template = beep_template(PITCH_HZ[name], rate)
        width = len(template)
        correlation = np.fft.irfft(spectrum * np.conj(np.fft.rfft(template, size)), size)[:length]
        local = np.sqrt(np.maximum(squared[np.minimum(np.arange(length) + width, length)] - squared[:length], 1e-12))
        score = correlation / (np.linalg.norm(template) * local)
        better = score > best
        best[better] = score[better]
        owner[better] = index
    onsets: list[dict] = []
    candidates = np.flatnonzero(best >= NCC_THRESHOLD)
    gap = int(0.03 * rate)
    window = int(0.024 * rate)
    for position in candidates:
        if onsets and position - onsets[-1]["sample"] < gap:
            if best[position] > onsets[-1]["score"]:
                onsets[-1].update(sample=int(position), score=float(best[position]), speaker=names[owner[position]])
            continue
        onsets.append({"sample": int(position), "score": float(best[position]), "speaker": names[owner[position]]})
    for onset in onsets:
        chunk = samples[onset["sample"]:onset["sample"] + window]
        onset["time"] = onset["sample"] / rate
        onset["peak"] = float(np.abs(chunk).max()) if len(chunk) else 0.0
    return onsets


def _best_offset(onsets: list[dict], glyphs: list[dict], fps: float) -> int:
    """Engine frame of movie frame 0: the small startup offset that best aligns
    beep onsets with revealed letters (searched, then reported)."""
    letter_frames = {int(g["frame"]) for g in glyphs if not g["skipped"] and g["glyph"] not in PUNCTUATION}
    if not letter_frames or not onsets:
        return 0
    best, best_score = 0, -1
    for offset in sorted(range(-3, 4), key=abs):
        score = sum(1 for o in onsets if any((int(round(o["time"] * fps)) + offset + d) in letter_frames for d in (-1, 0, 1)))
        if score > best_score:
            best, best_score = offset, score
    return best


def main(argv: list[str]) -> int:
    wav_path, report_path, out_path = (Path(value) for value in argv[1:4])
    samples, rate = read_mono(wav_path)
    report = json.loads(report_path.read_text(encoding="utf-8"))
    fps = float(report.get("capture_fps") or 30)
    onsets = detect_beeps(samples, rate)
    glyphs = report.get("glyphs", [])
    first_frame = _best_offset(onsets, glyphs, fps)
    by_frame: dict[int, list[dict]] = {}
    for glyph in glyphs:
        by_frame.setdefault(int(glyph["frame"]) - first_frame, []).append(glyph)

    unmatched = []
    environment = []
    pitch_mismatch = []
    reveal_frames = sorted(by_frame)
    for onset in onsets:
        frame = int(round(onset["time"] * fps))
        nearby = [g for f in range(frame - 2, frame + 2) for g in by_frame.get(f, []) if not g["skipped"] and g["glyph"] not in PUNCTUATION]
        if not nearby:
            # Far from any revealed text, a matching tone belongs to the scene's
            # own sounds; it is reported, but only in-dialogue strays fail.
            # A tone at another speaker's pitch is not this conversation's beep.
            closest = min(reveal_frames, key=lambda f: abs(frame - f), default=None)
            near_speakers = {g["speaker"] for g in by_frame.get(closest, [])} if closest is not None else set()
            stray = closest is not None and abs(frame - closest) <= ENVIRONMENT_FRAMES and onset["speaker"] in near_speakers
            (unmatched if stray else environment).append(round(onset["time"], 3))
        elif onset["speaker"] not in {g["speaker"] for g in nearby}:
            pitch_mismatch.append({"time": round(onset["time"], 3), "detected": onset["speaker"], "speakers": sorted({g["speaker"] for g in nearby})})

    onset_frames = [int(round(o["time"] * fps)) for o in onsets]
    punctuation_only = []
    for frame, items in by_frame.items():
        revealed = [g for g in items if not g["skipped"]]
        if revealed and all(g["glyph"] in PUNCTUATION for g in revealed) and not any(abs(frame - f) <= 1 for f in onset_frames):
            punctuation_only.append(frame)
    punctuation_with_beep = []
    for frame, items in by_frame.items():
        revealed = [g for g in items if not g["skipped"]]
        if revealed and all(g["glyph"] in PUNCTUATION for g in revealed):
            neighbours = [g for f in range(frame - 1, frame + 2) for g in by_frame.get(f, []) if not g["skipped"] and g["glyph"] not in PUNCTUATION]
            if not neighbours and any(abs(frame - f) <= 1 for f in onset_frames):
                punctuation_with_beep.append(frame)

    skipped_frames = sorted({int(g["frame"]) - first_frame for g in glyphs if g["skipped"]})
    skip_bursts = []
    for frame in skipped_frames:
        burst = [f for f in onset_frames if frame <= f <= frame + 3]
        if len(burst) > 1:
            skip_bursts.append({"frame": frame, "beeps": len(burst)})

    min_gap_ms = None
    for previous, current in zip(onsets, onsets[1:]):
        gap = (current["time"] - previous["time"]) * 1000.0
        min_gap_ms = gap if min_gap_ms is None else min(min_gap_ms, gap)

    volume = []
    for segment in report.get("volume_segments", []):
        start = (int(segment["start_frame"]) - first_frame) / fps
        end = (int(segment["end_frame"]) - first_frame) / fps
        peaks = [o["peak"] for o in onsets if start <= o["time"] <= end]
        volume.append({"sfx_volume": segment["sfx_volume"], "beeps": len(peaks), "median_peak": float(np.median(peaks)) if peaks else 0.0})
    ratio = None
    if len(volume) >= 2 and volume[0]["median_peak"] > 0:
        ratio = volume[1]["median_peak"] / volume[0]["median_peak"]

    result = {
        "sample_rate": rate, "seconds": round(len(samples) / rate, 2), "fps": fps, "engine_frame_offset": first_frame,
        "beep_onsets": len(onsets), "revealed_glyphs": sum(1 for g in glyphs if not g["skipped"]),
        "skipped_glyphs": sum(1 for g in glyphs if g["skipped"]),
        "onsets_without_revealed_letter": unmatched,
        "tones_outside_dialogue_reveal": environment,
        "onsets_with_other_speaker_pitch": pitch_mismatch,
        "punctuation_only_frames_silent": len(punctuation_only),
        "punctuation_only_frames_with_beep": punctuation_with_beep,
        "skip_reveal_bursts": skip_bursts,
        "minimum_gap_ms": round(min_gap_ms, 1) if min_gap_ms is not None else None,
        "volume_segments": volume, "half_to_full_peak_ratio": round(ratio, 3) if ratio is not None else None,
        "note": "PCM/time alignment check only; not a listening test.",
    }
    Path(out_path).write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps({k: result[k] for k in ("beep_onsets", "revealed_glyphs", "half_to_full_peak_ratio", "minimum_gap_ms")}, ensure_ascii=False))
    ok = not unmatched and not pitch_mismatch and not punctuation_with_beep and not skip_bursts
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
