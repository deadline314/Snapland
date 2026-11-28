extends "res://game/tests/native_review.gd"
## Native review of 逆潮港 (MAIN-69) through the real main scene: the door with
## eleven harbour devil stickers, then twelve; a chase played by a lane-picking
## bot (stills of the lanes, a barrel wind-up, the current flip warning, the
## fog and beam, a catch, the lighthouse finale, a 12-frame throw strip); the
## result; then an untouched chase ending in the postcard.
## python tools/run_native_capture.py res://game/tests/native_tide_chase_review.tscn --out <dir> --timeout 1500

const Game = preload("res://game/minigames/arcade/tide_chase_driver.gd")
const ProgressScript = preload("res://game/core/progress.gd")

var out := ""
var shots := {}
var strip: Array[Image] = []


func _run() -> void:
	out = OS.get_environment("SNAPLAND_CAPTURE_DIR")
	if out.is_empty() or DisplayServer.get_name() == "headless" or OS.get_environment("SNAPLAND_SAVE_PATH").is_empty():
		push_error("Native tide chase review needs a GPU window, SNAPLAND_CAPTURE_DIR and an isolated save")
		get_tree().quit(1)
		return
	progress = get_tree().root.get_node_or_null("Progress")
	progress.reset_progress()
	progress.intro_seen = true
	for index in range(1, 12):
		progress.photos["photo-harbor-devil-%d" % index] = {"devil": true}
	# Enough ordinary stickers to walk into the harbour and see the gate itself.
	for index in range(1, 7):
		progress.photos["photo-welcome-game-%d" % index] = {"game_id": "game-%03d" % index}
	main = _instantiate_main()
	get_tree().root.add_child(main)
	await get_tree().create_timer(1.5).timeout
	if not await _see_the_gate():
		return
	main._open_rift("harbor", "查看逆潮港")
	await _settle(8)
	if main.overlay.find_child("RiftEnter", true, false) != null or _find_label(main.overlay, "還差 1 張") == null:
		await _fail("The harbour door with eleven devil stickers should stay shut and say one is missing")
		return
	_save("door-locked")
	main._close()
	await _settle()
	progress.photos["photo-harbor-devil-12"] = {"devil": true}
	var coins_before: int = progress.coins
	var normal_before: int = progress.normal_count()
	main._open_rift("harbor", "查看逆潮港")
	await _settle()
	var enter := main.overlay.find_child("RiftEnter", true, false) as BaseButton
	if enter == null:
		await _fail("The harbour door with twelve devil stickers has no way in")
		return
	enter.pressed.emit()
	await _settle()
	if main.session == null or main.session.game_id != "rift-harbor":
		await _fail("The chase did not start")
		return
	if not await _play(true):
		return
	await _settle(30)
	_save("result")
	var photo: Dictionary = progress.photos.get(ProgressScript.rift_photo_id("harbor"), {})
	if photo.is_empty() or (photo.get("frames", []) as Array).is_empty() or progress.coins != coins_before + ProgressScript.RIFT_FIRST_COINS or progress.normal_count() != normal_before:
		await _fail("The lamp's return should keep one framed photo, pay and change no counts: %s" % str(photo))
		return
	main._close()
	await _settle()
	main._launch_rift("harbor")
	await _settle()
	Engine.time_scale = 6.0
	if not await _play(false):
		return
	Engine.time_scale = 1.0
	await _settle(8)
	if (progress.photos.get(ProgressScript.rift_photo_id("harbor", true), {}).get("frames", []) as Array).is_empty():
		await _fail("An untouched chase should keep the postcard")
		return
	_save_strip()
	print("PASS: tide chase native door, chase, finale, result and postcard: %s" % ", ".join(shots.keys()))
	await main._quit_game()


## Walk into the harbour and stand south of the 逆潮港 gate for a picture.
func _see_the_gate() -> bool:
	main._travel_to_region("harbor")
	var deadline := Time.get_ticks_msec() + 60000
	while (main.world_region != "harbor" or main.changing_region) and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	await get_tree().create_timer(2.0).timeout
	var point: Dictionary = main.world._point_by_id("harbor:rift")
	if main.world_region != "harbor" or point.is_empty():
		await _fail("Could not reach the harbour gate (region %s)" % main.world_region)
		return false
	main.world.player.global_position = (point.position as Vector3) + Vector3(0, 0.3, 3.2)
	await get_tree().create_timer(1.5).timeout
	await _settle(10)
	_save("gate")
	if str(main.world.nearest.get("id", "")) != "harbor:rift":
		main.world.player.global_position = (point.position as Vector3) + Vector3(0, 0.3, 0.6)
		await get_tree().create_timer(1.0).timeout
	print("gate nearest: %s" % str(main.world.nearest.get("id", "")))
	return true


func _play(bot: bool) -> bool:
	var deadline := Time.get_ticks_msec() + 400000
	var game: Game = main.session.active_driver
	var next_report := 0
	while main.session != null and not main.session.ended and Time.get_ticks_msec() < deadline:
		if main.session.paused:
			main.session.set_paused(false)
		var state: Dictionary = game.snapshot()
		if Time.get_ticks_msec() >= next_report:
			next_report = Time.get_ticks_msec() + 10000
			print("tide review: stage %s, %.0f s played, %d catches, shots %s" % [game.stage, game.play_time, game.catches, ", ".join(shots.keys())])
		if bot:
			_bot(game)
			await _collect(game, state)
		elif bool(state.get("photo_ready", false)) and not shots.has("postcard"):
			Engine.time_scale = 1.0
			await _settle(30)
			_save("postcard")
		await get_tree().process_frame
	if main.session != null and not main.session.ended:
		await _fail("The chase did not end in time")
		return false
	return true


func _collect(game: Game, state: Dictionary) -> void:
	var throw := float(state.get("throw_age", 99.0))
	if game.stage == "play" and throw > 0.35 and throw < 0.6 and not shots.has("barrel-windup"):
		_save("barrel-windup")
	# Wind-up through fling and follow-through: every fourth rendered frame.
	if game.stage == "play" and throw > 0.3 and throw < 0.6 and strip.is_empty():
		for i in 12:
			for skip in 4:
				await RenderingServer.frame_post_draw
			var frame := get_viewport().get_texture().get_image()
			frame.convert(Image.FORMAT_RGB8)
			strip.append(frame)
	if float(state.get("flip_warning", -1.0)) > 0.4 and not shots.has("flip-warning"):
		_save("flip-warning")
	if game.catches == 2 and game.clock - game.caught_at > 3.0 and game.stage == "play" and not shots.has("fog-beam") and not game.barrels.is_empty():
		_save("fog-beam")
	var caught := game.clock - float(state.get("caught_at", -99.0))
	if caught > 0.15 and caught < 0.4 and not shots.has("catch"):
		_save("catch")
	if bool(state.get("photo_ready", false)) and not shots.has("finale"):
		await _settle(6)
		_save("finale")


func _bot(game: Game) -> void:
	if game.stage != "play" or game.phase != "chase":
		return
	var danger := {}
	for barrel in game.barrels:
		if game.barrel_seen(barrel) and float(barrel.x) > 150.0 and float(barrel.x) < 560.0:
			danger[int(barrel.lane)] = true
	if game.clock - game.throw_at < Game.THROW_WIND + 0.4:
		danger[game.throw_lane] = true
	var target := game.lane
	var best_flow := -INF
	for lane in Game.LANES:
		var flow := game.current(lane) - absf(lane - game.lane) * 8.0
		if danger.has(lane):
			flow -= 500.0
		if flow > best_flow:
			best_flow = flow
			target = lane
	if absf(game.raft_lane() - game.lane) < 0.05 and target != game.lane:
		_send(game, KEY_UP if target < game.lane else KEY_DOWN)
	if game.in_reach() and game.can_throw():
		_send(game, KEY_SPACE)


func _send(game: Game, code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.pressed = pressed
		game.handle_input(event, Vector2.ZERO)


func _save(name: String) -> void:
	var image := get_viewport().get_texture().get_image()
	image.convert(Image.FORMAT_RGB8)
	image.save_png(out.path_join("tide-%s.png" % name))
	shots[name] = true


func _save_strip() -> void:
	if strip.is_empty():
		return
	var cell := Vector2i(320, 240)
	var sheet := Image.create(cell.x * 6, cell.y * 2, false, Image.FORMAT_RGB8)
	for i in strip.size():
		var frame: Image = strip[i]
		var scale := Vector2(frame.get_size()) / Vector2(1280, 720)
		# The right half of the picture, where 錨錨 winds up and throws.
		var crop := frame.get_region(Rect2i(Vector2i(int(560 * scale.x), int(150 * scale.y)), Vector2i(int(640 * scale.x), int(480 * scale.y))))
		crop.resize(cell.x, cell.y, Image.INTERPOLATE_BILINEAR)
		sheet.blit_rect(crop, Rect2i(Vector2i.ZERO, cell), Vector2i((i % 6) * cell.x, (i / 6) * cell.y))
	sheet.save_png(out.path_join("tide-throw-strip.png"))
	shots["throw-strip"] = true


func _find_label(node: Node, needle: String) -> Label:
	if node is Label and (node as Label).text.contains(needle):
		return node
	for child in node.get_children():
		var found := _find_label(child, needle)
		if found != null:
			return found
	return null


func _settle(count := 4) -> void:
	for i in count:
		await RenderingServer.frame_post_draw
