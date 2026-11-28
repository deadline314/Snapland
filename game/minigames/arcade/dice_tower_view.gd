extends "res://game/minigames/arcade/arcade_view.gd"
## Picture for 骰塔改道: a painted toy dice tower stands on the workshop bench:
## red lacquered sides with yellow trim and brass caps, a shingled roof with a
## brass funnel on top and a stepped base with an arched mouth. Its glass front
## shows the plank back wall studded with brass pegs, the coiled springs and
## the spinning flapper. The tower leans as it is tipped. Chunky ivory dice
## tumble down inside and shoot out onto a stitched felt tray of five turned
## cups with brass number plaques. A wrong cup bounces the die onto the island
## traveller (arcade_hero), who comes up with a bump printed with its pips.
## Baked pixel art in the backdrop's dusk palette.

const Hero = preload("res://game/minigames/arcade/arcade_hero.gd")
const YARD_ART := "res://assets/world/toy-clockwork-yard.webp"
const BENCH_TOP := 430.0
## Bottom middle of the tower, the point it leans about.
const BASE := Vector2(640, 548)
const TOWER := Vector2i(68, 98)
## The shaft inside the tower, relative to BASE.
const SHAFT := Rect2(-100, -324, 200, 300)
const LEAN := 0.17
const TRAY := Rect2(296, 572, 688, 76)
const CUP := Vector2i(24, 18)
const DIE := Vector2i(13, 13)
const SPRING := Vector2i(10, 9)
const HERO_FEET := Vector2(1150, 668)
const HERO_SCALE := 3.0
const WOOD := Color("#7a5238")
const PINE := Color("#d2a46a")
const WALNUT := Color("#8a5a3a")
const BRASS := Color("#c9953e")
const FELT := Color("#3f6f5a")
const LACQUER_RED := Color("#b8483a")
const TRIM := Color("#e0b04a")
const SHINGLE := Color("#5b6f9a")
const IVORY := Color("#f3ead6")
const DARK := Color("#2b2440")
const LABEL := Color("#efe0bc")
const PIPS := {1: [Vector2(0, 0)], 2: [Vector2(-1, -1), Vector2(1, 1)], 3: [Vector2(-1, -1), Vector2(0, 0), Vector2(1, 1)],
	4: [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)], 5: [Vector2(-1, -1), Vector2(1, -1), Vector2(0, 0), Vector2(-1, 1), Vector2(1, 1)]}
const DUSK := Color(1.0, 0.93, 0.86)

var _has_art := false
var _tower: ImageTexture
var _cup: ImageTexture
var _cup_front: ImageTexture
var _felt: ImageTexture
var _spring: ImageTexture
var _dice: Dictionary = {}


func _init() -> void:
	super()
	word_anchor = Vector2(250, 330)


func _ready() -> void:
	_has_art = use_backdrop_art(YARD_ART, Rect2(260, 0, 1157, 651), Color(0.58, 0.52, 0.58))
	_tower = Pixels.bake("dice-tower", TOWER, _paint_tower)
	_cup = Pixels.bake("dice-cup", CUP, _paint_cup.bind(true))
	_cup_front = Pixels.bake("dice-cup-front", CUP, _paint_cup.bind(false))
	var felt_size := Vector2i(int(TRAY.size.x / TEXEL), int(TRAY.size.y / TEXEL))
	_felt = Pixels.bake("dice-felt", felt_size, _paint_felt.bind(felt_size))
	_spring = Pixels.bake("dice-spring", SPRING, func(x: int, y: int) -> Color:
		# A brass coil on a wall plate with a red push pad.
		if x < 2:
			return Pixels.wood(WALNUT.darkened(0.2), x, y, 2)
		if x >= SPRING.x - 2:
			return Pixels.rounded(Color("#c0503f"), Vector2(0, (y - 4.0) / 4.5)) if y >= 1 and y < SPRING.y - 1 else Pixels.CLEAR
		if y < 2 or y >= SPRING.y - 2:
			return Pixels.CLEAR
		if (x + y) % 3 == 0:
			return BRASS.lightened(0.3)
		return Pixels.rounded(BRASS, Vector2(0, (y - 4.0) / 2.5)) if x % 2 == 0 else BRASS.darkened(0.35))
	for pips in range(1, 6):
		_dice[pips] = Pixels.bake("dice-die|%d" % pips, DIE, _paint_die.bind(pips))


func _draw_backdrop() -> void:
	if not _has_art:
		draw_rect(Rect2(Vector2.ZERO, DESIGN), Color("#3a2c2a"))
	bench(BENCH_TOP, WOOD)
	vignette()


func _draw_scene() -> void:
	if not state.has("dice"):
		return
	_draw_tower()
	_draw_tray()
	for die: Dictionary in state.dice:
		match str(die.state):
			"roll":
				_draw_rolling(die)
			"cup":
				_draw_cupped(die)
	_draw_cup_fronts()
	_draw_hero()
	for die: Dictionary in state.dice:
		if str(die.state) == "bonk":
			_draw_bonk(die)
	_draw_streak()


# --- Tower --------------------------------------------------------------------

func _lean() -> float:
	return float(state.get("tilt", 0.0)) * LEAN


## A point in the tower's frame (relative to BASE) on screen, leaned.
func _in_tower(local: Vector2) -> Vector2:
	return BASE + local.rotated(_lean())


func _shaft_point(x: float, y: float) -> Vector2:
	return _in_tower(Vector2(SHAFT.position.x + x * SHAFT.size.x, SHAFT.position.y + y * SHAFT.size.y))


func _draw_tower() -> void:
	ground_shadow(BASE + Vector2(14, 4), Vector2(TOWER.x * 2.4, 16), 0.42)
	draw_set_transform(BASE, _lean(), Vector2.ONE)
	cast_shadow(_tower, Vector2(-TOWER.x * 0.5, -TOWER.y) * TEXEL, Vector2(10, 8), TEXEL, 0.18)
	stamp(_tower, Vector2(-TOWER.x * 0.5, -TOWER.y) * TEXEL, TEXEL, DUSK)
	# Springs on the walls.
	for spring: Dictionary in state.get("springs", []):
		var side := float(spring.side)
		var y := SHAFT.position.y + float(spring.y) * SHAFT.size.y
		var x := SHAFT.position.x if side < 0.0 else SHAFT.end.x
		draw_set_transform_matrix(Transform2D(_lean(), BASE) * Transform2D(0.0, Vector2(-1.0 if side > 0.0 else 1.0, 1.0), 0.0, Vector2(x, y)))
		stamp(_spring, Vector2(0, -SPRING.y * 2.0), TEXEL, DUSK)
		draw_set_transform(BASE, _lean(), Vector2.ONE)
	# The flapper spins about the middle of the shaft.
	if bool(state.get("flapper", false)):
		var centre := Vector2(0, SHAFT.position.y + float(state.get("flapper_y", 0.55)) * SHAFT.size.y)
		var turn := float(state.get("flapper_phase", 0.0))
		var arm := Vector2(cos(turn), sin(turn) * 0.35) * 46.0
		draw_line(centre - arm + Vector2(3, 4), centre + arm + Vector2(3, 4), Color(SPRITE_SHADE, 0.35), 12.0)
		draw_line(centre - arm, centre + arm, WALNUT.darkened(0.3), 12.0)
		draw_line(centre - arm, centre + arm, PINE.darkened(0.05), 8.0)
		draw_circle(centre, 8.0, DARK)
		draw_circle(centre, 6.0, BRASS)
	draw_set_transform(Vector2.ZERO)
	# Falling dice tumble inside the shaft, behind the glass.
	for die: Dictionary in state.dice:
		if str(die.state) == "fall":
			var at := _shaft_point(float(die.x), float(die.y))
			var spin := 0.0 if reduced_motion else float(die.y) * 9.0 + float(die.id)
			_stamp_die(int(die.pips), at, spin)
	_draw_glass()


## A pane of glass over the shaft: a faint tint, two slanted sheen streaks and a lit inner lip.
func _draw_glass() -> void:
	draw_set_transform(BASE, _lean(), Vector2.ONE)
	draw_rect(SHAFT, Color(0.86, 0.94, 1.0, 0.07))
	for streak: Vector2 in [Vector2(0.12, 26.0), Vector2(0.3, 10.0)]:
		var x := SHAFT.position.x + SHAFT.size.x * streak.x
		var slant := 70.0
		draw_colored_polygon(PackedVector2Array([Vector2(x, SHAFT.position.y), Vector2(x + streak.y, SHAFT.position.y),
			Vector2(x + streak.y - slant, SHAFT.position.y + SHAFT.size.y * 0.45), Vector2(x - slant, SHAFT.position.y + SHAFT.size.y * 0.45)]), Color(1, 1, 1, 0.1))
	draw_rect(Rect2(SHAFT.position, Vector2(SHAFT.size.x, 4)), Color(1, 1, 1, 0.18))
	draw_rect(Rect2(SHAFT.position, Vector2(4, SHAFT.size.y)), Color(1, 1, 1, 0.12))
	draw_set_transform(Vector2.ZERO)


func _stamp_die(pips: int, at: Vector2, angle := 0.0, scale_factor := 1.0) -> void:
	draw_set_transform(at + Vector2(5, 7), angle, Vector2.ONE * scale_factor)
	draw_rect(Rect2(-Vector2(DIE) * TEXEL * 0.45, Vector2(DIE) * TEXEL * 0.9), Color(SPRITE_SHADE, 0.22))
	draw_set_transform(at, angle, Vector2.ONE * scale_factor)
	stamp(_dice[pips], -Vector2(DIE) * TEXEL * 0.5, TEXEL, DUSK)
	draw_set_transform(Vector2.ZERO)


# --- Tray and cups --------------------------------------------------------------

func _tray_point(x: float) -> Vector2:
	return Vector2(TRAY.position.x + x * TRAY.size.x, TRAY.position.y + 18.0)


func _draw_tray() -> void:
	ground_shadow(TRAY.get_center() + Vector2(12, TRAY.size.y * 0.5 + 10.0), Vector2(TRAY.size.x * 0.55, 14), 0.42)
	panel(TRAY.grow(12.0), "planks", WALNUT, Color(0, 0, 0, 0), TEXEL, DUSK)
	stamp(_felt, TRAY.position, TEXEL, DUSK)
	# Brass corner brackets on the rim.
	for corner: Vector2 in [TRAY.position, Vector2(TRAY.end.x, TRAY.position.y), Vector2(TRAY.position.x, TRAY.end.y), TRAY.end]:
		var spot := corner + (corner - TRAY.get_center()).sign() * 8.0
		draw_rect(Rect2(spot - Vector2(9, 9), Vector2(18, 18)), BRASS.darkened(0.45))
		draw_rect(Rect2(spot - Vector2(7, 7), Vector2(14, 14)), BRASS)
		draw_rect(Rect2(spot - Vector2(7, 7), Vector2(6, 4)), BRASS.lightened(0.4))
	for pips in range(1, int(state.get("cups", 5)) + 1):
		var at := _tray_point((pips - 0.5) / 5.0)
		ground_shadow(at + Vector2(6, 16), Vector2(CUP.x * 2.0, 8), 0.4)
		stamp(_cup, _cup_origin(at), TEXEL, DUSK)


func _cup_origin(at: Vector2) -> Vector2:
	return at - Vector2(CUP.x * 0.5, CUP.y - 7) * TEXEL


## The cups' bodies go over dice sitting in them, each with a brass number plaque.
func _draw_cup_fronts() -> void:
	for pips in range(1, int(state.get("cups", 5)) + 1):
		var at := _tray_point((pips - 0.5) / 5.0)
		stamp(_cup_front, _cup_origin(at), TEXEL, DUSK)
		var plaque := Rect2(at.x - 30.0, at.y + 14.0, 60, 28)
		draw_rect(Rect2(plaque.position + Vector2(3, 4), plaque.size), Color(SPRITE_SHADE, 0.4))
		panel(plaque, "enamel", BRASS, BRASS.darkened(0.3), 3.0, DUSK)
		label(plaque.position + Vector2(17, 14), str(pips), 22, DARK, 1.0, 1.0, false)
		_pip_face(plaque.position + Vector2(42, 14), pips, 2.8, DARK)


func _pip_face(centre: Vector2, pips: int, size: float, color: Color) -> void:
	for spot: Vector2 in PIPS[pips]:
		draw_rect(Rect2(centre + spot * size * 2.0 - Vector2(size, size) * 0.5 - Vector2(size, size) * 0.25, Vector2(size, size) * 1.5), color)


func _draw_rolling(die: Dictionary) -> void:
	var since := age(float(die.at))
	var t := clampf(since / float(state.get("roll_seconds", 0.35)), 0.0, 1.0)
	var mouth := _in_tower(Vector2(0, -16))
	var land := _tray_point(float(die.tray_x)) + Vector2(0, -6)
	var at := mouth.lerp(land, t) + Vector2(0, -50.0 * sin(t * PI))
	_stamp_die(int(die.pips), at, 0.0 if reduced_motion else t * 6.0)


func _draw_cupped(die: Dictionary) -> void:
	var since := age(float(die.at))
	var at := _tray_point(float(die.tray_x)) + Vector2(0, -8.0 + 10.0 * smoothstep(0.0, 0.2, since))
	_stamp_die(int(die.pips), at)
	if since < 0.5:
		glint(at, 26.0, 99.0, -since)


func _draw_bonk(die: Dictionary) -> void:
	var since := age(float(die.at))
	var t := clampf(since / 0.5, 0.0, 1.0)
	var from := _tray_point(float(die.tray_x)) + Vector2(0, -10)
	var head := HERO_FEET + Vector2(0, -44 * HERO_SCALE)
	var at := from.lerp(head, t) + Vector2(0, -160.0 * sin(t * PI))
	if t < 1.0:
		_stamp_die(int(die.pips), at, 0.0 if reduced_motion else t * 10.0)
	else:
		# It bounces off and away so the print on the forehead shows.
		var drop := clampf((since - 0.5) / 0.3, 0.0, 1.0)
		_stamp_die(int(die.pips), head + Vector2(-40.0 - 70.0 * drop, -30.0 * sin(drop * PI) + 130.0 * drop * drop), 0.0 if reduced_motion else drop * 5.0)


func _draw_hero() -> void:
	var tilt := float(state.get("tilt", 0.0))
	var bonked := age(float(state.get("bonk_at", -99.0)))
	var hit := bonked >= 0.5 and bonked < 3.0
	var pose := &"idle"
	if tilt < -0.3:
		pose = &"left"
	elif tilt > 0.3:
		pose = &"right"
	var mood := "shocked" if hit and bonked < 1.4 else ("sorry" if hit else "plain")
	var stretch := squash(bonked - 0.5, 0.3, 0.32)
	ground_shadow(HERO_FEET + Vector2(6, 2), Vector2(56, 13), 0.42)
	draw_set_transform(HERO_FEET, 0.0, stretch)
	stamp(Hero.texture(pose, true, mood), -Vector2(20, 46) * HERO_SCALE, HERO_SCALE, DUSK)
	if hit:
		# A bump rises on the traveller's head with the die's pips printed on it.
		var swell := pop_in(bonked - 0.5, 0.2)
		var bump := Vector2(4, -45 * HERO_SCALE)
		draw_circle(bump + Vector2(2, 3), 19.0 * swell, Color(SPRITE_SHADE, 0.4))
		draw_circle(bump, 19.0 * swell, Color("#7a2e3a"))
		draw_circle(bump, 16.0 * swell, Color("#f08c8c"))
		draw_circle(bump + Vector2(-5, -6), 6.0 * swell, Color("#ffc4c4"))
		if swell > 0.8:
			_pip_face(bump, int(state.get("bonk_pips", 1)), 3.4, DARK)
	draw_set_transform(Vector2.ZERO)
	if hit and bonked < 1.6:
		dust_puffs(HERO_FEET + Vector2(0, -150), bonked - 0.5, 40.0)


func _draw_streak() -> void:
	var streak := int(state.get("streak", 0))
	if streak >= 2:
		label(Vector2(1080, 250), "連續進杯 × %d" % streak, 26, GOLD, 1.0 + 0.08 * pulse(2.0))


# --- Texel painters -------------------------------------------------------------

func _paint_tower(x: int, y: int) -> Color:
	var at := Vector2(x + 0.5, y + 0.5)
	var middle := TOWER.x * 0.5
	# A shingled roof with a brass funnel where the dice go in.
	if y < 14:
		if y < 5 and absf(at.x - middle) < 6.0:
			if absf(at.x - middle) < 3.5 and y >= 1:
				return Color("#1d1420")
			return Pixels.rounded(BRASS, Vector2((at.x - middle) / 6.0, -0.3))
		var reach := 7.0 + (y - 3) * 3.0
		if y < 3 or absf(at.x - middle) > reach:
			return Pixels.CLEAR
		if y == 13:
			return LACQUER_RED.darkened(0.45)
		return Pixels.shingle(SHINGLE, x, y, 5, 3)
	# A yellow cornice under the eaves.
	if y < 17:
		return TRIM.lightened(0.2) if y == 14 else (TRIM if y == 15 else TRIM.darkened(0.35))
	# A stepped base with an arched mouth.
	if y >= TOWER.y - 6:
		if absf(at.x - middle) < 10.0:
			var arch := Vector2((at.x - middle) / 10.0, (at.y - (TOWER.y - 4)) / 5.0)
			if arch.y > 0.0 or arch.length() < 1.0:
				return Color("#1d1420")
		if y == TOWER.y - 6:
			return TRIM
		return Pixels.wood(LACQUER_RED.darkened(0.25), x, y, 8, false)
	var shaft := Rect2(9, 17, 50, 75)
	if shaft.has_point(at):
		# The plank back wall, lit from the open top, studded with brass pegs.
		var row := int((at.y - 22.0) / 12.0 + 0.5)
		var shift := 6.0 if row % 2 == 1 else 0.0
		var peg := Vector2(15.0 + shift + 12.0 * roundf((at.x - 15.0 - shift) / 12.0), 22.0 + 12.0 * row)
		var off := at - peg
		var inside := row >= 0 and peg.x > 11.0 and peg.x < 57.0 and peg.y < 89.0
		if inside and off.length() < 1.6:
			return Pixels.rounded(BRASS, off / 1.6)
		if inside and off.length() < 2.3 and off.y > 0.4:
			return Color("#3a2630")
		var light := 0.16 * (1.0 - (at.y - shaft.position.y) / shaft.size.y)
		return Pixels.wood(Color("#5a3a40").lightened(light), x, y, 7)
	# Lacquered red sides with yellow trim bands and brass corner caps.
	if (x < 2 or x >= TOWER.x - 2) and (y < 21 or y >= TOWER.y - 10):
		return Pixels.rounded(BRASS, Vector2(0.6 if x < 2 else -0.6, -0.3))
	if (y - 17) % 22 < 2:
		return TRIM.lightened(0.15) if (y - 17) % 22 == 0 else TRIM.darkened(0.2)
	if shaft.grow(1.0).has_point(at):
		return TRIM.darkened(0.25)
	var side := (at.x - (4.5 if x < middle else TOWER.x - 4.5)) / 4.5
	return Pixels.grainy(Pixels.rounded(LACQUER_RED, Vector2(side * 0.8, -0.2)), x, y, 0.07)


func _paint_cup(x: int, y: int, back: bool) -> Color:
	# A turned wooden cup: the dark mouth and back rim behind, the banded body in front.
	var at := Vector2(x + 0.5, y + 0.5)
	var mouth := (at - Vector2(CUP.x * 0.5, 4.5)) / Vector2(CUP.x * 0.5 - 0.5, 4.0)
	if back:
		if mouth.length() <= 1.0:
			return Color("#2a1d24").lightened(0.06 * (at.y / 5.0)) if mouth.length() < 0.8 else PINE.lightened(0.25)
		return Pixels.CLEAR
	if mouth.length() <= 1.0:
		return PINE.lightened(0.25) if mouth.length() >= 0.8 and at.y > 4.5 else Pixels.CLEAR
	if y < 5:
		return Pixels.CLEAR
	var taper := 0.5 + (y - 5) * 0.12
	if x < taper or x >= CUP.x - taper:
		return Pixels.CLEAR
	var across := (at.x - CUP.x * 0.5) / (CUP.x * 0.5 - taper)
	if y == 10 or y == 14:
		return Pixels.rounded(WALNUT, Vector2(across, -0.3))
	return Pixels.wood(Pixels.rounded(PINE, Vector2(across, -0.2)), x, y, 6, false, 2)


func _paint_felt(x: int, y: int, size: Vector2i) -> Color:
	# Green baize with a fine nap, darker toward the back, and a stitched border.
	var edge := mini(mini(x, size.x - 1 - x), mini(y, size.y - 1 - y))
	if edge == 1 and (x + y) % 3 != 0:
		return FELT.lightened(0.35)
	var tone := FELT.darkened(0.25 * (1.0 - float(y) / size.y))
	if edge == 0:
		tone = tone.darkened(0.3)
	return Pixels.grainy(tone.lightened(0.06 * Pixels.noise(x / 2, y, 5)), x, y, 0.12)


func _paint_die(x: int, y: int, pips: int) -> Color:
	# A chunky ivory die: rounded corners, big pips with a glint, lit top-left.
	var at := Vector2(x + 0.5, y + 0.5)
	var corner := Vector2(minf(at.x, DIE.x - at.x), minf(at.y, DIE.y - at.y))
	if corner.x + corner.y < 2.2:
		return Pixels.CLEAR
	var middle := DIE.x * 0.5
	for spot: Vector2 in PIPS[pips]:
		var pip := Vector2(middle, middle) + spot * 3.4
		var off := at - pip
		if absf(off.x) < 1.25 and absf(off.y) < 1.25:
			return Color("#5a4a5e") if off.x < -0.3 and off.y < -0.3 else DARK
	var tone := Pixels.rounded(IVORY, (at - Vector2(middle, middle)) / middle)
	if at.x + at.y < 6.0:
		tone = tone.lightened(0.08)
	return tone
