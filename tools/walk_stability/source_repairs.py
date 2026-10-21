"""Replay bounded, reviewed pixel-art corrections without moving the character.

The original generated sources remain immutable. A correction must match its
recorded lower-body input and output; head, feet and camera/hands stay original.
This is offline art compilation, never runtime anatomy or color inference.
"""
from pathlib import Path
import hashlib
import json
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
RECIPE = ROOT / 'tools/walk_stability/repairs/manifest.json'


def visible_digest(image: Image.Image, seam: int) -> str:
    if type(seam) is not int or not 0 < seam < image.height:
        raise ValueError('repair boundary must retain real lower-body pixels')
    pixels = bytearray(image.convert('RGBA').crop((0, seam, image.width, image.height)).tobytes())
    for i in range(0, len(pixels), 4):
        if pixels[i + 3] < 128:
            pixels[i:i + 3] = b'\0\0\0'
    return hashlib.sha256(pixels).hexdigest()


def _region(value, canvas, label):
    if not isinstance(value, list) or len(value) != 4 or any(type(v) is not int for v in value):
        raise ValueError(label + ': four integer coordinates required')
    x, y, w, h = value
    if min(x, y) < 0 or min(w, h) < 1 or x + w > canvas[0] or y + h > canvas[1]:
        raise ValueError(label + ': outside fixed original canvas')
    return x, y, x + w, y + h


def _source(root: Path, name, digest):
    if not isinstance(name, str) or Path(name).is_absolute() or '..' in Path(name).parts:
        raise ValueError('repair source must be repository-relative')
    source = (root / name).resolve()
    if not source.is_relative_to(root.resolve()) or not source.is_file() or hashlib.sha256(source.read_bytes()).hexdigest() != digest:
        raise ValueError('reviewed repair source changed or is missing')
    return source


def load_recipe(path: Path = RECIPE) -> dict:
    recipe = json.loads(path.read_text())
    if not isinstance(recipe, dict) or recipe.get('schema_version') != 1 or not isinstance(recipe.get('repairs'), list):
        raise ValueError('invalid reviewed source repair recipe')
    return recipe


def apply_repairs(image: Image.Image, sequence: str, frame: int, recipe: dict, root: Path = ROOT) -> Image.Image:
    if not isinstance(recipe, dict) or recipe.get('schema_version') != 1 or not isinstance(recipe.get('repairs'), list):
        raise ValueError('invalid reviewed source repair recipe')
    matched = []
    for row in recipe['repairs']:
        if not isinstance(row, dict) or not isinstance(row.get('sequence'), str) or type(row.get('frame')) is not int or row['frame'] < 0:
            raise ValueError('invalid source repair pose identity')
        if row['sequence'] == sequence and row['frame'] == frame: matched.append(row)
    if len(matched) > 1:
        raise ValueError('duplicate repairs cannot overwrite the same source cel')
    if not matched: return image.copy()
    row = matched[0]
    if row.get('review_status') != 'accepted_local_correction' or row.get('canvas') != list(image.size):
        raise ValueError('repair needs review on this fixed original canvas')
    original = image.convert('RGBA')
    box = _region(row.get('region'), image.size, 'repair region')
    if (box[2] - box[0]) * (box[3] - box[1]) > 8192:
        raise ValueError('local repair exceeds its bounded pixel area')
    protected = row.get('protected_regions')
    if not isinstance(protected, dict) or not {'head', 'feet', 'camera_hands'}.issubset(protected):
        raise ValueError('repair must protect original head, feet and camera hands')
    for name, region in protected.items():
        guard = _region(region, image.size, name)
        if max(box[0], guard[0]) < min(box[2], guard[2]) and max(box[1], guard[1]) < min(box[3], guard[3]):
            raise ValueError('repair overlaps protected original ' + name)
    seam = row.get('lower_y')
    if type(seam) is not int or box[1] < seam or visible_digest(original, seam) != row.get('before_lower_visible_sha256'):
        raise ValueError('original repair input changed; artist review is required')
    reference_path = _source(root, row.get('reference'), row.get('reference_png_sha256'))
    reference = Image.open(reference_path).convert('RGBA')
    if reference.size != image.size or visible_digest(reference, seam) != row['before_lower_visible_sha256']:
        raise ValueError('original repair reference disagrees with reviewed input')
    patch_path = _source(root, row.get('patch'), row.get('patch_png_sha256'))
    patch = Image.open(patch_path).convert('RGBA')
    if patch.size != (box[2] - box[0], box[3] - box[1]):
        raise ValueError('repair patch dimensions disagree with its exact region')
    result = original.copy()
    # Copy RGBA, including transparency, rather than blending a removed hand
    # back over its old silhouette. Never resize or recenter the original.
    result.paste(patch, box[:2])
    if visible_digest(result, seam) != row.get('after_lower_visible_sha256'):
        raise ValueError('repair output differs from its reviewed art')
    for name, region in protected.items():
        guard = _region(region, image.size, name)
        if original.crop(guard).tobytes() != result.crop(guard).tobytes():
            raise ValueError('repair changed protected original ' + name)
    return result
