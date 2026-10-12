extends Node

const MAIN_SCENE := preload("res://game/main.tscn")
var failures: Array[String] = []
var main: Node
var progress: Node
var _finishing := false
var _abort_tests := false
var _bench_finish_snapshot: Dictionary = {}
var _bench_finished_session_id := 0

func _ready() -> void:
	if OS.get_environment("SNAPLAND_SAVE_PATH").is_empty():
		push_error("Set SNAPLAND_SAVE_PATH to an isolated test profile before running the integration suite.")
		get_tree().quit(1)
		return
	call_deferred("_run")

func _run() -> void:
	progress = get_tree().root.get_node_or_null("Progress")
	if progress == null:
		_check(false, "Progress autoload is present when the native integration suite runs")
		_finish()
		return
	progress.reset_progress()
	progress.intro_seen = false
	progress.save_progress()
	# Headless defaults to a 64x36 display, which is not a usable pointer
	# review surface. Set the real test window geometry before creating UI.
	get_window().size = Vector2i(1280, 720)
	await _frames(2)
	main = MAIN_SCENE.instantiate()
	if main.get_script() == null:
		_check(false, "main scene script loads before integration assertions")
		_finish()
		return
	get_tree().root.add_child(main)
	await _frames(3)
	await _test_arrival_and_replay()
	if _abort_tests: _finish(); return
	await _test_movement_and_nearest_interaction()
	if _abort_tests: _finish(); return
	await _test_pause_resume()
	if _abort_tests: _finish(); return
	await _test_cancel_and_successful_game_flow()
	if _abort_tests: _finish(); return
	await _test_story_and_quests()
	if _abort_tests: _finish(); return
	await _test_fixed_collection_and_audio()
	_finish()

func _test_arrival_and_replay() -> void:
	_check(main.audio._active_context == "harbor", "main scene starts harbor audio while the player is at the dock")
	_check(main.modal_kind == "arrival", "new profile opens the arrival modal")
	_press_button_containing(main.overlay, "下船，去看看")
	await _frames(1)
	_check(main.modal_kind == "dialogue", "arrival action starts the intro")
	for _line in 5:
		_press_button_containing(main.overlay, "繼續")
		await _frames(1)
		_press_button_containing(main.overlay, "繼續")
		await _frames(1)
	_check(progress.intro_seen, "finishing the intro persists intro completion")
	_check(main.modal_kind == "", "finishing the intro closes its modal")
	await _frames(3)
	_check(main.world.nearest.get("id", "") == "arrival", "arrival marker is the nearest interaction at the dock")
	_key_down(KEY_E)
	_check(await _wait_for_modal("dialogue"), "arrival input opens replay dialogue")
	_key_up(KEY_E)
	await _frames(2)
	_check(main.modal_kind == "dialogue", "arrival interaction replays the intro")
	_press_button_containing(main.overlay, "略過這段對話")
	await _frames(1)
	_check(progress.intro_seen and main.modal_kind == "", "skipping replay closes it and keeps intro completion")

func _test_movement_and_nearest_interaction() -> void:
	var start: Vector3 = main.world.player.position
	_key_down(KEY_W)
	await _frames(20)
	_key_up(KEY_W)
	await _frames(2)
	_check(main.world.player.position.z < start.z - 0.4, "W input moves the player forward")
	_check(main.world.player.is_on_floor(), "player collision keeps the character on the walkable ground")
	main.world.player.position = main.world.points.filter(func(point: Dictionary) -> bool: return point.id == "arrival")[0].position + Vector3(0, 0.3, 0)
	await _frames(3)
	_check(main.world.nearest.get("id", "") == "arrival", "nearest interaction follows the moved player")
	var arrival_interactions: Array[String] = []
	main.world.interaction_requested.connect(func(id: String, _label: String): arrival_interactions.append(id))
	_key_down(KEY_E)
	await _frames(1)
	_key_up(KEY_E)
	await _frames(1)
	_check(arrival_interactions.has("arrival"), "E interacts with the nearest world point")
	_press_button_containing(main.overlay, "略過這段對話")
	await _frames(1)
	main.world.player.position = Vector3(0, 0.3, 23.2)
	await _frames(2)
	var before_collision: float = main.world.player.position.x
	_key_down(KEY_D)
	await _frames(60)
	_key_up(KEY_D)
	await _frames(2)
	_check(main.world.player.position.x <= 2.051, "dock boundary prevents moving through the shore edge (x=%.3f, z=%.3f)" % [main.world.player.position.x, main.world.player.position.z])
	_check(main.world.player.position.x > before_collision, "movement input remains active after a modal closes")

func _test_pause_resume() -> void:
	_key_down(KEY_ESCAPE)
	_check(await _wait_for_modal("pause"), "Escape opens the pause panel")
	_key_up(KEY_ESCAPE)
	await _frames(1)
	_check(not main.world.is_processing() and main.audio._paused, "pause stops world simulation and pauses audio")
	_key_down(KEY_ESCAPE)
	_check(await _wait_for_modal(""), "Escape closes the pause panel")
	_key_up(KEY_ESCAPE)
	await _frames(1)
	_check(main.modal_kind == "" and main.world.is_processing() and not main.audio._paused, "Escape resumes world simulation and audio")

func _test_cancel_and_successful_game_flow() -> void:
	await _interact_at("game-001")
	_check(main.modal_kind == "game_info", "interacting with a station opens game details")
	_press_button_containing(main.overlay, "開始遊玩")
	_check(await _wait_for_tutorial("game-001"), "first Start opens the unseen game's screenshot tutorial")
	if not is_instance_valid(main.tutorial_panel): return
	_check(main.session == null, "first-entry tutorial appears before a session exists")
	await _frames(8)
	_check(main.session == null, "reading first-entry tutorial does not advance or create a session")
	_check(not progress.has_seen_tutorial("game-001"), "tutorial is not marked seen before the player chooses")
	_press_button_containing(main.tutorial_panel, "開始挑戰")
	_check(await _wait_for_session("game-001"), "choosing Begin from the tutorial launches the first session")
	_check(await _wait_for_session("game-001"), "game details launch the first session")
	_check(main.session != null and main.session.game_id == "game-001", "game details launch the canonical session ID")
	_check(progress.has_seen_tutorial("game-001"), "choosing Begin records that the first-entry tutorial was learned")
	await _test_live_session_help()
	if _abort_tests: return
	_key_down(KEY_ESCAPE)
	await _frames(2)
	_key_up(KEY_ESCAPE)
	_check(main.session != null and main.session.paused, "Escape pauses the active session without losing the round")
	_check(_find_button_containing(main.session.minigame_hud, "離開小遊戲") != null, "pause offers an explicit leave action")
	_press_button_containing(main.session.minigame_hud, "離開小遊戲")
	_check(main.session != null, "leave requires confirmation before discarding the round")
	_press_button_containing(main.session.minigame_hud, "確定")
	_check(await _wait_for_session_end(), "confirmed leave closes the active session")
	await _frames(2)
	_check(main.session == null, "confirmed leave removes the session")
	_check(main.modal_kind == "", "cancel input does not leak into the pause menu")
	_check(main.hud.visible and not main.world.blocked, "cancel restores HUD and world controls")
	if main.modal_kind == "pause":
		_press_button_containing(main.overlay, "繼續遊園")
		await _frames(1)

	await _interact_at("game-011")
	_press_button_containing(main.overlay, "開始遊玩")
	_check(await _wait_for_tutorial("game-011"), "another unseen game's Start opens its screenshot tutorial")
	if not is_instance_valid(main.tutorial_panel): return
	_check(main.session == null, "second first-entry tutorial appears before its session exists")
	await _frames(8)
	_check(main.session == null, "reading second first-entry tutorial does not create a session")
	_press_button_containing(main.tutorial_panel, "略過")
	_check(await _wait_for_session("game-011"), "choosing Skip from the tutorial launches the second session")
	_check(await _wait_for_session("game-011"), "second station starts a session")
	_check(main.session != null and main.session.game_id == "game-011", "second station launches its own canonical ID")
	_check(progress.has_seen_tutorial("game-011"), "choosing Skip records that the tutorial was learned")
	await _test_live_session_help()
	if _abort_tests: return
	# Solve all three actual BenchSwap tables from their visible rules using real seat-key input.
	if not await _solve_bench_tables_with_real_keys(main.session): return
	_check(await _wait_for_modal("result"), "completed minigame input opens the result modal")
	_check(main.session == null and main.modal_kind == "result", "valid game input flows into the result modal")
	_check(progress.photos.has("photo-welcome-game-11"), "successful devil result awards the ordinary card")
	_check(progress.photos.has("photo-welcome-devil-11"), "successful devil result awards its devil card")
	_check(progress.devil_count("welcome") == 1, "result counts the devil card once")
	_press_button_containing(main.overlay, "返回遊園")
	await _frames(1)
	_check(main.modal_kind == "" and main.hud.visible and not main.world.blocked, "closing results restores normal world controls")

func _test_live_session_help() -> void:
	var active: Control = main.session
	await _frames(3)
	var phase_before: float = active.phase
	var elapsed_before: float = active.elapsed
	var score_before: int = active.score
	var help_button := active.minigame_hud.find_child("HelpButton", true, false) as Button
	_check(help_button != null, "active round exposes its actual HUD help button")
	if _abort_tests: return
	_click_real_button(help_button)
	await _frames(4)
	var lesson: Control = main.tutorial_panel
	_check(is_instance_valid(lesson) and active.paused, "HUD help opens screenshot teaching and pauses the live round")
	if _abort_tests: return
	_check(lesson.target_id == active.game_id and main.tutorial_origin == "session", "help loads this game's lesson")
	for key in ["_goal_label", "_input_label", "_ordinary_label", "_bonus_label"]:
		var label: Label = lesson.get(key)
		_check(label != null and not label.text.is_empty(), "teaching provides %s" % key)
	await _frames(8)
	_check(main.session == active and active.phase == phase_before and active.elapsed == elapsed_before and active.score == score_before, "reading help preserves session phase, time and score")
	_check(not main.hud.visible and not main.world.visible and main.world.blocked, "session lesson keeps park controls hidden and blocked")
	_click_real_button(lesson.get("_close_button") as Button)
	await _frames(3)
	_check(main.session == active and not is_instance_valid(main.tutorial_panel) and active.paused, "closing teaching returns to the paused same round")
	_check(active.phase == phase_before and active.elapsed == elapsed_before and active.score == score_before, "closing teaching does not reset progress")
	_click_real_button(active.minigame_hud.find_child("ResumeButton", true, false) as Button)
	await _frames(5)
	var learning_balloon: bool = active.mode == "balloon_delivery" and not active.balloon_started
	_check(not active.paused and active.phase > phase_before and (active.elapsed == elapsed_before if learning_balloon else active.elapsed > elapsed_before), "resume advances the preserved round and untimed learning remains untimed")
	_click_real_button(help_button)
	await _frames(3)
	_key_down(KEY_ESCAPE)
	_key_up(KEY_ESCAPE)
	await _frames(3)
	_check(main.session == active and not is_instance_valid(main.tutorial_panel) and active.paused and not main.hud.visible and main.modal_kind == "", "teaching Escape returns to paused game without leaking into park pause")
	_click_real_button(active.minigame_hud.find_child("ResumeButton", true, false) as Button)
	await _frames(2)

func _click_real_button(button: Button) -> void:
	var pressed_observed := {"value": false}
	button.pressed.connect(func(): pressed_observed.value = true, CONNECT_ONE_SHOT)
	var point := button.get_viewport().get_final_transform() * button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	motion.window_id = get_window().get_window_id()
	Input.parse_input_event(motion)
	Input.flush_buffered_events()
	for is_down in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.window_id = get_window().get_window_id()
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if is_down else 0
		event.pressed = is_down
		Input.parse_input_event(event)
		Input.flush_buffered_events()
	_check(pressed_observed.value, "real integration click activates %s; rect=%s pointer=%s hovered=%s" % [button.name, button.get_global_rect(), point, button.get_viewport().gui_get_hovered_control()])

func _test_story_and_quests() -> void:
	await _interact_at("guide")
	_check(main.modal_kind == "dialogue", "guide interaction starts the main story")
	_press_button_containing(main.overlay, "略過這段對話")
	await _frames(1)
	_check(progress.photos.has("photo-welcome-story-1"), "main story awards its fixed photo source")

	await _interact_at("quest-001")
	_check(int(progress.quests.get("quest-001", 0)) == 1, "real Xiao Jiao interaction starts the mission")
	_press_button_containing(main.modal_body, "返回遊園")
	await _frames(1)
	await _complete_exploration(3)
	_check(int(progress.quests.get("quest-001", 0)) == 2, "real bench photo advances the framing step")
	_press_button_containing(main.overlay, "返回遊園")
	await _frames(1)
	await _interact_at("quest-002")
	_check(int(progress.quests.get("quest-002", 0)) == 1, "real 阿浪 interaction starts his mission")
	_press_button_containing(main.modal_body, "返回遊園")
	await _frames(1)
	await _complete_exploration(2)
	_check(int(progress.quests.get("quest-002", 0)) == 2, "real welcome-wall photo proves the observation step")
	_check(not progress.photos.has("photo-welcome-quest-1") and not progress.photos.has("photo-welcome-quest-2"), "incomplete missions have not granted completion photos")
	_press_button_containing(main.overlay, "返回遊園")
	await _frames(1)

func _complete_exploration(index: int) -> void:
	await _interact_at("explore-%03d" % index)
	if index == 2:
		var slider := _find_slider(main.modal_body)
		_check(slider != null, "welcome-wall observation exposes its alignment control")
		if slider != null:
			slider.value = 0
	elif index == 3:
		_press_button_containing(main.modal_body, "借一個小角立牌")
	_press_button_containing(main.modal_body, "按下快門")
	await _frames(1)

func _test_fixed_collection_and_audio() -> void:
	for index in range(1, 13):
		if index != 11:
			progress.complete_game("game-%03d" % index, false)
	for index in range(1, 4):
		await _interact_at("explore-%03d" % index)
		var source_id := "photo-welcome-explore-%d" % index
		var previous_photo: Dictionary = progress.photos.get(source_id, {}).duplicate(true)
		if index == 1:
			_press_button_containing(main.modal_body, "按下快門")
			await _frames(1)
			_check(not progress.photos.has("photo-welcome-explore-1"), "flower exploration rejects shutter before choosing an expression")
			_press_button_containing(main.modal_body, "微笑")
		elif index == 2:
			var slider := _find_slider(main.modal_body)
			_check(slider != null, "shadow exploration exposes its slider")
			if slider != null:
				slider.value = 60
				_press_button_containing(main.modal_body, "按下快門")
				await _frames(1)
				_check(progress.photos.get(source_id, {}) == previous_photo, "shadow exploration rejects a misaligned shutter without overwriting a saved photo")
				slider.value = 0
		else:
			_press_button_containing(main.modal_body, "按下快門")
			await _frames(1)
			_check(progress.photos.get(source_id, {}) == previous_photo, "bench exploration rejects shutter before borrowing a prop without overwriting a saved photo")
			_press_button_containing(main.modal_body, "借一個小角立牌")
		_press_button_containing(main.modal_body, "按下快門")
		await _frames(1)
		_check(progress.photos.has("photo-welcome-explore-%d" % index), "exploration grants its fixed source %d" % index)
	var once: int = progress.normal_count()
	progress.complete_game("game-011", false)
	progress.complete_game("game-011", false)
	progress.grant_photo("photo-welcome-story-1")
	_check(progress.normal_count() == once, "repeating sources does not increase the fixed normal collection")
	_check(once == 18, "twelve games, three explorations, story and two quests total eighteen")
	main._show_album()
	await _frames(1)
	var grid := _find_grid(main.overlay)
	_check(grid != null and grid.get_child_count() == 18, "album displays exactly eighteen fixed normal sources")
	_check(progress.devil_count("welcome") == 1, "devil card stays outside ordinary collection count")
	
	_check(main.audio._active_context == "plaza", "moving into the welcome area switches to plaza audio")
	main.audio.play_context("game")
	_check(main.audio._active_context == "game" and main.audio._music_players[main.audio._active_music].stream != null, "audio switches to an actual game track")
	main.audio.apply_settings({"master_volume": 0.4, "music_volume": 0.5, "sfx_volume": 0.6})
	_check(is_equal_approx(float(main.audio._settings.master), 0.4), "audio applies persisted volume settings")
	main.audio.set_paused(true)
	_check(main.audio._paused, "audio supports pause")
	main.audio.set_paused(false)
	main.audio.play_sfx("photo_shutter")
	_check(main.audio._sfx.stream != null, "audio loads and plays a photo sound effect")

func _complete_quest(id: String) -> void:
	var quest: Dictionary = main.story.quest_data(id)
	for index in range(int(progress.quests.get(id, 0)), 3):
		var step: Dictionary = quest.steps[index]
		if index == 1 and id == "quest-001":
			var slider := _find_slider(main.modal_body)
			_check(slider != null, "tail quest exposes its alignment slider")
			if slider != null:
				slider.value = 90
				_press_button_containing(main.modal_body, "固定背景板")
				await _frames(1)
				_check(int(progress.quests.get(id, 0)) == index, "tail quest rejects a misaligned board")
				slider.value = 0
			_press_button_containing(main.modal_body, "固定背景板")
		elif index == 1:
			_press_button_containing(main.modal_body, "→ 廣場")
			_press_button_containing(main.modal_body, "試播方向")
			await _frames(1)
			_check(int(progress.quests.get(id, 0)) == index, "broadcast quest rejects wrong direction")
			_press_button_containing(main.modal_body, "↑ 大道")
			_press_button_containing(main.modal_body, "試播方向")
		else:
			_press_button_containing(main.modal_body, str(step.options[int(step.correct)]))
		await _frames(1)

func _interact_at(id: String) -> void:
	if _abort_tests: return
	for point in main.world.points:
		if point.id == id:
			main.world.player.position = point.position + Vector3(0, 0.3, 0)
			if not await _wait_for_nearest(id):
				_check(false, "nearest interaction resolves to %s (got %s)" % [id, str(main.world.nearest.get("id", "none"))])
				return
			_key_down(KEY_E)
			var expected := "game_info" if id.begins_with("game-") else "quest" if id.begins_with("quest-") else "explore" if id.begins_with("explore-") else "dialogue"
			var opened := await _wait_for_modal(expected)
			_key_up(KEY_E)
			if not opened:
				_check(false, "E opens %s modal at %s (got %s)" % [expected, id, main.modal_kind])
			return
	_check(false, "world contains interaction point %s" % id)

func _wait_for_nearest(id: String, timeout_seconds := 1.0) -> bool:
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < int(timeout_seconds * 1000.0):
		await get_tree().physics_frame
		if main.world.nearest.get("id", "") == id: return true
	return false

func _wait_for_modal(kind: String, timeout_seconds := 1.0) -> bool:
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < int(timeout_seconds * 1000.0):
		await get_tree().process_frame
		if main.modal_kind == kind: return true
	return false

func _wait_for_session(id: String, timeout_seconds := 1.0) -> bool:
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < int(timeout_seconds * 1000.0):
		await get_tree().process_frame
		if main.session != null and main.session.game_id == id: return true
	return false

func _wait_for_tutorial(id: String, timeout_seconds := 1.0) -> bool:
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < int(timeout_seconds * 1000.0):
		await get_tree().process_frame
		if is_instance_valid(main.tutorial_panel) and main.tutorial_panel.target_id == id: return true
	return false

func _solve_bench_tables_with_real_keys(active_session: Node) -> bool:
	var session_id := active_session.get_instance_id()
	_bench_finish_snapshot.clear()
	_bench_finished_session_id = 0
	active_session.finished.connect(_capture_bench_finish.bind(session_id), CONNECT_ONE_SHOT)
	for table in 3:
		if main.session != active_session:
			_check(false, "BenchSwap remains active through table %d" % (table + 1))
			return false
		var state: Dictionary = active_session.bench_model.snapshot()
		_check(int(state.level) == table, "visible BenchSwap model is on table %d" % (table + 1))
		var plan := _visible_bench_bfs(state.seats, state.rules)
		_check(plan.size() == int(state.optimal_moves) and plan.size() == table + 1, "table %d visible rules have the model's %d-swap solution" % [table + 1, int(state.optimal_moves)])
		if plan.is_empty(): return false
		for pair in plan:
			_key_down(KEY_1 + int(pair[0]))
			await get_tree().process_frame
			_key_up(KEY_1 + int(pair[0]))
			_key_down(KEY_1 + int(pair[1]))
			await get_tree().process_frame
			_key_up(KEY_1 + int(pair[1]))
			if not await _wait_for_bench_transition(session_id): return false
			if _bench_finished_session_id == session_id:
				state = _bench_finish_snapshot
			elif is_instance_valid(active_session):
				state = active_session.bench_model.snapshot()
			else:
				_check(false, "BenchSwap state remains available after real key input")
				return false
			if _bench_rules_satisfied(state.seats, state.rules) and pair != plan.back():
				_check(false, "table %d remains unsolved before its final BFS exchange" % (table + 1))
				return false
		var solved_state: Dictionary = _bench_finish_snapshot if table == 2 else active_session.bench_model.snapshot()
		var table_solved := false
		for entry in solved_state.ledger:
			if int(entry.level) == table and bool(entry.solved) and int(entry.moves) == plan.size() and int(entry.optimal_moves) == plan.size(): table_solved = true
		_check(table_solved, "table %d naturally records its exact visible-rule solution" % (table + 1))
		if not table_solved: return false
	return _bench_finished_session_id == session_id and not _bench_finish_snapshot.is_empty()

func _wait_for_bench_transition(session_id: int, timeout_seconds := 3.0) -> bool:
	var deadline := Time.get_ticks_msec() + int(timeout_seconds * 1000.0)
	var saw_transition := false
	while Time.get_ticks_msec() < deadline:
		var state: Dictionary
		if _bench_finished_session_id == session_id:
			state = _bench_finish_snapshot
		else:
			var active := instance_from_id(session_id) as Node if is_instance_id_valid(session_id) else null
			if active == null: return false
			state = active.bench_model.snapshot()
		if int(state.get("swap_from", -1)) >= 0:
			saw_transition = true
		elif saw_transition:
			return true
		await get_tree().physics_frame
	_check(false, "real seat-key input completes an animated BenchSwap transition")
	return false

func _capture_bench_finish(_result: Dictionary, session_id: int) -> void:
	var completed := instance_from_id(session_id) as Node if is_instance_id_valid(session_id) else null
	if completed == null:
		_check(false, "BenchSwap finished signal can still inspect its emitting session")
		return
	_bench_finish_snapshot = completed.bench_model.snapshot().duplicate(true)
	_bench_finished_session_id = session_id

func _bench_rules_satisfied(seats: Array, rules: Array) -> bool:
	if seats.size() != 6: return false
	var sorted := seats.duplicate()
	sorted.sort()
	if sorted != [0, 1, 2, 3, 4, 5]: return false
	for rule in rules:
		var first := seats.find(int(rule.get("a", -1)))
		var second := seats.find(int(rule.get("b", -1)))
		match str(rule.kind):
			"seat": if seats.find(int(rule.guest)) != int(rule.seat): return false
			"together": if absi(first - second) != 1: return false
			"apart": if absi(first - second) < 2: return false
	return true

func _visible_bench_bfs(start: Array, rules: Array) -> Array:
	var queue: Array = [start.duplicate()]
	var parents := {_bench_order_key(start): {"prev": "", "swap": []}}
	var cursor := 0
	var goal := ""
	while cursor < queue.size():
		var order: Array = queue[cursor]
		cursor += 1
		var key := _bench_order_key(order)
		if _bench_rules_satisfied(order, rules):
			goal = key
			break
		for first in 6:
			for second in range(first + 1, 6):
				var next: Array = order.duplicate()
				var hold: Variant = next[first]
				next[first] = next[second]
				next[second] = hold
				var next_key := _bench_order_key(next)
				if not parents.has(next_key):
					parents[next_key] = {"prev": key, "swap": [first, second]}
					queue.append(next)
	if goal.is_empty(): return []
	var path: Array = []
	var key := goal
	while str(parents[key].prev) != "":
		path.push_front(parents[key].swap)
		key = str(parents[key].prev)
	return path

func _bench_order_key(order: Array) -> String:
	return ",".join(order.map(func(value: Variant) -> String: return str(value)))

func _wait_for_session_end(timeout_seconds := 1.0) -> bool:
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < int(timeout_seconds * 1000.0):
		await get_tree().process_frame
		if main.session == null: return true
	return false

func _press_first_action_button() -> void:
	var button := _find_first_button(main.modal_body)
	if button == null:
		_check(false, "modal has an action button")
		return
	button.emit_signal("pressed")

func _press_button_containing(node: Node, needle: String) -> void:
	if _abort_tests: return
	var button := _find_button_containing(node, needle)
	if button == null:
		_check(false, "visible UI has a button containing '%s'" % needle)
		return
	button.emit_signal("pressed")

func _find_button_containing(node: Node, needle: String) -> Button:
	if node is Button and str((node as Button).text).contains(needle):
		return node as Button
	for child in node.get_children():
		var found := _find_button_containing(child, needle)
		if found != null:
			return found
	return null

func _find_first_button(node: Node) -> Button:
	if node is Button:
		return node as Button
	for child in node.get_children():
		var found := _find_first_button(child)
		if found != null:
			return found
	return null

func _find_grid(node: Node) -> GridContainer:
	if node is GridContainer:
		return node
	for child in node.get_children():
		var found := _find_grid(child)
		if found != null:
			return found
	return null

func _find_slider(node: Node) -> HSlider:
	if node is HSlider:
		return node as HSlider
	for child in node.get_children():
		var found := _find_slider(child)
		if found != null:
			return found
	return null

func _key_down(key: Key) -> void:
	if _abort_tests: return
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = true
	Input.parse_input_event(event)

func _key_up(key: Key) -> void:
	if _abort_tests: return
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = false
	Input.parse_input_event(event)

func _frames(count: int) -> void:
	for _index in count:
		await get_tree().process_frame

func _check(condition: bool, message: String) -> void:
	if _abort_tests: return
	if not condition:
		failures.append(message)
		_abort_tests = true

func _finish() -> void:
	if _finishing:
		return
	_finishing = true
	call_deferred("_finish_after_audio_shutdown")

func _finish_after_audio_shutdown() -> void:
	if is_instance_valid(main) and main.get_script() != null:
		var audio_node: Node = main.get("audio")
		if is_instance_valid(audio_node) and audio_node.has_method("shutdown"):
			audio_node.shutdown()
		await get_tree().create_timer(0.15).timeout
		main.queue_free()
		await _frames(3)
	if failures.is_empty():
		print("PASS: main scene integration checks")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		get_tree().quit(1)
