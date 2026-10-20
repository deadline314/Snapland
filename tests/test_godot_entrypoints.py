"""Safe, pre-spawn checks for Godot game and test entrypoints."""
from __future__ import annotations

from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import Mock, patch

import tools.godot_entrypoints as entrypoints
from tools.godot_entrypoints import validate_godot_command
from tools.godot_entrypoints import run_validated_godot


class GodotEntrypointTests(unittest.TestCase):
    def setUp(self) -> None:
        self._temporary = tempfile.TemporaryDirectory()
        self.root = Path(self._temporary.name).resolve()
        (self.root / "project.godot").write_text('[application]\nrun/main_scene="res://game/main.tscn"\n', encoding="utf-8")
        self._write("game/tests/test_valid.gd", "extends SceneTree\n")
        self._write("game/tests/custom_loop.gd", 'extends "res://game/tests/base_loop.gd"\n')
        self._write("game/tests/base_loop.gd", "extends MainLoop\n")
        self._write("game/tests/relative/base.gd", "extends SceneTree\n")
        self._write("game/tests/relative/child.gd", 'extends "base.gd"\n')
        self._write("game/ui/book.gd", "extends VBoxContainer\n")
        self._write("game/ui/book.tscn", '[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://game/ui/book.gd" id="1"]\n[node name="Book" type="VBoxContainer"]\nscript = ExtResource("1")\n')
        self._write("game/main.tscn", "[gd_scene format=3]\n[node name=\"Main\" type=\"Node\"]\n")

    def tearDown(self) -> None:
        self._temporary.cleanup()

    def _write(self, relative: str, contents: str) -> Path:
        path = self.root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(contents, encoding="utf-8")
        return path

    def _command(self, *args: str) -> list[str]:
        return ["godot", "--path", str(self.root), *args]

    def test_scene_tree_and_explicit_mainloop_inheritance_are_valid(self) -> None:
        self.assertIsNone(validate_godot_command(self.root, self._command("--script", "res://game/tests/test_valid.gd")))
        self.assertIsNone(validate_godot_command(self.root, self._command("--script", "res://game/tests/custom_loop.gd", "--check-only")))
        self.assertIsNone(validate_godot_command(self.root, self._command("--script", "res://game/tests/relative/child.gd")))

    def test_node_control_component_must_launch_through_scene(self) -> None:
        error = validate_godot_command(self.root, self._command("--script", "res://game/ui/book.gd"))
        self.assertIn("not SceneTree/MainLoop", error or "")
        self.assertIn(".tscn", error or "")
        self.assertIsNone(validate_godot_command(self.root, self._command("res://game/ui/book.tscn")))
        self.assertIsNone(validate_godot_command(self.root, self._command("--scene", "res://game/main.tscn")))

    def test_script_and_scene_entrypoints_cannot_be_mixed(self) -> None:
        error = validate_godot_command(self.root, self._command("--script", "res://game/tests/test_valid.gd", "res://game/main.tscn"))
        self.assertIn("both --script and a scene", error or "")

    def test_review_snapshots_are_not_runnable_even_if_they_extend_scene_tree(self) -> None:
        self._write(".review/commit-slices/19-MAIN16-book.gd", "extends SceneTree\n")
        error = validate_godot_command(self.root, self._command("--script", "res://.review/commit-slices/19-MAIN16-book.gd"))
        self.assertIn("Review snapshots are not runnable", error or "")

    def test_missing_and_outside_project_scripts_fail_before_spawn(self) -> None:
        missing = validate_godot_command(self.root, self._command("--script", "res://game/tests/missing.gd"))
        self.assertIn("does not exist", missing or "")
        with tempfile.TemporaryDirectory() as outside:
            external = Path(outside) / "test.gd"
            external.write_text("extends SceneTree\n", encoding="utf-8")
            error = validate_godot_command(self.root, self._command("--script", str(external)))
        self.assertIn("stay inside the project", error or "")

    def test_inheritance_cycle_and_unknown_base_fail_actionably(self) -> None:
        self._write("game/tests/cycle_a.gd", 'extends "res://game/tests/cycle_b.gd"\n')
        self._write("game/tests/cycle_b.gd", 'extends "res://game/tests/cycle_a.gd"\n')
        cycle = validate_godot_command(self.root, self._command("--script", "res://game/tests/cycle_a.gd"))
        self.assertIn("inheritance cycle", cycle or "")
        self._write("game/tests/unknown.gd", "extends MyUnregisteredBase\n")
        unknown = validate_godot_command(self.root, self._command("--script", "res://game/tests/unknown.gd"))
        self.assertIn("not SceneTree/MainLoop", unknown or "")

    def test_import_parser_path_is_valid_without_scene_or_script(self) -> None:
        command = ["godot", "--headless", "--editor", "--path", str(self.root), "--import", "--quit"]
        self.assertIsNone(validate_godot_command(self.root, command))

    def test_project_and_default_main_scene_must_exist(self) -> None:
        project_file = self.root / "project.godot"
        original = project_file.read_text(encoding="utf-8")
        project_file.unlink()
        self.assertIn("project.godot", validate_godot_command(self.root, self._command("--editor", "--import")) or "")
        project_file.write_text(original.replace("res://game/main.tscn", "res://game/missing.tscn"), encoding="utf-8")
        self.assertIn("does not exist", validate_godot_command(self.root, self._command()) or "")

    def test_gd_file_passed_as_scene_is_rejected(self) -> None:
        error = validate_godot_command(self.root, self._command("res://game/ui/book.gd"))
        self.assertIn("not a scene entry", error or "")

    def test_invalid_ui_script_is_rejected_before_process_spawn(self) -> None:
        command = self._command("--script", "res://game/ui/book.gd", "--check-only")
        with patch.object(entrypoints.subprocess, "Popen") as spawn:
            with self.assertRaisesRegex(ValueError, r"run its \.tscn scene"):
                run_validated_godot(self.root, command, timeout=1)
        spawn.assert_not_called()

    def test_exported_binary_boots_from_clean_release_directory(self) -> None:
        binary = self._write("release/Snapland.x86_64", "fixture binary")
        process = Mock(returncode=0)
        process.communicate.return_value = ("release output", "")
        with patch.object(entrypoints.subprocess, "Popen", return_value=process) as spawn:
            result = run_validated_godot(self.root, [str(binary), "--", "--smoke-test"], timeout=4, release_directory=binary.parent)
        self.assertEqual(result.stdout, "release output")
        self.assertEqual(spawn.call_args.kwargs["cwd"], binary.parent)

    def test_export_acceptance_cannot_override_or_use_loose_project(self) -> None:
        binary = self._write("release/Snapland.x86_64", "fixture binary")
        for args in (["--path", str(self.root)], ["--script=game/tests/test_valid.gd"], ["res://game/main.tscn"], ["--main-pack", "elsewhere.pck"]):
            with self.subTest(args=args), patch.object(entrypoints.subprocess, "Popen") as spawn:
                with self.assertRaisesRegex(ValueError, "without path or scene overrides"):
                    run_validated_godot(self.root, [str(binary), *args], release_directory=binary.parent)
                spawn.assert_not_called()
        self._write("release/project.godot", "loose source")
        with patch.object(entrypoints.subprocess, "Popen") as spawn:
            with self.assertRaisesRegex(ValueError, "loose project"):
                run_validated_godot(self.root, [str(binary)], release_directory=binary.parent)
            spawn.assert_not_called()

    def test_normal_run_returns_captured_text(self) -> None:
        process = Mock()
        process.communicate.return_value = ("Godot output", "warning text")
        process.returncode = 0
        command = self._command("--scene", "res://game/main.tscn")
        with patch.object(entrypoints.subprocess, "Popen", return_value=process) as spawn:
            result = run_validated_godot(self.root, command, env={"SNAPLAND_SAVE_PATH": "isolated.json"}, timeout=4)
        self.assertEqual((result.returncode, result.stdout, result.stderr), (0, "Godot output", "warning text"))
        self.assertEqual(spawn.call_args.kwargs["cwd"], self.root)
        self.assertTrue(spawn.call_args.kwargs["text"])
        process.communicate.assert_called_once_with(timeout=4)

    def test_timeout_kills_only_owned_windows_tree_and_preserves_output(self) -> None:
        command = self._command("--script", "res://game/tests/test_valid.gd")
        process = Mock()
        process.pid = 24680
        process.poll.return_value = None
        process.communicate.side_effect = [
            subprocess.TimeoutExpired(command, 0.01, output="early output", stderr="early warning"),
            ("complete output", "complete warning"),
        ]
        with patch.object(entrypoints, "_WINDOWS", True), patch.object(entrypoints.subprocess, "Popen", return_value=process), patch.object(entrypoints.subprocess, "run", return_value=Mock(returncode=0)) as taskkill:
            with self.assertRaises(subprocess.TimeoutExpired) as caught:
                run_validated_godot(self.root, command, timeout=0.01)
        self.assertEqual(taskkill.call_args.args[0], ["taskkill", "/PID", "24680", "/T", "/F"])
        self.assertEqual(caught.exception.output, "complete output")
        self.assertEqual(caught.exception.stderr, "complete warning")
        process.kill.assert_not_called()

    def test_timeout_falls_back_to_killing_owned_process(self) -> None:
        command = self._command("--script", "res://game/tests/test_valid.gd")
        process = Mock()
        process.pid = 31415
        process.poll.side_effect = [None, None]
        process.communicate.side_effect = [
            subprocess.TimeoutExpired(command, 0.01),
            subprocess.TimeoutExpired(command, 3),
            ("final output", "final error"),
        ]
        with patch.object(entrypoints, "_WINDOWS", True), patch.object(entrypoints.subprocess, "Popen", return_value=process), patch.object(entrypoints.subprocess, "run", side_effect=OSError("taskkill unavailable")):
            with self.assertRaises(subprocess.TimeoutExpired) as caught:
                run_validated_godot(self.root, command, timeout=0.01)
        process.kill.assert_called_once_with()
        self.assertEqual(caught.exception.output, "final output")
        self.assertEqual(caught.exception.stderr, "final error")


if __name__ == "__main__":
    unittest.main()
