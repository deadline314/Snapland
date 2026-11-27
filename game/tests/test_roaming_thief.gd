extends Node
## The roaming thief: when he appears, where he may stand, the chase and the
## catch, escaping to another part of the island, the three-catch keepsake,
## the setting, saves old and new, and a node count that never grows.

const MAIN_SCENE := preload("res://game/main.tscn")
const Thief = preload("res://game/world/roaming_thief.gd")
const DistrictSites = preload("res://game/world/district_sites.gd")

const STEP := 1.0 / 30.0
const START := Vector3(0, 0.2, -30)

var failures: Array[String] = []
var progress: Node
var main: Node
var world: Node3D
var thief: Node3D
var finished_arcs := 0


func _ready() -> void:
	assert(OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path())
	call_deferred("_run")


func _run() -> void:
	progress = get_tree().root.get_node("Progress")
	progress.reset_progress()
	progress.intro_seen = true
	progress.prologue_seen = true
	progress.save_progress()
	main = MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().physics_frame
	world = main.world
	thief = main.thief
	_check(is_instance_valid(thief) and thief.get_parent() == world, "the island world carries one roaming thief")
	if is_instance_valid(thief):
		# The test moves a simulated walker; the real one stands still.
		thief.set_physics_process(false)
		thief.arc_finished.connect(func() -> void: finished_arcs += 1)
		var nodes_before := _node_count()
		_spawn_rules()
		_chase_and_catch(false)
		_chase_and_catch(true)
		_escape_and_return()
		_map_marker()
		_settings_pause()
		_three_catches_reward_once()
		_check(_node_count() == nodes_before, "every appearance, chase and escape reuses the same nodes (%d -> %d)" % [nodes_before, _node_count()])
		_saves_old_and_new()
	main.audio.shutdown()
	await get_tree().create_timer(0.15).timeout
	main.queue_free()
	await get_tree().process_frame
	for failure in failures:
		push_error("FAIL: " + failure)
	if failures.is_empty():
		print("PASS: roaming thief spawns, chase, catch, escape, keepsake, setting and saves")
	get_tree().quit(0 if failures.is_empty() else 1)


func _spawn_rules() -> void:
	# The scene's first physics frames may already have counted a moment.
	_check(thief.state == Thief.State.AWAY and not thief.visible and thief.countdown > Thief.FIRST_DELAY - 1.0, "he starts away and hidden, after a first delay")
	thief.countdown = Thief.FIRST_DELAY
	world.blocked = true
	_run_for(Thief.FIRST_DELAY + 5.0, START)
	_check(thief.state == Thief.State.AWAY and thief.countdown == Thief.FIRST_DELAY, "no time counts while a menu, dialogue or game holds the walker")
	world.blocked = false
	progress.intro_seen = false
	_run_for(Thief.FIRST_DELAY + 5.0, START)
	_check(thief.state == Thief.State.AWAY, "he never turns up before the arrival tour is done")
	progress.intro_seen = true
	_run_for(Thief.FIRST_DELAY - 1.0, START)
	_check(thief.state == Thief.State.AWAY, "the first appearance waits for the full delay")
	_run_for(1.5, START)
	_check(thief.state == Thief.State.WAITING and thief.visible, "he appears after the delay of free walking")
	var gap := _flat(thief.position - START)
	_check(gap >= Thief.SPAWN_MIN - 0.01 and gap <= Thief.SPAWN_MAX + 0.01, "he appears near the walker (%.1f m)" % gap)
	_check(not thief.on_screen(thief.position, START), "he appears out of the camera's view")
	var bad := 0
	var picked := 0
	for index in range(40):
		var walker := START + Vector3(index % 5 * 4.0 - 8.0, 0, -index * 1.5)
		var spot: Vector3 = thief.pick_spawn(walker)
		if not spot.is_finite(): continue
		if not world.is_walkable(spot) or thief.on_screen(spot, walker) or not thief._clear_of_points(spot) or _flat(spot - walker) < Thief.SPAWN_MIN - 0.01:
			bad += 1
			print("bad spawn ", spot, " walker ", walker, " walk=", world.is_walkable(spot), " screen=", thief.on_screen(spot, walker), " clear=", thief._clear_of_points(spot))
		else:
			picked += 1
	_check(bad == 0 and picked >= 30, "every picked spot is walkable, off screen and clear of stalls and story points (%d picked)" % picked)
	var closed := ""
	for region: String in DistrictSites.regions():
		if not world.district_host.gate_is_open(region): closed = region
	_check(not closed.is_empty() and not thief.stand_ok(DistrictSites.arrival(closed)), "a district behind a closed gate is off limits")
	_send_away()


func _chase_and_catch(reduced: bool) -> void:
	world.reduced_motion = reduced
	thief.countdown = 0.0
	_run_for(STEP, START)
	_check(thief.state == Thief.State.WAITING, "he appears again once his cooldown is over")
	var walker := START
	var caught := false
	var coins: int = progress.coins
	var catches: int = progress.thief_catches
	for tick in range(int(120.0 / STEP)):
		var toward: Vector3 = thief.position - walker
		toward.y = 0.0
		if toward.length() > 0.05: walker += toward.normalized() * minf(1.5 * STEP, toward.length())
		thief.advance(STEP, walker)
		if thief.can_catch(walker) and thief.state == Thief.State.CHASE and thief.chase_time > Thief.DODGE_AFTER + 2.0:
			caught = thief.try_catch(walker)
			break
	var label := " with reduced motion" if reduced else ""
	_check(caught, "a walker heading straight for him catches him within two minutes" + label)
	_check(thief.dodged != reduced, "he side-steps a straight charge once late in the chase" if not reduced else "reduced motion never side-steps")
	_check(progress.thief_catches == catches + 1 and progress.coins == coins + progress.THIEF_CATCH_COINS, "each catch is saved with its coins" + label)
	_run_for(Thief.CAUGHT_SECONDS + Thief.PUFF_SECONDS + 0.2, walker)
	_check(thief.state == Thief.State.AWAY and not thief.visible and thief.countdown > Thief.COOLDOWN - 1.0, "after a catch he puffs away for a full cooldown" + label)
	world.reduced_motion = false


func _escape_and_return() -> void:
	thief.countdown = 0.0
	_run_for(STEP, START)
	var leaving := Thief.place_of(thief.position)
	var walker := START
	var away: Vector3 = (START - thief.position)
	away.y = 0.0
	away = away.normalized()
	for tick in range(int(40.0 / STEP)):
		walker += away * 1.5 * STEP
		thief.advance(STEP, walker)
		if thief.state == Thief.State.AWAY: break
	_run_for(Thief.PUFF_SECONDS, walker)
	_check(thief.state == Thief.State.AWAY and thief.hideout.is_finite(), "walking away from him lets him escape to a hideout")
	_check(Thief.place_of(thief.hideout) != leaving and _flat(thief.hideout - walker) >= Thief.HIDEOUT_MIN, "he hides in another part of the island, well away")
	_check(world.is_walkable(thief.hideout) and thief.stand_ok(thief.hideout), "his hideout is open walkable ground")
	_check(not thief.map_area().is_empty(), "the map knows roughly where he hides")
	_run_for(Thief.RETURN_DELAY + 0.5, walker)
	_check(thief.state == Thief.State.WAITING and _flat(thief.position - thief.hideout) < 0.5, "he turns up at the hideout later")
	_run_for(5.0, walker)
	_check(thief.state == Thief.State.WAITING, "while hiding he waits for the walker instead of escaping again")
	var near: Vector3 = thief.position + Vector3(5, 0, 0)
	thief.advance(STEP, near)
	_check(thief.state == Thief.State.CHASE and not thief.hideout.is_finite(), "finding him starts a new chase")


func _map_marker() -> void:
	var area: Dictionary = thief.map_area()
	main._show_island_map()
	var canvas: Node = main.overlay.find_child("IslandChartCanvas", true, false)
	var legend: Label = main.overlay.find_child("IslandMapLegend", true, false) as Label
	_check(canvas != null and not (canvas.get("thief_area") as Dictionary).is_empty() and float(area.radius) > 0.0, "the island map draws his rough area")
	_check(legend != null and legend.text.contains("面具：怪盜出沒"), "the map legend explains the mask")
	main._close()


func _settings_pause() -> void:
	progress.settings["roaming_thief"] = false
	_run_for(Thief.PUFF_SECONDS + 0.1, START)
	_check(thief.state == Thief.State.AWAY and not thief.visible and thief.map_area().is_empty(), "switching him off sends him away at once")
	var before: float = thief.countdown
	_run_for(30.0, START)
	_check(thief.state == Thief.State.AWAY and thief.countdown == before, "while switched off he never comes back")
	progress.settings["roaming_thief"] = true
	thief.countdown = 0.0
	_run_for(STEP, START)
	_check(thief.state == Thief.State.WAITING, "switching him back on lets him appear again")


func _three_catches_reward_once() -> void:
	_check(progress.thief_catches == 2 and not progress.achievements.has(progress.THIEF_ACHIEVEMENT), "two catches earn no keepsake yet")
	thief.position = START + Vector3(1, 0, 0)
	thief.state = Thief.State.CHASE
	var unlocked := []
	progress.achievement_unlocked.connect(func(id: String) -> void: unlocked.append(id))
	_check(thief.try_catch(START), "the third catch counts")
	_check(progress.thief_catches == 3 and progress.achievements.has(progress.THIEF_ACHIEVEMENT) and unlocked == [progress.THIEF_ACHIEVEMENT], "the third catch grants the keepsake stamp")
	_run_for(Thief.CAUGHT_SECONDS + 0.1, START)
	_check(finished_arcs == 1 and main.modal_kind == "dialogue", "the third catch closes the arc with a short scene")
	main._cancel_dialogue()
	_run_for(Thief.PUFF_SECONDS + 0.1, START)
	var again: Dictionary = progress.record_thief_catch()
	_check(not bool(again.saved) and progress.thief_catches == 3 and unlocked.size() == 1, "the keepsake is given exactly once")
	_run_for(Thief.COOLDOWN + 10.0, START)
	_check(thief.state == Thief.State.AWAY and not thief.visible, "after the arc he no longer appears")


func _saves_old_and_new() -> void:
	var path := OS.get_environment("SNAPLAND_SAVE_PATH")
	progress.load_progress()
	_check(progress.thief_catches == 3 and progress.achievements.has(progress.THIEF_ACHIEVEMENT), "catches and keepsake survive a reload")
	var on_disk: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	on_disk.erase("thief_catches")
	on_disk.erase("achievements")
	(on_disk.settings as Dictionary).erase("roaming_thief")
	_write(path, on_disk)
	progress.load_progress()
	_check(progress.thief_catches == 0 and bool(progress.settings.roaming_thief) and progress.coins == int(on_disk.coins), "an old save without the thief loads unchanged and starts him fresh")
	on_disk["thief_catches"] = 9
	_write(path, on_disk)
	progress.load_progress()
	_check(progress.thief_catches == 0, "a damaged catch count is dropped")
	on_disk["thief_catches"] = 1
	_write(path, on_disk)
	progress.load_progress()
	_check(progress.thief_catches == 1, "a saved catch count loads")


func _send_away() -> void:
	thief.hideout = Vector3.INF
	thief._go_away()


func _run_for(seconds: float, walker: Vector3) -> void:
	for tick in range(maxi(1, roundi(seconds / STEP))):
		thief.advance(STEP, walker)


func _node_count() -> int:
	return world.find_children("*", "Node", true, false).size()


func _flat(offset: Vector3) -> float:
	return Vector2(offset.x, offset.z).length()


func _write(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
