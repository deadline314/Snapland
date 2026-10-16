extends Node

const Rig = preload("res://game/world/avatar_motion_rig.gd")
const Avatar = preload("res://game/world/avatar_renderer.gd")
const NpcSources = preload("res://game/world/npc_motion_sources.gd")

var _source_renderer = Avatar.new()
var _ground_y := 0.0
var _role_metadata_path := ""

func _ready() -> void:
	_run_role_contract()

func _run_role_contract() -> void:
	var metadata_root: Variant = JSON.parse_string(FileAccess.get_file_as_string(Rig.METADATA_PATH))
	assert(metadata_root is Dictionary, "authored hero measurements remain available as an immutable fixture source")
	var hero_roles: Dictionary = metadata_root.get("roles", {})
	var hero_directions: Dictionary = hero_roles.get("hero", {}).get("directions", {})
	assert(not hero_directions.get("left", {}).has("limb_garment_max_y"), "default hero measurements retain the original garment-mask path")
	var role_directions := {"left": hero_directions.get("left", {}), "right": hero_directions.get("right", {})}
	var ticket_direction := _measured_entry(role_directions.left,260,0.3333333333333333)
	var announcer_direction := _measured_entry(role_directions.right,226,0.26666666666666666)
	var save_path := OS.get_environment("SNAPLAND_SAVE_PATH")
	if not save_path.is_absolute_path():
		push_error("role metadata fixture requires an isolated absolute SNAPLAND_SAVE_PATH")
		get_tree().quit(2)
		return
	# The runner supplies an owned temporary profile on every platform. TEMP is
	# Windows-specific and may be absent on Linux CI; never fall back to players.
	var temp_root := save_path.get_base_dir()
	assert(DirAccess.make_dir_recursive_absolute(temp_root)==OK, "role metadata fixture uses the isolated test profile directory")
	_role_metadata_path = temp_root.path_join("snapland-art17-role-rig-%d-%d.json" % [Time.get_ticks_usec(), randi()])
	var metadata_file := FileAccess.open(_role_metadata_path, FileAccess.WRITE)
	assert(metadata_file != null)
	metadata_file.store_string(JSON.stringify({"roles": {
		"short_npc": {"directions": role_directions},
		"measured_ticket": {"directions": {"left": ticket_direction}},
		"measured_announcer": {"directions": {"right": announcer_direction}},
	}}))
	metadata_file.close()

	var actor := Rig.new()
	actor.role = "short_npc"
	actor.metadata_path = _role_metadata_path
	actor.required_directions = ["left", "right"]
	actor.leg_length_scale = 0.7
	actor.source_provider = Callable(self, "_synthetic_source")
	actor.ground_height_provider = Callable(self, "_ground_height")
	add_child(actor)
	await get_tree().process_frame

	assert(actor.required_directions == ["left", "right"] and actor.source_records.size() == 2, "role declares only its measured left/right views; no front direction is fabricated")
	assert(actor.metadata_path == _role_metadata_path, "role loads its separate metadata path")
	assert(actor._renderer == null, "provider-backed role does not instantiate the hero renderer cache")
	assert(is_equal_approx(actor.leg_length_scale, 0.7))
	assert(not actor.source_records.left.measured_source_geometry and is_equal_approx(actor.source_records.left.hip_height,Rig.HIP_HEIGHT*0.7) and is_equal_approx(actor.source_records.left.hip_width_scale,0.7), "entries without measured dimensions keep the existing role-scale behavior")
	assert(is_equal_approx(actor.upper_bone_length, Rig.UPPER_LENGTH*0.7) and is_equal_approx(actor.lower_bone_length, Rig.LOWER_LENGTH*0.7), "both fixed joints use the role's measured length scale")
	assert(is_equal_approx(Rig.stride(false, Rig.FOOT_STROKE*actor.leg_length_scale), Rig.stride(false)*actor.leg_length_scale), "foot stroke scales with the shorter leg")

	for view in actor.required_directions:
		var record: Dictionary = actor.source_records[view]
		assert(record.valid, "measured role source prepares successfully for " + view + ": " + str(record.reason))
		var renderer_frame: int = _source_renderer.walk_idle_frame(view)
		var expected: Image = _source_renderer.texture(actor.appearance, actor.equipment, view, renderer_frame, "walk").get_image()
		assert(record.source.get_data() == expected.get_data(), "source RGB and selected outfit are supplied unchanged for " + view)
		var first_limb_row := 360
		for envelope: Array in record.limb_envelopes: first_limb_row = mini(first_limb_row, int(envelope[1]))
		for y in range(first_limb_row):
			for x in range(record.source.get_width()):
				assert(record.upper.get_pixel(x,y) == record.source.get_pixel(x,y), "head/face/upper clothes remain byte-identical above role limb ownership")

	actor.set_direction("right")
	assert(not actor.source_records.has("front"), "two-view role has no hidden eight-direction coverage")
	for ground in [0.09, -0.04]:
		_ground_y = ground
		actor._pose()
		for leg in range(2):
			var chain: Array = actor._legs[leg]
			var knee_pose: Transform3D = chain[1].get_bone_global_pose(1)
			var hip_world: Vector3 = chain[0].global_position
			var knee_world: Vector3 = chain[1].global_transform*knee_pose.origin
			var ankle_world: Vector3 = chain[1].global_transform*(knee_pose.origin+knee_pose.basis*Vector3.DOWN*actor.lower_bone_length)
			assert(is_equal_approx(hip_world.distance_to(knee_world), actor.upper_bone_length), "measured short upper bone remains a fixed length")
			assert(is_equal_approx(knee_world.distance_to(ankle_world), actor.lower_bone_length), "measured short lower bone remains a fixed length")
			assert(absf(actor.foot_world[leg].y-ground)<0.00001, "measured role sole tracks a changed ground height")
			var boot: Sprite3D = actor._boots[leg]
			var boot_size: Vector2 = actor.source_records.right.boot_image.get_size()
			var rendered_sole_y: float = boot.global_position.y-(actor.source_records.right.sole-boot_size.y*0.5)*boot.pixel_size
			assert(absf(rendered_sole_y-ground)<0.00001, "scaled boot sole stays on the measured ground plane")
	await _assert_measured_source_overrides()
	assert(await _assert_actual_npc_geometry(), "actual NPC source and geometry regression completed")
	assert(await _report_hero_geometry(),"hero source-pivot geometry regression completed")
	_assert_full_trouser_cut()

	var missing := Rig.new()
	missing.role = "unmeasured_npc"
	missing.metadata_path = _role_metadata_path
	missing.required_directions = ["left"]
	missing.source_provider = Callable(self, "_synthetic_source")
	add_child(missing)
	await get_tree().process_frame
	var fallback: Dictionary = missing.source_records.left
	assert(not fallback.valid, "a role without matching measurement remains explicit fallback, not claimed coverage")
	assert(fallback.upper.get_data() == fallback.source.get_data(), "missing role metadata preserves the complete original RGB source")
	assert(str(fallback.reason).contains(_role_metadata_path) and not missing.diagnostics.is_empty(), "fallback diagnostic reports the configured metadata path")

	missing.cleanup()
	missing.queue_free()
	actor.cleanup()
	actor.queue_free()
	await get_tree().process_frame
	assert(DirAccess.remove_absolute(_role_metadata_path) == OK, "remove only the generated role measurement fixture")
	print("PASS: role metadata path, two-view coverage, scaled fixed bones/boots, ground following, actual NPC source-width legs/opaque boot attachment, non-skin trouser limb ownership, and missing-role fallback")
	get_tree().quit()

func _measured_entry(source_entry: Dictionary, pelvis_y: int, ankle_height: float) -> Dictionary:
	var entry := source_entry.duplicate(true)
	entry.pelvis = [int(entry.pelvis[0]),pelvis_y]
	entry["measurements"] = {
		"boot_or_bare_foot_rect_complete": true,
		"sole_row_px": 346,
		"ankle_height_source_m": ankle_height,
	}
	return entry

func _assert_measured_source_overrides() -> void:
	var ticket := Rig.new()
	ticket.role = "measured_ticket"
	ticket.metadata_path = _role_metadata_path
	ticket.required_directions = ["left"]
	ticket.leg_length_scale = 0.5777777777777778
	ticket.source_provider = Callable(self, "_synthetic_source")
	ticket.ground_height_provider = Callable(self, "_ground_height")
	add_child(ticket)
	await get_tree().process_frame
	var ticket_record: Dictionary = ticket.source_records.left
	assert(ticket_record.valid and ticket_record.measured_source_geometry, "complete ticket source measurements activate the measured geometry override")
	assert(is_equal_approx(ticket_record.hip_height,(346.0-260.0)*Rig.PIXEL_SIZE), "ticket hip height derives from its measured pelvis-to-sole rows")
	assert(is_equal_approx(ticket_record.ankle_height,0.3333333333333333), "ticket ankle height uses the measured 0.333 m source distance")
	assert(is_equal_approx(ticket_record.boot_scale,1.0) and is_equal_approx(ticket_record.hip_width_scale,1.0), "measured boot pixels and hip width avoid a second bone-ratio scale")
	assert(is_equal_approx(ticket._boots[0].pixel_size,Rig.PIXEL_SIZE), "measured ticket boot texture keeps its normalized source pixel scale")
	assert(ticket._upper_pivot.position.y<=ticket_record.hip_height+0.0001, "ticket support pose stays at or below its measured nominal hip")
	_assert_measured_upper_source(ticket_record,"left","ticket")
	_assert_fixed_role_bones(ticket,"ticket")

	var announcer := Rig.new()
	announcer.role = "measured_announcer"
	announcer.metadata_path = _role_metadata_path
	announcer.required_directions = ["right"]
	announcer.leg_length_scale = 1.1555555555555557
	announcer.source_provider = Callable(self, "_synthetic_source")
	announcer.ground_height_provider = Callable(self, "_ground_height")
	add_child(announcer)
	await get_tree().process_frame
	var announcer_record: Dictionary = announcer.source_records.right
	assert(announcer_record.valid and announcer_record.measured_source_geometry, "complete announcer source measurements activate the measured geometry override")
	assert(is_equal_approx(announcer_record.hip_height,(346.0-226.0)*Rig.PIXEL_SIZE), "announcer hip height derives from its measured 226 px pelvis and 346 px sole")
	assert(is_equal_approx(announcer_record.ankle_height,0.26666666666666666), "announcer ankle height uses the measured 0.267 m source distance")
	assert(is_equal_approx(announcer_record.boot_scale,1.0) and is_equal_approx(announcer_record.hip_width_scale,1.0), "measured announcer boot pixels and hip width avoid a second bone-ratio scale")
	assert(is_equal_approx(announcer._boots[0].pixel_size,Rig.PIXEL_SIZE), "measured announcer boot texture keeps its normalized source pixel scale")
	assert(announcer._upper_pivot.position.y<announcer_record.hip_height and announcer.support_drop>0.0, "reach solve lowers the nominal announcer hip only as needed")
	_assert_measured_upper_source(announcer_record,"right","announcer")
	_assert_fixed_role_bones(announcer,"announcer")

	ticket.cleanup()
	ticket.queue_free()
	announcer.cleanup()
	announcer.queue_free()
	await get_tree().process_frame

func _assert_measured_upper_source(record: Dictionary, view: String, role_name: String) -> void:
	var frame: int = _source_renderer.walk_idle_frame(view)
	var expected: Image = _source_renderer.texture(Avatar.DEFAULT_APPEARANCE,{"outfit":"outfit-tide","hat":"hat-none"},view,frame,"walk").get_image()
	assert(record.source.get_data()==expected.get_data(),role_name+" original RGBA source remains unchanged")
	var first_limb_row := 360
	for envelope: Array in record.limb_envelopes: first_limb_row = mini(first_limb_row,int(envelope[1]))
	for y in range(first_limb_row):
		for x in range(record.source.get_width()):
			assert(record.upper.get_pixel(x,y)==record.source.get_pixel(x,y),role_name+" source RGBA above the measured limb remains byte-identical")

func _assert_fixed_role_bones(actor, role_name: String) -> void:
	for leg in range(2):
		var chain: Array = actor._legs[leg]
		var knee_pose: Transform3D = chain[1].get_bone_global_pose(1)
		var hip_world: Vector3 = chain[0].global_position
		var knee_world: Vector3 = chain[1].global_transform*knee_pose.origin
		var ankle_world: Vector3 = chain[1].global_transform*(knee_pose.origin+knee_pose.basis*Vector3.DOWN*actor.lower_bone_length)
		assert(is_equal_approx(hip_world.distance_to(knee_world),actor.upper_bone_length), role_name+" measured source retains fixed upper-bone length")
		assert(is_equal_approx(knee_world.distance_to(ankle_world),actor.lower_bone_length), role_name+" measured source retains fixed lower-bone length")

func _assert_actual_npc_geometry() -> bool:
	var provider := NpcSources.new()
	for npc_role in ["ticket","imp","announcer"]:
		var actor := Rig.new()
		actor.role = npc_role
		actor.metadata_path = NpcSources.METADATA_PATH
		actor.required_directions = ["left","right"]
		var left := provider.direction_measurement(npc_role,"left")
		var right := provider.direction_measurement(npc_role,"right")
		actor.leg_length_scale = (float(left.leg_measurement.leg_length_scale)+float(right.leg_measurement.leg_length_scale))*0.5
		actor.source_provider = Callable(provider,"provide")
		add_child(actor)
		await get_tree().process_frame
		if npc_role=="ticket":
			assert(is_equal_approx(actor.upper_bone_length+actor.lower_bone_length,0.23),"ticket fixed chain follows mean current hip rows261/262 to measured ankle296, not the old crop row300")
			for view in actor.required_directions:
				actor.set_direction(view)
				actor.cancel_motion()
				for leg in range(2):
					assert(_knee_bend_degrees(actor,leg)<25.0,"ticket neutral measured pose must not retain the old 49–56 degree crouch")
		for view in actor.required_directions:
			actor.set_direction(view)
			var record: Dictionary = actor.source_records[view]
			var independent_source: Dictionary = provider.provide(npc_role,view)
			assert(record.valid and record.source.get_data()==independent_source.source.get_data(),npc_role+" original normalized source RGBA remains unchanged")
			assert(FileAccess.get_sha256(ProjectSettings.globalize_path(provider.measurements_for(npc_role).source_atlas))==independent_source.atlas_sha256,npc_role+" original atlas SHA remains unchanged")
			var entry: Dictionary = provider.direction_measurement(npc_role,view)
			for protected: Dictionary in entry.protected_regions_named:
				var box := Rig.rectangle(protected.rect)
				for y in range(box.position.y,box.end.y):
					for x in range(box.position.x,box.end.x):
						assert(record.upper.get_pixel(x,y)==record.source.get_pixel(x,y),npc_role+" named head, satchel, tail and garment guards retain exact RGBA: "+str(protected.label))
			# The source's complete original feet lie below the measured boot rows;
			# checking only the old envelopes misses thin outer boot/foot outlines.
			var first_foot_row := mini(int(entry.lower[2][1]),int(entry.lower[3][1]))
			for y in range(first_foot_row,346):
				for x in range(280):
					if record.source.get_pixel(x,y).a>0.4 and record.garment_mask[y*280+x]==0:
						assert(record.upper.get_pixel(x,y).a==0,"%s/%s original foot outline x%d/y%d must not survive outside a too-narrow limb envelope" % [npc_role,view,x,y])
			for y in range(360):
				for x in range(280):
					if record.garment_mask[y*280+x]!=0 or record.limb_mask[y*280+x]==0 and not _inside_lower(record.lower,Vector2i(x,y)):
						assert(record.upper.get_pixel(x,y)==record.source.get_pixel(x,y),npc_role+" immutable upper identity remains exact RGBA")
			var crop: Rect2i = record.boot_rect
			for y in range(crop.position.y,crop.end.y):
				for x in range(crop.position.x,crop.end.x):
					var excluded := false
					for values: Array in record.boot_exclusions:
						if Rig.rectangle(values).has_point(Vector2i(x,y)): excluded = true
					if record.source.get_pixel(x,y).a>0.63 and not excluded:
						assert(record.boot_image.get_pixel(x,y)==record.source.get_pixel(x,y),npc_role+" complete opaque boot shaft, toes and sole retain source RGBA")
			for projection: Basis in [Basis.IDENTITY,Transform3D.IDENTITY.looking_at(Vector3(-3.5,-15.5,-25),Vector3.UP).basis]:
				actor.set_view_projection(projection,atan2(projection.z.x,projection.z.z),true)
				for phase in range(32):
					actor.travel = float(phase)/32.0*actor._stride(false)
					actor.blend = 1.0
					actor._pose()
					_assert_fixed_role_bones(actor,npc_role)
					if npc_role=="imp": _assert_imp_cuff_projection(actor,view)
					assert(_assert_leg_outline(actor),npc_role+" outline must stay behind protected garment")
					for leg in range(2):
						var vertices: PackedVector3Array = actor._legs[leg][3].positions
						for row in [3,7]:
							var diameter := 0.0
							for ring in range(Rig.RING):
								diameter = maxf(diameter,vertices[row*Rig.RING+ring].distance_to(vertices[row*Rig.RING+(ring+Rig.RING/2)%Rig.RING]))
							assert(diameter>=float(record.hip_widths[leg])*Rig.PIXEL_SIZE*2.0*0.70,npc_role+" source-width calf must not collapse to the hero's bone-scaled strand")
						var boot: Sprite3D = actor._boots[leg]
						var end_center := Vector3.ZERO
						var front_z := -INF
						for ring in range(Rig.RING):
							var point: Vector3 = actor._legs[leg][0].to_global(vertices[(Rig.ROWS.size()-1)*Rig.RING+ring])
							var local := boot.to_local(point)
							end_center += local/float(Rig.RING)
							front_z = maxf(front_z,local.z)
						var pixel := Vector2i(floori(record.boot_image.get_width()*0.5+end_center.x/boot.pixel_size),floori(record.boot_image.get_height()*0.5-end_center.y/boot.pixel_size))
						assert(Rect2i(Vector2i.ZERO,record.boot_image.get_size()).has_point(pixel) and record.boot_image.get_pixelv(pixel).a>0.63,npc_role+" actual mesh end must enter an opaque boot shaft pixel")
						assert(absf(front_z)<Rig.PIXEL_SIZE*0.5,npc_role+" distal tube front must meet the rendered boot plane without a depth gap")
						var rendered_sole_y: float = boot.global_position.y-(record.sole-record.boot_image.get_height()*0.5)*boot.pixel_size
						assert(absf(rendered_sole_y-actor.foot_world[leg].y)<0.00001,npc_role+" complete rendered boot sole remains at physical contact")
		assert(_assert_slow_walk_lift(actor,npc_role),npc_role+" actual gait lift regression completed")
		actor.cleanup()
		actor.queue_free()
		await get_tree().process_frame
	return true

func _assert_imp_cuff_projection(actor,view: String) -> void:
	# Independent source points in the native rejected thigh cut, including
	# right x164..184/y291. Check actual uploaded triangles through every gait
	# phase and both projections; restoring a fixed source leg cannot pass.
	var witnesses := [Vector2(100.5,285.5),Vector2(135.5,294.5)] if view=="left" else [Vector2(166.5,291.5),Vector2(174.5,291.5),Vector2(182.5,291.5)]
	var record: Dictionary = actor.source_records[view]
	for pixel: Vector2 in witnesses:
		var sample := Vector2i(pixel.floor())
		assert(record.source.get_pixelv(sample).a>0.95,"independent imp proximal contour exists in source")
		assert(record.upper.get_pixelv(sample).a==0,"old imp thigh root is replaced by articulated geometry")
		var covered := false
		for leg in range(2):
			var chain: Array = actor._legs[leg]
			var vertices: PackedVector3Array = chain[3].positions
			for row in range(4):
				for ring in range(Rig.RING):
					var next := (ring+1)%Rig.RING
					var ids := [row*Rig.RING+ring,row*Rig.RING+next,(row+1)*Rig.RING+ring,(row+1)*Rig.RING+next]
					var quad := PackedVector2Array()
					for index: int in ids:
						var local: Vector3 = actor._upper_pivot.to_local(chain[0].to_global(vertices[index]))
						quad.append(record.pelvis+Vector2(local.x,-local.y)/Rig.PIXEL_SIZE)
					if Geometry2D.is_point_in_polygon(pixel,PackedVector2Array([quad[0],quad[1],quad[2]])) or Geometry2D.is_point_in_polygon(pixel,PackedVector2Array([quad[1],quad[3],quad[2]])): covered=true
		assert(covered,"imp/%s source thigh cut has no hip-cuff projection gap at %s" % [view,str(pixel)])

func _knee_bend_degrees(actor, leg: int) -> float:
	var chain: Array = actor._legs[leg]
	var knee_pose: Transform3D = chain[1].get_bone_global_pose(1)
	var hip: Vector3 = chain[0].global_position
	var knee: Vector3 = chain[1].global_transform*knee_pose.origin
	var ankle: Vector3 = chain[1].global_transform*(knee_pose.origin+knee_pose.basis*Vector3.DOWN*actor.lower_bone_length)
	return rad_to_deg((knee-hip).normalized().angle_to((ankle-knee).normalized()))

func _assert_slow_walk_lift(actor, npc_role: String) -> bool:
	var caps := {"ticket":0.018,"imp":0.020,"announcer":0.024}
	var route_speeds := {"ticket":0.25,"imp":0.35,"announcer":0.60}
	var cap: float = caps[npc_role]
	var actual_speed: float = route_speeds[npc_role]
	actor.set_view_projection(Basis.IDENTITY,0,true)
	actor.set_direction("right")
	var peak_lift := 0.0
	for frame in range(180):
		var delta := Vector3.RIGHT*(actual_speed/60.0)
		actor.position += delta
		actor.advance_from_motion(1.0/60.0,delta,false)
		if frame>30:
			for leg in range(2): peak_lift = maxf(peak_lift,actor.foot_world[leg].y)
		_assert_fixed_role_bones(actor,npc_role)
	assert(peak_lift>=cap*0.90 and peak_lift<=cap+0.00001,npc_role+" slow route renders meaningful measured clearance without the inherited oversized lift")
	var cautious_peak := 0.0
	for frame in range(360):
		var delta := Vector3.RIGHT*(0.05/60.0)
		actor.position += delta
		actor.advance_from_motion(1.0/60.0,delta,false)
		if frame>30:
			for leg in range(2): cautious_peak = maxf(cautious_peak,actor.foot_world[leg].y)
	assert(cautious_peak>=cap*0.58 and cautious_peak<=cap*0.75,npc_role+" cautious rendered gait lowers lift with actual speed while retaining clearance")
	# Abrupt caller speed changes must produce bounded foot-amplitude changes,
	# independent of the ordinary stance/swing phase changing at those speeds.
	var previous_lift: float = actor._walk_lift_amplitude
	for requested_speed in [0.05,2.0,0.10,0.60,0.04]:
		var delta := Vector3.RIGHT*(float(requested_speed)/60.0)
		actor.position += delta
		actor.advance_from_motion(1.0/60.0,delta,false)
		assert(absf(actor._walk_lift_amplitude-previous_lift)<=0.00101,npc_role+" sudden speed changes cannot jump foot lift by more than1mm/frame at60FPS")
		assert(actor._walk_lift_amplitude>0.0 and actor._walk_lift_amplitude<=cap,npc_role+" moving lift stays positive and within its authored role cap")
		previous_lift = actor._walk_lift_amplitude
	print("NPC_GAIT_MEASUREMENT role=%s fixed_chain_m=%.6f rendered_slow_peak_m=%.6f rendered_cautious_peak_m=%.6f" % [npc_role,actor.upper_bone_length+actor.lower_bone_length,peak_lift,cautious_peak])
	return true

func _report_hero_geometry() -> bool:
	var hero := Rig.new()
	add_child(hero)
	await get_tree().process_frame
	assert(absf(hero.upper_bone_length+hero.lower_bone_length-0.3740643274853801)<0.000001,"hero uses one fixed median source-pivot chain across all eight views, including converted back boot coordinates")
	for projection: Basis in [Basis.IDENTITY,Transform3D.IDENTITY.looking_at(Vector3(-3.5,-15.5,-25),Vector3.UP).basis]:
		hero.set_view_projection(projection,atan2(projection.z.x,projection.z.z),true)
		for view in hero.required_directions:
			hero.set_direction(view)
			hero.cancel_motion()
			var record: Dictionary = hero.source_records[view]
			for leg in range(2): assert(_knee_bend_degrees(hero,leg)<65.0,"hero neutral source-pivot stance cannot retain the rejected 76–100 degree crouch")
			var hip_row := (float(record.hips[0][1])+float(record.hips[1][1]))*0.5
			var normalized_ankle_row: float = record.source_ankle_row
			print("HERO_CHAIN_DIAGNOSTIC view=%s camera_up_y=%.4f source_vertical_chain_m=%.6f fixed_chain_m=%.6f neutral_knee_deg=[%.2f,%.2f] support_drop_m=%.6f" % [view,projection.y.y,(normalized_ankle_row-hip_row)*Rig.PIXEL_SIZE,hero.upper_bone_length+hero.lower_bone_length,_knee_bend_degrees(hero,0),_knee_bend_degrees(hero,1),hero.support_drop])
			_assert_fixed_role_bones(hero,"hero")
	assert(_assert_hero_variants(hero),"three Hero wardrobes/species retain source-pivot geometry")
	hero.cleanup()
	hero.queue_free()
	await get_tree().process_frame
	return true

func _assert_hero_variants(hero) -> bool:
	var profiles := [
		{"species":"human","hair":"windswept","outfit":"outfit-tide"},
		{"species":"elf","hair":"bob","outfit":"outfit-coral"},
		{"species":"imp","hair":"curly","outfit":"outfit-gold"},
	]
	var anchors: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Rig.METADATA_PATH)).roles.hero.directions
	for profile: Dictionary in profiles:
		var look: Dictionary = Avatar.DEFAULT_APPEARANCE.duplicate()
		look.species = profile.species
		look.hair = profile.hair
		var equipped := {"outfit":profile.outfit,"hat":"hat-none"}
		# Capture independent renderer sources before the rig rebuilds this look.
		var originals := {}
		var hair_references := {}
		var species_references := {}
		for view in hero.required_directions:
			originals[view] = _source_renderer.texture(look,equipped,view,_source_renderer.walk_idle_frame(view),"walk").get_image()
			var source_hair_look: Dictionary = look.duplicate()
			source_hair_look.hair = "windswept"
			hair_references[view] = _source_renderer.texture(source_hair_look,equipped,view,_source_renderer.walk_idle_frame(view),"walk").get_image()
			var human_look: Dictionary = look.duplicate()
			human_look.species = "human"
			species_references[view] = _source_renderer.texture(human_look,equipped,view,_source_renderer.walk_idle_frame(view),"walk").get_image()
		hero.set_appearance(look,equipped)
		for projection: Basis in [Basis.IDENTITY,Transform3D.IDENTITY.looking_at(Vector3(-3.5,-15.5,-25),Vector3.UP).basis]:
			hero.set_view_projection(projection,atan2(projection.z.x,projection.z.z),true)
			for view in hero.required_directions:
				hero.set_direction(view)
				hero.cancel_motion()
				var record: Dictionary = hero.source_records[view]
				assert(record.valid and record.source.get_data()==originals[view].get_data(),"Hero geometry cannot mutate independently captured source head/hair/wardrobe RGBA")
				assert(hero._upper_body_mesh.visible and not hero._upper.visible and hero._upper_body_material.albedo_texture==hero._upper.texture,"all Hero variants display the actual mesh with the same canonical texture")
				var measured_hair_last := -1
				var measured_species_last := -1
				for y in range(360):
					for x in range(280):
						if originals[view].get_pixel(x,y)!=hair_references[view].get_pixel(x,y):
							measured_hair_last = maxi(measured_hair_last,y)
							assert(y<record.rigid_head_end,"every actual hairstyle-changed source pixel is inside the rigid head region")
						if originals[view].get_pixel(x,y).a>0.63 and species_references[view].get_pixel(x,y).a<0.1:
							measured_species_last = maxi(measured_species_last,y)
							assert(y<record.rigid_head_end,"every actual added horn/ear source pixel is inside the rigid head region")
				print("HERO_HEAD_GUARD species=%s hair=%s view=%s source_guard_bottom=%d actual_hair_changed_last=%d actual_species_added_last=%d rigid_end=%.1f" % [profile.species,profile.hair,view,record.source_head_bounds.end.y,measured_hair_last,measured_species_last,record.rigid_head_end])
				assert(absf(hero.upper_bone_length+hero.lower_bone_length-0.3740643274853801)<0.000001,"Hero fixed median bones cannot change with direction, camera or wardrobe")
				assert(is_equal_approx(record.hip_height,(record.source_sole-record.pelvis.y)*Rig.PIXEL_SIZE),"Hero nominal hip height derives from its source pelvis and retained sole")
				assert(is_equal_approx(record.hip_width_scale,1.0),"Hero source opening widths retain their original units")
				for y in range(360):
					for x in range(280):
						if record.garment_mask[y*280+x]!=0 or record.limb_mask[y*280+x]==0 and not _inside_lower(record.lower,Vector2i(x,y)):
							assert(record.upper.get_pixel(x,y)==originals[view].get_pixel(x,y),"Hero upper source guards and all unowned identity pixels remain exact")
				var source_data := {"source":originals[view],"raw":_source_renderer._walk_pose_image(view,_source_renderer.walk_idle_frame(view))}
				var palette: Image = _source_renderer._walk_pose_image("right",_source_renderer.walk_idle_frame("right")) if view=="back" else null
				# Independent reference: undo the manifest registration on image
				# pixels, extract with unchanged authored metadata, then translate
				# the body boot back. Do not reuse the production metadata adapter.
				var registration: Vector2i = _source_renderer._stable_walk_pixels.root_offset("hero",view,_source_renderer.walk_idle_frame(view))
				if palette!=null:
					var palette_registration: Vector2i = _source_renderer._stable_walk_pixels.root_offset("hero","right",_source_renderer.walk_idle_frame("right"))
					palette = _translated_image(palette,-palette_registration)
				var legacy_boot: Dictionary = Rig.prepare_source(_translated_image(source_data.source,-registration),_translated_image(source_data.raw,-registration),anchors[view],"hero-original-boot",palette)
				assert(legacy_boot.valid,"independent authored-coordinate source extraction remains valid")
				var expected_boot: Image = legacy_boot.boot_image if record.external_boot else _translated_image(legacy_boot.boot_image,registration)
				assert(record.boot_image.get_data()==expected_boot.get_data(),"Hero complete source boot pixels retain their original extraction and palette")
				if view=="back":
					assert(record.sole==515 and is_equal_approx(record.boot_center,195.0),"back external boot uses sole989/crop474 and pivot619/crop424")
					assert(absf(record.ankle_height-0.14853801169590643)<0.000001 and absf((record.source_ankle_row-registration.y)-324.719298245614)<0.000001,"back pivot735/crop474 converts through scale0.087719 into the normalized source canvas")
				var neutral_max := 0.0
				for leg in range(2): neutral_max = maxf(neutral_max,_knee_bend_degrees(hero,leg))
				assert(neutral_max<65.0,"Hero neutral joints avoid the rejected deeply crouched stance")
				var waist: Vector3 = hero.upper_display_point(record.pelvis)
				var pinned_hips := [hero._legs[0][0].global_position,hero._legs[1][0].global_position]
				var head_axis: Array = record.head_roll_points
				var head_distance: float = hero.upper_display_point(head_axis[0]).distance_to(hero.upper_display_point(head_axis[1]))
				for seconds in [0.8333333,2.5,8.2,9.2]:
					hero.idle_time = seconds
					hero._pose()
					assert(hero.upper_display_point(record.pelvis).distance_to(waist)<0.000001,"all Hero variants pin the displayed waist during their own idle motion")
					assert(absf(hero.upper_display_point(head_axis[0]).distance_to(hero.upper_display_point(head_axis[1]))-head_distance)<0.000001,"actual opaque head-axis pixels retain rigid shape in every hairstyle/species")
					for leg in range(2): assert(hero._legs[leg][0].global_position.distance_to(pinned_hips[leg])<0.000001,"all Hero variant hips remain fixed during breath and camera check")
					assert(_assert_upper_surface(hero),"bounded upper-body mesh remains connected and lit")
				hero.idle_time = 0.0
				var maximum_knee := 0.0
				for phase in range(32):
					hero.travel = float(phase)/32.0*hero._stride(false)
					hero.blend = 1.0
					hero.speed = 0.0
					hero._pose()
					_assert_fixed_role_bones(hero,"Hero "+view)
					assert(_assert_leg_outline(hero),"Hero outline must stay behind protected garment")
					assert(_assert_upper_surface(hero),"actual walk torso remains connected with uploaded normals")
					for leg in range(2):
						var hip_pixel := Vector2(record.hips[leg][0],record.hips[leg][1])
						assert(hero.upper_display_point(hip_pixel).distance_to(hero._legs[leg][0].global_position)<0.000001,"counterphase shoulder motion cannot drift either source hip attachment")
					for leg in range(2):
						maximum_knee = maxf(maximum_knee,_knee_bend_degrees(hero,leg))
						assert(hero._legs[leg][0].position.distance_to(hero._pose_ankles[leg])<hero.upper_bone_length+hero.lower_bone_length,"Hero sampled ankle remains inside actual fixed reach")
						var boot: Sprite3D = hero._boots[leg]
						assert(is_equal_approx(boot.pixel_size,Rig.PIXEL_SIZE*record.boot_scale),"Hero bone correction cannot shrink source boots")
						var boot_size: Vector2 = record.boot_image.get_size()
						var rendered_sole: Vector3 = boot.global_transform*(Vector3((record.boot_center-boot_size.x*0.5)*boot.pixel_size,(boot_size.y*0.5-record.sole)*boot.pixel_size,0)+hero._boot_contact_offset[leg])
						assert(rendered_sole.distance_to(hero.boot_contact_world[leg])<0.00001,"Hero measured source heel/toe/flat sole retains its physical contact plane")
						var actual_source_ankle: Vector3 = boot.to_local(hero.to_global(hero._pose_ankles[leg]))
						var expected_source_ankle := Vector3((record.boot_center-boot_size.x*0.5)*boot.pixel_size,(boot_size.y*0.5-record.sole)*boot.pixel_size+record.ankle_height,-0.045*hero.leg_length_scale)
						assert(actual_source_ankle.distance_to(expected_source_ankle)<0.00001,"toe-off foot orientation must feed the connected anatomical ankle IK, not detach the boot")
				print("HERO_PIVOT_VARIANT species=%s outfit=%s view=%s camera_up_y=%.4f neutral_max_deg=%.2f walk_max_deg=%.2f" % [profile.species,profile.outfit,view,projection.y.y,neutral_max,maximum_knee])
	return true

func _translated_image(source: Image, offset: Vector2i) -> Image:
	var translated := Image.create(source.get_width(),source.get_height(),false,Image.FORMAT_RGBA8)
	translated.fill(Color.TRANSPARENT)
	translated.blit_rect(source,Rect2i(Vector2i.ZERO,source.get_size()),offset)
	return translated

func _assert_leg_outline(actor) -> bool:
	var outline: StandardMaterial3D = actor._materials[0].next_pass
	assert(outline!=null and outline==actor._materials[1].next_pass,"one cached hull material serves both legs")
	assert(outline.grow and outline.cull_mode==BaseMaterial3D.CULL_FRONT and not outline.no_depth_test)
	assert(outline.shading_mode==BaseMaterial3D.SHADING_MODE_PER_PIXEL and outline.albedo_color==Rig.LEG_OUTLINE_INK,"outline retains scene lighting and opaque source-style ink")
	assert(outline.grow_amount>0.0 and outline.grow_amount<0.003*actor.leg_length_scale,"growth is strictly smaller than original cuff-to-garment clearance")
	for leg in range(2):
		var buffer = actor._legs[leg][3]
		for index in range(Rig.RING*2):
			var grown: Vector3 = buffer.positions[index]+buffer.normals[index]*outline.grow_amount
			var source_plane: Vector3 = actor._upper_pivot.basis.inverse()*grown
			assert(source_plane.z<=-0.003*actor.leg_length_scale*0.25+0.000001,"actual uploaded proximal hull stays behind immutable shorts/garment paint in every sampled view")
	return true

func _assert_upper_surface(actor) -> bool:
	var points: PackedVector3Array = actor._upper_positions
	assert(points.size()<=128 and actor._upper_vertex_bytes.size()==points.size()*20,"Hero upper mesh and upload storage remain bounded cached resources")
	for row in range(actor._upper_rows.size()-1):
		var a := points[row*2]
		var b := points[row*2+1]
		var c := points[(row+1)*2]
		var d := points[(row+1)*2+1]
		assert((c-a).cross(b-a).z>0.000001 and (c-b).cross(d-b).z>0.000001,"measured hanging-hair boundary must not invert or collapse torso triangles")
	for index in range(points.size()):
		var normal: Vector3 = actor._upper_normals[index]
		assert(absf(normal.length()-1.0)<0.00001,"deformed Hero torso keeps unit shaded normals")
		var offset := points.size()*12+index*8
		var decoded := Vector3.octahedron_decode(Vector2(actor._upper_vertex_bytes.decode_u16(offset)/65535.0,actor._upper_vertex_bytes.decode_u16(offset+2)/65535.0))
		assert(decoded.dot(normal)>0.9999,"uploaded torso lighting normals match actual cached geometry")
	return true

func _inside_lower(boxes: Array, point: Vector2i) -> bool:
	for values: Array in boxes:
		if Rig.rectangle(values).grow(1).has_point(point): return true
	return false

func _assert_full_trouser_cut() -> void:
	var source := Image.create(280,360,false,Image.FORMAT_RGBA8)
	source.fill(Color.TRANSPARENT)
	var raw := Image.create(280,360,false,Image.FORMAT_RGBA8)
	raw.fill(Color.TRANSPARENT)
	var torso := Color(0.22,0.34,0.78,1.0)
	var green_pants := Color(0.10,0.46,0.18,1.0)
	var boot_color := Color(0.08,0.10,0.16,1.0)
	for image in [source,raw]:
		image.fill_rect(Rect2i(130,80,20,120),torso)
		image.fill_rect(Rect2i(108,250,16,80),green_pants)
		image.fill_rect(Rect2i(160,250,16,80),green_pants)
		image.fill_rect(Rect2i(108,330,16,20),boot_color)
		image.fill_rect(Rect2i(160,330,16,20),boot_color)
	var full_pants_metadata := {
		"skin_rect": [132,90,8,8],
		"boot": [100,330,80,20],
		"lower": [[108,250,16,15],[160,250,16,15],[108,330,16,20],[160,330,16,20]],
		"pelvis": [140,260],
		"hip_points": [[112,268],[164,268]],
		"hip_half_width_px": [3.0,3.0],
		"opening_spans": [[109.0,115.0],[161.0,167.0]],
		"limb_envelopes": [[100,248,32,104],[152,248,32,104]],
		"limb_garment_max_y": 275,
		"garment_guards": [[112,300,3,3]],
	}
	var measured := Rig.prepare_source(source,raw,full_pants_metadata,"fixture/full-pants-role")
	assert(measured.valid, "teal/green full-pants source validates without warm-skin garment classification: " + str(measured.reason))
	var upper: Image = measured.upper
	var garment: PackedByteArray = measured.garment_mask
	var limbs: PackedByteArray = measured.limb_mask
	assert(Rig.is_garment_color(raw.get_pixel(108,275)), "synthetic trouser color enters the connected non-skin garment mask")
	for x in range(108,124):
		assert(upper.get_pixel(x,275) == source.get_pixel(x,275), "pixels at the measured garment cutoff remain byte-identical")
		assert(upper.get_pixel(x,276).a == 0 and limbs[276*280+x] == 1, "connected opaque trouser pixels below the cut become limb-owned mesh source")
		if x<112 or x>=115:
			assert(upper.get_pixel(x,300).a == 0, "unprotected lower-leg pixels remain removable around an authored guard")
	for y in range(300,303):
		for x in range(112,115):
			var index := y*280+x
			assert(upper.get_pixel(x,y) == source.get_pixel(x,y) and garment[index] == 1 and limbs[index] == 0, "measured garment guard restores exact source pixels after the lower-leg cut")
	assert(upper.get_pixel(140,150) == source.get_pixel(140,150), "non-limb source color remains exactly intact")

func _synthetic_source(actor_role: String, view: String, look: Dictionary, outfit: Dictionary) -> Dictionary:
	if actor_role not in ["short_npc", "measured_ticket", "measured_announcer", "unmeasured_npc"] or view not in ["left", "right"]:
		return {}
	var frame: int = _source_renderer.walk_idle_frame(view)
	return {
		"source": _source_renderer.texture(look, outfit, view, frame, "walk").get_image(),
		"raw": _source_renderer._walk_pose_image(view, frame),
	}

func _ground_height(_point: Vector2) -> float:
	return _ground_y
