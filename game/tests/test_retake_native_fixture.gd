extends SceneTree
## Package dependency preflight; GPU gameplay belongs to native_photo_retake.
var failures: Array[String] = []

func _initialize() -> void:
	if not OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path():
		push_error("Retake fixture preflight requires absolute isolated save")
		quit(1)
		return
	create_timer(85).timeout.connect(func(): push_error("Retake preflight watchdog"); quit(1))
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func _run() -> void:
	var native: Script = load("res://game/tests/native_photo_retake.gd")
	if native == null or not native.can_instantiate():
		push_error("Native retake script cannot load")
		quit(1)
		return
	var fixture: Node = native.new()
	var adjacent := native.resource_path.get_base_dir().path_join("retake_native_route.gd")
	check(fixture.Route != null and fixture.Route.resource_path == adjacent, "source helper is explicitly adjacent")
	fixture.free()
	var directory := OS.get_environment("SNAPLAND_SAVE_PATH").get_base_dir().path_join("retake-external")
	check(DirAccess.make_dir_recursive_absolute(directory) == OK, "isolated external fixture directory")
	var external := directory.path_join("native_photo_retake.gd")
	check(DirAccess.copy_absolute(ProjectSettings.globalize_path(native.resource_path),external) == OK, "copy actual fixture outside project")
	var external_script: Script = load(external)
	check(external_script != null, "external fixture parses using production resources")
	if external_script != null:
		var missing: Node = external_script.new()
		check(missing.Route == null, "absent adjacent helper fails closed despite source repository helper")
		missing.free()
	var helper_path := directory.path_join("retake_native_route.gd")
	check(DirAccess.copy_absolute(ProjectSettings.globalize_path(adjacent),helper_path) == OK, "explicitly copy only adjacent helper")
	if external_script != null:
		var independent: Node = external_script.new()
		check(independent.Route != null and independent.Route.resource_path == external_script.resource_path.get_base_dir().path_join("retake_native_route.gd"), "external fixture uses its own helper without repository fallback")
		independent.free()
	check(load("res://game/tests/native_photo_retake.tscn") is PackedScene, "source entry scene loads")
	check(load("res://game/main.tscn") is PackedScene, "real production Main loads")
	check(load("res://game/ui/retake_panel.gd") is Script, "real production retake panel loads")
	var catalog: Script = load("res://game/core/game_catalog.gd")
	var lessons: RefCounted = load("res://game/ui/tutorial_catalog.gd").new()
	for definition in catalog.all_definitions():
		var lesson: Dictionary = lessons.get_lesson(definition.id)
		check(not lesson.is_empty(), "delivered lesson exists "+definition.id)
		for step in lesson.get("steps",[]):
			var texture: Texture2D = load(step.image)
			check(texture != null and texture.get_size() == Vector2(1280,720), "actual tutorial PNG "+str(step.image))
	check(load("res://assets/minigames/props/tidal-props-v2.png") is Texture2D, "production set prop atlas loads")
	check(JSON.parse_string(FileAccess.get_file_as_string("res://assets/minigames/props/regions.json")) is Dictionary, "production prop regions load")
	for failure in failures: push_error("FAIL: "+failure)
	if failures.is_empty(): print("PASS: retake native fixture adjacent helper, isolated packaging and real resources")
	quit(0 if failures.is_empty() else 1)
