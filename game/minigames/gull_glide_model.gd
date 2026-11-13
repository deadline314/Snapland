extends RefCounted
class_name GullGlideModel

## Side-view gull glide (x forward, y up, metres). Wings spread by default; holding
## tuck dives faster and builds speed, and spreading again turns that speed into a
## zoom climb. Headwind grows with height, so high glides go far but slowly.
const ROUND_SECONDS := 120.0
const MAX_FRAME_DELTA := 0.25
const SUBSTEP := 1.0 / 60.0
const GLIDE_SPEED := 6.0
const GLIDE_SINK := 0.8
const TUCK_SINK := 4.5
const TUCK_ACCEL := 4.0
const TUCK_MAX := 14.0
const ZOOM := 0.9
const SPEED_DECAY := 0.8
const VY_RATE := 3.0
const WIND_MAX := 3.0
const WIND_TOP := 12.0
const TUCK_WIND := 0.5
const THERMAL_LIFT := 6.0
const TUCK_LIFT := 0.3
const CEILING := 14.0
const START := Vector2(0.0, 8.0)
const PICK_RADIUS := 1.0
const NEST_BELOW := 1.0
const FEATHER_POINTS := 50
const HOME_POINTS := 200
const DEVIL_POINTS := 100
const CRASH_PENALTY := 30
## Retries swap thermals, feathers, the rock gap and nest height.
const LAYOUTS := [
	{"name": "晨風灣", "thermals": [Vector2(3, 7), Vector2(27, 31), Vector2(41, 45)],
		"feathers": [Vector2(12, 10), Vector2(22, 2), Vector2(36, 7)],
		"gap": {"x": 50.0, "width": 1.2, "low": 3.0, "high": 4.8, "top": 6.6}, "nest": Vector2(58, 4)},
	{"name": "午潮崖", "thermals": [Vector2(5, 9), Vector2(21, 25), Vector2(39, 43)],
		"feathers": [Vector2(14, 2.5), Vector2(30, 9.5), Vector2(36, 5)],
		"gap": {"x": 50.0, "width": 1.2, "low": 4.2, "high": 6.0, "top": 7.8}, "nest": Vector2(58, 6)},
]

## One flier's state; the player and the low-wind companion share these rules.
class Flier extends RefCounted:
	var position := START
	var velocity := Vector2(GLIDE_SPEED, -GLIDE_SINK)
	var tucked := false
	var lap_threaded := false
	var respawn := START

	static func wind_at(height: float) -> float:
		return WIND_MAX * clampf(height / WIND_TOP, 0.0, 1.0)

	static func ground_speed(height: float, airspeed: float, is_tucked: bool) -> float:
		return airspeed - wind_at(height) * (TUCK_WIND if is_tucked else 1.0)

	func reset(at: Vector2 = START) -> void:
		position = at
		velocity = Vector2(GLIDE_SPEED, -GLIDE_SINK)
		tucked = false
		lap_threaded = false

	## Advances one slice and returns "" or the event: thread, scrape, rock, water, cliff, hard, nest.
	func advance(layout: Dictionary, dt: float) -> String:
		var lift := 0.0
		for column: Vector2 in layout.thermals:
			if position.x >= column.x and position.x <= column.y:
				lift = THERMAL_LIFT * (TUCK_LIFT if tucked else 1.0)
		var target := -TUCK_SINK
		if tucked:
			velocity.x = minf(TUCK_MAX, velocity.x + TUCK_ACCEL * dt)
		else:
			velocity.x -= SPEED_DECAY * (velocity.x - GLIDE_SPEED) * dt
			target = -GLIDE_SINK + maxf(0.0, velocity.x - GLIDE_SPEED) * ZOOM
		velocity.y += (target + lift - velocity.y) * minf(1.0, VY_RATE * dt)
		position.x += maxf(0.5, ground_speed(position.y, velocity.x, tucked)) * dt
		position.y = minf(CEILING, position.y + velocity.y * dt)
		var gap: Dictionary = layout.gap
		var event := ""
		if position.x >= gap.x and position.x <= gap.x + gap.width:
			if position.y > gap.low and position.y < gap.high:
				if not tucked:
					return "scrape"
				if not lap_threaded:
					lap_threaded = true
					event = "thread"
			elif position.y < gap.top:
				return "rock"
		if position.y <= 0.0:
			return "water"
		var nest: Vector2 = layout.nest
		if position.x >= nest.x:
			if position.y < nest.y - NEST_BELOW:
				return "cliff"
			return "hard" if tucked else "nest"
		return event

static func wind(height: float) -> float:
	return Flier.wind_at(height)

static func ground_speed(height: float, airspeed: float, tucked: bool) -> float:
	return Flier.ground_speed(height, airspeed, tucked)

var _assisted := false
var _variant := 0
var _layout: Dictionary = {}
var _elapsed := 0.0
var _bird := Flier.new()
var _companion := Flier.new()
var _companion_homes := 0
var _held := false
var _got: Array[int] = []
var _lap_got: Array[int] = []
var _laps := 0
var _crashes := 0
var _threaded_home := false
var _ended := false
var _success := false
var _home_time := 0.0
var _feedback := ""
var _last_event := ""

func _init() -> void:
	reset()

func reset(assisted: bool = false, variant: int = 0) -> void:
	_assisted = assisted
	_variant = posmod(variant, LAYOUTS.size())
	_layout = LAYOUTS[_variant]
	_elapsed = 0.0
	_bird.reset()
	_bird.respawn = START
	_companion.reset()
	_companion_homes = 0
	_held = false
	_got.clear()
	_lap_got.clear()
	_laps = 0
	_crashes = 0
	_threaded_home = false
	_ended = false
	_success = false
	_home_time = 0.0
	_last_event = ""
	_feedback = "展翼滑翔；按住收翼俯衝加速，放開會拉高。帶三根羽毛回巢"

func set_tucked(value: bool) -> void:
	_held = value and not _ended

func clear_input() -> void:
	_held = false

## Where a spread glide from here would meet the water (headwind included).
func glide_reach() -> float:
	var x := _bird.position.x
	var y := _bird.position.y
	var ground := maxf(0.5, GLIDE_SPEED - wind(y))
	return x + ground * y / GLIDE_SINK

func step(delta: float) -> Dictionary:
	if _ended or not is_finite(delta) or delta <= 0.0:
		return snapshot()
	var remaining := minf(delta, MAX_FRAME_DELTA)
	while remaining > 0.000001 and not _ended:
		var dt := minf(remaining, SUBSTEP)
		remaining -= dt
		_step_slice(dt)
	return snapshot()

func _step_slice(dt: float) -> void:
	_elapsed = minf(ROUND_SECONDS, _elapsed + dt)
	_bird.tucked = _held
	_handle(_bird.advance(_layout, dt))
	_pick_feathers()
	_fly_companion(dt)
	if not _ended and _elapsed >= ROUND_SECONDS:
		_ended = true
		_held = false
		_feedback = "時間到：還沒帶齊羽毛回巢（%d／3）" % _got.size()

func _pick_feathers() -> void:
	if _ended:
		return
	for index in _layout.feathers.size():
		if not _got.has(index) and _bird.position.distance_to(_layout.feathers[index]) < PICK_RADIUS:
			_got.append(index)
			_lap_got.append(index)
			_feedback = "拿到第 %d 根羽毛" % _got.size()

## Thermals passed this lap become the assisted respawn point.
func _update_respawn() -> void:
	for column: Vector2 in _layout.thermals:
		if _bird.position.x >= column.x and _bird.respawn.x < column.x:
			_bird.respawn = Vector2(column.x, START.y)

func _handle(event: String) -> void:
	_update_respawn()
	match event:
		"":
			return
		"thread":
			_last_event = event
			_feedback = "收翼穿過岩縫！展翼回巢就成"
		"nest":
			if _got.size() >= _layout.feathers.size():
				_ended = true
				_success = true
				_held = false
				_threaded_home = _bird.lap_threaded
				_home_time = _elapsed
				_last_event = event
				_feedback = "帶著三根羽毛回巢" + ("，還收翼穿了岩縫" if _threaded_home else "")
			else:
				_laps += 1
				_lap_got.clear()
				_last_event = "lap"
				_feedback = "還差 %d 根羽毛，乘風繞回起點" % (_layout.feathers.size() - _got.size())
				_bird.reset()
				_bird.respawn = START
		_:
			_crash(event)

func _crash(kind: String) -> void:
	_crashes += 1
	_last_event = kind
	var reason: String = {"scrape": "展著翼擦到岩縫", "rock": "撞上岩柱", "water": "掉進海裡", "cliff": "撞上巢下的崖壁", "hard": "收著翼衝進巢，太猛了"}.get(kind, kind)
	if _assisted:
		_feedback = "%s：回到最近的上升氣流，羽毛保留" % reason
		_bird.reset(_bird.respawn)
	else:
		for index in _lap_got:
			_got.erase(index)
		_feedback = "%s：這圈的羽毛掉回原處，從起點再飛" % reason
		_bird.reset()
		_bird.respawn = START
	_lap_got.clear()

## The companion keeps a low, safe line home and never picks feathers.
func _fly_companion(dt: float) -> void:
	var gap: Dictionary = _layout.gap
	var at := _companion.position
	var in_thermal := false
	for column: Vector2 in _layout.thermals:
		in_thermal = in_thermal or (at.x >= column.x and at.x <= column.y)
	var cruise := 3.0
	if at.x > gap.x - 12.0 and at.x < gap.x + gap.width:
		cruise = gap.top + 2.5
	elif at.x >= gap.x + gap.width:
		cruise = Vector2(_layout.nest).y + 1.0
	_companion.tucked = not in_thermal and at.y > cruise + 1.0 and at.x < Vector2(_layout.nest).x - 2.5
	var event := _companion.advance(_layout, dt)
	if event == "nest":
		_companion_homes += 1
	if event != "" and event != "thread":
		_companion.reset()

func score() -> int:
	var total := _got.size() * FEATHER_POINTS - _crashes * CRASH_PENALTY
	if _success:
		total += HOME_POINTS + int(ROUND_SECONDS - _home_time)
	if devil():
		total += DEVIL_POINTS
	return maxi(0, total)

func devil() -> bool:
	return _success and _threaded_home

func snapshot() -> Dictionary:
	var feathers: Array = []
	for index in _layout.feathers.size():
		feathers.append({"position": _layout.feathers[index], "taken": _got.has(index)})
	return {
		"assisted": _assisted, "variant": _variant, "variant_name": _layout.name, "elapsed": _elapsed,
		"remaining": maxf(0.0, ROUND_SECONDS - _elapsed), "ended": _ended, "success": _success, "devil": devil(), "devil_success": devil(),
		"ordinary_eligible": _ended, "score": score(), "mistakes": _crashes, "crashes": _crashes, "laps": _laps,
		"position": _bird.position, "velocity": _bird.velocity, "tucked": _held, "wind": wind(_bird.position.y),
		"ground_speed": ground_speed(_bird.position.y, _bird.velocity.x, _held), "reach": glide_reach(),
		"feathers": feathers, "feather_count": _got.size(), "thermals": _layout.thermals.duplicate(), "gap": _layout.gap.duplicate(),
		"nest": _layout.nest, "threaded": _bird.lap_threaded, "companion": _companion.position, "companion_tucked": _companion.tucked,
		"companion_homes": _companion_homes, "respawn": _bird.respawn, "feedback": _feedback, "last_event": _last_event,
	}
