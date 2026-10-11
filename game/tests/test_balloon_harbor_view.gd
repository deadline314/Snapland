extends SceneTree

const HarborView = preload("res://game/minigames/balloon_harbor_view.gd")

var checks := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var view: Control = HarborView.new()
	root.add_child(view)
	view.initialize()
	await process_frame
	await process_frame
	_expect(view.texture() is Texture2D, "view exposes its isolated SubViewport texture")
	_expect(view.get_node("HarborViewport").own_world_3d, "harbor renderer owns an isolated 3D world")
	_expect(view.get_node("HarborViewport/HarborWorld/KeyLight") is DirectionalLight3D, "harbor world has a directional key light")
	_expect(view.get_node("HarborViewport/HarborWorld/Environment") is WorldEnvironment, "harbor world has its own environment")
	var points: Array[Vector2] = [Vector2(520, 305), Vector2(820, 480), Vector2(1080, 320), Vector2(250, 380), Vector2(640, 390)]
	for point: Vector2 in points:
		var screen: Vector2 = view.design_to_screen(point)
		var recovered: Vector2 = view.screen_to_design(screen)
		_expect(screen.distance_to(point) < 0.1, "camera projection aligns with 1280×720 design coordinate %s" % str(point))
		_expect(recovered.distance_to(point) < 0.05, "camera ray projection roundtrips design coordinate %s" % str(point))
	var world: Node = view.get_node("HarborViewport/HarborWorld")
	var initial_nodes := _descendant_count(world)
	var roof: MeshInstance3D = world.get_node("RoofCap0")
	var dock_ring: MeshInstance3D = world.get_node("DockRing0")
	var dock_lights: Array = view._dock_lights[0]
	_expect(world.get_node("SeaCrest0") is MeshInstance3D and world.get_node("SeaCrest9") is MeshInstance3D, "harbor has a sparse set of prebuilt sea crests")
	_expect(world.get_node("ShedRoofLeft0") is MeshInstance3D and world.get_node("ShedRoofRight0") is MeshInstance3D and world.get_node("QuayRailPost0_0_0") is MeshInstance3D, "island has pitched roof planes and solid railing posts")
	_expect((world.get_node("ShedRoofLeft0") as MeshInstance3D).rotation.z > 0.0 and (world.get_node("ShedRoofRight0") as MeshInstance3D).rotation.z < 0.0, "shed roof planes rise inward to a proper ridge")
	_expect(world.get_node("PierDeckBoard0") is MeshInstance3D and world.get_node("PierLantern0/Glow") is OmniLight3D, "pier has layered deck boards and a pooled lantern light")
	_expect(view._viewport.msaa_3d == Viewport.MSAA_2X, "3D viewport uses modest antialiasing for toy geometry edges")
	_expect((world.get_node("SeaGlassWater") as MeshInstance3D).material_override is ShaderMaterial, "sea uses a reusable spatial shader for layered water movement")
	_expect(world.get_node("LighthouseTower") is MeshInstance3D and world.get_node("ParcelBoatHull") is MeshInstance3D and world.get_node("PostOfficeFascia") is MeshInstance3D, "three route stops have distinct post-office, lighthouse, and boat landmarks")
	_expect((world.get_node("RooftopIsland1") as MeshInstance3D).mesh is CylinderMesh, "lighthouse landing sits on a round apron rather than a third square quay")
	_expect(world.get_node("PostOfficeEnvelopeFold0") is MeshInstance3D and world.get_node("ParcelBoatSail") is MeshInstance3D and world.get_node("LighthouseLanternRoom") is MeshInstance3D, "each stop carries a clear silhouette cue: postal seal, sail, and lantern room")
	_expect(dock_ring.position.y - 0.12 > roof.position.y + 0.14, "active docking ring clears the roof cap surface")
	_expect((dock_lights[0] as MeshInstance3D).position.y - 0.16 > roof.position.y + 0.14, "docking lights clear the roof cap surface")
	_expect(world.has_node("PostalCounter") and world.has_node("PostalRoofBeam"), "postal kiosk has a visible service counter and structural roof beam")
	_expect(world.has_node("ParcelBoatJib") and world.has_node("BoatMooringRope") and world.has_node("BoatBowRail"), "sailing stop has separate jib, mooring, and bow rail")
	_expect(world.has_node("LighthouseDoor") and not world.has_node("ShedRoofLeft1") and not world.has_node("ShedRoofLeft2"), "lighthouse and sailboat do not repeat the postal roof silhouette")
	_expect(world.has_node("DockPlank0_0") and world.has_node("QuayRope0_0"), "working dock has actual timber planks and mooring ropes")
	_expect(world.has_node("ForecastWind/ForecastDash0") and not world.has_node("ForecastWind/Shaft") and world.has_node("CurrentWind/Shaft"), "forecast uses a segmented arrow distinct from the solid live-wind arrow")
	var mainsail := world.get_node("ParcelBoatSail") as MeshInstance3D
	var hull := world.get_node("ParcelBoatHull") as MeshInstance3D
	_expect(mainsail.mesh.get_aabb().size.y > 4.0 and hull.mesh.get_aabb().size.x > 7.0, "boat silhouette has a full-height sail and long pointed hull")
	_expect(world.get_node("LighthouseRoof").position.y > 6.0, "lighthouse lantern and cap form the highest stationary landmark")
	var delivered_bag: Node3D = world.get_node("DeliveredBag0")
	_expect(delivered_bag.get_parent() == world and delivered_bag.get_node("BagBody") is MeshInstance3D, "delivered bag is a mailbox-side parcel in the shared harbor world")
	_expect(view._viewport.has_node("WindLegend/CurrentCaption") and view._viewport.has_node("WindLegend/ForecastCaption"), "fixed wind legend labels current and forecast separately")
	var legend_position: Vector3 = view._current_wind.position
	for edge_position: Vector2 in [Vector2(220,210),Vector2(1080,585)]:
		view.present(edge_position,Vector2.ZERO,Vector2.UP*42.0,Vector2.DOWN*42.0,0,0.0,false,0.0,true,"noon",0)
		_expect(view._current_wind.position.is_equal_approx(legend_position), "wind legend stays clear of the header at legal route endpoint %s" % str(edge_position))
	view.present(Vector2(500,330),Vector2.ZERO,Vector2(30,-30),Vector2(-20,30),0,0.0,false,0.0,true,"noon",0)
	var wind_base: Vector2 = view._camera.unproject_position(view._current_wind.position)
	var wind_tip: Vector2 = view._camera.unproject_position(view._current_wind.position + view._current_wind.basis.x)
	_expect((wind_tip-wind_base).normalized().dot(Vector2(1,-1).normalized()) > 0.999, "diagonal live wind remains aligned with its gameplay vector after projection")
	var forecast_base: Vector2 = view._camera.unproject_position(view._forecast_wind.position)
	var forecast_tip: Vector2 = view._camera.unproject_position(view._forecast_wind.position + view._forecast_wind.basis.x)
	_expect((forecast_tip-forecast_base).normalized().dot(Vector2(-20,30).normalized()) > 0.999, "forecast direction independently matches the projected gameplay vector")
	var noon_key_energy: float = view._key_light.light_energy
	var noon_sky: Color = view._sky_material.sky_top_color
	for index in 120:
		var phase_name: String = ["noon", "dusk", "night", "dawn"][index % 4]
		view.present(Vector2(250 + float(index % 80), 380), Vector2(32, -9), Vector2(42, 0), Vector2(-18, 0), index % 3, 0.2, index % 2 == 0, float(index) * 0.03, index % 3 == 0, phase_name, index % 4)
	_expect(_descendant_count(world) == initial_nodes, "present updates pooled harbor nodes without per-frame growth")
	_expect(view._key_light.light_energy != noon_key_energy and view._sky_material.sky_top_color != noon_sky, "day-phase presentation updates the existing key light and sky")
	_expect(is_equal_approx(view._water_shader_material.get_shader_parameter("wave_time"), 3.57), "water shader follows the supplied game clock rather than allocating an animation node")
	_expect(not (world.get_node("PierLantern0") as Node3D).visible, "day phase hides night-only harbor lamps")
	_expect(is_zero_approx(view._mailbox_lights[0].light_energy), "day phase keeps mailbox route lamps dark")
	_expect((world.get_node("WindLane0") as Node3D).visible, "wind vector presents a prebuilt sea-level wind lane")
	_expect(not world.get_node("SeaUrchinHazard").visible, "missing hazard input safely hides the hazard model")
	view.present(Vector2(370, 400), Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, 0, 0.0, false, 6.2, false, "noon", 1, Vector2(720, 390), 65.0)
	var hazard: Node3D = world.get_node("SeaUrchinHazard")
	var avoidance_ring: MeshInstance3D = world.get_node("HazardAvoidanceRing")
	_expect(hazard.visible and avoidance_ring.visible, "actual hazard position presents both urchin and avoidance ring")
	_expect(avoidance_ring.get_node("HazardTick0") is MeshInstance3D and avoidance_ring.get_node("HazardTick7") is MeshInstance3D, "hazard boundary has high-contrast fixed ticks for distance readability")
	_expect(hazard.get_node("Spine11") is MeshInstance3D and hazard.get_node("UrchinEye0") is MeshInstance3D, "sea-urchin hazard reads as a distinct spiked obstacle")
	_expect(is_equal_approx(avoidance_ring.scale.x, 65.0 * view.VIEW_SCALE) and is_equal_approx(avoidance_ring.scale.z, 65.0 * view.Z_SCALE), "avoidance ring matches the supplied 65px collision radius")
	view.present(Vector2(370, 400), Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, 0, 0.0, false, 6.1, false, "noon", 0, Vector2(720, 390), 65.0)
	_expect(not delivered_bag.visible, "reset delivery count hides mailbox-side parcels")
	view.present(Vector2(370, 400), Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, 0, 0.0, false, 6.2, false, "noon", 1, Vector2(720, 390), 65.0)
	var bag_launch_y: float = delivered_bag.position.y
	view.present(Vector2(370, 400), Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, 0, 0.0, false, 6.27, false, "noon", 1, Vector2(720, 390), 65.0)
	_expect(delivered_bag.position.y < bag_launch_y and delivered_bag.position.y > 0.92, "delivery event animates the newly delivered bag down to its mailbox")
	view.present(Vector2(370, 400), Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, 0, 0.0, false, 6.8, false, "noon", 1, Vector2(720, 390), 65.0)
	_expect(is_equal_approx(delivered_bag.position.y, 0.92), "delivered bag settles at the mailbox after its brief arrival")
	var player: Node3D = world.get_node("Balloon")
	var canopy: Node3D = player.get_node("Canopy")
	view.present(Vector2(370, 400), Vector2(55, 14), Vector2(0, 42), Vector2(-42, 0), 1, 0.35, false, 6.0, true, "night", 1)
	_expect(player.global_transform.origin.y >= 0.0, "reduced-motion presentation keeps balloon above the harbor plane")
	_expect(canopy.rotation.is_zero_approx(), "reduced motion disables balloon sway and tilt")
	_expect(player.rotation.is_zero_approx(), "reduced motion keeps the shared envelope pivot steady")
	_expect(is_equal_approx(view._harbor_flags[0].rotation.y, -PI * 0.5), "reduced motion preserves the live wind direction on harbor pennants")
	_expect(is_zero_approx(float(view._water_shader_material.get_shader_parameter("wave_time"))), "reduced motion freezes shader water movement while keeping its static color and route cues")
	_expect(canopy.scale.x >= 1.6 and canopy.scale.y >= 1.9, "large envelope silhouette leads the miniature")
	_expect(player.get_node("EnvelopePanel0") is MeshInstance3D and player.get_node("EnvelopePanel2") is MeshInstance3D, "envelope carries fixed teal panels over its coral body")
	var curved_panel := player.get_node("EnvelopePanel0") as MeshInstance3D
	_expect(curved_panel.mesh is ArrayMesh and curved_panel.mesh.get_aabb().size.y > 3.5, "fabric stripe follows a curved full-height envelope surface")
	_expect(is_equal_approx(absf(view._forecast_wind.rotation.y), PI), "forecast arrow independently preserves its upcoming wind heading in reduced motion")
	var projected_east: Vector2 = view.design_to_screen(Vector2(785,390))
	var projected_center: Vector2 = view.design_to_screen(Vector2(720,390))
	_expect(is_equal_approx(projected_east.distance_to(projected_center), 65.0), "collision radius remains 65 screen pixels after art changes")
	_expect((world.get_node("PierLantern0") as Node3D).visible, "night phase reveals the existing lantern meshes and lights")
	var beacon_material := view._mailbox_beacons[0].material_override as StandardMaterial3D
	_expect(view._mailbox_lights[0].light_energy > 0.0 and beacon_material.emission_energy_multiplier > 0.0, "night phase lights mailbox symbols and route beacons")
	var night_window := world.get_node("ShedWindow0_0") as MeshInstance3D
	var night_window_mat := night_window.material_override as StandardMaterial3D
	_expect(night_window_mat.emission_enabled and night_window_mat.emission_energy_multiplier > 0.0, "night phase lights existing shed windows")
	view.present(Vector2(370, 400), Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, 1, 0.35, false, 6.0, true, "noon", 1)
	_expect(not night_window_mat.emission_enabled, "returning to day removes window glow without replacing materials")
	view.initialize()
	_expect(_descendant_count(world) == initial_nodes, "initialize is idempotent and repeated resets do not grow world resources")
	_expect(player.position.x != 0.0 or player.position.z != 0.0, "live balloon pose was actually presented before reset check")
	view.queue_free()
	await process_frame
	print("PASS: isolated miniature harbor view (%d checks)" % checks)
	quit()

func _descendant_count(node: Node) -> int:
	var total := 1
	for child: Node in node.get_children():
		total += _descendant_count(child)
	return total

func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		push_error("Balloon harbor view: " + message)
		quit(1)
