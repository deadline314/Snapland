extends Node

const Paper = preload("res://game/ui/paper_ui.gd")

class FakeProgress extends Node:
	var photos: Dictionary = {}
	var achievements: Dictionary = {}
	var quests: Dictionary = {}
	var coins := 120

	func normal_count() -> int:
		var count := 0
		for photo_id in photos:
			if str(photo_id).begins_with("photo-welcome-game-"):
				count += 1
		return count

	func devil_count(_zone := "welcome") -> int:
		return 0

	func _read_game_photo_image(_photo_id: String, path: String, image_cache: Dictionary) -> Image:
		if image_cache.has(path):
			return image_cache[path] as Image
		var image := Image.load_from_file(path)
		if image == null or image.get_width() != 320 or image.get_height() != 180:
			image_cache[path] = null
			return null
		image_cache[path] = image
		return image

var _failures: Array[String] = []
var _frame_path := ""
var _book: Control
var _overlay: Control

func _ready() -> void:
	if OS.get_environment("SNAPLAND_SAVE_PATH").is_empty():
		push_error("Set SNAPLAND_SAVE_PATH to an isolated profile before photo viewer tests.")
		get_tree().quit(1)
		return
	call_deferred("_run")

func _run() -> void:
	var save_path := OS.get_environment("SNAPLAND_SAVE_PATH")
	_frame_path = save_path.get_base_dir().path_join("photos/album-viewer-frame.png")
	_check(_write_photo(_frame_path), "create a real saved PNG photo fixture")
	var progress := FakeProgress.new()
	add_child(progress)
	progress.photos["photo-welcome-game-1"] = {"frames": [_frame_path]}
	progress.photos["photo-welcome-game-2"] = {"game_id": "game-002"}
	var before_photos: Dictionary = progress.photos.duplicate(true)
	var before_achievements: Dictionary = progress.achievements.duplicate(true)
	var before_quests: Dictionary = progress.quests.duplicate(true)
	var before_coins := progress.coins

	_overlay = Control.new()
	_overlay.name = "AlbumOverlay"
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)
	var center := CenterContainer.new()
	center.name = "RuntimeGeneratedModalCenter"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.name = "AdaptiveMenuPanel"
	panel.custom_minimum_size = Vector2(960, 600)
	center.add_child(panel)
	var content := VBoxContainer.new()
	content.name = "AdaptiveMenuContent"
	panel.add_child(content)
	_book = load("res://game/ui/collection_book_panel.gd").new()
	_book.setup(progress, [{"id": "game-001", "name": "第一趟遊園"}, {"id": "game-002", "name": "第二趟遊園"}], [], Callable(self, "_load_photo"))
	content.add_child(_book)
	await _frames(3)

	var tile := _overlay.find_child("AlbumPhoto_photo-welcome-game-1", true, false) as Control
	_check(tile != null, "collected photo remains in the existing book grid")
	_check(tile is Button, "collected photo tile is mouse and keyboard actionable")
	var tile_photo_frame := tile.find_child("SavedPhotoFrame", true, false) as Control if tile != null else null
	var frame_scale: float = Paper.physical_scale(tile_photo_frame) if tile_photo_frame != null else 1.0
	_check(tile_photo_frame != null and tile_photo_frame.size.x * frame_scale >= 219 and tile_photo_frame.size.y * frame_scale >= 123, "the album tile gives the real saved image a full 220×124 physical frame")
	var missing_tile := _overlay.find_child("AlbumPhoto_photo-welcome-game-2", true, false) as Button
	var missing_label := missing_tile.find_child("SavedPhotoFrame", true, false).get_child(0) as Label if missing_tile != null else null
	_check(missing_label != null and missing_label.text.contains("暫時看不清楚") and not missing_label.text.contains("讀取"), "a collected photo without a saved image gets friendly player-facing copy")
	if missing_tile != null:
		missing_tile.emit_signal("pressed")
		await _frames(1)
		_check(_overlay.find_child("PhotoViewer", true, false) == null, "a collected card with no real image never opens a fake viewer")
		_check((_overlay.find_child("AlbumPhotoDetails", true, false) as Label).text.contains("先留在本子裡"), "a missing photo gives a gentle explanation in the book")
	if tile is Button:
		tile.grab_focus()
		await _frames(1)
		_send_key(KEY_ENTER, true)
		await _frames(2)
		_send_key(KEY_ENTER, false)
		await _frames(2)
	var viewer := _overlay.find_child("PhotoViewer", true, false) as Control
	_check(viewer != null, "Enter opens the saved photo viewer without leaving the album")
	if viewer != null:
		var displayed := viewer.find_child("PhotoViewerImage", true, false) as TextureRect
		_check(displayed != null and displayed.texture is Texture2D, "viewer displays an actual saved texture")
		if displayed != null and displayed.texture is Texture2D:
			var image := displayed.texture.get_image()
			_check(image != null and image.get_width() == 320 and image.get_height() == 180, "viewer keeps the real saved photo dimensions and aspect ratio")
			_check(displayed.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED, "viewer centers the complete photo without cropping")
		_send_key(KEY_ESCAPE, true)
		await _frames(2)
		_send_key(KEY_ESCAPE, false)
		await _frames(2)
		_check(_overlay.find_child("PhotoViewer", true, false) == null and is_instance_valid(_book), "Escape closes only the viewer and keeps the book open")
		_check(tile.has_focus(), "closing the viewer restores focus to the selected photo tile")
	else:
		_check(false, "viewer behavior can be exercised only after opening the saved image")

	var title := _overlay.find_child("AlbumPhotoTitle", true, false) as Label
	if title != null:
		var tile_again := _overlay.find_child("AlbumPhoto_photo-welcome-game-1", true, false) as Control
		if tile_again is Button:
			tile_again.grab_focus()
			await _frames(1)
			(tile_again as Button).emit_signal("pressed")
			await _frames(2)
			viewer = _overlay.find_child("PhotoViewer", true, false) as Control
			var close_button := viewer.find_child("PhotoViewerClose", true, false) as Button if viewer != null else null
			_check(close_button != null and close_button.focus_mode == Control.FOCUS_ALL, "viewer offers a focusable close button for mouse and keyboard")
			if close_button != null:
				close_button.emit_signal("pressed")
				await _frames(2)
			_check(_overlay.find_child("PhotoViewer", true, false) == null, "close button returns to the collection book")
	_check(progress.photos == before_photos and progress.achievements == before_achievements and progress.quests == before_quests and progress.coins == before_coins, "opening and closing a photo does not award, consume, or mutate progress")
	_finish()

func _load_photo(path: String) -> Texture2D:
	var image := Image.load_from_file(path)
	if image == null or image.is_empty():
		return null
	return ImageTexture.create_from_image(image)

func _write_photo(path: String) -> bool:
	var error := DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if error != OK and error != ERR_ALREADY_EXISTS:
		return false
	var image := Image.create(320, 180, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.2, 0.55, 0.82, 1.0))
	return image.save_png(path) == OK

func _send_key(key: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.pressed = pressed
	Input.parse_input_event(event)

func _frames(count: int) -> void:
	for _index in range(count):
		await get_tree().process_frame

func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		_failures.append(message)

func _finish() -> void:
	if is_instance_valid(_overlay):
		_overlay.queue_free()
	for _index in range(2):
		await get_tree().process_frame
	if _failures.is_empty():
		print("PASS: saved album photo viewer, focus return, and immutable progress")
		get_tree().quit(0)
	else:
		push_error("Album photo viewer failures: " + str(_failures))
		get_tree().quit(1)
