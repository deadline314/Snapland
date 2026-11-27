extends "res://game/minigames/arcade/arcade_view.gd"
## Picture for 帽中套物: in the tent's arch an upside-down top hat sits on a
## striped circus drum; the hero reaches into it and everything pulled out flies
## up and is pegged onto a line strung across the stage, so how greedy this hat
## has been is plain to see. The hat shakes and puffs smoke as a warning. A
## skunk pops out in a green cloud that swallows the hero, nose pinched and eyes
## watering, while the line's catch drops to the boards. Every object is baked
## pixel art (arcade_pixels.gd, arcade_hero.gd) or a shared material.

const Hero = preload("res://game/minigames/arcade/arcade_hero.gd")
const TENT_ART := "res://assets/world/circus-tent.webp"
const FLOOR_TOP := 556.0
const LINE_Y := 236.0
const LINE_FROM := 150.0
const LINE_TO := 1130.0
const FEET := Vector2(590, 652)
const HAT_AT := Vector2(730, 604)
const HAT_TEXELS := Vector2i(40, 34)
const DRUM := Rect2(650, 604, 160, 58)
const FLY_SECONDS := 0.28
const LAMP := Color(0.94, 0.89, 0.96)
const WOOD := Color("#6b4658")
const WOOD_DARK := Color("#3b2536")
const BRASS := Color("#b0803a")
const SCARVES: Array[Color] = [Color("#c9483d"), Color("#e9b85c"), Color("#2f8a8c"), Color("#7a4f9a"), Color("#e07a9a")]

var _has_tent := false
var _items: Dictionary = {}
var _hat: ImageTexture
var _drum: ImageTexture
var _cloud: ImageTexture
var _skunk: ImageTexture


func _init() -> void:
	super()
	word_anchor = Vector2(1000, 380)


func _ready() -> void:
	_has_tent = use_backdrop_art(TENT_ART, Rect2(85, 0, 1366, 768), Color(0.7, 0.64, 0.78))
	for index in SCARVES.size():
		var tone: Color = SCARVES[index]
		_items["scarf%d" % index] = Pixels.bake_blocks("hat-scarf|%d" % index, Vector2i(14, 15), Vector2i(7, 0), [
			[Rect2(-7, 0, 14, 3), tone], [Rect2(-6, 3, 12, 3), tone], [Rect2(-5, 6, 10, 3), tone], [Rect2(-3, 9, 6, 3), tone], [Rect2(-1, 12, 2, 3), tone],
			[Rect2(-6, 1, 12, 1), tone.lightened(0.3)], [Rect2(-4, 7, 8, 1), tone.darkened(0.25)], [Rect2(-1, 0, 2, 2), tone.darkened(0.35)]])
	_items["bouquet"] = Pixels.bake_blocks("hat-bouquet", Vector2i(14, 18), Vector2i(7, 0), [
		[Rect2(-1, 0, 2, 3), Color("#c9483d")],
		[Rect2(-4, 9, 8, 3), Color("#f3e8cf")], [Rect2(-3, 12, 6, 3), Color("#f3e8cf")], [Rect2(-2, 15, 4, 3), Color("#e9dcc0")],
		[Rect2(-2, 6, 1, 6), Color("#4f8a3c")], [Rect2(1, 6, 1, 6), Color("#4f8a3c")],
		[Rect2(-6, 3, 4, 4), Color("#e07a9a")], [Rect2(-2, 2, 4, 4), Color("#e9b85c")], [Rect2(2, 3, 4, 4), Color("#c9483d")],
		[Rect2(-5, 4, 1, 1), Color("#ffd0dc")], [Rect2(-1, 3, 1, 1), Color("#fff0b0")], [Rect2(3, 4, 1, 1), Color("#ff9a8a")]])
	_items["dove"] = Pixels.bake_blocks("hat-dove", Vector2i(16, 12), Vector2i(8, 0), [
		[Rect2(-1, 0, 2, 2), Color("#c9a46a")],
		[Rect2(-6, 3, 11, 5), Color("#f4f0ea")], [Rect2(3, 1, 4, 4), Color("#f4f0ea")], [Rect2(7, 2, 2, 1), Color("#e0a050")],
		[Rect2(5, 2, 1, 1), Color("#2b2440")], [Rect2(-8, 4, 3, 3), Color("#dcd6e4")], [Rect2(-4, 1, 6, 3), Color("#e6e0ee")],
		[Rect2(-2, 8, 1, 2), Color("#e07b6a")], [Rect2(1, 8, 1, 2), Color("#e07b6a")]])
	_items["rabbit"] = Pixels.bake_blocks("hat-rabbit", Vector2i(14, 22), Vector2i(7, 0), [
		[Rect2(-3, 0, 2, 7), Color("#f4f0ea")], [Rect2(1, 0, 2, 7), Color("#f4f0ea")], [Rect2(-2, 1, 1, 5), Color("#f0a8b8")], [Rect2(2, 1, 1, 5), Color("#f0a8b8")],
		[Rect2(-4, 6, 8, 6), Color("#f4f0ea")], [Rect2(-3, 8, 1, 1), Color("#2b2440")], [Rect2(2, 8, 1, 1), Color("#2b2440")], [Rect2(-1, 10, 2, 1), Color("#e07a9a")],
		[Rect2(-5, 12, 10, 7), Color("#ebe5f0")], [Rect2(-6, 14, 2, 3), Color("#ebe5f0")], [Rect2(4, 14, 2, 3), Color("#ebe5f0")],
		[Rect2(-4, 19, 3, 2), Color("#f4f0ea")], [Rect2(1, 19, 3, 2), Color("#f4f0ea")], [Rect2(-1, 13, 3, 3), Color("#ffffff")]])
	var fur := Color("#2b2733")
	var white := Color("#f4f0ea")
	_skunk = Pixels.bake_blocks("hat-skunk", Vector2i(24, 22), Vector2i(12, 21), [
		[Rect2(2, -21, 8, 16), fur], [Rect2(0, -22, 7, 3), fur], [Rect2(4, -21, 3, 14), white], [Rect2(1, -21, 3, 1), white],
		[Rect2(-7, -11, 13, 11), fur], [Rect2(-4, -12, 8, 2), white],
		[Rect2(-12, -15, 9, 8), fur], [Rect2(-9, -17, 2, 8), white],
		[Rect2(-12, -17, 2, 2), fur], [Rect2(-6, -17, 2, 2), fur], [Rect2(-11, -16, 1, 1), Color("#e07a9a")],
		[Rect2(-11, -12, 2, 2), white], [Rect2(-11, -12, 1, 1), Color("#1a1420")], [Rect2(-6, -12, 2, 2), white], [Rect2(-6, -12, 1, 1), Color("#1a1420")],
		[Rect2(-13, -10, 2, 2), Color("#e07a9a")],
		[Rect2(-6, -1, 3, 1), fur], [Rect2(1, -1, 3, 1), fur]])
	_hat = Pixels.bake("hat-tophat", HAT_TEXELS, _paint_hat)
	_drum = Pixels.bake("hat-drum", Vector2i(40, 14), _paint_drum)
	_cloud = Pixels.bake("hat-cloud", Vector2i(52, 40), _paint_cloud)


func _draw_backdrop() -> void:
	if not _has_tent:
		draw_rect(Rect2(Vector2.ZERO, DESIGN), Color("#2b1f3a"))
	stage_floor(FLOOR_TOP, WOOD, WOOD_DARK)
	vignette(0.5)


func _draw_scene() -> void:
	var phase := str(state.get("phase", "idle"))
	var since := age(float(state.get("phase_at", 0.0)))
	_draw_line_rig()
	_draw_catch(phase, since)
	_draw_drum()
	_draw_hat(str(state.get("warning", "")), phase, since)
	if phase == "stink":
		_draw_stink(since)
	else:
		_draw_hero(phase, since)
	_draw_pot(phase)


# --- The line -----------------------------------------------------------------

func _slot(index: int) -> Vector2:
	var step := (LINE_TO - LINE_FROM - 100.0) / float(int(state.get("max_items", 12)) - 1)
	var x := LINE_FROM + 50.0 + index * step
	var along := (x - LINE_FROM) / (LINE_TO - LINE_FROM)
	return Vector2(x, LINE_Y + 22.0 * sin(along * PI))


func _draw_line_rig() -> void:
	for x: float in [LINE_FROM - 14.0, LINE_TO + 14.0]:
		ground_shadow(Vector2(x, FLOOR_TOP + 20.0), Vector2(30, 6), 0.4)
		panel(Rect2(x - 7.0, LINE_Y - 20.0, 14, FLOOR_TOP + 20.0 - LINE_Y + 20.0), "pole", BRASS, Pixels.CLEAR, 2.0, LAMP)
		draw_circle(Vector2(x, LINE_Y - 22.0), 10.0, BRASS.darkened(0.5))
		draw_circle(Vector2(x - 2, LINE_Y - 24.0), 7.0, BRASS.lightened(0.15))
	var points := PackedVector2Array()
	var x := LINE_FROM
	while x <= LINE_TO + 1.0:
		var along := (x - LINE_FROM) / (LINE_TO - LINE_FROM)
		points.append(Vector2(x, LINE_Y + 22.0 * sin(along * PI)))
		x += 20.0
	draw_polyline(points, INK, 5.0)
	draw_polyline(points, Color("#d9c49a"), 2.5)
	# Pegs waiting for the next tricks, faint until filled.
	for index in int(state.get("max_items", 12)):
		var peg := _slot(index)
		draw_rect(Rect2(peg - Vector2(3, 7), Vector2(6, 12)), Color(INK, 0.55))
		draw_rect(Rect2(peg - Vector2(2, 6), Vector2(4, 10)), Color(Color("#c9a46a"), 0.55))


## Everything pulled so far: flying up from the hat, pegged on the line, then
## bowing off on a bank or tumbling to the boards when the skunk comes.
func _draw_catch(phase: String, since: float) -> void:
	var line: Array = state.get("line", [])
	var mouth := HAT_AT + Vector2(0, -HAT_TEXELS.y * TEXEL + 18.0)
	for index in line.size():
		var item: Dictionary = line[index]
		if str(item.kind) == "skunk":
			continue
		var peg := _slot(index)
		var flight := 1.0 if reduced_motion else clampf(age(float(item.at)) / FLY_SECONDS, 0.0, 1.0)
		var at := mouth.lerp(peg, flight) - Vector2(0, 120.0 * sin(flight * PI))
		var tint := LAMP
		var turn := 0.0 if reduced_motion else 0.06 * sin(now * 2.4 + index)
		if phase == "stink" and not reduced_motion:
			# Dropped: everything falls off the line and bounces on the boards.
			var fall := maxf(0.0, since - 0.25 - index * 0.04)
			at.y = minf(FLOOR_TOP + 40.0 + (index % 3) * 10.0, peg.y + 900.0 * fall * fall)
			turn = fall * 6.0 * (1.0 if index % 2 == 0 else -1.0)
			tint = Color(LAMP, 1.0 - clampf((since - 1.5) / 0.6, 0.0, 1.0))
		elif phase == "stink":
			at.y = FLOOR_TOP + 40.0
		elif phase == "bow" and not reduced_motion:
			# Banked: the whole line hops and sparkles.
			at.y -= 18.0 * absf(sin(since * 9.0 + index * 0.5)) * (1.0 - since)
		var sprite := _sprite_for(str(item.kind), index)
		draw_set_transform(at, turn, Vector2.ONE * TEXEL)
		stamp(sprite, Vector2(-sprite.get_width() * 0.5, 0), 1.0, tint)
		draw_set_transform(Vector2.ZERO)
		if flight >= 1.0 and phase != "stink":
			draw_rect(Rect2(peg - Vector2(3, 7), Vector2(6, 12)), INK)
			draw_rect(Rect2(peg - Vector2(2, 6), Vector2(4, 10)), Color("#e9c88a"))
	if phase == "bow" and not reduced_motion:
		for spark in 6:
			var turn := now * 2.0 + spark * TAU / 6.0
			var at := Vector2(640, LINE_Y + 40.0) + Vector2.from_angle(turn) * Vector2(420, 50)
			draw_rect(Rect2(at - Vector2(4, 4), Vector2(8, 8)), Color(GOLD, 1.0 - since))


func _sprite_for(kind: String, index: int) -> Texture2D:
	if kind == "scarf":
		return _items["scarf%d" % (index % SCARVES.size())]
	return _items.get(kind, _items["scarf0"])


# --- Hat and drum ---------------------------------------------------------------

func _draw_drum() -> void:
	ground_shadow(Vector2(DRUM.get_center().x, DRUM.end.y + 2.0), Vector2(96, 10), 0.5)
	stamp(_drum, DRUM.position - Vector2(TEXEL, TEXEL), TEXEL, LAMP)


func _draw_hat(warning: String, phase: String, since: float) -> void:
	var shaking := warning == "both" or warning == "shake"
	var smoking := warning == "both" or warning == "smoke"
	var turn := 0.0
	var hop := Vector2.ZERO
	if shaking and not reduced_motion:
		turn = 0.09 * sin(now * 38.0)
		hop = Vector2(3.0 * sin(now * 51.0), -absf(4.0 * sin(now * 27.0)))
	if phase == "stink" and not reduced_motion:
		turn = 0.2 * sin(since * 20.0) * maxf(0.0, 1.0 - since * 2.0)
	var size := Vector2(HAT_TEXELS + Vector2i(2, 2)) * TEXEL
	draw_set_transform(HAT_AT + hop, turn)
	stamp(_hat, Vector2(-size.x * 0.5, -size.y + TEXEL), TEXEL, LAMP)
	draw_set_transform(Vector2.ZERO)
	var mouth := HAT_AT + hop + Vector2(0, -size.y + 26.0)
	if shaking:
		label(mouth + Vector2(118, 24), "喀喀喀", 24, CREAM, 0.9 + 0.1 * pulse(6.0))
	if smoking:
		for puff in 5:
			var rise := 0.6 if reduced_motion else fmod(now * 1.4 + puff * 0.2, 1.0)
			var at := mouth + Vector2(-30.0 + puff * 15.0 + 10.0 * sin(rise * 6.0 + puff), -rise * 90.0)
			var radius := 10.0 + rise * 16.0
			draw_circle(at + Vector2(2, 3), radius, Color(0.08, 0.04, 0.1, 0.25 * (1.0 - rise)))
			draw_circle(at, radius, Color(Color("#b8b0c8"), 0.7 * (1.0 - rise)))
			draw_circle(at - Vector2(radius * 0.3, radius * 0.3), radius * 0.45, Color(1, 1, 1, 0.35 * (1.0 - rise)))
	if phase == "stink":
		# The skunk pops up on the brim and waves its tail.
		var up := pop_in(since, 0.25)
		var wag := 0.0 if reduced_motion else 0.15 * sin(now * 8.0)
		draw_set_transform(mouth + Vector2(0, 14.0 - 66.0 * up), wag, Vector2(1.3, 1.3) * TEXEL)
		stamp(_skunk, Vector2(-13, -22), 1.0, LAMP)
		draw_set_transform(Vector2.ZERO)


## The pot this hat would bank right now, on a little sign by the drum.
func _draw_pot(phase: String) -> void:
	var pot := int(state.get("pot", 0))
	if phase == "pull" and pot > 0:
		var board := Rect2(840, 560, 150, 48)
		draw_rect(Rect2(board.position + Vector2(4, 6), board.size), Color(0.06, 0.02, 0.08, 0.4))
		panel(board, "lacquer", LACQUER, GILT, 3.0)
		label(board.get_center(), "這一帽 %d" % pot, 22, GOLD)


# --- Hero -----------------------------------------------------------------------

func _draw_hero(phase: String, since: float) -> void:
	var pose := &"idle"
	var mood := "plain"
	var warning := str(state.get("warning", ""))
	match phase:
		"pull":
			pose = &"up"
			mood = "shocked" if warning != "" else "plain"
		"bow":
			pose = &"up"
			mood = "tongue"
	var feet := FEET
	if phase == "pull" and not reduced_motion:
		# Tugging: a little lean back with every item.
		feet.x -= 4.0 * absf(sin(now * 9.0))
	var stretch := squash(since, 0.16) if phase == "bow" else Vector2.ONE
	ground_shadow(feet + Vector2(0, 4), Vector2(54, 10), 0.42)
	var texture := Hero.texture(pose, true, mood)
	draw_set_transform(feet, 0.0, stretch * TEXEL)
	stamp(texture, -Hero.FEET, 1.0, LAMP)
	draw_set_transform(Vector2.ZERO)


## A green cloud swallows the hero: nose pinched, eyes watering, stink lines.
## The cloud billows behind him with thinner puffs in front, so his face shows.
func _draw_stink(since: float) -> void:
	var grow := 1.0 if reduced_motion else clampf(since / 0.35, 0.0, 1.0)
	var fade := 1.0 - clampf((since - 1.7) / 0.5, 0.0, 1.0)
	var centre := FEET + Vector2(6, -96)
	var breathe := 1.0 + (0.0 if reduced_motion else 0.04 * sin(now * 4.0))
	draw_set_transform(centre, 0.0, Vector2.ONE * TEXEL * (0.5 + 1.0 * grow) * breathe)
	stamp(_cloud, -Vector2(_cloud.get_size()) * 0.5, 1.0, Color(1, 1, 1, 0.9 * fade))
	draw_set_transform(Vector2.ZERO)
	ground_shadow(FEET + Vector2(0, 4), Vector2(54, 10), 0.42)
	var texture := Hero.texture(&"nose", true, "stinky")
	var sway := 0.0 if reduced_motion else 0.05 * sin(now * 5.0)
	draw_set_transform(FEET, sway, Vector2.ONE * TEXEL)
	stamp(texture, -Hero.FEET, 1.0, LAMP.lerp(Color("#c8e8a8"), 0.3))
	draw_set_transform(Vector2.ZERO)
	for puff in 4:
		var drift := 0.0 if reduced_motion else sin(now * 1.7 + puff * 1.9) * 10.0
		var at := centre + Vector2(-80.0 + puff * 54.0 + drift, 60.0 - (puff % 2) * 30.0)
		var radius := (26.0 + (puff % 3) * 8.0) * grow
		draw_circle(at, radius, Color(Color("#8fbf62"), 0.32 * fade))
		draw_circle(at - Vector2(radius * 0.3, radius * 0.3), radius * 0.5, Color(Color("#c8e8a0"), 0.25 * fade))
	if not reduced_motion:
		for wisp in 3:
			var rise := fmod(now * 0.9 + wisp * 0.33, 1.0)
			var base := centre + Vector2(-70.0 + wisp * 70.0, -120.0 - rise * 50.0)
			var points := PackedVector2Array()
			for step in 6:
				points.append(base + Vector2(6.0 * sin(step * 1.6 + now * 6.0), -step * 8.0))
			draw_polyline(points, Color(Color("#6fae5c"), 0.8 * (1.0 - rise)), 4.0)
	label(centre + Vector2(-150, -40), "臭～～", 34, Color("#a8e08a"), 0.9 + 0.1 * pulse(3.0), fade)


# --- Painted props --------------------------------------------------------------

## An upside-down top hat: brim and dark mouth on top, felt crown standing on
## the drum, a red band near the bottom; felt sheen on the left.
func _paint_hat(x: int, y: int) -> Color:
	var w := HAT_TEXELS.x
	var cx := (w - 1) * 0.5
	var felt := Color("#2e2a3c")
	if y < 9:
		var brim := Vector2((x - cx) / (w * 0.5), (y - 4.0) / 4.5)
		if brim.length() > 1.0:
			return Pixels.CLEAR
		var mouth := Vector2((x - cx) / 13.5, (y - 4.5) / 2.6)
		if mouth.length() <= 1.0:
			return Pixels.lit(Color("#120d18"), -0.4 + mouth.y * 0.4, x, y)
		return Pixels.lit(felt, 0.9 - brim.y * 0.8 - (x - cx) / w, x, y)
	if absf(x - cx) > 14.0 - (y - 9) * 0.06:
		return Pixels.CLEAR
	var across := (x - cx) / 14.0
	var value := 0.7 - absf(across + 0.45) * 1.6 + 0.12 * (Pixels.noise(x, y, 21) - 0.5)
	if y >= HAT_TEXELS.y - 9 and y < HAT_TEXELS.y - 4:
		return Pixels.lit(Color("#a83a3a"), value + (0.5 if y == HAT_TEXELS.y - 9 else 0.0), x, y)
	if y >= HAT_TEXELS.y - 2:
		return Pixels.lit(felt, value - 0.6, x, y)
	return Pixels.lit(felt, value, x, y)


## A circus drum: red and cream chevrons between brass hoops.
func _paint_drum(x: int, y: int) -> Color:
	if y < 2 or y >= 12:
		return Pixels.metal(BRASS, x, y)
	var chevron := posmod(x + int(absf(y - 7.0)), 8) < 4
	var tone := Color("#b8463f") if chevron else Color("#efe2c4")
	return Pixels.lit(tone, 0.6 - absf(x - 12.0) / 20.0, x, y)


## A lumpy stink cloud in sickly greens.
func _paint_cloud(x: int, y: int) -> Color:
	var lumps: Array[Vector3] = [Vector3(14, 22, 12), Vector3(26, 14, 13), Vector3(38, 22, 12), Vector3(26, 27, 12), Vector3(18, 12, 8), Vector3(36, 11, 8)]
	var best := 99.0
	var lit_from := Vector2.ZERO
	for lump in lumps:
		var offset := Vector2(x - lump.x, y - lump.y) / lump.z
		if offset.length() < best:
			best = offset.length()
			lit_from = offset
	if best > 1.0:
		return Pixels.CLEAR
	return Pixels.lit(Color("#7fae5a").lerp(Color("#a8c86a"), Pixels.noise(x / 3, y / 3, 4) * 0.4), 0.6 - (lit_from.x + lit_from.y) * 0.7, x, y)
