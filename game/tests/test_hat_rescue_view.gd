extends SceneTree

const Model = preload("res://game/minigames/hat_rescue_model.gd")
const View = preload("res://game/minigames/hat_rescue_view.gd")
const HUD = preload("res://game/ui/minigame_hud.gd")
const Session = preload("res://game/minigames/session.gd")
var checks := 0
var failures := 0
var last_axis := 99.0
var last_target := -1.0
var catches := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var model = Model.new()
	model.reset()
	var view = View.new()
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view.set_size(View.DESIGN_SIZE)
	view.axis_requested.connect(_on_axis)
	view.target_x_requested.connect(_on_target)
	view.catch_requested.connect(_on_catch)
	get_root().add_child(view)
	view.update_frame(model.snapshot(), "noon", false)
	_test_frame_bounds_and_avatar(view)
	_test_catch_pose_matches_idle_alignment(view)
	_test_replacement_hair_preserves_catch_head_and_hands(view)
	_test_hat_lanes_wind_and_motion(view, model)
	_test_walk_phase_uses_model_travel(view)
	_test_phase_and_accessibility(view, model)
	_test_controls(view)
	_test_empty_and_malformed_snapshot(view)
	await _test_authored_catch_sequence_and_feedback(view)
	await process_frame
	if failures == 0:
		print("Hat rescue view: %d checks passed" % checks)
		view.queue_free()
		quit(0)
	else:
		push_error("Hat rescue view: %d check(s) failed" % failures)
		view.queue_free()
		quit(1)

func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _on_axis(value: float) -> void:
	last_axis = value

func _on_target(value: float) -> void:
	last_target = value

func _on_catch(pressed: bool) -> void:
	if pressed:
		catches += 1

func _test_frame_bounds_and_avatar(view) -> void:
	var hud: Rect2 = view.hud_safe_rect()
	var stage: Rect2 = view.stage_bounds()
	var scene: Rect2 = view.geometry_bounds()
	_expect(hud.end.y <= 130.0 and stage.position.y > hud.end.y, "in-game picture starts under the fixed HUD reservation")
	_expect(stage.position == Vector2(0.0, 136.0) and stage.end.y == View.DESIGN_SIZE.y, "complete side-on harbor scene stays inside the 1280x720 frame")
	_expect(scene.position.y >= hud.end.y and stage.encloses(scene), "the measured union of authored scene geometry stays inside reserved play bounds")
	_expect(scene.position == Vector2(0.0, 136.0) and scene.end == Vector2(1280.0, 720.0), "geometry bounds include full-width boardwalk and bottom instruction plate")
	_expect(View.HAT_RENDER_BOUNDS.position.y > hud.end.y and stage.encloses(View.HAT_RENDER_BOUNDS), "the full falling hat lane fits beneath the HUD and inside the frame")
	_expect(View.CHARACTER_RENDER_BOUNDS.position.x >= stage.position.x and stage.encloses(View.CHARACTER_RENDER_BOUNDS), "full-body avatar stays visible at both rail endpoints")
	_expect(view.catch_line_y() == Model.CATCH_Y and View.CATCH_LINE_Y == Model.CATCH_Y, "rendered hand contact line and model collision height are the same coordinate")
	_expect(view.uses_authored_avatar(), "catcher uses the existing full-body authored AvatarRenderer pose")

func _test_catch_pose_matches_idle_alignment(view) -> void:
	var library: RefCounted = view._renderer.animation_library
	# The approved registered idle bypasses the retired library idle atlas.
	# Compare visible pixels from the texture actually drawn in the game.
	var idle_image: Image = view._idle_texture.get_image()
	var idle_head_y := _central_hair_top(idle_image)
	var idle_bottom := _opaque_bottom(idle_image)
	var idle_bounds: Rect2i = idle_image.get_used_rect()
	var frame_data: Array = library.manifest.get("actors", {}).get("traveller", {}).get("catch", {}).get("front", {}).get("frames", [])
	var one_shared_scale := true
	var shared_scale := -1.0
	var anchors_within_head_range := true
	var all_feet_share_baseline := true
	var all_pose_bounds_fit := true
	for frame_index in view._catch_frames.size():
		var frame: Dictionary = {}
		if frame_index < frame_data.size() and frame_data[frame_index] is Dictionary:
			frame = frame_data[frame_index]
		var scale := float(frame.get("source_scale", -1.0))
		if shared_scale < 0.0:
			shared_scale = scale
		elif not is_equal_approx(shared_scale, scale):
			one_shared_scale = false
		var head: Vector2i = library.normalized_anchor("traveller", "catch", "front", frame_index, "head", view._equipped)
		var feet: Vector2i = library.normalized_anchor("traveller", "catch", "front", frame_index, "feet", view._equipped)
		var image: Image = view._catch_frames[frame_index].get_image()
		var bounds: Rect2i = image.get_used_rect()
		anchors_within_head_range = anchors_within_head_range and abs(head.y - idle_head_y) <= 12 and abs(_central_hair_top(image) - idle_head_y) <= 12
		all_feet_share_baseline = all_feet_share_baseline and feet == Vector2i(140, 346) and abs(_opaque_bottom(image) - idle_bottom) <= 1
		all_pose_bounds_fit = all_pose_bounds_fit and bounds.position.x >= 0 and bounds.position.y >= 0 and bounds.end.x <= 280 and bounds.end.y <= 360 and bounds.position.y <= idle_bounds.position.y + 12 and bounds.end.y >= idle_bottom - 1
	_expect(one_shared_scale and is_equal_approx(shared_scale, 0.50625), "all twelve v5 catch frames use the documented uniform .81 pixel scale, never independently fitted bodies")
	_expect(anchors_within_head_range and all_feet_share_baseline, "anatomical hair-top anchors stay within twelve normalized pixels of idle while every pose shares the approved foot baseline")
	_expect(all_pose_bounds_fit, "the full-body action textures, including raised hands, remain visible on the shared canvas")

func _central_hair_top(image: Image) -> int:
	# Exclude the raised hands on either side of the anatomical head.
	for y in range(180):
		for x in range(110, 171):
			if image.get_pixel(x, y).a >= 0.5:
				return y
	return image.get_height()

func _opaque_bottom(image: Image) -> int:
	for y in range(image.get_height() - 1, -1, -1):
		for x in image.get_width():
			if image.get_pixel(x, y).a >= 0.5:
				return y
	return -1

func _test_replacement_hair_preserves_catch_head_and_hands(view) -> void:
	# Actual v5 failure sites: an open forehead after replacing hair, and palms
	# hidden behind the new cut. These probes are independent of mask metadata.
	var hand_points := {5:[Vector2i(75,160),Vector2i(205,160)],6:[Vector2i(80,114),Vector2i(202,114)]}
	for frame in [5,6]:
		var base: Image = view._renderer.texture(view._appearance,view._equipped,"front",frame,"catch").get_image()
		for style in ["bob","curly"]:
			var appearance: Dictionary = view._appearance.duplicate()
			appearance.hair = style
			var image: Image = view._renderer.texture(appearance,view._equipped,"front",frame,"catch").get_image()
			var solid_head := true
			for point in [Vector2i(140,130),Vector2i(145,135),Vector2i(151,140),Vector2i(121,180),Vector2i(163,180)]:
				solid_head = solid_head and image.get_pixelv(point).a >= 0.95
			_expect(solid_head,"%s catch frame %d keeps the anatomical forehead and cheeks opaque" % [style,frame])
			var intact_palms := true
			for point in hand_points[frame]:
				intact_palms = intact_palms and base.get_pixelv(point).a >= 0.95 and image.get_pixelv(point) == base.get_pixelv(point)
			_expect(intact_palms,"%s catch frame %d preserves both original paletted palms in front of hair" % [style,frame])

func _test_hat_lanes_wind_and_motion(view, model) -> void:
	var state: Dictionary = model.snapshot()
	_expect(state.hats.size() == 6 and state.ledger.size() == 6, "six distinct hat trajectories and catch records are presented")
	_expect(view.wind_glyph() == "→" and bool(state.forecast_visible), "the pennant previews gust direction before the first wind force")
	var first_hat: Dictionary = state.hats[0]
	model.step(0.35)
	state = model.snapshot()
	first_hat = state.hats[0]
	view.update_frame(state, "noon", false)
	_expect(first_hat.active and first_hat.y > 176.0 and first_hat.landing_x > 0.0, "visible hat position and landing marker come from the integrated trajectory")
	_expect(is_equal_approx(float(first_hat.eta), model._time_to_contact(float(first_hat.y), float(first_hat.vy))), "display ETA derives from current vertical velocity and contact plane")
	_expect(view.visible_hat_angle(first_hat) == first_hat.rotation, "ordinary motion shows the true physical hat spin")
	var next_x := float(state.next_spawn_x)
	_expect(next_x > Model.PLAYER_MIN_X and next_x < Model.PLAYER_MAX_X, "the fixed next-hat pickup lane previews within reachable rails")
	var rack_model = Model.new()
	var rack_guard := 0
	while str(rack_model.snapshot().ledger[0].status) == "waiting" and rack_guard < 100:
		var falling: Dictionary = rack_model.snapshot().hats[0]
		if falling.active:
			rack_model.set_target_x(float(falling.landing_x))
			if float(falling.eta) <= 0.30 and float(rack_model.snapshot().catch_window) <= 0.0:
				rack_model.set_catch(true)
		rack_model.step(0.02)
		rack_guard += 1
	view.update_frame(rack_model.snapshot(), "noon", false)
	_expect(rack_guard < 100 and rack_model.caught == 1, "a real timed center input creates one caught entry for the display rack")
	_expect(view.visible_rack_hat_count() == 1, "the recovered brim is represented in its actual rack slot, not a generic counter icon")

func _test_walk_phase_uses_model_travel(view) -> void:
	var left_count: int = view._renderer.walk_frame_count("left")
	var right_count: int = view._renderer.walk_frame_count("right")
	var cached_left: Array[Texture2D] = view._left_walk.duplicate()
	var cached_right: Array[Texture2D] = view._right_walk.duplicate()
	_expect(left_count > 0 and right_count > 0 and view._left_walk.size() == left_count and view._right_walk.size() == right_count, "all authored left and right walk frames are cached from AvatarRenderer metadata")
	var still := {"elapsed": 0.0, "player_x": 640.0, "player_velocity": 0.0}
	view.update_frame(still)
	_expect(view.visible_walk_frame_index() == -1 and is_zero_approx(view._walk_distance), "an idle player has no walk frame and starts at phase zero")
	var moving := {"elapsed": 0.1, "player_x": 660.0, "player_velocity": 120.0}
	view.update_frame(moving)
	var moved_phase: int = view.visible_walk_frame_index()
	_expect(moved_phase > 0 and is_equal_approx(view._walk_distance, 20.0), "walk phase advances from measured player travel, not elapsed wall time")
	var held := {"elapsed": 0.3, "player_x": 660.0, "player_velocity": 120.0}
	view.update_frame(held)
	_expect(view.visible_walk_frame_index() == moved_phase and is_equal_approx(view._walk_distance, 20.0), "standing still across advancing model time does not animate the walk cycle")
	var turn := {"elapsed": 0.4, "player_x": 650.0, "player_velocity": -120.0}
	view.update_frame(turn)
	_expect(view.visible_walk_frame_index() == int(floor(30.0 / View.WALK_CYCLE_DISTANCE * float(left_count))) % left_count, "turning selects the opposite authored direction while retaining accumulated gait phase")
	view.update_frame({"elapsed": 0.45, "player_x": 650.0, "player_velocity": -120.0, "catch_pose": 1.0})
	_expect(view.visible_catch_frame_index() == -1 and view.visible_walk_frame_index() >= 0, "moving catches retain authored locomotion instead of sliding planted reach cels")
	view.update_frame({"elapsed":0.46,"player_x":650.0,"player_velocity":0.0,"catch_pose":0.0})
	view.update_frame({"elapsed":0.47,"player_x":650.0,"player_velocity":0.0,"catch_pose":1.0})
	_expect(view.visible_catch_frame_index()==0 and view.visible_walk_frame_index()==-1,"a new stationary catch starts its complete planted one-shot")
	var moving_reach := {"elapsed":0.49,"player_x":652.0,"player_velocity":28.0,"catch_pose":0.8}
	view.update_frame(moving_reach)
	_expect(view.visible_catch_frame_index()==-1 and view.visible_walk_frame_index()>=0 and moving_reach.catch_pose==0.8,"starting to move cancels only the cosmetic reach and preserves the model catch cue")
	view.update_frame({"elapsed":0.51,"player_x":652.0,"player_velocity":0.0,"catch_pose":0.6})
	_expect(view.visible_catch_frame_index()==-1 and view.visible_walk_frame_index()==-1,"stopping restores idle and never resumes a partly played planted reach")
	view.update_frame({"elapsed": 0.0, "player_x": 650.0, "player_velocity": 0.0})
	_expect(is_zero_approx(view._walk_distance) and view.visible_walk_frame_index() == -1, "a model-clock retry resets the gait phase and returns to idle")
	view.update_frame({"elapsed": 0.1, "player_x": 672.0, "player_velocity": 100.0})
	_expect(view._left_walk == cached_left and view._right_walk == cached_right, "walk textures remain cached across movement, turns and retries")

func _test_phase_and_accessibility(view, model) -> void:
	model.step(0.28)
	var moving: Dictionary = model.snapshot().hats[0]
	view.update_frame(model.snapshot(), "dawn", false)
	var dawn_phase: String = view.time_palette_phase()
	view.update_frame(model.snapshot(), "dusk", false)
	var dusk_phase: String = view.time_palette_phase()
	view.update_frame(model.snapshot(), "night", true)
	_expect(dawn_phase == "dawn" and dusk_phase == "dusk" and view.time_palette_phase() == "night", "dawn, dusk and night retain their own four-phase palettes")
	_expect(view.trajectory_motion_enabled() and not view.decorative_motion_enabled(), "reduced motion removes decorative movement while preserving hat travel")
	_expect(view.visible_hat_angle(moving) == 0.0 and moving.y > 176.0, "reduced motion can stop decorative spin without hiding falling position")
	_expect(view.wind_glyph() == "→", "lower motion leaves directional wind information available")
	var before: Color = view.sky_color()
	view.update_frame(model.snapshot(), "noon", true)
	_expect(view.sky_color() != before, "noon selection changes palette independently of accessibility mode")

func _test_controls(view) -> void:
	var left_press := InputEventKey.new()
	left_press.keycode = KEY_LEFT
	left_press.pressed = true
	view._gui_input(left_press)
	_expect(last_axis == -1.0, "left key emits a continuous movement-axis state")
	var right_press := InputEventKey.new()
	right_press.keycode = KEY_RIGHT
	right_press.pressed = true
	view._gui_input(right_press)
	_expect(last_axis == 0.0, "opposite held key cancels instead of producing a diagonal teleport")
	var key_release := InputEventKey.new()
	key_release.keycode = KEY_LEFT
	key_release.pressed = false
	view._gui_input(key_release)
	_expect(last_axis == 1.0, "releasing one direction retains the other held direction")
	var space := InputEventKey.new()
	space.keycode = KEY_SPACE
	space.pressed = true
	view._gui_input(space)
	_expect(catches == 1, "Space emits one timed reach action")
	var mouse_move := InputEventMouseMotion.new()
	mouse_move.position = Vector2(780.0, 540.0)
	view._gui_input(mouse_move)
	_expect(last_target == 780.0 and catches == 1, "absolute mouse movement steers continuously without accidentally reaching")
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = true
	mouse.position = Vector2(850.0, 540.0)
	view._gui_input(mouse)
	_expect(last_target == 850.0 and catches == 2, "pointer rail click requests physical movement and a short reach")
	var drag := InputEventMouseMotion.new()
	drag.position = Vector2(920.0, 540.0)
	drag.button_mask = MOUSE_BUTTON_MASK_LEFT
	view._gui_input(drag)
	_expect(last_target == 920.0, "drag updates the same absolute target without teleporting the model")

func _test_empty_and_malformed_snapshot(view) -> void:
	view.update_frame({})
	_expect(view.visible_rack_hat_count() == 0 and view._active_hat_index() == -1, "an empty initial snapshot safely renders an empty rack and no active trajectory")
	view.update_frame({"ledger": [null, {"status": "center"}, "bad"], "hats": [null, {"active": true, "resolved": false, "x": 600.0, "y": 300.0}]})
	_expect(view.visible_rack_hat_count() == 1 and view._active_hat_index() == 1, "malformed ledger and hat entries are skipped without hiding valid neighboring data")
	view.update_frame({"ledger": "invalid", "hats": "invalid"})
	_expect(view.visible_rack_hat_count() == 0 and view._active_hat_index() == -1, "wrongly typed cache fields fall back to a safe empty display")
	view.update_frame({})

func _test_authored_catch_sequence_and_feedback(view) -> void:
	_expect(view.authored_catch_frame_count() == 12 and is_equal_approx(view.authored_catch_frame_rate(), 20.0), "catch action uses all twelve dedicated empty-hand front frames at the authored 20 fps")
	var action_model = Model.new()
	action_model.set_catch(true)
	var observed_frames := {}
	var initial_textures: Array[Texture2D] = view._catch_frames.duplicate()
	for _tick in 45:
		var state: Dictionary = action_model.snapshot()
		view.update_frame(state, "noon", false)
		var frame_index: int = view.visible_catch_frame_index()
		if frame_index >= 0 and frame_index < view._catch_frames.size():
			observed_frames[frame_index] = true
		action_model.step(0.02)
	_expect(observed_frames.size() == 12, "the view-only 0.60 second one-shot completes all twelve frames although model catch eligibility stays at 0.38 seconds")
	_expect(view._catch_frames.size() == initial_textures.size() and view._catch_frames == initial_textures and view._catch_frames.all(func(texture: Texture2D) -> bool: return texture != null), "per-frame catch updates reuse cached dedicated authored textures and allocate no replacement pose")

	# A retry during an active reach rewinds only the visual clock; it does not affect model catch eligibility.
	action_model.reset()
	view.update_frame(action_model.snapshot(), "noon", false)
	_expect(not view._visual_catch_active and view.visible_catch_frame_index() == -1, "model-clock rewind during a reach immediately clears the stale visual one-shot")
	action_model.step(0.10)
	view.update_frame(action_model.snapshot(), "noon", false)
	_expect(view.visible_catch_frame_index() == -1, "the retry's idle interval does not resume an old catch frame")
	action_model.set_catch(true)
	view.update_frame(action_model.snapshot(), "noon", false)
	_expect(view._visual_catch_active and view.visible_catch_frame_index() == 0, "a fresh catch after retry starts at frame zero")
	action_model.step(0.12)
	view.update_frame(action_model.snapshot(), "noon", false)
	_expect(view.visible_catch_frame_index() >= 2, "the new reach advances from its own model elapsed clock")
	var paused_frame: int = view.visible_catch_frame_index()
	var paused_state: Dictionary = action_model.snapshot()
	for _pause_tick in 4:
		view.update_frame(paused_state, "noon", false)
	_expect(view.visible_catch_frame_index() == paused_frame, "a frozen model elapsed value freezes the reach animation across view updates")
	action_model.step(0.06)
	view.update_frame(action_model.snapshot(), "noon", false)
	_expect(view.visible_catch_frame_index() > paused_frame, "the reach animation resumes only when the model clock advances")

	var hud := HUD.new()
	hud.set_size(View.DESIGN_SIZE)
	get_root().add_child(hud)
	await process_frame
	var session := Session.new()
	session.mode = "hat_catching"
	session.p = Vector2(640.0, View.CATCH_LINE_Y)
	var production_anchor: Vector2 = session._feedback_anchor()
	hud.set_feedback_at("caught +120", production_anchor)
	var banner := Rect2(hud._feedback.position, hud._feedback.size)
	var full_actor := Rect2(session.p.x - View.PLAYER_DRAW_SIZE.x * 0.5, View.PLAYER_GROUND_Y - View.PLAYER_DRAW_SIZE.y, View.PLAYER_DRAW_SIZE.x, View.PLAYER_DRAW_SIZE.y)
	var forecast_and_landing_cues := Rect2(510.0, 202.0, 260.0, 166.0)
	var next_hat_label := Rect2(607.0, 420.0, 66.0, 22.0)
	_expect(production_anchor == Vector2(640.0, 448.0), "the actual Session feedback route anchors Hat feedback in the clear upper playfield band")
	_expect(banner == Rect2(370.0, 370.0, 540.0, 48.0), "HUD lays out the production feedback at the measured 540×48 banner rectangle")
	_expect(banner.end.y < full_actor.position.y and not banner.intersects(View.HUD_SAFE_RECT) and not banner.intersects(forecast_and_landing_cues) and not banner.intersects(next_hat_label) and not banner.intersects(full_actor), "actual HUD banner rectangle clears HUD, forecast/landing and next-hat labels, and full avatar bounds")
	session.free()
	hud.queue_free()
	_expect(view.bottom_control_hint().length() <= 24, "bottom hint stays a compact control legend; full instructions belong in tutorial")
