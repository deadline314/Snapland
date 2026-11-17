# Dialogue Test Audio Release Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Close MAIN-31 by releasing native playback ownership before test exit, without changing production audio or weakening diagnostics.

**Architecture:** Two test-only static functions capture weak playback references before shutdown and await bounded actual release after owner free. Five existing callers retain their own lifecycle assertions and barriers.

**Tech Stack:** Godot4.7.2, existing AudioDirector, GDScript/SceneTree, validated launchers on Windows and existing WSL Ubuntu. No dependency installation.

**Spec:** [測試音訊釋放](../../../design/runtime/test-audio-playback-release.md)

## Global Constraints

- Activecodex/dialogue-release-20261118; root-onlyGit/PM/runner/contracts/docs. No production Main/AudioDirector, game reward, UI or game logic changes.
- capture before shutdown; owner queue_free and existing framebarrier before wait.2000ms actualWeakRef condition, no strong references across await, no unconditional150ms wait/errorallowlist.
- PreserveMAIN28latecallbackassertionbetween shutdown andfree, alloldcompletionmarkers, previous26gamebehavior.
- Eachengine exact4.7.2 via tools.godot_entrypoints.run_validated_godot +absoluteisolatedSNAPLAND_SAVE_PATH. WSL usesPOSIXpaths andhelperinsideWSLPython, notWindowsvalidatoragainstPOSIXproject.
- Privatebuilds onnewownedDtaskdirs; do notmutateacceptedSG42package orretrydeletionofpolicy-blockedCstages.

## Review Focus

- WeakRef poll itself must not hold a playback across await and prevent release.
- Strongly held fault-injection must fail boundedly; no success marker on failure, clean injected references before exit.
- No caller can move its capture after shutdown or lose queue_free/barrier/latecallbackguards.
- NativeCookie's inherited cleanup gains a source dependency; explicit QA allowlist must include helper.
- Timing-sensitive normal/verbose passes cannot erase original Linux RED; reportactualidentitiesvsCIcount distinction.

## Task1: Shared test release and five callers

**Ownership:** originaldiagnosticimplementer only game/tests/audio_playback_release.gd, test_audio_playback_release.gd, test_npc_dialogue_hold.gd, test_photo_retake_main.gd, test_sugar_bridge_main.gd, test_cookie_mold_main.gd, native_sugar_bridge_main.gd. No runner/PM/Git/otherfiles.

- [x] Write actual-playback selfchecks for empty/capture/deadowner/strongretentiondeadline/recovery; capturemeaningfulRED before helper exists.
- [x] Implement exact capture(audio:Node)->Array[WeakRef] and wait_for_release(tree:SceneTree,playbacks:Array[WeakRef])->bool contract; useexistinghouseWeakRef.any lambda withno strongobject acrossawait.
- [x] Replaceonlyduplicatedcapture/pollblocks atfivecallers; NPC removes150mswait aftersamefunctionalchecks. Preservecaller-specificorder/guards andpropagatefalseintooldfailurepath.
- [x] Runselftest+fiveaffectedcallerpaths, NPC exactLinuxoriginal-vs-fix andheldfailure. Recordcommands/output/sourcehashes; sourcefreezeandfreshconcurrencyspec/qualityreview.

## Task2: Harness, native dependency and delivery

**Ownership:** root tools/run_game_tests.py, tests/test_runtime_result_contract.py, targetednativeQAallowlists, docs/PM/evidence/Git. AgentdiagnosticsremainprivateuntilTask1approved.

- [x] Register SceneTree test withlabel `audio playback release tests`, exactmarker `PASS: audio playback release weak refs, owner-free wait and bounded timeout`; strictsuffix/error/stderr/nonzero rejection companion.
- [x] ActualnativeCookie/sharedcleanup smoke plusprivateNPC QA entry includehelperdependency explicitly; verifyisolatedexitandfrozenresourcehashes.
- [x] Freshwholebranchreview, affectedchecks/designlinks, causalRED/GREEN/deadlineevidence; completeMAIN31onlyafteracceptance.
- [x] Commit/pushwithuseremail,fetch/rebase/mainmerge,checkCI,removeonlydeliveredownedfeaturebranch/worktree.

## Execution ledger

- MAIN31openingbc0ad63pushedimmediately, rebasedopeningnowonorigin/main04f3bac aspartSG42delivery; noimplementationonmain. Newbranchcodex/dialogue-release-20261118.
- Diagnosticread-onlyoriginalWindowsnormal/verboseoftenpass. ExactLinuxoriginaltimerendverbose reproduced3resourcesandnativeplaybacks; A/Bsame150mswithonlypostfreeconditionaddedpassed. Deliberateheldplaybackdeadline2004msfailsandcleansinjectedref. Sharedsourceuntouchedduringdiagnosis.
- Ruling: twofunctiontestutilityratherthanfifthcopiedblock — fourcorrectcallersalreadyduplicate the same mechanism andNPCneedsit; netlesslifecyclecode andfuturegamefixturescanreuseprovencondition. No general audio framework/options or mass migration of unrelatedfixtures.
- Ruling: NPCquitting guard followsotherMaincleanup topreventnewcallbacks; actualretentionproofcomesfrompostfreeWeakRef condition, notthisguard.
- SG42fullydelivered04f3bac/main, ownbranchcleaned;1188resourceQAhashesand4casespassafterEOF-onlyformatre-export. LatestSG42mainCI44133310374all6success; existingNPCflakyticketkeptseparate.

- Final: seven frozen implementation sources reviewed with zero open P1/P2; 51 Python checks, five Windows entries, Linux causal/held/mutation checks, native Cookie retake and independent embedded NPC QA passed. MAIN31 evidence records exact scope; delivery Git/CI status is tracked by root.
