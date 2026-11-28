extends "res://game/minigames/arcade/arcade_driver.gd"
## 回聲鑰匙: a guest-room door has a round brass lock of nested rings, each
## spinning with one notch in it. Press the button the moment the spinning
## ring's notch passes under the key at the top: the ring clicks open and the
## key slides one ring deeper; open every ring and the door swings open onto
## the next room. A soft echo pulses from the keyhole as the notch comes round.
## The rings spin faster and faster; later they reverse (a shudder first) or
## speed up and slow down. Press when the notch is elsewhere and the door
## bursts open on a broom cupboard that buries the traveller.
## Rules only: the picture lives in echo_key_view.gd.
##
## Angles are degrees of the notch from the top, increasing clockwise.

const View = preload("res://game/minigames/arcade/echo_key_view.gd")
## Ring speed (degrees a second) at the start and the end of play.
const SPIN_FIRST := 120.0
const SPIN_LAST := 320.0
## A press counts when the notch is this many seconds from the top, and dead
## on within the smaller window.
const HIT_SECONDS := 0.065
const DEAD_ON_SECONDS := 0.022
const RINGS_FIRST := 3
const RINGS_LAST := 5
## A reversing ring shudders this long before it turns the other way.
const SHUDDER_SECONDS := 0.3
const REVERSE_HEAT := 0.4
const WOBBLE_HEAT := 0.5
const BROOM_SECONDS := 1.7
const OPEN_SECONDS := 1.0
const RING_POINTS := 10
const DEAD_ON_POINTS := 15
const DOOR_POINTS := 40
const STREAK_POINTS := 1
const STREAK_CAP := 10

## The rings of the current door, outermost first: {angle, direction (1
## clockwise, -1 not), open, reverse_at (clock time of the next turn-about,
## negative for none), phase}.
var rings: Array[Dictionary] = []
## Index of the ring the key is working on.
var current := 0
var door := 1
var doors_opened := 0
var rings_opened := 0
var dead_on := 0
var streak := 0
var brooms := 0
var broom_at := -99.0
var open_at := -99.0
var clicked_at := -99.0
var _demo := false


func _init() -> void:
	verb = "鎖圈的缺口轉到鑰匙下面時按，一圈一圈打開房門！"
	hint = [["空白鍵", "轉鑰匙"]]
	round_seconds = 45.0
	thresholds = [180, 500, 680]
	verdicts = [
		"掃把們很高興認識你。",
		"銅牌！門是開了幾扇，掃把也埋了你幾次。",
		"銀牌！幽靈服務生要把備份鑰匙交給你。",
		"金牌！整條走廊的門都為你喀啦打開。",
	]
	variants = [
		{"id": "standard", "label": "一般客房"},
		{"id": "reverse", "label": "倒轉鎖", "reverse": 0.65, "reverse_heat": 0.1},
		{"id": "wobble", "label": "醉醺醺的鎖", "wobble": 0.5, "wobble_heat": 0.1},
	]
	score_label = "開鎖得分"
	view_script = View


func _begin_round(_chosen: Dictionary) -> void:
	_demo = true
	_reset_lock()


## The countdown opens the first ring by itself.
func _warm_up(delta: float) -> void:
	_spin(delta)
	if current == 0 and absf(wrapf(float(rings[0].angle), -180.0, 180.0)) / ring_speed(rings[0]) <= HIT_SECONDS * 0.5:
		_try()


func _go() -> void:
	_demo = false
	_reset_lock()


func _tick(delta: float) -> void:
	_spin(delta)


func _press(button: StringName) -> void:
	if button == &"action" or button == &"up":
		_try()


## No input, no points (a lock left alone never opens anyway).
func add_score(points: int, word := "") -> void:
	if touched:
		super(points, word)


func _snapshot(into: Dictionary) -> void:
	into.rings = rings
	into.current = current
	into.door = door
	into.broom_at = broom_at
	into.broom_seconds = BROOM_SECONDS
	into.open_at = open_at
	into.open_seconds = OPEN_SECONDS
	into.clicked_at = clicked_at
	into.shudder_seconds = SHUDDER_SECONDS
	into.streak = streak
	into.next_in = time_to_top(rings[current]) if current < rings.size() else 99.0


func spin_speed() -> float:
	return pace(lerpf(SPIN_FIRST, SPIN_LAST, heat()))


## How fast a ring turns right now: wobbling locks speed up and slow down.
func ring_speed(ring: Dictionary) -> float:
	var wobble := float(variant.get("wobble", 0.3))
	if _demo or heat() < float(variant.get("wobble_heat", WOBBLE_HEAT)):
		wobble = 0.0
	return spin_speed() * (1.0 + wobble * sin(clock * 3.1 + float(ring.phase)))


## Signed seconds until the ring's notch reaches the top at its current
## speed and direction; negative when it has just passed.
func time_to_top(ring: Dictionary) -> float:
	var off := wrapf(float(ring.angle), -180.0, 180.0)
	return -off * float(ring.direction) / maxf(1.0, ring_speed(ring))


func busy() -> bool:
	return clock - broom_at < BROOM_SECONDS or clock - open_at < OPEN_SECONDS


func _spin(delta: float) -> void:
	if busy():
		return
	for index in rings.size():
		var ring := rings[index]
		if bool(ring.open):
			continue
		var before := wrapf(float(ring.angle), -180.0, 180.0)
		if float(ring.reverse_at) >= 0.0 and clock >= float(ring.reverse_at):
			ring.direction = -int(ring.direction)
			ring.reverse_at = _next_reverse()
		ring.angle = wrapf(float(ring.angle) + float(ring.direction) * ring_speed(ring) * delta, -180.0, 180.0)
		# A soft tick each time the working ring's notch passes the keyhole.
		if index == current and signf(before) != signf(float(ring.angle)) and absf(before) < 90.0:
			sound(64)
	if current >= rings.size() and clock - open_at >= OPEN_SECONDS:
		_new_door()


func _try() -> void:
	if busy() or current >= rings.size():
		return
	var ring := rings[current]
	var away := absf(wrapf(float(ring.angle), -180.0, 180.0)) / maxf(1.0, ring_speed(ring))
	if away <= window(HIT_SECONDS):
		_open_ring(ring, away <= window(DEAD_ON_SECONDS))
	else:
		_broom()


func _open_ring(ring: Dictionary, spot_on: bool) -> void:
	ring.open = true
	ring.angle = 0.0
	clicked_at = clock
	current += 1
	streak += 1
	sound(70 + mini(streak, 12))
	if not _demo:
		rings_opened += 1
		if spot_on:
			dead_on += 1
		var points := RING_POINTS + (DEAD_ON_POINTS if spot_on else 0) + mini(streak, STREAK_CAP) * STREAK_POINTS
		add_score(points, "剛好！+%d" % points if spot_on else "")
	if current >= rings.size():
		open_at = clock
		sound(84)
		if not _demo:
			doors_opened += 1
			add_score(DOOR_POINTS, "開門！+%d" % DOOR_POINTS)


func _broom() -> void:
	broom_at = clock
	streak = 0
	sound(46)
	sound(40)
	if _demo:
		return
	brooms += 1
	# The first broom cupboard of a round is a free look.
	funny_fail("被掃把埋了！", brooms > 1)
	# The lock jams shut again: this door starts over once the brooms are swept.
	_fresh_rings()


func _reset_lock() -> void:
	door = 1
	doors_opened = 0
	rings_opened = 0
	dead_on = 0
	streak = 0
	brooms = 0
	broom_at = -99.0
	open_at = -99.0
	clicked_at = -99.0
	_fresh_rings()


func _new_door() -> void:
	door += 1
	_fresh_rings()


## A new set of rings for the current door: more rings later in the round,
## alternating directions, notches well away from the top.
func _fresh_rings() -> void:
	rings.clear()
	current = 0
	var count := RINGS_FIRST if _demo else roundi(lerpf(RINGS_FIRST, RINGS_LAST, heat()))
	var first := 1 if rng.randf() < 0.5 else -1
	for index in count:
		var direction := first if index % 2 == 0 else -first
		# Start each notch at least a third of a turn before the top.
		var angle := -float(direction) * rng.randf_range(120.0, 220.0)
		rings.append({"angle": wrapf(angle, -180.0, 180.0), "direction": direction, "open": false, "reverse_at": -99.0, "phase": rng.randf() * TAU})
		rings.back().reverse_at = _next_reverse()


## When a ring next turns about, or -99 for a ring that never does.
func _next_reverse() -> float:
	if _demo or heat() < float(variant.get("reverse_heat", REVERSE_HEAT)):
		return -99.0
	if rng.randf() >= float(variant.get("reverse", 0.35)):
		return -99.0
	return clock + rng.randf_range(0.7, 1.8)
