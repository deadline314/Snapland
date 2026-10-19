extends Node3D
## Scene-owned free play. Nothing here writes Progress or opens a game session.
signal note_requested(note: int)
const Ball = preload("res://game/world/drift_ball.gd")
var world: Node3D
var ball: RigidBody3D
var bell: Node3D
var rotor: Node3D
var gate: MeshInstance3D
var water: MeshInstance3D
var spill: MeshInstance3D
var streams: Array[MeshInstance3D] = []
var ball_point: Dictionary
var valve_open := true
var bell_elapsed := 10.0
var bell_hits := 0
var _cooldown := 0.0
var _flow_clock := 0.0
var _focused := true
var _ball_velocity := Vector3.ZERO
var _ball_spin := Vector3.ZERO

func configure(owner_world: Node3D) -> void:
 world=owner_world
 bell=world.get_node("CoastalBellSwing")
 rotor=world.get_node("CoastalWaterwheelRotor")
 rotor.set_meta("play_speed",0.18)
 water=world.get_node("CoastalWaterFlow")
 water.material_override=water.material_override.duplicate()
 _build_ball()
 # Put the movable gate on the camera-facing end, so its open/closed result
 # can be read from the trail rather than being hidden behind the wheel.
 gate=world._box(Vector3(32,0.65,-18),Vector3(2.3,0.7,0.14),Color("#b79459"))
 gate.name="PlayerSluiceGate"
 for side in [-1,1]:
  world._box(Vector3(32+side*1.3,0.95,-18),Vector3(0.16,1.9,0.2),Color("#71583c"))
 world._box(Vector3(32,1.85,-18),Vector3(2.85,0.16,0.2),Color("#9b8055"))
 spill=world._box(Vector3(32,0.61,-17.9),Vector3(1.9,0.6,0.045),Color("#8dc6bb"))
 var valve: MeshInstance3D=world._cylinder(Vector3(29.2,1.0,-19.4),0.32,0.08,Color("#c9995d"))
 valve.rotation.x=PI*0.5
 for index in 5:
  var stream: MeshInstance3D=world._box(Vector3(31.15+index*0.38,0.31,-20.0),Vector3(0.12,0.035,0.6),Color("#a6e1d0"))
  streams.append(stream)
 _update_gate()

func _build_ball() -> void:
 ball=Ball.new()
 ball.name="SeaDriftBall"
 ball.position=Ball.HOME
 ball.mass=0.7
 ball.linear_damp=0.45
 ball.angular_damp=0.6
 # Player walks through the small toy; only the environment and recall area
 # constrain it. Deliberate E input, rather than incidental collision, kicks it.
 ball.collision_layer=2
 ball.collision_mask=1
 ball.continuous_cd=true
 var material:=PhysicsMaterial.new()
 material.bounce=0.55;material.friction=0.65
 ball.physics_material_override=material
 world.add_child(ball)
 ball.add_collision_exception_with(world.player)
 var shape:=CollisionShape3D.new()
 var sphere:=SphereShape3D.new();sphere.radius=0.34;shape.shape=sphere
 ball.add_child(shape)
 var mesh: MeshInstance3D=world._sphere(Ball.HOME,0.34,Color("#e9c391"))
 mesh.name="StripedBuoy"
 mesh.reparent(ball)
 for axis in 2:
  var ring:=TorusMesh.new();ring.inner_radius=0.325;ring.outer_radius=0.348;ring.rings=16;ring.ring_segments=6
  var stripe:=MeshInstance3D.new();stripe.mesh=ring;stripe.material_override=world._mat(Color("#b45d48"))
  stripe.rotation.z=PI*0.5 if axis==1 else 0.0
  ball.add_child(stripe)
 var marker: Label3D=world._label("◇",Ball.HOME+Vector3(0,1.1,0),38,Color("#edbb65"))
 ball_point={"id":"play:ball","label":"踢海漂球","position":Ball.HOME,"marker":marker}
 world.points.append(ball_point)
 world._point("play:recall","拿回海漂球",Vector3(-21.4,0.18,8.0))
 # A low cradle makes the recall position legible without another floating sign.
 for side in [-1,1]:
  world._box(Vector3(-21.4+side*0.36,0.22,8.0),Vector3(0.12,0.32,0.9),Color("#8e7352"))

func activate(id: String) -> bool:
 if not is_instance_valid(world) or world.blocked or not world.is_processing() or not _focused:return false
 if id not in ["play:ball","play:recall","coast:storm-bell","coast:tide-wheel"]:return false
 if _cooldown>0.0:return true
 _cooldown=0.18
 match id:
  "play:ball":
   var direction: Vector3=ball.global_position-world.player.global_position
   direction.y=0.0
   if direction.length_squared()<0.01:direction=Vector3(0,0,-1)
   ball.sleeping=false
   ball.apply_central_impulse(direction.normalized()*2.8+Vector3.UP*0.65)
  "play:recall":
   ball.recall_requested=true
   ball.sleeping=false
  "coast:storm-bell":
   bell_elapsed=0.0
   bell_hits+=1
   note_requested.emit([0,2,3,2][(bell_hits-1)%4])
  "coast:tide-wheel":
   valve_open=not valve_open
   _update_gate()
 return true

func prompt(id: String) -> String:
 match id:
  "play:ball":return "踢海漂球"
  "play:recall":return "拿回海漂球"
  "coast:storm-bell":return "敲潮鐘"
  "coast:tide-wheel":return "關閉水閘" if valve_open else "打開水閘"
 return ""

func _update_gate() -> void:
 rotor.set_meta("play_speed",0.7 if valve_open else 0.0)
 gate.position.y=1.18 if valve_open else 0.55
 spill.visible=valve_open
 water.material_override.albedo_color=Color("#428d8c") if valve_open else Color("#28505a")
 for stream in streams:stream.visible=valve_open

func _physics_process(delta: float) -> void:
 if not is_instance_valid(world) or not is_instance_valid(ball):return
 var paused: bool=world.blocked or not world.is_processing() or not _focused
 if paused!=ball.freeze:
  if paused:
   _ball_velocity=ball.linear_velocity;_ball_spin=ball.angular_velocity
   ball.freeze=true
  else:
   ball.freeze=false
   ball.linear_velocity=_ball_velocity;ball.angular_velocity=_ball_spin
 if paused:return
 _cooldown=maxf(0,_cooldown-delta)
 ball_point.position=ball.global_position
 if is_instance_valid(ball_point.get("marker")):
  ball_point.marker.position=ball.global_position+Vector3(0,1.1,0)
 bell_elapsed+=delta
 _flow_clock+=delta
 bell.rotation.z=0.0 if world.reduced_motion else sin(bell_elapsed*9.0)*0.24*exp(-bell_elapsed*1.8)
 if valve_open and not world.reduced_motion:
  for index in streams.size():streams[index].position.z=-22.2+fposmod(_flow_clock*1.5+index*0.8,4.3)

func _notification(what: int) -> void:
 if what==NOTIFICATION_APPLICATION_FOCUS_OUT:_focused=false
 elif what==NOTIFICATION_APPLICATION_FOCUS_IN:_focused=true
