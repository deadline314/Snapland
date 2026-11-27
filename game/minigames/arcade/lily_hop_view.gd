extends "res://game/minigames/arcade/arcade_view.gd"
## Picture for 睡蓮踏浪: the greenhouse pond seen from the bank in afternoon sun,
## three lanes of lily pads between a mossy near bank and the far landing, the
## visitor in a straw hat hopping pad to pad, pads going under, the bouncy pad,
## the dunk and the frog that rides home on the visitor's head. Everything is
## baked pixel art (arcade_pixels.gd, arcade_hero.gd); the pond palette follows
## the garden world.

const Hero = preload("res://game/minigames/arcade/arcade_hero.gd")
## Screen pixels per hero texel: the hero is drawn at half the scene's texel.
const HERO_SCALE := 2.0
const LANE_TOP := 304.0
const LANE_GAP := 116.0
const FIRST_X := 196.0
const COLUMN_GAP := 138.0
const NEAR_X := 78.0
const FAR_X := 1176.0
const HOP_HEIGHT := 70.0
const BOUNCE_HEIGHT := 170.0
const WATER := Color("#2c6a66")
const DEEP := Color("#1f4d50")
const GLINT := Color("#a8dccb")
const PAD := Color("#5c9c62")
const PAD_DARK := Color("#3f7f52")
const BOUNCER := Color("#4f8a4c")
const BLOOM := Color("#f2a7b8")
const MOSS := Color("#5a8a45")
const SOIL := Color("#6b5137")
const STONE := Color("#a9ab98")
const GLASS := Color("#cfe6da")
const IRON := Color("#38534e")
const BRICK := Color("#a8634a")
const FROG := Color("#7cb85a")
## Mossy boulders on the banks and lotus blooms in the water, in texels.
const ROCKS: Array[Vector2] = [Vector2(10, 60), Vector2(14, 120), Vector2(6, 168), Vector2(306, 52), Vector2(312, 98), Vector2(300, 150)]
const LOTUS: Array[Vector2] = [Vector2(40, 52), Vector2(262, 92), Vector2(44, 150), Vector2(150, 172), Vector2(270, 170)]

var _scene: ImageTexture
var _pad: ImageTexture
var _bouncer: ImageTexture
var _frog: ImageTexture
var _reed: ImageTexture
var _flag: ImageTexture


func _init() -> void:
	super()
	word_anchor = Vector2(640, 210)


func _ready() -> void:
	_scene = Pixels.bake("lily-scene", Vector2i(320, 180), _paint_scene)
	_pad = Pixels.bake("lily-pad", Vector2i(28, 16), _paint_pad)
	_bouncer = Pixels.bake("lily-bouncer", Vector2i(36, 20), _paint_bouncer)
	_frog = Pixels.bake("lily-frog", Vector2i(12, 9), _paint_frog)
	_reed = Pixels.bake("lily-reed", Vector2i(5, 30), _paint_reed)
	_flag = Pixels.bake("lily-flag", Vector2i(16, 26), _paint_flag)


## Centre of a pad spot on screen; column 0 is the near bank, COLUMNS + 1 the far landing.
static func spot(column: int, lane: float, columns := 7) -> Vector2:
	var x := NEAR_X if column <= 0 else (FAR_X if column > columns else FIRST_X + (column - 1) * COLUMN_GAP)
	return Vector2(x, LANE_TOP + lane * LANE_GAP)


func _draw_backdrop() -> void:
	stamp(_scene, Vector2.ZERO)
	# Sun through the glass roof drifts over the water in slow bands.
	for shaft in 4:
		var slide := 0.0 if reduced_motion else 40.0 * sin(now * 0.25 + shaft * 1.7)
		var x := 180.0 + shaft * 260.0 + slide
		draw_colored_polygon(PackedVector2Array([Vector2(x, 150), Vector2(x + 70, 150), Vector2(x + 10, 660), Vector2(x - 60, 660)]), Color(1.0, 0.96, 0.8, 0.05))
	for glint in 14:
		var drift := 0.0 if reduced_motion else fmod(now * (10.0 + glint % 4 * 3.0), 120.0)
		var at := Vector2(150.0 + fmod(glint * 173.0 + drift, 960.0), 250.0 + fmod(glint * 97.0, 380.0))
		draw_rect(Rect2(at, Vector2(20 + glint % 3 * 8, 4)), Color(GLINT, 0.28))
	# Reeds lean at the banks; the far landing flies a little flag.
	for reed in 6:
		var foot := Vector2(24.0 + reed * 13.0, 640.0 - (reed % 3) * 150.0)
		draw_set_transform(foot, 0.0 if reduced_motion else 0.05 * sin(now * 1.1 + reed), Vector2.ONE)
		stamp(_reed, Vector2(-10, -118))
		draw_set_transform(Vector2.ZERO)
	stamp(_flag, Vector2(1206, 158))


func _draw_scene() -> void:
	var columns := int(state.get("columns", 7))
	var pads: Array = state.get("pads", [])
	var mode := str(state.get("mode", "stand"))
	var since := age(float(state.get("mode_at", 0.0)))
	var standing := int(state.get("standing", -1))
	_draw_cues(columns, pads, mode)
	for index in pads.size():
		_draw_pad(pads[index], columns, index == standing, float(state.get("sink_left", 1.0)))
	_draw_visitor(columns, mode, since)
	label(Vector2(96, 172), "第 %d 座池塘" % int(state.get("pond", 1)), 20, Color("#fff2cc"))
	vignette(0.35)


## Faint arrow marks on the pads one hop away, so the three choices read at a glance.
func _draw_cues(columns: int, pads: Array, mode: String) -> void:
	if mode != "stand":
		return
	var column := int(state.get("column", 0))
	var lane := int(state.get("lane", 1))
	if column + 1 > columns:
		return
	for pad: Dictionary in pads:
		if int(pad.column) != column + 1 or bool(pad.gone):
			continue
		var step := roundi(float(pad.lane)) - lane
		if absi(step) > 1 or absf(float(pad.lane) - roundf(float(pad.lane))) > 0.42:
			continue
		var at := spot(column + 1, float(pad.lane), columns)
		label(at + Vector2(0, -46), ["↑", "→", "↓"][step + 1], 34, Color("#fff2cc"), 1.0, 0.6 + 0.35 * pulse(1.2))


func _draw_pad(pad: Dictionary, columns: int, under_visitor: bool, sink_left: float) -> void:
	var at := spot(int(pad.column), float(pad.lane), columns)
	var born := age(float(pad.get("born", -99.0)))
	var sunk := 0.0
	if bool(pad.gone):
		# A pad the visitor has left goes on under and is gone in half a second.
		sunk = 0.6 + 0.4 * clampf(age(float(pad.get("left", -99.0))) / 0.5, 0.0, 1.0)
	elif under_visitor:
		sunk = 1.0 - sink_left
	if sunk >= 0.99:
		return
	var bouncy := str(pad.kind) == "bounce"
	var art := _bouncer if bouncy else _pad
	var half := Vector2(art.get_size()) * TEXEL * 0.5
	var wobble := Vector2.ZERO
	if under_visitor and sunk > 0.6 and not reduced_motion:
		wobble = Vector2(sin(now * 40.0) * 3.0, 0)
	var grow := pop_in(born, 0.3)
	# Ripples ring the pad; drifting pads drag a wake.
	var ring := 0.5 + 0.5 * sin(now * 2.0 + float(pad.phase)) if not reduced_motion else 0.5
	draw_set_transform(at + Vector2(0, 6), 0.0, Vector2(1.0, 0.42))
	draw_arc(Vector2.ZERO, half.x + 10.0 + ring * 8.0, 0.0, TAU, 32, Color(GLINT, 0.22 * (1.0 - ring)), 3.0)
	draw_set_transform(Vector2.ZERO)
	if float(pad.drift) > 0.0 and not reduced_motion:
		var heading := signf(sin(float(pad.phase) + now * float(pad.drift)))
		for wake in 3:
			draw_rect(Rect2(at + Vector2(-30.0 + wake * 22.0, -heading * (30.0 + wake * 10.0)), Vector2(16, 4)), Color(GLINT, 0.3 - wake * 0.08))
	ground_shadow(at + Vector2(8, 14), Vector2(half.x * 0.9, half.y * 0.5), 0.28 * (1.0 - sunk))
	# Water closes over the pad from the rim inward as it sinks.
	var tint := Color.WHITE.lerp(Color(WATER.lightened(0.15), 1.0), sunk * 0.85)
	tint.a = 1.0 - sunk * 0.55
	draw_set_transform(at + wobble, 0.0, Vector2.ONE * grow * (1.0 - 0.25 * sunk))
	stamp(art, -half + Vector2.ONE * TEXEL, TEXEL, tint)
	draw_set_transform(Vector2.ZERO)
	if sunk > 0.45:
		for bubble in 3:
			var rise := fmod(now * 1.6 + bubble * 0.33, 1.0) if not reduced_motion else 0.5
			draw_circle(at + Vector2(-24.0 + bubble * 24.0, -6.0 - rise * 18.0), 3.0 + bubble, Color(GLINT, 0.7 * (1.0 - rise)))
	if bouncy:
		label(at + Vector2(0, -36), "彈", 20, BLOOM.lightened(0.3), 1.0 + 0.08 * pulse(1.5))


func _draw_visitor(columns: int, mode: String, since: float) -> void:
	var from: Vector2i = state.get("hop_from", Vector2i(0, 1))
	var to: Vector2i = state.get("hop_to", Vector2i(0, 1))
	var feet := spot(int(state.get("column", 0)), float(state.get("lane", 1)), columns)
	var pose := &"idle"
	var mood := "plain" if int(state.get("frogs", 0)) == 0 else "sorry"
	var stretch := Vector2.ONE
	if mode == "dunk":
		_draw_dunk(feet, since)
		return
	if mode == "hop":
		var seconds := float(state.get("hop_seconds", 0.28))
		var t := clampf(since / seconds, 0.0, 1.0)
		var start := spot(from.x, from.y, columns)
		var finish := spot(to.x, to.y, columns)
		var lift := (BOUNCE_HEIGHT if bool(state.get("bounced", false)) else HOP_HEIGHT) * sin(t * PI)
		ground_shadow(start.lerp(finish, t) + Vector2(4, 4), Vector2(30, 10), 0.3 * (1.0 - t * 0.3))
		feet = start.lerp(finish, t) - Vector2(0, lift)
		pose = &"up"
		if bool(state.get("bounced", false)):
			mood = "shocked"
		if not reduced_motion:
			stretch = Vector2(0.92, 1.08)
	else:
		ground_shadow(feet + Vector2(6, 4), Vector2(30, 9), 0.36)
		stretch = squash(since, 0.24)
		if mode == "ashore":
			pose = &"up"
			mood = "tongue"
		dust_puffs(feet, since, 44.0)
	_draw_hero(feet + Vector2(0, -2), pose, mood, stretch)
	_draw_frogs(feet + Vector2(0, (-Hero.FEET.y + 3.0) * HERO_SCALE * stretch.y), int(state.get("frogs", 0)))
	if mode == "ashore":
		label(feet + Vector2(0, -150), "上岸！", 34, Color("#fff2cc"), pop_in(since, 0.2))


## The traveller standing on `feet`, drawn at the hero scale.
func _draw_hero(feet: Vector2, pose: StringName, mood: String, stretch := Vector2.ONE) -> void:
	var art := Hero.texture(pose, true, mood)
	draw_set_transform(feet, 0.0, stretch * HERO_SCALE)
	draw_texture_rect(art, Rect2(-Hero.FEET, Vector2(art.get_size())), false)
	draw_set_transform(Vector2.ZERO)


## Down with a splash, a moment of bubbles, then the head comes up wearing a frog.
func _draw_dunk(feet: Vector2, since: float) -> void:
	var splash := clampf(since / 0.5, 0.0, 1.0)
	for drop in 8:
		var angle := -PI * (0.1 + 0.8 * drop / 7.0)
		var reach := 26.0 + 60.0 * splash
		var at := feet + Vector2(cos(angle) * reach, sin(angle) * reach * 0.9 + 80.0 * splash * splash)
		if splash < 1.0:
			draw_rect(Rect2(at.round(), Vector2(8, 8)), Color(GLINT, 1.0 - splash))
	for ring in 2:
		var grow := fmod(since * 0.9 + ring * 0.5, 1.0) if not reduced_motion else 0.5
		draw_set_transform(feet, 0.0, Vector2(1.0, 0.4))
		draw_arc(Vector2.ZERO, 24.0 + 70.0 * grow, 0.0, TAU, 32, Color(GLINT, 0.6 * (1.0 - grow)), 4.0)
		draw_set_transform(Vector2.ZERO)
	var shown := 0.0
	if since < 0.4:
		shown = 1.0 - since / 0.4
	elif since > 0.7:
		shown = minf(0.5, (since - 0.7) / 0.25 * 0.5)
	if shown > 0.0:
		# Only the part above the water line is drawn.
		var art := Hero.texture(&"idle", true, "shocked" if since < 0.4 else "sorry")
		var rows := maxf(1.0, roundf((Hero.FEET.y) * shown))
		var source := Rect2(0, 0, art.get_width(), rows)
		var top := feet - Vector2(Hero.FEET.x * HERO_SCALE, rows * HERO_SCALE)
		draw_texture_rect_region(art, Rect2(top, source.size * HERO_SCALE), source)
		if since > 0.7:
			_draw_frogs(feet + Vector2(0, -rows * HERO_SCALE + 6.0), int(state.get("frogs", 1)))
	else:
		for bubble in 4:
			var rise := fmod(now * 2.0 + bubble * 0.25, 1.0) if not reduced_motion else 0.5
			draw_circle(feet + Vector2(-18.0 + bubble * 12.0, -rise * 30.0), 4.0, Color(GLINT, 0.8 * (1.0 - rise)))
	draw_rect(Rect2(feet + Vector2(-46, -2), Vector2(92, 6)), Color(WATER.lightened(0.2), 0.9))


## The frogs riding the visitor's hat, stacked; each one blinks on its own.
func _draw_frogs(top: Vector2, count: int) -> void:
	var size := Vector2(_frog.get_size()) * TEXEL
	for frog in count:
		var at := top + Vector2(-size.x * 0.5 + TEXEL + (frog % 2) * 6.0 - 3.0, -size.y + TEXEL + 8.0 - frog * 26.0)
		stamp(_frog, at)
		if frog == count - 1 and not reduced_motion and fmod(now + frog, 2.4) < 0.12:
			draw_rect(Rect2(at + Vector2(4, 0), Vector2(36, 8)), FROG.darkened(0.2))


# --- Texel painters ---------------------------------------------------------

## Glass wall and brick plinth at the back, the pond across the middle, and
## mossy banks left and right with stepping stones.
func _paint_scene(x: int, y: int) -> Color:
	var near_edge := 26.0 + 3.0 * sin(y * 0.4) + 2.0 * Pixels.noise(0, y / 3, 5)
	var far_edge := 288.0 - 3.0 * sin(y * 0.33 + 1.0) - 2.0 * Pixels.noise(1, y / 3, 5)
	if y < 30:
		# The glasshouse wall: panes between iron mullions, vines hanging from the transom.
		if x % 40 < 2 or y == 14 or y == 15:
			return IRON.lightened(0.25) if x % 40 == 0 or y == 14 else IRON
		var vine := Pixels.noise(x / 2, 0, 9)
		if y < 4 + vine * 18.0 and Pixels.noise(x, y / 2, 3) > 0.45:
			return Color("#4f8a4c").darkened(0.2 * Pixels.noise(x, y, 4))
		var pane := GLASS.darkened(0.08 * float(y) / 30.0)
		return pane.lightened(0.1) if (x + y * 2) % 37 < 3 else Pixels.grainy(pane, x, y, 0.05)
	if y < 38:
		if y < 31:
			return STONE.lightened(0.15)
		return Pixels.grainy(BRICK.darkened(0.12 if (y - 31) % 3 == 2 or (x + (y / 3) * 4) % 8 == 0 else 0.0), x, y, 0.12)
	var bank := x < near_edge or x > far_edge
	if bank:
		var from_water := minf(absf(x - near_edge), absf(x - far_edge))
		if from_water < 2.5:
			# Wet stones along the waterline, lit on top.
			var stone := Vector2(fmod(float(x) + 40.0, 5.0) - 2.5, float(y % 4) - 1.5) / Vector2(2.5, 2.0)
			return Pixels.rounded(STONE.darkened(0.1 + 0.15 * Pixels.noise(x / 5, y / 4, 3)), stone)
		for rock: Vector2 in ROCKS:
			var off := (Vector2(x + 0.5, y + 0.5) - rock) / Vector2(7.0, 4.5)
			if off.length() < 1.0:
				return Pixels.grainy(Pixels.rounded(STONE, off), x, y, 0.12) if off.y > -0.45 else Pixels.grainy(MOSS.lightened(0.1), x, y, 0.2)
		# Grass tufts and the odd flower on the moss.
		var tuft := Pixels.noise(x / 3, y / 3, 6)
		if tuft > 0.9 and y % 3 == 0:
			return Color("#f2a7b8") if Pixels.noise(x, y, 9) > 0.5 else Color("#fff2cc")
		var moss := MOSS.darkened(0.2) if tuft > 0.62 else (MOSS.lightened(0.1) if tuft < 0.15 else MOSS)
		if (x + y) % 3 == 0 and Pixels.noise(x, y / 2, 7) > 0.7:
			moss = moss.lightened(0.15)
		return Pixels.grainy(moss, x, y, 0.15)
	# Lotus blooms and duckweed near the banks, away from the hopping lanes.
	for bloom: Vector2 in LOTUS:
		var off := Vector2(x + 0.5, y + 0.5) - bloom
		if off.length() < 3.2:
			return Pixels.rounded(BLOOM if off.length() > 1.2 else Color("#ffd166"), off / 3.2)
		if (off / Vector2(6.0, 3.0)).length() < 1.0:
			return Pixels.grainy(PAD_DARK, x, y, 0.15)
	# Duckweed gathers in the still water along the banks only.
	if (x < 60 or x > 252) and Pixels.noise(x / 2, y / 2, 12) > 0.93 and Pixels.noise(x / 14, y / 10, 13) > 0.55:
		return Color("#7fbf6f").darkened(0.15 * Pixels.noise(x, y, 2))
	if y < 42:
		return Pixels.grainy(SOIL.darkened(0.2), x, y, 0.2)
	# Water: lighter where the glass reflects, darker and greener toward the viewer.
	var depth := float(y - 42) / 138.0 * 4.0 + Pixels.noise(x, y, 1) * 0.8
	var water := WATER.lightened(0.08).lerp(DEEP, floorf(depth) / 4.0)
	if (x + y / 2) % 40 < 2:
		water = water.darkened(0.08)
	if Pixels.noise(x / 5, y, 4) > 0.9:
		water = water.lightened(0.12)
	return water


## A lily pad with its notch, radiating veins and a lit rim.
func _paint_pad(x: int, y: int) -> Color:
	var offset := Vector2(x - 13.5, y - 7.5) / Vector2(13.5, 7.5)
	if offset.length() > 1.0:
		return Pixels.CLEAR
	var angle := offset.angle()
	if absf(angle - 0.35) < 0.22 and offset.length() > 0.15:
		return Pixels.CLEAR
	var tone := Pixels.rounded(PAD, offset * 0.8)
	if offset.length() > 0.82:
		tone = tone.darkened(0.12)
	if fmod(angle + TAU, PI / 4.0) < 0.12 and offset.length() > 0.2:
		tone = tone.lightened(0.14)
	return Pixels.grainy(tone, x, y, 0.08)


## The bouncy pad: big, scalloped, ringed, with a flower bud like a spring.
func _paint_bouncer(x: int, y: int) -> Color:
	var offset := Vector2(x - 17.5, y - 9.5) / Vector2(17.5, 9.5)
	var angle := offset.angle()
	var rim := 0.92 + 0.08 * cos(angle * 10.0)
	if offset.length() > rim:
		return Pixels.CLEAR
	var reach := offset.length() / rim
	var bud := Vector2(x - 17.5, (y - 8.5) * 1.6).length()
	if bud < 3.2:
		return Pixels.rounded(BLOOM, Vector2(x - 17.5, y - 8.5) / 3.2)
	if bud < 5.0 and int(angle * 5.0 / PI + 10.0) % 2 == 0:
		return Color("#fbe0e6")
	if reach > 0.62 and reach < 0.74:
		return Pixels.grainy(PAD.lightened(0.2), x, y, 0.1)
	return Pixels.grainy(Pixels.rounded(BOUNCER, offset * 0.7), x, y, 0.1)


func _paint_frog(x: int, y: int) -> Color:
	var at := Vector2(x + 0.5, y + 0.5)
	for eye: float in [3.0, 9.0]:
		var bump := at - Vector2(eye, 2.0)
		if bump.length() < 2.2:
			if bump.length() < 0.9:
				return Color("#1b1626")
			return Color("#f4f0dc") if bump.length() < 1.6 else FROG
	var body := (at - Vector2(6.0, 5.5)) / Vector2(6.0, 3.6)
	if body.length() > 1.0:
		return Pixels.CLEAR
	if y == 5 and x >= 3 and x <= 8:
		return FROG.darkened(0.45)
	if y >= 7:
		return Color("#d9e8a0")
	return Pixels.grainy(Pixels.rounded(FROG, body), x, y, 0.08)


## A cattail with a velvet head and two leaves at its foot.
func _paint_reed(x: int, y: int) -> Color:
	if y == 0:
		return Color("#4f7a3e") if x == 2 else Pixels.CLEAR
	if y < 10:
		return Pixels.grainy(Color("#7a5236").lightened(0.15 if x == 1 else 0.0), x, y, 0.2) if x >= 1 and x <= 3 else Pixels.CLEAR
	if x == 2:
		return Color("#5a8a45")
	if y > 18 and (x == 4 - (y - 19) / 4 or x == (y - 19) / 4):
		return Color("#4f7a3e")
	return Pixels.CLEAR


## A stake with a pennant at the far landing.
func _paint_flag(x: int, y: int) -> Color:
	if x >= 1 and x <= 2:
		return Pixels.wood(Color("#94713f"), x, y, 4)
	if y >= 2 and y <= 11 and x >= 3 and x - 3 <= (11 - y) * 1.3 + 2 and x - 3 <= (y - 2) * 1.3 + 2:
		return Pixels.grainy(Color("#ffd166") if (x + y) % 6 > 1 else Color("#f2a7b8"), x, y, 0.1)
	return Pixels.CLEAR
