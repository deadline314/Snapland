"""Bake an explicitly reviewed clothing-only preview on immutable original cels.

Every run needs a fresh isolated profile parent. This authoring entry never
registers a wardrobe item, including when its coverage happens to be complete.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import os
from pathlib import Path
import sys
import subprocess

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))
from tools.godot_entrypoints import run_validated_godot
from tools.island_avatar.garment_manifest import DEFAULT_GUIDE, validate


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--guide', type=Path, default=DEFAULT_GUIDE)
    parser.add_argument('--project', type=Path, default=ROOT)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--profile', type=Path, required=True)
    parser.add_argument('--verify-live-fallback', action='store_true', help='verify that this inspection-only id retains every live original cel and is absent from the wardrobe')
    args = parser.parse_args()
    guide = json.loads(args.guide.read_text())
    required = json.loads((ROOT / 'assets/characters/complete-animation-regions.json').read_text())['outfit_required_poses']['traveller']
    coverage = validate(guide, required)
    profile = args.profile
    if not profile.is_absolute() or profile.parent.exists():
        parser.error('use an absolute profile path in a fresh parent directory')
    profile.parent.mkdir(parents=True)
    snapshot = profile.parent / 'validated-guide.json'
    snapshot.write_text(json.dumps(guide, ensure_ascii=False, indent=2) + '\n')
    (profile.parent / 'coverage.json').write_text(json.dumps(coverage, ensure_ascii=False, indent=2) + '\n')
    script = 'check_garment_fallback.gd' if args.verify_live_fallback else 'build_garment_layers.gd'
    cmd = [args.godot, '--headless', '--path', str(args.project.resolve()), '--audio-driver', 'Dummy', '--rendering-method', 'gl_compatibility', '--log-file', str(profile.parent / 'engine.log'), '--script', 'res://tools/island_avatar/' + script]
    env = dict(os.environ, SNAPLAND_SAVE_PATH=str(profile), SNAPLAND_GARMENT_GUIDE=str(snapshot), SNAPLAND_GARMENT_GUIDE_SHA256=hashlib.sha256(snapshot.read_bytes()).hexdigest(), SNAPLAND_GARMENT_REQUIRED_COUNT=str(coverage['required']), SNAPLAND_GARMENT_FALLBACK_COUNT=str(coverage['runtime_fallback_request_count']))
    try:
        result = run_validated_godot(args.project.resolve(), cmd, env, 60)
    except subprocess.TimeoutExpired as exc:
        chunks = [exc.stdout or '', exc.stderr or '']
        log = ''.join(c.decode(errors='replace') if isinstance(c, bytes) else c for c in chunks)
        (profile.parent / 'result.log').write_text(log)
        (profile.parent / 'result.json').write_text(json.dumps({'exit': None, 'errors': log.count('ERROR:'), 'completed': False, 'timeout_seconds': 60}, indent=2) + '\n')
        print('REJECTED: garment authoring exceeded its finite 60-second guard', file=sys.stderr)
        return 1
    log = result.stdout + result.stderr
    (profile.parent / 'result.log').write_text(log)
    prefix = 'PASS: live garment fallback ' if args.verify_live_fallback else 'PASS: garment-only authoring bake '
    ok = result.returncode == 0 and 'ERROR:' not in log and prefix in log
    (profile.parent / 'result.json').write_text(json.dumps({'exit': result.returncode, 'errors': log.count('ERROR:'), 'completed': ok}, indent=2) + '\n')
    print(log, end='')
    return 0 if ok else 1

if __name__ == '__main__':
    raise SystemExit(main())
