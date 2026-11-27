extends SceneTree
## Picture-quality levels: only ever remove cost, are validated like any other
## saved setting, and drive the world's lamp, shading and ambience budgets.

const RenderQuality = preload("res://game/world/render_quality.gd")
const ParkWorld = preload("res://game/world/park_world.gd")

var failures := 0
var checks := 0


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("Render quality: " + message)


func _initialize() -> void:
	_run.call_deferred()


func _lamp_counts(world: Node3D) -> Vector2i:
	var lit := 0
	var shadowed := 0
	for lamp: Light3D in world.lamps:
		if lamp.light_energy > 0.0:
			lit += 1
		if lamp.shadow_enabled:
			shadowed += 1
	return Vector2i(lit, shadowed)


func _run() -> void:
	_check(RenderQuality.LEVELS.has(RenderQuality.DEFAULT_LEVEL), "default level exists")
	for level in RenderQuality.LEVELS:
		_check(RenderQuality.PROFILES.has(level), "level '%s' has a profile" % level)
	for bad in [null, 3, "ultra", "", ["high"]]:
		_check(RenderQuality.normalize(bad) == RenderQuality.DEFAULT_LEVEL, "invalid level %s falls back" % str(bad))
	# Each lower level may only remove cost relative to the one above it.
	for index in range(1, RenderQuality.LEVELS.size()):
		var above: Dictionary = RenderQuality.profile(RenderQuality.LEVELS[index - 1])
		var below: Dictionary = RenderQuality.profile(RenderQuality.LEVELS[index])
		for key: String in above:
			_check(below.has(key), "'%s' defines %s" % [RenderQuality.LEVELS[index], key])
			_check(int(below[key]) <= int(above[key]), "'%s' never costs more than '%s' for %s" % [RenderQuality.LEVELS[index], RenderQuality.LEVELS[index - 1], key])

	var progress := root.get_node("Progress")
	_check(progress.DEFAULT_SETTINGS.get("graphics_quality") == RenderQuality.DEFAULT_LEVEL, "new saves start at the default level")
	progress.set_setting("graphics_quality", "low")
	_check(progress.settings.graphics_quality == "low", "a valid level is stored")
	progress.set_setting("graphics_quality", "cinematic")
	_check(progress.settings.graphics_quality == RenderQuality.DEFAULT_LEVEL, "an invalid level stores the default")

	var world: Node3D = ParkWorld.new()
	root.add_child(world)
	await process_frame
	world.set_time_of_day("night")
	var nodes_before := world.find_children("*", "Node", true, false).size()
	var materials_before: int = world.material_cache.size()
	for level in RenderQuality.LEVELS:
		var profile: Dictionary = RenderQuality.profile(level)
		world.apply_settings({"reduced_motion": false, "graphics_quality": level})
		var counts := _lamp_counts(world)
		_check(world.render_quality == level, "world records level '%s'" % level)
		_check(counts.x <= int(profile.active_lamps) and counts.x <= ParkWorld.ACTIVE_LAMP_LIMIT, "'%s' lights at most its lamp budget (%d)" % [level, counts.x])
		_check(counts.y == mini(int(profile.lamp_shadows), counts.x), "'%s' shadows exactly its budget at night (%d)" % [level, counts.y])
		_check(world.environment.ssao_enabled == bool(profile.ssao) and world.environment.glow_enabled == bool(profile.glow), "'%s' sets environment passes" % level)
		if is_instance_valid(world.ambience) and world.ambience.cloud != null:
			world.set_time_of_day("noon")
			_check(world.ambience.cloud.visible == bool(profile.cloud_shade), "'%s' cloud shade matches at noon" % level)
			world.set_time_of_day("night")
	world.apply_settings({"reduced_motion": false, "graphics_quality": "not-a-level"})
	_check(world.render_quality == RenderQuality.DEFAULT_LEVEL, "the world falls back to the default level")
	world.apply_settings({"reduced_motion": false})
	_check(world.render_quality == RenderQuality.DEFAULT_LEVEL, "a missing setting means the default level")
	_check(world.find_children("*", "Node", true, false).size() == nodes_before, "switching levels adds no nodes")
	_check(world.material_cache.size() == materials_before, "switching levels adds no materials")
	world.queue_free()
	await process_frame
	if failures == 0:
		print("PASS: picture quality levels, saved setting and world budgets (%d checks)" % checks)
	quit(1 if failures > 0 else 0)
