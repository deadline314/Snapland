extends SceneTree

const TimeOfDay = preload("res://game/core/time_of_day.gd")
const ProgressScript = preload("res://game/core/progress.gd")
var failures: Array[String] = []
var progress: Node
var unlocked_ids: Array[String] = []

func _initialize() -> void:
	if OS.get_environment("SNAPLAND_SAVE_PATH").is_empty():
		push_error("Set SNAPLAND_SAVE_PATH to an isolated test profile before running time-of-day checks.")
		quit(1)
		return
	progress = ProgressScript.new()
	root.add_child(progress)
	progress.achievement_unlocked.connect(func(id: String): unlocked_ids.append(id))
	call_deferred("_run")

func _run() -> void:
	for phase: Dictionary in TimeOfDay.PHASES:
		var rotation: Vector3 = phase.key_rotation_degrees
		var ray_y := Vector3(0, 0, -1).rotated(Vector3.RIGHT, deg_to_rad(rotation.x)).y
		_check(ray_y < 0.0, "%s key light points down toward the park" % phase.id)
	progress.reset_progress()
	_check(progress.settings.time_phase == "noon", "new profile starts at noon")
	_check(progress.set_time_phase("dawn"), "valid phase can be selected")
	_check(not progress.set_time_phase("storm"), "invalid phase is rejected")
	_check(progress.settings.time_phase == "dawn", "invalid phase does not replace saved selection")

	_write_save('{"settings":{"day_time":"night"}}')
	progress.load_progress()
	_check(progress.settings.time_phase == "night", "legacy night value migrates")
	_check(not progress.settings.has("day_time"), "legacy setting is not retained as an unknown setting")
	_write_save('{"settings":{"day_time":false}}')
	progress.load_progress()
	_check(progress.settings.time_phase == "noon", "legacy false day/night toggle maps to noon")
	_write_save('{"settings":{"time_phase":"dusk","day_time":"night"}}')
	progress.load_progress()
	_check(progress.settings.time_phase == "dusk", "canonical phase takes precedence over legacy value")
	_write_save('{"settings":{"time_phase":"invalid"}}')
	progress.load_progress()
	_check(progress.settings.time_phase == "noon", "invalid saved phase safely resets to noon")

	progress.reset_progress()
	var normal_before: int = progress.normal_count()
	var devils_before: int = progress.devil_count()
	var coins_before: int = progress.coins
	var dawn_frame := _write_frame("wrong-phase-dawn.png", 320, 180)
	_check(not progress.collect_time_postcard("dawn", dawn_frame), "a frame for another selected phase cannot be collected")
	_check(progress.coins == coins_before and progress.photos.is_empty(), "wrong-phase capture gives no reward or record")
	_check(not progress.collect_time_postcard("noon", ""), "cancelled capture with no file is rejected")
	_check(progress.coins == coins_before and progress.photos.is_empty(), "cancelled capture gives no reward or record")
	for phase_id in TimeOfDay.phase_ids():
		_check(progress.set_time_phase(phase_id), "%s phase can be selected before collection" % phase_id)
		var frame_path := _write_frame("postcard-time-%s.png" % phase_id, 320, 180)
		_check(progress.collect_time_postcard(phase_id, frame_path), "first %s postcard is awarded" % phase_id)
		_check(not progress.collect_time_postcard(phase_id, frame_path), "duplicate %s postcard is rejected" % phase_id)
	_check(progress.coins == 200, "four first postcards award exactly 80 coins")
	_check(progress.photos.size() == 4, "four distinct time postcard records are stored")
	_check(progress.normal_count() == normal_before and progress.devil_count() == devils_before, "time postcards do not alter normal or devil counts")
	_check(progress.achievements.has(TimeOfDay.ACHIEVEMENT_ALL_POSTCARDS), "fourth postcard unlocks the achievement")
	_check(unlocked_ids.has(TimeOfDay.ACHIEVEMENT_ALL_POSTCARDS), "achievement signal is emitted for the platform bridge")
	progress._reset_memory()
	progress.load_progress()
	_check(progress.settings.time_phase == "night", "last selected phase survives save reload")
	_check(progress.coins == 200 and progress.photos.size() == 4, "postcards and their rewards survive save reload")
	_check(progress.achievements.has(TimeOfDay.ACHIEVEMENT_ALL_POSTCARDS), "postcard achievement survives save reload")
	for phase_id in TimeOfDay.phase_ids():
		var source_id := TimeOfDay.postcard_id(phase_id)
		var frames: Array = progress.photos[source_id].get("frames", [])
		_check(frames.size() == 1 and typeof(frames[0]) == TYPE_STRING and FileAccess.file_exists(str(frames[0])), "%s postcard frame metadata survives reload" % phase_id)
		if frames.size() == 1 and typeof(frames[0]) == TYPE_STRING and FileAccess.file_exists(str(frames[0])):
			var saved_frame := Image.load_from_file(str(frames[0]))
			_check(saved_frame != null and saved_frame.get_width() == 320 and saved_frame.get_height() == 180, "%s postcard PNG is 320x180 after reload" % phase_id)
	if failures.is_empty():
		print("PASS: time-of-day runtime checks")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _write_save(text: String) -> void:
	var file := FileAccess.open(progress._save_path(), FileAccess.WRITE)
	_check(file != null, "save fixture can be written")
	if file == null:
		return
	file.store_string(text)
	file.close()

func _write_frame(name: String, width: int, height: int) -> String:
	var directory: String = progress._save_path().get_base_dir() + "/photos"
	var error := DirAccess.make_dir_recursive_absolute(directory)
	if error != OK and error != ERR_ALREADY_EXISTS:
		_check(false, "photo directory can be created")
		return ""
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	image.fill(Color("#86b8ce"))
	var path: String = directory + "/" + name
	_check(image.save_png(path) == OK, "test frame can be saved")
	return path

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
