extends "res://game/minigames/arcade/arcade_view.gd"
## Picture for 折鏡迷箱: in the tent's ring a spotlight in the roof pours a
## column of light onto the gilt hand mirror the hero holds overhead; the
## reflected beam sweeps out across the ring, stopped by striped pillars, to the
## twinkling balloons floating along both sides. A gold balloon shows a ring that
## fills while it is lit. Tilt too far and the beam turns back onto the hero's
## face, which ends up tanned in the shape of sunglasses. Every object is baked
## pixel art (arcade_pixels.gd, arcade_hero.gd) or a shared material.

const Hero = preload("res://game/minigames/arcade/arcade_hero.gd")
const TENT_ART := "res://assets/world/circus-tent.webp"
const FLOOR_TOP := 560.0
const FEET := Vector2(640, 662)
const LAMP_AT := Vector2(640, 196)
const LAMP := Color(0.94, 0.89, 0.96)
const WARM := Color("#ffe6a8")
const WOOD := Color("#6b4658")
const WOOD_DARK := Color("#3b2536")
const BRASS := Color("#b0803a")
const PILLAR := Color("#b84a4a")
const TONES: Array[Color] = [Color("#d8463e"), Color("#2f9aa0"), Color("#8a4fb0"), Color("#e07a9a")]
const GOLD_BALLOON := Color("#e8b440")
const TAN := Color("#6a3f2a")

var _has_tent := false
var _balloons: Array[ImageTexture] = []
var _gold: ImageTexture
var _mirror: ImageTexture
var _lamp: ImageTexture


func _init() -> void:
	super()
	word_anchor = Vector2(640, 250)


func _ready() -> void:
	_has_tent = use_backdrop_art(TENT_ART, Rect2(85, 0, 1366, 768), Color(0.66, 0.6, 0.74))
	for tone in TONES:
		_balloons.append(Pixels.bake("mirror-balloon|" + tone.to_html(), Vector2i(15, 18), func(x: int, y: int) -> Color: return _paint_balloon(tone, x, y)))
	_gold = Pixels.bake("mirror-balloon|gold", Vector2i(15, 18), func(x: int, y: int) -> Color: return _paint_balloon(GOLD_BALLOON, x, y))
	_mirror = Pixels.bake("mirror-hand", Vector2i(16, 24), _paint_mirror)
	_lamp = Pixels.bake("mirror-lamp", Vector2i(16, 12), _paint_lamp)


func _draw_backdrop() -> void:
	if not _has_tent:
		draw_rect(Rect2(Vector2.ZERO, DESIGN), Color("#2b1f3a"))
	stage_floor(FLOOR_TOP, WOOD, WOOD_DARK)
	vignette(0.55)


func _draw_scene() -> void:
	var phase := str(state.get("phase", "aim"))
	var since := age(float(state.get("phase_at", 0.0)))
	_draw_pillars()
	_draw_balloons()
	_draw_lamp()
	_draw_hero(phase, since)
	_draw_mirror()
	_draw_beam(phase)


# --- Rig --------------------------------------------------------------------------

func _draw_lamp() -> void:
	panel(Rect2(LAMP_AT.x - 180.0, LAMP_AT.y - 30.0, 360, 12), "pole", BRASS.darkened(0.2), Pixels.CLEAR, 2.0, LAMP)
	draw_line(LAMP_AT + Vector2(0, -20), LAMP_AT, INK, 4.0)
	stamp(_lamp, LAMP_AT - Vector2(8, 2) * TEXEL, TEXEL, LAMP)


func _draw_pillars() -> void:
	for pillar: Rect2 in state.get("pillars", []):
		var body := Rect2(pillar.position.x, pillar.position.y, pillar.size.x, FLOOR_TOP + 34.0 - pillar.position.y)
		ground_shadow(Vector2(body.get_center().x + 6.0, body.end.y), Vector2(40, 8), 0.5)
		draw_rect(Rect2(body.position + Vector2(8, 10), body.size), Color(0.06, 0.02, 0.08, 0.3))
		panel(body, "pole", PILLAR, Pixels.CLEAR, 3.0, LAMP)
		# Gilt capital and base.
		panel(Rect2(body.position.x - 8.0, body.position.y - 14.0, body.size.x + 16.0, 18), "lacquer", GILT.darkened(0.15), GILT, 2.0, LAMP)
		panel(Rect2(body.position.x - 8.0, body.end.y - 16.0, body.size.x + 16.0, 18), "lacquer", GILT.darkened(0.15), GILT, 2.0, LAMP)


# --- Balloons ---------------------------------------------------------------------

func _draw_balloons() -> void:
	var gold_seconds := float(state.get("gold_seconds", 2.0))
	for balloon: Dictionary in state.get("balloons", []):
		var at: Vector2 = balloon.at
		var popped := float(balloon.popped_at)
		if popped >= 0.0:
			_draw_pop(at, age(popped), bool(balloon.gold))
			continue
		var bob := 0.0 if reduced_motion else sin(now * 2.2 + float(balloon.id)) * 4.0
		at.y += bob
		# A wavy string hangs down.
		var string := PackedVector2Array()
		for step in 7:
			var sway := 0.0 if reduced_motion else sin(now * 3.0 + step * 0.8 + float(balloon.id)) * 3.0
			string.append(at + Vector2(sway, 34.0 + step * 9.0))
		draw_polyline(string, Color("#e8dcc0"), 2.0)
		var sprite: Texture2D = _gold if bool(balloon.gold) else _balloons[int(balloon.tone) % _balloons.size()]
		var lit := float(balloon.lit) > 0.0
		var stretch := Vector2(1.0, 1.0) if not lit or reduced_motion else Vector2(1.06, 0.95)
		draw_set_transform(at, 0.0, stretch * TEXEL)
		stamp(sprite, -Vector2(sprite.get_size()) * 0.5, 1.0, LAMP.lerp(WARM, 0.5) if lit else LAMP)
		draw_set_transform(Vector2.ZERO)
		# Each balloon twinkles now and then.
		if not reduced_motion and fmod(now * 0.7 + float(balloon.id) * 0.37, 1.0) < 0.12:
			_star(at + Vector2(-14, -20), 6.0)
		if bool(balloon.gold):
			var fill := clampf(float(balloon.lit) / gold_seconds, 0.0, 1.0)
			draw_arc(at, 40.0, 0, TAU, 32, Color(INK, 0.6), 7.0)
			if fill > 0.0:
				draw_arc(at, 40.0, -PI * 0.5, -PI * 0.5 + TAU * fill, 32, GOLD, 5.0)
			label(at + Vector2(0, -56), "照 2 秒", 18, GOLD)


func _draw_pop(at: Vector2, since: float, gold: bool) -> void:
	if since > 0.6:
		return
	var tone := GOLD_BALLOON if gold else ROSE
	for shred in 7:
		var heading := Vector2.from_angle(shred * TAU / 7.0 + 0.3)
		var spread := (1.0 if reduced_motion else since / 0.6) * 60.0
		var piece := at + heading * spread + Vector2(0, 80.0 * since * since)
		draw_rect(Rect2(piece - Vector2(5, 4), Vector2(10, 8)), tone.darkened(0.4))
		draw_rect(Rect2(piece - Vector2(4, 3), Vector2(8, 6)), tone)
	if since < 0.35:
		label(at, "啪！", 30, GOLD if gold else CREAM, pop_in(since, 0.15))


func _star(at: Vector2, size: float) -> void:
	draw_rect(Rect2(at - Vector2(size, 1), Vector2(size * 2.0, 2)), Color(1, 1, 0.9, 0.9))
	draw_rect(Rect2(at - Vector2(1, size), Vector2(2, size * 2.0)), Color(1, 1, 0.9, 0.9))


# --- Mirror and beams ------------------------------------------------------------

func _mirror_at() -> Vector2:
	return state.get("mirror", Vector2(640, 430))


func _draw_mirror() -> void:
	var tilt := float(state.get("tilt", 0.0))
	draw_set_transform(_mirror_at(), tilt, Vector2.ONE * TEXEL)
	stamp(_mirror, Vector2(-9, -10), 1.0, LAMP)
	draw_set_transform(Vector2.ZERO)
	if not reduced_motion:
		glint(_mirror_at() + Vector2(-8, -10).rotated(tilt), 14.0, 2.6)


func _draw_beam(phase: String) -> void:
	var mirror := _mirror_at()
	# The column of light from the roof lamp onto the mirror.
	draw_colored_polygon(PackedVector2Array([LAMP_AT + Vector2(-18, 30), LAMP_AT + Vector2(18, 30), mirror + Vector2(28, -6), mirror + Vector2(-28, -6)]), Color(WARM, 0.16))
	draw_colored_polygon(PackedVector2Array([LAMP_AT + Vector2(-6, 30), LAMP_AT + Vector2(6, 30), mirror + Vector2(10, -6), mirror + Vector2(-10, -6)]), Color(WARM, 0.2))
	if phase == "tanned":
		return
	var end: Vector2 = state.get("beam_end", mirror)
	if bool(state.get("face_lit", false)):
		# Tilted too far: the light comes back down onto the hero's face.
		end = FEET + Vector2(0, -140)
	var across := (end - mirror).normalized().orthogonal()
	draw_colored_polygon(PackedVector2Array([mirror + across * 12.0, mirror - across * 12.0, end - across * 20.0, end + across * 20.0]), Color(WARM, 0.22))
	draw_colored_polygon(PackedVector2Array([mirror + across * 4.0, mirror - across * 4.0, end - across * 7.0, end + across * 7.0]), Color(1, 0.98, 0.88, 0.55))
	draw_circle(end, 14.0 + pulse(5.0) * 4.0, Color(WARM, 0.45))
	draw_circle(end, 6.0, Color(1, 1, 0.92, 0.8))


# --- Hero -------------------------------------------------------------------------

func _draw_hero(phase: String, since: float) -> void:
	var face_lit := bool(state.get("face_lit", false))
	var tanned := int(state.get("tans", 0)) > 0
	var mood := "plain"
	if phase == "tanned":
		mood = "sorry"
	elif face_lit:
		mood = "shocked"
	elif int(state.get("turn", 0)) != 0:
		mood = "tongue"
	var feet := FEET
	if phase == "tanned" and not reduced_motion:
		feet.x += sin(since * 30.0) * 3.0 * maxf(0.0, 1.0 - since)
	ground_shadow(feet + Vector2(0, 4), Vector2(54, 10), 0.45)
	var tint := LAMP.lerp(Color("#ffd0a0"), 0.35) if face_lit else LAMP
	draw_set_transform(feet, 0.0, Vector2.ONE * TEXEL)
	stamp(Hero.texture(&"up", true, mood), -Hero.FEET, 1.0, tint)
	draw_set_transform(Vector2.ZERO)
	if face_lit:
		var heat := float(state.get("on_face", 0.0))
		draw_circle(feet + Vector2(-2, -140), 30.0 + heat * 16.0, Color(1, 0.9, 0.6, 0.25 + heat * 0.3))
		label(feet + Vector2(110, -150), "好亮！", 24, ROSE, 0.9 + 0.1 * pulse(6.0))
	if tanned:
		_draw_tan(feet, 1.0 if phase == "tanned" else 0.75)
	if phase == "tanned":
		if not reduced_motion:
			for puff in 3:
				var rise := fmod(since * 1.2 + puff * 0.33, 1.0)
				draw_circle(feet + Vector2(-30.0 + puff * 30.0, -190.0 - rise * 50.0), 8.0 + rise * 8.0, Color(1, 1, 1, 0.5 * (1.0 - rise)))
		label(feet + Vector2(190, -120), "曬出墨鏡了…", 26, CREAM)


## A tan in the shape of sunglasses: two dark lenses and a bridge around the eyes.
func _draw_tan(feet: Vector2, strength: float) -> void:
	var tone := Color(TAN, 0.9 * strength)
	var rim := Color(TAN.darkened(0.4), 0.9 * strength)
	for lens: float in [-24.0, 4.0]:
		var box := Rect2(feet + Vector2(lens, -144), Vector2(20, 16))
		draw_rect(box.grow(2.0), rim)
		draw_rect(box, tone)
	draw_rect(Rect2(feet + Vector2(-4, -140), Vector2(8, 4)), rim)
	# The eyes blink pale inside the tan.
	for eye: float in [-16.0, 12.0]:
		draw_rect(Rect2(feet + Vector2(eye - 3.0, -138), Vector2(6, 6)), Color(1, 0.97, 0.9, strength))
		draw_rect(Rect2(feet + Vector2(eye - 1.0, -136), Vector2(3, 3)), Color(INK, strength))


# --- Painted props ----------------------------------------------------------------

func _paint_balloon(tone: Color, x: int, y: int) -> Color:
	var centre := Vector2(7.0, 7.5)
	if y >= 15:
		# The tied knot.
		return Pixels.lit(tone.darkened(0.2), 0.0, x, y) if absf(x - 7.0) <= (17 - y) * 0.7 else Pixels.CLEAR
	var offset := (Vector2(x, y) + Vector2(0.5, 0.5) - centre) / Vector2(7.2, 7.8)
	if offset.length() > 1.0:
		return Pixels.CLEAR
	if Vector2(x - 4.0, y - 4.0).length() < 1.6:
		return tone.lightened(0.6)
	return Pixels.rounded(tone, offset)


## A gilt hand mirror: oval glass in a chased frame on a short handle.
func _paint_mirror(x: int, y: int) -> Color:
	var centre := Vector2(7.5, 8.5)
	if y >= 16:
		return Pixels.metal(GILT, x, y) if absf(x - 7.5) <= 1.5 + (1 if y > 21 else 0) else Pixels.CLEAR
	var offset := (Vector2(x, y) + Vector2(0.5, 0.5) - centre) / Vector2(7.5, 8.2)
	var reach := offset.length()
	if reach > 1.0:
		return Pixels.CLEAR
	if reach > 0.78:
		return Pixels.lit(GILT, 0.6 - offset.y - offset.x * 0.4, x, y)
	var streak := float(x) + float(y) * 0.6
	var tone := Color("#bfe0f0")
	if absf(streak - 7.0) < 1.0 or absf(streak - 10.0) < 0.5:
		return tone.lightened(0.5)
	return Pixels.lit(tone, 0.4 - offset.y * 0.8, x, y)


## A brass spotlight hanging from the roof, lens pointing down.
func _paint_lamp(x: int, y: int) -> Color:
	if y >= 10:
		return Pixels.lit(WARM, 1.0, x, y) if x >= 4 and x <= 11 else Pixels.CLEAR
	if x < 2 or x > 13:
		return Pixels.CLEAR
	if y == 0 or y == 8:
		return Pixels.metal(BRASS, x, y)
	return Pixels.lit(Color("#3a3446"), 0.6 - absf(x - 5.0) / 6.0, x, y)
