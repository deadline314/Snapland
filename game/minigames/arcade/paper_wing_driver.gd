extends "res://game/minigames/arcade/arcade_driver.gd"
## 紙翼穿峽: the hero rides a big paper plane down a canyon of rock spires in the
## clouds. Gates of rock come at you out of the haze, each with a gap and a ring
## of wind in it. Hold ← or → to bank and slide across; fly through the gap to
## pay, through the ring at its heart to pay more. Every gate opens somewhere
## other than where you are headed, so you have to steer for every one. Gaps narrow
## as the round goes on, later gates sway side to side, and now and then a side
## gust shoves the plane (the streaks show which way a moment before). Clip the
## rock and the paper crumples into a ball with the hero wrapped inside, which
## tumbles away into the clouds. Rules only: the picture lives in
## paper_wing_view.gd.
##
## Sideways positions are pixels from the screen centre at the plane's distance.

const View = preload("res://game/minigames/arcade/paper_wing_view.gd")
const LIMIT := 430.0
## Half the plane's wingspan, and how much of it may scrape past a gap's edge.
const PLANE_HALF := 46.0
const SCRAPE := 0.6
const SPEED := 560.0
## How quickly the plane reaches its banking speed (per second).
const BANK := 7.0
## Seconds a gate takes to come out of the haze to the plane.
const TRAVEL_EARLY := 2.4
const TRAVEL_LATE := 1.5
const GAP_SECONDS_EARLY := 1.55
const GAP_SECONDS_LATE := 1.0
const WIDTH_EARLY := 330.0
const WIDTH_LATE := 190.0
## Late gates sway side to side by up to this much.
const SWAY := 120.0
const SWAY_HEAT := 0.4
## A gate never opens where the plane is headed: its gap starts at least this far
## off the plane (or the gate before it), and at most REACH further.
const CLEAR_MARGIN := 24.0
const REACH := 180.0
const GUST_WARN := 0.9
const GUST_SECONDS := 1.3
const GUST_PUSH := 230.0
const GUST_HEAT := 0.3
const CRASH_SECONDS := 1.8
const GATE_POINTS := 10
const RING_POINTS := 10
const STREAK_POINTS := 2
const STREAK_CAP := 5

var plane_x := 0.0
var plane_v := 0.0
## "fly" or "crash".
var phase := "fly"
var phase_at := 0.0
## Gates on their way: {serial, z (seconds until they reach the plane), travel, base, sway, omega, offset, width}.
var gates: Array[Dictionary] = []
## The gust on its way or blowing: {side, warn_at, start, end}.
var gust: Dictionary = {}
var streak := 0
var passed := 0
var rings := 0
var crashes := 0
## The last gate the plane met: {at, ok, ring, centre, width}.
var last: Dictionary = {}

var _next_gate := 0.0
var _gust_due := 0.0
var _serial := 0


func _init() -> void:
	verb = "按住 ← → 傾斜機翼，從峽口的風環穿過去！"
	hint = [["← →", "傾斜機翼"]]
	round_seconds = 45.0
	thresholds = [180, 500, 800]
	verdicts = [
		"紙飛機揉成一團，連你一起滾進雲裡。",
		"銅牌！紙翼還算平。",
		"銀牌！峽谷裡的老鷹回頭看了你一眼。",
		"金牌！你和紙飛機已經是同一張紙了。",
	]
	variants = [
		{"id": "standard", "label": "紙翼穿峽", "gusts": 1.0, "sway_from": SWAY_HEAT},
		{"id": "gusty", "label": "側風峽谷", "gusts": 1.9, "sway_from": 0.6},
		{"id": "slalom", "label": "搖擺峽口", "gusts": 0.6, "sway_from": 0.1},
	]
	score_label = "穿峽得分"
	view_script = View


func _begin_round(_chosen: Dictionary) -> void:
	_reset_flight()
	streak = 0
	passed = 0
	rings = 0
	crashes = 0
	# The countdown sends one wide gate a little to the right; the plane banks into it.
	_spawn(150.0)
	gates[0].z = 1.9
	gates[0].travel = 1.9


func _warm_up(delta: float) -> void:
	if not gates.is_empty():
		var aim := _centre(gates[0], clock + float(gates[0].z))
		_glide(signf(aim - plane_x) if absf(aim - plane_x) > 20.0 else 0.0, 0.0, delta)
	_advance_gates(delta, false)


func _go() -> void:
	_reset_flight()
	_next_gate = clock + 0.5
	_gust_due = clock + 6.0 / float(variant.get("gusts", 1.0))


func _tick(delta: float) -> void:
	if phase == "crash":
		if clock - phase_at >= CRASH_SECONDS:
			_reset_flight()
			_next_gate = clock + 0.3
		return
	var steer := 0.0
	if _held.values().has(&"left"):
		steer -= 1.0
	if _held.values().has(&"right"):
		steer += 1.0
	_glide(steer, _gust_push(), delta)
	if clock >= _next_gate:
		_spawn()
		_next_gate = clock + lerpf(GAP_SECONDS_EARLY, GAP_SECONDS_LATE, heat())
	_advance_gates(delta, true)
	_plan_gust()


func _snapshot(into: Dictionary) -> void:
	into.plane_x = plane_x
	into.bank = clampf(plane_v / SPEED, -1.0, 1.0)
	into.phase = phase
	into.phase_at = phase_at
	var shown: Array[Dictionary] = []
	for gate: Dictionary in gates:
		shown.append({"serial": int(gate.serial), "depth": float(gate.z) / float(gate.travel), "centre": _centre(gate, clock), "width": float(gate.width)})
	into.gates = shown
	into.gust = gust.duplicate()
	into.clock = clock
	into.streak = streak
	into.last = last.duplicate()


## Where a gate's gap is centred at time `when`.
func _centre(gate: Dictionary, when: float) -> float:
	return float(gate.base) + float(gate.sway) * sin(when * float(gate.omega) + float(gate.offset))


## Half the gap the plane's centre may be in, wider with assist.
func clearance(width: float) -> float:
	return window(width * 0.5 - PLANE_HALF * SCRAPE)


func ring_radius(width: float) -> float:
	return width * 0.18


func _glide(steer: float, push: float, delta: float) -> void:
	plane_v = lerpf(plane_v, steer * SPEED, minf(1.0, BANK * delta))
	plane_x = clampf(plane_x + (plane_v + push) * delta, -LIMIT, LIMIT)
	if absf(plane_x) >= LIMIT:
		plane_v = 0.0


func _gust_push() -> float:
	if gust.is_empty() or clock < float(gust.start) or clock > float(gust.end):
		return 0.0
	return float(gust.side) * GUST_PUSH


func _plan_gust() -> void:
	if not gust.is_empty() and clock > float(gust.end):
		gust = {}
	var gusts := float(variant.get("gusts", 1.0))
	if not gust.is_empty() or clock < _gust_due or heat() < GUST_HEAT / gusts:
		return
	var side := -1.0 if rng.randf() < 0.5 else 1.0
	gust = {"side": side, "warn_at": clock, "start": clock + GUST_WARN, "end": clock + GUST_WARN + GUST_SECONDS}
	_gust_due = clock + rng.randf_range(4.5, 7.5) / gusts


## A new gate whose gap, when it arrives, is well away from where the plane is
## now or, with gates already coming, from the last of them: never straight ahead.
func _spawn(aim := INF) -> void:
	var travel := lerpf(TRAVEL_EARLY, TRAVEL_LATE, heat())
	var width := lerpf(WIDTH_EARLY, WIDTH_LATE, heat()) * rng.randf_range(0.92, 1.08)
	var sway := 0.0
	if heat() >= float(variant.get("sway_from", SWAY_HEAT)):
		sway = SWAY * rng.randf_range(0.6, 1.0) * clampf(0.4 + heat(), 0.0, 1.0)
		# A wide gap sways less, so it can always open well away from the plane.
		sway = minf(sway, maxf(0.0, LIMIT - width - PLANE_HALF - CLEAR_MARGIN))
	var room := LIMIT - width * 0.5 - sway
	var centre := aim
	if centre == INF:
		var away := width * 0.5 + PLANE_HALF + CLEAR_MARGIN
		var from := plane_x
		if not gates.is_empty():
			var before: Dictionary = gates[-1]
			from = _centre(before, clock + float(before.z))
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		centre = from + side * rng.randf_range(away, away + REACH)
		if absf(centre) > room:
			centre = from - side * rng.randf_range(away, away + REACH)
		centre = clampf(centre, -room, room)
		if absf(centre - from) < away:
			# Squeezed against a wall: open on the far side instead.
			centre = -room if from > 0.0 else room
	var omega := rng.randf_range(1.6, 2.6)
	var offset := rng.randf() * TAU
	_serial += 1
	var gate := {"serial": _serial, "z": travel, "travel": travel, "sway": sway, "omega": omega, "offset": offset, "width": width, "base": 0.0}
	gate.base = centre - sway * sin((clock + travel) * omega + offset)
	gates.append(gate)


func _advance_gates(delta: float, scoring: bool) -> void:
	for gate: Dictionary in gates:
		gate.z = float(gate.z) - delta
	while not gates.is_empty() and float(gates[0].z) <= 0.0:
		var gate: Dictionary = gates.pop_front()
		_meet(gate, scoring)
		if phase == "crash":
			return


func _meet(gate: Dictionary, scoring: bool) -> void:
	var centre := _centre(gate, clock)
	var width := float(gate.width)
	var off := absf(plane_x - centre)
	var through := off <= clearance(width)
	var ring := off <= window(ring_radius(width))
	last = {"at": clock, "serial": int(gate.serial), "travel": float(gate.travel), "ok": through, "ring": through and ring, "centre": centre, "width": width}
	if not scoring:
		return
	if not through:
		_crash()
		return
	if not touched:
		return
	passed += 1
	var points := GATE_POINTS + STREAK_POINTS * mini(streak, STREAK_CAP)
	streak += 1
	if ring:
		rings += 1
		points += RING_POINTS
		add_score(points, "穿環！+%d" % points)
		sound(76 + mini(streak, 6) * 2)
	else:
		add_score(points, "+%d" % points)
		sound(64 + mini(streak, 6))


func _crash() -> void:
	crashes += 1
	streak = 0
	sound(38)
	# The first crumple of a round is a free look at the paper ball.
	funny_fail("撞上岩壁，揉成紙團了！", crashes > 1)
	phase = "crash"
	phase_at = clock
	gates.clear()
	gust = {}


func _reset_flight() -> void:
	phase = "fly"
	phase_at = clock
	plane_x = 0.0
	plane_v = 0.0
	gates.clear()
	gust = {}
