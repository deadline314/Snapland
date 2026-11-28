extends "res://game/minigames/arcade/arcade_view.gd"
## Picture for 雲梯換層: the sky park backdrop (sky_backdrop) with a course of
## bobbing cloud pads running off to an exit arch. A dashed line joins the pad
## underfoot to the next one and turns gold with 「跳！」 when they are level.
## Shrinking pads blush pink and dwindle under the hero; gusty pads trail wind
## streaks. A miss drops the hero into the cloud deck, from which their head
## pops up coated in cotton candy. Clouds are the backdrop's shared lit puffs;
## the hero is arcade_hero.gd.

const Hero = preload("res://game/minigames/arcade/arcade_hero.gd")
const SkyBackdrop = preload("res://game/minigames/arcade/sky_backdrop.gd")
const SPACING := 236.0
const FIRST_X := 300.0
const PAD_TEXELS := Vector2i(44, 22)
const HERO_SCALE := 3.0
const HOP_SECONDS := 0.32
const DECK_Y := 568.0
const LAMP := Color(1, 1, 1)
const CANDY := Color("#f6a8c8")

var _pad: ImageTexture
var _gate: ImageTexture


func _init() -> void:
	super()
	word_anchor = Vector2(640, 230)


func _ready() -> void:
	_pad = SkyBackdrop.cloud_puff(PAD_TEXELS, 3)
	_gate = SkyBackdrop.cloud_puff(Vector2i(20, 14), 7)


func _draw_backdrop() -> void:
	SkyBackdrop.draw(self, now, reduced_motion)


func _draw_scene() -> void:
	var phase := str(state.get("phase", "stand"))
	var since := age(float(state.get("phase_at", 0.0)))
	var heights: Array = state.get("heights", [])
	var sizes: Array = state.get("sizes", [])
	var kinds: Array = state.get("kinds", [])
	var count := int(state.get("count", 0))
	var pad := int(state.get("pad", 0))
	var from := int(state.get("hop_from", 0))
	var cam := float(pad)
	if phase == "hop" and not reduced_motion:
		cam = lerpf(float(from), float(pad), clampf(since / HOP_SECONDS, 0.0, 1.0))
	for index in count + 1:
		var x := FIRST_X + (index - cam) * SPACING
		if x < -200.0 or x > DESIGN.x + 200.0:
			continue
		if index == count:
			_draw_gate(x)
			continue
		_draw_pad(x, float(heights[index]), float(sizes[index]), str(kinds[index]), index)
	if phase == "stand" and pad < count:
		_draw_level_line(cam, pad, heights)
	match phase:
		"fall":
			_draw_fall(FIRST_X + (pad - cam) * SPACING, float(heights[pad]) if pad < heights.size() else 440.0, since)
		"hop":
			var t := 1.0 if reduced_motion else clampf(since / HOP_SECONDS, 0.0, 1.0)
			var start := Vector2(FIRST_X + (from - cam) * SPACING, _top(from, heights))
			var end := Vector2(FIRST_X + (pad - cam) * SPACING, _top(pad, heights))
			var at := start.lerp(end, t) - Vector2(0, 90.0 * sin(t * PI))
			_draw_hero(at, &"up", "tongue")
		_:
			var mood := "shocked" if pad < sizes.size() and float(sizes[pad]) < 0.5 else "plain"
			_draw_hero(Vector2(FIRST_X + (pad - cam) * SPACING, _top(pad, heights)), &"idle", mood)
	var streak := int(state.get("streak", 0))
	if streak >= 2:
		label(Vector2(180, 200), "連跳 ×%d" % streak, 24, GOLD)


func _top(index: int, heights: Array) -> float:
	return float(heights[index]) if index < heights.size() else 440.0


func _draw_pad(x: float, top: float, size: float, kind: String, index: int) -> void:
	if size <= 0.02:
		return
	var width := PAD_TEXELS.x * TEXEL * size
	# Its shadow on the cloud deck far below.
	ground_shadow(Vector2(x, DECK_Y + 10.0), Vector2(width * 0.4, 8), 0.18)
	var tint := Color(1, 0.86, 0.92) if kind == "shrink" else LAMP
	var tilt := 0.0
	if kind == "windy" and not reduced_motion:
		tilt = 0.08 * sin(now * 5.0 + index)
	draw_set_transform(Vector2(x, top + 34.0), tilt, Vector2.ONE * TEXEL * size)
	stamp(_pad, -Vector2(PAD_TEXELS.x * 0.5, PAD_TEXELS.y * 0.5), 1.0, tint)
	draw_set_transform(Vector2.ZERO)
	if kind == "windy":
		for streak in 3:
			var drift := 0.0 if reduced_motion else fmod(now * 2.0 + streak * 0.33, 1.0)
			var at := Vector2(x - 120.0 + drift * 240.0, top - 10.0 + streak * 18.0)
			draw_rect(Rect2(at, Vector2(36, 4)), Color(1, 1, 1, 0.5 * (1.0 - absf(drift - 0.5) * 1.6)))
	elif kind == "shrink":
		label(Vector2(x, top + 66.0), "會消失", 16, Color("#a8487a"), 1.0, 0.9, false)


## The exit: a cloud arch with a flag-hung banner.
func _draw_gate(x: float) -> void:
	for side: float in [-1.0, 1.0]:
		draw_set_transform(Vector2(x + side * 70.0, 440.0), 0.0, Vector2.ONE * TEXEL)
		stamp(_gate, Vector2(-10, -4), 1.0, LAMP)
		draw_set_transform(Vector2.ZERO)
		draw_rect(Rect2(x + side * 70.0 - 6.0, 300, 12, 150), Color("#c9953e").darkened(0.3))
		draw_rect(Rect2(x + side * 70.0 - 4.0, 300, 6, 150), Color("#e9b85c"))
	var banner := Rect2(x - 90.0, 288, 180, 44)
	draw_rect(Rect2(banner.position + Vector2(4, 6), banner.size), Color(0.1, 0.1, 0.2, 0.3))
	panel(banner, "velvet", Color("#c0485e"), GOLD)
	label(banner.get_center(), "出口", 24, CREAM)
	for flag in 5:
		var at := Vector2(x - 80.0 + flag * 40.0, 276.0)
		draw_colored_polygon(PackedVector2Array([at, at + Vector2(16, 0), at + Vector2(8, 14)]), [Color("#e8807a"), Color("#f2c46a"), Color("#7ac0b8"), Color("#a88ad8")][flag % 4])


## A dashed line from the pad underfoot to the next; gold and 「跳！」 when level.
func _draw_level_line(cam: float, pad: int, heights: Array) -> void:
	var from := Vector2(FIRST_X + (pad - cam) * SPACING + 70.0, _top(pad, heights))
	var to := Vector2(FIRST_X + (pad + 1 - cam) * SPACING - 70.0, _top(pad + 1, heights))
	var gap := float(state.get("gap", 99.0))
	var level := float(state.get("level", 10.0))
	var ready := gap <= level
	var color := GOLD if ready else Color(1, 1, 1, 0.55)
	var steps := 10
	for step in steps:
		if step % 2 == 1:
			continue
		var a := from.lerp(to, float(step) / steps)
		var b := from.lerp(to, float(step + 1) / steps)
		draw_line(a, b, INK, 7.0)
		draw_line(a, b, color, 4.0)
	if ready:
		label((from + to) * 0.5 + Vector2(0, -34), "跳！", 30, GOLD, 0.9 + 0.1 * pulse(6.0))


func _draw_hero(feet: Vector2, pose: StringName, mood: String) -> void:
	draw_set_transform(feet, 0.0, Vector2.ONE * HERO_SCALE)
	stamp(Hero.texture(pose, true, mood), -Hero.FEET, 1.0, LAMP)
	draw_set_transform(Vector2.ZERO)


## Down into the cloud deck, then the head pops up coated in cotton candy.
func _draw_fall(x: float, top: float, since: float) -> void:
	if since < 0.5 and not reduced_motion:
		var drop := since / 0.5
		_draw_hero(Vector2(x, lerpf(top, DECK_Y + 200.0, drop * drop)), &"up", "shocked")
		return
	var rise := 1.0 if reduced_motion else clampf((since - 0.5) / 0.25, 0.0, 1.0)
	var feet := Vector2(x, DECK_Y + 150.0 - 100.0 * rise)
	_draw_hero(feet, &"idle", "sorry")
	# The cloud deck closes over the body, leaving the head poking out.
	draw_set_transform(Vector2(x, DECK_Y + 30.0), 0.0, Vector2.ONE * TEXEL * 1.2)
	stamp(_pad, -Vector2(PAD_TEXELS.x * 0.5, PAD_TEXELS.y * 0.35), 1.0, LAMP)
	draw_set_transform(Vector2.ZERO)
	# Pink cotton candy stuck all over the head.
	var head := feet + Vector2(0, -38.0 * HERO_SCALE)
	for blob in 9:
		var at := head + Vector2(cos(blob * 1.9) * 30.0, sin(blob * 2.3) * 16.0 - 10.0)
		var radius := 10.0 + (blob % 3) * 3.0
		draw_circle(at, radius + 2.0, Color(CANDY.darkened(0.3), 0.9))
		draw_circle(at, radius, CANDY)
		draw_circle(at + Vector2(-3, -3), radius * 0.4, CANDY.lightened(0.35))
	if since > 0.7:
		label(head + Vector2(0, -60), "噗！", 26, CREAM)
