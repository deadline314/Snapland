extends SceneTree
## Source-atlas idle diagnostic only. Production grounded rest has a separate no-pop walk-hold gate.
const AvatarRenderer = preload("res://game/world/avatar_renderer.gd")
const CharacterAnimationLibrary = preload("res://game/world/character_animation_library.gd")
class MissingNeutralLibrary extends CharacterAnimationLibrary:
	func texture(actor: String, action: String, direction: String, frame_index: int, equipped: Dictionary = {}) -> Texture2D:
		if action == "idle" and direction in ["front_left", "front_right"] and frame_index == 0: return null
		return super.texture(actor, action, direction, frame_index, equipped)
var failures: Array[String] = []

func _initialize() -> void:
	assert(not OS.get_environment("SNAPLAND_SAVE_PATH").is_empty())
	var renderer := AvatarRenderer.new()
	renderer.inspect_authored_idle_sources=true
	var output := OS.get_environment("SNAPLAND_SAVE_PATH").get_base_dir()
	DirAccess.make_dir_recursive_absolute(output)
	for direction in ["front_left", "front_right"]:
		var neutral: Image = renderer.animation_library.texture("traveller", "idle", direction, 0).get_image()
		neutral.save_png(output.path_join(direction + "-neutral-source.png"))
		var raw: Image = renderer.animation_library.texture("traveller", "idle", direction, 2).get_image()
		var metrics: Dictionary = renderer._authored_source_hair_metrics(raw, direction, "idle")
		_check(not metrics.skull_underlay_indices.is_empty(), direction + " blink has a solid scalp beneath replacement hair")
		raw.save_png(output.path_join(direction + "-blink-source.png"))
		var appearance := {"skin":"warm", "species":"human", "hair":"windswept", "hair_color":"ink", "face":"curious"}
		var equipment := {"hat":"hat-none", "outfit":"outfit-tide"}
		var baseline: Image = renderer.texture(appearance, equipment, direction, 2, "idle").get_image()
		# Measured directly on the two authored blink cels, independent of the
		# renderer's inferred eye masks. These rectangles contain the closed lids.
		var lid_rects := [Rect2i(102,160,19,12), Rect2i(141,160,22,13)] if direction == "front_left" else [Rect2i(132,164,22,14), Rect2i(163,164,18,14)]
		for style in ["bob", "curly"]:
			appearance.hair = style
			var candidate: Image = renderer.texture(appearance, equipment, direction, 2, "idle").get_image()
			candidate.save_png(output.path_join(direction + "-blink-" + style + ".png"))
			_check(candidate.get_used_rect().position.y >= raw.get_used_rect().position.y - 4, direction + "/" + style + " registers to the authored crown without inflating the forehead")
			var lid_pixels := 0
			var changed_lids := 0
			var opened_whites := 0
			for region in lid_rects:
				for y in range(region.position.y, region.end.y):
					for x in range(region.position.x, region.end.x):
						var pixel := baseline.get_pixel(x,y)
						var actual := candidate.get_pixel(x,y)
						if pixel.a > 0.9 and pixel.v < 0.28:
							lid_pixels += 1
							if actual != pixel: changed_lids += 1
						if actual.a > 0.9 and actual.s < 0.11 and actual.v > 0.74: opened_whites += 1
			_check(lid_pixels > 40 and changed_lids == 0, "%s/%s retains every measured closed-lid ink pixel (%d changed of %d)" % [direction, style, changed_lids, lid_pixels])
			_check(opened_whites == 0, direction + "/" + style + " never restores the guide's open eyes")
			var holes := 0
			# Check the actual forehead between the authored brows, rather than
			# treating pointed source-hair tufts as anatomical skull samples.
			var forehead := Rect2i(125,137,15,24) if direction == "front_left" else Rect2i(150,144,12,20)
			for y in range(forehead.position.y, forehead.end.y):
				for x in range(forehead.position.x, forehead.end.x):
					if candidate.get_pixel(x,y).a < 0.9: holes += 1
			_check(holes == 0, direction + "/" + style + " has no exposed transparent scalp holes")
			var floating_scalp := 0
			for y in range(100):
				for x in range(candidate.get_width()):
					var pixel := candidate.get_pixel(x,y)
					if pixel.a > 0.9 and pixel.r > 0.6 and pixel.g > 0.4 and pixel.b < pixel.r * 0.9: floating_scalp += 1
			_check(floating_scalp == 0, direction + "/" + style + " has no pale scalp crescent above its crown")
			var lower_changes := 0
			# Lower legs start at y=300 in these cels. Long curls may naturally
			# cover the waist above that, but never the ankles or planted boots.
			for y in range(300, baseline.get_height()):
				for x in range(baseline.get_width()):
					if candidate.get_pixel(x,y) != baseline.get_pixel(x,y): lower_changes += 1
			_check(lower_changes == 0, direction + "/" + style + " preserves legs and planted shoes byte-for-byte")
		var missing_guide := AvatarRenderer.new()
		missing_guide.inspect_authored_idle_sources=true
		missing_guide.animation_library = MissingNeutralLibrary.new()
		var safe_appearance := {"skin":"warm", "species":"human", "hair":"bob", "hair_color":"ink", "face":"curious"}
		var fallback: Image = missing_guide.texture(safe_appearance, equipment, direction, 2, "idle").get_image()
		_check(fallback.get_data() == baseline.get_data(), direction + " retains complete original hair when closed-eye registration is unavailable")
		var missing_opening := AvatarRenderer.new()
		missing_opening.inspect_authored_idle_sources=true
		for row in missing_opening._diagonal_hair_regions:
			for cut: Image in row: cut.fill(Color("#293b50"))
		var closed_cut: Image = missing_opening.texture(safe_appearance, equipment, direction, 2, "idle").get_image()
		_check(closed_cut.get_data() == baseline.get_data(), direction + " retains complete original hair when the replacement has no face opening")
	var unknown_owner := AvatarRenderer.new()
	unknown_owner._head_material_owners.clear()
	var known_raw: Image=unknown_owner._walk_pose_image("front",0)
	_check(not unknown_owner.has_head_material_owner(known_raw),"missing source ownership is detected")
	var complete_source: Image=unknown_owner.texture({"hair":"windswept"},{"hat":"hat-none"},"front",0,"walk").get_image()
	for style in ["bob","curly"]:
		var safe_source: Image=unknown_owner.texture({"hair":style},{"hat":"hat-none"},"front",0,"walk").get_image()
		_check(safe_source.get_data()==complete_source.get_data(),"unowned source keeps its complete body, face, and hair instead of stripping a guessed mask")
	_check(unknown_owner._missing_head_owner_warnings.size()==1,"missing ownership is reported once per immutable source")
	if failures.is_empty(): print("PASS: source-atlas closed-eye attachment availability (not production idle playback)")
	quit(0 if failures.is_empty() else 1)

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error("IDLE ATTACHMENT: " + message)
