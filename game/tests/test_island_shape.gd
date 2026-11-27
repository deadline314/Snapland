extends SceneTree
## The Welcome island's outline module: an organic coast, exact-enough queries,
## an idempotent walk limit, a repeatable bake and the layers that hang off it.

const IslandShape = preload("res://game/world/island_shape.gd")

## Walkable area of the former 67.2 x 91.6 m rectangle.
const FORMER_WALK_AREA := 6155.52
const LONGEST_STRAIGHT_SHORE := 28.0
const STRAIGHT_TOLERANCE := deg_to_rad(8.0)

var failures: Array[String] = []

func _initialize() -> void:
	_check_outline()
	_check_queries()
	_check_walk_limit()
	_check_determinism()
	_check_lawn()
	_check_areas_and_texture()
	if failures.is_empty():
		print("PASS: island shape outline, queries, walk limit, bake and layers")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _polygon_area(outline: PackedVector2Array) -> float:
	var area := 0.0
	for index in outline.size():
		area += outline[index].cross(outline[(index + 1) % outline.size()]) * 0.5
	return absf(area)

func _exact(point: Vector2) -> float:
	var coast := IslandShape.coast()
	var nearest := INF
	for index in coast.size():
		nearest = minf(nearest, point.distance_to(Geometry2D.get_closest_point_to_segment(point, coast[index], coast[(index + 1) % coast.size()])))
	return nearest if Geometry2D.is_point_in_polygon(point, coast) else -nearest

func _check_outline() -> void:
	var coast := IslandShape.coast()
	_check(coast.size() >= 300, "the coast is a finely sampled curve (%d points)" % coast.size())
	var extent := Rect2(coast[0], Vector2.ZERO)
	for point in coast:
		extent = extent.expand(point)
	var area := _polygon_area(coast)
	var fill := area / extent.get_area()
	_check(fill < 0.75 and fill > 0.5, "the island is far from filling its bounding box: capes and bays, not a rectangle (%.2f)" % fill)
	_check(Geometry2D.triangulate_polygon(coast).size() == (coast.size() - 2) * 3, "the coastline never crosses itself")
	# No stretch of shore runs straight: follow the heading until it has turned
	# by the tolerance and measure how far that took.
	var longest := 0.0
	for start in coast.size():
		var heading := (coast[(start + 1) % coast.size()] - coast[start]).angle()
		var run := 0.0
		for step in range(1, coast.size()):
			var from := coast[(start + step - 1) % coast.size()]
			var to := coast[(start + step) % coast.size()]
			if absf(angle_difference(heading, (to - from).angle())) > STRAIGHT_TOLERANCE:
				break
			run += from.distance_to(to)
		longest = maxf(longest, run)
	_check(longest <= LONGEST_STRAIGHT_SHORE, "no shore runs straight for more than %.0f m (longest %.1f m)" % [LONGEST_STRAIGHT_SHORE, longest])
	# The counter-example this replaces: a rectangle fills its box and has long straight sides.
	var turns := 0.0
	for index in coast.size():
		var before := (coast[index] - coast[(index - 1 + coast.size()) % coast.size()]).angle()
		var after := (coast[(index + 1) % coast.size()] - coast[index]).angle()
		turns += absf(angle_difference(before, after))
	_check(turns > TAU * 2.5, "the shore winds in and out instead of circling once (%.1f turns)" % (turns / TAU))
	# Walkable ground: everything at least the walk margin inside the waterline.
	var walkable := 0
	var bounds := IslandShape.bounds()
	for x in range(floori(bounds.position.x), ceili(bounds.end.x)):
		for z in range(floori(bounds.position.y), ceili(bounds.end.y)):
			if IslandShape.contains(Vector2(x + 0.5, z + 0.5), IslandShape.WALK_MARGIN):
				walkable += 1
	_check(float(walkable) >= FORMER_WALK_AREA * 4.0, "walkable ground is at least four times the former island (%d m2, %.2fx)" % [walkable, float(walkable) / FORMER_WALK_AREA])
	# Named features of the authored coast.
	_check(not IslandShape.contains(Vector2(0, 24)) and IslandShape.contains(Vector2(-40, 34)) and IslandShape.contains(Vector2(50, 30)), "the dock sits in a bay between two headlands")
	# Since MAIN-56 the spit's north end runs on into the circus headland (the circus
	# approach crosses it), so the open water beside the spit lies to its east.
	_check(not IslandShape.contains(Vector2(78, -121)) and IslandShape.contains(Vector2(80, -136)) and not IslandShape.contains(Vector2(100, -136)), "a sand spit encloses the north-east lagoon")
	_check(not IslandShape.contains(Vector2(-66, -93)) and IslandShape.contains(Vector2(-66, -74)) and IslandShape.contains(Vector2(-66, -112)), "an inlet cuts into the west coast")

func _check_queries() -> void:
	var coast := IslandShape.coast()
	var random := RandomNumberGenerator.new()
	random.seed = 20261127
	var bounds := IslandShape.bounds().grow(12.0)
	var worst_near := 0.0
	var worst_far := 0.0
	var wrong_side := 0
	for sample in 1500:
		var point := bounds.position + Vector2(random.randf(), random.randf()) * bounds.size
		var exact := _exact(point)
		var measured := IslandShape.distance_to_coast(point)
		if absf(exact) <= 2.0:
			worst_near = maxf(worst_near, absf(exact - measured))
		elif absf(exact) <= IslandShape.EXACT_BAND:
			worst_far = maxf(worst_far, absf(exact - measured))
		if absf(exact) > 0.3 and IslandShape.contains(point) != Geometry2D.is_point_in_polygon(point, coast):
			wrong_side += 1
	_check(worst_near <= 0.25, "distance agrees with the polygon to a quarter metre beside the water (worst %.2f m)" % worst_near)
	# Narrow spits and inlets have a ridge in the distance field that a 2 m grid rounds off.
	_check(worst_far <= 1.0, "distance stays close to the polygon across the shore band (worst %.2f m)" % worst_far)
	_check(wrong_side == 0, "land and water agree with the polygon away from the waterline (%d disagreements)" % wrong_side)
	_check(IslandShape.distance_to_coast(Vector2(900, 900)) < 0.0 and IslandShape.distance_to_coast(IslandShape.CENTER) > 20.0, "far water is water and the middle of the island is deep inland")

func _check_walk_limit() -> void:
	var random := RandomNumberGenerator.new()
	random.seed = 55
	var bounds := IslandShape.bounds().grow(10.0)
	var shallow := 0
	var drifting := 0
	var disturbed := 0
	var farthest := 0.0
	for sample in 600:
		var point := bounds.position + Vector2(random.randf(), random.randf()) * bounds.size
		var kept := IslandShape.clamp_inside(point)
		if IslandShape.distance_to_coast(kept) < IslandShape.WALK_MARGIN - 0.03: shallow += 1
		if IslandShape.clamp_inside(kept).distance_to(kept) > 0.001: drifting += 1
		if IslandShape.contains(point, IslandShape.WALK_MARGIN):
			if kept != point: disturbed += 1
		elif IslandShape.distance_to_coast(point) > -6.0:
			farthest = maxf(farthest, kept.distance_to(point) - (IslandShape.WALK_MARGIN - IslandShape.distance_to_coast(point)))
	_check(shallow == 0, "every limited position stands the walk margin inside the waterline (%d too shallow)" % shallow)
	_check(drifting == 0, "limiting a limited position changes nothing (%d moved again)" % drifting)
	_check(disturbed == 0, "positions already on walkable ground are left alone (%d moved)" % disturbed)
	_check(farthest <= 0.6, "a step into the water comes back by the shortest way, not a jump (%.2f m extra)" % farthest)
	_check(IslandShape.contains(IslandShape.clamp_inside(Vector2(600, -700)), IslandShape.WALK_MARGIN - 0.03), "a position far out at sea is still brought ashore")
	_check(IslandShape.clamp_inside(Vector2(0, 30), 3.0).distance_to(IslandShape.clamp_inside(Vector2(0, 30), 0.5)) > 2.0, "a larger margin keeps the walker farther inland")

func _check_determinism() -> void:
	var coast := IslandShape.coast().duplicate()
	var grid: PackedFloat32Array = IslandShape._grid.duplicate()
	var lawn_points := 0
	for outline in IslandShape.lawns():
		lawn_points += outline.size()
	IslandShape._bake()
	var rebuilt_points := 0
	for outline in IslandShape.lawns():
		rebuilt_points += outline.size()
	_check(IslandShape.coast() == coast and IslandShape._grid == grid and rebuilt_points == lawn_points, "baking the island again gives the identical coast, distance grid and lawn")
	_check(IslandShape.smooth(IslandShape.COAST_CONTROL, true) == IslandShape.smooth(IslandShape.COAST_CONTROL, true), "smoothing is repeatable")
	for control: Vector2 in IslandShape.COAST_CONTROL:
		_check(absf(IslandShape.distance_to_coast(control)) <= 0.25, "the coast passes through its authored point %s" % control)

func _check_lawn() -> void:
	var lawns := IslandShape.lawns()
	_check(lawns.size() >= 1, "the island has a lawn")
	var grass := 0.0
	var narrowest := INF
	var loosest := 0.0
	for outline in lawns:
		grass += _polygon_area(outline)
		_check(Geometry2D.triangulate_polygon(outline).size() > 0, "each lawn outline is a simple polygon that can be drawn")
		for point in outline:
			narrowest = minf(narrowest, IslandShape.distance_to_coast(point))
			loosest = maxf(loosest, absf(IslandShape.lawn_inset(point)))
	_check(narrowest >= IslandShape.SAND_WIDTH - 0.25 and narrowest >= 0.3, "sand separates grass from water along the whole coast (narrowest %.2f m)" % narrowest)
	_check(loosest <= 0.3, "the drawn lawn edge and the lawn query agree (%.2f m apart at worst)" % loosest)
	var land := _polygon_area(IslandShape.coast())
	_check(grass > land * 0.8 and grass < land * 0.95, "the lawn fills the island without reaching the shore (%.0f of %.0f m2)" % [grass, land])
	for beach: Vector3 in IslandShape.BEACHES:
		var centre := Vector2(beach.x, beach.y)
		_check(not IslandShape.on_lawn(centre) and absf(IslandShape.distance_to_coast(centre)) < beach.z, "the beach at %s lies on the shore and has no grass" % centre)
	_check(IslandShape.on_lawn(Vector2(20, -10)) and not IslandShape.on_lawn(Vector2(0, 18.2)) and not IslandShape.on_lawn(Vector2(62, -50)) and not IslandShape.on_lawn(Vector2(0, 24)), "lawn membership separates the park interior from sand and water")
	_check(IslandShape.on_lawn(Vector2(20, -10), 5.0) and not IslandShape.on_lawn(Vector2(-12, 16.6), 1.2), "a planting margin keeps clear of the lawn's edge")

func _check_areas_and_texture() -> void:
	_check(IslandShape.area_at(Vector2(0, 22)) == IslandShape.DOCK_AREA and IslandShape.area_at(Vector2(3, -2)) == IslandShape.PLAZA_AREA, "the dock and the plaza keep their names")
	_check(IslandShape.area_at(Vector2(0, -30)) == IslandShape.INLAND_AREA and IslandShape.area_at(Vector2(-40, -135)) == IslandShape.COAST_AREA, "open ground is the promenade inland and the coastal loop by the sea")
	var names := {}
	for area: Array in IslandShape.AREAS:
		var centre := Vector2(area[1], area[2])
		names[area[0]] = true
		_check(IslandShape.area_at(centre) == area[0] and IslandShape.contains(centre), "%s is a named place on the island" % area[0])
	_check(names.size() == IslandShape.AREAS.size() and names.size() >= 10, "the island has many distinct little places (%d)" % names.size())
	var texture := IslandShape.sdf_texture()
	_check(texture != null and texture.get_image().get_format() == Image.FORMAT_RF and texture.get_width() <= 256 and texture.get_height() <= 256, "shaders get a small float distance texture")
	if texture == null: return
	var image := texture.get_image()
	for point: Vector2 in [Vector2(0, 0), Vector2(0, 30), Vector2(-99, -60), Vector2(80, -121)]:
		var uv := (point - IslandShape.sdf_origin()) * IslandShape.sdf_inverse_size()
		var texel := Vector2i((uv * Vector2(image.get_size())).floor())
		_check(uv.x > 0.0 and uv.x < 1.0 and uv.y > 0.0 and uv.y < 1.0 and absf(image.get_pixelv(texel).r - IslandShape.distance_to_coast(point)) < IslandShape.CELL, "the texture mapping lands on the same distance as the query at %s" % point)
