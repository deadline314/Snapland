extends "res://game/minigames/arcade/arcade_view.gd"
## Picture for 接飛碟: the clown on a striped drum in the middle of the tent
## stage, velvet wings with a gloved thrower behind each, porcelain plates and
## custard pies spinning in on arcs, the shrinking ring that says "now", and the
## wobbling tower of plates on the clown's bald head. Every object is baked
## pixel art (arcade_pixels.gd) tinted to the tent's warm lamplight.

const TENT_ART := "res://assets/world/circus-tent.webp"
const FLOOR_TOP := 548.0
const UNIT := 4.0
const FEET := Vector2(640, 538)
## Texels above the feet: the hands meet here, the tower starts there.
const HANDS_UP := 21.0
const HEAD_UP := 41.0
const STACK_STEP := 12.0
const STACK_SHOWN := 12
const RING_RADIUS := 84.0
## Flights never rise above this line, clear of the medal strip.
const SKY_LIMIT := 196.0
const WING_X := 104.0
const CLOWN_SIZE := Vector2i(38, 48)
const CLOWN_ORIGIN := Vector2i(19, 47)
const WOOD := Color("#6b4658")
const WOOD_DARK := Color("#3b2536")
const DRAPE := Color("#6a2440")
const BRASS := Color("#b0803a")
const PORCELAIN := Color("#f3ead9")
const COBALT := Color("#3f5f9f")
const TIN := Color("#a59a8c")
const CRUST := Color("#c98a4a")
const CREAM_PIE := Color("#fff1cf")
const CHERRY := Color("#c9344a")
## Scene light: a touch of the tent's dusk on every sprite, as in the other circus games.
const LAMP := Color(1.0, 0.94, 0.9)
const WING_WIDTH := 112.0
const MOODS: Array[String] = ["ready", "catch", "pie", "dizzy"]

var _has_tent := false
var _clowns: Dictionary = {}
var _plate: ImageTexture
var _plate_edge: ImageTexture
var _pie: ImageTexture
var _shard: ImageTexture
var _drum: ImageTexture
var _glove: ImageTexture


func _init() -> void:
	super()
	# Words pop over the open stage right of the tower, never across it.
	word_anchor = Vector2(940, 330)


func _ready() -> void:
	_has_tent = use_backdrop_art(TENT_ART, Rect2(85, 0, 1366, 768), Color(0.8, 0.74, 0.86))
	for mood in MOODS:
		_clowns[mood] = Pixels.bake_blocks("plate-clown|" + mood, CLOWN_SIZE, CLOWN_ORIGIN, _clown_blocks(mood))
	_plate = Pixels.bake("plate-face", Vector2i(16, 16), _paint_plate)
	_plate_edge = Pixels.bake("plate-edge", Vector2i(20, 5), _paint_plate_edge)
	_pie = Pixels.bake("plate-pie", Vector2i(16, 16), _paint_pie)
	_shard = Pixels.bake("plate-shard", Vector2i(5, 3), func(x: int, y: int) -> Color:
		return Pixels.CLEAR if x + y * 2 > 6 else (COBALT if y == 2 else Pixels.grainy(PORCELAIN, x, y, 0.1)))
	_drum = Pixels.bake("plate-drum", Vector2i(52, 22), _paint_drum)
	_glove = Pixels.bake_blocks("plate-glove", Vector2i(9, 6), Vector2i(0, 0), [
		[Rect2(0, 1, 4, 4), VELVET.lightened(0.2)], [Rect2(1, 1, 1, 4), BRASS],
		[Rect2(4, 0, 5, 6), PORCELAIN], [Rect2(8, 1, 1, 2), PORCELAIN.darkened(0.15)]])


func _draw_backdrop() -> void:
	if not _has_tent:
		draw_rect(Rect2(Vector2.ZERO, DESIGN), Color("#2b1f3a"))
	stage_floor(FLOOR_TOP, WOOD, WOOD_DARK)
	# The follow spot pools warm light on the boards around the drum.
	for ring in 4:
		draw_set_transform(Vector2(640, 600), 0.0, Vector2(1.0, 0.2))
		draw_circle(Vector2.ZERO, 330.0 - ring * 60.0, Color(1.0, 0.86, 0.6, 0.06))
	draw_set_transform(Vector2.ZERO)
	vignette(0.6)


func _draw_scene() -> void:
	var mood := str(state.get("mood", "play"))
	var since := age(float(state.get("mood_at", -99.0)))
	var flying: Array = state.get("flying", [])
	_draw_wings(flying)
	_draw_drum()
	if mood == "topple":
		_draw_fallen(since)
	else:
		_draw_ring_back()
	_draw_clown(mood, since)
	if mood != "topple":
		_draw_tower()
		_draw_ring(flying)
	for thing: Dictionary in flying:
		_draw_flight(thing)
	_draw_tower_count()


# --- Stage ------------------------------------------------------------------

func _draw_wings(flying: Array) -> void:
	for side: float in [-1.0, 1.0]:
		var left := -6.0 if side < 0.0 else DESIGN.x - WING_WIDTH
		panel(Rect2(left, PLAY_TOP - 4.0, WING_WIDTH + 6.0, DESIGN.y - PLAY_TOP + 8.0), "velvet", DRAPE, Pixels.CLEAR, 3.0, LAMP)
		var inner := WING_WIDTH if side < 0.0 else DESIGN.x - WING_WIDTH - 10.0
		draw_rect(Rect2(inner, PLAY_TOP - 4.0, 10, DESIGN.y - PLAY_TOP), Color(0.05, 0.02, 0.09, 0.35))
		panel(Rect2(left - 2.0, 470, WING_WIDTH + 10.0, 22), "liquid", BRASS, Pixels.CLEAR, 3.0, LAMP)
		# The thrower's glove pokes out for a moment as each plate leaves.
		var reach := 0.0
		for thing: Dictionary in flying:
			if float(thing.side) == side:
				reach = maxf(reach, 1.0 - clampf(age(float(thing.launched)) / 0.35, 0.0, 1.0))
		if reach > 0.0:
			var glove_x := WING_X - 20.0 + 26.0 * reach
			var glove_y := 330.0
			if side > 0.0:
				draw_set_transform(Vector2(DESIGN.x - glove_x, glove_y), 0.0, Vector2(-1, 1))
			else:
				draw_set_transform(Vector2(glove_x, glove_y))
			stamp(_glove, Vector2(-16, -12), TEXEL, LAMP)
			draw_set_transform(Vector2.ZERO)


func _draw_drum() -> void:
	var corner := Vector2(FEET.x - 26.0 * TEXEL, FEET.y - 2.0)
	ground_shadow(Vector2(FEET.x, corner.y + 22.0 * TEXEL + 4.0), Vector2(122, 14), 0.5)
	stamp(_drum, corner, TEXEL, LAMP)


func _draw_tower_count() -> void:
	var tower := int(state.get("tower", 0))
	if tower <= 0:
		return
	var at := Vector2(846, 470)
	stamp(_plate_edge, at + Vector2(-40, -10), 3.0, LAMP)
	label(at + Vector2(64, 0), "× %d" % tower, 26, GOLD if tower >= 8 else CREAM)


# --- Clown and tower ----------------------------------------------------------

func _draw_clown(mood: String, since: float) -> void:
	var look := "ready"
	var stretch := Vector2.ONE
	var feet := FEET
	if mood == "topple":
		look = "pie" if str(state.get("fall_reason", "")) == "pie" else "dizzy"
		stretch = squash(since - 0.25, 0.3, 0.45)
		if not reduced_motion and look == "dizzy":
			feet.x += sin(since * 9.0) * 6.0 * maxf(0.0, 1.0 - since)
	elif age(float(state.get("catch_at", -99.0))) < 0.22:
		look = "catch"
		stretch = squash(age(float(state.get("catch_at", -99.0))), 0.12, 0.22)
	# A slow breath keeps him alive between throws.
	if look == "ready" and not reduced_motion:
		stretch *= Vector2(1.0 - 0.015 * pulse(0.7), 1.0 + 0.015 * pulse(0.7))
	draw_set_transform(feet, 0.0, stretch * UNIT)
	stamp(_clowns[look], -Vector2(CLOWN_ORIGIN), 1.0, LAMP)
	draw_set_transform(Vector2.ZERO)
	if look == "dizzy":
		# The top plate of the tower landed on his head and stays there like a hat.
		stamp(_plate_edge, feet + Vector2(-40, -HEAD_UP * UNIT - 14.0), TEXEL, LAMP)
		_draw_stars(feet + Vector2(0, -HEAD_UP * UNIT - 34.0), since)
	elif look == "pie":
		_draw_drips(feet, since)


## Lateral offset of the i-th plate up the tower: taller towers sway more, and
## a fumble jolts the whole stack.
func _sway(index: int, tower: int) -> float:
	if reduced_motion:
		return 0.0
	var lean := (0.5 * index + 0.06 * index * index) * clampf(tower / 8.0, 0.3, 1.6)
	var jolt := maxf(0.0, 1.0 - age(float(state.get("fumble_at", -99.0))) / 0.5) * 3.0
	return sin(now * 2.3 + index * 0.33) * lean * (1.0 + jolt) * 0.6


func _draw_tower() -> void:
	var tower := mini(int(state.get("tower", 0)), STACK_SHOWN)
	var base := FEET.y - HEAD_UP * UNIT
	var landed := age(float(state.get("catch_at", -99.0)))
	for index in tower:
		var at := Vector2(FEET.x + _sway(index, tower), base - 6.0 - index * STACK_STEP)
		# The newest plate flips up from the hands onto the top.
		if index == tower - 1 and landed < 0.18 and not reduced_motion:
			var t := landed / 0.18
			at = Vector2(FEET.x, FEET.y - HANDS_UP * UNIT).lerp(at, t) + Vector2(0, -50.0 * sin(t * PI))
		stamp(_plate_edge, at - Vector2(40, 10), TEXEL, LAMP)
	if int(state.get("tower", 0)) > STACK_SHOWN:
		label(Vector2(FEET.x, base - 6.0 - STACK_SHOWN * STACK_STEP - 22.0), "+%d" % (int(state.get("tower", 0)) - STACK_SHOWN), 20, GOLD)


## The tower comes down on the clown: plates tumble out both ways and smash on
## the boards; the plate that was missed flies on past him and smashes too.
func _draw_fallen(since: float) -> void:
	var fallen := mini(int(state.get("fallen", 0)), STACK_SHOWN)
	var base := FEET.y - HEAD_UP * UNIT
	for index in fallen:
		var start := Vector2(FEET.x, base - 6.0 - index * STACK_STEP)
		var spread := (1.0 if index % 2 == 0 else -1.0) * (60.0 + 26.0 * index)
		var floor_y := FLOOR_TOP + 30.0 + float((index * 37) % 50)
		_draw_tumbling(start, Vector2(FEET.x + spread, floor_y), since - index * 0.03, index)
	if str(state.get("fall_reason", "")) == "miss":
		var side := float(state.get("fall_side", -1))
		_draw_tumbling(Vector2(FEET.x, FEET.y - HANDS_UP * UNIT), Vector2(FEET.x - side * 330.0, FLOOR_TOP + 54.0), since, 99)


func _draw_tumbling(from: Vector2, to: Vector2, since: float, salt: int) -> void:
	var t := 1.0 if reduced_motion else clampf(since / 0.5, 0.0, 1.0)
	if t < 1.0:
		var at := from.lerp(to, t) + Vector2(0, -70.0 * sin(t * PI) * (1.0 - t))
		draw_set_transform(at, since * 12.0 + salt, Vector2.ONE * TEXEL)
		stamp(_plate_edge, Vector2(-10, -2.5), 1.0, LAMP)
		draw_set_transform(Vector2.ZERO)
		return
	# Smashed: a fan of shards with a puff of dust for the first instant.
	var settle := since - 0.5
	for bit in 5:
		var angle := -PI * (0.1 + 0.2 * bit) + salt
		var fly := (1.0 if reduced_motion else clampf(settle / 0.25, 0.0, 1.0)) * (16.0 + 8.0 * ((bit + salt) % 3))
		var at := to + Vector2(cos(angle) * fly * 1.6, -absf(sin(angle)) * fly * 0.5)
		draw_set_transform(at, float(bit + salt), Vector2.ONE * 3.0)
		stamp(_shard, Vector2(-2.5, -1.5), 1.0, LAMP)
	draw_set_transform(Vector2.ZERO)
	dust_puffs(to, settle, 40.0)


func _draw_drips(feet: Vector2, since: float) -> void:
	var fall := 0.0 if reduced_motion else minf(since * 30.0, 26.0)
	for drip in 3:
		var at := feet + Vector2(-16.0 + drip * 14.0, -27.0 * UNIT + fall * (0.6 + 0.3 * drip))
		draw_rect(Rect2(at - Vector2(5, 0), Vector2(10, 14)), CREAM_PIE.darkened(0.55))
		draw_rect(Rect2(at - Vector2(3, -1), Vector2(6, 11)), CREAM_PIE)


func _draw_stars(center: Vector2, since: float) -> void:
	for star in 4:
		var angle := float(star) * TAU / 4.0 + (0.0 if reduced_motion else since * 5.0)
		var at := center + Vector2(cos(angle) * 58.0, sin(angle) * 14.0)
		var size := 5.0 if sin(angle) < 0.0 else 7.0
		draw_rect(Rect2(at - Vector2(size + 3.0, 5), Vector2(size * 2.0 + 6.0, 10)), INK)
		draw_rect(Rect2(at - Vector2(5, size + 3.0), Vector2(10, size * 2.0 + 6.0)), INK)
		draw_rect(Rect2(at - Vector2(size, 2), Vector2(size * 2.0, 4)), GOLD)
		draw_rect(Rect2(at - Vector2(2, size), Vector2(4, size * 2.0)), GOLD)


# --- Flights and the ring -----------------------------------------------------

func _catch_point() -> Vector2:
	return FEET - Vector2(0, HANDS_UP * UNIT)


func _flight_point(thing: Dictionary) -> Vector2:
	var side := float(thing.side)
	var start := Vector2(WING_X if side < 0.0 else DESIGN.x - WING_X, 330.0 + float(thing.lane) * 40.0)
	var share := (now - float(thing.launched)) / maxf(float(thing.flight), 0.01)
	var end := _catch_point()
	if share <= 1.0:
		var line := start.lerp(end, share)
		var lift := float(thing.apex) * sin(PI * maxf(share, 0.0))
		return Vector2(line.x, maxf(SKY_LIMIT, line.y - lift))
	# Past the hands it keeps going toward the far wing, dropping.
	var past := share - 1.0
	return end + (end - start) * past + Vector2(0, 260.0 * past * past)


func _draw_flight(thing: Dictionary) -> void:
	var share := (now - float(thing.launched)) / maxf(float(thing.flight), 0.01)
	if share < 0.0:
		return
	var at := _flight_point(thing)
	var pie := str(thing.kind) == "pie"
	ground_shadow(Vector2(at.x, FLOOR_TOP + 40.0), Vector2(30.0 - minf(18.0, (FLOOR_TOP - at.y) * 0.05), 5), 0.3)
	# Plates spin edge-over-edge; pies fly flat and wobble.
	var spin := 0.0 if reduced_motion else now * (3.0 if pie else 13.0)
	var squeeze := 0.55 + 0.35 * absf(cos(spin)) if not pie else 0.75
	var tilt := (-0.3 if float(thing.side) < 0.0 else 0.3) + (0.0 if reduced_motion or not pie else sin(now * 9.0) * 0.12)
	draw_set_transform(at, tilt, Vector2(1.0, squeeze) * TEXEL)
	stamp(_pie if pie else _plate, Vector2(-8, -8), 1.0, LAMP)
	draw_set_transform(Vector2.ZERO)
	if pie:
		label(at + Vector2(0, -50), "別接！", 20, ROSE, 0.9 + 0.1 * pulse(4.0))


## The brass hoop the clown catches in, hung behind him so he stays in view.
func _draw_ring_back() -> void:
	var center := _catch_point()
	var lit := false
	for thing: Dictionary in state.get("flying", []):
		lit = lit or (str(thing.kind) == "plate" and absf(float(thing.arrival) - now) <= float(state.get("catch_window", 0.11)))
	draw_arc(center + Vector2(4, 6), RING_RADIUS, 0.0, TAU, 48, Color(0.05, 0.02, 0.09, 0.35), 10.0)
	draw_arc(center, RING_RADIUS, 0.0, TAU, 48, INK, 12.0)
	draw_arc(center, RING_RADIUS, 0.0, TAU, 48, GOLD if lit else BRASS.darkened(0.15), 7.0)
	draw_arc(center, RING_RADIUS - 1.0, PI * 1.05, PI * 1.7, 14, BRASS.lightened(0.45), 3.0)
	for tack in 8:
		var at := center + Vector2.from_angle(tack * TAU / 8.0) * RING_RADIUS
		draw_rect(Rect2(at - Vector2(3, 3), Vector2(6, 6)), BRASS.darkened(0.5))
		draw_rect(Rect2(at - Vector2(2, 2), Vector2(3, 3)), BRASS.lightened(0.3))


## For each thing on its way, a ring that shrinks onto the hoop exactly when the
## thing arrives: gold for plates, red with a cross for pies.
func _draw_ring(flying: Array) -> void:
	var center := _catch_point()
	for thing: Dictionary in flying:
		var ahead := float(thing.arrival) - now
		if ahead < -0.05 or ahead > 0.9:
			continue
		var pie := str(thing.kind) == "pie"
		var radius := RING_RADIUS + maxf(0.0, ahead) * 150.0
		var tone := ROSE if pie else GOLD
		var alpha := 1.0 - clampf(ahead / 0.9, 0.0, 1.0) * 0.6
		draw_arc(center, radius, 0.0, TAU, 56, Color(INK, alpha * 0.8), 7.0)
		draw_arc(center, radius, 0.0, TAU, 56, Color(tone, alpha), 3.0)
		if pie:
			var mark := center + Vector2(0, -radius)
			draw_line(mark - Vector2(9, 9), mark + Vector2(9, 9), INK, 8.0)
			draw_line(mark - Vector2(9, -9), mark + Vector2(9, -9), INK, 8.0)
			draw_line(mark - Vector2(8, 8), mark + Vector2(8, 8), ROSE, 4.0)
			draw_line(mark - Vector2(8, -8), mark + Vector2(8, -8), ROSE, 4.0)


# --- Texel painters ---------------------------------------------------------

func _paint_plate(x: int, y: int) -> Color:
	var offset := (Vector2(x, y) + Vector2(0.5, 0.5) - Vector2(8, 8)) / 8.0
	var reach := offset.length()
	if reach > 1.0:
		return Pixels.CLEAR
	if reach > 0.78:
		# A cobalt rim with a painted dash every few texels.
		return Pixels.rounded(COBALT if int(atan2(offset.y, offset.x) * 4.0) % 2 == 0 else COBALT.lightened(0.25), offset)
	if reach > 0.66:
		return PORCELAIN.darkened(0.12)
	if reach < 0.22:
		return COBALT.lightened(0.15) if (x + y) % 2 == 0 else PORCELAIN
	return Pixels.grainy(Pixels.rounded(PORCELAIN, offset * 0.6), x, y, 0.05)


func _paint_plate_edge(x: int, y: int) -> Color:
	var inset: int = [3, 0, 0, 1, 4][y]
	if x < inset or x > 19 - inset:
		return Pixels.CLEAR
	match y:
		0: return PORCELAIN.lightened(0.1)
		3: return COBALT if x % 3 != 0 else COBALT.lightened(0.3)
		4: return PORCELAIN.darkened(0.35)
	return Pixels.grainy(PORCELAIN, x, y, 0.06)


func _paint_pie(x: int, y: int) -> Color:
	var offset := (Vector2(x, y) + Vector2(0.5, 0.5) - Vector2(8, 8)) / 8.0
	var reach := offset.length()
	if reach > 1.0:
		return Pixels.CLEAR
	if reach > 0.82:
		return Pixels.metal(Pixels.rounded(TIN, offset), x, y, 3)
	if reach > 0.64:
		return Pixels.grainy(CRUST if (x + y) % 3 != 0 else CRUST.darkened(0.2), x, y, 0.1)
	if reach < 0.16:
		return CHERRY.lightened(0.3) if x < 8 and y < 8 else CHERRY
	# A swirl of cream piped round the cherry.
	var swirl := fposmod(atan2(offset.y, offset.x) + reach * 9.0, TAU) < PI
	return Pixels.rounded(CREAM_PIE if swirl else CREAM_PIE.darkened(0.08), offset * 0.7)


## A circus drum: gilt bands with tacks, red and cream staves rounded by the light.
func _paint_drum(x: int, y: int) -> Color:
	var across := Vector2((x + 0.5 - 26.0) / 26.0, 0.0)
	if y < 3 or y > 18:
		var band := Pixels.metal(BRASS, x, y)
		return band.darkened(0.4) if (y == 1 or y == 20) and x % 6 == 3 else band
	if y == 3:
		return VELVET.darkened(0.5)
	var stave := Color("#b8423f") if (x / 4) % 2 == 0 else Color("#efe0c2")
	return Pixels.grainy(Pixels.rounded(stave, across), x, y, 0.07)


## The clown in texels around his feet (x right, y up is negative), back to front.
static func _clown_blocks(mood: String) -> Array:
	var suit := Color("#e9c46a")
	var suit_b := Color("#d9604f")
	var pants := Color("#4f5f9f")
	var face := Color("#f4e6d8")
	var hair := Color("#e07b39")
	var red := Color("#c9344a")
	var glove := Color("#f3ead9")
	var teal := Color("#4fa89a")
	var blocks: Array = [
		[Rect2(-12, -4, 10, 4), red], [Rect2(2, -4, 10, 4), red], [Rect2(-11, -4, 3, 1), red.lightened(0.3)], [Rect2(3, -4, 3, 1), red.lightened(0.3)],
		[Rect2(-8, -16, 16, 12), pants], [Rect2(-9, -6, 18, 2), pants.darkened(0.25)], [Rect2(0, -15, 1, 9), pants.darkened(0.3)],
		[Rect2(-6, -13, 2, 2), glove], [Rect2(3, -11, 2, 2), glove], [Rect2(-3, -9, 2, 2), glove],
		[Rect2(-9, -29, 9, 14), suit], [Rect2(0, -29, 9, 14), suit_b], [Rect2(-9, -17, 18, 2), suit.darkened(0.35)],
		[Rect2(-1, -26, 2, 2), red], [Rect2(-1, -22, 2, 2), teal],
		[Rect2(-10, -31, 20, 3), glove], [Rect2(-10, -29, 2, 1), glove.darkened(0.2)], [Rect2(-4, -29, 2, 1), glove.darkened(0.2)], [Rect2(2, -29, 2, 1), glove.darkened(0.2)], [Rect2(8, -29, 2, 1), glove.darkened(0.2)],
		[Rect2(-6, -41, 12, 10), face], [Rect2(-6, -41, 12, 1), face.lightened(0.3)],
		[Rect2(-10, -39, 4, 5), hair], [Rect2(6, -39, 4, 5), hair], [Rect2(-9, -35, 2, 2), hair], [Rect2(7, -35, 2, 2), hair],
		[Rect2(-1, -35, 3, 3), red], [Rect2(-1, -35, 1, 1), Color.WHITE],
	]
	match mood:
		"catch":
			blocks.append_array([[Rect2(-13, -38, 4, 10), suit], [Rect2(9, -38, 4, 10), suit_b],
				[Rect2(-14, -42, 5, 4), glove], [Rect2(9, -42, 5, 4), glove],
				[Rect2(-4, -38, 2, 2), Color("#2b2440")], [Rect2(2, -38, 2, 2), Color("#2b2440")],
				[Rect2(-3, -32, 6, 2), red], [Rect2(-2, -31, 4, 1), Color("#7a1f2f")]])
		"pie":
			blocks.append_array([[Rect2(-16, -29, 7, 3), suit], [Rect2(9, -29, 7, 3), suit_b],
				[Rect2(-19, -31, 4, 4), glove], [Rect2(15, -31, 4, 4), glove],
				[Rect2(-7, -42, 14, 11), Color("#fff1cf")], [Rect2(-5, -31, 3, 2), Color("#fff1cf")], [Rect2(2, -31, 3, 3), Color("#fff1cf")],
				[Rect2(-4, -40, 3, 2), Color("#f6dcaa")], [Rect2(-1, -44, 3, 3), red]])
		"dizzy":
			blocks.append_array([[Rect2(-12, -28, 3, 11), suit], [Rect2(9, -28, 3, 11), suit_b],
				[Rect2(-13, -18, 4, 4), glove], [Rect2(9, -18, 4, 4), glove],
				[Rect2(-5, -39, 1, 1), Color("#2b2440")], [Rect2(-3, -39, 1, 1), Color("#2b2440")], [Rect2(-4, -38, 1, 1), Color("#2b2440")],
				[Rect2(-5, -37, 1, 1), Color("#2b2440")], [Rect2(-3, -37, 1, 1), Color("#2b2440")],
				[Rect2(2, -39, 1, 1), Color("#2b2440")], [Rect2(4, -39, 1, 1), Color("#2b2440")], [Rect2(3, -38, 1, 1), Color("#2b2440")],
				[Rect2(2, -37, 1, 1), Color("#2b2440")], [Rect2(4, -37, 1, 1), Color("#2b2440")],
				[Rect2(-2, -32, 4, 2), Color("#7a1f2f")]])
		_:
			blocks.append_array([[Rect2(-13, -28, 4, 8), suit], [Rect2(9, -28, 4, 8), suit_b],
				[Rect2(-12, -23, 7, 3), suit], [Rect2(5, -23, 7, 3), suit_b],
				[Rect2(-6, -24, 4, 4), glove], [Rect2(2, -24, 4, 4), glove],
				[Rect2(-4, -38, 2, 2), Color("#2b2440")], [Rect2(2, -38, 2, 2), Color("#2b2440")],
				[Rect2(-4, -40, 2, 1), teal], [Rect2(2, -40, 2, 1), teal],
				[Rect2(-4, -32, 8, 1), red], [Rect2(-4, -33, 1, 1), red], [Rect2(3, -33, 1, 1), red]])
	return blocks
