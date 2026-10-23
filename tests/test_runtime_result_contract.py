"""Runtime completion cannot hide engine errors, early exits or another suite's output."""
from __future__ import annotations

import ast
from contextlib import redirect_stderr, redirect_stdout
import io
import os
from pathlib import Path
import inspect
import re
import subprocess
import unittest
from unittest import mock

from tools.run_game_tests import PASS_MARKERS, main, result_error

LABEL = "authored idle hair attachment tests"
ACTUAL_IDLE_COMPLETION = "PASS: source-atlas closed-eye attachment availability (not production idle playback)"


class RuntimeResultContractTests(unittest.TestCase):
    def result(self, stdout: str = "", stderr: str = "", code: int = 0) -> subprocess.CompletedProcess[str]:
        return subprocess.CompletedProcess(["godot"], code, stdout, stderr)

    def test_current_source_diagnostic_completion_is_accepted(self) -> None:
        self.assertIsNone(result_error(LABEL, self.result("Godot 4.7.2\r\n\r\n" + ACTUAL_IDLE_COMPLETION + "\r\n", "WARNING: fixture fallback\n")))

    def test_previous_wording_is_rejected_and_observed_completion_is_reported(self) -> None:
        old = "PASS: directional closed-eye idle hair attachment"
        error = result_error(LABEL, self.result(old + "\n"))
        self.assertIn("without its PASS marker", error or "")
        self.assertIn(old, error or "")

    def test_zero_exit_without_executed_suite_is_rejected(self) -> None:
        self.assertIn("without its PASS marker", result_error(LABEL, self.result("Godot 4.7.2\n")) or "")

    def test_nonzero_exit_overrides_a_valid_completion(self) -> None:
        for code in [1, 2, -15]:
            with self.subTest(code=code):
                self.assertIn(f"exited {code}", result_error(LABEL, self.result(ACTUAL_IDLE_COMPLETION, code=code)) or "")

    def test_errors_on_either_stream_override_a_valid_completion(self) -> None:
        for message in ["ERROR: invalid image", "SCRIPT ERROR: Assertion failed", "SCRIPT ERROR: Parse Error"]:
            for stream in ["stdout", "stderr"]:
                with self.subTest(message=message, stream=stream):
                    result = self.result(ACTUAL_IDLE_COMPLETION + "\n" + (message if stream == "stdout" else ""), message if stream == "stderr" else "")
                    self.assertIn("logged engine errors", result_error(LABEL, result) or "")

    def test_quoted_or_stderr_only_marker_cannot_claim_suite_completion(self) -> None:
        for result in [self.result("expected: " + ACTUAL_IDLE_COMPLETION), self.result(stderr=ACTUAL_IDLE_COMPLETION)]:
            self.assertIn("without its PASS marker", result_error(LABEL, result) or "")

    def test_other_suites_completion_is_rejected(self) -> None:
        self.assertIn("without its PASS marker", result_error(LABEL, self.result("PASS: wardrobe runtime checks\n")) or "")

    def test_only_clean_import_can_complete_without_a_test_marker(self) -> None:
        self.assertIsNone(result_error("clean project import", self.result("import complete")))
        self.assertIn("no configured completion marker", result_error("unregistered runtime suite", self.result("PASS: something\n")) or "")
        self.assertIn("logged engine errors", result_error("clean project import", self.result(stderr="ERROR: import failed")) or "")

    def test_every_selected_runtime_suite_has_one_completion_contract(self) -> None:
        tree = ast.parse(inspect.getsource(main))
        checks = next(node.value for node in ast.walk(tree) if isinstance(node, ast.Assign) and any(isinstance(target, ast.Name) and target.id == "checks" for target in node.targets))
        labels = [ast.literal_eval(row.elts[0]) for row in checks.elts]
        self.assertEqual(len(labels), len(set(labels)), "runtime suite names must be unique")
        self.assertEqual(set(labels) - {"clean project import"}, set(PASS_MARKERS), "new suites require a completion contract; retired suites cannot leave stale contracts")

    def test_suite_sidecar_directories_do_not_share_prior_suite_files(self) -> None:
        # Exercise the actual runner loop with a fake engine that owns the same
        # relative photo/cache names in every invocation. Distinct JSON names
        # alone must not permit any later suite to see those earlier sidecars.
        tree = ast.parse(inspect.getsource(main))
        checks = next(node.value for node in ast.walk(tree) if isinstance(node, ast.Assign) and any(isinstance(target, ast.Name) and target.id == "checks" for target in node.targets))
        labels = [ast.literal_eval(row.elts[0]) for row in checks.elts]
        observed: list[Path] = []
        protected: dict[Path, bytes] = {}

        def fake_engine(_root, command, *, env, timeout):
            label = labels[len(observed)]
            save = Path(env["SNAPLAND_SAVE_PATH"])
            self.assertTrue(save.is_absolute())
            self.assertTrue(save.parent.is_dir(), "runner prepares the private writable profile directory")
            sidecars = [save.parent / "photos" / "same-name.png", save.parent / "cache" / "same-name.bin"]
            for sidecar in sidecars:
                self.assertFalse(sidecar.exists(), f"{label} sees a previous suite sidecar: {sidecar}")
                sidecar.parent.mkdir(parents=True, exist_ok=True)
                payload = label.encode("utf-8")
                sidecar.write_bytes(payload)
                protected[sidecar] = payload
            for path, payload in protected.items():
                self.assertEqual(path.read_bytes(), payload, "a later suite overwrote another suite's sidecar")
            self.assertEqual(timeout, 240 if label == "avatar renderer tests" else 90)
            observed.append(save)
            return subprocess.CompletedProcess(command, 0, PASS_MARKERS.get(label, "import complete") + "\n", "")

        with mock.patch.dict(os.environ, {"GODOT_BIN": "fixture-godot"}), \
             mock.patch("tools.run_game_tests.subprocess.run", return_value=self.result("4.7.2.stable.official.fixture")), \
             mock.patch("tools.run_game_tests.run_validated_godot", side_effect=fake_engine), \
             redirect_stdout(io.StringIO()):
            self.assertEqual(main(), 0)
        self.assertEqual(len(observed), len(labels), "every configured runtime suite was dispatched")
        self.assertEqual(len({path.parent for path in observed}), len(labels))

    def run_with_fake_engine(self, argv: list[str], failing: set[str]) -> tuple[int, list[tuple[str, float]], str]:
        """Drive the real runner loop; returns exit code, dispatched (label, timeout) and stderr."""
        dispatched: list[tuple[str, float]] = []
        tree = ast.parse(inspect.getsource(main))
        checks = next(node.value for node in ast.walk(tree) if isinstance(node, ast.Assign) and any(isinstance(target, ast.Name) and target.id == "checks" for target in node.targets))
        # Each suite command carries one unique key: its res:// entry, the smoke flag or the import flag.
        keys = {}
        for row in checks.elts:
            label = ast.literal_eval(row.elts[0])
            found = re.findall(r"res://[^'\"]+|--smoke-test|--import", ast.unparse(row.elts[1]))
            keys[found[0]] = label

        def fake_engine(_root, command, *, env, timeout):
            label = next(keys[part] for part in command if part in keys)
            dispatched.append((label, timeout))
            stdout = "" if label in failing else (PASS_MARKERS.get(label, "import complete") + "\n")
            return subprocess.CompletedProcess(command, 0, stdout, "")

        errors = io.StringIO()
        with mock.patch.dict(os.environ, {"GODOT_BIN": "fixture-godot"}), \
             mock.patch("tools.run_game_tests.subprocess.run", return_value=self.result("4.7.2.stable.official.fixture")), \
             mock.patch("tools.run_game_tests.run_validated_godot", side_effect=fake_engine), \
             redirect_stdout(io.StringIO()), redirect_stderr(errors):
            try:
                code = main(argv)
            except SystemExit as exit_error:
                code = int(exit_error.code or 0)
        return code, dispatched, errors.getvalue()

    def test_default_run_stops_at_first_failure(self) -> None:
        code, dispatched, _ = self.run_with_fake_engine([], {"core runtime tests", "audio runtime tests"})
        self.assertEqual(code, 1)
        self.assertEqual(dispatched[-1][0], "core runtime tests", "CI behaviour is unchanged: the first failure ends the run")

    def test_keep_going_reports_every_failure(self) -> None:
        code, dispatched, errors = self.run_with_fake_engine(["--keep-going"], {"core runtime tests", "audio runtime tests"})
        self.assertEqual(code, 1)
        self.assertEqual(len(dispatched), len(PASS_MARKERS) + 1, "every suite still runs after a failure")
        self.assertIn("2 of", errors)
        self.assertIn("core runtime tests", errors)
        self.assertIn("audio runtime tests", errors)

    def test_only_selects_matching_suites_after_import(self) -> None:
        code, dispatched, _ = self.run_with_fake_engine(["--only", "fountain"], set())
        self.assertEqual(code, 0)
        self.assertEqual([label for label, _ in dispatched], ["clean project import", "fountain jump view tests", "fountain timing tests"])
        code, dispatched, errors = self.run_with_fake_engine(["--only", "no-such-suite"], set())
        self.assertEqual(code, 1)
        self.assertIn("matched no runtime suite", errors)

    def test_timeout_scale_only_lengthens_limits(self) -> None:
        code, dispatched, _ = self.run_with_fake_engine(["--only", "avatar renderer", "--timeout-scale", "2"], set())
        self.assertEqual(code, 0)
        self.assertEqual(dict(dispatched)["avatar renderer tests"], 480)
        self.assertEqual(dict(dispatched)["clean project import"], 180)
        code, dispatched, _ = self.run_with_fake_engine(["--timeout-scale", "0.5"], set())
        self.assertEqual(code, 2, "argparse rejects a shorter limit")
        self.assertEqual(dispatched, [])

    def test_newly_registered_contracts_require_real_completion(self) -> None:
        cases = {
            "source registration coordinate tests": "PASS: body registration, independent palette/boot coordinates and immutable rebuild",
            "authored avatar side idle tests": "PASS: dedicated stable idle timing, source diagnostics, and reduced-motion stance",
            "atomic outfit coverage tests": "PASS: atomic outfit coverage (333 checks)",
            "side outfit palette tests": "PASS: side jacket palette, 72 source-bound cases, exposed cloth witnesses and curly hair occlusion",
        }
        for label, completion in cases.items():
            with self.subTest(label=label):
                self.assertIn("without its PASS marker", result_error(label, self.result()) or "")
                self.assertIsNone(result_error(label, self.result(completion)))


if __name__ == "__main__":
    unittest.main()
