extends RefCounted
## The shared backdrop of the 苔光溫室 (garden) arcade games: the inside of the
## glasshouse at 320 x 180 texels (one screen at 4 px a texel). A glass roof
## in lit and shaded iron glazing bars, tall back panes with the garden
## outside (a tree line and shrubs, a sheen on the glass), a potting shelf of
## ferns, shrubs and flowering pots, hanging baskets trailing ivy, and a
## mossy brick knee wall with a planter trough on its cap. `draw()` lays it
## down with slow sun shafts and drifting dust; reduced motion stills both.
## A game draws its own bench or floor and its play objects on top.

const Pixels = preload("res://game/minigames/arcade/arcade_pixels.gd")
const Props = preload("res://game/ui/pixel_props.gd")
const SIZE := Vector2i(320, 180)
const TEXEL := 4.0
const IRON := Color("#38534e")
const SKY := Color("#cfe0cf")
const HAZE := Color("#a9c3b2")
const FAR_TREES := Color("#7f9f86")
const NEAR_SHRUBS := Color("#5c8464")
const GLASS := Color("#9cc4bd")
const SHELF := Color("#7a5a3a")
const CLAY := Color("#b8643f")
const SOIL := Color("#4f3f2e")
const FERN := Color("#4f8a4a")
const LEAVES := Color("#6aa85a")
const BRICK := Color("#9a5a44")
const MOSS := Color("#5f8a4a")
const BLOOMS: Array[Color] = [Color("#f2a7b8"), Color("#ffd166"), Color("#e8eef0"), Color("#bfa2e8")]
const ROOF_Y := 38
const SHELF_Y := 74
const KNEE_Y := 124
## Hanging baskets: texel x of each hook.
const BASKETS: Array[int] = [52, 166, 276]


static func texture() -> ImageTexture:
	return Pixels.bake("greenhouse-backdrop", SIZE, paint)


## Lay the backdrop on `canvas` with its sun shafts and dust; `now` is the
## driver clock.
static func draw(canvas: CanvasItem, now: float, reduced_motion: bool) -> void:
	Props.stamp(canvas, texture(), Vector2.ZERO, TEXEL)
	for shaft in 3:
		var x := 250.0 + shaft * 340.0
		var sway := 0.0 if reduced_motion else 12.0 * sin(now * 0.35 + shaft * 1.7)
		var glow := 0.06 + (0.0 if reduced_motion else 0.02 * sin(now * 0.8 + shaft))
		canvas.draw_colored_polygon(PackedVector2Array([Vector2(x + sway, 150), Vector2(x + 86 + sway, 150), Vector2(x - 74, 720), Vector2(x - 210, 720)]), Color(1, 0.97, 0.82, glow))
		canvas.draw_colored_polygon(PackedVector2Array([Vector2(x + 20 + sway, 150), Vector2(x + 48 + sway, 150), Vector2(x - 120, 720), Vector2(x - 160, 720)]), Color(1, 0.97, 0.82, glow * 0.8))
	# Dust motes turning slowly in the light.
	for mote in 26:
		var shaft := mote % 3
		var drift := 0.0 if reduced_motion else fposmod(now * (6.0 + mote % 4) + mote * 37.0, 420.0)
		var y := 190.0 + fposmod(mote * 61.0 + drift, 420.0)
		var x := 250.0 + shaft * 340.0 + 30.0 - (y - 150.0) * 0.27 + 14.0 * sin(mote * 2.3 + (0.0 if reduced_motion else now * 0.6))
		canvas.draw_rect(Rect2(Vector2(x, y).snapped(Vector2(2, 2)), Vector2(2, 2)), Color(1, 0.98, 0.85, 0.35 + 0.25 * sin(mote * 1.7)))


static func paint(x: int, y: int) -> Color:
	if y < ROOF_Y:
		return _roof(x, y)
	if y < KNEE_Y:
		var inside := _inside(x, y)
		return inside if inside.a > 0.0 else _back_glass(x, y)
	return _knee_wall(x, y)


## Glass roof: panes of pale sky with soft clouds and beads of condensation,
## iron glazing bars lit on the left and shaded on the right, and a gutter beam.
static func _roof(x: int, y: int) -> Color:
	if y >= ROOF_Y - 3:
		return IRON.lightened(0.28) if y == ROOF_Y - 3 else (IRON if y == ROOF_Y - 2 else IRON.darkened(0.35))
	var bar := x % 40
	if bar == 0:
		return IRON.lightened(0.3)
	if bar == 1:
		return IRON
	if bar == 2:
		return IRON.darkened(0.3)
	if y == 18:
		return IRON.lightened(0.15)
	if y == 19:
		return IRON.darkened(0.2)
	var sky := Color("#9fbfb8").lerp(SKY, float(y) / ROOF_Y)
	var cloud := sin(x * 0.045 + 1.0) * 0.5 + sin(x * 0.11 + y * 0.3) * 0.3 - absf(y - 12.0) / 14.0
	if cloud > 0.25:
		sky = sky.lerp(Color("#eef4ea"), clampf((cloud - 0.25) * 2.0, 0.0, 0.7))
	if Pixels.noise(x, y, 11) > 0.94:
		sky = sky.lightened(0.12)
	return Pixels.grainy(sky, x, y, 0.03)


## The tall back panes: mullions and a transom in lit iron, the garden outside
## in two soft layers, and a diagonal sheen on the glass.
static func _back_glass(x: int, y: int) -> Color:
	var mullion := x % 64
	if mullion == 0:
		return IRON.lightened(0.3)
	if mullion == 1 or mullion == 2:
		return IRON if mullion == 1 else IRON.darkened(0.3)
	if y == 86:
		return IRON.lightened(0.2)
	if y == 87:
		return IRON.darkened(0.25)
	var outside := HAZE.lerp(Color("#9db8a6"), float(y - ROOF_Y) / 86.0)
	var trees := 66.0 + 7.0 * sin(x * 0.05) + 4.0 * sin(x * 0.13 + 2.0) + 3.0 * absf(sin(x * 0.31))
	if y > trees:
		outside = FAR_TREES.lerp(FAR_TREES.darkened(0.12), Pixels.noise(x / 3, y / 3, 2) * 0.6)
	var shrubs := 98.0 + 6.0 * sin(x * 0.09 + 1.0) + 4.0 * sin(x * 0.21) + 3.0 * absf(sin(x * 0.47))
	if y > shrubs:
		outside = NEAR_SHRUBS.lerp(NEAR_SHRUBS.darkened(0.25), clampf((y - shrubs) / 20.0, 0.0, 1.0))
		if Pixels.noise(x / 2, y / 2, 5) > 0.85:
			outside = outside.lerp(BLOOMS[(x / 9) % BLOOMS.size()], 0.45)
	var tone := GLASS.darkened(0.2).lerp(outside, 0.72)
	if posmod(x + y, 96) < 7 or posmod(x + y + 13, 96) < 2:
		tone = tone.lightened(0.07)
	return Pixels.grainy(tone, x, y, 0.03)


## Things inside the glass in front of the panes: the potting shelf with its
## pots and plants, and baskets hanging from the roof. CLEAR where there are none.
static func _inside(x: int, y: int) -> Color:
	# Hanging baskets with trailing ivy.
	for hook in BASKETS:
		var off := x - hook
		if off == 0 and y < 46:
			return Color("#8a7a5a")
		var basket := Vector2(off / 7.0, (y - 49.0) / 4.0)
		if y >= 46 and y <= 52 and basket.length() <= 1.0:
			return Pixels.wood(Color("#9a7a4a"), x, y, 2, true) if y > 47 else LEAVES.darkened(0.1)
		if y > 50 and y < 70 and absi(off) <= 8 and posmod(off, 3) == 0:
			var reach := 56 + int(Pixels.noise(x, 3, 7) * 14.0)
			if y < reach:
				return LEAVES if posmod(y + off, 3) == 0 else LEAVES.darkened(0.25)
	# The shelf: a lit board on two iron brackets.
	var on_shelf := (x >= 14 and x <= 146) or (x >= 184 and x <= 306)
	if on_shelf and (y == SHELF_Y or y == SHELF_Y + 1):
		return Pixels.wood(SHELF.lightened(0.15) if y == SHELF_Y else SHELF.darkened(0.2), x, y, 14, false)
	if on_shelf and y == SHELF_Y + 2:
		return Color(Props.SHADOW, 1.0).lerp(SHELF, 0.4)
	if on_shelf and y > SHELF_Y + 2 and y < SHELF_Y + 8 and (x == 24 or x == 136 or x == 194 or x == 296):
		return IRON
	if not on_shelf or y >= SHELF_Y or y < 50:
		return Pixels.CLEAR
	# Pots every 22 texels, each with its own plant.
	var slot := (x - 14) / 22 if x < 160 else (x - 184) / 22 + 6
	var middle := (14 + 22 * slot + 11) if slot < 6 else (184 + 22 * (slot - 6) + 11)
	var dx := x - middle
	var kind := int(Pixels.noise(slot, 1, 13) * 4.0)
	var pot_top := SHELF_Y - 8 - (kind % 2) * 2
	if y >= pot_top:
		var half := 5.0 - (y - pot_top) * 0.25
		if absf(dx) <= half:
			if y == pot_top:
				return CLAY.lightened(0.15)
			return Pixels.lit(CLAY, -dx / 5.0 * 0.8, x, y)
		return Pixels.CLEAR
	var above := pot_top - y
	match kind:
		0:
			# A fern: arching fronds.
			for frond in 5:
				var lean := (frond - 2) * 1.6
				var fx := dx - lean * above * 0.35
				if absf(fx) < 1.0 and above < 11 - absf(frond - 2) * 2:
					return FERN.lightened(0.12) if frond % 2 == 0 else FERN
		1:
			# A round shrub.
			var bush := Vector2(dx / 7.0, (above - 6.0) / 6.0)
			if bush.length() < 1.0:
				return Pixels.rounded(LEAVES, bush) if Pixels.noise(x, y, 4) > 0.15 else LEAVES.darkened(0.3)
		2:
			# Flowers on stems.
			if absf(dx) <= 5 and above < 10:
				if above > 6 and posmod(dx, 3) == 0:
					return BLOOMS[posmod(slot + dx, BLOOMS.size())]
				if posmod(dx + 1, 3) == 0:
					return FERN.darkened(0.1)
		_:
			# A tall succulent spike.
			if absf(dx) <= 2 - above / 8 and above < 14:
				return Pixels.lit(Color("#7aa86a"), -dx * 0.4, x, y)
	return Pixels.CLEAR


## The mossy brick knee wall under the panes, a stone cap and a planter trough
## of low greenery along it.
static func _knee_wall(x: int, y: int) -> Color:
	var row := y - KNEE_Y
	if row < 6:
		var trough := row >= 2
		if row < 2:
			# Low plants spilling over the trough.
			var tuft := Pixels.noise(x / 2, 0, 21)
			return (LEAVES if tuft > 0.5 else FERN).lightened(0.1 * (1 - row)) if tuft > 0.2 else Color("#4a6a44")
		if trough:
			return Pixels.wood(SHELF.darkened(0.1), x, y, 18, false)
	if row < 8:
		return Color("#c9b9a0") if row == 6 else Color("#8a7a62")
	var course := (row - 8) / 4
	var shifted := x + (4 if course % 2 == 1 else 0)
	if (row - 8) % 4 == 3 or shifted % 9 == 0:
		return Color("#5a4a3a")
	var brick := BRICK.darkened(0.12 * Pixels.noise(shifted / 9, course, 5))
	if Pixels.noise(shifted / 3, course, 7) > 0.74:
		brick = brick.lerp(MOSS, 0.55)
	return Pixels.grainy(brick, x, y, 0.1)
