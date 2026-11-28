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
##   "action": authored NPC action for the speaker ("greet", "interact", …)
##   "hold": seconds of stillness before the text (a comedic beat)
## A line with "pantomime": true has no subtitle: only the cue, then it moves on.
## Reduced motion keeps the meaning (framing, emote, hold) but cuts instead of
## gliding and the emote does not bounce.

const GLIDE_SECONDS := 0.45
const EMOTE_SECONDS := 1.6
## The subtitle covers the lower third, so a framed actor sits a little high.
const SUBTITLE_LIFT := 0.16
## Orthographic framing only needs the focus in front of the near plane; this is room to spare.
const MIN_DEPTH := 20.0
const MARKS :=["!", "?", "!?", "…", "♪", "♥", "sweat"]

## Resolves an actor id to the node to frame: set by the caller.
var actor_lookup: Callable
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
	var frame := str(cue.get("frame", ""))
	if not frame.is_empty():
		_frame(frame, speaker_id, float(cue.get("zoom", 1.0 if frame == "wide" else 0.72)))
	var mark := str(cue.get("emote", ""))
	if MARKS.has(mark):
		var on := str(cue.get("emote_on", speaker_id))
		var node := _actor(on)
		if node != null: _show_emote(mark, node)
	var action := str(cue.get("action", ""))
	if not action.is_empty() and actor_lookup.is_valid():
		actor_lookup.call(speaker_id, action)
	return clampf(float(cue.get("hold", 0.0)), 0.0, 2.5)

func _actor(id: String) -> Node3D:
	if id.is_empty() or not actor_lookup.is_valid(): return null
	var node: Variant = actor_lookup.call(id, "")
	return node as Node3D if node is Node3D and is_instance_valid(node) else null

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
		height = (node as Sprite3D).texture.get_height() * (node as Sprite3D).pixel_size * 0.5
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
		top = (node as Sprite3D).texture.get_height() * (node as Sprite3D).pixel_size * 0.5
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
	if is_instance_valid(camera):
		if camera.current and is_instance_valid(_world_camera): _world_camera.make_current()
		camera.free()
	camera = null
	set_process(false)

func _exit_tree() -> void:
	finish()

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
