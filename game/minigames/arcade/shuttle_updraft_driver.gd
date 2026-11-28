extends "res://game/minigames/arcade/arcade_driver.gd"
## 羽球上升流: on the kite terrace a shuttlecock floats down on the updraft.
## Run left and right with the racket held over your head: a shuttle that drops
## onto the strings is lobbed straight back up by itself. Keep it off the deck
## as long as you can; every hit in an unbroken rally pays more. Gusts of wind
## blow the shuttles about (the windsock shows which way first): a lift makes
## them hang, a side gust carries them off, a downdraft drops them fast. Later a
## second shuttle joins in. A shuttle you miss plunks into your hair and stays
## there, a crooked feather hat that grows with every miss.
## Rules only: the picture lives in shuttle_updraft_view.gd.
##
## Positions run from 0 (left rail) to 1 (right rail); heights from 0 (the deck)
## to 1 (the top of the sky).

const View = preload("res://game/minigames/arcade/shuttle_updraft_view.gd")
const LEFT_WALL := 0.03
const RIGHT_WALL := 0.97
const RACKET_Y := 0.44
## Half the width of the racket head, and the middle part that hits a clean shot.
const RACKET_HALF := 0.07
const SWEET_HALF := 0.03
const SPEED := 1.0
## Pull of gravity and the fastest a shuttle falls, at the start and at the end of play.
const GRAVITY_FIRST := 0.55
const GRAVITY_LAST := 0.95
const FALL_FIRST := 0.42
const FALL_LAST := 0.68
## Height every lob climbs to.
const APEX := 0.9
const SIDE_KICK := 0.32
const HIT_POINTS := 10
const SWEET_POINTS := 5
## A rally adds this much per two hits, up to the cap.
const RALLY_STEP := 2
const RALLY_CAP := 16
## Seconds a gust is shown on the windsock before it blows, and how long it blows.
const WARN := 0.7
const GUST_SECONDS := 1.4
const GUST_GAP_FIRST := 3.6
const GUST_GAP_LAST := 1.9
const LIFT := 0.5
const SIDE := 0.34
const DOWN := 0.75
const DOWN_HEAT := 0.35
const TWIN_HEAT := 0.5
const SERVE_SECONDS := 1.1
const HAT_FLIGHT := 0.35
const MAX_HAT := 6

## The racket's centre, 0..1.
var hero_x := 0.5
## -1 running left, 1 right, 0 standing.
var facing := 0
## Shuttles in the air: {id, x, y, vx, vy, state ("air", "hat"), at, from (Vector2), tilt}.
var shuttles: Array[Dictionary] = []
## The gust on its way or blowing: {kind ("lift", "side", "down"), side (-1/1), warn_at, start, end}.
var gust: Dictionary = {}
var hats := 0
var hat_at := -99.0
var rally := 0
var best_rally := 0
var hits := 0
var sweets := 0
var misses := 0
var swing_at := -99.0
var swing_sweet := false

var _serial := 0
var _serves: Array[float] = []
var _gust_due := 0.0
var _twin := false
var _demo := false


func _init() -> void:
	verb = "左右跑，用球拍接住羽球，別讓它落地！"
	hint = [["← →", "移動球拍"]]
	round_seconds = 45.0
	thresholds = [180, 420, 540]
	verdicts = [
		"羽球決定在你頭上築巢。",
		"銅牌！羽球大多還在天上。",
		"銀牌！風箏都停下來看你打球。",
		"金牌！上升氣流聘你當專屬球僮。",
	]
	variants = [
		{"id": "breeze", "label": "午後微風"},
		{"id": "gusty", "label": "陣風亂吹", "gusts": 1.35},
		{"id": "twin", "label": "雙羽球練習", "twin": 0.15},
	]
	score_label = "接球得分"
	view_script = View


func _begin_round(_chosen: Dictionary) -> void:
	hero_x = 0.5
	facing = 0
	shuttles.clear()
	gust = {}
	hats = 0
	hat_at = -99.0
	rally = 0
	best_rally = 0
	hits = 0
	sweets = 0
	misses = 0
	swing_at = -99.0
	_serial = 0
	_serves.clear()
	_twin = false
	_demo = true
	# The countdown drops one shuttle a little off to the side and lobs it once.
	_launch(0.62, 0.78, 0.0, -0.05)


func _warm_up(delta: float) -> void:
	if not shuttles.is_empty():
		var target := float(shuttles[0].x)
		var step := SPEED * 0.7 * delta
		facing = int(signf(target - hero_x)) if absf(target - hero_x) > step else 0
		hero_x = move_toward(hero_x, target, step)
	_fly(delta)


func _go() -> void:
	_demo = false
	shuttles.clear()
	hats = 0
	hat_at = -99.0
	rally = 0
	hero_x = 0.5
	_serves = [clock + 0.2]
	_gust_due = clock + 2.2
	_twin = false


func _tick(delta: float) -> void:
	var push := 0.0
	if _held.values().has(&"left"):
		push -= 1.0
	if _held.values().has(&"right"):
		push += 1.0
	facing = int(push)
	hero_x = clampf(hero_x + push * SPEED * delta, LEFT_WALL + 0.02, RIGHT_WALL - 0.02)
	# Later in play a second shuttle joins in.
	if not _twin and heat() >= float(variant.get("twin", TWIN_HEAT)):
		_twin = true
		_serves.append(clock + 0.3)
	var still: Array[float] = []
	for due in _serves:
		if clock >= due:
			_serve()
		else:
			still.append(due)
	_serves = still
	_weather()
	_fly(delta)


func _snapshot(into: Dictionary) -> void:
	into.hero_x = hero_x
	into.facing = facing
	into.racket_y = RACKET_Y
	into.racket_half = racket_half()
	into.sweet_half = SWEET_HALF
	into.shuttles = shuttles
	into.gust = gust
	into.wind = wind()
	into.lift = lift()
	into.hats = hats
	into.hat_at = hat_at
	into.rally = rally
	into.swing_at = swing_at
	into.swing_sweet = swing_sweet
	into.hat_flight = HAT_FLIGHT


## The racket head is a little wider with assist.
func racket_half() -> float:
	return RACKET_HALF * (1.3 if assisted else 1.0)


## Sideways push of the wind now (negative blows left).
func wind() -> float:
	if _blowing() and str(gust.kind) == "side":
		return SIDE * float(gust.side) * _gust_scale()
	return 0.0


## Upward push of the air now (negative is a downdraft).
func lift() -> float:
	if not _blowing():
		return 0.0
	match str(gust.kind):
		"lift":
			return LIFT * _gust_scale()
		"down":
			return -DOWN * _gust_scale()
	return 0.0


func gravity() -> float:
	return lerpf(GRAVITY_FIRST, GRAVITY_LAST, heat())


func fall_limit() -> float:
	return pace(lerpf(FALL_FIRST, FALL_LAST, heat()))


func _gust_scale() -> float:
	return float(variant.get("gusts", 1.0))


func _blowing() -> bool:
	return not gust.is_empty() and clock >= float(gust.start) and clock < float(gust.end)


## Gusts come one after another; each shows on the windsock before it blows.
func _weather() -> void:
	if not gust.is_empty() and clock >= float(gust.end):
		gust = {}
	if not gust.is_empty() or clock < _gust_due:
		return
	var kinds := ["lift", "side", "side"]
	if heat() >= DOWN_HEAT:
		kinds.append("down")
	var kind: String = kinds[rng.randi() % kinds.size()]
	gust = {"kind": kind, "side": -1 if rng.randf() < 0.5 else 1, "warn_at": clock, "start": clock + WARN, "end": clock + WARN + GUST_SECONDS}
	var gap := lerpf(GUST_GAP_FIRST, GUST_GAP_LAST, heat()) / _gust_scale()
	_gust_due = float(gust.end) + gap * rng.randf_range(0.7, 1.2)


## A new shuttle floats down from high up.
func _serve() -> void:
	var x := rng.randf_range(0.15, 0.85)
	# Never right on top of the other shuttle.
	for other in shuttles:
		if str(other.state) == "air" and absf(float(other.x) - x) < 0.2:
			x = fposmod(x + 0.45, 0.7) + 0.15
	_launch(x, 1.02, rng.randf_range(-0.08, 0.08), -0.08)


func _launch(x: float, y: float, vx: float, vy: float) -> void:
	_serial += 1
	shuttles.append({"id": _serial, "x": x, "y": y, "vx": vx, "vy": vy, "state": "air", "at": -99.0, "from": Vector2.ZERO})


func _fly(delta: float) -> void:
	var kept: Array[Dictionary] = []
	for shuttle in shuttles:
		if str(shuttle.state) == "hat":
			# It sticks on the hat until it has finished flying onto the head.
			if clock - float(shuttle.at) < HAT_FLIGHT + 0.05:
				kept.append(shuttle)
			continue
		var before := float(shuttle.y)
		var vy := float(shuttle.vy) + (lift() - gravity()) * delta
		vy = maxf(vy, -fall_limit() * (1.6 if lift() < 0.0 else 1.0))
		var vx := float(shuttle.vx)
		vx += (wind() - vx) * minf(1.0, 2.2 * delta)
		var x := float(shuttle.x) + vx * delta
		if x < LEFT_WALL:
			x = LEFT_WALL + (LEFT_WALL - x)
			vx = absf(vx) * 0.6
		elif x > RIGHT_WALL:
			x = RIGHT_WALL - (x - RIGHT_WALL)
			vx = -absf(vx) * 0.6
		var y := minf(float(shuttle.y) + vy * delta, 1.05)
		shuttle.x = x
		shuttle.y = y
		shuttle.vx = vx
		shuttle.vy = vy
		if vy < 0.0 and before >= RACKET_Y and y < RACKET_Y and absf(x - hero_x) <= racket_half():
			_hit(shuttle)
		elif y <= 0.0:
			_miss(shuttle)
		kept.append(shuttle)
	shuttles.assign(kept)


func _hit(shuttle: Dictionary) -> void:
	var off := (float(shuttle.x) - hero_x) / racket_half()
	var sweet := absf(float(shuttle.x) - hero_x) <= SWEET_HALF
	shuttle.y = RACKET_Y
	shuttle.vy = sqrt(2.0 * gravity() * (APEX - RACKET_Y))
	# Off the edge of the strings it flies off sideways.
	shuttle.vx = off * SIDE_KICK + rng.randf_range(-0.04, 0.04)
	swing_at = clock
	swing_sweet = sweet
	sound(76 if sweet else 72)
	# A racket nobody has moved still bounces the shuttle, but pays nothing.
	if _demo or not touched:
		return
	hits += 1
	rally += 1
	best_rally = maxi(best_rally, rally)
	var points := HIT_POINTS + mini(rally / 2 * RALLY_STEP, RALLY_CAP)
	if sweet:
		sweets += 1
		points += SWEET_POINTS
	var word := "好球！" if sweet else ""
	if rally > 0 and rally % 10 == 0:
		word = "連續 %d 球！" % rally
	add_score(points, word)


## A missed shuttle hops onto the traveller's head and stays there.
func _miss(shuttle: Dictionary) -> void:
	shuttle.state = "hat"
	shuttle.at = clock
	shuttle.from = Vector2(float(shuttle.x), 0.0)
	hats = mini(hats + 1, MAX_HAT)
	hat_at = clock
	sound(45)
	if _demo:
		return
	misses += 1
	rally = 0
	_serves.append(clock + SERVE_SECONDS)
	# The first feather hat of a round is a free look.
	funny_fail("噗！", misses > 1)
