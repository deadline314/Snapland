extends "res://game/minigames/arcade/arcade_view.gd"
## Picture for 誰是假倒影: a row of gilded standing mirrors, the hero seen from
## behind in a spotlight, and the fake that sticks its tongue out and walks off
## when the wrong mirror is accused. Frames, glass and the traveller are baked
## pixel art (arcade_pixels.gd, arcade_hero.gd) in the tent's dusky palette.

const Hero = preload("res://game/minigames/arcade/arcade_hero.gd")
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
const BRASS := Color("#b0803a")
const BRASS_DARK := Color("#8a5a26")
const BULB := Color("#fff0b0")
const GLASS_TINT := Color("#9aa6bc")
const TENT_GLOW := Color("#d99a86")
const STAMP_RED := Color("#c23a50")
const POSES: Array[StringName] = [&"idle", &"left", &"right", &"up"]
const MOODS: Array[String] = ["plain", "shocked", "sorry", "tongue"]
## Scene light: a touch of the tent's dusk on every sprite; reflections also
## take a little of the glass's cool tone.
const DUSK := Color(1.0, 0.94, 0.9)
const IN_GLASS := Color(0.9, 0.92, 1.0)
## Lights up the mirror under the spotlight.
const LIT := Color(1.22, 1.16, 1.02)

var _has_tent := false
var _crest: ImageTexture


func _init() -> void:
	super()
	# Words land on the open floor beside the hero, clear of every mirror.
	word_anchor = Vector2(300, 604)


func _ready() -> void:
	_has_tent = use_backdrop_art(TENT_ART, Rect2(213, 60, 1110, 624), Color(0.7, 0.66, 0.8))
	# Bake every look of the traveller now so play never paints a sprite.
	for pose in POSES:
		Hero.texture(pose, false, "plain")
		for mood in MOODS:
			Hero.texture(pose, true, mood)
	_crest = Pixels.bake("mirror-crest", Vector2i(15, 6), func(x: int, y: int) -> Color:
		var offset := Vector2((x - 7.0) / 7.5, (y - 5.5) / 6.0)
		if offset.length() > 1.0 or y > 5:
			return Pixels.CLEAR
		if offset.length() > 0.62 and posmod(x, 3) == 0:
			return BRASS.darkened(0.35)
		return Pixels.rounded(BRASS, offset))


func _draw_backdrop() -> void:
	if not _has_tent:
		draw_rect(Rect2(Vector2.ZERO, DESIGN), Color("#2b1f3a"))
	stage_floor(FLOOR_TOP, WOOD, WOOD_DARK)
	vignette(0.45)


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
		var landing := entered - index * 0.03
		var drop := 0.0 if reduced_motion else -40.0 * (1.0 - smoothstep(0.0, 0.16, landing))
		frame.position += shake + Vector2(0, drop)
		var lit := index == selected and outcome.is_empty()
		_draw_mirror_stand(frame)
		_draw_glass(frame, index)
		var escaping := outcome == "escaped" and index == fake
		if not escaping and index < reflections.size():
			var mood := "plain"
			if outcome == "caught" and index == accused:
				mood = "shocked"
			elif outcome == "escaped" and index == accused:
				mood = "sorry"
			var feet := Vector2(frame.get_center().x, frame.end.y - 22.0)
			_draw_figure(feet, REFLECTION_UNIT, reflections[index], true, mood, squash(struck, 0.12, 0.22), IN_GLASS)
		_draw_frame(frame, lit)
		dust_puffs(Vector2(frame.get_center().x, FLOOR_TOP + 10.0), landing - 0.16, 70.0)
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


## Two brass legs on footed plates, standing in their own shadow.
func _draw_mirror_stand(frame: Rect2) -> void:
	ground_shadow(Vector2(frame.get_center().x, FLOOR_TOP + 12.0), Vector2(86, 12), 0.36)
	for side: float in [-1.0, 1.0]:
		var x := frame.get_center().x + side * 48.0
		panel(Rect2(x - 10.0, frame.end.y - 6.0, 20, FLOOR_TOP - frame.end.y + 14.0), "pole", BRASS, Pixels.CLEAR, 3.0, DUSK)
		panel(Rect2(x - 18.0, FLOOR_TOP + 2.0, 36, 12), "lacquer", BRASS_DARK, Pixels.CLEAR, 3.0, DUSK)
	draw_rect(Rect2(frame.position + Vector2(10, 12), frame.size), Color(0.06, 0.02, 0.08, 0.28))


func _draw_glass(frame: Rect2, index: int) -> void:
	var glass := frame.grow(-14.0)
	panel(glass.grow(4.0), "glass", GLASS_TINT, TENT_GLOW, 3.0)
	# Each mirror catches the light a moment after its neighbour.
	sheen(glass, fposmod(now - index * 0.18, 4.0) / 0.7, 24.0, 0.16)


## The gilt frame goes on after the reflection so nothing spills past the glass.
func _draw_frame(frame: Rect2, lit: bool) -> void:
	var tint := LIT if lit else DUSK
	gilt_frame(frame.grow(4.0), 18.0, BRASS, 3.0, tint)
	# A gilt crest with one bulb crowns every frame.
	var crest := Vector2(frame.get_center().x, frame.position.y - 6.0)
	stamp(_crest, crest - Vector2(30, 18), 4.0, tint)
	if lit:
		draw_circle(crest + Vector2(0, -8), 13.0, Color(1.0, 0.92, 0.6, 0.25))
	draw_circle(crest + Vector2(0, -8), 7.0, BRASS.darkened(0.66))
	draw_circle(crest + Vector2(0, -8), 5.0, BULB if lit else Color("#7a5a4a"))
	draw_rect(Rect2(crest + Vector2(-3, -11), Vector2(2, 2)), Color(1, 1, 1, 0.9 if lit else 0.35))


func _draw_spotlight(frame: Rect2) -> void:
	var bob := 6.0 * pulse(1.6)
	var tip := Vector2(frame.get_center().x, frame.position.y - 38.0 + bob)
	for row in 5:
		var half := 18.0 - row * 4.0
		draw_rect(Rect2(tip.x - half - 3.0, tip.y - 26.0 + row * 5.0 - 3.0, half * 2.0 + 6.0, 11), GOLD.darkened(0.66))
	for row in 5:
		var half := 18.0 - row * 4.0
		draw_rect(Rect2(tip.x - half, tip.y - 26.0 + row * 5.0, half * 2.0, 5), GOLD.lightened(0.3) if row == 0 else GOLD.darkened(0.08 * row))
		draw_rect(Rect2(tip.x + half - 3.0, tip.y - 26.0 + row * 5.0, 3, 5), GOLD.darkened(0.35))
	draw_rect(frame.grow(10.0), Color(GOLD, 0.5 + 0.4 * pulse(1.6)), false, 4.0)


func _draw_stamp(center: Vector2, since: float) -> void:
	var plate_rect := Rect2(-56, -30, 112, 60)
	draw_set_transform(center, -0.16, Vector2.ONE * pop_in(since, 0.16))
	draw_rect(Rect2(plate_rect.position + Vector2(5, 7), plate_rect.size), Color(0.06, 0.02, 0.08, 0.4))
	panel(plate_rect, "lacquer", STAMP_RED, CREAM, 3.0)
	draw_set_transform(Vector2.ZERO)
	label(center, "假的！", 30, CREAM, pop_in(since, 0.16))


# --- Figures ----------------------------------------------------------------

func _draw_hero(struck: float) -> void:
	ground_shadow(HERO_FEET + Vector2(0, 4), Vector2(120, 18), 0.5)
	draw_set_transform(HERO_FEET + Vector2(0, 2), 0.0, Vector2(1.0, 0.24))
	draw_circle(Vector2.ZERO, 150.0, Color(1.0, 0.95, 0.7, 0.10))
	draw_circle(Vector2.ZERO, 104.0, Color(1.0, 0.95, 0.7, 0.12))
	draw_set_transform(Vector2.ZERO)
	_draw_figure(HERO_FEET, HERO_UNIT, state.get("pose", &"idle"), false, "plain", squash(struck, 0.14, 0.24), DUSK)


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
	dust_puffs(Vector2(feet.x, landing.y + 2.0), since - 0.6, 50.0)
	var wiggle := &"up" if reduced_motion or int(since * 6.0) % 2 == 0 else &"idle"
	_draw_figure(feet, unit, wiggle, true, "tongue", squash(since - 0.6, 0.3), DUSK)
	if since > 0.5:
		label(feet + Vector2(0, -32.0 * unit), "略略略～", 26, ROSE, pop_in(since - 0.5, 0.2))


## Draw the traveller standing on `feet`; `unit` keeps the old figure scale
## (one sprite texel is two thirds of it).
func _draw_figure(feet: Vector2, unit: float, pose: StringName, front: bool, mood: String, stretch: Vector2, tint: Color) -> void:
	var art := Hero.texture(pose, front, mood)
	# A raised-arm pose is a small jump: lift the whole figure.
	var lift := Vector2(0, -3.0 * unit) if pose == &"up" else Vector2.ZERO
	draw_set_transform(feet + lift, 0.0, stretch * unit * 2.0 / 3.0)
	draw_texture_rect(art, Rect2(-Hero.FEET, Vector2(art.get_size())), false, tint)
	draw_set_transform(Vector2.ZERO)
