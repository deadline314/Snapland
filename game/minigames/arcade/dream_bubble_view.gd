extends "res://game/minigames/arcade/arcade_view.gd"
## Picture for 夢泡搬運: the hotel hall at night (hotel_backdrop) seen as a
## corridor: a carved ceiling beam with cracks overhead, a plum carpet runner
## underfoot, the dream-room door puffing lilac clouds on the left and the
## delivery door with its brass slot on the right. The traveller walks with a
## big iridescent bubble on their head, a sleeping sheep and stars inside it,
## tipping with every start and stop. Drops swell and fall from the cracks,
## chandeliers swing on their chains, vents puff steam. A popped bubble drops
## its woolly sheep onto the traveller's head. Every object is baked pixel art.

const Hero = preload("res://game/minigames/arcade/arcade_hero.gd")
const Hotel = preload("res://game/minigames/arcade/hotel_backdrop.gd")
const FLOOR_Y := 612.0
const CEILING_Y := 168.0
const HEAD_Y := 486.0
const HERO_SCALE := 2.7
const START_PX := 190.0
const END_PX := 1090.0
const BEAM := Color("#4a3046")
const WATER := Color("#9fd8f0")
const BRASS := Color("#d9a64e")
const DOOR_WOOD := Color("#6a4058")
const CLOUD := Color("#d8ccff")
const NIGHT_TINT := Color(0.95, 0.94, 1.04)

var _door: ImageTexture
var _lamp: ImageTexture
var _vent: ImageTexture
var _drop: ImageTexture
var _sheep: ImageTexture
var _bubbles: Dictionary = {}


func _init() -> void:
	super()
	word_anchor = Vector2(640, 236)


func _ready() -> void:
	_door = Pixels.bake("db-door", Vector2i(32, 58), _paint_door)
	_lamp = Pixels.bake("db-lamp", Vector2i(17, 11), _paint_lamp)
	_vent = Pixels.bake("db-vent", Vector2i(22, 4), _paint_vent)
	_drop = Pixels.bake("db-drop", Vector2i(5, 7), _paint_drop)
	_sheep = Pixels.bake("db-sheep", Vector2i(16, 12), _paint_sheep)


func _draw_backdrop() -> void:
	Hotel.draw(self, now, reduced_motion)
	stage_floor(FLOOR_Y, Color("#7a5040"), Color("#3a2430"))
	panel(Rect2(-8, FLOOR_Y + 18.0, DESIGN.x + 16.0, 64), "velvet", Color("#5a2f4e"), Color(0, 0, 0, 0))
	draw_rect(Rect2(0, FLOOR_Y + 22.0, DESIGN.x, 4), Color("#c9953e"))
	draw_rect(Rect2(0, FLOOR_Y + 74.0, DESIGN.x, 4), Color("#8a6030"))
	vignette(0.3)


func _draw_scene() -> void:
	if not state.has("walker"):
		return
	_draw_beam()
	_draw_doors()
	for hazard: Dictionary in state.get("hazards", []):
		match str(hazard.kind):
			"vent":
				_draw_vent(hazard)
			"lamp":
				_draw_lamp(hazard)
	_draw_hero()
	for hazard: Dictionary in state.get("hazards", []):
		if str(hazard.kind) == "drip":
			_draw_drip(hazard)
	_draw_delivery()
	label(Vector2(1110, 200), "第 %d 顆夢" % (int(state.get("delivered", 0)) + 1), 22, CREAM)


# --- The corridor ------------------------------------------------------------------

func _draw_beam() -> void:
	draw_rect(Rect2(0, CEILING_Y - 4.0, DESIGN.x, 10), Color(Props.SHADOW, 0.35))
	panel(Rect2(-8, CEILING_Y - 30.0, DESIGN.x + 16.0, 30), "planks", BEAM)
	draw_rect(Rect2(0, CEILING_Y - 2.0, DESIGN.x, 4), BEAM.darkened(0.5))


func _draw_doors() -> void:
	var size := Vector2(_door.get_size()) * TEXEL
	for side in 2:
		var x := 60.0 if side == 0 else DESIGN.x - 60.0 - size.x
		var at := Vector2(x, FLOOR_Y - size.y)
		cast_shadow(_door, at, Vector2(8, 4), TEXEL, 0.35)
		stamp(_door, at, TEXEL, NIGHT_TINT)
		var sign_rect := Rect2(at.x + size.x * 0.5 - 40.0, at.y + 34.0, 80, 28)
		plate(sign_rect, Color("#c9953e"), Color("#8a6030"))
		label(sign_rect.get_center() + Vector2(0, 1), "夢境房" if side == 0 else "收件處", 16, GOLD)
		if side == 0:
			# Lilac dream clouds curling out under the door.
			for puff in 5:
				var drift := 0.0 if reduced_motion else fposmod(now * 14.0 + puff * 23.0, 60.0)
				var c := Vector2(at.x + size.x - 10.0 + drift, FLOOR_Y - 18.0 - puff % 3 * 10.0 - drift * 0.4)
				draw_circle(c, 14.0 - drift * 0.12, Color(CLOUD, 0.35 * (1.0 - drift / 60.0)))
		else:
			# The brass delivery slot.
			draw_rect(Rect2(at.x + size.x * 0.5 - 30.0, at.y + 120.0, 60, 14), Color("#8a6030"))
			draw_rect(Rect2(at.x + size.x * 0.5 - 26.0, at.y + 124.0, 52, 6), Color("#1d1420"))


func _draw_drip(hazard: Dictionary) -> void:
	var x := float(hazard.x)
	# The crack in the beam, dark and damp.
	draw_rect(Rect2(x - 10.0, CEILING_Y - 8.0, 20, 6), Color("#2a1a24"))
	draw_rect(Rect2(x - 2.0, CEILING_Y - 20.0, 4, 14), Color("#2a1a24"))
	var period := float(hazard.period)
	var t := fposmod(now + float(hazard.phase), period)
	var swell_time := float(state.get("drip_swell", 0.75))
	var fall_time := float(state.get("drip_fall", 0.36))
	var size := Vector2(_drop.get_size()) * TEXEL
	if t < swell_time:
		var grow := t / swell_time
		var scale_factor := TEXEL * (0.4 + 0.6 * grow)
		stamp(_drop, Vector2(x - size.x * 0.5 * (scale_factor / TEXEL), CEILING_Y), scale_factor, NIGHT_TINT)
	elif t < swell_time + fall_time:
		var fall := (t - swell_time) / fall_time
		var y := lerpf(CEILING_Y + 12.0, FLOOR_Y, fall * fall)
		stamp(_drop, Vector2(x - size.x * 0.5, y - size.y * 0.5), TEXEL, NIGHT_TINT)
	elif t < swell_time + fall_time + 0.3:
		var splash := (t - swell_time - fall_time) / 0.3
		for bead in 4:
			var dir := Vector2.from_angle(PI + bead * PI / 3.0 + PI / 6.0)
			draw_rect(Rect2(Vector2(x, FLOOR_Y - 4.0) + dir * splash * 26.0, Vector2(4, 4)), Color(WATER, 1.0 - splash))
	# A little puddle under every crack.
	draw_rect(Rect2(x - 22.0, FLOOR_Y + 2.0, 44, 4), Color(WATER, 0.35))


func _draw_lamp(hazard: Dictionary) -> void:
	var length := 200.0
	var angle := 0.5 * sin(TAU * (now + float(hazard.phase)) / float(hazard.period))
	var pivot := Vector2(float(hazard.x), CEILING_Y)
	var bob := pivot + Vector2(sin(angle), cos(angle)) * length
	# Chain links down to the chandelier.
	for link in 16:
		var at := pivot.lerp(bob, link / 16.0)
		draw_rect(Rect2(at - Vector2(3, 3), Vector2(6, 8)), BRASS.darkened(0.3 if link % 2 == 0 else 0.0))
	var flicker := 1.0 if reduced_motion else 0.85 + 0.15 * sin(now * 9.0 + float(hazard.x))
	for ring in 3:
		draw_circle(bob, (40.0 + ring * 18.0) * flicker, Color(1.0, 0.82, 0.5, 0.1))
	var size := Vector2(_lamp.get_size()) * 5.5
	draw_set_transform(bob, -angle, Vector2.ONE)
	draw_texture_rect(_lamp, Rect2(Vector2(-size.x * 0.5, -size.y * 0.45), size), false, NIGHT_TINT)
	draw_set_transform(Vector2.ZERO)


func _draw_vent(hazard: Dictionary) -> void:
	var x := float(hazard.x)
	var size := Vector2(_vent.get_size()) * TEXEL
	stamp(_vent, Vector2(x - size.x * 0.5, FLOOR_Y + 2.0), TEXEL, NIGHT_TINT)
	var t := fposmod(now + float(hazard.phase), float(hazard.period))
	var puff_time := float(state.get("vent_puff", 0.8))
	var push := float(hazard.push)
	if t < puff_time:
		var strength := sin(t / puff_time * PI)
		for wisp in 6:
			var rise := fposmod(t * 2.0 + wisp / 6.0, 1.0) if not reduced_motion else wisp / 6.0
			var at := Vector2(x + push * rise * 90.0 + (wisp - 2.5) * 12.0, FLOOR_Y - rise * 260.0)
			draw_circle(at, 12.0 + rise * 18.0, Color(CREAM, 0.3 * strength * (1.0 - rise)))
		label(Vector2(x + push * 60.0, FLOOR_Y - 150.0), "→" if push > 0.0 else "←", 30, Color(CREAM, 0.7 * strength))


# --- The traveller and the bubble -----------------------------------------------------

func _hero_x() -> float:
	var x := float(state.get("walker_px", START_PX))
	var walk_in := age(float(state.get("walk_in_at", -99.0)))
	if walk_in >= 0.0 and walk_in < float(state.get("walk_in_seconds", 0.6)) and not reduced_motion:
		x = lerpf(START_PX - 110.0, START_PX, walk_in / float(state.get("walk_in_seconds", 0.6)))
	return x


func _draw_hero() -> void:
	var pop_since := age(float(state.get("pop_at", -99.0)))
	var popping := pop_since >= 0.0 and pop_since < float(state.get("pop_seconds", 1.8))
	var x := _hero_x()
	var speed := absf(float(state.get("speed", 0.0))) / maxf(0.01, float(state.get("walk_speed", 0.3)))
	var bob := 0.0 if reduced_motion else -absf(sin(float(state.get("step_phase", 0.0)) * 0.5 * PI)) * 7.0 * speed
	var feet := Vector2(x, FLOOR_Y + bob)
	ground_shadow(Vector2(x + 6.0, FLOOR_Y + 2.0), Vector2(56, 12), 0.42)
	var mood := "sorry" if popping and pop_since > 0.35 else ("shocked" if popping else ("plain" if absf(float(state.get("lean", 0.0))) < 0.6 else "shocked"))
	var stretch := Vector2.ONE
	if popping and pop_since > 0.35:
		stretch = Vector2(1.12, 0.86)
	var sprite := Hero.texture(&"up" if not popping else &"idle", true, mood)
	draw_set_transform(feet, 0.0, stretch)
	stamp(sprite, Vector2(-Hero.FEET.x, -Hero.FEET.y) * HERO_SCALE + Vector2(HERO_SCALE, HERO_SCALE), HERO_SCALE, NIGHT_TINT)
	draw_set_transform(Vector2.ZERO)
	var head := Vector2(x, HEAD_Y + bob)
	if popping:
		_draw_pop(head, pop_since)
		return
	var walk_in := age(float(state.get("walk_in_at", -99.0)))
	var grow := pop_in(walk_in, 0.35) if walk_in >= 0.0 and walk_in < 0.6 else 1.0
	_draw_bubble(head, float(state.get("radius", 40.0)) * grow, float(state.get("lean", 0.0)))


func _bubble_texture(radius: float) -> ImageTexture:
	var texels := int(round(radius / TEXEL))
	if not _bubbles.has(texels):
		_bubbles[texels] = Pixels.cached("db-bubble|%d" % texels, func() -> Image:
			var image := Image.create(texels * 2, texels * 2, false, Image.FORMAT_RGBA8)
			for y in texels * 2:
				for x in texels * 2:
					image.set_pixel(x, y, _paint_bubble(x, y, texels))
			return image)
	return _bubbles[texels]


func _draw_bubble(head: Vector2, radius: float, lean: float) -> void:
	if radius < 4.0:
		return
	var centre := Vector2(head.x + lean * radius * 0.9, head.y - radius + absf(lean) * radius * 0.25)
	var texture := _bubble_texture(radius)
	var size := Vector2(texture.get_size()) * TEXEL
	draw_set_transform(centre, lean * 0.5, Vector2.ONE)
	draw_texture_rect(texture, Rect2(-size * 0.5, size), false)
	# The sleeping sheep floating inside the dream, with a star or two.
	var sheep := Vector2(_sheep.get_size()) * TEXEL * clampf(radius / 70.0, 0.5, 1.0)
	var drift := 0.0 if reduced_motion else 4.0 * sin(now * 1.4)
	draw_texture_rect(_sheep, Rect2(Vector2(-sheep.x * 0.5, -sheep.y * 0.4 + drift), sheep), false, Color(1, 1, 1, 0.85))
	for star in 3:
		var at := Vector2.from_angle(star * 2.1 + (0.0 if reduced_motion else now * 0.4)) * radius * 0.6
		var twinkle := 1.0 if reduced_motion else 0.5 + 0.5 * sin(now * 3.0 + star)
		draw_rect(Rect2(at - Vector2(2, 2), Vector2(4, 4)), Color(1, 0.95, 0.7, twinkle))
	draw_set_transform(Vector2.ZERO)
	# A soft rim glint that stays on the lit side as it rolls.
	glint(centre + Vector2(-radius * 0.45, -radius * 0.45), radius * 0.25, 2.6, float(state.get("level", 0)))


## The bubble bursts into glints and its sheep tumbles onto the traveller's head.
func _draw_pop(head: Vector2, since: float) -> void:
	var radius := float(state.get("radius", 40.0))
	var centre := head + Vector2(0, -radius)
	if since < 0.4:
		var burst := since / 0.4
		for shard in 10:
			var dir := Vector2.from_angle(shard * TAU / 10.0)
			draw_rect(Rect2(centre + dir * radius * (1.0 + burst * 0.8) - Vector2(3, 3), Vector2(6, 6)), Color(CLOUD.lightened(0.3), 1.0 - burst))
	var fall := clampf(since / 0.35, 0.0, 1.0) if not reduced_motion else 1.0
	var size := Vector2(_sheep.get_size()) * TEXEL * 1.3
	var seat := head + Vector2(0, -size.y * 0.55 + 8.0)
	var at := centre.lerp(seat, fall * fall)
	var squish := squash(since - 0.35, 0.3, 0.35)
	draw_set_transform(at, 0.0 if reduced_motion else 0.08 * sin(since * 3.0), squish)
	draw_texture_rect(_sheep, Rect2(-size * 0.5, size), false, NIGHT_TINT)
	draw_set_transform(Vector2.ZERO)
	if since > 0.5:
		label(seat + Vector2(size.x * 0.6, -size.y * 0.7 - (0.0 if reduced_motion else 6.0 * sin(since * 2.0))), "Zzz", 22, Color("#d8d2ff"))


## A delivered dream floats into the slot of the delivery door.
func _draw_delivery() -> void:
	var since := age(float(state.get("deliver_at", -99.0)))
	if since < 0.0 or since > 0.7:
		return
	var t := since / 0.7
	var slot := Vector2(DESIGN.x - 60.0 - _door.get_width() * TEXEL * 0.5 + 4.0, FLOOR_Y - _door.get_height() * TEXEL + 128.0)
	var from := Vector2(END_PX, HEAD_Y - 60.0)
	var at := from.lerp(slot, t) + Vector2(0, -sin(t * PI) * 60.0)
	var radius := 40.0 * (1.0 - t * 0.85)
	var texture := _bubble_texture(maxf(8.0, radius))
	var size := Vector2(texture.get_size()) * TEXEL
	draw_texture_rect(texture, Rect2(at - size * 0.5, size), false, Color(1, 1, 1, 1.0 - t * 0.5))


# --- Texel painters ---------------------------------------------------------------

## A dream bubble: a thin bright rim, a faint lilac skin with a pink-and-teal
## sheen down one side and two highlight spots at the top left. Translucent.
func _paint_bubble(x: int, y: int, texels: int) -> Color:
	var at := Vector2(x + 0.5 - texels, y + 0.5 - texels)
	var r := at.length() / texels
	if r > 1.0:
		return Color(0, 0, 0, 0)
	var spot := at / texels
	if spot.distance_to(Vector2(-0.45, -0.45)) < 0.16 or spot.distance_to(Vector2(-0.22, -0.62)) < 0.07:
		return Color(1, 1, 1, 0.9)
	if r > 0.9:
		return Color(0.95, 0.92, 1.0, 0.85)
	if r > 0.78:
		var band := spot.x * 0.7 + spot.y * 0.3
		return Color("#f2a7c4").lerp(Color("#9fe0e0"), clampf(band + 0.5, 0.0, 1.0)) * Color(1, 1, 1, 0.55)
	return Color(0.85, 0.8, 1.0, 0.16 + 0.1 * r)


## A plain arched door with a lit frame, two panels and a brass knob.
func _paint_door(x: int, y: int) -> Color:
	var arch := Vector2(x + 0.5 - 16.0, y + 0.5 - 16.0)
	if y < 16 and arch.length() > 16.0:
		return Pixels.CLEAR
	if (y < 16 and arch.length() > 14.0) or x < 2 or x > 29:
		return Pixels.lit(Color("#e8dcc4"), 0.5 if x < 16 else -0.5, x, y)
	if Vector2(x - 25.5, y - 34.5).length() < 1.6:
		return Pixels.rounded(BRASS, Vector2(x - 25.5, y - 34.5) / 1.6)
	for panel_rect: Rect2i in [Rect2i(6, 20, 20, 12), Rect2i(6, 38, 20, 16)]:
		if panel_rect.has_point(Vector2i(x, y)):
			if y == panel_rect.position.y or x == panel_rect.position.x:
				return DOOR_WOOD.darkened(0.35)
			if y == panel_rect.end.y - 1 or x == panel_rect.end.x - 1:
				return DOOR_WOOD.lightened(0.25)
			return Pixels.wood(DOOR_WOOD.lightened(0.05), x, y, 7, true)
	return Pixels.wood(DOOR_WOOD, x, y, 8, true)


## A brass chandelier: a bowl with three cream candles and drops beneath.
func _paint_lamp(x: int, y: int) -> Color:
	if y < 4:
		for candle: int in [3, 8, 13]:
			if absi(x - candle) <= 0 and y >= 1:
				return Pixels.lit(Color("#f4ecd8"), 0.4, x, y)
			if x == candle and y == 0:
				return Color("#ffd98a")
		return Pixels.CLEAR
	var half := 8.5 - (y - 4) * 0.9
	if absf(x + 0.5 - 8.5) > half:
		return Pixels.CLEAR
	if y == 4:
		return BRASS.lightened(0.2)
	if y >= 8 and posmod(x, 3) == 1:
		return Color("#c9b6ff")
	return Pixels.lit(BRASS, 0.5 - (y - 4) * 0.3 - (x - 8) * 0.05, x, y)


## A brass floor grille.
func _paint_vent(x: int, y: int) -> Color:
	if y == 0:
		return BRASS.lightened(0.15)
	if posmod(x, 3) == 0:
		return BRASS.darkened(0.15)
	return Color("#1d1420")


## A water drop, round at the bottom with a point at the top.
func _paint_drop(x: int, y: int) -> Color:
	var half: float = [0.5, 1.0, 1.5, 2.2, 2.5, 2.4, 1.6][y]
	if absf(x + 0.5 - 2.5) > half:
		return Pixels.CLEAR
	if x == 1 and y == 3:
		return Color(1, 1, 1)
	return Pixels.lit(WATER, 0.3 - y * 0.1, x, y)


## A woolly sheep asleep: a cloud of curls, a dark face with closed eyes, legs.
func _paint_sheep(x: int, y: int) -> Color:
	var wool := Vector2((x + 0.5 - 9.0) / 6.5, (y + 0.5 - 5.0) / 4.5)
	var face := Vector2((x + 0.5 - 3.0) / 2.6, (y + 0.5 - 5.5) / 2.6)
	if face.length() <= 1.0:
		if y == 5 and (x == 2 or x == 4):
			return Color("#f4ecd8")
		return Pixels.lit(Color("#4a3a4a"), 0.4 - face.y * 0.4, x, y)
	if y >= 9 and (x == 6 or x == 7 or x == 11 or x == 12):
		return Color("#4a3a4a")
	if wool.length() > 1.0:
		return Pixels.CLEAR
	var curl := posmod(x + (y % 2) * 2, 4) == 0
	return Pixels.lit(Color("#f4f0ff"), 0.6 - wool.y * 0.6 - (0.35 if curl else 0.0), x, y)
