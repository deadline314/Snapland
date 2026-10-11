from pathlib import Path
import math
import random
import struct
import wave

RATE = 22050
OUT = Path(__file__).resolve().parents[2] / 'assets' / 'audio'
OUT.mkdir(parents=True, exist_ok=True)

# All audio is composed in this script. Equal temperament, gentle triangle-like
# partials, and restrained peaks keep the loops soft and easy to layer.
CHORDS = [[60, 64, 67], [55, 59, 62], [57, 60, 64], [53, 57, 60]]
MELODIES = {
    'plaza': [72, None, 76, 79, None, 76, 74, None, 71, None, 74, 76, None, 74, 71, None,
             69, None, 72, 76, None, 72, 69, None, 67, None, 71, 74, None, 71, 67, None],
    'game':  [79, None, 76, None, 83, None, 79, 76, None, 74, 79, None, 76, None, 72, None,
             76, None, 79, None, 84, None, 81, 79, None, 76, 79, None, 74, None, 71, None],
    'harbor':[67, None, 72, 74, None, 72, 76, None, 79, None, 76, 74, None, 72, 69, None,
             72, None, 76, 79, None, 76, 74, None, 72, None, 69, 67, None, 69, 72, None],
}

def hz(note):
    return 440.0 * 2.0 ** ((note - 69) / 12.0)

def render_music(name, melody):
    bpm = 88
    beat = 60.0 / bpm
    bar = 4 * beat
    duration = 16 * bar
    count = round(duration * RATE)
    left = [0.0] * count
    right = [0.0] * count

    def add_note(start, length, midi, amp, pan, tone='pluck'):
        first = round(start * RATE)
        last = min(count, round((start + length) * RATE))
        frequency = hz(midi)
        for i in range(first, last):
            t = (i - first) / RATE
            if tone == 'pad':
                attack = min(1.0, t / 0.18)
                env = attack * math.exp(-t / max(0.1, length * 1.8))
                sample = (math.sin(2 * math.pi * frequency * t) +
                          0.22 * math.sin(2 * math.pi * frequency * 2 * t)) * env * amp
            else:
                env = (1.0 - math.exp(-t / 0.012)) * math.exp(-t / max(0.045, length * 0.45))
                sample = (math.sin(2 * math.pi * frequency * t) +
                          0.24 * math.sin(2 * math.pi * frequency * 2 * t) +
                          0.07 * math.sin(2 * math.pi * frequency * 3 * t)) * env * amp
            left[i] += sample * math.sqrt(1.0 - pan)
            right[i] += sample * math.sqrt(1.0 + pan)

    for bar_index in range(16):
        chord = CHORDS[bar_index % 4]
        t0 = bar_index * bar
        # Slow, quiet two-note bed leaves space for dialogue and play.
        add_note(t0, bar * 0.96, chord[0] - 12, 0.085, -0.12, 'pad')
        add_note(t0, bar * 0.96, chord[1], 0.050, 0.12, 'pad')
        for beat_index in range(4):
            t = t0 + beat_index * beat
            if beat_index in (0, 2):
                add_note(t, beat * 0.56, chord[2], 0.075, 0.10 if beat_index == 0 else -0.10)
            elif beat_index == 1:
                add_note(t, beat * 0.45, chord[1] + 12, 0.042, 0.16)
        # Two eighth-note melody slots per beat; rests make the tune breathe.
        for slot in range(2):
            note = melody[bar_index * 2 + slot]
            if note is not None:
                add_note(t0 + slot * beat * 2, beat * 0.62, note, 0.105, -0.18 if slot == 0 else 0.18)

    # A short equal-power seam crossfade makes both ends meet without a click.
    seam = round(0.045 * RATE)
    for i in range(seam):
        a = (i + 1) / (seam + 1)
        j = count - seam + i
        l, r = left[j], right[j]
        left[i] = left[i] * a + l * (1 - a)
        right[i] = right[i] * a + r * (1 - a)
    peak = max(max(map(abs, left)), max(map(abs, right)), 1e-9)
    scale = 0.72 / peak
    with wave.open(str(OUT / f'{name}.wav'), 'wb') as file:
        file.setnchannels(2)
        file.setsampwidth(2)
        file.setframerate(RATE)
        frames = bytearray()
        for l, r in zip(left, right):
            frames.extend(struct.pack('<hh', int(max(-1, min(1, l * scale)) * 32767),
                                      int(max(-1, min(1, r * scale)) * 32767)))
        file.writeframes(frames)

def render_ambience():
    # Filtered deterministic noise plus sparse soft wind tones; seamless loop.
    rng = random.Random(41)
    seconds = 12.0
    n = round(seconds * RATE)
    low = 0.0
    values = []
    for i in range(n):
        raw = rng.uniform(-1.0, 1.0)
        low += 0.018 * (raw - low)
        t = i / RATE
        breeze = 0.018 * math.sin(2 * math.pi * 0.19 * t) + 0.012 * math.sin(2 * math.pi * 0.31 * t + 0.7)
        values.append(low * 0.14 + breeze)
    fade = round(0.35 * RATE)
    for i in range(fade):
        a = (i + 1) / (fade + 1)
        j = n - fade + i
        values[i] = values[i] * a + values[j] * (1 - a)
    with wave.open(str(OUT / 'plaza_ambience.wav'), 'wb') as file:
        file.setnchannels(1)
        file.setsampwidth(2)
        file.setframerate(RATE)
        file.writeframes(b''.join(struct.pack('<h', int(max(-1, min(1, x)) * 32767)) for x in values))

def render_sfx(filename, notes, seconds, noise=0.0):
    rng = random.Random(len(filename))
    n = round(seconds * RATE)
    with wave.open(str(OUT / filename), 'wb') as file:
        file.setnchannels(1)
        file.setsampwidth(2)
        file.setframerate(RATE)
        frames = bytearray()
        for i in range(n):
            t = i / RATE
            sample = 0.0
            for note, at, dur, amp in notes:
                local = t - at
                if 0 <= local < dur:
                    env = math.sin(math.pi * local / dur) ** 1.4
                    sample += math.sin(2 * math.pi * hz(note) * local) * env * amp
            sample += rng.uniform(-noise, noise) * math.exp(-t * 45)
            frames.extend(struct.pack('<h', int(max(-0.95, min(0.95, sample)) * 32767)))
        file.writeframes(frames)

for context, melody in MELODIES.items():
    render_music(context, melody)
render_ambience()
render_sfx('ui_click.wav', [(84, 0.0, 0.055, 0.32)], 0.07)
render_sfx('photo_shutter.wav', [(77, 0.0, 0.10, 0.22), (64, 0.055, 0.12, 0.12)], 0.20, noise=0.07)
render_sfx('quest_complete.wav', [(72, 0.0, 0.16, 0.18), (76, 0.12, 0.18, 0.17), (79, 0.25, 0.28, 0.16)], 0.58)

render_sfx('soft_error.wav', [(57, 0.0, 0.11, 0.12), (53, 0.09, 0.14, 0.10)], 0.27)
for index, pitch in enumerate([72, 76, 79, 84]):
    render_sfx(f'note_{index}.wav', [(pitch, 0.0, 0.27, 0.24)], 0.30)
