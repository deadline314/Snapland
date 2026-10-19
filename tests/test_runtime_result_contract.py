"""Runtime completion cannot hide engine errors, early exits or another suite's output."""
from __future__ import annotations

import ast
import inspect
import subprocess
import unittest

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
