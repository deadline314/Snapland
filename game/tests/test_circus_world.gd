extends SceneTree

const World = preload("res://game/world/circus_world.gd")
const MapPanel = preload("res://game/ui/harbor_map_panel.gd")
const SaveGuard = preload("res://game/core/test_save_guard.gd")
const Scenery = preload("res://game/world/circus_scenery.gd")
const Life = preload("res://game/world/circus_life.gd")
const LANDMARKS := ["CircusMeadow", "CircusYard", "CircusCanvas", "CircusEntranceArch", "CircusRing", "CircusPaddedLanding",
	"CircusMirrors", "CircusMarqueeBulbs", "CircusStringLights", "CircusTrapeze", "CircusHoop0", "CircusBalloons", "CircusSpot0", "CircusSpot2"]
## The follow camera shows this much ground around the player; scenery must reach 12 m further.
const VIEW_REACH := 19.2 + 12.0
const MOVE := ["move_left", "move_right", "move_up", "move_down"]

var _world: World
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if not SaveGuard.validate_save_path(OS.get_environment("SNAPLAND_SAVE_PATH"), OS.get_user_data_dir()).is_empty():
		push_error("Circus world test requires a private save.")
		quit(1)
		return
	_world = World.new()
	root.add_child(_world)
	await _frames(5)
	_check(_world.coastal_play == null and _world.npc_activity == null, "the camp does not inherit Welcome activities")
	_check_landmarks()
	await _check_life()
	_check(_world.current_area == "馬戲團入口" and _world.player.is_on_floor(), "spawn lands on the physical entry")
	var initial_map: Dictionary = _world.map_snapshot()
	_check(initial_map.areas.size() == 5 and initial_map.points.size() == 8 + World.PITCH_GAMES.size()
		and _world._point_by_id("circus:story").get("position") == World.STORY_POINT,
		"five physical areas and the on-duty welcome station appear in the floor plan")
	_check(_world._point_by_id("game-049").get("position") == World.PHOTO_BOOTH_POINT
		and _world._area_at_position(World.PHOTO_BOOTH_POINT) == "馬戲團入口" and _world._safe_footing(World.PHOTO_BOOTH_POINT),
		"the photo booth game has a reachable stand in the entry foyer")
	_check(_world._point_by_id("game-050").get("position") == World.REFLECTION_POINT
		and _world._area_at_position(World.REFLECTION_POINT) == "鏡廊" and _world._safe_footing(World.REFLECTION_POINT),
		"the fake reflection game has a reachable stand in the mirror hall")
	for room: Dictionary in _world.map_snapshot().areas:
		var floor_mesh := _world.get_node_or_null("CircusFloor_" + String(room.id)) as MeshInstance3D
		var footprint: Rect2 = room.rect
		_check(floor_mesh != null and floor_mesh.mesh is BoxMesh and _world.map_snapshot().bounds.encloses(footprint),
			"chart has the actual physical floor for " + room.id)
		if floor_mesh != null and floor_mesh.mesh is BoxMesh:
			var size: Vector3 = (floor_mesh.mesh as BoxMesh).size
			_check(Vector2(size.x, size.z).is_equal_approx(footprint.size), "chart and floor widths match each other")

	await _reach([Vector2(0, 4.65), Vector2(-8.1, 4.65), Vector2(-8.1, 0.85)], "circus:mirrors", "鏡廊")
	await _reach([Vector2(-8.1, 4.85), Vector2(World.REFLECTION_POINT.x, World.REFLECTION_POINT.z)], "game-050", "鏡廊")
	await _reach([Vector2(-4.25, 0.85), Vector2(-4.25, -6.40), Vector2(0, -6.40), Vector2(0, -8.80)],
		"circus:mats", "砲彈安全墊")
	await _reach([Vector2(-6.4, -9.7)], "game-055", "砲彈安全墊")
	await _reach([Vector2(0, -8.8), Vector2(6.4, -9.7)], "game-053", "砲彈安全墊")
	await _reach([Vector2(0, -8.8), Vector2(0, 0.20)], "circus:auditorium", "觀眾席")
	await _reach([Vector2(0, 4.06), Vector2(8.1, 4.06), Vector2(8.1, 0.75)], "circus:shadow", "影子台")
	await _reach([Vector2(11.5, 0.75), Vector2(11.5, -2.8)], "game-057", "影子台")
	await _reach([Vector2(11.5, 0.75), Vector2(8.1, 0.75)], "circus:shadow", "影子台")
	await _reach([Vector2(8.1, 5.25), Vector2(10.6, 5.25)], "game-051", "影子台")
	await _reach([Vector2(8.1, 5.25), Vector2(8.1, 0.75)], "circus:shadow", "影子台")
	await _check_projection()
	var snapshot := _world.map_snapshot()
	var map := MapPanel.new()
	map.setup(snapshot)
	root.add_child(map)
	var locations := map.find_child("CircusMapLocations", true, false)
	_check(map.find_child("CircusMapTerrain", true, false) != null
		and locations != null and locations.get_child_count() == _world.points.size()
		and map.snapshot.player == _world.player.position, "map shows all locations and the real player")
	snapshot.areas[0].label = "missing"
	_check(_world.map_snapshot().areas[0].label == "馬戲團入口", "map snapshot is detached from world data")
	map.free()
	await _reach([Vector2(8.1, 4.65), Vector2(0, 4.65), Vector2(0, 7.8)], "region:welcome", "馬戲團入口")
	await _reach([Vector2(3.3, 7.9)], "game-052", "馬戲團入口")
	await _reach([Vector2(World.PHOTO_BOOTH_POINT.x, World.PHOTO_BOOTH_POINT.z)], "game-049", "馬戲團入口")
	var safe_at: Vector3 = _world.player.position
	_world.player.position = Vector3(0, World.GROUND_Y, 10.1)
	_world._constrain_player(safe_at)
	_check(_world.player.position.is_equal_approx(safe_at) and _world.player.velocity == Vector3.ZERO,
		"outside a room the body stops safely")
	_world.player.position = Vector3(3, -3, -20)
	_world._constrain_player(_world.player.position)
	_check(_world.player.position == World.ENTRY and _world.player.velocity == Vector3.ZERO,
		"an invalid floor safely restores entry")
	_world.free()
	for failure in _failures:
		push_error(failure)
	if _failures.is_empty():
		print("PASS: circus terrain, physical routes, reversible projection and truthful map")
	quit(int(not _failures.is_empty()))


func _check_landmarks() -> void:
	for landmark: String in LANDMARKS:
		_check(_world.get_node_or_null(landmark) != null, "the district has its %s" % landmark)
	var meadow := _world.get_node_or_null("CircusMeadow") as MeshInstance3D
	_check(meadow != null and meadow.mesh is PlaneMesh
		and (meadow.mesh as PlaneMesh).size.x >= World.BOUNDS.size.x + 2.0 * VIEW_REACH
		and (meadow.mesh as PlaneMesh).size.y >= World.BOUNDS.size.y + 2.0 * VIEW_REACH,
		"natural ground runs past everything the camera can show from any floor")
	_check(_world.ground_surface_y(Vector3(40, 0, 40)) == Scenery.MEADOW_Y and Scenery.MEADOW_Y < World.GROUND_Y - 0.02,
		"outside the floors the camp stands on the meadow, a clear step below them")
	var shapes := {}
	for mirror: Array in Scenery.WALL_MIRRORS + Scenery.HALL_MIRRORS:
		shapes[mirror[1]] = true
	_check(_world._scenery.glass.count == Scenery.WALL_MIRRORS.size() + Scenery.HALL_MIRRORS.size() and _world._scenery.glass.count >= 7
		and shapes.size() >= 3, "the gallery has at least seven reflecting mirrors in three or more shapes")
	var bends := {}
	for mirror: Array in Scenery.WALL_MIRRORS:
		bends[mirror[4]] = true
		_check(float(mirror[0]) > World.AREAS[1].rect.position.y and float(mirror[0]) < World.AREAS[1].rect.end.y
			and Scenery.WALL_MIRROR_X < World.BOUNDS.position.x, "a wall mirror lines the hall without standing on its floor")
	_check(bends.size() == Scenery.WALL_MIRRORS.size(), "every funhouse mirror bends its reflection differently")
	_check(World.PITCHES.size() == 10, "ten pitches are kept for the district's games")
	var taken: Dictionary = {}
	for stand: Dictionary in World.PITCH_GAMES:
		var entry: Vector3 = World.PITCHES[stand.pitch] + Vector3(0, 0, World.PITCH_REACH)
		_check(not taken.has(stand.pitch) and _world._point_by_id(stand.id).get("position") == entry and _world._safe_footing(entry)
			and _world.get_node_or_null("CircusCabinet_" + str(stand.title)) != null,
			"%s has its cabinet on pitch %d and a reachable point in front of it" % [stand.id, stand.pitch])
		taken[stand.pitch] = stand.id
	for index in range(World.PITCHES.size()):
		var pitch: Vector3 = World.PITCHES[index]
		var entry := pitch + Vector3(0, 0, World.PITCH_REACH)
		var clear := _world._safe_footing(entry) and _world._on_floor_plan(Vector2(pitch.x, pitch.z))
		for point: Dictionary in _world.points:
			if point.id == taken.get(index, ""):
				continue
			clear = (clear and Vector2(point.position.x - entry.x, point.position.z - entry.z).length() >= 1.6
				and Vector2(point.position.x - pitch.x, point.position.z - pitch.z).length() >= 1.2)
		for other: Vector3 in World.PITCHES:
			clear = clear and (other == pitch or other.distance_to(pitch) >= 1.8)
		_check(clear, "the pitch at %s has a reachable entry clear of every existing point" % pitch)
	# Every real light is in the lamp budget; only the two pool lights stay outside it.
	var stray := 0
	for light: Light3D in _world.find_children("*", "Light3D", true, false):
		stray += int(light != _world.sun and not _world.lamps.has(light))
	_check(_world.lamps.size() >= 8 and stray == _world._pools.size() and stray <= 2, "stage and street lights all go through the lamp budget")
	_world.set_time_of_day("night")
	var lit := _world.lamps.filter(func(lamp: Light3D) -> bool: return lamp.light_energy > 0.0).size()
	var shadowed := _world.lamps.filter(func(lamp: Light3D) -> bool: return lamp.shadow_enabled).size()
	_check(lit > 0 and lit <= 8 and shadowed <= 2, "at night at most eight lamps are lit and two cast shadows")
	_world.set_time_of_day("noon")
	_check(_world.lamps.all(func(lamp: Light3D) -> bool: return lamp.light_energy == 0.0), "by day every lamp is off")


func _place(at: Vector3) -> void:
	_world.player.position = at
	_world.player.velocity = Vector3.ZERO
	_world._sync_external_avatar_reposition()


func _check_life() -> void:
	var life: Life = _world._life
	var mirror: ShaderMaterial = _world._scenery.mirror_material
	var cloth: ShaderMaterial = _world.material_cache["circus:canvas"]
	var nodes := _world.find_children("*", "Node", true, false).size()
	var materials: int = _world.material_cache.size()
	var rest: Array[Vector3] = [life.rest_target(0), life.rest_target(1), life.rest_target(2)]
	await _frames(30)
	_check(not is_zero_approx(life.trapeze_angle()), "the trapeze swings")
	_check(life.spot_target(0).distance_to(rest[0]) > 0.02 and not life.in_ring and is_zero_approx(life.drum_roll),
		"the stage spots sweep the empty ring and the drum is quiet")
	_check(_world._scenery.chase_bulbs.get_shader_parameter("motion") == 1.0 and float(_world._scenery.chase_bulbs.get_shader_parameter("chase")) > 0.0
		and cloth.get_shader_parameter("motion") == 1.0 and mirror.get_shader_parameter("motion") == 1.0,
		"marquee bulbs chase, canvas stirs and the mirrors glint")
	_check(mirror.get_shader_parameter("walker") == _world.player.global_position and mirror.get_shader_parameter("walker_sprite") == _world.avatar.texture,
		"the mirrors reflect the sprite of the walker where the walker stands")
	# Stepping into the ring: every spot finds the walker and the drum rolls.
	_place(World.MATS + Vector3(0.8, 0, 0.6))
	await _frames(90)
	var found := life.in_ring and life.drum_roll > 0.95
	for index in range(3):
		found = found and Vector2(life.spot_target(index).x - _world.player.position.x, life.spot_target(index).z - _world.player.position.z).length() < 0.25
	_check(found, "in the ring the spots follow the walker and the drum rolls")
	_place(World.REFLECTION_POINT)
	await _frames(90)
	_check(not life.in_ring and is_zero_approx(life.drum_roll) and life.spot_target(0).distance_to(_world.player.position) > 5.0,
		"leaving the ring releases the spots and stops the drum")
	var tie: Vector3 = Life.BALLOONS[3][0]
	var away := Vector2(tie.x - World.REFLECTION_POINT.x, tie.z - World.REFLECTION_POINT.z).normalized()
	_check(life.balloon_lean(3).length() > 0.2 and life.balloon_lean(3).normalized().dot(away) > 0.95 and life.balloon_lean(0).is_zero_approx(),
		"the balloons beside the walker lean away while distant bunches hang straight")
	_check(mirror.get_shader_parameter("walker") == _world.player.global_position, "the reflection follows the walker to the mirror hall")
	# Reduced motion: one still pose, but the mirrors still show where the walker is.
	_place(World.MATS)
	await _frames(20)
	_check(life.in_ring, "the walker is back in the ring before motion is reduced")
	_world.apply_settings({"reduced_motion": true})
	await _frames(4)
	var held: Array[Vector3] = [life.spot_target(0), life.spot_target(1), life.spot_target(2)]
	_check(held == rest and is_zero_approx(life.trapeze_angle()) and is_zero_approx(life.drum_roll) and not life.in_ring
		and life.balloon_lean(3).is_zero_approx(), "reduced motion parks the spots, trapeze, drum and balloons")
	_check(_world._scenery.chase_bulbs.get_shader_parameter("motion") == 0.0 and _world._scenery.shimmer_bulbs.get_shader_parameter("motion") == 0.0
		and cloth.get_shader_parameter("motion") == 0.0 and mirror.get_shader_parameter("motion") == 0.0,
		"reduced motion steadies the bulbs, the canvas and the mirror glints")
	_place(World.REFLECTION_POINT)
	await _frames(30)
	var still: Array[Vector3] = [life.spot_target(0), life.spot_target(1), life.spot_target(2)]
	_check(still == held and life.balloon_lean(3).is_zero_approx() and is_zero_approx(life.trapeze_angle()),
		"nothing moves under reduced motion, even beside the walker")
	_check(mirror.get_shader_parameter("walker") == _world.player.global_position, "a still mirror keeps reflecting the walker")
	_world.apply_settings({"reduced_motion": false})
	await _frames(20)
	_check(not is_zero_approx(life.trapeze_angle()) and life.balloon_lean(3).length() > 0.05, "motion resumes when the setting is cleared")
	_check(_world.find_children("*", "Node", true, false).size() == nodes and _world.material_cache.size() == materials,
		"the living scenery reuses its nodes and materials")
	_place(World.ENTRY)
	await _frames(10)


func _check_projection() -> void:
	var initial: Vector3 = _world.projection_shadow_center()
	var stage := _world.get_node("CircusProjection")
	var stencil := stage.get_node("CutoutStencil") as MeshInstance3D
	var shadow := stage.get_node("ProjectedShadow") as MeshInstance3D
	var child_count := _world.find_children("*", "", true, false).size()
	var mesh_count_before := _world.mesh_count
	_check(stencil.mesh == shadow.mesh and shadow.scale.x > 1.4, "projection reuses a triangulated physical cutout at its projected scale")
	_check(_world.projection_side() == 0 and initial.x > World.SHADOW_STAGE.x and not _world.projection_is_moving(),
		"left lamp casts the moon to the right")
	var dim_before := _world.sun.light_energy
	_world.set_time_of_day("night")
	_check(_world.sun.light_energy != dim_before and _world.projection_shadow_center() == initial,
		"time palette changes without interfering with the projection")
	_check(_world.switch_projection().contains("右燈") and _world.projection_side() == 1 and _world.projection_is_moving(),
		"player switch safely begins one smooth movement")
	await _frames(26)
	var right_lamp_shadow := _world.projection_shadow_center()
	_check(right_lamp_shadow.x < World.SHADOW_STAGE.x and is_equal_approx(initial.z, right_lamp_shadow.z)
		and not _world.projection_is_moving(), "right lamp casts left and settles at the same screen")
	_world.switch_projection()
	_world.apply_settings({"reduced_motion": true})
	_check(not _world.projection_is_moving() and _world.projection_shadow_center() == initial,
		"enabling reduced motion settles a live transition at the target")
	for trial in 6:
		_world.switch_projection()
		_check(not _world.projection_is_moving(), "reduced switch lands immediately")
	_check(_world.projection_shadow_center() == initial and _world.mesh_count == mesh_count_before
		and _world.find_children("*", "", true, false).size() == child_count, "repeated previews return exactly and reuse their geometry")


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
