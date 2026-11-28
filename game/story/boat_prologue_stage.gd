extends Node3D
## Owns only the temporary ferry actor and reversible presentation state.

const AvatarRenderer = preload("res://game/world/avatar_renderer.gd")
const ACTIONS := ["idle", "interact", "photograph", "wave"]
var preview: Sprite3D
var beat_index := -1
var action := "idle"
var action_elapsed := 0.0
var _idle_elapsed := 0.0
var _action_duration := 0.0
var _world: Node3D
var _player: Node3D
var _camera: Camera3D
var _renderer: RefCounted
var _appearance: Dictionary
var _equipped: Dictionary
var _reduced_motion := false
var _active := false
var _player_visible := true
var _physics_enabled := true
var _camera_transform: Transform3D
var _camera_size := 0.0
var _camera_projection := Camera3D.PROJECTION_ORTHOGONAL
var _last_action := ""
var _last_frame := -1
## Stand-ins the dialogue cues can frame: 阿浪 waiting on the pier, 小角 peeking
## into the shot for one beat, and a point on the island for the viewfinder line.
const PIER_SPOT := Vector3(1.6, 0.0, 22.2)
const PEEK_OFFSET := Vector3(1.0, 0.0, -0.9)
const ISLAND_SPOT := Vector3(0.0, 1.2, -3.0)
var _stand_ins: Dictionary = {}
var _peek_beat := -1
var _island: Marker3D
var _hidden_live: Sprite3D

func configure(world: Node3D, appearance: Dictionary, equipped: Dictionary, reduced_motion: bool) -> bool:
	if _active or not is_instance_valid(world) or world != get_parent() or not is_inside_tree(): return false
	var player := world.get("player") as Node3D
	var camera := world.get("camera") as Camera3D
	var avatar := world.get("avatar") as Sprite3D
	var renderer: Variant = world.get("avatar_renderer")
	var marker := world.get_node_or_null("FerryDeckStageAnchor") as Marker3D
	if not is_instance_valid(player) or not is_instance_valid(camera) or not is_instance_valid(avatar) or not is_instance_valid(marker) or not renderer is AvatarRenderer: return false
	if not is_finite(avatar.pixel_size) or avatar.pixel_size <= 0.0: return false
	var texture: Texture2D = renderer.texture(appearance, equipped, "front", 0, "idle")
	if texture == null: return false
	_world = world
	_player = player
	_camera = camera
	_renderer = renderer
	_appearance = appearance.duplicate(true)
	_equipped = equipped.duplicate(true)
	_reduced_motion = reduced_motion
	_player_visible = player.visible
	_physics_enabled = world.is_physics_processing()
	_camera_transform = camera.transform
	_camera_size = camera.size
	_camera_projection = camera.projection
	beat_index = -1
	action = "idle"
	action_elapsed = 0.0
	_idle_elapsed = 0.0
	_last_action = "idle"
	_last_frame = 0
	_active = true
	world.set_physics_process(false)
	player.visible = false
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 15.5
	var target := world.to_global(Vector3(5.5, 1.0, 24.6))
	camera.global_position = target + Vector3(7.0, 12.0, -18.0)
	camera.look_at(target)
	# Leave the lower frame for the existing dialogue plaque.
	camera.global_position -= camera.global_basis.y * 2.8
	preview = Sprite3D.new()
	preview.name = "FerryTravellerPreview"
	preview.pixel_size = avatar.pixel_size
	preview.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	preview.texture_filter = avatar.texture_filter
	preview.shaded = avatar.shaded
	preview.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	preview.texture = texture
	add_child(preview)
	var feet_offset := (AvatarRenderer.FEET_BASELINE - AvatarRenderer.CANVAS_SIZE.y * 0.5) * preview.pixel_size
	preview.global_position = marker.global_position + camera.global_basis.y.normalized() * feet_offset
	set_process(true)
	return true

## The node a staging cue names on the ferry, made on first use. An action
## ("greet") swaps the stand-in to its greeting pose; any other keeps it at rest.
func actor(id: String, requested_action := "") -> Node3D:
	if not _active: return null
	match id:
		"player": return preview
		"island":
			if not is_instance_valid(_island):
				_island = Marker3D.new()
				_island.name = "FerryIslandView"
				add_child(_island)
				_island.global_position = _world.to_global(ISLAND_SPOT)
			return _island
		"announcer", "imp":
			var stand_in := _stand_in(id)
			if stand_in == null: return null
			if id == "imp" and _peek_beat != beat_index:
				# 小角 only slips into this one beat of the shot.
				_peek_beat = beat_index
				stand_in.global_position = _ground(preview.global_position + PEEK_OFFSET) + Vector3(0, float(stand_in.get_meta("lift")), 0)
				stand_in.visible = true
			if not requested_action.is_empty():
				stand_in.texture = stand_in.get_meta("greet") if requested_action == "greet" else stand_in.get_meta("rest")
			return stand_in
	return null

func _stand_in(role: String) -> Sprite3D:
	if _stand_ins.has(role): return _stand_ins[role]
	var live := _world.call("story_actor", role) as Sprite3D if _world.has_method("story_actor") else null
	if live == null or live.texture == null: return null
	var sprite := Sprite3D.new()
	sprite.name = "Ferry%sStandIn" % role.capitalize()
	sprite.texture = live.texture
	sprite.pixel_size = live.pixel_size
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.shaded = true
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var greet: Variant = _world.call("story_pose", role, "greet") if _world.has_method("story_pose") else null
	if not greet is Texture2D: greet = live.texture
	sprite.set_meta("rest", live.texture)
	sprite.set_meta("greet", greet)
	sprite.set_meta("lift", live.position.y)
	add_child(sprite)
	sprite.global_position = _ground(_world.to_global(PIER_SPOT)) + Vector3(0, live.position.y, 0)
	if role == "announcer":
		# He is on the pier now, so the plaza copy steps out of view until the ferry lands.
		_hidden_live = live
		live.visible = false
	_stand_ins[role] = sprite
	return sprite

func _ground(point: Vector3) -> Vector3:
	if _world.has_method("ground_surface_y"): point.y = float(_world.call("ground_surface_y", point))
	return point

func show_beat(index: int, requested_action: String) -> void:
	if not _active or index <= beat_index or requested_action not in ACTIONS: return
	var peeking: Variant = _stand_ins.get("imp")
	if peeking != null and is_instance_valid(peeking): peeking.visible = false
	if requested_action != "idle" and not _renderer.has_authored_action(requested_action, "front"): return
	beat_index = index
	if _reduced_motion: return
	action = requested_action
	action_elapsed = 0.0
	_action_duration = _renderer.animation_library.sequence_duration("traveller", action, "front") if action != "idle" else 0.0
	if action != "idle" and (not is_finite(_action_duration) or _action_duration <= 0.0): action = "idle"
	_refresh_texture()

func _process(delta: float) -> void:
	if not _active or _reduced_motion: return
	var step := clampf(delta, 0.0, 0.1) if is_finite(delta) else 0.0
	_idle_elapsed += step
	if action != "idle":
		action_elapsed += step
		if action_elapsed >= _action_duration:
			action = "idle"
			action_elapsed = 0.0
	_refresh_texture()

func _refresh_texture() -> void:
	var frame: int = _renderer.idle_frame_for_time("front", _idle_elapsed, _reduced_motion) if action == "idle" else _renderer.animation_library.frame_for_time("traveller", action, "front", action_elapsed, false)
	if action == _last_action and frame == _last_frame: return
	preview.texture = _renderer.texture(_appearance, _equipped, "front", frame, action)
	_last_action = action
	_last_frame = frame

func finish() -> void:
	if not _active: return
	_active = false
	set_process(false)
	if is_instance_valid(_camera):
		_camera.transform = _camera_transform
		_camera.size = _camera_size
		_camera.projection = _camera_projection
	if is_instance_valid(_player): _player.visible = _player_visible
	if is_instance_valid(_world): _world.set_physics_process(_physics_enabled)
	if is_instance_valid(preview): preview.free()
	preview = null
	for stand_in in _stand_ins.values():
		if is_instance_valid(stand_in): stand_in.free()
	_stand_ins.clear()
	if is_instance_valid(_hidden_live): _hidden_live.visible = true
	_hidden_live = null
	if is_instance_valid(_island): _island.free()
	_island = null
	_peek_beat = -1

func _exit_tree() -> void:
	finish()
