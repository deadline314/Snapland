extends "res://game/minigames/arcade/arcade_view.gd"
## Picture for 磁鐵搬家: a riveted lattice girder across the toy workshop with a
## yellow trolley, a chain and a big red horseshoe magnet. Toys tumble out of the
## "old home" hopper onto a conveyor belt that runs to a dented recycling bin;
## the "new home" crate waits at the left end. The island traveller (arcade_hero)
## works the crane lever in a tin helmet, which is the iron the magnet grabs when
## it finds no toy. Every object is baked pixel art in the backdrop's dusk palette.

const Hero = preload("res://game/minigames/arcade/arcade_hero.gd")
const YARD_ART := "res://assets/world/toy-clockwork-yard.webp"
const RAIL_LEFT := 70.0
const RAIL_RIGHT := 1210.0
const GIRDER := Rect2(24, 146, 1232, 40)
const TROLLEY := Vector2i(30, 8)
const TROLLEY_TOP := 182.0
## Top of the magnet at rest, and how far its bottom travels down to the toys.
const MAGNET_TOP := 226.0
const MAGNET := Vector2i(24, 20)
const DROP_DEPTH := 132.0
const HEAVY_SAG := 30.0
const BELT_Y := 528.0
const TABLE_TOP := 474.0
const BOX := Vector2i(32, 22)
const BOX_BOTTOM := 568.0
const BIN := Vector2i(24, 24)
const BIN_AT := Vector2(1198, 612)
const HOPPER := Vector2i(26, 20)
const HOPPER_BOTTOM := 436.0
const CONSOLE := Vector2i(16, 20)
const CONSOLE_FEET := Vector2(902, 700)
const HERO_FEET := Vector2(1010, 700)
const HERO_SCALE := 3.0
const HELMET := Vector2i(22, 10)
## Where the hero's helmet sits on the hero sprite, in its texels.
const HELMET_ON := Vector2(9, -1)
const HELMET_TOP := Vector2(20, -1)
const SIZES := {
	"robot": Vector2i(12, 16), "woodbot": Vector2i(12, 16), "car": Vector2i(18, 10), "drum": Vector2i(12, 12),
	"mouse": Vector2i(14, 9), "block": Vector2i(11, 11), "duck": Vector2i(14, 12), "weight": Vector2i(22, 16),
}
## Where held toys cling: under the magnet's middle, then to its left and right.
const SLOTS: Array[Vector2] = [Vector2(0, -6), Vector2(-44, 10), Vector2(44, 10)]
## Toys are drawn a size up from the workshop props so they read at a glance.
const TOY_TEXEL := 5.0
const WOOD := Color("#7a5238")
const GIRDER_PAINT := Color("#b5553c")
const YELLOW := Color("#d9a64e")
const MAGNET_RED := Color("#c8423a")
const STEEL := Color("#c3c8cf")
const TIN := Color("#a9b0b8")
const TIN_BLUE := Color("#4f79a8")
const IRON := Color("#4a4e57")
const BELT := Color("#3a3340")
const FRAME := Color("#567f77")
const PINE := Color("#d2a46a")
const PAINT_RED := Color("#c0503f")
const DUCK := Color("#e8b84a")
const DARK := Color("#2b2440")
const LABEL := Color("#efe0bc")
const DUSK := Color(1.0, 0.93, 0.86)

var _has_art := false
var _girder: ImageTexture
var _trolley: ImageTexture
var _magnet: ImageTexture
var _box_back: ImageTexture
var _box_front: ImageTexture
var _bin: ImageTexture
var _hopper: ImageTexture
var _console: ImageTexture
var _helmet: ImageTexture
var _tread: ImageTexture
var _toys: Dictionary = {}


func _init() -> void:
	super()
	word_anchor = Vector2(640, 380)


func _ready() -> void:
	_has_art = use_backdrop_art(YARD_ART, Rect2(190, 0, 1157, 651), Color(0.58, 0.52, 0.58))
	var girder_size := Vector2i(int(GIRDER.size.x / TEXEL), int(GIRDER.size.y / TEXEL))
	_girder = Pixels.bake("magnet-girder", girder_size, _paint_girder.bind(girder_size))
	_trolley = Pixels.bake("magnet-trolley", TROLLEY, _paint_trolley)
	_magnet = Pixels.bake("magnet-horseshoe", MAGNET, _paint_magnet)
	_box_back = Pixels.bake("magnet-box-back", BOX, _paint_box.bind(true))
	_box_front = Pixels.bake("magnet-box-front", BOX, _paint_box.bind(false))
	_bin = Pixels.bake("magnet-bin", BIN, _paint_bin)
	_hopper = Pixels.bake("magnet-hopper", HOPPER, _paint_hopper)
	_console = Pixels.bake("magnet-console", CONSOLE, _paint_console)
	_helmet = Pixels.bake("magnet-helmet", HELMET, _paint_helmet)
	_tread = Pixels.bake("magnet-tread", Vector2i(int((_belt_right() - _belt_left()) / TEXEL) + 8, 3), func(x: int, y: int) -> Color:
		if y == 0:
			return BELT.lightened(0.25) if x % 4 != 0 else BELT.darkened(0.2)
		return Pixels.grainy(BELT if x % 4 != 0 else BELT.darkened(0.35), x, y, 0.12))
	for kind: String in SIZES:
		_toys[kind] = Pixels.bake("magnet-toy|" + kind, SIZES[kind], _paint_toy.bind(kind))


func _draw_backdrop() -> void:
	if not _has_art:
		draw_rect(Rect2(Vector2.ZERO, DESIGN), Color("#3a2c2a"))
	bench(TABLE_TOP, WOOD)
	vignette()


func _draw_scene() -> void:
	if not state.has("toys"):
		return
	# Feedback words pop on the far side from the crane, clear of whatever hangs from it.
	word_anchor = Vector2(880.0 if float(state.get("crane_x", 0.5)) < 0.5 else 400.0, 330.0)
	_draw_frame_posts()
	_draw_hopper()
	_draw_box_back()
	_draw_belt()
	for toy: Dictionary in state.toys:
		if str(toy.state) == "belt":
			_draw_belt_toy(toy)
	_draw_bin()
	_draw_console()
	_draw_hero_standing()
	_draw_girder()
	_draw_crane()
	_draw_boxing()
	_draw_box_front()
	_draw_hero_hanging()


# --- Placement ----------------------------------------------------------------

func _sx(x: float) -> float:
	return lerpf(RAIL_LEFT, RAIL_RIGHT, x)


func _belt_left() -> float:
	return _sx(float(state.get("belt_start", 0.2))) - 34.0 if not state.is_empty() else 262.0


func _belt_right() -> float:
	return _sx(float(state.get("belt_end", 0.95))) + 20.0 if not state.is_empty() else 1173.0


## How far the magnet hangs below its rest height right now.
func _magnet_drop() -> float:
	var times: Array = state.get("drop_seconds", [0.16, 0.06, 0.2])
	var since := age(float(state.get("drop_at", -99.0)))
	var down := float(times[0])
	var hold := float(times[1])
	var up := float(times[2])
	var depth := 0.0
	if since >= 0.0 and since < down:
		depth = since / down
		depth *= depth
	elif since >= down and since < down + hold:
		depth = 1.0
	elif since >= down + hold and since < down + hold + up:
		depth = 1.0 - smoothstep(0.0, 1.0, (since - down - hold) / up)
	var sag := HEAVY_SAG if bool(state.get("heavy", false)) else 0.0
	var full := age(float(state.get("full_at", -99.0)))
	var jolt := 0.0 if reduced_motion or full > 0.3 else 6.0 * sin(full * 40.0) * (1.0 - full / 0.3)
	return depth * (DROP_DEPTH - sag * 0.5) + sag + jolt


func _magnet_origin() -> Vector2:
	var x := _sx(float(state.get("crane_x", 0.5)))
	return Vector2(x - MAGNET.x * TEXEL * 0.5, MAGNET_TOP + _magnet_drop())


func _magnet_bottom() -> Vector2:
	return _magnet_origin() + Vector2(MAGNET.x * TEXEL * 0.5, MAGNET.y * TEXEL)


# --- Workshop -----------------------------------------------------------------

func _draw_frame_posts() -> void:
	# Two riveted posts carry the girder down to the table.
	for x: float in [GIRDER.position.x + 6.0, GIRDER.end.x - 30.0]:
		var post := Rect2(x, GIRDER.end.y - 8.0, 24, TABLE_TOP + 40.0 - GIRDER.end.y)
		draw_rect(Rect2(post.position + Vector2(8, 6), post.size), Color(SPRITE_SHADE, 0.3))
		panel(post, "enamel", GIRDER_PAINT.darkened(0.2), YELLOW, TEXEL, DUSK)
		ground_shadow(Vector2(post.get_center().x + 6.0, post.end.y), Vector2(26, 6), 0.4)


func _draw_girder() -> void:
	cast_shadow(_girder, GIRDER.position, Vector2(6, 12), TEXEL, 0.22)
	stamp(_girder, GIRDER.position, TEXEL, DUSK)


func _draw_hopper() -> void:
	var at := Vector2(_sx(float(state.get("belt_start", 0.2))) - HOPPER.x * TEXEL * 0.5, HOPPER_BOTTOM - HOPPER.y * TEXEL)
	# The chute hangs from the girder on two rods.
	for side: float in [16.0, HOPPER.x * TEXEL - 20.0]:
		draw_rect(Rect2(at.x + side, GIRDER.end.y - 4.0, 4, at.y - GIRDER.end.y + 8.0), DARK.lightened(0.1))
	cast_shadow(_hopper, at, Vector2(8, 10), TEXEL, 0.22)
	stamp(_hopper, at, TEXEL, DUSK)
	label(at + Vector2(HOPPER.x * TEXEL * 0.5, 28), "舊家", 20, LABEL)


func _draw_box_back() -> void:
	var at := Vector2(_sx(float(state.get("box_x", 0.07))) - BOX.x * TEXEL * 0.5, BOX_BOTTOM - BOX.y * TEXEL)
	ground_shadow(Vector2(at.x + BOX.x * TEXEL * 0.5 + 8.0, BOX_BOTTOM), Vector2(76, 12), 0.42)
	stamp(_box_back, at, TEXEL, DUSK)


func _draw_box_front() -> void:
	var at := Vector2(_sx(float(state.get("box_x", 0.07))) - BOX.x * TEXEL * 0.5, BOX_BOTTOM - BOX.y * TEXEL)
	var landed := age(float(state.get("boxed_at", -99.0))) - 0.18
	draw_set_transform(Vector2(at.x + BOX.x * TEXEL * 0.5, BOX_BOTTOM), 0.0, squash(landed, 0.08, 0.3))
	stamp(_box_front, Vector2(-BOX.x * TEXEL * 0.5, -BOX.y * TEXEL), TEXEL, DUSK)
	draw_set_transform(Vector2.ZERO)
	label(at + Vector2(BOX.x * TEXEL * 0.5, 54), "新家", 22, DARK, 1.0, 1.0, false)


func _draw_belt() -> void:
	var left := _belt_left()
	var right := _belt_right()
	# Legs, then the frame, then the moving tread on top with a roller at each end.
	for x: float in [left + 30.0, (left + right) * 0.5, right - 40.0]:
		draw_rect(Rect2(x, BELT_Y + 30.0, 14, 26), WOOD.darkened(0.35))
		draw_rect(Rect2(x + 2.0, BELT_Y + 30.0, 4, 26), WOOD.darkened(0.1))
		ground_shadow(Vector2(x + 10.0, BELT_Y + 56.0), Vector2(18, 5), 0.38)
	ground_shadow(Vector2((left + right) * 0.5 + 10.0, BELT_Y + 58.0), Vector2((right - left) * 0.5, 10), 0.3)
	panel(Rect2(left, BELT_Y + 2.0, right - left, 30), "enamel", FRAME, YELLOW, TEXEL, DUSK)
	var shift := fposmod(float(state.get("belt_run", 0.0)) * (RAIL_RIGHT - RAIL_LEFT), 16.0)
	var width := right - left
	draw_texture_rect_region(_tread, Rect2(left, BELT_Y - 8.0, width, 12), Rect2(4.0 - shift / TEXEL, 1, width / TEXEL, 3), DUSK)
	for x: float in [left, right]:
		var hub := Vector2(x, BELT_Y + 2.0)
		draw_circle(hub, 13.0, DARK)
		draw_circle(hub, 11.0, STEEL.darkened(0.25))
		draw_circle(hub + Vector2(-2, -2), 7.0, STEEL)
		var turn := float(state.get("belt_run", 0.0)) * 40.0
		for spoke in 3:
			draw_line(hub, hub + Vector2.from_angle(turn + spoke * TAU / 3.0) * 9.0, DARK, 2.0)


func _draw_bin() -> void:
	var at := BIN_AT - Vector2(BIN.x * 0.5, BIN.y) * TEXEL
	for toy: Dictionary in state.toys:
		if str(toy.state) == "lost":
			var since := age(float(toy.at))
			var t := clampf(since / 0.45, 0.0, 1.0)
			var spot := Vector2(lerpf(_belt_right() - 10.0, BIN_AT.x, t), BELT_Y - 30.0 * sin(t * PI * 0.7) + 90.0 * t * t)
			_stamp_toy(str(toy.kind), spot, 0.0 if reduced_motion else since * 6.0)
	ground_shadow(BIN_AT + Vector2(8, 0), Vector2(56, 11), 0.42)
	stamp(_bin, at, TEXEL, DUSK)
	label(at + Vector2(BIN.x * TEXEL * 0.5, 60), "回收", 18, LABEL)


func _draw_console() -> void:
	var at := CONSOLE_FEET - Vector2(CONSOLE.x * 0.5, CONSOLE.y) * HERO_SCALE
	ground_shadow(CONSOLE_FEET + Vector2(6, 0), Vector2(32, 8), 0.4)
	stamp(_console, at, HERO_SCALE, DUSK)
	# The lever leans the way the crane is going.
	var lean := float(state.get("push", 0.0)) * 0.5
	var pivot := at + Vector2(CONSOLE.x * 0.5, 3) * HERO_SCALE
	var tip := pivot + Vector2.from_angle(-PI * 0.5 + lean) * 30.0
	draw_line(pivot, tip, DARK, 6.0)
	draw_line(pivot, tip, STEEL.darkened(0.2), 3.0)
	draw_circle(tip, 7.0, DARK)
	draw_circle(tip, 5.0, MAGNET_RED)
	draw_circle(tip + Vector2(-2, -2), 2.0, MAGNET_RED.lightened(0.4))


# --- Toys ---------------------------------------------------------------------

## Draw a toy with its bottom middle at `foot`.
func _stamp_toy(kind: String, foot: Vector2, angle := 0.0, stretch := Vector2.ONE, tint := DUSK) -> void:
	var sprite: ImageTexture = _toys[kind]
	var size: Vector2i = SIZES[kind]
	draw_set_transform(foot, angle, stretch)
	stamp(sprite, Vector2(-size.x * 0.5, -size.y) * TOY_TEXEL, TOY_TEXEL, tint)
	draw_set_transform(Vector2.ZERO)
	if kind == "weight":
		label(foot + Vector2(0, -32) * stretch, "1噸", 18, LABEL)


func _draw_belt_toy(toy: Dictionary) -> void:
	var kind := str(toy.kind)
	var x := _sx(float(toy.x))
	var since := age(float(toy.at))
	# Fresh toys drop out of the hopper.
	var fall := 0.0 if reduced_motion else -60.0 * (1.0 - smoothstep(0.0, 0.22, since))
	var foot := Vector2(x, BELT_Y - 8.0 + fall)
	var size: Vector2i = SIZES[kind]
	ground_shadow(Vector2(x + 4.0, BELT_Y - 6.0), Vector2(size.x * 2.8, 5), 0.4)
	var crane := _sx(float(state.get("crane_x", 0.5)))
	var reach := float(state.get("grab_reach", 0.05)) * (RAIL_RIGHT - RAIL_LEFT)
	var pulled := bool(toy.iron) and absf(x - crane) <= reach and str(state.get("stage", "")) != "closing"
	var stretch := squash(age(float(toy.get("bonk_at", -99.0))), 0.3, 0.32)
	if pulled:
		# Tin under the magnet strains upward; wood never does.
		var lift := 2.0 if reduced_motion else 3.0 + 3.0 * absf(sin(now * 30.0 + float(toy.id)))
		foot.y -= lift
		var top := foot.y - size.y * TOY_TEXEL - 8.0
		for side: float in [-1.0, 1.0]:
			draw_line(Vector2(x + side * 10.0, top), Vector2(x + side * 16.0, top - 12.0), Color(LABEL, 0.85), 3.0)
	_stamp_toy(kind, foot, 0.0, stretch)
	if bool(toy.iron) and not bool(toy.heavy):
		glint(foot + Vector2(-size.x, -size.y * 3.6), 12.0, 2.6, float(toy.id) * 0.37)
	var bonked := age(float(toy.get("bonk_at", -99.0)))
	if bonked >= 0.0 and bonked < 0.5:
		dust_puffs(foot, bonked, 40.0)
		label(foot + Vector2(0, -size.y * TOY_TEXEL - 24.0), "咚", 22, LABEL, pop_in(bonked, 0.16))


## Held toys cling round the magnet's poles; boxed ones fall into the crate.
func _draw_held(bottom: Vector2) -> void:
	var held: Array = state.get("held", [])
	for index in [1, 2, 0]:
		if index >= held.size():
			continue
		var toy: Dictionary = held[index]
		var kind := str(toy.kind)
		var size: Vector2i = SIZES[kind]
		var snap := pop_in(age(float(toy.at)), 0.12)
		var foot := bottom + SLOTS[index] + Vector2(0, size.y * TOY_TEXEL)
		var from := Vector2(_sx(float(toy.x)), BELT_Y - 8.0)
		var swing := 0.0 if reduced_motion else 0.06 * sin(now * 5.0 + index)
		_stamp_toy(kind, from.lerp(foot, clampf(snap, 0.0, 1.0)), swing)


func _draw_boxing() -> void:
	var box_x := _sx(float(state.get("box_x", 0.07)))
	for toy: Dictionary in state.toys:
		if str(toy.state) != "boxed":
			continue
		var since := age(float(toy.at))
		var t := clampf(since / 0.2, 0.0, 1.0)
		var size: Vector2i = SIZES[str(toy.kind)]
		var start := _magnet_bottom().y + size.y * TOY_TEXEL
		_stamp_toy(str(toy.kind), Vector2(box_x + (int(toy.id) % 3 - 1) * 26.0, lerpf(start, BOX_BOTTOM - 20.0, t * t)))


# --- Crane --------------------------------------------------------------------

func _draw_crane() -> void:
	var x := _sx(float(state.get("crane_x", 0.5)))
	var heavy := bool(state.get("heavy", false))
	var origin := _magnet_origin()
	# The trolley rides under the girder; it tips a little under a weight.
	var trolley := Vector2(x - TROLLEY.x * TEXEL * 0.5, TROLLEY_TOP)
	var tip := 0.04 * sin(now * 3.0) if heavy and not reduced_motion else 0.0
	draw_set_transform(Vector2(x, TROLLEY_TOP), tip, Vector2.ONE)
	stamp(_trolley, Vector2(-TROLLEY.x * TEXEL * 0.5, 0), TEXEL, DUSK)
	draw_set_transform(Vector2.ZERO)
	var hook := trolley + Vector2(TROLLEY.x * TEXEL * 0.5, TROLLEY.y * TEXEL)
	Props.chain(self, hook, Vector2(x, origin.y + 6.0), 10.0, STEEL.darkened(0.3))
	# Field lines under the magnet show how wide it pulls.
	var bottom := _magnet_bottom()
	var reach := float(state.get("grab_reach", 0.05)) * (RAIL_RIGHT - RAIL_LEFT)
	if not bool(state.get("held_full", false)):
		for ring in 3:
			var grow := fposmod((0.0 if reduced_motion else now * 1.4) + ring / 3.0, 1.0)
			var radius := Vector2(lerpf(18.0, reach, grow), lerpf(6.0, 16.0, grow))
			_dotted_arc(bottom + Vector2(0, 8.0 + grow * 22.0), radius, Color(LABEL, 0.4 * (1.0 - grow)))
	_draw_held(bottom)
	cast_shadow(_magnet, origin, Vector2(8, 10), TEXEL, 0.2)
	stamp(_magnet, origin, TEXEL, DUSK)
	glint(origin + Vector2(22, 18), 14.0, 3.0)
	if heavy:
		label(Vector2(x + 70.0, TROLLEY_TOP + 10.0), "嘎…", 20, LABEL, 1.0 + 0.06 * pulse(1.5))


func _dotted_arc(center: Vector2, radius: Vector2, color: Color) -> void:
	for dot in 9:
		var angle := lerpf(PI * 0.15, PI * 0.85, dot / 8.0)
		var at := (center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y - radius.y)).round()
		draw_rect(Rect2(at - Vector2(2, 2), Vector2(4, 4)), color)


# --- Hero ---------------------------------------------------------------------

## 0 standing, 1 hanging from the magnet; eases both ways.
func _hang() -> float:
	var since := age(float(state.get("yank_at", -99.0)))
	var total := float(state.get("yank_seconds", 1.5))
	if since < 0.0 or since > total + 0.25:
		return 0.0
	if reduced_motion:
		return 1.0 if since < total else 0.0
	if since < 0.22:
		return smoothstep(0.0, 0.22, since)
	if since < total:
		return 1.0
	return 1.0 - smoothstep(total, total + 0.25, since)


func _hero_origin() -> Vector2:
	return HERO_FEET - Vector2(20, 46) * HERO_SCALE


func _draw_hero_standing() -> void:
	if _hang() > 0.0:
		ground_shadow(HERO_FEET + Vector2(6, 2), Vector2(56 * (1.0 - _hang() * 0.6), 13), 0.42 * (1.0 - _hang() * 0.5))
		return
	var push := float(state.get("push", 0.0))
	var pose := &"left" if push < 0.0 else (&"right" if push > 0.0 else &"idle")
	var landed := age(float(state.get("yank_at", -99.0))) - float(state.get("yank_seconds", 1.5)) - 0.25
	var mood := "sorry" if landed >= 0.0 and landed < 0.8 else "plain"
	var at := _hero_origin()
	ground_shadow(HERO_FEET + Vector2(6, 2), Vector2(56, 13), 0.42)
	draw_set_transform(HERO_FEET, 0.0, squash(landed, 0.25, 0.3))
	stamp(Hero.texture(pose, true, mood), at - HERO_FEET, HERO_SCALE, DUSK)
	stamp(_helmet, at - HERO_FEET + HELMET_ON * HERO_SCALE, HERO_SCALE, DUSK)
	draw_set_transform(Vector2.ZERO)
	dust_puffs(HERO_FEET, landed, 60.0)


## Yanked up by the tin helmet, the hero swings under the magnet.
func _draw_hero_hanging() -> void:
	var hang := _hang()
	if hang <= 0.0:
		return
	var since := age(float(state.get("yank_at", -99.0)))
	var stand_top := _hero_origin() + HELMET_TOP * HERO_SCALE
	var pivot := stand_top.lerp(_magnet_bottom() + Vector2(0, -6), hang)
	var swing := 0.0 if reduced_motion else 0.32 * sin(since * 7.0) * exp(-since * 0.8) * hang
	draw_set_transform(pivot, swing, Vector2.ONE)
	stamp(Hero.texture(&"up", true, "shocked"), -HELMET_TOP * HERO_SCALE, HERO_SCALE, DUSK)
	stamp(_helmet, (HELMET_ON - HELMET_TOP) * HERO_SCALE, HERO_SCALE, DUSK)
	draw_set_transform(Vector2.ZERO)
	if since < 1.2:
		label(pivot + Vector2(110, 30), "放我下來～", 20, LABEL, pop_in(since - 0.2, 0.2))


# --- Texel painters -------------------------------------------------------------

func _paint_girder(x: int, y: int, size: Vector2i) -> Color:
	# A lattice girder: two chords with rivets and zig-zag bracing between them.
	if y < 2 or y >= size.y - 2:
		var chord := GIRDER_PAINT if y < 2 else GIRDER_PAINT.darkened(0.12)
		if x % 8 == 4 and (y == 0 or y == size.y - 1):
			return YELLOW.lightened(0.2)
		return Pixels.metal(chord, x, y)
	var span := size.y - 4
	var phase := posmod(x, span * 2)
	var rise := phase if phase < span else span * 2 - phase
	if absf((y - 2) - rise) < 1.0 or x % (span * 2) == 0:
		return Pixels.metal(GIRDER_PAINT.darkened(0.2), x, y)
	return Pixels.CLEAR


func _paint_trolley(x: int, y: int) -> Color:
	var at := Vector2(x + 0.5, y + 0.5)
	# Two flanged wheels on top, a yellow body with rivets and a hook block below.
	for wheel: float in [7.0, 22.0]:
		var spoke := (at - Vector2(wheel, 2.5)) / 2.6
		if spoke.length() <= 1.0:
			return DARK.lightened(0.2) if spoke.length() < 0.35 else Pixels.rounded(STEEL.darkened(0.2), spoke)
	if y >= 3 and y < 7 and x >= 2 and x < TROLLEY.x - 2:
		if y == 4 and (x == 4 or x == TROLLEY.x - 5):
			return STEEL
		return Pixels.lit(YELLOW, 0.8 - 0.5 * (y - 3), x, y)
	if y >= 7 and x >= 12 and x < 18:
		return IRON.lightened(0.2)
	return Pixels.CLEAR


func _paint_magnet(x: int, y: int) -> Color:
	var at := Vector2(x + 0.5, y + 0.5)
	var middle := MAGNET.x * 0.5
	var arch := at - Vector2(middle, 10.0)
	var band := Vector2.ZERO
	var inside := false
	if y < 10:
		var reach := arch.length()
		inside = reach >= 5.0 and reach <= 12.0
		band = arch.normalized() * ((reach - 8.5) / 3.5)
	else:
		inside = x < 7 or x >= MAGNET.x - 7
		var leg := 3.5 if x < 7 else MAGNET.x - 3.5
		band = Vector2((at.x - leg) / 3.5, 0)
	if not inside:
		return Pixels.CLEAR
	if y >= 15:
		# Bright steel pole tips with a groove where the paint stops.
		if y == 15:
			return STEEL.darkened(0.35)
		return Pixels.rounded(STEEL, band)
	var tone := Pixels.rounded(MAGNET_RED, band)
	if y >= 3 and y < 13 and absf(band.x + band.y + 0.8) < 0.25:
		tone = tone.lightened(0.25)
	return Pixels.grainy(tone, x, y, 0.06)


func _paint_box(x: int, y: int, back: bool) -> Color:
	# An open pine crate: the back rim and dark inside, then the front boards,
	# corner posts and iron corner straps with a paper label.
	var rim := 6
	if back:
		if y < 2:
			return Pixels.wood(PINE.darkened(0.1), x, y, 6, false)
		if y < rim + 1:
			return Color("#2a1d24").lightened(0.05 * (rim - y)) if x >= 2 and x < BOX.x - 2 else Pixels.wood(PINE.darkened(0.3), x, y, 6)
		return Pixels.CLEAR
	if y < rim:
		return Pixels.CLEAR
	if y == rim:
		return PINE.lightened(0.2)
	var corner := x < 3 or x >= BOX.x - 3
	if corner:
		if (y - rim) % 6 == 2:
			return STEEL.darkened(0.15)
		return Pixels.wood(PINE.darkened(0.18), x, y, 3)
	var label_box := Rect2i(9, 10, 14, 8)
	if label_box.has_point(Vector2i(x, y)):
		return Pixels.grainy(LABEL, x, y, 0.1) if label_box.grow(-1).has_point(Vector2i(x, y)) else LABEL.darkened(0.3)
	var board := Pixels.wood(PINE, x, y - rim, 5, false)
	return board.darkened(0.12 * float(y - rim) / BOX.y)


func _paint_bin(x: int, y: int) -> Color:
	# A dented tin bin with ribs, a rolled rim and a recycling ring.
	var taper := 1.0 + (y / float(BIN.y)) * 1.5
	if x < taper or x >= BIN.x - taper:
		return Pixels.CLEAR
	if y < 2:
		return STEEL.darkened(0.1) if y == 0 else Color("#2a1d24")
	var across := (x - BIN.x * 0.5) / (BIN.x * 0.5 - taper)
	var tone := Pixels.rounded(TIN.darkened(0.15), Vector2(across, -0.3))
	if y % 6 == 3:
		tone = tone.darkened(0.2)
	if Vector2(x - 17, y - 19).length() < 2.2:
		tone = tone.darkened(0.25)
	return Pixels.metal(tone, x, y)


func _paint_hopper(x: int, y: int) -> Color:
	# A riveted funnel, wide at the top, opening at the bottom over the belt.
	var narrowing := y * 0.45
	if x < narrowing or x >= HOPPER.x - narrowing:
		return Pixels.CLEAR
	if y < 2:
		return YELLOW.lightened(0.15) if y == 0 else YELLOW.darkened(0.3)
	if y >= HOPPER.y - 2:
		return DARK.lightened(0.1)
	var across := (x + 0.5 - HOPPER.x * 0.5) / (HOPPER.x * 0.5 - narrowing)
	# Riveted sheet panels with a seam down each one.
	if y == 7 or y == 13:
		return YELLOW.darkened(0.35) if x % 3 != 1 else YELLOW.lightened(0.4)
	if posmod(x - int(narrowing), 6) == 0:
		return YELLOW.darkened(0.25)
	var tone := Pixels.rounded(YELLOW.darkened(0.08), Vector2(across, -0.2))
	return Pixels.grainy(tone, x, y, 0.08)


func _paint_console(x: int, y: int) -> Color:
	# A little control desk: a sloped panel with two buttons on a riveted box.
	if y < 3:
		return Pixels.CLEAR
	if x < 1 or x >= CONSOLE.x - 1:
		return Pixels.CLEAR
	if y < 8:
		if (x == 4 or x == 11) and y == 5:
			return Color("#6fae5c") if x == 4 else MAGNET_RED
		return Pixels.lit(FRAME.lightened(0.1), 1.0 - (y - 3) * 0.3, x, y)
	if (x == 2 or x == CONSOLE.x - 3) and (y == 10 or y == CONSOLE.y - 3):
		return STEEL
	return Pixels.metal(FRAME.darkened(0.15), x, y)


func _paint_helmet(x: int, y: int) -> Color:
	var at := Vector2(x + 0.5, y + 0.5)
	if y >= 8:
		return Pixels.metal(TIN.darkened(0.25), x, y) if y == 8 else TIN.darkened(0.45)
	var dome := (at - Vector2(HELMET.x * 0.5, 8.0)) / Vector2(9.0, 8.0)
	if dome.length() > 1.0:
		return Pixels.CLEAR
	if y == 5 and x in [4, 8, 13, 17]:
		return STEEL.lightened(0.3)
	return Pixels.rounded(TIN, dome)


func _paint_toy(x: int, y: int, kind: String) -> Color:
	var at := Vector2(x + 0.5, y + 0.5)
	match kind:
		"robot", "woodbot":
			var wooden := kind == "woodbot"
			var skin := PINE.darkened(0.12) if wooden else TIN
			var shade := func(base: Color, offset: Vector2) -> Color:
				return Pixels.wood(Pixels.rounded(base, offset * 0.6), x, y, 3, true, 5) if wooden else Pixels.rounded(base, offset)
			if y < 2:
				if x >= 5 and x < 7:
					return MAGNET_RED if y == 0 and not wooden else skin.darkened(0.2)
				return Pixels.CLEAR
			if y < 7:
				if x < 2 or x >= 10:
					return Pixels.CLEAR
				if y == 4 and (x == 4 or x == 7):
					return DARK
				if y == 6 and x >= 4 and x < 8:
					return skin.darkened(0.35) if x % 2 == 0 else skin.darkened(0.15)
				return shade.call(skin, Vector2((at.x - 6.0) / 4.0, (at.y - 4.5) / 2.5))
			if y == 7:
				return skin.darkened(0.3) if x >= 5 and x < 7 else Pixels.CLEAR
			if y < 14:
				if x == 0 or x == 11:
					return skin.darkened(0.15) if y < 12 else Pixels.CLEAR
				if x >= 5 and x < 7 and y >= 9 and y < 11:
					return Color("#e8c94a") if wooden else MAGNET_RED.lightened(0.15)
				if not wooden and (x == 2 or x == 9) and (y == 9 or y == 12):
					return STEEL.lightened(0.3)
				return shade.call(skin, Vector2((at.x - 6.0) / 5.0, (at.y - 10.5) / 3.5))
			return DARK.lightened(0.15) if (x >= 3 and x < 5) or (x >= 7 and x < 9) else Pixels.CLEAR
		"car":
			for wheel: float in [4.5, 13.5]:
				var tyre := (at - Vector2(wheel, 8.0)) / 2.2
				if tyre.length() <= 1.0:
					return STEEL if tyre.length() < 0.4 else Pixels.rounded(DARK.lightened(0.1), tyre)
			if y < 3:
				if x >= 15 and x < 17 and y >= 1:
					return YELLOW
				if x >= 5 and x < 12:
					return Color("#9fd0e0").lightened(0.2) if y >= 1 and x >= 6 and x < 11 else TIN_BLUE.lightened(0.1)
				return Pixels.CLEAR
			if y < 7 and x >= 1 and x < 17:
				if x == 1 or x == 16:
					return STEEL
				if y == 5 and x % 4 == 2:
					return STEEL.lightened(0.3)
				return Pixels.rounded(TIN_BLUE, Vector2(0, (at.y - 5.0) / 2.0))
			return Pixels.CLEAR
		"drum":
			var across := (at.x - 6.0) / 6.0
			if absf(across) > 1.0:
				return Pixels.CLEAR
			if y < 2:
				return STEEL.lightened(0.2) if y == 0 else Color("#f3ead6")
			if y == 2 or y == 10 or y == 11:
				return Pixels.rounded(STEEL, Vector2(across, 0))
			var zig := posmod(x - y * (1 if (y / 2) % 2 == 0 else -1), 4) < 2
			return Pixels.rounded(PAINT_RED if zig else Color("#f3ead6"), Vector2(across, 0))
		"mouse":
			if x >= 6 and x < 8 and y < 2:
				return YELLOW
			if x >= 12 and y == 6:
				return DARK.lightened(0.2)
			var body := (at - Vector2(7.0, 5.5)) / Vector2(6.0, 3.6)
			var ear := (at - Vector2(3.5, 2.5)).length() < 1.8
			if ear:
				return Color("#e7a3a8")
			if body.length() > 1.0:
				return Pixels.CLEAR
			if y == 4 and x == 2:
				return DARK
			if y == 6 and x % 3 == 1:
				return STEEL.lightened(0.3)
			return Pixels.rounded(TIN.darkened(0.05), body)
		"block":
			var edge := x == 0 or y == 0 or x == 10 or y == 10
			if edge:
				return Pixels.wood(FRAME.lightened(0.15), x, y, 3, false)
			# A carved letter A.
			var letter := (y >= 3 and y <= 8 and (absf(at.x - 5.5) * 2.0 >= (y - 2) - 0.6 and absf(at.x - 5.5) * 2.0 <= (y - 2) + 0.9)) or (y == 6 and x >= 4 and x <= 6)
			if letter:
				return PAINT_RED
			return Pixels.wood(PINE.lightened(0.1), x, y, 5, false, 2)
		"duck":
			for wheel: float in [4.5, 10.5]:
				if (at - Vector2(wheel, 10.5)).length() < 1.6:
					return WOOD.darkened(0.2)
			if x < 2 and y >= 3 and y < 5:
				return Color("#e0773c")
			var head := (at - Vector2(4.0, 3.5)) / 2.6
			var body := (at - Vector2(8.5, 6.5)) / Vector2(5.5, 3.2)
			if head.length() <= 1.0:
				if y == 3 and x == 4:
					return DARK
				return Pixels.wood(DUCK, x, y, 4, false, 4)
			if body.length() <= 1.0:
				if y == 6 and x >= 7 and x < 11:
					return DUCK.darkened(0.25)
				return Pixels.wood(DUCK.darkened(0.05), x, y, 4, false, 4)
			return Pixels.CLEAR
		"weight":
			var ring := (at - Vector2(11.0, 5.0)).length()
			if y < 5:
				return Pixels.rounded(IRON.lightened(0.1), (at - Vector2(11.0, 5.0)) / 5.0) if ring <= 5.0 and ring >= 3.0 else Pixels.CLEAR
			var narrowing := (SIZES["weight"].y - 1 - y) * 0.3
			if x < narrowing or x >= SIZES["weight"].x - narrowing:
				return Pixels.CLEAR
			if y >= 8 and y <= 12 and x >= 6 and x < 16:
				return Pixels.metal(IRON.lightened(0.15), x, y)
			return Pixels.metal(Pixels.rounded(IRON, Vector2((at.x - 11.0) / 11.0, -0.3)), x, y, 3)
	return Pixels.CLEAR
