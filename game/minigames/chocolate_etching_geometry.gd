extends RefCounted

const BOARD := Rect2(60, 70, 590, 330)
const EPS := 0.0001
const MAX_POINTS := 512

static func finite_point(p: Vector2) -> bool:
	return is_finite(p.x) and is_finite(p.y)

static func in_board(p: Vector2) -> bool:
	return finite_point(p) and p.x >= 60 and p.x <= 650 and p.y >= 70 and p.y <= 400

static func area(poly: PackedVector2Array) -> float:
	var total := 0.0
	for i in range(1, poly.size() - 1):
		var ax: float = float(poly[i].x) - float(poly[0].x)
		var ay: float = float(poly[i].y) - float(poly[0].y)
		var bx: float = float(poly[i + 1].x) - float(poly[0].x)
		var by: float = float(poly[i + 1].y) - float(poly[0].y)
		total += ax * by - ay * bx
	return absf(total) * 0.5

static func material_length(line: PackedVector2Array, removed: Array) -> float:
	var total := 0.0
	for i in range(line.size() - 1):
		var a := line[i]
		var b := line[i + 1]
		var edge := b - a
		var fractions: Array[float] = [0.0, 1.0]
		for poly in removed:
			for j in poly.size():
				var fraction := _segment_fraction(a, b, poly[j], poly[(j + 1) % poly.size()])
				if fraction >= 0.0:
					fractions.append(fraction)
		fractions.sort()
		for j in range(fractions.size() - 1):
			var midpoint := a.lerp(b, (fractions[j] + fractions[j + 1]) * 0.5)
			var remains := true
			for poly in removed:
				if Geometry2D.is_point_in_polygon(midpoint, poly):
					remains = false
					break
			if remains:
				total += edge.length() * (fractions[j + 1] - fractions[j])
	return total

static func simple(poly: PackedVector2Array) -> bool:
	if poly.size() < 3 or poly.size() > MAX_POINTS:
		return false
	for i in poly.size():
		if not in_board(poly[i]) or poly[i].distance_to(poly[(i + 1) % poly.size()]) < EPS:
			return false
		for j in range(i + 1, poly.size()):
			if j == i + 1 or (i == 0 and j == poly.size() - 1):
				continue
			if segment_distance(poly[i], poly[(i + 1) % poly.size()], poly[j], poly[(j + 1) % poly.size()]) < EPS:
				return false
	return area(poly) > 1.0

static func offset(poly: PackedVector2Array, amount: float, center: Vector2) -> PackedVector2Array:
	var results := Geometry2D.offset_polygon(poly, amount, Geometry2D.JOIN_MITER)
	# A split contour or a hole is unusable; never choose an arbitrary fragment.
	if results.size() != 1:
		return PackedVector2Array()
	return _offset_contour(results[0], center)

static func _offset_contour(raw: PackedVector2Array, center: Vector2) -> PackedVector2Array:
	if raw.size() > MAX_POINTS:
		return PackedVector2Array()
	var poly := PackedVector2Array()
	# Generated offsets may repeat a float32 vertex; retain all nonzero edges verbatim.
	for point in raw:
		if poly.is_empty() or poly[-1] != point:
			poly.append(point)
	if poly.size() > 1 and poly[0] == poly[-1]:
		poly.remove_at(poly.size() - 1)
	if poly.size() < 3 or area(poly) <= 1.0 or not Geometry2D.is_point_in_polygon(center, poly):
		return PackedVector2Array()
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		if not in_board(a) or _segment_fraction(a, b, b, poly[(i + 2) % poly.size()]) != 1.0:
			return PackedVector2Array()
		for j in range(i + 2, poly.size()):
			if i == 0 and j == poly.size() - 1:
				continue
			if _segment_fraction(a, b, poly[j], poly[(j + 1) % poly.size()]) >= 0.0:
				return PackedVector2Array()
	return poly

static func template(center: Vector2, teeth: int) -> PackedVector2Array:
	var poly := PackedVector2Array()
	var phase := PI / 2.0 - PI / teeth
	for i in teeth:
		for fraction in [0.0, 0.3, 0.7]:
			var angle: float = phase + TAU * (i + fraction) / teeth
			var radius := 4.0 * teeth + (-10.0 if fraction == 0.0 else 8.0)
			poly.append(center + Vector2.from_angle(angle) * radius)
	return poly

static func point_distance(p: Vector2, line: PackedVector2Array) -> float:
	var result := INF
	for i in range(line.size() - 1):
		result = minf(result, p.distance_to(Geometry2D.get_closest_point_to_segment(p, line[i], line[i + 1])))
	return result

static func segment_distance(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> float:
	if _segment_fraction(a, b, c, d) >= 0.0:
		return 0.0
	return minf(minf(a.distance_to(Geometry2D.get_closest_point_to_segment(a, c, d)), b.distance_to(Geometry2D.get_closest_point_to_segment(b, c, d))), minf(c.distance_to(Geometry2D.get_closest_point_to_segment(c, a, b)), d.distance_to(Geometry2D.get_closest_point_to_segment(d, a, b))))

static func _segment_fraction(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> float:
	if maxf(a.x, b.x) < minf(c.x, d.x) or maxf(c.x, d.x) < minf(a.x, b.x) or maxf(a.y, b.y) < minf(c.y, d.y) or maxf(c.y, d.y) < minf(a.y, b.y):
		return -1.0
	# Scalar double products keep near-collinear captured strokes from false contacts.
	var rx: float = float(b.x) - float(a.x)
	var ry: float = float(b.y) - float(a.y)
	var sx: float = float(d.x) - float(c.x)
	var sy: float = float(d.y) - float(c.y)
	var qx: float = float(c.x) - float(a.x)
	var qy: float = float(c.y) - float(a.y)
	var denominator := rx * sy - ry * sx
	if denominator != 0.0:
		var t := (qx * sy - qy * sx) / denominator
		var u := (qx * ry - qy * rx) / denominator
		return t if t >= 0.0 and t <= 1.0 and u >= 0.0 and u <= 1.0 else -1.0
	if qx * ry - qy * rx != 0.0:
		return -1.0
	var squared := rx * rx + ry * ry
	if squared == 0.0:
		return 0.0 if qx * sy - qy * sx == 0.0 else -1.0
	var start := (qx * rx + qy * ry) / squared
	var end := ((float(d.x) - float(a.x)) * rx + (float(d.y) - float(a.y)) * ry) / squared
	var first := maxf(0.0, minf(start, end))
	return first if first <= minf(1.0, maxf(start, end)) else -1.0

static func kerf_intrudes(line: PackedVector2Array, half_width: float, poly: PackedVector2Array) -> bool:
	if line.is_empty() or poly.is_empty() or not bounds(line).grow(half_width).intersects(bounds(poly), true):
		return false
	for i in range(line.size() - 1):
		if Geometry2D.is_point_in_polygon(line[i], poly) or Geometry2D.is_point_in_polygon((line[i] + line[i + 1]) * 0.5, poly):
			return true
		for j in poly.size():
			if segment_distance(line[i], line[i + 1], poly[j], poly[(j + 1) % poly.size()]) < half_width - 0.002:
				return true
	return false

static func overlaps(a: PackedVector2Array, b: PackedVector2Array) -> bool:
	if a.is_empty() or b.is_empty() or not bounds(a).intersects(bounds(b), true):
		return false
	var total := 0.0
	for poly in Geometry2D.intersect_polygons(a, b):
		total += area(poly)
	return total > EPS

static func bounds(points: PackedVector2Array) -> Rect2:
	var result := Rect2(points[0], Vector2.ZERO)
	for point in points:
		result = result.expand(point)
	return result

static func coverage(poly: PackedVector2Array, strokes: Array) -> Dictionary:
	var lengths := PackedFloat64Array()
	var perimeter := 0.0
	for i in poly.size():
		perimeter += poly[i].distance_to(poly[(i + 1) % poly.size()])
		lengths.append(perimeter)
	var minimum := 1.0
	var half_width := 0.0
	var segment := 0
	for sample in 128:
		var distance := perimeter * sample / 128.0
		while segment < poly.size() - 1 and distance > lengths[segment]:
			segment += 1
		var previous := lengths[segment - 1] if segment > 0 else 0.0
		var p := poly[segment].lerp(poly[(segment + 1) % poly.size()], (distance - previous) / (lengths[segment] - previous))
		var depth := 0.0
		for stroke in strokes:
			if point_distance(p, stroke.points) <= stroke.width * 0.5 + EPS:
				depth += stroke.depth
				half_width = maxf(half_width, stroke.width * 0.5)
		minimum = minf(minimum, minf(1.0, depth))
	return {"depth": minimum, "half_width": half_width}

static func ray_radius(poly: PackedVector2Array, center: Vector2, angle: float) -> float:
	var direction := Vector2.from_angle(angle)
	var hits: Array[float] = []
	for i in poly.size():
		var a := poly[i] - center
		var edge := poly[(i + 1) % poly.size()] - poly[i]
		var denominator := direction.cross(edge)
		if absf(denominator) < 1.0e-8:
			continue
		var radius := a.cross(edge) / denominator
		var fraction := a.cross(direction) / denominator
		if radius > 0 and fraction >= -EPS and fraction <= 1.0 + EPS:
			var duplicate := false
			for old in hits:
				duplicate = duplicate or absf(old - radius) < 0.002
			if not duplicate:
				hits.append(radius)
	return hits[0] if hits.size() == 1 else -1.0

static func measure(poly: PackedVector2Array, center: Vector2, teeth: int, assisted: bool) -> Dictionary:
	var radius := 4.0 * teeth
	var tolerance := 2.0 if assisted else 0.0
	var root_sum := 0.0
	var top_sum := 0.0
	var smallest := INF
	for i in teeth:
		var angle := PI / 2.0 - PI / teeth + TAU * i / teeth
		var root := ray_radius(poly, center, angle)
		if root < radius - 18.0 - tolerance or root > radius - 4.0 + tolerance:
			return {}
		root_sum += root
		smallest = minf(smallest, root)
		var next_root := ray_radius(poly, center, angle + TAU / teeth)
		for fraction in [0.35, 0.5, 0.65]:
			var top := ray_radius(poly, center, angle + TAU * fraction / teeth)
			if top < radius - 2.0 - tolerance or top > radius + 14.0 + tolerance or top - maxf(root, next_root) < 4.0:
				return {}
			if fraction == 0.5:
				top_sum += top
	var strength := smallest - 8.0
	if strength < maxf(6.0, (0.30 if assisted else 0.35) * radius):
		return {}
	var measured := (root_sum + top_sum) / (2.0 * teeth) + 1.0
	return {"pitch_radius": measured, "module": 2.0 * measured / teeth, "strength": strength}
