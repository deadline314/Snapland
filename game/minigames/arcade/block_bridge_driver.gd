extends "res://game/minigames/arcade/arcade_driver.gd"
## 積木拱橋: the toy railway needs a bridge pier. A wooden block swings to and
## fro on a long pendulum hook; press to let it go and it drops straight onto
## the pier. Whatever hangs over the edge of the block below is sawn off and
## tumbles away, so the next block is that much narrower. Eight blocks finish
## a pier: an arch is laid on top, a toy train toots across and a fresh pier
## starts. Late in the round cylinders and triangle keystones swing in; a
## keystone caps the pier early. Miss the pier altogether and the whole stack
## dominoes over onto the traveller, who ends up wearing the top block.
## Rules only: the picture lives in block_bridge_view.gd.
##
## Positions run from 0 (left) to 1 (right) across the stage.

const View = preload("res://game/minigames/arcade/block_bridge_view.gd")
const PIER_X := 0.5
const BASE_WIDTH := 0.24
const PIER_BLOCKS := 8
## The hook swings PIER_X +- this far.
const SWING := 0.3
## Swing speed in radians per second, at the start and at the end of play.
const OMEGA_FIRST := 2.2
const OMEGA_LAST := 4.4
## Each block already on the pier speeds the swing up a little more.
const OMEGA_PER_BLOCK := 0.06
const ASSIST_SWING := 1.25
const FALL_SECONDS := 0.22
## A new block is hooked on this long after the last one lands.
const REHOOK_SECONDS := 0.25
## Closer than this to the block below counts as dead on: nothing is cut.
const PERFECT := 0.012
## Thinner than this a block cannot stand; it falls off and topples the pier.
const MIN_WIDTH := 0.02
## Three dead-on drops in a row glue a little width back on.
const REGROW := 0.02
const BLOCK_POINTS := 10
const HEIGHT_POINTS := 2
const PERFECT_POINTS := 10
const CYLINDER_POINTS := 5
const PIER_POINTS := 40
const KEYSTONE_POINTS := 20
const ARCH_SECONDS := 1.6
const TOPPLE_SECONDS := 1.6
const SHAPES_HEAT := 0.45
const KEYSTONE_HEAT := 0.6

## The hook's swing phase; its x is PIER_X + swing * sin(phase).
var phase := 0.0
## The block on the hook: {shape, width, paint}; empty while one is falling.
var hooked: Dictionary = {}
## The falling block: {shape, width, paint, x, at}; empty when none.
var falling: Dictionary = {}
## Blocks on the pier, bottom first: {shape, width, paint, x, at, perfect}.
var pier: Array[Dictionary] = []
## Sawn-off ends tumbling away: {x, width, side, paint, shape, at, y}.
var offcuts: Array[Dictionary] = []
## The last toppled pier, kept for its fall: {blocks, at}.
var toppled: Dictionary = {}
var arch_at := -99.0
var topple_at := -99.0
var piers := 0
var placed := 0
var perfects := 0
var streak := 0
var topples := 0
var keystones := 0

var _rehook_at := 0.0
var _paint := 0
var _demo := false


func _init() -> void:
	verb = "看準了放下積木，替火車疊橋墩！"
	hint = [["空白鍵", "放下積木"]]
	round_seconds = 45.0
	thresholds = [300, 700, 1050]
	verdicts = [
		"火車決定改走地下道。",
		"銅牌！橋墩有點歪，火車閉著眼睛過。",
		"銀牌！積木們排得整整齊齊。",
		"金牌！鐵路局頒你榮譽造橋師傅。",
	]
	variants = [
		{"id": "standard", "label": "標準橋墩"},
		{"id": "wide", "label": "大塊積木", "width": 1.25, "omega": 1.15},
		{"id": "breeze", "label": "午後微風", "breeze": true},
	]
	score_label = "造橋得分"
	view_script = View


func _begin_round(_chosen: Dictionary) -> void:
	phase = 0.0
	pier.clear()
	offcuts.clear()
	falling = {}
	toppled = {}
	arch_at = -99.0
	topple_at = -99.0
	piers = 0
	placed = 0
	perfects = 0
	streak = 0
	topples = 0
	keystones = 0
	_paint = 0
	_demo = true
	_rehook_at = 0.0
	_hook_next()


func _warm_up(delta: float) -> void:
	_swing(delta)
	_settle()
	# The countdown lets the first block go once it swings over the pier.
	if pier.is_empty() and falling.is_empty() and not hooked.is_empty() and absf(hook_x() - PIER_X) < 0.01 and clock > 0.6:
		_let_go()


func _go() -> void:
	_demo = false
	pier.clear()
	offcuts.clear()
	falling = {}
	streak = 0
	_hook_next()


func _tick(delta: float) -> void:
	_swing(delta)
	_settle()


func _press(button: StringName) -> void:
	if button == &"action" or button == &"down" or button == &"second":
		_let_go()


func _round_over() -> void:
	falling = {}


func _snapshot(into: Dictionary) -> void:
	into.hook_x = hook_x()
	into.swing_angle = cos(phase)
	into.hooked = hooked
	into.falling = falling
	into.pier = pier
	into.offcuts = offcuts
	into.toppled = toppled
	into.arch_at = arch_at
	into.topple_at = topple_at
	into.topple_seconds = TOPPLE_SECONDS
	into.arch_seconds = ARCH_SECONDS
	into.fall_seconds = FALL_SECONDS
	into.pier_x = PIER_X
	into.base_width = base_width()
	into.pier_blocks = PIER_BLOCKS
	into.streak = streak
	into.piers = piers


func hook_x() -> float:
	return PIER_X + SWING * sin(phase)


func omega() -> float:
	var speed := lerpf(OMEGA_FIRST, OMEGA_LAST, heat()) + OMEGA_PER_BLOCK * pier.size()
	# Assist slows the swing a little; a much slower one would only mean fewer blocks.
	return speed * float(variant.get("omega", 1.0)) / (ASSIST_SWING if assisted else 1.0)


func base_width() -> float:
	return BASE_WIDTH * float(variant.get("width", 1.0))


## The width of the top of the pier (the base when it is empty) and its centre.
func top() -> Vector2:
	if pier.is_empty():
		return Vector2(PIER_X, base_width())
	return Vector2(float(pier.back().x), float(pier.back().width))


func busy() -> bool:
	return clock - arch_at < ARCH_SECONDS or clock - topple_at < TOPPLE_SECONDS


func perfect_reach() -> float:
	return window(PERFECT)


func _swing(delta: float) -> void:
	if busy():
		return
	var speed := omega()
	if bool(variant.get("breeze", false)):
		# A breeze puffs the swing faster and slower.
		speed *= 1.0 + 0.35 * sin(clock * 0.9)
	phase = fposmod(phase + speed * delta, TAU)


func _let_go() -> void:
	if hooked.is_empty() or not falling.is_empty() or busy():
		return
	falling = hooked.duplicate()
	falling.x = hook_x()
	falling.at = clock
	hooked = {}
	sound(60)


func _settle() -> void:
	if not falling.is_empty() and clock - float(falling.at) >= FALL_SECONDS:
		_land(falling)
		falling = {}
		_rehook_at = clock + REHOOK_SECONDS
	if hooked.is_empty() and falling.is_empty() and clock >= _rehook_at and not busy():
		if not pier.is_empty() and _pier_done():
			pier.clear()
		_hook_next()
	var kept: Array[Dictionary] = []
	for cut in offcuts:
		if clock - float(cut.at) < 1.0:
			kept.append(cut)
	offcuts.assign(kept)


func _pier_done() -> bool:
	return pier.size() >= PIER_BLOCKS or str(pier.back().shape) == "keystone"


func _land(block: Dictionary) -> void:
	var below := top()
	var x := float(block.x)
	var width := float(block.width)
	var left := maxf(x - width * 0.5, below.x - below.y * 0.5)
	var right := minf(x + width * 0.5, below.x + below.y * 0.5)
	if right - left < MIN_WIDTH:
		_topple(block)
		return
	var dead_on := absf(x - below.x) <= perfect_reach()
	if dead_on:
		x = below.x
		streak += 1
		width = minf(width, below.y)
		if streak % 3 == 0:
			width = minf(base_width(), width + REGROW)
	else:
		streak = 0
		# Saw off what hangs over either side.
		if x - width * 0.5 < left - 0.0005:
			offcuts.append({"x": (x - width * 0.5 + left) * 0.5, "width": left - (x - width * 0.5), "side": -1, "paint": block.paint, "shape": block.shape, "at": clock, "row": pier.size()})
		if x + width * 0.5 > right + 0.0005:
			offcuts.append({"x": (right + x + width * 0.5) * 0.5, "width": x + width * 0.5 - right, "side": 1, "paint": block.paint, "shape": block.shape, "at": clock, "row": pier.size()})
		x = (left + right) * 0.5
		width = right - left
	var landed := {"shape": block.shape, "width": width, "paint": block.paint, "x": x, "at": clock, "perfect": dead_on}
	pier.append(landed)
	sound(67 + mini(pier.size(), 12) if dead_on else 55 + mini(pier.size(), 8))
	if _demo:
		return
	placed += 1
	var points := BLOCK_POINTS + HEIGHT_POINTS * pier.size()
	if str(block.shape) == "cylinder":
		points += CYLINDER_POINTS
	if dead_on:
		perfects += 1
		points += PERFECT_POINTS
		add_score(points, "剛好！+%d" % points)
	else:
		add_score(points)
	if str(block.shape) == "keystone":
		keystones += 1
		_finish_pier(KEYSTONE_POINTS)
	elif pier.size() >= PIER_BLOCKS:
		_finish_pier(0)


func _finish_pier(extra: int) -> void:
	piers += 1
	arch_at = clock
	streak = 0
	var points := PIER_POINTS + extra
	add_score(points, "通車！+%d" % points)
	sound(84)
	sound(88)


func _topple(block: Dictionary) -> void:
	var fallen: Array = pier.duplicate()
	fallen.append(block)
	toppled = {"blocks": fallen, "at": clock}
	topple_at = clock
	pier.clear()
	streak = 0
	sound(48)
	sound(43)
	if _demo:
		return
	topples += 1
	# The first topple of a round is a free look at the domino.
	funny_fail("嘩啦啦！", topples > 1)


func _hook_next() -> void:
	if not pier.is_empty() and _pier_done():
		return
	var width := top().y
	var shape := "block"
	if heat() >= SHAPES_HEAT and not _demo:
		var roll := rng.randf()
		if heat() >= KEYSTONE_HEAT and pier.size() >= 3 and roll < 0.18:
			shape = "keystone"
		elif roll < 0.45:
			shape = "cylinder"
	_paint = (_paint + 1 + rng.randi() % 3) % 4
	hooked = {"shape": shape, "width": width, "paint": _paint}
