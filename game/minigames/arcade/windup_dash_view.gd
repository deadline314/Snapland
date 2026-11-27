extends "res://game/minigames/arcade/arcade_view.gd"
## Picture for 發條衝刺: a stitched felt race mat on the workshop bench, the tin
## cat with the key in its back, the brass spring gauge with its riveted cover,
## the rival in the far lane, and the spring that pops out when the cat is
## wound too far. Every object is baked pixel art (arcade_pixels.gd) in the
## backdrop's dusky palette.

const YARD_ART := "res://assets/world/toy-clockwork-yard.webp"
const FLOOR_TOP := 380.0
const MAT_RECT := Rect2(60, 392, 1196, 152)
const LANE_SPLIT_Y := 462.0
## Screen x of a standing toy's middle on the start line; its nose is NOSE ahead.
const START_X := 226.0
const NOSE := 52.0
const PX_PER_METRE := 48.0
const RIVAL_FEET_Y := 450.0
const HERO_FEET_Y := 530.0
const UNIT := 4.5
const RIVAL_UNIT := 4.0
## Inner channel of the gauge; its brass frame is FRAME texels thick around it.
const GAUGE := Rect2(380, 204, 600, 36)
const FRAME := 3
const TOY_SIZE := Vector2i(22, 26)
const TOY_ORIGIN := Vector2i(9, 25)
const WOOD := Color("#7a5238")
const MAT := Color("#33555a")
const MAT_LINE := Color("#e2d3ab")
const BRASS := Color("#c9953e")
const TIN := Color("#8a7860")
const PAPER := Color("#e9d8b0")
const DARK := Color("#2b2440")
const DUSK := Color(1.0, 0.93, 0.86)
## Toy blocks left on the near edge of the bench: [corner, texels, paint, letter].
const BLOCKS: Array = [
	[Vector2(38, 586), 16, Color("#b98a3c"), "A"], [Vector2(112, 606), 12, Color("#5f8ea6"), "B"],
	[Vector2(1128, 592), 16, Color("#a8584c"), "C"], [Vector2(1202, 612), 11, Color("#6f9a78"), "D"],
]
const PALETTES := {
	"hero": [Color("#d9705e"), Color("#a84e44"), Color("#f0d48a")],
	"rival_a": [Color("#6fa888"), Color("#4a7f64"), Color("#e9d8b0")],
	"rival_b": [Color("#8f84c9"), Color("#685da0"), Color("#e9d8b0")],
}
const MOODS: Array[String] = ["plain", "strain", "dizzy", "happy", "sorry"]

var _has_art := false
## Sprites, baked once in _ready().
var _mat: ImageTexture
var _frame: ImageTexture
var _covers: Dictionary = {}
var _key: ImageTexture
var _sign: ImageTexture
var _cubes: Array[ImageTexture] = []
## Palette name -> mood -> sprite.
var _toys: Dictionary = {}


func _init() -> void:
	super()
	word_anchor = Vector2(640, 306)


func _ready() -> void:
	_has_art = use_backdrop_art(YARD_ART, Rect2(128, 0, 1193, 671), Color(0.74, 0.68, 0.74))
	_mat = Pixels.bake("dash-mat", Vector2i(int(MAT_RECT.size.x / TEXEL), int(MAT_RECT.size.y / TEXEL)), _paint_mat)
	_frame = Pixels.bake("dash-gauge", Vector2i(int(GAUGE.size.x / TEXEL) + FRAME * 2, int(GAUGE.size.y / TEXEL) + FRAME * 2), _paint_frame)
	for share: float in [1.0 / 3.0, 1.0]:
		_covers[share] = Pixels.bake("dash-cover|%.2f" % share, Vector2i(int(GAUGE.size.x * share / TEXEL) + 2, int(GAUGE.size.y / TEXEL) + 4), _paint_cover)
	_key = Pixels.bake("dash-key", Vector2i(8, 13), _paint_key)
	_sign = Pixels.bake("dash-sign", Vector2i(38, 13), func(x: int, y: int) -> Color:
		return Pixels.grainy(PAPER, x, y, 0.08) if x > 1 and x < 36 and y > 1 and y < 11 else Pixels.wood(WOOD.lightened(0.15), x, y, 5, false))
	for block: Array in BLOCKS:
		_cubes.append(Pixels.bake("dash-cube|%s|%d" % [(block[2] as Color).to_html(), block[1]], Vector2i(block[1], block[1]), _paint_cube.bind(block[2], block[1])))
	for look: String in PALETTES:
		var moods: Dictionary = {}
		for mood in MOODS:
			moods[mood] = Pixels.bake_blocks("dash-toy|%s|%s" % [look, mood], TOY_SIZE, TOY_ORIGIN, _build_toy(PALETTES[look], mood))
		_toys[look] = moods


func _draw_backdrop() -> void:
	if not _has_art:
		draw_rect(Rect2(Vector2.ZERO, DESIGN), Color("#3a2c2a"))
	bench(FLOOR_TOP, WOOD)
	# The mat lies on the bench: a thin shadow all round, then stitched felt.
	draw_rect(MAT_RECT.grow(7.0), Color(0.05, 0.02, 0.09, 0.3))
	stamp(_mat, MAT_RECT.position, TEXEL, DUSK)
	var metres := int(float(state.get("track_metres", 12.0)))
	for metre in range(1, metres + 1):
		var x := _track_x(float(metre)) + NOSE
		if x > MAT_RECT.end.x - 10.0:
			break
		var tall := metre % 2 == 0
		draw_rect(Rect2(x - 2.0, MAT_RECT.end.y - (20.0 if tall else 12.0), 4, 12.0 if tall else 8.0), Color(MAT_LINE, 0.8))
		if tall:
			label(Vector2(x, MAT_RECT.end.y + 18.0), "%d m" % metre, 16, MAT_LINE)
	for index in BLOCKS.size():
		var block: Array = BLOCKS[index]
		var corner: Vector2 = block[0]
		var side := float(block[1]) * TEXEL
		ground_shadow(corner + Vector2(side * 0.5, side + 2.0), Vector2(side * 0.62, 7), 0.4)
		stamp(_cubes[index], corner, TEXEL, DUSK)
		label(corner + Vector2(side * 0.5, side * 0.5 - 2.0), str(block[3]), int(side * 0.5), PAPER)
	vignette()


func _draw_scene() -> void:
	var phase := str(state.get("phase", "wind"))
	var since := age(float(state.get("phase_at", 0.0)))
	_draw_gauge(phase)
	_draw_best_flag()
	if float(state.get("rival_turns", 0.0)) > 0.0:
		_draw_rival(phase, since)
	_draw_hero(phase, since)


# --- Gauge ------------------------------------------------------------------

func _draw_gauge(phase: String) -> void:
	var total := float(state.get("gauge", 24.0))
	var turns := float(state.get("turns", 0.0))
	var strain := float(state.get("strain", 0.0))
	var cover_from := float(state.get("cover_from", 0.66))
	var winding := phase == "wind"
	var corner := GAUGE.position - Vector2.ONE * FRAME * TEXEL
	cast_shadow(_frame, corner, Vector2(8, 10))
	stamp(_frame, corner, TEXEL, DUSK)
	# The coil: one bright loop per turn, hotter as the spring tightens.
	var shown := int(clampf(turns, 0.0, total)) if winding or phase == "burst" else 0
	var tone := Color("#6fc9a8").lerp(Color("#e3b95a"), smoothstep(0.4, 0.75, strain)).lerp(Color("#d9626a"), smoothstep(0.75, 1.0, strain))
	var loop := GAUGE.size.x / total
	for index in shown:
		var slot := Rect2(GAUGE.position.x + index * loop + 2.0, GAUGE.position.y + 4.0, loop - 4.0, GAUGE.size.y - 8.0)
		draw_rect(slot, tone.darkened(0.3))
		draw_rect(Rect2(slot.position, slot.size - Vector2(4, 4)), tone)
		draw_rect(Rect2(slot.position, Vector2(slot.size.x - 4.0, 4)), tone.lightened(0.35))
	# The covered end: a riveted tin plate with worn hazard paint.
	var share := 1.0 - cover_from
	var plate_art: ImageTexture = _covers[1.0 if share > 0.9 else 1.0 / 3.0]
	var cover_at := Vector2(GAUGE.position.x + GAUGE.size.x * cover_from - 4.0, GAUGE.position.y - 8.0)
	cast_shadow(plate_art, cover_at, Vector2(5, 6), TEXEL, 0.35)
	stamp(plate_art, cover_at, TEXEL, DUSK)
	for mark in 3:
		label(Vector2(cover_at.x + GAUGE.size.x * share * (float(mark) + 0.5) / 3.0, GAUGE.get_center().y - 6.0), "？", 24, PAPER)
	# What the rival needs, pinned on top of the gauge even over the cover.
	var rival_turns := float(state.get("rival_turns", 0.0))
	if rival_turns > 0.0:
		var pin := Vector2(GAUGE.position.x + GAUGE.size.x * rival_turns / total, GAUGE.position.y - 14.0)
		var bob := 3.0 * pulse(1.4)
		_draw_flag(pin + Vector2(0, bob), 32.0, Color("#6fa888"))
		label(pin + Vector2(66, -22.0 + bob), "贏過對手", 15, Color("#bfe6cf"))
	var readable := not winding or turns <= total * cover_from
	var count := "發條 %d 圈" % int(turns) if readable and cover_from > 0.0 else "發條 ？？圈"
	label(Vector2(GAUGE.position.x - 104.0, GAUGE.get_center().y - 16.0), count, 19, PAPER)
	# The key gets stiffer: the cap sinks less, reddens and creaks near the limit.
	var cap := Vector2(GAUGE.position.x - 104.0, GAUGE.get_center().y + 22.0)
	var tight := smoothstep(0.6, 1.0, strain) if winding else 0.0
	if not reduced_motion:
		cap.x += sin(now * 70.0) * 3.0 * tight
	var pressed := winding and age(float(state.get("press_at", -99.0))) < 0.07
	var width := key_cap(cap, "空白鍵", pressed and tight < 0.7, 17)
	draw_rect(Rect2(cap.x - width * 0.5, cap.y - 17.5, width, 35), Color(ROSE, 0.55 * tight))
	if winding and strain >= 0.88:
		label(Vector2(GAUGE.end.x + 76.0, GAUGE.get_center().y), "好緊！", 26, ROSE, 0.85 + 0.15 * pulse(5.0))


## A small pennant on a pin: pole with a dark edge, cloth with a lit fold.
func _draw_flag(foot: Vector2, height: float, cloth: Color) -> void:
	draw_rect(Rect2(foot.x - 3.5, foot.y - height, 7, height), cloth.darkened(0.7))
	draw_rect(Rect2(foot.x - 1.5, foot.y - height, 3, height), PAPER.darkened(0.2))
	var top := foot + Vector2(2, -height)
	draw_colored_polygon(PackedVector2Array([top + Vector2(-1, -3), top + Vector2(31, 8), top + Vector2(-1, 19)]), cloth.darkened(0.6))
	draw_colored_polygon(PackedVector2Array([top, top + Vector2(26, 8), top + Vector2(0, 16)]), cloth)
	draw_colored_polygon(PackedVector2Array([top, top + Vector2(26, 8), top + Vector2(0, 6)]), cloth.lightened(0.25))


func _draw_best_flag() -> void:
	var best := float(state.get("best", 0.0))
	if best <= 0.0:
		return
	var foot := Vector2(_track_x(best) + NOSE, MAT_RECT.end.y - 4.0)
	_draw_flag(foot, 32.0, Color("#d9b04a"))
	label(foot + Vector2(0, -46), "最佳 %.1f m" % best, 15, Color("#f0d48a"))


# --- Toys -------------------------------------------------------------------

func _track_x(metres: float) -> float:
	return START_X + metres * PX_PER_METRE


## Share of a run covered `since` seconds after the release: fast, then coasting.
func _run_share(since: float, seconds: float) -> float:
	var t := clampf(since / maxf(seconds, 0.01), 0.0, 1.0)
	return 1.0 - pow(1.0 - t, 3.0)


func _draw_hero(phase: String, since: float) -> void:
	var strain := float(state.get("strain", 0.0))
	var distance := float(state.get("distance", 0.0))
	var feet := Vector2(START_X, HERO_FEET_Y)
	var mood := "plain"
	var stretch := Vector2.ONE
	var turn := 0.0
	var key_angle := float(state.get("turns", 0.0)) * PI * 0.5
	match phase:
		"wind":
			var tight := smoothstep(0.6, 1.0, strain)
			if not reduced_motion:
				feet.x += sin(now * 64.0) * 5.0 * tight
			stretch = squash(age(float(state.get("press_at", -99.0))), 0.08 + 0.1 * tight, 0.14)
			if strain >= 0.75:
				mood = "strain"
			if strain >= 0.88:
				label(feet + Vector2(-74, -118), "喀！", 26, ROSE, 0.8 + 0.2 * pulse(6.0))
		"run":
			var share := _run_share(since, float(state.get("run_seconds", 1.0)))
			feet.x = _track_x(distance * share)
			mood = "happy"
			key_angle = now * 22.0 * (1.0 - share)
			if not reduced_motion:
				turn = 0.1 * (1.0 - share)
				feet.y -= absf(sin(now * 26.0)) * 4.0 * (1.0 - share)
				_draw_dust(feet, 1.0 - share)
		"rest":
			feet.x = _track_x(distance)
			var won := bool(state.get("beat_rival", false))
			mood = "happy" if won or float(state.get("rival_turns", 0.0)) <= 0.0 else "plain"
			stretch = squash(since, 0.2)
			if won and not reduced_motion:
				feet.y -= absf(sin(since * 12.0)) * 16.0
			_draw_distance_sign(feet, distance, since)
		"burst":
			mood = "dizzy"
			# Three fast spins on the spot, then it sits there tilted and seeing stars.
			turn = 0.3 if reduced_motion else TAU * 3.0 * _run_share(since, 1.3) + 0.3 * smoothstep(1.2, 1.4, since)
			_draw_popped_spring(feet, since)
	ground_shadow(Vector2(feet.x, HERO_FEET_Y + 3.0), Vector2(46, 8), 0.45)
	if phase != "burst":
		_draw_key(feet, key_angle, stretch, UNIT)
	_draw_toy(feet, "hero", mood, stretch, turn, UNIT)
	if mood == "strain":
		_draw_sweat(feet)
	if phase == "burst":
		_draw_stars(feet + Vector2(16, -122), since)


func _draw_rival(phase: String, since: float) -> void:
	var distance := float(state.get("rival_distance", 0.0))
	var look := "rival_a" if int(state.get("dash", 0)) % 2 == 1 else "rival_b"
	var feet := Vector2(START_X, RIVAL_FEET_Y)
	var mood := "plain"
	var goal := Vector2(_track_x(distance) + NOSE, RIVAL_FEET_Y + 6.0)
	match phase:
		"wind":
			if not reduced_motion:
				feet.y -= 3.0 * pulse(1.2)
			# Its finishing post stands on the mat before anybody runs.
			_draw_flag(goal, 34.0, PALETTES[look][0])
			label(goal + Vector2(0, -48), "對手 %.1f m" % distance, 15, PALETTES[look][2])
		"run":
			feet.x = _track_x(distance * _run_share(since, float(state.get("run_seconds", 1.0))))
			mood = "happy"
		"burst":
			feet.x = _track_x(distance * _run_share(since, 1.4))
			mood = "happy"
			if since > 1.0:
				label(feet + Vector2(0, -116), "嘿嘿～", 22, PALETTES[look][2], pop_in(since - 1.0, 0.2))
		"rest":
			feet.x = _track_x(distance)
			mood = "sorry" if bool(state.get("beat_rival", false)) else "happy"
			if mood == "happy" and not reduced_motion:
				feet.y -= absf(sin(since * 12.0)) * 12.0
	ground_shadow(Vector2(feet.x, RIVAL_FEET_Y + 3.0), Vector2(40, 7), 0.4)
	_draw_key(feet, now * 6.0 if phase != "wind" else 0.6, Vector2.ONE, RIVAL_UNIT)
	_draw_toy(feet, look, mood, Vector2.ONE, 0.0, RIVAL_UNIT)


## One tin cat on wheels, facing right, standing on `feet`; `turn` spins it
## around its middle.
func _draw_toy(feet: Vector2, look: String, mood: String, stretch: Vector2, turn: float, unit: float) -> void:
	var middle := Vector2(0, -11.0 * unit)
	draw_set_transform_matrix(Transform2D(turn, feet + middle) * Transform2D(0.0, stretch * unit, 0.0, Vector2.ZERO) * Transform2D(0.0, Vector2(0, 11)))
	stamp(_toys[look][mood], -Vector2(TOY_ORIGIN), 1.0, DUSK)
	draw_set_transform(Vector2.ZERO)


## The butterfly key in the cat's back, seen edge-on as it turns.
func _draw_key(feet: Vector2, angle: float, stretch: Vector2, unit: float) -> void:
	draw_set_transform(feet + Vector2(-7.5, -11.5) * unit * stretch, 0.0, Vector2(1.0, maxf(0.22, absf(cos(angle)))) * stretch * unit)
	stamp(_key, Vector2(-8, -6.5), 1.0, DUSK)
	draw_set_transform(Vector2.ZERO)


func _draw_sweat(feet: Vector2) -> void:
	for drop in 2:
		var fall := 0.0 if reduced_motion else fmod(now * 1.6 + drop * 0.5, 1.0)
		var at := feet + Vector2(-12.0 + drop * 70.0, -104.0 + fall * 26.0)
		draw_rect(Rect2(at - Vector2(4, 6), Vector2(8, 12)), Color("#2d4f66"))
		draw_rect(Rect2(at - Vector2(2, 4), Vector2(4, 8)), Color("#9fd0e6"))
		draw_rect(Rect2(at - Vector2(2, 4), Vector2(2, 2)), Color.WHITE)


func _draw_dust(feet: Vector2, power: float) -> void:
	for puff in 3:
		var life := fmod(now * 3.0 + puff * 0.33, 1.0)
		var size := (6.0 + life * 12.0) * power
		var at := feet + Vector2(-46.0 - life * 46.0, -8.0 - life * 14.0)
		draw_rect(Rect2(at - Vector2(size, size) * 0.5, Vector2(size, size)), Color(0.9, 0.84, 0.72, 0.6 * (1.0 - life) * power))
	for streak in 3:
		draw_rect(Rect2(feet.x - 130.0 - streak * 26.0, feet.y - 80.0 + streak * 26.0, 70.0 * power, 4), Color(1, 0.96, 0.86, 0.3 * power))


func _draw_distance_sign(feet: Vector2, distance: float, since: float) -> void:
	var at := Vector2(clampf(feet.x, 120.0, 1160.0), feet.y - 150.0)
	draw_set_transform(at, 0.0, Vector2.ONE * pop_in(since, 0.2))
	draw_rect(Rect2(-4, 18, 8, 26), WOOD.darkened(0.6))
	draw_rect(Rect2(-2, 18, 4, 26), WOOD.lightened(0.1))
	stamp(_sign, Vector2(-76, -26), TEXEL, DUSK)
	draw_set_transform(Vector2.ZERO)
	label(at + Vector2(0, -2), "%.1f 公尺" % distance, 24, DARK, pop_in(since, 0.2), 1.0, false)


## The spring leaves through the back, the key flies off and bounces away.
func _draw_popped_spring(feet: Vector2, since: float) -> void:
	var out := 1.0 if reduced_motion else pop_in(since, 0.22)
	var sway := 0.0 if reduced_motion else sin(since * 16.0) * 12.0 * maxf(0.0, 1.0 - since * 0.5)
	var root := feet + Vector2(-8, -56)
	# A gentle pop of rays for the first instant.
	if since < 0.3 and not reduced_motion:
		for ray in 8:
			var along := Vector2.from_angle(ray * TAU / 8.0)
			draw_line(root + along * (30.0 + since * 160.0), root + along * (52.0 + since * 220.0), Color(PAPER, 1.0 - since / 0.3), 6.0)
	var coil := PackedVector2Array([root])
	for bend in 11:
		var rise := float(bend + 1) / 11.0
		coil.append(root + Vector2((22.0 if bend % 2 == 0 else -22.0) + sway * rise - 16.0 * rise, -170.0 * rise * out))
	draw_polyline(coil, BRASS.darkened(0.66), 13.0)
	draw_polyline(coil, BRASS, 7.0)
	draw_polyline(coil, BRASS.lightened(0.4), 2.0)
	var tip: Vector2 = coil[coil.size() - 1]
	draw_rect(Rect2(tip - Vector2(9, 9), Vector2(18, 18)), BRASS.darkened(0.66))
	draw_rect(Rect2(tip - Vector2(6, 6), Vector2(12, 12)), BRASS.lightened(0.15))
	# The key lands on the mat ahead of the toy and bounces once.
	var fly := 1.0 if reduced_motion else clampf(since / 0.9, 0.0, 1.0)
	var key_at := root + Vector2(210.0 * fly, -230.0 * sin(fly * PI) + 44.0 * fly)
	draw_set_transform(key_at, PI * 0.5 if reduced_motion else since * 9.0 * (1.0 - fly) + PI * 0.5, Vector2.ONE * UNIT)
	stamp(_key, Vector2(-4, -6.5), 1.0, DUSK)
	draw_set_transform(Vector2.ZERO)


func _draw_stars(center: Vector2, since: float) -> void:
	for star in 4:
		var angle := float(star) * TAU / 4.0 + (0.0 if reduced_motion else since * 5.0)
		var at := center + Vector2(cos(angle) * 54.0, sin(angle) * 16.0)
		var size := 5.0 if sin(angle) < 0.0 else 7.0
		draw_rect(Rect2(at - Vector2(size + 3.0, 5), Vector2(size * 2.0 + 6.0, 10)), DARK)
		draw_rect(Rect2(at - Vector2(5, size + 3.0), Vector2(10, size * 2.0 + 6.0)), DARK)
		draw_rect(Rect2(at - Vector2(size, 2), Vector2(size * 2.0, 4)), GOLD)
		draw_rect(Rect2(at - Vector2(2, size), Vector2(4, size * 2.0)), GOLD)


# --- Texel painters ---------------------------------------------------------

## Felt with a stitched border, a lighter far lane, a stitched lane line and a chequered start.
func _paint_mat(x: int, y: int) -> Color:
	var width := int(MAT_RECT.size.x / TEXEL)
	var height := int(MAT_RECT.size.y / TEXEL)
	var split := int((LANE_SPLIT_Y - MAT_RECT.position.y) / TEXEL)
	var felt := Pixels.grainy(MAT.lightened(0.08) if y < split else MAT, x, y, 0.16)
	if Pixels.noise(x / 3, y / 2, 5) > 0.9:
		felt = felt.lightened(0.07)
	var edge := mini(mini(x, width - 1 - x), mini(y, height - 1 - y))
	if edge == 2 and (x + y) % 4 < 2:
		return MAT_LINE.darkened(0.1)
	if edge < 1:
		return MAT.darkened(0.3)
	if y == split and x % 5 < 3:
		return MAT_LINE.darkened(0.2)
	var start := int((START_X + NOSE - MAT_RECT.position.x) / TEXEL)
	if x >= start and x < start + 4 and edge > 3 and ((x - start) / 2 + y / 2) % 2 == 0:
		return Pixels.grainy(MAT_LINE, x, y, 0.1)
	return felt


## Brass frame with a screw in every corner around a dark channel of coil slots.
func _paint_frame(x: int, y: int) -> Color:
	var width := int(GAUGE.size.x / TEXEL) + FRAME * 2
	var height := int(GAUGE.size.y / TEXEL) + FRAME * 2
	var edge := mini(mini(x, width - 1 - x), mini(y, height - 1 - y))
	if edge >= FRAME:
		var slot := float(x - FRAME) * TEXEL / (GAUGE.size.x / 24.0)
		return Color("#1d1826") if fposmod(slot, 1.0) > 0.16 else Color("#3a3144")
	for screw: Vector2 in [Vector2(1, 1), Vector2(width - 2, 1), Vector2(1, height - 2), Vector2(width - 2, height - 2)]:
		if Vector2(x, y) == screw:
			return BRASS.darkened(0.5)
	return Pixels.metal(BRASS.darkened(0.2) if edge == FRAME - 1 else BRASS, x, y)


## Tin plate: rivets at the corners, hazard paint along the bottom, scratches.
func _paint_cover(x: int, y: int) -> Color:
	var height := int(GAUGE.size.y / TEXEL) + 4
	if y >= height - 3:
		var stripe := (x + y) / 4 % 2 == 0
		var paint := Color("#d9b04a") if stripe else DARK.lightened(0.1)
		return paint.darkened(0.25) if Pixels.noise(x, y, 9) > 0.82 else paint
	if (y == 1 or y == height - 5) and x % 12 == 2:
		return TIN.darkened(0.5)
	var tin := Pixels.metal(TIN, x, y, 4)
	return tin.lightened(0.14) if Pixels.noise(x / 4 - y, y / 3, 2) > 0.94 else tin


func _paint_key(x: int, y: int) -> Color:
	# Stem on the right, two rounded wings on the left.
	if x >= 4:
		return Pixels.metal(BRASS.darkened(0.25), x, y) if y >= 6 and y <= 7 else Pixels.CLEAR
	for wing_y: float in [3.0, 10.0]:
		var wing := Vector2(x + 0.5 - 2.0, y + 0.5 - wing_y) / Vector2(2.2, 3.2)
		if wing.length() < 1.0:
			return BRASS.darkened(0.4) if wing.length() < 0.35 else Pixels.rounded(BRASS, wing)
	return Pixels.metal(BRASS, x, y) if x >= 1 and x <= 2 and y >= 4 and y <= 9 else Pixels.CLEAR


## A painted wooden cube with worn corners.
func _paint_cube(x: int, y: int, paint: Color, side: int) -> Color:
	var edge := mini(mini(x, side - 1 - x), mini(y, side - 1 - y))
	if edge == 0 and (x + y) % 5 == 0:
		return WOOD.lightened(0.2)
	if edge == 1:
		return paint.lightened(0.16) if y == 1 or x == 1 else paint.darkened(0.2)
	return Pixels.wood(paint, x, y, 6, false)


## Blocks in art pixels around the feet (x right, y up is negative), back to front.
static func _build_toy(palette: Array, mood: String) -> Array:
	var body: Color = palette[0]
	var shade: Color = palette[1]
	var trim: Color = palette[2]
	var blocks: Array = [
		[Rect2(-7, -4, 4, 4), DARK], [Rect2(3, -4, 4, 4), DARK],
		[Rect2(-6, -3, 2, 2), trim], [Rect2(4, -3, 2, 2), trim],
		[Rect2(-8, -12, 15, 9), body], [Rect2(-8, -12, 15, 1), body.lightened(0.25)], [Rect2(-8, -6, 15, 3), shade],
		# A painted stripe and three rivets along the tin body.
		[Rect2(-8, -9, 15, 1), trim.darkened(0.15)], [Rect2(-5, -11, 1, 1), trim], [Rect2(-2, -11, 1, 1), trim], [Rect2(1, -11, 1, 1), trim],
		[Rect2(0, -24, 3, 3), body], [Rect2(6, -24, 3, 3), body],
		[Rect2(-1, -21, 11, 10), body], [Rect2(-1, -21, 11, 1), body.lightened(0.25)], [Rect2(-1, -13, 11, 2), shade],
		[Rect2(1, -23, 1, 2), trim], [Rect2(7, -23, 1, 2), trim],
		[Rect2(7, -16, 4, 3), PAPER], [Rect2(10, -16, 1, 1), DARK],
		# Whiskers and the seam where the two tin halves meet.
		[Rect2(4, -15, 2, 1), shade], [Rect2(-1, -17, 1, 4), shade],
	]
	match mood:
		"strain":
			blocks.append([Rect2(3, -20, 3, 4), Color.WHITE])
			blocks.append([Rect2(5, -19, 1, 2), DARK])
			blocks.append([Rect2(7, -13, 3, 1), DARK])
		"dizzy":
			for dot: Vector2 in [Vector2(3, -20), Vector2(5, -20), Vector2(4, -19), Vector2(3, -18), Vector2(5, -18)]:
				blocks.append([Rect2(dot, Vector2.ONE), DARK])
			blocks.append([Rect2(8, -13, 2, 2), DARK])
		"happy":
			for dot: Vector2 in [Vector2(3, -18), Vector2(4, -19), Vector2(5, -18)]:
				blocks.append([Rect2(dot, Vector2.ONE), DARK])
			blocks.append([Rect2(7, -13, 3, 1), Color("#c9586e")])
		"sorry":
			blocks.append([Rect2(3, -18, 3, 1), DARK])
			blocks.append([Rect2(1, -21, 1, 2), Color("#9fd0e6")])
		_:
			blocks.append([Rect2(4, -20, 2, 3), DARK])
			blocks.append([Rect2(4, -20, 1, 1), Color.WHITE])
	return blocks
