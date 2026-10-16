"""Compile source-bound side-jacket indices offline; review every contact sheet.

No runtime colour segmentation. The retained alpha and every non-cloth pixel stay
in the original cel. This is material annotation, not new clothing artwork.
"""
from __future__ import annotations
import argparse, colorsys, hashlib, json
from pathlib import Path
from PIL import Image, ImageDraw


def canonical_hash(image: Image.Image) -> str:
    data = bytearray(image.convert('RGBA').tobytes())
    for offset in range(0, len(data), 4):
        if data[offset + 3] < 13:
            data[offset:offset + 4] = b'\0' * 4
    return hashlib.sha256(data).hexdigest()


def cloth_indices(image: Image.Image, record: dict) -> list[int]:
    """Offline draft only: fixed side-garment area minus reviewed head ownership."""
    protected = set()
    for span in record['hair_owner_spans']:
        y, start, end = map(int, span)
        protected.update(y * 280 + x for x in range(start, end + 1))
    result = []
    for y in range(160, 290):
        for x in range(40, 240):
            index = y * 280 + x
            if index in protected:
                continue
            red, green, blue, alpha = image.getpixel((x, y))
            hue, saturation, value = colorsys.rgb_to_hsv(red / 255, green / 255, blue / 255)
            # Profile camera metal is desaturated; its dark lens outline is
            # below this side-view luminance floor. The jacket remains vivid.
            min_s, min_v = 0.5, 0.28
            if alpha >= 13 and 0.43 <= hue <= 0.63 and saturation > min_s and value > min_v:
                result.append(index)
    return result


def spans(indices: list[int]) -> list[list[int]]:
    output = []
    for index in indices:
        y, x = divmod(index, 280)
        if output and output[-1][0] == y and output[-1][2] + 1 == x:
            output[-1][2] = x
        else:
            output.append([y, x, x])
    return output


def build(source_dir: Path, output: Path, review: Path) -> dict:
    records = [record for record in json.loads((source_dir / 'sources.json').read_text())
               if record['direction'] in ('left', 'right') and record['action'] in ('walk', 'idle')]
    if len(records) != 24:
        raise ValueError('Exactly 24 authored side-walk/idle cels are required')
    owners = {}
    review.mkdir(parents=True, exist_ok=True)
    for start in range(0, len(records), 8):
        sheet = Image.new('RGB', (280 * 4, 380 * 4), '#243443')
        draw = ImageDraw.Draw(sheet)
        for n, record in enumerate(records[start:start + 8]):
            if not record['head_owner_available']:
                raise ValueError('Missing reviewed source head ownership: ' + record['source'])
            image = Image.open(source_dir / 'sources' / record['source']).convert('RGBA')
            if image.size != (280, 360):
                raise ValueError('Source is not the fixed production canvas')
            indices = cloth_indices(image, record)
            if not indices:
                raise ValueError('No cloth draft: ' + record['source'])
            signature = canonical_hash(image)
            entry = {'cloth_spans': spans(indices)}
            if signature in owners and owners[signature] != entry:
                raise ValueError('Conflicting annotations for identical source pixels')
            owners[signature] = entry
            annotated = image.copy()
            preview = image.copy()
            for index in indices:
                y, x = divmod(index, 280)
                original = image.getpixel((x, y))
                annotated.putpixel((x, y), (255, 0, 190, original[3]))
                ratio = min(1.65, max(0.48, max(original[:3]) / 131))
                preview.putpixel((x, y), (min(255, round(232 * ratio)), min(255, round(121 * ratio)), min(255, round(104 * ratio)), original[3]))
            col, row = n % 4, n // 4 * 2
            for offset, sprite in enumerate([annotated, preview]):
                px, py = col * 280, (row + offset) * 380
                sheet.paste(sprite, (px, py + 20), sprite)
                draw.text((px + 3, py + 3), record['source'] + (' MASK' if offset == 0 else ' coral draft'), fill='white')
        sheet.save(review / f'sheet-{start // 8 + 1:02d}.png')
    result = {'schema_version': 1, 'canvas': [280, 360], 'alpha_cutoff': 13,
              'authoring': 'Reviewed side-only cloth annotation: 24 walk/idle cels. Other actions retain their legacy palette. Not new clothing artwork.',
              'scope': 'left/right walk and dedicated idle only',
              'source_records': [{k: v for k, v in r.items() if k not in ('hair_owner_spans','head_delta','prop_guard_polygons')} for r in records],
              'owners': owners}
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source-dir', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--review-dir', type=Path, required=True)
    args = parser.parse_args()
    result = build(args.source_dir, args.output, args.review_dir)
    print('Drafted', len(result['source_records']), 'cels;', len(result['owners']), 'unique pixel owners; visual review required')

if __name__ == '__main__':
    main()
