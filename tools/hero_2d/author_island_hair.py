"""Author three small outer tufts per view from the reviewed island hair ownership.

No segmentation or generation runs in the game. The polygons below are measured
on the registered 280x360 island cels, not the separate sample's hair atlas.
"""
from pathlib import Path
import hashlib
import json

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "assets/characters/island-hair-windswept-v1.json"
# (root, tip, authored selection polygon). Only reviewed hair pixels are retained.
STRANDS = {
    "front": [
        ((108, 145), (75, 166), [(69, 135), (105, 135), (115, 157), (100, 179), (68, 177)]),
        ((177, 145), (207, 166), [(179, 130), (216, 132), (217, 177), (188, 181), (175, 158)]),
        ((155, 118), (149, 81), [(134, 76), (159, 74), (176, 110), (154, 125)]),
    ],
    "front_right": [
        ((111, 145), (77, 168), [(68, 128), (110, 132), (121, 151), (104, 180), (68, 176)]),
        ((199, 132), (214, 155), [(197, 118), (220, 130), (224, 160), (204, 161), (195, 141)]),
        ((139, 113), (139, 80), [(119, 75), (155, 73), (155, 104), (138, 122)]),
    ],
    "right": [
        ((120, 144), (83, 170), [(76, 130), (118, 130), (132, 151), (105, 183), (73, 179)]),
        ((201, 130), (210, 154), [(200, 118), (219, 126), (222, 156), (206, 161), (197, 142)]),
        ((139, 119), (150, 91), [(136, 88), (160, 84), (157, 109), (137, 126), (127, 118)]),
    ],
    "back_right": [
        ((117, 145), (86, 174), [(75, 135), (116, 132), (130, 157), (108, 187), (78, 180)]),
        ((166, 165), (178, 188), [(158, 154), (186, 160), (193, 192), (165, 193), (155, 174)]),
        ((140, 118), (151, 90), [(139, 84), (161, 82), (158, 107), (141, 126), (129, 117)]),
    ],
    "back": [
        ((112, 151), (81, 179), [(73, 137), (111, 135), (124, 161), (105, 189), (74, 184)]),
        ((179, 150), (207, 177), [(178, 133), (219, 136), (220, 186), (191, 190), (169, 165)]),
        ((141, 121), (150, 91), [(131, 88), (161, 83), (160, 111), (140, 131), (126, 122)]),
    ],
    "back_left": [
        ((112, 166), (102, 189), [(91, 153), (120, 153), (125, 180), (112, 194), (86, 191)]),
        ((169, 147), (201, 176), [(167, 134), (211, 136), (214, 185), (185, 193), (157, 161)]),
        ((143, 125), (132, 98), [(117, 93), (141, 90), (155, 117), (143, 133), (130, 124)]),
    ],
    "left": [
        ((84, 138), (72, 159), [(68, 124), (85, 125), (95, 149), (81, 165), (65, 159)]),
        ((164, 147), (201, 172), [(165, 133), (210, 132), (215, 181), (185, 185), (151, 159)]),
        ((142, 125), (134, 97), [(119, 92), (145, 91), (158, 114), (145, 134), (133, 124)]),
    ],
    "front_left": [
        ((105, 143), (77, 165), [(71, 131), (103, 133), (116, 151), (100, 176), (71, 177)]),
        ((176, 144), (207, 166), [(175, 128), (216, 131), (218, 175), (193, 182), (169, 159)]),
        ((156, 122), (152, 91), [(136, 86), (160, 84), (175, 108), (157, 132), (144, 121)]),
    ],
}


def build():
    owners_path = ROOT / "assets/characters/walk-stability-v1/head-owners.json"
    owners = json.loads(owners_path.read_text())["owners"]
    result = {"schema_version": 1, "style": "windswept", "canvas": [280, 360],
              "grid_step": 3, "scope": "Registered island walk/idle only; other actions retain original complete cels.",
              "ownership_sha256": hashlib.sha256(owners_path.read_bytes()).hexdigest(), "directions": {}}
    crown_tips = {"front": (149, 74), "front_right": (140, 60), "right": (154, 71),
                  "back_right": (144, 70), "back": (140, 65), "back_left": (139, 72),
                  "left": (145, 71), "front_left": (149, 60)}
    for view, strands in STRANDS.items():
        crown_x, crown_y = crown_tips[view]
        strands = list(strands)
        strands[2] = ((crown_x - 4, crown_y + 37), (crown_x, crown_y),
                      [(crown_x - 17, crown_y - 4), (crown_x + 15, crown_y - 4),
                       (crown_x + 17, crown_y + 19), (crown_x - 4, crown_y + 44),
                       (crown_x - 22, crown_y + 31)])
        path = ROOT / f"assets/characters/walk-stability-v1/island-raw-{view}.png"
        entries = [v for v in owners.values() if v["poses"] == [f"walk/{view}/0"]]
        if len(entries) != 1:
            raise ValueError("Missing unique reviewed head ownership for " + view)
        hair = Image.new("L", (280, 360))
        draw = ImageDraw.Draw(hair)
        for y, left, right in entries[0]["hair_owner_spans"]:
            draw.line((left, y, right, y), fill=255)
        reference = Image.open(path).convert("RGBA").crop((0, 0, 280, 360))
        alpha = reference.getchannel("A")
        # An authored four-pixel silhouette band is removed from the static
        # image. The complete tuft overlaps its retained opaque inner core,
        # like overlapping cutout joints, so internal hair cuts never open up.
        edge = alpha.point(lambda a: 255 if a == 0 else 0).filter(ImageFilter.MaxFilter(9))
        selected = set()
        parts = []
        for root, tip, polygon in strands:
            selection = Image.new("L", (280, 360))
            ImageDraw.Draw(selection).polygon(polygon, fill=255)
            spans = []
            for y in range(360):
                start = None
                for x in range(281):
                    inside = x < 280 and hair.getpixel((x, y)) and selection.getpixel((x, y)) and (x, y) not in selected
                    if inside:
                        selected.add((x, y))
                        if start is None:
                            start = x
                    elif start is not None:
                        spans.append([y, start, x - 1])
                        start = None
            if not spans:
                raise ValueError("Empty authored tuft in " + view)
            cut_spans = []
            for y, left, right in spans:
                start = None
                for x in range(left, right + 2):
                    cut = x <= right and edge.getpixel((x, y))
                    if cut and start is None:
                        start = x
                    elif not cut and start is not None:
                        cut_spans.append([y, start, x - 1])
                        start = None
            parts.append({"root": root, "tip": tip, "selection_polygon": polygon,
                          "spans": spans, "cut_spans": cut_spans})
        canonical = bytearray(reference.tobytes())
        for index in range(0, len(canonical), 4):
            if canonical[index + 3] == 0:
                canonical[index:index + 4] = b"\0\0\0\0"
        result["directions"][view] = {"source": "res://" + path.relative_to(ROOT).as_posix(),
                                      "source_sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
                                      "source_pixels_sha256": hashlib.sha256(canonical).hexdigest(), "strands": parts}
    return result


if __name__ == "__main__":
    OUTPUT.write_text(json.dumps(build(), ensure_ascii=False, indent=2) + "\n")
    print("Authored eight views with reviewed outer tufts:", OUTPUT)
