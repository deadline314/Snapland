extends Node
## Optional two-view NPC gait adapter. It consumes the actor root's measured
## post-route displacement; it never translates the actor itself.

const Rig = preload("res://game/world/avatar_motion_rig.gd")
const Provider = preload("res://game/world/npc_motion_sources.gd")
const ACTIVITY_CANVAS_SIZE := Vector2(320.0, 460.0)
const ACTIVITY_FEET_ROW := 448.0
const FOOT_GUARD_PIXELS := 1.0
const FOOT_VISIBLE_ALPHA_THRESHOLD := 0.5
const FOOT_SAMPLE_CACHE_LIMIT := 64

var actor_root: Node3D
var source_sprite: Sprite3D
var role := ""
var camera: Camera3D
var ground_height: Callable
var rig
var enabled := false
var paused := false
var supported := false
var active := false
var last_position := Vector3.ZERO
var stationary_elapsed := 0.0
var diagnostics: Array[String] = []
var source_provider: RefCounted
var original_sprite_pixel_size := 0.0
var original_sprite_position := Vector3.ZERO
var original_anchor_position := Vector3.ZERO
var front_body_height_px := 0
var calibrated_sprite_pixel_size := 0.0
var target_body_height_px := 0
var foot_samples_cache: Dictionary = {}
var foot_samples_order: Array[int] = []
var foot_clearance_y := 0.0

func configure(root: Node3D, sprite: Sprite3D, actor_role: String, view_camera: Camera3D, ground: Callable) -> bool:
	actor_root = root
	source_sprite = sprite
	original_sprite_pixel_size = sprite.pixel_size
	original_sprite_position = sprite.position
	original_anchor_position = root.position
	role = actor_role
	camera = view_camera
	ground_height = ground
	if role not in ["ticket", "imp", "announcer"] or not is_instance_valid(root) or not is_instance_valid(sprite) or not ground.is_valid():
		diagnostics.append("%s has no approved measured two-view gait source" % role)
		return false
	var provider = Provider.new()
	source_provider = provider
	var role_data: Dictionary = provider.measurements_for(role)
	var left: Dictionary = provider.direction_measurement(role,"left")
	var right: Dictionary = provider.direction_measurement(role,"right")
	if role_data.is_empty() or left.is_empty() or right.is_empty():
		diagnostics.append("%s requires measured left and right source records" % role)
		return false
	var left_scale := float(left.get("leg_measurement",{}).get("leg_length_scale",0.0))
	var right_scale := float(right.get("leg_measurement",{}).get("leg_length_scale",0.0))
	if left_scale<0.35 or right_scale<0.35:
		diagnostics.append("%s has invalid measured leg length" % role)
		return false
	var created_rig: Variant = Rig.new()
	rig = created_rig
	rig.name = "OptionalMeasuredGait"
	rig.role = role
	rig.metadata_path = Provider.METADATA_PATH
	var measured_views: Array[String] = ["left","right"]
	rig.required_directions = measured_views
	rig.leg_length_scale = (left_scale+right_scale)*0.5
	rig.source_provider = Callable(source_provider,"provide")
	rig.ground_height_provider = ground_height
	# Configuration can span ready callbacks before the first route update.
	# Never expose the candidate rig until measured movement activates it.
	rig.visible = false
	root.add_child(rig)
	rig.position = _ground_local_position()
	if is_instance_valid(camera):
		_sync_projection(true)
	var records: Dictionary = rig.source_records
	supported = records.has("left") and records.has("right") and bool(records.left.get("valid",false)) and bool(records.right.get("valid",false))
	if not supported:
		for message in rig.diagnostics: diagnostics.append(message)
		rig.cleanup()
		rig.queue_free()
		rig = null
		return false
	target_body_height_px = int(role_data.get("target_body_height_px", 0))
	front_body_height_px = _strong_alpha_height(sprite.texture)
	if target_body_height_px <= 0 or front_body_height_px <= 0:
		diagnostics.append("%s front sprite has no measurable opaque body height" % role)
		rig.cleanup()
		rig.queue_free()
		rig = null
		supported = false
		return false
	calibrated_sprite_pixel_size = float(target_body_height_px) * Rig.PIXEL_SIZE / float(front_body_height_px)
	_calibrate_front_sprite()
	last_position = root.global_position
	rig.cancel_motion()
	return true

func set_enabled(value: bool) -> void:
	enabled = value and supported
	if not enabled:
		_deactivate()

func set_paused(value: bool) -> void:
	paused = value
	if is_instance_valid(actor_root): last_position = actor_root.global_position
	if paused:
		if is_instance_valid(rig): rig.cancel_motion()
		_deactivate()

func update(delta: float, held: bool = false, paused: bool = false) -> void:
	if not supported or not is_instance_valid(actor_root) or not is_instance_valid(rig): return
	var current := actor_root.global_position
	var displacement := current-last_position
	var horizontal := Vector3(displacement.x,0,displacement.z)
	if is_instance_valid(camera): _sync_projection(false)
	_sync_front_ground_anchor()
	rig.global_position = actor_root.to_global(_ground_local_position())
	if not enabled or paused:
		if enabled and not paused: rig.advance_from_motion(delta,Vector3.ZERO,false)
		elif enabled: rig.cancel_motion()
		last_position = current
		_deactivate()
		return
	if held:
		# Preserve any current authored gesture while route and root movement hold.
		last_position = current
		rig.advance_from_motion(delta,Vector3.ZERO,false)
		_deactivate()
		return
	if horizontal.length()>0.0001:
		stationary_elapsed = 0.0
		var right_axis := camera.global_basis.x if is_instance_valid(camera) else Vector3.RIGHT
		var view := "right" if horizontal.dot(right_axis)>=0.0 else "left"
		rig.set_direction(view)
		rig.advance_from_motion(delta,displacement,false)
		# Any real post-route movement should switch to the gait. A per-frame
		# threshold here would suppress the measured slow-walk speed at 60 Hz.
		_activate()
	else:
		stationary_elapsed += delta
		rig.advance_from_motion(delta,Vector3.ZERO,false)
		if stationary_elapsed>=0.24: _deactivate()
	last_position = current

func close() -> void:
	_deactivate()
	if is_instance_valid(rig):
		# Rig.cleanup() now avoids the transform-dependent pose when detached,
		# while still clearing its measured source/material caches.
		rig.cleanup()
		rig.queue_free()
	if is_instance_valid(source_sprite):
		source_sprite.pixel_size = original_sprite_pixel_size
		source_sprite.position = original_sprite_position
		if source_sprite.has_meta("npc_foot_clearance_y"):
			source_sprite.set_meta("npc_foot_clearance_y",0.0)
	if is_instance_valid(actor_root): actor_root.position.y = original_anchor_position.y
	rig = null
	supported = false
	actor_root = null
	source_sprite = null
	ground_height = Callable()
	source_provider = null
	foot_samples_cache.clear()
	foot_samples_order.clear()
	foot_clearance_y = 0.0

func _strong_alpha_height(texture: Texture2D) -> int:
	if texture == null: return 0
	var image := texture.get_image()
	if image == null or image.is_empty(): return 0
	var top := image.get_height()
	var bottom := -1
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if roundi(image.get_pixel(x,y).a*255.0) >= 128:
				top = mini(top,y)
				bottom = maxi(bottom,y)
	if bottom < top: return 0
	return bottom-top+1

func _calibrate_front_sprite() -> void:
	if not is_instance_valid(source_sprite) or not is_instance_valid(actor_root): return
	var camera_up := camera.global_basis.y if is_instance_valid(camera) else Vector3.UP
	var foot_offset := (ACTIVITY_FEET_ROW-ACTIVITY_CANVAS_SIZE.y*0.5)*calibrated_sprite_pixel_size
	var root_world := actor_root.global_position
	var ground_y := float(ground_height.call(Vector2(root_world.x,root_world.z)))
	root_world.y = ground_y
	actor_root.global_position = root_world
	source_sprite.pixel_size = calibrated_sprite_pixel_size
	_sync_front_ground_anchor()

func _sync_front_ground_anchor() -> void:
	if not is_instance_valid(source_sprite) or not is_instance_valid(actor_root) or not ground_height.is_valid(): return
	var root_world := actor_root.global_position
	var ground_y := float(ground_height.call(Vector2(root_world.x,root_world.z)))
	var camera_up := camera.global_basis.y if is_instance_valid(camera) else Vector3.UP
	var camera_right := camera.global_basis.x if is_instance_valid(camera) else Vector3.RIGHT
	var foot_offset := (ACTIVITY_FEET_ROW-ACTIVITY_CANVAS_SIZE.y*0.5)*source_sprite.pixel_size
	# Sprite3D's billboard plane follows the whole camera-up vector. Keeping only
	# its Y component moves the visible feet in X/Z as soon as the camera tilts.
	var clearance := _required_foot_clearance(ground_y,camera_up,camera_right,foot_offset)
	foot_clearance_y = clearance
	if source_sprite.has_meta("npc_world_ground_anchor_managed"):
		source_sprite.set_meta("npc_foot_clearance_y",clearance)
	var world_offset := camera_up*foot_offset + Vector3(0.0,ground_y-root_world.y+FOOT_GUARD_PIXELS*source_sprite.pixel_size+clearance,0.0)
	_set_front_sprite_offset(world_offset)

func _required_foot_clearance(ground_y: float, camera_up: Vector3, camera_right: Vector3, foot_offset: float) -> float:
	if not is_instance_valid(source_sprite) or source_sprite.texture == null or not ground_height.is_valid(): return 0.0
	var texture_id := source_sprite.texture.get_instance_id()
	if not foot_samples_cache.has(texture_id):
		var samples := _build_foot_samples(source_sprite.texture)
		foot_samples_cache[texture_id] = samples
		foot_samples_order.append(texture_id)
		if foot_samples_order.size()>FOOT_SAMPLE_CACHE_LIMIT:
			var expired: int = foot_samples_order.pop_front()
			foot_samples_cache.erase(expired)
	var samples: PackedVector2Array = foot_samples_cache[texture_id]
	if samples.is_empty(): return 0.0
	var origin := Vector3(actor_root.global_position.x,ground_y,actor_root.global_position.z)
	var required := 0.0
	for sample in samples:
		var point := origin + camera_up*(foot_offset+sample.y*source_sprite.pixel_size) + camera_right*(sample.x*source_sprite.pixel_size)
		var surface_y := float(ground_height.call(Vector2(point.x,point.z)))
		required = maxf(required,surface_y-point.y+FOOT_GUARD_PIXELS*source_sprite.pixel_size)
	return maxf(0.0,required)

func _build_foot_samples(texture: Texture2D) -> PackedVector2Array:
	var samples := PackedVector2Array()
	if texture == null: return samples
	var image := texture.get_image()
	if image == null or image.is_empty(): return samples
	var width := image.get_width(); var height := image.get_height()
	for x in range(width):
		for y in range(maxi(0,int(ACTIVITY_FEET_ROW)-8),height):
			if image.get_pixel(x,y).a >= FOOT_VISIBLE_ALPHA_THRESHOLD:
				samples.append(Vector2(float(x)+0.5-float(width)*0.5,float(height)*0.5-float(y)-0.5))
	return samples

func _set_front_sprite_offset(world_offset: Vector3) -> void:
	if not is_instance_valid(source_sprite): return
	var sprite_parent := source_sprite.get_parent() as Node3D
	if is_instance_valid(sprite_parent):
		# Work in the Sprite's parent space so nested anchors and rotated/scaled
		# actor roots still place the billboard's foot row at the world anchor.
		if source_sprite.has_meta("npc_world_ground_anchor_managed"):
			source_sprite.position = sprite_parent.global_basis.inverse() * world_offset
		else:
			var desired_world_position := actor_root.global_position+world_offset
			source_sprite.position = sprite_parent.to_local(desired_world_position)
	else:
		source_sprite.position = world_offset

func _activate() -> void:
	if active: return
	active = true
	rig.visible = true
	source_sprite.visible = false

func _deactivate() -> void:
	if not active and (not is_instance_valid(rig) or not rig.visible) and (not is_instance_valid(source_sprite) or source_sprite.visible): return
	active = false
	if is_instance_valid(rig): rig.visible = false
	if is_instance_valid(source_sprite): source_sprite.visible = true

func _ground_local_position() -> Vector3:
	if not is_instance_valid(actor_root): return Vector3.ZERO
	var world := actor_root.global_position
	var y := float(ground_height.call(Vector2(world.x,world.z))) if ground_height.is_valid() else world.y
	return actor_root.to_local(Vector3(world.x,y,world.z))

func _sync_projection(discontinuous: bool) -> void:
	if not is_instance_valid(camera) or not is_instance_valid(rig): return
	var basis := camera.global_basis
	rig.set_view_projection(basis,atan2(basis.z.x,basis.z.z),discontinuous)
