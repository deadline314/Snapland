extends RefCounted
class_name HatRescueModel

## Fixed-chart, side-plane hat rescue. Snapshot and nested arrays are reused;
## callers may inspect but must treat them as read-only.
const ROUND_SECONDS := 60.0
const HAT_COUNT := 6
const CATCH_Y := 518.0
const PLAYER_MIN_X := 176.0
const PLAYER_MAX_X := 1104.0
const PLAYER_ACCEL := 1400.0
const PLAYER_DRAG := 5.8
const PLAYER_MAX_SPEED := 400.0
const CENTER_WINDOW := 19.0
const EDGE_WINDOW := 49.0
const ASSIST_EDGE_WINDOW := 66.0
const CENTER_POINTS := 120
const EDGE_POINTS := 70
const STREAK_STEP := 8
const STREAK_CAP := 24
const ORDINARY_CATCHES := 4
const CATCH_WINDOW := 0.38
const ASSIST_CATCH_WINDOW := 0.58
const WIND_STRENGTH := 156.0
const GUST_DURATION := 1.22
const FORECAST_SECONDS := 0.72
const MAX_FRAME_DELTA := 0.25
const MAX_STEP := 0.025
## One shared sea wind: each gust pushes every airborne hat at once. Hats 3–4 and
## 5–6 leave their owners in the same gust, so two brims are airborne together and
## the player must plan a route (or choose which one to save).
const GUST_STARTS: Array[float] = [0.52, 3.32, 6.1, 9.9]
const GUST_DIRECTIONS: Array[int] = [1, -1, -1, 1]
const HAT_GUST: Array[int] = [0, 1, 2, 2, 3, 3]
const SPAWN_TIMES: Array[float] = [0.0, 2.8, 5.6, 6.7, 9.4, 10.65]
const SPAWN_X: Array[float] = [346.0, 918.0, 520.0, 780.0, 300.0, 620.0]
const SPAWN_Y: Array[float] = [176.0, 202.0, 170.0, 160.0, 176.0, 160.0]
const INITIAL_VX: Array[float] = [38.0, -34.0, -20.0, -24.0, 30.0, 24.0]
const INITIAL_VY: Array[float] = [128.0, 119.0, 118.0, 104.0, 118.0, 100.0]
## How strongly each brim shape catches the same gust (wide brims drift farthest).
const HAT_WIND_RESPONSE: Array[float] = [1.25, 0.8, 1.35, 0.95, 0.85, 0.7]
const WIND_DIRECTIONS: Array[int] = [1, -1, -1, -1, 1, 1]
const HAT_NAMES: Array[String] = ["草編寬簷", "水手帽", "花邊遮陽帽", "漁夫帽", "港務便帽", "帆布鴨舌帽"]
const LEDGER_FIELDS: Array[String] = ["status", "grade", "offset", "wind_direction", "points", "contact_time"]

var assisted := false
## Calm seconds before the fixed chart starts; the catcher can already move.
var lead_in := 0.0
var time_phase := "noon"
var elapsed := 0.0
var player_x := 640.0
var player_velocity := 0.0
var axis := 0.0
var target_x := 640.0
var pointer_targeting := false
var catch_window := 0.0
var catch_pose := 0.0
var caught := 0
var misses := 0
var center_catches := 0
var edge_catches := 0
var combo := 0
var best_combo := 0
var score := 0
var finished := false
var success := false
var devil := false
var timed_out := false
var last_event := "看旗向與帽影，先走到預測落點"
var _snapshot: Dictionary = {}
var _hat_states: Array[Dictionary] = []
var _ledger: Array[Dictionary] = []
var _snapshot_revision := 0

func _init() -> void:
	reset()

func reset(p_assisted: bool = false, p_time_phase: String = "noon", p_lead_in: float = 0.0) -> void:
	assisted = p_assisted
	lead_in = clampf(p_lead_in, 0.0, 5.0) if is_finite(p_lead_in) else 0.0
	time_phase = _normalize_phase(p_time_phase)
	elapsed = 0.0
	player_x = 640.0
	player_velocity = 0.0
	axis = 0.0
	target_x = player_x
	pointer_targeting = false
	catch_window = 0.0
	catch_pose = 0.0
	caught = 0
	misses = 0
	center_catches = 0
	edge_catches = 0
	combo = 0
	best_combo = 0
	score = 0
	finished = false
	success = false
	devil = false
	timed_out = false
	last_event = "看旗向與帽影，先走到預測落點"
	_hat_states.clear()
	_ledger.clear()
	for index in HAT_COUNT:
		_hat_states.append({"active": false, "resolved": false, "x": SPAWN_X[index], "y": SPAWN_Y[index], "vx": INITIAL_VX[index], "vy": INITIAL_VY[index], "rotation": 0.0, "spin": (-1.0 if index % 2 == 0 else 1.0) * (0.48 + float(index % 3) * 0.14)})
		_ledger.append({"index": index, "name": HAT_NAMES[index], "status": "waiting", "grade": "", "offset": 0.0, "wind_direction": WIND_DIRECTIONS[index], "points": 0, "contact_time": 0.0})
	_snapshot_revision += 1
	_refresh_snapshot()

func set_axis(value: float) -> void:
	if finished or not is_finite(value):
		axis = 0.0
		return
	axis = clampf(value, -1.0, 1.0)
	pointer_targeting = false

## Mouse movement chooses a destination, but the catcher still accelerates toward it.
func set_target_x(value: float) -> void:
	if finished or not is_finite(value):
		return
	target_x = clampf(value, PLAYER_MIN_X, PLAYER_MAX_X)
	pointer_targeting = true

## A press starts a short catch pose; holding the button does not extend its timing window.
func set_catch(pressed: bool) -> void:
	if finished or not pressed:
		return
	catch_window = ASSIST_CATCH_WINDOW if assisted else CATCH_WINDOW
	catch_pose = catch_window
	last_event = "伸手救帽"
	_snapshot_revision += 1
	_refresh_snapshot()

func step(delta: float) -> Dictionary:
	if finished or not is_finite(delta) or delta <= 0.0:
		return snapshot()
	var remaining := minf(delta, MAX_FRAME_DELTA)
	while remaining > 0.000001 and not finished:
		var dt := minf(remaining, MAX_STEP)
		remaining -= dt
		_step_slice(dt)
	_snapshot_revision += 1
	_refresh_snapshot()
	return snapshot()

func snapshot() -> Dictionary:
	return _snapshot

func _step_slice(dt: float) -> void:
	if pointer_targeting:
		var distance := target_x - player_x
		var desired_acceleration := distance * 12.0 - player_velocity * 6.5
		axis = clampf(desired_acceleration / PLAYER_ACCEL, -1.0, 1.0)
	var old_player_x := player_x
	player_velocity += axis * PLAYER_ACCEL * dt
	if absf(axis) < 0.001:
		player_velocity *= exp(-PLAYER_DRAG * dt)
	player_velocity = clampf(player_velocity, -PLAYER_MAX_SPEED, PLAYER_MAX_SPEED)
	player_x = clampf(player_x + player_velocity * dt, PLAYER_MIN_X, PLAYER_MAX_X)
	if is_equal_approx(player_x, PLAYER_MIN_X) or is_equal_approx(player_x, PLAYER_MAX_X):
		player_velocity = 0.0
	catch_window = maxf(0.0, catch_window - dt)
	catch_pose = maxf(0.0, catch_pose - dt)
	var previous_elapsed := elapsed
	elapsed = minf(ROUND_SECONDS, elapsed + dt)
	for index in HAT_COUNT:
		var hat: Dictionary = _hat_states[index]
		if bool(hat["resolved"]):
			continue
		if not bool(hat["active"]):
			var spawn_at := SPAWN_TIMES[index] + lead_in
			if previous_elapsed <= spawn_at + 0.000001 and elapsed >= spawn_at:
				hat["active"] = true
			else:
				continue
		var old_y := float(hat["y"])
		var old_x := float(hat["x"])
		var wind := _gust_force(index, elapsed)
		hat["vx"] = clampf(float(hat["vx"]) + (wind - float(hat["vx"]) * 0.16) * dt, -128.0, 128.0)
		hat["vy"] = minf(float(hat["vy"]) + 218.0 * dt, 360.0)
		hat["x"] = clampf(float(hat["x"]) + float(hat["vx"]) * dt, PLAYER_MIN_X - 30.0, PLAYER_MAX_X + 30.0)
		hat["y"] = float(hat["y"]) + float(hat["vy"]) * dt
		hat["rotation"] = float(hat["rotation"]) + float(hat["spin"]) * dt + wind * dt * 0.0014
		if old_y < CATCH_Y and float(hat["y"]) >= CATCH_Y:
			var fraction := clampf((CATCH_Y - old_y) / maxf(float(hat["y"]) - old_y, 0.0001), 0.0, 1.0)
			var contact_x := lerpf(old_x, float(hat["x"]), fraction)
			var contact_player_x := lerpf(old_player_x, player_x, fraction)
			_resolve_contact(index, contact_x, contact_player_x, elapsed - dt + dt * fraction)
		elif float(hat["y"]) > CATCH_Y + 44.0:
			_resolve_miss(index, float(hat["x"]), elapsed)
	if elapsed >= ROUND_SECONDS and not finished:
		timed_out = true
		_finish()
	elif _resolved_count() >= HAT_COUNT and not finished:
		_finish()

func _resolve_contact(index: int, contact_x: float, contact_player_x: float, contact_time: float) -> void:
	var hat: Dictionary = _hat_states[index]
	var signed_offset := contact_x - contact_player_x
	var offset := absf(signed_offset)
	var radius := ASSIST_EDGE_WINDOW if assisted else EDGE_WINDOW
	var status := "miss"
	var grade := "漏接"
	var points := 0
	if catch_window > 0.0 and offset <= radius:
		caught += 1
		if offset <= (CENTER_WINDOW + (7.0 if assisted else 0.0)):
			status = "center"
			grade = "中心"
			center_catches += 1
			combo += 1
			best_combo = maxi(best_combo, combo)
			points = CENTER_POINTS + mini(STREAK_CAP, maxi(0, combo - 1) * STREAK_STEP)
		else:
			status = "edge"
			grade = "擦帽"
			edge_catches += 1
			combo = 0
			points = EDGE_POINTS
		score += points
		last_event = "中心接住 +%d" % points if status == "center" else "擦帽接住 +%d" % EDGE_POINTS
	else:
		misses += 1
		combo = 0
		last_event = "伸手太早或太晚，帽子漏接"
	catch_window = 0.0
	catch_pose = maxf(catch_pose, 0.18 if status != "miss" else 0.0)
	_set_ledger(index, status, grade, signed_offset, points, contact_time)
	hat["resolved"] = true
	_snapshot_revision += 1

func _resolve_miss(index: int, contact_x: float, contact_time: float) -> void:
	misses += 1
	combo = 0
	last_event = "帽子落過接帽線，漏接"
	_set_ledger(index, "miss", "漏接", contact_x - player_x, 0, contact_time)
	_hat_states[index]["resolved"] = true
	_snapshot_revision += 1

func _set_ledger(index: int, status: String, grade: String, offset: float, points: int, contact_time: float) -> void:
	var entry: Dictionary = _ledger[index]
	entry["status"] = status
	entry["grade"] = grade
	entry["offset"] = offset
	entry["points"] = points
	entry["contact_time"] = contact_time

func _finish() -> void:
	finished = true
	success = caught >= ORDINARY_CATCHES
	devil = success and not assisted and caught == HAT_COUNT and misses == 0 and center_catches == HAT_COUNT
	last_event = "六頂全救回，完美救援" if devil else ("救回 %d 頂，完成救援" % caught if success else "只救回 %d 頂，再試一次" % caught)
	_refresh_snapshot()

## Player-facing rule text, built from the same constants the round scores with.
static func score_rule_text() -> String:
	return "中心接住 +%d，從第二頂連續中心起每頂再加 %d（最多 +%d）；擦帽接住 +%d、漏接 0 分並中斷連續。接住至少 %d 頂得普通拍貼；未開輔助、六頂全部中心且零漏接才得小惡魔拍貼。" % [CENTER_POINTS, STREAK_STEP, STREAK_CAP, EDGE_POINTS, ORDINARY_CATCHES]

## Explains this finished formal round's ordinary/devil eligibility with its real counts.
static func qualification_text(state: Dictionary) -> String:
	var caught_count := int(state.get("caught", 0))
	var centers := int(state.get("center_catches", 0))
	var missed := int(state.get("misses", 0))
	if not bool(state.get("success", false)):
		var reason := "時間到" if bool(state.get("timed_out", false)) else "救回 %d / 6" % caught_count
		return "普通拍貼需接住至少 %d 頂（本次%s）；小惡魔需未輔助、六頂全中心且零漏接。" % [ORDINARY_CATCHES, reason]
	if bool(state.get("assisted", false)):
		return "救回 %d 頂，取得普通拍貼；輔助回合不取得小惡魔拍貼。" % caught_count
	if bool(state.get("devil", false)):
		return "六頂全部中心接住、零漏接，已達成小惡魔條件。"
	return "救回 %d 頂，取得普通拍貼。小惡魔需六頂全中心、零漏接（本次中心 %d / 6、漏接 %d）。" % [caught_count, centers, missed]

func _resolved_count() -> int:
	var count := 0
	for hat in _hat_states:
		if bool(hat["resolved"]):
			count += 1
	return count

## Signed shared sea-wind acceleration at a moment (zero between gusts).
func wind_at(at_time: float) -> float:
	var gust := _gust_at(at_time)
	if gust < 0:
		return 0.0
	var local_time := at_time - lead_in - GUST_STARTS[gust]
	var rise := smoothstep(0.0, 0.24, local_time)
	var fall := 1.0 - smoothstep(GUST_DURATION - 0.3, GUST_DURATION, local_time)
	var scale := 0.68 if assisted else 1.0
	return float(GUST_DIRECTIONS[gust]) * WIND_STRENGTH * rise * fall * scale

func _gust_at(at_time: float) -> int:
	for gust in GUST_STARTS.size():
		var local_time := at_time - lead_in - GUST_STARTS[gust]
		if local_time >= 0.0 and local_time <= GUST_DURATION:
			return gust
	return -1

func _gust_force(index: int, at_time: float) -> float:
	return wind_at(at_time) * HAT_WIND_RESPONSE[index]

func _refresh_snapshot() -> void:
	if _snapshot.is_empty():
		_snapshot = {"revision": 0, "elapsed": 0.0, "time_left": ROUND_SECONDS, "time_phase": "noon", "player_x": player_x, "player_velocity": 0.0, "catch_window": 0.0, "catch_pose": 0.0, "catch_y": CATCH_Y, "caught": 0, "misses": 0, "center_catches": 0, "edge_catches": 0, "combo": 0, "best_combo": 0, "score": 0, "assisted": false, "finished": false, "success": false, "devil": false, "timed_out": false, "last_event": "", "wind_direction": 0, "wind_strength": 0.0, "forecast_direction": 0, "forecast_seconds": 0.0, "forecast_visible": false, "wind_hat_index": -1, "next_hat_index": 0, "next_spawn_x": SPAWN_X[0], "next_spawn_time": SPAWN_TIMES[0], "airborne_count": 0, "gust_hat_count": 0, "lead_in_left": 0.0, "hats": [], "ledger": []}
	if _snapshot["hats"].is_empty():
		for index in HAT_COUNT:
			_snapshot["hats"].append({"index": index, "name": HAT_NAMES[index], "active": false, "resolved": false, "caught": false, "x": SPAWN_X[index], "y": SPAWN_Y[index], "vx": INITIAL_VX[index], "vy": INITIAL_VY[index], "rotation": 0.0, "midpoint_x": SPAWN_X[index], "midpoint_y": SPAWN_Y[index], "landing_x": SPAWN_X[index], "eta": 0.0, "spawn_time": SPAWN_TIMES[index], "wind_direction": WIND_DIRECTIONS[index], "wind_response": HAT_WIND_RESPONSE[index], "airborne_rank": 0})
			_snapshot["ledger"].append({"index": index, "name": HAT_NAMES[index], "status": "waiting", "grade": "", "offset": 0.0, "wind_direction": WIND_DIRECTIONS[index], "points": 0, "contact_time": 0.0})
	_snapshot["revision"] = _snapshot_revision
	_snapshot["elapsed"] = elapsed
	_snapshot["time_left"] = maxf(0.0, ROUND_SECONDS - elapsed)
	_snapshot["player_x"] = player_x
	_snapshot["player_velocity"] = player_velocity
	_snapshot["catch_window"] = catch_window
	_snapshot["catch_pose"] = catch_pose
	_snapshot["catch_y"] = CATCH_Y
	_snapshot["caught"] = caught
	_snapshot["misses"] = misses
	_snapshot["center_catches"] = center_catches
	_snapshot["edge_catches"] = edge_catches
	_snapshot["combo"] = combo
	_snapshot["best_combo"] = best_combo
	_snapshot["score"] = score
	_snapshot["assisted"] = assisted
	_snapshot["finished"] = finished
	_snapshot["success"] = success
	_snapshot["devil"] = devil
	_snapshot["timed_out"] = timed_out
	_snapshot["last_event"] = last_event
	var wind_direction := 0
	var wind_strength := 0.0
	var forecast_direction := 0
	var forecast_seconds := 0.0
	var forecast_visible := false
	var wind_hat_index := -1
	var gust_hat_count := 0
	var current_gust := _gust_at(elapsed)
	if current_gust >= 0:
		wind_direction = GUST_DIRECTIONS[current_gust]
		wind_strength = wind_at(elapsed)
		forecast_direction = wind_direction
	else:
		for gust in GUST_STARTS.size():
			var until_gust := GUST_STARTS[gust] + lead_in - elapsed
			if until_gust >= 0.0 and until_gust <= FORECAST_SECONDS:
				current_gust = gust
				forecast_direction = GUST_DIRECTIONS[gust]
				forecast_seconds = until_gust
				forecast_visible = true
				break
	if current_gust >= 0:
		for index in HAT_COUNT:
			if HAT_GUST[index] != current_gust:
				continue
			gust_hat_count += 1
			if wind_hat_index < 0 and not bool(_hat_states[index]["resolved"]):
				wind_hat_index = index
	_snapshot["wind_direction"] = wind_direction
	_snapshot["wind_strength"] = wind_strength
	_snapshot["forecast_direction"] = forecast_direction
	_snapshot["forecast_seconds"] = forecast_seconds
	_snapshot["forecast_visible"] = forecast_visible
	_snapshot["wind_hat_index"] = wind_hat_index
	_snapshot["gust_hat_count"] = gust_hat_count
	_snapshot["time_phase"] = time_phase
	var next_hat_index := -1
	for index in HAT_COUNT:
		if not bool(_hat_states[index]["active"]) and not bool(_hat_states[index]["resolved"]):
			next_hat_index = index
			break
	_snapshot["next_hat_index"] = next_hat_index
	_snapshot["next_spawn_x"] = SPAWN_X[next_hat_index] if next_hat_index >= 0 else -1.0
	_snapshot["next_spawn_time"] = SPAWN_TIMES[next_hat_index] + lead_in if next_hat_index >= 0 else -1.0
	_snapshot["lead_in_left"] = maxf(0.0, lead_in - elapsed)
	for index in HAT_COUNT:
		var hat: Dictionary = _hat_states[index]
		var view: Dictionary = _snapshot["hats"][index]
		view["active"] = hat["active"]
		view["resolved"] = hat["resolved"]
		view["caught"] = _ledger[index]["status"] == "center" or _ledger[index]["status"] == "edge"
		view["x"] = hat["x"]
		view["y"] = hat["y"]
		view["vx"] = hat["vx"]
		view["vy"] = hat["vy"]
		view["rotation"] = hat["rotation"]
		view["wind_direction"] = WIND_DIRECTIONS[index]
		var eta := _time_to_contact(float(hat["y"]), float(hat["vy"])) if bool(hat["active"]) and not bool(hat["resolved"]) else 0.0
		view["eta"] = eta
		if bool(hat["active"]) and not bool(hat["resolved"]):
			var midpoint := _predict_position(index, float(hat["x"]), float(hat["y"]), float(hat["vx"]), float(hat["vy"]), eta * 0.5)
			var landing := _predict_position(index, float(hat["x"]), float(hat["y"]), float(hat["vx"]), float(hat["vy"]), eta)
			view["midpoint_x"] = midpoint.x
			view["midpoint_y"] = midpoint.y
			view["landing_x"] = landing.x
		else:
			view["midpoint_x"] = SPAWN_X[index]
			view["midpoint_y"] = SPAWN_Y[index]
			view["landing_x"] = SPAWN_X[index]
		var ledger_view: Dictionary = _snapshot["ledger"][index]
		for key in LEDGER_FIELDS:
			ledger_view[key] = _ledger[index][key]
	# Rank airborne hats by time to the hand line so the view can number the route.
	var airborne := 0
	for index in HAT_COUNT:
		var view: Dictionary = _snapshot["hats"][index]
		if not bool(view["active"]) or bool(view["resolved"]):
			view["airborne_rank"] = 0
			continue
		airborne += 1
		var rank := 1
		for other in HAT_COUNT:
			var other_view: Dictionary = _snapshot["hats"][other]
			if other == index or not bool(other_view["active"]) or bool(other_view["resolved"]):
				continue
			if float(other_view["eta"]) < float(view["eta"]) or (is_equal_approx(float(other_view["eta"]), float(view["eta"])) and other < index):
				rank += 1
		view["airborne_rank"] = rank
	_snapshot["airborne_count"] = airborne

func _time_to_contact(y: float, velocity_y: float) -> float:
	var discriminant := velocity_y * velocity_y + 2.0 * 218.0 * maxf(0.0, CATCH_Y - y)
	return maxf(0.0, (sqrt(discriminant) - velocity_y) / 218.0)

func _predict_position(index: int, x: float, y: float, vx: float, vy: float, duration: float) -> Vector2:
	var remaining := duration
	var future_time := elapsed
	while remaining > 0.0001:
		var dt := minf(remaining, 0.025)
		var force := _gust_force(index, future_time)
		vx = clampf(vx + (force - vx * 0.16) * dt, -128.0, 128.0)
		vy = minf(vy + 218.0 * dt, 360.0)
		x = clampf(x + vx * dt, PLAYER_MIN_X - 30.0, PLAYER_MAX_X + 30.0)
		y += vy * dt
		future_time += dt
		remaining -= dt
	return Vector2(clampf(x, PLAYER_MIN_X - 30.0, PLAYER_MAX_X + 30.0), y)

func _normalize_phase(value: String) -> String:
	return value if value == "dawn" or value == "noon" or value == "dusk" or value == "night" else "noon"
