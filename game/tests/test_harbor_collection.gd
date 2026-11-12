extends SceneTree

const Album = preload("res://game/ui/collection_book_panel.gd")
const Stamps = preload("res://game/ui/achievement_stamp_book.gd")
const Catalog = preload("res://game/core/game_catalog.gd")
const Paper = preload("res://game/ui/paper_ui.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func frames(count := 3) -> void:
	for i in count: await process_frame

func _run() -> void:
	if OS.get_environment("SNAPLAND_SAVE_PATH").is_empty():
		quit(1)
		return
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(800, 600) if OS.get_environment("ROWING_LARGE_TEXT") == "1" else Vector2i(1280, 720)
	Paper.set_text_scale(1.25 if OS.get_environment("ROWING_LARGE_TEXT") == "1" else 1.0)
	var progress = root.get_node("Progress")
	progress.reset_progress()
	var base: String = OS.get_environment("SNAPLAND_SAVE_PATH").get_base_dir().path_join("task4-collection-photos")
	DirAccess.make_dir_recursive_absolute(base)
	var thumb := Image.create(320, 180, false, Image.FORMAT_RGBA8)
	thumb.fill(Color("#397f92"))
	var original := Image.create(960, 540, false, Image.FORMAT_RGBA8)
	original.fill(Color("#65bbc4"))
	expect(thumb.save_png(base.path_join("thumb.png")) == OK and original.save_png(base.path_join("original.png")) == OK, "bounded real PNG fixtures save")
	expect(progress.complete_game("game-013", true), "fixture gets real harbor normal and devil identities")
	expect(progress.attach_game_photo_frames("game-013", [base.path_join("thumb.png")], true, [base.path_join("original.png")]), "real Progress attaches harbor thumbnail and original")
	var before: Dictionary = progress.photos.duplicate(true)
	var overlay := Control.new()
	overlay.theme = Paper.theme()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(overlay)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.name = "AdaptiveMenuPanel"
	panel.custom_minimum_size = Vector2(780, 540) if root.size.x == 800 else Vector2(1100, 640)
	center.add_child(panel)
	var album = Album.new()
	album.setup(progress, Catalog.definitions("harbor"), [], Callable())
	panel.add_child(album)
	await frames()
	expect(album._entries().size() == 18, "welcome retains twelve games and six other sources")
	var selector := album.find_child("AlbumRegionSelector", true, false) as OptionButton
	selector.select(1)
	selector.item_selected.emit(1)
	await frames()
	var entries: Array = album._entries()
	expect(entries.size() == 1 and entries[0].id == "photo-harbor-game-1" and entries[0].title == "浪間小艇", "region switch resolves harbor local one from global thirteen")
	if entries.size() != 1:
		overlay.free()
		quit(1)
		return
	expect(album._normal_button.text.contains("1 / 18") and album._devil_button.text.contains("1 / 12"), "source region quotas remain eighteen and twelve")
	expect(not album._time_button.visible and not album._empty_message.visible, "harbor has real game entries without welcome postcards")
	var tile := album.find_child("AlbumPhoto_photo-harbor-game-1", true, false) as Button
	expect(tile != null and tile.find_child("SavedPhotoFrame", true, false) != null and album._thumbnail_decode_count == 1, "harbor thumbnail uses bounded reader and cache")
	expect(album._saved_original_texture("photo-harbor-game-1").get_width() == 960, "harbor original retains saved size")
	tile.pressed.emit()
	await frames()
	var viewer := overlay.find_child("PhotoViewer", true, false)
	expect(viewer != null and viewer.find_child("PhotoViewerImage", true, false).texture.get_width() == 960, "normal harbor tile opens original viewer")
	if viewer != null:
		viewer.queue_free()
		await frames()
	album._set_category("devil")
	await frames()
	expect(album._entries().size() == 1 and album._entries()[0].id == "photo-harbor-devil-1", "harbor devil identity is local one")
	tile = album.find_child("AlbumPhoto_photo-harbor-devil-1", true, false) as Button
	tile.pressed.emit()
	await frames()
	viewer = overlay.find_child("PhotoViewer", true, false)
	expect(viewer != null and viewer.find_child("PhotoViewerImage", true, false).texture.get_height() == 540, "devil tile opens shared original")
	if viewer != null:
		viewer.queue_free()
		await frames()
	selector.select(0)
	selector.item_selected.emit(0)
	album._set_category("normal")
	expect(album._entries().size() == 18 and album._entries()[0].id == "photo-welcome-game-1", "return to welcome restores exact sources")
	album._set_category("time")
	selector.select(1)
	selector.item_selected.emit(1)
	expect(album._category == "normal" and album._entries().size() == 1, "switching from welcome time cannot leak postcards into harbor")
	expect(progress.photos == before, "album browsing changes no collection records")
	var capture := OS.get_environment("HARBOR_COLLECTION_CAPTURE")
	if not capture.is_empty() and DisplayServer.get_name() != "headless":
		await frames()
		await RenderingServer.frame_post_draw
		expect(root.get_texture().get_image().save_png(capture) == OK, "native regional album saved")
	progress.photos["photo-harbor-game-1"] = {"game_id": "game-013"}
	album._game_photo_texture_cache.clear()
	album._refresh_book()
	tile = album.find_child("AlbumPhoto_photo-harbor-game-1", true, false) as Button
	tile.pressed.emit()
	expect(overlay.find_child("PhotoViewer", true, false) == null and album._photo_details.text.contains("先留在本子裡"), "missing harbor images retain card with safe explanation")
	album.queue_free()
	await frames()
	progress.achievements.erase("ACH_GAME_013")
	progress.achievements["ACH_GAME_001"] = true
	var stamps = Stamps.new()
	stamps.setup(progress, Catalog.definitions("harbor"))
	panel.add_child(stamps)
	await frames()
	var stamp := stamps.find_child("AchievementStamp_ACH_GAME_013", true, false)
	expect(stamp != null and stamps.find_child("AchievementStamp_ACH_GAME_001", true, false) == null, "harbor row never guesses achievement one from local position")
	expect(stamp != null and not stamp.find_child("StampMark_*", true, false).unlocked, "welcome achievement cannot unlock harbor stamp")
	expect(stamps._summary_title.text.contains("碼頭") and stamps._summary_title.text.contains("1 枚"), "inferred harbor stamp title matches catalog")
	stamps.queue_free()
	await frames()
	progress.achievements["ACH_GAME_013"] = true
	stamps = Stamps.new()
	stamps.setup(progress, Catalog.definitions(), "harbor")
	panel.add_child(stamps)
	await frames()
	stamp = stamps.find_child("AchievementStamp_ACH_GAME_013", true, false)
	expect(stamp != null and stamp.find_child("StampMark_*", true, false).unlocked, "explicit harbor scope resolves global thirteen and unlocked state")
	expect(stamps._photo_count("photo-welcome-game-%d", 12) == 0, "harbor card never advances welcome milestone numerator")
	var caption := stamp.find_child("StampCaption", true, false) as Label
	expect(caption.text == "浪間小艇" and Rect2(Vector2.ZERO, Vector2(root.size)).encloses(caption.get_global_rect()), "harbor stamp caption fits current native layout")
	if not capture.is_empty() and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		expect(root.get_texture().get_image().save_png(capture.get_basename() + "-stamps.png") == OK, "native harbor stamp page saved")
	overlay.queue_free()
	await frames()
	print("Harbor collection: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
