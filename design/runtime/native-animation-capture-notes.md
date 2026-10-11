# Native animation capture timing

The ART-17 idle capture at 60 FPS ended at the 12,000-process-iteration cap without an animation completion marker. Godot reported 619 drawn frames, while the decoded AVI contained 12,000 frames (200 seconds). The first and last inspected frames still showed the traveller idle sequence. This run is incomplete capture evidence and does not establish animation naturalness or full acceptance.

## Confirmed engine behavior

The installed engine is Godot 4.7.2, build `ed1daf0bf`.

- [Godot main.cpp, lines 4707–4721](https://github.com/godotengine/godot/blob/4.7.2-stable/main/main.cpp#L4707): automatic drawing depends on whether a window can draw or has additional outputs. An occluded/minimized native window can suppress that drawing while logic continues.
- [Godot main.cpp, lines 4770–4777](https://github.com/godotengine/godot/blob/4.7.2-stable/main/main.cpp#L4770): MovieWriter appends a frame every process iteration, and `--quit-after` counts process iterations.
- [MovieWriter, lines 169–224 and 242–254](https://github.com/godotengine/godot/blob/4.7.2-stable/servers/movie_writer/movie_writer.cpp#L169): image output reads the current viewport texture each iteration, while the printed summary counts automatic drawn frames. Those counts can differ. Repeated encoded frames are therefore possible without FFmpeg duplicate/drop warnings.
- [RenderingServer force_draw documentation](https://docs.godotengine.org/en/stable/classes/class_renderingserver.html#class-renderingserver-method-force-draw): the main thread can explicitly redraw the viewports. `frame_post_draw` is a rendering signal, not a MovieWriter output clock.

## Harness correction and local evidence

Movie clips now advance once per process iteration. Movie mode explicitly calls `force_draw(false, 0.0)` before the iteration's output, including when window presentation is unavailable. Zero extra frame-step avoids adding a second shader-time step when automatic drawing also occurs. Interactive capture uses process delta; MovieWriter capture uses integer output-frame counts at the actual fixed movie FPS.

Godot consumes `--fixed-fps` before exposing `OS.get_cmdline_args()`. Actual movie FPS is recovered from the fixed process delta, corrected for `Engine.time_scale`, rather than assuming 60 or relying on the project default. The isolated report records the delta, time scale, output FPS and source.

Headless diagnostics use the dummy renderer, not GPU acceptance:

- 120 process iterations produced zero automatic post-draw signals; explicitly forcing each draw produced 120 post-draw signals.
- The old harness failed to complete its first synthetic clip after 1,501 process iterations.
- The corrected harness completed four actors with eight source frames at 8 FPS: each normal clip used 60 output iterations and each quarter-speed clip used 240, totaling 1,200 at 60 FPS. All clip process counts matched their output counts.
- The same schedule at 30 FPS used 30 and 120 output iterations per actor (600 total). Both FPS runs verified the source-frame index on every output iteration, completed all eight clips and wrote isolated terminal reports without errors, warnings or leak messages.
- A ten-iteration frame cap wrote `interrupted`, `terminal=true`, `successful=false`. The real manifest check retained 50 missing requirements and zero frame issues; role/action filters left that missing list intact. This was a headless coverage check, not rendered acceptance.

The report is beside the isolated `SNAPLAND_SAVE_PATH`, under `.review/ART-17-animation-review.json`. Its run ID, current clip, completed clips and terminal marker distinguish the current run from stale output. Each completed clip records start/end process frame, source FPS, source frame count, output frames and expected duration. Interrupted runs are terminal failures. `available-only` still carries missing coverage and does not claim full acceptance; role/action filters do not waive coverage requirements. Harness-owned caches and references are released on exit.

## Required GPU review

Run the live scene with isolated save storage and MovieWriter, then check the current run's completion marker and report. Decode the output and compare each clip's pixel changes and normal/quarter-speed duration against its recorded frame range. Check that ticket, imp and announcer follow traveller. The report counts explicit draws independently because Godot's own movie summary may still count only automatic draws.

For the current `idle` filter at 60 FPS, traveller/ticket/announcer each have eight source frames at 3 FPS (160 normal and 640 quarter-speed output frames); imp has seven (140 and 560). The expected eight clips total 3,100 output frames, about 51.67 seconds plus startup/teardown. Use this authored duration to compare decoded clips; do not speed up the faulty 200-second AVI and label it normal speed.

Full coverage remains a separate strict check. The currently missing authored directions/actions are not supplied by a successful available-only recording. Human inspection must assess naturalness; headless diagnostics, coverage checks and movie encoding success do not establish it.
