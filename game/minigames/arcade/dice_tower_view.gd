extends "res://game/minigames/arcade/arcade_view.gd"
## Picture for 骰塔改道: a tall wooden dice tower with crenellations and brass
## corners stands on the workshop bench; its front is cut away so the shaft,
## the coiled springs on its walls and the spinning flapper show. The tower
## leans as it is tipped. Dice tumble down inside and shoot out of the arched
## mouth onto a green felt tray of five wooden cups painted one to five. A
## wrong cup bounces the die onto the island traveller (arcade_hero), who is
## left with its pips printed on their forehead. Baked pixel art in the
## backdrop's dusk palette.

const Hero = preload("res://game/minigames/arcade/arcade_hero.gd")
const YARD_ART := "res://assets/world/toy-clockwork-yard.webp"
const BENCH_TOP := 430.0
## Bottom middle of the tower, the point it leans about.
const BASE := Vector2(640, 548)
const TOWER := Vector2i(68, 98)
## The shaft inside the tower, relative to BASE.
const SHAFT := Rect2(-100, -364, 200, 344)
const LEAN := 0.17
const TRAY := Rect2(296, 572, 688, 76)
const CUP := Vector2i(22, 16)
const DIE := Vector2i(10, 10)
const SPRING := Vector2i(10, 9)
const HERO_FEET := Vector2(1150, 668)
const HERO_SCALE := 3.0
const WOOD := Color("#7a5238")
const PINE := Color("#d2a46a")
const WALNUT := Color("#8a5a3a")
const BRASS := Color("#c9953e")
const FELT := Color("#3f6f5a")
const IVORY := Color("#f3ead6")
const DARK := Color("#2b2440")
const LABEL := Color("#efe0bc")
const PIPS := {1: [Vector2(0, 0)], 2: [Vector2(-1, -1), Vector2(1, 1)], 3: [Vector2(-1, -1), Vector2(0, 0), Vector2(1, 1)],
	4: [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)], 5: [Vector2(-1, -1), Vector2(1, -1), Vector2(0, 0), Vector2(-1, 1), Vector2(1, 1)]}
const DUSK := Color(1.0, 0.93, 0.86)

var _has_art := false
var _tower: ImageTexture
var _cup: ImageTexture
var _spring: ImageTexture
var _dice: Dictionary = {}


func _init() -> void:
	super()
	word_anchor = Vector2(250, 330)


func _ready() -> void:
	_has_art = use_backdrop_art(YARD_ART, Rect2(260, 0, 1157, 651), Color(0.58, 0.52, 0.58))
	_tower = Pixels.bake("dice-tower", TOWER, _paint_tower)
	_cup = Pixels.bake("dice-cup", CUP, _paint_cup)
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
	# Falling dice tumble inside the shaft.
	for die: Dictionary in state.dice:
		if str(die.state) == "fall":
			var at := _shaft_point(float(die.x), float(die.y))
			var spin := 0.0 if reduced_motion else float(die.y) * 9.0 + float(die.id)
			_stamp_die(int(die.pips), at, spin)


func _stamp_die(pips: int, at: Vector2, angle := 0.0, scale_factor := 1.0) -> void:
	draw_set_transform(at, angle, Vector2.ONE * scale_factor)
	stamp(_dice[pips], -Vector2(DIE) * TEXEL * 0.5, TEXEL, DUSK)
	draw_set_transform(Vector2.ZERO)


# --- Tray and cups --------------------------------------------------------------

func _tray_point(x: float) -> Vector2:
	return Vector2(TRAY.position.x + x * TRAY.size.x, TRAY.position.y + 18.0)


func _draw_tray() -> void:
	draw_rect(Rect2(TRAY.position + Vector2(8, 12), TRAY.size), Color(SPRITE_SHADE, 0.35))
	panel(TRAY.grow(10.0), "planks", WALNUT, Color(0, 0, 0, 0), TEXEL, DUSK)
	panel(TRAY, "velvet", FELT, Color(0, 0, 0, 0), TEXEL, DUSK)
	for pips in range(1, int(state.get("cups", 5)) + 1):
		var at := _tray_point((pips - 0.5) / 5.0)
		stamp(_cup, at - Vector2(CUP.x * 0.5, CUP.y - 6) * TEXEL, TEXEL, DUSK)


## The cups' front faces go over dice sitting in them.
func _draw_cup_fronts() -> void:
	for pips in range(1, int(state.get("cups", 5)) + 1):
		var at := _tray_point((pips - 0.5) / 5.0)
		var front := Rect2(at.x - CUP.x * 2.0 + 4.0, at.y - 8.0, CUP.x * TEXEL - 8.0, 32)
		panel(front, "planks", PINE.darkened(0.05), Color(0, 0, 0, 0), TEXEL, DUSK)
		_pip_face(front.get_center(), pips, 4.0, DARK)


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
	# Crenellations on top, plank walls with brass corner straps, a cut-away
	# front showing the dark shaft, and an arched mouth at the bottom.
	if y < 4:
		return Pixels.wood(WALNUT.lightened(0.05), x, y, 3) if (x / 6) % 2 == 0 else Pixels.CLEAR
	if y < 6:
		return WALNUT.lightened(0.25) if y == 4 else WALNUT.darkened(0.2)
	var shaft := Rect2(9, 7, 50, 88)
	if shaft.has_point(at):
		# A little drop funnel at the top of the shaft.
		if y < 12 and absf(at.x - TOWER.x * 0.5) > (y - 6) * 2.4 + 6.0:
			return Pixels.wood(PINE.darkened(0.25), x, y, 3, false)
		# The dark back boards of the shaft, lit a little from the open top.
		return Pixels.wood(Color("#4a3038").lightened(0.12 * (1.0 - (at.y - shaft.position.y) / shaft.size.y)), x, y, 7)
	if y >= TOWER.y - 6 and absf(at.x - TOWER.x * 0.5) < 9.0:
		var arch := Vector2((at.x - TOWER.x * 0.5) / 9.0, (at.y - (TOWER.y - 6)) / 6.0)
		if arch.y > 0.0 or arch.length() < 1.0:
			return Color("#1d1420")
	if (x < 3 or x >= TOWER.x - 3) and y % 12 < 2:
		return BRASS.lightened(0.15 if y % 12 == 0 else 0.0)
	if shaft.grow(1.0).has_point(at):
		return WALNUT.darkened(0.35)
	return Pixels.wood(WALNUT, x, y, 6)


func _paint_cup(x: int, y: int) -> Color:
	# A turned wooden cup seen from just above: a dark mouth inside a lit rim.
	var at := Vector2(x + 0.5, y + 0.5)
	var mouth := (at - Vector2(CUP.x * 0.5, 4.0)) / Vector2(CUP.x * 0.5 - 0.5, 3.6)
	if mouth.length() <= 1.0:
		return Color("#2a1d24") if mouth.length() < 0.78 else PINE.lightened(0.2)
	if y > 4 and x >= 1 and x < CUP.x - 1:
		return Pixels.rounded(PINE.darkened(0.1), Vector2((at.x - CUP.x * 0.5) / (CUP.x * 0.5), 0))
	return Pixels.CLEAR


func _paint_die(x: int, y: int, pips: int) -> Color:
	var at := Vector2(x + 0.5, y + 0.5)
	var corner := Vector2(minf(at.x, DIE.x - at.x), minf(at.y, DIE.y - at.y))
	if corner.x < 1.0 and corner.y < 1.0:
		return Pixels.CLEAR
	for spot: Vector2 in PIPS[pips]:
		var pip := Vector2(5.0, 5.0) + spot * 2.6
		if (at - pip).length() < 1.05:
			return DARK
	return Pixels.rounded(IVORY, (at - Vector2(5, 5)) / 5.0)
