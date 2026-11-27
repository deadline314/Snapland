extends SceneTree
## The Yoyo Hotel standing alone: its four rooms and veranda, the landmarks that
## make each one recognisable, the room-number signposts, the twelve kept stand
## sites, every interaction point reached on foot, the friendly ghosts and the
## floating things, lamps within budget and a truthful floor plan.

const World = preload("res://game/world/hotel_world.gd")
const Scenery = preload("res://game/world/hotel_scenery.gd")
const Life = preload("res://game/world/hotel_life.gd")
const MapPanel = preload("res://game/ui/harbor_map_panel.gd")
const SaveGuard = preload("res://game/core/test_save_guard.gd")
const SceneStandards = preload("res://game/world/scene_standards.gd")
const LANDMARKS := ["HotelLawn", "HotelTower", "HotelAttic", "HotelSign", "HotelStructure", "HotelPageWalls", "HotelDeskBell",
	"HotelFloatingSheet", "HotelFloatingPillow0", "HotelFloatingLuggage", "HotelFloatingUmbrellas", "HotelFrontPath"]
## The follow camera shows this much ground around the player; scenery must reach 12 m further.
const VIEW_REACH := 19.2 + 12.0
const MOVE := ["move_left", "move_right", "move_up", "move_down"]
const CELL := 0.25

var _world: World
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if not SaveGuard.validate_save_path(OS.get_environment("SNAPLAND_SAVE_PATH"), OS.get_user_data_dir()).is_empty():
		push_error("Hotel world test requires a private save.")
		quit(1)
		return
	_world = World.new()
	root.add_child(_world)
	await _frames(5)
	_check(_world.coastal_play == null and _world.npc_activity == null, "the hotel does not inherit Welcome activities")
	_check(_world.current_area == "櫃檯大廳" and _world.player.is_on_floor(), "spawn lands inside the front door, in the lobby")
	_check_rooms()
	_check_sites()
	_check_lamps()
	await _check_life()
	_check_reach()
	await _reach([Vector2(-9.0, -8.2), Vector2(World.BELL_POINT.x, World.BELL_POINT.z)], "hotel:bell", "櫃檯大廳")
	await _reach([Vector2(-9.0, -8.2), Vector2(-9.0, 1.1), Vector2(-1.6, 1.1), Vector2(World.CORRIDOR_POINT.x, World.CORRIDOR_POINT.z)], "hotel:corridor", "折頁走廊")
	await _reach([Vector2(-1.6, 1.1), Vector2(5.2, 1.1), Vector2(World.LOST_POINT.x, World.LOST_POINT.z)], "hotel:lost", "失物室")
	await _reach([Vector2(5.2, 1.1), Vector2(12.8, 1.1), Vector2(World.DREAM_POINT.x, World.DREAM_POINT.z)], "hotel:dream", "夢境客房")
	await _reach([Vector2(12.8, 1.1), Vector2(-9.0, 1.1), Vector2(World.ENTRY.x, World.ENTRY.z)], "region:welcome", "櫃檯大廳")
	_check_map()
	var safe_at: Vector3 = _world.player.position
	_world.player.position = Vector3(-9.0, World.GROUND_Y, 12.5)
	_world._constrain_player(safe_at)
	_check(_world.player.position.is_equal_approx(safe_at) and _world.player.velocity == Vector3.ZERO, "off the veranda the body stops safely")
	_world.player.position = Vector3(3, -3, -20)
	_world._constrain_player(_world.player.position)
	_check(_world.player.position == World.ENTRY and _world.player.velocity == Vector3.ZERO, "an invalid floor safely restores the front door")
	var audit := SceneStandards.audit(_world, "hotel")
	for rule: String in SceneStandards.RULES:
		_check((audit[rule] as Array).is_empty(), "the hotel meets the scene standard '%s': %s" % [rule, str(audit[rule])])
	_world.free()
	for failure in _failures:
		push_error(failure)
	if _failures.is_empty():
		print("PASS: hotel rooms, landmarks, kept stand sites, friendly ghosts, physical routes and truthful map")
	quit(int(not _failures.is_empty()))


func _check_rooms() -> void:
	for landmark: String in LANDMARKS:
		_check(_world.get_node_or_null(landmark) != null, "the hotel has its %s" % landmark)
	var lawn := _world.get_node_or_null("HotelLawn") as MeshInstance3D
	_check(lawn != null and (lawn.mesh as PlaneMesh).size.x >= World.BOUNDS.size.x + 2.0 * VIEW_REACH
		and (lawn.mesh as PlaneMesh).size.y >= World.BOUNDS.size.y + 2.0 * VIEW_REACH and lawn.position.y < World.GROUND_Y - 0.1,
		"natural ground runs past everything the camera can show, a clear step below the floors")
	var ids := {}
	for area: Dictionary in World.AREAS:
		ids[area.id] = true
		var room: Rect2 = area.room
		var terrace: Rect2 = area.terrace
		for pair: Array in [["HotelFloor_", room], ["HotelVeranda_", terrace]]:
			var slab := _world.get_node_or_null(String(pair[0]) + String(area.id)) as MeshInstance3D
			var footprint: Rect2 = pair[1]
			_check(slab != null and slab.mesh is BoxMesh and Vector2((slab.mesh as BoxMesh).size.x, (slab.mesh as BoxMesh).size.z).is_equal_approx(footprint.size)
				and World.BOUNDS.encloses(footprint), "%s has the physical floor its plan says (%s)" % [area.id, pair[0]])
		_check(is_equal_approx(room.end.y, terrace.position.y) and is_equal_approx(room.position.x, terrace.position.x),
			"%s opens straight onto its stretch of veranda" % area.id)
		_check(_world._area_at_position(Vector3(room.get_center().x, 0, room.get_center().y)) == area.label
			and _world._area_at_position(Vector3(terrace.get_center().x, 0, terrace.get_center().y)) == area.label, "%s names its room and veranda" % area.id)
		var number := _world.get_node_or_null("HotelRoomNumber_" + String(area.number)) as Label3D
		_check(number != null and number.text == area.number, "%s has its room-number plate %s" % [area.id, area.number])
	_check(ids.size() == 4 and ids.has("lobby") and ids.has("corridor") and ids.has("lost") and ids.has("dream"),
		"four areas: lobby, folding-page corridor, lost property and dream rooms")
	_check(World.SIGNPOSTS.size() == World.AREAS.size(), "every room has a fixed number signpost")
	for index in World.SIGNPOSTS.size():
		var post: Vector3 = World.SIGNPOSTS[index]
		_check(_world._area_at_position(post) == World.AREAS[index].label, "signpost %s stands at its own room" % World.AREAS[index].number)
	var sign := _world.get_node_or_null("HotelSign") as Label3D
	_check(sign != null and sign.text == "幽幽旅館", "the clock tower carries the hotel's name")
	var ghosts := 0
	for child in _world.get_children():
		if String(child.name).begins_with("HotelGhost_"): ghosts += 1
	_check(ghosts == Life.GHOSTS.size() and ghosts >= 6, "little ghosts live in every room (%d)" % ghosts)


## Twelve stand sites, three on each veranda, clear of each other, the paths,
## the signposts, the lamps and every interaction point; empty ones show a tag
## and are not interactive.
func _check_sites() -> void:
	_check(World.STAND_SITES.size() == 12, "twelve stand sites are kept for the hotel's games")
	var per_area := {}
	var footprint := Vector2(1.5, 1.0)
	for index in World.STAND_SITES.size():
		var site: Dictionary = World.STAND_SITES[index]
		var stand: Vector3 = site.stand
		var point: Vector3 = site.point
		per_area[site.area] = int(per_area.get(site.area, 0)) + 1
		var area: Dictionary = World.AREAS.filter(func(entry: Dictionary) -> bool: return entry.id == site.area)[0]
		var terrace: Rect2 = area.terrace
		var box := Rect2(Vector2(stand.x, stand.z) - footprint * 0.5, footprint)
		_check(terrace.grow(-0.2).encloses(box), "site %d stands wholly on the %s veranda" % [index, site.area])
		_check(_world._safe_footing(point) and _world._area_at_position(point) == area.label and not box.grow(0.25).has_point(Vector2(point.x, point.z)),
			"site %d has a playable spot beside its counter" % index)
		# Clear of the runner that joins the rooms.
		_check(box.end.y < -0.4 or box.position.y > 1.1 + 0.75 + 1.0, "site %d keeps the veranda runner open" % index)
		for other in World.STAND_SITES.size():
			if other == index: continue
			var neighbour: Vector3 = World.STAND_SITES[other].stand
			var other_box := Rect2(Vector2(neighbour.x, neighbour.z) - footprint * 0.5, footprint)
			_check(not box.grow(0.6).intersects(other_box) and Vector2(point.x, point.z).distance_to(Vector2(neighbour.x, neighbour.z)) >= 1.2,
				"site %d keeps its distance from site %d" % [index, other])
		for post: Vector3 in World.SIGNPOSTS:
			_check(box.grow(1.0).has_point(Vector2(post.x, post.z)) == false, "site %d stays off the signposts" % index)
		for lamp: Vector2 in Scenery.LAMP_POSTS:
			_check(not box.grow(0.6).has_point(lamp) and lamp.distance_to(Vector2(point.x, point.z)) >= 1.2, "site %d stays off the lamp posts" % index)
		for entry: Dictionary in _world.points:
			var at: Vector3 = entry.position
			_check(not box.grow(1.2).has_point(Vector2(at.x, at.z)) and Vector2(at.x, at.z).distance_to(Vector2(point.x, point.z)) >= 1.6,
				"site %d stays clear of %s" % [index, entry.id])
	for area: Dictionary in World.AREAS:
		_check(int(per_area.get(area.id, 0)) == 3, "%s keeps three stand sites" % area.id)
	var open := World.open_sites()
	_check(open.size() == 12 - World.ArcadeStands.rows("hotel").size(), "a site shows its tag until a game stands on it")
	_check(_world._scenery.site_tags.size() == open.size() and _world._scenery.site_tags.all(func(tag: Label3D) -> bool: return tag.text == "準備中"),
		"every empty site wears a 準備中 tag")
	_check(_world.points.size() == 5 + World.ArcadeStands.rows("hotel").size(), "empty sites are not interactive")


func _check_lamps() -> void:
	var stray := 0
	for light: Light3D in _world.find_children("*", "Light3D", true, false):
		stray += int(light != _world.sun and not _world.lamps.has(light))
	_check(stray == 0 and _world.lamps.size() >= 6, "every light in the hotel goes through the lamp budget")
	_world.set_time_of_day("night")
	var lit := _world.lamps.filter(func(lamp: Light3D) -> bool: return lamp.light_energy > 0.0).size()
	var shadowed := _world.lamps.filter(func(lamp: Light3D) -> bool: return lamp.shadow_enabled).size()
	_check(lit > 0 and lit <= 8 and shadowed <= 2, "at night at most eight lamps are lit and two cast shadows")
	_world.set_time_of_day("noon")
	_check(_world.lamps.all(func(lamp: Light3D) -> bool: return lamp.light_energy == 0.0), "by day every lamp is off")
	var island := {"fog": Color.WHITE, "ambient": Color.WHITE, "glow": 0.0}
	_check(_world._air("night", island).fog != _world._air("noon", island).fog, "the hotel's air turns indigo after dark")


func _check_life() -> void:
	var life: Life = _world._life
	var nodes := _world.find_children("*", "Node", true, false).size()
	var materials: int = _world.material_cache.size()
	var greeter := Life.GHOSTS.map(func(spec: Dictionary) -> String: return spec.name).find("Greeter")
	_place(Vector3(14.0, World.GROUND_Y, 1.1))
	var before := life.ghost_position(greeter)
	await _frames(40)
	_check(life.ghost_position(greeter).distance_to(before) > 0.05, "the ghosts drift about")
	# The curious greeter floats over to the walker and waves.
	var route: Vector3 = Life._path(Life.GHOSTS[greeter], _world.time)
	var meet := Vector3(clampf(route.x - 1.6, -15.5, 15.5), World.GROUND_Y, 1.1)
	_place(meet)
	for wait in 8:
		await _frames(30)
		if life.is_waving(greeter): break
	var near := life.ghost_position(greeter)
	_check(life.is_waving(greeter) and Vector2(near.x - meet.x, near.z - meet.z).length() < Life.REACH, "a curious ghost floats to the walker and waves")
	# The bell pops the receptionist up.
	var desk := life.ghost_position(0)
	_world.ring_bell()
	await _frames(12)
	_check(life.ghost_position(0).y > desk.y + 0.2 and life.is_waving(0), "ringing the bell brings the receptionist up to wave")
	# The page walls rustle beside the walker.
	_place(Vector3(-3.4, World.GROUND_Y, -7.0))
	await _frames(30)
	_check(life.page_strength() > 0.06, "the page walls rustle as the walker passes between them")
	_place(Vector3(-13.0, World.GROUND_Y, 4.0))
	await _frames(70)
	_check(life.page_strength() < 0.05, "the pages settle when nobody is near")
	_check(_world.browse_lost().contains("失物室") and _world.fluff_dream().contains("枕頭"), "the lost room and the dream bed answer the walker")
	# Reduced motion: one still frame, nothing moves even beside a curious ghost.
	_world.apply_settings({"reduced_motion": true})
	await _frames(4)
	var held: Array[Vector3] = []
	for index in Life.GHOSTS.size(): held.append(life.ghost_position(index))
	var sheet: Vector3 = _world.get_node("HotelFloatingSheet").position
	var pages: ShaderMaterial = _world._scenery.pages
	_check(pages.get_shader_parameter("motion") == 0.0, "reduced motion steadies the page walls")
	_place(meet)
	await _frames(30)
	var still := true
	for index in Life.GHOSTS.size(): still = still and life.ghost_position(index) == held[index]
	_check(still and _world.get_node("HotelFloatingSheet").position == sheet and not life.is_waving(greeter), "nothing moves under reduced motion")
	_world.apply_settings({"reduced_motion": false})
	for phase: String in ["dusk", "night", "dawn", "noon"]:
		_world.set_time_of_day(phase)
	await _frames(20)
	_check(_world.find_children("*", "Node", true, false).size() == nodes and _world.material_cache.size() == materials,
		"the living hotel reuses its nodes and materials through motion settings and time of day")
	_place(World.ENTRY)
	await _frames(10)


## Every interaction point and every kept site's playing spot can be reached on
## foot from the front door, around every counter, wall and covered booth.
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
			probe.transform = Transform3D(Basis.IDENTITY, Vector3(spot.x, 1.0, spot.y))
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
	for target: Array in targets:
		var at: Vector3 = target[1]
		var cell := Vector2i(((Vector2(at.x, at.z) - bounds.position) / CELL).round())
		var reached := false
		for dz in range(-2, 3):
			for dx in range(-2, 3):
				var near := cell + Vector2i(dx, dz)
				if near.x >= 0 and near.y >= 0 and near.x < columns and near.y < rows and seen[near.y * columns + near.x] == 1: reached = true
		_check(reached, "%s can be walked to from the front door" % target[0])


func _check_map() -> void:
	var snapshot := _world.map_snapshot()
	_check(snapshot.region == "hotel" and snapshot.areas.size() == 8 and snapshot.signs.size() == 4 and snapshot.sites.size() == 12
		and snapshot.points.size() == _world.points.size(), "the floor plan lists the rooms, signposts, stand sites and points")
	for area: Dictionary in snapshot.areas:
		_check(World.BOUNDS.encloses(area.rect), "the plan keeps %s inside the hotel" % area.id)
	var map := MapPanel.new()
	map.setup(snapshot)
	root.add_child(map)
	var locations := map.find_child("HotelMapLocations", true, false)
	_check(map.find_child("HotelMapTerrain", true, false) != null and locations != null and locations.get_child_count() == _world.points.size()
		and map.snapshot.player == _world.player.position, "map shows all locations and the real player")
	snapshot.areas[0].label = "missing"
	_check(_world.map_snapshot().areas[0].label == "櫃檯大廳", "map snapshot is detached from world data")
	map.free()


func _place(at: Vector3) -> void:
	_world.player.position = at
	_world.player.velocity = Vector3.ZERO
	_world._sync_external_avatar_reposition()


func _reach(steps: Array[Vector2], id: String, area: String) -> void:
	for step in steps:
		_check(await _walk(step), "physical walking route reaches " + str(step))
	_check(_world.nearest.get("id") == id and _world.current_area == area, "actual point and breadcrumb agree on " + area)


func _walk(destination: Vector2) -> bool:
	var first: Vector3 = _world.player.position
	var distance := Vector2(first.x, first.z).distance_to(destination)
	var limit := ceili(distance / World.AVATAR_RUN_SPEED * 60.0) + 100
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
