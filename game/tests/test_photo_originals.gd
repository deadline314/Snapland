extends Node

var failures: Array[String] = []
var _main: Node
var _overlay: Control
var _book: Control

func _ready() -> void:
	if OS.get_environment("SNAPLAND_SAVE_PATH").is_empty():
		push_error("Set SNAPLAND_SAVE_PATH to an isolated profile before photo original tests.")
		get_tree().quit(1)
		return
	call_deferred("_run")

func _run() -> void:
	var progress := get_tree().root.get_node_or_null("Progress")
	_check(progress != null, "photo originals test uses the real Progress autoload")
	if progress == null:
		_finish()
		return
	progress.reset_progress()
	_main = load("res://game/main.gd").new()
	var full_capture := Image.create(960, 540, false, Image.FORMAT_RGBA8)
	full_capture.fill(Color("#e33b27"))
	full_capture.set_pixel(10, 10, Color("#245ae8"))
	_check(_main.has_method("_append_photo_image"), "Main retains the full capture alongside its album thumbnail")
	if _main.has_method("_append_photo_image"):
		_main.call("_append_photo_image", full_capture)
	_check(_main.photo_frames.size() == 1 and _main.photo_frames[0].get_width() == 320 and _main.photo_frames[0].get_height() == 180, "bounded album thumbnail remains 320x180")
	_check(_main.get("photo_original_frames") is Array and _main.photo_original_frames.size() == 1 and _main.photo_original_frames[0].get_width() == 960 and _main.photo_original_frames[0].get_height() == 540, "original capture keeps native 960x540 resolution")
	for capture_index in range(5): _main.call("_append_photo_image",full_capture)
	_check(_main.photo_frames.size()==Progress.MAX_GAME_PHOTO_FRAMES and _main.photo_original_frames.size()==Progress.MAX_GAME_PHOTO_FRAMES,"capture buffers agree with the collection limit and cannot save unreferenced fourth originals")
	_main.photo_frames.resize(1)
	_main.photo_original_frames.resize(1)
	var oversized_capture := Image.create(2050, 2050, false, Image.FORMAT_RGBA8)
	var bounded_capture: Image = _main.call("_prepare_photo_original", oversized_capture)
	_check(bounded_capture.get_width() * bounded_capture.get_height() <= 4 * 1024 * 1024 and bounded_capture.get_width() <= 2050 and bounded_capture.get_height() <= 2050, "capture bounds large sources without ever upscaling")
	var thumbs: Array[String] = []
	var thumb_result: Variant = _main.call("_save_photo_frames", "game-001")
	for path_value in thumb_result:
		thumbs.append(str(path_value))
	var originals: Array[String] = []
	if _main.has_method("_save_photo_original_frames"):
		var original_result: Variant = _main.call("_save_photo_original_frames", "game-001")
		for path_value in original_result:
			originals.append(str(path_value))
	_check(thumbs.size() == 1 and originals.size() == 1 and FileAccess.file_exists(thumbs[0]) and FileAccess.file_exists(originals[0]), "thumbnail and original are written as separate files")
	_check(not _main.call("_sync_finished_photo_thumbnails", {"game_id": "game-001", "success": false, "practice": false}, thumbs, originals), "failed games cannot attach either photo resolution")
	_check(not _main.call("_sync_finished_photo_thumbnails", {"game_id": "game-001", "success": true, "practice": true}, thumbs, originals), "practice games cannot attach either photo resolution")
	_check(progress.call("complete_game", "game-001", true) == null, "fixture awards through the existing game completion path")
	var attach_ok := bool(progress.call("attach_welcome_game_photo_frames", "game-001", thumbs, true, originals)) if progress.has_method("attach_welcome_game_photo_frames") else false
	_check(attach_ok, "game attachment stores optional shared originals without granting another card")
	var ordinary: Dictionary = progress.photos.get("photo-welcome-game-1", {})
	var devil: Dictionary = progress.photos.get("photo-welcome-devil-1", {})
	_check(ordinary.get("frames", []) == thumbs and devil.get("frames", []) == thumbs, "ordinary and devil keep their shared thumbnail contract")
	_check(ordinary.get("original_frames", []) == originals and devil.get("original_frames", []) == originals, "ordinary and devil reference the same optional original files")
	_check(progress.normal_count() == 1 and progress.devil_count("welcome") == 1, "original attachment does not change collection awards")
	progress.photos["photo-welcome-devil-1"].erase("original_frames")
	_check(progress.call("_backfill_legacy_devil_photo_frames"), "legacy devil backfill can copy an existing ordinary original")
	_check(progress.photos["photo-welcome-devil-1"].get("original_frames", []) == originals, "legacy backfill shares the original path without granting a card")
	progress.save_progress()
	progress._reset_memory()
	progress.load_progress()
	ordinary = progress.photos.get("photo-welcome-game-1", {})
	_check(ordinary.get("original_frames", []) == originals, "optional original metadata persists through a save reload")
	var coin_total := int(progress.coins)
	_check(progress.collect_time_postcard("noon", thumbs[0], originals[0]), "time postcard accepts a valid optional original alongside its thumbnail")
	_check(progress.photos.get("postcard-time-noon", {}).get("original_frames", []) == [originals[0]], "time postcard persists its optional original path")
	_check(int(progress.coins) == coin_total + 20, "time postcard award remains the existing single collection reward")

	var oversized_path := Progress._save_path().get_base_dir().path_join("photos/crc-valid-original-huge-ihdr.png")
	var huge_bytes := Marshalls.base64_to_raw("iVBORw0KGgoAAAANSUhEUn////9/////CAYAAAAUyQtmAAAAEElEQVRub3QtZGVjb2RlZC1odWdlLd8q9AAAAABJRU5ErkJggg==")
	_check(_write_bytes(oversized_path, huge_bytes), "write CRC-valid oversized-original IHDR")
	var decoder_calls := int(progress.get("_game_photo_original_decoder_invocations"))
	var image: Image = progress.call("_read_game_photo_original_image", "photo-welcome-game-1", oversized_path)
	_check(image == null and int(progress.get("_game_photo_original_decoder_invocations")) == decoder_calls, "oversized original is rejected before native image decoding")
	var oversized_file_path := Progress._save_path().get_base_dir().path_join("photos/oversized-original-file.png")
	var oversized_file_bytes := PackedByteArray()
	oversized_file_bytes.resize(16 * 1024 * 1024 + 1)
	_check(_write_bytes(oversized_file_path, oversized_file_bytes), "write an original file beyond the 16 MiB cap")
	image = progress.call("_read_game_photo_original_image", "photo-welcome-game-1", oversized_file_path)
	_check(image == null and int(progress.get("_game_photo_original_decoder_invocations")) == decoder_calls, "oversized original file is rejected before native image decoding")

	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.name = "AdaptiveMenuPanel"
	center.add_child(panel)
	var content := VBoxContainer.new()
	panel.add_child(content)
	progress.photos["photo-welcome-game-2"] = {"frames": thumbs, "original_frames": [oversized_path]}
	progress.photos["photo-welcome-game-3"] = {"frames": thumbs}
	var cards_before_open: int = progress.normal_count()
	var devils_before_open: int = progress.devil_count("welcome")
	_book = load("res://game/ui/collection_book_panel.gd").new()
	_book.setup(progress, [{"id": "game-001", "name": "測試拍貼"}, {"id": "game-002", "name": "過大原圖"}, {"id": "game-003", "name": "舊版拍貼"}], [], Callable(self, "_load_photo"))
	content.add_child(_book)
	await get_tree().process_frame
	var tile := _overlay.find_child("AlbumPhoto_photo-welcome-game-1", true, false) as Button
	_check(tile != null, "original photo remains in the regular album grid")
	if tile != null:
		tile.emit_signal("pressed")
		await get_tree().process_frame
	var viewer := _overlay.find_child("PhotoViewer", true, false) as Control
	var displayed := viewer.find_child("PhotoViewerImage", true, false) as TextureRect if viewer != null else null
	_check(displayed != null and displayed.texture is Texture2D and displayed.texture.get_width() == 960 and displayed.texture.get_height() == 540, "viewer decodes and displays the native original size")
	if displayed != null and displayed.texture is Texture2D:
		var original_pixel := displayed.texture.get_image().get_pixel(10, 10)
		_check(original_pixel.b > 0.8 and original_pixel.r < 0.25, "viewer retains source detail instead of enlarging its red thumbnail")
	_check(_book.get("_original_decode_count") == 1, "opening one card decodes only its selected original and does not build a large-image cache")
	if viewer != null:
		viewer.queue_free()
		await get_tree().process_frame
	var oversized_tile := _overlay.find_child("AlbumPhoto_photo-welcome-game-2", true, false) as Button
	if oversized_tile != null:
		oversized_tile.emit_signal("pressed")
		await get_tree().process_frame
	viewer = _overlay.find_child("PhotoViewer", true, false) as Control
	displayed = viewer.find_child("PhotoViewerImage", true, false) as TextureRect if viewer != null else null
	_check(displayed != null and displayed.texture is Texture2D and displayed.texture.get_width() == 320, "oversized IHDR fails safely and falls back to its bounded thumbnail")
	_check(_book.get("_original_decode_count") == 2, "large-image decode attempt is limited to the currently opened card")
	if viewer != null:
		viewer.queue_free()
		await get_tree().process_frame
	var legacy_tile := _overlay.find_child("AlbumPhoto_photo-welcome-game-3", true, false) as Button
	if legacy_tile != null:
		legacy_tile.emit_signal("pressed")
		await get_tree().process_frame
	viewer = _overlay.find_child("PhotoViewer", true, false) as Control
	displayed = viewer.find_child("PhotoViewerImage", true, false) as TextureRect if viewer != null else null
	_check(displayed != null and displayed.texture is Texture2D and displayed.texture.get_width() == 320, "legacy record without an original still opens its saved thumbnail")
	_check((_overlay.find_child("AlbumPhotoDetails", true, false) as Label).text.contains("完整尺寸照片沒有留下來"), "legacy fallback explains the missing full-size picture in player-friendly language")
	_check(progress.normal_count() == cards_before_open and progress.devil_count("welcome") == devils_before_open, "viewing the original does not award or spend cards")
	_finish()

func _load_photo(path: String) -> Texture2D:
	var image := Image.load_from_file(path)
	return ImageTexture.create_from_image(image) if image != null and not image.is_empty() else null

func _write_bytes(path: String, bytes: PackedByteArray) -> bool:
	var error := DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if error != OK and error != ERR_ALREADY_EXISTS:
		return false
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_buffer(bytes)
	file.close()
	return true

func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	push_error("FAIL: " + message)

func _finish() -> void:
	if _book != null and is_instance_valid(_book):
		_book.queue_free()
	if is_instance_valid(_main):
		_main.free()
	if failures.is_empty():
		print("PASS: bounded photo originals, shared collection metadata, safe viewer loading")
		get_tree().quit(0)
	else:
		push_error("%d photo-original checks failed" % failures.size())
		get_tree().quit(1)
