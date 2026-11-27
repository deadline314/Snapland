extends RefCounted
## The shared backdrop of the 幽幽旅館 (hotel) arcade games: a hotel hall at
## night at 320 x 180 texels (one screen at 4 px a texel). A plum ceiling with
## a dentil cornice, lilac damask wallpaper, two arched windows onto a starry
## sea with a big moon between velvet curtains, a gilt portrait of the hotel's
## smiling ghost, two brass candle sconces and dark wainscot panelling below a
## chair rail. `draw()` lays it down with twinkling stars, a breathing moon
## glow, flickering candles, moonbeams, drifting sparkles and a little ghost
## floating along the wall; reduced motion stills them all. A game draws its
## own floor and play objects on top. `ghost()` is the hotel's friendly ghost,
## for every hotel game to share.

const Pixels = preload("res://game/minigames/arcade/arcade_pixels.gd")
const Props = preload("res://game/ui/pixel_props.gd")
const SIZE := Vector2i(320, 180)
const TEXEL := 4.0
const CEILING := Color("#2e2140")
const WALLPAPER := Color("#6f5a96")
const DAMASK := Color("#8f78b8")
const NIGHT := Color("#1c2048")
const SEA := Color("#23365a")
const MOON := Color("#fff2c4")
const CURTAIN := Color("#7a3a5c")
const WOOD := Color("#4a3046")
const BRASS := Color("#c9953e")
const CREAM := Color("#f4ecd8")
const GHOST := Color("#eef0ff")
const BLUSH := Color("#f2a7c4")
const CORNICE_Y := 16
const RAIL_Y := 118
## Arched windows (texels): x, top, width, height; the moon sits in the first.
const WINDOWS: Array[Rect2i] = [Rect2i(28, 30, 50, 74), Rect2i(242, 30, 50, 74)]
const HORIZON := 0.7
const PORTRAIT := Rect2i(136, 34, 48, 58)
## Candle sconces: texel x of each, on the wallpaper between window and portrait.
const SCONCES: Array[int] = [108, 212]
const SCONCE_Y := 62


static func texture() -> ImageTexture:
	return Pixels.bake("hotel-backdrop", SIZE, paint)


## The hotel's friendly ghost, 16 x 18 texels: a round head, a wavy hem, two
## dark eyes and pink cheeks. Moods: plain, happy (eyes shut in a smile),
## cheeky (tongue out), oops (round mouth).
static func ghost(mood := "plain") -> ImageTexture:
	return Pixels.bake("hotel-ghost|" + mood, Vector2i(16, 18), func(x: int, y: int) -> Color:
		return _ghost(x, y, mood))


## Lay the backdrop on `canvas` with its living light; `now` is the driver clock.
static func draw(canvas: CanvasItem, now: float, reduced_motion: bool) -> void:
	Props.stamp(canvas, texture(), Vector2.ZERO, TEXEL)
	var still := reduced_motion
	# Moonbeams slanting in from both windows onto the floor.
	for index in WINDOWS.size():
		var pane := WINDOWS[index]
		var left := pane.position.x * TEXEL + 16.0
		var right := (pane.position.x + pane.size.x) * TEXEL - 16.0
		var top := (pane.position.y + pane.size.x / 2) * TEXEL
		var glow := 0.07 if still else 0.06 + 0.02 * sin(now * 0.5 + index * 2.0)
		canvas.draw_colored_polygon(PackedVector2Array([Vector2(left, top), Vector2(right, top), Vector2(right + 150.0, 720), Vector2(left + 60.0, 720)]), Color(0.78, 0.82, 1.0, glow))
	# A soft halo breathing round the moon.
	var moon := _moon_centre() * TEXEL
	for ring in 4:
		var breathe := 0.0 if still else 3.0 * sin(now * 0.7)
		canvas.draw_circle(moon, 34.0 + ring * 12.0 + breathe, Color(1.0, 0.95, 0.78, 0.06))
	# Stars twinkling in both windows.
	for star in 22:
		var pane := WINDOWS[star % 2]
		var sx := pane.position.x + 4 + int(Pixels.noise(star, 1, 31) * (pane.size.x - 8))
		var sy := pane.position.y + 6 + int(Pixels.noise(star, 2, 31) * pane.size.y * (HORIZON - 0.15))
		if not _in_window(sx, sy, pane) or Vector2(sx, sy).distance_to(_moon_centre()) < 12.0:
			continue
		var twinkle := 0.8 if still else 0.5 + 0.5 * sin(now * (1.3 + Pixels.noise(star, 3, 31) * 2.0) + star * 1.7)
		canvas.draw_rect(Rect2(Vector2(sx, sy) * TEXEL, Vector2(TEXEL, TEXEL)), Color(1.0, 0.97, 0.86, 0.35 + 0.6 * twinkle))
		if twinkle > 0.85:
			canvas.draw_rect(Rect2(Vector2(sx - 1, sy) * TEXEL, Vector2(TEXEL * 3, TEXEL)), Color(1.0, 0.97, 0.86, 0.35))
			canvas.draw_rect(Rect2(Vector2(sx, sy - 1) * TEXEL, Vector2(TEXEL, TEXEL * 3)), Color(1.0, 0.97, 0.86, 0.35))
	# Candle flames with a warm flicker on the wallpaper round them.
	for index in SCONCES.size():
		var tip := Vector2(SCONCES[index] * TEXEL + 2.0, (SCONCE_Y - 9) * TEXEL)
		var flicker := 1.0 if still else 0.85 + 0.15 * sin(now * 11.0 + index * 3.1) * sin(now * 6.3 + index)
		for ring in 3:
			canvas.draw_circle(tip + Vector2(0, 6), (26.0 + ring * 16.0) * flicker, Color(1.0, 0.78, 0.45, 0.07))
		var sway := 0.0 if still else roundf(sin(now * 7.0 + index) * 1.0)
		canvas.draw_rect(Rect2(tip + Vector2(-4 + sway * 2.0, -4), Vector2(8, 12)), Color("#ffb347"))
		canvas.draw_rect(Rect2(tip + Vector2(-4 + sway * 4.0, -12 * flicker), Vector2(4, 8)), Color("#ffd98a"))
		canvas.draw_rect(Rect2(tip + Vector2(-2, 0), Vector2(4, 6)), Color("#fff4d0"))
	# A little ghost floating slowly along the wall, bobbing; still beside the
	# portrait when motion is reduced.
	var lap := 40.0
	var t := 0.62 if still else fposmod(now / lap + 0.3, 1.0)
	var ghost_x := lerpf(-80.0, 1360.0, t)
	var bob := 0.0 if still else 8.0 * sin(now * 1.6)
	var ghost_at := Vector2(ghost_x, 250.0 + bob + 30.0 * sin(t * TAU * 2.0))
	var sprite := ghost("happy" if fposmod(now, 7.0) < 1.2 and not still else "plain")
	Props.stamp(canvas, sprite, ghost_at, 3.0, Color(1, 1, 1, 0.62))
	# Sparkles drifting up through the moonlight.
	for mote in 18:
		var rise := 0.0 if still else fposmod(now * (8.0 + mote % 5) + mote * 53.0, 560.0)
		var y := 690.0 - fposmod(mote * 97.0 + rise, 560.0)
		var x := fposmod(mote * 151.0, 1280.0) + 10.0 * sin(mote * 1.9 + (0.0 if still else now * 0.7))
		canvas.draw_rect(Rect2(Vector2(x, y).snapped(Vector2(2, 2)), Vector2(2, 2)), Color(0.92, 0.88, 1.0, 0.25 + 0.25 * sin(mote * 2.3)))


static func paint(x: int, y: int) -> Color:
	if y < CORNICE_Y:
		return _ceiling(x, y)
	if y >= RAIL_Y:
		return _wainscot(x, y)
	for pane in WINDOWS:
		var window := _window(x, y, pane)
		if window.a > 0.0:
			return window
	var portrait := _portrait(x, y)
	if portrait.a > 0.0:
		return portrait
	for sconce in SCONCES:
		var brass := _sconce(x, y, sconce)
		if brass.a > 0.0:
			return brass
	return _wallpaper(x, y)


## A plum plaster ceiling and a dentil cornice lit along its top.
static func _ceiling(x: int, y: int) -> Color:
	if y < 9:
		return Pixels.grainy(CEILING.darkened(0.25 - y * 0.02), x, y, 0.04)
	if y == 9:
		return WOOD.lightened(0.3)
	if y == 10:
		return WOOD
	if y < 14:
		# Dentil blocks with shaded gaps.
		var block := posmod(x, 6)
		if block == 4:
			return WOOD.darkened(0.45)
		return Pixels.lit(WOOD.lightened(0.1), 0.6 - (y - 11) * 0.5 - (0.4 if block == 3 else 0.0), x, y)
	if y == 14:
		return WOOD.lightened(0.2)
	return Color(WOOD.darkened(0.5), 1.0)


## Lilac damask: a diamond lattice of lighter lines with a small rose
## fleuron in each cell, fading darker toward the ceiling.
static func _wallpaper(x: int, y: int) -> Color:
	var cell_x := posmod(x, 20) - 10
	var cell_y := posmod(y - CORNICE_Y, 24) - 12
	var lattice := absf(cell_x) / 10.0 + absf(cell_y) / 12.0
	var shade := -0.6 * (1.0 - float(y - CORNICE_Y) / float(RAIL_Y - CORNICE_Y)) - 0.1
	# The cornice throws a band of shadow just under it.
	if y < CORNICE_Y + 4:
		shade -= 0.6
	var base := WALLPAPER
	if absf(lattice - 0.95) < 0.07:
		base = DAMASK
	var fleur := Vector2(cell_x, cell_y * 0.8)
	if fleur.length() < 2.3:
		base = DAMASK.lerp(BLUSH, 0.35)
	elif absi(cell_x) == 0 and absi(cell_y) <= 4 or absi(cell_y) == 0 and absi(cell_x) <= 3:
		base = DAMASK.darkened(0.1)
	return Pixels.lit(base, shade + 0.2 * (Pixels.noise(x, y, 5) - 0.5), x, y)


static func _moon_centre() -> Vector2:
	var pane := WINDOWS[0]
	return Vector2(pane.position.x + pane.size.x * 0.62, pane.position.y + 22)


static func _in_window(x: int, y: int, pane: Rect2i) -> bool:
	var radius := pane.size.x * 0.5
	var centre := Vector2(pane.position.x + radius, pane.position.y + radius)
	if x < pane.position.x or x >= pane.position.x + pane.size.x or y >= pane.position.y + pane.size.y:
		return false
	return y >= centre.y or Vector2(x + 0.5, y + 0.5).distance_to(centre) <= radius


## An arched window: a cream frame and glazing bars, a starry night sky over
## the sea with the moon and its path, and velvet curtains tied back each side.
static func _window(x: int, y: int, pane: Rect2i) -> Color:
	var curtain := _curtain(x, y, pane)
	if curtain.a > 0.0:
		return curtain
	var outer := Rect2i(pane.position - Vector2i(3, 3), pane.size + Vector2i(6, 4))
	var frame_pane := Rect2i(outer.position, outer.size)
	if not _in_window(x, y, frame_pane):
		return Pixels.CLEAR
	if not _in_window(x, y, pane):
		# The frame: lit on its upper left, a deep sill below.
		if y >= pane.position.y + pane.size.y:
			return CREAM.darkened(0.15) if y == pane.position.y + pane.size.y else CREAM.darkened(0.45)
		var left := x < pane.position.x + pane.size.x * 0.5
		return Pixels.lit(CREAM.darkened(0.25), 0.6 if left else -0.5, x, y)
	var mid_x := pane.position.x + pane.size.x / 2
	var bar_y := pane.position.y + int(pane.size.y * 0.55)
	if x == mid_x or y == bar_y:
		return CREAM.darkened(0.3)
	if x == mid_x + 1 or y == bar_y + 1:
		return CREAM.darkened(0.6)
	var down := float(y - pane.position.y) / pane.size.y
	var moon := _moon_centre()
	if down < HORIZON:
		var on_moon := Vector2(x + 0.5, y + 0.5).distance_to(moon)
		if on_moon < 8.0:
			# The moon: lit to the upper left with two soft craters.
			var crater := Vector2(x - moon.x + 2.0, y - moon.y + 1.0).length() < 1.8 or Vector2(x - moon.x - 2.5, y - moon.y - 3.0).length() < 1.4
			return Pixels.lit(MOON.darkened(0.12 if crater else 0.0), 0.5 - (x - moon.x + y - moon.y) * 0.06, x, y)
		var sky := NIGHT.lerp(Color("#3b3f7a"), down / HORIZON)
		if on_moon < 13.0:
			sky = sky.lerp(MOON, 0.18 * (13.0 - on_moon) / 5.0)
		if Pixels.noise(x, y, 17) > 0.975:
			sky = sky.lerp(MOON, 0.6)
		return Pixels.grainy(sky, x, y, 0.03)
	if down < HORIZON + 0.015:
		return Color("#4a5a8a")
	# The sea, with a glittering moon path under the moon.
	var sea := SEA.darkened((down - HORIZON) * 0.8)
	var path := absf(x + 0.5 - moon.x) < 4.0 - (down - HORIZON) * 4.0
	if posmod(y, 3) == 0 and (path or Pixels.noise(x / 3, y, 9) > 0.8):
		sea = sea.lerp(MOON, 0.55 if path else 0.15)
	return Pixels.grainy(sea, x, y, 0.04)


## Plum velvet curtains hanging either side of a window, gathered under a gold
## tieback a little below the middle.
static func _curtain(x: int, y: int, pane: Rect2i) -> Color:
	var tie := pane.position.y + int(pane.size.y * 0.62)
	var top := pane.position.y - 5
	var bottom := pane.position.y + pane.size.y + 6
	if y < top or y > bottom:
		return Pixels.CLEAR
	for side in 2:
		var inner := pane.position.x + (4 if side == 0 else pane.size.x - 4)
		var outer := pane.position.x + (-9 if side == 0 else pane.size.x + 9)
		# The curtain swings in over the glass above the tie and hangs straight below.
		var reach := 0.0
		if y < tie:
			reach = 1.0 - float(y - top) / float(tie - top) * 0.75
		else:
			reach = 0.25 + float(y - tie) / float(bottom - tie) * 0.15
		var edge := lerpf(float(outer), float(inner), reach)
		var lo := minf(float(outer), edge)
		var hi := maxf(float(outer), edge)
		if x + 0.5 < lo or x + 0.5 > hi:
			continue
		if absi(y - tie) <= 1:
			return BRASS.lightened(0.2) if y == tie - 1 else (BRASS if y == tie else BRASS.darkened(0.3))
		var fold := sin((x - outer) * 1.1 + y * 0.04)
		return Pixels.lit(CURTAIN, 0.5 * fold - 0.2 - (0.3 if y < top + 3 else 0.0), x, y)
	return Pixels.CLEAR


## A gilt portrait of the hotel's ghost in a bow tie, smiling on a teal ground.
static func _portrait(x: int, y: int) -> Color:
	var r := PORTRAIT
	if x < r.position.x or y < r.position.y or x >= r.position.x + r.size.x or y >= r.position.y + r.size.y:
		return Pixels.CLEAR
	var lx := x - r.position.x
	var ly := y - r.position.y
	var frame := Pixels.gilt(BRASS, lx, ly, r.size.x, r.size.y, 6, 3)
	if frame.a > 0.0:
		return frame
	var middle := Vector2(r.size.x * 0.5, r.size.y * 0.46)
	var ghost_x := int((lx - middle.x + 8) * 0.9)
	var ghost_y := int((ly - middle.y + 9) * 0.9)
	if ghost_x >= 0 and ghost_x < 16 and ghost_y >= 0 and ghost_y < 18:
		var body := _ghost(ghost_x, ghost_y, "happy")
		if body.a > 0.0:
			return body
	# A little red bow tie under the chin.
	var tie := Vector2(lx - middle.x, ly - middle.y - 7.0)
	if absf(tie.y) <= 1.5 and absf(tie.x) <= 3.5 and absf(tie.x) >= absf(tie.y) - 0.5:
		return Color("#c0485e") if absf(tie.x) > 0.6 else Color("#8a2a40")
	var ground := Vector2(lx, ly) - middle
	return Pixels.lit(Color("#2f5a5a"), 0.5 - ground.length() * 0.06, x, y)


## A brass backplate, a curled arm and a cream candle; the flame is drawn live.
static func _sconce(x: int, y: int, at: int) -> Color:
	var dx := x - at
	var dy := y - SCONCE_Y
	if absi(dx) <= 2 and dy >= -2 and dy <= 6:
		return Pixels.lit(BRASS, 0.6 - dy * 0.15 - absf(dx) * 0.2, x, y)
	if dy == -3 and absi(dx) <= 3:
		return BRASS.darkened(0.2)
	if absi(dx) <= 1 and dy >= -8 and dy < -3:
		return Pixels.lit(CREAM, 0.4 - dx * 0.4, x, y)
	if dx == 0 and dy == -9:
		return Color("#3a2a2a")
	return Pixels.CLEAR


## Dark panelled wainscot: a lit chair rail, then raised panels with bevels.
static func _wainscot(x: int, y: int) -> Color:
	var row := y - RAIL_Y
	if row < 4:
		return [WOOD.lightened(0.4), WOOD.lightened(0.15), WOOD, WOOD.darkened(0.4)][row]
	var bay := posmod(x, 40)
	var inset := row - 8
	if bay < 4 or bay > 35 or inset < 0:
		return Pixels.wood(WOOD.darkened(0.15), x, y, 9, true)
	# A raised panel: lit top and left bevels, shaded bottom and right.
	if inset == 0 or bay == 4:
		return WOOD.lightened(0.25)
	if bay == 35:
		return WOOD.darkened(0.35)
	return Pixels.wood(WOOD, x, y, 32, true, bay)


static func _ghost(x: int, y: int, mood: String) -> Color:
	var head := Vector2((x + 0.5 - 8.0) / 7.0, (y + 0.5 - 7.5) / 7.0)
	var inside := head.length() <= 1.0 or (absf(x + 0.5 - 8.0) <= 7.0 and y >= 7)
	# A wavy hem along the bottom.
	if y >= 15:
		inside = inside and posmod(x, 4) != 0 and not (y == 17 and posmod(x, 4) != 2)
	if not inside:
		return Pixels.CLEAR
	var eye_row := 7
	for eye_x: int in [5, 10]:
		if mood == "happy":
			if (y == eye_row and absi(x - eye_x) == 1) or (y == eye_row - 1 and x == eye_x):
				return Color("#2a2440")
		elif x == eye_x and (y == eye_row or y == eye_row + 1):
			return Color("#2a2440")
	if y == eye_row + 2 and (x == 3 or x == 12):
		return BLUSH
	if mood == "cheeky" and ((y == 11 and x >= 7 and x <= 8) or (y == 12 and x >= 7 and x <= 8)):
		return Color("#ff7fa0") if y == 12 else Color("#2a2440")
	if mood == "oops" and y >= 10 and y <= 11 and x >= 7 and x <= 8:
		return Color("#2a2440")
	if (mood == "plain" or mood == "happy") and y == 10 and x >= 7 and x <= 8:
		return Color("#2a2440")
	return Pixels.lit(GHOST, 0.4 - head.y * 0.5 - head.x * 0.3, x, y)
