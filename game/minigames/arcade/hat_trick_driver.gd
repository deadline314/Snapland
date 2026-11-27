extends "res://game/minigames/arcade/arcade_driver.gd"
## 帽中套物: hold the button and the hero keeps pulling things out of the magic
## hat — knotted scarves, bouquets, doves, a rabbit — each one clipped onto the
## line over the stage; let go to take a bow and bank the whole line. Somewhere
## in every hat waits a skunk. Just before it the hat both shakes and smokes;
## a hat that only shakes or only smokes is bluffing. Pull the skunk and a green
## cloud swallows the hero, who pinches his nose with watering eyes, and the
## line is lost. Rules only: the picture lives in hat_trick_view.gd.

const View = preload("res://game/minigames/arcade/hat_trick_view.gd")
const VALUES := {"scarf": 5, "bouquet": 10, "dove": 15, "rabbit": 25}
## The line holds this many; a hat that runs out of tricks banks itself.
const MAX_ITEMS := 12
const EMPTY_BONUS := 30
## Seconds from pressing to the first item, and between items early and late.
const FIRST_PULL := 0.45
const GAP_EARLY := 0.5
const GAP_LATE := 0.3
## How long the hat warns before the skunk, early and late.
const WARN_EARLY := 0.75
const WARN_LATE := 0.45
## A skunk never comes before this item; the chance per item early and late.
const SAFE_ITEMS := 3
const HAZARD_EARLY := 0.12
const HAZARD_LATE := 0.3
const HAZARD_STEP := 0.05
const FAKE_EARLY := 0.08
const FAKE_LATE := 0.28
## Letting go while the hat really warns earns this.
const CLOSE_CALL := 10
const BOW_SECONDS := 1.2
const STINK_SECONDS := 2.2

## "idle" (hat ready), "pull" (holding), "bow" (banked) or "stink".
var phase := "idle"
var phase_at := 0.0
## The line: {kind, at} in pull order.
var line: Array[Dictionary] = []
## This hat's script: what comes out of it in order (the skunk last if any),
## and the items whose turn is preceded by a warning: index -> "both" | "shake" | "smoke".
var hat_items: Array[String] = []
var warnings: Dictionary = {}
var gap := GAP_EARLY
var warn := WARN_EARLY
## Clock when this pull started (items come out from there).
var pull_at := 0.0
var last_bank := 0
var hats := 0
var stinks := 0
var _holding := false


func _init() -> void:
	verb = "按住一直拉！帽子又抖又冒煙就快放手！"
	hint = [["空白鍵", "按住拉、放手收"]]
	round_seconds = 50.0
	thresholds = [400, 750, 1200]
	verdicts = [
		"臭鼬比你還受歡迎。",
		"銅牌！兔子有拉出來，觀眾有鼓掌。",
		"銀牌！帽子裡的東西都被你騙光了。",
		"金牌！臭鼬到現在還沒見過你。",
	]
	variants = [
		{"id": "standard", "label": "今晚的帽子", "hazard": 1.0, "fakes": 1.0, "rabbits": 1.0},
		{"id": "bluff", "label": "愛演的帽子", "hazard": 1.0, "fakes": 2.6, "rabbits": 1.0},
		{"id": "bunnies", "label": "兔子大放送", "hazard": 1.3, "fakes": 1.0, "rabbits": 2.4},
	]
	score_label = "魔術得分"
	view_script = View


func _begin_round(_chosen: Dictionary) -> void:
	line.clear()
	hats = 0
	stinks = 0
	last_bank = 0
	_holding = false
	_new_hat()


## The countdown shows the idea: two scarves and a rabbit, then a bow.
func _warm_up(_delta: float) -> void:
	var demo := ["scarf", "scarf", "rabbit"]
	var due := int((clock - 0.3) / 0.45)
	while line.size() < mini(due, demo.size()) and clock < 1.9:
		line.append({"kind": demo[line.size()], "at": clock})
	if clock >= 1.9 and phase != "bow":
		_phase("bow")


func _go() -> void:
	line.clear()
	last_bank = 0
	_new_hat()
	# Holding through the countdown starts pulling the moment play begins.
	_holding = _held.values().has(&"action")
	if _holding:
		_start_pull()


func _tick(_delta: float) -> void:
	match phase:
		"pull":
			var due := pulled_by(clock)
			while line.size() < due and phase == "pull":
				_pull_next()
		"bow":
			if clock - phase_at >= BOW_SECONDS:
				_new_hat()
				if _holding:
					_start_pull()
		"stink":
			if clock - phase_at >= STINK_SECONDS:
				_new_hat()


func _press(button: StringName) -> void:
	if button != &"action":
		return
	_holding = true
	if phase == "idle":
		_start_pull()


func _release(button: StringName) -> void:
	if button != &"action":
		return
	_holding = false
	if phase == "pull":
		if line.is_empty():
			_phase("idle")
		else:
			_bank()


func _round_over() -> void:
	# Whatever is on the line when the bell rings still takes its bow.
	if phase == "pull" and not line.is_empty():
		_bank()


func _snapshot(into: Dictionary) -> void:
	into.phase = phase
	into.phase_at = phase_at
	into.line = line
	into.pot = pot()
	into.last_bank = last_bank
	into.warning = warning_now()
	into.next_kind = hat_items[line.size()] if phase == "pull" and line.size() < hat_items.size() else ""
	into.max_items = MAX_ITEMS
	into.holding = _holding


## How many items are out by `moment` in the current pull.
func pulled_by(moment: float) -> int:
	if moment < pull_at + FIRST_PULL:
		return 0
	return mini(hat_items.size(), int((moment - pull_at - FIRST_PULL) / gap) + 1)


## When item `index` of this pull comes out.
func due_at(index: int) -> float:
	return pull_at + FIRST_PULL + index * gap


## "both", "shake", "smoke" or "" — what the hat is doing right now.
func warning_now() -> String:
	if phase != "pull":
		return ""
	# A warning can start before the trick ahead of it is out.
	var shown := ""
	for index in range(line.size(), hat_items.size()):
		if clock < due_at(index) - warn:
			break
		if warnings.has(index) and shown != "both":
			shown = str(warnings[index])
	return shown


## What letting go now would bank.
func pot() -> int:
	var total := 0
	for item in line:
		total += int(VALUES.get(item.kind, 0))
	# Longer lines pay more per trick: three tricks at face value, six double.
	return roundi(total * maxf(1.0, line.size() / 3.0))


func _new_hat() -> void:
	hats += 1
	line.clear()
	hat_items.clear()
	warnings.clear()
	gap = lerpf(GAP_EARLY, GAP_LATE, heat())
	warn = window(lerpf(WARN_EARLY, WARN_LATE, heat()))
	var hazard := lerpf(HAZARD_EARLY, HAZARD_LATE, heat()) * float(variant.get("hazard", 1.0))
	var fake := lerpf(FAKE_EARLY, FAKE_LATE, heat()) * float(variant.get("fakes", 1.0))
	for index in MAX_ITEMS:
		# Each trick deeper into the hat is riskier than the last.
		if index >= SAFE_ITEMS and rng.randf() < hazard + HAZARD_STEP * (index - SAFE_ITEMS):
			hat_items.append("skunk")
			warnings[index] = "both"
			break
		hat_items.append(_trick())
		if index >= 1 and rng.randf() < fake:
			warnings[index] = "shake" if rng.randf() < 0.5 else "smoke"
	_phase("idle")


func _trick() -> String:
	var rabbits := 0.08 * float(variant.get("rabbits", 1.0))
	var roll := rng.randf()
	if roll < rabbits:
		return "rabbit"
	if roll < rabbits + 0.12:
		return "dove"
	if roll < rabbits + 0.3:
		return "bouquet"
	return "scarf"


func _start_pull() -> void:
	pull_at = clock
	_phase("pull")


func _pull_next() -> void:
	var kind := hat_items[line.size()]
	if kind == "skunk":
		_stink()
		return
	line.append({"kind": kind, "at": due_at(line.size())})
	sound(60 + line.size() * 2)
	if line.size() >= hat_items.size():
		# The hat ran out of tricks before any skunk.
		add_score(EMPTY_BONUS, "帽子空了！+%d" % EMPTY_BONUS)
		_bank()


func _bank() -> void:
	var amount := pot()
	var close := warning_now() == "both"
	if close:
		amount += CLOSE_CALL
	last_bank = amount
	add_score(amount, ("好險！+%d" if close else "+%d") % amount)
	sound(84)
	_phase("bow")


func _stink() -> void:
	stinks += 1
	line.append({"kind": "skunk", "at": clock})
	sound(36)
	# The first skunk of a round is a free look at the green cloud.
	funny_fail("臭鼬！", stinks > 1)
	_phase("stink")


func _phase(next_phase: String) -> void:
	phase = next_phase
	phase_at = clock
