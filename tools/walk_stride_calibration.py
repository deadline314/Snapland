"""Measure how far the hero's authored walk cycle carries the body, per direction.

The park advances the eight-frame walk cycle from real travelled distance. If that
distance is longer than the step the artwork actually draws, the planted foot glides
forward on screen (foot sliding). This tool reads the approved walk atlases and
measures, in each pose where both lower legs are separate shapes, the horizontal distance
between the two sole centres; the widest two are the double-support poses. One cycle contains two steps, so

    stride_world = 2 * step_px / |cos(screen_angle)| * world_per_source_px

`world_per_source_px` follows the renderer: walk sources are scaled by
canvas_height / scale_reference_height, and the sprite is 2.4 world units per canvas
height, so one source pixel is 2.4 / scale_reference_height world units.

Front/back walks travel mostly in depth, so their sole spacing on screen does not
measure stride; they reuse the side measurement (same legs, same artwork set).
Run with --write to refresh assets/characters/walk-stride-calibration.json.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
REGIONS = ROOT / "assets/characters/walk-regions.json"
OUTPUT = ROOT / "assets/characters/walk-stride-calibration.json"
AVATAR_WORLD_HEIGHT = 2.4
SOLE_BAND_ROWS = 6          # lowest rows of each boot used as its sole
LOWER_LEG_ROWS = 50         # boots and socks sit below the shorts in every approved pose
MIN_LEG_PIXELS = 300        # ignore stray pixels and loose outline fragments
SCREEN_ANGLE_DEGREES = {"right": 0.0, "left": 0.0, "front_right": 45.0, "front_left": 45.0,
                        "back_right": 45.0, "back_left": 45.0}
DEPTH_DIRECTIONS = ("front", "back")


def _components(mask: np.ndarray) -> list[np.ndarray]:
    """4-connected components as arrays of (row, column) pixels."""
    seen = np.zeros_like(mask, dtype=bool)
    components = []
    rows, columns = mask.shape
    for start_row, start_column in zip(*np.nonzero(mask)):
        if seen[start_row, start_column]:
            continue
        stack = [(int(start_row), int(start_column))]
        seen[start_row, start_column] = True
        pixels = []
        while stack:
            row, column = stack.pop()
            pixels.append((row, column))
            for next_row, next_column in ((row + 1, column), (row - 1, column), (row, column + 1), (row, column - 1)):
                if 0 <= next_row < rows and 0 <= next_column < columns and mask[next_row, next_column] and not seen[next_row, next_column]:
                    seen[next_row, next_column] = True
                    stack.append((next_row, next_column))
        components.append(np.array(pixels))
    return components


def foot_points(alpha: np.ndarray, feet_y: int) -> list[float]:
    """Sole-centre x of each separate lower leg (boot) above the feet line.

    Only poses where the two lower legs are separate shapes count; overlapping
    passing poses are skipped rather than guessed.
    """
    top = max(0, feet_y - LOWER_LEG_ROWS)
    window = alpha[top:feet_y + 1]
    legs = [pixels for pixels in _components(window) if len(pixels) >= MIN_LEG_PIXELS]
    if len(legs) != 2:
        return []
    points = []
    for pixels in legs:
        bottom = pixels[:, 0].max()
        sole = pixels[pixels[:, 0] >= bottom - SOLE_BAND_ROWS + 1]
        points.append(float(sole[:, 1].mean()))
    return points


def measure(metadata: dict) -> dict:
    reference = float(metadata.get("scale_reference_height", 444))
    world_per_px = AVATAR_WORLD_HEIGHT / reference
    results: dict[str, dict] = {}
    atlases: dict[str, np.ndarray] = {}
    for direction, angle in SCREEN_ANGLE_DEGREES.items():
        entry = metadata["directions"][direction]
        atlas_path = entry["atlas"].removeprefix("res://")
        if atlas_path not in atlases:
            atlases[atlas_path] = np.array(Image.open(ROOT / atlas_path).convert("RGBA"))[:, :, 3] > 128
        alpha = atlases[atlas_path]
        spacings = []
        for (x, y, w, h), anchor in zip(entry["regions"], entry["anchors"]):
            points = foot_points(alpha[y:y + h, x:x + w], int(anchor["feet_y"]))
            if len(points) == 2:
                spacings.append(abs(points[1] - points[0]))
        if not spacings:
            raise ValueError(f"{direction}: no double-support pose found")
        # The widest spacings are the true double-support poses; passing poses read narrower.
        widest = sorted(spacings)[-2:]
        step_px = sum(widest) / len(widest)
        stride = 2.0 * step_px / math.cos(math.radians(angle)) * world_per_px
        results[direction] = {"step_px": round(step_px, 2), "double_support_poses": len(spacings),
                              "screen_angle_degrees": angle, "stride_world": round(stride, 4)}
    side = (results["right"]["stride_world"] + results["left"]["stride_world"]) / 2.0
    for direction in DEPTH_DIRECTIONS:
        results[direction] = {"reuses": "side", "stride_world": round(side, 4)}
    return {"world_per_source_px": round(world_per_px, 6), "directions": results}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--write", action="store_true", help="write the calibration JSON used by the park")
    args = parser.parse_args()
    metadata = json.loads(REGIONS.read_text(encoding="utf-8"))
    result = measure(metadata)
    atlas_hashes = {}
    for entry in metadata["directions"].values():
        path = entry["atlas"].removeprefix("res://")
        atlas_hashes[path] = hashlib.sha256((ROOT / path).read_bytes()).hexdigest()
    document = {"schema_version": 1, "tool": "tools/walk_stride_calibration.py",
                "regions_sha256": hashlib.sha256(REGIONS.read_bytes()).hexdigest(),
                "atlas_sha256": dict(sorted(atlas_hashes.items())), **result}
    text = json.dumps(document, ensure_ascii=False, indent=2) + "\n"
    if args.write:
        OUTPUT.write_text(text, encoding="utf-8")
    print(text)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
