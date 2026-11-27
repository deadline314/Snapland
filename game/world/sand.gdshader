shader_type spatial;
render_mode cull_back;

uniform vec4 dry_color : source_color = vec4(0.80, 0.70, 0.51, 1.0);
uniform vec4 wet_color : source_color = vec4(0.55, 0.47, 0.35, 1.0);
uniform vec2 land_center;
uniform vec2 land_half_size;
uniform vec4 turf_color : source_color = vec4(0.38, 0.51, 0.42, 1.0);
uniform vec2 lawn_center;
uniform vec2 lawn_half_size;
uniform float lawn_corner_radius = 5.0;

varying vec3 world_position;

float cell_seed(vec2 cell) {
	return fract(sin(dot(cell, vec2(12.9898, 78.233))) * 43758.5453);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Grain is snapped to the same world pixel grid as the bay and the lawn.
	vec2 cell = floor(world_position.xz * 6.0);
	vec2 p = cell / 6.0;
	float grain = cell_seed(cell);
	float drift = sin(p.x * 0.9 + sin(p.y * 0.55) * 1.6) * sin(p.y * 1.3 + p.x * 0.21);
	float pebble = step(0.985, cell_seed(floor(world_position.xz * 3.0) + 17.0));
	// Distance inland from the waterline: the rim stays damp and a little darker.
	vec2 inland = land_half_size - abs(p - land_center);
	float shore = min(inland.x, inland.y) + drift * 0.16;
	float wet = 1.0 - smoothstep(0.45, 1.25, shore);
	float tide_mark = smoothstep(1.2, 1.3, shore) * (1.0 - smoothstep(1.3, 1.5, shore));
	vec3 sand = dry_color.rgb * (0.95 + (grain - 0.5) * 0.07 + drift * 0.035);
	sand = mix(sand, sand * 0.78, pebble);
	sand = mix(sand, wet_color.rgb * (0.97 + (grain - 0.5) * 0.04), wet);
	sand += vec3(0.05, 0.045, 0.03) * tide_mark;
	// Stray turf pixels thin out across the first stride of sand beside the lawn,
	// so the grass edge reads as growing into the beach instead of a cut line.
	vec2 q = abs(p - lawn_center) - (lawn_half_size - vec2(lawn_corner_radius));
	float beyond_lawn = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - lawn_corner_radius;
	float fringe = 1.0 - smoothstep(-0.35, 0.75, beyond_lawn + drift * 0.2);
	sand = mix(sand, turf_color.rgb * (0.9 + grain * 0.2), step(1.0 - fringe * 0.85, cell_seed(cell + 5.0)));
	ALBEDO = sand;
	ROUGHNESS = mix(0.96, 0.6, wet);
}
