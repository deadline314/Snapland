extends Node
## The island world's keeper of embedded districts (see DistrictSites and the
## district notes at the top of park_world.gd). It builds each district the
## first time the walker comes near, puts far ones to sleep, works out how much
## of each district's light and air reaches the walker, and keeps the sticker
## gates. It owns no scenery of its own.

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

var _open: Dictionary = {}
var _stickers := -1
var _applied: Dictionary = {}
var _stream_elapsed := STREAM_INTERVAL
var _settings: Dictionary = {}
var _look: Array = []

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

## Build a district now. Returns null, and remembers the failure, when its
## script is missing or its build did not finish; its gate then stays shut.
func ensure(region: String) -> Node3D:
	if districts.has(region): return districts[region]
	if failed.has(region) or not DistrictSites.has(region): return null
	var started := Time.get_ticks_msec()
	var site: Dictionary = DistrictSites.SITES[region]
	var script := load(site.script) as GDScript if ResourceLoader.exists(site.script) else null
	var node: Node3D = script.new() as Node3D if script != null else null
	if node != null:
		node.set("embedded_in", world)
		node.set("district", region)
		node.name = "District_" + region
		node.position = site.at
		world.add_child(node)
	if node == null or not bool(node.get("district_ready")):
		push_warning("District '%s' could not be built; its gate stays closed." % region)
		failed[region] = true
		if node != null: node.queue_free()
		_set_gate(region, false, false)
		return null
	districts[region] = node
	node.set_time_of_day(world.active_time_phase)
	if not _settings.is_empty(): node.apply_settings(_settings)
	if _look.size() == 2: node.set_avatar_look(_look[0], _look[1])
	world.bind_district_ground(districts.keys())
	last_build_msec = Time.get_ticks_msec() - started
	print("[district] %s built in %d ms, %d nodes" % [region, last_build_msec, node.find_children("*", "Node", true, false).size() + 1])
	return node

## Once per physics tick: weights, the district the walker stands in, and the
## blended light; a few times a second: building and sleeping.
func track(at: Vector3, delta: float) -> void:
	var spot := Vector2(at.x, at.z)
	var changed := false
	var leader := HOME
	var lead := 0.0
	for region: String in weights:
		var share := DistrictSites.weight(region, spot) if districts.has(region) else 0.0
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

## Fold every district's wanted light into `blend`, which starts as the island's own.
func blend_air(blend: Dictionary, keys: Array) -> void:
	for region: String in districts:
		var share := float(weights[region])
		if share <= 0.0: continue
		var target: Dictionary = districts[region].air_target
		# ponytail: one lerp per district is exact only while bands never overlap
		# (checked by the district tests); use a normalised sum if sites move closer.
		for key: String in keys:
			blend[key] = lerp(blend[key], target[key], share)

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
	var building := false
	for region: String in DistrictSites.regions():
		var gap := DistrictSites.distance(region, spot)
		var node: Node3D = districts.get(region)
		if node == null:
			# At most one build per pass keeps a first approach to one short pause.
			if gap < DistrictSites.BUILD_RADIUS and not building and not failed.has(region):
				building = true
				ensure(region)
			continue
		var awake := node.process_mode != Node.PROCESS_MODE_DISABLED
		if awake and gap > DistrictSites.DORMANT_RADIUS: _set_awake(node, false)
		elif not awake and gap < DistrictSites.ACTIVE_RADIUS: _set_awake(node, true)

func _set_awake(node: Node3D, awake: bool) -> void:
	node.visible = awake
	node.process_mode = Node.PROCESS_MODE_INHERIT if awake else Node.PROCESS_MODE_DISABLED
	world._update_lamp_selection(true)

func is_awake(region: String) -> bool:
	return districts.has(region) and districts[region].process_mode != Node.PROCESS_MODE_DISABLED

func _apply_presence() -> void:
	if is_instance_valid(world.ambience): world.ambience.set_presence(island_share())
	for region: String in districts:
		var air: Node = districts[region].ambience
		if is_instance_valid(air): air.set_presence(float(weights[region]))
