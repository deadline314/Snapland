shader_type spatial;
render_mode cull_disabled;

#include "res://game/world/sea_motion.gdshaderinc"

uniform vec4 deep_color : source_color = vec4(0.067, 0.29, 0.37, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.24, 0.62, 0.58, 1.0);
uniform vec4 foam_color : source_color = vec4(0.68, 0.82, 0.72, 1.0);
// Signed distance to the island's waterline in metres (positive on land).
uniform sampler2D shore_distance : filter_linear, repeat_disable;
uniform vec2 sdf_origin;
uniform vec2 sdf_inverse_size;
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

float inland(vec2 at) {
	return texture(shore_distance, (at - sdf_origin) * sdf_inverse_size).r;
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	// Snap detail to the same world pixel scale as the original sea. Depth is
	// measured from the real coastline and the dock, so the band cannot crawl
	// and the surf follows every cape and bay.
	vec2 p = floor(world_position * 5.0) * 0.2;
	float shore = max(-inland(p), 0.0);
	vec2 dock_delta = max(abs(world_position - dock_center) - dock_half_size, vec2(0.0));
	float dock = length(dock_delta);
	float shelf = 1.0 - smoothstep(0.28, 4.15, shore);
	float dock_shelf = 1.0 - smoothstep(0.18, 1.42, dock);
	float shallow = max(shelf, dock_shelf * 0.62);

	float t = TIME * motion;
	float ruffle = wind_gust(p);
	float swell = sea_swell(p, t);
	float flecks = sea_crests(p, t, ruffle);

	bool dock_edge = dock + 0.24 < shore;
	float distance_to_edge = dock_edge ? dock : shore;
	float foam = 0.0;
	if (distance_to_edge > 0.025 && distance_to_edge < 1.55) {
		// Offshore pixels skip the contact-wave work entirely. Metres along the
		// waterline are counted on whichever axis this stretch of shore runs along.
		bool side_edge = dock_delta.x > dock_delta.y;
		if (!dock_edge) {
			vec2 slope = vec2(inland(p + vec2(0.6, 0.0)) - inland(p - vec2(0.6, 0.0)), inland(p + vec2(0.0, 0.6)) - inland(p - vec2(0.0, 0.6)));
			side_edge = abs(slope.x) > abs(slope.y);
		}
		float tangent = side_edge ? p.y : p.x;
		foam = sea_surf(distance_to_edge - 0.025, tangent, t, 1.5);
		// A thin lapping line keeps the land and the dock seated in the water.
		float lap = 0.14 + 0.05 * sin(t * 1.1 + tangent * 0.9);
		foam = max(foam, (1.0 - smoothstep(lap * 0.6, lap, distance_to_edge)) * step(0.3, cell_seed(vec2(floor(tangent * 1.7), side_edge ? 5.0 : 9.0))) * 0.7);
	}
	float calm = 1.0 - ruffle;
	float ripples = sea_ripples(p, t) * calm * (1.0 - smoothstep(0.0, 1.0, foam));
	float glints = sea_glints(p, t) * (1.0 - shallow * 0.4);
	float lantern = dock_glow * dock_shelf * smoothstep(0.09, 0.36, dock) * flecks;

	vec3 water = mix(deep_color.rgb, shallow_color.rgb, shallow);
	ALBEDO = water * (0.93 + swell * 0.15 - ruffle * 0.07)
		+ foam_color.rgb * (flecks * mix(0.11, 0.045, shallow) + foam * 0.42 + ripples * 0.1 + glints * 0.3);
	EMISSION = vec3(0.095, 0.046, 0.014) * lantern;
	ROUGHNESS = mix(0.68, 0.49, shallow);
	METALLIC = 0.02;
}
