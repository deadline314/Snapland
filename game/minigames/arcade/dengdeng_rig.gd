extends RefCounted
## 燈燈, keeper of 午夜移動市 (design/01-park/other-space.md §5d): a night-market
## vendor whose head is a red paper lantern with a face on it, in a plum robe
## and apron, holding out a pole lantern whose beam is how it sees. Drawn
## facing right; the view mirrors it to face left.

const Rig = preload("res://game/minigames/arcade/part_rig.gd")
const Pixels = preload("res://game/minigames/arcade/arcade_pixels.gd")

const STAGE := Vector2i(110, 110)
const ROOT := Vector2(45, 96)
const MOVES := ["idle", "alert", "turn", "startled", "hop", "bow"]

const ROBE := Color("#5c3f74")
const ROBE_DARK := Color("#3f2a54")
const APRON := Color("#f2e9d4")
const LANTERN := Color("#e2493f")
const LANTERN_GLOW := Color("#ffb45e")
const RIB := Color("#9a2f2a")
const CAP := Color("#2f2440")
const TASSEL := Color("#ffd166")
const SKIN := Color("#f1c8a0")
const POLE := Color("#8a6a42")
const PAPER := Color("#fff0cd")
const INK := Color("#2f2440")


static func build() -> Rig:
	var rig: Rig = Rig.new()
	rig.add_part("robe", _robe(), Vector2(12, 31))
	rig.add_part("head", [_head(0), _head(1), _head(2)], Vector2(11, 23), "robe", Vector2(0, -27), 1, {"drag": 0.25})
	rig.add_part("tassel", _tassel(), Vector2(2, 1), "head", Vector2(0, 0), 0, {"drag": 0.9, "wobble": Vector2(10, 1.1)})
	rig.add_part("arm_back", _arm(), Vector2(2, 2), "robe", Vector2(-6, -22), -1, {"rot": 20.0, "drag": 0.5, "wobble": Vector2(5, 1.7)})
	rig.add_part("arm", _arm(), Vector2(2, 2), "robe", Vector2(6, -22), 2, {"rot": -70.0, "drag": 0.4})
	rig.add_part("pole", _pole(), Vector2(1, 2), "arm", Vector2(0, 11), 2, {"rot": -20.0, "drag": 0.35})
	rig.add_part("lamp", _lamp(), Vector2(5, 1), "pole", Vector2(0, 26), 1, {"upright": true, "drag": 1.0, "wobble": Vector2(8, 1.3)})
	_poses(rig)
	_moves(rig)
	return rig


static func _poses(rig: Rig) -> void:
	rig.add_pose("rest", {})
	rig.add_pose("sway", {"robe": {"rot": 3.0, "squash": 0.03}, "head": {"rot": -4.0}, "arm": {"rot": -6.0}})
	# Before the snap turn: freeze, lean back, the face goes "hm?".
	rig.add_pose("hm", {"robe": {"rot": -8.0, "squash": 0.08}, "head": {"rot": 14.0, "at": Vector2(-1, 1), "frame": 1}, "arm": {"rot": 18.0}, "pole": {"rot": 15.0}})
	rig.add_pose("whip", {"robe": {"rot": 10.0, "squash": -0.1}, "head": {"rot": -16.0, "frame": 1}, "arm": {"rot": -40.0}, "pole": {"rot": -30.0}})
	# Tapped on the shoulder: jumps out of its robe, head flame flaring.
	rig.add_pose("jump", {"robe": {"at": Vector2(0, -10), "squash": -0.2, "rot": -6.0}, "head": {"at": Vector2(0, -6), "rot": 20.0, "frame": 2, "scale": Vector2(1.15, 1.15)},
		"arm": {"rot": -150.0}, "arm_back": {"rot": 150.0}, "pole": {"rot": 30.0}})
	rig.add_pose("land", {"robe": {"squash": 0.25}, "head": {"frame": 2}, "arm": {"rot": 10.0}, "arm_back": {"rot": 40.0}})
	rig.add_pose("crouch", {"robe": {"squash": 0.22, "at": Vector2(0, 1)}, "arm": {"rot": 10.0}})
	rig.add_pose("air", {"robe": {"squash": -0.18, "at": Vector2(0, -8)}, "arm": {"rot": -100.0}, "arm_back": {"rot": 100.0}})
	rig.add_pose("bow", {"robe": {"rot": 22.0, "squash": 0.06}, "head": {"rot": 30.0, "at": Vector2(3, 2), "frame": 0}, "arm": {"rot": -110.0}, "arm_back": {"rot": 60.0}})


static func _moves(rig: Rig) -> void:
	rig.add_move("idle", [[0.0, "rest", "linear"], [1.1, "sway", "inout"], [2.2, "rest", "inout"]], true)
	rig.add_move("alert", [[0.0, "rest", "linear"], [0.35, "hm", "in"], [0.8, "hm", "linear"]])
	rig.add_move("turn", [[0.0, "hm", "linear"], [0.12, "whip", "out"], [0.5, "rest", "back"]])
	rig.add_move("startled", [[0.0, "rest", "linear"], [0.15, "jump", "out"], [0.45, "land", "in"], [0.9, "rest", "back"]])
	rig.add_move("hop", [[0.0, "rest", "linear"], [0.15, "crouch", "in"], [0.35, "air", "out"], [0.6, "crouch", "in"], [0.85, "rest", "back"]])
	rig.add_move("bow", [[0.0, "rest", "linear"], [0.6, "bow", "inout"], [1.6, "bow", "linear"], [2.2, "rest", "inout"]], true)


# --- Parts ------------------------------------------------------------------

## A plum robe flaring to the hem, a cream apron with a pocket.
static func _robe() -> Texture2D:
	return Pixels.bake("dengdeng|robe", Vector2i(24, 32), func(x: int, y: int) -> Color:
		var half := 5.0 + float(y) * 0.22
		var dx := x + 0.5 - 12.0
		if absf(dx) > half:
			return Pixels.CLEAR
		if y >= 30:
			return CAP
		if absf(dx) < half * 0.55 and y >= 8 and y < 29:
			if y >= 17 and y <= 20 and absf(dx) < 3.0:
				return APRON.darkened(0.15)
			return Pixels.grainy(APRON, x, y, 0.05)
		var tone := ROBE_DARK if (x + y / 3) % 7 == 0 else ROBE
		return Pixels.rounded(tone, Vector2(dx / half, 0.0)))


## The head: a paper lantern with ribs, caps and a face. 0 calm, 1 "hm?", 2 startled.
static func _head(kind: int) -> Texture2D:
	return Pixels.bake("dengdeng|head|%d" % kind, Vector2i(22, 24), func(x: int, y: int) -> Color:
		var dx := x + 0.5 - 11.0
		if y < 3 or y > 20:
			return CAP if absf(dx) < 6.0 else Pixels.CLEAR
		var body := Vector2(dx / 11.0, (y + 0.5 - 12.0) / 9.5)
		if body.length_squared() > 1.0:
			return Pixels.CLEAR
		# The face, painted on the paper.
		var eye_y := 10
		for side: float in [-1.0, 1.0]:
			var e := Vector2(dx - side * 4.0, y + 0.5 - eye_y)
			match kind:
				0:
					if absf(e.y + 0.6 - absf(e.x) * 0.6) < 0.7 and absf(e.x) < 2.2:
						return INK
				1:
					if (side < 0.0 and e.length() < 1.6) or (side > 0.0 and absf(e.y) < 0.6 and absf(e.x) < 2.0):
						return INK
				2:
					if e.length() < 2.4:
						return PAPER if e.length() > 1.0 else INK
		var mouth := Vector2(dx, y + 0.5 - 15.0)
		if (kind == 2 and Vector2(mouth.x / 2.0, mouth.y / 1.6).length() < 1.0) or (kind != 2 and absf(mouth.y - absf(mouth.x) * 0.3) < 0.6 and absf(mouth.x) < 2.6):
			return RIB.darkened(0.3)
		var tone := LANTERN.lerp(LANTERN_GLOW, 0.35 * (1.0 - body.length()))
		if int(roundf(dx)) % 4 == 0:
			tone = RIB
		return Pixels.rounded(tone, body * 0.6))


static func _tassel() -> Texture2D:
	return Pixels.bake("dengdeng|tassel", Vector2i(4, 9), func(x: int, y: int) -> Color:
		return TASSEL if x >= 1 and x <= 2 and y < 8 or y == 8 and x % 2 == 0 else Pixels.CLEAR)


static func _arm() -> Texture2D:
	return Pixels.bake("dengdeng|arm", Vector2i(5, 13), func(x: int, y: int) -> Color:
		if y >= 10:
			return SKIN if absf(x + 0.5 - 2.5) < 2.0 else Pixels.CLEAR
		return Pixels.rounded(ROBE, Vector2((x - 2.0) / 2.5, 0.0)) if absf(x + 0.5 - 2.5) < 2.2 else Pixels.CLEAR)


static func _pole() -> Texture2D:
	return Pixels.bake("dengdeng|pole", Vector2i(3, 28), func(x: int, y: int) -> Color:
		return Pixels.wood(POLE, x, y, 3) if x == 1 or y > 24 else Pixels.CLEAR)


## The pole lantern: brass cap, glowing paper body, tassel.
static func _lamp() -> Texture2D:
	return Pixels.bake("dengdeng|lamp", Vector2i(10, 15), func(x: int, y: int) -> Color:
		var dx := x + 0.5 - 5.0
		if y < 2:
			return CAP if absf(dx) < 2.0 else Pixels.CLEAR
		if y > 12:
			return TASSEL if absf(dx) < 1.0 else Pixels.CLEAR
		var body := Vector2(dx / 5.0, (y + 0.5 - 7.0) / 5.5)
		if body.length_squared() > 1.0:
			return Pixels.CLEAR
		return Pixels.rounded(LANTERN_GLOW.lightened(0.2), body * 0.5))
