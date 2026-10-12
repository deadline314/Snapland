extends Node

var failures: Array[String] = []

func _ready() -> void:
	if OS.get_environment("SNAPLAND_SAVE_PATH").is_empty():
		push_error("Set SNAPLAND_SAVE_PATH to an isolated test profile before running the core suite.")
		get_tree().quit(1)
		return
	call_deferred("_run")

func _run() -> void:
	Progress.reset_progress()
	_check(Progress.normal_count() == 0, "new profile has no normal photos")
	_check(Progress.grant_photo("photo-welcome-explore-1", {"source": "explore"}), "first source grants photo")
	_check(not Progress.grant_photo("photo-welcome-explore-1"), "repeat source does not duplicate photo")
	_check(Progress.normal_count() == 1, "unique normal count")
	for i in range(1, 13):
		Progress.complete_game("game-%03d" % i, false, i == 1)
	_check(Progress.achievements.has("ACH_GAME_001"), "game achievement unlocked")
	_check(Progress.achievements.has("ACH_WELCOME_CLEAR"), "all twelve normal games unlock welcome clear")
	_check(not Progress.achievements.has("ACH_WELCOME_DEVILS"), "normal clear does not unlock devil set")
	_check(not Progress.achievements.has("ACH_ALL_DEVILS"), "welcome collection does not unlock global devil set")
	for i in range(1, 13):
		Progress.complete_game("game-%03d" % i, true)
	_check(Progress.achievements.has("ACH_WELCOME_DEVILS"), "all welcome devils unlock zone achievement")
	_check(not Progress.achievements.has("ACH_ALL_DEVILS"), "one zone does not unlock global devil achievement")
	_check(Progress.devil_count() == 12, "welcome devil count is unique")
	for zone in ["harbor", "candy", "nightmarket", "circus", "toy", "garden", "hotel", "sky", "cinema"]:
		for i in range(1, 13):
			Progress.grant_photo("photo-%s-devil-%d" % [zone, i])
	_check(Progress.devil_count("harbor") == 12, "canonical zone devil IDs count correctly")
	_check(Progress.devil_count("nightmarket") == 12, "night market ID matches park data")
	Progress.complete_game("game-001", false)
	_check(Progress.achievements.has("ACH_ALL_DEVILS"), "all 120 canonical zone devil cards unlock global achievement")
	Progress.advance_quest("story-intro", 2)
	Progress.advance_quest("story-intro", 1)
	_check(Progress.quests["story-intro"] == 2, "quest progress cannot move backwards")
	Progress.advance_quest("quest-001", 99)
	_check(Progress.quests["quest-001"] == 3, "quest progress is bounded to three steps")
	_check(Progress._valid_quest_step(2.0), "whole-number JSON float quest steps are valid")
	_check(not Progress._valid_quest_step(2.5) and not Progress._valid_quest_step(-1.0) and not Progress._valid_quest_step(4.0), "fractional, negative and out-of-range quest steps are rejected")
	var fixed_normal_count := Progress.normal_count()
	Progress.grant_photo("photo-theatre-game-1")
	Progress.grant_photo("photo-welcome-random-1")
	_check(Progress.normal_count() == fixed_normal_count, "unknown photos remain stored without increasing unlock progress")
	Progress.set_setting("master_volume", 4.0)
	_check(Progress.settings.master_volume == 1.0, "volume values are clamped")
	Progress.set_setting("text_speed", 2.0)
	Progress.set_setting("reduced_motion", true)
	Progress.settings["future_setting"] = "preserved"
	Progress.visited["welcome"] = true
	Progress.intro_seen = true
	Progress._extra_fields["future_field"] = {"kept": true}
	Progress.photos["photo-welcome-explore-3"] = {"pose": 0}
	var complete_saved_tree_before: Dictionary = _progress_payload_snapshot()
	_check(Progress.save_progress(), "progress saves")
	Progress._reset_memory()
	Progress.load_progress()
	var complete_saved_tree_after: Dictionary = _progress_payload_snapshot()
	_check(_saved_tree_semantically_equal(complete_saved_tree_before, complete_saved_tree_after), "all saved progress fields, IDs, quest cursors, and integer-pose metadata survive one real JSON save/reload")
	var reloaded_pose: Variant = Progress.photos.get("photo-welcome-explore-3", {}).get("pose", null)
	print("CORE SAVE DIAGNOSTIC: pose=%s type=%s photo_ids=%d" % [str(reloaded_pose), type_string(typeof(reloaded_pose)), Progress.photos.size()])
	_check(typeof(reloaded_pose) in [TYPE_INT, TYPE_FLOAT] and float(reloaded_pose) == 0.0, "integer pose metadata retains its exact numeric value after reload")
	_check(Progress.photos.size() == 136, "all unique photos plus the integer-pose record survive reload")
	_check(Progress.quests["story-intro"] == 2 and Progress.quests["quest-001"] == 3, "integer quest progress survives JSON reload")
	_check(Progress.achievements.has("ACH_WELCOME_DEVILS"), "achievements survive reload")
	_check(Progress.settings.master_volume == 1.0 and Progress.settings.text_speed == 2.0, "settings survive reload")
	_check(Progress.settings.reduced_motion, "boolean accessibility setting survives reload")
	_check(Progress.settings.future_setting == "preserved", "unknown setting fields survive reload")
	_check(Progress.visited.has("welcome") and Progress.intro_seen, "visited and intro state survive reload")
	_check(Progress._extra_fields.get("future_field", {}).get("kept", false), "unknown save fields survive reload")
	var sent: Array[String] = []
	SteamBridge.pending_achievements.clear()
	SteamBridge.queue_achievement("ACH_OFFLINE")
	SteamBridge.set_achievement_sender(func(id: String) -> bool:
		sent.append(id)
		return false
	)
	_check(SteamBridge.sync_pending() == 0 and SteamBridge.pending_achievements.has("ACH_OFFLINE"), "failed platform callback remains queued")
	SteamBridge.set_achievement_sender(func(id: String) -> bool:
		sent.append(id)
		return true
	)
	_check(SteamBridge.sync_pending() == 1 and SteamBridge.pending_achievements.is_empty(), "successful platform callback clears queue")
	_check(sent.size() == 2, "platform callback is called per attempt")
	SteamBridge.queue_achievement("ACH_RESTART_QUEUE")
	_check(Progress.save_progress(), "queued achievement saves")
	Progress._reset_memory()
	Progress.load_progress()
	_check(Progress.platform_pending_achievements.has("ACH_RESTART_QUEUE"), "offline achievement queue survives reload")
	var float_save := FileAccess.open(Progress._save_path(), FileAccess.WRITE)
	_check(float_save != null, "can prepare JSON numeric quest-step fixture")
	if float_save != null:
		float_save.store_string('{"quests":{"json-float":2.0}}')
		float_save.close()
		Progress.load_progress()
		_check(Progress.quests.get("json-float", -1) == 2, "whole-number JSON float quest steps survive load")
	if failures.is_empty():
		print("PASS: core runtime checks")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		get_tree().quit(1)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _progress_payload_snapshot() -> Dictionary:
	var payload: Dictionary = Progress._extra_fields.duplicate(true)
	payload.merge({
		"version": Progress.SAVE_VERSION,
		"photos": Progress.photos,
		"achievements": Progress.achievements,
		"quests": Progress.quests,
		"settings": Progress.settings,
		"visited": Progress.visited,
		"intro_seen": Progress.intro_seen,
		"platform_pending_achievements": Progress.platform_pending_achievements,
		"appearance": Progress.appearance,
		"equipped": Progress.equipped,
		"owned_clothes": Progress.owned_clothes,
		"coins": Progress.coins,
		"wardrobe_rewarded_games": Progress.wardrobe_rewarded_games,
		"tutorial_seen_games": Progress.tutorial_seen_games,
	}, true)
	return payload

func _saved_tree_semantically_equal(before: Variant, after: Variant) -> bool:
	if typeof(before) == TYPE_DICTIONARY and typeof(after) == TYPE_DICTIONARY:
		var before_dict: Dictionary = before
		var after_dict: Dictionary = after
		if before_dict.size() != after_dict.size(): return false
		for key in before_dict:
			if not after_dict.has(key) or not _saved_tree_semantically_equal(before_dict[key], after_dict[key]): return false
		return true
	if typeof(before) == TYPE_ARRAY and typeof(after) == TYPE_ARRAY:
		var before_array: Array = before
		var after_array: Array = after
		if before_array.size() != after_array.size(): return false
		for index in range(before_array.size()):
			if not _saved_tree_semantically_equal(before_array[index], after_array[index]): return false
		return true
	if typeof(before) in [TYPE_INT, TYPE_FLOAT] and typeof(after) in [TYPE_INT, TYPE_FLOAT]:
		return float(before) == float(after)
	return typeof(before) == typeof(after) and before == after
