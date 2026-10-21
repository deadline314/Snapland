from pathlib import Path
import hashlib
import tempfile
import unittest

from tools.build_desktop_release import prepare_runtime_stage


class DesktopReleaseStageTests(unittest.TestCase):
    def test_authoring_dependent_tests_are_absent_before_import(self):
        with tempfile.TemporaryDirectory(prefix="snapland-release-stage-") as temporary:
            root = Path(temporary) / "source"
            stage = Path(temporary) / "player"
            runtime = {
                "project.godot": '[application]\nrun/main_scene="res://game/main.tscn"\n',
                "export_presets.cfg": "release presets\n",
                "game/main.tscn": "main scene\n",
                "game/avatar_renderer.gd": "extends RefCounted\n",
                "game/data/locales/zh_TW.json": "{}\n",
                "assets/characters/head-owners.json": "{}\n",
                "assets/fonts/OFL.txt": "font license\n",
                "assets/audio/cc0/licenses/source.txt": "CC0\n",
                "design/01-park/park.json": "{}\n",
            }
            development = {
                "game/tests/test_authoring.gd": 'extends "res://tools/authoring.gd"\n',
                "game/tests/fixture.tscn": "test scene\n",
                "game/tests/nested/private.json": "test fixture\n",
                "tools/authoring.gd": "extends SceneTree\n",
                "tests/test_game.py": "# development only\n",
                "pm/ticket.md": "ticket\n",
                "design/runtime/private.md": "design\n",
                "work/rejected.png": "private evidence\n",
            }
            for name, body in (runtime | development).items():
                path = root / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(body)
            # Untracked runtime candidates must not leak into the build either.
            (root / "game/untracked.gd").write_text("extends Node\n")
            copied = prepare_runtime_stage(root, stage, [*runtime, *development, ""])
            self.assertEqual(set(copied), set(runtime))
            self.assertFalse((stage / "game/tests").exists())
            self.assertFalse((stage / "tools").exists())
            self.assertFalse((stage / "game/untracked.gd").exists())
            self.assertEqual(
                {str(path.relative_to(stage)) for path in stage.rglob("*") if path.is_file()},
                set(runtime),
            )
            for name, body in runtime.items():
                self.assertEqual((stage / name).read_text(), body)
                self.assertEqual(copied[name], hashlib.sha256((root / name).read_bytes()).hexdigest())
            self.assertEqual((root / "game/tests/test_authoring.gd").read_text(), development["game/tests/test_authoring.gd"])


if __name__ == "__main__":
    unittest.main()
