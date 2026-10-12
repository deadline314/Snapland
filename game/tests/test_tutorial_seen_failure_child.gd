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
	_check(session != null and session.get("game_id") == "game-002", "failed seen save starts the selected game")
	_check(main.get("toast").get("text").contains("無法保存"), "failed seen save shows a brief notice")
	var session_count := 0
	for child in main.get("ui").get_children():
		if child.get_script() == SESSION_SCRIPT:
			session_count += 1
	_check(session_count == 1, "failed seen save launches exactly one session")
	_check(not progress.has_seen_tutorial("game-002"), "failed save rolls back seen state")
	OS.set_environment("SNAPLAND_SAVE_PATH", original_path)
	progress._reset_memory()
	progress.load_progress()
	_check(not progress.has_seen_tutorial("game-002"), "failed seen state remains absent after profile reload")
	if is_instance_valid(main.get("audio")):
		main.get("audio").call("shutdown")
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
		print("PASS: tutorial seen failed-save Main start")
		get_tree().quit(0)
	else:
		get_tree().quit(1)
