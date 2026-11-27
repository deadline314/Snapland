extends RefCounted
## Picture-quality presets.
##
## One row per level decides every optional rendering cost, so the world, the
## ambience layer and the settings screen can never disagree about what a level
## means. "high" is the authored look; lower levels only remove cost.

const DEFAULT_LEVEL := "high"
const LEVELS: Array[String] = ["high", "balanced", "low"]

## ssao / glow: environment passes.
## lamp_shadows / active_lamps: night lamp budget (the world clamps to its limits).
## cloud_shade / air_particles: ambience layers. sun_shadow_size: shadow atlas edge.
## msaa: edge smoothing for world geometry; it never blurs pixel-art textures.
const PROFILES := {
	"high": {"ssao": true, "glow": true, "lamp_shadows": 2, "active_lamps": 8, "cloud_shade": true, "air_particles": true, "sun_shadow_size": 4096, "msaa": Viewport.MSAA_2X},
	"balanced": {"ssao": true, "glow": true, "lamp_shadows": 1, "active_lamps": 8, "cloud_shade": true, "air_particles": true, "sun_shadow_size": 2048, "msaa": Viewport.MSAA_DISABLED},
	"low": {"ssao": false, "glow": false, "lamp_shadows": 0, "active_lamps": 5, "cloud_shade": false, "air_particles": false, "sun_shadow_size": 2048, "msaa": Viewport.MSAA_DISABLED},
}

static var _renderer_level_applied := ""


## Any unknown or malformed value becomes the default level.
static func normalize(level: Variant) -> String:
	return str(level) if typeof(level) == TYPE_STRING and LEVELS.has(level) else DEFAULT_LEVEL


static func profile(level: Variant) -> Dictionary:
	return PROFILES[normalize(level)]


## Renderer-wide switches (shared by every viewport). They reallocate buffers,
## so they run only when the level actually changes and never without a display.
static func apply_renderer(level_profile: Dictionary) -> void:
	var size := int(level_profile.get("sun_shadow_size", 4096))
	var key := str(size)
	if key == _renderer_level_applied or DisplayServer.get_name() == "headless":
		return
	_renderer_level_applied = key
	RenderingServer.directional_shadow_atlas_set_size(size, true)


## Per-viewport switches for the viewport that shows the world.
static func apply_viewport(viewport: Viewport, level_profile: Dictionary) -> void:
	if viewport == null or DisplayServer.get_name() == "headless":
		return
	var msaa := int(level_profile.get("msaa", Viewport.MSAA_DISABLED))
	if viewport.msaa_3d != msaa:
		viewport.msaa_3d = msaa as Viewport.MSAA
