import tempfile
import unittest
from pathlib import Path

from PIL import Image
from tools.island_avatar.author_side_coat import build, canonical_hash, cloth_indices


class SideCoatAuthoringTests(unittest.TestCase):
    def test_importer_hidden_rgb_does_not_change_source_identity(self):
        original = Image.new("RGBA", (2, 2), (0, 0, 0, 0))
        imported = original.copy()
        imported.putpixel((0, 0), (232, 121, 104, 0))
        self.assertEqual(canonical_hash(original), canonical_hash(imported))
        imported.putpixel((0, 0), (232, 121, 104, 255))
        self.assertNotEqual(canonical_hash(original), canonical_hash(imported))

    def test_observed_sleeve_is_cloth_but_camera_metal_is_not(self):
        image = Image.new("RGBA", (280, 360))
        image.putpixel((135, 210), (4, 105, 130, 253))  # Actual old blue sleeve.
        image.putpixel((196, 217), (60, 78, 93, 253))  # Actual camera metal.
        record = {"hair_owner_spans": [], "direction": "right"}
        indices = cloth_indices(image, record)
        self.assertIn(210 * 280 + 135, indices)
        self.assertNotIn(217 * 280 + 196, indices)

    def test_reviewed_head_ownership_wins_over_same_coloured_cloth(self):
        image = Image.new("RGBA", (280, 360))
        image.putpixel((135, 180), (4, 105, 130, 253))
        record = {"hair_owner_spans": [[180, 135, 135]], "direction": "right"}
        self.assertEqual(cloth_indices(image, record), [])

    def test_incomplete_input_cannot_publish_a_partial_side_set(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "sources.json").write_text("[]")
            with self.assertRaisesRegex(ValueError, "24"):
                build(root, root / "materials.json", root / "review")
            self.assertFalse((root / "materials.json").exists())
