extends SceneTree
var main: Node
var world: Node3D
var out: String
var failures: Array[String]=[]
var distance:=0.0
var deadline:=0
func _process(_delta: float) -> bool:
 if deadline>0 and Time.get_ticks_msec()>deadline:push_error("Ride native review exceeded 150 seconds");quit(1)
 return false
func _initialize() -> void:
 var save:=OS.get_environment("SNAPLAND_SAVE_PATH")
 if not save.is_absolute_path() or DisplayServer.get_name()=="headless":push_error("Ride review needs an isolated absolute save and a rendered window");quit(1);return
 out=save.get_base_dir();DirAccess.make_dir_recursive_absolute(out);deadline=Time.get_ticks_msec()+150000;call_deferred("_run")
func _run() -> void:
 root.size=Vector2i(1280,720)
 var progress=root.get_node("Progress");progress.reset_progress();progress.intro_seen=true;progress.save_progress()
 main=load("res://game/main.tscn").instantiate();root.add_child(main);await _frames(8);world=main.world
 var before:=FileAccess.get_file_as_string(OS.get_environment("SNAPLAND_SAVE_PATH"))
 for stop in [Vector2(0,15),Vector2(0,11.2),Vector2(-4.2,11.2),Vector2(-6.7,11.2)]:
  if not await _walk(stop):break
 for action in ["move_left","move_right","move_up","move_down"]:Input.action_release(action)
 await _frames(4)
 _check(str(world.nearest.get("id",""))=="ride-tide","walk from dock naturally reaches the ride")
 await _capture("approach-day")
 for phase in ["noon","night"]:
  progress.settings.time_phase=phase;main._refresh();await _frames(6)
  if phase=="night":
   _check(world.island_attractions._ride_lights[0].light_energy>0.0 and world.island_attractions._ride_lights[1].light_energy>0.0,"both visible boardwalk lamps illuminate the nighttime ride")
  await _key(KEY_E);await _frames(2)
  _check(world.is_riding(),phase+" E boards the existing ride")
  _check(main.context_action.text=="E   下來走走",phase+" HUD names the actual exit")
  for checkpoint in 4:
   await _frames(20)
   _check(world.is_riding(),phase+" remains seated before natural finish")
   _check(world.camera.global_position.distance_to(world.player.global_position)>20,phase+" camera remains outside the ride")
   await _capture(phase+"-seat-%d"%checkpoint)
  # A little more than 12 simulated seconds completes the authored cycle.
  for i in 140:
   if not world.is_riding():break
   await process_frame
  _check(not world.is_riding(),phase+" complete ride returns to boarding position")
  _check(Vector2(world.player.position.x+6.7,world.player.position.z-11.2).length()<0.4,phase+" exit restores safe approach")
  await _capture(phase+"-return")
  await _key(KEY_E);await _frames(2);await _key(KEY_E)
  _check(not world.is_riding(),phase+" explicit E exit works on revisit")
 _check(before==FileAccess.get_file_as_string(OS.get_environment("SNAPLAND_SAVE_PATH")),"ride creates no rewards and leaves complete save bytes unchanged")
 var file=FileAccess.open(out.path_join("report.json"),FileAccess.WRITE);file.store_string(JSON.stringify({"distance_walked":distance,"failures":failures,"scope":"actual dock-to-ride movement and E boarding/exit; fixture time phase, no teleport; sampled views of full day/night rides"},"  "))
 main.audio.shutdown();main.queue_free();await _frames(4)
 if failures.is_empty():print("PASS: native dock-to-ride approach and complete day/night carousel with unchanged save");quit(0)
 else:push_error(str(failures));quit(1)
func _walk(target: Vector2) -> bool:
 for i in 1200:
  var previous:=Vector2(world.player.position.x,world.player.position.z);var delta:=target-previous
  if delta.length()<0.18:return true
  var direction:=delta.normalized()
  for pair in [["move_left",-direction.x],["move_right",direction.x],["move_up",-direction.y],["move_down",direction.y]]:
   if pair[1]>0.08:Input.action_press(pair[0],absf(pair[1]))
   else:Input.action_release(pair[0])
  await physics_frame;distance+=Vector2(world.player.position.x,world.player.position.z).distance_to(previous)
 _check(false,"walk blocked on approach to "+str(target));return false
func _key(code: Key) -> void:
 for down in [true,false]:
  var event=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=down;event.window_id=root.get_window_id();Input.parse_input_event(event);Input.flush_buffered_events();await _frames(2)
func _frames(count: int) -> void:
 for i in count:await process_frame
func _capture(name: String) -> void:
 await RenderingServer.frame_post_draw;_check(root.get_texture().get_image().save_png(out.path_join(name+".png"))==OK,"capture "+name)
func _check(ok: bool,message: String) -> void:
 if not ok:failures.append(message);push_error(message)
