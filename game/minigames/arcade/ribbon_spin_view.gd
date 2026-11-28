extends "res://game/minigames/arcade/arcade_view.gd"
## Picture for 謝幕回旋: centre stage the hero twirls a ribbon on a stick; the
## ribbon's circle widens with every steady spin. A gilt ring at their feet
## closes in on each beat and shows which arrow comes next. To the right a
## drummer pounds a bass drum: sticks held high warn of a tempo change, a drum
## roll leads to the final crash of the cymbal (or a sneaky false one). A bow
## ends the routine; losing the rhythm wraps the hero in ribbon like a mummy who
## hops off and back. Every object is baked pixel art (arcade_pixels.gd,
## arcade_hero.gd) or a shared material.

const Hero = preload("res://game/minigames/arcade/arcade_hero.gd")
const TENT_ART := "res://assets/world/circus-tent.webp"
const FLOOR_TOP := 560.0
const FEET := Vector2(560, 640)
const DRUMMER := Vector2(1010, 640)
const LAMP := Color(0.94, 0.89, 0.96)
const RIBBON := Color("#e85a7a")
const RIBBON_DARK := Color("#a83a5a")
const WOOD := Color("#6b4658")
const WOOD_DARK := Color("#3b2536")
const BRASS := Color("#c9953e")

var _has_tent := false
var _drum: ImageTexture
var _drummer: Dictionary = {}
var _cymbal: ImageTexture


func _init() -> void:
	super()
	word_anchor = Vector2(560, 250)


func _ready() -> void:
	_has_tent = use_backdrop_art(TENT_ART, Rect2(85, 0, 1366, 768), Color(0.68, 0.62, 0.76))
	_drum = Pixels.bake("ribbon-drum", Vector2i(30, 28), _paint_drum)
	_cymbal = Pixels.bake("ribbon-cymbal", Vector2i(20, 6), func(x: int, y: int) -> Color:
		var offset := Vector2((x + 0.5 - 10.0) / 10.0, (y + 0.5 - 3.0) / 3.0)
		return Pixels.metal(Color("#d9b04a"), x, y) if offset.length() <= 1.0 else Pixels.CLEAR)
	for look: String in ["down", "up", "high"]:
		_drummer[look] = Pixels.bake_blocks("ribbon-drummer|" + look, Vector2i(26, 34), Vector2i(13, 34), _drummer_blocks(look))


func _draw_backdrop() -> void:
	if not _has_tent:
		draw_rect(Rect2(Vector2.ZERO, DESIGN), Color("#2b1f3a"))
	stage_floor(FLOOR_TOP, WOOD, WOOD_DARK)
	vignette(0.5)


func _draw_scene() -> void:
	var phase := str(state.get("phase", "rest"))
	var since := age(float(state.get("phase_at", 0.0)))
	_draw_spotlight(phase)
	_draw_drummer(phase)
	if phase == "tangle":
		_draw_mummy(since)
	else:
		_draw_beat_ring(phase)
		_draw_ribbon(phase, since, true)
		_draw_hero(phase, since)
		_draw_ribbon(phase, since, false)
	_draw_cues(phase, since)


# --- Hero and ribbon ----------------------------------------------------------------

## A warm spot from the rigging onto the hero, with a pool on the boards.
func _draw_spotlight(phase: String) -> void:
	var x := FEET.x if phase != "tangle" else FEET.x - 120.0
	var top := Vector2(x + 60.0, 130.0)
	draw_colored_polygon(PackedVector2Array([top + Vector2(-20, 0), top + Vector2(20, 0), Vector2(x + 190.0, FEET.y + 10.0), Vector2(x - 190.0, FEET.y + 10.0)]), Color(1, 0.9, 0.7, 0.07))
	draw_colored_polygon(PackedVector2Array([top + Vector2(-8, 0), top + Vector2(8, 0), Vector2(x + 110.0, FEET.y + 10.0), Vector2(x - 110.0, FEET.y + 10.0)]), Color(1, 0.92, 0.75, 0.06))
	for ring in 4:
		var radii := Vector2(230.0 - ring * 40.0, 44.0 - ring * 7.0)
		var points := PackedVector2Array()
		for step in 32:
			points.append(Vector2(x, FEET.y + 6.0) + Vector2.from_angle(step * TAU / 32.0) * radii)
		draw_colored_polygon(points, Color(1, 0.9, 0.65, 0.06 + ring * 0.03))

func _spin_angle() -> float:
	var press: Dictionary = state.get("last_press", {})
	var spins := int(state.get("spins", 0))
	var since := age(float(press.get("at", -99.0)))
	return spins * PI + (0.0 if reduced_motion else minf(since / 0.25, 1.0) * PI)


func _draw_hero(phase: String, since: float) -> void:
	var press: Dictionary = state.get("last_press", {})
	var mood := "plain"
	var pose := &"idle"
	var flip := 1.0
	if phase == "bow":
		mood = "tongue"
	elif not press.is_empty() and age(float(press.at)) < 0.35:
		pose = &"up"
		mood = "tongue" if bool(press.good) else "shocked"
		flip = -1.0 if press.side == &"left" else 1.0
	var stretch := Vector2.ONE
	var feet := FEET
	if phase == "bow":
		var dip := 1.0 if reduced_motion else sin(clampf(since / 0.5, 0.0, 1.0) * PI * 0.5)
		stretch = Vector2(1.0 + 0.08 * dip, 1.0 - 0.18 * dip)
	ground_shadow(feet + Vector2(0, 4), Vector2(56, 11), 0.45)
	draw_set_transform(feet, 0.0, Vector2(flip, 1.0) * stretch * TEXEL)
	stamp(Hero.texture(pose, true, mood), -Hero.FEET, 1.0, LAMP)
	draw_set_transform(Vector2.ZERO)


## The ribbon traces a tilted circle around the hero; its back half is drawn
## behind them and its front half in front. Twists alternate light and dark.
func _draw_ribbon(phase: String, since: float, back: bool) -> void:
	var size := float(state.get("size", 0))
	var radius := 46.0 + size * 24.0
	var centre := FEET + Vector2(0, -110)
	if phase == "bow":
		# Coils drop to the floor around the feet.
		if back:
			return
		var fall := 1.0 if reduced_motion else clampf(since / 0.5, 0.0, 1.0)
		# The ribbon settles in loose coils on the floor around the feet.
		for coil in 3:
			var at := FEET + Vector2(18.0 - coil * 14.0, 10.0 - coil * 3.0) + Vector2(0, -110.0 * (1.0 - fall))
			var radii := Vector2(radius * (0.55 + coil * 0.14), radius * (0.55 + coil * 0.14) * lerpf(0.32, 0.16, fall))
			_ellipse_ring(at, radii, INK, 11.0)
			_ellipse_ring(at, radii, RIBBON if coil % 2 == 0 else RIBBON_DARK, 7.0)
		return
	var turn := _spin_angle() + (0.0 if reduced_motion else now * 2.0)
	var points := 40
	for step in points:
		var a0 := turn + step * TAU / points
		var a1 := turn + (step + 1) * TAU / points
		var behind := sin(a0) < 0.0
		if behind != back:
			continue
		var p0 := centre + Vector2(cos(a0) * radius, sin(a0) * radius * 0.32 - sin(a0 * 3.0 + now) * 6.0)
		var p1 := centre + Vector2(cos(a1) * radius, sin(a1) * radius * 0.32 - sin(a1 * 3.0 + now) * 6.0)
		var twist := step % 4 < 2
		# A wide satin band that shows its light face and dark back as it twists.
		var wide := 14.0 if twist else 9.0
		draw_line(p0, p1, INK, wide + 4.0)
		draw_line(p0, p1, RIBBON if twist else RIBBON_DARK, wide)
		if twist:
			draw_line(p0 + Vector2(0, -wide * 0.3), p1 + Vector2(0, -wide * 0.3), RIBBON.lightened(0.4), 3.0)
	if not back:
		# The stick in the hero's hand.
		var hand := FEET + Vector2(52, -96)
		draw_line(hand, centre + Vector2(radius * 0.2, -30), INK, 6.0)
		draw_line(hand, centre + Vector2(radius * 0.2, -30), Color("#c9a46a"), 3.0)


## A gilt ring at the feet closes onto each beat; the next arrow sits on it.
func _draw_beat_ring(phase: String) -> void:
	if phase != "dance":
		return
	var beat := float(state.get("beat", 0.6))
	var until := float(state.get("next_beat", 0.0)) - now
	var t := clampf(1.0 - until / beat, 0.0, 1.0)
	var at := FEET + Vector2(0, 8)
	_ellipse_ring(at, Vector2(150, 30) * lerpf(1.6, 1.0, t), Color(GOLD, 0.25 + 0.5 * t), 4.0)
	_ellipse_ring(at, Vector2(150, 30), Color(GILT, 0.9), 6.0)
	var expect: StringName = state.get("expect", &"")
	var text := "← 或 →" if expect == &"" else ("←" if expect == &"left" else "→")
	label(at + Vector2(0, 38), text, 22, CREAM)
	var press: Dictionary = state.get("last_press", {})
	if not press.is_empty() and age(float(press.at)) < 0.3 and bool(press.get("perfect", false)):
		label(FEET + Vector2(0, -260), "漂亮！", 22, GOLD, pop_in(age(float(press.at)), 0.15))


func _ellipse_ring(center: Vector2, radii: Vector2, color: Color, width: float) -> void:
	var points := PackedVector2Array()
	for step in 41:
		points.append(center + Vector2.from_angle(step * TAU / 40.0) * radii)
	draw_polyline(points, color, width)


## Wrapped in ribbon like a mummy, the hero hops off stage and back.
func _draw_mummy(since: float) -> void:
	var out := since / 2.4
	var x := FEET.x - 300.0 * sin(clampf(out, 0.0, 1.0) * PI)
	var hop := 0.0 if reduced_motion else absf(sin(since * 9.0)) * 26.0
	var feet := Vector2(x, FEET.y - hop)
	if reduced_motion:
		feet = Vector2(FEET.x - 160.0, FEET.y)
	ground_shadow(Vector2(feet.x, FEET.y + 4.0), Vector2(46 - hop * 0.4, 9), 0.45)
	draw_set_transform(feet, 0.0, Vector2.ONE * TEXEL)
	stamp(Hero.texture(&"idle", true, "shocked"), -Hero.FEET, 1.0, LAMP)
	draw_set_transform(Vector2.ZERO)
	# Ribbon bands wound round from shoulders to boots.
	for band in 7:
		var y := feet.y - 170.0 + band * 22.0
		var tilt := 10.0 if band % 2 == 0 else -10.0
		var left := Vector2(feet.x - 64.0, y - tilt)
		var right := Vector2(feet.x + 64.0, y + tilt)
		draw_line(left, right, INK, 14.0)
		draw_line(left, right, RIBBON if band % 2 == 0 else RIBBON_DARK, 10.0)
		draw_line(left + Vector2(0, -3), right + Vector2(0, -3), RIBBON.lightened(0.35), 2.0)
	# A loose end flaps from the top.
	var flap := 0.0 if reduced_motion else sin(since * 12.0) * 14.0
	draw_line(feet + Vector2(30, -176), feet + Vector2(80, -200 + flap), INK, 9.0)
	draw_line(feet + Vector2(30, -176), feet + Vector2(80, -200 + flap), RIBBON, 6.0)
	if since > 0.3:
		label(feet + Vector2(0, -240), "嗚嗚嗚！", 24, CREAM)


# --- Drummer ----------------------------------------------------------------------

func _draw_drummer(phase: String) -> void:
	var look := "down"
	var beat := float(state.get("beat", 0.6))
	var until := float(state.get("next_beat", 0.0)) - now
	var tempo: Dictionary = state.get("tempo_change", {})
	if phase == "dance":
		look = "up" if fmod(until, beat) > beat * 0.6 else "down"
		if not tempo.is_empty() and float(tempo.at) - now > 0.0 and float(tempo.at) - now < beat * 1.6:
			look = "high"
	elif phase == "roll" and not reduced_motion:
		look = "up" if fmod(now, 0.1) < 0.05 else "down"
	ground_shadow(DRUMMER + Vector2(10, 6), Vector2(120, 14), 0.5)
	draw_set_transform(DRUMMER + Vector2(-46, 0), 0.0, Vector2.ONE * TEXEL * 1.25)
	stamp(_drummer[look], -Vector2(13, 34), 1.0, LAMP)
	draw_set_transform(Vector2.ZERO)
	var hit := 0.0 if reduced_motion or phase != "dance" else maxf(0.0, 1.0 - (beat - fmod(until + beat * 4.0, beat)) / 0.12)
	var drum_at := DRUMMER + Vector2(50, 0)
	draw_set_transform(drum_at, 0.0, Vector2(1.0 + hit * 0.04, 1.0 - hit * 0.04) * TEXEL * 1.25)
	stamp(_drum, Vector2(-15, -28), 1.0, LAMP)
	draw_set_transform(Vector2.ZERO)
	# The crash cymbal on its stand.
	var stand := DRUMMER + Vector2(140, 0)
	draw_line(stand, stand + Vector2(0, -170), INK, 6.0)
	draw_line(stand, stand + Vector2(0, -170), Color("#8a8a9a"), 3.0)
	var crash := float(state.get("crash_at", -99.0))
	var fake := float(state.get("fake_crash_at", -99.0))
	var shake := 0.0
	for moment: float in [crash, fake]:
		var after := now - moment
		if after >= 0.0 and after < 0.6 and not reduced_motion:
			shake = maxf(shake, (1.0 - after / 0.6) * 0.35)
	draw_set_transform(stand + Vector2(0, -176), sin(now * 40.0) * shake, Vector2.ONE * TEXEL)
	stamp(_cymbal, Vector2(-10, -3), 1.0, LAMP)
	draw_set_transform(Vector2.ZERO)


func _draw_cues(phase: String, since: float) -> void:
	var tempo: Dictionary = state.get("tempo_change", {})
	var beat := float(state.get("beat", 0.6))
	if phase == "dance" and not tempo.is_empty():
		var ahead := float(tempo.at) - now
		if ahead > 0.0 and ahead < beat * 1.6:
			label(DRUMMER + Vector2(0, -190), "變快！" if bool(tempo.faster) else "變慢！", 26, GOLD, 0.9 + 0.1 * pulse(5.0))
	if phase == "dance" and int(state.get("beats_left", 0)) <= 2:
		label(DRUMMER + Vector2(0, -230), "快收尾了…", 20, CREAM)
	if phase == "roll":
		var crash := float(state.get("crash_at", -99.0))
		var fake := float(state.get("fake_crash_at", -99.0))
		if now < crash:
			label(DRUMMER + Vector2(-20, -200), "咚咚咚咚…", 24, CREAM, 0.9 + 0.1 * pulse(8.0))
		if fake > 0.0 and now >= fake and now - fake < 0.5:
			label(DRUMMER + Vector2(140, -230), "鏘…還沒！", 22, ROSE)
		if now >= crash:
			label(DRUMMER + Vector2(140, -230), "鏘！", 34, GOLD, pop_in(now - crash, 0.15))
		label(FEET + Vector2(0, 60), "鏘！的那一下按空白鍵", 20, CREAM)


## The bass drum: red shell with brass hoops, a lit head and tension rods.
func _paint_drum(x: int, y: int) -> Color:
	var offset := Vector2((x + 0.5 - 15.0) / 15.0, (y + 0.5 - 14.0) / 14.0)
	if offset.length() > 1.0:
		return Pixels.CLEAR
	if offset.length() > 0.86:
		return Pixels.metal(BRASS, x, y)
	if offset.length() > 0.78:
		return Pixels.lit(Color("#a83a3a"), 0.4 - offset.y, x, y)
	if posmod(int(atan2(offset.y, offset.x) / TAU * 12.0 * 10.0), 10) == 0 and offset.length() > 0.7:
		return Pixels.metal(BRASS, x, y)
	# A painted gold star on the head, scuffed where the beater lands.
	var angle := fposmod(atan2(offset.y, offset.x) + PI * 0.5, TAU / 5.0) - TAU / 10.0
	var spike := 0.32 + 0.3 * (1.0 - absf(angle) / (TAU / 10.0))
	if offset.length() < spike * 0.95 and offset.length() > 0.05:
		return Pixels.lit(Color("#e9b85c"), 0.5 - offset.y * 0.6, x, y)
	var scuff := 0.25 * (Pixels.noise(x, y, 31) - 0.5) - (0.2 if Vector2(offset.x - 0.1, offset.y - 0.2).length() < 0.2 else 0.0)
	return Pixels.lit(Color("#efe2c4"), 0.6 - offset.length() * 0.6 - offset.y * 0.3 + scuff, x, y)


## The drummer: bandleader's red jacket and shako, sticks low, up or held high.
static func _drummer_blocks(look: String) -> Array:
	var coat := Color("#b8463f")
	var gold := Color("#e9b85c")
	var skin := Color("#f0c8a0")
	var ink := Color("#2b2440")
	var blocks: Array = [
		[Rect2(-5, -3, 4, 3), ink], [Rect2(1, -3, 4, 3), ink],
		[Rect2(-4, -14, 3, 11), Color("#3b3550")], [Rect2(1, -14, 3, 11), Color("#3b3550")],
		[Rect2(-7, -27, 14, 14), coat], [Rect2(-1, -27, 2, 14), gold], [Rect2(-7, -15, 14, 2), gold],
		[Rect2(-5, -35, 10, 8), skin], [Rect2(-3, -32, 2, 2), ink], [Rect2(2, -32, 2, 2), ink], [Rect2(-2, -29, 4, 1), Color("#c9344a")],
		[Rect2(-5, -41, 10, 6), Color("#2b2440")], [Rect2(-5, -37, 10, 1), gold], [Rect2(-1, -43, 2, 2), Color("#e85a7a")],
	]
	match look:
		"up":
			blocks.append_array([[Rect2(-10, -30, 3, 6), coat], [Rect2(7, -30, 3, 6), coat], [Rect2(-12, -36, 2, 8), Color("#c9a46a")], [Rect2(10, -36, 2, 8), Color("#c9a46a")]])
		"high":
			blocks.append_array([[Rect2(-10, -38, 3, 12), coat], [Rect2(7, -38, 3, 12), coat], [Rect2(-10, -46, 2, 8), Color("#c9a46a")], [Rect2(8, -46, 2, 8), Color("#c9a46a")]])
		_:
			blocks.append_array([[Rect2(-10, -26, 3, 9), coat], [Rect2(7, -26, 3, 9), coat], [Rect2(-13, -18, 6, 2), Color("#c9a46a")], [Rect2(7, -18, 6, 2), Color("#c9a46a")]])
	return blocks
