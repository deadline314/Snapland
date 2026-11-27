extends Node

const Scene = preload("res://game/main.tscn")
const Guard = preload("res://game/core/test_save_guard.gd")
const PlaybackRelease = preload("res://game/tests/audio_playback_release.gd")
const Visit = preload("res://game/story/regional_visit.gd")
const PhotoPanel = preload("res://game/ui/regional_visit_photo_panel.gd")

## The district the story happens in (a child of the island world).
var place: Node3D
var _main: Node
var _progress: Node
var _failures: Array[String] = []
var _checks := 0


func _ready() -> void:
	if not Guard.validate_save_path(OS.get_environment("SNAPLAND_SAVE_PATH"), OS.get_user_data_dir()).is_empty():
		push_error("Toy story tests require an isolated save path.")
		get_tree().quit(1)
		return
	_run.call_deferred()


func _run() -> void:
	_progress = get_tree().root.get_node("Progress")
	_progress.reset_progress()
	_progress.intro_seen = true
	_progress.prologue_seen = true
	_progress.settings.master_volume = 0.0
	_progress.settings.ui_scale = 1.25
	for venue in ["welcome", "harbor", "candy"]:
		var count := 6 if venue == "candy" else 12
		for index in range(1, count + 1):
			_progress.photos["photo-%s-game-%d" % [venue, index]] = {"fixture": true}
	_check(_progress.normal_count() == 30 and _progress.set_current_region(Visit.TOY), "Toy visit uses the normal thirty-card threshold")
	_main = Scene.instantiate()
	get_tree().root.add_child(_main)
	await _frames(5)
	var world: Node3D = _main.world
	place = _main.region_world()
	var point: Dictionary = place._point_by_id(Visit.TOY_POINT)
	var host: Dictionary = place._npc_record_for_role("announcer")
	if not _check(not point.is_empty() and not host.is_empty() and host.activity_root.position == place.STORY_HOST,
		"story glyph and authored host are at the real station lead"):
		await _finish()
		return
	var start: Vector3 = world.player.position
	await _walk("move_up", func() -> bool: return place.player_spot().z < 5.28)
	await _walk("move_right", func() -> bool: return world.nearest.get("id") == Visit.TOY_POINT)
	await _frames(10)
	if not _check(start.distance_to(world.player.position) > 4.0 and world.nearest.get("id") == Visit.TOY_POINT,
		"walking from the entrance reaches 阿浪 without moving the train controls"):
		await _finish()
		return
	place.switch_tracks()
	place.operate_train()
	await _frames(15)
	world.interact()
	if not _check(_main.modal_kind == "dialogue" and _main.dialogue[0].speaker == "阿浪" and str(_main.dialogue[2].text).contains("幕幕"),
		"physical interaction opens the short mechanic dialogue"):
		await _finish()
		return
	var train: Dictionary = place.train_state()
	var pose := _pose(world)
	var station_label: Label3D = place._station_label
	station_label.hide()
	var label_was_visible := station_label.visible
	var marker: Label3D = point.marker
	var marker_was_visible := marker.visible
	var skip: Button = _main.dialogue_panel.cancel_button
	_check(skip.text == "略過到合照", "dialogue offers skip directly to the live set")
	skip.pressed.emit()
	if not _check(_main.modal_kind == "visit_photo" and place._story_photo_camera.is_current(), "skip enters a live station portrait"):
		await _finish()
		return
	_check(train.branch == 1 and train.running and train.distance > 0.0 and place.train_state() == train,
		"stage leaves the running right-hand route at its exact as-entered position")
	_check(not world.player.visible and not marker.visible and station_label.visible and station_label.text.contains("右線")
		and place._story_host_sprite.texture == place._story_host_greeting,
		"portrait shows the actual greeter and true station sign without interaction markers")
	var portrait_guest := place._story_photo_camera.get_node_or_null("ToyStoryGuest") as Sprite3D
	_check(portrait_guest != null and portrait_guest.texture == world.avatar_renderer.texture(world.avatar_appearance,
		world.avatar_equipped, "front", 0, "photograph"), "portrait uses the same player's authored appearance and outfit")
	await _check_framing(world)
	_check(place.train_state() == train and _pose(world) == pose, "waiting in a portrait cannot advance the train or live pose")
	_main.visit_photo_panel.find_child("StoryPhotoCancel", true, false).pressed.emit()
	_check(place.train_state() == train and _pose(world) == pose and world.player.visible and world.camera.is_current()
		and station_label.visible == label_was_visible and place._story_host_sprite.texture == place._story_host_rest,
		"cancel restores the camera, greeter and labels with live player and rail state intact")
	await _frames(3)
	_check(marker.visible == marker_was_visible and place.train_state().distance > train.distance,
		"normal control restores the story glyph and the train resumes from its original position")
	_check(not _progress.photos.has(Visit.TOY_PHOTO) and not _progress.visited.has(Visit.TOY), "cancelling does not create a photo or visit")
	await _check_archive(world)
	await _finish()


func _check_framing(world: Node3D) -> void:
	var root := get_tree().root
	var camera: Camera3D = place._story_photo_camera
	for size in [Vector2i(800, 600), Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.content_scale_size = size
		root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
		root.size = size
		await _frames(3)
		var frame := PhotoPanel.viewfinder_rect(root.get_visible_rect().size)
		for location: Vector3 in [place.to_global(place.STORY_HOST), place.to_global(place.STORY_GUEST)]:
			_check(frame.has_point(camera.unproject_position(location)) and frame.has_point(camera.unproject_position(location + Vector3.UP * 2.42)),
				"both full-body portrait subjects fit at %s" % size)
		var stops: PackedVector3Array = place._train.stops()
		_check(stops.size() == 4, "the railway reports its dock, tail siding and both termini")
		for stop in stops:
			_check(frame.has_point(camera.unproject_position(Vector3(stop.x, 0.9, stop.z))), "each possible train position fits at %s" % size)
		for side in [-1.0, 1.0]:
			var corner: Vector3 = place.STATION_STATUS_AT + Vector3(side * place.STATION_STATUS_WIDTH * 0.5, 0.215, -0.07)
			_check(frame.grow(-4.0).has_point(camera.unproject_position(place.to_global(corner))), "the physical sign is fully framed at %s" % size)
		for button_name in ["StoryPhotoCancel", "StoryPhotoShutter"]:
			var button := _main.visit_photo_panel.find_child(button_name, true, false) as Control
			_check(button != null and root.get_visible_rect().grow(1.0).encloses(button.get_global_rect())
				and button.get_global_rect().position.y > frame.end.y, "reachable %s lies outside the photo at %s" % [button_name, size])


func _check_archive(world: Node3D) -> void:
	var path := OS.get_environment("SNAPLAND_SAVE_PATH")
	var coins: int = _progress.coins
	var image := Image.create(640, 360, false, Image.FORMAT_RGBA8)
	image.fill(Color("#54615b"))
	# Only the persistence pipeline uses fixture pixels. The live shutter is verified in a native window.
	if not _check(_main._save_region_story_photo(Visit.TOY, Visit.TOY_PHOTO, image), "first photo saves through the real bounded image pipeline"):
		return
	var photo: Dictionary = _progress.photos[Visit.TOY_PHOTO].duplicate(true)
	var original: String = photo.original_frames[0]
	var digest := FileAccess.get_sha256(original)
	var profile := FileAccess.get_file_as_string(path)
	_check(_progress.normal_count() == 31 and _progress.normal_count_for_zone(Visit.TOY) == 1
		and _progress.visited.get(Visit.TOY) == true and _progress.coins == coins and not digest.is_empty(),
		"one canonical photo and one visit are durable without unrelated rewards")
	_check(_progress.record_region_story_visit(Visit.TOY, "", "") and FileAccess.get_file_as_string(path) == profile,
		"repeat registration is idempotent and does not rewrite the profile")
	_progress.load_progress()
	_check(_progress.visited.get(Visit.TOY) == true and _progress.photos[Visit.TOY_PHOTO] == photo,
		"reload retains the canonical photo and regional visit")
	_progress.set_setting("reduced_motion", true)
	place.reset_train()
	place.operate_train()
	var reduced: Dictionary = place.train_state()
	var pose := _pose(world)
	_main._show_album()
	var tile := _main.overlay.find_child("AlbumPhoto_" + Visit.TOY_PHOTO, true, false) as Button
	if not _check(tile != null, "Toy album exposes its actual story photo"):
		return
	tile.pressed.emit()
	var replay := _main.overlay.find_child("PhotoViewerReplayStory", true, false) as Button
	if not _check(replay != null, "original-photo viewer offers replay"):
		return
	replay.pressed.emit()
	_main.dialogue_panel.cancel_button.pressed.emit()
	_check(_main.modal_kind == "visit_photo" and _main.visit_photo_from_album and reduced.reduced_motion,
		"on-site album replay opens the same set with reduced motion")
	await _frames(3)
	_check(place.train_state() == reduced and _pose(world) == pose, "replay does not move the stepped cart or real player")
	_main._exit_region_story_photo()
	_check(_main.modal_kind == "album" and _progress.photos[Visit.TOY_PHOTO] == photo and FileAccess.get_sha256(original) == digest,
		"closing replay returns to the album and preserves the original image")


func _pose(world: Node3D) -> Array:
	return [world.player.transform, world.camera.transform, world.facing, world.avatar.texture,
		world.avatar_action, world.avatar_action_elapsed, world.avatar_action_remaining, world.walk_distance_phase]


func _walk(action: String, reached: Callable) -> void:
	Input.action_press(action)
	for index in 240:
		await get_tree().physics_frame
		if reached.call():
			break
	Input.action_release(action)


func _frames(count: int) -> void:
	for frame in count:
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
	_check(await PlaybackRelease.wait_for_release(get_tree(), playbacks), "teardown releases the real audio playbacks")
	for reason in _failures:
		push_error(reason)
	if _failures.is_empty():
		print("PASS: toy story framing, scene continuity, atomic visit and replay")
	print("%d checks, %d failures" % [_checks, _failures.size()])
	get_tree().quit(int(not _failures.is_empty()))
