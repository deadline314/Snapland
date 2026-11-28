extends SceneTree
## The Starlight Cinema standing alone: its four areas and their landmarks,
## floors at several heights joined by slopes with no jump anywhere, a step off
## a sandbar caught and set back, the twelve kept stand sites, every
## interaction point reached on foot, the show (film, beam, searchlights,
## flashes, crane, rewinding flat, doors), lamps within budget and a truthful plan.

const World = preload("res://game/world/cinema_world.gd")
const Scenery = preload("res://game/world/cinema_scenery.gd")
const Life = preload("res://game/world/cinema_life.gd")
const MapPanel = preload("res://game/ui/harbor_map_panel.gd")
const SaveGuard = preload("res://game/core/test_save_guard.gd")
const SceneStandards = preload("res://game/world/scene_standards.gd")
const Registry = preload("res://game/world/field/field_registry.gd")
const LANDMARKS := ["CinemaLagoon", "CinemaSandbar0", "CinemaStructure", "CinemaFloor", "CinemaScreen", "CinemaProjectorBeam",
	"CinemaSearchlight0", "CinemaSearchlight1", "CinemaProjectorReel0", "CinemaProjectorReel1", "CinemaCraneArm", "CinemaRewindFlat",
	"CinemaDoor0", "CinemaDoor1", "CinemaFlashes", "CinemaSplash", "CinemaMarquee", "CinemaPierSign"]
## The follow camera shows this much ground around the player; the water must reach 12 m further.
const VIEW_REACH := 19.2 + 12.0
const MOVE := ["move_left", "move_right", "move_up", "move_down"]
const CELL := 0.25

var _world: World
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if not SaveGuard.validate_save_path(OS.get_environment("SNAPLAND_SAVE_PATH"), OS.get_user_data_dir()).is_empty():
		push_error("Cinema world test requires a private save.")
		quit(1)
		return
	_world = World.new()
	root.add_child(_world)
	await _frames(5)
	_check(_world.coastal_play == null and _world.npc_activity == null, "the cinema does not inherit Welcome activities")
	_check(_world.current_area == "紅毯" and _world.player.is_on_floor(), "spawn lands on the red carpet plaza at the pier's foot")
	_check_landmarks()
	_check_plan()
	_check_sites()
	_check_lamps()
	await _check_life()
	_check_reach()
	await _reach([Vector2(6.0, -9.3)] + _route("plaza", "premiere") + [Vector2(World.CARPET_POINT.x, World.CARPET_POINT.z)], "cinema:carpet", "紅毯", 1.0)
	await _reach(_route("premiere", "plaza") + [Vector2(0.0, -10.2), Vector2(-9.4, -9.6)] + _route("front", "tier1") + _route("tier1", "tier2")
		+ [Vector2(-9.4, -1.8)] + _route("tier2", "booth") + [Vector2(World.PROJECTOR_POINT.x, World.PROJECTOR_POINT.z)], "cinema:projector", "放映館", 1.10)
	await _reach([Vector2(-5.6, 2.4)] + _route("booth", "street") + [Vector2(World.FLATS_POINT.x, World.FLATS_POINT.z)], "cinema:flats", "布景街", World.GROUND_Y)
	await _reach([Vector2(0.0, 10.0), Vector2(3.6, 10.0), Vector2(3.6, 3.4)] + _route("lane", "stage") + [Vector2(World.CRANE_POINT.x, World.CRANE_POINT.z)], "cinema:crane", "攝影台", 1.10)
	# Back over the lighting gantry to the premiere terrace and down the carpet to the pier.
	await _reach([Vector2(16.6, 4.0)] + _route("stage", "premiere") + [Vector2(16.6, -9.6), Vector2(13.4, -9.6)] + _route("premiere", "plaza") + [Vector2(World.ENTRY.x, World.ENTRY.z)],
		"region:welcome", "紅毯", World.GROUND_Y)
	await _check_edges()
	_check_map()
	var audit := SceneStandards.audit(_world, "cinema")
	for rule: String in SceneStandards.RULES:
		_check((audit[rule] as Array).is_empty(), "the cinema meets the scene standard '%s': %s" % [rule, str(audit[rule])])
	_world.free()
	for failure in _failures:
		push_error(failure)
	if _failures.is_empty():
		print("PASS: cinema floors, slopes without jumps, caught steps, kept stand sites, the show and truthful map")
	quit(int(not _failures.is_empty()))


func _check_landmarks() -> void:
	for landmark: String in LANDMARKS:
		_check(_world.get_node_or_null(landmark) != null, "the cinema has its %s" % landmark)
	var lagoon := _world.get_node_or_null("CinemaLagoon") as MeshInstance3D
	_check(lagoon != null and (lagoon.mesh as PlaneMesh).size.x >= World.BOUNDS.size.x + 2.0 * VIEW_REACH
		and (lagoon.mesh as PlaneMesh).size.y >= World.BOUNDS.size.y + 2.0 * VIEW_REACH and lagoon.position.y < World.SAND_Y - 0.3,
		"standing alone, water runs past everything the camera can show, below every sandbar")
	for area: Dictionary in World.AREAS:
		var post := _world.get_node_or_null("CinemaSignpost_" + String(area.id)) as Label3D
		_check(post != null and post.text == area.label, "%s has its signpost" % area.label)
	_check((_world.get_node("CinemaMarquee") as Label3D).text == "星光影城", "the premiere palace's marquee carries the cinema's name")
	var film := (_world.get_node("CinemaScreen") as MeshInstance3D).material_override as ShaderMaterial
	_check(film != null and film.shader.resource_path.ends_with("cinema_film.gdshader"), "the big screen plays the film shader")
	var beam := (_world.get_node("CinemaProjectorBeam") as MeshInstance3D)
	var box := beam.get_aabb()
	_check(box.position.z <= World.SCREEN.z + 0.2 and box.end.z >= Scenery.LENS.z - 0.2, "the projector's beam reaches from the lens to the screen")


## Floors never overlap at different heights, every slope is gentle and meets
## its floors' edges at their own heights, the plan has at least four levels,
## and every area has a rise of its own.
func _check_plan() -> void:
	var levels := {}
	for entry: Dictionary in World.PADS:
		levels[snappedf(entry.y, 0.01)] = true
		_check(World.BOUNDS.grow(-0.8).encloses(entry.rect), "%s stays inside the lot" % entry.id)
		for other: Dictionary in World.PADS:
			if other.id <= entry.id or is_equal_approx(other.y, entry.y): continue
			_check(not (entry.rect as Rect2).grow(-0.05).intersects((other.rect as Rect2).grow(-0.05)), "%s and %s never overlap at different heights" % [entry.id, other.id])
	_check(levels.size() >= 4, "the floors stand at %d different heights" % levels.size())
	for link: Dictionary in World.links():
		var a: Vector2 = link.a
		var b: Vector2 = link.b
		var run := a.distance_to(b)
		var rise := absf(float(link.yb) - float(link.ya))
		_check(run > 1.5 and rad_to_deg(atan2(rise, run)) <= 16.0, "%s to %s is a gentle %s (%.0f degrees)" % [link.from, link.to, link.kind, rad_to_deg(atan2(rise, run))])
		_check(is_equal_approx(World.floor_height(a.lerp(b, 0.5)), lerpf(link.ya, link.yb, 0.5)) or rise < 0.01, "%s to %s carries the walker between the floors' heights" % [link.from, link.to])
		_check(World.in_pad(World.pad(link.from), a + (a - b).normalized() * 0.2) and World.in_pad(World.pad(link.to), b + (b - a).normalized() * 0.2),
			"%s to %s lands on both floors" % [link.from, link.to])
	for area: Dictionary in World.AREAS:
		var low := INF
		var high := -INF
		for entry: Dictionary in World.PADS:
			if entry.area != area.id: continue
			low = minf(low, entry.y)
			high = maxf(high, entry.y)
		for link: Dictionary in World.links():
			if link.area != area.id: continue
			low = minf(low, minf(link.ya, link.yb))
			high = maxf(high, maxf(link.ya, link.yb))
		_check(high - low >= 0.75, "%s rises %.2f m from its lowest to its highest floor" % [area.label, high - low])
	var bodies := (_world.get_node("CinemaFloor") as StaticBody3D).get_child_count()
	_check(bodies == World.PADS.size() + World.LINKS.size(), "every floor and slope stands on a physical floor (%d)" % bodies)


## Twelve stand sites, three in each area, wholly on their area's floors, clear
## of each other, the slopes, the landmarks and every interaction point; empty
## ones show a tag and are not interactive.
func _check_sites() -> void:
	_check(World.STAND_SITES.size() == 12, "twelve stand sites are kept for the cinema's games")
	var per_area := {}
	var footprint := Vector2(1.5, 1.0)
	for index in World.STAND_SITES.size():
		var site: Dictionary = World.STAND_SITES[index]
		var stand: Vector3 = site.stand
		var point: Vector3 = site.point
		var label := World._area_label(site.area)
		per_area[site.area] = int(per_area.get(site.area, 0)) + 1
		var box := Rect2(Vector2(stand.x, stand.z) - footprint * 0.5, footprint)
		var on_floor := true
		for step in 25:
			var corner := box.grow(0.2).position + box.grow(0.2).size * Vector2(float(step % 5) / 4.0, float(step / 5) / 4.0)
			on_floor = on_floor and is_equal_approx(World.floor_height(corner), stand.y) and _world._area_at_position(Vector3(corner.x, 0, corner.y)) == label
		_check(on_floor, "site %d stands wholly on a %s floor at its height" % [index, label])
		_check(_world._safe_footing(point) and _world._area_at_position(point) == label and not box.grow(0.25).has_point(Vector2(point.x, point.z))
			and is_equal_approx(point.y, World.floor_height(Vector2(point.x, point.z))), "site %d has a playable spot beside its counter" % index)
		for link: Dictionary in World.links():
			var clear := true
			for step in 25:
				var spot := box.grow(0.6).position + box.grow(0.6).size * Vector2(float(step % 5) / 4.0, float(step / 5) / 4.0)
				clear = clear and World.link_along(link, spot) < 0.0
			_check(clear, "site %d keeps the way from %s to %s open" % [index, link.from, link.to])
		for other in World.STAND_SITES.size():
			if other == index: continue
			var neighbour: Vector3 = World.STAND_SITES[other].stand
			var other_box := Rect2(Vector2(neighbour.x, neighbour.z) - footprint * 0.5, footprint)
			_check(not box.grow(0.6).intersects(other_box) and Vector2(point.x, point.z).distance_to(Vector2(neighbour.x, neighbour.z)) >= 1.2,
				"site %d keeps its distance from site %d" % [index, other])
		for lamp: Vector2 in Scenery.LAMP_POSTS:
			_check(not box.grow(0.6).has_point(lamp) and lamp.distance_to(Vector2(point.x, point.z)) >= 1.2, "site %d stays off the lamp posts" % index)
		for spec: Array in Scenery.SIGNPOSTS:
			_check(not box.grow(1.0).has_point(Vector2(spec[1], spec[2])), "site %d stays off the %s signpost" % [index, spec[0]])
		for landmark: Vector3 in [World.SCREEN, World.PROJECTOR, World.DOORS, World.REWIND_FLAT, World.CRANE]:
			_check(not box.grow(1.4).has_point(Vector2(landmark.x, landmark.z)), "site %d keeps clear of the landmarks" % index)
		for entry: Dictionary in _world.points:
			var at: Vector3 = entry.position
			_check(not box.grow(1.2).has_point(Vector2(at.x, at.z)) and Vector2(at.x, at.z).distance_to(Vector2(point.x, point.z)) >= 1.6,
				"site %d stays clear of %s" % [index, entry.id])
		for toy: Dictionary in Registry.toys("cinema"):
			var at: Vector3 = toy.at
			_check(not box.grow(1.2).has_point(Vector2(at.x, at.z)) and Vector2(at.x, at.z).distance_to(Vector2(point.x, point.z)) >= 1.6,
				"site %d stays clear of the %s toy" % [index, toy.id])
	for area: Dictionary in World.AREAS:
		_check(int(per_area.get(area.id, 0)) == 3, "%s keeps three stand sites" % area.label)
	var open := World.open_sites()
	_check(open.size() == 12 - World.ArcadeStands.rows("cinema").size(), "a site shows its tag until a game stands on it")
	_check(_world._scenery.site_tags.size() == open.size() and _world._scenery.site_tags.all(func(tag: Label3D) -> bool: return tag.text == "準備中"),
		"every empty site wears a 準備中 tag")
	_check(_world.points.size() == 5 + World.ArcadeStands.rows("cinema").size(), "empty sites are not interactive")


func _check_lamps() -> void:
	var stray := 0
	for light: Light3D in _world.find_children("*", "Light3D", true, false):
		stray += int(light != _world.sun and not _world.lamps.has(light))
	_check(stray == 0 and _world.lamps.size() >= 6 and _world.lamps.size() <= 8, "every light in the cinema goes through the lamp budget (%d)" % _world.lamps.size())
	_world.set_time_of_day("night")
	var lit := _world.lamps.filter(func(lamp: Light3D) -> bool: return lamp.light_energy > 0.0).size()
	var shadowed := _world.lamps.filter(func(lamp: Light3D) -> bool: return lamp.shadow_enabled).size()
	_check(lit > 0 and lit <= 8 and shadowed <= 2, "at night at most eight lamps are lit and two cast shadows")
	var life: Life = _world._life
	var night_film := float(life.film.get_shader_parameter("brightness"))
	var night_beam := float(life.beam_material.get_shader_parameter("strength"))
	_check(life.searchlights.all(func(light: MeshInstance3D) -> bool: return light.visible), "the searchlights sweep the night sky")
	_world.set_time_of_day("noon")
	_check(_world.lamps.all(func(lamp: Light3D) -> bool: return lamp.light_energy == 0.0), "by day every lamp is off")
	_check(life.searchlights.all(func(light: MeshInstance3D) -> bool: return not light.visible), "by day the searchlights are put away")
	_check(night_film > float(life.film.get_shader_parameter("brightness")) + 0.3 and night_beam > float(life.beam_material.get_shader_parameter("strength")) * 3.0,
		"after dark the screen glows brighter and the projector's beam shows")
	var island := {"sky": Color.WHITE, "fog": Color.WHITE, "ambient": Color.WHITE, "ambient_energy": 1.0, "glow": 0.0}
	_check(_world._air("night", island).sky != _world._air("noon", island).sky, "the lot's sky turns to velvet after dark")


func _check_life() -> void:
	var life: Life = _world._life
	var nodes := _world.find_children("*", "Node", true, false).size()
	var materials: int = _world.material_cache.size()
	var reel := life.reel_angle()
	var sweep := life.searchlight_tilt(0)
	var crane := life.crane_yaw()
	var popped := 0
	for frame in 360:
		await physics_frame
		popped = maxi(popped, life.flashes_lit())
	_check(life.reel_angle() != reel, "the projector's reels turn")
	_check(life.searchlight_tilt(0) != sweep, "the searchlights sweep")
	_check(not is_equal_approx(life.crane_yaw(), crane), "the camera crane drifts over the stage")
	_check(popped > 0, "paparazzi flashes pop along the carpet")
	# The carpet sets every flash off and swings the doors open.
	_check(_world.walk_carpet().contains("紅毯"), "the red carpet answers a walk")
	var opened := 0.0
	var crowd := 0
	for frame in 50:
		await physics_frame
		opened = maxf(opened, life.door_angle())
		crowd = maxi(crowd, life.flashes_lit())
	_check(opened > 1.0 and crowd >= 2, "walking the carpet opens the palace doors and sets the flashes off (%d at once)" % crowd)
	# A new reel: the film changes and the countdown leader runs first.
	var before := _world.reel_index()
	_check(_world.change_reel().contains("今晚放映") and _world.reel_index() != before and int(life.film.get_shader_parameter("reel")) == _world.reel_index(), "the projector changes the reel")
	await _frames(3)
	_check(float(life.film.get_shader_parameter("leader")) > 0.0, "a new reel opens with the countdown leader")
	# The flat falls on its face, then rewinds upright.
	_check(_world.topple_flat().contains("倒帶"), "the backlot flat answers a push")
	var fallen := 0.0
	for frame in int(Life.TOPPLE_SECONDS * 60.0) + 20:
		await physics_frame
		fallen = maxf(fallen, life.flat_tilt())
	_check(fallen > 1.3 and absf(life.flat_tilt()) < 0.05, "the flat falls flat (%.2f) and rewinds back upright" % fallen)
	# Action: the crane swoops.
	var calm := life.crane_yaw()
	_check(_world.call_action().contains("開麥拉"), "the stage answers a call of action")
	var swing := 0.0
	for frame in 90:
		await physics_frame
		swing = maxf(swing, absf(life.crane_yaw() - calm))
	_check(swing > 0.6, "called to action the crane swoops over the stage (%.2f)" % swing)
	# Reduced motion: one still frame.
	_world.apply_settings({"reduced_motion": true})
	await _frames(4)
	reel = life.reel_angle()
	sweep = life.searchlight_tilt(1)
	crane = life.crane_yaw()
	_world.walk_carpet()
	_world.topple_flat()
	await _frames(30)
	_check(life.reel_angle() == reel and life.searchlight_tilt(1) == sweep and life.crane_yaw() == crane and life.flat_tilt() == 0.0
		and life.door_angle() == 0.0 and life.flashes_lit() == 0, "nothing moves under reduced motion")
	_check(float(life.film.get_shader_parameter("motion")) == 0.0 and float(life.beam_material.get_shader_parameter("motion")) == 0.0,
		"reduced motion holds the film on one frame and stills the dust in the beams")
	_world.apply_settings({"reduced_motion": false})
	for phase: String in ["dusk", "night", "dawn", "noon"]:
		_world.set_time_of_day(phase)
	await _frames(20)
	_check(_world.find_children("*", "Node", true, false).size() == nodes and _world.material_cache.size() == materials,
		"the living lot reuses its nodes and materials through motion settings and time of day")


## A step off any floor is caught: the walker stays on the floor it stood on,
## at that floor's height, with a splash; a walker found off every floor goes
## back to the last safe spot.
func _check_edges() -> void:
	var splashed := 0
	for spec: Array in [["plaza", Vector2(0, -1)], ["stage", Vector2(1, 0)], ["street", Vector2(0, 1)], ["front", Vector2(-1, 0)]]:
		var entry := World.pad(spec[0])
		var out: Vector2 = spec[1]
		var rect: Rect2 = entry.rect
		var start: Vector2 = rect.get_center() + out * rect.size * 0.3
		if spec[0] == "plaza": start = Vector2(3.0, -10.0)
		if spec[0] == "street": start.x = -10.5
		if spec[0] == "front": start.y = -9.4
		_place(Vector3(start.x, entry.y, start.y))
		await _frames(6)
		var target := start + out * 6.0
		await _walk(target, 200)
		var at := _world.player_spot()
		_check(World.in_pad(entry, Vector2(at.x, at.z)) and absf(at.y - float(entry.y)) < 0.12 and _world.player.is_on_floor(),
			"walking off the %s edge leaves the walker safely on it" % spec[0])
		splashed += int(_world._life.catching())
	_check(splashed >= 3, "a caught step shows a splash (%d of 4)" % splashed)
	var safe := _world.last_safe_position()
	_world.player.position = Vector3(0.0, -3.0, 0.0)
	_world._constrain_player(Vector3(0.0, 1.0, 0.0))
	_check(_world.player.position.is_equal_approx(safe) and _world.player.velocity == Vector3.ZERO, "a walker off every floor goes back to the last safe spot")
	await _frames(4)


## Every interaction point and every kept site's playing spot can be reached on
## foot from the pier's foot, around every booth, seat row, screen and sign.
func _check_reach() -> void:
	var bounds := World.BOUNDS
	var columns := int(bounds.size.x / CELL) + 1
	var rows := int(bounds.size.y / CELL) + 1
	var open := PackedByteArray()
	open.resize(columns * rows)
	var probe := PhysicsShapeQueryParameters3D.new()
	var body := SphereShape3D.new()
	body.radius = 0.32
	probe.shape = body
	var exclusions: Array[RID] = [_world.player.get_rid()]
	probe.exclude = exclusions
	probe.collision_mask = _world.player.collision_mask
	var space := _world.player.get_world_3d().direct_space_state
	for row in rows:
		for column in columns:
			var spot := bounds.position + Vector2(column, row) * CELL
			if not _world._safe_footing(Vector3(spot.x, 0, spot.y)): continue
			probe.transform = Transform3D(Basis.IDENTITY, Vector3(spot.x, World.floor_height(spot) + 0.8, spot.y))
			if space.intersect_shape(probe, 1).is_empty(): open[row * columns + column] = 1
	var start := Vector2i(((Vector2(World.ENTRY.x, World.ENTRY.z) - bounds.position) / CELL).round())
	var seen := PackedByteArray()
	seen.resize(columns * rows)
	var queue: Array[Vector2i] = [start]
	seen[start.y * columns + start.x] = 1
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_back()
		for step: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var next := cell + step
			if next.x < 0 or next.y < 0 or next.x >= columns or next.y >= rows: continue
			var index := next.y * columns + next.x
			if open[index] == 0 or seen[index] == 1: continue
			seen[index] = 1
			queue.append(next)
	var targets: Array[Array] = []
	for point: Dictionary in _world.points: targets.append([point.id, point.position])
	for index in World.STAND_SITES.size(): targets.append(["site %d" % index, World.STAND_SITES[index].point])
	for toy: Dictionary in Registry.toys("cinema"): targets.append([toy.id, toy.at])
	for target: Array in targets:
		var at: Vector3 = target[1]
		var cell := Vector2i(((Vector2(at.x, at.z) - bounds.position) / CELL).round())
		var reached := false
		for dz in range(-2, 3):
			for dx in range(-2, 3):
				var near := cell + Vector2i(dx, dz)
				if near.x >= 0 and near.y >= 0 and near.x < columns and near.y < rows and seen[near.y * columns + near.x] == 1: reached = true
		_check(reached, "%s can be walked to from the pier's foot" % target[0])


func _check_map() -> void:
	var snapshot := _world.map_snapshot()
	_check(snapshot.region == "cinema" and snapshot.areas.size() == World.PADS.size() and snapshot.links.size() == World.LINKS.size() and snapshot.sites.size() == 12
		and snapshot.points.size() == _world.points.size(), "the plan lists the floors, slopes, stand sites and points")
	for area: Dictionary in snapshot.areas:
		_check(World.BOUNDS.encloses(area.rect), "the plan keeps %s inside the lot" % area.id)
	var map := MapPanel.new()
	map.setup(snapshot)
	root.add_child(map)
	var locations := map.find_child("CinemaMapLocations", true, false)
	_check(map.find_child("CinemaMapTerrain", true, false) != null and locations != null and locations.get_child_count() == _world.points.size()
		and map.snapshot.player == _world.player.position, "map shows all locations and the real player")
	snapshot.areas[0].label = "missing"
	_check(_world.map_snapshot().areas[0].label == "紅毯", "map snapshot is detached from world data")
	map.free()


## The centre line of the slope between two floors, as walking waypoints.
func _route(from: String, to: String) -> Array[Vector2]:
	for link: Dictionary in World.links():
		var a: Vector2 = link.a
		var b: Vector2 = link.b
		if link.from == to and link.to == from:
			var swap := a
			a = b
			b = swap
		elif not (link.from == from and link.to == to):
			continue
		var along := (b - a).normalized()
		return [a - along * 0.6, b + along * 0.8]
	push_error("no link from %s to %s" % [from, to])
	return []


func _place(at: Vector3) -> void:
	_world.player.position = at
	_world.player.velocity = Vector3.ZERO
	_world._sync_external_avatar_reposition()


func _reach(steps: Array, id: String, area: String, height: float) -> void:
	for step in steps:
		_check(await _walk(step), "physical walking route reaches " + str(step))
	_check(_world.nearest.get("id") == id and _world.current_area == area and absf(_world.player.position.y - height) < 0.12,
		"actual point, breadcrumb and floor height agree on " + id)


func _walk(destination: Vector2, limit_ticks := -1) -> bool:
	var first: Vector3 = _world.player.position
	var distance := Vector2(first.x, first.z).distance_to(destination)
	var limit := ceili(distance / World.AVATAR_RUN_SPEED * 60.0) + 100 if limit_ticks < 0 else limit_ticks
	for tick in limit:
		var at: Vector3 = _world.player.position
		var offset := destination - Vector2(at.x, at.z)
		if offset.length() < 0.22:
			break
		var direction := offset.normalized()
		var strength := [maxf(-direction.x, 0.0), maxf(direction.x, 0.0), maxf(-direction.y, 0.0), maxf(direction.y, 0.0)]
		for index in MOVE.size():
			if strength[index] > 0.0:
				Input.action_press(MOVE[index], strength[index])
			else:
				Input.action_release(MOVE[index])
		await physics_frame
	for action in MOVE:
		Input.action_release(action)
	await _frames(9)
	var position: Vector3 = _world.player.position
	return Vector2(position.x, position.z).distance_to(destination) < 0.47 and _world.player.is_on_floor()


func _frames(count: int) -> void:
	for index in count:
		await physics_frame


func _check(valid: bool, failure: String) -> void:
	if not valid:
		_failures.append(failure)
