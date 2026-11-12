extends "res://game/tests/native_island_hair_binding.gd"
## Actual Main input with explicit appearance, location and event fixtures.
const SWAPS := [
	{"outfit":"outfit-rainvest","hair":"curly","hat":"hat-straw"},
	{"outfit":"outfit-coral","hair":"bob","hat":"hat-sailor"},
	{"outfit":"outfit-rainvest","hair":"bob","hat":"hat-flower"},
	{"outfit":"outfit-tide","hair":"windswept","hat":"hat-none"},
]
var audit: Array = []
var captures := 0

func _run() -> void:
	evidence_dir=OS.get_environment("SNAPLAND_WARDROBE_MOTION_DIR")
	if not evidence_dir.is_absolute_path() or not OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path() or DisplayServer.get_name()=="headless":
		await _fail("Native motion review requires isolated paths and rendering")
		return
	DirAccess.make_dir_recursive_absolute(evidence_dir)
	get_tree().create_timer(240.0,true,false,true).timeout.connect(func(): get_tree().quit(1))
	Engine.time_scale=0.25 if OS.get_cmdline_user_args().has("--quarter") else 1.0
	progress=get_tree().root.get_node("Progress")
	progress.reset_progress()
	progress.intro_seen=true
	main=_instantiate_main()
	get_tree().root.add_child(main)
	main.world.camera.size=6.5
	var layer := CanvasLayer.new()
	add_child(layer)
	var backdrop := ColorRect.new()
	backdrop.position=Vector2(950,170)
	backdrop.size=Vector2(280,360)
	backdrop.color=Color("#354354")
	layer.add_child(backdrop)
	source_inset=TextureRect.new()
	source_inset.position=backdrop.position
	source_inset.size=backdrop.size
	source_inset.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	layer.add_child(source_inset)
	await _frames(4)
	if OS.get_cmdline_user_args().has("--reduced"):
		main.world.apply_settings({"reduced_motion":true})
		if not await _reduced(): return
	else:
		for fixture in [["front",[KEY_S]],["front_right",[KEY_S,KEY_D]],["right",[KEY_D]],["back_right",[KEY_W,KEY_D]],["back",[KEY_W]],["back_left",[KEY_W,KEY_A]],["left",[KEY_A]],["front_left",[KEY_S,KEY_A]]]:
			if not await _moving(str(fixture[0]),fixture[1]): return
		for action in ["wave","photograph","interact","celebrate"]:
			if not await _action_review(action): return
		await _tap(KEY_ESCAPE)
		if not main.world.blocked: await _fail("Pause input failed"); return
		var before: Dictionary=main.world.avatar_hair_rig.receipt()
		var clock: float=main.world.time
		await _frames(5)
		if before!=main.world.avatar_hair_rig.receipt() or clock!=main.world.time: await _fail("Paused wardrobe motion changed"); return
		await _capture("paused")
		await _tap(KEY_ESCAPE)
	var result := {"technical_status":"PASS","time_scale":Engine.time_scale,"reduced_review":OS.get_cmdline_user_args().has("--reduced"),"final_reduced_motion":main.world.reduced_motion,"observations":audit,"captures":captures,"scope":"Actual Main key input; appearance/location and interaction/celebration dispatch are explicit fixtures. Source inset is the actual final Sprite3D texture. No human gameplay/listening or hardware performance claim."}
	FileAccess.open(evidence_dir.path_join("audit.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("PASS: native wardrobe motion ",audit.size()," observations and ",captures," captures at ",Engine.time_scale)
	await main._quit_game()

func _set_look(index: int) -> bool:
	var before := [main.world.last_avatar_frame,main.world.avatar_action_elapsed,main.world.avatar_action_remaining,main.world.walk_distance_phase,main.world.player.global_position,main.world.facing]
	var spec: Dictionary=SWAPS[index%SWAPS.size()]
	var look: Dictionary=WalkRenderer.DEFAULT_APPEARANCE.duplicate()
	look.hair=spec.hair
	main.world.set_avatar_look(look,{"outfit":spec.outfit,"hat":spec.hat})
	var after := [main.world.last_avatar_frame,main.world.avatar_action_elapsed,main.world.avatar_action_remaining,main.world.walk_distance_phase,main.world.player.global_position,main.world.facing]
	if before!=after or not _avatar_texture_synced(): return false
	audit.append({"look":spec,"action":main.world.last_avatar_action,"source_action":main.world.last_avatar_source_action,"frame":main.world.last_avatar_frame,"phase":main.world.walk_distance_phase,"direction":main.world.facing,"same_progress_and_root":true})
	return true

func _moving(view: String, keys: Array) -> bool:
	for key in [KEY_W,KEY_A,KEY_S,KEY_D]: _held_key(key,false)
	main.world.player.position=Vector3(-4,0.4,-6)
	main.world.player.velocity=Vector3.ZERO
	await _frames(2)
	var look: Dictionary=WalkRenderer.DEFAULT_APPEARANCE.duplicate()
	look.hair="curly"
	main.world.set_avatar_look(look,{"outfit":"outfit-rainvest","hat":"hat-straw"})
	var start: Vector3=main.world.player.global_position
	var seen := {}
	var swapped := false
	var elapsed := 0.0
	while seen.size()<8 and elapsed<3.0:
		for key in [KEY_W,KEY_A,KEY_S,KEY_D]: _held_key(key,keys.has(key))
		await get_tree().physics_frame
		elapsed+=get_physics_process_delta_time()
		if not main.world.avatar_is_walking or main.world.facing!=view: continue
		var frame: int=main.world.last_avatar_frame
		if not seen.has(frame):
			seen[frame]=true
			await _capture("walk-%s-%d" % [view,frame])
		if frame>=2 and not swapped:
			if not _set_look(1) or not _set_look(0): await _fail("Moving appearance changed step or position"); return false
			swapped=true
	for key in [KEY_W,KEY_A,KEY_S,KEY_D]: _held_key(key,false)
	if seen.size()!=8 or not swapped or main.world.player.global_position.distance_to(start)<0.1:
		await _fail("Incomplete actual eight-cel walk: "+view+" "+str(seen)); return false
	await get_tree().create_timer(0.22).timeout
	if main.world.avatar_is_walking or main.world.facing!=view: await _fail("Stop changed facing or kept walking"); return false
	await _capture("stopped-"+view)
	audit.append({"walk":view,"frames":seen.keys(),"actual_displacement":main.world.player.global_position.distance_to(start)})
	return true

func _action_review(action: String) -> bool:
	if action=="wave": await _tap(KEY_F)
	elif action=="photograph": await _tap(KEY_P)
	else: main.world.play_action(action)
	if main.world.avatar_action!=action: await _fail("Action dispatch failed: "+action); return false
	var seen := {}
	var swaps := 0
	var elapsed := 0.0
	while main.world.avatar_action==action and main.world.avatar_action_remaining>0.0 and elapsed<3.0:
		var frame: int=main.world.last_avatar_frame
		if not seen.has(frame):
			seen[frame]=true
			if frame>=2 and swaps<SWAPS.size():
				if not _set_look(swaps): await _fail("Action appearance changed phase: "+action); return false
				swaps+=1
			await _capture("%s-%d" % [action,frame])
		await get_tree().physics_frame
		elapsed+=get_physics_process_delta_time()
	if seen.size()!=8 or swaps!=4: await _fail("Incomplete action poses/swaps: %s %s %d" % [action,seen,swaps]); return false
	audit.append({"action":action,"frames":seen.keys(),"live_swaps":swaps})
	await _capture(action+"-finished")
	return true

func _reduced() -> bool:
	for index in SWAPS.size():
		if not _set_look(index): await _fail("Reduced motion appearance changed phase"); return false
		await _capture("reduced-look-%d" % index)
	await _hold_for([KEY_D],0.4)
	for key in [KEY_W,KEY_A,KEY_S,KEY_D]: _held_key(key,false)
	if main.world.avatar_hair_rig.active: await _fail("Reduced motion retained secondary hair motion"); return false
	await _capture("reduced-movement")
	await _tap(KEY_P)
	await _capture("reduced-photograph")
	main.world.apply_settings({"reduced_motion":false})
	await _hold_for([KEY_A],0.4)
	for key in [KEY_W,KEY_A,KEY_S,KEY_D]: _held_key(key,false)
	await _capture("motion-restored")
	return true

func _capture(label: String) -> void:
	await super._capture(label)
	captures+=1
