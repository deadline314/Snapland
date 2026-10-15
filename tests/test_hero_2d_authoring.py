"""Temporary-fixture coverage for the 2D authored-cel pack compiler."""
from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

from PIL import Image

from tools.hero_2d import author_pack


DIRECTIONS = ["front", "front_right", "right", "back_right", "back", "back_left", "left", "front_left"]
ACTIONS = ["idle", "start", "walk", "stop", "turn", "photo"]


class Hero2DAuthoringCompilerTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory(prefix="hero-2d-authoring-", dir=Path(__file__).resolve().parents[1])
        self.pack = Path(self.temp.name) / "pack"
        self.pack.mkdir()
        (self.pack / "candidates").mkdir()
        self._write_fixture()
        self.v1_preview = Image.new("RGBA", (1, 1), (17, 33, 49, 255))
        self.v1_preview.save(self.pack / "binding-preview-v1.png")
        self.v1_preview_bytes = (self.pack / "binding-preview-v1.png").read_bytes()

    def tearDown(self) -> None:
        self.temp.cleanup()

    def _write_fixture(self) -> None:
        body = Image.new("RGBA", (8, 8), (20, 40, 220, 255))
        body.putpixel((2, 2), (250, 20, 20, 255))
        body.putpixel((3, 2), (250, 20, 20, 255))
        body.putpixel((2, 3), (250, 20, 20, 255))
        body.putpixel((3, 3), (250, 20, 20, 255))
        body.putpixel((4, 2), (20, 250, 20, 7))
        body.save(self.pack / "candidates/body.png")
        coat = Image.new("RGBA", (8, 8), (220, 100, 20, 255))
        coat.save(self.pack / "candidates/coat.png")

        hair = Image.new("RGBA", (8, 8), (0, 0, 0, 0))
        hair.putpixel((2, 2), (250, 20, 220, 255))
        hair.putpixel((3, 2), (250, 20, 220, 255))
        hair.putpixel((2, 3), (250, 20, 220, 255))
        hair.putpixel((3, 3), (250, 20, 220, 255))
        hair.putpixel((3, 4), (250, 20, 220, 255))
        hair.putpixel((4, 4), (250, 20, 220, 128))
        hair.putpixel((7, 7), (20, 20, 250, 255))  # disconnected artifact to remove
        hair.putpixel((6, 7), (20, 250, 20, 7))  # near-transparent speck
        hair.save(self.pack / "candidates/hair.png")
        hat = Image.new("RGBA", (8, 8), (230, 200, 20, 255))
        hat.save(self.pack / "candidates/hat.png")

        def body_record(source: str = "candidates/body.png") -> dict:
            return {
                "source": source,
                "region": [2, 2, 4, 4],
                "head_anchor": [1, 1],
                "feet": [2, 4],
                "scale": 1.0,
                "foreground_regions": [[139, 343, 1, 1]],
            }

        def pose_record() -> dict:
            return {
                **body_record(),
                "outfits": {"long_coat": body_record("candidates/coat.png")},
            }

        walk = {direction: [pose_record(), pose_record()] for direction in DIRECTIONS}
        actions = {
            direction: {
                "idle": [pose_record()],
                "start": [pose_record(), pose_record()],
                "stop": [pose_record(), pose_record()],
                "turn": [pose_record()],
                "photo": [pose_record(), pose_record()],
            }
            for direction in DIRECTIONS
        }
        hair_parts = {
            direction: {
                "source": "candidates/hair.png",
                "region": [2, 2, 6, 6],
                "anchor": [2, 2],
                "scale": 1.0,
                "order": "front",
                "hat_clip_y": 80,
                "hat_clear_regions": [[79, 80, 1, 1]],
            }
            for direction in DIRECTIONS
        }
        hat_parts = {
            direction: {
                "source": "candidates/hat.png",
                "region": [0, 0, 8, 8],
                "anchor": [4, 4],
                "scale": 1.0,
                "order": "front",
            }
            for direction in DIRECTIONS
        }
        source = {
            "schema_version": 1,
            "walk": walk,
            "actions": actions,
            "parts": {
                "hair": {"windswept": hair_parts, "bob": hair_parts},
                "hats": {"traveller": hat_parts},
            },
        }
        (self.pack / "authoring.json").write_text(json.dumps(source), encoding="utf-8")

    def test_source_crop_feet_alignment_and_head_anchor_normalization(self) -> None:
        with (self.pack / "authoring.json").open(encoding="utf-8") as file:
            record = json.load(file)["walk"]["front"][0]
        canvas, head_anchor = author_pack.source_frame(record, self.pack)
        self.assertEqual(canvas.size, author_pack.CANVAS)
        self.assertEqual(head_anchor, (139, 343))
        bounds = canvas.getchannel("A").getbbox()
        self.assertIsNotNone(bounds)
        self.assertEqual(bounds[3], author_pack.FEET[1], "crop bottom must align to the canonical feet baseline")
        self.assertEqual(canvas.getpixel((138, 342)), (250, 20, 20, 255), "crop origin and scale must preserve the explicit marker pixel")
        self.assertEqual(canvas.getpixel((140, 342))[3], 0, "source alpha below eight must be cleared")

    def test_part_cleanup_and_hat_clipping_are_explicit_and_local(self) -> None:
        source = Image.open(self.pack / "candidates/hair.png").crop((2, 2, 8, 8))
        cell = author_pack.compile_part_cell(source, [2, 2], 1.0)
        self.assertEqual(cell.getpixel((78, 78)), (250, 20, 220, 255))
        self.assertEqual(cell.getpixel((80, 80)), (250, 20, 220, 128), "component cleanup must preserve authored alpha")
        self.assertEqual(cell.getpixel((83, 83))[3], 0, "disconnected component and low-alpha specks must be removed")
        clipped = author_pack.clip_hat_part(cell, 80)
        self.assertEqual(clipped.getpixel((78, 78))[3], 0, "under-hat variant clears pixels above the authored clip row")
        self.assertEqual(clipped.getpixel((79, 80)), cell.getpixel((79, 80)), "under-hat variant preserves pixels at and below the clip row")

    def test_complete_manifest_atlases_fallback_and_action_coverage(self) -> None:
        manifest = author_pack.compile_pack(self.pack, write_manifest=True, write_preview=True)
        self.assertEqual(manifest["production"], "2d-authored-layers")
        self.assertEqual(manifest["format"], "production2d-authored-layers")
        self.assertEqual(manifest["schema_version"], 1)
        self.assertEqual(manifest["directions"], DIRECTIONS)
        self.assertEqual(set(manifest["outfits"]), {"tide_jacket", "long_coat"})
        self.assertEqual(set(manifest["hair"]), {"windswept", "bob"})
        self.assertEqual(set(manifest["hats"]), {"traveller"})
        self.assertEqual(manifest["character_model_files"], [])
        self.assertEqual(set(manifest["poses"]), set(DIRECTIONS))
        self.assertEqual(set(manifest["poses"]["front"]), set(ACTIONS))
        self.assertEqual(len(manifest["poses"]["right"]["walk"]), 2)
        walk_frame = manifest["poses"]["right"]["walk"][1]
        self.assertEqual(walk_frame["source"], "compiled/tide-walk.png")
        self.assertEqual(walk_frame["region"], [280, 720, 280, 360])
        self.assertEqual(walk_frame["head_anchor"], [139, 343])
        self.assertEqual(walk_frame["feet"], [140, 346])
        self.assertEqual(walk_frame["foreground_regions"], [[139, 343, 1, 1]])
        self.assertEqual(walk_frame["outfits"]["long_coat"]["source"], "compiled/coat-walk.png")
        self.assertEqual(walk_frame["outfits"]["long_coat"]["head_anchor"], [139, 343])
        with Image.open(self.pack / "compiled/tide-walk.png") as atlas:
            self.assertEqual(atlas.size, (560, 2880), "action atlas uses eight direction rows and maximum frame columns")
        self.assertTrue((self.pack / manifest["fallback"]["source"]).is_file(), "manifest fallback must be a compiled complete image")
        with Image.open(self.pack / manifest["fallback"]["source"]).convert("RGBA") as fallback:
            self.assertEqual(fallback.size, author_pack.CANVAS)
            self.assertEqual(fallback.getpixel((140, 343)), (20, 40, 220, 255), "fallback keeps the canonical front body")
            self.assertEqual(fallback.getpixel((137, 341)), (250, 20, 220, 255), "fallback composes authored front hair at the body head anchor")
        self.assertTrue(all((self.pack / relative).is_file() for relative in manifest["files"]))
        self.assertIn("compiled/hair-windswept-underhat.png", manifest["files"])
        hair_entry = manifest["hair"]["windswept"]["front"]
        self.assertIn("hat_layers", hair_entry, "hat-clipped hair is explicit optional manifest data")
        self.assertEqual(hair_entry["hat_layers"][0]["source"], "compiled/hair-windswept-underhat.png")
        with Image.open(self.pack / "compiled/hair-windswept.png") as regular_hair, Image.open(self.pack / "compiled/hair-windswept-underhat.png") as underhat:
            self.assertEqual(regular_hair.getpixel((79, 80)), (250, 20, 220, 255), "explicit under-hat clears do not alter regular hair")
            self.assertEqual(underhat.getpixel((79, 80))[3], 0, "authored clear rectangle removes only the reviewed under-hat tip")
            self.assertEqual(underhat.getpixel((80, 80)), (250, 20, 220, 128), "pixels outside the reviewed clear rectangle remain intact")
        self.assertTrue((self.pack / "binding-preview-v2.png").is_file(), "optional gallery generation creates a new preview")
        self.assertEqual((self.pack / "binding-preview-v1.png").read_bytes(), self.v1_preview_bytes, "compiler must preserve binding-preview-v1.png byte-for-byte")

    def test_large_combined_hat_variant_keeps_cap_and_disconnected_hair(self) -> None:
        authoring_path = self.pack / "authoring.json"
        data = json.loads(authoring_path.read_text(encoding="utf-8"))
        data["part_canvas"] = [256, 256]
        combined = Image.new("RGBA", (8, 8), (0, 0, 0, 0))
        for pixel in ((2, 2), (3, 2), (2, 3), (3, 3)):
            combined.putpixel(pixel, (230, 200, 20, 255))
        combined.putpixel((6, 6), (20, 180, 240, 255))
        combined.save(self.pack / "candidates/combined.png")
        for direction in DIRECTIONS:
            record = data["parts"]["hair"]["windswept"][direction]
            record.pop("hat_clip_y")
            record.pop("hat_clear_regions")
            record["hat_variant"] = {
                "source": "candidates/combined.png",
                "region": [0, 0, 8, 8],
                "anchor": [4, 4],
                "scale": 1.0,
                "offset": [0, 0],
            }
        authoring_path.write_text(json.dumps(data), encoding="utf-8")

        manifest = author_pack.compile_pack(self.pack, write_manifest=False, write_preview=False)
        entry = manifest["hair"]["windswept"]["front"]
        self.assertTrue(entry["hat_layers_include_hat"], "combined variant tells runtime not to add a second cap")
        self.assertEqual(entry["hat_layers"][0]["region"], [0, 0, 256, 256])
        self.assertEqual(entry["hat_layers"][0]["anchor"], [128, 128])
        with Image.open(self.pack / "compiled/hair-windswept.png") as regular, Image.open(self.pack / "compiled/hair-windswept-underhat.png") as combined_atlas:
            self.assertEqual(regular.size, (2048, 256))
            self.assertEqual(combined_atlas.size, (2048, 256), "part_canvas prevents cropping the larger authored layers")
            self.assertEqual(combined_atlas.getpixel((126, 126)), (230, 200, 20, 255), "combined hair+hat cel retains the cap")
            self.assertEqual(combined_atlas.getpixel((130, 130)), (20, 180, 240, 255), "combined cel retains disconnected hair instead of largest-component pruning")
            self.assertEqual(regular.getpixel((127, 127)), (250, 20, 220, 255), "regular hair atlas remains the no-hat variant")


if __name__ == "__main__":
    unittest.main()
