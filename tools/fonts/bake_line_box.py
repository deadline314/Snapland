"""Bake the interface's 4:3 line box into an upstream OFL font (ART-64).

The game lays text out on a line box of 4/3 em (Fusion Pixel's native metrics).
jf open huninn's own box is a tight 1.0 em and Fredoka's 1.21 em; baking the
taller box into the font's vertical metrics keeps every size and every display
oversampling consistent. Glyph outlines and advances are untouched; the extra
space is split above and below so glyphs stay centred.

Changing a font makes it a Modified Version under the SIL OFL, and jf open huninn
reserves the names "open huninn" and "huninn", so the output is renamed. The
upstream copyright and licence strings are kept.

    python tools/fonts/bake_line_box.py <upstream.ttf> <out.ttf> "<Family Name>" "<PostScriptName>"
"""
from __future__ import annotations

import sys

from fontTools.ttLib import TTFont

LINE_EM = 4.0 / 3.0
# name IDs that carry the family/full/PostScript names and the unique ID.
FAMILY_IDS = (1, 16)
SUBFAMILY_IDS = (2, 17)


def bake(source: str, target: str, family: str, postscript: str) -> dict:
    font = TTFont(source)
    upm = font["head"].unitsPerEm
    hhea = font["hhea"]
    os2 = font["OS/2"]
    ascent, descent = hhea.ascent, -hhea.descent
    spare = max(0.0, upm * LINE_EM - ascent - descent) / 2.0
    new_ascent = round(ascent + spare)
    new_descent = round(upm * LINE_EM) - new_ascent
    hhea.ascent, hhea.descent, hhea.lineGap = new_ascent, -new_descent, 0
    os2.sTypoAscender, os2.sTypoDescender, os2.sTypoLineGap = new_ascent, -new_descent, 0
    head = font["head"]
    os2.usWinAscent = max(new_ascent, head.yMax)
    os2.usWinDescent = max(new_descent, -head.yMin)
    os2.fsSelection |= 1 << 7  # USE_TYPO_METRICS: typo metrics are authoritative.
    subfamily = "Regular"
    names = font["name"]
    for record in names.names:
        if record.nameID in SUBFAMILY_IDS and record.platformID == 3 and record.langID == 0x409:
            subfamily = record.toUnicode()
    for record in list(names.names):
        if record.nameID in FAMILY_IDS:
            record.string = family
        elif record.nameID == 4:
            record.string = f"{family} {subfamily}".replace(" Regular", "")
        elif record.nameID == 6:
            record.string = postscript
        elif record.nameID == 3:
            record.string = f"{postscript};ART-64 line box"
    if "CFF " in font:
        font["CFF "].cff.fontNames = [postscript]
    font.save(target)
    return {"upm": upm, "ascent": new_ascent, "descent": new_descent, "line_em": (new_ascent + new_descent) / upm}


if __name__ == "__main__":
    if len(sys.argv) != 5:
        sys.exit(__doc__)
    print(bake(*sys.argv[1:5]))
