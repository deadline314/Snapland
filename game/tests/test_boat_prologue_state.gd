extends SceneTree

const ProgressScript = preload("res://game/core/progress.gd")
const StoryDirector = preload("res://game/story/story_director.gd")
const SaveGuard = preload("res://game/core/test_save_guard.gd")
var _failures: Array[String] = []
var _save_path := ""

func _initialize() -> void:
	_save_path = OS.get_environment("SNAPLAND_SAVE_PATH").strip_edges()
	if not SaveGuard.validate_save_path(_save_path, OS.get_user_data_dir()).is_empty():
		push_error("Boat state tests need an absolute isolated SNAPLAND_SAVE_PATH.")
		quit(1)
		return
	call_deferred("_run")

func _run() -> void:
	var progress: Node = root.get_node("Progress")
	var fresh := ProgressScript.new()
	_check(fresh.get("prologue_seen") == false, "new memory defaults to unseen")
	fresh.free()
	progress.reset_progress()
	_check(progress.get("prologue_seen") == false, "reset defaults to unseen")
	_check(progress.has_method("mark_prologue_seen"), "durable completion API exists")
	if progress.has_method("mark_prologue_seen"):
		_test_saves(progress)
	var story := StoryDirector.new()
	_check(story.has_method("prologue_lines"), "optional prologue API exists")
	if story.has_method("prologue_lines"):
		_test_story(story)
	for failure in _failures:
		push_error("FAIL: " + failure)
	if _failures.is_empty():
		print("PASS: boat prologue state, save boundaries, and optional story validation")
	quit(0 if _failures.is_empty() else 1)

func _test_saves(progress: Node) -> void:
	var payload: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_save_path))
	payload.merge({"coins": 347, "photos": {"photo-welcome-story": {"note": "keep"}}, "achievements": {"ACH_TEST": true}, "quests": {"quest-001": 2}, "intro_seen": true, "future_field": {"nested": ["keep", 3]}, "appearance": {"hair": "windswept", "hair_color": "ink"}}, true)
	payload.erase("prologue_seen")
	_write_json(_save_path, payload)
	progress.load_progress()
	_check(progress.get("prologue_seen") == true, "valid legacy save skips the new prologue")
	for value in [false, true]:
		payload["prologue_seen"] = value
		_write_json(_save_path, payload)
		progress.load_progress()
		_check(progress.get("prologue_seen") == value, "explicit %s loads" % str(value))
		_check(progress.save_progress(), "explicit %s saves" % str(value))
		progress._reset_memory()
		progress.load_progress()
		_check(progress.get("prologue_seen") == value, "explicit %s survives round trip" % str(value))
	for malformed in ["false", 0, null, [], {}]:
		payload["prologue_seen"] = malformed
		_write_json(_save_path, payload)
		progress.load_progress()
		_check(progress.get("prologue_seen") == true and progress.coins == 347, "malformed optional flag defaults to seen without rejecting save")
	payload["prologue_seen"] = false
	_write_json(_save_path, payload)
	progress.load_progress()
	_check(progress.save_progress(), "normalized fixture saves")
	var before: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_save_path))
	_check(progress.call("mark_prologue_seen") == true, "mark completes and saves")
	var after: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_save_path))
	var backup: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_save_path + ".bak"))
	_check(after.get("prologue_seen") == true and backup.get("prologue_seen") == false, "mark saves once and preserves previous backup")
	after.erase("prologue_seen")
	before.erase("prologue_seen")
	_check(after == before, "completion changes no rewards, arrival, appearance, or unknown fields")
	var saved_text := FileAccess.get_file_as_string(_save_path)
	var backup_text := FileAccess.get_file_as_string(_save_path + ".bak")
	DirAccess.make_dir_absolute(_save_path + ".tmp")
	_check(progress.call("mark_prologue_seen") == true, "already completed mark succeeds without a writable destination")
	_check(FileAccess.get_file_as_string(_save_path) == saved_text and FileAccess.get_file_as_string(_save_path + ".bak") == backup_text, "idempotent mark performs no save")
	progress.set("prologue_seen", false)
	_check(progress.call("mark_prologue_seen") == false, "unwritable temporary file reports failed save")
	_check(progress.get("prologue_seen") == false, "failed save rolls memory back")
	_check(FileAccess.get_file_as_string(_save_path) == saved_text and FileAccess.get_file_as_string(_save_path + ".bak") == backup_text, "failed save keeps durable files intact")
	DirAccess.remove_absolute(_save_path + ".tmp")
	progress.load_progress()
	_check(progress.get("prologue_seen") == true, "reload retains the prior durable completion")
	progress.reset_progress()
	progress.load_progress()
	_check(progress.get("prologue_seen") == false, "new game reset persists unseen")

func _test_story(story: RefCounted) -> void:
	var lines: Array = story.call("prologue_lines")
	_check(lines.size() == 5, "exactly five prologue beats")
	if lines.size() == 5:
		_check(lines.map(func(line: Dictionary) -> String: return str(line.speaker)) == ["阿浪", "主角", "主角", "阿浪", "主角"], "speakers follow the five beats")
		_check(lines.map(func(line: Dictionary) -> String: return str(line.pose)) == ["idle", "interact", "photograph", "wave", "idle"], "poses follow the five beats")
		lines[0]["text"] = "mutated"
		_check(story.call("prologue_lines")[0].text != "mutated", "getter returns a deep copy")
	var parsed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(StoryDirector.STORY_DATA_PATH))
	var fixture_path := _save_path + ".story.json"
	parsed.erase("prologue_lines")
	_write_json(fixture_path, parsed)
	var legacy := StoryDirector.new(fixture_path, false)
	_check(legacy.validation_report().ok and legacy.call("prologue_lines").is_empty() and not legacy.intro_lines().is_empty(), "missing optional lines preserve legacy arrival")
	for invalid in [null, {}, [], [null], [{"speaker": "露露", "text": "你好", "pose": "idle"}], [{"speaker": "主角", "text": "  ", "pose": "idle"}], [{"speaker": "主角", "text": 123, "pose": "idle"}], [{"speaker": "主角", "text": "你好", "pose": "jump"}], [{"speaker": "主角", "text": "你好"}]]:
		parsed["prologue_lines"] = invalid
		_write_json(fixture_path, parsed)
		var broken := StoryDirector.new(fixture_path, false)
		_check(not broken.validation_report().ok and str(broken.validation_report().diagnostics).contains("prologue_lines") and broken.call("prologue_lines").is_empty(), "invalid supplied prologue is diagnosed and unavailable")
	DirAccess.remove_absolute(fixture_path)

func _write_json(path: String, payload: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	_check(file != null, "fixture file opens")
	if file != null:
		file.store_string(JSON.stringify(payload))
		file.close()

func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
