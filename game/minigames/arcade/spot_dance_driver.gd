extends "res://game/minigames/arcade/arcade_driver.gd"
## 追光躲步: a dance floor of 7 x 3 tiles under a roaming spotlight. Every arrow
## press is one dance step to the next tile; standing in the light scores, and
## a step that lands in the light scores more and builds a combo. The light
## darts off in new directions, shrinks, later splits into two that cross each
## other. Too long in the dark and the lights die: only the hero's eyes blink
## in the blackness. Rules only: the picture lives in spot_dance_view.gd.

const View = preload("res://game/minigames/arcade/spot_dance_view.gd")
const COLUMNS := 7
const ROWS := 3
const STEPS := {&"left": Vector2i(-1, 0), &"right": Vector2i(1, 0), &"up": Vector2i(0, -1), &"down": Vector2i(0, 1)}
## Holding a direction keeps stepping after a short pause.
const REPEAT_DELAY := 0.28
const REPEAT_EVERY := 0.18
## Light speed in tiles per second, its radius in tiles, early and late.
const SPEED_EARLY := 1.1
const SPEED_LATE := 2.4
const RADIUS_EARLY := 1.35
const RADIUS_LATE := 0.85
## Seconds between darts (a sudden new heading), early and late.
const DART_EARLY := 3.6
const DART_LATE := 1.5
## Seconds in the dark before the lights die, early and late.
const DARK_EARLY := 1.6
const DARK_LATE := 1.0
const BLACKOUT_SECONDS := 2.2
## Points per second in the light while dancing (a step within DANCE_GRACE
## seconds); a step landing in it adds STEP_POINTS plus the combo. Standing
## still never scores, so an untouched round scores nothing.
const LIT_RATE := 10.0
const DANCE_GRACE := 1.0
const STEP_POINTS := 3
const COMBO_CAP := 5
## Twin lights are each this much smaller than one.
const TWIN_SHRINK := 0.82

## "dance" or "blackout".
var phase := "dance"
var phase_at := 0.0
var tile := Vector2i(3, 1)
var hop_from := Vector2i(3, 1)
var hop_at := -9.0
## Each light: {pos (tiles, Vector2), vel (tiles/s), dart_at}.
var lights: Array[Dictionary] = []
var dark_time := 0.0
var combo := 0
var lit_steps := 0
var blackouts := 0
var lit := true
var _held_dir: StringName = &""
var _held_since := 0.0
var _next_repeat := 0.0
var _lit_carry := 0.0
var _stepped_at := -99.0


func _init() -> void:
	verb = "方向鍵跳舞，一直待在聚光燈裡！"
	hint = [["↑ ↓ ← →", "跳一步"]]
	round_seconds = 45.0
	thresholds = [250, 560, 740]
	verdicts = [
		"燈光師找不到你，只看到兩顆眼睛。",
		"銅牌！有幾段舞是真的在光裡跳的。",
		"銀牌！聚光燈跑哪你跳哪。",
		"金牌！不是你追光，是光在追你。",
	]
	variants = [
		{"id": "solo", "label": "獨舞之夜", "split_from": 0.5, "darts": 1.0},
		{"id": "twins", "label": "雙燈交錯", "split_from": 0.2, "darts": 1.0},
		{"id": "jumpy", "label": "抽風燈", "split_from": 0.65, "darts": 2.0},
	]
	score_label = "跳舞得分"
	view_script = View


func _begin_round(_chosen: Dictionary) -> void:
	tile = Vector2i(3, 1)
	hop_from = tile
	hop_at = -9.0
	combo = 0
	lit_steps = 0
	blackouts = 0
	dark_time = 0.0
	_lit_carry = 0.0
	_stepped_at = -99.0
	_phase("dance")
	lights = [_light(Vector2(3, 1), Vector2(1, 0.4))]


## The countdown shows the idea: the light drifts and the hero hops after it.
func _warm_up(delta: float) -> void:
	_move_lights(delta, 0.9, 1.6)
	if clock - hop_at > 0.45:
		var target := _nearest_light(tile)
		var step := Vector2i(signi(roundi(target.x) - tile.x), 0)
		if step.x == 0:
			step = Vector2i(0, signi(roundi(target.y) - tile.y))
		if step != Vector2i.ZERO:
			_hop(step, false)


func _go() -> void:
	tile = Vector2i(3, 1)
	hop_from = tile
	hop_at = -9.0
	lights = [_light(Vector2(3, 1), Vector2(1, 0.35))]
	dark_time = 0.0
	_phase("dance")


func _tick(delta: float) -> void:
	if phase == "blackout":
		if clock - phase_at >= BLACKOUT_SECONDS:
			# The lights come back up on the hero.
			lights = [_light(Vector2(tile), Vector2(1, 0.35) * (1.0 if rng.randf() < 0.5 else -1.0))]
			dark_time = 0.0
			_phase("dance")
		return
	_repeat_held()
	_move_lights(delta, speed(), radius())
	_split_if_due()
	lit = is_lit(tile)
	if lit:
		dark_time = 0.0
		if dancing():
			_lit_carry += LIT_RATE * delta
		var whole := floori(_lit_carry)
		if whole > 0:
			_lit_carry -= whole
			add_score(whole)
	else:
		combo = 0
		dark_time += delta
		if dark_time >= dark_limit():
			_blackout()


func _press(button: StringName) -> void:
	if not STEPS.has(button):
		return
	_held_dir = button
	_held_since = clock
	_next_repeat = clock + REPEAT_DELAY
	if phase == "dance":
		_hop(STEPS[button], true)


func _release(button: StringName) -> void:
	if button == _held_dir:
		_held_dir = &""


func _snapshot(into: Dictionary) -> void:
	into.phase = phase
	into.phase_at = phase_at
	into.tile = tile
	into.hop_from = hop_from
	into.hop_at = hop_at
	into.lights = lights
	into.radius = radius()
	into.lit = lit
	into.dark = clampf(dark_time / dark_limit(), 0.0, 1.0)
	into.combo = combo
	into.dancing = dancing()
	into.columns = COLUMNS
	into.rows = ROWS


func speed() -> float:
	return lerpf(SPEED_EARLY, SPEED_LATE, heat())


func radius() -> float:
	var reach := lerpf(RADIUS_EARLY, RADIUS_LATE, heat())
	return reach * (TWIN_SHRINK if lights.size() > 1 else 1.0)


## True while the player has stepped within the last DANCE_GRACE seconds.
func dancing() -> bool:
	return clock - _stepped_at <= DANCE_GRACE


func dark_limit() -> float:
	return window(lerpf(DARK_EARLY, DARK_LATE, heat()))


func is_lit(at: Vector2i) -> bool:
	for light in lights:
		if Vector2(at).distance_to(light.pos) <= radius():
			return true
	return false


func _hop(step: Vector2i, scoring: bool) -> void:
	var next := Vector2i(clampi(tile.x + step.x, 0, COLUMNS - 1), clampi(tile.y + step.y, 0, ROWS - 1))
	if next == tile:
		return
	hop_from = tile
	tile = next
	hop_at = clock
	if not scoring:
		return
	_stepped_at = clock
	if is_lit(tile):
		lit_steps += 1
		add_score(STEP_POINTS + combo, "+%d" % (STEP_POINTS + combo) if combo >= 2 else "")
		combo = mini(combo + 1, COMBO_CAP)
		sound(64 + combo * 2)
	else:
		sound(52)


func _repeat_held() -> void:
	if _held_dir == &"" or clock < _next_repeat:
		return
	_next_repeat = clock + REPEAT_EVERY
	_hop(STEPS[_held_dir], true)


func _move_lights(delta: float, pace_now: float, _reach: float) -> void:
	for light in lights:
		var vel: Vector2 = light.vel
		if clock >= float(light.dart_at):
			# A sudden new heading: the light darts off.
			vel = Vector2.from_angle(rng.randf() * TAU)
			light.dart_at = clock + lerpf(DART_EARLY, DART_LATE, heat()) / float(variant.get("darts", 1.0)) * rng.randf_range(0.7, 1.3)
		vel = vel.normalized() * pace_now
		var pos: Vector2 = light.pos + Vector2(vel.x, vel.y * 0.5) * delta
		if pos.x < 0.0 or pos.x > COLUMNS - 1:
			vel.x = -vel.x
			pos.x = clampf(pos.x, 0.0, COLUMNS - 1)
		if pos.y < 0.0 or pos.y > ROWS - 1:
			vel.y = -vel.y
			pos.y = clampf(pos.y, 0.0, ROWS - 1)
		light.pos = pos
		light.vel = vel


func _split_if_due() -> void:
	if lights.size() == 1 and heat() >= float(variant.get("split_from", 0.5)):
		var one: Dictionary = lights[0]
		# The light splits in two that head off opposite ways and cross later.
		lights = [_light(one.pos, Vector2(1, 0.3)), _light(one.pos, Vector2(-1, -0.3))]
		say("分身了！", false)
		sound(76)


func _light(at: Vector2, heading: Vector2) -> Dictionary:
	return {"pos": at, "vel": heading.normalized(), "dart_at": clock + lerpf(DART_EARLY, DART_LATE, heat()) / float(variant.get("darts", 1.0))}


func _nearest_light(at: Vector2i) -> Vector2:
	var best: Vector2 = lights[0].pos
	for light in lights:
		if Vector2(at).distance_to(light.pos) < Vector2(at).distance_to(best):
			best = light.pos
	return best


func _blackout() -> void:
	blackouts += 1
	combo = 0
	dark_time = 0.0
	_held_dir = &""
	sound(36)
	# The first blackout of a round is a free look at the blinking eyes.
	funny_fail("燈暗了…", blackouts > 1)
	_phase("blackout")


func _phase(next_phase: String) -> void:
	phase = next_phase
	phase_at = clock
