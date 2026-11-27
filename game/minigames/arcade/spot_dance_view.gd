extends "res://game/minigames/arcade/arcade_view.gd"
## Picture for 追光躲步: the tent's stage is dark; a dance floor of lacquered
## tiles in three rows lies on the boards, and brass can-lamps on a truss above
## throw beams and warm pools across it. The hero strikes a new pose with every
## hop. The longer they stand in the dark, the bluer they get and a ring under
## their feet fills; then the lights die and only two blinking eyes are left.
## Every object is baked pixel art (arcade_pixels.gd, arcade_hero.gd) or a
## shared material.

const Hero = preload("res://game/minigames/arcade/arcade_hero.gd")
const TENT_ART := "res://assets/world/circus-tent.webp"
const FLOOR_TOP := 430.0
## Tile rows from the back: top edge, height and tile width.
const ROW_TOP: Array[float] = [450.0, 510.0, 578.0]
const ROW_HEIGHT: Array[float] = [58.0, 66.0, 78.0]
const TILE_WIDTH: Array[float] = [112.0, 126.0, 144.0]
const TRUSS_Y := 162.0
const HOP_SECONDS := 0.14
const LAMP := Color(0.94, 0.89, 0.96)
const WARM := Color("#ffe2a8")
const WOOD := Color("#6b4658")
const WOOD_DARK := Color("#3b2536")
const BRASS := Color("#b0803a")
const TILE_TONES: Array[Color] = [Color("#5a3560"), Color("#34486a")]

var _has_tent := false
var _lamp: ImageTexture
var _crowd: ImageTexture


func _init() -> void:
	super()
	word_anchor = Vector2(640, 300)


func _ready() -> void:
	_has_tent = use_backdrop_art(TENT_ART, Rect2(85, 0, 1366, 768), Color(0.55, 0.5, 0.64))
	_lamp = Pixels.bake("spot-lamp", Vector2i(14, 16), _paint_lamp)
	_crowd = Pixels.bake("spot-crowd", Vector2i(320, 22), Pixels.crowd)


func _draw_backdrop() -> void:
	if not _has_tent:
		draw_rect(Rect2(Vector2.ZERO, DESIGN), Color("#1e1630"))
	stage_floor(FLOOR_TOP, WOOD, WOOD_DARK)
	vignette(0.6)


func _draw_scene() -> void:
	var phase := str(state.get("phase", "dance"))
	var since := age(float(state.get("phase_at", 0.0)))
	_draw_tiles()
	# House lights down: only the spots light the stage.
	draw_rect(Rect2(Vector2(0, PLAY_TOP), DESIGN - Vector2(0, PLAY_TOP)), Color(0.03, 0.01, 0.06, 0.36))
	if phase != "blackout":
		_draw_pools()
	_draw_truss(phase)
	_draw_hero(phase)
	if phase != "blackout":
		_draw_beams()
	_draw_crowd()
	if phase == "blackout":
		_draw_blackout(since)


# --- Floor geometry -------------------------------------------------------------

## Screen point at the middle of tile position `at` (fractional allowed).
func _floor_point(at: Vector2) -> Vector2:
	var row := clampf(at.y, 0.0, 2.0)
	var low := floori(row)
	var high := mini(low + 1, 2)
	var mix := row - low
	var width := lerpf(TILE_WIDTH[low], TILE_WIDTH[high], mix)
	var middle := lerpf(ROW_TOP[low] + ROW_HEIGHT[low] * 0.5, ROW_TOP[high] + ROW_HEIGHT[high] * 0.5, mix)
	return Vector2(640.0 + (at.x - 3.0) * width, middle)


func _tile_rect(column: int, row: int) -> Rect2:
	var width := TILE_WIDTH[row]
	return Rect2(640.0 + (column - 3.5) * width + 3.0, ROW_TOP[row], width - 6.0, ROW_HEIGHT[row] - 6.0)


func _draw_tiles() -> void:
	var rows := int(state.get("rows", 3))
	var columns := int(state.get("columns", 7))
	var back := Rect2(_tile_rect(0, 0).position - Vector2(14, 12), Vector2(0, 0)).expand(_tile_rect(columns - 1, rows - 1).end + Vector2(14, 10))
	ground_shadow(Vector2(640, back.end.y + 6.0), Vector2(back.size.x * 0.52, 14), 0.5)
	panel(back, "lacquer", Color("#2a1d33"), GILT, 3.0, LAMP)
	for row in rows:
		for column in columns:
			var tone: Color = TILE_TONES[(row + column) % 2]
			panel(_tile_rect(column, row), "enamel", tone, Pixels.CLEAR, 3.0, LAMP)


## Warm pools on the floor; tiles inside them glow.
func _draw_pools() -> void:
	var reach := float(state.get("radius", 1.0))
	for light: Dictionary in state.get("lights", []):
		var at := _floor_point(light.pos)
		var size := Vector2(reach * _width_at(light.pos.y), reach * 66.0)
		for ring in 5:
			var grow := 1.0 - ring * 0.16
			_ellipse(at, size * grow, Color(WARM, 0.1 + ring * 0.05))
		_ellipse(at + Vector2(-size.x * 0.18, -size.y * 0.15), size * 0.3, Color(1, 1, 0.9, 0.12))


func _width_at(row: float) -> float:
	return lerpf(TILE_WIDTH[0], TILE_WIDTH[2], clampf(row / 2.0, 0.0, 1.0))


func _ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for step in 28:
		points.append(center + Vector2.from_angle(step * TAU / 28.0) * radii)
	draw_colored_polygon(points, color)


# --- Lamps ------------------------------------------------------------------------

func _lamp_at(light: Dictionary) -> Vector2:
	return Vector2(clampf(_floor_point(light.pos).x, 200.0, 1080.0), TRUSS_Y + 30.0)


func _draw_truss(phase: String) -> void:
	panel(Rect2(130, TRUSS_Y - 8.0, 1020, 16), "pole", BRASS.darkened(0.2), Pixels.CLEAR, 2.0, LAMP)
	for x in range(150, 1140, 60):
		draw_line(Vector2(x, TRUSS_Y - 8.0), Vector2(x + 30, TRUSS_Y + 8.0), BRASS.darkened(0.55), 3.0)
	if phase == "blackout":
		return
	for light: Dictionary in state.get("lights", []):
		var hang := _lamp_at(light)
		var aim := (_floor_point(light.pos) - hang).angle() - PI * 0.5
		draw_line(Vector2(hang.x, TRUSS_Y), hang, INK, 4.0)
		draw_set_transform(hang, aim, Vector2.ONE * TEXEL)
		stamp(_lamp, Vector2(-7, -4), 1.0, LAMP)
		draw_set_transform(Vector2.ZERO)


## Soft beams from each lamp down to its pool, drawn over the hero like haze.
func _draw_beams() -> void:
	var reach := float(state.get("radius", 1.0))
	for light: Dictionary in state.get("lights", []):
		var hang := _lamp_at(light) + Vector2(0, 40)
		var at := _floor_point(light.pos)
		var half := reach * _width_at(light.pos.y)
		draw_colored_polygon(PackedVector2Array([hang + Vector2(-16, 0), hang + Vector2(16, 0), at + Vector2(half, 0), at + Vector2(-half, 0)]), Color(WARM, 0.07))
		draw_colored_polygon(PackedVector2Array([hang + Vector2(-6, 0), hang + Vector2(6, 0), at + Vector2(half * 0.5, 0), at + Vector2(-half * 0.5, 0)]), Color(WARM, 0.06))


# --- Hero -------------------------------------------------------------------------

func _hero_feet() -> Vector2:
	var tile: Vector2i = state.get("tile", Vector2i(3, 1))
	var from: Vector2i = state.get("hop_from", tile)
	var t := 1.0 if reduced_motion else clampf(age(float(state.get("hop_at", -9.0))) / HOP_SECONDS, 0.0, 1.0)
	var at := _floor_point(Vector2(from)).lerp(_floor_point(Vector2(tile)), t)
	at.y += 14.0 - 26.0 * sin(t * PI)
	return at


func _draw_hero(phase: String) -> void:
	var tile: Vector2i = state.get("tile", Vector2i(3, 1))
	var from: Vector2i = state.get("hop_from", tile)
	var since_hop := age(float(state.get("hop_at", -9.0)))
	var step := tile - from
	var pose := &"idle"
	if since_hop < 0.6:
		pose = &"left" if step.x < 0 else (&"right" if step.x > 0 else &"up")
	var dark := float(state.get("dark", 0.0))
	var lit := bool(state.get("lit", true))
	var mood := "shocked" if dark > 0.45 else ("tongue" if int(state.get("combo", 0)) >= 3 else "plain")
	var feet := _hero_feet()
	var tint := LAMP.lerp(WARM, 0.25) if lit else LAMP.lerp(Color("#5a6a9a"), 0.55)
	if phase == "blackout":
		return
	ground_shadow(feet + Vector2(0, 2), Vector2(44, 9), 0.5)
	var stretch := squash(since_hop - HOP_SECONDS, 0.16)
	draw_set_transform(feet, 0.0, stretch * TEXEL)
	stamp(Hero.texture(pose, true, mood), -Hero.FEET, 1.0, tint)
	draw_set_transform(Vector2.ZERO)
	if dark > 0.0:
		# The dark ring fills under the feet: when it closes, the lights die.
		draw_arc(feet + Vector2(0, 4), 52.0, -PI * 0.5, -PI * 0.5 + TAU * dark, 32, INK, 9.0)
		draw_arc(feet + Vector2(0, 4), 52.0, -PI * 0.5, -PI * 0.5 + TAU * dark, 32, ROSE, 5.0)
		label(feet + Vector2(0, -210), "回光裡！", 22, ROSE, 0.9 + 0.1 * pulse(4.0))


# --- Audience and blackout ----------------------------------------------------------

func _draw_crowd() -> void:
	var bob := 0.0 if reduced_motion else roundf(sin(now * 2.0) * 2.0)
	stamp(_crowd, Vector2(0, DESIGN.y - 76.0 + bob), TEXEL, Color(0.42, 0.36, 0.5))


## Everything goes black; only the hero's two eyes blink where the head was.
func _draw_blackout(since: float) -> void:
	var fade := 1.0 if reduced_motion else clampf(since / 0.15, 0.0, 1.0)
	draw_rect(Rect2(Vector2(0, PLAY_TOP), DESIGN - Vector2(0, PLAY_TOP)), Color(0.01, 0.0, 0.02, 0.96 * fade))
	var head := _floor_point(Vector2(state.get("tile", Vector2i(3, 1)))) + Vector2(0, 14.0)
	var blink := not reduced_motion and fmod(since, 0.9) > 0.78
	# Eyes look left, then right, then at the audience.
	var glance: float = 0.0 if reduced_motion else [0.0, -3.0, 3.0][int(since / 0.7) % 3]
	for eye: float in [-38.0, 38.0]:
		var at := head + Vector2(eye + glance, -140.0)
		draw_set_transform(at, 0.0, Vector2.ONE * 1.7)
		if blink:
			draw_rect(Rect2(Vector2(-14, -2), Vector2(28, 6)), Color("#d8d0c0"))
			draw_rect(Rect2(Vector2(-12, -1), Vector2(24, 3)), Color("#fffaf0"))
		else:
			# Big round cartoon eyes, lit from the top left.
			draw_rect(Rect2(Vector2(-12, -16), Vector2(24, 30)), Color("#c8c0b0"))
			draw_rect(Rect2(Vector2(-14, -12), Vector2(28, 22)), Color("#c8c0b0"))
			draw_rect(Rect2(Vector2(-11, -15), Vector2(22, 27)), Color("#fffaf0"))
			draw_rect(Rect2(Vector2(-13, -11), Vector2(26, 19)), Color("#fffaf0"))
			draw_rect(Rect2(Vector2(-6 + glance * 1.5, -6), Vector2(12, 14)), INK)
			draw_rect(Rect2(Vector2(-4 + glance * 1.5, -5), Vector2(4, 4)), Color("#fffaf0"))
		draw_set_transform(Vector2.ZERO)
	if since > 0.3:
		# A cold sweat drop slides down beside the eyes.
		var slide := 0.0 if reduced_motion else fmod(since * 0.8, 1.0) * 18.0
		var drop := head + Vector2(78, -172 + slide)
		draw_rect(Rect2(drop + Vector2(-4, -6), Vector2(8, 14)), Color("#5a8ab0"))
		draw_rect(Rect2(drop + Vector2(-3, -4), Vector2(5, 10)), Color("#9fdcff"))
	if since > 0.6:
		label(head + Vector2(70, -170), "……", 26, CREAM, 1.0, 0.8)
		label(Vector2(200, 650), "咦？", 24, CREAM, 1.0, 0.6)
		label(Vector2(1080, 640), "停電？", 24, CREAM, 1.0, 0.6)


## A brass can-lamp pointing down: barrel, yoke and a glowing lens.
func _paint_lamp(x: int, y: int) -> Color:
	if y < 3:
		return Pixels.metal(BRASS.darkened(0.2), x, y) if x >= 5 and x <= 8 else Pixels.CLEAR
	if y >= 14:
		return Pixels.lit(WARM, 1.2, x, y) if x >= 3 and x <= 10 else Pixels.CLEAR
	if x < 2 or x > 11:
		return Pixels.CLEAR
	var body := Color("#3a3446")
	if y == 4 or y == 12:
		return Pixels.metal(BRASS, x, y)
	return Pixels.lit(body, 0.7 - absf(x - 4.0) / 6.0, x, y)
