extends "res://game/minigames/arcade/arcade_view.gd"
## Picture for 彈簧青蛙: a riveted conveyor on the workshop bench carries painted
## letter blocks out of a timber tunnel toward a toy bin; the tin frog with its
## butterfly key hops along them, a brass gauge shows the wind, and a crane on a
## rail fishes the frog back up after a miss. Every object is baked pixel art
## (arcade_pixels.gd) in the backdrop's dusky palette.

const YARD_ART := "res://assets/world/toy-clockwork-yard.webp"
const FLOOR_TOP := 618.0
const BELT_BAND := 16.0
const SKIRT := Rect2(0, 574, 1280, 40)
const BIN := Vector2(-8, 436)
const TUNNEL := Vector2(1150, 380)
const RAIL_Y := 168.0
const CLAW_PARK := 1080.0
const FROG_SIZE := Vector2i(26, 19)
## Texel of the frog sprite that sits on the frog's foot point.
const FROG_FOOT := Vector2(13, 18)
const FROG_SCALE := 4.0
## Block sprites: a 3-texel lit top face over a 16-texel front.
const BLOCK_TEXELS := 19
const BLOCK_LID := 3.0 * 4.0
const WOOD := Color("#7a5238")
const BENCH := Color("#7a5238")
const RUBBER := Color("#3b3135")
const STEEL := Color("#66574f")
const BRASS := Color("#c9953e")
const PAPER := Color("#e9d8b0")
const DARK := Color("#2b2440")
const TIN := Color("#7fa25a")
const TIN_DARK := Color("#4f6f3c")
const BELLY := Color("#e6d4a4")
const HAZARD := Color("#d9a63e")
const SPRING_RED := Color("#b4553f")
const PAINTS: Array[Color] = [Color("#5b8f80"), Color("#ad573f"), Color("#c4904a"), Color("#6a7aa0")]
## 5 x 5 glyphs for the block faces: A, B, C and a star.
const GLYPHS: Array[String] = [
	".###.#...#######...##...#", "####.#...#####.#...#####.", ".#####....#....#.....####", "..#...###.#####.###..#.#.",
]
## Scene light: a touch of the workshop's dusk on every sprite.
const DUSK := Color(1.0, 0.93, 0.86)

var _has_art := false
## Sprites, baked once in _ready() or on first use (blocks come in a few widths).
var _frog: Dictionary = {}
var _key: ImageTexture
var _belt: ImageTexture
var _skirt: ImageTexture
var _bin: ImageTexture
var _tunnel: ImageTexture
var _spring: ImageTexture
var _claw: Array[ImageTexture] = []
var _dial: ImageTexture
var _trolley: ImageTexture


func _init() -> void:
	super()
	word_anchor = Vector2(640, 300)


func _ready() -> void:
	_has_art = use_backdrop_art(YARD_ART, Rect2(0, 20, 1157, 651), Color(0.6, 0.54, 0.6))
	for pose: String in ["sit", "leap", "dizzy"]:
		_frog[pose] = Pixels.bake("frog|%s" % pose, FROG_SIZE, _paint_frog.bind(pose))
	_key = Pixels.bake("frog-key", Vector2i(9, 11), _paint_key)
	_belt = Pixels.bake("frog-belt", Vector2i(336, int(BELT_BAND / TEXEL) + 1), _paint_belt)
	_skirt = Pixels.bake("frog-skirt", Vector2i(320, int(SKIRT.size.y / TEXEL)), _paint_skirt)
	_bin = Pixels.bake("frog-bin", Vector2i(50, 42), _paint_bin)
	_tunnel = Pixels.bake("frog-tunnel", Vector2i(36, 50), _paint_tunnel)
	_spring = Pixels.bake("frog-spring", Vector2i(18, 9), _paint_spring)
	for closed: bool in [false, true]:
		_claw.append(Pixels.bake("frog-claw|%s" % closed, Vector2i(15, 12), _paint_claw.bind(closed)))
	_dial = Pixels.bake("frog-dial", Vector2i(21, 12), _paint_dial)
	_trolley = Pixels.bake("frog-trolley", Vector2i(14, 7), func(x: int, y: int) -> Color:
		return Pixels.metal(STEEL.darkened(0.1), x, y) if y > 1 or (x > 2 and x < 11) else Pixels.CLEAR)


func _draw_backdrop() -> void:
	if not _has_art:
		draw_rect(Rect2(Vector2.ZERO, DESIGN), Color("#3a2c2a"))
	bench(FLOOR_TOP, BENCH)
	vignette()


func _draw_scene() -> void:
	var belt_y := float(state.get("belt_y", 560.0))
	var top_y := float(state.get("top_y", 496.0))
	_draw_crane_rail()
	_draw_conveyor(belt_y)
	var blocks: Array = state.get("blocks", [])
	for block: Dictionary in blocks:
		_draw_block(block, belt_y, top_y)
	stamp(_tunnel, TUNNEL, TEXEL, DUSK)
	label(TUNNEL + Vector2(72, 44), "積木出口", 17, DARK, 1.0, 1.0, false)
	var frog: Dictionary = state.get("frog", {})
	_draw_frog(frog, belt_y, top_y)
	cast_shadow(_bin, BIN, Vector2(10, 10), TEXEL, 0.25)
	stamp(_bin, BIN, TEXEL, DUSK)
	label(BIN + Vector2(104, 90), "玩具箱", 22, DARK, 1.0, 1.0, false)
	_draw_claw(frog)
	_draw_streak()


# --- Belt and blocks --------------------------------------------------------

func _draw_conveyor(belt_y: float) -> void:
	# Legs down to the bench, then the moving rubber and the riveted skirt over the rollers.
	for leg_x: float in [260.0, 640.0, 1020.0]:
		draw_rect(Rect2(leg_x - 9.0, SKIRT.end.y - 4.0, 18, FLOOR_TOP - SKIRT.end.y + 10.0), DARK.lightened(0.05))
		draw_rect(Rect2(leg_x - 5.0, SKIRT.end.y - 4.0, 6, FLOOR_TOP - SKIRT.end.y + 6.0), STEEL.darkened(0.25))
		ground_shadow(Vector2(leg_x, FLOOR_TOP + 8.0), Vector2(30, 6), 0.35)
	var travel := float(state.get("belt_travel", 0.0))
	var shift := fposmod(travel, 32.0)
	stamp(_belt, Vector2(-shift, belt_y - 6.0), TEXEL, DUSK)
	stamp(_skirt, SKIRT.position + Vector2(0, belt_y + BELT_BAND - SKIRT.position.y), TEXEL, DUSK)
	# Roller hubs turn with the belt.
	var turn := travel / 22.0
	for hub_x: float in [96.0, 352.0, 608.0, 864.0, 1120.0]:
		var hub := Vector2(hub_x, belt_y + BELT_BAND + 20.0)
		draw_circle(hub, 13.0, DARK)
		draw_circle(hub, 10.0, STEEL.lightened(0.1))
		var spoke := Vector2.from_angle(-turn) * 8.0
		draw_line(hub - spoke, hub + spoke, DARK, 3.0)
		draw_line(hub - spoke.orthogonal(), hub + spoke.orthogonal(), DARK, 3.0)
		draw_rect(Rect2(hub - Vector2(7, 9), Vector2(4, 3)), Color(1, 0.95, 0.85, 0.5))


func _block_art(width: float, paint: int, letter: int, kind: String) -> ImageTexture:
	var texels := Vector2i(int(width / TEXEL), BLOCK_TEXELS)
	return Pixels.bake("frog-block|%d|%d|%d|%s" % [texels.x, paint, letter, kind], texels, _paint_block.bind(texels, PAINTS[paint % PAINTS.size()], GLYPHS[letter % GLYPHS.size()], kind))


func _draw_block(block: Dictionary, belt_y: float, top_y: float) -> void:
	var width := float(block.w)
	var x := float(block.x)
	if x + width * 0.5 < -20.0 or x - width * 0.5 > DESIGN.x + 20.0:
		return
	var kind := str(block.kind)
	var art := _block_art(width, int(block.paint), int(block.letter), kind)
	var sink := float(block.get("sink", 0.0))
	var height := belt_y - top_y
	var left := x - width * 0.5
	# A retracting block shivers just before it drops into its slot.
	if bool(block.get("warn", false)) and not reduced_motion:
		left += sin(now * 70.0) * 2.0
	if kind == "retract":
		draw_rect(Rect2(left - 2.0, belt_y - 2.0, width + 4.0, 8.0), DARK)
	if sink >= 0.98:
		return
	var shown := height * (1.0 - sink)
	ground_shadow(Vector2(x + 8.0, belt_y + 3.0), Vector2(width * 0.55, 6), 0.32)
	var size := Vector2(art.get_size()) * TEXEL
	var rows := ceilf((shown + BLOCK_LID) / TEXEL) + 1.0
	draw_texture_rect_region(art, Rect2(left - TEXEL, belt_y - shown - BLOCK_LID - TEXEL, size.x, rows * TEXEL), Rect2(0, 0, art.get_size().x, rows), DUSK)
	if kind == "spring" and sink <= 0.0:
		var bounce := 0.0
		var frog: Dictionary = state.get("frog", {})
		if bool(frog.get("sprung", false)):
			bounce = 1.0 - clampf(age(float(frog.get("hop_at", -99.0))) / 0.3, 0.0, 1.0)
		var spring_at := Vector2(x - 36.0, top_y - BLOCK_LID * 0.5 - 36.0 - 18.0 * bounce)
		draw_set_transform(spring_at + Vector2(36, 36), 0.0, Vector2(1.0, 1.0 + 0.5 * bounce))
		stamp(_spring, Vector2(-36, -36), TEXEL, DUSK)
		draw_set_transform(Vector2.ZERO)


# --- Frog -------------------------------------------------------------------

func _draw_frog(frog: Dictionary, belt_y: float, top_y: float) -> void:
	if frog.is_empty():
		return
	var mode := str(frog.state)
	# Feet stand on the middle of a block's lit top face.
	var foot := Vector2(float(frog.x), float(frog.y) - (0.0 if mode == "fall" else BLOCK_LID * 0.5))
	var pose := "sit"
	var stretch := Vector2.ONE
	var turn := 0.0
	var key_spin := 0.0
	var charge := float(frog.get("charge", 0.0))
	match mode:
		"wind":
			stretch = Vector2(1.0 + 0.16 * charge, 1.0 - 0.24 * charge)
			key_spin = charge * 9.0
			if charge >= 1.0 and not reduced_motion:
				foot.x += sin(now * 60.0) * 1.5
		"hop":
			pose = "leap"
			var t := clampf(age(float(frog.hop_at)) / 0.5, 0.0, 1.0)
			turn = lerpf(-0.35, 0.3, t) if not reduced_motion else 0.0
			key_spin = -t * 4.0
		"fall":
			pose = "dizzy"
			var since := age(float(frog.fall_at))
			if bool(frog.get("bin", false)):
				turn = PI * 0.8
			else:
				# Belly up on the belt, spinning round while the key whirrs itself loose.
				turn = PI
				if not reduced_motion:
					var spin := cos(since * (18.0 - since * 8.0))
					stretch = Vector2(signf(spin) * maxf(0.2, absf(spin)), 1.0)
					key_spin = since * 40.0
			dust_puffs(foot, since, 70.0)
		"claw":
			pose = "dizzy"
		"sit":
			var landed := age(float(frog.get("landed_at", -99.0)))
			stretch = squash(landed, 0.3, 0.32)
			dust_puffs(foot, landed, 36.0)
	if mode != "fall" or not bool(frog.get("bin", false)):
		var lift := maxf(0.0, (top_y if mode != "fall" else belt_y) - foot.y)
		ground_shadow(Vector2(foot.x + 6.0, (belt_y if mode == "fall" else top_y - BLOCK_LID * 0.5) + 2.0), Vector2(40.0 - minf(lift * 0.1, 24.0), 7), 0.4 - minf(lift * 0.001, 0.2))
	var sprite: ImageTexture = _frog[pose]
	var pivot := foot - Vector2(0, FROG_SIZE.y * FROG_SCALE * 0.45) if mode == "fall" else foot
	draw_set_transform(pivot, turn, stretch)
	var anchor := FROG_FOOT * FROG_SCALE if mode != "fall" else (FROG_FOOT - Vector2(0, FROG_SIZE.y * 0.45)) * FROG_SCALE
	stamp(sprite, -anchor, FROG_SCALE, DUSK)
	# The butterfly key on its back: its width narrows as it turns.
	var key_at := Vector2(-40, -54) - (anchor - FROG_FOOT * FROG_SCALE)
	var face := cos(key_spin)
	draw_set_transform(pivot + key_at.rotated(turn) * stretch, turn, Vector2(maxf(0.18, absf(face)), 1.0) * stretch)
	stamp(_key, Vector2(-18, -22), TEXEL, DUSK.darkened(0.0 if face > 0.0 else 0.2))
	draw_set_transform(Vector2.ZERO)
	if mode == "wind":
		_draw_gauge(foot, charge)
	if mode == "fall" and age(float(frog.fall_at)) > 0.25:
		label(foot + Vector2(0, -96), "嘰嘰嘰…", 22, PAPER, 1.0, 1.0 - clampf((age(float(frog.fall_at)) - 1.0) / 0.3, 0.0, 1.0))


## A brass dial above the frog: the needle sweeps from a short hop to a long one.
func _draw_gauge(foot: Vector2, charge: float) -> void:
	var at := foot + Vector2(-42, -150)
	cast_shadow(_dial, at, Vector2(6, 8), TEXEL, 0.22)
	stamp(_dial, at, TEXEL, DUSK)
	var pivot := at + Vector2(42, 42)
	var needle := Vector2.from_angle(PI + charge * PI) * 30.0
	draw_line(pivot + Vector2(2, 2), pivot + needle + Vector2(2, 2), Color(0, 0, 0, 0.3), 5.0)
	draw_line(pivot, pivot + needle, SPRING_RED.darkened(0.3), 5.0)
	draw_line(pivot, pivot + needle, SPRING_RED.lightened(0.2), 2.0)
	draw_rect(Rect2(pivot - Vector2(5, 5), Vector2(10, 10)), DARK)
	draw_rect(Rect2(pivot - Vector2(3, 3), Vector2(4, 4)), BRASS)
	if charge >= 1.0:
		glint(pivot - Vector2(0, 12), 34.0, 0.9)
		label(at + Vector2(42, -18), "滿了！", 18, GOLD, 1.0 + 0.1 * pulse(3.0))


# --- Crane ------------------------------------------------------------------

func _draw_crane_rail() -> void:
	draw_rect(Rect2(0, RAIL_Y - 6.0, DESIGN.x, 14), DARK)
	draw_rect(Rect2(0, RAIL_Y - 4.0, DESIGN.x, 8), STEEL.darkened(0.2))
	draw_rect(Rect2(0, RAIL_Y - 4.0, DESIGN.x, 2), STEEL.lightened(0.15))
	var x := 24.0
	while x < DESIGN.x:
		draw_rect(Rect2(x, RAIL_Y - 2.0, 4, 4), BRASS.darkened(0.2))
		x += 64.0


func _draw_claw(frog: Dictionary) -> void:
	var mode := str(frog.get("state", ""))
	var hang := Vector2(CLAW_PARK, RAIL_Y + 60.0)
	var closed := false
	if mode == "claw":
		hang = Vector2(float(frog.x), float(frog.y) - 70.0)
		closed = age(float(frog.claw_at)) < 0.55
	elif mode == "fall" and age(float(frog.fall_at)) > 0.7:
		# The crane rolls over and drops its hook toward the frog.
		var t := clampf((age(float(frog.fall_at)) - 0.7) / 0.6, 0.0, 1.0)
		var reach := Vector2(float(frog.x), float(frog.y) - 70.0)
		hang = Vector2(CLAW_PARK, RAIL_Y + 60.0).lerp(reach, smoothstep(0.0, 1.0, t))
	stamp(_trolley, Vector2(hang.x - 28.0, RAIL_Y - 12.0), TEXEL, DUSK)
	draw_line(Vector2(hang.x, RAIL_Y + 14.0), hang + Vector2(0, -20), DARK, 5.0)
	draw_line(Vector2(hang.x, RAIL_Y + 14.0), hang + Vector2(0, -20), STEEL.lightened(0.1), 2.0)
	stamp(_claw[int(closed)], hang - Vector2(30, 24), TEXEL, DUSK)



func _draw_streak() -> void:
	var streak := int(state.get("streak", 0))
	if streak < 2:
		return
	label(Vector2(200, 236), "連跳 × %d" % streak, 26, GOLD, 1.0 + 0.08 * pulse(2.0))


# --- Texel painters ---------------------------------------------------------

func _paint_frog(x: int, y: int, pose: String) -> Color:
	var at := Vector2(x + 0.5, y + 0.5)
	var leap := pose == "leap"
	# Back leg: folded under the body, or kicked out behind in a leap.
	var thigh := (at - (Vector2(5.5, 12.5) if not leap else Vector2(3.5, 14.0))) / (Vector2(4.6, 3.8) if not leap else Vector2(4.4, 2.2))
	var foot_back := Rect2(1, 16, 9, 2) if not leap else Rect2(0, 15, 3, 4)
	var front := Rect2(17, 13, 2, 4) if not leap else Rect2(19, 14, 3, 2)
	var foot_front := Rect2(16, 16, 6, 2) if not leap else Rect2(21, 15, 4, 2)
	var body := (at - Vector2(12.0, 10.5)) / Vector2(9.0, 6.2)
	var head := (at - Vector2(18.5, 8.5)) / Vector2(6.0, 4.8)
	var eye := at - Vector2(17.5, 4.0)
	if eye.length() < 3.1:
		if pose == "dizzy":
			var local := Vector2i(x - 15, y - 2)
			if local.x >= 0 and local.x <= 4 and local.y >= 0 and local.y <= 4 and (local.x == local.y or local.x + local.y == 4):
				return DARK
			return PAPER
		if eye.length() > 2.3:
			return TIN_DARK
		return DARK if (at - Vector2(18.6, 4.2)).length() < 1.3 else PAPER
	if body.length() <= 1.0 or head.length() <= 1.0:
		var shade := Pixels.rounded(TIN, body if body.length() <= 1.0 else head)
		# Belly plate, a pressed seam with rivets, and the painted mouth.
		if at.y > 13.0 and at.x > 9.0 and at.x < 21.0:
			return Pixels.grainy(BELLY, x, y, 0.08)
		if y == 11 and x >= 20:
			return SPRING_RED.darkened(0.3)
		if x == 11 and y > 4 and y < 15:
			return BRASS.lightened(0.1) if y % 3 == 0 else TIN_DARK
		if (at - Vector2(7.0, 7.0)).length() < 1.6 or (at - Vector2(14.0, 6.5)).length() < 1.1:
			return TIN_DARK.lightened(0.15)
		return Pixels.grainy(shade, x, y, 0.06)
	if thigh.length() <= 1.0:
		return Pixels.rounded(TIN.darkened(0.12), thigh)
	if foot_back.has_point(at) or foot_front.has_point(at):
		return Pixels.grainy(TIN_DARK, x, y, 0.1)
	if front.has_point(at):
		return TIN.darkened(0.2)
	return Pixels.CLEAR


func _paint_key(x: int, y: int) -> Color:
	var at := Vector2(x + 0.5, y + 0.5)
	if y >= 7:
		return Pixels.metal(BRASS.darkened(0.15), x, y) if x >= 3 and x <= 5 else Pixels.CLEAR
	for lobe: float in [2.2, 6.8]:
		var offset := (at - Vector2(lobe, 3.5)) / 2.6
		if offset.length() <= 1.0:
			return BRASS.darkened(0.45) if offset.length() < 0.35 else Pixels.rounded(BRASS, offset)
	return Pixels.metal(BRASS, x, y) if x >= 3 and x <= 5 and y >= 2 else Pixels.CLEAR


func _paint_block(x: int, y: int, texels: Vector2i, paint: Color, glyph: String, kind: String) -> Color:
	var right := texels.x - 1
	var raw := Color("#c8a676").darkened(0.1)
	# The lit top face, seen a little from above, with end grain at its corners.
	if y < 3:
		if x < 2 or x > right - 2:
			return Pixels.grainy(raw.lightened(0.12), x, y, 0.12)
		return Pixels.wood(paint.lightened(0.28), x, y, 9, false)
	if y == 3:
		return paint.darkened(0.42)
	var front := y - 4
	if kind == "retract" and front >= 12:
		return HAZARD.darkened(0.1) if (x + y) % 4 < 2 else DARK.lightened(0.15)
	# Raw wooden rims, a painted panel and a raised letter with its own shadow.
	if x < 2 or x > right - 2 or front > 13:
		return Pixels.wood(raw, x, y, 5, true)
	var middle := texels.x / 2
	var glyph_at := Vector2i(x - (middle - 2), front - 4)
	var lit := glyph_at.x >= 0 and glyph_at.x < 5 and glyph_at.y >= 0 and glyph_at.y < 5 and glyph[glyph_at.y * 5 + glyph_at.x] == "#"
	if lit:
		return PAPER.darkened(0.08)
	var under := glyph_at - Vector2i(1, 1)
	if under.x >= 0 and under.x < 5 and under.y >= 0 and under.y < 5 and glyph[under.y * 5 + under.x] == "#":
		return paint.darkened(0.38)
	var inside := Pixels.grainy(paint, x, y, 0.12)
	if front == 0 or x == 2:
		return inside.darkened(0.25)
	return inside.darkened(0.12) if front > 10 else inside


func _paint_belt(x: int, y: int) -> Color:
	if y == 0:
		return RUBBER.lightened(0.3)
	# Cleats every eight texels; the band darkens toward its front edge.
	if x % 8 == 0 or x % 8 == 1 and y > 1:
		return RUBBER.darkened(0.45)
	return Pixels.grainy(RUBBER.lightened(0.1).darkened(0.08 * y), x, y, 0.14)


func _paint_skirt(x: int, y: int) -> Color:
	# A pressed steel side: lit lip, panels with seams and rivets, a rusty lower edge.
	if y == 0:
		return STEEL.lightened(0.3)
	if y == 1:
		return STEEL.darkened(0.4)
	if y >= 8:
		return Pixels.grainy(Color("#5a3f33"), x, y, 0.2) if y == 8 else STEEL.darkened(0.5)
	if x % 64 == 0:
		return STEEL.darkened(0.45)
	if x % 64 == 1:
		return STEEL.lightened(0.12)
	if (x % 64 == 4 or x % 64 == 60) and (y == 3 or y == 6):
		return BRASS.lightened(0.05)
	var tone := Pixels.metal(STEEL, x, y)
	return tone.darkened(0.12) if y > 5 else tone


func _paint_bin(x: int, y: int) -> Color:
	var at := Vector2(x + 0.5, y + 0.5)
	# A slatted crate, its far rim showing above the front boards.
	if y < 4:
		return Pixels.wood(WOOD.darkened(0.35), x, y, 7, false) if x > 1 and x < 48 else Pixels.CLEAR
	if x < 3 or x > 46:
		return Pixels.wood(WOOD.darkened(0.15), x, y, 3, true)
	if y < 6:
		return WOOD.lightened(0.15)
	if (y - 6) % 9 == 0:
		return WOOD.darkened(0.45)
	if Rect2(10, 17, 30, 10).has_point(at):
		return Pixels.grainy(PAPER.darkened(0.08), x, y, 0.1) if Rect2(11, 18, 28, 8).has_point(at) else DARK.lightened(0.2)
	if (x == 6 or x == 43) and (y - 6) % 9 == 4:
		return BRASS
	return Pixels.wood(WOOD, x, y, 9, false)


func _paint_tunnel(x: int, y: int) -> Color:
	var at := Vector2(x + 0.5, y + 0.5)
	var arch := (at - Vector2(18.0, 30.0)) / Vector2(13.0, 16.0)
	if at.y > 30.0 and absf(at.x - 18.0) < 13.0 or arch.length() < 1.0:
		return Color("#1d1420").lightened(0.04 * (50.0 - at.y) / 20.0) if at.y < 49.0 else Pixels.CLEAR
	if y < 6:
		return Pixels.shingle(Color("#7a3f38"), x, y, 5, 3)
	if Rect2(4, 8, 28, 6).has_point(at):
		return Pixels.grainy(PAPER.darkened(0.1), x, y, 0.08)
	if arch.length() < 1.2:
		return Pixels.grainy(BRASS.darkened(0.1), x, y, 0.1) if int(arch.angle() * 6.0) % 2 == 0 else Pixels.wood(WOOD.lightened(0.1), x, y, 4)
	return Pixels.wood(WOOD.darkened(0.05), x, y, 6)


func _paint_spring(x: int, y: int) -> Color:
	if y < 2:
		return Pixels.grainy(SPRING_RED, x, y, 0.1) if x > 1 and x < 16 else Pixels.CLEAR
	if y > 7:
		return Pixels.metal(STEEL, x, y) if x > 1 and x < 16 else Pixels.CLEAR
	var coil := (x + y * 2) % 6
	if x > 4 and x < 13 and coil < 2:
		return Pixels.metal(Color("#b8b0a4"), x, y)
	return Pixels.CLEAR


func _paint_claw(x: int, y: int, closed: bool) -> Color:
	if y < 4:
		return Pixels.metal(STEEL, x, y) if x > 3 and x < 11 else Pixels.CLEAR
	var reach := 2 if closed else 0
	for side: int in [0, 1]:
		var inner := 5 - reach if side == 0 else 9 + reach
		var tip := 1 + reach if side == 0 else 13 - reach
		var along := clampf((y - 4.0) / 7.0, 0.0, 1.0)
		var at := lerpf(inner, tip, along) if y < 9 else lerpf(tip, inner, (y - 9.0) / 3.0)
		if absf(x - at) < 1.2:
			return Pixels.metal(BRASS.darkened(0.1), x, y)
	return Pixels.CLEAR


func _paint_dial(x: int, y: int) -> Color:
	var at := Vector2(x + 0.5, y + 0.5)
	var offset := (at - Vector2(10.5, 11.0)) / 10.5
	if offset.length() > 1.0 or at.y > 12.0:
		return Pixels.CLEAR
	if offset.length() > 0.82:
		return Pixels.rounded(BRASS, offset)
	var angle := fposmod(offset.angle(), TAU)
	if offset.length() > 0.62:
		# Green for short hops shading to red for the longest.
		var share := clampf((angle - PI) / PI, 0.0, 1.0)
		return Color("#6f9a5a").lerp(SPRING_RED, share)
	return Pixels.grainy(PAPER, x, y, 0.06)
