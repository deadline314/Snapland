extends Node
const MAIN_SCENE_PATH = 'res://game/main.tscn'
const GAME_SESSION = preload('res://game/minigames/session.gd')
## Godot consumes --fixed-fps before exposing OS.get_cmdline_args(). Drivers
## using that engine option must also pass -- --review-fixed-clock. This only
## selects bounded wall-clock hang guards; it never changes gameplay timing.
func _uses_fixed_review_clock() -> bool:
 return not Engine.get_write_movie_path().is_empty() or OS.get_cmdline_user_args().has("--review-fixed-clock")

var main: Node
var progress: Node
func _ready() -> void:
 call_deferred('_run')
func _run() -> void:
 if OS.get_environment('SNAPLAND_SAVE_PATH').is_empty() or DisplayServer.get_name()=='headless':
  push_error('Native review requires GPU and isolated SNAPLAND_SAVE_PATH');get_tree().quit(1);return
 progress=get_tree().root.get_node_or_null('Progress')
 if progress==null: push_error('Progress autoload is missing');get_tree().quit(1);return
 progress.reset_progress()
 progress.intro_seen=true
 main=_instantiate_main()
 if main==null: get_tree().quit(1);return
 get_tree().root.add_child(main)
 await get_tree().create_timer(1.5).timeout
 print('WORLD METRICS: meshes=', main.world.mesh_count, ' materials=', main.world.material_cache.size(), ' nodes=', Performance.get_monitor(Performance.OBJECT_NODE_COUNT), ' fps=', Performance.get_monitor(Performance.TIME_FPS), ' draw_calls=', RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME), ' static_memory=', Performance.get_monitor(Performance.MEMORY_STATIC))
 if not await _review_world(): return
 if OS.get_cmdline_user_args().has('--review-world-only'):
  await main._quit_game();return
 for number in range(1,13):
  var id='game-%03d'%number
  for point in main.world.points:
   if point.id==id: main.world.player.position=point.position+Vector3(0,0.3,0)
  var deadline=Time.get_ticks_msec()+2000
  while main.world.nearest.get('id','')!=id and Time.get_ticks_msec()<deadline: await get_tree().physics_frame
  _key(KEY_E)
  await get_tree().create_timer(0.1).timeout
  _button('開始遊玩')
  await get_tree().process_frame
  if main.session==null: await _fail('Station did not launch '+id);return
  await get_tree().create_timer(0.25).timeout
  await RenderingServer.frame_post_draw
  if not main._capture('pm/Snapland-art/images/ART-5-game-%02d.png'%number): await _fail('Failed gameplay evidence '+id);return
  if number==12:
   for prop in GAME_SESSION.REQUIRED_PROP_KEYS: main.session._prop_texture(prop)
   if not main.session.art_assets_ready(): await _fail('Runtime art cache '+str(main.session.art_cache_status()));return
   print('PASS: rendered art assets, four backdrops and sixteen prop regions')
  var waypoint=0
  var last_cycle=-1
  var puzzle_done=false
  var pipe_order_played=-1
  var rhythm=[KEY_LEFT,KEY_RIGHT,KEY_SPACE,KEY_RIGHT,KEY_LEFT,KEY_SPACE,KEY_LEFT,KEY_RIGHT]
  var waypoints=[Vector2(520,305),Vector2(780,270),Vector2(880,270),Vector2(960,360),Vector2(820,480),Vector2(1080,320)]
  var balloon_brake=false
  if number==1: _key(KEY_ENTER)
  deadline=Time.get_ticks_msec()+120000
  while main.session!=null and not main.session.ended and Time.get_ticks_msec()<deadline:
   var s=main.session
   match number:
    1:
     if s.balloon_delivery_index>=1 and waypoint==0: waypoint=1
     if waypoint>=1 and waypoint<=3 and s.p.distance_to(waypoints[waypoint])<30: waypoint+=1
     if s.balloon_delivery_index>=2: waypoint=5
     _motion(s.presentation.design_to_screen(waypoints[waypoint]) if is_instance_valid(s.presentation) else waypoints[waypoint])
     var dock_approach=waypoint not in [1,2,3]
     var distance_to_dock=s.p.distance_to(s.target)
     var brake_now=dock_approach and distance_to_dock<190
     if brake_now!=balloon_brake:
      _held_key(KEY_SPACE,brake_now);balloon_brake=brake_now
    2:
     if not s.ended:
      var state=s.kite_model.snapshot()
      var ring_index=int(state.nextRing)
      if ring_index<5:
       var error=float(state.height)-float(s.kite_model.RING_HEIGHT[ring_index])
       var aim=clampf(error*0.024-float(state.vy)*0.014,-1.0,1.0)
       _motion(Vector2(640.0,390.0-aim*235.0))
    3:
     if s.beat_window: _key(KEY_SPACE)
    4:
     var chosen=_crowd_priority_lane(s.crowd_model)
     if chosen>=0 and s.crowd_model.desired_lane!=chosen: _key(KEY_Q if chosen==0 else KEY_E)
    5:
     var index=-1
     var highest=-INF
     for i in s.hat_y.size():
      if not s.hats_consumed[i] and s.hat_y[i]>highest: index=i;highest=s.hat_y[i]
     if index>=0: _motion(Vector2(s.hat_x[index],570))
    6:
     if s.beat_window and s.beat<8: _key(rhythm[s.beat])
    7:
     if s.pipe_model.order_index!=pipe_order_played:
      pipe_order_played=s.pipe_model.order_index
      var routes=[[0,4,6,15],[0,1,2,3,4,8,12],[0,1,2,3,6,10,14,15]]
      for cell in routes[pipe_order_played]: _click(Vector2(400+(cell%4)*160,216+int(cell/4)*100))
    8:
     Input.action_release('ui_left');Input.action_release('ui_right')
     var expected=s.balance+sin((s.phase+0.016)*1.7)*0.50*0.016
     Input.action_press('ui_right' if expected>0 else 'ui_left')
    9: _motion(Vector2(640,420))
    10:
     var photo_state:Dictionary=s.bubble_model.snapshot()
     if str(photo_state.phase)=='aim':
      var center:Vector2=photo_state.target_center
      _motion(center)
      if float(photo_state.round_elapsed)>=float(s.bubble_model.BEST_POSE_TIMES[int(photo_state.round)])+0.02 and bool(photo_state.focus_available): _key(KEY_SPACE)
    11:
     if not puzzle_done:
      for key in [KEY_1,KEY_2,KEY_2,KEY_3,KEY_2,KEY_4]: _key(key)
      puzzle_done=true
    12:
     if not s.sequence_showing: _key(KEY_1+s.sequence[s.sequence_index])
   await get_tree().physics_frame
  Input.action_release('ui_left');Input.action_release('ui_right')
  if main.session!=null and not main.session.ended:
   print('NATIVE TIMEOUT: ',id,' waypoint=',waypoint,' position=',main.session.p,' velocity=',main.session.velocity,' steering=',main.session.mouse_steering,' target=',main.session.steering_target,' elapsed=',main.session.elapsed)
  if balloon_brake: _held_key(KEY_SPACE,false)
  deadline=Time.get_ticks_msec()+2000
  while main.modal_kind!='result' and Time.get_ticks_msec()<deadline: await get_tree().process_frame
  if main.modal_kind!='result' or not progress.photos.has('photo-welcome-game-%d'%number): await _fail('No successful result '+id);return
  await get_tree().create_timer(0.2).timeout
  await RenderingServer.frame_post_draw
  if not main._capture('pm/Snapland-art/images/ART-5-result-%02d.png'%number): await _fail('Failed result evidence '+id);return
  print('PASS: native input and photo result '+id)
  _button('返回遊園')
  await get_tree().process_frame
 if not await _review_wardrobe(): return
 main._show_achievements()
 await get_tree().create_timer(0.2).timeout
 await RenderingServer.frame_post_draw
 if not main._capture('pm/Snapland-small-game/images/SG-14-achievements-unlocked.png'): await _fail('Failed achievement evidence');return
 if progress.normal_count()!=12 or not progress.achievements.has('ACH_WELCOME_CLEAR'): await _fail('Park achievement mismatch');return
 print('PASS: native twelve-game review and park achievement')
 await main._quit_game()
func _review_world() -> bool:
 var world=main.world
 var original_size=world.camera.size
 world.camera.size=11.0
 for entry in [[KEY_W,'back'],[KEY_S,'front'],[KEY_A,'left'],[KEY_D,'right']]:
  world.player.position=Vector3(0,0.4,-24)
  await get_tree().create_timer(0.6).timeout
  var start=world.player.position
  var event=InputEventKey.new();event.keycode=entry[0];event.physical_keycode=entry[0];event.pressed=true;Input.parse_input_event(event)
  await get_tree().create_timer(0.35).timeout
  await RenderingServer.frame_post_draw
  if world.player.position.distance_to(start)<0.1 or world.facing!=entry[1]:
   event.pressed=false;Input.parse_input_event(event);await _fail('Native direction movement '+str(entry));return false
  if not main._capture('pm/Snapland-art/images/ART-4-walk-'+entry[1]+'.png'):
   event.pressed=false;Input.parse_input_event(event);await _fail('Walk screenshot failed');return false
  var walk_texture=world.avatar.texture
  var animation_deadline=Time.get_ticks_msec()+450
  while world.avatar.texture==walk_texture and Time.get_ticks_msec()<animation_deadline: await get_tree().physics_frame
  if world.avatar.texture==walk_texture:
   event.pressed=false;Input.parse_input_event(event);await _fail('Walk frame did not change '+entry[1]);return false
  await RenderingServer.frame_post_draw
  if not main._capture('pm/Snapland-art/images/ART-4-step-'+entry[1]+'.png'):
   event.pressed=false;Input.parse_input_event(event);await _fail('Walk second frame screenshot failed');return false
  event.pressed=false;Input.parse_input_event(event)
 world.player.position=Vector3(0,0.4,-24)
 world.facing='front'
 await get_tree().create_timer(0.6).timeout
 for action in ['wave','photo','interact','celebrate']:
  world.play_action(action)
  await get_tree().create_timer(0.1).timeout
  await RenderingServer.frame_post_draw
  if not main._capture('pm/Snapland-art/images/ART-7-action-'+action+'.png'): await _fail('Action capture '+action);return false
 if not world.avatar_renderer.is_asset_ready() or not world.avatar_renderer.has_hat_atlas(): await _fail('Avatar source assets not loaded');return false
 world.camera.size=original_size
 world.apply_settings({'reduced_motion':true});world.set_night(true)
 await get_tree().create_timer(0.6).timeout
 await RenderingServer.frame_post_draw
 if not main._capture('pm/Snapland-art/images/ART-3-reduced-night.png'): await _fail('Reduced night screenshot failed');return false
 world.apply_settings({'reduced_motion':false});world.set_night(false)
 for point in world.points:
  if not point.id.begins_with('gate:'): continue
  world.player.position=point.position+Vector3(0,0.3,0)
  await get_tree().create_timer(0.75).timeout
  if world.nearest.get('id','')!=point.id: await _fail('Gate nearest interaction '+point.id);return false
  await RenderingServer.frame_post_draw
  if not main._capture('pm/Snapland-art/images/ART-3-'+point.id.replace(':','-')+'.png'): await _fail('Gate screenshot failed');return false
  _key(KEY_E)
  await get_tree().create_timer(0.1).timeout
  if main.modal_kind!='gate': await _fail('Gate modal '+point.id);return false
  _key(KEY_ESCAPE)
  await get_tree().process_frame
 print('PASS: native four-direction movement, reduced night and nine gate interactions')
 return true
func _instantiate_main(prepare_returning_player: bool = true) -> Node:
 if prepare_returning_player:
  Progress.tutorial_seen_games.clear()
  for game_id in Progress.WELCOME_GAME_IDS:
   Progress.tutorial_seen_games.append(game_id)
  print("NATIVE PROFILE: returning-player tutorial state seeded for %d welcome games" % Progress.tutorial_seen_games.size())
 var packed_scene=load(MAIN_SCENE_PATH) as PackedScene
 if packed_scene==null: push_error('Could not load main scene '+MAIN_SCENE_PATH);return null
 return packed_scene.instantiate()
func _review_wardrobe() -> bool:
 var before_coins=progress.coins
 var before_appearance=progress.appearance.duplicate(true)
 _key(KEY_C)
 await get_tree().create_timer(0.25).timeout
 if main.modal_kind!='wardrobe': await _fail('Native wardrobe key entry');return false
 await RenderingServer.frame_post_draw
 if not main._capture('pm/Snapland-art/images/ART-8-appearance.png'): await _fail('Appearance screenshot');return false
 for index in range(3):
  if not await _option('Appearance_hair',index): return false
  await RenderingServer.frame_post_draw
  if not main._capture('pm/Snapland-art/images/ART-7-hair-%d.png'%index): await _fail('Hair preview');return false
 if not await _option('Appearance_skin',1): return false
 if main.wardrobe_panel.draft_appearance.skin==before_appearance.skin: await _fail('Native appearance option input');return false
 if progress.appearance!=before_appearance: await _fail('Draft saved before applying');return false
 _button('套用外觀')
 await get_tree().create_timer(0.15).timeout
 if progress.appearance.skin==before_appearance.skin or progress.coins!=before_coins: await _fail('Free appearance apply');return false
 _button('服飾店')
 await get_tree().create_timer(0.15).timeout
 for item_id in ['hat-straw','hat-sailor','hat-flower']:
  if not await _named_button('WardrobeItem_'+item_id): return false
  await RenderingServer.frame_post_draw
  if not main._capture('pm/Snapland-art/images/ART-7-preview-'+item_id+'.png'): await _fail('Hat preview');return false
  if not await _named_button('Preview_back'): return false
  await RenderingServer.frame_post_draw
  if not main._capture('pm/Snapland-art/images/ART-7-preview-'+item_id+'-back.png'): await _fail('Hat back preview');return false
  if not await _named_button('Preview_front'): return false
 for item_id in ['outfit-coral','hat-straw']:
  if not await _named_button('WardrobeItem_'+item_id): return false
  if progress.equipped.get(progress.wardrobe_item(item_id).slot,'')==item_id: await _fail('Preview auto equipped');return false
  await RenderingServer.frame_post_draw
  if not main._capture('pm/Snapland-art/images/ART-8-preview-'+item_id+'.png'): await _fail('Fitting screenshot');return false
  _button('購買所選')
  await get_tree().create_timer(0.2).timeout
  if not progress.owned_clothes.has(item_id): await _fail('Native clothing purchase '+item_id);return false
  if not await _named_button('WardrobeItem_'+item_id): return false
  _button('穿戴所選')
  await get_tree().create_timer(0.2).timeout
  if progress.equipped.get(progress.wardrobe_item(item_id).slot,'')!=item_id: await _fail('Native equip '+item_id);return false
 if progress.coins!=before_coins-140: await _fail('Purchase currency mismatch');return false
 await RenderingServer.frame_post_draw
 if not main._capture('pm/Snapland-main/images/MAIN-8-wardrobe.png'): await _fail('Wardrobe evidence');return false
 _key(KEY_ESCAPE)
 await get_tree().create_timer(0.9).timeout
 main.world.player.position=Vector3(0,0.4,-24);main.world.camera.size=11.0;main.world.facing='front'
 await get_tree().create_timer(0.6).timeout
 await RenderingServer.frame_post_draw
 if not main._capture('pm/Snapland-art/images/ART-7-equipped.png'): await _fail('Equipped island screenshot');return false
 var saved_equipped=progress.equipped.duplicate(true)
 if not progress.save_progress(): await _fail('Wardrobe save');return false
 progress._reset_memory();progress.load_progress()
 if progress.equipped!=saved_equipped or progress.coins!=before_coins-140: await _fail('Wardrobe reload');return false
 _key(KEY_C)
 await get_tree().create_timer(0.15).timeout
 _button('服飾店')
 await get_tree().create_timer(0.1).timeout
 if not await _named_button('WardrobeItem_outfit-gold'): return false
 _key(KEY_ESCAPE)
 await get_tree().process_frame
 if progress.equipped!=saved_equipped: await _fail('Cancel fitting changed outfit');return false
 print('PASS: native wardrobe inputs, free appearance, fitting, purchase, equip, cancellation and reload')
 return true
func _option(name:String,index:int) -> bool:
 var selector=main.overlay.find_child(name,true,false)
 if selector==null: await _fail('Missing appearance selector '+name);return false
 _motion(selector.get_global_rect().get_center());_click(selector.get_global_rect().get_center())
 await get_tree().process_frame
 var popup=selector.get_popup()
 if popup.visible:
  _popup_key(popup,KEY_ESCAPE)
  await get_tree().process_frame
 _key(KEY_SPACE)
 await get_tree().process_frame
 if not popup.visible: await _fail('Appearance popup did not open '+name);return false
 var step=KEY_DOWN if index>selector.selected else KEY_UP
 for i in range(absi(index-selector.selected)):
  _popup_key(popup,step)
  await get_tree().process_frame
 _popup_key(popup,KEY_ENTER)
 await get_tree().create_timer(0.15).timeout
 if selector.selected!=index: await _fail('Appearance popup selected '+str(selector.selected)+' expected '+str(index));return false
 return true
func _popup_key(popup:Window,code:int) -> void:
 if OS.get_name()!='Windows':
  push_error('Native popup keys require Windows PostMessage input')
  return
 var key_name=''
 match code:
  KEY_DOWN: key_name='down'
  KEY_UP: key_name='up'
  KEY_ENTER, KEY_KP_ENTER: key_name='enter'
  KEY_ESCAPE: key_name='escape'
  KEY_SPACE: key_name='space'
  _: push_error('Unsupported native popup key '+str(code));return
 var hwnd=DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE,popup.get_window_id())
 if hwnd==0:
  push_error('PopupMenu returned no Windows HWND')
  return
 var output=[]
 var script_path=ProjectSettings.globalize_path('res://tools/native_popup_key.py')
 var exit_code=OS.execute('python',[script_path,str(hwnd),key_name],output,true)
 if exit_code!=0:
  push_error('PostMessage popup key failed: '+str(output))
func _named_button(name:String) -> bool:
 var control=main.overlay.find_child(name,true,false)
 if control==null: await _fail('Missing named clothing button '+name);return false
 var parent=control.get_parent()
 while parent!=null:
  if parent is ScrollContainer: parent.ensure_control_visible(control);break
  parent=parent.get_parent()
 await get_tree().create_timer(0.1).timeout
 var rect=control.get_global_rect()
 if not main.get_viewport().get_visible_rect().encloses(rect): await _fail('Clothing button outside viewport '+name);return false
 _motion(rect.get_center());_click(rect.get_center())
 await get_tree().create_timer(0.15).timeout
 return true
func _button(needle:String) -> void:
 var button=_find(main.overlay,needle)
 if button:
  var rect=button.get_global_rect()
  if not main.get_viewport().get_visible_rect().encloses(rect):
   push_error('Native button outside viewport '+needle+' '+str(rect));return
  _motion(rect.get_center())
  _click(rect.get_center())
 else: push_error('Missing native review button '+needle)
func _find(node:Node,needle:String) -> Button:
 if node is Button and node.text.contains(needle): return node
 for child in node.get_children():
  var found=_find(child,needle)
  if found:return found
 return null
func _held_key(code:int,pressed:bool) -> void:
 var event=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=pressed;Input.parse_input_event(event)
func _key(code:int) -> void:
 for pressed in [true,false]:
  var event=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=pressed;Input.parse_input_event(event)
func _motion(position:Vector2) -> void:
 var event=InputEventMouseMotion.new();event.position=position;event.global_position=position;event.window_id=get_window().get_window_id();Input.parse_input_event(event)
func _click(position:Vector2) -> void:
 for pressed in [true,false]:
  var event=InputEventMouseButton.new();event.position=position;event.global_position=position;event.window_id=get_window().get_window_id();event.button_index=MOUSE_BUTTON_LEFT;event.button_mask=MOUSE_BUTTON_MASK_LEFT if pressed else 0;event.pressed=pressed;Input.parse_input_event(event)
func _crowd_priority_lane(model) -> int:
 var chosen=-1
 var earliest_deadline=INF
 for direction in 2:
  var lane_queue:Array=model.queues[direction]
  if lane_queue.is_empty(): continue
  var head:Dictionary=lane_queue[0]
  var deadline=float(head.arrived_at)+float(head.patience)
  if deadline<earliest_deadline:
   earliest_deadline=deadline
   chosen=direction
 return chosen
func _fail(message:String) -> void:
 push_error(message)
 main.audio.shutdown()
 await get_tree().create_timer(0.15).timeout
 get_tree().quit(1)

## Dispatch a complete, observable pointer click through the normal input route.
## Both coordinates matter: Input tracks global_position, while Viewport hit-tests
## position. Leaving global_position at zero moves the tracked pointer to (0, 0)
## between events even if gui_get_hovered_control() briefly reports the target.
func _native_click_button(button: BaseButton, context: String) -> bool:
 if not is_instance_valid(button) or not button.is_visible_in_tree() or button.disabled:
  await _fail("Native click target is missing, hidden or disabled: " + context)
  return false
 var ancestor := button.get_parent()
 while ancestor != null:
  if ancestor is ScrollContainer: ancestor.ensure_control_visible(button)
  ancestor = ancestor.get_parent()
 await get_tree().process_frame
 await get_tree().process_frame
 var viewport := button.get_viewport()
 var rect := button.get_global_rect()
 var visible_rect := viewport.get_visible_rect()
 ancestor = button.get_parent()
 while ancestor != null:
  if ancestor is Control and ancestor.clip_contents:
   visible_rect = visible_rect.intersection(ancestor.get_global_rect())
  ancestor = ancestor.get_parent()
 if not visible_rect.encloses(rect):
  await _fail("Native click target is clipped: %s rect=%s visible=%s" % [context, rect, visible_rect])
  return false
 var observation := {"down": 0, "up": 0, "pressed": 0, "gui": []}
 var on_down := func(): observation.down += 1
 var on_up := func(): observation.up += 1
 var on_pressed := func(): observation.pressed += 1
 var on_gui := func(event: InputEvent):
  if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
   observation.gui.append("down" if event.pressed else "up")
 button.button_down.connect(on_down)
 button.button_up.connect(on_up)
 button.pressed.connect(on_pressed)
 button.gui_input.connect(on_gui)
 var target_path := str(button.get_path())
 var point := viewport.get_final_transform() * rect.get_center()
 # Flush queued OS/fixture events before beginning this click. No input state,
 # control signal or gameplay callback is assigned or invoked directly.
 Input.flush_buffered_events()
 var motion := InputEventMouseMotion.new()
 motion.position = point
 motion.global_position = point
 motion.window_id = get_window().get_window_id()
 motion.button_mask = Input.get_mouse_button_mask()
 Input.parse_input_event(motion)
 Input.flush_buffered_events()
 var hovered := viewport.gui_get_hovered_control()
 var diagnostics := "target=%s rect=%s pointer=%s hovered=%s button_hovered=%s initial_mask=%d" % [target_path, rect, point, str(hovered.get_path()) if is_instance_valid(hovered) else "none", button.is_hovered(), Input.get_mouse_button_mask()]
 if not button.is_hovered() or not (hovered == button or is_instance_valid(hovered) and button.is_ancestor_of(hovered)):
  for pair in [[button.button_down, on_down], [button.button_up, on_up], [button.pressed, on_pressed], [button.gui_input, on_gui]]:
   pair[0].disconnect(pair[1])
  await _fail("Native pointer did not hover its target: %s; %s" % [context, diagnostics])
  return false
 # Dispatch and flush each distinct event without yielding to unrelated OS
 # motion or deferred focus changes between the observed down and release.
 for is_down in [true, false]:
  var event := InputEventMouseButton.new()
  event.position = point
  event.global_position = point
  event.window_id = get_window().get_window_id()
  event.button_index = MOUSE_BUTTON_LEFT
  event.button_mask = MOUSE_BUTTON_MASK_LEFT if is_down else 0
  event.pressed = is_down
  Input.parse_input_event(event)
  Input.flush_buffered_events()
 if is_instance_valid(button):
  for pair in [[button.button_down, on_down], [button.button_up, on_up], [button.pressed, on_pressed], [button.gui_input, on_gui]]:
   pair[0].disconnect(pair[1])
 diagnostics += " observed=%s final_mask=%d" % [observation, Input.get_mouse_button_mask()]
 if observation.down != 1 or observation.pressed != 1:
  await _fail("Native click did not activate its target: %s; %s" % [context, diagnostics])
  return false
 print("INPUT: ", context, " ", diagnostics)
 await get_tree().process_frame
 await get_tree().process_frame
 return true
