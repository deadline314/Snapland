import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("animation_manifest_builder", ROOT / "tools/build_character_animation_manifest.py")
BUILDER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(BUILDER)


class CharacterAnimationManifestBuilderTests(unittest.TestCase):
    def test_full_build_preserves_separately_authored_actions_and_directions(self):
        before = json.loads(BUILDER.OUT.read_text(encoding="utf-8"))
        before["actors"]["traveller"]["wave"]["left"] = {"fps": 2, "frames": [{"source": "separate-authoring-fixture"}]}
        with tempfile.TemporaryDirectory() as temporary:
            manifest = Path(temporary) / "regions.json"
            manifest.write_text(json.dumps(before), encoding="utf-8")
            with patch.object(BUILDER, "OUT", manifest):
                after, _ = BUILDER.build()
        for action in ("sit", "catch"):
            self.assertEqual(before["actors"]["traveller"][action], after["actors"]["traveller"].get(action))
        self.assertEqual(before["actors"]["traveller"]["wave"]["left"], after["actors"]["traveller"]["wave"].get("left"))
        self.assertEqual(4, len(after["actors"]["traveller"]["idle"]["front_left"]["frames"]))


if __name__ == "__main__":
    unittest.main()
