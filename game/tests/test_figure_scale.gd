extends SceneTree
## Every drawn character keeps one size. Measures the head and the ground contact
## of each actor x action x direction, and checks that the baked figure-size
## table still matches the art.
##
## Bake after changing character art:
##   SNAPLAND_BAKE_FIGURE_SCALE=1 godot --headless --path . --script res://game/tests/test_figure_scale.gd
## Hand-set fields (body, neck_below_top, pin_head, allow, reason) are kept;
## measured, head, neck_rows, feet and plant are rewritten.

const AvatarRenderer = preload("res://game/world/avatar_renderer.gd")
const FigureScale = preload("res://game/world/figure_scale.gd")
const Library = preload("res://game/world/character_animation_library.gd")
const NpcActivity = preload("res://game/world/npc_activity.gd")
const AmbienceSprites = preload("res://game/world/ambience_sprites.gd")

const HERO := "traveller"
const NPCS := ["ticket", "imp", "announcer"]
const SIDE_DIRECTIONS := ["left", "right"]
## The head is the one feature a pose does not change. Each actor names the
## colour family of a rigid head feature, searched in the upper part of the
## figure; "thick" drops the dark outline that surrounds the whole body.
const HEAD_FEATURES := {
	"traveller": {"color": "#2a2b48", "hue": 0.10, "value": [0.025, 0.58], "saturation": 0.15, "upper": 0.6, "thick": 9, "measure": "width"},
	"ticket": {"color": "#804020", "hue": 0.05, "value": [0.2, 0.75], "saturation": 0.4, "upper": 0.45, "thick": 9, "measure": "width"},
	"announcer": {"color": "#f0d8c0", "hue": 0.06, "value": [0.75, 1.01], "saturation": 0.05, "upper": 0.3, "thick": 9, "measure": "width"},
	"imp": {"color": "#f0d8a8", "hue": 0.06, "value": [0.75, 1.01], "saturation": 0.1, "upper": 0.4, "thick": 7, "measure": "area"},
}
const ALTERNATES := [
	[{"hair": "bob"}, {}],
	[{"hair": "curly", "hair_color": "chestnut"}, {"hat": "hat-straw"}],
	[{"skin": "deep", "hair_color": "silver"}, {"outfit": "outfit-coral", "hat": "hat-sailor"}],
	[{"species": "elf"}, {"outfit": "outfit-navy"}],
	[{"species": "imp", "hair": "bob"}, {"hat": "hat-flower"}],
]
const ALTERNATE_POSES := [["wave", "front", 0], ["wave", "front", 3], ["photograph", "front", 3], ["interact", "front", 2], ["wave", "back", 0], ["celebrate", "left", 0], ["jump", "front", 0]]
const MEASURED_SLACK := 0.015
const ALTERNATE_SLACK_PX := 10
const GENERATED_FIELDS := ["measured", "head", "feet", "plant", "neck_rows"]
## A resample may add at most this share of what composing its frame already costs.
const REFIT_SHARE := 0.4

var failures := 0
var checks := 0
var tolerance: Dictionary = {}
var report: Array[String] = []


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("Figure scale: " + message)


func _initialize() -> void:
	var baking := OS.get_environment("SNAPLAND_BAKE_FIGURE_SCALE") == "1"
	FigureScale.reload()
	var table: Dictionary = FigureScale.table().duplicate(true)
	tolerance = table.get("tolerance", {})
	_check(table.get("sources", {}) is Dictionary and not tolerance.is_empty(), "the figure-size table loads")
	if failures == 0:
		_hero(table, baking)
		if not baking:
			_alternates()
			_npcs(table)
			_npc_sprite_scale()
			_critters()
	for line in report:
		print(line)
	if baking and failures == 0:
		var file := FileAccess.open(FigureScale.TABLE_PATH, FileAccess.WRITE)
		file.store_string(_table_text(table))
		print("BAKED: %s" % FigureScale.TABLE_PATH)
	elif failures == 0:
		print("PASS: every character keeps one head size and ground contact across actions (%d checks)" % checks)
	quit(1 if failures > 0 else 0)


## One source per line keeps the baked table reviewable in a diff.
func _table_text(table: Dictionary) -> String:
	var text := "{\n"
	for key: String in table:
		if key != "sources":
			text += "\t%s: %s,\n" % [JSON.stringify(key), JSON.stringify(_whole_numbers(table[key]), "", false)]
	text += "\t\"sources\": {\n"
	var actors: Array = table.sources.keys()
	for actor: String in actors:
		text += "\t\t%s: {\n" % JSON.stringify(actor)
		var sources: Array = table.sources[actor].keys()
		for source: String in sources:
			text += "\t\t\t%s: %s%s\n" % [JSON.stringify(source), JSON.stringify(_whole_numbers(table.sources[actor][source]), "", false), "" if source == sources.back() else ","]
		text += "\t\t}%s\n" % ("" if actor == actors.back() else ",")
	return text + "\t}\n}\n"


func _whole_numbers(value: Variant) -> Variant:
	if value is float and value == floorf(value) and absf(value) > 1.5:
		return int(value)
	if value is Array:
		return value.map(_whole_numbers)
	if value is Dictionary:
		var result := {}
		for key: String in value:
			result[key] = _whole_numbers(value[key])
		return result
	return value


# --- measuring -------------------------------------------------------------

## `drawn_scale` is how much larger than the standing figure the source is drawn;
## the outline filter grows with it so both are judged at the same detail.
func _measure(image: Image, actor: String, drawn_scale: float = 1.0) -> Dictionary:
	var spec: Dictionary = HEAD_FEATURES[actor]
	var width := image.get_width()
	var height := image.get_height()
	var data := image.get_data()
	var left := width
	var right := -1
	var top := height
	var bottom := -1
	# Faintly visible texels bound the scan; only solid ones count as the figure.
	var used := image.get_used_rect()
	for y in range(used.position.y, used.end.y):
		var alpha := y * width * 4 + 3
		for x in range(used.position.x, used.end.x):
			if data[alpha + x * 4] > 127:
				left = mini(left, x)
				right = maxi(right, x)
				top = mini(top, y)
				bottom = y
	if bottom < 0:
		return {}
	var feet_left := width
	var feet_right := -1
	for y in range(maxi(top, bottom - 7), bottom + 1):
		var alpha := y * width * 4 + 3
		for x in range(left, right + 1):
			if data[alpha + x * 4] > 127:
				feet_left = mini(feet_left, x)
				feet_right = maxi(feet_right, x)
	var reference := Color(str(spec.color))
	var cut := top + int(float(bottom + 1 - top) * float(spec.upper))
	var span := right - left + 1
	var rows := cut - top
	var mask := PackedByteArray()
	mask.resize(span * rows)
	for y in rows:
		var offset := (top + y) * width * 4
		for x in span:
			var index := offset + (left + x) * 4
			if data[index + 3] <= 127:
				continue
			var color := Color8(data[index], data[index + 1], data[index + 2])
			var distance := absf(color.h - reference.h)
			if color.v > float(spec.value[0]) and color.v < float(spec.value[1]) and color.s > float(spec.saturation) and minf(distance, 1.0 - distance) < float(spec.hue):
				mask[y * span + x] = 1
	# A pixel is "thick" when the run through it is long both ways.
	var thick := maxi(2, roundi(float(spec.thick) * drawn_scale))
	var wide := PackedByteArray()
	wide.resize(span * rows)
	for y in rows:
		var start := -1
		for x in span + 1:
			var filled := x < span and mask[y * span + x] == 1
			if filled and start < 0:
				start = x
			elif not filled and start >= 0:
				if x - start >= thick:
					for fill in range(start, x):
						wide[y * span + fill] = 1
				start = -1
	var head_left := span
	var head_right := -1
	var area := 0
	for x in span:
		var start := -1
		for y in rows + 1:
			var filled := y < rows and mask[y * span + x] == 1
			if filled and start < 0:
				start = y
			elif not filled and start >= 0:
				if y - start >= thick:
					for fill in range(start, y):
						if wide[fill * span + x] == 1:
							area += 1
							head_left = mini(head_left, x)
							head_right = maxi(head_right, x)
				start = -1
	var head := 0.0
	if head_right >= 0:
		head = sqrt(float(area)) if str(spec.measure) == "area" else float(head_right - head_left + 1)
	return {"top": top, "bottom": bottom, "height": bottom + 1 - top, "feet_x": float(feet_left + feet_right) * 0.5, "head": head, "head_x": float(left) + float(head_left + head_right) * 0.5}


func _median(values: Array) -> float:
	var sorted := values.duplicate()
	sorted.sort()
	if sorted.is_empty():
		return 0.0
	var middle := sorted.size() / 2
	return float(sorted[middle]) if sorted.size() % 2 == 1 else (float(sorted[middle - 1]) + float(sorted[middle])) * 0.5


## One figure per source: the typical head, the ground row and the feet centre.
func _summary(frames: Array) -> Dictionary:
	var measured := frames.filter(func(frame: Dictionary) -> bool: return not frame.is_empty())
	if measured.is_empty():
		return {}
	return {
		"head": _median(measured.map(func(frame: Dictionary) -> float: return frame.head)),
		"feet_x": _median(measured.map(func(frame: Dictionary) -> float: return frame.feet_x)),
		"head_x": _median(measured.map(func(frame: Dictionary) -> float: return frame.head_x)),
		"ground": int(measured.map(func(frame: Dictionary) -> int: return frame.bottom).max()),
		"height": _median(measured.map(func(frame: Dictionary) -> int: return frame.height)),
		"tops": frames.map(func(frame: Dictionary) -> int: return int(frame.get("top", 0))),
		"heights": measured.map(func(frame: Dictionary) -> int: return frame.height),
		"heads": measured.map(func(frame: Dictionary) -> float: return frame.head),
	}


func _allowed(found: Dictionary, name: String, fallback: float) -> float:
	var allow: Variant = found.get("allow", {})
	var value: float = float(allow.get(name, fallback)) if allow is Dictionary else fallback
	return value if not str(found.get("reason", "")).strip_edges().is_empty() else fallback


## A step, a turn or a dance plants one foot away from the standing spot, so
## the feet centre says nothing about where the body stands.
func _steps(table: Dictionary, actor: String, action: String) -> bool:
	var actions: Variant = table.get("stepping", {}).get(actor, [])
	return actions is Array and actions.has(action)


func _close(stored: Variant, measured: Variant) -> bool:
	if stored == null or measured == null:
		return stored == null and measured == null
	if stored is Array and measured is Array:
		if stored.size() != measured.size():
			return false
		for index in stored.size():
			if not _close(stored[index], measured[index]):
				return false
		return true
	# Factors are compared as ratios, pixel rows within one pixel.
	return absf(float(stored) - float(measured)) <= (1.0 if absf(float(measured)) > 4.0 else MEASURED_SLACK)


## The measured fields of one table entry; hand-set fields in `found` steer them.
func _generated(found: Dictionary, drawn: Dictionary, reference: Dictionary, stepping: bool) -> Dictionary:
	var head_tolerance := float(tolerance.get("head", 0.04))
	var feet_tolerance := float(tolerance.get("feet_px", 2))
	var measured: float = float(drawn.head) / float(reference.head)
	var reasoned := not str(found.get("reason", "")).strip_edges().is_empty()
	var head: float = 1.0 / measured if absf(measured - 1.0) > head_tolerance else 1.0
	if reasoned and found.has("pin_head"):
		head = float(found.pin_head)
	var result := {"measured": snappedf(measured, 0.001), "head": snappedf(head, 0.001)}
	var scaled: bool = absf(head - 1.0) > FigureScale.MINIMUM_CHANGE or found.has("body")
	# Sideways, the feet and the head rarely agree to the pixel between two
	# drawings; split the difference unless the pose moves the feet on purpose.
	var feet_offset: float = float(reference.feet_x) - float(drawn.feet_x)
	var head_offset: float = float(reference.head_x) - (float(drawn.feet_x) + (float(drawn.head_x) - float(drawn.feet_x)) * head)
	var allow: Variant = found.get("allow", {})
	var free_feet: bool = stepping or (allow is Dictionary and allow.has("feet_x"))
	var shift: float = head_offset if free_feet else (feet_offset + head_offset) * 0.5
	var drop: int = int(reference.ground) - int(drawn.ground)
	if scaled or absi(drop) > feet_tolerance:
		result["feet"] = [roundi(float(drawn.feet_x)), int(drawn.ground)]
		result["plant"] = [roundi(float(drawn.feet_x) + (shift if scaled else 0.0)), int(reference.ground)]
	if found.has("neck_below_top"):
		result["neck_rows"] = drawn.tops.map(func(top: int) -> Array: return [top + int(found.neck_below_top[0]), top + int(found.neck_below_top[1])])
	return result


# --- hero ------------------------------------------------------------------

func _hero_frames(renderer: AvatarRenderer, action: String, direction: String, drawn_scale: float = 1.0) -> Array:
	var count := 8
	if action != "walk" and action != "idle":
		count = renderer.authored_frame_count(action, direction) if renderer.has_authored_action(action, direction) else 1
		# The last celebration frame is the following idle cel by design.
		if action == "celebrate" and count > 1: count -= 1
	var frames: Array = []
	var seen := {}
	for frame in count:
		var texture: Texture2D = renderer.texture({}, {}, direction, frame, action)
		# Standing and walking requests clamp to their last cel; measure each cel once.
		if texture == null or seen.has(texture.get_rid()):
			continue
		seen[texture.get_rid()] = true
		frames.append(_measure(texture.get_image(), HERO, drawn_scale))
	return frames


## Every distinct drawn source the hero can show: [source, action, direction, drawn direction].
func _hero_sources(renderer: AvatarRenderer) -> Array:
	var actions: Array = AvatarRenderer.ACTIONS.duplicate()
	for action: String in renderer.animation_library.coverage_report().get(HERO, {}):
		if action != "idle" and not actions.has(action):
			actions.append(action)
	var sources: Array = []
	var seen := {}
	for action: String in actions:
		for direction: String in AvatarRenderer.WALK_DIRECTIONS:
			var authored := renderer.has_authored_action(action, direction)
			var source := renderer.figure_source(action, direction, authored)
			if source.is_empty() or seen.has(source):
				continue
			seen[source] = true
			sources.append([source, action, direction, direction if authored else "front"])
	return sources


func _hero(table: Dictionary, baking: bool) -> void:
	var sources_table: Dictionary = table.sources.get(HERO, {})
	var head_tolerance := float(tolerance.get("head", 0.04))
	var feet_tolerance := float(tolerance.get("feet_px", 2))
	# Pass 1: the art as drawn, with no table.
	FigureScale.use_table({})
	var raw_renderer := AvatarRenderer.new()
	_check(raw_renderer.is_asset_ready(), "the hero atlas loads")
	var standing := {}
	for direction: String in AvatarRenderer.WALK_DIRECTIONS:
		standing[direction] = _summary(_hero_frames(raw_renderer, "idle", direction))
		_check(float(standing[direction].get("head", 0.0)) > 0.0, "standing %s has a measurable head" % direction)
		var walking := _summary(_hero_frames(raw_renderer, "walk", direction))
		var walk_ratio: float = float(walking.head) / float(standing[direction].head)
		_check(absf(walk_ratio - 1.0) <= head_tolerance, "walk %s head is %.3f of standing" % [direction, walk_ratio])
		_check(absi(int(walking.ground) - int(standing[direction].ground)) <= feet_tolerance, "walk %s ground row %d vs standing %d" % [direction, walking.ground, standing[direction].ground])
		var height_ratio: float = float(standing[direction].height) / float(standing.front.height)
		_check(absf(height_ratio - 1.0) <= float(tolerance.get("standing_height", 0.06)), "standing %s is %.3f of the front height" % [direction, height_ratio])
	var sources := _hero_sources(raw_renderer)
	var raw := {}
	for row in sources:
		var drawn := _summary(_hero_frames(raw_renderer, row[1], row[2]))
		# A larger drawing shows more of its fine detail. Measure it again at the
		# detail the standing figure is judged at, until the ratio settles.
		for pass_index in 2:
			var drawn_scale: float = float(drawn.head) / float(standing[row[3]].head)
			if absf(drawn_scale - 1.0) <= 0.02:
				break
			drawn = _summary(_hero_frames(raw_renderer, row[1], row[2], drawn_scale))
		raw[row[0]] = drawn
	var known := {}
	for row in sources:
		var source: String = row[0]
		known[source] = true
		var found: Dictionary = sources_table.get(source, {})
		var generated := _generated(found, raw[source], standing[row[3]], _steps(table, HERO, row[1]))
		var needed := generated.has("feet") or absf(float(generated.head) - 1.0) > FigureScale.MINIMUM_CHANGE
		if baking:
			for field in GENERATED_FIELDS:
				found.erase(field)
			if needed or not found.is_empty():
				found.merge(generated)
				sources_table[source] = found
			continue
		if found.is_empty():
			_check(not needed, "%s is drawn at %.3f of the standing head and has no table entry; bake the table" % [source, float(generated.measured)])
			continue
		for field in GENERATED_FIELDS:
			_check(_close(found.get(field), generated.get(field)), "%s %s is %s in the table but measures %s; bake the table" % [source, field, JSON.stringify(found.get(field)), JSON.stringify(generated.get(field))])
	if baking:
		table.sources[HERO] = sources_table
		return
	for source: String in sources_table:
		_check(known.has(source), "table entry %s names no drawn source" % source)
	# Pass 2: what the game shows.
	FigureScale.reload()
	var renderer := AvatarRenderer.new()
	var refit_msec := 0.0
	var refit_count := 0
	for row in sources:
		var source: String = row[0]
		var found: Dictionary = sources_table.get(source, {})
		var reference: Dictionary = standing[row[3]]
		var shown: Dictionary = raw[source]
		if not found.is_empty():
			shown = _summary(_hero_frames(renderer, row[1], row[2]))
			if absf(float(found.get("head", 1.0)) - 1.0) > FigureScale.MINIMUM_CHANGE:
				refit_count += shown.heads.size()
		var ratio: float = float(shown.head) / float(reference.head)
		var limit := _allowed(found, "head", head_tolerance)
		_check(absf(ratio - 1.0) <= limit, "%s head is %.3f of standing (limit %.2f)" % [source, ratio, limit])
		_check(absf(float(shown.ground) - float(reference.ground)) <= _allowed(found, "ground", feet_tolerance), "%s ground row %d vs standing %d" % [source, shown.ground, reference.ground])
		if not _steps(table, HERO, row[1]):
			_check(absf(float(shown.feet_x) - float(reference.feet_x)) <= _allowed(found, "feet_x", feet_tolerance), "%s feet centre %.1f vs standing %.1f" % [source, shown.feet_x, reference.feet_x])
		if OS.get_environment("SNAPLAND_FIGURE_SCALE_VERBOSE") == "1":
			report.append("  %-28s feet dx %+5.1f  head dx %+5.1f  ground %d" % [source, float(shown.feet_x) - float(reference.feet_x), float(shown.head_x) - float(reference.head_x), int(shown.ground)])
		if not found.is_empty() or absf(float(raw[source].head) / float(reference.head) - 1.0) > 0.02:
			report.append("hero %-26s head %.3f -> %.3f  height %3d -> %3d  feet %5.1f -> %5.1f%s" % [source, float(raw[source].head) / float(reference.head), ratio, int(raw[source].height), int(shown.height), float(raw[source].feet_x), float(shown.feet_x), "  (pinned)" if found.has("pin_head") else ""])
	# Cost of the resample next to composing the frame it belongs to. Both are
	# timed here, so a busy machine slows them alike.
	var compose_started := Time.get_ticks_usec()
	var sample: Image = renderer.texture({"skin": "cool"}, {}, "front", 0, "idle").get_image()
	var compose_msec := float(Time.get_ticks_usec() - compose_started) / 1000.0
	for source: String in sources_table:
		var found: Dictionary = sources_table[source]
		if absf(float(found.get("head", 1.0)) - 1.0) <= FigureScale.MINIMUM_CHANGE:
			continue
		var fastest := INF
		for repeat in 5:
			var started := Time.get_ticks_usec()
			FigureScale.refit(sample, found, 0)
			fastest = minf(fastest, float(Time.get_ticks_usec() - started) / 1000.0)
		refit_msec = maxf(refit_msec, fastest)
	_check(refit_msec <= compose_msec * REFIT_SHARE, "a resample costs %.2f ms next to %.1f ms for composing a frame" % [refit_msec, compose_msec])
	report.append("hero: %d sources, %d table entries, %d resampled frames, slowest resample %.2f ms, composing a frame %.1f ms" % [sources.size(), sources_table.size(), refit_count, refit_msec, compose_msec])
	# The cache key still identifies a frame: the same request returns the same texture.
	var first: Texture2D = renderer.texture({}, {}, "front", 2, "wave")
	var count := renderer.cached_texture_count()
	_check(first == renderer.texture({}, {}, "front", 2, "wave") and renderer.cached_texture_count() == count, "a scaled frame is cached once")
	_check(first.get_size() == Vector2(AvatarRenderer.CANVAS_SIZE), "scaled frames keep the shared canvas")
	# Standing and walking cels are never resampled.
	FigureScale.use_table({})
	var untouched := AvatarRenderer.new()
	for sample_pose in [["idle", "front", 0], ["idle", "back_left", 1], ["walk", "right", 3], ["walk", "front_left", 6]]:
		var plain: Image = untouched.texture({}, {}, sample_pose[1], sample_pose[2], sample_pose[0]).get_image()
		var shown_pose: Image = renderer.texture({}, {}, sample_pose[1], sample_pose[2], sample_pose[0]).get_image()
		_check(plain.get_data() == shown_pose.get_data(), "%s %s keeps its drawn pixels" % [sample_pose[0], sample_pose[1]])
	FigureScale.reload()


## Hair, hats, outfits, skin and species are fitted together with the figure:
## a dressed pose keeps the ground contact of the default look and gains only
## what its headwear adds to the standing figure.
func _alternates() -> void:
	var renderer := AvatarRenderer.new()
	var feet_tolerance := float(tolerance.get("feet_px", 2))
	var baseline := {}
	for pose in ALTERNATE_POSES:
		baseline[pose] = _measure(renderer.texture({}, {}, pose[1], pose[2], pose[0]).get_image(), HERO)
	var default_standing := _measure(renderer.texture({}, {}, "front", 0, "idle").get_image(), HERO)
	for look in ALTERNATES:
		var standing := _measure(renderer.texture(look[0], look[1], "front", 0, "idle").get_image(), HERO)
		# A hat raises the standing figure and the posed one by the same pixels.
		var headwear: int = int(default_standing.top) - int(standing.top)
		for pose in ALTERNATE_POSES:
			var posed := _measure(renderer.texture(look[0], look[1], pose[1], pose[2], pose[0]).get_image(), HERO)
			var plain: Dictionary = baseline[pose]
			var label := "%s %s with %s %s" % [pose[0], pose[1], JSON.stringify(look[0]), JSON.stringify(look[1])]
			_check(absi(int(posed.bottom) - int(plain.bottom)) <= feet_tolerance, "%s ground row %d vs %d" % [label, posed.bottom, plain.bottom])
			_check(absf(float(posed.feet_x) - float(plain.feet_x)) <= feet_tolerance + 1.0, "%s feet centre %.1f vs %.1f" % [label, posed.feet_x, plain.feet_x])
			# Headwear and hair are returned to standing size with the figure, so
			# they raise a pose by what they add to the standing figure, or by
			# nothing where a raised hand is already the highest point.
			var extra: int = int(plain.top) - int(posed.top)
			_check(extra >= mini(headwear, 0) - ALTERNATE_SLACK_PX and extra <= maxi(headwear, 0) + ALTERNATE_SLACK_PX, "%s rises %d px above the default pose; standing it adds %d" % [label, extra, headwear])
			if OS.get_environment("SNAPLAND_FIGURE_SCALE_VERBOSE") == "1":
				report.append("  alt %s: top %+d (standing %+d) ground %d feet %.1f/%.1f" % [label, extra, headwear, posed.bottom, posed.feet_x, plain.feet_x])


# --- NPCs ------------------------------------------------------------------

func _npc_frames(library: Library, actor: String, action: String, direction: String) -> Array:
	var frames: Array = []
	for frame in library.frame_count(actor, action, direction):
		var texture: Texture2D = library.texture(actor, action, direction, frame)
		frames.append(_measure(texture.get_image(), actor) if texture != null else {})
	return frames


func _npcs(table: Dictionary) -> void:
	var library := Library.new()
	var head_tolerance := float(tolerance.get("head", 0.04))
	var feet_tolerance := float(tolerance.get("feet_px", 2))
	var coverage: Dictionary = library.coverage_report()
	for actor: String in NPCS:
		var entries: Dictionary = table.sources.get(actor, {})
		var standing := _summary(_npc_frames(library, actor, "idle", "front"))
		_check(float(standing.get("head", 0.0)) > 0.0, "%s standing has a measurable head" % actor)
		var seen := {}
		for action: String in coverage.get(actor, {}):
			# The rejected exploratory front walk is never played.
			if action == "walk_candidate":
				continue
			for direction: String in coverage[actor][action]:
				var source := "%s:%s" % [action, direction]
				seen[source] = true
				var found: Dictionary = entries.get(source, {})
				var shown := _summary(_npc_frames(library, actor, action, direction))
				_check(not shown.is_empty(), "%s %s renders" % [actor, source])
				if shown.is_empty():
					continue
				_check(absf(float(shown.ground) - float(standing.ground)) <= _allowed(found, "ground", feet_tolerance), "%s %s ground row %d vs standing %d" % [actor, source, shown.ground, standing.ground])
				if SIDE_DIRECTIONS.has(direction):
					# A profile cannot be compared head to head with the front view;
					# an upright figure must still stand as tall.
					var limit := _allowed(found, "height", head_tolerance)
					for height: int in shown.heights:
						var height_ratio := float(height) / float(standing.height)
						_check(absf(height_ratio - 1.0) <= limit, "%s %s frame is %.3f of the standing height (limit %.2f)" % [actor, source, height_ratio, limit])
					if action == "walk":
						var spread: float = float(shown.heads.max()) / maxf(float(shown.heads.min()), 1.0)
						_check(spread - 1.0 <= head_tolerance, "%s %s head varies by %.3f between frames" % [actor, source, spread])
					report.append("%-9s %-22s height %.3f..%.3f of standing" % [actor, source, float(shown.heights.min()) / float(standing.height), float(shown.heights.max()) / float(standing.height)])
					continue
				var ratio: float = float(shown.head) / float(standing.head)
				var head_limit := _allowed(found, "head", head_tolerance)
				_check(absf(ratio - 1.0) <= head_limit, "%s %s head is %.3f of standing (limit %.2f)" % [actor, source, ratio, head_limit])
				if not _steps(table, actor, action):
					_check(absf(float(shown.feet_x) - float(standing.feet_x)) <= _allowed(found, "feet_x", feet_tolerance), "%s %s feet centre %.1f vs standing %.1f" % [actor, source, shown.feet_x, standing.feet_x])
				report.append("%-9s %-22s head %.3f of standing" % [actor, source, ratio])
		for source: String in entries:
			_check(seen.has(source), "table entry %s/%s names no drawn source" % [actor, source])


## The world shows every NPC frame on one canvas at one sprite scale, so the
## baked frame size is the on-screen size.
func _npc_sprite_scale() -> void:
	var activity := NpcActivity.new()
	root.add_child(activity)
	for role: String in NPCS:
		var sprite := Sprite3D.new()
		sprite.pixel_size = 0.0123
		root.add_child(sprite)
		_check(activity.register_actor(sprite, role), "%s registers for activity" % role)
		for action in ["stand", "greet", "interact", "walk"]:
			activity.request_action(sprite, action, "right" if action == "walk" else "front")
			_check(is_equal_approx(sprite.pixel_size, 0.0123), "%s %s keeps the sprite scale" % [role, action])
			_check(sprite.texture != null and sprite.texture.get_size() == Vector2(NpcActivity.ACTION_CANVAS_SIZE), "%s %s uses the shared canvas" % [role, action])
		sprite.queue_free()
	activity.release()
	activity.queue_free()


# --- other animated sprites ------------------------------------------------

## Ambience animals are drawn on one pixel grid; a frame authored at another
## size would stand out as a much longer or shorter silhouette.
func _critters() -> void:
	for kind: String in AmbienceSprites.CRITTER_FRAMES:
		var longest: Array = []
		for rows: Array in AmbienceSprites.CRITTER_FRAMES[kind]:
			var width := 0
			for row: String in rows:
				width = maxi(width, row.length())
			if AmbienceSprites.MIRRORED.has(kind):
				width = width * 2 - 1
			_check(width <= AmbienceSprites.CELL.x and rows.size() <= AmbienceSprites.CELL.y, "%s frame fits its atlas cell" % kind)
			longest.append(maxi(width, rows.size()))
		_check(float(longest.max()) / float(longest.min()) <= 1.35, "%s frames span %s px; one frame is a different size" % [kind, str(longest)])
