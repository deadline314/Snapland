extends "res://game/tests/native_layout_review.gd"
## Main-backed scripted evidence. Source reuse is not new art or human play.
var _output := ""
var _tag := ""
var _expected_action := ""
var _seen: Dictionary = {}
var _events: Array = []
var _captures: Array = []
var _quarter := false
var _clock_start := 0

func _process(_delta: float) -> void:
 if is_instance_valid(main) and main.world != null and main.session == null:
  var world = main.world
  world.camera.size = 5.5
  world.camera.global_position = world.player.global_position + Vector3(0,5.5,8.5)
  world.camera.look_at(world.player.global_position + Vector3(0,1,0))

func _run() -> void:
 _clock_start = Time.get_ticks_msec()
 _output = OS.get_environment("SNAPLAND_ACTION_REVIEW_DIR")
 _quarter = OS.get_cmdline_user_args().has("--quarter")
 if not _output.is_absolute_path() or DisplayServer.get_name() == "headless" or not OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path():
  push_error("Action review requires a native display and absolute private output/save paths");get_tree().quit(2);return
 DirAccess.make_dir_recursive_absolute(_output)
 Engine.time_scale = 0.25 if _quarter else 1.0
 process_priority = 100
 progress = get_tree().root.get_node("Progress")
 progress.reset_progress();progress.intro_seen = true
 get_window().size = Vector2i(1280,720)
 main = _instantiate_main();get_tree().root.add_child(main)
 await _frames(8)
 main.world.player.position = Vector3(-2.6,0.4,-5.5)
 main.world.player.velocity = Vector3.ZERO
 await get_tree().create_timer(0.3).timeout
 var renderer = main.world.avatar_renderer
 renderer.garment_overlays.ready(renderer)
 for hair in ["windswept","bob","curly"]:
  var look = renderer.DEFAULT_APPEARANCE.duplicate();look.hair = hair
  for index in 8: renderer.texture(look,{"outfit":"outfit-rainvest","hat":"hat-straw"},"front",index,"jump")
 RenderingServer.frame_post_draw.connect(_observe)
 if not _quarter:
  for pair in [["front",KEY_S],["back",KEY_W],["left",KEY_A],["right",KEY_D]]:
   var start: Vector3 = main.world.player.position
   for tick in 18:
    _held_key(int(pair[1]),true);await get_tree().physics_frame
   _held_key(int(pair[1]),false)
   if not await _wait_still():return
   if main.world.player.position.distance_to(start)<0.1 or main.world.facing!=pair[0]:await _fail("Cardinal input did not move in "+str(pair[0]));return
   await _capture("walk-"+str(pair[0]))
 for action in ["wave","photograph","interact"]:
  _tag = action;_expected_action = action
  if action == "wave":await _tap_key(KEY_F)
  elif action == "photograph":await _tap_key(KEY_P)
  else:main.world.play_action(action)
  if not await _wait_action():return
  if _seen.get(action,{}).size()!=8:await _fail("Action missed authored cels: %s seen=%s state=%s blocked=%s modal=%s"%[action,_seen,main.world.avatar_action,main.world.blocked,main.modal_kind]);return
 _tag = "celebrate-default";_expected_action = "celebrate"
 if not _quarter:
  main._launch_game("game-003",false)
  await _frames(3)
  if main.session==null:await _fail("Fountain entry did not start");return
  var sent_attempt := -1
  for tick in 1200:
   if main.session==null:break
   if bool(main.session.beat_window) and int(main.session.fountain_attempts)!=sent_attempt:
    sent_attempt=int(main.session.fountain_attempts);_key(KEY_SPACE)
   await get_tree().process_frame
  if main.modal_kind!="result" or not main.celebrate_on_close:await _fail("Real fountain inputs did not produce successful result");return
  await _capture("fountain-result")
 else:
  main._open("慶祝動作演練","來源與服飾檢視","result")
  main.celebrate_on_close = true
 var saved_before := FileAccess.get_file_as_bytes(OS.get_environment("SNAPLAND_SAVE_PATH"))
 if not _quarter and saved_before.is_empty():await _fail("Successful round did not leave a nonempty isolated save");return
 await _tap_key(KEY_ESCAPE)
 if main.world.avatar_action!="celebrate":await _fail("Result return did not route celebration event");return
 if not await _wait_action():return
 if _seen.get(_tag,{}).size()!=8:await _fail("Celebration did not show eight source cels");return
 for hair in ["bob","curly"]:
  var look = renderer.DEFAULT_APPEARANCE.duplicate();look.hair = hair
  main.world.set_avatar_look(look,{"outfit":"outfit-rainvest","hat":"hat-straw"})
  _tag = "celebrate-"+hair
  main.world.play_action("celebrate")
  if not await _wait_action():return
  if _seen.get(_tag,{}).size()!=8:await _fail("Outfit celebration missed source cels");return
 main.world.reduced_motion = true
 _tag = "celebrate-reduced"
 main.world.play_action("celebrate")
 if not await _wait_action():return
 if _seen.get(_tag,{}).keys()!=[0]:await _fail("Reduced motion did not hold the standing source");return
 if FileAccess.get_file_as_bytes(OS.get_environment("SNAPLAND_SAVE_PATH"))!=saved_before:await _fail("Visual action replay changed awarded save bytes");return
 var file=FileAccess.open(_output.path_join("review.json"),FileAccess.WRITE)
 file.store_string(JSON.stringify({"result":"PASS_NATIVE_ACTION_EVENTS","engine":Engine.get_version_info().string,"time_scale":Engine.time_scale,"rendered_size":get_viewport().get_texture().get_size(),"seen":_seen,"events":_events,"captures":_captures,"wall_ms":Time.get_ticks_msec()-_clock_start,"fountain_round":"scripted real inputs and native result return" if not _quarter else "synthetic result return for slow source inspection","scope":"Main-backed input/source/wardrobe evidence; camera and initial placement are fixtures. No new source art, human play or listening acceptance."},"\t"));file.close()
 print("PASS_NATIVE_ACTION_EVENTS scale=",Engine.time_scale," cases=",_seen.size())
 RenderingServer.frame_post_draw.disconnect(_observe)
 await main._quit_game()

func _wait_action() -> bool:
 for tick in ceili(300.0/Engine.time_scale):
  await get_tree().process_frame
  if main.world.avatar_action.is_empty():return true
 await _fail("Action did not end within finite frame budget");return false

func _wait_still() -> bool:
 for tick in ceili(90.0/Engine.time_scale):
  await get_tree().physics_frame
  if not main.world.avatar_is_walking and Vector2(main.world.player.velocity.x,main.world.player.velocity.z).length()<=0.001:
   await get_tree().process_frame
   return true
 await _fail("Movement did not naturally decelerate before gesture");return false

func _observe() -> void:
 if _tag.is_empty() or main.session!=null:return
 var world=main.world
 if world.last_avatar_action!=_expected_action:return
 var index:int=world.last_avatar_frame
 if not _seen.has(_tag):_seen[_tag]={}
 if _seen[_tag].has(index):return
 var source=world.avatar.texture.get_image()
 var expected: Image=world.avatar_renderer.texture(world.avatar_appearance,world.avatar_equipped,world.last_avatar_direction,index,world.last_avatar_source_action).get_image()
 if source.get_data()!=expected.get_data():push_error("Body and accessories disagree with source cel: "+_tag);return
 var filename="%s-%02d"%[_tag,index]
 if source.save_png(_output.path_join(filename+"-sprite.png"))!=OK:push_error("Cannot save source pose");return
 _seen[_tag][index]=true
 _events.append({"case":_tag,"semantic":world.last_avatar_action,"source":world.last_avatar_source_action,"frame":index,"elapsed":world.avatar_action_elapsed,"remaining":world.avatar_action_remaining,"model_time":world.time,"movie_frame":Engine.get_frames_drawn()})
 if index in [0,3,7]:
  if get_viewport().get_texture().get_image().save_png(_output.path_join(filename+".png"))==OK:_captures.append(filename+".png")

func _capture(label: String) -> void:
 await RenderingServer.frame_post_draw
 if get_viewport().get_texture().get_image().save_png(_output.path_join(label+".png"))!=OK:push_error("Cannot save review frame")

func _tap_key(code: int) -> void:
 _press_event(code,true)
 await get_tree().process_frame
 _press_event(code,false)
 await get_tree().process_frame

func _key(code: int) -> void:
 _press_event(code,true);_press_event(code,false)

func _press_event(code: int, pressed: bool) -> void:
 var event=InputEventKey.new()
 event.keycode=code;event.physical_keycode=code;event.pressed=pressed
 event.window_id=get_window().get_window_id()
 Input.parse_input_event(event);Input.flush_buffered_events()
