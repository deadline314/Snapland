extends "res://game/tests/native_review.gd"
## Native review for ART-10/11/13 in the real Main scene.
## Scripted fixture: rendering inspection and real key input; not human play.
## Output goes to SNAPLAND_REVIEW_OUT (absolute directory) so evidence is chosen
## and copied deliberately instead of overwriting committed images.

const Daylight = preload("res://game/core/time_of_day.gd")

var out_dir := ""
var report := {"scripted_fixture": true, "human_played": false, "renderer": "", "lighting": [], "occlusion": []}


func _run() -> void:
	out_dir = OS.get_environment("SNAPLAND_REVIEW_OUT")
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.get_environment("SNAPLAND_SAVE_PATH").is_empty() or DisplayServer.get_name() == "headless" or not out_dir.is_absolute_path():
		push_error("Native light/occlusion review needs a display, isolated SNAPLAND_SAVE_PATH and absolute SNAPLAND_REVIEW_OUT")
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(out_dir)
	progress = get_tree().root.get_node_or_null("Progress")
	if progress == null:
		push_error("Progress autoload is missing")
		get_tree().quit(1)
		return
	progress.reset_progress()
	progress.intro_seen = true
	main = _instantiate_main()
	if main == null:
		get_tree().quit(1)
		return
	get_tree().root.add_child(main)
	get_window().size = Vector2i(1280, 720)
	await get_tree().create_timer(1.5).timeout
	report.renderer = RenderingServer.get_video_adapter_name() + " / " + RenderingServer.get_current_rendering_method()
	var modes := OS.get_cmdline_user_args()
	if modes.is_empty() or modes.has("--lighting"):
		if not await _review_lighting(): return
	if modes.is_empty() or modes.has("--occlusion"):
		if not await _review_occlusion(modes.has("--video")): return
	_write_report()
	print("PASS: native light/occlusion review captures written to ", out_dir)
	await main._quit_game()


func _write_report() -> void:
	var file := FileAccess.open(out_dir.path_join("report.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t"))
		file.close()


func _save(name: String) -> bool:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(out_dir.path_join(name + ".png"))
	if error != OK:
		await _fail("Capture failed: " + name)
		return false
	var captures: Array = report.get("captures", [])
	captures.append({"name":name,"reduced_motion":main.world.reduced_motion,"phase":main.world.active_time_phase})
	report["captures"]=captures
	return true


## Optional "--phase=dawn" style filters narrow a diagnosis run.
func _selected_phases() -> Array[String]:
	var chosen: Array[String] = []
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--phase="): chosen.append(arg.trim_prefix("--phase="))
	return chosen if not chosen.is_empty() else Daylight.phase_ids()


func _frames(count: int) -> void:
	for _index in range(count): await get_tree().process_frame


func _place(position: Vector3, settle := 0.6) -> void:
	main.world.player.position = position
	main.world.player.velocity = Vector3.ZERO
	await get_tree().create_timer(settle).timeout


func _review_lighting() -> bool:
	var lighting_failures: Array[Dictionary] = []
	var phases := _selected_phases()
	var views := {"plaza": Vector3(0, 0.4, -6), "kiosks": Vector3(-6, 0.4, 3), "arch": Vector3(0, 0.4, -14), "harbor": Vector3(2, 0.4, 10)}
	for phase_id in phases:
		if not main._select_time_phase(phase_id):
			await _fail("Main rejected phase " + phase_id)
			return false
		for view_name in views:
			await _place(views[view_name])
			if not await _save("light-%s-%s" % [phase_id, view_name]): return false
		await _place(views.plaza)
		var casters := _plaza_casters()
		for caster in casters:
			var key_result: Dictionary = await _measure_shadow(caster, phase_id, "key")
			report.lighting.append(key_result)
			if not bool(key_result.pass): lighting_failures.append(key_result)
		if phase_id in ["dusk", "night"]:
			for caster in casters.slice(0, 4):
				var lamp_result: Dictionary = await _measure_shadow(caster, phase_id, "lamp")
				report.lighting.append(lamp_result)
				if not bool(lamp_result.pass):
					lighting_failures.append(lamp_result)
		var glow: Dictionary = await _measure_lamp_glow(phase_id, false)
		report.lighting.append(glow)
		if not bool(glow.pass): lighting_failures.append(glow)
	# Reduced motion must keep the same necessary lighting.
	main._select_time_phase("night")
	main.world.apply_settings({"reduced_motion": true})
	await _place(Vector3(0, 0.4, -6))
	var reduced: Dictionary = await _measure_lamp_glow("night", true)
	report.lighting.append(reduced)
	var reduced_sun: bool = main.world.sun.shadow_enabled and main.world.sun.light_energy > 0.0
	if not bool(reduced.pass) or not reduced_sun: lighting_failures.append(reduced)
	_write_report()
	if not lighting_failures.is_empty():
		await _fail("Lighting checks failed: " + JSON.stringify(lighting_failures))
		return false
	if not await _save("light-night-reduced-plaza"): return false
	main.world.apply_settings({"reduced_motion": false})
	main._select_time_phase("noon")
	return true


## One player, three NPCs, a tree, a lamp post and a kiosk near the plaza view.
func _plaza_casters() -> Array[Dictionary]:
	var world = main.world
	var casters: Array[Dictionary] = []
	for record in world.actor_shadow_proxies:
		var proxy := record.node as Node3D
		var geometry: Array[GeometryInstance3D] = []
		for child in proxy.get_children():
			if child is GeometryInstance3D and child.visible: geometry.append(child)
		casters.append({"name": "actor-" + str(record.role), "geometry": geometry, "base": proxy.global_position, "height": 1.5})
	var view_center: Vector3 = world.player.global_position
	var best_trunk: MeshInstance3D = null
	for node in world.find_children("TreeShadowTrunk*", "MeshInstance3D", true, false):
		var screen: Vector2 = world.camera.unproject_position(node.global_position)
		if not get_viewport().get_visible_rect().grow(-140).has_point(screen): continue
		if best_trunk == null or node.global_position.distance_to(view_center) < best_trunk.global_position.distance_to(view_center):
			best_trunk = node
	if best_trunk != null:
		var trunk_height := float((best_trunk.mesh as CylinderMesh).height)
		var tree_base := best_trunk.global_position - Vector3(0, trunk_height * 0.5, 0)
		var tree_geometry: Array[GeometryInstance3D] = [best_trunk]
		for crown in world.find_children("TreeShadowCrown*", "MeshInstance3D", true, false):
			if Vector2(crown.global_position.x, crown.global_position.z).distance_to(Vector2(tree_base.x, tree_base.z)) < 0.05:
				tree_geometry.append(crown)
		casters.append({"name": "tree", "geometry": tree_geometry, "base": tree_base, "height": trunk_height * 2.0})
		var trunk_only: Array[GeometryInstance3D] = [best_trunk]
		casters.append({"name": "tree-trunk", "geometry": trunk_only, "base": tree_base, "height": trunk_height})
	var nearest_lamp: Light3D = null
	for lamp in world.lamps:
		var screen: Vector2 = world.camera.unproject_position(lamp.global_position)
		if not get_viewport().get_visible_rect().grow(-140).has_point(screen): continue
		if nearest_lamp == null or lamp.global_position.distance_to(view_center) < nearest_lamp.global_position.distance_to(view_center):
			nearest_lamp = lamp
	if nearest_lamp != null:
		var lamp_xz := Vector2(nearest_lamp.global_position.x, nearest_lamp.global_position.z)
		var lamp_geometry: Array[GeometryInstance3D] = []
		for mesh in world.find_children("*", "MeshInstance3D", true, false):
			var mesh_instance := mesh as MeshInstance3D
			if mesh_instance.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF or not mesh_instance.is_visible_in_tree(): continue
			var center: Vector3 = mesh_instance.global_transform * mesh_instance.get_aabb().get_center()
			if Vector2(center.x, center.z).distance_to(lamp_xz) < 0.4 and center.y < nearest_lamp.global_position.y + 0.6:
				lamp_geometry.append(mesh_instance)
		var lamp_base := Vector3(lamp_xz.x, world._ground_surface_y(nearest_lamp.global_position), lamp_xz.y)
		casters.append({"name": "lamp-post", "geometry": lamp_geometry, "base": lamp_base, "height": nearest_lamp.global_position.y - lamp_base.y})
	for kind_part in [["Planter", "Pot"], ["Shrub", "Dome"]]:
		var kind: String = kind_part[0]
		var best_volume: MeshInstance3D = null
		for node in world.find_children(kind + "Shadow" + str(kind_part[1]) + "*", "MeshInstance3D", true, false):
			var screen: Vector2 = world.camera.unproject_position(node.global_position)
			if not get_viewport().get_visible_rect().grow(-140).has_point(screen): continue
			if best_volume == null or node.global_position.distance_to(view_center) < best_volume.global_position.distance_to(view_center):
				best_volume = node
		if best_volume == null: continue
		var volume_xz := Vector2(best_volume.global_position.x, best_volume.global_position.z)
		var volumes: Array[GeometryInstance3D] = []
		for node in world.find_children(kind + "Shadow*", "MeshInstance3D", true, false):
			if Vector2(node.global_position.x, node.global_position.z).distance_to(volume_xz) < 0.05: volumes.append(node)
		var volume_base := Vector3(volume_xz.x, world._ground_surface_y(best_volume.global_position), volume_xz.y)
		casters.append({"name": kind.to_lower(), "geometry": volumes, "base": volume_base, "height": 1.8})
	var kiosk_center := Vector3(8, 0, 5)
	var kiosk_geometry: Array[GeometryInstance3D] = []
	for mesh in world.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := mesh as MeshInstance3D
		if mesh_instance.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF or not mesh_instance.is_visible_in_tree(): continue
		var center: Vector3 = mesh_instance.global_transform * mesh_instance.get_aabb().get_center()
		if absf(center.x - kiosk_center.x) < 2.0 and absf(center.z - kiosk_center.z) < 1.5 and center.y < 4.0:
			kiosk_geometry.append(mesh_instance)
	casters.append({"name": "kiosk", "geometry": kiosk_geometry, "base": kiosk_center, "height": 2.6})
	return casters


## Renders the caster's shadow alone: its geometry casts as SHADOWS_ONLY in one
## frame and is hidden in the other. "key" disables lamp shadows; "lamp" disables
## the key shadow. The visible difference is that caster's shadow on the ground.
func _measure_shadow(caster: Dictionary, phase_id: String, source: String) -> Dictionary:
	var world = main.world
	var camera: Camera3D = world.camera
	var geometry: Array = caster.geometry
	var base: Vector3 = caster.base
	var result := {"phase": phase_id, "source": source, "caster": caster.name, "pass": false}
	if geometry.is_empty():
		result.reason = "no shadow geometry found"
		return result
	var saved_cast := {}
	var saved_visible := {}
	for item in geometry:
		saved_cast[item] = item.cast_shadow
		saved_visible[item] = item.visible
	var lamp_saved := {}
	for lamp in world.lamps: lamp_saved[lamp] = lamp.shadow_enabled
	var sun_saved: bool = world.sun.shadow_enabled
	var hidden_sprites: Array[Node3D] = []
	for sprite in world.find_children("*", "SpriteBase3D", true, false) + world.find_children("*", "Label3D", true, false):
		if sprite.visible:
			sprite.visible = false
			hidden_sprites.append(sprite)
	# Silence every other caster so ground already in a neighbour's shadow cannot
	# hide where this caster's shadow meets its base.
	var silenced := {}
	var hidden_proxies: Array[GeometryInstance3D] = []
	for node in world.find_children("*", "GeometryInstance3D", true, false):
		var other := node as GeometryInstance3D
		if geometry.has(other) or other.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF: continue
		if other.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
			if other.visible:
				other.visible = false
				hidden_proxies.append(other)
			continue
		silenced[other] = other.cast_shadow
		other.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var lamp_source: Light3D = null
	if source == "key":
		for lamp in world.lamps: lamp.shadow_enabled = false
	else:
		world.sun.shadow_enabled = false
		var nearest := INF
		for lamp in world.lamps:
			if not lamp.shadow_enabled: continue
			var distance := Vector2(lamp.global_position.x - base.x, lamp.global_position.z - base.z).length()
			if distance < nearest:
				nearest = distance
				lamp_source = lamp
		if lamp_source == null:
			result.reason = "no shadow-enabled lamp is active"
		else:
			result.lamp_distance_m = nearest
			result.lamp_range_m = (lamp_source as OmniLight3D).omni_range
			if nearest > 0.7 * (lamp_source as OmniLight3D).omni_range:
				# Only the two lamps nearest the player cast shadows. Near the edge of
				# their range the light has faded out, so no visible shadow is expected.
				result.reason = "outside shadow lamp reach"
				result.pass = true
	# OFF, ON, OFF: animated surfaces (water, flags) differ between the two OFF
	# frames and are excluded; only stable ground darkened by the caster counts.
	var tree := get_tree()
	tree.paused = true
	for item in geometry:
		item.visible = false
		item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	await _frames(3)
	await RenderingServer.frame_post_draw
	var without_shadow := get_viewport().get_texture().get_image()
	for item in geometry: item.visible = true
	await _frames(3)
	await RenderingServer.frame_post_draw
	var with_shadow := get_viewport().get_texture().get_image()
	for item in geometry: item.visible = false
	await _frames(3)
	await RenderingServer.frame_post_draw
	var without_again := get_viewport().get_texture().get_image()
	tree.paused = false
	for item in geometry:
		item.cast_shadow = saved_cast[item]
		item.visible = saved_visible[item]
	for lamp in world.lamps: lamp.shadow_enabled = lamp_saved[lamp]
	world.sun.shadow_enabled = sun_saved
	for sprite in hidden_sprites: sprite.visible = true
	for other in silenced: other.cast_shadow = silenced[other]
	for proxy in hidden_proxies: proxy.visible = true
	result.other_casters_silenced = silenced.size() + hidden_proxies.size()
	if result.has("reason"): return result
	var base_px := camera.unproject_position(base)
	var top_px := camera.unproject_position(base + Vector3.UP * float(caster.height))
	var height_px := maxf(8.0, base_px.distance_to(top_px))
	var ground_direction := Vector3.ZERO
	if source == "key":
		var ray: Vector3 = -world.sun.global_basis.z
		ground_direction = Vector3(ray.x, 0, ray.z).normalized()
	else:
		ground_direction = Vector3(base.x - lamp_source.global_position.x, 0, base.z - lamp_source.global_position.z).normalized()
	var expected_px := (camera.unproject_position(base + ground_direction) - base_px).normalized()
	var radius := clampf(height_px * 4.5, 60.0, 340.0)
	var bounds := Rect2i(Vector2i(base_px - Vector2(radius, radius)), Vector2i(int(radius * 2), int(radius * 2))).intersection(Rect2i(Vector2i.ZERO, with_shadow.get_size()))
	var attach_limit := maxf(10.0, height_px * 0.2)
	var candidates := {}
	var mask := with_shadow.duplicate() as Image
	for y in range(bounds.position.y, bounds.end.y, 2):
		for x in range(bounds.position.x, bounds.end.x, 2):
			var lit := without_shadow.get_pixel(x, y).get_luminance()
			var lit_again := without_again.get_pixel(x, y).get_luminance()
			if absf(lit - lit_again) > 2.0 / 255.0: continue
			if minf(lit, lit_again) - with_shadow.get_pixel(x, y).get_luminance() < 4.0 / 255.0: continue
			candidates[Vector2i(x, y)] = true
			mask.set_pixel(x, y, Color(0.55, 0.0, 0.55))
	# Keep the shadow region connected to the caster's base; disconnected diffs
	# (receivers such as water, or neighbouring props) are not this caster's shadow.
	var queue: Array[Vector2i] = []
	var component := {}
	var nearest_px := INF
	for point in candidates:
		var distance := Vector2(point).distance_to(base_px)
		nearest_px = minf(nearest_px, distance)
		if distance <= attach_limit:
			component[point] = true
			queue.append(point)
	while not queue.is_empty():
		var current: Vector2i = queue.pop_back()
		for dy in [-4, -2, 0, 2, 4]:
			for dx in [-4, -2, 0, 2, 4]:
				var neighbour := current + Vector2i(dx, dy)
				if candidates.has(neighbour) and not component.has(neighbour):
					component[neighbour] = true
					queue.append(neighbour)
	var count := component.size()
	var sum := Vector2.ZERO
	for point in component:
		sum += Vector2(point)
		mask.set_pixel(point.x, point.y, Color.MAGENTA)
	for offset in range(-6, 7):
		mask.set_pixel(clampi(int(base_px.x) + offset, 0, mask.get_width() - 1), clampi(int(base_px.y), 0, mask.get_height() - 1), Color.CYAN)
		var arrow := base_px + expected_px * float(offset + 6) * 4.0
		mask.set_pixel(clampi(int(arrow.x), 0, mask.get_width() - 1), clampi(int(arrow.y), 0, mask.get_height() - 1), Color.YELLOW)
	mask.get_region(bounds).save_png(out_dir.path_join("shadow-%s-%s-%s.png" % [phase_id, source, caster.name]))
	result.merge({"height_px": height_px, "shadow_samples": count, "candidate_samples": candidates.size(), "base_px": [base_px.x, base_px.y], "expected_dir": [expected_px.x, expected_px.y], "nearest_to_base_px": nearest_px, "attach_limit_px": attach_limit})
	if count < 12:
		result.reason = "no shadow attached to the caster base" if candidates.size() >= 12 else "caster shadow not visible"
		return result
	var centroid := sum / float(count)
	var observed := (centroid - base_px).normalized()
	var alignment := observed.dot(expected_px)
	result.merge({"observed_dir": [observed.x, observed.y], "alignment_cos": alignment})
	result.pass = alignment >= cos(deg_to_rad(40.0))
	if not result.pass: result.reason = "shadow direction or attachment differs from the light"
	return result


## Compares the active lamps' pools with the same frame at zero local light.
func _measure_lamp_glow(phase_id: String, reduced: bool) -> Dictionary:
	var world = main.world
	var active: Array[Light3D] = []
	for lamp in world.lamps:
		if lamp.light_energy > 0.0: active.append(lamp)
	var result := {"phase": phase_id, "source": "lamp-glow", "reduced_motion": reduced, "active_lamps": active.size(), "lamp_energy": world.lamp_energy_for_phase, "pass": false}
	if phase_id == "noon":
		result.pass = active.is_empty()
		if not result.pass: result.reason = "daylight left local lamps on"
		return result
	if active.is_empty():
		result.reason = "no lamp is lit"
		return result
	# Measure the ground pool itself: billboards standing on the pool (the lamp
	# sprite and its planter) would otherwise hide most of the sampled ground.
	var hidden_sprites: Array[Node3D] = []
	for sprite in world.find_children("*", "SpriteBase3D", true, false) + world.find_children("*", "Label3D", true, false):
		if sprite.visible:
			sprite.visible = false
			hidden_sprites.append(sprite)
	await _frames(2)
	await RenderingServer.frame_post_draw
	var lit := get_viewport().get_texture().get_image()
	var energies := {}
	for lamp in active:
		energies[lamp] = lamp.light_energy
		lamp.light_energy = 0.0
	await _frames(2)
	await RenderingServer.frame_post_draw
	var dark := get_viewport().get_texture().get_image()
	for lamp in active: lamp.light_energy = energies[lamp]
	for sprite in hidden_sprites: sprite.visible = true
	var gains: Array[float] = []
	for lamp in active:
		var center: Vector2 = world.camera.unproject_position(Vector3(lamp.global_position.x, world._ground_surface_y(lamp.global_position), lamp.global_position.z))
		if not get_viewport().get_visible_rect().has_point(center): continue
		var gain := 0.0
		var samples := 0
		for y in range(int(center.y) - 30, int(center.y) + 31, 3):
			for x in range(int(center.x) - 30, int(center.x) + 31, 3):
				if x < 0 or y < 0 or x >= lit.get_width() or y >= lit.get_height(): continue
				gain += lit.get_pixel(x, y).get_luminance() - dark.get_pixel(x, y).get_luminance()
				samples += 1
		if samples > 0: gains.append(gain / samples * 255.0)
	result.pool_gain_luma = gains
	var minimum: float = {"dawn": 1.5, "dusk": 4.0, "night": 6.0}.get(phase_id, 1.0)
	result.minimum_gain = minimum
	result.pass = not gains.is_empty() and gains.min() >= minimum
	if not result.pass: result.reason = "a lit lamp does not visibly brighten its ground pool"
	return result


# --- ART-10/11 occlusion -----------------------------------------------------

const ROUTES := {
	# Walk west behind the photo-book kiosk; its solid base blocks the direct path.
	"kiosk": {"start": Vector3(11.2, 0.4, 2.6), "key": KEY_A},
	# Walk north under the avenue arch; the beam covers the body behind it.
	"arch": {"start": Vector3(0, 0.4, -8.5), "key": KEY_W},
}


func _occlusion() -> Node:
	return main.world.occlusion_controller


## Holds a real movement key until the cutaway activates, then a little longer
## so the whole body is behind the building. Returns false if it never activates.
func _walk_until_occluded(route: Dictionary, extra := 0.18) -> bool:
	await _place(route.start, 0.7)
	if bool(_occlusion().statistics().active):
		await _fail("Route start is already occluded: " + str(route.start))
		return false
	_held_key(route.key, true)
	# Budget in physics frames, not wall time: movie recording and quarter speed
	# change how long a frame takes, never how far the route is.
	var budget := int(6.0 * Engine.physics_ticks_per_second / Engine.time_scale)
	while not bool(_occlusion().statistics().active) and budget > 0:
		budget -= 1
		await get_tree().physics_frame
	await get_tree().create_timer(extra).timeout
	_held_key(route.key, false)
	await get_tree().create_timer(0.45).timeout
	return bool(_occlusion().statistics().active)


func _walk_until_clear(route: Dictionary) -> bool:
	_held_key(route.key, true)
	var budget := int(6.0 * Engine.physics_ticks_per_second / Engine.time_scale)
	while bool(_occlusion().statistics().active) and budget > 0:
		budget -= 1
		await get_tree().physics_frame
	await get_tree().create_timer(0.3).timeout
	_held_key(route.key, false)
	await get_tree().create_timer(0.45).timeout
	return not bool(_occlusion().statistics().active) and is_zero_approx(float(_occlusion().statistics().fade_weight))


## The hero billboard only. The contact-shadow disc on the ground is not part of
## the figure and may legitimately sit under the building's edge.
func _player_visuals() -> Array[GeometryInstance3D]:
	var visuals: Array[GeometryInstance3D] = []
	if main.world.avatar.visible: visuals.append(main.world.avatar)
	return visuals


func _active_group_geometry() -> Array:
	var controller := _occlusion()
	var geometry: Array = []
	for group in controller._building_groups:
		if controller._active_group_ids.has(int(group.id)):
			for item in group.geometry:
				if is_instance_valid(item) and item.visible: geometry.append(item)
	return geometry


## Pixels the player sprite contributes to the final frame: render with and
## without the player's visuals, with the world frozen on the same pose.
func _player_mask(window: Rect2i) -> Dictionary:
	var visuals := _player_visuals()
	await _frames(2)
	await RenderingServer.frame_post_draw
	var shown := get_viewport().get_texture().get_image()
	for item in visuals: item.visible = false
	await _frames(2)
	await RenderingServer.frame_post_draw
	var hidden := get_viewport().get_texture().get_image()
	for item in visuals: item.visible = true
	await _frames(2)
	await RenderingServer.frame_post_draw
	var shown_again := get_viewport().get_texture().get_image()
	var pixels: Array[Vector2i] = []
	if OS.get_cmdline_user_args().has("--debug-masks"):
		var tag := str(Time.get_ticks_usec())
		for pair in [["shown", shown], ["hidden", hidden], ["again", shown_again]]:
			(pair[1] as Image).get_region(window.intersection(Rect2i(Vector2i.ZERO, shown.get_size()))).save_png(out_dir.path_join("mask-%s-%s.png" % [tag, pair[0]]))
	var count := 0
	var top := INF
	var bottom := -INF
	var area := window.intersection(Rect2i(Vector2i.ZERO, shown.get_size()))
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			var a := shown.get_pixel(x, y)
			var again := shown_again.get_pixel(x, y)
			if absf(a.r - again.r) + absf(a.g - again.g) + absf(a.b - again.b) > 0.03: continue
			var b := hidden.get_pixel(x, y)
			if absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) < 0.06: continue
			count += 1
			pixels.append(Vector2i(x, y))
			top = minf(top, y)
			bottom = maxf(bottom, y)
	return {"count": count, "top": top, "bottom": bottom, "image": shown, "pixels": pixels}


## Compares the visible player inside the cutaway with the same frozen pose when
## the occluding building is hidden: the opening must show the whole body.
func _probe_reveal(label: String) -> Dictionary:
	var world = main.world
	var controller := _occlusion()
	var stats: Dictionary = controller.statistics()
	var opening_center: Vector2 = stats.center_px
	var opening_radius := float(stats.radius_px)
	# The hero billboard's own projected quad: only pixels the figure can occupy.
	# Nearby sprites can shift slightly when the hero is hidden; they are not the figure.
	var frame: Dictionary = controller._reveal_frame()
	var window := Rect2i(Vector2i(opening_center - Vector2.ONE * opening_radius * 1.6), Vector2i(Vector2.ONE * opening_radius * 3.2))
	if not frame.is_empty():
		var quad := Rect2(world.camera.unproject_position(frame.centre), Vector2.ZERO)
		for sign_up in [-1.0, 1.0]:
			for sign_right in [-1.0, 1.0]:
				quad = quad.expand(world.camera.unproject_position(frame.centre + frame.half_up * sign_up + frame.half_right * sign_right))
		window = Rect2i(quad.grow(2.0))
	# Captured images are in window pixels; a resized window letterboxes the
	# 1280x720 logical view. Map logical coordinates into the captured image.
	var mapping := _image_mapping()
	window = Rect2i(_map_rect(Rect2(window), mapping))
	get_tree().paused = true
	world.set_process(false)
	world.set_physics_process(false)
	# Only the hero and the building are compared: other billboards and labels
	# (lamps, foliage, NPCs) are hidden so their alpha edges cannot count as the
	# hero or as the building.
	var hidden_billboards: Array[Node3D] = []
	for sprite in world.find_children("*", "SpriteBase3D", true, false) + world.find_children("*", "Label3D", true, false):
		if sprite != world.avatar and sprite.visible:
			sprite.visible = false
			hidden_billboards.append(sprite)
	# Freeze the opening exactly as the player sees it; hiding the avatar for the
	# mask must not let the controller recompute a different circle.
	controller.set_process(false)
	controller.set_physics_process(false)
	var cut := await _player_mask(window)
	var occluders := _active_group_geometry()
	# Screen bounds of the occluding building; the outside-the-circle check only
	# looks there, so animated water elsewhere cannot be mistaken for it.
	var building_bounds := Rect2()
	for item in occluders:
		var box: AABB = (item as VisualInstance3D).global_transform * (item as VisualInstance3D).get_aabb()
		for corner_index in range(8):
			var corner := box.get_endpoint(corner_index)
			var screen: Vector2 = main.world.camera.unproject_position(corner)
			building_bounds = Rect2(screen, Vector2.ZERO) if building_bounds.size == Vector2.ZERO and building_bounds.position == Vector2.ZERO else building_bounds.expand(screen)
	# Hide the building from the camera but keep its shadow, so a hero standing
	# in the building's shadow is compared under the same lighting.
	var original_cast := {}
	for item in occluders:
		original_cast[item] = (item as GeometryInstance3D).cast_shadow
		(item as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	var reference := await _player_mask(window)
	for item in occluders: (item as GeometryInstance3D).cast_shadow = original_cast[item]
	# Building pixels changed by the opening must stay inside the circle; the hero
	# is hidden too for these captures.
	world.avatar.visible = false
	await _frames(2)
	await RenderingServer.frame_post_draw
	var opened := get_viewport().get_texture().get_image()
	for item in occluders: (item as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	await _frames(2)
	await RenderingServer.frame_post_draw
	var without_building := get_viewport().get_texture().get_image()
	for item in occluders: (item as GeometryInstance3D).cast_shadow = original_cast[item]
	var weight := float(controller._fade_weight)
	controller._fade_weight = 0.0
	controller._update_shader_uniforms(controller._last_player_depth)
	await _frames(2)
	await RenderingServer.frame_post_draw
	var closed := get_viewport().get_texture().get_image()
	controller._fade_weight = weight
	controller._update_shader_uniforms(controller._last_player_depth)
	await _frames(2)
	await RenderingServer.frame_post_draw
	var reopened := get_viewport().get_texture().get_image()
	world.avatar.visible = true
	for sprite in hidden_billboards: sprite.visible = true
	controller.set_process(true)
	controller.set_physics_process(true)
	get_tree().paused = false
	world.set_process(true)
	world.set_physics_process(true)
	var center: Vector2 = Vector2(stats.center_px) * float(mapping.scale) + Vector2(mapping.offset)
	var radius := float(stats.radius_px) * float(mapping.scale)
	var player_frame: Image = cut.image
	var reference_image: Image = reference.image
	var outside_changes := 0
	var outside_debug: Image = (player_frame.duplicate() as Image) if OS.get_cmdline_user_args().has("--debug-masks") else null
	var inside_changes := 0
	var scan := Rect2i(_map_rect(building_bounds, mapping)).intersection(Rect2i(Vector2i.ZERO, opened.get_size()))
	for y in range(scan.position.y, scan.end.y, 2):
		for x in range(scan.position.x, scan.end.x, 2):
			var a := opened.get_pixel(x, y)
			var again := reopened.get_pixel(x, y)
			# Animated water/flags change between the two open frames; skip them.
			if absf(a.r - again.r) + absf(a.g - again.g) + absf(a.b - again.b) > 0.03: continue
			var b := closed.get_pixel(x, y)
			# Only the occluding building's own pixels: drawn when it is present.
			var without := without_building.get_pixel(x, y)
			if absf(b.r - without.r) + absf(b.g - without.g) + absf(b.b - without.b) < 0.06: continue
			if absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) < 0.06: continue
			if Vector2(x, y).distance_to(center) <= radius + 4.0: inside_changes += 1
			else:
				outside_changes += 1
				if outside_debug != null: outside_debug.set_pixel(x, y, Color.MAGENTA)
	# Every pixel the player shows with the building removed must look identical
	# through the opening; the matched head/feet rows must equal the reference.
	var matched := 0
	var matched_rows := {}
	var reference_rows := {}
	for point: Vector2i in reference.pixels:
		reference_rows[point.y] = int(reference_rows.get(point.y, 0)) + 1
		var through := player_frame.get_pixel(point.x, point.y)
		var clear := reference_image.get_pixel(point.x, point.y)
		if absf(through.r - clear.r) + absf(through.g - clear.g) + absf(through.b - clear.b) >= 0.06:
			if outside_debug != null: outside_debug.set_pixel(point.x, point.y, Color.CYAN)
			continue
		matched += 1
		matched_rows[point.y] = int(matched_rows.get(point.y, 0)) + 1
	# Head/feet rows: outermost rows with at least six figure pixels, so stray
	# edge pixels of sprites behind the hero cannot stand in for the figure.
	var reference_extent := _row_extent(reference_rows)
	var matched_extent := _row_extent(matched_rows)
	var ratio := float(matched) / maxf(1.0, float(reference.count))
	if outside_debug != null: outside_debug.save_png(out_dir.path_join("outside-" + label + ".png"))
	var result := {
		"case": label, "active": stats.active, "fade_weight": stats.fade_weight, "radius_px": radius,
		"center_px": [center.x, center.y], "viewport": [stats.viewport_size.x, stats.viewport_size.y],
		"visible_player_pixels": cut.count, "unoccluded_player_pixels": reference.count, "visible_ratio": ratio,
		"head_row": [matched_extent.x, reference_extent.x], "feet_row": [matched_extent.y, reference_extent.y],
		"building_pixels_changed_inside": inside_changes, "building_pixels_changed_outside": outside_changes,
		"building_screen_bounds": [building_bounds.position.x, building_bounds.position.y, building_bounds.size.x, building_bounds.size.y],
		"figure_window": [window.position.x, window.position.y, window.size.x, window.size.y],
		"image_scale": mapping.scale, "image_offset": [mapping.offset.x, mapping.offset.y],
		"time_phase": world.active_time_phase, "reduced_motion": controller.reduced_motion,
		"equipped": progress.equipped.duplicate(),
	}
	result.pass = bool(stats.active) and reference.count > 200 and ratio >= 0.95 and absf(matched_extent.y - reference_extent.y) <= 1.0 and absf(matched_extent.x - reference_extent.x) <= 1.0 and inside_changes > 0 and outside_changes <= 4
	report.occlusion.append(result)
	if player_frame.save_png(out_dir.path_join("occlusion-" + label + ".png")) != OK: result.pass = false
	if closed.save_png(out_dir.path_join("occlusion-" + label + "-closed.png")) != OK: result.pass = false
	print("OCCLUSION ", label, " ", JSON.stringify(result))
	return result


## Logical viewport -> captured image pixels (uniform scale plus letterbox offset).
func _image_mapping() -> Dictionary:
	var logical := get_viewport().get_visible_rect().size
	# Use a real capture: its size is what every comparison image will have.
	var image_size := Vector2(get_viewport().get_texture().get_image().get_size())
	var scale := minf(image_size.x / logical.x, image_size.y / logical.y)
	return {"scale": scale, "offset": (image_size - logical * scale) * 0.5}


func _map_rect(rect: Rect2, mapping: Dictionary) -> Rect2:
	return Rect2(rect.position * float(mapping.scale) + Vector2(mapping.offset), rect.size * float(mapping.scale))


func _row_extent(rows: Dictionary) -> Vector2:
	var top := INF
	var bottom := -INF
	for row in rows:
		if int(rows[row]) < 6: continue
		top = minf(top, float(row))
		bottom = maxf(bottom, float(row))
	return Vector2(top, bottom)


func _review_occlusion(video: bool) -> bool:
	var world = main.world
	if video:
		return await _record_occlusion_routes()
	# A building behind the player does not trigger the opening.
	await _place(Vector3(8, 0.4, 8.6))
	if bool(_occlusion().statistics().active):
		await _fail("Standing in front of the kiosk wrongly activated the cutaway")
		return false
	report.occlusion.append({"case": "in-front-of-kiosk", "active": false, "pass": true})
	if not await _save("occlusion-front-of-kiosk"): return false
	var only_routes: Array[String] = []
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--route="): only_routes.append(arg.trim_prefix("--route="))
	for phase_id in _selected_phases():
		main._select_time_phase(phase_id)
		for route_name in ROUTES:
			if not only_routes.is_empty() and not only_routes.has(route_name): continue
			var route: Dictionary = ROUTES[route_name]
			if not await _walk_until_occluded(route):
				await _save("debug-%s-%s-not-occluded" % [route_name, phase_id])
				await _fail("%s route never became occluded in %s; player=%s stats=%s" % [route_name, phase_id, main.world.player.global_position, _occlusion().statistics()])
				return false
			var probe := await _probe_reveal("%s-%s" % [route_name, phase_id])
			if not bool(probe.pass):
				await _fail("Reveal incomplete: " + JSON.stringify(probe))
				return false
			if not await _walk_until_clear(route):
				await _fail("%s route did not restore after leaving in %s" % [route_name, phase_id])
				return false
			if not await _save("occlusion-%s-%s-cleared" % [route_name, phase_id]): return false
	main._select_time_phase("noon")
	if OS.get_cmdline_user_args().has("--sweep-only"): return true
	# Outfit and hat change while hidden behind the kiosk.
	if not await _walk_until_occluded(ROUTES.kiosk): return false
	for item_id in ["outfit-coral", "hat-sailor"]:
		if not progress.owned_clothes.has(item_id): progress.owned_clothes.append(item_id)
	if not progress.equip_clothing("outfit-coral") or not progress.equip_clothing("hat-sailor"):
		await _fail("Could not equip review outfit")
		return false
	await get_tree().create_timer(0.4).timeout
	var outfit := await _probe_reveal("kiosk-outfit-change")
	if not bool(outfit.pass):
		await _fail("Outfit change reveal incomplete: " + JSON.stringify(outfit))
		return false
	# Reduced motion snaps the opening without losing the body.
	world.apply_settings({"reduced_motion": true})
	await get_tree().create_timer(0.2).timeout
	var reduced := await _probe_reveal("kiosk-reduced-motion")
	if not bool(reduced.pass) or not is_equal_approx(float(reduced.fade_weight), 1.0):
		await _fail("Reduced motion reveal incomplete: " + JSON.stringify(reduced))
		return false
	if not await _walk_until_clear(ROUTES.kiosk): return false
	world.apply_settings({"reduced_motion": false})
	# Window sizes smaller and larger than the authored 1280x720.
	for size in [Vector2i(800, 600), Vector2i(1600, 900)]:
		get_window().size = size
		await get_tree().create_timer(0.5).timeout
		if not await _walk_until_occluded(ROUTES.kiosk): return false
		var resized := await _probe_reveal("kiosk-window-%dx%d" % [size.x, size.y])
		if not bool(resized.pass):
			await _fail("Resized reveal incomplete: " + JSON.stringify(resized))
			return false
		if not await _walk_until_clear(ROUTES.kiosk): return false
	get_window().size = Vector2i(1280, 720)
	await get_tree().create_timer(0.4).timeout
	# Re-entering Main while hidden starts clean: no stale cutaway state.
	if not await _walk_until_occluded(ROUTES.arch): return false
	var old_main := main
	old_main.audio.shutdown()
	old_main.queue_free()
	await _frames(3)
	main = _instantiate_main()
	get_tree().root.add_child(main)
	await get_tree().create_timer(1.5).timeout
	await _place(ROUTES.arch.start, 0.8)
	var fresh: Dictionary = _occlusion().statistics()
	var fresh_ok := not bool(fresh.active) and is_zero_approx(float(fresh.fade_weight))
	report.occlusion.append({"case": "main-reentry", "active": fresh.active, "fade_weight": fresh.fade_weight, "registered_buildings": fresh.registered_buildings, "pass": fresh_ok})
	if not fresh_ok:
		await _fail("A re-entered Main started with a stale cutaway")
		return false
	if not await _walk_until_occluded(ROUTES.arch): return false
	var reentry := await _probe_reveal("arch-after-reentry")
	if not bool(reentry.pass):
		await _fail("Reveal after re-entry incomplete: " + JSON.stringify(reentry))
		return false
	return true


## Real key routes for Godot's movie writer (fixed engine clock).
func _record_occlusion_routes() -> bool:
	if OS.get_cmdline_user_args().has("--quarter"): Engine.time_scale = 0.25
	for phase_id in ["noon", "night"]:
		main._select_time_phase(phase_id)
		for route_name in ROUTES:
			var route: Dictionary = ROUTES[route_name]
			if not await _walk_until_occluded(route, 0.35): return false
			await get_tree().create_timer(0.6).timeout
			if not await _walk_until_clear(route): return false
	return true
