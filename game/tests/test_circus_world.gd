extends SceneTree

const World = preload("res://game/world/circus_world.gd")
const MapPanel = preload("res://game/ui/harbor_map_panel.gd")
const SaveGuard = preload("res://game/core/test_save_guard.gd")
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
	_check(_world.get_node_or_null("CircusTentBackdrop") != null and _world.coastal_play == null
		and _world.npc_activity == null, "original tent art loads without inheriting Welcome activities")
	_check(_world.current_area == "馬戲團入口" and _world.player.is_on_floor(), "spawn lands on the physical entry")
	_check(_world.map_snapshot().areas.size() == 5 and _world.points.size() == 5,
		"five real places describe the room floor plan")
	for room: Dictionary in _world.map_snapshot().areas:
		var floor_mesh := _world.get_node_or_null("CircusFloor_" + String(room.id)) as MeshInstance3D
		var footprint: Rect2 = room.rect
		_check(floor_mesh != null and floor_mesh.mesh is BoxMesh and _world.map_snapshot().bounds.encloses(footprint),
			"chart has the actual physical floor for " + room.id)
		if floor_mesh != null and floor_mesh.mesh is BoxMesh:
			var size: Vector3 = (floor_mesh.mesh as BoxMesh).size
			_check(Vector2(size.x, size.z).is_equal_approx(footprint.size), "chart and floor widths match each other")

	await _reach([Vector2(0, 4.65), Vector2(-8.1, 4.65), Vector2(-8.1, 0.85)], "circus:mirrors", "鏡廊")
	await _reach([Vector2(-4.25, 0.85), Vector2(-4.25, -6.40), Vector2(0, -6.40), Vector2(0, -8.80)],
		"circus:mats", "砲彈安全墊")
	await _reach([Vector2(0, 0.20)], "circus:auditorium", "觀眾席")
	await _reach([Vector2(0, 4.06), Vector2(8.1, 4.06), Vector2(8.1, 0.75)], "circus:shadow", "影子台")
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
