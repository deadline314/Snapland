extends Node
## GPU review of the real time-postcard capture, persistence, and album viewer.

const MAIN_SCENE := "res://game/main.tscn"
const PHOTO_ID := "postcard-time-noon"
const MAX_WAIT_SECONDS := 20.0
const HOLD_SECONDS := 2.0

var _main: Node
var _world: Node
var _progress: Node
var _save_path := ""
var _out_dir := ""
var _failure := ""
var _started_ms := 0
var _before := {}
var _report := {
	"status": "running",
	"review": "real time picker and collection button; read-only except intended noon postcard and its 20-coin reward",
	"human_played": false,
	"scripted_placement": "Player root is placed beside the authored guide interaction point; this is not a human free-roam claim.",
	"input_evidence": [],
	"screenshots": [],
}

func _ready() -> void:
	_save_path = OS.get_environment("SNAPLAND_SAVE_PATH").strip_edges()
	if _save_path.is_empty() or DisplayServer.get_name() == "headless":
		_fail_now("Requires a GPU-backed display and an isolated absolute SNAPLAND_SAVE_PATH.")
		return
	_out_dir = _save_path.get_base_dir()
	if not _out_dir.is_absolute_path():
		_fail_now("SNAPLAND_SAVE_PATH must be absolute.")
		return
	var mkdir_error := DirAccess.make_dir_recursive_absolute(_out_dir)
	if mkdir_error != OK and mkdir_error != ERR_ALREADY_EXISTS:
		_fail_now("Could not create isolated output directory: " + _out_dir)
		return
	for proof_name in ["native-time-photo-picker.png", "native-time-photo-collected-panel.png", "native-time-photo-original.png", "native-time-photo-original-viewer.png", "native-time-photo-original-review.json"]:
		if FileAccess.file_exists(_out_dir.path_join(proof_name)):
			_fail_now("Isolated proof output already exists; refusing to overwrite: " + proof_name)
			return
	_started_ms = Time.get_ticks_msec()
	get_window().size = Vector2i(1280, 720)
	_run.call_deferred()

func _run() -> void:
	_progress = get_tree().root.get_node_or_null("Progress")
	if _progress == null:
		await _fail("Progress autoload is missing")
		return
	if not _progress.photos.is_empty() or int(_progress.normal_count()) != 0 or int(_progress.devil_count()) != 0:
		await _fail("Use a fresh isolated profile with no photos or game awards; fixture will not reset it.")
		return
	_before = _snapshot()
	var packed := load(MAIN_SCENE) as PackedScene
	if packed == null:
		await _fail("Could not load Main scene")
		return
	_main = packed.instantiate()
	_main.name = "NativeTimePhotoOriginalMain"
	get_tree().root.add_child(_main)
	await _frames(10)
	_world = _main.world
	if _main.modal_kind == "dialogue":
		_send_key(KEY_ESCAPE, true)
		await _frames(1)
		_send_key(KEY_ESCAPE, false)
		await _frames(5)
	if _main.modal_kind != "" or not bool(_progress.intro_seen):
		await _fail("Actual Escape did not safely close arrival dialogue")
		return
	var guide: Dictionary = _world._point_by_id("guide")
	if guide.is_empty() or not guide.has("position"):
		await _fail("World does not expose the authored guide interaction point")
		return
	_world.player.position = guide.position + Vector3(0, 0.3, 1.2)
	await _frames(35)
	if str(_world.nearest.get("id", "")) != "guide":
		await _fail("Scripted station placement did not resolve to guide; nearest=%s" % str(_world.nearest))
		return
	_send_key(KEY_T, true)
	await _frames(1)
	_send_key(KEY_T, false)
	if not await _wait_for(func() -> bool: return _main.modal_kind == "time", "time picker"):
		await _fail(_failure)
		return
	_report["input_evidence"].append("actual T key opened time picker at the authored guide station")
	var dawn := _main.overlay.find_child("TimePhase_dawn", true, false) as Button
	var noon := _main.overlay.find_child("TimePhase_noon", true, false) as Button
	if dawn == null or noon == null or not await _click(dawn) or not await _click(noon):
		await _fail("Could not use actual mouse clicks to select dawn, then noon")
		return
	if str(_progress.settings.get("time_phase", "")) != "noon":
		await _fail("Actual Noon button did not set the saved phase")
		return
	_report["input_evidence"].append("actual mouse clicks selected dawn and then Noon")
	if not await _capture("native-time-photo-picker.png", HOLD_SECONDS):
		await _fail(_failure)
		return
	var collect := _main.overlay.find_child("CollectTimePostcard", true, false) as Button
	if collect == null or collect.disabled or not await _click(collect):
		await _fail("Actual CollectTimePostcard button was absent, disabled, or not clickable")
		return
	_report["input_evidence"].append("actual mouse click activated CollectTimePostcard")
	if not await _wait_for(func() -> bool: return _progress.photos.has(PHOTO_ID) and collect.disabled, "saved postcard and refreshed time panel"):
		await _fail(_failure)
		return
	var photo: Dictionary = _progress.photos.get(PHOTO_ID, {})
	var originals := _paths(photo, "original_frames")
	var thumbnails := _paths(photo, "frames")
	if _progress.photos.size() != 1 or originals.size() != 1 or thumbnails.size() != 1:
		await _fail("Expected one original and one thumbnail; originals=%d thumbnails=%d" % [originals.size(), thumbnails.size()])
		return
	if not _valid_image(originals[0], Vector2i(1280, 720)) or not _valid_image(thumbnails[0], Vector2i(320, 180)):
		await _fail("Saved source must be 1280x720 and its bounded thumbnail 320x180")
		return
	var original_copy := _out_dir.path_join("native-time-photo-original.png")
	if FileAccess.file_exists(original_copy):
		await _fail("Refusing to overwrite proof image: " + original_copy)
		return
	var copy_error := DirAccess.copy_absolute(originals[0], original_copy)
	if copy_error != OK or not _valid_image(original_copy, Vector2i(1280, 720)) or FileAccess.get_file_as_bytes(original_copy) != FileAccess.get_file_as_bytes(originals[0]):
		await _fail("Could not preserve review copy of captured original: " + original_copy)
		return
	if not await _capture("native-time-photo-collected-panel.png", HOLD_SECONDS):
		await _fail(_failure)
		return
	if int(_progress.coins) != int(_before.coins) + 20 or int(_progress.normal_count()) != int(_before.normal) or int(_progress.devil_count()) != int(_before.devil):
		await _fail("Expected only the postcard's 20 coins and no game photo awards; before=%s now=%s/%s/%s" % [str(_before), str(_progress.coins), str(_progress.normal_count()), str(_progress.devil_count())])
		return
	_report["capture"] = {"photo_id": PHOTO_ID, "original_path": originals[0], "thumbnail_path": thumbnails[0], "proof_original_copy": original_copy, "original_size": [1280, 720], "thumbnail_size": [320, 180], "coins_before": int(_before.coins), "coins_after": int(_progress.coins), "normal_count": int(_progress.normal_count()), "devil_count": int(_progress.devil_count())}
	_send_key(KEY_ESCAPE, true)
	await _frames(1)
	_send_key(KEY_ESCAPE, false)
	await _frames(3)
	_send_key(KEY_M, true)
	await _frames(1)
	_send_key(KEY_M, false)
	if not await _wait_for(func() -> bool: return _main.modal_kind == "ticket", "voyage pass"):
		await _fail("Actual M key did not open voyage pass")
		return
	var album_button := _find_text_button(_main.overlay, "拍貼收藏本")
	if album_button == null or not await _click(album_button):
		await _fail("Could not click actual album button inside voyage pass")
		return
	if not await _wait_for(func() -> bool: return _main.modal_kind == "album", "collection album"):
		await _fail(_failure)
		return
	var time_tab := _main.overlay.find_child("AlbumTab_time", true, false) as Button
	if time_tab == null or not await _click(time_tab):
		await _fail("Could not click actual time-postcard album tab")
		return
	var tile := _main.overlay.find_child("AlbumPhoto_" + PHOTO_ID, true, false) as Button
	if tile == null or not tile.visible or not await _click(tile):
		await _fail("Collected Noon postcard tile is not visible/clickable")
		return
	if not await _wait_for(func() -> bool: return _main.overlay.find_child("PhotoViewer", true, false) != null, "original viewer"):
		await _fail(_failure)
		return
	await _frames(5)
	var viewer: Control = _main.overlay.find_child("PhotoViewer", true, false)
	var image_rect := viewer.find_child("PhotoViewerImage", true, false) as TextureRect
	if image_rect == null or image_rect.texture == null or image_rect.texture.get_size() != Vector2(1280, 720) or image_rect.stretch_mode != TextureRect.STRETCH_KEEP_ASPECT_CENTERED:
		await _fail("Viewer did not decode the complete 1280x720 original with preserved aspect ratio")
		return
	var picture_rect := image_rect.get_global_rect()
	if picture_rect.size.x < 600 or picture_rect.size.y < 330 or not get_viewport().get_visible_rect().encloses(picture_rect):
		await _fail("Original viewer content is cropped or too small: %s" % str(picture_rect))
		return
	if not await _capture("native-time-photo-original-viewer.png", HOLD_SECONDS):
		await _fail(_failure)
		return
	_send_key(KEY_ESCAPE, true)
	await _frames(1)
	_send_key(KEY_ESCAPE, false)
	if not await _wait_for(func() -> bool: return _main.overlay.find_child("PhotoViewer", true, false) == null and _main.modal_kind == "album", "Escape closing viewer"):
		await _fail(_failure)
		return
	var after := _snapshot()
	if _progress.photos.size() != 1 or _progress.photos.get(PHOTO_ID, {}) != photo or after.normal != _before.normal or after.devil != _before.devil or after.achievements != _before.achievements or after.quests != _before.quests or after.coins != int(_before.coins) + 20:
		await _fail("Album viewing changed postcard records, unrelated progress, or game awards")
		return
	_report["viewer"] = {"dimensions": [1280, 720], "content_rect": [picture_rect.position.x, picture_rect.position.y, picture_rect.size.x, picture_rect.size.y], "aspect_mode": "keep_aspect_centered", "closed_by": "actual Escape"}
	_report["elapsed_seconds"] = float(Time.get_ticks_msec() - _started_ms) / 1000.0
	await _finish(true, "")

func _snapshot() -> Dictionary:
	return {"coins": int(_progress.coins), "normal": int(_progress.normal_count()), "devil": int(_progress.devil_count()), "achievements": _progress.achievements.duplicate(true), "quests": _progress.quests.duplicate(true)}

func _paths(photo: Dictionary, key: String) -> Array[String]:
	var result: Array[String] = []
	var values: Variant = photo.get(key, [])
	if values is Array:
		for value in values: result.append(str(value))
	return result

func _valid_image(path: String, expected: Vector2i) -> bool:
	if path.is_empty() or not FileAccess.file_exists(path): return false
	var image := Image.new()
	return image.load(path) == OK and image.get_size() == expected

func _find_text_button(root: Node, text: String) -> Button:
	if root == null: return null
	for child in root.get_children():
		if child is Button and (child as Button).text.strip_edges() == text.strip_edges(): return child
		var found := _find_text_button(child, text)
		if found != null: return found
	return null

func _click(button: Control) -> bool:
	if not is_instance_valid(button) or not button.is_visible_in_tree() or not button.get_global_rect().has_point(button.get_global_rect().get_center()): return false
	var point := button.get_global_rect().get_center()
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.global_position = point
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await get_tree().process_frame
	await _frames(3)
	return true

func _send_key(key: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _capture(name: String, hold_seconds: float) -> bool:
	await get_tree().create_timer(hold_seconds).timeout
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := _out_dir.path_join(name)
	if image == null or image.is_empty() or image.get_size() != Vector2i(1280, 720):
		_failure = "Rendered proof must be 1280x720: " + name
		return false
	if FileAccess.file_exists(path):
		_failure = "Refusing to overwrite existing proof image: " + path
		return false
	if image.save_png(path) != OK:
		_failure = "Could not save rendered proof: " + path
		return false
	_report["screenshots"].append({"path": path, "size": [1280, 720], "state": name, "hold_seconds": hold_seconds})
	return true

func _wait_for(condition: Callable, label: String) -> bool:
	var deadline := Time.get_ticks_msec() + int(MAX_WAIT_SECONDS * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if condition.call(): return true
		await get_tree().process_frame
	_failure = "Timed out waiting for " + label
	return false

func _frames(count: int) -> void:
	for _index in range(count): await get_tree().physics_frame

func _write_report() -> void:
	_report["failure_reason"] = _failure
	_report["process_id"] = OS.get_process_id()
	_report["display_server"] = DisplayServer.get_name()
	_report["viewport_size"] = [get_viewport().size.x, get_viewport().size.y]
	var file := FileAccess.open(_out_dir.path_join("native-time-photo-original-review.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(_report, "\t"))
		file.close()
	print("NATIVE_TIME_PHOTO_REVIEW_BEGIN")
	print(JSON.stringify(_report, "\t"))
	print("NATIVE_TIME_PHOTO_REVIEW_END")

func _finish(success: bool, reason: String) -> void:
	_failure = reason
	_report["status"] = "PASS" if success else "FAIL"
	_write_report()
	if success:
		print("PASS: native time postcard original and viewer review")
		get_tree().quit(0)
	else:
		push_error("Native time postcard review failed: " + reason)
		get_tree().quit(1)

func _fail(reason: String) -> void:
	await _finish(false, reason)

func _fail_now(reason: String) -> void:
	_failure = reason
	_report["status"] = "FAIL"
	_write_report()
	push_error("Native time postcard review failed: " + reason)
	get_tree().quit(1)
