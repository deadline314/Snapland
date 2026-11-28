extends "res://game/minigames/arcade/arcade_driver.gd"
## 夢泡搬運: the traveller carries a guest's dream, a big bubble balanced on
## their head, along the hotel corridor from the dream room to the delivery
## door. Hold ← or → to walk. The bubble leans with every start and stop, and
## the footsteps of a full-speed walk rock it in time, so rushing makes it
## wobble out of hand: walk, ease off, walk. Drips fall from cracks in the
## ceiling, chandeliers swing low, and later floor vents puff it sideways. Each
## delivery brings a bigger bubble. If it tips too far or something touches
## it, it pops and the woolly sheep from the dream lands on the traveller's
## head, and the next bubble is small again. Rules only: the picture lives in
## dream_bubble_view.gd.
##
## `walker` runs 0 (dream-room door) to 1 (delivery door); the hazards are
## placed in screen pixels, where the corridor runs from START_PX to END_PX.

const View = preload("res://game/minigames/arcade/dream_bubble_view.gd")
const START_PX := 190.0
const END_PX := 1090.0
const FLOOR_Y := 612.0
const CEILING_Y := 168.0
## Top of the traveller's head; the bubble sits on it.
const HEAD_Y := 486.0
## Walking: top speed (corridor lengths a second) and how fast it answers.
const WALK := 0.3
const WALK_RESPONSE := 5.0
## The bubble's lean: 1 is the point it rolls off. It springs back, damps,
## is pushed by the walker's changes of speed and rocked by their footsteps,
## whose beat at full speed matches its own sway.
const STIFF := 18.0
const DAMP := 2.0
const SHOVE := 2.6
const STEP_FORCE := 7.5
const STEP_RATE := 4.3
const GUST := 7.0
## Bubble radius in pixels for the first delivery and each one after.
const RADIUS_FIRST := 36.0
const RADIUS_GROWTH := 6.0
const RADIUS_MOST := 66.0
const POP_SECONDS := 1.8
const WALK_IN_SECONDS := 0.6
## Drip timing (seconds): the drop swells, then falls to the floor.
const DRIP_SWELL := 0.75
const DRIP_FALL := 0.36
const DROP := 9.0
const LAMP_LENGTH := 200.0
const LAMP := 28.0
const LAMP_SWING := 0.5
const VENT_PUFF := 0.8
const VENT_REACH := 70.0
const LAMP_HEAT := 0.2
const VENT_HEAT := 0.35
const DELIVER_POINTS := 60
const SIZE_POINTS := 30
const STEADY_POINTS := 40
const PASS_POINTS := 5

var walker := 0.0
var speed := 0.0
var lean := 0.0
var lean_speed := 0.0
var step_phase := 0.0
## The greatest lean on this trip, for the steady bonus.
var worst := 0.0
var trips := 0
var delivered := 0
var pops := 0
var level := 0
## This trip's hazards, left to right: {kind ("drip"/"lamp"/"vent"), x (px),
## period, phase, push (a vent's direction), passed}.
var hazards: Array[Dictionary] = []
var pop_at := -99.0
var pop_cause := ""
var deliver_at := -99.0
var walk_in_at := -99.0
var _left := 0
var _right := 0
var _demo := false
var _restart_pending := false


func _init() -> void:
	verb = "頂著夢泡泡走到對面，別走太快、別被碰破！"
	hint = [["← →", "走路"]]
	round_seconds = 45.0
	thresholds = [200, 520, 600]
	verdicts = [
		"綿羊很喜歡你的頭。",
		"銅牌！夢有送到，雖然破了幾顆。",
		"銀牌！客人睡得香甜，夢一顆也沒漏。",
		"金牌！你是幽幽旅館最溫柔的送夢員。",
	]
	variants = [
		{"id": "standard", "label": "夜班送夢"},
		{"id": "drafty", "label": "漏風走廊", "vent_heat": 0.08, "vents": 0.45},
		{"id": "drippy", "label": "雨夜滴水", "drips": 0.75, "drip_fast": 0.8},
	]
	score_label = "送夢得分"
	view_script = View


func _begin_round(_chosen: Dictionary) -> void:
	_demo = true
	_reset_corridor()


## The countdown walks a few steps by itself, so the bubble shows its sway.
func _warm_up(delta: float) -> void:
	_walk(delta, 1 if walker < 0.2 else 0)


func _go() -> void:
	_demo = false
	_reset_corridor()
	# An arrow already held through the countdown sets off at once.
	for button: StringName in _held.values():
		touched = true
		_press(button)


func _tick(delta: float) -> void:
	_walk(delta, _right - _left if _right != _left else 0)


func _press(button: StringName) -> void:
	if button == &"left":
		_left += 1
	elif button == &"right":
		_right += 1


func _release(button: StringName) -> void:
	if button == &"left":
		_left = maxi(0, _left - 1)
	elif button == &"right":
		_right = maxi(0, _right - 1)


## No input, no points (a walker nobody steers never moves anyway).
func add_score(points: int, word := "") -> void:
	if touched:
		super(points, word)


func _round_over() -> void:
	_left = 0
	_right = 0


func _snapshot(into: Dictionary) -> void:
	into.walker = walker
	into.walker_px = walker_px()
	into.speed = speed
	into.walk_speed = WALK
	into.lean = lean
	into.radius = radius()
	into.level = level
	into.hazards = hazards
	into.pop_at = pop_at
	into.pop_cause = pop_cause
	into.pop_seconds = POP_SECONDS
	into.deliver_at = deliver_at
	into.walk_in_at = walk_in_at
	into.walk_in_seconds = WALK_IN_SECONDS
	into.step_phase = step_phase
	into.drip_swell = DRIP_SWELL
	into.drip_fall = DRIP_FALL
	into.vent_puff = VENT_PUFF
	into.delivered = delivered


func walker_px() -> float:
	return lerpf(START_PX, END_PX, walker)


func radius() -> float:
	return minf(RADIUS_MOST, RADIUS_FIRST + RADIUS_GROWTH * level)


## Where the bubble's middle is right now.
func bubble_centre() -> Vector2:
	var r := radius()
	return Vector2(walker_px() + lean * r * 0.9, HEAD_Y - r + absf(lean) * r * 0.25)


## How hard pushes rock the bubble: bigger bubbles rock more; assist calms it.
func wobble_scale() -> float:
	return (1.0 + 0.12 * level) / (ASSIST_WINDOW if assisted else 1.0)


func busy() -> bool:
	return clock - pop_at < POP_SECONDS or clock - walk_in_at < WALK_IN_SECONDS


## Where a drip's drop is (y px) at the driver clock, or -1 while it hangs.
func drop_y(hazard: Dictionary) -> float:
	var t := fposmod(clock + float(hazard.phase), float(hazard.period))
	if t < DRIP_SWELL:
		return -1.0
	var fall := (t - DRIP_SWELL) / DRIP_FALL
	if fall > 1.0:
		return -1.0
	return lerpf(CEILING_Y + 12.0, FLOOR_Y, fall * fall)


## How far a drip's next drop has swelled, 0..1.
func drip_swell(hazard: Dictionary) -> float:
	var t := fposmod(clock + float(hazard.phase), float(hazard.period))
	return clampf(t / DRIP_SWELL, 0.0, 1.0) if t < DRIP_SWELL else 0.0


func lamp_angle(hazard: Dictionary) -> float:
	return LAMP_SWING * sin(TAU * (clock + float(hazard.phase)) / float(hazard.period))


func lamp_bob(hazard: Dictionary) -> Vector2:
	var angle := lamp_angle(hazard)
	return Vector2(float(hazard.x) + LAMP_LENGTH * sin(angle), CEILING_Y + LAMP_LENGTH * cos(angle))


func vent_puffing(hazard: Dictionary) -> bool:
	return fposmod(clock + float(hazard.phase), float(hazard.period)) < VENT_PUFF


func _walk(delta: float, side: int) -> void:
	if _restart_pending and clock - pop_at >= POP_SECONDS:
		_restart_pending = false
		_restart_trip()
	if busy():
		speed = 0.0
		return
	var before := speed
	speed = lerpf(speed, WALK * side, 1.0 - exp(-WALK_RESPONSE * delta))
	var accel := (speed - before) / delta
	walker = clampf(walker + speed * delta, 0.0, 1.0)
	# The bubble lags behind every change of pace, and footsteps rock it.
	var heavy := wobble_scale()
	step_phase += absf(speed) / WALK * STEP_RATE * delta
	var step := STEP_FORCE * pow(absf(speed) / WALK, 2.0) * sin(step_phase)
	var force := -STIFF * lean - DAMP * lean_speed - accel * SHOVE * heavy + step * heavy
	for hazard in hazards:
		if str(hazard.kind) == "vent" and vent_puffing(hazard) and absf(walker_px() - float(hazard.x)) < VENT_REACH:
			force += GUST * float(hazard.push) * heavy
	lean_speed += force * delta
	lean += lean_speed * delta
	worst = maxf(worst, absf(lean))
	if absf(lean) >= 1.0:
		_pop("tip")
		return
	if not _demo:
		_check_hazards()
	if walker >= 1.0:
		_deliver()


func _check_hazards() -> void:
	var centre := bubble_centre()
	var r := radius()
	for hazard in hazards:
		var x := float(hazard.x)
		match str(hazard.kind):
			"drip":
				var y := drop_y(hazard)
				if y >= 0.0 and absf(y - centre.y) < r + DROP and absf(x - centre.x) < r + DROP:
					_pop("drip")
					return
			"lamp":
				if lamp_bob(hazard).distance_to(centre) < r + LAMP:
					_pop("lamp")
					return
		if not bool(hazard.passed) and walker_px() > x + r:
			hazard.passed = true
			sound(72)
			add_score(PASS_POINTS)


func _pop(cause: String) -> void:
	pop_at = clock
	pop_cause = cause
	speed = 0.0
	sound(50)
	sound(43)
	# Back to the dream room for a fresh bubble once the sheep has hopped off.
	_restart_pending = true
	if _demo:
		return
	pops += 1
	# The dream is lost: the dream room starts over with a small bubble.
	level = 0
	# The first popped dream of a round is a free look.
	funny_fail("泡泡破了！", pops > 1)


func _deliver() -> void:
	deliver_at = clock
	sound(79)
	sound(84)
	if _demo:
		walker = 1.0
		return
	delivered += 1
	var points := DELIVER_POINTS + SIZE_POINTS * level
	if worst < 0.5:
		points += STEADY_POINTS
		add_score(points, "穩穩送達！+%d" % points)
	else:
		add_score(points, "送達！+%d" % points)
	level += 1
	_restart_trip()


## Back at the dream-room door with a fresh bubble: walk in, then go.
func _restart_trip() -> void:
	walker = 0.0
	speed = 0.0
	lean = 0.0
	lean_speed = 0.0
	worst = 0.0
	walk_in_at = clock
	trips += 1
	_plan_trip()


func _reset_corridor() -> void:
	walker = 0.0
	speed = 0.0
	lean = 0.0
	lean_speed = 0.0
	step_phase = 0.0
	worst = 0.0
	trips = 0
	delivered = 0
	pops = 0
	level = 0
	pop_at = -99.0
	deliver_at = -99.0
	walk_in_at = -99.0
	_restart_pending = false
	_left = 0
	_right = 0
	_plan_trip()


## Two to four hazards spread along the corridor: drips first, then
## chandeliers, then vents; later trips have more and quicker ones.
func _plan_trip() -> void:
	hazards.clear()
	if _demo:
		return
	var count := 2 + mini(2, int(heat() * 3.0))
	var slots: Array[float] = []
	for index in count:
		slots.append(lerpf(START_PX + 170.0, END_PX - 150.0, (index + rng.randf_range(0.3, 0.7)) / count))
	for x in slots:
		var kind := "drip"
		var pick := rng.randf()
		if heat() >= float(variant.get("vent_heat", VENT_HEAT)) and pick < float(variant.get("vents", 0.25)):
			kind = "vent"
		elif heat() >= LAMP_HEAT and pick < 1.0 - float(variant.get("drips", 0.45)):
			kind = "lamp"
		var period := 2.2
		match kind:
			"drip":
				period = rng.randf_range(1.35, 2.0) * float(variant.get("drip_fast", 1.0)) * lerpf(1.0, 0.85, heat())
			"lamp":
				period = rng.randf_range(2.2, 3.0) * lerpf(1.0, 0.8, heat())
			"vent":
				period = rng.randf_range(2.0, 2.8)
		hazards.append({"kind": kind, "x": x, "period": period, "phase": rng.randf() * period,
			"push": -1.0 if rng.randf() < 0.5 else 1.0, "passed": false})
