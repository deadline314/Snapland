extends "res://game/review/hero_2d_sample.gd"

const HairRigScript := preload("res://game/world/hero_2d_hair_rig.gd")
var hair_rig: Variant
var _head_view: SubViewport
var _head_camera: Camera2D
var _motion_max: Dictionary = {}
var _maximum_root_error := 0.0
var _maximum_attachment_error := 0.0
var _left_head_points: Dictionary = {}
var _maximum_tip_pixels := 0.0
var _motion_trace: Array[Dictionary] = []
var _head_panel: SubViewportContainer

func _ready() -> void:
	super._ready()
	hair_rig = HairRigScript.new()
	hair_rig.name = "HairRig"
	_library.add_child(hair_rig)
	_library_ok = _library_ok and hair_rig.initialize(_library)
	if not _library_ok: return
	hair_rig.sync_pose(_state)
	_set_actor_layer(_library)
	var ancestor: Node = _library.get_parent()
	while ancestor != null:
		if ancestor is CanvasItem: ancestor.visibility_layer = ancestor.visibility_layer | 2
		ancestor = ancestor.get_parent()
	_setup_head_view()
	_update_appearance_labels()
	if "--hair-review" in OS.get_cmdline_user_args(): _requested_tour.call_deferred()

func _set_actor_layer(node: Node) -> void:
	if node is CanvasItem: node.visibility_layer = 2
	for child in node.get_children(): _set_actor_layer(child)

func _build_interface() -> void:
	super._build_interface()
	outfit_button.hide()
	var column: VBoxContainer = hair_button.get_parent()
	column.add_theme_constant_override("separation",6)
	for child in column.get_children():
		if child is Button: child.custom_minimum_size.y = 36
		if child is Label and child.text.begins_with("造型"): child.text = "微風短髮動態樣本"
		if child is Label and child.text.begins_with("移動："): child.text = "方向鍵移動 · Space 拍照
對照髮尾開關、帽子與慢速"
	status_label.custom_minimum_size.y = 32

func _setup_head_view() -> void:
	var column: VBoxContainer = hair_button.get_parent()
	_head_panel = SubViewportContainer.new()
	_head_panel.name = "HairCloseup"
	_head_panel.custom_minimum_size = Vector2(328,190)
	_head_panel.stretch = true
	column.add_child(_head_panel)
	column.move_child(_head_panel,2)
	_head_view = SubViewport.new()
	_head_view.size = Vector2i(328,190)
	_head_view.world_2d = get_viewport().world_2d
	_head_view.canvas_cull_mask = 2
	_head_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_head_view.transparent_bg = true
	_head_panel.add_child(_head_view)
	_head_camera = Camera2D.new()
	_head_camera.zoom = Vector2(1.4,1.4)
	_head_view.add_child(_head_camera)
	_head_camera.make_current()
	_update_head_camera()

func _process(delta: float) -> void:
	super._process(delta)
	if hair_rig == null or not _library_ok: return
	if not _paused:
		var dt := maxf(delta,0.0)*_speed_scale
		var velocity := _last_actual_displacement/dt if dt>0.0 else Vector2.ZERO
		hair_rig.advance(dt,velocity,_state)
	_update_head_camera()
	if _tour_running:
		var receipt: Dictionary = hair_rig.motion_receipt()
		var error: float = receipt.root.origin.length()+absf(receipt.root.get_rotation())
		_maximum_root_error = maxf(_maximum_root_error,error)
		var frame: Dictionary = _library.manifest.poses[_state.visual_direction][_state.action][_state.frame]
		var anchor: Array = frame.head_anchor
		var expected_head := Vector2(anchor[0]-140,anchor[1]-346-4)
		_maximum_attachment_error = maxf(_maximum_attachment_error,hair_rig.skeleton.position.distance_to(expected_head))
		if _state.visual_direction=="left" and _state.action=="walk": _left_head_points[str(anchor)] = true
		var amount: float = hair_rig.maximum_tip_displacement()
		_maximum_tip_pixels = maxf(_maximum_tip_pixels,amount)
		var context := "%s|%s" % [_state.visual_direction,str(_hat)]
		_motion_max[context] = maxf(float(_motion_max.get(context,0.0)),amount)
		_motion_trace.append({"time":_time_simulated,"heading":_state.visual_direction,"hat":_hat,"action":_state.action,"paused":_paused,"base":[hair_rig.spring.angles.x,hair_rig.spring.angles.y],"tip":[hair_rig.spring.tip_angles.x,hair_rig.spring.tip_angles.y],"root_error":error,"head":[hair_rig.skeleton.position.x,hair_rig.skeleton.position.y],"tip_displacement":amount})

func _render_current(force := false) -> void:
	super._render_current(force)
	if hair_rig != null: hair_rig.sync_pose(_state)

func _update_head_camera() -> void:
	if _head_camera != null and hair_rig != null:
		_head_camera.position = _library.global_position+hair_rig.skeleton.position+Vector2(0,-18)
		_head_camera.force_update_scroll()

func _cycle_hair() -> void:
	if hair_rig == null: return
	hair_rig.set_motion_enabled(not hair_rig.motion_enabled)
	_update_appearance_labels()

func _update_appearance_labels() -> void:
	super._update_appearance_labels()
	if hair_button != null:
		hair_button.text = "髮尾動態：" + ("開" if hair_rig==null or hair_rig.motion_enabled else "關（原畫）")
	if appearance_label != null: appearance_label.text = "髮根固定 · 只讓髮尾輕擺"

func _place_actor_for_test(position: Vector2) -> void:
	super._place_actor_for_test(position)
	if hair_rig != null: hair_rig.reset_motion()

func _requested_tour() -> void:
	var output := OS.get_environment("SNAPLAND_HERO_2D_REVIEW_DIR")
	var save := OS.get_environment("SNAPLAND_SAVE_PATH")
	if not output.is_absolute_path() or not save.is_absolute_path():
		push_error("Hair review requires absolute isolated output/save paths")
		get_tree().quit(2)
		return
	start_tour(output,OS.get_environment("SNAPLAND_HERO_2D_QUARTER")=="1")
	var receipt: Dictionary = await tour_completed
	print("HERO_2D_HAIR_AUDIT "+JSON.stringify({"result":receipt.result,"checks":receipt.checks,"tip_max_pixels":receipt.hair_motion.tip_max_pixels,"attachment_max_error":receipt.hair_motion.attachment_max_error}))
	get_tree().quit(0 if receipt.result=="PASS_STATE_CHECKS" else 1)

func _run_tour() -> void:
	_tour_receipt.review = "ART-30 single original-style 2D hair bone sample"
	_tour_receipt["motion_source"] = "Unchanged ART-29 windswept textures; real Skeleton2D/Bone2D/Polygon2D; root/cap rigid"
	await _wait_frames(3)
	await _capture_hair("00-original-style.png")
	var all_views := true
	for hat in [false,true]:
		if _hat != hat: await _click_button(hat_button)
		for direction in DIRECTIONS:
			_place_actor_for_test(Vector2(420,500))
			await _press_keys(DIRECTION_KEYS[direction])
			await _wait_simulated(1.28)
			var key := "%s|%s" % [direction,str(hat)]
			var moved: float = _motion_max.get(key,0.0)
			all_views = all_views and _state.direction==direction and moved>0.15
			await _capture_hair("%s-hat%d-walk.png" % [direction,int(hat)])
			await _release_keys(DIRECTION_KEYS[direction])
			await _wait_simulated(0.16)
			await _capture_hair("%s-hat%d-stop.png" % [direction,int(hat)])
			await _wait_simulated(0.72)
		await _continuous_turns()
		await _exercise_halfstep_and_reverse()
	_tour_receipt.checks["eight_views_both_hat_states_move_tips"] = all_views
	_check(all_views,"all 16 direction/hat cases drive weighted hair tips")
	await _pause_rebound()
	await _hat_swap_and_original()
	await _photo_hair()
	await _wait_simulated(1.5)
	var settled: bool = hair_rig.spring.angles.length()<0.0002 and hair_rig.spring.tip_angles.length()<0.0002
	_tour_receipt.checks["rebound_settles"] = settled
	_tour_receipt.checks["root_bone_fixed"] = _maximum_root_error<0.00001
	_tour_receipt.checks["per_cel_head_following"] = _maximum_attachment_error<0.00001 and _left_head_points.size()==1
	_check(_maximum_attachment_error<0.00001 and _left_head_points.size()==1,"hair follows the changing head-pixel attachment rather than a constant body center")
	for required in ["idle","start","walk","stop","turn","photo"]:
		var seen: bool = _observed_actions.has(required)
		_tour_receipt.checks["observed_"+required] = seen
		_check(seen,"native hair tour observes "+required)
	_tour_receipt.checks["actual_native_bones"] = hair_rig.skeleton.get_bone_count()==7
	_tour_receipt.checks["no_composition_diagnostics"] = _library.get_diagnostics().is_empty()
	_check(settled,"stationary hair converges naturally to rest")
	_check(_maximum_root_error<0.00001,"hair root stays rigid in every action")
	_check(hair_rig.skeleton.get_bone_count()==7,"native skeleton contains root and three two-bone strands")
	_tour_receipt["hair_motion"] = {"root_max_error":_maximum_root_error,"attachment_max_error":_maximum_attachment_error,"left_head_points":_left_head_points.keys(),"tip_max_pixels":_maximum_tip_pixels,"per_view_max_pixels":_motion_max,"geometry":hair_rig.geometry_receipt(),"trace":_motion_trace}
	_tour_receipt.observations.shutter_events = _shutter_count
	_tour_receipt.native_input_events = {"keys":_key_events_sent,"mouse_buttons":_mouse_events_sent}
	_tour_receipt.diagnostics = _library.get_diagnostics()
	await _capture_hair("99-settled.png")
	_finish_tour()

func _continuous_turns() -> void:
	_place_actor_for_test(Vector2(420,500))
	for direction in DIRECTIONS:
		for key in _keys_down.keys():
			if _keys_down[key]: _send_key(int(key),false)
		for key in DIRECTION_KEYS[direction]: _send_key(int(key),true)
		await _wait_simulated(0.34)
		_check(_state.visual_direction==direction,"continuous octant turn reaches %s" % direction)
	for key in _keys_down.keys():
		if _keys_down[key]: _send_key(int(key),false)
	await _wait_simulated(0.8)
	_tour_receipt.checks["continuous_turns_hat%d" % int(_hat)] = true

func _pause_rebound() -> void:
	_place_actor_for_test(Vector2(420,500))
	await _press_keys([KEY_D])
	await _wait_simulated(0.30)
	await _release_keys([KEY_D])
	await _click_button(pause_button)
	var before: Dictionary = hair_rig.motion_receipt()
	var swinging: bool = hair_rig.spring.angles.length()+hair_rig.spring.tip_angles.length()>0.0003
	await _wait_real(0.35)
	var frozen: bool = hair_rig.motion_receipt()==before
	await _capture_hair("pause-during-rebound.png")
	await _click_button(pause_button)
	await _wait_simulated(0.1)
	var resumed: bool = hair_rig.motion_receipt()!=before
	_tour_receipt.checks["pause_during_motion"] = swinging and frozen and resumed
	_check(swinging and frozen and resumed,"pause freezes a moving hair strand and resumes the same simulation")
	await _wait_simulated(1.0)

func _hat_swap_and_original() -> void:
	_place_actor_for_test(Vector2(420,500))
	await _press_keys([KEY_A])
	await _wait_simulated(0.45)
	await _click_button(hat_button)
	_check(absf(hair_rig.spring.angles.x)+absf(hair_rig.spring.angles.y)<deg_to_rad(3.1 if _hat else 6.1),"hat swap resets and respects limits")
	await _capture_hair("hat-swap-in-motion.png")
	await _click_button(hair_button)
	var off: bool = not hair_rig.motion_enabled and _library.get_node("Hero2DComposite").visible and hair_rig.spring.angles==Vector2.ZERO
	await _capture_hair("dynamic-off-original.png")
	await _click_button(hair_button)
	var on: bool = hair_rig.motion_enabled
	await _release_keys([KEY_A])
	await _wait_simulated(0.9)
	_tour_receipt.checks["original_toggle_and_hat_swap"] = off and on
	_check(off and on,"native button switches between exact original and weighted 2D hair")

func _photo_hair() -> void:
	_send_key(KEY_SPACE,true)
	_send_key(KEY_SPACE,false)
	await _wait_simulated(0.60)
	await _capture_hair("photo-foreground.png")
	_tour_receipt.checks["photo_foreground"] = _state.action=="photo" and _shutter_count==1
	_check(_state.action=="photo" and _shutter_count==1,"photo uses the authored camera/hands foreground with one shutter")
	await _wait_simulated(0.8)

func _capture_hair(filename: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image.save_png(_tour_output_dir.path_join(filename))!=OK: _tour_failures.append("capture failed: "+filename)
	if _head_view!=null:
		var head := _head_view.get_texture().get_image()
		head.save_png(_tour_output_dir.path_join("head-"+filename))
	_tour_receipt.captures.append({"image":filename,"pose":_state.duplicate(true),"hair":hair_rig.motion_receipt()})

func _capture_fullbody(filename: String) -> void:
	await _capture_hair(filename)
