"""Compile the offline registered hair layers and pose-union silhouette from Godot."""
from pathlib import Path
import argparse
import hashlib
import json

from PIL import Image

from tools.hero_2d.author_alternate_hair import ROOT, VIEWS, spans


def alpha_points(path):
    image = Image.open(path).convert("RGBA")
    if image.size != (280, 360):
        raise ValueError(f"Expected a registered 280x360 layer: {path}")
    return {(x, y) for y in range(360) for x in range(280) if image.getpixel((x, y))[3] > 0}


def build(input_dir):
    owners = {}
    for style in ["bob", "curly"]:
        owners[style] = {}
        for view in VIEWS:
            owners[style][view] = {
                "hair_owner_spans": spans(alpha_points(input_dir / f"{style}-{view}-ownership.png")),
                "source_alpha_spans": spans(alpha_points(input_dir / f"{style}-{view}-union-alpha.png")),
            }
    paths = ["assets/characters/hair-v1.png", "assets/characters/diagonal-parts.json",
             "assets/characters/avatar-head-material-owners-v1.json"]
    diagonal = json.loads((ROOT / paths[1]).read_text())["parts"]["hair"]["atlas"]
    paths.append(diagonal.removeprefix("res://"))
    dependencies = []
    for relative in paths:
        path = ROOT / relative
        dependency = {"source": "res://" + relative, "source_sha256": hashlib.sha256(path.read_bytes()).hexdigest()}
        if path.suffix == ".png":
            pixels = bytearray(Image.open(path).convert("RGBA").tobytes())
            # The compositor discards alpha < 0.4. Godot pads RGB in those
            # unused border pixels; fingerprint only the actual haircut input.
            for index in range(0, len(pixels), 4):
                if pixels[index + 3] < 102:
                    pixels[index:index + 4] = b"\0" * 4
            dependency["alpha_cutoff"] = 102
            dependency["source_pixels_sha256"] = hashlib.sha256(pixels).hexdigest()
        dependencies.append(dependency)
    return {"schema_version": 1, "canvas": [280, 360], "dependencies": dependencies, "owners": owners}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input-dir", type=Path, required=True)
    args = parser.parse_args()
    path = ROOT / "assets/characters/island-hair-alternate-owners-v1.json"
    path.write_text(json.dumps(build(args.input_dir.resolve()), indent=2) + "\n")
    print("Compiled registered alternate hair ownership:", path)


if __name__ == "__main__":
    main()
