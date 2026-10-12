extends RefCounted
class_name SignBalanceModel

## Deterministic, pivot-driven harbor sign challenge. Callers may read the cached
## snapshot but must treat it and its nested arrays as read-only.
const ROUND_SECONDS := 60.0
const STAGE_COUNT := 7
const STAGE_SECONDS := 20.0 / STAGE_COUNT
const FORECAST_SECONDS := 0.55
const PRECISE_ANGLE := 0.055
const SAFE_ANGLE := 0.13
const IMPACT_ANGLE := 0.78
const IMPACT_RESET_ANGLE := 0.56
const SAFE_DWELL_SECONDS := 0.52
const MAX_DELTA := 0.025
const MAX_FRAME_DELTA := 0.25
const WIND_DIRECTIONS: Array[int] = [1, -1, 1, -1, -1, 1, -1]
const WIND_STRENGTHS: Array[float] = [0.22, 0.26, 0.19, 0.28, 0.23, 0.27, 0.21]
const TARGET_ANGLES: Array[float] = [0.0, 0.025, -0.02, 0.035, -0.025, 0.015, 0.0]
const COUNTERWEIGHT_TORQUE := 1.10
const RESTORE_TORQUE := 1.05
const ANGULAR_DAMPING := 1.75

var assisted := false
var balance := 0.0
var angle := 0.0
var angular_velocity := 0.0
var elapsed := 0.0
var stage := 0
var stage_elapsed := 0.0
var stable_seconds := 0.0
var safe_stages := 0
var precise_stages := 0
var impacts := 0
var score := 0
var ended := false
var success := false
var devil_success := false
var timed_out := false
var last_event := ""
var _impact_latched := false
var _stage_input_seen := false
var _snapshot_cache: Dictionary = {}
var _stage_results: Array[Dictionary] = []

func reset(p_assisted: bool = false) -> void:
	assisted = p_assisted
	balance = 0.0
	angle = 0.0
	angular_velocity = 0.0
	elapsed = 0.0
	stage = 0
	stage_elapsed = 0.0
	stable_seconds = 0.0
	safe_stages = 0
	precise_stages = 0
	impacts = 0
	score = 0
	ended = false
	success = false
	devil_success = false
	timed_out = false
	last_event = ""
	_impact_latched = false
	_stage_input_seen = false
	_stage_results.clear()
	for index in STAGE_COUNT:
		_stage_results.append({"passed": false, "precise": false, "stable_seconds": 0.0, "target_angle": TARGET_ANGLES[index]})
	_refresh_snapshot()

func set_balance(value: float) -> void:
	if ended or not is_finite(value):
		return
	balance = clampf(value, -1.0, 1.0)
	_refresh_snapshot()

func step(delta: float) -> Dictionary:
	if ended or not is_finite(delta) or delta <= 0.0:
		return snapshot()
	# Discard pathological frame hitches instead of processing an unbounded catch-up loop.
	var remaining := minf(delta, MAX_FRAME_DELTA)
	while remaining > 0.000001 and not ended:
		var dt := minf(remaining, MAX_DELTA)
		remaining -= dt
		_step_slice(dt)
	return snapshot()

func snapshot() -> Dictionary:
	return _snapshot_cache

func _step_slice(dt: float) -> void:
	var old_stage := stage
	if absf(balance) >= 0.08:
		_stage_input_seen = true
	elapsed = minf(ROUND_SECONDS, elapsed + dt)
	stage_elapsed += dt
	var direction: int = WIND_DIRECTIONS[mini(stage, STAGE_COUNT - 1)]
	var strength: float = WIND_STRENGTHS[mini(stage, STAGE_COUNT - 1)] * (0.72 if assisted else 1.0)
	var preview_phase := stage_elapsed - FORECAST_SECONDS
	var envelope := 0.0
	if preview_phase >= 0.0 and preview_phase < 1.95:
		var fade_in := smoothstep(0.0, 0.22, preview_phase)
		var fade_out := 1.0 - smoothstep(1.55, 1.95, preview_phase)
		var pulse := 0.74 + 0.26 * sin((preview_phase / 1.95) * PI)
		envelope = maxf(0.0, fade_in * fade_out * pulse)
	var gust_torque := float(direction) * strength * envelope
	var target: float = TARGET_ANGLES[mini(stage, STAGE_COUNT - 1)]
	var restoring_torque := -RESTORE_TORQUE * (angle - target)
	var player_torque := COUNTERWEIGHT_TORQUE * balance
	var acceleration := gust_torque + restoring_torque + player_torque - ANGULAR_DAMPING * angular_velocity
	angular_velocity = clampf(angular_velocity + acceleration * dt, -2.3, 2.3)
	angle = clampf(angle + angular_velocity * dt, -1.35, 1.35)

	if absf(angle) >= IMPACT_ANGLE and not _impact_latched:
		_impact_latched = true
		impacts += 1
		last_event = "撞線：陣風推過外側安全線"
		angle = signf(angle) * IMPACT_RESET_ANGLE
		angular_velocity *= -0.30
		stable_seconds = 0.0
		if impacts >= 3:
			ended = true
			last_event = "支架撞線三次，挑戰結束"
	elif _impact_latched and absf(angle) < IMPACT_RESET_ANGLE * 0.74:
		_impact_latched = false

	var target_error := absf(angle - target)
	var safe_limit := SAFE_ANGLE * (1.38 if assisted else 1.0)
	var precise_limit := PRECISE_ANGLE * (1.45 if assisted else 1.0)
	if target_error <= safe_limit and absf(angular_velocity) <= (0.34 if assisted else 0.25):
		stable_seconds += dt
	else:
		stable_seconds = maxf(0.0, stable_seconds - dt * 1.35)

	if stage_elapsed >= STAGE_SECONDS and not ended:
		var passed := _stage_input_seen and stable_seconds >= SAFE_DWELL_SECONDS
		var precise := passed and target_error <= precise_limit and impacts == int(_snapshot_cache.get("impacts", impacts)) and absf(angular_velocity) <= 0.11
		_stage_results[stage]["passed"] = passed
		_stage_results[stage]["precise"] = precise
		_stage_results[stage]["stable_seconds"] = stable_seconds
		if passed:
			safe_stages += 1
			score += 70 if not precise else 100
			if precise:
				precise_stages += 1
			last_event = "精準穩住第 %d 段" % (stage + 1) if precise else "穩住第 %d 段" % (stage + 1)
		else:
			last_event = "第 %d 段未停在安全區" % (stage + 1)
		stage += 1
		stage_elapsed = 0.0
		stable_seconds = 0.0
		_stage_input_seen = false
		if stage >= STAGE_COUNT:
			ended = true
			success = safe_stages >= 5
			devil_success = success and precise_stages == STAGE_COUNT and impacts == 0
			last_event = "七段平衡完成" if success else "穩定段不足五段"
	if elapsed >= ROUND_SECONDS and not ended:
		ended = true
		timed_out = true
		success = safe_stages >= 5
		devil_success = success and precise_stages == STAGE_COUNT and impacts == 0
		last_event = "時間到：完成安全段統計"
	_refresh_snapshot()
	if old_stage != stage:
		_refresh_snapshot()

func _refresh_snapshot() -> void:
	var index := mini(stage, STAGE_COUNT - 1)
	var direction: int = WIND_DIRECTIONS[index]
	var strength: float = WIND_STRENGTHS[index] * (0.72 if assisted else 1.0)
	var forecast := direction * strength if stage_elapsed <= FORECAST_SECONDS else 0.0
	var active_envelope := 0.0
	var preview_phase := stage_elapsed - FORECAST_SECONDS
	if preview_phase >= 0.0 and preview_phase < 1.95:
		active_envelope = maxf(0.0, smoothstep(0.0, 0.22, preview_phase) * (1.0 - smoothstep(1.55, 1.95, preview_phase)) * (0.74 + 0.26 * sin((preview_phase / 1.95) * PI)) )
	_snapshot_cache["assisted"] = assisted
	_snapshot_cache["balance"] = balance
	_snapshot_cache["angle"] = angle
	_snapshot_cache["angular_velocity"] = angular_velocity
	_snapshot_cache["elapsed"] = elapsed
	_snapshot_cache["stage"] = mini(stage, STAGE_COUNT - 1)
	_snapshot_cache["stage_number"] = mini(stage + 1, STAGE_COUNT)
	_snapshot_cache["completed_stage_count"] = mini(stage, STAGE_COUNT)
	_snapshot_cache["stage_elapsed"] = stage_elapsed
	_snapshot_cache["stage_seconds"] = STAGE_SECONDS
	_snapshot_cache["forecast_seconds"] = maxf(0.0, FORECAST_SECONDS - stage_elapsed)
	_snapshot_cache["wind_direction"] = direction
	_snapshot_cache["wind_kind"] = "海風" if index % 2 == 0 else "穿堂陣風"
	_snapshot_cache["wind_strength"] = strength
	_snapshot_cache["wind_torque"] = direction * strength * active_envelope
	_snapshot_cache["forecast_torque"] = forecast
	_snapshot_cache["target_angle"] = TARGET_ANGLES[index]
	_snapshot_cache["stable_seconds"] = stable_seconds
	_snapshot_cache["safe_stages"] = safe_stages
	_snapshot_cache["precise_stages"] = precise_stages
	_snapshot_cache["impacts"] = impacts
	_snapshot_cache["score"] = score
	_snapshot_cache["stage_results"] = _stage_results
	_snapshot_cache["ended"] = ended
	_snapshot_cache["success"] = success
	_snapshot_cache["devil_success"] = devil_success
	_snapshot_cache["timed_out"] = timed_out
	_snapshot_cache["last_event"] = last_event
	_snapshot_cache["stage_input_seen"] = _stage_input_seen
	_snapshot_cache["forecast_visible"] = not ended and stage_elapsed <= FORECAST_SECONDS
	_snapshot_cache["safe_limit"] = SAFE_ANGLE * (1.38 if assisted else 1.0)
	_snapshot_cache["precise_limit"] = PRECISE_ANGLE * (1.45 if assisted else 1.0)
