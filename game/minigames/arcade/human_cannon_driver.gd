extends "res://game/minigames/arcade/arcade_driver.gd"
## 人肉砲彈: hold the button to squeeze the cannon's spring, let go to fire the
## clown at a safety net sliding back and forth above a water trough. More
## squeeze flies farther, so the sweet spot is wherever the net will be, never
## simply "full". Short shots splash into the trough; long ones (or a spring
## held past its limit) punch the clown through the tent canvas. Later the net
## speeds up and shrinks and a fan bends the shot. Rules only: the picture
## lives in human_cannon_view.gd.

const View = preload("res://game/minigames/arcade/human_cannon_view.gd")
## Screen x the shot leaves from and how far a full squeeze carries it.
const MUZZLE_X := 270.0
const RANGE := 900.0
## The net slides between these; the tent canvas starts at WALL_X.
const NET_LEFT := 620.0
const NET_RIGHT := 1060.0
const WALL_X := 1150.0
## The water trough runs from here to the canvas.
const TROUGH_X := 330.0
const SQUEEZE_SECONDS := 1.3
## Held this far past full the spring lets go by itself.
const OVERLOAD := 1.18
const FLIGHT_SECONDS := 0.85
const LAND_SECONDS := 0.9
const FAIL_SECONDS := 1.7
const RELOAD_SECONDS := 0.5
const NET_SPEED_EARLY := 150.0
const NET_SPEED_LATE := 400.0
const NET_WIDTH_EARLY := 230.0
const NET_WIDTH_LATE := 120.0
const FAN_FROM_HEAT := 0.4
const BULLSEYE := 14.0
const NET_POINTS := 20
const AIM_POINTS := 30
const BULLSEYE_BONUS := 20
const STREAK_BONUS := 5
const STREAK_CAP := 5
const DEMO_POWER := 0.62

## "load" (ready to squeeze) -> "squeeze" -> "flight" -> "net" | "splash" | "canvas" -> "load".
var phase := "load"
var phase_at := 0.0
var power := 0.0
var shots := 0
var landed := 0
var streak := 0
var misses := 0
var bullseyes := 0
## Where the net is now and where it was when the clown came down.
var net_x := NET_LEFT
var net_dir := 1.0
var net_width := NET_WIDTH_EARLY
## Wind push in screen pixels on the shot now aimed; 0 with no fan.
var fan := 0.0
var shot_power := 0.0
var shot_from_x := MUZZLE_X
var land_x := 0.0
var land_offset := 0.0
var last_points := 0


func _init() -> void:
	verb = "按住壓彈簧，放開把小丑射進網子！"
	hint = [["空白鍵", "按住蓄力・放開發射"]]
	round_seconds = 45.0
	thresholds = [250, 550, 850]
	verdicts = [
		"小丑今天泡在水槽裡上班。",
		"銅牌！網子有碰到，觀眾有拍手。",
		"銀牌！砲彈小丑飛得又高又準。",
		"金牌！每一發都正中網心，帳篷差點掀了。",
	]
	variants = [
		{"id": "standard", "label": "標準砲", "speed": 1.0, "width": 1.0, "fan": 0.0, "blind": false},
		{"id": "tiny", "label": "迷你網", "speed": 0.85, "width": 0.7, "fan": 0.0, "blind": false},
		{"id": "windy", "label": "大風扇", "speed": 0.9, "width": 1.0, "fan": 1.0, "blind": false},
		{"id": "blind", "label": "看不到落點", "speed": 1.0, "width": 1.0, "fan": 0.0, "blind": true},
	]
	score_label = "砲彈得分"
	view_script = View


func _begin_round(_chosen: Dictionary) -> void:
	shots = 0
	landed = 0
	streak = 0
	misses = 0
	bullseyes = 0
	# The demonstration net waits where the demonstration shot comes down.
	net_x = MUZZLE_X + DEMO_POWER * RANGE
	net_dir = 1.0
	net_width = NET_WIDTH_EARLY * float(variant.width)
	fan = 0.0
	power = 0.0
	_phase("load")


## The countdown fires one clown by itself, into the net.
func _warm_up(delta: float) -> void:
	match phase:
		"load":
			if _stage_time > 0.25:
				_phase("squeeze")
		"squeeze":
			power = minf(DEMO_POWER, power + delta / SQUEEZE_SECONDS)
			if power >= DEMO_POWER:
				_fire()
		"flight":
			if clock - phase_at >= FLIGHT_SECONDS:
				land_x = shot_from_x + shot_power * RANGE
				land_offset = land_x - net_x
				_phase("net")


func _go() -> void:
	shots = 0
	power = 0.0
	streak = 0
	net_x = lerpf(NET_LEFT, NET_RIGHT, 0.4)
	_phase("load")
	_aim_fan()


func _tick(delta: float) -> void:
	_slide_net(delta)
	var waited := clock - phase_at
	match phase:
		"squeeze":
			power += delta / SQUEEZE_SECONDS
			if power >= OVERLOAD:
				power = OVERLOAD
				_fire()
		"flight":
			if waited >= FLIGHT_SECONDS:
				_land()
		"net":
			if waited >= LAND_SECONDS:
				_reload()
		"splash", "canvas":
			if waited >= FAIL_SECONDS:
				_reload()
		"reload":
			if waited >= RELOAD_SECONDS:
				_phase("load")


func _press(button: StringName) -> void:
	if button == &"action" and phase == "load":
		power = 0.0
		_phase("squeeze")
		sound(52)


func _release(button: StringName) -> void:
	if button == &"action" and phase == "squeeze":
		_fire()


## A shot in the air when time runs out still comes down and counts.
func _round_over() -> void:
	if phase == "flight":
		_land()


func _snapshot(into: Dictionary) -> void:
	into.phase = phase
	into.phase_at = phase_at
	into.power = power
	into.overload = OVERLOAD
	into.net_x = net_x
	into.net_width = net_width
	into.fan = fan
	into.blind = bool(variant.get("blind", false)) and heat() > 0.35
	into.shot_power = shot_power
	into.shot_from_x = shot_from_x
	into.land_x = land_x
	into.land_offset = land_offset
	into.streak = streak
	into.last_points = last_points
	into.aim_x = aim_x(power)
	into.muzzle_x = MUZZLE_X
	into.range = RANGE
	into.wall_x = WALL_X
	into.trough_x = TROUGH_X
	into.flight_seconds = FLIGHT_SECONDS


## Where a shot with this squeeze comes down, fan included.
func aim_x(squeeze: float) -> float:
	return MUZZLE_X + squeeze * RANGE + fan


## Net speed and width for the current moment of the round.
func net_speed() -> float:
	return pace(lerpf(NET_SPEED_EARLY, NET_SPEED_LATE, heat()) * float(variant.speed))


func _slide_net(delta: float) -> void:
	net_width = lerpf(NET_WIDTH_EARLY, NET_WIDTH_LATE, heat()) * float(variant.width)
	if phase == "net":
		return
	net_x += net_dir * net_speed() * delta
	var low := NET_LEFT
	var high := NET_RIGHT
	if net_x > high:
		net_x = high - (net_x - high)
		net_dir = -1.0
	elif net_x < low:
		net_x = low + (low - net_x)
		net_dir = 1.0


func _aim_fan() -> void:
	fan = 0.0
	var strength := float(variant.fan)
	if strength <= 0.0 and heat() >= FAN_FROM_HEAT:
		strength = 0.6
	if strength > 0.0:
		fan = (1.0 if rng.randf() < 0.5 else -1.0) * rng.randf_range(50.0, 110.0) * strength


func _fire() -> void:
	shots += 1
	shot_power = power
	shot_from_x = MUZZLE_X
	power = 0.0
	_phase("flight")
	sound(43)


func _land() -> void:
	land_x = MUZZLE_X + shot_power * RANGE + fan
	land_offset = land_x - net_x
	var half := net_width * 0.5
	if land_x >= WALL_X:
		_miss("canvas", "卡進帳篷了！")
	elif absf(land_offset) > half:
		_miss("splash", "噗通！")
	else:
		landed += 1
		streak += 1
		var accuracy := 1.0 - absf(land_offset) / half
		last_points = NET_POINTS + roundi(AIM_POINTS * accuracy) + STREAK_BONUS * mini(streak - 1, STREAK_CAP)
		if absf(land_offset) <= window(BULLSEYE):
			bullseyes += 1
			last_points += BULLSEYE_BONUS
			add_score(last_points, "正中網心！+%d" % last_points)
			sound(84)
		else:
			add_score(last_points, "+%d" % last_points)
			sound(76)
		_phase("net")


func _miss(kind: String, line: String) -> void:
	misses += 1
	streak = 0
	last_points = 0
	sound(40)
	# The first miss of a round is a free look at the trough or the canvas.
	if misses > 1:
		add_mistake(line)
	else:
		say(line, false)
	_phase(kind)


func _reload() -> void:
	_phase("reload")
	_aim_fan()


func _phase(next_phase: String) -> void:
	phase = next_phase
	phase_at = clock
