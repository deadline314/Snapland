extends SceneTree
const Paper=preload("res://game/ui/paper_ui.gd")
var main: Node
var out: String
var failures: Array[String]=[]
var cases: Array[Dictionary]=[]
var deadline := 0
func _process(_delta: float) -> bool:
 if deadline>0 and Time.get_ticks_msec()>deadline:push_error("Native HUD review exceeded 100 seconds");quit(1)
 return false
func _initialize() -> void:
 var save:=OS.get_environment("SNAPLAND_SAVE_PATH")
 if not save.is_absolute_path() or DisplayServer.get_name()=="headless":push_error("Native HUD review requires a window and absolute isolated save");quit(1);return
 out=save.get_base_dir();DirAccess.make_dir_recursive_absolute(out);deadline=Time.get_ticks_msec()+100000;call_deferred("_run")
func _run() -> void:
 var progress=root.get_node("Progress");progress.reset_progress();progress.intro_seen=true;progress.settings.ui_scale=1.25;progress.save_progress()
 main=load("res://game/main.tscn").instantiate();root.add_child(main);await _frames(6)
 for dimensions in [Vector2i(800,450),Vector2i(1280,720),Vector2i(1920,1080)]:
  root.size=dimensions;await _frames(5)
  progress.settings.time_phase="night" if dimensions.x==1280 else "noon";main._refresh()
  await _place(Vector3(-29,0.3,-20),"coast:storm-bell")
  await _frames(3)
  var strip: Control=main.hud.get_node("ParkKeepsakeBanner")
  var scale_factor:=Paper.physical_scale(strip)
  _check(not strip.find_child("ParkCollectionDetails",true,false).visible,"totals are not permanent HUD text")
  _check(strip.size.y*scale_factor<74,"location strip remains one compact row")
  _check(main.context_action.text=="E   敲潮鐘","context names the real nearby action")
  for control: Control in [strip,main.context_bar,main.ticket_button]:_check(root.get_visible_rect().encloses(control.get_global_rect()),"HUD in bounds "+str(control.name))
  var visible_signs:=0
  for sign in main.world.local_sign_labels:
   var d: Vector2=Vector2(sign.global_position.x-main.world.player.position.x,sign.global_position.z-main.world.player.position.z)
   if sign.visible:visible_signs+=1
   _check(sign.visible==(d.length_squared()<=100.0),"only local sign text is displayed")
  _check(visible_signs>0 and visible_signs<main.world.local_sign_labels.size()/2,"distant gate labels do not clutter this part of the coast")
  await _capture("%d-exploration"%dimensions.x)
  var hits: int=main.world.coastal_play.bell_hits
  await _key(KEY_E)
  _check(main.world.coastal_play.bell_hits==hits+1 and main.modal_kind=="","compact prompt still activates the bell")
  await _key(KEY_M);_check(main.modal_kind=="ticket","M still opens full travel tools")
  await _capture("%d-ticket"%dimensions.x)
  await _key(KEY_ESCAPE)
  await _place(main.world._point_by_id("guide").position+Vector3(0,0.2,0),"guide")
  await _key(KEY_E)
  _check(main.modal_kind=="dialogue" and not main.hud.visible,"dialogue hides unrelated park HUD")
  await _capture("%d-dialogue"%dimensions.x)
  await _key(KEY_ESCAPE)
  _check(main.modal_kind=="" and main.hud.visible,"closing dialogue restores exploration")
  await _place(main.world._point_by_id("game-001").position+Vector3(0,0.2,0),"game-001")
  await _key(KEY_E)
  _check(main.modal_kind=="game_info" and not main.hud.visible,"invite has one layer of relevant information")
  await _capture("%d-invite"%dimensions.x)
  await _key(KEY_ESCAPE)
  _check(main.hud.visible and not main.world.blocked,"invite return restores park controls")
  cases.append({"requested":var_to_str(dimensions),"window":var_to_str(root.size),"viewport":var_to_str(root.get_visible_rect().size),"text_scale":Paper.text_scale(),"strip_physical_height":strip.size.y*scale_factor,"near_signs":visible_signs,"total_local_signs":main.world.local_sign_labels.size()})
 var file=FileAccess.open(out.path_join("report.json"),FileAccess.WRITE);file.store_string(JSON.stringify({"cases":cases,"failures":failures,"scope":"native E/M/Escape input; fixture relocation and phase selection, no free walk or full minigame quality claimed"},"  "))
 main.audio.shutdown();main.queue_free();await _frames(4)
 if failures.is_empty():print("PASS: native light park HUD at three sizes, 1.25 text, local signs, ticket, dialogue and invite");quit(0)
 else:push_error(str(failures));quit(1)
func _place(p: Vector3,id: String) -> void:
 main.world.player.position=p
 for i in 40:
  await physics_frame
  if str(main.world.nearest.get("id",""))==id:return
 _check(false,"could not select "+id)
func _frames(count: int) -> void:
 for i in count:await process_frame
func _key(code: Key) -> void:
 for down in [true,false]:
  var event=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=down;event.window_id=root.get_window_id();Input.parse_input_event(event);Input.flush_buffered_events();await _frames(2)
func _capture(name: String) -> void:
 await RenderingServer.frame_post_draw
 _check(root.get_texture().get_image().save_png(out.path_join(name+".png"))==OK,"capture "+name)
func _check(ok: bool,message: String) -> void:
 if not ok:failures.append(message);push_error(message)
