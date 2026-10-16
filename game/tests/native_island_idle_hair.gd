extends "res://game/tests/native_walk_review.gd"
var evidence_dir := ""
var cases: Array=[]
func _run() -> void:
 evidence_dir=OS.get_environment("SNAPLAND_ISLAND_AVATAR_DIR")
 if not evidence_dir.is_absolute_path() or DisplayServer.get_name()=="headless":get_tree().quit(2);return
 Engine.time_scale=0.25 if OS.get_environment("SNAPLAND_ISLAND_AVATAR_QUARTER")=="1" else 1.0
 progress=get_tree().root.get_node_or_null("Progress");progress.reset_progress();progress.intro_seen=true
 main=_instantiate_main();get_tree().root.add_child(main);await _frames(8)
 main.world.camera.size=8.5
 for fixture in [["front",[KEY_S]],["front_right",[KEY_S,KEY_D]],["right",[KEY_D]],["back_right",[KEY_W,KEY_D]],["back",[KEY_W]],["back_left",[KEY_W,KEY_A]],["left",[KEY_A]],["front_left",[KEY_S,KEY_A]]]:
  for key in [KEY_W,KEY_A,KEY_S,KEY_D]:_held_key(key,false)
  main.world.player.position=Vector3(-4,0.4,-6);main.world.player.velocity=Vector3.ZERO
  await get_tree().create_timer(0.15).timeout
  for _tick in range(roundi(14.0/Engine.time_scale)):
   for key in [KEY_W,KEY_A,KEY_S,KEY_D]:_held_key(key,fixture[1].has(key))
   await get_tree().physics_frame
  for key in [KEY_W,KEY_A,KEY_S,KEY_D]:_held_key(key,false)
  await get_tree().create_timer(0.2).timeout
  if main.world.facing!=fixture[0] or main.world.avatar_is_walking:await _fail("native stop heading differs");return
  main.world.time=0.0 if fixture[0]=="front" else 1.7;main.world.last_avatar_frame=-1;main.world._refresh_avatar_texture(0)
  await _capture(fixture[0]+"-open")
  var spec: Dictionary=main.world.avatar_renderer._stable_idle_pixels.manifest["hero-idle/"+fixture[0]]
  var target=int(spec.blink_frame) if int(spec.blink_frame)>=0 else 2
  var deadline=main.world.time+3.8
  while main.world.last_avatar_frame!=target and main.world.time<deadline:await get_tree().process_frame
  if main.world.last_avatar_frame!=target:await _fail("idle did not reach authored blink/breath frame");return
  await _capture(fixture[0]+"-blink")
  cases.append({"direction":fixture[0],"frame":main.world.last_avatar_frame,"expected":target,"eye_visible":not spec.eye_regions.is_empty()})
  if fixture[0]=="front":
   _held_key(KEY_ESCAPE,true);await _frames(1);_held_key(KEY_ESCAPE,false);await _frames(3)
   var time_before: float=main.world.time
   var texture_before=main.world.avatar.texture
   if not main.world.blocked:await _fail("native pause not entered");return
   await _frames(8)
   if main.world.time!=time_before or main.world.avatar.texture!=texture_before:await _fail("pause advances idle");return
   _held_key(KEY_ESCAPE,true);await _frames(1);_held_key(KEY_ESCAPE,false);await _frames(3)
   if main.world.blocked:await _fail("native pause did not resume");return
  await get_tree().create_timer(0.3).timeout
 var file=FileAccess.open(evidence_dir.path_join("audit.json"),FileAccess.WRITE)
 file.store_string(JSON.stringify({"result":"PASS_NATIVE_ISLAND_IDLE","scale":Engine.time_scale,"cases":cases,"pause_resume":true,"scope":"Actual island native heading input, stop, authored idle/blink and native pause. Placement, clock reset and camera are explicit review fixtures."},"  "));file.close()
 print("PASS native island idle eight directions and native pause at ",Engine.time_scale)
 await main._quit_game()
func _capture(label: String) -> void:
 await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png(evidence_dir.path_join(label+".png"))
 main.world.avatar.texture.get_image().save_png(evidence_dir.path_join(label+"-pixels.png"))
