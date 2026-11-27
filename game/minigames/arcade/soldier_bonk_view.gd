extends "res://game/minigames/arcade/arcade_view.gd"
## Picture for 敲敲玩具兵: four striped sentry boxes round the island traveller
## (arcade_hero.gd) on the workshop bench. Toy soldiers in bearskin hats pop up
## behind the half-doors, the big toy mallet slams down on the one you pick, and
## the sleepy tabby that dozes on a sill wakes up cross, takes the mallet in its
## mouth and stalks off with it. Every object is baked pixel art in the
## backdrop's dusky palette.

const Hero = preload("res://game/minigames/arcade/arcade_hero.gd")
const YARD_ART := "res://assets/world/toy-clockwork-yard.webp"
const FLOOR_TOP := 300.0
## Bottom-middle of each sentry box, in driver door order: up, left, right, down.
const BOXES: Array[Vector2] = [Vector2(640, 318), Vector2(318, 496), Vector2(962, 496), Vector2(640, 652)]
const ARROWS: Array[String] = ["↑", "←", "→", "↓"]
const BOX := Vector2i(30, 36)
const ARCH := Rect2i(8, 12, 14, 20)
const HALF_DOOR := Vector2i(14, 8)
const SOLDIER := Vector2i(14, 26)
const CAT := Vector2i(22, 14)
const MALLET := Vector2i(16, 20)
const HERO_FEET := Vector2(640, 500)
const HERO_SCALE := 3.0
const WOOD := Color("#7a5238")
const STRIPE := Color("#ad573f")
const IVORY := Color("#e9d8b0")
const ROOF := Color("#5b6f9a")
const COAT := Color("#b8483a")
const FUR := Color("#2f2838")
const SKIN := Color("#ebb894")
const BRASS := Color("#c9953e")
const TABBY := Color("#9a8d86")
const DARK := Color("#2b2440")
const DUSK := Color(1.0, 0.93, 0.86)

var _has_art := false
var _box: ImageTexture
var _half: ImageTexture
var _soldier: Dictionary = {}
var _cat: Dictionary = {}
var _mallet: ImageTexture


func _init() -> void:
	super()
	word_anchor = Vector2(330, 250)


func _ready() -> void:
	_has_art = use_backdrop_art(YARD_ART, Rect2(0, 0, 1157, 600), Color(0.58, 0.52, 0.58))
	_box = Pixels.bake("bonk-box", BOX, _paint_box)
	_half = Pixels.bake("bonk-half", HALF_DOOR, func(x: int, y: int) -> Color:
		if y == 0:
			return WOOD.lightened(0.3)
		if (x == 2 or x == 11) and (y == 3 or y == 6):
			return BRASS
		return Pixels.wood(STRIPE.darkened(0.15) if (x / 3) % 2 == 0 else IVORY.darkened(0.12), x, y, 3))
	for mood: String in ["plain", "bonked", "tease"]:
		_soldier[mood] = Pixels.bake("bonk-soldier|" + mood, SOLDIER, _paint_soldier.bind(mood))
	for mood: String in ["sleep", "cross"]:
		_cat[mood] = Pixels.bake("bonk-cat|" + mood, CAT, _paint_cat.bind(mood))
	_mallet = Pixels.bake("bonk-mallet", MALLET, _paint_mallet)


func _draw_backdrop() -> void:
	if not _has_art:
		draw_rect(Rect2(Vector2.ZERO, DESIGN), Color("#3a2c2a"))
	bench(FLOOR_TOP, WOOD)
	vignette()


func _draw_scene() -> void:
	var doors: Array = state.get("doors", [])
	if doors.size() != BOXES.size():
		return
	# Far boxes first, the hero in the middle, the near box last.
	for index: int in [0, 1, 2]:
		_draw_box(index, doors[index])
	_draw_hero()
	_draw_box(3, doors[3])
	_draw_slam()
	_draw_cat_walk()
	_draw_streak()


# --- Sentry boxes -----------------------------------------------------------

func _box_origin(index: int) -> Vector2:
	return BOXES[index] - Vector2(BOX.x * 0.5, BOX.y) * TEXEL


func _draw_box(index: int, door: Dictionary) -> void:
	var origin := _box_origin(index)
	var kind := str(door.kind)
	var since := age(float(door.at))
	ground_shadow(BOXES[index] + Vector2(10, 2), Vector2(70, 12), 0.38)
	cast_shadow(_box, origin, Vector2(10, 8), TEXEL, 0.22)
	stamp(_box, origin, TEXEL, DUSK)
	var sill := origin + Vector2(ARCH.position.x, ARCH.end.y - HALF_DOOR.y) * TEXEL
	var doorway_bottom := origin.y + ARCH.end.y * TEXEL
	match kind:
		"soldier", "feint", "escaped", "bonked":
			var rise := pop_in(since, 0.14)
			var mood := "plain"
			var stretch := Vector2.ONE
			if kind == "feint":
				rise = 0.45 * sin(clampf(since / 0.32, 0.0, 1.0) * PI) if not reduced_motion else 0.4
			elif kind == "escaped":
				mood = "tease"
				rise = 1.0 - smoothstep(0.25, 0.5, since)
			elif kind == "bonked":
				mood = "bonked"
				rise = 0.55 - 0.55 * smoothstep(0.1, 0.45, since)
				stretch = squash(since, 0.35, 0.3)
			_draw_soldier(origin, doorway_bottom, rise, mood, stretch)
			if kind == "escaped" and since < 0.4:
				label(origin + Vector2(BOX.x * 2.0, -10), "嘿嘿～", 20, IVORY)
			if kind == "bonked":
				_draw_stars(origin + Vector2(BOX.x * 2.0, ARCH.position.y * TEXEL - 6.0), since)
		"cat", "snatch":
			if kind == "cat":
				var breathe := 1.0 + 0.04 * pulse(0.5)
				draw_set_transform(sill + Vector2(HALF_DOOR.x * 2.0, 0), 0.0, Vector2(1.0, breathe))
				stamp(_cat["sleep"], Vector2(-CAT.x * 2.0, -CAT.y * TEXEL + 8.0), TEXEL, DUSK)
				draw_set_transform(Vector2.ZERO)
				if not reduced_motion:
					label(sill + Vector2(70, -60 - 10.0 * pulse(0.6)), "Z z", 20, IVORY, 1.0, 0.8)
	stamp(_half, sill, TEXEL, DUSK)
	# The arrow that opens this box, on a key cap by its side.
	var cap_at: Vector2 = BOXES[index] + [Vector2(96, -70), Vector2(0, 34), Vector2(0, 34), Vector2(-96, -70)][index]
	key_cap(cap_at, ARROWS[index], age(float(state.get("swing_at", -99.0))) < 0.12 and int(state.get("swing_door", -1)) == index, 22)


## A soldier `rise` (0..1) of the way up out of the doorway, hidden below its bottom.
func _draw_soldier(origin: Vector2, bottom: float, rise: float, mood: String, stretch: Vector2) -> void:
	if rise <= 0.01:
		return
	var sprite: ImageTexture = _soldier[mood]
	var full := Vector2(sprite.get_size()) * TEXEL
	var top := bottom - (SOLDIER.y + 1) * TEXEL * rise - TEXEL
	var shown := clampf((bottom - top) / TEXEL, 0.0, sprite.get_size().y)
	var left := origin.x + (BOX.x * 0.5 - SOLDIER.x * 0.5) * TEXEL - TEXEL
	var pivot := Vector2(left + full.x * 0.5, bottom)
	draw_set_transform(pivot, 0.0, stretch)
	draw_texture_rect_region(sprite, Rect2(Vector2(left, top) - pivot, Vector2(full.x, shown * TEXEL)), Rect2(0, 0, sprite.get_size().x, shown), DUSK)
	draw_set_transform(Vector2.ZERO)


func _draw_stars(at: Vector2, since: float) -> void:
	dust_puffs(at + Vector2(0, 40), since, 50.0)
	for star in 3:
		var angle := star * TAU / 3.0 + (0.0 if reduced_motion else since * 7.0)
		var star_at := at + Vector2(cos(angle) * 34.0, sin(angle) * 10.0)
		draw_rect(Rect2(star_at - Vector2(8, 3), Vector2(16, 6)), DARK)
		draw_rect(Rect2(star_at - Vector2(3, 8), Vector2(6, 16)), DARK)
		draw_rect(Rect2(star_at - Vector2(5, 1), Vector2(10, 2)), GOLD)
		draw_rect(Rect2(star_at - Vector2(1, 5), Vector2(2, 10)), GOLD)


# --- Hero and mallet --------------------------------------------------------

func _draw_hero() -> void:
	var swing := int(state.get("swing_door", -1))
	var swung := age(float(state.get("swing_at", -99.0)))
	var armed := bool(state.get("has_mallet", true))
	var pose := &"idle"
	if swung < 0.3 and swing >= 0:
		pose = [&"up", &"left", &"right", &"idle"][swing]
	var mood := "plain" if armed else "shocked"
	if armed and swung < 0.3:
		mood = "tongue" if swing >= 0 and swung < 0.15 else "plain"
	var sprite := Hero.texture(pose, true, mood)
	ground_shadow(HERO_FEET + Vector2(6, 2), Vector2(56, 13), 0.42)
	stamp(sprite, HERO_FEET - Hero.FEET * HERO_SCALE + Vector2.ONE * HERO_SCALE, HERO_SCALE, DUSK)
	if armed and (swung >= 0.3 or swing < 0):
		# Resting on the shoulder, head up.
		var hand := HERO_FEET - Hero.FEET * HERO_SCALE + Vector2(31, 33) * HERO_SCALE
		_stamp_mallet(hand + Vector2(4, 6), 0.55, 1.0)
	if not armed:
		label(HERO_FEET + Vector2(0, -170), "我的槌子！", 22, ROSE)


## The mallet slams down onto the box that was picked.
func _draw_slam() -> void:
	var swing := int(state.get("swing_door", -1))
	var swung := age(float(state.get("swing_at", -99.0)))
	if swing < 0 or swung >= 0.3 or not bool(state.get("has_mallet", true)):
		return
	var origin := _box_origin(swing)
	var target := origin + Vector2(BOX.x * 0.5, ARCH.position.y + 3) * TEXEL
	var t := clampf(swung / 0.1, 0.0, 1.0) if not reduced_motion else 1.0
	# The head comes down on the doorway from the hero's side, swung up and over.
	var toward := (target - (HERO_FEET - Vector2(0, 70))).normalized()
	var reach := (MALLET.y - 4) * TEXEL * 1.25
	var hand := target - toward * reach
	var strike := atan2(toward.x, -toward.y)
	_stamp_mallet(hand, strike - 1.3 * (1.0 - t * t) * (1.0 if toward.x >= 0.0 else -1.0), 1.25)
	if swung < 0.12:
		glint(target, 24.0, 99.0, -swung)


## Mallet held at `hand`, head toward `angle` (0 points the head up-left onto the target).
func _stamp_mallet(hand: Vector2, angle: float, size: float) -> void:
	draw_set_transform(hand, angle, Vector2.ONE * size)
	stamp(_mallet, Vector2(-8.0, -MALLET.y) * TEXEL, TEXEL, DUSK)
	draw_set_transform(Vector2.ZERO)


## The cat stalks off along the bench edge with the mallet in its mouth, tail up.
func _draw_cat_walk() -> void:
	var door := int(state.get("snatch_door", -1))
	if door < 0:
		return
	var back := float(state.get("mallet_back_at", -99.0))
	var since := 2.2 - (back - now)
	var start := BOXES[door] + Vector2(0, 30)
	var t := clampf(since / 2.2, 0.0, 1.0)
	var at := start.lerp(Vector2(1180, 610), smoothstep(0.1, 1.0, t))
	var step := 0.0 if reduced_motion else absf(sin(since * 9.0)) * 4.0
	ground_shadow(at + Vector2(0, 4), Vector2(48, 9), 0.35)
	_stamp_mallet(at + Vector2(-34, -40 - step), 1.35, 0.75)
	stamp(_cat["cross"], at - Vector2(CAT.x * 2.0, CAT.y * TEXEL + step), TEXEL, DUSK)
	if since < 0.6:
		label(at + Vector2(0, -90), "哼！", 28, ROSE, pop_in(since, 0.2))


func _draw_streak() -> void:
	var streak := int(state.get("streak", 0))
	if streak < 2:
		return
	label(Vector2(1120, 236), "連敲 × %d" % streak, 26, GOLD, 1.0 + 0.08 * pulse(2.0))


# --- Texel painters ---------------------------------------------------------

func _paint_box(x: int, y: int) -> Color:
	var at := Vector2(x + 0.5, y + 0.5)
	var middle := BOX.x * 0.5
	# Peaked roof with an overhang and a brass finial.
	if y < 3:
		return BRASS.lightened(0.1) if absf(at.x - middle) < 1.5 else Pixels.CLEAR
	if y < 12:
		var reach := 3.0 + (y - 3) * 1.6
		if absf(at.x - middle) > reach:
			return Pixels.CLEAR
		return Pixels.shingle(ROOF, x, y, 4, 3) if y < 11 else ROOF.darkened(0.45)
	if x < 2 or x >= BOX.x - 2:
		return Pixels.CLEAR if y < 13 else Pixels.wood(WOOD.darkened(0.1), x, y, 2)
	if y >= BOX.y - 3:
		return Pixels.wood(WOOD.darkened(0.25), x, y, 6, false) if y > BOX.y - 3 else WOOD.lightened(0.2)
	var arch := Rect2(ARCH)
	var round_top := (at - Vector2(arch.get_center().x, arch.position.y + 4.0)) / Vector2(arch.size.x * 0.5, 4.0)
	if arch.has_point(at) and (at.y > arch.position.y + 4.0 or round_top.length() < 1.0):
		# A dark doorway, lighter toward its sill.
		return Color("#1d1420").lightened(0.06 * (at.y - arch.position.y) / arch.size.y)
	if arch.grow(1.0).has_point(at) and (at.y > arch.position.y + 3.0 or round_top.length() < 1.3):
		return Pixels.grainy(IVORY.darkened(0.15), x, y, 0.1)
	var stripe := (x - 2) / 4 % 2 == 0
	return Pixels.wood(STRIPE if stripe else IVORY.darkened(0.08), x, y, 4)


func _paint_soldier(x: int, y: int, mood: String) -> Color:
	var at := Vector2(x + 0.5, y + 0.5)
	# Tall bearskin hat with a chin strap, a round face, a red coat with crossed white belts.
	var hat := (at - Vector2(7.0, 5.5)) / Vector2(5.2, 5.6)
	if y < 10 and hat.length() <= 1.0:
		if mood == "bonked" and y < 2:
			return Pixels.CLEAR
		return Pixels.grainy(FUR.lightened(0.12) if Pixels.noise(x, y, 4) > 0.6 else FUR, x, y, 0.1)
	if y >= 9 and y < 15:
		if x < 3 or x > 10:
			return Pixels.CLEAR
		if y == 14 and (x == 3 or x == 10):
			return BRASS
		var eye_row := y == 11
		if eye_row and (x == 5 or x == 8):
			if mood == "bonked":
				return DARK.lightened(0.2)
			return DARK
		if mood == "tease" and y == 13 and x >= 6 and x <= 7:
			return Color("#ff7fa0")
		if y == 13 and x >= 5 and x <= 8 and mood != "tease":
			return COAT.darkened(0.2) if mood == "plain" else DARK
		if (x == 4 or x == 9) and y == 12:
			return Color("#f08c8c")
		return Pixels.rounded(SKIN, Vector2((at.x - 7.0) / 4.0, (at.y - 12.0) / 3.0))
	if y >= 15 and y < 24:
		if x < 2 or x > 11:
			return Pixels.CLEAR
		var belt := absf((x - 2) - (y - 15)) < 1.0 or absf((11 - x) - (y - 15)) < 1.0
		if belt:
			return IVORY
		if x == 7 and y % 2 == 0:
			return BRASS
		if x < 3 or x > 10:
			return COAT.darkened(0.2) if y < 22 else SKIN
		return Pixels.grainy(COAT, x, y, 0.08)
	if y >= 24:
		return Color("#3d4a78") if x >= 3 and x <= 10 and x != 7 else Pixels.CLEAR
	return Pixels.CLEAR


func _paint_cat(x: int, y: int, mood: String) -> Color:
	var at := Vector2(x + 0.5, y + 0.5)
	var cross := mood == "cross"
	# A loaf of tabby; cross, it stands with its back up and its tail straight.
	var body := (at - Vector2(11.0, 9.5 if not cross else 8.0)) / Vector2(8.0, 4.2 if not cross else 4.6)
	var head := (at - Vector2(4.5, 8.5 if not cross else 6.0)) / Vector2(4.2, 3.6)
	var tail := Rect2(19, 3 if cross else 9, 2, 8 if cross else 3)
	if cross and (Rect2(7, 11, 2, 3).has_point(at) or Rect2(15, 11, 2, 3).has_point(at)):
		return TABBY.darkened(0.2)
	if y < 5 and (absf(at.x - (2.0 if not cross else 2.0)) < 1.2 or absf(at.x - 6.5) < 1.2) and y >= (4 if not cross else 1):
		return TABBY.darkened(0.15)
	if head.length() <= 1.0:
		var eye_y := 8 if not cross else 5
		if y == eye_y and (x == 3 or x == 6):
			return DARK if not cross else Color("#e8c94a")
		if y == eye_y + 2 and x >= 3 and x <= 5:
			return Color("#d9727d") if cross else TABBY.darkened(0.3)
		return Pixels.rounded(TABBY.lightened(0.08), head)
	if body.length() <= 1.0 or tail.has_point(at):
		var stripe := (x + (2 if y > 9 else 0)) % 4 == 0
		var base := TABBY.darkened(0.28) if stripe else TABBY
		return Pixels.rounded(base, body) if body.length() <= 1.0 else base
	return Pixels.CLEAR


func _paint_mallet(x: int, y: int) -> Color:
	# A barrel head with red bands on a long turned handle.
	if y < 8:
		if x < 1 or x > 14:
			return Pixels.CLEAR
		if x < 3 or x > 12:
			return Pixels.grainy(COAT, x, y, 0.1)
		return Pixels.wood(Color("#c8a676"), x, y, 3, false)
	if x >= 7 and x <= 8:
		return Pixels.wood(WOOD.lightened(0.1), x, y, 2) if y < 18 else BRASS
	return Pixels.CLEAR
