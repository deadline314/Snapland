extends "res://game/minigames/arcade/arcade_view.gd"
## Picture for 風箏追風: the kite terrace under the sky park's shared backdrop
## (sky_backdrop.gd). The island traveller stands at the rail with their back to
## us, flying a big diamond kite on a long sagging line. A column of rising wind
## streaks marks where the wind blows, with a big arrow over it (coral and
## shaking when turbulence is lying about it); the kite climbs in the column and
## flutters and sinks outside it. Cloud rings drift down through the sky. When
## the kite stalls, the line wraps round the traveller and the kite hauls them
## up into the sky and drops them back on the deck in a puff of dust.

const Hero = preload("res://game/minigames/arcade/arcade_hero.gd")
const SkyBackdrop = preload("res://game/minigames/arcade/sky_backdrop.gd")
const LEFT := 80.0
const WIDE := 1120.0
const TOP := 168.0
const TALL := 480.0
const DECK_Y := 650.0
const RAIL_Y := 590.0
const HERO_X := 640.0
const HERO_SCALE := 3.0
const WOOD := Color("#a87a4f")
const DARK_WOOD := Color("#6e4c32")
const STRING := Color("#f4ecd8")
const CORAL := Color("#ff8a6b")
const SUN := Color("#ffd35c")
const NAVY := Color("#2f4a7a")
const MINT_KITE := Color("#8fe0c4")
const LILAC := Color("#b9a9f0")
const WHITE := Color("#fbfdff")
const CLOUD_SHADE := Color("#d5e3f6")
const NOON := Color(1.0, 0.99, 0.96)

var _kite: ImageTexture
var _arrow_shown := 0.5


func _init() -> void:
	super()
	word_anchor = Vector2(330, 300)


func _ready() -> void:
	_kite = Pixels.bake("windkite", Vector2i(18, 24), _paint_kite)


func _x(at: float) -> float:
	return LEFT + at * WIDE


func _y(at: float) -> float:
	return TOP + at * TALL


func _draw_backdrop() -> void:
	SkyBackdrop.draw(self, now, reduced_motion)
	_draw_rail()
	stage_floor(DECK_Y, WOOD, DARK_WOOD)
	vignette(0.3)


func _draw_rail() -> void:
	panel(Rect2(-8, RAIL_Y - 10.0, DESIGN.x + 16.0, 16), "planks", WOOD.lightened(0.08), Color(0, 0, 0, 0), TEXEL, NOON)
	panel(Rect2(-8, RAIL_Y + 26.0, DESIGN.x + 16.0, 12), "planks", WOOD, Color(0, 0, 0, 0), TEXEL, NOON)
	for post in 9:
		var x := 20.0 + post * 155.0
		panel(Rect2(x, RAIL_Y - 18.0, 20, DECK_Y - RAIL_Y + 18.0), "planks_v", DARK_WOOD.lightened(0.1), Color(0, 0, 0, 0), TEXEL, NOON)
		if post < 8:
			for flag in 5:
				var a := Vector2(x + 20.0 + flag * 27.0, RAIL_Y - 14.0 + sin(flag * 0.6) * 6.0)
				var tone: Color = [CORAL, SUN, MINT_KITE, LILAC, WHITE][(flag + post) % 5]
				draw_colored_polygon(PackedVector2Array([a, a + Vector2(18, 0), a + Vector2(9, 16)]), tone.darkened(0.15))
				draw_colored_polygon(PackedVector2Array([a + Vector2(2, 1), a + Vector2(16, 1), a + Vector2(9, 13)]), tone)


func _draw_scene() -> void:
	if not state.has("kite_x"):
		return
	_draw_window()
	_draw_rings()
	_draw_arrow()
	var hands := _draw_hero()
	_draw_line(hands)
	_draw_kite()
	_draw_combo()


## How far into the stall-and-drag the traveller is, or -1.
func _dragged() -> float:
	var since := age(float(state.get("stall_at", -99.0)))
	return since if since >= 0.0 and since < float(state.get("drag_seconds", 2.2)) else -1.0


func _draw_window() -> void:
	# A soft column of rising wind streaks where the wind blows.
	var centre := _x(float(state.wind_x))
	var half := float(state.get("window_half", 0.12)) * WIDE
	for band in 4:
		var spread := half * (1.0 - band * 0.22)
		draw_rect(Rect2(centre - spread, TOP + 40.0, spread * 2.0, _y(0.86) - TOP - 40.0), Color(WHITE, 0.09))
	for edge: float in [-1.0, 1.0]:
		draw_line(Vector2(centre + edge * half, TOP + 40.0), Vector2(centre + edge * half, _y(0.86)), Color(WHITE, 0.45), 2.0)
	for streak in 10:
		var lane := Pixels.noise(streak, 2, 9) * 2.0 - 1.0
		var run := 0.5 if reduced_motion else fposmod(now * 0.9 + Pixels.noise(streak, 4, 9), 1.0)
		var base := Vector2(centre + lane * half * 0.85, _y(0.86) - run * (_y(0.86) - TOP - 40.0))
		draw_line(base + Vector2(2, 2), base + Vector2(2, -58), Color(NAVY, 0.2), 5.0)
		draw_line(base, base + Vector2(0, -60), Color(WHITE, 0.9 * (1.0 - absf(lane) * 0.4)), 4.0)
		if streak % 3 == 0:
			draw_arc(base + Vector2(8, -66), 8.0, PI * 0.5, PI * 1.5, 8, Color(WHITE, 0.7), 3.0)


func _draw_arrow() -> void:
	# A big arrow over the wind's column, pointing down into it. Turbulence makes
	# it point the wrong way for a moment, shaking and coral.
	var target := float(state.get("arrow_x", 0.5))
	_arrow_shown = target if reduced_motion else lerpf(_arrow_shown, target, 0.25)
	var fake := bool(state.get("fake", false))
	var shake := 0.0 if reduced_motion or not fake else sin(now * 40.0) * 6.0
	var at := Vector2(_x(_arrow_shown) + shake, 214.0)
	var tone := CORAL if fake else SUN
	var fresh := age(float(state.get("arrow_at", -99.0)))
	var grow := 1.0 + (0.25 * (1.0 - fresh / 0.4) if fresh >= 0.0 and fresh < 0.4 and not reduced_motion else 0.0)
	var shape := PackedVector2Array([Vector2(-14, -34), Vector2(14, -34), Vector2(14, 0), Vector2(30, 0), Vector2(0, 32), Vector2(-30, 0), Vector2(-14, 0)])
	var outline := PackedVector2Array()
	var fill := PackedVector2Array()
	for point in shape:
		outline.append(at + point * grow * 1.15)
		fill.append(at + point * grow)
	draw_colored_polygon(outline, NAVY)
	draw_colored_polygon(fill, tone)
	draw_line(at + Vector2(-8, -28) * grow, at + Vector2(-8, 2) * grow, tone.lightened(0.4), 3.0)
	label(at + Vector2(0, -56), "亂流！" if fake else "風", 22 if fake else 24, tone if fake else WHITE)


func _draw_rings() -> void:
	for ring: Dictionary in state.rings:
		var at := Vector2(_x(float(ring.x)), _y(float(ring.y)))
		# Rings fade away as they sink past the kite's lowest reach, before the rail.
		var sink := 1.0 - smoothstep(0.8, 0.88, float(ring.y))
		if sink <= 0.0:
			continue
		var radius := float(state.get("ring_half", 0.06)) * WIDE
		var since := age(float(ring.at))
		match str(ring.state):
			"caught":
				var grow := 1.0 + since * 1.2
				_ring(at, radius * grow, Color(SUN, maxf(0.0, 1.0 - since / 0.6)))
				glint(at, radius * 0.8, 99.0, -since)
			"missed":
				_ring(at, radius, Color(CLOUD_SHADE, maxf(0.0, 0.6 - since)))
			_:
				_ring(at, radius, Color(WHITE, sink))


## A puffy cloud ring seen a little from below: a thick lit ellipse.
func _ring(at: Vector2, radius: float, tone: Color) -> void:
	if tone.a <= 0.0:
		return
	draw_set_transform(at, 0.0, Vector2(1.0, 0.42))
	draw_arc(Vector2(0, 6), radius, 0.0, TAU, 32, Color(NAVY, 0.25 * tone.a), 18.0)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, Color(CLOUD_SHADE, tone.a), 16.0)
	draw_arc(Vector2(0, -3), radius, PI * 1.05, PI * 1.95, 16, tone, 10.0)
	for puff in 8:
		var angle := puff * TAU / 8.0
		draw_circle(Vector2.from_angle(angle) * radius + Vector2(0, -2), 10.0, Color(tone, tone.a * 0.95))
	draw_set_transform(Vector2.ZERO)


## The traveller at the rail; returns where the line leaves their hands.
func _draw_hero() -> Vector2:
	var dragged := _dragged()
	var lift := 0.0
	var tilt := 0.0
	if dragged >= 0.0:
		# Up into the sky with the kite, then back down onto the deck with a bump.
		var up := clampf(dragged / 1.5, 0.0, 1.0)
		lift = 260.0 * sin(up * PI) if dragged < 1.5 else 0.0
		tilt = 0.0 if reduced_motion else sin(dragged * 9.0) * 0.18 * (1.0 - up)
	var feet := Vector2(HERO_X, DECK_Y + 4.0 - lift)
	var pulling := int(state.get("pulling", 0))
	var pose := &"up"
	if pulling < 0:
		pose = &"left"
	elif pulling > 0:
		pose = &"right"
	var mood := "shocked" if dragged >= 0.0 else ("plain" if bool(state.get("in_wind", true)) else "sorry")
	ground_shadow(Vector2(HERO_X, DECK_Y + 6.0), Vector2(54.0 - lift * 0.1, 12.0 - lift * 0.02), 0.42 - lift * 0.001)
	draw_set_transform(feet, tilt, Vector2.ONE)
	stamp(Hero.texture(pose, false, mood), -Vector2(20, 46) * HERO_SCALE, HERO_SCALE, NOON)
	draw_set_transform(Vector2.ZERO)
	if dragged >= 0.0:
		# The line wound round and round the traveller.
		for loop in 3:
			var centre := feet + Vector2(0, -70.0 - loop * 22.0).rotated(tilt)
			draw_set_transform(centre, tilt + 0.25 * (loop - 1), Vector2(1.0, 0.32))
			draw_arc(Vector2.ZERO, 46.0, 0.0, TAU, 20, STRING.darkened(0.2), 4.0)
			draw_set_transform(Vector2.ZERO)
		if dragged > 1.45 and dragged < 2.0:
			dust_puffs(Vector2(HERO_X, DECK_Y), dragged - 1.45, 70.0)
		return feet + Vector2(0, -150).rotated(tilt)
	var reach := Vector2(-48, -112) if pulling < 0 else (Vector2(48, -112) if pulling > 0 else Vector2(0, -136))
	return feet + reach


func _kite_at() -> Vector2:
	return Vector2(_x(float(state.kite_x)), _y(float(state.kite_y)))


func _draw_line(hands: Vector2) -> void:
	var kite := _kite_at() + Vector2(0, 30)
	var sag := hands.lerp(kite, 0.5) + Vector2(0, 50.0 + 40.0 * (1.0 - float(state.get("kite_h", 0.5))))
	var line := PackedVector2Array()
	for step in 17:
		var t := step / 16.0
		line.append(hands.lerp(sag, t).lerp(sag.lerp(kite, t), t))
	draw_polyline(line, Color(NAVY, 0.5), 3.0)
	draw_polyline(line, STRING, 1.5)


func _draw_kite() -> void:
	var at := _kite_at()
	var calm := bool(state.get("in_wind", true))
	var flutter := 0.0
	if not calm and not reduced_motion:
		flutter = sin(now * 14.0) * 0.3
	var angle := clampf(float(state.get("kite_vx", 0.0)) * 0.5, -0.4, 0.4) + flutter
	# A tail of bows hanging below, swinging the other way.
	var tail := PackedVector2Array([at + Vector2(0, 40).rotated(angle)])
	for bow in 5:
		var sway := 0.0 if reduced_motion else sin(now * 5.0 + bow * 0.8) * (6.0 + bow * 2.0)
		tail.append(tail[tail.size() - 1] + Vector2(sway * 0.4 - angle * 20.0, 22.0))
	draw_polyline(tail, Color(NAVY, 0.6), 2.0)
	for bow in 5:
		var spot := tail[bow + 1]
		var tone: Color = [CORAL, SUN, MINT_KITE, LILAC, WHITE][bow]
		draw_colored_polygon(PackedVector2Array([spot + Vector2(-9, -5), spot, spot + Vector2(-9, 5)]), tone)
		draw_colored_polygon(PackedVector2Array([spot + Vector2(9, -5), spot, spot + Vector2(9, 5)]), tone.darkened(0.15))
	cast_shadow(_kite, at - Vector2(9, 12) * TEXEL, Vector2(14, 20), TEXEL, 0.18)
	draw_set_transform(at, angle, Vector2.ONE)
	stamp(_kite, -Vector2(9, 12) * TEXEL, TEXEL, NOON)
	draw_set_transform(Vector2.ZERO)
	if calm and float(state.get("kite_h", 0.0)) > 0.9:
		glint(at + Vector2(-10, -20), 18.0, 2.0)
	if not calm and float(state.get("kite_h", 1.0)) < 0.3 and _dragged() < 0.0:
		label(at + Vector2(0, -70), "快掉了！", 22, CORAL, 1.0 + 0.1 * pulse(5.0))


func _draw_combo() -> void:
	var combo := int(state.get("combo", 0))
	if combo >= 3:
		# Low on the right, clear of the wind arrow that roams along the top.
		label(Vector2(1120, 540), "連穿 × %d" % combo, 26, SUN, 1.0 + 0.08 * pulse(2.0))


func _paint_kite(x: int, y: int) -> Color:
	# A big diamond kite in four colour panels with crossed spars and a star.
	var at := Vector2(x + 0.5, y + 0.5) - Vector2(9.0, 9.0)
	if absf(at.x) / 9.0 + absf(at.y) / (9.0 if at.y < 0.0 else 15.0) > 1.0:
		return Pixels.CLEAR
	if absf(at.x) < 0.6 or absf(at.y + 1.0) < 0.6:
		return DARK_WOOD
	if (at - Vector2(0, -1)).length() < 2.2:
		return SUN.lightened(0.2)
	var tone := CORAL if at.x < 0.0 else LILAC
	if at.y > -1.0:
		tone = SUN if at.x < 0.0 else MINT_KITE
	return Pixels.lit(tone, 0.4 - (at.x + at.y) / 18.0, x, y)
