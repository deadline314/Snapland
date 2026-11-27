extends "res://game/minigames/arcade/arcade_view.gd"
## Picture for 蒲公英落郵: inside the greenhouse the island traveller
## (arcade_hero) hangs from a dandelion stem under a big white puff, a satchel
## of letters at the hip. The floor and everything on it scroll by: red tin
## mailboxes on wooden posts or hanging on chains, flags waving until a letter
## goes in; cacti in clay pots; ivy baskets on chains; warm-air grates with
## shimmer rising; sprinkler heads spraying down. A sneeze bursts the puff into
## drifting seeds and drops the traveller holding a bare stem. Every object is
## baked pixel art over the shared greenhouse backdrop.

const Hero = preload("res://game/minigames/arcade/arcade_hero.gd")
const Greenhouse = preload("res://game/minigames/arcade/greenhouse_backdrop.gd")
const ROOF := 168.0
const FLOOR := 612.0
const HERO_SCALE := 2.0
const PUFF := Vector2i(18, 17)
const MAILBOX := Vector2i(13, 10)
const CLAY := Color("#b8643f")
const SOIL := Color("#4f3f2e")
const CACTUS := Color("#5f9a5a")
const TIN := Color("#c8483e")
const WOOD := Color("#8a6640")
const IRON := Color("#38534e")
const IVY := Color("#5f9e4f")
const SEED := Color("#f6f1e2")
const WATER := Color("#a9e2ef")
const PAPER := Color("#f4e6c4")
const MORNING := Color(1.0, 0.98, 0.94)

var _puff: ImageTexture
var _mailbox: ImageTexture
var _flag: Array[ImageTexture] = []
var _pot: ImageTexture
var _cactus: ImageTexture
var _cactus_top: ImageTexture
var _basket: ImageTexture
var _grate: ImageTexture
var _nozzle: ImageTexture
var _letter: ImageTexture


func _init() -> void:
	super()
	word_anchor = Vector2(790, 236)


func _ready() -> void:
	_puff = Pixels.bake("post-puff", PUFF, _paint_puff)
	_mailbox = Pixels.bake("post-mailbox", MAILBOX, _paint_mailbox)
	for frame in 3:
		_flag.append(Pixels.bake("post-flag|%d" % frame, Vector2i(7, 9), _paint_flag.bind(frame)))
	_pot = Pixels.bake("post-pot", Vector2i(16, 11), _paint_pot)
	_cactus = Pixels.bake("post-cactus", Vector2i(10, 8), _paint_cactus.bind(false))
	_cactus_top = Pixels.bake("post-cactus-top", Vector2i(10, 6), _paint_cactus.bind(true))
	_basket = Pixels.bake("post-basket", Vector2i(16, 14), _paint_basket)
	_grate = Pixels.bake("post-grate", Vector2i(18, 4), _paint_grate)
	_nozzle = Pixels.bake("post-nozzle", Vector2i(8, 6), _paint_nozzle)
	_letter = Pixels.bake("post-letter", Vector2i(8, 6), _paint_letter)


func _draw_backdrop() -> void:
	Greenhouse.draw(self, now, reduced_motion)
	_draw_floor()
	vignette(0.35)


func _draw_scene() -> void:
	if not state.has("things"):
		return
	for thing: Dictionary in state.things:
		match str(thing.kind):
			"vent": _draw_vent(thing)
			"sprinkler": _draw_sprinkler(thing)
	for thing: Dictionary in state.things:
		match str(thing.kind):
			"mailbox": _draw_mailbox(thing)
			"cactus": _draw_cactus(thing)
			"basket": _draw_basket(thing)
	_draw_hero()
	_draw_sneeze()
	_draw_streak()


# --- Placement ----------------------------------------------------------------

func _sx(x: float) -> float:
	return (x - float(state.get("travel", 0.0))) * DESIGN.x


func _sy(y: float) -> float:
	return FLOOR - y * (FLOOR - ROOF)


## The greenhouse floor: tiles scrolling by under a strip of moss.
func _draw_floor() -> void:
	bench(FLOOR, WOOD)
	var scroll := fposmod(float(state.get("travel", 0.0)) * DESIGN.x, 64.0)
	var x := -scroll
	while x < DESIGN.x:
		draw_rect(Rect2(x, FLOOR + 4.0, 3, 104), WOOD.darkened(0.45))
		draw_rect(Rect2(x + 3.0, FLOOR + 4.0, 1, 104), WOOD.lightened(0.15))
		x += 64.0
	# Small potted ferns along the back of the floor drift by, dimmed so they
	# read as scenery, not as things to dodge.
	var travel := float(state.get("travel", 0.0)) * DESIGN.x
	var first := floori(travel / 170.0)
	for slot in range(first, first + 10):
		var px := slot * 170.0 + 60.0 * Pixels.noise(slot, 2, 17) - travel
		var tint := Color(0.72, 0.74, 0.7)
		stamp(_pot, Vector2(px, FLOOR - 26.0), TEXEL * 0.5, tint)
		for frond in 5:
			var angle := -PI * 0.5 + (frond - 2) * 0.42
			var tip := Vector2(px + 16.0, FLOOR - 24.0) + Vector2.from_angle(angle) * (18.0 + 6.0 * (frond % 2))
			draw_line(Vector2(px + 16.0, FLOOR - 22.0), tip, Color(0.33, 0.5, 0.3), 3.0)


# --- Things along the way ---------------------------------------------------------

func _draw_mailbox(box: Dictionary) -> void:
	var x := _sx(float(box.x))
	if x < -80.0 or x > DESIGN.x + 80.0:
		return
	var at := Vector2(x, _sy(float(box.y)))
	var size := Vector2(MAILBOX) * TEXEL
	if bool(box.hang):
		# A chain from the roof rail.
		var link := ROOF
		while link < at.y - size.y * 0.5:
			draw_rect(Rect2(at.x - 3.0, link, 6, 8), IRON.darkened(0.2))
			draw_rect(Rect2(at.x - 2.0, link + 1.0, 2, 3), IRON.lightened(0.3))
			link += 10.0
	else:
		# A wooden post from the floor, with its shadow.
		ground_shadow(Vector2(x + 8.0, FLOOR + 4.0), Vector2(26, 6), 0.4)
		var post := Rect2(x - 7.0, at.y + size.y * 0.5 - 4.0, 14, FLOOR - at.y - size.y * 0.5 + 6.0)
		panel(post, "planks_v", WOOD, Color(0, 0, 0, 0), TEXEL, MORNING)
	stamp(_mailbox, at - size * 0.5, TEXEL, MORNING)
	var posted := age(float(box.posted_at))
	if bool(box.flag):
		var frame := 0 if reduced_motion else int(now * 6.0 + float(box.x) * 13.0) % 3
		stamp(_flag[frame], at + Vector2(size.x * 0.5 - 6.0, -size.y * 0.5 - 30.0), TEXEL, MORNING)
	elif posted >= 0.0 and posted < 0.6:
		# The letter slides into the slot with a little puff of dust.
		var drop := pop_in(posted, 0.18)
		stamp(_letter, at + Vector2(-14, -40.0 + 30.0 * drop), TEXEL, Color(1, 1, 1, 1.0 - posted / 0.6))
		dust_puffs(at + Vector2(0, -size.y * 0.5), posted, 30.0)


func _draw_cactus(cactus: Dictionary) -> void:
	var x := _sx(float(cactus.x))
	if x < -80.0 or x > DESIGN.x + 80.0:
		return
	var top := _sy(float(cactus.top))
	var pot_size := Vector2(16, 11) * TEXEL
	var pot_top := FLOOR - pot_size.y + 6.0
	ground_shadow(Vector2(x + 10.0, FLOOR + 4.0), Vector2(40, 7), 0.42)
	# A column of ribbed segments up to a rounded top with a flower.
	var segment := Vector2(10, 8) * TEXEL
	var y := pot_top - segment.y + 8.0
	while y > top + 20.0:
		stamp(_cactus, Vector2(x - segment.x * 0.5, y), TEXEL, MORNING)
		y -= segment.y - 4.0
	stamp(_cactus_top, Vector2(x - segment.x * 0.5, top - 4.0), TEXEL, MORNING)
	stamp(_pot, Vector2(x - pot_size.x * 0.5, pot_top), TEXEL, MORNING)


func _draw_basket(basket: Dictionary) -> void:
	var x := _sx(float(basket.x))
	if x < -80.0 or x > DESIGN.x + 80.0:
		return
	var bottom := _sy(float(basket.bottom))
	var size := Vector2(16, 14) * TEXEL
	var sway := 0.0 if reduced_motion else roundf(3.0 * sin(now * 1.4 + float(basket.x) * 5.0))
	for side: float in [-1.0, 1.0]:
		draw_line(Vector2(x, ROOF), Vector2(x + side * 24.0 + sway, bottom - size.y + 8.0), IRON.darkened(0.2), 3.0)
	draw_rect(Rect2(x - 4.0, ROOF - 4.0, 8, 8), IRON)
	stamp(_basket, Vector2(x - size.x * 0.5 + sway, bottom - size.y), TEXEL, MORNING)


func _draw_vent(vent: Dictionary) -> void:
	var x := _sx(float(vent.x))
	if x < -120.0 or x > DESIGN.x + 120.0:
		return
	var width := float(vent.width) * DESIGN.x
	var grate := Vector2(18, 4) * TEXEL
	stamp(_grate, Vector2(x - grate.x * 0.5, FLOOR - 6.0), TEXEL, MORNING)
	# Warm shimmer rising: wavy bands that drift upward.
	for band in 8:
		var rise := fposmod((0.0 if reduced_motion else now * 120.0) + band * 56.0, FLOOR - ROOF)
		var yy := FLOOR - 10.0 - rise
		var wobble := 0.0 if reduced_motion else 6.0 * sin(now * 3.0 + band)
		var fade := 1.0 - rise / (FLOOR - ROOF)
		draw_rect(Rect2(x - width * 0.35 + wobble, yy, width * 0.7, 4), Color(1.0, 0.82, 0.55, 0.32 * fade))
		draw_rect(Rect2(x - width * 0.25 - wobble, yy + 18.0, width * 0.5, 3), Color(1.0, 0.9, 0.7, 0.24 * fade))
	# A warm column of air above the grate.
	draw_rect(Rect2(x - width * 0.4, ROOF, width * 0.8, FLOOR - ROOF), Color(1.0, 0.8, 0.5, 0.06))
	for arrow in 3:
		var yy := FLOOR - 70.0 - arrow * 130.0 - (0.0 if reduced_motion else fposmod(now * 40.0, 30.0))
		label(Vector2(x, yy), "↑", 30, Color(1.0, 0.82, 0.55, 0.75))


func _draw_sprinkler(sprinkler: Dictionary) -> void:
	var x := _sx(float(sprinkler.x))
	if x < -120.0 or x > DESIGN.x + 120.0:
		return
	var width := float(sprinkler.width) * DESIGN.x
	draw_rect(Rect2(x - 4.0, ROOF - 10.0, 8, 30), IRON)
	draw_rect(Rect2(x - 3.0, ROOF - 10.0, 2, 30), IRON.lightened(0.3))
	stamp(_nozzle, Vector2(x - 16.0, ROOF + 16.0), TEXEL, MORNING)
	# A cone of falling drops.
	for drop in 26:
		var fall := fposmod((0.0 if reduced_motion else now * 260.0) + drop * 37.0, FLOOR - ROOF - 40.0)
		var spread := (float(drop % 9) / 8.0 - 0.5) * width * (0.3 + fall / (FLOOR - ROOF))
		var at := Vector2(x + spread, ROOF + 40.0 + fall).round()
		draw_rect(Rect2(at, Vector2(3, 7)), Color(WATER, 0.7))
	draw_rect(Rect2(x - width * 0.5, FLOOR - 2.0, width, 4), Color(WATER, 0.35))


# --- The traveller ----------------------------------------------------------------

func _draw_hero() -> void:
	var sneeze: Dictionary = state.get("sneeze", {})
	var since := age(float(sneeze.get("at", -99.0))) if not sneeze.is_empty() else 99.0
	if since >= 0.0 and since < float(state.get("sneeze_seconds", 1.7)):
		return
	var hands := Vector2(float(state.get("hero_x", 0.3)) * DESIGN.x, _sy(float(state.get("y", 0.5))))
	var rising := float(state.get("vy", 0.0))
	# Puff above, stem down to the raised hands, the traveller hanging below.
	var bob := 0.0 if reduced_motion else roundf(2.0 * sin(now * 3.0))
	var puff := Vector2(PUFF) * TEXEL
	var stretch := Vector2(1.0 + (0.08 if bool(state.get("holding", false)) and not reduced_motion else 0.0), 1.0)
	draw_line(hands, hands + Vector2(0, -46), Color("#7a9a4a"), 4.0)
	draw_line(hands + Vector2(-1, 0), hands + Vector2(-1, -46), Color("#a8c87a"), 1.0)
	draw_set_transform(hands + Vector2(0, -46 - puff.y * 0.5 + bob), clampf(-rising * 0.4, -0.25, 0.25), stretch)
	stamp(_puff, -puff * 0.5, TEXEL, MORNING)
	draw_set_transform(Vector2.ZERO)
	var mood := "shocked" if float(state.get("y", 0.5)) < 0.12 or float(state.get("y", 0.5)) > 0.9 else "plain"
	var sprite := Hero.texture(&"up", true, mood)
	var origin := hands - Vector2(20, 6) * HERO_SCALE
	stamp(sprite, origin, HERO_SCALE, MORNING)
	stamp(_letter, hands + Vector2(10, 56), TEXEL * 0.75, MORNING)
	# A faint shadow on the floor shows how high the traveller hangs.
	var height := clampf(float(state.get("y", 0.5)), 0.0, 1.0)
	ground_shadow(Vector2(hands.x + 6.0, FLOOR + 4.0), Vector2(40 - 20 * height, 7), 0.4 - 0.25 * height)


func _draw_sneeze() -> void:
	var sneeze: Dictionary = state.get("sneeze", {})
	if sneeze.is_empty():
		return
	var since := age(float(sneeze.at))
	var total := float(state.get("sneeze_seconds", 1.7))
	if since < 0.0 or since > total:
		return
	var hands := Vector2(float(state.get("hero_x", 0.3)) * DESIGN.x, _sy(float(sneeze.y)))
	var puff_at := hands + Vector2(0, -46 - PUFF.y * TEXEL * 0.5)
	# The puff bursts: seeds on little parachutes drift out and up.
	for seed_index in 22:
		var angle := seed_index * TAU / 22.0 + 0.2
		var spread := (40.0 + 260.0 * minf(since, 1.0)) * (0.6 + 0.4 * sin(seed_index * 2.7))
		var drift := Vector2(cos(angle), sin(angle) * 0.6) * spread + Vector2(0, -50.0 * since)
		if reduced_motion:
			drift = Vector2(cos(angle), sin(angle) * 0.6) * 160.0
		var at := (puff_at + drift).round()
		draw_line(at, at + Vector2(0, 10), Color("#d8ccb0"), 1.0)
		for spoke in 5:
			draw_line(at, at + Vector2.from_angle(-PI * 0.5 + (spoke - 2) * 0.45) * 7.0, SEED, 1.0)
	# The traveller drops holding a bare stem and lands with a bump.
	var fall := clampf(since / 0.55, 0.0, 1.0) if not reduced_motion else 1.0
	var feet_y := lerpf(hands.y + 86.0, FLOOR + 2.0, fall * fall)
	var feet := Vector2(hands.x, feet_y)
	var mood := "shocked" if since < 0.5 else "sorry"
	var origin := feet - Vector2(20, 46) * HERO_SCALE
	var landed := squash(since - 0.55, 0.3, 0.3)
	draw_set_transform(feet, 0.0, landed)
	stamp(Hero.texture(&"up", true, mood), origin - feet, HERO_SCALE, MORNING)
	draw_set_transform(Vector2.ZERO)
	var stem_top := feet + Vector2(0, -46 * HERO_SCALE - 40.0)
	draw_line(feet + Vector2(0, -42 * HERO_SCALE), stem_top, Color("#7a9a4a"), 4.0)
	draw_circle(stem_top, 5.0, Color("#c8b98a"))
	if fall >= 1.0:
		ground_shadow(Vector2(feet.x + 6.0, FLOOR + 4.0), Vector2(40, 8), 0.45)
		dust_puffs(Vector2(feet.x, FLOOR), since - 0.55, 50.0)


func _draw_streak() -> void:
	var streak := int(state.get("streak", 0))
	if streak >= 2:
		label(Vector2(1110, 250), "連投 × %d" % streak, 24, GOLD, 1.0 + 0.08 * pulse(2.0))


# --- Texel painters -----------------------------------------------------------------

func _paint_puff(x: int, y: int) -> Color:
	# A dandelion clock: a soft white ball of seed tufts around a grey heart.
	var at := Vector2(x + 0.5 - 9.0, y + 0.5 - 8.5)
	var r := at.length()
	if r < 2.0:
		return Color("#a89f88")
	var tuft := r < 8.2 - 0.9 * absf(sin(atan2(at.y, at.x) * 6.0))
	if not tuft:
		return Pixels.CLEAR
	if posmod(int(atan2(at.y, at.x) / TAU * 24.0), 2) == 0 and r < 6.5:
		return Color("#d8d2c0")
	return Pixels.lit(SEED, -(at.x + at.y) / 16.0, x, y)


func _paint_mailbox(x: int, y: int) -> Color:
	# A red tin mailbox with a rounded lid, a dark slot and a brass latch.
	var at := Vector2(x + 0.5, y + 0.5)
	if y < 3:
		var dome := (at.x - 6.5) / 6.5
		if absf(dome) > sqrt(maxf(0.0, 1.0 - pow((3.0 - at.y) / 3.0, 2.0))) + 0.05:
			return Pixels.CLEAR
		return Pixels.lit(TIN, 0.6 - y * 0.2, x, y)
	if y == 4 and x >= 3 and x <= 9:
		return Color("#2a1a1a")
	if y == 7 and x == 6:
		return Color("#d9a64e")
	return Pixels.grainy(Pixels.lit(TIN, -(at.x - 6.5) / 13.0, x, y), x, y, 0.05)


func _paint_flag(x: int, y: int, frame: int) -> Color:
	# A little flag on a pole that flaps: frame changes the cloth's ripple.
	if x == 0:
		return Color("#5a4a3a")
	var ripple: int = [0, 1, 0][frame] if x % 2 == 0 else [1, 0, 1][frame]
	if y >= ripple and y <= 4 + ripple:
		return Pixels.lit(Color("#ffd166"), 0.3 - y * 0.12, x, y)
	return Pixels.CLEAR


func _paint_pot(x: int, y: int) -> Color:
	var middle := 8.0
	if y < 2:
		return Pixels.grainy(SOIL if y == 0 and absf(x + 0.5 - middle) < 6.0 else CLAY.lightened(0.12), x, y, 0.1)
	var half := 8.0 - (y - 2) * 0.35
	if absf(x + 0.5 - middle) > half:
		return Pixels.CLEAR
	return Pixels.grainy(Pixels.lit(CLAY, -(x + 0.5 - middle) / half * 0.8, x, y), x, y, 0.07)


func _paint_cactus(x: int, y: int, top: bool) -> Color:
	# Ribbed cactus body with spines; the top is a dome with a pink flower.
	var across := (x + 0.5 - 5.0) / 5.0
	if top:
		var dome := Vector2(across, (y + 0.5 - 6.0) / 4.5)
		if y <= 1 and x >= 4 and x <= 5:
			return Color("#f2a7b8")
		if dome.length() > 1.0:
			return Pixels.CLEAR
	if x == 2 or x == 7:
		return CACTUS.darkened(0.25)
	if (x + y) % 4 == 0:
		return Color("#e8e2c8")
	return Pixels.lit(CACTUS, -across * 0.7, x, y)


func _paint_basket(x: int, y: int) -> Color:
	# Ivy spilling over a woven basket, trailing strands below it.
	var at := Vector2(x + 0.5 - 8.0, y + 0.5)
	if y < 5:
		var bush := Vector2(at.x / 8.0, (y - 4.0) / 4.0)
		if bush.length() < 1.0:
			return Pixels.lit(IVY, -bush.y * 0.5 - bush.x * 0.2, x, y)
		return Pixels.CLEAR
	if y < 10:
		var half := 7.5 - (y - 5) * 0.6
		if absf(at.x) > half:
			return Pixels.CLEAR
		return Pixels.wood(Color("#9a7a4a"), x, y, 2, (x + y) % 2 == 0)
	if x % 3 == 1 and y < 10 + int(Pixels.noise(x, 1, 3) * 4.0):
		return IVY.darkened(0.15)
	return Pixels.CLEAR


func _paint_grate(x: int, y: int) -> Color:
	if y == 0:
		return IRON.lightened(0.25)
	if x % 3 == 0:
		return IRON.darkened(0.3)
	return Color("#e0884a") if y == 2 else IRON


func _paint_nozzle(x: int, y: int) -> Color:
	var at := Vector2(x + 0.5 - 4.0, y + 0.5)
	if y < 3 and absf(at.x) < 2.0:
		return Pixels.lit(Color("#d9a64e"), -at.x * 0.3, x, y)
	if y >= 3 and absf(at.x) < 4.0 - (5 - y) * 0.6:
		return Pixels.lit(Color("#c9953e"), -at.x * 0.2, x, y)
	return Pixels.CLEAR


func _paint_letter(x: int, y: int) -> Color:
	# An envelope with a red seal.
	if x == 3 and y == 3 or x == 4 and y == 3:
		return Color("#c8483e")
	if y == x / 2 or y == (7 - x) / 2:
		return PAPER.darkened(0.2)
	return Pixels.grainy(PAPER, x, y, 0.04)
