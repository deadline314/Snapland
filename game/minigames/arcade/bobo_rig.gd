extends RefCounted
## 啵啵, keeper of 反重力糖廠 (design/01-park/other-space.md §5c): a strawberry
## jelly chef, a glossy wobbling dome with bubbles caught inside, a tall
## toque, two little jelly nubs for arms and a ladle. Copies and the real one
## are this same rig solved at different times: the real one runs late.

const Rig = preload("res://game/minigames/arcade/part_rig.gd")
const Pixels = preload("res://game/minigames/arcade/arcade_pixels.gd")

const STAGE := Vector2i(96, 100)
const ROOT := Vector2(48, 88)
const MOVES := ["wobble", "hop", "split", "scooped", "pop", "cheer"]
## One wobble beat; the copies keep it together and the real one lags it.
const BEAT := 0.8

const JELLY := Color("#ef5f7a")
const JELLY_LIGHT := Color("#ff9db0")
const JELLY_DEEP := Color("#b8344f")
const TOQUE := Color("#fff8ee")
const TOQUE_SHADE := Color("#e2d7c8")
const PLUM := Color("#3b2440")
const CREAM := Color("#fff4e2")
const MOUTH := Color("#7a2f3a")
const STEEL := Color("#b9b4c8")


static func build() -> Rig:
	var rig: Rig = Rig.new()
	rig.add_part("body", _body(), Vector2(18, 29))
	rig.add_part("band", _band(), Vector2(9, 4), "body", Vector2(0, -25), 1, {"drag": 0.25})
	rig.add_part("toque", _toque(), Vector2(10, 17), "band", Vector2(0, -3), 1, {"drag": 0.8, "wobble": Vector2(4, 1.6)})
	rig.add_part("eyes", [_eyes(0), _eyes(1), _eyes(2), _eyes(3)], Vector2(9, 3.5), "body", Vector2(0, -15), 2, {"blink": true})
	rig.add_part("mouth", [_mouth(0), _mouth(1), _mouth(2)], Vector2(5, 2), "body", Vector2(0, -9), 2)
	rig.add_part("arm_l", _arm(), Vector2(5, 3), "body", Vector2(-15, -10), -1, {"rot": 20.0, "drag": 0.6, "wobble": Vector2(8, 1.2)})
	rig.add_part("arm_r", _arm(), Vector2(5, 3), "body", Vector2(15, -10), 2, {"rot": -20.0, "drag": 0.6, "wobble": Vector2(8, 1.3)})
	rig.add_part("ladle", _ladle(), Vector2(2, 2), "arm_r", Vector2(6, 2), 1, {"rot": -30.0, "drag": 0.5})
	_poses(rig)
	_moves(rig)
	return rig


static func _poses(rig: Rig) -> void:
	rig.add_pose("rest", {})
	rig.add_pose("sag", {"body": {"squash": 0.14, "at": Vector2(0, 1)}, "arm_l": {"rot": 14.0}, "arm_r": {"rot": -14.0}})
	rig.add_pose("spring", {"body": {"squash": -0.1, "at": Vector2(0, -1)}, "arm_l": {"rot": -12.0}, "arm_r": {"rot": 12.0}})
	rig.add_pose("crouch", {"body": {"squash": 0.3, "at": Vector2(0, 1)}, "eyes": {"frame": 2}, "arm_l": {"rot": 40.0}, "arm_r": {"rot": -40.0}})
	rig.add_pose("leap", {"body": {"squash": -0.28}, "eyes": {"frame": 1}, "mouth": {"frame": 1}, "arm_l": {"rot": -70.0}, "arm_r": {"rot": 70.0}})
	rig.add_pose("land", {"body": {"squash": 0.34, "at": Vector2(0, 1)}, "eyes": {"frame": 2}, "arm_l": {"rot": 50.0}, "arm_r": {"rot": -50.0}})
	rig.add_pose("wide", {"body": {"squash": 0.45, "at": Vector2(0, 1)}, "eyes": {"frame": 2}, "mouth": {"frame": 1}, "arm_l": {"rot": 80.0}, "arm_r": {"rot": -80.0}})
	rig.add_pose("lifted", {"body": {"squash": -0.22, "at": Vector2(0, -6), "rot": 8.0}, "eyes": {"frame": 1}, "mouth": {"frame": 0}, "arm_l": {"rot": -90.0}, "arm_r": {"rot": 90.0}})
	rig.add_pose("swell", {"body": {"squash": 0.2, "scale": Vector2(1.25, 1.25)}, "eyes": {"frame": 3}, "mouth": {"frame": 2}, "arm_l": {"rot": 90.0}, "arm_r": {"rot": -90.0}})
	rig.add_pose("cheer", {"body": {"squash": -0.12, "at": Vector2(0, -3)}, "eyes": {"frame": 1}, "mouth": {"frame": 1}, "arm_l": {"rot": -120.0}, "arm_r": {"rot": 120.0}, "toque": {"rot": -8.0}})


static func _moves(rig: Rig) -> void:
	# One wobble per beat: sag, spring back past rest, settle.
	rig.add_move("wobble", [[0.0, "rest", "linear"], [BEAT * 0.3, "sag", "out"], [BEAT * 0.62, "spring", "back"], [BEAT, "rest", "inout"]], true)
	rig.add_move("hop", [[0.0, "rest", "linear"], [0.15, "crouch", "in"], [0.32, "leap", "out"], [0.6, "leap", "inout"], [0.72, "land", "in"], [0.95, "rest", "back"]])
	rig.add_move("split", [[0.0, "rest", "linear"], [0.35, "wide", "inout"], [0.5, "leap", "out"], [0.9, "rest", "back"]])
	rig.add_move("scooped", [[0.0, "rest", "linear"], [0.15, "crouch", "in"], [0.4, "lifted", "out"], [1.2, "lifted", "linear"]])
	rig.add_move("pop", [[0.0, "rest", "linear"], [0.25, "swell", "in"], [0.4, "swell", "linear"]])
	rig.add_move("cheer", [[0.0, "rest", "linear"], [0.3, "cheer", "back"], [0.7, "spring", "inout"], [1.0, "cheer", "back"]], true)


# --- Parts ------------------------------------------------------------------

## A glossy dome of jelly with a light rim, a darker core and bubbles inside.
static func _body() -> Texture2D:
	return Pixels.bake("bobo|body", Vector2i(36, 28), func(x: int, y: int) -> Color:
		var u := (x + 0.5 - 18.0) / 18.0
		var v := (y + 0.5) / 28.0
		var dome := 1.0 - u * u
		if v < 1.0 - dome * 1.05 or (v > 0.93 and absf(u) > 0.96):
			return Pixels.CLEAR
		var tone := JELLY.lerp(JELLY_DEEP, clampf(v * 0.7 + absf(u) * 0.3, 0.0, 1.0) * 0.6)
		if Vector2(x - 9.0, y - 8.0).length() < 2.2 or (x >= 6 and x <= 7 and y >= 11 and y <= 16):
			return Color("#ffe2ea")
		if Pixels.noise(x / 3, y / 3, 81) > 0.9:
			tone = JELLY_LIGHT
		if y >= 26:
			tone = JELLY_DEEP.darkened(0.1)
		return Pixels.rounded(tone, Vector2(u, v * 2.0 - 1.0)))


static func _band() -> Texture2D:
	return Pixels.bake("bobo|band", Vector2i(18, 5), func(x: int, y: int) -> Color:
		return TOQUE_SHADE if y >= 3 else TOQUE)


## The puffed top of a chef's toque, pleated.
static func _toque() -> Texture2D:
	return Pixels.bake("bobo|toque", Vector2i(20, 18), func(x: int, y: int) -> Color:
		var puff := Vector2((x + 0.5 - 10.0) / 10.0, (y + 0.5 - 8.0) / 8.5)
		if puff.length_squared() > 1.0 and not (y > 12 and absf(x + 0.5 - 10.0) < 7.0):
			return Pixels.CLEAR
		var tone := TOQUE_SHADE if x % 5 == 0 and y > 4 else TOQUE
		return Pixels.rounded(tone, puff * 0.6))


## 0 open, 1 happy arcs, 2 squeezed, 3 dizzy spirals.
static func _eyes(kind: int) -> Texture2D:
	return Pixels.bake("bobo|eyes|%d" % kind, Vector2i(18, 7), func(x: int, y: int) -> Color:
		for eye in [Vector2(4.5, 3.5), Vector2(13.5, 3.5)]:
			var d := Vector2(x + 0.5 - eye.x, y + 0.5 - eye.y)
			match kind:
				0:
					if (d / Vector2(2.6, 3.2)).length_squared() <= 1.0:
						return CREAM if d.x < -0.5 and d.y < -0.8 else PLUM
				1:
					if absf(d.y + 0.8 - absf(d.x) * 0.7) < 0.7 and absf(d.x) < 2.8:
						return PLUM
				2:
					if absf(d.y) < 0.7 and absf(d.x) < 2.6:
						return PLUM
				3:
					var ring := d.length()
					if absf(ring - 1.0 - fposmod(atan2(d.y, d.x) / TAU, 1.0) * 1.6) < 0.6 and ring < 3.0:
						return PLUM
		return Pixels.CLEAR)


## 0 smile, 1 open "o", 2 wobbly line.
static func _mouth(kind: int) -> Texture2D:
	return Pixels.bake("bobo|mouth|%d" % kind, Vector2i(10, 6), func(x: int, y: int) -> Color:
		var dx := x + 0.5 - 5.0
		match kind:
			0:
				return MOUTH if y == 1 + int(roundf((dx / 4.0) * (dx / 4.0) * -2.0 + 2.0)) and absf(dx) < 4.0 else Pixels.CLEAR
			1:
				return MOUTH if Vector2(dx / 2.2, (y + 0.5 - 3.0) / 2.6).length_squared() <= 1.0 else Pixels.CLEAR
		return MOUTH if absf(dx) < 4.0 and y == 2 + int(roundf(sin(dx * 1.6))) else Pixels.CLEAR)


static func _arm() -> Texture2D:
	return Pixels.bake("bobo|arm", Vector2i(10, 7), func(x: int, y: int) -> Color:
		var nub := Vector2((x + 0.5 - 5.0) / 5.0, (y + 0.5 - 3.5) / 3.5)
		return Pixels.rounded(JELLY, nub) if nub.length_squared() <= 1.0 else Pixels.CLEAR)


## A steel ladle: long handle and a deep bowl.
static func _ladle() -> Texture2D:
	return Pixels.bake("bobo|ladle", Vector2i(16, 9), func(x: int, y: int) -> Color:
		if x < 10:
			return Pixels.metal(STEEL, x, y) if y >= 2 and y <= 3 else Pixels.CLEAR
		var bowl := Vector2((x + 0.5 - 12.5) / 3.5, (y + 0.5 - 4.5) / 4.0)
		return Pixels.rounded(STEEL, bowl) if bowl.length_squared() <= 1.0 else Pixels.CLEAR)
