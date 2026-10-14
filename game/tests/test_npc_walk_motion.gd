extends SceneTree

const Motion = preload("res://game/world/npc_walk_motion.gd")
const Costume = preload("res://game/world/npc_costume.gd")
const Library = preload("res://game/world/character_animation_library.gd")
const NpcActivity = preload("res://game/world/npc_activity.gd")
const ParkWorld = preload("res://game/world/park_world.gd")

var _foot_test_failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var save_path:=OS.get_environment("SNAPLAND_SAVE_PATH").strip_edges()
	if save_path.is_empty() or not save_path.is_absolute_path() or save_path.begins_with("user://") or save_path.begins_with("res://"):
		push_error("NPC walk motion test requires a nonempty absolute OS-path SNAPLAND_SAVE_PATH")
		quit(1); return
	assert(load("res://game/tests/native_npc_motion_review.tscn") is PackedScene,"native three-role evidence fixture parses as a PackedScene")
	_check_foot_alpha_cutoff()
	_check_motion_disabled_by_default()
	for role in ["ticket","imp","announcer"]: await _check_motion(role)
	for terrain in [{"role":"ticket","position":Vector3(15.0,0.055,-10.0),"pitch":-18.0},{"role":"imp","position":Vector3(0.0,0.18,-4.0),"pitch":-30.0},{"role":"announcer","position":Vector3(7.75,0.0,-36.2),"pitch":-24.0}]:
		await _check_terrain_contact(String(terrain.role),terrain.position,float(terrain.pitch))
	_check_unmeasured_role_fallback()
	_check_announcer_costume()
	await _check_activity_integration()
	await _check_announcer_natural_rest_at_30hz()
	_check_detached_rig_close()
	if _foot_test_failures>0:
		push_error("NPC projected foot tests failed: %d" % _foot_test_failures)
		quit(1); return
	print("PASS: optional three-role measured gait, source fallback, pause/hold lifecycle, and measured announcer leg costume")
	quit(0)

func _check_foot_alpha_cutoff() -> void:
	var image := Image.create(4, int(NpcActivity.ACTION_CANVAS_SIZE.y), false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var y := int(NpcActivity.ACTION_FEET_ROW) - 1
	for x in range(4):
		var alpha: float = [101.0, 102.0, 127.0, 128.0][x] / 255.0
		image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	var texture := ImageTexture.create_from_image(image)
	var sampler := Motion.new()
	var samples: PackedVector2Array = sampler._build_foot_samples(texture)
	sampler.free()
	assert(samples.size() == 1, "projected-foot sampler follows the live Sprite shader's 0.5 alpha-scissor cutoff, excluding alpha 101/102/127 and retaining 128")
	assert(samples[0].is_equal_approx(Vector2(1.5, float(image.get_height()) * 0.5 - float(y) - 0.5)), "alpha-128 source-foot edge retains its exact pixel-center sample")

func _check_motion_disabled_by_default() -> void:
	var scene:=Node3D.new(); root.add_child(scene)
	var controller=NpcActivity.new(); scene.add_child(controller)
	var anchor:=Node3D.new(); anchor.position=Vector3(1,0.055,-3); scene.add_child(anchor)
	var sprite:=Sprite3D.new(); var frames=NpcActivity.load_action_frames("ticket"); sprite.texture=frames[0]; sprite.pixel_size=0.01; anchor.add_child(sprite)
	assert(controller.register_actor(sprite,"ticket",frames,anchor),"default-disabled ticket actor registers")
	controller.finish_registration()
	var camera:=Camera3D.new(); scene.add_child(camera)
	controller.configure_motion(camera,Callable(self,"_ground_height"))
	var start:=anchor.position
	controller._process(24.0)
	assert(not controller.motion_report().enabled and controller._records[0].motion==null,"measured gait remains opt-in by default")
	assert(anchor.position.is_equal_approx(start) and sprite.visible,"default configuration preserves authored Sprite and does not create a route")
	controller.release(); scene.queue_free(); await process_frame

func _check_motion(role: String) -> void:
	var scene:=Node3D.new(); root.add_child(scene)
	var actor:=Node3D.new(); actor.position=Vector3(2,0.055,-4); scene.add_child(actor)
	var sprite:=Sprite3D.new(); sprite.pixel_size=0.01
	var front_frames:=NpcActivity.load_action_frames(role)
	sprite.texture=front_frames[0]; actor.add_child(sprite)
	var camera:=Camera3D.new(); camera.rotation_degrees.x=-18.0; scene.add_child(camera)
	var motion=Motion.new(); scene.add_child(motion)
	assert(motion.configure(actor,sprite,role,camera,Callable(self,"_boundary_ground_height")),"%s uses complete measured left/right gait records" % role)
	assert(motion.supported and motion.rig.source_records.size()==2,"%s rig covers exactly its measured two directions" % role)
	_check_measured_views_foot_contact(motion,role)
	assert(sprite.visible and not motion.rig.visible and not motion.active,"%s starts stationary with only its authored Sprite visible immediately after rig configuration" % role)
	var role_measurements: Dictionary=motion.source_provider.measurements_for(role)
	assert(motion.front_body_height_px>0 and motion.target_body_height_px==int(role_measurements.target_body_height_px),"%s front Sprite uses measured strong-alpha height and rig target metadata" % role)
	assert(absf(sprite.pixel_size-(float(motion.target_body_height_px)*motion.rig.PIXEL_SIZE/float(motion.front_body_height_px)))<0.000001,"%s pixel size is calculated from its measured front-body height without Node scaling" % role)
	assert(absf(actor.global_position.y-float(_ground_height(Vector2(actor.global_position.x,actor.global_position.z))))<0.00001,"%s calibrated source feet remain on the supplied world ground" % role)
	camera.rotation_degrees.x=-30.0; motion.update(1.0/60.0)
	var expected_foot_offset: float=(NpcActivity.ACTION_FEET_ROW-float(NpcActivity.ACTION_CANVAS_SIZE.y)*0.5)*sprite.pixel_size
	var expected_world_offset := camera.global_basis.y * expected_foot_offset + Vector3(0.0,sprite.pixel_size+motion.foot_clearance_y,0.0)
	var sprite_parent := sprite.get_parent() as Node3D
	var expected_local_offset := sprite_parent.global_basis.inverse() * expected_world_offset
	_expect(sprite.position.distance_to(expected_local_offset)<0.00001 and sprite.global_position.distance_to(sprite_parent.global_position+expected_world_offset)<0.00001 and absf(actor.global_position.y-0.055)<0.00001,"%s entire projected source-foot anchor follows camera up in world XYZ without moving its actor root off terrain" % role)
	_expect(motion.foot_clearance_y>0.08,"%s raises the projected contact silhouette where plaza ground is higher than its lawn root" % role)
	_check_contact_pixels(motion,sprite,camera,Callable(self,"_boundary_ground_height"),role+" direct root")
	var nested:=Node3D.new(); nested.position=Vector3(0.23,0.14,-0.17); nested.rotation.y=0.19; actor.add_child(nested)
	actor.remove_child(sprite); nested.add_child(sprite)
	motion._sync_front_ground_anchor()
	var ground_origin := Vector3(actor.global_position.x,0.055,actor.global_position.z)
	var expected_nested_center := ground_origin + camera.global_basis.y*expected_foot_offset + Vector3(0.0,1.0*sprite.pixel_size+motion.foot_clearance_y,0.0)
	_expect(sprite.global_position.distance_to(expected_nested_center)<0.00002,"%s nested rotated anchor converts the full world foot offset through its parent transform" % role)
	_check_contact_pixels(motion,sprite,camera,Callable(self,"_boundary_ground_height"),role+" nested anchor")
	nested.remove_child(sprite); actor.add_child(sprite); actor.remove_child(nested); nested.queue_free()
	var original_sprite_size := 0.01
	var original_sprite_y := 0.0
	motion.set_enabled(true)
	var before_root:=actor.global_position
	actor.position.x+=0.10
	motion.update(1.0/60.0)
	assert(actor.global_position.x-before_root.x>0.099,"%s actor route supplies a real root displacement" % role)
	var seeded_phase: float=motion.rig._stride(false)*0.3
	assert(absf(motion.rig.travel-(seeded_phase+0.10))<0.002,"%s gait phase adds actual root displacement once after its documented startup phase" % role)
	assert(motion.rig.direction=="right" and motion.rig.visible and not sprite.visible,"%s shows only the measured side-view rig while moving right" % role)
	assert(is_zero_approx(motion.rig.position.x) and is_zero_approx(motion.rig.position.z),"%s rig never applies a second world translation" % role)
	for _tick in range(20): motion.update(1.0/60.0)
	assert(not motion.active and sprite.visible and not motion.rig.visible and motion.rig.blend<0.08,"%s settles and restores its authored Sprite without double-rendering after the route stops" % role)
	actor.position.x+=0.09; motion.update(1.0/60.0)
	assert(motion.active and motion.rig.travel>0.08,"%s resumes from actual post-pause distance" % role)
	motion.set_paused(true)
	var frozen_travel: float=motion.rig.travel
	actor.position.x+=0.4
	motion.update(1.0/60.0,false,true)
	assert(not motion.active and sprite.visible and not motion.rig.visible and is_equal_approx(motion.rig.travel,0.0),"%s real pause hides candidate rig and cancels its walk contacts" % role)
	motion.set_paused(false)
	actor.position.x+=0.025; motion.update(1.0/60.0)
	assert(motion.active and absf(motion.rig.travel-(motion.rig._stride(false)*0.3+0.025))<0.002,"%s resumes without a teleport burst" % role)
	var held_travel: float=motion.rig.travel
	var held_position:=actor.global_position
	motion.update(1.0/60.0,true)
	assert(is_equal_approx(motion.rig.travel,held_travel) and actor.global_position.is_equal_approx(held_position),"%s dialogue hold freezes the actual root and gait while leaving the caller's authored action available" % role)
	assert(sprite.visible and not motion.rig.visible,"%s dialogue hold exposes only the authored close-up sprite" % role)
	motion.set_paused(true); motion.set_paused(false)
	actor.position.x+=0.55/60.0; motion.update(1.0/60.0)
	assert(motion.active and not sprite.visible and motion.rig.direction=="right","%s measured gait also activates at 0.55 m/s careful-walk displacement at 60 Hz" % role)
	motion.set_paused(true)
	motion.close()
	assert(is_equal_approx(sprite.pixel_size,original_sprite_size) and is_equal_approx(sprite.position.y,original_sprite_y),"%s close restores the caller's original front Sprite scale and local position" % role)
	motion.queue_free(); scene.queue_free()
	await process_frame

func _check_unmeasured_role_fallback() -> void:
	var scene:=Node3D.new(); root.add_child(scene)
	var actor:=Node3D.new(); scene.add_child(actor)
	var sprite:=Sprite3D.new(); actor.add_child(sprite)
	var motion=Motion.new(); scene.add_child(motion)
	assert(not motion.configure(actor,sprite,"unmeasured-role",null,Callable(self,"_ground_height")),"a role without approved measured source cannot create a gait")
	assert(not motion.supported and motion.rig==null and not motion.diagnostics.is_empty(),"missing role ownership is an explicit sprite fallback, not motion coverage")
	assert(sprite.visible,"original sprite remains visible without a verified gait source")
	motion.close(); motion.queue_free(); scene.queue_free(); await process_frame

func _check_detached_rig_close() -> void:
	var scene:=Node3D.new(); root.add_child(scene)
	var actor:=Node3D.new(); scene.add_child(actor)
	var sprite:=Sprite3D.new(); sprite.texture=NpcActivity.load_action_frames("announcer")[0]; actor.add_child(sprite)
	var camera:=Camera3D.new(); scene.add_child(camera)
	var motion=Motion.new(); scene.add_child(motion)
	assert(motion.configure(actor,sprite,"announcer",camera,Callable(self,"_ground_height")),"announcer motion rig configures before detached-close regression")
	var detached_rig=motion.rig
	actor.remove_child(detached_rig)
	motion.close()
	var resources: Dictionary=detached_rig.resource_counts()
	assert(detached_rig._closed and detached_rig.source_records.is_empty() and int(resources.directions)==0 and int(resources.avatar_cache)==0,"closing an already-detached rig releases measured records/cache without evaluating global transforms")
	motion.queue_free(); detached_rig.queue_free(); scene.queue_free(); await process_frame

func _check_announcer_costume() -> void:
	var library=Library.new()
	var costume=Costume.new()
	var checked:=0
	var changed_total:=0
	var covered_actions:=0
	var coverage: Dictionary=library.coverage_report().get("announcer",{})
	for action in coverage.keys():
		var directions: Array=coverage[action]
		if not directions.has("front"): continue
		var sequence: Dictionary=library.get_sequence("announcer",String(action),"front")
		if not bool(sequence.get("available",false)): continue
		covered_actions+=1
		for frame: Dictionary in sequence.frames:
			var source_texture: Texture2D=frame.texture
			var before: Image=source_texture.get_image().duplicate()
			var result: Dictionary=costume.decorate(source_texture)
			assert(costume.cache_size()<=48,"announcer costume cache remains bounded to 48 source frames")
			if not bool(result.valid): continue
			checked+=1; changed_total+=int(result.changed)
			var after: Image=(result.texture as Texture2D).get_image()
			var mask: Array[Dictionary]=costume._lower_leg_components(before)
			assert(mask.size()==2,"%s front frame has exactly two measured connected warm-skin lower legs" % String(action))
			for y in range(before.get_height()):
				for x in range(before.get_width()):
					var src:=before.get_pixel(x,y); var dst:=after.get_pixel(x,y)
					assert(is_equal_approx(src.a,dst.a),"announcer pants preserve source alpha on every frame")
					if y<int(before.get_height()*0.78): assert(src==dst,"announcer face, hair, hat, coat and upper body pixels remain exact")
					if src!=dst:
						var allowed:=false
						for component: Dictionary in mask:
							var pixels: PackedInt32Array=component.pixels
							if pixels.has(y*before.get_width()+x): allowed=true; break
						assert(allowed,"announcer pants only recolor measured leg-component pixels")
	assert(covered_actions>0,"announcer has authored front actions available for costume checks")
	assert(checked>=4 and changed_total>=200,"at least four front poses expose paired measured legs suitable for the trouser/cuff decorator")
	assert(costume.cache_size()<=48,"announcer costume cache remains bounded after all covered front actions")
	print("ANNOUNCER_COSTUME checked=%d actions=%d changed=%d cache=%d" % [checked,covered_actions,changed_total,costume.cache_size()])

func _check_activity_integration() -> void:
	var scene:=Node3D.new(); root.add_child(scene)
	var controller=NpcActivity.new(); scene.add_child(controller)
	var actors: Dictionary={}; var anchors: Dictionary={}; var points: Dictionary={}; var materials: Dictionary={}
	for role in ["ticket","imp","announcer"]:
		var anchor:=Node3D.new(); anchor.position=Vector3(0,0.055,-3 if role=="ticket" else -6); scene.add_child(anchor)
		var sprite:=Sprite3D.new(); var fallback=NpcActivity.load_action_frames(role); sprite.texture=fallback[0]; sprite.pixel_size=0.01
		var material:=ShaderMaterial.new(); material.shader=load("res://game/world/living_sprite.gdshader")
		material.set_shader_parameter("texture_albedo",sprite.texture); material.set_shader_parameter("uv_rect",Vector4(0,0,1,1)); material.set_shader_parameter("motion",0.7)
		sprite.material_override=material; anchor.add_child(sprite)
		var point={"position":anchor.global_position}
		assert(controller.register_actor(sprite,role,fallback,anchor,point,0.0),"%s activity actor registers" % role)
		actors[role]=sprite; anchors[role]=anchor; points[role]=point; materials[role]=material
	controller.finish_registration()
	var camera:=Camera3D.new(); scene.add_child(camera)
	controller.configure_motion(camera,Callable(self,"_ground_height"),true)
	var report: Dictionary=controller.motion_report()
	assert(report.supported_roles.has("ticket") and report.supported_roles.has("imp") and report.supported_roles.has("announcer"),"integrated activity enables only the three measured two-view walk sets")
	assert(report.sprite_fallback_roles.is_empty(),"all three NPC roles use measured left/right sources when metadata is valid")
	for role in ["ticket","imp","announcer"]:
		var index:=_record_index_by_role(controller,role)
		var record: Dictionary=controller._records[index]
		var motion: Variant=record.motion
		assert(record.target.get_ref().visible and not motion.rig.visible and not motion.active,"%s remains on its authored Sprite and keeps the gait rig hidden at initial stationary rest" % role)
	for role in ["ticket","imp"]:
		var record_index:=_record_index_by_role(controller,role)
		var record: Dictionary=controller._records[record_index]
		record.route_phase=0.0; record.route_clock=0.0; controller._records[record_index]=record
	var ticket_start: Vector3=anchors.ticket.position
	var imp_start: Vector3=anchors.imp.position
	controller._process(1.0)
	assert(anchors.ticket.position.distance_to(ticket_start)>0.24 and anchors.ticket.position.distance_to(ticket_start)<0.26,"ticket short route uses its measured 0.25m path radius")
	assert(anchors.imp.position.distance_to(imp_start)>0.34 and anchors.imp.position.distance_to(imp_start)<0.36,"imp short route uses its measured 0.35m path radius")
	assert(not actors.ticket.visible and not actors.imp.visible and controller._records[_record_index_by_role(controller,"ticket")].motion.rig.visible and controller._records[_record_index_by_role(controller,"imp")].motion.rig.visible,"only source-valid actors switch to visible measured rigs during movement")
	assert(points.ticket.position.is_equal_approx(anchors.ticket.global_position) and points.imp.position.is_equal_approx(anchors.imp.global_position),"interaction points follow the physical route anchors")
	var ticket_record: Dictionary=controller._records[_record_index_by_role(controller,"ticket")]
	assert(controller.greet(actors.ticket,"front"),"dialogue greeting uses the existing authored action sequence")
	controller.set_dialogue_hold(true)
	controller.set_activity_paused(false)
	var held_root: Vector3=anchors.ticket.position
	var held_elapsed:=float(ticket_record.action_elapsed)
	controller._process(0.25)
	ticket_record=controller._records[_record_index_by_role(controller,"ticket")]
	assert(anchors.ticket.position.is_equal_approx(held_root),"dialogue hold freezes the route while action animation is allowed to advance")
	assert(float(ticket_record.action_elapsed)>held_elapsed,"dialogue hold keeps the in-progress authored greeting alive")
	assert(actors.ticket.visible and not controller._records[_record_index_by_role(controller,"ticket")].motion.rig.visible,"dialogue hold restores the current authored sprite for close interaction without showing the gait rig")
	controller.set_dialogue_hold(false)
	controller.set_activity_paused(true)
	var paused_root: Vector3=anchors.ticket.position
	var paused_elapsed:=float(ticket_record.action_elapsed)
	controller._process(1.0)
	ticket_record=controller._records[_record_index_by_role(controller,"ticket")]
	assert(anchors.ticket.position.is_equal_approx(paused_root) and is_equal_approx(float(ticket_record.action_elapsed),paused_elapsed),"real modal pause freezes both route and authored pose time")
	assert(is_zero_approx(float(materials.ticket.get_shader_parameter("motion"))),"real pause suppresses shader breathing instead of letting global TIME continue it")
	controller.set_activity_paused(false)
	assert(is_equal_approx(float(materials.ticket.get_shader_parameter("motion")),0.7),"resuming restores the original shader motion strength")
	controller.set_reduced_motion(true)
	var reduced_root: Vector3=anchors.imp.position
	controller._process(1.0)
	assert(anchors.imp.position.is_equal_approx(reduced_root) and is_zero_approx(float(materials.imp.get_shader_parameter("motion"))),"reduced motion freezes root movement and shader breathing")
	for role in ["ticket","imp","announcer"]:
		var index:=_record_index_by_role(controller,role)
		assert(actors[role].visible and not controller._records[index].motion.rig.visible,"reduced motion shows only the authored Sprite for %s" % role)
	var announcer_record: Dictionary=controller._records[_record_index_by_role(controller,"announcer")]
	assert(actors.announcer.texture==announcer_record.baseline_texture and materials.announcer.get_shader_parameter("texture_albedo")==announcer_record.baseline_shader_texture,"reduced motion retains the same bounded measured trouser treatment on announcer rest texture")
	controller.set_reduced_motion(false)
	assert(is_equal_approx(float(materials.imp.get_shader_parameter("motion")),0.7),"disabling reduced motion restores the prior shader value")
	controller.configure_motion(camera,Callable(self,"_ground_height"),false)
	for role in ["ticket","imp","announcer"]:
		assert(actors[role].visible and is_equal_approx(actors[role].pixel_size,0.01) and is_equal_approx(anchors[role].position.y,0.055),"disabling optional gait restores the registered source Sprite scale and ground anchor for %s" % role)
	controller.release()
	assert(controller.costume_report().cache_size<=48,"controller-owned announcer texture cache remains bounded")
	scene.queue_free(); await process_frame

func _check_announcer_natural_rest_at_30hz() -> void:
	var scene := Node3D.new(); root.add_child(scene)
	var controller = NpcActivity.new(); scene.add_child(controller)
	var actor := Node3D.new(); actor.position = Vector3(2.0, 0.055, -4.0); scene.add_child(actor)
	var sprite := Sprite3D.new(); sprite.texture = NpcActivity.load_action_frames("announcer")[0]; actor.add_child(sprite)
	var point := {"position": actor.global_position}
	assert(controller.register_actor(sprite, "announcer", NpcActivity.load_action_frames("announcer"), actor, point, 0.0), "30 Hz natural-rest regression registers the real announcer controller")
	controller.finish_registration()
	var camera := Camera3D.new(); scene.add_child(camera)
	controller.configure_motion(camera, Callable(self, "_ground_height"), true)
	var index := _record_index_by_role(controller, "announcer")
	var motion: Variant = controller._records[index].motion
	assert(motion != null and motion.supported, "30 Hz natural-rest regression uses the measured announcer gait adapter")
	assert(controller._play_actor_action(index, "walk", "right", true), "announcer begins from its authored route walk")
	actor.position.x += 0.02
	motion.update(1.0 / 30.0)
	assert(motion.active and not sprite.visible, "announcer source sprite is replaced by the gait rig while route movement is active")
	controller._action_clock = 1.0
	var sample_delta := 1.0 / 30.0
	var observed_natural_rest := false
	var action_index := 0
	var actions := ["greet", "interact"]
	var action_started_at := -1.0
	var action_durations := {}
	controller._ensure_animation_library()
	for action in actions:
		var sequence: Dictionary = controller._animation_library.get_sequence("announcer", action, "front")
		var frames: Array = sequence.get("frames", [])
		assert(bool(sequence.get("available", false)) and not frames.is_empty(), "30 Hz completion regression loads the authored announcer %s sequence" % action)
		action_durations[action] = float(frames.size()) / maxf(0.01, float(sequence.get("fps", 1.0)))
	for _sample in range(30 * 9):
		controller._action_clock += sample_delta
		controller._update_announcer_action(controller._records[index])
		var current: Dictionary = controller._records[index]
		controller._advance_actor(current, sprite, sample_delta, true)
		motion.update(sample_delta)
		current = controller._records[index]
		var phase := fposmod(float(controller._action_clock), NpcActivity.CYCLE_SECONDS)
		if action_index < actions.size() and action_started_at < 0.0 and _is_announcer_natural_rest_sample(String(current.action), bool(motion.active), bool(sprite.visible), bool(motion.rig.visible), phase):
			observed_natural_rest = true
			var action := String(actions[action_index])
			var required_remaining := float(action_durations[action]) + NpcActivity.ANNOUNCER_STOP_SETTLE_SECONDS
			var first_rest := phase < NpcActivity.ANNOUNCER_FIRST_REST_END
			var rest_end := NpcActivity.ANNOUNCER_FIRST_REST_END if first_rest else NpcActivity.ANNOUNCER_SECOND_REST_END
			if rest_end - phase >= required_remaining:
				assert(controller.request_action(sprite, action, "front"), "natural 30 Hz rest accepts the complete authored announcer %s action" % action)
				action_started_at = float(controller._action_clock)
		elif action_index < actions.size() and action_started_at >= 0.0:
			current = controller._records[index]
			var action := String(actions[action_index])
			if String(current.action) != action:
				var elapsed := float(controller._action_clock) - action_started_at
				assert(elapsed + sample_delta >= float(action_durations[action]), "30 Hz natural route rest allows authored %s to finish before its next route walk" % action)
				action_index += 1
				action_started_at = -1.0
				if action_index >= actions.size(): break
	assert(observed_natural_rest, "30 Hz samples observe the announcer's real source-sprite rest after the measured rig's 0.24s stop settle within a natural route-rest window")
	assert(action_index == actions.size(), "30 Hz natural rest test completes both authored announcer actions before the scheduler resumes walking")
	controller.release(); motion.close(); scene.queue_free(); await process_frame

func _is_announcer_natural_rest_sample(action: String, motion_active: bool, sprite_visible: bool, rig_visible: bool, phase: float) -> bool:
	var first_rest := phase >= NpcActivity.ANNOUNCER_OUTBOUND_SECONDS and phase < NpcActivity.ANNOUNCER_FIRST_REST_END
	var second_rest := phase >= NpcActivity.ANNOUNCER_RETURN_SECONDS and phase < NpcActivity.ANNOUNCER_SECOND_REST_END
	var rest_action := action in ["idle", "stand", "special", "emotion_curious"]
	return not motion_active and sprite_visible and not rig_visible and rest_action and (first_rest or second_rest)

func _record_index_by_role(controller, role: String) -> int:
	for index in range(controller._records.size()):
		if String(controller._records[index].role)==role: return index
	return -1

func _ground_height(_point: Vector2) -> float:
	return 0.055

func _boundary_ground_height(point: Vector2) -> float:
	# A measured actor remains on the lawn at z=-4 while a narrow raised plaza
	# lip begins along the tilted billboard's projected contact footprint.
	if point.x>1.5 and point.x<3.5 and point.y > -3.9995 and point.y < -3.75:
		return 0.18
	return 0.055

func _check_contact_pixels(motion, sprite: Sprite3D, camera: Camera3D, ground: Callable, label: String) -> void:
	var texture_image := sprite.texture.get_image()
	var up := camera.global_basis.y.normalized()
	var right := camera.global_basis.x.normalized()
	var root_ground := float(ground.call(Vector2(motion.actor_root.global_position.x,motion.actor_root.global_position.z)))
	var origin := Vector3(motion.actor_root.global_position.x,root_ground,motion.actor_root.global_position.z) + up*((float(NpcActivity.ACTION_FEET_ROW)-float(NpcActivity.ACTION_CANVAS_SIZE.y)*0.5)*sprite.pixel_size) + Vector3(0.0,sprite.pixel_size+motion.foot_clearance_y,0.0)
	var checked := 0
	for y in range(maxi(0,NpcActivity.ACTION_FEET_ROW-8),texture_image.get_height()):
		for x in range(texture_image.get_width()):
			if texture_image.get_pixel(x,y).a<0.5: continue
			var local_pixel := Vector2(float(x)+0.5-float(texture_image.get_width())*0.5,float(texture_image.get_height())*0.5-float(y)-0.5)
			var point := origin + right*(local_pixel.x*sprite.pixel_size) + up*(local_pixel.y*sprite.pixel_size)
			_expect(point.y+0.00001>=float(ground.call(Vector2(point.x,point.z))),"%s opaque foot pixel (%d,%d) clears its actual sampled ground" % [label,x,y])
			checked+=1
	_expect(checked>4,"%s checks all actual nontransparent foot-band pixels rather than quad bounds" % label)

func _check_terrain_contact(role: String, position: Vector3, pitch: float) -> void:
	var scene:=Node3D.new(); root.add_child(scene)
	var actor:=Node3D.new(); actor.position=position; scene.add_child(actor)
	var sprite:=Sprite3D.new(); sprite.texture=NpcActivity.load_action_frames(role)[0]; sprite.pixel_size=0.01; actor.add_child(sprite)
	var camera:=Camera3D.new(); camera.rotation_degrees=Vector3(pitch,27.0,0.0); scene.add_child(camera)
	var motion=Motion.new(); scene.add_child(motion)
	assert(motion.configure(actor,sprite,role,camera,Callable(self,"_park_ground_height")),"%s configures on an authored lawn/plaza/ramp height query" % role)
	motion._sync_front_ground_anchor()
	_check_contact_pixels(motion,sprite,camera,Callable(self,"_park_ground_height"),"%s actual-terrain %.2f-degree view" % [role,pitch])
	motion.close(); motion.queue_free(); scene.queue_free(); await process_frame

func _park_ground_height(point: Vector2) -> float:
	return ParkWorld._ground_surface_y(Vector3(point.x,0.0,point.y))

func _x_boundary_ground_height(point: Vector2) -> float:
	return 0.18 if point.x<0.0 else 0.055

func _check_measured_views_foot_contact(motion, role: String) -> void:
	var scene := Node3D.new(); root.add_child(scene)
	var camera := Camera3D.new(); scene.add_child(camera)
	var actor_position := Vector3(0.05,0.055,-4.0)
	var source_ground := Callable(self,"_x_boundary_ground_height")
	for view in ["left","right"]:
		var record: Dictionary = motion.rig.source_records[view]
		var source: Image = record.get("source") as Image
		_expect(bool(record.get("valid",false)) and source!=null and source.get_size()==Vector2i(280,360),"%s/%s measured two-view source retains its verified normalized pixels and foot row" % [role,view])
		if source==null: continue
		for pitch in [-18.0,-30.0]:
			camera.rotation_degrees=Vector3(pitch,27.0,0.0)
			_check_source_image_contact(source,camera,actor_position,motion.rig.PIXEL_SIZE,346.0,360.0,source_ground,"%s/%s %.0f-degree measured view" % [role,view,pitch])
	scene.queue_free(); await process_frame

func _check_source_image_contact(image: Image, camera: Camera3D, root_position: Vector3, pixel_size: float, feet_row: float, canvas_height: float, ground: Callable, label: String) -> void:
	var up := camera.global_basis.y.normalized()
	var right := camera.global_basis.x.normalized()
	var root_ground := float(ground.call(Vector2(root_position.x,root_position.z)))
	var foot_offset := (feet_row-canvas_height*0.5)*pixel_size
	var required := 0.0
	for y in range(maxi(0,int(feet_row)-8),image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x,y).a<0.5: continue
			var pixel := Vector2(float(x)+0.5-float(image.get_width())*0.5,float(image.get_height())*0.5-float(y)-0.5)
			var point := Vector3(root_position.x,root_ground,root_position.z)+up*(foot_offset+pixel.y*pixel_size)+right*(pixel.x*pixel_size)
			required=maxf(required,float(ground.call(Vector2(point.x,point.z)))-point.y+pixel_size)
	var origin := Vector3(root_position.x,root_ground,root_position.z)+up*foot_offset+Vector3(0.0,pixel_size+maxf(0.0,required),0.0)
	var checked:=0
	for y in range(maxi(0,int(feet_row)-8),image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x,y).a<0.5: continue
			var pixel := Vector2(float(x)+0.5-float(image.get_width())*0.5,float(image.get_height())*0.5-float(y)-0.5)
			var point := origin+right*(pixel.x*pixel_size)+up*(pixel.y*pixel_size)
			_expect(point.y+0.00001>=float(ground.call(Vector2(point.x,point.z))),"%s source alpha pixel (%d,%d) clears its sampled edge" % [label,x,y])
			checked+=1
	_expect(checked>4,"%s checks a nonempty measured foot-pixel band" % label)

func _expect(condition: bool, message: String) -> void:
	if condition: return
	_foot_test_failures+=1
	if _foot_test_failures<=5: push_error(message)
