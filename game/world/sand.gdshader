shader_type spatial;
render_mode cull_back;

// 0 dry .. 1 soaked: set by a passing shower (ART-72).
global uniform float snapland_wetness;

uniform vec4 dry_color : source_color = vec4(0.80, 0.70, 0.51, 1.0);
uniform vec4 wet_color : source_color = vec4(0.55, 0.47, 0.35, 1.0);
uniform vec4 turf_color : source_color = vec4(0.38, 0.51, 0.42, 1.0);
// Signed distance to the island's waterline in metres (positive on land).
uniform sampler2D shore_distance : filter_linear, repeat_disable;
uniform vec2 sdf_origin;
uniform vec2 sdf_inverse_size;
// Grass begins this far inland, except inside a beach (x, z, radius).
uniform float sand_width = 2.6;
uniform vec3 beaches[12];
uniform int beach_count = 0;

// World rects (min x, min z, max x, max z) where a district sinks water or a
// channel below the beach.
uniform vec4 cutouts[8];
uniform int cutout_count = 0;

varying vec3 world_position;

float cell_seed(vec2 cell) {
	return fract(sin(dot(cell, vec2(12.9898, 78.233))) * 43758.5453);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	for (int index = 0; index < cutout_count; index++) {
		vec4 hole = cutouts[index];
		if (world_position.x > hole.x && world_position.z > hole.y && world_position.x < hole.z && world_position.z < hole.w) {
			discard;
		}
	}
	// Grain is snapped to the same world pixel grid as the bay and the lawn.
	vec2 cell = floor(world_position.xz * 6.0);
	vec2 p = cell / 6.0;
	float grain = cell_seed(cell);
	float drift = sin(p.x * 0.9 + sin(p.y * 0.55) * 1.6) * sin(p.y * 1.3 + p.x * 0.21);
	float pebble = step(0.985, cell_seed(floor(world_position.xz * 3.0) + 17.0));
	// Distance inland from the waterline: the rim stays damp and a little darker.
	float inland = texture(shore_distance, (p - sdf_origin) * sdf_inverse_size).r;
	float shore = inland + drift * 0.16;
	float wet = 1.0 - smoothstep(0.55, 1.5, shore);
	float tide_mark = smoothstep(1.45, 1.55, shore) * (1.0 - smoothstep(1.55, 1.8, shore));
	vec3 sand = dry_color.rgb * (0.95 + (grain - 0.5) * 0.07 + drift * 0.035);
	sand = mix(sand, sand * 0.78, pebble);
	sand = mix(sand, wet_color.rgb * (0.97 + (grain - 0.5) * 0.04), wet);
	sand += vec3(0.05, 0.045, 0.03) * tide_mark;
	// Stray turf pixels thin out across the first stride of sand beside the lawn,
	// so the grass edge reads as growing into the beach instead of a cut line.
	float beyond_lawn = sand_width - inland;
	for (int index = 0; index < beach_count; index++) {
		beyond_lawn = max(beyond_lawn, beaches[index].z - distance(p, beaches[index].xy));
	}
	float fringe = 1.0 - smoothstep(-0.35, 0.75, beyond_lawn + drift * 0.2);
	sand = mix(sand, turf_color.rgb * (0.9 + grain * 0.2), step(1.0 - fringe * 0.85, cell_seed(cell + 5.0)));
	ALBEDO = sand * (1.0 - 0.28 * snapland_wetness);
	ROUGHNESS = mix(mix(0.96, 0.6, wet), 0.45, snapland_wetness);
}
