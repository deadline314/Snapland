extends "res://game/minigames/arcade/arcade_driver.gd"
## 影偶搭梯: shadow puppets on rods glide along a backlit paper screen toward the
## hero's own hand shadow. Press an arrow to make that shape with your hands
## (↑ bird, ← rabbit, → dog, ↓ goose); press it again to turn the shadow to face
## the other way. If your shadow matches the puppet when it arrives, it slips
## through; if not, your hands turn into a dog that turns round and barks at the
## hero. Puppets come faster, later in pairs and mirrored. The hands start as a
## plain fist that matches nothing, so an untouched round scores nothing. Rules
## only: the picture lives in shadow_puppet_view.gd.

const View = preload("res://game/minigames/arcade/shadow_puppet_view.gd")
const SHAPES := {&"up": "bird", &"left": "rabbit", &"right": "dog", &"down": "goose"}
const NAMES := {"bird": "鳥", "rabbit": "兔子", "dog": "狗", "goose": "鵝", "fist": "拳頭"}
## Screen x where the hand shadow sits and where puppets come in.
const SHADOW_X := 380.0
const ENTER_X := 1240.0
## Seconds a puppet takes to reach the shadow, early and late.
const TRAVEL_EARLY := 3.2
const TRAVEL_LATE := 1.4
const GAP_EARLY := 0.9
const GAP_LATE := 0.25
## A second puppet in a pair trails the first by this many seconds.
const PAIR_GAP := 0.75
const BARK_SECONDS := 1.8
const PASS_SECONDS := 0.5
## With assist, a wrong shape gets one short pause at the hands to fix it.
const GRACE_SECONDS := 0.45
const POINTS := 10
const MIRROR_BONUS := 5
const STREAK_BONUS := 2
const STREAK_CAP := 5

## "show" (puppets on their way) or "bark".
var phase := "show"
var phase_at := 0.0
## The hand shadow: a shape and which way it faces (1 right, -1 left).
var shape := "fist"
var facing := 1
var shaped_at := -9.0
## Puppets on the screen: {id, shape, facing, at (born), arrive (clock), passed_at}.
var puppets: Array[Dictionary] = []
var streak := 0
var passes := 0
var barks := 0
var _next_puppet := 0.0
var _next_id := 0


func _init() -> void:
	verb = "方向鍵擺手影，對上飄過來的剪影！"
	hint = [["↑ ← → ↓", "換手影，再按一次轉向"]]
	round_seconds = 45.0
	thresholds = [120, 320, 420]
	verdicts = [
		"你的手只會變成一隻生氣的狗。",
		"銅牌！有幾隻剪影真的穿過去了。",
		"銀牌！兔子鳥兒都從你手上飛過去。",
		"金牌！影子劇團想請你去當台柱。",
	]
	variants = [
		{"id": "standard", "label": "影子劇場", "pairs": 0.25, "mirrors": 0.2},
		{"id": "mirror", "label": "鏡像之夜", "pairs": 0.15, "mirrors": 0.85},
		{"id": "rush", "label": "連環剪影", "pairs": 0.6, "mirrors": 0.15},
	]
	score_label = "手影得分"
	view_script = View


func _begin_round(_chosen: Dictionary) -> void:
	puppets.clear()
	shape = "fist"
	facing = 1
	streak = 0
	passes = 0
	barks = 0
	_next_id = 0
	_phase("show")


## The countdown shows the idea: a rabbit glides in and the hands make a rabbit.
func _warm_up(_delta: float) -> void:
	if puppets.is_empty() and clock < 0.2:
		puppets.append(_puppet("rabbit", 1, 2.0))
	if clock >= 0.9 and shape != "rabbit":
		shape = "rabbit"
		shaped_at = clock
	_arrivals(false)


func _go() -> void:
	puppets.clear()
	shape = "fist"
	facing = 1
	shaped_at = -9.0
	_phase("show")
	_next_puppet = 0.3


func _tick(_delta: float) -> void:
	for puppet in puppets.duplicate():
		if float(puppet.passed_at) >= 0.0 and clock - float(puppet.passed_at) > PASS_SECONDS:
			puppets.erase(puppet)
	if phase == "bark":
		if clock - phase_at >= BARK_SECONDS:
			shape = "fist"
			facing = 1
			_phase("show")
			_next_puppet = play_time + gap()
		return
	_arrivals(true)
	if play_time >= _next_puppet and _waiting() == 0:
		_send()


func _press(button: StringName) -> void:
	if not SHAPES.has(button) or phase == "bark":
		return
	var wanted: String = SHAPES[button]
	if wanted == shape:
		# The same arrow again turns the hands round.
		facing = -facing
	else:
		shape = wanted
		facing = 1
	shaped_at = clock
	sound(60 + ["bird", "rabbit", "dog", "goose"].find(shape) * 4)


func _snapshot(into: Dictionary) -> void:
	into.phase = phase
	into.phase_at = phase_at
	into.shape = shape
	into.facing = facing
	into.shaped_at = shaped_at
	into.puppets = puppets
	into.streak = streak
	into.shadow_x = SHADOW_X
	into.enter_x = ENTER_X


func travel() -> float:
	return lerpf(TRAVEL_EARLY, TRAVEL_LATE, heat())


func gap() -> float:
	return lerpf(GAP_EARLY, GAP_LATE, heat())


## Where a puppet is on the screen now.
func puppet_x(puppet: Dictionary) -> float:
	var t := clampf((clock - float(puppet.at)) / maxf(0.1, float(puppet.arrive) - float(puppet.at)), 0.0, 1.0)
	return lerpf(ENTER_X, SHADOW_X, t)


func _waiting() -> int:
	var count := 0
	for puppet in puppets:
		count += int(float(puppet.passed_at) < 0.0)
	return count


func _send() -> void:
	var mirrored := rng.randf() < float(variant.mirrors) * minf(1.0, heat() * 3.0)
	var length := travel()
	puppets.append(_puppet(_pick(), -1 if mirrored else 1, length))
	if heat() >= 0.2 and rng.randf() < float(variant.pairs):
		var second := _puppet(_pick(), 1, length + PAIR_GAP)
		puppets.append(second)


func _pick() -> String:
	var options: Array = ["bird", "rabbit", "dog", "goose"]
	if not puppets.is_empty():
		options.erase(puppets.back().shape)
	return options[rng.randi() % options.size()]


func _puppet(kind: String, turn: int, length: float) -> Dictionary:
	_next_id += 1
	return {"id": _next_id, "shape": kind, "facing": turn, "at": clock, "arrive": clock + length, "passed_at": -1.0, "graced": false}


## Settle every puppet that has reached the hand shadow.
func _arrivals(scoring: bool) -> void:
	for puppet in puppets:
		if float(puppet.passed_at) >= 0.0 or clock < float(puppet.arrive):
			continue
		if shape == str(puppet.shape) and facing == int(puppet.facing):
			puppet.passed_at = clock
			if scoring:
				var points := POINTS + (MIRROR_BONUS if int(puppet.facing) < 0 else 0) + STREAK_BONUS * mini(streak, STREAK_CAP)
				streak += 1
				passes += 1
				add_score(points, "穿過去！+%d" % points)
				sound(80)
		elif scoring and assisted and not bool(puppet.get("graced", false)):
			puppet.graced = true
			puppet.arrive = clock + GRACE_SECONDS
			say("快換！", false)
		elif scoring:
			_bark()
			return
		else:
			puppet.passed_at = clock


func _bark() -> void:
	barks += 1
	streak = 0
	puppets.clear()
	shape = "dog"
	facing = -1
	sound(42)
	# The first bark of a round is a free look at the dog turning on the hero.
	funny_fail("汪汪！", barks > 1)
	_phase("bark")


func _phase(next_phase: String) -> void:
	phase = next_phase
	phase_at = clock
