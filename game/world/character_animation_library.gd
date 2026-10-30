extends RefCounted
## Tolerant loader for authored, frame-aligned character atlases.

const MANIFEST_PATH := "res://assets/characters/complete-animation-regions.json"
const TEXTURE_CACHE_LIMIT := 96
const IMAGE_CACHE_LIMIT := 8
const OUTFIT_CACHE_LIMIT := 64
const ACTORS := ["traveller", "ticket", "imp", "announcer"]

var _stable_walk_pixels = preload("res://game/world/walk_pixel_sources.gd").new()
var manifest: Dictionary = {}
var diagnostics: Array[String] = []
var _images: Dictionary = {}
var _image_order: Array[String] = []
var _textures: Dictionary = {}
var _texture_order: Array[String] = []
var _sequences: Dictionary = {}
var _sequence_order: Array[String] = []
var _layouts: Dictionary = {}
var _reference_sizes: Dictionary = {}
var _warned: Dictionary = {}
var _diagnostic_keys: Dictionary = {}
var _outfit_ready: Dictionary = {}

func _init(path: String = MANIFEST_PATH) -> void:
	load_manifest(path)

func load_manifest(path: String) -> bool:
	manifest.clear()
	diagnostics.clear()
	_diagnostic_keys.clear()
	_images.clear()
	_image_order.clear()
	_textures.clear()
	_texture_order.clear()
	_sequences.clear()
	_sequence_order.clear()
	_layouts.clear()
	_reference_sizes.clear()
	_warned.clear()
	_outfit_ready.clear()
	if not FileAccess.file_exists(path):
		_diagnostic("manifest", "missing manifest: %s" % path)
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary or int(parsed.get("schema_version", 0)) != 1:
		_diagnostic("manifest", "expected object with schema_version 1")
		return false
	var actors: Variant = parsed.get("actors", {})
	if not actors is Dictionary:
		_diagnostic("manifest", "actors must be an object")
		return false
	manifest = parsed
	for actor in actors:
		if not ACTORS.has(str(actor)):
			_diagnostic("actor %s" % actor, "unknown actor")
	return true

func has_frame(actor: String, action: String, direction: String) -> bool:
	return _frames(actor, action, direction).size() > 0

func frame_count(actor: String, action: String, direction: String) -> int:
	return _frames(actor, action, direction).size()

func frame_fps(actor: String, action: String, direction: String) -> float:
	var entry := _entry(actor, action, direction)
	var fps_value: Variant = entry.get("fps", 1.0)
	return clampf(float(fps_value), 0.01, 60.0) if fps_value is int or fps_value is float else 1.0

func has_action(actor: String, action: String, direction: String) -> bool:
	return has_frame(actor, action, direction)

func is_looping(actor: String, action: String, direction: String) -> bool:
	return bool(_entry(actor, action, direction).get("loop", true))

func coverage_report() -> Dictionary:
	var result := {}
	var actors: Dictionary = manifest.get("actors", {})
	for actor in ACTORS:
		var action_coverage := {}
		var actions: Variant = actors.get(actor, {})
		if actions is Dictionary:
			for action in actions:
				if str(action) in ["canvas_size", "reference_size", "feet_baseline"]: continue
				var directions: Variant = actions[action]
				if directions is Dictionary:
					action_coverage[action] = directions.keys()
		result[actor] = action_coverage
	return result

func get_sequence(actor: String, action: String, direction: String, equipped: Dictionary = {}) -> Dictionary:
	var key := "%s|%s|%s|%s" % [actor, action, direction, JSON.stringify(equipped)]
	if _sequences.has(key): return _sequences[key]
	var entry := _entry(actor, action, direction)
	var frames: Array = []
	var source_frames := _frames(actor, action, direction)
	for index in range(source_frames.size()):
		if not source_frames[index] is Dictionary:
			_diagnostic(_context(actor, action, direction, index), "frame entries must be objects")
			frames.append({"texture": null})
			continue
		var frame: Dictionary = source_frames[index].duplicate(true)
		frame["texture"] = texture(actor, action, direction, index, equipped)
		var selected_frame := _frame_for_equipment(frame, equipped, actor, action, direction, index)
		frame["source"] = selected_frame.get("source", frame.get("source", ""))
		frame["region"] = selected_frame.get("region", frame.get("region", []))
		var anchors_value: Variant = selected_frame.get("anchors", {})
		if frame["texture"] != null and anchors_value is Dictionary:
			frame["source_anchors"] = anchors_value.duplicate(true)
			var normalized_anchors := {}
			for anchor_name in anchors_value:
				var normalized_point: Vector2i = normalized_anchor(actor, action, direction, index, str(anchor_name), equipped)
				normalized_anchors[anchor_name] = [normalized_point.x, normalized_point.y]
			frame["anchors"] = normalized_anchors
		frames.append(frame)
	var result := {"fps": frame_fps(actor, action, direction), "loop": bool(entry.get("loop", true)), "frames": frames, "available": not frames.is_empty() and frames.all(func(item: Dictionary) -> bool: return item.get("texture") != null)}
	_sequences[key] = result
	_sequence_order.append(key)
	while _sequence_order.size() > 64: _sequences.erase(_sequence_order.pop_front())
	return result

func normalized_anchor(actor: String, action: String, direction: String, frame_index: int, name: String, equipped: Dictionary = {}) -> Vector2i:
	var frames := _frames(actor, action, direction)
	if frames.is_empty(): return Vector2i.ZERO
	var index := posmod(frame_index, frames.size())
	if not frames[index] is Dictionary: return Vector2i.ZERO
	var frame := _frame_for_equipment(frames[index], equipped, actor, action, direction, index)
	var layout_key := "%s|%s|%s|%d|%s" % [actor, action, direction, index, JSON.stringify(equipped)]
	if not _layouts.has(layout_key): return Vector2i.ZERO
	var anchors_value: Variant = frame.get("anchors", {})
	if not anchors_value is Dictionary: return Vector2i.ZERO
	var anchors: Dictionary = anchors_value
	if not anchors.has(name): return Vector2i.ZERO
	var layout: Dictionary = _layouts[layout_key]
	if name=="head" and layout.has("stable_head"):
		return layout.stable_head
	var point := _point(anchors[name])
	var scale_factor := float(layout.scale)
	var destination: Vector2i = layout.destination
	return destination + Vector2i(roundi(point.x * scale_factor), roundi(point.y * scale_factor))

func has_anchor(actor: String, action: String, direction: String, frame_index: int, name: String, equipped: Dictionary = {}) -> bool:
	var frames := _frames(actor, action, direction)
	if frames.is_empty(): return false
	var frame_value: Variant = frames[posmod(frame_index, frames.size())]
	if not frame_value is Dictionary: return false
	var frame := _frame_for_equipment(frame_value, equipped, actor, action, direction, posmod(frame_index, frames.size()))
	var anchors: Variant = frame.get("anchors", {})
	return anchors is Dictionary and anchors.has(name)

func frame_for_time(actor: String, action: String, direction: String, elapsed: float, reduced_motion: bool = false) -> int:
	var frames := _frames(actor, action, direction)
	if frames.is_empty() or reduced_motion: return 0
	var entry := _entry(actor, action, direction)
	var durations: Array = entry.get("frame_durations", [])
	if not durations.is_empty():
		var total := 0.0
		for duration in durations: total += float(duration)
		var remaining := fposmod(maxf(0.0, elapsed), total) if bool(entry.get("loop", true)) else minf(maxf(0.0, elapsed), total)
		for index in range(durations.size()):
			if remaining < float(durations[index]): return index
			remaining -= float(durations[index])
		return durations.size() - 1
	var index := floori(maxf(0.0, elapsed) * frame_fps(actor, action, direction))
	return posmod(index, frames.size()) if bool(entry.get("loop", true)) else mini(index, frames.size() - 1)

func texture(actor: String, action: String, direction: String, frame_index: int, equipped: Dictionary = {}) -> Texture2D:
	var frames := _frames(actor, action, direction)
	if frames.is_empty(): return null
	var index := posmod(frame_index, frames.size())
	if not frames[index] is Dictionary:
		_diagnostic(_context(actor, action, direction, index), "frame entry must be an object")
		return null
	var frame: Dictionary = _frame_for_equipment(frames[index], equipped, actor, action, direction, index)
	return _render_frame(actor, action, direction, index, frame, equipped)

func inspect_variant_texture(actor: String, action: String, direction: String, frame_index: int, outfit: String) -> Texture2D:
	# Explicit authoring inspection of one candidate, never production selection.
	# Incomplete outfits can be inspected without making any of their cels live.
	var frames := _frames(actor, action, direction)
	if frame_index<0 or frame_index>=frames.size() or not frames[frame_index] is Dictionary: return null
	var variant := _validated_outfit_variant(frames[frame_index], outfit, actor, action, direction, frame_index)
	if variant.is_empty(): return null
	var frame: Dictionary = frames[frame_index].duplicate(true)
	frame["source"] = variant.source
	frame["region"] = variant.region.duplicate()
	frame["anchors"] = variant.anchors.duplicate(true)
	# Distinct cache/layout keys keep inspected anchors out of live sequences.
	return _render_frame(actor, action, direction, frame_index, frame, {"outfit":outfit}, true)

func _render_frame(actor: String, action: String, direction: String, index: int, frame: Dictionary, equipped: Dictionary, inspection: bool = false) -> Texture2D:
	var key := ("inspection|" if inspection else "") + "%s|%s|%s|%d|%s" % [actor, action, direction, index, JSON.stringify(equipped)]
	if _textures.has(key):
		_texture_order.erase(key)
		_texture_order.append(key)
		return _textures[key]
	var entry := _entry(actor, action, direction)
	var fps_value: Variant = entry.get("fps", 1.0)
	if not (fps_value is int or fps_value is float) or not is_finite(float(fps_value)):
		_diagnostic(_context(actor, action, direction, index), "fps must be a finite number")
		return null
	var anchors_value: Variant = frame.get("anchors", {})
	if not anchors_value is Dictionary:
		_diagnostic(_context(actor, action, direction, index), "anchors must be an object")
		return null
	for anchor_name in anchors_value:
		var anchor_value: Variant = anchors_value[anchor_name]
		if not anchor_value is Array or anchor_value.size() != 2 or not (anchor_value[0] is int or anchor_value[0] is float) or not (anchor_value[1] is int or anchor_value[1] is float):
			_diagnostic(_context(actor, action, direction, index), "anchor '%s' must be a numeric [x,y] pair" % str(anchor_name))
			return null
	var source_scale_value: Variant = frame.get("source_scale", 1.0)
	if not (source_scale_value is int or source_scale_value is float) or not is_finite(float(source_scale_value)) or float(source_scale_value) < 0.01 or float(source_scale_value) > 4.0:
		_diagnostic(_context(actor, action, direction, index), "source_scale must be a finite number between 0.01 and 4.0")
		return null
	var source_image := _image(str(frame.get("source", "")), actor, action, direction, index)
	if not _valid_number_array(frame.get("region", []), 4):
		_diagnostic(_context(actor, action, direction, index), "body region must be numeric [x,y,w,h]")
		return null
	var region := _rect(frame.get("region", []))
	if source_image == null or not _inside(source_image, region) or region.size.x > 2048 or region.size.y > 2048 or region.size.x * region.size.y > 4194304:
		_diagnostic(_context(actor, action, direction, index), "body region is invalid or outside source")
		return null
	for anchor_name in anchors_value:
		var point := _point(anchors_value[anchor_name])
		if point.x < 0 or point.y < 0 or point.x > region.size.x or point.y > region.size.y:
			_diagnostic(_context(actor, action, direction, index), "anchor '%s' is outside the source frame" % str(anchor_name))
			return null
	var output := Image.create(region.size.x, region.size.y, false, Image.FORMAT_RGBA8)
	output.fill(Color.TRANSPARENT)
	var drawables: Array[Dictionary] = [{"body": true, "z": int(frame.get("body_z", 0)), "order": 0}]
	var layers: Variant = frame.get("layers", [])
	if not layers is Array:
		_diagnostic(_context(actor, action, direction, index), "layers must be an array")
		return null
	var layer_order := 1
	for layer_value in layers:
		if not layer_value is Dictionary:
			_diagnostic(_context(actor, action, direction, index), "layer entries must be objects")
			return null
		var selector: Variant = layer_value.get("equipped", {})
		if not selector is Dictionary and not selector is String:
			_diagnostic(_context(actor, action, direction, index), "layer equipped selector must be an object or string")
			return null
		var matches := true
		if selector is Dictionary:
			for selector_key in selector:
				if str(equipped.get(str(selector_key), "")) != str(selector[selector_key]):
					matches = false
					break
		elif selector is String and not selector.is_empty():
			var separator: int = selector.find("=")
			if separator > 0:
				matches = str(equipped.get(selector.substr(0, separator), "")) == selector.substr(separator + 1)
		if matches:
			if not _valid_number_array(layer_value.get("region", []), 4) or not _valid_number_array(layer_value.get("offset", [0, 0]), 2):
				_diagnostic(_context(actor, action, direction, index), "layer region/offset must be numeric arrays")
				return null
			var layer_drawable: Dictionary = layer_value.duplicate()
			layer_drawable["order"] = layer_order
			drawables.append(layer_drawable)
		layer_order += 1
	drawables.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.get("z", 0)) == int(b.get("z", 0)): return int(a.get("order", 0)) < int(b.get("order", 0))
		return int(a.get("z", 0)) < int(b.get("z", 0)))
	for drawable in drawables:
		if bool(drawable.get("body", false)):
			output.blit_rect(source_image, region, Vector2i.ZERO)
			continue
		var layer_image := _image(str(drawable.get("source", "")), actor, action, direction, index)
		var layer_rect := _rect(drawable.get("region", []))
		if layer_image == null or not _inside(layer_image, layer_rect) or layer_rect.size.x > 2048 or layer_rect.size.y > 2048 or layer_rect.size.x * layer_rect.size.y > 4194304:
			_diagnostic(_context(actor, action, direction, index), "layer '%s' has invalid source region" % str(drawable.get("slot", "?")))
			return null
		output.blend_rect(layer_image, layer_rect, _point(drawable.get("offset", [0, 0])))
	var actor_data: Variant = manifest.get("actors", {}).get(actor, {})
	if not actor_data is Dictionary: actor_data = {}
	var canvas_size := Vector2i(280, 360) if actor == "traveller" else Vector2i(320, 460)
	var canvas_value: Variant = actor_data.get("canvas_size", [canvas_size.x, canvas_size.y])
	if not _valid_number_array(canvas_value, 2):
		_diagnostic(_context(actor, action, direction, index), "canvas_size must be two numeric dimensions")
		return null
	if int(canvas_value[0]) <= 0 or int(canvas_value[1]) <= 0 or int(canvas_value[0]) > 512 or int(canvas_value[1]) > 512:
		_diagnostic(_context(actor, action, direction, index), "canvas_size must be two dimensions between 1 and 512")
		return null
	canvas_size = Vector2i(int(canvas_value[0]), int(canvas_value[1]))
	var reference_key := "%s|%s|%s" % [actor, action, direction]
	var reference_value: Variant = actor_data.get("reference_size", [])
	var reference_size: Vector2i
	if actor_data.has("reference_size") and not _valid_number_array(reference_value, 2):
		_diagnostic(_context(actor, action, direction, index), "reference_size must be two numeric dimensions")
		return null
	if _valid_number_array(reference_value, 2) and int(reference_value[0]) > 0 and int(reference_value[1]) > 0 and int(reference_value[0]) <= 8192 and int(reference_value[1]) <= 8192:
		reference_size = Vector2i(int(reference_value[0]), int(reference_value[1]))
	elif actor_data.has("reference_size"):
		_diagnostic(_context(actor, action, direction, index), "reference_size must be two dimensions between 1 and 8192")
		return null
	else:
		if not _reference_sizes.has(reference_key):
			var sequence_frames := _frames(actor, action, direction)
			var first_region := region
			if not sequence_frames.is_empty() and sequence_frames[0] is Dictionary and _valid_number_array(sequence_frames[0].get("region", []), 4):
				var first_rect := _rect(sequence_frames[0].get("region", []))
				if first_rect.size.x > 0 and first_rect.size.y > 0: first_region = first_rect
			_reference_sizes[reference_key] = first_region.size
		reference_size = _reference_sizes[reference_key]
	var actor_scale := minf(float(canvas_size.x) / float(reference_size.x), float(canvas_size.y) / float(reference_size.y))
	var scale_factor := actor_scale * float(source_scale_value)
	var scaled_size := Vector2i(maxi(1, roundi(float(output.get_width()) * scale_factor)), maxi(1, roundi(float(output.get_height()) * scale_factor)))
	if scaled_size.x > canvas_size.x or scaled_size.y > canvas_size.y:
		_diagnostic(_context(actor, action, direction, index), "normalized frame exceeds its shared canvas")
		return null
	output.resize(scaled_size.x, scaled_size.y, Image.INTERPOLATE_NEAREST)
	var feet: Vector2i = _point(anchors_value.get("feet", [region.size.x / 2, region.size.y]))
	if feet.x < 0 or feet.y < 0 or feet.x > region.size.x or feet.y > region.size.y:
		_diagnostic(_context(actor, action, direction, index), "feet anchor is outside the source frame")
		return null
	var baseline_value: Variant = actor_data.get("feet_baseline", 346 if actor == "traveller" else 448)
	if not (baseline_value is int or baseline_value is float):
		_diagnostic(_context(actor, action, direction, index), "feet_baseline must be numeric")
		return null
	var baseline := int(baseline_value)
	var destination := Vector2i(roundi(float(canvas_size.x) / 2.0 - float(feet.x) * scale_factor), baseline - roundi(float(feet.y) * scale_factor))
	if baseline < 0 or baseline > canvas_size.y:
		_diagnostic(_context(actor, action, direction, index), "feet_baseline is outside canvas")
		return null
	_layouts[key] = {"scale": scale_factor, "destination": destination}
	var fixed_canvas := Image.create(canvas_size.x, canvas_size.y, false, Image.FORMAT_RGBA8)
	fixed_canvas.fill(Color.TRANSPARENT)
	fixed_canvas.blend_rect(output, Rect2i(Vector2i.ZERO, scaled_size), destination)
	output = fixed_canvas
	if not inspection and action in ["walk","walk_candidate"]:
		var registered: Image = _stable_walk_pixels.frame(actor+"-"+action,direction,index)
		if registered!=null:
			output=registered
			var registered_layout: Dictionary=_layouts[key]
			registered_layout.destination += _stable_walk_pixels.root_offset(actor+"-"+action,direction,index)
			_layouts[key]["stable_head"]=_stable_walk_pixels.head_anchor(actor+"-"+action,direction)
	var result := ImageTexture.create_from_image(output)
	_textures[key] = result
	_texture_order.append(key)
	while _texture_order.size() > TEXTURE_CACHE_LIMIT:
		_textures.erase(_texture_order.pop_front())
	return result

func _frame_for_equipment(frame: Dictionary, equipped: Dictionary, actor: String, action: String, direction: String, index: int) -> Dictionary:
	var outfit := str(equipped.get("outfit", ""))
	if outfit.is_empty() or not outfit_variant_ready(actor, outfit): return frame
	var variant := _validated_outfit_variant(frame, outfit, actor, action, direction, index)
	if variant.is_empty(): return frame
	var result := frame.duplicate(true)
	result["source"] = variant.source
	result["region"] = variant.region.duplicate()
	result["anchors"] = variant.anchors.duplicate(true)
	return result

func outfit_variant_ready(actor: String, outfit: String) -> bool:
	# One decision for every registered pose, never per-cel mixed clothing.
	# Palette outfits intentionally keep the original complete body source.
	var key := JSON.stringify([actor, outfit])
	if _outfit_ready.has(key): return _outfit_ready[key]
	var modes: Variant = manifest.get("outfit_modes", {})
	if not modes is Dictionary or modes.get(outfit, "variant") != "variant":
		if not modes is Dictionary or modes.get(outfit, "") != "palette":
			_diagnostic("%s/outfit %s" % [actor, outfit], "unknown outfit mode; preserving all original body cels")
		return _remember_outfit(key, false)
	var actions: Variant = manifest.get("actors", {}).get(actor, {})
	if not actions is Dictionary: return _remember_outfit(key, false)
	# Some source families (the island walk atlas) live outside this library.
	# Their declared obligations still block activation until unified coverage exists.
	var required_actors: Variant = manifest.get("outfit_required_poses", {})
	var required: Variant = required_actors.get(actor, {}) if required_actors is Dictionary else null
	if not required is Dictionary: return _remember_outfit(key, false)
	for action in required:
		if not required[action] is Dictionary: return _remember_outfit(key, false)
		for direction in required[action]:
			var expected: Variant = required[action][direction]
			var actual := _frames(actor, str(action), str(direction)).size()
			if not (expected is int or expected is float) or not is_finite(float(expected)) or float(expected) != floorf(float(expected)) or expected <= 0 or expected > 256 or actual != int(expected):
				_diagnostic(_context(actor, str(action), str(direction), actual), "outfit '%s' requires %s poses, found %d; preserving the whole original outfit" % [outfit, str(expected), actual])
				return _remember_outfit(key, false)
	var count := 0
	for action in actions:
		if str(action) in ["canvas_size", "reference_size", "feet_baseline"]: continue
		if not actions[action] is Dictionary: return _remember_outfit(key, false)
		for direction in actions[action]:
			var frames := _frames(actor, str(action), str(direction))
			if frames.is_empty(): return _remember_outfit(key, false)
			for index in range(frames.size()):
				if not frames[index] is Dictionary or _validated_outfit_variant(frames[index], outfit, actor, str(action), str(direction), index).is_empty():
					return _remember_outfit(key, false)
				count += 1
	return _remember_outfit(key, count > 0)

func _remember_outfit(key: String, ready: bool) -> bool:
	if _outfit_ready.size() >= OUTFIT_CACHE_LIMIT: _outfit_ready.erase(_outfit_ready.keys()[0])
	_outfit_ready[key] = ready
	return ready

func _validated_outfit_variant(frame: Dictionary, outfit: String, actor: String, action: String, direction: String, index: int) -> Dictionary:
	var context := _context(actor, action, direction, index)
	var variants_value: Variant = frame.get("variants", {})
	if not variants_value is Dictionary:
		_diagnostic(context, "outfit '%s' variants must be an object; preserving the whole original outfit" % outfit)
		return {}
	if not variants_value.has(outfit):
		_diagnostic(context, "outfit '%s' is missing this pose; preserving the whole original outfit" % outfit)
		return {}
	var variant_value: Variant = variants_value[outfit]
	if not variant_value is Dictionary:
		_diagnostic(context, "variant '%s' must be an object; using base frame" % outfit)
		return {}
	var variant: Dictionary = variant_value
	var source_value: Variant = variant.get("source", "")
	var region_value: Variant = variant.get("region", [])
	var anchors_value: Variant = variant.get("anchors", null)
	if not source_value is String or str(source_value).is_empty() or not _valid_number_array(region_value, 4) or not anchors_value is Dictionary:
		_diagnostic(context, "variant '%s' requires a source, numeric region, and anchors object; using base frame" % outfit)
		return {}
	if not anchors_value.has("head") or not anchors_value.has("feet"):
		_diagnostic(context, "variant '%s' requires explicit head and feet anchors; preserving the whole original outfit" % outfit)
		return {}
	var region := _rect(region_value)
	if region.size.x > 2048 or region.size.y > 2048 or region.size.x * region.size.y > 4194304:
		_diagnostic(context, "variant '%s' region exceeds the frame safety limit; using base frame" % outfit)
		return {}
	var source_image := _image(str(source_value), actor, action, direction, index)
	if source_image == null or not _inside(source_image, region):
		_diagnostic(context, "variant '%s' source region is invalid or outside source; using base frame" % outfit)
		return {}
	for anchor_name in anchors_value:
		var anchor_value: Variant = anchors_value[anchor_name]
		if not _valid_number_array(anchor_value, 2):
			_diagnostic(context, "variant '%s' anchor '%s' must be a numeric [x,y] pair; using base frame" % [outfit, str(anchor_name)])
			return {}
		var point := _point(anchor_value)
		if point.x < 0 or point.y < 0 or point.x > region.size.x or point.y > region.size.y:
			_diagnostic(context, "variant '%s' anchor '%s' is outside its source frame; using base frame" % [outfit, str(anchor_name)])
			return {}
	var scale_value: Variant = frame.get("source_scale", 1.0)
	if not (scale_value is int or scale_value is float) or not is_finite(float(scale_value)) or float(scale_value) < 0.01 or float(scale_value) > 4.0:
		_diagnostic(context, "outfit '%s' has invalid shared source_scale; preserving the whole original outfit" % outfit)
		return {}
	return variant

func cached_texture_count() -> int:
	return _textures.size()

func _frames(actor: String, action: String, direction: String) -> Array:
	var entry := _entry(actor, action, direction)
	var frames: Variant = entry.get("frames", [])
	if not frames is Array or frames.size() > 256:
		return []
	return frames

func _entry(actor: String, action: String, direction: String) -> Dictionary:
	var actors: Dictionary = manifest.get("actors", {})
	var actions: Variant = actors.get(actor, {})
	var dirs: Variant = actions.get(action, {}) if actions is Dictionary else {}
	var entry: Variant = dirs.get(direction, {}) if dirs is Dictionary else {}
	var frames: Variant = entry.get("frames", []) if entry is Dictionary else null
	var valid_entry: bool = entry is Dictionary and frames is Array and frames.size() <= 256
	if valid_entry:
		var fps: Variant = entry.get("fps", 1.0)
		valid_entry = (fps is int or fps is float) and is_finite(float(fps)) and float(fps) > 0.0 and float(fps) <= 60.0
		var loop_value: Variant = entry.get("loop", true)
		valid_entry = valid_entry and loop_value is bool
		if entry.has("frame_durations"):
			var durations: Variant = entry.frame_durations
			valid_entry = valid_entry and durations is Array and durations.size() == frames.size() and not durations.is_empty()
			if valid_entry:
				for duration in durations:
					if not (duration is int or duration is float) or not is_finite(float(duration)) or float(duration) <= 0.0 or float(duration) > 30.0:
						valid_entry = false
						break
	if not valid_entry:
		var key := "%s/%s/%s" % [actor, action, direction]
		if not _warned.has(key) and _warned.size() < 128:
			_diagnostic(key, "missing or malformed authored direction/action; caller should use legacy fallback")
			_warned[key] = true
		return {}
	return entry

func _image(path: String, actor: String, action: String, direction: String, frame: int) -> Image:
	if _images.has(path):
		_image_order.erase(path)
		_image_order.append(path)
		return _images[path]
	var image: Image
	if path.begins_with("user://") or path.begins_with("/") or path.contains(":\\"):
		if FileAccess.file_exists(path):
			image = Image.new()
			if image.load(path) != OK: image = null
	else:
		if ResourceLoader.exists(path):
			var resource := ResourceLoader.load(path) as Texture2D
			image = resource.get_image() if resource != null else null
		if image == null and path.begins_with("res://") and FileAccess.file_exists(path):
			image = Image.new()
			if image.load(path) != OK: image = null
	if image == null:
		_diagnostic(_context(actor, action, direction, frame), "cannot load source '%s'" % path)
		return null
	if image.get_width() > 4096 or image.get_height() > 4096 or image.get_width() * image.get_height() > 8388608:
		_diagnostic(_context(actor, action, direction, frame), "source exceeds the 4096 edge / 8 megapixel safety limit")
		return null
	_images[path] = image
	_image_order.append(path)
	while _image_order.size() > IMAGE_CACHE_LIMIT:
		_images.erase(_image_order.pop_front())
	return image

func _rect(value: Variant) -> Rect2i:
	if not value is Array or value.size() != 4: return Rect2i()
	return Rect2i(int(value[0]), int(value[1]), int(value[2]), int(value[3]))

func _point(value: Variant) -> Vector2i:
	if not value is Array or value.size() != 2: return Vector2i.ZERO
	return Vector2i(int(value[0]), int(value[1]))

func _valid_number_array(value: Variant, expected_size: int) -> bool:
	if not value is Array or value.size() != expected_size: return false
	for component in value:
		if not (component is int or component is float) or not is_finite(float(component)): return false
	return true

func _inside(image: Image, rect: Rect2i) -> bool:
	return rect.position.x >= 0 and rect.position.y >= 0 and rect.size.x > 0 and rect.size.y > 0 and rect.end.x <= image.get_width() and rect.end.y <= image.get_height()

func _context(actor: String, action: String, direction: String, frame: int) -> String:
	return "%s/%s/%s/frame %d" % [actor, action, direction, frame]

func _diagnostic(context: String, message: String) -> void:
	var text := "%s: %s" % [context, message]
	if _diagnostic_keys.has(text) or diagnostics.size() >= 512: return
	_diagnostic_keys[text] = true
	diagnostics.append(text)
	if not text.begins_with("manifest: missing manifest:"):
		push_warning("Character animation: " + text)
