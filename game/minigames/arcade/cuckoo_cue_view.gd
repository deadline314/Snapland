extends "res://game/minigames/arcade/arcade_view.gd"
## Picture for 整點咕咕: a carved cuckoo clock hung on the workshop wall, with
## shingled gable, balcony, bevelled dial, tick lamps, pendulum and pine-cone
## weights; the card that names the tick; the crooked house of the decoy bird;
## and the cuckoo on its concertina arm, which flattens itself on a shut door.
## Every object is baked pixel art (arcade_pixels.gd) in the backdrop's dusky palette.

const YARD_ART := "res://assets/world/toy-clockwork-yard.webp"
const FLOOR_TOP := 566.0
## Top-left of the clock on screen, and its size in texels.
const ORIGIN := Vector2(152, 128)
const HOUSE := Vector2i(94, 86)
const DIAL := Vector2(47, 60)
const SOCKET_Y := 80.0
const SOCKET_XS: Array[float] = [23.75, 39.25, 54.75, 70.25]
const DOOR_SINGLE: Array[Rect2i] = [Rect2i(37, 28, 20, 13)]
const DOOR_DUET: Array[Rect2i] = [Rect2i(15, 28, 20, 13), Rect2i(59, 28, 20, 13)]
const CARD_AT := Vector2(650, 196)
const DECOY_AT := Vector2(1006, 214)
const WALL := Color("#8f5d3f")
const ROOF := Color("#7a3f38")
const TRIM := Color("#b98a52")
const LEAF := Color("#5d7550")
const BRASS := Color("#c9953e")
const PAPER := Color("#e9d8b0")
const RECESS := Color("#1d1420")
const BENCH := Color("#7a5238")
const DOORS: Array[Color] = [Color("#4c7468"), Color("#5b6f9a")]
const BIRDS: Array = [[Color("#e8b84a"), Color("#b9812e")], [Color("#8fc1d4"), Color("#5b8fae")]]
const OWL: Array = [Color("#9a89b8"), Color("#6a5a8c")]
const FOOT := Color("#c9703a")
const DARK := Color("#2b2440")
## Scene light: a touch of the workshop's dusk on every sprite.
const DUSK := Color(1.0, 0.93, 0.86)

var _has_art := false
## Sprites, baked once in _ready().
var _houses: Array[ImageTexture] = []
var _leaves: Array[ImageTexture] = []
var _lamps: Array[ImageTexture] = []
var _cone: ImageTexture
var _bob: ImageTexture
var _card: ImageTexture
var _leg: ImageTexture
var _decoy: ImageTexture
var _plaque: ImageTexture
## Body colour -> mood -> sprite.
var _bird_art: Dictionary = {}


func _init() -> void:
	super()
	word_anchor = Vector2(774, 500)


func _ready() -> void:
	_has_art = use_backdrop_art(YARD_ART, Rect2(0, 20, 1157, 651), Color(0.56, 0.5, 0.58))
	for doors: Array in [DOOR_SINGLE, DOOR_DUET]:
		_houses.append(Pixels.bake("cuckoo-house|%d" % doors.size(), HOUSE, _paint_house.bind(doors)))
	for index in DOORS.size():
		_leaves.append(Pixels.bake("cuckoo-door|%d" % index, Vector2i(20, 13), _paint_door.bind(DOORS[index])))
	for lit: bool in [false, true]:
		_lamps.append(Pixels.bake("cuckoo-lamp|%s" % lit, Vector2i(9, 9), _paint_lamp.bind(lit)))
	_cone = Pixels.bake("cuckoo-cone", Vector2i(7, 13), _paint_cone)
	_bob = Pixels.bake("cuckoo-bob", Vector2i(11, 11), _paint_bob)
	_card = Pixels.bake("cuckoo-card", Vector2i(62, 60), _paint_card)
	_leg = Pixels.bake("cuckoo-leg", Vector2i(4, 38), func(x: int, y: int) -> Color: return Pixels.wood(BENCH.lightened(0.1), x, y, 4))
	_decoy = Pixels.bake("cuckoo-decoy", Vector2i(36, 46), _paint_decoy)
	_plaque = Pixels.bake("cuckoo-plaque", Vector2i(34, 17), func(x: int, y: int) -> Color:
		if (x < 2 or x > 31) and (y < 2 or y > 14):
			return Pixels.metal(BRASS, x, y)
		return Pixels.wood(WALL.darkened(0.35), x, y, 6, false))
	for palette: Array in BIRDS + [OWL]:
		var moods: Dictionary = {}
		for mood: String in ["plain", "sing", "dizzy", "owl"]:
			moods[mood] = Pixels.bake("cuckoo-bird|%s|%s" % [(palette[0] as Color).to_html(), mood], Vector2i(16, 16), _paint_bird.bind(palette[0], palette[1], mood))
		_bird_art[palette[0]] = moods


func _draw_backdrop() -> void:
	if not _has_art:
		draw_rect(Rect2(Vector2.ZERO, DESIGN), Color("#3a2c2a"))
	bench(FLOOR_TOP, BENCH)
	vignette()


func _draw_scene() -> void:
	var since := now - float(state.get("bar_at", 0.0))
	var targets: Array = state.get("targets", [])
	_draw_clock(since, targets)
	_draw_card(targets)
	_draw_decoy()
	_draw_streak()


func _at(texel: Vector2) -> Vector2:
	return ORIGIN + texel * TEXEL


func _doors() -> Array[Rect2i]:
	return DOOR_DUET if bool(state.get("duet", false)) else DOOR_SINGLE


func _door_rect(target: Dictionary) -> Rect2:
	var doors := _doors()
	var door := doors[int(target.get("door", 0)) % doors.size()]
	return Rect2(_at(Vector2(door.position)), Vector2(door.size) * TEXEL)


# --- Clock ------------------------------------------------------------------

## Position along the bar counted in beats: 0 on the first tick, 1 on the second...
func _beat_phase(since: float) -> float:
	var ticks: Array = state.get("ticks", [])
	if ticks.is_empty():
		return 0.0
	var beat := float(state.get("beat", 0.5))
	if since < float(ticks[0]):
		return (since - float(ticks[0])) / beat
	for index in range(ticks.size() - 1, -1, -1):
		if since >= float(ticks[index]):
			var next := float(ticks[index + 1]) if index + 1 < ticks.size() else float(state.get("bar_length", 0.0)) + beat
			return float(index) + clampf((since - float(ticks[index])) / maxf(next - float(ticks[index]), 0.01), 0.0, 1.0)
	return 0.0


func _draw_clock(since: float, targets: Array) -> void:
	var heard := int(state.get("ticks_heard", 0))
	var ticked := age(float(state.get("tick_at", -99.0)))
	var bonked := 99.0
	for target: Dictionary in targets:
		if str(target.state) == "bonk":
			bonked = minf(bonked, age(float(target.at)))
	var house := _houses[_doors().size() - 1]
	var foot := _at(Vector2(47, HOUSE.y))
	# Pine-cone weights on their chains, slowly trading places.
	for side: float in [-1.0, 1.0]:
		var drop := 34.0 + side * (6.0 if reduced_motion else 8.0 * sin(now * 0.5))
		var top := foot + Vector2(side * 96.0, -6.0)
		for link in int(drop / 8.0):
			draw_rect(Rect2(top.x - 2.0, top.y + link * 8.0, 4, 6), BRASS.darkened(0.45 if link % 2 == 0 else 0.2))
		stamp(_cone, top + Vector2(-14, drop), TEXEL, DUSK)
	# Pendulum: at one end on every tick, through the middle in between. A bar
	# is five half-swings long, so every other bar starts from the other side.
	var phase := _beat_phase(since)
	var side_first := 1.0 if int(state.get("bar", 0)) % 2 == 0 else -1.0
	var swing := side_first * 0.62 * cos(PI * (roundf(phase) if reduced_motion else phase))
	var pivot := foot - Vector2(0, 8)
	var bob := pivot + Vector2(sin(swing), cos(swing)) * 56.0
	draw_line(pivot, bob, BRASS.darkened(0.66), 9.0)
	draw_line(pivot, bob, BRASS.darkened(0.15), 4.0)
	draw_set_transform(bob, 0.0, squash(ticked, 0.22, 0.2))
	stamp(_bob, Vector2(-22, -22), TEXEL, DUSK)
	# The bob catches the light at the end of each swing.
	if ticked >= 0.0 and ticked < 0.16:
		draw_rect(Rect2(-14, -14, 8, 8), Color(1, 0.98, 0.86, 1.0 - ticked / 0.16))
	draw_set_transform(Vector2.ZERO)
	if ticked >= 0.0 and ticked < 0.22 and heard > 0:
		var quiet := bool(state.get("silent", false))
		label(bob + Vector2(60.0 if swing > 0.0 else -60.0, -6), "…" if quiet else ("滴" if heard % 2 == 1 else "答"), 26, Color("#b9b2c8") if quiet else PAPER, 1.0, 1.0 - ticked / 0.22)
	# The clock itself, jolted when a bird hits the door.
	var jolt := Vector2.ZERO
	if bonked < 0.3 and not reduced_motion:
		jolt = Vector2(sin(bonked * 80.0) * 6.0 * (1.0 - bonked / 0.3), 0)
	cast_shadow(house, ORIGIN + jolt, Vector2(14, 16))
	stamp(house, ORIGIN + jolt, TEXEL, DUSK)
	# Hands; a bonk sends them spinning.
	var face := _at(DIAL) + jolt
	var spin := 0.0
	if bonked < 1.2:
		spin = 0.7 if reduced_motion else TAU * 4.0 * (1.0 - pow(1.0 - clampf(bonked / 1.2, 0.0, 1.0), 2.0))
	var bar := int(state.get("bar", 0))
	var minute := Vector2.from_angle((bar * 4 + heard) * TAU / 12.0 + spin * 1.7 - PI * 0.5)
	var hour := Vector2.from_angle(bar * TAU / 12.0 + spin - PI * 0.5)
	draw_line(face + Vector2(2, 3), face + Vector2(2, 3) + hour * 22.0, Color(0, 0, 0, 0.25), 8.0)
	draw_line(face, face + hour * 22.0, DARK, 8.0)
	draw_line(face, face + minute * 36.0, ROOF.darkened(0.35), 6.0)
	draw_line(face, face + minute * 36.0, ROOF.lightened(0.15), 2.0)
	draw_rect(Rect2(face - Vector2(6, 6), Vector2(12, 12)), DARK)
	draw_rect(Rect2(face - Vector2(4, 4), Vector2(4, 4)), BRASS)
	_draw_lamps(targets, heard, jolt)
	for target: Dictionary in targets:
		_draw_door(target, jolt)
	for target: Dictionary in targets:
		_draw_bird(target)


## One lamp per tick lights as the tick sounds; the bird's tick wears a ring.
func _draw_lamps(targets: Array, heard: int, jolt: Vector2) -> void:
	var rang := age(float(state.get("tick_at", -99.0)))
	for index in SOCKET_XS.size():
		var at := _at(Vector2(SOCKET_XS[index], SOCKET_Y)) + jolt
		var lit := index < heard
		if lit:
			draw_circle(at, 24.0 if index < heard - 1 else 24.0 + 10.0 * (1.0 - clampf(rang / 0.2, 0.0, 1.0)), Color(1.0, 0.8, 0.4, 0.2))
		stamp(_lamps[int(lit)], at - Vector2(18, 18), TEXEL, DUSK)
		label(at + Vector2(0, 1), str(index + 1), 15, DARK if lit else Color("#c9b99a"), 1.0, 1.0, false)
	for target: Dictionary in targets:
		var tick := float(target.tick)
		var whole := clampi(int(tick) - 1, 0, SOCKET_XS.size() - 1)
		var x := SOCKET_XS[whole] + (7.75 if tick > floorf(tick) else 0.0)
		var at := _at(Vector2(x, SOCKET_Y)) + jolt
		var tint: Color = BIRDS[int(target.get("door", 0))][0]
		var waiting := str(target.state) == "pending" or str(target.state) == "jammed"
		var shade := tint if waiting else Color(tint, 0.3)
		draw_arc(at, 25.0 + (2.0 * pulse(2.0) if waiting else 0.0), 0.0, TAU, 24, Color(DARK, shade.a), 8.0)
		draw_arc(at, 25.0 + (2.0 * pulse(2.0) if waiting else 0.0), 0.0, TAU, 24, shade, 4.0)
		draw_colored_polygon(PackedVector2Array([at + Vector2(-12, -48), at + Vector2(12, -48), at + Vector2(0, -30)]), Color(DARK, shade.a))
		draw_colored_polygon(PackedVector2Array([at + Vector2(-7, -45), at + Vector2(7, -45), at + Vector2(0, -34)]), shade)


## The door leaf swings on its hinges: wide open for a bird, a quick flap for a wrong press.
func _draw_door(target: Dictionary, jolt: Vector2) -> void:
	var door := _door_rect(target)
	var which := int(target.get("door", 0)) % DOORS.size()
	var status := str(target.state)
	var open := 0.0
	if status == "hit":
		open = pop_in(age(float(target.at)), 0.2)
	elif status == "jammed" or status == "bonk":
		var flap := age(float(state.get("empty_at", -99.0)))
		if flap >= 0.0 and flap < 0.34:
			open = sin(flap / 0.34 * PI)
			label(door.get_center() + Vector2(8, 0), "？", 28, Color("#8d7f9c"))
	draw_set_transform(door.position + jolt, 0.0, Vector2(maxf(0.1, 1.0 - 0.9 * open), 1.0))
	stamp(_leaves[which], Vector2.ZERO, TEXEL, DUSK)
	draw_set_transform(Vector2.ZERO)


func _draw_bird(target: Dictionary) -> void:
	var status := str(target.state)
	if status != "hit" and status != "bonk":
		return
	var door := _door_rect(target)
	var since := age(float(target.at))
	var palette: Array = BIRDS[int(target.get("door", 0))]
	var home := door.get_center()
	if status == "hit":
		var out := pop_in(since, 0.18)
		var at := home + Vector2(14, 6) + Vector2(26, 34) * out
		# The concertina arm unfolds behind the bird.
		var arm := PackedVector2Array([home])
		for fold in 5:
			var along := home.lerp(at, (fold + 1) / 6.0)
			arm.append(along + Vector2(-6, 8) * (1.0 if fold % 2 == 0 else -1.0))
		arm.append(at)
		draw_polyline(arm, BRASS.darkened(0.66), 9.0)
		draw_polyline(arm, BRASS, 4.0)
		_stamp_bird(at, TEXEL * (0.85 + 0.35 * out), palette, "sing", squash(since - 0.18, 0.28), 0.0)
		if since > 0.1:
			label(at + Vector2(92, -44), "咕咕！", 30, GOLD, pop_in(since - 0.1, 0.18))
		return
	# Flat against the door in a puff of dust, then down onto the balcony, seeing stars.
	var slide := 1.0 if reduced_motion else smoothstep(0.18, 0.5, since)
	var flat := Vector2.ONE if slide > 0.0 else Vector2(1.5, 0.55)
	var wobble := 0.0 if reduced_motion else sin(since * 9.0) * 0.28 * maxf(0.0, 1.0 - since * 0.35)
	var rest := home + Vector2(0, 10.0 + 34.0 * slide)
	if since < 0.45 and not reduced_motion:
		for puff in 6:
			var away := Vector2.from_angle(puff * TAU / 6.0 + 0.4) * (30.0 + since * 150.0)
			var size := 14.0 * (1.0 - since / 0.45) + 4.0
			draw_rect(Rect2(home + away - Vector2(size, size) * 0.5, Vector2(size, size)), Color(0.86, 0.78, 0.66, 0.7 * (1.0 - since / 0.45)))
	_stamp_bird(rest, TEXEL * 1.15, palette, "dizzy", flat, wobble)
	if slide > 0.0:
		for star in 3:
			var angle := star * TAU / 3.0 + (0.0 if reduced_motion else since * 5.0)
			var star_at := rest + Vector2(cos(angle) * 44.0, -46.0 + sin(angle) * 12.0)
			draw_rect(Rect2(star_at - Vector2(9, 4), Vector2(18, 8)), DARK)
			draw_rect(Rect2(star_at - Vector2(4, 9), Vector2(8, 18)), DARK)
			draw_rect(Rect2(star_at - Vector2(6, 1.5), Vector2(12, 3)), GOLD)
			draw_rect(Rect2(star_at - Vector2(1.5, 6), Vector2(3, 12)), GOLD)


func _stamp_bird(center: Vector2, scale_factor: float, palette: Array, mood: String, stretch: Vector2, turn: float) -> void:
	var bird: ImageTexture = _bird_art[palette[0]][mood]
	draw_set_transform(center, turn, stretch)
	stamp(bird, Vector2(-8, -8) * scale_factor, scale_factor, DUSK)
	draw_set_transform(Vector2.ZERO)


# --- Card, decoy and streak -------------------------------------------------

func _draw_card(targets: Array) -> void:
	var flip := age(float(state.get("bar_at", 0.0)))
	var middle := CARD_AT + Vector2(124, 120)
	ground_shadow(Vector2(middle.x, FLOOR_TOP + 10.0), Vector2(120, 12), 0.4)
	for side: float in [-1.0, 1.0]:
		draw_set_transform(Vector2(middle.x + side * 34.0, CARD_AT.y + 214.0), side * -0.16)
		stamp(_leg, Vector2(-8, 0), TEXEL, DUSK)
	draw_set_transform(Vector2.ZERO)
	draw_rect(Rect2(CARD_AT.x - 14.0, CARD_AT.y + 240.0, 276, 12), BENCH.darkened(0.55))
	draw_rect(Rect2(CARD_AT.x - 14.0, CARD_AT.y + 240.0, 276, 4), BENCH.lightened(0.2))
	# A fresh card drops onto the easel for every bar.
	var settle := squash(flip, 0.14, 0.24)
	draw_set_transform(middle + Vector2(0, 120), -0.025, settle)
	cast_shadow(_card, Vector2(-124, -240), Vector2(8, 8), TEXEL, 0.25)
	stamp(_card, Vector2(-124, -240), TEXEL, DUSK)
	draw_set_transform(Vector2.ZERO)
	label(CARD_AT + Vector2(124, 24), "這一小節", 21, PAPER)
	for index in targets.size():
		var target: Dictionary = targets[index]
		var tick := float(target.tick)
		var row := CARD_AT + Vector2(124, 118.0 if targets.size() == 1 else 96.0 + index * 74.0)
		var words := "第 %d 下" % int(tick) + ("半" if tick > floorf(tick) else "")
		if targets.size() > 1:
			_stamp_bird(Vector2(row.x - 86.0, row.y), TEXEL * 0.8, BIRDS[int(target.get("door", 0))], "plain", Vector2.ONE, 0.0)
			row.x += 22.0
		label(row, words, 52 if targets.size() == 1 else 38, DARK, 1.0, 1.0, false)
		if targets.size() == 1:
			label(row + Vector2(0, 60), "滴答之間！" if tick > floorf(tick) else "開門！", 24, ROOF.darkened(0.1), 1.0, 1.0, false)
	if bool(state.get("silent", false)):
		label(CARD_AT + Vector2(124, 218), "靜音：看鐘擺", 20, Color("#4f5f8c"), 1.0, 1.0, false)


## The decoy bird's crooked little house: it pops on the wrong tick to bait a press.
func _draw_decoy() -> void:
	var out := age(float(state.get("decoy_at", -99.0)))
	var sway := 0.0 if reduced_motion else sin(now * 0.8) * 0.02
	var hook := DECOY_AT + Vector2(72, -86)
	draw_line(hook, DECOY_AT + Vector2(72, 4), Color("#3a2c2a"), 6.0)
	draw_line(hook, DECOY_AT + Vector2(72, 4), Color("#8a745a"), 2.0)
	cast_shadow(_decoy, DECOY_AT, Vector2(12, 14))
	draw_set_transform(hook, sway)
	stamp(_decoy, DECOY_AT - hook, TEXEL, DUSK)
	draw_set_transform(Vector2.ZERO)
	label(DECOY_AT + Vector2(72, 204), "騙人鳥", 17, PAPER)
	if out >= 0.0 and out < 0.6:
		var hole := DECOY_AT + Vector2(72, 100)
		_stamp_bird(hole + Vector2(0, 6.0 * pop_in(out, 0.14)), TEXEL * (0.8 + 0.3 * pop_in(out, 0.14)), OWL, "owl", squash(out - 0.14, 0.2), 0.0)
		label(hole + Vector2(0, -78), "咕？", 26, OWL[0].lightened(0.3), pop_in(out, 0.14))


func _draw_streak() -> void:
	var streak := int(state.get("streak", 0))
	if streak < 2:
		return
	var at := DECOY_AT + Vector2(4, 236)
	cast_shadow(_plaque, at, Vector2(6, 8))
	stamp(_plaque, at, TEXEL, DUSK)
	label(at + Vector2(68, 20), "連續", 16, PAPER)
	label(at + Vector2(68, 46), "× %d" % streak, 26, GOLD, 1.0 + 0.1 * pulse(2.0))


# --- Texel painters ---------------------------------------------------------

func _paint_house(x: int, y: int, doors: Array) -> Color:
	var at := Vector2(x + 0.5, y + 0.5)
	var off := absf(at.x - 47.0)
	if at.y < 24.0:
		# Gable: a shingled roof band over a carved panel.
		var reach := 47.0 * at.y / 24.0
		if off > reach:
			return Pixels.CLEAR
		if off > reach - 10.0 or at.y < 6.0:
			return Pixels.shingle(ROOF, x + int(off * 0.5), y, 6, 4)
		var panel := Pixels.wood(WALL.darkened(0.2), x, y, 6)
		if off > reach - 13.0:
			panel = panel.darkened(0.3)
		for side: float in [-1.0, 1.0]:
			var leaf := (at - Vector2(47.0 + side * 8.0, 17.0)) / Vector2(6.0, 3.2)
			if leaf.length() < 1.0:
				return LEAF.darkened(0.25) if absf(leaf.y) < 0.2 else Pixels.rounded(LEAF, leaf)
		var stud := (at - Vector2(47.0, 14.0)) / 2.6
		return Pixels.rounded(BRASS, stud) if stud.length() < 1.0 else panel
	if at.x < 10.0 or at.x > 84.0:
		return ROOF.darkened(0.35) if at.y < 27.0 and at.x > 2.0 and at.x < 92.0 else Pixels.CLEAR
	var wall := Pixels.wood(WALL, x, y, 8)
	if at.y < 27.0:
		wall = wall.darkened(0.36)
	elif at.y < 30.0:
		wall = wall.darkened(0.16)
	for door: Rect2i in doors:
		var recess := Rect2(door)
		if recess.has_point(at):
			return RECESS.lightened(0.1 * (at.y - recess.position.y) / recess.size.y)
		if recess.grow(2.0).has_point(at):
			return Pixels.grainy(TRIM, x, y, 0.14)
		# Balcony: a rail on turned balusters under the door.
		var rail := Rect2(recess.position.x - 4.0, recess.end.y + 2.0, recess.size.x + 8.0, 5.0)
		if rail.has_point(at):
			if at.y < rail.position.y + 1.0 or at.y > rail.end.y - 1.0:
				return TRIM.lightened(0.1)
			return TRIM.darkened(0.15) if x % 3 == 0 else wall.darkened(0.45)
	var dial := at - DIAL
	var rim := dial.length()
	if rim < 14.0:
		if rim > 11.6:
			return Pixels.rounded(BRASS, dial / 14.0)
		if rim > 10.8:
			return PAPER.darkened(0.35)
		var face := Pixels.grainy(PAPER, x, y, 0.07)
		var hour := fposmod(dial.angle() / TAU * 12.0, 1.0)
		if rim > 7.6 and (hour < 0.1 or hour > 0.9):
			return DARK.lightened(0.15)
		return face.darkened(0.12) if dial.y > 0.0 and rim > 6.0 else face
	if rim < 15.2:
		return wall.darkened(0.4)
	if at.y > 73.0:
		# Carved base with a brass socket for every tick lamp.
		for socket_x in SOCKET_XS:
			var socket := at - Vector2(socket_x, SOCKET_Y)
			if socket.length() < 5.2:
				return Pixels.rounded(BRASS, socket / 5.2) if socket.length() > 3.9 else RECESS
		if at.y < 75.0:
			return TRIM if x % 4 < 2 else TRIM.darkened(0.25)
		return Pixels.wood(WALL.darkened(0.32), x, y, 5, false)
	return wall


func _paint_door(x: int, y: int, paint: Color) -> Color:
	if (y == 2 or y == 10) and x < 8:
		return DARK.lightened(0.2)
	if Vector2(x - 16.0, y - 6.5).length() < 1.6:
		return BRASS.lightened(0.15)
	return Pixels.wood(paint, x, y, 5)


func _paint_lamp(x: int, y: int, lit: bool) -> Color:
	var offset := Vector2(x - 4.0, y - 4.0) / 4.6
	if offset.length() > 1.0:
		return Pixels.CLEAR
	return Pixels.rounded(Color("#ffcf6a") if lit else Color("#6b4a36"), offset)


func _paint_bob(x: int, y: int) -> Color:
	var offset := Vector2(x - 5.0, y - 5.0) / 5.6
	var reach := offset.length()
	if reach > 1.0:
		return Pixels.CLEAR
	if reach > 0.42 and reach < 0.6:
		return BRASS.darkened(0.35)
	return Pixels.rounded(BRASS.lightened(0.1) if reach < 0.25 else BRASS, offset)


func _paint_cone(x: int, y: int) -> Color:
	var offset := Vector2(x - 3.0, y - 6.5) / Vector2(3.6, 6.4)
	if y < 1:
		return BRASS.darkened(0.2) if x == 3 else Pixels.CLEAR
	return Pixels.shingle(Color("#6b4a2f"), x, y, 3, 3) if offset.length() < 1.0 else Pixels.CLEAR


func _paint_card(x: int, y: int) -> Color:
	if Vector2(x - 30.5, y - 2.5).length() < 2.0:
		return BRASS.lightened(0.1)
	if y < 12:
		return Pixels.grainy(ROOF.lightened(0.05), x, y, 0.12)
	if y == 13 and x % 4 < 2:
		return ROOF.darkened(0.2)
	var paper := Pixels.grainy(PAPER, x, y, 0.06)
	return paper.darkened(0.08) if y > 52 or x > 57 else paper


func _paint_bird(x: int, y: int, body: Color, shade: Color, mood: String) -> Color:
	var at := Vector2(x + 0.5, y + 0.5)
	if y >= 14:
		return FOOT if x in [5, 6, 9, 10] else Pixels.CLEAR
	var ball := (at - Vector2(8.0, 8.0)) / Vector2(6.6, 6.2)
	if ball.length() > 1.0:
		if mood == "owl":
			return shade if y <= 3 and (x in [3, 4] or x in [11, 12]) else Pixels.CLEAR
		if mood == "dizzy":
			return Color("#d9727d") if y <= 2 and x >= 6 and x <= 8 else Pixels.CLEAR
		return shade if y <= 2 and x in [7, 8] else Pixels.CLEAR
	var eye_row := y == 6 or y == 7
	match mood:
		"owl":
			for eye_x: float in [5.5, 10.5]:
				var ring := (at - Vector2(eye_x, 6.5)).length()
				if ring < 2.4:
					return DARK if ring < 1.0 else PAPER
		"dizzy":
			# Crossed-out eyes.
			var local := x - 4 if x < 8 else x - 9
			if y >= 5 and y <= 7 and local >= 0 and local <= 2 and (local + y) % 2 == 1:
				return DARK
		_:
			if eye_row and x in [5, 10]:
				return DARK
	if x in [7, 8] and y >= 8 and y <= (11 if mood == "sing" else 9):
		return Color("#5a2330") if mood == "sing" and y in [9, 10] else FOOT
	if absf(at.x - 8.0) > 4.7 and at.y > 7.0:
		return Pixels.grainy(shade, x, y, 0.12)
	if ((at - Vector2(8.0, 11.0)) / Vector2(3.4, 2.6)).length() < 1.0:
		return body.lightened(0.28)
	return Pixels.rounded(body, ball)


func _paint_decoy(x: int, y: int) -> Color:
	# Everything leans: this house was nailed together in a hurry.
	var at := Vector2(x + 0.5 - (y - 23.0) * 0.09, y + 0.5)
	var plum := Color("#6d5b7c")
	if at.y < 14.0:
		if absf(at.x - 18.0) > 18.0 * at.y / 14.0:
			return Pixels.CLEAR
		var patched := at.x > 19.0 and at.x < 28.0 and at.y > 6.0 and at.y < 12.0
		return Pixels.shingle(Color("#6f7a52") if patched else Color("#5a4c6e"), x, y, 5, 3)
	if at.y > 42.0:
		return Pixels.wood(plum.darkened(0.4), x, y, 5, false) if at.x > 2.0 and at.x < 34.0 and at.y < 45.5 else Pixels.CLEAR
	if at.x < 4.0 or at.x > 32.0:
		return Pixels.CLEAR
	var hole := at - Vector2(18.0, 25.0)
	if hole.length() < 7.6:
		return Pixels.rounded(BRASS.darkened(0.1), hole / 7.6) if hole.length() > 6.2 else RECESS.lightened(0.06 * (at.y - 18.0) / 7.0)
	if at.y > 33.5 and at.y < 36.0 and absf(at.x - 18.0) < 2.5:
		return TRIM
	if at.y < 16.5:
		return plum.darkened(0.42)
	# One board is a different wood, held by two fat nails.
	if at.y > 36.5 and at.y < 41.0:
		return DARK.lightened(0.25) if (x == 7 or x == 28) and y == 38 else Pixels.wood(Color("#8d7a6a"), x, y, 9, true)
	return Pixels.wood(plum, x, y, 6, false)
