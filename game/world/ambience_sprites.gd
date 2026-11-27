extends RefCounted
## Hand-authored pixel frames for ambience critters and air motes.
## Bitmaps are rows of palette characters; '.' is transparent. Frames are
## bottom-aligned and centred in their atlas cell, so a critter's feet sit on
## the bottom edge of its quad.

const CELL := Vector2i(40, 16)
const COLUMNS := 4

# Outlines are a deep slate taken from each animal's own shadow tone, never black.
const PALETTE := {
	"o": Color("#3f4858"), # outline
	"B": Color("#8f9cab"), # pigeon body
	"D": Color("#66738a"), # pigeon wing
	"H": Color("#5b6880"), # pigeon head
	"G": Color("#6f9a8d"), # neck sheen
	"L": Color("#c3ccd4"), # belly
	"K": Color("#e6b56c"), # beak
	"F": Color("#d07b6a"), # feet
	"e": Color("#262b36"), # eye
	"S": Color("#a87f58"), # sparrow back
	"T": Color("#7a593f"), # sparrow wing
	"C": Color("#e7d6b6"), # sparrow chest
	"W": Color("#f4f2ea"), # gull white
	"A": Color("#a9b6c4"), # gull wing grey
	"m": Color("#6b7686"), # gull wing tip and soft outline
	"Y": Color("#f0c463"), # gull beak
	"P": Color("#ffffff"), # butterfly wing (tinted per instance)
	"p": Color("#d9d9d9"), # butterfly wing shade
	"b": Color("#4a4250"), # butterfly body
}

# One row per animal; columns are that animal's frames.
const CRITTER_ROWS := {
	"pigeon": 0, "sparrow": 1, "gull": 2, "butterfly": 3,
}

# Ground birds: stand, peck, wings up, wings down. Gull: glide, up, down.
# Butterfly: open, half, closed.
# Animals listed in MIRRORED are drawn as a left half plus the centre column.
const MIRRORED := ["gull"]
const CRITTER_FRAMES := {
	"pigeon": [
		[
			".......ooo..",
			"......oHHHo.",
			"......oHeHKK",
			"..ooooGGHo..",
			".oBBBBBBLo..",
			"oBDDDDBBLo..",
			"oDDDDDBLLo..",
			".oooBBLLo...",
			"....oooo....",
			"....F..F....",
		],
		[
			"..ooooo.....",
			".oBBBBBoo...",
			"oBDDDDBBGo..",
			"oDDDDDBLGHo.",
			".oooBBLLHHo.",
			"....ooooHeo.",
			"....F..FoKo.",
			".........K..",
		],
		[
			"...oo.......",
			"..oDDo......",
			"..oDDDo.ooo.",
			"...oDDDoHHHo",
			"...oDDDoHeHK",
			".oooBDDGGHo.",
			"oBBBBBBBLo..",
			".ooBBBLLo...",
			"...ooooo....",
		],
		[
			".......ooo..",
			"......oHHHo.",
			".oooooGHeHKK",
			"oBBBBBBGHo..",
			".ooBDDDLLo..",
			"..oDDDDoo...",
			"..oDDDo.....",
			"...oDo......",
			"....o.......",
		],
	],
	"sparrow": [
		[
			".....ooo.",
			"....oSSSo",
			"....oSeSK",
			".oooSSCo.",
			"oTTTSCCo.",
			"oTTTCCo..",
			".oooooo..",
			"...F.F...",
		],
		[
			".ooo.....",
			"oTTToo...",
			"oTTTSSo..",
			".ooCCSSo.",
			"...ooSeo.",
			"...F.FK..",
		],
		[
			"..oo.....",
			".oTTo.oo.",
			".oTTToSSo",
			"..oTTSeSK",
			".ooSSCCo.",
			"oSSCCCo..",
			".ooooo...",
		],
		[
			".....ooo.",
			".ooooSSSo",
			"oSSSSSeSK",
			".oTTTCCo.",
			".oTTToo..",
			"..oTo....",
			"...o.....",
		],
	],
	"gull": [
		[
			"..mmmm..............",
			".mAAAAmmmm..........",
			"mAAAAWWWWWmmmm......",
			".mmmAWWWWWWWWWmmmmmm",
			"....mmmmWWWWWWWWWWWW",
			"........mmmmWWWWWWWW",
			"............mmmWWeWW",
			"...............mWWWY",
			"................mmmm",
		],
		[
			"mmm.................",
			"mAAmm...............",
			"mAAAAmm.............",
			".mAAAWWmm...........",
			"..mmAWWWWmm.........",
			"....mmWWWWWmm.......",
			"......mmWWWWWmm.....",
			"........mmWWWWWmmmmm",
			"..........mmWWWWWWWW",
			"............mmWWWeWW",
			"..............mWWWWY",
			"...............mmmmm",
		],
		[
			"..............mmmmmm",
			"..........mmmmWWWeWW",
			"......mmmmWWWWWWWWWY",
			"...mmmWWWWWWWWWWmmmm",
			".mmAWWWWWWWmmmm.....",
			"mAAAWWWmmmm.........",
			"mAAAmmm.............",
			".mmm................",
		],
	],
	"butterfly": [
		[
			".oo.....oo.",
			"oPPo...oPPo",
			"oPPPo.oPPPo",
			".oPPPbPPPo.",
			"..oPPbPPo..",
			".oppPbPppo.",
			".opppbpppo.",
			"..ooo.ooo..",
		],
		[
			"...o...o...",
			"..oPo.oPo..",
			"..oPPbPPo..",
			"..oPPbPPo..",
			"..oppbppo..",
			"...oo.oo...",
		],
		[
			"....ooo....",
			"...oPPPo...",
			"...oPPPo...",
			"...oPPbo...",
			"...oppbo...",
			"....oob....",
		],
	],
}

# Greyscale glyphs for air motes; '#' is opaque, '+' and ':' are softer rims.
const MOTE_ALPHA := {"#": 1.0, "+": 0.55, ":": 0.25}
const MOTES := {
	"dot": [
		"##",
		"##",
	],
	"petal": [
		".##",
		"###",
		"##.",
	],
	"leaf": [
		"..##",
		".###",
		"###.",
		"#...",
	],
	"glow": [
		"..:::..",
		".:+++:.",
		":+###+:",
		":+###+:",
		":+###+:",
		".:+++:.",
		"..:::..",
	],
	"spark": [
		"..+..",
		"..#..",
		"+###+",
		"..#..",
		"..+..",
	],
	"puff": [
		".:++:.",
		":+##+:",
		"+####+",
		"+####+",
		":+##+:",
		".:++:.",
	],
}

const SHADOW_PIXELS := 16
const SHADOW_TONE := Color(0.10, 0.15, 0.19, 0.44)

static var _atlas: ImageTexture
static var _shadow: ImageTexture
static var _motes: Dictionary = {}


static func critter_atlas() -> ImageTexture:
	if _atlas != null:
		return _atlas
	var image := Image.create(CELL.x * COLUMNS, CELL.y * CRITTER_ROWS.size(), false, Image.FORMAT_RGBA8)
	for kind: String in CRITTER_FRAMES:
		var frames: Array = CRITTER_FRAMES[kind]
		for column in range(mini(frames.size(), COLUMNS)):
			var rows: Array = frames[column]
			if MIRRORED.has(kind):
				rows = rows.map(func(row: String) -> String: return row + row.left(-1).reverse())
			_stamp(image, rows, Vector2i(column * CELL.x, int(CRITTER_ROWS[kind]) * CELL.y))
	_atlas = ImageTexture.create_from_image(image)
	return _atlas


## Soft round ground shadow shared by every animal.
static func shadow_blob() -> ImageTexture:
	if _shadow != null:
		return _shadow
	var image := Image.create(SHADOW_PIXELS, SHADOW_PIXELS, false, Image.FORMAT_RGBA8)
	var half := SHADOW_PIXELS * 0.5
	for y in range(SHADOW_PIXELS):
		for x in range(SHADOW_PIXELS):
			var reach := (Vector2(x, y) + Vector2(0.5, 0.5) - Vector2(half, half)).length() / half
			image.set_pixel(x, y, Color(SHADOW_TONE, SHADOW_TONE.a * (1.0 - smoothstep(0.3, 1.0, reach))))
	_shadow = ImageTexture.create_from_image(image)
	return _shadow


static func critter_row(kind: String) -> int:
	return int(CRITTER_ROWS.get(kind, 0))


static func cell_uv() -> Vector2:
	return Vector2(1.0 / COLUMNS, 1.0 / CRITTER_ROWS.size())


static func mote(glyph: String) -> ImageTexture:
	if _motes.has(glyph):
		return _motes[glyph]
	var rows: Array = MOTES.get(glyph, MOTES["dot"])
	if not MOTES.has(glyph):
		push_warning("Ambience mote glyph '%s' is not authored; using a dot." % glyph)
	var image := Image.create(String(rows[0]).length(), rows.size(), false, Image.FORMAT_RGBA8)
	for y in range(rows.size()):
		var row := String(rows[y])
		for x in range(mini(row.length(), image.get_width())):
			image.set_pixel(x, y, Color(1, 1, 1, float(MOTE_ALPHA.get(row[x], 0.0))))
	var texture := ImageTexture.create_from_image(image)
	_motes[glyph] = texture
	return texture


static func mote_pixels(glyph: String) -> int:
	var rows: Array = MOTES.get(glyph, MOTES["dot"])
	return String(rows[0]).length()


static func _stamp(image: Image, rows: Array, cell_origin: Vector2i) -> void:
	var width := 0
	for row: String in rows:
		width = maxi(width, row.length())
	if width > CELL.x or rows.size() > CELL.y:
		push_warning("Ambience critter frame is larger than its %dx%d cell and was clipped." % [CELL.x, CELL.y])
	var left := cell_origin.x + maxi(0, (CELL.x - width) / 2)
	var top := cell_origin.y + maxi(0, CELL.y - rows.size())
	for y in range(mini(rows.size(), CELL.y)):
		var row := String(rows[y])
		for x in range(mini(row.length(), CELL.x)):
			if PALETTE.has(row[x]):
				image.set_pixel(left + x, top + y, PALETTE[row[x]])
