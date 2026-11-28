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
const BOX := Vector2i(26, 15)
const FOLDED := Vector2i(30, 7)
const BLOCK := Vector2i(10, 10)
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


func _init() -> void:
	super()
	word_anchor = Vector2(820, 280)


func _ready() -> void:
	_has_art = use_backdrop_art(YARD_ART, Rect2(60, 0, 1157, 651), Color(0.58, 0.52, 0.58))
	_box = Pixels.bake("kart-box", BOX, _paint_box.bind(false))
	_folded = Pixels.bake("kart-folded", FOLDED, _paint_box.bind(true))
	for paint in PAINTS.size():
		_blocks.append(Pixels.bake("kart-block|%d" % paint, BLOCK, _paint_block.bind(PAINTS[paint])))


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


## A kicker of stacked blocks whose top edge slopes up to the lip at `x`.
func _draw_kicker(x: float, launch: float) -> void:
	var rise := clampf(-launch, 0.1, 0.8)
	_wedge(x, -1.0, rise, 5)


## The landing: a downhill ramp of blocks, or a seesaw plank on a fulcrum.
func _draw_landing(jump: Dictionary, x: float) -> void:
	if str(jump.kind) == "seesaw":
		var angle := float(state.get("target", float(jump.land)))
		if str(state.get("phase", "")) != "air":
			angle = float(jump.flip)
		var pivot := Vector2(x + 140.0, GROUND_Y - 60.0)
		ground_shadow(pivot + Vector2(0, 62), Vector2(60, 10), 0.4)
		for row in 2:
			stamp(_blocks[2], pivot + Vector2(-BLOCK.x * 2.0, 6.0 + row * BLOCK.y * TEXEL * 0.6), TEXEL, DUSK)
		draw_set_transform(pivot, angle, Vector2.ONE)
		panel(Rect2(-180, -16, 360, 22), "planks", PINE, Color(0, 0, 0, 0), TEXEL, DUSK)
		draw_set_transform(Vector2.ZERO)
		return
	_wedge(x, 1.0, clampf(float(jump.land), 0.05, 0.8), 7)


## A ramp of blocks starting at `x` going `side` (−1 back to a lip, 1 ahead
## downhill) and rising by `slope` per pixel, `count` blocks long.
func _wedge(x: float, side: float, slope: float, count: int) -> void:
	var step := BLOCK.x * TEXEL
	for index in count:
		var along := (index + 0.5) * step
		var height := along * slope if side < 0.0 else (count * step - along) * slope
		var column := x + (side * along if side > 0.0 else -along)
		var rows := int(height / (BLOCK.y * TEXEL)) + 1
		for row in rows:
			stamp(_blocks[(index + row) % PAINTS.size()], Vector2(column - step * 0.5, GROUND_Y - row * BLOCK.y * TEXEL - 34.0 + 4.0), TEXEL, DUSK)
	# The ramp's surface: a lit plank laid along the top.
	var low := Vector2(x + side * count * step, GROUND_Y - 30.0) if side > 0.0 else Vector2(x - count * step, GROUND_Y - 30.0)
	var high := Vector2(x, GROUND_Y - 30.0 - count * step * slope)
	draw_line(low + Vector2(0, 5), high + Vector2(0, 5), Color(SPRITE_SHADE, 0.45), 16.0)
	draw_line(low, high, PINE.darkened(0.3), 14.0)
	draw_line(low + Vector2(0, -2), high + Vector2(0, -2), PINE.lightened(0.1), 8.0)
	draw_line(low + Vector2(0, -5), high + Vector2(0, -5), PINE.lightened(0.45), 2.0)
	if side > 0.0:
		# Chevrons down the landing plank show which way it slopes.
		for chevron in 3:
			var spot := high.lerp(low, 0.25 + chevron * 0.22) + Vector2(0, -1)
			var along := (low - high).normalized()
			var across := along.orthogonal() * 7.0
			draw_line(spot - along * 6.0 + across, spot + along * 4.0, GOLD, 3.0)
			draw_line(spot - along * 6.0 - across, spot + along * 4.0, GOLD, 3.0)


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
	stamp(Hero.texture(pose, true, mood), Vector2(-20, -46) * HERO_SCALE + Vector2(-6, -26), HERO_SCALE, DUSK)
	stamp(_box, Vector2(-BOX.x * 0.5, -BOX.y) * TEXEL, TEXEL, DUSK)
	for wheel: float in [-34.0, 34.0]:
		var spin := float(state.get("travelled", 0.0)) * 12.0
		draw_circle(Vector2(wheel, 2), 13.0, DARK)
		draw_circle(Vector2(wheel, 2), 11.0, CAP)
		draw_circle(Vector2(wheel - 2, 0), 6.0, CAP.lightened(0.3))
		for rib in 4:
			var ridge := Vector2.from_angle(spin + rib * TAU / 4.0) * 10.0
			draw_line(Vector2(wheel, 2) + ridge * 0.6, Vector2(wheel, 2) + ridge, CAP.darkened(0.4), 2.0)
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
	var size := FOLDED if folded else BOX
	var at := Vector2(x + 0.5, y + 0.5)
	if folded:
		# A flattened box: two layers of card with a dark crease between.
		if y == 3:
			return CARD.darkened(0.5)
		if x < 1 and y < 3:
			return Pixels.CLEAR
		return Pixels.grainy(CARD.darkened(0.08 if y > 3 else 0.0), x, y, 0.12)
	# Flaps folded out at the top, corrugated sides, a tape strip and a printed arrow.
	if y < 2:
		return Pixels.grainy(CARD.lightened(0.1), x, y, 0.1) if x < 5 or x >= size.x - 5 else Pixels.CLEAR
	if y == 2:
		return CARD.darkened(0.35)
	if x >= size.x / 2 - 2 and x < size.x / 2 + 2:
		return Pixels.grainy(TAPE, x, y, 0.08)
	if x >= 3 and x < 7 and y >= 6 and y < 10 and absf(at.x - 5.0) <= (at.y - 6.0) * 0.6 + 0.4:
		return Color("#5a3a2a")
	var tone := Pixels.rounded(CARD, Vector2((at.x - size.x * 0.5) / (size.x * 0.5) * 0.6, (at.y - 8.0) / 8.0))
	return tone.darkened(0.08) if x % 3 == 0 else tone


func _paint_block(x: int, y: int, paint: Color) -> Color:
	# A painted wooden block with a natural-wood rim.
	if x == 0 or y == 0 or x == BLOCK.x - 1 or y == BLOCK.y - 1:
		return PINE.darkened(0.15) if x > 0 and y > 0 else PINE.lightened(0.1)
	return Pixels.wood(paint.lerp(PINE, 0.2), x, y, 5, false, 3)
