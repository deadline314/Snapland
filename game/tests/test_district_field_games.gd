extends SceneTree
## Instant map games and toys in the themed districts: the placement table,
## the district lifecycle (built with the district, paused while it sleeps,
## gone when it goes), every district game played to bronze and to gold by
## simulated visitors, every toy answering a poke, and stable node counts.

const Registry = preload("res://game/world/field/field_registry.gd")
const FieldGames = preload("res://game/world/field/field_games.gd")
const DistrictSites = preload("res://game/world/district_sites.gd")
const SceneStandards = preload("res://game/world/scene_standards.gd")
const STEP := 1.0 / 60.0
const RUN_SPEED := 1.5
const STROLL_SPEED := 0.8
const WELCOME_TYPES := ["踩踏", "追逐", "時機", "收集競速", "拍照"]
## The districts MAIN-61 gave instant games and toys. A district joins this list
## with its own rows; the hotel (MAIN-63) has none yet.
const FIELD_DISTRICTS := ["harbor", "candy", "nightmarket", "circus", "toy", "garden"]

var failures: Array[String] = []
var main: Node
var world: Node3D
var field: Node3D
var progress: Node
var finished: Array[Dictionary] = []
var aborted: Array[String] = []
var sounds: Array[String] = []


func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)


func _initialize() -> void:
	if not OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path():
		quit(2)
		return
	call_deferred("_run")


func frames(count: int) -> void:
	for index in count:
		await physics_frame


func _run() -> void:
	progress = root.get_node("Progress")
	progress.reset_progress()
	progress.intro_seen = true
	progress.save_progress()
	main = load("res://game/main.tscn").instantiate()
	root.add_child(main)
	await frames(4)
	world = main.world
	field = world.field_games
	field.round_finished.connect(func(result: Dictionary) -> void: finished.append(result))
	field.round_aborted.connect(func(id: String) -> void: aborted.append(id))
	field.feedback_requested.connect(func(kind: String) -> void: sounds.append(kind))
	_test_table()
	await _test_lifecycle()
	field.set_physics_process(false)
	# Hold the island's streaming still: districts are built and woken here.
	world.set_physics_process(false)
	for region: String in DistrictSites.regions():
		world.district_host.ensure(region)
		_wake(region, true)
	_test_placement()
	_test_harbor()
	_test_candy()
	_test_nightmarket()
	_test_circus()
	_test_toy()
	_test_garden()
	_test_toys()
	_test_stable_nodes()
	_test_free()
	main.audio.shutdown()
	await create_timer(0.15).timeout
	main.queue_free()
	await frames(5)
	if failures.is_empty():
		print("PASS: district instant games: table, lifecycle, twelve games, twelve toys and stable nodes")
	quit(0 if failures.is_empty() else 1)


# --- helpers ---

func _wake(region: String, awake: bool) -> void:
	var node: Node3D = world.district_host.built(region)
	if node != null:
		world.district_host._set_awake(node, awake)


func record(id: String) -> Dictionary:
	return field.record_for("field:" + id)


func row(id: String) -> Dictionary:
	return record(id).row


func game(id: String) -> Node3D:
	return record(id).game


func arena(id: String) -> Vector3:
	var entry := row(id)
	return entry.get("arena", entry.at)


func place(at: Vector3) -> void:
	world.player.global_position = Vector3(at.x, world.ground_surface_y(at) + 0.3, at.z)


func feet() -> Vector3:
	return world.player.global_position


func walk(to: Vector3, speed: float) -> void:
	var here := feet()
	var offset := Vector2(to.x - here.x, to.z - here.z).limit_length(speed * STEP)
	place(here + Vector3(offset.x, 0, offset.y))


func advance(seconds: float) -> void:
	for index in range(roundi(seconds / STEP)):
		field.advance(STEP)


func begin(id: String) -> void:
	place(arena(id))
	finished.clear()
	main._interact("field:" + id, "")
	advance(FieldGames.COUNTDOWN_SECONDS + STEP)


func play_round(id: String, play: Callable) -> Dictionary:
	begin(id)
	check(field.phase == FieldGames.Phase.PLAYING, "%s starts through the interaction route" % id)
	var limit := roundi((float(row(id).seconds) + 2.0) / STEP)
	for index in range(limit):
		if field.phase != FieldGames.Phase.PLAYING:
			break
		play.call()
		field.advance(STEP)
	check(finished.size() == 1, "%s finishes exactly once within its clock" % id)
	if not finished.is_empty():
		print("  %s: %d points, medal %d" % [id, int(finished[0].score), int(finished[0].medal)])
	advance(FieldGames.RESULT_SECONDS + STEP)
	check(field.phase == FieldGames.Phase.IDLE, "%s returns to idle after its result" % id)
	return finished[0] if not finished.is_empty() else {"score": -1, "medal": -1}


## A keen visitor earns gold and a casual one a lower medal, with and without
## reduced motion, and someone who only stands about earns nothing.
func medal_runs(id: String, keen: Callable, casual: Callable, idle := Callable()) -> void:
	var gold := play_round(id, keen)
	check(int(gold.medal) == 3, "%s: a keen visitor earns gold (scored %d)" % [id, int(gold.score)])
	var bronze := play_round(id, casual)
	check(int(bronze.medal) >= 1 and int(bronze.medal) < 3, "%s: a casual visitor earns a lower medal (scored %d)" % [id, int(bronze.score)])
	progress.set_setting("reduced_motion", true)
	var steady := play_round(id, keen)
	check(int(steady.medal) == 3 and world.avatar_visual_lift == 0.0, "%s: reduced motion plays to the same gold (scored %d)" % [id, int(steady.score)])
	progress.set_setting("reduced_motion", false)
	if idle.is_valid():
		var lazy := play_round(id, idle)
		check(int(lazy.medal) == 0, "%s: standing about earns nothing (scored %d)" % [id, int(lazy.score)])
		check(String(lazy.line) == String(row(id).lines[0]), "%s: no medal gets the funny line" % id)


func stand_still() -> void:
	pass


func other_points() -> Array[Vector3]:
	var spots: Array[Vector3] = []
	for point: Dictionary in world.points:
		var id := String(point.id)
		if not id.begins_with("field:") and not id.begins_with("toy:"):
			spots.append(point.position)
	return spots


# --- the table ---

func _test_table() -> void:
	var types := {}
	for region: String in DistrictSites.regions():
		check(FIELD_DISTRICTS.has(region) == Registry.has_region(region), "%s has instant games exactly when it is a field district" % region)
	for region: String in FIELD_DISTRICTS:
		var games: Array = Registry.games(region)
		var toys: Array = Registry.toys(region)
		check(games.size() >= 2 and toys.size() >= 2, "%s has at least two instant games and two toys" % region)
		for entry: Dictionary in games:
			var kind := String(entry.type)
			check(not WELCOME_TYPES.has(kind) and not types.has(kind), "%s plays a kind of its own (%s)" % [entry.id, kind])
			types[kind] = true
			check(String(entry.prompt).length() <= 8 and not String(entry.hint).contains("\n"), "%s has a one-line prompt and hint" % entry.id)
	check(types.size() >= 12, "twelve district games cover twelve kinds of play (%d)" % types.size())
	# The district checker notices each kind of misplaced row.
	var walk_all := func(_spot: Vector3) -> bool: return true
	var none: Array[Vector3] = []
	var stray := Registry.placed(Registry.games("harbor")[0], "harbor").duplicate(true)
	stray.id = "probe-stray"
	stray.erase("layout")
	stray.at = DistrictSites.to_world("candy", Vector3(0, 0, -5))
	stray.arena = stray.at
	check(_has(Registry.district_problems("harbor", walk_all, none, [stray]), "in the candy district"), "a harbor row inside the candy factory is rejected")
	var strip := DistrictSites.world_rect("toy", "approach").get_center()
	stray.at = Vector3(strip.x, 0, strip.y)
	stray.arena = stray.at
	check(_has(Registry.district_problems("harbor", walk_all, none, [stray]), "toy approach"), "a row on an approach is rejected")
	stray.at = Registry.placed(Registry.games("candy")[0], "candy").at + Vector3(5, 0, 0)
	stray.arena = stray.at
	check(_has(Registry.district_problems("harbor", walk_all, none, [stray]), "needs 14 m"), "rows are spaced against other districts' rows too")
	var twin := stray.duplicate(true)
	twin.id = Registry.games("candy")[0].id
	twin.at = Vector3(0, 0, -400)
	twin.arena = twin.at
	check(_has(Registry.district_problems("harbor", walk_all, none, [twin]), "registered twice"), "ids are unique across every region")


func _has(found: Array[String], text: String) -> bool:
	for problem in found:
		if problem.contains(text):
			return true
	return false


func _test_placement() -> void:
	for region: String in FIELD_DISTRICTS:
		var found := Registry.district_problems(region, world.is_walkable, other_points())
		check(found.is_empty(), "%s placement is sound: %s" % [region, str(found)])
		var node: Node3D = world.district_host.built(region)
		var group: Dictionary = field.groups.get(region, {})
		check(not group.is_empty() and group.records.size() == Registry.games(region).size() and group.toys.items.size() == Registry.toys(region).size(),
			"%s builds every game and toy" % region)
		if group.is_empty():
			continue
		check((group.root as Node3D).get_parent() == node and (group.root as Node3D).global_position.is_zero_approx(), "%s keeps its games under the district" % region)
		for entry: Dictionary in Registry.games(region):
			var point: Dictionary = world._point_by_id(Registry.point_id(entry))
			var inside := DistrictSites.ruling(Vector2(point.position.x, point.position.z)) == region
			check(not point.is_empty() and String(point.get("region", "")) == (region if inside else ""), "%s is listed with the ground it stands on" % entry.id)
			check(point.position.distance_to(DistrictSites.to_world(region, entry.at)) < 0.5, "%s stands where its row says" % entry.id)
		var audit := SceneStandards.audit(group.root, region)
		for rule: String in SceneStandards.RULES:
			check((audit[rule] as Array).is_empty(), "%s games meet the scene standard '%s': %s" % [region, rule, str(audit[rule])])
		var nodes := node.find_children("*", "Node", true, false).size() + 1
		check(nodes <= SceneStandards.DEFAULT_NODE_BUDGET, "%s stays inside its node budget with its games (%d)" % [region, nodes])
		print("  %s: %d nodes, %d in its games and toys" % [region, nodes, (group.root as Node3D).find_children("*", "Node", true, false).size() + 1])


# --- lifecycle ---

func _test_lifecycle() -> void:
	var region := "harbor"
	var id := String(Registry.games(region)[0].id)
	check(world.district_host.built(region) == null and record(id).is_empty() and world._point_by_id("field:" + id).is_empty(),
		"a district's games do not exist before the district is built")
	var node: Node3D = world.district_host.ensure(region)
	check(node != null and not record(id).is_empty(), "building the district registers its games")
	var marker: Label3D = world._point_by_id("field:" + id).get("marker")
	check(marker != null and node.is_ancestor_of(marker), "the game's marker belongs to the district")
	# Asleep: toys hold still and rounds cannot start or continue.
	field.set_physics_process(false)
	_wake(region, true)
	var toy_id := Registry.point_id(Registry.toys(region)[0], true)
	var item: Dictionary = field.groups[region].toys.item_for(toy_id)
	_wake(region, false)
	place(DistrictSites.to_world(region, Registry.toys(region)[0].at))
	check(not field.activate(toy_id), "a sleeping district's toy cannot be poked")
	var resting := float(item.t)
	advance(0.5)
	check(is_equal_approx(float(item.t), resting), "a sleeping district's toys are paused")
	_wake(region, true)
	advance(0.5)
	check(float(item.t) > resting or resting >= 99.0, "an awake district's toys run again")
	begin(id)
	check(field.phase == FieldGames.Phase.PLAYING, "a district game starts while the district is awake")
	aborted.clear()
	_wake(region, false)
	advance(0.1)
	check(field.phase == FieldGames.Phase.IDLE and aborted == [id], "a district falling asleep ends its round without a result")
	_wake(region, true)
	advance(FieldGames.LEAVE_NOTE_SECONDS + 0.1)
	await frames(1)


func _test_free() -> void:
	var region := "garden"
	var node: Node3D = world.district_host.built(region)
	var ids: Array[String] = []
	for entry: Dictionary in Registry.games(region):
		ids.append(Registry.point_id(entry))
	for entry: Dictionary in Registry.toys(region):
		ids.append(Registry.point_id(entry, true))
	begin(String(Registry.games(region)[0].id))
	aborted.clear()
	world.district_host.districts.erase(region)
	node.get_parent().remove_child(node)
	node.free()
	check(not field.groups.has(region) and field.phase == FieldGames.Phase.IDLE and aborted.size() == 1, "freeing a district ends its round and forgets its games")
	var left := 0
	for point: Dictionary in world.points:
		if ids.has(String(point.id)):
			left += 1
	check(left == 0, "freeing a district removes its game and toy points from the island")
	check(record(String(Registry.games(region)[0].id)).is_empty(), "its games can no longer be found")


# --- the twelve games ---

func _test_harbor() -> void:
	medal_runs("harbor-fish-net", _fisher.bind(RUN_SPEED), _fisher.bind(STROLL_SPEED), stand_still)
	var fish := game("harbor-fish-net")
	begin("harbor-fish-net")
	advance(15.0)
	check(fish.flopped > 0, "uncaught fish flop on the sand")
	field.abort()
	advance(FieldGames.LEAVE_NOTE_SECONDS + 0.1)
	medal_runs("harbor-crate-stack", _crane.bind(0.08, 0.0), _crane.bind(0.3, 2.6), stand_still)
	var mashed := play_round("harbor-crate-stack", _masher)
	check(int(mashed.medal) < 3, "harbor-crate-stack: hammering the key does not earn gold (scored %d)" % int(mashed.score))


## Runs for the ring of the fish that lands soonest, keeping off puffers.
func _fisher(speed: float) -> void:
	var fish := game("harbor-fish-net")
	var best := -1
	var soonest := INF
	for index in range(fish.POOL):
		if fish.state[index] != 1 or fish.puffer[index] == 1:
			continue
		var left: float = fish.span[index] - fish.clock[index]
		if left < soonest:
			soonest = left
			best = index
	var to: Vector3 = fish.landing(best) if best >= 0 else arena("harbor-fish-net")
	for index in range(fish.POOL):
		# Step out of a puffer's ring before it lands.
		if fish.state[index] == 1 and fish.puffer[index] == 1 and fish.span[index] - fish.clock[index] < 0.3 and fish.flat_distance(feet(), fish.landing(index)) < 0.9:
			to = fish.landing(index) + (feet() - fish.landing(index)).normalized() * 1.2
	walk(to, speed)


var _last_drop := 0.0

## Lets go when the hook is over the pile, but no sooner than `wait` seconds after the last crate.
func _crane(slack: float, wait: float) -> void:
	var crane := game("harbor-crate-stack")
	if crane.elapsed < _last_drop:
		_last_drop = 0.0
	if absf(crane.hook_x - crane.top_x()) < slack and crane.elapsed - _last_drop >= wait and crane.mode == 0:
		_last_drop = crane.elapsed
		field.press()


func _masher() -> void:
	field.press()


func _test_candy() -> void:
	medal_runs("candy-gumball", _header.bind(RUN_SPEED), _header.bind(STROLL_SPEED), stand_still)
	var gum := game("candy-gumball")
	check(gum.splats > 0, "a gumball left alone splats on the mat")
	medal_runs("candy-sort", _sorter.bind(RUN_SPEED), _sorter.bind(STROLL_SPEED * 0.6), stand_still)
	# Holding one pedal sends every candy the same way: the wrong half is spat back.
	sounds.clear()
	var sort := game("candy-sort")
	var lazy := play_round("candy-sort", func() -> void: walk(sort.pad(0), RUN_SPEED))
	check(sort.wrong > 0 and int(lazy.medal) < 3 and sounds.has("miss"), "candy-sort: camping on one pedal gets candy spat back (scored %d)" % int(lazy.score))


func _header(speed: float) -> void:
	var gum := game("candy-gumball")
	var best := -1
	for index in range(gum.BALLS):
		if gum.live[index] == 1 and gum.splat[index] <= 0.0 and (best < 0 or gum.time_left(index) < gum.time_left(best)):
			best = index
	walk(gum.landing(best) if best >= 0 else arena("candy-gumball"), speed)


func _sorter(speed: float) -> void:
	var sort := game("candy-sort")
	var next: int = sort.next_candy()
	if next >= 0:
		walk(sort.pad(sort.color[next]), speed)


func _test_nightmarket() -> void:
	medal_runs("night-goldfish", _scooper.bind(RUN_SPEED, 0.0), _scooper.bind(STROLL_SPEED, 0.5), stand_still)
	var tub := game("night-goldfish")
	begin("night-goldfish")
	place(tub.net_at(arena("night-goldfish") + Vector3(3, 0, 0)) + Vector3(1.1, 0, 0))
	var paper: int = tub.paper
	for index in range(tub.PAPER):
		while tub.under(tub.net_at(feet())) >= 0:
			field.advance(STEP)
		field.press()
		advance(tub.DIP_SECONDS + STEP)
	check(paper == tub.PAPER and tub.tears == 1, "three empty dips tear the paper net")
	field.abort()
	advance(FieldGames.LEAVE_NOTE_SECONDS + 0.1)
	medal_runs("night-order", _cook.bind(RUN_SPEED), _cook.bind(STROLL_SPEED * 0.6), stand_still)
	var order := game("night-order")
	begin("night-order")
	while order.wanted() < 0:
		field.advance(STEP)
	var wrong: int = (order.wanted() + 1) % order.FOODS.size()
	for index in range(240):
		walk(order.plate(wrong), RUN_SPEED)
		field.advance(STEP)
	check(order.botched == 1 and order.score == 0, "a wrong plate botches the order and scores nothing")
	field.abort()
	advance(FieldGames.LEAVE_NOTE_SECONDS + 0.1)


var _dip_wait := 0.0

## Walks round the rim to the nearest catchable fish and dips when it is under the net.
func _scooper(speed: float, hesitate: float) -> void:
	var tub := game("night-goldfish")
	var middle := arena("night-goldfish")
	var best := -1
	var gap := INF
	for index in range(tub.FISH):
		if index == tub.BLACK or tub.away[index] > 0.0:
			continue
		var reach: float = tub.flat_distance(tub.fish_at(index), tub.net_at(feet()))
		if reach < gap:
			gap = reach
			best = index
	if best >= 0:
		var out: Vector3 = tub.fish_at(best) - middle
		out.y = 0.0
		walk(middle + out.normalized() * 2.0, speed)
	var under: int = tub.under(tub.net_at(feet()))
	_dip_wait = _dip_wait + STEP if under >= 0 and under != tub.BLACK else 0.0
	if _dip_wait > hesitate and under >= 0 and under != tub.BLACK:
		_dip_wait = 0.0
		field.press()


func _cook(speed: float) -> void:
	var order := game("night-order")
	var plate: int = order.wanted()
	walk(order.plate(plate) if plate >= 0 else arena("night-order") + Vector3(0, 0, 1.4), speed)


func _test_circus() -> void:
	medal_runs("circus-spotlight", _follower.bind(RUN_SPEED), _follower.bind(STROLL_SPEED * 0.7), stand_still)
	var light := game("circus-spotlight")
	check(light.boos > 0, "standing outside the light gets booed")
	medal_runs("circus-cups", _guesser.bind(true), _guesser.bind(false), stand_still)
	var cups := game("circus-cups")
	check(cups.cups == 4 or cups.right < 3, "a fourth cup joins after three right guesses")


func _follower(speed: float) -> void:
	walk(game("circus-spotlight").light_at(), speed)


## Watches the ball (or just picks the middle cup) and lifts it.
func _guesser(sharp: bool) -> void:
	var cups := game("circus-cups")
	if cups.mode != cups.PICK:
		walk(arena("circus-cups") + Vector3(0, 0, 0.6), RUN_SPEED)
		return
	var goal: Vector3 = cups.ball_slot() if sharp else cups._slots[1]
	walk(Vector3(goal.x, 0, arena("circus-cups").z + 0.0), RUN_SPEED)
	var near: int = cups.cup_near(feet())
	if near >= 0 and cups.flat_distance(feet(), Vector3(goal.x, 0, arena("circus-cups").z)) < 0.05:
		field.press()


func _test_toy() -> void:
	medal_runs("toy-cans", _bowler.bind(0.03), _bowler.bind(0.4), stand_still)
	var cans := game("toy-cans")
	begin("toy-cans")
	place(Vector3(cans._line.x + 1.4, 0, cans._line.z + 0.4))
	field.press()
	advance(2.5)
	check(cans.bonks == 1 and world.avatar_visual_lift >= 0.0, "a ball that hits nothing comes back and bonks you")
	field.abort()
	advance(FieldGames.LEAVE_NOTE_SECONDS + 0.1)
	medal_runs("toy-statue", _creeper.bind(RUN_SPEED, true), _creeper.bind(STROLL_SPEED, true), stand_still)
	var soldier := game("toy-statue")
	var reckless := play_round("toy-statue", _creeper.bind(RUN_SPEED, false))
	check(soldier.caught > 0 and int(reckless.medal) < 3, "running while he watches gets you caught and costs gold (scored %d, caught %d)" % [int(reckless.score), soldier.caught])


func _bowler(sloppy: float) -> void:
	var cans := game("toy-cans")
	var up: PackedInt32Array = cans.standing_cans()
	var aim := INF
	# Between two standing bottom cans takes both; otherwise straight at one.
	for pair in [[0, 1], [1, 2]]:
		if up.has(pair[0]) and up.has(pair[1]):
			aim = (cans.can_x(pair[0]) + cans.can_x(pair[1])) * 0.5
	if aim == INF:
		for index in range(3):
			if up.has(index):
				aim = cans.can_x(index)
	if aim == INF:
		return
	if sloppy > 0.1:
		aim += sin(cans.elapsed * 1.7) * sloppy
	else:
		# Leads the moving shelf by the ball's travel time.
		aim += cans.shelf_x_at(cans.travel_seconds() + 0.1) - cans.shelf_x
	walk(Vector3(aim, 0, cans._line.z + 0.4), RUN_SPEED)
	if absf(feet().x - aim) < 0.03 and cans.mode == cans.READY:
		field.press()


func _creeper(speed: float, careful: bool) -> void:
	var soldier := game("toy-statue")
	if careful and (soldier.mode == soldier.LOOK or (soldier.mode == soldier.WARN and speed < RUN_SPEED)):
		return
	walk(soldier.soldier_at(), speed)


func _test_garden() -> void:
	medal_runs("garden-water", _gardener.bind(RUN_SPEED), _gardener.bind(STROLL_SPEED), stand_still)
	var bed := game("garden-water")
	begin("garden-water")
	place(bed.flower(0))
	field.press()
	check(bed.wasted == 1 and bed.score == 0, "watering a flower that is not thirsty scores nothing")
	advance(25.0)
	check(bed.lost > 0, "flowers left alone wilt")
	field.abort()
	advance(FieldGames.LEAVE_NOTE_SECONDS + 0.1)
	medal_runs("garden-ducks", _herder.bind(RUN_SPEED, 3), _herder.bind(STROLL_SPEED, 1), stand_still)
	var flock := game("garden-ducks")
	var greedy := play_round("garden-ducks", _herder.bind(RUN_SPEED, 5))
	check(flock.strays > 0, "a long line of ducklings loses one at the back (scored %d)" % int(greedy.score))


func _gardener(speed: float) -> void:
	var bed := game("garden-water")
	var best := -1
	for index in range(bed.water.size()):
		if bed.wilted[index] <= 0.0 and (best < 0 or bed.water[index] < bed.water[best]):
			best = index
	if best < 0:
		return
	var goal: Vector3 = bed.flower(best)
	if bed.water[best] < bed.THIRSTY + 0.12:
		walk(goal, speed)
	if bed.water[best] < bed.THIRSTY and bed.flat_distance(feet(), goal) < bed.WATER_REACH * 0.7:
		field.press()


## Gathers ducklings into a line of up to `train`, then leads them into the pond.
func _herder(speed: float, train: int) -> void:
	var flock := game("garden-ducks")
	var best := -1
	if flock.line.size() < train:
		for index in range(flock.DUCKS):
			if flock.state[index] == flock.WANDER and (best < 0 or flock.duck_at(index).distance_to(feet()) < flock.duck_at(best).distance_to(feet())):
				best = index
	walk(flock.duck_at(best) if best >= 0 else flock.pond(), speed)


# --- toys ---

## Everything a toy shows: positions, turns, sizes and what is visible.
func _pose(node: Node) -> PackedFloat32Array:
	var pose := PackedFloat32Array()
	for child: Node in [node] + node.find_children("*", "", true, false):
		if child is Node3D:
			var spatial := child as Node3D
			pose.append_array([spatial.position.x, spatial.position.y, spatial.position.z, spatial.rotation.x, spatial.rotation.y, spatial.rotation.z, spatial.scale.y, float(spatial.visible)])
		if child is MultiMeshInstance3D:
			var batch := (child as MultiMeshInstance3D).multimesh
			for index in range(batch.instance_count):
				var spot := batch.get_instance_transform(index)
				pose.append_array([spot.origin.x, spot.origin.y, spot.origin.z, spot.basis.get_scale().y])
	return pose


func _test_toys() -> void:
	var saved := FileAccess.get_file_as_bytes(OS.get_environment("SNAPLAND_SAVE_PATH"))
	var coins: int = progress.coins
	for region: String in field.groups:
		for item: Dictionary in field.groups[region].toys.items:
			var node: Node3D = item.toy
			place(item.ground + Vector3(0, 0, 1.2))
			advance(0.2)
			var rest := _pose(node)
			main._interact(item.id, "")
			check(int(item.pokes) == 1, "%s answers the interact key" % item.id)
			var moved := false
			for index in range(6):
				advance(0.15)
				moved = moved or _pose(node) != rest
			check(moved, "%s shows a visible reaction" % item.id)
			advance(12.0)
			place(item.ground + Vector3(0, 0, 6.0))
			advance(2.0)
			world.apply_settings({"reduced_motion": true})
			main._interact(item.id, "")
			advance(0.3)
			var held := _pose(node)
			advance(0.3)
			check(held == _pose(node), "%s holds still under reduced motion" % item.id)
			world.apply_settings({"reduced_motion": false})
			advance(12.0)
	check(saved == FileAccess.get_file_as_bytes(OS.get_environment("SNAPLAND_SAVE_PATH")) and progress.coins == coins, "district toys leave the saved progress untouched")


func _test_stable_nodes() -> void:
	var nodes := world.find_children("*", "Node", true, false).size()
	var materials: int = world.material_cache.size()
	for phase in ["dawn", "noon", "dusk", "night", "noon"]:
		world.set_time_of_day(phase)
		field.advance(STEP)
	for reduced in [true, false]:
		world.apply_settings({"reduced_motion": reduced})
		field.advance(STEP)
	play_round("harbor-crate-stack", _crane.bind(0.08, 0.0))
	check(world.find_children("*", "Node", true, false).size() == nodes and world.material_cache.size() == materials,
		"time of day, settings and district rounds create no nodes or materials")
	check(field.find_children("*", "Light3D", true, false).is_empty(), "district games add no lights")
