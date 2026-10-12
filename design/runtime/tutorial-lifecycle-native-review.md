# MAIN-10 native tutorial lifecycle review

This fixture is based on clean repository `HEAD 0b337eaf54b169d62cb4650692d89569b2831237` extracted with `git archive`. It runs the actual `game/main.tscn`, actual `Progress` autoload, actual tutorial panel, and actual minigame sessions. Pointer and keyboard events enter through Godot's normal window input queue. The only placement shortcut moves the park player to each station before sending the real interact key.

Shared inherited minigame review fixtures call `native_review.gd::_instantiate_main()` with its default returning-player setup, which seeds the twelve tutorial-seen IDs in the isolated review profile so existing gameplay/input reviews continue to start directly. This tutorial lifecycle fixture explicitly calls `_instantiate_main(false)` and checks all twelve IDs are unseen before starting.

## Run

Use a visible GPU-backed desktop session. From the fixture root in PowerShell:

```powershell
$env:SNAPLAND_SAVE_PATH = Join-Path $env:TEMP 'snapland-main10-lifecycle-review/progress.json'
& 'C:\Tools\Godot\Godot_v4.7.2-stable_win64_console.exe' --path . res://game/tests/native_tutorial_lifecycle_review.tscn
```

The fixture rejects headless rendering and a missing isolated save path. It checks monotonic `Time.get_ticks_msec()` deadlines each process frame: six minutes globally and 60 seconds per game. These wall-clock deadlines remain finite under fixed-FPS/movie capture; the per-game deadline covers the complete first-entry, formal, private-practice, and reentry flow. Native screenshots are captured after `RenderingServer.frame_post_draw` into `.review/main10-lifecycle-evidence/` in this candidate.

## Coverage

For each of the twelve stations, the fixture uses E to open the game's real information screen and clicks Start. An unseen game must open its three-step screenshot tutorial; the fixture captures each step, alternates real mouse and keyboard Right navigation, verifies keyboard Left/Right round trips, then alternates between Begin and Skip to start the selected game and checks that the seen ID persists. It clicks the session HUD Help button, verifies the running session's duration and model clock remain fixed for 90 frames, captures the real help panel, checks a selected persistent snapshot, closes back to the paused HUD, and verifies only an explicit Resume advances clocks. It opens Help again through the actual pause menu, closes it, and leaves through the pause menu's confirmation controls. Reentering and pressing Start must launch directly without opening the tutorial. The returning formal session then enters real private practice from its pause menu, opens and reopens the tutorial, captures the actual private Help page once per game, checks both clocks remain frozen, leaves through confirmation, verifies the same selected progression snapshot, and starts directly again without repeating first-entry teaching. No result, score, collection, or unlock is injected.

If saving the learned ID fails, the session still launches once and the HUD shows a brief save warning. The ID remains unseen; the next time Start is pressed, the lesson is offered again.

The focused headless regression scene is `game/tests/test_tutorial_seen_progress.tscn`. Its final failure-path case deliberately blocks a write inside the isolated test-save directory, so Godot logs one expected `Cannot write progress temporary file` error before the test prints PASS and exits 0. It checks the actual Main tutorial start launches one selected session and retains the unseen state. The integration regression also solves BenchSwap tables 1–3 using shortest paths computed from each actual model snapshot and visible rules, then verifies natural result and ordinary/devil records; this remains coupled to SG-26's three-table puzzle rules.

The parent regression scene captures the child's isolated intentional I/O failure output and accepts only the single expected `Cannot write progress temporary file` engine error, zero script errors, child PASS marker, and exit 0. The normal game-test runner has a strict engine-error check, so this expected negative-path diagnostic does not escape the child process or get filtered from runner output.

Expected successful output is `PASS: native tutorial lifecycle game-001` through `game-012`, exit status 0, plus 72 PNG captures (three first-entry lesson steps, one formal HUD help image, one formal replay image, and one private-practice Help image per game). Progress lines identify the active game and phase. The monotonic wall-clock watchdog is six minutes overall and 60 seconds per game. A mismatch or missing UI target reports `FAIL`, and the watchdog reports the active phase before exiting.

## Evidence status

The refreshed v3 candidate is based on clean HEAD `0b337eaf54b169d62cb4650692d89569b2831237` with the SG-27 Melody initialization fix checkpointed at `7719b26`. The v3 native lifecycle run exited 0 with no `ERROR:`, `SCRIPT ERROR:`, or `FAIL:` lines, all twelve per-game PASS markers, 72 post-draw PNGs, and 4,150 frames at 60 FPS (69.1667 seconds). The focused tutorial-seen test and Main integration test also passed.

The fixture interacts with the real first-entry tutorial, Begin/Skip, session HUD help, resume, pause-menu replay, leave confirmation, private practice Help, and reentry. It moves the park player directly to each station before using the real interaction input. It launches sessions but does not complete all twelve games or validate result/score/collection awards. Its unchanged-state assertion compares only `photos`, `achievements`, `quests`, `appearance`, `equipped`, `owned_clothes`, `coins`, `platform_pending_achievements`, and `tutorial_seen_games`; it is not a full profile snapshot and excludes settings and other unlisted fields. Root viewed all six v3 contact sheets, full-resolution game-005 step 2, game-010 step 3, and game-012 private Help step 1. Root also played the encoded 69.1667-second movie through, inspected 21.74 seconds and the expected final gray shutdown frame, and accepted this limited lifecycle-presentation evidence with no blocking flow issue. This is not acceptance of twelve complete games or overall visual polish. The first-entry lesson pages still show older in-game HUD screenshots; refresh those teaching screenshots against the current HUD before final acceptance.


The v3 movie is saved as `pm/Snapland-main/images/MAIN-10-lifecycle-v3-native.mp4` (SHA-256 `e9a0714851e53f263357508d6c7ecaac69600d4d55248ac667ff9dd55e3386e2`; 1280×720 at 60 FPS, 4,150 frames). Individual image copies and six contact-sheet hashes are recorded in `MAIN-10-v3-native-evidence-manifest.md`. The lifecycle run does not complete all twelve games or validate their results. The no-change snapshot checks only photos, achievements, quests, appearance, equipped items, owned clothes, coins, platform pending achievements, and tutorial-seen IDs; settings, visited state, and other unlisted save fields were not compared. The fixture moves the player directly to each station as its sole world-position shortcut, then uses real UI input.
