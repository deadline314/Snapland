extends RefCounted
## The roaming thief's pixel frames, painted once from simple shapes: a chibi
## figure in a beret and domino mask, striped shirt, plum cape and a burlap
## sack with the stolen thing poking out. Shapes are authored on a 48 x 60
## design grid facing right (flip for left) and painted at SCALE, so the art
## matches the hero's pixel density. One column per pose, one row per loot.

const SCALE := 1.25
const CELL := Vector2i(60, 75)
enum { STAND, RUN_A, RUN_B, LOOK, TAUNT, HOP, DIZZY, PUFF_A, PUFF_B }
const POSE_COUNT := 9
const LOOT := ["balloon", "hat", "fish", "lollipop"]

# Outlines are a deep plum, never black (scene standards, section 3).
const OUT := Color("#2f2440")
const SKIN := Color("#f1c8a0")
const SKIN_SH := Color("#d49c78")
const BLUSH := Color("#ec9a88")
const HAIR := Color("#4a3130")
const HAT := Color("#433c66")
const HAT_SH := Color("#2f2a4d")
const MASK := Color("#2c2a45")
const EYE := Color("#fff7e8")
const PUPIL := Color("#2f2440")
const MOUTH := Color("#7a2f3a")
const TONGUE := Color("#ef7f8e")
const CREAM := Color("#f2e9d4")
const CREAM_SH := Color("#cfc3a8")
const NAVY := Color("#3f5f93")
const NAVY_SH := Color("#2e4672")
const PANTS := Color("#3b3558")
const SHOES := Color("#6a4031")
const BELT := Color("#5a3d2c")
const CAPE := Color("#9b3a58")
const CAPE_SH := Color("#732a44")
const LINING := Color("#e3ae4a")
const SACK := Color("#cfab72")
const SACK_SH := Color("#a7834f")
const SACK_TIE := Color("#6b4b2f")
const STAR := Color("#ffd768")
const PUFF := Color("#eeeaf4")
const PUFF_SH := Color("#bdb6cf")
const RED := Color("#e2604f")
const RED_SH := Color("#b7443b")
const TEAL := Color("#2f7276")
const TEAL_SH := Color("#21545a")
const CORAL := Color("#ee8a62")
const FISH := Color("#86b0c2")
const FISH_SH := Color("#5d879c")
const PINK := Color("#f08aa8")
const STRING := Color("#5b5368")

static var _atlas: ImageTexture
static var _visible_rows := Vector2i(-1, -1)

var _img: Image


static func atlas() -> ImageTexture:
	if _atlas == null:
		var image := Image.create(CELL.x * POSE_COUNT, CELL.y * LOOT.size(), false, Image.FORMAT_RGBA8)
		var painter := new()
		for row in range(LOOT.size()):
			for pose in range(POSE_COUNT):
				image.blit_rect(painter.paint(pose, String(LOOT[row])), Rect2i(Vector2i.ZERO, CELL), Vector2i(pose * CELL.x, row * CELL.y))
		_atlas = ImageTexture.create_from_image(image)
	return _atlas


## First and last opaque rows of the standing frame: its head top and its soles.
static func visible_rows() -> Vector2i:
	if _visible_rows.x < 0:
		# The hat sits low in the sack, so the beret is the top of this frame.
		var frame: Image = new().paint(STAND, "hat")
		var top := -1
		var bottom := -1
		for y in range(CELL.y):
			for x in range(CELL.x):
				if frame.get_pixel(x, y).a > 0.5:
					if top < 0: top = y
					bottom = y
					break
		_visible_rows = Vector2i(top, bottom)
	return _visible_rows


static func loot_index(kind: String) -> int:
	return maxi(0, LOOT.find(kind))


func paint(pose: int, loot: String) -> Image:
	_img = Image.create(CELL.x, CELL.y, false, Image.FORMAT_RGBA8)
	match pose:
		STAND: _stand(loot)
		RUN_A: _run(loot, false)
		RUN_B: _run(loot, true)
		LOOK: _look(loot)
		TAUNT: _taunt(loot)
		HOP: _hop(loot)
		DIZZY: _dizzy(loot)
		PUFF_A: _puff(false)
		PUFF_B: _puff(true)
	return _img


# --- poses -----------------------------------------------------------------

func _stand(loot: String) -> void:
	_poly([Vector2(17, 33), Vector2(30, 33), Vector2(31, 50), Vector2(24, 52), Vector2(15, 51), Vector2(12, 47)], CAPE, CAPE_SH)
	_poly([Vector2(12, 47), Vector2(15, 51), Vector2(17, 50), Vector2(15, 40)], LINING)
	_sack(Vector2(12, 33), loot)
	_leg(Vector2(20, 47), Vector2(20, 54))
	_leg(Vector2(26, 47), Vector2(26.5, 54))
	_ellipse(Vector2(21, 55.5), Vector2(3, 1.8), SHOES)
	_ellipse(Vector2(27.5, 55.5), Vector2(3, 1.8), SHOES)
	_torso(Vector2(23, 42))
	_arm(Vector2(27, 38), Vector2(28.5, 45))
	_arm(Vector2(19, 37), Vector2(14, 28))
	_head_side(Vector2(25, 24), false)
	_outline()
	_after_outline(loot, Vector2(12, 25))


func _run(loot: String, passing: bool) -> void:
	var lift := -1.0 if passing else 0.0
	if passing:
		_poly([Vector2(17, 32), Vector2(29, 32), Vector2(25, 46), Vector2(10, 50), Vector2(5, 45), Vector2(11, 37)], CAPE, CAPE_SH)
		_poly([Vector2(5, 45), Vector2(10, 50), Vector2(12, 47), Vector2(9, 42)], LINING)
	else:
		_poly([Vector2(17, 33), Vector2(29, 33), Vector2(26, 45), Vector2(8, 49), Vector2(3, 42), Vector2(10, 36)], CAPE, CAPE_SH)
		_poly([Vector2(3, 42), Vector2(8, 49), Vector2(10, 46), Vector2(7, 40)], LINING)
	_sack(Vector2(13, 33 + lift), loot)
	if passing:
		_leg(Vector2(22, 46), Vector2(19, 51))
		_ellipse(Vector2(18.5, 52), Vector2(2.6, 1.7), SHOES)
		_leg(Vector2(25, 46), Vector2(27, 53))
		_ellipse(Vector2(28.5, 54.6), Vector2(3, 1.8), SHOES)
	else:
		_leg(Vector2(21, 47), Vector2(15.5, 52))
		_ellipse(Vector2(14, 53.5), Vector2(2.8, 1.8), SHOES)
		_leg(Vector2(26, 47), Vector2(31, 53))
		_ellipse(Vector2(32.5, 54.8), Vector2(3, 1.8), SHOES)
	_torso(Vector2(24, 41 + lift))
	_arm(Vector2(28, 37 + lift), Vector2(33, 42 + lift) if not passing else Vector2(30, 44 + lift))
	_arm(Vector2(20, 36 + lift), Vector2(15, 28 + lift))
	_head_side(Vector2(26, 23 + lift), false)
	_outline()
	_after_outline(loot, Vector2(13, 25 + lift))


## Running, head turned back over the shoulder with a tongue out.
func _look(loot: String) -> void:
	_poly([Vector2(17, 33), Vector2(29, 33), Vector2(26, 45), Vector2(8, 49), Vector2(3, 42), Vector2(10, 36)], CAPE, CAPE_SH)
	_poly([Vector2(3, 42), Vector2(8, 49), Vector2(10, 46), Vector2(7, 40)], LINING)
	_sack(Vector2(13, 33), loot)
	_leg(Vector2(21, 47), Vector2(17, 53))
	_ellipse(Vector2(16, 54.6), Vector2(2.8, 1.8), SHOES)
	_leg(Vector2(26, 47), Vector2(29, 54))
	_ellipse(Vector2(30.5, 55.3), Vector2(3, 1.8), SHOES)
	_torso(Vector2(24, 41))
	_arm(Vector2(28, 37), Vector2(31, 44))
	_arm(Vector2(20, 36), Vector2(15, 28))
	_head_side(Vector2(24, 23), true)
	_outline()
	_after_outline(loot, Vector2(13, 25))


## Facing the camera, sack set down, both hands waggling: "catch me!"
func _taunt(loot: String) -> void:
	_poly([Vector2(16, 34), Vector2(32, 34), Vector2(36, 52), Vector2(12, 52)], CAPE, CAPE_SH)
	_sack(Vector2(8, 51), loot, 5.5)
	_leg(Vector2(21, 47), Vector2(21, 54))
	_leg(Vector2(27, 47), Vector2(27, 54))
	_ellipse(Vector2(20.5, 55.5), Vector2(3, 1.8), SHOES)
	_ellipse(Vector2(27.5, 55.5), Vector2(3, 1.8), SHOES)
	_torso(Vector2(24, 42))
	_arm(Vector2(18, 37), Vector2(13, 30))
	_arm(Vector2(30, 37), Vector2(35, 30))
	_head_front(Vector2(24, 24), true)
	_outline()
	_after_outline(loot, Vector2(8, 46))


func _hop(loot: String) -> void:
	_poly([Vector2(17, 31), Vector2(29, 31), Vector2(28, 40), Vector2(12, 45), Vector2(4, 38), Vector2(11, 33)], CAPE, CAPE_SH)
	_poly([Vector2(4, 38), Vector2(12, 45), Vector2(13, 42), Vector2(8, 37)], LINING)
	_sack(Vector2(13, 31), loot)
	_leg(Vector2(21, 45), Vector2(19, 49))
	_leg(Vector2(26, 45), Vector2(29, 49))
	_ellipse(Vector2(18.5, 50.5), Vector2(2.8, 1.8), SHOES)
	_ellipse(Vector2(30, 50.5), Vector2(2.8, 1.8), SHOES)
	_torso(Vector2(24, 39))
	_arm(Vector2(28, 35), Vector2(33, 30))
	_arm(Vector2(20, 34), Vector2(15, 26))
	_head_side(Vector2(26, 21), false)
	_outline()
	_after_outline(loot, Vector2(13, 23))


## Caught: sat down with seeing stars, the sack dropped and the loot rolling out.
func _dizzy(loot: String) -> void:
	_poly([Vector2(16, 40), Vector2(32, 40), Vector2(35, 54), Vector2(13, 54)], CAPE, CAPE_SH)
	_sack(Vector2(41, 52), loot, 5.0)
	_leg(Vector2(21, 50), Vector2(16, 54))
	_leg(Vector2(27, 50), Vector2(32, 54))
	_ellipse(Vector2(15, 55.4), Vector2(2.8, 1.8), SHOES)
	_ellipse(Vector2(33, 55.4), Vector2(2.8, 1.8), SHOES)
	_torso(Vector2(24, 47))
	_arm(Vector2(18, 43), Vector2(15, 49))
	_arm(Vector2(30, 43), Vector2(33, 49))
	_head_front(Vector2(24, 31), false)
	_outline()
	_after_outline(loot, Vector2(41, 47))
	for star: Vector2 in [Vector2(13, 18), Vector2(35, 16), Vector2(24, 13)]:
		_star(star)


func _puff(late: bool) -> void:
	var grow := 1.3 if late else 1.0
	var tone := PUFF if not late else Color(PUFF, 0.78)
	var shade := PUFF_SH if not late else Color(PUFF_SH, 0.72)
	for blob: Vector3 in [Vector3(24, 44, 9), Vector3(15, 48, 6.5), Vector3(33, 48, 6.5), Vector3(20, 36, 6), Vector3(29, 35, 6.5)]:
		_ellipse(Vector2(blob.x, blob.y), Vector2(blob.z, blob.z * 0.9) * grow, tone, shade)
	if late:
		for star: Vector2 in [Vector2(8, 30), Vector2(40, 28), Vector2(24, 22)]:
			_star(star)


# --- parts -----------------------------------------------------------------

func _torso(center: Vector2) -> void:
	var c := center * SCALE
	var r := Vector2(7, 7.5) * SCALE
	for y in range(floori(c.y - r.y), ceili(c.y + r.y) + 1):
		for x in range(floori(c.x - r.x), ceili(c.x + r.x) + 1):
			var n := (Vector2(x + 0.5, y + 0.5) - c) / r
			if n.length_squared() > 1.0: continue
			var navy := posmod(floori((y - c.y) / (2.0 * SCALE)), 2) == 0
			var shaded := n.x * 0.6 + n.y * 0.6 > 0.42
			_put(x, y, (NAVY_SH if shaded else NAVY) if navy else (CREAM_SH if shaded else CREAM))
	_line(center + Vector2(-6.5, 5.5), center + Vector2(6.5, 5.5), BELT, 1.0)


func _leg(hip: Vector2, foot: Vector2) -> void:
	_line(hip, foot, PANTS, 2.6)


func _arm(shoulder: Vector2, hand: Vector2) -> void:
	_line(shoulder, hand, NAVY, 2.4)
	_ellipse(hand, Vector2(1.7, 1.7), SKIN)


func _sack(center: Vector2, loot: String, size := 7.0) -> void:
	# The loot sits in the sack's mouth, behind its rim.
	_loot(loot, center + Vector2(0, -size * 1.05))
	_ellipse(center, Vector2(size, size * 1.1), SACK, SACK_SH)
	_ellipse(center + Vector2(0, -size * 1.0), Vector2(size * 0.45, size * 0.28), SACK)
	_line(center + Vector2(-size * 0.4, -size * 0.8), center + Vector2(size * 0.4, -size * 0.8), SACK_TIE, 1.2)
	_set_design(center + Vector2(size * 0.2, size * 0.15), SACK_SH)
	_set_design(center + Vector2(-size * 0.35, size * 0.35), SACK_SH)


## A 3/4 head facing right, or turned back to the left with the tongue out.
func _head_side(center: Vector2, back: bool) -> void:
	var side := -1.0 if back else 1.0
	_ellipse(center + Vector2(-8 * side, -3), Vector2(3, 4), HAIR)
	_ellipse(center, Vector2(10, 9.5), SKIN, SKIN_SH)
	_ellipse(center + Vector2(10 * side, 2), Vector2(1.5, 1.3), SKIN)
	_ellipse(center + Vector2(5 * side, 4), Vector2(1.3, 0.8), BLUSH)
	_ellipse(center + Vector2(1 * side, -1.5), Vector2(10.6, 3.3), MASK)
	_poly([center + Vector2(-8 * side, -3), center + Vector2(-15 * side, -6), center + Vector2(-15.5 * side, -0.5), center + Vector2(-8 * side, 0)], MASK)
	for eye_x: float in [0.0, 6.0]:
		_ellipse(center + Vector2(eye_x * side, -1.5), Vector2(1.9, 2.1), EYE)
		_set_design(center + Vector2((eye_x + 1.0) * side, -1.0), PUPIL)
		_set_design(center + Vector2((eye_x + 1.0) * side, -2.0), PUPIL)
	_line(center + Vector2(2 * side, 5), center + Vector2(7 * side, 5), MOUTH, 1.0)
	_set_design(center + Vector2(8 * side, 4), MOUTH)
	if back:
		_ellipse(center + Vector2(-4.5, 6.4), Vector2(1.5, 1.4), TONGUE)
	_beret(center + Vector2(-0.5 * side, -9), side)


func _head_front(center: Vector2, laughing: bool) -> void:
	_ellipse(center, Vector2(10, 9.5), SKIN, SKIN_SH)
	_ellipse(center + Vector2(-5.5, 4), Vector2(1.3, 0.8), BLUSH)
	_ellipse(center + Vector2(5.5, 4), Vector2(1.3, 0.8), BLUSH)
	_ellipse(center + Vector2(0, -1.5), Vector2(10.8, 3.3), MASK)
	_poly([center + Vector2(-9, -3), center + Vector2(-14, -6.5), center + Vector2(-13.5, -1), center + Vector2(-9, 0)], MASK)
	_poly([center + Vector2(9, -3), center + Vector2(14, -6.5), center + Vector2(13.5, -1), center + Vector2(9, 0)], MASK)
	for eye_x: float in [-4.0, 4.0]:
		_ellipse(center + Vector2(eye_x, -1.5), Vector2(1.9, 2.1), EYE)
		if laughing:
			_set_design(center + Vector2(eye_x, -2.0), PUPIL)
		else:
			# Seeing stars: an X in each eye hole.
			_set_design(center + Vector2(eye_x - 1, -2.5), PUPIL)
			_set_design(center + Vector2(eye_x + 1, -2.5), PUPIL)
			_set_design(center + Vector2(eye_x, -1.5), PUPIL)
			_set_design(center + Vector2(eye_x - 1, -0.5), PUPIL)
			_set_design(center + Vector2(eye_x + 1, -0.5), PUPIL)
	if laughing:
		_ellipse(center + Vector2(0, 5), Vector2(2.6, 1.9), MOUTH)
		_ellipse(center + Vector2(0, 6), Vector2(1.5, 0.9), TONGUE)
	else:
		_line(center + Vector2(-2.5, 5.5), center + Vector2(2.5, 4.5), MOUTH, 1.0)
	_beret(center + Vector2(2.5 if not laughing else 0.0, -9), 1.0 if laughing else -1.0)


func _beret(center: Vector2, side: float) -> void:
	_ellipse(center, Vector2(10.5, 4), HAT, HAT_SH)
	_ellipse(center + Vector2(-1.5 * side, -4), Vector2(1.3, 1.3), HAT)


func _loot(kind: String, mouth: Vector2) -> void:
	match kind:
		"balloon":
			_ellipse(mouth + Vector2(-2, -17), Vector2(4.6, 5.6), RED, RED_SH)
			_set_design(mouth + Vector2(-3.5, -19.5), Color("#ffd2c4"))
			_poly([mouth + Vector2(-3, -11.5), mouth + Vector2(-1, -11.5), mouth + Vector2(-2, -10)], RED_SH)
		"hat":
			_ellipse(mouth + Vector2(0, -1.5), Vector2(6.2, 1.6), TEAL_SH)
			_rect(mouth + Vector2(-4, -10), mouth + Vector2(4, -2), TEAL, TEAL_SH)
			_rect(mouth + Vector2(-4, -4), mouth + Vector2(4, -3), CORAL)
		"fish":
			_ellipse(mouth + Vector2(0, -6), Vector2(2.9, 6.2), FISH, FISH_SH)
			_poly([mouth + Vector2(-2.5, -0.5), mouth + Vector2(2.5, -0.5), mouth + Vector2(0, -3)], FISH_SH)
			_set_design(mouth + Vector2(1, -9.5), PUPIL)
		"lollipop":
			_ellipse(mouth + Vector2(0, -14), Vector2(4.6, 4.6), PINK)
			_ring(mouth + Vector2(0, -14), 2.6, EYE)
			_set_design(mouth + Vector2(0, -14), EYE)


## Thin things drawn after the outline pass so they stay one pixel wide.
func _after_outline(loot: String, mouth: Vector2) -> void:
	if loot == "balloon":
		_line(mouth + Vector2(0, 0), mouth + Vector2(-2, -10), STRING, 0.8)
	elif loot == "lollipop":
		_line(mouth + Vector2(0, 0), mouth + Vector2(0, -9.5), EYE, 0.9)


func _star(at: Vector2) -> void:
	for step: Vector2 in [Vector2.ZERO, Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
		_set_design(at + step * 1.2, STAR)


# --- pixel primitives (design units, painted at SCALE) ----------------------

func _put(x: int, y: int, color: Color) -> void:
	if x < 0 or y < 0 or x >= CELL.x or y >= CELL.y: return
	if color.a < 1.0:
		color = _img.get_pixel(x, y).blend(color)
	_img.set_pixel(x, y, color)


func _set_design(point: Vector2, color: Color) -> void:
	_put(floori(point.x * SCALE), floori(point.y * SCALE), color)


## Filled ellipse; the lower right (away from the late-day sun) takes `shade`.
func _ellipse(center: Vector2, radius: Vector2, base: Color, shade := Color(0, 0, 0, 0)) -> void:
	var c := center * SCALE
	var r := radius * SCALE
	for y in range(floori(c.y - r.y), ceili(c.y + r.y) + 1):
		for x in range(floori(c.x - r.x), ceili(c.x + r.x) + 1):
			var n := (Vector2(x + 0.5, y + 0.5) - c) / r
			if n.length_squared() > 1.0: continue
			_put(x, y, shade if shade.a > 0.0 and n.x * 0.6 + n.y * 0.6 > 0.42 else base)


func _ring(center: Vector2, radius: float, color: Color) -> void:
	var c := center * SCALE
	var r := radius * SCALE
	for y in range(floori(c.y - r - 1), ceili(c.y + r + 1) + 1):
		for x in range(floori(c.x - r - 1), ceili(c.x + r + 1) + 1):
			if absf((Vector2(x + 0.5, y + 0.5) - c).length() - r) < 0.6: _put(x, y, color)


func _rect(from: Vector2, to: Vector2, base: Color, shade := Color(0, 0, 0, 0)) -> void:
	var a := (from * SCALE).floor()
	var b := (to * SCALE).ceil()
	for y in range(int(a.y), int(b.y)):
		for x in range(int(a.x), int(b.x)):
			_put(x, y, shade if shade.a > 0.0 and x >= int(b.x) - 2 else base)


func _poly(points: Array, base: Color, shade := Color(0, 0, 0, 0)) -> void:
	var scaled := PackedVector2Array()
	for point: Vector2 in points:
		scaled.append(point * SCALE)
	var bounds := Rect2(scaled[0], Vector2.ZERO)
	for point in scaled:
		bounds = bounds.expand(point)
	for y in range(floori(bounds.position.y), ceili(bounds.end.y) + 1):
		for x in range(floori(bounds.position.x), ceili(bounds.end.x) + 1):
			var p := Vector2(x + 0.5, y + 0.5)
			if not Geometry2D.is_point_in_polygon(p, scaled): continue
			var t := (p.y - bounds.position.y) / maxf(bounds.size.y, 1.0)
			_put(x, y, shade if shade.a > 0.0 and t > 0.72 else base)


func _line(from: Vector2, to: Vector2, color: Color, width: float) -> void:
	var a := from * SCALE
	var b := to * SCALE
	var steps := maxi(1, ceili(a.distance_to(b) * 2.0))
	var half := width * SCALE * 0.5
	for step in range(steps + 1):
		var p := a.lerp(b, float(step) / steps)
		for y in range(floori(p.y - half), ceili(p.y + half)):
			for x in range(floori(p.x - half), ceili(p.x + half)):
				if Vector2(x + 0.5, y + 0.5).distance_to(p) <= maxf(half, 0.5): _put(x, y, color)


## A one-pixel outline around everything painted so far.
func _outline() -> void:
	var source := _img.duplicate() as Image
	for y in range(CELL.y):
		for x in range(CELL.x):
			if source.get_pixel(x, y).a > 0.0: continue
			for step: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n := Vector2i(x, y) + step
				if n.x >= 0 and n.y >= 0 and n.x < CELL.x and n.y < CELL.y and source.get_pixel(n.x, n.y).a > 0.5:
					_img.set_pixel(x, y, OUT)
					break
