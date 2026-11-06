"""Prepare MIC-3 assets from the exact downloaded source files; no network access.

Requires ffmpeg on PATH. Source URLs and hashes are in assets/audio/cc0/catalog.json.
Run with --source-dir pointing at the downloaded/extracted source directory.
This never runs the legacy composer or changes musical timing/pitch.
"""
from pathlib import Path
import argparse
import array
import hashlib
import json
import math
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def run(*args):
    return subprocess.run(list(args), check=True, capture_output=True, text=True, timeout=120)


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def measure(path):
    result = run('ffmpeg', '-hide_banner', '-i', str(path), '-af',
                 'loudnorm=I=-23:TP=-6:LRA=11:print_format=json', '-f', 'null', '-')
    match = re.findall(r'\{[^{}]*"input_i"[^{}]*\}', result.stderr, re.S)
    if not match:
        raise ValueError(f'No loudness measurement: {path}')
    return json.loads(match[-1])


def bake_loop_crossfade(source, output, seconds):
    """Make the file loop sample-continuously: its last `seconds` blend into its first.

    The result starts `seconds` into the track and ends on the original opening, so a
    plain Ogg loop wraps from the blended tail straight into the next note without a
    click, a gap or a faded ending followed by a sudden restart.
    """
    # Two reads of the same file, not asplit: asplit stalls when one branch ends early.
    graph = (f'[0:a]atrim=start={seconds},asetpts=PTS-STARTPTS[a];'
             f'[1:a]atrim=end={seconds},asetpts=PTS-STARTPTS[b];[a][b]acrossfade=d={seconds}:c1=qsin:c2=qsin[o]')
    run('ffmpeg', '-v', 'error', '-y', '-i', str(source), '-i', str(source), '-filter_complex', graph,
        '-map', '[o]', '-c:a', 'pcm_f32le', str(output))
    if subprocess.run(['ffprobe', '-v', 'error', '-show_entries', 'format=duration', '-of', 'csv=p=0', str(output)],
                      capture_output=True, text=True, timeout=60).stdout.strip() in ('', 'N/A'):
        raise ValueError(f'Loop crossfade produced no audio: {output}')


def _decode_mono(path, rate=44100):
    raw = subprocess.run(['ffmpeg', '-v', 'error', '-i', str(path), '-ac', '1', '-ar', str(rate), '-f', 'f32le', '-'],
                         check=True, capture_output=True, timeout=120).stdout
    samples = array.array('f')
    samples.frombytes(raw)
    return samples


def _level_db(values):
    mean_square = sum(value * value for value in values) / max(1, len(values))
    return 10 * math.log10(mean_square) if mean_square > 0 else -120.0


def measure_loop_seam(path, reference, offset_seconds, rate=44100, window_seconds=0.1):
    """Click size and level change across the shipped loop point.

    `reference` is the unlooped preparation; the loop wraps from its `offset_seconds`
    point back onto itself, so the same level change there is the music, not the seam.
    """
    samples, original = _decode_mono(path, rate), _decode_mono(reference, rate)
    count = int(rate * window_seconds)
    cut = int(rate * offset_seconds)
    if len(samples) < count * 2 or cut < count or len(original) < cut + count:
        raise ValueError(f'Too short to measure a loop seam: {path}')
    seam_step = _level_db(samples[:count]) - _level_db(samples[-count:])
    source_step = _level_db(original[cut:cut + count]) - _level_db(original[cut - count:cut])
    return {'sample_jump': round(abs(samples[-1] - samples[0]), 5), 'seam_level_step_db': round(seam_step, 2),
            'source_level_step_db': round(source_step, 2), 'offset_seconds': offset_seconds,
            'window_seconds': window_seconds}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source-dir', required=True, type=Path)
    parser.add_argument('--ids', nargs='*', default=None,
                        help='prepare only these asset ids; others keep their recorded files and hashes')
    args = parser.parse_args()
    selected = set(args.ids) if args.ids else None
    folder = ROOT / 'assets/audio/cc0'
    catalog = json.loads((folder / 'catalog.json').read_text(encoding='utf-8'))
    if selected is not None:
        unknown = selected - {item['id'] for item in catalog['assets']}
        if unknown:
            raise ValueError(f'Unknown asset ids: {sorted(unknown)}')
    for item in catalog['assets']:
        if selected is not None and item['id'] not in selected:
            continue
        if item.get('preparation') == 'generated-unchanged':
            if sha(ROOT / item['path']) != item['sha256']:
                raise ValueError(f'Generated reference changed: {item["path"]}')
            continue
        source = (args.source_dir / item['source_file']).resolve()
        if not source.is_relative_to(args.source_dir.resolve()):
            raise ValueError(f'Source path escapes source directory: {source}')
        if sha(source) != item['source_sha256']:
            raise ValueError(f'Source hash mismatch: {source}')
        output = (ROOT / item['path']).resolve()
        if not output.is_relative_to(ROOT / 'assets/audio') or output.suffix not in ('.wav', '.ogg'):
            raise ValueError(f'Invalid output path: {output}')
        output.parent.mkdir(parents=True, exist_ok=True)
        filters = item.get('filter', '')
        # Measure the final effect chain before applying a static gain. Never
        # normalize short transients to music LUFS or flatten musical dynamics.
        intermediate = args.source_dir / ('prepared-' + item['id'] + '.wav')
        command = ['ffmpeg', '-v', 'error', '-y', '-i', str(source)]
        if filters:
            command += ['-af', filters]
        command += ['-ar', '44100', '-ac', str(item['channels']), '-c:a', 'pcm_s16le', str(intermediate)]
        # Float intermediate retains peaks above 0 dB from lossy source decoding.
        command[command.index('pcm_s16le')] = 'pcm_f32le'
        run(*command)
        crossfade = float(item.get('loop_crossfade_seconds', 0) or 0)
        unlooped = intermediate
        if crossfade > 0:
            if item['kind'] != 'music':
                raise ValueError(f'Only music loops take a baked crossfade: {item["id"]}')
            looped = args.source_dir / ('looped-' + item['id'] + '.wav')
            bake_loop_crossfade(intermediate, looped, crossfade)
            intermediate = looped
        loud = measure(intermediate)
        peak = float(loud['input_tp'])
        integrated = float(loud['input_i'])
        gain = item['peak_limit_db'] - peak
        if item['kind'] == 'music' and math.isfinite(integrated):
            gain = min(gain, -23.0 - integrated)
        command = ['ffmpeg', '-v', 'error', '-y', '-i', str(intermediate), '-af', f'volume={gain:.6f}dB']
        if output.suffix == '.ogg':
            command += ['-c:a', 'libvorbis', '-q:a', '6']
        else:
            command += ['-c:a', 'pcm_s16le']
        run(*command, str(output))
        item['gain_db'] = round(gain, 6)
        item['sha256'] = sha(output)
        item['bytes'] = output.stat().st_size
        item['measurement'] = measure(output)
        if item['kind'] == 'music' and crossfade > 0:
            item['loop_seam'] = measure_loop_seam(output, unlooped, crossfade)
        print(item['id'], item['bytes'], item['measurement']['input_i'], item['measurement']['input_tp'], flush=True)
    catalog['preparation_tool'] = run('ffmpeg', '-version').stdout.splitlines()[0]
    (folder / 'catalog.json').write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


if __name__ == '__main__':
    main()
