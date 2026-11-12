# Harbor Travel Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task.

**Goal:** MAIN-24, real qualified welcome ↔ harbor travel with navigable tide scenery and safe region persistence. No new minigame or collectible grants.

**Architecture:** Add one transactional Progress field, extend existing ParkWorld through small region/terrain hooks, and let Main replace one active world. A harbor-only map and a region-scoped collection view reuse Paper UI; no generic scene framework or dependency.

**Tech Stack:** Godot4.7.2, existing GDScript/PaperUI/AvatarRenderer. Spec: `design/runtime/harbor-travel.md`.

## Global Constraints

- Work only in C:/Users/stanl/Github/Snapland/.review/harbor-travel-worktree, assigned codex branch. No pushes or branch changes by implementers. Parent rebases onto ST-6 main after its pending CI/closure.
- Author/committer email stanley890314@gmail.com, no assistant/model names or Co-Authored-By trailers. Stage only assigned source/test paths, leave generated imports/UIDs untouched.
- Every direct Godot run uses an absolute isolated SNAPLAND_SAVE_PATH. Keep save version1, all old fields including prologue_seen, unknown fields, rewards and stable welcome IDs.
- MAIN-24 is travel/scenery only: no harbor games, story rewards, visit flags, quests or photos; no renamed welcome games. Other eight future gates stay truthful. Global six-card admission never consumes photos/coins.
- Reuse existing player/camera/material/animation/cache behavior; no full duplicate _ready/physics, new dependency or image editing. Only one world resident after replacement and old world freed before building new; never build all zones.
- Traditional Chinese concise UI/hover, actual viewport dimensions for native evidence, no automated result described as human play/listening.
- Implementers are not alone, must not revert others, do not spawn agents; controller owns ticket/docs/evidence publication.

## Review Focus

- Exact preservation of welcome construction, static terrain sampler compatibility and telemetry resets while extracting instance hooks.
- No hidden welcome floors, shoreline clamp, recovery position, NPCs or toys under harbor geometry.
- Save failure happens before releasing the old world; one durable write, no reentrant signals/callbacks or false region claim.
- Tide preview never strands player; actual collision agrees with walkable land/sandbar, free return at both tides.
- Reset/startup/current-region UI agree; welcome photos remain inspectable; no false harbor games/quests/cards and no missing-component crashes.

### Task 1: Transactional current-region state

**Files:** Modify `game/core/progress.gd`, `game/tests/progress_restart_review.gd`; create `game/tests/test_region_progress.gd`.

**Interfaces:** `Progress.current_region: String = "welcome"`; supported persisted values welcome/harbor. `set_current_region(region: String) -> bool` idempotently saves once, rolls back failure and does not emit changed. Missing/invalid/unimplemented destination loads welcome without rejecting other data.

- [ ] Write/run red tests for fresh/reset/missing/malformed/unknown/unimplemented destinations, both supported round trips, same-value no write, rejected value no write, exactly-one-write success, real failure rollback, unknown fields/prologue/rewards preserved.
- [ ] Reach declaration, payload, known-field exclusion, validation/load/reset paths, keeping version1. Optional malformed field warns and defaults welcome. Add current_region to explicit restart snapshot.
- [ ] Cover failure with real isolated IO in a captured child, assert exact expected diagnostic+PASS+exit and no hidden errors; parent suite has clean output (reuse existing child-test convention).
- [ ] Run new state test plus existing core/save/prologue-state regressions; self-review, commit only owned paths, detailed task-1-report.md. Do not edit runner/Main/world/UI.

### Task 2: Reusable world seams and real harbor terrain

**Files:** Modify `game/world/park_world.gd`; create `game/world/harbor_world.gd`, `game/tests/test_harbor_world.gd`.

**Interfaces:** HarborWorld extends ParkWorld; shared world contract unchanged. Expose `set_tide(high: bool)`, `is_high_tide() -> bool`, `take_ferry(point_id: String) -> bool`, `map_snapshot() -> Dictionary` as specified. Points harbor:tide, harbor:ferry:*, harbor:info:*, region:welcome only.

- [ ] Write/run red focused world tests for real independent scene, collision/terrain agreement, safe spawns, return/clock/docks reachability, both tide states, player-on-sandbar rising tide, free ferry and bounded scene reentry.
- [ ] Extract only existing region geometry/activities, player spawn/floor, instance ground wrapper, movement constraints and area name hooks. Preserve the static welcome ground API and original default behavior/order, including recovery stride reset. Route all internal grounding through wrapper; null-guard optional water materials.
- [ ] Build distinct lighthouse shore, sandbar shortcut, ring waterway and permanent reachable docks/path with existing helpers/materials. No welcome geometry built then deleted, hidden welcome slabs, NPC/toy controllers or reward points. Use real collision surfaces matching map terrain.
- [ ] Local tide preview uses no global clock/save; high tide makes sandbar unavailable and safely relocates a player standing there; ferry always free to fixed safe docks, zero velocity. Recovery cannot trap player in water.
- [ ] Reuse approved avatar/appearance/settings/time/lighting and shared movement; override no-op NPC/activity/collection behavior. Return snapshots only primitive geometry/point data, no retained world nodes.
- [ ] Run new world test plus affected welcome layout/grounding/avatar-motion/boat-stage tests. Self-review and commit owned files; detailed task-2-report.md. No Main/Progress/UI/runner/docs edits.

### Task 3: Travel lifecycle and truthful regional UI

**Files:** Modify `game/main.gd`, `game/ui/collection_book_panel.gd`, `game/ui/island_map_panel.gd`, `tools/run_game_tests.py`; create `game/ui/harbor_map_panel.gd`, `game/tests/test_region_travel.gd` and `.tscn`, `game/tests/native_region_travel_review.gd` and `.tscn`; update only affected UI/entry test fixtures and PASS-contract unit checks as needed.

**Interfaces:** Consume Tasks1/2. Startup chooses saved world; explicit guarded travel saves before replacing world, applies current settings/look/phase/story and reconnects signals once. Harbor map consumes map_snapshot; collection setup gains optional region default welcome and preserves existing callers.

- [ ] Write/run failing integration tests for below/equal threshold, no consumption/rewards, qualified entry/return, both tides, repeated travel/old-world release, save failure preserving original world, saved-harbor startup, legacy/malformed fallback, profile reset, session/dialogue/capture travel rejection and unchanged welcome flow.
- [ ] Implement one small explicit welcome/harbor selector and guarded replacement: block reentry/input/old area events, validate known destination and threshold, save first, only then release old world/build destination at safe spawn. Rebind/apply once; initial area/HUD/audio must match region. No transition during game/dialogue/capture; no boat replay on harbor startup/harbor pause. Welcome return retains its replay feature.
- [ ] Guard exact optional CoastalPlay/discoveries call sites. Preserve current shutdown guards. Keep current-region state and visible world consistent on reset; minigame cancel/settings while in harbor recover the same world/audio without rewards.
- [ ] Region-scope HUD/pause /18,/12; add harbor-only real map with tide, dock/lighthouse/return markers; welcome map retains routes and shows harbor available with six-card admission. Other gates remain future. Collection defaults current region, can switch to welcome to inspect saved originals; harbor is an honest empty state. Harbor task shortcut directs to welcome, existing game/achievement views explicitly label their welcome scope. Do not add future game definitions.
- [ ] Register all3 new suites/exact PASS markers in official runner without broad error exceptions. Update intentional welcome-only fixtures narrowly. Run affected travel/UI/story/dialogue/settings/save/boat tests and focused Python runner contracts.
- [ ] Add native fixture real admission/travel/tide/ferry/free return, restart-from-harbor mode, settings/currentlook, map/collection, no reward changes; exact actual dimensions800x600/1280x720/1920x1080,1.25text/reduced. Controller executes native/isolated PCK/Windows and publishes evidence.
- [ ] Self-review, commit only owned files and detailed task-3-report.md. Do not push/mark ticket complete.
