extends "res://game/minigames/arcade/arcade_view.gd"
## Picture for 折頁走廊: the hotel hall at night (hotel_backdrop) with the
## corridor floor as a giant open book seen from the side. The top pages run
## along under the traveller over a deep stack of page edges and a plum leather
## cover; numbered guest-room doors and fold lines scroll past on the wall.
## At each crease the two pages either side swing up and clap together; a
## trembling crease waits with its pages half up, and a feint twitches early.
## A friendly ghost floats over the next tricky crease. Caught on the ground,
## the traveller is squeezed thin between the pages, then floats away as a
## bookmark with their own picture on it. Every object is baked pixel art.

const Hero = preload("res://game/minigames/arcade/arcade_hero.gd")
const Hotel = preload("res://game/minigames/arcade/hotel_backdrop.gd")
const HERO_X := 420.0
const FLOOR_Y := 588.0
const STACK_Y := 600.0
const COVER_Y := 668.0
const HERO_SCALE := 2.5
const JUMP_HEIGHT := 165.0
const FLAP := Vector2i(30, 6)
const TILE := Vector2i(64, 20)
const DOOR := Vector2i(22, 40)
const PAPER := Color("#f3e6c6")
const PAPER_EDGE := Color("#d9c39a")
const INKLINE := Color("#8a7a8e")
const LEATHER := Color("#5a2f4e")
const RIBBONS: Array[Color] = [Color("#c0485e"), Color("#4f8f86"), Color("#d9a64e")]
const DOOR_WOOD := Color("#6a4058")
const MOONLIT := Color(0.94, 0.94, 1.04)

var _flap: ImageTexture
var _floor: ImageTexture
var _cover: ImageTexture
var _door: ImageTexture


func _init() -> void:
	super()
	word_anchor = Vector2(900, 250)


func _ready() -> void:
	_flap = Pixels.cached("pc-flap", func() -> Image: return _paint_image(FLAP, _paint_flap))
	_floor = Pixels.cached("pc-floor", func() -> Image: return _paint_image(TILE, _paint_floor))
	_cover = Pixels.cached("pc-cover", func() -> Image: return _paint_image(Vector2i(320, 13), _paint_cover))
	_door = Pixels.bake("pc-door", DOOR, _paint_door)


func _draw_backdrop() -> void:
	Hotel.draw(self, now, reduced_motion)
	vignette(0.3)


func _draw_scene() -> void:
	if not state.has("distance"):
		return
	_draw_wall()
	_draw_floor()
	var squash_since := age(float(state.get("squash_at", -99.0)))
	var squashing := squash_since >= 0.0 and squash_since < float(state.get("squash_seconds", 1.6))
	for crease: Dictionary in state.get("creases", []):
		var x := _screen_x(crease)
		if x < -120.0 or x > 1400.0:
			continue
		_draw_crease(crease, x, squashing and _is_squash_crease(crease, squash_since))
	if not squashing:
		_draw_hero()
	_draw_ghost()
	_draw_streak()


# --- Placement ----------------------------------------------------------------

func _screen_x(crease: Dictionary) -> float:
	return HERO_X + float(crease.at) - float(state.get("distance", 0.0))


func _is_squash_crease(crease: Dictionary, squash_since: float) -> bool:
	return absf(age(float(crease.snapped_at)) - squash_since) < 0.001


## Angle (radians) the two pages of `crease` stand at right now.
func _flap_angle(crease: Dictionary) -> float:
	var snapped := float(crease.snapped_at)
	if snapped >= 0.0 and age(snapped) >= 0.0:
		var since := age(snapped)
		if since < 0.06:
			return lerpf(deg_to_rad(25.0), PI * 0.5, since / 0.06)
		if since < 0.34:
			return PI * 0.5
		if since < 0.62:
			var u := (since - 0.34) / 0.28
			return PI * 0.5 * (1.0 - u) * (1.0 - u) + (0.0 if reduced_motion else deg_to_rad(6.0) * sin(u * PI))
		return 0.0
	var arrived := float(crease.arrived_at)
	if float(crease.hold) > 0.0 and arrived >= 0.0:
		var waited := age(arrived)
		var dip := float(state.get("dip_seconds", 0.35))
		var left := float(crease.hold) - waited
		if left > dip:
			var tremble := 0.0 if reduced_motion else deg_to_rad(4.0) * sin(now * 40.0)
			return deg_to_rad(32.0) + tremble
		return deg_to_rad(32.0) * clampf(left / dip, 0.0, 1.0)
	var arrive := (float(crease.at) - float(state.get("distance", 0.0))) / maxf(1.0, float(state.get("speed", 300.0)))
	var angle := 0.0
	if arrive < 0.7:
		var lift := 1.0 - clampf(arrive / 0.7, 0.0, 1.0)
		angle = deg_to_rad(18.0) * lift * lift
	if str(crease.kind) == "hold" and arrive < 0.5:
		angle = maxf(angle, deg_to_rad(32.0) * (1.0 - clampf(arrive / 0.5, 0.0, 1.0)))
	var lead := float(state.get("feint_lead", 0.85))
	if str(crease.kind) == "feint" and arrive <= lead and arrive >= lead - 0.24:
		angle = maxf(angle, deg_to_rad(55.0) * sin(PI * (lead - arrive) / 0.24))
	return angle


# --- The corridor ----------------------------------------------------------------

## Guest-room doors between the creases, and a fold line up the wall at each.
func _draw_wall() -> void:
	var creases: Array = state.get("creases", [])
	for index in creases.size():
		var x := _screen_x(creases[index])
		if x > -40.0 and x < 1320.0:
			draw_rect(Rect2(x - 3.0, 130, 6, FLOOR_Y - 130.0), Color(0.08, 0.04, 0.14, 0.22))
			draw_rect(Rect2(x + 3.0, 130, 2, FLOOR_Y - 130.0), Color(0.9, 0.86, 1.0, 0.12))
		if index + 1 >= creases.size():
			continue
		var middle := (x + _screen_x(creases[index + 1])) * 0.5
		if absf(_screen_x(creases[index + 1]) - x) < 230.0:
			continue
		var size := Vector2(DOOR) * TEXEL
		var at := Vector2(middle - size.x * 0.5, FLOOR_Y - size.y)
		if at.x < -size.x or at.x > 1300.0:
			continue
		cast_shadow(_door, at, Vector2(8, 4), TEXEL, 0.35)
		stamp(_door, at, TEXEL, MOONLIT)
		label(Vector2(middle, at.y + 26.0), "%d" % (200 + int(creases[index].number)), 15, Color("#3a2433"), 1.0, 1.0, false)


func _draw_floor() -> void:
	var scroll := fposmod(float(state.get("distance", 0.0)), TILE.x * TEXEL)
	var x := -scroll
	while x < DESIGN.x:
		draw_texture_rect(_floor, Rect2(x, FLOOR_Y, TILE.x * TEXEL, TILE.y * TEXEL), false, MOONLIT)
		x += TILE.x * TEXEL
	draw_texture_rect(_cover, Rect2(0, COVER_Y, DESIGN.x, DESIGN.y - COVER_Y + 4.0), false, MOONLIT)
	# The traveller's own shadow on the page.
	var lift := _hero_lift()
	ground_shadow(Vector2(HERO_X + 4.0, FLOOR_Y + 4.0), Vector2(48.0 - lift * 0.12, 9.0), 0.42 - lift * 0.0015)


## One crease: the gutter in the floor, a ribbon now and then, and its two pages.
func _draw_crease(crease: Dictionary, x: float, squashing: bool) -> void:
	# The gutter: page edges dip into a dark fold.
	for step in 4:
		var half := 16.0 - step * 4.0
		draw_rect(Rect2(x - half, FLOOR_Y, half * 2.0, 12), Color(0.12, 0.06, 0.16, 0.12 + step * 0.06))
	draw_rect(Rect2(x - 2.0, FLOOR_Y, 4, COVER_Y - FLOOR_Y), Color(0.12, 0.06, 0.16, 0.45))
	if int(crease.number) % 3 == 0:
		var ribbon := RIBBONS[int(crease.number) / 3 % RIBBONS.size()]
		var sway := 0.0 if reduced_motion else roundf(3.0 * sin(now * 1.4 + float(crease.number)))
		draw_rect(Rect2(x + 26.0 + sway, STACK_Y, 12, COVER_Y - STACK_Y + 22.0), ribbon.darkened(0.35))
		draw_rect(Rect2(x + 28.0 + sway, STACK_Y, 8, COVER_Y - STACK_Y + 20.0), ribbon)
		draw_rect(Rect2(x + 28.0 + sway, STACK_Y, 2, COVER_Y - STACK_Y + 20.0), ribbon.lightened(0.3))
		draw_colored_polygon(PackedVector2Array([Vector2(x + 26.0 + sway, COVER_Y + 22.0), Vector2(x + 38.0 + sway, COVER_Y + 22.0), Vector2(x + 32.0 + sway, COVER_Y + 14.0)]), Color(Props.SHADOW, 0.6))
	var angle := _flap_angle(crease)
	var since := age(float(crease.snapped_at)) if float(crease.snapped_at) >= 0.0 else -1.0
	if since >= 0.0 and since < 0.5:
		dust_puffs(Vector2(x, FLOOR_Y - 4.0), since, 70.0)
	if squashing:
		_draw_squeezed(x, since)
	if angle <= 0.001:
		return
	# Shadows the raised pages throw on the floor, then the pages themselves.
	var reach := float(FLAP.x) * TEXEL * cos(angle)
	draw_rect(Rect2(x - reach, FLOOR_Y - 2.0, reach, 6), Color(Props.SHADOW, 0.3 * sin(angle)))
	draw_rect(Rect2(x, FLOOR_Y - 2.0, reach, 6), Color(Props.SHADOW, 0.3 * sin(angle)))
	for side: float in [-1.0, 1.0]:
		var facing := 1.0 + 0.12 * sin(angle) * (1.0 if side < 0.0 else -1.0)
		var tint := Color(MOONLIT.r * facing, MOONLIT.g * facing, MOONLIT.b * facing)
		if side < 0.0:
			draw_set_transform(Vector2(x, FLOOR_Y), PI + angle, Vector2.ONE)
			draw_texture_rect(_flap, Rect2(0, 0, FLAP.x * TEXEL, FLAP.y * TEXEL), false, tint)
		else:
			draw_set_transform(Vector2(x, FLOOR_Y), -angle, Vector2.ONE)
			draw_texture_rect(_flap, Rect2(0, -FLAP.y * TEXEL, FLAP.x * TEXEL, FLAP.y * TEXEL), false, tint)
		draw_set_transform(Vector2.ZERO)


# --- The traveller --------------------------------------------------------------

func _hero_lift() -> float:
	if not bool(state.get("airborne", false)):
		return 0.0
	var t := clampf(age(float(state.get("jump_at", -99.0))) / float(state.get("jump_seconds", 0.5)), 0.0, 1.0)
	return 4.0 * JUMP_HEIGHT * t * (1.0 - t)


func _draw_hero() -> void:
	var squash_since := age(float(state.get("squash_at", -99.0)))
	var total := float(state.get("squash_seconds", 1.6))
	var popping := squash_since >= total and squash_since < total + 0.3
	var stumble := age(float(state.get("stumble_at", -99.0)))
	var stumbling := stumble >= 0.0 and stumble < float(state.get("stumble_seconds", 0.45))
	var airborne := bool(state.get("airborne", false))
	var running := str(state.get("stage", "")) in ["ready", "play"] and not stumbling
	var pose: StringName = &"idle"
	var mood := "plain"
	var bob := 0.0
	if airborne:
		pose = &"up"
		mood = "tongue" if int(state.get("streak", 0)) >= 5 else "plain"
	elif stumbling:
		mood = "shocked"
	elif running:
		bob = 0.0 if reduced_motion else -absf(sin(now * PI / 0.16)) * 8.0
	var feet := Vector2(HERO_X, FLOOR_Y - _hero_lift() + bob)
	var stretch := squash(stumble, 0.25, 0.4) if stumbling else Vector2.ONE
	if running and not airborne and not reduced_motion:
		var step := absf(cos(now * PI / 0.16))
		stretch = Vector2(1.0 + 0.04 * step, 1.0 - 0.04 * step)
	if popping:
		stretch *= pop_in(squash_since - total, 0.3)
	var sprite := Hero.texture(pose, true, mood)
	var origin := Vector2(-Hero.FEET.x, -Hero.FEET.y) * HERO_SCALE
	draw_set_transform(feet, 0.0, stretch)
	stamp(sprite, origin + Vector2(HERO_SCALE, HERO_SCALE), HERO_SCALE, MOONLIT)
	draw_set_transform(Vector2.ZERO)
	if stumbling and stumble < 0.3:
		dust_puffs(Vector2(HERO_X, FLOOR_Y - 2.0), stumble, 40.0)


## Caught: squeezed thin between the clapped pages with the hair poking out,
## then the pages open and a bookmark with the traveller's face floats away.
func _draw_squeezed(x: float, since: float) -> void:
	var sprite := Hero.texture(&"up", true, "shocked")
	var origin := Vector2(-Hero.FEET.x, -Hero.FEET.y) * HERO_SCALE
	if since < 0.34:
		draw_set_transform(Vector2(x, FLOOR_Y), 0.0, Vector2(0.24, 1.3))
		stamp(sprite, origin + Vector2(HERO_SCALE, HERO_SCALE), HERO_SCALE, MOONLIT)
		draw_set_transform(Vector2.ZERO)
		return
	var total := float(state.get("squash_seconds", 1.6))
	var float_t := clampf((since - 0.34) / (total - 0.34), 0.0, 1.0)
	var sway := 0.0 if reduced_motion else sin(since * 4.2) * 0.28
	var drift := 0.0 if reduced_motion else sin(since * 2.1) * 46.0
	var centre := Vector2(x - 20.0 + drift, lerpf(FLOOR_Y - 70.0, 300.0, float_t))
	var card := Vector2(74, 150)
	draw_set_transform(centre, sway, Vector2.ONE * pop_in(since - 0.34, 0.2))
	var face := Rect2(-card * 0.5, card)
	draw_rect(Rect2(face.position + Vector2(6, 8), card), Color(Props.SHADOW, 0.35))
	panel(face, "paper", PAPER)
	draw_rect(face.grow(-6.0), Color(Color("#b7a3df"), 0.35))
	stamp(sprite, Vector2(-Hero.FEET.x * 1.5, -Hero.FEET.y * 1.5 + 56.0) + Vector2(1.5, 1.5), 1.5, Color(1.0, 0.92, 0.86))
	# A ribbon tassel threaded through a hole at the top.
	draw_circle(Vector2(0, -card.y * 0.5 + 12.0), 5.0, Color(Props.SHADOW, 0.7))
	draw_rect(Rect2(-3, -card.y * 0.5 - 34.0, 6, 46), RIBBONS[0])
	draw_rect(Rect2(-3, -card.y * 0.5 - 34.0, 2, 46), RIBBONS[0].lightened(0.3))
	draw_circle(Vector2(0, -card.y * 0.5 - 36.0), 7.0, RIBBONS[2])
	draw_circle(Vector2(-2, -card.y * 0.5 - 38.0), 3.0, RIBBONS[2].lightened(0.35))
	draw_set_transform(Vector2.ZERO)


# --- The ghost and the streak -----------------------------------------------------

## The hotel ghost hovers cheekily over the next tricky crease, otherwise
## floats ahead on the right; it giggles when the traveller is caught.
func _draw_ghost() -> void:
	var at := Vector2(1080, 340)
	var mood := "plain"
	for crease: Dictionary in state.get("creases", []):
		if float(crease.snapped_at) >= 0.0:
			continue
		var x := _screen_x(crease)
		if str(crease.kind) != "plain" and x > HERO_X - 10.0 and x < 1180.0:
			at = Vector2(x, FLOOR_Y - 230.0)
			mood = "cheeky"
		break
	var squash_since := age(float(state.get("squash_at", -99.0)))
	if squash_since >= 0.0 and squash_since < float(state.get("squash_seconds", 1.6)):
		mood = "happy"
	var bob := 0.0 if reduced_motion else 10.0 * sin(now * 1.7)
	var sprite := Hotel.ghost(mood)
	var size := Vector2(sprite.get_size()) * 4.0
	ground_shadow(Vector2(at.x, FLOOR_Y + 2.0), Vector2(30, 6), 0.18)
	stamp(sprite, at - size * 0.5 + Vector2(0, bob), 4.0, Color(1, 1, 1, 0.9))


func _draw_streak() -> void:
	var streak := int(state.get("streak", 0))
	if streak >= 3:
		label(Vector2(1110, 470), "連跳 × %d" % streak, 26, GOLD, 1.0 + 0.08 * pulse(2.0))


# --- Texel painters ---------------------------------------------------------------

static func _paint_image(size: Vector2i, paint: Callable) -> Image:
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	for y in size.y:
		for x in size.x:
			image.set_pixel(x, y, paint.call(x, y))
	return image


## A slab of pages seen edge-on: a lit printed top page over page edges, with
## a gilt edge at the free end.
func _paint_flap(x: int, y: int) -> Color:
	if x >= FLAP.x - 1:
		return Color("#e0b05a") if y < 3 else Color("#a9762e")
	if y == 0:
		return PAPER.lightened(0.16)
	if y == 1:
		return INKLINE if posmod(x, 7) < 5 and Pixels.noise(x / 7, 3, 4) > 0.25 else PAPER
	if y == FLAP.y - 1:
		return PAPER_EDGE.darkened(0.45)
	var line := PAPER_EDGE if posmod(y, 2) == 0 else PAPER_EDGE.darkened(0.14)
	return Pixels.grainy(line, x, y, 0.04)


## The floor tile: the top page lit and printed with two lines of tiny text,
## its shaded fore-edge, then the page edges stacked below, darker deeper down
## with a darker signature line every few pages.
func _paint_floor(x: int, y: int) -> Color:
	if y == 0:
		return PAPER.lightened(0.18)
	if y == 1 or y == 2:
		var word := posmod(x + (5 if y == 2 else 0), 11)
		return INKLINE if word < 7 and Pixels.noise((x + y * 5) / 11, y, 4) > 0.18 else PAPER
	if y == 3:
		return PAPER.darkened(0.22)
	var depth := float(y - 4) / float(TILE.y - 4)
	var tone := PAPER_EDGE.darkened(0.08 + depth * 0.5)
	if posmod(y, 2) == 1:
		tone = tone.darkened(0.12)
	if posmod(y, 6) == 0:
		tone = tone.darkened(0.25)
	if Pixels.noise(x / 5, y, 8) > 0.88:
		tone = tone.lightened(0.08)
	return Pixels.grainy(tone, x, y, 0.03)


## The plum leather cover with a gold tooled line and a worn edge.
func _paint_cover(x: int, y: int) -> Color:
	if y == 0:
		return LEATHER.lightened(0.3)
	if y == 3:
		return Color("#c9953e") if posmod(x, 8) != 7 else Color("#8a6030")
	if y == 4:
		return LEATHER.darkened(0.3)
	return Pixels.grainy(LEATHER.darkened(float(y) * 0.025), x, y, 0.08 if Pixels.noise(x / 3, y / 2, 6) > 0.7 else 0.04)


## A guest-room door: cream frame, plum panelled leaf, brass knob and number plate.
func _paint_door(x: int, y: int) -> Color:
	if x < 2 or x >= DOOR.x - 2 or y < 2:
		return Pixels.lit(Color("#e8dcc4"), 0.5 if x < 2 or y < 2 else -0.6, x, y)
	var leaf_x := x - 2
	var leaf_y := y - 2
	if leaf_y >= 4 and leaf_y <= 6 and leaf_x >= 6 and leaf_x <= 11:
		return Pixels.lit(Color("#c9953e"), 0.6 - (leaf_y - 4) * 0.5, x, y)
	if Vector2(leaf_x - 14.5, leaf_y - 20.5).length() < 1.6:
		return Pixels.rounded(Color("#d9a64e"), Vector2(leaf_x - 14.5, leaf_y - 20.5) / 1.6)
	for panel_rect: Rect2i in [Rect2i(3, 9, 12, 9), Rect2i(3, 23, 12, 12)]:
		if panel_rect.has_point(Vector2i(leaf_x, leaf_y)):
			var edge_top := leaf_y == panel_rect.position.y or leaf_x == panel_rect.position.x
			var edge_bottom := leaf_y == panel_rect.end.y - 1 or leaf_x == panel_rect.end.x - 1
			if edge_top:
				return DOOR_WOOD.darkened(0.35)
			if edge_bottom:
				return DOOR_WOOD.lightened(0.25)
			return Pixels.wood(DOOR_WOOD.lightened(0.06), x, y, 6, true)
	return Pixels.wood(DOOR_WOOD, x, y, 9, true)
