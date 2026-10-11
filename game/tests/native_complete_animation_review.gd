extends "res://game/tests/native_layout_review.gd"

const LibraryScript := preload("res://game/world/character_animation_library.gd")
const NpcActivityScript := preload("res://game/world/npc_activity.gd")
const DIRECTIONS := ["front", "front_right", "right", "back_right", "back", "back_left", "left", "front_left"]
const ACTORS := ["traveller", "ticket", "imp", "announcer"]
const CATEGORIES := ["stance", "idle", "greet", "interact", "emotion", "special", "walk"]
const CLIP_WATCHDOG_SECONDS := 300.0
const FONT := preload("res://assets/fonts/NotoSansCJKtc-Regular.otf")
const IMAGE_DIR := "pm/Snapland-art/images"

var library: RefCounted
var sprites: Dictionary = {}
var materials: Dictionary = {}
var sprite_baselines: Dictionary = {}
var ground_baselines: Dictionary = {}
var _capture_only := false
var _clip_only := false
var _missing: Array[String] = []
var _coverage: Dictionary = {}
var _hud: Label
var _gallery: Control
var _gallery_layer: CanvasLayer
var _frame_issues: Array[String] = []
var _capture_roles: Array[String] = []
var _clip_watchdog: Timer
var _action_filter := ""
var _closeup: TextureRect
var _closeup_label: Label
var _world_process_baseline := true
var _world_physics_baseline := true
var _npc_process_baseline := true
var _npc_activity_paused_baseline := false
var _report_stage := "startup"
var _report_path := ""
var _run_id := "%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
var _terminal_report_saved := false
var _movie_capture := false
var _output_fps := 0.0
var _output_fps_source := "live process delta"
var _forced_draws := 0
var _completed_clips: Array[Dictionary] = []
var _clip_progress: Dictionary = {}

func _run() -> void:
	if OS.get_environment("SNAPLAND_SAVE_PATH").is_empty() or DisplayServer.get_name() == "headless":
		push_error("Native complete animation review requires GPU and isolated SNAPLAND_SAVE_PATH")
		get_tree().quit(1)
		return
	_report_path = _resolve_report_path()
	_set_report_stage("reading arguments")
	_capture_only = OS.get_cmdline_user_args().has("--review-available")
	_clip_only = OS.get_cmdline_user_args().has("--review-clip-only")
	_capture_roles.clear()
	for actor in ACTORS:
		_capture_roles.append(str(actor))
	for argument in OS.get_cmdline_user_args():
		if str(argument).begins_with("--review-role="):
			var role := str(argument).trim_prefix("--review-role=")
			if not ACTORS.has(role):
				await _fail("Unknown --review-role '%s'; expected one of %s" % [role, ", ".join(ACTORS)])
				return
			_capture_roles.clear()
			_capture_roles.append(role)
		elif str(argument).begins_with("--review-action="):
			_action_filter = str(argument).trim_prefix("--review-action=")
	_clip_watchdog = Timer.new()
	_clip_watchdog.one_shot = true
	_clip_watchdog.wait_time = CLIP_WATCHDOG_SECONDS
	_clip_watchdog.timeout.connect(_on_clip_watchdog_timeout)
	add_child(_clip_watchdog)
	progress = get_tree().root.get_node_or_null("Progress")
	if progress == null:
		await _fail("Complete animation review has no Progress autoload")
		return
	progress.reset_progress()
	progress.intro_seen = true
	progress.settings["reduced_motion"] = false
	_set_report_stage("creating live main scene")
	main = _instantiate_main()
	if main == null:
		_report_stage = "failed"
		_save_report("failed", "Main scene could not be instantiated")
		get_tree().quit(1)
		return
	get_tree().root.add_child(main)
	await _frames(8)
	if main.world == null or main.world.npc_activity == null:
		await _fail("Complete animation review requires the live park and registered NPC activity")
		return
	library = LibraryScript.new()
	if library.manifest.is_empty():
		await _fail("Complete animation manifest is unavailable; --review-available cannot fake a capture")
		return
	_set_report_stage("binding live actors")
	_bind_live_sprites()
	if sprites.size() != ACTORS.size():
		await _fail("Live park actors are incomplete: %s" % str(sprites.keys()))
		return
	_build_coverage()
	_set_report_stage("coverage built")
	if not _action_filter.is_empty():
		var has_filtered_action := false
		for actor in _capture_roles:
			var actor_data: Dictionary = library.manifest.get("actors", {}).get(actor, {})
			if not _actions_for_capture(actor, actor_data).is_empty(): has_filtered_action = true
		if not has_filtered_action:
			await _fail("--review-action filter '%s' has no authored action for capture roles %s" % [_action_filter, ", ".join(_capture_roles)])
			return
	if not _capture_only and (not _missing.is_empty() or not _frame_issues.is_empty()):
		push_error("INCOMPLETE ANIMATION REVIEW: missing=%d frame issues=%d; see report, no full PASS" % [_missing.size(), _frame_issues.size()])
		_report_stage = "coverage incomplete"
		await _save_report("incomplete")
		_release_review_resources()
		get_tree().quit(1)
		return
	_pause_runtime_animation()
	main.world.player.position = Vector3(15, 0.4, -24.5)
	main.world.set_time_of_day("noon")
	if not _clip_only:
		_set_report_stage("capturing pose sheets")
		if not await _capture_pose_sheets(): return
	_set_report_stage("capturing animation clips")
	if not await _capture_clips(): return
	_set_report_stage("animation clips captured")
	_restore_live_sprites()
	_restore_runtime_animation()
	if not _clip_only:
		_set_report_stage("reviewing world controls and wardrobe")
		if not await _review_world_controls(): return
	var final_status := "available-only" if _capture_only else "complete"
	_report_stage = "finished"
	_save_report(final_status)
	if _capture_only:
		print("CAPTURE ONLY: captured available authored sequences; missing coverage=%d; this is not full animation acceptance." % _missing.size())
	else:
		print("PASS: selected authored sequences captured at normal and quarter speed. Naturalness remains a human visual judgment; see report for coverage and wardrobe scope.")
	_release_review_resources()
	await main._quit_game()

func _bind_live_sprites() -> void:
	sprites["traveller"] = main.world.avatar as Sprite3D
	for record: Dictionary in main.world.npc_activity._records:
		if not bool(record.get("active", false)): continue
		var role := String(record.get("role", ""))
		var target_ref := record.get("target") as WeakRef
		if ACTORS.has(role) and target_ref != null:
			sprites[role] = target_ref.get_ref() as Sprite3D
	for actor in sprites:
		var sprite := sprites[actor] as Sprite3D
		if sprite != null:
			materials[actor] = sprite.material_override as ShaderMaterial
			sprite_baselines[actor] = {"texture": sprite.texture, "pixel_size": sprite.pixel_size, "position": sprite.position, "flip_h": sprite.flip_h}
			var records: Array = []
			for index in main.world.sprite_ground_anchors.size():
				var record: Dictionary = main.world.sprite_ground_anchors[index]
				if record.get("sprite") == sprite:
					records.append({"index": index, "record": record.duplicate(true)})
			ground_baselines[actor] = records

func _build_coverage() -> void:
	var actor_manifest: Dictionary = library.manifest.get("actors", {})
	for actor in ACTORS:
		var actor_data: Dictionary = actor_manifest.get(actor, {})
		var actions := _action_entries(actor_data)
		var category_actions := _category_actions(actor, actions)
		var actor_report := {"categories": category_actions, "directions": {}, "required_directions": {}, "missing": []}
		for category in CATEGORIES:
			if not category_actions.has(category):
				_add_missing(actor, category, "<no matching action>")
		for action in actions:
			var directions: Dictionary = actions[action] if actions[action] is Dictionary else {}
			var required := _required_directions(actor, str(action), actions)
			actor_report.required_directions[str(action)] = required
			for direction in required:
				var entry: Dictionary = directions.get(direction, {})
				var frames: Array = entry.get("frames", []) if entry is Dictionary else []
				if frames.is_empty():
					_add_missing(actor, str(action), direction)
				else:
					var sequence := _sequence_for_capture(actor, str(action), direction)
					if not bool(sequence.get("available", false)):
						_add_missing(actor, str(action), direction + " (unreadable frame)")
					else:
						_check_sequence_frames(actor, str(action), direction, sequence.get("frames", []), actor_data)
			actor_report.directions[str(action)] = directions.keys()
		actor_report.missing = _missing.filter(func(value: String) -> bool: return value.begins_with(actor + "/"))
		actor_report.frame_issues = _frame_issues.filter(func(value: String) -> bool: return value.begins_with(actor + "/"))
		_coverage[actor] = actor_report

func _action_entries(actor_data: Dictionary) -> Dictionary:
	var result := {}
	for key in actor_data:
		var value: Variant = actor_data[key]
		if not value is Dictionary: continue
		if value.keys().any(func(direction: Variant) -> bool: return DIRECTIONS.has(str(direction))):
			result[str(key)] = value
	return result

func _actions_for_capture(actor: String, actor_data: Dictionary) -> Dictionary:
	var actions := _action_entries(actor_data)
	if _action_filter.is_empty(): return actions
	var filter_actor := ""
	var filter_action := _action_filter
	if _action_filter.contains("/"):
		var parts := _action_filter.split("/", false, 2)
		if parts.size() == 2:
			filter_actor = parts[0]
			filter_action = parts[1]
	if not filter_actor.is_empty() and filter_actor != actor: return {}
	return {filter_action: actions[filter_action]} if actions.has(filter_action) else {}

func _pause_runtime_animation() -> void:
	_world_process_baseline = main.world.is_processing()
	_world_physics_baseline = main.world.is_physics_processing()
	_npc_process_baseline = main.world.npc_activity.is_processing()
	_npc_activity_paused_baseline = bool(main.world.npc_activity.statistics().get("activity_paused", false))
	main.world.set_process(false)
	main.world.set_physics_process(false)
	main.world.npc_activity.set_activity_paused(true)
	main.world.npc_activity.set_process(false)

func _restore_runtime_animation() -> void:
	main.world.npc_activity.set_process(_npc_process_baseline)
	main.world.npc_activity.set_activity_paused(_npc_activity_paused_baseline)
	main.world.set_physics_process(_world_physics_baseline)
	main.world.set_process(_world_process_baseline)

func _required_directions(actor: String, action: String, actions: Dictionary) -> Array[String]:
	if actor == "traveller": return _string_array(DIRECTIONS)
	if actor == "ticket": return _string_array(["front"])
	if actor == "announcer": return _string_array(["front", "right", "left"])
	if actor == "imp" and actions.has("walk"): return _string_array(["front", "right", "left"])
	return _string_array(["front"])

func _string_array(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		result.append(str(value))
	return result

func _sequence_for_capture(actor: String, action: String, direction: String) -> Dictionary:
	var equipped: Dictionary = Progress.equipped.duplicate(true) if actor == "traveller" else {}
	return library.get_sequence(actor, action, direction, equipped)

func _category_actions(actor: String, actions: Dictionary) -> Dictionary:
	var picked := {}
	for raw_action in actions:
		var action := str(raw_action).to_lower()
		if action in ["stand", "stance"]: picked["stance"] = str(raw_action)
		elif action in ["idle", "idle_gesture"]: picked["idle"] = str(raw_action)
		elif action == "greet" or (actor == "traveller" and action == "wave"): picked["greet"] = str(raw_action)
		elif action == "interact": picked["interact"] = str(raw_action)
		elif action.begins_with("emotion_") and action != "emotion_static": picked["emotion"] = str(raw_action)
		elif action in ["special", "dance", "celebrate", "photograph", "quest"]: picked["special"] = str(raw_action)
		elif action == "walk": picked["walk"] = str(raw_action)
	return picked

func _add_missing(actor: String, action: String, direction: String) -> void:
	_missing.append("%s/%s/%s" % [actor, action, direction])

func _check_sequence_frames(actor: String, action: String, direction: String, frames: Array, actor_data: Dictionary) -> void:
	var canvas_size := Vector2.ZERO
	var baseline := NpcActivityScript.ACTION_FEET_ROW if actor != "traveller" else int(actor_data.get("feet_baseline", -1))
	for index in frames.size():
		var texture := frames[index].get("texture") as Texture2D
		if texture == null:
			_frame_issues.append("%s/%s/%s/frame-%d has no composed texture" % [actor, action, direction, index])
			continue
		if index == 0: canvas_size = texture.get_size()
		elif texture.get_size() != canvas_size:
			_frame_issues.append("%s/%s/%s/frame-%d canvas differs from first frame" % [actor, action, direction, index])
		var image := texture.get_image()
		var bounds := _alpha_bounds(image)
		if bounds.size == Vector2i.ZERO or bounds.position.x < 2 or bounds.position.y < 2 or bounds.end.x > image.get_width() - 2 or bounds.end.y > image.get_height() - 2:
			_frame_issues.append("%s/%s/%s/frame-%d ink touches canvas edge or frame is empty" % [actor, action, direction, index])
		var anchors: Variant = frames[index].get("anchors", {})
		var anchor: Variant = anchors.get("feet") if anchors is Dictionary else null
		if not anchor is Array or anchor.size() != 2:
			_frame_issues.append("%s/%s/%s/frame-%d has no feet anchor" % [actor, action, direction, index])
		if baseline < 0 or baseline >= image.get_height():
			_frame_issues.append("%s/%s/%s/frame-%d has no valid canonical feet baseline" % [actor, action, direction, index])
		elif bounds.size != Vector2i.ZERO:
			var bottom_delta := baseline - (bounds.end.y - 1)
			if bottom_delta < -1 or bottom_delta > 12:
				_frame_issues.append("%s/%s/%s/frame-%d visible shoe row is %dpx from canonical ground line" % [actor, action, direction, index, bottom_delta])

func _alpha_bounds(image: Image) -> Rect2i:
	var left := image.get_width()
	var top := image.get_height()
	var right := -1
	var bottom := -1
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a < 0.5: continue
			left = mini(left, x)
			top = mini(top, y)
			right = maxi(right, x)
			bottom = maxi(bottom, y)
	return Rect2i(left, top, right - left + 1, bottom - top + 1) if right >= left and bottom >= top else Rect2i()

func _capture_pose_sheets() -> bool:
	for actor in _capture_roles:
		var actor_data: Dictionary = library.manifest.get("actors", {}).get(actor, {})
		var actions := _actions_for_capture(actor, actor_data)
		for action_key in actions:
			var action := str(action_key)
			var direction_map: Dictionary = actions[action]
			var directions: Array[String] = []
			for direction_key in direction_map:
				if DIRECTIONS.has(str(direction_key)): directions.append(str(direction_key))
			directions.sort_custom(func(a: String, b: String) -> bool: return DIRECTIONS.find(a) < DIRECTIONS.find(b))
			for page in ceili(float(directions.size()) / 4.0):
				var first_dir := page * 4
				var page_sequences: Array[Dictionary] = []
				var page_frame_count := 0
				for column in mini(4, directions.size() - first_dir):
					var direction: String = directions[first_dir + column]
					var sequence := _sequence_for_capture(actor, action, direction)
					page_sequences.append(sequence)
					if bool(sequence.get("available", false)):
						page_frame_count = maxi(page_frame_count, (sequence.get("frames", []) as Array).size())
				for frame_index in page_frame_count:
					_new_gallery("姿勢原稿｜%s｜%s｜影格 %d｜方向 %d–%d（原始合成）" % [actor, action, frame_index + 1, first_dir + 1, mini(first_dir + 4, directions.size())])
					for column in page_sequences.size():
						var sequence: Dictionary = page_sequences[column]
						if not bool(sequence.get("available", false)): continue
						var frames: Array = sequence.get("frames", [])
						if frame_index >= frames.size(): continue
						var frame: Dictionary = frames[frame_index]
						var texture := frame.get("texture") as Texture2D
						var direction: String = directions[first_dir + column]
						if texture == null:
							_frame_issues.append("%s/%s/%s/frame-%d has no capture texture" % [actor, action, direction, frame_index])
							continue
						_set_live_texture(actor, texture)
						_gallery_cell(texture, column, direction, "%s/%s #%d" % [action, direction, frame_index + 1])
					await _frames(2)
					await _review_draw_frame()
					if not main._capture("%s/ART-17-%s-%s-%s-frame-%02d.png" % [IMAGE_DIR, actor, _safe_name(action), _safe_name(directions[first_dir]), frame_index + 1]):
						await _fail("Could not save live-actor pose sheet %s/%s page %d frame %d" % [actor, action, page + 1, frame_index + 1])
						return false
	return true

func _capture_clips() -> bool:
	# Begin on a process boundary with a populated Node process delta. This also
	# makes start/end process counters match the number of MovieWriter outputs.
	await get_tree().process_frame
	await get_tree().process_frame
	_configure_capture_clock()
	# Capture every authored action/direction. Filters split long libraries into
	# focused runs without changing strict coverage evaluation.
	for actor in _capture_roles:
		var actor_data: Dictionary = library.manifest.get("actors", {}).get(actor, {})
		var actions := _actions_for_capture(actor, actor_data)
		for action_key in actions:
			var action := str(action_key)
			var direction_map: Dictionary = actions[action]
			for direction_key in direction_map:
				var direction := str(direction_key)
				if not DIRECTIONS.has(direction): continue
				var sequence := _sequence_for_capture(actor, action, direction)
				var frames: Array = sequence.get("frames", [])
				if frames.is_empty() or not bool(sequence.get("available", false)): continue
				for speed: float in [1.0, 0.25]:
					var base_fps := maxf(0.01, float(sequence.get("fps", 1.0)))
					var duration_seconds := float(frames.size()) / (base_fps * speed)
					var expected_frames := ceili(duration_seconds * _output_fps) if _output_fps > 0.0 else -1
					var start_process_frame := Engine.get_process_frames()
					_clip_progress = {"actor": actor, "action": action, "direction": direction, "speed": speed, "source_fps": base_fps, "source_frame_count": frames.size(), "expected_output_frames": expected_frames, "output_frames": 0, "start_process_frame": start_process_frame, "duration_seconds": duration_seconds}
					_set_report_stage("clip %s/%s/%s at %.2f speed" % [actor, action, direction, speed])
					_new_gallery("動畫原速／慢速檢視｜%s｜%s｜%s｜%.2f×" % [actor, action, direction, speed], true)
					var elapsed_seconds := 0.0
					var output_frames := 0
					var last_frame_index := -1
					var display_texture: Texture2D
					_clip_watchdog.start()
					while output_frames < expected_frames if expected_frames >= 0 else elapsed_seconds < duration_seconds:
						# MovieWriter appends once per process iteration, including when an
						# occluded window prevents the automatic rendering loop from drawing.
						# Never use frame_post_draw as a clock for movie output.
						var action_time := (float(output_frames) / _output_fps if _output_fps > 0.0 else elapsed_seconds) * speed
						var frame_index := mini(floori(action_time * base_fps), frames.size() - 1)
						var source_frame: Dictionary = frames[frame_index]
						var source_texture := source_frame.get("texture") as Texture2D
						if source_texture == null:
							_clip_watchdog.stop()
							await _fail("Clip frame has no composed texture: %s/%s/%s/%d" % [actor, action, direction, frame_index])
							return false
						if frame_index != last_frame_index:
							display_texture = _runtime_actor_texture(actor, action, direction, frame_index, source_texture)
						if display_texture == null:
							_clip_watchdog.stop()
							await _fail("Runtime avatar compositor returned null: %s/%s/%s/%d" % [actor, action, direction, frame_index])
							return false
						_set_live_texture(actor, display_texture)
						if _closeup != null:
							_closeup.texture = display_texture
							_closeup_label.text = "%s / %s / %s · frame %d/%d · %.2f×" % [actor, action, direction, frame_index + 1, frames.size(), speed]
						_hud.text = "LIVE PARK SPRITE + CANONICAL CLOSE-UP · %s · %s · %s · %.2f× · frame %d/%d" % [actor, action, direction, speed, frame_index + 1, frames.size()]
						_clip_progress.output_frames = output_frames
						_clip_progress.source_frame_index = frame_index
						if frame_index != last_frame_index: _save_report("running")
						last_frame_index = frame_index
						if _movie_capture:
							# Draw the viewport even if Windows suppresses window presentation.
							# No extra shader-time step: automatic draw owns its normal timestep.
							RenderingServer.force_draw(false, 0.0)
							_forced_draws += 1
						await get_tree().process_frame
						output_frames += 1
						elapsed_seconds += get_process_delta_time()
					_clip_watchdog.stop()
					_clip_progress.output_frames = output_frames
					_clip_progress.end_process_frame = Engine.get_process_frames()
					_clip_progress.process_frame_count = Engine.get_process_frames() - start_process_frame
					_clip_progress.recorded_duration_seconds = float(output_frames) / _output_fps if _output_fps > 0.0 else elapsed_seconds
					_completed_clips.append(_clip_progress.duplicate())
					print("ART-17 CLIP COMPLETE run_id=%s actor=%s action=%s direction=%s speed=%.2f output_frames=%d process_frames=%d source_fps=%.4f output_fps=%.4f" % [_run_id, actor, action, direction, speed, output_frames, _clip_progress.process_frame_count, base_fps, _output_fps])
					_clip_progress = {}
					_save_report("running")
	if _completed_clips.is_empty():
		await _fail("No available authored sequence was captured for the requested roles/actions")
		return false
	return true

func _configure_capture_clock() -> void:
	_movie_capture = not Engine.get_write_movie_path().is_empty()
	_output_fps = 0.0
	_output_fps_source = "live process delta"
	if _movie_capture:
		# Godot consumes --fixed-fps before exposing OS.get_cmdline_args(). Movie
		# mode fixes process delta to the actual writer FPS (CLI or project setting).
		_output_fps = _movie_output_fps()
		_output_fps_source = "MovieWriter fixed process delta / Engine.time_scale"

func _movie_output_fps() -> float:
	return maxf(1.0, roundf(Engine.time_scale / maxf(get_process_delta_time(), 0.000001)))

func _runtime_actor_texture(actor: String, action: String, direction: String, frame_index: int, source_texture: Texture2D) -> Texture2D:
	if actor != "traveller": return source_texture
	if main.world.avatar_renderer == null:
		_frame_issues.append("traveller/%s/%s has no AvatarRenderer" % [action, direction])
		return null
	return main.world.avatar_renderer.texture(Progress.appearance, Progress.equipped, direction, frame_index, action)

func _safe_name(value: String) -> String:
	var output := value.to_lower().replace("/", "-").replace("\\", "-").replace(" ", "-")
	return output.replace(":", "-").replace("*", "-").replace("?", "-")

func _set_live_texture(actor: String, texture: Texture2D) -> void:
	var sprite := sprites.get(actor) as Sprite3D
	if sprite == null: return
	sprite.texture = texture
	if actor == "traveller":
		var actor_data: Dictionary = library.manifest.get("actors", {}).get(actor, {})
		var canvas: Array = actor_data.get("canvas_size", [])
		var baseline := int(actor_data.get("feet_baseline", -1))
		if canvas.size() == 2 and int(canvas[1]) > 0 and baseline >= 0:
			sprite.pixel_size = 2.4 / float(canvas[1])
			for index in main.world.sprite_ground_anchors.size():
				var record: Dictionary = main.world.sprite_ground_anchors[index]
				if record.get("sprite") == sprite:
					record["feet_row"] = baseline + main.world.SPRITE_FOOT_GUARD_PIXELS
					record["canvas_height"] = int(canvas[1])
					main.world.sprite_ground_anchors[index] = record
		elif baseline < 0:
			_frame_issues.append("traveller/%s has no manifest feet baseline" % str(texture.get_size()))
	else:
		# Match ParkWorld's live NPC setup: normalized action cards are 320x460,
		# their ground line is row 448, and their scale uses the 420px visible body.
		sprite.pixel_size = 2.4 / float(NpcActivityScript.ACTION_VISIBLE_HEIGHT)
		sprite.position.y = sprite.pixel_size * (float(NpcActivityScript.ACTION_FEET_ROW) - float(NpcActivityScript.ACTION_CANVAS_SIZE.y) * 0.5)
	main.world._update_sprite_grounding()
	var material := materials.get(actor) as ShaderMaterial
	if material != null and material.shader != null:
		if material.get_shader_parameter("texture_albedo") != null:
			material.set_shader_parameter("texture_albedo", texture)
		if material.get_shader_parameter("uv_rect") != null:
			material.set_shader_parameter("uv_rect", Vector4(0, 0, 1, 1))

func _restore_live_sprites() -> void:
	for actor in sprites:
		var sprite := sprites[actor] as Sprite3D
		if sprite == null: continue
		var baseline: Dictionary = sprite_baselines.get(actor, {})
		sprite.texture = baseline.get("texture") as Texture2D
		sprite.pixel_size = float(baseline.get("pixel_size", sprite.pixel_size))
		sprite.position = baseline.get("position", sprite.position)
		sprite.flip_h = bool(baseline.get("flip_h", sprite.flip_h))
		var material := materials.get(actor) as ShaderMaterial
		if material != null and material.shader != null:
			if material.get_shader_parameter("texture_albedo") != null: material.set_shader_parameter("texture_albedo", sprite.texture)
			if material.get_shader_parameter("uv_rect") != null: material.set_shader_parameter("uv_rect", Vector4(0, 0, 1, 1))
		for saved: Dictionary in ground_baselines.get(actor, []):
			var index := int(saved.index)
			if index >= 0 and index < main.world.sprite_ground_anchors.size():
				main.world.sprite_ground_anchors[index] = saved.record
	main.world._update_sprite_grounding()

func _review_world_controls() -> bool:
	main.world.apply_settings({"reduced_motion": true})
	await _frames(3)
	_new_gallery("實際公園｜降低動態設定")
	if not await _capture_named("ART-17-reduced-motion"): return false
	main.world.apply_settings({"reduced_motion": false})
	var original_appearance: Dictionary = Progress.appearance.duplicate(true)
	main._show_wardrobe()
	await _frames(2)
	if main.modal_kind != "wardrobe":
		await _fail("Wardrobe did not open over the reviewed park")
		return false
	var hair_selector := main.wardrobe_panel.content.find_child("Appearance_hair", true, false) as OptionButton
	if hair_selector == null or hair_selector.item_count < 2:
		await _fail("Wardrobe appearance selector lacks a second authored hair choice")
		return false
	var next_hair := (hair_selector.selected + 1) % hair_selector.item_count
	hair_selector.select(next_hair)
	hair_selector.item_selected.emit(next_hair)
	await _frames(2)
	await _review_draw_frame()
	if not main._capture("%s/ART-17-wardrobe.png" % IMAGE_DIR):
		await _fail("Wardrobe capture failed")
		return false
	var apply_button := main.overlay.find_child("ApplyAppearance", true, false) as Button
	if apply_button == null:
		await _fail("Wardrobe apply control is missing")
		return false
	await _click_control(apply_button)
	await _frames(3)
	if Progress.appearance == original_appearance:
		await _fail("Wardrobe appearance change did not reach the live Progress state")
		return false
	await _review_draw_frame()
	if not main._capture("%s/ART-17-wardrobe-applied.png" % IMAGE_DIR):
		await _fail("Applied wardrobe appearance capture failed")
		return false
	if not Progress.set_appearance_batch(original_appearance):
		await _fail("Could not restore the isolated review appearance after wardrobe exercise")
		return false
	await _frames(2)
	main._show_pause()
	await _frames(2)
	if main.modal_kind != "pause":
		await _fail("Pause modal did not open over the reviewed park")
		return false
	if not main._capture("%s/ART-17-pause.png" % IMAGE_DIR):
		await _fail("Pause capture failed")
		return false
	main._close()
	return true

func _new_gallery(title: String, with_closeup: bool = false) -> void:
	# A movie frame is rendered explicitly before deferred frees are flushed.
	# Remove the previous sheet now so its HUD cannot cover a new clip's first frame.
	if _gallery_layer != null and is_instance_valid(_gallery_layer): _gallery_layer.free()
	_gallery_layer = CanvasLayer.new()
	_gallery_layer.name = "AnimationReviewLayer"
	_gallery_layer.layer = 100
	main.add_child(_gallery_layer)
	_gallery = Control.new()
	_gallery.name = "AnimationReviewSheet"
	_gallery.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_gallery.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gallery_layer.add_child(_gallery)
	_hud = Label.new()
	_hud.name = "AnimationReviewCounter"
	_hud.position = Vector2(24, 24)
	_hud.size = Vector2(900, 48)
	_hud.add_theme_font_override("font", FONT)
	_hud.add_theme_font_size_override("font_size", 26)
	_hud.add_theme_color_override("font_color", Color("#fff2d2"))
	_hud.add_theme_color_override("font_shadow_color", Color("#13273b"))
	_hud.add_theme_constant_override("shadow_offset_x", 2)
	_hud.add_theme_constant_override("shadow_offset_y", 2)
	_hud.text = title
	_gallery.add_child(_hud)
	_closeup = null
	_closeup_label = null
	if with_closeup:
		_closeup = TextureRect.new()
		_closeup.name = "CanonicalAnimationCloseup"
		_closeup.position = Vector2(940, 116)
		_closeup.size = Vector2(300, 460)
		_closeup.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_closeup.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_closeup.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_closeup.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_gallery.add_child(_closeup)
		_closeup_label = Label.new()
		_closeup_label.position = Vector2(884, 584)
		_closeup_label.size = Vector2(372, 44)
		_closeup_label.add_theme_font_override("font", FONT)
		_closeup_label.add_theme_font_size_override("font_size", 15)
		_closeup_label.add_theme_color_override("font_color", Color("#fff2d2"))
		_gallery.add_child(_closeup_label)

func _gallery_cell(texture: Texture2D, column: int, direction: String, label_text: String) -> void:
	var root := Control.new()
	root.position = Vector2(112 + column * 270, 208)
	root.size = Vector2(232, 390)
	_gallery.add_child(root)
	var rect := TextureRect.new()
	rect.position = Vector2(0, 32)
	rect.size = Vector2(232, 330)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.texture = texture
	root.add_child(rect)
	var label := Label.new()
	label.position = Vector2(0, 360)
	label.size = Vector2(232, 28)
	label.text = "%s · %s" % [direction, label_text]
	label.add_theme_font_override("font", FONT)
	label.add_theme_color_override("font_color", Color("#fff2d2"))
	root.add_child(label)

func _capture_named(name: String) -> bool:
	await _review_draw_frame()
	if not main._capture("%s/%s.png" % [IMAGE_DIR, name]):
		await _fail("Capture failed: " + name)
		return false
	return true

func _review_draw_frame() -> void:
	if not Engine.get_write_movie_path().is_empty():
		RenderingServer.force_draw(false, 0.0)
		_forced_draws += 1
	else:
		await RenderingServer.frame_post_draw

func _resolve_report_path() -> String:
	var save_path := OS.get_environment("SNAPLAND_SAVE_PATH")
	if save_path.begins_with("user://") or save_path.begins_with("res://"):
		save_path = ProjectSettings.globalize_path(save_path)
	var report_dir := save_path.get_base_dir().path_join(".review")
	return report_dir.path_join("ART-17-animation-review.json")

func _set_report_stage(stage: String) -> void:
	_report_stage = stage
	_save_report("running")

func _save_report(status: String, detail: String = "") -> void:
	if _report_path.is_empty():
		push_error("Could not resolve isolated animation review report path")
		return
	var report := {"status": status, "terminal": status != "running", "successful": status == "complete" or status == "available-only", "full_animation_accepted": status == "complete" and _missing.is_empty() and _frame_issues.is_empty(), "stage": _report_stage, "detail": detail, "capture_only": _capture_only, "clip_only": _clip_only, "capture_roles": _capture_roles, "capture_action_filter": _action_filter, "coverage_complete": _missing.is_empty() and _frame_issues.is_empty(), "missing_count": _missing.size(), "frame_issue_count": _frame_issues.size(), "wardrobe_change": "hair preview/apply/restore only; outfit purchase/wear is not covered", "visual_naturalness": "requires human GPU screenshot/video review", "clip_watchdog_seconds": CLIP_WATCHDOG_SECONDS}
	report.successful = report.successful and not _completed_clips.is_empty()
	report.run_id = _run_id
	report.full_animation_accepted = report.full_animation_accepted and report.successful and _capture_roles.size() == ACTORS.size() and _action_filter.is_empty()
	report.wardrobe_change = "not exercised (clip-only)" if _clip_only else report.wardrobe_change
	report.movie_capture = _movie_capture
	report.movie_path = Engine.get_write_movie_path()
	report.output_fps = _output_fps
	report.output_fps_source = _output_fps_source
	report.process_delta_seconds = get_process_delta_time()
	report.engine_time_scale = Engine.time_scale
	report.forced_draws = _forced_draws
	report.process_frames = Engine.get_process_frames()
	report.engine_automatic_draws = Engine.get_frames_drawn()
	report.completed_clips = _completed_clips
	report.completed_clip_count = _completed_clips.size()
	report.current_clip = _clip_progress
	if status != "running":
		report["missing"] = _missing
		report["frame_issues"] = _frame_issues
		report["actors"] = _coverage
	var directory_error := DirAccess.make_dir_recursive_absolute(_report_path.get_base_dir())
	if directory_error != OK and directory_error != ERR_ALREADY_EXISTS:
		push_error("Could not create isolated animation review report directory: " + str(directory_error))
		return
	var file := FileAccess.open(_report_path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write animation coverage report: " + _report_path)
		return
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	_terminal_report_saved = status != "running"
	print("ART-17 STATUS run_id=%s status=%s terminal=%s successful=%s full_animation_accepted=%s clips=%d stage=%s report=%s" % [_run_id, status, str(report.terminal), str(report.successful), str(report.full_animation_accepted), _completed_clips.size(), _report_stage, _report_path])
	if report.successful:
		print("ART-17 CAPTURE COMPLETE run_id=%s status=%s completed_clips=%d report=%s" % [_run_id, status, _completed_clips.size(), _report_path])

func _fail(message: String) -> void:
	_report_stage = "failed"
	_save_report("failed", message)
	push_error(message)
	if main != null and is_instance_valid(main) and main.audio != null:
		main.audio.shutdown()
	_release_review_resources()
	await get_tree().create_timer(0.15).timeout
	get_tree().quit(1)

func _on_clip_watchdog_timeout() -> void:
	var detail := "Animation clip exceeded its %.0f second watchdog; capture stopped." % CLIP_WATCHDOG_SECONDS
	_report_stage = "watchdog timeout"
	_save_report("failed", detail)
	push_error(detail)
	_release_review_resources()
	get_tree().quit(1)

func _release_review_resources() -> void:
	if _clip_watchdog != null and is_instance_valid(_clip_watchdog): _clip_watchdog.stop()
	if _gallery_layer != null and is_instance_valid(_gallery_layer): _gallery_layer.free()
	_gallery_layer = null
	_gallery = null
	_hud = null
	_closeup = null
	_closeup_label = null
	sprites.clear()
	materials.clear()
	sprite_baselines.clear()
	ground_baselines.clear()
	if library != null:
		# The harness owns this separate review library. Release all cached
		# textures/images/sequence references before the scene and renderer exit.
		library._sequences.clear()
		library._sequence_order.clear()
		library._textures.clear()
		library._texture_order.clear()
		library._images.clear()
		library._image_order.clear()
		library._layouts.clear()
		library = null

func _exit_tree() -> void:
	if not _report_path.is_empty() and not _terminal_report_saved:
		_save_report("interrupted", "Scene exited before capture completion; a frame cap or window close is not a successful capture.")
	_release_review_resources()
