extends "res://game/minigames/arcade/arcade_view.gd"
## Picture for 藤蔓編路: a bamboo trellis climbs the greenhouse wall and
## scrolls past as the vine grows. Each crossbar is a bamboo pole lashed with
## twine at its gap; breathing gaps are framed by leafy flaps that open and
## shut, every eighth bar is an iron skylight sash, and butterflies perch in
## the way. The vine trails leaves behind a curling tip. A crash whips the
## vine down onto the island traveller (arcade_hero) on the potting bench and
## ties them up in a big green bow. Every object is baked pixel art.

const Hero = preload("res://game/minigames/arcade/arcade_hero.gd")
const Greenhouse = preload("res://game/minigames/arcade/greenhouse_backdrop.gd")
const LEFT := 190.0
const RIGHT := 1010.0
const TIP_SCREEN := 470.0
const BAR_PX := 150.0
const BENCH_TOP := 640.0
const HERO_FEET := Vector2(1140, 690)
const HERO_SCALE := 3.0
const POLE_TEXELS := Vector2i(210, 5)
const BAMBOO := Color("#c9b26a")
const TWINE := Color("#d9c08a")
const VINE := Color("#4f8a3a")
const VINE_LIGHT := Color("#8ccf5a")
const LEAF := Color("#5f9e4f")
const IRON := Color("#38534e")
const WOOD := Color("#8a6640")
const WINGS: Array[Color] = [Color("#f2a7b8"), Color("#ffd166"), Color("#9fd8f0")]
const MORNING := Color(1.0, 0.98, 0.94)

var _pole: ImageTexture
var _sash: ImageTexture
var _leaf: ImageTexture
var _butterfly: Array[ImageTexture] = []
var _bloom: ImageTexture


func _init() -> void:
	super()
	word_anchor = Vector2(600, 250)


func _ready() -> void:
	_pole = Pixels.bake("vine-pole", POLE_TEXELS, _paint_pole)
	_sash = Pixels.bake("vine-sash", POLE_TEXELS, _paint_sash)
	_leaf = Pixels.bake("vine-leaf", Vector2i(7, 5), _paint_leaf)
	for frame in 2:
		_butterfly.append(Pixels.bake("vine-butterfly|%d" % frame, Vector2i(11, 8), _paint_butterfly.bind(frame)))
	_bloom = Pixels.bake("vine-bloom", Vector2i(11, 11), _paint_bloom)


func _draw_backdrop() -> void:
	Greenhouse.draw(self, now, reduced_motion)
	bench(BENCH_TOP, WOOD)
	vignette(0.35)


func _draw_scene() -> void:
	if not state.has("tip_y"):
		return
	_draw_frame()
	_draw_vine()
	_draw_bars()
	_draw_tip()
	_draw_hero()
	_draw_streak()


# --- Placement ----------------------------------------------------------------

func _sx(x: float) -> float:
	return lerpf(LEFT, RIGHT, x)


func _sy(height: float) -> float:
	return TIP_SCREEN - (height - float(state.get("tip_y", 0.0))) * BAR_PX


func _px(width: float) -> float:
	return width * (RIGHT - LEFT)


# --- The trellis ----------------------------------------------------------------

## The two upright bamboo posts at the trellis edges, their joints scrolling by.
func _draw_frame() -> void:
	var scroll := fposmod(float(state.get("tip_y", 0.0)) * BAR_PX, 60.0)
	for x: float in [LEFT - 14.0, RIGHT + 2.0]:
		draw_rect(Rect2(x + 6.0, 150, 12, 490), Color(Props.SHADOW, 0.25))
		panel(Rect2(x, 150, 12, 490), "pole", BAMBOO.darkened(0.08), Color(0, 0, 0, 0), TEXEL, MORNING)
		var y := 150.0 + scroll
		while y < 640.0:
			draw_rect(Rect2(x - 2.0, y, 16, 4), BAMBOO.darkened(0.35))
			draw_rect(Rect2(x - 2.0, y, 16, 1), BAMBOO.lightened(0.2))
			y += 60.0


func _draw_bars() -> void:
	for bar: Dictionary in state.get("bars", []):
		var y := _sy(float(bar.height))
		if y < 130.0 or y > BENCH_TOP - 16.0:
			continue
		var centre := _sx(float(bar.x))
		var half := _px(float(bar.width)) * 0.5
		var skylight := bool(bar.skylight)
		var sprite := _sash if skylight else _pole
		var full := Vector2(POLE_TEXELS) * TEXEL
		var left_len := maxf(0.0, centre - half - (LEFT - 14.0))
		var right_len := maxf(0.0, RIGHT + 14.0 - (centre + half))
		# Shadows on the wall behind, then the two lengths of pole either side of the gap.
		draw_rect(Rect2(LEFT - 14.0 + 8.0, y + 10.0, left_len, 12), Color(Props.SHADOW, 0.22))
		draw_rect(Rect2(centre + half + 8.0, y + 10.0, right_len, 12), Color(Props.SHADOW, 0.22))
		draw_texture_rect_region(sprite, Rect2(LEFT - 14.0, y - full.y * 0.5, left_len, full.y), Rect2(sprite.get_width() - left_len / TEXEL, 0, left_len / TEXEL, sprite.get_height()), MORNING)
		draw_texture_rect_region(sprite, Rect2(centre + half, y - full.y * 0.5, right_len, full.y), Rect2(0, 0, right_len / TEXEL, sprite.get_height()), MORNING)
		# Twine lashing (or an iron latch on a skylight) at each side of the gap.
		for side: float in [-1.0, 1.0]:
			var end := Vector2(centre + side * half, y)
			if skylight:
				draw_rect(Rect2(end.x - 6.0 - (8.0 if side > 0 else 0.0), y - 16.0, 14, 32), IRON.darkened(0.3))
				draw_rect(Rect2(end.x - 4.0 - (8.0 if side > 0 else 0.0), y - 14.0, 10, 28), IRON.lightened(0.15))
			else:
				for wrap in 3:
					draw_rect(Rect2(end.x - side * (6.0 + wrap * 5.0) - 2.0, y - 12.0, 4, 24), TWINE.darkened(0.25 if wrap % 2 == 0 else 0.05))
			if bool(bar.breathe):
				# Leafy flaps that open and shut with the gap.
				for flap in 2:
					var at := end + Vector2(-side * 10.0, -14.0 + flap * 18.0)
					draw_set_transform(at, side * (0.4 + flap * 0.5), Vector2(side * 2.0, 2.0))
					stamp(_leaf, Vector2(-14, -10), TEXEL * 0.5, MORNING)
					draw_set_transform(Vector2.ZERO)
		if skylight:
			# Sunlight pours in over the sash.
			draw_rect(Rect2(LEFT - 14.0, y - 46.0, RIGHT - LEFT + 28.0, 36), Color(1, 0.96, 0.72, 0.18 + 0.06 * pulse(0.8)))
			for ray in 6:
				var x := LEFT + 60.0 + ray * 140.0
				draw_colored_polygon(PackedVector2Array([Vector2(x, y - 10.0), Vector2(x + 22.0, y - 10.0), Vector2(x - 18.0, y + 70.0), Vector2(x - 44.0, y + 70.0)]), Color(1, 0.96, 0.72, 0.1))
			label(Vector2(centre, y - 34.0), "天窗", 20, Color("#fff2c4"))
		for butterfly: float in bar.butterflies:
			_draw_butterfly(Vector2(_sx(butterfly), _sy(float(bar.height) - 0.5)), butterfly)


func _draw_butterfly(at: Vector2, seed_x: float) -> void:
	var frame := 0 if reduced_motion else int(now * 6.0 + seed_x * 10.0) % 2
	var hover := 0.0 if reduced_motion else roundf(3.0 * sin(now * 2.0 + seed_x * 7.0))
	var sprite := _butterfly[frame]
	var size := Vector2(sprite.get_size()) * TEXEL * 1.5
	ground_shadow(at + Vector2(8, 34), Vector2(24, 5), 0.3)
	stamp(sprite, at - size * 0.5 + Vector2(0, hover), TEXEL * 1.5, MORNING)


# --- The vine -------------------------------------------------------------------

func _draw_vine() -> void:
	var path: Array = state.get("path", [])
	if path.is_empty():
		return
	var raw := PackedVector2Array()
	for point: Vector2 in path:
		raw.append(Vector2(_sx(point.x), _sy(point.y)))
	raw.append(Vector2(_sx(float(state.tip_x)), _sy(float(state.tip_y))))
	# The vine climbs out from behind the bench's front edge.
	var points := PackedVector2Array()
	for index in raw.size():
		if raw[index].y <= BENCH_TOP:
			if points.is_empty() and index > 0:
				var below := raw[index - 1]
				points.append(below.lerp(raw[index], (below.y - BENCH_TOP) / maxf(below.y - raw[index].y, 0.001)))
			points.append(raw[index])
	if points.size() < 2:
		return
	# Shadow, outline, stem and a lit stripe; leaves alternate along it.
	var shadow := PackedVector2Array()
	for point in points:
		shadow.append(point + Vector2(8, 10))
	draw_polyline(shadow, Color(Props.SHADOW, 0.25), 12.0)
	draw_polyline(points, VINE.darkened(0.45), 12.0)
	draw_polyline(points, VINE, 8.0)
	var lit := PackedVector2Array()
	for point in points:
		lit.append(point + Vector2(-2, -1))
	draw_polyline(lit, VINE_LIGHT, 2.0)
	for index in range(1, points.size() - 1, 3):
		var side := 1.0 if index % 2 == 0 else -1.0
		var along := (points[index + 1] - points[index - 1]).normalized()
		draw_set_transform(points[index] + along.orthogonal() * side * 10.0, along.angle() + side * 0.6, Vector2.ONE)
		stamp(_leaf, Vector2(-14, -10), TEXEL, MORNING)
		draw_set_transform(Vector2.ZERO)


func _draw_tip() -> void:
	var tip := Vector2(_sx(float(state.get("tip_x", 0.5))), TIP_SCREEN)
	var stalled := age(float(state.get("stalled_at", -99.0))) < float(state.get("stall_seconds", 0.6))
	# A curling tendril and a fat bud lead the way.
	var curl := 0.0 if reduced_motion else 0.3 * sin(now * 4.0)
	var lean := clampf(float(state.get("drift", 0.0)) * 0.9, -0.6, 0.6)
	var tendril := PackedVector2Array()
	for step in 8:
		var t := step / 7.0
		var angle := -PI * 0.5 + lean + (curl + 1.6) * t * t
		tendril.append(tip + Vector2.from_angle(angle) * (6.0 + 22.0 * t))
	draw_polyline(tendril, VINE.darkened(0.3), 4.0)
	draw_polyline(tendril, VINE_LIGHT, 2.0)
	draw_circle(tip + Vector2(1, 2), 10.0, VINE.darkened(0.45))
	draw_circle(tip, 9.0, VINE)
	draw_circle(tip + Vector2(-3, -3), 3.5, VINE_LIGHT)
	if stalled:
		label(tip + Vector2(0, -40), "…", 26, CREAM)
	var skylight: Dictionary = state.get("skylight", {})
	var since := age(float(skylight.get("at", -99.0))) if not skylight.is_empty() else 99.0
	if since >= 0.0 and since < float(state.get("skylight_seconds", 1.2)):
		# Sun pours through the skylight and a flower opens on the vine.
		var y := _sy(float(skylight.height))
		draw_rect(Rect2(LEFT, y - 120.0, RIGHT - LEFT, 240), Color(1, 0.96, 0.75, 0.25 * (1.0 - since / 1.2)))
		var grow := pop_in(since, 0.3)
		stamp(_bloom, Vector2(tip.x - 22.0 * grow, y - 22.0 * grow), TEXEL * grow, MORNING)


# --- The traveller --------------------------------------------------------------

func _draw_hero() -> void:
	var tangle: Dictionary = state.get("tangle", {})
	var since := age(float(tangle.get("at", -99.0))) if not tangle.is_empty() else 99.0
	var total := float(state.get("tangle_seconds", 1.8))
	var tied := since >= 0.35 and since < total + 1.0
	var mood := "sorry" if tied else ("shocked" if since >= 0.0 and since < 0.35 else "plain")
	var origin := HERO_FEET - Vector2(20, 46) * HERO_SCALE
	ground_shadow(HERO_FEET + Vector2(6, 2), Vector2(56, 13), 0.42)
	var stretch := squash(since - 0.35, 0.3, 0.3)
	draw_set_transform(HERO_FEET, 0.0, stretch)
	stamp(Hero.texture(&"idle", true, mood), origin - HERO_FEET, HERO_SCALE, MORNING)
	draw_set_transform(Vector2.ZERO)
	if since < 0.0 or since > total + 1.0:
		return
	var head := HERO_FEET + Vector2(0, -46.0 * HERO_SCALE)
	if since < 0.35:
		# The vine whips down from the bar it hit.
		var from := Vector2(_sx(float(tangle.x)), clampf(_sy(float(tangle.height)), 150.0, 600.0))
		var t := since / 0.35
		var whip := PackedVector2Array()
		for step in 12:
			var u := step / 11.0
			whip.append(from.lerp(head, u * t) + Vector2(0, -60.0 * sin(u * PI) * (1.0 - t)))
		draw_polyline(whip, VINE.darkened(0.45), 10.0)
		draw_polyline(whip, VINE, 6.0)
		return
	# Tied up: vine bands round the body and a big bow on top.
	var wrap := clampf((since - 0.35) / 0.25, 0.0, 1.0) if not reduced_motion else 1.0
	for band in 4:
		var y := HERO_FEET.y - 30.0 - band * 26.0
		var width := 64.0 * wrap
		draw_rect(Rect2(HERO_FEET.x - width * 0.5, y - 5.0, width, 10), VINE.darkened(0.45))
		draw_rect(Rect2(HERO_FEET.x - width * 0.5, y - 4.0, width, 6), VINE)
		draw_rect(Rect2(HERO_FEET.x - width * 0.5, y - 4.0, width, 2), VINE_LIGHT)
	var knot := head + Vector2(0, -8.0)
	for side: float in [-1.0, 1.0]:
		var loop := PackedVector2Array()
		for step in 13:
			var angle := step / 12.0 * TAU
			loop.append(knot + Vector2(side * (26.0 + 22.0 * cos(angle)), -14.0 * sin(angle)) * wrap)
		draw_colored_polygon(loop, VINE)
		draw_polyline(loop, VINE.darkened(0.45), 4.0)
		draw_line(knot, knot + Vector2(side * 18.0, 30.0) * wrap, VINE.darkened(0.2), 6.0)
	draw_circle(knot, 9.0 * wrap, VINE.darkened(0.3))
	draw_circle(knot + Vector2(-2, -2), 4.0 * wrap, VINE_LIGHT)
	stamp(_leaf, knot + Vector2(10, -32), TEXEL, MORNING)


func _draw_streak() -> void:
	var streak := int(state.get("streak", 0))
	if streak >= 3:
		label(Vector2(1140, 300), "連穿 × %d" % streak, 24, GOLD, 1.0 + 0.08 * pulse(2.0))
	# How many bars to the next skylight, as a little gauge of buds on the right post.
	var every := int(state.get("skylight_every", 8))
	var into := posmod(floori(float(state.get("tip_y", 0.0))), every)
	for bud in every:
		var at := Vector2(RIGHT + 8.0, 600.0 - bud * 26.0)
		var lit := bud < into
		draw_circle(at, 7.0, VINE.darkened(0.45))
		draw_circle(at, 5.0, Color("#ffd166") if lit else VINE.lightened(0.1))


# --- Texel painters ---------------------------------------------------------------

func _paint_pole(x: int, y: int) -> Color:
	# A bamboo pole: lit top, round body, a node ring every 24 texels.
	if x % 24 == 0:
		return BAMBOO.darkened(0.35)
	if x % 24 == 1:
		return BAMBOO.lightened(0.15)
	return Pixels.grainy(Pixels.rounded(BAMBOO, Vector2(0.0, (y - 2.0) / 2.5)), x, y, 0.05)


func _paint_sash(x: int, y: int) -> Color:
	# An iron skylight sash: rails with rivets and a strip of bright glass.
	if y == 0 or y == 4:
		return IRON.lightened(0.2) if y == 0 else IRON.darkened(0.3)
	if x % 20 < 2:
		return IRON
	if x % 20 == 10 and y == 2:
		return Color("#d9a64e")
	return Color("#d8ecef").lerp(Color("#fff6d8"), float(y) / 4.0)


func _paint_leaf(x: int, y: int) -> Color:
	var at := Vector2((x + 0.5) / 3.5 - 1.0, (y + 0.5) / 2.5 - 1.0)
	var half := 1.0 - absf(at.x) * 0.9
	if absf(at.y) > half:
		return Pixels.CLEAR
	if absf(at.y) < 0.2:
		return LEAF.lightened(0.25)
	return Pixels.lit(LEAF, -at.y * 0.6, x, y)


func _paint_butterfly(x: int, y: int, frame: int) -> Color:
	# A body down the middle and two wings, open on frame 0, half shut on frame 1.
	if x == 5 and y >= 1 and y <= 7:
		return Color("#3a2a2a")
	var wing := WINGS[0] if x < 5 else WINGS[1]
	var span := 5.0 if frame == 0 else 3.0
	var dx := absf(x - 5.0)
	if dx > span or dx < 1.0:
		return Pixels.CLEAR
	var upper := y >= 1 and y <= 4 and dx <= span
	var lower := y >= 4 and y <= 7 and dx <= span * 0.7
	if not (upper or lower):
		return Pixels.CLEAR
	if (dx == 2.0 and y == 2) or (dx == 3.0 and y == 6):
		return Color("#fff2dc")
	return Pixels.lit(wing, (4.0 - y) * 0.15, x, y)


func _paint_bloom(x: int, y: int) -> Color:
	var at := Vector2(x + 0.5 - 5.5, y + 0.5 - 5.5)
	if at.length() < 1.8:
		return Color("#ffd166")
	if at.length() < 5.2 and posmod(int(atan2(at.y, at.x) / TAU * 10.0 + 10.0), 2) == 0:
		return Pixels.lit(Color("#f2a7b8"), -at.y * 0.1, x, y)
	if at.length() < 4.0:
		return Color("#f2a7b8").darkened(0.1)
	return Pixels.CLEAR
