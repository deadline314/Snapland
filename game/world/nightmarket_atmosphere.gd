extends Node3D
## Local lighting and horizon composition for the rainy market.

const SkylineShader = preload("res://game/world/nightmarket_skyline.gdshader")
const PALETTES := {
	"dawn": {
		"haze": Color("#343754"), "fill": Color("#c5ccec"), "key": Color("#ffccaf"),
		"fill_energy": 0.80, "key_energy": 0.44, "pool_energy": 0.78,
	},
	"noon": {
		"haze": Color("#414861"), "fill": Color("#d7e3ff"), "key": Color("#e7edff"),
		"fill_energy": 0.87, "key_energy": 0.59, "pool_energy": 0.62,
	},
	"dusk": {
		"haze": Color("#35304e"), "fill": Color("#c2bde9"), "key": Color("#ffc6a5"),
		"fill_energy": 0.83, "key_energy": 0.38, "pool_energy": 0.93,
	},
	"night": {
		"haze": Color("#252744"), "fill": Color("#afc6fc"), "key": Color("#b2c4ff"),
		"fill_energy": 0.86, "key_energy": 0.34, "pool_energy": 1.02,
	},
}
const POOLS := [
	{"position": Vector3(-7.7, 2.72, 2.8), "color": Color("#ffbd80"), "range": 5.8},
	{"position": Vector3(7.7, 2.72, -0.25), "color": Color("#ff998d"), "range": 5.8},
	{"position": Vector3(0.0, 3.62, -11.7), "color": Color("#ffd3a4"), "range": 5.0},
]
const LIGHT_UPDATE_INTERVAL := 0.14

var _environment: Environment
var _sun: DirectionalLight3D
var _skyline: ShaderMaterial
var _pools: Array[OmniLight3D] = []
var _operating := true
var _reduced_motion := false
var _light_energy := 0.62
var _pulse_phase := 0.0
var _until_update := 0.0

func setup(environment: Environment, sun: DirectionalLight3D, skyline: Texture2D) -> void:
	_environment = environment
	_sun = sun
	if skyline != null:
		_build_skyline(skyline)
	if DisplayServer.get_name() != "headless":
		_build_pools()
	apply_palette("noon")
	_sync_animation()

func apply_palette(phase: String) -> void:
	var palette: Dictionary = PALETTES.get(phase, PALETTES.noon)
	var haze: Color = palette.haze
	_environment.background_color = haze
	_environment.ambient_light_color = palette.fill
	_environment.ambient_light_energy = palette.fill_energy
	_environment.fog_light_color = haze
	_sun.light_color = palette.key
	_sun.light_energy = palette.key_energy
	_light_energy = palette.pool_energy
	if _skyline != null:
		_skyline.set_shader_parameter("haze", haze)
	_sync_pools()

func set_market_open(value: bool) -> void:
	_operating = value
	_sync_animation()

func set_reduced_motion(value: bool) -> void:
	_reduced_motion = value
	_sync_animation()

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
	backdrop.position = Vector3(0.0, 5.4, -15.6)
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
	var base := _light_energy if _operating else _light_energy * 0.24
	for index in _pools.size():
		var pulse := 0.0
		if _operating and not _reduced_motion and index < 2:
			pulse = sin(_pulse_phase + index * 1.2) * 0.035
		_pools[index].light_energy = base + pulse
