extends SceneTree

const NpcActivityScript := preload("res://game/world/npc_activity.gd")

class MissingAnimationLibrary:
	extends RefCounted

	func get_sequence(_actor: String, _action: String, _direction: String) -> Dictionary:
		return {}

	func coverage_report() -> Dictionary:
		return {"ticket": {}, "imp": {}, "announcer": {}}

var _scene: Node3D
var _controller: Node
var _actors: Dictionary = {}
var _anchors: Dictionary = {}
var _materials: Dictionary = {}
var _frames: Dictionary = {}
var _baseline_textures: Dictionary = {}
var _baseline_uvs: Dictionary = {}
var _baseline_pixel_sizes: Dictionary = {}
var _points: Dictionary = {}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if OS.get_environment("SNAPLAND_SAVE_PATH").is_empty():
		push_error("SNAPLAND_SAVE_PATH must point to an isolated test save location.")
		quit(1)
		return
	var ticket_frames := NpcActivityScript.load_action_frames("ticket")
	assert(ticket_frames.size() == 4, "ticket legacy frames remain available as an explicit fallback")
	assert(ticket_frames[0] == NpcActivityScript.load_action_frames("ticket")[0], "normalized fallback textures are cached")
	for role in ["ticket", "imp", "announcer"]:
		var frames: Array[Texture2D] = NpcActivityScript.load_action_frames(role)
		assert(frames.size() == 4, "%s retains its four-frame fallback" % role)
		for frame in frames:
			assert(frame is ImageTexture and frame.get_size() == Vector2(320, 460), "%s fallback stays on the normalized 320x460 canvas" % role)
		assert(frames[0] != frames[1] and frames[1] != frames[2] and frames[2] != frames[3], "%s keeps distinct source poses" % role)
	assert(NpcActivityScript.load_action_frames("unknown").is_empty(), "unsupported fallback role returns no textures")
	_scene = Node3D.new()
	root.add_child(_scene)
	_controller = NpcActivityScript.new()
	_scene.add_child(_controller)
	_controller._animation_library = MissingAnimationLibrary.new()
	for role in ["ticket", "imp", "announcer"]:
		_register_fixture(role)
	for role in ["ticket", "imp", "announcer"]:
		assert(_controller.register_actor(_actors[role], role, _frames[role], _anchors[role], _points[role], float(_actors.size()) * 0.1), "%s registers with its preserved legacy fallback" % role)
	assert(not _controller.register_actor(_actors.ticket, "ticket"), "duplicate registration is rejected")
	assert(not _controller.register_actor(_actors.imp, "unsupported"), "unsupported role is rejected")
	_controller.finish_registration()
	await process_frame
	assert(_controller.statistics().registration_count == 3, "the three NPC roles remain registered")
	for role in ["ticket", "imp", "announcer"]:
		assert(_actors[role].texture == _baseline_textures[role], "%s uses its original full sprite while authored stand is missing" % role)
		assert(is_equal_approx(_actors[role].pixel_size, _baseline_pixel_sizes[role]), "%s keeps its original pixel size" % role)
		assert(_materials[role].get_shader_parameter("texture_albedo") == _baseline_textures[role], "%s preserves its shader texture" % role)
		assert(_materials[role].get_shader_parameter("uv_rect") == _baseline_uvs[role], "%s preserves its shader UV rectangle" % role)
	assert(not _controller.coverage_report().missing_requests.ticket.is_empty(), "missing authored stand and action coverage is explicit")
	var route_start: Vector3 = _anchors.announcer.position
	_controller._player.seek(0.0, true)
	_controller._player.advance(1.2)
	_controller._process(0.0)
	assert(_anchors.announcer.position == route_start, "announcer does not glide when directional walk frames are missing")
	assert(_points.announcer.position == _anchors.announcer.global_position, "the interaction point remains attached to its stationary safe fallback")
	_controller.set_activity_paused(true)
	var paused_anchor: Vector3 = _anchors.announcer.position
	_controller._process(2.0)
	assert(_anchors.announcer.position == paused_anchor and _controller.statistics().activity_paused, "modal pause freezes the scene route timeline")
	_controller.set_activity_paused(false)
	_controller.set_reduced_motion(true)
	for role in ["ticket", "imp", "announcer"]:
		assert(_actors[role].texture == _baseline_textures[role] and is_equal_approx(_actors[role].pixel_size, _baseline_pixel_sizes[role]), "%s restores the original visual for reduced motion" % role)
		assert(_materials[role].get_shader_parameter("uv_rect") == _baseline_uvs[role], "%s restores its original UV rectangle" % role)
	assert(_anchors.announcer.position == route_start and _points.announcer.position == route_start, "reduced motion restores the original route root and interaction point")
	_controller.set_reduced_motion(false)
	assert(_controller.statistics().playing, "normal activity resumes after reduced motion")
	_actors.imp.queue_free()
	await process_frame
	assert(_controller.statistics().registration_count == 2 and _controller.statistics().by_role.get("imp", 0) == 0, "removed actor clears its role registration")
	_controller.release()
	assert(_controller.statistics().registration_count == 0 and not _controller.statistics().playing, "release stops playback and clears registrations")
	_scene.queue_free()
	await process_frame
	print("PASS: NPC activity runtime checks (role registration, safe fallback, route gating, pause, and cleanup)")
	quit(0)


func _register_fixture(role: String) -> void:
	var anchor := Node3D.new()
	anchor.name = "ActivityRoot_" + role
	anchor.position = Vector3(4, 0, -20) if role == "announcer" else Vector3.ZERO
	_scene.add_child(anchor)
	var sprite := Sprite3D.new()
	sprite.name = "Actor_" + role
	sprite.position.y = 1.2
	anchor.add_child(sprite)
	var image := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	sprite.texture = ImageTexture.create_from_image(image)
	var material := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = "shader_type spatial; uniform sampler2D texture_albedo; uniform vec4 uv_rect = vec4(0.0,0.0,1.0,1.0); uniform float gesture_pixels=0.65; void fragment(){ ALBEDO=texture(texture_albedo,UV).rgb; }"
	material.shader = shader
	material.set_shader_parameter("texture_albedo", sprite.texture)
	material.set_shader_parameter("uv_rect", Vector4(0.25, 0.25, 0.5, 0.5))
	sprite.material_override = material
	var point := {"position": anchor.global_position}
	_anchors[role] = anchor
	_actors[role] = sprite
	_materials[role] = material
	_frames[role] = NpcActivityScript.load_action_frames(role)
	_baseline_textures[role] = sprite.texture
	_baseline_uvs[role] = material.get_shader_parameter("uv_rect")
	_baseline_pixel_sizes[role] = sprite.pixel_size
	_points[role] = point
