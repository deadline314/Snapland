extends "res://game/tests/native_review.gd"
## Native review of 午夜移動市 (MAIN-72) through the real main scene: the gate in
## the night market, the door with eleven devil stickers then twelve, a show
## played by a sneaking bot (stills of the light, the "hm?", a catch, the cart
## marks, the floating lantern, a 12-frame strip of 燈燈 jumping when tapped),
## the lit-street finale, the result, then an untouched show ending as a lantern.
## python tools/run_native_capture.py res://game/tests/native_lantern_sneak_review.tscn --out <dir> --timeout 1500

const Game = preload("res://game/minigames/arcade/lantern_sneak_driver.gd")
const ProgressScript = preload("res://game/core/progress.gd")

var out := ""
var shots := {}
var strip: Array[Image] = []
var _keys := {}


func _run() -> void:
	out = OS.get_environment("SNAPLAND_CAPTURE_DIR")
	if out.is_empty() or DisplayServer.get_name() == "headless" or OS.get_environment("SNAPLAND_SAVE_PATH").is_empty():
		push_error("Native sneak review needs a GPU window, SNAPLAND_CAPTURE_DIR and an isolated save")
		get_tree().quit(1)
		return
	progress = get_tree().root.get_node_or_null("Progress")
	progress.reset_progress()
	progress.intro_seen = true
	for index in range(1, 7):
		progress.photos["photo-welcome-game-%d" % index] = {"game_id": "game-%03d" % index}
	for index in range(1, 12):
		progress.photos["photo-nightmarket-devil-%d" % index] = {"devil": true}
	main = _instantiate_main()
	get_tree().root.add_child(main)
	await get_tree().create_timer(1.5).timeout
	if not await _see_the_gate():
		return
	main._open_rift("nightmarket", "查看午夜移動市")
	await _settle(8)
	if main.overlay.find_child("RiftEnter", true, false) != null or _find_label(main.overlay, "還差 1 張") == null:
		await _fail("The night market door with eleven devil stickers should stay shut and say one is missing")
		return
	_save("door-locked")
	main._close()
	await _settle()
	progress.photos["photo-nightmarket-devil-12"] = {"devil": true}
	var coins_before: int = progress.coins
	var normal_before: int = progress.normal_count()
	main._open_rift("nightmarket", "查看午夜移動市")
	await _settle()
	var enter := main.overlay.find_child("RiftEnter", true, false) as BaseButton
	if enter == null:
		await _fail("The night market door with twelve devil stickers has no way in")
		return
	enter.pressed.emit()
	await _settle()
	if main.session == null or main.session.game_id != "rift-nightmarket":
		await _fail("The sneak did not start")
		return
	if not await _play(true):
		return
	await _settle(30)
	_save("result")
	var photo: Dictionary = progress.photos.get(ProgressScript.rift_photo_id("nightmarket"), {})
	if photo.is_empty() or (photo.get("frames", []) as Array).is_empty() or progress.coins != coins_before + ProgressScript.RIFT_FIRST_COINS or progress.normal_count() != normal_before:
		await _fail("The lit street should keep one framed photo, pay and change no counts: %s" % str(photo))
		return
	main._close()
	await _settle()
	main._launch_rift("nightmarket")
	await _settle()
	Engine.time_scale = 6.0
	if not await _play(false):
		return
	Engine.time_scale = 1.0
	await _settle(8)
	if (progress.photos.get(ProgressScript.rift_photo_id("nightmarket", true), {}).get("frames", []) as Array).is_empty():
		await _fail("An untouched sneak should keep the lantern photo")
		return
	_save_strip()
	print("PASS: lantern sneak native gate, door, sneak, lit street, result and lantern: %s" % ", ".join(shots.keys()))
	await main._quit_game()


func _see_the_gate() -> bool:
	main._travel_to_region("nightmarket")
	var deadline := Time.get_ticks_msec() + 60000
	while (main.world_region != "nightmarket" or main.changing_region) and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	await get_tree().create_timer(2.0).timeout
	var point: Dictionary = main.world._point_by_id("nightmarket:rift")
	if main.world_region != "nightmarket" or point.is_empty():
		await _fail("Could not reach the night market gate (region %s)" % main.world_region)
		return false
	deadline = Time.get_ticks_msec() + 15000
	while str(main.world.nearest.get("id", "")) != "nightmarket:rift" and Time.get_ticks_msec() < deadline:
		main.world.player.global_position = (point.position as Vector3) + Vector3(0, 0.3, 0.6)
		await get_tree().create_timer(0.5).timeout
	print("gate nearest: %s" % str(main.world.nearest.get("id", "")))
	main.world.player.global_position = (point.position as Vector3) + Vector3(0, 0.3, 1.6)
	await get_tree().create_timer(2.5).timeout
	await _settle(10)
	_save("gate")
	return true


func _play(bot: bool) -> bool:
	var deadline := Time.get_ticks_msec() + 400000
	var game: Game = main.session.active_driver
	var next_report := 0
	_keys.clear()
	while main.session != null and not main.session.ended and Time.get_ticks_msec() < deadline:
		if main.session.paused:
			main.session.set_paused(false)
		var state: Dictionary = game.snapshot()
		if Time.get_ticks_msec() >= next_report:
			next_report = Time.get_ticks_msec() + 10000
			print("sneak review: stage %s, %.0f s played, %d taps, %d caught, shots %s" % [game.stage, game.play_time, game.taps, game.caught, ", ".join(shots.keys())])
		if bot:
			_bot(game)
			await _collect(game, state)
		elif bool(state.get("photo_ready", false)) and not shots.has("lantern"):
			Engine.time_scale = 1.0
			await _settle(30)
			if main.session != null and main.session.paused:
				main.session.set_paused(false)
				await _settle(3)
			_save("lantern")
		await get_tree().process_frame
	if main.session != null and not main.session.ended:
		await _fail("The sneak did not end in time")
		return false
	return true


func _collect(game: Game, state: Dictionary) -> void:
	if game.stage == "play" and game.play_time > 3.0 and not shots.has("light"):
		_save("light")
	if game.alerting() and not shots.has("hm"):
		_save("hm")
	var caught := game.clock - game.caught_at
	if caught > 0.3 and caught < 0.6 and not shots.has("caught"):
		_save("caught")
	if not (state.get("cart_targets", []) as Array).is_empty() and not shots.has("cart-marks"):
		_save("cart-marks")
	if game.act() == 3 and game.play_time > 0.0 and not shots.has("floating-lantern") and game.clock - game.tapped_at > 2.0:
		_save("floating-lantern")
	var tapped := game.clock - game.tapped_at
	if tapped >= 0.0 and tapped < 0.1 and strip.is_empty():
		for i in 12:
			for skip in 3:
				await RenderingServer.frame_post_draw
			var frame := get_viewport().get_texture().get_image()
			frame.convert(Image.FORMAT_RGB8)
			strip.append(frame)
	if bool(state.get("photo_ready", false)) and not shots.has("lit-street"):
		await _settle(6)
		_save("lit-street")


func _bot(game: Game) -> void:
	if game.stage != "play" or game.phase != "sneak":
		_hold(game, Vector2.ZERO)
		return
	if game.can_tap() and game.behind(game.player) and game.player.distance_to(game.spot) < Game.REACH - 8.0 and not game.lit(game.player):
		_send(game, KEY_SPACE, true)
		_send(game, KEY_SPACE, false)
		return
	var face := Vector2.from_angle(game.facing)
	var side := face.orthogonal()
	if side.dot(game.player - game.spot) < 0.0:
		side = -side
	var target := game.spot - face * 50.0
	if face.dot(game.player - game.spot) > -10.0 or game.alerting():
		target = game.spot + side * 140.0 - face * 20.0
	var dir := target - game.player
	if dir.length() < 4.0:
		_hold(game, Vector2.ZERO)
		return
	dir = dir.normalized()
	if game.lit(game.player + dir * Game.SPEED * 0.25) and not game.lit(game.player):
		_hold(game, Vector2.ZERO)
		return
	_hold(game, dir)


func _hold(game: Game, dir: Vector2) -> void:
	var want := {KEY_LEFT: dir.x < -0.35, KEY_RIGHT: dir.x > 0.35, KEY_UP: dir.y < -0.35, KEY_DOWN: dir.y > 0.35}
	for code: int in want:
		if bool(want[code]) != bool(_keys.get(code, false)):
			_keys[code] = want[code]
			_send(game, code, want[code])


func _send(game: Game, code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	game.handle_input(event, Vector2.ZERO)


func _save(name: String) -> void:
	var image := get_viewport().get_texture().get_image()
	image.convert(Image.FORMAT_RGB8)
	image.save_png(out.path_join("sneak-%s.png" % name))
	shots[name] = true


func _save_strip() -> void:
	if strip.is_empty():
		return
	var cell := Vector2i(320, 180)
	var sheet := Image.create(cell.x * 6, cell.y * 2, false, Image.FORMAT_RGB8)
	for i in strip.size():
		var frame := strip[i].duplicate() as Image
		frame.resize(cell.x, cell.y, Image.INTERPOLATE_BILINEAR)
		sheet.blit_rect(frame, Rect2i(Vector2i.ZERO, cell), Vector2i((i % 6) * cell.x, (i / 6) * cell.y))
	sheet.save_png(out.path_join("sneak-startle-strip.png"))
	shots["startle-strip"] = true


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
