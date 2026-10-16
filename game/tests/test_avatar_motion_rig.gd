extends SceneTree
const Rig = preload("res://game/world/avatar_motion_rig.gd")

class IncompleteHero extends Rig:
	var fail_front := true
	func _source_for(view: String) -> Dictionary:
		# Exercise real prepare_source -> rebuild_sources -> _ready with
		# unchanged authored RGBA and one invalid measured source record.
		var entry: Dictionary = _metadata.roles.hero.directions.front
		if fail_front: entry["invalid"] = "fixture: measured front source unavailable"
		else: entry.erase("invalid")
		return super._source_for(view)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if OS.get_cmdline_user_args().has("--world-reach-audit"):
		await _world_reach_audit()
		return
	await _assert_incomplete_hero_recovery()
	if OS.get_cmdline_user_args().has("--invalid-source-only"):
		print("PASS: real Hero ready/source fallback and rebuild recovery")
		quit()
		return
	var rig := Rig.new()
	root.add_child(rig)
	await process_frame
	assert(rig.source_records.size()==8)
	assert(absf(rig._stride(false)-0.60)<0.000001,"source-sized Hero walk cycle reduces cadence without changing caller speed")
	assert(absf(rig._stride(true)-1.40)<0.000001,"run retains its original world-distance cycle")
	var outline: StandardMaterial3D = rig._materials[0].next_pass
	assert(outline!=null,"source-style legs require the cached inverted-hull pass")
	assert(outline==rig._materials[1].next_pass,"both legs share one outline resource")
	assert(outline.grow and outline.cull_mode==BaseMaterial3D.CULL_FRONT)
	assert(outline.shading_mode==BaseMaterial3D.SHADING_MODE_PER_PIXEL and not outline.no_depth_test)
	assert(outline.albedo_texture==null and outline.next_pass==null and outline.albedo_color.a==1.0)
	assert(outline.grow_amount>0.0 and outline.grow_amount<=Rig.PIXEL_SIZE*0.35)
	assert(absf(rig.upper_bone_length+rig.lower_bone_length-0.3740643274853801)<0.000001,"actual Hero binds one fixed median source-pivot chain")
	var vertices := Rig.bind_vertices()
	for view in Rig.DIRECTIONS:
		var record: Dictionary = rig.source_records[view]
		assert(record.valid,"every supplied direction must validate; fallback is not eight-direction acceptance: "+record.get("reason",""))
		var source: Image = record.source
		var upper: Image = record.upper
		if view=="front": assert(record.boot_image.get_pixel(142,310).a==0,"primary front boot must exclude the other leg's vertical shaft edge")
		if OS.get_cmdline_user_args().has("--audit"):
			source.save_png("res://.review/motion-source-"+view+".png")
			upper.save_png("res://.review/motion-upper-"+view+".png")
			record.boot_image.save_png("res://.review/motion-boot-"+view+".png")
			rig._renderer._walk_pose_image(view,rig._renderer.walk_idle_frame(view)).save_png("res://.review/motion-raw-"+view+".png")
			print(view, " hips=",record.hips," boxes=",record.lower)
		var first_owned := 360
		for box: Array in record.limb_envelopes: first_owned = mini(first_owned,int(box[1]))
		for y in range(first_owned):
			for x in range(280): assert(source.get_pixel(x,y)==upper.get_pixel(x,y),"head/face/camera source bytes cannot change")
		# All untouched source pixels outside explicit ownership remain exact.
		for y in range(360):
			for x in range(280):
				var owned := false
				for box: Array in record.lower:
					if Rig.rectangle(box).grow(1).has_point(Vector2i(x,y)): owned = true
				if record.limb_mask[y*280+x]!=0: owned = true
				if not owned: assert(source.get_pixel(x,y)==upper.get_pixel(x,y),"garments/bag outside limb ownership cannot be cut")
		# Exhaustive source silhouette audit extends beyond guessed old boot boxes.
		var raw: Image = rig._renderer._walk_pose_image(view,rig._renderer.walk_idle_frame(view))
		for leg in range(2):
			var envelope := Rig.rectangle(record.limb_envelopes[leg])
			var below_hem := int(record.lower[leg][1])+6
			for y in range(below_hem,envelope.end.y):
				for x in range(envelope.position.x,envelope.end.x):
					if raw.get_pixel(x,y).a>0.63 and record.garment_mask[y*280+x]==0:
						assert(upper.get_pixel(x,y).a==0,"%s x=%d y=%d full source limb/shaft/outline silhouette must be removed, including outside old crops" % [view,x,y])
		for y in range(360):
			for x in range(280):
				if record.garment_mask[y*280+x]!=0 and source.get_pixel(x,y).a>0.63: assert(upper.get_pixel(x,y)==source.get_pixel(x,y),"connected true garment pixels remain byte exact")
		if view=="right":
			for witness in [Vector2i(105,286),Vector2i(109,289),Vector2i(166,289)]:
				assert(source.get_pixelv(witness).a>0.63 and upper.get_pixelv(witness).a==0,"root-observed shaft fragments outside guessed boot rectangle must disappear")
		for box_index in range(2,record.lower.size()):
			var old_boot := Rig.rectangle(record.lower[box_index])
			for y in range(old_boot.position.y,old_boot.end.y):
				for x in range(old_boot.position.x,old_boot.end.x):
					if record.garment_mask[y*280+x]==0: assert(upper.get_pixel(x,y).a==0,"no legacy shoe, glint or sole fragment survives under the hem")
					if y>=old_boot.position.y+12: assert(upper.get_pixel(x,y).a==0,"lower original shoe area must be empty regardless of cream classification")
		if not record.external_boot:
			var box: Rect2i = record.boot_rect
			for y in range(box.position.y+12,box.end.y):
				for x in range(box.position.x,box.end.x):
					var excluded := false
					for exclusion: Array in record.boot_exclusions:
						if Rig.rectangle(exclusion).has_point(Vector2i(x,y)): excluded = true
					if source.get_pixel(x,y).a>0.63 and not excluded:
						assert(record.boot_image.get_pixel(x,y)==source.get_pixel(x,y),"complete original lower boot/heel/toe/sole pixels retained")
		var forward := Rig.forward_for(view)
		var lateral := Vector3(forward.z,0,-forward.x)
		for projection: Basis in [Basis.IDENTITY,Transform3D.IDENTITY.looking_at(Vector3(-3.5,-15.5,-25),Vector3.UP).basis]:
			for run in [false,true]:
				for leg in range(2):
					for index in range(256):
						var distance := index/256.0*Rig.stride(run)
						var phase := fposmod(distance/Rig.stride(run)+leg*0.5,1.0)
						var offset := Rig.foot_offset(distance,leg,run)
						var upper_basis := projection*Basis(Quaternion(lateral,-0.08 if run else 0.0))
						var anchor := upper_basis*Rig.hip_offset(record,leg)
						var side := Vector3(anchor.x,0,anchor.z)
						var root_position := forward*distance
						var bob := Rig.pelvis_bob(distance,run)
						var hip := root_position+anchor+Vector3(0,Rig.HIP_HEIGHT+bob,0)
						var foot := root_position+forward*offset.x+side+Vector3(0,offset.y,0)
						var ankle := foot+Vector3(0,record.ankle_height,0)
						var knee := Rig.solve_knee(hip,ankle,forward)
						assert(absf(hip.distance_to(knee)-Rig.UPPER_LENGTH)<0.00001)
						assert(absf(knee.distance_to(ankle)-Rig.LOWER_LENGTH)<0.00001)
						if phase<Rig.stance(run)-0.0001:
							var next_distance := distance+0.00001
							var next_offset := Rig.foot_offset(next_distance,leg,run)
							var next_foot := forward*next_distance+forward*next_offset.x+side+Vector3(0,next_offset.y,0)
							assert(foot.distance_to(next_foot)<0.000001,"actual world foot stays planted while root advances")
							assert(is_zero_approx(foot.y),"stance sole is exactly on ground")
						# Project the upper ring into the immutable garment plane. Actual
						# opaque shorts must overlap this skin tube at every gait phase.
						var garment_contacts := 0
						for ring in range(Rig.RING):
							var surface := Rig.surface_vertex(vertices[ring],hip,knee,ankle,upper_basis,record.hip_widths[leg]*Rig.PIXEL_SIZE)
							var local := upper_basis.inverse()*(surface-root_position-Vector3(0,Rig.HIP_HEIGHT+bob,0))
							var pixel := Vector2i(roundi(record.pelvis.x+local.x/Rig.PIXEL_SIZE),roundi(record.pelvis.y-local.y/Rig.PIXEL_SIZE))
							if pixel.x>=0 and pixel.x<280 and pixel.y>=0 and pixel.y<360 and upper.get_pixelv(pixel).a>0.63: garment_contacts += 1
						assert(garment_contacts>=4,"%s leg=%d phase=%d skin must penetrate actual opaque shorts" % [view,leg,index])
						var projected_min := INF
						var projected_max := -INF
						for ring in range(Rig.RING):
							var seam := upper_basis.inverse()*(Rig.surface_vertex(vertices[ring],hip,knee,ankle,upper_basis,record.hip_widths[leg]*Rig.PIXEL_SIZE)-hip)
							projected_min = minf(projected_min,record.hips[leg][0]+seam.x/Rig.PIXEL_SIZE)
							projected_max = maxf(projected_max,record.hips[leg][0]+seam.x/Rig.PIXEL_SIZE)
						assert(projected_min<=record.opening_spans[leg][0] and projected_max>=record.opening_spans[leg][1],"skin cuff covers the whole measured shorts opening")
						var points := PackedVector3Array()
						for vertex in vertices: points.append(Rig.surface_vertex(vertex,hip,knee,ankle,upper_basis,record.hip_widths[leg]*Rig.PIXEL_SIZE))
						var knee_center := Rig.surface_vertex(Vector3(0,-Rig.UPPER_LENGTH,0),hip,knee,ankle)
						assert(knee_center.distance_to(knee)<0.04,"soft knee bend encloses the physical joint rather than exposing a hard cap")
						assert(Rig.surface_vertex(Vector3(0,-Rig.UPPER_LENGTH-Rig.LOWER_LENGTH,0),hip,knee,ankle).distance_to(ankle)<0.000001)
						for row in range(Rig.ROWS.size()-1):
							for ring in range(Rig.RING):
								var next := (ring+1)%Rig.RING
								var a := points[row*Rig.RING+ring]
								var b := points[row*Rig.RING+next]
								var c := points[(row+1)*Rig.RING+ring]
								var d := points[(row+1)*Rig.RING+next]
								assert((b-a).cross(c-a).length()>0.00001 and (d-b).cross(c-b).length()>0.00001,"%s run=%s phase=%d row=%d ring=%d continuous knee surface" % [view,run,index,row,ring])
							var width := points[row*Rig.RING].distance_to(points[row*Rig.RING+Rig.RING/2])
							assert(width>0.028,"%s run=%s phase=%d row=%d width=%f leg cross section never collapses" % [view,run,index,row,width])
		rig.set_direction(view)
		rig.advance(0.5,0.55,false)
		rig.cancel_motion()
		assert(rig.speed==0 and rig.travel==0 and rig.blend==0,"cancellation resets phase and anchors")
		for foot in rig.foot_world: assert(is_zero_approx(foot.y))
		var boot: Sprite3D = rig._boots[0]
		var size: Vector2 = record.boot_image.get_size()
		var sole_y: float = boot.position.y-(record.sole-size.y*0.5)*boot.pixel_size
		assert(absf(sole_y)<0.000001,"actual Sprite3D strong sole edge shares the world ground plane")
	# Actual advance() contact locks, not only an algebraic foot model.
	for view in Rig.DIRECTIONS:
		rig.set_direction(view)
		for sprint in [false,true]:
			rig.cancel_motion()
			var previous := [Vector3.ZERO,Vector3.ZERO]
			var epochs := [-1,-1]
			var previous_contacts := [Vector3.ZERO,Vector3.ZERO]
			var previous_pivots := [Vector3.ZERO,Vector3.ZERO]
			var maximum_roll := 0.0
			for tick in range(256):
				rig.advance(1.0/120.0,2.0 if sprint else 0.55,sprint)
				for leg in range(2):
					_assert_rendered_sole(rig,leg)
					maximum_roll=maxf(maximum_roll,absf(rig._boot_roll[leg]))
					if rig.source_records[view].has("boot_floor_points"):
						for point: Vector2 in rig.source_records[view].boot_floor_points:
							var edge: Vector3 = rig.boot_contact_world[leg]+rig.global_basis*rig._boot_rotations[leg]*(Vector3(point.x,point.y,0)-rig._boot_contact_offset[leg])
							assert(edge.y>=-0.000001,"complete retained opaque boot contour cannot rotate below the flat contact plane")
					if rig._contact_valid[leg]:
						assert(absf(rig.foot_world[leg].y)<0.000001)
						if epochs[leg]==rig._contact_epoch[leg]:
							assert(rig.foot_world[leg].distance_to(previous[leg])<0.000001,"advance() original plant plane cannot slide")
							if previous_pivots[leg]==rig._boot_contact_offset[leg]: assert(rig.boot_contact_world[leg].distance_to(previous_contacts[leg])<0.000001,"actual source toe/heel anchor cannot slide during a planted pivot interval")
						previous[leg] = rig.foot_world[leg]
						previous_contacts[leg] = rig.boot_contact_world[leg]
						previous_pivots[leg] = rig._boot_contact_offset[leg]
						epochs[leg] = rig._contact_epoch[leg]
					else: epochs[leg] = -1
			for tick in range(240): rig.advance(1.0/120.0,0,sprint)
			if not sprint and (view=="right" or view=="left"): assert(maximum_roll>deg_to_rad(2.0),"actual side walk displays measured toe-off, not only a helper angle")
			assert(rig.speed==0 and rig.blend<0.001)
			for leg in range(2): assert(rig._boot_roll[leg]==0.0 and rig._boot_contact_offset[leg]==Vector3.ZERO,"stop settles actual foot rotation to original flat sole")
			for foot in rig.foot_world: assert(absf(foot.y)<0.000001,"stopping settles both soles to floor")
	assert(rig._upper.shaded and not rig._upper.no_depth_test,"upper obeys light and opaque world depth")
	for boot in rig._boots: assert(boot.shaded and not boot.no_depth_test,"boots obey light and depth")
	for material in rig._materials: assert(material.shading_mode==BaseMaterial3D.SHADING_MODE_PER_PIXEL and not material.no_depth_test)
	for chain in rig._legs:
		var format: int = chain[2].mesh.surface_get_format(0)
		assert(format & Mesh.ARRAY_FORMAT_NORMAL)
		assert(RenderingServer.mesh_surface_get_format_normal_tangent_stride(format,vertices.size())==8,"normal/tangent upload uses the supported surface stride")
		var buffer = chain[3]
		assert(buffer.bytes.size()==buffer.positions.size()*20)
		for index in range(buffer.normals.size()):
			assert(absf(buffer.normals[index].length()-1.0)<0.00001,"deformed surface normal is normalized")
			var offset: int = buffer.positions.size()*12+index*8
			var decoded := Vector3.octahedron_decode(Vector2(buffer.bytes.decode_u16(offset)/65535.0,buffer.bytes.decode_u16(offset+2)/65535.0))
			assert(decoded.dot(buffer.normals[index])>0.9999,"GPU octahedral normal bytes match current geometry")
	# Parent-driven production API matches standalone gait, never translates twice.
	var moved_parent := Node3D.new()
	root.add_child(moved_parent)
	var external := Rig.new()
	moved_parent.add_child(external)
	await process_frame
	rig.set_direction("right")
	external.set_direction("right")
	rig.running = false
	external.running = false
	for sprint in [false,true]:
		rig.cancel_motion()
		external.cancel_motion()
		for tick in range(240):
			var before := rig.global_position
			rig.advance(1.0/120.0,2.0 if sprint else 0.55,sprint)
			var actual_delta := rig.global_position-before
			moved_parent.global_position += actual_delta
			var own_position := external.position
			external.advance_from_motion(1.0/120.0,actual_delta,sprint)
			assert(external.position==own_position,"external motion API never performs translation")
			assert(absf(external.travel-rig.travel)<0.0001 and absf(external.speed-rig.speed)<0.0001 and absf(external.blend-rig.blend)<0.0001,"external and standalone gait follow same actual displacement tick%d run%s: travel %.8f/%.8f speed %.8f/%.8f blend %.8f/%.8f" % [tick,sprint,external.travel,rig.travel,external.speed,rig.speed,external.blend,rig.blend])
		# Blocked motion supplies zero, even when the controller intended to walk.
		var blocked_travel: float = external.travel
		for tick in range(60): external.advance_from_motion(1.0/120.0,Vector3.ZERO,sprint)
		assert(external.travel==blocked_travel and external.speed==0 and external.blend==0)
		for foot in external.foot_world: assert(absf(foot.y)<0.000001)
	external.cancel_motion()
	# Analog/collision-slide heading differs from unchanged right-facing art.
	var diagonal := Vector3(0.003,0,0.004)
	moved_parent.global_position += diagonal
	external.advance_from_motion(0.01,diagonal,false)
	var previous_travel: float = external.travel
	var planted_diagonal: Vector3 = external.foot_world[0]
	moved_parent.global_position += diagonal
	external.advance_from_motion(0.01,diagonal,false)
	assert(external.foot_world[0].distance_to(planted_diagonal)<0.000001,"actual analog heading retains its planted world foot")
	assert(absf(external.travel-previous_travel-0.005)<0.000001,"phase advances actual horizontal diagonal distance")
	assert(external.direction=="right" and (external.global_basis*external._motion_heading_local).distance_to(diagonal.normalized())<0.000001,"planting uses actual heading, not art quantization")
	# World relocation sets ground/camera and then art direction BEFORE motion API.
	for tick in range(60): external.advance_from_motion(1.0/120.0,Vector3.ZERO,false)
	assert(external._settling)
	moved_parent.global_position += Vector3(6.2,0.18,-50.0)
	external.projection_basis = Transform3D.IDENTITY.looking_at(Vector3(-3.5,-15.5,-25),Vector3.UP).basis
	external.set_direction("right")
	for foot in external.foot_world: assert(foot.distance_to(external.global_position)<1.0,"synchronous source application cannot reuse pre-teleport settled world feet")
	# Follow the actual ParkWorld ground sampler across ramp/deck boundaries.
	var world_script = load("res://game/world/park_world.gd")
	external.ground_height_provider = func(point: Vector2) -> float: return world_script._ground_surface_y(Vector3(point.x,0,point.y))
	moved_parent.global_position = Vector3(6.2,world_script._ground_surface_y(Vector3(6.2,0,-36.2)),-36.2)
	external.cancel_motion()
	external.set_direction("right")
	var ramp_contacts := [Vector3.ZERO,Vector3.ZERO]
	var ramp_contact_epochs := [-1,-1]
	var ramp_pivots := [Vector3.ZERO,Vector3.ZERO]
	for tick in range(400):
		var old_position := moved_parent.global_position
		moved_parent.position.x += 0.55/60.0
		moved_parent.position.y = world_script._ground_surface_y(moved_parent.global_position)
		external.projection_basis = Basis(Quaternion(Vector3.UP,sin(tick*0.01)*0.015))*Transform3D.IDENTITY.looking_at(Vector3(-3.5,-15.5,-25),Vector3.UP).basis
		# Preserve the real world's setter-before-motion ordering.
		external.set_direction("right")
		external.advance_from_motion(1.0/60.0,moved_parent.global_position-old_position,false)
		for leg in range(2):
			var source: Dictionary = external.source_records.right
			var boot: Sprite3D = external._boots[leg]
			var size: Vector2 = source.boot_image.get_size()
			var physical_ankle: Vector3 = boot.global_transform*Vector3((source.boot_center-size.x*0.5)*boot.pixel_size,(size.y*0.5-source.sole)*boot.pixel_size+source.ankle_height,-0.045*external.leg_length_scale)
			assert(external._legs[leg][0].global_position.distance_to(physical_ankle)<external.upper_bone_length+external.lower_bone_length,"ramp and camera changes remain within true fixed-bone reach")
			assert(physical_ankle.distance_to(external.to_global(external._pose_ankles[leg]))<0.00001,"ramp reach uses the actual source ankle after foot orientation")
			_assert_rendered_sole(external,leg)
			if external._contact_valid[leg]:
				assert(absf(external.foot_world[leg].y-world_script._ground_surface_y(external.foot_world[leg]))<0.00001,"real terrain original plant remains exactly grounded")
				assert(absf(external.boot_contact_world[leg].y-world_script._ground_surface_y(external.boot_contact_world[leg]))<0.00001,"active toe/heel grounds at its own terrain position, not the old ankle centre")
				if ramp_contact_epochs[leg]==external._contact_epoch[leg] and ramp_pivots[leg]==external._boot_contact_offset[leg]:
					assert(ramp_contacts[leg].distance_to(external.boot_contact_world[leg])<0.000001,"terrain and moving camera preserve actual active toe/heel world anchor")
				ramp_contacts[leg]=external.boot_contact_world[leg]
				ramp_contact_epochs[leg]=external._contact_epoch[leg]
				ramp_pivots[leg]=external._boot_contact_offset[leg]
			else: ramp_contact_epochs[leg]=-1
	assert(moved_parent.position.x>9 and moved_parent.position.y>0.5)
	for tick in range(60): external.advance_from_motion(1.0/60.0,Vector3.ZERO,false)
	external.projection_basis = Basis.IDENTITY
	external.set_direction("front")
	for foot in external.foot_world: assert(foot.distance_to(external.global_position)<1.0)
	# Actual .055 lawn -> .28 boardwalk edge with one low planted stance foot.
	moved_parent.global_position = Vector3(-10,world_script._ground_surface_y(Vector3(-10,0,13.4)),13.4)
	external.set_view_projection(Transform3D.IDENTITY.looking_at(Vector3(-3.5,-15.5,-25),Vector3.UP).basis,atan2(3.5,25),true)
	external.set_direction("back")
	var maximum_step_support := 0.0
	var step_feet := [Vector3.ZERO,Vector3.ZERO]
	var step_epochs := [-1,-1]
	for tick in range(150):
		var old_position := moved_parent.global_position
		moved_parent.position.z -= 0.55/60.0
		moved_parent.position.y = world_script._ground_surface_y(moved_parent.global_position)
		external.set_direction("back")
		external.advance_from_motion(1.0/60.0,moved_parent.global_position-old_position,false)
		assert(external.first_reach_failure.is_empty(),"boardwalk edge must support fixed bones and actual world plants")
		_assert_runtime_surface(external)
		maximum_step_support = maxf(maximum_step_support,external.support_drop)
		for leg in range(2):
			if external._contact_valid[leg]:
				if step_epochs[leg]==external._contact_epoch[leg]: assert(external.foot_world[leg].distance_to(step_feet[leg])<0.000001,"up-step keeps old stance foot on its actual low ground")
				step_feet[leg] = external.foot_world[leg]
				step_epochs[leg] = external._contact_epoch[leg]
			else: step_epochs[leg] = -1
	assert(maximum_step_support>0.08,"high step requires an actual shared waist support change")
	for tick in range(60): external.advance_from_motion(1.0/60.0,Vector3.ZERO,false)
	external.set_direction("front")
	step_epochs = [-1,-1]
	for tick in range(150):
		var old_position := moved_parent.global_position
		moved_parent.position.z += 0.55/60.0
		moved_parent.position.y = world_script._ground_surface_y(moved_parent.global_position)
		external.set_direction("front")
		external.advance_from_motion(1.0/60.0,moved_parent.global_position-old_position,false)
		assert(external.first_reach_failure.is_empty(),"down-step never stretches fixed bones")
		_assert_runtime_surface(external)
		for leg in range(2):
			if external._contact_valid[leg]:
				if step_epochs[leg]==external._contact_epoch[leg]: assert(external.foot_world[leg].distance_to(step_feet[leg])<0.000001,"down-step keeps old stance foot on its actual high ground")
				step_feet[leg] = external.foot_world[leg]
				step_epochs[leg] = external._contact_epoch[leg]
			else: step_epochs[leg] = -1
	# An unreported parent teleport cancels stale world foot anchors safely.
	moved_parent.global_position += Vector3(10,0,0)
	moved_parent.position.y = world_script._ground_surface_y(moved_parent.global_position)
	external.advance_from_motion(0.01,Vector3.ZERO,false)
	assert(external.travel==0 and external.speed==0 and external.blend==0)
	for foot in external.foot_world: assert(foot.distance_to(external.global_position)<1.0)
	# A zero-time relocation cannot leave the old planted pose behind.
	moved_parent.global_position += diagonal
	external.advance_from_motion(0,diagonal,false)
	assert(external.speed==0 and external.travel==0)
	for foot in external.foot_world: assert(foot.distance_to(external.global_position)<1.0)
	external.cleanup()
	moved_parent.queue_free()
	await process_frame
	# Visible shoulder movement is now measured on the displayed torso mesh.
	# The former hip-pivot proxy would wrongly require breathing to move bones.
	rig.projection_basis = Transform3D.IDENTITY.looking_at(Vector3(-3.5,-15.5,-25),Vector3.UP).basis
	for view in Rig.DIRECTIONS:
		rig.set_direction(view)
		rig.cancel_motion()
		rig.advance(0.01,0,false)
		var feet := rig.foot_world.duplicate()
		var texture_id: int = rig._upper.texture.get_instance_id()
		assert(not rig._upper.visible and rig._upper_body_mesh.visible,"Hero canonical source Sprite is hidden; its textured torso mesh is the visible body")
		assert(rig._upper_body_material.albedo_texture==rig._upper.texture,"visible Hero mesh uses the exact canonical source texture instance")
		var pelvis: Vector2 = rig.source_records[view].pelvis
		var waist := rig.upper_display_point(pelvis)
		var hips := [rig._legs[0][0].global_position,rig._legs[1][0].global_position]
		var head_pair_distance := rig.upper_display_point(Vector2(130,90)).distance_to(rig.upper_display_point(Vector2(155,160)))
		var minimum_y := INF
		var maximum_y := -INF
		var maximum_roll := 0.0
		var displayed_roll := 0.0
		for tick in range(256):
			rig.advance(24.0/256.0,0,false)
			var displayed_shoulder := rig.upper_display_point(Vector2(pelvis.x,190))
			minimum_y = minf(minimum_y,displayed_shoulder.y)
			maximum_y = maxf(maximum_y,displayed_shoulder.y)
			assert(rig.upper_display_point(pelvis).distance_to(waist)<0.000001,"breathing waist landmark stays stationary")
			assert(absf(rig.upper_display_point(Vector2(130,90)).distance_to(rig.upper_display_point(Vector2(155,160)))-head_pair_distance)<0.000001,"head/face/hair translate rigidly without stretching")
			assert(rig._upper_body_material.albedo_texture==rig._upper.texture and rig._upper_body_mesh.visible,"actual visible body keeps the canonical source texture")
			var idle := Rig.idle_body_sample(rig.idle_time,view)
			maximum_roll = maxf(maximum_roll,absf(idle.y))
			var head_axis: Array = rig.source_records[view].head_roll_points
			var displayed_axis: Vector3 = rig._upper_pivot.global_basis.inverse()*(rig.upper_display_point(head_axis[1])-rig.upper_display_point(head_axis[0]))
			displayed_roll = maxf(displayed_roll,absf(atan2(displayed_axis.y,displayed_axis.x)))
			if rig.idle_time<7: assert(idle.y==0 and idle.z==0,"camera check waits until prolonged rest")
			assert(rig._upper.texture.get_instance_id()==texture_id,"idle cannot redraw/morph source face or attachments")
			for leg in range(2):
				assert(rig._legs[leg][0].global_position.distance_to(hips[leg])<0.000001,"breath never adds hip motion or neutral crouch slack")
				assert(rig.foot_world[leg].distance_to(feet[leg])<0.000001,"idle soles remain at the same planted world point")
				var chain: Array = rig._legs[leg]
				var knee_pose: Transform3D = chain[1].get_bone_global_pose(1)
				var hip_world: Vector3 = chain[0].global_position
				var knee_world: Vector3 = chain[1].global_transform*knee_pose.origin
				var ankle_world: Vector3 = chain[1].global_transform*(knee_pose.origin+knee_pose.basis*Vector3.DOWN*rig.lower_bone_length)
				assert(absf(hip_world.distance_to(knee_world)-rig.upper_bone_length)<0.00001,"idle upperbone %s leg%d tick%d distance%f pose%s" % [view,leg,tick,hip_world.distance_to(knee_world),knee_pose])
				assert(absf(knee_world.distance_to(ankle_world)-rig.lower_bone_length)<0.00001)
				var expected_ankle: Vector3 = feet[leg]+rig.global_basis*(Vector3(0,rig.source_records[view].ankle_height,0)-Rig.boot_depth(rig.boot_yaw))
				assert(ankle_world.distance_to(expected_ankle)<0.00001,"idle waist tilt preserves actual connected fixed-bone chain")
		assert(maximum_y-minimum_y>0.035,"breath is visible at normal island projection (about 1-2 pixels peak-to-peak)")
		assert(maximum_roll>deg_to_rad(0.6) and maximum_roll<=deg_to_rad(1.5))
		assert(displayed_roll>deg_to_rad(0.6) and displayed_roll<=deg_to_rad(1.5)+0.000001,"actual displayed opaque head landmarks retain the restrained camera-check roll above pinned hips")
		var paused_idle: float = rig.idle_time
		rig.advance(0,0,false)
		assert(rig.idle_time==paused_idle)
		rig.advance(0.1,0.55,false)
		assert(rig.idle_time==0,"movement resets stationary camera-check schedule")
		rig.cancel_motion()
		assert(rig.idle_time==0,"cancel/teleport reset stationary schedule")
	assert(Rig.idle_body_sample(8.2,"right","npc")==Vector3.ZERO,"no invented NPC idle profile")
	# An explicit camera cut rebinds once; continuous camera motion does not skate.
	var baseline_projection := Transform3D.IDENTITY.looking_at(Vector3(-3.5,-15.5,-25),Vector3.UP).basis
	for view in Rig.DIRECTIONS:
		rig.set_direction(view)
		rig.set_view_projection(Basis(Quaternion(Vector3.UP,deg_to_rad(127)))*baseline_projection,0,true)
		rig.advance(0.1,0,false)
		rig.set_view_projection(baseline_projection,0,true)
		assert(rig.speed==0 and rig.blend==0 and rig.idle_time==0)
		var rebound_feet := rig.foot_world.duplicate()
		for sprint in [false,true]:
			rig.cancel_motion()
			var last_feet := [Vector3.ZERO,Vector3.ZERO]
			var last_epoch := [-1,-1]
			for tick in range(256):
				var yaw := deg_to_rad(30.0)*sin(tick*TAU/256.0)
				var pitch := deg_to_rad(15.0)*sin(tick*TAU/128.0)
				rig.set_view_projection(Basis(Quaternion(Vector3.UP,yaw))*baseline_projection*Basis(Quaternion(Vector3.RIGHT,pitch)),yaw,false)
				rig.advance(1.0/120.0,2.0 if sprint else 0.55,sprint)
				for leg in range(2):
					_assert_rendered_sole(rig,leg)
					if rig._contact_valid[leg]:
						if last_epoch[leg]==rig._contact_epoch[leg]: assert(last_feet[leg].distance_to(rig.foot_world[leg])<0.000001,"moving camera cannot reproject/skate physical stance feet")
						last_epoch[leg] = rig._contact_epoch[leg]
						last_feet[leg] = rig.foot_world[leg]
					else: last_epoch[leg] = -1
			rig.set_view_projection(baseline_projection,0,true)
		# Stationary continuous projection changes retain exact feet as well.
		rig.advance(0.01,0,false)
		rebound_feet = rig.foot_world.duplicate()
		for tick in range(256):
			var yaw := deg_to_rad(30.0)*sin(tick*TAU/256.0)
			var pitch := deg_to_rad(15.0)*sin(tick*TAU/128.0)
			rig.set_view_projection(Basis(Quaternion(Vector3.UP,yaw))*baseline_projection*Basis(Quaternion(Vector3.RIGHT,pitch)),yaw,false)
			rig.advance(0.02,0,false)
			for leg in range(2): assert(rebound_feet[leg].distance_to(rig.foot_world[leg])<0.000001,"stationary camera sweep cannot skate soles")
	rig.set_view_projection(baseline_projection,0,true)
	var source_record: Dictionary = rig.source_records.right
	var bad := Rig.prepare_source(source_record.source,source_record.source,{},"fixture/missing")
	assert(not bad.valid and bad.upper.get_data()==source_record.source.get_data(),"missing metadata logs its path and uses the exact original sprite")
	var counts := rig.resource_counts()
	assert(counts.directions==8 and counts.leg_meshes==2 and counts.boot_nodes==2 and counts.leg_outline_materials==1 and counts.avatar_cache<=128)
	var source_builds: int = rig._renderer._source_metrics_build_count
	for repeat in range(20):
		for view in Rig.DIRECTIONS:
			rig.set_direction(view)
			rig.advance(0.016,2.0,true)
	assert(rig.resource_counts()==counts,"phase/direction updates never allocate new meshes/texture caches")
	for material in rig._materials: assert(material.next_pass==outline,"motion and view changes reuse the same outline material")
	assert(rig._renderer._source_metrics_build_count==source_builds)
	rig.cleanup()
	assert(rig.source_records.is_empty() and rig._upper.texture==null)
	for boot in rig._boots: assert(boot.texture==null)
	for material in rig._materials: assert(material.next_pass==null,"cleanup releases the shared outline pass")
	assert(rig._leg_outline==null)
	assert(rig.resource_counts().leg_outline_materials==0)
	rig.queue_free()
	await process_frame
	print("PASS: eight direction 3D gait model/source/sole/cancellation/bounded resource tests; native quality pending")
	quit()


func _assert_incomplete_hero_recovery() -> void:
	var actor := IncompleteHero.new()
	root.add_child(actor)
	await process_frame
	assert(actor._upper!=null,"one invalid prepared direction must not abort real Hero _ready")
	_assert_whole_hero_fallback(actor)
	assert(actor.diagnostics.any(func(message): return str(message).contains("/directions/front") and str(message).contains("fixture: measured front source unavailable")),"safe mode reports the actual source direction, metadata path and reason")
	actor.fail_front = false
	actor.set_appearance(actor.appearance)
	_assert_recovered_hero(actor)
	var mesh_id := actor._upper_body_mesh.get_instance_id()
	actor.fail_front = true
	actor.set_appearance(actor.appearance)
	_assert_whole_hero_fallback(actor)
	actor.fail_front = false
	actor.rebuild_sources()
	_assert_recovered_hero(actor)
	assert(actor._upper_body_mesh.get_instance_id()==mesh_id,"safe/recovered rebuild reuses the bounded torso resource")
	actor.source_records.front.source_pivot_chain = 0.60
	actor._calibrate_hero_sources()
	_assert_whole_hero_fallback(actor,false)
	assert(actor.diagnostics.any(func(message): return str(message).contains("/directions/front") and str(message).contains("source-pivot chain")),"an unreasonable source chain reports its direction and reason without aborting calibration")
	actor.rebuild_sources()
	_assert_recovered_hero(actor)
	actor.source_records.front.rigid_head_end = actor.source_records.front.pelvis.y
	actor._calibrate_hero_sources()
	_assert_whole_hero_fallback(actor,false)
	assert(actor.diagnostics.any(func(message): return str(message).contains("/directions/front") and str(message).contains("head-to-waist transition")),"unsupported head overlap safely rejects the whole set before caching torso weights")
	actor.rebuild_sources()
	_assert_recovered_hero(actor)
	actor.cleanup()
	actor.queue_free()
	await process_frame

func _assert_whole_hero_fallback(actor,invalid_record: bool = true) -> void:
	assert(actor.source_records.size()==8 and actor.source_records.front.valid==not invalid_record,"source inventory retains each actual validity result; calibration rejects incomplete or unreasonable measurements")
	assert(actor._hero_fixed_chain==0 and is_equal_approx(actor.upper_bone_length,Rig.UPPER_LENGTH),"incomplete Hero builds nominal bones without applying partial source-pivot geometry")
	for view in Rig.DIRECTIONS:
		actor.set_direction(view)
		actor.cancel_motion()
		actor.advance(0.05,2.0,true)
		var record: Dictionary = actor.source_records[view]
		assert(actor._upper.visible and (actor._upper_body_mesh==null or not actor._upper_body_mesh.visible),"every incomplete Hero view uses the full source Sprite")
		assert(actor._upper.texture.get_image().get_data()==record.source.get_data(),"all eight fallback views preserve the complete original supplied RGBA, including the seven valid sources")
		for leg in range(2): assert(not actor._legs[leg][0].visible and not actor._boots[leg].visible,"safe full source never overlaps articulated legs or boots")
	assert(actor.first_reach_failure.is_empty(),"partial source geometry never reaches a fixed-bone pose solve")

func _assert_recovered_hero(actor) -> void:
	assert(actor.diagnostics.is_empty() and actor._hero_fixed_chain>0.30 and actor._hero_fixed_chain<0.45,"all eight valid sources restore measured calibration")
	assert(absf(actor._hero_fixed_chain-0.3740643274853801)<0.000001,"recovery uses the unchanged original source median")
	for view in Rig.DIRECTIONS:
		actor.set_direction(view)
		actor.cancel_motion()
		assert(actor.source_records[view].valid and actor.source_records[view].hero_pivot_geometry,"recovered coverage requires every original direction to validate")
		assert(not actor._upper.visible and actor._upper_body_mesh.visible and actor._upper_body_material.albedo_texture==actor._upper.texture,"recovery restores the same canonical textured torso")
		for leg in range(2):
			assert(actor._legs[leg][0].visible and actor._boots[leg].visible,"recovery restores both articulated limbs and retained boots")
			var skeleton: Skeleton3D = actor._legs[leg][1]
			assert(is_equal_approx(skeleton.get_bone_rest(1).origin.y,-actor.upper_bone_length),"recovery rebinds the nominal skeleton to the fixed measured chain")
		_assert_runtime_surface(actor)
	assert(actor.first_reach_failure.is_empty(),"restored eight-view source chain remains reachable")

func _world_reach_audit() -> void:
	if OS.get_environment("SNAPLAND_SAVE_PATH").is_empty(): OS.set_environment("SNAPLAND_SAVE_PATH",ProjectSettings.globalize_path("res://.review/sol-world-reach-save.json"))
	var progress = root.get_node("Progress")
	progress.reset_progress()
	progress.intro_seen = false
	var main = load("res://game/main.tscn").instantiate()
	root.add_child(main)
	var world = main.world
	for tick in range(120): await physics_frame
	main._close()
	world.blocked = false
	world.player.position = Vector3(0,0.3,-22)
	for movement in [["move_up"],["move_up","move_right"],["move_right"],["move_right","move_down"],["move_down"],["move_down","move_left"],["move_left"],["move_left","move_up"]]:
		print("REACH_AUDIT_MOVE ",movement)
		for action in movement: Input.action_press(action)
		for tick in range(40): await physics_frame
		for action in movement: Input.action_release(action)
		for tick in range(6): await physics_frame
		if not world.avatar_motion_rig.first_reach_failure.is_empty():
			print("REACH_AUDIT_FIRST ",world.avatar_motion_rig.first_reach_failure)
			main.queue_free()
			await process_frame
			quit(1)
			return
	for point_id in ["guide","quest-001","quest-002","game-001","game-002","game-003","game-004","game-005","game-006","game-007","game-008","game-009","game-010","game-011","game-012","ride-tide"]:
		var point: Dictionary = world._point_by_id(point_id)
		print("REACH_AUDIT_LOCATION ",point_id," ",point.position)
		world.player.position = point.position+Vector3(0,0.3,1.1)
		for tick in range(10): await physics_frame
		if not world.avatar_motion_rig.first_reach_failure.is_empty():
			print("REACH_AUDIT_FIRST ",world.avatar_motion_rig.first_reach_failure)
			main.queue_free()
			await process_frame
			quit(1)
			return
	main.queue_free()
	await process_frame
	print("PASS: world station reach audit")
	quit()

func _assert_rendered_sole(actor, leg: int) -> void:
	var record: Dictionary = actor.source_records[actor.direction]
	var size: Vector2 = record.boot_image.get_size()
	var boot: Sprite3D = actor._boots[leg]
	var sole_pixel: Vector3 = Vector3((record.boot_center-size.x*0.5)*boot.pixel_size,(size.y*0.5-record.sole)*boot.pixel_size,0)+actor._boot_contact_offset[leg]
	assert((boot.global_transform*sole_pixel).distance_to(actor.boot_contact_world[leg])<0.00001,"actual source heel/toe/flat sole point stays at its physical contact anchor")
	if actor._boot_contact_offset[leg]==Vector3.ZERO:
		assert(actor.boot_contact_world[leg].distance_to(actor.foot_world[leg])<0.00001,"flat source sole plane retains the original world anchor")

func _assert_runtime_surface(actor) -> void:
	for leg in range(2):
		_assert_rendered_sole(actor,leg)
		var points: PackedVector3Array = actor._legs[leg][3].positions
		for row in range(Rig.ROWS.size()-1):
			for ring in range(Rig.RING):
				var next := (ring+1)%Rig.RING
				var a := points[row*Rig.RING+ring]
				var b := points[row*Rig.RING+next]
				var c := points[(row+1)*Rig.RING+ring]
				var d := points[(row+1)*Rig.RING+next]
				assert((b-a).cross(c-a).length()>0.00001 and (d-b).cross(c-b).length()>0.00001,"actual terrain pose keeps a continuous skin surface")
