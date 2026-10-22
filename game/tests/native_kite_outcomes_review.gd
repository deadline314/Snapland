extends "res://game/tests/native_kite_main_flow_review.gd"
## Genuine missed-ring failure, actual retry, and a pointer-flown edge/center route.
var _outcome: Dictionary = {}
var _outcome_state: Dictionary = {}

func _run() -> void:
	if not OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path() or DisplayServer.get_name()=="headless":_fail("Kite outcomes require GPU and an isolated absolute profile");return
	_wall_started_msec=Time.get_ticks_msec();_guard_active=true
	progress=get_tree().root.get_node("Progress");progress.reset_progress();progress.intro_seen=true
	progress.settings.assist=false;progress.settings.reduced_motion=false
	main=_instantiate_main();get_tree().root.add_child(main);await _frames(5)
	if not await _move_to_kite_station():return
	_key(KEY_E)
	if not await _wait_until(func():return main.modal_kind=="game_info","open actual kite station"):return
	if not await _activate_main_button("開始遊玩","start actual kite failure route"):return
	if not await _wait_until(func():return is_instance_valid(main.session),"kite session begins"):return
	var path:=OS.get_environment("SNAPLAND_SAVE_PATH")
	if not progress.save_progress():_fail("Save nonempty Kite baseline");return
	var baseline:=FileAccess.get_file_as_string(path)
	if baseline.is_empty():_fail("Empty full-save baseline");return
	var live:Control=main.session;live.finished.connect(_latch_outcome.bind(live),CONNECT_ONE_SHOT)
	_send_key(KEY_DOWN,true)
	if not await _wait_outcome(45000):return
	_send_key(KEY_DOWN,false)
	if bool(_outcome.success) or int(_outcome.score)!=0 or int(_outcome_state.misses)!=3 or int(_outcome_state.rescues_used)!=2 or FileAccess.get_file_as_string(path)!=baseline:
		_fail("Three actual missed rings did not fail with unchanged full save: "+str(_outcome_state));return
	if not await _review_kite_result_pages("kite-failed"):return
	var qualification:=main.overlay.find_child("ResultQualification",true,false) as Label
	if qualification==null or not qualification.text.contains("本次 0 / 5"):_fail("Failure hides actual ordinary qualification");return
	var failed:Dictionary={"result":_outcome.duplicate(true),"model":_outcome_state.duplicate(true),"complete_save_unchanged":true}
	var button:=_find(main.overlay,"再玩一次") as Button;var reset:Dictionary={}
	if button==null:_fail("Missing Kite result retry");return
	button.pressed.connect(func():
		var active:Control=main.session
		if is_instance_valid(active):reset.merge({"score":active.score,"elapsed":active.elapsed,"ring":active.kite_model.ring_index,"centers":active.kite_model.center_hits,"edges":active.kite_model.edge_hits,"misses":active.kite_model.misses,"rescues":active.kite_model.rescues_used,"events":active.score_events.size()})
	)
	if not await _native_click_button(button,"retry actual missed-ring result"):return
	if reset!={"score":0,"elapsed":0.0,"ring":0,"centers":0,"edges":0,"misses":0,"rescues":0,"events":0}:_fail("Kite retry retained state: "+str(reset));return
	_outcome.clear();_outcome_state.clear();live=main.session
	live.finished.connect(_latch_outcome.bind(live),CONNECT_ONE_SHOT)
	if not main._capture("kite-real-result-retry.png"):_fail("Capture Kite retry");return
	if not await _drive_edge_route(live):return
	if not await _wait_outcome(5000):return
	if not bool(_outcome.success) or bool(_outcome.devil) or int(_outcome.score)!=460 or int(_outcome_state.edge_hits)!=1 or int(_outcome_state.center_hits)!=4 or int(_outcome_state.rescues_used)!=0 or not progress.photos.has("photo-welcome-game-2") or progress.photos.has("photo-welcome-devil-2"):
		_fail("One edge plus four centers did not earn460 ordinary only: "+str(_outcome_state));return
	qualification=main.overlay.find_child("ResultQualification",true,false) as Label
	if qualification==null or not qualification.text.contains("本次中心 4 / 5") or not get_viewport().get_visible_rect().encloses(qualification.get_global_rect()):_fail("Ordinary result hides/clips actual devil qualification");return
	if not await _review_kite_result_pages("kite-ordinary"):return
	var ordinary:Dictionary={"result":_outcome.duplicate(true),"model":_outcome_state.duplicate(true)}
	if not await _activate_main_button("返回遊園","return from actual ordinary Kite result"):return
	if not await _wait_until(func():return main.session==null and main.modal_kind=="","return to park"):return
	var protected_before:=_progress_state()
	progress.settings.reduced_motion=true;progress.settings.time_phase="night"
	if not await _move_to_kite_station():return
	_key(KEY_E)
	if not await _wait_until(func():return main.modal_kind=="game_info","open Kite assisted replay"):return
	if not await _activate_main_button("玩法與選項","open optional formal assist"):return
	if not await _activate_main_button("輔助挑戰","launch real assisted formal Kite"):return
	if not await _wait_until(func():return is_instance_valid(main.session),"assisted formal Kite begins"):return
	live=main.session
	if not live.assisted or live.practice_mode or not live.reduced_motion or live.time_phase!="night":_fail("Assisted formal replay lost fixture night/reduced settings");return
	_outcome.clear();_outcome_state.clear();live.finished.connect(_latch_outcome.bind(live),CONNECT_ONE_SHOT)
	if not await _drive_edge_route(live,0.0,"assist-night"):return
	if not await _wait_outcome(5000):return
	if not bool(_outcome.success) or bool(_outcome.devil) or not bool(_outcome.assisted) or int(_outcome.score)!=500 or int(_outcome_state.center_hits)!=5 or progress.devil_count("welcome")!=0 or progress.normal_count()!=1:_fail("Assisted five centers did not retain ordinary-only qualification");return
	qualification=main.overlay.find_child("ResultQualification",true,false) as Label
	if qualification==null or not qualification.text.contains("輔助回合不取得"):_fail("Assisted result hides its individual devil eligibility");return
	if not await _review_kite_result_pages("kite-assisted-night"):return
	var protected_after:=_progress_state()
	for key in ["coins","achievements","owned_clothes","wardrobe_rewarded_games","pending_achievements"]:
		if protected_before[key]!=protected_after[key]:_fail("Formal replay duplicated a persistent reward: "+key);return
	FileAccess.open(path.get_base_dir().path_join("outcomes.json"),FileAccess.WRITE).store_string(JSON.stringify({"failed":failed,"retry_at_input":reset,"ordinary":ordinary,"assisted_night_reduced":{"result":_outcome,"model":_outcome_state,"persistent_rewards_unchanged":true},"result_pages_actual_pointer":true},"  "))
	if not await _activate_main_button("返回遊園","return from assisted formal replay"):return
	if not await _wait_until(func():return main.session==null and main.modal_kind=="","assisted replay returns to park"):return
	print("PASS: native Kite three real misses fail safely, result retry resets, pointer edge+four centers earn460 ordinary only, assisted night/reduced five centers earn500 ordinary only without duplicate rewards; all result pages clicked")
	_guard_active=false;await main._quit_game()

func _latch_outcome(result:Dictionary, live:Control) -> void:
	_outcome=result.duplicate(true);_outcome_state=live.kite_model.snapshot().duplicate(true)

func _wait_outcome(limit:int) -> bool:
	var deadline:=Time.get_ticks_msec()+limit
	while _outcome.is_empty() and Time.get_ticks_msec()<deadline:
		if _failure_latched:return false
		await get_tree().physics_frame
	if _outcome.is_empty():_fail("Kite route did not naturally finish before its original finite guard");return false
	await _frames(3)
	return true

func _drive_edge_route(live:Control, first_offset:float=27.0, label:String="edge-route") -> bool:
	var deadline:=Time.get_ticks_msec()+45000
	var last_ring:=-1
	while _outcome.is_empty() and Time.get_ticks_msec()<deadline:
		if not is_instance_valid(live):_fail("Kite freed before natural finish");return false
		var state:Dictionary=live.kite_model.snapshot();var ring:=int(state.nextRing)
		if ring>=5:break
		var target:float=live.kite_model.RING_HEIGHT[ring]+(first_offset if ring==0 else 0.0)
		var aim:=clampf((float(state.height)-target)*0.06-float(state.vy)*0.012,-1.0,1.0)
		var point:Vector2=get_viewport().get_final_transform()*(live.presentation.get_global_transform_with_canvas()*Vector2(640,390-aim*235))
		var motion:=InputEventMouseMotion.new();motion.position=point;motion.global_position=point;motion.window_id=get_window().get_window_id()
		Input.parse_input_event(motion);Input.flush_buffered_events()
		if ring!=last_ring:
			if not main._capture("kite-%s-ring-%d.png"%[label,ring+1]):_fail("Capture actual Kite ring");return false
			last_ring=ring
		await get_tree().physics_frame
	if _outcome.is_empty():_fail("Pointer edge route exceeded45-second guard");return false
	return true
