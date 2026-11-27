extends "res://game/minigames/arcade/arcade_driver.gd"
## 露珠牽橋: one dewdrop sits on a big greenhouse leaf. Hold ← or → to tip the
## leaf and roll it. Leaf tips above drip little droplets onto the leaf; roll
## over one and the dewdrop drinks it and grows. A big drop glides further and
## is harder to stop. Roll it off the leaf tip into the flower bud to bank it:
## the bigger the drop, the more it pays. A caterpillar is chewing wormholes in
## the leaf and they widen as the round goes on; a small drop drops straight
## through, a big one stretches across like a little bridge. Off the stem end
## or through a hole, the drop lands on the traveller, who is always shuffling
## about underneath watching it, and their hair goes flat.
## Rules only: the picture lives in dew_bridge_view.gd.
##
## Positions run from 0 (the stem end, left) to 1 (the leaf tip, right).

const View = preload("res://game/minigames/arcade/dew_bridge_view.gd")
const MAX_TILT := 0.34
## Radians per second the leaf tips toward a held side, or back to flat.
const TILT_RATE := 1.5
## Leaf widths per second squared at full tip, per unit of sin(tilt).
const GRAVITY := 2.2
## The last stretch of the leaf at either end droops and pulls the drop outward.
const DROOP_ZONE := 0.1
const DROOP := 0.7
## Velocity damping per second for the seed drop and for a full one.
const DAMP_SEED := 2.6
const DAMP_FULL := 0.9
const SEED_SIZE := 1.0
const FULL_SIZE := 3.0
## Size one droplet adds (a variant doubles it).
const SIP := 0.25
## Drop radius in leaf widths per unit of size.
const RADIUS := 0.02
const DROPLET_RADIUS := 0.014
const START_X := 0.4
## Where a new seed drop may appear, best first.
const SEED_SPOTS: Array[float] = [0.4, 0.46, 0.5, 0.25, 0.67, 0.2]
## Where the leaf tips above drip, and how long a droplet takes to fall.
const DRIP_TIPS: Array[float] = [0.22, 0.47, 0.68, 0.86]
const DRIP_FALL := 0.45
const DRIP_FIRST := 1.5
const DRIP_LAST := 0.75
const MAX_DROPLETS := 3
## Wormhole widths at the start and the end of play; the caterpillar chews a
## third hole under the drop halfway through.
const HOLE_SLOTS: Array[float] = [0.33, 0.58, 0.77]
const HOLE_FIRST := 0.035
const HOLE_LAST := 0.105
const THIRD_HOLE_HEAT := 0.5
## A drop that has barely moved for this long counts as dawdling.
const DAWDLE_SECONDS := 1.5
const SIP_POINTS := 10
## The bud pays this much per unit of size above a seed drop.
const POUR_POINTS := 60
const FULL_BONUS := 60
const SPLASH_SECONDS := 1.6
const POUR_SECONDS := 1.1
const HERO_SPEED := 0.45
## Gust (breeze variant): pushes toward the stem every few seconds.
const GUST := 0.6
## Assist: a little more grip, and the drop spans holes as if it were this much bigger.
const ASSIST_GRIP := 1.25
const ASSIST_SPAN := 1.3

var tilt := 0.0
var drop_x := START_X
var drop_v := 0.0
var size := SEED_SIZE
## Droplets the current drop has drunk.
var sips := 0
## Droplets dripping or sitting on the leaf: {x, at} (it lands at at + DRIP_FALL).
var droplets: Array[Dictionary] = []
## Wormholes: {x, chewed_at}; their width comes from hole_width().
var holes: Array[Dictionary] = []
## The last lost drop: {x, at, size, through} with through "stem" or "hole".
var splash: Dictionary = {}
## The last banked drop: {at, size, sips}.
var pour: Dictionary = {}
var hero_x := START_X
var pours := 0
var splashes := 0
var drunk := 0
var best_sips := 0

var _left := 0
var _right := 0
var _next_drip := 0.0
var _demo := false
var _steered := false
var _chewed := false
var _still_for := 0.0


func _init() -> void:
	verb = "傾斜葉子，讓露珠吃水長大，送進花苞！"
	hint = [["← →", "傾斜葉子"]]
	round_seconds = 45.0
	thresholds = [200, 420, 540]
	verdicts = [
		"花苞說它今天自己喝自來水。",
		"銅牌！花苞喝到幾口，打了個嗝。",
		"銀牌！一顆顆露珠滾得剛剛好。",
		"金牌！整排花苞為你開成拱門。",
	]
	variants = [
		{"id": "standard", "label": "清晨露水"},
		{"id": "breeze", "label": "穿堂風", "gust": true},
		{"id": "heavy", "label": "大顆水滴", "sip": 2.0, "drip": 1.8},
	]
	score_label = "澆花得分"
	view_script = View


func _begin_round(_chosen: Dictionary) -> void:
	_steered = false
	tilt = 0.0
	droplets.clear()
	splash = {}
	pour = {}
	pours = 0
	splashes = 0
	drunk = 0
	best_sips = 0
	_left = 0
	_right = 0
	_new_drop()
	hero_x = START_X
	holes.clear()
	_chewed = false
	# Two of the three gaps between the drip spots start with a wormhole; the
	# caterpillar chews a third one near the stem halfway through.
	var skip := rng.randi() % HOLE_SLOTS.size()
	for slot in HOLE_SLOTS.size():
		if slot != skip:
			holes.append({"x": HOLE_SLOTS[slot], "chewed_at": -99.0})
	_demo = true
	# The countdown demo: one droplet drips just right of the drop.
	droplets.append({"x": 0.47, "at": 0.3})
	_next_drip = 99.0


## The countdown shows the idea: the leaf tips itself, the drop rolls over the
## droplet and drinks it.
func _warm_up(delta: float) -> void:
	var waiting := not droplets.is_empty()
	_steer(delta, 1 if waiting and clock > 0.8 else 0)
	_roll(delta)
	_walk_hero(delta)


func _go() -> void:
	# Play starts on a level leaf with a still seed drop, away from every edge
	# and hole, so the first move is always the player's.
	_demo = false
	tilt = 0.0
	droplets.clear()
	splash = {}
	pour = {}
	_new_drop()
	_next_drip = 0.6


func _tick(delta: float) -> void:
	_steer(delta, _right - _left if _right != _left else 0)
	if heat() >= THIRD_HOLE_HEAT and not _chewed and drop_x >= 0.0 and not busy():
		# Halfway the caterpillar chews a new hole by the stem, or, if the
		# dewdrop has been dawdling, right under it: a small drop left sitting
		# still drops through.
		_chewed = true
		var at := clampf(drop_x, 0.15, 0.85) if _still_for >= DAWDLE_SECONDS else 0.12 + 0.03 * rng.randf()
		holes.append({"x": at, "chewed_at": clock})
	_drip()
	_roll(delta)
	_walk_hero(delta)


func _press(button: StringName) -> void:
	if button == &"left" or button == &"right":
		_steered = true
	if button == &"left":
		_left += 1
	elif button == &"right":
		_right += 1


func _release(button: StringName) -> void:
	if button == &"left":
		_left = maxi(0, _left - 1)
	elif button == &"right":
		_right = maxi(0, _right - 1)


## No input, no points: until the player has steered this round, nothing that
## happens on its own (a gust, a gap sliding over the tip) scores.
func add_score(points: int, word := "") -> void:
	if _steered:
		super(points, word)


func _round_over() -> void:
	_left = 0
	_right = 0


func _snapshot(into: Dictionary) -> void:
	into.tilt = tilt
	into.max_tilt = MAX_TILT
	into.drop_x = drop_x
	into.drop_v = drop_v
	into.drop_radius = radius()
	into.size = size
	into.full_size = FULL_SIZE
	into.sips = sips
	into.droplets = droplets
	into.droplet_radius = DROPLET_RADIUS
	into.drip_fall = DRIP_FALL
	into.drip_tips = DRIP_TIPS
	var widths: Array[Dictionary] = []
	for hole in holes:
		widths.append({"x": hole.x, "width": hole_width(), "chewed_at": hole.chewed_at})
	into.holes = widths
	into.splash = splash
	into.pour = pour
	into.splash_seconds = SPLASH_SECONDS
	into.pour_seconds = POUR_SECONDS
	into.hero_x = hero_x
	into.gusting = gust() != 0.0
	into.pours = pours


func radius() -> float:
	return RADIUS * size


## How wide a hole the drop can stretch across.
func span() -> float:
	return radius() * 2.0 * (ASSIST_SPAN if assisted else 1.0)


func hole_width() -> float:
	return lerpf(HOLE_FIRST, HOLE_LAST, heat())


func damping() -> float:
	var full := (size - SEED_SIZE) / (FULL_SIZE - SEED_SIZE)
	var damp := lerpf(DAMP_SEED, DAMP_FULL, full)
	# Assist gives the leaf a little more grip, so the drop stops sooner.
	return damp * ASSIST_GRIP if assisted else damp


## Extra reach for drinking a droplet; wider with assist.
func reach() -> float:
	return (radius() + DROPLET_RADIUS) * (ASSIST_WINDOW if assisted else 1.0)


## A push toward the stem while the breeze blows (two seconds in every five).
func gust() -> float:
	if not bool(variant.get("gust", false)) or _demo or stage != "play":
		return 0.0
	return -GUST if fposmod(play_time, 5.0) >= 3.0 else 0.0


func busy() -> bool:
	return (not splash.is_empty() and clock - float(splash.at) < SPLASH_SECONDS) or (not pour.is_empty() and clock - float(pour.at) < POUR_SECONDS)


func landed(droplet: Dictionary) -> bool:
	return clock >= float(droplet.at) + DRIP_FALL


func _steer(delta: float, side: int) -> void:
	tilt = move_toward(tilt, MAX_TILT * side, TILT_RATE * delta)


func _roll(delta: float) -> void:
	if busy():
		return
	if drop_x < 0.0:
		_new_drop()
	var accel := GRAVITY * sin(tilt) + gust()
	if drop_x < DROOP_ZONE:
		accel -= DROOP * (1.0 - drop_x / DROOP_ZONE)
	elif drop_x > 1.0 - DROOP_ZONE:
		accel += DROOP * (1.0 - (1.0 - drop_x) / DROOP_ZONE)
	drop_v += accel * delta
	drop_v *= exp(-damping() * delta)
	drop_x += drop_v * delta
	_still_for = _still_for + delta if absf(drop_v) < 0.02 else 0.0
	for droplet: Dictionary in droplets.duplicate():
		if landed(droplet) and absf(float(droplet.x) - drop_x) <= reach():
			droplets.erase(droplet)
			_sip()
	if drop_x > 1.0:
		_pour()
		return
	if drop_x < 0.0:
		_lose("stem")
		return
	var width := hole_width()
	for hole in holes:
		if absf(drop_x - float(hole.x)) < width * 0.5 and span() < width:
			drop_x = float(hole.x)
			_lose("hole")
			return


func _sip() -> void:
	size = minf(FULL_SIZE, size + SIP * float(variant.get("sip", 1.0)))
	sips += 1
	sound(72 + mini(sips, 10))
	if _demo:
		return
	drunk += 1
	best_sips = maxi(best_sips, sips)
	add_score(SIP_POINTS)


func _pour() -> void:
	var full := size >= FULL_SIZE
	pour = {"at": clock, "size": size, "sips": sips}
	sound(79)
	sound(84 if full else 81)
	if not _demo:
		pours += 1
		var points := roundi(POUR_POINTS * (size - SEED_SIZE)) + (FULL_BONUS if full else 0)
		add_score(points, ("滿開！+%d" if full else "澆花！+%d") % points)
	drop_x = -1.0


func _lose(through: String) -> void:
	splash = {"x": clamp(drop_x, 0.0, 1.0), "at": clock, "size": size, "through": through}
	drop_x = -1.0
	drop_v = 0.0
	sound(50)
	sound(45)
	if _demo:
		return
	splashes += 1
	# The first splash of a round is a free look at the wet hair.
	funny_fail("噗啾！", splashes > 1)


## A fresh seed drop drips onto the middle of the leaf, in a gap that stays
## clear of every hole even at its widest.
func _new_drop() -> void:
	drop_x = START_X
	for spot in SEED_SPOTS:
		var clear := true
		for hole in holes:
			clear = clear and absf(spot - float(hole.x)) > HOLE_LAST * 0.5 + RADIUS * SEED_SIZE + 0.02
		if clear:
			drop_x = spot
			break
	drop_v = 0.0
	size = SEED_SIZE
	sips = 0


func _drip() -> void:
	if play_time < _next_drip:
		return
	_next_drip = play_time + lerpf(DRIP_FIRST, DRIP_LAST, heat()) * float(variant.get("drip", 1.0))
	if droplets.size() >= MAX_DROPLETS:
		return
	var open: Array[float] = []
	for tip in DRIP_TIPS:
		var clear := absf(tip - drop_x) > 0.06
		for hole in holes:
			clear = clear and absf(tip - float(hole.x)) > hole_width()
		for droplet in droplets:
			clear = clear and absf(tip - float(droplet.x)) > 0.05
		if clear:
			open.append(tip)
	if open.is_empty():
		return
	droplets.append({"x": open[rng.randi() % open.size()], "at": clock})
	sound(76)


## The traveller shuffles about under the leaf to keep an eye on the drop.
func _walk_hero(delta: float) -> void:
	if not splash.is_empty() and clock - float(splash.at) < SPLASH_SECONDS:
		return
	var target := clampf(drop_x if drop_x >= 0.0 else START_X, 0.04, 0.9)
	hero_x = move_toward(hero_x, target, HERO_SPEED * delta)
