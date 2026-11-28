extends "res://game/minigames/arcade/arcade_driver.gd"
## 雲影快門: on the cloud-top photo deck the traveller stands at a camera on a
## tripod. A big cloud in the viewfinder keeps changing shape, and the call
## goes up for one: 兔子, 鯨魚 or 茶壺. Press the shutter just as the cloud turns
## into it. Before the real one a look-alike sometimes forms first (a cat for
## the rabbit, a fish for the whale, a mug for the teapot). A shot at the wrong
## cloud catches a cloud shaped like the traveller's own head, sticking its
## tongue out at them. The cloud changes faster and faster as the round goes on.
## Rules only: the picture lives in cloud_shutter_view.gd.
##
## A shape is nine blobs, Vector3(x, y, radius) in a 0..1 box; the cloud melts
## from one shape to the next blob by blob.

const View = preload("res://game/minigames/arcade/cloud_shutter_view.gd")
const SHAPES := {
	"rabbit": [Vector3(0.5, 0.66, 0.2), Vector3(0.5, 0.4, 0.14), Vector3(0.43, 0.12, 0.055), Vector3(0.57, 0.12, 0.055), Vector3(0.44, 0.24, 0.06),
		Vector3(0.56, 0.24, 0.06), Vector3(0.74, 0.72, 0.07), Vector3(0.38, 0.86, 0.08), Vector3(0.62, 0.86, 0.08)],
	"cat": [Vector3(0.5, 0.66, 0.2), Vector3(0.5, 0.42, 0.14), Vector3(0.41, 0.27, 0.06), Vector3(0.59, 0.27, 0.06), Vector3(0.45, 0.34, 0.07),
		Vector3(0.55, 0.34, 0.07), Vector3(0.78, 0.52, 0.07), Vector3(0.38, 0.86, 0.08), Vector3(0.62, 0.86, 0.08)],
	"whale": [Vector3(0.3, 0.56, 0.17), Vector3(0.5, 0.53, 0.2), Vector3(0.68, 0.57, 0.15), Vector3(0.82, 0.6, 0.09), Vector3(0.95, 0.46, 0.07),
		Vector3(0.96, 0.72, 0.07), Vector3(0.32, 0.25, 0.05), Vector3(0.26, 0.14, 0.05), Vector3(0.38, 0.14, 0.05)],
	"fish": [Vector3(0.36, 0.56, 0.13), Vector3(0.52, 0.55, 0.15), Vector3(0.66, 0.57, 0.12), Vector3(0.78, 0.58, 0.08), Vector3(0.92, 0.46, 0.07),
		Vector3(0.92, 0.7, 0.07), Vector3(0.5, 0.38, 0.06), Vector3(0.52, 0.72, 0.06), Vector3(0.4, 0.5, 0.06)],
	"teapot": [Vector3(0.45, 0.6, 0.19), Vector3(0.55, 0.6, 0.19), Vector3(0.5, 0.34, 0.1), Vector3(0.5, 0.2, 0.05), Vector3(0.78, 0.48, 0.08),
		Vector3(0.9, 0.35, 0.065), Vector3(0.19, 0.48, 0.08), Vector3(0.17, 0.66, 0.07), Vector3(0.5, 0.8, 0.12)],
	"mug": [Vector3(0.44, 0.6, 0.2), Vector3(0.56, 0.6, 0.2), Vector3(0.44, 0.42, 0.12), Vector3(0.56, 0.42, 0.12), Vector3(0.6, 0.66, 0.1),
		Vector3(0.4, 0.66, 0.1), Vector3(0.75, 0.52, 0.07), Vector3(0.76, 0.66, 0.06), Vector3(0.5, 0.8, 0.12)],
	"head": [Vector3(0.5, 0.56, 0.25), Vector3(0.3, 0.32, 0.08), Vector3(0.4, 0.22, 0.08), Vector3(0.5, 0.19, 0.09), Vector3(0.6, 0.22, 0.08),
		Vector3(0.7, 0.32, 0.08), Vector3(0.25, 0.58, 0.06), Vector3(0.75, 0.58, 0.06), Vector3(0.5, 0.78, 0.1)],
}
const TARGETS := {"rabbit": "兔子", "whale": "鯨魚", "teapot": "茶壺"}
const DECOYS := {"rabbit": "cat", "whale": "fish", "teapot": "mug"}
const PERFECT_POINTS := 30
const GOOD_POINTS := 20
const WRONG_POINTS := 10
const STREAK_CAP := 5
## Seconds to melt into the next shape and to hold it, at the start and at the end of play.
const MORPH_FIRST := 1.0
const MORPH_LAST := 0.5
const HOLD_FIRST := 0.9
const HOLD_LAST := 0.45
const DECOY_FIRST := 0.2
const DECOY_LAST := 0.6
## How far into a melt the cloud already counts as the new shape.
const FORMED := 0.85
const COOLDOWN := 0.5
const FACE_SECONDS := 1.4

## The shape the cloud is leaving and the one it is turning into.
var from_shape: Array = []
var to_shape: Array = []
var to_name := ""
var morph_at := 0.0
var morph_seconds := 1.0
var hold_seconds := 0.9
## The shape called for, and when.
var target := "rabbit"
var called_at := -99.0
var shot_at := -99.0
var shot_hit := false
var shot_shape := ""
var shot_label := ""
var face_at := -99.0
var streak := 0
var best_streak := 0
var hits := 0
var perfects := 0
var wrongs := 0
var passes := 0

var _queue: Array[String] = []
var _fillers := 0
var _demo := false


func _init() -> void:
	verb = "雲變成指定的形狀時按下快門！"
	hint = [["空白鍵", "按快門"]]
	round_seconds = 45.0
	thresholds = [140, 290, 380]
	verdicts = [
		"相機裡只有一片白白的天空。",
		"銅牌！有幾張看得出是什麼。",
		"銀牌！雲都排隊等你拍。",
		"金牌！你拍的雲可以出寫真集了。",
	]
	variants = [
		{"id": "slow", "label": "慢慢變"},
		{"id": "quick", "label": "雲跑得快", "speed": 0.75},
		{"id": "tricky", "label": "騙人雲", "decoy": 0.3},
	]
	score_label = "拍照得分"
	view_script = View


func _begin_round(_chosen: Dictionary) -> void:
	from_shape = _filler()
	to_shape = from_shape.duplicate()
	to_name = "filler"
	morph_at = clock
	morph_seconds = MORPH_FIRST
	hold_seconds = HOLD_FIRST
	shot_at = -99.0
	shot_hit = false
	shot_shape = ""
	face_at = -99.0
	streak = 0
	best_streak = 0
	hits = 0
	perfects = 0
	wrongs = 0
	passes = 0
	_queue.clear()
	_fillers = 0
	_demo = true
	# The countdown calls a rabbit, melts the cloud into one and takes its picture.
	_call("rabbit", false)
	_queue.clear()
	_melt_to("rabbit")


func _warm_up(_delta: float) -> void:
	_advance_shapes()
	if to_name == target and formed() >= 1.0 and clock - shot_at > 2.0 and clock - morph_at > morph_seconds + hold_seconds * 0.5:
		_shoot()


func _go() -> void:
	_demo = false
	shot_at = -99.0
	_call(_pick_target(), true)


func _tick(_delta: float) -> void:
	_advance_shapes()


func _press(button: StringName) -> void:
	if not button in [&"action", &"down", &"up", &"second"] or clock - shot_at < COOLDOWN or clock - face_at < FACE_SECONDS:
		return
	_shoot()


func _snapshot(into: Dictionary) -> void:
	into.blobs = blobs()
	into.to_name = to_name
	into.target = target
	into.target_label = TARGETS.get(target, "")
	into.called_at = called_at
	into.formed = formed()
	into.shot_at = shot_at
	into.shot_hit = shot_hit
	into.shot_shape = shot_shape
	into.shot_label = shot_label
	into.face_at = face_at
	into.face_seconds = FACE_SECONDS
	into.streak = streak
	into.cooldown = COOLDOWN


## How far the cloud has melted into its next shape (0..1; 1 while holding it).
func formed() -> float:
	return clampf((clock - morph_at) / morph_seconds, 0.0, 1.0)


## The cloud's blobs now, melting from the last shape into the next.
func blobs() -> Array:
	var t := smoothstep(0.0, 1.0, formed())
	var out: Array = []
	for index in to_shape.size():
		out.append((from_shape[index] as Vector3).lerp(to_shape[index], t))
	return out


func _speed() -> float:
	return float(variant.get("speed", 1.0))


func _pick_target() -> String:
	var names := TARGETS.keys()
	var next: String = names[rng.randi() % names.size()]
	if next == target:
		next = names[(names.find(next) + 1 + rng.randi() % (names.size() - 1)) % names.size()]
	return next


## Call for a shape: a filler or two first, sometimes its look-alike, then the real thing.
func _call(shape: String, playing: bool) -> void:
	target = shape
	called_at = clock
	_queue.clear()
	var fillers := 1 if not playing else 1 + (rng.randi() % 2 if heat() < 0.6 else 0)
	for filler in fillers:
		_queue.append("filler")
	var decoy := lerpf(DECOY_FIRST, DECOY_LAST, heat()) + float(variant.get("decoy", 0.0))
	if playing and rng.randf() < decoy:
		_queue.append(DECOYS[shape])
		_queue.append("filler")
	_queue.append(shape)


## Move on to the next shape once this one has formed and been held.
func _advance_shapes() -> void:
	if clock - face_at < FACE_SECONDS:
		return
	if clock - morph_at < morph_seconds + hold_seconds:
		return
	if to_name == target and not _demo:
		# The called shape went by without a picture.
		passes += 1
		streak = 0
		sound(45)
		_call(_pick_target(), true)
	elif to_name == target:
		_call(target, false)
	var next: String = _queue.pop_front() if not _queue.is_empty() else "filler"
	_melt_to(next)


func _melt_to(next: String) -> void:
	from_shape = blobs()
	to_name = next
	to_shape = _filler() if next == "filler" else SHAPES[next].duplicate()
	morph_at = clock
	morph_seconds = lerpf(MORPH_FIRST, MORPH_LAST, heat()) * _speed()
	hold_seconds = window(lerpf(HOLD_FIRST, HOLD_LAST, heat()) * _speed())
	if next == "filler":
		hold_seconds *= 0.5


## A lumpy nothing-in-particular cloud.
func _filler() -> Array:
	var out: Array = []
	for index in 9:
		var angle := index * TAU / 9.0 + rng.randf_range(-0.3, 0.3)
		var reach := rng.randf_range(0.08, 0.26)
		out.append(Vector3(0.5 + cos(angle) * reach * 1.3, 0.55 + sin(angle) * reach, rng.randf_range(0.09, 0.17)))
	return out


func _shoot() -> void:
	shot_at = clock
	sound(88)
	var hit := to_name == target and formed() >= FORMED
	shot_hit = hit
	shot_shape = to_name
	shot_label = str(TARGETS.get(target, ""))
	if _demo:
		if hit:
			_call(target, false)
		return
	if hit:
		var perfect := formed() >= 1.0
		hits += 1
		streak += 1
		best_streak = maxi(best_streak, streak)
		if perfect:
			perfects += 1
		add_score((PERFECT_POINTS if perfect else GOOD_POINTS) + mini(streak, STREAK_CAP) * 2, "喀嚓！%s！" % TARGETS[target])
		_call(_pick_target(), true)
		# The cloud drifts on into something else after its portrait.
		_melt_to(_queue.pop_front())
		return
	# Wrong cloud: it turns into the traveller's own head and pulls a face.
	wrongs += 1
	streak = 0
	add_score(-WRONG_POINTS)
	face_at = clock
	shot_shape = "head"
	from_shape = blobs()
	to_shape = SHAPES["head"].duplicate()
	to_name = "head"
	morph_at = clock
	morph_seconds = 0.3
	hold_seconds = FACE_SECONDS - 0.3
	sound(40)
	funny_fail("略～", wrongs > 1)
