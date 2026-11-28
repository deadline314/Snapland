extends "res://game/minigames/arcade/arcade_driver.gd"
## 倒影首映照, the welcome other space's finale (design/01-park/other-space.md §5).
## Not a catalogue minigame: it earns no stickers and is started by the rift door.
##
## Slide the viewfinder along the fountain rim (← →) and press the shutter when
## 倒倒 strikes a pose inside it. The pool's reflection acts first: it does the
## next move and lights the next pose half a beat before the body does, so the
## reflection is the telegraph. Six photos pop the troupe's six balloons and the
## curtain falls on a bow; run out of time and 倒倒 takes your camera for a selfie.
##
## Three acts: dashes only; dashes and confetti; then 倒倒 dives and the
## reflection comes back left-right mirrored. Getting hit only jams the camera.

const VIEW = preload("res://game/minigames/arcade/reflection_premiere_view.gd")

const BALLOONS := 6
## Viewfinder and walker.
const X_MIN := 150.0
const X_MAX := 1130.0
const FRAME_HALF := 95.0
const SPEED := 560.0
## 倒倒 roams between these.
const BOSS_MIN := 230.0
const BOSS_MAX := 1050.0
## How far ahead the reflection runs, per act.
const LEADS: Array[float] = [0.8, 0.55, 0.55]
## Beat lengths in seconds; a dash follows the rig's dash move.
const DRIFT := [1.4, 1.1, 1.0]
const DASH := 2.0
const DASH_STRIKE := [0.6, 0.8]
const CONFETTI := 1.7
const CONFETTI_LAND := 1.3
const POSE := 1.6
## The pose window inside a pose beat (the rig's 亮相 and hold).
const POSE_OPEN := 0.48
const POSE_CLOSE := 1.08
const INTERLUDE := 2.4
const SWAP := 1.6
const SHUTTER_COOLDOWN := 0.45
const BUMP_SECONDS := 1.5
const LENS_SECONDS := 2.2
const DASH_REACH := 70.0
const SPLAT_REACH := 75.0
const CURTAIN_PHOTO := 1.6
const CURTAIN_END := 3.2
const SELFIE_SECONDS := 4.0
const SELFIE_FLASH := 1.6
const SELFIE_PHOTO := 2.2
const PLAN_AHEAD := 3.5

var frame_x := 640.0
var captures := 0
var bumps := 0
## Beats from now into the future: {kind, start, length, x_from, x_to, act, spots, captured, hit}.
var beats: Array[Dictionary] = []
var shutter_at := -99.0
var capture_at := -99.0
var last_quality := 0
var bump_at := -99.0
var lens_at := -99.0
var wipes := 0
var phase := "show"
var phase_at := -99.0
var popped: Array[String] = []
var _dir := 0
var _last_dir := 0
var _planned_act := 1
## Position in the current act's cycle of beats.
var _cycle_step := 0


func _init() -> void:
	verb = "倒影先亮的地方，就是倒倒等一下亮相的地方！"
	hint = [["← →", "移動取景框"], ["空白鍵", "快門"]]
	round_seconds = 150.0
	# Bronze is the curtain call itself; see medal().
	thresholds = [600, 900, 1080]
	verdicts = ["倒倒拿走了相機，幫你拍了一張。", "謝幕成功！劇團收下六張劇照。", "構圖漂亮，倒倒想要簽名照。", "首映海報就用你的！"]
	variants = [{"id": "matinee", "label": "午場"}, {"id": "soiree", "label": "晚場"}]
	score_label = "劇照"
	view_script = VIEW


## The finale runs longer than an arcade round; the shared clamp is for minigames.
func reset(assisted_mode: bool, clock_text: String) -> void:
	super.reset(assisted_mode, clock_text)
	round_seconds = 150.0 * clampf(round_scale, 0.1, 1.0)
	_refresh()


## The arcade rule line talks about stickers; the finale gives none.
func score_summary(practice: bool) -> Dictionary:
	var summary := super.score_summary(practice)
	summary.rule = "拍滿六張謝幕才有獎牌：銅 %d、銀 %d、金 %d 分。壓軸不發拍貼。" % thresholds
	summary.qualification_text = "練習回合不保存。" if practice else ""
	return summary


## Medals only count once the curtain has fallen on all six photos.
func medal() -> int:
	return super.medal() if captures >= BALLOONS else 0


func act() -> int:
	return 1 + mini(2, captures / 2)


func lead() -> float:
	var seconds: float = LEADS[act() - 1]
	return seconds * 1.5 if assisted else seconds


func mirrored() -> bool:
	return act() >= 3


func can_shoot() -> bool:
	return phase == "show" and clock - shutter_at >= SHUTTER_COOLDOWN and clock - bump_at >= BUMP_SECONDS and not lens_dirty()


func lens_dirty() -> bool:
	return clock - lens_at < LENS_SECONDS and wipes < 2


## Where 倒倒 is and what it is doing at driver time `at`: {x, y, kind, move, t, beat}.
func boss_at(at: float) -> Dictionary:
	for beat in beats:
		if at >= beat.start and at < beat.start + beat.length:
			return _pose_of(beat, at - beat.start)
	if not beats.is_empty() and at >= beats[-1].start:
		return _pose_of(beats[-1], beats[-1].length)
	return {"x": 640.0, "y": 0.0, "kind": "drift", "move": "idle", "t": at, "beat": {}}


## The reflection: the body `lead()` seconds from now, mirrored left-right in act three.
func reflection() -> Dictionary:
	var ahead := boss_at(clock + lead())
	if mirrored():
		ahead.x = 1280.0 - float(ahead.x)
	return ahead


func pose_open(at := clock) -> bool:
	var now := boss_at(at)
	if now.kind != "pose" or now.beat.get("captured", false):
		return false
	var half := (POSE_CLOSE - POSE_OPEN) * 0.5
	var middle := POSE_OPEN + half
	return absf(float(now.t) - middle) <= window(half)


# --- Round ------------------------------------------------------------------

func _begin_round(_variant: Dictionary) -> void:
	frame_x = 640.0
	captures = 0
	bumps = 0
	beats.clear()
	shutter_at = -99.0
	capture_at = -99.0
	last_quality = 0
	bump_at = -99.0
	lens_at = -99.0
	wipes = 0
	phase = "show"
	phase_at = -99.0
	popped.clear()
	_dir = 0
	_last_dir = 0
	_planned_act = 1
	_cycle_step = 0
	# The countdown: 倒倒 drifts in and its reflection shows a pose early.
	_push("drift", 0.0, 1.2, 640.0, 520.0)
	_push("pose", 1.2, POSE, 520.0, 520.0)
	_plan()


func _warm_up(_delta: float) -> void:
	_plan()


func _go() -> void:
	# Play opens on a fresh drift from wherever the demo left 倒倒.
	var x := float(boss_at(clock).x)
	beats.clear()
	_push("drift", clock, DRIFT[0], x, _pick_x(x))
	beats[-1].act = 1
	_cycle_step = 1
	_plan()


func _tick(delta: float) -> void:
	if phase == "show":
		frame_x = clampf(frame_x + _dir * SPEED * delta, X_MIN, X_MAX)
	_plan()
	_resolve_attacks()
	match phase:
		"curtain":
			if clock - phase_at >= CURTAIN_END:
				play_time = round_seconds
		"show":
			if round_seconds - play_time <= SELFIE_SECONDS and captures < BALLOONS:
				phase = "selfie"
				phase_at = clock
				_cut_to("selfie")
		"selfie":
			if clock - phase_at >= SELFIE_FLASH and fail_at < 0.0:
				funny_fail("咔嚓！倒倒幫你拍了一張", false)
				sound(52)


func _press(button: StringName) -> void:
	match button:
		&"left", &"right":
			_dir = -1 if button == &"left" else 1
			if lens_dirty() and _last_dir != 0 and _dir != _last_dir:
				wipes += 1
				if wipes >= 2:
					say("擦乾淨了", true)
			_last_dir = _dir
		&"action":
			_shutter()


func _release(button: StringName) -> void:
	if (button == &"left" and _dir < 0) or (button == &"right" and _dir > 0):
		_dir = 0


func _shutter() -> void:
	if not can_shoot():
		return
	shutter_at = clock
	sound(76)
	var now := boss_at(clock)
	var dx := absf(frame_x - float(now.x))
	if not pose_open() or dx > FRAME_HALF:
		say("拍到空氣" if not pose_open() else "沒入框", false)
		return
	var beat: Dictionary = now.beat
	beat.captured = true
	var middle := (POSE_OPEN + POSE_CLOSE) * 0.5
	var timing := 1.0 - clampf(absf(float(now.t) - middle) / window((POSE_CLOSE - POSE_OPEN) * 0.5), 0.0, 1.0)
	last_quality = 100 + roundi(60.0 * (1.0 - dx / FRAME_HALF)) + roundi(40.0 * timing)
	captures += 1
	capture_at = clock
	popped.append("balloon_%d" % captures)
	add_score(last_quality, "劇照！" if last_quality < 180 else "完美劇照！")
	sound(84)
	if captures >= BALLOONS:
		phase = "curtain"
		phase_at = clock
		_cut_to("bow")
		say("謝幕！", true)


func _round_over() -> void:
	_dir = 0


# --- Choreography -----------------------------------------------------------

## Keep beats planned far enough ahead for the reflection to show them.
func _plan() -> void:
	while beats.is_empty() or beats[-1].start + beats[-1].length < clock + PLAN_AHEAD:
		var last: Dictionary = beats[-1] if not beats.is_empty() else {"start": 0.0, "length": 0.0, "x_to": 640.0, "kind": "drift"}
		var start: float = last.start + last.length
		var x: float = last.x_to
		var current := 1 + mini(2, captures / 2)
		if phase != "show":
			_push("bow" if phase == "curtain" else "selfie", start, 60.0, x, x)
			continue
		if current > _planned_act:
			_planned_act = current
			_cycle_step = 0
			_push("interlude", start, INTERLUDE, x, 640.0)
			if current == 3:
				_push("swap", start + INTERLUDE, SWAP, 640.0, 640.0)
			continue
		var cycle := _cycle(current)
		var kind: String = cycle[_cycle_step % cycle.size()]
		_cycle_step += 1
		match kind:
			"drift":
				_push("drift", start, DRIFT[current - 1], x, _pick_x(x))
			"dash":
				var target := clampf(x + (rng.randf_range(300.0, 520.0) * (1.0 if x < 640.0 else -1.0)), BOSS_MIN, BOSS_MAX)
				_push("dash", start, DASH, x, target)
			"confetti":
				_push("confetti", start, CONFETTI, x, x)
			"pose":
				_push("pose", start, POSE, x, x)
		beats[-1].act = current
	# Forget beats long past.
	while beats.size() > 2 and beats[1].start + beats[1].length < clock - 2.0:
		beats.pop_front()


## End the choreography now and hold `kind` (the bow or the selfie) to the end.
func _cut_to(kind: String) -> void:
	var x := float(boss_at(clock).x)
	var kept: Array[Dictionary] = []
	for beat in beats:
		if beat.start < clock:
			kept.append(beat)
	beats = kept
	if not beats.is_empty():
		beats[-1].length = minf(beats[-1].length, clock - beats[-1].start)
	_push(kind, clock, 60.0, x, x)


func _cycle(current: int) -> Array:
	match current:
		1: return ["drift", "dash", "drift", "pose"]
		2: return ["drift", "dash", "drift", "confetti", "drift", "pose"]
	return ["drift", "confetti", "drift", "dash", "drift", "pose"]


func _push(kind: String, start: float, length: float, x_from: float, x_to: float) -> void:
	beats.append({"kind": kind, "start": start, "length": length, "x_from": x_from, "x_to": x_to, "act": 0, "spots": [], "captured": false, "hit": false})


func _pick_x(from: float) -> float:
	var x := rng.randf_range(BOSS_MIN, BOSS_MAX)
	if absf(x - from) < 220.0:
		x = clampf(from + (300.0 if from < 640.0 else -300.0), BOSS_MIN, BOSS_MAX)
	return x


func _pose_of(beat: Dictionary, t: float) -> Dictionary:
	var u := clampf(t / maxf(0.01, beat.length), 0.0, 1.0)
	var x: float = beat.x_from
	var y := 0.0
	var move := "idle"
	match str(beat.kind):
		"drift", "interlude":
			x = lerpf(beat.x_from, beat.x_to, smoothstep(0.0, 1.0, u))
			move = "idle" if beat.kind == "drift" else "confetti"
		"dash":
			move = "dash"
			var strike := clampf((t - DASH_STRIKE[0]) / (DASH_STRIKE[1] - DASH_STRIKE[0]), 0.0, 1.0)
			x = lerpf(beat.x_from, beat.x_to, 1.0 - pow(1.0 - strike, 3.0))
		"confetti":
			move = "confetti"
		"pose":
			move = "pose"
		"bow":
			# Spring into the 亮相 and hold it for the curtain-call photo.
			move = "pose"
			t = minf(t, 0.9)
		"selfie":
			move = "confetti"
			t = fmod(t, CONFETTI)
		"swap":
			# Down into the pool and back up the other way round.
			y = 230.0 * sin(PI * u)
	return {"x": x, "y": y, "kind": str(beat.kind), "move": move, "t": t, "beat": beat}


func _resolve_attacks() -> void:
	if phase != "show":
		return
	var now := boss_at(clock)
	var beat: Dictionary = now.beat
	if beat.is_empty() or beat.hit:
		return
	match str(beat.kind):
		"dash":
			if now.t >= DASH_STRIKE[0] and now.t <= DASH_STRIKE[1] + 0.05:
				var low := minf(beat.x_from, float(now.x)) - DASH_REACH
				var high := maxf(beat.x_from, float(now.x)) + DASH_REACH
				if frame_x >= low and frame_x <= high and clock - bump_at >= BUMP_SECONDS:
					beat.hit = true
					bump_at = clock
					bumps += 1
					say("被撞歪了！", false)
					sound(40)
		"confetti":
			if (beat.spots as Array).is_empty():
				# Three landing spots: one on the walker, two well away from it.
				var spots := [frame_x]
				for side: float in [-1.0, 1.0]:
					spots.append(clampf(frame_x + side * rng.randf_range(260.0, 420.0), X_MIN, X_MAX))
				beat.spots = spots
			if now.t >= CONFETTI_LAND:
				beat.hit = true
				for spot: float in beat.spots:
					if absf(frame_x - spot) < SPLAT_REACH:
						lens_at = clock
						wipes = 0
						bumps += 1
						say("鏡頭被彩紙糊住了！左右晃一晃", false)
						sound(45)
						break


func _snapshot(into: Dictionary) -> void:
	var body := boss_at(clock)
	var mirror := reflection()
	into.frame_x = frame_x
	into.captures = captures
	into.bumps = bumps
	into.act = act()
	into.lead = lead()
	into.mirrored = mirrored()
	into.boss = {"x": body.x, "y": body.y, "kind": body.kind, "move": body.move, "t": body.t}
	into.reflection = {"x": mirror.x, "y": mirror.y, "kind": mirror.kind, "move": mirror.move, "t": mirror.t}
	into.pose_open = pose_open()
	into.reflection_open = pose_open(clock + lead())
	into.dash = {}
	into.spots = []
	var beat: Dictionary = body.beat
	if not beat.is_empty() and beat.kind == "dash" and float(body.t) < DASH_STRIKE[1]:
		into.dash = {"from": beat.x_from, "to": beat.x_to, "t": body.t}
	if not beat.is_empty() and beat.kind == "confetti":
		into.spots = (beat.spots as Array).duplicate()
		into.confetti_t = body.t
	into.shutter_at = shutter_at
	into.capture_at = capture_at
	into.last_quality = last_quality
	into.bump_at = bump_at
	into.lens_dirty = lens_dirty()
	into.lens_at = lens_at
	into.wipes = wipes
	into.phase = phase
	into.phase_at = phase_at
	into.popped = popped.duplicate()
	into.photo_ready = (phase == "curtain" and clock - phase_at >= CURTAIN_PHOTO) or (phase == "selfie" and clock - phase_at >= SELFIE_PHOTO)
	into.cleared = captures >= BALLOONS
	into.progress_text = "劇照 %d / %d" % [captures, BALLOONS]
