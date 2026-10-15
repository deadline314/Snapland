extends SceneTree

const Library = preload("res://game/world/hero_2d_library.gd")
const DIRECTIONS = ["front", "front_right", "right", "back_right", "back", "back_left", "left", "front_left"]

var failures := 0
var temp_root := ""

func _initialize() -> void:
	var isolated_save := OS.get_environment("SNAPLAND_SAVE_PATH")
	if isolated_save.is_empty():
		push_error("SNAPLAND_SAVE_PATH must point to an isolated test profile")
		quit(2)
		return
	temp_root = isolated_save.get_base_dir().path_join("hero_2d_library_fixture")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(temp_root))
	_write_fixture()
	_test_layer_order_anchor_and_foreground()
	_test_appearance_change_preserves_pose_atomically()
	_test_missing_frame_uses_complete_fallback_and_diagnostic()
	_test_invalid_schema_uses_complete_fallback_and_diagnostic()
	_test_invalid_optional_hat_layers_reject_manifest_atomically()
	_test_combined_hat_variant_is_not_drawn_twice()
	_test_empty_hair_direction_rejects_manifest_and_uses_fallback()
	_remove_fixture()
	if failures == 0:
		print("PASS hero 2D library tests")
		quit(0)
	else:
		push_error("%d hero 2D library checks failed" % failures)
		quit(1)

func _write_fixture(missing_front_left_walk := false, schema_version := 1, invalid_hat_layers := false, combined_hat := false, empty_hair_layers := false) -> void:
	var root := ProjectSettings.globalize_path(temp_root)
	var body := _solid_image(Color(0.8, 0.1, 0.1, 1.0))
	# Transparent center makes behind-hair visible while an authored opaque pixel
	# demonstrates that foreground restoration covers accessory pixels.
	body.fill(Color.TRANSPARENT)
	body.set_pixel(140, 100, Color(0.8, 0.1, 0.1, 1.0))
	_save_png(body, root.path_join("body.png"))
	_save_png(_solid_image(Color(0.1, 0.2, 0.9, 1.0)), root.path_join("coat.png"))
	var layers := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	layers.fill(Color(0.1, 0.9, 0.1, 1.0))
	_save_png(layers, root.path_join("hair-front.png"))
	var behind := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	behind.fill(Color(0.9, 0.1, 0.9, 1.0))
	_save_png(behind, root.path_join("hair-behind.png"))
	var hat := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	hat.fill(Color(0.9, 0.8, 0.1, 1.0))
	_save_png(hat, root.path_join("hat.png"))
	var under_hat := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	under_hat.fill(Color(0.2, 0.7, 0.9, 1.0))
	_save_png(under_hat, root.path_join("hair-under-hat.png"))
	var combined := Image.create(4, 2, false, Image.FORMAT_RGBA8)
	combined.fill(Color(0.95, 0.35, 0.15, 1.0))
	_save_png(combined, root.path_join("hair-with-hat.png"))
	_save_png(_solid_image(Color(0.2, 0.8, 0.8, 1.0)), root.path_join("fallback.png"))
	var poses := {}
	for direction in DIRECTIONS:
		var actions := {}
		for action in ["idle", "walk"]:
			if missing_front_left_walk and direction == "front_left" and action == "walk":
				actions[action] = []
				continue
			var frame := {
				"source": "body.png", "region": [0, 0, 280, 360],
				"head_anchor": [140, 100], "feet": [140, 346],
				"outfits": {"long_coat": {
					"source": "coat.png", "region": [0, 0, 280, 360],
					"head_anchor": [142, 100], "foreground_regions": [[142, 100, 1, 1]],
				}},
				"foreground_regions": [[140, 100, 1, 1]],
			}
			actions[action] = [frame]
		poses[direction] = actions
	var hair_directions := {}
	var hat_directions := {}
	for direction in DIRECTIONS:
		var regular_layers: Array = [
		{"source": "hair-behind.png", "region": [0, 0, 2, 2], "anchor": [0, 0], "offset": [-2, 0], "order": "behind"},
		{"source": "hair-front.png", "region": [0, 0, 2, 2], "anchor": [0, 0], "offset": [-1, 0], "order": "front"},
		]
		if empty_hair_layers and direction == "front_left": regular_layers = []
		var hair_entry := {"layers": regular_layers, "hat_layers": "invalid" if invalid_hat_layers else [
		{"source": "hair-under-hat.png", "region": [0, 0, 2, 2], "anchor": [0, 0], "offset": [-1, 0], "order": "front"},
		]}
		if combined_hat:
			hair_entry["hat_layers"] = [{"source": "hair-with-hat.png", "region": [0, 0, 4, 2], "anchor": [0, 0], "offset": [-1, 0], "order": "front"}]
			hair_entry["hat_layers_include_hat"] = true
		hair_directions[direction] = hair_entry
		hat_directions[direction] = {"layers": [
		{"source": "hat.png", "region": [0, 0, 2, 2], "anchor": [0, 0], "offset": [0, 0], "order": "front"},
		]}
	var manifest := {
		"schema_version": schema_version, "format": "production2d-authored-layers",
		"canvas": [280, 360], "feet_origin": [140, 346],
		"directions": DIRECTIONS, "outfits": {"tide_jacket": {}, "long_coat": {}},
		"hair": {"windswept": hair_directions, "bob": hair_directions},
		"hats": {"traveller": hat_directions}, "poses": poses,
		"fallback": {"source": "fallback.png", "region": [0, 0, 280, 360], "head_anchor": [140, 100], "feet": [140, 346]},
	}
	var file := FileAccess.open(root.path_join("manifest.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest))
	file.close()

func _test_layer_order_anchor_and_foreground() -> void:
	var library = _new_library()
	_expect(library.set_appearance("windswept", false, "tide_jacket"), "valid un-hatted appearance is accepted")
	var image: Image = library.compose_frame({"action": "idle", "direction": "front", "frame": 0})
	_expect(image != null and image.get_size() == Vector2i(280, 360), "composition returns the canonical body canvas")
	if image == null: return
	_expect(_pixel_is(image, Vector2i(140, 100), Color(0.8, 0.1, 0.1, 1.0)), "authored foreground region restores the body over front accessories")
	_expect(_pixel_is(image, Vector2i(139, 100), Color(0.1, 0.9, 0.1, 1.0)), "front hair draws over body after behind hair")
	_expect(_pixel_is(image, Vector2i(138, 100), Color(0.9, 0.1, 0.9, 1.0)), "behind hair remains visible only where the body is transparent")
	_expect(_pixel_is(image, Vector2i(139, 100), Color(0.1, 0.9, 0.1, 1.0)), "unhatted hair uses the authored regular layer set")
	_expect(library.set_appearance("windswept", true, "tide_jacket"), "valid hat and hair appearance is accepted")
	var hatted: Image = library.compose_frame({"action": "idle", "direction": "front", "frame": 0}, {"hair_style": "windswept", "hat_on": true, "outfit": "tide_jacket"})
	_expect(_pixel_is(hatted, Vector2i(139, 100), Color(0.2, 0.7, 0.9, 1.0)), "hat-on appearance uses the authored cropped under-hat hair variant")
	_expect(_pixel_is(hatted, Vector2i(141, 100), Color(0.9, 0.8, 0.1, 1.0)), "front hat draws after front hair at head_anchor minus part anchor")
	library.free()

func _test_appearance_change_preserves_pose_atomically() -> void:
	var library = _new_library()
	var state := {"action": "walk", "direction": "back_right", "frame": 0}
	library.render_pose(state)
	var before: Image = library.compose_frame(state)
	_expect(library.set_appearance("bob", true, "long_coat"), "complete appearance combination validates across eight directions and actions")
	_expect(library.current_pose == state, "appearance switch preserves the current action, direction and frame")
	var after: Image = library.compose_frame(state)
	_expect(_pixel_is(after, Vector2i(20, 20), Color(0.1, 0.2, 0.9, 1.0)), "selected outfit variant is used after atomic appearance switch")
	_expect(not _pixel_is(before, Vector2i(20, 20), Color(0.1, 0.2, 0.9, 1.0)), "appearance switch changes rendered body without changing pose identity")
	_expect(_pixel_is(after, Vector2i(141, 100), Color(0.2, 0.7, 0.9, 1.0)), "outfit head-anchor override moves all selected head parts together")
	_expect(_pixel_is(after, Vector2i(142, 100), Color(0.1, 0.2, 0.9, 1.0)), "outfit foreground override restores the shifted body pixel")
	_expect(not library.set_appearance("bob", true, "missing_outfit"), "unknown outfit is rejected")
	_expect(library.current_pose == state, "failed appearance switch keeps the current pose and appearance")
	_expect(library.current_appearance == {"hair_style": "bob", "hat_on": true, "outfit": "long_coat"}, "failed appearance switch retains the previous complete appearance")
	library.free()

func _test_missing_frame_uses_complete_fallback_and_diagnostic() -> void:
	_write_fixture(true)
	var library = _new_library()
	_expect(not library.set_appearance("windswept", false, "tide_jacket"), "appearance with a missing required direction/action frame is rejected")
	var image: Image = library.compose_frame({"action": "walk", "direction": "front_left", "frame": 0})
	_expect(image != null and _pixel_is(image, Vector2i.ZERO, Color(0.2, 0.8, 0.8, 1.0)), "missing pose renders the complete authored fallback, not a partial body")
	_expect(_has_diagnostic(library, "front_left/walk"), "missing pose diagnostic names the direction and action")
	library.free()

func _test_invalid_schema_uses_complete_fallback_and_diagnostic() -> void:
	_write_fixture(false, 2)
	var library = _new_library()
	var image: Image = library.compose_frame({"action": "idle", "direction": "front", "frame": 0})
	_expect(image != null and _pixel_is(image, Vector2i.ZERO, Color(0.2, 0.8, 0.8, 1.0)), "unsupported manifest version renders only the explicit complete fallback")
	_expect(_has_diagnostic(library, "schema_version"), "unsupported manifest version is diagnosed")
	library.free()

func _test_invalid_optional_hat_layers_reject_manifest_atomically() -> void:
	_write_fixture(false, 1, true)
	var library = _new_library()
	var image: Image = library.compose_frame({"action": "idle", "direction": "front", "frame": 0})
	_expect(not library._valid_manifest, "malformed optional under-hat layer set invalidates the manifest before any appearance can use it")
	_expect(image != null and _pixel_is(image, Vector2i.ZERO, Color(0.2, 0.8, 0.8, 1.0)), "invalid under-hat variant falls back to the complete authored frame")
	_expect(_has_diagnostic(library, "hat_layers"), "invalid under-hat variant is diagnosed")
	library.free()

func _test_combined_hat_variant_is_not_drawn_twice() -> void:
	_write_fixture(false, 1, false, true)
	var library = _new_library()
	_expect(library.set_appearance("windswept", true, "tide_jacket"), "combined hair-and-hat variant validates")
	var image: Image = library.compose_frame({"action": "idle", "direction": "front", "frame": 0})
	_expect(_pixel_is(image, Vector2i(141, 100), Color(0.95, 0.35, 0.15, 1.0)), "combined variant draws its authored hat pixels without a second separate hat overdraw")
	_expect(library.get_diagnostics().is_empty(), "combined variant produces no runtime diagnostic")
	library.free()

func _test_empty_hair_direction_rejects_manifest_and_uses_fallback() -> void:
	_write_fixture(false, 1, false, false, true)
	var library = _new_library()
	var image: Image = library.compose_frame({"action": "idle", "direction": "front", "frame": 0})
	_expect(not library._valid_manifest, "empty hair layers in one direction reject the pack instead of counting as complete coverage")
	_expect(image != null and _pixel_is(image, Vector2i.ZERO, Color(0.2, 0.8, 0.8, 1.0)), "empty required hair direction uses the complete fallback")
	_expect(_has_diagnostic(library, "hair/windswept/front_left"), "empty required hair direction is diagnosed")
	library.free()

func _new_library():
	var library = Library.new(temp_root.path_join("manifest.json"))
	root.add_child(library)
	return library

func _pixel_is(image: Image, point: Vector2i, expected: Color) -> bool:
	var actual := image.get_pixel(point.x, point.y)
	return absf(actual.r - expected.r) < 0.015 and absf(actual.g - expected.g) < 0.015 and absf(actual.b - expected.b) < 0.015 and absf(actual.a - expected.a) < 0.015

func _solid_image(color: Color) -> Image:
	var image := Image.create(280, 360, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return image

func _save_png(image: Image, path: String) -> void:
	var error := image.save_png(path)
	if error != OK: push_error("fixture PNG save failed: %s" % path)

func _remove_fixture() -> void:
	var root := ProjectSettings.globalize_path(temp_root)
	for file in DirAccess.get_files_at(root): DirAccess.remove_absolute(root.path_join(file))
	DirAccess.remove_absolute(root)

func _has_diagnostic(library, token: String) -> bool:
	for message in library.diagnostics:
		if String(message).contains(token): return true
	return false

func _expect(condition: bool, description: String) -> void:
	if condition: return
	failures += 1
	push_error("FAIL hero 2D library: " + description)
