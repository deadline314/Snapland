extends RefCounted
## The shared backdrop of the 雲端遊樂場 (sky park) arcade games: an open sky at
## 320 x 180 texels (one screen at 4 px a texel). A pastel sky deepening upward
## with a soft sun, banks of far cumulus lit from the upper left, the park's
## ferris wheel standing hazy in the distance on its A-frame, two little floating
## isles with grass and a tree, and a fluffy cloud deck along the bottom. `draw()`
## lays it down with the wheel's gondolas slowly turning, small clouds drifting
## across and a pair of birds; reduced motion stills them all. A game draws its
## own play objects on top; `cloud_puff()` is a lit cloud sprite games can reuse.

const Pixels = preload("res://game/minigames/arcade/arcade_pixels.gd")
const Props = preload("res://game/ui/pixel_props.gd")
const SIZE := Vector2i(320, 180)
const TEXEL := 4.0
const SKY_TOP := Color("#6fa8e0")
const SKY_MID := Color("#b8dcf2")
const HORIZON := Color("#f6d8bc")
const CLOUD := Color("#f6f2fa")
const CLOUD_SHADE := Color("#b9b0d8")
const SUN := Color("#fff4c8")
const STEEL := Color("#8a8fb8")
const GRASS := Color("#8fc46e")
const ROCK := Color("#9a8a9e")
const GONDOLAS: Array[Color] = [Color("#e8807a"), Color("#f2c46a"), Color("#7ac0b8"), Color("#a88ad8")]
## Wheel centre and radius in texels; where the cloud deck starts.
const WHEEL := Vector2(72, 66)
const WHEEL_RADIUS := 44.0
const DECK_Y := 142
const SUN_AT := Vector2(252, 34)


static func texture() -> ImageTexture:
	return Pixels.bake("sky-backdrop", SIZE, paint)


## A lit cloud puff `size` texels across, shaded lavender underneath; games use
## it for platforms, puffs and splashes so every sky game's clouds match.
static func cloud_puff(size: Vector2i, salt := 0) -> ImageTexture:
	return Pixels.bake("sky-puff|%d|%d|%d" % [size.x, size.y, salt], size, func(x: int, y: int) -> Color:
		return _puff(x, y, size, salt))


## Lay the backdrop on `canvas` with its living sky; `now` is the driver clock.
static func draw(canvas: CanvasItem, now: float, reduced_motion: bool) -> void:
	Props.stamp(canvas, texture(), Vector2.ZERO, TEXEL)
	var still := reduced_motion
	# A soft breathing halo round the sun.
	for ring in 4:
		var breathe := 0.0 if still else 3.0 * sin(now * 0.6)
		canvas.draw_circle(SUN_AT * TEXEL, 40.0 + ring * 16.0 + breathe, Color(1.0, 0.97, 0.82, 0.07))
	# Gondolas turning slowly round the far wheel, hazy like the wheel itself.
	var turn := 0.0 if still else now * 0.12
	for seat in 12:
		var angle := turn + seat * TAU / 12.0
		var hang := (WHEEL + Vector2.from_angle(angle) * WHEEL_RADIUS) * TEXEL + Vector2(0, 6)
		var tone: Color = GONDOLAS[seat % GONDOLAS.size()].lerp(SKY_MID, 0.35)
		canvas.draw_rect(Rect2(hang - Vector2(7, 4), Vector2(14, 12)), tone.darkened(0.35))
		canvas.draw_rect(Rect2(hang - Vector2(6, 3), Vector2(12, 10)), tone)
		canvas.draw_rect(Rect2(hang - Vector2(6, 3), Vector2(12, 3)), tone.lightened(0.25))
	# Small clouds drifting across the upper sky.
	for drift in 3:
		var speed := 6.0 + drift * 3.0
		var x := fposmod((40.0 + drift * 110.0) + (0.0 if still else now * speed), 360.0) - 40.0
		var at := Vector2(x, 14.0 + drift * 16.0) * TEXEL
		Props.stamp(canvas, cloud_puff(Vector2i(26 - drift * 4, 10 - drift), 10 + drift), at, TEXEL, Color(1, 1, 1, 0.9))
	# Two birds gliding past.
	for bird in 2:
		var x := fposmod(200.0 + bird * 24.0 - (0.0 if still else now * 9.0), 380.0) - 30.0
		var at := Vector2(x, 52.0 + bird * 6.0) * TEXEL
		var flap := 0.0 if still else sin(now * 6.0 + bird) * 3.0
		canvas.draw_line(at + Vector2(-8, -flap), at, Color("#5a5878"), 3.0)
		canvas.draw_line(at, at + Vector2(8, -flap), Color("#5a5878"), 3.0)


static func paint(x: int, y: int) -> Color:
	if y >= _deck_top(x):
		return _deck(x, y)
	var isle := _isle(x, y)
	if isle.a > 0.0:
		return isle
	var wheel := _wheel(x, y)
	if wheel.a > 0.0:
		return wheel
	var far := _far_clouds(x, y)
	if far.a > 0.0:
		return far
	return _sky(x, y)


static func _sky(x: int, y: int) -> Color:
	var t := float(y) / float(DECK_Y)
	var tone := SKY_TOP.lerp(SKY_MID, smoothstep(0.0, 0.55, t)).lerp(HORIZON, smoothstep(0.55, 1.0, t))
	var sun := Vector2(x, y).distance_to(SUN_AT)
	if sun < 9.0:
		return Pixels.lit(SUN, 1.0 - sun / 9.0, x, y)
	if sun < 22.0:
		tone = tone.lerp(SUN, 0.35 * (1.0 - (sun - 9.0) / 13.0))
	return Pixels.lit(tone, 0.15 * (Pixels.noise(x / 8, y / 6, 3) - 0.5), x, y)


## Far cumulus along the horizon: lumpy tops lit warm, lavender underneath.
static func _far_clouds(x: int, y: int) -> Color:
	var top := 104.0 - 12.0 * absf(sin(x * 0.045)) - 7.0 * absf(sin(x * 0.11 + 1.3)) - 4.0 * Pixels.noise(x / 5, 1, 7)
	if y < top:
		return Pixels.CLEAR
	var depth := (y - top) / 30.0
	var tone := CLOUD.lerp(CLOUD_SHADE, clampf(depth, 0.0, 1.0) * 0.7).lerp(HORIZON, 0.25)
	return Pixels.lit(tone, 0.6 - depth * 1.2 + 0.2 * (Pixels.noise(x / 3, y / 3, 5) - 0.5), x, y)


## The ferris wheel far away: rim, spokes, hub and an A-frame, softened by haze.
static func _wheel(x: int, y: int) -> Color:
	var offset := Vector2(x, y) - WHEEL
	var reach := offset.length()
	var haze := SKY_MID
	var steel := STEEL.lerp(haze, 0.3)
	if absf(reach - WHEEL_RADIUS) < 1.6 or absf(reach - (WHEEL_RADIUS - 4.0)) < 0.9:
		return Pixels.lit(steel, 0.4 - offset.normalized().y * 0.6, x, y)
	if reach < WHEEL_RADIUS - 4.0:
		var angle := fposmod(atan2(offset.y, offset.x), TAU / 12.0)
		if reach < 5.0:
			return Pixels.lit(steel.darkened(0.15), 0.6 - offset.y * 0.1, x, y)
		if angle < 0.06 or angle > TAU / 12.0 - 0.06:
			return Pixels.lit(steel.lightened(0.1), 0.2, x, y)
	# The A-frame legs from the hub down into the clouds.
	for side: float in [-1.0, 1.0]:
		var along := (y - WHEEL.y) / float(DECK_Y - WHEEL.y)
		if along >= 0.0 and along <= 1.0 and absf(x - (WHEEL.x + side * along * 30.0)) < 1.6:
			return Pixels.lit(steel.darkened(0.1), 0.3 * side, x, y)
	return Pixels.CLEAR


## Two little floating isles: grass on top, a rocky underside, one tree.
static func _isle(x: int, y: int) -> Color:
	for isle: Vector3 in [Vector3(198, 90, 16), Vector3(286, 74, 12)]:
		var dx := (x - isle.x) / isle.z
		if absf(dx) > 1.0:
			continue
		var top := isle.y - 2.0 * (1.0 - dx * dx)
		var bottom := isle.y + 3.0 + 9.0 * (1.0 - absf(dx)) * (isle.z / 16.0)
		if y >= top and y < top + 2.0:
			return Pixels.lit(GRASS, 0.6 - dx * 0.4, x, y)
		if y >= top + 2.0 and y < bottom:
			return Pixels.lit(ROCK, 0.3 - (y - top) / 10.0 - dx * 0.3, x, y)
		# A round tree on the bigger isle.
		var tree := Vector2(x - (isle.x - 4.0), y - (top - 6.0))
		if isle.z > 14.0 and tree.length() < 4.5:
			return Pixels.lit(Color("#5f9a54"), 0.6 - (tree.x + tree.y) / 6.0, x, y)
		if isle.z > 14.0 and absf(x - (isle.x - 4.0)) < 1.0 and y >= top - 2.0 and y < top:
			return Color("#7a5a40")
	return Pixels.CLEAR


static func _deck_top(x: int) -> float:
	return DECK_Y - 5.0 * absf(sin(x * 0.06)) - 4.0 * absf(sin(x * 0.17 + 0.8)) - 2.0 * Pixels.noise(x / 4, 2, 9)


## The cloud deck the park floats on: bright puffy tops, soft shade below.
static func _deck(x: int, y: int) -> Color:
	var depth := (y - _deck_top(x)) / 30.0
	var bump := sin(x * 0.21 + y * 0.35) * 0.25
	var tone := CLOUD.lerp(CLOUD_SHADE, clampf(depth * 0.8, 0.0, 0.8))
	return Pixels.lit(tone, 0.9 - depth * 1.6 + bump + 0.15 * (Pixels.noise(x / 2, y / 2, 4) - 0.5), x, y)


## A cartoon cloud: four round bumps (the second one tallest) on a flattened
## oval base, nudged a little per `salt` so neighbouring clouds differ.
const PUFF_LUMPS: Array[Vector3] = [Vector3(0.2, 0.64, 0.3), Vector3(0.4, 0.46, 0.4), Vector3(0.62, 0.5, 0.36), Vector3(0.81, 0.64, 0.28)]


static func _puff(x: int, y: int, size: Vector2i, salt: int) -> Color:
	if y >= size.y * 0.88:
		return Pixels.CLEAR
	var point := Vector2(x + 0.5, y + 0.5)
	var best := 99.0
	var lit_from := Vector2.ZERO
	for index in PUFF_LUMPS.size():
		var lump := PUFF_LUMPS[index]
		var shift := (Pixels.noise(index, salt, 6) - 0.5) * 0.06
		var centre := Vector2((lump.x + shift) * size.x, (lump.y - absf(shift)) * size.y)
		var offset := (point - centre) / (lump.z * size.y)
		if offset.length() < best:
			best = offset.length()
			lit_from = offset
	var base := Vector2((point.x - 0.5 * size.x) / (0.46 * size.x), (point.y - 0.72 * size.y) / (0.2 * size.y))
	if best > 1.0 and base.length() > 1.0:
		return Pixels.CLEAR
	if best > 1.0:
		lit_from = base * 0.6
	var down := clampf(float(y) / size.y, 0.0, 1.0)
	var tone := CLOUD.lerp(CLOUD_SHADE, smoothstep(0.4, 1.0, down) * 0.9)
	return Pixels.lit(tone, 0.6 - (lit_from.x + lit_from.y) * 0.6 - down * 0.4 + 0.1 * (Pixels.noise(x, y, salt + 2) - 0.5), x, y)
