extends SceneTree

const AvatarRenderer = preload("res://game/world/avatar_renderer.gd")
const RendererRegression = preload("res://game/tests/test_avatar_renderer.gd")

const DIRECTIONS := ["front", "front_right", "right", "back_right", "back", "back_left", "left", "front_left"]
const HAIRSTYLES := ["windswept", "bob", "curly"]

func _initialize() -> void:
	assert(not OS.get_environment("SNAPLAND_SAVE_PATH").is_empty(), "avatar attachment checks require an isolated SNAPLAND_SAVE_PATH")
	var renderer := AvatarRenderer.new()
	if not _check_species_component_contacts(renderer):
		quit(1)
		return
	_test_open_face_cutout_registration(renderer)
	assert(renderer.has_walk_atlas(), "all authored walk cels are available for attachment checks")
	var appearance := {"skin":"warm", "species":"human", "gender":"neutral", "hair":"windswept", "hair_color":"ink", "face":"curious"}
	var equipped := {"outfit":"outfit-tide", "hat":"hat-none"}
	for direction in DIRECTIONS:
		var count := renderer.walk_frame_count(direction)
		assert(count == 8, "%s exposes eight authored frames" % direction)
		var anchors: Array[Vector2i] = []
		for frame in range(count):
			var source := renderer._walk_pose_image(direction, frame)
			var raw_source := source.duplicate()
			var anchor: Vector2i = renderer.walk_head_anchor(direction, frame)
			assert(anchor.x >= 0 and anchor.x < source.get_width(), "%s/%d has an in-canvas measured head center" % [direction, frame])
			assert(anchor.y > 45 and anchor.y < 130, "%s/%d derives its scalp anchor from the cel instead of fixed y=45" % [direction, frame])
			anchors.append(anchor)
			var base: Texture2D = renderer.texture(appearance, equipped, direction, frame, "walk")
			assert(base != null and base.get_image().get_used_rect().size.x > 100, "%s/%d keeps the complete walk body and authored windswept hair" % [direction, frame])
			var source_metrics: Dictionary = renderer._walk_source_hair_metrics(direction, frame, raw_source)
			assert(_masked_pixel_difference_count(base.get_image(), raw_source, source_metrics.source_hair_indices) == 0, "%s/%d default ink preserves every connected authored hair pixel exactly" % [direction, frame])
			var chestnut_windswept: Texture2D = renderer.texture({"skin":"warm", "species":"human", "gender":"neutral", "hair":"windswept", "hair_color":"chestnut", "face":"curious"}, equipped, direction, frame, "walk")
			var lower_hair_tint_pixels := _masked_lower_difference_count(chestnut_windswept.get_image(), raw_source, source_metrics.source_hair_indices, roundi(float(raw_source.get_height()) * 0.42), renderer)
			assert(lower_hair_tint_pixels > 0, "%s/%d alternate windswept color reaches connected hair below the old hard cutoff (%d pixels)" % [direction, frame, lower_hair_tint_pixels])
			renderer._apply_palette(source, appearance, "outfit-tide", renderer._closest_cardinal(direction), false)
			var source_difference := _full_difference_count(base, source)
			assert(source_difference == 0, "%s/%d retains its authored windswept silhouette without a displaced overlay (%d differing pixels)" % [direction, frame, source_difference])
			var bob: Texture2D = renderer.texture({"skin":"warm", "species":"human", "hair":"bob", "hair_color":"ink", "face":"curious"}, equipped, direction, frame, "walk")
			var curly: Texture2D = renderer.texture({"skin":"warm", "species":"human", "hair":"curly", "hair_color":"ink", "face":"curious"}, equipped, direction, frame, "walk")
			assert(_assert_semantic_face(renderer,direction,frame,base,bob),"exact bob face preservation completed")
			assert(_assert_semantic_face(renderer,direction,frame,base,curly),"exact curly face preservation completed")
			if frame == 3:
				var bob_strays := _uncovered_source_hair_pixels(renderer, direction, frame, base, bob, _replacement_hair_mask(renderer, direction, frame, "bob"), anchor)
				var curly_strays := _uncovered_source_hair_pixels(renderer, direction, frame, base, curly, _replacement_hair_mask(renderer, direction, frame, "curly"), anchor)
				assert(bob_strays == 0 and curly_strays == 0, "%s/frame3 removes source windswept hair outside both replacement cuts (bob=%d, curly=%d)" % [direction, bob_strays, curly_strays])
			assert(_image_data(base) != _image_data(bob) and _image_data(bob) != _image_data(curly), "%s/%d preserves distinct source, bob, and curly appearances" % [direction, frame])
			var head_region := Rect2i(anchor.x - 90, anchor.y - 2, 180, 34)
			assert(_source_hair_pixels(renderer, bob, head_region) > 0 and _source_hair_pixels(renderer, curly, head_region) > 0, "%s/%d keeps each replacement hair attached near the measured scalp" % [direction, frame])
			if frame == attachment_frame_for_test(renderer, direction):
				var measured_width := renderer.walk_head_width(direction, frame)
				var bob_delta := _difference_bounds(base, bob)
				var curly_delta := _difference_bounds(base, curly)
				var allowed_width := roundi(float(measured_width) * 1.55)
				var allowed_height := roundi(float(measured_width) * 2.0)
				assert(measured_width > 25 and bob_delta.size.x <= allowed_width and curly_delta.size.x <= allowed_width, "%s attaches alternate cuts at the measured head width without oversized spill" % direction)
				assert(bob_delta.size.y <= allowed_height and curly_delta.size.y <= allowed_height, "%s keeps bob and curl silhouette within a head-scaled length" % direction)
			for style in HAIRSTYLES:
				var ink: Texture2D = renderer.texture({"skin":"warm", "species":"human", "hair":style, "hair_color":"ink", "face":"curious"}, equipped, direction, frame, "walk")
				var chestnut: Texture2D = renderer.texture({"skin":"warm", "species":"human", "hair":style, "hair_color":"chestnut", "face":"curious"}, equipped, direction, frame, "walk")
				assert(_region_difference_count(ink, chestnut, Rect2i(anchor.x - 85, anchor.y - 5, 170, 190)) > 20, "%s/%d maps %s hair color instead of retaining the source palette" % [direction, frame, style])
		assert(anchors.size() == count, "%s measured every authored frame" % direction)
		var attachment_frame := renderer.walk_idle_frame(direction)
		var anchor: Vector2i = renderer.walk_head_anchor(direction, attachment_frame)
		var base: Texture2D = renderer.texture(appearance, equipped, direction, attachment_frame, "walk")
		var hat: Texture2D = renderer.texture(appearance, {"outfit":"outfit-tide", "hat":"hat-straw"}, direction, attachment_frame, "walk")
		assert(_region_difference_count(base, hat, Rect2i(anchor.x - 90, anchor.y - 24, 180, 72)) > 0, "%s places the hat change within the measured head attachment area" % direction)
		for species in ["elf", "imp"]:
			var species_appearance := appearance.duplicate(true)
			species_appearance["species"] = species
			var species_pose: Texture2D = renderer.texture(species_appearance, equipped, direction, attachment_frame, "walk")
			assert(species_pose != null and species_pose.get_image().get_used_rect().size.x > 100, "%s retains the complete %s walk pose" % [direction, species])
	assert(renderer.cached_texture_count() <= renderer.CACHE_LIMIT, "attachment combinations remain inside the bounded avatar cache")
	_benchmark_walk_attachment_caches()
	print("PASS: measured walk head attachments")
	quit(0)

func _check_species_component_contacts(renderer) -> bool:
	for direction in DIRECTIONS:
		for frame in range(8):
			for style in HAIRSTYLES:
				var appearance := {"skin":"warm","species":"human","hair":style,"hair_color":"ink","face":"curious"}
				var equipment := {"outfit":"outfit-tide","hat":"hat-none"}
				var human: Image = renderer.texture(appearance,equipment,direction,frame,"walk").get_image()
				var anchor: Vector2i = renderer.walk_head_anchor(direction,frame)
				var metrics: Dictionary = renderer._walk_source_hair_metrics(direction,frame,renderer._walk_pose_image(direction,frame))
				for species in ["imp","elf"]:
					appearance.species = species
					var candidate: Image = renderer.texture(appearance,equipment,direction,frame,"walk").get_image()
					for index in metrics.face_indices:
						var point := Vector2i(index%human.get_width(),index/human.get_width())
						if human.get_pixelv(point).a>0.63 and candidate.get_pixelv(point)!=human.get_pixelv(point):
							push_error("%s/%d/%s/%s alters an authored face pixel at %s" % [direction,frame,style,species,point])
							return false
					var components := _added_species_components(human,candidate,anchor)
					var expected := 1 if direction in ["left","right"] else 2
					if components.size()<expected:
						push_error("%s/%d/%s/%s: expected %d visible accessory components, got %d" % [direction,frame,style,species,expected,components.size()])
						return false
					for component: PackedInt32Array in components:
						var contacts := 0
						for index in component:
							var x := index % human.get_width()
							var y := index / human.get_width()
							var touches := false
							for dy in range(-1,2):
								for dx in range(-1,2):
									var point := Vector2i(x+dx,y+dy)
									if point.x<0 or point.x>=human.get_width() or point.y<0 or point.y>=human.get_height(): continue
									var base := human.get_pixelv(point)
									var hue_distance := absf(base.h-AvatarRenderer.HAIR_COLORS.ink.h)
									var hair: bool = (base.s>0.15 and minf(hue_distance,1.0-hue_distance)<0.065) or renderer._is_source_hair(base)
									if base.a>0.63 and (hair if species=="imp" else (hair or _is_warm_skin(base))): touches = true
							if touches: contacts += 1
						if contacts<3:
							push_error("%s/%d/%s/%s: opaque accessory component floats (%d strong head contacts)" % [direction,frame,style,species,contacts])
							return false
	print("PASS: 64cels x3styles horn/ear opaque component contacts")
	return true

func _added_species_components(base: Image, candidate: Image, anchor: Vector2i) -> Array[PackedInt32Array]:
	var width := base.get_width()
	var marked := PackedByteArray()
	marked.resize(width*base.get_height())
	for y in range(mini(base.get_height(),anchor.y+110)):
		for x in range(width):
			if candidate.get_pixel(x,y).a>0.63 and candidate.get_pixel(x,y)!=base.get_pixel(x,y): marked[y*width+x] = 1
	var result: Array[PackedInt32Array] = []
	for seed in range(marked.size()):
		if marked[seed]==0: continue
		var queue := PackedInt32Array([seed])
		marked[seed] = 0
		var cursor := 0
		while cursor<queue.size():
			var index := queue[cursor]
			cursor += 1
			var x := index%width
			var y := index/width
			for dy in range(-1,2):
				for dx in range(-1,2):
					var point := Vector2i(x+dx,y+dy)
					if point.x<0 or point.x>=width or point.y<0 or point.y>=base.get_height(): continue
					var neighbor := point.y*width+point.x
					if marked[neighbor]!=0:
						marked[neighbor] = 0
						queue.append(neighbor)
		if queue.size()>4: result.append(queue)
	return result

func _benchmark_walk_attachment_caches() -> void:
	var renderer := AvatarRenderer.new()
	var first_started := Time.get_ticks_usec()
	_render_walk_attachment_grid(renderer, "outfit-tide")
	var first_elapsed := Time.get_ticks_usec() - first_started
	assert(renderer._walk_source_image_cache.size() == 64 and renderer._walk_source_image_build_count == 64, "all 64 normalized walk cels are prepared once and read from immutable cached copies")
	assert(renderer._walk_source_metrics_cache.size() == 64 and renderer._source_metrics_build_count == 64, "the 64 authored walk cels build source hair/face metrics once")
	assert(renderer._hair_cut_cache.size() == 16 and renderer._hair_cut_build_count == 16, "the 16 bob/curly cardinal and diagonal cuts are each preprocessed once")
	var source_builds := renderer._source_metrics_build_count
	var cut_builds := renderer._hair_cut_build_count
	var second_started := Time.get_ticks_usec()
	_render_walk_attachment_grid(renderer, "outfit-coral")
	var second_elapsed := Time.get_ticks_usec() - second_started
	assert(renderer._source_metrics_build_count == source_builds and renderer._hair_cut_build_count == cut_builds, "a second full walk grid does not rescan immutable cel masks or hairstyle cuts")
	assert(renderer._walk_source_image_build_count == 64, "the repeat grid does not extract or resize walk cels again")
	assert(renderer._walk_source_image_cache.size() <= 64 and renderer._walk_source_metrics_cache.size() <= 64 and renderer._hair_cut_cache.size() <= 24, "immutable geometry caches remain strictly bounded")
	print("CACHE_BENCH 64celsx3styles first_ms=%d repeat_ms=%d source_metrics=%d haircuts=%d" % [roundi(float(first_elapsed) / 1000.0), roundi(float(second_elapsed) / 1000.0), source_builds, cut_builds])

func _render_walk_attachment_grid(renderer, outfit: String) -> void:
	for direction in DIRECTIONS:
		for frame in range(8):
			for style in HAIRSTYLES:
				renderer.texture({"skin":"warm", "species":"human", "gender":"neutral", "hair":style, "hair_color":"ink", "face":"curious"}, {"outfit":outfit, "hat":"hat-none"}, direction, frame, "walk")

func _image_data(texture: Texture2D) -> PackedByteArray:
	return texture.get_image().get_data()

func _region_difference_count(first: Texture2D, second: Texture2D, region: Rect2i) -> int:
	var a := first.get_image()
	var b := second.get_image()
	var count := 0
	var clipped := region.intersection(Rect2i(Vector2i.ZERO, Vector2i(a.get_width(), a.get_height())))
	for y in range(clipped.position.y, clipped.end.y):
		for x in range(clipped.position.x, clipped.end.x):
			if a.get_pixel(x, y) != b.get_pixel(x, y):
				count += 1
	return count

func _difference_bounds(first: Texture2D, second: Texture2D) -> Rect2i:
	var a := first.get_image()
	var b := second.get_image()
	var left := a.get_width()
	var top := a.get_height()
	var right := -1
	var bottom := -1
	for y in range(a.get_height()):
		for x in range(a.get_width()):
			if a.get_pixel(x, y) != b.get_pixel(x, y):
				left = mini(left, x)
				top = mini(top, y)
				right = maxi(right, x)
				bottom = maxi(bottom, y)
	return Rect2i(left, top, right - left + 1, bottom - top + 1) if right >= left and bottom >= top else Rect2i()

func _full_difference_count(texture: Texture2D, image: Image) -> int:
	var rendered := texture.get_image()
	var count := 0
	for y in range(rendered.get_height()):
		for x in range(rendered.get_width()):
			if rendered.get_pixel(x, y) != image.get_pixel(x, y):
				count += 1
	return count

func _masked_pixel_difference_count(candidate: Image, reference: Image, indices: PackedInt32Array) -> int:
	var count := 0
	var width := reference.get_width()
	for index in indices:
		if candidate.get_pixel(index % width, index / width) != reference.get_pixel(index % width, index / width):
			count += 1
	return count

func _masked_lower_difference_count(candidate: Image, reference: Image, indices: PackedInt32Array, cutoff_y: int, renderer) -> int:
	var count := 0
	var width := reference.get_width()
	for index in indices:
		var x := index % width
		var y := index / width
		var source_pixel := reference.get_pixel(x, y)
		if y >= cutoff_y and renderer._is_source_hair(source_pixel) and candidate.get_pixel(x, y) != source_pixel:
			count += 1
	return count

func _source_hair_pixels(renderer, texture: Texture2D, region: Rect2i) -> int:
	var image := texture.get_image()
	var clipped := region.intersection(Rect2i(Vector2i.ZERO, Vector2i(image.get_width(), image.get_height())))
	var count := 0
	for y in range(clipped.position.y, clipped.end.y):
		for x in range(clipped.position.x, clipped.end.x):
			if renderer._is_source_hair(image.get_pixel(x, y)):
				count += 1
	return count

func _assert_semantic_face(renderer,direction: String,frame: int,reference: Texture2D,candidate: Texture2D) -> bool:
	# RED before this migration: front/0 failed the old 92%-of-skin rectangle
	# assertion. That scalp-anchor rectangle included the old cream fringe and
	# its shadow, while the 4px near-skin mark helper classified its brown ink
	# as an eye/brow. Keeping those pixels recreates the native rejected forehead
	# (front_right0 x155/y131, x161/y146). Preserve 100% of semantic facial RGBA
	# for every cel, plus independent raw-cel witnesses and mandatory fringe
	# removal, instead of lowering the old percentage or ignoring the failure.
	var raw: Image = renderer._walk_pose_image(direction,frame)
	var metrics: Dictionary = renderer._walk_source_hair_metrics(direction,frame,raw)
	var expected: Image = reference.get_image()
	var actual: Image = candidate.get_image()
	var eyes := 0
	for label: String in metrics.face_features_named:
		if label.begins_with("eye_"): eyes+=1
		for index in metrics.face_features_named[label]:
			var point := Vector2i(index%raw.get_width(),index/raw.get_width())
			assert(actual.get_pixelv(point)==expected.get_pixelv(point),"every authored semantic eye/brow/mouth/ear RGBA stays exact: %s/%d/%s" % [direction,frame,label])
	var visible_eyes := 0 if direction.begins_with("back") else (1 if direction=="right" or direction=="left" else 2)
	assert(eyes==visible_eyes,"all64cels preserve actual visible eyes, not hair highlights")
	if frame==0 and RendererRegression.FEATURES.has(direction):
		for point: Vector2i in RendererRegression.FEATURES[direction]: assert(actual.get_pixelv(point)==expected.get_pixelv(point),"independently inspected original feature RGBA remains exact: "+str(point))
	if direction=="front_right" and frame==0:
		for point in [Vector2i(155,131),Vector2i(161,146),Vector2i(188,117)]:
			assert(metrics.face_mask[point.y*280+point.x]==0 and metrics.replacement_source_mask[point.y*280+point.x]!=0,"old brown/cream fringe is owned by replacement, never restored as a face feature")
	return true

func _skin_pixels(texture: Texture2D, region: Rect2i) -> int:
	var image := texture.get_image()
	var clipped := region.intersection(Rect2i(Vector2i.ZERO, Vector2i(image.get_width(), image.get_height())))
	var count := 0
	for y in range(clipped.position.y, clipped.end.y):
		for x in range(clipped.position.x, clipped.end.x):
			if image.get_pixel(x, y).a > 0.4 and _is_warm_skin(image.get_pixel(x, y)):
				count += 1
	return count

func _preserved_skin_pixels(reference: Texture2D, candidate: Texture2D, region: Rect2i) -> int:
	var reference_image := reference.get_image()
	var candidate_image := candidate.get_image()
	var clipped := region.intersection(Rect2i(Vector2i.ZERO, Vector2i(reference_image.get_width(), reference_image.get_height())))
	var count := 0
	for y in range(clipped.position.y, clipped.end.y):
		for x in range(clipped.position.x, clipped.end.x):
			var expected := reference_image.get_pixel(x, y)
			if expected.a > 0.4 and _is_warm_skin(expected) and candidate_image.get_pixel(x, y) == expected:
				count += 1
	return count

func _face_mark_pixels(renderer, reference: Texture2D, region: Rect2i, candidate: Variant) -> int:
	var image := reference.get_image()
	var candidate_image: Image = candidate.get_image() if candidate is Texture2D else image
	var clipped := region.intersection(Rect2i(Vector2i.ZERO, Vector2i(image.get_width(), image.get_height())))
	var count := 0
	for y in range(clipped.position.y, clipped.end.y):
		for x in range(clipped.position.x, clipped.end.x):
			var mark := image.get_pixel(x, y)
			if mark.a <= 0.4 or mark.v > 0.22 or renderer._is_source_hair(mark):
				continue
			var near_skin := false
			for near_y in range(maxi(clipped.position.y, y - 4), mini(clipped.end.y, y + 5)):
				for near_x in range(maxi(clipped.position.x, x - 4), mini(clipped.end.x, x + 5)):
					if _is_warm_skin(image.get_pixel(near_x, near_y)):
						near_skin = true
						break
				if near_skin: break
			if near_skin and candidate_image.get_pixel(x, y) == mark:
				count += 1
	return count

func _is_warm_skin(color: Color) -> bool:
	var reference := Color("#e8b991")
	var distance := absf(color.h - reference.h)
	return minf(distance, 1.0 - distance) < 0.055 and color.s > 0.2 and color.v > 0.25

func attachment_frame_for_test(renderer, direction: String) -> int:
	return renderer.walk_idle_frame(direction)

func _replacement_hair_mask(renderer, direction: String, frame: int, style: String) -> Image:
	var mask := Image.create(280, 360, false, Image.FORMAT_RGBA8)
	mask.fill(Color.TRANSPARENT)
	var anchor: Vector2i = renderer.walk_head_anchor(direction, frame)
	var target_width := float(renderer.walk_head_width(direction, frame)) * 1.05
	var shift := anchor.x - mask.get_width() / 2
	var hair_color: Color = AvatarRenderer.HAIR_COLORS.ink
	var source: Image = renderer._walk_pose_image(direction,frame)
	var overlay_metrics: Dictionary = renderer._walk_source_hair_metrics(direction,frame,source).duplicate()
	overlay_metrics.erase("skull_underlay_indices")
	if AvatarRenderer.DIRECTIONS.has(direction):
		renderer._apply_hair_atlas(mask,style,direction,hair_color,anchor.y,shift,target_width,source,overlay_metrics)
	else:
		renderer._apply_diagonal_hair(mask,style,direction,hair_color,anchor.y,shift,target_width,source,overlay_metrics)
	return mask

func _uncovered_source_hair_pixels(renderer, direction: String, frame: int, source: Texture2D, candidate: Texture2D, overlay_mask: Image, anchor: Vector2i) -> int:
	var source_image := source.get_image()
	var candidate_image := candidate.get_image()
	var raw: Image = renderer._walk_pose_image(direction, frame)
	var source_hair_mask: PackedByteArray = renderer._walk_source_hair_metrics(direction, frame, raw).source_hair_mask
	var rect := Rect2i(anchor.x - 115, anchor.y - 18, 230, 112).intersection(Rect2i(Vector2i.ZERO, Vector2i(280, 360)))
	var count := 0
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var original := source_image.get_pixel(x, y)
			if source_hair_mask[y * source_image.get_width() + x] != 0 and candidate_image.get_pixel(x, y) == original and overlay_mask.get_pixel(x, y).a < 0.05:
				count += 1
	return count

func _test_open_face_cutout_registration(renderer) -> void:
	# A deliberately off-center face opening must register by its opening,
	# rather than the whole cut's crown center. This catches the old wig offset.
	var hair := Image.create(100, 100, false, Image.FORMAT_RGBA8)
	hair.fill(Color("#293b50"))
	for y in range(35, 100):
		for x in range(15, 50): hair.set_pixel(x, y, Color.TRANSPARENT)
	var opening: Rect2i = renderer._hair_face_opening(hair)
	assert(opening.position == Vector2i(15, 35) and opening.size.x == 35, "an open-bottom face hole is measured independently of crown center")
	var source := Image.create(280, 360, false, Image.FORMAT_RGBA8)
	source.fill(Color.TRANSPARENT)
	for y in range(70, 150):
		for x in range(70, 220): source.set_pixel(x, y, Color("#2a2b48"))
	for y in range(105, 145):
		for x in range(100, 145): source.set_pixel(x, y, Color("#fdbb7b"))
	var canvas := Image.create(280, 360, false, Image.FORMAT_RGBA8)
	canvas.fill(Color.TRANSPARENT)
	renderer._blend_registered_hair(canvas, hair, "front", 70, 0, 112.0, source)
	assert(canvas.get_used_rect().size.x >= 150, "source head scale is retained even when an old 112px target is supplied")
	assert(canvas.get_pixel(122, 122).a < 0.1, "the off-center cutout exposes the authored face center")
