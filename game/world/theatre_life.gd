extends RefCounted
## Everything in the underground theatre that moves: the two halves of the
## velvet curtain, which draw open as the walker comes toward the stage and
## close again behind them; the stage spotlight, which picks the walker up on
## the stage or the curtain-call dais and rests on the stage's middle
## otherwise; the costumes swinging on their rail (a rummage sets them going);
## the pit's band of instruments that bounce when asked to strike up; the rose
## petals that shower the dais at a practised bow; the marquee's bulbs chasing
## on the islet; and the short fade between the islet and the theatre. Built
## once; nothing here is saved, and the reduced-motion pose is one still frame.

const Scenery := preload("res://game/world/theatre_scenery.gd")
const Kit := preload("res://game/world/scenery_kit.gd")
const BEAM := preload("res://game/world/cinema_beam.gdshader")
const POOL := preload("res://game/world/spot_pool.gdshader")
const CURTAIN_SECONDS := 1.3
const SPOT_HEIGHT := 8.6
const SPOT_REACH := 15.0
const FLARE_SECONDS := 1.6
const SWING_SECONDS := 2.4
const STRIKE_SECONDS := 1.4
const PETAL_SECONDS := 3.2
const PETALS := 36
const MARQUEE_SECONDS := 2.0
## Region colours of the costumes on the rail, in the order they are rummaged.
const COSTUME_COLORS := [Color("#e2795e"), Color("#3d6f9a"), Color("#e85a7a"), Color("#e0533f"), Color("#c8463c"),
	Color("#3b82c4"), Color("#5f7f45"), Color("#7a5a9e"), Color("#7cc4ec"), Color("#a8243a")]

var world: Node3D
var scenery: Scenery
var curtains: Array[Node3D] = []
var spot_rig: Node3D
var spot_light: SpotLight3D
var spot_pool: MeshInstance3D
var beam_material: ShaderMaterial
var pool_material: ShaderMaterial
var costumes: Array[Node3D] = []
var band: Node3D
var petals: MultiMeshInstance3D
var fade_layer: CanvasLayer
var fade_rect: ColorRect
var marquee_material: StandardMaterial3D
var _open := 0.0
var _aim := Vector3.ZERO
var _flare := 0.0
var _swing := 0.0
var _swung := -1
var _strike := 0.0
var _petals := 0.0
var _marquee := 0.0
var _time := 0.0
var _petal_seeds := PackedVector3Array()

func _init(owner: Node3D, theatre_scenery: Scenery) -> void:
	world = owner
	scenery = theatre_scenery

func build() -> void:
	_build_curtains()
	_build_spotlight()
	_build_costumes()
	_build_band()
	_build_petals()
	_aim = world.STAGE_CENTRE

# --- Curtains -------------------------------------------------------------------

## Each half is a deep velvet drape of rounded folds hung from a rod, with a
## gold fringe along its foot; it is drawn aside by sliding to its side of the
## opening and gathering its folds.
func _build_curtains() -> void:
	var y: float = world.pad("stage").y
	var height := 5.9
	var half: float = (world.CURTAIN_TO - world.CURTAIN_FROM) * 0.5
	var drape := Kit.Sculpt.new()
	var folds := 9
	for fold in folds:
		var x := (float(fold) + 0.5) / float(folds) * half
		var tone := Scenery.VELVET.darkened(0.16 * float(fold % 2))
		drape.tube(Vector3(x, height * 0.5, 0.06 * float(fold % 2)), half / float(folds) * 0.62, half / float(folds) * 0.58, height, tone, 8)
		drape.box(Vector3(x, 0.08, 0.12), Vector3(half / float(folds), 0.12, 0.04), Scenery.GOLD)
	drape.box(Vector3(half * 0.5, height + 0.04, 0), Vector3(half + 0.1, 0.08, 0.08), Scenery.BRASS)
	var mesh := drape.mesh()
	for side: float in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.name = "TheatreCurtain%d" % curtains.size()
		# Each half hangs from the outer edge of the opening; scaling its x gathers it there.
		pivot.position = Vector3(world.CURTAIN_FROM if side < 0.0 else world.CURTAIN_TO, y, world.CURTAIN_Z)
		pivot.scale.x = 1.0 if side < 0.0 else -1.0
		world.add_child(pivot)
		var cloth := MeshInstance3D.new()
		cloth.name = "Drape"
		cloth.mesh = mesh
		cloth.material_override = scenery._painted()
		pivot.add_child(cloth)
		world.mesh_count += 1
		curtains.append(pivot)

## 0 shut, 1 drawn fully aside.
func curtain_open() -> float:
	return _open

## The curtain is open while the walker is on the stage, the dais or in the
## pit, or anywhere in the house within reach of the stage's front.
func wants_curtain_open(walker: Vector3) -> bool:
	if not world.is_below(walker.y): return false
	if world._area_id(walker) in ["stage", "bow", "pit"]: return true
	return Vector2(walker.x - world.STAGE_CENTRE.x, walker.z - (world.STAGE_CENTRE.z + 2.0)).length() < world.CURTAIN_REACH

func _pose_curtains() -> void:
	var gathered := lerpf(1.0, 0.16, _open)
	for index in curtains.size():
		curtains[index].scale.x = gathered * (1.0 if index == 0 else -1.0)

# --- Spotlight ---------------------------------------------------------------------

## A follow spot hung high over the front of the house: a dusty cone of light,
## the bright pool it throws and a real spot lamp in the theatre's lamp budget.
func _build_spotlight() -> void:
	spot_rig = Node3D.new()
	spot_rig.name = "TheatreSpotlight"
	spot_rig.position = Vector3(-9.3, world.FLOOR + SPOT_HEIGHT, 4.6)
	world.add_child(spot_rig)
	beam_material = world.material_cache.get("theatre:beam")
	if beam_material == null:
		beam_material = ShaderMaterial.new()
		beam_material.shader = BEAM
		beam_material.set_shader_parameter("tint", Color(1.0, 0.93, 0.78))
		beam_material.set_shader_parameter("strength", 0.34)
		beam_material.set_shader_parameter("fade_power", 0.6)
		world.material_cache["theatre:beam"] = beam_material
	var cone := CylinderMesh.new()
	cone.top_radius = 0.14
	cone.bottom_radius = 1.25
	cone.height = SPOT_REACH
	cone.radial_segments = 14
	cone.cap_top = false
	cone.cap_bottom = false
	var beam := MeshInstance3D.new()
	beam.name = "Beam"
	beam.mesh = cone
	beam.material_override = beam_material
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The cone's narrow end sits on the lamp and its axis follows the rig's aim.
	beam.rotation.x = PI * 0.5
	beam.position.z = -SPOT_REACH * 0.5
	spot_rig.add_child(beam)
	world.mesh_count += 1
	var head := Kit.Sculpt.new()
	head.tube(Vector3(0, 0, 0.3), 0.3, 0.26, 0.8, Color("#2e2a33"), 10, Basis(Vector3.RIGHT, PI * 0.5))
	head.tube(Vector3(0, 0, -0.12), 0.27, 0.27, 0.04, Color(1.0, 0.95, 0.82), 10, Basis(Vector3.RIGHT, PI * 0.5))
	head.box(Vector3(0, 0.42, 0.3), Vector3(0.08, 0.5, 0.08), Color("#4a4452"))
	var housing := MeshInstance3D.new()
	housing.name = "Head"
	housing.mesh = head.mesh()
	housing.material_override = world._vertex_color_material("scenery-detail")
	spot_rig.add_child(housing)
	world.mesh_count += 1
	spot_light = SpotLight3D.new()
	spot_light.name = "Lamp"
	spot_light.light_color = Color(1.0, 0.94, 0.82)
	spot_light.spot_range = SPOT_REACH + 2.0
	spot_light.spot_angle = 13.0
	spot_light.spot_attenuation = 0.35
	spot_light.light_energy = 0.0
	spot_light.set_meta(&"level", 6.0)
	spot_light.set_meta(&"always_shadow", true)
	spot_rig.add_child(spot_light)
	world.lamps.append(spot_light)
	pool_material = world.material_cache.get("theatre:pool")
	if pool_material == null:
		pool_material = ShaderMaterial.new()
		pool_material.shader = POOL
		pool_material.set_shader_parameter("pool_color", Color(1.0, 0.9, 0.66))
		pool_material.set_shader_parameter("intensity", 0.75)
		world.material_cache["theatre:pool"] = pool_material
	var disc := QuadMesh.new()
	disc.size = Vector2(3.0, 3.0)
	disc.orientation = PlaneMesh.FACE_Y
	spot_pool = world._mesh(disc, Vector3.ZERO, pool_material)
	spot_pool.name = "TheatreSpotPool"
	spot_pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

## Where the spot points: the walker on the stage or the dais, else the stage's middle.
func spot_target() -> Vector3:
	return _aim

func _aim_spot(target: Vector3) -> void:
	_aim = target
	spot_rig.look_at(world.to_global(target + Vector3(0, 0.9, 0)), Vector3.UP)
	spot_pool.position = target + Vector3(0, 0.03, 0)

# --- Costumes ----------------------------------------------------------------------

## Ten costumes on hangers along the rail, one per region, each on its own
## hook so the rummaged one can swing out.
func _build_costumes() -> void:
	var rail: Vector3 = world.COSTUME_RAIL
	var hanger := Kit.Sculpt.new()
	hanger.box(Vector3(0, -0.04, 0), Vector3(0.03, 0.08, 0.03), Scenery.BRASS)
	hanger.box(Vector3(0, -0.12, 0), Vector3(0.05, 0.04, 0.42), Scenery.BRASS)
	for index in COSTUME_COLORS.size():
		var hook := Node3D.new()
		hook.name = "TheatreCostume%d" % index
		hook.position = rail + Vector3(0.02, 1.86, -1.1 + float(index) * 0.245)
		world.add_child(hook)
		var cloth := Kit.Sculpt.new()
		var tone: Color = COSTUME_COLORS[index]
		cloth.box(Vector3(0, -0.12, 0), Vector3(0.05, 0.04, 0.42), Scenery.BRASS)
		cloth.tube(Vector3(0, -0.6, 0), 0.2, 0.16, 0.9, tone, 8, Basis.from_scale(Vector3(0.45, 1.0, 1.0)))
		cloth.tube(Vector3(0, -1.2, 0), 0.32, 0.2, 0.4, tone.darkened(0.15), 8, Basis.from_scale(Vector3(0.45, 1.0, 1.0)))
		cloth.ball(Vector3(0.05, -0.4, 0), 0.06, Scenery.GOLD if index % 2 == 0 else Scenery.CREAM, Color.TRANSPARENT, 6, 3)
		var drawn := MeshInstance3D.new()
		drawn.mesh = cloth.mesh()
		drawn.material_override = scenery._painted()
		hook.add_child(drawn)
		world.mesh_count += 1
		costumes.append(hook)

func costume_swing() -> float:
	return costumes[maxi(_swung, 0)].rotation.z

# --- Band ---------------------------------------------------------------------------

## The pit's instruments as one piece: a grand piano with its lid up, a drum
## kit and a double bass on its spike; it hops when the band strikes up.
func _build_band() -> void:
	var pit: Dictionary = world.pad("pit")
	var y: float = pit.y
	var kit := Kit.Sculpt.new()
	var piano := Vector3(-6.0, 0, 1.0)
	kit.box(piano + Vector3(0, 0.75, 0), Vector3(1.4, 0.3, 1.1), Scenery.NIGHT)
	kit.tube(piano + Vector3(0.5, 0.75, -0.25), 0.62, 0.62, 0.3, Scenery.NIGHT, 12)
	kit.box(piano + Vector3(-0.1, 1.25, -0.2), Vector3(1.3, 0.04, 1.0), Scenery.INK, Basis(Vector3.BACK, 0.12) * Basis(Vector3.RIGHT, -0.6))
	kit.box(piano + Vector3(-0.2, 0.88, 0.5), Vector3(1.0, 0.04, 0.16), Scenery.CREAM)
	for leg: Vector2 in [Vector2(-0.6, 0.45), Vector2(0.6, 0.45), Vector2(0.4, -0.6)]:
		kit.box(piano + Vector3(leg.x, 0.3, leg.y), Vector3(0.1, 0.6, 0.1), Scenery.NIGHT)
	var drums := Vector3(-13.4, 0, 0.9)
	kit.tube(drums + Vector3(0, 0.36, 0), 0.38, 0.38, 0.5, Scenery.CREAM, 12, Basis(Vector3.RIGHT, PI * 0.5))
	kit.tube(drums + Vector3(0, 0.36, 0.27), 0.3, 0.3, 0.02, Scenery.VELVET, 12, Basis(Vector3.RIGHT, PI * 0.5))
	for tom: Vector3 in [Vector3(-0.5, 0.72, 0.1), Vector3(0.5, 0.7, 0.1), Vector3(0.0, 0.9, -0.1)]:
		kit.tube(drums + tom, 0.18, 0.18, 0.2, Scenery.CREAM.darkened(0.08), 10)
	kit.tube(drums + Vector3(0.75, 1.1, -0.1), 0.26, 0.26, 0.02, Scenery.GOLD, 10)
	kit.box(drums + Vector3(0.75, 0.55, -0.1), Vector3(0.03, 1.1, 0.03), Scenery.INK)
	var bass := Vector3(-11.6, 0, 0.7)
	kit.tube(bass + Vector3(0, 0.75, 0), 0.32, 0.24, 1.0, Color("#8a4a2a"), 10, Basis.from_scale(Vector3(1.0, 1.0, 0.45)))
	kit.box(bass + Vector3(0, 1.6, 0.05), Vector3(0.08, 0.9, 0.06), Scenery.NIGHT)
	kit.ball(bass + Vector3(0, 2.05, 0.05), 0.07, Color("#8a4a2a"), Color.TRANSPARENT, 6, 3)
	kit.box(bass + Vector3(0, 0.1, 0), Vector3(0.03, 0.2, 0.03), Scenery.INK)
	band = Node3D.new()
	band.name = "TheatreBand"
	band.position = Vector3(0, y, 0)
	world.add_child(band)
	var drawn := MeshInstance3D.new()
	drawn.mesh = kit.mesh()
	drawn.material_override = scenery._painted()
	band.add_child(drawn)
	world.mesh_count += 1
	for spot: Vector3 in [piano, drums, bass]:
		world._kit_down.blocker(Vector3(spot.x, y + 1.0, spot.z), Vector3(1.4 if spot == piano else 0.9, 2.0, 1.2 if spot == piano else 0.8))

func band_lift() -> float:
	return band.position.y - float(world.pad("pit").y)

# --- Petals --------------------------------------------------------------------------

func _build_petals() -> void:
	var petal := Kit.Sculpt.new()
	petal.sheet(Vector3(-0.07, 0, 0), Vector3(0.07, 0, 0), Vector3(0, 0.02, 0.1), Color.WHITE)
	var transforms: Array[Transform3D] = []
	var tints: Array[Color] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 7103
	for index in PETALS:
		transforms.append(Transform3D(Basis.from_scale(Vector3.ONE * 0.001), Vector3.ZERO))
		tints.append((Color("#e2405a") if index % 3 != 0 else Color("#ffd0dc")).srgb_to_linear())
		_petal_seeds.append(Vector3(rng.randf_range(-1.3, 1.3), rng.randf_range(0.0, 1.0), rng.randf_range(-1.3, 1.3)))
	petals = world._multi_mesh(petal.mesh(), world.PHOTO_SPOT, transforms, tints, world._vertex_color_material("theatre-petals"))
	petals.name = "TheatrePetals"
	petals.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	petals.multimesh.custom_aabb = AABB(Vector3(-2, -0.5, -2), Vector3(4, 6, 4))
	petals.visible = false

func petals_falling() -> bool:
	return petals.visible

func _pose_petals() -> void:
	var t := 1.0 - _petals / PETAL_SECONDS
	for index in PETALS:
		var seed := _petal_seeds[index]
		var fall := clampf(t * 1.3 - seed.y * 0.3, 0.0, 1.0)
		var at := Vector3(seed.x + sin(t * 9.0 + seed.y * 6.0) * 0.25, 5.0 * (1.0 - fall) + 0.02, seed.z + cos(t * 7.0 + seed.x) * 0.2)
		var turn := Basis(Vector3.UP, t * 6.0 + seed.x * 3.0) * Basis(Vector3.RIGHT, sin(t * 11.0 + seed.z) * 0.8)
		petals.multimesh.set_instance_transform(index, Transform3D(turn, at))

# --- Fade between the levels ---------------------------------------------------------

## A screen-wide black card the passage between the levels fades through.
func build_fade() -> void:
	fade_layer = CanvasLayer.new()
	fade_layer.name = "TheatreFade"
	fade_layer.layer = 40
	world.add_child(fade_layer)
	fade_rect = ColorRect.new()
	fade_rect.color = Color(0.03, 0.01, 0.05, 0.0)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_layer.add_child(fade_rect)
	fade_layer.visible = false

func set_fade(amount: float) -> void:
	fade_rect.color.a = amount
	fade_layer.visible = amount > 0.001

func fade_amount() -> float:
	return fade_rect.color.a if fade_layer.visible else 0.0

# --- Reactions ------------------------------------------------------------------------

func flash_marquee() -> void:
	_marquee = MARQUEE_SECONDS

func swing_costumes(index: int) -> void:
	_swung = index % costumes.size()
	_swing = SWING_SECONDS

func strike_up() -> void:
	_strike = STRIKE_SECONDS

func flare_spotlight() -> void:
	_flare = FLARE_SECONDS

func shower_petals() -> void:
	_petals = PETAL_SECONDS
	petals.visible = true

# --- Time -----------------------------------------------------------------------------

func apply_time_of_day(_lamp_level: float) -> void:
	_apply_flare()

func _apply_flare() -> void:
	beam_material.set_shader_parameter("strength", 0.34 + 0.4 * (_flare / FLARE_SECONDS))
	pool_material.set_shader_parameter("intensity", 0.75 + 0.5 * (_flare / FLARE_SECONDS))

func animate(delta: float, walker: Vector3) -> void:
	_time += delta
	beam_material.set_shader_parameter("motion", 1.0)
	# Curtains: open while the walker is near the front of the stage on the theatre's level.
	var near := wants_curtain_open(walker)
	_open = move_toward(_open, 1.0 if near else 0.0, delta / CURTAIN_SECONDS)
	_pose_curtains()
	# The follow spot picks the walker up on the stage and the dais.
	var area: String = world._area_id(walker)
	var target: Vector3 = walker if world.is_below(walker.y) and area in ["stage", "bow"] else world.STAGE_CENTRE
	_aim_spot(_aim.lerp(target, minf(1.0, delta * 3.5)))
	if _flare > 0.0:
		_flare = maxf(0.0, _flare - delta)
		_apply_flare()
	# Costumes sway a little on their own; the rummaged one swings out and settles.
	_swing = maxf(0.0, _swing - delta)
	for index in costumes.size():
		var sway := sin(_time * 1.3 + float(index) * 0.9) * 0.03
		if index == _swung and _swing > 0.0: sway += sin(_swing * 7.0) * 0.6 * (_swing / SWING_SECONDS)
		costumes[index].rotation.z = sway
	# The band hops in time when it strikes up.
	_strike = maxf(0.0, _strike - delta)
	band.position.y = float(world.pad("pit").y) + absf(sin(_strike * 9.0)) * 0.16 * (_strike / STRIKE_SECONDS)
	if _petals > 0.0:
		_petals = maxf(0.0, _petals - delta)
		_pose_petals()
		petals.visible = _petals > 0.0
	if _marquee > 0.0:
		_marquee = maxf(0.0, _marquee - delta)
		# The marquee's bulbs blaze, then settle back to the hour's glow.
		scenery.kit_up.set_glow(scenery.glow_base + 2.4 * _marquee / MARQUEE_SECONDS * (0.6 + 0.4 * sin(_time * 18.0)))

## One still frame: curtains at rest where they belong, the spot on the stage's
## middle, costumes and band at rest, no petals, the dust in the beam held.
func hold_still() -> void:
	beam_material.set_shader_parameter("motion", 0.0)
	var walker: Vector3 = world.player_spot() if is_instance_valid(world.player) else world.ENTRY
	var near := wants_curtain_open(walker)
	_open = 1.0 if near else 0.0
	_pose_curtains()
	_aim_spot(world.STAGE_CENTRE)
	_flare = 0.0
	_apply_flare()
	_swing = 0.0
	for hook in costumes:
		hook.rotation.z = 0.0
	_strike = 0.0
	band.position.y = float(world.pad("pit").y)
	_petals = 0.0
	petals.visible = false
	_marquee = 0.0
	scenery.kit_up.set_glow(scenery.glow_base)
