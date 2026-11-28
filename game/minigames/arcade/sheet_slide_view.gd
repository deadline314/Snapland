extends "res://game/minigames/arcade/arcade_view.gd"
## Picture for 被單滑梯: the hotel hall at night (hotel_backdrop) with a long
## pinstriped bedsheet slide running away from the camera, down from a big
## bed into the moonlit dark. The slide is drawn row by row in perspective with
## rose-piped hems and gentle bends; sleeping cats, fluffy pillows and
## patchwork blanket forts ride on it, scaled by distance. The traveller sits
## on a sheet corner seen from behind. A crash wraps them into a spring roll
## that rolls away down the slide. Every object is baked pixel art.

const Hero = preload("res://game/minigames/arcade/arcade_hero.gd")
const Hotel = preload("res://game/minigames/arcade/hotel_backdrop.gd")
## Far end of the slide on screen, the focal length and slide half-width.
const HORIZON := 330.0
const FOCAL := 360.0
const HALF_WIDTH := 560.0
const HERO_Z := 1.18
const FAR_Z := 14.0
const NEAR_Z := 0.95
const ROW := 4.0
const SHEET := Color("#efe6f4")
const SHEET_SHADE := Color("#d6c8e6")
const STRIPE := Color("#9c86c8")
const PIPING := Color("#e79bb6")
const BELOW := Color("#2a1d3c")
const MIST := Color("#8c7ab0")
const CAT_TONES: Array[Color] = [Color("#8e8ca0"), Color("#d98a4a"), Color("#4a4052")]
const QUILTS: Array[Color] = [Color("#5b3f74"), Color("#e79bb6"), Color("#4f8f86"), Color("#f2e3c6")]
const NIGHT_TINT := Color(0.95, 0.94, 1.05)

var _pillow: ImageTexture
var _cats: Array[ImageTexture] = []
var _fort: ImageTexture
var _sled: ImageTexture
var _rolls: Array[ImageTexture] = []


func _init() -> void:
	super()
	word_anchor = Vector2(990, 250)


func _ready() -> void:
	_pillow = Pixels.bake("ss-pillow", Vector2i(14, 9), _paint_pillow)
	for tone in CAT_TONES.size():
		for awake in 2:
			_cats.append(Pixels.bake("ss-cat|%d|%d" % [tone, awake], Vector2i(18, 12), _paint_cat.bind(CAT_TONES[tone], awake == 1)))
	_fort = Pixels.bake("ss-fort", Vector2i(30, 16), _paint_fort)
	_sled = Pixels.bake("ss-sled", Vector2i(24, 7), _paint_sled)
	for frame in 4:
		_rolls.append(Pixels.bake("ss-roll|%d" % frame, Vector2i(26, 10), _paint_roll.bind(frame)))


func _draw_backdrop() -> void:
	Hotel.draw(self, now, reduced_motion)


func _draw_scene() -> void:
	if not state.has("distance"):
		return
	_draw_slide()
	_draw_things()
	_draw_speed_lines()
	vignette(0.32)
	_draw_streak()


# --- Perspective -----------------------------------------------------------------

func _row_y(z: float) -> float:
	return HORIZON + FOCAL / z


func _half(z: float) -> float:
	return HALF_WIDTH / z


## Screen x of the slide's middle at depth `z`: the far end bends left and
## right as the slide winds; the stretch at the traveller stays straight.
func _centre(z: float) -> float:
	var ahead := maxf(0.0, z - HERO_Z)
	var bend := sin(float(state.get("distance", 0.0)) * 0.045 + 1.0)
	return 640.0 + bend * ahead * ahead * 3.2


func _screen(x: float, z: float) -> Vector2:
	return Vector2(_centre(z) + x * _half(z), _row_y(z))


func _depth(at: float) -> float:
	return at - float(state.get("distance", 0.0)) + HERO_Z


# --- The slide -------------------------------------------------------------------

func _draw_slide() -> void:
	var distance := float(state.get("distance", 0.0))
	var forts: Array = (state.get("things", []) as Array).filter(func(thing: Dictionary) -> bool: return str(thing.kind) == "fort")
	var fort := float(state.get("fort", 0.3))
	var fort_length := float(state.get("fort_length", 3.0))
	var edge := float(state.get("edge", 0.84))
	# The dark drop on either side and mist where the slide fades away.
	draw_rect(Rect2(0, HORIZON - 30.0, DESIGN.x, DESIGN.y - HORIZON + 30.0), BELOW)
	var y := _row_y(FAR_Z)
	while y < DESIGN.y:
		var z := FOCAL / (y + ROW * 0.5 - HORIZON)
		var d := distance + z - HERO_Z
		var half := _half(z)
		var cx := _centre(z)
		var near := clampf((z - 1.0) / (FAR_Z - 1.0), 0.0, 1.0)
		var fog := near * near
		# Faint carpet diamonds far below, drifting by more slowly.
		var carpet := posmod(int(floor(d * 0.5)) + int(floor((cx - 640.0) / 90.0)), 2) == 0
		draw_rect(Rect2(0, y, DESIGN.x, ROW), BELOW.lerp(MIST, fog * 0.7).lightened(0.04 if carpet else 0.0))
		# The sheet: bands every slide unit and pinstripes along it, piping at the hems.
		var band := posmod(int(floor(d)), 2) == 0
		var sheet := (SHEET if band else SHEET_SHADE).lerp(MIST, fog * 0.6)
		draw_rect(Rect2(cx - half, y, half * 2.0, ROW), sheet)
		for lane: float in [-0.7, -0.35, 0.35, 0.7]:
			draw_rect(Rect2(cx + lane * half - maxf(1.0, half * 0.015), y, maxf(2.0, half * 0.03), ROW), STRIPE.lerp(MIST, fog * 0.6))
		var piping := maxf(2.0, half * (1.0 - edge) * 0.6)
		for side: float in [-1.0, 1.0]:
			# A rolled hem: lit on its inner lip, deeper on the outer one.
			var left := cx - half if side < 0.0 else cx + half - piping
			draw_rect(Rect2(left, y, piping, ROW), PIPING.lerp(MIST, fog * 0.6).darkened(0.0 if side < 0.0 else 0.25))
			var lip := left + (piping * 0.6 if side < 0.0 else 0.0)
			draw_rect(Rect2(lip, y, maxf(2.0, piping * 0.4), ROW), PIPING.lightened(0.3).lerp(MIST, fog * 0.6))
		# The shade the slide throws on the drop beneath it.
		draw_rect(Rect2(cx + half, y + ROW * 0.5, maxf(4.0, half * 0.08), ROW), Color(0, 0, 0, 0.25 * (1.0 - fog)))
		# A blanket fort's patchwork ridge running down the middle.
		for thing: Dictionary in forts:
			var from := float(thing.at)
			if d >= from and d <= from + fort_length:
				var width := fort * half
				var patch := posmod(int(floor(d * 1.5)), QUILTS.size())
				var quilt := QUILTS[patch].lerp(MIST, fog * 0.5)
				draw_rect(Rect2(cx - width, y, width * 2.0, ROW), quilt.darkened(0.15))
				draw_rect(Rect2(cx - width * 0.7, y, width * 1.4, ROW), quilt)
				draw_rect(Rect2(cx - width * 0.25, y, width * 0.3, ROW), quilt.lightened(0.15))
				draw_rect(Rect2(cx + width, y, maxf(3.0, width * 0.15), ROW), Color(0, 0, 0, 0.18))
		y += ROW
	# Mist swallowing the far end of the slide, under the hall's carved
	# gallery balustrade.
	for band in 4:
		draw_rect(Rect2(0, _row_y(FAR_Z) - 6.0 + band * 6.0, DESIGN.x, 6), Color(MIST, 0.4 - band * 0.09))
	_draw_balustrade()


func _draw_balustrade() -> void:
	var top := HORIZON - 34.0
	var bottom := _row_y(FAR_Z) - 2.0
	draw_rect(Rect2(0, top, DESIGN.x, bottom - top), Color("#1d1430"))
	var post := Pixels.bake("ss-baluster", Vector2i(5, int((bottom - top - 20.0) / TEXEL)), _paint_baluster)
	var x := 6.0
	while x < DESIGN.x:
		stamp(post, Vector2(x, top + 10.0), TEXEL, NIGHT_TINT)
		x += 32.0
	panel(Rect2(-8, top, DESIGN.x + 16.0, 12), "planks", Color("#5a3a4e"))
	panel(Rect2(-8, bottom - 8.0, DESIGN.x + 16.0, 10), "planks", Color("#4a3046"))
	draw_rect(Rect2(0, bottom + 2.0, DESIGN.x, 6), Color(0, 0, 0, 0.3))


# --- Things on the slide -----------------------------------------------------------

func _draw_things() -> void:
	var drawn_hero := false
	var things: Array = state.get("things", [])
	var order: Array = things.duplicate()
	order.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.at) > float(b.at))
	for thing: Dictionary in order:
		var z := _depth(float(thing.at))
		if not drawn_hero and z < HERO_Z:
			_draw_hero()
			drawn_hero = true
		if z < NEAR_Z or z > FAR_Z:
			continue
		match str(thing.kind):
			"pillow":
				if not bool(thing.taken) or bool(thing.get("missed", false)):
					_draw_pillow(thing, z)
			"cat", "roller":
				if bool(thing.hit):
					_draw_startled(thing, z)
				elif not bool(thing.taken):
					_draw_cat(thing, z)
			"fort":
				_draw_fort_face(z)
	if not drawn_hero:
		_draw_hero()


func _sprite_at(texture: Texture2D, foot: Vector2, width_px: float, tint := NIGHT_TINT) -> void:
	var size := Vector2(texture.get_size()) * width_px / float(texture.get_width())
	draw_texture_rect(texture, Rect2(foot - Vector2(size.x * 0.5, size.y), size), false, tint)


func _fogged(z: float) -> Color:
	var near := clampf((z - 1.0) / (FAR_Z - 1.0), 0.0, 1.0)
	return NIGHT_TINT.lerp(MIST, near * near * 0.6)


func _draw_pillow(thing: Dictionary, z: float) -> void:
	var foot := _screen(float(thing.x), z)
	var width := 0.3 * _half(z)
	var bob := 0.0 if reduced_motion else absf(sin(now * 3.0 + float(thing.at))) * width * 0.06
	ground_shadow(foot + Vector2(width * 0.06, 0), Vector2(width * 0.45, width * 0.1), 0.3)
	_sprite_at(_pillow, foot - Vector2(0, bob), width, _fogged(z))


func _draw_cat(thing: Dictionary, z: float) -> void:
	var x := float(thing.x)
	var roll_at := float(thing.roll_at)
	var lead := float(state.get("roll_lead", 0.95))
	var roller := str(thing.kind) == "roller"
	var awake := false
	var spin := 0.0
	if roller:
		if roll_at >= 0.0:
			var t := clampf(age(roll_at) / float(state.get("roll_seconds", 0.38)), 0.0, 1.0)
			var eased := t * t * (3.0 - 2.0 * t)
			x = lerpf(float(thing.x), float(thing.to), eased)
			spin = 0.0 if reduced_motion else eased * TAU * signf(float(thing.to) - float(thing.x))
			awake = t < 1.0
		else:
			var until := (float(thing.at) - float(state.get("distance", 0.0))) / maxf(0.1, float(state.get("speed", 5.0)))
			awake = until <= lead + 0.5 and int(now * 6.0) % 2 == 0
	var tone := int(absf(float(thing.at)) * 7.0) % CAT_TONES.size()
	var texture := _cats[tone * 2 + (1 if awake else 0)]
	var foot := _screen(x, z)
	var width := 0.32 * _half(z)
	ground_shadow(foot + Vector2(width * 0.06, 0), Vector2(width * 0.48, width * 0.12), 0.36)
	if spin != 0.0:
		var size := Vector2(texture.get_size()) * width / float(texture.get_width())
		draw_set_transform(foot - Vector2(0, size.y * 0.5), spin, Vector2.ONE)
		draw_texture_rect(texture, Rect2(-size * 0.5, size), false, _fogged(z))
		draw_set_transform(Vector2.ZERO)
	else:
		_sprite_at(texture, foot, width, _fogged(z))
	if not awake and not roller and not reduced_motion and z < 7.0:
		label(foot + Vector2(width * 0.4, -width * (0.75 + 0.1 * pulse(0.6, float(thing.at)))), "z", int(clampf(width * 0.22, 12.0, 28.0)), Color("#d8d2ff"), 1.0, 0.85)
	elif roller and roll_at < 0.0 and awake:
		label(foot + Vector2(0, -width * 0.85), "！", int(clampf(width * 0.4, 22.0, 40.0)), GOLD)


## The cat that was hit leaps up and off the slide, wide awake.
func _draw_startled(thing: Dictionary, z: float) -> void:
	var since := age(float(state.get("wrap_at", -99.0)))
	if since < 0.0 or since > 0.6:
		return
	var t := since / 0.6
	var side := -1.0 if float(thing.x) > 0.0 else 1.0
	var width := 0.32 * _half(z)
	var foot := _screen(float(thing.x), z) + Vector2(side * t * width * 2.2, -sin(t * PI) * width * 1.2)
	var tone := int(absf(float(thing.at)) * 7.0) % CAT_TONES.size()
	_sprite_at(_cats[tone * 2 + 1], foot, width, Color(_fogged(z), 1.0 - t * t))
	label(foot + Vector2(0, -width * 0.9), "！", int(clampf(width * 0.4, 22.0, 40.0)), GOLD, 1.0, 1.0 - t)


func _draw_fort_face(z: float) -> void:
	var foot := _screen(0.0, z)
	var width := float(state.get("fort", 0.3)) * 2.2 * _half(z)
	ground_shadow(foot + Vector2(width * 0.05, 0), Vector2(width * 0.55, width * 0.08), 0.35)
	_sprite_at(_fort, foot, width, _fogged(z))


# --- The traveller ---------------------------------------------------------------

func _draw_hero() -> void:
	var since := age(float(state.get("wrap_at", -99.0)))
	var total := float(state.get("wrap_seconds", 1.8))
	var hero_y := _row_y(HERO_Z)
	if since >= 0.0 and since < total:
		_draw_wrap(since, total)
		return
	var x := _screen(float(state.get("hero_x", 0.0)), HERO_Z).x
	var drift := float(state.get("drift", 0.0))
	var lean := clampf(-drift * 0.12, -0.25, 0.25)
	var cheering := int(state.get("streak", 0)) >= 5 and int(now * 2.0) % 2 == 0
	var bob := 0.0 if reduced_motion else roundf(2.0 * sin(now * 18.0))
	var pop := pop_in(since - total, 0.3) if since >= total and since < total + 0.3 else 1.0
	ground_shadow(Vector2(x + 6.0, hero_y + 4.0), Vector2(70, 14), 0.4)
	var sled_width := 104.0
	_sprite_at(_sled, Vector2(x, hero_y + 10.0), sled_width)
	var sprite := Hero.texture(&"up" if cheering else &"idle", false)
	var scale_factor := 2.2
	draw_set_transform(Vector2(x, hero_y + bob), lean, Vector2.ONE * pop)
	stamp(sprite, Vector2(-Hero.FEET.x, -Hero.FEET.y) * scale_factor + Vector2(scale_factor, scale_factor), scale_factor, NIGHT_TINT)
	draw_set_transform(Vector2.ZERO)


## The sheet whips up round the traveller, then the spring roll tumbles away
## down the slide into the dark.
func _draw_wrap(since: float, total: float) -> void:
	var start := _screen(float(state.get("wrap_x", 0.0)), HERO_Z)
	var scale_factor := 2.6
	if since < 0.25:
		var sprite := Hero.texture(&"up", true, "shocked")
		draw_set_transform(start, 0.0, Vector2.ONE)
		stamp(sprite, Vector2(-Hero.FEET.x, -Hero.FEET.y) * scale_factor + Vector2(scale_factor, scale_factor), scale_factor, NIGHT_TINT)
		draw_set_transform(Vector2.ZERO)
		var wrap := since / 0.25 if not reduced_motion else 1.0
		for band in 3:
			var y := start.y - 20.0 - band * 34.0
			draw_rect(Rect2(start.x - 52.0 * wrap, y - 12.0, 104.0 * wrap, 24), SHEET_SHADE)
			draw_rect(Rect2(start.x - 52.0 * wrap, y - 12.0, 104.0 * wrap, 6), SHEET)
			draw_rect(Rect2(start.x - 52.0 * wrap, y + 6.0, 104.0 * wrap, 4), PIPING)
		dust_puffs(start, since, 80.0)
		return
	var t := clampf((since - 0.25) / (total - 0.45), 0.0, 1.0)
	var z := lerpf(HERO_Z, FAR_Z * 0.8, t * t)
	var foot := _screen(float(state.get("wrap_x", 0.0)) * (1.0 - t), z)
	var width := 260.0 * HERO_Z / z
	var frame := 0 if reduced_motion else int(since * 14.0) % _rolls.size()
	var roll := _rolls[frame]
	var size := Vector2(roll.get_size()) * width / float(roll.get_width())
	ground_shadow(foot + Vector2(6, 0), Vector2(width * 0.45, width * 0.07), 0.4)
	# The traveller's head pokes out of the left end of the roll.
	var head := Hero.texture(&"idle", true, "sorry")
	var head_scale := width / 110.0
	var head_at := foot + Vector2(-size.x * 0.5 - 10.0 * head_scale, -size.y * 0.5)
	draw_set_transform(head_at, -PI * 0.5, Vector2.ONE * head_scale)
	draw_texture_rect_region(head, Rect2(-24, -24, 42, 26), Rect2(0, 0, 42, 26), _fogged(z))
	draw_set_transform(Vector2.ZERO)
	draw_texture_rect(roll, Rect2(foot - Vector2(size.x * 0.5, size.y), size), false, _fogged(z))


func _draw_speed_lines() -> void:
	if reduced_motion or float(state.get("speed", 0.0)) < 6.5:
		return
	var strength := clampf((float(state.get("speed", 0.0)) - 6.5) / 3.0, 0.0, 1.0)
	for line in 10:
		var phase := fposmod(now * 2.2 + line * 0.37, 1.0)
		var side := -1.0 if line % 2 == 0 else 1.0
		var z := lerpf(6.0, 1.05, phase)
		var at := _screen(side * (1.05 + 0.1 * (line % 3)), z)
		draw_rect(Rect2(at.x - 2.0, at.y, 4, 26.0 * HERO_Z / z + 8.0), Color(1, 1, 1, 0.22 * strength * phase))


func _draw_streak() -> void:
	var streak := int(state.get("streak", 0))
	if streak >= 3:
		label(Vector2(1110, 430), "枕頭 × %d" % streak, 26, GOLD, 1.0 + 0.08 * pulse(2.0))


# --- Texel painters ---------------------------------------------------------------

## A plump pillow: a pale lilac case with rose piping, a button in the
## middle, tufted corners and a shaded underside.
func _paint_pillow(x: int, y: int) -> Color:
	var at := Vector2((x + 0.5) / 7.0 - 1.0, (y + 0.5) / 4.5 - 1.0)
	var waist := 1.0 - 0.18 * (1.0 - absf(at.x)) * (1.0 if absf(at.y) > 0.6 else 0.0)
	if absf(at.y) > waist or (absf(at.x) > 0.86 and absf(at.y) > 0.72):
		return Pixels.CLEAR
	if (x == 0 or x == 13) and (y == 1 or y == 7):
		return Color("#e79bb6")
	if x == 7 and y == 4:
		return Color("#9c86c8")
	if y == 8 or (absf(at.y) > 0.78 and y > 4):
		return Color("#c9b8e0")
	return Pixels.lit(Color("#f3ecfa"), 0.5 - at.y * 0.6 - absf(at.x) * 0.3, x, y)


## A cat curled asleep: a round body, its head tucked at the left with two
## ears, the tail wrapped round the front and stripes on the back; awake it
## opens its eyes and flicks its tail up.
func _paint_cat(x: int, y: int, tone: Color, awake: bool) -> Color:
	var body := Vector2((x + 0.5 - 10.0) / 7.5, (y + 0.5 - 7.5) / 4.5)
	var head := Vector2((x + 0.5 - 4.5) / 3.6, (y + 0.5 - 6.0) / 3.2)
	var ear := (y == 2 and (x == 2 or x == 6)) or (y == 3 and x >= 2 and x <= 6 and x != 4)
	var tail_y := 3 if awake else 10
	var tail := (y == 10 or y == 11) and x >= 6 and x <= 16 if not awake else (x >= 15 and x <= 16 and y >= tail_y and y <= 8)
	if not (body.length() <= 1.0 or head.length() <= 1.0 or ear or tail):
		return Pixels.CLEAR
	if head.length() <= 1.0:
		if y == 6 and (x == 3 or x == 6):
			return Color("#ffe27a") if awake else Color("#2a2232")
		if y == 7 and x == 4:
			return Color("#f2a7b8")
		return Pixels.lit(tone.lightened(0.08), 0.5 - head.y * 0.5, x, y)
	if ear:
		return tone.darkened(0.15) if y == 2 else Color("#f2a7b8")
	if tail and not (body.length() <= 1.0):
		return tone.darkened(0.12)
	if posmod(x, 3) == 0 and body.y < 0.2:
		return tone.darkened(0.22)
	return Pixels.lit(tone, 0.6 - body.y * 0.7 - body.x * 0.2, x, y)


## A fort of folded quilts seen from the front: four layers with stitching
## and rounded folds, and a little pillow on top.
func _paint_fort(x: int, y: int) -> Color:
	if y < 3:
		if x >= 11 and x <= 18:
			return Pixels.lit(Color("#f3ecfa"), 0.4 - y * 0.4, x, y)
		return Pixels.CLEAR
	var layer := (y - 3) / 3
	var inside := y - 3 - layer * 3
	var inset := 2 - layer / 2
	if x < inset or x >= 30 - inset:
		return Pixels.CLEAR
	var quilt := QUILTS[layer % QUILTS.size()]
	if inside == 1 and posmod(x, 3) == 0:
		return quilt.lightened(0.35)
	if inside == 2:
		return quilt.darkened(0.3)
	return Pixels.lit(quilt, 0.5 - inside * 0.4, x, y)


## The sheet corner the traveller sits on, wrinkled and piped.
func _paint_sled(x: int, y: int) -> Color:
	var taper := absf(x + 0.5 - 12.0) / 12.0
	if y < 2 and taper > 0.7:
		return Pixels.CLEAR
	if y == 6:
		return PIPING.darkened(0.1)
	if posmod(x + y, 7) == 0:
		return SHEET_SHADE.darkened(0.08)
	return Pixels.lit(SHEET, 0.4 - y * 0.15 - taper * 0.3, x, y)


## The spring roll: a cylinder of pinstriped sheet whose stripes slide round
## as it rolls, with a rose hem at the right end.
func _paint_roll(x: int, y: int, frame: int) -> Color:
	var across := (y + 0.5) / 5.0 - 1.0
	if absf(across) > 1.0:
		return Pixels.CLEAR
	if x >= 23:
		return Pixels.lit(PIPING, 0.4 - across * 0.8, x, y)
	if posmod(y + frame * 2 + x / 6, 5) == 0:
		return STRIPE
	return Pixels.lit(SHEET, 0.5 - across * 0.9, x, y)


## A turned baluster: a bulb near the foot, a slim neck and a collar.
func _paint_baluster(x: int, y: int) -> Color:
	var rows := 9.0
	var t := float(y) / maxf(1.0, rows)
	var half := 1.0 if t < 0.15 else (2.4 if t > 0.55 and t < 0.85 else 1.4)
	if absf(x + 0.5 - 2.5) > half:
		return Pixels.CLEAR
	return Pixels.lit(Color("#6a4058"), 0.6 - (x - 2.0) * 0.35, x, y)
