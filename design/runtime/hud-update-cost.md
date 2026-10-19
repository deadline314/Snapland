# Live HUD theme updates

2026-10-20, base 8dbb00c. A real integration timeout led to a bounded early-input replay, which completes eight genuine misses. No score or result is injected. The model ends at 8.01 simulated seconds; wall time was 32.65 s before, 3.69 s after avoiding identical font-size overrides, and 2.86 s after also avoiding identical feedback-color overrides. These are same-host headless diagnostics, not native FPS, music timing or cross-platform benchmarks.

The HUD still receives current score/time/feedback and performs responsive measurement. Only unchanged style mutations are avoided. Theme changes are observable: a regression changes score/time twenty times and requires zero title theme notifications while displaying the final values. Existing resize, physical text scaling, keyboard/mouse and overlay assertions remain. Completion count moves from 69 to 71 solely for those two additional assertions.

## Sources actually read

- [Godot Control](https://docs.godotengine.org/en/stable/classes/class_control.html): theme override getters/setters and theme notifications; compare the current effective style before mutating.
- [Godot Control source, 4.7](https://github.com/godotengine/godot/blob/4.7-stable/scene/gui/control.cpp): distinguish a theme mutation from changing label content.
- [Flutter performance](https://docs.flutter.dev/perf/best-practices): repeated rebuilding and intrinsic layout work have real cost; preserve stable subtrees. This is a transferable principle, not a Godot API guarantee.
- [Qt Quick performance](https://doc.qt.io/qt-6/qtquick-performance.html): reduce unnecessary property changes and profile actual workloads.
- [web.dev layout cost](https://web.dev/articles/avoid-large-complex-layouts-and-layout-thrashing): avoid repeated invalidation/measurement work; browser scheduling does not establish Godot behavior.
- [Python monotonic clock](https://docs.python.org/3/library/time.html#time.monotonic): use elapsed monotonic wall time for the owned-process diagnostic.

Full original welcome integration completes 81 cases in 79.37 s, within its unchanged 90 s guard, with exit 0 and no engine ERROR. Related model/view tests pass 42/138. Native two-size captures are static HUD fixtures, not gameplay screenshots. The first 71-check result was rejected by the stale exact 69-check completion contract; preserve that finding and update the contract alongside the added assertions. No test selector, score threshold or time limit changes.

The first compact native fixture used physical window dimensions as logical canvas dimensions, applying stretch twice. That capture is rejected and retained. The corrected fixture uses the viewport logical rect: an 800×600 window renders an 800×450 aspect-preserved image. This was a capture harness correction, not a product layout change.
