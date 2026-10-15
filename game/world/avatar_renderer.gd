extends RefCounted
## Builds cached, nearest-filtered avatar poses from the authored action atlas.
## The fallback keeps the wardrobe usable when a packaged atlas is unavailable.

const ATLAS_PATH := "res://assets/characters/traveller-actions-v1.png"
const CACHE_LIMIT := 128
const WALK_SOURCE_METRICS_LIMIT := 64
const HAIR_CUT_CACHE_LIMIT := 24
const DIRECTIONS := ["front", "left", "back", "right"]
const WALK_DIRECTIONS := ["front", "front_right", "right", "back_right", "back", "back_left", "left", "front_left"]
const WALK_METADATA_PATH := "res://assets/characters/walk-regions.json"
const DIAGONAL_PARTS_PATH := "res://assets/characters/diagonal-parts.json"
const IDLE_WALK_FRAME := 0
const ACTIONS := ["wave", "photograph", "interact", "celebrate"]
const CharacterAnimationLibraryScript = preload("res://game/world/character_animation_library.gd")
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
var _walk_images: Dictionary = {}
var _walk_metadata: Dictionary = {}
var _walk_frame_counts: Dictionary = {}
var _walk_idle_frames: Dictionary = {}
var _walk_head_anchor_cache: Dictionary = {}
var _walk_head_width_cache: Dictionary = {}
var _walk_source_metrics_cache: Dictionary = {}
var _walk_source_image_cache: Dictionary = {}
var _hair_cut_cache: Dictionary = {}
var _walk_source_image_build_count := 0
var _source_metrics_build_count := 0
var _hair_cut_build_count := 0
var _walk_scale_reference_height := 444.0
var _walk_atlas_valid := false
var _diagonal_hair_image: Image
var _diagonal_hat_image: Image
var _diagonal_hair_regions: Array = []
var _diagonal_hat_regions: Array = []
var _diagonal_hair_valid := false
var _diagonal_hat_valid := false
var animation_library: RefCounted

func _init() -> void:
	_load_atlas()
	animation_library = CharacterAnimationLibraryScript.new()

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

func has_walk_atlas() -> bool:
	return _walk_atlas_valid

func walk_frame_count(direction: String) -> int:
	return int(_walk_frame_counts.get(direction, 0)) if _walk_atlas_valid else 0

func walk_idle_frame(direction: String) -> int:
	return int(_walk_idle_frames.get(direction, IDLE_WALK_FRAME)) if _walk_atlas_valid else IDLE_WALK_FRAME

func has_diagonal_parts() -> bool:
	return _diagonal_hair_valid and _diagonal_hat_valid

func cached_texture_count() -> int:
	return _cache.size()

func has_authored_action(action: String, direction: String = "front") -> bool:
	var safe_direction := direction if WALK_DIRECTIONS.has(direction) else "front"
	return animation_library != null and animation_library.has_action("traveller", action, safe_direction)

func authored_frame_count(action: String, direction: String = "front") -> int:
	var safe_direction := direction if WALK_DIRECTIONS.has(direction) else "front"
	return animation_library.frame_count("traveller", action, safe_direction) if animation_library != null else 0

func authored_action_fps(action: String, direction: String = "front") -> float:
	var safe_direction := direction if WALK_DIRECTIONS.has(direction) else "front"
	return animation_library.frame_fps("traveller", action, safe_direction) if animation_library != null else 0.0

func texture(appearance: Dictionary, equipped: Dictionary, direction: String = "front", frame: int = 0, action: String = "idle") -> Texture2D:
	var safe_direction := direction if WALK_DIRECTIONS.has(direction) else "front"
	var authored_action: bool = animation_library != null and animation_library.has_action("traveller", action, safe_direction)
	var safe_action := action if ACTIONS.has(action) or action == "walk" or authored_action else "idle"
	var has_manifest_frame: bool = safe_action != "walk" and animation_library.has_frame("traveller", safe_action, safe_direction)
	var authored_frame_count: int = animation_library.frame_count("traveller", safe_action, safe_direction) if has_manifest_frame else 0
	var safe_frame := clampi(frame, 0, 7) if safe_action == "walk" else clampi(frame, 0, authored_frame_count - 1) if has_manifest_frame else clampi(frame, 0, 2)
	var use_walk_source := _walk_atlas_valid and (safe_action == "walk" or (safe_action == "idle" and WALK_DIRECTIONS.has(direction))) and not has_manifest_frame
	var walk_frame := IDLE_WALK_FRAME
	if use_walk_source:
		var frame_count := walk_frame_count(safe_direction)
		walk_frame = clampi(frame, 0, frame_count - 1) if safe_action == "walk" else walk_idle_frame(safe_direction)
	var pose_direction := safe_direction if DIRECTIONS.has(safe_direction) else _closest_cardinal(safe_direction)
	var normalized_appearance := DEFAULT_APPEARANCE.duplicate()
	for key in DEFAULT_APPEARANCE:
		if appearance.has(key): normalized_appearance[key] = str(appearance[key])
	var outfit := str(equipped.get("outfit", "outfit-tide"))
	var hat := str(equipped.get("hat", "hat-none"))
	var pose := _pose_index(pose_direction, safe_frame, safe_action)
	var render_appearance := normalized_appearance.duplicate()
	render_appearance.erase("gender")
	var pose_key := "walk:%s:%d" % [safe_direction, walk_frame] if use_walk_source else ("manifest:%s:%s:%d" % [safe_action, safe_direction, safe_frame] if has_manifest_frame else "action:%d" % pose)
	var key := "%s|%s|%s" % [JSON.stringify(render_appearance), outfit + ":" + hat, pose_key]
	if _cache.has(key):
		_cache_order.erase(key)
		_cache_order.append(key)
		return _cache[key]
	var image := _walk_pose_image(safe_direction, walk_frame) if use_walk_source else (_atlas_pose_image(pose) if _atlas_valid else _fallback_image(pose_direction, safe_frame, safe_action))
	var manifest_head_anchor := Vector2i.ZERO
	var manifest_has_head_anchor := false
	if has_manifest_frame:
		# The coral vest atlas is an incomplete silhouette prototype. Keep its
		# historical metadata intact, but render the catalog's coral jacket by
		# recoloring each authored base pose until a complete matching set exists.
		var pose_equipped := equipped
		if outfit == "outfit-coral":
			pose_equipped = equipped.duplicate()
			pose_equipped.erase("outfit")
		var authored: Texture2D = animation_library.texture("traveller", safe_action, safe_direction, safe_frame, pose_equipped)
		if authored != null:
			# ImageTexture.get_image() may expose a cached image. Renderer passes
			# mutate their working canvas, so detach before stripping or compositing.
			image = authored.get_image().duplicate()
			if animation_library.has_anchor("traveller", safe_action, safe_direction, safe_frame, "head", pose_equipped):
				manifest_head_anchor = animation_library.normalized_anchor("traveller", safe_action, safe_direction, safe_frame, "head", pose_equipped)
				manifest_has_head_anchor = true
	var vertical_offset := 0 if use_walk_source else (_pose_vertical_offsets[pose] if _atlas_valid else 0)
	var hair_hat_offset := 45 if use_walk_source else vertical_offset
	var head_shift_x := 0
	var hair_target_width := HAIR_TARGET_WIDTH
	if use_walk_source:
		var head_anchor := walk_head_anchor(safe_direction, walk_frame)
		var rest_anchor := walk_head_anchor(safe_direction, walk_idle_frame(safe_direction))
		head_shift_x = head_anchor.x - image.get_width() / 2
		hair_hat_offset = head_anchor.y
		hair_target_width = float(walk_head_width(safe_direction, walk_frame)) * 1.05
		# Species parts keep their direction-specific baseline and follow the measured
		# head motion from that direction's hold pose.
		vertical_offset = head_anchor.y - rest_anchor.y
	if manifest_has_head_anchor:
		head_shift_x = manifest_head_anchor.x - image.get_width() / 2
		hair_hat_offset = manifest_head_anchor.y
	var species := str(normalized_appearance.get("species", "human"))
	var species_head_shift_x := 0
	if use_walk_source:
		var rest_head_anchor := walk_head_anchor(safe_direction, walk_idle_frame(safe_direction))
		species_head_shift_x = walk_head_anchor(safe_direction, walk_frame).x - rest_head_anchor.x
	# Authored source frames carry the approved windswept hair outside the walk
	# atlas too (idle, seated, and other manifest actions). Preserve those cels;
	# replacement cuts belong only to alternate styles or un-authored fallbacks.
	var has_authored_source_hair := use_walk_source or has_manifest_frame
	var use_replacement_hair := str(normalized_appearance.get("hair", "windswept")) != "windswept" or not has_authored_source_hair
	var has_hair_overlay := use_replacement_hair and ((_hair_atlas_valid and DIRECTIONS.has(safe_direction)) or (_diagonal_hair_valid and not DIRECTIONS.has(safe_direction)))
	var has_hat_overlay := _hat_atlas_valid and DIRECTIONS.has(safe_direction) or _diagonal_hat_valid and not DIRECTIONS.has(safe_direction)
	var face_backdrop: Image
	var face_mask := PackedByteArray()
	var source_hair_mask := PackedByteArray()
	var source_metrics: Dictionary = {}
	if has_hair_overlay:
		if use_walk_source:
			source_metrics = _walk_source_hair_metrics(safe_direction, walk_frame, image)
		else:
			source_metrics = _authored_source_hair_metrics(image, safe_direction, safe_action)
	if has_hair_overlay and has_manifest_frame and safe_action == "idle" and safe_direction in ["front_left", "front_right"]:
		var replacement_cut := _cached_hair_cut(str(normalized_appearance.get("hair", "windswept")), safe_direction, HAIR_COLORS.ink)
		if not bool(source_metrics.get("replacement_geometry_valid", false)) or not bool(replacement_cut.get("face_opening_valid", false)):
			# Keep a complete authored source if either side of registration is
			# unavailable. Never strip hair before discovering a missing face cut.
			has_hair_overlay = false
			use_replacement_hair = false
	var palette_hair_indices := PackedInt32Array()
	if not has_hair_overlay and str(normalized_appearance.get("hair", "windswept")) == "windswept" and str(normalized_appearance.get("hair_color", "ink")) != "ink":
		if source_metrics.is_empty():
			var palette_hair_source := _walk_pose_image(safe_direction, walk_frame) if use_walk_source else image.duplicate()
			source_metrics = _walk_source_hair_metrics(safe_direction, walk_frame, palette_hair_source) if use_walk_source else _authored_source_hair_metrics(palette_hair_source, safe_direction, safe_action)
		palette_hair_indices = source_metrics.source_hair_indices
	if species=="elf" and source_metrics.is_empty():
		source_metrics = _walk_source_hair_metrics(safe_direction,walk_frame,image) if use_walk_source else _authored_source_hair_metrics(image,safe_direction,safe_action)
	# Recolor the body before compositing a prepared haircut. Applying the coat
	# palette afterwards mistakes dark-blue curls over the jacket for cloth.
	_apply_palette(image, normalized_appearance, outfit, pose_direction, has_hair_overlay, palette_hair_indices)
	if has_hair_overlay:
		face_backdrop = image.duplicate()
		source_hair_mask = source_metrics.source_hair_mask
		face_mask = source_metrics.face_mask
		_strip_source_hair(image,source_metrics.get("replacement_source_mask",source_hair_mask),source_metrics.get("replacement_source_indices",source_metrics.source_hair_indices))

	if use_replacement_hair and _hair_atlas_valid and DIRECTIONS.has(safe_direction):
		_apply_hair_atlas(image, str(normalized_appearance.get("hair", "windswept")), safe_direction, HAIR_COLORS.get(str(normalized_appearance.get("hair_color", "ink")), HAIR_COLORS.ink), hair_hat_offset, head_shift_x, hair_target_width, face_backdrop, source_metrics, SKIN_COLORS.get(str(normalized_appearance.get("skin", "warm")), SKIN_COLORS.warm))
	elif use_replacement_hair and _diagonal_hair_valid and not DIRECTIONS.has(safe_direction):
		_apply_diagonal_hair(image, str(normalized_appearance.get("hair", "windswept")), safe_direction, HAIR_COLORS.get(str(normalized_appearance.get("hair_color", "ink")), HAIR_COLORS.ink), hair_hat_offset, head_shift_x, hair_target_width, face_backdrop, source_metrics, SKIN_COLORS.get(str(normalized_appearance.get("skin", "warm")), SKIN_COLORS.warm))
	if face_backdrop != null:
		_restore_face_features(image, face_backdrop, face_mask, source_metrics.face_indices)
	if DIRECTIONS.has(safe_direction):
		_apply_appearance_details(image, normalized_appearance, safe_direction, safe_action)
	var selected_hair_color: Color = HAIR_COLORS.get(str(normalized_appearance.get("hair_color","ink")),HAIR_COLORS.ink)
	if species == "elf" and _species_atlas_valid:
		if source_metrics.is_empty():
			var raw_pose := _walk_pose_image(safe_direction,walk_frame) if use_walk_source else image
			source_metrics = _walk_source_hair_metrics(safe_direction,walk_frame,raw_pose) if use_walk_source else _authored_source_hair_metrics(raw_pose,safe_direction,safe_action)
		var ear_layer := Image.create(image.get_width(),image.get_height(),false,Image.FORMAT_RGBA8)
		ear_layer.fill(Color.TRANSPARENT)
		_apply_species_ears(ear_layer,species,pose_direction,vertical_offset,SKIN_COLORS.get(str(normalized_appearance.get("skin","warm")),SKIN_COLORS.warm),species_head_shift_x,image,source_metrics)
		var selected_face_backdrop := image
		ear_layer.blend_rect(image,Rect2i(Vector2i.ZERO,Vector2i(image.get_width(),image.get_height())),Vector2i.ZERO)
		image = ear_layer
		_restore_face_features(image,selected_face_backdrop,source_metrics.face_mask,source_metrics.face_indices)
	_apply_species_horns(image,species,pose_direction,vertical_offset,species_head_shift_x,selected_hair_color)
	if DIRECTIONS.has(safe_direction):
		_apply_hat(image, hat, safe_direction, hair_hat_offset, head_shift_x)
	elif has_hat_overlay:
		_apply_diagonal_hat(image, hat, safe_direction, hair_hat_offset, head_shift_x)
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
	_load_walk_atlases()
	_load_hat_atlas()
	_load_hair_atlas()
	_load_diagonal_parts()
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

func _closest_cardinal(direction: String) -> String:
	match direction:
		"front_left", "front_right": return "front"
		"back_left", "back_right": return "back"
	return direction if DIRECTIONS.has(direction) else "front"

func _load_walk_atlases() -> void:
	if not FileAccess.file_exists(WALK_METADATA_PATH):
		push_warning("Avatar walk metadata '%s' is missing; authored eight-direction movement is unavailable." % WALK_METADATA_PATH)
		return
	var file := FileAccess.open(WALK_METADATA_PATH, FileAccess.READ)
	if file == null:
		push_warning("Avatar walk metadata '%s' cannot be read; authored eight-direction movement is unavailable." % WALK_METADATA_PATH)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_warning("Avatar walk metadata has an invalid schema; authored eight-direction movement is unavailable.")
		return
	var directions_value: Variant = parsed.get("directions")
	if not directions_value is Dictionary or directions_value.size() != WALK_DIRECTIONS.size():
		push_warning("Avatar walk metadata must define exactly the eight authored directions.")
		return
	if parsed.has("frames_per_direction"):
		var declared_frames: Variant = parsed.frames_per_direction
		if not _is_finite_json_number(declared_frames) or not [8.0, 16.0].has(float(declared_frames)):
			push_warning("Avatar walk metadata has an invalid frames_per_direction value.")
			return
	var scale_reference: Variant = parsed.get("scale_reference_height", 444)
	if not _is_finite_json_number(scale_reference) or float(scale_reference) <= 0.0:
		push_warning("Avatar walk metadata has an invalid scale_reference_height.")
		return
	var atlases: Dictionary = {}
	var directions: Dictionary = directions_value
	var loaded_metadata: Dictionary = {}
	var frame_counts: Dictionary = {}
	var idle_frames: Dictionary = {}
	for direction in WALK_DIRECTIONS:
		if not directions.has(direction):
			push_warning("Avatar walk metadata omits direction '%s'; authored eight-direction movement is unavailable." % direction)
			return
		var entry_value: Variant = directions[direction]
		if not entry_value is Dictionary:
			push_warning("Avatar walk direction '%s' entry must be an object." % direction)
			return
		var entry: Dictionary = entry_value
		var regions_value: Variant = entry.get("regions")
		var anchors_value: Variant = entry.get("anchors")
		if not regions_value is Array or not anchors_value is Array:
			push_warning("Avatar walk direction '%s' must define region and anchor arrays." % direction)
			return
		var regions: Array = regions_value
		var anchors: Array = anchors_value
		if regions.size() not in [8, 16] or anchors.size() != regions.size():
			push_warning("Avatar walk direction '%s' must define matching arrays of eight or sixteen poses." % direction)
			return
		var idle_frame_value: Variant = entry.get("idle_frame", IDLE_WALK_FRAME)
		if not _is_json_integer(idle_frame_value) or int(idle_frame_value) < 0 or int(idle_frame_value) >= regions.size():
			push_warning("Avatar walk direction '%s' has an invalid idle_frame." % direction)
			return
		var atlas_value: Variant = entry.get("atlas", "")
		if typeof(atlas_value) != TYPE_STRING or str(atlas_value).is_empty():
			push_warning("Avatar walk direction '%s' has an invalid atlas path." % direction)
			return
		var atlas_path := str(atlas_value)
		if not atlases.has(atlas_path):
			if not ResourceLoader.exists(atlas_path):
				push_warning("Avatar walk atlas '%s' is missing; authored eight-direction movement is unavailable." % atlas_path)
				return
			var atlas_texture := load(atlas_path) as Texture2D
			if atlas_texture == null:
				push_warning("Avatar walk atlas '%s' is not an imported texture resource." % atlas_path)
				return
			atlases[atlas_path] = atlas_texture.get_image()
		var atlas_image: Image = atlases[atlas_path]
		for frame in range(regions.size()):
			var raw_region_value: Variant = regions[frame]
			var anchor_value: Variant = anchors[frame]
			if not raw_region_value is Array or raw_region_value.size() != 4 or not anchor_value is Dictionary:
				push_warning("Avatar walk pose '%s:%d' has invalid region/anchor metadata." % [direction, frame])
				return
			var raw_region: Array = raw_region_value
			var anchor: Dictionary = anchor_value
			if not anchor.has("center_x") or not anchor.has("feet_y"):
				push_warning("Avatar walk pose '%s:%d' has invalid region/anchor metadata." % [direction, frame])
				return
			for coordinate in raw_region:
				if not _is_json_integer(coordinate):
					push_warning("Avatar walk pose '%s:%d' region coordinates must be integers." % [direction, frame])
					return
			var region := Rect2i(int(raw_region[0]), int(raw_region[1]), int(raw_region[2]), int(raw_region[3]))
			if region.position.x < 0 or region.position.y < 0 or region.size.x <= 0 or region.size.y <= 0 or region.end.x > atlas_image.get_width() or region.end.y > atlas_image.get_height():
				push_warning("Avatar walk pose '%s:%d' region exceeds its imported atlas." % [direction, frame])
				return
			var center_value: Variant = anchor.center_x
			var feet_value: Variant = anchor.feet_y
			var bounds_value: Variant = anchor.get("bounds")
			if not _is_finite_json_number(center_value) or not _is_finite_json_number(feet_value) or not bounds_value is Array or bounds_value.size() != 4:
				push_warning("Avatar walk pose '%s:%d' has malformed numeric anchors or bounds." % [direction, frame])
				return
			var bounds: Array = bounds_value
			for bound in bounds:
				if not _is_json_integer(bound):
					push_warning("Avatar walk pose '%s:%d' bounds must use integer coordinates." % [direction, frame])
					return
			for delta_key in ["head_delta_x", "head_delta_y"]:
				if anchor.has(delta_key) and (not _is_finite_json_number(anchor[delta_key]) or absf(float(anchor[delta_key])) > float(scale_reference)):
					push_warning("Avatar walk pose '%s:%d' has an invalid %s." % [direction, frame, delta_key])
					return
			if float(center_value) < 0 or float(center_value) >= region.size.x or float(feet_value) < 0 or float(feet_value) >= region.size.y:
				push_warning("Avatar walk pose '%s:%d' has invalid common-center/feet anchors." % [direction, frame])
				return
			var visible := 0
			var central_visible := false
			for y in range(region.size.y):
				for x in range(region.size.x):
					if atlas_image.get_pixel(region.position.x + x, region.position.y + y).a <= 0.4: continue
					visible += 1
					if x >= region.size.x * 0.25 and x <= region.size.x * 0.75 and y >= region.size.y * 0.2 and y <= region.size.y * 0.85:
						central_visible = true
			if visible < 10000 or not central_visible:
				push_warning("Avatar walk pose '%s:%d' is empty or lacks central character pixels." % [direction, frame])
				return
			if int(bounds[0]) < 0 or int(bounds[1]) < 0 or int(bounds[2]) <= int(bounds[0]) or int(bounds[3]) <= int(bounds[1]) or int(bounds[2]) > region.size.x or int(bounds[3]) > region.size.y:
				push_warning("Avatar walk pose '%s:%d' visible bounds exceed the cell." % [direction, frame])
				return
			loaded_metadata["%s:%d" % [direction, frame]] = {"region": region, "anchor": anchor, "atlas": atlas_path}
		frame_counts[direction] = regions.size()
		idle_frames[direction] = idle_frame_value
	_walk_images = atlases
	_walk_metadata = loaded_metadata
	_walk_frame_counts = frame_counts
	_walk_idle_frames = idle_frames
	_walk_scale_reference_height = float(scale_reference)
	_walk_atlas_valid = true

func _is_finite_json_number(value: Variant) -> bool:
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT: return false
	return is_finite(float(value))

func _is_json_integer(value: Variant) -> bool:
	return _is_finite_json_number(value) and floorf(float(value)) == float(value)

func _walk_pose_image(direction: String, frame: int) -> Image:
	var cache_key := "%s:%d" % [direction, frame]
	if _walk_source_image_cache.has(cache_key):
		return _walk_source_image_cache[cache_key].duplicate()
	var data: Dictionary = _walk_metadata["%s:%d" % [direction, frame]]
	var region: Rect2i = data.region
	var anchor: Dictionary = data.anchor
	var source: Image = _walk_images[data.atlas]
	var cell := source.get_region(region)
	for y in range(cell.get_height()):
		for x in range(cell.get_width()):
			if cell.get_pixel(x, y).a < 0.4: cell.set_pixel(x, y, Color.TRANSPARENT)
	var scale := float(_canvas_height) / _walk_scale_reference_height
	var resized := Vector2i(maxi(1, roundi(float(cell.get_width()) * scale)), maxi(1, roundi(float(cell.get_height()) * scale)))
	cell.resize(resized.x, resized.y, Image.INTERPOLATE_NEAREST)
	var image := Image.create(_canvas_width, _canvas_height, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var source_center := float(anchor.center_x) * scale
	var source_feet := float(anchor.feet_y) * scale
	var offset := Vector2i(roundi(float(_canvas_width) * 0.5 - source_center), roundi(float(FEET_BASELINE) - source_feet))
	image.blend_rect(cell, Rect2i(Vector2i.ZERO, resized), offset)
	_walk_source_image_cache[cache_key] = image.duplicate()
	_walk_source_image_build_count += 1
	assert(_walk_source_image_cache.size() <= WALK_SOURCE_METRICS_LIMIT)
	return image

func walk_head_anchor(direction: String, frame: int) -> Vector2i:
	## Measures the head from the authored walk cel after it is placed on the
	## shared canvas. Hair and accessories therefore follow each actual pose.
	if not _walk_atlas_valid or not _walk_metadata.has("%s:%d" % [direction, frame]):
		return Vector2i(_canvas_width / 2, 45)
	var cache_key := "%s:%d" % [direction, frame]
	if _walk_head_anchor_cache.has(cache_key):
		return _walk_head_anchor_cache[cache_key]
	var image := _walk_pose_image(direction, frame)
	var hair_top := image.get_height()
	var hair_left := image.get_width()
	var hair_right := -1
	var face_sum_x := 0.0
	var face_pixels := 0
	var face_left := image.get_width()
	var face_right := -1
	var source_skin := Color("#fdbb7b")
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var color := image.get_pixel(x, y)
			if color.a < 0.4:
				continue
			if _is_source_hair(color):
				hair_top = mini(hair_top, y)
				hair_left = mini(hair_left, x)
				hair_right = maxi(hair_right, x)
			if y < image.get_height() * 0.45 and _is_color_family(color, source_skin, 0.055, 0.25):
				face_sum_x += float(x)
				face_pixels += 1
				face_left = mini(face_left, x)
				face_right = maxi(face_right, x)
	if hair_right < hair_left:
		return Vector2i(_canvas_width / 2, 45)
	var head_center_x := roundi(face_sum_x / float(face_pixels)) if face_pixels > 0 else roundi(float(hair_left + hair_right) * 0.5)
	var result := Vector2i(head_center_x, hair_top)
	_walk_head_anchor_cache[cache_key] = result
	var head_left := mini(hair_left, face_left) if face_right >= face_left else hair_left
	var head_right := maxi(hair_right, face_right) if face_right >= face_left else hair_right
	_walk_head_width_cache[cache_key] = maxi(1, head_right - head_left + 1)
	return result

func walk_head_width(direction: String, frame: int) -> int:
	var cache_key := "%s:%d" % [direction, frame]
	if not _walk_head_width_cache.has(cache_key):
		walk_head_anchor(direction, frame)
	return int(_walk_head_width_cache.get(cache_key, 90))

func _pose_index(direction: String, frame: int, action: String) -> int:
	if action != "idle" and action != "walk": return 12 + ACTIONS.find(action)
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

func _apply_palette(image: Image, appearance: Dictionary, outfit_id: String, direction: String, use_hair_overlay: bool, source_hair_indices: PackedInt32Array = PackedInt32Array()) -> void:
	var skin_target: Color = SKIN_COLORS.get(str(appearance.get("skin", "warm")), SKIN_COLORS.warm)
	var hair_target: Color = HAIR_COLORS.get(str(appearance.get("hair_color", "ink")), HAIR_COLORS.ink)
	var coat_target: Color = OUTFIT_COLORS.get(outfit_id, OUTFIT_COLORS["outfit-tide"])
	var skin_source := Color("#fdbb7b")
	var hair_source := Color("#2a2b48")
	var coat_source := Color("#267e83")
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var color := image.get_pixel(x, y)
			if color.a < 0.05: continue
			var skin_zone := (y >= image.get_height() * 0.16 and y <= image.get_height() * 0.57) or (y >= image.get_height() * 0.62 and y <= image.get_height() * 0.87)
			var coat_zone := y >= image.get_height() * 0.35 and y <= image.get_height() * 0.78 and not (x >= image.get_width() * 0.40 and x <= image.get_width() * 0.61 and y >= image.get_height() * 0.54)
			if skin_zone and _is_color_family(color, skin_source, 0.055, 0.35):
				image.set_pixel(x, y, _shade_preserving(color, skin_source, skin_target))
			elif coat_zone and _is_color_family(color, coat_source, 0.075, 0.12):
				image.set_pixel(x, y, _shade_preserving(color, coat_source, coat_target))
	if not use_hair_overlay and not source_hair_indices.is_empty() and hair_target != HAIR_COLORS.ink:
		var width := image.get_width()
		for index in source_hair_indices:
			var x := index % width
			var y := index / width
			var color := image.get_pixel(x, y)
			if color.a > 0.05 and _is_source_hair(color):
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

func _load_diagonal_parts() -> void:
	if not FileAccess.file_exists(DIAGONAL_PARTS_PATH):
		push_warning("Avatar diagonal hair/hat manifest '%s' is missing; diagonal source art remains visible." % DIAGONAL_PARTS_PATH)
		return
	var file := FileAccess.open(DIAGONAL_PARTS_PATH, FileAccess.READ)
	if file == null:
		push_warning("Avatar diagonal hair/hat manifest cannot be read; diagonal source art remains visible.")
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary or not parsed.get("parts", {}) is Dictionary:
		push_warning("Avatar diagonal hair/hat manifest has an invalid schema; diagonal source art remains visible.")
		return
	var parts: Dictionary = parsed.parts
	var directions: Array = parsed.get("directions", [])
	if directions != ["front_left", "front_right", "back_left", "back_right"]:
		push_warning("Avatar diagonal part direction order is invalid; diagonal source art remains visible.")
		return
	_diagonal_hair_valid = _load_diagonal_part("hair", parts, _diagonal_hair_regions)
	_diagonal_hat_valid = _load_diagonal_part("hats", parts, _diagonal_hat_regions)

func _load_diagonal_part(name: String, parts: Dictionary, target_regions: Array) -> bool:
	if not parts.has(name): return false
	var entry: Dictionary = parts[name]
	var atlas_path := str(entry.get("atlas", ""))
	if not ResourceLoader.exists(atlas_path):
		push_warning("Avatar diagonal %s atlas '%s' is unavailable." % [name, atlas_path])
		return false
	var atlas_texture := load(atlas_path) as Texture2D
	if atlas_texture == null:
		push_warning("Avatar diagonal %s atlas '%s' is not an imported texture." % [name, atlas_path])
		return false
	var atlas_image := atlas_texture.get_image()
	var rows: Array = entry.get("regions", [])
	if rows.size() != 3:
		push_warning("Avatar diagonal %s atlas must define three appearance rows." % name)
		return false
	for row in range(3):
		var cells: Array = rows[row]
		if cells.size() != 4:
			push_warning("Avatar diagonal %s row %d must define four direction parts." % [name, row])
			return false
		var stored_row: Array = []
		for cell_index in range(4):
			var values: Array = cells[cell_index]
			if values.size() != 4:
				push_warning("Avatar diagonal %s row %d direction %d has malformed bounds." % [name, row, cell_index])
				return false
			var region := Rect2i(int(values[0]), int(values[1]), int(values[2]), int(values[3]))
			if region.position.x < 0 or region.position.y < 0 or region.size.x <= 0 or region.size.y <= 0 or region.end.x > atlas_image.get_width() or region.end.y > atlas_image.get_height():
				push_warning("Avatar diagonal %s row %d direction %d exceeds the imported image." % [name, row, cell_index])
				return false
			var part := atlas_image.get_region(region)
			var visible := 0
			for y in range(part.get_height()):
				for x in range(part.get_width()):
					var pixel := part.get_pixel(x, y)
					if pixel.a < 0.4:
						part.set_pixel(x, y, Color.TRANSPARENT)
					else:
						visible += 1
			if visible < 300:
				push_warning("Avatar diagonal %s row %d direction %d is visually empty." % [name, row, cell_index])
				return false
			var used := part.get_used_rect()
			if used.size.x <= 0 or used.size.y <= 0:
				push_warning("Avatar diagonal %s row %d direction %d has no visible bounds." % [name, row, cell_index])
				return false
			stored_row.append(part.get_region(used))
		target_regions.append(stored_row)
	if name == "hair": _diagonal_hair_image = atlas_image
	else: _diagonal_hat_image = atlas_image
	return true

func _apply_diagonal_hair(image: Image, hair_style: String, direction: String, hair_color: Color, vertical_offset: int, head_shift_x: int = 0, target_width_override: float = HAIR_TARGET_WIDTH, source_pose: Image = null, source_metrics: Dictionary = {}, skull_skin_color: Color = Color("#e8b991")) -> void:
	var style_row: int = {"windswept": 0, "bob": 1, "curly": 2}.get(hair_style, 0)
	var direction_index := ["front_left", "front_right", "back_left", "back_right"].find(direction)
	if style_row >= _diagonal_hair_regions.size() or direction_index < 0: return
	# The authored second column is a strict left profile. Mirror the first
	# three-quarter component for rightward front travel so it exposes the face.
	if direction == "front_right": direction_index = 0
	var cut := _cached_hair_cut(hair_style, direction, hair_color)
	if cut.is_empty(): return
	_blend_registered_hair(image, cut.image, direction, vertical_offset, head_shift_x, target_width_override, source_pose, source_metrics, cut, skull_skin_color)

func _hair_face_opening(hair: Image) -> Rect2i:
	# Face cutouts are open at the chin. Interior row gaps therefore work for
	# both closed holes and open-bottom masks without mistaking exterior alpha
	# for the face. Ignore tiny curls/strand gaps.
	var spans: Array[Rect2i] = []
	var widest := 0
	for y in range(roundi(hair.get_height() * 0.24), roundi(hair.get_height() * 0.86)):
		var left := -1
		var right := -1
		for x in range(hair.get_width()):
			if hair.get_pixel(x, y).a > 0.4:
				if left < 0: left = x
				right = x
		var start := -1
		var best := Rect2i()
		for x in range(left + 1, right):
			if hair.get_pixel(x, y).a < 0.1:
				if start < 0: start = x
			elif start >= 0:
				if x - start > best.size.x: best = Rect2i(start, y, x - start, 1)
				start = -1
		if start >= 0 and right - start > best.size.x: best = Rect2i(start, y, right - start, 1)
		spans.append(best)
		widest = maxi(widest, best.size.x)
	if widest < hair.get_width() * 0.12: return Rect2i()
	var result := Rect2i()
	for span in spans:
		if span.size.x < widest * 0.55: continue
		result = span if result.size == Vector2i.ZERO else result.merge(span)
	return result

func _hair_face_opening_mask(hair: Image, opening: Rect2i) -> PackedByteArray:
	var mask := PackedByteArray()
	mask.resize(hair.get_width()*hair.get_height())
	if opening.size.x<=0: return mask
	for y in range(hair.get_height()):
		var left := -1
		var right := -1
		for x in range(hair.get_width()):
			if hair.get_pixel(x,y).a>0.4:
				if left<0: left=x
				right=x
		# Curls can split a head opening into several channels on one row. The
		# physical source-head contour distinguishes scalp from exterior gaps;
		# selecting only the widest channel leaves transparent cracks by an eye.
		for x in range(left+1,right):
			if hair.get_pixel(x,y).a<0.05: mask[y*hair.get_width()+x]=1
	return mask

func _mask_bounds(mask: PackedByteArray, width: int) -> Rect2i:
	var result := Rect2i()
	for index in range(mask.size()):
		if mask[index] == 0: continue
		var pixel := Rect2i(index % width, index / width, 1, 1)
		result = pixel if result.size == Vector2i.ZERO else result.merge(pixel)
	return result

func _connected_face_opening_mask(hair: Image, opening: Rect2i) -> PackedByteArray:
	# Keep only the transparent channel connected to the measured face opening.
	# Isolated holes in crown curls must never expose source-tuft scalp colors.
	var width := hair.get_width()
	var height := hair.get_height()
	var interior := PackedByteArray()
	interior.resize(width * height)
	for y in range(height):
		var left := width
		var right := -1
		for x in range(width):
			if hair.get_pixel(x,y).a > 0.4:
				left = mini(left,x)
				right = x
		for x in range(left + 1,right): interior[y * width + x] = 1
	var seed := -1
	var closest := INF
	var bounds := opening.intersection(Rect2i(0,0,width,height))
	for y in range(bounds.position.y,bounds.end.y):
		for x in range(bounds.position.x,bounds.end.x):
			if interior[y * width + x] == 0 or hair.get_pixel(x,y).a >= 0.4: continue
			var distance := Vector2(x,y).distance_squared_to(Vector2(opening.get_center()))
			if distance < closest:
				closest = distance
				seed = y * width + x
	var mask := PackedByteArray()
	mask.resize(width * height)
	if seed < 0: return PackedByteArray()
	var queue := PackedInt32Array([seed])
	mask[seed] = 1
	var cursor := 0
	while cursor < queue.size():
		var index := queue[cursor]
		cursor += 1
		var point := Vector2i(index % width,index / width)
		for offset in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var next: Vector2i = point + offset
			if next.x < 0 or next.x >= width or next.y < 0 or next.y >= height: continue
			var neighbor := next.y * width + next.x
			if mask[neighbor] != 0 or interior[neighbor] == 0 or hair.get_pixelv(next).a >= 0.4: continue
			mask[neighbor] = 1
			queue.append(neighbor)
	# Fill underneath the opening's partially transparent antialias boundary.
	# These neighbours are not flood seeds, so a fringe cannot bridge curls.
	for index in queue:
		var point := Vector2i(index % width,index / width)
		for dy in range(-1,2):
			for dx in range(-1,2):
				var next := point + Vector2i(dx,dy)
				if next.x < 0 or next.x >= width or next.y < 0 or next.y >= height: continue
				var neighbor := next.y * width + next.x
				if interior[neighbor] != 0 and hair.get_pixelv(next).a < 1.0: mask[neighbor] = 1
	return mask

func _blend_registered_hair(image: Image, hair: Image, direction: String, crown_y: int, shift_x: int, target_width: float, source_pose: Image, source_metrics: Dictionary = {}, hair_metadata: Dictionary = {}, skull_skin_color: Color = Color("#e8b991")) -> void:
	var used: Rect2i = hair_metadata.used if hair_metadata.has("used") else hair.get_used_rect()
	var ratio := target_width * float(image.get_width()) / CANVAS_SIZE.x / maxi(1, used.size.x)
	var opening: Rect2i = hair_metadata.opening if hair_metadata.has("opening") else _hair_face_opening(hair)
	var target_face := Rect2i()
	var source_bounds := Rect2i()
	if source_pose != null:
		var metrics := source_metrics if not source_metrics.is_empty() else _build_source_hair_metrics(source_pose, _closest_cardinal(direction))
		source_bounds = metrics.source_bounds
		target_face = metrics.target_face
		if source_bounds.size.x > 0:
			ratio = float(source_bounds.size.x) * 1.05 / maxi(1, used.size.x)
	# Use one uniform scale: the face opening constrains registration, never
	# independently stretch x/y or fit the body to a changed hairstyle.
	var resized := Vector2i(maxi(1, roundi(hair.get_width() * ratio)), maxi(1, roundi(hair.get_height() * ratio)))
	var position := Vector2i(image.get_width() / 2 + shift_x, crown_y) - Vector2i(roundi(used.get_center().x * ratio), roundi(used.position.y * ratio))
	if opening.size.x > 0 and target_face.size.x > 0 and not direction.begins_with("back"):
		position.x = roundi(target_face.get_center().x - opening.get_center().x * ratio)
		position.y = target_face.position.y - roundi(opening.position.y * ratio)
	elif source_bounds.size.x > 0:
		position.x = roundi(source_bounds.get_center().x - used.get_center().x * ratio)
		position.y = source_bounds.position.y - roundi(used.position.y * ratio)
	if bool(source_metrics.get("constrain_crown", false)) and source_bounds.size.x > 0:
		# The cream forelock is higher than the anatomical face opening. Letting
		# that patch register a new cut raises the whole wig and enlarges scalp.
		position.y = maxi(position.y, source_bounds.position.y - roundi(used.position.y * ratio))
	hair.resize(resized.x, resized.y, Image.INTERPOLATE_NEAREST)
	var constrained_opening := PackedByteArray()
	if bool(source_metrics.get("constrain_crown", false)):
		constrained_opening = _connected_face_opening_mask(hair, _hair_face_opening(hair))
	# Reconstruct only the existing, source-opaque anatomical head contour.
	# Cut alpha tells us which samples are exposed, including open-bottom cuts.
	var underlay_indices: PackedInt32Array = source_metrics.get("skull_underlay_indices", PackedInt32Array())
	var underlay_colors: PackedColorArray = source_metrics.get("skull_underlay_colors",PackedColorArray())
	for sample_index in range(underlay_indices.size()):
		var index := underlay_indices[sample_index]
		var source_point := Vector2i(index % image.get_width(), index / image.get_width())
		var local_point := source_point - position
		var inside_cut := local_point.x>=0 and local_point.y>=0 and local_point.x<hair.get_width() and local_point.y<hair.get_height()
		# A pointed source-hair tuft is not exposed scalp. For registered idle
		# cuts, fill only the actual transparent face opening between strands.
		if not constrained_opening.is_empty() and (not inside_cut or constrained_opening[local_point.y * hair.get_width() + local_point.x] == 0):
			continue
		var exposed := not inside_cut or hair.get_pixelv(local_point).a<1.0
		if exposed:
			# Bob's side strands end above the nose: requiring enclosed hair alpha
			# leaves rectangular holes there. These samples are already bounded by
			# the source head contour and exclude all semantic facial features;
			# features are restored byte-for-byte after the cut is composited.
			# Source palette colors are mapped exactly once by _apply_palette.
			var raw_color := underlay_colors[sample_index] if sample_index<underlay_colors.size() else Color("#fdbb7b")
			image.set_pixelv(source_point,_shade_preserving(raw_color,Color("#fdbb7b"),skull_skin_color))
	image.blend_rect(hair, Rect2i(Vector2i.ZERO, resized), position)

func _hair_attachment_anchor(hair: Image) -> Vector2i:
	# Side tufts can be taller than the crown. Anchor on the topmost opaque
	# pixel in the central scalp band, rather than the whole cut's used-rect top.
	var band_left := roundi(float(hair.get_width()) * 0.35)
	var band_right := roundi(float(hair.get_width()) * 0.65)
	for y in range(hair.get_height()):
		var total_x := 0
		var count := 0
		for x in range(band_left, band_right):
			if hair.get_pixel(x, y).a > 0.4:
				total_x += x
				count += 1
		if count > 0:
			return Vector2i(roundi(float(total_x) / float(count)), y)
	return Vector2i(hair.get_width() / 2, 0)

func _walk_source_hair_metrics(direction: String, frame: int, source: Image) -> Dictionary:
	var key := "%s:%d" % [direction, frame]
	if _walk_source_metrics_cache.has(key):
		return _walk_source_metrics_cache[key]
	var metrics := _build_source_hair_metrics(source, direction)
	_walk_source_metrics_cache[key] = metrics
	_source_metrics_build_count += 1
	assert(_walk_source_metrics_cache.size() <= WALK_SOURCE_METRICS_LIMIT)
	return metrics

func _authored_source_hair_metrics(source: Image, direction: String, action: String) -> Dictionary:
	var guide: Image
	if action == "idle" and direction in ["front_left", "front_right"]:
		var neutral: Texture2D = animation_library.texture("traveller", "idle", direction, 0)
		if neutral != null: guide = neutral.get_image()
	var metrics := _build_source_hair_metrics(source, direction, guide)
	var geometry_valid: bool = not metrics.skull_underlay_indices.is_empty() and not metrics.face_indices.is_empty()
	metrics["replacement_geometry_valid"] = geometry_valid
	metrics["constrain_crown"] = guide != null and geometry_valid
	return metrics

func _build_source_hair_metrics(source: Image, direction: String, eye_guide: Image = null) -> Dictionary:
	var source_hair_mask := _source_hair_mask(source, direction)
	var skin_bounds_out: Array = [Rect2i()]
	var face_mask := _source_face_mask(source, source_hair_mask, skin_bounds_out)
	var source_bounds := _mask_bounds(source_hair_mask, source.get_width())
	var skin_bounds: Rect2i = skin_bounds_out[0]
	var guide_eyes: Array[Rect2i] = []
	if eye_guide != null and eye_guide.get_size() == source.get_size() and direction in ["front_left", "front_right"]:
		var guide_hair := _source_hair_mask(eye_guide, direction)
		var guide_bounds := _mask_bounds(guide_hair, source.get_width())
		# Only borrow registration from the neutral cel of the same authored
		# direction. No guide pixels are copied into a closed-eye expression.
		if guide_bounds.size.x > 0 and abs(source_bounds.size.x - guide_bounds.size.x) <= 8 and abs(source_bounds.size.y - guide_bounds.size.y) <= 8:
			var delta := Vector2i(roundi(source_bounds.get_center().x - guide_bounds.get_center().x), source_bounds.position.y - guide_bounds.position.y)
			for eye in _source_eye_regions(eye_guide, guide_bounds):
				guide_eyes.append(Rect2i(eye.position + delta, eye.size))
	var face_layers := _semantic_face_layers(source,direction,source_hair_mask,source_bounds,skin_bounds,guide_eyes)
	var replacement_mask := source_hair_mask.duplicate()
	if not face_layers.is_empty():
		face_mask = face_layers.face_mask
		for index in face_layers.skull_indices: replacement_mask[index]=1
		for index in range(face_mask.size()):
			if face_mask[index]!=0:
				source_hair_mask[index]=0
				replacement_mask[index]=0
	return {
		"source_hair_mask": source_hair_mask,
		"face_mask": face_mask,
		"source_hair_indices": _mask_indices(source_hair_mask),
		"replacement_source_mask":replacement_mask,
		"replacement_source_indices":_mask_indices(replacement_mask),
		"face_indices": _mask_indices(face_mask),
		"source_bounds": source_bounds,
		"skin_bounds": skin_bounds,
		"skull_underlay_indices": face_layers.get("skull_indices",PackedInt32Array()),
		"skull_underlay_colors": face_layers.get("skull_colors",PackedColorArray()),
		"skull_contour": face_layers.get("skull_contour",PackedVector2Array()),
		"face_features_named": face_layers.get("features",{}),
		"side_open_head":direction in ["right","left","back_right","back_left"],
		"target_face": face_layers.get("target_face",_mask_bounds(face_mask,source.get_width())),
	}

func _source_eye_regions(source: Image, hair_bounds: Rect2i) -> Array[Rect2i]:
	var width := source.get_width()
	var limit := mini(source.get_height(),roundi(source.get_height()*0.55))
	var visited := PackedByteArray()
	visited.resize(width*limit)
	var eyes: Array[Rect2i] = []
	# Authored eye whites seed complete enclosed non-skin components. The cream
	# forehead fringe is not an eye: its connected component spans the crown.
	for y in range(maxi(0,hair_bounds.position.y),limit):
		for x in range(maxi(0,hair_bounds.position.x),mini(width,hair_bounds.end.x)):
			var index := y*width+x
			var color := source.get_pixel(x,y)
			if visited[index]!=0 or color.a<=0.4 or color.s>0.11 or color.v<0.74: continue
			var queue := PackedInt32Array([index])
			visited[index]=1
			var bounds := Rect2i(x,y,1,1)
			var cursor := 0
			while cursor<queue.size():
				var item := queue[cursor]
				cursor+=1
				var point := Vector2i(item%width,item/width)
				bounds=bounds.merge(Rect2i(point,Vector2i.ONE))
				for offset in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
					var next: Vector2i = point+offset
					if next.x<0 or next.x>=width or next.y<0 or next.y>=limit: continue
					var neighbor := next.y*width+next.x
					if visited[neighbor]!=0: continue
					var pixel := source.get_pixelv(next)
					if pixel.a>0.4 and not _is_color_family(pixel,Color("#fdbb7b"),0.055,0.25):
						visited[neighbor]=1
						queue.append(neighbor)
			if queue.size()>=6 and bounds.size.x>=3 and bounds.size.x<hair_bounds.size.x*0.24 and bounds.size.y>=6 and bounds.size.y<hair_bounds.size.y*0.30:
				eyes.append(bounds)
	eyes.sort_custom(func(a: Rect2i,b: Rect2i)->bool: return a.position.x<b.position.x)
	return eyes

func _semantic_face_layers(source: Image, direction: String, hair_mask: PackedByteArray, hair_bounds: Rect2i, skin_bounds: Rect2i, guide_eyes: Array[Rect2i] = []) -> Dictionary:
	var eyes := _source_eye_regions(source,hair_bounds)
	var guided_blink := eyes.is_empty() and not guide_eyes.is_empty()
	if eyes.is_empty(): eyes = guide_eyes
	if eyes.is_empty(): return _side_face_layers(source,direction,hair_mask,hair_bounds,skin_bounds)
	var width := source.get_width()
	var height := source.get_height()
	var mask := PackedByteArray()
	mask.resize(width*height)
	var features := {}
	var all_eyes := eyes[0]
	# These named brow contours were measured against the actual authored eye
	# components, including brows touching the old fringe. A color flood cannot
	# separate those shared ink components. Normalize per cel to its own eye.
	var brow_shapes := {
		"front":[[Vector2(0,-10),Vector2(3,-10),Vector2(15,-2),Vector2(16,1),Vector2(10,-2),Vector2(0,-7)],[Vector2(0,-3),Vector2(3,-7),Vector2(12,-12),Vector2(16,-10),Vector2(16,-6),Vector2(5,-1),Vector2(0,2)]],
		"front_right":[[Vector2(2,-6),Vector2(5,-7),Vector2(16,-1),Vector2(17,1),Vector2(13,-1),Vector2(3,-3)],[Vector2(0,-2),Vector2(6,-6),Vector2(11,-8),Vector2(12,-5),Vector2(8,-2),Vector2(1,2)]],
		"right":[[Vector2(1,-8),Vector2(7,-8),Vector2(16,-1),Vector2(16,1),Vector2(11,-1),Vector2(1,-5)]],
		"left":[[Vector2(-3,-3),Vector2(-1,-6),Vector2(8,-8),Vector2(11,-6),Vector2(7,-3),Vector2(0,2)]],
		"front_left":[[Vector2(0,-8),Vector2(3,-7),Vector2(13,-1),Vector2(14,1),Vector2(10,0),Vector2(1,-4)],[Vector2(1,-3),Vector2(8,-7),Vector2(15,-9),Vector2(19,-6),Vector2(14,-4),Vector2(5,1),Vector2(0,1)]],
	}
	var reference_sizes := {"front":[Vector2(16,16),Vector2(15,16)],"front_right":[Vector2(17,17),Vector2(12,17)],"right":[Vector2(15,18)],"left":[Vector2(13,18)],"front_left":[Vector2(14,18),Vector2(18,17)]}
	for eye_index in range(eyes.size()):
		var eye := eyes[eye_index]
		all_eyes=all_eyes.merge(eye)
		# Closed lashes extend a few pixels beyond the neutral eye-white box.
		var eye_guard := eye.grow(3 if guided_blink else 1).intersection(Rect2i(0,0,width,height))
		var eye_pixels := PackedInt32Array()
		for y in range(eye_guard.position.y,eye_guard.end.y):
			for x in range(eye_guard.position.x,eye_guard.end.x):
				if source.get_pixel(x,y).a>0.4:
					mask[y*width+x]=1
					eye_pixels.append(y*width+x)
		features["eye_%d" % eye_index]=eye_pixels
		if not brow_shapes.has(direction) or eye_index>=brow_shapes[direction].size(): continue
		var polygon := PackedVector2Array()
		var reference: Vector2 = reference_sizes[direction][eye_index]
		for point: Vector2 in brow_shapes[direction][eye_index]: polygon.append(Vector2(eye.position)+point*Vector2(eye.size)/reference)
		var brow_pixels := PackedInt32Array()
		for y in range(maxi(0,eye.position.y-16),mini(height,eye.position.y+3)):
			for x in range(maxi(0,eye.position.x-5),mini(width,eye.end.x+6)):
				if Geometry2D.is_point_in_polygon(Vector2(x+0.5,y+0.5),polygon) and source.get_pixel(x,y).a>0.4 and hair_mask[y*width+x]==0:
					mask[y*width+x]=1
					brow_pixels.append(y*width+x)
		features["brow_%d" % eye_index]=brow_pixels
	# The visible cheek row supplies the anatomical face width without the ear
	# or cream fringe enlarging a skin bbox. Source crown samples close a convex
	# head contour; filling is later clipped to the cut's actual per-row opening.
	var cheek_y := mini(height-1,all_eyes.end.y+2)
	var center_x := roundi(all_eyes.get_center().x)
	var left := center_x
	var right := center_x
	while left>0 and _is_color_family(source.get_pixel(left-1,cheek_y),Color("#fdbb7b"),0.055,0.25): left-=1
	while right+1<width and _is_color_family(source.get_pixel(right+1,cheek_y),Color("#fdbb7b"),0.055,0.25): right+=1
	if right-left<all_eyes.size.x*0.60:
		left=all_eyes.position.x-3
		right=all_eyes.end.x+3
	# Ears can join the cheek run. The measured eye spread bounds the face core.
	left=maxi(left,all_eyes.position.x-roundi(all_eyes.size.y*0.30))
	right=mini(maxi(right,all_eyes.end.x-1),all_eyes.end.x+roundi(all_eyes.size.y*0.30))
	var contour_points := PackedVector2Array()
	var colors := PackedColorArray()
	var skin_component := PackedByteArray()
	skin_component.resize(width*height)
	var skin_queue := PackedInt32Array([cheek_y*width+center_x])
	skin_component[skin_queue[0]]=1
	var cursor := 0
	while cursor<skin_queue.size():
		var index := skin_queue[cursor]
		cursor+=1
		var point := Vector2i(index%width,index/width)
		for offset in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var next: Vector2i = point+offset
			if next.x<0 or next.x>=width or next.y<0 or next.y>=roundi(height*0.60): continue
			var neighbor := next.y*width+next.x
			if skin_component[neighbor]==0 and source.get_pixelv(next).a>0.4 and _is_color_family(source.get_pixelv(next),Color("#fdbb7b"),0.055,0.25):
				skin_component[neighbor]=1
				skin_queue.append(neighbor)
	for x in range(left,right+1):
		# Use the actual source cheek surface palette, not a previously selected
		# skin color that would be palette-mapped twice. A shared sample avoids
		# projecting nose/cheek pixel columns as vertical forehead stripes.
		colors.append(source.get_pixel(center_x,cheek_y))
		for y in range(maxi(0,hair_bounds.position.y),cheek_y+1):
			if source.get_pixel(x,y).a>0.4:
				contour_points.append(Vector2(x,y))
				contour_points.append(Vector2(x+1,y+1))
				break
	# Preserve the real lower face/ear/neck contour and mouth, not old forehead
	# skin-neighbourhood pixels or transparent pixels over replacement hair.
	var lower_pixels := PackedInt32Array()
	var ear_pixels := PackedInt32Array()
	var skull_left := left
	var skull_right := right
	for index in skin_queue:
		var point := Vector2i(index%width,index/width)
		if point.y<all_eyes.end.y:
			contour_points.append(Vector2(point))
			contour_points.append(Vector2(point+Vector2i.ONE))
			skull_left=mini(skull_left,point.x)
			skull_right=maxi(skull_right,point.x)
	for y in range(all_eyes.position.y,mini(height,roundi(height*0.60))):
		for x in range(maxi(0,skin_bounds.position.x-2),mini(width,skin_bounds.end.x+2)):
			var color := source.get_pixel(x,y)
			if color.a<=0.4: continue
			var skin_neighbor := skin_component[y*width+x]!=0
			for ny in range(maxi(0,y-2),mini(height,y+3)):
				for nx in range(maxi(0,x-2),mini(width,x+3)):
					if skin_component[ny*width+nx]!=0: skin_neighbor=true
			if skin_neighbor and (y>=all_eyes.end.y or x<left or x>right):
				mask[y*width+x]=1
				if y>=all_eyes.end.y: lower_pixels.append(y*width+x)
				else: ear_pixels.append(y*width+x)
				if x>=left and x<=right and _is_color_family(color,Color("#fdbb7b"),0.055,0.25): contour_points.append(Vector2(x,y))
	features["lower_face_mouth"]=lower_pixels
	features["ears"]=ear_pixels
	var contour := Geometry2D.convex_hull(contour_points)
	var indices := PackedInt32Array()
	var skull_colors := PackedColorArray()
	for y in range(maxi(0,hair_bounds.position.y),all_eyes.end.y):
		for x in range(maxi(0,skull_left),mini(width,skull_right+1)):
			var index := y*width+x
			if mask[index]==0 and source.get_pixel(x,y).a>0.4 and Geometry2D.is_point_in_polygon(Vector2(x+0.5,y+0.5),contour):
				indices.append(index)
				skull_colors.append(colors[clampi(x-left,0,colors.size()-1)])
	return {"face_mask":mask,"features":features,"skull_indices":indices,"skull_colors":skull_colors,"skull_contour":contour,"target_face":Rect2i(left,skin_bounds.position.y-2,right-left+1,all_eyes.end.y-skin_bounds.position.y+2)}

func _side_face_layers(source: Image,direction: String,hair_mask: PackedByteArray,hair_bounds: Rect2i,skin_bounds: Rect2i) -> Dictionary:
	if direction not in ["back_right","back_left"] or skin_bounds.size.x<=0: return {}
	var width := source.get_width()
	var mask := PackedByteArray()
	mask.resize(width*source.get_height())
	var points := PackedVector2Array()
	var face_indices := PackedInt32Array()
	var side_start := skin_bounds.position.y+roundi(skin_bounds.size.y*0.45)
	var skin_source := Color("#fdbb7b")
	var widest_side := -1
	for y in range(skin_bounds.position.y+skin_bounds.size.y/2,mini(source.get_height(),hair_bounds.end.y)):
		var count := 0
		for x in range(maxi(0,skin_bounds.position.x),mini(width,skin_bounds.end.x)):
			if _is_color_family(source.get_pixel(x,y),skin_source,0.055,0.25): count+=1
		if count>widest_side:
			widest_side=count
			side_start=maxi(skin_bounds.position.y,y-2)
	var surface_color := skin_source
	var closest := INF
	# Back-quarter cels expose an ear/side face but no eye. Their source skin
	# contour and central crown still prove a solid head beneath an open cut.
	for y in range(skin_bounds.position.y,mini(source.get_height(),hair_bounds.end.y)):
		for x in range(maxi(0,skin_bounds.position.x-2),mini(width,skin_bounds.end.x+2)):
			var color := source.get_pixel(x,y)
			if color.a<=0.4 or not _is_color_family(color,skin_source,0.055,0.25): continue
			points.append(Vector2(x,y))
			points.append(Vector2(x+1,y+1))
			if y>=side_start:
				var distance := Vector3(color.r-skin_source.r,color.g-skin_source.g,color.b-skin_source.b).length_squared()
				if distance<closest:
					closest=distance
					surface_color=color
				for ny in range(maxi(0,y-2),mini(source.get_height(),y+3)):
					for nx in range(maxi(0,x-2),mini(width,x+3)):
						if source.get_pixel(nx,ny).a>0.4: mask[ny*width+nx]=1
	for x in range(hair_bounds.position.x+roundi(hair_bounds.size.x*0.35),hair_bounds.position.x+roundi(hair_bounds.size.x*0.65)):
		for y in range(hair_bounds.position.y,hair_bounds.end.y):
			if hair_mask[y*width+x]!=0:
				points.append(Vector2(x,y))
				points.append(Vector2(x+1,y+1))
				break
	var contour := Geometry2D.convex_hull(points)
	var indices := PackedInt32Array()
	var colors := PackedColorArray()
	for y in range(hair_bounds.position.y,hair_bounds.end.y):
		for x in range(maxi(0,hair_bounds.position.x),mini(width,hair_bounds.end.x)):
			var index := y*width+x
			if mask[index]==0 and source.get_pixel(x,y).a>0.4 and Geometry2D.is_point_in_polygon(Vector2(x+0.5,y+0.5),contour):
				indices.append(index)
				colors.append(surface_color)
	face_indices=_mask_indices(mask)
	return {"face_mask":mask,"features":{"side_face_ear":face_indices},"skull_indices":indices,"skull_colors":colors,"skull_contour":contour,"target_face":skin_bounds}

func _mask_indices(mask: PackedByteArray) -> PackedInt32Array:
	var indices := PackedInt32Array()
	for index in range(mask.size()):
		if mask[index] != 0: indices.append(index)
	return indices

func _cached_hair_cut(hair_style: String, direction: String, hair_color: Color) -> Dictionary:
	var style_row: int = {"windswept": 0, "bob": 1, "curly": 2}.get(hair_style, 0)
	var cardinal := DIRECTIONS.has(direction)
	var direction_index := DIRECTIONS.find(direction) if cardinal else ["front_left", "front_right", "back_left", "back_right"].find(direction)
	if not cardinal and direction == "front_right": direction_index = 0
	if style_row < 0 or style_row >= 3 or direction_index < 0:
		return {}
	var orientation_key := str(direction_index) if cardinal else direction
	var key := ("cardinal" if cardinal else "diagonal") + ":%d:%s" % [style_row, orientation_key]
	var entry: Dictionary = _hair_cut_cache.get(key, {})
	if entry.is_empty():
		var hair: Image
		var source_base := Color("#2a2b48")
		if cardinal:
			var region: Rect2i = _scaled_region(HAIR_REGIONS[style_row][direction_index], float(_hair_atlas_image.get_width()) / HAIR_SOURCE_SIZE.x, float(_hair_atlas_image.get_height()) / HAIR_SOURCE_SIZE.y)
			hair = _hair_atlas_image.get_region(region)
		else:
			hair = _diagonal_hair_regions[style_row][direction_index].duplicate()
			if direction == "front_right": hair.flip_x()
			if style_row == 1: source_base = Color("#6a4137")
		for y in range(hair.get_height()):
			for x in range(hair.get_width()):
				var pixel := hair.get_pixel(x, y)
				if pixel.a < 0.4:
					hair.set_pixel(x, y, Color.TRANSPARENT)
		var variants: Dictionary = {}
		for color_name in HAIR_COLORS:
			var tint: Color = HAIR_COLORS[color_name]
			var tinted: Image = hair.duplicate()
			for y in range(tinted.get_height()):
				for x in range(tinted.get_width()):
					var pixel: Color = tinted.get_pixel(x, y)
					if pixel.a < 0.4: continue
					if cardinal:
						if _is_dark_blue(pixel, Color("#2a2b48")):
							tinted.set_pixel(x, y, _shade_preserving(pixel, Color("#2a2b48"), tint))
					elif pixel.a >= 0.4:
						tinted.set_pixel(x, y, _recolor_hair_shade(pixel, source_base, tint))
			variants[color_name] = tinted
		var opening := _hair_face_opening(hair)
		entry = {
			"used": hair.get_used_rect(),
			"opening": opening,
			"opening_mask": _hair_face_opening_mask(hair,opening),
			"face_opening_valid": not _connected_face_opening_mask(hair,opening).is_empty(),
			"size": hair.get_size(),
			"variants": variants,
		}
		_hair_cut_cache[key] = entry
		_hair_cut_build_count += 1
		assert(_hair_cut_cache.size() <= HAIR_CUT_CACHE_LIMIT)
	var color_key := "ink"
	for candidate in HAIR_COLORS:
		if HAIR_COLORS[candidate] == hair_color:
			color_key = str(candidate)
			break
	var variants: Dictionary = entry.variants
	return {"image": variants[color_key].duplicate(), "used": entry.used, "opening": entry.opening,"opening_mask":entry.opening_mask,"size":entry.size,"face_opening_valid":entry.face_opening_valid}

func _recolor_hair_shade(pixel: Color, source_base: Color, target_base: Color) -> Color:
	var shade := clampf(pixel.v / maxf(source_base.v, 0.08), 0.18, 1.65)
	var recolored := Color(target_base.r * shade, target_base.g * shade, target_base.b * shade, pixel.a)
	recolored.a = pixel.a
	return recolored.clamp()

func _source_hair_mask(source: Image, direction: String) -> PackedByteArray:
	var width := source.get_width()
	var height := source.get_height()
	var mask := PackedByteArray()
	mask.resize(width * height)
	# Walk down from the crown through contiguous source-hair pixels. A broad
	# height-only color mask also catches the similarly colored jacket; this
	# component stays tied to the actual head silhouette and its hanging locks.
	var hair_limit := mini(height, roundi(float(height) * (0.58 if direction.begins_with("back") else 0.54)))
	var queue := PackedInt32Array()
	for y in range(mini(hair_limit, roundi(float(height) * 0.30))):
		for x in range(width):
			var index := y * width + x
			var color := source.get_pixel(x, y)
			if color.a > 0.05 and _is_source_hair(color):
				mask[index] = 1
				queue.append(index)
	var cursor := 0
	while cursor < queue.size():
		var index: int = queue[cursor]
		cursor += 1
		var x := index % width
		var y := index / width
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				if dx == 0 and dy == 0: continue
				var nx := x + dx
				var ny := y + dy
				if nx < 0 or nx >= width or ny < 0 or ny >= hair_limit: continue
				var neighbor := ny * width + nx
				if mask[neighbor] != 0: continue
				var color := source.get_pixel(nx, ny)
				if color.a > 0.05 and _is_source_hair(color):
					mask[neighbor] = 1
					queue.append(neighbor)
	return mask

func _source_face_mask(source: Image, source_hair_mask: PackedByteArray, skin_bounds_out: Array = []) -> PackedByteArray:
	var width := source.get_width()
	var height := source.get_height()
	var skin_mask := PackedByteArray()
	skin_mask.resize(width * height)
	var face_mask := PackedByteArray()
	face_mask.resize(width * height)
	var skin_source := Color("#fdbb7b")
	var face_bottom := mini(height, roundi(float(height) * 0.45))
	var face_left := width
	var face_right := -1
	var face_top := face_bottom
	var face_last_row := -1
	for y in range(face_bottom):
		for x in range(width):
			var color := source.get_pixel(x, y)
			if color.a > 0.4 and _is_color_family(color, skin_source, 0.055, 0.25):
				var index := y * width + x
				skin_mask[index] = 1
				face_left = mini(face_left, x)
				face_right = maxi(face_right, x)
				face_top = mini(face_top, y)
				face_last_row = maxi(face_last_row, y)
	if not skin_bounds_out.is_empty():
		skin_bounds_out[0] = Rect2i(face_left, face_top, face_right - face_left + 1, face_last_row - face_top + 1) if face_right >= face_left and face_last_row >= face_top else Rect2i()
	if face_right < face_left or face_last_row < face_top:
		return face_mask
	const FACE_FEATURE_RADIUS := 4
	for y in range(maxi(0, face_top - FACE_FEATURE_RADIUS), mini(face_bottom, face_last_row + FACE_FEATURE_RADIUS + 1)):
		for x in range(maxi(0, face_left - FACE_FEATURE_RADIUS), mini(width, face_right + FACE_FEATURE_RADIUS + 1)):
			var index := y * width + x
			if source_hair_mask[index] != 0:
				continue
			var found_skin := skin_mask[index] != 0
			for near_y in range(maxi(0, y - FACE_FEATURE_RADIUS), mini(face_bottom, y + FACE_FEATURE_RADIUS + 1)):
				if found_skin:
					break
				for near_x in range(maxi(0, x - FACE_FEATURE_RADIUS), mini(width, x + FACE_FEATURE_RADIUS + 1)):
					if skin_mask[near_y * width + near_x] != 0:
						found_skin = true
						break
			if found_skin and source.get_pixel(x,y).a>0.4:
				face_mask[index] = 1
	return face_mask

func _restore_face_features(image: Image, face_backdrop: Image, face_mask: PackedByteArray, face_indices: PackedInt32Array = PackedInt32Array()) -> void:
	var width := image.get_width()
	if not face_indices.is_empty():
		for index in face_indices:
			image.set_pixel(index % width, index / width, face_backdrop.get_pixel(index % width, index / width))
		return
	var height := image.get_height()
	for y in range(height):
		for x in range(width):
			if face_mask[y * width + x] != 0:
				image.set_pixel(x, y, face_backdrop.get_pixel(x, y))

func _strip_source_hair(image: Image, source_hair_mask: PackedByteArray, source_hair_indices: PackedInt32Array = PackedInt32Array()) -> void:
	var width := image.get_width()
	if not source_hair_indices.is_empty():
		for index in source_hair_indices:
			image.set_pixel(index % width, index / width, Color.TRANSPARENT)
		return
	var height := image.get_height()
	for y in range(height):
		for x in range(width):
			if source_hair_mask[y * width + x] != 0:
				image.set_pixel(x, y, Color.TRANSPARENT)

func _apply_diagonal_hat(image: Image, hat: String, direction: String, vertical_offset: int, head_shift_x: int = 0) -> void:
	var row: int = {"hat-straw": 0, "hat-sailor": 1, "hat-flower": 2}.get(hat, -1)
	var direction_index := ["front_left", "front_right", "back_left", "back_right"].find(direction)
	if row < 0 or row >= _diagonal_hat_regions.size() or direction_index < 0: return
	var hat_image: Image = _diagonal_hat_regions[row][direction_index].duplicate()
	var width := roundi(HAT_TARGET_WIDTHS[row] * float(image.get_width()) / CANVAS_SIZE.x)
	var ratio := float(width) / 314.0
	var height_scale: float = HAT_VERTICAL_SCALE[row]
	var resized_width := maxi(1, roundi(float(hat_image.get_width()) * ratio))
	var resized_height := maxi(1, roundi(float(hat_image.get_height()) * ratio * height_scale))
	hat_image.resize(resized_width, resized_height, Image.INTERPOLATE_NEAREST)
	var crown_offset := roundi(HAT_CROWN_OFFSETS[row] * float(image.get_height()) / CANVAS_SIZE.y)
	var crown_y := maxi(roundi(2.0 * float(image.get_height()) / CANVAS_SIZE.y), vertical_offset + crown_offset)
	image.blend_rect(hat_image, Rect2i(Vector2i.ZERO, Vector2i(resized_width, resized_height)), Vector2i((image.get_width() - resized_width) / 2 + head_shift_x, crown_y))

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

func _apply_species_ears(image: Image, species: String, direction: String, vertical_offset: int, skin_color: Color, head_shift_x: int = 0, selected_head: Image = null, metrics: Dictionary = {}) -> void:
	if species != "elf" or not _species_atlas_valid or selected_head == null: return
	var face: Rect2i = metrics.get("target_face",Rect2i())
	var source_bounds: Rect2i = metrics.get("source_bounds",Rect2i())
	var eye_y := roundi(face.position.y+face.size.y*0.48) if face.size.y>0 else roundi(source_bounds.position.y+source_bounds.size.y*0.45)
	var left := selected_head.get_width()
	var right := -1
	for y in range(maxi(0,eye_y-2),mini(selected_head.get_height(),eye_y+3)):
		for x in range(selected_head.get_width()):
			if selected_head.get_pixel(x,y).a>0.63:
				left = mini(left,x)
				right = maxi(right,x)
	if right<left: return
	var profile := direction in ["left","right"]
	for side in range(2):
		if profile and side != (0 if direction=="right" else 1): continue
		var region: Rect2i = ELF_EAR_REGIONS[(2 if side==0 else 3) if profile else side]
		var part := _species_part_image(region,22 if profile else 36,skin_color)
		var base := _strong_part_base(part)
		var root := Vector2i(left+4 if side==0 else right-4,eye_y)
		image.blend_rect(part,Rect2i(Vector2i.ZERO,Vector2i(part.get_width(),part.get_height())),root-base)

func _hair_color_matches(color: Color, hair_color: Color) -> bool:
	var distance := absf(color.h-hair_color.h)
	return color.a>0.63 and color.s>0.15 and (minf(distance,1.0-distance)<0.065 or _is_source_hair(color))

func _strong_hair_crown(image: Image, hair_color: Color) -> Rect2i:
	var top := image.get_height()
	for y in range(roundi(image.get_height()*0.35)):
		for x in range(image.get_width()):
			if _hair_color_matches(image.get_pixel(x,y),hair_color): top = mini(top,y)
	if top==image.get_height(): return Rect2i()
	var left := image.get_width()
	var right := -1
	for y in range(top,mini(image.get_height(),top+50)):
		for x in range(image.get_width()):
			if _hair_color_matches(image.get_pixel(x,y),hair_color):
				left = mini(left,x)
				right = maxi(right,x)
	return Rect2i(left,top,right-left+1,50)

func _crown_root(image: Image, target_x: int, crown: Rect2i, hair_color: Color) -> Vector2i:
	for offset in range(13):
		for side in [-1,1]:
			var x_center: int = target_x+offset*side
			for y in range(crown.position.y,mini(image.get_height(),crown.end.y)):
				var opaque := 0
				for x in range(maxi(0,x_center-4),mini(image.get_width(),x_center+5)):
					if _hair_color_matches(image.get_pixel(x,y),hair_color): opaque += 1
				if opaque>=6: return Vector2i(x_center,y+5)
	assert(false,"No strong selected-hair crown at horn root")
	return Vector2i.ZERO

func _apply_species_horns(image: Image, species: String, direction: String, vertical_offset: int, head_shift_x: int = 0, hair_color: Color = Color("#293b50")) -> void:
	if species != "imp" or not _species_atlas_valid: return
	var crown := _strong_hair_crown(image,hair_color)
	if crown.size.x<=0:
		push_error("Imp horns require selected hairstyle strong crown geometry")
		return
	var profile := direction in ["left","right"]
	var count := 1 if profile else 2
	for side in range(count):
		var factor := 0.5 if profile else (0.30 if side==0 else 0.70)
		var root := _crown_root(image,roundi(crown.position.x+crown.size.x*factor),crown,hair_color)
		var region: Rect2i = IMP_HORN_REGIONS[0] if profile else IMP_HORN_REGIONS[3 if direction=="back" else 1]
		var part := _species_part_image(region,26 if profile else 31,Color.WHITE,direction=="right" if profile else side==1)
		var base := _strong_part_base(part)
		var position := root-base
		# Complete source tips stay in-canvas while the broad base penetrates hair.
		position.y = maxi(0,position.y)
		image.blend_rect(part,Rect2i(Vector2i.ZERO,Vector2i(part.get_width(),part.get_height())),position)

func _strong_part_base(part: Image) -> Vector2i:
	var bottom := -1
	for y in range(part.get_height()):
		for x in range(part.get_width()):
			if part.get_pixel(x,y).a>0.63: bottom = maxi(bottom,y)
	var sum_x := 0
	var count := 0
	for y in range(maxi(0,bottom-3),bottom+1):
		for x in range(part.get_width()):
			if part.get_pixel(x,y).a>0.63:
				sum_x += x
				count += 1
	assert(count>0,"species part lacks a strong opaque base")
	return Vector2i(roundi(float(sum_x)/count),maxi(0,bottom-2))

func _blend_species_part(image: Image, source_region: Rect2i, target_width: int, target_position: Vector2i, skin_color: Color, flip_horizontal: bool = false) -> void:
	var part := _species_part_image(source_region,target_width,skin_color,flip_horizontal)
	image.blend_rect(part,Rect2i(Vector2i.ZERO,Vector2i(part.get_width(),part.get_height())),target_position)

func _species_part_image(source_region: Rect2i, target_width: int, skin_color: Color, flip_horizontal: bool = false) -> Image:
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
	return part

func _is_source_hair(color: Color) -> bool:
	var reference := Color("#2a2b48")
	var distance := absf(color.h - reference.h)
	return color.v > 0.025 and color.v < 0.58 and color.s > 0.15 and minf(distance, 1.0 - distance) < 0.065

func _apply_hair_atlas(image: Image, hair_style: String, direction: String, hair_color: Color, vertical_offset: int, head_shift_x: int = 0, target_width_override: float = HAIR_TARGET_WIDTH, source_pose: Image = null, source_metrics: Dictionary = {}, skull_skin_color: Color = Color("#e8b991")) -> void:
	var row: int = {"windswept": 0, "bob": 1, "curly": 2}.get(hair_style, 0)
	var column := DIRECTIONS.find(direction)
	if column < 0: column = 0
	var cut := _cached_hair_cut(hair_style, direction, hair_color)
	if cut.is_empty(): return
	_blend_registered_hair(image, cut.image, direction, vertical_offset, head_shift_x, target_width_override, source_pose, source_metrics, cut, skull_skin_color)

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

func _apply_hat(image: Image, hat: String, direction: String, vertical_offset: int, head_shift_x: int = 0) -> void:
	if hat == "hat-none": return
	if _hat_atlas_valid:
		var row: int = {"hat-straw": 0, "hat-sailor": 1, "hat-flower": 2}.get(hat, -1)
		if row >= 0:
			_apply_hat_atlas(image, row, DIRECTIONS.find(direction), vertical_offset, head_shift_x)
			return
	var sx := float(image.get_width()) / 64.0
	var sy := float(image.get_height()) / 96.0
	var color := Color("#d8bb77") if hat == "hat-straw" else (Color("#f2f1e8") if hat == "hat-sailor" else Color("#d8789b"))
	if hat == "hat-flower":
		for offset in [-6, 0, 6]: _draw_rect(image, head_shift_x + int((31+offset)*sx), int(5*sy), maxi(2, int(5*sx)), maxi(2, int(5*sy)), color.lightened(0.16 if offset == 0 else 0.0))
		_draw_rect(image, head_shift_x + int(31*sx), int(5*sy), maxi(2, int(4*sx)), maxi(2, int(4*sy)), Color("#edbb65"))
	elif hat == "hat-sailor":
		_draw_rect(image, head_shift_x + int(17*sx), int(5*sy), int(30*sx), int(7*sy), color)
		_draw_rect(image, head_shift_x + int(13*sx), int(11*sy), int(39*sx), int(3*sy), Color("#36536a"))
		_draw_rect(image, head_shift_x + int(19*sx), int(8*sy), int(26*sx), int(2*sy), Color("#36536a"))
	else:
		_draw_rect(image, head_shift_x + int(18*sx), int(6*sy), int(28*sx), int(4*sy), color)
		_draw_rect(image, head_shift_x + int(10*sx), int(10*sy), int(45*sx), int(3*sy), color.darkened(0.1))
		_draw_rect(image, head_shift_x + int(25*sx), int(10*sy), int(13*sx), int(2*sy), Color("#815e42"))
	# Profile hats extend forward so the face remains visible; rear hats stay centered.
	if direction == "left": _draw_rect(image, head_shift_x + int(9*sx), int(11*sy), int(8*sx), int(2*sy), color)
	elif direction == "right": _draw_rect(image, head_shift_x + int(47*sx), int(11*sy), int(8*sx), int(2*sy), color)

func _apply_hat_atlas(image: Image, row: int, column: int, vertical_offset: int, head_shift_x: int = 0) -> void:
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
	var position := Vector2i((image.get_width() - resized.x) / 2 + head_shift_x, crown_y)
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
