class_name NpcActivity
extends Node
## One scene-scoped AnimationPlayer coordinates authored sprite frames and
## bounded, ground-level idle paths for the three named NPCs.

const ANIMATION_NAME := "npc_idle_actions"
const CYCLE_SECONDS := 6.0
const WALK_FRAMES_PER_SECOND := 5.0
const IMP_FRAMES_PER_SECOND := 3.3333333
const TICKET_FRAMES_PER_SECOND := 5.0
const ANNOUNCER_ROUTE_HALF_WIDTH := 0.6
const GESTURE_PROPERTY := ":material_override:shader_parameter/gesture_pixels"
const SHADER_TEXTURE_PROPERTY := ":material_override:shader_parameter/texture_albedo"
const SHADER_UV_RECT_PROPERTY := ":material_override:shader_parameter/uv_rect"
const ROLE_NAMES := ["ticket", "imp", "announcer"]
const ACTION_REGIONS_PATH := "res://assets/characters/npc-action-regions.json"
const ACTION_CANVAS_SIZE := Vector2i(320, 460)
const ACTION_FEET_ROW := 448
const ACTION_MAX_HEIGHT := 420
const ACTION_VISIBLE_HEIGHT := 420
const ACTION_SIDE_PADDING := 2

static var _action_frame_cache: Dictionary = {}
static var _action_atlas: Texture2D
static var _action_atlas_image: Image
static var _action_region_data: Dictionary = {}
static var _action_assets_loaded := false

var _player: AnimationPlayer
var _animation: Animation
var _records: Array[Dictionary] = []
var _registered_ids: Dictionary = {}
var _by_role: Dictionary = {}
var _finished := false
var _reduced_motion := false
var _activity_paused := false


func _exit_tree() -> void:
	release()


static func load_action_frames(role: String) -> Array[Texture2D]:
	if _action_frame_cache.has(role):
		return _action_frame_cache[role]
	var empty: Array[Texture2D] = []
	if role not in ROLE_NAMES:
		push_warning("NpcActivity: cannot load authored frames for unknown role %s." % role)
		return empty
	if not _load_action_assets():
		return empty
	var regions: Array = _action_region_data.get(role, [])
	if regions.size() != 4:
		push_warning("NpcActivity: expected four authored atlas regions for %s." % role)
		return empty
	var role_anchors: Array = _action_region_data.get("anchors", {}).get(role, [])
	if not role_anchors.is_empty() and role_anchors.size() != 4:
		push_warning("NpcActivity: expected four source-cell anchors for %s." % role)
		return empty
	var cropped_frames: Array[Dictionary] = []
	var max_source_width := 0
	var max_source_height := 0
	for index in range(regions.size()):
		var values: Variant = regions[index]
		if not values is Array or values.size() != 4:
			push_warning("NpcActivity: malformed authored atlas region for %s." % role)
			return empty
		var rect := Rect2(float(values[0]), float(values[1]), float(values[2]), float(values[3]))
		if rect.position.x < 0.0 or rect.position.y < 0.0 or rect.size.x <= 0.0 or rect.size.y <= 0.0 or rect.end.x > _action_atlas.get_width() or rect.end.y > _action_atlas.get_height():
			push_warning("NpcActivity: authored atlas region for %s falls outside the source image." % role)
			return empty
		var cell := Rect2i(Vector2i(rect.position), Vector2i(rect.size))
		var source_frame := _action_atlas_image.get_region(cell)
		var used := source_frame.get_used_rect()
		if used.size.x <= 0 or used.size.y <= 0:
			push_warning("NpcActivity: authored frame %d for %s has no visible pixels." % [index, role])
			return empty
		var bounds := Rect2i(cell.position + used.position, used.size)
		var local_bounds := used
		if not role_anchors.is_empty():
			# Final regions are tight connected-component bounds at source alpha >= 128.
			bounds = cell
			local_bounds = Rect2i(Vector2i.ZERO, cell.size)
		var crop := source_frame.get_region(local_bounds)
		var anchor_x := float(cell.size.x) * 0.5 - float(bounds.position.x - cell.position.x)
		var feet_y := float(bounds.size.y - 1)
		if not role_anchors.is_empty():
			var anchor_data: Variant = role_anchors[index]
			if not anchor_data is Dictionary or not anchor_data.has("center_x") or not anchor_data.has("feet_y"):
				push_warning("NpcActivity: malformed source-cell anchor for %s." % role)
				return empty
			anchor_x = float(anchor_data["center_x"])
			feet_y = float(anchor_data["feet_y"])
		cropped_frames.append({"cell": cell, "bounds": bounds, "image": crop, "anchor_x": anchor_x, "feet_y": feet_y})
		max_source_width = maxi(max_source_width, bounds.size.x)
		max_source_height = maxi(max_source_height, bounds.size.y)
	var shared_scale := minf(float(ACTION_MAX_HEIGHT) / float(max_source_height), float(ACTION_CANVAS_SIZE.x - ACTION_SIDE_PADDING * 2) / float(max_source_width))
	var frames: Array[Texture2D] = []
	for frame_data in cropped_frames:
		var bounds: Rect2i = frame_data.bounds
		var crop: Image = frame_data.image
		var dest_width := maxi(1, roundi(float(crop.get_width()) * shared_scale))
		var dest_height := maxi(1, roundi(float(crop.get_height()) * shared_scale))
		crop.resize(dest_width, dest_height, Image.INTERPOLATE_NEAREST)
		var canvas := Image.create(ACTION_CANVAS_SIZE.x, ACTION_CANVAS_SIZE.y, false, Image.FORMAT_RGBA8)
		canvas.fill(Color.TRANSPARENT)
		# Preserve each original cell center so an outstretched arm does not make
		# the actor's head jump sideways between frames; align connected feet.
		var dest_x := roundi(float(ACTION_CANVAS_SIZE.x) * 0.5 - float(frame_data.anchor_x) * shared_scale)
		var dest_y := roundi(float(ACTION_FEET_ROW) - float(frame_data.feet_y) * shared_scale)
		canvas.blit_rect(crop, Rect2i(Vector2i.ZERO, crop.get_size()), Vector2i(dest_x, dest_y))
		frames.append(ImageTexture.create_from_image(canvas))
	_action_frame_cache[role] = frames
	return frames


func register_actor(
	target: Sprite3D,
	role: String,
	frames: Array[Texture2D] = [],
	activity_root: Node3D = null,
	interaction_point: Dictionary = {},
	seed: float = 0.0
) -> bool:
	if _finished:
		push_warning("NpcActivity: registration after finish_registration() was ignored.")
		return false
	if not is_instance_valid(target) or role not in ROLE_NAMES:
		push_warning("NpcActivity: unknown role or invalid Sprite3D target: %s" % role)
		return false
	if not frames.is_empty() and frames.size() != 4:
		push_warning("NpcActivity: authored action sequence for %s must contain four shared Texture2D frames." % role)
		return false
	var anchor := target if activity_root == null else activity_root
	if not is_instance_valid(anchor) or (anchor != target and not anchor.is_ancestor_of(target)):
		push_warning("NpcActivity: activity_root must be the actor or one of its ancestors.")
		return false
	var instance_id := target.get_instance_id()
	if _registered_ids.has(instance_id):
		push_warning("NpcActivity: duplicate actor registration rejected for role %s." % role)
		return false
	for frame in frames:
		if not is_instance_valid(frame):
			push_warning("NpcActivity: invalid authored frame for role %s." % role)
			return false
	var material := target.material_override as ShaderMaterial
	var gesture_baseline := 0.0
	var shader_texture_baseline: Variant = null
	var shader_uv_rect_baseline: Variant = null
	var has_shader_texture := false
	var has_shader_uv_rect := false
	if material != null and material.shader != null:
		var gesture_value: Variant = material.get_shader_parameter("gesture_pixels")
		if gesture_value != null:
			gesture_baseline = float(gesture_value)
		shader_texture_baseline = material.get_shader_parameter("texture_albedo")
		has_shader_texture = shader_texture_baseline != null
		shader_uv_rect_baseline = material.get_shader_parameter("uv_rect")
		has_shader_uv_rect = shader_uv_rect_baseline != null
	var point_offset := Vector3.ZERO
	var original_point_position := Vector3.ZERO
	var has_point := interaction_point.has("position")
	if has_point:
		original_point_position = interaction_point["position"] as Vector3
		point_offset = original_point_position - anchor.global_position
	_registered_ids[instance_id] = role
	_records.append({
		"target": weakref(target),
		"anchor": weakref(anchor),
		"material": weakref(material) if material != null else null,
		"instance_id": instance_id,
		"role": role,
		"frames": frames,
		"seed": seed,
		"baseline_texture": target.texture,
		"baseline_flip_h": target.flip_h,
		"baseline_pixel_size": target.pixel_size,
		"baseline_shader_texture": shader_texture_baseline,
		"baseline_shader_uv_rect": shader_uv_rect_baseline,
		"has_shader_texture": has_shader_texture,
		"has_shader_uv_rect": has_shader_uv_rect,
		"baseline_anchor_position": anchor.position,
		"point": interaction_point,
		"point_offset": point_offset,
		"original_point_position": original_point_position,
		"has_point": has_point,
		"gesture_baseline": gesture_baseline,
		"tracks": PackedInt32Array(),
		"active": true,
	})
	if not frames.is_empty():
		target.pixel_size = 2.4 / float(ACTION_VISIBLE_HEIGHT)
		target.texture = frames[0]
		if material != null and has_shader_texture:
			material.set_shader_parameter("texture_albedo", frames[0])
			if has_shader_uv_rect:
				material.set_shader_parameter("uv_rect", Vector4(0.0, 0.0, 1.0, 1.0))
	_by_role[role] = int(_by_role.get(role, 0)) + 1
	var callback := Callable(self, "_on_actor_exiting").bind(instance_id)
	var record_index := _records.size() - 1
	var saved_record: Dictionary = _records[record_index]
	saved_record["exit_callback"] = callback
	_records[record_index] = saved_record
	if not target.tree_exiting.is_connected(callback):
		target.tree_exiting.connect(callback, CONNECT_ONE_SHOT)
	if anchor != target and not anchor.tree_exiting.is_connected(callback):
		anchor.tree_exiting.connect(callback, CONNECT_ONE_SHOT)
	return true


func finish_registration() -> void:
	if _finished:
		return
	_finished = true
	var scene_root := get_parent()
	if scene_root == null:
		push_warning("NpcActivity: add this node beneath a scene root before registration.")
		return
	_player = AnimationPlayer.new()
	_player.name = "NpcActivityAnimationPlayer"
	add_child(_player)
	_player.root_node = _player.get_path_to(scene_root)
	_animation = Animation.new()
	_animation.resource_name = ANIMATION_NAME
	_animation.length = CYCLE_SECONDS
	_animation.loop_mode = Animation.LOOP_LINEAR
	for record_index in range(_records.size()):
		_build_actor_tracks(record_index, scene_root)
	if _animation.get_track_count() == 0:
		return
	var library := AnimationLibrary.new()
	library.add_animation(ANIMATION_NAME, _animation)
	_player.add_animation_library("", library)
	if not _reduced_motion:
		_apply_authored_sizes()
		_player.play(ANIMATION_NAME)
		_player.seek(0.0, true)


func set_reduced_motion(enabled: bool) -> void:
	_reduced_motion = enabled
	if enabled:
		if is_instance_valid(_player):
			_player.stop()
		_restore_baselines()
		return
	if _finished and not _activity_paused and is_instance_valid(_player) and _animation != null and _animation.get_track_count() > 0:
		_apply_authored_sizes()
		_player.play(ANIMATION_NAME)
		_player.seek(0.0, true)


func set_activity_paused(paused: bool) -> void:
	_activity_paused = paused
	if not is_instance_valid(_player) or _reduced_motion:
		return
	if paused:
		_player.pause()
	elif _animation != null and _animation.get_track_count() > 0:
		_player.play(ANIMATION_NAME)


func statistics() -> Dictionary:
	var active := 0
	for record in _records:
		var target: Object = record.target.get_ref()
		if bool(record.active) and is_instance_valid(target):
			active += 1
	return {
		"registration_count": active,
		"by_role": _by_role.duplicate(),
		"playing": is_instance_valid(_player) and _player.is_playing(),
		"reduced_motion": _reduced_motion,
		"activity_paused": _activity_paused,
	}


func release() -> void:
	if is_instance_valid(_player):
		_player.stop()
	for record in _records:
		_disconnect_actor(record)
		_restore_record(record)
	_records.clear()
	_registered_ids.clear()
	_by_role.clear()
	_animation = null
	if is_instance_valid(_player):
		_player.queue_free()
	_player = null
	_finished = true


func _process(_delta: float) -> void:
	for record in _records:
		if not bool(record.active) or not bool(record.has_point):
			continue
		var anchor: Node3D = record.anchor.get_ref()
		if is_instance_valid(anchor):
			var point: Dictionary = record.point
			point["position"] = anchor.global_position + record.point_offset


func _build_actor_tracks(record_index: int, scene_root: Node) -> void:
	var record: Dictionary = _records[record_index]
	var target: Sprite3D = record.target.get_ref()
	var anchor: Node3D = record.anchor.get_ref()
	if not is_instance_valid(target) or not is_instance_valid(anchor) or not target.is_inside_tree():
		record.active = false
		_records[record_index] = record
		return
	var frames: Array = record.frames
	if not frames.is_empty():
		_add_frame_track(record, target, scene_root)
	else:
		_add_gesture_track(record, target, scene_root)
	if String(record.role) == "announcer" and anchor != target:
		_add_announcer_route_track(record, anchor, scene_root)
		_add_announcer_facing_track(record, target, scene_root)
	_records[record_index] = record


func _add_frame_track(record: Dictionary, target: Sprite3D, scene_root: Node) -> void:
	var role := String(record.role)
	var frames: Array = record.frames
	var path := NodePath(String(scene_root.get_path_to(target)) + ":texture")
	var track := _add_track(path, Animation.INTERPOLATION_NEAREST, Animation.UPDATE_DISCRETE)
	var material := target.material_override as ShaderMaterial
	var shader_texture_track := -1
	var shader_uv_rect_track := -1
	if material != null and material.shader != null and bool(record.has_shader_texture):
		shader_texture_track = _add_track(NodePath(String(scene_root.get_path_to(target)) + SHADER_TEXTURE_PROPERTY), Animation.INTERPOLATION_NEAREST, Animation.UPDATE_DISCRETE)
	if material != null and material.shader != null and bool(record.has_shader_uv_rect):
		shader_uv_rect_track = _add_track(NodePath(String(scene_root.get_path_to(target)) + SHADER_UV_RECT_PROPERTY), Animation.INTERPOLATION_NEAREST, Animation.UPDATE_DISCRETE)
	match role:
		"ticket":
			# Wait at the service point, offer the tray briefly, then return to idle.
			var duration := 1.0 / TICKET_FRAMES_PER_SECOND
			for index in range(4):
				_insert_texture_keys(track, shader_texture_track, shader_uv_rect_track, 2.4 + float(index) * duration, frames[index])
			_insert_texture_keys(track, shader_texture_track, shader_uv_rect_track, 2.4 + 4.0 * duration, frames[0])
			_insert_texture_keys(track, shader_texture_track, shader_uv_rect_track, CYCLE_SECONDS, frames[0])
		"imp":
			# Four foot-planted dance poses at about 3.3 frames per second.
			var duration := 1.0 / IMP_FRAMES_PER_SECOND
			var cycles := int(floor(CYCLE_SECONDS / (duration * 4.0)))
			for cycle in range(cycles):
				for index in range(4):
					var time := float(cycle) * duration * 4.0 + float(index) * duration
					_insert_texture_keys(track, shader_texture_track, shader_uv_rect_track, time, frames[index])
		"announcer":
			# A short side-step loop; root travel uses a separate bounded track.
			var duration := 1.0 / WALK_FRAMES_PER_SECOND
			var cycle_length := duration * 4.0
			var cycles := int(floor(CYCLE_SECONDS / cycle_length))
			for cycle in range(cycles):
				for index in range(4):
					var time := float(cycle) * cycle_length + float(index) * duration
					_insert_texture_keys(track, shader_texture_track, shader_uv_rect_track, time, frames[index])
	record.tracks.append(track)
	if shader_texture_track >= 0:
		record.tracks.append(shader_texture_track)
	if shader_uv_rect_track >= 0:
		record.tracks.append(shader_uv_rect_track)


func _insert_texture_keys(sprite_track: int, shader_track: int, uv_track: int, time: float, texture: Texture2D) -> void:
	_animation.track_insert_key(sprite_track, time, texture)
	if shader_track >= 0:
		_animation.track_insert_key(shader_track, time, texture)
	if uv_track >= 0:
		_animation.track_insert_key(uv_track, time, Vector4(0.0, 0.0, 1.0, 1.0))


func _insert_baseline_texture_keys(sprite_track: int, shader_track: int, uv_track: int, time: float, record: Dictionary) -> void:
	_animation.track_insert_key(sprite_track, time, record.baseline_texture)
	if shader_track >= 0:
		_animation.track_insert_key(shader_track, time, record.baseline_shader_texture)
	if uv_track >= 0:
		_animation.track_insert_key(uv_track, time, record.baseline_shader_uv_rect)


func _add_gesture_track(record: Dictionary, target: Sprite3D, scene_root: Node) -> void:
	var material := target.material_override as ShaderMaterial
	if material == null or material.shader == null or material.get_shader_parameter("gesture_pixels") == null:
		return
	var path := NodePath(String(scene_root.get_path_to(target)) + GESTURE_PROPERTY)
	var track := _add_track(path, Animation.INTERPOLATION_CUBIC, Animation.UPDATE_CONTINUOUS)
	for sample in range(33):
		var time := CYCLE_SECONDS * float(sample) / 32.0
		_animation.track_insert_key(track, time, _gesture_value(String(record.role), float(record.gesture_baseline), _seed_phase(float(record.seed), int(record.instance_id)), time))
	record.tracks.append(track)


func _add_announcer_route_track(record: Dictionary, anchor: Node3D, scene_root: Node) -> void:
	var path := NodePath(String(scene_root.get_path_to(anchor)) + ":position")
	var track := _add_track(path, Animation.INTERPOLATION_LINEAR, Animation.UPDATE_CONTINUOUS)
	var base: Vector3 = record.baseline_anchor_position
	var width := ANNOUNCER_ROUTE_HALF_WIDTH
	for key in [
		Vector2(0.0, 0.0), Vector2(1.2, width), Vector2(1.65, width),
		Vector2(3.0, 0.0), Vector2(4.2, -width), Vector2(4.65, -width), Vector2(6.0, 0.0),
	]:
		var position := base
		position.x += key.y
		_animation.track_insert_key(track, key.x, position)
	record.tracks.append(track)


func _add_announcer_facing_track(record: Dictionary, target: Sprite3D, scene_root: Node) -> void:
	var path := NodePath(String(scene_root.get_path_to(target)) + ":flip_h")
	var track := _add_track(path, Animation.INTERPOLATION_NEAREST, Animation.UPDATE_DISCRETE)
	for key in [
		Vector2(0.0, 0.0), Vector2(1.2, 0.0), Vector2(1.65, 1.0),
		Vector2(3.0, 1.0), Vector2(4.2, 1.0), Vector2(4.65, 0.0), Vector2(6.0, 0.0),
	]:
		_animation.track_insert_key(track, key.x, bool(key.y))
	record.tracks.append(track)


func _add_track(path: NodePath, interpolation: Animation.InterpolationType, update_mode: Animation.UpdateMode) -> int:
	var track := _animation.add_track(Animation.TYPE_VALUE)
	_animation.track_set_path(track, path)
	_animation.track_set_interpolation_type(track, interpolation)
	_animation.value_track_set_update_mode(track, update_mode)
	return track


func _gesture_value(role: String, baseline: float, phase: float, time: float) -> float:
	var cycle_phase := TAU * time / CYCLE_SECONDS + phase
	var activity := 0.0
	match role:
		"ticket": activity = pow(maxf(0.0, sin(cycle_phase)), 12.0)
		"imp": activity = 0.5 + 0.5 * sin(cycle_phase * 3.0)
		"announcer": activity = pow(maxf(0.0, sin(cycle_phase * 0.5)), 2.0)
	return clampf(baseline + activity * 0.2, 0.0, 1.0)


func _on_actor_exiting(instance_id: int) -> void:
	for index in range(_records.size()):
		var record: Dictionary = _records[index]
		if int(record.instance_id) != instance_id or not bool(record.active):
			continue
		_disconnect_actor(record)
		_restore_record(record)
		for track_index in record.tracks:
			if _animation != null:
				_animation.track_set_enabled(int(track_index), false)
		var role := String(record.role)
		var remaining_for_role := int(_by_role.get(role, 0)) - 1
		if remaining_for_role > 0:
			_by_role[role] = remaining_for_role
		else:
			_by_role.erase(role)
		_registered_ids.erase(instance_id)
		record.active = false
		_records[index] = record
		return


func _restore_baselines() -> void:
	for record in _records:
		_restore_record(record)


func _disconnect_actor(record: Dictionary) -> void:
	var callback: Callable = record.get("exit_callback", Callable())
	if not callback.is_valid():
		return
	var target: Sprite3D = record.target.get_ref()
	if is_instance_valid(target) and target.tree_exiting.is_connected(callback):
		target.tree_exiting.disconnect(callback)
	var anchor: Node3D = record.anchor.get_ref()
	if is_instance_valid(anchor) and anchor != target and anchor.tree_exiting.is_connected(callback):
		anchor.tree_exiting.disconnect(callback)


func _restore_record(record: Dictionary) -> void:
	var target: Sprite3D = record.target.get_ref()
	if is_instance_valid(target):
		target.texture = record.baseline_texture
		target.flip_h = bool(record.baseline_flip_h)
		target.pixel_size = float(record.baseline_pixel_size)
	var anchor: Node3D = record.anchor.get_ref()
	if is_instance_valid(anchor):
		anchor.position = record.baseline_anchor_position
	var material_ref: WeakRef = record.material
	if material_ref != null:
		var material: ShaderMaterial = material_ref.get_ref()
		if is_instance_valid(material) and material.shader != null and material.get_shader_parameter("gesture_pixels") != null:
			material.set_shader_parameter("gesture_pixels", float(record.gesture_baseline))
		if is_instance_valid(material) and material.shader != null:
			if bool(record.has_shader_texture):
				material.set_shader_parameter("texture_albedo", record.baseline_shader_texture)
			if bool(record.has_shader_uv_rect):
				material.set_shader_parameter("uv_rect", record.baseline_shader_uv_rect)
	if bool(record.has_point):
		var point: Dictionary = record.point
		point["position"] = record.original_point_position


func _seed_phase(seed: float, instance_id: int) -> float:
	var phase_source := seed
	if is_zero_approx(phase_source):
		phase_source = float(instance_id) * 0.61803398875
	return fposmod(phase_source, 1.0) * TAU


func _apply_authored_sizes() -> void:
	for record in _records:
		var frames: Array = record.frames
		var target: Sprite3D = record.target.get_ref()
		if bool(record.active) and not frames.is_empty() and is_instance_valid(target):
			target.pixel_size = 2.4 / float(ACTION_VISIBLE_HEIGHT)


static func _load_action_assets() -> bool:
	if _action_assets_loaded:
		return is_instance_valid(_action_atlas) and not _action_region_data.is_empty()
	_action_assets_loaded = true
	if not FileAccess.file_exists(ACTION_REGIONS_PATH):
		push_warning("NpcActivity: authored action region manifest is missing: %s" % ACTION_REGIONS_PATH)
		return false
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(ACTION_REGIONS_PATH))
	if not manifest is Dictionary or not manifest.has("atlas") or not manifest.has("regions") or not manifest["regions"] is Dictionary:
		push_warning("NpcActivity: authored action region manifest is malformed.")
		return false
	_action_atlas = ResourceLoader.load(String(manifest["atlas"])) as Texture2D
	if not is_instance_valid(_action_atlas):
		push_warning("NpcActivity: authored action atlas could not be loaded.")
		return false
	_action_atlas_image = _action_atlas.get_image()
	if _action_atlas_image == null or _action_atlas_image.is_empty():
		push_warning("NpcActivity: authored action atlas has no readable image data.")
		return false
	_action_region_data = manifest["regions"]
	return true
