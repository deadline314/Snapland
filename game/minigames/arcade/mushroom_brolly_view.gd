extends "res://game/minigames/arcade/arcade_view.gd"
## Picture for 蘑菇撐傘: a rainy afternoon in the greenhouse potting room. Rain
## leaks through the glass roof onto four seedlings in clay pots on the bench;
## the big spotted mushroom umbrella hangs from a brass trolley on a rail, rain
## it catches trickles down its stem into the pot below, hail bonks off its cap
## and dents it, and a seedling that takes a hailstone droops with a plaster on.
## Everything is baked pixel art (arcade_pixels.gd) in the garden's palette.

const ROOF_Y := 196.0
const SOIL_Y := 548.0
const BENCH_TOP := 604.0
const LEFT := 80.0
const RIGHT := 1200.0
const RAIL_Y := 214.0
const CAP_TOP := 46.0
const GLASS := Color("#9cc4bd")
const IRON := Color("#38534e")
const RAIN := Color("#cfe9f2")
const HAIL := Color("#e8f4ff")
const CAP := Color("#c8483e")
const CAP_SPOT := Color("#fff2dc")
const STEM := Color("#efe2c4")
const CLAY := Color("#b8643f")
const SOIL := Color("#4f3f2e")
const LEAF := Color("#6fae5c")
const BRASS := Color("#d9a64e")
const WOOD := Color("#8a6640")
const BLOOMS: Array[Color] = [Color("#f2a7b8"), Color("#ffd166"), Color("#bfa2e8"), Color("#fff2dc")]

var _scene: ImageTexture
var _cap: ImageTexture
var _stem: ImageTexture
var _pot: ImageTexture
var _sprout: ImageTexture
var _droop: ImageTexture
var _hail: ImageTexture
var _trolley: ImageTexture
var _bubble: ImageTexture
var _flowers: Array[ImageTexture] = []


func _init() -> void:
	super()
	word_anchor = Vector2(640, 300)


func _ready() -> void:
	_scene = Pixels.bake("brolly-scene", Vector2i(320, 180), _paint_scene)
	_cap = Pixels.bake("brolly-cap", Vector2i(46, 20), _paint_cap)
	_stem = Pixels.bake("brolly-stem", Vector2i(8, 20), _paint_stem)
	_pot = Pixels.bake("brolly-pot", Vector2i(22, 16), _paint_pot)
	_sprout = Pixels.bake("brolly-sprout", Vector2i(15, 16), _paint_sprout.bind(false))
	_droop = Pixels.bake("brolly-droop", Vector2i(15, 16), _paint_sprout.bind(true))
	_hail = Pixels.bake("brolly-hail", Vector2i(6, 6), _paint_hail)
	_trolley = Pixels.bake("brolly-trolley", Vector2i(14, 8), _paint_trolley)
	_bubble = Pixels.bake("brolly-bubble", Vector2i(13, 15), _paint_bubble)
	for petal in BLOOMS.size():
		_flowers.append(Pixels.bake("brolly-flower|%d" % petal, Vector2i(5, 5), _paint_flower.bind(BLOOMS[petal])))


func screen_x(x: float) -> float:
	return LEFT + x * (RIGHT - LEFT)


func screen_y(y: float) -> float:
	return ROOF_Y + y * (SOIL_Y - ROOF_Y)


func _draw_backdrop() -> void:
	stamp(_scene, Vector2.ZERO)
	# Rain runs down the far glass in slow streaks.
	for streak in 18:
		var x := 40.0 + streak * 68.0 + 14.0 * sin(streak * 2.3)
		var run := 0.0 if reduced_motion else fmod(now * (60.0 + streak % 5 * 12.0) + streak * 53.0, 300.0)
		draw_rect(Rect2(x, 230.0 + run, 3, 16), Color(RAIN, 0.22))
	bench(BENCH_TOP, WOOD)
	# The brass rail the umbrella's trolley runs on.
	panel(Rect2(40, RAIL_Y - 6.0, 1200, 12), "pole", BRASS)
	for bracket: float in [40.0, 640.0, 1240.0]:
		draw_rect(Rect2(bracket - 8.0, ROOF_Y - 40.0, 16, RAIL_Y - ROOF_Y + 40.0), IRON.darkened(0.2))


func _draw_scene() -> void:
	var pot_xs: Array = state.get("pot_xs", [])
	var pots: Array = state.get("pots", [])
	for index in pot_xs.size():
		_draw_pot(index, screen_x(float(pot_xs[index])), pots[index] if index < pots.size() else {})
	_draw_hail_shadows()
	_draw_umbrella()
	_draw_drops()
	var thirsty := int(state.get("thirsty", -1))
	if thirsty >= 0 and thirsty < pot_xs.size() and thirsty < pots.size():
		_draw_thirst(screen_x(float(pot_xs[thirsty])), pots[thirsty])
	vignette(0.4)


# --- Seedlings --------------------------------------------------------------

func _draw_pot(index: int, x: float, pot: Dictionary) -> void:
	var base := Vector2(x, BENCH_TOP)
	ground_shadow(base + Vector2(8, 0), Vector2(50, 8), 0.4)
	var droop_age := age(float(pot.get("droop_at", -99.0)))
	var drooping := droop_age >= 0.0 and droop_age < float(state.get("droop_seconds", 2.0))
	var sway := 0.0 if reduced_motion else 0.06 * sin(now * 1.6 + index)
	var plant := _droop if drooping else _sprout
	var size := Vector2(plant.get_size()) * TEXEL
	var foot := Vector2(x, SOIL_Y + 6.0)
	var stretch := squash(droop_age, 0.3, 0.4) if drooping else Vector2.ONE
	draw_set_transform(foot, 0.0 if drooping else sway, stretch)
	stamp(plant, Vector2(-size.x * 0.5 + TEXEL, -size.y + TEXEL))
	# Every bloom it earned stays on it.
	for bloom in mini(int(pot.get("blooms", 0)), 4):
		var spot := [Vector2(-22, -54), Vector2(18, -46), Vector2(-4, -66), Vector2(24, -62)][bloom] as Vector2
		if drooping:
			spot = Vector2(spot.x * 0.6 + 16.0, spot.y * 0.45)
		stamp(_flowers[(bloom + index) % _flowers.size()], spot - Vector2(8, 8))
	draw_set_transform(Vector2.ZERO)
	stamp(_pot, Vector2(x - _pot.get_width() * TEXEL * 0.5 + TEXEL, SOIL_Y - 4.0))
	if drooping:
		label(Vector2(x + 30, SOIL_Y - 96.0), "嗚…", 26, ROSE, pop_in(droop_age, 0.2))
		# A sticking plaster across the bend, and one tear.
		draw_rect(Rect2(x + 4.0, SOIL_Y - 46.0, 20, 8), Color("#f4dcb8"))
		draw_rect(Rect2(x + 12.0, SOIL_Y - 46.0, 4, 8), Color("#d9b48a"))
		var tear := 0.0 if reduced_motion else fmod(droop_age * 40.0, 24.0)
		draw_rect(Rect2(x + 30.0, SOIL_Y - 20.0 + tear, 6, 8), RAIN)


## A droplet bubble over the thirsty seedling, with a pip for every gulp it still needs.
func _draw_thirst(x: float, pot: Dictionary) -> void:
	var since := age(float(state.get("thirsty_at", 0.0)))
	var bob := 0.0 if reduced_motion else 4.0 * sin(now * 3.0)
	# Beside the seedling, under the cap's rim, so the cap never hides it.
	var at := Vector2(x + 70.0, SOIL_Y - 64.0 + bob)
	draw_set_transform(at, 0.0, Vector2.ONE * pop_in(since, 0.3))
	stamp(_bubble, Vector2(-26, -60))
	draw_set_transform(Vector2.ZERO)
	# A pip on the pot for every gulp it still needs.
	var needed := int(state.get("gulps_needed", 4))
	var had := int(pot.get("gulps", 0))
	for pip in needed:
		var dot := Vector2(x - (needed - 1) * 11.0 + pip * 22.0, SOIL_Y + 30.0)
		draw_rect(Rect2(dot - Vector2(7, 7), Vector2(14, 14)), INK)
		draw_rect(Rect2(dot - Vector2(5, 5), Vector2(10, 10)), Color("#4fa3d9") if pip < had else Color("#d9b48a"))


# --- Umbrella ---------------------------------------------------------------

func _draw_umbrella() -> void:
	var x := screen_x(float(state.get("cap_x", 0.5)))
	var cap_line := screen_y(float(state.get("cap_y", 0.62)))
	var dent_age := age(float(state.get("dent_at", -99.0)))
	var stretch := squash(dent_age, 0.2, 0.3)
	# Trolley on the rail, a chain down to the crown.
	stamp(_trolley, Vector2(x - 28.0 + TEXEL, RAIL_Y - 20.0))
	var link := RAIL_Y + 12.0
	while link < cap_line - CAP_TOP:
		draw_rect(Rect2(x - 3.0, link, 6, 8), BRASS.darkened(0.25 if int(link) % 16 < 8 else 0.0))
		link += 8.0
	# The cap: the line drops land on runs across its middle.
	var cap_size := Vector2(_cap.get_size()) * TEXEL
	var scale_x := float(state.get("cap_half", 0.085)) / 0.085
	draw_set_transform(Vector2(x, cap_line), 0.0, Vector2(scale_x, 1.0) * stretch)
	stamp(_stem, Vector2(-_stem.get_width() * TEXEL * 0.5 + TEXEL, 10.0))
	stamp(_cap, Vector2(-cap_size.x * 0.5 + TEXEL, -CAP_TOP))
	# Dents from hail: dark pits on the crown that slowly pop back out.
	for dent in int(state.get("dents", 0)):
		var pit := Vector2(-48.0 + dent * 44.0, -CAP_TOP + 14.0 + (dent % 2) * 6.0)
		draw_rect(Rect2(pit, Vector2(16, 8)), CAP.darkened(0.55))
		draw_rect(Rect2(pit + Vector2(0, 8), Vector2(16, 4)), CAP.lightened(0.2))
	draw_set_transform(Vector2.ZERO)
	glint(Vector2(x - 40.0, cap_line - 30.0), 22.0, 4.0)
	if dent_age >= 0.0 and dent_age < 0.5:
		dust_puffs(Vector2(x, cap_line - CAP_TOP + 4.0), dent_age, 50.0)


# --- Rain and hail ----------------------------------------------------------

## A shadow grows on the bench under every falling hailstone: where it will land.
func _draw_hail_shadows() -> void:
	for drop: Dictionary in state.get("drops", []):
		if str(drop.kind) != "hail" or str(drop.state) != "falling":
			continue
		var t := clampf(age(float(drop.born)) / float(drop.fall), 0.0, 1.0)
		var land := float(drop.start) + float(drop.drift)
		ground_shadow(Vector2(screen_x(land), SOIL_Y + 4.0), Vector2(10.0 + 22.0 * t, 5.0 + 4.0 * t), 0.2 + 0.4 * t)


func _draw_drops() -> void:
	var cap_x := screen_x(float(state.get("cap_x", 0.5)))
	var cap_line := screen_y(float(state.get("cap_y", 0.62)))
	for drop: Dictionary in state.get("drops", []):
		var kind := str(drop.kind)
		var fall := float(drop.fall)
		var t := clampf(age(float(drop.born)) / fall, 0.0, 1.0)
		var at := Vector2(screen_x(float(drop.x)), screen_y(t))
		var since := age(float(drop.at))
		match str(drop.state):
			"falling":
				if kind == "hail":
					stamp(_hail, at - Vector2(12, 12))
				else:
					var lean := float(drop.drift) * 40.0
					draw_line(at - Vector2(lean, 18), at, Color(RAIN, 0.85), 3.0)
			"caught":
				# Down the stem and into the pot.
				var trickle := clampf(since / 0.35, 0.0, 1.0)
				var from := Vector2(cap_x + (screen_x(float(drop.x)) - cap_x) * (1.0 - trickle), cap_line + 10.0 + trickle * 70.0)
				draw_rect(Rect2(from - Vector2(4, 4), Vector2(8, 10)), RAIN)
				if since > 0.35:
					_splash(Vector2(cap_x, SOIL_Y), since - 0.35, 0.6)
			"splash":
				_splash(Vector2(screen_x(float(drop.x)), cap_line - 30.0), since, 1.0)
			"ground", "hit":
				if kind == "hail":
					var hop := 0.0 if reduced_motion else -40.0 * sin(clampf(since / 0.4, 0.0, 1.0) * PI)
					stamp(_hail, Vector2(screen_x(float(drop.x)) + since * 60.0, SOIL_Y + hop) - Vector2(12, 12), TEXEL, Color(1, 1, 1, 1.0 - since / 0.6))
				else:
					_splash(Vector2(screen_x(float(drop.x)), SOIL_Y + 30.0), since, 0.8)
			"bonk":
				var fly := Vector2((-1.0 if float(drop.x) < float(state.get("cap_x", 0.5)) else 1.0) * since * 300.0, -120.0 * since + 400.0 * since * since)
				stamp(_hail, Vector2(screen_x(float(drop.x)), cap_line - CAP_TOP) + fly - Vector2(12, 12))
				if since < 0.3:
					label(Vector2(screen_x(float(drop.x)), cap_line - CAP_TOP - 30.0), "咚", 26, CREAM, pop_in(since, 0.12))


func _splash(at: Vector2, since: float, size: float) -> void:
	if since < 0.0 or since > 0.4:
		return
	var t := since / 0.4
	for side: float in [-1.0, -0.4, 0.4, 1.0]:
		var spot := at + Vector2(side * 26.0 * t * size, -22.0 * sin(t * PI) * size)
		draw_rect(Rect2(spot.round() - Vector2(3, 3), Vector2(6, 6)), Color(RAIN, 1.0 - t))


# --- Texel painters ---------------------------------------------------------

## The potting room in the rain: glass roof with dark leaking seams, glass wall
## with shelves of spare pots, a brick plinth behind the bench.
func _paint_scene(x: int, y: int) -> Color:
	if y < 49:
		# Roof glass: grey-green panes with iron glazing bars; the seams drip.
		if x % 32 < 2 or y == 48 or y == 47:
			return IRON.lightened(0.18) if x % 32 == 0 or y == 47 else IRON
		var pane := Color("#6f8d8a").lerp(Color("#8aa9a2"), float(y) / 48.0)
		if Pixels.noise(x / 3, y / 4, 2) > 0.8:
			pane = pane.lightened(0.08)
		return Pixels.grainy(pane, x, y, 0.06)
	if y < 120:
		# The far wall: tall panes with the wet garden blurred behind them.
		if x % 54 < 2 or y == 84:
			return IRON.lightened(0.12) if x % 54 == 0 else IRON.darkened(0.1)
		var blur := Pixels.noise(x / 6, y / 6, 4)
		var outside := Color("#4d6f5c").lerp(Color("#6f8f78"), blur * 0.6)
		if y > 92 and blur > 0.55:
			outside = Color("#3f5f4a")
		# A shelf of spare pots on the left and of seed trays on the right.
		if y >= 76 and y <= 78 and (x < 110 or x > 210):
			return Pixels.wood(WOOD.darkened(0.1), x, y, 12, false)
		if y >= 64 and y < 76 and (x < 110 or x > 210):
			var cell := x % 18
			if x < 110 and cell > 3 and cell < 14 and y > 66:
				return Pixels.rounded(CLAY.darkened(0.15), Vector2(float(cell - 9) / 5.0, float(y - 71) / 5.0))
			if x > 210 and y > 71 and cell > 1 and cell < 16:
				return Pixels.grainy(Color("#5d7a3c") if y < 73 else SOIL, x, y, 0.2)
		return Pixels.grainy(GLASS.darkened(0.35).lerp(outside, 0.6), x, y, 0.05)
	if y < 124:
		return Color("#c9b9a0") if y == 120 else Color("#9a8a72")
	# Brick plinth down to the bench.
	var course := (y - 124) / 4
	var shifted := x + (4 if course % 2 == 1 else 0)
	if (y - 124) % 4 == 3 or shifted % 9 == 0:
		return Color("#6a4a3a")
	return Pixels.grainy(Color("#9a5a44").darkened(0.12 * Pixels.noise(shifted / 9, course, 5)), x, y, 0.1)


## The mushroom cap seen from the side: a dome with cream spots and a frilled rim.
func _paint_cap(x: int, y: int) -> Color:
	var offset := Vector2((x - 22.5) / 22.5, (y - 15.0) / 14.0)
	if y > 15:
		# The underside gills, a shallow band below the rim.
		if absf(x - 22.5) > 22.5 - (y - 15) * 2.0 or y > 18:
			return Pixels.CLEAR
		return STEM.darkened(0.2) if x % 2 == 0 else STEM.darkened(0.35)
	if offset.length() > 1.0:
		return Pixels.CLEAR
	for spot: Vector3 in [Vector3(10, 6, 2.6), Vector3(22, 3, 2.2), Vector3(33, 7, 2.8), Vector3(16, 11, 1.8), Vector3(29, 12, 2.0), Vector3(39, 13, 1.4)]:
		if Vector2(x - spot.x, y - spot.y).length() < spot.z:
			return Pixels.rounded(CAP_SPOT, Vector2(x - spot.x, y - spot.y) / spot.z)
	var tone := Pixels.rounded(CAP, offset * 0.9)
	if y == 15:
		return CAP.darkened(0.3)
	return Pixels.grainy(tone, x, y, 0.06)


## The stem hanging under the cap, narrowing to a drip tip.
func _paint_stem(x: int, y: int) -> Color:
	var half := 3.5 - y * 0.12
	if absf(x - 3.5) > half:
		return Pixels.CLEAR
	if y >= 2 and y <= 3:
		return STEM.darkened(0.18)
	return Pixels.rounded(STEM, Vector2((x - 3.5) / maxf(half, 0.5), 0.0))


## A clay pot with a rim and a band, the soil showing at the top.
func _paint_pot(x: int, y: int) -> Color:
	if y < 2:
		return Pixels.grainy(SOIL, x, y, 0.2) if x >= 2 and x <= 19 else Pixels.CLEAR
	if y < 5:
		return Pixels.grainy(CLAY.lightened(0.1 if y == 2 else 0.0), x, y, 0.1)
	var inset := (y - 5) / 4
	if x < 1 + inset or x > 20 - inset:
		return Pixels.CLEAR
	var tone := Pixels.rounded(CLAY, Vector2((x - 10.5) / 10.0, 0.0))
	return Pixels.grainy(tone.darkened(0.1) if y == 9 else tone, x, y, 0.12)


## A seedling with two leaves; `sulking` bends it over with its leaves down.
func _paint_sprout(x: int, y: int, sulking: bool) -> Color:
	var at := Vector2(x + 0.5, y + 0.5)
	if sulking:
		# The stem rises, then hooks over to the right; leaves hang like wet ears.
		if absf(at.x - 6.5) < 0.8 and at.y > 5.0:
			return LEAF.darkened(0.25)
		var hook := at - Vector2(9.5, 5.0)
		if at.y <= 5.0 and absf(hook.length() - 3.0) < 0.8:
			return LEAF.darkened(0.2)
		if absf(at.x - 12.5) < 0.8 and at.y > 5.0 and at.y < 9.0:
			return LEAF.darkened(0.2)
		for leaf: Vector2 in [Vector2(11.2, 10.8), Vector2(13.8, 11.0)]:
			if ((at - leaf) / Vector2(1.3, 2.8)).length() < 1.0:
				return Pixels.rounded(LEAF.darkened(0.08), (at - leaf) / 2.8)
		return Pixels.CLEAR
	if absf(at.x - 7.5) < 0.8 and at.y > 4.0:
		return LEAF.darkened(0.2)
	for leaf: Vector3 in [Vector3(4.0, 6.0, -1.0), Vector3(11.0, 5.0, 1.0)]:
		var off := (at - Vector2(leaf.x, leaf.y)) / Vector2(3.4, 2.2)
		if off.length() < 1.0:
			return Pixels.rounded(LEAF, off)
	if ((at - Vector2(7.5, 3.0)) / Vector2(1.8, 2.4)).length() < 1.0:
		return LEAF.lightened(0.15)
	return Pixels.CLEAR


func _paint_hail(x: int, y: int) -> Color:
	var off := Vector2(x - 2.5, y - 2.5) / 3.0
	if off.length() > 1.0:
		return Pixels.CLEAR
	return Pixels.rounded(HAIL, off) if (x + y) % 3 != 0 else HAIL.darkened(0.12)


func _paint_trolley(x: int, y: int) -> Color:
	if y < 3:
		var wheel := Vector2(x % 7 - 3.0, y - 1.0)
		return Pixels.rounded(IRON.lightened(0.2), wheel / 3.0) if wheel.length() < 2.6 else Pixels.CLEAR
	if y < 6:
		return Pixels.metal(BRASS, x, y)
	return Pixels.metal(BRASS.darkened(0.15), x, y) if x >= 5 and x <= 8 else Pixels.CLEAR


## A speech bubble with a water droplet in it.
func _paint_bubble(x: int, y: int) -> Color:
	var at := Vector2(x + 0.5, y + 0.5)
	var body := (at - Vector2(6.5, 6.0)) / Vector2(6.5, 6.0)
	var tail := at.y >= 11.0 and at.y <= 14.0 and absf(at.x - 6.5) < 14.0 - at.y - 0.5
	if body.length() > 1.0 and not tail:
		return Pixels.CLEAR
	var drop := at - Vector2(6.5, 7.0)
	if drop.length() < 2.6 or (drop.y < 0.0 and absf(drop.x) < 2.6 + drop.y * 0.75 and drop.y > -5.0):
		return Pixels.rounded(Color("#4fa3d9"), drop / 3.0)
	return Pixels.grainy(Color("#fff5dc"), x, y, 0.05)


func _paint_flower(x: int, y: int, petal: Color) -> Color:
	var off := Vector2(x - 2.0, y - 2.0)
	if off.length() > 2.3:
		return Pixels.CLEAR
	return Color("#ffd166") if off.length() < 0.8 else Pixels.rounded(petal, off / 2.3)
