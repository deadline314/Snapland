extends "res://game/minigames/arcade/arcade_driver.gd"
## 電梯借重: the traveller runs the hotel's old brass lift. It keeps going up
## and down the shaft on its own; hold the button to brake. The car slides a
## little before it stops, further the faster it goes and the more guests are
## aboard, so brake early and stop it level with a storey. Guests wait at lit
## floors; they hop in and want another storey. Level stops let them in and
## out for points. Later the lift runs faster, more guests call at once and
## some are in a hurry. Stop between floors and the doors open anyway: a
## guest's feet dangle over the gap and the door pinches the traveller's cap.
## Rules only: the picture lives in lift_brake_view.gd.
##
## Heights are in floors: 0 is the ground floor, FLOORS - 1 the top.

const View = preload("res://game/minigames/arcade/lift_brake_view.gd")
const FLOORS := 5
## Top speed (floors a second) early and late, how fast it gets there and how
## hard the brake bites with an empty car.
const SPEED_FIRST := 1.1
const SPEED_LAST := 2.4
const ACCEL := 3.5
const BRAKE := 4.2
## Each guest aboard makes the car this much heavier to stop.
const WEIGHT := 0.18
const CAPACITY := 4
## How close to a storey counts as level, and as dead level.
const LEVEL := 0.07
const DEAD_LEVEL := 0.025
const DOORS_SECONDS := 0.9
const PINCH_SECONDS := 1.6
## Seconds between new guests early and late, and how long they will wait.
const CALL_FIRST := 2.6
const CALL_LAST := 1.3
const PATIENCE_FIRST := 9.0
const PATIENCE_LAST := 6.0
const RUSH_HEAT := 0.3
const DROP_POINTS := 30
const PICK_POINTS := 10
const LEVEL_POINTS := 15
const STREAK_POINTS := 2
const STREAK_CAP := 10

var car := 0.0
var velocity := 0.0
var direction := 1
var braking := false
## Waiting guests: {floor, at, patience, rush}. Riders: {to, rush}.
var waiting: Array[Dictionary] = []
var riders: Array[Dictionary] = []
## The last stop: {floor, at, offset, level (bool), boarded, left}.
var stop: Dictionary = {}
var pinch_at := -99.0
var delivered := 0
var pinches := 0
var gave_up := 0
var streak := 0
var _next_call := 0.0
var _demo := false
var _settled := false


func _init() -> void:
	verb = "按住鍵剎車，讓電梯剛好停在有客人的樓層！"
	hint = [["空白鍵", "按住剎車"]]
	round_seconds = 45.0
	thresholds = [200, 520, 780]
	verdicts = [
		"客人們決定走樓梯。",
		"銅牌！停得歪歪的，客人還是到了。",
		"銀牌！幽靈房客說這是最平穩的電梯。",
		"金牌！每一層都剛剛好，叮！",
	]
	variants = [
		{"id": "standard", "label": "夜班電梯"},
		{"id": "rush", "label": "退房潮", "calls": 0.7, "rush": 0.45},
		{"id": "heavy", "label": "胖胖幽靈團", "weight": 1.8},
	]
	score_label = "電梯得分"
	view_script = View


func _begin_round(_chosen: Dictionary) -> void:
	_demo = true
	_reset_lift()
	waiting.append(_guest(2))


## The countdown brakes the lift onto the first guest's storey by itself.
func _warm_up(delta: float) -> void:
	var target := 2.0
	braking = stop.is_empty() and absf(car - target) <= velocity * velocity / (2.0 * brake_force()) + 0.01 and signf(target - car) == signf(velocity)
	_run(delta)


func _go() -> void:
	_demo = false
	_reset_lift()
	# A button already held through the countdown takes hold at once.
	for button: StringName in _held.values():
		touched = true
		_press(button)


func _tick(delta: float) -> void:
	_run(delta)
	_call_guests()


func _press(button: StringName) -> void:
	if button == &"action" or button == &"down":
		braking = true


func _release(button: StringName) -> void:
	if button == &"action" or button == &"down":
		braking = false
		_settled = false


## No input, no points (a lift nobody brakes never stops anyway).
func add_score(points: int, word := "") -> void:
	if touched:
		super(points, word)


func _round_over() -> void:
	braking = false


func _snapshot(into: Dictionary) -> void:
	into.car = car
	into.velocity = velocity
	into.braking = braking
	into.floors = FLOORS
	into.waiting = waiting
	into.riders = riders
	into.stop = stop
	into.pinch_at = pinch_at
	into.pinch_seconds = PINCH_SECONDS
	into.doors_seconds = DOORS_SECONDS
	into.streak = streak
	into.stopping = stopping_distance()


func top_speed() -> float:
	return pace(lerpf(SPEED_FIRST, SPEED_LAST, heat()))


## How hard the brake bites now: every guest aboard makes the car slide further.
func brake_force() -> float:
	return BRAKE / (1.0 + WEIGHT * float(variant.get("weight", 1.0)) * riders.size())


## How far the car will slide from here if the brake is held.
func stopping_distance() -> float:
	return velocity * velocity / (2.0 * brake_force())


func pinched() -> bool:
	return clock - pinch_at < PINCH_SECONDS


func doors_open() -> bool:
	return not stop.is_empty() and clock - float(stop.at) < DOORS_SECONDS


func _run(delta: float) -> void:
	if pinched() or doors_open():
		velocity = 0.0
		return
	if braking:
		var slow := brake_force() * delta
		if absf(velocity) <= slow:
			if not _settled and absf(velocity) > 0.0:
				velocity = 0.0
				_stopped()
			velocity = 0.0
			_settled = true
			return
		velocity -= signf(velocity) * slow
	else:
		velocity = move_toward(velocity, direction * top_speed(), ACCEL * delta)
	car += velocity * delta
	# Turn round at the top and bottom of the shaft.
	if car >= FLOORS - 1 and velocity > 0.0:
		car = FLOORS - 1
		velocity = 0.0
		direction = -1
	elif car <= 0.0 and velocity < 0.0:
		car = 0.0
		velocity = 0.0
		direction = 1


func _stopped() -> void:
	var storey := clampi(roundi(car), 0, FLOORS - 1)
	var offset := absf(car - storey)
	if offset <= window(LEVEL):
		_serve(storey, offset)
	else:
		_pinch(storey, offset)


func _serve(storey: int, offset: float) -> void:
	car = float(storey)
	var left := 0
	var boarded := 0
	var points := 0
	for rider in riders.duplicate():
		if int(rider.to) == storey:
			riders.erase(rider)
			left += 1
			points += DROP_POINTS * (2 if bool(rider.rush) else 1)
	for guest in waiting.duplicate():
		if int(guest.floor) == storey and riders.size() < CAPACITY:
			waiting.erase(guest)
			boarded += 1
			points += PICK_POINTS
			var to := rng.randi_range(0, FLOORS - 2)
			if to >= storey:
				to += 1
			riders.append({"to": to, "rush": bool(guest.rush)})
	stop = {"floor": storey, "at": clock, "offset": offset, "level": true, "boarded": boarded, "left": left}
	sound(84)
	if left + boarded == 0:
		say("沒有人…", false)
		return
	streak += 1
	if _demo:
		return
	delivered += left
	var dead_on := offset <= window(DEAD_LEVEL)
	points += (LEVEL_POINTS if dead_on else 0) + mini(streak, STREAK_CAP) * STREAK_POINTS
	add_score(points, ("剛剛好！+%d" if dead_on else "叮！+%d") % points)
	sound(72 + mini(streak, 12))


func _pinch(storey: int, offset: float) -> void:
	stop = {"floor": storey, "at": clock, "offset": car - storey, "level": false, "boarded": 0, "left": 0}
	pinch_at = clock
	streak = 0
	sound(46)
	sound(40)
	if _demo:
		return
	pinches += 1
	# The first pinched cap of a round is a free look.
	funny_fail("帽子被夾住了！", pinches > 1)


func _call_guests() -> void:
	for guest in waiting.duplicate():
		if clock - float(guest.at) >= float(guest.patience):
			waiting.erase(guest)
			gave_up += 1
			streak = 0
			say("等不及走樓梯了…", false)
	if clock < _next_call:
		return
	_next_call = clock + lerpf(CALL_FIRST, CALL_LAST, heat()) * rng.randf_range(0.8, 1.2) * (1.0 - float(variant.get("calls", 0.0)) * 0.4)
	if waiting.size() >= 3:
		return
	var free: Array[int] = []
	for storey in FLOORS:
		if absf(car - storey) > 0.6 and not waiting.any(func(guest: Dictionary) -> bool: return int(guest.floor) == storey):
			free.append(storey)
	if free.is_empty():
		return
	var guest := _guest(free[rng.randi() % free.size()])
	if heat() >= RUSH_HEAT and rng.randf() < float(variant.get("rush", 0.2)):
		guest.rush = true
		guest.patience = float(guest.patience) * 0.7
	waiting.append(guest)
	sound(66)


func _reset_lift() -> void:
	car = 0.0
	velocity = 0.0
	direction = 1
	braking = false
	_settled = false
	waiting.clear()
	riders.clear()
	stop = {}
	pinch_at = -99.0
	delivered = 0
	pinches = 0
	gave_up = 0
	streak = 0
	_next_call = clock + 0.3


func _guest(storey: int) -> Dictionary:
	return {"floor": storey, "at": clock, "patience": window(lerpf(PATIENCE_FIRST, PATIENCE_LAST, heat())), "rush": false}
