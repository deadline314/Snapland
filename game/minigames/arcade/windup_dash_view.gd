extends "res://game/minigames/arcade/arcade_view.gd"
## Picture for 發條衝刺: a race mat on the workshop bench, the tin cat with the
## key in its back, the spring gauge with its covered end, the rival in the far
## lane, and the spring that pops out when the cat is wound too far.

const YARD_ART := "res://assets/world/toy-clockwork-yard.webp"
const FLOOR_TOP := 380.0
const MAT_RECT := Rect2(60, 392, 1196, 150)
const LANE_SPLIT_Y := 462.0
## Screen x of a standing toy's middle on the start line; its nose is NOSE ahead.
const START_X := 226.0
const NOSE := 52.0
const PX_PER_METRE := 48.0
const RIVAL_FEET_Y := 450.0
const HERO_FEET_Y := 530.0
const UNIT := 4.5
const RIVAL_UNIT := 4.0
const GAUGE := Rect2(380, 204, 600, 34)
const WOOD := Color("#8a5a3c")
const WOOD_DARK := Color("#3d2a22")
const MAT := Color("#2f5d62")
const MAT_LINE := Color("#f3e6c0")
const BRASS := Color("#e3a53c")
const BRASS_DARK := Color("#a86a24")
const TIN := Color("#8f7a5e")
const DARK := Color("#2b2440")
## Toy blocks left on the near edge of the bench: [corner, size, paint, letter].
const BLOCKS: Array = [
	[Vector2(38, 586), 62.0, Color("#e2a63c"), "A"], [Vector2(110, 604), 46.0, Color("#6fa8c4"), "B"],
	[Vector2(1128, 592), 64.0, Color("#c9675a"), "C"], [Vector2(1200, 612), 44.0, Color("#7fb489"), "D"],
]
const PALETTES := {
	"hero": [Color("#ff7f6a"), Color("#d95a4c"), Color("#ffe08a")],
	"rival_a": [Color("#6fc48f"), Color("#4a9a6c"), Color("#fff5dc")],
	"rival_b": [Color("#9a8cf0"), Color("#6f62c4"), Color("#fff5dc")],
}

## Pixel blocks per toy look, built once: "palette|mood" -> [[Rect2, Color], ...].
static var _toys: Dictionary = {}

var _has_art := false


func _init() -> void:
	super()
	word_anchor = Vector2(640, 300)


func _ready() -> void:
	_has_art = use_backdrop_art(YARD_ART, Rect2(128, 0, 1193, 671), Color(0.8, 0.76, 0.8))


func _draw_backdrop() -> void:
	if not _has_art:
		draw_rect(Rect2(Vector2.ZERO, DESIGN), Color("#3a2c2a"))
	stage_floor(FLOOR_TOP, WOOD, WOOD_DARK)
	_draw_mat()
	for block: Array in BLOCKS:
		var face := Rect2(block[0], Vector2.ONE * float(block[1]))
		plate(face, block[2], (block[2] as Color).darkened(0.3))
		label(face.get_center() - Vector2(0, 3), str(block[3]), int(float(block[1]) * 0.5), CREAM)


func _draw_scene() -> void:
	var phase := str(state.get("phase", "wind"))
	var since := age(float(state.get("phase_at", 0.0)))
	_draw_gauge(phase)
	_draw_best_flag()
	if float(state.get("rival_turns", 0.0)) > 0.0:
		_draw_rival(phase, since)
	_draw_hero(phase, since)


# --- Bench and gauge --------------------------------------------------------

func _draw_mat() -> void:
	var mat := MAT_RECT
	draw_rect(mat.grow(4.0), INK)
	draw_rect(mat, MAT)
	# The far lane is a shade lighter, so two toys never read as one.
	draw_rect(Rect2(mat.position, Vector2(mat.size.x, LANE_SPLIT_Y - mat.position.y)), MAT.lightened(0.09))
	draw_rect(Rect2(mat.position.x, LANE_SPLIT_Y - 1.5, mat.size.x, 3), Color(MAT_LINE, 0.4))
	draw_rect(Rect2(mat.position, Vector2(mat.size.x, 4)), MAT.lightened(0.25))
	# Chequered start line, then a tick every metre and a number every two.
	for row in 15:
		for column in 2:
			if (row + column) % 2 == 0:
				draw_rect(Rect2(START_X + NOSE + column * 8.0, mat.position.y + 6.0 + row * 9.4, 8, 9.4), MAT_LINE)
	var metres := int(float(state.get("track_metres", 12.0)))
	for metre in range(1, metres + 1):
		var x := _track_x(float(metre)) + NOSE
		if x > mat.end.x - 10.0:
			break
		var tall := metre % 2 == 0
		draw_rect(Rect2(x - 1.5, mat.end.y - (16.0 if tall else 9.0), 3, 16.0 if tall else 9.0), Color(MAT_LINE, 0.85))
		if tall:
			label(Vector2(x, mat.end.y + 16.0), "%d m" % metre, 16, MAT_LINE)


func _draw_gauge(phase: String) -> void:
	var total := float(state.get("gauge", 24.0))
	var turns := float(state.get("turns", 0.0))
	var strain := float(state.get("strain", 0.0))
	var cover_from := float(state.get("cover_from", 0.66))
	var winding := phase == "wind"
	plate(GAUGE.grow(10.0), Color("#4a3a44"), Color("#2c2230"))
	draw_rect(GAUGE, Color("#1d1826"))
	var shown := clampf(turns / total, 0.0, 1.0) if winding or phase == "burst" else 0.0
	var tone := MINT.lerp(GOLD, smoothstep(0.4, 0.75, strain)).lerp(ROSE, smoothstep(0.75, 1.0, strain))
	draw_rect(Rect2(GAUGE.position, Vector2(GAUGE.size.x * shown, GAUGE.size.y)), tone)
	draw_rect(Rect2(GAUGE.position, Vector2(GAUGE.size.x * shown, 5)), tone.lightened(0.35))
	# The coil: evenly spaced loops that crowd together as the spring tightens.
	for loop in int(total):
		var x := GAUGE.position.x + GAUGE.size.x * (float(loop) + 0.5) / total
		draw_rect(Rect2(x - 1.5, GAUGE.position.y + 4.0, 3, GAUGE.size.y - 8.0), Color(INK, 0.35))
	# The covered end: a riveted tin plate with hazard teeth.
	var cover := Rect2(GAUGE.position.x + GAUGE.size.x * cover_from, GAUGE.position.y - 6.0, GAUGE.size.x * (1.0 - cover_from), GAUGE.size.y + 12.0)
	draw_rect(cover.grow(3.0), INK)
	draw_rect(cover, TIN)
	draw_rect(Rect2(cover.position, Vector2(cover.size.x, 4)), TIN.lightened(0.25))
	var stripe := 0
	var stripe_x := cover.position.x
	while stripe_x < cover.end.x - 1.0:
		draw_rect(Rect2(stripe_x, cover.end.y - 8.0, minf(14.0, cover.end.x - stripe_x), 8), GOLD if stripe % 2 == 0 else INK)
		stripe_x += 14.0
		stripe += 1
	for mark in 3:
		label(Vector2(cover.position.x + cover.size.x * (float(mark) + 0.5) / 3.0, cover.get_center().y - 4.0), "？", 24, CREAM)
	for corner: Vector2 in [cover.position + Vector2(5, 5), Vector2(cover.end.x - 9.0, cover.position.y + 5.0)]:
		draw_rect(Rect2(corner, Vector2(4, 4)), TIN.darkened(0.4))
	# What the rival needs, pinned on top of the gauge even over the cover.
	var rival_turns := float(state.get("rival_turns", 0.0))
	if rival_turns > 0.0:
		var pin := Vector2(GAUGE.position.x + GAUGE.size.x * rival_turns / total, GAUGE.position.y - 12.0)
		var bob := 3.0 * pulse(1.4)
		draw_rect(Rect2(pin.x - 2.5, pin.y - 26.0 + bob, 5, 32.0 - bob), INK)
		draw_colored_polygon(PackedVector2Array([pin + Vector2(2, -28.0 + bob), pin + Vector2(30, -20.0 + bob), pin + Vector2(2, -10.0 + bob)]), Color("#6fc48f"))
		label(pin + Vector2(64, -20.0 + bob), "贏過對手", 15, Color("#bff0cf"))
	var readable := not winding or turns <= total * cover_from
	var count := "發條 %d 圈" % int(turns) if readable and cover_from > 0.0 else "發條 ？？圈"
	label(Vector2(GAUGE.position.x - 96.0, GAUGE.get_center().y - 14.0), count, 19, CREAM)
	# The key gets stiffer: the cap sinks less, reddens and creaks near the limit.
	var cap := Vector2(GAUGE.position.x - 96.0, GAUGE.get_center().y + 22.0)
	var tight := smoothstep(0.6, 1.0, strain) if winding else 0.0
	if not reduced_motion:
		cap.x += sin(now * 70.0) * 3.0 * tight
	var pressed := winding and age(float(state.get("press_at", -99.0))) < 0.07
	var width := key_cap(cap, "空白鍵", pressed and tight < 0.7, 17)
	draw_rect(Rect2(cap.x - width * 0.5, cap.y - 17.5, width, 35), Color(ROSE, 0.55 * tight))
	if winding and strain >= 0.88:
		label(Vector2(GAUGE.end.x + 70.0, GAUGE.get_center().y), "好緊！", 26, ROSE, 0.85 + 0.15 * pulse(5.0))


func _draw_best_flag() -> void:
	var best := float(state.get("best", 0.0))
	if best <= 0.0:
		return
	var foot := Vector2(_track_x(best) + NOSE, MAT_RECT.end.y - 2.0)
	draw_rect(Rect2(foot.x - 2.5, foot.y - 30.0, 5, 30), INK)
	draw_colored_polygon(PackedVector2Array([foot + Vector2(2, -30), foot + Vector2(28, -23), foot + Vector2(2, -16)]), GOLD)
	label(foot + Vector2(0, -42), "最佳 %.1f m" % best, 15, GOLD)


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
	ground_shadow(Vector2(feet.x, HERO_FEET_Y + 3.0), Vector2(46, 8), 0.4)
	_draw_toy(feet, "hero", mood, stretch, turn)
	if phase != "burst":
		_draw_key(feet, key_angle, stretch)
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
			draw_rect(Rect2(goal.x - 2.5, goal.y - 34.0, 5, 34), INK)
			draw_colored_polygon(PackedVector2Array([goal + Vector2(2, -34), goal + Vector2(26, -27), goal + Vector2(2, -20)]), PALETTES[look][0])
			label(goal + Vector2(0, -46), "對手 %.1f m" % distance, 15, PALETTES[look][2])
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
	ground_shadow(Vector2(feet.x, RIVAL_FEET_Y + 3.0), Vector2(40, 7), 0.34)
	_draw_toy(feet, look, mood, Vector2.ONE, 0.0, RIVAL_UNIT)
	_draw_key(feet, now * 6.0 if phase != "wind" else 0.6, Vector2.ONE, RIVAL_UNIT)


## One tin cat on wheels, facing right, standing on `feet`; `turn` spins it
## around its middle.
func _draw_toy(feet: Vector2, look: String, mood: String, stretch: Vector2, turn: float, unit := UNIT) -> void:
	var key := look + "|" + mood
	if not _toys.has(key):
		_toys[key] = _build_toy(PALETTES[look], mood)
	var blocks: Array = _toys[key]
	var middle := Vector2(0, -11.0 * unit)
	draw_set_transform_matrix(Transform2D(turn, feet + middle) * Transform2D(0.0, stretch * unit, 0.0, Vector2.ZERO) * Transform2D(0.0, Vector2(0, 11)))
	for block: Array in blocks:
		draw_rect((block[0] as Rect2).grow(0.5), INK)
	for block: Array in blocks:
		draw_rect(block[0], block[1])
	draw_set_transform(Vector2.ZERO)


## The key in the cat's back, seen edge-on as it turns.
func _draw_key(feet: Vector2, angle: float, stretch: Vector2, unit := UNIT) -> void:
	var half := 1.0 + 4.5 * absf(cos(angle))
	draw_set_transform(feet, 0.0, stretch * unit)
	draw_rect(Rect2(-12, -12, 4, 2).grow(0.5), INK)
	draw_rect(Rect2(-15, -11.0 - half, 3, half * 2.0).grow(0.5), INK)
	draw_rect(Rect2(-12, -12, 4, 2), BRASS_DARK)
	draw_rect(Rect2(-15, -11.0 - half, 3, half * 2.0), BRASS)
	draw_rect(Rect2(-15, -11.0 - half, 1, half * 2.0), Color("#ffe08a"))
	draw_set_transform(Vector2.ZERO)


func _draw_sweat(feet: Vector2) -> void:
	for drop in 2:
		var fall := 0.0 if reduced_motion else fmod(now * 1.6 + drop * 0.5, 1.0)
		var at := feet + Vector2(-12.0 + drop * 70.0, -104.0 + fall * 26.0)
		draw_rect(Rect2(at - Vector2(4, 6), Vector2(8, 12)), INK)
		draw_rect(Rect2(at - Vector2(2, 4), Vector2(4, 8)), Color("#8fd6ff"))


func _draw_dust(feet: Vector2, power: float) -> void:
	for puff in 3:
		var life := fmod(now * 3.0 + puff * 0.33, 1.0)
		var size := (6.0 + life * 12.0) * power
		var at := feet + Vector2(-46.0 - life * 46.0, -8.0 - life * 14.0)
		draw_rect(Rect2(at - Vector2(size, size) * 0.5, Vector2(size, size)), Color(1.0, 0.96, 0.86, 0.6 * (1.0 - life) * power))
	for streak in 3:
		draw_rect(Rect2(feet.x - 130.0 - streak * 26.0, feet.y - 80.0 + streak * 26.0, 70.0 * power, 4), Color(1, 1, 1, 0.35 * power))


func _draw_distance_sign(feet: Vector2, distance: float, since: float) -> void:
	var words := "%.1f 公尺" % distance
	var board := Rect2(-70, -24, 140, 44)
	var at := Vector2(clampf(feet.x, 120.0, 1160.0), feet.y - 150.0)
	draw_set_transform(at, 0.0, Vector2.ONE * pop_in(since, 0.2))
	draw_rect(board.grow(4.0), INK)
	draw_rect(board, CREAM)
	draw_rect(Rect2(-3, 20, 6, 22), INK)
	draw_set_transform(Vector2.ZERO)
	label(at + Vector2(0, -2), words, 24, INK, pop_in(since, 0.2), 1.0, false)


## The spring leaves through the back, the key flies off and bounces away.
func _draw_popped_spring(feet: Vector2, since: float) -> void:
	var out := 1.0 if reduced_motion else pop_in(since, 0.22)
	var sway := 0.0 if reduced_motion else sin(since * 16.0) * 12.0 * maxf(0.0, 1.0 - since * 0.5)
	var root := feet + Vector2(-8, -56)
	# A gentle pop of rays for the first instant.
	if since < 0.3 and not reduced_motion:
		for ray in 8:
			var along := Vector2.from_angle(ray * TAU / 8.0)
			draw_line(root + along * (30.0 + since * 160.0), root + along * (52.0 + since * 220.0), Color(CREAM, 1.0 - since / 0.3), 6.0)
	var coil := PackedVector2Array([root])
	for bend in 11:
		var rise := float(bend + 1) / 11.0
		coil.append(root + Vector2((22.0 if bend % 2 == 0 else -22.0) + sway * rise - 16.0 * rise, -170.0 * rise * out))
	draw_polyline(coil, INK, 13.0)
	draw_polyline(coil, BRASS, 7.0)
	var tip: Vector2 = coil[coil.size() - 1]
	draw_rect(Rect2(tip - Vector2(9, 9), Vector2(18, 18)), INK)
	draw_rect(Rect2(tip - Vector2(6, 6), Vector2(12, 12)), GOLD)
	# The key lands on the mat ahead of the toy and bounces once.
	var fly := 1.0 if reduced_motion else clampf(since / 0.9, 0.0, 1.0)
	var key_at := root + Vector2(210.0 * fly, -230.0 * sin(fly * PI) + 44.0 * fly)
	draw_set_transform(key_at, 0.0 if reduced_motion else since * 9.0 * (1.0 - fly))
	draw_rect(Rect2(-17, -9, 34, 18), INK)
	draw_rect(Rect2(-14, -6, 28, 12), BRASS)
	draw_rect(Rect2(-4, -3, 8, 6), INK)
	draw_set_transform(Vector2.ZERO)


func _draw_stars(center: Vector2, since: float) -> void:
	for star in 4:
		var angle := float(star) * TAU / 4.0 + (0.0 if reduced_motion else since * 5.0)
		var at := center + Vector2(cos(angle) * 54.0, sin(angle) * 16.0)
		var size := 5.0 if sin(angle) < 0.0 else 7.0
		draw_rect(Rect2(at - Vector2(size + 3.0, 5), Vector2(size * 2.0 + 6.0, 10)), INK)
		draw_rect(Rect2(at - Vector2(5, size + 3.0), Vector2(10, size * 2.0 + 6.0)), INK)
		draw_rect(Rect2(at - Vector2(size, 2), Vector2(size * 2.0, 4)), GOLD)
		draw_rect(Rect2(at - Vector2(2, size), Vector2(4, size * 2.0)), GOLD)


## Blocks in art pixels around the feet (x right, y up is negative).
static func _build_toy(palette: Array, mood: String) -> Array:
	var body: Color = palette[0]
	var shade: Color = palette[1]
	var trim: Color = palette[2]
	var blocks: Array = [
		[Rect2(-7, -4, 4, 4), DARK], [Rect2(3, -4, 4, 4), DARK],
		[Rect2(-6, -3, 2, 2), trim], [Rect2(4, -3, 2, 2), trim],
		[Rect2(-8, -12, 15, 9), body], [Rect2(-8, -6, 15, 3), shade],
		[Rect2(-5, -10, 1, 1), trim], [Rect2(-2, -10, 1, 1), trim], [Rect2(1, -10, 1, 1), trim],
		[Rect2(0, -24, 3, 3), body], [Rect2(6, -24, 3, 3), body],
		[Rect2(-1, -21, 11, 10), body], [Rect2(-1, -13, 11, 2), shade],
		[Rect2(1, -23, 1, 2), trim], [Rect2(7, -23, 1, 2), trim],
		[Rect2(7, -16, 4, 3), CREAM], [Rect2(10, -16, 1, 1), DARK],
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
			blocks.append([Rect2(7, -13, 3, 1), Color("#ff6f9c")])
		"sorry":
			blocks.append([Rect2(3, -18, 3, 1), DARK])
			blocks.append([Rect2(1, -21, 1, 2), Color("#8fd6ff")])
		_:
			blocks.append([Rect2(4, -20, 2, 3), DARK])
			blocks.append([Rect2(4, -20, 1, 1), Color.WHITE])
	return blocks
