# Retake Lifecycle Implementation Plan and Record

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development for the scoped fix and review. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver MAIN-28 with actual audio-playback ownership drained before the retake fixture exits.

**Architecture:** Keep the production audio owner unchanged. The real retake fixture observes existing native playbacks weakly, frees the scene, then checks actual release under a monotonic deadline. Existing completion/error contracts remain strict.

**Tech Stack:** Godot 4.7.2, WeakRef, existing validated Python launcher and runtime checker; no dependencies.

**Spec:** [補拍回歸退出生命週期](../../../design/runtime/retake-test-lifecycle.md)

## Task 1: Isolate and fix ownership

**Ownership:** game/tests/test_photo_retake_main.gd only; root owns ticket/design/evidence/Git.

- [x] Preserve original full-suite failure and establish origin/main baseline attribution.
- [x] Obtain the actual five resource/ten object identities without startup verbosity perturbation.
- [x] Prove the owner-release boundary through same-project/flags/profile A/B/A/B, preserving original nonverbose execution.
- [x] Replace fixed delay with weak-reference release observation after owner deletion, explicit two-second failure bound and unchanged assertions/marker.
- [x] Run normal and detailed modes with independent profiles and re-evaluate original/fixed logs through unchanged result_error.
- [x] Fresh high-capability review checks transient strong references, deadline/failure child, source hashes and causal proof.

## Task 2: Delivery

- [x] Fresh current-workspace retake integration check passes with no error/leak lines.
- [x] Attach actual raw proof, complete ticket, commit/push independently of concurrent MAIN-27 UI edits.
- [x] Fetch/rebase as needed, integrate latest main and inspect CI.

## Execution ledger

- MAIN-28 opened/pushed f3408ec after MAIN-26 investigation reproduced the baseline issue. Design investigation boundary was recorded before the targeted implementation; this plan records the resulting focused task and evidence.
- Script/factory/watchdog/notice hypotheses were not established and no such workaround shipped.
- Actual audio identities: plaza_ambience.wav; game.ogg and harbor.ogg with their Ogg packet sequences and native playbacks. Quiet-startup detailed exit log reproduces exact batch.
- Original nonverbose focused A/B/A/B: two no-drain runs fail with matching resource/object ownership; two bounded-drain runs pass, observed drains 65/21 ms. Detailed variants also pass 90–104 ms. No fixed wait assumed release.
- Four full retake runs pass in 32.34/32.72/32.34/32.52 s across normal/detailed and distinct profiles; strict checker rejects original and accepts all four fixed results.
- Fresh review: no actionable findings; weak references do not keep native playbacks alive across await, and deadline records failure/nonzero exit. Fresh current-workspace check passed in 32.35 s. Hardware audio/whole-game play are outside this pure fixture correction.
- Delivery: 08b872a5103241e524ee60065e32c619b894f21d pushed and fast-forwarded into local/origin main. Concurrent MAIN-27 tracked edits were hash-verified unchanged across integration. The active region-map branch is retained for its unfinished ticket; no worktree was created. Main CI 44113523193 in progress, duplicate owned branch run cancelled.

- main CI confirmed successful after delivery: https://github.com/deadline314/Snapland/actions/runs/44113523193.
