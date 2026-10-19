extends SceneTree
var world: Node3D
var failures: Array[String]=[]
var distance:=0.0
var main: Node
var inspected: Array[String]=[]
func _initialize():
 if OS.get_environment("SNAPLAND_SAVE_PATH").strip_edges().is_empty() or DisplayServer.get_name()=="headless":
  push_error("Native coastal review requires an isolated SNAPLAND_SAVE_PATH and rendered window")
  quit(1)
  return
 call_deferred("_run")
func _run():
 root.size=Vector2i(800,450)
 var progress=root.get_node("Progress")
 progress.reset_progress()
 progress.intro_seen=true
 main=load("res://game/main.tscn").instantiate()
 root.add_child(main)
 for frame in 8: await process_frame
 world=main.world
 await physics_frame
 var stops=[Vector2(0,15),Vector2(-19,15),Vector2(-25,4),Vector2(-29,-8),Vector2(-28,-20),Vector2(-28,-27),Vector2(-27,-45),Vector2(-22,-60),Vector2(-9,-66),Vector2(0,-66),Vector2(12,-66),Vector2(26,-56),Vector2(27,-52),Vector2(29,-38),Vector2(28,-20),Vector2(26,-4),Vector2(21,6),Vector2(12,6),Vector2(12,7),Vector2(3,7),Vector2(3,10),Vector2(0,10),Vector2(0,23.2)]
 for stop in stops:
  if not await _walk(stop): break
  for action in ["move_left","move_right","move_up","move_down"]: Input.action_release(action)
  for frame in 3: await process_frame
  var nearest_id: String = str(world.nearest.get("id",""))
  if nearest_id.begins_with("coast:") and not inspected.has(nearest_id):
   var out=OS.get_environment("SNAPLAND_SAVE_PATH").get_base_dir()
   DirAccess.make_dir_recursive_absolute(out)
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png(out+"/"+nearest_id.trim_prefix("coast:")+".png")
   _key(KEY_E)
   for frame in 3: await process_frame
   if not world.coastal_play.prompt(nearest_id).is_empty():
    if main.modal_kind!="" or main.session!=null:
     failures.append("coastal free play unexpectedly opened a modal: "+nearest_id);break
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(out+"/"+nearest_id.trim_prefix("coast:")+"-action.png")
    inspected.append(nearest_id)
    continue
   if main.modal_kind!="dialogue" or main.dialogue.is_empty():
    failures.append("real E did not open coastal observation: "+nearest_id);break
   _key(KEY_E)
   for frame in 3: await process_frame
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png(out+"/"+nearest_id.trim_prefix("coast:")+"-dialogue.png")
   _key(KEY_E)
   for frame in 3: await process_frame
   if world.blocked:
    failures.append("observation did not resume walking: "+nearest_id);break
   inspected.append(nearest_id)
 for action in ["move_left","move_right","move_up","move_down"]: Input.action_release(action)
 if inspected.size()!=6: failures.append("expected all six actual E inspections, got "+str(inspected))
 var report={"inspected":inspected,"failures":failures,"distance":distance,"position":var_to_str(world.player.position),"scope":"real CharacterBody movement via Input actions, no mid-route teleport or collision reset"}
 var out=OS.get_environment("SNAPLAND_SAVE_PATH").get_base_dir()
 DirAccess.make_dir_recursive_absolute(out)
 var file=FileAccess.open(out+"/walk.json",FileAccess.WRITE)
 file.store_string(JSON.stringify(report,"  "))
 print("ROUTE REPORT ",report)
 main.audio.shutdown()
 main.queue_free()
 await process_frame
 if failures.is_empty(): print("PASS: native coastal walk and six keyboard observations"); quit(0)
 else: push_error(str(failures)); quit(1)
func _walk(target: Vector2)->bool:
 var initial=Vector2(world.player.position.x,world.player.position.z)
 var limit=int(initial.distance_to(target)/2.0*60.0)+240
 var stalled:=0
 for frame in limit:
  var here=Vector2(world.player.position.x,world.player.position.z)
  var diff=target-here
  if diff.length()<0.25:
   print("REACHED ",target," actual=",here)
   return true
  var direction=diff.normalized()
  for entry in [["move_left",-direction.x],["move_right",direction.x],["move_up",-direction.y],["move_down",direction.y]]:
   if entry[1]>0.08: Input.action_press(entry[0],absf(entry[1]))
   else: Input.action_release(entry[0])
  await physics_frame
  var moved=Vector2(world.player.position.x,world.player.position.z).distance_to(here)
  distance+=moved
  if moved<0.0001: stalled+=1
  else: stalled=0
  if stalled>100 or world.player.position.y < -0.1:
   failures.append("stalled/fell target=%s actual=%s" % [target,world.player.position]);return false
 failures.append("bounded walk did not reach %s actual=%s"%[target,world.player.position]);return false

func _key(code: int)->void:
 for pressed in [true,false]:
  var event=InputEventKey.new()
  event.keycode=code
  event.physical_keycode=code
  event.pressed=pressed
  event.window_id=root.get_window_id()
  Input.parse_input_event(event)
  Input.flush_buffered_events()
