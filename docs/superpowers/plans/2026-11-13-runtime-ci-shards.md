# Runtime CI Shards Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task.

**Goal:** MAIN-25, complete deterministic four-way CI runtime execution within bounded job time. Preserve all current checks and local default behavior.

**Architecture:** One existing suite registry, a pure stable-label partition, current execution/validation unchanged. Shared authoring/source preflight once, then four required matrix jobs. No dependency or distributed-test framework.

**Spec:** `design/runtime/runtime-ci-shards.md`. Stack: Python standard library, existing Godot4.7.2 runner, GitHub Actions.

## Global Constraints

- Work only C:/Users/stanl/Github/Snapland/.review/runtime-ci-worktree on assigned codex branch. No implementer branch changes/push/subagents. Not alone; do not revert other work. Parent later rebases onto MAIN-24 main closure.
- Author/committer stanley890314@gmail.com, no assistant/model names or Co-Authored-By trailers. Stage only owned source/tests; leave generated metadata untouched.
- No game/assets/rewards/save schema changes. Every actual test retains isolated absolute SNAPLAND_SAVE_PATH; runner already gives each suite a separate parent directory, preserve that behavior.
- No tests omitted or duplicated except required clean import in each shard. Preserve version checks, registry/marker validation, entrypoint safety, exact expected diagnostic policy, deadlines and all existing flags/defaults.
- Standard library only, no general scheduler/configurable registry/plugin framework or dependency upgrades. No visual/human-play/listening claims.
- Controller owns ticket/docs/evidence/publication; CI source preflight and every matrix shard must pass before completion.

## Review Focus

- Stable cross-process label partition, exact union/disjointness for actual configured suites, no second or manually copied catalog.
- Clean import first per shard; no empty/default-import-only success or missing test/marker hidden by selection.
- Local default unchanged; invalid/mixed CLI fails clearly; subprocess safety/per-suite save paths and strict completion parser unchanged.
- Workflow retains every existing gate/event/permission and runs common source preflight once; all four matrix jobs and their correct arguments exist, fail-fast false.

### Task 1: Deterministic runner partition and real catalog coverage

**Files:** Modify `tools/run_game_tests.py`; create `tests/test_runtime_shards.py`; update only concretely affected existing runner contract fixtures if needed. No workflow/game/assets edits.

**Interfaces:** `--shard-index I --shard-count N` 0-based, both-or-neither; invalid/negative/outside/empty and --only combination fail. Default invocation unchanged. Extract one reusable suite-construction function and one selection/partition helper if required; choose clear names and record for Task2. Use stable hashlib label hash, preserve registry order and commands.

- [ ] Run existing result/entrypoint contract baseline before changes; write/run red shard tests using actual registry plus small edge fixtures, then implement.
- [ ] Move existing registry without altering commands/order. Validate unique labels, complete marker correspondence and nonempty runtime catalog. Keep every existing missing-engine/test/version/marker/error guard; missing markers cannot hide in unselected shards.
- [ ] Add validated CLI pair; stable per-label assignment independent of process hash seed/input membership/order, clean import always first, exactly-once union across4 and representative other counts. Reject empty shard and --only mixing. Default and old flags keep current semantics.
- [ ] Meaningful tests cover real registry completeness/partition union/disjointness, ordering/no mutation, stable membership, invalid values, actual main selection invocation, nonzero/errors/missing marker behavior and per-suite profile isolation. Do not mirror the chosen hash's numeric answers.
- [ ] Run focused new+existing Python contracts and one actual Godot shard (not only mocked commands). Record exact labels/count, pinned engine, isolated profiles and output. No repeat full suite required locally; four real cloud shards are Task2/controller gate.
- [ ] Self-review, commit owned paths, detailed task-1-report.md with status/commit/interfaces/exact commands/logs/concerns. Do not change workflow or tickets.

### Task 2: Complete required CI matrix and timing evidence

**Files:** Modify `.github/workflows/full-tests.yml`; only affected existing workflow contract tests if concretely necessary. No runner/game/assets edits.

**Interfaces:** Consume Task1 flags, four indices0/1/2/3 with count4. Preserve full-suite job and all triggers, shared source gates once as a required prerequisite, game-runtime becomes fail-fast:false matrix.

- [ ] Read actual workflow and source preflight requirements. Preserve pinned Python/Godot/action versions, rights, timeouts, concurrency and all existing source/runtime/coverage/entrypoint checks.
- [ ] Move authoring/source preflight from repeated runtime job to a required once-only job; install its existing pinned engine there. Each runtime matrix job installs its own original pinned engine, keeps parser/entrypoint/partition coverage validation and runs its exact shard. No missing fourth job or partial --only filter.
- [ ] Validate existing/new contracts and exact matrix/flag coverage without a new YAML dependency. Parent pushes and runs actual full cloud workflow; any syntax/coverage failure must be fixed, no bypass.
- [ ] Self-review, commit owned paths, detailed task-2-report.md. Controller records per-job actual results/times, confirms full actual universe covered, reviews branch, updates ticket and merges/pushes/cleans. No visual screenshot is needed because product UI is unchanged.
