# Sugar Bridge Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Deliver SG-41 as the twenty-fifth real game with material-based bridge/sling play and existing collection lifecycle.

**Architecture:** Follow existing RefCounted model and driver plus retained 3D Control view. Model owns bounded deterministic material and ball physics; driver owns input and existing session contract; Main and Catalog expose only delivered content. No new dependencies.

**Tech Stack:** Godot 4.7.2, GDScript, existing Paper UI/runtime test and native export helpers.

**Spec:** [拉糖橋](../../../design/runtime/sugar-bridge-gameplay.md)

## Constraints and review focus

- Read AGENTS.md and spec first; root alone handles Git, tickets and shared runtime registry.
- MAIN-26 must deliver first; do not include SG-41 production files in its commit.
- Preserve other agents' work and unrelated untracked import/UID files.
- Bounded two bands, four endpoints, three delivery balls and one reusable trial bean. No per-frame nodes or growing histories.
- Every success/qualification follows actual input, geometry and collision. Helper does not solve or inject flags.
- All Godot invocations use validated launcher and isolated absolute save paths. Coordinate engine slots with root.
- Focus boundary inputs, detached snapshots, no held inputs across teardown, honest rewards and no pre-existing catalog regression.

## Task 1: Material and transport model

**Ownership:** game/minigames/sugar_bridge_model.gd and game/tests/test_sugar_bridge.gd only.

- [x] Pin testable public interfaces and actual long/short solution routes before implementation.
- [x] Implement bounded stretch/thickness/capacity/sag, real rolling/falling and reclaim, actual sling collision and same-band qualification.
- [x] Cover both retry configurations, assist/helper equivalence, invalid inputs, timeout and detached snapshots.
- [x] Run focused test through validated launcher, record red/green command/output, submit model for fresh review.

## Task 2: Driver and retained 3D workbench

**Ownership:** game/minigames/sugar_bridge_driver.gd, sugar_bridge_view.gd and corresponding driver/view tests.

- [x] Read final Task 1 interface; map keyboard, mouse and touch to common actions with ownership and motion handling.
- [x] Reuse established 3D viewport, Paper UI and tutorial patterns; retain finite meshes and short instruction/hover copy.
- [x] Expose existing session lifecycle/score_summary contract; release inputs on pause/focus/exit without unintended shot.
- [x] Verify actual pointer/keyboard routes, bounded nodes, readable states and reduced motion; fresh review.

## Task 3: Runtime, progression and tutorial integration

**Ownership:** Catalog/data, game session routing, CandyWorld/Main/menu entry points, tutorial integration and corresponding session/progress/Main tests; excludes Task 1/2 files.

- [x] Trace every game-024 integration seam, then add candy game-025 with accurate one-game counts and fixed identities.
- [x] Connect tutorial/practice/pause/retry/results, photos/originals/retake, achievement and reward dedup through existing pathways.
- [x] Update factory world/map/info from empty to one playable; leave eleven upcoming games honest.
- [x] Verify actual completion/timeout/practice/cancel/restart; preserve previous catalog assertions and routes.

## Task 4: Delivery

**Ownership:** root test registry/contracts, native fixture, docs, evidence, SG-41 ticket and Git operations.

- [x] Review all tasks and full branch; fix real findings through original implementer and scoped review.
- [x] Run affected tests, native three-size actual-input routes, saved restart and private standalone output.
- [x] Save evidence, validate design/links, complete ticket only when acceptance met, commit/push using user email.
- [x] Fetch/rebase/integrate main, inspect CI and remove only delivered owned branch.

## Execution ledger

- Ticket opening: f333324, pushed. User authorizes autonomous decisions and delivery without repeated questions.
- Ruling: analytic material/trajectory model provides reproducible meaningful material choices; full soft-body simulation adds calibration and instability without needed player value.
- Builder preflight: froze four endpoint IDs, absolute motion, bounds/layouts, single drag ownership, release versus cancellation, capped substeps, reusable bean and load recovery. Same-band qualification binds generation and a real post-hit delivered traversal; attaching a marked segment alone is insufficient. Task 3 explicitly removes MAIN-26 candy empty-state overrides and audits album photo recognition.
- Task 1 initial: 48 real-operation checks pass; fresh review found AI holding only altered flags while every free endpoint stayed stationary. Ruling: free unpinned/ungrabbed/unheld endpoints settle under bounded gravity to the existing catch, making the requested assistance meaningful without a new solver.
- Task 1: fix round 1/5 (1 addressed, 0 open). Four fixed vertical velocities; original 48 plus six holding/gravity/cancellation/reset/catch checks. RED 54 checks/4 failures, GREEN 54 checks/0 failures, exit 0. Scoped source re-review accepted the fix with no new issue; driver/view/native remain separate.
- Task 1: fix round 2/5 (1 addressed, 0 open). Simultaneous loads previously occupied the same physical point through the entire trip. The fixed pool now feeds three visibly spaced queued balls onto the actual bridge; only supported rolling balls add load. RED 60 checks/7 failures; GREEN 63 checks/0 failures including whole-route spacing in both layouts. Scoped re-review accepted without new breakage.
- Task 2: fix round 1/5 (2 addressed, 0 open). Clear driver drag ownership when AI takes a keyboard grab; measure retained Label3D physical font heights against actual projection and text preference. Driver 47, view 51 clean checks, fresh scoped review accepted. Native preflight then fixed a clipped legend and coincident endpoint/support text; standalone GPU 800/1280 each 36 clean checks, view 52. Root viewed 800 captures: full controls/copy and spaced balls are legible. A new coincident-endpoint pointer-selection finding is in round 2; full Main/native/1920 remain separate.

- Task 2: fix round 2/5 addressed shared-center endpoint selection; exact ties favor the selected endpoint, ordinary nearest hits unchanged. Driver51/view55 clean; standalone GPU800 fix2 reports40checks0. Root native Main initially suspended automatic processing without refreshing accepted GUI input, leaving a stale view; diagnostic proved model selected1 while view rejected the old endpoint location. Fixture now invokes normal Session process with zero delta after input/capture, preserving physics time and actual input. Historical failures retained; final realMain1280 yields500/same-band devil.
- Task 3: fresh integration review found one P2 Candy album location incorrectly inherited Welcome. Original implementer added Candy lookup and both-card/participation copy assertions; scoped re-review ADDRESSED, zero open. Planned ordinary18/devil12 targets retained; actual released games1/12 separately stated. No global180/progress migration change.
- Runtime registry and design alignment: exact five-suite Sugar completion markers, strict suffix/error rejection (22 Python contract tests); game025 delivered-state and strict Candy local1 coverage/drift plus game026 unbuilt (43 design tests, games scope PASS).
- Tutorial assets: three real1280x720 Main GPU captures from 1280x720-asset-sync (short bridge, actual pull, natural500 result), root visually inspected, copied unchanged and imported. No synthetic result or model flag injection. Admission alone uses six explicitly synthetic welcome cards. Earlier unimported800 lesson capture is superseded by final native reruns.

- Task 3 fix round 2/5: actual native shutter revealed24-row themed props table failed closed for newly delivered025. Original implementer extended one existing asset row; RED two game025-only ready/shutter failures, GREEN all25 ready/3props/Next2/shutter plus026 fail-closed. NewMain now asserts real set readiness before its explicitly synthetic image-persistence fixture. Root actual GPU `1280x720-retake-props` passed arranged-image pixel equality, truthful selected devil provenance, no ordinary/practice/cancel awards and one40coin receipt.
- Task 3 fix round 3/5: root found all_definitions -> each identity caused repeated25-row deep-copy traversals per thumbnail. Replaced with three known zone prefix checks, preserving validation/cache/legacy behavior. Existing AlbumViewer, HarborCollection22 and shared MainPhotoThumbnails passed. Fresh full-branch scoped review ADDRESSED both findings, zero open P1/P2.
- Newlesson copy shortened after pagedViewport caught252px ordinary text in242px field at800x450/125%; all26lessons/semanticfields/three sizes now pass. No global tutorial layout or prior lesson changed.
- Final native routes also pass:800x600125%/reduced-motion assisted500,1280x720 sequential longbridge400, participated load/fall timeout0,1920x1080 same-band500. Three lesson PNGs are real Main sources, not stand-ins. All captures/physics progression are scripted, not human play.

- Final standalone acceptance: all1178runtime/allowlistedfixture source hashes match current workspace, binarySHAverified;500writer/coldrestart andactualselecteddevilretake/coldrestart pass with noERROR/missingimagewarnings. SG-41 evidence zip22.5MB+sixPNGs prepared;20uniqueaffectedGodotsuites,65Python tests andfive designscopes passed. Git integration/CI next.

- Git closure: a7491430f0b226bf0512a460e374d14d0a5321be committed/pushed, latestorigin/main fast-forwarded with zero divergence; localmain/originmain sameSHA, userauthor+committer verified. Ownedfeaturebranch removedlocal/remote. mainfullCIstarted44121228790; its duplicatedownbranchrun44121151940cancelled. CIstillrunning atSG42opening; notclaimedpassed.
