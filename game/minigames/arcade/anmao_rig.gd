extends RefCounted
## 錨錨, keeper of 逆潮港 (design/01-park/other-space.md §5b): a crab captain
## sitting backwards in a barrel boat, facing the chasing raft, captain's hat on,
## eyes on stalks, the stolen lighthouse lamp swinging from its big claw.
## Fifteen parts on the shared part rig.

const Rig = preload("res://game/minigames/arcade/part_rig.gd")
const Pixels = preload("res://game/minigames/arcade/arcade_pixels.gd")

const STAGE := Vector2i(150, 120)
const ROOT := Vector2(80, 92)
const MOVES := ["idle", "throw", "sprint", "caught", "handback"]

const SHELL := Color("#e2604f")
const SHELL_DARK := Color("#b7443b")
const BELLY := Color("#f6d7b0")
const HAT := Color("#2f4a7a")
const GOLD := Color("#ffd166")
const WOOD := Color("#9a6a42")
const HOOP := Color("#5b6470")
const GLASS := Color("#fff0b8")
const CREAM := Color("#fff7e8")
const PLUM := Color("#2f2440")
const MOUTH := Color("#7a2f3a")
const SAIL := Color("#f2e9d4")


static func build() -> Rig:
	var rig: Rig = Rig.new()
	rig.add_part("boat", _boat(), Vector2(29, 12))
	rig.add_part("mast", _mast(), Vector2(2, 25), "boat", Vector2(18, -6), -2, {"rot": 4.0, "drag": 0.3, "wobble": Vector2(2, 2.6)})
	rig.add_part("flag", _flag(), Vector2(1, 2), "mast", Vector2(0, -23), -2, {"drag": 0.9, "wobble": Vector2(10, 0.9), "smear": true})
	rig.add_part("leg_l", _leg(), Vector2(2, 1), "boat", Vector2(-10, -8), -1, {"rot": 30.0, "wobble": Vector2(14, 0.7)})
	rig.add_part("leg_r", _leg(), Vector2(2, 1), "boat", Vector2(8, -8), -1, {"rot": -30.0, "wobble": Vector2(14, 0.8)})
	rig.add_part("shell", _shell(), Vector2(18, 22), "boat", Vector2(0, -6), 0)
	rig.add_part("eye_l", _eye(), Vector2(3, 12), "shell", Vector2(-6, -19), -1, {"rot": -12.0, "drag": 0.6, "wobble": Vector2(5, 1.7), "blink": true})
	rig.add_part("eye_r", _eye(), Vector2(3, 12), "shell", Vector2(6, -19), -1, {"rot": 12.0, "drag": 0.7, "wobble": Vector2(5, 1.9), "blink": true})
	rig.add_part("hat", _hat(), Vector2(12, 9), "shell", Vector2(0, -19), 1, {"drag": 0.4})
	rig.add_part("mouth", [_mouth(0), _mouth(1), _mouth(2)], Vector2(6, 2), "shell", Vector2(0, -8), 1)
	rig.add_part("arm_l", _arm(false), Vector2(13, 3), "shell", Vector2(-14, -9), 2, {"rot": 10.0, "drag": 0.35, "smear": true})
	rig.add_part("claw_l", [_claw(false, false), _claw(false, true)], Vector2(15, 7), "arm_l", Vector2(-11, 0), 2, {"drag": 0.4, "smear": true})
	rig.add_part("lamp", _lamp(), Vector2(6, 1), "claw_l", Vector2(-8, 5), 1, {"upright": true, "drag": 0.9, "wobble": Vector2(6, 1.4)})
	rig.add_part("arm_r", _arm(true), Vector2(1, 3), "shell", Vector2(14, -9), -1, {"rot": -20.0, "drag": 0.4, "wobble": Vector2(6, 2.2)})
	rig.add_part("claw_r", [_claw(true, false), _claw(true, true)], Vector2(1, 5), "arm_r", Vector2(9, 0), -1, {"drag": 0.5, "wobble": Vector2(8, 1.1)})
	_poses(rig)
	_moves(rig)
	return rig


static func _poses(rig: Rig) -> void:
	rig.add_pose("rest", {})
	rig.add_pose("rock", {"boat": {"rot": 3.0, "at": Vector2(0, 1)}, "shell": {"rot": -2.0}, "claw_r": {"frame": 1}})
	# The throw: big claw and lamp swung back over the shoulder, then flung forward.
	rig.add_pose("wind", {
		"shell": {"rot": 12.0, "at": Vector2(2, 1), "squash": 0.16},
		"arm_l": {"rot": 125.0}, "claw_l": {"rot": 30.0, "frame": 1},
		"eye_l": {"rot": 18.0}, "eye_r": {"rot": 18.0}, "mouth": {"frame": 2},
		"boat": {"rot": -4.0},
	})
	rig.add_pose("fling", {
		"shell": {"rot": -16.0, "at": Vector2(-4, -1), "squash": -0.18},
		"arm_l": {"rot": -35.0}, "claw_l": {"rot": -20.0, "frame": 0},
		"eye_l": {"rot": -20.0}, "eye_r": {"rot": -20.0}, "mouth": {"frame": 0},
		"boat": {"rot": 5.0},
	})
	rig.add_pose("settle", {"shell": {"rot": 4.0, "squash": 0.06}, "arm_l": {"rot": 8.0}})
	# Sprinting: hunched forward over the oarless barrel, legs paddling, hat clamped.
	rig.add_pose("hunch", {
		"shell": {"rot": 18.0, "at": Vector2(3, 2), "squash": 0.1},
		"arm_l": {"rot": 40.0}, "arm_r": {"rot": -60.0}, "claw_r": {"frame": 1},
		"leg_l": {"rot": 60.0}, "leg_r": {"rot": -60.0}, "mouth": {"frame": 2},
	})
	rig.add_pose("paddle", {
		"shell": {"rot": 14.0, "at": Vector2(3, 0), "squash": 0.02},
		"arm_l": {"rot": 30.0}, "arm_r": {"rot": -40.0},
		"leg_l": {"rot": -10.0}, "leg_r": {"rot": 10.0}, "mouth": {"frame": 2},
	})
	# Caught by the rope: eyes shoot up, hat jumps, everything flung back.
	rig.add_pose("yank", {
		"shell": {"rot": -22.0, "at": Vector2(-6, -4), "squash": -0.22},
		"eye_l": {"at": Vector2(0, -5), "rot": -25.0}, "eye_r": {"at": Vector2(0, -5), "rot": 25.0},
		"hat": {"at": Vector2(0, -12), "rot": -30.0}, "mouth": {"frame": 1},
		"arm_l": {"rot": 70.0}, "arm_r": {"rot": -80.0}, "claw_l": {"frame": 1}, "claw_r": {"frame": 1},
		"boat": {"rot": -8.0},
	})
	rig.add_pose("dazed", {"shell": {"rot": 6.0, "squash": 0.12}, "hat": {"at": Vector2(2, -1), "rot": 14.0}, "mouth": {"frame": 1}})
	# Handing the lamp back, shamefaced.
	rig.add_pose("offer", {
		"shell": {"rot": -8.0, "at": Vector2(-2, 0), "squash": 0.08},
		"arm_l": {"rot": -55.0}, "claw_l": {"frame": 1},
		"eye_l": {"rot": 20.0}, "eye_r": {"rot": -20.0}, "hat": {"rot": 10.0}, "mouth": {"frame": 2},
	})


static func _moves(rig: Rig) -> void:
	rig.add_move("idle", [[0.0, "rest", "linear"], [1.3, "rock", "inout"], [2.6, "rest", "inout"]], true)
	rig.add_move("throw", [[0.0, "rest", "linear"], [0.7, "wind", "in"], [0.85, "fling", "out"], [1.25, "settle", "back"], [1.6, "rest", "inout"]])
	var sprint: Array = [[0.0, "rest", "linear"], [0.25, "hunch", "out"]]
	for stroke in 6:
		sprint.append([0.25 + 0.18 * (stroke + 1), "paddle" if stroke % 2 == 0 else "hunch", "inout"])
	sprint.append([1.7, "rest", "inout"])
	rig.add_move("sprint", sprint)
	rig.add_move("caught", [[0.0, "rest", "linear"], [0.12, "yank", "out"], [0.7, "dazed", "back"], [1.3, "rest", "inout"]])
	rig.add_move("handback", [[0.0, "rest", "linear"], [0.5, "offer", "inout"], [2.0, "offer", "linear"]])


# --- Parts ------------------------------------------------------------------

## A barrel cut in half lengthways: staves, two iron hoops, a dark open top.
static func _boat() -> Texture2D:
	return Pixels.bake("anmao|boat", Vector2i(56, 18), func(x: int, y: int) -> Color:
		var u := (x + 0.5 - 28.0) / 28.0
		var bottom := 6.0 + 11.0 * sqrt(maxf(0.0, 1.0 - u * u))
		if float(y) > bottom:
			return Pixels.CLEAR
		if y < 3:
			return WOOD.darkened(0.5) if y > 0 else WOOD.lightened(0.15)
		if absi(x - 14) <= 1 or absi(x - 42) <= 1:
			return Pixels.metal(HOOP, x, y)
		return Pixels.rounded(Pixels.wood(WOOD, x, y, 5), Vector2(u * 0.6, (y - 9.0) / 9.0)))


static func _mast() -> Texture2D:
	return Pixels.bake("anmao|mast", Vector2i(4, 26), func(x: int, y: int) -> Color:
		return Pixels.wood(WOOD.darkened(0.15), x, y, 4) if x >= 1 and x <= 2 else Pixels.CLEAR)


## A little pennant: skull-and-claw in cream on navy.
static func _flag() -> Texture2D:
	return Pixels.bake("anmao|flag", Vector2i(16, 10), func(x: int, y: int) -> Color:
		if absf(y + 0.5 - 5.0) > 5.0 - x * 0.28:
			return Pixels.CLEAR
		if Vector2(x - 5.0, y - 4.5).length() < 2.0:
			return CREAM
		return Pixels.grainy(HAT, x, y, 0.08))


static func _leg() -> Texture2D:
	return Pixels.bake("anmao|leg", Vector2i(4, 10), func(x: int, y: int) -> Color:
		if absf(x + 0.5 - 2.0) > 1.6 - y * 0.08:
			return Pixels.CLEAR
		return SHELL_DARK if y % 4 == 3 else SHELL)


## The shell: a wide dome with bumps along the rim, a pale belly and spots.
static func _shell() -> Texture2D:
	return Pixels.bake("anmao|shell", Vector2i(36, 22), func(x: int, y: int) -> Color:
		var offset := Vector2((x + 0.5 - 18.0) / 18.0, (y + 0.5 - 15.0) / 15.0)
		if offset.length_squared() > 1.0 or y > 21:
			return Pixels.CLEAR
		if offset.y > 0.35:
			return Pixels.grainy(BELLY.darkened(0.08 * float(x % 5 == 0)), x, y, 0.05)
		var tone := SHELL
		if Pixels.noise(x / 3, y / 3, 17) > 0.82:
			tone = SHELL_DARK
		return Pixels.rounded(tone, offset))


static func _eye() -> Texture2D:
	return Pixels.bake("anmao|eye", Vector2i(7, 13), func(x: int, y: int) -> Color:
		var ball := Vector2(x + 0.5 - 3.5, y + 0.5 - 3.5)
		if ball.length() <= 3.4:
			if ball.length() <= 1.4 and ball.x > -0.5:
				return PLUM
			return CREAM
		if y > 6 and absf(x + 0.5 - 3.5) < 1.2:
			return SHELL
		return Pixels.CLEAR)


## A navy captain's cap with a gold anchor badge and a peak.
static func _hat() -> Texture2D:
	return Pixels.bake("anmao|hat", Vector2i(24, 10), func(x: int, y: int) -> Color:
		if y >= 7:
			return PLUM.lightened(0.2) if x >= 1 and x <= 22 else Pixels.CLEAR
		var crown := Vector2((x + 0.5 - 12.0) / 10.0, (y + 0.5 - 7.0) / 7.0)
		if crown.length_squared() > 1.0:
			return Pixels.CLEAR
		if absf(x + 0.5 - 12.0) < 1.5 and y >= 2 and y <= 5:
			return GOLD
		if y == 5 and absf(x + 0.5 - 12.0) < 3.0:
			return GOLD
		return Pixels.rounded(HAT, crown))


## 0 smirk, 1 shocked O, 2 gritted grin.
static func _mouth(kind: int) -> Texture2D:
	return Pixels.bake("anmao|mouth|%d" % kind, Vector2i(12, 7), func(x: int, y: int) -> Color:
		var dx := x + 0.5 - 6.0
		match kind:
			0:
				return MOUTH if y == 2 + int(roundf(absf(dx) * 0.25 - (0.8 if dx > 0.0 else 0.0))) and absf(dx) < 5.0 else Pixels.CLEAR
			1:
				return MOUTH if Vector2(dx / 2.4, (y + 0.5 - 3.5) / 3.0).length_squared() <= 1.0 else Pixels.CLEAR
		if absf(dx) < 5.0 and y >= 1 and y <= 4:
			return CREAM if y % 3 != 0 and int(dx + 6.0) % 3 != 0 else MOUTH
		return Pixels.CLEAR)


## An arm segment; the big one reaches left (toward the raft), the small one right.
static func _arm(small: bool) -> Texture2D:
	var length := 10 if small else 14
	return Pixels.bake("anmao|arm|%s" % small, Vector2i(length, 5), func(x: int, y: int) -> Color:
		if absf(y + 0.5 - 2.5) > 2.0 - float(x % 5 == 0) * 0.6:
			return Pixels.CLEAR
		return Pixels.rounded(SHELL, Vector2(0.0, (y - 2.0) / 2.5)))


## A pincer, closed or open; the big claw is twice the small one.
static func _claw(small: bool, open: bool) -> Texture2D:
	var size := Vector2i(10, 10) if small else Vector2i(16, 14)
	return Pixels.bake("anmao|claw|%s|%s" % [small, open], size, func(x: int, y: int) -> Color:
		var u := (x + 0.5) / size.x
		var v := (y + 0.5) / size.y
		# The big claw opens toward the raft (left); the small one points right.
		if small:
			u = 1.0 - u
		var palm := Vector2((u - 0.75) / 0.3, (v - 0.55) / 0.42)
		var gap := 0.2 if open else 0.04
		var upper := u < 0.75 and v > 0.08 + (0.75 - u) * (0.6 if open else 0.25) and v < 0.5 - gap
		var lower := u < 0.75 and v > 0.5 + gap and v < 0.92 - (0.75 - u) * 0.3
		if palm.length_squared() > 1.0 and not upper and not lower:
			return Pixels.CLEAR
		return Pixels.rounded(SHELL, Vector2(palm.x * 0.5, v * 2.0 - 1.0)) if u > 0.2 else SHELL_DARK)


## The stolen lighthouse lamp: brass cage and a glowing lens, hanging from a ring.
static func _lamp() -> Texture2D:
	return Pixels.bake("anmao|lamp", Vector2i(12, 18), func(x: int, y: int) -> Color:
		var dx := absf(x + 0.5 - 6.0)
		if y < 3:
			return Pixels.metal(Color("#b58a3a"), x, y) if dx < 2.0 and (y == 0 or dx > 1.0) else Pixels.CLEAR
		if y < 5 or y > 15:
			return Pixels.metal(Color("#c9953e"), x, y) if dx < 5.5 else Pixels.CLEAR
		if dx < 5.0:
			return Color("#8a6a2a") if x % 4 == 1 else Pixels.rounded(GLASS, Vector2((x - 6.0) / 5.0, (y - 10.0) / 6.0))
		return Pixels.CLEAR)
