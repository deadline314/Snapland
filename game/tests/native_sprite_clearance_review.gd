extends "res://game/tests/native_npc_review.gd"

const AvatarRendererScript := preload("res://game/world/avatar_renderer.gd")
const NpcActivityScript := preload("res://game/world/npc_activity.gd")
const ParkWorldScript := preload("res://game/world/park_world.gd")
const NPC_CAMERA_PITCHES := [deg_to_rad(19.86), deg_to_rad(27.1), deg_to_rad(8.0)]
const NPC_FRAME_NAMES := ["first", "second", "third", "fourth"]
const HERO_DIRECTIONS := ["front", "front_right", "right", "back_right", "back", "back_left", "left", "front_left"]
const HERO_ACTIONS := ["photograph", "wave", "celebrate"]
const CLEARANCE_CAMERA_DISTANCE := 6.5
const CLEARANCE_CAMERA_SIZE := 4.8
const CONTACT_EPSILON := 0.001

var _npc_frame_records: Dictionary = {}
var _npc_material_baselines: Dictionary = {}
var _hero_material: ShaderMaterial
var _hero_material_baseline: Dictionary = {}
var _watchdog: Timer

func _run() -> void:
	_watchdog = Timer.new()
	_watchdog.name = "NativeSpriteClearanceWatchdog"
	_watchdog.one_shot = true
	_watchdog.wait_time = 180.0
	_watchdog.timeout.connect(_on_watchdog_timeout)
	add_child(_watchdog)
	_watchdog.start()
	if OS.get_environment("SNAPLAND_SAVE_PATH").is_empty() or DisplayServer.get_name() == "headless":
		push_error("Native sprite clearance review requires GPU and isolated SNAPLAND_SAVE_PATH")
		get_tree().quit(1)
		return
	progress = get_tree().root.get_node_or_null("Progress")
	if progress == null:
		await _fail("Native sprite clearance review has no Progress autoload")
		return
	progress.reset_progress()
	progress.intro_seen = true
	progress.settings["reduced_motion"] = false
	main = _instantiate_main()
	if main == null:
		get_tree().quit(1)
		return
	get_tree().root.add_child(main)
	await _frames(8)
	if main.world.npc_activity == null or int(main.world.npc_activity.statistics().get("registration_count", 0)) != 3:
		await _fail("Native sprite clearance fixture does not have three registered NPCs")
		return
	for record: Dictionary in main.world.npc_activity._records:
		if bool(record.get("active", false)):
			_npc_frame_records[String(record.role)] = record
	for role in NpcRoles:
		if not _npc_frame_records.has(role):
			await _fail("Native sprite clearance fixture is missing NPC role " + role)
			return
		var sprite := _sprite_for_role(role)
		if sprite == null:
			await _fail("Native sprite clearance fixture has no live Sprite3D for NPC role " + role)
			return
		var material := sprite.material_override as ShaderMaterial
		if material == null:
			await _fail("Native sprite clearance fixture has no ordinary ShaderMaterial for NPC role " + role)
			return
		_npc_material_baselines[role] = _capture_material_state(material)
	# Hold the world and activity player steady. These are explicit camera/pose review fixtures.
	main.world.set_physics_process(false)
	main.world.player.position = Vector3(15, 0.4, 24)
	main.world.set_time_of_day("noon")
	main.world.npc_activity.set_activity_paused(true)
	if not await _review_npc_frames(): return
	if not await _review_reduced_motion_npcs(): return
	if not await _review_avatar_poses(): return
	print("PASS: native sprite clearance captures all three NPCs across four authored frames and three camera pitches, plus the player's eight idle directions and walk/photo/wave/celebrate poses. All views use explicit review fixtures, not gameplay evidence.")
	_watchdog.stop()
	await main._quit_game()

func _on_watchdog_timeout() -> void:
	push_error("Native sprite clearance review watchdog timed out; terminating the review process")
	if is_instance_valid(main) and is_instance_valid(main.audio):
		main.audio.shutdown()
	get_tree().quit(1)

func _sprite_for_role(role: String) -> Sprite3D:
	var record: Dictionary = _npc_frame_records.get(role, {})
	var target: WeakRef = record.get("target") as WeakRef
	return target.get_ref() as Sprite3D if target != null else null

func _activity_root_for_role(role: String) -> Node3D:
	var record: Dictionary = _npc_frame_records.get(role, {})
	var root_ref: WeakRef = record.get("anchor") as WeakRef
	return root_ref.get_ref() as Node3D if root_ref != null else null

func _review_npc_frames() -> bool:
	for role in NpcRoles:
		var sprite := _sprite_for_role(role)
		var activity_root := _activity_root_for_role(role)
		if sprite == null or activity_root == null:
			await _fail("Native sprite clearance fixture lost the live sprite/root for NPC role " + role)
			return false
		var anchor := sprite.get_parent() as Node3D
		var frames: Array = _npc_frame_records[role].frames
		if frames.size() != 4:
			await _fail("NPC role %s does not have four authored action frames" % role)
			return false
		if sprite.get_parent() == null or sprite.get_parent().name != "BillboardGroundAnchor" or sprite.get_parent().get_parent() != activity_root:
			await _fail("NPC role %s lost its independent ground anchor" % role)
			return false
		var baseline_position := sprite.position
		var baseline_pixel_size := sprite.pixel_size
		var baseline_material: ShaderMaterial = sprite.material_override as ShaderMaterial
		if not await _check_normal_depth(sprite, baseline_material, role): return false
		for frame_index in range(frames.size()):
			var frame := frames[frame_index] as Texture2D
			if frame == null:
				await _fail("NPC role %s authored frame %d is missing" % [role, frame_index])
				return false
			var pitch: float = NPC_CAMERA_PITCHES[frame_index % NPC_CAMERA_PITCHES.size()]
			var target := activity_root.global_position + Vector3(0, 1.28, 0)
			_position_camera(target, pitch)
			main.world._update_sprite_grounding()
			sprite.texture = frame
			baseline_material.set_shader_parameter("texture_albedo", frame)
			await RenderingServer.frame_post_draw
			if sprite.texture != frame or not _texture_synced(sprite):
				await _fail("NPC role %s frame %d is not synchronized to its normal full-canvas shader UVs" % [role, frame_index])
				return false
			if sprite.material_override != baseline_material or sprite.position != baseline_position or not is_equal_approx(sprite.pixel_size, baseline_pixel_size):
				await _fail("NPC role %s frame %d changed its Sprite3D/material baseline" % [role, frame_index])
				return false
			if not _material_state_unchanged(baseline_material, _npc_material_baselines[role], frame):
				await _fail("NPC role %s frame %d altered living-sprite depth or motion material settings" % [role, frame_index])
				return false
			if not await _check_visible_sprite_and_contact(sprite, frame, anchor, activity_root, NpcActivityScript.ACTION_FEET_ROW, NpcActivityScript.ACTION_CANVAS_SIZE.y, "NPC %s frame %d" % [role, frame_index]):
				return false
			var suffix: String = NPC_FRAME_NAMES[frame_index]
			if not main._capture("pm/Snapland-art/images/ART-15-sprite-clearance-npc-%s-%s.png" % [role, suffix]):
				await _fail("Could not save native NPC clearance capture: %s/%s" % [role, suffix])
				return false
	return true

func _review_reduced_motion_npcs() -> bool:
	var expected_states: Dictionary = {}
	for role in NpcRoles:
		var sprite := _sprite_for_role(role)
		if sprite == null:
			await _fail("Reduced-motion NPC fixture lost its Sprite3D: " + role)
			return false
		var record: Dictionary = _npc_frame_records[role]
		var material := sprite.material_override as ShaderMaterial
		if material == null:
			await _fail("Reduced-motion NPC fixture has no live ShaderMaterial: " + role)
			return false
		expected_states[role] = {
			"texture": record.baseline_texture,
			"shader_texture": record.baseline_shader_texture,
			"shader_uv_rect": record.baseline_shader_uv_rect,
		}
	main.world.apply_settings({"reduced_motion": true})
	await RenderingServer.frame_post_draw
	if not bool(main.world.npc_activity.statistics().get("reduced_motion", false)):
		await _fail("World did not enable reduced motion for the NPC clearance fixture")
		return false
	for role in NpcRoles:
		var sprite := _sprite_for_role(role)
		var activity_root := _activity_root_for_role(role)
		var record: Dictionary = _npc_frame_records[role]
		var expected: Dictionary = expected_states[role]
		var material := sprite.material_override as ShaderMaterial
		var texture := sprite.texture as Texture2D
		if texture != expected.texture or not _texture_synced(sprite):
			await _fail("Reduced-motion NPC %s did not restore a synchronized canonical rest frame" % role)
			return false
		if texture.get_width() != NpcActivityScript.ACTION_CANVAS_SIZE.x or texture.get_height() != NpcActivityScript.ACTION_CANVAS_SIZE.y:
			await _fail("Reduced-motion NPC %s rest texture is not the full canonical %s canvas" % [role, NpcActivityScript.ACTION_CANVAS_SIZE])
			return false
		var image := texture.get_image()
		var visible_rect := _visible_alpha_bounds(image)
		if image.get_format() != Image.FORMAT_RGBA8 or visible_rect.end.y - 1 != NpcActivityScript.ACTION_FEET_ROW:
			await _fail("Reduced-motion NPC %s rest texture is not RGBA8 with its lowest opaque foot pixel on row %d" % [role, NpcActivityScript.ACTION_FEET_ROW])
			return false
		if not await _check_normal_depth(sprite, material, "reduced-motion NPC %s" % role): return false
		var anchor := sprite.get_parent() as Node3D
		var target := activity_root.global_position + Vector3(0, 1.28, 0)
		_position_camera(target, deg_to_rad(27.1))
		main.world._update_sprite_grounding()
		await RenderingServer.frame_post_draw
		if not _texture_synced(sprite) or sprite.texture != texture:
			await _fail("Reduced-motion NPC %s texture/shader changed before its full-body capture" % role)
			return false
		if not await _check_visible_sprite_and_contact(sprite, texture, anchor, activity_root, NpcActivityScript.ACTION_FEET_ROW, NpcActivityScript.ACTION_CANVAS_SIZE.y, "reduced-motion NPC %s" % role):
			return false
		if not main._capture("pm/Snapland-art/images/ART-15-sprite-clearance-npc-%s-reduced.png" % role):
			await _fail("Could not save reduced-motion NPC clearance capture: " + role)
			return false
	main.world.apply_settings({"reduced_motion": false})
	await _frames(2)
	if bool(main.world.npc_activity.statistics().get("reduced_motion", true)):
		await _fail("World did not restore normal motion after NPC clearance captures")
		return false
	for role in NpcRoles:
		var sprite := _sprite_for_role(role)
		var record: Dictionary = _npc_frame_records[role]
		var expected: Dictionary = expected_states[role]
		var material := sprite.material_override as ShaderMaterial
		if sprite.texture != expected.texture or not _texture_synced(sprite):
			await _fail("NPC %s shader texture/UV did not resynchronize after restoring normal motion" % role)
			return false
		if material == null or material.get_shader_parameter("texture_albedo") != expected.shader_texture or material.get_shader_parameter("uv_rect") != expected.shader_uv_rect:
			await _fail("NPC %s did not restore its exact registered shader texture/UV after reduced motion" % role)
			return false
		if sprite.texture != record.baseline_texture:
			await _fail("NPC %s did not restore its registered canonical texture after reduced motion" % role)
			return false
	return true

func _review_avatar_poses() -> bool:
	var world = main.world
	var avatar: Sprite3D = world.avatar
	_hero_material = avatar.material_override as ShaderMaterial
	if _hero_material == null:
		await _fail("Native sprite clearance fixture has no ordinary ShaderMaterial for the hero")
		return false
	_hero_material_baseline = _capture_material_state(_hero_material)
	if not await _check_normal_depth(avatar, _hero_material, "hero"):
		return false
	world.player.position = Vector3(0, 0.3, -24)
	world.avatar_action = ""
	world.avatar_action_remaining = 0.0
	world.avatar_is_walking = false
	world.camera.size = CLEARANCE_CAMERA_SIZE
	var hero_target: Vector3 = world.player.global_position + Vector3(0, 1.25, 0)
	_position_camera(hero_target, deg_to_rad(24.0))
	world._update_sprite_grounding()
	for direction in HERO_DIRECTIONS:
		world.facing = direction
		world.last_avatar_direction = ""
		world.last_avatar_frame = -1
		world.last_avatar_action = ""
		world._refresh_avatar_texture(0)
		await RenderingServer.frame_post_draw
		if not await _check_avatar_frame(avatar, "idle/%s" % direction): return false
		if not main._capture("pm/Snapland-art/images/ART-15-sprite-clearance-avatar-idle-%s.png" % direction):
			await _fail("Could not save native avatar idle capture for " + direction)
			return false
	var walk_direction := "front_right"
	world.facing = walk_direction
	world.avatar_is_walking = true
	var walk_frame_count := 8
	if world.avatar_renderer.has_method("walk_frame_count"):
		var renderer_frame_count := int(world.avatar_renderer.walk_frame_count(walk_direction))
		if renderer_frame_count > 0:
			walk_frame_count = renderer_frame_count
	var walk_frame := mini(walk_frame_count - 1, int(walk_frame_count / 2))
	world.last_avatar_direction = ""
	world.last_avatar_frame = -1
	world.last_avatar_action = ""
	world._refresh_avatar_texture(walk_frame)
	await RenderingServer.frame_post_draw
	if not await _check_avatar_frame(avatar, "walk/%s/%d-of-%d" % [walk_direction, walk_frame + 1, walk_frame_count]): return false
	if not main._capture("pm/Snapland-art/images/ART-15-sprite-clearance-avatar-walk-%s-%d-of-%d.png" % [walk_direction, walk_frame + 1, walk_frame_count]):
		await _fail("Could not save native avatar walk capture")
		return false
	world.avatar_is_walking = false
	world.last_avatar_action = ""
	for action in HERO_ACTIONS:
		world.play_action(action)
		await RenderingServer.frame_post_draw
		if world.last_avatar_action != action:
			await _fail("Hero action fixture did not select its requested pose: " + action)
			return false
		if not await _check_avatar_frame(avatar, action): return false
		if not main._capture("pm/Snapland-art/images/ART-15-sprite-clearance-avatar-%s.png" % action):
			await _fail("Could not save native avatar action capture for " + action)
			return false
	return true

func _check_avatar_frame(avatar: Sprite3D, pose: String) -> bool:
	if not _texture_synced(avatar):
		await _fail("Hero %s Sprite3D and shader texture/UV differ" % pose)
		return false
	if avatar.material_override != _hero_material or not _material_state_unchanged(_hero_material, _hero_material_baseline, avatar.texture):
		await _fail("Hero %s changed the live SpriteShader material or depth settings" % pose)
		return false
	if not await _check_visible_sprite_and_contact(avatar, avatar.texture, world_avatar_anchor(), main.world.player, AvatarRendererScript.FEET_BASELINE, AvatarRendererScript.CANVAS_SIZE.y, "hero %s" % pose):
		return false
	return true

func world_avatar_anchor() -> Node3D:
	return main.world.avatar_ground_anchor as Node3D

func _check_visible_sprite_and_contact(sprite: Sprite3D, texture: Texture2D, anchor: Node3D, ground_parent: Node3D, feet_row: int, canvas_height: int, description: String) -> bool:
	if not is_instance_valid(anchor) or anchor.get_parent() != ground_parent:
		await _fail("Sprite %s has no ground anchor under its actor root" % description)
		return false
	var image := texture.get_image()
	if image == null or image.is_empty():
		await _fail("Sprite review texture has no readable pixels: " + description)
		return false
	var visible_rect := _visible_alpha_bounds(image)
	if visible_rect.size.x <= 0 or visible_rect.size.y <= 0:
		await _fail("Sprite review texture has no visible pixels: " + description)
		return false
	var surface_y := ParkWorldScript._ground_surface_y(ground_parent.global_position)
	var camera_up: Vector3 = main.world.camera.global_basis.y
	var pixel_world := sprite.pixel_size
	var center := sprite.global_position
	var grounding_record: Dictionary = {}
	for record: Dictionary in main.world.sprite_ground_anchors:
		if record.get("sprite") == sprite and record.get("anchor") == anchor:
			grounding_record = record
			break
	if grounding_record.is_empty():
		await _fail("Sprite %s has no registered world grounding record" % description)
		return false
	var registered_feet_row := float(grounding_record.get("feet_row", -INF))
	var expected_grounded_feet_row := float(feet_row) + ParkWorldScript.SPRITE_FOOT_GUARD_PIXELS
	if not is_equal_approx(registered_feet_row, expected_grounded_feet_row):
		await _fail("Sprite %s source feet row %d does not match registered guarded row %.1f (expected %.1f)" % [description, feet_row, registered_feet_row, expected_grounded_feet_row])
		return false
	var authored_feet_y: float = center.y - float(feet_row - canvas_height / 2) * pixel_world * camera_up.y
	var grounded_feet_y: float = center.y - (registered_feet_row - float(canvas_height) * 0.5) * pixel_world * camera_up.y
	var expected_authored_feet_y: float = surface_y + (registered_feet_row - float(feet_row)) * pixel_world * camera_up.y
	var lowest_visible_row := visible_rect.end.y - 1
	var lowest_visible_y: float = center.y + float(canvas_height / 2 - lowest_visible_row) * pixel_world * camera_up.y
	if absf(authored_feet_y - expected_authored_feet_y) > CONTACT_EPSILON:
		await _fail("Sprite %s fixed source feet row does not retain its registered pixel guard: foot=%.4f expected=%.4f" % [description, authored_feet_y, expected_authored_feet_y])
		return false
	if absf(grounded_feet_y - surface_y) > CONTACT_EPSILON:
		await _fail("Sprite %s registered guarded contact row misses its floor: foot=%.4f floor=%.4f" % [description, grounded_feet_y, surface_y])
		return false
	if lowest_visible_y < surface_y:
		await _fail("Sprite %s lowest visible pixel center is below floor: pixel=%.4f floor=%.4f" % [description, lowest_visible_y, surface_y])
		return false
	var view := main.get_viewport().get_visible_rect()
	var billboard_right: Vector3 = main.world.camera.global_basis.x
	var corners := [
		Vector2(visible_rect.position.x, visible_rect.position.y),
		Vector2(visible_rect.end.x - 1, visible_rect.position.y),
		Vector2(visible_rect.position.x, lowest_visible_row),
		Vector2(visible_rect.end.x - 1, lowest_visible_row),
	]
	for corner: Vector2 in corners:
		var world_point: Vector3 = center + billboard_right * (float(corner.x - image.get_width() / 2) * pixel_world)
		world_point += camera_up * (float(canvas_height / 2 - corner.y) * pixel_world)
		if main.world.camera.is_position_behind(world_point) or not view.has_point(main.world.camera.unproject_position(world_point)):
			await _fail("Sprite %s opaque bounds, including its feet, are outside the camera view" % description)
			return false
	return true

func _visible_alpha_bounds(image: Image) -> Rect2i:
	var left := image.get_width()
	var top := image.get_height()
	var right := -1
	var bottom := -1
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a < 0.5:
				continue
			left = mini(left, x)
			top = mini(top, y)
			right = maxi(right, x)
			bottom = maxi(bottom, y)
	if right < left or bottom < top:
		return Rect2i()
	return Rect2i(left, top, right - left + 1, bottom - top + 1)

func _position_camera(target: Vector3, pitch: float) -> void:
	main.world.camera.size = CLEARANCE_CAMERA_SIZE
	main.world.camera.position = target + Vector3(0, tan(pitch) * CLEARANCE_CAMERA_DISTANCE, CLEARANCE_CAMERA_DISTANCE)
	main.world.camera.look_at(target, Vector3.UP)
	main.world.camera.current = true

func _check_normal_depth(sprite: Sprite3D, material: ShaderMaterial, description: String) -> bool:
	if material == null or material.shader == null or not material.shader.code.contains("depth_draw_opaque") or material.shader.code.contains("depth_test_disabled"):
		await _fail("Sprite %s is not using the ordinary opaque depth-tested living shader" % description)
		return false
	if sprite.billboard != BaseMaterial3D.BILLBOARD_ENABLED:
		await _fail("Sprite %s is not using its camera-facing billboard" % description)
		return false
	var found_depth_flag := false
	for property in sprite.get_property_list():
		if String(property.get("name", "")) == "no_depth_test":
			found_depth_flag = true
			if bool(sprite.get("no_depth_test")):
				await _fail("Sprite %s has Sprite3D depth testing disabled" % description)
				return false
	if not found_depth_flag:
		await _fail("Sprite %s does not expose its regular Sprite3D depth-test setting" % description)
		return false
	return true

func _capture_material_state(material: ShaderMaterial) -> Dictionary:
	var state := {"material": material, "shader": material.shader}
	for parameter in ["uv_rect", "motion_kind", "idle_role", "motion", "breath_rate", "breath_pixels", "gesture_pixels", "wind_strength"]:
		state[parameter] = material.get_shader_parameter(parameter)
	return state

func _material_state_unchanged(material: ShaderMaterial, baseline: Dictionary, expected_texture: Texture2D) -> bool:
	if material == null or material != baseline.get("material") or material.shader != baseline.get("shader"):
		return false
	for parameter in ["uv_rect", "motion_kind", "idle_role", "motion", "breath_rate", "breath_pixels", "gesture_pixels", "wind_strength"]:
		if material.get_shader_parameter(parameter) != baseline.get(parameter):
			return false
	return material.get_shader_parameter("texture_albedo") == expected_texture
