extends SceneTree
const Paper = preload("res://game/ui/paper_ui.gd")
var main: Node
var progress: Node
var failures: Array[String] = []
var out: String
var returning := false
var checked: Array[String] = []
func _initialize() -> void:
 out=OS.get_environment("SNAPLAND_SAVE_PATH").get_base_dir()
 returning=OS.get_cmdline_user_args().has("--returning")
 if not out.is_absolute_path() or DisplayServer.get_name()=="headless":
  push_error("Native entry needs a rendered window and isolated absolute profile");quit(1);return
 call_deferred("_run")
func _run() -> void:
 root.size=Vector2i(800,450) if returning else Vector2i(1280,720)
 progress=root.get_node("Progress")
 if not returning:
  progress.reset_progress()
  progress.intro_seen=false
 else:
  _check(progress.tutorial_seen_games.size()==12,"new process loaded all twelve learned tutorials")
  progress.settings.reduced_motion=true
  progress.settings.ui_scale=1.25
  progress.settings.time_phase="night"
 progress.save_progress()
 main=load("res://game/main.tscn").instantiate()
 root.add_child(main)
 await _frames(8)
 if not returning:
  _check(main.modal_kind=="dialogue","fresh profile opens arrival")
  await _key(KEY_ESCAPE)
 var original: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("SNAPLAND_SAVE_PATH")))
 for number in range(1,13):
  var id="game-%03d"%number
  await _review(id,number)
  if not failures.is_empty():break
 if returning:
  var final: Variant=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("SNAPLAND_SAVE_PATH")))
  _check(original==final,"returning entry/cancel preserves the complete saved payload")
 _check(checked.size()==12,"all twelve entry paths completed")
 var report={"returning":returning,"checked":checked,"failures":failures,"physical_window":var_to_str(root.size),"viewport":var_to_str(root.get_visible_rect().size),"text_scale":Paper.text_scale(),"scope":"actual Main and real window key/mouse events; fixture positions between stations; no wins or complete-game quality claimed"}
 var file=FileAccess.open(out.path_join("returning.json" if returning else "new.json"),FileAccess.WRITE)
 file.store_string(JSON.stringify(report,"  "))
 main.audio.shutdown();main.queue_free();await _frames(3)
 if failures.is_empty():print("PASS: native twelve-station ","returning" if returning else "new"," entry/assist/tutorial/cancel");quit(0)
 else:push_error(str(failures));quit(1)
func _review(id: String,number: int) -> void:
 var station: Dictionary={}
 for point in main.world.points:
  if str(point.id)==id:station=point;break
 _check(not station.is_empty(),id+" exists")
 if station.is_empty():return
 main.world.player.position=station.position+Vector3(0,0.3,0)
 await _until(func():return str(main.world.nearest.get("id",""))==id,id+" nearest")
 var position_before: Vector3=main.world.player.position
 await _key(KEY_E)
 _check(main.modal_kind=="game_info",id+" E opens invite")
 _check(not main.hud.visible,id+" invite hides duplicate park HUD")
 var invite: Control=main.overlay.find_child("IslandGameInvite",true,false)
 if invite==null:_check(false,id+" invite missing");return
 await _frames(3)
 _check(invite.find_children("*","Button",true,false).size()==3,id+" only three invite actions")
 for name in ["InviteStart","InviteRules","InviteBack","InviteTitle","InviteLine"]:
  var control: Control=invite.find_child(name,true,false)
  _check(control!=null and root.get_visible_rect().encloses(control.get_global_rect()),id+" visible "+name)
 await _capture(id+"-invite")
 # Cancel once using the actual return action, then re-enter from the island.
 await _click(invite.find_child("InviteBack",true,false))
 _check(main.modal_kind=="" and not main.world.blocked,id+" invite returns to park")
 await _key(KEY_E)
 invite=main.overlay.find_child("IslandGameInvite",true,false)
 if not returning:
  # Odd-numbered games use optional assisted entry, even ones the primary Start.
  if number%2==1:
   await _click(invite.find_child("InviteRules",true,false))
   _check(main.modal_kind=="game_rules",id+" optional rules")
   await _click(_button(main.overlay,"輔助挑戰"))
  else:
   await _click(invite.find_child("InviteStart",true,false))
  await _until(func():return is_instance_valid(main.tutorial_panel),id+" first entry offers lesson")
  if not is_instance_valid(main.tutorial_panel):return
  _check(main.session==null and main.tutorial_assist==(number%2==1),id+" lesson retains chosen assistance without starting clock")
  await _key(KEY_D)
  _check(main.world.player.position.distance_to(position_before)<0.2,id+" tutorial blocks movement")
  if number in [1,2]:await _capture(id+"-first-tutorial")
  await _click(_button(main.tutorial_panel,"關閉"))
  _check(not progress.has_seen_tutorial(id) and main.session==null,id+" cancel leaves lesson unseen")
  if number%2==1:
   await _click(_button(main.overlay,"輔助挑戰"))
  else:
   await _click(main.overlay.find_child("InviteStart",true,false))
  await _until(func():return is_instance_valid(main.tutorial_panel),id+" second lesson")
  if not is_instance_valid(main.tutorial_panel):return
  await _click(_button(main.tutorial_panel,"略過"))
 else:
  await _click(invite.find_child("InviteStart",true,false))
 await _until(func():return is_instance_valid(main.session),id+" session starts")
 if not is_instance_valid(main.session):return
 _check(not is_instance_valid(main.tutorial_panel),id+" session has no lesson overlay")
 _check(main.session.game_id==id,id+" correct session")
 if not returning:_check(main.session.assisted==(number%2==1),id+" assistance preserved")
 if number in [1,2,12]:await _capture(id+"-session")
 var hud: Node=main.session.minigame_hud
 await _click(hud.find_child("PauseButton",true,false))
 await _click(hud.find_child("LeaveButton",true,false))
 await _click(hud.find_child("ConfirmAction",true,false))
 await _until(func():return main.session==null,id+" confirmed leave")
 _check(main.modal_kind=="" and main.world.visible and not main.world.blocked,id+" resumes park")
 _check(progress.photos.is_empty() and progress.achievements.is_empty() and progress.coins==120,id+" cancel awards nothing")
 checked.append(id)
 print("PASS: entry ",id," returning=",returning)
func _button(node: Node,text: String) -> Button:
 if node==null:return null
 for button in node.find_children("*","Button",true,false):
  if button.text==text and button.is_visible_in_tree():return button
 return null
func _click(button: Control) -> void:
 if button==null:_check(false,"missing click target");return
 await _frames(2)
 var point: Vector2=button.get_viewport().get_final_transform()*button.get_global_rect().get_center()
 var motion=InputEventMouseMotion.new();motion.position=point;motion.global_position=point;motion.window_id=root.get_window_id()
 Input.parse_input_event(motion);Input.flush_buffered_events();await _frames(1)
 _check(button.is_hovered(),"pointer reaches "+str(button.name))
 for down in [true,false]:
  var event=InputEventMouseButton.new();event.position=point;event.global_position=point;event.window_id=root.get_window_id();event.button_index=MOUSE_BUTTON_LEFT;event.button_mask=MOUSE_BUTTON_MASK_LEFT if down else 0;event.pressed=down
  Input.parse_input_event(event);Input.flush_buffered_events();await _frames(1)
 await _frames(2)
func _key(code: Key) -> void:
 for down in [true,false]:
  var event=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=down;event.window_id=root.get_window_id()
  Input.parse_input_event(event);Input.flush_buffered_events();await _frames(1)
func _frames(count: int) -> void:
 for i in count:await process_frame
func _until(predicate: Callable,context: String) -> void:
 for i in 90:
  if predicate.call():return
  await process_frame
 _check(false,"timeout "+context)
func _capture(name: String) -> void:
 await RenderingServer.frame_post_draw
 _check(root.get_texture().get_image().save_png(out.path_join(("return-" if returning else "new-")+name+".png"))==OK,"capture "+name)
func _check(ok: bool,message: String) -> void:
 if not ok:failures.append(message);push_error(message)
