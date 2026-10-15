extends Control

const SampleScene := preload("res://game/review/hero_2d_sample.tscn")

var _sample: Variant


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var save_path := OS.get_environment("SNAPLAND_SAVE_PATH").strip_edges()
	var output_dir := OS.get_environment("SNAPLAND_HERO_2D_REVIEW_DIR").strip_edges()
	if save_path.is_empty() or not save_path.is_absolute_path() or output_dir.is_empty() or not output_dir.is_absolute_path():
		push_error("Set absolute isolated SNAPLAND_SAVE_PATH and SNAPLAND_HERO_2D_REVIEW_DIR before the native 2D tour.")
		get_tree().quit(2)
		return
	get_window().size = Vector2i(1280, 800)
	_sample = SampleScene.instantiate()
	_sample.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_sample)
	await get_tree().process_frame
	var quarter := OS.get_environment("SNAPLAND_HERO_2D_QUARTER") == "1"
	_sample.start_tour(output_dir, quarter)
	var receipt: Dictionary = await _sample.tour_completed
	print("HERO_2D_AUDIT " + JSON.stringify(receipt))
	if str(receipt.get("result", "FAIL")) != "PASS_STATE_CHECKS":
		get_tree().quit(1)
		return
	get_tree().quit(0)
