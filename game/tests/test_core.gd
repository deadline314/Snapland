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
	_check(Progress.save_progress(), "progress saves")
	Progress._reset_memory()
	Progress.load_progress()
	_check(Progress.photos.size() == 135, "unique photos survive reload")
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
