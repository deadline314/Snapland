# Regional Map Layout Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver MAIN-27 so every delivered regional game's map invitation is reachable at small viewport sizes without horizontal overflow.

**Architecture:** Keep the terrain chart and whole-entry HFlow. Replace twelve fixed-footer actions with one game-entrance action opening an existing Paper modal/GridContainer with all delivered games visible. Keep back/free return fixed; no new scrolling framework or data source.

**Tech Stack:** Godot 4.7.2, existing Paper modal and ScrollContainer; validated tests and native captures.

**Spec:** [糖果工廠往返與材料探索](../../../design/runtime/candy-travel.md), final paragraph records MAIN-27 layout decision.

## Constraints

- Begin mutation only after MAIN-26 has committed/pushed and root creates the next branch.
- Keep existing button names/callback identities and all twelve harbor games; no hidden or deleted actions.
- Respect the user's existing no-scroll UI requirement (pixel-ui-redesign.md, 2026-10-14): map and complete game-entry grid are separate pages, with fixed return controls and readable type.
- Separate profiles and validated launcher for all engine runs. Root alone handles Git/ticket/evidence.

## Task 1: Bounded regional map actions

**Ownership:** game/main.gd::_show_map plus one regional game-entry modal method; game/tests/test_region_travel.gd; twelve existing harbor game Main tests and native_rowing_main.gd to follow the new menu flow. Preserve all others' work; SG-41's new Main test owner must be notified of the same selector change.

Fix-round expansion: game/ui/island_map_panel.gd and game/tests/test_travel_book_ui.gd for the same real small-window map clipping goal. Actual 800 content scale exposes a pre-existing welcome chart/detail minimum-width overflow; compact layout must preserve all targets/details/back without scrolling and adapt on live resize.

- [x] Add regression proving the map and footer remain inside 800×600/1.25; the separate entry grid exposes all twelve actions without scrolling.
- [x] Use one footer action for the entry modal, preserving existing per-game labels, names and callbacks in its grid; no new world or progress side effects.
- [x] Check every action opens the correct game info; retain candy and welcome behavior and no reward changes.
- [x] Update the twelve existing game Main tests and native rowing capture to open RegionGamesButton before their unchanged per-game assertions; retain stable per-game button IDs and all original outcome assertions.
- [x] Run covering travel/UI checks and submit fresh scoped review with exact red/green logs.

## Task 2: Delivery

**Ownership:** root dedicated native map fixture, docs/PM/evidence and Git.

- [x] Inspect three native sizes including large text, complete map/grid, all game info callbacks and back.
- [ ] Save real screenshots and logs, complete MAIN-27, commit/push independently and integrate latest main.
- [ ] Inspect CI and remove only the delivered owned branch; immediately continue SG-41 integration.

## Execution ledger

- Ticket opening 1479d7b pushed before implementation.
- Diagnosis: actual harbor flow/footer width 3713 in both original smart-wrap and corrected whole-entry mode. The twelve fixed-footer actions cause pre-existing overflow; location wrap fix did not introduce it.
- Ruling before implementation: initial draft assumed an existing scrollable body, but source inspection shows the modal is fixed and the user's 2026-10-14 requirement prefers fully expanded menus. Use a map-to-entry-grid flow instead; a scroll redesign would conflict with that established preference.
- Builder preflight: twelve existing harbor Main fixtures and native_rowing_main use direct per-game map selectors; ownership expanded to preserve their assertions through the new entry page. Two expanding columns and existing Paper button/adaptation helpers fit the required fixed layout. Root native fixture already records the real 800×600 failure; add text-fit/no-scroll checks to its eventual green route.
- Task 1 initial: 17 affected suites passed with unchanged markers, including twelve game Main routes and final region-travel reset-from-entry guard. Root native 800 confirms complete harbor terrain and all twelve grid callbacks fit; two findings enter fix round 1: return label says park while going to map, and unchanged welcome map clips details/back. Ruling: include the existing welcome physical-width issue in this same map responsiveness requirement; retain the native failure and strengthen actual content-scale tests rather than weakening the welcome check.
- Task 1: fix round 1/5 (2 addressed, 0 open). Two-column/full-grid map return is labeled accurately; welcome uses retained responsive layout, real content scale, all 21 target/hub/detail checks and bounded live resize. Four covering suites pass. Whole-branch most-capable review found no actionable defect; actual three-size fixed2 GPU captures pass.
- Task 1 minor resolved: stale welcome legend said all nine destinations were unbuilt, despite open harbor/candy. One caption becomes the truthful regional-gate label, preserving all targets and route captions; focused travel/book check passes. Fresh final three-size GPU cases each produce five captures, zero errors/leaks/failures and truthful synthetic-setup metadata.
- Native harness ownership: an otherwise successful 1280 run exposed the same asynchronous audio release at exit; new fixture observes weak playback references under a deadline, following proven MAIN-28 evidence. All old failed/raw runs remain available; no error was ignored. Clean editor import also passed.

- Final native acceptance: 800×600/1.25, 1280×720 and1920×1080 each pass five actual Main captures and all twelve invitation callbacks. Fresh scoped review accepted truthful legend copy. Evidence preserves original failures, final PNGs, source snapshot/hashes and all covering logs. Design/link validation passed all five scopes.

- main CI confirmed successful after delivery: https://github.com/deadline314/Snapland/actions/runs/44116097783.
