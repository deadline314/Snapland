extends Node

var failures: Array[String] = []
var _valid_image_path := ""

func _ready() -> void:
	if OS.get_environment("SNAPLAND_SAVE_PATH").is_empty():
		push_error("Set SNAPLAND_SAVE_PATH to an isolated profile before thumbnail tests.")
		get_tree().quit(1)
		return
	call_deferred("_run")

func _run() -> void:
	var progress := get_tree().root.get_node_or_null("Progress")
	_check(progress != null, "Progress autoload exists")
	if progress == null:
		_finish()
		return
	_check(progress.has_method("attach_welcome_game_photo_frames"), "Progress exposes the shared game-photo attachment path")
	_check(progress.has_method("_backfill_legacy_devil_photo_frames"), "Progress exposes the legacy thumbnail migration")
	if not progress.has_method("attach_welcome_game_photo_frames") or not progress.has_method("_backfill_legacy_devil_photo_frames"):
		_finish()
		return
	_valid_image_path = Progress._save_path().get_base_dir().path_join("photos/main13-thumbnail-source.png")
	_check(_write_photo(_valid_image_path), "create one actual-dimension gameplay photo")
	var fixture_frames: Array[String] = [_valid_image_path]
	Progress.reset_progress()
	var main_script: Script = load("res://game/main.gd")
	var main_instance: Node = main_script.new()
	_check(not main_instance._sync_finished_photo_thumbnails({"game_id": "game-001", "success": false, "devil": true}, fixture_frames), "failed game result cannot write thumbnail references")
	_check(not main_instance._sync_finished_photo_thumbnails({"game_id": "game-001", "success": true, "practice": true, "devil": true}, fixture_frames), "private practice cannot write thumbnail references")
	_check(not Progress.photos.has("photo-welcome-game-1") and not Progress.photos.has("photo-welcome-devil-1"), "failed and practice results leave both collections unchanged")
	Progress.complete_game("game-001", true)
	_check(main_instance._sync_finished_photo_thumbnails({"game_id": "game-001", "success": true, "practice": false, "devil": true}, fixture_frames), "successful ordinary/devil result attaches saved photo paths")
	var ordinary_id := "photo-welcome-game-1"
	var devil_id := "photo-welcome-devil-1"
	Progress._reset_memory()
	Progress.load_progress()
	_check(Progress.photos.get(ordinary_id, {}).get("frames", []) == [_valid_image_path], "ordinary record points to saved gameplay frame")
	_check(Progress.photos.get(devil_id, {}).get("frames", []) == Progress.photos.get(ordinary_id, {}).get("frames", []), "devil and ordinary records share the same path list")
	_check(Progress.normal_count() == 1 and Progress.devil_count("welcome") == 1, "thumbnail linkage does not duplicate either collection")
	_check(_count_photo_files() == 1, "one photo file serves both collected cards")
	Progress.complete_game("game-001", true)
	_check(main_instance._sync_finished_photo_thumbnails({"game_id": "game-001", "success": true, "practice": false, "devil": true}, fixture_frames), "replay can refresh the already-collected photo metadata")
	_check(Progress.normal_count() == 1 and Progress.devil_count("welcome") == 1, "replay remains idempotent for collection counts")
	_check(_count_photo_files() == 1, "replay does not create a duplicate photo file")
	_check(Progress.attach_welcome_game_photo_frames("game-001", ["missing-replay-frame.png"], true), "unreadable replay frames fall back to the existing readable screenshot")
	_check(Progress.photos.get(devil_id, {}).get("frames", []) == [_valid_image_path], "unreadable replay does not replace the existing shared screenshot")
	main_instance.free()

	_check(_write_save_with_legacy_photo([_valid_image_path]), "write a legacy save with ordinary screenshot and collected devil")
	Progress._reset_memory()
	Progress.load_progress()
	_check(Progress.photos.get(devil_id, {}).get("frames", []) == [_valid_image_path], "legacy collected devil is backfilled from the valid ordinary screenshot")
	_check(Progress.photos.has(devil_id) and Progress.normal_count() == 1 and Progress.devil_count("welcome") == 1, "legacy backfill retains existing collection IDs and counts")
	var saved_migration := _read_save()
	_check(saved_migration.get("photos", {}).get(devil_id, {}).get("frames", []) == [_valid_image_path], "legacy backfill is persisted to the save file")
	var persisted_before_reload := FileAccess.get_file_as_string(Progress._save_path())
	Progress._reset_memory()
	Progress.load_progress()
	_check(FileAccess.get_file_as_string(Progress._save_path()) == persisted_before_reload, "already-migrated save reload does not rewrite unchanged metadata")
	_check(Progress.normal_count() == 1 and Progress.devil_count("welcome") == 1, "migration and reload never grant a collection card")

	for number in range(1, 13):
		Progress.photos["photo-welcome-game-%d" % number] = {"frames": [_valid_image_path]}
	var collection_panel: Variant = load("res://game/ui/collection_book_panel.gd").new()
	collection_panel.setup(Progress, [], [], Callable(self, "_load_validated_texture"))
	var load_started := Time.get_ticks_usec()
	for number in range(1, 13):
		_check(collection_panel._saved_texture("photo-welcome-game-%d" % number) is Texture2D, "shared path loads for game card %d" % number)
	var shared_path_load_ms := float(Time.get_ticks_usec() - load_started) / 1000.0
	_check(collection_panel._thumbnail_decode_count == 1, "12 collected cards sharing a screenshot decode that path only once per book opening")
	_check(shared_path_load_ms < 250.0, "12-card shared-path image loading stays within the CPU budget (%.2f ms)" % shared_path_load_ms)
	print("MAIN13_SHARED_PATH_12_CARDS_MS=%.2f DECODE_COUNT=%d" % [shared_path_load_ms, collection_panel._thumbnail_decode_count])
	collection_panel.free()
	_check(_write_photo(_valid_image_path, 320, 180, Color(0.82, 0.18, 0.12)), "replace source image at the same path between album openings")
	var reopened_panel: Variant = load("res://game/ui/collection_book_panel.gd").new()
	reopened_panel.setup(Progress, [], [], Callable(self, "_load_validated_texture"))
	var refreshed_texture: Texture2D = reopened_panel._saved_texture("photo-welcome-game-1")
	var refreshed_pixel := refreshed_texture.get_image().get_pixel(0, 0) if refreshed_texture is Texture2D else Color.BLACK
	_check(refreshed_texture is Texture2D and absf(refreshed_pixel.r - 0.82) < 0.01 and absf(refreshed_pixel.g - 0.18) < 0.01, "new album opening reads changed content at a previously used path")
	_check(reopened_panel._thumbnail_decode_count == 1, "a new album opening gets its own one-decode cache")
	reopened_panel.free()

	var bounded_paths: Array[String] = []
	for frame_index in range(4):
		var frame_path := Progress._save_path().get_base_dir().path_join("photos/bounded-frame-%d.png" % frame_index)
		_check(_write_photo(frame_path), "create bounded frame %d" % frame_index)
		bounded_paths.append(frame_path)
	var frame_cache: Dictionary = {}
	var capped_frames: Array[String] = Progress._validated_game_photo_frames(ordinary_id, bounded_paths, frame_cache)
	_check(capped_frames.size() == 3 and frame_cache.size() == 3, "only three distinct valid screenshot frames are retained or decoded")
	Progress.photos[ordinary_id]["frames"] = capped_frames
	var three_frame_panel: Variant = load("res://game/ui/collection_book_panel.gd").new()
	three_frame_panel.setup(Progress, [], [], Callable(self, "_load_validated_texture"))
	_check(three_frame_panel._saved_texture(ordinary_id) is Texture2D and Progress.photos[ordinary_id]["frames"].size() == 3, "collection book still reads a normal three-frame record")
	three_frame_panel.free()
	var many_duplicate_paths: Array[String] = []
	for _index in range(100000):
		many_duplicate_paths.append(_valid_image_path)
	var duplicate_cache: Dictionary = {}
	var deduplicated: Array[String] = Progress._validated_game_photo_frames(ordinary_id, many_duplicate_paths, duplicate_cache)
	_check(deduplicated == [_valid_image_path] and duplicate_cache.size() == 1, "repeated paths are decoded once and a huge list is bounded")
	var overlong_ui_paths: Array[String] = []
	for index in range(12):
		overlong_ui_paths.append(Progress._save_path().get_base_dir().path_join("photos/ui-missing-%d.png" % index))
	overlong_ui_paths.append(_valid_image_path)
	Progress.photos[ordinary_id]["frames"] = overlong_ui_paths
	var bounded_ui_panel: Variant = load("res://game/ui/collection_book_panel.gd").new()
	bounded_ui_panel.setup(Progress, [], [], Callable(self, "_load_validated_texture"))
	_check(bounded_ui_panel._saved_texture(ordinary_id) == null, "collection book does not read a valid path after twelve invalid candidates")
	_check(bounded_ui_panel._thumbnail_decode_count == 12, "collection book checks at most twelve candidate paths")
	bounded_ui_panel.free()

	Progress._reset_memory()
	Progress.load_progress()

	_check(_write_save_with_legacy_photo([Progress._save_path().get_base_dir().path_join("photos/missing-main13-photo.png")]), "write missing-source legacy save")
	Progress._reset_memory()
	Progress.load_progress()
	_check(Progress.photos.has(devil_id), "missing source does not remove collected devil")
	_check(not Progress.photos.get(devil_id, {}).has("frames"), "missing source remains on safe unreadable-thumbnail fallback")
	_check(Progress.normal_count() == 1 and Progress.devil_count("welcome") == 1, "missing source leaves collection counts intact")

	_check(_write_save_with_legacy_photo("not-an-array"), "write malformed legacy frame field")
	Progress._reset_memory()
	Progress.load_progress()
	_check(Progress.photos.has(devil_id), "malformed screenshot metadata does not remove collected devil")
	_check(not Progress.photos.get(devil_id, {}).has("frames"), "malformed screenshot metadata is not copied to devil")
	_check(_write_save_with_legacy_photo([17]), "write malformed screenshot path value")
	Progress._reset_memory()
	Progress.load_progress()
	_check(Progress.photos.has(devil_id), "invalid screenshot path value does not remove collected devil")
	_check(not Progress.photos.get(devil_id, {}).has("frames"), "invalid screenshot path value is not copied to devil")

	var broken_path := Progress._save_path().get_base_dir().path_join("photos/corrupt-main13-photo.png")
	var broken_file := FileAccess.open(broken_path, FileAccess.WRITE)
	_check(broken_file != null, "create corrupt image fixture")
	if broken_file != null:
		broken_file.store_string("not a PNG")
		broken_file.close()
	_check(_write_save_with_legacy_photo([broken_path]), "write corrupt-image legacy save")
	Progress._reset_memory()
	Progress.load_progress()
	_check(Progress.photos.has(devil_id), "corrupt screenshot does not remove collected devil")
	_check(not Progress.photos.get(devil_id, {}).has("frames"), "corrupt screenshot is not copied to devil")
	var corrupt_panel: Variant = load("res://game/ui/collection_book_panel.gd").new()
	corrupt_panel.setup(Progress, [], [], Callable(self, "_load_validated_texture"))
	_check(corrupt_panel._saved_texture(ordinary_id) == null, "collection book keeps its fallback for corrupt ordinary screenshot")
	corrupt_panel.free()

	var broken_zlib_path := Progress._save_path().get_base_dir().path_join("photos/crc-valid-broken-zlib.png")
	# This fixed PNG has valid CRCs for every chunk; only the IDAT zlib stream is invalid.
	var broken_zlib_bytes := Marshalls.base64_to_raw("iVBORw0KGgoAAAANSUhEUgAAAUAAAAC0CAYAAADl5PURAAAAEklEQVRicm9rZW4temxpYi1zdHJlYW2Us/gVAAAAAElFTkSuQmCC")
	var broken_zlib_file := FileAccess.open(broken_zlib_path, FileAccess.WRITE)
	_check(broken_zlib_file != null and broken_zlib_bytes.size() == 75, "prepare CRC-valid PNG with a broken IDAT zlib stream")
	if broken_zlib_file != null:
		broken_zlib_file.store_buffer(broken_zlib_bytes)
		broken_zlib_file.close()
	var broken_decoder_proof: Dictionary = await _verify_broken_zlib_in_child(broken_zlib_path)
	_check(bool(broken_decoder_proof.get("rejected", false)), "Godot image decoder rejects CRC-valid broken-zlib image content")
	_check(int(broken_decoder_proof.get("decoder_calls", 0)) == 1, "broken zlib passes the dimensions preflight and is rejected by the native decoder")
	_check(bool(broken_decoder_proof.get("logged", false)), "complete isolated negative child output is saved as negative-proof.log")

	var huge_header_path := Progress._save_path().get_base_dir().path_join("photos/crc-valid-huge-ihdr.png")
	# Each PNG chunk CRC is valid; the IHDR claims a 2,147,483,647 × 2,147,483,647 image.
	var huge_header_bytes := Marshalls.base64_to_raw("iVBORw0KGgoAAAANSUhEUn////9/////CAYAAAAUyQtmAAAAEElEQVRub3QtZGVjb2RlZC1odWdlLd8q9AAAAABJRU5ErkJggg==")
	_check(huge_header_bytes.size() == 73 and _write_bytes(huge_header_path, huge_header_bytes), "write CRC-valid oversized-IHDR image fixture")
	var huge_header_cache: Dictionary = {}
	var decoder_calls_before_huge: int = Progress._game_photo_decoder_invocations
	_check(Progress._read_game_photo_image(ordinary_id, huge_header_path, huge_header_cache) == null, "oversized IHDR is rejected before image decoding")
	_check(Progress._game_photo_decoder_invocations == decoder_calls_before_huge, "CRC-valid huge IHDR never reaches the native decoder")

	var wrong_size_path := Progress._save_path().get_base_dir().path_join("photos/wrong-size-main13-photo.png")
	_check(_write_photo(wrong_size_path, 160, 90), "create incorrectly sized image fixture")
	_check(_write_save_with_legacy_photo([wrong_size_path]), "write wrong-size legacy save")
	Progress._reset_memory()
	Progress.load_progress()
	_check(Progress.photos.has(devil_id), "wrong-size screenshot does not remove collected devil")
	_check(not Progress.photos.get(devil_id, {}).has("frames"), "wrong-size screenshot is not copied to devil")

	_check(_write_devil_only_save(), "write legacy save with no ordinary photo record")
	Progress._reset_memory()
	Progress.load_progress()
	_check(Progress.photos.has(devil_id), "devil remains collected when the ordinary photo record is absent")
	_check(not Progress.photos.get(devil_id, {}).has("frames"), "absent ordinary record leaves the devil on its safe fallback")
	_finish()

func _write_bytes(path: String, bytes: PackedByteArray) -> bool:
	var mkdir_error := DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if mkdir_error != OK and mkdir_error != ERR_ALREADY_EXISTS:
		return false
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_buffer(bytes)
	file.close()
	return true

func _verify_broken_zlib_in_child(image_path: String) -> Dictionary:
	var proof_log := Progress._save_path().get_base_dir().path_join("negative-proof.log")
	var child_save_path := Progress._save_path().get_base_dir().path_join("decoder-child/profile/progress.json")
	var child_output: Array = []
	var arguments := [
		"--headless", "--path", ProjectSettings.globalize_path("res://"),
		"--audio-driver", "Dummy", "--rendering-method", "gl_compatibility",
		"res://game/tests/thumbnail_decoder_probe.tscn", "--", image_path
	]
	print("NEGATIVE TEST: CRC-valid broken-zlib PNG is expected to reach and fail the native image decoder; subprocess output is isolated.")
	var parent_save_path := OS.get_environment("SNAPLAND_SAVE_PATH")
	OS.set_environment("SNAPLAND_SAVE_PATH", child_save_path)
	var exit_code := OS.execute(OS.get_executable_path(), arguments, child_output, true, false)
	OS.set_environment("SNAPLAND_SAVE_PATH", parent_save_path)
	var complete_output := "\n".join(PackedStringArray(child_output))
	var log_file := FileAccess.open(proof_log, FileAccess.WRITE)
	var saved_log := log_file != null
	if log_file != null:
		log_file.store_string(complete_output)
		log_file.close()
	var invoked_marker := "NEGATIVE_PROOF: decoder_invocations=1"
	var rejected_marker := "NEGATIVE_PROOF: CRC-valid broken zlib was rejected"
	_check(saved_log, "write complete child decoder output to the isolated negative-proof.log")
	_check(exit_code == 0, "negative decoder child exits successfully after proving native rejection (exit=%d)" % exit_code)
	_check(complete_output.contains(invoked_marker) and complete_output.contains(rejected_marker), "negative decoder child records invocation and rejection in proof markers")
	return {
		"rejected": exit_code == 0 and complete_output.contains(rejected_marker),
		"decoder_calls": 1 if exit_code == 0 and complete_output.contains(invoked_marker) else 0,
		"logged": saved_log and FileAccess.file_exists(proof_log),
	}

func _write_photo(path: String, width: int = 320, height: int = 180, color: Color = Color(0.2, 0.5, 0.8, 1.0)) -> bool:
	var mkdir_error := DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if mkdir_error != OK and mkdir_error != ERR_ALREADY_EXISTS:
		return false
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return image.save_png(path) == OK

func _read_save() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(Progress._save_path()))
	return parsed if parsed is Dictionary else {}

func _write_save_with_legacy_photo(frames: Variant) -> bool:
	var payload := {
		"version": Progress.SAVE_VERSION,
		"photos": {
			"photo-welcome-game-1": {"game_id": "game-001", "frames": frames},
			"photo-welcome-devil-1": {"game_id": "game-001", "devil": true},
		}
	}
	var file := FileAccess.open(Progress._save_path(), FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(payload))
	file.close()
	return true

func _write_devil_only_save() -> bool:
	var payload := {"version": Progress.SAVE_VERSION, "photos": {"photo-welcome-devil-1": {"game_id": "game-001", "devil": true}}}
	var file := FileAccess.open(Progress._save_path(), FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(payload))
	file.close()
	return true

func _count_photo_files() -> int:
	var directory := DirAccess.open(Progress._save_path().get_base_dir().path_join("photos"))
	if directory == null:
		return 0
	var count := 0
	directory.list_dir_begin()
	var file_name := directory.get_next()
	while not file_name.is_empty():
		if not directory.current_is_dir() and file_name.ends_with(".png"):
			count += 1
		file_name = directory.get_next()
	directory.list_dir_end()
	return count

func _load_validated_texture(path: String) -> Texture2D:
	var image := Image.load_from_file(path)
	if image == null or image.is_empty():
		return null
	return ImageTexture.create_from_image(image)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _finish() -> void:
	for failure in failures:
		push_error("FAIL: " + failure)
	if failures.is_empty():
		print("PASS: MAIN-13 shared photo paths, replay idempotence, legacy backfill, malformed/missing fallback")
		get_tree().quit(0)
	else:
		get_tree().quit(1)
