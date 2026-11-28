extends "res://game/minigames/arcade/arcade_view.gd"
## Picture for 回聲鑰匙: the hotel hall at night (hotel_backdrop) with an arched
## guest-room door standing on a plum carpet runner. On the door a round brass
## lock plate holds nested bronze rings, each with one glowing notch; the key
## hangs from the keyhole at the top and its bit rests on the ring it is
## working. An echo ripples out of the keyhole as the notch comes round. The
## traveller waits on the left, the hotel ghost hovers on the right with a
## lantern. An opened door swings onto a warm room; a wrong turn swings it onto
## a broom cupboard whose brooms bury the traveller. Every object is baked
## pixel art.

const Hero = preload("res://game/minigames/arcade/arcade_hero.gd")
const Hotel = preload("res://game/minigames/arcade/hotel_backdrop.gd")
const FLOOR_Y := 612.0
const DOOR_RECT := Rect2(480, 180, 320, 432)
const LOCK := Vector2(640, 404)
const PLATE := 34
const RING_OUTER := 31
const RING_STEP := 5
const RING_WIDTH := 4
const NOTCH_DEGREES := 14.0
const HERO_FEET := Vector2(290, 640)
const HERO_SCALE := 3.0
const GHOST_AT := Vector2(1000, 380)
const BRONZE := Color("#b07a3a")
const BRASS := Color("#d9a64e")
const ECHO := Color("#c9b6ff")
const DOOR_WOOD := Color("#6a4058")
const FRAME := Color("#e8dcc4")
const CARPET := Color("#5a2f4e")
const NIGHT_TINT := Color(0.95, 0.94, 1.04)
const BROOM_COUNT := 9
const RINGS_MAX := 5

var _door: ImageTexture
var _plate: ImageTexture
var _rings: Array[ImageTexture] = []
var _key: ImageTexture
var _broom: ImageTexture
var _bucket: ImageTexture
var _lantern: ImageTexture


func _init() -> void:
	super()
	word_anchor = Vector2(980, 236)


func _ready() -> void:
	_door = Pixels.bake("ek-door", Vector2i(80, 108), _paint_door)
	_plate = Pixels.bake("ek-plate", Vector2i(PLATE * 2, PLATE * 2), _paint_plate)
	for index in RINGS_MAX:
		var outer := RING_OUTER - index * RING_STEP
		_rings.append(Pixels.bake("ek-ring|%d" % outer, Vector2i(outer * 2, outer * 2), _paint_ring.bind(outer)))
	_key = Pixels.bake("ek-key", Vector2i(13, 12), _paint_key)
	_broom = Pixels.bake("ek-broom", Vector2i(7, 34), _paint_broom)
	_bucket = Pixels.bake("ek-bucket", Vector2i(12, 11), _paint_bucket)
	_lantern = Pixels.bake("ek-lantern", Vector2i(9, 13), _paint_lantern)


func _draw_backdrop() -> void:
	Hotel.draw(self, now, reduced_motion)
	stage_floor(FLOOR_Y, Color("#7a5040"), Color("#3a2430"))
	# A plum carpet runner along the corridor with gold borders.
	panel(Rect2(-8, FLOOR_Y + 18.0, DESIGN.x + 16.0, 64), "velvet", CARPET, Color(0, 0, 0, 0))
	draw_rect(Rect2(0, FLOOR_Y + 22.0, DESIGN.x, 4), Color("#c9953e"))
	draw_rect(Rect2(0, FLOOR_Y + 74.0, DESIGN.x, 4), Color("#8a6030"))
	vignette(0.3)


func _draw_scene() -> void:
	if not state.has("rings"):
		return
	var broom_since := age(float(state.get("broom_at", -99.0)))
	var brooming := broom_since >= 0.0 and broom_since < float(state.get("broom_seconds", 1.7))
	var open_since := age(float(state.get("open_at", -99.0)))
	var opening := open_since >= 0.0 and open_since < float(state.get("open_seconds", 1.0))
	_draw_door(broom_since if brooming else -1.0, open_since if opening else -1.0)
	_draw_ghost(brooming, opening)
	_draw_hero(broom_since if brooming else -1.0, opening)
	if brooming:
		_draw_brooms(broom_since)
	_draw_streak()


# --- The door and its lock -------------------------------------------------------

func _draw_door(broom_since: float, open_since: float) -> void:
	# The door frame and room plate stay put; the leaf swings.
	var frame := DOOR_RECT.grow(10.0)
	draw_rect(Rect2(frame.position + Vector2(10, 12), frame.size), Color(Props.SHADOW, 0.35))
	panel(Rect2(frame.position.x, frame.position.y, frame.size.x, frame.size.y + 2.0), "planks_v", FRAME.darkened(0.45))
	var swing := 0.0
	var inside := ""
	if broom_since >= 0.0:
		inside = "cupboard"
		swing = _swing(broom_since, float(state.get("broom_seconds", 1.7)))
	elif open_since >= 0.0:
		inside = "room"
		swing = _swing(open_since, float(state.get("open_seconds", 1.0)))
	if swing > 0.0:
		_draw_inside(inside)
	var width := DOOR_RECT.size.x * (1.0 - 0.85 * swing)
	var leaf := Rect2(DOOR_RECT.position, Vector2(width, DOOR_RECT.size.y))
	draw_texture_rect(_door, leaf, false, NIGHT_TINT.darkened(0.25 * swing))
	if swing <= 0.0:
		_draw_lock()
	# The brass room-number plate on the arch.
	var plate_rect := Rect2(LOCK.x - 44.0, DOOR_RECT.position.y + 34.0, 88, 30)
	plate(plate_rect, Color("#c9953e"), Color("#8a6030"))
	label(plate_rect.get_center() + Vector2(0, 1), "%d" % (300 + int(state.get("door", 1))), 20, GOLD)


func _swing(since: float, total: float) -> float:
	if reduced_motion:
		return 1.0 if since < total - 0.15 else 0.0
	if since < 0.22:
		return since / 0.22
	if since > total - 0.25:
		return clampf((total - since) / 0.25, 0.0, 1.0)
	return 1.0


func _draw_inside(kind: String) -> void:
	var hole := DOOR_RECT.grow(-2.0)
	if kind == "room":
		# A warm guest room: lamplight, a quilt-topped bed and a window of stars.
		draw_rect(hole, Color("#e8a46a"))
		var stripe := hole.position.x
		while stripe < hole.end.x:
			draw_rect(Rect2(stripe, hole.position.y, 10, hole.size.y), Color("#f2b88a"))
			draw_rect(Rect2(stripe + 22.0, hole.position.y, 2, hole.size.y), Color("#c97a4a"))
			stripe += 36.0
		draw_rect(Rect2(hole.position.x, hole.end.y - 44.0, hole.size.x, 44), Color("#8a4a3a"))
		panel(Rect2(hole.position.x + 70.0, hole.end.y - 34.0, 180, 26), "velvet", Color("#4f8f86"))
		for glow in 4:
			draw_circle(Vector2(hole.end.x - 50.0, hole.position.y + 200.0), 30.0 + glow * 26.0, Color(1, 0.9, 0.6, 0.12))
		panel(Rect2(hole.position.x + 40.0, hole.end.y - 120.0, 240, 120), "velvet", Color("#c0485e"))
		panel(Rect2(hole.position.x + 40.0, hole.end.y - 140.0, 240, 28), "paper", Color("#f3ecfa"))
		panel(Rect2(hole.position.x + 110.0, hole.position.y + 60.0, 100, 90), "glass", Color("#3b3f7a"), Color("#ffd166"))
	else:
		# A dark broom cupboard with shelves and a dangling bulb.
		draw_rect(hole, Color("#241a2c"))
		for shelf in 3:
			panel(Rect2(hole.position.x, hole.position.y + 90.0 + shelf * 110.0, hole.size.x, 14), "planks", Color("#5a3a3a"))
		draw_line(Vector2(LOCK.x, hole.position.y), Vector2(LOCK.x, hole.position.y + 40.0), Color("#1a1218"), 3.0)
		draw_circle(Vector2(LOCK.x, hole.position.y + 46.0), 10.0, Color("#ffe8a8"))


func _draw_lock() -> void:
	var rings: Array = state.get("rings", [])
	var current := int(state.get("current", 0))
	var plate_px := Vector2(_plate.get_size()) * TEXEL
	draw_texture_rect(_plate, Rect2(LOCK - plate_px * 0.5 + Vector2(8, 10), plate_px), false, Color(Props.SHADOW, 0.3))
	draw_texture_rect(_plate, Rect2(LOCK - plate_px * 0.5, plate_px), false, NIGHT_TINT)
	var clicked := age(float(state.get("clicked_at", -99.0)))
	for index in rings.size():
		var ring: Dictionary = rings[index]
		var texture := _rings[index]
		var angle := float(ring.angle)
		var tint := NIGHT_TINT
		if bool(ring.open):
			tint = Color(1.15, 1.05, 0.7)
		elif index == current:
			tint = NIGHT_TINT.lightened(0.12 + 0.08 * pulse(1.5))
		else:
			tint = NIGHT_TINT.darkened(0.25)
		var reverse_at := float(ring.reverse_at)
		var shudder := reverse_at >= 0.0 and reverse_at - now < float(state.get("shudder_seconds", 0.3)) and reverse_at > now
		if shudder and not reduced_motion:
			angle += 4.0 * sin(now * 60.0)
		var size := Vector2(texture.get_size()) * TEXEL
		draw_set_transform(LOCK, deg_to_rad(angle), Vector2.ONE)
		draw_texture_rect(texture, Rect2(-size * 0.5, size), false, tint)
		draw_set_transform(Vector2.ZERO)
		if shudder and index == current:
			label(LOCK + Vector2(190, -40), "反轉！", 24, GOLD)
	# The key: a bow above the plate and its shaft down to the working ring.
	var depth := RING_OUTER - mini(current, RINGS_MAX - 1) * RING_STEP - RING_WIDTH * 0.5
	if current >= rings.size():
		depth = 4.0
	var tip := LOCK + Vector2(0, -depth * TEXEL)
	var top := LOCK + Vector2(0, -(PLATE + 6) * TEXEL)
	var push := 0.0
	if not reduced_motion and clicked >= 0.0:
		push = 6.0 * maxf(0.0, 1.0 - clicked / 0.2)
	draw_rect(Rect2(top.x - 5.0, top.y + push, 10, tip.y - top.y), BRASS.darkened(0.35))
	draw_rect(Rect2(top.x - 3.0, top.y + push, 4, tip.y - top.y), BRASS.lightened(0.2))
	stamp(_key, top + Vector2(-26, -44 + push), TEXEL, NIGHT_TINT)
	_draw_echo()


## An echo rippling out of the keyhole as the working notch comes round.
func _draw_echo() -> void:
	var next_in := float(state.get("next_in", 99.0))
	if next_in < 0.0 or next_in > 0.6:
		return
	var near := 1.0 - next_in / 0.6
	var current := int(state.get("current", 0))
	var at := LOCK + Vector2(0, -(RING_OUTER - current * RING_STEP - RING_WIDTH * 0.5) * TEXEL)
	for wave in 3:
		var grow := fposmod(now * 2.5 + wave / 3.0, 1.0) if not reduced_motion else 0.3 + wave * 0.25
		draw_arc(at, 10.0 + grow * 46.0, 0.0, TAU, 28, Color(ECHO, near * (1.0 - grow) * 0.8), 4.0)
	draw_circle(at, 9.0 * near + 3.0, Color(ECHO, 0.4 + 0.5 * near))


# --- The traveller, the ghost and the brooms ----------------------------------------

func _draw_hero(broom_since: float, opening: bool) -> void:
	var mood := "plain"
	var pose: StringName = &"idle"
	if broom_since >= 0.0:
		mood = "shocked" if broom_since < 0.5 else "sorry"
	elif opening:
		pose = &"up"
		mood = "tongue"
	ground_shadow(HERO_FEET + Vector2(6, 2), Vector2(60, 13), 0.42)
	var sprite := Hero.texture(pose, true, mood)
	var origin := Vector2(-Hero.FEET.x, -Hero.FEET.y) * HERO_SCALE + Vector2(HERO_SCALE, HERO_SCALE)
	var hop := 0.0 if reduced_motion or not opening else -absf(sin(now * 9.0)) * 14.0
	draw_set_transform(HERO_FEET + Vector2(0, hop), 0.0, squash(broom_since, 0.3, 0.4) if broom_since >= 0.0 else Vector2.ONE)
	stamp(sprite, origin, HERO_SCALE, NIGHT_TINT)
	draw_set_transform(Vector2.ZERO)


## Brooms and a bucket burst out of the cupboard and pile up on the traveller.
func _draw_brooms(since: float) -> void:
	var total := float(state.get("broom_seconds", 1.7))
	var fade := clampf((total - since) / 0.25, 0.0, 1.0)
	var from := LOCK + Vector2(-60, 40)
	for index in BROOM_COUNT + 1:
		var start := 0.12 + index * 0.05
		var t := clampf((since - start) / 0.32, 0.0, 1.0) if not reduced_motion else (1.0 if since >= start else 0.0)
		if t <= 0.0:
			continue
		var pile := HERO_FEET + Vector2(-70.0 + (index * 37) % 140, -20.0 - (index % 4) * 30.0)
		var at := from.lerp(pile, t) + Vector2(0, -sin(t * PI) * 140.0)
		var spin := (index * 1.7 + t * 5.0) if not reduced_motion else index * 1.7
		spin = fposmod(spin, TAU) * (1.0 - t) + (index * 0.9 - 2.0) * t
		var texture := _bucket if index == BROOM_COUNT else _broom
		var size := Vector2(texture.get_size()) * TEXEL
		draw_set_transform(at, spin, Vector2.ONE)
		draw_texture_rect(texture, Rect2(-size * 0.5, size), false, Color(NIGHT_TINT, fade))
		draw_set_transform(Vector2.ZERO)
	if since > 0.55:
		dust_puffs(HERO_FEET + Vector2(0, -10), since - 0.55, 90.0)


func _draw_ghost(brooming: bool, opening: bool) -> void:
	var mood := "oops" if brooming else ("happy" if opening else "plain")
	var bob := 0.0 if reduced_motion else 10.0 * sin(now * 1.6)
	var sprite := Hotel.ghost(mood)
	var size := Vector2(sprite.get_size()) * 4.0
	ground_shadow(Vector2(GHOST_AT.x, FLOOR_Y + 10.0), Vector2(34, 7), 0.2)
	stamp(sprite, GHOST_AT - size * 0.5 + Vector2(0, bob), 4.0, Color(1, 1, 1, 0.92))
	# A lantern held out on a little arm.
	var hand := GHOST_AT + Vector2(-46, 30 + bob)
	draw_circle(hand + Vector2(0, 22), 26.0 + (0.0 if reduced_motion else 3.0 * sin(now * 7.0)), Color(1, 0.82, 0.45, 0.16))
	stamp(_lantern, hand + Vector2(-18, 0), TEXEL, NIGHT_TINT)


func _draw_streak() -> void:
	var streak := int(state.get("streak", 0))
	if streak >= 3:
		label(Vector2(1000, 520), "連開 × %d" % streak, 26, GOLD, 1.0 + 0.08 * pulse(2.0))


# --- Texel painters ---------------------------------------------------------------

## An arched guest-room door: plum boards, two raised panels and a lit arch.
func _paint_door(x: int, y: int) -> Color:
	var arch := Vector2(x + 0.5 - 40.0, y + 0.5 - 40.0)
	if y < 40 and arch.length() > 40.0:
		return Pixels.CLEAR
	for panel_rect: Rect2i in [Rect2i(10, 20, 60, 30), Rect2i(10, 62, 60, 38)]:
		if panel_rect.has_point(Vector2i(x, y)):
			if y == panel_rect.position.y or x == panel_rect.position.x:
				return DOOR_WOOD.darkened(0.35)
			if y == panel_rect.end.y - 1 or x == panel_rect.end.x - 1:
				return DOOR_WOOD.lightened(0.25)
			return Pixels.wood(DOOR_WOOD.lightened(0.05), x, y, 10, true)
	if y < 40 and arch.length() > 37.0:
		return DOOR_WOOD.lightened(0.2)
	return Pixels.wood(DOOR_WOOD, x, y, 8, true)


## The round brass lock plate: an engraved rim with screws.
func _paint_plate(x: int, y: int) -> Color:
	var at := Vector2(x + 0.5 - PLATE, y + 0.5 - PLATE)
	var r := at.length()
	if r > PLATE:
		return Pixels.CLEAR
	for screw in 4:
		var spot := Vector2.from_angle(screw * TAU / 4.0 + PI * 0.25) * (PLATE - 2.5)
		if at.distance_to(spot) < 1.4:
			return Pixels.rounded(BRASS.lightened(0.15), (at - spot) / 1.4)
	if r > PLATE - 1.2:
		return BRASS.darkened(0.3)
	if r > PLATE - 2.2:
		return BRASS.lightened(0.2)
	if r < RING_OUTER + 1.0:
		# A dark recessed well the rings turn in.
		return Pixels.lit(Color("#3a2433"), 0.3 - r / RING_OUTER * 0.6, x, y)
	return Pixels.lit(BRASS.darkened(0.25), 0.4 - (at.x + at.y) / PLATE * 0.6, x, y)


## A bronze ring seen face on, its notch at the top: engraved ticks round it and
## the notch cut through, glowing lilac. Shading is radial so it can turn.
func _paint_ring(x: int, y: int, outer: int) -> Color:
	var at := Vector2(x + 0.5 - outer, y + 0.5 - outer)
	var r := at.length()
	if r > outer or r < outer - RING_WIDTH:
		return Pixels.CLEAR
	var degrees := rad_to_deg(atan2(at.x, -at.y))
	if absf(degrees) < NOTCH_DEGREES:
		return ECHO if r > outer - RING_WIDTH + 1.0 else ECHO.darkened(0.3)
	var across := (r - (outer - RING_WIDTH)) / RING_WIDTH
	if posmod(int(round(degrees / 15.0)), 2) == 0 and absf(fposmod(degrees, 15.0) - 7.5) > 6.5 and across > 0.3:
		return BRONZE.darkened(0.35)
	return Pixels.lit(BRONZE, 0.9 * (across - 0.5), x, y)


## The key's ornate bow: a ring with a heart cut-out.
func _paint_key(x: int, y: int) -> Color:
	var at := Vector2(x + 0.5 - 6.5, y + 0.5 - 6.0)
	if at.length() > 6.0:
		return Pixels.CLEAR
	if at.length() < 2.4:
		return Pixels.CLEAR
	return Pixels.lit(BRASS, 0.5 - (at.x + at.y) * 0.12, x, y)


## A broom: a wooden handle and a straw head bound with red twine.
func _paint_broom(x: int, y: int) -> Color:
	if y < 22:
		if x >= 2 and x <= 4:
			return Pixels.lit(Color("#9a6a40"), 0.5 - (x - 2) * 0.5, x, y)
		return Pixels.CLEAR
	if y < 24:
		return Color("#c0485e") if x >= 1 and x <= 5 else Pixels.CLEAR
	var spread := 1 + (y - 24) / 3
	if absi(x - 3) > spread:
		return Pixels.CLEAR
	return Color("#d9b85a") if posmod(x + y, 3) != 0 else Color("#a9883a")


## A tin bucket with a handle.
func _paint_bucket(x: int, y: int) -> Color:
	if y < 3:
		var handle := Vector2(x + 0.5 - 6.0, (y + 0.5 - 3.0) * 1.6).length()
		return Color("#6a6a7a") if absf(handle - 5.0) < 0.8 else Pixels.CLEAR
	var inset := (y - 3) / 4
	if x < inset or x >= 12 - inset:
		return Pixels.CLEAR
	if y == 3:
		return Color("#c8c8d8")
	return Pixels.lit(Color("#8a8aa0"), 0.5 - x * 0.1, x, y)


## A little brass lantern with a warm flame behind its glass.
func _paint_lantern(x: int, y: int) -> Color:
	if y < 2:
		return BRASS.darkened(0.2) if x >= 3 and x <= 5 else Pixels.CLEAR
	if y < 4 or y > 11:
		return Pixels.lit(BRASS, 0.3 - (x - 4) * 0.2, x, y)
	if x == 0 or x == 8:
		return BRASS.darkened(0.3)
	var flame := Vector2(x - 4.0, (y - 8.0) * 0.6).length()
	return Color("#ffe8a8") if flame < 1.6 else Color("#f0a85a").lerp(Color("#5a3a2a"), clampf(flame / 4.0, 0.0, 1.0))
