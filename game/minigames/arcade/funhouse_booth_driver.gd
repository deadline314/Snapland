extends "res://game/minigames/arcade/arcade_driver.gd"
## 哈哈鏡大頭貼: three bands (hair, eyes, mouth) slide through a funhouse mirror;
## one press stops each in turn to rebuild the wanted face. Rules only: the
## picture lives in funhouse_booth_view.gd.

const Faces = preload("res://game/minigames/arcade/funhouse_faces.gd")
const View = preload("res://game/minigames/arcade/funhouse_booth_view.gd")
const REELS := 3
const OPTIONS := Faces.OPTIONS
const PART_POINTS := 10
const PERFECT_BONUS := 30
## Parts passing the frame per second at the first and the last second of play.
const SLOW := 1.9
const FAST := 3.7
## Each band drifts at its own rate so the three never line up for free.
const REEL_RATES: Array[float] = [1.0, 1.16, 0.9]
## A clean print is quick; a wonky one takes its time sliding out for the laugh.
const PRINT_SECONDS := 0.8
const WONKY_PRINT_SECONDS := 1.6
## Heat (0..1 through the round) at which one band, then every band, hides a decoy.
const DECOY_HEATS: Array[float] = [0.28, 0.6]
const PRINT_HISTORY := 5

var target: Array[int] = [0, 0, 0]
var bands: Array = [[], [], []]
var positions: Array[float] = [0.0, 0.0, 0.0]
var directions: Array[int] = [1, 1, 1]
var picked: Array[int] = [-1, -1, -1]
var stop_at: Array[float] = [-99.0, -99.0, -99.0]
## Bands already stopped on the current face, top to bottom.
var stopped := 0
## Seconds left showing the finished print; bands rest meanwhile.
var printing := 0.0
var faces_done := 0
var perfect_faces := 0
## Newest last: {"parts", "matched", "at"}.
var prints: Array[Dictionary] = []
var face_at := 0.0


func _init() -> void:
	verb = "看左邊的臉，按一下停一格！"
	hint = [["空白鍵", "停住轉輪"]]
	round_seconds = 45.0
	thresholds = [120, 240, 360]
	verdicts = [
		"這張臉連哈哈鏡都笑到起霧。",
		"銅牌！臉是拼出來了，就是有點隨緣。",
		"銀牌！攝影師說再一張就封面。",
		"金牌！連鏡子都以為在照本人。",
	]
	variants = [
		{"id": "classic", "label": "三輪同向", "reverse": false, "peek": 0.0},
		{"id": "reverse", "label": "中輪逆轉", "reverse": true, "peek": 0.0},
		{"id": "peek", "label": "只看一眼", "reverse": false, "peek": 1.6},
	]
	score_label = "大頭貼得分"
	view_script = View


func _begin_round(chosen: Dictionary) -> void:
	directions[1] = -1 if bool(chosen.get("reverse", false)) else 1
	faces_done = 0
	perfect_faces = 0
	prints.clear()
	_next_face()


func _warm_up(delta: float) -> void:
	_spin(delta)


func _go() -> void:
	# The first wanted face is read from "go", not from the countdown.
	face_at = clock


func _tick(delta: float) -> void:
	if printing > 0.0:
		printing -= delta
		if printing <= 0.0:
			_next_face()
		return
	_spin(delta)


func _press(button: StringName) -> void:
	if button != &"action" or printing > 0.0 or stopped >= REELS:
		return
	var reel := stopped
	var band: Array = bands[reel]
	positions[reel] = roundf(positions[reel])
	picked[reel] = band[posmod(int(positions[reel]), band.size())]
	stop_at[reel] = clock
	stopped += 1
	if picked[reel] == target[reel]:
		add_score(PART_POINTS)
		sound(72 + reel * 4)
	else:
		sound(58)
	if stopped == REELS:
		_print_face()


func _snapshot(into: Dictionary) -> void:
	into.target = target
	into.bands = bands
	into.positions = positions
	into.directions = directions
	into.picked = picked
	into.stop_at = stop_at
	into.stopped = stopped
	into.printing = printing
	into.prints = prints
	into.faces_done = faces_done
	into.face_at = face_at
	into.target_hidden = target_hidden()
	into.decoy_reels = decoy_reels()


## Parts per second for one band right now.
func speed(reel: int) -> float:
	return pace(lerpf(SLOW, FAST, heat())) * REEL_RATES[reel]


## How many bands hide a decoy at this point of the round.
func decoy_reels() -> int:
	var count := 0
	for line in DECOY_HEATS:
		if heat() >= line:
			count += 1
	return 0 if count == 0 else (1 if count == 1 else REELS)


## The "只看一眼" variant turns the wanted card face down after a moment.
func target_hidden() -> bool:
	var peek := float(variant.get("peek", 0.0))
	return peek > 0.0 and stage == "play" and printing <= 0.0 and clock - face_at > window(peek)


## The part currently in the frame of a band.
func part_in_frame(reel: int) -> int:
	var band: Array = bands[reel]
	return band[posmod(roundi(positions[reel]), band.size())]


func _spin(delta: float) -> void:
	for reel in range(stopped, REELS):
		positions[reel] += directions[reel] * speed(reel) * delta


func _next_face() -> void:
	stopped = 0
	printing = 0.0
	face_at = clock
	var decoys := decoy_reels()
	var decoy_reel := rng.randi() % REELS
	for reel in REELS:
		target[reel] = rng.randi() % OPTIONS
		picked[reel] = -1
		stop_at[reel] = -99.0
		var band: Array[int] = []
		for id in OPTIONS:
			band.append(id)
		for index in range(band.size() - 1, 0, -1):
			var other := rng.randi() % (index + 1)
			var held := band[index]
			band[index] = band[other]
			band[other] = held
		if decoys == REELS or (decoys == 1 and reel == decoy_reel):
			band.insert(rng.randi() % (band.size() + 1), target[reel] + OPTIONS)
		bands[reel] = band
		# Start well away from the wanted part, each band by its own amount, so
		# nothing is free and stopping one band says nothing about the next.
		var away := rng.randf_range(1.5, band.size() - 0.8)
		positions[reel] = band.find(target[reel]) - directions[reel] * away


func _print_face() -> void:
	var matched := 0
	for reel in REELS:
		if picked[reel] == target[reel]:
			matched += 1
	faces_done += 1
	prints.append({"parts": picked.duplicate(), "matched": matched, "at": clock})
	if prints.size() > PRINT_HISTORY:
		prints.pop_front()
	printing = PRINT_SECONDS
	if matched == REELS:
		perfect_faces += 1
		add_score(PERFECT_BONUS, "完美！")
		sound(84)
	elif matched == REELS - 1:
		say("差一格！", true)
	else:
		printing = WONKY_PRINT_SECONDS
		# The very first face is a free look at how the booth works.
		funny_fail("怪臉出爐！", faces_done > 1)
