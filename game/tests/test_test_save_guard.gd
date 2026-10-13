extends Node

const SaveGuard = preload("res://game/core/test_save_guard.gd")
const FIXTURE_APP_PREFIX := "SnaplandSaveGuard-"

var _fixture_root := ""
var _fixture_userdata := ""
var _fixture_name := ""
var _failed := false
var _owns_fake_userdata := false
var _fake_profile_hashes: Array[String] = []

func _ready() -> void:
	var temp_root := OS.get_environment("TEMP").replace("\\", "/")
	assert(temp_root.is_absolute_path(), "test project fixture uses the OS temporary directory")
	var unique := "%d-%d" % [Time.get_ticks_usec(), randi()]
	_fixture_root = temp_root.path_join("snapland-save-guard-" + unique)
	_fixture_name = FIXTURE_APP_PREFIX + unique
	var appdata := OS.get_environment("APPDATA").replace("\\", "/")
	_fixture_userdata = appdata.path_join("Godot/app_userdata").path_join(_fixture_name)
	var make_error := DirAccess.make_dir_recursive_absolute(_fixture_root)
	assert(make_error == OK, "create only a fresh temporary fixture root")
	var project_dir := _fixture_root.path_join("project")
	assert(DirAccess.make_dir_recursive_absolute(project_dir) == OK)
	_assertions()
	_build_fixture_project(project_dir)
	if DirAccess.dir_exists_absolute(_fixture_userdata):
		_check(false, "unique default userdata fixture does not pre-exist")
		_cleanup_temp_fixture()
		get_tree().quit(1)
		return
	var probe := _run_child(project_dir, "", "probe")
	if probe.exit_code != 0 or not probe.output.contains("FIXTURE_USERDATA=" + _fixture_userdata) or not DirAccess.dir_exists_absolute(_fixture_userdata):
		_check(false, "Godot probe creates and reports the exact unique fake default-userdata directory")
		_cleanup_temp_fixture()
		get_tree().quit(1)
		return
	_owns_fake_userdata = true
	_seed_fake_default_userdata()
	_run_guard_children(project_dir)
	_verify_fake_userdata_unchanged()
	if not _failed:
		print("NEGATIVE_FAKE_PROFILE_HASHES_UNCHANGED")
	_run_positive_isolated_child(project_dir)
	_verify_fake_userdata_unchanged()
	_run_normal_default_roundtrip(project_dir)
	_cleanup_fake_userdata()
	_cleanup_temp_fixture()
	if _failed:
		get_tree().quit(1)
		return
	print("PASS: save guard child processes use a unique verified fake Godot profile; every rejected-path case preserves seeded sidecars")
	get_tree().quit(0)

func _assertions() -> void:
	_check(SaveGuard.is_test_launch(PackedStringArray(["--script", "res://game/tests/test_test_save_guard.gd"])), "recognizes a res:// test script")
	_check(SaveGuard.is_test_launch(PackedStringArray(["--path", ".", "game/tests/test_core.tscn"])), "recognizes a relative test scene argument")
	_check(SaveGuard.is_test_launch(PackedStringArray(["--path", ".", "res://.review/native-check.tscn"])), "recognizes a review scene argument")
	_check(not SaveGuard.is_test_launch(PackedStringArray(["--path", ".", "res://game/main.tscn"])), "normal game startup keeps its existing save behavior")
	_check(not SaveGuard.is_test_launch(PackedStringArray(["--script", "res://normal_save_roundtrip.gd"])), "a root-level normal-startup fixture entrypoint uses the regular save branch")
	_check(not SaveGuard.validate_save_path("", _fixture_root).is_empty(), "missing test save path is rejected")
	_check(not SaveGuard.validate_save_path("relative/profile.json", _fixture_root).is_empty(), "relative test save path is rejected")
	_check(not SaveGuard.validate_save_path("user://progress.json", _fixture_root).is_empty(), "user:// aliases are rejected before absolute-path classification")
	_check(not SaveGuard.validate_save_path("res://.review/progress.json", _fixture_root).is_empty(), "res:// aliases are rejected before absolute-path classification")
	_check(not SaveGuard.validate_save_path(_fixture_userdata.path_join("progress.json"), _fixture_userdata).is_empty(), "default userdata path is rejected")
	_check(not SaveGuard.validate_save_path(_fixture_userdata.path_join("progress.json.bak"), _fixture_userdata).is_empty(), "default backup path is rejected")
	_check(not SaveGuard.validate_save_path(_fixture_userdata.path_join("progress.json.tmp"), _fixture_userdata).is_empty(), "default temp path is rejected")
	_check(not SaveGuard.validate_save_path(_fixture_userdata.to_upper().path_join("profile.json"), _fixture_userdata).is_empty(), "case-folded aliases stay inside default userdata boundary")
	_check(not SaveGuard.validate_save_path(_fixture_userdata.path_join("nested/profile.json"), _fixture_userdata).is_empty(), "nested paths under default userdata are rejected")
	_check(not SaveGuard.validate_save_path(_fixture_userdata.path_join("nested/../profile.json"), _fixture_userdata).is_empty(), "dot-segment aliases are normalized before userdata containment checks")
	_check(SaveGuard.validate_save_path(_fixture_root.path_join("isolated/profile.json"), _fixture_userdata).is_empty(), "an absolute isolated temporary path is accepted")
	print("MEASURED: user://progress.json String.is_absolute_path() = ", "user://progress.json".is_absolute_path(), "; validator rejects virtual URIs explicitly")

func _build_fixture_project(project_dir: String) -> void:
	var game_dir := project_dir.path_join("game")
	var core_dir := game_dir.path_join("core")
	assert(DirAccess.make_dir_recursive_absolute(core_dir) == OK)
	for source: String in ["progress.gd", "wardrobe_catalog.gd", "time_of_day.gd", "test_save_guard.gd"]:
		var source_path := "res://game/core/" + source
		var target_path := core_dir.path_join(source)
		var input := FileAccess.open(source_path, FileAccess.READ)
		assert(input != null, "fixture dependency exists: " + source)
		var output := FileAccess.open(target_path, FileAccess.WRITE)
		assert(output != null, "fixture dependency destination opens: " + source)
		output.store_buffer(input.get_buffer(input.get_length()))
		input.close()
		output.close()
	var tests_dir := game_dir.path_join("tests")
	assert(DirAccess.make_dir_recursive_absolute(tests_dir) == OK)
	_copy_script("res://game/tests/test_save_guard_child.gd", tests_dir.path_join("test_save_guard_child.gd"))
	var project := FileAccess.open(project_dir.path_join("project.godot"), FileAccess.WRITE)
	assert(project != null)
	project.store_string("[application]\nconfig/name=\"%s\"\n\n[autoload]\nProgress=\"*res://game/core/progress.gd\"\n" % _fixture_name)
	project.close()
	var normal_entry := FileAccess.open(project_dir.path_join("normal_save_roundtrip.gd"), FileAccess.WRITE)
	assert(normal_entry != null)
	normal_entry.store_string(_normal_entrypoint_source())
	normal_entry.close()

func _normal_entrypoint_source() -> String:
	return """extends SceneTree

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var mode := str(args[args.size() - 1]) if not args.is_empty() else ""
	call_deferred("_run_mode", mode)

func _run_mode(mode: String) -> void:
	var progress := root.get_node_or_null("Progress")
	if progress == null:
		push_error("normal fixture did not load the Progress autoload")
		quit(2)
		return
	print("NORMAL_USERDATA=" + OS.get_user_data_dir())
	if not OS.get_environment("SNAPLAND_SAVE_PATH").is_empty():
		push_error("normal fixture must use the default user:// save path")
		quit(3)
		return
	if mode == "load-save":
		var settings: Dictionary = progress.get("settings")
		if int(progress.get("coins")) != 321 or not bool(progress.get("intro_seen")) or str(settings.get("time_phase", "")) != "dusk":
			push_error("normal startup did not load the known fake default-userdata save")
			quit(4)
			return
		progress.set("coins", 654)
		if not bool(progress.call("save_progress")):
			push_error("normal startup could not save to its fake default userdata")
			quit(5)
			return
		print("NORMAL_DEFAULT_LOAD_SAVE_OK")
		quit(0)
		return
	if mode == "reopen":
		if int(progress.get("coins")) != 654 or not bool(progress.get("intro_seen")):
			push_error("fresh normal process did not reopen the default-userdata save")
			quit(6)
			return
		print("NORMAL_DEFAULT_REOPEN_OK")
		quit(0)
		return
	push_error("unknown normal fixture mode: " + mode)
	quit(7)
"""

func _copy_script(source_path: String, target_path: String) -> void:
	var input := FileAccess.open(source_path, FileAccess.READ)
	assert(input != null)
	var output := FileAccess.open(target_path, FileAccess.WRITE)
	assert(output != null)
	output.store_buffer(input.get_buffer(input.get_length()))
	input.close()
	output.close()

func _seed_fake_default_userdata() -> void:
	var paths := _protected_paths()
	var contents := ["fixture-primary", "fixture-backup", "fixture-temporary"]
	for index in range(paths.size()):
		var file := FileAccess.open(paths[index], FileAccess.WRITE)
		assert(file != null, "seed fake profile file " + paths[index])
		file.store_string(contents[index])
		file.close()
		_fake_profile_hashes.append(FileAccess.get_sha256(paths[index]))

func _run_guard_children(project_dir: String) -> void:
	var saved_override := OS.get_environment("SNAPLAND_SAVE_PATH")
	var bad_paths := ["", "relative/profile.json", "user://progress.json", _fixture_userdata.path_join("progress.json"), _fixture_userdata.path_join("progress.json.bak"), _fixture_userdata.path_join("progress.json.tmp")]
	for bad_path in bad_paths:
		OS.set_environment("SNAPLAND_SAVE_PATH", bad_path)
		var result := _run_child(project_dir, "--script", "guard")
		_check(result.exit_code != 0, "invalid test launch exits nonzero for '%s'" % bad_path)
		_check(result.output.contains("Save isolation guard blocked startup"), "invalid test launch reports startup guard for '%s'" % bad_path)
		_verify_fake_userdata_unchanged()
	OS.set_environment("SNAPLAND_SAVE_PATH", saved_override)

func _run_positive_isolated_child(project_dir: String) -> void:
	var positive_path := _fixture_root.path_join("positive-save/progress.json")
	OS.set_environment("SNAPLAND_SAVE_PATH", positive_path)
	var result := _run_child(project_dir, "--script", "positive")
	_check(result.exit_code == 0, "valid isolated test launch saves and reloads progress")
	_check(result.output.contains("ISOLATED_SAVE_ROUNDTRIP_OK"), "positive child reports successful save/load round trip")
	_check(FileAccess.file_exists(positive_path), "positive child wrote only the explicit temporary save")
	OS.set_environment("SNAPLAND_SAVE_PATH", "")
	DirAccess.remove_absolute(positive_path)
	DirAccess.remove_absolute(positive_path.get_base_dir())

func _run_normal_default_roundtrip(project_dir: String) -> void:
	for path in _protected_paths():
		if FileAccess.file_exists(path):
			_check(DirAccess.remove_absolute(path) == OK, "remove only owned sentinel before normal default-save test")
	var initial_payload := {"version": 1, "coins": 321, "intro_seen": true, "settings": {"time_phase": "dusk"}}
	var initial_file := FileAccess.open(_protected_paths()[0], FileAccess.WRITE)
	assert(initial_file != null, "seed the fake normal-game default progress file")
	initial_file.store_string(JSON.stringify(initial_payload, "\t"))
	initial_file.close()
	var saved_override := OS.get_environment("SNAPLAND_SAVE_PATH")
	OS.set_environment("SNAPLAND_SAVE_PATH", "")
	var first := _run_normal_game_child(project_dir, "load-save")
	_print_normal_child_output("load-save", first)
	_check(first.exit_code == 0, "ordinary startup loads and saves the seeded fake default profile")
	_check(first.output.replace("\\", "/").contains("NORMAL_USERDATA=" + _fixture_userdata), "ordinary startup resolves to the exact fake application userdata")
	_check(first.output.contains("NORMAL_DEFAULT_LOAD_SAVE_OK"), "ordinary startup reaches the normal default load/save branch")
	var saved_payload: Variant = JSON.parse_string(FileAccess.get_file_as_string(_protected_paths()[0])) if FileAccess.file_exists(_protected_paths()[0]) else null
	_check(saved_payload is Dictionary and int(saved_payload.get("coins", -1)) == 654 and bool(saved_payload.get("intro_seen", false)), "ordinary save updates the fake default profile with known loaded data")
	var reopened := _run_normal_game_child(project_dir, "reopen")
	_print_normal_child_output("reopen", reopened)
	_check(reopened.exit_code == 0, "fresh ordinary process reopens the fake default profile")
	_check(reopened.output.replace("\\", "/").contains("NORMAL_USERDATA=" + _fixture_userdata), "fresh ordinary process still resolves to the same fake application userdata")
	_check(reopened.output.contains("NORMAL_DEFAULT_REOPEN_OK"), "fresh ordinary process loads the value written by the previous process")
	OS.set_environment("SNAPLAND_SAVE_PATH", saved_override)

func _print_normal_child_output(mode: String, result: Dictionary) -> void:
	print("NORMAL_CHILD_BEGIN mode=%s exit=%d" % [mode, int(result.exit_code)])
	print(str(result.output))
	print("NORMAL_CHILD_END mode=%s" % mode)

func _run_normal_game_child(project_dir: String, mode: String) -> Dictionary:
	var args := ["--headless", "--path", project_dir, "--script", "res://normal_save_roundtrip.gd", "--", mode]
	var output: Array = []
	var exit_code := OS.execute(OS.get_executable_path(), args, output, true)
	return {"exit_code": exit_code, "output": "\n".join(PackedStringArray(output))}

func _run_child(project_dir: String, script_flag: String, mode: String) -> Dictionary:
	var args := ["--headless", "--path", project_dir]
	if not script_flag.is_empty():
		args.append_array([script_flag, "res://game/tests/test_save_guard_child.gd", "--", mode])
	else:
		args.append_array(["--script", "res://game/tests/test_save_guard_child.gd", "--", mode])
	var output: Array = []
	var exit_code := OS.execute(OS.get_executable_path(), args, output, true)
	return {"exit_code": exit_code, "output": "\n".join(PackedStringArray(output))}

func _protected_paths() -> Array[String]:
	return [_fixture_userdata.path_join("progress.json"), _fixture_userdata.path_join("progress.json.bak"), _fixture_userdata.path_join("progress.json.tmp")]

func _verify_fake_userdata_unchanged() -> void:
	var paths := _protected_paths()
	for index in range(paths.size()):
		_check(FileAccess.file_exists(paths[index]), "fake profile fixture remains present: " + paths[index])
		_check(FileAccess.get_sha256(paths[index]) == _fake_profile_hashes[index], "child left fake profile file SHA-256 unchanged: " + paths[index])

func _cleanup_fake_userdata() -> void:
	if not _owns_fake_userdata:
		return
	for path in _protected_paths():
		DirAccess.remove_absolute(path)
	# Godot creates timestamped logs while opening the child project. This path is
	# uniquely owned by the fixture name, so remove only files in that exact log dir.
	var logs_dir := _fixture_userdata.path_join("logs")
	if DirAccess.dir_exists_absolute(logs_dir):
		var logs := DirAccess.open(logs_dir)
		assert(logs != null)
		logs.list_dir_begin()
		var entry := logs.get_next()
		while not entry.is_empty():
			assert(not logs.current_is_dir() and entry.to_lower().ends_with(".log"), "unexpected file in unique Godot fixture profile: " + entry)
			assert(DirAccess.remove_absolute(logs_dir.path_join(entry)) == OK, "remove only Godot's fixture log " + entry)
			entry = logs.get_next()
		logs.list_dir_end()
		logs = null
		assert(DirAccess.remove_absolute(logs_dir) == OK)
	# Remove only this test's known sidecars and the now-empty profile directory.
	_check(DirAccess.remove_absolute(_fixture_userdata) == OK, "remove only the verified empty unique fake profile")

func _cleanup_temp_fixture() -> void:
	# The fixture root is generated uniquely above and contains only test-owned files.
	DirAccess.remove_absolute(_fixture_root.path_join("project/normal_save_roundtrip.gd"))
	DirAccess.remove_absolute(_fixture_root.path_join("project/game/tests/test_save_guard_child.gd"))
	for name: String in ["progress.gd", "wardrobe_catalog.gd", "time_of_day.gd", "test_save_guard.gd"]:
		DirAccess.remove_absolute(_fixture_root.path_join("project/game/core").path_join(name))
	DirAccess.remove_absolute(_fixture_root.path_join("project/game/tests"))
	DirAccess.remove_absolute(_fixture_root.path_join("project/game/core"))
	DirAccess.remove_absolute(_fixture_root.path_join("project/game"))
	DirAccess.remove_absolute(_fixture_root.path_join("project/project.godot"))
	DirAccess.remove_absolute(_fixture_root.path_join("project"))
	var positive_save := _fixture_root.path_join("positive-save/progress.json")
	for suffix: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(positive_save + suffix)
	DirAccess.remove_absolute(positive_save.get_base_dir())
	_check(DirAccess.remove_absolute(_fixture_root) == OK, "remove only the empty unique temporary fixture root")

func _check(condition: bool, description: String) -> void:
	if condition:
		return
	_failed = true
	push_error("FAIL: " + description)
