extends Node

const NativeReviewBase = preload("res://game/tests/native_review.gd")
var failures: Array[String] = []

func _ready() -> void:
	if OS.get_environment("SNAPLAND_SAVE_PATH").is_empty():
		push_error("Set SNAPLAND_SAVE_PATH to an isolated profile before tutorial progress checks.")
		get_tree().quit(1)
		return
	call_deferred("_run")

func _run() -> void:
	var progress := get_tree().root.get_node_or_null("Progress")
	_check(progress != null, "Progress autoload exists")
	if progress == null:
		_finish()
		return
	progress.reset_progress()
	_check(not progress.has_seen_tutorial("game-001"), "new profile sees the first game tutorial")
	_check(not progress.mark_game_tutorial_seen("game-000"), "unknown game IDs cannot be marked learned")
	_check(not progress.mark_game_tutorial_seen("game-120"), "out-of-range game IDs cannot be marked learned")
	_check(progress.mark_game_tutorial_seen("game-001"), "valid game can be marked learned")
	_check(progress.mark_game_tutorial_seen("game-001"), "marking the same game learned is idempotent")
	_check(progress.tutorial_seen_games == ["game-001"], "seen state contains one canonical ID")
	_check(progress.save_progress(), "seen state saves")
	progress._reset_memory()
	progress.load_progress()
	_check(progress.has_seen_tutorial("game-001"), "seen state survives profile reload")
	_check(not progress.has_seen_tutorial("game-002"), "unseen game remains eligible for its first tutorial")
	var mixed: Dictionary = progress._validated_payload({"tutorial_seen_games": ["game-001", "unknown", 2, "game-012"]}, "fixture")
	_check(mixed.get("tutorial_seen_games", []) == ["game-001", "game-012"], "unknown or malformed IDs are discarded from valid arrays")
	var wrong_type: Dictionary = progress._validated_payload({"tutorial_seen_games": {"game-001": true}}, "fixture")
	_check(not wrong_type.has("tutorial_seen_games"), "wrong-type seen state falls back to empty defaults")
	var native_helper := NativeReviewBase.new()
	var prepared_main: Node = native_helper._instantiate_main()
	for number in range(1, 13):
		_check(progress.has_seen_tutorial("game-%03d" % number), "shared native review setup prepares returning-player game-%03d" % number)
	if prepared_main != null:
		prepared_main.free()
	native_helper.free()
	_check_save_failure_child_contract()
	_check(_write_failure_diagnostic("fixture.json.tmp","Windows")=="ERROR: Cannot write progress temporary file 'fixture.json.tmp': File not found", "measured Windows obstructed-parent diagnostic mapping")
	_check(_write_failure_diagnostic("fixture.json.tmp","Linux")=="ERROR: Cannot write progress temporary file 'fixture.json.tmp': Can't open file", "measured Linux obstructed-parent diagnostic mapping")
	_check(_write_failure_diagnostic("fixture.json.tmp","Unknown").is_empty(), "unmeasured platforms do not gain a catchall diagnostic")
	_finish()

func _check_save_failure_child_contract() -> void:
	var output: Array = []
	var project_path := ProjectSettings.globalize_path("res://")
	var arguments := PackedStringArray([
		"--headless", "--audio-driver", "Dummy", "--path", project_path,
		"res://game/tests/test_tutorial_seen_failure_child.tscn",
	])
	var exit_code := OS.execute(OS.get_executable_path(), arguments, output, true, false)
	var child_log := str(output[0]) if not output.is_empty() else ""
	var error_lines: Array[String] = []
	for line in child_log.split("\n"):
		if line.begins_with("ERROR:") or line.begins_with("SCRIPT ERROR:"):
			error_lines.append(line.strip_edges())
	_check(exit_code == 0, "failed-save Main child exits successfully")
	_check(child_log.contains("PASS: tutorial and attempt failed-save cleanup"), "failed-save Main child emits its result marker")
	var blocked := (OS.get_environment("SNAPLAND_SAVE_PATH")+".blocked-directory").path_join("progress.json.tmp")
	var expected := _write_failure_diagnostic(blocked,OS.get_name())
	_check(error_lines == [expected,expected], "child captures exactly tutorial and attempt unwritable-profile diagnostics")
	_check(not child_log.contains("SCRIPT ERROR:"), "failed-save child has no script or parse errors")

func _write_failure_diagnostic(path: String, platform: String) -> String:
	var native_errors := {"Windows":ERR_FILE_NOT_FOUND,"Linux":ERR_FILE_CANT_OPEN}
	if not native_errors.has(platform): return ""
	return "ERROR: Cannot write progress temporary file '%s': %s" % [path,error_string(native_errors[platform])]

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _finish() -> void:
	for failure in failures:
		push_error("FAIL: " + failure)
	if failures.is_empty():
		print("PASS: tutorial seen progress and failed-save start checks")
		get_tree().quit(0)
	else:
		get_tree().quit(1)
