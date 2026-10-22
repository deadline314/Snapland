"""Validate authoring-only garment guides against actual required production cels.

This module does not equip or enable an outfit. Missing cels always keep readiness
false, even when the provided authoring preview is structurally valid.
"""
from __future__ import annotations
import hashlib
import json
import math
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_GUIDE = ROOT / 'tools/island_avatar/garments/mustard-front-guide.json'
IDLE_GUIDE = ROOT / 'tools/island_avatar/garments/mustard-idle-eight-guide.json'

def _numbers(value: object, count: int, label: str) -> list[float]:
    if not isinstance(value, list) or len(value) != count or any(isinstance(n, bool) or not isinstance(n, (int, float)) or not math.isfinite(n) for n in value):
        raise ValueError(f'{label}: expected {count} finite numbers')
    return value

def _point(value: object, size: list[int], label: str) -> None:
    p = _numbers(value, 2, label)
    if not all(0 <= p[i] < size[i] for i in range(2)):
        raise ValueError(f'{label}: point outside its fixed canvas')

def _bones(value: object, size: list[int], label: str) -> None:
    if not isinstance(value, list) or len(value) != 2:
        raise ValueError(f'{label}: both sleeve guides are required')
    for side, arm in enumerate(value):
        if not isinstance(arm, list) or len(arm) != 3:
            raise ValueError(f'{label}/{side}: shoulder, elbow and wrist are required')
        for p in arm:
            _point(p, size, label)
        if any(math.dist(arm[i], arm[i + 1]) < 1 for i in range(2)):
            raise ValueError(f'{label}/{side}: zero-length or subpixel bone')

def _atlas(guide: dict, root: Path, prefix: str = '') -> list[int]:
    size = _numbers(guide.get(prefix + 'atlas_size'), 2, prefix + 'atlas_size')
    if any(n != int(n) or n < 1 or n > 4096 for n in size) or math.prod(size) > 8388608:
        raise ValueError(prefix + 'atlas exceeds the source image budget')
    name = guide.get(prefix + 'atlas')
    if not isinstance(name, str) or Path(name).is_absolute() or '..' in Path(name).parts:
        raise ValueError(prefix + 'atlas must be a repository-relative source')
    path = root / name
    if not path.is_file() or hashlib.sha256(path.read_bytes()).hexdigest() != guide.get(prefix + 'atlas_sha256'):
        raise ValueError(prefix + 'garment source changed or is missing; artist review is required')
    raw = path.read_bytes()
    if raw[:8] != b'\x89PNG\r\n\x1a\n' or len(raw) < 24 or list(int.from_bytes(raw[i:i + 4], 'big') for i in (16, 20)) != size:
        raise ValueError(prefix + 'garment PNG dimensions disagree with its source record')
    return size

def _region(value: object, size: list[int], label: str) -> list[int]:
    region = _numbers(value, 4, label)
    if any(n != int(n) for n in region) or min(region[:2]) < 0 or min(region[2:]) < 1 or any(region[i] + region[i + 2] > size[i] for i in range(2)):
        raise ValueError(label + ': garment cel is outside the atlas')
    return region[2:]

def _spans(value: object, label: str) -> None:
    if not isinstance(value, list):
        raise ValueError(label + ': explicit original foreground spans are required')
    for span in value:
        y, lo, hi = _numbers(span, 3, label)
        if any(n != int(n) for n in (y, lo, hi)) or not 0 <= y < 360 or not 0 <= lo <= hi < 280:
            raise ValueError(label + ': foreground span outside fixed original canvas')

def validate(guide: dict, required: dict, root: Path = ROOT) -> dict:
    if not isinstance(guide, dict):
        raise ValueError('garment guide must be an object')
    if guide.get('schema_version') != 1 or guide.get('status') != 'inspection_only':
        raise ValueError('garment guides must remain explicitly inspection_only')
    if not isinstance(guide.get('outfit'), str) or re.fullmatch(r'[a-z][a-z0-9-]{1,79}', guide['outfit']) is None:
        raise ValueError('garment outfit must have a stable nonempty identifier')
    if guide.get('actor') != 'traveller' or guide.get('canvas') != [280, 360]:
        raise ValueError('garment wearer must use the fixed traveller canvas')
    construction = guide.get('construction', 'coat')
    if construction not in ['coat', 'sleeveless_overlay']:
        raise ValueError('unsupported garment construction')
    width_scale = _numbers([guide.get('width_scale')], 1, 'width_scale')[0]
    radius = _numbers([guide.get('source_arm_radius')], 1, 'source_arm_radius')[0]
    torso_scale = _numbers(guide.get('torso_scale', [width_scale, width_scale]), 2, 'torso_scale')
    if any(not 0.05 <= n <= 4 for n in torso_scale):
        raise ValueError('torso scale is outside authoring bounds')
    if not 0.05 <= width_scale <= 4 or not 1 <= radius <= 128:
        raise ValueError('garment scale or sleeve corridor is outside authoring bounds')
    # Header checks avoid an optional imaging dependency in verification/CI.
    atlas_size = _atlas(guide, root)
    separate_body = any(k.startswith('body_atlas') for k in guide)
    body_size = _atlas(guide, root, 'body_') if separate_body else atlas_size
    if construction == 'sleeveless_overlay' and not separate_body:
        raise ValueError('a sleeveless overlay requires its own uninterrupted torso source')
    expected = {(action, direction, frame) for action, dirs in required.items() for direction, count in dirs.items() for frame in range(count)}
    rows = guide.get('frames')
    if not isinstance(rows, list) or not rows:
        raise ValueError('at least one explicit authoring cel is required')
    seen = set()
    for row in rows:
        if not isinstance(row, dict):
            raise ValueError('every authoring cel must be an object')
        key = (row.get('action'), row.get('direction'), row.get('frame'))
        if row.get('actor') != 'traveller' or not isinstance(key[0], str) or not isinstance(key[1], str) or isinstance(key[2], bool) or not isinstance(key[2], int) or key not in expected:
            raise ValueError(f'{key}: unknown required pose')
        if key in seen:
            raise ValueError(f'{key}: duplicate cel cannot fill a missing pose')
        seen.add(key)
        signature = row.get('source_pixel_sha256')
        if not isinstance(signature, str) or len(signature) != 64 or any(c not in '0123456789abcdef' for c in signature):
            raise ValueError(f'{key}: exact original wearer signature is required')
        size = _region(row.get('atlas_region'), atlas_size, f'{key}/atlas_region')
        torso_size = _region(row.get('body_atlas_region'), body_size, f'{key}/body_atlas_region') if separate_body else size
        if not separate_body and 'body_atlas_region' in row:
            raise ValueError(f'{key}: body atlas metadata is required for a separate body region')
        _point(row.get('source_root'), torso_size, f'{key}/source_root')
        _point(row.get('target_root'), [280, 360], f'{key}/target_root')
        polygon = row.get('body_polygon')
        if not isinstance(polygon, list) or len(polygon) < 3:
            raise ValueError(f'{key}: explicit torso ownership polygon is required')
        for p in polygon:
            _point(p, torso_size, f'{key}/torso')
        if construction == 'coat':
            _bones(row.get('source_arms'), size, f'{key}/source_arms')
            _bones(row.get('target_arms'), [280, 360], f'{key}/target_arms')
        else:
            arms = row.get('original_arm_spans')
            if not isinstance(arms, list) or len(arms) != 2 or any(not arm for arm in arms):
                raise ValueError(f'{key}: both original arm ownership guides are required')
            for side, arm in enumerate(arms):
                _spans(arm, f'{key}/original_arm/{side}')
        order = row.get('part_order')
        expected_order = ['arm_0', 'arm_1', 'body'] if construction == 'coat' else ['body']
        if not isinstance(order, list) or not all(isinstance(part, str) for part in order) or sorted(order) != expected_order:
            raise ValueError(f'{key}: explicit body and sleeve order is required')
        mesh_regions = row.get('arm_mesh_regions')
        owner_bounds = row.get('arm_owner_bounds')
        if construction == 'coat' and (not isinstance(mesh_regions, list) or len(mesh_regions) != 2 or not isinstance(owner_bounds, list) or len(owner_bounds) != 2):
            raise ValueError(f'{key}: two explicit source sleeve regions are required')
        for mesh, bounds in zip(mesh_regions, owner_bounds) if construction == 'coat' else []:
            x, y, w, h = _numbers(mesh, 4, f'{key}/sleeve mesh')
            lo, hi = _numbers(bounds, 2, f'{key}/sleeve ownership')
            if any(n != int(n) for n in (x, y, w, h)) or x < 0 or y < 0 or w < 1 or h < 1 or x + w > size[0] or y + h > size[1] or not 0 <= lo < hi <= size[0]:
                raise ValueError(f'{key}: invalid source sleeve region')
        _spans(row.get('protection_spans'), f'{key}/foreground span')
        protection = row.get('protection')
        if not isinstance(protection, dict) or not {'head', 'feet'}.issubset(protection):
            raise ValueError(f'{key}: explicit original head and foot ownership is required')
        unchanged = row.get('unchanged_regions')
        if not isinstance(unchanged, list) or not unchanged:
            raise ValueError(f'{key}: at least one original-pixel equality region is required')
        regions = [*protection.values(), *unchanged, row.get('draw_clip')]
        for protected in regions:
            x, y, w, h = _numbers(protected, 4, f'{key}/region')
            if any(n != int(n) for n in (x, y, w, h)) or x < 0 or y < 0 or w < 1 or h < 1 or x + w > 280 or y + h > 360:
                raise ValueError(f'{key}: region outside fixed wearer canvas')
    return _coverage(required, seen, root)


def _coverage(required: dict, seen: set, root: Path) -> dict:
    expected = {(a, d, f) for a, dirs in required.items() for d, count in dirs.items() for f in range(count)}
    missing = sorted(expected - seen)
    # Read the real renderer inventory rather than treating the authored table
    # as the entire runtime. ParkWorld keeps a three-frame legacy path when an
    # action has no authored direction at all; these are requests, not new art.
    renderer = (root / 'game/world/avatar_renderer.gd').read_text()
    def inventory(name: str) -> list[str]:
        match = re.search(r'^const ' + name + r' := (\[[^\n]+\])$', renderer, re.MULTILINE)
        if match is None:
            raise ValueError('runtime action inventory changed; review fallback coverage')
        return json.loads(match[1])
    fallback_requests = [{'action': a, 'direction': d, 'frame': f}
                         for a in inventory('ACTIONS') if not required.get(a)
                         for d in inventory('WALK_DIRECTIONS') for f in range(3)]
    return {'status': 'inspection_only', 'required': len(expected), 'provided': len(seen),
            'missing_count': len(missing), 'authored_coverage_complete': not missing,
            'runtime_fallback_request_count': len(fallback_requests),
            'runtime_fallback_requests': fallback_requests,
            'runtime_fallbacks_are_authored_art': False,
            'coverage_complete': not missing and not fallback_requests,
            'ready_for_wardrobe': False,
            'missing': [{'action': a, 'direction': d, 'frame': f} for a, d, f in missing]}


def validate_collection(guides: list[dict], required: dict, root: Path = ROOT) -> dict:
    if not isinstance(guides, list) or not guides:
        raise ValueError('at least one validated garment guide is required')
    seen: set = set()
    outfit = None
    for guide in guides:
        validate(guide, required, root)
        if outfit is not None and guide['outfit'] != outfit:
            raise ValueError('different garments cannot combine their pose coverage')
        outfit = guide['outfit']
        for row in guide['frames']:
            key = (row['action'], row['direction'], row['frame'])
            if key in seen:
                raise ValueError(f'{key}: duplicate cel across garment guides')
            seen.add(key)
    report = _coverage(required, seen, root)
    report.update(outfit=outfit, source_guides=len(guides))
    return report


def main() -> None:
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--guide', type=Path, action='append', help='repeat to report the union of validated source atlases')
    args = parser.parse_args()
    required = json.loads((ROOT / 'assets/characters/complete-animation-regions.json').read_text())['outfit_required_poses']['traveller']
    guides = [json.loads(path.read_text()) for path in (args.guide or [DEFAULT_GUIDE])]
    report = validate(guides[0], required) if len(guides) == 1 else validate_collection(guides, required)
    print(json.dumps(report, ensure_ascii=False, indent=2))

if __name__ == '__main__':
    main()
