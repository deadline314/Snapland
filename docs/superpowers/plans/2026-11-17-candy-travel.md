# 糖果工廠旅行 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver MAIN-26 as a third explorable region with safe persistence, truthful menus and native/package evidence.

**Architecture:** Reuse ParkWorld's existing region override hooks and Progress's atomic current_region lifecycle. Keep geometry and interaction snapshots in CandyWorld; Main owns transitions and UI dispatch. Share a small terrain chart only where both maps have the same rendering responsibility.

**Tech Stack:** Godot 4.7.2, GDScript, existing Paper UI, Python verification/packaging tools; no new dependencies.

**Spec:** [糖果工廠往返與材料探索](../../../design/runtime/candy-travel.md)

## Global Constraints

- Gate is six distinct ordinary photos, never consumed; return is permanently free.
- Persist candy through the existing save version; preserve welcome/harbor and unrelated save data.
- No new game or collectible is credited in this ticket; factory toy is an observation, not game-025.
- Keep one world at steady state; persist before replacement and ignore stale events.
- Godot launches use run_validated_godot and isolated absolute SNAPLAND_SAVE_PATH.
- User authorizes implementation, commit/push/main integration and cleanup without repeated questions; author email is stanley890314@gmail.com.

## Review Focus

- Unknown region or malformed save: welcome fallback preserves other fields; candy is accepted, not confused with harbor.
- Save failure or reentrant transition: original world remains functional and no duplicate world survives.
- No local games/tasks/photos: menus show honest empty state while existing collections and originals remain accessible.
- Temperature and reset spam: bounded nodes/materials, stable footing, no rewards and no unbounded state growth.
- Missing optional region nodes and small UI: settings, day/night, camera, return and large text remain usable.

## Task 1: Factory world and bounded material observation

**Ownership:** game/world/candy_world.gd; game/tests/test_candy_world.gd. Worker must not modify Main, Progress, UI or runtime registry.

**Interfaces:** ParkWorld region hooks; cycle_temperature(), temperature_label(), reset_to_entry(), map_snapshot() as specified. Static bounds/land/spawn constants available to tests, snapshot is detached values.

- [x] Pin connected land, safe spawn/reset, actual map points and all three temperature states in a focused test.
- [x] Build distinct factory geometry using existing native primitives/material helpers; preserve shared character/camera/grounding owner.
- [x] Verify no welcome activities/NPCs, no game/reward IDs, reset zeroes velocity, settings and temperature changes keep node counts bounded.
- [x] Run affected world tests through the validated launcher; report exact marker and changed files for review.

## Task 2: Three-region state, Main and truthful UI

**Ownership:** game/core/progress.gd; game/main.gd; game/world/park_world.gd::_build_gates(); affected UI map/book files and corresponding tests. A small pure region lookup or shared terrain chart is allowed only if it removes actual repeated region assumptions. Worker does not edit CandyWorld or runtime runner registry.

**Interfaces:** CandyWorld interface from Task 1; existing atomic set_current_region and replacement lifecycle. No world preloads in persistence-only data helpers.

- [x] Add third-region roundtrip, invalid legacy region, save failure, gate difference and existing-region preservation cases before changing behavior.
- [x] Find and update all two-region assumptions in Main, HUD, pause, map, book, guide, tasks, reset and restart. Keep the original welcome and harbor paths tested.
- [x] Add safe candy interaction dispatch, map and short hover copy; use real terrain/points and honest empty local content.
- [x] Test reentry, failed save, stale events, old-world release and repeated three-way switching; verify settings and missing optional nodes.
- [x] Run affected state/Main/UI regression and hand exact new test markers to the root agent for registry integration.

## Task 3: Delivery verification and ticket closure

**Ownership:** root owns tools/run_game_tests.py registry, any dedicated native fixture, design/runtime/full-game-delivery.md, pm ticket, evidence and Git operations.

- [x] Register all new runtime tests with required pass markers and check runtime coverage configuration.
- [x] Review each worker's result against the spec and check the entire final branch; fix actionable findings.
- [x] Run affected local tests, design/link validation, native three-size route/restart checks and isolated output validation.
- [ ] Add only actual evidence, mark MAIN-26 acceptance when met, commit/push separately from any later SG-41 implementation.
- [ ] Fetch/rebase latest main if needed, integrate/push main, inspect CI and remove only the delivered owned branch/worktree.

## Execution ledger

- Ticket opening: 47face2, pushed codex/candy-world-20261117.
- Ruling: work in the current clean tracked checkout on a feature branch rather than duplicate the large artifact tree into a worktree; preserve all unrelated untracked import/UID files.
- Ruling: implement only the third-region foundation in MAIN-26; follow with the genuinely different material/bridge gameplay as its own ticket, preserving the basic-game count.
- Preflight: read-only builder check found no blocker; Task 2 also owns the physical welcome candy gate label, breadcrumbs and achievement summary names. Candy reuses the existing valid plaza music context without new audio assets or listening claims.
- Task 1 static review: no actionable source/spec issue; 4,140 headless checks pass across three builds. Native visual round 1 found unreadable small signs and overbright floors against an empty backdrop; original implementer owns the bounded readability/theme fix, preserving topology and reward scope.
- Task 2: expanded persistence/travel and legacy book checks pass; fresh read-only review found no actionable lifecycle or scope defect.
- Baseline before code: clean import 5.35 s, region progress 0.70 s, harbor world 36.69 s, region travel 29.23 s; all passed.
- Native initial 1280×720: real Main buttons and input actions exercised all three regions, temperature/reset, saved restart writer and truthful menus; 14 captures and no engine errors. This functional pass did not accept initial world art.
- Task 1: fix round 1/5 (initial floor/sign theme findings addressed in source, native sign clipping open). Covering test: 4,239 checks, three builds, 100 meshes/143 nodes each. Enlarged billboard text intersects fixed signboards in native images; round 2 keeps candy sign text parallel to its board without changing shared labels or disabling depth.
- Native harness correction: restart correctly produces 12 captures rather than the writer's 14; inspect the dedicated engine log as well as captured streams, since Windows console forwarding omitted the final marker from one stream. Preserve that first run and require explicit exit, marker and failure-free report on fresh runs.
- Task 1: fix round 2/5 (1 addressed, 0 open). Sign-alignment regression: 21 red failures; 4,260 green checks, exact marker, exit 0. Scoped review found no new breakage. Fresh 1280×720 GPU arrival/temperature captures show complete legible physical labels with depth retained.
- Registry/contracts: 20 Python completion-contract tests, runtime registration check and all five design scopes passed; no gameplay or listening claim from those checks.
- Task 2 native map finding: Paper label autowrap split each numbered location into fragments. Fix round 1 keeps whole location entries in the existing HFlow. Candy retains full small-viewport containment tests. Harbor's separate 3713 px footer overflow reproduced with original and fixed wrapping alike, so MAIN-27 records that pre-existing issue independently; no assertion claims all harbor content currently fits.
- Fresh whole-branch review: no other actionable MAIN-26 findings in lifecycle, persistence, world/map and legacy menus. Final six native writer/restart runs passed across three sizes; map-layout correction additionally repeated all three restart routes. Private embedded Windows QA writer/restart also passed, then re-exported and repeated after layout correction. Audio driver was Dummy; no human play/listening claim.
- Task 2: fix round 1/5 (1 addressed, 0 new open). Whole-entry map labels pass focused source review and final native layout captures. Existing harbor footer width remains tracked by MAIN-27.
- Final affected validation: 14 distinct suites passed with strict completion/error contracts (first three in affected-final, next ten in affected-rest, retake Main in retake-final). The initial retake run also exposed intermittent 5-resource/10-object shutdown warnings. Same-project, same-fixture, same-flags, same-profile origin/main 5655318 reproduction proves this pre-existing; MAIN-28 was opened/pushed independently, not waived or called fixed.
- Task 2: fix round 2/5 separates a proven fixture teardown race from that existing warning: setting quitting before shutdown and emitting a real late area event gives deterministic red/green protection against audio reactivation. Production Main unchanged. Four-line fixture fix covering retake run passed; no extra error allowlist or arbitrary drain wait was added.
- Final most-capable whole-branch review: no Critical/Important finding. Minor QA provenance flag: writer inherited scripted_profile_setup=false despite synthetic setup. A dedicated one-line QA fix sets it only in writer mode; all previous raw evidence is retained and fresh root/package writer/readers will prove the corrected field. No gameplay/source asset behavior changes.

- Final QA provenance correction: fresh root and re-exported private writer/readers pass with true/false setup flags respectively, 14/12 captures each. Previous raw reports retained with an explicit legacy-field correction note. Scoped most-capable re-review accepted, no new finding. Compact evidence now records 15 native cases and source/executable hashes.
