# Minigame Shared Presentation Polish — Implementation Plan

**Goal:** Give all twelve first-park minigames a calm, consistent HUD, useful explanations of their existing scores, brief contextual feedback, and a pause-safe tutorial/practice flow without changing ordinary or devil completion rules.

**Architecture:** Keep game rules and result ownership in MiniGameSession; move shared visual controls and score-detail presentation into a focused MinigameHUD child. The session publishes current state and event-derived score data, while the HUD emits pause, help, practice, retry, and leave requests. Practice remains explicit in the session result so the main game can suppress rewards.

**Tech Stack:** Godot 4.7.2, GDScript, built-in SceneTree tests, headless gl_compatibility, isolated SNAPLAND_SAVE_PATH.

**Spec:** design/runtime/first-park-gameplay-quality.md; current gate source is game/data/welcome_games.json and current rule implementation is game/minigames/session.gd.

## Global Constraints

- Keep all twelve existing ordinary and devil award predicates unchanged in this presentation pass.
- Keep keyboard and mouse bindings behavior equivalent; do not alter assist thresholds or assisted award eligibility.
- The HUD shows one concise current objective, score, time, progress, and an on-demand help affordance; it does not keep the long controls paragraph, devil hint, or bottom prompt permanently visible.
- Context feedback stays brief and near the relevant game object; reduced-motion mode removes particles and movement but retains readable state changes.
- Pause stops elapsed time, game phase, physics, input-driven simulation, feedback expiry, and melody playback advancement; resume continues from the exact paused state with no time catch-up.
- Practice uses the same game rules and input response, but is marked practice=true in the result; the main game must not award either collection item for it.
- Score explanations report only point rules and events that the current implementation actually evaluates. Do not label unimplemented precision grades as current behavior.
- Scope edits to game/minigames/session.gd, new game/ui/minigame_hud.gd, minigame/balloon tests, this native UI review harness, and this implementation plan. Do not edit game/main.gd, tutorial files/assets, paper_ui, art, or collection predicates.
- Do not begin editing session.gd until the parent explicitly sends “session解锁”.

## Review Focus

- Escape, pause button, and help entry must not accidentally emit cancelled or advance a running game; cover with state/input tests.
- Large frame deltas while paused or on resume must not advance clocks, physics, or note sequence; cover with explicit pause/resume delta tests.
- Practice retry must preserve practice status and must report no award-eligible result; cover retry and finish result tests.
- Every mode's current score explanation must agree with its implemented point events, including derived move-count scores and non-point progress; table-driven tests assert exact summaries.
- Reduced-motion mode must still show objective, progress, score details, and success/miss feedback without animated-only state; inspect all three HUD states in native review.

---

## File and Interface Map

- Modify game/minigames/session.gd: authoritative pause/practice/help state, contextual HUD refresh, event score ledger and per-mode truthful score summaries, result metadata, and compatibility forwarding for existing finished, cancelled, note_played, and feedback signals.
- Create game/ui/minigame_hud.gd: programmatically constructed HUD, score-details panel, pause panel, help request, practice control, retry and leave actions. It owns no minigame rules or award logic.
- Modify game/tests/test_minigames.gd: state, score summary, interaction, help/pause/practice/result regression tests while retaining every current gate assertion.
- Modify game/tests/test_balloon.gd: confirm balloon learn-by-doing, pause, retry, and normal route timing compatibility.
- Create game/tests/native_ui_polish_review.gd/.tscn: native UI review captures the main menu at 1280×720 and 800×600, opens all twelve games from their real station interactions and visible start buttons, and records three distinct live game states to the image paths in tutorials.json. It also checks a live pause/help interaction and verifies elapsed time remains frozen; it does not force a win or claim first-time-player validation.

HUD/session interface:

- Signals: pause_requested, resume_requested, help_requested, practice_requested, retry_requested, leave_requested.
- HUD methods: set_state(state: Dictionary), set_score_details(details: Dictionary), set_paused(value: bool).
- Session methods: set_practice_mode(value: bool), request_help(), score_summary() -> Dictionary. set_practice_mode(true) from a running formal round means discard and reset that round before practice begins.
- set_state receives title, objective, score, time_left, progress_text, feedback_text, feedback_kind, assisted, practice, and reduced_motion.
- score_summary returns {total: int, label: String, rule: String, rows: Array[Dictionary]}; each row has a player-facing label and an amount/count backed by real state. The ledger aggregates by a fixed set of event categories and preserves the exact total; summaries are built when details open and when the round finishes.
- _finish retains existing result keys and adds practice, score_summary, and mistakes. Existing ordinary/devil result rules remain authoritative and unchanged.

## Implementation Tasks

### Task 1: Lock current rule and score-summary fixtures

**Files:** Test game/tests/test_minigames.gd; read-only references game/data/welcome_games.json and game/minigames/session.gd.

- [ ] Add a table-driven fixture with one session per mode and assert the current objective, ordinary text, devil text, total score, and progress descriptor. Assert all twelve modes remain present and preserve existing award boundaries.
- [ ] Add score-summary expectations based on current rules: balloon deliveries, kite rings, fountain hits, crowd safe passes, hats caught, ribbon hits, pipe move formula, balance checks, shadow hold completion, photos, bench swaps, and melody correct notes/phrase bonuses.
- [ ] Run the isolated Godot minigame test script and confirm the fixture passes against current implementation before adding UI behavior.

### Task 2: Build the shared HUD and its visual review harness

**Files:** Create game/ui/minigame_hud.gd and game/tests/native_ui_polish_review.gd/.tscn; modify game/tests/test_minigames.gd.

- [ ] Build MinigameHUD as a Control with one top row: title, one-sentence objective, progress indicator, prominent score, remaining time, and a ? help button. Put all control help inside the requestable help panel. Show assist/practice status in a small text badge.
- [ ] Add separate pause, score details, help-request, retry-confirmation, and leave-confirmation panels. Buttons emit the interface signals above. Escape opens pause; it does not immediately leave.
- [ ] Make the compact score detail panel display per-mode rows and actual score total; keep it hidden until requested. Keep temporary success/miss text readable for at least 1.2 seconds without translating the whole game scene.
- [ ] Add SceneTree tests for panel open/close, one signal per action, Escape behavior, and objective/progress/score/time state refresh.
- [ ] Use the native UI harness to capture main/menu, pause/help, and all tutorial gameplay states after real input. Root owns GPU execution and visual inspection.

### Task 3: Add a truthful score event ledger and current-rule explanations

**Files:** Modify game/minigames/session.gd and game/tests/test_minigames.gd.

- [ ] Add _record_score_event(key, label, amount, count=1) and replace every direct score increment/assignment with the same arithmetic plus an event entry. For flower_pipes and bench_swap, record derived score updates as score_adjustment and state move count separately so the UI cannot imply per-move points that do not exist.
- [ ] Implement score_summary() for all twelve modes. Each summary must add up to score; include zero-point but award-relevant counts only when clearly labeled as progress, not points.
- [ ] Add tests that drive at least one success and one miss through each scoring function and assert ledger totals, row labels, and final numeric score agree. Keep completion conditions and award results identical to the Task 1 baselines.

### Task 4: Integrate pause, help, practice, and HUD updates with the session

**Files:** Modify game/minigames/session.gd, game/ui/minigame_hud.gd, game/tests/test_minigames.gd, and game/tests/test_balloon.gd.

- [ ] Instantiate the HUD as a child in _ready() and connect each request signal. Refresh set_state after start/reset, every relevant progress/score/feedback event, pause/resume, and finish.
- [ ] Implement set_paused(value) so _process, _unhandled_input, melody note emission, and game physics return without state changes while paused. Preserve paused state across a large frame delta and resume without catching elapsed wall time up.
- [ ] Implement set_practice_mode(value) and make retry/reset preserve it. The pause menu's “重新開始練習” choice resets the current round before setting practice=true; the practice badge appears before its clock starts. Practice uses the same state/rules and timer semantics, but _finish adds practice=true and includes the same truthful score summary; no success/devil rule changes. Main integration must gate Progress.complete_game on not result.practice after this subtask is handed off.
- [ ] Implement request_help() to pause first and emit help_requested; do not fabricate a screenshot tutorial or edit tutorial assets in this scope. On return, resume only when the help panel signals resume.
- [ ] Route pause-menu retry/leave to existing reset/cancel behavior only after explicit menu selection. Keep backward compatibility for parent consumers of existing signals.
- [ ] Add regression tests for pause freezing elapsed/phase/balloon physics/note emission, resume with delta=10.0, help signal lifecycle, practice retry retention, and practice completion metadata. Update balloon tests to verify paused intro and paused active flight both remain untimed.

### Task 5: Verify the shared HUD across all twelve modes

**Files:** Modify game/tests/test_minigames.gd and game/tests/test_balloon.gd; create/verify game/tests/native_ui_polish_review.gd/.tscn.

- [ ] Run headless tests with isolated save and Godot 4.7.2's gl_compatibility renderer (without the unsupported dummy-driver combination):

~~~powershell
$env:SNAPLAND_SAVE_PATH = Join-Path $env:TEMP 'snapland-minigame-polish-review'
& 'C:/Tools/Godot/Godot_v4.7.2-stable_win64_console.exe' --headless --path . --rendering-method gl_compatibility --script res://game/tests/test_minigames.gd
& 'C:/Tools/Godot/Godot_v4.7.2-stable_win64_console.exe' --headless --path . --rendering-method gl_compatibility --script res://game/tests/test_balloon.gd
~~~

- [ ] Run native_ui_polish_review.tscn with the desktop renderer; root owns GPU review and must inspect the ART20/ART21 screenshots for clipping, overlap, actual input states, and HUD obstruction. These deterministic captures are presentation evidence, not gameplay usability claims.
- [ ] Compare each mode's ordinary/devil outcome from Task 1 fixtures before and after pause/practice code; practice results must carry practice=true, and ordinary/devil results outside practice must remain unchanged.
- [ ] Report the precise session-to-main integration contract (set_practice_mode(true) before start or immediately after start; final result practice boolean) to root; do not change game/main.gd in this scope.

## Scope Boundary and Known Rule Mismatches

This pass does not rebalance or replace minigame mechanics. It must surface current mechanics honestly. In particular, Fountain's catalog says three successful jumps while session.gd currently completes ordinary play at two; Bench Swap's catalog says friends sit together while the current completion check expects one exact permutation. Keep those current outcomes in regression fixtures, call both mismatches out for a later game-rule task, and do not silently change either predicate while presenting the HUD.

The native review is a presentation review, not a claim of successful gameplay usability testing. Root must play each game at normal and assisted settings, use the tutorial flow with a first-time player, and verify the screenshots/feedback placement before describing the set as publicly polished.
