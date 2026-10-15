extends SceneTree

const Library = preload("res://game/world/hero_2d_library.gd")
const DIRECTIONS := ["front", "front_right", "right", "back_right", "back", "back_left", "left", "front_left"]
const EXPECTED_ACTIONS := ["idle", "start", "walk", "stop", "turn", "photo"]
const CANVAS := Vector2i(280, 360)
const STAGE := Color(0.12, 0.15, 0.19, 1.0)

var failures := 0
var rendered_pose_count := 0
var gallery_count := 0
var library
var gallery_dir := ""

func _initialize() -> void:
	var save_path := OS.get_environment("SNAPLAND_SAVE_PATH")
	if save_path.is_empty() or not save_path.is_absolute_path():
		push_error("SNAPLAND_SAVE_PATH must be an absolute isolated test-profile path")
		quit(2)
		return
	gallery_dir = OS.get_environment("SNAPLAND_HERO_2D_GALLERY_DIR")
	if not gallery_dir.is_empty() and not gallery_dir.is_absolute_path():
		push_error("SNAPLAND_HERO_2D_GALLERY_DIR must be absolute when supplied")
		quit(2)
	library = Library.new()
	root.add_child(library)
	_expect(library._valid_manifest, "real hero 2D manifest initializes and validates")
	if not library._valid_manifest:
		_finish()
		return
	var hair_styles: Array = library.manifest.hair.keys()
	var outfit_names: Array = library.manifest.outfits.keys()
	var action_names: Array = library.manifest.poses.get("front", {}).keys()
	_expect(hair_styles.size() == 2, "pack exposes the expected two authored hair styles")
	_expect(outfit_names.size() == 2, "pack exposes the expected two authored outfits")
	_expect(action_names.size() == EXPECTED_ACTIONS.size(), "pack exposes all six required authored actions")
	for required_action in EXPECTED_ACTIONS:
		_expect(action_names.has(required_action), "required action exists: %s" % required_action)
	var combinations := 0
	for hair_style in hair_styles:
		for hat_on in [false, true]:
			for outfit in outfit_names:
				combinations += 1
				_run_appearance(str(hair_style), bool(hat_on), str(outfit), action_names)
	_expect(combinations == 8, "all eight hair/hat/outfit appearance combinations were checked")
	_expect(library.get_diagnostics().is_empty(), "all real pack coverage checks complete without runtime diagnostics")
	_finish()

func _run_appearance(hair_style: String, hat_on: bool, outfit: String, actions: Array) -> void:
	var old_pose := {"action": "idle", "direction": "front", "frame": 0}
	_expect(library.render_pose(old_pose), "baseline pose renders before appearance switch")
	_expect(library.set_appearance(hair_style, hat_on, outfit), "complete appearance accepted: %s hat=%s %s" % [hair_style, str(hat_on), outfit])
	_expect(library.current_pose == old_pose, "appearance change preserves the active pose")
	var committed_appearance := {"hair_style": hair_style, "hat_on": hat_on, "outfit": outfit}
	_expect(library.current_appearance == committed_appearance, "appearance switches atomically to the requested complete combination")
	if not gallery_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(gallery_dir)
	for action in actions:
		var max_frames := 0
		for direction in DIRECTIONS:
			var frames: Variant = library.manifest.poses.get(direction, {}).get(action, [])
			max_frames = maxi(max_frames, frames.size() if frames is Array else 0)
		var sheet := Image.create(CANVAS.x * max_frames, CANVAS.y * DIRECTIONS.size(), false, Image.FORMAT_RGBA8)
		sheet.fill(STAGE)
		for row in range(DIRECTIONS.size()):
			var direction: String = DIRECTIONS[row]
			var frames: Array = library.manifest.poses.get(direction, {}).get(action, [])
			for frame_index in range(frames.size()):
				var state := {"action": str(action), "direction": direction, "frame": frame_index}
				var image: Image = library.compose_frame(state)
				_expect(image != null, "non-null composition %s/%s frame %d" % [direction, action, frame_index])
				if image == null:
					continue
				_expect(image.get_size() == CANVAS, "canonical canvas %s/%s frame %d" % [direction, action, frame_index])
				_expect(_has_visible_pixel(image), "nonempty composed cel %s/%s frame %d" % [direction, action, frame_index])
				sheet.blend_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), Vector2i(frame_index * CANVAS.x, row * CANVAS.y))
				rendered_pose_count += 1
		if not gallery_dir.is_empty():
			var hat_suffix := "hat1" if hat_on else "hat0"
			var output_path := gallery_dir.path_join("%s-%s-%s-%s.png" % [hair_style, hat_suffix, outfit, action])
			var save_error := sheet.save_png(output_path)
			_expect(save_error == OK, "gallery saved: %s" % output_path)
			if save_error == OK:
				gallery_count += 1
	_expect(library.get_diagnostics().is_empty(), "appearance produced no library diagnostics: %s/%s/%s" % [hair_style, str(hat_on), outfit])

func _has_visible_pixel(image: Image) -> bool:
	return image.get_used_rect().has_area()

func _expect(condition: bool, description: String) -> void:
	if condition:
		return
	failures += 1
	push_error("FAIL hero 2D real pack: " + description)

func _finish() -> void:
	if failures == 0:
		print("PASS hero 2D real pack: %d composed cels across %d appearance/action galleries" % [rendered_pose_count, gallery_count])
		quit(0)
	else:
		push_error("%d hero 2D real pack checks failed; composed %d cels and wrote %d galleries" % [failures, rendered_pose_count, gallery_count])
		quit(1)
