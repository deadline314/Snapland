extends "res://game/minigames/arcade/arcade_view.gd"
## Picture for 影偶搭梯: a backlit paper screen in a wooden frame glows on the
## tent's stage with an oil lamp beneath it. Shadow puppets on rods glide in from
## the right; the hero sits at the left with both hands raised, and their hand
## shadow sits on the paper where the puppets arrive. A pinned card on the frame
## shows which arrow makes which shadow. When the shapes don't match, the hand
## shadow turns into a dog that faces the hero and barks. Shadows are cut from
## flat dark shapes so the paper's grain shows through; frame, lamp, card and
## hero are baked pixel art (arcade_pixels.gd, arcade_hero.gd).

const Hero = preload("res://game/minigames/arcade/arcade_hero.gd")
const TENT_ART := "res://assets/world/circus-tent.webp"
const FLOOR_TOP := 590.0
const SCREEN := Rect2(150, 176, 1000, 380)
const SHADOW_Y := 382.0
const HERO_FEET := Vector2(176, 664)
const SHAPE_TEXELS := Vector2i(40, 34)
const LAMP := Color(0.94, 0.89, 0.96)
const PAPER := Color("#f2dcae")
const INKSHADE := Color("#2a1d33")
const WOOD := Color("#6b4658")
const WOOD_DARK := Color("#3b2536")
const FRAME := Color("#7a5238")
const SHAPES: Array[String] = ["bird", "rabbit", "dog", "goose", "fist", "dog_open"]
const CARD := [["↑", "bird"], ["←", "rabbit"], ["→", "dog"], ["↓", "goose"]]

var _has_tent := false
var _shadows: Dictionary = {}
var _lamp: ImageTexture


func _init() -> void:
	super()
	word_anchor = Vector2(640, 250)


func _ready() -> void:
	_has_tent = use_backdrop_art(TENT_ART, Rect2(85, 0, 1366, 768), Color(0.6, 0.55, 0.68))
	for kind in SHAPES:
		_shadows[kind] = Pixels.cached("shadow-hand|" + kind, func() -> Image: return _shadow_image(kind))
	_lamp = Pixels.bake_blocks("shadow-lamp", Vector2i(14, 18), Vector2i(7, 18), [
		[Rect2(-6, -3, 12, 3), Color("#8a5a34")], [Rect2(-4, -6, 8, 3), Color("#b0803a")],
		[Rect2(-3, -14, 6, 8), Color("#d8e0e8")], [Rect2(-1, -12, 2, 4), Color("#ffd27a")], [Rect2(-1, -14, 2, 2), Color("#fff0b0")],
		[Rect2(-4, -16, 8, 2), Color("#b0803a")], [Rect2(-1, -18, 2, 2), Color("#8a5a34")]])


func _draw_backdrop() -> void:
	if not _has_tent:
		draw_rect(Rect2(Vector2.ZERO, DESIGN), Color("#2b1f3a"))
	stage_floor(FLOOR_TOP, WOOD, WOOD_DARK)
	vignette(0.55)


func _draw_scene() -> void:
	var phase := str(state.get("phase", "show"))
	var since := age(float(state.get("phase_at", 0.0)))
	_draw_screen()
	_draw_puppets()
	_draw_hand_shadow(phase, since)
	_draw_frame()
	_draw_card()
	_draw_hero(phase, since)


# --- Screen ----------------------------------------------------------------------

func _draw_screen() -> void:
	draw_rect(Rect2(SCREEN.position + Vector2(8, 12), SCREEN.size), Color(0.05, 0.02, 0.08, 0.4))
	panel(SCREEN, "paper", PAPER, Pixels.CLEAR, TEXEL, LAMP)
	# The lamp behind glows warmest low in the middle and falls off to the edges.
	var glow_at := Vector2(SCREEN.get_center().x - 120.0, SCREEN.end.y - 40.0)
	for ring in 6:
		var radii := Vector2(560.0 - ring * 80.0, 300.0 - ring * 44.0)
		_ellipse(glow_at, radii, Color(1, 0.86, 0.55, 0.06 + ring * 0.015))
	for band in 4:
		var shade := Color(0.12, 0.05, 0.1, 0.16 - band * 0.04)
		draw_rect(Rect2(SCREEN.position.x, SCREEN.position.y + band * 10.0, SCREEN.size.x, 10), shade)
		draw_rect(Rect2(SCREEN.end.x - 10.0 - band * 10.0, SCREEN.position.y, 10, SCREEN.size.y), shade)
	# Faint vertical seams where the paper sheets are pasted together.
	var seam := SCREEN.position.x + 250.0
	while seam < SCREEN.end.x:
		draw_rect(Rect2(seam, SCREEN.position.y, 2, SCREEN.size.y), Color(0.45, 0.3, 0.2, 0.12))
		seam += 250.0


func _draw_frame() -> void:
	var outer := SCREEN.grow(18.0)
	for side: Rect2 in [Rect2(outer.position, Vector2(outer.size.x, 18)), Rect2(outer.position.x, SCREEN.end.y, outer.size.x, 18),
			Rect2(outer.position, Vector2(18, outer.size.y)), Rect2(SCREEN.end.x, outer.position.y, 18, outer.size.y)]:
		panel(side, "planks", FRAME, Pixels.CLEAR, 2.0, LAMP)
	for leg: float in [outer.position.x + 30.0, outer.end.x - 30.0]:
		panel(Rect2(leg - 9.0, outer.end.y, 18, FLOOR_TOP + 40.0 - outer.end.y), "planks_v", FRAME.darkened(0.15), Pixels.CLEAR, 2.0, LAMP)
		ground_shadow(Vector2(leg, FLOOR_TOP + 42.0), Vector2(34, 7), 0.45)
	var lamp_at := Vector2(SCREEN.get_center().x - 120.0, outer.end.y + 6.0)
	stamp(_lamp, lamp_at - Vector2(7, 18) * TEXEL, TEXEL, LAMP)
	if not reduced_motion:
		draw_circle(lamp_at + Vector2(0, -50), 14.0 + pulse(3.0) * 4.0, Color(1, 0.85, 0.5, 0.25))


## The pinned card: which arrow makes which shadow.
func _draw_card() -> void:
	var card := Rect2(SCREEN.end.x - 330.0, SCREEN.end.y - 78.0, 320, 70)
	draw_rect(Rect2(card.position + Vector2(4, 6), card.size), Color(0.06, 0.02, 0.08, 0.35))
	panel(card, "paper", Color("#f7ecd4"), Pixels.CLEAR, 2.0, LAMP)
	draw_rect(Rect2(card.get_center().x - 22.0, card.position.y - 6.0, 44, 12), Color(0.95, 0.9, 0.75, 0.7))
	for index in CARD.size():
		var at := Vector2(card.position.x + 44.0 + index * 78.0, card.get_center().y)
		draw_set_transform(at + Vector2(10, -6), 0.0, Vector2.ONE * 1.1)
		draw_texture(_shadows[CARD[index][1]], -Vector2(SHAPE_TEXELS) * 0.5, Color(1, 1, 1, 0.85))
		draw_set_transform(Vector2.ZERO)
		key_cap(at + Vector2(-16, 14), str(CARD[index][0]), false, 13)


# --- Shadows ---------------------------------------------------------------------

func _shadow(kind: String, center: Vector2, turn: int, alpha := 0.84, grow := 1.0) -> void:
	draw_set_transform(center, 0.0, Vector2(float(turn), 1.0) * TEXEL * 1.3 * grow)
	draw_texture(_shadows[kind], -Vector2(SHAPE_TEXELS) * 0.5, Color(1, 1, 1, alpha))
	draw_set_transform(Vector2.ZERO)


func _draw_puppets() -> void:
	var enter_x := float(state.get("enter_x", 1240.0))
	var shadow_x := float(state.get("shadow_x", 380.0))
	for puppet: Dictionary in state.get("puppets", []):
		var span := maxf(0.1, float(puppet.arrive) - float(puppet.at))
		var t := clampf((now - float(puppet.at)) / span, 0.0, 1.0)
		var x := lerpf(enter_x, shadow_x, t)
		var alpha := 0.84
		var passed := float(puppet.passed_at)
		if passed >= 0.0:
			# Slipping through the hand shadow and out the other side.
			var after := now - passed
			x = shadow_x - after * 400.0
			alpha = 0.84 * (1.0 - clampf(after / 0.5, 0.0, 1.0))
		if x > SCREEN.end.x - 20.0:
			continue
		var bob := 0.0 if reduced_motion else sin(now * 4.0 + float(puppet.id)) * 4.0
		var at := Vector2(x, SHADOW_Y - 12.0 + bob)
		# The rod the stagehand holds it by, from below the screen.
		draw_line(at + Vector2(0, 50), Vector2(x + 20.0, SCREEN.end.y), Color(INKSHADE, alpha * 0.8), 5.0)
		_shadow(str(puppet.shape), at, int(puppet.facing), alpha)
		if passed < 0.0 and t > 0.55:
			# The name floats above as it comes close.
			label(at + Vector2(0, -112), NAME_OF.get(str(puppet.shape), ""), 18, Color("#5a3a3a"), 1.0, 0.8, false)
		if passed >= 0.0 and now - passed < 0.3 and not reduced_motion:
			for spark in 6:
				var heading := Vector2.from_angle(spark * TAU / 6.0)
				draw_rect(Rect2(Vector2(shadow_x, SHADOW_Y) + heading * (40.0 + (now - passed) * 200.0) - Vector2(4, 4), Vector2(8, 8)), Color(GOLD, 0.9))


const NAME_OF := {"bird": "鳥", "rabbit": "兔子", "dog": "狗", "goose": "鵝"}


func _draw_hand_shadow(phase: String, since: float) -> void:
	var shadow_x := float(state.get("shadow_x", 380.0))
	var shape := str(state.get("shape", "fist"))
	var turn := int(state.get("facing", 1))
	var changed := age(float(state.get("shaped_at", -9.0)))
	var at := Vector2(shadow_x, SHADOW_Y)
	# The forearm's shadow reaches in from the hero's side.
	draw_colored_polygon(PackedVector2Array([at + Vector2(-30, 40), at + Vector2(10, 46), Vector2(SCREEN.position.x, SCREEN.end.y - 20.0), Vector2(SCREEN.position.x, SCREEN.end.y - 90.0)]), Color(INKSHADE, 0.8))
	var grow := 1.0 if reduced_motion else 1.0 + 0.12 * maxf(0.0, 1.0 - changed / 0.15)
	if phase == "bark":
		# The hands turn into a dog that faces the hero and barks.
		var open := not reduced_motion and fmod(since, 0.3) < 0.15
		var lunge := 0.0 if reduced_motion else sin(minf(since, 0.4) / 0.4 * PI) * -30.0
		_shadow("dog_open" if open else "dog", at + Vector2(lunge, 0), -1, 0.9, 1.1)
		if since > 0.2:
			label(at + Vector2(-140, -120), "汪汪！", 34, Color("#5a2a2a"), 0.9 + 0.1 * pulse(5.0), 1.0, false)
		return
	_shadow(shape, at, turn, 0.86, grow)
	if shape == "fist":
		label(at + Vector2(0, -116), "擺個手影！", 18, Color("#5a3a3a"), 1.0, 0.75, false)


# --- Hero ------------------------------------------------------------------------

func _draw_hero(phase: String, since: float) -> void:
	var mood := "plain"
	if phase == "bark":
		mood = "shocked" if since < 0.9 else "sorry"
	elif int(state.get("streak", 0)) >= 2:
		mood = "tongue"
	var feet := HERO_FEET
	if phase == "bark" and not reduced_motion:
		feet.x -= minf(since, 0.3) / 0.3 * 16.0
	ground_shadow(feet + Vector2(0, 4), Vector2(54, 10), 0.45)
	draw_set_transform(feet, 0.0, Vector2.ONE * TEXEL)
	stamp(Hero.texture(&"right" if phase != "bark" else &"up", true, mood), -Hero.FEET, 1.0, LAMP)
	draw_set_transform(Vector2.ZERO)
	var streak := int(state.get("streak", 0))
	if streak >= 2 and phase != "bark":
		label(feet + Vector2(20, -210), "連續 ×%d" % streak, 22, GOLD)


func _ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for step in 32:
		points.append(center + Vector2.from_angle(step * TAU / 32.0) * radii)
	draw_colored_polygon(points, color)


# --- Shadow shapes ----------------------------------------------------------------

## A hand shadow as a flat dark shape with a soft rim, facing right. Holes (eyes,
## the gap of an open mouth) let the light through.
static func _shadow_image(kind: String) -> Image:
	var image := Image.create_empty(SHAPE_TEXELS.x, SHAPE_TEXELS.y, false, Image.FORMAT_RGBA8)
	for y in SHAPE_TEXELS.y:
		for x in SHAPE_TEXELS.x:
			var inside := _inside(kind, float(x) + 0.5, float(y) + 0.5)
			if inside:
				var rim := not (_inside(kind, x - 0.5, y + 0.5) and _inside(kind, x + 1.5, y + 0.5) and _inside(kind, x + 0.5, y - 0.5) and _inside(kind, x + 0.5, y + 1.5))
				image.set_pixel(x, y, Color(INKSHADE, 0.72 if rim else 1.0))
	return image


static func _in_ellipse(x: float, y: float, cx: float, cy: float, rx: float, ry: float) -> bool:
	return pow((x - cx) / rx, 2) + pow((y - cy) / ry, 2) <= 1.0


static func _inside(kind: String, x: float, y: float) -> bool:
	match kind:
		"rabbit":
			if _in_ellipse(x, y, 21, 19, 1.3, 1.3):
				return false
			return _in_ellipse(x, y, 15, 9, 2.8, 8.5) or _in_ellipse(x, y, 22, 8, 2.8, 8.0) or _in_ellipse(x, y, 19, 21, 9, 7) \
				or _in_ellipse(x, y, 27, 23, 4, 3) or (y > 25 and absf(x - 15.0) < 6.0 - (y - 25) * 0.2)
		"bird":
			return _in_ellipse(x, y, 20, 20, 6, 4) or _in_ellipse(x, y, 10, 14, 9, 3.5) or _in_ellipse(x, y, 30, 14, 9, 3.5) \
				or (absf(x - 6.0) < 1.5 and y > 9 and y < 15) or (absf(x - 34.0) < 1.5 and y > 9 and y < 15) \
				or _in_ellipse(x, y, 25, 16, 3, 3) or (x > 27 and x < 32 and absf(y - 16.0) < (32.0 - x) * 0.35) \
				or _in_ellipse(x, y, 13, 22, 4, 2) or (y > 23 and absf(x - 20.0) < 3.5)
		"dog", "dog_open":
			if _in_ellipse(x, y, 20, 11, 1.3, 1.3):
				return false
			var open := kind == "dog_open"
			if x > 21 and y > 16 and y < (22.5 if open else 17.5):
				return false
			return _in_ellipse(x, y, 17, 15, 8, 7.5) or (x > 20 and x < 34 and y > 10 and y < 16.5) or _in_ellipse(x, y, 34, 12.5, 2.2, 3.5) \
				or (x > 20 and x < 31 and y > (22.0 if open else 17.0) and y < (26.0 if open else 21.0)) or _in_ellipse(x, y, 11, 6, 3.5, 7.5) \
				or (open and x > 26 and x < 30 and y > 22 and y < 24) \
				or (y > 19 and absf(x - 14.0) < 6.0 - (y - 19) * 0.12)
		"goose":
			if _in_ellipse(x, y, 25, 6, 1.0, 1.0):
				return false
			var along := clampf((33.0 - y) / 26.0, 0.0, 1.0)
			var neck_x := 10.0 + along * 13.0 - sin(along * PI) * 3.0
			return (y > 7 and absf(x - neck_x) < 3.2) or _in_ellipse(x, y, 24, 7, 4, 3) or (x > 26 and x < 34 and absf(y - 7.5) < (34.0 - x) * 0.25 + 0.6) \
				or _in_ellipse(x, y, 11, 30, 6, 4)
		_:
			return _in_ellipse(x, y, 19, 18, 8, 7) or _in_ellipse(x, y, 25, 14, 3, 3) or (y > 20 and absf(x - 16.0) < 6.0)
	return false
