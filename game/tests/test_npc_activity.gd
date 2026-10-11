extends SceneTree

const NpcActivityScript := preload("res://game/world/npc_activity.gd")
const BASE_GESTURE := 0.65

var _test_root: Node3D
var _controller: Node
var _actors: Dictionary = {}
var _anchors: Dictionary = {}
var _materials: Dictionary = {}
var _frames: Dictionary = {}
var _baseline_textures: Dictionary = {}
var _baseline_shader_textures: Dictionary = {}
var _baseline_uv_rects: Dictionary = {}
var _baseline_pixel_sizes: Dictionary = {}
var _points: Dictionary = {}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if OS.get_environment("SNAPLAND_SAVE_PATH").is_empty():
		push_error("SNAPLAND_SAVE_PATH must point to an isolated test save location.")
		quit(1)
		return
	var loaded_ticket_frames: Array[Texture2D] = NpcActivityScript.load_action_frames("ticket")
	var cached_ticket_frames: Array[Texture2D] = NpcActivityScript.load_action_frames("ticket")
	assert(loaded_ticket_frames.size() == 4, "role region manifest loads four authored AtlasTexture frames")
	assert(loaded_ticket_frames[0] == cached_ticket_frames[0] and loaded_ticket_frames[0] is ImageTexture, "normalized ImageTexture resources are cached per role")
	for role in ["ticket", "imp", "announcer"]:
		var role_frames: Array[Texture2D] = NpcActivityScript.load_action_frames(role)
		assert(role_frames.size() == 4, "%s has four authored action frames" % role)
		for frame in role_frames:
			assert(frame is ImageTexture and frame.get_size() == Vector2(320.0, 460.0), "%s frames share a normalized 320x460 canvas" % role)
		assert(role_frames[0] != role_frames[1] and role_frames[1] != role_frames[2] and role_frames[2] != role_frames[3], "%s keeps distinct authored poses" % role)
	assert(NpcActivityScript.load_action_frames("unknown").is_empty(), "unsupported authored-frame role returns no textures")
	_test_root = Node3D.new()
	_test_root.name = "NpcActivityTestRoot"
	root.add_child(_test_root)
	_controller = NpcActivityScript.new()
	_test_root.add_child(_controller)
	for role in ["ticket", "imp", "announcer"]:
		_register_fixture(role)
	for role in ["ticket", "imp", "announcer"]:
		assert(_controller.register_actor(_actors[role], role, _frames[role], _anchors[role], _points[role], float(_actors.size()) * 0.1), "authored %s activity registers" % role)
	assert(not _controller.register_actor(_actors["ticket"], "ticket"), "duplicate target registration is rejected")
	assert(not _controller.register_actor(_actors["imp"], "unsupported"), "unsupported role is rejected")
	_controller.finish_registration()
	await process_frame
	assert(bool(_controller.statistics().playing), "one native AnimationPlayer runs the authored role tracks")
	assert(int(_controller.statistics().registration_count) == 3, "all named roles remain registered")
	assert(int(_controller.statistics().by_role.get("ticket", 0)) == 1 and int(_controller.statistics().by_role.get("imp", 0)) == 1 and int(_controller.statistics().by_role.get("announcer", 0)) == 1, "role counts remain distinct")
	assert(_has_track_with_suffix(":texture"), "authored textures are switched by native value tracks")
	assert(_has_track_with_suffix(":position") and _has_track_with_suffix(":flip_h"), "announcer path and facing are native animation tracks")
	assert(_has_track_with_suffix("shader_parameter/texture_albedo") and _has_track_with_suffix("shader_parameter/uv_rect"), "native tracks keep Sprite3D and shader textures synchronized and use normalized UVs")
	for role in ["ticket", "imp", "announcer"]:
		assert(_actors[role].texture == _materials[role].get_shader_parameter("texture_albedo"), "%s begins with matching sprite and shader frame textures" % role)
		assert(_materials[role].get_shader_parameter("uv_rect") == Vector4(0.0, 0.0, 1.0, 1.0), "%s uses full-canvas UVs for normalized frames" % role)
		assert(is_equal_approx(_actors[role].pixel_size, 2.4 / 420.0), "%s renders its 420-pixel visible body at 2.4 world units" % role)
	var baseline_position: Vector3 = _anchors["announcer"].position
	_seek_from_start(2.41)
	assert(_actors["ticket"].texture == _frames["ticket"][0], "ticket plays the authored service sequence after its idle hold")
	_assert_shader_texture_matches("ticket", 0)
	_seek_from_start(2.61)
	assert(_actors["ticket"].texture == _frames["ticket"][1], "ticket service sequence advances through source atlas frames")
	_assert_shader_texture_matches("ticket", 1)
	_seek_from_start(0.31)
	assert(_actors["imp"].texture == _frames["imp"][1], "imp cycles through authored dance poses")
	_assert_shader_texture_matches("imp", 1)
	_seek_from_start(0.21)
	assert(_actors["announcer"].texture == _frames["announcer"][1], "announcer cycles through authored walking poses")
	_assert_shader_texture_matches("announcer", 1)
	_seek_from_start(1.2)
	_controller._process(0.0)
	assert(is_equal_approx(_anchors["announcer"].position.x, baseline_position.x + 0.6), "announcer route reaches but does not exceed the open-side bound")
	assert(is_equal_approx(_anchors["announcer"].position.y, baseline_position.y) and is_equal_approx(_actors["announcer"].position.y, 1.2), "side steps keep the anchor and sprite foot height fixed")
	assert(is_equal_approx(float(_points["announcer"].position.x), _anchors["announcer"].global_position.x), "interaction target follows the moving actor root")
	_seek_from_start(4.2)
	_controller._process(0.0)
	assert(is_equal_approx(_anchors["announcer"].position.x, baseline_position.x - 0.6), "announcer route returns to the opposite bounded side")
	_controller.set_activity_paused(true)
	assert(not bool(_controller.statistics().playing) and bool(_controller.statistics().activity_paused), "modal pause freezes all ambient NPC activity")
	_controller.set_activity_paused(false)
	assert(bool(_controller.statistics().playing), "unpause resumes registered activity")
	_controller.set_reduced_motion(true)
	assert(not bool(_controller.statistics().playing), "reduced motion stops all idle action tracks")
	for role in ["ticket", "imp", "announcer"]:
		assert(_actors[role].texture == _baseline_textures[role], "%s keeps its clear baseline pose" % role)
		assert(not bool(_actors[role].flip_h), "%s restores its authored facing" % role)
		assert(is_equal_approx(float(_actors[role].pixel_size), float(_baseline_pixel_sizes[role])), "%s restores its baseline scale" % role)
		assert(_materials[role].get_shader_parameter("texture_albedo") == _baseline_shader_textures[role], "%s restores its shader texture" % role)
		assert(_materials[role].get_shader_parameter("uv_rect") == _baseline_uv_rects[role], "%s restores its shader UV rectangle" % role)
	assert(_anchors["announcer"].position == baseline_position and _points["announcer"].position == baseline_position, "reduced motion restores actor root and interaction point")
	_controller.set_reduced_motion(false)
	assert(bool(_controller.statistics().playing), "normal motion replays the animation after reduced mode")
	_actors["imp"].queue_free()
	await process_frame
	assert(int(_controller.statistics().registration_count) == 2 and int(_controller.statistics().by_role.get("imp", 0)) == 0, "freed actor clears its role registration")
	assert(_materials["imp"].get_shader_parameter("gesture_pixels") == BASE_GESTURE, "removed actor material returns to its baseline")
	_controller.release()
	assert(int(_controller.statistics().registration_count) == 0 and not bool(_controller.statistics().playing), "release stops playback and clears registrations")
	_test_root.queue_free()
	await process_frame
	print("PASS: NPC activity runtime checks")
	quit(0)


func _register_fixture(role: String) -> void:
	var anchor := Node3D.new()
	anchor.name = "ActivityRoot_" + role
	anchor.position = Vector3(4.0, 0.0, -20.0) if role == "announcer" else Vector3.ZERO
	_test_root.add_child(anchor)
	var sprite := Sprite3D.new()
	sprite.name = "Actor_" + role
	sprite.position = Vector3(0.0, 1.2, 0.0)
	sprite.flip_h = false
	anchor.add_child(sprite)
	var original_image := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	original_image.fill(Color.WHITE)
	sprite.texture = ImageTexture.create_from_image(original_image)
	var material := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = "shader_type spatial; uniform sampler2D texture_albedo; uniform vec4 uv_rect = vec4(0.0, 0.0, 1.0, 1.0); uniform float gesture_pixels = 0.65; void fragment() { ALBEDO = texture(texture_albedo, UV).rgb; }"
	material.shader = shader
	material.set_shader_parameter("gesture_pixels", BASE_GESTURE)
	material.set_shader_parameter("texture_albedo", sprite.texture)
	material.set_shader_parameter("uv_rect", Vector4(0.25, 0.25, 0.5, 0.5))
	sprite.material_override = material
	var frames: Array[Texture2D] = NpcActivityScript.load_action_frames(role)
	var name_label := Label3D.new()
	name_label.name = "Name_" + role
	name_label.position = Vector3(0.0, 2.65, 0.0)
	anchor.add_child(name_label)
	var point := {"id": role, "position": anchor.global_position}
	_anchors[role] = anchor
	_actors[role] = sprite
	_materials[role] = material
	_points[role] = point
	_frames[role] = frames
	_baseline_textures[role] = sprite.texture
	_baseline_shader_textures[role] = material.get_shader_parameter("texture_albedo")
	_baseline_uv_rects[role] = material.get_shader_parameter("uv_rect")
	_baseline_pixel_sizes[role] = sprite.pixel_size
	# The world point dictionary is retained by reference by the controller.
	_points[role] = point


func _has_track_with_suffix(suffix: String) -> bool:
	for track_index in range(_controller._animation.get_track_count()):
		if String(_controller._animation.track_get_path(track_index)).ends_with(suffix):
			return true
	return false


func _seek_from_start(seconds: float) -> void:
	_controller._player.seek(0.0, true)
	_controller._player.advance(seconds)


func _assert_shader_texture_matches(role: String, frame_index: int) -> void:
	assert(_actors[role].texture == _frames[role][frame_index], "%s Sprite3D frame is authored frame %d" % [role, frame_index])
	assert(_materials[role].get_shader_parameter("texture_albedo") == _frames[role][frame_index], "%s material samples the same authored frame %d" % [role, frame_index])
	assert(_materials[role].get_shader_parameter("uv_rect") == Vector4(0.0, 0.0, 1.0, 1.0), "%s samples its normalized full-canvas image" % role)
