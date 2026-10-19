# Runtime CI budget and independent failure evidence

2026-10-20 (Asia/Taipei), base `f14b215`. This is infrastructure verification, not gameplay or animation acceptance.

## Observed failure

[Run 298](https://github.com/deadline314/Snapland/actions/runs/39263438202), runtime job 118096783329, started 13:49:29 UTC and was cancelled at 13:59:42. Checkout used 129 seconds; the four isolated character stages passed. Runtime import/startup/core/save guard/wardrobe/avatar/renderer passed before cancellation during attachments. Renderer alone used 220.9 seconds, within its existing 240-second limit. The job-level ten-minute budget truncated valid work; this is distinct from an individual test timeout. The design job separately failed on SG-1's missing catalogue and skipped all Python tests.

## Primary sources actually read

| Source | Observation and decision |
|---|---|
| [GitHub workflow syntax](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax#jobsjob_idtimeout-minutes) | Job and step budgets differ. Give the unchanged sequential runtime suite a bounded 30-minute job window, then measure actual completion; this is not proof the new run passes. |
| [GitHub status expressions](https://docs.github.com/en/actions/reference/workflows-and-actions/expressions#status-check-functions) | Default success conditions skip later steps. Run independent Python regressions after design failure only when dependency installation succeeded and the run was not cancelled; retain the failed design result. |
| [GitHub concurrency](https://docs.github.com/en/actions/how-tos/write-workflows/choose-when-workflows-run/control-workflow-concurrency) | A new run can cancel an earlier run. Preserve the current concurrency rule and record cancelled runs as cancelled, not passing. |
| [Python subprocess](https://docs.python.org/3/library/subprocess.html#subprocess.Popen.communicate) | Timeout does not itself kill a Popen child. Retain owned-process cleanup and captured diagnostics. |
| [Godot command line](https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html) | Headless execution and movie output have different purposes. Retain headless runtime checks; do not label these rendered playthroughs. |
| [Meson testing](https://mesonbuild.com/Unit-tests.html) | Per-test budgets and streamed results expose where a suite stops. Emit each current test name/index/limit before launch and elapsed time after its validated completion. Do not adopt unlimited timeout. |
| [CTest TIMEOUT](https://cmake.org/cmake/help/latest/prop_test/TIMEOUT.html) | Individual time limits remain separate from whole-run limits. Keep the existing 90/240-second guards. |

Text documentation only; no external image or video review is claimed for this infrastructure change.

## Verification and scope

23 Python result/entrypoint tests pass. AST comparison against the base confirms identical 91 runtime commands, 90 completion contracts and individual timeout assignments. No known-failure waiver, selector change, retry, success override or engine change. Full-suite Python tests now execute despite unrelated design failure; existing catalogue tests can still report SG-1 errors. The original design failure continues to fail the job. Native CI outcome must be recorded from the actual subsequent run.
