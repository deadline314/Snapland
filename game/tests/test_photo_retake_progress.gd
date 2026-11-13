extends SceneTree

const Catalog = preload("res://game/core/game_catalog.gd")
var progress: Node
var failures: Array[String] = []
var changes := 0
var unlocked: Array[String] = []
var save_path: String
var thumb: String
var original: String

func _initialize() -> void:
	save_path = OS.get_environment("SNAPLAND_SAVE_PATH")
	assert(save_path.is_absolute_path())
	call_deferred("_run")

func _run() -> void:
	progress = root.get_node("Progress")
	for method in ["has_attempted_game", "mark_game_attempted", "complete_retake"]:
		_check(progress.has_method(method), "required API: " + method)
	if not failures.is_empty():
		_finish()
		return
	if OS.get_cmdline_user_args().has("--failure-child"):
		_test_blocked_writes()
		_finish()
		return
	progress.reset_progress()
	progress.changed.connect(func(): changes += 1)
	progress.achievement_unlocked.connect(func(id: String):
		unlocked.append(id)
		_check(JSON.parse_string(FileAccess.get_file_as_string(save_path)).achievements.has(id), "signals follow persisted transaction")
	)
	thumb = save_path.get_base_dir().path_join("retake.png")
	original = save_path.get_base_dir().path_join("retake-original.png")
	var image := Image.create(320, 180, false, Image.FORMAT_RGBA8)
	image.fill(Color.TEAL)
	_check(image.save_png(thumb) == OK, "write real thumbnail")
	image.resize(960, 540)
	_check(image.save_png(original) == OK, "write real original")
	var bytes := FileAccess.get_file_as_bytes(thumb)
	for invalid in ["", "game-000", "game-015", "game-13", "rowing_cargo", "game-013 "]:
		var before := _snapshot()
		_check(not progress.mark_game_attempted(invalid) and not progress.has_attempted_game(invalid) and not progress.complete_retake(invalid, true, [thumb], [original]) and _snapshot() == before, "invalid target rejected: " + invalid)
	_check(not progress.complete_retake("game-013", false, [thumb], [original]), "unattempted game cannot retake")
	_check(progress.mark_game_attempted("game-013") and progress.mark_game_attempted("game-013") and progress.attempted_games == ["game-013"], "one canonical attempt")
	progress._reset_memory()
	progress.load_progress()
	_check(progress.has_attempted_game("game-013"), "attempt reload")
	progress.reset_progress()
	progress.load_progress()
	_check(progress.attempted_games.is_empty(), "reset clears persisted history")
	var mixed: Array = ["game-013", "game-013", "rowing_cargo", "game-015", "game-13", null, 13]
	for i in 100: mixed.append("game-001")
	var safe: Dictionary = progress._validated_payload({"attempted_games": mixed, "future": {"kept": true}}, "fixture")
	_check(safe.attempted_games == ["game-001", "game-013"], "canonical deduplicated bounded attempt history")
	progress._apply_save(safe)
	_check(progress.attempted_games == safe.attempted_games and progress._extra_fields == {"future": {"kept": true}}, "known history and future metadata preserved")
	var all_attempts: Array = mixed.duplicate()
	for definition: Dictionary in Catalog.all_definitions(): all_attempts.append(definition.id)
	_check(progress._validated_payload({"attempted_games": all_attempts}, "fixture").attempted_games.size() == Catalog.all_definitions().size(), "history never exceeds delivered count")
	for definition: Dictionary in Catalog.all_definitions():
		var identity := Catalog.identity(definition.id)
		for card: String in [identity.photo_id, identity.devil_photo_id]:
			progress._apply_save({"photos": {card: {"legacy": true}, "photo-future-game-1": {"game_id": "game-015"}}, "future": 7})
			_check(progress.attempted_games == [definition.id], "canonical old card infers " + card)
	progress._apply_save({"photos": {"photo-welcome-game-01": {}, "photo-welcome-game-99": {}, "photo-future": {"game_id": "game-001"}}})
	_check(progress.attempted_games.is_empty(), "malformed and unrelated metadata cannot infer attempts")
	_check(progress._validated_payload({"attempted_games": {}}, "fixture").get("attempted_games", []).is_empty(), "wrong-type attempt history defaults empty")
	progress.reset_progress()
	progress._extra_fields["future"] = {"kept": true}
	_check(progress.save_progress(), "persist before blocked writes")
	_test_failure_child()
	_check(progress.mark_game_attempted("game-013"), "retry attempt save")
	for invalid_frames: Array in [[], [original], [thumb + ".missing"], [thumb, thumb], [thumb, thumb, thumb, thumb]]:
		_check(not progress.complete_retake("game-013", true, invalid_frames, [original]), "invalid thumbnail list rejected")
	for invalid_originals: Array in [[], [original + ".missing"], [original, original]]:
		_check(not progress.complete_retake("game-013", true, [thumb], invalid_originals), "invalid original list rejected")
	var oversized := save_path.get_base_dir().path_join("oversized.png")
	image.resize(2049, 2048)
	_check(image.save_png(oversized) == OK, "write over-limit original")
	_check(not progress.complete_retake("game-013", true, [thumb], [oversized]), "bounded original required")
	_check(progress.complete_retake("game-013", true, [thumb], [original]), "selected devil awarded")
	_check(not progress.photos.has("photo-harbor-game-1") and progress.photos["photo-harbor-devil-1"].acquisition_method == "retake" and not progress.photos["photo-harbor-devil-1"].challenge_earned, "devil retake never grants ordinary or technique")
	_check(progress.coins == 160 and progress.wardrobe_rewarded_games == ["game-013"], "one forty-coin receipt")
	var devil: Dictionary = progress.photos["photo-harbor-devil-1"].duplicate(true)
	_check(progress.complete_retake("game-013", false, [thumb], [original]) and progress.photos["photo-harbor-devil-1"] == devil, "ordinary retake preserves existing devil metadata")
	var ordinary: Dictionary = progress.photos["photo-harbor-game-1"].duplicate(true)
	var before := _snapshot()
	_check(not progress.complete_retake("game-013", false, [thumb], [original]) and _snapshot() == before, "owned selected card is refused without mutation")
	_check(progress.complete_game("game-013", false) and progress.photos["photo-harbor-devil-1"] == devil, "ordinary gameplay cannot assert devil technique")
	_check(progress.complete_game("game-013", true), "genuine devil records evidence")
	_check(progress.photos["photo-harbor-devil-1"].challenge_earned and progress.photos["photo-harbor-devil-1"].frames == devil.frames and progress.photos["photo-harbor-devil-1"].acquisition_method == "retake" and progress.photos["photo-harbor-game-1"] == ordinary, "real technique retains first provenance and both retake photos")
	var other_thumb := save_path.get_base_dir().path_join("gameplay.png")
	var other_original := save_path.get_base_dir().path_join("gameplay-original.png")
	image.resize(320, 180)
	image.fill(Color.CORAL)
	_check(image.save_png(other_thumb) == OK, "write different gameplay thumbnail")
	image.resize(960, 540)
	_check(image.save_png(other_original) == OK, "write different gameplay original")
	devil = progress.photos["photo-harbor-devil-1"].duplicate(true)
	_check(progress.attach_game_photo_frames("game-013", [other_thumb], true, [other_original]) and progress.photos["photo-harbor-game-1"] == ordinary and progress.photos["photo-harbor-devil-1"] == devil, "gameplay attachment preserves both retake metadata and paths")
	progress.load_progress()
	_check(progress.photos["photo-harbor-game-1"] == ordinary and progress.photos["photo-harbor-devil-1"] == devil, "reload migration preserves retake photos and genuine proof")
	_check(progress.coins == 160 and FileAccess.get_file_as_bytes(thumb) == bytes, "both paths and replays keep single receipt and PNG bytes")
	for legacy_game: String in ["game-001", "game-013"]:
		var identity := Catalog.identity(legacy_game)
		for old_devil in [false, true]:
			progress.reset_progress()
			var old_id: String = identity.devil_photo_id if old_devil else identity.photo_id
			progress._apply_save({"photos": {old_id: {"legacy": "keep"}}})
			before = _snapshot()
			_check(not progress.complete_retake(legacy_game, old_devil, [thumb], [original]) and _snapshot() == before, "owned old selected card never silently grants its missing counterpart or receipt")
			_check(progress.complete_retake(legacy_game, not old_devil, [thumb], [original]) and progress.coins == 120 and progress.photos[old_id] == {"legacy": "keep"}, "old ordinary OR devil without receipt receives no money or other-card changes")
			before = _snapshot()
			progress.load_progress()
			_check(_snapshot() == before, "legacy migration cannot borrow retake photos or mutate the other card")
			_check(progress.complete_game(legacy_game, true), "genuine gameplay after mixed acquisition")
			var retake_id: String = identity.photo_id if old_devil else identity.devil_photo_id
			var retake_card: Dictionary = progress.photos[retake_id].duplicate(true)
			before = _snapshot()
			var saved_before := FileAccess.get_file_as_bytes(save_path)
			_check(not progress.attach_game_photo_frames(legacy_game, [thumb + ".missing"], true, []), "mixed invalid replay fails when gameplay target has no valid image")
			_check(_snapshot() == before and FileAccess.get_file_as_bytes(save_path) == saved_before, "failed mixed fallback cannot borrow staged captures or mutate saved cards")
			_check(progress.attach_game_photo_frames(legacy_game, [other_thumb], true, [other_original]), "mixed gameplay attachment succeeds")
			_check(progress.photos[retake_id] == retake_card and progress.photos[old_id].frames == [other_thumb], "only gameplay-acquired card receives replay images")
			before = _snapshot()
			_check(progress.attach_game_photo_frames(legacy_game, [thumb + ".missing"], true, []), "mixed invalid replay retains the target's validated gameplay image")
			_check(_snapshot() == before and progress.photos[old_id].frames == [other_thumb] and progress.photos[old_id].original_frames == [other_original], "mixed fallback preserves genuine thumbnail and original without staged borrowing")
	progress.reset_progress()
	_check(progress.mark_game_attempted("game-002") and progress.complete_retake("game-002", false, [thumb], [original]), "ordinary-first retake succeeds")
	_check(not progress.photos.has("photo-welcome-devil-2") and progress.photos["photo-welcome-game-2"].acquisition_method == "retake" and not progress.photos["photo-welcome-game-2"].challenge_earned, "ordinary-first retake grants only selected ordinary without technique")
	progress.reset_progress()
	_check(progress.complete_game("game-001", true), "real gameplay award")
	_check(progress.photos["photo-welcome-devil-1"].challenge_earned, "real devil first acquisition carries evidence")
	_check(progress.mark_game_attempted("game-001") and not progress.complete_retake("game-001", true, [thumb], [original]) and progress.coins == 160, "gameplay first cannot duplicate retake money")
	_finish()

func _test_failure_child() -> void:
	var child_path := save_path.get_base_dir().path_join("failed/profile.json")
	OS.set_environment("SNAPLAND_SAVE_PATH", child_path)
	var output: Array = []
	var code := OS.execute(OS.get_executable_path(), PackedStringArray(["--headless", "--audio-driver", "Dummy", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://game/tests/test_photo_retake_progress.gd", "--", "--failure-child"]), output, true, false)
	OS.set_environment("SNAPLAND_SAVE_PATH", save_path)
	var log_text := str(output[0]) if not output.is_empty() else ""
	var errors: Array[String] = []
	for line in log_text.split("\n"):
		if line.contains("ERROR:"): errors.append(line.strip_edges())
	var expected: Array[String] = []
	for retry in 4: expected.append("ERROR: Cannot write progress temporary file '%s.tmp': Can't open file" % child_path)
	_check(code == 0 and log_text.contains("PASS: attempt history, selected retake awards, provenance and atomic rollback") and errors == expected, "isolated blocked-save child checks exact four deliberate errors: " + log_text.right(1600))

func _test_blocked_writes() -> void:
	progress.reset_progress()
	progress.changed.connect(func(): changes += 1)
	progress.achievement_unlocked.connect(func(id: String): unlocked.append(id))
	progress._extra_fields["future"] = {"kept": true}
	_check(progress.save_progress(), "prepare persisted blocked-write state")
	var before := _snapshot()
	var disk := FileAccess.get_file_as_string(save_path)
	var blocker := save_path + ".tmp"
	_check(DirAccess.make_dir_absolute(blocker) == OK, "block real writes")
	for retry in 2:
		_check(not progress.mark_game_attempted("game-013") and _snapshot() == before and FileAccess.get_file_as_string(save_path) == disk and changes == 0 and unlocked.is_empty(), "failed attempt rolls back repeatedly without signals")
	_check(DirAccess.remove_absolute(blocker) == OK, "unblock attempts")
	_check(progress.mark_game_attempted("game-013"), "retry saves attempt")
	var child_thumb := save_path.get_base_dir().get_base_dir().path_join("retake.png")
	var child_original := save_path.get_base_dir().get_base_dir().path_join("retake-original.png")
	before = _snapshot()
	disk = FileAccess.get_file_as_string(save_path)
	_check(DirAccess.make_dir_absolute(blocker) == OK, "block real retake award")
	_check(not progress.complete_retake("game-013", true, [child_thumb], [child_original]), "award fails honestly")
	_check(_snapshot() == before and FileAccess.get_file_as_string(save_path) == disk and changes == 0 and unlocked.is_empty(), "failed award restores every reward field, queue and signals")
	_check(DirAccess.remove_absolute(blocker) == OK, "unblock award")
	_check(progress.complete_retake("game-013", true, [child_thumb], [child_original]), "retry retake succeeds")
	before = _snapshot()
	disk = FileAccess.get_file_as_string(save_path)
	changes = 0
	unlocked.clear()
	_check(DirAccess.make_dir_absolute(blocker) == OK, "block genuine technique update")
	_check(not progress.complete_game("game-013", true) and _snapshot() == before and FileAccess.get_file_as_string(save_path) == disk and changes == 0 and unlocked.is_empty(), "failed gameplay proof restores retake photo, missing ordinary and reward state")
	_check(DirAccess.remove_absolute(blocker) == OK, "unblock genuine proof")

func _snapshot() -> Dictionary:
	return {"photos": progress.photos.duplicate(true), "achievements": progress.achievements.duplicate(true), "coins": progress.coins, "receipts": progress.wardrobe_rewarded_games.duplicate(), "pending": progress.platform_pending_achievements.duplicate(), "attempts": progress.attempted_games.duplicate(), "extra": progress._extra_fields.duplicate(true)}

func _check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func _finish() -> void:
	for failure in failures: push_error("FAIL: " + failure)
	if failures.is_empty(): print("PASS: attempt history, selected retake awards, provenance and atomic rollback")
	quit(0 if failures.is_empty() else 1)
