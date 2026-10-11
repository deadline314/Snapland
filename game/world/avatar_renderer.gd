extends RefCounted
## Builds cached, nearest-filtered avatar poses from the authored action atlas.
## The fallback keeps the wardrobe usable when a packaged atlas is unavailable.

const ATLAS_PATH := "res://assets/characters/traveller-actions-v1.png"
const CACHE_LIMIT := 128
const DIRECTIONS := ["front", "left", "back", "right"]
const ACTIONS := ["wave", "photograph", "interact", "celebrate"]
const SOURCE_SIZE := Vector2i(1122, 1402)
const HAT_ATLAS_PATH := "res://assets/characters/hats-v1.png"
const HAT_SOURCE_SIZE := Vector2i(1217, 1293)
const SPECIES_ATLAS_PATH := "res://assets/characters/species-parts-v1.png"
const SPECIES_SOURCE_SIZE := Vector2i(1536, 1024)
const ELF_EAR_REGIONS := [Rect2i(98, 114, 256, 309), Rect2i(463, 114, 256, 309), Rect2i(875, 93, 169, 342), Rect2i(1261, 93, 168, 342)]
const IMP_HORN_REGIONS := [Rect2i(117, 627, 198, 263), Rect2i(485, 561, 250, 347), Rect2i(866, 627, 187, 258), Rect2i(1244, 561, 191, 347)]
const HAT_TARGET_WIDTHS := [200.0, 158.0, 38.0]
const HAT_VERTICAL_SCALE := [0.40, 0.55, 1.0]
const HAT_CROWN_OFFSETS := [-5.0, -5.0, 5.0]
const HAIR_ATLAS_PATH := "res://assets/characters/hair-v1.png"
const HAIR_SOURCE_SIZE := Vector2i(1448, 1086)
const HAIR_REGIONS := [
	[Rect2i(26, 75, 345, 292), Rect2i(398, 75, 317, 302), Rect2i(745, 69, 327, 310), Rect2i(1100, 77, 323, 301)],
	[Rect2i(34, 404, 315, 262), Rect2i(397, 409, 303, 255), Rect2i(750, 404, 310, 266), Rect2i(1111, 408, 299, 254)],
	[Rect2i(16, 686, 362, 340), Rect2i(400, 690, 313, 338), Rect2i(734, 690, 340, 344), Rect2i(1094, 690, 315, 341)],
]
const HAIR_TARGET_WIDTH := 190.0
const HAT_REGIONS := [
	[Rect2i(5, 242, 316, 213), Rect2i(334, 242, 281, 221), Rect2i(622, 242, 316, 214), Rect2i(939, 242, 269, 226)],
	[Rect2i(39, 599, 252, 156), Rect2i(374, 598, 217, 163), Rect2i(651, 598, 242, 173), Rect2i(953, 598, 215, 163)],
	[Rect2i(93, 923, 185, 160), Rect2i(403, 913, 156, 168), Rect2i(673, 914, 170, 162), Rect2i(1012, 923, 122, 163)],
]
const POSE_REGIONS := [
	Rect2i(64, 12, 202, 347), Rect2i(330, 19, 196, 339), Rect2i(588, 19, 194, 339), Rect2i(847, 15, 198, 343),
	Rect2i(62, 363, 195, 339), Rect2i(323, 368, 195, 332), Rect2i(588, 366, 200, 340), Rect2i(854, 366, 201, 338),
	Rect2i(65, 702, 198, 337), Rect2i(328, 705, 193, 333), Rect2i(587, 708, 198, 335), Rect2i(858, 705, 201, 333),
	Rect2i(39, 1035, 200, 339), Rect2i(323, 1037, 191, 337), Rect2i(586, 1065, 220, 309), Rect2i(849, 1039, 237, 335),
]
const CANVAS_SIZE := Vector2i(280, 360)
const FEET_BASELINE := 346
const DEFAULT_APPEARANCE := {
	"skin": "warm", "species": "human", "gender": "neutral",
	"hair": "windswept", "hair_color": "ink", "face": "curious",
}
const SKIN_COLORS := {
	"warm": Color("#e8b991"), "deep": Color("#79503e"), "bronze": Color("#b87950"),
	"cool": Color("#f0d6c2"), "olive": Color("#b08c61"),
}
const HAIR_COLORS := {
	"ink": Color("#293b50"), "chestnut": Color("#76503d"), "silver": Color("#abb6b8"),
}
const OUTFIT_COLORS := {
	"outfit-tide": Color("#4b9bb0"), "outfit-coral": Color("#e87968"),
	"outfit-gold": Color("#d8ab47"), "outfit-navy": Color("#364d78"),
}

var _atlas: Texture2D
var _atlas_image: Image
var _hat_atlas_image: Image
var _hat_atlas_valid := false
var _species_atlas_image: Image
var _species_atlas_valid := false
var _hair_atlas_image: Image
var _hair_atlas_valid := false
var _cell_width := 0
var _cell_height := 0
var _canvas_width := 280
var _canvas_height := 360
var _pose_visible_bottoms: Array[int] = []
var _pose_vertical_offsets: Array[int] = []
var _atlas_valid := false
var _cache: Dictionary = {}
var _cache_order: Array[String] = []
var _warned_missing := false

func _init() -> void:
	_load_atlas()

func pose_height() -> int:
	return _canvas_height if _atlas_valid else 96

func is_asset_ready() -> bool:
	return _atlas_valid

func has_hat_atlas() -> bool:
	return _hat_atlas_valid

func has_species_atlas() -> bool:
	return _species_atlas_valid

func has_hair_atlas() -> bool:
	return _hair_atlas_valid

func cached_texture_count() -> int:
	return _cache.size()

func texture(appearance: Dictionary, equipped: Dictionary, direction: String = "front", frame: int = 0, action: String = "idle") -> Texture2D:
	var safe_direction := direction if DIRECTIONS.has(direction) else "front"
	var safe_action := action if ACTIONS.has(action) else "idle"
	var safe_frame := clampi(frame, 0, 2)
	var normalized_appearance := DEFAULT_APPEARANCE.duplicate()
	for key in DEFAULT_APPEARANCE:
		if appearance.has(key): normalized_appearance[key] = str(appearance[key])
	var outfit := str(equipped.get("outfit", "outfit-tide"))
	var hat := str(equipped.get("hat", "hat-none"))
	var pose := _pose_index(safe_direction, safe_frame, safe_action)
	var render_appearance := normalized_appearance.duplicate()
	render_appearance.erase("gender")
	var key := "%s|%s|%s" % [JSON.stringify(render_appearance), outfit + ":" + hat, str(pose)]
	if _cache.has(key): return _cache[key]
	var image := _atlas_pose_image(pose) if _atlas_valid else _fallback_image(safe_direction, safe_frame, safe_action)
	var vertical_offset := _pose_vertical_offsets[pose] if _atlas_valid else 0
	var species := str(normalized_appearance.get("species", "human"))
	if _hair_atlas_valid: _strip_source_hair(image, safe_direction)
	if species == "elf" and _species_atlas_valid:
		var ear_layer := Image.create(image.get_width(), image.get_height(), false, Image.FORMAT_RGBA8)
		ear_layer.fill(Color.TRANSPARENT)
		_apply_species_ears(ear_layer, species, safe_direction, vertical_offset, SKIN_COLORS.get(str(normalized_appearance.get("skin", "warm")), SKIN_COLORS.warm))
		ear_layer.blend_rect(image, Rect2i(Vector2i.ZERO, Vector2i(image.get_width(), image.get_height())), Vector2i.ZERO)
		image = ear_layer
	if _hair_atlas_valid:
		_apply_hair_atlas(image, str(normalized_appearance.get("hair", "windswept")), safe_direction, HAIR_COLORS.get(str(normalized_appearance.get("hair_color", "ink")), HAIR_COLORS.ink), vertical_offset)
	_apply_palette(image, normalized_appearance, outfit, safe_direction)
	_apply_appearance_details(image, normalized_appearance, safe_direction, safe_action)
	_apply_species_horns(image, species, safe_direction, vertical_offset)
	_apply_hat(image, hat, safe_direction, vertical_offset)
	var result := ImageTexture.create_from_image(image)
	_cache[key] = result
	_cache_order.append(key)
	while _cache_order.size() > CACHE_LIMIT:
		_cache.erase(_cache_order.pop_front())
	return result

func _load_atlas() -> void:
	if not ResourceLoader.exists(ATLAS_PATH):
		if not _warned_missing:
			push_warning("Avatar action atlas '%s' is missing; using a clear built-in fallback." % ATLAS_PATH)
			_warned_missing = true
		return
	_atlas = load(ATLAS_PATH) as Texture2D
	if _atlas == null:
		push_warning("Avatar action atlas '%s' could not be loaded; using a clear built-in fallback." % ATLAS_PATH)
		return
	_atlas_image = _atlas.get_image()
	var width := _atlas_image.get_width()
	var height := _atlas_image.get_height()
	if width < SOURCE_SIZE.x or height < SOURCE_SIZE.y:
		push_warning("Avatar action atlas is smaller than its pose metadata (%d x %d); using fallback." % [width, height])
		return
	var scale_x := float(width) / SOURCE_SIZE.x
	var scale_y := float(height) / SOURCE_SIZE.y
	if absf(scale_x - scale_y) > 0.015:
		push_warning("Avatar action atlas was resized nonuniformly; using fallback to preserve sprite proportions.")
		return
	_canvas_width = roundi(CANVAS_SIZE.x * scale_x)
	_canvas_height = roundi(CANVAS_SIZE.y * scale_y)
	for pose in range(POSE_REGIONS.size()):
		var region: Rect2i = _scaled_region(POSE_REGIONS[pose], scale_x, scale_y)
		if region.position.x < 0 or region.position.y < 0 or region.end.x > width or region.end.y > height:
			push_warning("Avatar pose %d region %s exceeds atlas bounds; using fallback." % [pose, str(region)])
			return
		var has_center_ink := false
		for y in range(region.position.y + region.size.y / 3, region.position.y + region.size.y * 2 / 3):
			for x in range(region.position.x + region.size.x / 3, region.position.x + region.size.x * 2 / 3):
				if _atlas_image.get_pixel(x, y).a > 0.63:
					has_center_ink = true
					break
			if has_center_ink: break
		if not has_center_ink:
			push_warning("Avatar pose %d has no central opaque pixels; using fallback." % pose)
			return
		var visible_bottom := -1
		for y in range(region.size.y):
			for x in range(region.size.x):
				if _atlas_image.get_pixel(region.position.x + x, region.position.y + y).a > 0.4:
					visible_bottom = maxi(visible_bottom, y)
		if visible_bottom < region.size.y * 0.55:
			push_warning("Avatar pose %d has no lower-body pixels for foot alignment; using fallback." % pose)
			return
		_pose_visible_bottoms.append(visible_bottom)
		_pose_vertical_offsets.append(roundi(FEET_BASELINE * scale_y) - visible_bottom)
		for x in range(region.position.x, region.end.x):
			for y in [region.position.y, region.end.y - 1]:
				if _atlas_image.get_pixel(x, y).a > 0.63:
					push_warning("Avatar pose %d touches its metadata boundary and may be clipped; using fallback." % pose)
					return
		for y in range(region.position.y, region.end.y):
			for x in [region.position.x, region.end.x - 1]:
				if _atlas_image.get_pixel(x, y).a > 0.63:
					push_warning("Avatar pose %d touches its metadata boundary and may be clipped; using fallback." % pose)
					return
	_atlas_valid = true
	_load_hat_atlas()
	_load_hair_atlas()
	_load_species_atlas()

func _load_hat_atlas() -> void:
	if not ResourceLoader.exists(HAT_ATLAS_PATH):
		push_warning("Avatar hat atlas '%s' is missing; using the recognizable built-in hat overlay." % HAT_ATLAS_PATH)
		return
	var texture := load(HAT_ATLAS_PATH) as Texture2D
	if texture == null:
		push_warning("Avatar hat atlas '%s' could not be loaded; using the built-in hat overlay." % HAT_ATLAS_PATH)
		return
	_hat_atlas_image = texture.get_image()
	if _hat_atlas_image.get_width() < HAT_SOURCE_SIZE.x or _hat_atlas_image.get_height() < HAT_SOURCE_SIZE.y:
		push_warning("Avatar hat atlas is smaller than its region metadata; using pixel hat overlays.")
		return
	for row in HAT_REGIONS:
		for region: Rect2i in row:
			if region.end.x > _hat_atlas_image.get_width() or region.end.y > _hat_atlas_image.get_height():
				push_warning("Avatar hat atlas region %s exceeds image bounds; using pixel hat overlays." % str(region))
				return
			var has_ink := false
			for y in range(region.position.y, region.end.y):
				for x in range(region.position.x, region.end.x):
					if _hat_atlas_image.get_pixel(x, y).a > 0.63:
						has_ink = true
						break
				if has_ink: break
			if not has_ink:
				push_warning("Avatar hat atlas region %s is empty; using pixel hat overlays." % str(region))
				return
	_hat_atlas_valid = true

func _scaled_region(region: Rect2i, scale_x: float, scale_y: float) -> Rect2i:
	return Rect2i(roundi(region.position.x * scale_x), roundi(region.position.y * scale_y), roundi(region.size.x * scale_x), roundi(region.size.y * scale_y))

func _pose_index(direction: String, frame: int, action: String) -> int:
	if action != "idle": return 12 + ACTIONS.find(action)
	var column := DIRECTIONS.find(direction)
	if frame <= 0: return column
	return (1 if frame % 2 == 1 else 2) * 4 + column

func _atlas_pose_image(pose: int) -> Image:
	var scale_x := float(_atlas_image.get_width()) / SOURCE_SIZE.x
	var scale_y := float(_atlas_image.get_height()) / SOURCE_SIZE.y
	var region: Rect2i = _scaled_region(POSE_REGIONS[pose], scale_x, scale_y)
	var image := Image.create(_canvas_width, _canvas_height, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var offset_x := _canvas_width / 2 - region.size.x / 2
	var offset_y := roundi(FEET_BASELINE * scale_y) - _pose_visible_bottoms[pose]
	for y in range(region.size.y):
		for x in range(region.size.x):
			var color := _atlas_image.get_pixel(region.position.x + x, region.position.y + y)
			if color.a < 0.4: continue
			var target_x := offset_x + x
			var target_y := offset_y + y
			if target_x >= 0 and target_x < _canvas_width and target_y >= 0 and target_y < _canvas_height:
				image.set_pixel(target_x, target_y, color)
	return image

func _apply_palette(image: Image, appearance: Dictionary, outfit_id: String, direction: String) -> void:
	var skin_target: Color = SKIN_COLORS.get(str(appearance.get("skin", "warm")), SKIN_COLORS.warm)
	var hair_target: Color = HAIR_COLORS.get(str(appearance.get("hair_color", "ink")), HAIR_COLORS.ink)
	var coat_target: Color = OUTFIT_COLORS.get(outfit_id, OUTFIT_COLORS["outfit-tide"])
	var skin_source := Color("#fdbb7b")
	var hair_source := Color("#2a2b48")
	var coat_source := Color("#267e83")
	var hair_bottom := image.get_height() * 0.43
	var face_left := image.get_width() * 0.30
	var face_right := image.get_width() * 0.70
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var color := image.get_pixel(x, y)
			if color.a < 0.05: continue
			if _is_color_family(color, skin_source, 0.03, 0.42):
				image.set_pixel(x, y, _shade_preserving(color, skin_source, skin_target))
			elif _is_color_family(color, coat_source, 0.055, 0.22):
				image.set_pixel(x, y, _shade_preserving(color, coat_source, coat_target))
			elif not _hair_atlas_valid and y < hair_bottom and (direction == "back" or y < image.get_height() * 0.22 or x < face_left or x > face_right) and _is_dark_blue(color, hair_source):
				image.set_pixel(x, y, _shade_preserving(color, hair_source, hair_target))

func _is_color_family(color: Color, reference: Color, tolerance: float, minimum_value: float) -> bool:
	var distance := absf(color.h - reference.h)
	return minf(distance, 1.0 - distance) < tolerance and color.s > 0.2 and color.v > minimum_value

func _is_dark_blue(color: Color, reference: Color) -> bool:
	var distance := absf(color.h - reference.h)
	return color.v >= 0.17 and color.v < 0.52 and color.s > 0.18 and minf(distance, 1.0 - distance) < 0.065

func _load_hair_atlas() -> void:
	if not ResourceLoader.exists(HAIR_ATLAS_PATH):
		push_warning("Avatar hair atlas '%s' is missing; using the source hairstyle fallback." % HAIR_ATLAS_PATH)
		return
	var texture := load(HAIR_ATLAS_PATH) as Texture2D
	if texture == null:
		push_warning("Avatar hair atlas '%s' could not be loaded; using the source hairstyle fallback." % HAIR_ATLAS_PATH)
		return
	_hair_atlas_image = texture.get_image()
	if _hair_atlas_image.get_width() < HAIR_SOURCE_SIZE.x or _hair_atlas_image.get_height() < HAIR_SOURCE_SIZE.y:
		push_warning("Avatar hair atlas is smaller than its region metadata; using the source hairstyle fallback.")
		return
	for row in HAIR_REGIONS:
		for region: Rect2i in row:
			if region.end.x > _hair_atlas_image.get_width() or region.end.y > _hair_atlas_image.get_height():
				push_warning("Avatar hair region %s exceeds image bounds; using the source hairstyle fallback." % str(region))
				return
			var has_ink := false
			for y in range(region.position.y, region.end.y):
				for x in range(region.position.x, region.end.x):
					if _hair_atlas_image.get_pixel(x, y).a > 0.63:
						has_ink = true
						break
				if has_ink: break
			if not has_ink:
				push_warning("Avatar hair region %s is empty; using the source hairstyle fallback." % str(region))
				return
	_hair_atlas_valid = true

func _load_species_atlas() -> void:
	if ResourceLoader.exists(SPECIES_ATLAS_PATH):
		var imported_texture := load(SPECIES_ATLAS_PATH) as Texture2D
		if imported_texture != null:
			_species_atlas_image = imported_texture.get_image()
	if _species_atlas_image == null or _species_atlas_image.is_empty():
		if not FileAccess.file_exists(SPECIES_ATLAS_PATH):
			push_warning("Avatar species-parts resource '%s' is unavailable; human appearance remains available." % SPECIES_ATLAS_PATH)
			return
		_species_atlas_image = Image.new()
		var load_error := _species_atlas_image.load(SPECIES_ATLAS_PATH)
		if load_error != OK or _species_atlas_image.is_empty():
			push_warning("Avatar species-parts resource '%s' could not be loaded from import or source PNG; human appearance remains available." % SPECIES_ATLAS_PATH)
			return
	if _species_atlas_image.get_width() < SPECIES_SOURCE_SIZE.x or _species_atlas_image.get_height() < SPECIES_SOURCE_SIZE.y:
		push_warning("Avatar species-parts atlas is smaller than its region metadata; species overlays are disabled.")
		return
	for region: Rect2i in ELF_EAR_REGIONS + IMP_HORN_REGIONS:
		if region.position.x < 0 or region.position.y < 0 or region.end.x > _species_atlas_image.get_width() or region.end.y > _species_atlas_image.get_height():
			push_warning("Avatar species part %s exceeds atlas bounds; species overlays are disabled." % str(region))
			return
		var visible_pixels := 0
		for y in range(region.position.y, region.end.y):
			for x in range(region.position.x, region.end.x):
				if _species_atlas_image.get_pixel(x, y).a > 0.63:
					visible_pixels += 1
		if visible_pixels < 100:
			push_warning("Avatar species part %s is empty; species overlays are disabled." % str(region))
			return
	_species_atlas_valid = true

func _apply_species_ears(image: Image, species: String, direction: String, vertical_offset: int, skin_color: Color) -> void:
	if species != "elf" or not _species_atlas_valid: return
	if direction == "left" or direction == "right":
		var profile_index := 2 if direction == "left" else 3
		var region: Rect2i = ELF_EAR_REGIONS[profile_index]
		var width := 22
		var x := 35 if direction == "left" else image.get_width() - 57
		_blend_species_part(image, region, width, Vector2i(x, 79 + vertical_offset), skin_color)
		return
	var left_region: Rect2i = ELF_EAR_REGIONS[0]
	var right_region: Rect2i = ELF_EAR_REGIONS[1]
	_blend_species_part(image, left_region, 36, Vector2i(15, 78 + vertical_offset), skin_color)
	_blend_species_part(image, right_region, 36, Vector2i(image.get_width() - 51, 78 + vertical_offset), skin_color)

func _apply_species_horns(image: Image, species: String, direction: String, vertical_offset: int) -> void:
	if species != "imp" or not _species_atlas_valid: return
	var left_part: Rect2i
	var right_part: Rect2i
	if direction == "back":
		left_part = IMP_HORN_REGIONS[3]
		right_part = IMP_HORN_REGIONS[3]
	elif direction == "left" or direction == "right":
		var side_part: Rect2i = IMP_HORN_REGIONS[0]
		var x := 119 if direction == "left" else 137
		_blend_species_part(image, side_part, 26, Vector2i(x, 12 + vertical_offset), Color.WHITE, direction == "right")
		return
	else:
		left_part = IMP_HORN_REGIONS[1]
		right_part = IMP_HORN_REGIONS[1]
	var center_x := image.get_width() / 2
	_blend_species_part(image, left_part, 31, Vector2i(center_x - 37, 13 + vertical_offset), Color.WHITE)
	_blend_species_part(image, right_part, 31, Vector2i(center_x + 6, 13 + vertical_offset), Color.WHITE, true)

func _blend_species_part(image: Image, source_region: Rect2i, target_width: int, target_position: Vector2i, skin_color: Color, flip_horizontal: bool = false) -> void:
	var part := _species_atlas_image.get_region(source_region)
	for y in range(part.get_height()):
		for x in range(part.get_width()):
			var pixel := part.get_pixel(x, y)
			if pixel.a < 0.4:
				part.set_pixel(x, y, Color.TRANSPARENT)
			elif skin_color != Color.WHITE and _is_color_family(pixel, Color("#f0ac7d"), 0.11, 0.2):
				part.set_pixel(x, y, _shade_preserving(pixel, Color("#f0ac7d"), skin_color))
	var resize_ratio := float(target_width) / float(part.get_width())
	var target_height := maxi(1, roundi(float(part.get_height()) * resize_ratio))
	part.resize(target_width, target_height, Image.INTERPOLATE_NEAREST)
	if flip_horizontal: part.flip_x()
	image.blend_rect(part, Rect2i(Vector2i.ZERO, Vector2i(target_width, target_height)), target_position)

func _strip_source_hair(image: Image, direction: String) -> void:
	var face_left := image.get_width() * 0.30
	var face_right := image.get_width() * 0.70
	var hair_bottom := image.get_height() * (0.43 if direction == "back" else 0.39)
	for y in range(mini(image.get_height(), roundi(hair_bottom))):
		for x in range(image.get_width()):
			if direction != "back" and y >= image.get_height() * 0.22 and x >= face_left and x <= face_right:
				continue
			var color := image.get_pixel(x, y)
			if color.a > 0.05 and _is_source_hair(color):
				image.set_pixel(x, y, Color.TRANSPARENT)

func _is_source_hair(color: Color) -> bool:
	var reference := Color("#2a2b48")
	var distance := absf(color.h - reference.h)
	return color.v > 0.025 and color.v < 0.58 and color.s > 0.15 and minf(distance, 1.0 - distance) < 0.065

func _apply_hair_atlas(image: Image, hair_style: String, direction: String, hair_color: Color, vertical_offset: int) -> void:
	var row: int = {"windswept": 0, "bob": 1, "curly": 2}.get(hair_style, 0)
	var column := DIRECTIONS.find(direction)
	if column < 0: column = 0
	var source_region: Rect2i = HAIR_REGIONS[row][column]
	var scale_x := float(_hair_atlas_image.get_width()) / HAIR_SOURCE_SIZE.x
	var scale_y := float(_hair_atlas_image.get_height()) / HAIR_SOURCE_SIZE.y
	var region := _scaled_region(source_region, scale_x, scale_y)
	var target_width: float = HAIR_TARGET_WIDTH * float(image.get_width()) / CANVAS_SIZE.x
	var row_average_width: float = 0.0
	for hair_region: Rect2i in HAIR_REGIONS[row]: row_average_width += hair_region.size.x * scale_x
	row_average_width /= HAIR_REGIONS[row].size()
	var resize_ratio: float = target_width / row_average_width
	var scaled_region_size: Vector2 = Vector2(region.size.x * scale_x * resize_ratio, region.size.y * scale_y * resize_ratio)
	var hair := _hair_atlas_image.get_region(region)
	for y in range(hair.get_height()):
		for x in range(hair.get_width()):
			var pixel := hair.get_pixel(x, y)
			if pixel.a < 0.4: hair.set_pixel(x, y, Color.TRANSPARENT)
			elif _is_dark_blue(pixel, Color("#2a2b48")):
				hair.set_pixel(x, y, _shade_preserving(pixel, Color("#2a2b48"), hair_color))
	var resized := Vector2i(maxi(1, roundi(scaled_region_size.x)), maxi(1, roundi(scaled_region_size.y)))
	hair.resize(resized.x, resized.y, Image.INTERPOLATE_NEAREST)
	var position := Vector2i((image.get_width() - resized.x) / 2, vertical_offset)
	image.blend_rect(hair, Rect2i(Vector2i.ZERO, resized), position)

func _shade_preserving(source: Color, source_base: Color, target_base: Color) -> Color:
	var ratio := clampf(source.v / maxf(0.08, source_base.v), 0.48, 1.65)
	var result := Color(target_base.r * ratio, target_base.g * ratio, target_base.b * ratio, source.a)
	result.a = source.a
	return result.clamp()

func _apply_appearance_details(image: Image, appearance: Dictionary, direction: String, action: String) -> void:
	var w := image.get_width()
	var h := image.get_height()
	var sx := float(w) / 64.0
	var sy := float(h) / 96.0
	var face := str(appearance.get("face", "curious"))
	# Expressions are drawn only on the authored front idle face, whose landmarks
	# are stable. Other directions and gestures retain their original facial pixels.
	if direction == "front" and action == "idle" and face != "curious":
		_apply_face_shape(image, face, sx, sy)

func _apply_face_shape(image: Image, expression: String, sx: float, sy: float) -> void:
	var dark := Color("#26394a")
	var eye_y := roundi(20.0*sy)
	var mouth_y := roundi(30.0*sy)
	var line_width := maxi(1, roundi(0.45*sx))
	if expression == "confident":
		_draw_line(image, Vector2i(roundi(24.0*sx), eye_y), Vector2i(roundi(27.0*sx), eye_y-roundi(0.8*sy)), dark, line_width)
		_draw_line(image, Vector2i(roundi(37.0*sx), eye_y-roundi(0.8*sy)), Vector2i(roundi(40.0*sx), eye_y), dark, line_width)
		_draw_line(image, Vector2i(roundi(31.0*sx), mouth_y), Vector2i(roundi(33.0*sx), mouth_y), dark, line_width)
	elif expression == "smiling":
		var closed_eye_y := eye_y + roundi(0.6*sy)
		_draw_line(image, Vector2i(roundi(24.0*sx), closed_eye_y), Vector2i(roundi(27.0*sx), closed_eye_y), dark, line_width)
		_draw_line(image, Vector2i(roundi(37.0*sx), closed_eye_y), Vector2i(roundi(40.0*sx), closed_eye_y), dark, line_width)
		_draw_line(image, Vector2i(roundi(30.0*sx), mouth_y), Vector2i(roundi(34.0*sx), mouth_y+roundi(0.6*sy)), Color("#9b5152"), line_width)

func _apply_hat(image: Image, hat: String, direction: String, vertical_offset: int) -> void:
	if hat == "hat-none": return
	if _hat_atlas_valid:
		var row: int = {"hat-straw": 0, "hat-sailor": 1, "hat-flower": 2}.get(hat, -1)
		if row >= 0:
			_apply_hat_atlas(image, row, DIRECTIONS.find(direction), vertical_offset)
			return
	var sx := float(image.get_width()) / 64.0
	var sy := float(image.get_height()) / 96.0
	var color := Color("#d8bb77") if hat == "hat-straw" else (Color("#f2f1e8") if hat == "hat-sailor" else Color("#d8789b"))
	if hat == "hat-flower":
		for offset in [-6, 0, 6]: _draw_rect(image, int((31+offset)*sx), int(5*sy), maxi(2, int(5*sx)), maxi(2, int(5*sy)), color.lightened(0.16 if offset == 0 else 0.0))
		_draw_rect(image, int(31*sx), int(5*sy), maxi(2, int(4*sx)), maxi(2, int(4*sy)), Color("#edbb65"))
	elif hat == "hat-sailor":
		_draw_rect(image, int(17*sx), int(5*sy), int(30*sx), int(7*sy), color)
		_draw_rect(image, int(13*sx), int(11*sy), int(39*sx), int(3*sy), Color("#36536a"))
		_draw_rect(image, int(19*sx), int(8*sy), int(26*sx), int(2*sy), Color("#36536a"))
	else:
		_draw_rect(image, int(18*sx), int(6*sy), int(28*sx), int(4*sy), color)
		_draw_rect(image, int(10*sx), int(10*sy), int(45*sx), int(3*sy), color.darkened(0.1))
		_draw_rect(image, int(25*sx), int(10*sy), int(13*sx), int(2*sy), Color("#815e42"))
	# Profile hats extend forward so the face remains visible; rear hats stay centered.
	if direction == "left": _draw_rect(image, int(9*sx), int(11*sy), int(8*sx), int(2*sy), color)
	elif direction == "right": _draw_rect(image, int(47*sx), int(11*sy), int(8*sx), int(2*sy), color)

func _apply_hat_atlas(image: Image, row: int, column: int, vertical_offset: int) -> void:
	if column < 0: return
	var source_region: Rect2i = HAT_REGIONS[row][column]
	var scale_x := float(_hat_atlas_image.get_width()) / HAT_SOURCE_SIZE.x
	var scale_y := float(_hat_atlas_image.get_height()) / HAT_SOURCE_SIZE.y
	var region := _scaled_region(source_region, scale_x, scale_y)
	var target_width: float = HAT_TARGET_WIDTHS[row] * float(image.get_width()) / CANVAS_SIZE.x
	var row_average_width := 0.0
	for hat_region: Rect2i in HAT_REGIONS[row]: row_average_width += hat_region.size.x * scale_x
	row_average_width /= HAT_REGIONS[row].size()
	var resize_ratio: float = target_width / row_average_width
	var scaled_region_size := Vector2(region.size.x * resize_ratio, region.size.y * scale_y * resize_ratio * HAT_VERTICAL_SCALE[row])
	var hat := _hat_atlas_image.get_region(region)
	# Keep generated semitransparent dust transparent so it cannot make a dark halo.
	for y in range(hat.get_height()):
		for x in range(hat.get_width()):
			var pixel := hat.get_pixel(x, y)
			if pixel.a < 0.4: hat.set_pixel(x, y, Color.TRANSPARENT)
	var resized := Vector2i(maxi(1, roundi(scaled_region_size.x)), maxi(1, roundi(scaled_region_size.y)))
	hat.resize(resized.x, resized.y, Image.INTERPOLATE_NEAREST)
	var crown_offset := roundi(HAT_CROWN_OFFSETS[row] * float(image.get_height()) / CANVAS_SIZE.y)
	var crown_y := maxi(roundi(2.0 * float(image.get_height()) / CANVAS_SIZE.y), vertical_offset + crown_offset)
	var position := Vector2i((image.get_width() - resized.x) / 2, crown_y)
	var composite := Image.create(image.get_width(), image.get_height(), false, Image.FORMAT_RGBA8)
	composite.fill(Color.TRANSPARENT)
	composite.blend_rect(hat, Rect2i(Vector2i.ZERO, resized), position)
	image.blend_rect(composite, Rect2i(Vector2i.ZERO, Vector2i(image.get_width(), image.get_height())), Vector2i.ZERO)

func _fallback_image(direction: String, frame: int, action: String) -> Image:
	var image := Image.create(64, 96, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var skin := Color("#e8b991")
	var ink := Color("#293b50")
	var coat := Color("#4b9bb0")
	var offset := 1 if frame == 1 else (-1 if frame == 2 else 0)
	_draw_rect(image, 18, 69+offset, 11, 15-offset, Color("#654b3e"))
	_draw_rect(image, 36, 69-offset, 11, 15+offset, Color("#654b3e"))
	_draw_rect(image, 14, 25, 36, 46, ink)
	_draw_rect(image, 16, 27, 32, 40, coat)
	_draw_rect(image, 17, 9, 30, 19, ink)
	_draw_rect(image, 20, 12, 24, 17, skin)
	if direction != "back":
		_draw_rect(image, 24, 22, 4, 3, ink)
		_draw_rect(image, 38, 22, 4, 3, ink)
		_draw_rect(image, 29, 32, 10, 2, Color("#984d4f"))
	if action == "wave": _draw_line(image, Vector2i(43, 40), Vector2i(54, 25), skin, 5)
	elif action == "photograph":
		_draw_rect(image, 41, 42, 14, 10, Color("#994f45"))
		_draw_rect(image, 49, 45, 4, 4, Color("#8fc4c6"))
	elif action == "celebrate":
		_draw_line(image, Vector2i(17, 40), Vector2i(8, 24), skin, 5)
		_draw_line(image, Vector2i(46, 40), Vector2i(55, 24), skin, 5)
	return image

func _draw_rect(image: Image, x: int, y: int, width: int, height: int, color: Color) -> void:
	var rect := Rect2i(x, y, width, height).intersection(Rect2i(0, 0, image.get_width(), image.get_height()))
	if rect.size.x > 0 and rect.size.y > 0: image.fill_rect(rect, color)

func _draw_triangle(image: Image, x: int, y: int, width: int, height: int, color: Color, point_up: bool) -> void:
	for row in range(height):
		var t := float(row) / maxf(1.0, float(height - 1))
		var span := maxi(1, roundi(width * (1.0 - t) if point_up else width * t))
		_draw_rect(image, x + (width - span) / 2, y + row, span, 1, color)

func _draw_line(image: Image, start: Vector2i, finish: Vector2i, color: Color, thickness: int) -> void:
	var steps := maxi(absi(finish.x - start.x), absi(finish.y - start.y))
	for i in range(steps + 1):
		var t := float(i) / maxf(1.0, float(steps))
		_draw_rect(image, roundi(lerpf(start.x, finish.x, t)) - thickness / 2, roundi(lerpf(start.y, finish.y, t)) - thickness / 2, thickness, thickness, color)
