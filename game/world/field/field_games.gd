extends Node3D
## Instant games and small toys played right on the walkable map: walk up,
## press interact, play for a few seconds with the same camera, walk on.
## This layer owns everything the games share (stand, prompt, countdown,
## clock, medals, saving, result, leaving) and stays free of interface
## nodes: the HUD listens to the signals below.
##
## The island's own games hang under this layer. Each district's games and
## toys hang under that district (see add_district), so they are built with
## it, sleep with it and go with it; this layer still runs their rounds.

signal note_requested(note: int)
signal feedback_requested(kind: String)
signal round_started(info: Dictionary)
signal round_progress(seconds_left: int, score: int, medal: int)
signal round_finished(result: Dictionary)
signal round_aborted(id: String)

const Registry = preload("res://game/world/field/field_registry.gd")
const Kit = preload("res://game/world/field/field_kit.gd")
const Toys = preload("res://game/world/field/field_toys.gd")
const AmbienceProfiles = preload("res://game/world/ambience_profiles.gd")
const DistrictSites = preload("res://game/world/district_sites.gd")
const Dressing = preload("res://game/world/field/field_dressing.gd")

enum Phase { IDLE, COUNTDOWN, PLAYING, RESULT }

const COUNTDOWN_SECONDS := 2.4
const GO_SECONDS := 1.2
const RESULT_SECONDS := 4.5
const LEAVE_NOTE_SECONDS := 1.8
const MEDAL_NAMES := ["再接再厲", "銅牌", "銀牌", "金牌"]
const MEDAL_COLORS := [Color("#e8e0cc"), Color("#cf8f5a"), Color("#d5dde3"), Color("#f2c75a")]
const STAND_HEIGHT := 2.3
## The countdown and result float over the player's head.
const BANNER_ABOVE := Vector3(0, 4.25, 0)
const CAPTION_BELOW := Vector3(0, 1.3, 0)
## Clear space (view metres) kept between the banner and a game's own labels.
const BANNER_MARGIN := 0.12

var world: Node3D
var region := ""
var phase := Phase.IDLE
var time_left := 0.0
var toys: Node3D
## One entry per island game: {row, game, point, ground, pennant, pips, medal}.
var records: Array[Dictionary] = []
## Districts with games, by region: {node, root, records, toys}.
var groups: Dictionary = {}
var active: Dictionary = {}

var _progress: Node
var _clock := 0.0
var _focused := true
var _rounds := 0
var _headline: Label3D
var _caption: Label3D
var _banner_time := 0.0
var _shown_count := -1
var _last_second := -1
var _last_score := -1
var _action_point := {"id": "", "label": "", "position": Vector3.ZERO, "marker": null}
var _no_point := {}
var _hop_height := 0.0
var _hop_span := 0.0
var _hop_clock := 0.0
var _hop_repeats := 1
var _pennant: ArrayMesh
## Labels the banner must not cover during the active round: the game's own
## remarks and its sign, gathered once when the round starts.
var _avoid: Array[Label3D] = []


## Adds the layer to the island world. District rows join as each district is
## built on the island (add_district); a district world standing alone gets none.
static func attach(owner_world: Node3D) -> Node3D:
	var owner_region := AmbienceProfiles.region_for(owner_world)
	if owner_region != Registry.HOME or not Registry.has_region(owner_region):
		return null
	var layer: Node3D = new()
	layer.name = "FieldGames"
	owner_world.add_child(layer)
	layer.configure(owner_world, owner_region)
	return layer


func configure(owner_world: Node3D, owner_region: String) -> void:
	world = owner_world
	region = owner_region
	_progress = get_node_or_null("/root/Progress")
	records = _build_games(Registry.games(region), self, world)
	toys = Toys.new()
	toys.name = "FieldToys"
	add_child(toys)
	toys.configure(world, self, Registry.toys(region))
	_headline = _banner_label(72, MEDAL_COLORS[3])
	_caption = _banner_label(40, MEDAL_COLORS[0])
	if is_instance_valid(_progress):
		_progress.changed.connect(_refresh_pips)
	# Districts built before this layer existed (a restored save) join now.
	var host: Node = world.get("district_host")
	if is_instance_valid(host):
		for built: Node3D in host.districts.values():
			add_district(built)
	_refresh_pips()


## A district's games and toys, built under the district while it builds so
## its markers join its own animation. Rows are authored in the district's
## coordinates; the group's root cancels the district's offset, so every game
## works in island coordinates exactly like the island's own.
func add_district(node: Node3D) -> void:
	var owner_region := String(node.get("district"))
	if groups.has(owner_region) or not Registry.has_region(owner_region):
		return
	var root := Node3D.new()
	root.name = "FieldGames"
	node.add_child(root)
	root.position = -node.position
	var placed_games: Array = Registry.games(owner_region).map(func(row: Dictionary) -> Dictionary: return Registry.placed(row, owner_region))
	var placed_toys: Array = Registry.toys(owner_region).map(func(row: Dictionary) -> Dictionary: return Registry.placed(row, owner_region))
	var group := {"node": node, "root": root, "records": _build_games(placed_games, root, node)}
	var district_toys: Node3D = Toys.new()
	district_toys.name = "FieldToys"
	root.add_child(district_toys)
	district_toys.configure(world, self, placed_toys, node)
	group["toys"] = district_toys
	groups[owner_region] = group
	# Rows on the island's edge band belong to the island on the map and in
	# travel; only those inside the district's own ground carry its name.
	var ids := _group_ids(group)
	for point: Dictionary in world.points:
		if ids.has(String(point.id)) and DistrictSites.ruling(Vector2(point.position.x, point.position.z)) != owner_region:
			point.erase("region")
	# The district's own list feeds its regional map of stalls and stories;
	# the island's list (above) is the one the walker and the island map use.
	for index in range(node.points.size() - 1, -1, -1):
		if ids.has(String(node.points[index].id)):
			node.points.remove_at(index)
	root.tree_exiting.connect(_drop_district.bind(owner_region), CONNECT_ONE_SHOT)
	_refresh_pips()


## The district is going away: its round ends and its points leave the island.
func _drop_district(owner_region: String) -> void:
	var group: Dictionary = groups.get(owner_region, {})
	if group.is_empty():
		return
	groups.erase(owner_region)
	if phase != Phase.IDLE and String(active.row.get("region", "")) == owner_region:
		var id := String(active.row.id)
		phase = Phase.IDLE
		active = {}
		_land()
		_hide_banner()
		round_aborted.emit(id)
	var ids := _group_ids(group)
	for index in range(world.points.size() - 1, -1, -1):
		if ids.has(String(world.points[index].id)):
			world.points.remove_at(index)


func _group_ids(group: Dictionary) -> Dictionary:
	var ids := {}
	for record: Dictionary in group.records:
		ids[Registry.point_id(record.row)] = true
	for item: Dictionary in (group.toys as Node3D).items:
		ids[item.id] = true
	return ids


## Each row's sign and game under `parent`; `owner` (the island or a
## district) lists the interaction point in its own coordinates. A district's
## stations also get their themed floor and props.
func _build_games(rows: Array, parent: Node3D, owner: Node3D) -> Array[Dictionary]:
	var built: Array[Dictionary] = []
	var posts: Array[Vector3] = []
	var bulbs: Array[Transform3D] = []
	var owner_region := region if owner == world else String(owner.get("district"))
	if _pennant == null:
		_pennant = _pennant_mesh()
	for row: Dictionary in rows:
		var script := load(String(row.script)) as GDScript
		if script == null or not script.can_instantiate():
			push_warning("Field game '%s' has no usable script; it was skipped." % String(row.id))
			continue
		var at: Vector3 = row.at
		var ground := Vector3(at.x, world.ground_surface_y(at), at.z)
		var record := {"row": row, "ground": ground}
		posts.append_array(Dressing.build_sign(world, parent, record, owner_region, _pennant, bulbs))
		var game: Node3D = script.new()
		parent.add_child(game)
		game.setup(world, self, row)
		record["game"] = game
		owner._point(Registry.point_id(row), String(row.prompt), owner.to_local(ground), STAND_HEIGHT + 1.0)
		record["point"] = world.points[-1]
		built.append(record)
	if not posts.is_empty():
		Kit.posts(world, parent, posts, Dressing.POST_HEIGHT, Dressing.theme(owner_region).cap, 0.075)
	Dressing.build_bulbs(world, parent, bulbs, owner_region)
	if owner != world:
		var avoid: Array[Vector3] = []
		for point: Dictionary in world.points:
			avoid.append(point.position)
		for row: Dictionary in Registry.placed_toys():
			avoid.append(row.at)
		Dressing.build_grounds(world, parent, built, owner_region, _walkable.bind(owner), avoid)
	return built


## Whether a ground point (island coordinates) can be stood on, asking the
## district being built for its own ground (the host does not list it yet).
func _walkable(at: Vector3, owner: Node3D) -> bool:
	var ruler := DistrictSites.ruling(Vector2(at.x, at.z))
	if ruler == String(owner.get("district")):
		return owner.is_walkable(owner.to_local(at))
	return world.is_walkable(at)


static func _pennant_mesh() -> ArrayMesh:
	var points := [Vector3(0.05, 0.28, 0), Vector3(0.05, -0.28, 0), Vector3(1.1, 0.0, 0)]
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	for order in [[0, 2, 1], [0, 1, 2]]:
		var normal: Vector3 = (points[order[2]] - points[order[0]]).cross(points[order[1]] - points[order[0]]).normalized()
		for index: int in order:
			vertices.append(points[index])
			normals.append(normal)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	var shape := ArrayMesh.new()
	shape.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return shape


func _banner_label(size: int, color: Color) -> Label3D:
	var item := Kit.label(self, "", Vector3.ZERO, size, color)
	item.no_depth_test = true
	item.render_priority = 4
	item.outline_render_priority = 3
	item.visible = false
	return item


func record_for(id: String) -> Dictionary:
	for record in all_records():
		if Registry.point_id(record.row) == id:
			return record
	return {}


## The island's games and those of every built district.
func all_records() -> Array[Dictionary]:
	var every: Array[Dictionary] = records.duplicate()
	for group: Dictionary in groups.values():
		every.append_array(group.records)
	return every


## True while a district is near enough to run (the island always is).
func is_awake(owner_region: String) -> bool:
	var host: Node = world.get("district_host")
	return not groups.has(owner_region) or not is_instance_valid(host) or host.is_awake(owner_region)


func _toys_with(id: String) -> Node3D:
	if not toys.item_for(id).is_empty():
		return toys
	for owner_region: String in groups:
		var group_toys: Node3D = groups[owner_region].toys
		if not group_toys.item_for(id).is_empty():
			return group_toys if is_awake(owner_region) else null
	return null


static func medal_for(row: Dictionary, score: int) -> int:
	var medal := 0
	for threshold: int in row.medals:
		if score >= threshold:
			medal += 1
	return medal


func best_for(row: Dictionary) -> Dictionary:
	if not is_instance_valid(_progress):
		return {}
	return _progress.field_records.get(String(row.id), {})


func is_busy() -> bool:
	return phase == Phase.COUNTDOWN or phase == Phase.PLAYING


func _paused() -> bool:
	return not is_instance_valid(world) or world.blocked or not world.is_processing() or not _focused


## The world interaction route: starts a game or plays with a toy.
func activate(id: String) -> bool:
	if id.begins_with("toy:"):
		var owner_toys := _toys_with(id)
		return owner_toys != null and not _paused() and not is_busy() and owner_toys.activate(id)
	var record := record_for(id)
	if record.is_empty():
		return false
	if not _paused() and not is_busy():
		_start_countdown(record)
	return true


## The interact key while a round is on. True when the key was used up.
func press() -> bool:
	if not is_busy():
		return false
	if phase == Phase.PLAYING and not _paused():
		active.game.press()
	return true


## Leaves the current round without a result. True when there was one.
func abort() -> bool:
	if not is_busy():
		return false
	_leave()
	return true


## A short line above the play area, for a game's own remarks during a round.
func say(text: String, duration: float) -> void:
	_caption.text = text
	_caption.visible = true
	_banner_time = duration


func hop(height: float, duration: float, repeats := 1) -> void:
	_hop_height = height
	_hop_span = maxf(duration, 0.01)
	_hop_repeats = maxi(repeats, 1)
	_hop_clock = 0.0


func _physics_process(delta: float) -> void:
	advance(delta)


## One step of every game and toy; tests call this directly.
func advance(delta: float) -> void:
	if _paused() or not is_instance_valid(world.player):
		return
	var player: Vector3 = world.player.global_position
	_advance_hop(delta)
	_sway_pennants()
	toys.advance(delta, player)
	for owner_region: String in groups:
		# A sleeping district's toys hold still until the walker comes back.
		if is_awake(owner_region):
			groups[owner_region].toys.advance(delta, player)
	if _headline.visible or _caption.visible:
		_place_banner(player)
	if _banner_time > 0.0:
		_banner_time -= delta
		if _banner_time <= 0.0 and phase != Phase.RESULT and phase != Phase.COUNTDOWN:
			_hide_banner()
	if phase == Phase.IDLE:
		return
	var game: Node3D = active.game
	match phase:
		Phase.COUNTDOWN:
			_clock -= delta
			if _left_arena(player):
				_leave()
			elif _clock <= 0.0:
				_begin_round()
			else:
				_show_count(ceili(_clock / (COUNTDOWN_SECONDS / 3.0)))
		Phase.PLAYING:
			game.elapsed += delta
			game.step(delta, player)
			time_left = maxf(0.0, game.seconds - game.elapsed)
			if _left_arena(player) or not is_awake(String(active.row.get("region", ""))):
				_leave()
				return
			_publish_progress()
			if game.finished or time_left <= 0.0:
				_finish_round()
		Phase.RESULT:
			_clock -= delta
			game.show_step(delta, player)
			if _clock <= 0.0:
				_to_idle()
	if is_busy():
		# Nothing else on the map answers the interact key during a round.
		_action_point.label = game.action_label() if phase == Phase.PLAYING else ""
		world.nearest = _action_point if not String(_action_point.label).is_empty() else _no_point
		world._set_interaction_marker(null)


func _left_arena(player: Vector3) -> bool:
	var row: Dictionary = active.row
	var centre: Vector3 = row.get("arena", row.at)
	return Vector2(player.x - centre.x, player.z - centre.z).length() > float(row.radius)


func _start_countdown(record: Dictionary) -> void:
	if phase == Phase.RESULT:
		active.game.reset()
	active = record
	var row: Dictionary = record.row
	var game: Node3D = record.game
	_avoid.clear()
	for item: Node in game.find_children("*", "Label3D", true, false):
		_avoid.append(item as Label3D)
	for item: Label3D in record.get("sign_labels", []):
		_avoid.append(item)
	game.reset()
	game.ready_up()
	game.rng.seed = hash(String(row.id)) + _rounds
	_rounds += 1
	phase = Phase.COUNTDOWN
	_clock = COUNTDOWN_SECONDS
	_shown_count = -1
	_action_point.id = Registry.point_id(row)
	_action_point.position = record.ground
	_place_banner(world.player.global_position)
	# One line stands in for a tutorial page.
	_caption.text = String(row.get("hint", ""))
	_caption.visible = true
	_show_count(3)
	round_started.emit({
		"id": String(row.id), "title": String(row.title), "medals": row.medals,
		"seconds": game.seconds, "best": int(best_for(row).get("best", 0)),
	})


func _show_count(count: int) -> void:
	if count == _shown_count:
		return
	_shown_count = count
	_headline.text = str(count)
	_headline.modulate = MEDAL_COLORS[3]
	_headline.visible = true
	note_requested.emit(0)


func _begin_round() -> void:
	var game: Node3D = active.game
	game.score = 0
	game.elapsed = 0.0
	game.finished = false
	time_left = game.seconds
	_last_second = -1
	_last_score = -1
	phase = Phase.PLAYING
	game.begin()
	_headline.text = "開始！"
	_headline.modulate = MEDAL_COLORS[3]
	_banner_time = GO_SECONDS
	note_requested.emit(3)
	_publish_progress()


func _publish_progress() -> void:
	var second := ceili(time_left)
	var game: Node3D = active.game
	if second == _last_second and game.score == _last_score:
		return
	_last_second = second
	_last_score = game.score
	round_progress.emit(second, game.score, medal_for(active.row, game.score))


func _finish_round() -> void:
	var row: Dictionary = active.row
	var game: Node3D = active.game
	var medal := medal_for(row, game.score)
	var saved := {"saved": true, "coins": 0, "best": game.score, "new_best": false}
	if is_instance_valid(_progress):
		saved = _progress.record_field_result(String(row.id), game.score, medal)
	var line: String = game.comment(medal) if bool(saved.saved) else "成績沒有存到，再玩一次試試"
	phase = Phase.RESULT
	_clock = RESULT_SECONDS
	_banner_time = 0.0
	_land()
	game.conclude(medal)
	_headline.text = "%s　%d 分" % [MEDAL_NAMES[medal], game.score]
	_headline.modulate = MEDAL_COLORS[medal]
	_headline.visible = true
	_caption.text = line
	_caption.visible = true
	feedback_requested.emit("success" if medal > 0 else "miss")
	if medal > 0:
		world.play_action("celebrate")
	_refresh_pips()
	round_finished.emit({
		"id": String(row.id), "title": String(row.title), "score": game.score, "medal": medal,
		"medal_name": MEDAL_NAMES[medal], "line": line, "coins": int(saved.coins),
		"best": int(saved.best), "new_best": bool(saved.new_best), "saved": bool(saved.saved),
	})


func _leave() -> void:
	var id := String(active.row.id)
	active.game.reset()
	phase = Phase.IDLE
	_land()
	_headline.visible = false
	_caption.text = "先走一步？隨時回來玩"
	_caption.visible = true
	_banner_time = LEAVE_NOTE_SECONDS
	feedback_requested.emit("miss")
	round_aborted.emit(id)


func _to_idle() -> void:
	active.game.reset()
	phase = Phase.IDLE
	_hide_banner()


func _place_banner(player: Vector3) -> void:
	_headline.position = player + BANNER_ABOVE
	_caption.position = _headline.position - CAPTION_BELOW
	var lift := _banner_lift()
	_headline.position.y += lift
	_caption.position.y += lift


## How far to raise the banner so that, as seen by the camera, it clears every
## label of the active game (a cheer, an order bubble, the sign).
func _banner_lift() -> float:
	var camera: Camera3D = world.get("camera")
	if not is_instance_valid(camera) or _avoid.is_empty():
		return 0.0
	var view := camera.global_basis
	var rise := maxf(view.y.y, 0.2)
	var head := _view_box(_headline, view)
	var foot := _view_box(_caption, view) if _caption.visible and not _caption.text.is_empty() else head
	var left := minf(head.x - head.z, foot.x - foot.z)
	var right := maxf(head.x + head.z, foot.x + foot.z)
	var bottom := foot.y - foot.w
	var height := head.y + head.w - bottom
	var lift := 0.0
	# A few passes: clearing one label can push the banner into a higher one.
	for _pass in range(3):
		var raised := false
		for item in _avoid:
			if not is_instance_valid(item) or item.text.is_empty() or not item.is_visible_in_tree():
				continue
			var box := _view_box(item, view)
			if box.x + box.z < left or box.x - box.z > right:
				continue
			var low := bottom + lift * rise
			if box.y - box.w > low + height + BANNER_MARGIN or box.y + box.w < low - BANNER_MARGIN:
				continue
			lift = (box.y + box.w + BANNER_MARGIN - bottom) / rise
			raised = true
		if not raised:
			break
	return lift


## A label's rough extent as the camera sees it: centre x, centre y, half
## width, half height, in view metres. Wide glyphs make this a slight overestimate.
static func _view_box(item: Label3D, view: Basis) -> Vector4:
	var at := item.global_position
	var em := item.font_size * item.pixel_size
	return Vector4(view.x.dot(at), view.y.dot(at), maxi(item.text.length(), 1) * em * 0.5, em * 0.6)


func _hide_banner() -> void:
	_headline.visible = false
	_caption.visible = false


func _land() -> void:
	_hop_clock = _hop_span
	world.avatar_visual_lift = 0.0


func _advance_hop(delta: float) -> void:
	if _hop_clock >= _hop_span:
		if world.avatar_visual_lift != 0.0:
			world.avatar_visual_lift = 0.0
		return
	_hop_clock = minf(_hop_span, _hop_clock + delta)
	var arc := sin(PI * fposmod(_hop_clock / _hop_span * _hop_repeats, 1.0))
	world.avatar_visual_lift = 0.0 if world.reduced_motion or _hop_clock >= _hop_span else _hop_height * arc


func _sway_pennants() -> void:
	_sway(records, 0)
	for owner_region: String in groups:
		if is_awake(owner_region):
			_sway(groups[owner_region].records, owner_region.length())


func _sway(list: Array[Dictionary], offset: int) -> void:
	for index in range(list.size()):
		var pennant: MeshInstance3D = list[index].pennant
		pennant.rotation.y = 0.0 if world.reduced_motion else sin(world.time * 2.1 + (index + offset) * 1.7) * 0.32


func _refresh_pips() -> void:
	for record in all_records():
		var medal := int(best_for(record.row).get("medal", 0))
		record["medal"] = medal
		var pips: MultiMesh = record.pips
		for index in range(pips.instance_count):
			pips.set_instance_color(index, MEDAL_COLORS[index + 1] if index < medal else Dressing.PIP_OFF)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_focused = false
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_focused = true
	elif what == NOTIFICATION_EXIT_TREE and is_instance_valid(world):
		world.avatar_visual_lift = 0.0
