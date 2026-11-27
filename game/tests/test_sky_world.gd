extends SceneTree
## The Cloud Park standing alone: its four areas and their landmarks, decks at
## several heights joined by ramps with no jump anywhere, a step off a deck
## caught and set back, the twelve kept stand sites, every interaction point
## reached on foot, the wind (flags, kites, drifting clouds), the turning
## wheel, lamps within budget and a truthful plan.

const World = preload("res://game/world/sky_world.gd")
const Scenery = preload("res://game/world/sky_scenery.gd")
const Life = preload("res://game/world/sky_life.gd")
const MapPanel = preload("res://game/ui/harbor_map_panel.gd")
const SaveGuard = preload("res://game/core/test_save_guard.gd")
const SceneStandards = preload("res://game/world/scene_standards.gd")
const LANDMARKS := ["SkyCloudSea", "SkyCloudBank", "SkyStructure", "SkyDeck_plaza", "SkyDeck_isle", "SkyDeck_deck", "SkyDeck_cloud",
	"SkyWheel", "SkyWheelCabins", "SkyKites", "SkyKiteStrings", "SkyBalloon", "SkyBalloonRopes", "SkyDriftClouds",
	"SkyCloudBridge", "SkyParkSign", "SkyPhotoSign", "SkyFloor"]
## The follow camera shows this much ground around the player; scenery must reach 12 m further.
const VIEW_REACH := 19.2 + 12.0
const MOVE := ["move_left", "move_right", "move_up", "move_down"]
const CELL := 0.25
const WIND := Vector3(0.86, 0, 0.51)

var _world: World
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if not SaveGuard.validate_save_path(OS.get_environment("SNAPLAND_SAVE_PATH"), OS.get_user_data_dir()).is_empty():
		push_error("Sky world test requires a private save.")
		quit(1)
		return
	_world = World.new()
	root.add_child(_world)
	await _frames(5)
	_check(_world.coastal_play == null and _world.npc_activity == null, "the park does not inherit Welcome activities")
	_check(_world.current_area == "摩天輪" and _world.player.is_on_floor(), "spawn lands on the gate plaza, by the wheel")
	_check_landmarks()
	_check_plan()
	_check_sites()
	_check_lamps()
	await _check_life()
	_check_reach()
	var plaza := Vector2(World.ENTRY.x, World.ENTRY.z)
	await _reach([Vector2(World.WHEEL_POINT.x, World.WHEEL_POINT.z)], "sky:wheel", "摩天輪", World.GROUND_Y)
	await _reach([Vector2(-1.0, -12.4)] + _route("plaza", "isle1") + _route("isle1", "isle2") + [Vector2(World.BALLOON_POINT.x, World.BALLOON_POINT.z)], "sky:balloon", "浮島步道", 1.30)
	await _reach(_route("isle2", "isle3") + _route("isle3", "kite") + [Vector2(World.KITE_POINT.x, World.KITE_POINT.z)], "sky:kites", "風箏台", 1.85)
	await _reach(_route("kite", "isle3") + _route("isle3", "isle4") + _route("isle4", "photo") + [Vector2(World.PHOTO_POINT.x, World.PHOTO_POINT.z)], "sky:photo", "雲霄攝影點", 2.35)
	# Down the long cloud stair to the wheel and back to the gate.
	await _reach(_route("photo", "wheel") + [Vector2(4.0, -11.0), plaza], "region:welcome", "摩天輪", World.GROUND_Y)
	await _check_edges()
	_check_map()
	var audit := SceneStandards.audit(_world, "sky")
	for rule: String in SceneStandards.RULES:
		_check((audit[rule] as Array).is_empty(), "the park meets the scene standard '%s': %s" % [rule, str(audit[rule])])
	_world.free()
	for failure in _failures:
		push_error(failure)
	if _failures.is_empty():
		print("PASS: sky park decks, ramps without jumps, caught steps, kept stand sites, wind, wheel and truthful map")
	quit(int(not _failures.is_empty()))


func _check_landmarks() -> void:
	for landmark: String in LANDMARKS:
		_check(_world.get_node_or_null(landmark) != null, "the park has its %s" % landmark)
	var sea := _world.get_node_or_null("SkyCloudSea") as MeshInstance3D
	_check(sea != null and (sea.mesh as PlaneMesh).size.x >= World.BOUNDS.size.x + 2.0 * VIEW_REACH
		and (sea.mesh as PlaneMesh).size.y >= World.BOUNDS.size.y + 2.0 * VIEW_REACH and sea.position.y < World.GROUND_Y - 0.05,
		"a sea of cloud runs past everything the camera can show, below every deck")
	var material := sea.material_override as ShaderMaterial if sea != null else null
	_check(material != null and material.shader.resource_path.ends_with("sky_cloud_sea.gdshader") and not bool(material.get_shader_parameter("bounded")),
		"standing alone the cloud sea is unbounded")
	for area: Dictionary in World.AREAS:
		var post := _world.get_node_or_null("SkySignpost_" + String(area.id)) as Label3D
		_check(post != null and post.text == area.label, "%s has its signpost" % area.label)
		_check(World.PADS.any(func(entry: Dictionary) -> bool: return entry.area == area.id), "%s has a deck to walk on" % area.label)
	_check((_world.get_node("SkyParkSign") as Label3D).text == "雲端遊樂場", "the plaza board carries the park's name")


## Decks never overlap at different heights, every link is a gentle slope
## that meets its decks' edges at their own heights, and the plan has at least
## four levels.
func _check_plan() -> void:
	var levels := {}
	for entry: Dictionary in World.PADS:
		levels[snappedf(entry.y, 0.01)] = true
		_check(World.BOUNDS.grow(-0.8).encloses(Rect2((entry.centre as Vector2) - entry.radius, (entry.radius as Vector2) * 2.0)), "%s stays inside the park" % entry.id)
		for other: Dictionary in World.PADS:
			if other.id <= entry.id or is_equal_approx(other.y, entry.y): continue
			_check(not _ellipses_touch(entry, other), "%s and %s never overlap at different heights" % [entry.id, other.id])
	_check(levels.size() >= 5, "the decks stand at %d different heights" % levels.size())
	for link: Dictionary in World.links():
		var a: Vector2 = link.a
		var b: Vector2 = link.b
		var run := a.distance_to(b)
		var rise := absf(float(link.yb) - float(link.ya))
		_check(run > 1.5 and rad_to_deg(atan2(rise, run)) <= 16.0, "%s to %s is a gentle %s (%.0f degrees)" % [link.from, link.to, link.kind, rad_to_deg(atan2(rise, run))])
		_check(is_equal_approx(World.floor_height(a.lerp(b, 0.5)), lerpf(link.ya, link.yb, 0.5)), "%s to %s carries the walker between the decks' heights" % [link.from, link.to])
		_check(World.in_pad(World.pad(link.from), a + (a - b).normalized() * 0.2) and World.in_pad(World.pad(link.to), b + (b - a).normalized() * 0.2),
			"%s to %s lands on both decks" % [link.from, link.to])
	_check(World.links().any(func(link: Dictionary) -> bool: return link.kind == "stair" and a_long(link)), "a long cloud stair runs down from the photo deck")
	var bodies := (_world.get_node("SkyFloor") as StaticBody3D).get_child_count()
	_check(bodies == World.PADS.size() + World.LINKS.size(), "every deck and link stands on a physical floor (%d)" % bodies)


func a_long(link: Dictionary) -> bool:
	return (link.a as Vector2).distance_to(link.b) > 10.0


func _ellipses_touch(a: Dictionary, b: Dictionary) -> bool:
	for index in 48:
		var angle := TAU * float(index) / 48.0
		var edge: Vector2 = (a.centre as Vector2) + Vector2(cos(angle) * a.radius.x, sin(angle) * a.radius.y)
		if World.in_pad(b, edge, -0.3): return true
	return false


## Twelve stand sites, three in each area, wholly on their area's decks, clear
## of each other, the links, the landmarks and every interaction point; empty
## ones show a tag and are not interactive.
func _check_sites() -> void:
	_check(World.STAND_SITES.size() == 12, "twelve stand sites are kept for the park's games")
	var per_area := {}
	var footprint := Vector2(1.5, 1.0)
	for index in World.STAND_SITES.size():
		var site: Dictionary = World.STAND_SITES[index]
		var stand: Vector3 = site.stand
		var point: Vector3 = site.point
		var label := World._area_label(site.area)
		per_area[site.area] = int(per_area.get(site.area, 0)) + 1
		var box := Rect2(Vector2(stand.x, stand.z) - footprint * 0.5, footprint)
		var on_deck := true
		for step in 25:
			var corner := box.grow(0.2).position + box.grow(0.2).size * Vector2(float(step % 5) / 4.0, float(step / 5) / 4.0)
			on_deck = on_deck and not is_nan(World.floor_height(corner)) and _world._area_at_position(Vector3(corner.x, 0, corner.y)) == label
		_check(on_deck and is_equal_approx(stand.y, World.floor_height(Vector2(stand.x, stand.z))), "site %d stands wholly on a %s deck at its height" % [index, label])
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
		for landmark: Vector3 in [World.WHEEL, World.BALLOON, World.MAST, World.FRAME]:
			_check(not box.grow(1.4).has_point(Vector2(landmark.x, landmark.z)), "site %d keeps clear of the landmarks" % index)
		for entry: Dictionary in _world.points:
			var at: Vector3 = entry.position
			_check(not box.grow(1.2).has_point(Vector2(at.x, at.z)) and Vector2(at.x, at.z).distance_to(Vector2(point.x, point.z)) >= 1.6,
				"site %d stays clear of %s" % [index, entry.id])
	for area: Dictionary in World.AREAS:
		_check(int(per_area.get(area.id, 0)) == 3, "%s keeps three stand sites" % area.label)
	var open := World.open_sites()
	_check(open.size() == 12 - World.ArcadeStands.rows("sky").size(), "a site shows its tag until a game stands on it")
	_check(_world._scenery.site_tags.size() == open.size() and _world._scenery.site_tags.all(func(tag: Label3D) -> bool: return tag.text == "準備中"),
		"every empty site wears a 準備中 tag")
	_check(_world.points.size() == 5 + World.ArcadeStands.rows("sky").size(), "empty sites are not interactive")


func _check_lamps() -> void:
	var stray := 0
	for light: Light3D in _world.find_children("*", "Light3D", true, false):
		stray += int(light != _world.sun and not _world.lamps.has(light))
	_check(stray == 0 and _world.lamps.size() >= 6 and _world.lamps.size() <= 8, "every light in the park goes through the lamp budget (%d)" % _world.lamps.size())
	_world.set_time_of_day("night")
	var lit := _world.lamps.filter(func(lamp: Light3D) -> bool: return lamp.light_energy > 0.0).size()
	var shadowed := _world.lamps.filter(func(lamp: Light3D) -> bool: return lamp.shadow_enabled).size()
	_check(lit > 0 and lit <= 8 and shadowed <= 2, "at night at most eight lamps are lit and two cast shadows")
	_check(float(_world._life.glow_paint.get_shader_parameter("glow")) > 1.0, "the wheel's bulbs and cabin windows light up at night")
	_world.set_time_of_day("noon")
	_check(_world.lamps.all(func(lamp: Light3D) -> bool: return lamp.light_energy == 0.0) and float(_world._life.glow_paint.get_shader_parameter("glow")) < 0.1,
		"by day every lamp and bulb is off")
	var island := {"sky": Color.WHITE, "fog": Color.WHITE, "ambient": Color.WHITE, "ambient_energy": 1.0, "glow": 0.0}
	_check(_world._air("night", island).sky != _world._air("noon", island).sky, "the park's sky turns deep blue after dark")


func _check_life() -> void:
	var life: Life = _world._life
	var nodes := _world.find_children("*", "Node", true, false).size()
	var materials: int = _world.material_cache.size()
	var angle := life.wheel_angle()
	var kite := life.kite_position(0)
	var cloud := life.cloud_position(1)
	await _frames(60)
	_check(life.wheel_angle() != angle and absf(angle_difference(angle, life.wheel_angle())) < 0.2, "the wheel turns slowly")
	_check(life.cloud_position(1).distance_to(cloud) > 0.05, "clouds drift past")
	var moved := (life.cloud_position(1) - cloud)
	_check(Vector2(moved.x, moved.z).normalized().dot(Vector2(WIND.x, WIND.z)) > 0.95, "clouds drift downwind")
	var high := 0
	var low := 0
	for index in Life.DRIFT_CLOUDS:
		var at := life.cloud_position(index)
		if at.y > 1.6: high += 1
		if at.y < 1.1: low += 1
	_check(high >= 3 and low >= 6, "clouds pass at walkway height and below the decks (%d high, %d low)" % [high, low])
	_check(life.kite_position(0).distance_to(kite) > 0.01, "the kites ride the wind")
	for index in Life.KITES.size():
		var reel: Vector3 = _world._scenery.kite_reels[index]
		var flown := life.kite_position(index) - reel
		_check(flown.y > 3.5 and Vector3(flown.x, 0, flown.z).dot(WIND) > 3.0, "kite %d flies high and downwind of its reel" % index)
	for index in Life.CABINS:
		var cabin := life.cabin_position(index)
		var hub := World.WHEEL + Vector3(0, Scenery.HUB_HEIGHT, 0)
		_check(absf(cabin.distance_to(hub) - Scenery.WHEEL_RADIUS) < 0.01, "cabin %d rides the rim" % index)
	var flags := _world.get_node_or_null("Scenery_sky-flags") as MultiMeshInstance3D
	var placed: Array[Transform3D] = _world._kit.batch("sky-flags", null, null).transforms
	_check(flags != null and flags.multimesh.instance_count == placed.size() and placed.size() >= 8, "wind flags line the bridge and the kite mast")
	if flags != null:
		var downwind := true
		for place: Transform3D in placed:
			downwind = downwind and place.basis.x.normalized().dot(WIND) > 0.95
		_check(downwind, "every wind flag points the way the wind blows")
		var shader := (flags.material_override as ShaderMaterial).shader
		_check(shader.code.contains("wind_gust"), "the flags flutter harder in the island's gusts")
	# A push spins the wheel faster; a tug and the kites answer too.
	angle = life.wheel_angle()
	await _frames(30)
	var calm := absf(angle_difference(angle, life.wheel_angle()))
	_check(_world.push_wheel().contains("摩天輪"), "the wheel answers a push")
	angle = life.wheel_angle()
	await _frames(30)
	_check(absf(angle_difference(angle, life.wheel_angle())) > calm * 2.0, "a push turns the wheel faster")
	var before := life.kite_position(1)
	_check(_world.fly_kites().contains("風箏"), "the kite terrace answers")
	await _frames(90)
	_check(life.kite_position(1).y > before.y + 0.3, "flown higher, the kites climb")
	_check(_world.tug_balloon().contains("熱氣球") and _world.take_photo().contains("雲霄攝影點"), "the balloon and the photo point answer")
	await _frames(2)
	_check((_world.get_node("SkyCameraFlash") as MeshInstance3D).visible, "the camera flashes")
	# Reduced motion: one still frame.
	_world.apply_settings({"reduced_motion": true})
	await _frames(4)
	angle = life.wheel_angle()
	var held := life.kite_position(2)
	var balloon := life.balloon_position()
	var drift := life.cloud_position(3)
	await _frames(30)
	_check(life.wheel_angle() == angle and life.kite_position(2) == held and life.balloon_position() == balloon and life.cloud_position(3) == drift,
		"nothing moves under reduced motion")
	_check(float(_world._scenery.flag_material.get_shader_parameter("motion")) == 0.0 and float(_world._scenery.cloud_sea.get_shader_parameter("motion")) == 0.0,
		"reduced motion steadies the flags and the cloud sea")
	_world.apply_settings({"reduced_motion": false})
	for phase: String in ["dusk", "night", "dawn", "noon"]:
		_world.set_time_of_day(phase)
	await _frames(20)
	_check(_world.find_children("*", "Node", true, false).size() == nodes and _world.material_cache.size() == materials,
		"the living park reuses its nodes and materials through motion settings and time of day")


## A step off any deck is caught: the walker stays on the deck it stood on,
## at that deck's height, with a puff of cloud; a walker found off every deck
## goes back to the last safe spot.
func _check_edges() -> void:
	var puffed := 0
	for spec: Array in [["isle1", Vector2(-1, 0)], ["kite", Vector2(0, 1)], ["photo", Vector2(1, 0)], ["isle4", Vector2(0, -1)]]:
		var entry := World.pad(spec[0])
		var out: Vector2 = spec[1]
		var start: Vector2 = (entry.centre as Vector2) + out * (entry.radius as Vector2) * 0.55
		_place(Vector3(start.x, entry.y, start.y))
		await _frames(6)
		var target := (entry.centre as Vector2) + out * ((entry.radius as Vector2) + Vector2(3, 3))
		await _walk(target, 200)
		var at := _world.player_spot()
		_check(World.in_pad(entry, Vector2(at.x, at.z)) and absf(at.y - float(entry.y)) < 0.12 and _world.player.is_on_floor(),
			"walking off the %s edge leaves the walker safely on it" % spec[0])
		puffed += int(_world._life.catching())
	_check(puffed >= 3, "a caught step shows a puff of cloud (%d of 4)" % puffed)
	var safe := _world.last_safe_position()
	_world.player.position = Vector3(0.0, -3.0, 0.0)
	_world._constrain_player(Vector3(0.0, 1.0, 0.0))
	_check(_world.player.position.is_equal_approx(safe) and _world.player.velocity == Vector3.ZERO, "a walker off every deck goes back to the last safe spot")
	await _frames(4)


## Every interaction point and every kept site's playing spot can be reached on
## foot from the gate plaza, around every booth, mast, frame and sign.
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
	for target: Array in targets:
		var at: Vector3 = target[1]
		var cell := Vector2i(((Vector2(at.x, at.z) - bounds.position) / CELL).round())
		var reached := false
		for dz in range(-2, 3):
			for dx in range(-2, 3):
				var near := cell + Vector2i(dx, dz)
				if near.x >= 0 and near.y >= 0 and near.x < columns and near.y < rows and seen[near.y * columns + near.x] == 1: reached = true
		_check(reached, "%s can be walked to from the gate plaza" % target[0])


func _check_map() -> void:
	var snapshot := _world.map_snapshot()
	_check(snapshot.region == "sky" and snapshot.areas.size() == World.PADS.size() and snapshot.links.size() == World.LINKS.size() and snapshot.sites.size() == 12
		and snapshot.points.size() == _world.points.size(), "the plan lists the decks, links, stand sites and points")
	for area: Dictionary in snapshot.areas:
		_check(World.BOUNDS.encloses(area.rect), "the plan keeps %s inside the park" % area.id)
	var map := MapPanel.new()
	map.setup(snapshot)
	root.add_child(map)
	var locations := map.find_child("SkyMapLocations", true, false)
	_check(map.find_child("SkyMapTerrain", true, false) != null and locations != null and locations.get_child_count() == _world.points.size()
		and map.snapshot.player == _world.player.position, "map shows all locations and the real player")
	snapshot.areas[0].label = "missing"
	_check(_world.map_snapshot().areas[0].label == "摩天輪", "map snapshot is detached from world data")
	map.free()


## The centre line of the link between two decks, as walking waypoints.
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
		"actual point, breadcrumb and deck height agree on " + id)


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
