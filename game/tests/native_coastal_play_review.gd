extends SceneTree
const MAIN_SCENE_PATH="res://game/main.tscn"
var main: Node
var play: Node3D
var out: String
var failures: Array[String]=[]
var _deadline := 0
func _process(_delta: float) -> bool:
 if _deadline>0 and Time.get_ticks_msec()>_deadline:
  push_error("Native coastal play review exceeded its bounded 110-second deadline")
  quit(1)
 return false
func _initialize() -> void:
 var save:=OS.get_environment("SNAPLAND_SAVE_PATH")
 if not save.is_absolute_path() or DisplayServer.get_name()=="headless":push_error("Native free play requires a rendered window and absolute isolated save");quit(1);return
 out=save.get_base_dir();DirAccess.make_dir_recursive_absolute(out);call_deferred("_run")
 _deadline=Time.get_ticks_msec()+110000
func _run() -> void:
 root.size=Vector2i(1280,720)
 var progress=root.get_node("Progress");progress.reset_progress();progress.intro_seen=true;progress.save_progress()
 main=load(MAIN_SCENE_PATH).instantiate();root.add_child(main);await _frames(8);play=main.world.coastal_play
 var before:=FileAccess.get_file_as_string(OS.get_environment("SNAPLAND_SAVE_PATH"))
 await _place(play.ball.global_position+Vector3(0,0,1.0),"play:ball")
 await _capture("ball-before")
 var start: Vector3=play.ball.global_position
 await _key(KEY_E);await _frames(8)
 _check(play.ball.position.z<start.z-0.1,"native E kicks away from player")
 await _capture("ball-kicked")
 await _key(KEY_ESCAPE);await _frames(2)
 _check(main.modal_kind=="pause" and play.ball.freeze,"actual pause freezes toy")
 var paused: Vector3=play.ball.position;await _frames(8)
 _check(play.ball.position.distance_to(paused)<0.001,"pause holds physical position")
 await _key(KEY_ESCAPE);await _frames(3)
 await _place(Vector3(-21.4,0.3,8.0),"play:recall")
 await _key(KEY_E);await _frames(3)
 _check(play.ball.position.distance_to(Vector3(-24,0.7,5.1))<0.3,"native recall returns ball")
 # Walk around the ball to change the direction of the next kick.
 await _place(play.ball.global_position+Vector3(1,0,0),"play:ball")
 start=play.ball.position
 await _key(KEY_E);await _frames(8)
 _check(play.ball.position.x<start.x-0.1,"second side changes the physical kick direction")
 await _capture("ball-side-kick")
 await _place(Vector3(-29,0.3,-20),"coast:storm-bell")
 await _capture("bell-before")
 for hit in 4:
  await _key(KEY_E);await _frames(12)
 _check(play.bell_hits==4 and main.modal_kind=="" and main.session==null,"four native strikes stay in exploration")
 await _capture("bell-played")
 # Physical world time fixture, rather than claiming the time-panel UI was tested.
 progress.settings.time_phase="night";main._refresh();await _frames(5)
 await _place(Vector3(28,0.3,-20),"coast:tide-wheel")
 await _capture("wheel-night-open")
 await _key(KEY_E);await _frames(8)
 _check(not play.valve_open and not play.streams[0].visible,"native gate closes its flow")
 var stopped: float=play.rotor.rotation.z
 await _frames(5);_check(is_equal_approx(stopped,play.rotor.rotation.z),"native closed rotor remains stopped")
 await _capture("wheel-night-closed")
 await _key(KEY_E);await _frames(8)
 _check(play.valve_open and not is_equal_approx(stopped,play.rotor.rotation.z),"native reopen restores rotation")
 progress.settings.reduced_motion=true;main._refresh();await _frames(5)
 stopped=play.rotor.rotation.z;await _frames(8)
 _check(is_equal_approx(stopped,play.rotor.rotation.z) and play.streams[0].visible,"native reduced motion keeps essential flow state")
 await _capture("wheel-reduced-open")
 await _review_discoveries()
 _check(before==FileAccess.get_file_as_string(OS.get_environment("SNAPLAND_SAVE_PATH")),"native free play does not write any progress")
 var report={"failures":failures,"bell_hits":play.bell_hits,"flow_open":play.valve_open,"scope":"actual Main, real E/Escape input, fixture relocation between sites, direction and flow checks; no reward or human audio listening claimed","window":var_to_str(root.size),"viewport":var_to_str(root.get_visible_rect().size)}
 var file=FileAccess.open(out.path_join("report.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "))
 main.audio.shutdown();main.queue_free();await _frames(4)
 if failures.is_empty():print("PASS: native coastal free play direction, bell, gate, pause and reduced motion");quit(0)
 else:push_error(str(failures));quit(1)
func _place(p: Vector3,id: String) -> void:
 main.world.player.position=p
 for i in 60:
  await physics_frame
  if str(main.world.nearest.get("id",""))==id:return
 _check(false,"could not select "+id+" got "+str(main.world.nearest.get("id","")))
func _review_discoveries() -> void:
 var discovery: Node3D=play.discoveries
 await _place(Vector3(-27,0.3,-45),"coast:lighthouse")
 await _capture("lighthouse-before")
 await _key(KEY_E)
 _check(discovery.controlling and main.modal_kind=="","native E starts world optics")
 var start: Vector3=main.world.player.position
 await _hold(KEY_D,54)
 _check(discovery.receiver_active==1,"native held direction finds the middle reflector")
 _check(Vector2(main.world.player.position.x-start.x,main.world.player.position.z-start.z).length()<0.02,"held lens direction does not move the player")
 await _capture("lighthouse-keyboard-center")
 await _drag(Vector2(700,340),Vector2(844,340))
 _check(discovery.receiver_active==2,"native mouse drag steers the same lens to the third reflector")
 await _capture("lighthouse-mouse-right")
 await _key(KEY_ESCAPE)
 _check(not discovery.controlling and main.modal_kind=="","first Escape releases optics without opening pause")
 await _key(KEY_ESCAPE)
 _check(main.modal_kind=="pause","second Escape still opens the normal pause")
 var held: float=discovery.lens_angle
 await _hold(KEY_A,5)
 _check(is_equal_approx(held,discovery.lens_angle),"pause does not leak directional input to the lens")
 await _key(KEY_ESCAPE)
 await _key(KEY_E)
 _check(discovery.controlling,"native re-entry works after pause")
 await _click(main.context_action.get_global_rect().get_center())
 _check(not discovery.controlling,"actual context button releases the same control mode")
 await _hold(KEY_D,8)
 _check(main.world.player.position.x>start.x+0.05,"ordinary movement returns after leaving optics")
 await _place(Vector3(27,0.3,-52),"coast:glass-garden")
 await _capture("garden-before")
 await _click(main.context_action.get_global_rect().get_center())
 _check(discovery.garden_open,"actual context button opens garden irrigation")
 await _frames(190)
 _check(is_equal_approx(discovery.garden_growth,1.0),"native watering completes four blooms")
 await _capture("garden-watered-reduced")
 await _key(KEY_E)
 _check(not discovery.garden_open and not discovery.droplets[0].visible,"native E closes watering")
 await _capture("garden-blooms-retained")
 _check(main.modal_kind=="" and main.session==null,"all new discoveries remain in free exploration")
func _hold(code: Key,count: int) -> void:
 var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=true;event.window_id=root.get_window_id()
 Input.parse_input_event(event);Input.flush_buffered_events();await _frames(count)
 event=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=false;event.window_id=root.get_window_id()
 Input.parse_input_event(event);Input.flush_buffered_events();await _frames(1)
func _click(position: Vector2) -> void:
 for down in [true,false]:
  var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.position=position;event.global_position=position;event.pressed=down;event.window_id=root.get_window_id()
  Input.parse_input_event(event);Input.flush_buffered_events();await _frames(2)
func _drag(start: Vector2,finish: Vector2) -> void:
 var button:=InputEventMouseButton.new();button.button_index=MOUSE_BUTTON_LEFT;button.position=start;button.global_position=start;button.pressed=true;button.window_id=root.get_window_id()
 Input.parse_input_event(button);Input.flush_buffered_events();await _frames(1)
 var move:=InputEventMouseMotion.new();move.position=finish;move.global_position=finish;move.relative=finish-start;move.button_mask=MOUSE_BUTTON_MASK_LEFT;move.window_id=root.get_window_id()
 Input.parse_input_event(move);Input.flush_buffered_events();await _frames(2)
 button=InputEventMouseButton.new();button.button_index=MOUSE_BUTTON_LEFT;button.position=finish;button.global_position=finish;button.pressed=false;button.window_id=root.get_window_id()
 Input.parse_input_event(button);Input.flush_buffered_events();await _frames(1)
func _key(code: Key) -> void:
 # Wait for the existing real toy cooldown; frame counts alone change duration
 # between 20 and 60 FPS capture. Do not drop the second kick at the input gate.
 if code == KEY_E and is_instance_valid(play):
  for frame in 30:
   if play._cooldown <= 0.0 and play.discoveries._cooldown <= 0.0: break
   await _frames(1)
 for down in [true,false]:
  var event=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=down;event.window_id=root.get_window_id()
  Input.parse_input_event(event);Input.flush_buffered_events();await _frames(2)
func _capture(name: String) -> void:
 await RenderingServer.frame_post_draw
 _check(root.get_texture().get_image().save_png(out.path_join(name+".png"))==OK,"capture "+name)
func _frames(count: int) -> void:
 for i in count:await process_frame
func _check(ok: bool,message: String) -> void:
 if not ok:failures.append(message);push_error(message)
