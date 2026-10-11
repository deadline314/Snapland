extends SceneTree

const AvatarRenderer = preload("res://game/world/avatar_renderer.gd")
const ParkWorld = preload("res://game/world/park_world.gd")

func _initialize() -> void:
	assert(not OS.get_environment("SNAPLAND_SAVE_PATH").is_empty(), "avatar runtime checks require an isolated SNAPLAND_SAVE_PATH")
	var renderer := AvatarRenderer.new()
	assert(renderer.is_asset_ready(), "packaged action atlas passes its bounds and center-pixel checks")
	assert(renderer.has_walk_atlas(), "all eight authored walk directions load from imported atlas resources")
	assert(renderer.has_diagonal_parts(), "the four authored diagonal hairstyle and hat parts load from imported resources")
	assert(renderer.has_hat_atlas(), "packaged directional hat atlas passes its region checks")
	assert(renderer.has_hair_atlas(), "packaged directional hair atlas passes its region checks")
	assert(renderer.has_species_atlas(), "packaged species-parts atlas passes its region checks")
	var appearance := {
		"skin":"warm", "species":"human", "gender":"neutral",
		"hair":"windswept", "hair_color":"ink", "face":"curious",
	}
	var equipped := {"outfit":"outfit-tide", "hat":"hat-none"}
	var base: Texture2D = renderer.texture(appearance, equipped)
	assert(base != null and base.get_height() > 0, "avatar renderer returns a usable default texture")
	assert(base == renderer.texture(appearance, equipped), "identical poses reuse the bounded texture cache")
	assert(renderer.animation_library.has_frame("traveller", "idle", "front"), "the real animation manifest provides traveller front idle frames")
	var authored_idle_first: Texture2D = renderer.texture(appearance, equipped, "front", 0, "idle")
	var authored_idle_blink: Texture2D = renderer.texture(appearance, equipped, "front", 4, "idle")
	assert(_image_data(authored_idle_first) != _image_data(authored_idle_blink), "manifest idle frame 0 and blink frame 4 render distinct authored poses")
	assert(renderer.walk_frame_count("front") == 8, "manifest idle does not replace the compatible eight-frame legacy walk")
	var authored_tide: Texture2D = renderer.animation_library.texture("traveller", "idle", "front", 0, equipped)
	var authored_coral: Texture2D = renderer.animation_library.texture("traveller", "idle", "front", 0, {"outfit":"outfit-coral"})
	assert(authored_tide != null and authored_coral != null and _image_data(authored_tide) != _image_data(authored_coral), "real manifest's outfit-coral variant loads and replaces the traveller body cel")
	assert(renderer.has_authored_action("jump", "front") and renderer.authored_frame_count("jump", "front") == 8 and is_equal_approx(renderer.authored_action_fps("jump", "front"), 12.0), "renderer exposes the authored jump frame count and cadence")
	var jump_frames: Array[PackedByteArray] = []
	for frame_index in range(renderer.authored_frame_count("jump", "front")):
		var jump_pose: Texture2D = renderer.texture(appearance, equipped, "front", frame_index, "jump")
		assert(jump_pose != null and _opaque_pixels(jump_pose) > 5000, "jump pose %d retains appearance and visible authored pixels" % frame_index)
		jump_frames.append(_image_data(jump_pose))
	assert(_unique_bytes(jump_frames) == 8, "renderer selects all eight distinct jump poses without clamping to three frames")
	var coral_jump: Texture2D = renderer.texture(appearance, {"outfit":"outfit-coral", "hat":"hat-none"}, "front", 7, "jump")
	assert(coral_jump != null and _image_data(coral_jump) != jump_frames[7], "renderer selects the coral jump variant while preserving avatar appearance processing")
	assert(renderer.texture(appearance, equipped, "front", 7, "jump") == renderer.texture(appearance, equipped, "front", 7, "jump"), "repeated jump frame requests reuse the composed appearance texture cache")

	var directions := ["front", "front_right", "right", "back_right", "back", "back_left", "left", "front_left"]
	var pose_images: Array[PackedByteArray] = []
	var foot_rows: Array[int] = []
	for direction in directions:
		var frame_count := renderer.walk_frame_count(direction)
		assert(frame_count in [8, 16], "each authored heading reports its actual eight- or sixteen-pose count: %s=%d" % [direction, frame_count])
		var idle_frame := renderer.walk_idle_frame(direction)
		assert(idle_frame >= 0 and idle_frame < frame_count, "each heading's authored idle_frame stays within its walk cycle: %s/%d" % [direction, idle_frame])
		var idle_pose: Texture2D = renderer.texture(appearance, equipped, direction, 0, "idle")
		assert(idle_pose != null and _opaque_pixels(idle_pose) > 5000, "every idle heading retains visible source pixels")
		foot_rows.append(_last_opaque_row(idle_pose))
		var manifest_idle_count: int = renderer.animation_library.frame_count("traveller", "idle", direction)
		if manifest_idle_count > 0:
			assert(_image_data(idle_pose) != _image_data(renderer.texture(appearance, equipped, direction, idle_frame, "walk")), "manifest idle uses authored pose art instead of the legacy walk hold cel")
		else:
			assert(idle_pose == renderer.texture(appearance, equipped, direction, frame_count - 1, "idle"), "legacy idle holds its metadata-selected pose independent of the walk phase")
			assert(_image_data(idle_pose) == _image_data(renderer.texture(appearance, equipped, direction, idle_frame, "walk")), "legacy idle uses the authored contact/hold cel selected by its direction metadata")
		var frames: Array[PackedByteArray] = []
		for frame in range(frame_count):
			var pose: Texture2D = renderer.texture(appearance, equipped, direction, frame, "walk")
			assert(pose != null and _opaque_pixels(pose) > 5000, "every direction/frame cel has visible pixels: %s/%d" % [direction, frame])
			assert(_walk_source_has_clear_margin(renderer, direction, frame, 2), "source walk cel keeps a two-pixel alpha-scissor-safe margin: %s/%d" % [direction, frame])
			assert(_image_has_clear_margin(pose.get_image(), 2), "composed 280x360 walk pose keeps a transparent two-pixel boundary: %s/%d" % [direction, frame])
			frames.append(_image_data(pose))
			foot_rows.append(_last_opaque_row(pose))
		assert(_unique_bytes(frames) == frame_count, "all %d authored cels remain distinct for %s" % [frame_count, direction])
		pose_images.append(frames[0])
	for action in ["wave", "photograph", "interact", "celebrate"]:
		var pose: Texture2D = renderer.texture(appearance, equipped, "front", 0, action)
		assert(pose != null and _opaque_pixels(pose) > 5000, "every action pose has visible content")
		pose_images.append(_image_data(pose))
		foot_rows.append(_last_opaque_row(pose))
	assert(pose_images[0] != pose_images[4], "front and back authored views differ")
	assert(pose_images[0] != pose_images[6], "front and left authored views differ")
	assert(pose_images[2] != pose_images[6], "right and left authored views differ")
	assert(pose_images[4] != pose_images[2], "back and right authored views differ")
	assert(pose_images[1] != pose_images[0] and pose_images[7] != pose_images[0], "both front diagonals retain authored perspective rather than cardinal reuse")
	assert(_image_data(renderer.texture(appearance, equipped, "front", 0, "walk")) != _image_data(renderer.texture(appearance, equipped, "front", 1, "walk")), "walking changes authored cel instead of repeating a two-frame toggle")
	assert(pose_images[0] != _image_data(renderer.texture(appearance, equipped, "front", 0, "wave")), "wave action differs from the authored idle pose")
	var diagonal_wave: Texture2D = renderer.texture(appearance, equipped, "front_right", 0, "wave")
	assert(not renderer.animation_library.has_frame("traveller", "wave", "front_right") and _opaque_pixels(diagonal_wave) > 5000, "uncovered diagonal wave remains an explicit legacy fallback, not claimed manifest coverage")
	for row in foot_rows:
		assert(absi(row - 346) <= 1, "all directions and actions stay within one output pixel of the common foot baseline: %s" % str(foot_rows))

	var changed_equipped := equipped.duplicate()
	changed_equipped.outfit = "outfit-coral"
	assert(_image_data(base) != _image_data(renderer.texture(appearance, changed_equipped)), "outfit changes avatar pixels")
	changed_equipped.outfit = "outfit-tide"
	changed_equipped.hat = "hat-straw"
	var straw_hat: Texture2D = renderer.texture(appearance, changed_equipped)
	assert(_image_data(base) != _image_data(straw_hat), "hat changes avatar pixels")
	var authored_head: Vector2i = renderer.animation_library.normalized_anchor("traveller", "idle", "front", 0, "head", equipped)
	var straw_head: Vector2i = renderer.animation_library.normalized_anchor("traveller", "idle", "front", 0, "head", changed_equipped)
	# The fixed y=38 probe belonged to earlier source art. Read the current authored head anchor instead.
	var crown_probe := Rect2i(authored_head.x - 95, authored_head.y - 8, 190, 20)
	var hat_envelope := Rect2i(authored_head.x - 110, authored_head.y - 6, 220, 65)
	assert(straw_head == authored_head and _region_difference_count(base, straw_hat, crown_probe) > 0, "straw crown adds pixels immediately around the current authored source head without moving its anchor")
	assert(_last_opaque_row(base) == _last_opaque_row(straw_hat), "adding the straw hat leaves the authored feet baseline unchanged")
	assert(_difference_outside_region_count(base, straw_hat, hat_envelope) == 0, "straw hat changes pixels only within its head-anchored overlay envelope")
	assert(_region_difference_count(base, straw_hat, Rect2i(80, 126, 120, 54)) == 0, "straw brim stays above the new front eye and face landmarks")
	changed_equipped.hat = "hat-sailor"
	var sailor_hat: Texture2D = renderer.texture(appearance, changed_equipped)
	assert(renderer.animation_library.normalized_anchor("traveller", "idle", "front", 0, "head", changed_equipped) == authored_head and _region_difference_count(base, sailor_hat, crown_probe) > 0, "sailor crown uses the same current source head without moving its anchor")
	assert(_last_opaque_row(base) == _last_opaque_row(sailor_hat), "adding the sailor hat leaves the authored feet baseline unchanged")
	assert(_difference_outside_region_count(base, sailor_hat, hat_envelope) == 0, "sailor hat changes pixels only within its head-anchored overlay envelope")
	assert(_region_difference_count(base, sailor_hat, Rect2i(80, 126, 120, 54)) == 0, "sailor brim stays above the new front eye and face landmarks")

	var changed_appearance := appearance.duplicate()
	changed_appearance.skin = "deep"
	assert(_image_data(base) != _image_data(renderer.texture(changed_appearance, equipped)), "skin tone changes avatar pixels")
	changed_appearance = appearance.duplicate()
	changed_appearance.species = "elf"
	var elf_front: Texture2D = renderer.texture(changed_appearance, equipped)
	assert(_image_data(base) != _image_data(elf_front), "elf species parts change avatar pixels")
	assert(_region_difference_count(base, elf_front, Rect2i(0, 76, 55, 60)) > 20, "front elf ear tip protrudes outside the left hair silhouette")
	assert(_region_difference_count(base, elf_front, Rect2i(225, 76, 55, 60)) > 20, "front elf ear tip protrudes outside the right hair silhouette")
	assert(_image_data(renderer.texture(appearance, equipped, "left")) != _image_data(renderer.texture(changed_appearance, equipped, "left")), "profile elf has a directional ear part")
	assert(_region_difference_count(renderer.texture(appearance, equipped, "left"), renderer.texture(changed_appearance, equipped, "left"), Rect2i(0, 76, 55, 65)) > 20, "profile elf ear extends beyond the side hair")
	assert(_region_difference_count(renderer.texture(appearance, equipped, "left"), renderer.texture(changed_appearance, equipped, "left"), Rect2i(32, 82, 48, 56)) > 20, "profile elf ear overlaps the cheek-side silhouette at its root")
	assert(_region_difference_count(renderer.texture(appearance, equipped, "right"), renderer.texture(changed_appearance, equipped, "right"), Rect2i(225, 76, 55, 65)) > 20, "opposite profile elf ear extends beyond the side hair")
	assert(_region_difference_count(renderer.texture(appearance, equipped, "right"), renderer.texture(changed_appearance, equipped, "right"), Rect2i(200, 82, 48, 56)) > 20, "opposite profile elf ear overlaps the cheek-side silhouette at its root")
	assert(_image_data(renderer.texture(appearance, equipped, "back")) != _image_data(renderer.texture(changed_appearance, equipped, "back")), "back-facing elf has attached ear parts")
	assert(_region_difference_count(renderer.texture(appearance, equipped, "back"), renderer.texture(changed_appearance, equipped, "back"), Rect2i(0, 76, 55, 60)) > 20, "back-facing elf ear tips remain visible outside the hair silhouette")
	changed_appearance.species = "imp"
	assert(_image_data(base) != _image_data(renderer.texture(changed_appearance, equipped)), "imp horns use the species-parts atlas")
	changed_appearance.species = "human"
	changed_appearance.gender = "female"
	assert(renderer.texture(changed_appearance, equipped) == base, "female identity reuses the shared gender-neutral sprite texture")
	changed_appearance.gender = "male"
	assert(renderer.texture(changed_appearance, equipped) == base, "male identity reuses the shared gender-neutral sprite texture")
	changed_appearance = appearance.duplicate()
	changed_appearance.hair = "bob"
	assert(_image_data(base) != _image_data(renderer.texture(changed_appearance, equipped)), "hair style changes avatar pixels")
	assert(_image_data(renderer.texture(appearance, equipped, "front_left")) != _image_data(renderer.texture(changed_appearance, equipped, "front_left")), "diagonal hairstyle uses its matching authored hair piece")
	changed_equipped.hat = "hat-straw"
	assert(_image_data(renderer.texture(appearance, equipped, "back_right")) != _image_data(renderer.texture(appearance, changed_equipped, "back_right")), "diagonal headwear uses its matching authored hat piece")
	changed_appearance = appearance.duplicate()
	changed_appearance.face = "smiling"
	var smiling_front: Texture2D = renderer.texture(changed_appearance, equipped)
	assert(_image_data(base) != _image_data(smiling_front), "front idle expression changes avatar pixels")
	assert(_image_data(renderer.texture(appearance, equipped, "left")) == _image_data(renderer.texture(changed_appearance, equipped, "left")), "expression overlay is not misplaced on profile faces")
	assert(_image_data(renderer.texture(appearance, equipped, "back")) == _image_data(renderer.texture(changed_appearance, equipped, "back")), "expression overlay never appears on the back of the head")
	assert(renderer.cached_texture_count() <= 128, "renderer reports a bounded texture cache")
	call_deferred("_probe_world_integration")


func _probe_world_integration() -> void:
	var world := ParkWorld.new()
	root.add_child(world)
	await process_frame
	assert(world.avatar.texture != null and world.identity_textures.size() == 3, "world uses detailed player and NPC atlas sprites")
	var appearance := AvatarRenderer.DEFAULT_APPEARANCE.duplicate()
	var coral_equipped := {"outfit":"outfit-coral", "hat":"hat-sailor"}
	var original_texture: Texture2D = world.avatar.texture
	world.set_avatar_look(appearance, coral_equipped)
	var updated := world.avatar.texture
	assert(updated != null and updated != original_texture, "changing equipment replaces the existing world avatar texture")
	world.play_action("celebrate")
	assert(world.avatar_action == "celebrate" and world.avatar.texture != updated, "world action API selects a visible celebration pose")
	var wave_key := InputEventKey.new()
	wave_key.pressed = true
	wave_key.keycode = KEY_F
	world._unhandled_key_input(wave_key)
	assert(world.avatar_action == "wave", "unhandled F key selects wave action")
	var photo_key := InputEventKey.new()
	photo_key.pressed = true
	photo_key.keycode = KEY_P
	world._unhandled_key_input(photo_key)
	assert(world.avatar_action == "photograph", "unhandled P key selects photo action")
	world.blocked = true
	world._unhandled_key_input(wave_key)
	assert(world.avatar_action == "photograph", "blocked modal input cannot replace an avatar action")
	var paused_action_time: float = world.avatar_action_elapsed
	var paused_idle_time: float = world.time
	for _step in range(2): await physics_frame
	assert(world.avatar_action == "photograph" and is_equal_approx(world.avatar_action_elapsed, paused_action_time) and is_equal_approx(world.time, paused_idle_time), "modal freeze preserves action and idle animation phases")
	world.blocked = false
	Input.action_press("move_right")
	for _step in range(5): await physics_frame
	Input.action_release("move_right")
	assert(world.avatar_action.is_empty(), "walking cancels a gesture so its planted pose never slides")
	world.queue_free()
	print("PASS: avatar runtime checks")
	quit(0)

func _image_data(texture: Texture2D) -> PackedByteArray:
	return texture.get_image().get_data()

func _unique_bytes(items: Array[PackedByteArray]) -> int:
	var unique: Dictionary = {}
	for item in items: unique[Marshalls.raw_to_base64(item)] = true
	return unique.size()

func _opaque_pixels(texture: Texture2D) -> int:
	var image := texture.get_image()
	var count := 0
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a > 0.63: count += 1
	return count

func _walk_source_has_clear_margin(renderer, direction: String, frame: int, margin: int) -> bool:
	var data: Dictionary = renderer._walk_metadata["%s:%d" % [direction, frame]]
	var region: Rect2i = data.region
	var source: Image = renderer._walk_images[data.atlas]
	for inset in range(margin):
		var top := region.position.y + inset
		var bottom := region.end.y - 1 - inset
		var left := region.position.x + inset
		var right := region.end.x - 1 - inset
		for x in range(region.position.x, region.end.x):
			if source.get_pixel(x, top).a >= 0.5 or source.get_pixel(x, bottom).a >= 0.5:
				return false
		for y in range(region.position.y, region.end.y):
			if source.get_pixel(left, y).a >= 0.5 or source.get_pixel(right, y).a >= 0.5:
				return false
	return true

func _image_has_clear_margin(image: Image, margin: int) -> bool:
	if image.get_width() <= margin * 2 or image.get_height() <= margin * 2: return false
	for inset in range(margin):
		for x in range(image.get_width()):
			if image.get_pixel(x, inset).a >= 0.5 or image.get_pixel(x, image.get_height() - 1 - inset).a >= 0.5:
				return false
		for y in range(image.get_height()):
			if image.get_pixel(inset, y).a >= 0.5 or image.get_pixel(image.get_width() - 1 - inset, y).a >= 0.5:
				return false
	return true

func _last_opaque_row(texture: Texture2D) -> int:
	var image := texture.get_image()
	for y in range(image.get_height() - 1, -1, -1):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a > 0.4: return y
	return -1

func _region_difference_count(first: Texture2D, second: Texture2D, region: Rect2i) -> int:
	var first_image := first.get_image()
	var second_image := second.get_image()
	var count := 0
	for y in range(region.position.y, mini(region.end.y, first_image.get_height())):
		for x in range(region.position.x, mini(region.end.x, first_image.get_width())):
			if first_image.get_pixel(x, y) != second_image.get_pixel(x, y): count += 1
	return count

func _difference_outside_region_count(first: Texture2D, second: Texture2D, allowed: Rect2i) -> int:
	var first_image := first.get_image()
	var second_image := second.get_image()
	var count := 0
	for y in range(first_image.get_height()):
		for x in range(first_image.get_width()):
			if allowed.has_point(Vector2i(x,y)):
				continue
			if first_image.get_pixel(x,y) != second_image.get_pixel(x,y): count += 1
	return count
