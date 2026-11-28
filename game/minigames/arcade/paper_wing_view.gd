extends "res://game/minigames/arcade/arcade_view.gd"
## Picture for 紙翼穿峽: the sky park backdrop (sky_backdrop) seen from just
## behind the hero's paper plane, flying through gates of lavender rock. Gates of
## rock rise out of the cloud floor in the haze and grow as they come; each has
## a gap with a swirling wind ring in it. The plane banks with the steering and
## its shadow slides over the clouds below. Gust streaks sweep across a moment
## before a side gust shoves the plane. A crash crumples plane and hero into a
## paper ball that tumbles away into the clouds. Rocks are textured in world
## space (strata, cracks, grass on top) and fade into the sky with distance.

const Hero = preload("res://game/minigames/arcade/arcade_hero.gd")
const SkyBackdrop = preload("res://game/minigames/arcade/sky_backdrop.gd")
## Where everything at the plane's height meets the haze, and the plane's own line.
const HORIZON := Vector2(640, 250)
const NEAR_Y := 560.0
## Perspective: scale = 1 / (1 + DEPTH * depth).
const DEPTH := 4.0
## Rock heights above (+) and below (-) the plane's height, in world pixels.
const ROCK_TOP := 110.0
const ROCK_FOOT := -520.0
const SPIRE := 300.0
## World pixels per rock texel.
const ROCK_TEXEL := 5.0
const LIMIT := 430.0
const ROCK := Color("#9a8a9e")
const ROCK_DARK := Color("#5e4e6e")
const MOSS := Color("#8fc46e")
const PAPER := Color("#fbf8ee")
const PAPER_SHADE := Color("#cfc6d8")
const WIND := Color("#e8fbff")
const CRASH_SECONDS := 1.8
const HERO_SCALE := 2.0

var _rock: ImageTexture


func _init() -> void:
	super()
	word_anchor = Vector2(640, 228)


func _ready() -> void:
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	# Built without the sprite outline so the rock tiles without seams.
	_rock = Pixels.cached("paper-wing-rock", func() -> Image:
		var image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
		for y in 64:
			for x in 64:
				image.set_pixel(x, y, _paint_rock(x, y))
		return image)


func _draw_backdrop() -> void:
	SkyBackdrop.draw(self, now, reduced_motion)


func _draw_scene() -> void:
	var gates: Array = state.get("gates", [])
	# Far gates first, so nearer rock covers them.
	for index in range(gates.size() - 1, -1, -1):
		var gate: Dictionary = gates[index]
		_draw_gate(float(gate.depth), float(gate.centre), float(gate.width), int(gate.serial))
	var x := float(state.get("plane_x", 0.0))
	var phase := str(state.get("phase", "fly"))
	_draw_gust()
	if phase == "crash":
		_draw_crash(x, age(float(state.get("phase_at", 0.0))))
	else:
		_draw_plane(x, float(state.get("bank", 0.0)), age(float(state.get("phase_at", 0.0))))
	# The gate just met keeps rushing past the camera for a moment.
	var last: Dictionary = state.get("last", {})
	if not last.is_empty() and not reduced_motion:
		var since := age(float(last.at))
		if since < 0.3:
			_draw_gate(-since / float(last.get("travel", 2.0)), float(last.centre), float(last.width), int(last.get("serial", 0)))
	if not last.is_empty() and bool(last.get("ring", false)) and age(float(last.at)) < 0.5:
		_draw_ring_burst(Vector2(HORIZON.x + x, NEAR_Y - 30.0), age(float(last.at)))
	var streak := int(state.get("streak", 0))
	if streak >= 2:
		label(Vector2(170, 200), "連穿 ×%d" % streak, 24, GOLD)


func _scale(depth: float) -> float:
	return 1.0 / (1.0 + DEPTH * depth)


## Screen point of world sideways `x` and height `h` (above the plane) at `depth`.
func _project(x: float, h: float, depth: float) -> Vector2:
	var s := _scale(depth)
	return Vector2(HORIZON.x + x * s, HORIZON.y + (NEAR_Y - HORIZON.y) * s - h * s)


## One gate: a rock spire on each side of the gap, reaching out past where the
## plane can fly, rising out of the cloud floor; a wind ring in the gap.
func _draw_gate(depth: float, centre: float, width: float, serial: int) -> void:
	var fog := clampf(depth, 0.0, 1.0) * 0.8
	var s := _scale(depth)
	for side: float in [-1.0, 1.0]:
		var edge := centre + side * width * 0.5
		var outer := side * (LIMIT + SPIRE)
		# World outline: shoulder at the outside, a craggy edge down the gap side.
		var world := PackedVector2Array([Vector2(outer, ROCK_TOP - 30.0), Vector2(lerpf(outer, edge, 0.55), ROCK_TOP + 26.0)])
		for step in 7:
			var h := lerpf(ROCK_TOP, ROCK_FOOT, step / 6.0)
			var jag := Pixels.noise(serial, step, 31 if side < 0.0 else 37) * 34.0
			world.append(Vector2(edge + side * jag, h))
		world.append(Vector2(outer, ROCK_FOOT))
		_rock_polygon(world, depth, fog)
		var screen := PackedVector2Array()
		for point in world:
			screen.append(_project(point.x, point.y, depth))
		# The face along the gap: lit on the left spire (the sun is up right), shaded on the right.
		var face := PackedVector2Array()
		for step in 5:
			face.append(screen[step + 2])
		for step in range(4, -1, -1):
			face.append(screen[step + 2] + Vector2(-side * 14.0 * s, 0.0))
		var lit := Color(1.0, 0.94, 0.8, 0.4) if side < 0.0 else Color(0.18, 0.1, 0.3, 0.35)
		draw_colored_polygon(face, Color(lit, lit.a * (1.0 - fog)))
		# Moss along the top, and the ink outline.
		var moss := MOSS.lerp(SkyBackdrop.SKY_MID, fog)
		draw_polyline(PackedVector2Array([screen[0], screen[1], screen[2]]), moss, maxf(2.0, 10.0 * s))
		draw_polyline(PackedVector2Array([screen[0], screen[1], screen[2]]), moss.lightened(0.25), maxf(1.0, 4.0 * s))
		# Inked down to where the clouds take over.
		draw_polyline(screen.slice(0, 6), Color(INK, 0.85 * (1.0 - fog)), maxf(1.0, 3.0 * s))
		# Cloud banks swallowing the foot of the spire.
		for wisp in 4:
			var x := lerpf(outer, edge, 0.08 + wisp * 0.3)
			var at := _project(x, ROCK_FOOT + 70.0 + (wisp % 2) * 30.0, depth)
			var texel := TEXEL * 3.0 * s
			var puff := SkyBackdrop.cloud_puff(Vector2i(30, 12), (serial + wisp) % 6)
			Props.stamp(self, puff, at - Vector2(15, 7) * texel, texel, Color(1, 1, 1, 1.0 - fog * 0.4))
	# A gate already met rushes past without its ring (it would sink below the plane).
	if depth >= 0.0:
		_draw_ring(_project(centre, 0.0, depth), width * 0.18 * s, depth)


## A spire filled with the rock texture fixed to the world, darker toward its
## cloudy foot and fading into the sky with distance.
func _rock_polygon(world: PackedVector2Array, depth: float, fog: float) -> void:
	var points := PackedVector2Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	var low := Color(0.6, 0.52, 0.72)
	for point in world:
		points.append(_project(point.x, point.y, depth))
		uvs.append(Vector2(point.x, -point.y) / (64.0 * ROCK_TEXEL))
		var down := clampf((ROCK_TOP - point.y) / (ROCK_TOP - ROCK_FOOT), 0.0, 1.0)
		# The foot dissolves into the cloud floor.
	draw_polygon(points, colors, uvs, _rock)


## The wind ring: swirling white arcs round the gap's heart.
func _draw_ring(at: Vector2, radius: float, depth: float) -> void:
	if radius < 2.0:
		return
	var fade := 1.0 - clampf(depth, 0.0, 1.0) * 0.55
	var spin := 0.0 if reduced_motion else now * 3.0
	var band := maxf(3.0, radius * 0.24)
	# A soft glow, an inked rim and a mint band, with bright gusts swirling round it.
	draw_circle(at, radius * 1.25, Color(WIND, 0.12 * fade))
	draw_arc(at, radius, 0.0, TAU, 48, Color(INK, 0.55 * fade), band + 4.0)
	draw_arc(at, radius, 0.0, TAU, 48, Color(MINT.lerp(WIND, 0.4), 0.9 * fade), band)
	draw_arc(at, radius - band * 0.25, 0.0, TAU, 48, Color(1, 1, 1, 0.6 * fade), maxf(1.0, band * 0.25))
	for arc in 4:
		var from := spin + arc * TAU / 4.0
		draw_arc(at, radius + band * 0.9, from, from + 0.9, 12, Color(1, 1, 1, 0.95 * fade), maxf(1.5, band * 0.45))

## The paper plane seen from behind, banking, with the hero sitting on it.
func _draw_plane(x: float, bank: float, since: float) -> void:
	var at := Vector2(HORIZON.x + x, NEAR_Y)
	var rise := 0.0 if reduced_motion else 160.0 * (1.0 - clampf(since / 0.4, 0.0, 1.0))
	at.y += rise
	if not reduced_motion:
		at.y += 4.0 * sin(now * 3.1)
	# Its shadow on the cloud floor far below.
	ground_shadow(Vector2(at.x, 690.0), Vector2(70.0, 9.0), 0.22)
	var tilt := bank * 0.35
	draw_set_transform(at, tilt, Vector2.ONE)
	var span := 150.0
	var wing_l := PackedVector2Array([Vector2(0, -6), Vector2(-span * 0.5, 10), Vector2(-span * 0.46, 18), Vector2(0, 12)])
	var wing_r := PackedVector2Array([Vector2(0, -6), Vector2(span * 0.5, 10), Vector2(span * 0.46, 18), Vector2(0, 12)])
	var keel := PackedVector2Array([Vector2(-8, 8), Vector2(8, 8), Vector2(0, 40)])
	for shape in [wing_l, wing_r, keel]:
		var outline := PackedVector2Array(shape)
		outline.append(shape[0])
		draw_polyline(outline, INK, 6.0)
	# The wing on the side it banks toward catches the light.
	draw_colored_polygon(wing_l, PAPER if bank <= 0.0 else PAPER.lerp(PAPER_SHADE, 0.5))
	draw_colored_polygon(wing_r, PAPER if bank >= 0.0 else PAPER.lerp(PAPER_SHADE, 0.5))
	draw_colored_polygon(keel, PAPER_SHADE)
	# Fold creases and a red stripe along each wing.
	for side: float in [-1.0, 1.0]:
		draw_line(Vector2(0, 4), Vector2(side * span * 0.47, 13), Color(PAPER_SHADE, 0.9), 2.0)
		draw_line(Vector2(side * span * 0.3, 7), Vector2(side * span * 0.42, 9), Color("#e8807a"), 3.0)
	draw_set_transform(Vector2.ZERO)
	# The hero sits astride the keel, seen from behind, leaning into the bank.
	draw_set_transform(at + Vector2(0, 2), tilt * 0.6, Vector2.ONE * HERO_SCALE)
	stamp(Hero.texture(&"up" if absf(bank) > 0.5 else &"idle", false), -Hero.FEET, 1.0)
	draw_set_transform(Vector2.ZERO)
	# Air streaming off the wing tips.
	if not reduced_motion:
		for side: float in [-1.0, 1.0]:
			var tip := at + Vector2(side * span * 0.5, 10.0).rotated(tilt)
			for trail in 3:
				var back := fmod(now * 2.5 + trail * 0.33, 1.0)
				draw_line(tip + Vector2(0, back * 40.0), tip + Vector2(0, back * 40.0 + 10.0), Color(1, 1, 1, 0.6 * (1.0 - back)), 2.0)


## A side gust: faint streaks while it gathers, strong ones while it blows.
func _draw_gust() -> void:
	var gust: Dictionary = state.get("gust", {})
	if gust.is_empty():
		return
	var side := float(gust.side)
	var blowing := now >= float(gust.start)
	var alpha := 0.75 if blowing else 0.35
	for streak in 9:
		var lane := 210.0 + streak * 52.0
		var run := 0.5 if reduced_motion else fmod(now * (1.6 if blowing else 0.8) + streak * 0.37, 1.0)
		var x := lerpf(-120.0, 1400.0, run) if side > 0.0 else lerpf(1400.0, -120.0, run)
		draw_line(Vector2(x, lane), Vector2(x - side * 90.0, lane), Color(WIND, alpha * sin(run * PI)), 4.0)
	var word := "側風 →" if side > 0.0 else "← 側風"
	label(Vector2(640.0 + side * 360.0, 300.0), word, 26 if blowing else 22, WIND if blowing else CREAM, 1.0 + (0.06 * pulse(5.0) if blowing else 0.0))


## Plane and hero crumple into a paper ball that tumbles down into the clouds.
func _draw_crash(x: float, since: float) -> void:
	var start := Vector2(HORIZON.x + x, NEAR_Y)
	var crumple := clampf(since / 0.25, 0.0, 1.0)
	var fall := 0.0 if reduced_motion else maxf(0.0, since - 0.35)
	var at := start + Vector2(fall * 60.0 * signf(-x if x != 0.0 else 1.0), fall * fall * 140.0)
	var radius := lerpf(70.0, 46.0, crumple)
	var spin := 0.0 if reduced_motion else fall * 7.0
	ground_shadow(Vector2(at.x, 690.0), Vector2(radius, 8.0), 0.22)
	# The hero, wrapped up to the chin: only the head and waving hands show over the ball.
	var wobble := 0.0 if reduced_motion else 0.25 * sin(since * 9.0)
	draw_set_transform(at, wobble, Vector2.ONE * 1.6)
	stamp(Hero.texture(&"up", true, "shocked"), -Hero.FEET, 1.0)
	draw_set_transform(Vector2.ZERO)
	# The ball: a lumpy crumpled sheet with crease lines, lit from the upper left.
	var lumps := PackedVector2Array()
	for corner in 14:
		var angle := spin + corner * TAU / 14.0
		var bump := 1.0 + 0.14 * (Pixels.noise(corner, 3, 41) - 0.5) * 2.0 * crumple
		lumps.append(at + Vector2.from_angle(angle) * radius * bump)
	var ring := PackedVector2Array(lumps)
	ring.append(lumps[0])
	draw_colored_polygon(lumps, PAPER_SHADE)
	draw_circle(at + Vector2(-radius * 0.15, -radius * 0.15), radius * 0.78, PAPER)
	draw_polyline(ring, INK, 5.0)
	for crease in 5:
		var angle := spin + crease * 1.37
		var a := at + Vector2.from_angle(angle) * radius * 0.2
		var b := at + Vector2.from_angle(angle + 0.5) * radius * 0.85
		draw_line(a, b, Color(PAPER_SHADE.darkened(0.2), 0.9), 2.0)
	draw_line(at + Vector2.from_angle(spin + 2.2) * radius * 0.4, at + Vector2.from_angle(spin + 2.6) * radius * 0.9, Color("#e8807a"), 3.0)
	if since > 0.2:
		label(at + Vector2(0, -radius - 64.0), "皺巴巴……", 24, CREAM)


func _draw_ring_burst(at: Vector2, since: float) -> void:
	var grow := since / 0.5
	for spark in 10:
		var dir := Vector2.from_angle(spark * TAU / 10.0)
		var a := at + dir * (30.0 + 90.0 * grow)
		draw_line(a, a + dir * 18.0, Color(GOLD, 1.0 - grow), 4.0)
	draw_arc(at, 40.0 + 80.0 * grow, 0.0, TAU, 32, Color(WIND, 0.8 * (1.0 - grow)), 4.0)


## Rock texels: soft strata, blocky cracks and specks, lit from the upper right.
static func _paint_rock(x: int, y: int) -> Color:
	# Chunky facets (8 x 6 texel blocks, rows offset like stacked stone), each lit
	# a little differently; dark seams between strata, a few cracks and specks.
	var row := y / 6
	var col := (x + (row % 2) * 4) / 8
	var facet := Pixels.noise(col % 8, row % 11, 51)
	var tone := ROCK.lerp(ROCK_DARK, 0.15 + 0.35 * facet)
	var in_x := (x + (row % 2) * 4) % 8
	var in_y := y % 6
	var light := 0.25 - 0.08 * in_y + (0.15 if in_x == 0 else 0.0)
	if in_y == 5:
		tone = ROCK_DARK.darkened(0.1)
		light = -0.1
	elif Pixels.noise(x / 3, y / 2, 52) > 0.9:
		tone = ROCK_DARK
	return Pixels.grainy(Pixels.lit(tone, light, x, y), x, y, 0.05, 54)
