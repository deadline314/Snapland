shader_type spatial;
// Sand banks and shore rocks that meet the sea. The surface reads its own height
// above the water level, so the wet band and the lapping foam line follow the real
// mesh on every side and move with the tide.

uniform vec4 dry_color : source_color = vec4(0.93, 0.82, 0.60, 1.0);
uniform vec4 wet_color : source_color = vec4(0.62, 0.52, 0.38, 1.0);
uniform vec4 foam_color : source_color = vec4(0.90, 0.96, 0.92, 1.0);
uniform float water_level = -0.3;
uniform float speckle = 1.0;
uniform float motion = 1.0;

varying vec3 world_position;
varying vec3 tint;

float cell_seed(vec2 cell) {
	vec3 seed = fract(vec3(cell.xyx) * vec3(0.1031, 0.11369, 0.13787));
	seed += dot(seed, seed.yxz + 19.19);
	return fract((seed.x + seed.y) * seed.z);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	tint = COLOR.rgb;
}

void fragment() {
	vec2 cell = floor(world_position.xz * 10.0);
	float grain = cell_seed(cell);
	float lap = 0.022 * sin(TIME * motion * 1.1 + cell.x * 0.07 + cell.y * 0.05);
	float height = world_position.y - water_level - lap;
	// Three flat tones read as pixel art instead of a soft gradient.
	float wet = floor((1.0 - smoothstep(0.03, 0.2, height)) * 3.0 + 0.5) / 3.0;
	vec3 ground = mix(dry_color.rgb, wet_color.rgb, wet) * tint;
	ground *= 0.95 + grain * 0.1;
	float ripple = sin(world_position.z * 5.5 + sin(world_position.x * 1.1) * 1.4);
	ground *= 1.0 - step(0.9, ripple) * 0.045 * speckle * (1.0 - wet);
	float shell = step(0.988, cell_seed(cell + 17.0)) * speckle;
	ground = mix(ground, vec3(0.97, 0.93, 0.86), shell * (1.0 - wet) * 0.7);
	float pebble = step(0.986, cell_seed(cell * 0.5 + 91.0)) * speckle;
	ground *= 1.0 - pebble * 0.22;
	float swash = smoothstep(-0.006, 0.004, height) * (1.0 - smoothstep(0.022, 0.05, height));
	swash *= step(0.3, cell_seed(vec2(floor(cell.x * 0.34) + floor(cell.y * 0.34), 3.0)));
	ALBEDO = mix(ground, foam_color.rgb, swash * 0.85);
	ROUGHNESS = mix(0.96, 0.55, wet);
}
