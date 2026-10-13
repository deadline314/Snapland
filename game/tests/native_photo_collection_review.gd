extends Node
## Native, real-input review of gameplay captures and shared album originals.

const MAIN_SCENE_PATH := "res://game/main.tscn"
const GAME_ID := "game-012"
const PHRASES: Array[Array] = [[0, 2, 1], [3, 1, 0, 2, 1], [2, 2, 0, 3, 1, 0, 2]]
const RHYTHMS: Array[Array] = [[0.0, 0.50, 0.88], [0.0, 0.86, 0.43, 0.43, 0.86], [0.0, 0.43, 0.86, 0.43, 0.86, 0.43, 0.43]]
const MAX_REVIEW_SECONDS := 360.0
const MAX_WAIT_SECONDS := 30.0
const STUCK_SECONDS := 2.0
const REVIEW_IMAGE_DIR := "res://pm/Snapland-main/images"
const CAPTURE_ENV := "SNAPLAND_NATIVE_CAPTURE"

var _main: Node
var _world: Node
var _progress: Node
var _started_ms := 0
var _failure := ""
var _movement_state := {KEY_W: false, KEY_A: false, KEY_S: false, KEY_D: false}
var _last_result: Dictionary = {}
var _report: Dictionary = {
	"status": "running",
	"game_id": GAME_ID,
	"input_evidence": "real Input.parse_input_event key and mouse events through Main/Session/Control",
	"human_played": false,
	"scripted_gameplay_note": "A script plays the published fixed melody using real keyboard events; this is not a human play session.",
	"tutorial": "Skipped through the visible tutorial button on first entry.",
	"ordinary_run": {},
	"devil_run": {},
	"album": {},
	"screenshot_capture_opted_in": false,
	"screenshots": [],
}

func _ready() -> void:
	if OS.get_environment("SNAPLAND_SAVE_PATH").strip_edges().is_empty() or DisplayServer.get_name() == "headless":
		_fail_now("Requires a GPU-backed display and an isolated SNAPLAND_SAVE_PATH.")
		return
	_started_ms = Time.get_ticks_msec()
	_report["screenshot_capture_opted_in"] = OS.get_environment(CAPTURE_ENV).strip_edges() == "1"
	get_window().size = Vector2i(1280, 720)
	_run.call_deferred()

func _run() -> void:
	_progress = get_tree().root.get_node_or_null("Progress")
	if _progress == null:
		await _fail("Progress autoload is missing")
		return
	var packed: PackedScene = load(MAIN_SCENE_PATH)
	if packed == null:
		await _fail("Could not load Main scene")
		return
	_main = packed.instantiate()
	_main.name = "NativePhotoCollectionMain"
	get_tree().root.add_child(_main)
	await _frames(8)
	_world = _main.world
	if not _progress.photos.is_empty() or int(_progress.normal_count()) != 0 or int(_progress.devil_count()) != 0:
		await _fail("SNAPLAND_SAVE_PATH must point to a fresh profile with no existing photo rewards")
		return
	if _main.modal_kind == "dialogue":
		_send_key(KEY_ESCAPE, true)
		await _frames(1)
		_send_key(KEY_ESCAPE, false)
		await _frames(3)
	if _main.modal_kind != "" or not bool(_progress.intro_seen):
		await _fail("Actual Escape input did not close and persist arrival dialogue")
		return
	if not await _walk_to_game_012():
		await _fail(_failure)
		return
	if str(_world.nearest.get("id", "")) != GAME_ID:
		await _fail("At the game-012 approach, nearest interaction is %s, not game-012" % str(_world.nearest.get("id", "")))
		return
	_send_key(KEY_E, true)
	await _frames(1)
	_send_key(KEY_E, false)
	if not await _wait_for(func() -> bool: return _main.modal_kind == "game_info", "game-012 invitation"):
		await _fail(_failure)
		return
	var invite_start := _main.overlay.find_child("InviteStart", true, false) as Button
	if invite_start == null or not await _click_control(invite_start):
		await _fail("Could not click the visible InviteStart button")
		return
	if not await _wait_for(func() -> bool: return is_instance_valid(_main.tutorial_panel), "first-entry tutorial"):
		await _fail(_failure)
		return
	var skip_button := _find_button_with_text(_main.tutorial_panel, "略過")
	if skip_button == null or not await _click_control(skip_button):
		await _fail("Could not click the visible first-entry tutorial Skip button")
		return
	if not await _wait_for(func() -> bool: return is_instance_valid(_main.session), "ordinary game session"):
		await _fail(_failure)
		return
	if not await _play_fixed_melody(false):
		await _fail(_failure)
		return
	if not await _wait_for(func() -> bool: return _main.modal_kind == "result" and not is_instance_valid(_main.session), "ordinary result"):
		await _fail(_failure)
		return
	if not await _capture_review_image("MAIN-13-native-ordinary-result.png"):
		await _fail(_failure)
		return
	var ordinary_id := "photo-welcome-game-12"
	var ordinary_photo: Dictionary = _progress.photos.get(ordinary_id, {})
	if ordinary_photo.is_empty():
		await _fail("The genuine ordinary-success result did not award photo-welcome-game-12")
		return
	var ordinary_paths := _photo_paths(ordinary_photo, "original_frames")
	if not _validate_originals(ordinary_paths, "ordinary run"):
		await _fail(_failure)
		return
	if not bool(_last_result.get("success", false)) or bool(_last_result.get("devil", false)):
		await _fail("First natural run must end in ordinary success only: %s" % str(_last_result))
		return
	_report["ordinary_run"] = {"result": _last_result.duplicate(true), "photo_id": ordinary_id, "original_paths": ordinary_paths, "normal_count": int(_progress.normal_count()), "assisted": bool(_last_result.get("assisted", true))}
	var retry := _find_button_with_text(_main.overlay, "再玩一次")
	if retry == null or not await _click_control(retry):
		await _fail("Could not click the actual result screen's 再玩一次 button")
		return
	if not await _wait_for(func() -> bool: return is_instance_valid(_main.session), "devil game session"):
		await _fail(_failure)
		return
	if not await _play_fixed_melody(true):
		await _fail(_failure)
		return
	if not await _wait_for(func() -> bool: return _main.modal_kind == "result" and not is_instance_valid(_main.session), "devil result"):
		await _fail(_failure)
		return
	if not await _capture_review_image("MAIN-13-native-devil-result.png"):
		await _fail(_failure)
		return
	var devil_id := "photo-welcome-devil-12"
	var devil_photo: Dictionary = _progress.photos.get(devil_id, {})
	ordinary_photo = _progress.photos.get(ordinary_id, {})
	if devil_photo.is_empty() or not ordinary_photo.has("original_frames"):
		await _fail("The genuine perfect run did not award the devil photo and shared originals")
		return
	var devil_paths := _photo_paths(devil_photo, "original_frames")
	ordinary_paths = _photo_paths(ordinary_photo, "original_frames")
	if devil_paths.is_empty() or devil_paths != ordinary_paths:
		await _fail("Ordinary/devil cards do not point to the same captured original files: normal=%s devil=%s" % [str(ordinary_paths), str(devil_paths)])
		return
	if not _validate_originals(devil_paths, "devil run"):
		await _fail(_failure)
		return
	var normal_thumbnails := _photo_paths(ordinary_photo, "frames")
	var devil_thumbnails := _photo_paths(devil_photo, "frames")
	if normal_thumbnails.is_empty() or normal_thumbnails != devil_thumbnails or not _validate_thumbnails(normal_thumbnails):
		await _fail(_failure if not _failure.is_empty() else "Ordinary/devil cards do not share valid 320x180 thumbnail files")
		return
	if not bool(_last_result.get("success", false)) or not bool(_last_result.get("devil", false)) or bool(_last_result.get("assisted", true)):
		await _fail("Second natural run must be unassisted devil success: %s" % str(_last_result))
		return
	_report["devil_run"] = {"result": _last_result.duplicate(true), "photo_id": devil_id, "original_paths": devil_paths, "normal_count": int(_progress.normal_count()), "devil_count": int(_progress.devil_count()), "same_paths_as_ordinary": true, "assisted": false}
	if int(_progress.normal_count()) != 1 or int(_progress.devil_count()) != 1:
		await _fail("Repeated success duplicated a reward count: normal=%d devil=%d" % [int(_progress.normal_count()), int(_progress.devil_count())])
		return
	_send_key(KEY_ESCAPE, true)
	await _frames(1)
	_send_key(KEY_ESCAPE, false)
	await _frames(3)
	if _main.modal_kind != "":
		await _fail("Actual Escape input did not close the completed result panel before album navigation")
		return
	if not await _walk_to_album():
		await _fail(_failure)
		return
	_send_key(KEY_E, true)
	await _frames(1)
	_send_key(KEY_E, false)
	if not await _wait_for(func() -> bool: return _main.modal_kind == "album", "photo album"):
		await _fail(_failure)
		return
	var normal_view := await _open_album_photo("normal")
	if not normal_view:
		await _fail(_failure)
		return
	var devil_view := await _open_album_photo("devil")
	if not devil_view:
		await _fail(_failure)
		return
	var normal_count_before_reload := int(_progress.normal_count())
	var devil_count_before_reload := int(_progress.devil_count())
	var shared_path_before_reload := devil_paths[0]
	_progress.load_progress()
	ordinary_photo = _progress.photos.get(ordinary_id, {})
	devil_photo = _progress.photos.get(devil_id, {})
	var persisted_normal := _photo_paths(ordinary_photo, "original_frames")
	var persisted_devil := _photo_paths(devil_photo, "original_frames")
	if persisted_normal != persisted_devil or persisted_normal.is_empty() or persisted_normal[0] != shared_path_before_reload:
		await _fail("Reloaded records lost their shared original path")
		return
	if int(_progress.normal_count()) != normal_count_before_reload or int(_progress.devil_count()) != devil_count_before_reload:
		await _fail("Reload changed collection counts or granted duplicate cards")
		return
	if not _validate_originals(persisted_normal, "reloaded profile"):
		await _fail(_failure)
		return
	if not await _capture_review_image("MAIN-13-native-reload-album.png"):
		await _fail(_failure)
		return
	_report["album"] = {"opened_normal_original": normal_view, "opened_devil_original": devil_view, "reload_shared_path": persisted_normal[0], "original_count_after_reload": persisted_normal.size(), "thumbnail_paths": normal_thumbnails, "thumbnail_size": [320, 180], "original_size": [1280, 720], "normal_count_after_reload": int(_progress.normal_count()), "devil_count_after_reload": int(_progress.devil_count())}
	_report["elapsed_seconds"] = float(Time.get_ticks_msec() - _started_ms) / 1000.0
	await _finish(true, "")

func _walk_to_game_012() -> bool:
	var path: Array[Vector2] = [Vector2(0, 12), Vector2(4.2, 7), Vector2(3, -13), Vector2(3, -9), Vector2(5, -20), Vector2(5, -27), Vector2(4.2, -34), Vector2(6, -40.5)]
	for index in range(path.size()):
		if not await _walk_to(path[index], "game-012 approach %d" % (index + 1)):
			return false
	await _frames(3)
	return true

func _walk_to_album() -> bool:
	var path: Array[Vector2] = [Vector2(4.2, -34), Vector2(5, -27), Vector2(5, -20), Vector2(3, -13), Vector2(3, -9), Vector2(4.2, -4.2), Vector2(4.2, 6.2), Vector2(8, 7)]
	for index in range(path.size()):
		if not await _walk_to(path[index], "album approach %d" % (index + 1)):
			return false
	await _frames(3)
	return str(_world.nearest.get("id", "")) == "album"

func _walk_to(target: Vector2, label: String) -> bool:
	var started := Time.get_ticks_msec()
	var last_progress := started
	var best_distance := _distance_to(target)
	var step := {"name": label, "from": _position(), "target": [target.x, target.y]}
	while _distance_to(target) > 0.45:
		if Time.get_ticks_msec() - _started_ms > int(MAX_REVIEW_SECONDS * 1000.0):
			_failure = "Review exceeded total time budget at %s; position=%s" % [label, str(_world.player.position)]
			return false
		if Time.get_ticks_msec() - started > 35000:
			_failure = "Timed out walking to %s; position=%s distance=%.2f" % [label, str(_world.player.position), _distance_to(target)]
			return false
		var position: Vector3 = _world.player.position
		_set_key(KEY_A, target.x < position.x - 0.08)
		_set_key(KEY_D, target.x > position.x + 0.08)
		_set_key(KEY_W, target.y < position.z - 0.08)
		_set_key(KEY_S, target.y > position.z + 0.08)
		await get_tree().physics_frame
		var distance := _distance_to(target)
		if distance < best_distance - 0.015:
			best_distance = distance
			last_progress = Time.get_ticks_msec()
		elif Time.get_ticks_msec() - last_progress > int(STUCK_SECONDS * 1000.0):
			_failure = "Stuck at %s; position=%s distance=%.2f wall=%s" % [label, str(_world.player.position), distance, str(_world.player.is_on_wall())]
			return false
		if _world.player.is_on_wall():
			var collisions: Array[String] = []
			for collision_index in range(_world.player.get_slide_collision_count()):
				var collision: KinematicCollision3D = _world.player.get_slide_collision(collision_index)
				if collision != null and collision.get_collider() is Node:
					collisions.append((collision.get_collider() as Node).name)
			step["last_wall_contacts"] = collisions
	_set_movement(false)
	step["actual"] = _position()
	step["elapsed_seconds"] = float(Time.get_ticks_msec() - started) / 1000.0
	var walk_report: Array = _report.get("walk", [])
	walk_report.append(step)
	_report["walk"] = walk_report
	return true

func _play_fixed_melody(precise: bool) -> bool:
	var session: Node = _main.session
	if not is_instance_valid(session) or session.game_id != GAME_ID or session.assisted or session.practice_mode:
		_failure = "Game session is not an unassisted standard game-012 session"
		return false
	_last_result.clear()
	session.finished.connect(_capture_result, CONNECT_ONE_SHOT)
	var run_started := Time.get_ticks_msec()
	for phrase_index in range(PHRASES.size()):
		if not await _wait_for(func() -> bool: return is_instance_valid(_main.session) and int(_main.session.melody_snapshot.get("phrase_index", -1)) == phrase_index and str(_main.session.melody_snapshot.get("phase", "")) == "active", "melody phrase %d ready" % (phrase_index + 1)):
			_failure = _failure
			return false
		var last_note_usec := 0
		for note_index in range(PHRASES[phrase_index].size()):
			if note_index > 0:
				var offset := float(RHYTHMS[phrase_index][note_index])
				if not precise:
					offset += 0.36
				var target_usec := last_note_usec + int(offset * 1000000.0)
				while Time.get_ticks_usec() < target_usec:
					await get_tree().process_frame
			var press_usec := Time.get_ticks_usec()
			_send_key(KEY_1 + int(PHRASES[phrase_index][note_index]), true)
			await get_tree().process_frame
			_send_key(KEY_1 + int(PHRASES[phrase_index][note_index]), false)
			last_note_usec = press_usec
			var current: Dictionary = session.melody_snapshot if is_instance_valid(session) else {}
			if current.is_empty():
				current = {"error_count": 0, "precise_notes": _note_serial(phrase_index, note_index + 1)}
			if int(current.get("error_count", 0)) > 0:
				_failure = "Correct fixed melody caused a model error at phrase %d note %d: %s" % [phrase_index + 1, note_index + 1, str(current.get("last_event", ""))]
				return false
			if note_index < PHRASES[phrase_index].size() - 1 and int(current.get("input_index", -1)) != note_index + 1:
				_failure = "Real note input was not accepted at phrase %d note %d; snapshot=%s" % [phrase_index + 1, note_index + 1, str(current)]
				return false
			if precise and int(current.get("precise_notes", -1)) != _note_serial(phrase_index, note_index + 1):
				_failure = "Note missed the precise timing window at phrase %d note %d; precise=%d" % [phrase_index + 1, note_index + 1, int(current.get("precise_notes", -1))]
				return false
		if phrase_index < PHRASES.size() - 1:
			var expected_next := phrase_index + 1
			if not await _wait_for(func() -> bool: return is_instance_valid(_main.session) and int(_main.session.melody_snapshot.get("phrase_index", -1)) == expected_next and str(_main.session.melody_snapshot.get("phase", "")) == "active", "next melody phrase"):
				_failure = _failure
				return false
		if Time.get_ticks_msec() - run_started > 120000:
			_failure = "Gameplay input exceeded 120 seconds"
			return false
	if not bool(_last_result.get("success", false)) or (precise and not bool(_last_result.get("devil", false))):
		_failure = "Melody ended without expected %s success: %s" % ["devil" if precise else "ordinary", str(_last_result)]
		return false
	_report["last_melody_run"] = {"precise_input": precise, "elapsed_seconds": float(Time.get_ticks_msec() - run_started) / 1000.0}
	return true

func _open_album_photo(category: String) -> bool:
	var book: Node = _main.overlay.find_child("AlbumPhotoGrid", true, false)
	if book == null:
		_failure = "Album photo grid is unavailable for %s" % category
		return false
	var tab_name := "AlbumTab_normal" if category == "normal" else "AlbumTab_devil"
	var tab := _main.overlay.find_child(tab_name, true, false) as Button
	if tab == null or not await _click_control(tab):
		_failure = "Could not click %s album tab" % category
		return false
	var page_next := _main.overlay.find_child("AlbumNextPage", true, false) as Button
	if page_next == null or not await _click_control(page_next):
		_failure = "Could not exercise next-page navigation in %s album" % category
		return false
	# Earned photos sort onto page one. Exercise a real round-trip rather than
	# assuming that catalog number 12 lives on the old six-card second page.
	var photo_name := "AlbumPhoto_photo-welcome-%s-12" % ("game" if category == "normal" else "devil")
	var next_page_photo := _main.overlay.find_child(photo_name,true,false) as Button
	if next_page_photo == null or next_page_photo.visible:
		_failure = "Next-page navigation did not leave the earned first page in %s album" % category
		return false
	var page_previous := _main.overlay.find_child("AlbumPreviousPage",true,false) as Button
	if page_previous == null or not await _click_control(page_previous):
		_failure = "Could not return to the earned first page in %s album" % category
		return false
	if not await _capture_review_image("MAIN-13-native-%s-album-tiles.png" % ("ordinary" if category == "normal" else "devil")):
		return false
	var photo := _main.overlay.find_child(photo_name, true, false) as Button
	if photo == null or not photo.visible or not await _click_control(photo):
		_failure = "Could not click the collected game-012 tile in %s album" % category
		return false
	if not await _wait_for(func() -> bool: return _main.overlay.find_child("PhotoViewer", true, false) != null, "%s original viewer" % category):
		return false
	var viewer: Node = _main.overlay.find_child("PhotoViewer", true, false)
	var texture_rect := viewer.find_child("PhotoViewerImage", true, false) as TextureRect
	if texture_rect == null or texture_rect.texture == null or texture_rect.texture.get_size() != Vector2(1280, 720):
		_failure = "%s album viewer did not show the 1280x720 gameplay original" % category
		return false
	if not await _capture_review_image("MAIN-16-native-%s-original-viewer.png" % ("ordinary" if category == "normal" else "devil")):
		return false
	var image_path := _photo_paths(_progress.photos.get("photo-welcome-%s-12" % ("game" if category == "normal" else "devil"), {}), "original_frames")
	if image_path.is_empty() or image_path[0] != _photo_paths(_progress.photos.get("photo-welcome-game-12", {}), "original_frames")[0]:
		_failure = "%s viewer does not use the shared original path" % category
		return false
	var close := viewer.find_child("PhotoViewerClose", true, false) as Button
	if close == null or not await _click_control(close):
		_failure = "Could not close actual %s PhotoViewer" % category
		return false
	return true

func _capture_review_image(file_name: String) -> bool:
	if not bool(_report.get("screenshot_capture_opted_in", false)):
		return true
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		_failure = "Could not capture rendered review frame %s" % file_name
		return false
	if image.get_size() != Vector2i(1280, 720):
		_failure = "Review screenshot %s must be 1280x720; actual=%s" % [file_name, str(image.get_size())]
		return false
	var directory := ProjectSettings.globalize_path(REVIEW_IMAGE_DIR)
	var mkdir_error := DirAccess.make_dir_recursive_absolute(directory)
	if mkdir_error != OK and mkdir_error != ERR_ALREADY_EXISTS:
		_failure = "Could not create review screenshot directory: %s" % directory
		return false
	var path := directory.path_join(file_name)
	if FileAccess.file_exists(path):
		_failure = "Refusing to overwrite an existing proof image: %s" % path
		return false
	if image.save_png(path) != OK:
		_failure = "Could not save review screenshot: %s" % path
		return false
	var persisted := Image.new()
	if persisted.load(path) != OK or persisted.get_size() != image.get_size():
		_failure = "Saved review screenshot failed dimension verification: %s" % path
		return false
	var screenshots: Array = _report.get("screenshots", [])
	screenshots.append({"path": path, "size": [persisted.get_width(), persisted.get_height()]})
	_report["screenshots"] = screenshots
	return true

func _click_control(control: Control) -> bool:
	if not is_instance_valid(control) or not control.is_visible_in_tree() or not control.is_inside_tree():
		return false
	var ancestor := control.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer:
			(ancestor as ScrollContainer).ensure_control_visible(control)
		ancestor = ancestor.get_parent()
	await get_tree().process_frame
	var rect := control.get_global_rect()
	var position := rect.get_center()
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.position = position
	down.global_position = position
	down.pressed = true
	Input.parse_input_event(down)
	Input.flush_buffered_events()
	await get_tree().process_frame
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.position = position
	up.global_position = position
	up.pressed = false
	Input.parse_input_event(up)
	Input.flush_buffered_events()
	await _frames(2)
	return true

func _find_button_with_text(root: Node, button_text: String) -> Button:
	for child in root.get_children():
		if child is Button and (child as Button).text == button_text:
			return child as Button
		var found := _find_button_with_text(child, button_text)
		if found != null:
			return found
	return null

func _validate_originals(paths: Array[String], label: String) -> bool:
	if paths.is_empty():
		_failure = "%s has no original_frames" % label
		return false
	for path in paths:
		if not FileAccess.file_exists(path):
			_failure = "%s original is missing: %s" % [label, path]
			return false
		var image := Image.new()
		if image.load(path) != OK or image.get_size() != Vector2i(1280, 720) or image.get_width() * image.get_height() > 4 * 1024 * 1024:
			_failure = "%s original has wrong dimensions or exceeds 4Mpx: %s %s" % [label, path, str(image.get_size())]
			return false
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null or file.get_length() < 45 or file.get_length() > 16 * 1024 * 1024:
			_failure = "%s original violates 16 MiB file bounds: %s" % [label, path]
			return false
		file.close()
	return true

func _validate_thumbnails(paths: Array[String]) -> bool:
	for path in paths:
		if not FileAccess.file_exists(path):
			_failure = "Thumbnail is missing: %s" % path
			return false
		var image := Image.new()
		if image.load(path) != OK or image.get_size() != Vector2i(320, 180):
			_failure = "Thumbnail is not 320x180: %s %s" % [path, str(image.get_size())]
			return false
	return true

func _photo_paths(photo: Dictionary, key: String) -> Array[String]:
	var paths: Array[String] = []
	var value: Variant = photo.get(key, [])
	if value is Array:
		for item in value:
			paths.append(str(item))
	return paths

func _wait_for(condition: Callable, label: String) -> bool:
	var deadline := Time.get_ticks_msec() + int(MAX_WAIT_SECONDS * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if condition.call():
			return true
		if Time.get_ticks_msec() - _started_ms > int(MAX_REVIEW_SECONDS * 1000.0):
			_failure = "Total review deadline expired while waiting for %s" % label
			return false
		await get_tree().process_frame
	_failure = "Timed out waiting for %s" % label
	return false

func _distance_to(target: Vector2) -> float:
	return Vector2(_world.player.position.x, _world.player.position.z).distance_to(target)

func _position() -> Dictionary:
	return {"x": snappedf(_world.player.position.x, 0.01), "y": snappedf(_world.player.position.y, 0.01), "z": snappedf(_world.player.position.z, 0.01)}

func _note_serial(phrase_index: int, note_index: int) -> int:
	var result := note_index
	for index in range(phrase_index):
		result += PHRASES[index].size()
	return result

func _set_key(key: Key, pressed: bool) -> void:
	if key in _movement_state:
		if bool(_movement_state[key]) == pressed:
			return
		_movement_state[key] = pressed
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _set_movement(pressed: bool) -> void:
	for key in [KEY_W, KEY_A, KEY_S, KEY_D]:
		_set_key(key, pressed)

func _send_key(key: Key, pressed: bool) -> void:
	_set_key(key, pressed)

func _capture_result(result: Dictionary) -> void:
	_last_result = result.duplicate(true)

func _frames(count: int) -> void:
	for _index in range(count):
		await get_tree().physics_frame

func _write_report() -> void:
	_report["elapsed_seconds"] = float(Time.get_ticks_msec() - _started_ms) / 1000.0
	var save_path := OS.get_environment("SNAPLAND_SAVE_PATH")
	if not save_path.is_empty():
		var report_path := save_path.get_base_dir().path_join("native-photo-collection-report.json")
		var error := DirAccess.make_dir_recursive_absolute(report_path.get_base_dir())
		if error == OK or error == ERR_ALREADY_EXISTS:
			var file := FileAccess.open(report_path, FileAccess.WRITE)
			if file != null:
				file.store_string(JSON.stringify(_report, "\t"))
				file.close()
	print("NATIVE_PHOTO_COLLECTION_REPORT_BEGIN")
	print(JSON.stringify(_report, "\t"))
	print("NATIVE_PHOTO_COLLECTION_REPORT_END")

func _finish(success: bool, reason: String) -> void:
	_set_movement(false)
	_report["status"] = "PASS" if success else "FAIL"
	_report["failure_reason"] = reason
	_write_report()
	if success:
		print("PASS: scripted native gameplay photo and album review")
		get_tree().quit(0)
	else:
		push_error("Native photo collection review failed: " + reason)
		get_tree().quit(1)

func _fail(reason: String) -> void:
	_failure = reason
	await _finish(false, reason)

func _fail_now(reason: String) -> void:
	push_error("Native photo collection review failed: " + reason)
	get_tree().quit(1)
