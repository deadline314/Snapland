shader_type spatial;
render_mode cull_disabled;

uniform vec4 deep_color : source_color = vec4(0.067, 0.29, 0.37, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.24, 0.62, 0.58, 1.0);
uniform vec4 foam_color : source_color = vec4(0.68, 0.82, 0.72, 1.0);
uniform vec2 land_center;
uniform vec2 land_half_size;
uniform vec2 dock_center;
uniform vec2 dock_half_size;
uniform float dock_glow = 0.0;
uniform float motion = 1.0;

varying vec2 world_position;

float cell_seed(vec2 cell) {
	vec3 seed = fract(vec3(cell.xyx) * vec3(0.1031, 0.11369, 0.13787));
	seed += dot(seed, seed.yxz + 19.19);
	return fract((seed.x + seed.y) * seed.z);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	// Snap detail to the same world pixel scale as the original sea. Measure
	// depth from the continuous land and dock edges so the band cannot crawl.
	vec2 p = floor(world_position * 5.0) * 0.2;
	vec2 land_delta = max(abs(world_position - land_center) - land_half_size, vec2(0.0));
	vec2 dock_delta = max(abs(world_position - dock_center) - dock_half_size, vec2(0.0));
	float shore = length(land_delta);
	float dock = length(dock_delta);
	float shelf = 1.0 - smoothstep(0.28, 4.15, shore);
	float dock_shelf = 1.0 - smoothstep(0.18, 1.42, dock);
	float shallow = max(shelf, dock_shelf * 0.62);

	float t = TIME * motion;
	float swell = sin(p.x * 0.37 + p.y * 0.22 - t * 0.48) * cos(p.y * 0.31 - p.x * 0.08 + t * 0.36);
	// Short asymmetric fragments provide scale in deep water without drawing
	// an uninterrupted line through neighboring cells.
	vec2 fleck = vec2(p.x * 0.73 + p.y * 0.28, p.y * 1.17 - p.x * 0.19);
	vec2 fleck_local = fract(fleck);
	float fleck_seed = cell_seed(floor(fleck));
	float fleck_body = 1.0 - smoothstep(0.17, 0.43, abs(fleck_local.x - 0.48));
	float fleck_crest = 1.0 - smoothstep(0.04, 0.15, abs(fleck_local.y - (0.19 + fleck_seed * 0.64 + swell * 0.075)));
	float flecks = fleck_body * fleck_crest * smoothstep(0.34, 0.84, fleck_seed);

	bool dock_edge = dock + 0.24 < shore;
	float distance_to_edge = dock_edge ? dock : shore;
	float foam = 0.0;
	if (distance_to_edge > 0.025 && distance_to_edge < 1.55) {
		// Offshore pixels skip the contact-wave work entirely.
		vec2 edge_delta = dock_edge ? dock_delta : land_delta;
		bool side_edge = edge_delta.x > edge_delta.y;
		float tangent = side_edge ? p.y : p.x;
		float segment = tangent * 0.64 + 0.19 * distance_to_edge;
		float section = fract(segment);
		float seed = cell_seed(vec2(floor(segment), side_edge ? 31.0 : 47.0));
		float breaks = smoothstep(0.09, 0.35, section) * (1.0 - smoothstep(0.62, 0.91, section));
		breaks *= mix(0.18, 1.0, smoothstep(0.22, 0.78, seed));
		float contact = smoothstep(0.025, 0.22, distance_to_edge) * (1.0 - smoothstep(0.67, 1.55, distance_to_edge));
		float wave = smoothstep(0.59, 0.97, sin(distance_to_edge * 6.6 + seed * 1.8 + t * 1.24));
		foam = contact * wave * breaks;
	}
	float lantern = dock_glow * dock_shelf * smoothstep(0.09, 0.36, dock) * flecks;

	vec3 water = mix(deep_color.rgb, shallow_color.rgb, shallow);
	ALBEDO = water * (0.93 + swell * 0.15)
		+ foam_color.rgb * (flecks * mix(0.055, 0.018, shallow) + foam * 0.23);
	EMISSION = vec3(0.095, 0.046, 0.014) * lantern;
	ROUGHNESS = mix(0.68, 0.49, shallow);
	METALLIC = 0.02;
}
