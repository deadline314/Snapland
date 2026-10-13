class_name NpcActivity
extends Node
## One scene-scoped AnimationPlayer coordinates authored sprite frames and
## bounded, ground-level idle paths for the three named NPCs.

const ANIMATION_NAME := "npc_idle_actions"
const CYCLE_SECONDS := 8.6
const WALK_FRAMES_PER_SECOND := 5.0
const IMP_FRAMES_PER_SECOND := 3.3333333
const TICKET_FRAMES_PER_SECOND := 5.0
const ANNOUNCER_ROUTE_HALF_WIDTH := 0.6
const ANNOUNCER_OUTBOUND_SECONDS := 1.0
const ANNOUNCER_FIRST_REST_END := 3.3
const ANNOUNCER_RETURN_SECONDS := 5.3
const ANNOUNCER_SECOND_REST_END := 7.6
const ANNOUNCER_STOP_SETTLE_SECONDS := 0.16
const ANNOUNCER_PERSONALITY_DELAY := 0.12
const ROLE_NAMES := ["ticket", "imp", "announcer"]
const ACTION_REGIONS_PATH := "res://assets/characters/npc-action-regions.json"
const ANIMATION_LIBRARY_PATH := "res://game/world/character_animation_library.gd"
const DIRECTIONS := ["front", "front_right", "right", "back_right", "back", "back_left", "left", "front_left"]
const ACTION_CANVAS_SIZE := Vector2i(320, 460)
const ACTION_FEET_ROW := 448
const ACTION_MAX_HEIGHT := 420
const ACTION_VISIBLE_HEIGHT := 420
const ACTION_SIDE_PADDING := 2
const NpcWalkMotionScript = preload("res://game/world/npc_walk_motion.gd")
const NpcCostumeScript = preload("res://game/world/npc_costume.gd")

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
var _dialogue_hold := false
var _animation_library: RefCounted
var _action_clock := 0.0
var _motion_enabled := false
var _motion_camera: Camera3D
var _motion_ground: Callable
var _npc_costume = NpcCostumeScript.new()


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
	var motion_baseline := 1.0
	var has_shader_motion := false
	if material != null and material.shader != null:
		var gesture_value: Variant = material.get_shader_parameter("gesture_pixels")
		if gesture_value != null:
			gesture_baseline = float(gesture_value)
		shader_texture_baseline = material.get_shader_parameter("texture_albedo")
		has_shader_texture = shader_texture_baseline != null
		shader_uv_rect_baseline = material.get_shader_parameter("uv_rect")
		has_shader_uv_rect = shader_uv_rect_baseline != null
		var motion_value: Variant = material.get_shader_parameter("motion")
		has_shader_motion = motion_value != null
		if has_shader_motion: motion_baseline = float(motion_value)
	var point_offset := Vector3.ZERO
	var original_point_position := Vector3.ZERO
	var has_point := interaction_point.has("position")
	if has_point:
		original_point_position = interaction_point["position"] as Vector3
		point_offset = original_point_position - anchor.global_position
	var baseline_texture: Texture2D = target.texture
	if role == "announcer":
		baseline_texture = _costume_texture(role, baseline_texture)
		if has_shader_texture and shader_texture_baseline is Texture2D:
			shader_texture_baseline = _costume_texture(role, shader_texture_baseline as Texture2D)
	_registered_ids[instance_id] = role
	_records.append({
		"target": weakref(target),
		"anchor": weakref(anchor),
		"material": weakref(material) if material != null else null,
		"instance_id": instance_id,
		"role": role,
		"frames": frames,
		"seed": seed,
		"baseline_texture": baseline_texture,
		"baseline_flip_h": target.flip_h,
		"baseline_pixel_size": target.pixel_size,
		"baseline_shader_texture": shader_texture_baseline,
		"baseline_shader_uv_rect": shader_uv_rect_baseline,
		"has_shader_texture": has_shader_texture,
		"has_shader_uv_rect": has_shader_uv_rect,
		"baseline_motion": motion_baseline,
		"has_shader_motion": has_shader_motion,
		"baseline_anchor_position": anchor.position,
		"point": interaction_point,
		"point_offset": point_offset,
		"original_point_position": original_point_position,
		"has_point": has_point,
		"gesture_baseline": gesture_baseline,
		"tracks": PackedInt32Array(),
		"active": true,
		"action": "stand",
		"direction": "front",
		"action_elapsed": 0.0,
		"action_sequence": {},
		"idle_due": 5.0 + fposmod(_phase_seed(seed, instance_id) * 7.31, 7.0),
		"last_idle_action": "",
		"idle_event_count": 0,
		"route_rest_started": -1.0,
		"missing_actions": {},
	})
	_ensure_animation_library()
	_play_actor_action(_records.size() - 1, "stand", "front", true)
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
	if _motion_enabled:
		_setup_motion(record_index)
	return true


func request_action(target: Sprite3D, action: String, direction: String = "front") -> bool:
	var instance_id := target.get_instance_id() if is_instance_valid(target) else 0
	for index in range(_records.size()):
		if int(_records[index].instance_id) == instance_id and bool(_records[index].active):
			return _play_actor_action(index, action, direction, false)
	return false


func greet(target: Sprite3D, direction: String = "front") -> bool:
	return request_action(target, "greet", direction)


func interact(target: Sprite3D, direction: String = "front") -> bool:
	return request_action(target, "interact", direction)


func play_special(target: Sprite3D, direction: String = "front") -> bool:
	return request_action(target, "special", direction)


func set_actor_emotion(target: Sprite3D, emotion: String, direction: String = "front") -> bool:
	return request_action(target, "emotion_%s" % emotion, direction)


func coverage_report() -> Dictionary:
	var authored: Dictionary = _animation_library.coverage_report() if _animation_library != null else {}
	var missing := {}
	for record in _records:
		if bool(record.active):
			missing[String(record.role)] = record.missing_actions.duplicate()
	return {"authored": authored, "missing_requests": missing, "library_loaded": _animation_library != null}


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
	var library := AnimationLibrary.new()
	library.add_animation(ANIMATION_NAME, _animation)
	_player.add_animation_library("", library)
	if not _reduced_motion:
		_player.play(ANIMATION_NAME)
		_player.seek(0.0, true)


func set_reduced_motion(enabled: bool) -> void:
	_reduced_motion = enabled
	if enabled:
		if is_instance_valid(_player):
			_player.pause()
		_restore_baselines()
		_freeze_shader_motion(true)
		_update_motion_pause(true)
		return
	_freeze_shader_motion(_activity_paused and not _dialogue_hold)
	_update_motion_pause(_activity_paused and not _dialogue_hold)
	if _finished and not _activity_paused and not _dialogue_hold and is_instance_valid(_player) and _animation != null and _animation.get_track_count() > 0:
		_player.play(ANIMATION_NAME)


func set_activity_paused(paused: bool) -> void:
	_activity_paused = paused
	var freeze := paused and not _dialogue_hold
	_freeze_shader_motion(freeze or _reduced_motion)
	_update_motion_pause(freeze or _reduced_motion)
	if not is_instance_valid(_player) or _reduced_motion:
		return
	if paused or _dialogue_hold:
		_player.pause()
	elif _animation != null and _animation.get_track_count() > 0:
		_player.play(ANIMATION_NAME)


func set_dialogue_hold(held: bool) -> void:
	## Let the current authored pose/action continue while world input and route
	## motion stay held. The caller pairs this with set_activity_paused(true).
	if _dialogue_hold == held:
		return
	_dialogue_hold = held
	_freeze_shader_motion(_activity_paused and not held or _reduced_motion)
	_update_motion_pause(_activity_paused and not held or _reduced_motion)
	if not is_instance_valid(_player):
		return
	if held:
		_player.pause()
		# A route may have stopped on a walk cel. Put that actor into its authored
		# idle loop once; do not advance the route or start another idle gesture.
		for index in range(_records.size()):
			if not bool(_records[index].active) or String(_records[index].action) != "walk":
				continue
			var direction := String(_records[index].direction)
			if not _play_actor_action(index,"idle",direction,true):
				_play_actor_action(index,"stand",direction,true)
	elif not _activity_paused and not _reduced_motion and _animation != null and _animation.get_track_count() > 0:
		_player.play(ANIMATION_NAME)

## Root opts in only after native review. Missing/invalid source records retain
## their original Sprite3D and are not counted as motion coverage.
func configure_motion(view_camera: Camera3D, ground_height: Callable, enabled: bool = false) -> void:
	_motion_camera = view_camera
	_motion_ground = ground_height
	_motion_enabled = enabled and is_instance_valid(view_camera) and view_camera.is_inside_tree() and ground_height.is_valid()
	if enabled and not _motion_enabled:
		var missing: Array[String] = []
		if not is_instance_valid(view_camera) or not view_camera.is_inside_tree(): missing.append("in-tree Camera3D")
		if not ground_height.is_valid(): missing.append("valid ground-height Callable")
		push_warning("NpcActivity: measured gait was requested but disabled because configuration is missing %s." % ", ".join(missing))
		_motion_camera = null
		_motion_ground = Callable()
	for index in range(_records.size()):
		var old: Variant = _records[index].get("motion")
		if old != null and is_instance_valid(old):
			var record: Dictionary = _records[index]
			var target: Sprite3D = record.target.get_ref()
			var anchor: Node3D = record.anchor.get_ref()
			var registered_pixel_size := float(old.original_sprite_pixel_size)
			var registered_sprite_position: Vector3 = old.original_sprite_position
			var registered_anchor_position: Vector3 = old.original_anchor_position
			old.close()
			old.queue_free()
			if is_instance_valid(target):
				record["baseline_pixel_size"] = registered_pixel_size
				target.position = registered_sprite_position
			if is_instance_valid(anchor): record["baseline_anchor_position"] = registered_anchor_position
			_records[index] = record
			_restore_actor_visual(record)
		_records[index]["motion"] = null
		_records[index]["route_base"] = null
		if _motion_enabled: _setup_motion(index)
	_update_motion_pause(_reduced_motion or (_activity_paused and not _dialogue_hold))

func motion_report() -> Dictionary:
	var supported := {}
	var fallbacks := {}
	for record in _records:
		var role := String(record.role)
		var motion: Variant = record.get("motion")
		if motion != null and is_instance_valid(motion) and bool(motion.supported): supported[role]=true
		elif role in ["ticket","imp","announcer"]: fallbacks[role]=true
	return {"enabled":_motion_enabled,"supported_roles":supported.keys(),"sprite_fallback_roles":fallbacks.keys()}

func costume_report() -> Dictionary:
	return {"cache_size":_npc_costume.cache_size(),"cache_limit":NpcCostumeScript.CACHE_LIMIT}

func _setup_motion(record_index: int) -> void:
	if record_index<0 or record_index>=_records.size() or _motion_camera==null or not _motion_ground.is_valid(): return
	var record: Dictionary=_records[record_index]
	var role:=String(record.role)
	if role not in ["ticket","imp","announcer"]: return
	var target: Sprite3D=record.target.get_ref()
	var anchor: Node3D=record.anchor.get_ref()
	if not is_instance_valid(target) or not is_instance_valid(anchor): return
	var motion=NpcWalkMotionScript.new()
	motion.name="NpcMeasuredMotion_%s" % role
	add_child(motion)
	var configured: bool=motion.configure(anchor,target,role,_motion_camera,_motion_ground)
	if configured:
		# Motion calibration is derived from the authored Sprite's measured opaque
		# height. Keep later authored action restores at that same body scale.
		record["baseline_pixel_size"] = target.pixel_size
		record["baseline_anchor_position"] = anchor.position
		_records[record_index] = record
		motion.set_enabled(true)
		var duration:=2.0
		var radius:=0.25 if role=="ticket" else 0.35
		var rest:=10.0 if role=="ticket" else 7.0
		var cycle:=duration+rest
		record["route_base"]=anchor.position
		record["route_phase"]=_phase_seed(float(record.seed),int(record.instance_id))*cycle
		record["route_cycle"]=cycle
		record["route_walk_seconds"]=duration
		record["route_radius"]=radius
		if role=="announcer":
			# Its existing authored route owns translation and timing; this driver
			# only consumes that real anchor displacement if measured assets land.
			record["route_base"]=null
	else:
		push_warning("NpcActivity: %s keeps its original sprite; measured gait unavailable: %s" % [role,"; ".join(motion.diagnostics)])
		motion.queue_free()
		record["motion"]=null
		_records[record_index]=record
		return
	record["motion"]=motion
	_records[record_index]=record

func _update_short_route(record: Dictionary, delta: float) -> void:
	var role:=String(record.role)
	if role not in ["ticket","imp"] or not _motion_enabled or not bool(record.get("motion",null)!=null): return
	var anchor: Node3D=record.anchor.get_ref()
	if not is_instance_valid(anchor) or not record.get("route_base") is Vector3: return
	var clock:=float(record.get("route_clock",0.0))+delta
	var phase:=fposmod(clock+float(record.get("route_phase",0.0)),float(record.route_cycle))
	var offset:=0.0
	var moving:=phase<float(record.route_walk_seconds)
	if moving:
		var progress:=phase/float(record.route_walk_seconds)
		offset=float(record.route_radius)*(1.0-absf(progress*2.0-1.0))
	anchor.position=record.route_base+Vector3(offset,0,0)
	var index:=_record_index(record)
	if index>=0:
		_records[index].route_clock=clock
		if moving and String(_records[index].action)!="walk":
			var direction:="right" if phase<float(record.route_walk_seconds)*0.5 else "left"
			# Measured gait owns route movement even when this authored direction
			# has no walk cels. Preserve the current breathing/interaction sequence.
			if _has_sequence(role,"walk",direction):
				_play_actor_action(index,"walk",direction,true)
			else:
				var missing: Dictionary=_records[index].missing_actions
				var key := "walk/%s" % direction
				if not missing.has(key):
					missing[key]=true
					push_warning("NpcActivity: %s lacks authored %s; measured route gait retains the current authored pose." % [role,key])
		elif not moving and String(_records[index].action)=="walk":
			if not _play_actor_action(index,"idle","front",true): _play_actor_action(index,"stand","front",true)

func _update_motion_pause(paused: bool) -> void:
	for record in _records:
		var motion: Variant=record.get("motion")
		if motion!=null and is_instance_valid(motion): motion.set_paused(paused)

func _freeze_shader_motion(frozen: bool) -> void:
	for record in _records:
		if not bool(record.get("has_shader_motion",false)): continue
		var material_ref: WeakRef=record.get("material")
		if material_ref==null: continue
		var material: ShaderMaterial=material_ref.get_ref()
		if is_instance_valid(material) and material.shader!=null:
			material.set_shader_parameter("motion",0.0 if frozen else float(record.get("baseline_motion",1.0)))

func _costume_texture(role: String, texture: Texture2D) -> Texture2D:
	if role!="announcer" or texture==null: return texture
	return _npc_costume.decorate(texture).get("texture",texture)


func statistics() -> Dictionary:
	var active := 0
	for record in _records:
		var target: Object = record.target.get_ref()
		if bool(record.active) and is_instance_valid(target):
			active += 1
	return {
		"registration_count": active,
		"by_role": _by_role.duplicate(),
		"playing": is_instance_valid(_player) and _player.is_playing() or (_finished and active > 0 and not _reduced_motion and not _activity_paused),
		"reduced_motion": _reduced_motion,
		"activity_paused": _activity_paused,
		"dialogue_hold": _dialogue_hold,
	}


func release() -> void:
	if is_instance_valid(_player):
		_player.stop()
	for record in _records:
		var motion: Variant = record.get("motion")
		if motion != null and is_instance_valid(motion): motion.close()
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


func _process(delta: float) -> void:
	if _reduced_motion or (_activity_paused and not _dialogue_hold):
		return
	if not _dialogue_hold:
		_action_clock += delta
	for record in _records:
		if not bool(record.active):
			continue
		var target: Sprite3D = record.target.get_ref()
		if is_instance_valid(target):
			if not _dialogue_hold:
				_update_short_route(record,delta)
			if not _dialogue_hold and String(record.role) == "announcer":
				_update_announcer_action(record)
			var record_index := _record_index(record)
			if record_index >= 0:
				record = _records[record_index]
			_advance_actor(record, target, delta, not _dialogue_hold)
			var motion: Variant = record.get("motion")
			if motion != null and is_instance_valid(motion): motion.update(delta,_dialogue_hold,false)
		if not bool(record.has_point):
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
	if String(record.role) == "announcer" and anchor != target and _has_sequence("announcer", "walk", "right") and _has_sequence("announcer", "walk", "left"):
		_add_announcer_route_track(record, anchor, scene_root)
	_records[record_index] = record


func _add_announcer_route_track(record: Dictionary, anchor: Node3D, scene_root: Node) -> void:
	var path := NodePath(String(scene_root.get_path_to(anchor)) + ":position")
	var track := _add_track(path, Animation.INTERPOLATION_LINEAR, Animation.UPDATE_CONTINUOUS)
	var base: Vector3 = record.baseline_anchor_position
	var width := ANNOUNCER_ROUTE_HALF_WIDTH
	for key in [
		Vector2(0.0, 0.0), Vector2(ANNOUNCER_OUTBOUND_SECONDS, width),
		Vector2(ANNOUNCER_OUTBOUND_SECONDS + ANNOUNCER_STOP_SETTLE_SECONDS, width),
		Vector2(ANNOUNCER_FIRST_REST_END, width), Vector2(ANNOUNCER_RETURN_SECONDS - ANNOUNCER_OUTBOUND_SECONDS, 0.0),
		Vector2(ANNOUNCER_RETURN_SECONDS, -width),
		Vector2(ANNOUNCER_RETURN_SECONDS + ANNOUNCER_STOP_SETTLE_SECONDS, -width),
		Vector2(ANNOUNCER_SECOND_REST_END, -width),
		Vector2(CYCLE_SECONDS, 0.0),
	]:
		var position := base
		position.x += key.y
		_animation.track_insert_key(track, key.x, position)
	record.tracks.append(track)


func _add_track(path: NodePath, interpolation: Animation.InterpolationType, update_mode: Animation.UpdateMode) -> int:
	var track := _animation.add_track(Animation.TYPE_VALUE)
	_animation.track_set_path(track, path)
	_animation.track_set_interpolation_type(track, interpolation)
	_animation.value_track_set_update_mode(track, update_mode)
	return track


func _on_actor_exiting(instance_id: int) -> void:
	for index in range(_records.size()):
		var record: Dictionary = _records[index]
		if int(record.instance_id) != instance_id or not bool(record.active):
			continue
		var motion: Variant=record.get("motion")
		if motion!=null and is_instance_valid(motion): motion.close(); motion.queue_free()
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
			if is_instance_valid(material) and material.shader != null and bool(record.get("has_shader_motion",false)):
				material.set_shader_parameter("motion", 0.0 if _reduced_motion or (_activity_paused and not _dialogue_hold) else float(record.baseline_motion))
	if bool(record.has_point):
		var point: Dictionary = record.point
		point["position"] = record.original_point_position


func _ensure_animation_library() -> void:
	if _animation_library != null or not ResourceLoader.exists(ANIMATION_LIBRARY_PATH):
		return
	var script := load(ANIMATION_LIBRARY_PATH) as Script
	if script != null and script.can_instantiate():
		_animation_library = script.new()


func _play_actor_action(record_index: int, action: String, direction: String, reset: bool) -> bool:
	if record_index < 0 or direction not in DIRECTIONS:
		return false
	var record: Dictionary = _records[record_index]
	var target: Sprite3D = record.target.get_ref()
	if not is_instance_valid(target):
		return false
	_ensure_animation_library()
	var sequence: Dictionary = {}
	if _animation_library != null:
		var action_candidates := [action]
		if action == "stand":
			action_candidates.append_array(["idle", "idle_stand"])
		for candidate in action_candidates:
			if not _has_sequence(String(record.role), String(candidate), direction):
				continue
			sequence = _animation_library.get_sequence(String(record.role), String(candidate), direction)
			if bool(sequence.get("available", false)):
				break
		sequence = _normalize_sequence(sequence)
	if not bool(sequence.get("available", false)) or sequence.get("frames", []).is_empty():
		sequence = _legacy_fallback_sequence(record, action)
	var frames: Array = sequence.get("frames", [])
	var usable := bool(sequence.get("available", false)) and not frames.is_empty()
	if not usable:
		var missing: Dictionary = record.missing_actions
		missing["%s/%s" % [action, direction]] = true
		record.missing_actions = missing
		_restore_actor_visual(record)
		record.action = "stand"
		record.action_sequence = {}
		record.action_elapsed = 0.0
		_records[record_index] = record
		return false
	if bool(sequence.get("legacy_fallback", false)):
		var missing: Dictionary = record.missing_actions
		missing["%s/%s (legacy four-frame fallback; incomplete)" % [action, direction]] = true
		record.missing_actions = missing
	if reset or String(record.action) != action or String(record.direction) != direction:
		record.action_elapsed = 0.0
	record.action = action
	record.direction = direction
	record.action_sequence = sequence
	_records[record_index] = record
	_apply_actor_frame(record_index, 0)
	return true


func _advance_actor(record: Dictionary, target: Sprite3D, delta: float, allow_idle_actions := true) -> void:
	var sequence: Dictionary = record.action_sequence
	var action := String(record.action)
	if allow_idle_actions and action in ["stand", "idle"] and _action_clock >= float(record.idle_due):
		var current_index := _record_index(record)
		var idle_action := _idle_action_for_role(
			String(record.role), String(record.direction), String(record.last_idle_action),
			float(record.seed), int(record.instance_id), int(record.idle_event_count)
		)
		if not idle_action.is_empty() and _play_actor_action(current_index, idle_action, String(record.direction), false):
			record = _records[current_index]
			record.last_idle_action = idle_action
			record.idle_event_count = int(record.idle_event_count) + 1
		record.idle_due = _action_clock + 7.0 + fposmod(_phase_seed(float(record.seed), int(record.instance_id)) * 11.7 + _action_clock, 9.0)
		sequence = record.action_sequence
		if current_index >= 0:
			_records[current_index] = record
	if sequence.is_empty():
		var empty_index := _record_index(record)
		if empty_index >= 0:
			_records[empty_index].idle_due = record.idle_due
		return
	record.action_elapsed = float(record.action_elapsed) + delta
	var frames: Array = sequence.get("frames", [])
	if frames.is_empty():
		return
	var frame_index := floori(float(record.action_elapsed) * maxf(0.01, float(sequence.get("fps", 1.0))))
	if bool(sequence.get("loop", false)):
		frame_index = posmod(frame_index, frames.size())
	elif frame_index >= frames.size():
		var direction := String(record.direction)
		if _play_actor_action(_record_index(record), "stand", direction, true):
			return
		var index := _record_index(record)
		if index >= 0:
			_restore_actor_visual(_records[index])
			var idle_record: Dictionary = _records[index]
			idle_record.action = "stand"
			idle_record.action_sequence = {}
			idle_record.action_elapsed = 0.0
			_records[index] = idle_record
		return
	_apply_actor_frame(_record_index(record), frame_index)
	_records[_record_index(record)] = record


func _apply_actor_frame(record_index: int, frame_index: int) -> void:
	if record_index < 0:
		return
	var record: Dictionary = _records[record_index]
	var target: Sprite3D = record.target.get_ref()
	if not is_instance_valid(target):
		return
	var frames: Array = record.action_sequence.get("frames", [])
	if frames.is_empty():
		return
	var frame: Dictionary = frames[clampi(frame_index, 0, frames.size() - 1)]
	var texture := frame.get("texture") as Texture2D
	if String(record.role)=="announcer" and not bool(record.action_sequence.get("legacy_fallback",false)):
		texture=_costume_texture(String(record.role),texture)
	if texture == null:
		return
	target.texture = texture
	target.flip_h = bool(record.baseline_flip_h)
	var material := target.material_override as ShaderMaterial
	if material != null and material.shader != null:
		if bool(record.has_shader_texture): material.set_shader_parameter("texture_albedo", texture)
		if bool(record.has_shader_uv_rect): material.set_shader_parameter("uv_rect", Vector4(0, 0, 1, 1))


func _restore_actor_visual(record: Dictionary) -> void:
	var target: Sprite3D = record.target.get_ref()
	if not is_instance_valid(target):
		return
	target.texture = record.baseline_texture
	target.flip_h = bool(record.baseline_flip_h)
	target.pixel_size = float(record.baseline_pixel_size)
	var material_ref: WeakRef = record.material
	if material_ref != null:
		var material: ShaderMaterial = material_ref.get_ref()
		if is_instance_valid(material) and material.shader != null:
			if bool(record.has_shader_texture): material.set_shader_parameter("texture_albedo", record.baseline_shader_texture)
			if bool(record.has_shader_uv_rect): material.set_shader_parameter("uv_rect", record.baseline_shader_uv_rect)


func _normalize_sequence(sequence: Dictionary) -> Dictionary:
	var copy := sequence.duplicate()
	var frames: Array = sequence.get("frames", [])
	var normalized: Array[Dictionary] = []
	for original in frames:
		if not original is Dictionary:
			continue
		var frame: Dictionary = original.duplicate(true)
		var texture := frame.get("texture") as Texture2D
		if texture != null:
			frame["texture"] = _normalize_frame(texture)
		normalized.append(frame)
	copy["frames"] = normalized
	copy["available"] = bool(sequence.get("available", false)) and normalized.size() == frames.size() and not normalized.is_empty()
	return copy


func _normalize_frame(texture: Texture2D) -> Texture2D:
	# The shared library returns the canonical canvas and translated anchors. Do
	# not recrop or rescale per frame: changing arm bounds would make the whole
	# character visibly zoom during an action.
	if texture.get_size() == Vector2(ACTION_CANVAS_SIZE):
		return texture
	push_warning("NpcActivity: authored frame texture must use the canonical 320x460 canvas; preserving baseline.")
	return null


func _has_sequence(role: String, action: String, direction: String) -> bool:
	if _animation_library == null:
		return false
	var coverage: Dictionary = _animation_library.coverage_report()
	var actor_coverage: Variant = coverage.get(role, {})
	var action_coverage: Variant = actor_coverage.get(action, []) if actor_coverage is Dictionary else []
	return action_coverage is Array and action_coverage.has(direction)


func _idle_action_for_role(role: String, direction: String, previous_action: String = "", seed: float = 0.0, instance_id: int = 0, event_index: int = 0) -> String:
	var candidates: Array[String] = []
	match role:
		"ticket": candidates = ["idle_gesture", "emotion_happy"]
		"imp": candidates = ["idle_gesture", "emotion_proud", "dance"]
		"announcer": candidates = ["special", "emotion_curious"]
	var available: Array[String] = []
	for action in candidates:
		if action != previous_action and _has_sequence(role, action, direction):
			available.append(action)
	if available.is_empty():
		return ""
	var phase := fposmod(_phase_seed(seed, instance_id) + float(event_index) * 0.61803398875, 1.0)
	return available[mini(floori(phase * float(available.size())), available.size() - 1)]


func _phase_seed(seed: float, instance_id: int) -> float:
	var source := seed
	if is_zero_approx(source):
		source = float(instance_id) * 0.61803398875
	return fposmod(source, 1.0)


func _legacy_fallback_sequence(record: Dictionary, action: String) -> Dictionary:
	var role := String(record.role)
	var allowed_action := "service" if role == "ticket" else "special" if role == "imp" else "legacy_activity"
	if role == "announcer":
		allowed_action = "legacy_activity"
	if action != allowed_action and action != "legacy_activity":
		return {}
	var textures: Array = record.frames
	if textures.size() != 4:
		return {}
	var frames: Array[Dictionary] = []
	for texture in textures:
		frames.append({"texture": texture, "anchors": {}, "layers": []})
	var fps := TICKET_FRAMES_PER_SECOND if role == "ticket" else IMP_FRAMES_PER_SECOND if role == "imp" else WALK_FRAMES_PER_SECOND
	return {"fps": fps, "loop": false, "frames": frames, "available": true, "legacy_fallback": true}


func _update_announcer_action(record: Dictionary) -> void:
	var phase := fposmod(_action_clock, CYCLE_SECONDS)
	var direction := ""
	if phase < ANNOUNCER_OUTBOUND_SECONDS or phase >= ANNOUNCER_SECOND_REST_END:
		direction = "right"
	elif phase >= ANNOUNCER_FIRST_REST_END and phase < ANNOUNCER_RETURN_SECONDS:
		direction = "left"
	var current_action := String(record.action)
	var current_direction := String(record.direction)
	var index := _record_index(record)
	if direction.is_empty():
		if current_action == "walk":
			var rest_started := float(record.get("route_rest_started", -1.0))
			if rest_started < 0.0:
				record.route_rest_started = _action_clock
				_records[index] = record
				return
			if _action_clock - rest_started < ANNOUNCER_STOP_SETTLE_SECONDS:
				return
			if not _play_actor_action(index, "idle", "front", true):
				_play_actor_action(index, "stand", "front", true)
			index = _record_index(record)
			if index >= 0:
				var idle_record: Dictionary = _records[index]
				idle_record.direction = "front"
				idle_record.idle_due = _action_clock + ANNOUNCER_PERSONALITY_DELAY
				_records[index] = idle_record
		return
	if current_action == "walk" and current_direction == direction:
		return
	if index >= 0:
		record.route_rest_started = -1.0
		_records[index] = record
	if not _play_actor_action(index, "walk", direction, true) and current_action == "walk":
		_restore_actor_visual(record)
		if index >= 0:
			var idle_record: Dictionary = _records[index]
			idle_record.action_sequence = {}
			idle_record.action = "stand"
			idle_record.direction = direction
			_records[index] = idle_record


func _record_index(record: Dictionary) -> int:
	for index in range(_records.size()):
		if int(_records[index].instance_id) == int(record.instance_id):
			return index
	return -1


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
