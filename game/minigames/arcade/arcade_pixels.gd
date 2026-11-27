extends RefCounted
## Bakes chunky pixel-art sprites for arcade views, once each.
##
## A view describes an object texel by texel (shape tests plus the material
## helpers below); the baker then adds what makes it sit in a painted scene: a
## lit top-left edge, a shaded lower-right edge and a one-texel outline in a
## deepened local colour. Views draw the result with nearest filtering through
## `arcade_view.stamp()`. See 畫面下限 in design/00-principles/simple-fun-minigames.md.
##
## This is the texel layer of the one minigame drawing kit; the canvas layer
## every view calls, arcade or not, is game/ui/pixel_props.gd.

const CLEAR := Color(0, 0, 0, 0)
const NEIGHBOURS: Array[Vector2i] = [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]

static var _cache: Dictionary = {}


## `paint.call(x, y)` returns the local colour of a texel, or CLEAR outside the
## shape. The texture is one texel larger on every side (the outline).
static func bake(key: String, size: Vector2i, paint: Callable) -> ImageTexture:
	if _cache.has(key):
		return _cache[key]
	var width := size.x + 2
	var height := size.y + 2
	var raw := Image.create(width, height, false, Image.FORMAT_RGBA8)
	for y in size.y:
		for x in size.x:
			var local: Color = paint.call(x, y)
			if local.a > 0.0:
				raw.set_pixel(x + 1, y + 1, Color(local, 1.0))
	var art := Image.create(width, height, false, Image.FORMAT_RGBA8)
	for y in height:
		for x in width:
			var tone := raw.get_pixel(x, y)
			if tone.a > 0.0:
				if _open(raw, x, y - 1) or _open(raw, x - 1, y):
					tone = tone.lightened(0.2)
				elif _open(raw, x, y + 1) or _open(raw, x + 1, y):
					tone = tone.darkened(0.26)
				art.set_pixel(x, y, tone)
				continue
			for step in NEIGHBOURS:
				if not _open(raw, x + step.x, y + step.y):
					art.set_pixel(x, y, Color(raw.get_pixel(x + step.x, y + step.y).darkened(0.66), 1.0))
					break
	var texture := ImageTexture.create_from_image(art)
	_cache[key] = texture
	return texture


## Bake a figure given as [Rect2 in texels, Color] blocks, later blocks on top;
## `origin` is the texel that the blocks' (0, 0) lands on.
static func bake_blocks(key: String, size: Vector2i, origin: Vector2i, blocks: Array, wear := 0.07) -> ImageTexture:
	if _cache.has(key):
		return _cache[key]
	return bake(key, size, func(x: int, y: int) -> Color:
		var at := Vector2(x - origin.x + 0.5, y - origin.y + 0.5)
		for index in range(blocks.size() - 1, -1, -1):
			if (blocks[index][0] as Rect2).has_point(at):
				return grainy(blocks[index][1], x, y, wear)
		return CLEAR)


## Cache a texture built by `build.call() -> Image` as it is, with no outline
## pass: tileable materials, soft blobs and icons share the sprites' cache.
static func cached(key: String, build: Callable) -> ImageTexture:
	if not _cache.has(key):
		_cache[key] = ImageTexture.create_from_image(build.call())
	return _cache[key]


static func _open(image: Image, x: int, y: int) -> bool:
	return x < 0 or y < 0 or x >= image.get_width() or y >= image.get_height() or image.get_pixel(x, y).a <= 0.0


## Repeatable 0..1 value per texel.
static func noise(x: int, y: int, salt := 0) -> float:
	var mixed := (x * 374761393 + y * 668265263 + salt * 1442695041) & 0x7fffffff
	mixed = ((mixed ^ (mixed >> 13)) * 1274126177) & 0x7fffffff
	return float((mixed ^ (mixed >> 16)) & 0xffff) / 65535.0


## Boards with seams, a lit edge, long grain streaks and the odd knot.
static func wood(base: Color, x: int, y: int, plank := 8, upright := true, salt := 0) -> Color:
	var across := x if upright else y
	var along := y if upright else x
	var board := across / plank
	if across % plank == 0:
		return base.darkened(0.44)
	var tone := base.darkened(0.14 * noise(board, 7, salt))
	var streak := noise(across, along / 6 + board * 13, salt)
	if streak > 0.74:
		tone = tone.darkened(0.13)
	elif streak < 0.1:
		tone = tone.lightened(0.1)
	if across % plank == 1:
		tone = tone.lightened(0.09)
	if noise(board, along / 9, salt + 3) > 0.93 and across % plank == plank / 2:
		tone = tone.darkened(0.3)
	return tone


## Overlapping roof tiles in staggered rows.
static func shingle(base: Color, x: int, y: int, width := 6, height := 4, salt := 0) -> Color:
	var row := y / height
	var shifted := x + (width / 2 if row % 2 == 1 else 0)
	var tone := base.darkened(0.2 * noise(shifted / width, row, salt))
	if y % height == height - 1 or shifted % width == 0:
		return base.darkened(0.48)
	if y % height == 0:
		tone = tone.lightened(0.14)
	return tone


## Brushed metal with a few pits.
static func metal(base: Color, x: int, y: int, salt := 0) -> Color:
	var tone := base.lightened(0.1) if noise(0, y, salt) > 0.62 else base
	return tone.darkened(0.22) if noise(x, y, salt) > 0.94 else tone


## Paper, felt, paint or tin: an even speckle of slightly darker texels.
static func grainy(base: Color, x: int, y: int, amount := 0.08, salt := 0) -> Color:
	return base.darkened(amount * noise(x, y, salt))


## Shade a point on a rounded form: `offset` runs from the middle (0, 0) to the rim (length 1).
static func rounded(base: Color, offset: Vector2) -> Color:
	var facing := -(offset.x + offset.y) * 0.5
	return base.lightened(0.28 * facing) if facing > 0.0 else base.darkened(-0.34 * facing)


# --- Stage materials (circus arcade games and the shared overlays) -----------

## Shadows lean toward dusky plum and highlights toward warm lamp light, the two
## ends of the painted tents.
const SHADOW_HUE := Color("#2a1430")
const LIGHT_HUE := Color("#ffe2b0")
## Red clay under gilding, showing through where a frame is chipped.
const BOLE := Color("#8a3a2e")
const BAYER: Array[int] = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]


## `base` lit (`value` > 0) or shaded (< 0) with a hue shift, posterised to half
## steps; an ordered dither only right at each step keeps the bands crisp.
static func lit(base: Color, value: float, x: int, y: int) -> Color:
	var step := floorf(value * 2.0 + (BAYER[(y % 4) * 4 + x % 4] / 16.0 - 0.47) * 0.4 + 0.5) * 0.5
	if step > 0.0:
		return base.lightened(0.2 * step).lerp(LIGHT_HUE, 0.1 * step)
	return base.darkened(0.26 * -step).lerp(SHADOW_HUE, 0.14 * -step)


## A whole surface of one material, baked once per kind, size and colours.
## Kinds: lacquer (dark plate, gilt pinstripe, corner rivets in `trim`), velvet
## (hanging folds; a gold fringe when `trim` is opaque), enamel (glossy cabinet,
## rivets in `trim`), glass (mirror with streaks, `trim` glowing low down),
## paper (stock with fibres and a curled corner), key (a dished key top),
## liquid (a striped progress fill), groove (a recessed slot), pole (round
## brass), photo (studio backdrop), planks and planks_v (lacquered boards).
static func surface(kind: String, size: Vector2i, base: Color, trim := CLEAR) -> ImageTexture:
	var key := "surface|%s|%d|%d|%s|%s" % [kind, size.x, size.y, base.to_html(), trim.to_html()]
	if _cache.has(key):
		return _cache[key]
	return bake(key, size, func(x: int, y: int) -> Color: return material(kind, base, trim, x, y, size.x, size.y))


static func material(kind: String, base: Color, trim: Color, x: int, y: int, w: int, h: int) -> Color:
	var down := float(y) / maxf(1.0, h - 1.0)
	match kind:
		"lacquer":
			if w > 10 and h > 8 and trim.a > 0.0:
				if (x < 3 or x > w - 4) and (y < 3 or y > h - 4):
					var stud := Vector2(x if x < 3 else x - (w - 3), y if y < 3 else y - (h - 3)) - Vector2(1, 1)
					if stud.length() < 1.3:
						return rounded(trim, stud / 1.3)
				var rail_x := (x == 3 or x == w - 4) and y >= 3 and y <= h - 4
				var rail_y := (y == 3 or y == h - 4) and x >= 3 and x <= w - 4
				if rail_x or rail_y:
					return trim.darkened(0.2) if x == w - 4 or y == h - 4 else trim
			return lit(base, 0.5 - 1.1 * down + 0.2 * sin((y + 1.4 * sin(x * 0.05)) * 1.3), x, y)
		"velvet":
			if trim.a > 0.0 and y >= h - 3:
				if y == h - 1 and x % 3 == 0:
					return CLEAR
				return trim.lightened(0.15) if y == h - 3 else (trim if (x + y) % 2 == 0 else trim.darkened(0.25))
			var fold := sin(x * TAU / 10.0 + sin(y * 0.045) * 0.9)
			var value := 0.45 * fold + (0.25 if fold > 0.9 else 0.0) - 0.7 * maxf(0.0, 1.0 - y / 8.0)
			return lit(base, value + 0.2 * (noise(x, y) - 0.5), x, y)
		"enamel":
			var stud := rivet(trim if trim.a > 0.0 else base, x, y, w, h)
			if stud.a > 0.0:
				return stud
			var streak := float(x) + float(y) * 0.8 - w * 0.12 - 3.0
			if down < 0.5 and streak > 0.0 and streak < 2.5:
				return base.lightened(0.55).lerp(LIGHT_HUE, 0.3)
			if down < 0.4 and streak > 4.0 and streak < 5.0:
				return base.lightened(0.35)
			return lit(base, 0.9 - 1.5 * down + 0.15 * (noise(x, y) - 0.5), x, y)
		"glass":
			var sheen := float(x) + float(y) * 0.55
			var value := 1.2 - 1.9 * down
			if absf(sheen - w * 0.2) < 1.6 or absf(sheen - w * 0.36) < 0.6:
				value += 1.2
			var tone := lit(base, value, x, y)
			if trim.a > 0.0 and down > 0.62 and BAYER[(y % 4) * 4 + x % 4] / 16.0 < (down - 0.62) * 1.1:
				return tone.lerp(trim, 0.35)
			return tone
		"paper":
			var value := 0.35 + 0.3 * (noise(x, y) - 0.5) - maxf(0.0, float(x) / w + down - 1.5) * 3.2
			if noise(x, y / 2, 3) > 0.975:
				value -= 0.6
			return lit(base, value, x, y)
		"key":
			var dish := Vector2(float(x) / w - 0.45, down - 0.4).length()
			return lit(base, 0.2 - 0.6 * down + (0.4 if dish > 0.42 else 0.0), x, y)
		"liquid":
			return lit(base, (0.2 if posmod(x - y, 8) < 3 else 0.9) - 1.3 * down, x, y)
		"groove":
			return lit(base, -1.0 + 1.1 * minf(1.0, down / 0.6), x, y)
		"pole":
			if y % 14 == 0:
				return base.darkened(0.45)
			var band := 1.5 if y % 14 == 1 else 0.0
			return lit(base, band + 1.5 - absf(float(x) / maxf(1.0, w - 1.0) - 0.3) * 4.2, x, y)
		"photo":
			var centre := Vector2(float(x) / w - 0.5, down - 0.42)
			return lit(base, 0.7 - centre.length() * 2.4 + 0.4 * (noise(x / 2, y / 2) - 0.5), x, y)
		"planks", "planks_v":
			var tone := wood(base, x, y, 10, kind == "planks_v")
			# A lacquer gloss line across the upper left.
			var gloss := float(x) / w + down * 0.7
			return tone.lightened(0.22) if absf(gloss - 0.22) < 0.05 else tone
	return grainy(base, x, y)


## A brass rivet head lit from the top-left on a 10-texel pitch along every
## edge, or CLEAR between rivets.
static func rivet(base: Color, x: int, y: int, w: int, h: int, pitch := 10, inset := 2) -> Color:
	var across := y == inset or y == inset + 1 or y == h - inset - 2 or y == h - inset - 1
	var down := x == inset or x == inset + 1 or x == w - inset - 2 or x == w - inset - 1
	if not ((across and posmod(x - inset - 2, pitch) < 2) or (down and posmod(y - inset - 2, pitch) < 2)):
		return CLEAR
	var corner := Vector2(posmod(x - inset, 2), posmod(y - inset, 2))
	if corner == Vector2.ZERO:
		return base.lightened(0.4)
	return base.darkened(0.4) if corner == Vector2.ONE else base


## A gilded moulding `border` texels wide around a clear hole: outer bead, a
## beaded flat, a groove and an inner lip, with mitred corners and chips down
## to the red bole.
static func gilt(base: Color, x: int, y: int, w: int, h: int, border: int, salt := 0) -> Color:
	var edges := [y, x, h - 1 - y, w - 1 - x]
	var depth: int = edges.min()
	if depth >= border:
		return CLEAR
	var side := edges.find(depth)
	var facing := side <= 1
	var along := x if side % 2 == 0 else y
	var q := float(depth) / float(maxi(1, border - 1))
	var value := 0.0
	if q < 0.25:
		value = 1.4 if facing else -1.2
	elif q < 0.6:
		value = 0.3 if facing else -0.3
		var bead_row := int(border * 0.42)
		if border >= 6 and posmod(along, 6) in [2, 3] and (depth == bead_row or depth == bead_row + 1):
			value = 1.8 if depth == bead_row else -1.0
	elif q < 0.75:
		value = -1.4
	else:
		value = -0.8 if facing else 1.0
	if mini(x, w - 1 - x) == mini(y, h - 1 - y):
		value = minf(value, -0.8)
	if q < 0.25 and noise(x / 2, y / 2, salt + 7) < 0.05:
		return BOLE if facing else BOLE.darkened(0.3)
	return lit(base, value + 0.2 * (noise(x, y, salt) - 0.5), x, y)


static func frame(size: Vector2i, border: int, base: Color, salt := 0) -> ImageTexture:
	return bake("gilt|%d|%d|%d|%s|%d" % [size.x, size.y, border, base.to_html(), salt], size, func(x: int, y: int) -> Color:
		return gilt(base, x, y, size.x, size.y, border, salt))


## Stage boards seen from the front: rows grow taller toward the viewer, with
## staggered seams, nail heads beside every seam and long grain.
static func stage_boards(base: Color, seam: Color, x: int, y: int) -> Color:
	var top := 0
	var row := 0
	while top + 6 + row * 2 <= y:
		top += 6 + row * 2
		row += 1
	var height := 6 + row * 2
	var inside := y - top
	var step := 34 + row * 11
	var cut := posmod(x - (row * 29) % step, step)
	var tone := base.lerp(Color("#6e4436"), 0.3).darkened(maxf(0.2, 0.52 - row * 0.06))
	if cut == 0 or inside == height - 1:
		return seam
	if inside == int(height * 0.5) and (cut == 2 or cut == step - 3):
		return tone.lightened(0.45)
	var value := 0.5 * sin((y + 1.8 * sin(x * 0.07 + row * 2.1)) * 1.7 + row) + 0.4 * (noise(x / 4, y, row) - 0.5)
	if inside == 0:
		value = 1.2
	elif inside == height - 2:
		value = -1.0
	elif cut == 1:
		value += 0.8
	elif cut == step - 1:
		value -= 0.7
	return lit(tone, value, x, y)


## The audience's heads and shoulders in the dark along the front of the ring,
## one seat every 14 texels; paint a band about 22 texels tall.
static func crowd(x: int, y: int) -> Color:
	var seat := x / 14
	var middle := float(seat * 14 + 7 + int(noise(seat, 1) * 4.0) - 2)
	var head_y := 6.0 + noise(seat, 2) * 4.0
	var head := Vector2((x + 0.5 - middle) / 5.0, (y + 0.5 - head_y - 5.0) / 5.0)
	var tones: Array[Color] = [Color("#3b3550"), Color("#5a3a4a"), Color("#3a4a5a"), Color("#4a3f30")]
	var tone := tones[seat % tones.size()]
	if head.length() < 1.0:
		return rounded(Color("#8a6a5a") if noise(seat, 3) > 0.5 else Color("#6a5048"), head)
	if noise(seat, 4) > 0.55 and absf(x + 0.5 - middle) < 4.0 and y < head_y + 1.0 and y > head_y - 4.0:
		return tone.lightened(0.1)
	if y > head_y + 9.0 and absf(x + 0.5 - middle) < 7.0:
		return grainy(tone, x, y, 0.1)
	return CLEAR
