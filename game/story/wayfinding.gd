extends RefCounted
## Signpost data and the live status line each direction shows.
##
## Signposts answer "where can I go next and what is left there" from saved
## progress only. They never change progress themselves.

const DATA_PATH := "res://game/data/wayfinding.json"
const TARGET_KINDS := ["character", "quest", "games", "coast"]
const QUEST_STEP_COUNT := 3

var _signposts: Array = []
var _diagnostics: Array[String] = []

func _init(path: String = DATA_PATH) -> void:
	_load(path)

func _load(path: String) -> void:
	_signposts.clear()
	_diagnostics.clear()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	if not parsed is Dictionary or int(parsed.get("schema_version", 0)) != 1 or not parsed.get("signposts", null) is Array:
		_diagnostics.append("wayfinding data at %s must be an object with schema_version 1 and signposts" % path)
		push_warning("Wayfinding: " + _diagnostics.back())
		return
	var seen: Dictionary = {}
	for signpost: Variant in parsed.signposts:
		var problem := _signpost_problem(signpost, seen)
		if not problem.is_empty():
			_diagnostics.append(problem)
			push_warning("Wayfinding: %s; signpost ignored" % problem)
			continue
		seen[str(signpost.id)] = true
		_signposts.append(signpost)

func _signpost_problem(signpost: Variant, seen: Dictionary) -> String:
	if not signpost is Dictionary:
		return "signpost must be an object"
	var id := str(signpost.get("id", ""))
	if id.is_empty() or seen.has(id):
		return "signpost has a missing or duplicate id"
	var position: Variant = signpost.get("position", null)
	if not position is Array or position.size() != 2:
		return "signpost '%s' needs an [x, z] position" % id
	var entries: Variant = signpost.get("entries", null)
	if not entries is Array or entries.is_empty() or entries.size() > 4:
		return "signpost '%s' needs one to four entries" % id
	for entry: Variant in entries:
		if not entry is Dictionary or str(entry.get("label", "")).is_empty() or str(entry.get("arrow", "")).is_empty():
			return "signpost '%s' has an entry without arrow or label" % id
		var target: Variant = entry.get("target", null)
		if not target is Dictionary or not TARGET_KINDS.has(str(target.get("kind", ""))):
			return "signpost '%s' has an entry with an unknown target" % id
		if str(target.kind) == "games" and (not target.get("ids", null) is Array or (target.ids as Array).is_empty()):
			return "signpost '%s' lists a game group without ids" % id
	return ""

func diagnostics() -> Array[String]:
	return _diagnostics.duplicate()

func signposts() -> Array:
	return _signposts.duplicate(true)

## snapshot: {"story_photo": bool, "steps": {quest_id: int}, "photos": {photo_id: ...}}.
## Returns a status short enough for one signpost line, such as "拍貼 2/4".
static func entry_status(entry: Dictionary, snapshot: Dictionary) -> String:
	var target: Dictionary = entry.get("target", {})
	var steps: Dictionary = snapshot.get("steps", {})
	var photos: Dictionary = snapshot.get("photos", {})
	match str(target.get("kind", "")):
		"character":
			return "已見面 ✓" if bool(snapshot.get("story_photo", false)) else "先打招呼"
		"quest":
			var step := int(steps.get(str(target.get("id", "")), 0))
			if step >= QUEST_STEP_COUNT:
				return "完成 ✓"
			# Same count as the HUD quest line: steps already done out of three.
			return "有事相求" if step <= 0 else "委託 %d/3" % step
		"games":
			var ids: Array = target.get("ids", [])
			var collected := 0
			for game_id in ids:
				if photos.has("photo-welcome-game-%d" % int(str(game_id).trim_prefix("game-"))):
					collected += 1
			return "拍貼 %d/%d" % [collected, ids.size()] + (" ✓" if collected == ids.size() else "")
		"coast":
			return "6 處地標"
	return ""

## One readable signpost line: arrow, destination and live status.
static func entry_line(entry: Dictionary, snapshot: Dictionary) -> String:
	return "%s %s　%s" % [str(entry.get("arrow", "")), str(entry.get("label", "")), entry_status(entry, snapshot)]
