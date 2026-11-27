extends "res://game/minigames/arcade/arcade_view.gd"
## Picture for 誰是假倒影: a row of brass mirrors, the hero seen from behind
## in a spotlight, and the fake that sticks its tongue out and walks off when
## the wrong mirror is accused.

const TENT_ART := "res://assets/world/circus-tent.webp"
const FLOOR_TOP := 500.0
const MIRROR_SIZE := Vector2(150, 200)
const MIRROR_GAP := 36.0
const MIRROR_TOP := 214.0
const REFLECTION_UNIT := 5.0
const HERO_UNIT := 6.0
const HERO_FEET := Vector2(640, 646)
const WOOD := Color("#6b4658")
const WOOD_DARK := Color("#3b2536")
const BRASS := Color("#e3a53c")
const BRASS_DARK := Color("#a86a24")
const BRASS_LIGHT := Color("#ffe08a")
const SKIN := Color("#ffcf9e")
const HAIR := Color("#3a2b4a")
const SHIRT := Color("#ff7f6a")
const SHIRT_SHADE := Color("#d95a4c")
const PANTS := Color("#3b4a8a")
const SHOES := Color("#2b2440")

## Painted pixel blocks per figure look, built once: "pose|front|mood" -> [[Rect2, Color], ...].
static var _figures: Dictionary = {}

var _has_tent := false


func _init() -> void:
	super()
	# Words land on the open floor beside the hero, clear of every mirror.
	word_anchor = Vector2(300, 604)


func _ready() -> void:
	_has_tent = use_backdrop_art(TENT_ART, Rect2(213, 60, 1110, 624), Color(0.72, 0.7, 0.86))


func _draw_backdrop() -> void:
	if not _has_tent:
		draw_rect(Rect2(Vector2.ZERO, DESIGN), Color("#2b1f3a"))
	stage_floor(FLOOR_TOP, WOOD, WOOD_DARK)


func _draw_scene() -> void:
	var count := int(state.get("mirrors", 3))
	var reflections: Array = state.get("reflections", [])
	var selected := int(state.get("selected", 0))
	var fake := int(state.get("fake", -1))
	var accused := int(state.get("accused", -1))
	var outcome := str(state.get("outcome", ""))
	var since := age(float(state.get("outcome_at", -99.0)))
	var entered := age(float(state.get("case_at", 0.0)))
	var struck := age(float(state.get("pose_at", 0.0)))
	for index in count:
		var frame := _mirror_rect(index, count)
		var shake := Vector2.ZERO
		if outcome == "caught" and index == accused and since < 0.3 and not reduced_motion:
			shake = Vector2(sin(since * 70.0) * 5.0 * (1.0 - since / 0.3), 0)
		# A fresh row of mirrors drops in one after another.
		var drop := 0.0 if reduced_motion else -40.0 * (1.0 - smoothstep(0.0, 0.16, entered - index * 0.03))
		frame.position += shake + Vector2(0, drop)
		_draw_mirror(frame, index == selected and outcome.is_empty())
		var escaping := outcome == "escaped" and index == fake
		if not escaping and index < reflections.size():
			var mood := "plain"
			if outcome == "caught" and index == accused:
				mood = "shocked"
			elif outcome == "escaped" and index == accused:
				mood = "sorry"
			var feet := Vector2(frame.get_center().x, frame.end.y - 22.0)
			_draw_figure(feet, REFLECTION_UNIT, reflections[index], true, mood, squash(struck, 0.12, 0.22))
		if outcome == "caught" and index == accused:
			_draw_stamp(frame.get_center() + Vector2(0, -34), since)
	if outcome.is_empty():
		_draw_spotlight(_mirror_rect(selected, count))
	elif outcome == "escaped" and fake >= 0 and fake < count:
		_draw_escape(_mirror_rect(fake, count), since)
	_draw_hero(struck)


# --- Mirrors ----------------------------------------------------------------

func _mirror_rect(index: int, count: int) -> Rect2:
	var row := count * MIRROR_SIZE.x + (count - 1) * MIRROR_GAP
	return Rect2(640.0 - row * 0.5 + index * (MIRROR_SIZE.x + MIRROR_GAP), MIRROR_TOP, MIRROR_SIZE.x, MIRROR_SIZE.y)


func _draw_mirror(frame: Rect2, lit: bool) -> void:
	ground_shadow(Vector2(frame.get_center().x, FLOOR_TOP + 12.0), Vector2(86, 12), 0.36)
	for side: float in [-1.0, 1.0]:
		var x := frame.get_center().x + side * 48.0
		draw_rect(Rect2(x - 9.0, frame.end.y - 4.0, 18, FLOOR_TOP - frame.end.y + 12.0), INK)
		draw_rect(Rect2(x - 6.0, frame.end.y - 4.0, 12, FLOOR_TOP - frame.end.y + 9.0), BRASS_DARK)
		draw_rect(Rect2(x - 6.0, frame.end.y - 4.0, 4, FLOOR_TOP - frame.end.y + 9.0), BRASS)
	draw_rect(frame.grow(4.0), INK)
	draw_rect(frame, BRASS_LIGHT if lit else BRASS)
	draw_rect(Rect2(frame.position, Vector2(frame.size.x, 5)), Color.WHITE if lit else BRASS_LIGHT)
	draw_rect(Rect2(frame.position.x, frame.end.y - 7.0, frame.size.x, 7), BRASS_DARK)
	draw_rect(Rect2(frame.end.x - 6.0, frame.position.y, 6, frame.size.y), BRASS_DARK)
	var glass := frame.grow(-14.0)
	draw_rect(glass.grow(4.0), INK)
	draw_rect(glass, Color("#9fd2dc"))
	draw_rect(Rect2(glass.position, Vector2(glass.size.x, 64)), Color("#bfe7ec"))
	draw_rect(Rect2(glass.position.x, glass.end.y - 30.0, glass.size.x, 30), Color("#7fb6c6"))
	draw_colored_polygon(PackedVector2Array([
		glass.position + Vector2(14, 0), glass.position + Vector2(34, 0),
		glass.position + Vector2(-20, glass.size.y) + Vector2(34, 0), glass.position + Vector2(-20, glass.size.y) + Vector2(14, 0)]),
		Color(1, 1, 1, 0.16))
	# A small crest with one bulb crowns every frame.
	var crest := Vector2(frame.get_center().x, frame.position.y - 10.0)
	draw_rect(Rect2(crest - Vector2(26, 8), Vector2(52, 16)), INK)
	draw_rect(Rect2(crest - Vector2(23, 5), Vector2(46, 10)), BRASS)
	draw_rect(Rect2(crest - Vector2(7, 7), Vector2(14, 14)), INK)
	draw_rect(Rect2(crest - Vector2(4, 4), Vector2(8, 8)), Color("#fff3b0") if lit else BRASS_DARK)


func _draw_spotlight(frame: Rect2) -> void:
	var bob := 6.0 * pulse(1.6)
	var tip := Vector2(frame.get_center().x, frame.position.y - 30.0 + bob)
	for row in 5:
		var half := 18.0 - row * 4.0
		draw_rect(Rect2(tip.x - half - 3.0, tip.y - 26.0 + row * 5.0 - 3.0, half * 2.0 + 6.0, 11), INK)
	for row in 5:
		var half := 18.0 - row * 4.0
		draw_rect(Rect2(tip.x - half, tip.y - 26.0 + row * 5.0, half * 2.0, 5), GOLD)
	draw_rect(frame.grow(8.0), Color(GOLD, 0.5 + 0.4 * pulse(1.6)), false, 4.0)


func _draw_stamp(center: Vector2, since: float) -> void:
	var plate := Rect2(-52, -26, 104, 52)
	draw_set_transform(center, -0.16, Vector2.ONE * pop_in(since, 0.16))
	draw_rect(plate.grow(4.0), Color("#7a1626"))
	draw_rect(plate, Color("#e23b54"))
	draw_rect(plate.grow(-5.0), CREAM, false, 3.0)
	draw_set_transform(Vector2.ZERO)
	label(center, "假的！", 30, CREAM, pop_in(since, 0.16))


# --- Figures ----------------------------------------------------------------

func _draw_hero(struck: float) -> void:
	ground_shadow(HERO_FEET + Vector2(0, 4), Vector2(120, 18), 0.5)
	draw_set_transform(HERO_FEET + Vector2(0, 2), 0.0, Vector2(1.0, 0.24))
	draw_circle(Vector2.ZERO, 150.0, Color(1.0, 0.95, 0.7, 0.10))
	draw_circle(Vector2.ZERO, 104.0, Color(1.0, 0.95, 0.7, 0.12))
	draw_set_transform(Vector2.ZERO)
	_draw_figure(HERO_FEET, HERO_UNIT, state.get("pose", &"idle"), false, "plain", squash(struck, 0.14, 0.24))


## The fake steps out of its frame, tongue out, takes a bow and walks off stage.
func _draw_escape(frame: Rect2, since: float) -> void:
	var start := Vector2(frame.get_center().x, frame.end.y - 22.0)
	var landing := Vector2(frame.get_center().x, FLOOR_TOP + 64.0)
	var step_out := 1.0 if reduced_motion else smoothstep(0.1, 0.6, since)
	var hop := 0.0 if reduced_motion else -34.0 * sin(step_out * PI)
	var feet := start.lerp(landing, step_out) + Vector2(0, hop)
	# After the bow it strolls toward the nearer wing.
	var stroll := 0.0 if reduced_motion else maxf(0.0, since - 1.1) * 260.0
	feet.x += stroll * (1.0 if frame.get_center().x >= 640.0 else -1.0)
	var unit := lerpf(REFLECTION_UNIT, 7.0, step_out)
	ground_shadow(Vector2(feet.x, landing.y + 4.0), Vector2(60, 9) * step_out, 0.4)
	var wiggle := &"up" if reduced_motion or int(since * 6.0) % 2 == 0 else &"idle"
	_draw_figure(feet, unit, wiggle, true, "tongue", squash(since - 0.6, 0.3))
	if since > 0.5:
		label(feet + Vector2(0, -38.0 * unit), "略略略～", 26, ROSE, pop_in(since - 0.5, 0.2))


## Draw one pixel person standing on `feet`; one art pixel is `unit` screen pixels.
func _draw_figure(feet: Vector2, unit: float, pose: StringName, front: bool, mood: String, stretch: Vector2) -> void:
	var key := "%s|%s|%s" % [pose, front, mood]
	if not _figures.has(key):
		_figures[key] = _build_figure(pose, front, mood)
	var blocks: Array = _figures[key]
	# A raised-arm pose is a small jump: lift the whole figure.
	var lift := Vector2(0, -3.0 * unit) if pose == &"up" else Vector2.ZERO
	draw_set_transform(feet + lift, 0.0, stretch * unit)
	for block: Array in blocks:
		draw_rect((block[0] as Rect2).grow(0.5), INK)
	for block: Array in blocks:
		draw_rect(block[0], block[1])
	draw_set_transform(Vector2.ZERO)


## Blocks in art pixels around the feet (x right, y up is negative).
static func _build_figure(pose: StringName, front: bool, mood: String) -> Array:
	var blocks: Array = []
	var lean := -1.0 if pose == &"left" else (1.0 if pose == &"right" else 0.0)
	blocks.append([Rect2(-4, -8, 3, 8), PANTS])
	blocks.append([Rect2(1, -8, 3, 8), PANTS])
	blocks.append([Rect2(-5, -1, 4, 1), SHOES])
	blocks.append([Rect2(1, -1, 4, 1), SHOES])
	blocks.append([Rect2(-5 + lean * 0.5, -18, 10, 10), SHIRT])
	blocks.append([Rect2(-5 + lean * 0.5, -11, 10, 3), SHIRT_SHADE])
	if front:
		blocks.append([Rect2(-1 + lean * 0.5, -18, 2, 7), CREAM])
	match pose:
		&"left":
			blocks.append([Rect2(-12, -17, 7, 2), SHIRT])
			blocks.append([Rect2(-14, -17, 2, 2), SKIN])
			blocks.append([Rect2(5.5, -17, 2, 6), SHIRT])
			blocks.append([Rect2(5.5, -11, 2, 2), SKIN])
		&"right":
			blocks.append([Rect2(5, -17, 7, 2), SHIRT])
			blocks.append([Rect2(12, -17, 2, 2), SKIN])
			blocks.append([Rect2(-7.5, -17, 2, 6), SHIRT])
			blocks.append([Rect2(-7.5, -11, 2, 2), SKIN])
		&"up":
			for x: float in [-7.0, 5.0]:
				blocks.append([Rect2(x, -25, 2, 8), SHIRT])
				blocks.append([Rect2(x, -27, 2, 2), SKIN])
		_:
			for x: float in [-7.0, 5.0]:
				blocks.append([Rect2(x, -17, 2, 7), SHIRT])
				blocks.append([Rect2(x, -10, 2, 2), SKIN])
	var head := Rect2(-5 + lean, -28, 10, 10)
	blocks.append([head, SKIN])
	if not front:
		blocks.append([Rect2(head.position.x, head.position.y - 1.0, 10, 8), HAIR])
		blocks.append([Rect2(head.position.x + 2.0, head.position.y + 7.0, 6, 1), HAIR])
		return blocks
	blocks.append([Rect2(head.position.x, head.position.y - 1.0, 10, 3), HAIR])
	blocks.append([Rect2(head.position.x, head.position.y + 2.0, 1, 3), HAIR])
	blocks.append([Rect2(head.position.x + 9.0, head.position.y + 2.0, 1, 3), HAIR])
	var eye_y := head.position.y + 4.0
	var left_eye := head.position.x + 2.0
	var right_eye := head.position.x + 7.0
	match mood:
		"tongue":
			blocks.append([Rect2(left_eye - 0.5, eye_y + 0.5, 2, 1), SHOES])
			blocks.append([Rect2(right_eye, eye_y, 1, 2), SHOES])
			blocks.append([Rect2(head.position.x + 3.0, head.position.y + 7.0, 4, 1), SHOES])
			blocks.append([Rect2(head.position.x + 4.0, head.position.y + 8.0, 2, 3), Color("#ff6f9c")])
		"shocked":
			blocks.append([Rect2(left_eye - 0.5, eye_y - 0.5, 2, 2), CREAM])
			blocks.append([Rect2(right_eye - 0.5, eye_y - 0.5, 2, 2), CREAM])
			blocks.append([Rect2(left_eye, eye_y, 1, 1), SHOES])
			blocks.append([Rect2(right_eye, eye_y, 1, 1), SHOES])
			blocks.append([Rect2(head.position.x + 4.0, head.position.y + 7.0, 2, 2), SHOES])
		"sorry":
			blocks.append([Rect2(left_eye, eye_y, 1, 2), SHOES])
			blocks.append([Rect2(right_eye, eye_y, 1, 2), SHOES])
			blocks.append([Rect2(head.position.x + 4.0, head.position.y + 7.5, 2, 1), SHOES])
			blocks.append([Rect2(head.position.x + 10.0, head.position.y + 1.0, 1, 2), Color("#8fd6ff")])
		_:
			blocks.append([Rect2(left_eye, eye_y, 1, 2), SHOES])
			blocks.append([Rect2(right_eye, eye_y, 1, 2), SHOES])
			blocks.append([Rect2(head.position.x + 3.0, head.position.y + 7.0, 4, 1), SHOES])
			blocks.append([Rect2(head.position.x + 1.0, head.position.y + 6.0, 1, 1), Color("#ff9d9d")])
			blocks.append([Rect2(head.position.x + 8.0, head.position.y + 6.0, 1, 1), Color("#ff9d9d")])
	return blocks
