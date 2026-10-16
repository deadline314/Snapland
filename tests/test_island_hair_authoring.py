"""Independent source-pixel constraints for the island's authored moving cutouts."""
import hashlib
import json
from pathlib import Path
import unittest

from PIL import Image

from tools.hero_2d.author_island_hair import build

ROOT = Path(__file__).resolve().parents[1]


def pixels(spans):
    return {(x, y) for y, left, right in spans for x in range(left, right + 1)}


class IslandHairAuthoringTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.profile = json.loads((ROOT / "assets/characters/island-hair-windswept-v1.json").read_text())
        cls.owners = json.loads((ROOT / "assets/characters/walk-stability-v1/head-owners.json").read_text())["owners"]

    def test_rebuild_preserves_all_author_data_and_source_fingerprints(self):
        self.assertEqual(json.loads(json.dumps(build())), self.profile)
        self.assertEqual(len(self.profile["directions"]), 8)
        for view, spec in self.profile["directions"].items():
            with self.subTest(view=view):
                path = ROOT / spec["source"].removeprefix("res://")
                self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), spec["source_sha256"])

    def test_cutouts_never_contain_face_clothes_or_other_unowned_pixels(self):
        for view, spec in self.profile["directions"].items():
            owner = next(v for v in self.owners.values() if v["poses"] == [f"walk/{view}/0"])
            owned = pixels(owner["hair_owner_spans"])
            selected = set()
            for strand in spec["strands"]:
                with self.subTest(view=view, root=strand["root"]):
                    full, cut = pixels(strand["spans"]), pixels(strand["cut_spans"])
                    self.assertTrue(full)
                    self.assertTrue(cut)
                    self.assertTrue(full <= owned)
                    self.assertTrue(cut <= full)
                    self.assertFalse(selected & full, "a pixel cannot belong to two moving tufts")
                    selected |= full

    def test_inner_hair_has_real_overlap_and_only_outer_silhouette_is_cut(self):
        for view, spec in self.profile["directions"].items():
            image = Image.open(ROOT / spec["source"].removeprefix("res://")).convert("RGBA").crop((0, 0, 280, 360))
            alpha = image.getchannel("A")
            for strand in spec["strands"]:
                full, cut = pixels(strand["spans"]), pixels(strand["cut_spans"])
                self.assertGreater(len(full - cut), 10, f"{view}: root needs retained original overlap")
                for x, y in cut:
                    self.assertTrue(any(alpha.getpixel((xx, yy)) == 0
                                        for yy in range(max(0, y - 4), min(360, y + 5))
                                        for xx in range(max(0, x - 4), min(280, x + 5))),
                                    f"{view}: removed interior hair pixel {(x, y)}")

    def test_same_cutout_pixels_exist_in_every_authored_walk_frame(self):
        for view, spec in self.profile["directions"].items():
            atlas = Image.open(ROOT / spec["source"].removeprefix("res://")).convert("RGBA")
            selected = set().union(*(pixels(s["spans"]) for s in spec["strands"]))
            for frame in range(1, 8):
                self.assertTrue(all(atlas.getpixel((x, y)) == atlas.getpixel((x + 280 * frame, y)) for x, y in selected),
                                f"{view}/{frame}: stable head/source registration changed")


if __name__ == "__main__":
    unittest.main()
