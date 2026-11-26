extends Node

const Scene = preload("res://game/main.tscn")
const Guard = preload("res://game/core/test_save_guard.gd")
const PlaybackRelease = preload("res://game/tests/audio_playback_release.gd")
const Visit = preload("res://game/story/regional_visit.gd")
const PhotoPanel = preload("res://game/ui/regional_visit_photo_panel.gd")
const ACTIONS := ["move_left", "move_right", "move_up", "move_down"]

var _main: Node
var _failures: Array[String] = []
var _checks := 0

func _ready() -> void:
	if not Guard.validate_save_path(OS.get_environment("SNAPLAND_SAVE_PATH"), OS.get_user_data_dir()).is_empty():
		push_error("Garden story tests require an isolated save path.")
		get_tree().quit(1)
		return
	_run.call_deferred()

func _run() -> void:
	Progress.reset_progress()
	Progress.intro_seen = true
	Progress.prologue_seen = true
	Progress.settings.master_volume = 0.0
	Progress.settings.ui_scale = 1.25
	for region in ["welcome", "harbor", "candy"]:
		var total := 6 if region == "candy" else 12
		for number in range(1, total + 1):
			Progress.photos["photo-%s-game-%d" % [region, number]] = {"fixture": true}
	_check(Progress.normal_count() == 30 and Progress.set_current_region(Visit.GARDEN), "Garden visit uses ordinary admission")
	_main = Scene.instantiate()
	get_tree().root.add_child(_main)
	await _frames(8)
	var world: Node = _main.world
	var mark: Dictionary = world._point_by_id(Visit.GARDEN_POINT)
	var host: Dictionary = world._npc_record_for_role("ticket")
	if _check(not mark.is_empty() and mark.position == world.STORY_POINT and host.get("activity_root") != null
		and host.activity_root.position == world.STORY_HOST and host.name_label.text == "票票", "new point is beside the real authored greeter"):
		if await _opening_then_cancel(world, mark):
			await _complete_and_replay(world)
	await _finish()

func _opening_then_cancel(world: Node, mark: Dictionary) -> bool:
	if not await _choose_bed(world, 1) or not await _reach_host(world):
		return false
	world.interact()
	if not _check(_main.modal_kind == "dialogue" and _main.dialogue[0].speaker == "票票"
		and _main.dialogue[0].text.contains("盆栽先坐到頭排") and _main.dialogue[2].text.contains("首演"),
		"physical greeting opens the localized greenhouse joke and premiere clue"):
		return false
	var before_light := _light_state(world)
	var pose := _live_pose(world)
	var hidden := world.local_sign_labels[0] as Label3D
	hidden.hide()
	var marker: Label3D = mark.marker
	var skip: Button = _main.dialogue_panel.cancel_button
	_check(skip.text == "略過到合照", "localized skip offers the actual picture")
	skip.pressed.emit()
	if not _check(_main.modal_kind == "visit_photo" and world._story_camera.is_current(), "skip enters the live Garden frame"):
		return false
	var guest := world._story_camera.get_node_or_null("GardenStoryGuest") as Sprite3D
	_check(not world.player.visible and not marker.visible and world._story_host_sprite.texture == world._story_host_greeting
		and guest != null and guest.texture == world.avatar_renderer.texture(world.avatar_appearance, world.avatar_equipped, "front", 0, "photograph"),
		"portrait uses real greeter and installed traveller outfit while hiding interaction UI")
	_check(world._story_host_root.position == world.STORY_PORTRAIT_HOST and not world._foyer_sign[0].visible,
		"portrait briefly clears the active bed and foreground plaque")
	await _check_framing(world)
	_check(_light_state(world) == before_light and _live_pose(world) == pose,
		"staying in the portrait preserves player and actual lit bed")
	_main.visit_photo_panel.find_child("StoryPhotoCancel", true, false).pressed.emit()
	_check(_main.modal_kind == "" and world.camera.is_current() and world.player.visible and not hidden.visible
		and _live_pose(world) == pose and _light_state(world) == before_light and world._story_host_sprite.texture == world._story_host_still
		and world._story_host_root.position == world.STORY_HOST and world._foyer_sign[0].visible,
		"cancel restores the exact player, label visibility, walking camera and bed")
	_check(not Progress.photos.has(Visit.GARDEN_PHOTO) and not Progress.visited.has(Visit.GARDEN), "cancel creates neither a card nor a visit")
	return true

func _complete_and_replay(world: Node) -> void:
	Progress.set_setting("reduced_motion", true)
	if not await _choose_bed(world, 2) or not await _reach_host(world):
		return
	world.interact()
	for page in Visit.lines(Visit.GARDEN).size() * 2:
		if _main.modal_kind == "dialogue":
			_main._next_dialogue()
	if not _check(_main.modal_kind == "visit_photo" and world.illuminated_bed() == 2 and not world.louver_is_moving(),
		"reading every panel reaches the same portrait with the different east bed in reduced motion"):
		return
	var before := _live_pose(world)
	var before_light := _light_state(world)
	await _check_framing(world)
	var rewards := [Progress.coins, Progress.achievements.duplicate(true), Progress.wardrobe_rewarded_games.duplicate()]
	_main.visit_photo_panel.find_child("StoryPhotoShutter", true, false).pressed.emit()
	await _frames(2)
	_check(not Progress.photos.has(Visit.GARDEN_PHOTO) and not Progress.visited.has(Visit.GARDEN),
		"unavailable headless image never grants the Garden visit")
	var image := Image.create(640, 360, false, Image.FORMAT_RGBA8)
	image.fill(Color("#6e845e"))
	if not _check(_main._save_region_story_photo(Visit.GARDEN, Visit.GARDEN_PHOTO, image), "isolated pixel fixture exercises the real atomic writer"):
		return
	var record: Dictionary = Progress.photos[Visit.GARDEN_PHOTO].duplicate(true)
	var original: String = record.original_frames[0]
	var original_hash := FileAccess.get_sha256(original)
	var save_path := OS.get_environment("SNAPLAND_SAVE_PATH")
	var save_hash := FileAccess.get_sha256(save_path)
	_check(Progress.normal_count() == 31 and Progress.normal_count_for_zone(Visit.GARDEN) == 1 and Progress.visited.get(Visit.GARDEN) == true
		and not original_hash.is_empty() and rewards == [Progress.coins, Progress.achievements, Progress.wardrobe_rewarded_games],
		"one ordinary Garden card and one visit save with no unrelated reward")
	_check(Progress.record_region_story_visit(Visit.GARDEN, "", "") and FileAccess.get_sha256(save_path) == save_hash, "duplicate registration keeps the profile bytes")
	_main._exit_region_story_photo()
	Progress.load_progress()
	_check(Progress.photos.get(Visit.GARDEN_PHOTO) == record and Progress.visited.get(Visit.GARDEN) == true, "reloading keeps the initial photo and visit")
	_main._show_album()
	if not _open_replay():
		return
	_main.dialogue_panel.cancel_button.pressed.emit()
	_check(_main.modal_kind == "visit_photo" and _main.visit_photo_from_album and _light_state(world) == before_light
		and _live_pose(world) == before, "on-site album replay preserves the real east bed and same standing position")
	_main._exit_region_story_photo()
	_check(_main.modal_kind == "album" and Progress.photos[Visit.GARDEN_PHOTO] == record
		and FileAccess.get_sha256(original) == original_hash, "replay returns to the album and keeps the first original")

func _open_replay() -> bool:
	var tile := _main.overlay.find_child("AlbumPhoto_" + Visit.GARDEN_PHOTO, true, false) as Button
	if not _check(tile != null, "Garden album shows its real story photo"):
		return false
	tile.pressed.emit()
	var replay := _main.overlay.find_child("PhotoViewerReplayStory", true, false) as Button
	if not _check(replay != null, "saved original opens the replay entry"):
		return false
	replay.pressed.emit()
	return true

func _check_framing(world: Node) -> void:
	var root := get_tree().root
	var camera: Camera3D = world._story_camera
	for size in [Vector2i(800, 600), Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.content_scale_size = size
		root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
		root.size = size
		await _frames(3)
		var frame := PhotoPanel.viewfinder_rect(root.get_visible_rect().size)
		for at: Vector3 in [world.STORY_PORTRAIT_HOST, world.STORY_GUEST]:
			_check(frame.grow(-4.0).has_point(camera.unproject_position(at)) and frame.grow(-4.0).has_point(camera.unproject_position(at + Vector3.UP * 2.42)),
				"both complete actors fit in the portrait at %s" % size)
		for position: Vector3 in world.map_snapshot().beds:
			_check(frame.grow(-5.0).has_point(camera.unproject_position(position)), "each actual plant bed can appear in the portrait at %s" % size)
		for blade_index in [0, 6]:
			var blade := world.get_node("GardenSunRack/GardenSlat_%d" % blade_index) as MeshInstance3D
			var visible := true
			for corner in 8:
				if not frame.grow(-4.0).has_point(camera.unproject_position(blade.to_global(blade.get_aabb().get_endpoint(corner)))):
					visible = false
			_check(visible, "both extreme blades fit with the live detent at %s" % size)
		for name in ["StoryPhotoCancel", "StoryPhotoShutter"]:
			var button := _main.visit_photo_panel.find_child(name, true, false) as Control
			_check(button != null and root.get_visible_rect().grow(1.0).encloses(button.get_global_rect())
				and button.get_global_rect().position.y > frame.end.y, "accessible %s is outside the photo at %s" % [name, size])

func _choose_bed(world: Node, expected: int) -> bool:
	if not await _walk(world, Vector2(0, 4.66)) or not await _walk(world, Vector2(0, 3.45)):
		return _check(false, "physical route reaches the louver")
	if not _check(world.nearest.get("id") == "garden:louvers", "louver and welcome spot are distinct and usable"):
		return false
	world.interact()
	await _frames(30)
	return _check(world.illuminated_bed() == expected and not world.louver_is_moving(), "the actual louver selects bed %d" % expected)

func _reach_host(world: Node) -> bool:
	return _check(await _walk(world, Vector2(0, 5.56)) and await _walk(world, Vector2(2.80, 5.56))
		and world.nearest.get("id") == Visit.GARDEN_POINT, "walking toward the greeter reaches the fixed welcome interaction")

func _walk(world: Node, target: Vector2) -> bool:
	for tick in 240:
		var current: Vector3 = world.player.position
		var offset := target - Vector2(current.x, current.z)
		if offset.length() < 0.20:
			break
		var direction := offset.normalized()
		var strengths := [maxf(-direction.x, 0.0), maxf(direction.x, 0.0), maxf(-direction.y, 0.0), maxf(direction.y, 0.0)]
		for index in ACTIONS.size():
			if strengths[index] > 0.0:
				Input.action_press(ACTIONS[index], strengths[index])
			else:
				Input.action_release(ACTIONS[index])
		await get_tree().physics_frame
	for action in ACTIONS:
		Input.action_release(action)
	await _frames(9)
	var at: Vector3 = world.player.position
	return world.player.is_on_floor() and Vector2(at.x, at.z).distance_to(target) < 0.47

func _light_state(world: Node) -> Array:
	return [world.louver_detent(), world.louver_angle(), world.louver_is_moving(), world.sun_patch_center(), world.illuminated_bed(), world.active_time_phase]

func _live_pose(world: Node) -> Array:
	return [world.player.transform, world.player.velocity, world.camera.transform, world.avatar.texture, world.facing,
		world.avatar_action, world.avatar_action_elapsed, world.walk_distance_phase, world.safe_reset_count()]

func _frames(count: int) -> void:
	for index in count:
		await get_tree().process_frame

func _check(ok: bool, reason: String) -> bool:
	_checks += 1
	if not ok:
		_failures.append(reason)
	return ok

func _finish() -> void:
	var playbacks := PlaybackRelease.capture(_main.audio)
	_main.quitting = true
	_main.audio.shutdown()
	_main.free()
	await _frames(3)
	_check(await PlaybackRelease.wait_for_release(get_tree(), playbacks), "teardown releases the actual audio stream")
	for reason in _failures:
		push_error(reason)
	if _failures.is_empty():
		print("PASS: garden story framing, live louver continuity, atomic visit and replay")
	print("Garden story: %d checks, %d failures" % [_checks, _failures.size()])
	get_tree().quit(int(not _failures.is_empty()))
