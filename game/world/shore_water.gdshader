shader_type spatial;

#include "res://game/world/sea_motion.gdshaderinc"
// Sea for a region whose shore is a set of axis-aligned land rectangles.
// One analytic shore distance drives the shelf colour and the contact foam, so
// foam hugs every side of every quay regardless of the camera angle. Shoals are
// sand banks the tide covers; rings are hulls sitting in the water.

uniform vec4 deep_color : source_color = vec4(0.067, 0.29, 0.37, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.24, 0.62, 0.58, 1.0);
uniform vec4 foam_color : source_color = vec4(0.86, 0.94, 0.88, 1.0);
uniform vec4 far_color : source_color = vec4(0.05, 0.21, 0.31, 1.0);
// Rectangles are packed as centre x, centre z, half x, half z.
uniform float land_rects[32];
uniform int land_count = 0;
uniform float shoal_rects[32];
uniform int shoal_count = 0;
// Rings are packed as x, z, radius.
uniform float foam_rings[72];
uniform int ring_count = 0;
uniform vec2 quiet_center = vec2(0.0);
uniform float quiet_radius = 24.0;
uniform vec4 sky_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float tide = 0.0;
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
	// Detail snaps to a world pixel grid; distances stay continuous so bands cannot crawl.
	vec2 p = floor(world_position * 6.0) / 6.0;
	float t = TIME * motion;

	float shore = 1000.0;
	vec2 edge = vec2(0.0);
	for (int i = 0; i < land_count; i++) {
		vec2 center = vec2(land_rects[i * 4], land_rects[i * 4 + 1]);
		vec2 half_size = vec2(land_rects[i * 4 + 2], land_rects[i * 4 + 3]);
		vec2 delta = max(abs(world_position - center) - half_size, vec2(0.0));
		float distance_to_land = length(delta);
		if (distance_to_land < shore) {
			shore = distance_to_land;
			edge = delta;
		}
	}
	float shoal = 0.0;
	float shoal_core = 0.0;
	for (int i = 0; i < shoal_count; i++) {
		vec2 center = vec2(shoal_rects[i * 4], shoal_rects[i * 4 + 1]);
		vec2 half_size = vec2(shoal_rects[i * 4 + 2], shoal_rects[i * 4 + 3]);
		float corner = min(half_size.x, half_size.y) * 0.6;
		float signed_distance = length(max(abs(world_position - center) - half_size + corner, vec2(0.0))) - corner;
		shoal = max(shoal, 1.0 - smoothstep(-0.4, 2.2, signed_distance));
		shoal_core = max(shoal_core, 1.0 - smoothstep(-0.9, 0.5, signed_distance));
	}
	float ring = 1000.0;
	for (int i = 0; i < ring_count; i++) {
		ring = min(ring, distance(world_position, vec2(foam_rings[i * 3], foam_rings[i * 3 + 1])) - foam_rings[i * 3 + 2]);
	}

	// The shelf edge wanders and steps down in bands like a painted depth chart.
	float wander = sin(p.x * 0.55 + p.y * 0.21) * 0.5 + sin(p.y * 0.83 - p.x * 0.17) * 0.4;
	float shelf = 1.0 - smoothstep(0.25, mix(3.8, 2.7, tide), shore + wander * smoothstep(0.3, 1.6, shore));
	float shallow = max(shelf * mix(1.0, 0.82, tide), shoal * mix(0.95, 0.8, tide));
	shallow = mix(shallow, floor(shallow * 4.0 + 0.5) / 4.0, 0.7);

	float ruffle = wind_gust(p);
	float swell = sea_swell(p, t);
	float flecks = sea_crests(p, t, ruffle);

	float foam = 0.0;
	if (shore > 0.01 && shore < 1.6) {
		bool side_edge = edge.x > edge.y;
		float tangent = side_edge ? p.y : p.x;
		float seed = cell_seed(vec2(floor(tangent * 0.64), side_edge ? 31.0 : 47.0));
		foam = sea_surf(shore - 0.03, tangent, t, mix(1.2, 1.55, tide)) * 0.8;
		// A broken bright line at the wall keeps the quay seated in the water.
		float lap = 0.17 + 0.06 * sin(t * 0.9 + tangent * 0.8 + seed * 4.0);
		float wall_seed = cell_seed(vec2(floor(tangent * 1.7), side_edge ? 5.0 : 9.0));
		foam = max(foam, (1.0 - smoothstep(lap * 0.6, lap, shore)) * step(0.25, wall_seed));
	}
	if (ring < 0.5) {
		float lap = 0.2 + 0.07 * sin(t * 1.1 + p.x * 1.3 + p.y * 0.9);
		float ring_seed = cell_seed(floor(p * 2.5));
		foam = max(foam, (1.0 - smoothstep(lap * 0.5, lap, ring)) * step(0.35, ring_seed) * 0.8);
	}

	float ripples = sea_ripples(p, t) * (1.0 - ruffle) * (1.0 - clamp(foam, 0.0, 1.0));
	float glints = sea_glints(p, t) * (1.0 - shallow * 0.4);
	float distant = smoothstep(quiet_radius, quiet_radius + 34.0, distance(world_position, quiet_center));
	vec3 water = mix(deep_color.rgb, shallow_color.rgb, shallow);
	// Submerged sand shows through as a paler patch once the tide covers it.
	water = mix(water, shallow_color.rgb * 1.16 + vec3(0.05, 0.045, 0.01), shoal_core * 0.45);
	water = mix(water, far_color.rgb, distant * 0.75);
	flecks *= 1.0 - distant * 0.6;
	ALBEDO = mix(water * (0.93 + swell * 0.13 - ruffle * 0.06) + foam_color.rgb * (flecks * mix(0.12, 0.05, shallow) + ripples * 0.1 + glints * 0.28), foam_color.rgb, clamp(foam, 0.0, 1.0) * 0.82);
	// A little of the sky colour keeps dusk and night water from turning to mud.
	EMISSION = mix(sky_color.rgb, deep_color.rgb, 0.45) * mix(0.085, 0.035, shallow);
	ROUGHNESS = mix(0.68, 0.49, shallow);
	METALLIC = 0.02;
}
