extends "res://game/minigames/arcade/arcade_driver.gd"
## 風箏追風: on the kite terrace the traveller flies a kite. A big arrow shows
## where the wind is blowing; hold ← or → to pull the line and swing the kite
## over into the wind, where it climbs. Out of the wind it sinks, and a kite that
## sinks all the way stalls: the line wraps round the traveller and the next
## gust drags them up into the sky before dropping them back on the deck. Cloud
## rings drift down through the sky; fly the kite through them for points. The
## wind shifts more and more often, and later a gust of turbulence swings the
## arrow the wrong way first before it settles where the wind really goes.
## Rules only: the picture lives in kite_wind_view.gd.
##
## Across the sky runs 0 (left) to 1 (right); the kite's height runs 0 (down on
## the deck) to 1 (as high as the line goes); ring heights run 0 (top of the
## sky) to 1 (the deck).

const View = preload("res://game/minigames/arcade/kite_wind_view.gd")
const WINDOW_HALF := 0.12
const SPEED := 0.85
const PULL := 5.0
const CLIMB := 0.45
const SINK := 0.32
const RING_HALF := 0.06
const RING_SPEED := 0.32
const RING_POINTS := 15
const COMBO_STEP := 3
const COMBO_CAP := 6
## Seconds between wind shifts, at the start and at the end of play.
const SHIFT_FIRST := 4.6
const SHIFT_LAST := 2.0
const WARN := 0.6
const FOLLOW := 1.6
const FAKE_HEAT := 0.4
const FAKE_SECONDS := 0.55
const RING_GAP_FIRST := 1.2
const RING_GAP_LAST := 0.7
const DRAG_SECONDS := 2.2

var kite_x := 0.5
var kite_h := 0.6
var kite_vx := 0.0
## Where the wind really blows (the middle of the window) and where it is heading.
var wind_x := 0.5
var wind_target := 0.5
## Where the arrow points; during turbulence it points the wrong way for a moment.
var arrow_x := 0.5
var arrow_at := -99.0
var fake_until := -99.0
## Cloud rings: {id, x, y, state ("drift", "caught", "missed"), at}.
var rings: Array[Dictionary] = []
var stall_at := -99.0
var stalls := 0
var combo := 0
var best_combo := 0
var caught := 0
var missed := 0
var pulling := 0

var _serial := 0
var _shift_due := 0.0
var _ring_due := 0.0
var _demo := false


func _init() -> void:
	verb = "左右拉線，讓風箏一直待在風裡，穿過雲圈！"
	hint = [["← →", "拉風箏線"]]
	round_seconds = 45.0
	thresholds = [180, 380, 500]
	verdicts = [
		"風箏決定自己去旅行。",
		"銅牌！風箏還算聽話。",
		"銀牌！風都跟著你的線走。",
		"金牌！雲圈排隊等你的風箏穿過。",
	]
	variants = [
		{"id": "breeze", "label": "午後風"},
		{"id": "gusty", "label": "亂流天", "fake": 0.0},
		{"id": "rings", "label": "雲圈大會", "rings": 0.7},
	]
	score_label = "風箏得分"
	view_script = View


func _begin_round(_chosen: Dictionary) -> void:
	kite_x = 0.5
	kite_h = 0.6
	kite_vx = 0.0
	wind_x = 0.5
	wind_target = 0.5
	arrow_x = 0.5
	arrow_at = -99.0
	fake_until = -99.0
	rings.clear()
	stall_at = -99.0
	stalls = 0
	combo = 0
	best_combo = 0
	caught = 0
	missed = 0
	pulling = 0
	_serial = 0
	_demo = true
	# The countdown shifts the wind once and swings the kite over after it.
	_shift_to(0.72, false)


func _warm_up(delta: float) -> void:
	var want := signf(wind_x - kite_x) if absf(wind_x - kite_x) > 0.03 else 0.0
	_fly(delta, want)


func _go() -> void:
	_demo = false
	rings.clear()
	kite_h = maxf(kite_h, 0.6)
	_shift_due = clock + 2.0
	_ring_due = clock + 0.4


func _tick(delta: float) -> void:
	var push := 0.0
	if not dragging():
		if _held.values().has(&"left"):
			push -= 1.0
		if _held.values().has(&"right"):
			push += 1.0
	_fly(delta, push)
	if clock >= _shift_due:
		var target := _new_target()
		var fake_chance := float(variant.get("fake", -1.0))
		var fake := heat() >= FAKE_HEAT or fake_chance >= 0.0
		_shift_to(target, fake and rng.randf() < 0.45)
		_shift_due = clock + lerpf(SHIFT_FIRST, SHIFT_LAST, heat()) * rng.randf_range(0.85, 1.15)
	if clock >= _ring_due:
		_ring_due = clock + lerpf(RING_GAP_FIRST, RING_GAP_LAST, heat()) * float(variant.get("rings", 1.0)) * rng.randf_range(0.8, 1.2)
		_spawn_ring()
	_drift(delta)


func _snapshot(into: Dictionary) -> void:
	into.kite_x = kite_x
	into.kite_h = kite_h
	into.kite_y = kite_y()
	into.kite_vx = kite_vx
	into.wind_x = wind_x
	into.arrow_x = arrow_x
	into.arrow_at = arrow_at
	into.fake = clock < fake_until
	into.window_half = window_half()
	into.in_wind = in_wind()
	into.rings = rings
	into.ring_half = RING_HALF
	into.stall_at = stall_at
	into.drag_seconds = DRAG_SECONDS
	into.combo = combo
	into.pulling = pulling


## The wind window is a little wider with assist.
func window_half() -> float:
	return WINDOW_HALF * (1.35 if assisted else 1.0)


func in_wind() -> bool:
	return absf(kite_x - wind_x) <= window_half()


func dragging() -> bool:
	return clock - stall_at < DRAG_SECONDS


## The kite's height on screen, 0 top of the sky to 1 the deck.
func kite_y() -> float:
	return 0.82 - 0.6 * kite_h


func _new_target() -> float:
	var target := rng.randf_range(0.15, 0.85)
	if absf(target - wind_target) < 0.25:
		target = fposmod(target + 0.4 - 0.15, 0.7) + 0.15
	return target


## Turn the wind; with `fake` the arrow first swings the other way.
func _shift_to(target: float, fake: bool) -> void:
	wind_target = target
	arrow_at = clock
	if fake:
		arrow_x = clampf(wind_x - (target - wind_x), 0.1, 0.9)
		fake_until = clock + FAKE_SECONDS
	else:
		arrow_x = target
		fake_until = -99.0


func _fly(delta: float, push: float) -> void:
	pulling = int(push)
	if clock >= fake_until:
		arrow_x = wind_target
	# The wind itself follows the arrow a little behind, so the arrow is the warning.
	if clock - arrow_at >= WARN and clock >= fake_until:
		wind_x = move_toward(wind_x, wind_target, FOLLOW * delta * absf(wind_target - wind_x) + 0.2 * delta)
	kite_vx = lerpf(kite_vx, push * SPEED, minf(1.0, PULL * delta))
	kite_x = clampf(kite_x + kite_vx * delta, 0.05, 0.95)
	if dragging():
		return
	if in_wind():
		kite_h = minf(1.0, kite_h + CLIMB * delta)
	else:
		kite_h -= pace(SINK) * delta
	if kite_h <= 0.0:
		_stall()


func _stall() -> void:
	# The kite is caught by the next gust and climbs again, carrying the traveller up with it.
	kite_h = 0.55
	stall_at = clock
	combo = 0
	sound(40)
	if _demo:
		return
	stalls += 1
	# The first stall of a round is a free look at the traveller being carried off.
	funny_fail("飛走啦！", stalls > 1)


func _spawn_ring() -> void:
	_serial += 1
	var x := clampf(wind_target + rng.randf_range(-0.08, 0.08), 0.1, 0.9)
	# Now and then a ring sits off to one side, worth a quick dash out of the wind.
	if rng.randf() < 0.25:
		x = rng.randf_range(0.12, 0.88)
	rings.append({"id": _serial, "x": x, "y": 0.0, "state": "drift", "at": -99.0})


func _drift(delta: float) -> void:
	var kept: Array[Dictionary] = []
	var height := kite_y()
	for ring in rings:
		if str(ring.state) == "drift":
			var before := float(ring.y)
			ring.y = before + RING_SPEED * delta
			if before < height and float(ring.y) >= height:
				if absf(float(ring.x) - kite_x) <= RING_HALF and not dragging():
					_catch(ring)
				else:
					ring.state = "missed"
					ring.at = clock
					combo = 0
					missed += 1
		if str(ring.state) == "drift" and float(ring.y) < 1.1 or clock - float(ring.at) < 0.6:
			kept.append(ring)
	rings.assign(kept)


func _catch(ring: Dictionary) -> void:
	ring.state = "caught"
	ring.at = clock
	sound(76 + mini(combo, 8))
	# A kite nobody has steered can drift through a ring, but that pays nothing.
	if not touched:
		return
	caught += 1
	combo += 1
	best_combo = maxi(best_combo, combo)
	add_score(RING_POINTS + mini(combo / COMBO_STEP, COMBO_CAP) * 2, "穿過！" if combo % 5 != 0 else "連穿 %d 圈！" % combo)
