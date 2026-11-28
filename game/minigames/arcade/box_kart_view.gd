extends "res://game/minigames/arcade/arcade_view.gd"
## Picture for 紙盒變車: a side view of a toy-block race course on the workshop
## bench. Kickers and landing ramps are stacked painted blocks; a seesaw is a
## plank on a block fulcrum that flops over mid-flight. The traveller
## (arcade_hero) sits in a taped cardboard box on bottle-cap wheels, head and
## arms poking out. A crooked landing folds the box flat, a hand poking out of
## the crease waving a white flag. Baked pixel art in the backdrop's dusk palette.

const Hero = preload("res://game/minigames/arcade/arcade_hero.gd")
const YARD_ART := "res://assets/world/toy-clockwork-yard.webp"
const BENCH_TOP := 470.0
## Where the box sits on screen and the ground line it rolls on.
const CAR_X := 430.0
const GROUND_Y := 590.0
const BOX := Vector2i(28, 17)
const FOLDED := Vector2i(30, 7)
const BLOCK := Vector2i(10, 10)
## The chunky blocks the ramps and jump lips are stacked from.
const RAMP := Vector2i(13, 11)
const CRAYON_RED := Color("#d8423a")
const CRAYON_BLUE := Color("#3f63b0")
const CRAYON_BLACK := Color("#2a2228")
const HERO_SCALE := 2.0
## The car and its driver are drawn a size up so the tilt and the fold read at a glance.
const CAR_SCALE := 1.6
## Screen pixels the course scrolls per unit of travel.
const SCROLL := 320.0
const CARD := Color("#c99a62")
const TAPE := Color("#d9c08a")
const CAP := Color("#c0503f")
const WOOD := Color("#7a5238")
const PINE := Color("#d2a46a")
const DARK := Color("#2b2440")
const LABEL := Color("#efe0bc")
const PAINTS: Array[Color] = [Color("#c0503f"), Color("#4f79a8"), Color("#e0b04a"), Color("#4f8f86")]
const DUSK := Color(1.0, 0.93, 0.86)

var _has_art := false
var _box: ImageTexture
var _folded: ImageTexture
var _blocks: Array[ImageTexture] = []
var _ramp_blocks: Array[ImageTexture] = []
var _lip: ImageTexture


func _init() -> void:
	super()
	word_anchor = Vector2(820, 280)


func _ready() -> void:
	_has_art = use_backdrop_art(YARD_ART, Rect2(60, 0, 1157, 651), Color(0.58, 0.52, 0.58))
	_box = Pixels.bake("kart-box", BOX, _paint_box.bind(false))
	_folded = Pixels.bake("kart-folded", FOLDED, _paint_box.bind(true))
	for paint in PAINTS.size():
		_blocks.append(Pixels.bake("kart-block|%d" % paint, BLOCK, _paint_block.bind(PAINTS[paint], BLOCK)))
		_ramp_blocks.append(Pixels.bake("kart-ramp|%d" % paint, RAMP, _paint_block.bind(PAINTS[paint], RAMP)))
	_lip = Pixels.bake("kart-lip", RAMP, _paint_lip)


func _draw_backdrop() -> void:
	if not _has_art:
		draw_rect(Rect2(Vector2.ZERO, DESIGN), Color("#3a2c2a"))
	bench(BENCH_TOP, WOOD)
	vignette()


func _draw_scene() -> void:
	if not state.has("phase"):
		return
	var phase := str(state.phase)
	_draw_ground()
	var jump: Dictionary = state.get("jump", {})
	var since := age(float(jump.get("at", -99.0)))
	var air := float(jump.get("air", 1.0))
	var p := clampf(since / air, 0.0, 1.0) if phase == "air" else 1.0
	var reach := air * float(state.get("speed", 1.0)) * SCROLL
	if not jump.is_empty():
		_draw_kicker(CAR_X - p * reach - 30.0, float(jump.launch))
		_draw_landing(jump, CAR_X + (1.0 - p) * reach)
	var lift := 0.0
	if phase == "air":
		lift = 4.0 * p * (1.0 - p) * (90.0 + 60.0 * air)
	_draw_car(phase, Vector2(CAR_X, GROUND_Y - lift), float(state.get("pitch", 0.0)))
	_draw_speed()


# --- Course -------------------------------------------------------------------

func _draw_ground() -> void:
	# A runway of blocks along the bench, scrolling by.
	var run := float(state.get("travelled", 0.0)) * SCROLL
	var step := BLOCK.x * TEXEL
	var shift := fposmod(run, step * 4.0)
	ground_shadow(Vector2(640, GROUND_Y + 50.0), Vector2(700, 14), 0.3)
	for index in range(-1, int(DESIGN.x / step) + 2):
		var x := index * step - shift
		var paint := posmod(index + int(run / step), PAINTS.size())
		stamp(_blocks[paint], Vector2(x, GROUND_Y + 4.0), TEXEL, DUSK)


## A kicker of chunky stacked blocks stepping up to a wedge-block lip at `x`.
func _draw_kicker(x: float, launch: float) -> void:
	_ramp(x, -1.0, clampf(-launch, 0.1, 0.8), 5)


## The landing: a downhill stair of blocks, or a seesaw plank on a block fulcrum.
func _draw_landing(jump: Dictionary, x: float) -> void:
	if str(jump.kind) == "seesaw":
		var angle := float(state.get("target", float(jump.land)))
		if str(state.get("phase", "")) != "air":
			angle = float(jump.flip)
		var pivot := Vector2(x + 140.0, GROUND_Y - RAMP.y * TEXEL * 2.0 + 2.0)
		ground_shadow(Vector2(pivot.x + 10.0, GROUND_Y + 4.0), Vector2(70, 12), 0.45)
		for row in 2:
			_stack_block(Vector2(pivot.x - RAMP.x * 2.0, GROUND_Y - row * RAMP.y * TEXEL + 4.0), 2 + row, row == 1)
		draw_set_transform(pivot, angle, Vector2.ONE)
		draw_rect(Rect2(-184, -14, 368, 34), Color(SPRITE_SHADE, 0.4))
		panel(Rect2(-180, -20, 360, 28), "planks", PINE, Color(0, 0, 0, 0), TEXEL, DUSK)
		draw_rect(Rect2(-180, -20, 360, 4), Color(1, 1, 1, 0.18))
		draw_set_transform(Vector2.ZERO)
		return
	_ramp(x, 1.0, clampf(float(jump.land), 0.05, 0.8), 7)


## A stair of chunky blocks from `x`: `side` −1 rises back toward a lip at `x`,
## 1 steps down ahead of `x`; `slope` is the rise per pixel, `count` columns long.
func _ramp(x: float, side: float, slope: float, count: int) -> void:
	var step := RAMP.x * TEXEL
	var tall := RAMP.y * TEXEL
	var tops: Array[Vector2] = []
	var left := x - count * step if side < 0.0 else x
	ground_shadow(Vector2(left + count * step * 0.5 + 16.0, GROUND_Y + 6.0), Vector2(count * step * 0.55, 14), 0.42)
	for index in count:
		var along := (index + 0.5) * step
		var height := along * slope if side < 0.0 else (count * step - along) * slope
		var rows := maxi(1, roundi(height / tall))
		var column := left + index * step
		for row in rows:
			var lit := row == rows - 1
			_stack_block(Vector2(column, GROUND_Y - row * tall + 4.0), index + row, lit)
		tops.append(Vector2(column + step * 0.5, GROUND_Y - rows * tall + 4.0))
	if side < 0.0:
		# The lip: a wedge block on the top of the tallest column, sloping up to the edge.
		var top := tops.back() as Vector2
		stamp(_lip, Vector2(top.x - step * 0.5, top.y - tall), TEXEL, DUSK)
		return
	# Chevrons down the landing stair show which way it slopes.
	var high := tops[0] + Vector2(0, -12)
	var low := tops.back() as Vector2 + Vector2(0, -12)
	var down := (low - high).normalized()
	for chevron in 3:
		var spot := high.lerp(low, 0.2 + chevron * 0.3)
		var across := down.orthogonal() * 8.0
		draw_line(spot - down * 7.0 + across, spot + down * 5.0, DARK, 6.0)
		draw_line(spot - down * 7.0 - across, spot + down * 5.0, DARK, 6.0)
		draw_line(spot - down * 7.0 + across, spot + down * 5.0, GOLD, 3.0)
		draw_line(spot - down * 7.0 - across, spot + down * 5.0, GOLD, 3.0)


## One chunky block with its bottom-left at `at`; the top one of a column shows
## a lit top face, and every block throws a little shadow to its lower right.
func _stack_block(at: Vector2, paint: int, lit_top: bool) -> void:
	var size := Vector2(RAMP) * TEXEL
	draw_rect(Rect2(at + Vector2(8, -size.y + 8), size), Color(SPRITE_SHADE, 0.22))
	stamp(_ramp_blocks[posmod(paint, PAINTS.size())], at - Vector2(0, size.y), TEXEL, DUSK)
	if lit_top:
		var tone := PAINTS[posmod(paint, PAINTS.size())].lerp(PINE, 0.2).lightened(0.3)
		var face := PackedVector2Array([at + Vector2(2, -size.y), at + Vector2(size.x - 2, -size.y), at + Vector2(size.x + 8, -size.y - 8), at + Vector2(12, -size.y - 8)])
		draw_colored_polygon(face, tone)
		draw_polyline(PackedVector2Array([face[3], face[2], face[1]]), tone.darkened(0.45), 2.0)


# --- Car ----------------------------------------------------------------------

func _draw_car(phase: String, at: Vector2, pitch: float) -> void:
	var landed: Dictionary = state.get("landed", {})
	var since := age(float(landed.get("at", -99.0)))
	ground_shadow(Vector2(at.x + 10.0, GROUND_Y + 2.0), Vector2(110.0 * (1.0 - clampf((GROUND_Y - at.y) / 400.0, 0.0, 0.6)), 12), 0.4)
	if phase == "fold":
		_draw_folded(Vector2(at.x, GROUND_Y - 6.0), since)
		return
	var stretch := (squash(since, 0.22, 0.3) if since < 0.4 else Vector2.ONE) * CAR_SCALE
	draw_set_transform(at, pitch, stretch)
	# The traveller sits in the box, head and arms above the rim.
	var pose := &"up" if phase == "air" else &"idle"
	var mood := "tongue" if str(landed.get("grade", "")) == "perfect" and since < 0.8 else ("shocked" if phase == "air" and absf(pitch - float(state.get("target", 0.0))) > float(state.get("good", 0.32)) else "plain")
	stamp(Hero.texture(pose, true, mood), Vector2(-20, -46) * HERO_SCALE + Vector2(-6, -30), HERO_SCALE, DUSK)
	stamp(_box, Vector2(-BOX.x * 0.5, -BOX.y) * TEXEL, TEXEL, DUSK)
	if pose == &"idle":
		# Both hands grip the front rim.
		for hand: float in [-20.0, 14.0]:
			draw_circle(Vector2(hand, -BOX.y * TEXEL + 14.0), 6.0, DARK)
			draw_circle(Vector2(hand, -BOX.y * TEXEL + 14.0), 4.5, Color("#ebb894"))
	var spin := float(state.get("travelled", 0.0)) * 12.0
	for wheel: float in [-36.0, 36.0]:
		# Cardboard discs with crayon rims and spokes.
		var hub := Vector2(wheel, 4)
		draw_circle(hub + Vector2(2, 3), 15.0, Color(SPRITE_SHADE, 0.35))
		draw_circle(hub, 15.0, CARD.darkened(0.45))
		draw_circle(hub, 13.0, CARD.lightened(0.12))
		draw_arc(hub, 10.5, spin, spin + TAU * 0.85, 14, CRAYON_BLACK, 3.0)
		for spoke in 3:
			var reach := Vector2.from_angle(spin + spoke * TAU / 3.0) * 9.0
			draw_line(hub - reach * 0.2, hub + reach, CRAYON_RED, 2.5)
		draw_circle(hub, 3.0, CRAYON_BLACK)
	draw_set_transform(Vector2.ZERO)
	if str(landed.get("grade", "")) == "perfect" and since < 0.4:
		dust_puffs(Vector2(at.x, GROUND_Y), since, 80.0)


## The box folded flat, a hand poking out of the crease waving a white flag.
func _draw_folded(at: Vector2, since: float) -> void:
	var drop := squash(since, 0.35, 0.4) * CAR_SCALE
	draw_set_transform(at, 0.0, drop)
	stamp(_folded, Vector2(-FOLDED.x * 0.5, -FOLDED.y) * TEXEL, TEXEL, DUSK)
	draw_set_transform(Vector2.ZERO)
	dust_puffs(at, since, 90.0)
	if since < 0.25:
		return
	var wave := 0.0 if reduced_motion else 0.35 * sin(since * 10.0)
	var hand := at + Vector2(30, -FOLDED.y * TEXEL * CAR_SCALE + 4.0)
	var top := hand + Vector2.from_angle(-PI * 0.5 + wave) * 100.0
	draw_line(hand, top, DARK, 5.0)
	draw_line(hand, top, PINE.lightened(0.1), 3.0)
	var flutter := 0.0 if reduced_motion else 6.0 * sin(since * 14.0)
	var cloth := PackedVector2Array([top, top + Vector2(60, 8 + flutter), top + Vector2(56, 42 + flutter * 0.5), top + Vector2(2, 36)])
	draw_colored_polygon(cloth, DARK)
	draw_colored_polygon(PackedVector2Array([cloth[0] + Vector2(2, 2), cloth[1] + Vector2(-3, 2), cloth[2] + Vector2(-3, -2), cloth[3] + Vector2(2, -2)]), Color("#f7f1e3"))
	draw_circle(hand, 8.0, DARK)
	draw_circle(hand, 6.0, Color("#ebb894"))
	if since < 1.0:
		label(at + Vector2(-80, -70), "投降～", 22, LABEL, pop_in(since - 0.25, 0.2))


func _draw_speed() -> void:
	var speed := float(state.get("speed", 1.0))
	label(Vector2(1130, 250), "時速 × %.1f" % speed, 24, GOLD if speed > 1.3 else LABEL)
	var streak := int(state.get("streak", 0))
	if streak >= 2:
		label(Vector2(1130, 290), "連續落地 × %d" % streak, 22, GOLD, 1.0 + 0.08 * pulse(2.0))


# --- Texel painters -------------------------------------------------------------

func _paint_box(x: int, y: int, folded: bool) -> Color:
	var at := Vector2(x + 0.5, y + 0.5)
	if folded:
		# A flattened box: two layers of card with a dark crease and a strip of tape.
		var flat := FOLDED
		if y == 3:
			return CARD.darkened(0.5)
		if x < 1 and y < 3:
			return Pixels.CLEAR
		if x >= flat.x / 2 - 2 and x < flat.x / 2 + 1:
			return Pixels.grainy(TAPE.lightened(0.1), x, y, 0.06)
		return Pixels.grainy(CARD.darkened(0.08 if y > 3 else 0.0), x, y, 0.12)
	var size := BOX
	# The four top flaps, folded out and up at a slant.
	if y < 5:
		var left_flap := x < 8 and x >= 4 - y
		var right_flap := x >= size.x - 8 and x < size.x - 4 + y
		if left_flap or right_flap:
			return Pixels.grainy(CARD.lightened(0.18 - y * 0.03), x, y, 0.1) if y > 0 else CARD.darkened(0.2)
		if y == 4 and x >= 8 and x < size.x - 8:
			return Color("#3a2630")
		return Pixels.CLEAR
	if y == 5:
		return CARD.lightened(0.25)
	# Packing tape over the rim and down the front.
	if x >= 6 and x < 9:
		return Pixels.grainy(TAPE.lightened(0.12 if x == 6 else 0.0), x, y, 0.05)
	if y == 6 and x >= 3 and x < size.x - 3:
		return Pixels.grainy(TAPE, x, y, 0.05)
	# A crayon racing number in a scribbled ring.
	var ring := (at - Vector2(18.5, 11.0)).length()
	if absf(ring - 4.3) < 0.7 and Pixels.noise(x, y, 9) > 0.18:
		return CRAYON_RED
	var seven := (y == 9 and x >= 17 and x <= 20) or (y > 9 and y <= 13 and absf(at.x - (20.4 - (at.y - 9.5) * 0.55)) < 0.75)
	if seven and Pixels.noise(x, y, 4) > 0.12:
		return CRAYON_BLUE
	# Crayon speed lines at the back.
	if (y == 10 or y == 13) and x >= 1 and x < 5 and Pixels.noise(x, y, 7) > 0.25:
		return CRAYON_BLUE.lightened(0.15)
	var tone := Pixels.rounded(CARD, Vector2((at.x - size.x * 0.5) / (size.x * 0.5) * 0.6, (at.y - 11.0) / 8.0))
	return tone.darkened(0.08) if x % 3 == 0 else Pixels.grainy(tone, x, y, 0.05)


func _paint_block(x: int, y: int, paint: Color, size: Vector2i) -> Color:
	# A painted wooden block with a natural-wood rim and a little carved star.
	if x == 0 or y == 0 or x == size.x - 1 or y == size.y - 1:
		return PINE.darkened(0.15) if x > 0 and y > 0 else PINE.lightened(0.1)
	if size.x >= 12:
		var star := Vector2(x + 0.5 - size.x * 0.5, y + 0.5 - size.y * 0.5)
		if absf(star.x) + absf(star.y) < 2.0 or (absf(star.x) < 0.6 and absf(star.y) < 3.0) or (absf(star.y) < 0.6 and absf(star.x) < 3.0):
			return LABEL.darkened(0.1)
	return Pixels.wood(paint.lerp(PINE, 0.2), x, y, 5, false, 3)


func _paint_lip(x: int, y: int) -> Color:
	# A wedge block, low on the left and high on the right, for the jump lip.
	var rise := float(x + 1) / RAMP.x * RAMP.y
	if float(RAMP.y - y) > rise:
		return Pixels.CLEAR
	if float(RAMP.y - y) > rise - 1.2:
		return PINE.lightened(0.3)
	return Pixels.wood(PAINTS[2].lerp(PINE, 0.2), x, y, 5, false, 6)
