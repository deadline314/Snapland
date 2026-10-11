extends SceneTree

const ParkWorldScript := preload("res://game/world/park_world.gd")
const AvatarRendererScript := preload("res://game/world/avatar_renderer.gd")
const NpcActivityScript := preload("res://game/world/npc_activity.gd")

var _world: Node3D
var _failed := false

func _initialize() -> void:
	if OS.get_environment("SNAPLAND_SAVE_PATH").is_empty():
		push_error("SNAPLAND_SAVE_PATH must point to an isolated test save location.")
		quit(1)
		return
	call_deferred("_run")

func _run() -> void:
	_world = ParkWorldScript.new()
	root.add_child(_world)
	await process_frame
	_assert_avatar_frames_share_feet_baseline()
	if _failed: quit(1); return
	_assert_npc_frames_share_feet_baseline()
	if _failed: quit(1); return
	_assert_npc_reduced_motion_restoration()
	if _failed: quit(1); return
	_assert_projected_feet_touch_their_ground()
	if _failed: quit(1); return
	_world.queue_free()
	await process_frame
	print("PASS: billboard sprites keep authored feet on the ground for eight headings and camera pitches")
	quit(0)

func _assert_avatar_frames_share_feet_baseline() -> void:
	var renderer = _world.avatar_renderer
	var directions: Array = AvatarRendererScript.WALK_DIRECTIONS
	var equipped: Dictionary = _world.avatar_equipped
	var appearance: Dictionary = _world.avatar_appearance
	var baseline_rows := PackedInt32Array()
	for direction in directions:
		var idle: Texture2D = renderer.texture(appearance,equipped,direction,0,"idle")
		baseline_rows.append(_visible_bottom(idle))
		_check_canvas_clearance(idle,"avatar idle/%s" % direction)
		var walk_count: int = renderer.walk_frame_count(direction)
		if walk_count > 0:
			for frame in range(walk_count):
				var walk: Texture2D = renderer.texture(appearance,equipped,direction,frame,"walk")
				baseline_rows.append(_visible_bottom(walk))
				_check_canvas_clearance(walk,"avatar walk/%s/%d-of-%d" % [direction,frame+1,walk_count])
		for action in AvatarRendererScript.ACTIONS:
			for frame in range(3):
				var action_texture: Texture2D = renderer.texture(appearance,equipped,direction,frame,action)
				baseline_rows.append(_visible_bottom(action_texture))
				_check_canvas_clearance(action_texture,"avatar %s/%s/%d" % [action,direction,frame])
	_check(not baseline_rows.is_empty(), "avatar frame fixtures include idle, every authored walk frame, and all three frames of every action")
	if baseline_rows.is_empty(): return
	var low := baseline_rows[0]
	var high := baseline_rows[0]
	for row in baseline_rows:
		low = mini(low,row)
		high = maxi(high,row)
	_check(high - low <= 2, "all eight directions and full action frames stay within two pixels of one visible feet baseline; found %d..%d" % [low,high])
	_check(high <= AvatarRendererScript.FEET_BASELINE + 1, "avatar artwork keeps its visible pixels within one pixel of its authored feet row")
	for direction in directions:
		for hat in ["hat-straw","hat-sailor","hat-flower"]:
			var hat_look := equipped.duplicate(true)
			hat_look["hat"] = hat
			var hat_texture: Texture2D = renderer.texture(appearance,hat_look,direction,0,"idle")
			_check_canvas_clearance(hat_texture,"avatar %s/%s" % [hat,direction])

func _assert_npc_frames_share_feet_baseline() -> void:
	for record in _world.npc_activity._records:
		var role := String(record.role)
		var frames: Array = record.frames
		_check(frames.size() == 4, "%s has all four authored activity frames" % role)
		var low := NpcActivityScript.ACTION_FEET_ROW
		var high := 0
		for frame in frames:
			var bottom := _visible_bottom(frame)
			low = mini(low,bottom)
			high = maxi(high,bottom)
			_check_full_canvas_clearance(frame,NpcActivityScript.ACTION_CANVAS_SIZE,"NPC %s action frame" % role)
		_check(high <= NpcActivityScript.ACTION_FEET_ROW, "%s action frames do not extend below their foot anchor" % role)
		_check(high - low <= 1, "%s action frames share a consistent foot baseline" % role)

func _assert_npc_reduced_motion_restoration() -> void:
	var activity = _world.npc_activity
	activity.set_reduced_motion(true)
	for record: Dictionary in activity._records:
		if not bool(record.get("active",false)): continue
		var role := String(record.role)
		var target_ref: WeakRef = record.target
		var sprite := target_ref.get_ref() as Sprite3D
		var root_ref: WeakRef = record.anchor
		var activity_root := root_ref.get_ref() as Node3D
		var material := sprite.material_override as ShaderMaterial if is_instance_valid(sprite) else null
		_check(is_instance_valid(sprite) and is_instance_valid(activity_root), "%s reduced-motion actor is still present" % role)
		if not is_instance_valid(sprite) or not is_instance_valid(activity_root): continue
		_check(sprite.texture == record.baseline_texture, "%s reduced motion restores its registered rest texture" % role)
		_check(is_equal_approx(sprite.pixel_size,float(record.baseline_pixel_size)), "%s reduced motion restores its pixel size" % role)
		_check(sprite.flip_h == bool(record.baseline_flip_h), "%s reduced motion restores its horizontal flip" % role)
		_check(activity_root.position.is_equal_approx(record.baseline_anchor_position), "%s reduced motion restores its activity-root position" % role)
		if material != null:
			if bool(record.has_shader_texture):
				_check(material.get_shader_parameter("texture_albedo") == record.baseline_shader_texture, "%s reduced motion restores its material texture" % role)
			if bool(record.has_shader_uv_rect):
				_check(material.get_shader_parameter("uv_rect") == record.baseline_shader_uv_rect, "%s reduced motion restores its material UV rectangle" % role)
			if material.get_shader_parameter("gesture_pixels") != null:
				_check(is_equal_approx(float(material.get_shader_parameter("gesture_pixels")),float(record.gesture_baseline)), "%s reduced motion restores its gesture baseline" % role)
		_check_npc_grounded_texture(sprite,role+" reduced motion")
	activity.set_reduced_motion(false)
	for record: Dictionary in activity._records:
		if not bool(record.get("active",false)): continue
		var role := String(record.role)
		var target_ref: WeakRef = record.target
		var sprite := target_ref.get_ref() as Sprite3D
		var material := sprite.material_override as ShaderMaterial if is_instance_valid(sprite) else null
		_check(is_instance_valid(sprite), "%s restored activity actor is still present" % role)
		if not is_instance_valid(sprite): continue
		var frames: Array = record.frames
		_check(not frames.is_empty() and sprite.texture == frames[0], "%s activity resumes from its first authored frame" % role)
		if material != null:
			_check(material.get_shader_parameter("texture_albedo") == sprite.texture, "%s activity shader texture matches the restored Sprite3D" % role)
			_check(material.get_shader_parameter("uv_rect") == Vector4(0.0,0.0,1.0,1.0), "%s activity restores full-canvas shader UVs" % role)
		_check_npc_grounded_texture(sprite,role+" restored activity")
	activity.set_reduced_motion(false)

func _check_npc_grounded_texture(sprite: Sprite3D, description: String) -> void:
	var image := sprite.texture.get_image() if sprite.texture != null else null
	_check(image != null and not image.is_empty(), "%s rest/activity texture pixels are readable" % description)
	if image == null or image.is_empty(): return
	_check(image.get_size() == NpcActivityScript.ACTION_CANVAS_SIZE, "%s texture uses the complete normalized NPC canvas" % description)
	var bounds := _alpha_bounds(image)
	_check(bounds.size.x > 0 and bounds.size.y > 0, "%s has visible alpha >= 0.5" % description)
	if bounds.size.x <= 0 or bounds.size.y <= 0: return
	_check(bounds.position.x > 0 and bounds.position.y > 0 and bounds.end.x < image.get_width() and bounds.end.y < image.get_height(), "%s complete >=0.5-alpha silhouette stays inside every canvas edge" % description)
	var bottom := bounds.end.y - 1
	_check(bottom <= NpcActivityScript.ACTION_FEET_ROW, "%s visible feet do not pass the authored foot row" % description)
	var record: Dictionary = {}
	for candidate: Dictionary in _world.sprite_ground_anchors:
		if candidate.get("sprite") == sprite:
			record = candidate
			break
	_check(not record.is_empty(), "%s has a registered grounding record" % description)
	if record.is_empty(): return
	var anchor := record.anchor as Node3D
	var parent := record.parent as Node3D
	if not is_instance_valid(anchor) or not is_instance_valid(parent): return
	var camera_up_y: float = _world.camera.global_basis.y.y
	var surface_y := ParkWorldScript._ground_surface_y(parent.global_position)
	var guarded_row := float(record.feet_row)
	var canvas_height := float(record.canvas_height)
	var projected_ground_row := parent.global_position.y + anchor.position.y + sprite.position.y
	projected_ground_row -= (guarded_row - canvas_height * 0.5) * sprite.pixel_size * camera_up_y
	_check(absf(projected_ground_row - surface_y) <= 0.001, "%s registered guarded row meets its floor" % description)
	var lowest_visible_y := sprite.global_position.y + (canvas_height * 0.5 - float(bottom)) * sprite.pixel_size * camera_up_y
	_check(lowest_visible_y >= surface_y, "%s lowest >=0.5-alpha pixel stays above the floor" % description)

func _alpha_bounds(image: Image) -> Rect2i:
	var left := image.get_width()
	var top := image.get_height()
	var right := -1
	var bottom := -1
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x,y).a < 0.5: continue
			left = mini(left,x)
			top = mini(top,y)
			right = maxi(right,x)
			bottom = maxi(bottom,y)
	if right < left or bottom < top: return Rect2i()
	return Rect2i(left,top,right-left+1,bottom-top+1)

func _check_canvas_clearance(texture: Texture2D, description: String) -> void:
	_check_full_canvas_clearance(texture,AvatarRendererScript.CANVAS_SIZE,description)

func _check_full_canvas_clearance(texture: Texture2D, canvas_size: Vector2i, description: String) -> void:
	_check(texture != null, "%s texture exists" % description)
	if texture == null: return
	var image := texture.get_image()
	_check(image != null and not image.is_empty(), "%s texture pixels are readable" % description)
	if image == null or image.is_empty(): return
	_check(image.get_size() == canvas_size, "%s uses the complete normalized canvas" % description)
	var bounds := _alpha_bounds(image)
	_check(bounds.size.x > 0 and bounds.size.y > 0, "%s has visible alpha >= 0.5" % description)
	if bounds.size.x <= 0 or bounds.size.y <= 0: return
	_check(bounds.position.x > 0 and bounds.position.y > 0 and bounds.end.x < image.get_width() and bounds.end.y < image.get_height(), "%s full >=0.5-alpha silhouette does not touch any canvas edge" % description)

func _assert_projected_feet_touch_their_ground() -> void:
	# A correct root baseline alone cannot prevent a raised neighbour clipping a toe.
	for actor in _world.character_sprites:
		if actor.role != "ticket": continue
		var actor_root := actor.activity_root as Node3D
		var ticket_sprite := actor.sprite as Sprite3D
		var half_width := float(ticket_sprite.texture.get_width()) * ticket_sprite.pixel_size * 0.5
		var middle_ground := ParkWorldScript._ground_surface_y(actor_root.global_position)
		for edge in [-1.0, 1.0]:
			var edge_position := actor_root.global_position + Vector3(edge * half_width, 0, 0)
			_check(is_equal_approx(ParkWorldScript._ground_surface_y(edge_position), middle_ground), "ticket's whole card stays on one ground level")
	var pitch_angles := [deg_to_rad(19.86), deg_to_rad(27.1), deg_to_rad(8.0), deg_to_rad(38.0)]
	for pitch in pitch_angles:
		for heading in range(8):
			var yaw := float(heading) * TAU / 8.0
			var direction := Vector3(sin(yaw) * cos(pitch), -sin(pitch), -cos(yaw) * cos(pitch))
			_world.camera.look_at(_world.camera.global_position + direction,Vector3.UP)
			_world._update_sprite_grounding()
			var camera_up_y: float = _world.camera.global_basis.y.y
			for record in _world.sprite_ground_anchors:
				var sprite := record.sprite as Sprite3D
				var anchor := record.anchor as Node3D
				var parent := record.parent as Node3D
				var feet_row := float(record.feet_row)
				var canvas_height := float(record.canvas_height)
				var projected_foot_y := parent.global_position.y + anchor.position.y + sprite.position.y
				projected_foot_y -= (feet_row - canvas_height * 0.5) * sprite.pixel_size * camera_up_y
				var surface_y := ParkWorldScript._ground_surface_y(parent.global_position)
				_check(absf(projected_foot_y - surface_y) <= 0.001, "%s foot row meets its actual ground mesh at heading %d and pitch %.2f" % [sprite.name,heading,pitch])

func _visible_bottom(texture: Texture2D) -> int:
	_check(texture != null, "authored sprite frame is available")
	if texture == null: return 0
	var image := texture.get_image()
	_check(image != null and not image.is_empty(), "authored sprite frame pixels are readable")
	if image == null or image.is_empty(): return 0
	var used_rect := image.get_used_rect()
	_check(used_rect.size.x > 0 and used_rect.size.y > 0, "authored sprite frame contains visible pixels")
	return used_rect.end.y - 1

func _check(condition: bool, message: String) -> void:
	if condition: return
	_failed = true
	push_error(message)
