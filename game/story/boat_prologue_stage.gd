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

func show_beat(index: int, requested_action: String) -> void:
	if not _active or index <= beat_index or requested_action not in ACTIONS: return
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

func _exit_tree() -> void:
	finish()
