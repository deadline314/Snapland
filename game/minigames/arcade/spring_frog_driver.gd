extends "res://game/minigames/arcade/arcade_driver.gd"
## 彈簧青蛙: toy blocks ride a conveyor toward the toy bin. Hold the button to
## wind the tin frog, let go to hop ahead onto the next block; the longer the
## wind, the longer the hop. Landing near a block's middle scores more, skipping
## a block scores more still. Miss and the frog's key unwinds on the belt until
## the crane puts it back. Rules only: the picture lives in spring_frog_view.gd.
## Lengths are canvas pixels.

const View = preload("res://game/minigames/arcade/spring_frog_view.gd")
## Top of the belt and height of a block: the frog stands at BELT_Y - BLOCK_H.
const BELT_Y := 560.0
const BLOCK_H := 64.0
## Blocks whose middle passes this line tip into the toy bin.
const DROP_X := 150.0
const SPAWN_X := 1400.0
## Blocks come out of a tunnel here; a hop that comes down past it hits the wall.
const FAR_X := 1110.0
const MIN_HOP := 60.0
const MAX_HOP := 440.0
## Seconds of holding for a full wind; the frog cannot wind past full.
const CHARGE_SECONDS := 1.0
const HOP_TIME := 0.5
## Extra reach either side of a block's top that still counts as landed.
const EDGE := 8.0
const SPEED_START := 80.0
const SPEED_END := 175.0
const GAP_START := Vector2(30, 80)
const GAP_END := Vector2(100, 190)
const WIDTHS: Array[float] = [88.0, 104.0, 120.0, 136.0, 152.0]
const TINY_WIDTHS: Array[float] = [64.0, 72.0, 80.0, 88.0, 104.0]
## Heat (0..1 through the round) from which retracting blocks and springboards join.
const RETRACT_HEAT := 0.25
const RETRACT_CHANCE := 0.3
const SPRING_HEAT := 0.4
const SPRING_CHANCE := 0.18
## A retracting block: up, sinking, down, rising, in seconds.
const RETRACT_CYCLE: Array[float] = [1.6, 0.35, 0.45, 0.25]
const LAND_POINTS := 5
const AIM_POINTS := 15
const SKIP_POINTS := 10
const STREAK_POINTS := 2
const MAX_STREAK := 5
const SPRING_POINTS := 10
## Seconds the frog spins on the belt after a miss, then the crane's lift.
const UNWIND_SECONDS := 1.3
const CLAW_SECONDS := 0.6
const CLAW_X := 520.0
const PAINTS := 4
const DEMO_WIND := 0.55

## {id, x, w, kind ("plain", "retract", "spring"), paint, letter, phase}
var blocks: Array[Dictionary] = []
var speed := SPEED_START
var belt_travel := 0.0
## "sit", "wind", "hop", "fall" (missed: unwinding on the belt or in the bin), "claw".
var frog_state := "sit"
var frog_x := 0.0
var frog_y := 0.0
var frog_block := -1
var frog_offset := 0.0
var charge := 0.0
var hop_from := Vector2.ZERO
var hop_to := Vector2.ZERO
var hop_at := -99.0
var hop_sprung := false
## The block the current hop started from.
var hop_block := -1
var landed_at := -99.0
var landed_aim := 0.0
var fall_at := -99.0
var fall_into_bin := false
var claw_from := Vector2.ZERO
var claw_at := -99.0
var streak := 0
var landings := 0
var misses := 0
var springs_used := 0
var retracts_seen := 0

var _next_id := 0
var _holding := false
var _demo := false
var _demo_goal := 0.0


func _init() -> void:
	verb = "按住上發條，放開跳上下一塊積木！"
	hint = [["空白鍵", "按住上發條，放開就跳"]]
	round_seconds = 45.0
	thresholds = [200, 450, 660]
	verdicts = [
		"青蛙決定在輸送帶上躺平。",
		"銅牌！跳是跳上去了，腳還在抖。",
		"銀牌！積木一塊一塊都被你踩過。",
		"金牌！玩具城的青蛙跳遠冠軍。",
	]
	variants = [
		{"id": "standard", "label": "標準輸送帶", "worth": 1.0, "speed": 1.0},
		{"id": "tiny", "label": "迷你積木", "worth": 1.15, "speed": 1.0, "tiny": true},
		{"id": "springs", "label": "彈簧派對", "worth": 1.0, "speed": 1.0, "springs": true},
		{"id": "rush", "label": "加速輸送帶", "worth": 1.0, "speed": 1.22},
	]
	score_label = "跳躍得分"
	view_script = View


func _begin_round(_chosen: Dictionary) -> void:
	blocks.clear()
	_next_id = 0
	belt_travel = 0.0
	streak = 0
	landings = 0
	misses = 0
	springs_used = 0
	retracts_seen = 0
	speed = _belt_speed()
	_add_block(380.0, 152.0, "plain")
	while _last_edge() < SPAWN_X:
		_spawn()
	_seat(blocks[0], 0.0)
	_holding = false
	hop_at = -99.0
	landed_at = -99.0
	fall_at = -99.0
	claw_at = -99.0
	# The countdown winds the frog and hops it onto the next block by itself.
	_demo = true
	_demo_goal = -1.0


func _warm_up(delta: float) -> void:
	speed = _belt_speed() * 0.5
	_run(delta)
	if frog_state == "sit" and clock >= DEMO_WIND and hop_at < 0.0:
		frog_state = "wind"
		_demo_goal = clampf((_aim_distance(_block_after(frog_x)) - MIN_HOP) / (MAX_HOP - MIN_HOP), 0.0, 1.0)
	if frog_state == "wind":
		charge = minf(_demo_goal, charge + delta / CHARGE_SECONDS)
		if charge >= _demo_goal:
			_hop(lerpf(MIN_HOP, MAX_HOP, charge), false)


func _go() -> void:
	_demo = false
	if frog_state == "wind":
		frog_state = "sit"
		charge = 0.0


func _tick(delta: float) -> void:
	speed = _belt_speed()
	_run(delta)


func _press(button: StringName) -> void:
	if button != &"action":
		return
	_holding = true
	if frog_state == "sit":
		frog_state = "wind"
		charge = 0.0
		sound(60)


func _release(button: StringName) -> void:
	if button != &"action":
		return
	_holding = false
	if frog_state == "wind":
		_hop(lerpf(MIN_HOP, MAX_HOP, charge), false)


func _round_over() -> void:
	if frog_state == "wind":
		frog_state = "sit"
		charge = 0.0


func _snapshot(into: Dictionary) -> void:
	var drawn: Array = []
	for block in blocks:
		drawn.append({"x": block.x, "w": block.w, "kind": block.kind, "paint": block.paint, "letter": block.letter,
			"sink": sink(block), "warn": _warning(block), "ridden": int(block.id) == frog_block and _riding()})
	into.blocks = drawn
	into.belt_travel = belt_travel
	into.speed = speed
	into.frog = {"state": frog_state, "x": frog_x, "y": frog_y, "charge": charge, "hop_at": hop_at, "hop_from": hop_from,
		"hop_to": hop_to, "sprung": hop_sprung, "landed_at": landed_at, "aim": landed_aim, "fall_at": fall_at,
		"bin": fall_into_bin, "claw_at": claw_at, "claw_from": claw_from}
	into.streak = streak
	into.top_y = BELT_Y - BLOCK_H
	into.belt_y = BELT_Y
	into.drop_x = DROP_X
	into.demo = _demo


## Seconds of holding for a full wind; assist winds slower, so a hop is easier to judge.
func wind_seconds() -> float:
	return window(CHARGE_SECONDS)


## 0 standing up, 1 fully sunk into the belt. A block never sinks under the frog.
func sink(block: Dictionary) -> float:
	if str(block.kind) != "retract" or (int(block.id) == frog_block and _riding()):
		return 0.0
	var t := fposmod(clock - float(block.phase), RETRACT_CYCLE[0] + RETRACT_CYCLE[1] + RETRACT_CYCLE[2] + RETRACT_CYCLE[3])
	if t < RETRACT_CYCLE[0]:
		return 0.0
	t -= RETRACT_CYCLE[0]
	if t < RETRACT_CYCLE[1]:
		return t / RETRACT_CYCLE[1]
	t -= RETRACT_CYCLE[1]
	if t < RETRACT_CYCLE[2]:
		return 1.0
	return 1.0 - (t - RETRACT_CYCLE[2]) / RETRACT_CYCLE[3]


## How far a hop released now must go to come down on the middle of `block`.
func _aim_distance(block: Dictionary) -> float:
	if block.is_empty():
		return MIN_HOP
	return float(block.x) - frog_x - speed * HOP_TIME


func block_by_id(id: int) -> Dictionary:
	for block in blocks:
		if int(block.id) == id:
			return block
	return {}


## The first block wholly ahead of `x`.
func _block_after(x: float) -> Dictionary:
	for block in blocks:
		if float(block.x) - float(block.w) * 0.5 > x:
			return block
	return {}


func _riding() -> bool:
	return frog_state == "sit" or frog_state == "wind" or (frog_state == "claw" and clock - claw_at >= CLAW_SECONDS * 0.5)


func _warning(block: Dictionary) -> bool:
	if str(block.kind) != "retract" or sink(block) > 0.0:
		return false
	var t := fposmod(clock - float(block.phase), RETRACT_CYCLE[0] + RETRACT_CYCLE[1] + RETRACT_CYCLE[2] + RETRACT_CYCLE[3])
	return t > RETRACT_CYCLE[0] - 0.45 and t < RETRACT_CYCLE[0]


func _belt_speed() -> float:
	return lerpf(SPEED_START, SPEED_END, heat()) * float(variant.get("speed", 1.0))


func _last_edge() -> float:
	if blocks.is_empty():
		return 0.0
	return float(blocks[-1].x) + float(blocks[-1].w) * 0.5


func _add_block(x: float, w: float, kind: String) -> void:
	var look := rng.randi()
	blocks.append({"id": _next_id, "x": x, "w": w, "kind": kind, "paint": look % PAINTS, "letter": (look / PAINTS) % 4,
		"phase": rng.randf() * 2.0})
	_next_id += 1


func _spawn() -> void:
	var gaps := GAP_START.lerp(GAP_END, heat())
	var gap := rng.randf_range(gaps.x, gaps.y)
	var widths := TINY_WIDTHS if bool(variant.get("tiny", false)) else WIDTHS
	var w := widths[rng.randi() % widths.size()]
	var kind := "plain"
	var roll := rng.randf()
	var spring_rate := 0.24 if bool(variant.get("springs", false)) else (SPRING_CHANCE if heat() >= SPRING_HEAT else 0.0)
	# Never two specials in a row, and the first blocks of a round are plain.
	if _next_id > 3 and str(blocks[-1].kind) == "plain":
		if roll < spring_rate:
			kind = "spring"
		elif heat() >= RETRACT_HEAT and roll < spring_rate + RETRACT_CHANCE:
			kind = "retract"
			retracts_seen += 1
	_add_block(_last_edge() + gap + w * 0.5, w, kind)


## Move the belt and everything on it, then settle hops and falls that are due.
func _run(delta: float) -> void:
	var shift := speed * delta
	belt_travel += shift
	for block in blocks:
		block.x = float(block.x) - shift
	while not blocks.is_empty() and float(blocks[0].x) + float(blocks[0].w) * 0.5 < -40.0:
		if int(blocks[0].id) == frog_block and _riding():
			break
		blocks.pop_front()
	while _last_edge() < SPAWN_X:
		_spawn()
	match frog_state:
		"sit", "wind":
			var block := block_by_id(frog_block)
			frog_x = float(block.x) + frog_offset
			frog_y = BELT_Y - BLOCK_H
			if frog_state == "wind" and not _demo:
				charge = minf(1.0, charge + delta / wind_seconds())
			if float(block.x) < DROP_X:
				_miss(true)
		"hop":
			var t := clampf((clock - hop_at) / HOP_TIME, 0.0, 1.0)
			frog_x = lerpf(hop_from.x, hop_to.x, t)
			frog_y = hop_from.y - (4.0 * t * (1.0 - t)) * (70.0 + 0.22 * absf(hop_to.x - hop_from.x)) * (1.5 if hop_sprung else 1.0)
			if t >= 1.0:
				_land()
		"fall":
			var since := clock - fall_at
			if fall_into_bin:
				frog_y = minf(BELT_Y + 40.0, frog_y + delta * 520.0)
			else:
				frog_x -= shift
				frog_y = minf(BELT_Y, frog_y + delta * 700.0)
			if since >= UNWIND_SECONDS:
				_send_claw()
		"claw":
			var block := block_by_id(frog_block)
			var t := clampf((clock - claw_at) / CLAW_SECONDS, 0.0, 1.0)
			var goal := Vector2(float(block.x), BELT_Y - BLOCK_H)
			var lift := claw_from.lerp(goal, t)
			frog_x = lift.x
			frog_y = lift.y - sin(t * PI) * 120.0
			if t >= 1.0:
				_seat(block, 0.0)


func _seat(block: Dictionary, offset: float) -> void:
	frog_block = int(block.id)
	frog_offset = offset
	frog_x = float(block.x) + offset
	frog_y = BELT_Y - BLOCK_H
	charge = 0.0
	frog_state = "wind" if _holding and stage == "play" else "sit"


func _hop(distance: float, sprung: bool) -> void:
	frog_state = "hop"
	hop_from = Vector2(frog_x, BELT_Y - BLOCK_H)
	hop_to = Vector2(frog_x + distance, BELT_Y - BLOCK_H)
	hop_at = clock
	hop_sprung = sprung
	hop_block = frog_block
	frog_block = -1
	sound(72 if sprung else 67)


func _land() -> void:
	var reach := window(EDGE)
	var target: Dictionary = {}
	if hop_to.x > FAR_X:
		_miss(false)
		say("撞到隧道了！", false)
		return
	for block in blocks:
		if absf(hop_to.x - float(block.x)) <= float(block.w) * 0.5 + reach and sink(block) < 0.5:
			target = block
			break
	if target.is_empty():
		_miss(false)
		return
	var start := hop_from.x
	var half := float(target.w) * 0.5
	var aim := clampf(1.0 - absf(hop_to.x - float(target.x)) / half, 0.0, 1.0)
	var skipped := 0
	for block in blocks:
		var middle := float(block.x)
		if middle - float(block.w) * 0.5 > start and middle < float(target.x) and int(block.id) != int(target.id):
			skipped += 1
	var same := int(target.id) == hop_block
	_seat(target, clampf(hop_to.x - float(target.x), -half + 6.0, half - 6.0))
	landed_at = clock
	landed_aim = aim
	sound(76 if aim > 0.75 else 71)
	if _demo:
		return
	if same:
		# Hopping in place along one block is safe but scores nothing.
		say("原地跳", false)
		return
	landings += 1
	var worth := float(variant.get("worth", 1.0))
	var points := roundi((LAND_POINTS + AIM_POINTS * aim + SKIP_POINTS * skipped + STREAK_POINTS * mini(streak, MAX_STREAK)
		+ (SPRING_POINTS if hop_sprung else 0)) * worth)
	streak += 1
	var word := "+%d" % points
	if skipped > 0:
		word = "跳%s格！+%d" % ["兩" if skipped == 1 else "好幾", points]
	elif aim > 0.75:
		word = "正中！+%d" % points
	add_score(points, word)
	if str(target.kind) == "spring":
		# The springboard throws the frog onto the middle of the block after it.
		springs_used += 1
		var next := _block_after(float(target.x) + half)
		if not next.is_empty():
			say("彈！", true)
			_hop(_aim_distance(next), true)


func _miss(into_bin: bool) -> void:
	frog_state = "fall"
	fall_at = clock
	fall_into_bin = into_bin
	frog_block = -1
	charge = 0.0
	streak = 0
	sound(43)
	if _demo:
		return
	misses += 1
	var word := "掉進玩具箱！" if into_bin else "發條鬆掉了！"
	# The first miss of a round is a free look at what happens.
	funny_fail(word, misses > 1)


func _send_claw() -> void:
	var best: Dictionary = {}
	for block in blocks:
		if str(block.kind) == "plain" and float(block.x) > DROP_X + 160.0 and (best.is_empty() or absf(float(block.x) - CLAW_X) < absf(float(best.x) - CLAW_X)):
			best = block
	if best.is_empty():
		best = blocks[-1]
	frog_state = "claw"
	claw_at = clock
	claw_from = Vector2(frog_x, frog_y)
	frog_block = int(best.id)
	frog_offset = 0.0
	sound(64)
