from __future__ import annotations

import importlib.util
from pathlib import Path
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "tools" / "animation_qa" / "export_animation_qa.py"
SPEC = importlib.util.spec_from_file_location("animation_qa_export", SCRIPT)
assert SPEC is not None and SPEC.loader is not None
EXPORT = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(EXPORT)


class AnimationQaExportTests(unittest.TestCase):
    def test_formal_helper_discovers_repository_and_sibling_preset(self) -> None:
        self.assertEqual(EXPORT.ROOT, ROOT)
        self.assertEqual(EXPORT.PRESET, SCRIPT.with_name("animation-qa-export-presets.cfg"))
        self.assertTrue((ROOT / "project.godot").is_file())
        self.assertTrue(EXPORT.PRESET.is_file())

    def test_sanitized_project_keeps_only_fixture_tests_and_formal_content(self) -> None:
        with tempfile.TemporaryDirectory(prefix="snapland-qa-export-fixture-") as temporary:
            source = Path(temporary) / "source"
            destination = Path(temporary) / "output"
            for relative, body in {
                "project.godot": '[application]\nrun/main_scene="res://game/main.tscn"\n',
                "export_presets.cfg": "release source\n",
                "game/main.tscn": "main scene\n",
                "game/runtime.gd": "runtime\n",
                "game/tests/native_island_animation_acceptance.gd": "fixture script\n",
                "game/tests/native_island_animation_acceptance.tscn": "fixture scene\n",
                "game/tests/other_test.gd": "must be omitted\n",
                "assets/island.png": "asset\n",
                "game/data/species.json": "{}\n",
                "game/data/locales/zh_TW.json": "{}\n",
                "assets/fonts/pixel.ttf": "font\n",
                "assets/fonts/OFL.txt": "font license\n",
                "assets/fonts/pixel/LICENSE.txt": "pixel font license\n",
                "assets/audio/cc0/licenses/source.txt": "audio license\n",
                "assets/characters/complete-animation-regions.json": "{}\n",
                "design/01-park/park.json": "{}\n",
                "design/runtime/private.md": "must be omitted\n",
                "pm/ticket.md": "must be omitted\n",
                "tools/export.py": "must be omitted\n",
                "tests/test_game.py": "must be omitted\n",
            }.items():
                path = source / relative
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(body, encoding="utf-8")
            old_root, old_preset = EXPORT.ROOT, EXPORT.PRESET
            EXPORT.ROOT = source
            EXPORT.PRESET = SCRIPT.with_name("animation-qa-export-presets.cfg")
            try:
                info = EXPORT.prepare_project(destination)
            finally:
                EXPORT.ROOT, EXPORT.PRESET = old_root, old_preset

            project = destination / "qa-project"
            self.assertEqual(
                sorted(info["included_tests"]),
                ["game/tests/native_island_animation_acceptance.gd", "game/tests/native_island_animation_acceptance.tscn"],
            )
            self.assertTrue((project / "assets/island.png").is_file())
            self.assertTrue((project / "game/runtime.gd").is_file())
            self.assertTrue((project / "game/data/locales/zh_TW.json").is_file())
            self.assertTrue((project / "assets/fonts/pixel.ttf").is_file())
            self.assertIn("assets/fonts/pixel.ttf", info["included_fonts"])
            self.assertEqual(info["included_licenses"], ["assets/audio/cc0/licenses/source.txt", "assets/fonts/OFL.txt", "assets/fonts/pixel/LICENSE.txt"])
            for license_path in info["included_licenses"]:
                self.assertTrue((project / license_path).is_file())
            self.assertTrue((project / "design/01-park/park.json").is_file())
            self.assertFalse((project / "game/tests/other_test.gd").exists())
            self.assertFalse((project / "design/runtime/private.md").exists())
            self.assertFalse((project / "pm/ticket.md").exists())
            self.assertFalse((project / "tools/export.py").exists())
            self.assertFalse((project / "tests/test_game.py").exists())
            self.assertIn('run/main_scene="res://game/tests/native_island_animation_acceptance.tscn"', (project / "project.godot").read_text(encoding="utf-8"))
            self.assertEqual((project / "export_presets.cfg").read_text(encoding="utf-8"), EXPORT.PRESET.read_text(encoding="utf-8"))
            self.assertFalse(info["source_release_preset_modified"])
            self.assertEqual((source / "export_presets.cfg").read_text(encoding="utf-8"), "release source\n")

    def test_design_documents_are_excluded_but_main_runtime_park_json_is_selected(self) -> None:
        self.assertTrue(EXPORT._selected_project_file(Path("design/01-park/park.json")))
        self.assertFalse(EXPORT._selected_project_file(Path("design/01-park/park.md")))
        self.assertFalse(EXPORT._selected_project_file(Path("design/runtime/private.md")))
        self.assertTrue(EXPORT._selected_project_file(Path("game/data/locales/manifest.json")))
        self.assertTrue(EXPORT._selected_project_file(Path("assets/fonts/pixel.ttf")))


if __name__ == "__main__":
    unittest.main()
