extends SceneTree

const HARBOR_PATH := "res://game/world/harbor_world.gd"
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if not ResourceLoader.exists(HARBOR_PATH):
		_check(false, "independent HarborWorld exists")
		_finish()
		return
	var harbor_script = load(HARBOR_PATH)
	var progress = root.get_node("Progress")
	var before := _progress_snapshot(progress)
	var node_count := 0
	var cache_count := 0
	for visit in range(3):
		var world = harbor_script.new()
		root.add_child(world)
		await physics_frame
		await physics_frame
		world.blocked = true
		_check(world.coastal_play == null and world.island_attractions == null and world.npc_activity == null and world.story_landmarks == null, "no welcome controllers or NPCs")
		_check(world.character_sprites.is_empty() and world.district_labels.is_empty(), "no welcome actors or districts built")
		_check(world.avatar.texture != null and world.avatar_motion_rig == null, "shared complete source avatar")
		_check(world.current_area == "潮汐碼頭", "initial harbor identity")
		world.apply_settings({"reduced_motion": true})
		world.set_time_of_day("night")
		world.set_avatar_look({"skin":"deep","species":"elf","gender":"neutral","hair":"curly","hair_color":"ink","face":"curious"}, {"outfit":"outfit-tide","hat":"hat-none"})
		_check(world.avatar.texture != null and world.reduced_motion and world.active_time_phase == "night", "shared appearance/settings/time remain usable without fountain")
		var snapshot: Dictionary = world.map_snapshot()
		_check(snapshot.keys().size() == 6 and snapshot.bounds is Rect2 and snapshot.sandbar is Rect2 and snapshot.land is Array, "map geometry value contract")
		_check(_values_only(snapshot), "snapshot holds no nodes/resources")
		for rect in snapshot.land:
			_check(snapshot.bounds.encloses(rect), "map bounds enclose each actual shore")
		var detached: Dictionary = world.map_snapshot()
		detached.land.clear()
		detached.points[0].label = "changed"
		_check(not world.map_snapshot().land.is_empty() and world.map_snapshot().points[0].label != "changed", "snapshot cannot mutate world data")
		_check(snapshot.points.size() == world.points.size(), "map includes every actual interaction")
		for point in snapshot.points:
			_check(point.keys().size() == 3 and point.has("id") and point.has("label") and point.position is Vector3, "point snapshot only id/label/position")
			_check(point.id in ["game-013", "game-014", "game-015", "game-016", "game-017", "game-018", "game-019", "game-020", "game-021", "game-022"] or point.id == "region:welcome" or point.id == "harbor:tide" or point.id.begins_with("harbor:ferry:") or point.id.begins_with("harbor:info:"), "only delivered harbor games and existing regional interactions")
		var spawn: Vector3 = world.player.position
		var shore_landing: Vector3 = world._point_by_id("harbor:ferry:shore").position
		_check(_map_land(snapshot, Vector2(spawn.x, spawn.z)), "safe mapped spawn")
		var sand: Rect2 = snapshot.sandbar
		var sand_position := Vector3(sand.get_center().x, 0.2, sand.get_center().y)
		for high in [false, true]:
			world.set_tide(high)
			await physics_frame
			await physics_frame
			_check(world.is_high_tide() == high and world.map_snapshot().high_tide == high, "local tide preview matches map")
			var state: Dictionary = world.map_snapshot()
			# Independently sample physics across the full bounds, not just declared paths.
			for x in range(-14, 15):
				for z in range(-11, 12):
					var sample := Vector3(float(x) + 0.17, 0.0, float(z) + 0.19)
					var mapped := _map_land(state, Vector2(sample.x, sample.z))
					var hit := _floor_hit(world, sample)
					_check((not hit.is_empty()) == mapped, "collision/map agreement %s tide=%s" % [sample, high])
					if mapped and not hit.is_empty():
						_check(absf(hit.position.y - world.ground_surface_y(sample)) < 0.001, "terrain/collision height agreement")
			_check(_floor_hit(world, sand_position).is_empty() == high, "sandbar collision follows tide")
			var reachable := _reachable_cells(state, Vector2i(-12, 9))
			for point in state.points:
				var cell := Vector2i(roundi(point.position.x), roundi(point.position.z))
				_check(reachable.has(cell), "permanent walking route to %s at tide=%s" % [point.id, high])
				world.player.position = point.position
				world.player.velocity = Vector3.ZERO
				await physics_frame
				await physics_frame
				_check(world.player.position.distance_to(point.position) < 0.2, "point has safe actual footing")
				_check(world.nearest.get("id", "") == point.id, "point reachable through inherited interaction selection")
			_check(world.take_ferry("harbor:ferry:shore"), "free shore to lighthouse ferry")
			var island_landing: Vector3 = world.player.position
			_check(island_landing.is_equal_approx(world._point_by_id("harbor:ferry:lighthouse").position), "fixed opposite lighthouse ferry landing independent of tide")
			_check(world.player.velocity == Vector3.ZERO and _map_land(state, Vector2(island_landing.x, island_landing.z)), "safe fixed island ferry landing")
			_check(world.take_ferry("harbor:ferry:lighthouse"), "free lighthouse to shore ferry")
			_check(world.player.position.is_equal_approx(shore_landing) and world.player.velocity == Vector3.ZERO, "fixed safe return ferry landing independent of tide")
			_check(not world.take_ferry("game-013"), "unknown ferry refused")
		world.set_tide(false)
		await physics_frame
		world.player.position = sand_position
		world.player.velocity = Vector3(1, -4, 1)
		world.set_tide(true)
		_check(world.player.position.is_equal_approx(shore_landing) and world.player.velocity == Vector3.ZERO, "rising tide moves sandbar player before removing support")
		await physics_frame
		_check(not world.avatar_is_walking and is_zero_approx(world.walk_distance_phase), "tide relocation resets stride telemetry")
		# Real input must cross the shortcut at low tide and stop at water at high tide.
		world.blocked = false
		for high in [false, true]:
			world.set_tide(high)
			world.player.position = Vector3(-10, 0.2, 0)
			world.player.velocity = Vector3.ZERO
			await physics_frame
			Input.action_press("move_right")
			for tick in range(280): await physics_frame
			Input.action_release("move_right")
			_check(world.player.position.x > -4.0 if not high else world.player.position.x < -9.0, "actual movement uses low-tide shortcut and rejects high-tide water")
		world.blocked = true
		world.player.position = Vector3(6, -3, 0)
		await physics_frame
		await physics_frame
		_check(world.player.position.distance_to(spawn) < 0.2 and not world.avatar_is_walking, "water/fall recovery uses harbor safe dock without false stride")
		world.update_collection({"photo-welcome-story-1": true})
		_check(world.map_snapshot().points == snapshot.points, "welcome collection cannot turn harbor information into rewards")
		var count: int = world.find_children("*", "Node", true, false).size()
		if visit == 0:
			node_count = count
			cache_count = world.material_cache.size()
		else:
			_check(count == node_count and world.material_cache.size() == cache_count, "bounded scene/resources on reentry")
		var weak: WeakRef = weakref(world)
		world.queue_free()
		await process_frame
		await process_frame
		_check(weak.get_ref() == null, "old world freed on reentry")
	_check(_progress_snapshot(progress) == before, "tides/ferries/exploration never mutate global phase/progress/rewards")
	_finish()

func _progress_snapshot(progress) -> Dictionary:
	var snapshot := {}
	for property in progress.get_property_list():
		if int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			var value: Variant = progress.get(property.name)
			if value is Dictionary or value is Array: value = value.duplicate(true)
			snapshot[property.name] = value
	return snapshot

func _floor_hit(world, at: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(Vector3(at.x, 0.8, at.z), Vector3(at.x, -1, at.z))
	query.exclude = [world.player.get_rid()]
	return world.get_world_3d().direct_space_state.intersect_ray(query)

func _map_land(snapshot: Dictionary, point: Vector2) -> bool:
	for rect in snapshot.land:
		if rect.has_point(point): return true
	return not snapshot.high_tide and snapshot.sandbar.has_point(point)

func _reachable_cells(snapshot: Dictionary, start: Vector2i) -> Dictionary:
	var reached := {start: true}
	var pending := [start]
	while not pending.is_empty():
		var cell: Vector2i = pending.pop_back()
		for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = cell + direction
			if reached.has(next) or not _map_land(snapshot, Vector2(next)): continue
			reached[next] = true
			pending.append(next)
	return reached

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
	# The check count grows with each delivered kiosk, so it is reported apart from the fixed completion marker.
	print("Harbor world checks: %d" % checks)
	if failures.is_empty(): print("PASS: harbor world terrain, tide safety, free ferry, map alignment and bounded reentry")
	else: print("FAIL: harbor world (%d/%d)" % [failures.size(), checks])
	quit(0 if failures.is_empty() else 1)
