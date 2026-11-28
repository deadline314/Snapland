extends "res://game/minigames/arcade/arcade_view.gd"
## Picture for 窗簾星圖: a hotel bedroom at night (hotel_backdrop behind) with a
## wide window between velvet curtains. Through it, three layers: a starry sky
## over far blue hills, a meadow with dark trees swaying, and a wooden fence
## the sheep jump, grass tufts nodding in front. Woolly sheep run and leap it,
## each with a shadow on the grass; ghost sheep float paler with wispy tails and
## no shadow (they look more and more like sheep later). Counted sheep are
## stitched as gold stars onto the left curtain. The traveller sits up in bed in
## front, a bedside lamp and tally slate beside them; a miscount sends them off
## to sleep in a stream of Zzz and rolling out of bed. Every object is baked
## pixel art.

const Hero = preload("res://game/minigames/arcade/arcade_hero.gd")
const Hotel = preload("res://game/minigames/arcade/hotel_backdrop.gd")
const WINDOW := Rect2(320, 150, 720, 330)
const GROUND := 0.8
const JUMP := 74.0
const QUILT := Color("#5b3f74")
const CURTAIN := Color("#7a3a5c")
const FRAME := Color("#e8dcc4")
const NIGHT_TINT := Color(0.95, 0.94, 1.04)
const STAR := Color("#ffd98a")
## Where the eight stars of a constellation are stitched on the left curtain.
const STAR_SPOTS: Array[Vector2] = [Vector2(212, 200), Vector2(248, 236), Vector2(222, 280), Vector2(262, 318),
	Vector2(230, 362), Vector2(268, 404), Vector2(236, 446), Vector2(252, 488)]

var _sky: ImageTexture
var _sheep: Array[ImageTexture] = []
var _ghost: ImageTexture
var _fence: ImageTexture
var _bed: ImageTexture
var _lamp: ImageTexture


func _init() -> void:
	super()
	word_anchor = Vector2(880, 214)


func _ready() -> void:
	for frame in 2:
		_sheep.append(Pixels.bake("sc-sheep|%d" % frame, Vector2i(22, 15), _paint_sheep.bind(frame)))
	_ghost = Pixels.bake("sc-ghost", Vector2i(22, 15), _paint_ghost_sheep)
	_fence = Pixels.bake("sc-fence", Vector2i(30, 16), _paint_fence)
	_bed = Pixels.bake("sc-bed", Vector2i(70, 30), _paint_bed)
	_lamp = Pixels.bake("sc-lamp", Vector2i(26, 34), _paint_lamp)


func _draw_backdrop() -> void:
	Hotel.draw(self, now, reduced_motion)
	vignette(0.3)


func _draw_scene() -> void:
	if not state.has("sheep"):
		return
	_draw_window()
	_draw_curtains()
	_draw_room()
	var streak := int(state.get("streak", 0))
	if streak >= 3:
		label(Vector2(1150, 430), "連數 × %d" % streak, 24, GOLD, 1.0 + 0.08 * pulse(2.0))


# --- Through the window -------------------------------------------------------------

func _draw_window() -> void:
	var frame := WINDOW.grow(22.0)
	draw_rect(Rect2(frame.position + Vector2(12, 14), frame.size), Color(Props.SHADOW, 0.35))
	panel(frame, "planks_v", FRAME.darkened(0.2))
	if _sky == null:
		var size := Vector2i(WINDOW.size / TEXEL)
		_sky = Pixels.cached("sc-sky|%d|%d" % [size.x, size.y], func() -> Image:
			var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
			for y in size.y:
				for x in size.x:
					image.set_pixel(x, y, _paint_sky(x, y, size))
			return image)
	draw_texture_rect(_sky, WINDOW, false, NIGHT_TINT)
	# Stars twinkling over the hills.
	for star in 26:
		var at := WINDOW.position + Vector2(fposmod(star * 97.0, WINDOW.size.x), fposmod(star * 53.0, WINDOW.size.y * 0.42) + 8.0)
		var twinkle := 0.7 if reduced_motion else 0.45 + 0.55 * absf(sin(now * (1.2 + star % 4 * 0.4) + star))
		draw_rect(Rect2(at.snapped(Vector2(4, 4)), Vector2(4, 4)), Color(1, 0.96, 0.8, twinkle))
	var ground := WINDOW.position.y + WINDOW.size.y * GROUND
	# The fence the sheep jump, and its shadow.
	var fence_size := Vector2(_fence.get_size()) * TEXEL
	var fence_at := Vector2(WINDOW.position.x + WINDOW.size.x * float(state.get("fence", 0.5)) - fence_size.x * 0.5, ground - fence_size.y + 10.0)
	ground_shadow(Vector2(fence_at.x + fence_size.x * 0.5, ground + 8.0), Vector2(fence_size.x * 0.55, 8), 0.4)
	stamp(_fence, fence_at, TEXEL, NIGHT_TINT)
	_draw_sheep(ground)
	# Foreground grass tufts nodding.
	for tuft in 18:
		var x := WINDOW.position.x + 18.0 + tuft * 40.0
		var lean := 0.0 if reduced_motion else 5.0 * sin(now * 1.6 + tuft * 0.7)
		var base := Vector2(x, WINDOW.end.y)
		for blade in 3:
			draw_line(base + Vector2(blade * 6 - 6, 0), base + Vector2(blade * 6 - 6 + lean, -22.0 - blade * 4.0), Color("#3f6a4a").lightened(blade * 0.08), 4.0)


func _draw_sheep(ground: float) -> void:
	var fence := float(state.get("fence", 0.5))
	for one: Dictionary in state.get("sheep", []):
		var x := (now - float(one.born)) / float(one.cross)
		if x < -0.08 or x > 1.08:
			continue
		var ghost := bool(one.ghost)
		var disguise := float(one.disguise)
		var screen_x := lerpf(WINDOW.position.x - 40.0, WINDOW.end.x + 40.0, x)
		var leap := clampf((x - (fence - 0.12)) / 0.24, 0.0, 1.0)
		var height := sin(leap * PI) * JUMP * (1.15 if ghost else 1.0)
		var hover := (10.0 + (0.0 if reduced_motion else 4.0 * sin(now * 5.0 + float(one.born)))) * (1.0 - disguise * 0.6) if ghost else 0.0
		var foot := Vector2(screen_x, ground - height - hover)
		if not ghost:
			# Real sheep cast a shadow on the grass; ghosts never do.
			ground_shadow(Vector2(screen_x + 4.0, ground + 4.0), Vector2(30.0 - height * 0.15, 6), 0.42 - height * 0.003)
		var running := leap <= 0.0 or leap >= 1.0
		var texture := _sheep[int(now * 8.0) % 2 if running and not reduced_motion else 1]
		var tint := NIGHT_TINT
		if ghost:
			texture = _ghost if disguise < 0.5 else texture
			tint = Color(0.82, 0.8, 1.0, lerpf(0.55, 0.92, disguise))
		if bool(one.counted):
			tint = tint.lerp(Color(1.1, 1.0, 0.7), 0.35)
		var size := Vector2(texture.get_size()) * TEXEL
		var tilt := 0.0 if running else (leap - 0.5) * 0.5
		draw_set_transform(foot, tilt, Vector2.ONE)
		draw_texture_rect(texture, Rect2(Vector2(-size.x * 0.5, -size.y), size), false, tint)
		draw_set_transform(Vector2.ZERO)
		if ghost and disguise < 0.8:
			# A wispy tail curls behind a ghost sheep.
			for wisp in 3:
				draw_circle(foot + Vector2(-size.x * 0.5 - wisp * 9.0, -size.y * 0.5 + wisp * 3.0), 6.0 - wisp * 1.5, Color(0.86, 0.84, 1.0, 0.4 - wisp * 0.1))


# --- The room -------------------------------------------------------------------

func _draw_curtains() -> void:
	for side in 2:
		var x := WINDOW.position.x - 150.0 if side == 0 else WINDOW.end.x + 30.0
		panel(Rect2(x, WINDOW.position.y - 40.0, 120, WINDOW.size.y + 110.0), "velvet", CURTAIN, Color("#d9a64e"))
	# Counted sheep stitched on as stars, a constellation at a time.
	var stars := int(state.get("stars", 0))
	for index in STAR_SPOTS.size():
		var at := STAR_SPOTS[index]
		if index < stars:
			var since := age(float(state.get("last_count", -99.0)))
			var grow := pop_in(since, 0.3) if index == stars - 1 else 1.0
			_star(at, 13.0 * grow, STAR)
			if index > 0:
				draw_line(STAR_SPOTS[index - 1], at, Color(STAR, 0.45), 2.0)
		else:
			_star(at, 7.0, Color(STAR, 0.18))
	var done := int(state.get("constellations", 0))
	if done > 0:
		label(Vector2(240, 556), "★ × %d" % done, 22, STAR)


func _star(at: Vector2, radius: float, tone: Color) -> void:
	var points := PackedVector2Array()
	for point in 10:
		var r := radius if point % 2 == 0 else radius * 0.45
		points.append(at + Vector2.from_angle(-PI * 0.5 + point * PI / 5.0) * r)
	draw_colored_polygon(points, tone)
	if tone.a > 0.5:
		draw_polyline(points + PackedVector2Array([points[0]]), tone.darkened(0.4), 2.0)


func _draw_room() -> void:
	var bed_size := Vector2(_bed.get_size()) * TEXEL
	var bed_at := Vector2(110.0, DESIGN.y - bed_size.y - 6.0)
	var doze := age(float(state.get("doze_at", -99.0)))
	var dozing := doze >= 0.0 and doze < float(state.get("doze_seconds", 1.7))
	ground_shadow(Vector2(bed_at.x + bed_size.x * 0.5, DESIGN.y - 4.0), Vector2(bed_size.x * 0.55, 14), 0.45)
	var scale_factor := 2.8
	if not dozing:
		# The traveller sitting up in bed, gazing out of the window.
		var hero := Hero.texture(&"idle", false)
		var feet := Vector2(bed_at.x + bed_size.x * 0.45, bed_at.y + 44.0)
		var bob := 0.0 if reduced_motion else roundf(2.0 * sin(now * 1.4))
		stamp(hero, feet + Vector2(-Hero.FEET.x, -Hero.FEET.y) * scale_factor + Vector2(scale_factor, scale_factor + bob), scale_factor, NIGHT_TINT)
	stamp(_bed, bed_at, TEXEL, NIGHT_TINT)
	if dozing:
		_draw_dozing(bed_at, bed_size, doze, scale_factor)
	# The bedside lamp with the tally slate, over on the right.
	var lamp_at := Vector2(1090.0, DESIGN.y - _lamp.get_height() * TEXEL - 6.0)
	for ring in 3:
		draw_circle(lamp_at + Vector2(52, 40), 60.0 + ring * 26.0, Color(1, 0.82, 0.5, 0.08 + (0.0 if reduced_motion else 0.02 * sin(now * 3.0))))
	ground_shadow(Vector2(lamp_at.x + 52.0, DESIGN.y - 4.0), Vector2(56, 10), 0.4)
	stamp(_lamp, lamp_at, TEXEL, NIGHT_TINT)
	plate(Rect2(lamp_at.x - 6.0, lamp_at.y + 80.0, 116, 34), Color("#2a2a32"), Color("#141418"))
	label(lamp_at + Vector2(52, 97), "%d 隻" % int(state.get("counted", 0)), 22, CREAM)


## The traveller nods off: a stream of Zzz pours up, then they roll out of bed
## onto the rug and lie there snoring.
func _draw_dozing(bed_at: Vector2, bed_size: Vector2, since: float, scale_factor: float) -> void:
	var roll := clampf((since - 0.4) / 0.5, 0.0, 1.0) if not reduced_motion else (1.0 if since > 0.4 else 0.0)
	var start := Vector2(bed_at.x + bed_size.x * 0.45, bed_at.y + 44.0)
	# Off the front of the bed onto the rug, lying in plain view.
	var floor_spot := Vector2(bed_at.x + bed_size.x * 0.62, DESIGN.y - 44.0)
	var at := start.lerp(floor_spot, roll) + Vector2(0, -sin(roll * PI) * 50.0)
	var hero := Hero.texture(&"idle", true, "sorry")
	draw_set_transform(at, roll * PI * 0.5 + (0.0 if roll >= 1.0 else roll * TAU), Vector2.ONE)
	stamp(hero, Vector2(-Hero.FEET.x, -Hero.FEET.y) * scale_factor + Vector2(scale_factor, scale_factor), scale_factor, NIGHT_TINT)
	draw_set_transform(Vector2.ZERO)
	for z in 7:
		var rise := fposmod(since * 0.9 + z / 7.0, 1.0) if not reduced_motion else z / 7.0
		var spot := at + Vector2(20.0 + z * 14.0 + rise * 60.0, -80.0 - rise * 200.0)
		label(spot, "Z", 18 + z * 3, Color("#d8d2ff"), 1.0, 1.0 - rise * 0.8)


# --- Texel painters ---------------------------------------------------------------

## The view out of the window: a deep sky with a moon, far blue hills, then a
## dark meadow rolling down to the grass.
func _paint_sky(x: int, y: int, size: Vector2i) -> Color:
	var down := float(y) / size.y
	var moon := Vector2(x - size.x * 0.82, y - size.y * 0.2).length()
	if moon < 9.0:
		return Color("#fff2c4").darkened(0.1 if Pixels.noise(x / 2, y / 2, 3) > 0.75 else 0.0)
	var sky := Color("#1a1e46").lerp(Color("#3e4380"), down / 0.6)
	if moon < 16.0:
		sky = sky.lerp(Color("#fff2c4"), 0.22 * (16.0 - moon) / 7.0)
	var far := size.y * 0.5 + 6.0 * sin(x * 0.05) + 4.0 * sin(x * 0.13 + 1.5)
	if y > far:
		sky = Color("#2a3460").lerp(Color("#232c50"), Pixels.noise(x / 4, y / 4, 6) * 0.5)
	var meadow := size.y * 0.66 + 3.0 * sin(x * 0.08 + 2.0)
	# Dark fir trees along the meadow's far edge, lit faintly on the moon side.
	var tree := posmod(x, 32)
	var tall := 26 + (x / 32) % 3 * 5
	var spread := (y - (meadow - tall)) * 0.42
	if y < meadow + 2 and y > meadow - tall and absf(tree - 16.0) < spread and (y - int(meadow - tall)) % 5 != 0:
		return Pixels.lit(Color("#1e3044"), 0.4 if tree > 16 else -0.3, x, y)
	if y > meadow:
		var depth := (y - meadow) / (size.y - meadow)
		sky = Color("#26443a").lerp(Color("#34583f"), depth)
		if Pixels.noise(x, y / 2, 9) > 0.82:
			sky = sky.lightened(0.08)
	return sky


## A woolly sheep running right: a cloud of curls lit from the upper left, a
## dark face and ears, thin dark legs (tucked up mid-leap on frame 1).
func _paint_sheep(x: int, y: int, frame: int) -> Color:
	var wool := Vector2((x + 0.5 - 10.0) / 8.5, (y + 0.5 - 6.0) / 5.0)
	var face := Vector2((x + 0.5 - 18.5) / 2.8, (y + 0.5 - 6.0) / 3.0)
	if face.length() <= 1.0:
		if y == 5 and x == 19:
			return Color("#f4ecd8")
		return Pixels.lit(Color("#3a3040"), 0.4 - face.y * 0.5, x, y)
	if y == 3 and x >= 16 and x <= 17:
		return Color("#3a3040")
	if y >= 10:
		var legs: Array = [5, 8, 12, 15] if frame == 0 else [6, 7, 13, 14]
		var reach := 14 if frame == 0 else 11
		if x in legs and y <= reach:
			return Color("#3a3040")
		return Pixels.CLEAR
	if wool.length() > 1.0 + 0.12 * sin(x * 2.1 + y):
		return Pixels.CLEAR
	var curl := posmod(x + (y % 2) * 2, 3) == 0
	return Pixels.lit(Color("#f4f0ff"), 0.6 - wool.y * 0.7 - wool.x * 0.2 - (0.35 if curl else 0.0), x, y)


## A ghost sheep: the same woolly shape but pale lilac, no legs, a wavy hem.
func _paint_ghost_sheep(x: int, y: int) -> Color:
	var wool := Vector2((x + 0.5 - 10.0) / 8.5, (y + 0.5 - 6.0) / 5.0)
	var face := Vector2((x + 0.5 - 18.5) / 2.8, (y + 0.5 - 6.0) / 3.0)
	if face.length() <= 1.0:
		if y == 5 and (x == 18 or x == 20):
			return Color("#2a2440")
		return Pixels.lit(Color("#dcd6ff"), 0.4, x, y)
	if y >= 10:
		if y <= 11 and posmod(x, 3) != 0 and x >= 3 and x <= 16:
			return Color("#dcd6ff")
		return Pixels.CLEAR
	if wool.length() > 1.0 + 0.12 * sin(x * 2.1 + y):
		return Pixels.CLEAR
	return Pixels.lit(Color("#eeeaff"), 0.5 - wool.y * 0.6, x, y)


## A weathered wooden fence: two posts and three rails.
func _paint_fence(x: int, y: int) -> Color:
	var wood := Color("#8a6a4a")
	if (x <= 2 or x >= 27) and y <= 15:
		return Pixels.lit(wood, 0.5 if x <= 1 or x == 27 else -0.4, x, y)
	if y in [3, 4, 8, 9, 13]:
		return Pixels.wood(wood.lightened(0.05) if y != 4 and y != 9 else wood.darkened(0.2), x, y, 6, false)
	return Pixels.CLEAR


## The bed: a carved footboard and a plum quilt with stitched patches.
func _paint_bed(x: int, y: int) -> Color:
	var wood := Color("#6a4058")
	if y < 4:
		if x < 3 or x > 66:
			return Pixels.lit(wood, 0.5 if x < 3 else -0.4, x, y)
		return Pixels.CLEAR
	if y > 25:
		return Pixels.wood(wood.darkened(0.2), x, y, 9, false)
	if x < 3 or x > 66:
		return Pixels.lit(wood, 0.5 if x < 3 else -0.4, x, y)
	if (x - 3) % 9 == 0 or (y - 4) % 7 == 0:
		return QUILT.darkened(0.35)
	var patch := ((x - 3) / 9 + (y - 4) / 7) % 2 == 0
	return Pixels.lit(QUILT.lightened(0.12) if patch else QUILT, 0.6 - (y - 4) * 0.06, x, y)


## A bedside table with a fringed lamp and a little chalk slate leaning on it.
func _paint_lamp(x: int, y: int) -> Color:
	if y < 10:
		var half := 5.0 + y * 0.6
		if absf(x + 0.5 - 13.0) > half:
			return Pixels.CLEAR
		if y == 9 and x % 2 == 0:
			return Color("#d9a64e")
		return Pixels.lit(Color("#f0c27a"), 0.6 - y * 0.08 - (x - 13) * 0.04, x, y)
	if y < 18:
		return Color("#d9a64e") if absi(x - 13) <= 1 else Pixels.CLEAR
	if y < 20:
		return Pixels.wood(Color("#7a4a3a").lightened(0.15), x, y, 8, false)
	if x < 2 or x > 23:
		return Pixels.lit(Color("#7a4a3a"), 0.4 if x < 2 else -0.4, x, y)
	return Pixels.wood(Color("#7a4a3a"), x, y, 6, true)
