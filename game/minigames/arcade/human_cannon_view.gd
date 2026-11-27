extends "res://game/minigames/arcade/arcade_view.gd"
## Picture for 人肉砲彈: the striped cannon on its wheeled carriage with the
## spring showing at its breech, a long water trough across the ring, the
## safety net sliding above it, the tent canvas closing the far side and, later,
## a fan hung from the rigging. Every object is baked pixel art
## (arcade_pixels.gd) or a shared material, tinted to the tent's dusk.

const TENT_ART := "res://assets/world/circus-tent.webp"
const FLOOR_TOP := 556.0
const WOOD := Color("#6b4658")
const WOOD_DARK := Color("#3b2536")
const BRASS := Color("#b0803a")
const BARREL := Color("#b8433f")
const IRON := Color("#4a4458")
const TIMBER := Color("#8a5a3c")
const WATER := Color("#4f8fa8")
const ROPE := Color("#e0cfa0")
const CANVAS := Color("#e9dcc0")
const STRIPE := Color("#b84a4a")
const SUIT := Color("#c9c3d6")
const HELMET := Color("#c9483d")
const SKIN := Color("#f4e6d8")
const LAMP := Color(1.0, 0.94, 0.9)
const TROUGH_TOP := 540.0
const TROUGH_BOTTOM := 632.0
const NET_Y := 486.0
const PIVOT := Vector2(140, 506)
const BARREL_ANGLE := -0.62
const BARREL_LENGTH := 44
const APEX := 250.0
const HOLE_Y := 360.0

var _has_tent := false
var _barrel: ImageTexture
var _carriage: ImageTexture
var _wheel: ImageTexture
var _canvas: ImageTexture
var _fan_cage: ImageTexture
var _ball: ImageTexture
var _sit: ImageTexture
var _wet: ImageTexture
var _legs: ImageTexture
var _helmet: ImageTexture


func _init() -> void:
	super()
	word_anchor = Vector2(560, 392)


func _ready() -> void:
	_has_tent = use_backdrop_art(TENT_ART, Rect2(85, 0, 1366, 768), Color(0.78, 0.72, 0.84))
	_barrel = Pixels.bake("cannon-barrel", Vector2i(BARREL_LENGTH, 14), _paint_barrel)
	_carriage = Pixels.bake("cannon-carriage", Vector2i(44, 22), _paint_carriage)
	_wheel = Pixels.bake("cannon-wheel", Vector2i(16, 16), _paint_wheel)
	_canvas = Pixels.bake("cannon-canvas", Vector2i(34, 110), _paint_canvas)
	_fan_cage = Pixels.bake("cannon-fan", Vector2i(26, 26), _paint_fan)
	_ball = Pixels.bake_blocks("cannon-ball", Vector2i(18, 18), Vector2i(9, 9), [
		[Rect2(-8, -6, 16, 13), SUIT], [Rect2(-8, 3, 16, 3), SUIT.darkened(0.2)], [Rect2(-2, -2, 4, 4), Color("#e9b85c")],
		[Rect2(-6, -9, 12, 7), HELMET], [Rect2(-1, -9, 2, 7), CANVAS], [Rect2(-4, -4, 8, 2), Color("#4fa89a")],
		[Rect2(-9, 1, 4, 4), CANVAS], [Rect2(5, 1, 4, 4), CANVAS], [Rect2(-5, 6, 4, 3), HELMET.darkened(0.2)], [Rect2(1, 6, 4, 3), HELMET.darkened(0.2)]])
	_sit = Pixels.bake_blocks("cannon-sit", Vector2i(26, 26), Vector2i(13, 24), [
		[Rect2(-9, -4, 7, 4), HELMET.darkened(0.2)], [Rect2(2, -4, 7, 4), HELMET.darkened(0.2)],
		[Rect2(-6, -14, 12, 11), SUIT], [Rect2(-2, -11, 4, 4), Color("#e9b85c")],
		[Rect2(-11, -22, 4, 10), SUIT], [Rect2(7, -22, 4, 10), SUIT], [Rect2(-12, -24, 4, 3), CANVAS], [Rect2(8, -24, 4, 3), CANVAS],
		[Rect2(-5, -23, 10, 9), SKIN], [Rect2(-6, -25, 12, 5), HELMET], [Rect2(-1, -25, 2, 5), CANVAS],
		[Rect2(-4, -19, 3, 2), Color("#2b2440")], [Rect2(1, -19, 3, 2), Color("#2b2440")], [Rect2(-1, -17, 2, 2), HELMET], [Rect2(-3, -15, 6, 1), HELMET.darkened(0.3)]])
	_wet = Pixels.bake_blocks("cannon-wet", Vector2i(30, 16), Vector2i(15, 15), [
		[Rect2(-14, -7, 6, 3), SUIT], [Rect2(8, -10, 6, 3), SUIT], [Rect2(-15, -9, 3, 3), CANVAS], [Rect2(12, -12, 3, 3), CANVAS],
		[Rect2(-6, -6, 12, 6), SUIT], [Rect2(-5, -14, 10, 9), SKIN], [Rect2(-6, -16, 12, 5), HELMET], [Rect2(-1, -16, 2, 5), CANVAS],
		[Rect2(-5, -11, 10, 3), Color("#4fa89a")], [Rect2(-4, -11, 3, 2), Color("#bfe6e8")], [Rect2(1, -11, 3, 2), Color("#bfe6e8")],
		[Rect2(-2, -7, 4, 2), Color("#7a1f2f")]])
	_legs = Pixels.bake_blocks("cannon-legs", Vector2i(14, 20), Vector2i(0, 10), [
		[Rect2(0, -7, 10, 5), SUIT], [Rect2(0, 2, 10, 5), SUIT], [Rect2(4, -7, 2, 5), HELMET], [Rect2(4, 2, 2, 5), HELMET],
		[Rect2(10, -9, 4, 6), HELMET.darkened(0.2)], [Rect2(10, 1, 4, 6), HELMET.darkened(0.2)]])
	_helmet = Pixels.bake_blocks("cannon-helmet", Vector2i(12, 8), Vector2i(6, 8), [
		[Rect2(-5, -8, 10, 5), HELMET], [Rect2(-1, -8, 2, 5), CANVAS], [Rect2(-4, -4, 8, 3), SKIN], [Rect2(-4, -4, 8, 1), Color("#4fa89a")]])


func _draw_backdrop() -> void:
	if not _has_tent:
		draw_rect(Rect2(Vector2.ZERO, DESIGN), Color("#2b1f3a"))
	stage_floor(FLOOR_TOP, WOOD, WOOD_DARK)
	vignette(0.5)


func _draw_scene() -> void:
	var phase := str(state.get("phase", "load"))
	var since := age(float(state.get("phase_at", 0.0)))
	_draw_wall(phase, since)
	_draw_fan()
	_draw_trough(phase, since)
	_draw_net(phase, since)
	_draw_cannon(phase, since)
	_draw_aim(phase)
	match phase:
		"flight":
			_draw_flight(since)
		"splash":
			_draw_splash(since)
		"canvas":
			_draw_stuck(since)


# --- Set --------------------------------------------------------------------

func _wall_x() -> float:
	return float(state.get("wall_x", 1150.0))


## Striped canvas from the rigging to the floor; a stuck clown leaves a torn hole.
func _draw_wall(phase: String, since: float) -> void:
	var x := _wall_x()
	draw_rect(Rect2(x - 12.0, PLAY_TOP, 12, FLOOR_TOP - PLAY_TOP), Color(0.05, 0.02, 0.09, 0.3))
	var bulge := 0.0
	if phase == "canvas" and not reduced_motion:
		bulge = 14.0 * maxf(0.0, 1.0 - since * 2.0)
	stamp(_canvas, Vector2(x - bulge * 0.3, PLAY_TOP + 8.0), TEXEL, Color(0.72, 0.64, 0.7))
	panel(Rect2(x - 6.0, PLAY_TOP, DESIGN.x - x + 12.0, 16), "pole", BRASS, Pixels.CLEAR, 3.0, LAMP)


func _draw_trough(phase: String, since: float) -> void:
	var left := float(state.get("trough_x", 300.0))
	var rect := Rect2(left, TROUGH_TOP, _wall_x() - left, TROUGH_BOTTOM - TROUGH_TOP)
	ground_shadow(Vector2(rect.get_center().x, rect.end.y + 6.0), Vector2(rect.size.x * 0.52, 12), 0.45)
	panel(rect, "planks", TIMBER.darkened(0.15), Pixels.CLEAR, TEXEL, LAMP)
	# Water level with a moving glint; it slops after a splash.
	var slosh := 0.0
	if phase == "splash" and not reduced_motion:
		slosh = sin(since * 14.0) * 5.0 * maxf(0.0, 1.0 - since)
	var water := Rect2(rect.position.x + 8.0, rect.position.y + 6.0 + slosh, rect.size.x - 16.0, 26.0)
	panel(water, "liquid", WATER, Pixels.CLEAR, 3.0, LAMP)
	sheen(water, fposmod(now * 0.2, 1.0), 40.0, 0.22)
	for hoop in 4:
		var hx := rect.position.x + 30.0 + hoop * (rect.size.x - 60.0) / 3.0
		panel(Rect2(hx - 6.0, rect.position.y + 2.0, 12, rect.size.y - 4.0), "pole", IRON, Pixels.CLEAR, 3.0, LAMP)


## The net: a rope hammock between two brass posts on runners in the trough,
## with a red target patch in its middle.
func _draw_net(phase: String, since: float) -> void:
	var centre := float(state.get("net_x", 800.0))
	var half := float(state.get("net_width", 200.0)) * 0.5
	var sag := 18.0
	if phase == "net":
		sag += (0.0 if reduced_motion else 30.0 * exp(-since * 4.0) * absf(cos(since * 14.0))) + 10.0
	for side: float in [-1.0, 1.0]:
		var post := centre + side * (half + 6.0)
		panel(Rect2(post - 7.0, NET_Y - 34.0, 14, TROUGH_TOP - NET_Y + 44.0), "pole", BRASS, Pixels.CLEAR, 3.0, LAMP)
		draw_rect(Rect2(post - 10.0, NET_Y - 40.0, 20, 8), BRASS.lightened(0.3))
	var rope: Array[PackedVector2Array] = []
	for row in 3:
		var line := PackedVector2Array()
		for step in 13:
			var t := float(step) / 12.0
			line.append(Vector2(centre - half + t * half * 2.0, NET_Y - 26.0 + row * 12.0 + sin(t * PI) * sag * (0.6 + row * 0.2)))
		rope.append(line)
	for line in rope:
		draw_polyline(line, INK, 6.0)
	for step in 13:
		draw_line(rope[0][step], rope[2][step], INK, 5.0)
	for line in rope:
		draw_polyline(line, ROPE, 2.5)
	for step in 13:
		draw_line(rope[0][step], rope[2][step], ROPE.darkened(0.15), 2.0)
	var patch := Vector2(centre, NET_Y - 14.0 + sag * 0.8)
	draw_rect(Rect2(patch - Vector2(13, 7), Vector2(26, 14)), INK)
	draw_rect(Rect2(patch - Vector2(10, 5), Vector2(20, 10)), HELMET)
	draw_rect(Rect2(patch - Vector2(4, 5), Vector2(8, 10)), CANVAS)
	if phase == "net":
		var at := Vector2(centre + float(state.get("land_offset", 0.0)), NET_Y + sag * 0.8 - 6.0)
		var hop := 0.0 if reduced_motion else -60.0 * exp(-since * 3.0) * absf(sin(since * 9.0))
		var stretch := squash(since, 0.25, 0.4)
		draw_set_transform(at + Vector2(0, hop), 0.0, stretch * TEXEL)
		stamp(_sit, Vector2(-13, -24), 1.0, LAMP)
		draw_set_transform(Vector2.ZERO)


func _draw_fan() -> void:
	var fan := float(state.get("fan", 0.0))
	if is_zero_approx(fan):
		return
	var hub := Vector2(720, 214)
	draw_rect(Rect2(hub.x - 3.0, PLAY_TOP, 6, hub.y - PLAY_TOP - 40.0), INK)
	draw_rect(Rect2(hub.x - 1.5, PLAY_TOP, 3, hub.y - PLAY_TOP - 40.0), BRASS)
	var spin := 0.0 if reduced_motion else now * 18.0 * signf(fan)
	for blade in 3:
		var angle := spin + blade * TAU / 3.0
		draw_set_transform(hub, angle)
		draw_rect(Rect2(-6, -40, 12, 36), INK)
		draw_rect(Rect2(-4, -38, 8, 32), CANVAS.darkened(0.1))
	draw_set_transform(Vector2.ZERO)
	stamp(_fan_cage, hub - Vector2(52, 52), TEXEL, LAMP)
	# Gusts stream the way the fan pushes; longer for a stronger fan.
	var push := signf(fan)
	var reach := 60.0 + absf(fan) * 1.6
	for gust in 4:
		var drift := 0.0 if reduced_motion else fmod(now * 1.4 + gust * 0.25, 1.0)
		var start := hub + Vector2(push * (70.0 + drift * reach), -36.0 + gust * 24.0)
		draw_rect(Rect2(start.x - (0.0 if push > 0.0 else 40.0), start.y, 40, 4), Color(1, 0.97, 0.9, 0.5 * (1.0 - drift)))
	label(hub + Vector2(0, 74), "風 →" if push > 0.0 else "← 風", 22, CREAM)


# --- Cannon -------------------------------------------------------------------

func _muzzle() -> Vector2:
	return PIVOT + Vector2.from_angle(BARREL_ANGLE) * (BARREL_LENGTH - 4) * TEXEL


func _draw_cannon(phase: String, since: float) -> void:
	var power := float(state.get("power", 0.0))
	var squeezing := phase == "squeeze"
	var kick := 0.0
	if phase == "flight" and not reduced_motion:
		kick = 26.0 * exp(-since * 8.0)
	var shake := Vector2.ZERO
	if squeezing and power > 0.85 and not reduced_motion:
		shake = Vector2(sin(now * 70.0), cos(now * 63.0)) * 4.0 * smoothstep(0.85, float(state.get("overload", 1.18)), power)
	ground_shadow(Vector2(PIVOT.x, FLOOR_TOP + 78.0), Vector2(120, 14), 0.5)
	stamp(_carriage, Vector2(PIVOT.x - 96.0, PIVOT.y + 14.0), TEXEL, LAMP)
	var back := Vector2.from_angle(BARREL_ANGLE) * -kick
	# The spring between the breech and the back plate squeezes as power builds.
	var breech := PIVOT + back + shake - Vector2.from_angle(BARREL_ANGLE) * 12.0
	var plate := PIVOT + Vector2.from_angle(BARREL_ANGLE + PI) * 74.0
	var squeeze := clampf(power, 0.0, 1.2) if squeezing else 0.0
	var tip := plate.lerp(breech, 1.0 - 0.45 * squeeze)
	var coil := PackedVector2Array()
	for bend in 11:
		var t := float(bend) / 10.0
		var side := Vector2.from_angle(BARREL_ANGLE + PI * 0.5) * (13.0 if bend % 2 == 0 else -13.0)
		coil.append(plate.lerp(tip, t) + (side if bend > 0 and bend < 10 else Vector2.ZERO))
	draw_polyline(coil, INK, 10.0)
	draw_polyline(coil, Color("#d9d2c0"), 5.0)
	draw_polyline(coil, Color.WHITE, 1.5)
	draw_set_transform(plate, BARREL_ANGLE)
	panel(Rect2(-12, -24, 24, 48), "lacquer", IRON, BRASS, 3.0, LAMP)
	draw_set_transform(PIVOT + back + shake, BARREL_ANGLE + (-0.05 * squeeze if not reduced_motion else 0.0))
	stamp(_barrel, Vector2(-4, -7) * TEXEL, TEXEL, LAMP)
	draw_set_transform(Vector2.ZERO)
	# The next clown's helmet waits in the muzzle.
	if phase in ["load", "squeeze"] or (phase == "reload" and since > 0.2):
		var peek := 1.0 if phase != "reload" else smoothstep(0.2, 0.5, since)
		draw_set_transform(_muzzle() + back + shake + Vector2.from_angle(BARREL_ANGLE) * (6.0 * peek - 10.0), BARREL_ANGLE + PI * 0.5)
		stamp(_helmet, Vector2(-6, -8) * TEXEL, TEXEL, LAMP)
		draw_set_transform(Vector2.ZERO)
	for wheel_x: float in [PIVOT.x - 52.0, PIVOT.x + 44.0]:
		var spin := 0.0 if reduced_motion else -kick * 0.05
		draw_set_transform(Vector2(wheel_x, FLOOR_TOP + 44.0), spin)
		stamp(_wheel, Vector2(-8, -8) * TEXEL, TEXEL, LAMP)
	draw_set_transform(Vector2.ZERO)
	if phase == "flight" and since < 0.35 and not reduced_motion:
		var puff := _muzzle()
		for cloud in 5:
			var drift := Vector2.from_angle(BARREL_ANGLE + (cloud - 2) * 0.3) * (20.0 + since * 160.0)
			var size := 18.0 + since * 40.0
			draw_rect(Rect2(puff + drift - Vector2(size, size) * 0.5, Vector2(size, size)), Color(0.95, 0.9, 0.82, 0.7 * (1.0 - since / 0.35)))
	_draw_gauge(phase, power)


## A brass pressure gauge on the carriage: the needle sweeps as the spring tightens.
func _draw_gauge(phase: String, power: float) -> void:
	var centre := Vector2(84, 420)
	draw_circle(centre, 42.0, INK)
	draw_circle(centre, 38.0, BRASS)
	draw_circle(centre, 32.0, CANVAS)
	var overload := float(state.get("overload", 1.18))
	draw_arc(centre, 26.0, PI * 0.75 + PI * 1.5 / overload, PI * 2.25, 10, HELMET, 6.0)
	var shown := power if phase == "squeeze" else 0.0
	var angle := PI * 0.75 + PI * 1.5 * clampf(shown / overload, 0.0, 1.0)
	draw_line(centre, centre + Vector2.from_angle(angle) * 26.0, INK, 5.0)
	draw_line(centre, centre + Vector2.from_angle(angle) * 25.0, HELMET.darkened(0.2), 2.5)
	draw_circle(centre, 5.0, BRASS.darkened(0.3))
	glint(centre, 32.0, 4.0)
	label(centre + Vector2(0, 58), "壓力", 18, CREAM)


## Where the shot will land, marked on the trough rim while the spring is held.
func _draw_aim(phase: String) -> void:
	if phase != "squeeze" or bool(state.get("blind", false)):
		return
	var x := float(state.get("aim_x", 0.0))
	var over := x >= _wall_x()
	var tone := ROSE if over else GOLD
	x = minf(x, _wall_x() - 8.0)
	var tip := Vector2(x, TROUGH_TOP - 4.0)
	# A dotted drop line and a big arrow: where he comes down if you let go now.
	var dash := NET_Y - 70.0
	while dash < tip.y - 34.0:
		draw_rect(Rect2(x - 3.0, dash, 6, 8), INK)
		draw_rect(Rect2(x - 1.5, dash + 1.5, 3, 5), tone)
		dash += 16.0
	draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-20, -32), tip + Vector2(20, -32)]), INK)
	draw_colored_polygon(PackedVector2Array([tip + Vector2(0, -6), tip + Vector2(-13, -28), tip + Vector2(13, -28)]), tone)
	draw_colored_polygon(PackedVector2Array([tip + Vector2(-13, -28), tip + Vector2(-6, -28), tip + Vector2(-2, -12)]), tone.lightened(0.4))
	label(tip + Vector2(0, -50), "落點", 18, tone)


# --- Clown --------------------------------------------------------------------

func _shot_point(share: float) -> Vector2:
	var start := _muzzle()
	var land := Vector2(float(state.get("land_x", 0.0)) if share >= 1.0 else _target_x(), NET_Y - 10.0)
	var line := start.lerp(land, share)
	return line - Vector2(0, APEX * sin(PI * share))


## Where the shot in the air is heading: power, plus the fan's push.
func _target_x() -> float:
	return float(state.get("muzzle_x", 236.0)) + float(state.get("shot_power", 0.0)) * float(state.get("range", 900.0)) + float(state.get("fan", 0.0))


func _draw_flight(since: float) -> void:
	var share := clampf(since / float(state.get("flight_seconds", 0.85)), 0.0, 1.0)
	var at := _shot_point(share)
	if _target_x() >= _wall_x():
		at.x = minf(at.x, _wall_x())
	for trail in 4:
		var behind := _shot_point(maxf(0.0, share - 0.04 * (trail + 1)))
		draw_rect(Rect2(behind - Vector2(5, 5), Vector2(10, 10)), Color(1, 0.94, 0.8, 0.35 - trail * 0.08))
	draw_set_transform(at, 0.0 if reduced_motion else now * 14.0, Vector2.ONE * TEXEL)
	stamp(_ball, Vector2(-9, -9), 1.0, LAMP)
	draw_set_transform(Vector2.ZERO)


## Short: the clown drops into the trough, only his goggled head and arms show.
func _draw_splash(since: float) -> void:
	var x := clampf(float(state.get("land_x", 600.0)), float(state.get("trough_x", 300.0)) + 40.0, _wall_x() - 40.0)
	var surface := TROUGH_TOP + 10.0
	var rise := 1.0 if reduced_motion else smoothstep(0.15, 0.6, since)
	draw_set_transform(Vector2(x, surface + 10.0 + 24.0 * (1.0 - rise)), 0.0, Vector2.ONE * TEXEL)
	stamp(_wet, Vector2(-15, -15), 1.0, LAMP)
	draw_set_transform(Vector2.ZERO)
	if not reduced_motion and since < 0.9:
		for drop in 12:
			var angle := -PI * (0.15 + 0.7 * drop / 11.0)
			var speed := 220.0 + 90.0 * ((drop * 7) % 3)
			var at := Vector2(x, surface) + Vector2(cos(angle), sin(angle)) * speed * since + Vector2(0, 520.0 * since * since)
			if at.y < surface + 4.0:
				draw_rect(Rect2(at - Vector2(5, 5), Vector2(10, 10)), Color(INK, 0.6))
				draw_rect(Rect2(at - Vector2(3, 3), Vector2(6, 6)), WATER.lightened(0.4))
	# A ring of ripples, then a bubble now and then.
	var ripple := 30.0 + since * 80.0
	draw_arc(Vector2(x, surface + 4.0), ripple, PI * 1.05, PI * 1.95, 16, Color(CREAM, 0.5 * maxf(0.0, 1.0 - since)), 3.0)


## Long: he punches through the canvas; only his legs stick out, kicking.
func _draw_stuck(since: float) -> void:
	var x := _wall_x()
	var y := HOLE_Y
	# A torn star in the canvas with frayed cream edges, the stitching pulled open.
	var rim := PackedVector2Array()
	var hole := PackedVector2Array()
	for corner in 12:
		var angle := corner * TAU / 12.0
		var reach := 46.0 if corner % 2 == 0 else 28.0
		rim.append(Vector2(x + 30.0, y) + Vector2(cos(angle) * reach * 0.7, sin(angle) * reach))
		hole.append(Vector2(x + 30.0, y) + Vector2(cos(angle) * reach * 0.55, sin(angle) * reach * 0.82))
	draw_colored_polygon(rim, CANVAS.darkened(0.1))
	draw_colored_polygon(hole, INK)
	var kick := 0.0 if reduced_motion else sin(since * 16.0) * 0.3
	draw_set_transform(Vector2(x + 24.0, y), PI + kick, Vector2.ONE * 6.0)
	stamp(_legs, Vector2(0, -10), 1.0, LAMP)
	draw_set_transform(Vector2.ZERO)
	if since < 0.4 and not reduced_motion:
		for bit in 6:
			var drift := Vector2.from_angle(PI + (bit - 2.5) * 0.4) * since * 220.0
			draw_rect(Rect2(Vector2(x, y) + drift - Vector2(5, 5), Vector2(10, 10)), CANVAS if bit % 2 == 0 else STRIPE)


# --- Texel painters ---------------------------------------------------------

func _paint_barrel(x: int, y: int) -> Color:
	var across := (y + 0.5 - 7.0) / 7.0
	if x < 3:
		return Pixels.CLEAR if absf(across) > 0.75 else Pixels.metal(Pixels.rounded(IRON, Vector2(0, across)), x, y)
	if x >= BARREL_LENGTH - 4:
		return Pixels.metal(Pixels.rounded(Color("#d9b04a"), Vector2(0, across)), x, y)
	if x % 12 == 6 or x % 12 == 7:
		return Pixels.metal(Pixels.rounded(Color("#d9b04a"), Vector2(0, across)), x, y)
	var star := Vector2(x - 20, y - 7)
	if absf(star.x) + absf(star.y) * 1.6 < 3.0:
		return Pixels.rounded(CANVAS, Vector2(0, across))
	var stripe := BARREL if (x / 3) % 4 != 0 else BARREL.darkened(0.12)
	return Pixels.grainy(Pixels.rounded(stripe, Vector2(0, across)), x, y, 0.06)


func _paint_wheel(x: int, y: int) -> Color:
	var offset := (Vector2(x, y) + Vector2(0.5, 0.5) - Vector2(8, 8)) / 8.0
	var reach := offset.length()
	if reach > 1.0:
		return Pixels.CLEAR
	if reach > 0.76:
		return Pixels.metal(Pixels.rounded(IRON, offset), x, y)
	if reach < 0.22:
		return Pixels.rounded(Color("#d9b04a"), offset * 2.0)
	var angle := fposmod(atan2(offset.y, offset.x), TAU / 8.0)
	if angle < 0.22 or angle > TAU / 8.0 - 0.22:
		return Pixels.wood(TIMBER.lightened(0.1), x, y, 4)
	return Pixels.CLEAR


func _paint_canvas(x: int, y: int) -> Color:
	var tone := STRIPE if (x / 6) % 2 == 0 else CANVAS
	if x % 6 == 0:
		tone = tone.darkened(0.25)
	var fold := sin(float(y) * 0.11 + float(x) * 0.3) * 0.12
	tone = tone.lightened(fold) if fold > 0.0 else tone.darkened(-fold)
	if y % 18 == 0 and x % 2 == 0:
		return tone.darkened(0.35)
	return Pixels.grainy(tone.darkened(0.25 * float(x) / 34.0), x, y, 0.08)


## Oak cheeks of the gun carriage: high at the back, bolted iron straps.
func _paint_carriage(x: int, y: int) -> Color:
	if y < x / 6:
		return Pixels.CLEAR
	if x % 11 == 5:
		return Pixels.metal(IRON, x, y) if y % 4 != 1 else Color("#d9b04a")
	return Pixels.wood(TIMBER, x, y, 5, false)


## A brass cage with a hub, seen face on; the blades are drawn under it.
func _paint_fan(x: int, y: int) -> Color:
	var offset := (Vector2(x, y) + Vector2(0.5, 0.5) - Vector2(13, 13)) / 13.0
	var reach := offset.length()
	if reach > 1.0:
		return Pixels.CLEAR
	if reach > 0.86 or reach < 0.16:
		return Pixels.metal(Pixels.rounded(BRASS, offset), x, y)
	if (x % 5 == 2 and reach > 0.3) or (absf(reach - 0.55) < 0.05):
		return BRASS.darkened(0.2)
	return Pixels.CLEAR
