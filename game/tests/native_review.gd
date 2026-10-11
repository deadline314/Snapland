extends Node
const MAIN = preload('res://game/main.tscn')
var main: Node
func _ready() -> void:
 call_deferred('_run')
func _run() -> void:
 if OS.get_environment('SNAPLAND_SAVE_PATH').is_empty() or DisplayServer.get_name()=='headless':
  push_error('Native review requires GPU and isolated SNAPLAND_SAVE_PATH');get_tree().quit(1);return
 Progress.reset_progress()
 Progress.intro_seen=true
 main=MAIN.instantiate();get_tree().root.add_child(main)
 await get_tree().create_timer(0.5).timeout
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
  var waypoint=0
  var last_cycle=-1
  var puzzle_done=false
  var rhythm=[KEY_LEFT,KEY_RIGHT,KEY_SPACE,KEY_RIGHT,KEY_LEFT,KEY_SPACE,KEY_LEFT,KEY_RIGHT]
  var waypoints=[Vector2(560,540),Vector2(885,540),Vector2(1060,345)]
  deadline=Time.get_ticks_msec()+35000
  while main.session!=null and not main.session.ended and Time.get_ticks_msec()<deadline:
   var s=main.session
   match number:
    1:
     _motion(waypoints[waypoint])
     if waypoint<2 and s.p.distance_to(waypoints[waypoint])<20: waypoint+=1
    2:
     if s.count<5: _motion(Vector2(640,s.ring_y[s.count]))
    3:
     if s.beat_window: _key(KEY_SPACE)
    4:
     if s.lane!=s.count%2: _key(KEY_Q)
    5:
     var index=-1
     var highest=-INF
     for i in s.hat_y.size():
      if not s.hats_consumed[i] and s.hat_y[i]>highest: index=i;highest=s.hat_y[i]
     if index>=0: _motion(Vector2(s.hat_x[index],570))
    6:
     if s.beat_window and s.beat<8: _key(rhythm[s.beat])
    7:
     if not puzzle_done:
      for point in [Vector2(426,237),Vector2(426,322),Vector2(696,322),Vector2(831,492)]: _click(point)
      puzzle_done=true
    8:
     Input.action_release('ui_left');Input.action_release('ui_right')
     var expected=s.balance+sin((s.phase+0.016)*1.7)*0.50*0.016
     Input.action_press('ui_right' if expected>0 else 'ui_left')
    9: _motion(Vector2(640,420))
    10:
     var cycle=int(floor(s.phase/2.0))
     if fposmod(s.phase,2.0)>=1.65 and cycle!=last_cycle:
      _click(Vector2(790,s.target.y));_click(Vector2(790,s.target.y));last_cycle=cycle
    11:
     if not puzzle_done:
      for key in [KEY_1,KEY_2,KEY_2,KEY_3,KEY_2,KEY_4]: _key(key)
      puzzle_done=true
    12:
     if not s.sequence_showing: _key(KEY_1+s.sequence[s.sequence_index])
   await get_tree().physics_frame
  Input.action_release('ui_left');Input.action_release('ui_right')
  deadline=Time.get_ticks_msec()+2000
  while main.modal_kind!='result' and Time.get_ticks_msec()<deadline: await get_tree().process_frame
  if main.modal_kind!='result' or not Progress.photos.has('photo-welcome-game-%d'%number): await _fail('No successful result '+id);return
  await get_tree().create_timer(0.2).timeout
  await RenderingServer.frame_post_draw
  main._capture('pm/Snapland-small-game/images/SG-%d-result.png'%(number+1))
  print('PASS: native input and photo result '+id)
  _button('返回遊園')
  await get_tree().process_frame
 main._show_achievements()
 await get_tree().create_timer(0.2).timeout
 await RenderingServer.frame_post_draw
 main._capture('pm/Snapland-main/images/MAIN-5-achievements-unlocked.png')
 if Progress.normal_count()!=12 or not Progress.achievements.has('ACH_WELCOME_CLEAR'): await _fail('Park achievement mismatch');return
 print('PASS: native twelve-game review and park achievement')
 await main._quit_game()
func _button(needle:String) -> void:
 var button=_find(main.overlay,needle)
 if button: button.pressed.emit()
 else: push_error('Missing native review button '+needle)
func _find(node:Node,needle:String) -> Button:
 if node is Button and node.text.contains(needle): return node
 for child in node.get_children():
  var found=_find(child,needle)
  if found:return found
 return null
func _key(code:int) -> void:
 for pressed in [true,false]:
  var event=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=pressed;Input.parse_input_event(event)
func _motion(position:Vector2) -> void:
 var event=InputEventMouseMotion.new();event.position=position;Input.parse_input_event(event)
func _click(position:Vector2) -> void:
 for pressed in [true,false]:
  var event=InputEventMouseButton.new();event.position=position;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed;Input.parse_input_event(event)
func _fail(message:String) -> void:
 push_error(message)
 main.audio.shutdown()
 await get_tree().create_timer(0.15).timeout
 get_tree().quit(1)
