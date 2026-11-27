extends "res://game/minigames/arcade/arcade_view.gd"
## Picture for 木偶牽線: a little puppet theatre on the workshop bench, velvet
## curtains in a gilt frame and a row of footlights that brighten on the beat.
## A wooden marionette in a red jacket hangs from a cross-shaped control bar by
## four strings; brass beads marked with their arrow slide down each string to a
## glowing ring at the limb. A pulled string yanks its limb up. Too many knots
## and the strings snarl, the puppet flips upside down and waves at the island
## traveller (arcade_hero) watching from the wings. Baked pixel art in the
## backdrop's dusk palette.

const Hero = preload("res://game/minigames/arcade/arcade_hero.gd")
const YARD_ART := "res://assets/world/toy-clockwork-yard.webp"
const STAGE := Rect2(380, 150, 520, 420)
const FLOOR_Y := 570.0
const BAR := Vector2(640, 198)
const BAR_SIZE := Vector2i(52, 6)
## Where each string hangs from the control bar: head, left hand, right hand, and the two feet.
const BAR_POINTS: Array[Vector2] = [Vector2(640, 196), Vector2(556, 194), Vector2(724, 194), Vector2(530, 204), Vector2(750, 204)]
const TORSO := Vector2(640, 392)
## The puppet is drawn a size up from the theatre so it reads at a glance.
const S := 1.5
const HEAD := Vector2i(12, 12)
const BODY := Vector2i(12, 16)
const ARM := Vector2i(4, 14)
const LEG := Vector2i(5, 15)
const BEAD := Vector2i(9, 9)
const HERO_FEET := Vector2(1060, 664)
const HERO_SCALE := 3.0
const ARROWS: Array[String] = ["↑", "←", "→", "↓"]
const WOOD := Color("#7a5238")
const PINE := Color("#d2a46a")
const JACKET := Color("#c0503f")
const TROUSER := Color("#4f79a8")
const BRASS := Color("#c9953e")
const STRING_TONE := Color("#efe0bc")
const CURTAIN := Color("#7a2a3c")
const BACKCLOTH := Color("#2c2440")
const DARK := Color("#2b2440")
const LABEL := Color("#efe0bc")
const DUSK := Color(1.0, 0.93, 0.86)

var _has_art := false
var _head: ImageTexture
var _body: ImageTexture
var _arm: ImageTexture
var _leg: ImageTexture
var _bead: ImageTexture
var _bar: ImageTexture
## The puppet's torso frame while its parts are drawn.
var _current := Transform2D.IDENTITY


func _init() -> void:
	super()
	# Words pop beside the stage, clear of the puppet, its strings and the keys.
	word_anchor = Vector2(175, 380)


func _ready() -> void:
	_has_art = use_backdrop_art(YARD_ART, Rect2(190, 0, 1157, 651), Color(0.5, 0.45, 0.52))
	_head = Pixels.bake("puppet-head", HEAD, _paint_head)
	_body = Pixels.bake("puppet-body", BODY, _paint_body)
	_arm = Pixels.bake("puppet-arm", ARM, _paint_arm)
	_leg = Pixels.bake("puppet-leg", LEG, _paint_leg)
	_bead = Pixels.bake("puppet-bead", BEAD, func(x: int, y: int) -> Color:
		var at := (Vector2(x + 0.5, y + 0.5) - Vector2(4.5, 4.5)) / 4.5
		return Pixels.rounded(BRASS, at) if at.length() <= 1.0 else Pixels.CLEAR)
	_bar = Pixels.bake("puppet-bar", BAR_SIZE, func(x: int, y: int) -> Color:
		if absf(x + 0.5 - BAR_SIZE.x * 0.5) < 2.0:
			return Pixels.wood(PINE.darkened(0.15), x, y, 3)
		return Pixels.wood(PINE, x, y, 9, false) if y >= 2 and y < 5 else Pixels.CLEAR)


func _draw_backdrop() -> void:
	if not _has_art:
		draw_rect(Rect2(Vector2.ZERO, DESIGN), Color("#3a2c2a"))
	bench(FLOOR_Y + 20.0, WOOD)
	vignette()


func _draw_scene() -> void:
	if not state.has("beads"):
		return
	_draw_theatre_back()
	var since_tangle := age(float(state.get("tangled_at", -99.0)))
	var tangled := since_tangle >= 0.0 and since_tangle < float(state.get("tangle_seconds", 1.8))
	var pose := _pose(tangled, since_tangle)
	if tangled:
		_draw_knotted_strings(pose, since_tangle)
	else:
		_draw_strings(pose)
	_draw_puppet(pose)
	if not tangled:
		_draw_beads(pose)
	_draw_bar()
	_draw_theatre_front()
	_draw_keys(pose, tangled)
	_draw_hero(tangled)
	_draw_combo()
	if tangled and since_tangle > 0.3:
		label(Vector2(830, 330), "嗨～", 24, LABEL, pop_in(since_tangle - 0.3, 0.2))


# --- Theatre ------------------------------------------------------------------

func _draw_theatre_back() -> void:
	panel(STAGE, "velvet", BACKCLOTH, Color(0, 0, 0, 0), TEXEL, DUSK)
	# Stage boards and a row of footlights that brighten on the beat.
	panel(Rect2(STAGE.position.x, FLOOR_Y - 18.0, STAGE.size.x, 30), "planks", PINE.darkened(0.2), Color(0, 0, 0, 0), TEXEL, DUSK)
	var beat := clampf(1.0 - age(float(state.get("beat_at", -99.0))) / 0.25, 0.0, 1.0)
	if reduced_motion:
		beat = 0.4
	for bulb in 9:
		var at := Vector2(STAGE.position.x + 40.0 + bulb * 55.0, FLOOR_Y + 8.0)
		draw_circle(at, 18.0, Color(1.0, 0.85, 0.5, 0.12 + 0.18 * beat))
		draw_circle(at, 7.0, DARK)
		draw_circle(at, 5.0, Color("#ffe7a0").lerp(Color.WHITE, 0.4 * beat))


func _draw_theatre_front() -> void:
	# Velvet curtains drawn back to each side, a gilt proscenium on top.
	for side in 2:
		var x := STAGE.position.x - 30.0 if side == 0 else STAGE.end.x - 50.0
		panel(Rect2(x, STAGE.position.y + 30.0, 80, STAGE.size.y - 12.0), "velvet", CURTAIN, GOLD.darkened(0.2), TEXEL, DUSK)
	panel(Rect2(STAGE.position.x - 40.0, STAGE.position.y, STAGE.size.x + 80.0, 44), "velvet", CURTAIN.darkened(0.1), GOLD.darkened(0.2), TEXEL, DUSK)
	gilt_frame(Rect2(STAGE.position.x - 48.0, STAGE.position.y - 8.0, STAGE.size.x + 96.0, STAGE.size.y + 40.0), 12.0, GILT, TEXEL, DUSK)
	ground_shadow(Vector2(STAGE.get_center().x + 14.0, STAGE.end.y + 34.0), Vector2(STAGE.size.x * 0.55, 14), 0.4)


func _draw_bar() -> void:
	var sway := 0.0 if reduced_motion else 0.04 * sin(now * 2.0)
	draw_set_transform(BAR, sway, Vector2.ONE)
	stamp(_bar, -Vector2(BAR_SIZE.x * 0.5, BAR_SIZE.y * 0.5) * TEXEL, TEXEL, DUSK)
	draw_set_transform(Vector2.ZERO)
	# Knots tied so far, as little loops along the bar.
	var knots := int(float(state.get("knots", 0.0)))
	for knot in int(state.get("knot_limit", 4)):
		var at := BAR + Vector2(-60.0 + knot * 40.0, 22.0)
		draw_arc(at, 7.0, 0.0, TAU, 12, DARK if knot < knots else Color(LABEL, 0.25), 3.0)
		if knot < knots:
			draw_line(at + Vector2(-9, 6), at + Vector2(9, -6), DARK, 3.0)


# --- Puppet -------------------------------------------------------------------

## How far each string's limb is pulled up right now, 0..1.
func _lift(string: int) -> float:
	var pulled: Array = state.get("pulled_at", [-99.0, -99.0, -99.0, -99.0])
	var since := age(float(pulled[string]))
	if since < 0.0 or since > 0.4:
		return 0.0
	if reduced_motion:
		return 1.0 if since < 0.25 else 0.0
	return 1.0 - smoothstep(0.08, 0.4, since)


## Joint positions and angles for this frame.
func _pose(tangled: bool, since_tangle: float) -> Dictionary:
	var hop := -12.0 * maxf(_lift(0), _lift(3))
	var sway := 0.0 if reduced_motion else 6.0 * sin(now * 2.2)
	var torso := TORSO + Vector2(sway, hop)
	var arms := [lerpf(0.18, 2.5, _lift(1)), lerpf(-0.18, -2.5, _lift(2))]
	var kick := _lift(3)
	var legs := [lerpf(0.05, 0.9, kick), lerpf(-0.05, -0.9, kick)]
	var head_lift := -10.0 * _lift(0)
	if tangled:
		# Upside down, one arm waving at the traveller.
		var wave := 0.0 if reduced_motion else 0.6 * sin(since_tangle * 12.0)
		# Flipped, the left arm is the one on the traveller's side.
		arms = [2.2 + wave, -0.4]
		legs = [0.25, -0.25]
		head_lift = 0.0
	return {"torso": torso, "arms": arms, "legs": legs, "head_lift": head_lift, "flip": tangled}


## Where each string meets the puppet: head, left hand, right hand, left foot, right foot.
func _attach(pose: Dictionary) -> Array[Vector2]:
	var torso: Vector2 = pose.torso
	var points: Array[Vector2] = []
	points.append(torso + Vector2(0, -88 + float(pose.head_lift)) * S)
	for side in 2:
		var shoulder := torso + Vector2(-26.0 if side == 0 else 26.0, -24) * S
		points.append(shoulder + Vector2(0, ARM.y * TEXEL - 4.0).rotated(float(pose.arms[side])) * S)
	for side in 2:
		var hip := torso + Vector2(-12.0 if side == 0 else 12.0, 30) * S
		points.append(hip + Vector2(0, LEG.y * TEXEL - 4.0).rotated(float(pose.legs[side])) * S)
	if bool(pose.flip):
		for index in points.size():
			points[index] = _flip(points[index], pose)
	return points


func _flip(point: Vector2, pose: Dictionary) -> Vector2:
	var torso: Vector2 = pose.torso
	return torso + (point - torso).rotated(PI)


func _draw_puppet(pose: Dictionary) -> void:
	var torso: Vector2 = pose.torso
	var flip := bool(pose.flip)
	var turn := PI if flip else 0.0
	ground_shadow(Vector2(torso.x + 8.0, FLOOR_Y - 4.0), Vector2(80, 12), 0.3)
	_current = Transform2D(turn, Vector2(S, S), 0.0, torso)
	draw_set_transform_matrix(_current)
	for side in 2:
		var hip := Vector2(-12.0 if side == 0 else 12.0, 30)
		_limb(_leg, LEG, hip, float(pose.legs[side]))
	_limb(_arm, ARM, Vector2(-26, -24), float(pose.arms[0]))
	stamp(_body, Vector2(-BODY.x * 0.5, -BODY.y * 0.5) * TEXEL, TEXEL, DUSK)
	stamp(_head, Vector2(-HEAD.x * 0.5, -HEAD.y - 8.0 / TEXEL) * TEXEL + Vector2(0, -32 + float(pose.head_lift)), TEXEL, DUSK)
	_limb(_arm, ARM, Vector2(26, -24), float(pose.arms[1]))
	draw_set_transform(Vector2.ZERO)


## A limb sprite hanging from `joint` (in the torso's frame), turned by `angle`.
func _limb(sprite: ImageTexture, size: Vector2i, joint: Vector2, angle: float) -> void:
	draw_set_transform_matrix(_current * Transform2D(angle, joint))
	stamp(sprite, Vector2(-size.x * 0.5, -1.0) * TEXEL, TEXEL, DUSK)
	draw_set_transform_matrix(_current)



func _draw_strings(pose: Dictionary) -> void:
	var ends := _attach(pose)
	for index in ends.size():
		var top := BAR_POINTS[index]
		var lit := _lift(mini(index, 3)) > 0.0
		draw_line(top, ends[index], Color(STRING_TONE, 0.9 if lit else 0.55), 2.0 if lit else 1.5)


func _draw_knotted_strings(pose: Dictionary, since: float) -> void:
	var ends := _attach(pose)
	var knot := BAR + Vector2(0, 60)
	for index in ends.size():
		var points := PackedVector2Array([BAR_POINTS[index]])
		for step in 6:
			var t := (step + 1) / 7.0
			var wobble := Vector2(sin(index * 3.1 + step * 2.3) * 26.0, cos(index * 1.7 + step * 1.9) * 12.0)
			points.append(BAR_POINTS[index].lerp(knot, t * 2.0) if t < 0.5 else knot.lerp(ends[index], t * 2.0 - 1.0))
			points[-1] += wobble * sin(t * PI)
		points.append(ends[index])
		draw_polyline(points, Color(STRING_TONE, 0.8), 2.0)
	draw_circle(knot, 14.0, Color(STRING_TONE, 0.5))
	draw_arc(knot, 14.0, 0.0, TAU, 16, STRING_TONE, 2.0)


func _draw_beads(pose: Dictionary) -> void:
	var ends := _attach(pose)
	var lead := float(state.get("lead", 1.3))
	for bead: Dictionary in state.beads:
		var string := int(bead.string)
		var end := ends[string]
		var top := BAR_POINTS[string]
		if string == 3:
			# The feet bead rides between the two foot strings.
			end = (ends[3] + ends[4]) * 0.5
			top = (BAR_POINTS[3] + BAR_POINTS[4]) * 0.5
		var left := float(bead.t) - now
		match str(bead.state):
			"coming":
				var t := clampf(1.0 - left / lead, 0.0, 1.0)
				var at := top.lerp(end, t)
				var near := clampf(1.0 - absf(left) / 0.3, 0.0, 1.0)
				stamp(_bead, at - Vector2(BEAD) * TEXEL * 0.5, TEXEL, DUSK.lerp(Color.WHITE, 0.3 * near))
				label(at + Vector2(0, 1), ARROWS[string], 18, DARK, 1.0, 1.0, false)
			"hit":
				var since := age(float(bead.at))
				var burst := pop_in(since, 0.15)
				draw_arc(end, 16.0 + 30.0 * since, 0.0, TAU, 20, Color(GOLD, 1.0 - since / 0.6), 4.0)
				if str(bead.grade) == "perfect":
					glint(end, 24.0 * burst, 99.0, -since)
			"miss":
				var since := age(float(bead.at))
				var at := end + Vector2(0, 260.0 * since * since)
				stamp(_bead, at - Vector2(BEAD) * TEXEL * 0.5, TEXEL, Color(DUSK, 1.0 - since / 0.6))
	# The landing rings at each limb pulse with the beat.
	var beat := clampf(1.0 - age(float(state.get("beat_at", -99.0))) / 0.25, 0.0, 1.0)
	for string in 4:
		var end := ends[string] if string < 3 else (ends[3] + ends[4]) * 0.5
		draw_arc(end, 20.0 + 4.0 * beat, 0.0, TAU, 20, Color(GOLD, 0.5 + 0.4 * beat), 3.0)


func _draw_keys(pose: Dictionary, tangled: bool) -> void:
	var ends := _attach(pose)
	var spots: Array[Vector2] = [Vector2(744, 268), Vector2(470, 470), Vector2(810, 470), Vector2(640, 612)]
	for string in 4:
		key_cap(spots[string], ARROWS[string], _lift(string) > 0.6 and not tangled, 18)


func _draw_hero(tangled: bool) -> void:
	var pulled := false
	for string in 4:
		pulled = pulled or _lift(string) > 0.5
	var pose := &"up" if pulled else &"idle"
	var mood := "shocked" if tangled else ("tongue" if int(state.get("combo", 0)) >= 12 else "plain")
	ground_shadow(HERO_FEET + Vector2(6, 2), Vector2(56, 13), 0.42)
	stamp(Hero.texture(pose, true, mood), HERO_FEET - Vector2(20, 46) * HERO_SCALE, HERO_SCALE, DUSK)


func _draw_combo() -> void:
	var combo := int(state.get("combo", 0))
	if combo >= 4:
		label(Vector2(1110, 250), "連拍 × %d" % combo, 26, GOLD, 1.0 + 0.08 * pulse(2.0))
	label(Vector2(200, 250), "第 %d 段" % (int(state.get("section", 0)) + 1), 22, LABEL)


# --- Texel painters -------------------------------------------------------------

func _paint_head(x: int, y: int) -> Color:
	var at := Vector2(x + 0.5, y + 0.5)
	# A little red cap over a round wooden face with painted cheeks and a smile.
	if y < 4:
		var cap := (at - Vector2(6, 4)) / Vector2(5, 3.6)
		if cap.length() <= 1.0:
			return Pixels.rounded(JACKET, cap) if y > 0 or absf(at.x - 6.0) > 1.0 else BRASS
		return Pixels.CLEAR
	var face := (at - Vector2(6, 7.5)) / Vector2(5.5, 4.6)
	if face.length() > 1.0:
		return Pixels.CLEAR
	if y == 7 and (x == 4 or x == 7):
		return DARK
	if y == 9 and (x == 3 or x == 8):
		return Color("#f08c8c")
	if y == 10 and x >= 5 and x <= 6:
		return JACKET.darkened(0.2)
	return Pixels.rounded(PINE.lightened(0.1), face)


func _paint_body(x: int, y: int) -> Color:
	var at := Vector2(x + 0.5, y + 0.5)
	# A red jacket with a white collar and brass buttons; wooden hips below.
	if y >= 13:
		return Pixels.wood(PINE.darkened(0.1), x, y, 3) if x >= 2 and x < 10 else Pixels.CLEAR
	if x < 1 or x >= 11:
		return Pixels.CLEAR
	if y < 2:
		return Color("#f3ead6") if x >= 3 and x < 9 else Pixels.CLEAR
	if x == 6 and y % 3 == 0:
		return BRASS.lightened(0.2)
	return Pixels.grainy(Pixels.rounded(JACKET, Vector2((at.x - 6.0) / 5.0, (at.y - 7.0) / 7.0)), x, y, 0.08)


func _paint_arm(x: int, y: int) -> Color:
	# A red sleeve with a wooden hand at the end.
	if y >= 10:
		return Pixels.rounded(PINE.lightened(0.05), Vector2((x - 1.5) / 2.0, (y - 11.5) / 2.0))
	if y == 9:
		return Color("#f3ead6")
	return Pixels.rounded(JACKET.darkened(0.05), Vector2((x - 1.5) / 2.0, -0.2))


func _paint_leg(x: int, y: int) -> Color:
	# Blue trousers, a wooden knee and a black shoe.
	if y >= 12:
		return DARK.lightened(0.15) if y < 14 or x >= 1 else Pixels.CLEAR
	if y == 6:
		return PINE.darkened(0.1)
	return Pixels.rounded(TROUSER, Vector2((x - 2.0) / 2.5, -0.2))
