# NPC Approach Actions Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task.

**Goal:** Deliver the existing ART-17 event-direction defect fix without claiming the whole art ticket complete.

**Spec:** [NPC approach actions](../../../design/runtime/npc-approach-actions.md).

## Global Constraints

- Base main3ca0b9c, branch codex/npc-approach-actions-20261118. Root owns Git/PM/docs/evidence/private packaging. Workers are not alone; preserve unrelated edits and all preexisting untracked imports/UIDs.
- Existing ticket ART-17 already covers this requirement. No new art, dependency, direction alias, generalized fallback or production audio change. Select front at the world interaction event boundary, preserve exact-direction library validation and actual missing-source recovery.
- Keep original dialogue-hold assertions, pause/reduced-motion behavior, lifecycle ordering and strict result markers. No test claims of human gameplay/listening/whole-art acceptance.
- Godot4.7.2 executable C:/Tools/Godot/Godot_v4.7.2-stable_win64_console.exe, launch ONLY tools.godot_entrypoints.run_validated_godot; absolute isolated SNAPLAND_SAVE_PATH, new task-owned D:/Snapland-QA staging, no broad untracked copy. SceneTree scripts via --script; Node fixtures via real game/tests .tscn.
- Never retry policy-blocked deletion of existing C QA projects or mutate accepted SG42/MAIN31 frozen packages. No worker subagents, Git/PM edits or external messages.

## Task 1: Correct world selection and actual interaction regression

**Ownership:** game/world/park_world.gd and game/tests/test_npc_dialogue_hold.gd only; private diagnostic scripts/logs under .review/npc-approach-20261118 and new owned D stage. Root docs/runner/PM/Git not owned.

- [ ] Inspect all callers of the touched world interaction selection and existing source contracts before editing. Capture baseline local dialogue suite.
- [ ] Add focused coverage to the existing Main dialogue fixture: all three roles (ticket/guide/greet, imp/quest-001/interact, announcer/quest-002/interact), eight distinct geometric player-relative approach vectors. Use real world.nearest/world.interact and Main dialogue flow; do not write pending request, activity record, sequence, success, or nearest result to manufacture passing behavior. Allow real physics proximity and document any stage-state setup. Assert correct complete front action, hold/position preservation, action advance/end and safe cancel; preserve every old assertion. Keep runtime bounded, reuse existing routines rather than duplicate a framework.
- [ ] Before production edit, run meaningful RED showing side/back interactions open dialogue yet omit expected action. Save source snapshot, command, save path and raw logs.
- [ ] Minimal production fix selects existing front at world event boundary and removes unused position quantization only for this event. Leave shared exact-direction/fail-closed library untouched. If inspecting callers reveals a different requirement, report before changing scope.
- [ ] GREEN original plus new fixture; relevant NPC world/action/library/missing-source/departure regressions; explicitly prove unsupported direct directional request still fails and complete standing restores, including damaged front source via existing test mechanism when feasible. Avoid adding unrelated production branches.
- [ ] Write report with final hashes, actual RED/GREEN, commands, test counts and limitations. Freeze sources for fresh task review; no commit by worker.

## Task 2: Native existing-source evidence and delivery

**Ownership:** fresh worker only new game/tests/native_npc_approach_review.gd and .tscn plus private logs; root packaging/PM/Git/docs. Depends on reviewed Task1.

- [ ] Minimal scripted Main fixture reuses current actor/library/capture conventions, actual E input/nonfront proximity for all three roles; captures real intermediate authored actions then complete idle, checking held root position, correct texture/direction and finite sequence. Normal and true quarter-speed timeline; reduced-motion/reentry option only if needed by existing harness conventions. No NPC-root movement, manual action/sequence/result injection or duplicate production implementation.
- [ ] Output caller-save-folder receipt/screenshots with explicit scripted camera/player placement and no human acceptance claim. Use shared audio release capture/shutdown/free/barrier/wait for clean exit; independent source allowlist includes helper.
- [ ] Root runs/reviews normal/quarter/reduced/reentry captures, independent embedded Windows QA and exact source hashes. Preserve failures honestly. Fresh task review then most-capable whole-branch review.
- [ ] Root appends bounded ART17 Commit entry, keeps whole ticket in progress and unchecked art criteria; evidence zip/representative screenshots, affected checks and design links. Commit/push, fetch/rebase/latest main integration, CI, own delivered branch cleanup.

## Rulings

- Fixed front is the smallest current authored event policy; generic available-direction selection is unnecessary while all three actions have only front approved sources. Shared direction lookup stays strict, so future missing assets remain visible.
- ART17 exists and is in progress: this is a partial delivery of its interaction transition requirement, not a new ticket or full artistic signoff.
