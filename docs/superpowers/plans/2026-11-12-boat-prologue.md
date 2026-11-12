# Boat Prologue Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox syntax for tracking.

**Goal:** Deliver ST-6: a reversible boat prologue before the existing arrival dialogue, without changing rewards or returning players' experience.

**Architecture:** Reuse the existing world ferry and dialogue UI. One temporary Node3D owns only the preview actor, camera and physics/visibility restoration; StoryDirector supplies dialogue and Progress owns one transactional flag. Main coordinates lifecycle and replay.

**Tech Stack:** Godot 4.7.2, GDScript, existing Paper UI and AvatarRenderer; no new dependency.

**Spec:** `design/runtime/boat-prologue.md`

## Global Constraints

- Work only in `C:/Users/stanl/Github/Snapland/.review/full-game-worktree` on the assigned feature branch; do not change branches or push.
- Author email `stanley890314@gmail.com`; no assistant/model names or Co-Authored-By trailers in commits.
- Every Godot invocation uses an absolute isolated `SNAPLAND_SAVE_PATH`. Preserve player saves, save version 1, unknown save fields, rewards and existing arrival dialogue.
- Reuse approved complete character textures and the world's existing renderer/cache. No limb reconstruction, per-frame autozoom, new PNG editing or new dependency.
- Use Traditional Chinese UI and concise hover text. No claim of human play/listening from automated evidence.
- Implementers do not spawn subagents; they own only assigned files and do not revert other work. Controller owns ticket/status, docs and final integration publication.

## Review Focus

- A legacy file missing the new flag must not replay an unsolicited prologue; a new profile must still see it.
- Failed saving must not retain a falsely completed flag or damage other progress.
- Camera, physics, visibility and preview nodes must restore on skip, finish, external dialogue removal and scene exit.
- A stale/duplicate beat notification must not restart or duplicate an animation or callback.
- At small viewports/large text, the complete actor and forward/skip controls remain usable; reduced motion stays still.

### Task 1: Story data and durable completion flag

**Files:** Modify `game/core/progress.gd`, `game/story/story_director.gd`, `game/data/first_park_story.json`; create `game/tests/test_boat_prologue_state.gd`.

**Interfaces:** `Progress.prologue_seen: bool` defaults false in new/reset memory; loaded legacy saves without the key default true. `Progress.mark_prologue_seen() -> bool` is idempotent and rolls back on failed save. `StoryDirector.prologue_lines() -> Array` returns a deep copy of valid prologue dialogue or an empty array. Keep the existing future entry status until Task 3 integrates playback.

- [x] Write and run a failing focused test for default/reset false, legacy missing flag true, explicit false/true round trips, idempotence, failed save rollback, malformed optional field, and unchanged coins/photos/unknown fields.
- [x] Add exactly five prologue lines to first_park_story.json, in order: 阿浪/idle welcomes the late-wind ferry approaching dock; 主角/interact secures the camera strap; 主角/photograph looks through the viewfinder; 阿浪/wave invites the player to greet the island; 主角/idle is ready to step onto the boardwalk. Text is short, warm, consistent with existing cast and non-punishing; there is no reward.
- [x] Validate supplied prologue lines: allowed existing speaker, nonempty text, whitelisted pose idle/interact/photograph/wave. A missing optional field keeps legacy story validation working; invalid supplied data reports diagnostics and returns no prologue lines.
- [x] Extend the existing save payload/validation/load/reset paths without bumping version, without moving fields into an unrelated wrapper, and without saving twice. Warning/default for malformed optional flag; preserve all unrelated data.
- [x] Run the new state test and existing story/save checks affected by the edits. Record the red/green evidence, self-review, commit only owned files and write `task-1-report.md` with status, commits, tests and concerns.

### Task 2: Reversible ferry presentation

**Files:** Create `game/story/boat_prologue_stage.gd`, `game/tests/test_boat_prologue_stage.gd`; modify only the ferry portion of `game/world/park_world.gd` to add `FerryDeckStageAnchor`.

**Interfaces:** Stage extends Node3D. `configure(world: Node3D, appearance: Dictionary, equipped: Dictionary, reduced_motion: bool) -> bool`, `show_beat(index: int, action: String) -> void`, `finish() -> void`. Caller adds Stage as a world child before configure. Failed configuration changes nothing. `finish` is idempotent and `_exit_tree` restores state too.

- [x] Write/run failing tests for configuration, exact restoration, duplicate beats, missing world components, reduced motion and bounded temporary nodes.
- [x] Add one named Marker3D at the existing ferry's forward deck, initially `(5.5,1.04,22.65)`. Use the spec's camera/composition constraints; calibration after native rendering is allowed.
- [x] Reuse `world.avatar_renderer` and approved full AvatarRenderer textures, with the existing avatar's pixel_size. Preview feet coincide with the deck marker: compensate along the camera up vector using `AvatarRenderer.FEET_BASELINE` and the canonical image center. Preserve the real player's transform/facing; hide and restore its original visibility and disable/restore world physics.
- [x] Save/restore camera transform, size and projection. Frame the whole ferry/actor above the existing bottom dialogue plaque. No new world, source PNG, body deformation or camera sway.
- [x] Idle uses `idle_frame_for_time`; finite front actions use the existing animation library timing then return to idle. Update the texture only on frame changes. Reduced motion keeps a fixed approved pose. Clamp exceptional delta; reject unknown actions safely; repeat beat indices do not restart playback.
- [x] Run focused stage tests, self-review, commit owned files and write `task-2-report.md`. Do not touch Main, Progress, StoryDirector, registry or ticket.

### Task 3: First-run, replay and interruption integration

**Files:** Modify `game/main.gd`, `game/story/story_director.gd` entry metadata, `tools/run_game_tests.py`; create `game/tests/test_boat_prologue_integration.gd` and `.tscn`; update only affected existing story/UI fixtures; add native review fixtures as needed.

**Interfaces:** Consume Tasks 1/2. First-run only when both intro_seen and prologue_seen are false; returning players keep the original path. `show_beat` receives line index and pose from prologue_lines. Ordinary dialogue continues using existing code/UI/beep/reveal handling.

- [x] Write/run failing integration tests for finish and skip into original arrival, replay to original location, repeated replay, external dialogue removal, scene exit, failed saving and no reward changes.
- [x] Coordinate the Stage with existing `_start_dialogue`, `_render_dialogue`, `_finish_dialogue`, `_dialogue_panel_exiting` and quitting lifecycle. Guard against duplicate completion; interruption without actual finish/skip does not mark seen. Existing direct `_show_arrival` callers remain arrival-only.
- [x] Add a pause replay action only while not in a minigame. Boat dialogue uses `直接下船` with contextual hover; existing dialogue defaults remain unchanged. Reuse focus, keyboard advance/skip and scale behavior.
- [x] Change prologue entry to available with an honest description only after playback integration exists. Register all new state, stage and integration tests in the official runner and exact PASS marker contract. Existing tests specifically targeting arrival may explicitly set prologue_seen=true; do not globally bypass the new first-run path.
- [x] Run affected story/save/dialogue/pause tests. Capture real native first-run and replay at 800×600, 1280×720 and 1920×1080 including text scale 1.25/reduced motion; inspect shots and run isolated PCK. Record fixture controls accurately. Controller completes native/export evidence if not owned by implementer.
- [x] Self-review, commit owned files and write `task-3-report.md`; do not push or mark the ticket complete.
