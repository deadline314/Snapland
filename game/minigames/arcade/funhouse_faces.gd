extends RefCounted
## Pixel faces for the funhouse photo booth, painted in code into one atlas.
##
## A face is a static head plus three horizontal bands: hair, eyes and mouth.
## Each band has six parts with distinct silhouettes and colours. Ids 6..11 are
## decoys: the same shape as id - 6 in a clearly wrong colour.

const OPTIONS := 6
const TILE_WIDTH := 32
const FACE_SIZE := Vector2i(32, 36)
## Per band: first face row it covers, and its height in art pixels.
const BAND_ROWS: Array[Vector2i] = [Vector2i(0, 16), Vector2i(15, 8), Vector2i(23, 9)]
const OUTLINE := Color("#2b1d2e")
const SKIN := Color("#ffcf9e")
const SKIN_SHADE := Color("#e9a877")
const DARK := Color("#2b2440")
const WHITE := Color("#fffaf0")
const PARTS: Array = [
	[
		{"name": "妹妹頭", "color": Color("#2b2440"), "decoy": Color("#7ad1ff")},
		{"name": "爆炸頭", "color": Color("#e0483e"), "decoy": Color("#8d5bd6")},
		{"name": "雙丸子", "color": Color("#f2c23a"), "decoy": Color("#ff8fb8")},
		{"name": "龐克頭", "color": Color("#3aa0f2"), "decoy": Color("#9be04a")},
		{"name": "捲捲毛", "color": Color("#4fc46a"), "decoy": Color("#f29a3a")},
		{"name": "高禮帽", "color": Color("#6a4bc4"), "decoy": Color("#2fb8a6")},
	],
	[
		{"name": "大圓眼", "color": Color("#2b2440"), "decoy": Color("#e0483e")},
		{"name": "瞇瞇眼", "color": Color("#2b2440"), "decoy": Color("#ff5fa2")},
		{"name": "墨鏡", "color": Color("#2b2440"), "decoy": Color("#e0483e")},
		{"name": "星星眼", "color": Color("#ffd23a"), "decoy": Color("#4ad6f2")},
		{"name": "圓眼鏡", "color": Color("#2fb8a6"), "decoy": Color("#f2793a")},
		{"name": "愛心眼", "color": Color("#ff5fa2"), "decoy": Color("#58c45a")},
	],
	[
		{"name": "大笑", "color": Color("#c2303a"), "decoy": Color("#3a6ff2")},
		{"name": "吐舌", "color": Color("#ff7fa8"), "decoy": Color("#6fd45a")},
		{"name": "翹鬍子", "color": Color("#7a4a2a"), "decoy": Color("#4a7af2")},
		{"name": "親親", "color": Color("#e0304a"), "decoy": Color("#9a4be0")},
		{"name": "鯊魚牙", "color": Color("#fffaf0"), "decoy": Color("#ffd23a")},
		{"name": "奶嘴", "color": Color("#4ab0f2"), "decoy": Color("#ff6fa8")},
	],
]

static var _atlas: ImageTexture


static func part_name(reel: int, id: int) -> String:
	var label: String = PARTS[reel][id % OPTIONS].name
	return label + "（變色）" if id >= OPTIONS else label


static func atlas() -> Texture2D:
	if _atlas == null:
		_atlas = ImageTexture.create_from_image(_paint_atlas())
	return _atlas


## Atlas region of one part (ids 0..11) of one band.
static func region(reel: int, id: int) -> Rect2:
	var top := 0
	for earlier in reel:
		top += BAND_ROWS[earlier].y
	return Rect2(id * TILE_WIDTH, top, TILE_WIDTH, BAND_ROWS[reel].y)


static func head_region() -> Rect2:
	return Rect2(0, _head_top(), FACE_SIZE.x, FACE_SIZE.y)


## Draw a whole face whose top-left art pixel sits at `origin`.
static func draw_face(canvas: CanvasItem, origin: Vector2, unit: float, parts: Array, tint := Color.WHITE) -> void:
	var sheet := atlas()
	canvas.draw_texture_rect_region(sheet, Rect2(origin, Vector2(FACE_SIZE) * unit), head_region(), tint)
	for reel in parts.size():
		var id := int(parts[reel])
		if id < 0:
			continue
		var rows := BAND_ROWS[reel]
		canvas.draw_texture_rect_region(sheet, Rect2(origin + Vector2(0, rows.x) * unit, Vector2(TILE_WIDTH, rows.y) * unit), region(reel, id), tint)


static func _head_top() -> int:
	var top := 1
	for rows in BAND_ROWS:
		top += rows.y
	return top


static func _paint_atlas() -> Image:
	var sheet := Image.create_empty(TILE_WIDTH * OPTIONS * 2, _head_top() + FACE_SIZE.y, false, Image.FORMAT_RGBA8)
	for reel in BAND_ROWS.size():
		for id in OPTIONS * 2:
			var tile := Image.create_empty(TILE_WIDTH, BAND_ROWS[reel].y, false, Image.FORMAT_RGBA8)
			var spec: Dictionary = PARTS[reel][id % OPTIONS]
			var color: Color = spec.decoy if id >= OPTIONS else spec.color
			match reel:
				0: _paint_hair(tile, id % OPTIONS, color)
				1: _paint_eyes(tile, id % OPTIONS, color)
				2: _paint_mouth(tile, id % OPTIONS, color)
			_outline(tile)
			sheet.blit_rect(tile, Rect2i(Vector2i.ZERO, tile.get_size()), Vector2i(region(reel, id).position))
	var head := Image.create_empty(FACE_SIZE.x, FACE_SIZE.y, false, Image.FORMAT_RGBA8)
	_paint_head(head)
	_outline(head)
	sheet.blit_rect(head, Rect2i(Vector2i.ZERO, FACE_SIZE), Vector2i(0, _head_top()))
	return sheet


static func _paint_head(image: Image) -> void:
	_rect(image, 13, 30, 6, 4, SKIN_SHADE)
	_disc(image, 16.0, 39.0, 13.0, 6.5, Color("#3fb8a8"))
	_rect(image, 14, 33, 4, 1, WHITE)
	for x in [8, 12, 19, 23]:
		_rect(image, x, 34, 1, 2, Color("#2f8f86"))
	_disc(image, 5.5, 20.5, 2.0, 2.5, SKIN_SHADE)
	_disc(image, 26.5, 20.5, 2.0, 2.5, SKIN_SHADE)
	_disc(image, 16.0, 20.0, 10.0, 12.0, SKIN)
	_disc(image, 16.0, 26.0, 7.0, 5.5, SKIN.lightened(0.08))
	_rect(image, 15, 22, 2, 2, SKIN_SHADE)
	for x in [8, 22]:
		_rect(image, x, 25, 2, 1, Color("#ff9d9d"))


static func _paint_hair(image: Image, kind: int, color: Color) -> void:
	var shade := color.darkened(0.28)
	var light := color.lightened(0.3)
	match kind:
		0:
			_disc(image, 16.0, 12.0, 12.0, 8.0, color)
			_rect(image, 4, 11, 4, 5, color)
			_rect(image, 24, 11, 4, 5, color)
			_rect(image, 8, 13, 16, 3, Color(0, 0, 0, 0))
			_rect(image, 8, 12, 16, 1, shade)
			_rect(image, 10, 6, 6, 1, light)
		1:
			_disc(image, 16.0, 8.0, 14.5, 8.0, color)
			for bump in [[5, 4], [12, 2], [20, 2], [27, 4], [9, 9], [23, 9]]:
				_rect(image, bump[0] - 1, bump[1], 2, 1, light)
				_rect(image, bump[0], bump[1] + 3, 2, 1, shade)
			_rect(image, 9, 14, 14, 2, Color(0, 0, 0, 0))
		2:
			_disc(image, 4.5, 6.0, 4.0, 4.0, color)
			_disc(image, 27.5, 6.0, 4.0, 4.0, color)
			_disc(image, 16.0, 11.0, 11.0, 4.5, color)
			_rect(image, 3, 4, 2, 1, light)
			_rect(image, 26, 4, 2, 1, light)
			_rect(image, 15, 7, 2, 6, shade)
			_rect(image, 7, 9, 2, 2, Color("#e0483e"))
			_rect(image, 23, 9, 2, 2, Color("#e0483e"))
		3:
			for spike in 5:
				var x := 10 + spike * 3
				var height := 12 - absi(spike - 2) * 2
				for row in height:
					var half := 1 if row * 3 < height * 2 else 0
					_rect(image, x - half, 11 - row, 2 + half * 2, 1, light if row * 2 > height and spike % 2 == 0 else color)
			_rect(image, 8, 12, 16, 2, shade)
		4:
			for curl in [[8, 9], [13, 7], [19, 7], [24, 9], [10, 5], [16, 4], [22, 5]]:
				_disc(image, float(curl[0]), float(curl[1]), 3.4, 3.4, color)
				_rect(image, curl[0] - 1, curl[1] - 2, 2, 1, light)
				_rect(image, curl[0], curl[1] + 1, 2, 1, shade)
		5:
			_rect(image, 10, 0, 12, 10, color)
			_rect(image, 10, 0, 2, 10, light)
			_rect(image, 20, 0, 2, 10, shade)
			_rect(image, 10, 7, 12, 2, Color("#ffd23a"))
			_rect(image, 5, 10, 22, 2, color)
			_rect(image, 5, 11, 22, 1, shade)


static func _paint_eyes(image: Image, kind: int, color: Color) -> void:
	for center: float in [11.0, 21.0]:
		var x := int(center)
		match kind:
			0:
				_disc(image, center, 4.0, 3.4, 3.4, WHITE)
				_rect(image, x - 1, 3, 3, 3, color)
				_rect(image, x - 1, 3, 1, 1, WHITE)
			1:
				for step in 5:
					_rect(image, x - 2 + step, 4 - (2 - absi(step - 2)), 1, 2, color)
			2:
				_rect(image, x - 4, 1, 8, 5, color)
				_rect(image, x - 3, 6, 6, 1, color)
				_rect(image, x - 3, 2, 2, 1, color.lightened(0.55))
			3:
				_rect(image, x - 1, 1, 2, 6, color)
				_rect(image, x - 3, 3, 6, 2, color)
				_rect(image, x - 2, 2, 4, 4, color)
				_rect(image, x - 1, 3, 2, 2, WHITE)
			4:
				_disc(image, center, 4.0, 3.9, 3.9, color)
				_disc(image, center, 4.0, 2.6, 2.6, WHITE)
				_rect(image, x, 4, 1, 1, DARK)
			5:
				_rect(image, x - 3, 2, 3, 3, color)
				_rect(image, x, 2, 3, 3, color)
				_rect(image, x - 2, 5, 4, 1, color)
				_rect(image, x - 1, 6, 2, 1, color)
				_rect(image, x - 2, 2, 1, 1, WHITE)
	if kind == 2:
		_rect(image, 15, 2, 2, 1, color)
	if kind == 4:
		_rect(image, 15, 3, 2, 1, color)


static func _paint_mouth(image: Image, kind: int, color: Color) -> void:
	match kind:
		0:
			_disc(image, 16.0, 2.0, 6.0, 5.5, color)
			_rect(image, 9, 0, 14, 2, Color(0, 0, 0, 0))
			_rect(image, 11, 2, 10, 2, WHITE)
			_rect(image, 14, 6, 4, 1, color.lightened(0.35))
		1:
			_rect(image, 10, 2, 12, 1, DARK)
			_rect(image, 9, 1, 1, 1, DARK)
			_rect(image, 22, 1, 1, 1, DARK)
			_rect(image, 14, 3, 5, 4, color)
			_rect(image, 15, 7, 3, 1, color)
			_rect(image, 16, 3, 1, 3, color.darkened(0.25))
		2:
			_disc(image, 11.5, 3.5, 4.5, 2.6, color)
			_disc(image, 20.5, 3.5, 4.5, 2.6, color)
			_rect(image, 5, 1, 2, 2, color)
			_rect(image, 25, 1, 2, 2, color)
			_rect(image, 9, 2, 3, 1, color.lightened(0.3))
			_rect(image, 19, 2, 3, 1, color.lightened(0.3))
		3:
			_disc(image, 16.0, 4.0, 3.2, 3.2, color)
			_rect(image, 15, 3, 2, 2, DARK)
			_rect(image, 14, 2, 1, 1, color.lightened(0.45))
		4:
			_rect(image, 8, 1, 16, 6, DARK)
			for tooth in 5:
				var x := 9 + tooth * 3
				_rect(image, x, 1, 2, 2, color)
				_rect(image, x, 3, 1, 1, color)
				_rect(image, x + 1, 5, 2, 2, color)
				_rect(image, x + 2, 4, 1, 1, color)
		5:
			_disc(image, 16.0, 6.0, 3.0, 2.6, Color("#ffd23a"))
			_rect(image, 15, 5, 2, 2, Color(0, 0, 0, 0))
			_rect(image, 10, 1, 12, 4, color)
			_rect(image, 9, 2, 14, 2, color)
			_rect(image, 11, 2, 3, 1, color.lightened(0.4))


static func _rect(image: Image, x: int, y: int, width: int, height: int, color: Color) -> void:
	image.fill_rect(Rect2i(x, y, width, height).intersection(Rect2i(Vector2i.ZERO, image.get_size())), color)


static func _disc(image: Image, cx: float, cy: float, rx: float, ry: float, color: Color) -> void:
	var size := image.get_size()
	for y in range(maxi(0, floori(cy - ry)), mini(size.y, ceili(cy + ry))):
		for x in range(maxi(0, floori(cx - rx)), mini(size.x, ceili(cx + rx))):
			var offset := Vector2((x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry)
			if offset.length_squared() <= 1.0:
				image.set_pixel(x, y, color)


## Ring every painted shape with one dark pixel so parts read on any backdrop.
static func _outline(image: Image) -> void:
	var size := image.get_size()
	var edge: Array[Vector2i] = []
	for y in size.y:
		for x in size.x:
			if image.get_pixel(x, y).a > 0.0:
				continue
			for step in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var near: Vector2i = Vector2i(x, y) + step
				if near.x >= 0 and near.y >= 0 and near.x < size.x and near.y < size.y and image.get_pixel(near.x, near.y).a > 0.0:
					edge.append(Vector2i(x, y))
					break
	for point in edge:
		image.set_pixel(point.x, point.y, OUTLINE)
