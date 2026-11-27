extends RefCounted
## Everything in the Yoyo Hotel that moves: friendly little ghosts that drift
## about (the curious ones float over and wave when the walker comes near), the
## lost luggage spiralling up from its heap with umbrellas bobbing above it, the
## sheet and pillows hovering over the dream bed, the desk bell and the page
## walls that rustle as someone walks between them. Nothing here is saved; the
## reduced-motion pose is one still frame.

const Scenery := preload("res://game/world/hotel_scenery.gd")
const Kit := preload("res://game/world/scenery_kit.gd")
const GHOST_PIXELS := Vector2i(40, 48)
## About 38 texels a metre, inside the standard's 48 ±25%.
const GHOST_PIXEL_SIZE := 0.026
## A curious ghost drifts over to the walker inside this range.
const REACH := 3.4
## look, path ("hover", "line" or "orbit"), centre, sway (x, z), float height, cycles a second, curious.
const GHOSTS := [
	{"name": "Receptionist", "look": "cap", "path": "hover", "at": Vector3(-13.6, 0, -11.7), "sway": Vector2(0.35, 0.1), "height": 0.95, "speed": 0.18, "curious": false},
	{"name": "PageReader", "look": "plain", "path": "line", "at": Vector3(-1.6, 0, -7.6), "sway": Vector2(0.7, 3.4), "height": 1.0, "speed": 0.05, "curious": true},
	{"name": "PagePeeker", "look": "plain", "path": "hover", "at": Vector3(-3.5, 0, -11.6), "sway": Vector2(0.25, 0.2), "height": 2.5, "speed": 0.22, "curious": false},
	{"name": "Porter", "look": "cap", "path": "orbit", "at": Vector3(6.0, 0, -10.2), "sway": Vector2(1.9, 1.3), "height": 2.1, "speed": 0.06, "curious": false},
	{"name": "Sleeper", "look": "nightcap", "path": "hover", "at": Vector3(12.8, 0, -11.2), "sway": Vector2(0.25, 0.15), "height": 1.75, "speed": 0.12, "curious": false},
	{"name": "Greeter", "look": "plain", "path": "line", "at": Vector3(0.0, 0, 2.4), "sway": Vector2(13.5, 0.5), "height": 0.85, "speed": 0.025, "curious": true},
	{"name": "Dreamer", "look": "nightcap", "path": "line", "at": Vector3(12.8, 0, 5.4), "sway": Vector2(2.6, 1.2), "height": 1.1, "speed": 0.04, "curious": true},
]
const LUGGAGE := 9
const LUGGAGE_TINTS := [Color("#4f8f99"), Color("#e79bb6"), Color("#b7a3df"), Color("#c98d5a"), Color("#ffe6a8"), Color("#8fb0d8"), Color("#e2795e"), Color("#7fd0a8"), Color("#d9b45c")]
## Umbrellas over the lost room: centre x, z, height, drift radius.
const UMBRELLAS := [[3.4, -11.6, 3.4, 0.5], [8.0, -11.9, 3.0, 0.45], [4.0, -6.8, 3.6, 0.6], [7.9, -7.4, 3.9, 0.5], [5.0, -9.0, 4.3, 0.4]]
const UMBRELLA_TINTS := [Color("#e79bb6"), Color("#4f8f99"), Color("#ffe6a8"), Color("#b7a3df"), Color("#8fb0d8")]
const SHEET_SIZE := Vector2(2.3, 2.6)

static var _looks: Dictionary = {}

var world: Node3D
var scenery: Scenery
var ghosts: Array[Dictionary] = []
var bell: MeshInstance3D
var sheet: MeshInstance3D
var pillows: Array[MeshInstance3D] = []
var _luggage: MultiMesh
var _umbrellas: MultiMesh
var _ring := 0.0
var _spin := 0.0
var _dream := 0.0
var _rustle := 0.0
var _turn := 0.0
var _page_strength := -1.0
var _posed_still := false

func _init(owner: Node3D, hotel_scenery: Scenery) -> void:
	world = owner
	scenery = hotel_scenery

func build() -> void:
	var paint: Material = world._vertex_color_material("scenery-detail")
	var headless := DisplayServer.get_name() == "headless"
	for spec: Dictionary in GHOSTS:
		var root := Node3D.new()
		root.name = "HotelGhost_" + String(spec.name)
		world.add_child(root)
		var sprite := Sprite3D.new()
		sprite.name = "Body"
		sprite.texture = look(String(spec.look), false)
		sprite.pixel_size = GHOST_PIXEL_SIZE
		sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sprite.shaded = true
		sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		sprite.layers = world.SCENERY_RENDER_LAYER
		root.add_child(sprite)
		var material: ShaderMaterial = null
		if not headless:
			material = world._set_living_sprite_material(sprite, 2, float(ghosts.size()) * 1.3, 0.8)
			material.set_shader_parameter("gesture_pixels", 1.0)
			world.foliage_materials.append(material)
		# A soft round shade on the floor; ghosts cast no hard shadow.
		var shade := MeshInstance3D.new()
		shade.name = "Shade"
		var blob := PlaneMesh.new()
		blob.size = Vector2(0.9, 0.55)
		shade.mesh = blob
		shade.material_override = world.contact_shadow_material
		shade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(shade)
		world.mesh_count += 2
		ghosts.append({"spec": spec, "root": root, "sprite": sprite, "material": material, "at": _path(spec, 0.0), "waving": false})
	bell = world._mesh(_bell_mesh(), world.DESK + Vector3(0.95, 1.15, 0.2), paint)
	bell.name = "HotelDeskBell"
	sheet = world._mesh(_sheet_mesh(), world.BED + Vector3(0, 1.55, 0.3), scenery.kit.cloth_material("hotel-sheet", 0.12))
	sheet.name = "HotelFloatingSheet"
	sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	for index in 2:
		var pillow: MeshInstance3D = world._mesh(_pillow_mesh(Scenery.CREAM if index == 0 else Color("#d8ccff")), world.BED, paint)
		pillow.name = "HotelFloatingPillow%d" % index
		pillows.append(pillow)
	var transforms: Array[Transform3D] = []
	var tints: Array[Color] = []
	for index in LUGGAGE:
		transforms.append(Transform3D.IDENTITY)
		tints.append((LUGGAGE_TINTS[index] as Color).srgb_to_linear())
	var cases: MultiMeshInstance3D = world._multi_mesh(_suitcase_mesh(), Vector3.ZERO, transforms, tints, paint)
	cases.name = "HotelFloatingLuggage"
	_luggage = cases.multimesh
	_luggage.custom_aabb = AABB(Vector3(2.5, 0, -13.5), Vector3(7.0, 6.0, 7.0))
	transforms.clear()
	tints.clear()
	for index in UMBRELLAS.size():
		transforms.append(Transform3D.IDENTITY)
		tints.append((UMBRELLA_TINTS[index] as Color).srgb_to_linear())
	var shades: MultiMeshInstance3D = world._multi_mesh(_umbrella_mesh(), Vector3.ZERO, transforms, tints, paint)
	shades.name = "HotelFloatingUmbrellas"
	_umbrellas = shades.multimesh
	_umbrellas.custom_aabb = AABB(Vector3(2.0, 1.5, -13.5), Vector3(7.5, 4.5, 8.0))

## Reduced motion: pose once, then leave everything alone.
func hold_still() -> void:
	if _posed_still: return
	_ring = 0.0
	_spin = 0.0
	_dream = 0.0
	_rustle = 0.0
	_set_page_strength(0.03)
	for ghost: Dictionary in ghosts:
		ghost.at = _path(ghost.spec, 0.0)
		_wave(ghost, false)
	_pose(0.0, true)
	_posed_still = true

func animate(delta: float) -> void:
	_posed_still = false
	var time: float = world.time
	var walker: Vector3 = world.player_spot() if is_instance_valid(world.player) else Vector3.INF
	_ring = move_toward(_ring, 0.0, delta / 1.4)
	_spin = move_toward(_spin, 0.0, delta / 3.0)
	_dream = move_toward(_dream, 0.0, delta / 7.0)
	_rustle = move_toward(_rustle, 0.0, delta / 1.6)
	_turn += delta * (0.32 + _spin * 2.4)
	var follow := 1.0 - exp(-delta * 2.2)
	for index in ghosts.size():
		var ghost: Dictionary = ghosts[index]
		var spec: Dictionary = ghost.spec
		var wanted := _path(spec, time)
		var near := walker.is_finite() and bool(spec.curious) and Vector2(wanted.x - walker.x, wanted.z - walker.z).length() < REACH
		if near:
			# Float to the walker's side, a little behind, and wave.
			var side := signf(wanted.x - walker.x) if not is_zero_approx(wanted.x - walker.x) else 1.0
			wanted = Vector3(walker.x + side * 1.15, wanted.y, walker.z - 0.35)
		ghost.at = (ghost.at as Vector3).lerp(wanted, follow)
		_wave(ghost, near or (index == 0 and _ring > 0.05))
	_set_page_strength(0.03 + 0.1 * maxf(_page_closeness(walker), _rustle))
	_pose(time, false)

func ring_bell() -> void:
	_ring = 1.0

func rustle_pages() -> void:
	_rustle = 1.0

func spin_luggage() -> void:
	_spin = 1.0

func fluff_dream() -> void:
	_dream = 1.0

func apply_time_of_day(_lamp_level: float) -> void:
	pass

func ghost_position(index: int) -> Vector3:
	return (ghosts[index].root as Node3D).position + (ghosts[index].sprite as Sprite3D).position

func is_waving(index: int) -> bool:
	return bool(ghosts[index].waving)

func page_strength() -> float:
	return _page_strength

## Where a ghost's own route puts it at `time`, in district metres.
static func _path(spec: Dictionary, time: float) -> Vector3:
	var at: Vector3 = spec.at
	var sway: Vector2 = spec.sway
	var cycle := time * float(spec.speed) * TAU + float(String(spec.name).length())
	match String(spec.path):
		"orbit":
			return at + Vector3(cos(cycle) * sway.x, 0, sin(cycle) * sway.y)
		"line":
			return at + Vector3(sin(cycle) * sway.x, 0, sin(cycle * 0.63 + 1.1) * sway.y)
	return at + Vector3(sin(cycle) * sway.x, 0, cos(cycle * 1.3) * sway.y)

## How close the walker is to the page walls, 0..1, inside the corridor.
func _page_closeness(walker: Vector3) -> float:
	if not walker.is_finite() or walker.z < Scenery.PAGE_FROM or walker.z > Scenery.PAGE_TO + 1.0: return 0.0
	var gap := INF
	for x: float in Scenery.PAGE_WALLS:
		gap = minf(gap, absf(walker.x - x))
	return 1.0 - smoothstep(0.6, 2.6, gap)

func _set_page_strength(value: float) -> void:
	if is_equal_approx(value, _page_strength): return
	_page_strength = value
	scenery.pages.set_shader_parameter("strength", value)

func _wave(ghost: Dictionary, waving: bool) -> void:
	if bool(ghost.waving) == waving: return
	ghost.waving = waving
	var texture := look(String(ghost.spec.look), waving)
	(ghost.sprite as Sprite3D).texture = texture
	var material := ghost.material as ShaderMaterial
	if material != null: material.set_shader_parameter("texture_albedo", texture)

func _pose(time: float, still: bool) -> void:
	for index in ghosts.size():
		var ghost: Dictionary = ghosts[index]
		var spec: Dictionary = ghost.spec
		var at: Vector3 = ghost.at
		var root: Node3D = ghost.root
		root.position = Vector3(at.x, world.ground_surface_y(at) + 0.012, at.z)
		var lift := float(spec.height) + (0.55 * _ring if index == 0 else 0.0)
		var bob := 0.0 if still else sin(time * 1.7 + float(index) * 1.9) * 0.12
		(ghost.sprite as Sprite3D).position = Vector3(0, lift + bob + GHOST_PIXELS.y * GHOST_PIXEL_SIZE * 0.5, 0)
		var shade: MeshInstance3D = root.get_child(1)
		shade.scale = Vector3.ONE * clampf(1.15 - 0.22 * (lift + bob), 0.45, 1.0)
	bell.rotation = Vector3(0, 0, 0.0 if still else sin(time * 32.0) * 0.32 * _ring)
	var bed: Vector3 = world.BED
	var dream_lift := 0.8 * _dream
	sheet.position = bed + Vector3(0, 1.55 + dream_lift + (0.0 if still else sin(time * 0.9) * 0.1), 0.3)
	sheet.rotation = Vector3(0.0 if still else sin(time * 0.7) * 0.06, 0, 0.0 if still else sin(time * 0.55 + 1.0) * 0.05)
	for index in pillows.size():
		var side := -0.55 if index == 0 else 0.55
		var bob := 0.0 if still else sin(time * 1.2 + float(index) * 2.1) * 0.08
		pillows[index].position = bed + Vector3(side, 1.15 + 0.6 * _dream + float(index) * 0.18 + bob, -1.05)
		pillows[index].rotation = Vector3(0, 0, 0.0 if still else sin(time * 0.8 + float(index)) * 0.18)
	var tower: Vector3 = world.LOST_TOWER
	for index in LUGGAGE:
		var angle := float(index) * 0.92 + _turn
		var radius := 0.75 + 0.18 * sin(float(index) * 1.7)
		var bob := 0.0 if still else sin(time * 1.3 + float(index) * 0.8) * 0.06
		var spot := tower + Vector3(cos(angle) * radius, 1.15 + float(index) * 0.42 + bob, sin(angle) * radius * 0.8)
		var basis := Basis(Vector3.UP, -angle + float(index)) * Basis(Vector3.BACK, sin(float(index) * 2.3) * 0.35)
		_luggage.set_instance_transform(index, Transform3D(basis, spot))
	for index in UMBRELLAS.size():
		var spec: Array = UMBRELLAS[index]
		var drift := 0.0 if still else time * 0.3 + float(index) * 1.4
		var spot := Vector3(float(spec[0]) + cos(drift) * float(spec[3]), float(spec[2]) + (0.0 if still else sin(time * 0.9 + float(index)) * 0.15), float(spec[1]) + sin(drift) * float(spec[3]) * 0.6)
		var tilt := Basis(Vector3.BACK, sin(drift * 1.3) * 0.18) * Basis(Vector3.UP, drift)
		_umbrellas.set_instance_transform(index, Transform3D(tilt, spot))

# --- Meshes and pictures ---------------------------------------------------------

func _bell_mesh() -> ArrayMesh:
	var s := Kit.Sculpt.new()
	s.tube(Vector3(0, 0.02, 0), 0.16, 0.16, 0.04, Scenery.DARK_WOOD, 12)
	s.ball(Vector3(0, 0.04, 0), 0.13, Scenery.GOLD, Scenery.GOLD.lightened(0.15), 10, 4, 0.85, true)
	s.tube(Vector3(0, 0.17, 0), 0.025, 0.02, 0.05, Scenery.GOLD.darkened(0.15), 6)
	s.ball(Vector3(0, 0.21, 0), 0.03, Scenery.GOLD.lightened(0.2), Color.TRANSPARENT, 6, 3)
	return s.mesh()

## A cloth sheet lying flat, free at its edges so they ripple; its own origin is its centre.
func _sheet_mesh() -> ArrayMesh:
	const CELLS := 8
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tone := Scenery.SHEET.srgb_to_linear()
	var stripe := Color("#e3dafa").srgb_to_linear()
	for row in CELLS:
		for column in CELLS:
			for corner: Vector2i in [Vector2i(0, 0), Vector2i(1, 1), Vector2i(1, 0), Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1)]:
				var u := float(column + corner.x) / float(CELLS)
				var v := float(row + corner.y) / float(CELLS)
				var edge := maxf(absf(u - 0.5), absf(v - 0.5)) * 2.0
				tool.set_color(stripe if row % 3 == 1 else tone)
				tool.set_normal(Vector3.UP)
				tool.set_uv(Vector2(u, v))
				tool.set_uv2(Vector2(edge * edge, 0.0))
				# The corners droop a little, like a sheet caught mid-air.
				tool.add_vertex(Vector3((u - 0.5) * SHEET_SIZE.x, -0.18 * edge * edge, (v - 0.5) * SHEET_SIZE.y))
	return tool.commit()

func _pillow_mesh(tone: Color) -> ArrayMesh:
	var s := Kit.Sculpt.new()
	s.ball(Vector3.ZERO, 0.4, tone, tone.darkened(0.06), 10, 4, 0.38)
	for corner: float in [-1.0, 1.0]:
		s.ball(Vector3(corner * 0.36, 0, 0), 0.08, tone.darkened(0.04), Color.TRANSPARENT, 6, 3)
	return s.mesh()

## A suitcase in pale paint, so each copy takes its own colour; straps and a handle.
func _suitcase_mesh() -> ArrayMesh:
	var s := Kit.Sculpt.new()
	s.box(Vector3.ZERO, Vector3(0.62, 0.42, 0.24), Color("#f2f2f2"))
	s.box(Vector3.ZERO, Vector3(0.64, 0.34, 0.26), Color("#d8d8d8"))
	for strap: float in [-0.17, 0.17]:
		s.box(Vector3(strap, 0, 0), Vector3(0.05, 0.44, 0.27), Color("#6f5a48"))
	s.box(Vector3(0, 0.25, 0), Vector3(0.18, 0.05, 0.05), Color("#8a7254"))
	s.box(Vector3(0.22, -0.05, 0.13), Vector3(0.1, 0.12, 0.01), Color("#fff6df"))
	return s.mesh()

## An open umbrella: alternating canopy panels, a shaft and a crook handle.
func _umbrella_mesh() -> ArrayMesh:
	var s := Kit.Sculpt.new()
	const PANELS := 8
	var apex := Vector3(0, 0.32, 0)
	for panel in PANELS:
		var a := Vector3(cos(TAU * float(panel) / PANELS), 0, sin(TAU * float(panel) / PANELS)) * 0.62
		var b := Vector3(cos(TAU * float(panel + 1) / PANELS), 0, sin(TAU * float(panel + 1) / PANELS)) * 0.62
		s.sheet(apex, a, b, Color("#f6f6f6") if panel % 2 == 0 else Color("#d6d6d6"))
	s.tube(apex + Vector3(0, 0.06, 0), 0.02, 0.01, 0.12, Color("#5a4636"), 5)
	s.tube(Vector3(0, -0.3, 0), 0.015, 0.015, 0.95, Color("#5a4636"), 5)
	s.box(Vector3(0.05, -0.78, 0), Vector3(0.12, 0.035, 0.035), Color("#7a5638"))
	s.box(Vector3(0.1, -0.72, 0), Vector3(0.035, 0.12, 0.035), Color("#7a5638"))
	return s.mesh()

## The ghost picture for a look, drawn once per process: a round sheet with a
## wavy hem, a lavender outline (never black), shy eyes and pink cheeks. Waving,
## one little arm is up.
static func look(kind: String, waving: bool) -> ImageTexture:
	var key := kind + (":wave" if waving else "")
	if _looks.has(key): return _looks[key]
	var w := GHOST_PIXELS.x
	var h := GHOST_PIXELS.y
	var image := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var body := Color("#f7f3ff")
	var shade := Color("#ddd3f4")
	var line := Color("#8f80bd")
	var inside := PackedByteArray()
	inside.resize(w * h)
	for y in h:
		for x in w:
			var dx := float(x) + 0.5 - 20.0
			var dy := float(y) + 0.5 - 21.0
			var hem := 42.0 + 2.6 * sin(float(x) * 0.7 + 0.6)
			var skirt := float(y) >= 21.0 and absf(dx) <= 13.5 + (float(y) - 21.0) * 0.08 and float(y) <= hem
			var arm := float(y) >= 29.0 and float(y) <= 32.0 and ((x >= 4 and x <= 6) or (not waving and x >= 33 and x <= 35))
			var raised := waving and x >= 32 and x <= 35 and y >= 15 and y <= 22 and float(x - 32) * 2.0 >= float(22 - y) - 4.0
			if dx * dx + dy * dy <= 13.5 * 13.5 or skirt or arm or raised:
				inside[y * w + x] = 1
	for y in h:
		for x in w:
			if inside[y * w + x] == 1:
				var lit := float(x) < 26.0 and float(y) < 38.0
				image.set_pixel(x, y, body if lit else shade)
			else:
				for step: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var nx := x + step.x
					var ny := y + step.y
					if nx >= 0 and ny >= 0 and nx < w and ny < h and inside[ny * w + nx] == 1:
						image.set_pixel(x, y, line)
						break
	var eye := Color("#3d2f55")
	for side: int in [15, 25]:
		for dy in 4:
			for dx in 3:
				if (dx == 0 or dx == 2) and (dy == 0 or dy == 3): continue
				image.set_pixel(side - 1 + dx, 21 + dy, eye)
		image.set_pixel(side - 1, 22, Color.WHITE)
	for cheek: int in [11, 27]:
		for dx in 3:
			image.set_pixel(cheek + dx, 27, Color("#ffb3c7"))
			image.set_pixel(cheek + dx, 28, Color("#ffc9d7"))
	for spot: Vector2i in [Vector2i(19, 28), Vector2i(20, 29), Vector2i(21, 28)]:
		image.set_pixel(spot.x, spot.y, eye)
	match kind:
		"cap":
			# A red bellhop cap with a gold band, worn at a jaunty tilt.
			for y in range(4, 10):
				for x in range(13 + int((9 - y) / 3.0), 26 + int((9 - y) / 3.0)):
					image.set_pixel(x, y, Color("#d9b45c") if y >= 8 else Color("#c8463c"))
			for x in range(13, 27):
				image.set_pixel(x, 10, Color("#8a2f2a"))
		"nightcap":
			# A floppy blue nightcap with a star pompom.
			for y in range(2, 11):
				var reach := 26 + (y - 2)
				for x in range(12 + maxi(0, 6 - y), mini(reach, 36)):
					if y < 6 and x > 20 + y * 2: continue
					image.set_pixel(x, y, Color("#6f86d6") if (x + y) % 5 != 0 else Color("#8ea2e6"))
			for x in range(12, 29):
				image.set_pixel(x, 10, Color("#f4ecd8"))
			for spot: Vector2i in [Vector2i(35, 10), Vector2i(36, 11), Vector2i(35, 12), Vector2i(34, 11), Vector2i(35, 11)]:
				image.set_pixel(spot.x, spot.y, Color("#ffe6a8"))
	var texture := ImageTexture.create_from_image(image)
	_looks[key] = texture
	return texture
