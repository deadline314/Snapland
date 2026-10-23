extends "res://game/tests/native_layout_review.gd"

const WalkRenderer = preload("res://game/world/avatar_renderer.gd")
const GalleryFont = preload("res://assets/fonts/NotoSansCJKtc-Regular.otf")
var gallery: Control

func _run() -> void:
	if OS.get_environment("SNAPLAND_SAVE_PATH").is_empty() or DisplayServer.get_name() == "headless":
		push_error("Native walk review requires GPU and isolated SNAPLAND_SAVE_PATH")
		get_tree().quit(1)
		return
	progress = get_tree().root.get_node_or_null("Progress")
	if progress == null:
		await _fail("Native walk review has no Progress autoload")
		return
	progress.reset_progress()
	progress.intro_seen = true
	main = _instantiate_main()
	if main == null:
		get_tree().quit(1)
		return
	get_tree().root.add_child(main)
	await _frames(8)
	main.world.camera.size = 11.0
	var cases := [
		["front", [KEY_S]], ["back", [KEY_W]], ["left", [KEY_A]], ["right", [KEY_D]],
		["front_left", [KEY_S, KEY_A]], ["front_right", [KEY_S, KEY_D]],
		["back_left", [KEY_W, KEY_A]], ["back_right", [KEY_W, KEY_D]],
	]
	for fixture in cases:
		if not await _review_heading(str(fixture[0]), fixture[1]): return
	if not main.world.avatar_renderer.has_walk_atlas() or not main.world.avatar_renderer.has_diagonal_parts():
		await _fail("Eight-direction authored walk/diagonal appearance assets are unavailable")
		return
	main.world.blocked = true
	main.world.hide()
	main.hud.hide()
	if not await _review_gallery(): return
	print("PASS: native W/A/S/D eight headings, distance-carried gait, idle holds, authored per-heading 8/16 cel counts, ART14 appearance galleries, and ART16 pose/speed-comparison captures. Open-ground placement and gallery poses are explicit review fixtures.")
	await main._quit_game()

func _review_heading(direction: String, keys: Array) -> bool:
	# Each case owns all four synthetic keys; drain releases before relocating its
	# fixture so a delayed native transition cannot contaminate the next heading.
	for code in [KEY_W, KEY_A, KEY_S, KEY_D]: _held_key(code, false)
	await _frames(2)
	main.world.player.position = Vector3(0, 0.4, -6)
	main.world.player.velocity = Vector3.ZERO
	await get_tree().create_timer(0.2).timeout
	for code in keys: _held_key(int(code), true)
	var input_deadline := Time.get_ticks_msec() + 1000
	while not _heading_keys_match(keys) and Time.get_ticks_msec() < input_deadline:
		await get_tree().process_frame
	if not _heading_keys_match(keys):
		for code in [KEY_W, KEY_A, KEY_S, KEY_D]: _held_key(code, false)
		await _fail("Native heading input was not acknowledged: %s vector=%s" % [direction, Input.get_vector("move_left", "move_right", "move_up", "move_down")])
		return false
	var start_position: Vector3 = main.world.player.position
	var start_phase: float = main.world.walk_distance_phase
	# Desktop inspection can generate focus-loss releases. Sustain the requested
	# hold with real key events at each physics tick, retaining the native input
	# path rather than modifying action state or moving the avatar directly.
	for _tick in range(24):
		for code in [KEY_W, KEY_A, KEY_S, KEY_D]: _held_key(code, keys.has(code))
		await get_tree().physics_frame
		await get_tree().process_frame
	var end_position: Vector3 = main.world.player.position
	var displacement := Vector2(end_position.x - start_position.x, end_position.z - start_position.z)
	var expected_phase: float = main.world.advance_walk_phase(start_phase, displacement.length(), main.world.walk_stride_for(direction))
	var phase_error: float = absf(wrapf(main.world.walk_distance_phase - expected_phase, -main.world.WALK_STRIDE_DISTANCE * 0.5, main.world.WALK_STRIDE_DISTANCE * 0.5))
	if displacement.length() < 0.5 or main.world.facing != direction or not main.world.avatar_is_walking or phase_error > 0.015:
		var failed_vector := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		for code in keys: _held_key(int(code), false)
		await _fail("Native heading/gait mismatch expected=%s actual=%s distance=%.3f phase_error=%.5f input_vector=%s position=%s/%s" % [direction, main.world.facing, displacement.length(), phase_error, failed_vector, start_position, end_position])
		return false
	if not _avatar_texture_synced():
		for code in keys: _held_key(int(code), false)
		await _fail("Walk Sprite3D and shader textures differ: " + direction)
		return false
	await RenderingServer.frame_post_draw
	if not main._capture("pm/Snapland-art/images/ART-14-walk-%s.png" % direction):
		for code in keys: _held_key(int(code), false)
		await _fail("Walk screenshot failed: " + direction)
		return false
	for code in keys: _held_key(int(code), false)
	await get_tree().create_timer(0.15).timeout
	var stopped_phase: float = main.world.walk_distance_phase
	var stopped_position: Vector3 = main.world.player.position
	var stopped_texture: Texture2D = main.world.avatar.texture
	await _frames(5)
	if main.world.avatar_is_walking or main.world.facing != direction or main.world.last_avatar_action != "idle" or not is_equal_approx(main.world.walk_distance_phase, stopped_phase) or main.world.player.position.distance_to(stopped_position) > 0.01 or main.world.avatar.texture != stopped_texture or not _avatar_texture_synced():
		await _fail("Released native keys did not preserve stationary idle heading/gait/texture: " + direction)
		return false
	print("NATIVE WALK: ", direction, " distance=", displacement.length(), " phase_error=", phase_error)
	return true

func _heading_keys_match(keys: Array) -> bool:
	var expected := Vector2.ZERO
	if keys.has(KEY_A): expected.x -= 1.0
	if keys.has(KEY_D): expected.x += 1.0
	if keys.has(KEY_W): expected.y -= 1.0
	if keys.has(KEY_S): expected.y += 1.0
	return Input.get_vector("move_left", "move_right", "move_up", "move_down").distance_to(expected.normalized()) < 0.001

func _avatar_texture_synced() -> bool:
	var material := main.world.avatar.material_override as ShaderMaterial
	return material != null and main.world.avatar.texture != null and material.get_shader_parameter("texture_albedo") == main.world.avatar.texture

func _review_gallery() -> bool:
	var renderer = main.world.avatar_renderer
	var sixteen_directions: Array[String] = []
	for direction in WalkRenderer.WALK_DIRECTIONS:
		var frame_count: int = renderer.walk_frame_count(direction)
		if frame_count not in [8, 16]:
			await _fail("Walk gallery received an unsupported authored frame count: %s/%d" % [direction, frame_count])
			return false
		if frame_count == 16: sixteen_directions.append(direction)
		_new_gallery("八方向原稿 · %s · %d 個實際步態姿勢" % [direction, frame_count])
		var unique: Dictionary = {}
		for frame in range(frame_count):
			var pose: Texture2D = renderer.texture(WalkRenderer.DEFAULT_APPEARANCE, {"outfit": "outfit-tide", "hat": "hat-none"}, direction, frame, "walk")
			if pose == null or pose.get_image().is_empty() or _opaque_pixels(pose) < 5000:
				await _fail("Authored walk gallery pose is missing: %s/%d" % [direction, frame])
				return false
			if not _source_cell_has_clear_margin(renderer, direction, frame, 2):
				await _fail("Authored walk cel touches its atlas boundary: %s/%d" % [direction, frame])
				return false
			var base_bytes: PackedByteArray = pose.get_image().get_data()
			unique[Marshalls.raw_to_base64(base_bytes)] = true
			if frame_count == 16:
				var outfit_variant: Texture2D = renderer.texture(WalkRenderer.DEFAULT_APPEARANCE, {"outfit": "outfit-coral", "hat": "hat-none"}, direction, frame, "walk")
				var hair_variant: Dictionary = WalkRenderer.DEFAULT_APPEARANCE.duplicate(true)
				hair_variant.hair = "bob"
				var hair_pose: Texture2D = renderer.texture(hair_variant, {"outfit": "outfit-tide", "hat": "hat-straw"}, direction, frame, "walk")
				if outfit_variant == null or hair_pose == null or outfit_variant.get_size() != pose.get_size() or hair_pose.get_size() != pose.get_size():
					await _fail("Avatar identity composition disappeared for %s/%d" % [direction, frame])
					return false
				if _region_difference_count(pose, outfit_variant, Rect2i(0, 150, pose.get_width(), 210)) < 100 or _region_difference_count(pose, hair_pose, Rect2i(0, 0, pose.get_width(), 150)) < 50:
					await _fail("Outfit or head identity details do not remain visible across %s/%d" % [direction, frame])
					return false
			var columns := 4
			var cell_width := 320
			var cell_height := 168
			var column := frame % columns
			var row := int(frame / columns)
			_gallery_pose(pose, Vector2(column * cell_width + 88, row * cell_height + 28), Vector2(144, 132), "姿勢 %02d" % (frame + 1))
		if unique.size() != frame_count:
			await _fail("Native gallery did not retain all %d distinct authored cels: %s" % [frame_count, direction])
			return false
		if not await _capture_gallery("poses-%s" % direction): return false
		if frame_count == 16:
			if not await _capture_art16_gallery("poses-%s" % direction): return false
			if not await _capture_speed_comparison(direction, frame_count): return false
	if sixteen_directions.is_empty():
		print("ART-16 PILOT: no sixteen-pose direction is in the accepted manifest; ART14 eight-pose galleries remain the only captured walk evidence.")
	else:
		print("ART-16 PILOT: sixteen-pose directions=%s; total sixteen-pose coverage=%d/8, so this is not a completed 128-pose set." % [str(sixteen_directions), sixteen_directions.size()])
	for kind in ["hair", "hat", "species"]:
		var values: Array = {"hair": ["windswept", "bob", "curly"], "hat": ["hat-straw", "hat-sailor", "hat-flower"], "species": ["human", "elf", "imp"]}[kind]
		_new_gallery("八方向外觀原稿 · %s · 三種外觀 / 每列八方向" % kind)
		for row in range(3):
			for column in range(8):
				var appearance: Dictionary = WalkRenderer.DEFAULT_APPEARANCE.duplicate(true)
				var equipped := {"outfit": "outfit-tide", "hat": "hat-none"}
				if kind == "hat": equipped.hat = values[row]
				else: appearance[kind] = values[row]
				var direction: String = WalkRenderer.WALK_DIRECTIONS[column]
				var pose: Texture2D = renderer.texture(appearance, equipped, direction, 2, "walk")
				_gallery_pose(pose, Vector2(column * 160 + 20, row * 205 + 75), Vector2(120, 162), "%s\n%s" % [values[row], direction])
		if not await _capture_gallery(kind): return false
	if gallery != null:
		gallery.queue_free()
		gallery = null
	return true

func _source_cell_has_clear_margin(renderer, direction: String, frame: int, margin: int) -> bool:
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

func _opaque_pixels(texture: Texture2D) -> int:
	var image := texture.get_image()
	var count := 0
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a > 0.63: count += 1
	return count

func _region_difference_count(first: Texture2D, second: Texture2D, region: Rect2i) -> int:
	var first_image := first.get_image()
	var second_image := second.get_image()
	var count := 0
	for y in range(region.position.y, mini(region.end.y, first_image.get_height())):
		for x in range(region.position.x, mini(region.end.x, first_image.get_width())):
			if first_image.get_pixel(x, y) != second_image.get_pixel(x, y): count += 1
	return count

func _capture_speed_comparison(direction: String, frame_count: int) -> bool:
	_new_gallery("ART-16 步態速度比較 · %s · normal / slow inspection" % direction)
	var normal := TextureRect.new()
	var slow := TextureRect.new()
	for item in [normal, slow]:
		item.position = Vector2(300 if item == normal else 730, 120)
		item.size = Vector2(250, 390)
		item.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		item.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		item.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		gallery.add_child(item)
	var normal_label := Label.new()
	var slow_label := Label.new()
	for label in [normal_label, slow_label]:
		label.add_theme_font_override("font", GalleryFont)
		label.add_theme_font_size_override("font_size", 22)
		label.add_theme_color_override("font_color", Color("#243b50"))
	gallery.add_child(normal_label)
	gallery.add_child(slow_label)
	normal_label.position = Vector2(350, 535)
	slow_label.position = Vector2(775, 535)
	normal_label.text = "Normal cadence"
	slow_label.text = "Slow pose inspection"
	for sample in range(frame_count * 2):
		normal.texture = main.world.avatar_renderer.texture(WalkRenderer.DEFAULT_APPEARANCE, {"outfit": "outfit-tide", "hat": "hat-none"}, direction, sample % frame_count, "walk")
		slow.texture = main.world.avatar_renderer.texture(WalkRenderer.DEFAULT_APPEARANCE, {"outfit": "outfit-tide", "hat": "hat-none"}, direction, int(sample / 2) % frame_count, "walk")
		await get_tree().create_timer(0.12).timeout
	if not await _capture_art16_gallery("normal-slow-%s" % direction): return false
	return true

func _capture_art16_gallery(suffix: String) -> bool:
	await _frames(2)
	await RenderingServer.frame_post_draw
	if not main._capture("pm/Snapland-art/images/ART-16-%s.png" % suffix):
		await _fail("ART-16 native pose/speed-comparison screenshot failed: " + suffix)
		return false
	return true

func _new_gallery(title: String) -> void:
	if gallery != null:
		remove_child(gallery)
		gallery.queue_free()
	gallery = Control.new()
	gallery.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(gallery)
	var background := ColorRect.new()
	background.size = Vector2(1280, 720)
	background.color = Color("#eddfb6")
	gallery.add_child(background)
	var heading := Label.new()
	heading.position = Vector2(20, 10)
	heading.text = title
	heading.add_theme_font_override("font", GalleryFont)
	heading.add_theme_font_size_override("font_size", 22)
	heading.add_theme_color_override("font_color", Color("#243b50"))
	gallery.add_child(heading)

func _gallery_pose(texture: Texture2D, position: Vector2, dimensions: Vector2, caption: String) -> void:
	var image := TextureRect.new()
	image.position = position
	image.size = dimensions
	image.texture = texture
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	gallery.add_child(image)
	var label := Label.new()
	label.position = position + Vector2(0, dimensions.y)
	label.text = caption
	label.add_theme_font_override("font", GalleryFont)
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color("#243b50"))
	gallery.add_child(label)

func _capture_gallery(suffix: String) -> bool:
	await _frames(2)
	await RenderingServer.frame_post_draw
	if not main._capture("pm/Snapland-art/images/ART-14-gallery-%s.png" % suffix):
		await _fail("Eight-direction native gallery screenshot failed: " + suffix)
		return false
	return true
