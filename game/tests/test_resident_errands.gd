extends Node
## Resident errands in the circus, toy town and greenhouse, end to end on the
## real main scene: offer, three steps from real evidence, save and reopen
## mid-errand, one errand photo, album replay, and the greeting left as it was.

var root: Window:
	get: return get_tree().root

const Scene = preload("res://game/main.tscn")
const Guard = preload("res://game/core/test_save_guard.gd")
const PlaybackRelease = preload("res://game/tests/audio_playback_release.gd")
const Visit = preload("res://game/story/regional_visit.gd")
const Errands = preload("res://game/story/resident_errands.gd")
const REGIONS := [Visit.CIRCUS, Visit.TOY, Visit.GARDEN]
var main: Node
var progress: Node
var failures: Array[String] = []

func _ready() -> void:
	if not Guard.validate_save_path(OS.get_environment("SNAPLAND_SAVE_PATH"), OS.get_user_data_dir()).is_empty():
		push_error("Resident errand tests require an isolated save path.")
		get_tree().quit(1)
		return
	call_deferred("_run")

func _run() -> void:
	_check(Errands.problems().is_empty(), "errand table is valid: %s" % str(Errands.problems()))
	progress = root.get_node("Progress")
	progress.reset_progress()
	progress.intro_seen = true
	progress.prologue_seen = true
	progress.settings.master_volume = 0.0
	for venue in ["welcome", "harbor", "candy"]:
		for index in range(1, (6 if venue == "candy" else 12) + 1):
			progress.photos["photo-%s-game-%d" % [venue, index]] = {"fixture": "scripted setup"}
	_check(progress.set_current_region(Visit.CIRCUS) and progress.save_progress(), "fixture profile saved")
	# A save from before errands existed: no errand field at all.
	var path := OS.get_environment("SNAPLAND_SAVE_PATH")
	var legacy: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	legacy.erase("errands")
	_write(path, legacy)
	progress.load_progress()
	_check(progress.errands.is_empty() and progress.normal_count() == 30, "an older save loads with no errand started")
	legacy["errands"] = {"circus": 9, "toy": "x"}
	_write(path, legacy)
	progress.load_progress()
	_check(progress.errands.is_empty(), "malformed errand values are dropped, never trusted")
	_write(path, legacy.merged({"errands": {}}, true))
	progress.load_progress()
	main = Scene.instantiate()
	root.add_child(main)
	await _frames(5)
	for region: String in REGIONS:
		await _run_errand(region)
	await _finish()

func _run_errand(region: String) -> void:
	await _go_to(region)
	var host_point := Visit.point_id(region)
	var photo_id := Errands.photo_id(region)
	for index in Errands.DONE:
		var step := Errands.step(region, index)
		_check(not _island_point(str(step.point)).is_empty(), "%s: step %d target %s exists on the island" % [region, index + 1, step.point])
	# Before the greeting photo the host still plays the greeting.
	main._interact(host_point, "")
	_check(main.modal_kind == "dialogue" and str(main.dialogue[0].text) == str(Visit.lines(region)[0].text), "%s: greeting comes first" % region)
	main._cancel_dialogue()
	await _frames(2)
	_check(progress.errand_step(region) == -1 and main._errand_prompt(host_point).is_empty(), "%s: no errand before the greeting photo" % region)
	var greeting := {"story_region": region, "fixture": "scripted greeting"}
	progress.photos[Visit.photo_id(region)] = greeting
	progress.visited[region] = true
	progress.save_progress()
	_check(main._errand_prompt(host_point).contains(Visit.host_name(region)), "%s: the host's prompt offers the errand" % region)
	main._interact(host_point, "")
	_check(main.modal_kind == "dialogue" and main.dialogue == Errands.intro(region) and main.dialogue_panel.cancel_button.text == "略過",
		"%s: the host tells the errand and it can be skipped" % region)
	main.dialogue_panel.cancel_button.pressed.emit()
	await _frames(2)
	_check(progress.errand_step(region) == 0 and main.quest_label.visible and main.quest_label.text.contains(Errands.step(region, 0).goal),
		"%s: skipping still accepts; the HUD shows the first goal" % region)
	_check(await _map_shows_errand(region), "%s: the district map flags the first goal" % region)
	for index in Errands.PHOTO_STEP:
		var step := Errands.step(region, index)
		main._errand_event("reach" if step.kind != "reach" else "toy", str(step.point))
		main._errand_event(str(step.kind), "field:nothing-here")
		_check(progress.errand_step(region) == index, "%s: unrelated evidence leaves step %d alone" % [region, index + 1])
		await _complete(region, index, step)
		_check(progress.errand_step(region) == index + 1 and main.quest_label.text.contains(Errands.step(region, index + 1).goal),
			"%s: %s step %d finishes from real evidence" % [region, step.kind, index + 1])
		if index == 0:
			await _reopen()
			await _go_to(region)
			_check(progress.errand_step(region) == 1 and main.quest_label.text.contains(Errands.step(region, 1).goal),
				"%s: reopening the game resumes the errand at step 2" % region)
	await _go_to(region)
	main._interact(host_point, "")
	_check(main.modal_kind == "dialogue" and main.dialogue == Errands.finale(region) and main.dialogue_panel.cancel_button.text == "略過到合照",
		"%s: back at the host the wrap-up can skip to the photo" % region)
	main.dialogue_panel.cancel_button.pressed.emit()
	await _frames(3)
	_check(main.modal_kind == "visit_photo" and main.visit_photo_errand and main.visit_photo_panel.photo_title == Errands.title(region),
		"%s: the errand photo uses the district's live photo stage" % region)
	main._exit_region_story_photo()
	await _frames(2)
	_check(main.modal_kind.is_empty() and not progress.photos.has(photo_id) and progress.errand_step(region) == Errands.PHOTO_STEP,
		"%s: cancelling the photo awards nothing and keeps the last step" % region)
	var zone_before: int = progress.normal_count_for_zone(region)
	var image := Image.create(640, 360, false, Image.FORMAT_RGBA8)
	image.fill(Color("#6f8a7c"))
	_check(main._save_region_story_photo(region, photo_id, image), "%s: the errand photo saves" % region)
	var record: Dictionary = progress.photos.get(photo_id, {}).duplicate(true)
	_check(record.get("story_errand") == region and progress.errand_step(region) == Errands.DONE
		and progress.normal_count_for_zone(region) == zone_before + 1 and progress.photos[Visit.photo_id(region)] == greeting,
		"%s: one quest sticker, errand done, greeting photo untouched" % region)
	var saved := FileAccess.get_file_as_string(OS.get_environment("SNAPLAND_SAVE_PATH"))
	_check(progress.record_errand_photo(region, "", "") and not progress.advance_errand(region, Errands.PHOTO_STEP)
		and FileAccess.get_file_as_string(OS.get_environment("SNAPLAND_SAVE_PATH")) == saved and progress.photos[photo_id] == record,
		"%s: the sticker is registered once; repeats change nothing" % region)
	main._refresh_quest_line()
	_check(not main.quest_label.visible and main._errand_prompt(host_point).is_empty(), "%s: finished errand leaves the HUD" % region)
	main._interact(host_point, "")
	_check(main.modal_kind == "dialogue" and str(main.dialogue[0].text) == str(Visit.lines(region)[0].text), "%s: afterwards the host plays the greeting again" % region)
	main._cancel_dialogue()
	await _frames(2)
	_check(await _album_replays(region, photo_id, record), "%s: album replays the errand photo" % region)

## Produces the step's evidence the way play does.
func _complete(region: String, index: int, step: Dictionary) -> void:
	match str(step.kind):
		"reach":
			main.world.place_player(_island_point(str(step.point)).position)
			for frame in 30:
				await get_tree().physics_frame
				if progress.errand_step(region) > index:
					break
			await _frames(2)
		"field_game":
			# A whole real round: walk up, start it, let the clock run out.
			main.world.place_player(_island_point(str(step.point)).position)
			await _frames(3)
			main._interact(str(step.point), "")
			for tick in 600:
				main.world.field_games.advance(0.1)
				if progress.errand_step(region) > index:
					break
		"toy":
			main._interact(str(step.point), "")
	await _frames(2)

## Into the district (fast travel when the walker is elsewhere) once it is fully built.
func _go_to(region: String) -> void:
	if main.world_region != region:
		_check(main._travel_to_region(region), "%s: travel starts" % region)
	for frame in 240:
		await get_tree().process_frame
		if main.world_region == region and not main.changing_region and not _island_point(Visit.point_id(region)).is_empty() and not _island_point(str(Errands.step(region, 1).point)).is_empty() and not _island_point(str(Errands.step(region, 0).point)).is_empty():
			break
	_check(main.world_region == region, "%s: walker stands in the built district" % region)

func _map_shows_errand(region: String) -> bool:
	main._show_map()
	await _frames(2)
	var flag: Node = main.overlay.find_child("*MapErrand", true, false)
	var ok: bool = flag is Label and (flag as Label).text.contains(Errands.step(region, 0).goal)
	main._close()
	return ok

func _album_replays(region: String, photo_id: String, record: Dictionary) -> bool:
	main._show_album(region)
	await _frames(2)
	var tile := main.overlay.find_child("AlbumPhoto_" + photo_id, true, false) as Button
	var greeting_tile: Node = main.overlay.find_child("AlbumPhoto_" + Visit.photo_id(region), true, false)
	if tile == null or greeting_tile == null:
		_check(false, "%s: album shows both the greeting and the errand photo" % region)
		return false
	var status := tile.find_child("AlbumPhotoStatus", true, false) as Label
	_check(status != null and status.text == "已收藏 · 委託", "%s: the errand tile is marked as a collected errand" % region)
	tile.pressed.emit()
	var replay := main.overlay.find_child("PhotoViewerReplayStory", true, false) as Button
	if replay == null:
		return false
	replay.pressed.emit()
	var opened: bool = main.modal_kind == "dialogue" and main.dialogue == Errands.finale(region)
	main.dialogue_panel.cancel_button.pressed.emit()
	await _frames(2)
	opened = opened and main.modal_kind == "visit_photo" and main.visit_photo_errand and main.visit_photo_from_album
	main._exit_region_story_photo()
	await _frames(2)
	var back: bool = main.modal_kind == "album" and progress.photos[photo_id] == record
	main._close()
	return opened and back

func _island_point(id: String) -> Dictionary:
	for point: Dictionary in main.world.points:
		if str(point.id) == id:
			return point
	return {}

## Quit and start again from the saved file, the way a player reopens the game.
func _reopen() -> void:
	var playbacks := PlaybackRelease.capture(main.audio)
	main.quitting = true
	main.audio.shutdown()
	main.free()
	await _frames(3)
	await PlaybackRelease.wait_for_release(get_tree(), playbacks)
	progress.load_progress()
	main = Scene.instantiate()
	root.add_child(main)
	await _frames(8)

func _write(path: String, payload: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(payload))
	file.close()

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
	_check(await PlaybackRelease.wait_for_release(get_tree(), playbacks), "teardown releases stopped audio playbacks")
	for reason in failures:
		push_error(reason)
	if failures.is_empty():
		print("PASS: resident errands: three districts, real steps, reopen, one sticker and album replay")
	get_tree().quit(int(not failures.is_empty()))
