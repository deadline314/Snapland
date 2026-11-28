extends "res://game/minigames/arcade/arcade_view.gd"
## Picture for 繩橋共振: seen from just behind the island traveller, a plank rope
## bridge runs away over the sea of clouds to a far floating isle, hung from two
## hand ropes on posts with lanterns at every stretch. The whole bridge rolls
## from side to side about its ropes, more wildly as it wobbles; footprints on
## the next plank light up on the side to step and a ring closes on them on the
## beat, and a broken plank shows a big ↑ to stride over. When it rolls right
## over, the traveller is left hanging upside down underneath. Drawn in the sky
## park palette over the shared sky backdrop (sky_backdrop.gd).

const Hero = preload("res://game/minigames/arcade/arcade_hero.gd")
const SkyBackdrop = preload("res://game/minigames/arcade/sky_backdrop.gd")
const CX := 640.0
const HORIZON := 300.0
const FEET_Y := 640.0
const DEPTH := 3.5
const HALF := 150.0
const RAIL := 118.0
const AHEAD := 18
const HERO_SCALE := 3.0
const WOOD := Color("#a87a4f")
const DARK_WOOD := Color("#6e4c32")
const ROPE := Color("#d9c08a")
const NAVY := Color("#2f4a7a")
const CORAL := Color("#ff8a6b")
const MINT_ISLE := Color("#8fe0c4")
const ROCK := Color("#8c7563")
const ROCK_DARK := Color("#5f4f47")
const SUN := Color("#ffd35c")
const WHITE := Color("#fbfdff")
const NOON := Color(1.0, 0.99, 0.96)

var _isle: ImageTexture


func _init() -> void:
	super()
	word_anchor = Vector2(640, 214)


func _ready() -> void:
	_isle = Pixels.bake("bridge-isle", Vector2i(44, 26), _paint_isle)


# --- Geometry -------------------------------------------------------------------

## How big things are `d` planks ahead of the traveller (1 at their feet).
func _scale(d: float) -> float:
	return DEPTH / maxf(0.35, d + DEPTH)


## The point the bridge hangs from (between the two hand ropes) `d` planks ahead.
func _pivot(d: float) -> Vector2:
	var s := _scale(d)
	return Vector2(CX, HORIZON + (FEET_Y - HORIZON) * s - RAIL * s)


## The roll `d` planks ahead: the far end, tied to its isle, rolls less.
func _roll(d: float) -> float:
	return float(state.get("roll", 0.0)) * clampf(1.0 - d / 22.0, 0.35, 1.0)


## A point across the bridge `d` planks ahead: `across` -1..1 from the left edge
## to the right, `down` 0 at the hand ropes and 1 on the deck.
func _at(d: float, across: float, down: float) -> Vector2:
	var s := _scale(d)
	return _pivot(d) + Vector2(across * HALF * s, down * RAIL * s).rotated(_roll(d))


## Planks walked so far, easing through the step in progress.
func _walk() -> float:
	var pos := float(state.get("pos", 0))
	var t := clampf(age(float(state.get("step_at", -99.0))) / float(state.get("step_seconds", 0.2)), 0.0, 1.0)
	return pos - float(state.get("stride", 1)) * (1.0 - smoothstep(0.0, 1.0, t))


# --- Backdrop ------------------------------------------------------------------

func _draw_backdrop() -> void:
	SkyBackdrop.draw(self, now, reduced_motion)
	# Floating isles drift either side, and the far isle the bridge is tied to.
	for index in 3:
		var bob := 0.0 if reduced_motion else sin(now * 0.7 + index * 2.1) * 6.0
		var spot: Vector2 = [Vector2(150, 360), Vector2(1080, 420), Vector2(CX - 44, HORIZON - 40)][index]
		var size: float = [5.0, 4.0, 2.0][index]
		stamp(_isle, spot + Vector2(0, bob), size, NOON)
	vignette(0.28)


# --- Play ----------------------------------------------------------------------

func _draw_scene() -> void:
	if not state.has("pos"):
		return
	var walk := _walk()
	var pos := int(state.pos)
	var gaps: Dictionary = state.get("gaps", {})
	var stretch := int(state.get("stretch", 8))
	var wild := clampf(float(state.get("wobble", 0.0)), 0.0, 1.0)
	var rope := ROPE.lerp(CORAL, smoothstep(0.55, 1.0, wild))
	# Far to near: posts, planks and the suspenders under the hand ropes.
	var first := pos - 2
	var last := pos + AHEAD
	_draw_ropes(walk, first, last, rope, 1.0)
	for plank in range(last, first - 1, -1):
		var d := plank - walk
		if d < -1.4:
			continue
		if plank % stretch == 0:
			_draw_post(d, plank)
		if gaps.has(plank):
			_draw_gap(d)
		else:
			_draw_plank(d, plank)
		_draw_suspenders(d, rope)
	_draw_ropes(walk, first, last, rope, 0.0)
	_draw_cue(walk)
	_draw_hero()
	if str(state.get("next_button", "")) == "up" and str(state.get("stage", "")) == "play" and _hanging() < 0.0:
		# The broken plank is right behind the traveller, so the call goes over their head.
		label(_at(0.0, 0.0, 1.0) + Vector2(0, -170), "↑ 跨！", 34, SUN, 1.0 + 0.08 * pulse(4.0))
	_draw_grade(walk)
	_draw_streak()
	if wild > 0.6 and _hanging() < 0.0:
		label(_at(2.0, 1.25, 0.0) + Vector2(0, -20), "嘎吱…", 20, CORAL, 1.0 + 0.1 * pulse(5.0))


func _draw_ropes(walk: float, first: int, last: int, tone: Color, down: float) -> void:
	# The two hand ropes (down 0) or the deck-edge ropes (down 1), sagging a little between posts.
	for across: float in [-1.0, 1.0]:
		var line := PackedVector2Array()
		for step in range((last - first) * 2 + 1):
			var d := first - walk + (last - first) - step * 0.5
			if d < -1.4:
				continue
			var sag := 0.0 if down > 0.5 else 0.12 * absf(sin(PI * fposmod(d + walk, 8.0) / 8.0))
			line.append(_at(d, across, down + sag))
		if line.size() > 1:
			draw_polyline(line, DARK_WOOD.darkened(0.3), 6.0 if down < 0.5 else 4.0)
			draw_polyline(line, tone, 3.0 if down < 0.5 else 2.0)


func _draw_suspenders(d: float, tone: Color) -> void:
	for across: float in [-1.0, 1.0]:
		draw_line(_at(d, across, 0.08), _at(d, across, 1.0), Color(tone.darkened(0.25), 0.9), maxf(1.0, 2.0 * _scale(d)))


func _draw_plank(d: float, plank: int) -> void:
	var near := d - 0.42
	var far := d + 0.42
	var shade := 0.12 * Pixels.noise(plank, 1, 7)
	var top := WOOD.darkened(shade)
	var face := PackedVector2Array([_at(far, -1.0, 1.0), _at(far, 1.0, 1.0), _at(near, 1.0, 1.0), _at(near, -1.0, 1.0)])
	var edge := PackedVector2Array([_at(near, -1.0, 1.0), _at(near, 1.0, 1.0), _at(near, 1.0, 1.12), _at(near, -1.0, 1.12)])
	_fill(edge, DARK_WOOD.darkened(0.2))
	_fill(face, top)
	# A lit front lip, grain lines and two nail heads.
	draw_line(_at(near, -0.96, 1.0), _at(near, 0.96, 1.0), top.lightened(0.22), maxf(1.0, 3.0 * _scale(d)))
	for grain in 2:
		var along := -0.15 + grain * 0.3
		draw_line(_at(d + along * 0.6, -0.9, 1.0), _at(d + along * 0.6, 0.9, 1.0), Color(DARK_WOOD, 0.35), maxf(1.0, 1.5 * _scale(d)))
	for side: float in [-0.82, 0.82]:
		draw_circle(_at(d, side, 1.0), maxf(1.0, 2.5 * _scale(d)), DARK_WOOD.darkened(0.3))


## A broken plank: two splintered stubs and the clouds far below through the hole.
func _draw_gap(d: float) -> void:
	for side: float in [-1.0, 1.0]:
		var inner := side * 0.62
		var stub := PackedVector2Array([_at(d + 0.42, side, 1.0), _at(d + 0.42, inner, 1.0), _at(d - 0.1, inner * 0.8, 1.0), _at(d - 0.42, inner, 1.0), _at(d - 0.42, side, 1.0)])
		_fill(stub, WOOD.darkened(0.25))


func _draw_post(d: float, plank: int) -> void:
	# A post either side at the start of each stretch, with a lantern on top.
	var s := _scale(d)
	for across: float in [-1.08, 1.08]:
		var foot := _at(d, across, 1.08)
		var head := _at(d, across, -0.3)
		draw_line(foot, head, DARK_WOOD.darkened(0.35), maxf(3.0, 14.0 * s))
		draw_line(foot, head, WOOD, maxf(2.0, 9.0 * s))
		var glow := SUN if plank > 0 else MINT_ISLE
		draw_circle(head, maxf(2.0, 11.0 * s), DARK_WOOD.darkened(0.3))
		draw_circle(head, maxf(1.5, 8.0 * s), glow)
		draw_circle(head + Vector2(-2, -2) * s, maxf(1.0, 3.0 * s), WHITE)


func _hanging() -> float:
	var since := age(float(state.get("flip_at", -99.0)))
	return since if since >= 0.0 and since < float(state.get("hang_seconds", 1.8)) else -1.0


## Footprints on the next plank: the one to step on lights up and a ring closes
## on it in time with the swing; over a broken plank, a big ↑ instead.
func _draw_cue(walk: float) -> void:
	if str(state.get("stage", "")) != "play" or _hanging() >= 0.0:
		return
	var d := float(int(state.pos) + 1) - walk
	var s := _scale(d)
	var beat := maxf(0.05, float(state.get("beat_seconds", 0.6)))
	var closing := clampf(float(state.get("next_in", 0.0)) / beat, 0.0, 1.0)
	if str(state.get("next_button", "")) == "up":
		var centre := _at(d + 0.2, 0.0, 1.0)
		draw_arc(centre, (26.0 + 80.0 * closing) * s, 0.0, TAU, 28, Color(SUN, 0.95), 5.0)
		return
	var lit := int(state.get("next_side", 1))
	for side: int in [-1, 1]:
		var spot := _at(d, side * 0.42, 1.0)
		var on := side == lit
		var tone := SUN if on else Color(WHITE, 0.35)
		_footprint(spot, s, tone, side, _roll(d))
		if on:
			draw_arc(spot, (22.0 + 70.0 * closing) * s, 0.0, TAU, 24, Color(SUN, 0.5 + 0.5 * (1.0 - closing)), 4.0)
			label(spot + Vector2(0, -46 * s), "←" if side < 0 else "→", int(34 * s), SUN)


func _footprint(at: Vector2, s: float, tone: Color, side: int, angle: float) -> void:
	draw_set_transform(at, angle, Vector2(s, s * 0.55))
	draw_circle(Vector2(0, 6), 13.0, Color(DARK_WOOD, 0.4))
	draw_circle(Vector2.ZERO, 13.0, tone)
	for toe in 4:
		draw_circle(Vector2(-9 + toe * 6.0 + side * 1.0, -19 + absf(toe - 1.5) * 2.0), 3.6, tone)
	draw_set_transform(Vector2.ZERO)


func _draw_hero() -> void:
	var hanging := _hanging()
	var wild := clampf(float(state.get("wobble", 0.0)), 0.0, 1.0)
	var roll := _roll(0.0)
	var feet := _at(0.0, 0.0, 1.0)
	var hop := 0.0
	var step := age(float(state.get("step_at", -99.0))) / float(state.get("step_seconds", 0.2))
	if step < 1.0 and not reduced_motion:
		hop = -14.0 * sin(clampf(step, 0.0, 1.0) * PI)
	var pose := &"idle"
	if hanging >= 0.0:
		pose = &"up"
	elif wild > 0.35:
		# Throwing an arm out to balance on the low side.
		pose = &"right" if roll > 0.0 else &"left"
	var mood := "shocked" if hanging >= 0.0 or wild > 0.75 else "plain"
	if hanging < 0.0:
		ground_shadow(feet + Vector2(0, 4), Vector2(46, 10), 0.35)
	draw_set_transform(feet + Vector2(0, hop).rotated(roll), roll, Vector2.ONE)
	stamp(Hero.texture(pose, false, mood), -Vector2(20, 46) * HERO_SCALE, HERO_SCALE, NOON)
	draw_set_transform(Vector2.ZERO)
	if hanging >= 0.4 and not reduced_motion:
		# Little stars spinning round the upside-down head.
		var head := feet + Vector2(0, 150).rotated(roll - PI if roll > 0.0 else roll + PI)
		for star in 3:
			var angle := star * TAU / 3.0 + hanging * 6.0
			var spot := head + Vector2(cos(angle) * 38.0, sin(angle) * 10.0 + 20.0)
			draw_rect(Rect2(spot - Vector2(6, 2), Vector2(12, 4)), SUN)
			draw_rect(Rect2(spot - Vector2(2, 6), Vector2(4, 12)), SUN)


func _draw_grade(walk: float) -> void:
	var since := age(float(state.get("grade_at", -99.0)))
	if since > 0.5 or str(state.get("grade", "")) == "":
		return
	var perfect := str(state.grade) == "perfect"
	var spot := _at(0.0, 0.0, 1.0) + Vector2(110, -150 - since * 60.0)
	label(spot, "穩！" if perfect else "好", 28 if perfect else 22, SUN if perfect else WHITE, 1.0, 1.0 - since / 0.5)


func _draw_streak() -> void:
	var streak := int(state.get("streak", 0))
	if streak >= 4:
		label(Vector2(1110, 230), "連踩 × %d" % streak, 26, SUN, 1.0 + 0.08 * pulse(2.0))


# --- Texel painters -------------------------------------------------------------

func _paint_isle(x: int, y: int) -> Color:
	# A floating isle: a grassy top with a tuft of flowers and a rocky root below.
	var at := Vector2(x + 0.5, y + 0.5)
	var top := (at - Vector2(22, 7)) / Vector2(21, 5)
	if top.length() <= 1.0:
		if y <= 4 and Pixels.noise(x, y, 3) > 0.86:
			return CORAL
		return Pixels.lit(MINT_ISLE.darkened(0.15), 0.6 - top.y, x, y)
	var depth := (y - 9.0) / 16.0
	var width := 19.0 * (1.0 - depth * depth) - 2.0 * Pixels.noise(y, 0, 5)
	if y >= 9 and absf(at.x - 22.0) <= width and depth <= 1.0:
		return Pixels.lit(ROCK if (x + y) % 5 != 0 else ROCK_DARK, 0.3 - depth - (at.x - 22.0) / 30.0, x, y)
	return Pixels.CLEAR


## A filled shape drawn as a fan of triangles: a plank twisting through a flip
## turns into a bow-tie no polygon fill can take, and an edge-on one has no area.
func _fill(shape: PackedVector2Array, tone: Color) -> void:
	for index in range(1, shape.size() - 1):
		var tri := PackedVector2Array([shape[0], shape[index], shape[index + 1]])
		if absf((tri[1] - tri[0]).cross(tri[2] - tri[0])) > 1.0:
			draw_colored_polygon(tri, tone)
