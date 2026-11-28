extends "res://game/minigames/arcade/arcade_driver.gd"
## 枕頭靜步: the traveller tiptoes past a row of sleeping guests to the door at
## the far end. Hold → to creep along. Each guest snores in their own rhythm,
## a bubble swelling and shrinking; while the guest in front of you snores you
## may move, but the moment the snoring stops they open their eyes, and after
## a heartbeat to freeze anyone still moving is caught. Later the snoring gets
## irregular and some guests only pretend to sleep, peeking with one eye. A
## guest who catches you sits up and throws a pillow in the traveller's face.
## Rules only: the picture lives in quiet_steps_view.gd.
##
## `walker` runs 0 (the door you came in by) to 1 (the far door).

const View = preload("res://game/minigames/arcade/quiet_steps_view.gd")
const BEDS := 4
const ZONE := 0.13
## Creeping speed (rows a second) and how fast the traveller stops and starts.
const CREEP := 0.16
const RESPONSE := 14.0
## Moving faster than this counts as moving.
const STILL := 0.012
## Snoring and quiet spells (seconds) early and late.
const SNORE_FIRST := Vector2(1.8, 2.8)
const SNORE_LAST := Vector2(0.7, 1.8)
const QUIET_FIRST := Vector2(0.7, 1.2)
const QUIET_LAST := Vector2(0.6, 1.5)
## The bubble shrinks for this long before the snoring stops.
const WARN := 0.3
## A heartbeat to freeze after the snoring stops or an eye opens.
const REACT := 0.3
const PEEK := 0.8
const FAKE_HEAT := 0.3
const PILLOW_SECONDS := 1.6
const KNOCK_BACK := 0.08
const BED_POINTS := 20
const ROW_POINTS := 60
const STREAK_POINTS := 3
const STREAK_CAP := 10

var walker := 0.0
var speed := 0.0
## This row's guests, left to right: {x, cycle: [[start, end, kind]...]} where
## kind is "snore" or "quiet"; peeks: [start, ...] (a faker peeking mid-snore);
## passed.
var guests: Array[Dictionary] = []
var row := 1
var pillow_at := -99.0
var thrower := -1
var beds_passed := 0
var rows := 0
var caught := 0
var streak := 0
var _right := 0
var _left := 0
var _demo := false


func _init() -> void:
	verb = "客人打呼時往前走，打呼一停立刻站住！"
	hint = [["→", "按住前進"]]
	round_seconds = 45.0
	thresholds = [200, 520, 620]
	verdicts = [
		"枕頭大戰，你輸了。",
		"銅牌！挨了幾顆枕頭，還是溜過去了。",
		"銀牌！客人們一個都沒醒。",
		"金牌！你走路比幽靈還安靜。",
	]
	variants = [
		{"id": "standard", "label": "客房走廊"},
		{"id": "light", "label": "淺眠客人", "snore": 0.8},
		{"id": "peekers", "label": "偷看大會", "fake": 0.55, "fake_heat": 0.08},
	]
	score_label = "靜步得分"
	view_script = View


func _begin_round(_chosen: Dictionary) -> void:
	_demo = true
	_reset_room()


## The countdown creeps forward while the first guest snores and freezes when
## they stop.
func _warm_up(delta: float) -> void:
	_creep(delta, 1 if not watching(0, REACT * 0.5) else 0)


func _go() -> void:
	_demo = false
	_reset_room()
	# An arrow already held through the countdown takes hold at once.
	for button: StringName in _held.values():
		touched = true
		_press(button)


func _tick(delta: float) -> void:
	_creep(delta, _right - _left if _right != _left else 0)


func _press(button: StringName) -> void:
	if button == &"right":
		_right += 1
	elif button == &"left":
		_left += 1


func _release(button: StringName) -> void:
	if button == &"right":
		_right = maxi(0, _right - 1)
	elif button == &"left":
		_left = maxi(0, _left - 1)


## No input, no points (a traveller nobody moves never gets anywhere).
func add_score(points: int, word := "") -> void:
	if touched:
		super(points, word)


func _round_over() -> void:
	_right = 0
	_left = 0


func _snapshot(into: Dictionary) -> void:
	into.walker = walker
	into.speed = speed
	into.creep = CREEP
	into.guests = guests
	into.row = row
	into.pillow_at = pillow_at
	into.pillow_seconds = PILLOW_SECONDS
	into.thrower = thrower
	into.warn = WARN
	into.react = REACT
	into.streak = streak
	var states: Array[String] = []
	for index in guests.size():
		states.append(guest_state(index))
	into.states = states


func pillowed() -> bool:
	return clock - pillow_at < PILLOW_SECONDS


## What a guest is doing now: "snore", "drowsy" (bubble shrinking, about to
## stop), "quiet" (eyes open), or "peek" (a faker's one eye open mid-snore).
func guest_state(index: int) -> String:
	var guest: Dictionary = guests[index]
	for peek: float in guest.peeks:
		if clock >= peek and clock < peek + PEEK:
			return "peek"
	for spell: Array in guest.cycle:
		if clock >= float(spell[0]) and clock < float(spell[1]):
			if str(spell[2]) == "snore":
				return "drowsy" if float(spell[1]) - clock < WARN else "snore"
			return "quiet"
	return "snore"


## Whether guest `index` would catch someone moving now: quiet or peeking for
## longer than `grace` seconds.
func watching(index: int, grace: float) -> bool:
	var guest: Dictionary = guests[index]
	for peek: float in guest.peeks:
		if clock >= peek + grace and clock < peek + PEEK:
			return true
	for spell: Array in guest.cycle:
		if str(spell[2]) == "quiet" and clock >= float(spell[0]) + grace and clock < float(spell[1]):
			return true
	return false


## The guest whose stretch of floor the traveller is on, or -1.
func guest_at(at: float) -> int:
	for index in guests.size():
		if absf(at - float(guests[index].x)) <= ZONE:
			return index
	return -1


func _creep(delta: float, side: int) -> void:
	if pillowed():
		speed = 0.0
		return
	speed = lerpf(speed, CREEP * side, 1.0 - exp(-RESPONSE * delta))
	walker = clampf(walker + speed * delta, 0.0, 1.0)
	var index := guest_at(walker)
	if index >= 0 and absf(speed) > STILL and watching(index, window(REACT)) and not _demo:
		_caught(index)
		return
	for guest_index in guests.size():
		var guest: Dictionary = guests[guest_index]
		if not bool(guest.passed) and walker > float(guest.x) + ZONE:
			guest.passed = true
			streak += 1
			sound(70 + mini(streak, 12))
			if not _demo:
				beds_passed += 1
				add_score(BED_POINTS + mini(streak, STREAK_CAP) * STREAK_POINTS)
	if walker >= 1.0 and not _demo:
		rows += 1
		row += 1
		add_score(ROW_POINTS, "溜過去了！+%d" % ROW_POINTS)
		sound(84)
		walker = 0.0
		speed = 0.0
		_plan_row()


func _caught(index: int) -> void:
	pillow_at = clock
	thrower = index
	streak = 0
	speed = 0.0
	caught += 1
	walker = maxf(0.0, walker - KNOCK_BACK)
	sound(48)
	sound(41)
	# The first pillow of a round is a free look.
	funny_fail("被枕頭砸中了！", caught > 1)
	# The thrower lies back down and snores again a little later.
	var guest: Dictionary = guests[index]
	guest.peeks = (guest.peeks as Array).filter(func(peek: float) -> bool: return peek > clock + PILLOW_SECONDS)
	guest.cycle = _cycle(clock + PILLOW_SECONDS, false)


func _reset_room() -> void:
	walker = 0.0
	speed = 0.0
	row = 1
	pillow_at = -99.0
	thrower = -1
	beds_passed = 0
	rows = 0
	caught = 0
	streak = 0
	_right = 0
	_left = 0
	_plan_row()


func _plan_row() -> void:
	guests.clear()
	for index in BEDS:
		var x := lerpf(0.16, 0.84, float(index) / (BEDS - 1))
		var fake := not _demo and heat() >= float(variant.get("fake_heat", FAKE_HEAT)) and rng.randf() < float(variant.get("fake", 0.25))
		var guest := {"x": x, "cycle": _cycle(clock, index == 0), "peeks": [], "passed": false, "fake": fake}
		if fake:
			# Peeks land in the middle of snoring spells, now and then.
			for spell: Array in guest.cycle:
				if str(spell[2]) == "snore" and float(spell[1]) - float(spell[0]) > 1.2 and rng.randf() < 0.6:
					guest.peeks.append(rng.randf_range(float(spell[0]) + 0.3, float(spell[1]) - PEEK - 0.1))
		guests.append(guest)


## Alternating snoring and quiet spells from `start` for the rest of the
## round, shorter and more uneven later. `snore_first` starts with a snore.
func _cycle(start: float, snore_first: bool) -> Array:
	var spells: Array = []
	var at := start
	var snoring := snore_first or rng.randf() < 0.6
	var shorter := float(variant.get("snore", 1.0))
	while at < start + 70.0:
		var t := clampf((at - clock + play_time) / maxf(1.0, round_seconds), 0.0, 1.0)
		var length := 0.0
		if snoring:
			var span := SNORE_FIRST.lerp(SNORE_LAST, t)
			length = rng.randf_range(span.x, span.y) * shorter
		else:
			var span := QUIET_FIRST.lerp(QUIET_LAST, t)
			length = rng.randf_range(span.x, span.y)
		spells.append([at, at + length, "snore" if snoring else "quiet"])
		at += length
		snoring = not snoring
	return spells
