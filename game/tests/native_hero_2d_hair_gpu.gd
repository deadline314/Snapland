extends Node2D
## Render contract only: synthetic drive with a frozen body pose, not a playtest.
const LibraryScript := preload("res://game/world/hero_2d_library.gd")
const RigScript := preload("res://game/world/hero_2d_hair_rig.gd")
var left: Variant
var right: Variant
var rig: Variant
var output := ""
var receipts: Array[Dictionary] = []
func _ready() -> void: _run.call_deferred()
func _run() -> void:
	output = OS.get_environment("SNAPLAND_HERO_2D_REVIEW_DIR")
	if not output.is_absolute_path() or not OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path():
		push_error("GPU contract requires isolated paths");get_tree().quit(2);return
	get_window().size = Vector2i(1280,800)
	left = LibraryScript.new();left.position=Vector2(320,500);add_child(left)
	right = LibraryScript.new();right.position=Vector2(960,500);add_child(right)
	rig = RigScript.new();left.add_child(rig)
	if not rig.initialize(left): get_tree().quit(1);return
	for direction in LibraryScript.DIRECTIONS:
		for hat in [false,true]:
			var state := {"action":"idle" if direction=="front" else "walk","direction":direction,"visual_direction":direction,"frame":0 if direction=="front" else 1}
			left.set_appearance("windswept",hat,"tide_jacket");right.set_appearance("windswept",hat,"tide_jacket")
			left.render_pose(state);right.render_pose(state);rig.sync_pose(state);rig.reset_motion()
			var key := "%s-hat%d" % [direction,int(hat)]
			await _capture(key+"-rest.png")
			for i in range(30): rig.advance(1.0/120.0,Vector2(90,0),state)
			await _capture(key+"-moving.png")
			var amount: float = rig.maximum_tip_displacement()
			for i in range(240): rig.advance(1.0/120.0,Vector2.ZERO,state)
			await _capture(key+"-settled.png")
			var layers: Dictionary = left.get_hair_rig_layers(state)
			receipts.append({"key":key,"view":direction,"hat":hat,"head": [layers.head.x,layers.head.y],"hair_origin":[320+layers.head.x-128,500+layers.head.y-128],"reference_origin":[960+layers.head.x-128,500+layers.head.y-128],"predicted_visible_displacement":amount})
	var f := FileAccess.open(output.path_join("render-contract.json"),FileAccess.WRITE)
	f.store_string(JSON.stringify({"scope":"Synthetic GPU skinning contract with static body; actual input/animation acceptance is a separate native tour","cases":receipts},"  "));f.close()
	print("PASS GPU hair captures ready for pixel comparison; not a visual acceptance claim")
	get_tree().quit()
func _capture(filename: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image.save_png(output.path_join(filename))!=OK: push_error("GPU capture failed")
