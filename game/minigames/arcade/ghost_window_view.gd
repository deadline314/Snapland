extends "res://game/minigames/arcade/arcade_view.gd"
## Picture for 鬼影擦窗: the hotel hall at night (hotel_backdrop) with a tall
## six-pane window in a cream frame between velvet curtains, a moonlit garden
## outside. Fog lies on the glass in chunky pixel cells with drip streaks; the
## cloth wipes it away as it moves. A little ghost peeks in at one pane, a soft
## glow through the fog, fading as time runs out; wiped clear he waves hello.
## A wrong pane shows the traveller's own shocked reflection with a big ghost
## grinning behind them, while the traveller in the room jumps, hair on end.
## Every object is baked pixel art.

const Hero = preload("res://game/minigames/arcade/arcade_hero.gd")
const Hotel = preload("res://game/minigames/arcade/hotel_backdrop.gd")
const FRAME := Color("#e8dcc4")
const FOG := Color(0.88, 0.86, 0.96)
const GLOW := Color("#c9b6ff")
const NIGHT_TINT := Color(0.95, 0.94, 1.04)
const MULLION := 12.0

var _garden: ImageTexture
var _cloth: ImageTexture
var _pot: ImageTexture


func _init() -> void:
	super()
	word_anchor = Vector2(1150, 300)


func _ready() -> void:
	_cloth = Pixels.bake("gw-cloth", Vector2i(15, 11), _paint_cloth)
	_pot = Pixels.bake("gw-pot", Vector2i(14, 16), _paint_pot)


func _draw_backdrop() -> void:
	Hotel.draw(self, now, reduced_motion)
	vignette(0.3)


func _draw_scene() -> void:
	if not state.has("fog"):
		return
	var window: Rect2 = state.window
	_place_words()
	_draw_frame(window)
	_draw_garden(window)
	_draw_ghosts(true)
	_draw_fog(window)
	_draw_ghosts(false)
	_draw_mullions(window)
	_draw_hello()
	_draw_scare()
	_draw_sill(window)
	_draw_cloth()
	_draw_hero()
	var streak := int(state.get("streak", 0))
	if streak >= 3:
		label(Vector2(1140, 640), "連擦 × %d" % streak, 26, GOLD, 1.0 + 0.08 * pulse(2.0))


## Feedback words sit on a top pane on the far side from what just happened,
## so they never cover the ghost or the reflection.
func _place_words() -> void:
	var focus := -1
	var scare: Dictionary = state.get("scare", {})
	var hello: Dictionary = state.get("hello", {})
	if not scare.is_empty() and age(float(scare.at)) < 2.0:
		focus = int(scare.pane)
	elif not hello.is_empty():
		focus = int(hello.pane)
	var far := 2 if focus < 0 or focus % 3 == 0 else 0
	word_anchor = _pane_rect(far).get_center() + Vector2(0, -20)


func _pane_rect(pane: int) -> Rect2:
	var window: Rect2 = state.window
	var size := Vector2(window.size.x / 3.0, window.size.y / 2.0)
	return Rect2(window.position + Vector2(pane % 3, pane / 3) * size, size)


# --- The window ----------------------------------------------------------------

func _draw_frame(window: Rect2) -> void:
	var outer := window.grow(26.0)
	# Velvet curtains either side, tied back.
	for side in 2:
		var x := outer.position.x - 96.0 if side == 0 else outer.end.x + 8.0
		panel(Rect2(x, outer.position.y - 30.0, 88, outer.size.y + 70.0), "velvet", Color("#7a3a5c"), Color("#d9a64e"))
	draw_rect(Rect2(outer.position + Vector2(12, 14), outer.size), Color(Props.SHADOW, 0.35))
	panel(outer, "planks_v", FRAME.darkened(0.2))
	draw_rect(window.grow(4.0), FRAME.darkened(0.55))


func _draw_garden(window: Rect2) -> void:
	if _garden == null:
		var size := Vector2i(window.size / TEXEL)
		_garden = Pixels.cached("gw-garden|%d|%d" % [size.x, size.y], func() -> Image:
			var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
			for y in size.y:
				for x in size.x:
					image.set_pixel(x, y, _paint_garden(x, y, size))
			return image)
	draw_texture_rect(_garden, window, false, NIGHT_TINT)


func _draw_fog(window: Rect2) -> void:
	var fog: PackedFloat32Array = state.fog
	var grid: Vector2i = state.grid
	var cell := float(state.cell)
	for y in grid.y:
		for x in grid.x:
			var amount := fog[y * grid.x + x]
			if amount <= 0.02:
				continue
			var at := window.position + Vector2(x, y) * cell
			var rect := Rect2(at, Vector2(cell, cell)).intersection(window)
			var shade := 0.04 * (Pixels.noise(x, y, 17) - 0.5)
			draw_rect(rect, Color(FOG.r + shade, FOG.g + shade, FOG.b + shade, 0.9 * amount))
			# Beads and drip streaks run down the thickest fog.
			if amount > 0.7 and Pixels.noise(x, y, 23) > 0.82:
				draw_rect(Rect2(at + Vector2(cell * 0.4, cell * 0.2), Vector2(4, cell * 0.8)), Color(0.7, 0.72, 0.86, 0.55 * amount))
				draw_rect(Rect2(at + Vector2(cell * 0.4 - 1.0, cell * 0.85), Vector2(6, 6)), Color(1, 1, 1, 0.6 * amount))


func _draw_mullions(window: Rect2) -> void:
	for column in range(1, 3):
		var x := window.position.x + window.size.x * column / 3.0
		panel(Rect2(x - MULLION * 0.5, window.position.y - 2.0, MULLION, window.size.y + 4.0), "planks_v", FRAME.darkened(0.15))
	panel(Rect2(window.position.x - 2.0, window.get_center().y - MULLION * 0.5, window.size.x + 4.0, MULLION), "planks", FRAME.darkened(0.15))


func _draw_sill(window: Rect2) -> void:
	var sill := Rect2(window.position.x - 50.0, window.end.y + 26.0, window.size.x + 100.0, 24)
	draw_rect(Rect2(sill.position + Vector2(8, 12), sill.size), Color(Props.SHADOW, 0.4))
	panel(sill, "planks", FRAME.darkened(0.3))
	for side: float in [0.08, 0.92]:
		var at := Vector2(lerpf(sill.position.x, sill.end.x, side) - 28.0, sill.position.y - 62.0)
		cast_shadow(_pot, at, Vector2(6, 4), TEXEL, 0.3)
		stamp(_pot, at, TEXEL, NIGHT_TINT)


# --- The ghosts ----------------------------------------------------------------

## Behind the fog: each peeking ghost, fading as his time runs out. In front:
## a soft glow that shows through the fog where he is.
func _draw_ghosts(behind: bool) -> void:
	for ghost: Dictionary in state.get("ghosts", []):
		var hop_at := float(ghost.hop_at)
		var hopped := hop_at < 0.0 or now >= hop_at
		var pane := int(ghost.pane) if hopped else int(ghost.from)
		var since := age(float(ghost.at))
		var left := 1.0 - since / maxf(0.1, float(ghost.stay))
		var fade := clampf(left / 0.35, 0.0, 1.0)
		var centre := _pane_rect(pane).get_center()
		var bob := 0.0 if reduced_motion else 6.0 * sin(now * 2.0 + pane)
		if behind:
			var sprite := Hotel.ghost("cheeky" if fade > 0.5 else "oops")
			var size := Vector2(sprite.get_size()) * 6.0
			stamp(sprite, centre - size * 0.5 + Vector2(0, bob), 6.0, Color(1, 1, 1, 0.95 * fade))
		else:
			var glow := (0.25 + 0.15 * pulse(1.2, pane * 0.3)) * fade
			for ring in 3:
				draw_circle(centre + Vector2(0, bob), 30.0 + ring * 22.0, Color(GLOW, glow * 0.45))
			if hop_at >= 0.0 and absf(now - hop_at) < 0.3:
				dust_puffs(centre, now - hop_at, 60.0)


func _draw_hello() -> void:
	var hello: Dictionary = state.get("hello", {})
	if hello.is_empty():
		return
	var since := age(float(hello.at))
	if since < 0.0 or since > float(state.get("wave_seconds", 0.9)):
		return
	var rect := _pane_rect(int(hello.pane))
	var centre := rect.get_center()
	# He pops through the misting glass waving, with a little sparkle.
	var grow := pop_in(since, 0.25)
	var sprite := Hotel.ghost("happy")
	var size := Vector2(sprite.get_size()) * 6.0 * grow
	draw_circle(centre, 70.0 * grow, Color(GLOW, 0.25))
	stamp(sprite, centre - size * 0.5, 6.0 * grow, Color.WHITE)
	var wave := 0.0 if reduced_motion else 0.5 * sin(since * 18.0)
	var hand := centre + Vector2(52, -22).rotated(wave) * grow
	draw_circle(hand, 9.0 * grow, Color("#eef0ff"))
	draw_circle(hand, 9.0 * grow, Color(0.4, 0.38, 0.6, 0.3), false, 2.0)
	for spark in 6:
		var dir := Vector2.from_angle(spark * TAU / 6.0 + since * 2.0)
		draw_rect(Rect2(centre + dir * (60.0 + since * 60.0) - Vector2(3, 3), Vector2(6, 6)), Color(GOLD, 1.0 - since))


func _draw_scare() -> void:
	var scare: Dictionary = state.get("scare", {})
	if scare.is_empty():
		return
	var since := age(float(scare.at))
	if since < 0.0 or since > float(state.get("scare_seconds", 1.6)):
		return
	var rect := _pane_rect(int(scare.pane)).grow(-8.0)
	# A dark clear patch of glass like a mirror: the traveller's own reflection
	# and a big grinning ghost right behind them.
	draw_rect(rect, Color("#1d1a33"))
	var ghost := Hotel.ghost("cheeky")
	var ghost_size := Vector2(ghost.get_size()) * 9.0
	var rise := pop_in(since, 0.3)
	stamp(ghost, rect.get_center() - ghost_size * 0.5 + Vector2(40, -16.0 - 20.0 * rise), 9.0, Color(1, 1, 1, 0.75))
	var me := Hero.texture(&"up", true, "shocked")
	var scale_factor := 2.4
	var feet := Vector2(rect.get_center().x - 30.0, rect.end.y + 30.0)
	stamp(me, feet + Vector2(-Hero.FEET.x, -Hero.FEET.y) * scale_factor + Vector2(scale_factor, scale_factor), scale_factor, Color(0.75, 0.75, 0.95))
	_draw_hair_on_end(feet + Vector2(0, -44.0 * scale_factor), scale_factor * 0.6)


func _draw_hair_on_end(top: Vector2, scale_factor: float) -> void:
	for spike in 5:
		var x := (spike - 2) * 7.0 * scale_factor
		var tall := (14.0 + 6.0 * (2 - absi(spike - 2))) * scale_factor
		draw_line(top + Vector2(x, 0), top + Vector2(x * 1.3, -tall), Color("#2f3660"), 5.0 * scale_factor * 0.5)


# --- The cloth and the traveller ---------------------------------------------------

func _draw_cloth() -> void:
	var at: Vector2 = state.get("cloth", Vector2(640, 400))
	var velocity: Vector2 = state.get("cloth_velocity", Vector2.ZERO)
	var tilt := 0.0 if reduced_motion else clampf(velocity.x / 1400.0, -0.35, 0.35)
	var size := Vector2(_cloth.get_size()) * TEXEL
	draw_set_transform(at + Vector2(10, 14), tilt, Vector2.ONE)
	draw_texture_rect(_cloth, Rect2(-size * 0.5, size), false, Color(Props.SHADOW, 0.3))
	draw_set_transform(at, tilt, Vector2.ONE)
	draw_texture_rect(_cloth, Rect2(-size * 0.5, size), false, NIGHT_TINT)
	draw_set_transform(Vector2.ZERO)


func _draw_hero() -> void:
	var cloth: Vector2 = state.get("cloth", Vector2(640, 400))
	var scare: Dictionary = state.get("scare", {})
	var since := age(float(scare.get("at", -99.0))) if not scare.is_empty() else 99.0
	var frightened := since >= 0.0 and since < float(state.get("scare_seconds", 1.6))
	var x := clampf(cloth.x - 60.0, 220.0, 1060.0)
	var scale_factor := 3.2
	var jump := 0.0 if reduced_motion or not frightened else -absf(sin(since * 9.0)) * 30.0 * (1.0 - since / 1.6)
	var feet := Vector2(x, 790.0 + jump)
	var sprite := Hero.texture(&"up", false)
	stamp(sprite, feet + Vector2(-Hero.FEET.x, -Hero.FEET.y) * scale_factor + Vector2(scale_factor, scale_factor), scale_factor, NIGHT_TINT)
	# A long wooden pole from the traveller's hands up to the cloth.
	var hands := feet + Vector2(4, -40.0 * scale_factor)
	draw_line(hands + Vector2(4, 6), cloth + Vector2(4, 26), Color(Props.SHADOW, 0.3), 10.0)
	draw_line(hands, cloth + Vector2(0, 20), Color("#5a3a2a"), 10.0)
	draw_line(hands + Vector2(-2, 0), cloth + Vector2(-2, 20), Color("#9a6a40"), 5.0)
	if frightened:
		_draw_hair_on_end(feet + Vector2(-2, -45.0 * scale_factor), scale_factor * 0.6)


# --- Texel painters ---------------------------------------------------------------

## The garden at night through the window: deep sky with stars and the moon,
## a line of dark trees, a lit lamp post and a hedge.
func _paint_garden(x: int, y: int, size: Vector2i) -> Color:
	var down := float(y) / size.y
	var moon := Vector2(x - size.x * 0.78, y - size.y * 0.22).length()
	if moon < 7.0:
		return Color("#fff2c4").darkened(0.08 if Pixels.noise(x, y, 3) > 0.8 else 0.0)
	var sky := Color("#1c2048").lerp(Color("#3b3f7a"), down)
	if moon < 12.0:
		sky = sky.lerp(Color("#fff2c4"), 0.25 * (12.0 - moon) / 5.0)
	var trees := size.y * 0.55 + 6.0 * sin(x * 0.12) + 4.0 * sin(x * 0.31 + 1.0)
	if y > trees:
		sky = Color("#16233a").lerp(Color("#22304a"), Pixels.noise(x / 3, y / 3, 5) * 0.6)
	var hedge := size.y * 0.82 + 2.0 * sin(x * 0.4)
	if y > hedge:
		sky = Color("#1f3a34").lerp(Color("#2a4a40"), Pixels.noise(x / 2, y / 2, 7))
	var post := x - int(size.x * 0.3)
	if absi(post) <= 0 and y > size.y * 0.6 and y < hedge:
		return Color("#3a3040")
	if Vector2(post, y - size.y * 0.58).length() < 2.2:
		return Color("#ffe8a8")
	if Pixels.noise(x, y, 19) > 0.985 and down < 0.5:
		return Color("#fff7d8")
	return sky


## A cream cloth bunched in a hand, with a stitched hem.
func _paint_cloth(x: int, y: int) -> Color:
	var at := Vector2((x + 0.5 - 7.5) / 7.5, (y + 0.5 - 5.5) / 5.5)
	if at.length() > 1.0 + 0.12 * sin(x * 1.7):
		return Pixels.CLEAR
	if y == 9 and posmod(x, 2) == 0:
		return Color("#e79bb6")
	var fold := 0.3 * sin(x * 1.3 + y * 0.7)
	return Pixels.lit(Color("#f4ecd8"), 0.4 - at.y * 0.5 + fold, x, y)


## A clay pot with a small fern.
func _paint_pot(x: int, y: int) -> Color:
	if y < 8:
		var leaf := absf(x + 0.5 - 7.0) < (8 - y) * 0.9 and posmod(x + y, 3) != 0
		return Pixels.lit(Color("#4f8a4a"), 0.4 - y * 0.05, x, y) if leaf else Pixels.CLEAR
	var inset := (y - 8) / 3
	if x < 1 + inset or x > 12 - inset:
		return Pixels.CLEAR
	if y == 8:
		return Color("#d98a5a")
	return Pixels.lit(Color("#b8643f"), 0.5 - x * 0.08, x, y)
