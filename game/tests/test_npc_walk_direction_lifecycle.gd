extends SceneTree
const Motion = preload("res://game/world/npc_walk_motion.gd")
const NpcActivity = preload("res://game/world/npc_activity.gd")
func _initialize() -> void:
	call_deferred("_run")
func _ground(_point: Vector2) -> float:
	return 0.18
func _run() -> void:
	var scene := Node3D.new()
	root.add_child(scene)
	var actor := Node3D.new()
	actor.position=Vector3(-5.4,0.18,-7.8)
	scene.add_child(actor)
	var sprite := Sprite3D.new()
	sprite.texture=NpcActivity.load_action_frames("imp")[0]
	sprite.pixel_size=0.01
	actor.add_child(sprite)
	var camera := Camera3D.new()
	camera.rotation_degrees=Vector3(-31.56,8.0,0)
	scene.add_child(camera)
	var motion := Motion.new()
	scene.add_child(motion)
	assert(motion.configure(actor,sprite,"imp",camera,Callable(self,"_ground")))
	motion.set_enabled(true)
	var chain: float=motion.rig.upper_bone_length+motion.rig.lower_bone_length
	for step in range(4):
		actor.position.x+=0.35/60.0
		motion.update(1.0/60.0)
	# A valid long route frame crosses the support epoch while moving less than
	# the fixed chain's relocation guard; new distance must precede any IK pose.
	var displacement := Vector3(0.252,0,0)
	var before := actor.global_position
	var prior_travel: float=motion.rig.travel
	actor.position+=displacement
	motion.update(0.72)
	assert(actor.global_position.is_equal_approx(before+displacement),"adapter cannot translate its actor a second time")
	assert(is_equal_approx(motion.rig.travel,prior_travel+displacement.length()),"same-view long frame consumes actual distance exactly once")
	assert(motion.rig.first_reach_failure.is_empty(),"long-frame imp support remains physically within fixed reach")
	for leg in range(2):
		assert(motion.rig._legs[leg][0].global_position.distance_to(motion.rig.to_global(motion.rig._pose_ankles[leg]))<chain,"both fixed-bone chains reach the true posed ankle")
	# Turn the short route via the public adapter, then settle and restart it.
	for step in range(30):
		actor.position.x-=0.35/60.0
		motion.update(1.0/60.0)
	assert(motion.rig.direction=="left" and motion.active,"real route turn activates the measured left source")
	for step in range(20): motion.update(1.0/60.0)
	assert(not motion.active and sprite.visible,"stationary settling restores the original authored sprite")
	actor.position.x+=0.006433
	motion.update(0.000144)
	assert(motion.rig.direction=="right" and motion.rig.first_reach_failure.is_empty(),"tiny-frame direction restart keeps exact source/bone geometry")
	motion.close()
	scene.queue_free()
	await process_frame
	print("PASS: imp same-view long-frame support epoch, route turns, settlement and tiny-frame restart")
	quit(0)
