extends SceneTree
## The underground theatre standing alone: the islet and the theatre far below
## it, the passages between them (a short fade each way), both levels' floors
## joined by slopes with no jump anywhere, a step off an edge held back, the
## eight kept stand sites, every interaction point reached on foot, the show
## (curtains that open as the walker comes near, a spotlight that follows,
## costumes, band, petals), the house lights dimming in the seats, lamps within
## budget, the scene standards on both levels and a truthful plan of each.

const World = preload("res://game/world/theatre_world.gd")
const Scenery = preload("res://game/world/theatre_scenery.gd")
const Life = preload("res://game/world/theatre_life.gd")
const MapPanel = preload("res://game/ui/harbor_map_panel.gd")
const SaveGuard = preload("res://game/core/test_save_guard.gd")
const SceneStandards = preload("res://game/world/scene_standards.gd")
const RegionRoutes = preload("res://game/core/region_routes.gd")
const DistrictSites = preload("res://game/world/district_sites.gd")
const IslandShape = preload("res://game/world/island_shape.gd")
const LANDMARKS := ["TheatreSurface", "TheatreUnderground", "TheatreBay", "TheatreIslet0", "TheatreIsletStructure", "TheatreFloor", "TheatreMarquee",
	"TheatreMarqueeLamp", "TheatreCavern", "TheatreStructure", "TheatreCurtain0", "TheatreCurtain1", "TheatreSpotlight", "TheatreSpotPool",
	"TheatreBand", "TheatrePetals", "TheatreCostume0", "TheatrePhotoSpot", "TheatreFade"]
const MOVE := ["move_left", "move_right", "move_up", "move_down"]
const CELL := 0.25
## The lowest thing on the island (the beach's foot under the sea); the
## theatre's camera must look out from below it, so it never sees the island.
const ISLAND_FLOOR := -1.0

var _world: World
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if not SaveGuard.validate_save_path(OS.get_environment("SNAPLAND_SAVE_PATH"), OS.get_user_data_dir()).is_empty():
		push_error("Theatre world test requires a private save.")
		quit(1)
		return
	_check_site_data()
	_world = World.new()
	root.add_child(_world)
	await _frames(5)
	_check(_world.coastal_play == null and _world.npc_activity == null, "the theatre does not inherit Welcome activities")
	_check(_world.current_area == "劇場入口" and _world.player.is_on_floor() and not _world.is_underground(), "spawn lands on the islet plaza at the bridge's foot")
	_check(_node("TheatreSurface").visible and not _node("TheatreUnderground").visible, "on the islet only the islet is shown")
	_check_landmarks()
	_check_plan()
	_check_sites()
	_check_reach(false, World.ENTRY)
	_check_reach(true, World.DOWN_ARRIVAL)
	var audit := SceneStandards.audit(_world, "theatre")
	for rule: String in SceneStandards.RULES:
		_check((audit[rule] as Array).is_empty(), "the islet meets the scene standard '%s': %s" % [rule, str(audit[rule])])
	var island_air: Dictionary = _world.air_target
	await _reach(_route("landing", "islet") + [Vector2(World.TICKET_POINT.x, World.TICKET_POINT.z)], "theatre:ticket", "劇場入口", World.ISLET_Y)
	_check(_world.read_programme().contains("相冊"), "the ticket booth hands out the programme")
	await _descend()
	_check_air(island_air)
	var below_audit := SceneStandards.audit(_world, "theatre")
	for rule: String in SceneStandards.RULES:
		_check((below_audit[rule] as Array).is_empty(), "the theatre meets the scene standard '%s': %s" % [rule, str(below_audit[rule])])
	_check_lamps()
	# Up the corridor to the costumes, through the door into the stalls, down into the pit.
	_check(_world._life.curtain_open() == 0.0, "the curtain is shut while the walker is backstage")
	await _reach([Vector2(-24.0, 12.0), Vector2(World.COSTUME_POINT.x, World.COSTUME_POINT.z)], "theatre:costumes", "後台走廊", World.FLOOR)
	var corridor_light: float = _world.environment.ambient_light_energy
	await _reach([Vector2(-24.0, 6.1)] + _route("corridor", "stalls") + [Vector2(-20.2, 5.1), Vector2(-10.5, 5.1)] + _route("stalls", "pit") + [Vector2(World.PIT_POINT.x, World.PIT_POINT.z)],
		"theatre:pit", "樂池", World.FLOOR - 0.4)
	await _frames(120)
	_check(_world.house_darkness() > 0.95 and _world.environment.ambient_light_energy < corridor_light - 0.2, "the house goes dark around the walker in the seats (%.2f to %.2f)" % [corridor_light, _world.environment.ambient_light_energy])
	_check(_world._life.curtain_open() > 0.95, "walking toward the stage draws the curtain open")
	# Up the stage stair to the spotlight, across to the dais.
	await _reach(_route("pit", "stalls") + [Vector2(-2.8, 5.0)] + _route("stalls", "stage", Vector2(-2.8, 0.0)) + [Vector2(World.SPOTLIGHT_POINT.x, World.SPOTLIGHT_POINT.z)],
		"theatre:spotlight", "舞台", World.FLOOR + 1.2)
	await _frames(40)
	var spot: Vector3 = _world._life.spot_target()
	_check(Vector2(spot.x, spot.z).distance_to(Vector2(World.SPOTLIGHT_POINT.x, World.SPOTLIGHT_POINT.z)) < 0.5, "the stage spot picks the walker up")
	await _reach([Vector2(-2.6, -6.0)] + _route("stage", "bow") + [Vector2(World.BOW_POINT.x, World.BOW_POINT.z)], "theatre:bow", "謝幕台", World.FLOOR + 1.7)
	await _check_life()
	await _check_edges()
	# Back through the house and out of the stage door.
	await _reach(_route("bow", "stage") + [Vector2(-16.8, -2.6)] + _route("stage", "stalls", Vector2(-16.8, 0.0)) + [Vector2(-20.2, 5.2), Vector2(-20.2, 6.1)] + _route("stalls", "corridor") + [Vector2(-24.8, 14.6)],
		"", "後台走廊", World.FLOOR)
	_check(_world._life.curtain_open() < 0.05, "the curtain closes again once the walker leaves the stage behind")
	await _ascend()
	_check_map()
	_world.free()
	for failure in _failures:
		push_error(failure)
	if _failures.is_empty():
		print("PASS: theatre islet and two levels, passages, slopes without jumps, kept stand sites, the show, house lights and truthful map")
	quit(int(not _failures.is_empty()))


func _node(name: String) -> Node:
	return _world.find_child(name, true, false)


## The district row: a claim over open water, a bridge that reaches island
## ground, a gate that counts down to 180 normal stickers.
func _check_site_data() -> void:
	_check(RegionRoutes.supports("theatre") and RegionRoutes.threshold("theatre") == 180 and RegionRoutes.counts_down("theatre") and RegionRoutes.ORDER.has("theatre"),
		"the theatre opens at 180 normal stickers and its gate counts down")
	var claim := DistrictSites.world_rect("theatre", "claim")
	var dry := 0
	for row in 31:
		for column in 35:
			dry += int(IslandShape.contains(claim.position + Vector2(column, row) * Vector2(claim.size.x / 34.0, claim.size.y / 30.0)))
	_check(dry == 0, "the theatre's claim lies wholly over the bay (%d land samples)" % dry)
	var strip := DistrictSites.world_rect("theatre", "approach")
	_check(IslandShape.contains(Vector2(strip.end.x - 0.4, strip.get_center().y), IslandShape.WALK_MARGIN), "the bridge lands on island ground beyond the claim")
	# The follow camera looks down; nothing above the top of its view (10.5 m up the
	# view from a camera 16.5 m over the walker) can ever be seen.
	_check(World.FLOOR + 1.0 + World.CAMERA_OFFSET.y + 10.5 + 2.0 < ISLAND_FLOOR, "the theatre lies deep enough that its camera never sees the island")


func _check_landmarks() -> void:
	for landmark: String in LANDMARKS:
		_check(_node(landmark) != null, "the theatre has its %s" % landmark)
	var bay := _node("TheatreBay") as MeshInstance3D
	_check(bay != null and (bay.mesh as PlaneMesh).size.x >= World.BOUNDS.size.x + 62.0 and bay.position.y < World.ROCK_Y - 0.3, "standing alone, water runs past everything the camera can show")
	var cavern := _node("TheatreCavern") as MeshInstance3D
	_check(cavern != null and (cavern.mesh as PlaneMesh).size.x >= World.BOUNDS.size.x + 62.0 and cavern.position.y < World.FLOOR - 0.5, "the cavern floor runs past everything the camera can show below")
	_check((_node("TheatreMarquee") as Label3D).text == "地底惡魔劇場", "the marquee carries the theatre's name")
	_check(Scenery.playbill_text(179, 180).contains("還差 1 張") and Scenery.playbill_text(180, 180).contains("請進") and (_node("TheatrePlaybill") as Label3D).text.contains("180 張"),
		"the playbill at the bridge counts down the cards still missing")
	for area: Dictionary in World.AREAS:
		if area.id == "entrance": continue
		var sign := _node("TheatreSign_" + String(area.id)) as Label3D
		_check(sign != null and sign.text == area.label, "%s has its sign" % area.label)
	# Every region lends the set something: four painted flats and the island's own props.
	var lent := {}
	for spec: Array in Scenery.SET_PROPS: lent[spec[1]] = true
	_check(lent.size() >= 8 and Scenery.FLATS.size() == 4, "the set is built from the regions' signature objects (%d regions lend props)" % lent.size())


## Floors never overlap at different heights, every slope is gentle and meets
## its floors' edges at their own heights, the theatre stands at several
## heights and is far below the islet.
func _check_plan() -> void:
	var levels := {}
	for entry: Dictionary in World.PADS:
		if World.is_below(entry.y): levels[snappedf(entry.y, 0.01)] = true
		_check(World.BOUNDS.grow(-0.8).encloses(entry.rect), "%s stays inside the claim" % entry.id)
		for other: Dictionary in World.PADS:
			if other.id <= entry.id or is_equal_approx(other.y, entry.y) or World.is_below(other.y) != World.is_below(entry.y): continue
			_check(not (entry.rect as Rect2).grow(-0.05).intersects((other.rect as Rect2).grow(-0.05)), "%s and %s never overlap at different heights" % [entry.id, other.id])
	_check(levels.size() >= 5, "the theatre's floors stand at %d different heights" % levels.size())
	_check(World.pad("stage").y > World.pad("stalls").y + 1.0 and World.pad("tier2").y > World.pad("tier1").y and World.pad("tier1").y > World.pad("stalls").y
		and World.pad("pit").y < World.pad("stalls").y and World.pad("bow").y > World.pad("stage").y, "a raised stage, a sunken pit and stepped tiers")
	for link: Dictionary in World.links():
		var a: Vector2 = link.a
		var b: Vector2 = link.b
		var run := a.distance_to(b)
		var rise := absf(float(link.yb) - float(link.ya))
		var below := World.is_below(link.ya)
		_check(run > 1.5 and rad_to_deg(atan2(rise, run)) <= 16.0, "%s to %s is a gentle %s (%.0f degrees)" % [link.from, link.to, link.kind, rad_to_deg(atan2(rise, run))])
		_check(is_equal_approx(World.floor_height(a.lerp(b, 0.5), below), lerpf(link.ya, link.yb, 0.5)) or rise < 0.01, "%s to %s carries the walker between the floors' heights" % [link.from, link.to])
		_check(World.in_pad(World.pad(link.from), a + (a - b).normalized() * 0.2) and World.in_pad(World.pad(link.to), b + (b - a).normalized() * 0.2),
			"%s to %s lands on both floors" % [link.from, link.to])
	var bodies := (_node("TheatreFloor") as StaticBody3D).get_child_count()
	_check(bodies == World.PADS.size() + World.LINKS.size(), "every floor and slope stands on a physical floor (%d)" % bodies)


## Eight stand sites, four backstage and four in the stage's wings, wholly on
## their floors, clear of each other, the slopes, the landmarks and every
## interaction point; empty ones show a tag and are not interactive.
func _check_sites() -> void:
	_check(World.STAND_SITES.size() == 8, "eight stand sites are kept for the theatre's short games")
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
			on_floor = on_floor and is_equal_approx(World.floor_height(corner, true), stand.y) and _world._area_at_position(Vector3(corner.x, stand.y, corner.y)) == label
		_check(on_floor, "site %d stands wholly on a %s floor at its height" % [index, label])
		_check(_world._safe_footing(point) and _world._area_at_position(point) == label and not box.grow(0.25).has_point(Vector2(point.x, point.z))
			and is_equal_approx(point.y, World.floor_height(Vector2(point.x, point.z), true)), "site %d has a playable spot beside its counter" % index)
		for link: Dictionary in World.links():
			if not World.is_below(link.ya): continue
			var clear := true
			for step in 25:
				var spot := box.grow(0.6).position + box.grow(0.6).size * Vector2(float(step % 5) / 4.0, float(step / 5) / 4.0)
				clear = clear and World.link_along(link, spot) < 0.0
			_check(clear, "site %d keeps the way from %s to %s open" % [index, link.from, link.to])
		for other in World.STAND_SITES.size():
			if other == index: continue
			var neighbour: Vector3 = World.STAND_SITES[other].stand
			var other_box := Rect2(Vector2(neighbour.x, neighbour.z) - footprint * 0.5, footprint)
			_check(not box.grow(0.6).intersects(other_box), "site %d keeps its distance from site %d" % [index, other])
		for landmark: Vector3 in [World.COSTUME_RAIL, World.PHOTO_SPOT, World.STAGE_CENTRE, World.DOWN_ARRIVAL]:
			_check(not box.grow(1.0).has_point(Vector2(landmark.x, landmark.z)), "site %d keeps clear of the landmarks" % index)
		_check(Vector2(stand.x, stand.z).distance_to(Vector2(World.STAGE_CENTRE.x, World.STAGE_CENTRE.z)) > 4.0 or stand.z < -8.0, "site %d leaves the middle of the stage to the show" % index)
		for entry: Dictionary in _world.points:
			var at: Vector3 = entry.position
			if not World.is_below(at.y): continue
			_check(not box.grow(1.2).has_point(Vector2(at.x, at.z)) and Vector2(at.x, at.z).distance_to(Vector2(point.x, point.z)) >= 1.6,
				"site %d stays clear of %s" % [index, entry.id])
	_check(int(per_area.get("backstage", 0)) == 4 and int(per_area.get("stage", 0)) == 4, "four sites backstage and four in the stage's wings")
	var open := World.open_sites()
	_check(open.size() == 8 - World.ArcadeStands.rows("theatre").size(), "a site shows its tag until a game stands on it")
	_check(_world._scenery.site_tags.size() == open.size() and _world._scenery.site_tags.all(func(tag: Label3D) -> bool: return tag.text == "準備中"),
		"every empty site wears a 準備中 tag")
	_check(_world.points.size() == 6 + World.ArcadeStands.rows("theatre").size(), "empty sites are not interactive")


func _check_lamps() -> void:
	var stray := 0
	var below := 0
	for light: Light3D in _world.find_children("*", "Light3D", true, false):
		stray += int(light != _world.sun and not _world.lamps.has(light))
		below += int(light.has_meta(&"level"))
	_check(stray == 0 and below >= 8 and _world.lamps.size() <= 12, "every light in the theatre goes through the lamp budget (%d, %d below)" % [_world.lamps.size(), below])
	for phase: String in ["noon", "night"]:
		_world.set_time_of_day(phase)
		_world._update_lamp_selection(true)
		var lit := _world.lamps.filter(func(lamp: Light3D) -> bool: return lamp.light_energy > 0.0)
		var shadowed := _world.lamps.filter(func(lamp: Light3D) -> bool: return lamp.shadow_enabled).size()
		_check(lit.size() > 4 and lit.size() <= 8 and shadowed <= 2 and lit.all(func(lamp: Light3D) -> bool: return lamp.has_meta(&"level")),
			"below ground at %s the theatre's own lamps burn, at most eight lit and two shadowed" % phase)
		_check(_world._life.spot_light.light_energy > 0.0 and _world._life.spot_light.shadow_enabled, "at %s the stage spot shines and casts shadows" % phase)
	_world.set_time_of_day("noon")


## Below, the theatre has its own air: no sun, a dark sky and dim fill.
func _check_air(island_air: Dictionary) -> void:
	_check(_world.sun.light_energy < 0.01 and (_world.environment.background_color as Color).get_luminance() < 0.05
		and _world.environment.ambient_light_energy < float(island_air.ambient_energy) + float(island_air.sun_energy), "underground there is no sun, the air is dark and the fill is less than daylight (sun %.2f, fill %.2f)"
		% [_world.sun.light_energy, _world.environment.ambient_light_energy])
	_check((island_air.sky as Color) != _world._air("noon", island_air).sky, "the islet and the theatre have different air")


## Walk off the foot of the grand stair: the screen fades, the walker lands on
## the theatre's level backstage, the level swaps, all in under a second.
func _descend() -> void:
	await _walk(Vector2(World.STAIR_X, 0.4))
	await _walk(Vector2(World.STAIR_X, -1.4))
	var faded := 0.0
	var ticks := 0
	Input.action_press("move_up", 1.0)
	while not _world.is_underground() and ticks < 600:
		await physics_frame
		ticks += 1
		faded = maxf(faded, _world._life.fade_amount())
	Input.action_release("move_up")
	var started := ticks
	while _world.is_passing() and ticks < 900:
		await physics_frame
		ticks += 1
	var spot := _world.player_spot()
	_check(_world.is_underground() and World.is_below(spot.y) and _world._area_at_position(spot) == "後台走廊" and absf(spot.y - World.FLOOR) < 0.15,
		"walking off the foot of the grand stair takes the walker down to the backstage corridor")
	_check(faded > 0.9 and World.FADE_OUT + World.FADE_IN < 1.0 and ticks - started < 60, "the way down is a short, clear fade (%.2f)" % faded)
	_check(not _node("TheatreSurface").visible and _node("TheatreUnderground").visible, "below ground only the theatre is shown")
	await _frames(6)


func _ascend() -> void:
	Input.action_press("move_down", 1.0)
	var ticks := 0
	while _world.is_underground() and ticks < 600:
		await physics_frame
		ticks += 1
	Input.action_release("move_down")
	while _world.is_passing() and ticks < 900:
		await physics_frame
		ticks += 1
	await _frames(6)
	var spot := _world.player_spot()
	_check(not _world.is_underground() and _world._area_at_position(spot) == "劇場入口" and _node("TheatreSurface").visible and not _node("TheatreUnderground").visible
		and _world.sun.light_energy > 0.1, "out through the stage door the walker is back on the islet under the sky")


func _check_life() -> void:
	var life: Life = _world._life
	var nodes := _world.find_children("*", "Node", true, false).size()
	var materials: int = _world.material_cache.size()
	_check(_world.rummage_costumes().contains("戲服") and _world.costume_index() == 0, "the costume rail answers a rummage")
	_check(_world.strike_up().contains("樂池"), "the pit strikes up")
	_check(_world.take_spotlight().contains("聚光燈"), "the spotlight flares")
	_check(_world.practise_bow().contains("謝幕"), "the dais answers a bow")
	var swing := 0.0
	var lift := 0.0
	var showered := false
	for frame in 50:
		await physics_frame
		swing = maxf(swing, absf(life.costume_swing()))
		lift = maxf(lift, life.band_lift())
		showered = showered or life.petals_falling()
	_check(swing > 0.2 and lift > 0.05 and showered, "costumes swing out (%.2f), the band hops (%.2f) and petals fall" % [swing, lift])
	# Reduced motion: one still frame.
	_world.apply_settings({"reduced_motion": true})
	await _frames(4)
	_world.rummage_costumes()
	_world.strike_up()
	_world.practise_bow()
	await _frames(20)
	_check(life.costume_swing() == 0.0 and absf(life.band_lift()) < 0.001 and not life.petals_falling()
		and float(life.beam_material.get_shader_parameter("motion")) == 0.0, "nothing moves under reduced motion (%.2f, %.2f, %s)" % [life.costume_swing(), life.band_lift(), life.petals_falling()])
	_world.apply_settings({"reduced_motion": false})
	for phase: String in ["dusk", "night", "dawn", "noon"]:
		_world.set_time_of_day(phase)
	await _frames(60)
	_check(_world.find_children("*", "Node", true, false).size() == nodes and _world.material_cache.size() == materials,
		"the living theatre reuses its nodes and materials through motion settings and time of day")


## A step off a floor's edge is held back: the walker stays on the floor it
## stood on, at that floor's height; a walker found off every floor goes back
## to the last safe spot.
func _check_edges() -> void:
	for spec: Array in [["bow", Vector2(1, 0), Vector2(3.6, -6.0)], ["stage", Vector2(0, 1), Vector2(-12.0, -2.6)], ["tier2", Vector2(0, 1), Vector2(-6.0, 15.8)]]:
		var entry := World.pad(spec[0])
		var start: Vector2 = spec[2]
		_place(Vector3(start.x, entry.y, start.y))
		await _frames(6)
		await _walk(start + (spec[1] as Vector2) * 6.0, 200)
		var at := _world.player_spot()
		_check(World.in_pad(entry, Vector2(at.x, at.z)) and absf(at.y - float(entry.y)) < 0.12 and _world.player.is_on_floor(),
			"walking off the %s edge leaves the walker safely on it" % spec[0])
	var safe := _world.last_safe_position()
	_world.player.position = Vector3(-10.0, World.FLOOR - 3.0, -20.0)
	_world._constrain_player(Vector3(-10.0, World.FLOOR + 1.0, -20.0))
	_check(_world.player.position.is_equal_approx(safe) and _world.player.velocity == Vector3.ZERO, "a walker off every floor goes back to the last safe spot")
	_place(Vector3(World.BOW_POINT.x, World.BOW_POINT.y, World.BOW_POINT.z))
	await _frames(6)


## Every interaction point and every kept site's playing spot on a level can be
## reached on foot from that level's arrival, around every booth, seat row and sign.
func _check_reach(below: bool, start_at: Vector3) -> void:
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
	var level_y := World.FLOOR if below else World.ISLET_Y
	for row in rows:
		for column in columns:
			var spot := bounds.position + Vector2(column, row) * CELL
			if not _world._safe_footing(Vector3(spot.x, level_y, spot.y)): continue
			probe.transform = Transform3D(Basis.IDENTITY, Vector3(spot.x, World.floor_height(spot, below) + 0.8, spot.y))
			if space.intersect_shape(probe, 1).is_empty(): open[row * columns + column] = 1
	var start := Vector2i(((Vector2(start_at.x, start_at.z) - bounds.position) / CELL).round())
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
	for point: Dictionary in _world.points:
		if World.is_below((point.position as Vector3).y) == below: targets.append([point.id, point.position])
	if below:
		for index in World.STAND_SITES.size(): targets.append(["site %d" % index, World.STAND_SITES[index].point])
		targets.append(["the stage door", Vector3(-24.8, World.FLOOR, World.ASCENT_Z + 0.3)])
	else:
		targets.append(["the foot of the grand stair", _world.passage_entrance() + Vector3(0, 0, -0.4)])
	for target: Array in targets:
		var at: Vector3 = target[1]
		var cell := Vector2i(((Vector2(at.x, at.z) - bounds.position) / CELL).round())
		var reached := false
		for dz in range(-2, 3):
			for dx in range(-2, 3):
				var near := cell + Vector2i(dx, dz)
				if near.x >= 0 and near.y >= 0 and near.x < columns and near.y < rows and seen[near.y * columns + near.x] == 1: reached = true
		_check(reached, "%s can be walked to on its level" % target[0])


func _check_map() -> void:
	var above := _world.map_snapshot()
	_check(above.region == "theatre" and not above.below and above.areas.size() == 3 and above.links.size() == 3 and above.sites.is_empty()
		and above.points.size() == 2, "the islet's plan shows the landing, the plaza, the stairs, the bridge and its two points")
	_place(World.DOWN_ARRIVAL)
	var snapshot := _world.map_snapshot()
	_check(snapshot.below and snapshot.areas.size() == 7 and snapshot.links.size() == World.LINKS.size() - 2 and snapshot.sites.size() == 8
		and snapshot.points.size() == 4, "the theatre's plan lists its floors, slopes, stand sites and points")
	for area: Dictionary in snapshot.areas:
		_check(World.BOUNDS.encloses(area.rect) and float(area.y) > -1.0 and float(area.y) < 3.0, "the plan keeps %s inside the claim at a printable height" % area.id)
	var map := MapPanel.new()
	map.setup(snapshot)
	root.add_child(map)
	var locations := map.find_child("TheatreMapLocations", true, false)
	_check(map.find_child("TheatreMapTerrain", true, false) != null and locations != null and locations.get_child_count() == snapshot.points.size()
		and map.snapshot.player == _world.player.position, "map shows the level's locations and the real player")
	snapshot.areas[0].label = "missing"
	_check(_world.map_snapshot().areas[0].label == "後台走廊", "map snapshot is detached from world data")
	map.free()


## The centre line of the slope between two floors, as walking waypoints.
func _route(from: String, to: String, through := Vector2.INF) -> Array[Vector2]:
	for link: Dictionary in World.links():
		var a: Vector2 = link.a
		var b: Vector2 = link.b
		if link.from == to and link.to == from:
			var swap := a
			a = b
			b = swap
		elif not (link.from == from and link.to == to):
			continue
		if through.is_finite() and Vector2(a.x, 0).distance_to(Vector2(through.x, 0)) > 1.0: continue
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
		_check(await _walk(step), "physical walking route reaches %s (stopped at %s)" % [step, _world.player.position])
	_check((id.is_empty() or _world.nearest.get("id") == id) and _world.current_area == area and absf(_world.player.position.y - height) < 0.12,
		"actual point, breadcrumb and floor height agree on " + (id if not id.is_empty() else area))


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
