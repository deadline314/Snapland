extends RefCounted
## The collage interface's happy moments, each under a second and skippable
## with any key (paper_motion shows):
## * `stick`: a new sticker peels off its photo, flies to the album and sticks
##   with a squash; then the count bumps. Several queue up a beat apart.
## * `celebrate`: the medal is stamped down and paper confetti bursts, more and
##   brighter for a better medal.
## * `flop`: no medal; the headline sags and the "play again" stamp swings.
## With reduced motion or without a display, nothing is added to the tree and
## every callback runs at once, so the final state shows immediately. Nothing
## here creates textures: stickers reuse the photo already on screen.

const Kit = preload("res://game/ui/collage_kit.gd")
const PaperMotion = preload("res://game/ui/paper_motion.gd")
const Props = preload("res://game/ui/pixel_props.gd")
const Pixels = preload("res://game/minigames/arcade/arcade_pixels.gd")

const STICK_SECONDS := 0.8
## Peel, flight and squash as fractions of STICK_SECONDS.
const PEEL_END := 0.22
const FLY_END := 0.78
const STICK_GAP := 0.18
## More stickers than this at once land together as one bump.
const STICK_QUEUE := 3
const CONFETTI_SECONDS := 0.85
const SLAM_SECONDS := 0.14
const DROOP_SECONDS := 0.7
## Confetti pieces by medal tier (none, bronze, silver, gold).
const PIECES: Array[int] = [0, 10, 18, 30]
## Gold also throws curling streamers.
const STREAMERS: Array[int] = [0, 0, 2, 5]
const CONFETTI_TONES: Array[Color] = [Color("#f08f73"), Color("#6fc7b7"), Color("#f6ecd0"), Color("#4f9fc4"), Color("#c26a8a")]
const GOLD := Color("#ffd166")


## Fly a sticker from `from` (a global rect: the photo it peels off) to
## `target`, then call `landed`. `layer` holds the sticker while it flies.
static func stick(layer: Control, photo: Texture2D, from: Rect2, target: Control, landed := Callable()) -> void:
	var flying := int(layer.get_meta(&"collage_stickers", 0)) if is_instance_valid(layer) else 0
	if not PaperMotion.enabled() or not is_instance_valid(target) or not target.is_inside_tree() or not layer.is_inside_tree() or flying >= STICK_QUEUE:
		_land(target, landed)
		return
	layer.set_meta(&"collage_stickers", flying + 1)
	var sticker := Sticker.new()
	sticker.name = "CollageSticker"
	sticker.photo = photo
	sticker.from = Rect2(from.position + Vector2(flying * 10.0, flying * 6.0), from.size)
	sticker.to = target.get_global_rect().get_center()
	sticker.salt = flying * 5 + 3
	layer.add_child(sticker)
	var tween := PaperMotion.show_tween(sticker, &"collage_flight")
	if flying > 0:
		tween.tween_interval(STICK_GAP * flying)
	tween.tween_property(sticker, "flight", 1.0, STICK_SECONDS).from(0.0)
	tween.tween_callback(func() -> void:
		if is_instance_valid(layer):
			layer.set_meta(&"collage_stickers", maxi(0, int(layer.get_meta(&"collage_stickers", 1)) - 1))
		_land(target, landed)
		sticker.queue_free())


static func _land(target: Control, landed: Callable) -> void:
	if is_instance_valid(target):
		PaperMotion.pop(target, 1.12)
	if landed.is_valid():
		landed.call()


## Stamp `medal` (an arcade_medal) down and throw confetti from it by `tier`.
static func celebrate(anchor: Control, tier: int, medal: Control = null) -> void:
	tier = clampi(tier, 0, 3)
	if not PaperMotion.enabled() or not is_instance_valid(anchor) or not anchor.is_inside_tree() or tier == 0:
		return
	var delay := 0.0
	if is_instance_valid(medal) and "slam" in medal:
		delay = SLAM_SECONDS
		var slam := PaperMotion.show_tween(medal, &"collage_slam")
		slam.tween_property(medal, "slam", 0.0, SLAM_SECONDS).from(1.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		slam.tween_callback(func() -> void:
			PaperMotion.swing(medal, &"thud", 1.0, 0.22)
			PaperMotion.ease_property(medal, &"ink", 0.0, 0.6, 0.0, Tween.TRANS_SINE, 1.0))
	var burst := Confetti.new()
	burst.name = "CollageConfetti"
	burst.tier = tier
	burst.position = anchor.get_global_transform().affine_inverse() * medal.get_global_rect().get_center() if is_instance_valid(medal) else anchor.size * 0.5
	anchor.add_child(burst)
	var tween := PaperMotion.show_tween(burst, &"collage_confetti")
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.tween_property(burst, "age", 1.0, CONFETTI_SECONDS).from(0.0)
	tween.tween_callback(burst.queue_free)


## A round without a medal: the headline sags off its tape and the "play
## again" stamp swings, a shrug rather than a jeer.
static func flop(headline: Control, again: Control, medal: Control = null) -> void:
	if not PaperMotion.enabled():
		return
	for sagging: Control in [headline, medal]:
		if is_instance_valid(sagging) and sagging.is_inside_tree():
			var key: StringName = &"wiggle" if sagging == headline else &"droop"
			var tween := PaperMotion.show_tween(sagging, StringName("collage_flop_" + key))
			tween.tween_interval(0.2)
			tween.tween_property(sagging, NodePath(key), 7.0 if sagging == headline else 24.0, DROOP_SECONDS).from(0.0).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	if is_instance_valid(again) and again.is_inside_tree():
		PaperMotion.swing(again, &"wiggle", 9.0, 0.9)


## Confetti `age` (0 burst .. 1 gone) for `tier`, around `origin` on `canvas`.
## Positions come from the age alone, so a view driven by its own clock can
## draw the same burst without any nodes.
static func draw_confetti(canvas: CanvasItem, origin: Vector2, age: float, tier: int, salt := 0) -> void:
	tier = clampi(tier, 0, 3)
	if age <= 0.0 or age >= 1.0 or tier == 0:
		return
	var seconds := age * CONFETTI_SECONDS
	var fade := 1.0 - smoothstep(0.7, 1.0, age)
	for index in PIECES[tier]:
		var angle := -PI * 0.5 + (Pixels.noise(index, 1, salt) - 0.5) * PI * 1.5
		var speed := (380.0 + Pixels.noise(index, 2, salt) * 420.0) * (1.0 + tier * 0.15)
		# Thrown out, slowed by the air, falling and fluttering side to side.
		var travel := speed * (1.0 - exp(-seconds * 3.2)) / 3.2
		var at := origin + Vector2.from_angle(angle) * travel + Vector2(sin(seconds * 9.0 + index) * 10.0, 360.0 * seconds * seconds)
		var spin := seconds * (5.0 + Pixels.noise(index, 3, salt) * 9.0) + index
		var piece := Vector2(7.0 + Pixels.noise(index, 4, salt) * 7.0, 4.0 + Pixels.noise(index, 5, salt) * 4.0)
		# A paper chip turning in the air shows its edge now and then.
		piece.x *= 0.3 + 0.7 * absf(cos(spin))
		var tone: Color = GOLD if tier == 3 and index % 3 == 0 else CONFETTI_TONES[index % CONFETTI_TONES.size()]
		var axis := Vector2.from_angle(spin * 0.4)
		var across := axis.orthogonal()
		canvas.draw_colored_polygon(PackedVector2Array([
			Props.snap(at - axis * piece.x - across * piece.y), Props.snap(at + axis * piece.x - across * piece.y),
			Props.snap(at + axis * piece.x + across * piece.y), Props.snap(at - axis * piece.x + across * piece.y)]), Color(tone, fade))
	for ribbon in STREAMERS[tier]:
		var heading := -PI * 0.5 + (ribbon - (STREAMERS[tier] - 1) * 0.5) * 0.55
		var points := PackedVector2Array()
		for step in 9:
			var along := step / 8.0 * 200.0 * (1.0 - exp(-seconds * 4.0))
			var curl := sin(step * 0.9 + seconds * 10.0 + ribbon) * 10.0 * step / 8.0
			points.append(origin + Vector2.from_angle(heading) * along + Vector2.from_angle(heading).orthogonal() * curl + Vector2(0.0, 120.0 * seconds * seconds))
		canvas.draw_polyline(points, Color(GOLD if ribbon % 2 == 0 else CONFETTI_TONES[0], fade), 4.0)


class Confetti extends Control:
	const Life = preload("res://game/ui/collage_life.gd")

	var tier := 1
	var age := 0.0:
		set(value):
			age = value
			queue_redraw()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		z_index = 5

	func _draw() -> void:
		Life.draw_confetti(self, Vector2.ZERO, age, tier, 11)


## The flying sticker: a cream-bordered print of the photo, drawn in global
## coordinates along its whole path (peel, arc, squash).
class Sticker extends Control:
	const Life = preload("res://game/ui/collage_life.gd")

	var photo: Texture2D
	var from := Rect2()
	var to := Vector2.ZERO
	var salt := 3
	var flight := 0.0:
		set(value):
			flight = value
			queue_redraw()

	func _init() -> void:
		top_level = true
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		z_index = 10

	func _draw() -> void:
		var peel := clampf(flight / Life.PEEL_END, 0.0, 1.0)
		var fly := smoothstep(Life.PEEL_END, Life.FLY_END, flight)
		var press := clampf((flight - Life.FLY_END) / (1.0 - Life.FLY_END), 0.0, 1.0)
		# Shrink the print to a stamp-sized sticker on the way.
		var full := from.size.limit_length(220.0)
		var small := full * (56.0 / maxf(full.x, 1.0))
		var body := full.lerp(small, fly)
		# A high arc: up and over, then down onto the album.
		var start := from.get_center() + Vector2(0.0, -10.0 * peel)
		var lift := start.lerp(to, 0.5) + Vector2(0.0, -140.0)
		var centre := start.lerp(lift, fly).lerp(lift.lerp(to, fly), fly)
		var angle := deg_to_rad(-5.0 * peel + 14.0 * sin(fly * PI) * (1.0 if salt % 2 == 1 else -1.0))
		var squash := sin(press * PI) * 0.28
		var grow := 1.0 + 0.06 * peel * (1.0 - fly)
		draw_set_transform(centre, angle, Vector2(grow * (1.0 + squash), grow * (1.0 - squash)))
		var face := Rect2(-body * 0.5, body)
		var frame := face.grow(maxf(3.0, body.x * 0.05))
		frame.size.y += maxf(4.0, body.x * 0.08)
		var height := 4.0 + 14.0 * peel * (1.0 - press)
		draw_rect(Rect2(frame.position + Vector2(height * 0.6, height), frame.size), Color(Kit.Paper.SHADOW, 0.4))
		draw_rect(frame.grow(2.0), Props.deepen(Kit.CREAM, 0.5))
		draw_rect(frame, Color("#fbf7ec"))
		if photo != null:
			draw_texture_rect(photo, face, false)
		else:
			draw_rect(face, Color("#9fd8d0"))
			draw_rect(Rect2(face.position.x, face.end.y - face.size.y * 0.3, face.size.x, face.size.y * 0.3), Color("#7cc46a"))
			Props.icon(self, "album", face.get_center(), Kit.INK_TEAL, maxf(2.0, roundf(body.x / 40.0)))
		# The corner that came away first curls back until the sticker is pressed down.
		var curl := minf(body.x, body.y) * 0.32 * (peel - fly * 0.7) * (1.0 - press)
		if curl > 2.0:
			var corner := Vector2(frame.end.x, frame.position.y)
			draw_colored_polygon(PackedVector2Array([corner + Vector2(-curl, 0), corner, corner + Vector2(0, curl)]), Color(Kit.Paper.SHADOW, 0.55))
			draw_colored_polygon(PackedVector2Array([corner + Vector2(-curl, 0), corner + Vector2(-curl, curl), corner + Vector2(0, curl)]), Props.deepen(Kit.CREAM, 0.15))
		draw_set_transform(Vector2.ZERO)
		if press > 0.0:
			Kit.tape(self, centre + Vector2(0.0, -body.y * 0.5 - 4.0), body.x * 0.7, deg_to_rad(-8.0), Color(0.98, 0.93, 0.78, 0.85 * press))
			Props.dust_puffs(self, centre + Vector2(0.0, body.y * 0.5 + 4.0), press * 0.5, body.x * 0.9, Color(0.94, 0.88, 0.74))
