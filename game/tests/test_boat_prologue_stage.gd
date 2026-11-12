extends SceneTree

const WorldScript = preload("res://game/world/park_world.gd")
const AvatarRenderer = preload("res://game/world/avatar_renderer.gd")
const SaveGuard = preload("res://game/core/test_save_guard.gd")
var failures: Array[String] = []

class CountingRenderer extends AvatarRenderer:
	var requests := 0
	func texture(appearance: Dictionary, equipped: Dictionary, direction: String = "front", frame: int = 0, action: String = "idle") -> Texture2D:
		requests += 1
		return super.texture(appearance, equipped, direction, frame, action)

func _initialize() -> void:
	if not SaveGuard.validate_save_path(OS.get_environment("SNAPLAND_SAVE_PATH"), OS.get_user_data_dir()).is_empty():
		push_error("Boat stage tests need an absolute isolated SNAPLAND_SAVE_PATH.")
		quit(1)
		return
	call_deferred("_run")

func _run() -> void:
	var stage_script := load("res://game/story/boat_prologue_stage.gd") as GDScript
	_check(stage_script != null and stage_script.can_instantiate(), "reversible ferry stage exists")
	if stage_script == null or not stage_script.can_instantiate():
		_report()
		return
	var world := WorldScript.new()
	root.add_child(world)
	world.set_process(false)
	world.set_physics_process(false)
	var renderer := CountingRenderer.new()
	world.avatar_renderer = renderer
	var marker := world.get_node_or_null("FerryDeckStageAnchor") as Marker3D
	_check(marker != null and marker.position == Vector3(5.5, 1.04, 22.65), "existing ferry owns the forward deck marker")
	if marker == null:
		world.free()
		_report()
		return
	var original_player: Transform3D = world.player.transform
	var original_facing: String = world.facing
	world.camera.transform = Transform3D(Basis.from_euler(Vector3(-0.5, 0.2, 0.1)), Vector3(12, 13, 14))
	world.camera.size = 17.75
	world.camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	var original_camera: Transform3D = world.camera.transform
	var stage: Node3D = stage_script.new()
	world.add_child(stage)
	_check(not stage.configure(null, {}, {}, false), "null world fails safely")
	for property in ["player", "camera", "avatar", "avatar_renderer"]:
		var saved: Variant = world.get(property)
		world.set(property, null)
		_check(not stage.configure(world, {}, {}, false), "missing %s fails safely" % property)
		world.set(property, saved)
		_check(world.camera.transform == original_camera and not world.is_physics_processing() and world.player.visible and stage.get_child_count() == 0, "failed configure changes nothing for %s" % property)
	world.remove_child(marker)
	_check(not stage.configure(world, {}, {}, false), "missing deck marker fails safely")
	world.add_child(marker)
	world.set_physics_process(true)
	var appearance := world.avatar_appearance.duplicate(true)
	var equipped := world.avatar_equipped.duplicate(true)
	_check(stage.configure(world, appearance, equipped, false), "valid world configures")
	stage.set_process(false)
	var staged_camera: Transform3D = world.camera.transform
	_check(not stage.configure(world, appearance, equipped, false) and world.camera.transform == staged_camera and stage.get_child_count() == 1, "active configure cannot duplicate the preview or overwrite restoration")
	_check(not world.player.visible and not world.is_physics_processing(), "stage hides real player and suspends world physics")
	_check(world.player.transform == original_player and world.facing == original_facing, "real location and facing stay untouched")
	var sprite := stage.get_child(0) as Sprite3D
	_check(stage.get_child_count() == 1 and sprite != null, "one complete temporary sprite")
	_check(sprite.pixel_size == world.avatar.pixel_size and sprite.texture == renderer.texture(appearance, equipped, "front", 0, "idle"), "preview shares approved complete textures and original scale")
	var feet := sprite.global_position - world.camera.global_basis.y.normalized() * (AvatarRenderer.FEET_BASELINE - AvatarRenderer.CANVAS_SIZE.y * 0.5) * sprite.pixel_size
	_check(feet.distance_to(marker.global_position) < 0.00001, "feet coincide with marker along camera up")
	var requests := renderer.requests
	stage._process(0.0)
	_check(renderer.requests == requests, "unchanged frame does not request a texture")
	stage._process(0.001)
	_check(renderer.requests == requests, "time within the same cel does not request a texture")
	stage.show_beat(0, "wave")
	stage._process(0.1)
	var elapsed: float = stage.action_elapsed
	stage.show_beat(0, "photograph")
	_check(stage.action == "wave" and stage.action_elapsed == elapsed, "duplicate beat cannot restart or replace action")
	stage.show_beat(-1, "interact")
	_check(stage.action == "wave", "stale beats do not restart actions")
	stage.show_beat(1, "unknown")
	_check(stage.action == "wave", "unknown action safely leaves playback alone")
	stage._process(INF)
	stage._process(NAN)
	_check(is_finite(stage.action_elapsed), "exceptional delta stays finite")
	for action_name in ["interact", "photograph", "wave"]:
		stage.show_beat(stage.beat_index + 1, action_name)
		var duration: float = renderer.animation_library.sequence_duration("traveller", action_name, "front")
		stage._process(0.1)
		var frame: int = renderer.animation_library.frame_for_time("traveller", action_name, "front", 0.1, false)
		_check(sprite.texture == renderer.texture(appearance, equipped, "front", frame, action_name), "%s follows authored frame timing" % action_name)
		for tick in range(ceili(duration / 0.1) + 2): stage._process(0.1)
		_check(stage.action == "idle", "%s returns to idle after finite duration" % action_name)
	for tick in range(500): stage._process(0.05)
	var idle_frame: int = renderer.idle_frame_for_time("front", stage._idle_elapsed, false)
	_check(sprite.texture == renderer.texture(appearance, equipped, "front", idle_frame, "idle"), "idle uses the renderer's authored idle timing")
	_check(stage.get_child_count() == 1 and renderer.cached_texture_count() <= AvatarRenderer.CACHE_LIMIT, "long playback keeps nodes and shared cache bounded")
	stage.finish()
	stage.finish()
	_check(world.camera.transform == original_camera and world.camera.size == 17.75 and world.camera.projection == Camera3D.PROJECTION_PERSPECTIVE, "finish restores exact camera transform size and projection")
	_check(world.player.visible and world.is_physics_processing() and stage.get_child_count() == 0, "idempotent finish restores visibility physics and removes preview")
	_check(world.player.transform == original_player and world.facing == original_facing, "finish preserves original transform and facing")
	world.set_physics_process(false)
	world.player.visible = false
	_check(stage.configure(world, appearance, equipped, true), "stage supports repeat configure with reduced motion")
	stage.set_process(false)
	sprite = stage.get_child(0) as Sprite3D
	var held_texture: Texture2D = sprite.texture
	requests = renderer.requests
	for index in range(20):
		stage.show_beat(index, ["interact", "photograph", "wave"][index % 3])
		stage._process(0.1)
	_check(sprite.texture == held_texture and renderer.requests == requests, "reduced motion holds a fixed approved pose across beats")
	stage.free()
	_check(not world.player.visible and not world.is_physics_processing() and world.camera.transform == original_camera, "external removal restores originally hidden and disabled states")
	world.free()
	_report()

func _check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)

func _report() -> void:
	for failure in failures: push_error("FAIL: " + failure)
	if failures.is_empty(): print("PASS: boat prologue reversible ferry stage, timing, and bounded preview")
	quit(0 if failures.is_empty() else 1)
