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
  await _key(KEY_E);await _frames(5)
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
func _key(code: Key) -> void:
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
