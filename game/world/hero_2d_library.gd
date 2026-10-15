extends Node2D
class_name Hero2DLibrary
## Runtime compositor for author-authored 2D hero cels and replacement parts.

const MANIFEST_PATH := "res://assets/characters/hero-2d-v1/manifest.json"
const DIRECTIONS := ["front", "front_right", "right", "back_right", "back", "back_left", "left", "front_left"]
const SOURCE_CACHE_LIMIT := 64
const REQUIRED_FORMAT := "production2d-authored-layers"

var manifest: Dictionary = {}
var diagnostics: Array[String] = []
var current_pose: Dictionary = {}
var current_appearance: Dictionary = {"hair_style": "windswept", "hat_on": false, "outfit": "tide_jacket"}
var manifest_path := MANIFEST_PATH
var _valid_manifest := false
var _fallback_image: Image
var _source_images: Dictionary = {}
var _source_order: Array[String] = []
var _sprite: Sprite2D
var _canvas_size := Vector2i(280, 360)
var _feet_origin := Vector2i(140, 346)
var _diagnostic_set: Dictionary = {}

func _init(path: String = MANIFEST_PATH) -> void:
	_sprite = Sprite2D.new()
	_sprite.name = "Hero2DComposite"
	_sprite.centered = false
	_sprite.position = Vector2(-_feet_origin.x, -_feet_origin.y)
	add_child(_sprite)
	initialize(path)

func initialize(path: String = MANIFEST_PATH) -> bool:
	manifest_path = path
	manifest.clear()
	diagnostics.clear()
	_diagnostic_set.clear()
	_source_images.clear()
	_source_order.clear()
	_fallback_image = null
	_valid_manifest = false
	_sprite.texture = null
	_sprite.position = Vector2(-_feet_origin.x, -_feet_origin.y)
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_diagnose("manifest", "cannot open manifest '%s'" % path)
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		_diagnose("manifest", "manifest must be a JSON object")
		return false
	manifest = parsed
	_load_fallback()
	if int(manifest.get("schema_version", 0)) != 1:
		_diagnose("schema_version", "expected schema_version 1")
		return false
	if str(manifest.get("format", "")) != REQUIRED_FORMAT:
		_diagnose("format", "expected '%s'" % REQUIRED_FORMAT)
		return false
	if not _valid_pair(manifest.get("canvas"), "canvas") or not _valid_pair(manifest.get("feet_origin"), "feet_origin"):
		return false
	_canvas_size = Vector2i(int(manifest.canvas[0]), int(manifest.canvas[1]))
	_feet_origin = Vector2i(int(manifest.feet_origin[0]), int(manifest.feet_origin[1]))
	if _canvas_size != Vector2i(280, 360) or _feet_origin != Vector2i(140, 346):
		_diagnose("canvas", "hero canvas and feet origin must be [280,360] and [140,346]")
		return false
	var direction_value: Variant = manifest.get("directions", [])
	if direction_value != DIRECTIONS:
		_diagnose("directions", "directions must match the canonical eight-direction order")
		return false
	if not manifest.get("outfits", {}) is Dictionary or not manifest.outfits.has("tide_jacket") or not manifest.outfits.has("long_coat"):
		_diagnose("outfits", "outfits must include tide_jacket and long_coat")
		return false
	if not manifest.get("poses", {}) is Dictionary or not manifest.get("hair", {}) is Dictionary or not manifest.get("hats", {}) is Dictionary:
		_diagnose("manifest", "poses, hair, and hats must be objects")
		return false
	var default_hair := str(manifest.get("default_hair", "windswept"))
	var default_outfit := str(manifest.get("default_outfit", "tide_jacket"))
	if default_hair.is_empty() or not manifest.hair.has(default_hair):
		default_hair = str(manifest.hair.keys()[0]) if not manifest.hair.is_empty() else ""
	if default_outfit.is_empty() or not manifest.outfits.has(default_outfit):
		default_outfit = "tide_jacket"
	if default_hair.is_empty():
		_diagnose("hair", "manifest has no hair style")
		return false
	_valid_manifest = true
	current_appearance = {"hair_style": default_hair, "hat_on": false, "outfit": default_outfit}
	_sprite.position = Vector2(-_feet_origin.x, -_feet_origin.y)
	if not _appearance_complete(current_appearance):
		_valid_manifest = false
		_diagnose("coverage", "default appearance lacks complete eight-direction/action coverage")
		return false
	return true

func set_appearance(hair_style: String, hat_on: bool, outfit: String) -> bool:
	var candidate := {"hair_style": hair_style, "hat_on": hat_on, "outfit": outfit}
	if not _valid_manifest:
		_diagnose("appearance", "cannot change appearance without a valid manifest")
		return false
	if not _appearance_complete(candidate):
		_diagnose("appearance", "requested appearance is incomplete; current appearance retained")
		return false
	current_appearance = candidate
	if not current_pose.is_empty():
		render_pose(current_pose)
	return true

func render_pose(state: Dictionary) -> bool:
	current_pose = state.duplicate(true)
	var image := compose_frame(current_pose)
	if image == null:
		_sprite.texture = null
		return false
	_sprite.texture = ImageTexture.create_from_image(image)
	return _valid_manifest and _pose_frame(current_pose) != null

func compose_frame(state: Dictionary, appearance: Dictionary = {}) -> Image:
	if not _valid_manifest:
		return _fallback_image.duplicate() if _fallback_image != null else null
	var selected := current_appearance.duplicate()
	for key in appearance:
		selected[key] = appearance[key]
	var frame: Variant = _pose_frame(state)
	if frame == null:
		return _fallback_image.duplicate() if _fallback_image != null else null
	var direction := _direction_for_state(state)
	var action := str(state.get("action", ""))
	var outfit := str(selected.get("outfit", ""))
	var body_source := str(frame.get("source", ""))
	var body_region: Variant = frame.get("region", [])
	var outfit_variant: Dictionary = {}
	if outfit != "tide_jacket":
		var variants: Variant = frame.get("outfits", {})
		var variant: Variant = variants.get(outfit, {}) if variants is Dictionary else {}
		if not variant is Dictionary or not variant.has("source") or not variant.has("region"):
			_diagnose("%s/%s" % [direction, action], "missing outfit variant '%s'" % outfit)
			return _fallback_image.duplicate() if _fallback_image != null else null
		outfit_variant = variant
		body_source = str(variant.source)
		body_region = variant.region
	var body := _read_region(body_source, body_region, "%s/%s body" % [direction, action], _canvas_size)
	if body == null:
		return _fallback_image.duplicate() if _fallback_image != null else null
	var anchor_value: Variant = outfit_variant.get("head_anchor", frame.head_anchor)
	var head_anchor := Vector2i(anchor_value[0], anchor_value[1])
	var result := Image.create(_canvas_size.x, _canvas_size.y, false, Image.FORMAT_RGBA8)
	result.fill(Color.TRANSPARENT)
	var part_data := _directional_parts(selected, direction)
	if part_data.is_empty():
		return _fallback_image.duplicate() if _fallback_image != null else null
	var hair_layers: Array = part_data.hair
	var hat_layers: Array = part_data.hat
	_draw_layers(result, hair_layers, head_anchor, "behind", direction, action)
	_draw_layers(result, hat_layers, head_anchor, "behind", direction, action)
	result.blend_rect(body, Rect2i(Vector2i.ZERO, _canvas_size), Vector2i.ZERO)
	_draw_layers(result, hair_layers, head_anchor, "front", direction, action)
	_draw_layers(result, hat_layers, head_anchor, "front", direction, action)
	var foreground: Variant = outfit_variant.get("foreground_regions", frame.get("foreground_regions", []))
	if foreground is Array:
		for value in foreground:
			var rect := _rect(value)
			if not _inside(_canvas_size, rect):
				_diagnose("%s/%s" % [direction, action], "foreground region is outside canonical body frame")
				return _fallback_image.duplicate() if _fallback_image != null else null
			result.blend_rect(body, rect, rect.position)
	return result

func get_diagnostics() -> Array[String]:
	return diagnostics.duplicate()

func _pose_frame(state: Dictionary) -> Variant:
	if not _valid_manifest: return null
	var direction := _direction_for_state(state)
	if direction.is_empty(): return null
	var action := str(state.get("action", ""))
	var directions: Variant = manifest.poses.get(direction, {})
	var frames: Variant = directions.get(action, []) if directions is Dictionary else []
	if not frames is Array or frames.is_empty():
		_diagnose("%s/%s" % [direction, action], "missing authored action frames")
		return null
	var index := int(state.get("frame", state.get("frame_index", 0)))
	if index < 0 or index >= frames.size():
		_diagnose("%s/%s" % [direction, action], "frame index %d is outside authored sequence" % index)
		return null
	var value: Variant = frames[index]
	if not value is Dictionary or not _valid_pair(value.get("head_anchor"), "%s/%s head_anchor" % [direction, action]) or not _valid_pair(value.get("feet"), "%s/%s feet" % [direction, action]):
		return null
	return value

func _direction_for_state(state: Dictionary) -> String:
	var direction := str(state.get("visual_direction", state.get("direction", "front")))
	if not DIRECTIONS.has(direction):
		_diagnose("direction", "unknown direction '%s'; complete fallback used" % direction)
		return ""
	return direction

func _appearance_complete(value: Dictionary) -> bool:
	var hair_style := str(value.get("hair_style", ""))
	var outfit := str(value.get("outfit", ""))
	var hat_on: bool = bool(value.get("hat_on", false))
	if not manifest.hair.has(hair_style) or not manifest.outfits.has(outfit):
		_diagnose("appearance", "unknown hair style or outfit")
		return false
	if not _part_style_complete(manifest.hair[hair_style], "hair/%s" % hair_style): return false
	if hat_on:
		var hat_style: Variant = manifest.hats.get("traveller", null)
		if not hat_style is Dictionary or not _part_style_complete(hat_style, "hats/traveller"):
			_diagnose("hats/traveller", "hat layers are not complete for all directions")
			return false
	for direction in DIRECTIONS:
		var actions: Variant = manifest.poses.get(direction, {})
		if not actions is Dictionary or actions.is_empty():
			_diagnose("poses/%s" % direction, "no authored actions")
			return false
		if direction != DIRECTIONS[0]:
			var first_actions: Dictionary = manifest.poses.get(DIRECTIONS[0], {})
			if actions.keys().size() != first_actions.keys().size():
				_diagnose("poses/%s" % direction, "action coverage differs from %s" % DIRECTIONS[0])
				return false
			for action_name in first_actions:
				if not actions.has(action_name):
					_diagnose("poses/%s" % direction, "missing action '%s'" % action_name)
					return false
		for action in actions:
			var frames: Variant = actions[action]
			if not frames is Array or frames.is_empty():
				_diagnose("%s/%s" % [direction, action], "no authored frames")
				return false
			for frame in frames:
				if not frame is Dictionary or not _valid_pose_frame(frame, direction, str(action)) or not _valid_body_frame(frame, direction, str(action), outfit): return false
	return true

func _valid_body_frame(frame: Dictionary, direction: String, action: String, outfit: String) -> bool:
	var source := str(frame.get("source", ""))
	var region: Variant = frame.get("region", [])
	if outfit != "tide_jacket":
		var variants: Variant = frame.get("outfits", {})
		var variant: Variant = variants.get(outfit, {}) if variants is Dictionary else {}
		if not variant is Dictionary:
			_diagnose("%s/%s" % [direction, action], "missing outfit variant '%s'" % outfit)
			return false
		source = str(variant.get("source", ""))
		region = variant.get("region", [])
		if variant.has("head_anchor") and not _valid_pair(variant.head_anchor, "%s/%s outfits/%s head_anchor" % [direction, action, outfit]): return false
		if variant.has("foreground_regions") and not _valid_foreground_regions(variant.foreground_regions, "%s/%s outfits/%s" % [direction, action, outfit]): return false
	var image := _read_region(source, region, "%s/%s body" % [direction, action], _canvas_size)
	if image == null: return false
	return true

func _valid_pose_frame(frame: Dictionary, direction: String, action: String) -> bool:
	if not _valid_pair(frame.get("head_anchor"), "%s/%s head_anchor" % [direction, action]) or not _valid_pair(frame.get("feet"), "%s/%s feet" % [direction, action]): return false
	var foreground: Variant = frame.get("foreground_regions", [])
	return _valid_foreground_regions(foreground, "%s/%s" % [direction, action])

func _valid_foreground_regions(foreground: Variant, context: String) -> bool:
	if not foreground is Array:
		_diagnose(context, "foreground_regions must be an array")
		return false
	for value in foreground:
		var rect := _rect(value)
		if not _inside(_canvas_size, rect):
			_diagnose(context, "foreground region is outside canonical body frame")
			return false
	return true

func _directional_parts(selected: Dictionary, direction: String) -> Dictionary:
	var hair_style: Variant = manifest.hair.get(str(selected.get("hair_style", "")), {})
	var hair_entry: Variant = hair_style.get(direction, {}) if hair_style is Dictionary else {}
	var hair_layers: Variant = hair_entry.get("layers", []) if hair_entry is Dictionary else []
	if bool(selected.get("hat_on", false)) and hair_entry is Dictionary and hair_entry.has("hat_layers"):
		hair_layers = hair_entry.hat_layers
	if not _validate_layers(hair_layers, "hair/%s/%s" % [selected.get("hair_style", ""), direction]): return {}
	var hat_layers: Array = []
	if bool(selected.get("hat_on", false)):
		var combined_variant := hair_entry is Dictionary and bool(hair_entry.get("hat_layers_include_hat", false))
		if not combined_variant:
			var hat_style: Variant = manifest.hats.get("traveller", {})
			var hat_entry: Variant = hat_style.get(direction, {}) if hat_style is Dictionary else {}
			var value: Variant = hat_entry.get("layers", []) if hat_entry is Dictionary else []
			if not _validate_layers(value, "hat/%s" % direction): return {}
			hat_layers = value
	return {"hair": hair_layers, "hat": hat_layers}

func _part_style_complete(style: Variant, context: String) -> bool:
	if not style is Dictionary: return false
	for direction in DIRECTIONS:
		var entry: Variant = style.get(direction, {})
		if not entry is Dictionary or not _validate_layers(entry.get("layers", []), "%s/%s" % [context, direction]): return false
		if entry.has("hat_layers_include_hat") and not entry.hat_layers_include_hat is bool:
			_diagnose("%s/%s" % [context, direction], "hat_layers_include_hat must be boolean")
			return false
		if bool(entry.get("hat_layers_include_hat", false)) and not entry.has("hat_layers"):
			_diagnose("%s/%s" % [context, direction], "hat_layers_include_hat requires combined hat_layers")
			return false
		if entry.has("hat_layers") and not _validate_layers(entry.hat_layers, "%s/%s hat_layers" % [context, direction]): return false
	return true

func _validate_layers(layers: Variant, context: String) -> bool:
	if not layers is Array:
		_diagnose(context, "layers must be an array")
		return false
	if layers.is_empty():
		_diagnose(context, "layers must contain at least one authored layer")
		return false
	for index in range(layers.size()):
		var layer: Variant = layers[index]
		if not layer is Dictionary or not layer.get("order", "") in ["behind", "front"]:
			_diagnose(context, "layer %d requires order behind/front" % index)
			return false
		var region: Variant = layer.get("region", [])
		var image := _read_region(str(layer.get("source", "")), region, "%s layer %d" % [context, index])
		if image == null: return false
		if not _valid_pair(layer.get("anchor"), "%s layer %d anchor" % [context, index]) or not _valid_pair(layer.get("offset", [0, 0]), "%s layer %d offset" % [context, index]): return false
	return true

func _draw_layers(target: Image, layers: Array, head_anchor: Vector2i, order: String, direction: String, action: String) -> void:
	for index in range(layers.size()):
		var layer: Dictionary = layers[index]
		if str(layer.get("order", "")) != order: continue
		var part := _read_region(str(layer.get("source", "")), layer.get("region", []), "%s/%s part %d" % [direction, action, index])
		if part == null: continue
		var anchor := Vector2i(layer.anchor[0], layer.anchor[1])
		var offset := Vector2i(layer.get("offset", [0, 0])[0], layer.get("offset", [0, 0])[1])
		var position := head_anchor - anchor + offset
		target.blend_rect(part, Rect2i(Vector2i.ZERO, part.get_size()), position)

func _load_fallback() -> void:
	var value: Variant = manifest.get("fallback", {})
	if not value is Dictionary:
		_diagnose("fallback", "manifest must provide a complete fallback frame")
		return
	_fallback_image = _read_region(str(value.get("source", "")), value.get("region", []), "fallback", _canvas_size)
	if _fallback_image == null:
		_diagnose("fallback", "complete fallback image is unavailable")

func _read_region(path: String, region_value: Variant, context: String, required_size: Vector2i = Vector2i.ZERO) -> Image:
	if path.is_empty() or not region_value is Array or region_value.size() != 4:
		_diagnose(context, "source and [x,y,w,h] region are required")
		return null
	for value in region_value:
		if not (value is int or value is float) or not is_finite(float(value)):
			_diagnose(context, "region coordinates must be finite numbers")
			return null
	var region := Rect2i(int(region_value[0]), int(region_value[1]), int(region_value[2]), int(region_value[3]))
	var image := _source_image(path, context)
	if image == null or not _inside(image.get_size(), region):
		_diagnose(context, "source region is missing or outside image: %s" % path)
		return null
	if required_size != Vector2i.ZERO and region.size != required_size:
		_diagnose(context, "source region must be %dx%d" % [required_size.x, required_size.y])
		return null
	return image.get_region(region)

func _source_image(path: String, context: String) -> Image:
	var resolved := _resolve_path(path)
	if _source_images.has(resolved):
		_source_order.erase(resolved)
		_source_order.append(resolved)
		return _source_images[resolved]
	var image: Image
	if resolved.begins_with("res://") and ResourceLoader.exists(resolved):
		var texture := ResourceLoader.load(resolved) as Texture2D
		if texture != null: image = texture.get_image()
	if image == null:
		image = Image.new()
		if image.load(resolved) != OK: image = null
	if image == null:
		_diagnose(context, "cannot load source '%s'" % resolved)
		return null
	_source_images[resolved] = image
	_source_order.append(resolved)
	while _source_order.size() > SOURCE_CACHE_LIMIT:
		_source_images.erase(_source_order.pop_front())
	return image

func _resolve_path(path: String) -> String:
	if path.begins_with("res://") or path.begins_with("user://") or path.is_absolute_path(): return path
	return manifest_path.get_base_dir().path_join(path).simplify_path()

func _valid_pair(value: Variant, context: String) -> bool:
	if not value is Array or value.size() != 2:
		_diagnose(context, "must be a numeric [x,y] pair")
		return false
	for component in value:
		if not (component is int or component is float) or not is_finite(float(component)):
			_diagnose(context, "must be a finite numeric [x,y] pair")
			return false
	return true

func _rect(value: Variant) -> Rect2i:
	if not value is Array or value.size() != 4: return Rect2i()
	return Rect2i(int(value[0]), int(value[1]), int(value[2]), int(value[3]))

func _inside(size: Vector2i, rect: Rect2i) -> bool:
	return rect.position.x >= 0 and rect.position.y >= 0 and rect.size.x > 0 and rect.size.y > 0 and rect.end.x <= size.x and rect.end.y <= size.y

func _diagnose(context: String, message: String) -> void:
	var text := "%s: %s" % [context, message]
	if _diagnostic_set.has(text) or diagnostics.size() >= 128: return
	_diagnostic_set[text] = true
	diagnostics.append(text)
	push_warning("Hero2DLibrary: " + text)
