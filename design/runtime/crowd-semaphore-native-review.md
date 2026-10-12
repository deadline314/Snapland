# Crowd Semaphore native review record

This record describes the parent-run native review of candidate `SG19-native-v5`; it is not a claim of an independent manual playthrough. The fixture drove the real Main station route for `game-004`, used native pointer and keyboard events, and captured post-draw viewport images. Its screenshots are in the candidate `.review/` directory and the three tutorial images are byte-for-byte copies of the opening, vertical-pointer, and formal-result captures.

## Captured player-facing states

- `crowd-semaphore-formal-opening.png`: actual station launch, empty crossing, both queues and signal cards visible.
- `crowd-semaphore-formal-vertical-pointer.png`: actual pointer click on the vertical card and the live feedback toast.
- `crowd-semaphore-formal-horizontal-key.png`: actual Q-key lane selection.
- `crowd-semaphore-formal-first-crossing.png`: a live group crossing in the formal run.
- `crowd-semaphore-formal-result-award.png`: actual result UI after six safe crossings; the recorded run shows 430 points and both ordinary and devil photo awards.
- `crowd-semaphore-practice-assisted-reduced-opening.png`, `crowd-semaphore-practice-real-input.png`, and `crowd-semaphore-private-assisted-reduced-practice-first-crossing.png`: actual assisted/reduced private-mode start and real-input progression.
- `crowd-semaphore-practice-result-no-award.png`: actual private result after six safe crossings.

## State and input checks

The fixture confirms the pointer signal is emitted once for the selected vertical lane, then confirms Q changes the live model to horizontal `walk`. The formal run includes an actual Pause button press; the pressed-handler latch records the paused model phase and elapsed time, which remain frozen across six process frames. Retry is confirmed through its real `ConfirmAction.pressed` handler, which observes exactly elapsed `0.0`, red phase, no desired lane, unpaused state, and the same practice flag.

Both formal and private runs finish all six groups from real input while the fixture chooses the most urgent live queue. It checks the finished result against the model's safe count and score. The formal route persists its normal photo and returns to the park; Main frees the completed session. The assisted/reduced private route leaves the full captured progress snapshot unchanged (photos, quests, achievements, visited state, settings, appearance, equipment, owned clothing, pending platform achievements, coins, and normal/devil counts), returns to the park, and is freed by Main.

The view is a real 3D orthographic harbor miniature in a bounded SubViewport, with six pooled guest tokens. Its headless bounds test measured the projected mesh union at `868.6875 × 348.404` pixels (origin `205.6563, 266.3116`) within the HUD-safe playfield. The Control GUI path emits the lane request consumed by Session; pointer input and Q/E selection share the same existing model state. The screenshots demonstrate the scene at the captured phases; automated geometry assertions and image capture do not replace an independent visual-quality review.

The parent reported successful native runs at both normal and quarter playback rates: 1,886 frames / 31.433 seconds and 7,355 frames / 122.583 seconds, with no runtime errors. These are review-fixture timings, not gameplay-performance benchmarks.
