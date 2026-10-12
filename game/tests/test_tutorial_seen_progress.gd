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
	_check(not progress.mark_game_tutorial_seen("game-013"), "out-of-range game IDs cannot be marked learned")
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
	_finish()

func _check_save_failure_child_contract() -> void:
	var output: Array = []
	var project_path := ProjectSettings.globalize_path("res://")
	var arguments := PackedStringArray([
		"--headless", "--audio-driver", "Dummy", "--path", project_path,
		"res://game/tests/test_tutorial_seen_failure_child.tscn",
	])
	var exit_code := OS.execute(OS.get_executable_path(), arguments, output, true, false)
	var child_log := str(output)
	var error_lines: Array[String] = []
	for line in child_log.split("\n"):
		if line.contains("ERROR:"):
			error_lines.append(line)
	_check(exit_code == 0, "failed-save Main child exits successfully")
	_check(child_log.contains("PASS: tutorial seen failed-save Main start"), "failed-save Main child emits its result marker")
	_check(error_lines.size() == 1 and error_lines[0].contains("Cannot write progress temporary file"), "child captures only the deliberate unwritable-profile error")
	_check(not child_log.contains("SCRIPT ERROR:"), "failed-save child has no script or parse errors")

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
