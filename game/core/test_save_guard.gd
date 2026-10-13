extends RefCounted
## Keeps test/review launches from falling back to a player's live progress file.

static func is_test_launch(arguments: PackedStringArray) -> bool:
	for argument in arguments:
		var normalized := str(argument).replace("\\", "/").to_lower()
		if normalized.contains("/game/tests/") or normalized.begins_with("game/tests/") or normalized.contains("/.review/") or normalized.begins_with(".review/"):
			return true
	return false

static func validate_save_path(override_path: String, default_user_data_dir: String) -> String:
	var candidate := override_path.strip_edges()
	if candidate.is_empty():
		return "SNAPLAND_SAVE_PATH is required when running a test or review scene; refusing to use player progress."
	if candidate.contains("://"):
		return "SNAPLAND_SAVE_PATH must be a plain absolute filesystem path, not a Godot virtual path; refusing '%s'." % candidate
	if not candidate.is_absolute_path():
		return "SNAPLAND_SAVE_PATH must be an absolute file path; refusing '%s'." % candidate
	var normalized_candidate := _normalized_path(candidate)
	var normalized_default := _normalized_path(default_user_data_dir)
	if _path_is_inside(normalized_candidate, normalized_default):
		return "SNAPLAND_SAVE_PATH must be outside the default Godot userdata directory; refusing '%s'." % candidate
	return ""

static func _normalized_path(path: String) -> String:
	return path.replace("\\", "/").simplify_path().trim_suffix("/").to_lower()

static func _path_is_inside(candidate: String, directory: String) -> bool:
	if directory.is_empty():
		return false
	return candidate == directory or candidate.begins_with(directory + "/")
