"""Partition the real runtime catalog without weakening its execution contract."""
from __future__ import annotations

from collections import Counter
from contextlib import redirect_stderr, redirect_stdout
import ast
import copy
import io
import os
from pathlib import Path
import re
import subprocess
import sys
import unittest
from unittest import mock

from tools import run_game_tests as runner


class RuntimeShardTests(unittest.TestCase):
    def setUp(self) -> None:
        self.checks = runner.build_checks("fixture-godot")

    def test_real_catalog_has_exact_marker_coverage_and_valid_entrypoints(self) -> None:
        from tools.godot_entrypoints import validate_godot_command

        labels = [label for label, _ in self.checks]
        self.assertEqual(labels[0], "clean project import")
        self.assertEqual(len(labels), len(set(labels)))
        self.assertEqual(set(labels[1:]), set(runner.PASS_MARKERS))
        for label, command in self.checks:
            with self.subTest(label=label):
                self.assertIsNone(validate_godot_command(runner.ROOT, command))

    def test_real_shards_cover_every_runtime_suite_once_in_original_order(self) -> None:
        original = copy.deepcopy(self.checks)
        for count in (1, 2, 3, 4, 7):
            seen = Counter()
            for index in range(count):
                selected = runner.select_checks(self.checks, shard_index=index, shard_count=count)
                self.assertEqual(selected[0], self.checks[0])
                self.assertGreater(len(selected), 1)
                self.assertEqual(selected, [row for row in self.checks if row in selected])
                seen.update(label for label, _ in selected[1:])
            self.assertEqual(seen, Counter(runner.PASS_MARKERS.keys()))
        self.assertEqual(self.checks, original)

    def test_ci_matrix_runs_the_complete_real_partition_after_source_checks(self) -> None:
        workflow = (runner.ROOT / ".github/workflows/full-tests.yml").read_text(encoding="utf-8")
        jobs = dict(re.findall(r"^  ([\w-]+):\n(.*?)(?=^  [\w-]+:|\Z)",
                               workflow.split("\njobs:\n", 1)[1], re.M | re.S))
        runtime = jobs["game-runtime"]
        self.assertIn("    needs: runtime-source\n", runtime)
        strategy = runtime.split("    strategy:\n", 1)[1].split("    steps:\n", 1)[0]
        matrix = re.fullmatch(r"      fail-fast: false\n      matrix:\n        shard-index: (\[[^\n]+\])\n", strategy)
        self.assertIsNotNone(matrix, "all four shards must run without matrix exclusions or early cancellation")
        indices = ast.literal_eval(matrix.group(1))
        command = re.findall(r"^        run: python tools/run_game_tests.py (.+)$", runtime, re.M)
        self.assertEqual(len(command), 1)
        flags = re.fullmatch(r"--shard-index \$\{\{ matrix.shard-index \}\} --shard-count (\d+)", command[0])
        self.assertIsNotNone(flags, "CI must run its complete shard without local filters")
        count = int(flags.group(1))
        self.assertEqual(count, 4)
        self.assertEqual(indices, list(range(count)))
        seen = Counter()
        for index in indices:
            selected = runner.select_checks(self.checks, shard_index=index, shard_count=count)
            self.assertEqual(selected[0], self.checks[0])
            seen.update(label for label, _ in selected[1:])
        self.assertEqual(seen, Counter(runner.PASS_MARKERS.keys()))
        source = jobs["runtime-source"]
        self.assertNotIn("    strategy:", source, "shared source checks run once")
        for script in ("tools/check_runtime_tests.py", "tools/hero_2d/run_contract_tests.py",
                       "tools/hero_2d/run_hair_review.py --contracts",
                       "tools/walk_stability/run_audit.py --tag ci --test",
                       "tools/island_avatar/run_contracts.py"):
            line = f"        run: python {script}\n"
            self.assertEqual(workflow.count(line), 1)
            self.assertIn(line, source)
        self.assertIn("tests.test_runtime_shards", runtime)
        self.assertIn("tests.test_runtime_result_contract", runtime)
        self.assertIn("tests.test_godot_entrypoints", runtime)
        for job in (source, runtime):
            self.assertNotRegex(job, r"(?m)^\s+(?:if|continue-on-error):")
            self.assertIn("Godot_v4.7.2-stable_linux.x86_64.zip", job)

    def test_membership_does_not_depend_on_other_labels_or_input_order(self) -> None:
        count = 4
        before = [runner.select_checks(self.checks, shard_index=i, shard_count=count)[1:] for i in range(count)]
        extended = self.checks + [("new runtime suite", ["fixture-command"])]
        with mock.patch.dict(runner.PASS_MARKERS, {"new runtime suite": "PASS: new"}):
            for index in range(count):
                selected = runner.select_checks(extended, shard_index=index, shard_count=count)
                self.assertEqual([row for row in selected[1:] if row[0] != "new runtime suite"], before[index])
        reversed_checks = self.checks[:1] + self.checks[:0:-1]
        for index in range(count):
            selected = runner.select_checks(reversed_checks, shard_index=index, shard_count=count)
            self.assertEqual(selected[1:], list(reversed(before[index])))

    def test_membership_is_stable_across_process_hash_seeds(self) -> None:
        script = ("from tools.run_game_tests import build_checks, select_checks; "
                  "print([[label for label, _ in select_checks(build_checks('fixture'), "
                  "shard_index=i, shard_count=4)] for i in range(4)])")
        outputs = []
        for seed in ("1", "8473"):
            env = dict(os.environ, PYTHONHASHSEED=seed)
            result = subprocess.run([sys.executable, "-c", script], cwd=runner.ROOT, env=env,
                                    check=True, capture_output=True, text=True)
            outputs.append(result.stdout)
        self.assertEqual(outputs[0], outputs[1])

    def test_default_and_only_preserve_existing_selection(self) -> None:
        self.assertEqual(runner.select_checks(self.checks), self.checks)
        selected = runner.select_checks(self.checks, only=["fountain", "audio runtime"])
        self.assertEqual(selected, [row for row in self.checks
                                   if row[0] == "clean project import" or "fountain" in row[0] or "audio runtime" in row[0]])
        with self.assertRaisesRegex(ValueError, "matched no runtime suite"):
            runner.select_checks(self.checks, only=["not-a-suite"])

    def test_invalid_shard_options_fail_before_engine_discovery(self) -> None:
        cases = (["--shard-index", "0"], ["--shard-count", "4"],
                 ["--shard-index", "0", "--shard-count", "0"],
                 ["--shard-index", "0", "--shard-count", "-2"],
                 ["--shard-index", "-1", "--shard-count", "4"],
                 ["--shard-index", "4", "--shard-count", "4"],
                 ["--shard-index", "0", "--shard-count", "4", "--only", "core"],
                 ["--shard-index", "1.5", "--shard-count", "4"])
        for argv in cases:
            with self.subTest(argv=argv), redirect_stderr(io.StringIO()), mock.patch.object(runner.shutil, "which") as which:
                with self.assertRaises(SystemExit) as caught:
                    runner.main(argv)
                self.assertEqual(caught.exception.code, 2)
                which.assert_not_called()

    def test_count_exceeding_runtime_catalog_and_empty_shards_fail(self) -> None:
        with self.assertRaisesRegex(ValueError, "exceeds.*runtime"):
            runner.select_checks(self.checks, shard_index=0, shard_count=len(self.checks))
        # Pigeonhole guarantees an empty bucket; do not pin an implementation's hash answers.
        tiny = [("clean project import", []), ("a", []), ("b", []), ("c", [])]
        for pair in (("a", "b"), ("a", "c"), ("b", "c")):
            checks = tiny[:1] + [row for row in tiny[1:] if row[0] in pair]
            with mock.patch.object(runner, "PASS_MARKERS", {label: "PASS" for label in pair}):
                errors = []
                for index in range(2):
                    try:
                        runner.select_checks(checks, shard_index=index, shard_count=2)
                    except ValueError as error:
                        errors.append(str(error))
                if errors:
                    self.assertTrue(all("empty" in error for error in errors))
                    break
        else:
            self.fail("three labels in two buckets must contain a colliding pair")

    def test_whole_catalog_validation_precedes_selection(self) -> None:
        cases = ([], self.checks[:1], self.checks + [self.checks[1]], self.checks[1:],
                 self.checks + [("unmarked runtime suite", [])],
                 [row for row in self.checks if row[0] != "audio runtime tests"])
        for checks in cases:
            with self.subTest(labels=[row[0] for row in checks]), self.assertRaises(ValueError):
                runner.select_checks(checks, only=["fountain"])
        markers = dict(runner.PASS_MARKERS)
        del markers["audio runtime tests"]
        with mock.patch.object(runner, "PASS_MARKERS", markers), self.assertRaisesRegex(ValueError, "completion marker"):
            runner.select_checks(self.checks, shard_index=0, shard_count=4)

    def run_main(self, argv, *, broken=None, import_failure=False):
        selected = runner.select_checks(self.checks, shard_index=1, shard_count=4)
        labels = {tuple(command): label for label, command in self.checks}
        observed = []
        paths = []

        def engine(_root, command, *, env, timeout):
            label = labels[tuple(command)]
            observed.append(label)
            save = Path(env["SNAPLAND_SAVE_PATH"])
            self.assertTrue(save.is_absolute())
            self.assertTrue(save.parent.is_dir())
            sidecar = save.parent / "same-sidecar.bin"
            self.assertFalse(sidecar.exists())
            sidecar.write_bytes(label.encode())
            self.assertNotIn(save.parent, paths)
            paths.append(save.parent)
            self.assertEqual(timeout, (240 if label == "avatar renderer tests" else 90) * 2)
            if label == selected[1][0] and broken is not None:
                if isinstance(broken, Exception):
                    raise broken
                return subprocess.CompletedProcess(command, *broken)
            if label == "clean project import" and import_failure:
                return subprocess.CompletedProcess(command, 0, "", "ERROR: failed import")
            diagnostic = f"ERROR: Cannot write progress temporary file '{save}.tmp': Can't open file" if label == "boat prologue state tests" else ""
            return subprocess.CompletedProcess(command, 0, runner.PASS_MARKERS.get(label, "imported"), diagnostic)

        errors = io.StringIO()
        with mock.patch.dict(os.environ, {"GODOT_BIN": "fixture-godot"}), \
             mock.patch.object(runner.subprocess, "run", return_value=subprocess.CompletedProcess([], 0, "4.7.2.stable.official", "")), \
             mock.patch.object(runner, "run_validated_godot", side_effect=engine), \
             redirect_stdout(io.StringIO()), redirect_stderr(errors):
            code = runner.main(argv + ["--timeout-scale", "2"])
        return code, observed, errors.getvalue()

    def test_actual_main_dispatches_only_its_shard_with_private_suite_directories(self) -> None:
        code, observed, errors = self.run_main(["--shard-index", "1", "--shard-count", "4"])
        self.assertEqual((code, errors), (0, ""))
        self.assertEqual(observed, [label for label, _ in runner.select_checks(self.checks, shard_index=1, shard_count=4)])

    def test_sharded_execution_retains_failure_and_keep_going_policies(self) -> None:
        selected = runner.select_checks(self.checks, shard_index=1, shard_count=4)
        marker = runner.PASS_MARKERS[selected[1][0]]
        failures = ((7, marker, ""), (0, marker, "ERROR: failed resource"), (0, "", ""),
                    ValueError("invalid entrypoint"), OSError("missing engine"),
                    subprocess.TimeoutExpired(["fixture"], 180, output=b"partial output"))
        for broken in failures:
            with self.subTest(broken=broken):
                code, observed, _ = self.run_main(["--shard-index", "1", "--shard-count", "4"], broken=broken)
                self.assertEqual(code, 1)
                self.assertEqual(observed, [row[0] for row in selected[:2]])
                code, observed, errors = self.run_main(["--shard-index", "1", "--shard-count", "4", "--keep-going"], broken=broken)
                self.assertEqual(code, 1)
                self.assertEqual(observed, [row[0] for row in selected])
                self.assertIn("1 of", errors)
        code, observed, _ = self.run_main(["--shard-index", "1", "--shard-count", "4", "--keep-going"], import_failure=True)
        self.assertEqual((code, observed), (1, ["clean project import"]))

    def test_unselected_missing_marker_prevents_any_engine_suite(self) -> None:
        markers = dict(runner.PASS_MARKERS)
        del markers["audio runtime tests"]
        for argv in (["--only", "fountain"], ["--shard-index", "1", "--shard-count", "4"]):
            with mock.patch.object(runner, "PASS_MARKERS", markers), \
                 mock.patch.dict(os.environ, {"GODOT_BIN": "fixture-godot"}), \
                 mock.patch.object(runner.subprocess, "run", return_value=subprocess.CompletedProcess([], 0, "4.7.2.stable", "")), \
                 mock.patch.object(runner, "run_validated_godot") as engine, redirect_stderr(io.StringIO()):
                self.assertEqual(runner.main(argv), 1)
                engine.assert_not_called()

    def test_shards_require_the_pinned_runnable_engine(self) -> None:
        argv = ["--shard-index", "1", "--shard-count", "4"]
        with mock.patch.dict(os.environ, {}, clear=True), mock.patch.object(runner.shutil, "which", return_value=None), \
             mock.patch.object(runner.subprocess, "run") as version, redirect_stderr(io.StringIO()):
            self.assertEqual(runner.main(argv), 1)
            version.assert_not_called()
        for result in (subprocess.CompletedProcess([], 0, "4.6.stable", ""), OSError("missing engine"),
                       subprocess.TimeoutExpired(["fixture-godot", "--version"], 30)):
            with self.subTest(result=result), mock.patch.dict(os.environ, {"GODOT_BIN": "fixture-godot"}), \
                 mock.patch.object(runner.subprocess, "run", **({"side_effect": result} if isinstance(result, Exception) else {"return_value": result})), \
                 mock.patch.object(runner, "run_validated_godot") as engine, redirect_stderr(io.StringIO()):
                self.assertEqual(runner.main(argv), 1)
                engine.assert_not_called()


if __name__ == "__main__":
    unittest.main()
