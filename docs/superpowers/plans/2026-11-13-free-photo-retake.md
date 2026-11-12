# Free Photo Retake Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every delivered game's original ordinary/devil cards remain obtainable through participation and a free, explicit three-step photo set after one real attempt.

**Architecture:** Extend existing Progress atomic reward/save root and Session natural-result policy. One bounded retake Control owns observe/adjust/shutter, while Main owns launch eligibility and persistence; existing Paper, catalog, tutorial images and album remain authoritative. No new game models or dependencies.

**Tech Stack:** Godot 4.7.2 / GDScript, existing Python validation and four required runtime CI shards.

**Spec:** design/runtime/free-photo-retake.md

## Global Constraints

- Only actually delivered GameCatalog canonical IDs; no game-014 or planning-only unlocks. Default welcome twelve remains compatible; harbor game-013 is local first card.
- Normal natural finish grants ordinary eligibility independent of success. Practice/cancel do not automatically grant. Never fabricate success, score, story events or devil challenge proof.
- Actual launched practice counts as an attempt even if immediately cancelled; invitation/tutorial alone do not. Atomic save failure must not pretend eligibility persisted.
- Original card IDs/quotas, acquisition_method=retake, one global game receipt and 40 coins at most; old ordinary OR devil without receipt gets no retroactive money. Selected devil retake never grants missing ordinary.
- A retake only grants the missing selected card with validated actual images. Existing other card metadata/PNG bytes remain unchanged, and later genuine devil success can record technique without rewriting retake provenance.
- Three no-timer reversible steps: clearly labelled demonstration, visibly adjustable themed set, actual set photograph. No equipment, fee, skill or AI gate; keyboard sequential choices suffice.
- Reuse Paper/accessibility/PNG size limits. Absolute isolated SNAPLAND_SAVE_PATH for every test; no real user profiles. New suites keep the standard 90-second limit; existing exceptions (avatar renderer 240 seconds), error scanning and all old tests are retained.
- One implementation worker at a time; reviewers read-only. Author and committer stanley890314@gmail.com, no assistant/model/coauthor text; no worker push, branch switches, unrelated changes or subagents.

## Review Focus

1. Old devil-only save without a receipt: no retroactive coins or silent ordinary card. Task1 pins this.
2. Invalid/duplicate/forward attempt IDs and repeated failed save: bounded canonical history, rollback and safe reload. Task1 pins this.
3. Cancel/reopen during delayed shutter or duplicate presses: no stale award, duplicate capture, growing textures or abandoned files. Task2+3 pin this.
4. Writable directory with failed PNG replacement, oversized input or existing valid photo: old bytes survive; only this capture's new files are cleaned. Task3 pins this.
5. Album harbor selection from a locked welcome profile: practice cannot bypass six-card gate; saved-current-harbor recovery and free return still work. Task3 pins this.

---

### Task 1: Attempt history, honest natural results and atomic selected-card awards

**Files:** Modify game/core/progress.gd, game/minigames/session.gd; create game/tests/test_photo_retake_progress.gd and game/tests/test_participation_results.gd. Existing affected progress/save guard fixtures may be amended only for concrete changed contract/dependencies.

**Interfaces:**
- Consume GameCatalog.identity(id), existing validated thumbnail/original helpers and save_progress() -> bool.
- Produce Progress.has_attempted_game(game_id: String) -> bool, mark_game_attempted(game_id: String) -> bool, complete_retake(game_id: String, devil: bool, saved_frames: Array, saved_original_frames: Array) -> bool.
- Persist attempted_games as validated deduplicated canonical IDs, maximum delivered count; reset clears, old valid game cards infer historical attempts, unknown future metadata stays preserved.
- Session natural _finish results always contain ordinary_eligible; legacy = not practice, driver retains its own natural eligibility AND not practice. Cancel remains separate.
- Existing complete_game signature/boolean and attach APIs stay compatible. Share the existing atomic reward transaction by a narrow private extraction, rather than a parallel copy. Retake metadata contains acquisition_method="retake" and challenge_earned=false. Genuine devil completion records challenge_earned=true; retain first acquisition provenance and retake photo paths (attachment must not replace an existing retake card's photos). Existing gameplay cards preserve replay behavior.

- [x] Write focused failing tests: all thirteen natural false results remain success=false but ordinary eligible, practice/cancel excluded; bad/alias/unbuilt attempt IDs rejected; one attempt save/reload/reset; failed attempt save rolls back; canonical old-card inference.
- [x] Add award tests: missing ordinary/devil selected independently, no other-card mutation, valid decoded 320x180 thumbnails and bounded originals required, no blank grants; one40coin receipt across both paths/replays; old ordinary OR devil without receipt no money; invalid target and no attempt fail; actual blocked save restores all photos/coins/receipts/achievements/platform queue/signals; real later devil proof updates without falsely winning from retake.
- [x] Run red with pinned engine and private profiles, implement minimal shared changes, run green plus core/wardrobe/photos/original/harbor reward/save guard and Session affected regressions. No weakening assertions or limits.
- [x] Self-review callers, apply-save known-fields/validation/payload/reset, exact image ownership and emitted signals. Commit only owned scope; report exact APIs/results.

### Task 2: Reversible themed photo set

**Files:** Create game/ui/retake_panel.gd and game/tests/test_retake_panel.gd. Reuse game/ui/paper_ui.gd, tutorial_catalog.gd and original authored assets without edits unless concrete API gap is reported first.

**Interfaces:**
- Produce Control setup(definition: Dictionary, devil: bool, lesson: Dictionary) -> void, signal capture_requested(image: Image), signal close_requested(), set_capture_result(saved: bool, message: String) -> void.
- Parent creates/configures before add_child; target immutable for panel lifetime. Step0 observe,1 adjust,2 shutter. Public UI buttons advance/back and shutter; step index is readable for tests only, never a production external bypass.
- Three bounded cyclic keyboard/pointer choices: framing left/center/right, decoration one of three theme-appropriate whole props, near/normal/wide composition. Each choice visibly changes actual set; preserve on Back. Reuse real lesson PNG as explicitly labelled demonstration/backdrop and whole authored sprites/props, with clear "補拍布景／非挑戰成績" distinction. No re-simulated physics or copied demonstration claimed as this player's gameplay.
- One reusable 1280x720 SubViewport photo set, no per-frame allocation; displayed preview is exactly shutter source. Actual shutter waits render, reads its image, disables double shutter until set_capture_result. Missing/invalid/oversized source has readable fallback and refuses empty capture. Headless tests validate state without pretending rendered capture.

- [x] Add failing state/invalid setup tests covering canonical delivered target, lesson mismatch, ordered steps/back/preserved choices, keyboard/button focus, no early/duplicate shutter, failure enables retry, success blocks duplicate award, close/destroy invalidates deferred capture.
- [x] Implement minimal Paper layout with concise hints and named accessible controls; adaptive 800x600/1.25 text, reduced-motion with no mandatory motion. Frame composition never includes controls or demonstration explanation as fake gameplay.
- [x] Verify headless tests and native 800x600/1280x720 actual preview changes, shutter pixels/dimensions/zero empty capture, keyboard sequential navigation, missing image fallback and eight open/close cycles stable node/resource counts. Record actual PNGs as set photographs, not earned-game photos.
- [x] Self-review single viewport and capture lifetime, input ownership and source validation; commit owned files and report.

### Task 3: Album/kiosk entry, real launch attempts and safe photo persistence

**Files:** Modify game/main.gd, game/ui/collection_book_panel.gd, game/ui/achievement_stamp_book.gd (collection achievement copy only), game/minigames/session.gd and game/ui/minigame_hud.gd (qualification/result copy and a minimal visible unsaved-launch notice only; no goal/scoring/rule changes), game/data/tutorials.json and concise rules/help copy where existing wording contradicts participation; public qualification_text/score_rule_text string literals in hat_rescue_model.gd, ribbon_rhythm_model.gd and melody_memory_model.gd may change at source (no goals/constants/conditions/scoring changes). Create game/tests/test_photo_retake_main.gd; extend existing shared photo writer tests where appropriate. Concrete required-API fixtures test_album_photo_viewer.gd and test_pixel_ui_collections.gd add has_attempted_game without changing collected-original viewer behavior; exact old stamp/tutorial/HUD copy assertions (including game/tests/test_minigame_hud.gd formal qualification/practice copy) may update with owned wording. No unrelated UI redesign.

**Interfaces:**
- Consume Task1 Progress APIs/natural eligibility and Task2 RetakePanel signals/setup/set_capture_result.
- Collection emits retake_requested(game_id: String, devil: bool), practice_requested(game_id: String, devil: bool); preserve setup's five positional args, region selection and collected-card full original viewer. Missing game cards show region, fixed kiosk and selected ID, plus practice-first/free-retake action based on has_attempted_game. Non-game postcards/story/time entries keep existing behavior.
- Main connects those signals and exposes same retake choices from existing kiosk rules. Retain the selected ordinary/devil target across practice start and immediate cancel or practice result return, so the same missing-card retake entrance resumes without silently switching card kind. Main validates actual zone access using existing six-card harbor threshold (or legitimate current saved harbor), then valid Session start, then mark_game_attempted. If actual-attempt saving fails on the new practice-for-retake shortcut, dispose that Session, restore world and show clear retry without enabling retake. Preserve the existing ordinary/generic-practice fallback: keep one fully initialized playable Session, show a visible unsaved-qualification notice, keep history ungranted, and allow the next launch/entrance to retry; invitations/tutorials alone never save attempt.
- Main owns selected-target/panel generation guard, receives actual shutter Image, writes unique selected-card namespace, derives thumbnail and original with existing limits, then complete_retake. Only saved success claims collection. Failure retains safe image/award retry or removes only this capture's newly owned unreferenced files; stale/closed panel cannot grant.
- Shared _save_bounded_photo_image retains signature: encode same-directory temporary PNG, validate existing bounds/size, then DirAccess.rename_absolute over destination. On failure clean only temporary, never existing destination. Exact pinned Windows/Linux rename behavior already proved in .review/rename-probe-*.log. Keep time postcard and gameplay original callers working; no generic image framework.

- [x] Capture baseline affected Main/album/original/time postcard regressions. Write failing tests for true launch vs invite, practice-immediate-cancel unlock, retake-shortcut atomic attempt failure/cleanup versus preserved generic/tutorial-failure playable Session and visible unsaved notice in both legacy and driver modes, locked album harbor shortcut, saved harbor recovery, selected ordinary/devil from both regions (including initially unattempted devil→practice→cancel→same devil retake with ordinary still missing), no success/story false positive and no duplicate40coins.
- [x] Add actual PNG failure tests: existing target hash survives bad dimension/size/encode or replacement failure, new capture namespace never collides with other card, partial writes and save failures preserve original card metadata/bytes, stale capture and double shutter award once. Use real temporary filesystem failures and exact expected diagnostics, no broad error swallowing.
- [x] Connect minimal entrances/copy. Existing acquired cards show gameplay/補拍 provenance and actual challenge state; retake collection achievements use collection language, not false formal-round completion. Actual challenge/highscore claims stay truthful.
- [x] Run green and affected Main story, progress/photo viewer/thumbnail/original, regional collection, time postcards, tutorials and input regressions. Native kiosk/album path checks are labelled programmatic; fixture source data may not forge attempted/earned cards.
- [x] Self-review every touched caller, cancel/async lifetime, failure cleanup ownership and UI scale; commit and report.

### Task 4: Register complete regression and genuine native/release fixture

**Files:** Modify tools/run_game_tests.py and tests/test_runtime_result_contract.py (extend existing house contracts; tests/test_runtime_shards.py only for a concrete coverage gap) only to register/assert all new suites; create game/tests/native_photo_retake.gd/.tscn and test-only adjacent helper only if necessary; create game/tests/test_retake_native_fixture.gd for package dependency preflight. Parent owns public ticket/docs/CI/export/archive/main/cleanup. Controller acceptance scope adds game/ui/collection_book_panel.gd game-card action tooltip only: concise practice/free-retake/original action, while full region/kiosk/ID/provenance remains in visible details; concrete existing album tooltip assertion may update if needed, no layout redesign. Controller actual800x600/1.25 visual acceptance additionally authorizes the smallest correction to existing responsive album page capacity/card fitting, with true800x600/enlarged geometry cases in game/tests/test_pixel_ui_collections.gd: all visible card content and rectangles must remain above the fixed pager, retaining compact800x450 and1280/1920 behavior. Responsive page remapping/rebuild preserves the genuinely focused photo by stable ID and keeps its page visible; resizing a focused latter-half photo then Enter must still invoke that same actual target.

**Interfaces:**
- All new tests participate in existing build_checks and stable four-shard exact-once registry, original115 retained. Existing timeout90/error scanning/isolated profiles/required engine unchanged.
- Native Node fixture uses adjacent external helper via its own resource_path; exported resources exclude game/tests. No res://tests fallback, production automation flags, scene-tree score/end/attempt/card mutation or screenshot-forged gameplay.
- Absolute RETAKE_CAPTURE_DIR, RETAKE_REVIEW_MODE=welcome|harbor|read and optional RETAKE_LARGE_TEXT=1. Real attempt via Main-launched practice then actual cancel, actual album and kiosk controls, all three public UI steps/visible choices, true shutter; at least one route uses normal GUI-routed Tab/Enter/pointer events rather than only emitting pressed signals. Preserve an unedited actual attempt-only snapshot before any target award for standalone EXE verification. Harbor prerequisites may fill only missing OLD welcome cards, without overwriting genuinely acquired target metadata/photos; new target cards/attempts must be real. Reader loads actual writer, original decoding and provenance, and leaves its JSON bytes unchanged; independent private profiles.

- [x] Add registry/fixture preflight tests, verify all original suites remain and new exact RUN/PASS markers documented. Red→green focused Python and runner imports/new suites.
- [x] Native welcome and harbor ordinary/devil selected routes, missing ordinary selected devil independence, 800x600+1.25/reduced,1280x720,1920x1080; real failed-normal participation from one existing welcome game remains false; no forged finish. Capture actual set before/after adjustment, collected card/provenance/originals, first-devil-only stamp with ordinary absent, restart, return/cancel, save-failure UI and repeat no payout. Record actual OS window, logical viewport and screenshot render dimensions, so800x600 is not silently800x450letterboxing. Do not repeat unchanged exhaustive SG28 physics.
- [x] Native helper dependency audit for independent pack; provide parent precise build/bootstrap/profiles commands. Commit owned files with full report and honest limits.
- [x] Parent completes whole-branch review, full exact-HEAD Python/source/four-shard CI, separate clean packed proof and actual standalone Windows smoke/UI as supported by release template, public evidence and ticket closure. Rebase latest origin/main, commit/push/merge/push and remove only delivered worktree/branches. Stop after the handoff per the user’s latest instruction; do not open another ticket in this session.
