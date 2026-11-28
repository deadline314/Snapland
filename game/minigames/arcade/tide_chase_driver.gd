extends "res://game/minigames/arcade/arcade_driver.gd"
## 燈塔追潮, the harbour other space's finale (design/01-park/other-space.md §5b).
## Not a catalogue minigame: it earns no stickers and is started by the rift door.
##
## The tide runs backwards. The raft keeps pace on its own; which of the four
## lanes it rides decides whether it gains on 錨錨 (a lane flowing its way) or
## drops back (a lane against it). Up and down change lanes; when the raft is
## right behind 錨錨's barrel boat, the action key throws a rope. Three catches
## and 錨錨 hands the lighthouse lamp back; run out of time and it sails off.
##
## Act two: a foam line sweeps in and the lanes' currents flip. Act three: fog
## hides the barrels except where the stolen lamp's beam sweeps back over them.

const VIEW = preload("res://game/minigames/arcade/tide_chase_view.gd")

const LANES := 4
const CATCHES := 3
## Gap to 錨錨 in screen pixels: starts far, catchable under REACH.
const START_GAP := 740.0
const REACH := 70.0
const MAX_GAP := 760.0
## Gap change per second from a lane's current (positive closes the gap).
const CURRENTS := [[70.0, -60.0, 30.0, -90.0], [-80.0, 65.0, -50.0, 35.0]]
const LANE_SECONDS := 0.22
const ROPE_WINDOW := 0.9
const ROPE_COOLDOWN := 0.6
const ESCAPE_GAP := 700.0
const MISS_PUSH := 150.0
## Barrels: thrown from 錨錨, landing this far ahead of the raft, drifting back.
const THROW_WIND := 0.7
const THROW_FLIGHT := 0.55
const DRIFT := 260.0
const BUMP_SECONDS := 1.2
const BUMP_PUSH := 130.0
const FLIP_WARN := 1.5
const FLIP_EVERY := 7.0
## The stolen lamp's beam sweeps back and forth over the lanes in the fog.
const BEAM_PERIOD := 2.6
const FINALE_PHOTO := 1.8
const FINALE_END := 3.4
const POSTCARD_SECONDS := 4.0
const POSTCARD_PHOTO := 2.4

var lane := 1
var lane_from := 1
var lane_at := -99.0
var gap := START_GAP
var catches := 0
var bumps := 0
var flipped := false
var flip_at := INF
var next_throw := 0.0
var next_flip := INF
## Barrels: {lane, x (screen), thrown_at, landed, hit}.
var barrels: Array[Dictionary] = []
var throw_at := -99.0
var throw_lane := 0
var rope_at := -99.0
var caught_at := -99.0
var sprint_at := -99.0
var bump_at := -99.0
var phase := "chase"
var phase_at := -99.0
var _planned_act := 1


func _init() -> void:
	verb = "換到順流的水道追上錨錨，追近時拋繩！"
	hint = [["↑ ↓", "換水道"], ["空白鍵", "拋繩"]]
	round_seconds = 120.0
	thresholds = [400, 650, 820]
	verdicts = ["錨錨開船跑了，寄來一張明信片。", "燈塔燈拿回來了！", "追得漂亮，港口在鼓掌。", "錨錨說下次換你當船長。"]
	variants = [{"id": "ebb", "label": "退潮"}, {"id": "flood", "label": "漲潮"}]
	score_label = "追潮"
	view_script = VIEW


func reset(assisted_mode: bool, clock_text: String) -> void:
	super.reset(assisted_mode, clock_text)
	round_seconds = 120.0 * clampf(round_scale, 0.1, 1.0)
	_refresh()


func score_summary(practice: bool) -> Dictionary:
	var summary := super.score_summary(practice)
	summary.rule = "勾住錨錨三次才有獎牌：銅 %d、銀 %d、金 %d 分。壓軸不發拍貼。" % thresholds
	summary.qualification_text = "練習回合不保存。" if practice else ""
	return summary


func medal() -> int:
	return super.medal() if catches >= CATCHES else 0


func act() -> int:
	return 1 + mini(2, catches)


func current(of_lane: int) -> float:
	var row: Array = CURRENTS[1 if flipped else 0]
	var flow := float(row[clampi(of_lane, 0, LANES - 1)])
	if variant.get("id", "") == "flood":
		flow = float(CURRENTS[0 if flipped else 1][LANES - 1 - clampi(of_lane, 0, LANES - 1)])
	return flow


## Where the raft sits between lanes while it changes (for drawing and hits).
func raft_lane() -> float:
	var u := clampf((clock - lane_at) / LANE_SECONDS, 0.0, 1.0)
	return lerpf(lane_from, lane, u * u * (3.0 - 2.0 * u))


func in_reach() -> bool:
	return phase == "chase" and gap <= window(REACH) and clock - bump_at >= BUMP_SECONDS


func can_throw() -> bool:
	return phase == "chase" and clock - rope_at >= ROPE_COOLDOWN and clock - bump_at >= BUMP_SECONDS


## 0..1 across the lanes: where the lamp's beam points in the fog.
func beam() -> float:
	return 0.5 + 0.5 * sin(TAU * clock / BEAM_PERIOD)


func foggy() -> bool:
	return act() >= 3


## A barrel is visible unless it sits in the fog outside the beam.
func barrel_seen(barrel: Dictionary) -> bool:
	if not foggy():
		return true
	var u := (float(barrel.lane) + 0.5) / LANES
	return absf(u - beam()) < window(0.2)


# --- Round ------------------------------------------------------------------

func _begin_round(_variant: Dictionary) -> void:
	lane = 1
	lane_from = 1
	lane_at = -99.0
	gap = START_GAP
	catches = 0
	bumps = 0
	flipped = false
	flip_at = INF
	next_flip = INF
	barrels.clear()
	throw_at = -99.0
	throw_lane = 0
	rope_at = -99.0
	caught_at = -99.0
	sprint_at = -99.0
	bump_at = -99.0
	phase = "chase"
	phase_at = -99.0
	_planned_act = 1
	next_throw = READY_SECONDS + 2.0


func _tick(delta: float) -> void:
	if phase == "chase":
		_chase(delta)
	match phase:
		"finale":
			if clock - phase_at >= FINALE_END:
				play_time = round_seconds
		"chase":
			if round_seconds - play_time <= POSTCARD_SECONDS and catches < CATCHES:
				phase = "postcard"
				phase_at = clock
		"postcard":
			if clock - phase_at >= 1.4 and fail_at < 0.0:
				funny_fail("嘩啦！木筏翻了", false)
				sound(45)


func _chase(delta: float) -> void:
	if act() > _planned_act:
		_planned_act = act()
		if act() == 2:
			next_flip = clock + 2.0
	# Currents: the lane decides who gains. Bumped rafts only drift back.
	# Assist softens only the losing side: against the flow you drop back slower.
	var flow := current(roundi(raft_lane())) if clock - bump_at >= BUMP_SECONDS else -40.0
	gap = clampf(gap - (flow if flow > 0.0 else pace(flow)) * delta, 0.0, MAX_GAP)
	# The flip: warned by a foam line, then the lanes trade currents.
	if clock >= next_flip - FLIP_WARN and flip_at == INF:
		flip_at = next_flip
	if clock >= flip_at:
		flipped = not flipped
		flip_at = INF
		next_flip = clock + FLIP_EVERY
		say("翻潮了！", false)
		sound(60)
	# Barrels: wind up, mark the lane, throw.
	if clock >= next_throw and clock - throw_at > THROW_WIND + THROW_FLIGHT:
		throw_at = clock
		throw_lane = clampi(lane + rng.randi_range(-1, 1), 0, LANES - 1)
		next_throw = clock + rng.randf_range(2.6, 3.8) * (0.85 if act() >= 2 else 1.0)
	if throw_at >= 0.0 and clock - throw_at >= THROW_WIND and not _thrown():
		barrels.append({"lane": throw_lane, "x": 640.0, "thrown_at": clock, "hit": false, "id": throw_at})
		sound(50)
	for barrel in barrels:
		if clock - float(barrel.thrown_at) >= THROW_FLIGHT:
			barrel.x = float(barrel.x) - pace(DRIFT) * delta
			if not barrel.hit and absf(float(barrel.x) - 250.0) < 40.0 and absf(raft_lane() - float(barrel.lane)) < 0.5:
				barrel.hit = true
				bump_at = clock
				bumps += 1
				gap = minf(MAX_GAP, gap + BUMP_PUSH)
				say("撞上木桶了！", false)
				sound(40)
	var kept: Array[Dictionary] = []
	for barrel in barrels:
		if float(barrel.x) > -80.0:
			kept.append(barrel)
	barrels = kept


func _thrown() -> bool:
	for barrel in barrels:
		if float(barrel.id) == throw_at:
			return true
	return false


func _press(button: StringName) -> void:
	match button:
		&"up", &"down":
			if phase != "chase":
				return
			var next := clampi(lane + (-1 if button == &"up" else 1), 0, LANES - 1)
			if next != lane:
				lane_from = roundi(raft_lane())
				lane = next
				lane_at = clock
				sound(64)
		&"action":
			_rope()


func _rope() -> void:
	if not can_throw():
		return
	rope_at = clock
	sound(70)
	if not in_reach():
		say("繩子太短！", false)
		return
	catches += 1
	caught_at = clock
	add_score(200 + roundi(100.0 * (1.0 - gap / window(REACH))), "勾住了！")
	sound(84)
	if catches >= CATCHES:
		phase = "finale"
		phase_at = clock
		say("燈塔燈拿回來了！", true)
	else:
		gap = ESCAPE_GAP
		sprint_at = clock


func _round_over() -> void:
	if catches >= CATCHES:
		# Time left over is part of a quick chase.
		add_score(roundi(maxf(0.0, round_seconds - play_time)))


func _snapshot(into: Dictionary) -> void:
	into.lane = lane
	into.raft_lane = raft_lane()
	into.gap = gap
	into.in_reach = in_reach()
	into.catches = catches
	into.act = act()
	into.flipped = flipped
	into.currents = [current(0), current(1), current(2), current(3)]
	into.flip_warning = clampf(1.0 - (flip_at - clock) / FLIP_WARN, 0.0, 1.0) if flip_at != INF else -1.0
	into.foggy = foggy()
	into.beam = beam()
	var shown: Array = []
	for barrel in barrels:
		shown.append({"lane": barrel.lane, "x": barrel.x, "age": clock - float(barrel.thrown_at), "seen": barrel_seen(barrel), "hit": barrel.hit})
	into.barrels = shown
	into.throw_age = clock - throw_at
	into.throw_lane = throw_lane
	into.rope_at = rope_at
	into.caught_at = caught_at
	into.sprint_at = sprint_at
	into.bump_at = bump_at
	into.phase = phase
	into.phase_at = phase_at
	into.photo_ready = (phase == "finale" and clock - phase_at >= FINALE_PHOTO) or (phase == "postcard" and clock - phase_at >= POSTCARD_PHOTO)
	into.cleared = catches >= CATCHES
	into.progress_text = "勾住 %d / %d" % [catches, CATCHES]
