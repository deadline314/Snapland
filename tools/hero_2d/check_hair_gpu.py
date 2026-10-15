"""Check actual GPU captures; a static render contract, not a playtest.

Requires the separately pinned authoring dependencies. Run after --gpu-contracts.
"""
from __future__ import annotations
import argparse
import json
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
PACK = ROOT / "assets/characters/hero-2d-v1"


def validate_cases(receipt: dict) -> list:
    cases = receipt.get("cases")
    expected = {(view, hat) for view in ["front","front_right","right","back_right","back","back_left","left","front_left"] for hat in [False, True]}
    if not isinstance(cases, list) or len(cases) != len(expected):
        raise ValueError("GPU receipt requires exactly sixteen captured configurations")
    seen = set()
    for case in cases:
        if not isinstance(case, dict) or type(case.get("hat")) is not bool:
            raise ValueError("GPU configuration must identify a view and boolean hat state")
        pair = (case.get("view"), case["hat"])
        if pair not in expected or pair in seen or case.get("key") != f"{pair[0]}-hat{int(pair[1])}":
            raise ValueError("GPU receipt has a duplicate, missing or mislabeled configuration")
        seen.add(pair)
    return cases


def check(folder: Path) -> dict:
    import cv2
    import numpy as np
    from PIL import Image
    manifest = json.loads((PACK / "manifest.json").read_text(encoding="utf-8"))
    profile = json.loads((PACK / "hair-rig-windswept.json").read_text(encoding="utf-8"))
    receipt = json.loads((folder / "render-contract.json").read_text(encoding="utf-8"))
    results = []
    for case in validate_cases(receipt):
        key = case["key"]
        spec = manifest["hair"]["windswept"][case["view"]]["hat_layers" if case["hat"] else "layers"][0]
        x, y, w, h = spec["region"]
        source = np.array(Image.open(PACK / spec["source"]).convert("RGBA").crop((x, y, x+w, y+h)))
        yy, xx = np.indices((h, w))
        cx, cy, cw, ch = profile["protected_core"]
        protected = (xx >= cx) & (xx <= cx+cw) & (yy >= cy) & (yy <= cy+ch)
        if case["hat"]:
            protected |= yy <= profile["hat_protected_y"]
        # Source opaque hair is mostly alpha253, not255. Erode to exclude blend boundaries.
        opaque = cv2.erode((source[:, :, 3] >= 240).astype(np.uint8), np.ones((3, 3), np.uint8)).astype(bool)
        protected &= opaque
        assert protected.sum() > 500, f"{key}: empty protected interior"
        images = {name: np.array(Image.open(folder / f"{key}-{name}.png").convert("RGB")) for name in ["rest", "moving", "settled"]}
        ox, oy = map(int, case["hair_origin"])
        rx, ry = map(int, case["reference_origin"])
        crops = {name: pixels[oy:oy+h, ox:ox+w] for name, pixels in images.items()}
        delta = np.abs(crops["moving"].astype(int)-crops["rest"].astype(int))
        locked_error = int(delta[protected].max())
        changed = int(((delta.max(axis=2) > 0) & (source[:, :, 3] >= 64)).sum())
        settled_error = int(np.abs(crops["settled"].astype(int)-crops["rest"].astype(int)).max())
        original = images["rest"][ry:ry+h, rx:rx+w]
        template = cv2.cvtColor(crops["rest"][20:-20,20:-20], cv2.COLOR_RGB2GRAY)
        search = cv2.cvtColor(original[16:-16,16:-16], cv2.COLOR_RGB2GRAY)
        _, score, _, point = cv2.minMaxLoc(cv2.matchTemplate(search, template, cv2.TM_CCOEFF_NORMED))
        shift = [point[0]-4, point[1]-4]
        # Different CPU/GPU alpha blending may differ slightly in color, independently of translation.
        original_color_error = int(np.abs(original.astype(int)-crops["rest"].astype(int))[protected].max())
        assert locked_error == 0, f"{key}: root/cap pixels moved"
        assert changed > 20, f"{key}: no visible hair response"
        assert settled_error == 0, f"{key}: failed to settle"
        assert shift == [0,0] and score > .999, f"{key}: reference placement changed"
        results.append({"key":key,"protected_interior_pixels":int(protected.sum()),"protected_max_channel_difference":locked_error,"changed_hair_region_pixels":changed,"settled_max_difference":settled_error,"original_head_translation":shift,"original_head_correlation":score,"original_protected_max_color_difference":original_color_error,"predicted_visible_displacement":case["predicted_visible_displacement"]})
    result = {"scope":receipt["scope"],"source_alpha_note":"Eroded alpha>=240 interior; source hair is mostly alpha253. Reference color differences are independent of root movement.","cases":results,"result":"PASS"}
    (folder / "pixel-comparison.json").write_text(json.dumps(result, indent=2)+"\n",encoding="utf-8")
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("folder",type=Path)
    args = parser.parse_args()
    result = check(args.folder)
    print("PASS GPU protected pixels, visible tips, settlement and original placement:",len(result["cases"]),"cases")


if __name__ == "__main__":
    main()
