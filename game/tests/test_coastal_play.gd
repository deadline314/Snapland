extends SceneTree
var main: Node
var play: Node3D
var failures: Array[String]=[]
var notes: Array[int]=[]
func _initialize() -> void:
 if not OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path():push_error("Coastal play tests require an isolated absolute save path");quit(1);return
 call_deferred("_run")
func _run() -> void:
 var progress=root.get_node("Progress")
 progress.reset_progress();progress.intro_seen=true;progress.save_progress()
 main=load("res://game/main.tscn").instantiate();root.add_child(main)
 await _frames(4)
 play=main.world.coastal_play
 play.note_requested.connect(func(note: int):notes.append(note))
 var before: String=FileAccess.get_file_as_string(OS.get_environment("SNAPLAND_SAVE_PATH"))
 var original: Vector3=play.ball.global_position
 main.world.player.position=original+Vector3(0,0,1.0)
 await _frames(8)
 # Enter through actual Main interaction routing, not an independent toy model.
 main._interact("play:ball","球")
 await _frames(10)
 _check(play.ball.global_position.z<original.z-0.05,"kick direction follows the player's side of the ball")
 _check(main.session==null and main.modal_kind=="" and not main.world.blocked,"free play stays in the world")
 _check(play.ball_point.position.distance_to(play.ball.global_position)<0.2,"interaction follows the physical ball")
 main.world.blocked=true
 await _frames(3)
 var held: Vector3=play.ball.position
 var velocity: Vector3=play._ball_velocity
 await _frames(12)
 _check(play.ball.freeze and play.ball.position.distance_to(held)<0.0001,"modal pause freezes the physical ball")
 _check(not play.activate("coast:tide-wheel"),"blocked world rejects free-play actions")
 main.world.blocked=false
 await _frames(3)
 _check(not play.ball.freeze and play.ball.linear_velocity.length()>0.01 and velocity.length()>0.01,"resume restores physical momentum")
 play._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
 await _frames(2);held=play.ball.position;await _frames(8)
 _check(play.ball.freeze and play.ball.position.distance_to(held)<0.0001,"focus loss freezes the ball")
 play._notification(NOTIFICATION_APPLICATION_FOCUS_IN)
 await _frames(2)
 main.world.set_process(false)
 await _frames(2);held=play.ball.position;await _frames(4)
 _check(play.ball.freeze and play.ball.position.distance_to(held)<0.0001,"hidden game-session world freezes the toy")
 main.world.set_process(true)
 await _frames(20)
 main._interact("play:recall","球架")
 await _frames(2)
 _check(play.ball.position.distance_to(Vector3(-24,0.7,5.1))<0.15,"explicit recall returns the toy safely through its physics state")
 main.world.player.position=play.ball.global_position+Vector3(1,0,0)
 await _frames(8)
 _check(str(main.world.nearest.get("id",""))=="play:ball","recall cradle does not steal the side-kick interaction")
 var side_start: Vector3=play.ball.position
 await _frames(20)
 main._interact("play:ball","球")
 await _frames(8)
 _check(play.ball.position.x<side_start.x-0.05,"side kick reverses direction through actual physics")
 for hit in 4:
  await _frames(20)
  main._interact("coast:storm-bell","鐘")
 _check(notes==[0,2,3,2],"each manual bell strike advances its four-tone phrase")
 _check(main.modal_kind=="" and play.bell_hits==4,"bell remains a world object rather than a dialogue or challenge")
 await _frames(3)
 _check(absf(play.bell.rotation.z)>0.001,"normal bell strike has visible swing")
 main.world.reduced_motion=true
 await _frames(3)
 _check(is_zero_approx(play.bell.rotation.z),"reduced motion removes secondary bell swing")
 await _frames(20)
 main._interact("coast:tide-wheel","水閘")
 var stopped: float=play.rotor.rotation.z
 await _frames(20)
 _check(not play.valve_open and is_equal_approx(stopped,play.rotor.rotation.z),"closing the gate stops its real rotor")
 _check(not play.streams[0].visible and play.prompt("coast:tide-wheel")=="打開水閘","closed flow and next action agree")
 main.world.reduced_motion=false
 main._interact("coast:tide-wheel","水閘")
 await _frames(20)
 _check(play.valve_open and play.streams[0].visible and not is_equal_approx(stopped,play.rotor.rotation.z),"reopening the gate restores visible flow and rotation")
 main.world.reduced_motion=true
 await _frames(2);stopped=play.rotor.rotation.z;await _frames(12)
 _check(is_equal_approx(stopped,play.rotor.rotation.z) and play.streams[0].visible,"reduced motion keeps water's open state without ambient rotation")
 await _test_discoveries()
 _check(before==FileAccess.get_file_as_string(OS.get_environment("SNAPLAND_SAVE_PATH")),"all free play preserves the complete save bytes")
 var ball_ref: WeakRef=weakref(play.ball)
 main.world.set_process(false);main.world.set_physics_process(false)
 main.audio.shutdown()
 await create_timer(0.15).timeout
 main.queue_free();await _frames(5)
 _check(ball_ref.get_ref()==null,"scene exit frees the body and its free-play owner")
 if failures.is_empty():print("PASS: coastal free play direction, physics, recall, bell, water, pause/focus/reduced-motion and unchanged save");quit(0)
 else:push_error(str(failures));quit(1)
func _frames(count: int) -> void:
 for i in count:await physics_frame
func _test_discoveries() -> void:
 var discovery: Node3D=play.discoveries
 main.world.player.position=Vector3(-27,0.3,-45)
 main.world.player.velocity=Vector3.ZERO
 await _frames(3)
 var start: Vector3=main.world.player.position
 main._interact("coast:lighthouse","燈鏡")
 _check(discovery.controlling and main.session==null and main.modal_kind=="","lens control stays in the live world without opening a modal")
 var initial: float=discovery.lens_angle
 Input.action_press("move_right")
 await _frames(25)
 Input.action_release("move_right")
 _check(discovery.lens_angle>initial+0.2,"real movement input turns the optical axis")
 _check(Vector2(main.world.player.position.x-start.x,main.world.player.position.z-start.z).length()<0.01,"lens input does not also walk the player")
 main.world.blocked=true
 var held: float=discovery.lens_angle
 Input.action_press("move_left");await _frames(5);Input.action_release("move_left")
 _check(is_equal_approx(held,discovery.lens_angle),"modal pause blocks lens input")
 main.world.blocked=false
 play._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
 _check(not discovery.controlling,"focus loss releases the manual control mode")
 play._notification(NOTIFICATION_APPLICATION_FOCUS_IN)
 discovery.turn_lens(-100)
 _check(is_equal_approx(discovery.lens_angle,-0.9) and discovery.receiver_active==-1,"out-of-range wheel input clamps safely without a false reflected hit")
 discovery.turn_lens(0.18)
 _check(discovery.receiver_active==0,"optical direction selects the actual aligned sea reflector")
 var direction: Vector3=-discovery.beacon_light.global_basis.z
 var target: Vector3=discovery.receivers[0].global_position-discovery.beacon_light.global_position
 _check(direction.normalized().dot(target.normalized())>0.999,"real spotlight and lit reflector share the same three-dimensional ray")
 main.world.set_time_of_day("night")
 main.world._update_lamp_selection(true)
 _check(main.world.lamps.has(discovery.beacon_light) and discovery.beacon_light.light_energy>0.0,"nearby steerable light joins the real night-light budget")
 _check(main.world.lamps.filter(func(light: Light3D):return light.light_energy>0.0).size()<=8 and main.world.lamps.filter(func(light: Light3D):return light.shadow_enabled).size()<=2,"manual optics preserve the global light and shadow caps")
 main.world.player.position=Vector3(27,0.3,-52)
 await _frames(15)
 main._interact("coast:glass-garden","溫室")
 _check(discovery.garden_open and discovery.droplets[0].visible,"opening the real garden valve shows water")
 await _frames(25)
 var growth: float=discovery.garden_growth
 _check(growth>0.0 and growth<1.0,"manual watering produces gradual visible bloom")
 main.world.blocked=true
 await _frames(10)
 _check(is_equal_approx(growth,discovery.garden_growth),"garden does not grow behind a modal")
 main.world.blocked=false
 await _frames(15)
 main._interact("coast:glass-garden","溫室")
 growth=discovery.garden_growth
 await _frames(20)
 _check(not discovery.garden_open and not discovery.droplets[0].visible and is_equal_approx(growth,discovery.garden_growth),"closing water stops flow and growth but retains the flowers")
 main._interact("coast:glass-garden","溫室")
 await _frames(200)
 _check(is_equal_approx(discovery.garden_growth,1.0) and discovery.flowers.all(func(flower: Node3D):return flower.scale.is_equal_approx(Vector3.ONE)),"all four blooms finish without giving a score or forcing another scene")
 _check(main.session==null and main.modal_kind=="","garden stays in ordinary exploration")
func _check(ok: bool,message: String) -> void:
 if not ok:failures.append(message);push_error(message)
