extends "res://game/minigames/arcade/arcade_view.gd"
## Picture for 羽球上升流: the timber kite terrace of the cloud park on a bright
## afternoon. Kites fly over the rail, a striped windsock on its pole swings to
## show each gust before it blows, and wind streaks sweep the sky while it does.
## The island traveller (arcade_hero) runs along the deck with a racket held
## over their head; shuttlecocks tumble down on the updraft with their shadows
## on the boards, and every one that gets past sticks in the traveller's hair,
## one more feather in a crooked hat. Baked pixel art in the sky park palette.

const Hero = preload("res://game/minigames/arcade/arcade_hero.gd")
const LEFT := 120.0
const WIDE := 1040.0
const DECK_Y := 640.0
const TALL := 460.0
const HERO_SCALE := 3.0
const RAIL_Y := 566.0
const POLE_X := 70.0
const SKY := Color("#7cc4ec")
const DEEP := Color("#3d6fb0")
const PALE := Color("#d8eefa")
const WHITE := Color("#fbfdff")
const CLOUD_SHADE := Color("#d5e3f6")
const SUN := Color("#ffd35c")
const CORAL := Color("#ff8a6b")
const MINT_KITE := Color("#8fe0c4")
const LILAC := Color("#b9a9f0")
const WOOD := Color("#a87a4f")
const DARK_WOOD := Color("#6e4c32")
const NAVY := Color("#2f4a7a")
const CORK := Color("#e9c98f")
const NOON := Color(1.0, 0.99, 0.96)

var _sky: ImageTexture
var _cloud: ImageTexture
var _shuttle: ImageTexture
var _kites: Array[ImageTexture] = []


func _init() -> void:
	super()
	word_anchor = Vector2(640, 300)


func _ready() -> void:
	_sky = Pixels.bake("updraft-sky", Vector2i(322, 182), _paint_sky)
	_cloud = Pixels.bake("updraft-cloud", Vector2i(30, 12), _paint_cloud)
	_shuttle = Pixels.bake("updraft-shuttle", Vector2i(9, 12), _paint_shuttle)
	for tone: Color in [CORAL, MINT_KITE, LILAC]:
		_kites.append(Pixels.bake("updraft-kite|%s" % tone.to_html(), Vector2i(12, 15), _paint_kite.bind(tone)))


func _x(at: float) -> float:
	return LEFT + at * WIDE


func _y(height: float) -> float:
	return DECK_Y - height * TALL


# --- Backdrop -----------------------------------------------------------------

## A plain afternoon sky over a sea of clouds. Stands in until the sky park's
## shared arcade backdrop arrives; the terrace below is this game's own.
func _draw_backdrop() -> void:
	stamp(_sky, Vector2(-TEXEL * 2.0, -TEXEL * 2.0))
	# Little clouds drifting past behind the kites.
	for index in 4:
		var drift := 0.0 if reduced_motion else now * (10.0 + index * 4.0)
		var x := fposmod(index * 360.0 + drift, DESIGN.x + 260.0) - 180.0
		stamp(_cloud, Vector2(x, 150.0 + index * 58.0), 3.0 + index % 2, NOON)
	_draw_kites()
	_draw_rail()
	stage_floor(DECK_Y, WOOD, DARK_WOOD)
	vignette(0.32)


func _draw_kites() -> void:
	var lean := float(state.get("wind", 0.0)) * 120.0
	for index in _kites.size():
		var sway := 0.0 if reduced_motion else sin(now * (0.9 + index * 0.3) + index * 2.0) * 14.0
		var at := Vector2(300.0 + index * 330.0 + lean + sway, 210.0 + (index % 2) * 50.0 + sway * 0.5)
		var reel := Vector2(260.0 + index * 360.0, RAIL_Y)
		draw_line(at + Vector2(24, 56), reel, Color(WHITE, 0.6), 2.0)
		stamp(_kites[index], at, TEXEL, NOON)
		# A ribbon tail of little bows on a string.
		var tail := PackedVector2Array([at + Vector2(24, 58)])
		for bow in 4:
			tail.append(at + Vector2(24 - bow * 10.0 - lean * 0.08, 70 + bow * 16.0 + (0.0 if reduced_motion else sin(now * 4.0 + bow) * 4.0)))
		draw_polyline(tail, Color(NAVY, 0.6), 2.0)
		for bow in 4:
			var spot := tail[bow + 1]
			draw_colored_polygon(PackedVector2Array([spot + Vector2(-8, -5), spot, spot + Vector2(-8, 5)]), [CORAL, SUN, MINT_KITE, LILAC][(bow + index) % 4])
			draw_colored_polygon(PackedVector2Array([spot + Vector2(8, -5), spot, spot + Vector2(8, 5)]), [CORAL, SUN, MINT_KITE, LILAC][(bow + index) % 4].darkened(0.15))


func _draw_rail() -> void:
	# A timber rail along the back of the terrace with bunting between the posts.
	panel(Rect2(-8, RAIL_Y - 10.0, DESIGN.x + 16.0, 16), "planks", WOOD.lightened(0.08), Color(0, 0, 0, 0), TEXEL, NOON)
	panel(Rect2(-8, RAIL_Y + 30.0, DESIGN.x + 16.0, 12), "planks", WOOD, Color(0, 0, 0, 0), TEXEL, NOON)
	for post in 9:
		var x := 20.0 + post * 155.0
		panel(Rect2(x, RAIL_Y - 18.0, 20, DECK_Y - RAIL_Y + 18.0), "planks_v", DARK_WOOD.lightened(0.1), Color(0, 0, 0, 0), TEXEL, NOON)
		if post < 8:
			for flag in 5:
				var a := Vector2(x + 20.0 + flag * 27.0, RAIL_Y - 14.0 + sin(flag * 0.6) * 6.0)
				var tone: Color = [CORAL, SUN, MINT_KITE, LILAC, WHITE][(flag + post) % 5]
				draw_colored_polygon(PackedVector2Array([a, a + Vector2(18, 0), a + Vector2(9, 16)]), tone.darkened(0.15))
				draw_colored_polygon(PackedVector2Array([a + Vector2(2, 1), a + Vector2(16, 1), a + Vector2(9, 13)]), tone)


# --- Play ---------------------------------------------------------------------

func _draw_scene() -> void:
	if not state.has("shuttles"):
		return
	_draw_gust()
	_draw_windsock()
	for shuttle: Dictionary in state.shuttles:
		if str(shuttle.state) == "air":
			_draw_shadow(shuttle)
	_draw_hero()
	for shuttle: Dictionary in state.shuttles:
		if str(shuttle.state) == "air":
			_draw_shuttle(Vector2(_x(float(shuttle.x)), _y(float(shuttle.y))), Vector2(float(shuttle.vx) * WIDE, -float(shuttle.vy) * TALL))
		else:
			_draw_flying_hat(shuttle)
	_draw_rally()


## How far through its warning a gust is (0..1), or -1 when none is coming.
func _warning() -> float:
	var gust: Dictionary = state.get("gust", {})
	if gust.is_empty() or now >= float(gust.start):
		return -1.0
	return clampf((now - float(gust.warn_at)) / maxf(0.01, float(gust.start) - float(gust.warn_at)), 0.0, 1.0)


func _blowing() -> bool:
	var gust: Dictionary = state.get("gust", {})
	return not gust.is_empty() and now >= float(gust.start) and now < float(gust.end)


## The way the coming or blowing gust pushes, on screen.
func _gust_way() -> Vector2:
	var gust: Dictionary = state.get("gust", {})
	if gust.is_empty():
		return Vector2.ZERO
	match str(gust.kind):
		"lift":
			return Vector2.UP
		"down":
			return Vector2.DOWN
	return Vector2(float(gust.side), 0.0)


func _draw_gust() -> void:
	if not _blowing():
		return
	var way := _gust_way()
	var gust: Dictionary = state.gust
	var fade := minf(1.0, minf(now - float(gust.start), float(gust.end) - now) / 0.3)
	# Long white streaks racing across (or up, or down) the sky.
	for streak in 12:
		var lane := Pixels.noise(streak, 3, 11)
		var run := 0.4 if reduced_motion else fposmod(now * 1.4 + lane * 3.0, 1.0)
		var at: Vector2
		var length := 70.0 + 60.0 * Pixels.noise(streak, 5, 11)
		if way.x != 0.0:
			var x := -100.0 + run * (DESIGN.x + 200.0)
			at = Vector2(x if way.x > 0.0 else DESIGN.x - x, 170.0 + lane * 380.0)
		else:
			var y := DECK_Y - run * (DECK_Y - 150.0)
			at = Vector2(LEFT + lane * WIDE, y if way.y < 0.0 else DECK_Y + 150.0 - y)
		var tail := at - way * length
		draw_line(at, tail, Color(DEEP, 0.18 * fade), 12.0)
		draw_line(at, tail, Color(WHITE, 0.45 * fade), 8.0)
		draw_line(at, at - way * length * 0.7, Color(WHITE, 0.95 * fade), 3.0)
		if streak % 3 == 0:
			draw_arc(at + way.orthogonal() * 10.0, 10.0, way.angle() - PI * 0.5, way.angle() + PI, 8, Color(WHITE, 0.9 * fade), 3.0)


func _draw_windsock() -> void:
	# A striped windsock on a pole: limp in still air, it swings round and fills
	# before a gust blows, pointing the way the gust will push.
	var top := Vector2(POLE_X, 300.0)
	panel(Rect2(POLE_X - 6.0, top.y, 12, DECK_Y - top.y), "planks_v", DARK_WOOD, Color(0, 0, 0, 0), TEXEL, NOON)
	ground_shadow(Vector2(POLE_X + 8.0, DECK_Y + 4.0), Vector2(26, 7), 0.3)
	draw_circle(top, 9.0, SUN.darkened(0.3))
	draw_circle(top, 6.0, SUN)
	var warning := _warning()
	var way := _gust_way()
	var full := 0.0
	if _blowing():
		full = 1.0
	elif warning >= 0.0:
		full = smoothstep(0.0, 0.6, warning)
	var limp := Vector2(0.25, 1.0).normalized()
	var aim := way if way != Vector2.ZERO else limp
	var flap := 0.0 if reduced_motion else sin(now * 18.0) * 0.12 * full
	var dir := limp.lerp(aim, full).normalized().rotated(flap)
	var side := dir.orthogonal()
	var rings := 5
	for ring in rings:
		var a := top + dir * (ring * 22.0)
		var b := top + dir * ((ring + 1) * 22.0)
		var wide_a := maxf(6.0, 18.0 - ring * (2.0 + 1.4 * (1.0 - full)))
		var wide_b := maxf(5.0, 18.0 - (ring + 1) * (2.0 + 1.4 * (1.0 - full)))
		var shape := PackedVector2Array([a + side * wide_a, b + side * wide_b, b - side * wide_b, a - side * wide_a])
		draw_colored_polygon(shape, NAVY)
		var inner := PackedVector2Array([a + side * (wide_a - 2.0), b + side * (wide_b - 2.0), b - side * (wide_b - 2.0), a - side * (wide_a - 2.0)])
		var tone := CORAL if ring % 2 == 0 else WHITE
		draw_colored_polygon(inner, tone)
		draw_line(a + side * (wide_a - 3.0), b + side * (wide_b - 3.0), tone.lightened(0.3), 2.0)
	# Before it blows, the gust says what it is beside the pole.
	if warning >= 0.0 or _blowing():
		var word: String = {"lift": "上升氣流", "down": "下沉氣流"}.get(str(state.gust.kind), "側風")
		var arrow: String = {"lift": "↑", "down": "↓"}.get(str(state.gust.kind), "→" if way.x > 0.0 else "←")
		var grow := 1.0 + (0.1 * pulse(4.0) if warning >= 0.0 and not reduced_motion else 0.0)
		label(Vector2(POLE_X + 92.0, 260.0), "%s %s" % [word, arrow], 24, WHITE if _blowing() else SUN, grow)


func _draw_shadow(shuttle: Dictionary) -> void:
	var height := clampf(float(shuttle.y), 0.0, 1.0)
	ground_shadow(Vector2(_x(float(shuttle.x)), DECK_Y + 6.0), Vector2(26.0 - 14.0 * height, 7.0 - 3.0 * height), 0.5 - 0.32 * height)


## A shuttlecock, cork first along `velocity` (screen pixels per second).
func _draw_shuttle(at: Vector2, velocity: Vector2, scale_factor := 4.0, angle := INF) -> void:
	if angle == INF:
		angle = velocity.angle() - PI * 0.5 if velocity.length() > 20.0 else 0.0
	var centre := Vector2(4.5, 6.0) * scale_factor
	draw_set_transform(at, angle, Vector2.ONE)
	stamp(_shuttle, -centre, scale_factor, NOON)
	draw_set_transform(Vector2.ZERO)


func _hero_feet() -> Vector2:
	return Vector2(_x(float(state.get("hero_x", 0.5))), DECK_Y + 4.0)


func _draw_hero() -> void:
	var feet := _hero_feet()
	var hat_since := age(float(state.get("hat_at", -99.0)))
	var flight := float(state.get("hat_flight", 0.35))
	var plunked := hat_since >= flight and hat_since < flight + 0.9
	var rally := int(state.get("rally", 0))
	var mood := "shocked" if plunked else ("tongue" if rally >= 8 else "plain")
	var facing := int(state.get("facing", 0))
	var lean := 0.0 if reduced_motion else facing * 0.1
	var knock := squash(hat_since - flight, 0.3, 0.3) if plunked and not reduced_motion else Vector2.ONE
	ground_shadow(feet + Vector2(4, 0), Vector2(54, 12), 0.42)
	if facing != 0 and str(state.get("stage", "")) == "play":
		dust_puffs(feet - Vector2(facing * 34.0, 4.0), fposmod(now, 0.4), 24.0)
	draw_set_transform(feet, lean, knock)
	stamp(Hero.texture(&"up", true, mood), -Vector2(20, 46) * HERO_SCALE, HERO_SCALE, NOON)
	draw_set_transform(Vector2.ZERO)
	_draw_racket(feet)
	_draw_hat(feet + Vector2(lean * 120.0, -44.0 * HERO_SCALE))
	if plunked and not reduced_motion:
		dust_puffs(feet + Vector2(0, -44.0 * HERO_SCALE), hat_since - flight, 36.0)


## The shuttles the traveller has missed, stuck cork-first in their hair.
func _draw_hat(head: Vector2) -> void:
	var settled := int(state.get("hats", 0))
	if age(float(state.get("hat_at", -99.0))) < float(state.get("hat_flight", 0.35)):
		settled -= 1
	for index in settled:
		var spread := (index - (settled - 1) * 0.5) * 0.4
		var lean := spread * 0.9 + (0.16 if index % 2 == 0 else -0.1)
		# Cork down in the hair, feathers fanning up, each a little crooked.
		var base := head + Vector2(spread * 36.0, 12.0 + spread * spread * 12.0)
		_draw_shuttle(base + Vector2.from_angle(lean - PI * 0.5) * 4.5 * 3.2, Vector2.ZERO, 3.2, lean)


## A missed shuttle hopping from the deck onto the traveller's head.
func _draw_flying_hat(shuttle: Dictionary) -> void:
	var t := clampf(age(float(shuttle.at)) / float(state.get("hat_flight", 0.35)), 0.0, 1.0)
	if t >= 1.0:
		return
	var from: Vector2 = shuttle.from
	var start := Vector2(_x(from.x), DECK_Y - 8.0)
	var head := _hero_feet() + Vector2(0, -44.0 * HERO_SCALE + 6.0)
	var at := start.lerp(head, t) + Vector2(0, -120.0 * sin(t * PI))
	_draw_shuttle(at, Vector2.ZERO, 3.2, t * TAU)


func _draw_racket(feet: Vector2) -> void:
	# Held up over the head; it flicks up on every hit, gold on a clean one.
	var swing := age(float(state.get("swing_at", -99.0)))
	var tilt := 0.0
	if swing < 0.25 and not reduced_motion:
		tilt = -0.35 * sin(swing / 0.25 * PI)
	var head := Vector2(_x(float(state.get("hero_x", 0.5))), _y(float(state.get("racket_y", 0.44))))
	var grip := feet + Vector2(14, -40.0 * HERO_SCALE)
	# The racket head is exactly as wide as the part that hits.
	var across := int(round(float(state.get("racket_half", 0.07)) * WIDE * 2.0 / TEXEL))
	var racket := Pixels.bake("updraft-racket|%d" % across, Vector2i(across, 22), _paint_racket.bind(across))
	var neck := head + Vector2(0, 13.0 * TEXEL).rotated(tilt)
	draw_line(grip, neck, DARK_WOOD.darkened(0.3), 10.0)
	draw_line(grip, neck, WOOD.lightened(0.15), 5.0)
	draw_set_transform(head, tilt, Vector2.ONE)
	stamp(racket, Vector2(-across * 0.5, -9.0) * TEXEL, TEXEL, NOON)
	draw_set_transform(Vector2.ZERO)
	if swing < 0.3:
		if bool(state.get("swing_sweet", false)):
			glint(head + Vector2(0, -6), 30.0, 99.0, -swing)
		if not reduced_motion:
			draw_arc(head, 48.0 + swing * 120.0, PI * 1.1, PI * 1.9, 12, Color(WHITE, 0.7 * (1.0 - swing / 0.3)), 4.0)


func _draw_rally() -> void:
	var rally := int(state.get("rally", 0))
	if rally >= 3:
		label(Vector2(1120, 230), "連續 × %d" % rally, 26, SUN, 1.0 + 0.08 * pulse(2.0))


# --- Texel painters -------------------------------------------------------------

func _paint_sky(x: int, y: int) -> Color:
	# Deep blue at the top fading to pale near a sea of clouds, a warm glow
	# round the sun, and the rounded tops of the cloud sea along the bottom.
	var fall := float(y) / 182.0
	var tone := DEEP.lerp(SKY, smoothstep(0.0, 0.55, fall)).lerp(PALE, smoothstep(0.5, 0.95, fall))
	var sun := Vector2(262, 40)
	var glow := 1.0 - clampf((Vector2(x, y) - sun).length() / 70.0, 0.0, 1.0)
	tone = tone.lerp(Color("#fff1c8"), glow * glow * 0.55)
	if (Vector2(x, y) - sun).length() < 9.0:
		return SUN.lightened(0.4)
	var crest := 128.0 - 7.0 * absf(sin(x * 0.09)) - 5.0 * absf(sin(x * 0.037 + 1.3)) - 3.0 * Pixels.noise(x / 3, 0, 4)
	if y >= crest:
		var depth := (y - crest) / 20.0
		var cloud := WHITE.lerp(CLOUD_SHADE, clampf(depth, 0.0, 1.0))
		return Pixels.lit(cloud, 0.6 - depth, x, y)
	return Pixels.lit(tone, 0.15, x, y)


func _paint_cloud(x: int, y: int) -> Color:
	var at := Vector2(x + 0.5, y + 0.5)
	var puffs := [Vector3(8, 7, 5), Vector3(15, 5, 6), Vector3(22, 7, 5), Vector3(15, 8, 4)]
	for puff: Vector3 in puffs:
		var offset := (at - Vector2(puff.x, puff.y)) / puff.z
		if offset.length() <= 1.0:
			return WHITE if offset.y < 0.35 else CLOUD_SHADE
	return Pixels.CLEAR


func _paint_shuttle(x: int, y: int) -> Color:
	# Feather skirt on top (wide, white, ribbed), a red band, and a round cork below.
	var mid := 4.5
	var from_mid := absf(x + 0.5 - mid)
	if y <= 7:
		var spread := 1.2 + (7 - y) * 0.48
		if from_mid > spread:
			return Pixels.CLEAR
		if y == 0 and x % 2 == 0:
			return Pixels.CLEAR
		var rib := x % 2 == 0 and y > 1
		return CLOUD_SHADE if rib else WHITE
	if y == 8:
		return CORAL if from_mid <= 2.0 else Pixels.CLEAR
	var cork := (Vector2(x + 0.5, y + 0.5) - Vector2(mid, 9.4)) / Vector2(2.4, 2.4)
	if cork.length() > 1.0:
		return Pixels.CLEAR
	return Pixels.rounded(CORK, cork)


func _paint_racket(x: int, y: int, across: int) -> Color:
	# The oval frame seen a little from below, a criss-cross of strings, and a
	# V-shaped throat down to the handle.
	var mid := across * 0.5
	if y >= 17:
		var gap := absf(x + 0.5 - mid)
		var arm := (21.0 - y) * 1.6
		return CORAL.darkened(0.12) if gap <= arm + 0.8 and gap >= arm - 0.8 or (y == 21 and gap <= 1.0) else Pixels.CLEAR
	var ring := (Vector2(x + 0.5, y + 0.5) - Vector2(mid, 9.0)) / Vector2(mid, 9.0)
	var reach := ring.length()
	if reach > 1.0:
		return Pixels.CLEAR
	if reach > 0.8:
		return Pixels.rounded(CORAL, ring)
	return Color("#e8f1fa") if (x % 3 == 0 or y % 3 == 0) else Pixels.CLEAR


func _paint_kite(x: int, y: int, tone: Color) -> Color:
	# A diamond kite with crossed spars.
	var at := Vector2(x + 0.5, y + 0.5) - Vector2(6.0, 6.0)
	if absf(at.x) / 6.0 + absf(at.y) / (6.0 if at.y < 0.0 else 9.0) > 1.0:
		return Pixels.CLEAR
	if absf(at.x) < 0.6 or absf(at.y) < 0.6:
		return DARK_WOOD
	return tone.lightened(0.18) if (at.x < 0.0) == (at.y < 0.0) else tone
