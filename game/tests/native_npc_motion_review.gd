extends Node3D
## Scripted, human-review-only comparison of measured NPC gait sources.
## This fixture writes evidence but does not claim native gameplay acceptance.

const NpcActivityScript = preload("res://game/world/npc_activity.gd")
const MotionScript = preload("res://game/world/npc_walk_motion.gd")
const ROLES: Array[String] = ["ticket", "imp", "announcer"]
const STARTS := {"ticket": -2.55, "imp": 0.0, "announcer": 2.55}
const NORMAL_DIRECTIONS := {"ticket": 1.0, "imp": 1.0, "announcer": 1.0}
const SLOW_DIRECTIONS := {"ticket": -1.0, "imp": -1.0, "announcer": -1.0}
const INITIAL_FRONT_PIXEL_SIZE := 2.4 / 420.0
const SAVE_DIR := "res://.review/npc-motion-native"

var _controller: Node
var _camera: Camera3D
var _actors: Dictionary = {}
var _stage_speeds: Dictionary = {}
var _failure := ""
var _report: Dictionary = {
	"scripted_fixture": true,
	"human_played": false,
	"native_visual_acceptance": "pending parent review",
	"captures": [],
	"roles": {},
}


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		_fail("native NPC motion review requires a GPU-backed display")
		return
	var save_path := OS.get_environment("SNAPLAND_SAVE_PATH").strip_edges()
	if save_path.is_empty() or not save_path.is_absolute_path() or not save_path.to_lower().contains(".review"):
		_fail("native NPC motion review requires an absolute isolated .review SNAPLAND_SAVE_PATH")
		return
	get_window().size = Vector2i(1280, 720)
	_build_scene()
	await get_tree().process_frame
	_camera = _camera_node()
	_controller = NpcActivityScript.new()
	_controller.name = "NpcActivity"
	add_child(_controller)
	for role in ROLES:
		if not _build_actor(role):
			_fail("could not build measured review actor: " + role)
			return
	_controller.finish_registration()
	_controller.configure_motion(_camera, Callable(self, "_ground_height"), true)
	if _controller._player != null:
		_controller._player.stop()
	_controller.set_process(false)
	var unsupported: Array[String] = []
	for role in ROLES:
		var index := _record_index(role)
		if index < 0 or _controller._records[index].get("motion") == null:
			unsupported.append(role)
			continue
		var motion = _controller._records[index].motion
		if not motion.supported:
			unsupported.append(role)
			continue
		motion.rig.visible = false
		var measurements: Dictionary = motion.source_provider.measurements_for(role)
		_report.roles[role] = {
			"supported_views": motion.rig.source_records.keys(),
			"target_body_height_px": int(measurements.get("target_body_height_px", 0)),
			"measured_front_opaque_height_px": motion.front_body_height_px,
			"calibrated_front_sprite_pixel_size": motion.calibrated_sprite_pixel_size,
			"calibrated_front_body_world_height": motion.calibrated_sprite_pixel_size * float(motion.front_body_height_px),
			"leg_length_scale": float(motion.rig.leg_length_scale),
			"source_atlas": String(measurements.get("source_atlas", "")),
			"actor_root_start": str(motion.actor_root.global_position),
		}
	if not unsupported.is_empty():
		_fail("measured gait unavailable for role(s): " + ", ".join(unsupported))
		return
	_update_caption("IDLE FRONT SPRITES  |  3-second authored rest baseline  |  ticket  ·  imp  ·  announcer")
	await _settle(3.0)
	if not await _capture("npc-motion-idle-front.png", "idle-front", 0.0, {}):
		return
	await _walk_stage("npc-motion-normal-walk.png", "normal-walk", 2.0, 0.48, NORMAL_DIRECTIONS, 4.0, 0.16)
	if not _failure.is_empty(): return
	await _settle(1.0)
	if not _all_sprites_restored():
		_fail("normal walk did not settle back to the original front sprites")
		return
	await _walk_stage("npc-motion-slow-walk.png", "slow-walk", 0.55, 0.28, SLOW_DIRECTIONS, 4.0, 0.24)
	if not _failure.is_empty(): return
	await _settle(3.0)
	if not _all_sprites_restored():
		_fail("slow walk did not settle back to the original front sprites")
		return
	_report["post_walk_idle_verified"] = true
	_report["post_walk_idle_duration_seconds"] = 3.0
	_report["post_walk_sprite_visibility"] = {"ticket": _actors.ticket.sprite.visible, "imp": _actors.imp.sprite.visible, "announcer": _actors.announcer.sprite.visible}
	_report["godot_version"] = Engine.get_version_info()
	_report["viewport_px"] = str(get_viewport().get_visible_rect().size)
	_report["source_roles"] = ROLES
	_report["notes"] = "Scripted source/renderer comparison only. Parent must inspect full-body framing, visible scale continuity, feet and anatomy in the PNGs."
	_write_report()
	print("CAPTURED: three-role measured NPC motion review evidence; visual acceptance pending parent review")
	get_tree().quit(0)


func _build_scene() -> void:
	var environment := WorldEnvironment.new()
	var world_environment := Environment.new()
	world_environment.background_mode = Environment.BG_COLOR
	world_environment.background_color = Color("#24333a")
	world_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world_environment.ambient_light_color = Color("#aeb9bf")
	world_environment.ambient_light_energy = 0.72
	environment.environment = world_environment
	add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-43.0, -24.0, 0.0)
	light.light_energy = 1.25
	add_child(light)
	var floor := MeshInstance3D.new()
	var floor_mesh := BoxMesh.new()
	floor_mesh.size = Vector3(12.0, 0.12, 5.2)
	floor.mesh = floor_mesh
	floor.position = Vector3(0.0, -0.06, 0.0)
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color("#69766f")
	floor_material.roughness = 0.96
	floor.material_override = floor_material
	add_child(floor)
	var floor_edge := MeshInstance3D.new()
	var edge_mesh := BoxMesh.new()
	edge_mesh.size = Vector3(12.0, 0.08, 0.08)
	floor_edge.mesh = edge_mesh
	floor_edge.position = Vector3(0.0, 0.01, -2.1)
	var edge_material := StandardMaterial3D.new()
	edge_material.albedo_color = Color("#c5b997")
	floor_edge.material_override = edge_material
	add_child(floor_edge)
	var camera := Camera3D.new()
	camera.name = "ReviewCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 6.25
	camera.position = Vector3(0.0, 3.45, 10.0)
	add_child(camera)
	# look_at() needs an in-tree Node3D so it can resolve global transform.
	camera.look_at(Vector3(0.0, 1.2, 0.0), Vector3.UP)
	var canvas := CanvasLayer.new()
	canvas.name = "EvidenceOverlay"
	add_child(canvas)
	var label := Label.new()
	label.name = "StageCaption"
	label.position = Vector2(32.0, 24.0)
	label.size = Vector2(1210.0, 50.0)
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color("#f6f0df"))
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.85))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	canvas.add_child(label)


func _build_actor(role: String) -> bool:
	var actor := Node3D.new()
	actor.name = role.capitalize() + "ActivityRoot"
	actor.position = Vector3(float(STARTS[role]), 0.0, 0.0)
	add_child(actor)
	var marker := MeshInstance3D.new()
	var marker_mesh := CylinderMesh.new()
	marker_mesh.top_radius = 0.35
	marker_mesh.bottom_radius = 0.35
	marker_mesh.height = 0.018
	marker.mesh = marker_mesh
	marker.position.y = 0.012
	var marker_material := StandardMaterial3D.new()
	marker_material.albedo_color = Color("#a69a7f")
	marker_material.roughness = 1.0
	marker.material_override = marker_material
	actor.add_child(marker)
	var ground_anchor := Node3D.new()
	ground_anchor.name = "BillboardGroundAnchor"
	actor.add_child(ground_anchor)
	var sprite := Sprite3D.new()
	var frames := NpcActivityScript.load_action_frames(role)
	if frames.size() != 4:
		return false
	sprite.texture = frames[0]
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.pixel_size = INITIAL_FRONT_PIXEL_SIZE
	sprite.position.y = INITIAL_FRONT_PIXEL_SIZE * (float(NpcActivityScript.ACTION_FEET_ROW) - float(NpcActivityScript.ACTION_CANVAS_SIZE.y) * 0.5)
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ground_anchor.add_child(sprite)
	var feet_from_center := (float(NpcActivityScript.ACTION_FEET_ROW) - float(NpcActivityScript.ACTION_CANVAS_SIZE.y) * 0.5) * INITIAL_FRONT_PIXEL_SIZE
	ground_anchor.position.y = feet_from_center * _camera.global_basis.y.y - sprite.position.y
	var name_label := Label3D.new()
	name_label.text = {"ticket": "TICKET GUIDE", "imp": "TIDE IMP", "announcer": "ANNOUNCER"}[role]
	name_label.position.y = 2.82
	name_label.font_size = 28
	name_label.pixel_size = 0.008
	name_label.modulate = Color("#fff3d0")
	name_label.outline_size = 8
	name_label.outline_modulate = Color("#17252a")
	name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	actor.add_child(name_label)
	var point := {"position": actor.global_position}
	if not _controller.register_actor(sprite, role, frames, actor, point, float(ROLES.find(role))):
		return false
	_actors[role] = {"root": actor, "anchor": ground_anchor, "sprite": sprite, "point": point}
	return true


func _walk_stage(file_name: String, stage: String, peak_speed: float, amplitude: float, directions: Dictionary, total_time: float, capture_after: float) -> void:
	var elapsed := 0.0
	var captured := false
	var angular_speed := peak_speed / amplitude
	var route_origins: Dictionary = {}
	var previous_positions: Dictionary = {}
	var observed_peak_speed := 0.0
	for role in ROLES:
		var actor: Dictionary = _actors[role]
		var root_node := actor.root as Node3D
		route_origins[role] = root_node.position.x
		previous_positions[role] = root_node.position.x
	_update_caption("%s  |  peak %.2f m/s  |  ticket %s   imp %s   announcer %s" % [stage.to_upper(), peak_speed, _arrow(float(directions.ticket)), _arrow(float(directions.imp)), _arrow(float(directions.announcer))])
	for role in ROLES:
		var index := _record_index(role)
		if index >= 0:
			_controller._play_actor_action(index, "idle", "front", true)
	while elapsed < total_time:
		var delta := minf(get_process_delta_time(), total_time - elapsed)
		for role in ROLES:
			var actor: Dictionary = _actors[role]
			var root_node := actor.root as Node3D
			# Smooth periodic root path stays inside a one-metre lane and reverses
			# continuously at each end; the gait sees only actual per-frame delta.
			root_node.position.x = float(route_origins[role]) + float(directions[role]) * amplitude * sin(angular_speed * elapsed)
			var actual_speed := absf(root_node.position.x - float(previous_positions[role])) / maxf(delta, 0.000001)
			observed_peak_speed = maxf(observed_peak_speed, actual_speed)
			_stage_speeds[role] = actual_speed
			previous_positions[role] = root_node.position.x
			var index := _record_index(role)
			var record: Dictionary = _controller._records[index]
			var motion = record.get("motion")
			motion.update(delta, false, false)
		elapsed += delta
		if not captured and elapsed >= capture_after:
			captured = true
			if not await _capture(file_name, stage, peak_speed, directions):
				return
		await get_tree().process_frame
	for role in ROLES:
		var index := _record_index(role)
		if index >= 0:
			_controller._play_actor_action(index, "idle", "front", true)
	if not captured:
		_fail("motion capture time was outside the scripted walk interval: " + stage)
		return
	var stage_record := {"stage": stage, "requested_peak_speed_mps": peak_speed, "observed_root_speed_mps": observed_peak_speed, "duration_seconds": elapsed, "continuous_sine_route": true}
	_report["stage_metrics"] = _report.get("stage_metrics", [])
	_report.stage_metrics.append(stage_record)
	_write_report()


func _settle(duration: float) -> void:
	var elapsed := 0.0
	while elapsed < duration:
		var delta := minf(get_process_delta_time(), duration - elapsed)
		for role in ROLES:
			var motion = _controller._records[_record_index(role)].get("motion")
			motion.update(delta, false, false)
		elapsed += delta
		await get_tree().process_frame


func _capture(file_name: String, stage: String, speed: float, directions: Dictionary) -> bool:
	if not _check_stage(stage, speed, directions):
		return false
	var projected: Dictionary = {}
	for role in ROLES:
		var actor: Dictionary = _actors[role]
		var index := _record_index(role)
		var motion = _controller._records[index].motion
		var source_bounds := _project_sprite_alpha_bounds(actor.sprite as Sprite3D)
		if not _bounds_have_padding(source_bounds):
			_fail("%s source front sprite is clipped or lacks 12px head/foot padding at %s: %s" % [role, stage, str(source_bounds)])
			return false
		var rig_bounds: Array[Rect2] = []
		if motion.rig.visible:
			var visible_parts: Array = motion.rig.find_children("*", "VisualInstance3D", true, false)
			for part in visible_parts:
				var visual := part as VisualInstance3D
				if not is_instance_valid(visual) or not visual.is_visible_in_tree(): continue
				var part_bounds := _project_visual_bounds(visual)
				if not _bounds_have_padding(part_bounds):
					_fail("%s rig part %s is clipped or lacks 12px head/foot padding at %s: %s" % [role, visual.name, stage, str(part_bounds)])
					return false
				rig_bounds.append(part_bounds)
		var rig_union := _union_bounds(rig_bounds)
		if motion.rig.visible and not _bounds_have_padding(rig_union):
			_fail("%s full measured rig is clipped at %s: %s" % [role, stage, str(rig_union)])
			return false
		projected[role] = {"front_sprite_source_bounds_px": str(source_bounds), "measured_rig_part_bounds_px": rig_bounds.map(func(rect: Rect2) -> String: return str(rect)), "measured_rig_bounds_px": str(rig_union)}
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path(SAVE_DIR.path_join(file_name))
	var error := DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if error != OK and error != ERR_ALREADY_EXISTS:
		_fail("could not create review output folder: " + str(error))
		return false
	var image := get_viewport().get_texture().get_image()
	if image.get_size() != Vector2i(1280, 720):
		_fail("review viewport is not 1280x720: " + str(image.get_size()))
		return false
	if image.save_png(path) != OK:
		_fail("could not save review image: " + path)
		return false
	var capture := {
		"file": SAVE_DIR.path_join(file_name),
		"stage": stage,
		"engine_frame": Engine.get_process_frames(),
		"timestamp_ms": Time.get_ticks_msec(),
			"target_peak_speed_mps": speed,
		"roles": {},
	}
	for role in ROLES:
		var actor: Dictionary = _actors[role]
		var index := _record_index(role)
		var motion = _controller._records[index].motion
		capture.roles[role] = {
			"root_world": str(motion.actor_root.global_position),
			"ground_y": float(_ground_height(Vector2(motion.actor_root.global_position.x, motion.actor_root.global_position.z))),
			"source_direction": motion.rig.direction,
			"actual_root_speed_mps": float(_stage_speeds.get(role, 0.0)),
			"rig_visible": motion.rig.visible,
			"front_sprite_visible": actor.sprite.visible,
			"front_sprite_pixel_size": actor.sprite.pixel_size,
			"front_sprite_position": str(actor.sprite.position),
			"projected_bounds": projected[role],
		}
	_report.captures.append(capture)
	_write_report()
	return true


func _check_stage(stage: String, speed: float, directions: Dictionary) -> bool:
	for role in ROLES:
		var actor: Dictionary = _actors[role]
		var index := _record_index(role)
		var motion = _controller._records[index].motion
		if stage == "idle-front":
			if not actor.sprite.visible or motion.rig.visible:
				_fail("baseline must show the authored front sprite for " + role)
				return false
		else:
			if not motion.active or not motion.rig.visible or actor.sprite.visible:
				_fail("%s does not show only the measured gait rig for %s at %.2f m/s" % [stage, role, speed])
				return false
			var expected := "right" if float(directions[role]) > 0.0 else "left"
			if motion.rig.direction != expected:
				_fail("%s view mismatch for %s: expected %s, got %s" % [stage, role, expected, motion.rig.direction])
				return false
		if not is_equal_approx(float(_ground_height(Vector2(motion.actor_root.global_position.x, motion.actor_root.global_position.z))), 0.0):
			_fail("actor is off the fixture ground plane: " + role)
			return false
	return true


func _all_sprites_restored() -> bool:
	for role in ROLES:
		var actor: Dictionary = _actors[role]
		var index := _record_index(role)
		if not actor.sprite.visible or _controller._records[index].motion.rig.visible:
			return false
	return true


func _project_sprite_alpha_bounds(sprite: Sprite3D) -> Rect2:
	if not is_instance_valid(sprite) or sprite.texture == null: return Rect2()
	var image := sprite.texture.get_image()
	if image == null or image.is_empty(): return Rect2()
	var used := image.get_used_rect()
	if used.size.x <= 0 or used.size.y <= 0: return Rect2()
	var local_aabb: AABB = sprite.get_aabb()
	var minimum := Vector2(INF, INF)
	var maximum := Vector2(-INF, -INF)
	var plane_basis := _camera.global_basis if sprite.billboard != BaseMaterial3D.BILLBOARD_DISABLED else sprite.global_basis
	var start_x := float(used.position.x) / float(image.get_width())
	var end_x := float(used.end.x) / float(image.get_width())
	var start_y := float(used.position.y) / float(image.get_height())
	var end_y := float(used.end.y) / float(image.get_height())
	for x_ratio in [start_x, end_x]:
		for y_ratio in [start_y, end_y]:
			var local_x: float = local_aabb.position.x + float(x_ratio) * local_aabb.size.x
			var local_y: float = local_aabb.position.y + (1.0 - float(y_ratio)) * local_aabb.size.y
			var world_point := sprite.global_position + plane_basis * Vector3(local_x, local_y, 0.0)
			var screen := _camera.unproject_position(world_point)
			minimum.x = minf(minimum.x, screen.x); minimum.y = minf(minimum.y, screen.y)
			maximum.x = maxf(maximum.x, screen.x); maximum.y = maxf(maximum.y, screen.y)
	return Rect2(minimum, maximum - minimum)


func _project_visual_bounds(visual: VisualInstance3D) -> Rect2:
	var local_aabb: AABB = visual.get_aabb()
	var minimum := Vector2(INF, INF)
	var maximum := Vector2(-INF, -INF)
	for corner in range(8):
		var local_point := local_aabb.position + Vector3(
			local_aabb.size.x if corner & 1 else 0.0,
			local_aabb.size.y if corner & 2 else 0.0,
			local_aabb.size.z if corner & 4 else 0.0
		)
		var screen := _camera.unproject_position(visual.global_transform * local_point)
		minimum.x = minf(minimum.x, screen.x); minimum.y = minf(minimum.y, screen.y)
		maximum.x = maxf(maximum.x, screen.x); maximum.y = maxf(maximum.y, screen.y)
	return Rect2(minimum, maximum - minimum)


func _bounds_have_padding(bounds: Rect2) -> bool:
	var viewport := get_viewport().get_visible_rect()
	return bounds.size.x > 0.0 and bounds.size.y > 0.0 and bounds.position.x >= 12.0 and bounds.position.y >= 12.0 and bounds.end.x <= viewport.size.x - 12.0 and bounds.end.y <= viewport.size.y - 12.0


func _union_bounds(bounds: Array[Rect2]) -> Rect2:
	if bounds.is_empty(): return Rect2()
	var union := bounds[0]
	for index in range(1, bounds.size()): union = union.merge(bounds[index])
	return union


func _record_index(role: String) -> int:
	for index in range(_controller._records.size()):
		if String(_controller._records[index].role) == role:
			return index
	return -1


func _update_caption(text: String) -> void:
	var label := get_node_or_null("EvidenceOverlay/StageCaption") as Label
	if is_instance_valid(label):
		label.text = text


func _arrow(direction: float) -> String:
	return "→" if direction > 0.0 else "←"


func _camera_node() -> Camera3D:
	return get_node("ReviewCamera") as Camera3D


func _ground_height(_point: Vector2) -> float:
	return 0.0


func _write_report() -> void:
	var path := ProjectSettings.globalize_path(SAVE_DIR.path_join("npc-motion-review-report.json"))
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(_report, "\t"))


func _fail(message: String) -> void:
	_failure = message
	_report["failure"] = message
	_write_report()
	push_error("NPC motion review fixture failed: " + message)
	get_tree().quit(1)
