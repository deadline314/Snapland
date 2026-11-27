extends Node
## The island world's keeper of embedded districts (see DistrictSites and the
## district notes at the top of park_world.gd). It builds each district the
## first time the walker comes near, puts far ones to sleep, works out how much
## of each district's light and air reaches the walker, and keeps the sticker
## gates. It owns no scenery of its own.
##
## For features that span the park (a roaming event, instant games in every
## district), ask the host rather than reaching into districts:
## - standing / district_changed: the district the walker is in ("welcome" on the island).
## - weights: each district's 0..1 share at the walker; island_share() the rest.
## - built(region) / is_awake(region): a district's world node, and whether it
##   is near enough to process and draw. Anything placed inside a district should
##   be a child of built(region) so it sleeps and wakes with it.
## - gate_is_open(region) / gate_opened: the sticker gates.
## - DistrictSites.ruling(point) / claims(point): who owns a spot of ground;
##   island-wide props keep out of claims and off approaches.
## Lifecycle: a district is built a little each frame once the walker comes
## within DistrictSites.BUILD_RADIUS (ensure() builds at once, for fast travel
## and restored saves), shown and processed inside ACTIVE_RADIUS and put to
## sleep beyond DORMANT_RADIUS. A district that fails to build is logged, its
## gate shows that it is closed for repairs, and the rest of the park runs on.

const DistrictSites = preload("res://game/world/district_sites.gd")
const RegionRoutes = preload("res://game/core/region_routes.gd")
const HOME := "welcome"
## The walker belongs to a district above ENTER and to the island again below LEAVE.
const ENTER_WEIGHT := 0.6
const LEAVE_WEIGHT := 0.4
const STREAM_INTERVAL := 0.4
const AIR_STEP := 0.002

var world: Node3D
## Built districts by region, and the regions whose build failed.
var districts: Dictionary = {}
var failed: Dictionary = {}
## Share of each district's light and air at the walker, 0..1; the island has the rest.
var weights: Dictionary = {}
var standing := HOME
var last_build_msec := 0
## The longest single frame of the last build, in ms.
var longest_step_msec := 0.0
## How many frames a staged build may take before it counts as failed. Counted
## in frames, not wall time, so a long frame elsewhere (a loading hitch, a check
## that works without yielding) never fails a build that is still progressing.
const BUILD_DEADLINE_FRAMES := 900

var _open: Dictionary = {}
var _stickers := -1
var _applied: Dictionary = {}
var _stream_elapsed := STREAM_INTERVAL
var _settings: Dictionary = {}
var _look: Array = []
## Districts being built over several frames: region -> {node, lamps, started}.
var _building: Dictionary = {}

func configure(owner_world: Node3D) -> void:
	world = owner_world
	for region: String in DistrictSites.regions():
		weights[region] = 0.0
		_applied[region] = 0.0
		_open[region] = false

func built(region: String) -> Node3D:
	return districts.get(region)

## The built district whose own walking rules apply at a world position, or null.
func ruling(at: Vector3) -> Node3D:
	return districts.get(DistrictSites.ruling(Vector2(at.x, at.z)))

func island_share() -> float:
	var total := 0.0
	for region: String in weights:
		total += float(weights[region])
	return clampf(1.0 - total, 0.0, 1.0)

func gate_is_open(region: String) -> bool:
	return bool(_open.get(region, false))

## Build a district now, in this frame (fast travel behind the cover, a restored
## save). Returns null, and remembers the failure, when its script is missing or
## its build did not finish; its gate then stays shut.
func ensure(region: String) -> Node3D:
	if districts.has(region): return districts[region]
	if failed.has(region) or not DistrictSites.has(region) or _building.has(region): return null
	return _build(region, str(DistrictSites.SITES[region].script))

## True while a district is being built over several frames.
func is_building(region: String) -> bool:
	return _building.has(region)

## Start building a district a little each frame (the walker is still far off);
## it stays hidden and still until finished.
func _build_in_steps(region: String) -> void:
	_build(region, str(DistrictSites.SITES[region].script), true)

func _build(region: String, script_path: String, staged := false) -> Node3D:
	var started := Time.get_ticks_msec()
	var site: Dictionary = DistrictSites.SITES[region]
	var lamps_before: int = world.lamps.size()
	var script := load(script_path) as GDScript if ResourceLoader.exists(script_path) else null
	var node: Node3D = script.new() as Node3D if script != null else null
	if node != null:
		node.set("embedded_in", world)
		node.set("district", region)
		node.set("build_in_steps", staged)
		node.name = "District_" + region
		node.position = site.at
		if staged:
			node.visible = false
			node.process_mode = Node.PROCESS_MODE_DISABLED
			_building[region] = {"node": node, "lamps": lamps_before, "started": started, "frame": Engine.get_process_frames()}
			node.district_built.connect(_finish_build.bind(region, node, lamps_before, started), CONNECT_ONE_SHOT)
		world.add_child(node)
		if staged: return null
	return _finish_build(region, node, lamps_before, started)

func _finish_build(region: String, node: Node3D, lamps_before: int, started: int) -> Node3D:
	_building.erase(region)
	if node == null or not bool(node.get("district_ready")):
		push_warning("District '%s' could not be built; its gate stays closed." % region)
		failed[region] = true
		if node != null:
			world.lamps.resize(lamps_before)
			for index in range(world.points.size() - 1, -1, -1):
				if world.points[index].get("region", "") == region: world.points.remove_at(index)
			node.queue_free()
		_set_gate(region, false, false)
		return null
	districts[region] = node
	# The host chooses which lamps burn; each district still sets how bright its own are.
	for index in range(lamps_before, world.lamps.size()):
		world.lamps[index].set_meta(&"district", node)
	# Its other lights burn on their own and take places from the lamp budget while it is awake.
	node.steady_lights = node.find_children("*", "Light3D", true, false).filter(func(light: Light3D) -> bool: return not world.lamps.has(light)).size()
	node.set_time_of_day(world.active_time_phase)
	if not _settings.is_empty(): node.apply_settings(_settings)
	world.trim_small_shadows(node)
	if _look.size() == 2: node.set_avatar_look(_look[0], _look[1])
	world.bind_district_ground(districts.keys())
	if _stickers >= 0: _set_gate(region, _stickers >= RegionRoutes.threshold(region), false)
	last_build_msec = Time.get_ticks_msec() - started
	longest_step_msec = float(node.longest_step_usec) / 1000.0 if node.build_in_steps else float(last_build_msec)
	print("[district] %s built in %d ms over %d frames (longest frame %.0f ms), %d nodes" % [region, last_build_msec, node.build_steps + 1, longest_step_msec,
		node.find_children("*", "Node", true, false).size() + 1])
	if node.build_in_steps:
		node.build_in_steps = false
		_set_awake(node, true)
	return node

## Once per physics tick: weights, the district the walker stands in, and the
## blended light; a few times a second: building and sleeping.
func track(at: Vector3, delta: float) -> void:
	var spot := Vector2(at.x, at.z)
	var changed := false
	var leader := HOME
	var lead := 0.0
	var total := 0.0
	for region: String in weights:
		var share := DistrictSites.weight(region, spot) if districts.has(region) else 0.0
		weights[region] = share
		total += share
	# Where two bands overlap the districts share the air and the island has none.
	var scale := 1.0 / total if total > 1.0 else 1.0
	for region: String in weights:
		var share := float(weights[region]) * scale
		weights[region] = share
		if absf(share - float(_applied[region])) > AIR_STEP or (share == 0.0) != (float(_applied[region]) == 0.0): changed = true
		if share > lead:
			lead = share
			leader = region
	if changed:
		for region: String in weights:
			_applied[region] = weights[region]
		_apply_presence()
		world.blend_air()
	var next := standing
	if lead >= ENTER_WEIGHT: next = leader
	elif standing != HOME and float(weights.get(standing, 0.0)) <= LEAVE_WEIGHT: next = HOME
	if next != standing:
		standing = next
		world.district_changed.emit(standing)
	_stream_elapsed += delta
	if _stream_elapsed >= STREAM_INTERVAL:
		_stream_elapsed = 0.0
		_stream(spot)

## Mix every district's wanted light into `blend`, which starts as the island's
## own: a weighted sum with the island's share, so overlapping bands stay exact.
func blend_air(blend: Dictionary, keys: Array) -> void:
	var home := island_share()
	for key: String in keys:
		var mixed: Variant = blend[key] * home
		for region: String in districts:
			var share := float(weights[region])
			if share > 0.0: mixed += districts[region].air_target[key] * share
		blend[key] = mixed

func set_phase(phase: String) -> void:
	for region: String in districts:
		districts[region].set_time_of_day(phase)

func apply_settings(settings: Dictionary) -> void:
	_settings = settings
	for region: String in districts:
		districts[region].apply_settings(settings)

func set_avatar_look(appearance: Dictionary, equipped: Dictionary) -> void:
	_look = [appearance, equipped]
	for region: String in districts:
		districts[region].set_avatar_look(appearance, equipped)

## Open every gate whose sticker threshold is met. The first call after a load
## opens them quietly; a gate that opens later celebrates.
func set_sticker_count(count: int) -> void:
	var quiet := _stickers < 0
	_stickers = count
	for region: String in DistrictSites.regions():
		var open := count >= RegionRoutes.threshold(region) and not failed.has(region)
		if open != gate_is_open(region): _set_gate(region, open, open and not quiet)

func _set_gate(region: String, open: bool, celebrate: bool) -> void:
	_open[region] = open
	world.show_gate(region, open, celebrate)
	if celebrate: world.gate_opened.emit(region)

func _stream(spot: Vector2) -> void:
	var building := not _building.is_empty()
	for region: String in _building.keys():
		# A build that stopped part way (a script error) never finishes: give up on it.
		if Engine.get_process_frames() - int(_building[region].frame) > BUILD_DEADLINE_FRAMES:
			var record: Dictionary = _building[region]
			for link: Dictionary in (record.node as Node3D).district_built.get_connections():
				(record.node as Node3D).district_built.disconnect(link.callable)
			_finish_build(region, record.node, record.lamps, record.started)
	for region: String in DistrictSites.regions():
		var gap := DistrictSites.distance(region, spot)
		var node: Node3D = districts.get(region)
		if node == null:
			# One build at a time, spread over frames, so a first approach never stalls.
			if gap < DistrictSites.BUILD_RADIUS and not building and not failed.has(region):
				building = true
				_build_in_steps(region)
			continue
		var awake := node.process_mode != Node.PROCESS_MODE_DISABLED
		if awake and gap > DistrictSites.DORMANT_RADIUS: _set_awake(node, false)
		elif not awake and gap < DistrictSites.ACTIVE_RADIUS: _set_awake(node, true)

func _set_awake(node: Node3D, awake: bool) -> void:
	node.visible = awake
	node.process_mode = Node.PROCESS_MODE_INHERIT if awake else Node.PROCESS_MODE_DISABLED
	world._update_lamp_selection(true)

## Lights awake districts keep burning outside the shared lamp list.
func steady_lights() -> int:
	var count := 0
	for region: String in districts:
		count += int(districts[region].steady_light_count())
	return count

func is_awake(region: String) -> bool:
	return districts.has(region) and districts[region].process_mode != Node.PROCESS_MODE_DISABLED

func _apply_presence() -> void:
	if is_instance_valid(world.ambience): world.ambience.set_presence(island_share())
	for region: String in districts:
		var air: Node = districts[region].ambience
		if is_instance_valid(air): air.set_presence(float(weights[region]))
