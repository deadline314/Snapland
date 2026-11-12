extends SceneTree

const ProgressScript = preload("res://game/core/progress.gd")
const SaveGuard = preload("res://game/core/test_save_guard.gd")
const INVALID_REGIONS := [null, true, 12, 1.5, [], {}, "", "moon", "candy", "WELCOME", " harbor "]
var failures: Array[String] = []
var save_path := ""
var changes := 0

func _initialize() -> void:
	save_path = OS.get_environment("SNAPLAND_SAVE_PATH")
	if not SaveGuard.validate_save_path(save_path, OS.get_user_data_dir()).is_empty():
		push_error("Region progress tests require an absolute isolated SNAPLAND_SAVE_PATH.")
		quit(1)
		return
	call_deferred("_run")

func _run() -> void:
	var progress: Node = root.get_node("Progress")
	var fresh := ProgressScript.new()
	_check(fresh.get("current_region") == "welcome", "fresh memory starts in welcome")
	fresh.free()
	_check(progress.has_method("set_current_region"), "transactional region API exists")
	if not progress.has_method("set_current_region"):
		_finish()
		return
	if OS.get_cmdline_user_args().has("--region-diagnostics-child"):
		_test_diagnostics(progress)
		_finish("PASS: region malformed fallback and real IO rollback")
		return
	progress.reset_progress()
	_check(progress.get("current_region") == "welcome", "reset defaults to welcome")
	_test_round_trips(progress)
	_test_diagnostic_process()
	_finish()

func _fixture(progress: Node) -> Dictionary:
	progress.reset_progress()
	var payload := _read_json(save_path)
	payload.merge({
		"coins": 347, "photos": {"photo-welcome-game-1": {"note": "keep", "devil": false}},
		"achievements": {"ACH_GAME_001": true}, "quests": {"quest-001": 2},
		"visited": {"lighthouse": true}, "intro_seen": true, "prologue_seen": false,
		"platform_pending_achievements": ["ACH_GAME_001"],
		"appearance": {"hair": "windswept", "hair_color": "ink"},
		"equipped": {"outfit": "outfit-coral", "hat": "hat-none"},
		"owned_clothes": ["outfit-tide", "outfit-rainvest", "outfit-coral"],
		"wardrobe_rewarded_games": ["game-001"], "tutorial_seen_games": ["game-002"],
		"future_field": {"nested": ["keep", 3]},
	}, true)
	payload.settings.merge({"reduced_motion": true, "ui_scale": 1.25, "future_setting": {"keep": true}}, true)
	_write_json(payload)
	progress.load_progress()
	_check(progress.save_progress(), "complete fixture normalizes and saves")
	return _read_json(save_path)

func _test_round_trips(progress: Node) -> void:
	var original := _fixture(progress)
	_check(original.get("version") == 1, "save version stays one")
	progress.changed.connect(_on_changed)
	for region in ["harbor", "welcome"]:
		var before := FileAccess.get_file_as_string(save_path)
		changes = 0
		_check(progress.call("set_current_region", region) == true, "supported destination succeeds: " + region)
		_check(changes == 0, "region transaction emits no changed signal")
		_check(FileAccess.get_file_as_string(save_path + ".bak") == before, "successful transaction writes exactly once")
		var after := _read_json(save_path)
		_check(after.get("current_region") == region and progress.get("current_region") == region, "destination is durable and in memory")
		after.erase("current_region")
		var unrelated := original.duplicate(true)
		unrelated.erase("current_region")
		_check(after == unrelated, "full normalized unrelated payload remains identical")
		_check(not progress.get("_extra_fields").has("current_region"), "region is a known field")
		progress._reset_memory()
		progress.load_progress()
		_check(progress.get("current_region") == region, "supported destination survives reload: " + region)
		changes = 0
		var saved := FileAccess.get_file_as_string(save_path)
		var backup := FileAccess.get_file_as_string(save_path + ".bak")
		_check(DirAccess.make_dir_absolute(save_path + ".tmp") == OK, "block writes during no-op checks")
		_check(progress.call("set_current_region", region) == true, "same destination succeeds without writing")
		for rejected in ["", "moon", "candy", "WELCOME", " harbor "]:
			_check(progress.call("set_current_region", rejected) == false, "unsupported input rejected: " + rejected)
		_check(progress.get("current_region") == region and changes == 0, "rejected and no-op calls preserve memory and signals")
		_check(FileAccess.get_file_as_string(save_path) == saved and FileAccess.get_file_as_string(save_path + ".bak") == backup, "rejected and no-op calls preserve both files")
		_check(DirAccess.remove_absolute(save_path + ".tmp") == OK, "remove no-op write blocker")
	progress.changed.disconnect(_on_changed)
	_check(progress.call("set_current_region", "harbor") == true, "prepare harbor reset")
	progress.reset_progress()
	progress.load_progress()
	_check(progress.get("current_region") == "welcome" and _read_json(save_path).get("current_region") == "welcome", "reset persists welcome")
	for seen in [false, true]:
		var legacy := original.duplicate(true)
		legacy.erase("current_region")
		legacy.prologue_seen = seen
		_write_json(legacy)
		progress.load_progress()
		_check(progress.get("current_region") == "welcome" and progress.get("prologue_seen") == seen, "legacy region fallback preserves explicit prologue state")
		_check(progress.save_progress(), "legacy fixture saves")
		legacy["current_region"] = "welcome"
		_check(_read_json(save_path) == legacy, "legacy full normalized payload survives with welcome added")

func _test_diagnostics(progress: Node) -> void:
	var original := _fixture(progress)
	for value: Variant in INVALID_REGIONS:
		var malformed := original.duplicate(true)
		malformed["current_region"] = value
		_write_json(malformed)
		progress.load_progress()
		_check(progress.get("current_region") == "welcome", "malformed or unimplemented region falls back: " + str(value))
		_check(progress.save_progress(), "fallback normalizes save")
		_check(_read_json(save_path) == original, "fallback preserves every other normalized field")
	for previous in ["welcome", "harbor"]:
		_check(progress.call("set_current_region", previous) == true, "prepare rollback origin: " + previous)
		var saved := FileAccess.get_file_as_string(save_path)
		var backup := FileAccess.get_file_as_string(save_path + ".bak")
		progress.changed.connect(_on_changed)
		changes = 0
		_check(DirAccess.make_dir_absolute(save_path + ".tmp") == OK, "block the real temporary write")
		var destination := "harbor" if previous == "welcome" else "welcome"
		_check(progress.call("set_current_region", destination) == false, "real IO failure returns false")
		_check(progress.get("current_region") == previous and changes == 0, "failure rolls memory back without changed signal")
		_check(FileAccess.get_file_as_string(save_path) == saved and FileAccess.get_file_as_string(save_path + ".bak") == backup, "failed transaction preserves primary and backup bytes")
		_check(DirAccess.remove_absolute(save_path + ".tmp") == OK, "remove failure fixture")
		progress.changed.disconnect(_on_changed)
		_check(progress.save_progress(), "full memory remains saveable after failure")
		original["current_region"] = previous
		_check(_read_json(save_path) == original, "rollback preserves full normalized memory payload")
		progress.load_progress()
		_check(progress.get("current_region") == previous, "failed destination never survives reload")

func _test_diagnostic_process() -> void:
	var child_path := save_path.get_base_dir().path_join("region-diagnostics-child/progress.json")
	OS.set_environment("SNAPLAND_SAVE_PATH", child_path)
	var output: Array = []
	var code := OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--audio-driver", "Dummy", "--rendering-method", "gl_compatibility", "--script", "res://game/tests/test_region_progress.gd", "--", "--region-diagnostics-child"], output, true)
	OS.set_environment("SNAPLAND_SAVE_PATH", save_path)
	var expected: Array[String] = []
	for value: Variant in INVALID_REGIONS:
		expected.append("WARNING: Invalid 'current_region' field in progress file '%s'; using welcome." % child_path)
	for previous in ["welcome", "harbor"]:
		expected.append("ERROR: Cannot write progress temporary file '%s.tmp': Can't open file" % child_path)
	var diagnostics: Array[String] = []
	var passed := false
	var child_output := str(output[0] if not output.is_empty() else "")
	for line in child_output.split("\n"):
		var clean := line.strip_edges()
		if clean.contains("ERROR:") or clean.contains("WARNING:"): diagnostics.append(clean)
		if clean == "PASS: region malformed fallback and real IO rollback": passed = true
	var details := "exit=%d passed=%s diagnostics=%s output_tail=%s" % [code, passed, JSON.stringify(diagnostics).left(1500), child_output.right(3000)]
	_check(code == 0 and passed and diagnostics == expected, "child has exactly expected fallback warnings and IO error, no hidden errors; " + details)

func _read_json(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))

func _write_json(payload: Dictionary) -> void:
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	_check(file != null, "fixture opens")
	if file != null:
		file.store_string(JSON.stringify(payload))
		file.close()

func _on_changed() -> void:
	changes += 1

func _check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)

func _finish(marker := "PASS: region progress defaults, migration, transactions, and rollback") -> void:
	for failure in failures: push_error("FAIL: " + failure)
	if failures.is_empty(): print(marker)
	quit(0 if failures.is_empty() else 1)
