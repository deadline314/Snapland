# Godot launch and verification entries

Open the checkout containing `project.godot`, then use **Run Project / F5**. Its configured entry is `res://game/main.tscn`. `C:/Github/Snapland` is currently the design checkout; the executable candidate lives in the `island-experience` worktree.

| Purpose | Engine entry |
| --- | --- |
| Play the game | Project default scene, or explicit `res://game/main.tscn` |
| Standalone test extending `SceneTree` / `MainLoop` | `--script res://game/tests/test_time_of_day.gd` |
| Test or review extending `Node`, `Control`, or `Node3D` | Its `.tscn`, such as `res://game/tests/test_album_photo_viewer.tscn` |
| Parse/import project sources | `--editor --import --quit` |

Every test/review sets `SNAPLAND_SAVE_PATH` to an absolute isolated profile before starting Godot. The registered CI runner validates each entry before creating the engine process and preserves its existing suite selection, engine-error checks and PASS markers. Invalid component scripts, review snapshots, missing files, ambiguous entries and unsafe path resolution fail before Godot is spawned. `--check-only` does not make a Node/Control script a standalone entry; use project import or the matching test scene.

The validator and bounded runner are in `tools/godot_entrypoints.py`. Timeout handling targets the process created by that invocation; on Windows it first closes that owned PID tree. It never enumerates or stops unrelated Godot processes. Existing arbitrary manual Godot invocations and editor commands do not pass through this Python guard.

Session-only commit snapshots use `.gd.txt`, remain outside the game content and are not engine launch targets. The session's erroneous Node-script invocation was identified and stopped; the caller of the user's separate `19-MAIN16-book.gd` alert was not established.

Verification: 13 focused Python tests; all 63 registered entries accepted by preflight without running the entire suite; real engine script, Node scene, default Main smoke launch and a controlled timeout checked in isolated profiles. Native default Main startup was recorded for 180 frames at 60 FPS and its rendered frame inspected. These checks do not establish animation quality or human playtest acceptance.
