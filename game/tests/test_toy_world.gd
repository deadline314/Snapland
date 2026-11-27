extends SceneTree

const World = preload("res://game/world/toy_world.gd")
const Visit = preload("res://game/story/regional_visit.gd")
const Catalog = preload("res://game/core/game_catalog.gd")
const ArcadeStands = preload("res://game/world/arcade_stands.gd")
const MapPanel = preload("res://game/ui/harbor_map_panel.gd")
const SaveGuard = preload("res://game/core/test_save_guard.gd")
const Scenery = preload("res://game/world/toy_scenery.gd")
const Standards = preload("res://game/world/scene_standards.gd")
const MOVES := ["move_left", "move_right", "move_up", "move_down"]
const LANDMARKS := ["ToyLawn", "ToyClockHourHand", "ToyClockPendulum", "ToySpinningTop", "ToyCarousel", "ToyJackHead", "ToySoldiers",
	"ToyFloorPiano", "ToyGlassFloor", "ToyKite", "ToyMarbles", "ToyWindUpKeys", "ToyPinwheels", "ToyGears16", "ToyRailPlatform", "ToyPointsLever",
	"ToyClockSecondHand", "ToySignalArm0", "ToySignalArm1"]
## Half of what the follow camera shows on the ground, across and along its view.
const VIEW_HALF := Vector2(18.7, 19.2)

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
	_check(LANDMARKS.all(func(landmark: String) -> bool: return _world.get_node_or_null(landmark) != null)
		and _world.coastal_play == null and _world.npc_activity == null, "Toy Town builds its landmarks and its own activities only")
	_check(_world.current_area == "玩具城入口" and _world.player.is_on_floor(), "grounded arrival at the free return")
	_check_surround()
	await _frames(40)
	_check(_world._life.salute(0) > 0.9 and _world._life.salute(1) > 0.9 and _world._life.salute(4) == 0.0,
		"the two gate guards salute the arriving visitor while the far patrol marches on")
	await _check_arcade_stands()
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
	await _check_life()
	_world.free()
	for error in _errors:
		push_error(error)
	if _errors.is_empty():
		print("PASS: toy town walking routes, physical rail branches, reversible controls and truthful map")
	print("%d checks, %d failures" % [_checks, _errors.size()])
	quit(int(not _errors.is_empty()))


## Every delivered game has a stand the visitor can walk up to; coordinates live in the stand table.
func _check_arcade_stands() -> void:
	var delivered: Array = Catalog.definitions("toy")
	_check(ArcadeStands.rows("toy").size() == delivered.size(), "one entry stand per delivered Toy Town game")
	for definition: Dictionary in delivered:
		var point: Dictionary = _world._point_by_id(definition.id)
		var stand := _world.get_node_or_null("ArcadeStand_" + str(definition.id)) as MeshInstance3D
		_check(not point.is_empty() and stand != null and stand.find_children("*", "CollisionShape3D", true, false).size() == 1,
			str(definition.id) + " has a solid stand and an interaction point")
		if point.is_empty():
			continue
		var at: Vector3 = point.position
		_check(_world._safe_footing(at) and str(point.label).contains(str(definition.name)), str(definition.id) + " is entered from safe ground and named on its prompt")
		_check(await _walk(Vector2(0, 4.45)) and await _walk(Vector2(at.x, 4.45)) and await _walk(Vector2(at.x, at.z))
			and _world.nearest.get("id") == definition.id and Catalog.identity(str(_world.nearest.get("id"))).zone == "toy",
			str(definition.id) + " is reachable on foot and its prompt opens that game")
	_check(await _walk(Vector2(0, 4.45)), "the way back to the foyer stays open")


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


## Nothing floats: grass runs past everything the camera can show, the yard has
## kerbs, lamps stay in the budget and every interaction point and stand bay is clear.
func _check_surround() -> void:
	var lawn := _world.get_node("ToyLawn") as MeshInstance3D
	var reach := (lawn.mesh as PlaneMesh).size * 0.5
	var view := maxf(VIEW_HALF.x, VIEW_HALF.y) + 12.0
	_check(reach.x >= World.BOUNDS.end.x + view and reach.y >= World.BOUNDS.end.y + view and lawn.position.y < World.GROUND_Y - 0.02
		and lawn.position.y > 0.0, "the lawn lies under the yard and runs 12 m past every view from the walkable area")
	_check(Scenery.KNOLLS.size() >= 5 and _world.ground_surface_y(Vector3(0, 0, -22)) > 2.0
		and is_equal_approx(_world.ground_surface_y(Vector3(-20, 0, 12)), Scenery.LAWN_Y), "hills rise behind the tower and the ground is never a void")
	var blocks := _world.get_node("Scenery_box") as MultiMeshInstance3D
	_check(blocks != null and blocks.multimesh.instance_count > 300 and not Standards._is_flat_material(blocks.material_override),
		"houses, kerbs and the tower are batched painted blocks, not flat colours")
	var lights := _world.find_children("*", "Light3D", true, false)
	_check(_world.lamps.size() == 8 and lights.size() == _world.lamps.size() + 1, "every light is the sun or one of eight budgeted lamps")
	var obstacles := _obstacles()
	for point: Dictionary in _world.points:
		var at := Vector2(point.position.x, point.position.z)
		_check(not obstacles.any(func(rect: Rect2) -> bool: return rect.grow(0.42).has_point(at)), "%s has room to stand" % point.id)
	for bay: Rect2 in Scenery.STAND_BAYS:
		_check(not obstacles.any(func(rect: Rect2) -> bool: return rect.intersects(bay))
			and not _world.points.any(func(point: Dictionary) -> bool: return bay.grow(1.2).has_point(Vector2(point.position.x, point.position.z))),
			"a bay stays free for a future game stand at %s" % bay.get_center())
	_check(_world.find_children("*", "Node", true, false).size() + 1 <= 900, "the town stays within the 900 node budget")


## Footprints of every invisible obstacle the scenery placed.
func _obstacles() -> Array[Rect2]:
	var found: Array[Rect2] = []
	for child in _world.get_children():
		if not child is StaticBody3D or child.get_child_count() == 0:
			continue
		var box := (child.get_child(0) as CollisionShape3D).shape as BoxShape3D
		if box != null:
			found.append(Rect2(child.position.x - box.size.x * 0.5, child.position.z - box.size.z * 0.5, box.size.x, box.size.z))
	return found


## Ambient motion, the toys that answer the player, the crank and reduced motion.
func _check_life() -> void:
	var life: RefCounted = _world._life
	var rail := _world.get_node("ToyRailDemonstration") as Node3D
	var notes: Array[int] = []
	_world.note_requested.connect(func(note: int) -> void: notes.append(note))
	_world.apply_settings({"reduced_motion": false})
	_world.reset_train()
	_world.player.position = Vector3(8.0, World.GROUND_Y, 6.5)
	await _frames(40)
	var phase: float = life.gear_phase()
	var pendulum := _world.get_node("ToyClockPendulum") as Node3D
	var top := _world.get_node("ToySpinningTop") as Node3D
	var carousel := _world.get_node("ToyCarousel") as Node3D
	var before := [pendulum.rotation.z, top.basis, carousel.rotation.y, life.soldier_position(4)]
	await _frames(30)
	_check(life.gear_phase() > phase and pendulum.rotation.z != before[0] and top.basis != before[1] and carousel.rotation.y != before[2]
		and life.soldier_position(4) != before[3], "gears, pendulum, top, carousel and the patrol all keep moving")
	for gear: Array in life._gears:
		_check(not is_zero_approx(gear[5]), "every gear turns with its train")
	var pair: Array = [life._gears[0], life._gears[1]]
	_check(is_equal_approx(pair[1][5], -pair[0][5] * 16.0 / 12.0), "meshed gears counter-rotate by their tooth ratio")
	var slow: float = life.gear_phase()
	await _frames(30)
	var cruising: float = life.gear_phase() - slow
	_check(_world.wind_tower().contains(_world.tower_clock()), "winding the tower still tells the time")
	slow = life.gear_phase()
	await _frames(30)
	_check(life.gear_phase() - slow > cruising * 2.0, "cranking the tower sets the clockwork racing")
	# Tin soldiers salute a passing visitor and stand easy again afterwards.
	_check(life.salute(0) < 0.05 and life.jack_pop() < 0.05, "toys rest while the visitor is far away")
	_world.player.position = Vector3(-1.5, World.GROUND_Y, 9.0)
	await _frames(40)
	_check(life.salute(0) > 0.95 and life.salute(2) == 0.0, "the nearest gate guard salutes, the far one does not")
	_world.player.position = Vector3(-1.6, World.GROUND_Y, 6.0)
	await _frames(50)
	_check(life.jack_pop() > 0.6 and notes.has(3) and (_world.get_node("ToyJackHead") as Node3D).position.y > World.GROUND_Y + 1.0,
		"the jack-in-the-box pops with a note when approached")
	_world.player.position = Vector3(8.0, World.GROUND_Y, 6.5)
	await _frames(150)
	_check(life.salute(0) < 0.05 and life.jack_pop() < 0.1, "soldier and jack-in-the-box settle after the visitor leaves")
	# The floor piano plays one note per key as it is stepped on, never while standing.
	notes.clear()
	for x: float in [-2.1, -1.4, -0.7, 0.0]:
		_world.player.position = Vector3(x, World.GROUND_Y, 2.7)
		await _frames(3)
	await _frames(20)
	_check(notes == [0, 1, 2, 3], "four piano keys play four ascending notes, once each")
	# The train: wagons trail the engine and the signal arms follow the points.
	var wagon := rail.get_node("CargoWagon1") as Node3D
	var arms: Array = _world._scenery.signals
	_check(wagon.global_position.z > _world.train_state().position.z + 1.5 and Scenery.YARD_TAIL.has_point(Vector2(wagon.global_position.x, wagon.global_position.z)),
		"at the dock the wagons stand on the tail siding behind the engine")
	_check(arms[0].rotation.z > 0.5 and arms[1].rotation.z == 0.0, "the left signal arm is raised for the left branch")
	_world.switch_tracks()
	_check(arms[1].rotation.z > 0.5 and arms[0].rotation.z == 0.0, "switching the points swaps the raised arm")
	_world.operate_train()
	await _frames(60)
	_check(rail.puffing() and rail.get_node_or_null("FunnelPuffs") != null, "the running engine puffs")
	# Reduced motion: one still frame, no reactions, the piano still sounds.
	var count := _world.find_children("*", "Node", true, false).size()
	var materials: int = _world.material_cache.size()
	_world.apply_settings({"reduced_motion": true})
	_world.player.position = Vector3(-1.5, World.GROUND_Y, 9.0)
	await _frames(20)
	before = [pendulum.rotation.z, top.basis, carousel.rotation.y, life.soldier_position(4)]
	notes.clear()
	_world.player.position = Vector3(-1.4, World.GROUND_Y, 2.7)
	await _frames(30)
	_check(life.gear_phase() == 0.0 and pendulum.rotation.z == before[0] and top.basis == before[1] and carousel.rotation.y == before[2]
		and life.soldier_position(4) == before[3] and life.salute(0) == 0.0 and life.jack_pop() == 0.0, "reduced motion holds every toy in one still pose")
	_check(not rail.puffing() and not _world.train_state().running,
		"reduced motion stops the train and clears its steam")
	_check(notes == [1] and not _world.wind_tower().contains("發條上緊") and life.gear_phase() == 0.0, "the piano still sounds and the crank only tells the time")
	_world.reset_train()
	_world.apply_settings({"reduced_motion": false})
	for phase_id: String in ["dawn", "noon", "dusk", "night"]:
		_world.set_time_of_day(phase_id)
		_check((_world._kit.glow_material.emission_energy_multiplier > 0.0) == (phase_id != "noon"), "windows glow at %s only when lamps are lit" % phase_id)
	_world.set_time_of_day("noon")
	_check(_world.find_children("*", "Node", true, false).size() == count and _world.material_cache.size() == materials,
		"settings, time of day and play add no nodes or materials")


func _check_map() -> void:
	var snapshot := _world.map_snapshot()
	var map := MapPanel.new()
	map.setup(snapshot)
	root.add_child(map)
	var locations := map.find_child("ToyMapLocations", true, false)
	var status := map.find_child("ToyMapStatus", true, false) as Label
	_check(snapshot.region == "toy" and snapshot.player == _world.player.position and snapshot.points.size() == 7 + ArcadeStands.rows("toy").size()
		and snapshot.areas.size() == 5 and locations != null and locations.get_child_count() == snapshot.points.size() and status != null
		and status.text.contains("逐站") and map.find_child("ToyMapTerrain", true, false) != null,
		"shared map records real player, switches and stops")
	_check(snapshot.points.any(func(point: Dictionary) -> bool:
		return point.id == Visit.TOY_POINT and point.position == World.STORY_POINT), "map directs to the physical story host")
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
