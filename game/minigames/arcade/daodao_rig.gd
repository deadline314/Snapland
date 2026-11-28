extends RefCounted
## 倒倒, keeper of 倒影大道 (design/01-park/other-space.md §5): a mirror-balloon
## demon whose belly shows the avenue upside down, with little coral horns,
## twisted-balloon arms and the troupe's six balloons in its left mitten.
## Twenty parts on the shared part rig; every part is baked once through the
## arcade pixel kit (lit edge, shaded edge, deepened outline).

const Rig = preload("res://game/minigames/arcade/part_rig.gd")
const Pixels = preload("res://game/minigames/arcade/arcade_pixels.gd")

## Stage size in texels and where the root pivot (under the knot) sits on it.
const STAGE := Vector2i(150, 128)
const ROOT := Vector2(75, 100)
const MOVES := ["idle", "dash", "confetti", "pose", "shy"]
const BALLOONS := ["balloon_1", "balloon_2", "balloon_3", "balloon_4", "balloon_5", "balloon_6"]

const LILAC := Color("#b9b2e8")
const GRASS := Color("#8fc46e")
const PATH := Color("#efe0b8")
const SKY := Color("#a9dcf2")
const GLINT := Color("#fbf8ff")
const CREAM := Color("#fff1d2")
const PLUM := Color("#2f2440")
const MOUTH := Color("#7a2f3a")
const TONGUE := Color("#ef7f8e")
const BLUSH := Color("#f08aa8")
const HORN := Color("#e8705e")
const ARM := Color("#f29bb4")
const STRING := Color("#9a90aa")
const GOLD := Color("#ffd768")
const TROUPE: Array[Color] = [Color("#e2604f"), Color("#ffd768"), Color("#70e1c1"), Color("#7fb8ee"), Color("#f08aa8"), Color("#a58be0")]


static func build() -> Rig:
	var rig: Rig = Rig.new()
	rig.add_part("body", _body(), Vector2(24, 51))
	rig.add_part("knot", _knot(), Vector2(5, 1), "body", Vector2(0, -1), 1)
	rig.add_part("tail_1", _string(9), Vector2(2.5, 1), "knot", Vector2(0, 5), -3, {"drag": 0.5, "wobble": Vector2(6, 1.9)})
	rig.add_part("tail_2", _string(9), Vector2(2.5, 1), "tail_1", Vector2(0, 9), -3, {"drag": 0.8, "wobble": Vector2(9, 1.6)})
	rig.add_part("tail_3", _string(8), Vector2(2.5, 1), "tail_2", Vector2(0, 9), -3, {"drag": 1.0, "wobble": Vector2(12, 1.3)})
	rig.add_part("horn_l", _horn(false), Vector2(5.5, 12), "body", Vector2(-12, -45), -1, {"rot": -22.0, "drag": 0.35, "wobble": Vector2(3, 2.1)})
	rig.add_part("horn_r", _horn(true), Vector2(5.5, 12), "body", Vector2(12, -45), -1, {"rot": 22.0, "drag": 0.35, "wobble": Vector2(3, 2.3)})
	rig.add_part("arm_l", _arm(), Vector2(5, 3), "body", Vector2(-20, -25), 1, {"rot": 34.0, "drag": 0.45, "wobble": Vector2(4, 2.9), "smear": true})
	for i in BALLOONS.size():
		# Fanned strings, longest in the middle, each swinging at its own pace.
		var lean := (float(i) - 2.5) * 11.0
		rig.add_part(BALLOONS[i], _balloon(i), Vector2(7, 45), "arm_l", Vector2(0, 13), -2,
			{"rot": lean, "upright": true, "drag": 0.7 + 0.08 * i, "wobble": Vector2(5, 2.0 + 0.27 * i)})
	rig.add_part("cheek_l", _cheek(), Vector2(5, 3.5), "body", Vector2(-13, -21), 2)
	rig.add_part("cheek_r", _cheek(), Vector2(5, 3.5), "body", Vector2(13, -21), 2)
	rig.add_part("eyes", [_eyes(0), _eyes(1), _eyes(2), _eyes(3)], Vector2(12, 6.5), "body", Vector2(0, -29), 2, {"blink": true})
	rig.add_part("mouth", [_mouth(0), _mouth(1), _mouth(2), _mouth(3)], Vector2(8, 2), "body", Vector2(0, -21), 2)
	rig.add_part("arm_r", _arm(), Vector2(5, 3), "body", Vector2(20, -25), 3, {"rot": -34.0, "drag": 0.45, "wobble": Vector2(4, 3.3), "smear": true})
	_poses(rig)
	_moves(rig)
	return rig


static func _poses(rig: Rig) -> void:
	rig.add_pose("rest", {})
	rig.add_pose("float_up", {"body": {"at": Vector2(0, -3), "squash": -0.04}, "arm_l": {"rot": -8.0}, "arm_r": {"rot": 8.0}})
	# Wind-up: squashed low, leaning back, cheeks swollen, eyes squeezed.
	rig.add_pose("inhale", {
		"body": {"rot": -11.0, "at": Vector2(-3, 0), "squash": 0.24},
		"cheek_l": {"scale": Vector2(1.9, 1.9)}, "cheek_r": {"scale": Vector2(1.9, 1.9)},
		"eyes": {"frame": 2}, "mouth": {"frame": 1},
		"arm_l": {"rot": 38.0}, "arm_r": {"rot": -38.0}, "horn_l": {"rot": 12.0}, "horn_r": {"rot": -12.0},
	})
	rig.add_pose("dash", {
		"body": {"rot": 17.0, "at": Vector2(7, -2), "squash": -0.22},
		"cheek_l": {"scale": Vector2(0.7, 0.7)}, "cheek_r": {"scale": Vector2(0.7, 0.7)},
		"mouth": {"frame": 3}, "arm_l": {"rot": 72.0}, "arm_r": {"rot": 58.0},
	})
	rig.add_pose("dash_over", {"body": {"rot": 23.0, "at": Vector2(9, -1), "squash": -0.1}, "mouth": {"frame": 3}, "arm_l": {"rot": 60.0}, "arm_r": {"rot": 44.0}})
	rig.add_pose("recover", {"body": {"rot": -6.0, "squash": 0.12}, "arm_l": {"rot": -12.0}, "arm_r": {"rot": 12.0}})
	for side in [-1.0, 1.0]:
		rig.add_pose("shimmy_l" if side < 0.0 else "shimmy_r", {
			"body": {"rot": 9.0 * side, "at": Vector2(2.0 * side, 0), "squash": 0.06 if side < 0.0 else -0.04},
			"eyes": {"frame": 1}, "mouth": {"frame": 3},
			"arm_l": {"rot": 120.0 + 12.0 * side}, "arm_r": {"rot": -120.0 + 12.0 * side},
		})
	rig.add_pose("crouch", {"body": {"squash": 0.26, "at": Vector2(0, 1)}, "eyes": {"frame": 2}, "arm_l": {"rot": 22.0}, "arm_r": {"rot": -22.0},
		"horn_l": {"rot": 8.0}, "horn_r": {"rot": -8.0}})
	# The 亮相: sprung up and stretched, arms flung wide, the widest grin.
	rig.add_pose("pose", {
		"body": {"rot": -4.0, "at": Vector2(0, -11), "squash": -0.17},
		"eyes": {"frame": 3}, "mouth": {"frame": 3},
		"cheek_l": {"scale": Vector2(1.3, 1.3)}, "cheek_r": {"scale": Vector2(1.3, 1.3)},
		"arm_l": {"rot": 102.0}, "arm_r": {"rot": -112.0}, "horn_l": {"rot": -10.0}, "horn_r": {"rot": 10.0},
	})
	rig.add_pose("pose_hold", {
		"body": {"rot": -2.0, "at": Vector2(0, -8), "squash": -0.06},
		"eyes": {"frame": 3}, "mouth": {"frame": 3},
		"cheek_l": {"scale": Vector2(1.2, 1.2)}, "cheek_r": {"scale": Vector2(1.2, 1.2)},
		"arm_l": {"rot": 94.0}, "arm_r": {"rot": -104.0},
	})
	# Photographed: eyes shut, cheeks aflame, mittens over the face.
	rig.add_pose("shy", {
		"body": {"rot": 6.0, "at": Vector2(0, 2), "squash": 0.1},
		"eyes": {"frame": 2}, "mouth": {"frame": 2},
		"cheek_l": {"scale": Vector2(1.8, 1.6)}, "cheek_r": {"scale": Vector2(1.8, 1.6)},
		"arm_l": {"rot": -142.0}, "arm_r": {"rot": 142.0},
	})


static func _moves(rig: Rig) -> void:
	rig.add_move("idle", [[0.0, "rest", "linear"], [1.2, "float_up", "inout"], [2.4, "rest", "inout"]], true)
	# Wind up slowly, strike fast, then swing back past upright and settle.
	rig.add_move("dash", [[0.0, "rest", "linear"], [0.6, "inhale", "in"], [0.78, "dash", "out"], [1.05, "dash_over", "inout"],
		[1.55, "recover", "back"], [2.0, "rest", "inout"]])
	var shake: Array = [[0.0, "rest", "linear"]]
	for beat in 6:
		shake.append([0.34 + 0.13 * beat, "shimmy_l" if beat % 2 == 0 else "shimmy_r", "inout"])
	shake.append_array([[1.3, "recover", "back"], [1.7, "rest", "inout"]])
	rig.add_move("confetti", shake)
	rig.add_move("pose", [[0.0, "rest", "linear"], [0.3, "crouch", "in"], [0.58, "pose", "back"], [1.18, "pose_hold", "inout"], [1.6, "rest", "inout"]])
	rig.add_move("shy", [[0.0, "rest", "linear"], [0.24, "shy", "out"], [0.95, "shy", "linear"], [1.4, "rest", "inout"]])


# --- Parts ------------------------------------------------------------------

## A teardrop balloon of mirror foil; the belly reflects the avenue upside down
## (flowerbeds on top, a path, then sky).
static func _body() -> Texture2D:
	var size := Vector2i(46, 50)
	return Pixels.bake("daodao|body", size, func(x: int, y: int) -> Color:
		var offset := Vector2((x + 0.5 - 23.0) / 23.0, (y + 0.5 - 25.0) / 25.0)
		offset.x /= 1.0 - 0.2 * maxf(0.0, offset.y)
		var d := offset.length_squared()
		if d > 1.0:
			return Pixels.CLEAR
		var tone := LILAC
		var band := float(y) / size.y
		var inside := absf(offset.x) < 0.83 * sqrt(maxf(0.0, 1.0 - offset.y * offset.y))
		if inside and band > 0.66 and band < 0.92:
			if band < 0.76:
				tone = GRASS.lerp(LILAC, 0.25)
				if Pixels.noise(x, y, 5) > 0.86:
					tone = [Color("#f6a3b9"), Color("#ffe08a")][(x + y) % 2]
			elif band < 0.8:
				tone = PATH.lerp(LILAC, 0.2)
			else:
				tone = SKY.lerp(LILAC, 0.3)
				if Pixels.noise(x / 3, y / 2, 9) > 0.8:
					tone = tone.lightened(0.18)
		tone = Pixels.rounded(tone, offset)
		if d > 0.8 and offset.x + offset.y > 0.3:
			tone = tone.darkened(0.12)
		# Window glints of the foil, top left.
		if (x >= 10 and x <= 12 and y >= 9 and y <= 14) or (x >= 15 and x <= 16 and y >= 7 and y <= 8):
			tone = GLINT
		return Pixels.grainy(tone, x, y, 0.05))


static func _knot() -> Texture2D:
	return Pixels.bake("daodao|knot", Vector2i(8, 5), func(x: int, y: int) -> Color:
		return LILAC.darkened(0.18) if absf(x + 0.5 - 4.0) <= 4.0 - y * 0.7 else Pixels.CLEAR)


static func _string(length: int) -> Texture2D:
	return Pixels.bake("daodao|string|%d" % length, Vector2i(3, length), func(x: int, y: int) -> Color:
		return STRING.lightened(0.15 * float(y % 3 == 0)) if x == 1 else Pixels.CLEAR)


## A curled coral horn with a cream tip; `right` mirrors the curl.
static func _horn(right: bool) -> Texture2D:
	return Pixels.bake("daodao|horn|%s" % right, Vector2i(9, 11), func(x: int, y: int) -> Color:
		var u := float(y) / 10.0
		var centre := 4.5 + (1.0 - u) * (1.0 - u) * 2.4 * (1.0 if right else -1.0)
		var half := 0.6 + u * 2.6
		if absf(x + 0.5 - centre) > half:
			return Pixels.CLEAR
		var tone := CREAM if y < 3 else HORN
		return Pixels.rounded(tone, Vector2((x + 0.5 - centre) / maxf(half, 0.5), 0.2)))


## A twisted-balloon arm hanging from the shoulder, ending in a cream mitten.
static func _arm() -> Texture2D:
	return Pixels.bake("daodao|arm", Vector2i(8, 19), func(x: int, y: int) -> Color:
		var dx := x + 0.5 - 4.0
		if y >= 12:
			var mitten := Vector2(dx / 3.6, (y + 0.5 - 15.0) / 3.6)
			return Pixels.rounded(CREAM, mitten) if mitten.length() <= 1.0 else Pixels.CLEAR
		var pinch := 1.0 if y % 5 == 4 else 0.0
		if absf(dx) > 2.2 - pinch * 0.9:
			return Pixels.CLEAR
		var tone := ARM.darkened(0.2) if pinch > 0.0 else ARM
		return Pixels.rounded(tone, Vector2(dx / 2.2, 0.0)))


## One troupe balloon floating up on a long string; the pivot is the string's end.
static func _balloon(index: int) -> Texture2D:
	var colour := TROUPE[index]
	return Pixels.bake("daodao|balloon|%d" % index, Vector2i(12, 44), func(x: int, y: int) -> Color:
		var offset := Vector2((x + 0.5 - 6.0) / 5.0, (y + 0.5 - 7.0) / 6.5)
		if offset.length_squared() <= 1.0:
			if x == 4 and y >= 3 and y <= 5:
				return GLINT
			return Pixels.rounded(colour, offset)
		if y >= 13 and y <= 14 and absi(x - 6) <= 14 - y:
			return colour.darkened(0.2)
		if y > 14 and x == 6 + int(roundf(sin(y * 0.45 + index) * 0.6)):
			return STRING
		return Pixels.CLEAR)


static func _cheek() -> Texture2D:
	return Pixels.bake("daodao|cheek", Vector2i(8, 5), func(x: int, y: int) -> Color:
		var offset := Vector2((x + 0.5 - 4.0) / 4.0, (y + 0.5 - 2.5) / 2.5)
		return BLUSH if offset.length_squared() <= 1.0 else Pixels.CLEAR)


## 0 open, 1 happy arcs, 2 squeezed shut, 3 wide with gold sparkles.
static func _eyes(kind: int) -> Texture2D:
	return Pixels.bake("daodao|eyes|%d" % kind, Vector2i(22, 11), func(x: int, y: int) -> Color:
		for eye in [Vector2(5.5, 5.5), Vector2(16.5, 5.5)]:
			var d := Vector2(x + 0.5 - eye.x, y + 0.5 - eye.y)
			var side := -1.0 if eye.x < 11.0 else 1.0
			match kind:
				0, 3:
					var radii := Vector2(3.6, 4.6) if kind == 3 else Vector2(3.0, 4.0)
					if (d / radii).length_squared() > 1.0:
						continue
					if d.x < -0.5 and d.x > -1.6 and d.y < -1.2 and d.y > -2.6:
						return CREAM
					var pupil := Vector2(d.x / 1.8, (d.y - 0.6) / 2.4)
					if pupil.length_squared() <= 1.0:
						return GOLD if kind == 3 and absf(d.x) + absf(d.y - 0.6) < 1.1 else PLUM
					return CREAM
				1:
					if absf(d.y + 1.0 - absf(d.x) * 0.75) < 0.7 and absf(d.x) < 3.2:
						return PLUM
				2:
					if absf(d.x * -side - (1.8 - absf(d.y) * 0.9)) < 0.7 and absf(d.y) < 2.6:
						return PLUM
		return Pixels.CLEAR)


## 0 grin with a fang, 1 round inhale, 2 shy squiggle, 3 wide open grin.
static func _mouth(kind: int) -> Texture2D:
	return Pixels.bake("daodao|mouth|%d" % kind, Vector2i(14, 9), func(x: int, y: int) -> Color:
		var dx := (x + 0.5 - 7.0)
		match kind:
			0, 3:
				var width := 6.5 if kind == 3 else 5.0
				var depth := 7.0 if kind == 3 else 4.0
				var bottom := 0.5 + depth * (1.0 - (dx / width) * (dx / width))
				if y < 0.5 or y > bottom:
					return Pixels.CLEAR
				if y <= 1 and (x == 4 or (kind == 3 and x == 9)):
					return CREAM
				return TONGUE if y > bottom - 2.2 else MOUTH
			1:
				var offset := Vector2(dx / 2.6, (y + 0.5 - 4.5) / 3.4)
				if offset.length_squared() > 1.0:
					return Pixels.CLEAR
				return TONGUE if y >= 6 else MOUTH
			2:
				return MOUTH if absf(dx) < 4.5 and y == 3 + int(roundf(sin(dx * 1.3))) else Pixels.CLEAR
		return Pixels.CLEAR)
