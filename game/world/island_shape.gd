extends RefCounted
## The Welcome island's outline and everything measured from it.
##
## One authored coastline is smoothed into a closed polygon; a signed-distance
## grid baked from it answers "is this land, how far is the water, which place
## is this". Ground meshes, the bay shader, movement limits, planting and the
## map all read this module, so the shore cannot drift apart between them.
## Coordinates are world x/z in metres (x east, z south). Nothing is random and
## the bake is cached for the life of the process.

## Clockwise from the dock bay: east headland, south-east cape, east bay, east
## cape, lagoon and its sand spit, north cape, north-west cape, west inlet,
## west cape, west bay, south-west cape, west headland.
const COAST_CONTROL := [
	Vector2(0,19), Vector2(11,19.4), Vector2(20,22), Vector2(28,27), Vector2(38,32.5), Vector2(50,36), Vector2(59.5,32), Vector2(65,22.5), Vector2(67,11.5), Vector2(72.5,1.5),
	Vector2(82,-4), Vector2(92,-8), Vector2(98.5,-17.5), Vector2(95,-28.5), Vector2(83.5,-33),
	Vector2(74.5,-36), Vector2(67,-43.5), Vector2(65,-54.5), Vector2(70.5,-64.5),
	Vector2(82,-69.5), Vector2(93,-73), Vector2(100.5,-82.5), Vector2(96.5,-93.5), Vector2(85.5,-97),
	Vector2(76.5,-103), Vector2(67,-108.5), Vector2(63,-119.5), Vector2(70.5,-129), Vector2(82,-129), Vector2(87.5,-121.5), Vector2(92,-117.5), Vector2(96,-125), Vector2(91,-136.5), Vector2(80,-142), Vector2(67,-143.5),
	Vector2(54,-147.5), Vector2(41,-145.5), Vector2(30,-151), Vector2(20.5,-160.5), Vector2(9.5,-166), Vector2(-2,-162.5), Vector2(-7.5,-153), Vector2(-15,-145.5),
	Vector2(-28,-143.5), Vector2(-43,-140), Vector2(-56,-142), Vector2(-69,-136.5), Vector2(-78,-125), Vector2(-80,-112),
	Vector2(-72.5,-103), Vector2(-59.5,-101), Vector2(-50,-93.5), Vector2(-52,-84), Vector2(-63,-80.5), Vector2(-76.5,-80.5),
	Vector2(-89.5,-78.5), Vector2(-100.5,-71), Vector2(-104,-58), Vector2(-96.5,-47), Vector2(-83.5,-43.5),
	Vector2(-74.5,-37.5), Vector2(-70.5,-26.5), Vector2(-76.5,-15.5),
	Vector2(-87.5,-8), Vector2(-96.5,1.5), Vector2(-96.5,14.5), Vector2(-87.5,23.5),
	Vector2(-74.5,29), Vector2(-61.5,27.5), Vector2(-52,33), Vector2(-43,40.5), Vector2(-31.5,40.5), Vector2(-23,33), Vector2(-20,26), Vector2(-11,21),
]
## Sand between the waterline and the grass, everywhere along the coast.
const SAND_WIDTH := 2.6
## Wider beaches: x, z, radius. Grass is cut away inside each circle.
const BEACHES := [
	Vector3(-17,22.5,7.5), Vector3(17,21.5,7.0), Vector3(64,-50,11.0), Vector3(68,-122,7.0), Vector3(-75,-36,7.0),
	Vector3(72,-136,8.0), Vector3(82,-135.5,8.0), Vector3(91,-128,8.5), Vector3(-51,-90,6.0),
]
## How close to the waterline a walker may stand.
const WALK_MARGIN := 1.2
## Middle of the island: where a query heads when it has no better hint.
const CENTER := Vector2(-2, -62)
## Named places for the banner and the map, first match wins: name, x, z, radius.
const AREAS := [
	["風帆工坊", -13, -47, 11], ["風箏草坡", -58, -50, 12], ["湧泉池", -38, -30, 11], ["風向路口", -2, -62, 8],
	["帽子沙灘", 62, -50, 13], ["彩帶涼亭", 40, -28, 9], ["花壇園圃", 34, -96, 9], ["潮池廣場", 38, -57, 9],
	["林蔭空地", 30, -112, 9], ["海風觀景台", 54, -121, 9], ["長椅池畔", -27, -95, 11], ["月影劇台", 2, -117, 12],
	["潟湖沙洲", 80, -135, 16],
	["西南岬", -86, 8, 11], ["東岬", 88, -81, 11], ["西北岬", -69, -122, 11], ["東北岸", 52, -139, 8], ["北岬", 10, -156, 11],
	["東南岬", 88, -17, 11], ["西堤", -38, 33, 11], ["東堤", 50, 29, 11], ["燈塔岬", -96, -62, 12],
]
const DOCK_AREA := "海風碼頭"
const PLAZA_AREA := "中央廣場"
const COAST_AREA := "海岸環線"
const INLAND_AREA := "迎賓大道"
## Within this distance of the water an unnamed spot belongs to the coastal loop.
const COAST_AREA_WIDTH := 20.0

const POLYGON_STEP := 2.0
const CELL := 2.0
const GRID_PADDING := 16.0
## Cells nearer the coast than this hold exact distances; farther ones are interpolated.
const EXACT_BAND := 6.0
const COARSE_STRIDE := 4

static var _coast := PackedVector2Array()
static var _coast_curve: Curve2D
static var _lawns: Array[PackedVector2Array] = []
static var _grid := PackedFloat32Array()
static var _origin := Vector2.ZERO
static var _columns := 0
static var _rows := 0
static var _texture: ImageTexture

## A smooth curve through `points`, sampled about `interval` metres apart.
static func smooth(points: Array, closed: bool, interval := POLYGON_STEP) -> PackedVector2Array:
	var curve := _curve_through(points, closed, interval)
	var samples := curve.get_baked_points()
	if closed and samples.size() > 1: samples.remove_at(samples.size() - 1)
	return samples

static func _curve_through(points: Array, closed: bool, interval: float) -> Curve2D:
	var curve := Curve2D.new()
	curve.bake_interval = interval
	var count := points.size()
	for index in count + (1 if closed else 0):
		var previous: Vector2 = points[(index - 1 + count) % count] if closed else points[maxi(index - 1, 0)]
		var next: Vector2 = points[(index + 1) % count] if closed else points[mini(index + 1, count - 1)]
		var handle := (next - previous) / 6.0
		curve.add_point(points[index % count], -handle, handle)
	return curve

## The waterline as a closed polygon.
static func coast() -> PackedVector2Array:
	_ensure()
	return _coast

## Grass outlines: the coast drawn back by the sand width, minus the beaches.
static func lawns() -> Array[PackedVector2Array]:
	_ensure()
	return _lawns

static func bounds() -> Rect2:
	_ensure()
	return Rect2(_origin, Vector2(_columns - 1, _rows - 1) * CELL).grow(-GRID_PADDING)

## Metres to the waterline: positive on land, negative over water.
static func distance_to_coast(point: Vector2) -> float:
	_ensure()
	var gx := clampf((point.x - _origin.x) / CELL, 0.0, float(_columns) - 1.001)
	var gz := clampf((point.y - _origin.y) / CELL, 0.0, float(_rows) - 1.001)
	var column := int(gx)
	var row := int(gz)
	var index := row * _columns + column
	var fx := gx - float(column)
	return lerpf(lerpf(_grid[index], _grid[index + 1], fx), lerpf(_grid[index + _columns], _grid[index + _columns + 1], fx), gz - float(row))

static func contains(point: Vector2, margin := 0.0) -> bool:
	return distance_to_coast(point) >= margin

## `point`, or the nearest spot at least `margin` metres inland.
static func clamp_inside(point: Vector2, margin := WALK_MARGIN) -> Vector2:
	_ensure()
	# Beyond the grid every reading is flat, so start from its edge.
	var result := point.clamp(_origin, _origin + Vector2(_columns - 1, _rows - 1) * CELL)
	for attempt in 8:
		var distance := distance_to_coast(result)
		if distance >= margin: return result
		var inland := inland_direction(result)
		result += inland * (margin - distance + 0.02)
	return result

## Unit vector pointing away from the nearest water.
static func inland_direction(point: Vector2) -> Vector2:
	const PROBE := 0.5
	var slope := Vector2(
		distance_to_coast(point + Vector2(PROBE, 0)) - distance_to_coast(point - Vector2(PROBE, 0)),
		distance_to_coast(point + Vector2(0, PROBE)) - distance_to_coast(point - Vector2(0, PROBE)))
	# Flat readings happen only beyond the grid; head for the island.
	return slope.normalized() if slope.length_squared() > 0.0001 else (CENTER - point).normalized()

## Metres inside the grass: positive on lawn, negative on sand or water.
static func lawn_inset(point: Vector2) -> float:
	var inset := distance_to_coast(point) - SAND_WIDTH
	for beach: Vector3 in BEACHES:
		inset = minf(inset, point.distance_to(Vector2(beach.x, beach.y)) - beach.z)
	return inset

static func on_lawn(point: Vector2, margin := 0.0) -> bool:
	return lawn_inset(point) >= margin

static func area_at(point: Vector2) -> String:
	if absf(point.x) <= 16.0 and point.y > 12.0 and point.y < 30.0: return DOCK_AREA
	if absf(point.x) <= 16.0 and absf(point.y) <= 12.0: return PLAZA_AREA
	for area: Array in AREAS:
		if point.distance_squared_to(Vector2(area[1], area[2])) <= float(area[3]) * float(area[3]): return area[0]
	return COAST_AREA if distance_to_coast(point) < COAST_AREA_WIDTH else INLAND_AREA

## Signed distance as a float texture for shaders; sample it with
## uv = (world.xz - sdf_origin()) * sdf_inverse_size().
static func sdf_texture() -> ImageTexture:
	_ensure()
	if _texture == null:
		_texture = ImageTexture.create_from_image(Image.create_from_data(_columns, _rows, false, Image.FORMAT_RF, _grid.to_byte_array()))
	return _texture

static func sdf_origin() -> Vector2:
	_ensure()
	return _origin - Vector2.ONE * CELL * 0.5

static func sdf_inverse_size() -> Vector2:
	_ensure()
	return Vector2(1.0 / (float(_columns) * CELL), 1.0 / (float(_rows) * CELL))

static func _ensure() -> void:
	if _grid.is_empty(): _bake()

static func _bake() -> void:
	_coast_curve = _curve_through(COAST_CONTROL, true, POLYGON_STEP)
	_coast = _coast_curve.get_baked_points()
	_coast.remove_at(_coast.size() - 1)
	# Polygon clipping reads a clockwise outline as a hole.
	if Geometry2D.is_polygon_clockwise(_coast): _coast.reverse()
	_lawns = _lawn_outlines()
	var extent := Rect2(_coast[0], Vector2.ZERO)
	for point in _coast: extent = extent.expand(point)
	extent = extent.grow(GRID_PADDING)
	_origin = extent.position
	var block := float(COARSE_STRIDE) * CELL
	_columns = ceili(extent.size.x / block) * COARSE_STRIDE + 1
	_rows = ceili(extent.size.y / block) * COARSE_STRIDE + 1
	_grid.resize(_columns * _rows)
	var land := _land_mask()
	# Exact distances on a coarse lattice decide which blocks need exact cells.
	var coarse_columns := (_columns - 1) / COARSE_STRIDE + 1
	var coarse_rows := (_rows - 1) / COARSE_STRIDE + 1
	var coarse := PackedFloat32Array()
	coarse.resize(coarse_columns * coarse_rows)
	for row in coarse_rows:
		for column in coarse_columns:
			coarse[row * coarse_columns + column] = _exact_distance(column * COARSE_STRIDE, row * COARSE_STRIDE)
	var far := EXACT_BAND + block * 0.71
	for block_row in coarse_rows:
		for block_column in coarse_columns:
			var corner := block_row * coarse_columns + block_column
			var right := corner + (1 if block_column + 1 < coarse_columns else 0)
			var below := corner + (coarse_columns if block_row + 1 < coarse_rows else 0)
			var opposite := below + right - corner
			var interpolate := minf(minf(coarse[corner], coarse[right]), minf(coarse[below], coarse[opposite])) > far
			for dz in COARSE_STRIDE:
				var row := block_row * COARSE_STRIDE + dz
				if row >= _rows: break
				for dx in COARSE_STRIDE:
					var column := block_column * COARSE_STRIDE + dx
					if column >= _columns: break
					var distance: float
					if dx == 0 and dz == 0:
						distance = coarse[corner]
					elif interpolate:
						var fx := float(dx) / COARSE_STRIDE
						distance = lerpf(lerpf(coarse[corner], coarse[right], fx), lerpf(coarse[below], coarse[opposite], fx), float(dz) / COARSE_STRIDE)
					else:
						distance = _exact_distance(column, row)
					var index := row * _columns + column
					_grid[index] = distance if land[index] == 1 else -distance

static func _exact_distance(column: int, row: int) -> float:
	var point := _origin + Vector2(column, row) * CELL
	return _coast_curve.get_closest_point(point).distance_to(point)

## One byte per grid cell: 1 on land. Each row is clipped against the coast once.
static func _land_mask() -> PackedByteArray:
	var land := PackedByteArray()
	land.resize(_columns * _rows)
	var right := _origin.x + float(_columns - 1) * CELL
	for row in _rows:
		# A hair off the lattice so no scan line runs exactly through a vertex.
		var z := _origin.y + float(row) * CELL + 0.0007
		for span: PackedVector2Array in Geometry2D.intersect_polyline_with_polygon(PackedVector2Array([Vector2(_origin.x, z), Vector2(right, z)]), _coast):
			var from := ceili((minf(span[0].x, span[span.size() - 1].x) - _origin.x) / CELL)
			var to := floori((maxf(span[0].x, span[span.size() - 1].x) - _origin.x) / CELL)
			for column in range(from, to + 1):
				land[row * _columns + column] = 1
	return land

static func _lawn_outlines() -> Array[PackedVector2Array]:
	var pieces: Array[PackedVector2Array] = []
	for outline: PackedVector2Array in Geometry2D.offset_polygon(_coast, -SAND_WIDTH, Geometry2D.JOIN_ROUND):
		if not Geometry2D.is_polygon_clockwise(outline): pieces.append(outline)
	for beach: Vector3 in BEACHES:
		var circle := PackedVector2Array()
		for step in 28:
			circle.append(Vector2(beach.x, beach.y) + Vector2.from_angle(TAU * float(step) / 28.0) * beach.z)
		var cut: Array[PackedVector2Array] = []
		for piece in pieces:
			for outline: PackedVector2Array in Geometry2D.clip_polygons(piece, circle):
				# Clockwise results are holes; beaches sit on the shore, so none are expected.
				if not Geometry2D.is_polygon_clockwise(outline): cut.append(outline)
		pieces = cut
	return pieces
