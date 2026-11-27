extends "res://game/minigames/arcade/arcade_view.gd"
## Picture for 走鋼索: a steel wire high across the tent between two striped
## masts with platforms, the clown on it with his long balance pole, a brass
## spirit level that shows his lean, and everything that pushes him: gusts
## streaming in from a wing, a pigeon landing on a pole end, hats thrown up from
## the audience, and late on the wire bouncing. Every object is baked pixel art
## (arcade_pixels.gd) or a shared material, tinted to the tent's dusk.

const TENT_ART := "res://assets/world/circus-tent.webp"
const FLOOR_TOP := 610.0
const WIRE_Y := 372.0
const UNIT := 4.0
const WOOD := Color("#6b4658")
const WOOD_DARK := Color("#3b2536")
const BRASS := Color("#b0803a")
const STEEL := Color("#c9ccd6")
const TIMBER := Color("#8a5a3c")
const MAST := Color("#b84a4a")
const LEVEL_GLASS := Color("#9fd2b4")
const LAMP := Color(1.0, 0.94, 0.9)
const CLOWN_SIZE := Vector2i(24, 40)
const CLOWN_ORIGIN := Vector2i(12, 39)
const POLE_HALF := 150.0
const LEVEL := Rect2(470, 592, 340, 40)
const MOODS: Array[String] = ["calm", "worried", "shock"]

var _has_tent := false
var _clowns: Dictionary = {}
var _platform: ImageTexture
var _pigeon: ImageTexture
var _hat: ImageTexture
var _weight: ImageTexture
var _crowd: ImageTexture


func _init() -> void:
	super()
	word_anchor = Vector2(640, 232)


func _ready() -> void:
	_has_tent = use_backdrop_art(TENT_ART, Rect2(85, 0, 1366, 768), Color(0.7, 0.64, 0.78))
	for mood in MOODS:
		_clowns[mood] = Pixels.bake_blocks("rope-clown|" + mood, CLOWN_SIZE, CLOWN_ORIGIN, _clown_blocks(mood))
	_platform = Pixels.bake("rope-platform", Vector2i(30, 8), func(x: int, y: int) -> Color:
		if y >= 5 and (x < 3 or x > 26):
			return Pixels.CLEAR
		return Pixels.metal(BRASS, x, y) if y < 2 else Pixels.wood(TIMBER, x, y, 6, false))
	_pigeon = Pixels.bake_blocks("rope-pigeon", Vector2i(12, 9), Vector2i(6, 9), [
		[Rect2(-5, -6, 9, 5), Color("#9aa0b4")], [Rect2(-6, -5, 3, 2), Color("#7c8296")], [Rect2(2, -8, 4, 4), Color("#a8aec2")],
		[Rect2(5, -7, 2, 1), Color("#e0a050")], [Rect2(3, -7, 1, 1), Color("#2b2440")], [Rect2(-1, -4, 4, 2), Color("#7fb0a8")],
		[Rect2(-2, -1, 1, 1), Color("#e07b6a")], [Rect2(1, -1, 1, 1), Color("#e07b6a")]])
	_hat = Pixels.bake_blocks("rope-hat", Vector2i(12, 8), Vector2i(6, 8), [
		[Rect2(-6, -2, 12, 2), Color("#3b3550")], [Rect2(-3, -8, 6, 6), Color("#3b3550")], [Rect2(-3, -4, 6, 1), Color("#c9483d")]])
	_crowd = Pixels.bake("rope-crowd", Vector2i(320, 22), Pixels.crowd)
	_weight = Pixels.bake("rope-weight", Vector2i(7, 7), func(x: int, y: int) -> Color:
		var offset := (Vector2(x, y) + Vector2(0.5, 0.5) - Vector2(3.5, 3.5)) / 3.5
		return Pixels.rounded(BRASS, offset) if offset.length() <= 1.0 else Pixels.CLEAR)


func _draw_backdrop() -> void:
	if not _has_tent:
		draw_rect(Rect2(Vector2.ZERO, DESIGN), Color("#2b1f3a"))
	stage_floor(FLOOR_TOP, WOOD, WOOD_DARK)
	# Dusk gathers below the wire so it reads as a long way down.
	for band in 5:
		draw_rect(Rect2(0, WIRE_Y + 60.0 + band * 36.0, DESIGN.x, 36), Color(0.05, 0.02, 0.09, 0.05 + band * 0.03))
	vignette(0.55)


func _draw_crowd() -> void:
	var bob := 0.0 if reduced_motion else roundf(sin(now * 2.0) * 2.0)
	stamp(_crowd, Vector2(0, DESIGN.y - 80.0 + bob), TEXEL, Color(0.55, 0.48, 0.6))


func _draw_scene() -> void:
	var phase := str(state.get("phase", "walk"))
	var since := age(float(state.get("phase_at", 0.0)))
	_draw_masts()
	_draw_gusts()
	_draw_wire()
	_draw_clown(phase, since)
	_draw_crowd()
	_draw_hats()
	_draw_level()


# --- Rig ----------------------------------------------------------------------

func _wire_from() -> float:
	return float(state.get("wire_from", 150.0))


func _wire_to() -> float:
	return float(state.get("wire_to", 1130.0))


func _bob() -> float:
	return 0.0 if reduced_motion else float(state.get("bounce", 0.0)) * 9.0


## Height of the wire at `x`: it sags under the clown and bobs when it bounces.
func _wire_at(x: float) -> float:
	var walker := float(state.get("walk_x", 150.0))
	var span := _wire_to() - _wire_from()
	var along := clampf((x - _wire_from()) / span, 0.0, 1.0)
	var under := clampf((walker - _wire_from()) / span, 0.01, 0.99)
	var sag := 26.0 * (along / under if along < under else (1.0 - along) / (1.0 - under))
	return WIRE_Y + sag * minf(1.0, 4.0 * under * (1.0 - under) + 0.4) + _bob() * sin(along * PI)


func _draw_masts() -> void:
	for side: float in [-1.0, 1.0]:
		var x := _wire_from() - 30.0 if side < 0.0 else _wire_to() + 30.0
		ground_shadow(Vector2(x, FLOOR_TOP + 30.0), Vector2(60, 9), 0.45)
		panel(Rect2(x - 12.0, WIRE_Y + 20.0, 24, FLOOR_TOP - WIRE_Y + 10.0), "pole", MAST, Pixels.CLEAR, 3.0, LAMP)
		# A rope ladder hangs beside each mast.
		var ladder := x + side * 34.0
		for rail: float in [-10.0, 10.0]:
			draw_line(Vector2(ladder + rail, WIRE_Y + 26.0), Vector2(ladder + rail, FLOOR_TOP + 8.0), INK, 4.0)
			draw_line(Vector2(ladder + rail, WIRE_Y + 26.0), Vector2(ladder + rail, FLOOR_TOP + 8.0), Color("#d9c49a"), 2.0)
		var rung := WIRE_Y + 40.0
		while rung < FLOOR_TOP:
			draw_rect(Rect2(ladder - 12.0, rung - 2.0, 24, 5), INK)
			draw_rect(Rect2(ladder - 10.0, rung - 1.0, 20, 3), TIMBER.lightened(0.15))
			rung += 26.0
		stamp(_platform, Vector2(x - 60.0, WIRE_Y + 4.0), TEXEL, LAMP)
		# A pennant on top of each mast shows the wind.
		var flap := 0.0 if reduced_motion else sin(now * 6.0 + side) * 4.0
		panel(Rect2(x - 4.0, WIRE_Y - 110.0, 8, 114), "pole", BRASS, Pixels.CLEAR, 2.0, LAMP)
		var top := Vector2(x + 4.0, WIRE_Y - 108.0)
		draw_colored_polygon(PackedVector2Array([top, top + Vector2(40, 10 + flap), top + Vector2(0, 22)]), INK)
		draw_colored_polygon(PackedVector2Array([top + Vector2(0, 3), top + Vector2(32, 10 + flap), top + Vector2(0, 18)]), GOLD.darkened(0.15))


func _draw_wire() -> void:
	var points := PackedVector2Array()
	var x := _wire_from() - 30.0
	while x <= _wire_to() + 30.0:
		points.append(Vector2(x, _wire_at(x)))
		x += 20.0
	draw_polyline(points, INK, 6.0)
	draw_polyline(points, STEEL.darkened(0.2), 3.0)
	draw_polyline(points, STEEL.lightened(0.3), 1.0)


# --- Clown --------------------------------------------------------------------

func _draw_clown(phase: String, since: float) -> void:
	var walker := float(state.get("walk_x", 150.0))
	var heading := float(state.get("heading", 1.0))
	var lean := float(state.get("lean", 0.0))
	var steer := float(state.get("steer", 0))
	var feet := Vector2(walker, _wire_at(walker) - 2.0)
	var limit := float(state.get("fall_lean", 0.85))
	if phase == "fall":
		_draw_hanging(feet, lean, since)
		return
	var mood := "worried" if absf(lean) > limit * 0.5 else "calm"
	var stretch := Vector2.ONE
	if phase == "turn":
		stretch = Vector2(1.0, 1.0 - 0.12 * sin(clampf(since / 0.8, 0.0, 1.0) * PI))
	elif not reduced_motion:
		# A little bob on every step.
		feet.y -= absf(sin(now * 7.0)) * 3.0
	# The pole tips with him and swings further toward the side being pushed.
	var pole_tilt := lean * 0.7 + steer * 0.22
	var hands := feet + Vector2(0, -24.0 * UNIT).rotated(lean)
	_draw_pole(hands, pole_tilt)
	draw_set_transform(feet, lean, Vector2(heading, 1.0) * stretch * UNIT)
	stamp(_clowns[mood], -Vector2(CLOWN_ORIGIN), 1.0, LAMP)
	draw_set_transform(Vector2.ZERO)
	_draw_pole_front(hands, pole_tilt)
	if mood == "worried" and not reduced_motion:
		for drop in 2:
			var fall := fmod(now * 1.6 + drop * 0.5, 1.0)
			var at := feet + Vector2(-30.0 + drop * 60.0, -42.0 * UNIT + fall * 24.0).rotated(lean)
			draw_rect(Rect2(at - Vector2(4, 6), Vector2(8, 12)), Color("#2d4f66"))
			draw_rect(Rect2(at - Vector2(2, 4), Vector2(4, 8)), Color("#9fd0e6"))


## The long pole behind his hands, with brass weights and any pigeon on an end.
func _draw_pole(hands: Vector2, tilt: float) -> void:
	var along := Vector2.from_angle(tilt)
	var left := hands - along * POLE_HALF
	var right := hands + along * POLE_HALF
	draw_line(left, right, INK, 9.0)
	draw_line(left, right, Color("#c9a46a"), 5.0)
	draw_line(left - Vector2(0, 1), right - Vector2(0, 1), Color("#ecd3a0"), 1.5)
	for end: Vector2 in [left, right]:
		stamp(_weight, end - Vector2(3.5, 3.5) * TEXEL, TEXEL, LAMP)
	for event: Dictionary in state.get("events", []):
		if str(event.kind) != "pigeon":
			continue
		var end := right if float(event.side) > 0.0 else left
		var perch := end + Vector2(0, -14)
		var arrive := clampf(1.0 - (float(event.at) - now) / 0.8, 0.0, 1.0)
		var leave := clampf((now - float(event.until) + 0.5) / 0.5, 0.0, 1.0)
		var sky := Vector2(end.x + float(event.side) * 260.0, 140.0)
		var at := sky.lerp(perch, arrive) if leave <= 0.0 else perch.lerp(sky + Vector2(0, -60), leave)
		if reduced_motion:
			at = perch
		if not reduced_motion and (arrive < 1.0 or leave > 0.0):
			at.y -= sin(now * 30.0) * 4.0
		draw_set_transform(at, 0.0, Vector2(-float(event.side), 1.0) * TEXEL)
		stamp(_pigeon, Vector2(-6, -9), 1.0, LAMP)
		draw_set_transform(Vector2.ZERO)
		if now >= float(event.at) and now < float(event.until):
			label(perch + Vector2(0, -52), "咕！", 18, CREAM)


## His gloved hands go over the pole.
func _draw_pole_front(hands: Vector2, tilt: float) -> void:
	for side: float in [-1.0, 1.0]:
		var at := hands + Vector2.from_angle(tilt) * 18.0 * side
		draw_rect(Rect2(at - Vector2(8, 8), Vector2(16, 16)), INK)
		draw_rect(Rect2(at - Vector2(6, 6), Vector2(12, 12)), Color("#f3ead9"))
		draw_rect(Rect2(at - Vector2(6, 6), Vector2(12, 3)), Color.WHITE)


## He flipped: knees hooked over the wire, upside down, swinging, pole dropped.
func _draw_hanging(feet: Vector2, lean: float, since: float) -> void:
	var swing := 0.0 if reduced_motion else sin(since * 6.0) * 0.5 * exp(-since * 0.6)
	var flip := clampf(since / 0.3, 0.0, 1.0) if not reduced_motion else 1.0
	var angle := lean + (PI - absf(lean)) * signf(lean if lean != 0.0 else 1.0) * flip + swing
	draw_set_transform(feet + Vector2(0, 6), angle, UNIT * Vector2.ONE)
	stamp(_clowns["shock"], -Vector2(CLOWN_ORIGIN), 1.0, LAMP)
	draw_set_transform(Vector2.ZERO)
	# The pole falls to the floor and clatters.
	var drop := 1.0 if reduced_motion else clampf(since / 0.6, 0.0, 1.0)
	var pole_at := feet.lerp(Vector2(feet.x + 40.0, FLOOR_TOP + 30.0), drop * drop)
	var tilt := 0.0 if drop >= 1.0 else since * 5.0
	draw_set_transform(pole_at, tilt)
	draw_rect(Rect2(-POLE_HALF, -4, POLE_HALF * 2.0, 9), INK)
	draw_rect(Rect2(-POLE_HALF, -2, POLE_HALF * 2.0, 5), Color("#c9a46a"))
	draw_set_transform(Vector2.ZERO)
	dust_puffs(Vector2(feet.x + 40.0, FLOOR_TOP + 34.0), since - 0.6, 70.0)
	label(feet + Vector2(0, 190), "救命～", 24, CREAM, 0.9 + 0.1 * pulse(3.0))


# --- Pushes -------------------------------------------------------------------

## Wind lines stream in from a wing during a gust, and faintly just before it.
func _draw_gusts() -> void:
	for event: Dictionary in state.get("events", []):
		if str(event.kind) != "gust":
			continue
		var side := float(event.side)
		var warming := now < float(event.at)
		var strength := 0.45 if warming else 1.0
		for line in 6:
			var drift := 0.0 if reduced_motion else fmod(now * 1.8 + line * 0.17, 1.0)
			var x := (0.0 if side > 0.0 else DESIGN.x) + side * DESIGN.x * drift
			var y := WIRE_Y - 150.0 + line * 34.0
			draw_rect(Rect2(x - 40.0, y, 80, 5), Color(1, 0.97, 0.9, 0.45 * strength * (1.0 - absf(drift - 0.5) * 1.4)))
		var tag := Vector2(140 if side > 0.0 else 1140, WIRE_Y - 180.0)
		label(tag, "風 →" if side > 0.0 else "← 風", 26, CREAM if warming else GOLD)


## Hats arc up from the audience and bounce off the clown's side.
func _draw_hats() -> void:
	var walker := float(state.get("walk_x", 150.0))
	for event: Dictionary in state.get("events", []):
		if str(event.kind) != "hat":
			continue
		var side := float(event.side)
		var target := Vector2(walker - side * 26.0, _wire_at(walker) - 90.0)
		var start := Vector2(target.x - side * 220.0, DESIGN.y + 20.0)
		var t := 1.0 - (float(event.at) - now) / 0.8
		var at: Vector2
		var turn := now * 9.0
		if t < 1.0:
			at = start.lerp(target, t) - Vector2(0, 160.0 * sin(t * PI))
		else:
			var after := now - float(event.at)
			at = target + Vector2(side * -140.0 * after, 600.0 * after * after - 120.0 * after)
		if reduced_motion:
			turn = 0.0
		draw_set_transform(at, turn, Vector2.ONE * TEXEL)
		stamp(_hat, Vector2(-6, -8), 1.0, LAMP)
		draw_set_transform(Vector2.ZERO)
		if t >= 1.0 and now - float(event.at) < 0.3:
			label(target + Vector2(0, -30), "咚！", 24, ROSE)


## A brass spirit level: the bubble follows the lean; the green middle is steady.
func _draw_level() -> void:
	var lean := float(state.get("lean", 0.0))
	var limit := float(state.get("fall_lean", 0.85))
	var steady := float(state.get("steady", 0.14))
	panel(LEVEL.grow(8.0), "lacquer", BRASS.darkened(0.3), BRASS, 3.0, LAMP)
	panel(LEVEL, "glass", LEVEL_GLASS, Pixels.CLEAR, 3.0, LAMP)
	var middle := LEVEL.get_center()
	var reach := LEVEL.size.x * 0.5 - 20.0
	var calm := reach * steady / limit
	draw_rect(Rect2(middle.x - calm, LEVEL.position.y + 4.0, calm * 2.0, LEVEL.size.y - 8.0), Color(MINT, 0.3))
	for edge: float in [-1.0, 1.0]:
		draw_rect(Rect2(middle.x + edge * reach - (14.0 if edge > 0.0 else 0.0), LEVEL.position.y + 4.0, 14, LEVEL.size.y - 8.0), Color(ROSE, 0.45))
		draw_rect(Rect2(middle.x + edge * calm - 2.0, LEVEL.position.y + 2.0, 4, LEVEL.size.y - 4.0), INK)
	var bubble := Vector2(middle.x + clampf(lean / limit, -1.0, 1.0) * reach, middle.y)
	draw_circle(bubble, 15.0, INK)
	draw_circle(bubble, 12.0, Color("#f4fff4"))
	draw_circle(bubble + Vector2(-4, -4), 4.0, Color.WHITE)
	if absf(lean) > limit * 0.6:
		var toward := "←" if lean > 0.0 else "→"
		label(Vector2(LEVEL.end.x + 46.0, middle.y), toward, 34, ROSE, 0.9 + 0.1 * pulse(5.0))


## The clown in texels around his feet (x right, y up is negative), facing right.
static func _clown_blocks(mood: String) -> Array:
	var suit := Color("#4fa89a")
	var stripe := Color("#e9c46a")
	var face := Color("#f4e6d8")
	var hair := Color("#c9483d")
	var ink := Color("#2b2440")
	var blocks: Array = [
		[Rect2(-4, -3, 4, 3), Color("#3b3550")], [Rect2(1, -3, 5, 3), Color("#3b3550")],
		[Rect2(-3, -14, 3, 11), suit], [Rect2(1, -14, 3, 11), suit], [Rect2(-3, -10, 7, 2), stripe], [Rect2(-3, -6, 7, 1), stripe],
		[Rect2(-6, -26, 12, 13), suit], [Rect2(-6, -22, 12, 2), stripe], [Rect2(-6, -17, 12, 2), stripe], [Rect2(-1, -26, 2, 4), stripe],
		[Rect2(-7, -28, 14, 3), Color("#f3ead9")], [Rect2(-9, -25, 4, 3), suit], [Rect2(5, -25, 4, 3), suit],
		[Rect2(-5, -37, 10, 9), face], [Rect2(-5, -37, 10, 1), face.lightened(0.3)],
		[Rect2(-7, -38, 4, 4), hair], [Rect2(3, -38, 4, 4), hair], [Rect2(-3, -40, 6, 3), Color("#3b3550")], [Rect2(-2, -41, 4, 1), Color("#3b3550")],
		[Rect2(3, -32, 3, 2), Color("#c9344a")],
	]
	match mood:
		"worried":
			blocks.append_array([[Rect2(-2, -35, 2, 3), Color.WHITE], [Rect2(2, -35, 2, 3), Color.WHITE], [Rect2(-1, -34, 1, 2), ink], [Rect2(3, -34, 1, 2), ink],
				[Rect2(-2, -30, 4, 1), ink], [Rect2(-3, -36, 2, 1), ink], [Rect2(2, -36, 2, 1), ink]])
		"shock":
			blocks.append_array([[Rect2(-2, -35, 2, 2), ink], [Rect2(2, -35, 2, 2), ink], [Rect2(-1, -31, 3, 3), Color("#7a1f2f")]])
		_:
			blocks.append_array([[Rect2(-2, -34, 2, 2), ink], [Rect2(2, -34, 2, 2), ink], [Rect2(-2, -30, 5, 1), Color("#c9344a")], [Rect2(-2, -31, 1, 1), Color("#c9344a")], [Rect2(2, -31, 1, 1), Color("#c9344a")]])
	return blocks
