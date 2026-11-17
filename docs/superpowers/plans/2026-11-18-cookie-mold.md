# Cookie Mold Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Deliver SG-42/game-026 as a distinct mold-release and tray-catching game with six actual shapes and existing collection lifecycle.

**Architecture:** Reuse the existing RefCounted model/driver and retained 3D Control view pattern. The model owns edge adhesion, crack stress, angular inertia and one flying rigid body; the driver owns input, the view owns bounded geometry, and existing Main/Progress own transactional awards.

**Tech Stack:** Godot 4.7.2, GDScript, existing Paper UI, validated launcher and private embedded QA export. No new dependencies.

**Spec:** [餅乾翻模](../../../design/runtime/cookie-mold-gameplay.md)

## Global Constraints

- Work on codex/cookie-mold-20261118, never main; root alone handles PM/Git/shared runner/validator/native evidence. Preserve other workers and unrelated import/UID files.
- Six fixed cookie slots, at most32 polygon edges, one active rigid body/tray; no unbounded history, fragments, physics nodes or per-frame geometry creation.
- Only real public operations and physical release/catch can produce scores and challenge proof. No injected phase, adhesion, caught or qualification in tests.
- 150seconds, delta capped0.25 and <=1/120substeps, finite input guards, detached snapshots. Double-layer whole thickness participates in resistance/stress/catch geometry.
- Standard and assisted can both earn devil; helper only holds tray under outlet. Idle/practice/cancel never grant normal cards.
- Planned ordinary18/devil12 and global180 remain. Candy released2/12, island playable26; game027 remains unbuilt.
- Every engine process uses tools.godot_entrypoints.run_validated_godot, exact4.7.2 and an absolute isolated SNAPLAND_SAVE_PATH. Coordinate slots; no real player saves.

## Review Focus

- Rapid angle crossing +/-pi preserves physical inertia and shortest rotation; no wrap teleport or fake inertial proof.
- Canceled mouse/touch/keyboard charge releases ownership without a knock; no duplicate touch-emulated mouse command.
- Moving tray after cookie has crossed below its plane cannot retroactively catch it; require whole-body bounds at crossing.
- Shape/reset/retry cannot retain cracked state, double-layer proof or growing geometry; retry keeps elapsed time and completed slots.
- Released26 must have a valid themed retake set and real tutorial PNGs; headless synthetic persistence fixtures alone cannot prove the shutter works.

## Task 1: Physical cookie model

**Files:** Create game/minigames/cookie_mold_model.gd and game/tests/test_cookie_mold.gd only.
**Produces:** Model APIs and snapshot fields exactly as frozen in the spec: reset, set_mold_target/release_mold, select_edge/select_edge_at, begin_tap/release_tap, set_tray_target, toggle_helper, retry_cookie, clear_input, step, snapshot.

- [x] Write failing operation tests for six distinct valid polygons/two configurations and idle/helper-only nocompletion; run exact SceneTree entry through validated launcher to capture RED.
- [x] Implement bounded angular/adhesion/stress/release/whole-body swept catch model using spec starting values; keep collision and score in one model.
- [x] Drive real gentle and inertial routes to six caught cookies in both variants and assist modes. Pin heavy repeated same-edge crack, wrong tray miss, free retry, actual double-layer low/high-inertia distinction, cancellation, nonfinite guards, detached snapshots and fixed capacities.
- [x] Record final calibration constants and replayable operation route (public APIs only), GREEN command/output and source hash; fresh spec+quality review before dependent acceptance.

## Task 2: Controls and retained hand/mold view

**Files:** Create game/minigames/cookie_mold_driver.gd, cookie_mold_view.gd, game/tests/test_cookie_mold_driver.gd, test_cookie_mold_view.gd, and optional explicitly named native_cookie_mold_workbench_review.gd/.tscn only.
**Consumes:** Task1 frozen API/snapshot; coordinates from spec.
**Produces:** Existing driver lifecycle reset/create_view/handle_input/clear_input/step/snapshot/present/score_summary and View command_requested/pointer_requested. Expose reusable design_point/work_point/mold_handle_point/edge_point/tray_point/button_rect helpers for real native input fixtures.

- [x] Read interface before coding; add RED keyboard/pointer/touch/charge cancellation and ownership tests. Keyboard A/D, arrows, Tab/ShiftTab, Space hold-release, R andX exactly match spec.
- [x] Implement minimal retained 3D extruded shape/mold/tray and recognizable articulated gloved hands; shared polygon supplies visible shape and model adhesion. Rebuild finite meshes only on actual shape/config change.
- [x] Retain physical font readability and nine on-screen actions at800x600/125%,1280x720 and1920x1080; brief visible guidance/hover. Preserve shared Session top HUD area.
- [x] Prove full keyboard and pointer/owned-touch routes, lifecycle clears without knock, real model score rows, finite nodes/resources after retry and view removal. Record GREEN and fresh scoped review.

## Task 3: Runtime/progression integration

**Files:** game/core/game_catalog.gd; game/data/candy_games.json/tutorials.json; game/minigames/session.gd; game/world/candy_world.gd; game/main.gd; game/ui/tutorial_catalog.gd/retake_panel.gd/collection_book_panel.gd; related runtime tests plus new test_cookie_mold_session.gd and test_cookie_mold_main.gd/.tscn. Ownership details in .review/cookie-mold-20261118/seams.md. Do not touch Task1/2, root runner/validator/designJSON, PM/Git or tutorial images.
**Consumes:** Task2 driver and Task1 public real-input route.

- [x] Pin missing026 RED before adding Catalog local2/modecookie_mold/ACH_GAME_026 and one Session driver route. Preserve25 literals that mean Candy globalstart, not delivered total.
- [x] Add a reachable second factory point without removing any old six interactions; dynamic map/collection/stamps expose2 games. Candy ticket opens two-column available tutorial choice; other region guides unchanged.
- [x] Append real PROP26 and tutorial26 data. Only root supplies three real Main1280 PNGs; do not substitute design placeholders or another game.
- [x] Update precise released-total/candy2 assertions and unbuilt rejection to027 without relaxing existing25 behavior, sugar400/500 outcomes or18/12 collection targets. Truthful participation copy and actual input in global participation regression.
- [x] Verify Session/Main actual six catches, timeouts, idle, practice/cancel, reward dedup, fixed IDs, original/thumbnail decode, real retake-set readiness/Next2/enabled shutter BEFORE synthetic persistence check, source provenance preservation and reload. Fresh integration review.

## Task 4: Validation and per-ticket delivery

**Files:** root owns tools/run_game_tests.py, tools/verify_design.py, tests/test_runtime_result_contract.py, tests/test_design_validation.py, design/02-minigames/catalog.json, game/tests/native_cookie_mold_main.gd/.tscn, tutorial images, docs and SG42 ticket/evidence.

- [x] Register five strict exact completion markers and companion rejection tests; CANDY_DELIVERED2 with both exact identities/coverage/drift and game027 first unbuilt.
- [x] Capture three REAL Main1280 lesson sources, then import and check all lessons/fields/physical sizes. Actual native input at800125%/reduced motion,1280ordinary/challenge/timeout,1920; actual arranged-set shutter pixels and cold saved restart.
- [x] Build exact final private QA snapshot only AFTER integration freeze; clean release-directory boot without path/scene overrides, actualresult+retake writers and cold readers. Compare all runtime resource hashes and executable SHA to final source.
- [x] Fresh whole-branch review, fix via original implementer/scoped re-review, appropriate affected checks, all design scopes, evidence and ticket completion.
- [x] Fetch/rebase as needed; explicit SG42 files only, user author/committer email, commit+push feature then main, inspect CI, remove only delivered owned branch/worktree. No assistant/model attribution in commit messages.

## Execution ledger

- Opening45c779a pushed immediately after origin/main+local highestSG41 check. User explicitly authorizes continuous autonomous implementation, per-ticket push/main integration and no repeated questions.
- Ruling: analytic bounded edge adhesion and rigid-body flight, not full softbody/fragments — preserves meaningful force/angle/catch interactions with reproducibility and fixed memory; cost is simplified material response documented for players through honest cues.
- Ruling: a single isolated feature branch in the shared workspace with disjoint worker ownership, no additional worktree — all prior changes committed and low disk space; cost is coordination, mitigated by no overlapping writes and root-only Git.
- Design preflight authored on most-capable architecture model; explicit publicAPI/physics/shape/collision/calibration routes frozen. Model author can calibrate coefficients while reporting real replay evidence, cannot change qualification/API/shape count without root ruling.
- Prior QA stage recursive cleanup was rejected by automatic policy and not retried; old artifacts retained. Reuse bounded stage resources for future package if needed, never use a player profile.

- Task1 complete/reviewed:1209public-operationchecks,8fullroutes,normal700/devil800 bothconfigs+assist. No coefficient changes beyond fixed-radius shapecoordinates andboundedstress; reviewfoundnoP1/P2. Exactrim/deadlinecombination coverage notedforwholebranchreview.
- Task2 fixround1/5: idlehandoccludedrealMaincookie/cue. Originalimplementer adds chargingcondition; projectedvisibility RED176/7 ->GREEN176/0, native98atall3sizes. ScopedreviewADDRESSED0open, driver34 unchanged. First preimplementationcontrolsREDnotcaptured; parser/nativeRED andlimitsdocumented, no retrospectivefakeclaim.
- Rootregistry/validator:fiveexactcookiecontracts1209/34/176/21/Main; noSugarcontractrelaxed.50Pythoncompletion/entry/shardtests and44designvalidationtests pass. game026catalogdeliveryalignment+bothCandyrowsnegativecoverage,game027unbuilt.
- CIrepairtickets deliveredseparately: MAIN29 5594015 declaresallfixturedata incopy+cleanup (25baseline/26fixturestrictpasses); MAIN30 d233d1f distinguishesstrictplayerbodyvsnormalSpritecamera-grounding (deterministicRED/GREEN164). Bothsparseworktrees/branchesremoved, localmain/originmainlatestd233d1f; currentSG42branchwillrebaseaftercodecommit. LatestmainCI44127544526pending, oldSG41CIhadthesetwofailures, notclaimedallpassed.

- Task3 FINALFREEZE: CookieMain exactPASS plusall26Retake/tutorialPanel/paged27lessons5fields3sizes125%/RegionTravel2-guide/retakeNativeFixtureGREEN. Newcookieordinarycopy57->47chars after10pxclip at800x450/125%; onlydatafieldchanged, noUI/goldenrelax.19production/testhashes+3PNGhashes recorded. FreshTask3source andfreshmostcapable wholebranch reviews PASS0openP1/P2; no engine rerunbyreviewers.
- Final realMainGPU routes: asset-visible1280actual800/sixreleases;800125%/reduced assisted800,1280ordinary700,1920devil800,participatedtimeout0, actualselecteddevilshutter/pixel-equaloriginal andordinary/retakecoldread allpass. Firstasset-first hadidlehandocclusion andwas supersededbyvisiblecase afterround1; preservehistoricalraw.
- NewprivateQA export uses task-owned D:/Snapland-QA/20261118-cookie-mold-2a75381f because C:isspace-limited; it copies only declaredtrackedruntime+newcookieassets, not the repository or blocked oldstage directories. ExistingblockedQAprojectdirectoriesremainuntouched. EmbeddedWindowsreleasewith3allowlistednativefixturefilespendingexactsource/hash/4-caseacceptance.

- Final embeddedQA acceptance complete:1188source/resourcehashesmatchfrozenworkspace,binarySHAverified;actual800writer/coldreader andactualselecteddevilshutter/coldreader all4exit0/noERROR/nomissing026. PublicSG42evidence14.94MB+sixPNGs,allfive designscopespassed. Per-ticketGit/mainintegrationnext; MAIN31separatelydiagnosesexistingNPCaudioexitresource retention, noSG42productionmutation.

- Git closure: feature2be4e18pushed, rebasedontoorigin/main d233d1f withfourpreviouslydeliveredpatch-equivalentMAIN29/30commits skipped; final04f3bac02dc5d9ed3e4d777d303367ed9ce548bd fast-forwarded/pushedtomain. Userauthor/committer+cleanmessageverified; ownedfeaturebranchremovedlocal/remote,noactiveownedworktree. LatestmainCI44133310374started, duplicatebranch44133215820cancelled. EOF-onlyblanklineformattingkeptbodyidentical; finalDexportrecompiledandall4casespassed,1188rawhashesmatch. MAIN31continuesonnewcodex/dialogue-release-20261118.
