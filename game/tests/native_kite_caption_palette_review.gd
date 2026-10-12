extends Node

const FlightView = preload("res://game/minigames/kite_flight_view.gd")
const KiteModel = preload("res://game/minigames/kite_flight_model.gd")
const REVIEW_DIR := "res://.review/kite-flight-caption"
const PHASES: Array[String] = ["dawn", "noon", "dusk", "night"]
const WATCHDOG_MSEC := 10000

var _deadline_msec := 0
var _finished := false

func _ready() -> void:
	call_deferred("_run")

func _process(_delta: float) -> void:
	if _movie_mode():
		RenderingServer.force_draw()
	if _deadline_msec > 0 and Time.get_ticks_msec() >= _deadline_msec and not _finished:
		_fail("four-phase caption capture exceeded its 10-second wall-clock watchdog")

func _movie_mode() -> bool:
	return OS.has_feature("movie") or OS.get_cmdline_args().has("--write-movie")

func _run() -> void:
	if DisplayServer.get_name() == "headless" or OS.get_environment("SNAPLAND_SAVE_PATH").strip_edges().is_empty():
		_fail("requires a GPU window and isolated SNAPLAND_SAVE_PATH")
		return
	_deadline_msec = Time.get_ticks_msec() + WATCHDOG_MSEC
	var output_dir := ProjectSettings.globalize_path(REVIEW_DIR)
	if DirAccess.make_dir_recursive_absolute(output_dir) != OK and not DirAccess.dir_exists_absolute(output_dir):
		_fail("could not create isolated caption screenshot folder")
		return
	var model = KiteModel.new()
	model.reset(false)
	var snapshot: Dictionary = model.snapshot()
	var view: Control = FlightView.new()
	view.name = "KiteCaptionPaletteReview"
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(view)
	for phase in PHASES:
		if Time.get_ticks_msec() >= _deadline_msec:
			_fail("wall-clock deadline expired before phase " + phase)
			return
		view.update_frame(snapshot, "playing", false, phase)
		if not await _capture_image("phase-" + phase):
			return
		print("CAPTION PALETTE CAPTURE: phase=", phase, " path=", REVIEW_DIR, "/phase-", phase, ".png")
	# Synthetic view-only labels exercise caption tints across both dark palettes
	# and the Session's real singular result phase. They do not award or claim play.
	for time_phase in ["dusk", "night"]:
		for flight_phase in ["playing", "result"]:
			for event in ["", "miss", "edge", "center", "line_snap"]:
				if Time.get_ticks_msec() >= _deadline_msec:
					_fail("wall-clock deadline expired during synthetic caption previews")
					return
				var preview_snapshot: Dictionary = snapshot.duplicate(true)
				preview_snapshot["event"] = event
				view.update_frame(preview_snapshot, flight_phase, false, time_phase)
				var label: String = "generic" if event.is_empty() else event
				if not await _capture_image("preview-%s-%s-%s" % [time_phase, flight_phase, label]):
					return
				print("SYNTHETIC CAPTION PREVIEW ONLY: palette=", time_phase, " phase=", flight_phase, " event=", label)
	view.queue_free()
	await get_tree().process_frame
	_finished = true
	_deadline_msec = 0
	print("PASS: captured dawn/noon/dusk/night actual rendered view palettes; no session, gameplay input, score, reward, or completion was created")
	get_tree().quit(0)

func _capture_image(name: String) -> bool:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	if Time.get_ticks_msec() >= _deadline_msec:
		_fail("wall-clock deadline expired while rendering " + name)
		return false
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty() or image.get_width() != 1280 or image.get_height() != 720:
		_fail("unexpected/empty native viewport image for " + name)
		return false
	var path := ProjectSettings.globalize_path(REVIEW_DIR + "/" + name + ".png")
	if image.save_png(path) != OK:
		_fail("could not save native phase image: " + path)
		return false
	return true

func _fail(message: String) -> void:
	if _finished:
		return
	_finished = true
	_deadline_msec = 0
	push_error("Native kite caption palette review: " + message)
	get_tree().quit(1)
