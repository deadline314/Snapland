extends SceneTree
## The shared island wind: declared once, advanced by the world ambience, and
## standing still under reduced motion.

const ParkWorld = preload("res://game/world/park_world.gd")
const WorldAmbience = preload("res://game/world/world_ambience.gd")
const WIND_INCLUDE := "res://game/world/wind.gdshaderinc"

var failures := 0
var checks := 0


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("Island wind: " + message)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for global_name in [WorldAmbience.WIND_TIME, WorldAmbience.WIND_WALKER]:
		_check(ProjectSettings.has_setting("shader_globals/" + str(global_name)), "project declares global '%s'" % global_name)
	_check(FileAccess.file_exists(WIND_INCLUDE), "the shared wind include exists")
	var include_text := FileAccess.get_file_as_string(WIND_INCLUDE)
	for global_name in [WorldAmbience.WIND_TIME, WorldAmbience.WIND_WALKER]:
		_check(include_text.contains("global uniform") and include_text.contains(str(global_name)), "include reads global '%s'" % global_name)
	for user in ["res://game/world/grass.gdshader", "res://game/world/living_sprite.gdshader"]:
		var code := FileAccess.get_file_as_string(user)
		_check(code.contains('#include "%s"' % WIND_INCLUDE), "%s uses the shared wind" % user.get_file())
		_check(not code.contains("TIME * 0.72"), "%s no longer runs its own wind clock" % user.get_file())
		_check(load(user) is Shader, "%s loads" % user.get_file())

	var world: Node3D = ParkWorld.new()
	root.add_child(world)
	await process_frame
	var ambience: Node = world.ambience
	_check(is_instance_valid(ambience), "the world has an ambience layer to drive the wind")
	world.apply_settings({"reduced_motion": false})
	var before: float = ambience._wind_time
	for step in 5:
		ambience.advance(0.1)
	_check(ambience._wind_time > before + 0.49, "wind advances with the world")
	world.apply_settings({"reduced_motion": true})
	var frozen: float = ambience._wind_time
	for step in 5:
		ambience.advance(0.1)
	_check(is_equal_approx(ambience._wind_time, frozen), "wind stands still under reduced motion")
	world.apply_settings({"reduced_motion": false})
	ambience.advance(0.1)
	_check(ambience._wind_time > frozen, "wind resumes when motion returns")
	world.queue_free()
	await process_frame
	if failures == 0:
		print("PASS: shared island wind declaration, users and reduced-motion freeze (%d checks)" % checks)
	quit(1 if failures > 0 else 0)
