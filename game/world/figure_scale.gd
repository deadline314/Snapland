extends RefCounted
## Brings every drawn character source back to the size of the standing figure.
## The factors are baked into TABLE_PATH by game/tests/test_figure_scale.gd, so
## nothing is measured while the game runs.
##
## An entry keeps the ground contact fixed and may scale the head and the body
## by different amounts: some source sheets draw a larger head on a shorter
## body, and one uniform factor cannot bring both back to the standing figure.

const TABLE_PATH := "res://assets/characters/figure-scale.json"
## Factors closer to 1 than this are not worth a resample.
const MINIMUM_CHANGE := 0.02
## Up to this much change is resampled without smoothing.
const GENTLE_CHANGE := 0.1

static var _table: Dictionary = {}
static var _loaded := false

static func table() -> Dictionary:
	if not _loaded:
		_loaded = true
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(TABLE_PATH)) if FileAccess.file_exists(TABLE_PATH) else null
		if parsed is Dictionary and int(parsed.get("schema_version", 0)) == 1:
			_table = parsed
		else:
			push_warning("FigureScale: %s is missing or invalid; characters keep their drawn size." % TABLE_PATH)
	return _table

## Replaces the baked table; the bake and its test use this to see raw frames.
static func use_table(replacement: Dictionary) -> void:
	_table = replacement
	_loaded = true

static func reload() -> void:
	_loaded = false

static func entry(actor: String, source: String) -> Dictionary:
	var sources: Variant = table().get("sources", {}).get(actor, {})
	var found: Variant = sources.get(source, {}) if sources is Dictionary else {}
	return found if found is Dictionary else {}

## Returns `image` itself when the entry asks for no change.
static func refit(image: Image, found: Dictionary, frame: int = 0) -> Image:
	var head := float(found.get("head", 1.0))
	var body_value: Variant = found.get("body", [head, head])
	var body := Vector2(float(body_value[0]), float(body_value[1]))
	var feet_value: Variant = found.get("feet", [image.get_width() / 2, image.get_height() - 1])
	var feet := Vector2(float(feet_value[0]), float(feet_value[1]))
	var plant_value: Variant = found.get("plant", feet_value)
	var plant := Vector2(float(plant_value[0]), float(plant_value[1]))
	var width := image.get_width()
	var height := image.get_height()
	var whole := Rect2i(0, 0, width, height)
	var scaled := absf(head - 1.0) > MINIMUM_CHANGE or absf(body.x - 1.0) > MINIMUM_CHANGE or absf(body.y - 1.0) > MINIMUM_CHANGE
	var output := Image.create(width, height, false, image.get_format())
	if not scaled:
		var shift := Vector2i(roundi(plant.x - feet.x), roundi(plant.y - feet.y))
		if shift == Vector2i.ZERO:
			return image
		output.blit_rect(image, whole, shift)
		return output
	var ground := clampi(int(feet.y) + 1, 1, height)
	var neck := Vector2i(ground, ground)
	var necks: Variant = found.get("neck_rows", [])
	if necks is Array and not necks.is_empty() and (absf(head - body.x) > 0.001 or absf(head - body.y) > 0.001):
		var rows: Variant = necks[clampi(frame, 0, necks.size() - 1)]
		neck = Vector2i(clampi(int(rows[0]), 0, ground), clampi(int(rows[1]), 0, ground))
	else:
		body = Vector2(head, head)
	# Strips are laid from the ground upwards so the contact row never moves.
	var cursor := plant.y + 1.0
	# A small correction keeps pixel cels crisp; a large one needs the smoother filter.
	var gentle := maxf(absf(head - 1.0), maxf(absf(body.x - 1.0), absf(body.y - 1.0))) <= GENTLE_CHANGE
	var filter := Image.INTERPOLATE_NEAREST if gentle else Image.INTERPOLATE_BILINEAR
	var source := image
	if not gentle:
		# Transparent texels carry black; give them their neighbours' colour so
		# the smoother filter cannot pull a dark fringe into the silhouette.
		source = image.duplicate() as Image
		source.fix_alpha_edges()
	cursor = _place(output, source, Rect2i(0, neck.y, width, ground - neck.y), body, feet.x, plant.x, cursor, filter)
	for row in range(neck.y - 1, neck.x - 1, -1):
		var blend := (float(row - neck.x) + 0.5) / float(neck.y - neck.x)
		cursor = _place(output, source, Rect2i(0, row, width, 1), Vector2(head, head).lerp(body, blend), feet.x, plant.x, cursor, filter)
	_place(output, source, Rect2i(0, 0, width, neck.x), Vector2(head, head), feet.x, plant.x, cursor, filter)
	return output

static func _place(output: Image, source: Image, region: Rect2i, factor: Vector2, feet_x: float, plant_x: float, bottom: float, filter: Image.Interpolation) -> float:
	if region.size.y <= 0:
		return bottom
	var top := bottom - float(region.size.y) * factor.y
	var rows := roundi(bottom) - roundi(top)
	if rows > 0:
		var strip := source.get_region(region)
		strip.resize(maxi(1, roundi(float(region.size.x) * factor.x)), rows, filter)
		output.blit_rect(strip, Rect2i(Vector2i.ZERO, strip.get_size()), Vector2i(roundi(plant_x - feet_x * factor.x), roundi(top)))
	return top
