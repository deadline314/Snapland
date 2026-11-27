extends "res://game/minigames/arcade/arcade_view.gd"
## Picture for 軌道換軌: a grooved wooden toy-train track runs across the
## workshop bench to a three-way set of points with a signal post, then curves
## up, straight on and down to three little stations, each with its colour and
## its roof emblem (triangle, circle, square). Painted tin trains puff along it;
## home trains roll in under the station roof, a wrong one leaps off the end
## into the big toy box with a trail of tooting stars. The island traveller
## (arcade_hero) throws the points. Baked pixel art in the backdrop's dusk palette.

const Hero = preload("res://game/minigames/arcade/arcade_hero.gd")
const YARD_ART := "res://assets/world/toy-clockwork-yard.webp"
const BENCH_TOP := 300.0
const MAIN_Y := 440.0
const MAIN_LEFT := -30.0
const POINTS_X := 600.0
const DOOR_X := 1000.0
const BRANCH_Y: Array[float] = [272.0, 440.0, 608.0]
const STATION := Vector2i(34, 26)
const ENGINE := Vector2i(17, 13)
const CAR := Vector2i(12, 10)
const BOX := Vector2i(32, 26)
const BOX_AT := Vector2(1206, 578)
const HERO_FEET := Vector2(430, 664)
const HERO_SCALE := 3.0
const COLOURS: Array[Color] = [Color("#c0503f"), Color("#4f79a8"), Color("#e0b04a")]
const NAMES: Array[String] = ["紅", "藍", "黃"]
const WOOD := Color("#7a5238")
const PINE := Color("#d2a46a")
const IRON := Color("#4a4e57")
const STEEL := Color("#c3c8cf")
const DARK := Color("#2b2440")
const LABEL := Color("#efe0bc")
const ARROWS: Array[String] = ["↑", "→", "↓"]
const DUSK := Color(1.0, 0.93, 0.86)

var _has_art := false
var _engines: Array[ImageTexture] = []
var _cars: Array[ImageTexture] = []
var _stations: Array[ImageTexture] = []
var _box_back: ImageTexture
var _box_front: ImageTexture


func _init() -> void:
	super()
	word_anchor = Vector2(330, 300)


func _ready() -> void:
	_has_art = use_backdrop_art(YARD_ART, Rect2(60, 0, 1157, 651), Color(0.58, 0.52, 0.58))
	for colour in COLOURS.size():
		_engines.append(Pixels.bake("switch-engine|%d" % colour, ENGINE, _paint_engine.bind(colour)))
		_cars.append(Pixels.bake("switch-car|%d" % colour, CAR, _paint_car.bind(colour)))
		_stations.append(Pixels.bake("switch-station|%d" % colour, STATION, _paint_station.bind(colour)))
	_box_back = Pixels.bake("switch-box-back", BOX, _paint_box.bind(true))
	_box_front = Pixels.bake("switch-box-front", BOX, _paint_box.bind(false))


func _draw_backdrop() -> void:
	if not _has_art:
		draw_rect(Rect2(Vector2.ZERO, DESIGN), Color("#3a2c2a"))
	bench(BENCH_TOP, WOOD)
	vignette()


func _draw_scene() -> void:
	if not state.has("trains"):
		return
	_draw_track()
	_draw_box_back()
	for train: Dictionary in state.trains:
		if str(train.state) != "crash":
			_draw_train(train)
	for branch in BRANCH_Y.size():
		_draw_station(branch)
	_draw_points()
	for train: Dictionary in state.trains:
		if str(train.state) == "crash":
			_draw_crash(train)
	_draw_box_front()
	_draw_hero()
	_draw_streak()


# --- The line -----------------------------------------------------------------

## Screen point and heading of distance `s` along the line, on `branch` past the points.
func _along(s: float, branch: int) -> Array:
	var junction := float(state.get("junction", 0.55))
	if s <= junction or branch < 0:
		return [Vector2(lerpf(MAIN_LEFT, POINTS_X, s / junction), MAIN_Y), 0.0]
	var t := clampf((s - junction) / float(state.get("branch", 0.45)), 0.0, 1.0)
	var y := BRANCH_Y[branch]
	var p := [Vector2(POINTS_X, MAIN_Y), Vector2(POINTS_X + 150.0, MAIN_Y), Vector2(DOOR_X - 180.0, y), Vector2(DOOR_X, y)]
	var u := 1.0 - t
	var at: Vector2 = p[0] * u * u * u + p[1] * 3.0 * u * u * t + p[2] * 3.0 * u * t * t + p[3] * t * t * t
	var slope: Vector2 = (p[1] - p[0]) * 3.0 * u * u + (p[2] - p[1]) * 6.0 * u * t + (p[3] - p[2]) * 3.0 * t * t
	return [at, slope.angle()]


func _branch_points(branch: int, from := 0.0, to := 1.0) -> PackedVector2Array:
	var junction := float(state.get("junction", 0.55))
	var length := float(state.get("branch", 0.45))
	var points := PackedVector2Array()
	for step in 25:
		var t := lerpf(from, to, step / 24.0)
		points.append(_along(junction + t * length, branch)[0])
	return points


func _rails(points: PackedVector2Array, bright := false) -> void:
	# A grooved beech track: shadow, body, lit top edge and two grooves.
	var shade := 0.0 if bright else 0.12
	draw_polyline(points, Color(SPRITE_SHADE, 0.35), 44.0)
	draw_polyline(points, PINE.darkened(0.45 + shade), 38.0)
	draw_polyline(points, PINE.darkened(shade), 32.0)
	var up := PackedVector2Array()
	var down := PackedVector2Array()
	var top := PackedVector2Array()
	for index in points.size():
		var ahead := points[mini(index + 1, points.size() - 1)] - points[maxi(index - 1, 0)]
		var side := ahead.normalized().orthogonal()
		up.append(points[index] + side * 8.0)
		down.append(points[index] - side * 8.0)
		top.append(points[index] + side * 14.0)
	draw_polyline(top, PINE.lightened(0.18 if bright else 0.05), 3.0)
	draw_polyline(up, PINE.darkened(0.55), 4.0)
	draw_polyline(down, PINE.darkened(0.55), 4.0)


func _draw_track() -> void:
	var main := PackedVector2Array()
	for step in 13:
		main.append(Vector2(lerpf(MAIN_LEFT - 40.0, POINTS_X, step / 12.0), MAIN_Y))
	var thrown := int(state.get("points", -1))
	for branch in BRANCH_Y.size():
		if branch != thrown:
			_rails(_branch_points(branch))
	if thrown >= 0:
		_rails(_branch_points(thrown), true)
	_rails(main, true)
	# Joints every so often, like real toy-track pieces.
	for step in 6:
		var x := lerpf(MAIN_LEFT, POINTS_X, step / 6.0) + 60.0
		draw_rect(Rect2(x - 2.0, MAIN_Y - 16.0, 4, 32), PINE.darkened(0.4))


func _draw_points() -> void:
	var thrown := int(state.get("points", -1))
	var since := age(float(state.get("points_at", -99.0)))
	var post := Vector2(POINTS_X - 10.0, MAIN_Y - 40.0)
	if thrown < 0:
		_draw_stop(post, since)
		_draw_branch_keys(thrown, since)
		return
	# A signal post with an arrow arm that swings to the thrown branch.
	draw_rect(Rect2(post + Vector2(-4, -70), Vector2(10, 74)), DARK)
	draw_rect(Rect2(post + Vector2(-2, -70), Vector2(6, 74)), WOOD.lightened(0.15))
	ground_shadow(post + Vector2(8, 6), Vector2(20, 5), 0.4)
	var target: float = [-0.55, 0.0, 0.55][thrown]
	var swing: float = target if reduced_motion else target + 0.25 * exp(-since * 9.0) * sin(since * 30.0)
	var pivot := post + Vector2(0, -64)
	var tip := pivot + Vector2.from_angle(swing) * 74.0
	draw_line(pivot, tip, DARK, 14.0)
	draw_line(pivot, tip, Color("#f1e2bc"), 10.0)
	var head := PackedVector2Array([tip + Vector2.from_angle(swing) * 18.0, tip + Vector2.from_angle(swing + 2.3) * 16.0, tip + Vector2.from_angle(swing - 2.3) * 16.0])
	draw_colored_polygon(head, DARK)
	draw_colored_polygon(PackedVector2Array([head[0] - Vector2.from_angle(swing) * 3.0, head[1].lerp(head[0], 0.15), head[2].lerp(head[0], 0.15)]), COLOURS[0])
	draw_circle(pivot, 8.0, DARK)
	draw_circle(pivot, 6.0, STEEL)
	_draw_branch_keys(thrown, since)


## Points at stop: the post shows a red disc until they are thrown.
func _draw_stop(post: Vector2, since: float) -> void:
	draw_rect(Rect2(post + Vector2(-4, -70), Vector2(10, 74)), DARK)
	draw_rect(Rect2(post + Vector2(-2, -70), Vector2(6, 74)), WOOD.lightened(0.15))
	ground_shadow(post + Vector2(8, 6), Vector2(20, 5), 0.4)
	var disc := post + Vector2(1, -82)
	var grow := pop_in(since, 0.2)
	draw_circle(disc, 20.0 * grow, DARK)
	draw_circle(disc, 17.0 * grow, COLOURS[0])
	draw_circle(disc + Vector2(-4, -4), 8.0 * grow, COLOURS[0].lightened(0.25))
	label(disc, "停", 18, LABEL, grow)


func _draw_branch_keys(thrown: int, since: float) -> void:
	# The key for each branch sits beside it.
	for branch in BRANCH_Y.size():
		var at: Vector2 = _along(float(state.get("junction", 0.55)) + float(state.get("branch", 0.45)) * 0.42, branch)[0]
		key_cap(at + Vector2(0, -44 if branch < 2 else 44), ARROWS[branch], branch == thrown and since < 0.15, 20)


func _draw_station(branch: int) -> void:
	var stations: Array = state.get("stations", [0, 1, 2])
	var colour := int(stations[branch])
	var door := Vector2(DOOR_X, BRANCH_Y[branch])
	var origin := door + Vector2(-6, -(STATION.y - 4) * TEXEL)
	ground_shadow(door + Vector2(STATION.x * 2.0 + 10.0, 14.0), Vector2(STATION.x * 2.2, 10), 0.4)
	var due := float(state.get("shuffle_due", -99.0))
	var warn := due - now < float(state.get("shuffle_warning", 1.5)) and due > now
	var flip := age(float(state.get("shuffle_at", -99.0)))
	var shake := Vector2.ZERO
	if warn and not reduced_motion:
		shake.x = 3.0 * sin(now * 40.0)
	draw_set_transform(origin + Vector2(STATION.x * 2.0, STATION.y * TEXEL) + shake, 0.0, Vector2(1.0, 1.0) * (squash(flip, 0.2, 0.35)))
	stamp(_stations[colour], Vector2(-STATION.x * 2.0, -STATION.y * TEXEL), TEXEL, DUSK)
	draw_set_transform(Vector2.ZERO)
	label(origin + Vector2(STATION.x * 2.6, 70), NAMES[colour] + "站", 18, DARK, 1.0, 1.0, false)
	if warn:
		label(origin + Vector2(STATION.x * 2.0, -16), "要換了！", 18, LABEL, 1.0 + 0.1 * pulse(3.0))


# --- Trains -------------------------------------------------------------------

func _draw_train(train: Dictionary) -> void:
	var s := float(train.s)
	if str(train.state) == "home":
		# Home trains roll on in under the station roof.
		s += 0.25 * age(float(train.at))
	var branch := int(train.branch)
	var colour := int(train.colour)
	var engine_len := float(state.get("engine", 0.06))
	var car_len := float(state.get("car", 0.045))
	var end := float(state.get("junction", 0.55)) + float(state.get("branch", 0.45))
	for index in range(int(train.cars), -1, -1):
		var centre := s - engine_len * 0.5 if index == 0 else s - engine_len - car_len * (index - 0.5)
		if centre > end + 0.02 or centre < -0.05:
			continue
		var spot: Array = _along(minf(centre, end), branch)
		var at: Vector2 = spot[0]
		if centre > end:
			at += Vector2((centre - end) * 900.0, 0)
		var sprite: ImageTexture = _engines[colour] if index == 0 else _cars[colour]
		var size := Vector2(sprite.get_size() - Vector2(2, 2)) * TEXEL
		var bob := 0.0 if reduced_motion else 1.5 * sin(now * 14.0 + index + float(train.id))
		ground_shadow(at + Vector2(4, 16), Vector2(size.x * 0.5, 6), 0.35)
		draw_set_transform(at + Vector2(0, bob), float(spot[1]), Vector2.ONE)
		stamp(sprite, Vector2(-size.x * 0.5, -size.y + 14.0), TEXEL, DUSK)
		draw_set_transform(Vector2.ZERO)
		if index == 0 and not reduced_motion and str(train.state) == "run":
			# Puffs from the funnel.
			for puff in 2:
				var rise := fposmod(now * 1.6 + puff * 0.5 + float(train.id) * 0.3, 1.0)
				draw_circle(at + Vector2(size.x * 0.25 - rise * 30.0, -size.y + 6.0 - rise * 36.0), 6.0 + rise * 8.0, Color(LABEL, 0.45 * (1.0 - rise)))
		if index == 0 and bool(train.backer) and str(train.get("phase", "")) in ["stop", "back"]:
			label(at + Vector2(0, -size.y - 10.0), "倒車～" if str(train.phase) == "back" else "？", 20, LABEL)
		if index == 0 and bool(train.get("waiting", false)) and str(train.state) == "run":
			label(at + Vector2(0, -size.y - 14.0 - 4.0 * pulse(2.5)), "嘟嘟！", 20, LABEL)


## A wrong train leaps off the end of the line into the toy box, tooting stars.
func _draw_crash(train: Dictionary) -> void:
	var since := age(float(train.at))
	var t := clampf(since / 0.7, 0.0, 1.0)
	var door := Vector2(DOOR_X + STATION.x * TEXEL * 0.6, BRANCH_Y[int(train.branch)] - 10.0)
	var into := BOX_AT + Vector2(0, -60)
	var at := door.lerp(into, t) + Vector2(0, -180.0 * sin(t * PI))
	var spin := 0.0 if reduced_motion else t * TAU * 1.25
	var sprite: ImageTexture = _engines[int(train.colour)]
	var size := Vector2(sprite.get_size() - Vector2(2, 2)) * TEXEL
	if t < 1.0:
		draw_set_transform(at, spin, Vector2.ONE)
		stamp(sprite, -size * 0.5, TEXEL, DUSK)
		draw_set_transform(Vector2.ZERO)
	# A trail of little stars toots out of the funnel.
	for star in 6:
		var back := clampf(t - star * 0.07, 0.0, 1.0)
		if back <= 0.0 or (since > 1.0 and star > 2):
			continue
		var spot := door.lerp(into, back) + Vector2(0, -180.0 * sin(back * PI) - 20.0)
		var twinkle := 1.0 if reduced_motion else 0.7 + 0.3 * sin(now * 20.0 + star)
		_star(spot, 7.0 * twinkle)
	if since > 0.6:
		label(BOX_AT + Vector2(0, -130), "嘟嘟嘟～", 22, LABEL, pop_in(since - 0.6, 0.2))


func _star(at: Vector2, radius: float) -> void:
	draw_rect(Rect2(at - Vector2(radius, radius * 0.35), Vector2(radius * 2.0, radius * 0.7)), DARK)
	draw_rect(Rect2(at - Vector2(radius * 0.35, radius), Vector2(radius * 0.7, radius * 2.0)), DARK)
	draw_rect(Rect2(at - Vector2(radius * 0.7, radius * 0.15), Vector2(radius * 1.4, radius * 0.3)), GOLD)
	draw_rect(Rect2(at - Vector2(radius * 0.15, radius * 0.7), Vector2(radius * 0.3, radius * 1.4)), GOLD)


func _draw_box_back() -> void:
	var at := BOX_AT - Vector2(BOX.x * 0.5, BOX.y) * TEXEL
	ground_shadow(BOX_AT + Vector2(8, 2), Vector2(BOX.x * 2.2, 12), 0.42)
	stamp(_box_back, at, TEXEL, DUSK)


func _draw_box_front() -> void:
	var at := BOX_AT - Vector2(BOX.x * 0.5, BOX.y) * TEXEL
	var landed := 99.0
	for train: Dictionary in state.trains:
		if str(train.state) == "crash":
			landed = minf(landed, age(float(train.at)) - 0.7)
	draw_set_transform(BOX_AT, 0.0, squash(landed, 0.12, 0.3))
	stamp(_box_front, at - BOX_AT, TEXEL, DUSK)
	draw_set_transform(Vector2.ZERO)
	label(BOX_AT + Vector2(0, 26), "玩具箱", 18, LABEL)


func _draw_hero() -> void:
	var thrown := int(state.get("points", 1))
	var since := age(float(state.get("points_at", -99.0)))
	var pose := &"idle"
	if since < 0.3:
		pose = [&"up", &"right", &"idle"][thrown]
	var crashed := 99.0
	for train: Dictionary in state.trains:
		if str(train.state) == "crash":
			crashed = minf(crashed, age(float(train.at)))
	var mood := "shocked" if crashed < 1.2 else ("tongue" if int(state.get("streak", 0)) >= 5 else "plain")
	ground_shadow(HERO_FEET + Vector2(6, 2), Vector2(56, 13), 0.42)
	stamp(Hero.texture(pose, true, mood), HERO_FEET - Vector2(20, 46) * HERO_SCALE, HERO_SCALE, DUSK)


func _draw_streak() -> void:
	var streak := int(state.get("streak", 0))
	if streak >= 2:
		label(Vector2(140, 236), "連續到站 × %d" % streak, 24, GOLD, 1.0 + 0.08 * pulse(2.0))


# --- Texel painters -------------------------------------------------------------

## The emblem for each colour: triangle, circle or square, inside a `size` box.
func _emblem(colour: int, at: Vector2, size: float) -> bool:
	match colour:
		0:
			return at.y >= 0.0 and at.y <= size and absf(at.x) <= at.y * 0.6 + 0.4
		1:
			return Vector2(at.x, at.y - size * 0.5).length() <= size * 0.55
	return absf(at.x) <= size * 0.45 and at.y >= 0.0 and at.y <= size * 0.9


func _paint_engine(x: int, y: int, colour: int) -> Color:
	var paint := COLOURS[colour]
	var at := Vector2(x + 0.5, y + 0.5)
	for wheel: float in [3.5, 8.5, 13.5]:
		var spoke := (at - Vector2(wheel, 11.0)) / 2.0
		if spoke.length() <= 1.0:
			return STEEL if spoke.length() < 0.35 else Pixels.rounded(IRON.lightened(0.1), spoke)
	# A funnel up front, a round boiler, a cab at the back with the emblem.
	if x >= 11 and x < 14 and y < 4:
		return IRON.lightened(0.15) if y > 0 else IRON.lightened(0.35)
	if y >= 4 and y < 10 and x >= 9:
		if x == 16:
			return STEEL
		return Pixels.rounded(paint, Vector2(0, (at.y - 7.0) / 3.0))
	if x < 9 and y >= 1 and y < 10:
		if y < 2:
			return IRON.lightened(0.2)
		if _emblem(colour, Vector2(at.x - 4.5, at.y - 3.5), 4.0):
			return LABEL
		return Pixels.grainy(paint.darkened(0.1), x, y, 0.08)
	if y == 10 and x >= 1:
		return IRON
	return Pixels.CLEAR


func _paint_car(x: int, y: int, colour: int) -> Color:
	var paint := COLOURS[colour]
	var at := Vector2(x + 0.5, y + 0.5)
	for wheel: float in [3.0, 9.0]:
		var spoke := (at - Vector2(wheel, 8.0)) / 1.8
		if spoke.length() <= 1.0:
			return STEEL if spoke.length() < 0.35 else Pixels.rounded(IRON.lightened(0.1), spoke)
	# An open wooden wagon with a couple of toy blocks for cargo.
	if y < 3 and ((x >= 2 and x < 5) or (x >= 6 and x < 10 and y >= 1)):
		return Pixels.wood(COLOURS[(colour + 1 + x / 5) % 3].lerp(PINE, 0.3), x, y, 3)
	if y >= 3 and y < 7 and x >= 0 and x < CAR.x:
		if y == 3:
			return paint.lightened(0.2)
		return Pixels.wood(paint.lerp(PINE, 0.15), x, y, 3, false)
	if y == 7 and x >= 1 and x < CAR.x - 1:
		return IRON
	return Pixels.CLEAR


func _paint_station(x: int, y: int, colour: int) -> Color:
	var paint := COLOURS[colour]
	var at := Vector2(x + 0.5, y + 0.5)
	var middle := STATION.x * 0.5 + 2.0
	# A pitched roof in the station's colour with its emblem in the gable.
	if y < 11:
		var reach := 2.0 + y * 1.55
		if absf(at.x - middle) > reach:
			return Pixels.CLEAR
		if _emblem(colour, Vector2(at.x - middle, at.y - 3.5), 6.0):
			return LABEL
		return Pixels.shingle(paint, x, y, 4, 3)
	if y == 11:
		return paint.darkened(0.45) if x >= 1 else Pixels.CLEAR
	# Walls with a dark arched doorway on the left where the track runs in.
	if y < STATION.y - 3:
		if x < 12:
			var arch := Rect2(1, 13, 10, STATION.y - 16)
			if arch.has_point(at):
				return Color("#1d1420").lightened(0.03 * (at.y - 13))
			return Pixels.wood(PINE.darkened(0.15), x, y, 3)
		if x >= 18 and x < 26 and y >= 14 and y < 19:
			return Color("#ffe7a0") if (x + y) % 5 != 0 else Color("#e8c94a")
		return Pixels.wood(PINE.lightened(0.05), x, y, 4)
	return Pixels.grainy(Color("#b8ab98").darkened(0.08 * (y - STATION.y + 3)), x, y, 0.1)


func _paint_box(x: int, y: int, back: bool) -> Color:
	# A big painted toy box, open, its lid leaning back, toys poking over the rim.
	var at := Vector2(x + 0.5, y + 0.5)
	if back:
		if y < 6:
			return Pixels.wood(COLOURS[1].lerp(PINE, 0.3), x, y, 5) if x >= 3 and x < BOX.x - 3 else Pixels.CLEAR
		if y < 13:
			# A ball, a block and a doll's arm sticking up out of the box.
			if (at - Vector2(9, 10)).length() < 3.2:
				return Pixels.rounded(COLOURS[2], (at - Vector2(9, 10)) / 3.2)
			if x >= 15 and x < 20 and y >= 8:
				return Pixels.wood(COLOURS[0].lerp(PINE, 0.2), x, y, 3)
			if x >= 24 and x < 26 and y >= 7:
				return Color("#ebb894")
			return Color("#2a1d24").lightened(0.03 * (13 - y)) if y >= 11 and x >= 1 and x < BOX.x - 1 else Pixels.CLEAR
		return Pixels.CLEAR
	if y < 12:
		return Pixels.CLEAR
	if y == 12:
		return COLOURS[2].lightened(0.15)
	if y == 13:
		return COLOURS[2].darkened(0.25)
	# A painted star on the front.
	var star := at - Vector2(BOX.x * 0.5, 19.5)
	if absf(star.x) + absf(star.y) < 3.0 or (absf(star.x) < 0.8 and absf(star.y) < 4.5) or (absf(star.y) < 0.8 and absf(star.x) < 4.5):
		return LABEL
	if x < 2 or x >= BOX.x - 2:
		return Pixels.wood(COLOURS[0].lerp(PINE, 0.1).darkened(0.2), x, y, 2)
	return Pixels.wood(COLOURS[0].lerp(PINE, 0.25).darkened(0.05 * (y - 12) / 4.0), x, y - 12, 4, false)
