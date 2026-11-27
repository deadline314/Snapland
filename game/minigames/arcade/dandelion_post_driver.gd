extends "res://game/minigames/arcade/arcade_driver.gd"
## 蒲公英落郵: the traveller hangs under a big dandelion puff and drifts along
## the greenhouse with a satchel of letters. Hold to catch the air and rise,
## let go to sink. Mailboxes stand on posts or hang from the roof at all
## heights; brush one whose flag is waving and a letter drops in. Warm-air
## vents push the puff up, sprinklers push it down. Bump a cactus pot, a
## hanging basket, the floor or the roof and the traveller lets out a huge
## sneeze: the puff bursts into seeds and they drop holding a bare stem.
## Rules only: the picture lives in dandelion_post_view.gd.
##
## x is in screen widths along the greenhouse (the view scrolls with `travel`);
## y runs 0 (floor) to 1 (roof).

const View = preload("res://game/minigames/arcade/dandelion_post_view.gd")
## Where the traveller hangs across the screen.
const HERO_X := 0.3
const START_Y := 0.55
## Screens per second the greenhouse drifts by, early and late.
const DRIFT_FIRST := 0.17
const DRIFT_LAST := 0.3
const LIFT := 2.3
const GRAVITY := 1.5
const RISE_MAX := 0.6
const SINK_MAX := 0.55
const DAMP := 1.8
## Hit size of the traveller and the puff, in screen widths across and heights up.
const REACH_X := 0.03
const REACH_Y := 0.07
const MAILBOX_REACH := 0.075
const CENTRE := 0.03
const UPDRAFT := 2.6
const SPRAY := 2.4
const GAP := 0.38
const POST_POINTS := 20
const CENTRE_POINTS := 20
const STREAK_POINTS := 5
const STREAK_CAP := 6
const SNEEZE_SECONDS := 1.7
## Ahead of the traveller, how far things are planned.
const AHEAD := 1.6

var y := START_Y
var vy := 0.0
var travel := 0.0
var holding := false
## Planned things along the way: {kind, x, ...}. Kinds:
##   mailbox {y, hang, flag, posted_at}, cactus {top}, basket {bottom},
##   vent {width}, sprinkler {width}.
var things: Array[Dictionary] = []
## The last sneeze: {y, at, why}.
var sneeze: Dictionary = {}
var posted := 0
var streak := 0
var sneezes := 0

var _lifting := 0
var _next_x := 0.0
var _demo := false
var _steered := false


func _init() -> void:
	verb = "按住往上飄、放開往下，碰到揮旗的信箱就投信！"
	hint = [["空白鍵", "按住往上"]]
	round_seconds = 45.0
	thresholds = [200, 500, 650]
	verdicts = [
		"信全飄走了，收信人今天收到蒲公英。",
		"銅牌！信有寄到，只是有點皺。",
		"銀牌！整排信箱的旗子都放下來了。",
		"金牌！溫室郵局頒你飛行郵差徽章。",
	]
	variants = [
		{"id": "standard", "label": "晴天郵路"},
		{"id": "vents", "label": "暖氣日", "vents": 2.0},
		{"id": "sprinklers", "label": "灑水日", "sprinklers": 2.0},
	]
	score_label = "投信得分"
	view_script = View


func _begin_round(_chosen: Dictionary) -> void:
	_steered = false
	_demo = true
	_reset_route()
	# The countdown demo: one mailbox a little above, which the puff floats up to.
	things.append({"kind": "mailbox", "x": HERO_X + 0.24, "y": START_Y + 0.12, "hang": false, "flag": true, "posted_at": -99.0})
	_next_x = 99.0


## The countdown rises to the demo mailbox and posts a letter by itself.
func _warm_up(delta: float) -> void:
	holding = y < START_Y + 0.12 and clock > 0.4
	_fly(delta * 0.7)


func _go() -> void:
	# Play starts mid-air with no climb or fall and nothing within a screen, so
	# the first move is always the player's; left alone the puff sinks to the floor.
	_demo = false
	_reset_route()


func _tick(delta: float) -> void:
	holding = _lifting > 0
	_fly(delta)


func _press(button: StringName) -> void:
	if button in [&"action", &"up", &"second"]:
		_lifting += 1
		_steered = true


func _release(button: StringName) -> void:
	if button in [&"action", &"up", &"second"]:
		_lifting = maxi(0, _lifting - 1)


## No input, no points: a puff left alone never posts a letter for score.
func add_score(points: int, word := "") -> void:
	if _steered:
		super(points, word)


func _round_over() -> void:
	_lifting = 0
	holding = false


func _snapshot(into: Dictionary) -> void:
	into.y = y
	into.vy = vy
	into.travel = travel
	into.holding = holding
	into.hero_x = HERO_X
	into.things = things
	into.sneeze = sneeze
	into.sneeze_seconds = SNEEZE_SECONDS
	into.streak = streak
	into.reach_y = REACH_Y


func drift() -> float:
	return lerpf(DRIFT_FIRST, DRIFT_LAST, heat())


## How far below the hands the traveller can bump things; assist trims it.
func body() -> float:
	return REACH_Y * (0.6 if assisted else 1.0)


func busy() -> bool:
	return not sneeze.is_empty() and clock - float(sneeze.at) < SNEEZE_SECONDS


## Where along the greenhouse the traveller is.
func hero_at() -> float:
	return travel + HERO_X


func _fly(delta: float) -> void:
	if busy():
		return
	if not sneeze.is_empty() and float(sneeze.at) >= 0.0 and y < 0.0:
		_respawn()
	travel += drift() * delta
	var push := LIFT if holding else -GRAVITY
	var at := hero_at()
	for thing: Dictionary in things:
		if absf(float(thing.x) - at) > float(thing.get("width", 0.0)) * 0.5:
			continue
		if thing.kind == "vent":
			push += UPDRAFT
		elif thing.kind == "sprinkler":
			push -= SPRAY
	vy = clampf((vy + push * delta) * exp(-DAMP * delta), -SINK_MAX, RISE_MAX)
	y += vy * delta
	if y <= 0.0:
		_sneeze("floor")
		return
	if y >= 1.0:
		_sneeze("roof")
		return
	for thing: Dictionary in things:
		if absf(float(thing.x) - at) > REACH_X + 0.03:
			continue
		match str(thing.kind):
			"mailbox":
				if bool(thing.flag) and absf(float(thing.y) - y) < window(MAILBOX_REACH) and absf(float(thing.x) - at) < REACH_X + 0.02:
					_post(thing)
			"cactus":
				if y - body() < float(thing.top):
					_sneeze("cactus")
					return
			"basket":
				if y + body() * 0.6 > float(thing.bottom):
					_sneeze("basket")
					return
	_plan()


func _post(mailbox: Dictionary) -> void:
	mailbox.flag = false
	mailbox.posted_at = clock
	streak += 1
	sound(76 + mini(streak, 8))
	if _demo:
		return
	posted += 1
	var centred := absf(float(mailbox.y) - y) < CENTRE
	var points := POST_POINTS + (CENTRE_POINTS if centred else 0) + mini(streak - 1, STREAK_CAP) * STREAK_POINTS
	add_score(points, ("正中信箱！+%d" % points) if centred else "")


func _sneeze(why: String) -> void:
	sneeze = {"y": clampf(y, 0.0, 1.0), "at": clock, "why": why, "x": hero_at()}
	streak = 0
	vy = 0.0
	sound(52)
	sound(40)
	y = -1.0
	if _demo:
		return
	sneezes += 1
	# The first sneeze of a round is a free look at the bare stem.
	funny_fail("哈啾！", sneezes > 1)


## A fresh dandelion: back mid-air with a clear stretch ahead.
func _respawn() -> void:
	y = START_Y
	vy = 0.0
	var clear_to := hero_at() + 0.5
	var kept: Array[Dictionary] = []
	for thing in things:
		if float(thing.x) > clear_to or float(thing.x) < hero_at() - 0.2:
			kept.append(thing)
	things.assign(kept)


func _reset_route() -> void:
	y = START_Y
	vy = 0.0
	travel = 0.0
	holding = false
	_lifting = 0
	things.clear()
	sneeze = {}
	posted = 0
	streak = 0
	sneezes = 0
	_next_x = HERO_X + 1.0
	_plan()


## Keep the route planned ahead: one mailbox every GAP, with a hazard, vent or
## sprinkler between some of them, always leaving a way through.
func _plan() -> void:
	while _next_x < hero_at() + AHEAD:
		var x := _next_x
		var heat_now := heat()
		var low := 0.12
		var high := 0.88
		var mailbox_y := rng.randf_range(lerpf(0.3, low, heat_now), lerpf(0.7, high, heat_now))
		var hang := mailbox_y > 0.62 and rng.randf() < 0.5
		things.append({"kind": "mailbox", "x": x, "y": mailbox_y, "hang": hang, "flag": true, "posted_at": -99.0})
		# Between this mailbox and the next: maybe a hazard or an air current.
		var between := x + GAP * 0.5
		var roll := rng.randf()
		var vents := float(variant.get("vents", 1.0))
		var sprinklers := float(variant.get("sprinklers", 1.0))
		if heat_now > 0.1 and roll < 0.42:
			if rng.randf() < 0.5:
				things.append({"kind": "cactus", "x": between, "top": rng.randf_range(0.18, lerpf(0.3, 0.5, heat_now))})
			else:
				things.append({"kind": "basket", "x": between, "bottom": rng.randf_range(lerpf(0.75, 0.55, heat_now), 0.85)})
		elif roll < 0.42 + 0.15 * vents:
			things.append({"kind": "vent", "x": between, "width": 0.14})
		elif roll < 0.42 + 0.15 * vents + 0.15 * sprinklers:
			things.append({"kind": "sprinkler", "x": between, "width": 0.14})
		_next_x += lerpf(GAP, GAP * 0.8, heat_now)
	var kept: Array[Dictionary] = []
	for thing in things:
		if float(thing.x) > hero_at() - 0.6:
			kept.append(thing)
	things.assign(kept)
