extends SceneTree

const View = preload("res://game/minigames/fountain_jump_view.gd")
const AvatarRendererScript = preload("res://game/world/avatar_renderer.gd")
const FountainModel = preload("res://game/minigames/fountain_jump_model.gd")

var _failures: Array[String] = []
var _checks := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var view := View.new()
	root.add_child(view)
	view.initialize()
	view.configure_avatar(AvatarRendererScript.DEFAULT_APPEARANCE, {"outfit":"outfit-tide", "hat":"hat-none"})
	await process_frame
	var viewport: SubViewport = view.sub_viewport()
	var world: Node3D = view.world_root()
	var camera: Camera3D = view.camera()
	_check(viewport != null and viewport.size == Vector2i(1280, 720), "view owns an isolated 1280x720 render target")
	_check(viewport != null and viewport.own_world_3d and viewport.render_target_update_mode == SubViewport.UPDATE_ALWAYS, "world renders independently for texture composition")
	_check(camera != null and camera.current and camera.projection == Camera3D.PROJECTION_ORTHOGONAL, "fixed close three-quarter orthographic camera is active")
	_check(view.get_texture() != null, "parent-facing texture API returns the SubViewport render target")
	_check(view.content_bounds() == Rect2(142.0,130.0,996.0,550.0) and view.content_bounds().position.y >= 130.0, "declared play content stays below the safe HUD strip")
	var avatar := view.avatar_sprite()
	var projected_stage := _projected_geometry_bounds(world, camera, avatar if view.avatar_available() else null)
	print("FOUNTAIN_PROJECTED_STAGE: " + str(projected_stage))
	_check(_inside_safe_frame(projected_stage), "actual projected mesh AABBs and full avatar canvas avoid HUD and viewport edges")
	_check(world.get_node_or_null("CourtFloor") is MeshInstance3D and world.get_node_or_null("BasinBody") is MeshInstance3D and world.get_node_or_null("NozzleBrassCap") is MeshInstance3D, "scene contains a tiled court, layered fountain basin, and shaped nozzle pedestal")
	_check(world.get_node_or_null("StagePier0") is MeshInstance3D and world.get_node_or_null("CanopyScallop6") is MeshInstance3D and world.get_node_or_null("WaterClockBell") is MeshInstance3D, "local fountain stage has restrained harbor-court architecture")
	_check(world.get_node_or_null("FrontStep0") is MeshInstance3D and world.get_node_or_null("PierInset0") is MeshInstance3D and world.get_node_or_null("BasinShell5") is MeshInstance3D and world.get_node_or_null("BasinWaveInlay5") is MeshInstance3D, "front approach, framed supports, and small sculpted shell/wave details finish the pavilion")
	var sun := world.get_node_or_null("SunAndStageKey") as DirectionalLight3D
	var bounce := world.get_node_or_null("WaterBounce") as OmniLight3D
	var fountain_light := world.get_node_or_null("BasinWaterGlow") as OmniLight3D
	var lantern_light := world.get_node_or_null("StageLanternLight") as OmniLight3D
	var hero_light := world.get_node_or_null("HeroLanternBounce") as OmniLight3D
	_check(sun != null and sun.shadow_enabled and sun.directional_shadow_mode == DirectionalLight3D.SHADOW_ORTHOGONAL, "real key lighting computes scene shadows")
	_check(bounce != null and bounce.light_energy >= 1.0 and bounce.omni_range > 6.0 and not bounce.shadow_enabled and hero_light != null and hero_light.omni_range >= 2.5, "broad stage fill and a close lantern bounce illuminate the visitor with real positional lights")
	_check(fountain_light != null and fountain_light.light_energy > 0.0 and lantern_light != null and lantern_light.light_energy > 0.0, "basin and built-in stage lantern have real local lights")
	_check(avatar != null and avatar.billboard == BaseMaterial3D.BILLBOARD_ENABLED and avatar.centered and avatar.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST, "avatar uses a centered pixel-faithful billboard")
	_check(avatar != null and avatar.alpha_cut == SpriteBase3D.ALPHA_CUT_DISCARD and avatar.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON, "authored silhouette participates in depth and real light shadow passes")
	_check(avatar != null and avatar.texture != null and avatar.texture.get_size() == Vector2(AvatarRendererScript.CANVAS_SIZE), "AvatarRenderer supplies its complete uncropped 280x360 texture canvas")
	_check(view.avatar_available(), "selected full-body idle pose resolved")
	if avatar != null:
		var expected_foot := (AvatarRendererScript.FEET_BASELINE - AvatarRendererScript.CANVAS_SIZE.y * 0.5) * avatar.pixel_size + 0.02
		_check(is_equal_approx(avatar.position.y, expected_foot), "sprite center offset preserves authored feet baseline on the front landing")
		var basin_front_edge := (world.get_node("BasinBody") as Node3D).position.z - 1.72
		_check(avatar.global_position.z < basin_front_edge - 0.5, "visitor's complete billboard plane stands physically in front of the basin rim")
		var shoe_baseline := avatar.global_position.y - (AvatarRendererScript.FEET_BASELINE - AvatarRendererScript.CANVAS_SIZE.y * 0.5) * avatar.pixel_size
		_check(is_equal_approx(shoe_baseline, 0.02) and shoe_baseline >= 0.0, "authored shoe baseline stays grounded at the modeled front-stage tread")
		var sprite_half := AvatarRendererScript.CANVAS_SIZE.y * avatar.pixel_size * 0.5
		var sprite_up := camera.global_basis.y * sprite_half
		_check(_inside_content(camera.unproject_position(avatar.global_position - sprite_up), view.content_bounds()) and _inside_content(camera.unproject_position(avatar.global_position + sprite_up), view.content_bounds()), "complete sprite canvas projects inside the declared play bounds")
	_check(_descendant_count(world) > 45, "the miniature stage is assembled from finite authored scene geometry")
	var initial_nodes := _descendant_count(world)
	var center_jet := world.get_node("WaterJet2") as MeshInstance3D
	var center_crest := world.get_node("JetCrest2") as MeshInstance3D
	var first_stream_mesh: Mesh = center_jet.mesh
	var first_stream_material: Material = center_jet.material_override
	var stream_meshes: Array[Mesh] = []
	var stream_materials: Array[Material] = []
	for index in 5:
		stream_meshes.append((world.get_node("WaterJet%d" % index) as MeshInstance3D).mesh)
		stream_materials.append((world.get_node("WaterJet%d" % index) as MeshInstance3D).material_override)
	_check(first_stream_mesh is ArrayMesh and first_stream_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size() >= 72, "jet uses curved triangulated water ribbons instead of a solid cone")
	_check(first_stream_material is StandardMaterial3D and (first_stream_material as StandardMaterial3D).transparency == BaseMaterial3D.TRANSPARENCY_ALPHA, "water ribbons remain translucent so the other stream lines read through them")
	_check(center_crest.mesh is TorusMesh, "crest is a thin spray ring, not a ball")
	for attempt in 3:
		var beat := FountainModel.beat_time(attempt)
		view.update_frame({"phase":beat,"fountain_attempts":attempt,"fountain_jump_started":-1.0,"beat_window":true}, "noon", false)
		var measured := center_jet.scale.y
		var expected := view.timed_jet_height_pixels(beat,attempt,false) * view.WATER_PIXELS_TO_WORLD
		_check(is_equal_approx(measured, expected), "three jump cycles %d place actual middle-jet mesh at its matching model crest" % (attempt+1))
		_check(measured > 1.29 and center_crest.position.y > 1.9, "matching beat visibly raises the actual water mesh and crest marker")
		_check(_inside_content(camera.unproject_position(center_crest.global_position), view.content_bounds()), "water crest projects inside the viewport safe content rectangle")
		var stream_top: Vector3 = center_jet.global_transform * Vector3(0.0, 1.0, 0.0)
		var stream_base: Vector3 = center_jet.global_transform * Vector3(0.0, 0.0, 0.0)
		_check(_inside_content(camera.unproject_position(stream_top), view.content_bounds()) and _inside_content(camera.unproject_position(stream_base), view.content_bounds()), "complete center stream from nozzle to timed crest stays inside camera-safe bounds")
		_check(_inside_safe_frame(_projected_geometry_bounds(world, camera, avatar if view.avatar_available() else null)), "all actual stage meshes and avatar remain inside safe frame at peak %d" % (attempt+1))
		view.update_frame({"phase":beat-0.22,"attempt":attempt,"jump_started":-1.0}, "noon", false)
		_check(center_jet.scale.y < measured, "pre-beat charge height differs causally from the timed peak")
		view.update_frame({"phase":beat-FountainModel.interval(attempt)-0.05,"attempt":attempt,"jump_started":-1.0}, "noon", false)
		_check(is_equal_approx(center_jet.scale.y, view.HIT_HEIGHT_BASE * view.WATER_PIXELS_TO_WORLD), "central crest rests low before the phrase's final interval %d" % (attempt+1))
	_check_count_in(view, world)
	var last_beat := FountainModel.beat_time(2)
	view.update_frame({"phase":last_beat,"fountain_attempts":2,"fountain_jump_started":last_beat,"beat_window":true}, "noon", false)
	_check(view._last_avatar_pose == "jump_0" and avatar.position.y > (AvatarRendererScript.FEET_BASELINE - 180.0) * avatar.pixel_size, "starting a jump selects authored frame and moves the complete sprite on the model arc")
	var airborne_y := avatar.position.y
	view.update_frame({"phase":last_beat + 4.0/12.0,"fountain_attempts":2,"fountain_jump_started":last_beat}, "noon", false)
	_check(avatar.position.y > airborne_y and view._last_avatar_pose.begins_with("jump_"), "mid-arc uses an authored jump frame and measured lift")
	_check(_inside_safe_frame(_projected_geometry_bounds(world, camera, avatar)), "full airborne avatar and all actual 3D geometry remain inside the HUD-safe frame")
	var landed_phase := last_beat + view.JUMP_DURATION + 0.05
	view.update_frame({"phase":landed_phase,"fountain_attempts":3,"fountain_jump_started":last_beat,"fountain_grades":["完美","準確","完美"]}, "noon", false)
	_check(view._last_avatar_pose == "idle" and is_equal_approx(avatar.position.y,(AvatarRendererScript.FEET_BASELINE - 180.0) * avatar.pixel_size + 0.02), "post-landing returns to authored idle with the feet still grounded")
	_check(view.splash_visible(), "landing shows a ripple at the visitor's feet right after the authored jump ends")
	var gems := view.grade_gem_colors()
	_check(gems.size() == 3 and gems[0] == view.GRADE_COLORS["完美"] and gems[1] == view.GRADE_COLORS["準確"] and gems[2] == view.GRADE_COLORS["完美"], "three grade gems keep each jump's actual grade color")
	view.update_frame({"phase":landed_phase + view.SPLASH_SECONDS,"fountain_attempts":3,"fountain_jump_started":last_beat,"fountain_grades":["完美","準確","完美"]}, "noon", false)
	_check(not view.splash_visible(), "the landing ripple ends after its fixed duration")
	var first_beat := FountainModel.beat_time(0)
	view.update_frame({"phase":first_beat,"attempt":0,"jump_started":first_beat}, "noon", true)
	_check(is_equal_approx(center_jet.scale.y,108.0*view.WATER_PIXELS_TO_WORLD), "reduced motion keeps the model's stable 108-pixel water cue")
	_check(is_equal_approx(avatar.position.y,(AvatarRendererScript.FEET_BASELINE - 180.0) * avatar.pixel_size + 0.02), "reduced motion disables vertical jump travel")
	var noon_energy := sun.light_energy
	var noon_sky := view._sky_material.sky_top_color
	var night_fill := 0.0
	for phase_name in ["dusk","night","dawn","noon"]:
		view.update_frame({"phase":1.0,"attempt":0,"jump_started":-1.0}, phase_name, true)
		_check(sun.light_energy != noon_energy or view._sky_material.sky_top_color != noon_sky, "dawn/dusk/night/noon update actual light and sky resources")
		if phase_name == "night":
			night_fill = bounce.light_energy
			_check(bounce.light_energy >= 2.5 and fountain_light.light_energy >= 1.2 and lantern_light.light_energy >= 0.9 and hero_light.light_energy >= 2.0, "night phase strengthens real local light on the face, basin, and lantern")
		noon_energy = sun.light_energy
		noon_sky = view._sky_material.sky_top_color
	_check(_descendant_count(world) == initial_nodes, "per-frame updates reuse the original nodes and meshes")
	_check(center_jet.mesh == first_stream_mesh and center_jet.material_override == first_stream_material and night_fill > 0.0, "phase and timing updates reuse cached stream meshes/materials")
	for index in 5:
		var reused_jet := world.get_node("WaterJet%d" % index) as MeshInstance3D
		_check(reused_jet.mesh == stream_meshes[index] and reused_jet.material_override == stream_materials[index], "stream %d keeps its original mesh and material resources" % index)
	view.update_frame({"phase":first_beat,"attempt":0,"jump_started":-1.0}, "noon", true)
	for index in [0, 1, 3, 4]:
		_check(is_equal_approx((world.get_node("WaterJet%d" % index) as MeshInstance3D).scale.y, 78.0 * view.WATER_PIXELS_TO_WORLD), "reduced motion holds side jet %d still" % index)
	view.update_frame({"phase":FountainModel.counts(0)[0].time + 0.01,"attempt":0,"jump_started":-1.0}, "noon", true)
	_check(view.beat_lamp_colors()[0] == view.LAMP_COUNT, "reduced motion still lights the first count lamp")
	view.update_frame({"phase":NAN,"attempt":-12,"jump_started":INF}, "unknown", false)
	_check(is_finite(center_jet.scale.y) and center_jet.scale.y > 0.0 and view._last_phase == "noon", "non-finite snapshot values and invalid time phases take safe finite defaults")
	var missing := View.new()
	root.add_child(missing)
	missing.initialize()
	missing.configure_avatar({}, {})
	missing.update_frame({}, "night", false)
	_check(missing.get_texture() != null and missing.sub_viewport().size == Vector2i(1280,720), "resource degradation keeps a renderable stage instead of raising a runtime error")
	print("FountainJumpView tests: %d checks, %d failures" % [_checks, _failures.size()])
	for failure in _failures:
		printerr("FAIL: " + failure)
	quit(0 if _failures.is_empty() else 1)

## Side jets surge on sounded counts, rests stay calm, and the lamp row tracks
## counts, the rest and the jump lamp from the shared phrase schedule.
func _check_count_in(view: Control, world: Node3D) -> void:
	for attempt in FountainModel.phrase_count():
		var counts: Array[Dictionary] = FountainModel.counts(attempt)
		for count in counts:
			var jet_index: int = FountainModel.COUNT_JETS[int(count.slot)]
			var jet := world.get_node("WaterJet%d" % jet_index) as MeshInstance3D
			view.update_frame({"phase":float(count.time) - 0.02,"attempt":attempt,"jump_started":-1.0}, "noon", false)
			var before := jet.scale.y
			view.update_frame({"phase":float(count.time) + 0.01,"attempt":attempt,"jump_started":-1.0}, "noon", false)
			if bool(count.sounded):
				_check(jet.scale.y > before + 0.4, "phrase %d count %d surges its side jet" % [attempt + 1, int(count.slot) + 1])
				_check(view.beat_lamp_colors()[int(count.slot)] == view.LAMP_COUNT, "phrase %d count %d lights its lamp" % [attempt + 1, int(count.slot) + 1])
			else:
				_check(is_equal_approx(jet.scale.y, before), "phrase %d rest %d keeps its jet calm" % [attempt + 1, int(count.slot) + 1])
				_check(view.beat_lamp_colors()[int(count.slot)] == view.LAMP_REST, "phrase %d rest %d shows the rest lamp color" % [attempt + 1, int(count.slot) + 1])
		view.update_frame({"phase":FountainModel.beat_time(attempt),"attempt":attempt,"jump_started":-1.0,"beat_window":true}, "noon", false)
		var lamps: Array[Color] = view.beat_lamp_colors()
		_check(lamps.size() == counts.size() + 1 and lamps[-1] == view.LAMP_JUMP, "phrase %d jump lamp is brightest on the judged beat" % (attempt + 1))
	_check(FountainModel.phrase(2).pattern.has(false), "the final phrase teaches a silent rest before the jump")
	_check(FountainModel.interval(1) < FountainModel.interval(0), "the second phrase is quicker than the first")

func _check(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(description)

func _descendant_count(node: Node) -> int:
	var total := 1
	for child in node.get_children():
		total += _descendant_count(child)
	return total

func _inside_content(point: Vector2, bounds: Rect2) -> bool:
	return bounds.has_point(point)

func _inside_safe_frame(bounds: Rect2) -> bool:
	return bounds.position.x >= 130.0 and bounds.end.x <= 1150.0 and bounds.position.y >= 130.0 and bounds.end.y <= 680.0

func _projected_geometry_bounds(world: Node3D, camera: Camera3D, avatar: Sprite3D) -> Rect2:
	var points: Array[Vector2] = []
	for candidate in world.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := candidate as MeshInstance3D
		if not mesh_node.visible or mesh_node.mesh == null:
			continue
		var local_bounds := mesh_node.mesh.get_aabb()
		for corner in 8:
			var local_point := local_bounds.position + Vector3(
				local_bounds.size.x if (corner & 1) != 0 else 0.0,
				local_bounds.size.y if (corner & 2) != 0 else 0.0,
				local_bounds.size.z if (corner & 4) != 0 else 0.0
			)
			points.append(camera.unproject_position(mesh_node.global_transform * local_point))
	if avatar != null:
		var half := avatar.texture.get_size() * avatar.pixel_size * 0.5
		var right := avatar.global_basis.x * half.x
		var up := avatar.global_basis.y * half.y
		for sx in [-1.0, 1.0]:
			for sy in [-1.0, 1.0]:
				points.append(camera.unproject_position(avatar.global_position + right * sx + up * sy))
	if points.is_empty():
		return Rect2()
	var left := points[0].x
	var right_edge := points[0].x
	var top := points[0].y
	var bottom := points[0].y
	for point in points:
		left = minf(left, point.x)
		right_edge = maxf(right_edge, point.x)
		top = minf(top, point.y)
		bottom = maxf(bottom, point.y)
	return Rect2(Vector2(left, top), Vector2(right_edge-left, bottom-top))
