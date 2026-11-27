extends RefCounted
## Signature props of the tidal harbor. Each builder goes through the scenery kit,
## so textured parts batch across the region and trim merges into shared meshes.

const Kit := preload("res://game/world/scenery_kit.gd")
const LIGHT_BEAM := preload("res://game/world/light_beam.gdshader")
const CREAM := Color("#edddb8")
const TEAL := Color("#246c6c")
const CORAL := Color("#da705c")
const GOLD := Color("#edbb65")
const IRON := Color("#39474f")
const DARK_WOOD := Color("#5a4632")
const PALE_WOOD := Color("#d9b98a")
const ROPE := Color("#c9b58a")
const STONE := Color("#b9ad92")
const WHITEWASH := Color("#f6efdc")
const BEAM_LENGTH := 11.0

## Tapered banded tower with gallery, lantern room and a rotating beam. Returns the
## parts the world animates (glass, rotor, beam material) and the tower top height.
static func lighthouse(world: Node3D, kit: Kit, at: Vector3) -> Dictionary:
	const BAND := 1.45
	var top := 0.1 + BAND * 4.0
	# The paved apron stays out of the cutaway group: its ray shape would sit below
	# the height that floor probes start from.
	kit.detail.tube(at + Vector3(0, 0.05, 0), 1.34, 1.26, 0.1, STONE, 14)
	world.occlusion_controller.begin_building()
	var radii := [0.94, 0.85, 0.76, 0.67, 0.58]
	# The tint is above 1 on purpose: it lifts the sandstone tile to whitewash.
	var whitewash: Material = world._coastal_surface(4, 1.55, Color(1.2, 1.385, 1.82))
	var tower: MeshInstance3D
	for band in range(4):
		var segment: MeshInstance3D = world._cylinder(at + Vector3(0, 0.1 + BAND * (float(band) + 0.5), 0), radii[band], BAND, CREAM, radii[band + 1])
		world._set_registered_surface(segment, whitewash if band % 2 == 0 else world._coastal_surface(3, 1.3))
		if band == 0: tower = segment
	tower.name = "HarborLighthouse"
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 0.94
	cylinder.height = top
	shape.shape = cylinder
	shape.position.y = top * 0.5 - BAND * 0.5 - 0.1
	body.add_child(shape)
	tower.add_child(body)
	var roof: MeshInstance3D = world._cylinder(at + Vector3(0, top + 1.58, 0), 0.76, 0.76, CORAL, 0.03)
	world._set_registered_surface(roof, world._coastal_surface(3, 0.9, Color("#f2c9b8")))
	var glass: MeshInstance3D = world._cylinder(at + Vector3(0, top + 0.77, 0), 0.46, 0.7, CREAM)
	var glass_material := StandardMaterial3D.new()
	glass_material.albedo_color = Color("#dcefe6")
	glass_material.roughness = 0.35
	glass_material.emission_enabled = true
	glass_material.emission = Kit.WARM_GLOW
	glass_material.emission_energy_multiplier = 0.0
	world.material_cache["harbor:lantern-glass"] = glass_material
	world._set_registered_surface(glass, glass_material)
	var trim := Kit.Sculpt.new()
	trim.frame = Transform3D(Basis.IDENTITY, at)
	trim.tube(Vector3(0, 0.2, 0), 1.03, 0.97, 0.2, STONE, 14)
	for band in range(1, 4):
		trim.tube(Vector3(0, 0.1 + BAND * float(band), 0), radii[band] + 0.04, radii[band] + 0.04, 0.08, TEAL.darkened(0.25), 14)
	trim.box(Vector3(0, 0.62, 0.9), Vector3(0.5, 0.94, 0.12), TEAL.darkened(0.2))
	trim.box(Vector3(0, 1.15, 0.9), Vector3(0.7, 0.1, 0.18), CREAM)
	trim.box(Vector3(0, 0.13, 1.05), Vector3(0.8, 0.08, 0.34), STONE.lightened(0.15))
	trim.box(Vector3(0.12, 0.62, 0.97), Vector3(0.05, 0.05, 0.05), GOLD)
	for window: Vector2 in [Vector2(0.55, 0.38), Vector2(-0.6, 0.6), Vector2(0.35, 0.84)]:
		var facing := Basis(Vector3.UP, window.x)
		var radius: float = lerpf(0.94, 0.58, window.y) - 0.02
		trim.box(facing * Vector3(0, 0.1 + window.y * BAND * 4.0, radius), Vector3(0.26, 0.36, 0.08), Color("#24343c"), facing)
		trim.box(facing * Vector3(0, -0.11 + window.y * BAND * 4.0, radius + 0.03), Vector3(0.36, 0.06, 0.12), CREAM, facing)
	trim.tube(Vector3(0, top + 0.11, 0), 0.6, 1.02, 0.22, Color("#3a5560"), 14)
	trim.tube(Vector3(0, top + 0.27, 0), 1.08, 1.08, 0.1, Color("#2c4048"), 14)
	for post in range(10):
		trim.box(Basis(Vector3.UP, TAU * float(post) / 10.0) * Vector3(0, top + 0.53, 1.02), Vector3(0.05, 0.42, 0.05), GOLD.darkened(0.15))
		var chord := Basis(Vector3.UP, TAU * (float(post) + 0.5) / 10.0)
		trim.box(chord * Vector3(0, top + 0.74, 0.97), Vector3(0.64, 0.045, 0.045), GOLD.darkened(0.15), chord)
	trim.tube(Vector3(0, top + 0.37, 0), 0.56, 0.56, 0.1, Color("#2c4048"), 12)
	for mullion in range(6):
		trim.box(Basis(Vector3.UP, TAU * (float(mullion) + 0.5) / 6.0) * Vector3(0, top + 0.77, 0.47), Vector3(0.05, 0.7, 0.05), Color("#2c4048"))
	trim.tube(Vector3(0, top + 1.16, 0), 0.62, 0.8, 0.08, Color("#2c4048"), 12)
	trim.tube(Vector3(0, top + 2.06, 0), 0.035, 0.035, 0.26, GOLD, 6)
	trim.tube(Vector3(0, top + 2.22, 0), 0.09, 0.09, 0.14, GOLD, 6)
	world._mesh(trim.mesh(), Vector3.ZERO, world._vertex_color_material("scenery-detail")).name = "HarborLighthouseTrim"
	world.occlusion_controller.finish_building(body)
	# The beam and its light turn together; both stay outside the cutaway group.
	var rotor := Node3D.new()
	rotor.name = "HarborLighthouseBeam"
	rotor.position = at + Vector3(0, top + 0.77, 0)
	world.add_child(rotor)
	var beam_material := ShaderMaterial.new()
	beam_material.shader = LIGHT_BEAM
	beam_material.set_shader_parameter("beam_length", BEAM_LENGTH)
	world.material_cache["harbor:beam"] = beam_material
	var cone := CylinderMesh.new()
	cone.top_radius = 0.14
	cone.bottom_radius = 1.5
	cone.height = BEAM_LENGTH
	cone.radial_segments = 12
	cone.cap_top = false
	cone.cap_bottom = false
	for side: float in [-1.0, 1.0]:
		var beam := MeshInstance3D.new()
		beam.mesh = cone
		beam.material_override = beam_material
		beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		beam.rotation.z = side * PI * 0.5
		beam.position.x = side * (BEAM_LENGTH * 0.5 + 0.45)
		rotor.add_child(beam)
		world.mesh_count += 1
	var spot := SpotLight3D.new()
	spot.position = Vector3(0.6, 0, 0)
	spot.basis = Basis.looking_at(Vector3(1, -0.5, 0).normalized())
	spot.light_color = Kit.WARM_GLOW
	spot.spot_range = 18.0
	spot.spot_angle = 21.0
	spot.spot_attenuation = 0.6
	spot.light_energy = 0.0
	rotor.add_child(spot)
	world.lamps.append(spot)
	var door_lamp := OmniLight3D.new()
	door_lamp.position = at + Vector3(0.2, 1.9, 1.5)
	door_lamp.light_color = Color("#ffd79a")
	door_lamp.omni_range = 6.0
	door_lamp.light_energy = 0.0
	world.add_child(door_lamp)
	world.lamps.append(door_lamp)
	kit.glow.box(at + Vector3(0.5, 1.5, 0.98), Vector3(0.16, 0.22, 0.14), Kit.WARM_GLOW)
	kit.detail.box(at + Vector3(0.5, 1.66, 0.94), Vector3(0.22, 0.05, 0.22), IRON)
	return {"glass": glass, "rotor": rotor, "beam_material": beam_material, "top": top}

## Market stall facing local +Z: counter, plank back wall, slanted striped awning,
## framed name board and a small emblem that hints at the game.
static func stall(world: Node3D, kit: Kit, ground: Vector3, yaw: float, title: String, tint: Color, emblem_kind: String, variation: int) -> void:
	var frame := Transform3D(Basis(Vector3.UP, yaw), ground)
	kit.surface(world._coastal_surface(1, 1.3)).add(frame * Vector3(0, 0.44, 0.28), Vector3(1.8, 0.88, 0.56), frame.basis)
	kit.surface(world._coastal_surface(3, 1.2)).add(frame * Vector3(0, 0.95, -0.54), Vector3(1.8, 1.9, 0.1), frame.basis)
	kit.surface(world._coastal_surface(6, 1.1, tint)).add(frame * Vector3(0, 2.08, 0.12), Vector3(2.3, 0.06, 1.8), frame.basis * Basis(Vector3.RIGHT, 0.3))
	var detail := kit.detail
	detail.frame = frame
	detail.box(Vector3(0, 0.91, 0.28), Vector3(1.96, 0.07, 0.7), PALE_WOOD)
	for side: float in [-1.0, 1.0]:
		detail.box(Vector3(side * 0.95, 0.95, 0.6), Vector3(0.08, 1.9, 0.08), DARK_WOOD)
		detail.box(Vector3(side * 0.95, 1.17, -0.62), Vector3(0.08, 2.34, 0.08), DARK_WOOD)
	for scallop in range(8):
		detail.box(Vector3(-0.98 + 0.28 * float(scallop), 1.7, 0.99), Vector3(0.27, 0.2 if scallop % 2 == 0 else 0.15, 0.03), CREAM if scallop % 2 == 0 else tint)
	detail.box(Vector3(0, 1.38, -0.42), Vector3(1.6, 0.05, 0.2), PALE_WOOD)
	var wares: Array[Color] = [CORAL, GOLD, TEAL, Color("#7abec3"), CREAM]
	for item in range(5):
		var ware := wares[(item + variation) % wares.size()]
		if (item + variation) % 2 == 0:
			detail.tube(Vector3(-0.6 + 0.3 * float(item), 1.5, -0.42), 0.08, 0.06, 0.2, ware, 6)
		else:
			detail.box(Vector3(-0.6 + 0.3 * float(item), 1.48, -0.42), Vector3(0.16, 0.15, 0.14), ware)
	detail.box(Vector3(-0.55, 1.03, 0.3), Vector3(0.34, 0.16, 0.3), DARK_WOOD.lightened(0.2))
	detail.box(Vector3(-0.55, 1.12, 0.3), Vector3(0.28, 0.04, 0.24), wares[variation % wares.size()])
	detail.tube(Vector3(0.5, 1.05, 0.28), 0.1, 0.1, 0.2, wares[(variation + 2) % wares.size()], 6)
	detail.box(Vector3(0, 2.7, -0.5), Vector3(1.74, 0.5, 0.08), DARK_WOOD.darkened(0.15))
	for edge: float in [-1.0, 1.0]:
		detail.box(Vector3(0, 2.7 + edge * 0.26, -0.5), Vector3(1.84, 0.06, 0.12), PALE_WOOD)
		detail.box(Vector3(edge * 0.89, 2.7, -0.5), Vector3(0.06, 0.5, 0.12), PALE_WOOD)
		detail.box(Vector3(edge * 0.6, 2.4, -0.5), Vector3(0.06, 0.2, 0.06), DARK_WOOD)
	detail.frame = frame * Transform3D(Basis.IDENTITY, Vector3(0, 2.99, -0.5))
	emblem(detail, emblem_kind)
	detail.frame = Transform3D.IDENTITY
	kit.glow.frame = frame
	kit.glow.box(Vector3(-0.95, 1.56, 0.78), Vector3(0.15, 0.2, 0.15), Kit.WARM_GLOW)
	kit.glow.frame = Transform3D.IDENTITY
	detail.box(frame * Vector3(-0.95, 1.7, 0.78), Vector3(0.2, 0.05, 0.2), IRON, frame.basis)
	world._local_label(title, frame * Vector3(0, 2.7, -0.3), 26)
	kit.blocker(frame * Vector3(0, 0.95, -0.02), Vector3(1.9, 1.9, 1.24), yaw)

## Small rooftop figure, at most 0.6 m across, with its base at the frame origin.
static func emblem(sculpt: Kit.Sculpt, kind: String) -> void:
	match kind:
		"boat":
			sculpt.box(Vector3(0, 0.09, 0), Vector3(0.56, 0.14, 0.2), TEAL)
			sculpt.box(Vector3(0, 0.18, 0), Vector3(0.62, 0.04, 0.24), CREAM)
			sculpt.box(Vector3(-0.04, 0.38, 0), Vector3(0.03, 0.4, 0.03), DARK_WOOD)
			sculpt.sheet(Vector3(0, 0.22, 0), Vector3(0, 0.58, 0), Vector3(0.26, 0.22, 0), CREAM)
		"flags":
			for side: float in [-1.0, 1.0]:
				sculpt.box(Vector3(side * 0.16, 0.26, 0), Vector3(0.03, 0.52, 0.03), DARK_WOOD)
				sculpt.sheet(Vector3(side * 0.16, 0.5, 0), Vector3(side * 0.16, 0.34, 0), Vector3(side * 0.16 + 0.2, 0.42, 0), CORAL if side < 0.0 else GOLD)
			sculpt.tube(Vector3(0, 0.04, 0), 0.3, 0.24, 0.08, Color("#eed29a"), 8)
		"rope":
			for turn in range(3):
				sculpt.tube(Vector3(0, 0.05 + 0.09 * float(turn), 0), 0.22 - 0.03 * float(turn), 0.22 - 0.03 * float(turn), 0.08, ROPE if turn % 2 == 0 else ROPE.darkened(0.15), 8)
			sculpt.box(Vector3(0.1, 0.42, 0), Vector3(0.05, 0.3, 0.05), IRON)
			sculpt.box(Vector3(0.02, 0.3, 0), Vector3(0.16, 0.05, 0.05), IRON)
		"crab":
			sculpt.box(Vector3(0, 0.16, 0), Vector3(0.36, 0.15, 0.2), CORAL)
			sculpt.box(Vector3(0, 0.07, 0), Vector3(0.54, 0.04, 0.05), CORAL.darkened(0.2))
			for side: float in [-1.0, 1.0]:
				sculpt.box(Vector3(side * 0.27, 0.3, 0), Vector3(0.14, 0.13, 0.1), CORAL.lightened(0.1))
				sculpt.box(Vector3(side * 0.08, 0.29, 0.02), Vector3(0.05, 0.12, 0.05), Color("#2a2a30"))
		"crates":
			sculpt.box(Vector3(-0.14, 0.13, 0), Vector3(0.26, 0.26, 0.24), PALE_WOOD.darkened(0.1))
			sculpt.box(Vector3(0.15, 0.13, 0), Vector3(0.26, 0.26, 0.24), DARK_WOOD.lightened(0.25))
			sculpt.box(Vector3(0, 0.38, 0), Vector3(0.24, 0.24, 0.22), PALE_WOOD)
		"buoy":
			sculpt.tube(Vector3(0, 0.1, 0), 0.18, 0.16, 0.2, CORAL, 8)
			sculpt.tube(Vector3(0, 0.25, 0), 0.13, 0.1, 0.1, CREAM, 8)
			sculpt.box(Vector3(0, 0.44, 0), Vector3(0.03, 0.3, 0.03), IRON)
			sculpt.tube(Vector3(0, 0.6, 0), 0.06, 0.06, 0.08, GOLD, 6)
		"sail":
			sculpt.box(Vector3(0, 0.3, 0), Vector3(0.04, 0.6, 0.04), DARK_WOOD)
			sculpt.sheet(Vector3(0.03, 0.08, 0), Vector3(0.03, 0.58, 0), Vector3(0.36, 0.08, 0), CREAM)
			sculpt.sheet(Vector3(-0.03, 0.14, 0), Vector3(-0.03, 0.5, 0), Vector3(-0.24, 0.14, 0), CORAL)
		"shell":
			for rib in range(5):
				sculpt.box(Basis(Vector3.BACK, 0.42 * float(rib - 2)) * Vector3(0, 0.2, 0) + Vector3(0, 0.04, 0), Vector3(0.09, 0.34, 0.05), Color("#f3c4b4") if rib % 2 == 0 else CREAM, Basis(Vector3.BACK, 0.42 * float(rib - 2)))
			sculpt.box(Vector3(0, 0.05, 0), Vector3(0.2, 0.08, 0.08), Color("#e7a898"))
		"anchor":
			sculpt.box(Vector3(0, 0.3, 0), Vector3(0.06, 0.5, 0.06), IRON)
			sculpt.box(Vector3(0, 0.48, 0), Vector3(0.3, 0.05, 0.06), IRON)
			for side: float in [-1.0, 1.0]:
				sculpt.box(Vector3(side * 0.11, 0.1, 0), Vector3(0.26, 0.06, 0.06), IRON, Basis(Vector3.BACK, side * 0.6))
			sculpt.tube(Vector3(0, 0.6, 0), 0.07, 0.07, 0.05, GOLD, 6, Basis(Vector3.RIGHT, PI * 0.5))
		"gull":
			sculpt.box(Vector3(0, 0.1, 0), Vector3(0.04, 0.2, 0.04), DARK_WOOD)
			sculpt.box(Vector3(0, 0.27, 0), Vector3(0.3, 0.13, 0.13), Color.WHITE)
			sculpt.box(Vector3(0.19, 0.3, 0), Vector3(0.1, 0.05, 0.05), GOLD)
			for side: float in [-1.0, 1.0]:
				sculpt.box(Vector3(-0.04, 0.4, side * 0.02), Vector3(0.34, 0.03, 0.14), Color("#cfd6d8"), Basis(Vector3.BACK, 0.5 * side + 0.2))
		"bell":
			for side: float in [-1.0, 1.0]:
				sculpt.box(Vector3(side * 0.2, 0.26, 0), Vector3(0.04, 0.52, 0.04), DARK_WOOD)
			sculpt.box(Vector3(0, 0.52, 0), Vector3(0.48, 0.05, 0.06), DARK_WOOD)
			sculpt.tube(Vector3(0, 0.34, 0), 0.16, 0.08, 0.26, GOLD, 8)
			sculpt.tube(Vector3(0, 0.2, 0), 0.19, 0.17, 0.04, GOLD.darkened(0.15), 8)

## Open boat shell along local +Z, waterline at the origin, built into `sculpt`.
static func hull(sculpt: Kit.Sculpt, length: float, beam: float, depth: float, paint: Color, trim: Color, inside: Color) -> void:
	const STATIONS := 8
	var rings: Array[PackedVector3Array] = []
	for station in range(STATIONS + 1):
		var along := float(station) / float(STATIONS)
		var taper := 1.0 - pow(maxf(0.0, (along - 0.4) / 0.6), 2.2)
		var half := maxf(0.03, beam * 0.5 * lerpf(0.82, 1.0, smoothstep(0.0, 0.35, along)) * taper)
		var top := depth * (1.0 + 0.3 * along * along) - 0.14
		var rim := minf(0.08, half * 0.5)
		var floor_y := depth * 0.3 - 0.14
		var z := (along - 0.5) * length
		rings.append(PackedVector3Array([
			Vector3(-half * 0.55, -0.14, z), Vector3(-half, top - 0.1, z), Vector3(-half, top, z), Vector3(-half + rim, top, z),
			Vector3((-half + rim) * 0.8, floor_y, z), Vector3((half - rim) * 0.8, floor_y, z),
			Vector3(half - rim, top, z), Vector3(half, top, z), Vector3(half, top - 0.1, z), Vector3(half * 0.55, -0.14, z),
		]))
	var strip_colors: Array[Color] = [paint, trim, PALE_WOOD, inside.darkened(0.12), inside, inside.darkened(0.12), PALE_WOOD, trim, paint]
	for station in range(STATIONS):
		for strip in range(9):
			sculpt.quad(rings[station][strip + 1], rings[station + 1][strip + 1], rings[station + 1][strip], rings[station][strip], strip_colors[strip])
	var stern := rings[0]
	sculpt.quad(stern[9], stern[7], stern[2], stern[0], paint.darkened(0.1))
	sculpt.quad(stern[3] + Vector3(0, 0, 0.06), stern[6] + Vector3(0, 0, 0.06), stern[5] + Vector3(0, 0, 0.06), stern[4] + Vector3(0, 0, 0.06), inside.darkened(0.2))
	sculpt.box(Vector3(0, stern[2].y - 0.02, stern[0].z + 0.03), Vector3(stern[7].x * 2.0, 0.06, 0.08), PALE_WOOD)

static func rowboat_mesh() -> ArrayMesh:
	var sculpt := Kit.Sculpt.new()
	hull(sculpt, 2.5, 1.05, 0.42, Color.WHITE, Color("#e9e2cf"), Color("#b08a5c"))
	for thwart: float in [-0.55, 0.3]:
		sculpt.box(Vector3(0, 0.2, thwart), Vector3(0.84, 0.05, 0.2), PALE_WOOD)
	for side: float in [-1.0, 1.0]:
		sculpt.box(Vector3(side * 0.34, 0.24, -0.1), Vector3(0.05, 0.04, 1.5), DARK_WOOD.lightened(0.2), Basis(Vector3.UP, side * 0.1))
	return sculpt.mesh()

## The free ferry: cabin, funnel and a striped canopy over the passenger bench.
static func ferry_mesh() -> ArrayMesh:
	var sculpt := Kit.Sculpt.new()
	hull(sculpt, 4.4, 1.8, 0.62, TEAL, CREAM, Color("#b08a5c"))
	sculpt.box(Vector3(0, 0.16, -0.1), Vector3(1.3, 0.06, 3.3), PALE_WOOD.darkened(0.1))
	sculpt.box(Vector3(0, 0.62, 0.75), Vector3(1.1, 0.9, 1.1), CREAM)
	sculpt.box(Vector3(0, 1.1, 0.75), Vector3(1.34, 0.1, 1.36), CORAL)
	for side: float in [-1.0, 1.0]:
		sculpt.box(Vector3(side * 0.56, 0.74, 0.75), Vector3(0.03, 0.3, 0.6), Color("#335b6e"))
	sculpt.box(Vector3(0, 0.74, 1.31), Vector3(0.7, 0.3, 0.03), Color("#335b6e"))
	sculpt.tube(Vector3(0, 1.5, 0.6), 0.2, 0.17, 0.7, TEAL.darkened(0.15), 8)
	sculpt.tube(Vector3(0, 1.75, 0.6), 0.2, 0.2, 0.1, GOLD, 8)
	for corner_x: float in [-0.62, 0.62]:
		for corner_z: float in [-1.75, -0.3]:
			sculpt.box(Vector3(corner_x, 0.75, corner_z), Vector3(0.06, 1.1, 0.06), DARK_WOOD)
	for stripe in range(6):
		sculpt.box(Vector3(-0.6 + 0.24 * float(stripe), 1.32, -1.02), Vector3(0.24, 0.05, 1.7), CREAM if stripe % 2 == 0 else CORAL)
	sculpt.box(Vector3(0, 0.4, -1.5), Vector3(1.0, 0.06, 0.3), PALE_WOOD)
	sculpt.tube(Vector3(0.93, 0.5, 0.2), 0.2, 0.2, 0.07, CORAL, 8, Basis(Vector3.BACK, PI * 0.5))
	sculpt.tube(Vector3(0.95, 0.5, 0.2), 0.1, 0.1, 0.08, CREAM, 8, Basis(Vector3.BACK, PI * 0.5))
	return sculpt.mesh()

## Moored sloop with its sail furled along the boom.
static func sloop_mesh() -> ArrayMesh:
	var sculpt := Kit.Sculpt.new()
	hull(sculpt, 3.6, 1.3, 0.55, Color("#f2ece0"), CORAL, Color("#b08a5c"))
	sculpt.box(Vector3(0, 0.3, 0.1), Vector3(0.9, 0.3, 1.5), PALE_WOOD.darkened(0.08))
	sculpt.box(Vector3(0, 0.47, 0.1), Vector3(0.98, 0.05, 1.6), TEAL)
	sculpt.tube(Vector3(0, 2.2, 0.55), 0.05, 0.035, 3.6, DARK_WOOD.lightened(0.15), 6)
	sculpt.box(Vector3(0, 0.95, -0.45), Vector3(0.06, 0.06, 2.0), DARK_WOOD.lightened(0.15))
	sculpt.tube(Vector3(0, 1.06, -0.45), 0.1, 0.1, 1.8, CREAM, 6, Basis(Vector3.RIGHT, PI * 0.5))
	sculpt.sheet(Vector3(0, 3.95, 0.55), Vector3(0, 3.75, 0.55), Vector3(0.4, 3.85, 0.55), GOLD)
	return sculpt.mesh()

static func buoy_mesh() -> ArrayMesh:
	var sculpt := Kit.Sculpt.new()
	sculpt.tube(Vector3(0, 0.05, 0), 0.3, 0.26, 0.34, Color.WHITE, 8)
	sculpt.tube(Vector3(0, 0.27, 0), 0.24, 0.16, 0.12, Color("#f6efdc"), 8)
	sculpt.box(Vector3(0, 0.62, 0), Vector3(0.04, 0.6, 0.04), IRON)
	sculpt.tube(Vector3(0, 0.96, 0), 0.07, 0.07, 0.1, GOLD, 6)
	return sculpt.mesh()

## Dark shape seen through the water; nose toward local +Z.
static func fish_mesh() -> ArrayMesh:
	var sculpt := Kit.Sculpt.new()
	var scales := Color("#1c4a55")
	sculpt.quad(Vector3(0, 0, 0.24), Vector3(-0.075, 0, 0.02), Vector3(0, 0, -0.16), Vector3(0.075, 0, 0.02), scales)
	sculpt.tri(Vector3(0, 0, -0.12), Vector3(-0.08, 0, -0.27), Vector3(0.08, 0, -0.27), scales)
	return sculpt.mesh()

## Wicker lobster pots stacked on the quay.
static func pots(kit: Kit, at: Vector3, yaw: float) -> void:
	var detail := kit.detail
	detail.frame = Transform3D(Basis(Vector3.UP, yaw), at)
	for pot: Vector3 in [Vector3(-0.32, 0.17, 0), Vector3(0.32, 0.17, 0.05), Vector3(0.02, 0.5, 0.02)]:
		detail.box(pot, Vector3(0.58, 0.32, 0.42), Color("#a8834f"))
		for hoop: float in [-0.2, 0.0, 0.2]:
			detail.box(pot + Vector3(hoop, 0, 0), Vector3(0.05, 0.35, 0.45), Color("#7c5c36"))
	detail.tube(Vector3(0.75, 0.09, 0.3), 0.16, 0.16, 0.18, CORAL, 8)
	detail.tube(Vector3(0.75, 0.2, 0.3), 0.1, 0.1, 0.06, CREAM, 8)
	detail.frame = Transform3D.IDENTITY

static func crab_mesh() -> ArrayMesh:
	var sculpt := Kit.Sculpt.new()
	sculpt.box(Vector3(0, 0.11, 0), Vector3(0.34, 0.13, 0.24), CORAL)
	sculpt.box(Vector3(0, 0.19, -0.02), Vector3(0.24, 0.04, 0.16), CORAL.lightened(0.12))
	for side: float in [-1.0, 1.0]:
		sculpt.box(Vector3(side * 0.24, 0.17, 0.12), Vector3(0.13, 0.11, 0.12), CORAL.lightened(0.08))
		sculpt.box(Vector3(side * 0.07, 0.24, 0.1), Vector3(0.04, 0.1, 0.04), Color("#2a2a30"))
		for leg in range(3):
			sculpt.box(Vector3(side * 0.24, 0.05, -0.1 + 0.09 * float(leg)), Vector3(0.16, 0.035, 0.035), CORAL.darkened(0.2))
	return sculpt.mesh()

## Tide clock: the hand points at sand for low water and at sea for high water; the
## bell swings when the tide turns. Returns the hand and the bell.
static func tide_clock(world: Node3D, kit: Kit, at: Vector3) -> Dictionary:
	var detail := kit.detail
	detail.frame = Transform3D(Basis.IDENTITY, at)
	detail.box(Vector3(0, 0.14, 0), Vector3(0.9, 0.28, 0.62), STONE)
	detail.box(Vector3(0, 0.31, 0), Vector3(0.7, 0.06, 0.5), STONE.lightened(0.15))
	detail.box(Vector3(0, 1.02, 0), Vector3(0.34, 1.4, 0.3), WHITEWASH.darkened(0.06))
	detail.box(Vector3(0, 1.0, 0), Vector3(0.4, 0.08, 0.36), TEAL)
	var face_on := Basis(Vector3.RIGHT, PI * 0.5)
	detail.tube(Vector3(0, 2.34, 0), 0.66, 0.66, 0.2, TEAL, 14, face_on)
	detail.tube(Vector3(0, 2.34, 0.08), 0.56, 0.56, 0.08, CREAM, 14, face_on)
	detail.box(Vector3(-0.25, 2.34, 0.125), Vector3(0.36, 0.5, 0.02), Color("#eed29a"))
	detail.box(Vector3(0.25, 2.34, 0.125), Vector3(0.36, 0.5, 0.02), Color("#4f9aa0"))
	detail.tube(Vector3(0, 2.34, 0.15), 0.07, 0.07, 0.05, GOLD, 8, face_on)
	for side: float in [-1.0, 1.0]:
		detail.box(Vector3(side * 0.36, 3.2, 0), Vector3(0.86, 0.07, 0.5), CORAL, Basis(Vector3.BACK, side * -0.5))
	detail.box(Vector3(0, 3.42, 0), Vector3(0.1, 0.1, 0.56), DARK_WOOD)
	detail.box(Vector3(0.55, 1.78, 0), Vector3(0.8, 0.06, 0.06), IRON)
	detail.box(Vector3(0, 0.62, 0.2), Vector3(2.7, 0.44, 0.06), DARK_WOOD.darkened(0.15))
	for edge: float in [-1.0, 1.0]:
		detail.box(Vector3(0, 0.62 + edge * 0.24, 0.2), Vector3(2.8, 0.05, 0.1), PALE_WOOD)
	detail.frame = Transform3D.IDENTITY
	var hand_sculpt := Kit.Sculpt.new()
	hand_sculpt.box(Vector3(0, 0.2, 0), Vector3(0.07, 0.48, 0.03), Color("#24343c"))
	hand_sculpt.box(Vector3(0, 0.44, 0), Vector3(0.14, 0.1, 0.03), CORAL)
	var hand: MeshInstance3D = world._mesh(hand_sculpt.mesh(), at + Vector3(0, 2.34, 0.17), world._vertex_color_material("scenery-detail"))
	hand.name = "HarborTideHand"
	var bell_sculpt := Kit.Sculpt.new()
	bell_sculpt.box(Vector3(0, -0.06, 0), Vector3(0.03, 0.12, 0.03), IRON)
	bell_sculpt.tube(Vector3(0, -0.25, 0), 0.17, 0.08, 0.26, GOLD, 8)
	bell_sculpt.tube(Vector3(0, -0.39, 0), 0.2, 0.18, 0.04, GOLD.darkened(0.15), 8)
	bell_sculpt.box(Vector3(0, -0.46, 0), Vector3(0.06, 0.08, 0.06), IRON)
	var bell: MeshInstance3D = world._mesh(bell_sculpt.mesh(), at + Vector3(0.88, 1.76, 0), world._vertex_color_material("scenery-detail"))
	bell.name = "HarborTideBell"
	return {"hand": hand, "bell": bell}

## Crates, a barrel and a rope coil; `variation` reshuffles the stack.
static func cargo(kit: Kit, at: Vector3, variation: int) -> void:
	var detail := kit.detail
	detail.frame = Transform3D(Basis(Vector3.UP, 0.37 * float(variation)), at)
	var woods: Array[Color] = [PALE_WOOD.darkened(0.08), DARK_WOOD.lightened(0.28), Color("#b98d5a")]
	for crate in range(2 + variation % 2):
		var corner := Vector3(-0.3 + 0.62 * float(crate % 2), 0.28 + 0.56 * float(crate >> 1), 0.05 * float(crate))
		detail.box(corner, Vector3(0.56, 0.56, 0.56), woods[(crate + variation) % 3], Basis(Vector3.UP, 0.2 * float(crate)))
		detail.box(corner + Vector3(0, 0.29, 0), Vector3(0.6, 0.05, 0.6), DARK_WOOD, Basis(Vector3.UP, 0.2 * float(crate)))
	detail.tube(Vector3(0.1, 0.34, 0.66), 0.25, 0.25, 0.68, Color("#9b6f47"), 10)
	for hoop: float in [0.16, 0.52]:
		detail.tube(Vector3(0.1, hoop, 0.66), 0.265, 0.265, 0.05, IRON, 10)
	detail.tube(Vector3(-0.55, 0.05, 0.6), 0.24, 0.24, 0.1, ROPE, 8)
	detail.tube(Vector3(-0.55, 0.12, 0.6), 0.17, 0.17, 0.08, ROPE.darkened(0.12), 8)
	detail.frame = Transform3D.IDENTITY

## Slatted bench facing local +Z.
static func bench(kit: Kit, at: Vector3, yaw: float) -> void:
	var detail := kit.detail
	detail.frame = Transform3D(Basis(Vector3.UP, yaw), at)
	detail.box(Vector3(0, 0.44, 0), Vector3(1.4, 0.06, 0.42), PALE_WOOD.darkened(0.12))
	detail.box(Vector3(0, 0.74, -0.2), Vector3(1.4, 0.3, 0.06), PALE_WOOD.darkened(0.12), Basis(Vector3.RIGHT, -0.15))
	for side: float in [-1.0, 1.0]:
		detail.box(Vector3(side * 0.6, 0.22, 0), Vector3(0.07, 0.44, 0.38), IRON)
		detail.box(Vector3(side * 0.6, 0.66, -0.2), Vector3(0.07, 0.5, 0.06), IRON)
	detail.frame = Transform3D.IDENTITY

## Post with a framed board; returns the label so callers can change its text.
static func signpost(world: Node3D, kit: Kit, at: Vector3, text: String, width: float, font_size := 22) -> Label3D:
	var detail := kit.detail
	detail.frame = Transform3D(Basis.IDENTITY, at)
	detail.box(Vector3(0, 0.75, 0), Vector3(0.1, 1.5, 0.1), DARK_WOOD)
	detail.tube(Vector3(0, 0.06, 0), 0.2, 0.14, 0.12, STONE, 8)
	detail.box(Vector3(0, 1.72, 0.04), Vector3(width, 0.46, 0.07), TEAL.darkened(0.1))
	for edge: float in [-1.0, 1.0]:
		detail.box(Vector3(0, 1.72 + edge * 0.25, 0.04), Vector3(width + 0.1, 0.05, 0.11), CREAM)
	detail.frame = Transform3D.IDENTITY
	return world._local_label(text, at + Vector3(0, 1.72, 0.24), font_size)
