extends SceneTree

const StoryDirector = preload("res://game/story/story_director.gd")
const Wayfinding = preload("res://game/story/wayfinding.gd")

func _initialize() -> void:
	if OS.get_environment("SNAPLAND_SAVE_PATH").strip_edges().is_empty():
		push_error("Set SNAPLAND_SAVE_PATH to an isolated temporary save path before running story tests.")
		quit(1)
		return
	call_deferred("_run")

func _run() -> void:
	var story := StoryDirector.new()
	var report := story.validation_report()
	_check(bool(report.get("ok", false)), "story data validates: %s" % str(report.get("diagnostics", [])))
	_check(story.character_profiles().keys().size() == 3, "exactly three park character profiles")
	for character_id in ["ticket", "imp", "announcer"]:
		var profile := story.character_profile(character_id)
		_check(not str(profile.get("motivation", "")).is_empty(), "%s has a clear motive" % character_id)
		_check(not str(profile.get("voice", "")).is_empty(), "%s has a distinct voice" % character_id)
	_check(story.character_profile("lulu").is_empty(), "unavailable Lulu has no profile")
	var intro := story.intro_lines()
	var main_lines := story.main_lines()
	_check(not intro.is_empty() and main_lines.size() >= 3, "intro and return dialogue exist")
	for line in intro + main_lines:
		_check(str(line.get("speaker", "")) != "露露", "dialogue does not present unavailable Lulu as a speaker")
		_check(not str(line.get("text", "")).strip_edges().is_empty(), "dialogue text is non-empty")
	_check(not str(main_lines[1].get("text", "")).contains("修好了"), "announcer return line does not claim an unimplemented sign repair")
	var imp_mission := story.quest_mission_data("quest-001")
	var imp_steps: Array = imp_mission.get("steps", [])
	var camera_goal := str(imp_steps[2].get("goal", "")) if imp_steps.size() == 3 else ""
	_check(camera_goal.contains("自己的角色") and not camera_goal.contains("小角"), "game-010 lesson describes the player avatar, not Xiao Jiao appearing in the photo")
	_check(not str(imp_mission.get("motivation", "")).contains("修好"), "Xiao Jiao's story does not claim the backdrop was repaired")

	var first := story.quest_data("quest-001")
	var second := story.quest_data("quest-002")
	for quest in [first, second]:
		_check(not quest.is_empty(), "legacy quest remains available")
		_check((quest.get("steps", []) as Array).size() == 3, "legacy quiz API retains three steps")
		_check(quest.has("photo_id"), "legacy reward photo field remains available")
		for step in quest.steps:
			_check(step.prompt is String and not step.prompt.is_empty(), "legacy prompt remains available")
			_check(step.options is Array and step.options.size() >= 2, "legacy options remain available")
			_check(step.correct >= 0 and step.correct < step.options.size(), "legacy answer index remains valid")
	_check(first.photo_id == "photo-welcome-quest-1", "quest-001 reward photo id is stable")
	_check(second.photo_id == "photo-welcome-quest-2", "quest-002 reward photo id is stable")
	_check(story.quest_data("missing").is_empty(), "unknown legacy quest safely returns empty")
	_check(story.mission_progress_valid("quest-001", 0) and story.mission_progress_valid("quest-001", 3), "legacy mission progress bounds accepted")
	_check(not story.mission_progress_valid("quest-001", -1) and not story.mission_progress_valid("quest-001", 4), "invalid mission progress rejected")

	_test_mission_one(story)
	_test_mission_two(story)
	_test_conversations()
	_test_wayfinding()
	var explorations := story.exploration_data()
	_check(explorations.size() == 3, "all legacy exploration entries remain")
	_check(explorations.map(func(item: Dictionary) -> String: return item.id) == ["explore-001", "explore-002", "explore-003"], "exploration ids are stable")
	_check(explorations.map(func(item: Dictionary) -> String: return item.photo_id) == ["photo-welcome-explore-1", "photo-welcome-explore-2", "photo-welcome-explore-3"], "exploration photo ids are stable")
	_check(story.prologue_entry().get("status") == "future", "unimplemented boat prologue stays marked future")
	if _failures.is_empty():
		print("PASS: story data, compatibility, mission evidence, and idempotency")
		quit(0)
	else:
		push_error("Story tests failed: %d assertion(s)" % _failures.size())
		quit(1)

var _failures: Array[String] = []

func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
		push_error("FAIL: " + message)

func _state(story_photo: bool, first: int, second: int, phase := "noon") -> Dictionary:
	return {"story_photo": story_photo, "steps": {"quest-001": first, "quest-002": second}, "time_phase": phase}

func _test_conversations() -> void:
	var story := StoryDirector.new()
	# The request a character makes follows the saved step and reacts to the last thing done.
	var imp_ids: Array[String] = []
	for step in range(4):
		imp_ids.append(str(story.conversation_for("imp", _state(true, step, 0)).get("id", "")))
	_check(imp_ids == ["imp-ask", "imp-bench", "imp-bubble", "imp-done"], "Xiao Jiao's lines follow each quest step: %s" % str(imp_ids))
	var announcer_ids: Array[String] = []
	for step in range(4):
		announcer_ids.append(str(story.conversation_for("announcer", _state(true, 0, step)).get("id", "")))
	_check(announcer_ids == ["announcer-ask", "announcer-sign", "announcer-crowd", "announcer-done"], "阿浪's lines follow each quest step: %s" % str(announcer_ids))
	_check(str(story.conversation_for("imp", _state(true, 3, 0)).get("id", "")) == "imp-done-encore", "equally specific finished lines rotate instead of repeating")
	_check(str(story.conversation_for("imp", _state(true, 3, 0)).get("id", "")) == "imp-done", "rotation returns to the least recently heard line")
	var ticket_cases := {
		"ticket-open-day": _state(true, 0, 0), "ticket-underway": _state(true, 1, 0),
		"ticket-imp-done": _state(true, 3, 2), "ticket-announcer-done": _state(true, 1, 3),
		"ticket-both-done": _state(true, 3, 3), "ticket-fallback": _state(false, 0, 0),
	}
	for expected in ticket_cases:
		_check(str(story.conversation_for("ticket", ticket_cases[expected]).get("id", "")) == expected, "票票 picks %s for its matching progress" % expected)
	# Result lines only appear once the result really exists.
	for step in range(3):
		for line in story.conversation_for("imp", _state(true, step, 0)).get("lines", []):
			_check(not str(line.text).contains("綁上"), "unfinished Xiao Jiao never claims the ribbon is tied (step %d)" % step)
		for line in story.conversation_for("announcer", _state(true, 0, step)).get("lines", []):
			_check(not str(line.text).contains("轉正"), "unfinished 阿浪 never claims the sign was turned (step %d)" % step)
	# Time asides join a conversation once per phase, in the speaker's own voice.
	var fresh := StoryDirector.new()
	var first: Dictionary = fresh.conversation_for("announcer", _state(true, 0, 0, "night"))
	var last_line: Dictionary = (first.get("lines", []) as Array).back()
	_check(bool(first.get("time_aside", false)) and str(last_line.speaker) == "阿浪" and str(last_line.text) == fresh.time_aside("announcer", "night"), "a night visit ends with 阿浪's night remark")
	_check(not bool(fresh.conversation_for("announcer", _state(true, 0, 0, "night")).get("time_aside", true)), "the same phase remark is not repeated on the next visit")
	_check(bool(fresh.conversation_for("announcer", _state(true, 0, 0, "dawn")).get("time_aside", false)), "a new phase brings a new remark")
	for character_id in ["ticket", "imp", "announcer"]:
		for phase_id in ["dawn", "noon", "dusk", "night"]:
			_check(not fresh.time_aside(character_id, phase_id).is_empty(), "%s has a %s remark" % [character_id, phase_id])
		_check(not (fresh.conversation_for(character_id, {}).get("lines", []) as Array).is_empty(), "%s always has something to say" % character_id)
	# Broken data is reported rather than silently accepted.
	var broken_path := "user://story-conversation-negative.json"
	var parsed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(StoryDirector.STORY_DATA_PATH))
	var conversations: Dictionary = parsed.conversations
	conversations["imp"] = (conversations["imp"] as Array).filter(func(entry: Dictionary) -> bool: return not (entry.when as Dictionary).is_empty())
	(conversations["announcer"] as Array)[0]["when"] = {"weather": "rain"}
	var file := FileAccess.open(broken_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(parsed))
	file.close()
	var broken_report: Dictionary = StoryDirector.new(broken_path, false).validation_report()
	var diagnostics := str(broken_report.get("diagnostics", []))
	_check(not bool(broken_report.get("ok", true)) and diagnostics.contains("fallback") and diagnostics.contains("weather"), "missing fallback and unknown conditions are reported: %s" % diagnostics)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(broken_path))

func _test_wayfinding() -> void:
	var wayfinding := Wayfinding.new()
	_check(wayfinding.diagnostics().is_empty() and wayfinding.signposts().size() == 3, "three signposts load without diagnostics")
	var ids: Array = wayfinding.signposts().map(func(signpost: Dictionary) -> String: return str(signpost.id))
	_check(ids == ["dock", "plaza", "avenue"], "signposts cover the dock, plaza and avenue forks")
	var snapshot := {"story_photo": false, "steps": {"quest-001": 1, "quest-002": 3}, "photos": {"photo-welcome-game-1": {}, "photo-welcome-game-3": {}}}
	var quest_entry := {"arrow": "↖", "label": "小角", "target": {"kind": "quest", "id": "quest-001"}}
	_check(Wayfinding.entry_status(quest_entry, snapshot) == "委託 1/3" and Wayfinding.entry_line(quest_entry, snapshot) == "↖ 小角　委託 1/3", "quest direction counts finished steps like the HUD")
	_check(Wayfinding.entry_status({"target": {"kind": "quest", "id": "quest-002"}}, snapshot) == "完成 ✓", "finished quest direction says so")
	_check(Wayfinding.entry_status({"target": {"kind": "quest", "id": "quest-002"}}, {"steps": {}}) == "有事相求", "unstarted quest direction invites the player")
	var group := {"target": {"kind": "games", "ids": ["game-001", "game-002", "game-003", "game-004"]}}
	_check(Wayfinding.entry_status(group, snapshot) == "拍貼 2/4", "district direction counts only that district's photos")
	_check(Wayfinding.entry_status({"target": {"kind": "games", "ids": ["game-001"]}}, snapshot).ends_with("✓"), "a completed district is marked")
	_check(Wayfinding.entry_status({"target": {"kind": "character", "id": "ticket"}}, snapshot) == "先打招呼", "before meeting 票票 the sign points the player to her")
	var met_entry := {"arrow": "←", "label": "票票・導覽亭", "target": {"kind": "character", "id": "ticket"}}
	var met_line := Wayfinding.entry_line(met_entry, {"story_photo": true})
	_check(Wayfinding.entry_status(met_entry, {"story_photo": true}) == "已見面 ✓" and met_line.count("導覽亭") == 1, "after meeting 票票 the sign says so without repeating the place name: %s" % met_line)
	var bad_path := "user://wayfinding-negative.json"
	var file := FileAccess.open(bad_path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"schema_version": 1, "signposts": [{"id": "x", "position": [0, 0], "entries": [{"arrow": "↑", "label": "?", "target": {"kind": "teleport"}}]}, {"id": "y", "position": [1], "entries": []}]}))
	file.close()
	var broken := Wayfinding.new(bad_path)
	_check(broken.signposts().is_empty() and broken.diagnostics().size() == 2, "invalid signposts are skipped with diagnostics")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(bad_path))

func _test_mission_one(story: RefCounted) -> void:
	var progress := 0
	var response: Dictionary = story.mission_event_result("quest-001", progress, {"type": "interaction", "id": "quest-001"})
	_check(response.accepted and response.next_step == 1, "quest-001 accepts the real greeting interaction")
	progress = int(response.next_step)
	response = story.mission_event_result("quest-001", progress, {"type": "photo_collected", "id": "photo-welcome-explore-1"})
	_check(not response.accepted and response.next_step == progress, "wrong photo evidence cannot advance quest-001")
	response = story.mission_event_result("quest-001", progress, {"type": "photo_collected", "id": "photo-welcome-explore-3"})
	_check(response.accepted and response.next_step == 2, "the existing explore-003 photo proves the framing step")
	progress = int(response.next_step)
	response = story.mission_event_result("quest-001", progress, {"type": "minigame_result", "id": "game-010", "success": true, "practice": true})
	_check(not response.accepted, "practice result cannot advance a reward mission")
	response = story.mission_event_result("quest-001", progress, {"type": "minigame_result", "id": "game-010", "success": true, "practice": false})
	_check(response.accepted and response.complete and response.next_step == 3, "successful non-practice game completes quest-001")
	_check(response.reward_photo_id == "photo-welcome-quest-1" and response.idempotency_key == response.reward_photo_id, "completion emits stable legacy reward key")
	response = story.mission_event_result("quest-001", 3, {"type": "minigame_result", "id": "game-010", "success": true})
	_check(not response.accepted and response.reward_photo_id.is_empty(), "re-entry after completion cannot emit a duplicate reward")

func _test_mission_two(story: RefCounted) -> void:
	var response: Dictionary = story.mission_event_result("quest-002", 0, {"type": "interaction", "id": "quest-002"})
	_check(response.accepted and response.next_step == 1, "quest-002 accepts its announcer interaction")
	response = story.mission_event_result("quest-002", 1, {"type": "photo_collected", "id": "photo-welcome-explore-2"})
	_check(response.accepted and response.next_step == 2, "existing explore-002 proof photo completes observation step")
	response = story.mission_event_result("quest-002", 2, {"type": "minigame_result", "id": "game-004", "success": true, "practice": false})
	_check(response.accepted and response.complete and response.reward_photo_id == "photo-welcome-quest-2", "crowd-control result completes quest-002 with stable reward")
	_check(not story.mission_event_result("unknown", 0, {}).accepted, "unknown mission returns explicit rejection")
	_check(not story.mission_event_result("quest-002", 4, {}).accepted, "out-of-range mission cursor returns explicit rejection")
