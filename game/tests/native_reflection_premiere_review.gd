extends "res://game/tests/native_review.gd"
## Native review of 倒影大道 (MAIN-66) through the real main scene: the door
## with eleven devil stickers, the door with twelve, a full finale played by a
## bot that reads the reflection (stills and a 12-frame dash strip), the
## curtain-call result and album page, then an untouched round ending in
## 倒倒's selfie. Writes PNGs to SNAPLAND_CAPTURE_DIR.
## python tools/run_native_capture.py res://game/tests/native_reflection_premiere_review.tscn --out <dir> --timeout 900

const Game = preload("res://game/minigames/arcade/reflection_premiere_driver.gd")
const ProgressScript = preload("res://game/core/progress.gd")

var out := ""
var shots := {}
var strip: Array[Image] = []


func _run() -> void:
	out = OS.get_environment("SNAPLAND_CAPTURE_DIR")
	if out.is_empty() or DisplayServer.get_name() == "headless" or OS.get_environment("SNAPLAND_SAVE_PATH").is_empty():
		push_error("Native premiere review needs a GPU window, SNAPLAND_CAPTURE_DIR and an isolated save")
		get_tree().quit(1)
		return
	progress = get_tree().root.get_node_or_null("Progress")
	progress.reset_progress()
	progress.intro_seen = true
	for index in range(1, 12):
		progress.photos["photo-welcome-devil-%d" % index] = {"game_id": "game-%03d" % index, "devil": true}
	main = _instantiate_main()
	get_tree().root.add_child(main)
	await get_tree().create_timer(1.5).timeout
	# Eleven stickers: the door says what is missing and offers no way in.
	main._interact("rift", "查看倒影大道")
	await _settle()
	if main.overlay.find_child("RiftEnter", true, false) != null or _find_label(main.overlay, "還差 1 張") == null or _find_label(main.overlay, "迎賓大合奏") == null:
		await _fail("The door with eleven devil stickers should list 迎賓大合奏 and stay shut")
		return
	_save("door-locked")
	main._close()
	await _settle()
	progress.photos["photo-welcome-devil-12"] = {"game_id": "game-012", "devil": true}
	var coins_before: int = progress.coins
	main._interact("rift", "查看倒影大道")
	await _settle()
	var enter := main.overlay.find_child("RiftEnter", true, false) as BaseButton
	if enter == null:
		await _fail("The door with twelve devil stickers has no way in")
		return
	enter.pressed.emit()
	await _settle()
	if main.session == null or main.session.game_id != "rift-welcome":
		await _fail("The finale did not start")
		return
	if not await _play(true):
		return
	await _settle(30)
	_save("result")
	var photo: Dictionary = progress.photos.get("photo-welcome-backstage", {})
	if photo.is_empty() or (photo.get("frames", []) as Array).is_empty() or progress.coins != coins_before + ProgressScript.RIFT_FIRST_COINS or progress.normal_count() != 0 or progress.devil_count("welcome") != 12:
		await _fail("The curtain call should keep one framed backstage photo and %d coins and change no counts: %s" % [ProgressScript.RIFT_FIRST_COINS, str(photo)])
		return
	main._close()
	await _settle()
	main._interact("album", "翻閱拍貼收藏")
	await _settle()
	var tab := main.overlay.find_child("AlbumTab_devil", true, false) as BaseButton
	if tab == null:
		await _fail("Album devil tab missing")
		return
	tab.pressed.emit()
	await _settle(8)
	# The backstage photo follows the twelve cards: page four.
	for page in 3:
		var next := _find(main.overlay, "下一頁")
		if next != null:
			next.pressed.emit()
			await _settle(6)
	var album := main.overlay.find_child("AlbumPhoto_photo-welcome-backstage", true, false) as Control
	if album != null:
		album.grab_focus()
		await _settle(4)
	_save("album")
	main._close()
	await _settle()
	# An untouched show, sped up: the curtain falls early on 倒倒's selfie.
	main._launch_rift()
	await _settle()
	Engine.time_scale = 6.0
	if not await _play(false):
		return
	Engine.time_scale = 1.0
	await _settle(8)
	var selfie: Dictionary = progress.photos.get(ProgressScript.rift_photo_id("welcome", true), {})
	if selfie.is_empty() or (selfie.get("frames", []) as Array).is_empty():
		await _fail("An untouched show should keep 倒倒's selfie")
		return
	_save_strip()
	print("PASS: reflection premiere native door, finale, curtain photo, album and selfie: %s" % ", ".join(shots.keys()))
	await main._quit_game()


## Drive the finale until it ends; `bot` reads the reflection, otherwise nothing is pressed.
func _play(bot: bool) -> bool:
	var deadline := Time.get_ticks_msec() + 300000
	var game: Game = main.session.active_driver
	var next_report := 0
	while main.session != null and not main.session.ended and Time.get_ticks_msec() < deadline:
		# The off-screen window can lose focus, which pauses the session.
		if main.session.paused:
			main.session.set_paused(false)
		var state: Dictionary = game.snapshot()
		if Time.get_ticks_msec() >= next_report:
			next_report = Time.get_ticks_msec() + 10000
			print("premiere review: stage %s, %.0f s played, %d photos, shots %s" % [game.stage, game.play_time, game.captures, ", ".join(shots.keys())])
		if bot:
			_bot(game, state)
			await _collect(game, state)
		elif bool(state.get("photo_ready", false)) and not shots.has("selfie"):
			Engine.time_scale = 1.0
			await _settle(30)
			_save("selfie")
		await get_tree().process_frame
	if main.session != null and not main.session.ended:
		await _fail("The finale did not end in time")
		return false
	return true


## Stills at the telling moments, and a 12-frame strip of the first dash.
func _collect(game: Game, state: Dictionary) -> void:
	var dash: Dictionary = state.get("dash", {})
	if not dash.is_empty() and float(dash.t) > 0.3 and not shots.has("dash-telegraph"):
		_save("dash-telegraph")
	# Twelve consecutive frames from just before the strike through it.
	if not dash.is_empty() and float(dash.t) > 0.5 and strip.is_empty():
		_strip_centre = (float(dash.from) + float(dash.to)) * 0.5
		for i in 12:
			await RenderingServer.frame_post_draw
			var frame := get_viewport().get_texture().get_image()
			frame.convert(Image.FORMAT_RGB8)
			strip.append(frame)
	if bool(state.get("reflection_open", false)) and not bool(state.get("pose_open", false)) and not shots.has("reflection-lights-pose"):
		_save("reflection-lights-pose")
	if int(state.get("act", 1)) == 3 and str(state.boss.kind) == "drift" and not shots.has("act-three-mirror"):
		_save("act-three-mirror")
	if bool(state.get("lens_dirty", false)) and not shots.has("lens-confetti"):
		_save("lens-confetti")
	if bool(state.get("photo_ready", false)) and not shots.has("curtain-call"):
		await _settle(6)
		_save("curtain-call")


func _bot(game: Game, state: Dictionary) -> void:
	if game.stage != "play":
		return
	var target := game.frame_x
	var mirror: Dictionary = state.reflection
	var reflected_x := float(mirror.x)
	if bool(state.mirrored):
		reflected_x = 1280.0 - reflected_x
	if str(mirror.kind) == "pose" or str(state.boss.kind) == "pose":
		target = reflected_x if str(mirror.kind) == "pose" else float(state.boss.x)
	var dash: Dictionary = state.dash
	if not dash.is_empty():
		var low := minf(float(dash.from), float(dash.to)) - 110.0
		var high := maxf(float(dash.from), float(dash.to)) + 110.0
		if game.frame_x > low and game.frame_x < high:
			target = low - 40.0 if low - 40.0 > Game.X_MIN else high + 40.0
	for spot: float in state.spots:
		if float(state.get("confetti_t", 9.0)) < 1.35 and absf(target - spot) < 110.0:
			target = spot + (130.0 if spot < 640.0 else -130.0)
	var want := 0
	if target > game.frame_x + 10.0:
		want = 1
	elif target < game.frame_x - 10.0:
		want = -1
	if want != game._dir:
		_send(game, KEY_LEFT, false)
		_send(game, KEY_RIGHT, false)
		if want != 0:
			_send(game, KEY_RIGHT if want > 0 else KEY_LEFT, true)
	if game.pose_open() and absf(game.frame_x - float(state.boss.x)) < 50.0 and game.can_shoot():
		_send(game, KEY_SPACE, true)
		_send(game, KEY_SPACE, false)
	if game.lens_dirty():
		for code in [KEY_LEFT, KEY_RIGHT]:
			_send(game, code, true)
			_send(game, code, false)


func _send(game: Game, code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	game.handle_input(event, Vector2.ZERO)


func _save(name: String) -> void:
	var image := get_viewport().get_texture().get_image()
	image.convert(Image.FORMAT_RGB8)
	image.save_png(out.path_join("premiere-%s.png" % name))
	shots[name] = true


## The dash strip: twelve consecutive rendered frames, cropped around 倒倒.
func _save_strip() -> void:
	if strip.is_empty():
		return
	var cell := Vector2i(320, 300)
	var sheet := Image.create(cell.x * 6, cell.y * 2, false, Image.FORMAT_RGB8)
	for i in strip.size():
		var frame: Image = strip[i]
		var scale := Vector2(frame.get_size()) / Vector2(1280, 720)
		var crop := frame.get_region(Rect2i(Vector2i(0, int(150 * scale.y)), Vector2i(frame.get_width(), int(560 * scale.y))))
		crop.resize(cell.x * 2, cell.y, Image.INTERPOLATE_BILINEAR)
		var centre := clampi(int(_strip_centre / 1280.0 * cell.x * 2) - cell.x / 2, 0, cell.x)
		sheet.blit_rect(crop, Rect2i(Vector2i(centre, 0), cell), Vector2i((i % 6) * cell.x, (i / 6) * cell.y))
	sheet.save_png(out.path_join("premiere-dash-strip.png"))
	shots["dash-strip"] = true


var _strip_centre := 640.0


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
