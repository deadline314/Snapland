extends "res://game/minigames/arcade/arcade_driver.gd"
## 折鏡迷箱: a spotlight in the tent roof shines straight down onto a hand mirror
## the hero holds overhead. Hold left or right to tilt it; the reflected beam
## sweeps across the ring and pops the twinkling balloons along its sides (a
## gold one needs two seconds of light). Striped pillars stand in the way and
## balloons drift behind them. Tilt too far and the beam lands on the hero's own
## face: a sunglasses-shaped tan. Left alone the mirror bounces the light
## straight back up, where no balloon ever floats, so an untouched round scores
## nothing. Rules only: the picture lives in mirror_beam_view.gd.

const View = preload("res://game/minigames/arcade/mirror_beam_view.gd")
## Where the light lands on the mirror, in screen pixels.
const MIRROR := Vector2(640, 430)
## Tilt in radians: the beam leaves at twice the tilt from straight up.
const MAX_TILT := 0.92
const FACE_TILT := 0.8
const TURN_SPEED := 1.3
## Balloons keep to the sides: never closer than this to the middle column.
const SIDE_GAP := 110.0
const FIELD := Rect2(120, 190, 1040, 300)
const BALLOON_RADIUS := 30.0
const POP_SECONDS := 0.2
const GOLD_SECONDS := 2.0
const BALLOON_POINTS := 10
## Pops in quick succession add a streak bonus per pop, up to STREAK_CAP.
const STREAK_SECONDS := 1.5
const STREAK_BONUS := 2
const STREAK_CAP := 5
const GOLD_POINTS := 40
const SPAWN_EARLY := 1.1
const SPAWN_LATE := 0.45
const CROWD_EARLY := 3
const CROWD_LATE := 6
const DRIFT_EARLY := 40.0
const DRIFT_LATE := 120.0
const GOLD_EARLY := 0.08
const GOLD_LATE := 0.2
const LIFE_SECONDS := 6.0
const FACE_SECONDS := 0.45
const TAN_SECONDS := 2.0
const PILLAR_WIDTH := 36.0
const PILLARS := {
	"few": [Rect2(372, 350, PILLAR_WIDTH, 150), Rect2(872, 350, PILLAR_WIDTH, 150)],
	"many": [Rect2(250, 330, PILLAR_WIDTH, 170), Rect2(462, 390, PILLAR_WIDTH, 110), Rect2(782, 390, PILLAR_WIDTH, 110), Rect2(994, 330, PILLAR_WIDTH, 170)],
}

## "aim" or "tanned" (the beam just scorched the hero's face).
var phase := "aim"
var phase_at := 0.0
var tilt := 0.0
## -1, 0 or 1 from the held arrows.
var turn := 0
## Each: {id, at (Vector2), vel, side -1|1, gold, born, lit (seconds of light), popped_at}.
var balloons: Array[Dictionary] = []
var pillars: Array = []
var beam_end := Vector2.ZERO
var on_face := 0.0
var tans := 0
var pops := 0
var golds := 0
var _next_spawn := 0.0
var streak := 0
var _last_pop := -99.0
var _next_id := 0
var _held_left := false
var _held_right := false


func _init() -> void:
	verb = "左右轉鏡子，把光反射到氣球上！"
	hint = [["← →", "轉鏡子"]]
	round_seconds = 45.0
	thresholds = [130, 360, 600]
	verdicts = [
		"只曬黑了自己的眼睛。",
		"銅牌！氣球破了幾顆，臉還算白。",
		"銀牌！光打到哪破到哪。",
		"金牌！你是帳篷裡最亮的人，而且沒戴墨鏡。",
	]
	variants = [
		{"id": "standard", "label": "氣球大會", "pillars": "few", "gold": 1.0, "drift": 1.0},
		{"id": "pillars", "label": "柱子迷宮", "pillars": "many", "gold": 1.0, "drift": 0.9},
		{"id": "golden", "label": "金色之夜", "pillars": "few", "gold": 2.5, "drift": 0.8},
	]
	score_label = "打氣球得分"
	view_script = View


func _begin_round(chosen: Dictionary) -> void:
	pillars = PILLARS[str(chosen.get("pillars", "few"))]
	balloons.clear()
	tilt = 0.0
	tans = 0
	pops = 0
	streak = 0
	_last_pop = -99.0
	golds = 0
	on_face = 0.0
	_next_id = 0
	_phase("aim")
	_trace()


## The countdown shows the idea: the mirror swings right and pops a balloon.
func _warm_up(delta: float) -> void:
	if balloons.is_empty() and clock < 0.3:
		balloons.append(_balloon(Vector2(800, 290), 1, false))
		balloons[0].vel = Vector2.ZERO
	tilt = minf(tilt + 0.35 * delta, 0.37)
	_trace()
	_light_balloons(delta, false)
	_clear_popped()


func _go() -> void:
	balloons.clear()
	tilt = 0.0
	on_face = 0.0
	_next_spawn = 0.4
	# An arrow held through the countdown starts turning as play begins.
	_held_left = _held.values().has(&"left")
	_held_right = _held.values().has(&"right")
	turn = int(_held_right) - int(_held_left)
	_phase("aim")
	_trace()


func _tick(delta: float) -> void:
	_move_balloons(delta)
	_clear_popped()
	if phase == "tanned":
		if clock - phase_at >= TAN_SECONDS:
			tilt = 0.0
			on_face = 0.0
			_phase("aim")
		_trace()
		return
	tilt = clampf(tilt + float(turn) * TURN_SPEED * delta, -MAX_TILT, MAX_TILT)
	_trace()
	if face_lit():
		on_face += delta
		if on_face >= window(FACE_SECONDS):
			_tan()
		return
	on_face = maxf(0.0, on_face - delta * 2.0)
	_light_balloons(delta, true)
	if play_time >= _next_spawn:
		_next_spawn = play_time + lerpf(SPAWN_EARLY, SPAWN_LATE, heat()) * rng.randf_range(0.8, 1.2)
		if _live_count() < roundi(lerpf(CROWD_EARLY, CROWD_LATE, heat())):
			_spawn()


func _press(button: StringName) -> void:
	if button == &"left":
		_held_left = true
	elif button == &"right":
		_held_right = true
	turn = int(_held_right) - int(_held_left)


func _release(button: StringName) -> void:
	if button == &"left":
		_held_left = false
	elif button == &"right":
		_held_right = false
	turn = int(_held_right) - int(_held_left)


func _snapshot(into: Dictionary) -> void:
	into.phase = phase
	into.phase_at = phase_at
	into.tilt = tilt
	into.turn = turn
	into.balloons = balloons
	into.pillars = pillars
	into.beam_end = beam_end
	into.face_lit = face_lit() and phase == "aim"
	into.on_face = clampf(on_face / window(FACE_SECONDS), 0.0, 1.0)
	into.tans = tans
	into.mirror = MIRROR
	into.gold_seconds = gold_seconds()
	into.streak = streak


## Direction the reflected beam leaves the mirror.
func beam_direction() -> Vector2:
	return Vector2(sin(2.0 * tilt), -cos(2.0 * tilt))


func face_lit() -> bool:
	return absf(tilt) >= FACE_TILT


func gold_seconds() -> float:
	return pace(GOLD_SECONDS)


## Follow the beam to the first pillar or the edge of the ring.
func _trace() -> void:
	if face_lit():
		beam_end = MIRROR + Vector2(0, 70)
		return
	var direction := beam_direction()
	var at := MIRROR
	for step in 160:
		var next := at + direction * 8.0
		if next.y < FIELD.position.y - 70.0 or next.x < 40.0 or next.x > 1240.0 or next.y > MIRROR.y + 40.0:
			at = next
			break
		var blocked := false
		for pillar: Rect2 in pillars:
			if pillar.has_point(next):
				blocked = true
		if blocked:
			break
		at = next
	beam_end = at


func _light_balloons(delta: float, scoring: bool) -> void:
	var direction := beam_direction()
	var reach := (beam_end - MIRROR).length()
	for balloon in balloons:
		if float(balloon.popped_at) >= 0.0:
			continue
		var offset: Vector2 = balloon.at - MIRROR
		var along := offset.dot(direction)
		var lit := not face_lit() and along > 0.0 and along < reach + BALLOON_RADIUS and absf(offset.cross(direction)) < BALLOON_RADIUS
		if lit:
			balloon.lit = float(balloon.lit) + delta
			var needed := gold_seconds() if bool(balloon.gold) else POP_SECONDS
			if float(balloon.lit) >= needed:
				_pop(balloon, scoring)
		elif bool(balloon.gold):
			# A gold balloon must be lit for two seconds in a row.
			balloon.lit = 0.0
		else:
			balloon.lit = maxf(0.0, float(balloon.lit) - delta)


func _pop(balloon: Dictionary, scoring: bool) -> void:
	balloon.popped_at = clock
	sound(88 if bool(balloon.gold) else 76)
	if not scoring:
		return
	pops += 1
	streak = mini(streak + 1, STREAK_CAP) if clock - _last_pop <= STREAK_SECONDS else 0
	_last_pop = clock
	var bonus := STREAK_BONUS * streak
	if bool(balloon.gold):
		golds += 1
		add_score(GOLD_POINTS + bonus, "金色！+%d" % (GOLD_POINTS + bonus))
	else:
		add_score(BALLOON_POINTS + bonus, "啪！+%d" % (BALLOON_POINTS + bonus) if streak >= 2 else "啪！")


func _move_balloons(delta: float) -> void:
	for balloon in balloons:
		if float(balloon.popped_at) >= 0.0:
			continue
		var side := float(balloon.side)
		var at: Vector2 = balloon.at + Vector2(balloon.vel) * delta
		var inner := 640.0 + side * SIDE_GAP
		var outer := FIELD.position.x if side < 0.0 else FIELD.end.x
		var low := minf(inner, outer)
		var high := maxf(inner, outer)
		if at.x < low or at.x > high:
			balloon.vel = Vector2(-balloon.vel.x, balloon.vel.y)
			at.x = clampf(at.x, low, high)
		if at.y < FIELD.position.y or at.y > FIELD.end.y:
			balloon.vel = Vector2(balloon.vel.x, -balloon.vel.y)
			at.y = clampf(at.y, FIELD.position.y, FIELD.end.y)
		balloon.at = at


func _clear_popped() -> void:
	for balloon in balloons.duplicate():
		var popped := float(balloon.popped_at)
		if (popped >= 0.0 and clock - popped > 0.6) or (popped < 0.0 and clock - float(balloon.born) > LIFE_SECONDS + (3.0 if bool(balloon.gold) else 0.0)):
			balloons.erase(balloon)


func _live_count() -> int:
	var count := 0
	for balloon in balloons:
		count += int(float(balloon.popped_at) < 0.0)
	return count


func _spawn() -> void:
	var side := -1 if rng.randf() < 0.5 else 1
	var gold := rng.randf() < lerpf(GOLD_EARLY, GOLD_LATE, heat()) * float(variant.get("gold", 1.0))
	var x := rng.randf_range(FIELD.position.x + 20.0, 640.0 - SIDE_GAP - 20.0) if side < 0 else rng.randf_range(640.0 + SIDE_GAP + 20.0, FIELD.end.x - 20.0)
	balloons.append(_balloon(Vector2(x, rng.randf_range(FIELD.position.y + 20.0, FIELD.end.y - 20.0)), side, gold))


func _balloon(at: Vector2, side: int, gold: bool) -> Dictionary:
	_next_id += 1
	var speed := lerpf(DRIFT_EARLY, DRIFT_LATE, heat()) * float(variant.get("drift", 1.0)) * (0.5 if gold else 1.0)
	var heading := Vector2.from_angle(rng.randf() * TAU) * Vector2(1.0, 0.5)
	return {"id": _next_id, "at": at, "vel": heading.normalized() * speed, "side": side, "gold": gold, "born": clock,
		"lit": 0.0, "popped_at": -1.0, "tone": rng.randi() % 4}


func _tan() -> void:
	tans += 1
	sound(40)
	# The first scorch of a round is a free look at the tan lines.
	funny_fail("好燙！", tans > 1)
	_phase("tanned")


func _phase(next_phase: String) -> void:
	phase = next_phase
	phase_at = clock
