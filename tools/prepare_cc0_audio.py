"""Prepare MIC-3 assets from the exact downloaded source files; no network access.

Requires ffmpeg on PATH. Source URLs and hashes are in assets/audio/cc0/catalog.json.
Run with --source-dir pointing at the downloaded/extracted source directory.
This never runs the legacy composer or changes musical timing/pitch.
"""
from pathlib import Path
import argparse
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
        print(item['id'], item['bytes'], item['measurement']['input_i'], item['measurement']['input_tp'], flush=True)
    catalog['preparation_tool'] = run('ffmpeg', '-version').stdout.splitlines()[0]
    (folder / 'catalog.json').write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


if __name__ == '__main__':
    main()
