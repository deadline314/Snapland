extends SceneTree

const Profiles = preload("res://game/world/ambience_profiles.gd")
const Sprites = preload("res://game/world/ambience_sprites.gd")
const Critters = preload("res://game/world/ambience_critters.gd")
const SaveGuard = preload("res://game/core/test_save_guard.gd")
const WORLDS := {
	"welcome": "res://game/world/park_world.gd",
	"harbor": "res://game/world/harbor_world.gd",
	"candy": "res://game/world/candy_world.gd",
	"nightmarket": "res://game/world/nightmarket_world.gd",
	"circus": "res://game/world/circus_world.gd",
	"toy": "res://game/world/toy_world.gd",
	"garden": "res://game/world/garden_world.gd",
	"hotel": "res://game/world/hotel_world.gd",
}
const PHASES := ["dawn", "noon", "dusk", "night"]
const STEP := 1.0 / 60.0
const FAR := Vector3(60, 0.4, 60)

var _errors: Array[String] = []
var _checks := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if not SaveGuard.validate_save_path(OS.get_environment("SNAPLAND_SAVE_PATH"), OS.get_user_data_dir()).is_empty():
		push_error("World ambience test requires a private save.")
		quit(1)
		return
	_check_tables()
	for region: String in WORLDS:
		await _check_region(region)
	await _check_plaza_birds()
	for error in _errors:
		push_error(error)
	if _errors.is_empty():
		print("PASS: world ambience profiles, stable nodes, reactive birds and reduced motion")
	print("World ambience: %d checks, %d failures" % [_checks, _errors.size()])
	quit(int(not _errors.is_empty()))


func _check_tables() -> void:
	_check(Profiles.REGIONS.size() == WORLDS.size(), "every region has an ambience profile")
	for region: String in Profiles.REGIONS:
		var profile: Dictionary = Profiles.REGIONS[region]
		_check(Profiles.particle_total(profile) <= Profiles.PARTICLE_BUDGET,
			"%s keeps %d particles within the budget" % [region, Profiles.particle_total(profile)])
		for spec: Dictionary in profile.particles:
			var look: Dictionary = Profiles.PARTICLE_KINDS.get(spec.kind, {})
			_check(not look.is_empty() and Sprites.MOTES.has(look.get("glyph", "")) and Profiles.RAMPS.has(look.get("ramp", "fade")),
				"%s particle '%s' is fully defined" % [region, spec.kind])
			_check(not (spec.get("phases", []) as Array).is_empty() and int(spec.amount) > 0, "%s particle '%s' has phases and an amount" % [region, spec.kind])
		for group: Dictionary in profile.critters:
			var kind: Dictionary = Profiles.CRITTER_KINDS.get(group.kind, {})
			_check(not kind.is_empty() and Sprites.CRITTER_ROWS.has(kind.get("sprite", group.kind)) and Critters.BEHAVIORS.has(kind.get("behavior", "")),
				"%s critter '%s' is fully defined" % [region, group.kind])
		var kinds_by_phase := {}
		for phase: String in PHASES:
			kinds_by_phase[phase] = profile.particles.filter(func(spec: Dictionary) -> bool: return (spec.phases as Array).has(phase)).map(func(spec: Dictionary) -> String: return spec.kind)
			_check(not (kinds_by_phase[phase] as Array).is_empty(), "%s has air particles at %s" % [region, phase])
	var welcome: Dictionary = Profiles.REGIONS.welcome
	_check(welcome.particles.any(func(spec: Dictionary) -> bool: return spec.kind == "firefly" and spec.phases == ["night"]),
		"fireflies belong to the Welcome night only")
	_check(float(Profiles.CLOUD_PHASE_STRENGTH.night) == 0.0 and float(Profiles.CLOUD_PHASE_STRENGTH.noon) > 0.0, "cloud shade is a daytime effect")
	var atlas := Sprites.critter_atlas()
	_check(atlas.get_width() == Sprites.CELL.x * Sprites.COLUMNS and atlas.get_height() == Sprites.CELL.y * Sprites.CRITTER_ROWS.size()
		and Sprites.critter_atlas() == atlas, "critter frames are authored once into one shared atlas")
	for kind: String in Sprites.CRITTER_FRAMES:
		for rows: Array in Sprites.CRITTER_FRAMES[kind]:
			_check(rows.size() <= Sprites.CELL.y and rows.all(func(row: String) -> bool: return row.length() <= Sprites.CELL.x),
				"%s frame fits its atlas cell" % kind)


func _check_region(region: String) -> void:
	var world: Node3D = (load(WORLDS[region]) as GDScript).new()
	root.add_child(world)
	await process_frame
	var profile: Dictionary = Profiles.REGIONS[region]
	var ambience: Node3D = world.ambience
	_check(Profiles.region_for(world) == region and world._ambience_profile() == profile, "%s resolves its own ambience profile" % region)
	_check(is_instance_valid(ambience) and ambience.get_parent() == world, "%s inherits the shared ambience layer" % region)
	if not is_instance_valid(ambience):
		world.free()
		return
	var expects_cloud := float(profile.clouds) > 0.0
	_check((ambience.cloud != null) == expects_cloud, "%s cloud shade matches its profile" % region)
	_check(ambience.critters.count == Profiles.critter_total(profile), "%s pools every profiled animal" % region)
	# Three batches at most without a renderer; emitters are added only on a GPU.
	_check(ambience.get_child_count() <= 3 + ambience.emitters.size() and ambience.emitters.size() <= profile.particles.size(),
		"%s ambience stays a handful of nodes (%d)" % [region, ambience.get_child_count()])
	_check(ambience.find_children("*", "Light3D", true, false).is_empty() and ambience.find_children("*", "CollisionObject3D", true, false).is_empty(),
		"%s ambience adds no lights or collision" % region)
	var nodes := world.find_children("*", "Node", true, false).size()
	var materials: int = world.material_cache.size()
	for cycle in range(2):
		for phase: String in PHASES:
			world.apply_settings({"reduced_motion": cycle == 0})
			world.set_time_of_day(phase)
			ambience.advance(STEP)
			if expects_cloud:
				_check(ambience.cloud.visible == (phase != "night") and is_equal_approx(ambience.cloud_strength(), float(profile.clouds) * float(Profiles.CLOUD_PHASE_STRENGTH[phase])),
					"%s cloud shade follows %s" % [region, phase])
			_check_phase_visibility(region, ambience.critters, phase)
	world.apply_settings({"reduced_motion": false})
	world.set_time_of_day("noon")
	_check(world.find_children("*", "Node", true, false).size() == nodes and world.material_cache.size() == materials,
		"%s phase and settings toggles add no nodes or materials" % region)
	world.free()
	await process_frame


func _check_phase_visibility(region: String, critters: Critters, phase: String) -> void:
	for flock in critters.flocks:
		var shown := 0
		for index in range(flock.first, flock.first + flock.count):
			shown += int(critters.visible_scale[index] > 0.0)
		var expected: int = flock.count if flock.phases.has(phase) else 0
		_check(shown == expected, "%s %s are %s at %s" % [region, flock.kind, "out" if expected > 0 else "hidden", phase])


func _check_plaza_birds() -> void:
	var world: Node3D = (load(WORLDS.welcome) as GDScript).new()
	root.add_child(world)
	await process_frame
	var ambience: Node3D = world.ambience
	ambience.set_process(false)
	world.set_physics_process(false)
	var critters: Critters = ambience.critters
	var flock: Critters.Flock = critters.flocks[0]
	_check(flock.kind == "pigeon" and flock.behavior == Critters.Behavior.GROUND_BIRD and flock.count >= 4, "the plaza keeps a pigeon flock")
	_check(absf(flock.ground - world.ground_surface_y(flock.center)) < 0.001 and flock.ground > 0.1, "pigeons stand on the plaza paving")

	world.player.global_position = FAR
	_simulate(ambience, 6.0)
	_check(critters.flock_is_home(0) and _airborne(critters, flock) == 0 and _inside_home(critters, flock), "undisturbed pigeons hop and peck inside their patch")

	var gull := _first_of(critters, Critters.Behavior.GLIDER)
	var gull_before := critters.position[gull.first]
	_simulate(ambience, 1.0)
	_check(critters.position[gull.first].distance_to(gull_before) > 0.5 and critters.position[gull.first].y - critters.ground[gull.first] > 2.0
		and critters.shadow_width[gull.first] > 0.0, "gulls glide above the dock with a ground shadow")

	# Walking into the flock startles it.
	world.player.global_position = flock.center + Vector3(0.4, 0.3, 0.2)
	_simulate(ambience, 0.6)
	_check(not critters.flock_is_home(0), "pigeons take off when the player walks into them")
	_simulate(ambience, 1.0)
	_check(_airborne(critters, flock) == flock.count, "the whole flock is in the air a moment later")
	var fled := true
	for index in range(flock.first, flock.first + flock.count):
		fled = fled and Vector2(critters.position[index].x - flock.center.x, critters.position[index].z - flock.center.z).length() > 2.0
	_check(fled, "fleeing pigeons move away from the player")
	_simulate(ambience, 8.0)
	var gone := true
	for index in range(flock.first, flock.first + flock.count):
		gone = gone and critters.state[index] == Critters.State.AWAY and critters.visible_scale[index] == 0.0
	_check(gone, "pigeons stay away while the player stands in their patch")

	# Once the player leaves, they come back and land.
	world.player.global_position = FAR
	_simulate(ambience, 14.0)
	_check(critters.flock_is_home(0) and _airborne(critters, flock) == 0 and _inside_home(critters, flock), "pigeons return and land after the player leaves")
	var all_visible := true
	for index in range(flock.first, flock.first + flock.count):
		all_visible = all_visible and is_equal_approx(critters.visible_scale[index], 1.0)
	_check(all_visible, "returned pigeons are fully visible")

	# Reduced motion: nothing darts, drifts or glides.
	world.player.global_position = flock.center + Vector3(0.3, 0.3, 0.0)
	_simulate(ambience, 1.2)
	_check(_airborne(critters, flock) > 0, "pigeons are mid-flight before motion is reduced")
	world.apply_settings({"reduced_motion": true})
	_check(critters.flock_is_home(0) and _airborne(critters, flock) == 0 and _inside_home(critters, flock), "reduced motion perches every bird at once")
	var held := critters.position.duplicate()
	var held_frames := critters.frame.duplicate()
	var drift: Variant = ambience.cloud.material_override.get_shader_parameter("drift")
	_simulate(ambience, 4.0)
	_check(critters.position == held and critters.frame == held_frames, "no animal moves under reduced motion, even beside the player")
	_check(ambience.cloud.material_override.get_shader_parameter("drift") == drift and ambience.cloud.visible, "cloud shade holds still under reduced motion")
	world.apply_settings({"reduced_motion": false})
	_simulate(ambience, 1.5)
	_check(not critters.flock_is_home(0), "pigeons react again once motion is restored")
	_check(ambience.cloud.material_override.get_shader_parameter("drift") != drift, "cloud shade drifts again once motion is restored")
	world.free()
	await process_frame


func _simulate(ambience: Node3D, seconds: float) -> void:
	for step in range(int(round(seconds / STEP))):
		ambience.advance(STEP)


func _airborne(critters: Critters, flock: Critters.Flock) -> int:
	var total := 0
	for index in range(flock.first, flock.first + flock.count):
		total += int(critters.position[index].y > flock.ground + 0.2)
	return total


func _inside_home(critters: Critters, flock: Critters.Flock) -> bool:
	for index in range(flock.first, flock.first + flock.count):
		var offset := critters.position[index] - flock.center
		if Vector2(offset.x, offset.z).length() > flock.spread + 0.01 or offset.y < -0.001 or offset.y > Critters.HOP_HEIGHT + 0.001:
			return false
	return true


func _first_of(critters: Critters, behavior: int) -> Critters.Flock:
	for flock in critters.flocks:
		if flock.behavior == behavior:
			return flock
	return null


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_errors.append("FAIL: " + message)
