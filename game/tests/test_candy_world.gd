extends SceneTree

const CANDY_PATH := "res://game/world/candy_world.gd"
const Catalog = preload("res://game/core/game_catalog.gd")
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if not ResourceLoader.exists(CANDY_PATH):
		_check(false, "independent CandyWorld exists")
		_finish()
		return
	var script = load(CANDY_PATH)
	var progress = root.get_node("Progress")
	var before := _progress_snapshot(progress)
	var node_count := 0
	var cache_count := 0
	var expected_games: Array = Catalog.definitions("candy").map(func(row: Dictionary) -> String: return row.id)
	for visit in range(3):
		var world = script.new()
		root.add_child(world)
		await physics_frame
		await physics_frame
		world.blocked = true
		_check(world.coastal_play == null and world.island_attractions == null and world.npc_activity == null and world.story_landmarks == null, "no welcome activities or NPCs")
		_check(world.character_sprites.is_empty() and world.district_labels.is_empty(), "no welcome actors or districts")
		_check(world.avatar.texture != null and world.avatar_motion_rig == null, "shared complete source avatar")
		_check(world.current_area == "糖果工廠" and world.map_snapshot().temperature == 0, "reentry starts in cold factory")
		var backdrop := world.get_node("ChocolateBackdrop") as MeshInstance3D
		_check(backdrop != null and backdrop.position.y < -0.4 and backdrop.find_children("*", "CollisionObject3D", true, false).is_empty(), "bounded chocolate scenery stays below land without fake walkable collision")
		_check(backdrop.mesh is PlaneMesh and (backdrop.mesh as PlaneMesh).size == Vector2(110, 110), "chocolate backdrop has fixed dimensions")
		_check(world._temperature_label.font_size == 32 and is_equal_approx(world._temperature_label.pixel_size, 0.02), "physical sign uses larger glyphs")
		var game_signs: Array = world.local_sign_labels.filter(func(label: Label3D): return label.text.begins_with("工廠遊戲 "))
		world.player.position = Vector3(0, script.GROUND_Y, -10.8)
		world.player.velocity = Vector3.ZERO
		await physics_frame
		await physics_frame
		_check(game_signs.size() == 1 and game_signs[0].is_visible_in_tree() and game_signs[0].text == "工廠遊戲 %d／12" % expected_games.size(), "factory sign advertises all delivered games")
		world.reset_to_entry()
		for sign_label in world.local_sign_labels:
			_check(sign_label.billboard == BaseMaterial3D.BILLBOARD_DISABLED and sign_label.basis.is_equal_approx(Basis.IDENTITY) and not sign_label.no_depth_test, "physical sign stays parallel to its fixed board with depth enabled")
		var snapshot: Dictionary = world.map_snapshot()
		_check(snapshot.size() == 6 and snapshot.bounds == script.BOUNDS and snapshot.land == script.LAND and snapshot.region == "candy", "map value contract and actual geometry constants")
		_check(_values_only(snapshot), "map has no nodes/resources")
		var detached: Dictionary = world.map_snapshot()
		detached.land.clear()
		detached.points[0].label = "changed"
		_check(not world.map_snapshot().land.is_empty() and world.map_snapshot().points[0].label != "changed", "snapshot mutations remain detached")
		for rect in snapshot.land:
			_check(snapshot.bounds.encloses(rect), "bounds enclose all factory floors")
		_check(world.player.position.distance_to(script.ENTRY) < 0.2 and _safe_land(snapshot, script.ENTRY), "fixed safe entrance")
		for x in range(-14, 15):
			for z in range(-13, 14):
				var sample := Vector3(float(x) + 0.17, 0.0, float(z) + 0.19)
				var mapped := _map_land(snapshot, Vector2(sample.x, sample.z))
				var hit := _floor_hit(world, sample)
				_check((not hit.is_empty()) == mapped, "collision/map agreement at %s" % sample)
				if mapped and not hit.is_empty():
					_check(absf(hit.position.y - world.ground_surface_y(sample)) < 0.001, "floor height agreement")
		var reached := _reachable_cells(snapshot, Vector2i(0, 9))
		_check(snapshot.points.size() == world.points.size() and snapshot.points.size() == expected_games.size() + 5, "all actual factory interactions mapped")
		for point in snapshot.points:
			_check(point.size() == 3 and point.position is Vector3, "point contains only id/label/position")
			_check(point.id in ["region:welcome", "candy:temperature", "candy:reset"] or point.id.begins_with("candy:info:") or point.id in expected_games, "only delivered games and observation IDs")
			_check(reached.has(Vector2i(roundi(point.position.x), roundi(point.position.z))), "connected safe walking route to %s" % point.id)
			world.player.position = point.position
			world.player.velocity = Vector3.ZERO
			await physics_frame
			await physics_frame
			_check(world.player.position.distance_to(point.position) < 0.2 and world.nearest.get("id", "") == point.id, "actual safe footing and selection for %s" % point.id)
		var actual_games: Array = snapshot.points.filter(func(point): return str(point.id).begins_with("game-")).map(func(point: Dictionary) -> String: return point.id)
		_check(actual_games == expected_games and world._point_by_id("game-025").label.contains("拉糖橋") and world._point_by_id("game-026").label.contains("餅乾翻模"), "each delivered candy game has a real entrance")
		_check(world._point_by_id("game-027").position == Vector3(7, script.GROUND_Y, -6), "third game has the actual upper-right pipe entrance")
		_check(world._point_by_id("game-028").position == Vector3(7, script.GROUND_Y, -1), "fourth game uses the next safe upper-right floor with margin")
		_check(world._point_by_id("game-029").position == Vector3(10.5, script.GROUND_Y, -0.8), "fifth game uses the calibrated entrance")
		_check(world._point_by_id("game-030").position == Vector3(6.5, script.GROUND_Y, 10), "sixth game uses the lower-right floor")
		_check(world._point_by_id("game-031").position == Vector3(-2.2, script.GROUND_Y, -4.5), "seventh game uses the left side of the conveyor aisle")
		_check(world._point_by_id("game-032").position == Vector3(-9, script.GROUND_Y, -2.6), "eighth game uses the floor by the materials lab")
		_check(world._point_by_id("game-033").position == Vector3(4.9, script.GROUND_Y, -3.8), "ninth game uses the floor by the baking aisle")
		_check(world._point_by_id("game-034").position == Vector3(-2.6, script.GROUND_Y, 6.55), "tenth game uses the clear floor off the main conveyor")
		var count: int = world.find_children("*", "Node", true, false).size()
		var materials: int = world.material_cache.size()
		var display_id: int = world._temperature_display.get_instance_id()
		var display_mesh_id: int = world._temperature_display.mesh.get_instance_id()
		var state_shapes := {}
		var state_materials := {}
		for cycle in range(30):
			world.apply_settings({"reduced_motion": cycle % 2 == 0})
			world.set_time_of_day("night" if cycle % 2 == 0 else "noon")
			world.cycle_temperature()
			var state: int = world.map_snapshot().temperature
			_check(state == (cycle + 1) % 3, "cold/warm/hot cycle is bounded")
			_check(world.temperature_label() == script.TEMPERATURE_LABELS[state] and world._temperature_label.text == script.TEMPERATURE_SIGN_LABELS[state], "full temperature explanation and short physical sign agree on state")
			_check(world._temperature_label.text.length() <= 6 and world.temperature_label().length() > world._temperature_label.text.length(), "short physical signs preserve detailed toast copy")
			state_shapes[state] = world._temperature_display.scale
			state_materials[state] = world._temperature_display.material_override.get_instance_id()
			_check(world._temperature_display.visible and world._temperature_display.get_instance_id() == display_id and world._temperature_display.mesh.get_instance_id() == display_mesh_id, "same visible sample and mesh reused")
			_check(world.find_children("*", "Node", true, false).size() == count and world.material_cache.size() == materials, "settings/day/night/temperature do not allocate scene resources")
		_check(state_shapes[0] != state_shapes[1] and state_shapes[1] != state_shapes[2] and state_shapes[0] != state_shapes[2], "three distinct static sample shapes")
		_check(state_materials[0] != state_materials[1] and state_materials[1] != state_materials[2] and state_materials[0] != state_materials[2], "three distinct cached sample colors")
		world.set_avatar_look({"skin":"deep","species":"elf","gender":"neutral","hair":"curly","hair_color":"ink","face":"curious"}, {"outfit":"outfit-tide","hat":"hat-none"})
		_check(world.avatar.texture != null and world.sea_material == null and world.fountain_water == null, "appearance/settings work without optional sea or fountain")
		for destination in [Vector3(9, 0.2, 9), script.ENTRY + Vector3(0.01, 0, 0)]:
			world.player.position = destination
			world.player.velocity = Vector3(2, -4, 3)
			world.avatar_is_walking = true
			world.walk_distance_phase = 1.2
			world.play_action("wave")
			_check(world.reset_to_entry(), "free reset succeeds")
			_check(world.player.position == script.ENTRY and world.player.velocity == Vector3.ZERO and not world.avatar_is_walking and is_zero_approx(world.walk_distance_phase), "reset clears movement even beside entrance")
			_check(world.camera.position.is_equal_approx(script.ENTRY + world.CAMERA_OFFSET) and world.avatar_action_remaining == 0.0 and world.avatar.texture != null, "reset synchronizes camera and complete idle avatar")
		world.player.position = Vector3(30, -3, 30)
		await physics_frame
		await physics_frame
		_check(world.player.position.distance_to(script.ENTRY) < 0.2 and not world.avatar_is_walking, "out-of-bounds/fall recovers safely")
		world.blocked = false
		world.player.position = Vector3(0, 0.2, 0)
		world.player.velocity = Vector3.ZERO
		await physics_frame
		Input.action_press("move_right")
		for tick in range(240): await physics_frame
		Input.action_release("move_right")
		_check(world.player.position.x <= 3.71 and world.player.position.x > 3.0, "actual movement stops at missing factory floor")
		world.blocked = true
		world.update_collection({"photo-welcome-story-1": true})
		_check(world.map_snapshot().points == snapshot.points, "collection cannot turn information into reward entries")
		if visit == 0:
			node_count = count
			cache_count = materials
		else:
			_check(count == node_count and materials == cache_count, "bounded resources across repeated entry")
		var weak: WeakRef = weakref(world)
		world.queue_free()
		await process_frame
		await process_frame
		_check(weak.get_ref() == null, "previous factory fully released")
	_check(_progress_snapshot(progress) == before, "exploration/temperature/reset never mutate Progress or rewards")
	_finish()

func _floor_hit(world, at: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(Vector3(at.x, 0.8, at.z), Vector3(at.x, -1, at.z))
	query.exclude = [world.player.get_rid()]
	return world.get_world_3d().direct_space_state.intersect_ray(query)

func _map_land(snapshot: Dictionary, point: Vector2) -> bool:
	for rect in snapshot.land:
		if rect.has_point(point): return true
	return false

func _safe_land(snapshot: Dictionary, position: Vector3) -> bool:
	for offset in [Vector2(-0.3, -0.3), Vector2(-0.3, 0.3), Vector2(0.3, -0.3), Vector2(0.3, 0.3)]:
		if not _map_land(snapshot, Vector2(position.x, position.z) + offset): return false
	return true

func _reachable_cells(snapshot: Dictionary, start: Vector2i) -> Dictionary:
	var reached := {start: true}
	var pending := [start]
	while not pending.is_empty():
		var cell: Vector2i = pending.pop_back()
		for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = cell + direction
			if reached.has(next) or not _safe_land(snapshot, Vector3(next.x, 0.2, next.y)): continue
			reached[next] = true
			pending.append(next)
	return reached

func _progress_snapshot(progress) -> Dictionary:
	var snapshot := {}
	for property in progress.get_property_list():
		if int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			var value: Variant = progress.get(property.name)
			if value is Dictionary or value is Array: value = value.duplicate(true)
			snapshot[property.name] = value
	return snapshot

func _values_only(value: Variant) -> bool:
	if value is Object: return false
	if value is Dictionary:
		for key in value:
			if not _values_only(key) or not _values_only(value[key]): return false
	if value is Array:
		for item in value:
			if not _values_only(item): return false
	return true

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

func _finish() -> void:
	print("Candy world checks: %d" % checks)
	if failures.is_empty(): print("PASS: candy world connected terrain, temperature, safe reset, map and bounded reentry")
	else: print("FAIL: candy world (%d/%d)" % [failures.size(), checks])
	quit(0 if failures.is_empty() else 1)
