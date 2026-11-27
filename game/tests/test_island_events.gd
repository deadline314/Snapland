extends Node
## Island events: the director's schedule and phases, each of the three events
## played through once (splashing puddles and photographing the rainbow,
## catching the balloon or watching it go, photographing a firework at its
## peak), the souvenir sticker given once, pausing under menus and games, the
## setting, reduced motion and the power-saving picture, and a scene that is
## back to the same node count after every event.

const MAIN_SCENE := preload("res://game/main.tscn")
const Director = preload("res://game/world/island_events.gd")
const Catalog = preload("res://game/core/island_event_catalog.gd")
const Shower = preload("res://game/world/island_event_shower.gd")
const Wind = preload("res://game/world/island_event_wind.gd")
const Fireworks = preload("res://game/world/island_event_fireworks.gd")

const STEP := 1.0 / 30.0
const START := Vector3(0, 0.2, -30)

var failures: Array[String] = []
var progress: Node
var main: Node
var world: Node3D
var events: Node3D
var notices: Array[String] = []
var notes := 0


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
	events = main.island_events
	_check(is_instance_valid(events) and events.get_parent() == world, "the island world carries one event director")
	if is_instance_valid(events):
		# The test moves a simulated walker; the real one stands still.
		events.set_physics_process(false)
		if is_instance_valid(main.thief): main.thief.set_physics_process(false)
		events.notice_requested.connect(func(text: String) -> void: notices.append(text))
		events.note_requested.connect(func(_note: int) -> void: notes += 1)
		var nodes_before := _node_count()
		var sky_before: Color = world.environment.background_color
		_schedule()
		_check(_node_count() == nodes_before, "scheduled events leave no nodes behind (%d -> %d)" % [nodes_before, _node_count()])
		await _shower()
		_check(_node_count() == nodes_before and world.environment.background_color == sky_before, "the shower frees everything and clears the sky (%d -> %d)" % [nodes_before, _node_count()])
		await _wind()
		_check(_node_count() == nodes_before, "the windy afternoon frees everything (%d -> %d)" % [nodes_before, _node_count()])
		await _fireworks()
		_check(_node_count() == nodes_before, "the fireworks free everything (%d -> %d)" % [nodes_before, _node_count()])
		_pause_and_menus()
		_settings_and_looks()
		_check(_node_count() == nodes_before, "toggling settings and the time of day adds no nodes (%d -> %d)" % [nodes_before, _node_count()])
		_stickers_kept()
	main.audio.shutdown()
	await get_tree().create_timer(0.15).timeout
	main.queue_free()
	await get_tree().process_frame
	for failure in failures:
		push_error("FAIL: " + failure)
	if failures.is_empty():
		print("PASS: island events schedule, shower, wind, fireworks, stickers, pause, settings and cleanup")
	get_tree().quit(0 if failures.is_empty() else 1)


func _schedule() -> void:
	_phase("noon")
	_check(not events.is_active() and events.countdown > Catalog.FIRST_DELAY - 1.0, "no event at first; the first waits for a delay")
	events.countdown = Catalog.FIRST_DELAY
	world.blocked = true
	_run_for(Catalog.FIRST_DELAY + 5.0, START)
	_check(not events.is_active() and events.countdown == Catalog.FIRST_DELAY, "no time counts while a menu or game holds the walker")
	world.blocked = false
	progress.intro_seen = false
	_run_for(Catalog.FIRST_DELAY + 5.0, START)
	_check(not events.is_active(), "no event before the arrival tour is done")
	progress.intro_seen = true
	_run_for(Catalog.FIRST_DELAY - 1.0, START)
	_check(not events.is_active(), "the first event waits for the full delay")
	_run_for(1.5, START)
	_check(events.is_active() and events.active_id in ["shower", "wind"], "after the delay an afternoon event begins (%s)" % events.active_id)
	_check(not notices.is_empty(), "an event opens with a one-line notice")
	var first: String = events.active_id
	_check(not events.start("fireworks", START), "only one event runs at a time")
	var row := Catalog.find(first)
	_run_for(float(row.seconds) + 6.0, START)
	_check(not events.is_active() and events.last_id == first, "the event ends by itself within its length (%.0f s)" % float(row.seconds))
	_check(events.countdown > 200.0, "a long cooldown follows (%.0f s)" % events.countdown)
	_run_for(120.0, START)
	_check(not events.is_active(), "no new event during the cooldown")
	for row_check: Dictionary in Catalog.EVENTS:
		_check(float(row_check.seconds) >= 60.0 and float(row_check.seconds) <= 180.0, "%s lasts one to three minutes" % row_check.id)
	var picks := {}
	for phase: String in ["dawn", "noon", "dusk", "night"]:
		picks[phase] = {}
		for index in range(40): picks[phase][events.pick(phase)] = true
	_check(picks.dawn.keys() == ["shower"] and picks.night.keys() == ["fireworks"], "dawn brings only showers and night only fireworks")
	_check(picks.noon.has("shower") and picks.noon.has("wind") and not picks.noon.has("fireworks"), "an afternoon picks between the shower and the wind")
	_check(picks.dusk.has("fireworks") and picks.dusk.has("wind") and not picks.dusk.has("shower"), "dusk picks between the wind and the fireworks")
	events.countdown = 0.0
	_phase("night")
	_run_for(STEP, START)
	_check(events.active_id == "fireworks", "at night the director starts the fireworks")
	_phase("noon")
	_run_for(STEP, START)
	_check(not events.is_active(), "switching to a time the event does not belong to ends it at once")


func _shower() -> void:
	_phase("noon")
	var sky: Color = world.environment.background_color
	var sun: float = world.sun.light_energy
	notices.clear()
	_check(events.start("shower", START), "a shower can be started directly")
	var shower: Node3D = events.active
	_run_for(5.0, START)
	_check(world.environment.background_color != sky and world.sun.light_energy < sun * 0.6, "the sky greys over and the sun dims")
	_check(shower.puddles.size() >= 4, "puddles open near the walker (%d)" % shower.puddles.size())
	var near := true
	for puddle: MeshInstance3D in shower.puddles:
		if _flat(puddle.global_position - START) > 8.0 or not world.is_walkable(puddle.global_position): near = false
	_check(near, "every puddle is on walkable ground close by")
	_check(shower.umbrellas.size() >= 1 and _any_visible(shower.umbrellas), "residents nearby open umbrellas")
	var before_notes := notes
	var walker := START
	for puddle: MeshInstance3D in shower.puddles.slice(0, 3):
		walker = _walk_to(walker, puddle.global_position, 1.2)
	_check(shower.participation >= 3 and notes > before_notes, "walking through puddles splashes them (%d)" % shower.participation)
	_check(notices.any(func(text: String) -> bool: return text.contains("三朵水花")), "the third splash says the goal is met")
	_check(shower.prompt(walker).is_empty(), "nothing to photograph while it rains")
	_run_until(func() -> bool: return shower.stage == Shower.Stage.RAINBOW and shower.rainbow_strength() >= 1.0, walker, 90.0)
	_check(shower.rainbow.visible and world.environment.background_color == sky, "after the rain the sky clears and a rainbow rises")
	_check(shower.prompt(walker) == "拍下彩虹", "the rainbow offers a one-line shutter prompt")
	events._offer_prompt(walker)
	_check(world.nearest.get("id", "") == Director.POINT_ID and main._context_prompt() == "E   拍下彩虹", "the prompt shows on the context bar")
	_check(events.shutter(walker), "the shutter takes the rainbow photo")
	await _settle()
	_check(progress.photos.has("event-shower"), "the photo is kept as the shower's souvenir sticker")
	_check(progress.normal_count() == 0 and progress.devil_count("welcome") == 0, "a souvenir sticker never counts toward game stickers")
	_run_until(func() -> bool: return not events.is_active(), walker, 60.0)
	_check(not events.is_active(), "the rainbow fades and the shower ends")
	# Once only: a second shower gives no second sticker.
	var kept: int = progress.photos.size()
	events.start("shower", START)
	shower = events.active
	walker = START
	for puddle: MeshInstance3D in shower.puddles.slice(0, 3):
		walker = _walk_to(walker, puddle.global_position, 1.2)
	_run_until(func() -> bool: return not shower.prompt(walker).is_empty(), walker, 90.0)
	events.shutter(walker)
	await _settle()
	_check(progress.photos.size() == kept, "a second shower keeps the one sticker")
	events.finish()
	await _settle()


func _wind() -> void:
	_phase("noon")
	notices.clear()
	_check(events.start("wind", START), "a windy afternoon can be started directly")
	var wind: Node3D = events.active
	_run_for(0.5, START)
	_check(wind.balloon.visible and world.ambience.gust > 0.0, "a balloon breaks loose and the wind picks up")
	var walker := START
	var caught := false
	for tick in range(int(Wind.CHASE_SECONDS / STEP)):
		var target: Vector3 = wind.balloon_position()
		var toward := target - walker
		toward.y = 0.0
		if toward.length() > 0.05: walker += toward.normalized() * minf(1.5 * STEP, toward.length())
		events.advance(STEP, walker)
		if wind.stage == Wind.Stage.CAUGHT:
			caught = true
			break
	_check(caught, "running after it catches the balloon in time")
	_check(_flat(wind.balloon_position() - START) > 3.0, "the balloon drifted away before it was caught")
	await _settle()
	_check(progress.photos.has("event-wind"), "catching it keeps the wind's souvenir sticker")
	_run_until(func() -> bool: return not events.is_active(), walker, 10.0)
	_check(not events.is_active() and world.ambience.gust == 0.0, "the event ends and the wind calms")
	# Missed twice: it sails away (funny), a second balloon follows, then it is over.
	notices.clear()
	events.start("wind", START)
	wind = events.active
	var lost := false
	var seconds := 0.0
	while events.is_active() and seconds < 90.0:
		events.advance(STEP, START)
		seconds += STEP
		if is_instance_valid(wind) and wind.stage == Wind.Stage.LOST: lost = true
	_check(lost and notices.any(func(text: String) -> bool: return text.contains("掰掰")), "a missed balloon sails off with a goodbye")
	_check(notices.any(func(text: String) -> bool: return text.contains("另一顆")), "a second gust frees another balloon")
	_check(not events.is_active() and seconds <= float(Catalog.find("wind").seconds) + 1.0, "after two misses the wind dies down (%.0f s)" % seconds)
	await _settle()


func _fireworks() -> void:
	_phase("dusk")
	var ambient: float = world.environment.ambient_light_energy
	_check(events.start("fireworks", START), "fireworks can be started directly")
	var show: Node3D = events.active
	var lookout: Vector3 = show.lookout
	_check(lookout != Vector3.ZERO and show.shore_x > lookout.x and show.shore_x < lookout.x + 20.0 and not world.island_walkable(Vector2(show.shore_x + 3.0, lookout.z)), "the lookout looks out over the lagoon close by")
	_check(world.island_walkable(Vector2(lookout.x, lookout.z)), "the lookout is ground the walker can reach")
	_check(show.prompt(START).is_empty() and show.prompt(lookout) == "拍下煙火", "the shutter is offered only at the lookout")
	var area: Dictionary = events.map_area()
	main._show_island_map()
	var canvas: Node = main.overlay.find_child("IslandChartCanvas", true, false)
	var legend := main.overlay.find_child("IslandMapLegend", true, false) as Label
	_check(not area.is_empty() and canvas != null and not (canvas.get("event_area") as Dictionary).is_empty() and legend.text.contains("星星：島上活動"), "the island map marks the lookout")
	main._close()
	show.shutter(lookout)
	_check(show.best == 0 and progress.photos.has("event-fireworks") == false, "a shot before any shell opens scores nothing")
	_run_until(func() -> bool: return show.seconds_to_peak() <= STEP, lookout, 12.0)
	_check(world.environment.ambient_light_energy > ambient + 0.05, "an open shell flashes the island's light")
	_check(_any_glow(show), "an open shell lights the water under it")
	_check(show.shot_score() >= 90, "a shell at its fullest scores high (%d)" % show.shot_score())
	_check(events.shutter(lookout) and show.best >= 90, "the shutter at the peak keeps the best shot (%d)" % show.best)
	await _settle()
	_check(progress.photos.has("event-fireworks"), "a good shot keeps the fireworks' souvenir sticker")
	_run_until(func() -> bool: return not events.is_active(), lookout, 120.0)
	_check(not events.is_active() and is_equal_approx(world.environment.ambient_light_energy, ambient), "the show ends and the light returns (%s, %.3f -> %.3f)" % [events.is_active(), ambient, world.environment.ambient_light_energy])
	await _settle()


func _pause_and_menus() -> void:
	_phase("noon")
	events.start("shower", START)
	var shower: Node3D = events.active
	_run_for(5.0, START)
	var clock: float = shower._stage_time
	main._show_settings()
	(main.overlay.find_child("SettingsTab_play", true, false) as Button).pressed.emit()
	_run_for(3.0, START)
	_check(events.paused and not shower.visible and shower._stage_time == clock, "a menu pauses the event and hides it")
	_check(world.environment.background_color == world.air_target.sky or world.event_air.is_empty(), "the sky clears behind a menu")
	var toggle := main.overlay.find_child("Value_island_events", true, false) as CheckButton
	_check(toggle != null and toggle.button_pressed and not toggle.tooltip_text.is_empty(), "settings offer the island events toggle with a short tooltip")
	main._close()
	_run_for(STEP, START)
	_check(not events.paused and shower.visible and shower._stage_time > clock, "closing the menu resumes it")
	world.hide()
	_run_for(3.0, START)
	_check(events.paused and shower._stage_time < clock + 0.2, "an arcade game (the world hidden) pauses it")
	world.show()
	world.field_games.phase = world.field_games.Phase.PLAYING
	_run_for(1.0, START)
	_check(events.paused, "an instant map game pauses it too")
	world.field_games.phase = world.field_games.Phase.IDLE
	_run_for(STEP, START)
	_check(not events.paused, "after the game it carries on")
	# The event's own prompt never takes over a nearer stall or story point.
	var point: Dictionary = world.points[0]
	world.nearest = point
	shower.photographed = false
	shower.stage = Shower.Stage.RAINBOW
	shower._stage_time = 5.0
	events._offer_prompt(point.position)
	_check(world.nearest == point, "a stall or story point keeps its own prompt")
	events.finish()


func _settings_and_looks() -> void:
	progress.settings[Catalog.SETTING] = false
	_phase("dusk")
	events.start("fireworks", START)
	_run_for(STEP, START)
	_check(not events.is_active(), "switching events off ends the running one")
	events.countdown = 10.0
	_run_for(30.0, START)
	_check(not events.is_active() and events.countdown == 10.0, "while off, no event comes")
	progress.settings[Catalog.SETTING] = true
	events.start("fireworks", START)
	var show: Node3D = events.active
	show.launch_now()
	_run_for(0.5, START)
	var counted := _node_count()
	var full: int = show._batch.visible_instance_count
	world.reduced_motion = true
	_run_for(STEP, START)
	_check(show._trail == 1 and show._batch.visible_instance_count < full, "reduced motion draws simpler shells")
	_run_for(1.0, START)
	_check(world.event_air.get("flash", 0.0) == 0.0, "reduced motion never flashes the light")
	world._apply_render_quality("low")
	_run_for(STEP, START)
	_check(show._spark_count == Fireworks.SPARKS_SAVER, "the power-saving picture uses fewer sparks")
	_phase("night")
	_run_for(STEP, START)
	_check(_node_count() == counted, "settings and time-of-day changes during an event add no nodes")
	events.finish()
	_phase("noon")
	events.start("shower", START)
	var shower: Node3D = events.active
	_run_for(5.0, START)
	_check(shower._puddle_material.get_shader_parameter("rain") == 0.0 and (shower.rain == null or not shower.rain.visible), "reduced motion stills the rain")
	var clock: float = shower._clock
	_run_for(1.0, START)
	_check(shower._clock == clock, "reduced motion holds the puddles still")
	events.finish()
	events.start("wind", START)
	_run_for(1.0, START)
	_check(world.ambience.gust == 0.0 and (events.active.leaves == null or not events.active.leaves.visible), "reduced motion keeps the wind and leaves still")
	events.finish()
	world.reduced_motion = false
	world._apply_render_quality("high")
	events.start("shower", START)
	_check(events.active.rain == null or events.active.rain.amount == Shower.RAIN_AMOUNT, "full picture quality rains at full strength")
	world._apply_render_quality("low")
	_run_for(STEP, START)
	_check(events.active.rain == null or events.active.rain.amount == Shower.RAIN_SAVER, "power saving rains with fewer drops")
	world._apply_render_quality("high")
	events.finish()


func _stickers_kept() -> void:
	var path := OS.get_environment("SNAPLAND_SAVE_PATH")
	progress.load_progress()
	var kept := true
	for sticker in Catalog.sticker_ids():
		if not progress.photos.has(sticker): kept = false
	_check(kept, "all three souvenir stickers survive a reload")
	_check(not progress.record_event_sticker("event-shower"), "a sticker already kept is never given again")
	_check(not progress.record_event_sticker("event-unknown"), "only the island's events have stickers")
	var on_disk: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	(on_disk.settings as Dictionary).erase(Catalog.SETTING)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(on_disk))
	file.close()
	progress.load_progress()
	_check(bool(progress.settings.get(Catalog.SETTING, false)), "an old save without the setting has events on")


# --- helpers -------------------------------------------------------------------

## Walks the simulated walker to `target` and `beyond` metres past it.
func _walk_to(from: Vector3, target: Vector3, beyond: float) -> Vector3:
	var direction := target - from
	direction.y = 0.0
	var finish := target + direction.normalized() * beyond
	var walker := from
	for tick in range(int(30.0 / STEP)):
		var toward := finish - walker
		toward.y = 0.0
		if toward.length() < 0.05: break
		walker += toward.normalized() * minf(1.5 * STEP, toward.length())
		events.advance(STEP, walker)
	return walker


func _run_for(seconds: float, walker: Vector3) -> void:
	for tick in range(maxi(1, roundi(seconds / STEP))):
		events.advance(STEP, walker)


func _run_until(done: Callable, walker: Vector3, limit: float) -> void:
	var seconds := 0.0
	while not done.call() and seconds < limit:
		events.advance(STEP, walker)
		seconds += STEP


func _settle() -> void:
	for frame in range(3): await get_tree().process_frame


func _any_visible(records: Array) -> bool:
	for record: Dictionary in records:
		if (record.node as Node3D).visible: return true
	return false


func _any_glow(show: Node3D) -> bool:
	for glow: MeshInstance3D in show.glows:
		if glow.visible and float(glow.get_instance_shader_parameter("strength")) > 0.3: return true
	return false


func _node_count() -> int:
	return world.find_children("*", "Node", true, false).size()


func _flat(offset: Vector3) -> float:
	return Vector2(offset.x, offset.z).length()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


## The island's time of day, as the time panel would set it (menus re-apply the saved one).
func _phase(phase: String) -> void:
	progress.settings["time_phase"] = phase
	world.set_time_of_day(phase)
