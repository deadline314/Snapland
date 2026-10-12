extends SceneTree

const StoryDirector = preload("res://game/story/story_director.gd")

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
