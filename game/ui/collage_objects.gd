extends RefCounted
## The big menu objects of the collage menus, baked once each as pixel sprites:
## a folded island map, a photo album, a coat on a hanger and a park ticket.
## Names are not baked in; `label_area` says where each object carries its
## printed name, so the text is drawn live in the player's font and size.

const Pixels = preload("res://game/minigames/arcade/arcade_pixels.gd")

## Texels of each object (the bake adds a one-texel outline all round).
const SIZES := {"map": Vector2i(72, 50), "album": Vector2i(60, 50), "hanger": Vector2i(60, 58), "ticket": Vector2i(76, 40)}
## Name sticker (or print area) of each object, as fractions of its sprite.
const LABELS := {"map": Rect2(0.05, 0.62, 0.6, 0.26), "album": Rect2(0.2, 0.66, 0.62, 0.2), "hanger": Rect2(0.16, 0.6, 0.68, 0.22), "ticket": Rect2(0.06, 0.22, 0.66, 0.56)}
## A second, small part of the name (the text after " · "), on the ticket stub.
const NOTES := {"ticket": Rect2(0.77, 0.12, 0.2, 0.36)}

const PAPER := Color("#f6ecd0")
const PAPER_FOLD := Color("#e2cf9f")
const SEA := Color("#8fd3c8")
const SEA_LINE := Color("#6cbcb2")
const SAND := Color("#ecd5a4")
const GRASS := Color("#7cc46a")
const HILL := Color("#4f9a55")
const CORAL := Color("#f08f73")
const DEEP_CORAL := Color("#8d3c33")
const INK := Color("#12303b")
const BRASS := Color("#c9a45a")
const COAT := Color("#2f9a8d")
const CLEAR := Color(0, 0, 0, 0)


static func has(kind: String) -> bool:
	return SIZES.has(kind)


static func aspect(kind: String) -> float:
	var size: Vector2i = SIZES[kind] + Vector2i(2, 2)
	return float(size.x) / size.y


static func sprite(kind: String) -> ImageTexture:
	var paint: Callable
	match kind:
		"map":
			paint = func(x: int, y: int) -> Color: return _map(x, y)
		"album":
			paint = func(x: int, y: int) -> Color: return _album(x, y)
		"hanger":
			paint = func(x: int, y: int) -> Color: return _hanger(x, y)
		_:
			paint = func(x: int, y: int) -> Color: return _ticket(x, y)
	return Pixels.bake("collage|object:" + kind, SIZES[kind], paint)


## White shape of the object, for its shadow and focus rim.
static func silhouette(kind: String) -> ImageTexture:
	return Pixels.cached("collage|silhouette:" + kind, func() -> Image:
		var image := sprite(kind).get_image()
		for y in image.get_height():
			for x in image.get_width():
				if image.get_pixel(x, y).a > 0.0:
					image.set_pixel(x, y, Color.WHITE)
		return image)


## Where the name goes on an object drawn over `body`.
static func label_area(kind: String, body: Rect2, notes := false) -> Rect2:
	var table: Dictionary = NOTES if notes else LABELS
	if not table.has(kind):
		return Rect2()
	var part: Rect2 = table[kind]
	return Rect2(body.position + part.position * body.size, part.size * body.size)


## A map folded in four: each panel shears a little, alternate panels sit in
## shade, and the sea carries two islands, a dotted route and an X.
static func _map(x: int, y: int) -> Color:
	var t := fposmod(float(x), 36.0) / 18.0
	var lip := roundi((t if t < 1.0 else 2.0 - t) * 3.0)
	var row := y - lip
	if row < 0 or row >= 47:
		return CLEAR
	var tone := SEA
	if x < 2 or x > 69 or row < 2 or row > 44:
		tone = PAPER
	else:
		if x % 12 == 0 or row % 12 == 0:
			tone = SEA_LINE
		var island := minf(Vector2((x - 27) / 16.0, (row - 25) / 10.0).length(), Vector2((x - 55) / 8.0, (row - 33) / 6.0).length())
		if island < 1.0:
			tone = SAND if island > 0.74 else (HILL if island < 0.32 else GRASS)
		var route := 15.0 + 5.0 * sin(x / 7.0)
		if absf(row - route) < 1.0 and x % 4 < 2 and x > 8 and x < 52:
			tone = CORAL
		var mark := Vector2i(x - 58, row - 13)
		if absi(mark.x) <= 3 and absi(mark.x) == absi(mark.y):
			tone = DEEP_CORAL
		if (x == 9 and absi(row - 9) <= 3) or (row == 9 and absi(x - 9) <= 3):
			tone = INK
	if int(x / 18.0) % 2 == 1:
		tone = tone.darkened(0.12)
	if x % 18 == 0 and x > 0:
		tone = tone.darkened(0.22)
	return Pixels.grainy(tone, x, y, 0.05, 3)


## A coral photo album seen from the front: stitched spine, brass corners,
## a snapshot taped to the cover and the page block showing behind.
static func _album(x: int, y: int) -> Color:
	var on_cover := x < 55 and y < 45
	if not on_cover:
		if x < 3 or y < 3:
			return CLEAR
		var page := PAPER
		if (x >= 55 and y % 2 == 0) or (y >= 45 and x % 2 == 0):
			page = PAPER_FOLD
		return page
	var cover := Color("#c25b4e")
	var tone := cover
	if x < 7:
		tone = cover.darkened(0.32)
		if x == 3 and y % 4 == 1:
			tone = PAPER
	elif (54 - x) + y < 6 or (54 - x) + (44 - y) < 6 or (x - 7) + y < 5 or (x - 7) + (44 - y) < 5:
		tone = BRASS
	if x >= 17 and x < 45 and y >= 5 and y < 32:
		tone = Color("#fbf7ec")
		if x >= 19 and x < 43 and y >= 7 and y < 26:
			tone = Color("#9fd8d0") if y < 19 else Color("#4f9fc4")
			if Vector2(x - 37, y - 11).length() < 2.8:
				tone = Color("#ffd27a")
			if y >= 15 and absf(x - 25.0) < (y - 14) * 1.5 and y < 21:
				tone = GRASS
	if x >= 26 and x < 37 and y >= 3 and y < 7:
		tone = Color("#f3e6b8")
	return Pixels.grainy(tone, x, y, 0.05, 5)


## A teal coat hung on a brass hanger.
static func _hanger(x: int, y: int) -> Color:
	var cx := x - 29.5
	var side := absf(cx)
	var ring := Vector2(cx, y - 5.0).length()
	if y <= 9 and ring >= 2.4 and ring <= 4.3 and not (cx < 0.0 and y > 5):
		return BRASS
	if side < 1.0 and y >= 8 and y < 13:
		return BRASS
	if y >= 12 and y < 24 and absf((y - 12.0) - side * 0.44) < 0.9 and side < 27.0:
		return BRASS
	if y >= 22 and y < 24 and side < 27.0:
		return BRASS.darkened(0.18)
	if y < 24 or y >= 58:
		return CLEAR
	var body := 13.0 + (y - 24) * 0.14
	var sleeve := 26.0 - (y - 24) * 0.18
	var tone := COAT
	if side <= body:
		var collar := 8.0 - (y - 24) * 0.55
		if side < collar:
			tone = PAPER
		elif side < collar + 3.0 and y < 40:
			tone = COAT.darkened(0.3)
		elif side < 1.0 and (y - 42) % 6 == 0 and y >= 42:
			tone = BRASS
		elif cx < -8.0 and cx > -16.0 and y >= 46 and y < 48:
			tone = COAT.darkened(0.25)
	elif side <= sleeve and y < 47:
		tone = COAT.darkened(0.12) if y < 45 else PAPER
	else:
		return CLEAR
	return Pixels.grainy(tone, x, y, 0.05, 7)


## A park ticket: half-moon notches, a printed double frame, a perforation and
## a coral stub with a barcode.
static func _ticket(x: int, y: int) -> Color:
	if minf(Vector2(x + 0.5, y - 19.5).length(), Vector2(x - 75.5, y - 19.5).length()) < 5.5:
		return CLEAR
	if x >= 56 and x < 58:
		return CLEAR if y % 3 == 1 else Color("#d9a441")
	var stub := x >= 58
	var tone := CORAL if stub else Color("#f2c75c")
	if not stub:
		var inside := x >= 3 and x <= 52 and y >= 3 and y <= 36
		if inside and (x == 3 or x == 52 or y == 3 or y == 36):
			tone = Color("#a0662a")
		elif inside and (x == 5 or x == 50 or y == 5 or y == 34) and (x + y) % 2 == 0 and x >= 5 and x <= 50 and y >= 5 and y <= 34:
			tone = Color("#c9913a")
		for corner: Vector2i in [Vector2i(9, 9), Vector2i(46, 9), Vector2i(9, 30), Vector2i(46, 30)]:
			if (x == corner.x and absi(y - corner.y) <= 1) or (y == corner.y and absi(x - corner.x) <= 1):
				tone = DEEP_CORAL
	elif x >= 61 and x < 73 and y >= 26 and y < 35 and Pixels.noise(x, 0, 7) > 0.42:
		tone = INK
	return Pixels.grainy(tone, x, y, 0.04, 11)
