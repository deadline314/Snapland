extends Node

var root: Window:
	get: return get_tree().root

const Scene = preload("res://game/main.tscn")
const Guard = preload("res://game/core/test_save_guard.gd")
const PlaybackRelease = preload("res://game/tests/audio_playback_release.gd")
const Visit = preload("res://game/story/regional_visit.gd")
const Viewfinder = preload("res://game/ui/regional_visit_photo_panel.gd")
const REGION := Visit.CIRCUS
const PHOTO := Visit.CIRCUS_PHOTO
var main: Node
var progress: Node
var failures: Array[String] = []
var signals := 0

func _ready() -> void:
	if not Guard.validate_save_path(OS.get_environment("SNAPLAND_SAVE_PATH"), OS.get_user_data_dir()).is_empty():
		push_error("Circus story tests require an isolated save path.")
		get_tree().quit(1)
		return
	call_deferred("_run")

func _run() -> void:
	progress = root.get_node("Progress")
	progress.reset_progress()
	progress.intro_seen = true
	progress.prologue_seen = true
	progress.settings.master_volume = 0.0
	progress.settings.ui_scale = 1.25
	for venue in ["welcome", "harbor", "candy"]:
		var cards := 6 if venue == "candy" else 12
		for index in range(1, cards + 1):
			progress.photos["photo-%s-game-%d" % [venue, index]] = {"fixture": "scripted setup"}
	_check(progress.normal_count() == 30 and progress.set_current_region(REGION), "standard unlocked regional profile")
	main = Scene.instantiate()
	root.add_child(main)
	await _frames(5)
	var origin: Vector3 = main.world.player.position
	var point: Dictionary = main.world._point_by_id(Visit.CIRCUS_POINT)
	var actor: Dictionary = main.world._npc_record_for_role("imp")
	_check(not actor.is_empty() and not point.is_empty() and actor.activity_root.position == main.world.STORY_HOST,
		"fixed story point has authored 小角 at the foyer")
	_check(is_instance_valid(main.world._story_rest_pose) and is_instance_valid(main.world._story_photo_pose)
		and main.world._story_rest_pose != main.world._story_photo_pose, "authored host has distinct front standing and greeting poses")
	if point.is_empty():
		await _finish()
		return
	Input.action_press("move_up")
	for frame in 190:
		await get_tree().physics_frame
		if str(main.world.nearest.get("id", "")) == Visit.CIRCUS_POINT:
			break
	Input.action_release("move_up")
	await _frames(3)
	_check(origin.distance_to(main.world.player.position) > 1.0 and main.world.nearest.get("id") == Visit.CIRCUS_POINT,
		"real walking reaches the story point from spawn")
	var walk_position: Vector3 = main.world.player.position
	var story_marker := point.get("marker") as Label3D
	_check(is_instance_valid(story_marker) and story_marker.visible, "the reachable story glyph is visible before dialogue")
	var marker_states: Array[bool] = []
	var signs: Array[Node3D] = main.world._story_photo_signs
	_check(not signs.is_empty(), "tent signs are registered for the photo")
	if not signs.is_empty():
		signs[0].hide()
	var sign_visibility := signs.map(func(sign: Node3D) -> bool: return sign.visible)
	if is_instance_valid(story_marker):
		story_marker.visibility_changed.connect(func() -> void: marker_states.append(story_marker.visible))
	main.world.interact()
	_check(main.modal_kind == "dialogue" and main.dialogue[0].speaker == "小角" and str(main.dialogue[2].text).contains("幕幕"),
		"real world interaction opens the on-duty story")
	if main.modal_kind != "dialogue":
		await _finish()
		return
	var skip: Button = main.dialogue_panel.cancel_button
	_check(skip.text == "略過到合照", "skip is available before any text has been read")
	skip.pressed.emit()
	await _frames(3)
	_check(main.modal_kind == "visit_photo" and main.visit_photo_panel != null and main.world._story_photo_camera.is_current(),
		"skip opens the live stage with its dedicated camera")
	if main.modal_kind == "visit_photo":
		_check(signs.all(func(sign: Node3D) -> bool: return not sign.visible),
			"the portrait hides the actual plaques without altering tent geometry")
		_check(actor.sprite.texture == main.world._story_photo_pose, "photo stage uses the registered front greeting pose")
		for viewport_size: Vector2i in [Vector2i(800, 600), Vector2i(1280, 720), Vector2i(1920, 1080)]:
			root.content_scale_size = viewport_size
			root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
			root.size = viewport_size
			await _frames(4)
			var finder := Viewfinder.viewfinder_rect(root.get_visible_rect().size)
			var camera: Camera3D = main.world._story_photo_camera
			for at: Vector3 in [main.world.STORY_HOST, main.world.STORY_GUEST]:
				_check(finder.has_point(camera.unproject_position(at + Vector3(0, 0.12, 0)))
					and finder.has_point(camera.unproject_position(at + Vector3(0, 2.34, 0))),
					"both full-body subjects fit the actual crop at %s" % viewport_size)
			for button_name in ["StoryPhotoShutter", "StoryPhotoCancel"]:
				var button := main.visit_photo_panel.find_child(button_name, true, false) as Control
				_check(button != null and root.get_visible_rect().grow(1.0).encloses(button.get_global_rect()) and button.get_global_rect().position.y > finder.end.y,
					"viewfinder control %s fits %s: button %s viewport %s" % [button_name, viewport_size, str(button.get_global_rect()) if button != null else "missing", root.get_visible_rect()])
		_check(main.world.nearest.get("id") == Visit.CIRCUS_POINT and marker_states == [false],
			"photo staging keeps the story target and hides its glyph once across portrait frames")
		main.visit_photo_panel.find_child("StoryPhotoCancel", true, false).pressed.emit()
	await _frames(3)
	_check(main.modal_kind.is_empty() and main.world.camera.is_current()
		and main.world.player.position.distance_to(walk_position) < 0.15 and not main.world.blocked,
		"cancelling restores normal zoom, character position and movement")
	_check(actor.sprite.texture == main.world._story_rest_pose, "close restores the host’s standing pose")
	_check(marker_states == [false, true], "cancelling restores the nearby story glyph once")
	_check(signs.map(func(sign: Node3D) -> bool: return sign.visible) == sign_visibility,
		"return restores each plaque to the same visibility it had before the photo")
	_check(not progress.photos.has(PHOTO) and not progress.visited.has(REGION), "cancelling never creates collection or visit credit")
	_check(await _save_then_replay(), "the photo and visit carry through the archive")
	await _finish()

func _save_then_replay() -> bool:
	var path := OS.get_environment("SNAPLAND_SAVE_PATH")
	# A previous-format profile has no explicit regional visit map.
	var legacy: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	legacy.erase("visited")
	var old_file := FileAccess.open(path, FileAccess.WRITE)
	old_file.store_string(JSON.stringify(legacy))
	old_file.close()
	progress.load_progress()
	_check(progress.current_region == REGION and progress.normal_count() == 30 and not progress.visited.has(REGION),
		"legacy save keeps the admission and qualifying cards without fabricating a visit")
	var before := FileAccess.get_file_as_string(path)
	var coins: int = progress.coins
	progress.changed.connect(_increment_changes)
	# Use synthetic pixels to verify acquisition and decoding here. The native
	# visit suite exercises a GPU capture of the two actual role sprites.
	var image := Image.create(640, 360, false, Image.FORMAT_RGBA8)
	image.fill(Color("#81617c"))
	if OS.get_environment("SNAPLAND_CIRCUS_PROBE_ROLLBACK") == "1":
		var temporary := path + ".tmp"
		var photos: String = main._photo_directory()
		var photo_files := DirAccess.get_files_at(photos) if DirAccess.dir_exists_absolute(photos) else PackedStringArray()
		if DirAccess.make_dir_absolute(temporary) != OK:
			_check(false, "isolated rollback diagnostic needs a private temporary collision")
			return false
		var saved: bool = main._save_region_story_photo(REGION, PHOTO, image)
		var removed := DirAccess.remove_absolute(temporary)
		_check(not saved and removed == OK and signals == 0
			and not progress.photos.has(PHOTO) and not progress.visited.has(REGION)
			and FileAccess.get_file_as_string(path) == before
			and DirAccess.get_files_at(main._photo_directory()) == photo_files,
			"atomic rollback after the deliberate file collision leaves profile, images, and notifications unchanged")
	if not main._save_region_story_photo(REGION, PHOTO, image):
		_check(false, "production image pipeline can save a bounded fixture photo")
		return false
	var after := FileAccess.get_file_as_string(path)
	var backup := FileAccess.get_file_as_string(path + ".bak")
	_check(backup == before and signals == 1, "one durable write precedes one changed signal")
	_check(progress.normal_count() == 31 and progress.normal_count_for_zone(REGION) == 1 and progress.visited.get(REGION) == true,
		"one canonical photo and one visit are awarded together")
	var photo: Dictionary = progress.photos[PHOTO].duplicate(true)
	var original := str(photo.original_frames[0])
	var original_hash := FileAccess.get_sha256(original)
	_check(progress.coins == coins and progress.achievements.is_empty() and progress.quests.is_empty()
		and FileAccess.file_exists(photo.frames[0]) and FileAccess.file_exists(photo.original_frames[0]),
		"collection has both valid file references and no unrelated reward")
	_check(progress.record_region_story_visit(REGION, "", "") and FileAccess.get_file_as_string(path) == after
		and FileAccess.get_file_as_string(path + ".bak") == backup and FileAccess.get_sha256(original) == original_hash and signals == 1,
		"repeat visit uses the same durable photo without changes or extra files")
	progress.load_progress()
	_check(progress.visited.get(REGION) == true and progress.photos[PHOTO] == photo, "same photograph and visit survive reload")
	main._show_album()
	var tile := main.overlay.find_child("AlbumPhoto_" + PHOTO, true, false) as Button
	if tile == null:
		_check(false, "regional album exposes the story tile")
		return false
	tile.pressed.emit()
	var replay := main.overlay.find_child("PhotoViewerReplayStory", true, false) as Button
	if replay == null:
		_check(false, "viewing the original offers replay")
		return false
	replay.pressed.emit()
	_check(main.modal_kind == "dialogue", "original-photo viewer reopens the story scene")
	main.dialogue_panel.cancel_button.pressed.emit()
	_check(main.modal_kind == "visit_photo" and main.visit_photo_from_album, "on-site album replay opens a live stage")
	main._exit_region_story_photo()
	_check(main.modal_kind == "album" and progress.photos[PHOTO] == photo and progress.visited.get(REGION) == true,
		"closing a replay returns to the album with original photo unchanged")
	progress.changed.disconnect(_increment_changes)
	main._close()
	if not main._travel_to_region("welcome"):
		_check(false, "the free return can leave the original region")
		return false
	await _frames(5)
	main._show_album(REGION)
	var remote_tile := main.overlay.find_child("AlbumPhoto_" + PHOTO, true, false) as Button
	if remote_tile == null:
		return false
	remote_tile.pressed.emit()
	var remote_replay := main.overlay.find_child("PhotoViewerReplayStory", true, false) as Button
	if remote_replay == null:
		return false
	remote_replay.pressed.emit()
	_check(main.modal_kind == "dialogue" and main.dialogue_panel.cancel_button.text == "略過",
		"remote archive replays the short text while keeping the set on-site")
	main.dialogue_panel.cancel_button.pressed.emit()
	_check(main.modal_kind == "album" and main.world_region == "welcome" and main.visit_photo_panel == null
		and progress.photos[PHOTO] == photo and FileAccess.get_sha256(original) == original_hash,
		"remote review keeps the travel region and original photo")
	return true

func _increment_changes() -> void:
	signals += 1

func _frames(count: int) -> void:
	for frame in count:
		await get_tree().process_frame

func _check(condition: bool, reason: String) -> void:
	if not condition:
		failures.append(reason)

func _finish() -> void:
	var playbacks := PlaybackRelease.capture(main.audio)
	main.quitting = true
	main.audio.shutdown()
	main.free()
	await _frames(3)
	# Fixed simulation time does not drain the audio backend's real-time queue.
	_check(await PlaybackRelease.wait_for_release(get_tree(), playbacks),
		"circus teardown releases stopped audio playbacks")
	for reason in failures:
		push_error(reason)
	if failures.is_empty():
		print("PASS: circus story approach, framing, atomic visit and replay")
	get_tree().quit(int(not failures.is_empty()))
