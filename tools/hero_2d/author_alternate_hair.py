"""Compile measured bob/curl tufts from offline compositor ownership, never RGB guesses."""
import hashlib
import json
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter
from tools.hero_2d.author_island_hair import ROOT

OWNERS = ROOT / "assets/characters/island-hair-alternate-owners-v1.json"
VIEWS = ["front", "front_right", "right", "back_right", "back", "back_left", "left", "front_left"]
# Each root/tip/region is measured in the registered canvas, per actual haircut.
# Lower side locks bend; the crown and face opening remain rigid.
BOB = {
    "front": [(92,156,78,183,(67,143,105,202)), (191,155,207,181,(179,143,221,202)), (93,134,73,149,(65,123,91,156))],
    "front_right": [(103,150,88,177,(66,141,108,199)), (192,154,211,181,(185,142,224,203)), (88,128,75,145,(65,113,92,148))],
    "right": [(103,152,88,181,(70,139,113,205)), (183,148,199,165,(181,128,220,173)), (95,130,78,147,(62,115,99,149))],
    "back_right": [(103,153,89,187,(70,141,118,208)), (166,170,186,193,(151,164,204,215)), (195,126,210,143,(189,110,224,150))],
    "back": [(93,161,80,188,(66,145,111,213)), (191,161,206,189,(176,145,224,213)), (89,131,75,149,(65,115,94,158))],
    "back_left": [(107,176,103,199,(84,166,129,218)), (176,158,194,185,(165,144,214,213)), (85,127,74,148,(64,114,94,154))],
    "left": [(98,150,81,171,(61,135,101,181)), (175,155,196,185,(163,144,216,211)), (184,130,203,148,(183,114,222,152))],
    "front_left": [(103,154,87,182,(66,141,111,204)), (191,154,207,181,(181,141,225,205)), (88,130,73,147,(63,116,93,154))],
}
CURLY = {
    "front": [(91,176,80,204,(61,162,109,225)), (193,177,207,207,(178,159,228,229)), (88,129,71,144,(61,114,91,155))],
    "front_right": [(107,202,92,242,(66,184,121,261)), (186,202,202,241,(174,186,226,265)), (193,116,214,136,(185,100,231,151))],
    "right": [(105,193,91,232,(68,175,124,253)), (179,174,185,207,(162,163,213,223)), (95,132,75,149,(58,116,101,162))],
    "back_right": [(109,203,94,244,(69,184,132,265)), (89,155,75,176,(66,139,100,183)), (193,123,211,145,(183,106,229,157))],
    "back": [(96,207,79,246,(63,186,116,272)), (186,207,204,247,(167,186,225,273)), (89,142,74,164,(62,124,99,177))],
    "back_left": [(106,214,99,253,(77,197,131,273)), (175,206,192,245,(157,189,217,269)), (87,135,70,153,(59,116,98,164))],
    "left": [(91,126,77,146,(65,110,107,164)), (173,198,192,237,(153,180,218,260)), (186,133,207,155,(178,115,229,166))],
    "front_left": [(104,205,88,243,(64,186,122,265)), (187,202,204,241,(172,184,228,266)), (87,126,69,145,(57,109,98,160))],
}

def pixels(spans):
    return {(x, y) for y, left, right in spans for x in range(left, right + 1)}

def spans(points):
    rows = []
    for y in range(360):
        start = None
        for x in range(281):
            inside = x < 280 and (x, y) in points
            if inside and start is None: start = x
            elif not inside and start is not None:
                rows.append([y, start, x - 1]); start = None
    return rows

def build(style):
    data = json.loads(OWNERS.read_text())
    result = {"schema_version": 1, "style": style, "canvas": [280,360],
              "ownership_sha256": hashlib.sha256(OWNERS.read_bytes()).hexdigest(),
              "dependencies": data["dependencies"],
              "motion": {"gain": 0.52 if style == "bob" else 0.72,
                         "strand_gain": [1.0, 0.9, 0.65]}, "directions": {}}
    for view, selections in (BOB if style == "bob" else CURLY).items():
        owner = data["owners"][style][view]
        owned = pixels(owner["hair_owner_spans"])
        alpha = Image.new("L", (280,360))
        ImageDraw.Draw(alpha).point(list(pixels(owner["source_alpha_spans"])), fill=255)
        edge = alpha.point(lambda a: 255-a).filter(ImageFilter.MaxFilter(9))
        selected = set(); parts = []
        for rx,ry,tx,ty,(left,top,right,bottom) in selections:
            polygon = [(left,top),(right,top),(right,bottom),(left,bottom)]
            full = {p for p in owned if left <= p[0] <= right and top <= p[1] <= bottom} - selected
            cut = {p for p in full if edge.getpixel(p)}
            if not cut or len(full-cut) < 10: raise ValueError(f"Empty/unsupported tuft {style}/{view}/{rx}")
            selected |= full
            parts.append({"root":[rx,ry],"tip":[tx,ty],"selection_polygon":polygon,
                          "spans":spans(full),"cut_spans":spans(cut)})
        # Existing registered source head is also required; alternate atlas changes
        # are checked separately against the dependencies above.
        original = json.loads((ROOT / "assets/characters/island-hair-windswept-v1.json").read_text())["directions"][view]
        result["directions"][view] = {k:v for k,v in original.items() if k != "strands"}
        result["directions"][view]["strands"] = parts
    return result

if __name__ == "__main__":
    for style in ["bob", "curly"]:
        path = ROOT / f"assets/characters/island-hair-{style}-v1.json"
        path.write_text(json.dumps(build(style), indent=2)+"\n")
        print("Authored", style, path)
