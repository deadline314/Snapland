extends Node

signal changed
signal achievement_unlocked(id: String)

const SAVE_FILE := "user://progress.json"
const SAVE_VERSION := 1
const MAX_COINS := 1000000
const MAX_GAME_PHOTO_FRAMES := 3
const MAX_GAME_PHOTO_FRAME_CANDIDATES := 12
const MAX_GAME_PHOTO_FILE_BYTES := 16 * 1024 * 1024
const MAX_GAME_PHOTO_ORIGINAL_PIXELS := 4 * 1024 * 1024
const WardrobeCatalog = preload("res://game/core/wardrobe_catalog.gd")
const TimeOfDay = preload("res://game/core/time_of_day.gd")
const TestSaveGuard = preload("res://game/core/test_save_guard.gd")
const DEFAULT_APPEARANCE := {
	"skin": "warm", "species": "human", "gender": "neutral",
	"hair": "windswept", "hair_color": "ink", "face": "curious",
}
const DEFAULT_EQUIPPED := {"outfit": "outfit-tide", "hat": "hat-none"}
const DEFAULT_SETTINGS := {
	"master_volume": 0.7,
	"music_volume": 0.6,
	"sfx_volume": 0.8,
	"reduced_motion": false,
	"text_speed": 1.0,
	"assist": false,
	"fullscreen": false,
	"ui_scale": 1.0,
	"time_phase": TimeOfDay.DEFAULT_PHASE,
}
const WELCOME_GAME_IDS := [
	"game-001", "game-002", "game-003", "game-004", "game-005", "game-006",
	"game-007", "game-008", "game-009", "game-010", "game-011", "game-012",
]
const ZONES := ["welcome", "harbor", "candy", "nightmarket", "circus", "toy", "garden", "hotel", "sky", "cinema"]

var photos: Dictionary = {}
var achievements: Dictionary = {}
var quests: Dictionary = {}
var settings: Dictionary = DEFAULT_SETTINGS.duplicate(true)
var visited: Dictionary = {}
var intro_seen := false
var platform_pending_achievements: Array[String] = []
var appearance: Dictionary = DEFAULT_APPEARANCE.duplicate(true)
var equipped: Dictionary = DEFAULT_EQUIPPED.duplicate(true)
var owned_clothes: Array[String] = ["outfit-tide"]
var coins := 120
var wardrobe_rewarded_games: Array[String] = []
var tutorial_seen_games: Array[String] = []
var _extra_fields: Dictionary = {}
var _loading := false
var _suppress_changed_save := false
var _game_photo_decoder_invocations := 0
var _game_photo_original_decoder_invocations := 0

func _ready() -> void:
	if not _guard_test_save_path("startup"):
		return
	changed.connect(_on_changed)
	load_progress()

func grant_photo(source_id: String, metadata: Dictionary = {}) -> bool:
	if source_id.is_empty():
		return false
	if photos.has(source_id):
		return false
	photos[source_id] = metadata.duplicate(true)
	changed.emit()
	return true

func has_seen_tutorial(game_id: String) -> bool:
	return WELCOME_GAME_IDS.has(game_id) and tutorial_seen_games.has(game_id)

func mark_game_tutorial_seen(game_id: String) -> bool:
	if not WELCOME_GAME_IDS.has(game_id):
		return false
	if tutorial_seen_games.has(game_id):
		return true
	tutorial_seen_games.append(game_id)
	if not save_progress():
		tutorial_seen_games.erase(game_id)
		return false
	return true

func set_time_phase(value: String) -> bool:
	if not TimeOfDay.phase_ids().has(value):
		return false
	if settings.get("time_phase", TimeOfDay.DEFAULT_PHASE) == value:
		return true
	var previous := str(settings.get("time_phase", TimeOfDay.DEFAULT_PHASE))
	settings["time_phase"] = value
	if not save_progress():
		settings["time_phase"] = previous
		return false
	changed.emit()
	return true

func collect_time_postcard(value: String, frame_path: String, original_path: String = "") -> bool:
	if not TimeOfDay.phase_ids().has(value):
		return false
	if settings.get("time_phase", TimeOfDay.DEFAULT_PHASE) != value or not FileAccess.file_exists(frame_path):
		return false
	var frame := Image.load_from_file(frame_path)
	if frame == null or frame.get_width() != 320 or frame.get_height() != 180:
		return false
	var valid_original := ""
	if not original_path.is_empty():
		if _read_game_photo_original_image(TimeOfDay.postcard_id(value), original_path) == null:
			return false
		valid_original = original_path
	var source_id := TimeOfDay.postcard_id(value)
	if photos.has(source_id):
		return false
	var previous_coins := coins
	coins = mini(clampi(coins, 0, MAX_COINS) + 20, MAX_COINS)
	photos[source_id] = {"time_phase": value, "frames": [frame_path]}
	if not valid_original.is_empty():
		photos[source_id]["original_frames"] = [valid_original]
	var completes_set := true
	for postcard in TimeOfDay.all_postcard_ids():
		if not photos.has(postcard):
			completes_set = false
			break
	var newly_unlocked := completes_set and not achievements.has(TimeOfDay.ACHIEVEMENT_ALL_POSTCARDS)
	if newly_unlocked:
		achievements[TimeOfDay.ACHIEVEMENT_ALL_POSTCARDS] = true
	if not save_progress():
		coins = previous_coins
		photos.erase(source_id)
		if newly_unlocked:
			achievements.erase(TimeOfDay.ACHIEVEMENT_ALL_POSTCARDS)
		return false
	if newly_unlocked:
		achievement_unlocked.emit(TimeOfDay.ACHIEVEMENT_ALL_POSTCARDS)
	changed.emit()
	return true

func complete_game(game_id: String, devil: bool, assisted: bool = false) -> void:
	var game_number := _welcome_game_number(game_id)
	if game_number == 0:
		return
	var completed_photo_id := "photo-welcome-game-%d" % game_number
	if not wardrobe_rewarded_games.has(game_id):
		if not photos.has(completed_photo_id):
			coins = mini(clampi(coins, 0, MAX_COINS) + 40, MAX_COINS)
		wardrobe_rewarded_games.append(game_id)
	grant_photo("photo-welcome-game-%d" % game_number, {"game_id": game_id, "assisted": assisted, "devil": false})
	if devil:
		grant_photo("photo-welcome-devil-%d" % game_number, {"game_id": game_id, "assisted": assisted, "devil": true})
	_unlock("ACH_GAME_%03d" % game_number)
	if _has_complete_game_set("welcome", false):
		_unlock("ACH_WELCOME_CLEAR")
	if _has_complete_game_set("welcome", true):
		_unlock("ACH_WELCOME_DEVILS")
	var all_devils := true
	for zone in ZONES:
		if devil_count(zone) < 12:
			all_devils = false
			break
	if all_devils:
		_unlock("ACH_ALL_DEVILS")
	changed.emit()

## Attach saved gameplay captures to cards already granted by complete_game.
## Ordinary and devil records share paths; this method never grants a card.
func attach_welcome_game_photo_frames(game_id: String, saved_frames: Array, include_devil: bool, saved_original_frames: Array = []) -> bool:
	var game_number := _welcome_game_number(game_id)
	if game_number == 0:
		push_warning("Cannot attach gameplay thumbnails for unknown game '%s'." % game_id)
		return false
	var ordinary_id := "photo-welcome-game-%d" % game_number
	if not photos.has(ordinary_id) or not photos[ordinary_id] is Dictionary:
		push_warning("Cannot attach gameplay thumbnails: collected ordinary photo '%s' is missing." % ordinary_id)
		return false
	var image_cache: Dictionary = {}
	var valid_frames := _validated_game_photo_frames(ordinary_id, saved_frames, image_cache)
	if valid_frames.is_empty():
		var ordinary_photo: Dictionary = photos[ordinary_id]
		valid_frames = _validated_game_photo_frames(ordinary_id, ordinary_photo.get("frames", []), image_cache)
	if valid_frames.is_empty():
		push_warning("No readable 320x180 gameplay thumbnails are available for collected photo '%s'." % ordinary_id)
		return false
	var valid_originals := _validated_game_photo_original_frames(ordinary_id, saved_original_frames)
	var previous_ordinary: Variant = photos[ordinary_id].get("frames", null)
	var had_previous_ordinary: bool = photos[ordinary_id].has("frames")
	var devil_id := "photo-welcome-devil-%d" % game_number
	var update_devil := include_devil and photos.has(devil_id) and photos[devil_id] is Dictionary
	var previous_devil: Variant = photos[devil_id].get("frames", null) if update_devil else null
	var had_previous_devil: bool = update_devil and photos[devil_id].has("frames")
	var previous_ordinary_original: Variant = photos[ordinary_id].get("original_frames", null)
	var had_previous_ordinary_original: bool = photos[ordinary_id].has("original_frames")
	var previous_devil_original: Variant = photos[devil_id].get("original_frames", null) if update_devil else null
	var had_previous_devil_original: bool = update_devil and photos[devil_id].has("original_frames")
	photos[ordinary_id]["frames"] = valid_frames.duplicate()
	if update_devil:
		photos[devil_id]["frames"] = valid_frames.duplicate()
	if not valid_originals.is_empty():
		photos[ordinary_id]["original_frames"] = valid_originals.duplicate()
		if update_devil:
			photos[devil_id]["original_frames"] = valid_originals.duplicate()
	if not save_progress():
		if had_previous_ordinary:
			photos[ordinary_id]["frames"] = previous_ordinary
		else:
			photos[ordinary_id].erase("frames")
		if update_devil:
			if had_previous_devil:
				photos[devil_id]["frames"] = previous_devil
			else:
				photos[devil_id].erase("frames")
		if had_previous_ordinary_original:
			photos[ordinary_id]["original_frames"] = previous_ordinary_original
		else:
			photos[ordinary_id].erase("original_frames")
		if update_devil:
			if had_previous_devil_original:
				photos[devil_id]["original_frames"] = previous_devil_original
			else:
				photos[devil_id].erase("original_frames")
		push_error("Could not save gameplay thumbnail paths for '%s'." % ordinary_id)
		return false
	return true

## Add legacy devil-card thumbnails only when their ordinary card has a readable saved image.
## The migration updates existing metadata; it never creates or rewards a card.
func _backfill_legacy_devil_photo_frames() -> bool:
	var changed_any := false
	var image_cache: Dictionary = {}
	for game_number in range(1, 13):
		var devil_id := "photo-welcome-devil-%d" % game_number
		if not photos.has(devil_id) or not photos[devil_id] is Dictionary:
			continue
		var devil_photo: Dictionary = photos[devil_id]
		var current_frames := _validated_game_photo_frames(devil_id, devil_photo.get("frames", []), image_cache)
		if not current_frames.is_empty():
			if devil_photo.get("frames", []) != current_frames:
				devil_photo["frames"] = current_frames
				changed_any = true
			if not devil_photo.has("original_frames"):
				var ordinary_with_originals: Variant = photos.get("photo-welcome-game-%d" % game_number, {})
				if ordinary_with_originals is Dictionary:
					var shared_originals := _validated_game_photo_original_frames(devil_id, ordinary_with_originals.get("original_frames", []))
					if not shared_originals.is_empty():
						devil_photo["original_frames"] = shared_originals.duplicate()
						changed_any = true
			continue
		var ordinary_id := "photo-welcome-game-%d" % game_number
		if not photos.has(ordinary_id) or not photos[ordinary_id] is Dictionary:
			if devil_photo.has("frames"):
				devil_photo.erase("frames")
				changed_any = true
			continue
		var ordinary_photo: Dictionary = photos[ordinary_id]
		var source_frames := _validated_game_photo_frames(ordinary_id, ordinary_photo.get("frames", []), image_cache)
		if source_frames.is_empty():
			if devil_photo.has("frames"):
				devil_photo.erase("frames")
				changed_any = true
			continue
		devil_photo["frames"] = source_frames.duplicate()
		var source_originals := _validated_game_photo_original_frames(ordinary_id, ordinary_photo.get("original_frames", []))
		if not source_originals.is_empty():
			devil_photo["original_frames"] = source_originals.duplicate()
		changed_any = true
	return changed_any

func _validated_game_photo_original_frames(photo_id: String, frame_value: Variant) -> Array[String]:
	var valid: Array[String] = []
	if typeof(frame_value) != TYPE_ARRAY:
		if frame_value != null:
			push_warning("Photo '%s' has invalid 'original_frames' data (expected an array)." % photo_id)
		return valid
	if frame_value.size() > MAX_GAME_PHOTO_FRAME_CANDIDATES:
		push_warning("Photo '%s' has more than %d original screenshot entries; remaining entries are not inspected." % [photo_id, MAX_GAME_PHOTO_FRAME_CANDIDATES])
	var seen_paths: Dictionary = {}
	for frame_index in range(mini(frame_value.size(), MAX_GAME_PHOTO_FRAME_CANDIDATES)):
		var candidate: Variant = frame_value[frame_index]
		if typeof(candidate) != TYPE_STRING or str(candidate).strip_edges().is_empty():
			push_warning("Photo '%s' has an invalid original screenshot path value at index %d." % [photo_id, frame_index])
			break
		var path := str(candidate)
		if seen_paths.has(path):
			push_warning("Photo '%s' repeats an original screenshot path; later entries are ignored." % photo_id)
			break
		seen_paths[path] = true
		if valid.size() >= MAX_GAME_PHOTO_FRAMES:
			break
		if _read_game_photo_original_image(photo_id, path) == null:
			break
		valid.append(path)
	return valid

func _read_game_photo_original_image(photo_id: String, path: String) -> Image:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("Photo '%s' original screenshot is missing or cannot be opened: '%s'." % [photo_id, path])
		return null
	var file_length := file.get_length()
	if file_length < 45 or file_length > MAX_GAME_PHOTO_FILE_BYTES:
		file.close()
		push_warning("Photo '%s' original screenshot has invalid size (%d bytes; allowed 45..%d)." % [photo_id, file_length, MAX_GAME_PHOTO_FILE_BYTES])
		return null
	var header := file.get_buffer(24)
	var signature := PackedByteArray([137, 80, 78, 71, 13, 10, 26, 10])
	if header.size() != 24 or header.slice(0, 8) != signature or header.slice(12, 16).get_string_from_ascii() != "IHDR" or _thumbnail_u32(header, 8) != 13:
		file.close()
		push_warning("Photo '%s' original screenshot has no standard PNG IHDR header." % photo_id)
		return null
	var width := _thumbnail_u32(header, 16)
	var height := _thumbnail_u32(header, 20)
	if width <= 0 or height <= 0 or width > MAX_GAME_PHOTO_ORIGINAL_PIXELS or height > MAX_GAME_PHOTO_ORIGINAL_PIXELS or width * height > MAX_GAME_PHOTO_ORIGINAL_PIXELS:
		file.close()
		push_warning("Photo '%s' original screenshot dimensions %dx%d exceed the 4-megapixel limit; decoder was not called." % [photo_id, width, height])
		return null
	file.seek(0)
	var png_bytes := file.get_buffer(file_length)
	file.close()
	if png_bytes.size() != file_length:
		push_warning("Photo '%s' original screenshot could not be read completely." % photo_id)
		return null
	var image := Image.new()
	_game_photo_original_decoder_invocations += 1
	var decode_error: Error = image.load_png_from_buffer(png_bytes)
	if decode_error != OK or image.is_empty() or image.get_width() != width or image.get_height() != height:
		push_warning("Photo '%s' original screenshot could not be decoded safely (%s)." % [photo_id, error_string(decode_error)])
		return null
	return image

func _validated_game_photo_frames(photo_id: String, frame_value: Variant, image_cache: Dictionary = {}) -> Array[String]:
	var valid: Array[String] = []
	if typeof(frame_value) != TYPE_ARRAY:
		if frame_value != null:
			push_warning("Photo '%s' has invalid 'frames' data (expected an array)." % photo_id)
		return valid
	if frame_value.size() > MAX_GAME_PHOTO_FRAME_CANDIDATES:
		push_warning("Photo '%s' has %d screenshot entries; only the first %d will be inspected." % [photo_id, frame_value.size(), MAX_GAME_PHOTO_FRAME_CANDIDATES])
	var inspected_count := mini(frame_value.size(), MAX_GAME_PHOTO_FRAME_CANDIDATES)
	var seen_paths: Dictionary = {}
	for frame_index in range(inspected_count):
		var candidate: Variant = frame_value[frame_index]
		if typeof(candidate) != TYPE_STRING or str(candidate).strip_edges().is_empty():
			push_warning("Photo '%s' has an invalid screenshot path value at index %d: %s." % [photo_id, frame_index, str(candidate)])
			continue
		var path := str(candidate)
		if seen_paths.has(path):
			push_warning("Photo '%s' repeats screenshot path at index %d; duplicate ignored: '%s'." % [photo_id, frame_index, path])
			continue
		seen_paths[path] = true
		if valid.size() >= MAX_GAME_PHOTO_FRAMES:
			push_warning("Photo '%s' has more paths after the %d-image limit; remaining entries are not inspected (next: '%s')." % [photo_id, MAX_GAME_PHOTO_FRAMES, path])
			break
		if not FileAccess.file_exists(path):
			push_warning("Photo '%s' screenshot is missing: '%s'." % [photo_id, path])
			continue
		if _read_game_photo_image(photo_id, path, image_cache) == null:
			continue
		valid.append(path)
	return valid

func _read_game_photo_image(photo_id: String, path: String, image_cache: Dictionary) -> Image:
	if image_cache.has(path):
		return image_cache[path] as Image
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("Photo '%s' screenshot cannot be opened: '%s'." % [photo_id, path])
		image_cache[path] = null
		return null
	var file_length := file.get_length()
	if file_length < 45 or file_length > MAX_GAME_PHOTO_FILE_BYTES:
		file.close()
		push_warning("Photo '%s' screenshot has invalid size (%d bytes; allowed 45..%d): '%s'." % [photo_id, file_length, MAX_GAME_PHOTO_FILE_BYTES, path])
		image_cache[path] = null
		return null
	var header := file.get_buffer(24)
	var signature := PackedByteArray([137, 80, 78, 71, 13, 10, 26, 10])
	if header.size() != 24 or header.slice(0, 8) != signature or header.slice(12, 16).get_string_from_ascii() != "IHDR" or _thumbnail_u32(header, 8) != 13:
		file.close()
		push_warning("Photo '%s' screenshot has no standard PNG IHDR header: '%s'." % [photo_id, path])
		image_cache[path] = null
		return null
	var width := _thumbnail_u32(header, 16)
	var height := _thumbnail_u32(header, 20)
	if width != 320 or height != 180:
		file.close()
		push_warning("Photo '%s' screenshot has unexpected IHDR dimensions %dx%d at '%s' (expected 320x180); decoder was not called." % [photo_id, width, height, path])
		image_cache[path] = null
		return null
	file.seek(0)
	var png_bytes := file.get_buffer(file_length)
	file.close()
	if png_bytes.size() != file_length:
		push_warning("Photo '%s' screenshot could not be read completely: '%s'." % [photo_id, path])
		image_cache[path] = null
		return null
	var image := Image.new()
	_game_photo_decoder_invocations += 1
	var decode_error: Error = image.load_png_from_buffer(png_bytes)
	if decode_error != OK or image.is_empty():
		push_warning("Photo '%s' screenshot could not be decoded (%s): '%s'." % [photo_id, error_string(decode_error), path])
		image_cache[path] = null
		return null
	if image.get_width() != 320 or image.get_height() != 180:
		push_warning("Photo '%s' decoded to unexpected dimensions %dx%d at '%s'." % [photo_id, image.get_width(), image.get_height(), path])
		image_cache[path] = null
		return null
	image_cache[path] = image
	return image

func _thumbnail_u32(bytes: PackedByteArray, offset: int) -> int:
	return (int(bytes[offset]) << 24) | (int(bytes[offset + 1]) << 16) | (int(bytes[offset + 2]) << 8) | int(bytes[offset + 3])

func set_appearance(key: String, value: String) -> bool:
	var options := WardrobeCatalog.options()
	if not options.has(key):
		return false
	for option: Dictionary in options[key]:
		if option.id == value:
			if appearance.get(key) == value:
				return true
			var previous_appearance := appearance.duplicate(true)
			appearance[key] = value
			if not _save_wardrobe_change():
				appearance = previous_appearance
				return false
			return true
	return false

func set_appearance_batch(values: Dictionary) -> bool:
	var options := WardrobeCatalog.options()
	var updated_appearance := appearance.duplicate(true)
	for key: Variant in values:
		if not options.has(key) or typeof(values[key]) != TYPE_STRING:
			return false
		var valid_value := false
		for option: Dictionary in options[key]:
			if option.id == values[key]:
				valid_value = true
				break
		if not valid_value:
			return false
		updated_appearance[str(key)] = values[key]
	if updated_appearance == appearance:
		return true
	var previous_appearance := appearance
	appearance = updated_appearance
	if not _save_wardrobe_change():
		appearance = previous_appearance
		return false
	return true

func buy_clothing(id: String) -> bool:
	var item := wardrobe_item(id)
	if item.is_empty() or id == "hat-none" or owned_clothes.has(id):
		return false
	var price := int(item.price)
	if coins < price:
		return false
	var previous_coins := coins
	var previous_owned := owned_clothes.duplicate()
	coins -= price
	owned_clothes.append(id)
	if not _save_wardrobe_change():
		coins = previous_coins
		owned_clothes = previous_owned
		return false
	return true

func equip_clothing(id: String) -> bool:
	var item := wardrobe_item(id)
	if item.is_empty() or (id != "hat-none" and not owned_clothes.has(id)):
		return false
	var slot: String = item.slot
	if not equipped.has(slot):
		return false
	if equipped[slot] == id:
		return true
	var previous_equipped := equipped.duplicate(true)
	equipped[slot] = id
	if not _save_wardrobe_change():
		equipped = previous_equipped
		return false
	return true

func _save_wardrobe_change() -> bool:
	if not save_progress():
		return false
	_suppress_changed_save = true
	changed.emit()
	_suppress_changed_save = false
	return true

func wardrobe_item(id: String) -> Dictionary:
	return WardrobeCatalog.item(id)

func wardrobe_items() -> Array:
	var items: Array = []
	for item: Dictionary in WardrobeCatalog.ITEMS:
		items.append(item.duplicate(true))
	return items

func appearance_options() -> Dictionary:
	return WardrobeCatalog.options()

func advance_quest(id: String, step: int) -> void:
	if id.is_empty() or step < 0:
		return
	quests[id] = maxi(int(quests.get(id, 0)), mini(step, 3))
	changed.emit()

func save_progress() -> bool:
	if not _guard_test_save_path("save"):
		return false
	var path := _save_path()
	var directory := path.get_base_dir()
	if not DirAccess.dir_exists_absolute(directory):
		var mkdir_error := DirAccess.make_dir_recursive_absolute(directory)
		if mkdir_error != OK:
			push_error("Cannot create progress directory '%s': %s" % [directory, error_string(mkdir_error)])
			return false
	var payload := _extra_fields.duplicate(true)
	payload.merge({
		"version": SAVE_VERSION,
		"photos": photos,
		"achievements": achievements,
		"quests": quests,
		"settings": settings,
		"visited": visited,
		"intro_seen": intro_seen,
		"platform_pending_achievements": platform_pending_achievements,
		"appearance": appearance,
		"equipped": equipped,
		"owned_clothes": owned_clothes,
		"coins": coins,
		"wardrobe_rewarded_games": wardrobe_rewarded_games,
		"tutorial_seen_games": tutorial_seen_games,
	}, true)
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write progress temporary file '%s': %s" % [temporary, error_string(FileAccess.get_open_error())])
		return false
	file.store_string(JSON.stringify(payload, "\t"))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		push_error("Cannot flush progress temporary file '%s': %s" % [temporary, error_string(write_error)])
		return false
	var backup := path + ".bak"
	if FileAccess.file_exists(backup):
		var remove_backup_error := DirAccess.remove_absolute(backup)
		if remove_backup_error != OK:
			push_error("Cannot replace progress backup '%s': %s" % [backup, error_string(remove_backup_error)])
			return false
	if FileAccess.file_exists(path):
		var backup_error := DirAccess.rename_absolute(path, backup)
		if backup_error != OK:
			push_error("Cannot preserve previous progress at '%s': %s" % [backup, error_string(backup_error)])
			return false
	var commit_error := DirAccess.rename_absolute(temporary, path)
	if commit_error != OK:
		if FileAccess.file_exists(backup):
			DirAccess.rename_absolute(backup, path)
		push_error("Cannot atomically replace progress file '%s': %s" % [path, error_string(commit_error)])
		return false
	return true

func load_progress() -> void:
	if not _guard_test_save_path("load"):
		return
	var path := _save_path()
	var parsed := _read_save(path)
	var backup := path + ".bak"
	if parsed.is_empty() and (FileAccess.file_exists(path) or FileAccess.file_exists(backup)):
		if FileAccess.file_exists(path):
			push_error("Invalid progress data at '%s'; attempting backup." % path)
		else:
			push_warning("Progress file '%s' is missing; attempting backup '%s'." % [path, backup])
		parsed = _read_save(backup)
		if not parsed.is_empty():
			push_warning("Recovered progress from backup '%s'." % backup)
	if parsed.is_empty():
		_reset_memory()
		return
	_apply_save(parsed)
	var migrated_frames := _backfill_legacy_devil_photo_frames()
	if migrated_frames and not save_progress():
		push_error("Could not persist legacy gameplay thumbnail migration to '%s'." % path)
	_suppress_changed_save = true
	changed.emit()
	_suppress_changed_save = false

func reset_progress() -> void:
	_reset_memory()
	changed.emit()

func set_setting(key: String, value: Variant) -> void:
	if not DEFAULT_SETTINGS.has(key):
		return
	var default_value: Variant = DEFAULT_SETTINGS[key]
	if typeof(default_value) == TYPE_BOOL:
		if typeof(value) != TYPE_BOOL:
			return
		settings[key] = value
	else:
		if typeof(value) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(value)):
			return
		if key.ends_with("_volume"):
			settings[key] = clampf(float(value), 0.0, 1.0)
		elif key == "ui_scale":
			settings[key] = clampf(float(value), 1.0, 1.25)
		else:
			settings[key] = clampf(float(value), 0.5, 2.0)
	_apply_setting(key)
	changed.emit()

func normal_count() -> int:
	var count := 0
	for source_id in photos:
		if _is_canonical_normal_photo(str(source_id)):
			count += 1
	return count

func normal_count_for_zone(zone: String) -> int:
	var count := 0
	for source_id in photos:
		if _is_canonical_normal_photo(str(source_id), zone):
			count += 1
	return count

func devil_count(zone: String = "welcome") -> int:
	if not ZONES.has(zone):
		return 0
	var count := 0
	for index in range(1, 13):
		if photos.has("photo-%s-devil-%d" % [zone, index]):
			count += 1
	return count

func _unlock(id: String) -> void:
	if achievements.has(id):
		return
	achievements[id] = true
	achievement_unlocked.emit(id)
	changed.emit()

func _welcome_game_number(game_id: String) -> int:
	var index := WELCOME_GAME_IDS.find(game_id)
	return index + 1 if index >= 0 else 0

func _is_rewardable_game_id(game_id: String) -> bool:
	if not game_id.begins_with("game-"):
		return false
	var number_text := game_id.trim_prefix("game-")
	if not number_text.is_valid_int():
		return false
	var number := int(number_text)
	return WELCOME_GAME_IDS.has(game_id) and game_id == "game-%03d" % number

func _has_complete_game_set(zone: String, devil: bool) -> bool:
	for index in range(1, 13):
		var card_id := "photo-%s-game-%d" % [zone, index]
		if devil:
			card_id = "photo-%s-devil-%d" % [zone, index]
		if not photos.has(card_id):
			return false
	return true

func _is_canonical_normal_photo(source_id: String, only_zone := "") -> bool:
	for zone in ZONES:
		if not only_zone.is_empty() and zone != only_zone:
			continue
		for index in range(1, 13):
			if source_id == "photo-%s-game-%d" % [zone, index]:
				return true
		if zone == "welcome":
			for index in range(1, 4):
				if source_id == "photo-welcome-explore-%d" % index:
					return true
			if source_id in ["photo-welcome-story-1", "photo-welcome-quest-1", "photo-welcome-quest-2"]:
				return true
	return false

func _save_path() -> String:
	var override_path := OS.get_environment("SNAPLAND_SAVE_PATH")
	return override_path if not override_path.is_empty() else ProjectSettings.globalize_path(SAVE_FILE)

func _guard_test_save_path(operation: String) -> bool:
	if not _is_test_or_review_launch():
		return true
	var override_path := OS.get_environment("SNAPLAND_SAVE_PATH")
	var error_message := TestSaveGuard.validate_save_path(override_path, OS.get_user_data_dir())
	if error_message.is_empty():
		return true
	push_error("Save isolation guard blocked %s: %s" % [operation, error_message])
	if operation == "startup":
		get_tree().quit(1)
	return false

func _is_test_or_review_launch() -> bool:
	var arguments := OS.get_cmdline_args()
	var user_arguments := OS.get_cmdline_user_args()
	arguments.append_array(user_arguments)
	return TestSaveGuard.is_test_launch(arguments)

func _read_save(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Cannot read progress file '%s': %s" % [path, error_string(FileAccess.get_open_error())])
		return {}
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	var parse_error := json.parse(text)
	if parse_error != OK or typeof(json.data) != TYPE_DICTIONARY:
		push_error("Corrupt progress file '%s' at line %d: %s" % [path, json.get_error_line(), json.get_error_message()])
		return {}
	return _validated_payload(json.data, path)

func _validated_payload(payload: Dictionary, path: String) -> Dictionary:
	var result := payload.duplicate(true)
	for key in ["photos", "achievements", "quests", "settings", "visited"]:
		if result.has(key) and typeof(result[key]) != TYPE_DICTIONARY:
			push_error("Invalid '%s' field in progress file '%s'; using defaults for that field." % [key, path])
			result.erase(key)
	if result.has("quests") and typeof(result["quests"]) == TYPE_DICTIONARY:
		var safe_quests: Dictionary = result["quests"]
		for quest_id: Variant in safe_quests.keys():
			if not _valid_quest_step(safe_quests[quest_id]):
				push_error("Invalid quest step for '%s' in progress file '%s'; using default." % [str(quest_id), path])
				safe_quests.erase(quest_id)
	if result.has("settings") and typeof(result["settings"]) == TYPE_DICTIONARY:
		var safe_settings: Dictionary = result["settings"]
		for key: Variant in DEFAULT_SETTINGS.keys():
			if not safe_settings.has(key):
				continue
			var value: Variant = safe_settings[key]
			var default_value: Variant = DEFAULT_SETTINGS[key]
			var valid := typeof(default_value) == TYPE_BOOL and typeof(value) == TYPE_BOOL
			if str(key) == "time_phase":
				valid = typeof(value) == TYPE_STRING and TimeOfDay.phase_ids().has(value)
			if typeof(default_value) in [TYPE_INT, TYPE_FLOAT]:
				valid = typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value))
				if valid:
					var low := 0.0 if str(key).ends_with("_volume") else 0.5
					var high := 1.0 if str(key).ends_with("_volume") else 2.0
					valid = float(value) >= low and float(value) <= high
			if not valid:
				if str(key) == "time_phase":
					push_warning("Invalid setting '%s' in progress file '%s'; using default." % [str(key), path])
				else:
					push_error("Invalid setting '%s' in progress file '%s'; using default." % [str(key), path])
				safe_settings.erase(key)
	if result.has("platform_pending_achievements") and typeof(result["platform_pending_achievements"]) != TYPE_ARRAY:
		push_error("Invalid 'platform_pending_achievements' field in progress file '%s'; using defaults." % path)
		result.erase("platform_pending_achievements")
	for key in ["intro_seen"]:
		if result.has(key) and typeof(result[key]) != TYPE_BOOL:
			push_error("Invalid '%s' field in progress file '%s'; using default." % [key, path])
			result.erase(key)
	if result.has("tutorial_seen_games") and typeof(result["tutorial_seen_games"]) != TYPE_ARRAY:
		push_warning("Invalid 'tutorial_seen_games' field in progress file '%s'; using defaults." % path)
		result.erase("tutorial_seen_games")
	elif result.has("tutorial_seen_games"):
		var safe_tutorial_seen: Array = result["tutorial_seen_games"]
		for game_id: Variant in safe_tutorial_seen.duplicate():
			if typeof(game_id) != TYPE_STRING or not WELCOME_GAME_IDS.has(str(game_id)):
				push_warning("Invalid seen tutorial ID '%s' in progress file '%s'; skipping." % [str(game_id), path])
				safe_tutorial_seen.erase(game_id)
	if result.has("appearance"):
		if typeof(result.appearance) != TYPE_DICTIONARY:
			push_warning("Invalid 'appearance' field in progress file '%s'; using wardrobe defaults." % path)
			result.erase("appearance")
		else:
			var safe_appearance: Dictionary = result.appearance
			var options := WardrobeCatalog.options()
			for key: Variant in safe_appearance.keys():
				var valid := false
				if options.has(key) and typeof(safe_appearance[key]) == TYPE_STRING:
					for option: Dictionary in options[key]:
						if option.id == safe_appearance[key]:
							valid = true
							break
				if not valid:
					push_warning("Invalid appearance option '%s' in progress file '%s'; using default." % [str(key), path])
					safe_appearance.erase(key)
	if result.has("equipped") and typeof(result.equipped) == TYPE_DICTIONARY:
		var safe_equipped: Dictionary = result.equipped
		for slot: Variant in safe_equipped.keys():
			if not DEFAULT_EQUIPPED.has(slot):
				push_warning("Invalid wardrobe slot '%s' in progress file '%s'; skipping." % [str(slot), path])
				safe_equipped.erase(slot)
	for key in ["equipped", "owned_clothes"]:
		if result.has(key) and typeof(result[key]) != (TYPE_DICTIONARY if key == "equipped" else TYPE_ARRAY):
			push_warning("Invalid '%s' field in progress file '%s'; using wardrobe defaults." % [key, path])
			result.erase(key)
	if result.has("coins"):
		var saved_coins: Variant = result.coins
		if typeof(saved_coins) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(saved_coins)) or float(saved_coins) < 0.0 or float(saved_coins) > MAX_COINS or floor(float(saved_coins)) != float(saved_coins):
			push_warning("Invalid 'coins' field in progress file '%s'; using default." % path)
			result.erase("coins")
	if result.has("wardrobe_rewarded_games") and typeof(result.wardrobe_rewarded_games) != TYPE_ARRAY:
		push_warning("Invalid 'wardrobe_rewarded_games' field in progress file '%s'; using defaults." % path)
		result.erase("wardrobe_rewarded_games")
	elif result.has("wardrobe_rewarded_games"):
		var safe_rewarded_games: Array = result.wardrobe_rewarded_games
		for game_id: Variant in safe_rewarded_games.duplicate():
			if typeof(game_id) != TYPE_STRING or not _is_rewardable_game_id(str(game_id)):
				push_warning("Invalid completed game reward '%s' in progress file '%s'; skipping." % [str(game_id), path])
				safe_rewarded_games.erase(game_id)
	return result

func _apply_save(payload: Dictionary) -> void:
	_loading = true
	_reset_memory()
	for key in payload:
		if key not in ["version", "photos", "achievements", "quests", "settings", "visited", "intro_seen", "platform_pending_achievements", "appearance", "equipped", "owned_clothes", "coins", "wardrobe_rewarded_games", "tutorial_seen_games"]:
			_extra_fields[key] = payload[key]
	var loaded_photos: Variant = payload.get("photos", {})
	if typeof(loaded_photos) == TYPE_DICTIONARY:
		for key in loaded_photos:
			if typeof(loaded_photos[key]) == TYPE_DICTIONARY:
				photos[str(key)] = loaded_photos[key]
	var loaded_achievements: Variant = payload.get("achievements", {})
	if typeof(loaded_achievements) == TYPE_DICTIONARY:
		for key in loaded_achievements:
			if loaded_achievements[key] == true:
				achievements[str(key)] = true
	var loaded_quests: Variant = payload.get("quests", {})
	if typeof(loaded_quests) == TYPE_DICTIONARY:
		for key in loaded_quests:
			if _valid_quest_step(loaded_quests[key]):
				quests[str(key)] = int(loaded_quests[key])
	var loaded_settings: Variant = payload.get("settings", {})
	if typeof(loaded_settings) == TYPE_DICTIONARY:
		# Prefer the new value when present; migrate saves that used the old binary day/night key.
		if loaded_settings.has("time_phase"):
			settings["time_phase"] = TimeOfDay.normalize(loaded_settings["time_phase"])
		elif loaded_settings.has("day_time"):
			settings["time_phase"] = TimeOfDay.normalize(loaded_settings["day_time"])
		for setting_key: Variant in loaded_settings.keys():
			if setting_key == "day_time":
				continue
			if DEFAULT_SETTINGS.has(setting_key):
				_apply_loaded_setting(str(setting_key), loaded_settings[setting_key])
			else:
				settings[str(setting_key)] = loaded_settings[setting_key]
	var loaded_visited: Variant = payload.get("visited", {})
	if typeof(loaded_visited) == TYPE_DICTIONARY:
		for key in loaded_visited:
			if loaded_visited[key] == true:
				visited[str(key)] = true
	intro_seen = payload.get("intro_seen", false) == true
	var loaded_pending: Variant = payload.get("platform_pending_achievements", [])
	if typeof(loaded_pending) == TYPE_ARRAY:
		for achievement_id in loaded_pending:
			if typeof(achievement_id) == TYPE_STRING and not achievement_id.is_empty() and not platform_pending_achievements.has(achievement_id):
				platform_pending_achievements.append(achievement_id)
	var loaded_appearance: Variant = payload.get("appearance", {})
	if typeof(loaded_appearance) == TYPE_DICTIONARY:
		for key: Variant in loaded_appearance:
			if DEFAULT_APPEARANCE.has(key):
				appearance[str(key)] = loaded_appearance[key]
	var loaded_owned: Variant = payload.get("owned_clothes", [])
	if typeof(loaded_owned) == TYPE_ARRAY:
		if payload.has("owned_clothes"):
			owned_clothes = []
		for item_id: Variant in loaded_owned:
			var id := str(item_id)
			if typeof(item_id) != TYPE_STRING or owned_clothes.has(id) or wardrobe_item(id).is_empty() or id == "hat-none":
				push_warning("Invalid wardrobe item '%s' in field 'owned_clothes' in progress file '%s'; skipping." % [id, _save_path()])
				continue
			owned_clothes.append(id)
	if not owned_clothes.has("outfit-tide"):
		owned_clothes.append("outfit-tide")
	var loaded_equipped: Variant = payload.get("equipped", {})
	if typeof(loaded_equipped) == TYPE_DICTIONARY:
		for slot: Variant in DEFAULT_EQUIPPED:
			var id := str(loaded_equipped.get(slot, DEFAULT_EQUIPPED[slot]))
			var item := wardrobe_item(id)
			if item.is_empty() or item.slot != slot or (id != "hat-none" and not owned_clothes.has(id)):
				push_warning("Invalid equipped wardrobe item '%s' for slot '%s' in progress file '%s'; using default." % [id, str(slot), _save_path()])
				continue
			equipped[str(slot)] = id
	var loaded_coins: Variant = payload.get("coins", 120)
	if typeof(loaded_coins) in [TYPE_INT, TYPE_FLOAT]:
		coins = int(loaded_coins)
	var loaded_rewarded: Variant = payload.get("wardrobe_rewarded_games", [])
	if typeof(loaded_rewarded) == TYPE_ARRAY:
		for game_id: Variant in loaded_rewarded:
			if typeof(game_id) == TYPE_STRING and _is_rewardable_game_id(game_id) and not wardrobe_rewarded_games.has(game_id):
				wardrobe_rewarded_games.append(game_id)
	var loaded_tutorial_seen: Variant = payload.get("tutorial_seen_games", [])
	if typeof(loaded_tutorial_seen) == TYPE_ARRAY:
		for game_id: Variant in loaded_tutorial_seen:
			if typeof(game_id) == TYPE_STRING and WELCOME_GAME_IDS.has(game_id) and not tutorial_seen_games.has(game_id):
				tutorial_seen_games.append(game_id)
	_loading = false

func _apply_loaded_setting(key: String, value: Variant) -> void:
	if not DEFAULT_SETTINGS.has(key):
		return
	var default_value: Variant = DEFAULT_SETTINGS[key]
	if key == "time_phase":
		if typeof(value) == TYPE_STRING and TimeOfDay.phase_ids().has(value):
			settings[key] = value
	elif typeof(default_value) == TYPE_BOOL:
		if typeof(value) == TYPE_BOOL:
			settings[key] = value
	else:
		if typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)):
			settings[key] = clampf(float(value), 0.0, 1.0) if key.ends_with("_volume") else (clampf(float(value), 1.0, 1.25) if key == "ui_scale" else clampf(float(value), 0.5, 2.0))
	_apply_setting(key)

func _valid_quest_step(value: Variant) -> bool:
	if typeof(value) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(value)):
		return false
	var numeric := float(value)
	return numeric >= 0.0 and numeric <= 3.0 and floor(numeric) == numeric

func _apply_setting(key: String) -> void:
	# AudioDirector combines master and channel gains on each player. Keep the
	# global Master bus at unity so master_volume is applied exactly once.
	if key == "fullscreen" and DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if settings.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)

func _on_changed() -> void:
	if not _loading and not _suppress_changed_save:
		save_progress()

func _reset_memory() -> void:
	photos = {}
	achievements = {}
	quests = {}
	settings = DEFAULT_SETTINGS.duplicate(true)
	visited = {}
	intro_seen = false
	platform_pending_achievements = []
	appearance = DEFAULT_APPEARANCE.duplicate(true)
	equipped = DEFAULT_EQUIPPED.duplicate(true)
	owned_clothes = ["outfit-tide"]
	coins = 120
	wardrobe_rewarded_games = []
	tutorial_seen_games = []
	settings["time_phase"] = TimeOfDay.DEFAULT_PHASE
	_extra_fields = {}
