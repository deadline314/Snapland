extends Node3D
## Small in-engine staging for dialogue: per-line cues frame the camera on an
## actor, pop an emote over a head, play an authored NPC action, or hold a
## silent beat before the line. Everything is reversible: finish() hands the
## view back to the world's own camera and frees what this made.
##
## A dialogue line may carry `"cue": {...}`:
##   "frame": actor id | "two" (speaker and player) | "wide" (back to the start)
##   "zoom": camera size factor (0.5 = punch in), default 1 for "wide"
##   "emote": "!", "?", "!?", "…", "♪", "♥" or "sweat"; "emote_on": actor id
##   "action": authored NPC action ("greet", "interact", …); "action_on": actor id (default the speaker)
##   "hold": seconds of stillness before the text (a comedic beat)
##   "prop": "bowtie"; "prop_on": actor id holding it (one prop at a time)
##   "exit": a stage double leaves the shot (with any prop it holds)
## An actor id "<role>_mirror" is a stage-made reflection of that role: a flipped,
## cool-tinted copy beside it. It strikes a pose only on the beat that asks and
## stands at rest otherwise.
## A line with "pantomime": true has no subtitle: only the cue, then it moves on.
## Reduced motion keeps the meaning (framing, emote, hold) but cuts instead of
## gliding and the emote does not bounce.

const GLIDE_SECONDS := 0.45
const EMOTE_SECONDS := 1.6
## The subtitle covers the lower third, so a framed actor sits a little high.
const SUBTITLE_LIFT := 0.16
## Orthographic framing only needs the focus in front of the near plane; this is room to spare.
const MIN_DEPTH := 20.0
const MARKS := ["!", "?", "!?", "…", "♪", "♥", "sweat"]
const PROPS := ["bowtie"]
const MIRROR_TINT := Color(0.74, 0.86, 1.0, 0.82)
## A reflection stands this far to the screen-right of its role.
const MIRROR_GAP := 1.7

## Resolves an actor id to the node to frame: set by the caller.
var actor_lookup: Callable
## (role, action) -> Texture2D: the front pose a reflection strikes; set by the caller.
var pose_lookup: Callable
## (role, action) -> bool: plays the role's authored action; false when nothing played.
var react: Callable
var _posed: Dictionary = {}
var _doubles: Dictionary = {}
var _prop: Sprite3D
var _prop_holder: Node3D
var camera: Camera3D
var _world_camera: Camera3D
var _start: Transform3D
var _start_size := 0.0
var _reduced := false
var _tween: Tween
var _emote: Node3D
var _emote_left := 0.0
var _emote_base := Vector3.ZERO
var _emote_time := 0.0

func begin(world_camera: Camera3D, reduced_motion: bool) -> bool:
	if is_instance_valid(camera) or not is_instance_valid(world_camera) or not is_inside_tree(): return false
	_world_camera = world_camera
	_reduced = reduced_motion
	camera = Camera3D.new()
	camera.name = "StageCueCamera"
	camera.projection = world_camera.projection
	camera.size = world_camera.size
	camera.fov = world_camera.fov
	camera.far = world_camera.far
	camera.near = world_camera.near
	add_child(camera)
	camera.global_transform = world_camera.global_transform
	_start = camera.global_transform
	_start_size = camera.size
	camera.make_current()
	set_process(true)
	return true

func active() -> bool:
	return is_instance_valid(camera)

## Seconds the caller should keep the subtitle back before showing the line.
func apply(cue: Dictionary, speaker_id: String) -> float:
	if not active() or cue.is_empty(): return 0.0
	for double in _doubles.values():
		if is_instance_valid(double): double.texture = double.get_meta("rest")
	_restore_poses()
	var leaving := str(cue.get("exit", ""))
	if _doubles.has(leaving) and is_instance_valid(_doubles[leaving]):
		_doubles[leaving].visible = false
		if _prop_holder == _doubles[leaving]: _clear_prop()
	var frame := str(cue.get("frame", ""))
	if not frame.is_empty():
		_frame(frame, speaker_id, float(cue.get("zoom", 1.0 if frame == "wide" else 0.72)))
	var mark := str(cue.get("emote", ""))
	if MARKS.has(mark):
		var on := str(cue.get("emote_on", speaker_id))
		var node := _actor(on)
		if node != null: _show_emote(mark, node)
	var action := str(cue.get("action", ""))
	var action_on := str(cue.get("action_on", speaker_id))
	if not action.is_empty():
		if action_on.ends_with("_mirror"):
			var double := _actor(action_on) as Sprite3D
			var pose: Variant = pose_lookup.call(action_on.trim_suffix("_mirror"), action) if pose_lookup.is_valid() else null
			if double != null and pose is Texture2D: double.texture = pose
		else:
			if react.is_valid(): react.call(action_on, action)
			# Also hold the key pose for this beat: a district's resting host has no animation to
			# play it, and an animated one simply draws over it on its next frame.
			var sprite := _actor(action_on) as Sprite3D
			var pose: Variant = pose_lookup.call(action_on, action) if pose_lookup.is_valid() else null
			if sprite != null and pose is Texture2D and not _posed.has(sprite):
				var material := sprite.material_override as ShaderMaterial
				_posed[sprite] = [sprite.texture, material.get_shader_parameter("texture_albedo") if material != null else null, material.get_shader_parameter("uv_rect") if material != null else null]
				_show_pose(sprite, pose, Vector4(0, 0, 1, 1))
	var prop := str(cue.get("prop", ""))
	if PROPS.has(prop):
		var holder := _actor(str(cue.get("prop_on", speaker_id)))
		if holder != null: _show_prop(prop, holder)
	return clampf(float(cue.get("hold", 0.0)), 0.0, 2.5)

func _actor(id: String) -> Node3D:
	if id.is_empty() or not actor_lookup.is_valid(): return null
	if id.ends_with("_mirror"): return _double(id)
	var node: Variant = actor_lookup.call(id, "")
	return node as Node3D if node is Node3D and is_instance_valid(node) else null

## A reflection of a role, made on first use and freed by finish().
func _double(id: String) -> Sprite3D:
	if _doubles.has(id) and is_instance_valid(_doubles[id]):
		_doubles[id].visible = true
		return _doubles[id]
	var base := _actor(id.trim_suffix("_mirror")) as Sprite3D
	if base == null or base.texture == null: return null
	var double := Sprite3D.new()
	double.name = "StageMirror"
	double.texture = base.texture
	double.set_meta("rest", base.texture)
	double.pixel_size = base.pixel_size
	double.flip_h = true
	double.modulate = MIRROR_TINT
	double.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	double.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	double.shaded = false
	double.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(double)
	double.global_position = base.global_position + _start.basis.x.normalized() * MIRROR_GAP
	_doubles[id] = double
	return double

func _show_prop(kind: String, holder: Node3D) -> void:
	_clear_prop()
	_prop = Sprite3D.new()
	_prop.name = "StageProp"
	_prop.texture = _prop_texture(kind)
	_prop.pixel_size = 0.022
	_prop.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prop.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_prop.shaded = false
	_prop.render_priority = 9
	holder.add_child(_prop)
	# Held up beside the holder's shoulder.
	var top := 1.0
	if holder is Sprite3D and (holder as Sprite3D).texture != null:
		top = _half_height(holder as Sprite3D)
	_prop.global_position = holder.global_position + Vector3(0, top * 0.55, 0) + _start.basis.x.normalized() * 0.45
	_prop_holder = holder

func _restore_poses() -> void:
	for sprite in _posed:
		if not is_instance_valid(sprite): continue
		var saved: Array = _posed[sprite]
		sprite.texture = saved[0]
		var material := sprite.material_override as ShaderMaterial
		if material != null and saved[1] != null:
			material.set_shader_parameter("texture_albedo", saved[1])
			material.set_shader_parameter("uv_rect", saved[2])
	_posed.clear()

## Living NPC sprites draw through a shader that reads its own texture parameter.
static func _show_pose(sprite: Sprite3D, texture: Texture2D, uv_rect: Vector4) -> void:
	sprite.texture = texture
	var material := sprite.material_override as ShaderMaterial
	if material != null:
		material.set_shader_parameter("texture_albedo", texture)
		material.set_shader_parameter("uv_rect", uv_rect)

## Half the drawn height of one frame: an atlas sprite (the thief) shows one cell, not the sheet.
static func _half_height(sprite: Sprite3D) -> float:
	var height := float(sprite.region_rect.size.y) if sprite.region_enabled else float(sprite.texture.get_height()) / maxi(sprite.vframes, 1)
	return height * sprite.pixel_size * 0.5

func _clear_prop() -> void:
	if is_instance_valid(_prop): _prop.free()
	_prop = null
	_prop_holder = null

## Framing keeps the world camera's angle (billboards stay upright); it only
## slides along the view plane and changes the orthographic size.
func _frame(frame: String, speaker_id: String, zoom: float) -> void:
	var target_transform := _start
	var target_size := _start_size * clampf(zoom, 0.35, 1.4)
	if frame != "wide":
		var focus := Vector3.INF
		if frame == "two":
			var a := _actor(speaker_id)
			var b := _actor("player")
			if a != null and b != null: focus = (_head(a) + _head(b)) * 0.5
		else:
			var node := _actor(frame)
			if node != null: focus = _head(node)
		if not focus.is_finite(): return
		var forward := -_start.basis.z.normalized()
		# Keep the focus comfortably in front of the lens: a target that lies behind the
		# starting camera (the island seen from the ferry) would otherwise fall past the near plane.
		var depth := maxf(forward.dot(focus - _start.origin), MIN_DEPTH)
		target_transform.origin = focus - forward * depth - _start.basis.y.normalized() * target_size * SUBTITLE_LIFT
	if is_instance_valid(_tween): _tween.kill()
	if _reduced:
		camera.global_transform = target_transform
		camera.size = target_size
		return
	# Long pans (across the bay to the island) take a little longer than a punch-in.
	var seconds := clampf(camera.global_position.distance_to(target_transform.origin) / 24.0, GLIDE_SECONDS, 1.1)
	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(camera, "global_transform", target_transform, seconds)
	_tween.tween_property(camera, "size", target_size, seconds)

func _head(node: Node3D) -> Vector3:
	var height := 1.0
	if node is Sprite3D and (node as Sprite3D).texture != null:
		height = _half_height(node as Sprite3D)
	return node.global_position + Vector3(0, height * 0.5, 0)

func _show_emote(mark: String, node: Node3D) -> void:
	_clear_emote()
	_emote = Node3D.new()
	_emote.name = "StageEmote"
	var bubble := Sprite3D.new()
	bubble.texture = _bubble_texture(mark == "sweat")
	bubble.pixel_size = 0.012
	bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	bubble.no_depth_test = true
	bubble.render_priority = 10
	bubble.shaded = false
	bubble.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	_emote.add_child(bubble)
	if mark != "sweat":
		var glyph := Label3D.new()
		glyph.text = mark
		glyph.font_size = 64
		glyph.pixel_size = 0.012
		glyph.outline_size = 0
		glyph.modulate = Color("#3b2a44")
		glyph.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		glyph.no_depth_test = true
		glyph.render_priority = 11
		glyph.position = Vector3(0, 0.08, 0)
		_emote.add_child(glyph)
	add_child(_emote)
	var top := 2.0
	if node is Sprite3D and (node as Sprite3D).texture != null:
		top = _half_height(node as Sprite3D)
	_emote_base = node.global_position + Vector3(0.35, top + 0.45, 0)
	_emote.global_position = _emote_base
	_emote_left = EMOTE_SECONDS
	_emote_time = 0.0
	if not _reduced:
		_emote.scale = Vector3.ONE * 0.2
		create_tween().tween_property(_emote, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _process(delta: float) -> void:
	if not is_instance_valid(_emote): return
	_emote_left -= delta
	_emote_time += delta
	if not _reduced:
		_emote.global_position = _emote_base + Vector3(0, absf(sin(_emote_time * 7.0)) * 0.06 * maxf(0.0, 1.0 - _emote_time), 0)
	if _emote_left <= 0.0: _clear_emote()

func _clear_emote() -> void:
	if is_instance_valid(_emote): _emote.free()
	_emote = null

func emote_visible() -> bool:
	return is_instance_valid(_emote)

func finish() -> void:
	if is_instance_valid(_tween): _tween.kill()
	_clear_emote()
	_clear_prop()
	_restore_poses()
	for double in _doubles.values():
		if is_instance_valid(double): double.free()
	_doubles.clear()
	if is_instance_valid(camera):
		if camera.current and is_instance_valid(_world_camera): _world_camera.make_current()
		camera.free()
	camera = null
	set_process(false)

func _exit_tree() -> void:
	finish()

static var _props: Dictionary = {}

## A small pixel bowtie: two inked wings and a knot.
static func _prop_texture(kind: String) -> Texture2D:
	if _props.has(kind): return _props[kind]
	var w := 30
	var h := 18
	var image := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var inside := func(x: int, y: int) -> bool:
		var dx := absf(x - 14.5)
		var dy := absf(y - 8.5)
		return (dx <= 13.5 and dy <= dx * 0.55 + 2.0) or (dx <= 2.5 and dy <= 4.5)
	for y in range(h):
		for x in range(w):
			if not inside.call(x, y): continue
			var edge: bool = not (inside.call(x - 1, y) and inside.call(x + 1, y) and inside.call(x, y - 1) and inside.call(x, y + 1))
			var knot: bool = absf(x - 14.5) <= 2.5
			image.set_pixel(x, y, Color("#3b2a44") if edge else (Color("#a8324f") if knot else Color("#e0546f")))
	var texture := ImageTexture.create_from_image(image)
	_props[kind] = texture
	return texture

static var _bubbles: Dictionary = {}

## A cream sticker bubble with an ink rim and a little tail; or a sweat drop.
static func _bubble_texture(sweat: bool) -> Texture2D:
	if _bubbles.has(sweat): return _bubbles[sweat]
	var size := 96
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var ink := Color("#3b2a44")
	var cream := Color("#fff4dc")
	var sky := Color("#8fd3f0")
	var center := Vector2(48, 42)
	for y in range(size):
		for x in range(size):
			var p := Vector2(x + 0.5, y + 0.5)
			var inside := 0.0
			var rim := 0.0
			if sweat:
				# Teardrop: a circle at the bottom meeting a point at the top.
				var c := Vector2(48, 60)
				var d := p.distance_to(c)
				var t := clampf((c.y - p.y) / 46.0, 0.0, 1.0)
				var r := 24.0 * (1.0 - t * t) if p.y < c.y else 24.0
				inside = 1.0 if (d <= 24.0 or (p.y < c.y and absf(p.x - c.x) <= r and p.y > c.y - 46.0)) else 0.0
				var shrink := 18.0 * (1.0 - t * t) if p.y < c.y else 18.0
				rim = 0.0 if (p.distance_to(c) <= 18.0 or (p.y < c.y and absf(p.x - c.x) <= shrink and p.y > c.y - 38.0)) else 1.0
				if inside > 0.0: image.set_pixel(x, y, ink if rim > 0.0 else sky)
				continue
			var d := p.distance_to(center)
			# Tail: a small triangle down-left of the bubble.
			var tail := p.y > 70 and p.y < 90 and p.x > 26 and p.x < 46 and (p.x - 26.0) > (p.y - 70.0) * 0.9
			if d <= 38.0 or tail:
				var edge := d > 32.0 and not (tail and d > 38.0)
				var tail_edge := tail and d > 38.0 and ((p.x - 26.0) - (p.y - 70.0) * 0.9 < 6.0 or p.x > 40.0 or p.y > 84.0)
				image.set_pixel(x, y, ink if (edge or tail_edge) else cream)
	var texture := ImageTexture.create_from_image(image)
	_bubbles[sweat] = texture
	return texture
