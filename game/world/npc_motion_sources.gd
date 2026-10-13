extends RefCounted
## Candidate-only two-view NPC source provider for AvatarMotionRig measurement.
## No image colors are changed and unsupported views are never mirrored.

const METADATA_PATH := "res://assets/characters/npc-motion-regions.json"
const CANVAS_SIZE := Vector2i(280, 360)
const SUPPORTED_VIEWS: Array[String] = ["left", "right"]

var _metadata: Dictionary = {}
var _source_cache: Dictionary = {}
var diagnostics: Array[String] = []

func _init() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(METADATA_PATH))
	if parsed is Dictionary:
		_metadata = parsed
	else:
		diagnostics.append("Could not load NPC source metadata: " + METADATA_PATH)

func measurements_for(role: String) -> Dictionary:
	var roles: Dictionary = _metadata.get("roles", {})
	return roles.get(role, {})

func direction_measurement(role: String, view: String) -> Dictionary:
	var role_record := measurements_for(role)
	var directions: Dictionary = role_record.get("directions", {})
	var measurement: Dictionary = directions.get(view, {})
	if role=="ticket" and not measurement.is_empty():
		# Runtime's two fixed bones use the mean of these direction scales. The
		# crop's top row is not the anatomical ankle; reject a stale chain record.
		var hips: Array = measurement.get("hip_points",[])
		var anatomy: Dictionary = measurement.get("measurements",{})
		var leg: Dictionary = measurement.get("leg_measurement",{})
		if hips.size()!=2 or not anatomy.has("ankle_row_px") or not leg.has("rig_reference_chain_m"):
			diagnostics.append("Ticket fixed chain has incomplete anatomical measurements: "+view)
			return {}
		var hip_row := (float(hips[0][1])+float(hips[1][1]))*0.5
		var ankle_row := float(anatomy.ankle_row_px)
		var distance_px := ankle_row-hip_row
		var distance_m := distance_px*2.4/360.0
		var reference := float(leg.rig_reference_chain_m)
		if reference<=0.0 or distance_m<=0.0 or absf(float(leg.get("ankle_y_px",-1))-ankle_row)>0.00001 or absf(float(leg.get("hip_to_ankle_px",-1))-distance_px)>0.00001 or absf(float(leg.get("source_hip_to_ankle_m",-1))-distance_m)>0.00001 or absf(float(leg.get("leg_length_scale",-1))-distance_m/reference)>0.00001:
			diagnostics.append("Ticket fixed chain disagrees with measured hip-to-ankle rows: "+view)
			return {}
	return measurement

## Signature is compatible with AvatarMotionRig.source_provider.
func provide(role: String, view: String, _appearance: Dictionary = {}, _equipment: Dictionary = {}) -> Dictionary:
	if role not in ["ticket", "imp", "announcer"] or view not in SUPPORTED_VIEWS:
		return {}
	var key := role + ":" + view
	if not _source_cache.has(key):
		var generated := _normalize_candidate(role, view)
		if generated.is_empty():
			return {}
		_source_cache[key] = generated
	var cached: Dictionary = _source_cache[key]
	return {"source": cached.source.duplicate(), "raw": cached.raw.duplicate(), "candidate_only": true, "atlas_sha256": cached.atlas_sha256, "source_rect": cached.source_rect.duplicate()}

func _normalize_candidate(role: String, view: String) -> Dictionary:
	var role_record := measurements_for(role)
	var measurement := direction_measurement(role, view)
	if role_record.is_empty() or measurement.is_empty():
		diagnostics.append("No measured NPC source for %s/%s" % [role, view])
		return {}
	var atlas_path := str(role_record.get("source_atlas", ""))
	var absolute_path := ProjectSettings.globalize_path(atlas_path)
	var actual_hash := FileAccess.get_sha256(absolute_path)
	var expected_hash := str(role_record.get("source_sha256", ""))
	if actual_hash.is_empty() or actual_hash != expected_hash:
		diagnostics.append("Candidate source hash mismatch for %s: expected %s got %s" % [atlas_path, expected_hash, actual_hash])
		return {}
	var atlas := Image.new()
	if atlas.load(absolute_path) != OK:
		diagnostics.append("Could not decode candidate atlas: " + atlas_path)
		return {}
	var rect := rect_from_values(measurement.get("source_rect", []))
	var atlas_bounds := Rect2i(Vector2i.ZERO, atlas.get_size())
	if rect.size.x <= 0 or rect.size.y <= 0 or not atlas_bounds.encloses(rect):
		diagnostics.append("Measured candidate bounds outside source atlas: %s/%s" % [role, view])
		return {}
	var target_height := int(role_record.get("target_body_height_px", 0))
	var width_limit := 276
	var feet_row := 346
	var scale := minf(float(target_height) / float(rect.size.y), float(width_limit) / float(rect.size.x))
	var normalized_size := Vector2i(maxi(1, roundi(rect.size.x * scale)), maxi(1, roundi(rect.size.y * scale)))
	var destination := Vector2i((CANVAS_SIZE.x - normalized_size.x) / 2, feet_row - normalized_size.y)
	var body := atlas.get_region(rect)
	body.resize(normalized_size.x, normalized_size.y, Image.INTERPOLATE_NEAREST)
	var normalized := Image.create(CANVAS_SIZE.x, CANVAS_SIZE.y, false, Image.FORMAT_RGBA8)
	normalized.fill(Color.TRANSPARENT)
	normalized.blit_rect(body, Rect2i(Vector2i.ZERO, normalized_size), destination)
	var expected_norm: Dictionary = measurement.get("normalization", {})
	var expected_size_values: Array = expected_norm.get("destination_body_size", [])
	var expected_origin_values: Array = expected_norm.get("destination_origin", [])
	if expected_size_values.size() != 2 or expected_origin_values.size() != 2:
		diagnostics.append("Normalization measurements are incomplete for %s/%s" % [role, view])
		return {}
	var expected_size := Vector2i(int(expected_size_values[0]), int(expected_size_values[1]))
	var expected_origin := Vector2i(int(expected_origin_values[0]), int(expected_origin_values[1]))
	if normalized_size != expected_size or destination != expected_origin:
		diagnostics.append("Normalization measurements disagree for %s/%s" % [role, view])
		return {}
	return {"source": normalized, "raw": normalized.duplicate(), "atlas_sha256": actual_hash, "source_rect": measurement.source_rect.duplicate()}

## Measures all strong-alpha pixels within the selected half. The reviewed
## candidate sheets have one dominant opaque figure per half and no strong
## alpha satellites outside these bounds.
static func strong_alpha_bounds(image: Image, half_rect: Rect2i, alpha_threshold: int = 128) -> Rect2i:
	var min_x := half_rect.end.x
	var min_y := half_rect.end.y
	var max_x := -1
	var max_y := -1
	var clipped := half_rect.intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	for y in range(clipped.position.y, clipped.end.y):
		for x in range(clipped.position.x, clipped.end.x):
			if roundi(image.get_pixel(x, y).a * 255.0) < alpha_threshold:
				continue
			min_x = mini(min_x, x)
			min_y = mini(min_y, y)
			max_x = maxi(max_x, x)
			max_y = maxi(max_y, y)
	if max_x < min_x or max_y < min_y:
		return Rect2i()
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)

static func rect_from_values(values: Array) -> Rect2i:
	if values.size() != 4:
		return Rect2i()
	return Rect2i(int(values[0]), int(values[1]), int(values[2]), int(values[3]))
