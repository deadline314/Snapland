extends RefCounted
## Bakes chunky pixel-art sprites for arcade views, once each.
##
## A view describes an object texel by texel (shape tests plus the material
## helpers below); the baker then adds what makes it sit in a painted scene: a
## lit top-left edge, a shaded lower-right edge and a one-texel outline in a
## deepened local colour. Views draw the result with nearest filtering through
## `arcade_view.stamp()`. See 畫面下限 in design/00-principles/simple-fun-minigames.md.

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
