extends Node

const MAIN_SCENE = preload("res://game/main.tscn")
const SESSION_SCRIPT = preload("res://game/minigames/session.gd")
var failures: Array[String] = []

func _ready() -> void:
	if OS.get_environment("SNAPLAND_SAVE_PATH").is_empty():
		push_error("Set SNAPLAND_SAVE_PATH to an isolated profile before failure-path test.")
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
	progress.prologue_seen = true # Preserve the original-arrival setup before tutorial failure.
	var original_path := OS.get_environment("SNAPLAND_SAVE_PATH")
	var obstruction_path := original_path + ".blocked-directory"
	var obstruction := FileAccess.open(obstruction_path, FileAccess.WRITE)
	_check(obstruction != null, "can create isolated file blocking profile directory")
	if obstruction == null:
		_finish()
		return
	obstruction.store_string("directory blocker")
	obstruction.close()
	OS.set_environment("SNAPLAND_SAVE_PATH", obstruction_path.path_join("progress.json"))
	var main: Variant = MAIN_SCENE.instantiate()
	get_tree().root.add_child(main)
	await get_tree().process_frame
	main.set("tutorial_target", "game-002")
	main.set("tutorial_origin", "first_entry")
	main.set("tutorial_assist", false)
	main.call("_tutorial_start", "game-002")
	await get_tree().process_frame
	await get_tree().process_frame
	var session: Node = main.get("session")
	_check(session != null and session.get("game_id") == "game-002", "failed seen save still starts the selected ordinary game")
	_check(main.get("toast").get("text").contains("嘗試資格尚未保存"), "failed actual-attempt save shows a retry notice")
	_check(session != null and not session.ended and not session.paused and session.is_processing(), "generic failed-save launch retains a fully initialized playable session")
	await get_tree().create_timer(0.5).timeout
	_check(session != null and session.minigame_hud._feedback.visible and session.minigame_hud._feedback_label.text.contains("本局可繼續"), "legacy session HUD retains unsaved retake notice after half a second")
	var session_count := 0
	for child in main.get("ui").get_children():
		if child.get_script() == SESSION_SCRIPT:
			session_count += 1
	_check(session_count == 1, "generic failed-save launch retains exactly one playable session")
	_check(not progress.has_seen_tutorial("game-002"), "failed save rolls back seen state")
	_check(not progress.has_attempted_game("game-002"), "failed save rolls back actual-attempt state")
	OS.set_environment("SNAPLAND_SAVE_PATH", original_path)
	progress._reset_memory()
	progress.load_progress()
	_check(not progress.has_seen_tutorial("game-002"), "failed seen state remains absent after profile reload")
	_check(not progress.has_attempted_game("game-002"), "failed attempt remains absent after profile reload")
	if is_instance_valid(main.get("audio")):
		main.get("audio").call("shutdown")
		await get_tree().create_timer(0.15).timeout
	main.queue_free()
	await get_tree().process_frame
	DirAccess.remove_absolute(obstruction_path)
	_finish()

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _finish() -> void:
	for failure in failures:
		push_error("FAIL: " + failure)
	if failures.is_empty():
		print("PASS: tutorial and attempt failed-save cleanup")
		get_tree().quit(0)
	else:
		get_tree().quit(1)
