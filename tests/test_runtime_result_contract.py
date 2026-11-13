"""Runtime completion cannot hide engine errors, early exits or another suite's output."""
from __future__ import annotations

from contextlib import redirect_stderr, redirect_stdout
import io
import os
from pathlib import Path
import subprocess
import unittest
from unittest import mock

from tools.run_game_tests import PASS_MARKERS, build_checks, main, result_error

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
        labels = [label for label, _ in build_checks("fixture-godot")]
        self.assertEqual(len(labels), len(set(labels)), "runtime suite names must be unique")
        self.assertEqual(set(labels) - {"clean project import"}, set(PASS_MARKERS), "new suites require a completion contract; retired suites cannot leave stale contracts")

    def test_rowing_markers_require_exact_zero_failure_completion(self) -> None:
        for label in ('rowing cargo model tests', 'rowing cargo driver tests', 'rowing cargo view tests',
                      'rowing Session tests', 'harbor collection tests', 'rowing Main tests', 'rowing native fixture tests',
                      'delivered game catalog tests', 'harbor game progress tests', 'sandbar model tests',
                      'sandbar driver tests', 'sandbar view tests', 'sandbar Session tests', 'sandbar Main tests',
                      'sandbar native fixture tests', 'prism model tests', 'prism driver tests', 'prism view tests',
                      'prism Session tests', 'prism Main tests', 'prism native fixture tests', 'tug model tests',
                      'tug driver tests', 'tug view tests', 'tug Session tests', 'tug Main tests', 'tug native fixture tests',
                      'crab native fixture tests', 'crab Main tests', 'crab Session tests', 'crab view tests', 'crab driver tests', 'crab model tests',
                      'cargo native fixture tests', 'cargo Main tests', 'cargo Session tests', 'cargo view tests', 'cargo driver tests', 'cargo model tests',
                      'relay native fixture tests', 'relay Main tests', 'relay Session tests', 'relay view tests', 'relay driver tests', 'relay model tests'):
            marker = PASS_MARKERS[label]
            with self.subTest(label=label):
                self.assertIsNone(result_error(label, self.result(marker + '\n')))
                self.assertIsNotNone(result_error(label, self.result(marker + ' trailing unverified output\n')))

    def test_suite_sidecar_directories_do_not_share_prior_suite_files(self) -> None:
        # Exercise the actual runner loop with a fake engine that owns the same
        # relative photo/cache names in every invocation. Distinct JSON names
        # alone must not permit any later suite to see those earlier sidecars.
        labels = [label for label, _ in build_checks("fixture-godot")]
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
            stderr = f"ERROR: Cannot write progress temporary file '{save}.tmp': Can't open file" if label == "boat prologue state tests" else ""
            return subprocess.CompletedProcess(command, 0, PASS_MARKERS.get(label, "import complete") + "\n", stderr)

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
        keys = {tuple(command): label for label, command in build_checks("fixture-godot")}

        def fake_engine(_root, command, *, env, timeout):
            label = keys[tuple(command)]
            dispatched.append((label, timeout))
            stdout = "" if label in failing else (PASS_MARKERS.get(label, "import complete") + "\n")
            stderr = f"ERROR: Cannot write progress temporary file '{env['SNAPLAND_SAVE_PATH']}.tmp': Can't open file" if label == "boat prologue state tests" else ""
            return subprocess.CompletedProcess(command, 0, stdout, stderr)

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

    def test_boat_state_requires_one_exact_error_for_its_own_profile(self) -> None:
        label = "boat prologue state tests"
        save = "C:/isolated/regex [profile]+/progress.json"
        expected = f"ERROR: Cannot write progress temporary file '{save}.tmp': Can't open file"
        marker = PASS_MARKERS[label]
        self.assertIsNone(result_error(label, self.result(marker, expected), save))
        for stderr in ["", expected + "\n" + expected, expected.replace(save, "C:/other/progress.json"),
                       expected.replace("Can't open file", "Permission denied"), expected + " extra"]:
            with self.subTest(stderr=stderr):
                self.assertIn("exactly one", result_error(label, self.result(marker, stderr), save) or "")
        for extra in ["ERROR: another IO failure", "SCRIPT ERROR: Parse Error", "SCRIPT ERROR: Assertion failed"]:
            self.assertIn("logged engine errors", result_error(label, self.result(marker, expected + "\n" + extra), save) or "")
        self.assertIsNotNone(result_error(label, self.result(marker, expected)))
        self.assertIn("logged engine errors", result_error("boat prologue stage tests", self.result(PASS_MARKERS["boat prologue stage tests"], expected), save) or "")
        self.assertIn("exited 1", result_error(label, self.result(marker, expected, 1), save) or "")

    def test_boat_suites_require_exact_completion_lines(self) -> None:
        save = "C:/isolated/profile.json"
        for label in ["boat prologue state tests", "boat prologue stage tests", "boat prologue integration tests"]:
            expected = f"ERROR: Cannot write progress temporary file '{save}.tmp': Can't open file" if label == "boat prologue state tests" else ""
            self.assertIsNone(result_error(label, self.result(PASS_MARKERS[label], expected), save))
            for marker in ["", PASS_MARKERS[label] + " suffix", "quoted " + PASS_MARKERS[label]]:
                self.assertIn("without its PASS marker", result_error(label, self.result(marker, expected), save) or "")

    def test_region_suites_require_exact_clean_completion(self) -> None:
        for label in ["region progress tests", "harbor world tests", "region travel tests"]:
            marker = PASS_MARKERS[label]
            self.assertIsNone(result_error(label, self.result(marker)))
            for output in ["", marker + " suffix", "quoted " + marker]:
                self.assertIn("without its PASS marker", result_error(label, self.result(output)) or "")
            self.assertIn("logged engine errors", result_error(label, self.result(marker, "ERROR: resource failed")) or "")
            self.assertIn("exited 1", result_error(label, self.result(marker, code=1)) or "")

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



RETAKE_SUITES = {
    "photo retake progress tests": ("test_photo_retake_progress.gd", "PASS: attempt history, selected retake awards, provenance and atomic rollback"),
    "participation result tests": ("test_participation_results.gd", "PASS: every delivered participation result, practice, cancellation and driver eligibility"),
    "retake panel tests": ("test_retake_panel.gd", "PASS: retake panel canonical targets, reversible state, keyboard and capture guards"),
    "photo retake Main tests": ("test_photo_retake_main.tscn", "PASS: Main selected retakes, actual attempts, truthful awards and safe PNG replacement"),
    "retake native fixture tests": ("test_retake_native_fixture.gd", "PASS: retake native fixture adjacent helper, isolated packaging and real resources"),
}


class RetakeRunnerTests(unittest.TestCase):
    def test_all_five_entries_and_strict_completion(self):
        checks = dict(build_checks("fixture-godot"))
        for label, (entry, marker) in RETAKE_SUITES.items():
            with self.subTest(label=label):
                self.assertIn(label, checks)
                self.assertIn("res://game/tests/" + entry, checks[label])
                self.assertEqual(PASS_MARKERS[label], marker)
                for output in ("", marker + " suffix", "quoted " + marker):
                    self.assertIsNotNone(result_error(label, subprocess.CompletedProcess([], 0, output, "")))
                self.assertIsNone(result_error(label, subprocess.CompletedProcess([], 0, marker, "")))
                for diagnostic in ("ERROR: failed", "SCRIPT ERROR: Parse Error"):
                    self.assertIsNotNone(result_error(label, subprocess.CompletedProcess([], 0, marker, diagnostic)))


if __name__ == "__main__":
    unittest.main()
