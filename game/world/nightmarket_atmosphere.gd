extends Node3D
## Local lighting and horizon composition for the rainy market.

const SkylineShader = preload("res://game/world/nightmarket_skyline.gdshader")
const WetStreetShader = preload("res://game/world/nightmarket_wet_street.gdshader")
const PALETTES := {
	"dawn": {
		"haze": Color("#343754"), "fill": Color("#c5ccec"), "key": Color("#ffccaf"),
		"fill_energy": 0.80, "key_energy": 0.44, "pool_energy": 0.78,
		"reflected_sky": Color("#758da8"),
	},
	"noon": {
		"haze": Color("#414861"), "fill": Color("#d7e3ff"), "key": Color("#e7edff"),
		"fill_energy": 0.87, "key_energy": 0.59, "pool_energy": 0.62,
		"reflected_sky": Color("#a3b1bc"),
	},
	"dusk": {
		"haze": Color("#35304e"), "fill": Color("#c2bde9"), "key": Color("#ffc6a5"),
		"fill_energy": 0.83, "key_energy": 0.38, "pool_energy": 0.93,
		"reflected_sky": Color("#7488a4"),
	},
	"night": {
		"haze": Color("#252744"), "fill": Color("#afc6fc"), "key": Color("#b2c4ff"),
		"fill_energy": 0.86, "key_energy": 0.34, "pool_energy": 1.02,
		"reflected_sky": Color("#567baf"),
	},
}
const POOLS := [
	{"id": "west", "position": Vector3(-7.7, 2.72, 2.8), "color": Color("#ffbd80"), "range": 5.8},
	{"id": "east", "position": Vector3(7.7, 2.72, -0.25), "color": Color("#ff998d"), "range": 5.8},
	{"id": "roof", "position": Vector3(0.0, 3.62, -11.7), "color": Color("#ffd3a4"), "range": 5.0},
]
const LIGHT_UPDATE_INTERVAL := 0.14
const CLOSED_LIGHT_SCALE := 0.24

var _skyline: ShaderMaterial
var _pools: Array[OmniLight3D] = []
var _street_paving: ShaderMaterial
var _roof_paving: ShaderMaterial
## The unlit lanes around the street share the wet look in a darker stone.
var _lane_paving: ShaderMaterial
var _pavings: Array[ShaderMaterial] = []
var _operating := true
var _reduced_motion := false
var _light_energy := 0.62
var _pulse_phase := 0.0
var _until_update := 0.0

func setup(skyline: Texture2D, stone_atlas: Texture2D, shelter: Rect2) -> void:
	_street_paving = _make_paving(stone_atlas, shelter, false, Color("#8c96a2"))
	_roof_paving = _make_paving(stone_atlas, shelter, true, Color("#978b9d"))
	_lane_paving = _make_paving(stone_atlas, shelter, false, Color("#6a7285"))
	if skyline != null:
		_build_skyline(skyline)
	if DisplayServer.get_name() != "headless":
		_build_pools()
	apply_palette("noon")
	_sync_animation()

func paving_material(rooftop := false, lane := false) -> ShaderMaterial:
	if lane:
		return _lane_paving
	return _roof_paving if rooftop else _street_paving

## The market's own sky, fill and key light for `phase`, as light targets for
## the world to blend (see park_world's _air); this node never writes the sky.
static func air(phase: String) -> Dictionary:
	var palette: Dictionary = PALETTES.get(phase, PALETTES.noon)
	return {"sky": palette.haze, "fog": palette.haze, "ambient": palette.fill, "ambient_energy": palette.fill_energy,
		"sun": palette.key, "sun_energy": palette.key_energy, "glow": 0.55}

## Pools, reflections and the skyline haze for `phase`.
func apply_palette(phase: String) -> void:
	var palette: Dictionary = PALETTES.get(phase, PALETTES.noon)
	var haze: Color = palette.haze
	_light_energy = palette.pool_energy
	if _skyline != null:
		_skyline.set_shader_parameter("haze", haze)
	for paving in _pavings:
		paving.set_shader_parameter("reflected_sky", palette.reflected_sky)
	_sync_reflections()
	_sync_pools()

func set_market_open(value: bool) -> void:
	if _operating == value:
		return
	_operating = value
	_sync_reflections()
	_sync_animation()

func set_reduced_motion(value: bool) -> void:
	if _reduced_motion == value:
		return
	_reduced_motion = value
	_sync_reflections()
	_sync_animation()

func _make_paving(stone_atlas: Texture2D, shelter: Rect2, rooftop: bool, tint: Color) -> ShaderMaterial:
	var surface := ShaderMaterial.new()
	surface.shader = WetStreetShader
	surface.set_shader_parameter("has_stone_atlas", stone_atlas != null)
	if stone_atlas != null:
		surface.set_shader_parameter("stone_atlas", stone_atlas)
	surface.set_shader_parameter("rooftop", rooftop)
	surface.set_shader_parameter("stone_tint", tint)
	surface.set_shader_parameter("shelter_rect", Vector4(shelter.position.x, shelter.position.y, shelter.end.x, shelter.end.y))
	for pool in POOLS:
		var position: Vector3 = pool.position
		surface.set_shader_parameter("%s_pool" % pool.id, Vector2(position.x, position.z))
		surface.set_shader_parameter("%s_lantern" % pool.id, pool.color)
	_pavings.append(surface)
	return surface

func _build_skyline(texture: Texture2D) -> void:
	var plane := QuadMesh.new()
	plane.size = Vector2(48.0, 14.6)
	_skyline = ShaderMaterial.new()
	_skyline.shader = SkylineShader
	_skyline.set_shader_parameter("skyline_texture", texture)
	var backdrop := MeshInstance3D.new()
	backdrop.name = "RainyMarketSkyline"
	backdrop.mesh = plane
	backdrop.material_override = _skyline
	# Right behind the northern row of shop fronts, so the painted town climbs the
	# hill from their eaves.
	backdrop.position = Vector3(0.0, 4.68, -16.7)
	backdrop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(backdrop)

func _build_pools() -> void:
	for spec: Dictionary in POOLS:
		var lamp := OmniLight3D.new()
		lamp.position = spec.position
		lamp.light_color = spec.color
		lamp.omni_range = spec.range
		lamp.omni_attenuation = 1.5
		lamp.light_specular = 0.18
		lamp.shadow_enabled = false
		add_child(lamp)
		_pools.append(lamp)

func pool_count() -> int:
	return _pools.size()

func _sync_animation() -> void:
	set_process(_operating and not _reduced_motion and not _pools.is_empty())
	_sync_pools()

func _process(delta: float) -> void:
	_pulse_phase = fposmod(_pulse_phase + delta * 1.35, TAU)
	_until_update -= delta
	if _until_update <= 0.0:
		_until_update = LIGHT_UPDATE_INTERVAL
		_sync_pools()

func _sync_pools() -> void:
	var base := _operating_light()
	for index in _pools.size():
		var pulse := 0.0
		if _operating and not _reduced_motion and index < 2:
			pulse = sin(_pulse_phase + index * 1.2) * 0.035
		_pools[index].light_energy = base + pulse

func _sync_reflections() -> void:
	var energy := _operating_light()
	var moving := _operating and not _reduced_motion
	for paving in _pavings:
		paving.set_shader_parameter("reflection_energy", energy)
		paving.set_shader_parameter("reflections_move", moving)

func _operating_light() -> float:
	return _light_energy if _operating else _light_energy * CLOSED_LIGHT_SCALE
