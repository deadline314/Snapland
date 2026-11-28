extends "res://game/tests/native_review.gd"
## Native review of 反重力糖廠 (MAIN-70) through the real main scene: the gate
## in the candy factory, the door with eleven devil stickers then twelve, a
## show played by a bot that watches for the late wobble (one deliberate wrong
## scoop for the burst), stills, a 12-frame hop strip, the cake finale, the
## result, then an untouched show ending jellied. Writes PNGs to SNAPLAND_CAPTURE_DIR.
## python tools/run_native_capture.py res://game/tests/native_jelly_shell_review.tscn --out <dir> --timeout 1500

const Game = preload("res://game/minigames/arcade/jelly_shell_driver.gd")
const ProgressScript = preload("res://game/core/progress.gd")

var out := ""
var shots := {}
var strip: Array[Image] = []
var _blundered := false


func _run() -> void:
	out = OS.get_environment("SNAPLAND_CAPTURE_DIR")
	if out.is_empty() or DisplayServer.get_name() == "headless" or OS.get_environment("SNAPLAND_SAVE_PATH").is_empty():
		push_error("Native jelly review needs a GPU window, SNAPLAND_CAPTURE_DIR and an isolated save")
		get_tree().quit(1)
		return
	progress = get_tree().root.get_node_or_null("Progress")
	progress.reset_progress()
	progress.intro_seen = true
	for index in range(1, 7):
		progress.photos["photo-welcome-game-%d" % index] = {"game_id": "game-%03d" % index}
	for index in range(1, 12):
		progress.photos["photo-candy-devil-%d" % index] = {"devil": true}
	main = _instantiate_main()
	get_tree().root.add_child(main)
	await get_tree().create_timer(1.5).timeout
	if not await _see_the_gate():
		return
	main._open_rift("candy", "查看反重力糖廠")
	await _settle(8)
	if main.overlay.find_child("RiftEnter", true, false) != null or _find_label(main.overlay, "還差 1 張") == null:
		await _fail("The candy door with eleven devil stickers should stay shut and say one is missing")
		return
	_save("door-locked")
	main._close()
	await _settle()
	progress.photos["photo-candy-devil-12"] = {"devil": true}
	var coins_before: int = progress.coins
	var normal_before: int = progress.normal_count()
	main._open_rift("candy", "查看反重力糖廠")
	await _settle()
	var enter := main.overlay.find_child("RiftEnter", true, false) as BaseButton
	if enter == null:
		await _fail("The candy door with twelve devil stickers has no way in")
		return
	enter.pressed.emit()
	await _settle()
	if main.session == null or main.session.game_id != "rift-candy":
		await _fail("The jelly show did not start")
		return
	if not await _play(true):
		return
	await _settle(30)
	_save("result")
	var photo: Dictionary = progress.photos.get(ProgressScript.rift_photo_id("candy"), {})
	if photo.is_empty() or (photo.get("frames", []) as Array).is_empty() or progress.coins != coins_before + ProgressScript.RIFT_FIRST_COINS or progress.normal_count() != normal_before:
		await _fail("The cake should keep one framed photo, pay and change no counts: %s" % str(photo))
		return
	main._close()
	await _settle()
	main._launch_rift("candy")
	await _settle()
	Engine.time_scale = 6.0
	if not await _play(false):
		return
	Engine.time_scale = 1.0
	await _settle(8)
	if (progress.photos.get(ProgressScript.rift_photo_id("candy", true), {}).get("frames", []) as Array).is_empty():
		await _fail("An untouched show should keep the jellied photo")
		return
	_save_strip()
	print("PASS: jelly shell native gate, door, show, cake, result and jellied: %s" % ", ".join(shots.keys()))
	await main._quit_game()


func _see_the_gate() -> bool:
	main._travel_to_region("candy")
	var deadline := Time.get_ticks_msec() + 60000
	while (main.world_region != "candy" or main.changing_region) and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	await get_tree().create_timer(2.0).timeout
	var point: Dictionary = main.world._point_by_id("candy:rift")
	if main.world_region != "candy" or point.is_empty():
		await _fail("Could not reach the candy gate (region %s)" % main.world_region)
		return false
	# Stand right in front of the gate until it is the nearest point, then step
	# back a little so the gate itself is in the picture.
	deadline = Time.get_ticks_msec() + 15000
	while str(main.world.nearest.get("id", "")) != "candy:rift" and Time.get_ticks_msec() < deadline:
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
	while main.session != null and not main.session.ended and Time.get_ticks_msec() < deadline:
		if main.session.paused:
			main.session.set_paused(false)
		var state: Dictionary = game.snapshot()
		if Time.get_ticks_msec() >= next_report:
			next_report = Time.get_ticks_msec() + 10000
			print("jelly review: stage %s, %.0f s played, %d moulds, shots %s" % [game.stage, game.play_time, game.moulds, ", ".join(shots.keys())])
		if bot:
			_bot(game)
			await _collect(game, state)
		elif bool(state.get("photo_ready", false)) and not shots.has("jellied"):
			Engine.time_scale = 1.0
			await _settle(30)
			# The off-screen window may have lost focus and paused the show.
			if main.session != null and main.session.paused:
				main.session.set_paused(false)
				await _settle(3)
			print("jellied score %d, moulds %d" % [game.score, game.moulds])
			_save("jellied")
		await get_tree().process_frame
	if main.session != null and not main.session.ended:
		await _fail("The jelly show did not end in time")
		return false
	return true


func _collect(game: Game, state: Dictionary) -> void:
	if game.stage == "play" and game.round_phase == "split" and game.clock - game.round_at > 0.9 and not shots.has("split-ladle"):
		_save("split-ladle")
	if game.stage == "play" and game.round_phase == "shuffle" and game.act() == 2 and strip.is_empty():
		for i in 12:
			for skip in 2:
				await RenderingServer.frame_post_draw
			var frame := get_viewport().get_texture().get_image()
			frame.convert(Image.FORMAT_RGB8)
			strip.append(frame)
	if game.round_phase == "pick" and game.act() == 1 and not shots.has("pick"):
		_save("pick")
	var goo := game.clock - game.goo_at
	if goo > 0.15 and goo < 0.4 and not shots.has("burst"):
		_save("burst")
	if game.flipped() and game.round_phase == "shuffle" and not shots.has("gravity-flip"):
		_save("gravity-flip")
	if bool(state.get("photo_ready", false)) and not shots.has("cake"):
		await _settle(6)
		_save("cake")


## Watch for the late wobble; once, in act one, scoop a copy to see it burst.
func _bot(game: Game) -> void:
	if game.stage != "play" or game.round_phase != "pick" or game.phase != "show":
		return
	var latest := INF
	var target := game.cursor
	var decoy := -1
	for jelly: Dictionary in game.layout():
		if bool(jelly.popped):
			continue
		if float(jelly.t) < latest - 0.001:
			latest = float(jelly.t)
			target = roundi(float(jelly.x))
	for jelly: Dictionary in game.layout():
		if not bool(jelly.popped) and roundi(float(jelly.x)) != target:
			decoy = roundi(float(jelly.x))
	if not _blundered and game.act() == 1 and game.moulds == 1 and decoy >= 0:
		target = decoy
		if target == game.cursor and game.can_pick():
			_send(game, KEY_SPACE)
			_blundered = true
			return
	if target != game.cursor:
		_send(game, KEY_LEFT if target < game.cursor else KEY_RIGHT)
	elif game.can_pick():
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
	image.save_png(out.path_join("jelly-%s.png" % name))
	shots[name] = true


func _save_strip() -> void:
	if strip.is_empty():
		return
	var cell := Vector2i(320, 180)
	var sheet := Image.create(cell.x * 6, cell.y * 2, false, Image.FORMAT_RGB8)
	for i in strip.size():
		var frame: Image = strip[i]
		var crop := frame.duplicate() as Image
		crop.resize(cell.x, cell.y, Image.INTERPOLATE_BILINEAR)
		sheet.blit_rect(crop, Rect2i(Vector2i.ZERO, cell), Vector2i((i % 6) * cell.x, (i / 6) * cell.y))
	sheet.save_png(out.path_join("jelly-hop-strip.png"))
	shots["hop-strip"] = true


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
