extends "res://game/minigames/arcade/arcade_driver.gd"
## 氣壓彈射: on the ferris wheel plaza the hero stands at a brass launcher with a
## big pump. Hold the button to pump air in; the gauge needle climbs. Let go to
## fire a cloud bundle across the gap: the harder the pressure, the further it
## flies. The landing platform floats somewhere different every shot, and the
## gauge's green zone is exactly the stretch of air above it, so letting go in
## the green lands the bundle on the platform (bang in the middle pays most).
## Short and it drops into the clouds, long and it sails off the far edge.
## Keep pumping past the red and the pump bursts: the hero floats up with an
## afro of frizzed hair. Later the green narrows, the pump fills faster and the
## needle shivers. Standing still scores nothing. Rules only: the picture
## lives in pump_launch_view.gd.

const View = preload("res://game/minigames/arcade/pump_launch_view.gd")
## Pressure runs 0..1; at BURST the pump gives way.
const BURST := 1.0
const RED := 0.9
## The platform's centre is drawn from this range of pressures.
const NEAR := 0.3
const FAR := 0.8
## Half the green zone: how far from the platform's centre still lands on it.
const ZONE_EARLY := 0.085
const ZONE_LATE := 0.045
## Pressure added per second while pumping.
const RISE_EARLY := 0.62
const RISE_LATE := 1.0
## The needle's shiver late in the round.
const SHIVER := 0.035
const SHIVER_HEAT := 0.45
const FLIGHT_SECONDS := 0.85
const LAND_SECONDS := 0.45
const BURST_SECONDS := 2.0
const SHOT_POINTS := 10
const BULL_POINTS := 10
const STREAK_POINTS := 2
const STREAK_CAP := 5

## "aim" (pumping or waiting), "fly", "land", "burst".
var phase := "aim"
var phase_at := 0.0
var pressure := 0.0
var pumping := false
## The platform's centre as a pressure, and the half-width of its green zone.
var target := 0.5
## The last shot: {pressure, result ("hit", "short", "long"), bull}.
var shot: Dictionary = {}
var streak := 0
var hits := 0
var bulls := 0
var misses := 0
var bursts := 0

var _demo_aim := -1.0


func _init() -> void:
	verb = "按住打氣，指針在綠區時放開，把雲包彈到對面！"
	hint = [["空白鍵", "按住打氣・放開發射"]]
	round_seconds = 45.0
	thresholds = [150, 380, 560]
	verdicts = [
		"氣筒爆了，你頂著一頭爆炸頭飄在半空。",
		"銅牌！雲包大多送到了。",
		"銀牌！摩天輪上的乘客都在幫你數。",
		"金牌！你的手比氣壓錶還準。",
	]
	variants = [
		{"id": "standard", "label": "氣壓彈射", "rise": 1.0, "shiver_from": SHIVER_HEAT},
		{"id": "shaky", "label": "指針亂抖", "rise": 1.0, "shiver_from": 0.05},
		{"id": "quick", "label": "快充氣筒", "rise": 1.45, "shiver_from": 0.7, "zone": 1.2},
	]
	score_label = "彈射得分"
	view_script = View


func _begin_round(_chosen: Dictionary) -> void:
	streak = 0
	hits = 0
	bulls = 0
	misses = 0
	bursts = 0
	shot = {}
	# The countdown pumps once and fires a bundle onto the platform by itself.
	_new_target()
	_demo_aim = target


func _warm_up(delta: float) -> void:
	match phase:
		"aim":
			if clock > 0.3 and _demo_aim >= 0.0:
				pumping = true
				pressure += rise() * delta
				if pressure >= _demo_aim:
					_fire(false)
					_demo_aim = -1.0
		"fly", "land":
			_flight()


func _go() -> void:
	streak = 0
	shot = {}
	pumping = false
	pressure = 0.0
	_phase("aim")
	_new_target()


func _tick(delta: float) -> void:
	match phase:
		"aim":
			if pumping:
				pressure += rise() * delta
				if pressure >= BURST:
					_burst()
		"fly", "land":
			_flight()
		"burst":
			if clock - phase_at >= BURST_SECONDS:
				pressure = 0.0
				_phase("aim")
				_new_target()


func _press(button: StringName) -> void:
	if button == &"action" and phase == "aim":
		pumping = true


func _release(button: StringName) -> void:
	if button == &"action" and phase == "aim" and pumping:
		_fire(true)


func _snapshot(into: Dictionary) -> void:
	into.phase = phase
	into.phase_at = phase_at
	into.pressure = pressure
	into.needle = needle()
	into.pumping = pumping
	into.target = target
	into.zone = zone()
	into.shot = shot.duplicate()
	into.streak = streak


## Half the green zone now, wider with assist.
func zone() -> float:
	return window(lerpf(ZONE_EARLY, ZONE_LATE, heat()) * float(variant.get("zone", 1.0)))


func rise() -> float:
	return lerpf(RISE_EARLY, RISE_LATE, heat()) * float(variant.get("rise", 1.0))


## Where the needle points: the pressure, shivering late in the round.
func needle() -> float:
	if heat() < float(variant.get("shiver_from", SHIVER_HEAT)) or pressure <= 0.0:
		return pressure
	var shake := SHIVER * clampf(heat() * 1.3, 0.3, 1.0)
	return pressure + shake * (sin(clock * 23.0) * 0.6 + sin(clock * 37.0 + 1.1) * 0.4)


func _fire(scoring: bool) -> void:
	pumping = false
	var at := needle()
	var off := at - target
	var result := "hit"
	if off < -zone():
		result = "short"
	elif off > zone():
		result = "long"
	var bull := result == "hit" and absf(off) <= zone() * 0.3
	shot = {"pressure": at, "result": result, "bull": bull, "target": target, "zone": zone(), "at": clock}
	_phase("fly")
	if not scoring:
		return
	if result != "hit":
		misses += 1
		streak = 0
		sound(44)
		say("太近了！" if result == "short" else "飛過頭了！", false)
		return
	hits += 1
	var points := SHOT_POINTS + roundi(BULL_POINTS * (1.0 - absf(off) / zone())) + STREAK_POINTS * mini(streak, STREAK_CAP)
	streak += 1
	if bull:
		bulls += 1
	add_score(points, ("正中！+%d" if bull else "+%d") % points)
	sound(70 + mini(streak, 6) * 2)


func _flight() -> void:
	if phase == "fly" and clock - phase_at >= FLIGHT_SECONDS:
		_phase("land")
	elif phase == "land" and clock - phase_at >= LAND_SECONDS:
		pressure = 0.0
		_phase("aim")
		if stage == "play":
			_new_target()


func _burst() -> void:
	bursts += 1
	pumping = false
	streak = 0
	pressure = BURST
	shot = {}
	sound(36)
	# The first burst of a round is a free look at the afro.
	funny_fail("氣筒爆開了！", bursts > 1)
	_phase("burst")


## A new platform, never in nearly the same place as the last one.
func _new_target() -> void:
	var last := target
	for attempt in 8:
		target = rng.randf_range(NEAR, FAR)
		if absf(target - last) >= 0.12:
			break


func _phase(next_phase: String) -> void:
	phase = next_phase
	phase_at = clock
