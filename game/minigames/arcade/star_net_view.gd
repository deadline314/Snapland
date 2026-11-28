extends "res://game/minigames/arcade/arcade_view.gd"
## Picture for 落星接網: the cloud-top photo deck at dusk, over the sky park's
## shared backdrop (sky_backdrop.gd) with a violet evening wash. The island
## traveller holds a big wooden hoop net overhead; stars tumble down out of the
## sky with a glow on the deck under each, and every one caught arcs off into a
## woven basket at either end of the deck. Thundercloud balls crackle as they
## fall; catching one stands the traveller's hair on end, smoking, with sparks.

const Hero = preload("res://game/minigames/arcade/arcade_hero.gd")
const SkyBackdrop = preload("res://game/minigames/arcade/sky_backdrop.gd")
const LEFT := 120.0
const WIDE := 1040.0
const TOP := 170.0
const NET_Y := 478.0
const DECK_Y := 650.0
const HERO_SCALE := 3.0
const BASKETS: Array[Vector2] = [Vector2(70, 590), Vector2(1210, 590)]
const WOOD := Color("#a87a4f")
const DARK_WOOD := Color("#6e4c32")
const WICKER := Color("#c99a5b")
const GOLD_STAR := Color("#ffd35c")
const STORM := Color("#4a4f72")
const BOLT := Color("#fff27a")
const DUSK_TOP := Color("#3a2f6e")
const DUSK_LOW := Color("#ff9a6b")
const NAVY := Color("#2f4a7a")
const WHITE := Color("#fbfdff")
const MESH := Color("#e8f1fa")
const SMOKE := Color("#8a8a99")
const NOON := Color(1.0, 0.96, 0.94)

var _star: ImageTexture
var _big: ImageTexture
var _storm: ImageTexture
var _basket: ImageTexture


func _init() -> void:
	super()
	word_anchor = Vector2(640, 280)


func _ready() -> void:
	_star = Pixels.bake("starnet-star", Vector2i(11, 11), _paint_star.bind(11))
	_big = Pixels.bake("starnet-big", Vector2i(17, 17), _paint_star.bind(17))
	_storm = Pixels.bake("starnet-storm", Vector2i(15, 12), _paint_storm)
	_basket = Pixels.bake("starnet-basket", Vector2i(18, 12), _paint_basket)


func _x(at: float) -> float:
	return LEFT + at * WIDE


func _y(at: float) -> float:
	return TOP + at * (NET_Y - TOP)


# --- Backdrop ------------------------------------------------------------------

func _draw_backdrop() -> void:
	SkyBackdrop.draw(self, now, reduced_motion)
	# An evening wash: violet overhead warming to orange at the horizon.
	for band in 12:
		var t := band / 11.0
		draw_rect(Rect2(0, band * 60.0, DESIGN.x, 60), Color(DUSK_TOP.lerp(DUSK_LOW, t), 0.42 - 0.22 * t))
	# Little stars already twinkling in the evening sky.
	for dot in 16:
		var spot := Vector2(Pixels.noise(dot, 1, 31) * DESIGN.x, 130.0 + Pixels.noise(dot, 2, 31) * 220.0)
		var blink := 1.0 if reduced_motion else 0.5 + 0.5 * sin(now * 2.0 + dot)
		draw_rect(Rect2(spot - Vector2(2, 2), Vector2(4, 4)), Color(WHITE, 0.5 * blink))
	_draw_rail()
	stage_floor(DECK_Y, WOOD, DARK_WOOD)
	vignette(0.34)


func _draw_rail() -> void:
	# A white picket rail along the back of the photo deck.
	var rail := 600.0
	panel(Rect2(-8, rail - 8.0, DESIGN.x + 16.0, 12), "planks", Color("#efe6da"), Color(0, 0, 0, 0), TEXEL, NOON)
	for picket in 32:
		var x := 10.0 + picket * 40.0
		draw_colored_polygon(PackedVector2Array([Vector2(x, rail - 22), Vector2(x + 8, rail - 30), Vector2(x + 16, rail - 22), Vector2(x + 16, DECK_Y), Vector2(x, DECK_Y)]), Color("#d8cfc4"))
		draw_rect(Rect2(x + 2, rail - 22, 6, DECK_Y - rail + 22), Color("#f4ece2"))


# --- Play ----------------------------------------------------------------------

func _draw_scene() -> void:
	if not state.has("drops"):
		return
	_draw_baskets()
	for drop: Dictionary in state.drops:
		if str(drop.state) == "fall":
			_draw_glow(drop)
	_draw_hero()
	for drop: Dictionary in state.drops:
		_draw_drop(drop)
	_draw_combo()


func _zapped() -> float:
	var since := age(float(state.get("zap_at", -99.0)))
	return since if since >= 0.0 and since < float(state.get("stun_seconds", 1.2)) + 0.4 else -1.0


func _draw_baskets() -> void:
	for at in BASKETS:
		ground_shadow(at + Vector2(0, 58), Vector2(52, 10), 0.35)
		draw_rect(Rect2(at.x - 6, at.y + 24, 12, DECK_Y - at.y - 20), DARK_WOOD)
		stamp(_basket, at - Vector2(9, 6) * TEXEL, TEXEL, NOON)


func _draw_glow(drop: Dictionary) -> void:
	# A soft glow on the deck under each falling thing, brighter as it nears.
	var t := _height(drop)
	var tone := Color(GOLD_STAR, 0.15 + 0.3 * t) if str(drop.kind) != "thunder" else Color(STORM, 0.2 + 0.3 * t)
	draw_set_transform(Vector2(_x(float(drop.x)), DECK_Y + 6.0), 0.0, Vector2(1.0, 0.3))
	draw_circle(Vector2.ZERO, 16.0 + 18.0 * t, tone)
	draw_set_transform(Vector2.ZERO)


func _height(drop: Dictionary) -> float:
	var t := clampf((now - float(drop.born)) / maxf(0.01, float(drop.fall)), 0.0, 1.0)
	if bool(drop.bounced):
		return 1.0 - 0.6 * sin(PI * t)
	return t


func _draw_drop(drop: Dictionary) -> void:
	var kind := str(drop.kind)
	var since := age(float(drop.at))
	var at := Vector2(_x(float(drop.x)), _y(_height(drop)))
	var spin := 0.0 if reduced_motion else now * (2.0 if kind == "big" else 3.0) + float(drop.id)
	match str(drop.state):
		"caught":
			# Off into the nearest basket in a little arc.
			var basket: Vector2 = BASKETS[0] if float(drop.x) < 0.5 else BASKETS[1]
			var t := clampf(since / 0.5, 0.0, 1.0)
			if t >= 1.0:
				glint(basket + Vector2(0, -10), 26.0, 99.0, -(since - 0.5))
				return
			var start := Vector2(_x(float(drop.x)), NET_Y)
			at = start.lerp(basket, t) + Vector2(0, -160.0 * sin(PI * t))
			_stamp_drop(kind, at, spin * 2.0, 1.0 - 0.4 * t)
		"missed":
			# Down past the net to the deck, where it fizzles out.
			var t := clampf(since / 0.35, 0.0, 1.0)
			at = Vector2(at.x, lerpf(NET_Y, DECK_Y - 10.0, t))
			var fade := 1.0 - clampf((since - 0.35) / 0.45, 0.0, 1.0)
			if fade > 0.0:
				_stamp_drop(kind, at, spin, 1.0, fade * (0.6 if kind != "thunder" else 1.0))
		"zapped":
			if since < 0.3:
				_stamp_drop(kind, Vector2(at.x, NET_Y), spin, 1.0 + since)
		_:
			if not reduced_motion and kind != "thunder":
				for spark in 3:
					var back := at - Vector2(0, 14.0 + spark * 14.0)
					draw_rect(Rect2(back - Vector2(2, 2), Vector2(4, 4)), Color(GOLD_STAR, 0.5 - spark * 0.15))
			_stamp_drop(kind, at, spin, 1.0)


func _stamp_drop(kind: String, at: Vector2, spin: float, grow: float, alpha := 1.0) -> void:
	var sprite: ImageTexture = _star
	var size := 11.0
	var angle := spin
	match kind:
		"big":
			sprite = _big
			size = 17.0
		"thunder":
			sprite = _storm
			size = 15.0
			angle = 0.0 if reduced_motion else sin(now * 20.0) * 0.08
	var scale_factor := TEXEL * grow
	draw_set_transform(at, angle, Vector2.ONE)
	stamp(sprite, -Vector2(size, size * (12.0 / 15.0 if kind == "thunder" else 1.0)) * 0.5 * scale_factor, scale_factor, Color(NOON, alpha))
	draw_set_transform(Vector2.ZERO)
	if kind == "thunder" and alpha > 0.5 and not reduced_motion and fposmod(now * 6.0, 1.0) < 0.5:
		_bolt(at + Vector2(16, 18), 0.8)


func _bolt(at: Vector2, size: float) -> void:
	var shape := PackedVector2Array([Vector2(0, 0), Vector2(8, 0), Vector2(3, 9), Vector2(10, 9), Vector2(-2, 26), Vector2(2, 13), Vector2(-4, 13)])
	var placed := PackedVector2Array()
	for point in shape:
		placed.append(at + point * size * 1.6)
	draw_colored_polygon(placed, BOLT)


func _draw_hero() -> void:
	var feet := Vector2(_x(float(state.get("hero_x", 0.5))), DECK_Y + 4.0)
	var zapped := _zapped()
	var facing := int(state.get("facing", 0))
	var lean := 0.0 if reduced_motion or zapped >= 0.0 else facing * 0.1
	var shake := Vector2.ZERO
	if zapped >= 0.0 and zapped < 0.5 and not reduced_motion:
		shake = Vector2(sin(now * 70.0) * 5.0, 0)
	ground_shadow(feet + Vector2(4, 0), Vector2(54, 12), 0.42)
	if facing != 0 and str(state.get("stage", "")) == "play" and zapped < 0.0:
		dust_puffs(feet - Vector2(facing * 34.0, 4.0), fposmod(now, 0.4), 24.0)
	draw_set_transform(feet + shake, lean, Vector2.ONE)
	stamp(Hero.texture(&"up", true, "shocked" if zapped >= 0.0 else "plain"), -Vector2(20, 46) * HERO_SCALE, HERO_SCALE, NOON)
	draw_set_transform(Vector2.ZERO)
	_draw_net(feet + shake, zapped)
	if zapped >= 0.0:
		_frizz(feet + shake)
		var head := feet + shake + Vector2(0, -200)
		for puff in 4:
			var rise := 0.5 if reduced_motion else fposmod(zapped * 0.7 + puff * 0.25, 1.0)
			draw_circle(head + Vector2(-36 + puff * 24.0, -10.0 - rise * 70.0), 16.0 + rise * 14.0, Color(SMOKE.darkened(0.2), 0.75 * (1.0 - rise * 0.8)))
		if not reduced_motion and fposmod(now * 8.0, 1.0) < 0.6:
			_bolt(feet + Vector2(-70, -120), 0.9)
			_bolt(feet + Vector2(58, -90), 0.7)


## Hair standing straight up on end after a zap: a tall spiky shock in front
## of the net, with singed light tips.
func _frizz(feet: Vector2) -> void:
	var crown := feet + Vector2(0, -46.0 * HERO_SCALE + 18.0)
	for spike in 11:
		var x := -40.0 + spike * 8.0
		var tall := 64.0 + 22.0 * Pixels.noise(spike, 0, 13)
		var root := crown + Vector2(x, 0)
		var tip := root + Vector2(x * 0.35, -tall)
		draw_colored_polygon(PackedVector2Array([root + Vector2(-7, 0), tip, root + Vector2(7, 0)]), Color("#1f2547"))
		draw_colored_polygon(PackedVector2Array([root + Vector2(-4, -2), tip + Vector2(0, 6), root + Vector2(4, -2)]), Color("#2f3660"))
		draw_circle(tip, 3.0, Color("#e9dcc0"))


func _draw_net(feet: Vector2, zapped: float) -> void:
	# A wooden hoop as wide as the part that catches, with a mesh bag sagging below.
	var half := float(state.get("net_half", 0.08)) * WIDE
	var centre := Vector2(feet.x, NET_Y)
	var frame := WOOD if zapped < 0.0 else Color("#3a3434")
	var mesh := MESH if zapped < 0.0 else SMOKE
	var bag := PackedVector2Array()
	for step in 13:
		var t := step / 12.0
		bag.append(centre + Vector2(lerpf(-half, half, t), 26.0 * sin(PI * t)))
	draw_colored_polygon(bag, Color(mesh, 0.25))
	for strand in 7:
		var x := lerpf(-half, half, strand / 6.0)
		draw_line(centre + Vector2(x, 0), centre + Vector2(x * 0.6, 26.0 * sin(PI * strand / 6.0)), Color(mesh, 0.8), 2.0)
	draw_polyline(bag, Color(mesh, 0.9), 2.0)
	for handle: float in [-0.7, 0.7]:
		draw_line(feet + Vector2(handle * 26.0, -126), centre + Vector2(handle * half * 0.55, 6), DARK_WOOD, 6.0)
	draw_set_transform(centre, 0.0, Vector2(1.0, 0.28))
	draw_arc(Vector2.ZERO, half, 0.0, TAU, 32, DARK_WOOD.darkened(0.3), 16.0)
	draw_arc(Vector2.ZERO, half, 0.0, TAU, 32, frame, 10.0)
	draw_arc(Vector2(0, -3), half, PI * 1.1, PI * 1.9, 16, frame.lightened(0.3), 4.0)
	draw_set_transform(Vector2.ZERO)


func _draw_combo() -> void:
	var combo := int(state.get("combo", 0))
	if combo >= 4:
		label(Vector2(1110, 520), "連接 × %d" % combo, 26, GOLD_STAR, 1.0 + 0.08 * pulse(2.0))


# --- Texel painters -------------------------------------------------------------

func _paint_star(x: int, y: int, size: int) -> Color:
	# A plump five-pointed star with a sleepy smile.
	var c := Vector2(size * 0.5, size * 0.53)
	var at := Vector2(x + 0.5, y + 0.5) - c
	var angle := fposmod(at.angle() + PI * 0.5, TAU / 5.0) - TAU / 10.0
	var reach := size * 0.5 * (0.55 + 0.45 * pow(cos(angle * 2.5), 6.0))
	if at.length() > reach:
		return Pixels.CLEAR
	var face := at / (size * 0.5)
	if size >= 11 and absf(face.y + 0.05) < 0.08 and absf(absf(face.x) - 0.22) < 0.08:
		return Color("#5a3a2a")
	if size >= 11 and absf(face.y - 0.22) < 0.07 and absf(face.x) < 0.16:
		return Color("#c0503f")
	return Pixels.lit(GOLD_STAR, 0.5 - (face.x + face.y) * 0.6, x, y)


func _paint_storm(x: int, y: int) -> Color:
	# A dark, lumpy thundercloud ball with a cross little face.
	var at := Vector2(x + 0.5, y + 0.5)
	for puff: Vector3 in [Vector3(5, 7, 4.2), Vector3(10, 7, 4.2), Vector3(7.5, 4.5, 4.4)]:
		var offset := (at - Vector2(puff.x, puff.y)) / puff.z
		if offset.length() <= 1.0:
			if y == 6 and (x == 5 or x == 9):
				return BOLT
			if y == 8 and x >= 6 and x <= 8:
				return Color("#1e2038")
			return Pixels.lit(STORM, 0.4 - offset.y - offset.x * 0.3, x, y)
	return Pixels.CLEAR


func _paint_basket(x: int, y: int) -> Color:
	# A woven basket with a lip and a few caught stars glowing inside.
	if y <= 2:
		if Pixels.noise(x, y, 5) > 0.6 and x > 2 and x < 15:
			return GOLD_STAR
		if y == 2:
			return WICKER.darkened(0.3)
		return Pixels.CLEAR
	var inset := (y - 3) * 0.35
	if x < inset or x >= 18 - inset:
		return Pixels.CLEAR
	var weave := (x + y) % 3 == 0 or (x - y) % 4 == 0
	return WICKER.darkened(0.18) if weave else WICKER
