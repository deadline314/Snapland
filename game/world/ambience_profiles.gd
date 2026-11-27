extends RefCounted
## World ambience data. Adding a region, a mote or an animal is an edit to
## these tables; the ambience layer itself has no region-specific code.

const PARTICLE_BUDGET := 200
const PIXELS_PER_METRE := 48.0
const DAY := ["dawn", "noon", "dusk"]
const ALWAYS := ["dawn", "noon", "dusk", "night"]

## Cloud shade depth per phase, multiplied by the region's "clouds" value.
const CLOUD_PHASE_STRENGTH := {"dawn": 0.75, "noon": 1.0, "dusk": 0.65, "night": 0.0}

## Alpha over a mote's life, as (life fraction, alpha) points.
const RAMPS := {
	"fade": [Vector2(0.0, 0.0), Vector2(0.18, 1.0), Vector2(0.75, 1.0), Vector2(1.0, 0.0)],
	"blink": [Vector2(0.0, 0.0), Vector2(0.12, 1.0), Vector2(0.34, 0.12), Vector2(0.55, 1.0), Vector2(0.78, 0.18), Vector2(0.9, 0.8), Vector2(1.0, 0.0)],
	"pop": [Vector2(0.0, 0.0), Vector2(0.3, 1.0), Vector2(1.0, 0.0)],
	"smoke": [Vector2(0.0, 0.0), Vector2(0.15, 1.0), Vector2(1.0, 0.0)],
}
## Size over a mote's life, as (life fraction, scale) points.
const SCALE_CURVES := {
	"grow": [Vector2(0.0, 0.4), Vector2(1.0, 1.0)],
	"pop": [Vector2(0.0, 0.0), Vector2(0.35, 1.0), Vector2(1.0, 0.0)],
}

## glyph: bitmap in AmbienceSprites.MOTES. energy above 1 lets additive motes
## pass the bloom threshold. box/lift: emission volume around its anchor.
const PARTICLE_KINDS := {
	"pollen": {
		"glyph": "dot", "color": Color(1.0, 0.97, 0.74, 0.95), "scale": 1.6, "life": 9.0, "speed": Vector2(0.08, 0.26),
		"direction": Vector3(1.0, 0.1, 0.3), "spread": 60.0, "force": Vector3(0.03, 0.012, 0.0),
		"box": Vector3(16.0, 1.5, 11.0), "lift": 1.8, "ramp": "fade",
	},
	"petal": {
		"glyph": "petal", "color": Color(1.0, 0.80, 0.82, 1.0), "scale": 1.3, "life": 8.0, "speed": Vector2(0.4, 0.8),
		"direction": Vector3(1.0, -0.28, 0.35), "spread": 24.0, "force": Vector3(0.05, -0.04, 0.0), "spin": 150.0,
		"box": Vector3(16.0, 1.2, 11.0), "lift": 3.0, "ramp": "fade",
	},
	"leaf": {
		"glyph": "leaf", "color": Color(0.74, 0.80, 0.42, 0.95), "life": 8.0, "speed": Vector2(0.45, 0.9),
		"direction": Vector3(1.0, -0.3, 0.3), "spread": 22.0, "force": Vector3(0.06, -0.05, 0.0), "spin": 110.0,
		"box": Vector3(16.0, 1.2, 11.0), "lift": 3.0, "ramp": "fade",
	},
	"dust": {
		"glyph": "dot", "color": Color(1.0, 0.80, 0.52, 0.9), "additive": true, "scale": 1.6, "life": 10.0, "speed": Vector2(0.03, 0.15),
		"direction": Vector3.UP, "spread": 180.0, "force": Vector3(0.02, 0.004, 0.0),
		"box": Vector3(16.0, 1.6, 11.0), "lift": 1.9, "ramp": "fade",
	},
	"firefly": {
		"glyph": "glow", "color": Color(0.80, 1.0, 0.42), "additive": true, "energy": 2.6, "life": 7.0, "speed": Vector2(0.12, 0.38),
		"direction": Vector3.UP, "spread": 180.0, "force": Vector3(0.0, 0.015, 0.0),
		"box": Vector3(15.0, 0.9, 10.0), "lift": 1.1, "ramp": "blink",
	},
	"steam": {
		"glyph": "puff", "color": Color(0.93, 0.95, 1.0, 0.32), "life": 3.2, "speed": Vector2(0.35, 0.6), "scale": 2.4,
		"direction": Vector3.UP, "spread": 12.0, "force": Vector3(0.07, 0.05, 0.0),
		"box": Vector3(0.5, 0.05, 0.5), "lift": 0.0, "ramp": "smoke", "scale_curve": "grow",
	},
	"smoke": {
		"glyph": "puff", "color": Color(1.0, 0.90, 0.94, 0.5), "life": 5.0, "speed": Vector2(0.5, 0.8), "scale": 5.5,
		"direction": Vector3.UP, "spread": 10.0, "force": Vector3(0.12, 0.03, 0.0),
		"box": Vector3(0.3, 0.05, 0.3), "lift": 0.0, "ramp": "smoke", "scale_curve": "grow",
	},
	"ember": {
		"glyph": "dot", "color": Color(1.0, 0.55, 0.22), "additive": true, "energy": 2.2, "scale": 1.4, "life": 3.6, "speed": Vector2(0.35, 0.85),
		"direction": Vector3.UP, "spread": 24.0, "force": Vector3(0.08, 0.1, 0.0),
		"box": Vector3(9.0, 0.3, 6.0), "lift": 1.2, "ramp": "fade",
	},
	"sparkle": {
		"glyph": "spark", "color": Color(1.0, 0.86, 0.95), "additive": true, "energy": 1.5, "life": 1.7, "speed": Vector2(0.0, 0.04),
		"direction": Vector3.UP, "spread": 180.0, "force": Vector3.ZERO,
		"box": Vector3(13.0, 1.4, 11.0), "lift": 1.4, "ramp": "pop", "scale_curve": "pop",
	},
	"spray": {
		"glyph": "dot", "color": Color(0.90, 0.97, 1.0, 0.7), "scale": 1.3, "life": 2.2, "speed": Vector2(0.5, 1.1),
		"direction": Vector3(0.5, 1.0, 0.1), "spread": 35.0, "force": Vector3(0.1, -1.3, 0.0),
		"box": Vector3(16.0, 0.05, 11.0), "lift": 0.0, "ramp": "fade",
	},
}

## sprite: row in AmbienceSprites (defaults to the kind name), so a recoloured
## variant is one more entry here. shadow: ground blob width in metres.
const CRITTER_KINDS := {
	"pigeon": {
		"behavior": "ground_bird", "phases": DAY, "flee_radius": 2.7, "return_radius": 5.5, "fly_speed": 6.5, "shadow": 0.30,
		"tints": [Color(1, 1, 1), Color(0.93, 0.90, 0.88), Color(0.86, 0.88, 0.95), Color(1.0, 0.96, 0.90)],
	},
	"dove": {
		"sprite": "pigeon", "behavior": "ground_bird", "phases": ALWAYS, "flee_radius": 2.5, "return_radius": 5.0, "fly_speed": 6.0, "shadow": 0.30,
		"tints": [Color(1.32, 1.24, 1.14), Color(1.24, 1.20, 1.16)],
	},
	"sparrow": {
		"behavior": "ground_bird", "phases": DAY, "flee_radius": 3.0, "return_radius": 5.5, "fly_speed": 7.5, "shadow": 0.22,
		"tints": [Color(1, 1, 1), Color(0.92, 0.88, 0.84), Color(1.0, 0.95, 0.88)],
	},
	"gull": {
		"behavior": "glider", "pixels_per_metre": 40.0, "phases": DAY, "fly_speed": 3.0, "shadow": 1.25,
		# Brighter than 1 so the white plumage survives the camera-facing shading.
		"tints": [Color(1.5, 1.5, 1.46), Color(1.42, 1.45, 1.5)],
	},
	"butterfly": {
		"behavior": "flutter", "phases": ["dawn", "noon"], "shadow": 0.16,
		"tints": [Color("#fff6e8"), Color("#7fc4f2"), Color("#ff9a5c"), Color("#ff8fb0")],
	},
	"moth": {
		"sprite": "butterfly", "behavior": "flutter", "phases": ["dusk", "night"], "shadow": 0.16,
		"tints": [Color(1.5, 1.44, 1.26), Color(1.34, 1.38, 1.5)],
	},
}

## clouds: 0 hides cloud shade (indoors, overcast). particles: follow the
## player unless "at" pins them. critters: a flock, loop or flowerbed each.
## reserved_particles: emitters the region already owns outside this layer.
const DEFAULT := {
	"clouds": 0.8,
	"particles": [
		{"kind": "pollen", "phases": ["dawn", "noon"], "amount": 40},
		{"kind": "dust", "phases": ["dusk"], "amount": 44},
		{"kind": "firefly", "phases": ["night"], "amount": 30},
	],
	"critters": [],
}

const REGIONS := {
	"welcome": {
		"clouds": 1.0,
		"particles": [
			{"kind": "pollen", "phases": ["dawn", "noon"], "amount": 60},
			{"kind": "petal", "phases": ["noon"], "amount": 20},
			{"kind": "dust", "phases": ["dusk"], "amount": 70},
			{"kind": "firefly", "phases": ["night"], "amount": 44},
		],
		"critters": [
			{"kind": "pigeon", "count": 6, "at": Vector3(4.1, 0, 5.4), "spread": 1.25},
			{"kind": "sparrow", "count": 4, "at": Vector3(-3.0, 0, -5.6), "spread": 1.0},
			{"kind": "sparrow", "count": 3, "at": Vector3(2.4, 0, -21.0), "spread": 1.0},
			{"kind": "gull", "count": 3, "at": Vector3(-5.0, 0, 27.0), "spread": 8.0, "height": 4.0},
			# Beside each planter, over open paving where the wings read clearly.
			{"kind": "butterfly", "count": 2, "at": Vector3(5.2, 0, -5.3), "spread": 0.5, "height": 1.1},
			{"kind": "butterfly", "count": 2, "at": Vector3(-5.2, 0, -5.3), "spread": 0.5, "height": 1.1},
			{"kind": "butterfly", "count": 1, "at": Vector3(10.6, 0, -2.4), "spread": 0.4, "height": 1.1},
			{"kind": "butterfly", "count": 1, "at": Vector3(-10.6, 0, -2.4), "spread": 0.4, "height": 1.1},
		],
	},
	"harbor": {
		# water_y sits just above high water so gull shadows stay on the sea at any tide.
		"clouds": 1.0, "water_y": -0.03,
		"particles": [
			{"kind": "spray", "phases": DAY, "amount": 36},
			{"kind": "pollen", "phases": ["dawn", "noon"], "amount": 20},
			{"kind": "dust", "phases": ["dusk"], "amount": 36},
			{"kind": "firefly", "phases": ["night"], "amount": 22},
		],
		"critters": [
			{"kind": "gull", "count": 4, "at": Vector3(0, 0, 1.5), "spread": 9.5, "height": 4.4},
			{"kind": "sparrow", "count": 4, "at": Vector3(-11.4, 0, 4.6), "spread": 1.0},
		],
	},
	"candy": {
		"clouds": 0.55,
		"particles": [
			{"kind": "sparkle", "phases": ALWAYS, "amount": 34},
			# Kettles along the hall wall, the two hall chimneys and the cooling tower.
			{"kind": "steam", "phases": ALWAYS, "amount": 8, "at": Vector3(5.9, 2.4, -10.9)},
			{"kind": "steam", "phases": ALWAYS, "amount": 8, "at": Vector3(8.5, 2.4, -10.9)},
			{"kind": "steam", "phases": ALWAYS, "amount": 8, "at": Vector3(11.1, 2.4, -10.9)},
			{"kind": "smoke", "phases": ALWAYS, "amount": 10, "at": Vector3(-9.0, 12.7, -18.5)},
			{"kind": "smoke", "phases": ALWAYS, "amount": 10, "at": Vector3(5.5, 11.9, -20.5)},
			{"kind": "smoke", "phases": ALWAYS, "amount": 12, "at": Vector3(23.5, 6.7, -8.5), "box": Vector3(1.0, 0.05, 1.0)},
			{"kind": "firefly", "phases": ["night"], "amount": 20},
		],
		"critters": [
			{"kind": "sparrow", "count": 4, "at": Vector3(-7.0, 0, 2.4), "spread": 1.1},
		],
	},
	"nightmarket": {
		"clouds": 0.0, "reserved_particles": 90,
		"particles": [
			{"kind": "steam", "phases": ALWAYS, "amount": 14, "at": Vector3(-7.33, 1.36, 5.5), "box": Vector3(0.6, 0.04, 0.12)},
			{"kind": "steam", "phases": ALWAYS, "amount": 16, "at": Vector3(-6.1, 1.5, 0.0), "box": Vector3(0.4, 0.04, 3.2)},
			{"kind": "ember", "phases": ["dusk", "night"], "amount": 18, "at": Vector3(6.1, 1.3, 0.0), "box": Vector3(0.4, 0.05, 3.2)},
		],
		"critters": [
			{"kind": "pigeon", "count": 4, "at": Vector3(0.0, 0, 1.2), "spread": 1.1, "phases": ALWAYS},
			{"kind": "moth", "count": 3, "at": Vector3(-7.4, 0, 2.6), "spread": 1.2, "height": 1.7, "phases": ALWAYS},
		],
	},
	"circus": {
		"clouds": 0.0,
		"particles": [
			{"kind": "dust", "phases": ALWAYS, "amount": 46, "box": Vector3(11.0, 1.8, 9.0)},
			{"kind": "sparkle", "phases": ALWAYS, "amount": 14, "box": Vector3(10.0, 1.2, 8.0)},
		],
		"critters": [
			{"kind": "dove", "count": 3, "at": Vector3(3.0, 0, 6.4), "spread": 0.8},
			{"kind": "moth", "count": 3, "at": Vector3(7.1, 0, -0.5), "spread": 1.2, "height": 1.7, "phases": ALWAYS},
		],
	},
	"toy": {
		"clouds": 0.6,
		"particles": [
			{"kind": "dust", "phases": DAY, "amount": 40, "box": Vector3(11.0, 1.6, 9.0)},
			{"kind": "sparkle", "phases": ["dusk", "night"], "amount": 18, "box": Vector3(10.0, 1.2, 8.0)},
			{"kind": "firefly", "phases": ["night"], "amount": 18},
		],
		"critters": [
			{"kind": "sparrow", "count": 4, "at": Vector3(-1.6, 0, 1.2), "spread": 1.3},
		],
	},
	"garden": {
		"clouds": 0.55,
		"particles": [
			{"kind": "pollen", "phases": ["dawn", "noon"], "amount": 44, "box": Vector3(11.0, 1.4, 9.5)},
			{"kind": "dust", "phases": ["dusk"], "amount": 36, "box": Vector3(11.0, 1.4, 9.5)},
			{"kind": "firefly", "phases": ["night"], "amount": 40, "box": Vector3(11.0, 0.9, 9.5)},
		],
		"critters": [
			{"kind": "butterfly", "count": 4, "at": Vector3(0.0, 0, 1.4), "spread": 2.0},
			{"kind": "butterfly", "count": 2, "at": Vector3(0.0, 0, -9.4), "spread": 2.4},
			{"kind": "sparrow", "count": 3, "at": Vector3(-3.0, 0, 5.6), "spread": 0.8},
		],
	},
}

## Region scripts are named "<region>_world.gd"; the shared base is the Welcome island.
const SCRIPT_REGIONS := {"park": "welcome"}


static func region_for(world: Object) -> String:
	var script := world.get_script() as Script
	while script != null:
		var key := script.resource_path.get_file().trim_suffix("_world.gd")
		key = String(SCRIPT_REGIONS.get(key, key))
		if REGIONS.has(key):
			return key
		script = script.get_base_script()
	return ""


static func profile(region: String) -> Dictionary:
	return REGIONS.get(region, DEFAULT)


static func particle_total(region_profile: Dictionary) -> int:
	var total := int(region_profile.get("reserved_particles", 0))
	for spec: Dictionary in region_profile.get("particles", []):
		total += int(spec.get("amount", 0))
	return total


static func critter_total(region_profile: Dictionary) -> int:
	var total := 0
	for group: Dictionary in region_profile.get("critters", []):
		total += int(group.get("count", 0))
	return total
