extends "res://game/minigames/arcade/arcade_view.gd"
## Picture for 螢火蟲長曝光: the moss pond at night seen over the top of an old
## camera, firefly trails that grow while the shutter is open, the lamp sockets
## on the camera's top plate, every temptation, and the print: crisp trails or
## a smeared ghost. The real lamp is always round with the camera mark; fakes
## differ in shape and mark, never in colour alone. Scene and objects are baked
## pixel art (arcade_pixels.gd).

const CAMERA_TOP := 470.0
const POND_ROW := 98
const LAMP_Y := 512.0
const LAMP_XS: Array[float] = [440.0, 640.0, 840.0]
const FLIES := 12
const TRAIL_STEP := 0.09
const PRINT := Rect2(430, 162, 420, 300)
const FILM := Rect2i(4, 4, 97, 52)
const NIGHT := Color("#0c1a2a")
const GLASS := Color("#1b3a4a")
const LEAF := Color("#143530")
const MOSS := Color("#2a5a40")
const GLOW := Color("#dcff8a")
const REAL := Color("#6fd39a")
const BODY := Color("#2a2533")
const PLATE := Color("#5b5566")
const BRASS := Color("#c9953e")
const PAPER := Color("#e9d8b0")
const PROMPTS: Array[String] = ["快按！", "就是現在！", "按下去啦！"]
const SPOTS: Array[Vector2] = [Vector2(300, 250), Vector2(640, 300), Vector2(960, 230)]
## Fake lamp looks: [glass colour, mark]; baked square, diamond and triangle.
const FAKES: Array = [[Color("#d9626a"), "✕"], [Color("#e0a04a"), "？"], [Color("#6fd39a"), "！"]]
const PADS: Array[Vector2] = [Vector2(47, 106), Vector2(105, 110), Vector2(163, 104), Vector2(221, 109), Vector2(279, 105)]

var _trail := PackedVector2Array()
## Sprites, baked once in _ready().
var _scene: ImageTexture
var _cameras: Dictionary = {}
var _reed: ImageTexture
var _lamp: ImageTexture
var _fakes: Array[ImageTexture] = []
var _paper: ImageTexture
var _ghost: ImageTexture
var _bug: ImageTexture


func _init() -> void:
	super()
	word_anchor = Vector2(226, 404)


func _ready() -> void:
	_scene = Pixels.bake("still-scene", Vector2i(320, 118), _paint_scene)
	for slots: int in [1, 3]:
		_cameras[slots] = Pixels.bake("still-camera|%d" % slots, Vector2i(320, 63), _paint_camera.bind(slots))
	_reed = Pixels.bake("still-reed", Vector2i(5, 28), _paint_reed)
	_lamp = Pixels.bake("still-lamp", Vector2i(17, 17), _paint_lamp)
	for look in FAKES.size():
		_fakes.append(Pixels.bake("still-fake|%d" % look, Vector2i(17, 17), _paint_fake.bind(look)))
	_paper = Pixels.bake("still-print", Vector2i(105, 75), _paint_print)
	_ghost = Pixels.bake("still-ghost", Vector2i(34, 40), _paint_ghost)
	_bug = Pixels.bake("still-bug", Vector2i(17, 15), _paint_bug)


func _draw_backdrop() -> void:
	stamp(_scene, Vector2.ZERO)
	# Glints drift on the pond and the reeds lean with the night air.
	for glint in 7:
		var slide := 0.0 if reduced_motion else 14.0 * sin(now * 0.6 + glint)
		draw_rect(Rect2(120.0 + glint * 150.0 + slide, 400.0 + glint * 9.0, 44, 4), Color(0.7, 0.9, 0.95, 0.2))
	for reed in 10:
		var foot := Vector2(24.0 + reed * 136.0 + 30.0 * sin(reed * 3.3), CAMERA_TOP + 6.0)
		draw_set_transform(foot, 0.0 if reduced_motion else 0.05 * sin(now * 0.9 + reed), Vector2(1.0, 0.8 + 0.2 * sin(reed * 1.7)))
		stamp(_reed, Vector2(-10, -112))
	draw_set_transform(Vector2.ZERO)
	vignette(0.7)


func _draw_scene() -> void:
	var phase := str(state.get("phase", "frame"))
	var since := age(float(state.get("phase_at", 0.0)))
	var result := str(state.get("result", ""))
	var exposed := float(state.get("exposed", 0.0))
	var exposing := phase == "expose"
	# A press with the shutter open jolts the whole view for a moment.
	var jolt := Vector2.ZERO
	if phase == "print" and result == "smear" and since < 0.4 and not reduced_motion:
		jolt = Vector2(sin(since * 90.0), cos(since * 70.0)) * 14.0 * (1.0 - since / 0.4)
	if exposing:
		_draw_trails(exposed, Transform2D(0.0, jolt), 1.0)
	_draw_flies(exposed if exposing else now, jolt)
	_draw_viewfinder(phase, exposed, since)
	_draw_camera(phase)
	if exposing:
		_draw_decoys()
	if phase == "print":
		_draw_print(result, exposed, since)


# --- Fireflies --------------------------------------------------------------

## Where firefly `index` is `at` seconds into this photo; each photo has its own swarm.
func _fly(index: int, at: float) -> Vector2:
	var own := float(index) * 1.7 + float(state.get("photo_seed", 0)) * 0.37
	return Vector2(640.0 + 450.0 * sin(own * 2.3) + 76.0 * sin(at * (0.9 + 0.13 * (index % 5)) + own),
		286.0 + 96.0 * sin(own * 1.3 + 1.0) + 48.0 * sin(at * (1.3 + 0.17 * (index % 4)) + own * 2.0))


func _draw_flies(at: float, jolt: Vector2) -> void:
	for index in FLIES:
		var spot := _fly(index, at) + jolt
		var blink := 0.75 if reduced_motion else 0.55 + 0.45 * sin(now * 3.0 + index * 1.9)
		draw_circle(spot, 14.0, Color(GLOW, 0.12 * blink))
		draw_rect(Rect2(spot - Vector2(6, 6), Vector2(12, 12)), Color(GLOW, 0.22 * blink))
		draw_rect(Rect2(spot - Vector2(4, 4), Vector2(8, 8)), Color(GLOW, 0.6 + 0.4 * blink))
		draw_rect(Rect2(spot - Vector2(4, 4), Vector2(4, 4)), Color(1, 1, 0.9, 0.5 + 0.5 * blink))


## Every firefly's path since the shutter opened, as light left on the film.
func _draw_trails(exposed: float, onto: Transform2D, strength: float) -> void:
	var steps := maxi(2, int(exposed / TRAIL_STEP) + 1)
	draw_set_transform_matrix(onto)
	for index in FLIES:
		_trail.resize(steps)
		for step in steps:
			_trail[step] = _fly(index, exposed * step / float(steps - 1))
		draw_polyline(_trail, Color(GLOW, 0.14 * strength), 11.0)
		draw_polyline(_trail, Color(GLOW, 0.75 * strength), 3.5)
	draw_set_transform(Vector2.ZERO)


# --- Camera -----------------------------------------------------------------

func _draw_viewfinder(phase: String, exposed: float, since: float) -> void:
	for corner: Vector2 in [Vector2(70, 150), Vector2(1210, 150), Vector2(70, 452), Vector2(1210, 452)]:
		var inward := Vector2(1.0 if corner.x < 640.0 else -1.0, 1.0 if corner.y < 300.0 else -1.0)
		draw_rect(Rect2(minf(corner.x, corner.x + inward.x * 44.0), corner.y - 3.0, 44, 6), Color(PAPER, 0.8))
		draw_rect(Rect2(corner.x - 3.0, minf(corner.y, corner.y + inward.y * 44.0), 6, 44), Color(PAPER, 0.8))
	var note := Vector2(196, 176)
	match phase:
		"frame":
			label(note, "拿穩…要開快門了", 22, PAPER, pop_in(since, 0.2))
		"expose":
			draw_rect(Rect2(note.x - 112.0, note.y - 9.0, 18, 18), ROSE if pulse(1.0) > 0.4 else ROSE.darkened(0.4))
			label(note + Vector2(14, 0), "曝光中 %.1f 秒" % exposed, 22, PAPER)
			if not bool(state.get("lit", false)):
				label(Vector2(640, 176), "別按！", 30, ROSE, 1.0, 0.85)
		"print":
			label(note, "可以動了", 22, MINT)


func _draw_camera(phase: String) -> void:
	var slots := int(state.get("lamp_slots", 1))
	draw_rect(Rect2(0, CAMERA_TOP - 10.0, DESIGN.x, 10), Color(0.02, 0.03, 0.06, 0.45))
	stamp(_cameras[slots], Vector2(0, CAMERA_TOP))
	# The rule, always on the camera: what the real lamp looks and sounds like.
	stamp(_lamp, Vector2(40, LAMP_Y - 26.0), 3.0)
	label(Vector2(232, LAMP_Y - 12.0), "真快門燈：圓形", 17, BODY, 1.0, 1.0, false)
	label(Vector2(232, LAMP_Y + 12.0), "相機圖示＋叮咚", 17, BODY, 1.0, 1.0, false)
	if bool(state.get("lit", false)) and phase == "expose":
		var at := Vector2(LAMP_XS[int(state.get("lamp_slot", 1)) % LAMP_XS.size()], LAMP_Y)
		var glow := age(float(state.get("lamp_at", -99.0)))
		draw_circle(at, 46.0 + 8.0 * pulse(2.5), Color(REAL, 0.22))
		draw_set_transform(at, 0.0, Vector2.ONE * pop_in(glow, 0.14))
		stamp(_lamp, Vector2(-34, -34))
		draw_set_transform(Vector2.ZERO)
		label(at + Vector2(0, -62), "拍！", 34, REAL.lightened(0.2), pop_in(glow, 0.14))
	var needed := int(state.get("lamps_needed", 1))
	if needed > 1:
		label(Vector2(1010, LAMP_Y), "曝光 %d / %d" % [int(state.get("lamps_done", 0)), needed], 20, PAPER)


# --- Temptations ------------------------------------------------------------

func _draw_decoys() -> void:
	var lifetime := float(state.get("decoy_seconds", 0.9))
	for decoy: Dictionary in state.get("decoys", []):
		var shown := age(float(decoy.at))
		if shown < 0.0 or shown > lifetime:
			continue
		var fade := 1.0 - smoothstep(lifetime - 0.2, lifetime, shown)
		var spot: Vector2 = SPOTS[int(decoy.slot) % SPOTS.size()]
		match str(decoy.kind):
			"prompt":
				label(spot, PROMPTS[int(decoy.look) % PROMPTS.size()], 60, GOLD, pop_in(shown, 0.16), fade)
				label(spot + Vector2(0, 52), "▼ ▼ ▼", 22, GOLD, 1.0, fade)
			"mosquito":
				var crawl := spot + Vector2(0.0 if reduced_motion else sin(shown * 9.0) * 30.0, 40.0 * shown)
				stamp(_bug, crawl - Vector2(51, 45), 6.0, Color(1, 1, 1, fade))
				label(crawl + Vector2(86, -30), "嗡～", 24, PAPER, 1.0, fade)
			"itch":
				var bar := Rect2(spot.x - 110.0, spot.y - 16.0, 220, 32)
				draw_rect(bar.grow(4.0), Color(BODY, fade))
				for cell in int(11.0 * clampf(shown / (lifetime * 0.8), 0.0, 1.0)):
					draw_rect(Rect2(bar.position.x + cell * 20.0 + 2.0, bar.position.y + 2.0, 16, 28), Color(ROSE.darkened(0.25), fade))
					draw_rect(Rect2(bar.position.x + cell * 20.0 + 2.0, bar.position.y + 2.0, 16, 8), Color(ROSE, fade))
				label(spot + Vector2(0, -36), "鼻子好癢…", 24, PAPER, 1.0, fade)
				if shown > lifetime * 0.7:
					label(spot + Vector2(0, 42), "哈…哈…", 26, ROSE, pop_in(shown - lifetime * 0.7, 0.14), fade)
			"lamp":
				var look := int(decoy.look) % FAKES.size()
				var socket := Vector2(LAMP_XS[int(decoy.slot) % LAMP_XS.size()], LAMP_Y)
				draw_set_transform(socket, 0.0, Vector2.ONE * pop_in(shown, 0.14))
				stamp(_fakes[look], Vector2(-34, -34), TEXEL, Color(1, 1, 1, fade))
				draw_set_transform(Vector2.ZERO)
				label(socket + Vector2(0, 4), str(FAKES[look][1]), 28, BODY, 1.0, fade, false)
			"flash":
				# A soft wash, never a hard strobe; reduced motion gets a still frame line instead.
				if reduced_motion:
					draw_rect(Rect2(60, 140, 1160, 322), Color(1, 1, 1, 0.5 * fade), false, 6.0)
				else:
					draw_rect(Rect2(0, PLAY_TOP, DESIGN.x, CAMERA_TOP - PLAY_TOP), Color(1, 1, 1, 0.2 * (1.0 - smoothstep(0.0, 0.5, shown))))
				label(spot, "♪？", 40, PAPER, pop_in(shown, 0.16), fade * 0.8)


# --- Print ------------------------------------------------------------------

func _draw_print(result: String, exposed: float, since: float) -> void:
	var rise := 1.0 if reduced_motion else smoothstep(0.0, 0.22, since)
	var card := PRINT
	card.position.y += 260.0 * (1.0 - rise)
	var tilt := -0.03
	if result == "smear" and not reduced_motion:
		tilt += sin(since * 26.0) * 0.05 * maxf(0.0, 1.0 - since)
	var frame := Transform2D(tilt, card.get_center())
	var corner := -card.size * 0.5
	var film := Rect2(corner + Vector2(FILM.position) * TEXEL, Vector2(FILM.size) * TEXEL)
	draw_set_transform_matrix(frame)
	draw_rect(Rect2(corner + Vector2(10, 14), card.size), Color(0.02, 0.03, 0.06, 0.4))
	draw_rect(film, Color("#f4efe0") if result == "over" else Color("#0d1f2c"))
	draw_set_transform(Vector2.ZERO)
	# The whole view squeezed onto the film.
	var squeeze := Vector2(film.size.x / 1160.0, film.size.y / 330.0)
	var onto := frame * Transform2D(0.0, squeeze, 0.0, film.position - Vector2(60, 130) * squeeze)
	var verdict := "清晰！"
	match result:
		"crisp":
			_draw_trails(exposed, onto, 1.0)
		"smear":
			verdict = "糊成鬼影了！"
			_draw_trails(exposed, onto, 0.25)
			var sway := 0.0 if reduced_motion else sin(since * 6.0) * 8.0
			draw_set_transform_matrix(frame)
			for echo in 3:
				stamp(_ghost, film.get_center() + Vector2(-68.0 + sway - (echo + 1) * 30.0, -84.0), TEXEL, Color(1, 1, 1, 0.14))
			stamp(_ghost, film.get_center() + Vector2(-68.0 + sway, -84.0), TEXEL, Color(1, 1, 1, 0.92))
		_:
			verdict = "過曝了，一片白…"
			draw_set_transform_matrix(frame)
			for dot: Vector2 in [Vector2(-36, -56), Vector2(22, -56)]:
				draw_rect(Rect2(dot, Vector2(14, 14)), Color("#d9d2c0"))
			draw_rect(Rect2(-26, -16, 52, 10), Color("#d9d2c0"))
	draw_set_transform_matrix(frame)
	stamp(_paper, corner)
	draw_set_transform(Vector2.ZERO)
	label(card.get_center() + Vector2(0, card.size.y * 0.5 - 36.0), verdict, 28, BODY if result == "crisp" else ROSE.darkened(0.3), pop_in(since - 0.15, 0.2), 1.0, false)


# --- Texel painters ---------------------------------------------------------

## Night air through the glasshouse, a moon, hedges, and the pond with its lily pads.
func _paint_scene(x: int, y: int) -> Color:
	var at := Vector2(x + 0.5, y + 0.5)
	if y >= POND_ROW:
		for pad in PADS:
			var leaf := (at - pad) / Vector2(8.5, 3.2)
			if leaf.length() < 1.0:
				if leaf.x > 0.2 and absf(leaf.y) < leaf.x * 0.3:
					break
				return MOSS.lightened(0.12) if leaf.y < -0.3 else Pixels.grainy(MOSS, x, y, 0.2)
		if y > 114 and Pixels.noise(x / 3, 0, 8) > 0.35:
			return Pixels.grainy(MOSS.darkened(0.3), x, y, 0.25)
		var water := Color("#0f2c3c").lightened(0.06) if (y + x / 9) % 3 == 0 else Color("#0f2c3c")
		if absf(at.x - 260.0) < 9.0 - (y - POND_ROW) * 0.3 and (x + y) % 2 == 0:
			water = water.lightened(0.22)
		return water.lightened(0.14) if Pixels.noise(x / 6, y, 4) > 0.86 else water
	# Hedges along the far bank: two rows of leafy clumps with lit crowns.
	var crown := POND_ROW - 11.0 - 7.0 * Pixels.noise(x / 9, 0, 3) - 3.0 * Pixels.noise(x / 3, 1, 3)
	if at.y > crown:
		if at.y < crown + 2.0:
			return LEAF.lightened(0.16)
		return LEAF.darkened(0.25) if Pixels.noise(x / 2, y / 2, 6) > 0.6 else LEAF
	var back := POND_ROW - 22.0 - 9.0 * Pixels.noise(x / 13, 2, 3)
	if at.y > back:
		return LEAF.darkened(0.35) if at.y > back + 1.5 else LEAF.darkened(0.1)
	# Iron ribs with rivets.
	if x % 50 == 10 or x % 50 == 11 or y == 59 or y == 60:
		var crossing := (x % 50 == 10 or x % 50 == 11) and (y == 59 or y == 60)
		return Color("#3a5560") if crossing else (Color("#0a171d") if x % 50 == 11 or y == 60 else Color("#16303a"))
	var moon := at - Vector2(260.0, 49.0)
	if moon.length() < 10.0:
		var face := Pixels.rounded(Color("#cfe3e0"), moon / 10.0)
		return face.darkened(0.12) if Pixels.noise(x / 2, y / 2, 11) > 0.78 else face
	# Dithered dusk: darker overhead, greener toward the pond.
	var depth := float(y) / float(POND_ROW) * 5.0 + Pixels.noise(x, y, 1) * 0.9
	var air := NIGHT.lerp(GLASS, floorf(depth) / 5.0)
	if moon.length() < 17.0 and (x + y) % 2 == 0:
		air = air.lightened(0.12)
	return Color("#c9dfe6") if y < 44 and Pixels.noise(x, y, 7) > 0.995 else air


## The camera seen from behind: a top plate with the lamp sockets, the rule on
## an enamel plate, a knurled dial, and pebbled leather below.
func _paint_camera(x: int, y: int, slots: int) -> Color:
	var at := Vector2(x + 0.5, y + 0.5)
	if y >= 24:
		if y == 26 and x % 4 < 2:
			return PAPER.darkened(0.35)
		if (x < 56 or x > 264) and x % 4 == 0:
			return BODY.lightened(0.12)
		return BODY.lightened(0.07) if Pixels.noise(x / 2, y / 2, 2) > 0.62 else Pixels.grainy(BODY, x, y, 0.2)
	if y < 2:
		return PLATE.lightened(0.3)
	if y >= 22:
		return PLATE.darkened(0.45)
	for slot in LAMP_XS.size():
		if slots == 1 and slot != 1:
			continue
		var well := at - Vector2(LAMP_XS[slot] / TEXEL, (LAMP_Y - CAMERA_TOP) / TEXEL)
		if well.length() < 10.4:
			return Pixels.rounded(BRASS, well / 10.4) if well.length() > 8.6 else Color("#15121c").lightened(0.05 * (well.y + 9.0) / 9.0)
	var plate := Rect2(6, 3, 88, 17)
	if plate.has_point(at):
		return BODY if not plate.grow(-1.0).has_point(at) else Pixels.grainy(PAPER, x, y, 0.07)
	var dial := at - Vector2(291.0, 11.0)
	if dial.length() < 8.6:
		if dial.length() > 6.2:
			return PLATE.lightened(0.35) if int(dial.angle() * 9.0 + 40.0) % 2 == 0 else PLATE.darkened(0.3)
		return Pixels.rounded(PLATE.lightened(0.15), dial / 6.2)
	return Pixels.metal(PLATE, x, y, 3)


func _paint_reed(x: int, y: int) -> Color:
	if y < 9:
		return Pixels.grainy(Color("#4a3628"), x, y, 0.25) if x >= 1 and x <= 3 and y >= 1 else Pixels.CLEAR
	return Color("#1d4a36") if x == 2 else Pixels.CLEAR


## The real shutter lamp: round green glass with the camera mark.
func _paint_lamp(x: int, y: int) -> Color:
	var offset := Vector2(x - 8.0, y - 8.0)
	var reach := offset.length()
	if reach > 8.6:
		return Pixels.CLEAR
	if reach > 7.0:
		return Pixels.rounded(BRASS, offset / 8.6)
	if (reach > 3.2 and reach < 4.6) or reach < 1.5 or (y == 2 and absf(offset.x) < 2.0):
		return BODY
	return Pixels.rounded(REAL, offset / 7.0)


## A lamp that is not the shutter: square, diamond or triangle glass.
func _paint_fake(x: int, y: int, look: int) -> Color:
	var offset := Vector2(x - 8.0, y - 8.0)
	var inside := maxf(absf(offset.x), absf(offset.y)) < 7.5
	if look == 1:
		inside = absf(offset.x) + absf(offset.y) < 8.6
	elif look == 2:
		inside = offset.y < 6.5 and absf(offset.x) < (offset.y + 8.5) * 0.56
	return Pixels.rounded(FAKES[look][0], offset / 9.0) if inside else Pixels.CLEAR


## Instant-print paper with the film window cut out.
func _paint_print(x: int, y: int) -> Color:
	if FILM.has_point(Vector2i(x, y)):
		return Pixels.CLEAR
	var paper := Pixels.grainy(PAPER, x, y, 0.07)
	return paper.darkened(0.1) if x > 100 or y > 70 else paper


func _paint_ghost(x: int, y: int) -> Color:
	var at := Vector2(x + 0.5, y + 0.5)
	var pale := Color("#d6f5c8")
	var head := (at - Vector2(17.0, 15.0)) / 15.0
	var body := at.y >= 15.0 and absf(at.x - 17.0) < 15.0 and at.y < 34.0 + 3.0 * sin(at.x * 0.8)
	if head.length() > 1.0 and not body:
		return Pixels.CLEAR
	for eye_x: float in [11.0, 23.0]:
		if ((at - Vector2(eye_x, 14.0)) / Vector2(2.6, 3.8)).length() < 1.0:
			return Color("#0d1f2c")
	if (at - Vector2(17.0, 23.0)).length() < 3.0:
		return Color("#0d1f2c")
	return Pixels.rounded(pale, (at - Vector2(17.0, 19.0)) / Vector2(17.0, 21.0))


func _paint_bug(x: int, y: int) -> Color:
	var at := Vector2(x + 0.5, y + 0.5)
	if ((at - Vector2(8.5, 9.0)) / Vector2(2.6, 5.4)).length() < 1.0:
		return Color("#6b5a52") if int(at.y) % 3 == 0 else Color("#3a2f2c")
	if (at - Vector2(8.5, 3.5)).length() < 2.4:
		return Color("#d9626a") if y == 3 and (x == 7 or x == 9) else Color("#2a2224")
	for side: float in [-1.0, 1.0]:
		if ((at - Vector2(8.5 + side * 5.0, 6.5)) / Vector2(3.6, 1.8)).length() < 1.0:
			return Color("#b9d6e0")
		if absf(at.x - (8.5 + side * (2.0 + (at.y - 8.0) * 0.9))) < 0.6 and at.y > 8.0 and at.y < 14.0:
			return Color("#2a2224")
	return Pixels.CLEAR
