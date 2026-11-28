extends RefCounted
## Part-based rig for big pixel characters (design/01-park/other-space.md §7).
##
## A character is a tree of baked pixel parts, each with a pivot texel, a parent
## and a draw layer. Moves are keyed poses with easing; between keys every frame
## is computed, so a two-second move has a hundred-odd distinct frames instead of
## two or three sprite diffs. On top of the keys sit procedural layers: an idle
## that never stops (breath, sway, part wobble, blinks), follow-through (a part
## re-samples its parents a little in the past, so ribbons and strings arrive and
## settle late), stretch along fast motion, and a hit flinch.
##
## `solve()` is a pure function of (move, time into it, clock, hit age): no state
## accumulates, so pausing freezes it, replays match and it runs headless. Draw
## the result through a `Stage` (a texel-sized SubViewport) so rotated parts stay
## on one pixel grid when the picture is scaled up.

## Channels a pose may set per part: rot (degrees), at (texel offset from the
## rest place), scale, squash (> 0 wider and shorter, area kept) and frame (index
## into the part's textures, stepped, never blended).
const CHANNELS := ["rot", "at", "scale", "squash", "frame"]
const EASES := ["linear", "in", "out", "inout", "back", "snap"]
## Seconds back a follow-through part looks per unit of `drag`.
const DRAG_SECONDS := 0.11
const DRAG_LIMIT := 35.0
## Texels per second at which a smearing part starts to stretch.
const SMEAR_SPEED := 70.0
const SMEAR_MAX := 0.4
const FLINCH_SECONDS := 0.6
const FLASH_SECONDS := 0.12
const BREATH_PERIOD := 2.4
const SWAY_PERIOD := 3.7
const BLINK_SECONDS := 0.13
const FRAME := 1.0 / 60.0

var parts: Array[Dictionary] = []
var poses: Dictionary = {}
var moves: Dictionary = {}
var reduced_motion := false
## Root idle amplitudes: squash from breathing, sway degrees, bob texels.
var breath := 0.035
var sway := 2.5
var bob := 1.5
var _index: Dictionary = {}
var _silhouettes: Dictionary = {}
var _drift := Vector2.ZERO


## `textures` is one texture or an array (switched by the frame channel). `at`
## places this part's pivot in its parent's pivot space. `drag` (0..1) sets
## follow-through; `rot` is the rest angle; `wobble` [degrees, period] adds an idle swing; `blink` squeezes
## the part shut now and then; `smear` lets it stretch along fast motion;
## `upright` parts (balloons) float level instead of turning with their parent.
func add_part(name: String, textures: Variant, pivot: Vector2, parent := "", at := Vector2.ZERO, z := 0, options := {}) -> void:
	assert(not _index.has(name) and (parent.is_empty() or _index.has(parent)), "parts are added parents first, once each")
	var list: Array = textures if textures is Array else [textures]
	_index[name] = parts.size()
	parts.append({
		"name": name, "textures": list, "pivot": pivot, "parent": _index.get(parent, -1), "at": at, "z": z,
		"rot": float(options.get("rot", 0.0)), "upright": bool(options.get("upright", false)),
		"drag": float(options.get("drag", 0.0)), "wobble": options.get("wobble", Vector2.ZERO),
		"blink": bool(options.get("blink", false)), "smear": bool(options.get("smear", false)),
		"phase": float(parts.size()) * 1.37,
	})


func add_pose(name: String, channels: Dictionary) -> void:
	for part: String in channels:
		assert(_index.has(part), "pose %s names an unknown part %s" % [name, part])
	poses[name] = channels


## `keys` is [[seconds, pose, ease], ...] from 0; the ease shapes the approach
## to that key. A looping move wraps; a one-shot holds its last key.
func add_move(name: String, keys: Array, loop := false) -> void:
	for key: Array in keys:
		assert(poses.has(key[1]) and EASES.has(key[2]), "move %s has a bad key %s" % [name, key])
	moves[name] = {"keys": keys, "loop": loop}


func duration(move: String) -> float:
	var keys: Array = moves[move].keys
	return float(keys[-1][0])


func has_part(name: String) -> bool:
	return _index.has(name)


## Every visible part as {"part", "texture", "pivot", "xform", "z", "flash"},
## back to front. `hit_age` is seconds since the character was last hit;
## `drift` is how fast the caller is carrying the whole rig (texels per second),
## so trailing parts and smears react to travel as well as to the keys.
func solve(move: String, t: float, clock: float, hit_age := INF, hidden: Array = [], drift := Vector2.ZERO) -> Array[Dictionary]:
	_drift = drift
	var world := _world(move, t, clock, hit_age)
	var smear_from: Array[Transform2D] = []
	if not reduced_motion:
		smear_from = _world(move, t - FRAME, clock - FRAME, hit_age + FRAME)
	var flash := 0.0
	if hit_age >= 0.0 and hit_age < FLASH_SECONDS:
		flash = 1.0 - hit_age / FLASH_SECONDS
	var out: Array[Dictionary] = []
	for i in parts.size():
		var part := parts[i]
		if hidden.has(part.name):
			continue
		var xform: Transform2D = world[i]
		var channels := _channels(move, t, i)
		var textures: Array = part.textures
		if part.smear and not smear_from.is_empty():
			# The middle of the part, not its pivot: a swung arm smears at the hand.
			var middle: Vector2 = (textures[0] as Texture2D).get_size() * 0.5 - part.pivot
			xform = _stretch(xform, (xform * middle - smear_from[i] * middle) / FRAME + drift)
		var texture: Texture2D = textures[clampi(int(channels.frame), 0, textures.size() - 1)]
		out.append({"part": part.name, "texture": texture, "pivot": part.pivot, "xform": xform, "z": part.z, "flash": flash, "order": part.z * 1000 + i})
	# Ties keep the order parts were added in, so layers never swap between frames.
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.order < b.order)
	return out


## Draw solved parts; `base` maps rig space (texels, root pivot at the origin)
## onto the canvas.
func draw(canvas: CanvasItem, solved: Array[Dictionary], base: Transform2D, tint := Color.WHITE) -> void:
	for item in solved:
		canvas.draw_set_transform_matrix(base * item.xform)
		canvas.draw_texture(item.texture, -item.pivot, tint)
		if item.flash > 0.0:
			canvas.draw_texture(_silhouette(item.texture), -item.pivot, Color(1, 1, 1, item.flash * 0.85))
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)


# --- Evaluation ---------------------------------------------------------------

## Drawn transforms. A child rides on its parent's drawn (squashed) shape, so a
## face squashes with the balloon, but turns in the parent's unsquashed frame,
## so a limb never shears into a long bar. Upright parts keep only their place.
func _world(move: String, t: float, clock: float, hit_age: float) -> Array[Transform2D]:
	var drawn: Array[Transform2D] = []
	var frames: Array[Transform2D] = []
	drawn.resize(parts.size())
	frames.resize(parts.size())
	for i in parts.size():
		var part := parts[i]
		var local := _local(move, t, clock, hit_age, i)
		var own: Transform2D = local[0]
		var frame := own
		if part.parent >= 0:
			var parent: Transform2D = frames[part.parent]
			var basis := Transform2D.IDENTITY if part.upright else Transform2D(parent.x, parent.y, Vector2.ZERO)
			frame = basis * Transform2D(own.x, own.y, Vector2.ZERO)
			frame.origin = drawn[part.parent] * own.origin
		frames[i] = frame
		drawn[i] = frame * Transform2D(0.0, local[1], 0.0, Vector2.ZERO)
	return drawn


## [rotation, scale and place without squash, squash as a scale].
func _local(move: String, t: float, clock: float, hit_age: float, i: int) -> Array:
	var part := parts[i]
	var channels := _channels(move, t, i)
	var rot: float = part.rot + channels.rot
	var at: Vector2 = part.at + channels.at
	var scale: Vector2 = channels.scale
	var squash: float = channels.squash
	var motion := 0.0 if reduced_motion else 1.0
	if part.parent < 0:
		var breathing := sin(TAU * clock / BREATH_PERIOD)
		squash += breath * breathing * motion
		rot += sway * sin(TAU * clock / SWAY_PERIOD) * motion
		at.y += bob * sin(TAU * clock / BREATH_PERIOD + 0.9) * motion
		if hit_age >= 0.0 and hit_age < FLINCH_SECONDS:
			var fade := exp(-6.0 * hit_age)
			squash += 0.22 * exp(-9.0 * hit_age) * motion
			rot += -11.0 * fade * cos(21.0 * hit_age) * motion
			at.x += -3.0 * fade * sin(21.0 * hit_age) * motion
	var wobble: Vector2 = part.wobble
	if wobble.x != 0.0:
		rot += wobble.x * sin(TAU * clock / maxf(0.1, wobble.y) + part.phase) * motion
	if part.drag > 0.0 and part.parent >= 0 and motion > 0.0:
		rot += clampf(_lag(move, t, clock, i, part.drag * DRAG_SECONDS), -DRAG_LIMIT, DRAG_LIMIT)
	if part.blink and _blinking(clock, part.phase):
		scale.y *= 0.18
	var stretch := Vector2(1.0 + squash, 1.0 / maxf(0.2, 1.0 + squash))
	return [Transform2D(deg_to_rad(rot), scale, 0.0, at), stretch]


## How far the part should trail behind its ancestors: their summed rotation
## and the root's sideways travel, sampled now and `lag` seconds ago.
func _lag(move: String, t: float, clock: float, i: int, lag: float) -> float:
	var now := _ancestry(move, t, clock, i)
	var then := _ancestry(move, t - lag, clock - lag, i)
	return (then.x - now.x) * 0.9 + (then.y - now.y - _drift.x * lag) * 1.6


func _ancestry(move: String, t: float, clock: float, i: int) -> Vector2:
	var turn := 0.0
	var travel := 0.0
	var parent: int = parts[i].parent
	while parent >= 0:
		var channels := _channels(move, t, parent)
		turn += float(channels.rot)
		if parts[parent].parent < 0:
			turn += sway * sin(TAU * clock / SWAY_PERIOD)
			travel = (channels.at as Vector2).x
		parent = parts[parent].parent
	return Vector2(turn, travel)


func _blinking(clock: float, phase: float) -> bool:
	if reduced_motion:
		return false
	# One blink in every 3.1 s window at a fixed, varied moment.
	var window := floorf(clock / 3.1)
	var when := window * 3.1 + 0.4 + 2.2 * fposmod(sin(window * 12.9898 + phase) * 43758.5453, 1.0)
	return clock >= when and clock < when + BLINK_SECONDS


func _channels(move: String, t: float, i: int) -> Dictionary:
	var name: String = parts[i].name
	var keys: Array = moves[move].keys
	var total := float(keys[-1][0])
	if moves[move].loop and total > 0.0:
		# A looping idle holds still with reduced motion; one-shot moves still play.
		t = 0.0 if reduced_motion else fposmod(t, total)
	t = clampf(t, 0.0, total)
	var next := 1
	while next < keys.size() - 1 and float(keys[next][0]) < t:
		next += 1
	var from: Dictionary = poses[keys[next - 1][1]].get(name, {}) if keys.size() > 1 else poses[keys[0][1]].get(name, {})
	var to: Dictionary = poses[keys[next][1]].get(name, {}) if keys.size() > 1 else from
	var span := float(keys[next][0]) - float(keys[next - 1][0]) if keys.size() > 1 else 0.0
	var u := 1.0 if span <= 0.0 else clampf((t - float(keys[next - 1][0])) / span, 0.0, 1.0)
	var e := _ease(keys[next][2] if keys.size() > 1 else "snap", u)
	return {
		"rot": lerpf(float(from.get("rot", 0.0)), float(to.get("rot", 0.0)), e),
		"at": (from.get("at", Vector2.ZERO) as Vector2).lerp(to.get("at", Vector2.ZERO), e),
		"scale": (from.get("scale", Vector2.ONE) as Vector2).lerp(to.get("scale", Vector2.ONE), e),
		"squash": lerpf(float(from.get("squash", 0.0)), float(to.get("squash", 0.0)), e),
		"frame": to.get("frame", 0) if u >= 0.5 else from.get("frame", 0),
	}


func _ease(kind: String, u: float) -> float:
	if reduced_motion and kind != "snap":
		return u
	match kind:
		"in":
			return u * u * u
		"out":
			return 1.0 - pow(1.0 - u, 3.0)
		"inout":
			return u * u * (3.0 - 2.0 * u)
		"back":
			# Ease out past the key by about 10 % and settle back.
			var c := 1.70158
			var v := u - 1.0
			return 1.0 + (c + 1.0) * v * v * v + c * v * v
		"snap":
			return 1.0 if u >= 1.0 else 0.0
	return u


## Stretch a part along its screen velocity, keeping its area.
func _stretch(xform: Transform2D, velocity: Vector2) -> Transform2D:
	var speed := velocity.length()
	if speed <= SMEAR_SPEED:
		return xform
	var amount := minf(SMEAR_MAX, (speed - SMEAR_SPEED) / SMEAR_SPEED * 0.12)
	var along := Transform2D(velocity.angle(), Vector2.ZERO)
	var squeeze := Transform2D(Vector2(1.0 + amount, 0.0), Vector2(0.0, 1.0 / (1.0 + amount)), Vector2.ZERO)
	var pivot := xform.origin
	return Transform2D(0.0, pivot) * along * squeeze * along.affine_inverse() * Transform2D(0.0, -pivot) * xform


func _silhouette(texture: Texture2D) -> Texture2D:
	var key := texture.get_instance_id()
	if not _silhouettes.has(key):
		var image := texture.get_image()
		for y in image.get_height():
			for x in image.get_width():
				if image.get_pixel(x, y).a > 0.0:
					image.set_pixel(x, y, Color("#fff6e0"))
		_silhouettes[key] = ImageTexture.create_from_image(image)
	return _silhouettes[key]


## A texel-sized canvas for one rig. Add it under the view; each frame call
## `show_pose()`, then draw `get_texture()` scaled by the view's texel size.
## Rotated parts are rasterised at texel size, so every pixel stays one size.
class Stage extends SubViewport:
	## The part rig (this script) being shown.
	var rig
	## Where the rig's root pivot sits on the stage, in texels.
	var origin := Vector2.ZERO
	var solved: Array[Dictionary] = []
	var tint := Color.WHITE
	var _painter: Painter

	func _init(texels: Vector2i, character: Object, root_at: Vector2) -> void:
		size = texels
		rig = character
		origin = root_at
		transparent_bg = true
		disable_3d = true
		render_target_update_mode = SubViewport.UPDATE_ALWAYS
		canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
		_painter = Painter.new()
		_painter.stage = self
		add_child(_painter)

	func show_pose(parts: Array[Dictionary], colour := Color.WHITE) -> void:
		solved = parts
		tint = colour
		_painter.queue_redraw()


class Painter extends Node2D:
	var stage: Stage

	func _draw() -> void:
		stage.rig.draw(self, stage.solved, Transform2D(0.0, stage.origin), stage.tint)
