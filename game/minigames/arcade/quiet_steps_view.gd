extends "res://game/minigames/arcade/arcade_view.gd"
## Picture for 枕頭靜步: the hotel hall at night (hotel_backdrop) as a long
## guest room with four beds along the back wall, a sleeping ghost under each
## quilt in a nightcap, a snot bubble swelling and shrinking with every snore
## and Zzz drifting up. A rug lies in front of each bed: that is the stretch
## the guest watches, and its edge glows red while the guest is awake. The
## traveller tiptoes along the carpet in front from the door on the left to
## the door on the right. A guest who catches them sits up and throws a
## pillow that bursts in feathers on their face. Every object is baked pixel art.

const Hero = preload("res://game/minigames/arcade/arcade_hero.gd")
const Hotel = preload("res://game/minigames/arcade/hotel_backdrop.gd")
const FLOOR_Y := 572.0
const WALK_Y := 664.0
const LEFT := 150.0
const RIGHT := 1130.0
const QUILTS: Array[Color] = [Color("#5b3f74"), Color("#4f8f86"), Color("#c0485e"), Color("#d9a64e")]
const NIGHT_TINT := Color(0.95, 0.94, 1.04)
const HERO_SCALE := 2.6

var _bed: Array[ImageTexture] = []
var _pillow: ImageTexture
var _cap: ImageTexture
var _door: ImageTexture


func _init() -> void:
	super()
	word_anchor = Vector2(640, 232)


func _ready() -> void:
	for tone in QUILTS.size():
		_bed.append(Pixels.bake("qs-bed|%d" % tone, Vector2i(46, 26), _paint_bed.bind(QUILTS[tone])))
	_pillow = Pixels.bake("qs-pillow", Vector2i(14, 9), _paint_pillow)
	_cap = Pixels.bake("qs-cap", Vector2i(12, 9), _paint_cap)
	_door = Pixels.bake("qs-door", Vector2i(26, 52), _paint_door)


func _draw_backdrop() -> void:
	Hotel.draw(self, now, reduced_motion)
	stage_floor(FLOOR_Y, Color("#7a5040"), Color("#3a2430"))
	vignette(0.3)


func _draw_scene() -> void:
	if not state.has("guests"):
		return
	_draw_doors()
	var guests: Array = state.get("guests", [])
	var states: Array = state.get("states", [])
	for index in guests.size():
		_draw_bed(index, guests[index], str(states[index]) if index < states.size() else "snore")
	_draw_hero()
	_draw_pillow_throw()
	label(Vector2(1110, 180), "第 %d 間" % int(state.get("row", 1)), 22, CREAM)
	var streak := int(state.get("streak", 0))
	if streak >= 3:
		label(Vector2(170, 180), "連過 × %d" % streak, 24, GOLD, 1.0 + 0.08 * pulse(2.0))


func _x(at: float) -> float:
	return lerpf(LEFT, RIGHT, at)


func _draw_doors() -> void:
	var size := Vector2(_door.get_size()) * TEXEL
	for side in 2:
		var x := 18.0 if side == 0 else DESIGN.x - 18.0 - size.x
		stamp(_door, Vector2(x, FLOOR_Y - size.y), TEXEL, NIGHT_TINT)


func _draw_bed(index: int, guest: Dictionary, mood: String) -> void:
	var centre := _x(float(guest.x))
	var texture := _bed[index % _bed.size()]
	var size := Vector2(texture.get_size()) * TEXEL
	var at := Vector2(centre - size.x * 0.5, FLOOR_Y - size.y)
	# The rug in front marks the stretch this guest watches; it glows red awake.
	var zone := Rect2(_x(float(guest.x) - 0.13), FLOOR_Y + 30.0, _x(float(guest.x) + 0.13) - _x(float(guest.x) - 0.13), 70)
	panel(zone, "velvet", QUILTS[index % QUILTS.size()].darkened(0.35))
	var awake := mood == "quiet" or mood == "peek"
	if awake:
		var glow := 0.5 + 0.3 * pulse(3.0)
		draw_rect(Rect2(zone.position, Vector2(zone.size.x, 5)), Color(ROSE, glow))
		draw_rect(Rect2(zone.position + Vector2(0, zone.size.y - 5.0), Vector2(zone.size.x, 5)), Color(ROSE, glow))
	ground_shadow(Vector2(centre, FLOOR_Y + 2.0), Vector2(size.x * 0.55, 12), 0.4)
	var pillow_since := age(float(state.get("pillow_at", -99.0)))
	var sitting := int(state.get("thrower", -1)) == index and pillow_since >= 0.0 and pillow_since < float(state.get("pillow_seconds", 1.6))
	stamp(texture, at, TEXEL, NIGHT_TINT)
	# The guest's head resting on the pillow, or sitting up to throw.
	var head := Vector2(centre + size.x * 0.22, at.y + 34.0 - (40.0 if sitting else 0.0))
	var sprite := Hotel.ghost("cheeky" if sitting else ("plain" if awake else "happy"))
	var ghost_size := Vector2(sprite.get_size()) * 3.5
	stamp(sprite, head - ghost_size * 0.5, 3.5, Color(1, 1, 1, 0.97))
	if mood == "peek":
		# One eyelid stays shut: only a single eye peeks out.
		draw_rect(Rect2(head + Vector2(-12, -5), Vector2(10, 8)), Color("#e8e8f6"))
		draw_line(head + Vector2(-12, 0), head + Vector2(-3, 0), Color("#2a2440"), 2.0)
	stamp(_cap, head + Vector2(-26, -42), TEXEL, NIGHT_TINT)
	# The quilt tucked up to the chin.
	if not sitting:
		draw_rect(Rect2(head.x - 34.0, head.y + 18.0, 68, 14), QUILTS[index % QUILTS.size()])
		draw_rect(Rect2(head.x - 34.0, head.y + 18.0, 68, 4), QUILTS[index % QUILTS.size()].lightened(0.25))
	if mood == "snore" or mood == "drowsy":
		_draw_snore(head, guest, mood == "drowsy")
	elif awake and not sitting:
		label(head + Vector2(30, -40), "？" if mood == "quiet" else "…", 26, ROSE if mood == "quiet" else GOLD)


## A snot bubble swelling with each breath (shrinking as the snore runs out)
## and Zzz drifting up.
func _draw_snore(head: Vector2, guest: Dictionary, drowsy: bool) -> void:
	var breath := 0.5 + 0.5 * sin(now * 3.2 + float(guest.x) * 9.0)
	if reduced_motion:
		breath = 0.6
	var radius := (6.0 + 12.0 * breath) * (0.45 if drowsy else 1.0)
	var nose := head + Vector2(16, 6)
	draw_circle(nose + Vector2(radius, 0), radius, Color(0.75, 0.9, 1.0, 0.55))
	draw_arc(nose + Vector2(radius, 0), radius, 0.0, TAU, 20, Color(1, 1, 1, 0.8), 2.0)
	draw_circle(nose + Vector2(radius * 0.6, -radius * 0.4), radius * 0.2, Color(1, 1, 1, 0.9))
	for z in 3:
		var rise := fposmod(now * 0.6 + z / 3.0, 1.0) if not reduced_motion else z / 3.0
		label(head + Vector2(30 + z * 10.0, -30.0 - rise * 60.0), "z" if drowsy else "Z", 18 + z * 4, Color("#d8d2ff"), 1.0, 1.0 - rise * 0.7)


func _draw_hero() -> void:
	var x := _x(float(state.get("walker", 0.0)))
	var moving := absf(float(state.get("speed", 0.0))) > 0.012
	var pillow_since := age(float(state.get("pillow_at", -99.0)))
	var hit := pillow_since >= 0.3 and pillow_since < float(state.get("pillow_seconds", 1.6))
	var watched := false
	var guests: Array = state.get("guests", [])
	var states: Array = state.get("states", [])
	for index in guests.size():
		if absf(float(state.get("walker", 0.0)) - float(guests[index].x)) <= 0.13 and index < states.size() and str(states[index]) in ["quiet", "peek"]:
			watched = true
	var mood := "sorry" if hit else ("shocked" if watched else "plain")
	var bob := 0.0 if reduced_motion or not moving else -absf(sin(now * 9.0)) * 8.0
	var lean := 0.0 if reduced_motion or not moving else 0.08
	var feet := Vector2(x, WALK_Y + bob)
	ground_shadow(Vector2(x + 4.0, WALK_Y + 2.0), Vector2(46, 10), 0.42)
	var sprite := Hero.texture(&"up" if watched and not moving else &"idle", true, mood)
	draw_set_transform(feet, lean, Vector2(1.08, 0.92) if hit else Vector2.ONE)
	stamp(sprite, Vector2(-Hero.FEET.x, -Hero.FEET.y) * HERO_SCALE + Vector2(HERO_SCALE, HERO_SCALE), HERO_SCALE, NIGHT_TINT)
	draw_set_transform(Vector2.ZERO)
	if hit:
		# The pillow stuck on the traveller's face, feathers drifting off.
		var face := feet + Vector2(0, -34.0 * HERO_SCALE)
		var size := Vector2(_pillow.get_size()) * TEXEL * 1.2
		stamp(_pillow, face - size * 0.5, TEXEL * 1.2, NIGHT_TINT)
		for feather in 7:
			var drift := pillow_since - 0.3
			var dir := Vector2.from_angle(-PI * 0.5 + (feather - 3) * 0.45)
			var at := face + dir * (30.0 + drift * 70.0) + Vector2(0, drift * drift * 60.0)
			draw_rect(Rect2(at, Vector2(8, 4)), Color(1, 1, 1, maxf(0.0, 1.0 - drift)))


## The pillow flying from the thrower's bed to the traveller's face.
func _draw_pillow_throw() -> void:
	var since := age(float(state.get("pillow_at", -99.0)))
	var thrower := int(state.get("thrower", -1))
	var guests: Array = state.get("guests", [])
	if since < 0.0 or since >= 0.3 or thrower < 0 or thrower >= guests.size():
		return
	var t := since / 0.3 if not reduced_motion else 1.0
	var from := Vector2(_x(float(guests[thrower].x)), FLOOR_Y - 120.0)
	var to := Vector2(_x(float(state.get("walker", 0.0))), WALK_Y - 34.0 * HERO_SCALE)
	var at := from.lerp(to, t) + Vector2(0, -sin(t * PI) * 90.0)
	var size := Vector2(_pillow.get_size()) * TEXEL
	draw_set_transform(at, t * TAU, Vector2.ONE)
	draw_texture_rect(_pillow, Rect2(-size * 0.5, size), false, NIGHT_TINT)
	draw_set_transform(Vector2.ZERO)


# --- Texel painters ---------------------------------------------------------------

## A wooden bed seen from the front: a carved headboard, a plump white pillow
## and a patchwork quilt folded back.
func _paint_bed(x: int, y: int, quilt: Color) -> Color:
	var wood := Color("#6a4058")
	if y < 6:
		var arch := Vector2((x + 0.5 - 23.0) / 23.0, (y + 0.5 - 6.0) / 6.0).length()
		if arch > 1.0:
			return Pixels.CLEAR
		return Pixels.wood(wood.lightened(0.1), x, y, 9, false)
	if x < 2 or x > 43:
		return Pixels.lit(wood, 0.4 if x < 2 else -0.4, x, y)
	if y < 11:
		return Pixels.lit(Color("#f3ecfa"), 0.4 - (y - 6) * 0.15, x, y) if x > 20 else Pixels.wood(wood, x, y, 7, false)
	if y < 13:
		return Color("#f3ecfa").darkened(0.08)
	if y > 23:
		return wood.darkened(0.3)
	var patch := (x / 6 + (y - 13) / 4) % 2 == 0
	if (x % 6 == 0) or ((y - 13) % 4 == 0):
		return quilt.darkened(0.3)
	return Pixels.lit(quilt.lightened(0.1) if patch else quilt, 0.3 - (y - 13) * 0.05, x, y)


## A plump pillow in a ticking-stripe case: lilac stripes, a stitched seam
## round the edge, tufted corners and a rounded shade toward the bottom.
func _paint_pillow(x: int, y: int) -> Color:
	var at := Vector2((x + 0.5) / 7.0 - 1.0, (y + 0.5) / 4.5 - 1.0)
	if absf(at.y) > 1.0 - 0.15 * absf(at.x) or (absf(at.x) > 0.86 and absf(at.y) > 0.72):
		return Pixels.CLEAR
	if (x == 0 or x == 13) and (y == 1 or y == 7):
		return Color("#c9b6ff")
	var base := Color("#f3ecfa")
	if posmod(x, 4) == 1:
		base = Color("#b7a3df")
	# A dotted seam just inside the edge.
	var inside := absf(at.y) > 0.62 - 0.12 * absf(at.x) and absf(at.y) < 0.8 and posmod(x, 2) == 0
	if inside:
		return Color("#8f78b8")
	return Pixels.lit(base, 0.6 - at.y * 0.7 - absf(at.x) * 0.35, x, y)


## A floppy striped nightcap with a pom-pom.
func _paint_cap(x: int, y: int) -> Color:
	if Vector2(x - 10.0, y - 1.5).length() < 1.6:
		return Color("#f4ecd8")
	var edge := 9.0 - y * 0.9
	if y < 2 or x < 1 or x > edge + 3.0:
		return Pixels.CLEAR
	return Color("#c0485e") if (x + y) % 4 < 2 else Color("#f4ecd8")


## A guest-room door.
func _paint_door(x: int, y: int) -> Color:
	if x < 2 or x > 23 or y < 2:
		return Pixels.lit(Color("#e8dcc4"), 0.5 if x < 2 or y < 2 else -0.5, x, y)
	if Vector2(x - 19.5, y - 28.5).length() < 1.5:
		return Color("#d9a64e")
	return Pixels.wood(Color("#6a4058"), x, y, 7, true)
