extends SceneTree
## Deterministic real-world state regression; native rendering is checked separately.
const World := preload("res://game/world/park_world.gd")
const Renderer := preload("res://game/world/avatar_renderer.gd")
var failures: Array[String] = []
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	if not OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path(): quit(2); return
	var world := World.new()
	root.add_child(world)
	await process_frame
	world.set_physics_process(false)
	world.set_process(false)
	world.facing = "left"
	world.avatar_is_walking = true
	world.walk_distance_phase = world.WALK_STRIDE_DISTANCE * 0.625
	world._refresh_avatar_texture(5)
	var phase: float = world.walk_distance_phase
	var look := Renderer.DEFAULT_APPEARANCE.duplicate()
	var clothes := {"outfit": "outfit-coral", "hat": "hat-sailor"}
	world.set_avatar_look(look, clothes)
	_check(world.last_avatar_frame == 5 and world.walk_distance_phase == phase, "outfit swap must retain current step, not jump to cel zero")
	world.set_avatar_hair_motion_enabled(false)
	_check(world.last_avatar_frame == 5 and world.walk_distance_phase == phase, "hair off must retain current step")
	world.set_avatar_hair_motion_enabled(true)
	_check(world.last_avatar_frame == 5 and world.walk_distance_phase == phase, "hair on must retain current step")
	world.apply_settings({"reduced_motion": true})
	_check(world.last_avatar_frame == 5 and world.walk_distance_phase == phase, "reduced motion must retain the actual walk phase")
	world.apply_settings({"reduced_motion": false})
	_check(world.last_avatar_frame == 5 and world.walk_distance_phase == phase, "restoring motion must retain actual walk phase")
	if DisplayServer.get_name() == "headless":
		var expected: Image = world.avatar_renderer.texture(look, clothes, "left", 5, "walk").get_image()
		_check(world.avatar.texture.get_image().get_data() == expected.get_data(), "no graphics device must use complete original cel five")
		_check(not world.avatar_hair_rig.active, "headless source checks cannot pretend to render bones")
	world.free()
	if failures.is_empty(): print("PASS: island hair lifecycle retains live walk phase through appearance, motion and reduced-motion changes")
	else: printerr("FAIL: " + "; ".join(failures))
	quit(0 if failures.is_empty() else 1)
func _check(condition: bool, label: String) -> void:
	if not condition: failures.append(label)
