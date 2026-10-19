extends Node
## Native app-restart review of persisted ordinary/devil photo originals.

const MAIN_SCENE_PATH := "res://game/main.tscn"
const PHOTO_IDS := ["photo-welcome-game-12", "photo-welcome-devil-12"]
const CAPTURE_ENV := "SNAPLAND_NATIVE_CAPTURE"
const REVIEW_TIMEOUT_SECONDS := 30.0

var _main: Node
var _book: Node
var _progress: Node
var _profile_path := ""
var _profile_bytes := PackedByteArray()
var _started_ms := 0
var _failure := ""
var _photo_snapshot := {}
var _counts_snapshot := {}
var _report := {
	"status": "running",
	"review": "persisted app-restart album and original viewer; read-only profile",
	"input_evidence": [],
	"records": {},
	"images": [],
	"screenshots_opted_in": false,
}


func _ready() -> void:
	_profile_path = OS.get_environment("SNAPLAND_SAVE_PATH").strip_edges()
	if _profile_path.is_empty() or DisplayServer.get_name() == "headless":
		_fail_now("Requires a rendered display and the persisted isolated SNAPLAND_SAVE_PATH.")
		return
	_started_ms = Time.get_ticks_msec()
	_report["screenshots_opted_in"] = OS.get_environment(CAPTURE_ENV).strip_edges() == "1"
	get_window().size = Vector2i(1280, 720)
	_run.call_deferred()


func _run() -> void:
	_progress = get_tree().root.get_node_or_null("Progress")
	if _progress == null:
		await _fail("Progress autoload is missing")
		return
	if not FileAccess.file_exists(_profile_path):
		await _fail("Persisted save is missing: %s" % _profile_path)
		return
	_profile_bytes = FileAccess.get_file_as_bytes(_profile_path)
	if _profile_bytes.is_empty():
		await _fail("Persisted save is empty: %s" % _profile_path)
		return
	for photo_id in PHOTO_IDS:
		var photo: Variant = _progress.photos.get(photo_id, null)
		if not photo is Dictionary or photo.is_empty():
			await _fail("Persisted profile is missing %s" % photo_id)
			return
		var originals := _photo_paths(photo, "original_frames")
		var thumbnails := _photo_paths(photo, "frames")
		if originals.size() != 3 or thumbnails.size() != 3:
			await _fail("%s must have the three persisted shared original and thumbnail paths" % photo_id)
			return
		for path in originals:
			if not _valid_png(path, Vector2i(1280, 720)):
				await _fail("Persisted original is missing or not 1280x720: %s" % path)
				return
		for path in thumbnails:
			if not _valid_png(path, Vector2i(320, 180)):
				await _fail("Persisted thumbnail is missing or not 320x180: %s" % path)
				return
	var ordinary: Dictionary = _progress.photos[PHOTO_IDS[0]]
	var devil: Dictionary = _progress.photos[PHOTO_IDS[1]]
	var original_paths := _photo_paths(ordinary, "original_frames")
	var devil_original_paths := _photo_paths(devil, "original_frames")
	var thumbnail_paths := _photo_paths(ordinary, "frames")
	if original_paths != devil_original_paths or thumbnail_paths != _photo_paths(devil, "frames"):
		await _fail("Persisted ordinary and devil entries no longer share the same originals and thumbnails")
		return
	if int(_progress.normal_count()) != 1 or int(_progress.devil_count()) != 1:
		await _fail("Expected one ordinary and one devil collection count after process restart")
		return
	_photo_snapshot = _progress.photos.duplicate(true)
	_counts_snapshot = _current_counts()
	_report["save_path"] = _profile_path
	_report["process_id"] = OS.get_process_id()
	_report["engine_version"] = Engine.get_version_info()
	_report["display_server"] = DisplayServer.get_name()
	_report["viewport_size"] = [get_viewport().size.x, get_viewport().size.y]
	_report["records"] = {
		"ordinary_id": PHOTO_IDS[0],
		"devil_id": PHOTO_IDS[1],
		"normal_count": int(_progress.normal_count()),
		"devil_count": int(_progress.devil_count()),
		"shared_original_paths": original_paths,
		"shared_thumbnail_paths": thumbnail_paths,
		"original_dimensions": [1280, 720],
		"thumbnail_dimensions": [320, 180],
	}

	var packed: PackedScene = load(MAIN_SCENE_PATH)
	if packed == null:
		await _fail("Could not load Main scene")
		return
	_main = packed.instantiate()
	_main.name = "NativePhotoReopenMain"
	get_tree().root.add_child(_main)
	await _frames(8)
	if bool(_report["screenshots_opted_in"]):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		get_window().size = Vector2i(1280, 720)
		await _frames(4)
	if not await _open_album_through_ticket():
		await _fail(_failure)
		return
	if not await _wait_for(func() -> bool: return _main.modal_kind == "album", "album after ticket click"):
		await _fail(_failure)
		return
	_book = _find_collection_book(_main.overlay)
	if _book == null:
		await _fail("Actual CollectionBookPanel script node is missing")
		return
	if not await _open_category("normal", PHOTO_IDS[0], "MAIN-13-native-reopened-ordinary.png"):
		await _fail(_failure)
		return
	if not await _open_category("devil", PHOTO_IDS[1], "MAIN-13-native-reopened-devil.png"):
		await _fail(_failure)
		return
	var back := _find_button_with_text(_main.overlay, "返回遊園  ·  Esc")
	if back == null or not await _click_control(back):
		await _fail("Could not use the actual album back button")
		return
	_report["input_evidence"].append("real mouse clicks: M-ticket collection button, ordinary/devil tabs and first-page photo cards; Escape and album back button")
	await _frames(4)
	if _main.modal_kind != "" or not _records_unchanged():
		await _fail("Closing the album changed collection state or did not return to the island")
		return
	_report["final_counts"] = _current_counts()
	_report["save_file_unchanged"] = FileAccess.get_file_as_bytes(_profile_path) == _profile_bytes
	if not bool(_report["save_file_unchanged"]):
		await _fail("Opening and closing the album modified the persisted save file")
		return
	await _finish(true, "")


func _open_album_through_ticket() -> bool:
	_send_key(KEY_M, true)
	await _frames(1)
	_send_key(KEY_M, false)
	if not await _wait_for(func() -> bool: return _main.modal_kind == "ticket", "voyage pass"):
		_failure = "Actual M input did not open the voyage pass"
		return false
	_report["input_evidence"].append("actual M key opens voyage pass")
	var album_button := _find_button_with_text(_main.overlay, "拍貼收藏本")
	if album_button == null or not await _click_control(album_button):
		_failure = "Could not click the visible 拍貼收藏本 button in the voyage pass"
		return false
	return true


func _open_category(category: String, photo_id: String, screenshot_name: String) -> bool:
	var tab_name := "AlbumTab_normal" if category == "normal" else "AlbumTab_devil"
	var tab := _main.overlay.find_child(tab_name, true, false) as Button
	if tab == null or not await _click_control(tab):
		_failure = "Could not click the real %s album tab" % category
		return false
	var grid: Node = _main.overlay.find_child("AlbumPhotoGrid", true, false)
	var visible_cards := 0
	for card in grid.get_children():
		if card is Control and (card as Control).visible:
			visible_cards += 1
	var tile := _main.overlay.find_child("AlbumPhoto_" + photo_id, true, false) as Button
	if tile == null or not tile.visible:
		_failure = "%s collected photo must sort onto the first album page" % category
		return false
	if visible_cards != 4:
		_failure = "%s album page should show four cards; got %d" % [category, visible_cards]
		return false
	if not await _capture_review_image(screenshot_name):
		return false
	if not await _click_control(tile):
		_failure = "Could not click the actual collected %s photo tile" % category
		return false
	if not await _wait_for(func() -> bool: return _main.overlay.find_child("PhotoViewer", true, false) != null, "%s original photo viewer" % category):
		return false
	var viewer: Control = _main.overlay.find_child("PhotoViewer", true, false)
	var image_rect := viewer.find_child("PhotoViewerImage", true, false) as TextureRect
	if image_rect == null or image_rect.texture == null or image_rect.texture.get_size() != Vector2(1280, 720):
		_failure = "%s viewer did not decode its 1280x720 original" % category
		return false
	if image_rect.stretch_mode != TextureRect.STRETCH_KEEP_ASPECT_CENTERED:
		_failure = "%s viewer does not preserve the original aspect ratio" % category
		return false
	var decode_count_value: Variant = _book.get("_original_decode_count")
	if typeof(decode_count_value) != TYPE_INT:
		_failure = "CollectionBookPanel original decode counter must be an integer; actual=%s" % type_string(typeof(decode_count_value))
		return false
	var expected_decode_count := 1 if category == "normal" else 2
	if int(decode_count_value) != expected_decode_count:
		_failure = "Expected one newly decoded original per viewer open; category=%s count=%s" % [category, str(decode_count_value)]
		return false
	var records: Dictionary = _report["records"]
	records[category + "_viewer"] = {
		"photo_id": photo_id,
		"texture_dimensions": [image_rect.texture.get_width(), image_rect.texture.get_height()],
		"stretch_mode": "keep_aspect_centered",
		"original_decode_count": int(decode_count_value),
		"path": _photo_paths(_progress.photos[photo_id], "original_frames")[0],
	}
	_report["records"] = records
	if category == "normal" and not await _capture_review_image("MAIN-16-native-reopened-original.png"):
		return false
	if category == "normal":
		_send_key(KEY_ESCAPE, true)
		await _frames(1)
		_send_key(KEY_ESCAPE, false)
		if not await _wait_for(func() -> bool: return _main.overlay.find_child("PhotoViewer", true, false) == null, "Escape closing ordinary viewer"):
			return false
	else:
		var close := viewer.find_child("PhotoViewerClose", true, false) as Button
		if close == null or not await _click_control(close):
			_failure = "Could not click actual devil viewer's back button"
			return false
		if not await _wait_for(func() -> bool: return _main.overlay.find_child("PhotoViewer", true, false) == null, "devil viewer return button"):
			return false
	if not _records_unchanged():
		_failure = "Opening or closing %s viewer changed persisted photo records/counters" % category
		return false
	return true


func _capture_review_image(file_name: String) -> bool:
	if not bool(_report.get("screenshots_opted_in", false)):
		return true
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty() or image.get_size() != Vector2i(1280, 720):
		_failure = "Rendered frame for %s must be 1280x720" % file_name
		return false
	var directory := OS.get_environment("SNAPLAND_SAVE_PATH").get_base_dir().path_join("native-photo-reopen")
	var mkdir_error := DirAccess.make_dir_recursive_absolute(directory)
	if mkdir_error != OK and mkdir_error != ERR_ALREADY_EXISTS:
		_failure = "Could not create native proof image directory: %s" % directory
		return false
	var path := directory.path_join(file_name)
	if FileAccess.file_exists(path):
		_failure = "Refusing to overwrite existing proof image: %s" % path
		return false
	if image.save_png(path) != OK:
		_failure = "Could not save proof screenshot: %s" % path
		return false
	var persisted := Image.new()
	if persisted.load(path) != OK or persisted.get_size() != Vector2i(1280, 720):
		_failure = "Saved proof image dimensions are invalid: %s" % path
		return false
	var images: Array = _report["images"]
	images.append({"path": path, "dimensions": [1280, 720], "state": file_name})
	_report["images"] = images
	return true


func _records_unchanged() -> bool:
	return _progress.photos == _photo_snapshot and _current_counts() == _counts_snapshot


func _current_counts() -> Dictionary:
	return {
		"normal": int(_progress.normal_count()),
		"devil": int(_progress.devil_count()),
		"coins": int(_progress.coins),
		"achievements": _progress.achievements.duplicate(true),
		"quests": _progress.quests.duplicate(true),
	}


func _photo_paths(photo: Dictionary, key: String) -> Array[String]:
	var paths: Array[String] = []
	var values: Variant = photo.get(key, [])
	if values is Array:
		for value in values:
			paths.append(str(value))
	return paths


func _valid_png(path: String, expected_size: Vector2i) -> bool:
	if path.is_empty() or not FileAccess.file_exists(path):
		return false
	var image := Image.new()
	return image.load(path) == OK and image.get_size() == expected_size


func _find_button_with_text(root: Node, button_text: String) -> Button:
	if root == null:
		return null
	for child in root.get_children():
		if child is Button and (child as Button).text.strip_edges() == button_text.strip_edges():
			return child as Button
		var found := _find_button_with_text(child, button_text)
		if found != null:
			return found
	return null


func _find_collection_book(root: Node) -> Node:
	if root == null:
		return null
	for child in root.get_children():
		var attached_script := child.get_script() as Script
		if attached_script != null and attached_script.resource_path == "res://game/ui/collection_book_panel.gd":
			return child
		var found := _find_collection_book(child)
		if found != null:
			return found
	return null


func _click_control(control: Control) -> bool:
	if not is_instance_valid(control) or not control.is_inside_tree() or not control.is_visible_in_tree():
		return false
	var ancestor := control.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer:
			(ancestor as ScrollContainer).ensure_control_visible(control)
		ancestor = ancestor.get_parent()
	await get_tree().process_frame
	var position := control.get_global_rect().get_center()
	for pressed in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.position = position
		click.global_position = position
		click.pressed = pressed
		Input.parse_input_event(click)
		Input.flush_buffered_events()
		await get_tree().process_frame
	await _frames(2)
	return true


func _send_key(key: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _frames(count: int) -> void:
	for _index in range(count):
		await get_tree().physics_frame


func _wait_for(condition: Callable, label: String) -> bool:
	var deadline := Time.get_ticks_msec() + int(REVIEW_TIMEOUT_SECONDS * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if condition.call():
			return true
		await get_tree().process_frame
	_failure = "Timed out waiting for %s" % label
	return false


func _write_report() -> void:
	_report["elapsed_seconds"] = float(Time.get_ticks_msec() - _started_ms) / 1000.0
	_report["failure_reason"] = _failure
	if not _profile_path.is_empty():
		var report_path := _profile_path.get_base_dir().path_join("native-photo-reopen-review.json")
		var file := FileAccess.open(report_path, FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(_report, "\t"))
			file.close()
	print("NATIVE_PHOTO_REOPEN_REPORT_BEGIN")
	print(JSON.stringify(_report, "\t"))
	print("NATIVE_PHOTO_REOPEN_REPORT_END")


func _finish(success: bool, reason: String) -> void:
	_failure = reason
	_report["status"] = "PASS" if success else "FAIL"
	_report["save_file_unchanged"] = FileAccess.get_file_as_bytes(_profile_path) == _profile_bytes
	_write_report()
	if success:
		print("PASS: persisted ordinary/devil album reopen and full-resolution originals")
		get_tree().quit(0)
	else:
		push_error("Native photo reopen review failed: " + reason)
		get_tree().quit(1)


func _fail(reason: String) -> void:
	_failure = reason
	await _finish(false, reason)


func _fail_now(reason: String) -> void:
	_failure = reason
	_report["status"] = "FAIL"
	_write_report()
	push_error("Native photo reopen review failed: " + reason)
	get_tree().quit(1)
