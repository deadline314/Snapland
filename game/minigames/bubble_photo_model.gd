extends RefCounted
class_name BubblePhotoModel

## Small deterministic model for SG-25. UI/input routing belongs to Session.
const PLAY_RECT := Rect2(300.0, 160.0, 680.0, 460.0)
const FRAME_SIZE := Vector2(300.0, 390.0)
const SUBJECT_SIZE := Vector2(206.0, 298.0) # Union alpha bounds of the cached idle poses on canonical human appearance.
const ROUND_SECONDS := 6.0
const SHUTTER_HOLD_SECONDS := 1.0
const MAX_STEP := 0.25
const BEST_POSE_TIMES: Array[float] = [2.6, 3.2, 2.9]
const TIMING_WINDOW := 2.4
const ASSIST_TIME_EXTRA := 0.45
const CENTER_SCALE := 0.35
const MIN_QUALIFYING_SCORE := 67

var assisted := false
var time_of_day := "noon"
var round := 0
var round_elapsed := 0.0
var phase := "aim" # aim, exposure, finished
var exposure_elapsed := 0.0
var frame_center := PLAY_RECT.get_center()
var subject_size := SUBJECT_SIZE
var total_score := 0
var misses := 0
var finished := false
var success := false
var devil := false
var _photos: Array[Dictionary] = []
var _snapshot_cache: Dictionary = {}
var _snapshot_revision := 0
var _composition_cache: Dictionary = {}

func _init() -> void:
	_composition_cache = {
		"target_box": Rect2(), "target_center": Vector2.ZERO, "frame_rect": Rect2(),
		"coverage": 0.0, "centering": 0.0, "timing_quality": 0.0,
		"score_preview": 0, "focus_available": false
	}
	_snapshot_cache = {
		"round": 0, "round_elapsed": 0.0, "phase": "aim", "frame_center": PLAY_RECT.get_center(),
		"frame_rect": Rect2(), "target_center": Vector2.ZERO, "target_box": Rect2(),
		"coverage": 0.0, "centering": 0.0, "timing_quality": 0.0, "score_preview": 0,
		"focus_available": false, "best_shutter_time": BEST_POSE_TIMES[0], "time_of_day": "noon",
		"light_cue": "warm window light", "assisted": false, "score": 0, "misses": 0,
		"qualified_count": 0, "perfect_count": 0, "photos": _photos,
		"finished": false, "success": false, "devil": false, "revision": 0
	}
	_refresh_snapshot()

func reset(assisted: bool = false, time_of_day: String = "noon") -> void:
	self.assisted = assisted
	self.time_of_day = _normalize_time_of_day(time_of_day)
	round = 0
	round_elapsed = 0.0
	phase = "aim"
	exposure_elapsed = 0.0
	frame_center = PLAY_RECT.get_center()
	total_score = 0
	misses = 0
	finished = false
	success = false
	devil = false
	_photos.clear()
	_snapshot_revision += 1
	_refresh_snapshot()

func set_frame_center(center: Vector2) -> void:
	if phase != "aim" or not is_finite(center.x) or not is_finite(center.y):
		return
	var half := FRAME_SIZE * 0.5
	var next_center := Vector2(
		clampf(center.x, PLAY_RECT.position.x + half.x, PLAY_RECT.end.x - half.x),
		clampf(center.y, PLAY_RECT.position.y + half.y, PLAY_RECT.end.y - half.y)
	)
	if not next_center.is_equal_approx(frame_center):
		frame_center = next_center
		_snapshot_revision += 1
	_refresh_snapshot()

## Set to the union visible-alpha size measured from the selected AvatarRenderer poses before a run.
func set_subject_size(size: Vector2) -> void:
	if phase != "aim" or round_elapsed > 0.0 or not _photos.is_empty():
		return
	if not is_finite(size.x) or not is_finite(size.y) or size.x <= 0.0 or size.y <= 0.0:
		return
	var next_size := Vector2(minf(size.x, PLAY_RECT.size.x - 20.0), minf(size.y, PLAY_RECT.size.y - 20.0))
	if next_size.is_equal_approx(subject_size):
		return
	subject_size = next_size
	_snapshot_revision += 1
	_refresh_snapshot()

func step(delta: float) -> void:
	if finished or not is_finite(delta) or delta <= 0.0:
		return
	var advance := minf(delta, MAX_STEP)
	if phase == "exposure":
		exposure_elapsed += advance
		if exposure_elapsed + 0.000001 >= SHUTTER_HOLD_SECONDS:
			_advance_round()
	elif phase == "aim":
		round_elapsed += advance
		if round_elapsed >= ROUND_SECONDS:
			_record_miss("timeout")
	_snapshot_revision += 1
	_refresh_snapshot()

func shutter() -> Dictionary:
	if finished or phase != "aim":
		return {"accepted": false, "captured": false, "score": 0}
	if round_elapsed < 1.0:
		_record_miss("early_shutter")
		_snapshot_revision += 1
		_refresh_snapshot()
		return {"accepted": true, "captured": false, "score": 0, "round": round - 1, "reason": "early_shutter"}
	var state := _compose_current()
	var timing_grade: float = float(state.timing_quality)
	var coverage_grade: float = float(state.coverage)
	var centering_grade: float = float(state.centering)
	var photo_score := int(roundi(coverage_grade * 60.0 + centering_grade * 30.0 + timing_grade * 10.0))
	var center_error: float = frame_center.distance_to(Vector2(state.target_center))
	var qualify_center_limit := 108.0 if assisted else 76.0
	var qualified := coverage_grade >= (0.68 if assisted else 0.80) and center_error <= qualify_center_limit and timing_grade >= (0.0 if assisted else 0.08) and photo_score >= MIN_QUALIFYING_SCORE
	var perfect_center_limit := 28.0 if assisted else 16.0
	var perfect_time_limit := 0.62 if assisted else 0.28
	var perfect := coverage_grade >= 0.999 and center_error <= perfect_center_limit and absf(round_elapsed - float(BEST_POSE_TIMES[round])) <= perfect_time_limit
	var shot := {
		"round": round, "captured": true, "qualified": qualified, "perfect": perfect,
		"score": photo_score, "coverage": coverage_grade, "centering": centering_grade,
		"timing_quality": timing_grade, "center_error": center_error,
		"time_of_day": time_of_day, "light_cue": _light_cue(),
		"frame_rect": state.frame_rect, "target_box": state.target_box,
		"shutter_time": round_elapsed
	}
	_photos.append(shot)
	total_score += photo_score
	_snapshot_revision += 1
	phase = "exposure"
	exposure_elapsed = 0.0
	_refresh_snapshot()
	return {"accepted": true, "captured": true, "qualified": qualified, "perfect": perfect, "score": photo_score, "coverage": coverage_grade, "centering": centering_grade, "timing_quality": timing_grade, "round": round, "hold_seconds": SHUTTER_HOLD_SECONDS, "time_of_day": time_of_day}

## Returns a stable dictionary and stable photo ledger; callers must not mutate it.
func snapshot() -> Dictionary:
	_refresh_snapshot()
	return _snapshot_cache

func _compose_current() -> Dictionary:
	var target_box := _target_box()
	var frame_rect := Rect2(frame_center - FRAME_SIZE * 0.5, FRAME_SIZE)
	var intersection := frame_rect.intersection(target_box)
	var coverage := 0.0 if intersection.size.x <= 0.0 or intersection.size.y <= 0.0 else clampf(intersection.get_area() / target_box.get_area(), 0.0, 1.0)
	var center_error := frame_center.distance_to(target_box.get_center())
	var center_scale := FRAME_SIZE.length() * CENTER_SCALE
	var centering := clampf(1.0 - center_error / center_scale, 0.0, 1.0)
	var time_width := TIMING_WINDOW + (ASSIST_TIME_EXTRA if assisted else 0.0)
	var timing_quality := clampf(1.0 - absf(round_elapsed - float(BEST_POSE_TIMES[round])) / time_width, 0.0, 1.0)
	var focus_available := absf(round_elapsed - float(BEST_POSE_TIMES[round])) <= (0.6 + (0.2 if assisted else 0.0))
	_composition_cache["target_box"] = target_box
	_composition_cache["target_center"] = target_box.get_center()
	_composition_cache["frame_rect"] = frame_rect
	_composition_cache["coverage"] = coverage
	_composition_cache["centering"] = centering
	_composition_cache["timing_quality"] = timing_quality
	_composition_cache["score_preview"] = int(roundi(coverage * 60.0 + centering * 30.0 + timing_quality * 10.0))
	_composition_cache["focus_available"] = focus_available
	return _composition_cache

func _target_box() -> Rect2:
	# Three repeatable portrait paths with different drift; poses stay inside the safe work area.
	var x := 0.0
	var y := 390.0 + sin(round_elapsed * 1.15 + float(round) * 0.8) * 22.0
	match round:
		0: x = 465.0 + sin(round_elapsed * 0.74) * 115.0
		1: x = 760.0 - sin(round_elapsed * 0.68 + 0.3) * 112.0
		_: x = 640.0 + sin(round_elapsed * 0.83 + 1.1) * 128.0
	return Rect2(Vector2(x, y) - subject_size * 0.5, subject_size)

func _record_miss(reason: String) -> void:
	var state := _compose_current()
	var miss := {
		"round": round, "captured": false, "qualified": false, "perfect": false,
		"score": 0, "coverage": float(state.coverage), "centering": float(state.centering),
		"timing_quality": float(state.timing_quality), "time_of_day": time_of_day,
		"light_cue": _light_cue(), "reason": reason, "target_box": state.target_box,
		"frame_rect": state.frame_rect
	}
	_photos.append(miss)
	misses += 1
	_advance_round()

func _advance_round() -> void:
	if round >= 2:
		finished = true
		phase = "finished"
		var qualified_count := 0
		var perfect_count := 0
		for photo in _photos:
			if bool(photo.get("qualified", false)): qualified_count += 1
			if bool(photo.get("perfect", false)): perfect_count += 1
		success = qualified_count >= 2
		devil = perfect_count == 3
		return
	round += 1
	round_elapsed = 0.0
	exposure_elapsed = 0.0
	phase = "aim"

func _refresh_snapshot() -> void:
	var state := _compose_current()
	var qualified_count := 0
	var perfect_count := 0
	for photo in _photos:
		if bool(photo.get("qualified", false)): qualified_count += 1
		if bool(photo.get("perfect", false)): perfect_count += 1
	_snapshot_cache["round"] = round
	_snapshot_cache["round_elapsed"] = round_elapsed
	_snapshot_cache["phase"] = phase
	_snapshot_cache["frame_center"] = frame_center
	_snapshot_cache["frame_rect"] = state.frame_rect
	_snapshot_cache["target_center"] = state.target_center
	_snapshot_cache["target_box"] = state.target_box
	_snapshot_cache["coverage"] = state.coverage
	_snapshot_cache["centering"] = state.centering
	_snapshot_cache["timing_quality"] = state.timing_quality
	_snapshot_cache["score_preview"] = state.score_preview
	_snapshot_cache["focus_available"] = state.focus_available
	_snapshot_cache["best_shutter_time"] = BEST_POSE_TIMES[round] if round < BEST_POSE_TIMES.size() else 0.0
	_snapshot_cache["time_of_day"] = time_of_day
	_snapshot_cache["light_cue"] = _light_cue()
	_snapshot_cache["assisted"] = assisted
	_snapshot_cache["score"] = total_score
	_snapshot_cache["misses"] = misses
	_snapshot_cache["qualified_count"] = qualified_count
	_snapshot_cache["perfect_count"] = perfect_count
	_snapshot_cache["photos"] = _photos
	_snapshot_cache["finished"] = finished
	_snapshot_cache["success"] = success
	_snapshot_cache["devil"] = devil
	_snapshot_cache["revision"] = _snapshot_revision

func _normalize_time_of_day(value: String) -> String:
	return value if value in ["dawn", "noon", "dusk", "sunset", "night"] else "noon"

func _light_cue() -> String:
	match time_of_day:
		"dawn": return "soft apricot morning light"
		"dusk", "sunset": return "amber harbor light"
		"night": return "cool lantern fill"
		_: return "warm-neutral daylight"
