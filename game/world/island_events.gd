extends Node3D
## The island's occasional events (afternoon shower, windy balloon chase,
## evening fireworks over the bay). One small director on the island world:
## after enough free walking it picks one event allowed in the current time
## of day (IslandEventCatalog), builds that event's effects near the walker,
## runs it, then frees every node it made and waits out a cooldown.
##
## One event at a time. Menus, dialogue, rides and games (arcade or instant)
## pause it and hide its effects; switching the setting off, or the time of
## day to a phase the event does not belong to, ends it at once.
##
## An event is a Node3D script with: begin(director, player), step(delta,
## player) -> bool (false when over), set_look(reduced, saver), prompt(player)
## -> String (the one-line shutter prompt, empty when none), shutter(player),
## resume(), close() and an int `participation`. Tests drive advance() and
## start() directly with simulated walker positions.

signal notice_requested(text: String)
signal sfx_requested(kind: String)
signal note_requested(note: int)
## An event's goal was met: main snaps the moment and keeps the souvenir sticker.
signal sticker_earned(sticker: String)

const Catalog = preload("res://game/core/island_event_catalog.gd")
const DistrictSites = preload("res://game/world/district_sites.gd")
const EVENT_SCRIPTS := {
	"shower": preload("res://game/world/island_event_shower.gd"),
	"wind": preload("res://game/world/island_event_wind.gd"),
	"fireworks": preload("res://game/world/island_event_fireworks.gd"),
}
const POINT_ID := "island-event"
## Seconds before trying again when nothing could start (no event fits the phase).
const RETRY := 10.0
## A stall or story point this close to the walker keeps its own prompt.
const POINT_PRIORITY := 2.0
const POINT_CLEARANCE := 1.6

var world: Node3D
## Free seconds until the next event may start (while none runs).
var countdown := Catalog.FIRST_DELAY
var active: Node3D
var active_id := ""
var last_id := ""
var paused := false

var _progress: Node
var _rng := RandomNumberGenerator.new()
var _look := ""
var _point := {"id": POINT_ID, "label": "", "position": Vector3.ZERO, "marker": null}


static func attach(owner_world: Node3D) -> Node3D:
	var director: Node3D = new()
	director.name = "IslandEvents"
	owner_world.add_child(director)
	director.configure(owner_world)
	return director


func configure(owner_world: Node3D) -> void:
	world = owner_world
	_progress = get_node_or_null("/root/Progress")
	_rng.seed = 0x5A1E
	if world.has_signal("photo_snapped"): world.photo_snapped.connect(_on_photo_snapped)


func enabled() -> bool:
	return not is_instance_valid(_progress) or bool(_progress.settings.get(Catalog.SETTING, true))


## True while the walker is free to roam: no menu, dialogue, game, ride,
## travel cover, story photo or first-visit prologue (as for the thief).
func is_free() -> bool:
	if not is_instance_valid(world) or world.blocked or not world.is_processing() or not world.is_visible_in_tree(): return false
	if world.is_riding() or world.staging_photo(): return false
	if is_instance_valid(world.field_games) and world.field_games.is_busy(): return false
	var play: Node = world.get("coastal_play")
	if is_instance_valid(play) and is_instance_valid(play.discoveries) and play.discoveries.controlling: return false
	return not is_instance_valid(_progress) or bool(_progress.intro_seen)


func is_active() -> bool:
	return is_instance_valid(active)


func _physics_process(delta: float) -> void:
	if not is_instance_valid(world.player): return
	var player: Vector3 = world.player.global_position
	advance(delta, player)
	_offer_prompt(player)


## One step of the director; tests call this with a simulated walker position.
func advance(delta: float, player: Vector3) -> void:
	var free := is_free()
	if is_active():
		_set_paused(not free)
		if not free: return
		var row := Catalog.find(active_id)
		if not enabled() or not (row.phases as Array).has(_phase()):
			finish()
			return
		_sync_look()
		if not active.step(delta, player): finish()
		return
	if not free or not enabled(): return
	countdown -= delta
	if countdown > 0.0: return
	var id := pick(_phase())
	if id.is_empty() or not start(id, player): countdown = RETRY


## A weighted pick among the events allowed in `phase`: an event whose sticker
## is still missing is twice as likely, the one just seen far less so.
func pick(phase: String) -> String:
	var choices: Array[Dictionary] = []
	var total := 0.0
	for row: Dictionary in Catalog.EVENTS:
		if not (row.phases as Array).has(phase): continue
		var weight := float(row.weight)
		if not owns(str(row.sticker)): weight *= 2.0
		if row.id == last_id: weight *= 0.25
		choices.append({"id": row.id, "weight": weight})
		total += weight
	if choices.is_empty(): return ""
	var roll := _rng.randf() * total
	for choice: Dictionary in choices:
		roll -= float(choice.weight)
		if roll <= 0.0: return str(choice.id)
	return str(choices.back().id)


## Starts an event now (tests trigger events this way). False while another runs.
func start(id: String, player := Vector3.INF) -> bool:
	if is_active() or not EVENT_SCRIPTS.has(id): return false
	if not player.is_finite(): player = world.player.global_position if is_instance_valid(world.player) else Vector3.ZERO
	active = EVENT_SCRIPTS[id].new()
	active.name = "IslandEvent_" + id
	active_id = id
	paused = false
	_look = ""
	add_child(active)
	active.begin(self, player)
	_sync_look()
	return true


## Ends the running event and frees everything it made.
func finish() -> void:
	if not is_active(): return
	var row := Catalog.find(active_id)
	active.close()
	remove_child(active)
	active.free()
	active = null
	last_id = active_id
	active_id = ""
	paused = false
	countdown = float(row.get("cooldown", 300.0))
	world.set_event_air({})
	if world.nearest.get("id", "") == POINT_ID: world.nearest = {}


func owns(sticker: String) -> bool:
	return is_instance_valid(_progress) and _progress.photos.has(sticker)


## An event's goal: the souvenir sticker, once. True when it was new.
func earn(event_id: String) -> bool:
	var sticker := str(Catalog.find(event_id).get("sticker", ""))
	if sticker.is_empty() or owns(sticker): return false
	sticker_earned.emit(sticker)
	return true


## Where the map should draw the running event's spot: {"center", "radius"}, or empty.
func map_area() -> Dictionary:
	if is_active() and active.has_method("map_area"): return active.map_area()
	return {}


## The world interaction route. True when the id was the event's.
func activate(id: String) -> bool:
	if id != POINT_ID: return false
	if is_instance_valid(world.player) and shutter(world.player.global_position): world.play_action("photograph")
	return true


## The photo key or the event prompt: takes the event's picture when it offers one.
func shutter(player: Vector3) -> bool:
	if not is_active() or not is_free() or active.prompt(player).is_empty(): return false
	sfx_requested.emit("shutter")
	active.shutter(player)
	return true


func _on_photo_snapped() -> void:
	if is_instance_valid(world.player): shutter(world.player.global_position)


# --- helpers the events share -------------------------------------------------

func say(text: String) -> void:
	notice_requested.emit(text)


func sfx(kind: String) -> void:
	sfx_requested.emit(kind)


func note(index: int) -> void:
	note_requested.emit(clampi(index, 0, 7))


func reduced() -> bool:
	return bool(world.reduced_motion)


## Picture quality "省電": events show fewer particles.
func saver() -> bool:
	return str(world.render_quality) == "low"


func rng() -> RandomNumberGenerator:
	return _rng


## Particles only exist on a real renderer, like the ambience motes.
func can_draw_particles() -> bool:
	return DisplayServer.get_name() != "headless"


func camera_basis() -> Basis:
	return world.camera.global_basis if is_instance_valid(world.camera) else Basis.looking_at(-world.CAMERA_OFFSET)


## Ground the walker may stand on, outside shut districts and clear of stalls
## and story points.
func open_ground(spot: Vector3) -> bool:
	var region := DistrictSites.ruling(Vector2(spot.x, spot.z))
	if not region.is_empty() and not (is_instance_valid(world.district_host) and world.district_host.gate_is_open(region)): return false
	if not world.is_walkable(spot): return false
	for point: Dictionary in world.points:
		var at: Vector3 = point.position
		if Vector2(at.x - spot.x, at.z - spot.z).length() < POINT_CLEARANCE: return false
	return true


## A random open spot `reach_min`..`reach_max` from `centre` on the ground; INF if none.
func spot_near(centre: Vector3, reach_min: float, reach_max: float, avoid: Array = [], spacing := 0.0) -> Vector3:
	for attempt in range(20):
		var angle := _rng.randf() * TAU
		var spot := centre + Vector3(cos(angle), 0, sin(angle)) * _rng.randf_range(reach_min, reach_max)
		if not open_ground(spot): continue
		var crowded := false
		for other: Vector3 in avoid:
			if Vector2(other.x - spot.x, other.z - spot.z).length() < spacing: crowded = true
		if crowded: continue
		return Vector3(spot.x, world.ground_surface_y(spot), spot.z)
	return Vector3.INF


func _phase() -> String:
	return str(world.active_time_phase)


func _set_paused(value: bool) -> void:
	if value == paused: return
	paused = value
	# Frozen and out of sight under a menu or game; nothing of it is heard either.
	active.visible = not value
	active.process_mode = Node.PROCESS_MODE_DISABLED if value else Node.PROCESS_MODE_INHERIT
	if value:
		world.set_event_air({})
		if is_instance_valid(world.ambience): world.ambience.gust = 0.0
	else:
		active.resume()


func _sync_look() -> void:
	var key := "%s|%s" % [reduced(), saver()]
	if key == _look: return
	_look = key
	active.set_look(reduced(), saver())


## Offers the event's shutter prompt when nothing nearer wants the walker.
func _offer_prompt(player: Vector3) -> void:
	if not is_active() or paused or not is_free(): return
	var label: String = active.prompt(player)
	if label.is_empty(): return
	var current: Dictionary = world.nearest
	if not current.is_empty() and current.get("id", "") != POINT_ID and player.distance_to(current.position) < POINT_PRIORITY: return
	_point.label = label
	_point.position = player
	world.nearest = _point
	world._set_interaction_marker(null)
