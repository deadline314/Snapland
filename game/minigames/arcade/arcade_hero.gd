extends RefCounted
## The park's traveller as a small pixel sprite for arcade pictures, matching
## the island hero: spiky navy hair with a cream streak, teal coat over a
## striped shirt, cream shorts, brown boots, the red camera in front and the
## satchel behind. One texture per pose, facing and mood, baked once through
## arcade_pixels.gd (which adds the lit edges and the outline).

const Pixels = preload("res://game/minigames/arcade/arcade_pixels.gd")
const SIZE := Vector2i(40, 46)
## Texel point under the middle of the boots in the baked texture (which has
## one outline texel on every side).
const FEET := Vector2(21, 47)
enum { EMPTY, HAIR, STREAK, SKIN, COAT, CUFF, SHIRT, SHORTS, BOOTS, BAG, CAMERA }
const COLORS: Array[Color] = [
	Color(0, 0, 0, 0), Color("#2f3660"), Color("#e9dcc0"), Color("#ebb894"), Color("#2f8290"), Color("#e0675e"),
	Color("#efe4cc"), Color("#e3d6b8"), Color("#7a4a2c"), Color("#8a5a34"), Color("#b23a44"),
]
const INK := Color("#241c34")
const STRIPE := Color("#36406e")
const BLUSH := Color("#f08c8c")
const TONGUE := Color("#ff7fa0")
const SWEAT := Color("#9fdcff")
const BUCKLE := Color("#e8b44a")

## Per part: shade, base and light tones.
static var _ramps: Array = []


## `pose` is idle, left, right, up (arms only) or nose (pinching it, front
## only); `front` faces the viewer. Moods change the face: plain, shocked,
## sorry, tongue, stinky (eyes squeezed shut and watering); soaked is sorry
## with the hair plastered flat and wet over the brow.
static func texture(pose: StringName, front: bool, mood := "plain") -> Texture2D:
	var key := "arcade-hero|%s|%s|%s" % [pose, front, mood]
	var painted: Image = null
	return Pixels.bake(key, SIZE, func(x: int, y: int) -> Color:
		if painted == null:
			painted = _paint(pose, front, mood)
		return painted.get_pixel(x, y))


static func _paint(pose: StringName, front: bool, mood: String) -> Image:
	if _ramps.is_empty():
		for color in COLORS:
			_ramps.append([color, Pixels.lit(color, -1.0, 0, 0), color, Pixels.lit(color, 1.0, 0, 0)])
	var ids := PackedByteArray()
	ids.resize(SIZE.x * SIZE.y)
	var lean := -1 if pose == &"left" else (1 if pose == &"right" else 0)
	_fill(ids, 15, 39, 17, 40, SKIN)
	_fill(ids, 23, 39, 25, 40, SKIN)
	_fill(ids, 13, 41, 18, 45, BOOTS)
	_fill(ids, 22, 41, 27, 45, BOOTS)
	_fill(ids, 14, 35, 26, 38, SHORTS)
	_fill(ids, 12, 22, 28, 31, COAT)
	_fill(ids, 11, 32, 29, 34, COAT)
	if front:
		_fill(ids, 18, 22, 22, 31, SHIRT)
		_fill(ids, 17, 27, 23, 31, CAMERA)
	else:
		_fill(ids, 14, 23, 26, 33, BAG)
	var hands := [Vector2(10, 33), Vector2(30, 33)]
	match pose:
		&"left":
			hands[0] = Vector2(2.5, 22)
		&"right":
			hands[1] = Vector2(37.5, 22)
		&"up":
			hands = [Vector2(6, 4.5), Vector2(34, 4.5)]
	if pose != &"nose" or not front:
		_arm(ids, Vector2(11.5, 24), hands[0])
	_arm(ids, Vector2(28.5, 24), hands[1])
	var hx := 20 + lean
	_fill(ids, hx - 2, 19, hx + 2, 22, SKIN)
	var soaked := mood == "soaked"
	if soaked:
		# No spikes: the wet hair lies flat in a low cap with strands stuck to the cheeks.
		_ellipse(ids, Vector2(hx, 12), Vector2(10.2, 6.4), HAIR)
		for strand: int in [-9, -8, 8, 9]:
			_fill(ids, hx + strand, 12, hx + strand, 19 - absi(strand) % 2 * 2, HAIR)
	else:
		_ellipse(ids, Vector2(hx, 11), Vector2(9.6, 8.2), HAIR)
		for spike: Vector3 in [Vector3(-6, 1, 2), Vector3(-2, 0, 2), Vector3(3, 0, 2), Vector3(7, 2, 2), Vector3(-10, 8, 1), Vector3(10, 7, 1)]:
			_ellipse(ids, Vector2(hx + spike.x, spike.y + 2.0), Vector2(spike.z, 2.4), HAIR)
	if front:
		_fill(ids, hx - 7, 10, hx + 7, 19, SKIN)
		_fill(ids, hx - 5, 20, hx + 5, 20, SKIN)
		for x in range(hx - 7, hx + 8):
			# A wet fringe hangs lower, in dripping points.
			_fill(ids, x, 9, x, (11 + posmod(x * 5, 3) * 1) if soaked else (10 + posmod(x * 7, 3)), HAIR)
		_fill(ids, hx - 8, 10, hx - 8, 14, HAIR)
		_fill(ids, hx + 8, 10, hx + 8, 14, HAIR)
		if not soaked:
			for at: Vector2i in [Vector2i(4, 3), Vector2i(5, 4), Vector2i(5, 5), Vector2i(6, 6), Vector2i(6, 7)]:
				_put(ids, hx + at.x, at.y, STREAK)
	else:
		_fill(ids, hx - 5, 17, hx + 5, 21, HAIR)
		for at: Vector2i in [Vector2i(-4, 3), Vector2i(-5, 4), Vector2i(-5, 5), Vector2i(-6, 6), Vector2i(-6, 7)]:
			_put(ids, hx + at.x, at.y, STREAK)
	var image := _shade(ids)
	_details(image, ids, front, mood, hx)
	if pose == &"nose" and front:
		_pinch(image, hx)
	return image


## The sleeve rises across the chest, the cuff sits under the chin and an
## outlined hand pinches the nose; painted after the face so it stays on top.
static func _pinch(image: Image, hx: int) -> void:
	var coat: Array = _ramps[COAT]
	for step in 6:
		var x := hx - 9 + step
		var y := 23 - step
		image.set_pixel(x, y, coat[3] if step % 2 == 0 else coat[2])
		image.set_pixel(x, y + 1, coat[2])
		image.set_pixel(x, y + 2, coat[1])
	for at: Vector2i in [Vector2i(hx - 3, 17), Vector2i(hx - 3, 18), Vector2i(hx - 2, 18), Vector2i(hx - 4, 18)]:
		image.set_pixel(at.x, at.y, _ramps[CUFF][2])
	var outline := (_ramps[SKIN][1] as Color).darkened(0.55)
	for x in range(hx - 2, hx + 2):
		image.set_pixel(x, 13, outline)
		image.set_pixel(x, 14, _ramps[SKIN][3])
		image.set_pixel(x, 15, _ramps[SKIN][2])
		image.set_pixel(x, 16, _ramps[SKIN][2])
		image.set_pixel(x, 17, outline)
	image.set_pixel(hx + 2, 14, outline)
	image.set_pixel(hx + 2, 15, outline)
	image.set_pixel(hx + 2, 16, outline)
	image.set_pixel(hx - 1, 15, _ramps[SKIN][1])
	image.set_pixel(hx, 15, outline)


static func _arm(ids: PackedByteArray, shoulder: Vector2, hand: Vector2) -> void:
	var toward := (hand - shoulder).normalized()
	var cuff := hand - toward * 2.2
	_segment(ids, shoulder, cuff, 1.7, COAT)
	_segment(ids, cuff, hand - toward * 1.0, 1.8, CUFF)
	_ellipse(ids, hand, Vector2(1.6, 1.6), SKIN)


## Hair shadow on the brow, coat shadow on the shorts, tufts in the hair and
## folds in the coat; the baker adds the lit rim and the outline.
static func _shade(ids: PackedByteArray) -> Image:
	var image := Image.create_empty(SIZE.x, SIZE.y, false, Image.FORMAT_RGBA8)
	for y in SIZE.y:
		for x in SIZE.x:
			var part := _id(ids, x, y)
			if part == EMPTY:
				continue
			var above := _id(ids, x, y - 1)
			var tone := 2
			if (part == SKIN and above == HAIR) or (part == SHORTS and above == COAT) or (part == SKIN and above == SHORTS):
				tone = 1
			if part == HAIR:
				tone = _hair_tone(x, y)
			if part == COAT and tone == 2 and (x == 15 or x == 25) and y > 26:
				tone = 1
			image.set_pixel(x, y, _ramps[part][tone])
	return image


## Spiky hair: a lit crown on the upper left with a jagged lower edge, shade
## gathering underneath, and strands that run down and out.
static func _hair_tone(x: int, y: int) -> int:
	var across := (x - 20.0) / 9.6
	var down := (y - 10.0) / 8.0
	if down > 0.55 or (down > 0.0 and posmod(x * 2 + y, 5) == 0):
		return 1
	if down < -0.2 + 0.25 * posmod(x, 3) / 2.0 and across < 0.35:
		return 3
	return 2


static func _details(image: Image, ids: PackedByteArray, front: bool, mood: String, hx: int) -> void:
	for y in range(22, 32, 2):
		for x in range(18, 23):
			if _id(ids, x, y) == SHIRT:
				image.set_pixel(x, y, STRIPE)
	if not front:
		var bag: Array = _ramps[BAG]
		for x in range(15, 26):
			if _id(ids, x, 26) == BAG:
				image.set_pixel(x, 26, (bag[1] as Color).darkened(0.3))
			for y in range(24, 26):
				if _id(ids, x, y) == BAG:
					image.set_pixel(x, y, bag[3])
		for x: int in [17, 23]:
			image.set_pixel(x, 27, BUCKLE)
		return
	for x in range(17, 24):
		if _id(ids, x, 27) == CAMERA:
			image.set_pixel(x, 27, _ramps[CAMERA][3])
	for at: Vector2i in [Vector2i(19, 28), Vector2i(20, 28), Vector2i(21, 28), Vector2i(19, 29), Vector2i(21, 29), Vector2i(19, 30), Vector2i(20, 30), Vector2i(21, 30)]:
		if _id(ids, at.x, at.y) == CAMERA:
			image.set_pixel(at.x, at.y, INK)
	image.set_pixel(20, 29, Color("#5a7cb0"))
	for x in range(hx - 6, hx + 7):
		if _id(ids, x, 20) == SKIN:
			image.set_pixel(x, 20, _ramps[SKIN][1])
	var left := hx - 4
	var right := hx + 3
	match mood:
		"shocked":
			for eye: int in [left, right]:
				_rect(image, eye - 1, 13, 3, 3, Color("#fffaf0"))
				image.set_pixel(eye, 14, INK)
			_rect(image, hx - 1, 17, 2, 2, INK)
			_rect(image, hx + 7, 9, 1, 2, SWEAT)
		"sorry", "soaked":
			for eye: int in [left, right]:
				_rect(image, eye, 15, 2, 1, INK)
			image.set_pixel(hx - 1, 18, INK)
			image.set_pixel(hx, 17, INK)
			image.set_pixel(hx + 1, 18, INK)
			_rect(image, hx + 7, 9, 1, 2, SWEAT)
			_rect(image, hx + 8, 10, 1, 2, SWEAT)
			if mood == "soaked":
				# Water beads on the flat hair and drips off the fringe.
				for at: Vector2i in [Vector2i(-6, 8), Vector2i(-1, 7), Vector2i(4, 8), Vector2i(-4, 12), Vector2i(2, 12)]:
					_rect(image, hx + at.x, at.y, 1, 2, SWEAT)
		"stinky":
			for eye: int in [left, right]:
				_rect(image, eye - 1, 14, 3, 1, INK)
				image.set_pixel(eye - 1 if eye == left else eye + 1, 13, INK)
				_rect(image, eye if eye == left else eye + 1, 15, 1, 3, SWEAT)
			_rect(image, hx + 7, 9, 1, 2, SWEAT)
		"tongue":
			_rect(image, left, 15, 2, 1, INK)
			_eye(image, right)
			_rect(image, hx - 2, 17, 4, 1, INK)
			_rect(image, hx - 1, 18, 2, 2, TONGUE)
		_:
			_eye(image, left)
			_eye(image, right)
			image.set_pixel(hx - 1, 17, INK)
			image.set_pixel(hx, 18, INK)
			image.set_pixel(hx + 1, 17, INK)
	if mood != "shocked":
		_rect(image, hx - 6, 17, 2, 1, BLUSH)
		_rect(image, hx + 5, 17, 2, 1, BLUSH)


static func _eye(image: Image, x: int) -> void:
	_rect(image, x, 13, 2, 3, INK)
	image.set_pixel(x, 13, Color("#fffaf0"))


static func _rect(image: Image, x: int, y: int, w: int, h: int, color: Color) -> void:
	image.fill_rect(Rect2i(x, y, w, h), color)


static func _id(ids: PackedByteArray, x: int, y: int) -> int:
	if x < 0 or y < 0 or x >= SIZE.x or y >= SIZE.y:
		return EMPTY
	return ids[y * SIZE.x + x]


static func _put(ids: PackedByteArray, x: int, y: int, part: int) -> void:
	if x >= 0 and y >= 0 and x < SIZE.x and y < SIZE.y:
		ids[y * SIZE.x + x] = part


static func _fill(ids: PackedByteArray, x0: int, y0: int, x1: int, y1: int, part: int) -> void:
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			_put(ids, x, y, part)


static func _ellipse(ids: PackedByteArray, centre: Vector2, radii: Vector2, part: int) -> void:
	for y in range(floori(centre.y - radii.y), ceili(centre.y + radii.y) + 1):
		for x in range(floori(centre.x - radii.x), ceili(centre.x + radii.x) + 1):
			var d := Vector2((x + 0.5 - centre.x) / radii.x, (y + 0.5 - centre.y) / radii.y)
			if d.length_squared() <= 1.0:
				_put(ids, x, y, part)


static func _segment(ids: PackedByteArray, from: Vector2, to: Vector2, radius: float, part: int) -> void:
	var box := Rect2(from, Vector2.ZERO).expand(to).grow(radius + 1.0)
	for y in range(floori(box.position.y), ceili(box.end.y)):
		for x in range(floori(box.position.x), ceili(box.end.x)):
			var point := Vector2(x + 0.5, y + 0.5)
			if point.distance_to(Geometry2D.get_closest_point_to_segment(point, from, to)) <= radius:
				_put(ids, x, y, part)
