extends "res://game/minigames/arcade/arcade_view.gd"
## Picture for 音盒補拍: an inlaid walnut music box on the workshop bench with
## its front window open on the mechanism. A pinned brass cylinder turns toward
## the viewer and its pins roll down onto a steel comb whose teeth flick as they
## play; an empty socket rolls down as a hollow ring. Beside the window sits a
## jack-in-the-box compartment whose little lid rattles as pressure builds; when
## it bursts, a clown on a spring shoots out and boxes the island traveller
## (arcade_hero) on the nose. Baked pixel art in the backdrop's dusk palette.

const Hero = preload("res://game/minigames/arcade/arcade_hero.gd")
const YARD_ART := "res://assets/world/toy-clockwork-yard.webp"
const BENCH_TOP := 470.0
const BOX := Rect2(236, 214, 704, 404)
const WINDOW := Rect2(276, 244, 500, 322)
const CYLINDER := Rect2(300, 262, 452, 190)
## The comb touches the cylinder this far round (radians below the middle).
const COMB_ANGLE := 0.9
const TOP_ANGLE := -1.15
const COMPARTMENT := Rect2(800, 300, 116, 150)
const CLOWN := Vector2i(14, 14)
const GLOVE := Vector2i(11, 9)
const HERO_FEET := Vector2(1130, 664)
const HERO_SCALE := 3.0
const WALNUT := Color("#6e4630")
const PINE := Color("#d2a46a")
const BRASS := Color("#c9953e")
const STEEL := Color("#c3c8cf")
const IRON := Color("#4a4e57")
const RED := Color("#c0503f")
const DARK := Color("#2b2440")
const LABEL := Color("#efe0bc")
const DUSK := Color(1.0, 0.93, 0.86)

var _has_art := false
var _cylinder: ImageTexture
var _clown: ImageTexture
var _glove: ImageTexture


func _init() -> void:
	super()
	word_anchor = Vector2(150, 330)


func _ready() -> void:
	_has_art = use_backdrop_art(YARD_ART, Rect2(200, 0, 1157, 651), Color(0.56, 0.5, 0.56))
	var size := Vector2i(int(CYLINDER.size.x / TEXEL), int(CYLINDER.size.y / TEXEL))
	_cylinder = Pixels.bake("musicbox-cylinder", size, _paint_cylinder.bind(size))
	_clown = Pixels.bake("musicbox-clown", CLOWN, _paint_clown)
	_glove = Pixels.bake("musicbox-glove", GLOVE, func(x: int, y: int) -> Color:
		var at := (Vector2(x + 0.5, y + 0.5) - Vector2(6.0, 4.5)) / Vector2(5.0, 4.4)
		var thumb := (Vector2(x + 0.5, y + 0.5) - Vector2(2.0, 2.5)).length() < 1.8
		if at.length() > 1.0 and not thumb:
			return Pixels.CLEAR
		return Pixels.rounded(RED, at) if not thumb else RED.lightened(0.15))


func _draw_backdrop() -> void:
	if not _has_art:
		draw_rect(Rect2(Vector2.ZERO, DESIGN), Color("#3a2c2a"))
	bench(BENCH_TOP, WALNUT.lightened(0.05))
	vignette()


func _draw_scene() -> void:
	if not state.has("pins"):
		return
	_draw_box()
	_draw_cylinder()
	_draw_comb()
	_draw_compartment()
	_draw_crank()
	_draw_hero()
	_draw_clown()
	_draw_combo()


# --- Box ----------------------------------------------------------------------

func _draw_box() -> void:
	ground_shadow(Vector2(BOX.get_center().x + 16.0, BOX.end.y + 4.0), Vector2(BOX.size.x * 0.55, 18), 0.45)
	draw_rect(Rect2(BOX.position + Vector2(12, 14), BOX.size), Color(SPRITE_SHADE, 0.3))
	panel(BOX, "planks", WALNUT, Color(0, 0, 0, 0), TEXEL, DUSK)
	# A lighter inlaid band and a gilt-framed window onto the mechanism.
	panel(Rect2(BOX.position.x + 10.0, BOX.end.y - 40.0, BOX.size.x - 20.0, 24), "planks", PINE.darkened(0.05), Color(0, 0, 0, 0), TEXEL, DUSK)
	panel(WINDOW, "velvet", Color("#3a2433"), Color(0, 0, 0, 0), TEXEL, DUSK)
	gilt_frame(WINDOW.grow(10.0), 12.0, GILT, TEXEL, DUSK)
	label(Vector2(WINDOW.get_center().x, BOX.end.y - 28.0), "♪ 發條音樂盒 ♪", 18, DARK, 1.0, 1.0, false)
	# Brass feet.
	for foot: float in [BOX.position.x + 30.0, BOX.end.x - 30.0]:
		draw_rect(Rect2(foot - 22.0, BOX.end.y - 2.0, 44, 12), BRASS.darkened(0.4))
		draw_rect(Rect2(foot - 20.0, BOX.end.y - 2.0, 40, 8), BRASS)


# --- Cylinder and pins ---------------------------------------------------------

func _column_x(column: int) -> float:
	var teeth := int(state.get("teeth", 8))
	return CYLINDER.position.x + (column + 0.5) * CYLINDER.size.x / teeth


func _angle_y(angle: float) -> float:
	return CYLINDER.get_center().y + sin(angle) * CYLINDER.size.y * 0.5


func _draw_cylinder() -> void:
	# The barrel, with a bright band sliding round to show it turning.
	stamp(_cylinder, CYLINDER.position, TEXEL, DUSK)
	var turned := float(state.get("turned", 0.0))
	if not reduced_motion:
		for band in 3:
			var angle := TOP_ANGLE + fposmod(turned * 0.6 + band / 3.0, 1.0) * (COMB_ANGLE + 0.5 - TOP_ANGLE)
			if angle > 1.4:
				continue
			draw_rect(Rect2(CYLINDER.position.x, _angle_y(angle) - 1.0, CYLINDER.size.x, 2), Color(BRASS.darkened(0.35), 0.5 * cos(angle)))
	var comb_y := _angle_y(COMB_ANGLE)
	draw_rect(Rect2(CYLINDER.position.x - 6.0, comb_y - 2.0, CYLINDER.size.x + 12.0, 4), Color(GOLD, 0.35))
	var lead := float(state.get("lead", 1.4))
	for pin: Dictionary in state.pins:
		var left := float(pin.t) - now
		var angle := COMB_ANGLE - left / lead * (COMB_ANGLE - TOP_ANGLE)
		if angle < TOP_ANGLE - 0.05 or angle > 1.45:
			continue
		var at := Vector2(_column_x(int(pin.column)), _angle_y(angle))
		var size := 11.0 + 10.0 * cos(angle)
		match str(pin.state):
			"coming":
				if bool(pin.gap):
					_draw_socket(at, size, left)
				else:
					_draw_pin(at, size)
			"played":
				_draw_pin(at, size)
			"plucked":
				_draw_pin(at, size, true)
				var since := age(float(pin.at))
				if since < 0.35:
					glint(at, 22.0, 99.0, -since)
			"missed":
				_draw_socket(at, size, -1.0)


## A raised steel pin (gold when the player just put it back), with its shadow on the barrel.
func _draw_pin(at: Vector2, size: float, fresh := false) -> void:
	var tone := GOLD if fresh else STEEL
	draw_circle(at + Vector2(3, 4), size * 0.5, Color(SPRITE_SHADE, 0.4))
	draw_circle(at, size * 0.5, tone.darkened(0.5))
	draw_circle(at, size * 0.5 - 2.0, tone.darkened(0.1))
	draw_circle(at + Vector2(-size * 0.12, -size * 0.12), size * 0.28, tone.lightened(0.25))
	draw_circle(at + Vector2(-size * 0.18, -size * 0.18), size * 0.1, Color(1, 1, 1, 0.8))


## An empty socket: a dark hole with a ring that brightens as it nears the comb.
func _draw_socket(at: Vector2, size: float, left: float) -> void:
	var near := clampf(1.0 - absf(left) / 0.4, 0.0, 1.0) if left >= -0.2 else 0.0
	draw_circle(at, size * 0.5 + 3.0, BRASS.darkened(0.55))
	draw_circle(at, size * 0.5, Color("#1d1420"))
	draw_arc(at, size * 0.5 + 5.0, 0.0, TAU, 16, Color(GOLD, 0.5 + 0.5 * near), 2.0 + 3.0 * near)
	if left < 0.0 and left > -0.9:
		label(at + Vector2(0, -size - 10.0), "✕", 16, ROSE)


# --- Comb ---------------------------------------------------------------------

func _draw_comb() -> void:
	var teeth := int(state.get("teeth", 8))
	var plucked: Array = state.get("plucked_at", [])
	var root := _angle_y(COMB_ANGLE) - 4.0
	# A brass bar the teeth are screwed to, below the cylinder.
	var bar := Rect2(CYLINDER.position.x - 10.0, root + 74.0, CYLINDER.size.x + 20.0, 26)
	panel(bar, "enamel", BRASS.darkened(0.1), BRASS.darkened(0.4), TEXEL, DUSK)
	for tooth in teeth:
		var x := _column_x(tooth)
		var since := age(float(plucked[tooth])) if tooth < plucked.size() else 99.0
		var flick := 0.0 if reduced_motion or since > 0.4 else 6.0 * exp(-since * 9.0) * cos(since * 60.0)
		var tip := Vector2(x, root + flick)
		var base := Vector2(x, root + 74.0)
		var width := 18.0
		draw_colored_polygon(PackedVector2Array([tip + Vector2(-width * 0.3, 0), tip + Vector2(width * 0.3, 0), base + Vector2(width * 0.5, 0), base + Vector2(-width * 0.5, 0)]), STEEL.darkened(0.45))
		draw_colored_polygon(PackedVector2Array([tip + Vector2(-width * 0.3 + 2, 2), tip + Vector2(width * 0.3 - 2, 2), base + Vector2(width * 0.5 - 2, 0), base + Vector2(-width * 0.5 + 2, 0)]), STEEL.lightened(0.05) if since > 0.15 else GOLD.lightened(0.2))
		draw_line(tip + Vector2(-width * 0.3 + 3, 3), base + Vector2(-width * 0.5 + 4, -2), Color(1, 1, 1, 0.45), 2.0)
		if since < 0.6 and not reduced_motion:
			label(tip + Vector2(10, -24 - since * 50.0), "♪", 20, GOLD, 1.0, 1.0 - since / 0.6)
		elif since < 0.3:
			label(tip + Vector2(10, -28), "♪", 20, GOLD)


# --- Jack-in-the-box ----------------------------------------------------------

func _popped() -> float:
	var since := age(float(state.get("popped_at", -99.0)))
	return since if since >= 0.0 and since < float(state.get("pop_seconds", 1.8)) else -1.0


func _draw_compartment() -> void:
	var box := COMPARTMENT
	draw_rect(Rect2(box.position + Vector2(8, 10), box.size), Color(SPRITE_SHADE, 0.3))
	panel(box, "lacquer", Color("#4f79a8"), GOLD, TEXEL, DUSK)
	# Stars painted on the front and the pressure springs as little coils.
	label(box.get_center() + Vector2(0, -20), "★", 30, GOLD)
	var pressure := float(state.get("pressure", 0.0))
	var limit := float(state.get("pressure_limit", 4.0))
	for coil in int(limit):
		var at := Vector2(box.position.x + 22.0 + coil * 24.0, box.end.y - 30.0)
		var lit := coil < int(pressure)
		draw_rect(Rect2(at - Vector2(9, 9), Vector2(18, 18)), DARK)
		draw_rect(Rect2(at - Vector2(7, 7), Vector2(14, 14)), ROSE if lit else Color("#3a2433"))
		if lit:
			draw_rect(Rect2(at - Vector2(7, 7), Vector2(6, 4)), ROSE.lightened(0.4))
	# The little lid rattles harder as pressure builds, and flies open when it pops.
	var popped := _popped()
	var lid_angle := 0.0
	if popped >= 0.0:
		lid_angle = -1.9 * pop_in(popped, 0.15)
	elif not reduced_motion:
		lid_angle = -0.08 * (pressure / limit) * absf(sin(now * 22.0))
	var hinge := Vector2(box.end.x, box.position.y)
	draw_set_transform(hinge, lid_angle, Vector2.ONE)
	panel(Rect2(-box.size.x - 6.0, -18, box.size.x + 12.0, 20), "lacquer", Color("#c0503f"), GOLD, TEXEL, DUSK)
	draw_set_transform(Vector2.ZERO)


func _draw_clown() -> void:
	var popped := _popped()
	if popped < 0.0:
		return
	var total := float(state.get("pop_seconds", 1.8))
	var out := pop_in(popped, 0.22) if popped < total - 0.4 else 1.0 - smoothstep(total - 0.4, total, popped)
	var start := Vector2(COMPARTMENT.get_center().x, COMPARTMENT.position.y)
	var face := HERO_FEET + Vector2(-6, -36 * HERO_SCALE)
	var reach := start.lerp(face, clampf(out, 0.0, 1.05))
	# A zigzag spring out of the box to the clown, glove first.
	var spring := PackedVector2Array()
	for coil in 13:
		var t := coil / 12.0
		var side := Vector2(0, 10.0 if coil % 2 == 0 else -10.0) if coil > 0 and coil < 12 else Vector2.ZERO
		spring.append(start.lerp(reach, t) + side)
	draw_polyline(spring, DARK, 6.0)
	draw_polyline(spring, STEEL, 3.0)
	stamp(_clown, reach - Vector2(CLOWN.x * 2.0 + 30.0, CLOWN.y * 2.0 + 20.0), TEXEL, DUSK)
	stamp(_glove, reach - Vector2(GLOVE.x * 2.0, GLOVE.y * 2.0), TEXEL, DUSK)
	if out > 0.95 and popped < 1.0:
		dust_puffs(face, popped - 0.2, 50.0)


func _draw_crank() -> void:
	# A brass winding key turning on the side of the box.
	var hub := Vector2(BOX.position.x - 10.0, BOX.get_center().y)
	var turn := 0.0 if reduced_motion else float(state.get("turned", 0.0)) * 1.5
	draw_circle(hub, 12.0, BRASS.darkened(0.4))
	draw_circle(hub, 9.0, BRASS)
	for wing: float in [0.0, PI]:
		var tip := hub + Vector2.from_angle(turn + wing) * 30.0
		draw_line(hub, tip, BRASS.darkened(0.4), 10.0)
		draw_circle(tip, 11.0, BRASS.darkened(0.4))
		draw_circle(tip, 9.0, BRASS.lightened(0.1))


func _draw_hero() -> void:
	var popped := _popped()
	var hit := popped >= 0.15 and popped < 1.6
	var pressed := age(float(state.get("press_at", -99.0))) < 0.15
	var pose := &"up" if pressed and not hit else &"idle"
	var mood := "shocked" if hit else ("tongue" if int(state.get("combo", 0)) >= 12 else "plain")
	var knock := squash(popped - 0.15, 0.3, 0.35) if hit else Vector2.ONE
	ground_shadow(HERO_FEET + Vector2(6, 2), Vector2(56, 13), 0.42)
	draw_set_transform(HERO_FEET + (Vector2(16, 0) if hit and not reduced_motion else Vector2.ZERO), 0.0, knock)
	stamp(Hero.texture(pose, true, mood), -Vector2(20, 46) * HERO_SCALE, HERO_SCALE, DUSK)
	draw_set_transform(Vector2.ZERO)
	if hit:
		for star in 3:
			var angle := star * TAU / 3.0 + (0.0 if reduced_motion else popped * 7.0)
			var spot := HERO_FEET + Vector2(cos(angle) * 40.0, -150.0 + sin(angle) * 10.0)
			draw_rect(Rect2(spot - Vector2(7, 3), Vector2(14, 6)), DARK)
			draw_rect(Rect2(spot - Vector2(3, 7), Vector2(6, 14)), DARK)
			draw_rect(Rect2(spot - Vector2(5, 1), Vector2(10, 2)), GOLD)
			draw_rect(Rect2(spot - Vector2(1, 5), Vector2(2, 10)), GOLD)


func _draw_combo() -> void:
	var combo := int(state.get("combo", 0))
	if combo >= 4:
		label(Vector2(1110, 250), "連拍 × %d" % combo, 26, GOLD, 1.0 + 0.08 * pulse(2.0))


# --- Texel painters -------------------------------------------------------------

func _paint_cylinder(x: int, y: int, size: Vector2i) -> Color:
	# A turned brass barrel: dark where it curves away top and bottom, a bright
	# band where it faces the lamp, raised end rings and a groove down each
	# pin track.
	var round := (y + 0.5 - size.y * 0.5) / (size.y * 0.5)
	var light := 1.1 - 2.4 * round * round - 0.5 * round
	if x < 4 or x >= size.x - 4:
		var ring := 0.6 if x == 1 or x == size.x - 2 else -0.4
		return Pixels.lit(BRASS.darkened(0.2), light + ring, x, y)
	var track := posmod(x - 4, (size.x - 8) / 8)
	if track == (size.x - 8) / 16:
		light -= 0.7
	var tone := Pixels.lit(BRASS, light, x, y)
	return Pixels.grainy(tone, x, y, 0.04, 4)


func _paint_clown(x: int, y: int) -> Color:
	var at := Vector2(x + 0.5, y + 0.5)
	# Tufts of red and teal hair, a white face, a round red nose and a grin.
	var face := (at - Vector2(7.0, 8.0)) / Vector2(5.0, 5.2)
	if face.length() > 1.0:
		if y < 6 and (at - Vector2(3.0, 4.5)).length() < 3.0:
			return Pixels.rounded(Color("#4f8f86"), (at - Vector2(3.0, 4.5)) / 3.0)
		if y < 6 and (at - Vector2(11.0, 4.5)).length() < 3.0:
			return Pixels.rounded(RED, (at - Vector2(11.0, 4.5)) / 3.0)
		return Pixels.CLEAR
	if (at - Vector2(7.0, 8.5)).length() < 1.6:
		return Pixels.rounded(RED.lightened(0.1), (at - Vector2(7.0, 8.5)) / 1.6)
	if y == 6 and (x == 4 or x == 9):
		return DARK
	if y == 11 and x >= 4 and x <= 9:
		return RED.darkened(0.2)
	return Pixels.rounded(Color("#f7f1e3"), face)
