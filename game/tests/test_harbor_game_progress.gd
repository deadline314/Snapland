extends SceneTree

class CountingProgress:
	extends "res://game/core/progress.gd"
	var save_calls := 0
	func save_progress() -> bool:
		save_calls += 1
		return super.save_progress()

var failures: Array[String] = []
var changes := 0
var unlocked: Array[String] = []
var progress: Node
var save_path := ""

func _initialize() -> void:
	save_path = OS.get_environment("SNAPLAND_SAVE_PATH")
	if not save_path.is_absolute_path():
		push_error("Harbor progress tests require an absolute isolated SNAPLAND_SAVE_PATH.")
		quit(1)
		return
	call_deferred("_run")

func _run() -> void:
	progress = CountingProgress.new()
	root.add_child(progress)
	if OS.get_cmdline_user_args().has("--reload-child"):
		_check(progress.photos.get("photo-harbor-game-1", {}).get("frames", []) == [save_path.get_base_dir().path_join("thumb.png")], "second process loads the harbor thumbnail")
		_check(progress.photos.get("photo-harbor-devil-1", {}).get("original_frames", []) == [save_path.get_base_dir().path_join("original.png")], "second process loads the harbor original")
		_check(progress.coins == 160 and progress.wardrobe_rewarded_games == ["game-013"] and progress.has_seen_tutorial("game-013"), "second process loads currency, global receipt and tutorial")
		_check(progress.achievements.has("ACH_GAME_013") and progress.platform_pending_achievements.has("ACH_GAME_013"), "second process loads global achievement and pending platform receipt")
		_check(progress._extra_fields.get("future", {}).get("kept", false) and progress.photos.get("photo-future", {}).get("opaque", []) == ["keep"], "second process preserves unknown metadata")
		_finish("PASS: harbor progress reload child")
		return
	if OS.get_cmdline_user_args().has("--failure-child"):
		_test_real_write_failure()
		_finish("PASS: harbor atomic failure child")
		return
	progress.reset_progress()
	progress.changed.connect(func(): changes += 1)
	progress.achievement_unlocked.connect(func(id: String):
		unlocked.append(id)
		_check(_read_saved().get("achievements", {}).has(id), "achievement signal only observes persisted rewards")
		progress.changed.emit()
	)
	_check(progress.has_method("attach_game_photo_frames"), "regional photo attachment API exists")
	_check(progress.call("complete_game", "game-013", false, true) == true, "first ordinary harbor completion reports saved status")
	if not progress.photos.has("photo-harbor-game-1") or not progress.has_method("attach_game_photo_frames"):
		_finish()
		return
	progress.reset_progress()
	changes = 0
	unlocked.clear()
	progress.save_calls = 0
	progress._extra_fields["future"] = {"kept": true}
	progress.photos["photo-future"] = {"opaque": ["keep"]}
	_check(progress.complete_game("game-013", false, true), "ordinary completion saves")
	_check(progress.save_calls == 1 and changes == 2 and unlocked == ["ACH_GAME_013"], "one atomic write includes all rewards before achievement and changed signals, including nested changed")
	_check(progress.coins == 160 and progress.wardrobe_rewarded_games == ["game-013"], "harbor awards forty coins once using the global receipt")
	_check(progress.photos["photo-harbor-game-1"] == {"game_id": "game-013", "assisted": true, "devil": false}, "ordinary metadata records assistance")
	_check(not progress.photos.has("photo-harbor-devil-1") and not progress.achievements.has("ACH_WELCOME_CLEAR"), "ordinary harbor card neither grants devil nor welcome completion")
	var before_replay := _snapshot()
	var writes: int = progress.save_calls
	var signals := changes
	_check(progress.complete_game("game-013", false) and _snapshot() == before_replay and progress.save_calls == writes and changes == signals, "ordinary replay preserves metadata with no duplicate writes, money or signals")
	_check(progress.complete_game("game-013", true, true), "assisted devil completion saves")
	_check(progress.coins == 160 and progress.photos["photo-harbor-devil-1"].assisted and unlocked == ["ACH_GAME_013"], "devil assistance remains eligible without a second payout or achievement signal")
	before_replay = _snapshot()
	writes = progress.save_calls
	signals = changes
	_check(progress.complete_game("game-013", true) and _snapshot() == before_replay and progress.save_calls == writes and changes == signals, "devil replay is idempotent")
	for invalid in ["game-015", "game-000", "game-13", "rowing_cargo", "game-013 ", ""]:
		_check(not progress.complete_game(invalid, true) and not progress.mark_game_tutorial_seen(invalid) and not progress.has_seen_tutorial(invalid) and _snapshot() == before_replay, "unsupported and malformed persistent IDs never mutate state: " + invalid)
	_check(progress.mark_game_tutorial_seen("game-013") and progress.has_seen_tutorial("game-013"), "delivered harbor tutorial is supported")
	var safe: Dictionary = progress._validated_payload({"tutorial_seen_games": ["game-013", "game-015", "game-13", 13], "wardrobe_rewarded_games": ["game-013", "game-015", "rowing_cargo", null]}, "harbor-fixture")
	_check(safe.tutorial_seen_games == ["game-013"] and safe.wardrobe_rewarded_games == ["game-013"], "tutorial and reward validators accept only delivered canonical IDs")
	var thumb := save_path.get_base_dir().path_join("thumb.png")
	var original := save_path.get_base_dir().path_join("original.png")
	var image := Image.create(320, 180, false, Image.FORMAT_RGBA8)
	image.fill(Color.CORNFLOWER_BLUE)
	_check(image.save_png(thumb) == OK, "actual 320x180 thumbnail is written")
	image.resize(960, 540)
	_check(image.save_png(original) == OK, "actual full resolution PNG is written")
	_check(not progress.attach_welcome_game_photo_frames("game-013", [thumb], true, [original]), "welcome wrapper preserves its region restriction")
	_check(not progress.attach_game_photo_frames("game-015", [thumb], true), "unsupported attachment cannot grant a card")
	_check(not progress.attach_game_photo_frames("game-013", [original], true), "original dimensions cannot pass thumbnail validation")
	_check(progress.attach_game_photo_frames("game-013", [thumb], true, [original]), "harbor shares validated thumbnails and originals")
	_check(progress.photos["photo-harbor-game-1"].frames == [thumb] and progress.photos["photo-harbor-devil-1"].frames == [thumb] and progress.photos["photo-harbor-devil-1"].original_frames == [original], "both harbor records reference the same captures")
	_check(progress.attach_game_photo_frames("game-013", ["missing.png"], true, [thumb + ".missing"]), "invalid replay files retain previously validated thumbnail and original metadata")
	_check(progress.save_progress(), "harbor reload fixture persists")
	_test_child("--reload-child", save_path, "PASS: harbor progress reload child", 0)
	_test_child("--failure-child", save_path.get_base_dir().path_join("failure/profile.json"), "PASS: harbor atomic failure child", 3)
	progress.reset_progress()
	progress.photos["photo-harbor-game-1"] = {"legacy": {"kept": true}}
	_check(progress.complete_game("game-013", true) and progress.coins == 120 and progress.wardrobe_rewarded_games == ["game-013"], "legacy harbor card records a receipt without retroactive currency")
	_check(progress.photos["photo-harbor-game-1"] == {"legacy": {"kept": true}}, "legacy ordinary metadata remains untouched")
	progress.reset_progress()
	for number in range(1, 12): progress.complete_game("game-%03d" % number, true)
	progress.complete_game("game-013", true)
	_check(not progress.achievements.has("ACH_WELCOME_CLEAR") and not progress.achievements.has("ACH_WELCOME_DEVILS"), "eleven welcome games plus harbor do not meet either twelve-game milestone")
	progress.complete_game("game-012", false)
	_check(progress.achievements.has("ACH_WELCOME_CLEAR") and not progress.achievements.has("ACH_WELCOME_DEVILS"), "all twelve welcome ordinary cards unlock only their milestone")
	progress.complete_game("game-012", true)
	_check(progress.achievements.has("ACH_WELCOME_DEVILS") and not progress.achievements.has("ACH_ALL_DEVILS"), "all twelve welcome devils unlock welcome milestone only")
	_finish()

func _test_child(argument: String, child_path: String, marker: String, expected_errors: int) -> void:
	var output: Array = []
	OS.set_environment("SNAPLAND_SAVE_PATH", child_path)
	var code := OS.execute(OS.get_executable_path(), PackedStringArray(["--headless", "--audio-driver", "Dummy", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://game/tests/test_harbor_game_progress.gd", "--", argument]), output, true, false)
	OS.set_environment("SNAPLAND_SAVE_PATH", save_path)
	var log_text := str(output[0]) if not output.is_empty() else ""
	var errors: Array[String] = []
	for line in log_text.split("\n"):
		if line.contains("ERROR:"): errors.append(line.strip_edges())
	var expected: Array[String] = []
	if expected_errors > 0:
		for index in range(2): expected.append("ERROR: Cannot write progress temporary file '%s.tmp': Can't open file" % child_path)
		expected.append("ERROR: Could not save gameplay thumbnail paths for 'photo-harbor-game-1'.")
	_check(code == 0 and log_text.contains(marker) and errors == expected, "isolated child contract %s: exit=%d errors=%s output=%s" % [argument, code, str(errors), log_text.right(2000)])

func _test_real_write_failure() -> void:
	progress.reset_progress()
	progress.photos["photo-future"] = {"opaque": ["keep"]}
	progress._extra_fields["future"] = {"kept": true}
	_check(progress.save_progress(), "prepare existing persisted state before a failed completion")
	progress.changed.connect(func(): changes += 1)
	progress.achievement_unlocked.connect(func(id: String): unlocked.append(id))
	var before := _snapshot()
	var persisted := FileAccess.get_file_as_string(save_path)
	var blocker := save_path + ".tmp"
	_check(DirAccess.make_dir_absolute(blocker) == OK, "directory blocks the real temporary write")
	progress.save_calls = 0
	_check(not progress.complete_game("game-013", true, true), "actual write failure reports completion unsaved")
	_check(progress.save_calls == 1 and changes == 0 and unlocked.is_empty(), "failed completion attempts one write without success signals")
	_check(_snapshot() == before and FileAccess.get_file_as_string(save_path) == persisted, "failed completion rolls back cards, coins, receipt, achievements and platform queue without touching the saved file")
	_check(DirAccess.remove_absolute(blocker) == OK, "remove isolated temporary-write blocker")
	_check(progress.complete_game("game-013", true), "completion can be retried after the write failure")
	var thumb := save_path.get_base_dir().path_join("kept.png")
	var original := save_path.get_base_dir().path_join("kept-original.png")
	var image := Image.create(320, 180, false, Image.FORMAT_RGBA8)
	image.fill(Color.TEAL)
	_check(image.save_png(thumb) == OK, "write failure fixture thumbnail")
	image.resize(960, 540)
	_check(image.save_png(original) == OK, "write failure fixture original")
	_check(progress.attach_game_photo_frames("game-013", [thumb], true, [original]), "prepare existing shared capture metadata")
	var replacement := save_path.get_base_dir().path_join("replacement.png")
	image.resize(320, 180)
	_check(image.save_png(replacement) == OK, "write replacement thumbnail")
	before = _snapshot()
	persisted = FileAccess.get_file_as_string(save_path)
	_check(DirAccess.make_dir_absolute(blocker) == OK, "block the attachment save")
	_check(not progress.attach_game_photo_frames("game-013", [replacement], true, [replacement]), "attachment failure reports unsaved status")
	_check(_snapshot() == before and FileAccess.get_file_as_string(save_path) == persisted, "failed attachment restores both thumbnails and both originals in memory and on disk")
	_check(DirAccess.remove_absolute(blocker) == OK, "remove attachment save blocker")

func _snapshot() -> Dictionary:
	return {"photos": progress.photos.duplicate(true), "achievements": progress.achievements.duplicate(true), "coins": progress.coins, "receipts": progress.wardrobe_rewarded_games.duplicate(), "pending": progress.platform_pending_achievements.duplicate(), "tutorials": progress.tutorial_seen_games.duplicate(), "extra": progress._extra_fields.duplicate(true)}

func _read_saved() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(save_path))

func _check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)

func _finish(marker := "PASS: harbor rewards, replay, legacy, captures, reload and atomic failure") -> void:
	for failure in failures: push_error("FAIL: " + failure)
	if failures.is_empty(): print(marker)
	quit(0 if failures.is_empty() else 1)
