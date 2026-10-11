# Runtime implementation research (2026-10-11)

- Official Godot 4.7 docs state that `user://` remains writable on exported/runtime targets, while project resources can be read-only. Snapland progress therefore belongs in `user://`, never beside project data. Source: https://docs.godotengine.org/en/4.7/tutorials/scripting/filesystem.html
- Godot 4.7 documents headless mode for running without a GPU/display and the project `--path` argument; the CI runner uses these for a real native process and fails on a missing binary. Source: https://docs.godotengine.org/en/4.6/tutorials/editor/command_line_tutorial.html
- Godot 4.7.2 is an official stable release, dated 2026-08-18. The workflow pins to that version. Source: https://godotengine.org/download/archive/4.7.2-stable/
- Godot's autoload guidance treats a singleton as a persistent global node and cautions against using autoloads as general-purpose node containers. Progress and platform synchronization are narrow state services. Source: https://docs.godotengine.org/en/4.7/tutorials/best_practices/godot_interfaces.html

Implementation consequence: tests set `SNAPLAND_SAVE_PATH` to a temporary absolute file before the process starts. Production keeps `user://progress.json`; CI never touches a developer's regular user data. Corrupt current data reports its concrete file path, tries a validated backup, and otherwise uses defaults.
