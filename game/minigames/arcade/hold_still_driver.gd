extends "res://game/minigames/arcade/arcade_driver.gd"
## 螢火蟲長曝光: a long exposure of fireflies over the moss pond. While the
## shutter is open every button shakes the camera and smears the picture; fake
## prompts, a mosquito, an itchy nose and wrong lamps all beg for a press. Only
## the real shutter lamp (round, with the camera mark and a double chime) ends
## the exposure. Rules only: the picture lives in hold_still_view.gd.

const View = preload("res://game/minigames/arcade/hold_still_view.gd")
## Seconds to settle before the shutter opens; presses are still harmless.
const FRAME_SECONDS := 0.9
const PRINT_SECONDS := 1.5
## A ruined photo is shown a little longer: that is the show.
const RUINED_SECONDS := 1.9
## Length of the exposure at the first and at the last second of play.
const EXPOSE_FIRST := 3.0
const EXPOSE_LAST := 6.0
## Seconds the real lamp stays lit before the picture overexposes.
const SHUTTER_WINDOW := 0.9
const DECOY_SECONDS := 0.9
## Decoys keep this far from the real lamp so the two never overlap.
const DECOY_CLEARANCE := 0.55
const POINTS_PER_SECOND := 10.0
const LAMP_SLOTS := 3
const CHIME_GAP := 0.12
## Heat (0..1 through the round) from which the itch and fake lamps join, and
## from which a fake lamp may copy the real colour (never the shape or mark).
const LAMP_HEAT := 0.25
const LOOKALIKE_HEAT := 0.55
const DEMO_EXPOSURE := 1.2
const DEMO_PRESS_AFTER := 0.4

## "frame" -> "expose" -> "print", then the next shot.
var phase := "frame"
var phase_at := 0.0
var shot := 0
var exposure := EXPOSE_FIRST
## Clock at which the shutter opened.
var shot_at := 0.0
## Seconds the shutter was open when the photo was taken or ruined.
var exposed := 0.0
## Seconds into the exposure at which the real lamp lights (two in a double exposure).
var lamp_times: Array[float] = []
var lamps_done := 0
var lamp_slot := 1
var lit := false
var lamp_at := -99.0
## Temptations of this shot: {kind, time, slot, look, at}; `at` is the clock when shown.
var decoys: Array[Dictionary] = []
## "" while exposing, then "crisp", "smear" (a press shook the camera) or "over" (nobody pressed).
var result := ""
var crisp_count := 0
var ruined := 0
var photo_seed := 0

var _shown := 0
var _chime_due := -1.0
var _demo := false


func _init() -> void:
	verb = "忍住別按！真快門燈亮才按！"
	hint = [["任何鍵", "只在真快門燈亮時按一下"]]
	round_seconds = 50.0
	thresholds = [60, 140, 220]
	verdicts = [
		"相簿裡全是鬼影，螢火蟲嚇得搬家了。",
		"銅牌！手是穩的，心有點浮。",
		"銀牌！蚊子叮你都沒在怕。",
		"金牌！你比腳架還像腳架。",
	]
	variants = [
		{"id": "standard", "label": "標準長曝光"},
		{"id": "flash", "label": "閃光與怪聲", "flash": true},
		{"id": "moving", "label": "會換位置的快門燈", "moving": true},
		{"id": "double", "label": "雙重曝光", "double": true},
	]
	score_label = "長曝光得分"
	view_script = View


func _begin_round(_chosen: Dictionary) -> void:
	shot = 0
	crisp_count = 0
	ruined = 0
	# The countdown takes one short picture for the player, with no temptations.
	_demo = true
	_open_shot(DEMO_EXPOSURE, [DEMO_EXPOSURE], 1, [])
	_phase("expose")
	shot_at = clock


func _warm_up(_delta: float) -> void:
	if phase == "expose":
		_run_exposure()
		if lit and clock - lamp_at >= DEMO_PRESS_AFTER:
			lit = false
			exposed = clock - shot_at
			result = "crisp"
			sound(79)
			_phase("print")


func _go() -> void:
	_demo = false
	shot = 0
	_next_shot()


func _tick(_delta: float) -> void:
	var waited := clock - phase_at
	match phase:
		"frame":
			if waited >= FRAME_SECONDS:
				_phase("expose")
				shot_at = clock
		"expose":
			_run_exposure()
			if lit and clock - lamp_at > shutter_window():
				_finish("over")
		"print":
			if waited >= (PRINT_SECONDS if result == "crisp" else RUINED_SECONDS):
				_next_shot()


## Any button at all: while the shutter is open it either takes the picture or shakes the camera.
func _press(_button: StringName) -> void:
	if phase != "expose":
		return
	if not lit:
		_finish("smear")
		return
	lit = false
	lamps_done += 1
	sound(79)
	if lamps_done >= lamp_times.size():
		_finish("crisp")
	else:
		say("第一次曝光好了，再等一次！", true)


func _snapshot(into: Dictionary) -> void:
	into.phase = phase
	into.phase_at = phase_at
	into.shot = shot
	into.exposed = clock - shot_at if phase == "expose" else exposed
	into.lit = lit
	into.lamp_at = lamp_at
	into.lamp_slot = lamp_slot
	into.lamp_slots = LAMP_SLOTS if bool(variant.get("moving", false)) else 1
	into.lamps_needed = lamp_times.size()
	into.lamps_done = lamps_done
	into.decoys = decoys
	into.decoy_seconds = DECOY_SECONDS
	into.result = result
	into.photo_seed = photo_seed
	into.crisp_count = crisp_count


## Seconds the real lamp waits for the press; longer with assist.
func shutter_window() -> float:
	return window(SHUTTER_WINDOW)


func _next_shot() -> void:
	shot += 1
	var length := lerpf(EXPOSE_FIRST, EXPOSE_LAST, heat())
	var lamps: Array[float] = [length]
	if bool(variant.get("double", false)):
		lamps = [length * 0.5, length]
	var moving := bool(variant.get("moving", false))
	var slot := rng.randi() % LAMP_SLOTS if moving else 1
	var kinds: Array[String] = ["prompt", "mosquito"]
	if heat() >= LAMP_HEAT:
		kinds.append_array(["itch", "lamp", "lamp"])
	var plan: Array[Dictionary] = []
	for index in 1 + int(heat() * 3.0):
		var at := rng.randf_range(0.5, length - DECOY_CLEARANCE)
		for lamp_time in lamps:
			# Slide a temptation off the real lamp's own moment.
			if at > lamp_time - DECOY_CLEARANCE and at < lamp_time + SHUTTER_WINDOW:
				at = lamp_time - DECOY_CLEARANCE - 0.4 * rng.randf()
		var kind := kinds[rng.randi() % kinds.size()]
		var look := rng.randi() % (3 if heat() >= LOOKALIKE_HEAT else 2)
		var place := rng.randi() % LAMP_SLOTS
		if kind == "lamp":
			# A fake lamp never lights the real lamp's socket when the lamp can move.
			place = (slot + 1 + rng.randi() % (LAMP_SLOTS - 1)) % LAMP_SLOTS if moving else 1
		if bool(variant.get("flash", false)):
			kind = "flash"
		plan.append({"kind": kind, "time": maxf(at, 0.3), "slot": place, "look": look, "at": -99.0})
	plan.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.time) < float(b.time))
	_open_shot(length, lamps, slot, plan)
	_phase("frame")


func _open_shot(length: float, lamps: Array[float], slot: int, plan: Array[Dictionary]) -> void:
	exposure = length
	lamp_times = lamps
	lamp_slot = slot
	decoys = plan
	lamps_done = 0
	lit = false
	lamp_at = -99.0
	result = ""
	exposed = 0.0
	_shown = 0
	_chime_due = -1.0
	photo_seed = rng.randi() % 1000


## Show the temptations that are due and light the real lamp at its moment.
func _run_exposure() -> void:
	var open := clock - shot_at
	while _shown < decoys.size() and open >= float(decoys[_shown].time):
		decoys[_shown].at = clock
		# One low note: never the real lamp's double chime.
		sound(57 if str(decoys[_shown].kind) == "lamp" else 62)
		_shown += 1
	if _chime_due >= 0.0 and clock >= _chime_due:
		_chime_due = -1.0
		sound(88)
	if not lit and lamps_done < lamp_times.size() and open >= lamp_times[lamps_done]:
		lit = true
		lamp_at = clock
		sound(84)
		_chime_due = clock + CHIME_GAP


func _finish(outcome: String) -> void:
	result = outcome
	exposed = clock - shot_at
	lit = false
	if outcome == "crisp":
		crisp_count += 1
		var points := roundi(exposure * POINTS_PER_SECOND)
		add_score(points, "清晰！+%d" % points)
		sound(86)
	else:
		ruined += 1
		var words := "手震了！" if outcome == "smear" else "過曝了！"
		sound(50)
		# The first ruined photo of a round is a free look at the ghost.
		funny_fail(words, ruined > 1)
	_phase("print")


func _phase(next_phase: String) -> void:
	phase = next_phase
	phase_at = clock
