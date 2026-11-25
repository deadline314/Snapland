extends SceneTree

const World = preload("res://game/world/toy_world.gd")
const MapPanel = preload("res://game/ui/harbor_map_panel.gd")
const SaveGuard = preload("res://game/core/test_save_guard.gd")
const MOVES := ["move_left", "move_right", "move_up", "move_down"]

var _world: World
var _errors: Array[String] = []
var _checks := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if not SaveGuard.validate_save_path(OS.get_environment("SNAPLAND_SAVE_PATH"), OS.get_user_data_dir()).is_empty():
		push_error("Toy Town test requires a private save.")
		quit(1)
		return
	_world = World.new()
	root.add_child(_world)
	await _frames(5)
	_check(_world.get_node_or_null("ToyWorkshopMural") != null and _world.coastal_play == null
		and _world.npc_activity == null, "Toy Town loads its original workshop and its own activities only")
	_check(_world.current_area == "玩具城入口" and _world.player.is_on_floor(), "grounded arrival at the free return")
	await _reach([Vector2(0, 4.45), Vector2(-8, 4.45), Vector2(-8, 2.2)], "toy:blocks", "積木街")
	await _reach([Vector2(-7.6, -6.95)], "toy:repair", "維修台")
	await _reach([Vector2(-4.8, -6.95), Vector2(0, -6.95), Vector2(0, -7.6)], "toy:tower", "發條鐘樓")
	var hour := _world._clock_hour.rotation.z
	_world.set_time_of_day("dusk")
	_check(_world.tower_clock() == "18:15" and _world._clock_hour.rotation.z != hour, "clock face follows the actual selected park phase")
	await _reach([Vector2(0, 4.45), Vector2(6.3, 4.45), Vector2(6.3, 2.25)], "toy:switch", "車站岔道")
	await _reach([Vector2(9.5, 2.25)], "toy:train", "車站岔道")
	await _check_train()
	_check_map()
	await _reach([Vector2(9.5, 4.45), Vector2(0, 4.45), Vector2(0, 7.65)], "region:welcome", "玩具城入口")
	var last: Vector3 = _world.player.position
	_world.player.position = Vector3(0, World.GROUND_Y, 10.2)
	_world._constrain_player(last)
	_check(_world.player.position.is_equal_approx(last) and _world.player.velocity == Vector3.ZERO,
		"the foundation does not extend the playable border")
	_world.player.position = Vector3(-24, -2, -15)
	_world._constrain_player(_world.player.position)
	_check(_world.player.position == World.ENTRY and _world.player.velocity == Vector3.ZERO, "invalid footing safely recovers")
	_world.free()
	for error in _errors:
		push_error(error)
	if _errors.is_empty():
		print("PASS: toy town walking routes, physical rail branches, reversible controls and truthful map")
	print("%d checks, %d failures" % [_checks, _errors.size()])
	quit(int(not _errors.is_empty()))


func _check_train() -> void:
	var origin: Dictionary = _world.train_state()
	var rail := _world.get_node("ToyRailDemonstration") as Node3D
	_check(origin.at_dock and origin.branch == 0 and rail.get_node("ClockworkLocomotive").global_position == origin.position,
		"the actual carriage starts parked on the default route")
	_check(rail.find_children("*", "CollisionObject3D", true, false).is_empty(), "only the static table protects the demonstration")
	var count := rail.find_children("*", "", true, false).size()
	_check(_world.switch_tracks().contains("右線") and _world.train_state().branch == 1, "dock switch selects the real right rail")
	_check(_world.operate_train().contains("開始") and _world.train_state().running, "start moves the same carriage")
	await _frames(74)
	_check(_world.train_state().distance > 1.10, "ordinary train crosses the actual fork from dock")
	_world.operate_train()
	var paused := _world.train_state()
	await _frames(30)
	_check(not paused.running and not paused.at_dock and _world.train_state().position == paused.position, "pause holds the exact point")
	_check(_world.switch_tracks().contains("回站") and _world.train_state().branch == 1, "moving or paused train cannot change physical path")
	_world.operate_train()
	for index in 300:
		if not _world.train_state().outbound:
			break
		await process_frame
	var right := _world.train_state()
	_check(not right.outbound and right.position.x > origin.position.x + 1.7, "ordinary train visits the real right terminal")
	for index in 450:
		if _world.train_state().at_dock:
			break
		await process_frame
	_check(_world.train_state().at_dock and _world.train_state().position.is_equal_approx(origin.position), "train backs up to dock without teleporting")
	_world.apply_settings({"reduced_motion": true})
	_check(_world.switch_tracks().contains("左線"), "left route is selectable in reduced motion")
	var previous := 0.0
	for visit in 3:
		_world.operate_train()
		var state := _world.train_state()
		_check(state.distance > previous and not state.running, "reduced input shows each exact waypoint once")
		previous = state.distance
	var left := _world.train_state()
	_check(not left.outbound and left.position.x < origin.position.x - 1.5
		and is_equal_approx(left.distance, left.length), "second route reaches its distinct left terminal")
	await _frames(20)
	_check(_world.train_state().position == left.position, "reduced view is still at the chosen terminal")
	_world.operate_train()
	_check(_world.train_state().distance < left.distance and not _world.train_state().running, "next step backs down the same branch")
	var avatar: Vector3 = _world.player.position
	_world.reset_train()
	_check(_world.train_state().at_dock and _world.train_state().branch == 0 and _world.train_state().outbound
		and _world.player.position == avatar and rail.find_children("*", "", true, false).size() == count,
		"maintenance reset restores the same model, default switch and dock without touching the walker")


func _check_map() -> void:
	var snapshot := _world.map_snapshot()
	var map := MapPanel.new()
	map.setup(snapshot)
	root.add_child(map)
	var locations := map.find_child("ToyMapLocations", true, false)
	var status := map.find_child("ToyMapStatus", true, false) as Label
	_check(snapshot.region == "toy" and snapshot.player == _world.player.position and snapshot.points.size() == 6
		and snapshot.areas.size() == 5 and locations != null and locations.get_child_count() == 6 and status != null
		and status.text.contains("逐站") and map.find_child("ToyMapTerrain", true, false) != null,
		"shared map records real player, switches and stops")
	var tracks: Array = snapshot.tracks
	_check(tracks.size() == 2 and tracks[0][0] == tracks[1][0] and tracks[0][-1].x < tracks[1][-1].x,
		"route map has the shared physical fork and two distinct endpoints")
	for path: PackedVector2Array in tracks:
		for location in path:
			_check(snapshot.rail_table.has_point(location), "every rail appears inside the actual protected table")
	snapshot.areas[0].label = "changed"
	_check(_world.map_snapshot().areas[0].label == "玩具城入口", "map export cannot change world data")
	map.free()


func _reach(sequence: Array[Vector2], id: String, area: String) -> void:
	for location in sequence:
		_check(await _walk(location), "physical path reaches " + str(location))
	_check(_world.current_area == area and _world.nearest.get("id") == id, "real breadcrumb and interaction agree on " + area)


func _walk(destination: Vector2) -> bool:
	var start: Vector3 = _world.player.position
	var distance := Vector2(start.x, start.z).distance_to(destination)
	var limit := ceili(distance / World.AVATAR_RUN_SPEED * 60.0) + 100
	for tick in limit:
		var at: Vector3 = _world.player.position
		var offset := destination - Vector2(at.x, at.z)
		if offset.length() < 0.22:
			break
		var direction := offset.normalized()
		var inputs := [maxf(-direction.x, 0.0), maxf(direction.x, 0.0), maxf(-direction.y, 0.0), maxf(direction.y, 0.0)]
		for index in MOVES.size():
			if inputs[index] > 0.0:
				Input.action_press(MOVES[index], inputs[index])
			else:
				Input.action_release(MOVES[index])
		await physics_frame
	for action in MOVES:
		Input.action_release(action)
	await _frames(9)
	var end: Vector3 = _world.player.position
	return _world.player.is_on_floor() and Vector2(end.x, end.z).distance_to(destination) < 0.47


func _frames(count: int) -> void:
	for index in count:
		await physics_frame


func _check(valid: bool, message: String) -> void:
	_checks += 1
	if not valid:
		_errors.append(message)
