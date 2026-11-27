// Shared water motion for every sea, lagoon and pool.
//
// All functions take `p`, a world position already snapped to the water's
// pixel grid, and `t`, seconds of water time (the caller passes 0 when motion
// is reduced, which freezes the whole surface). Wind comes from the island's
// shared gust field, so water ruffles when the same gust sweeps the lawn.

#include "res://game/world/wind.gdshaderinc"

const vec2 SEA_ACROSS_WIND = vec2(-0.51, 0.86);

// Slow rolling light and dark across open water (-1..1).
float sea_swell(vec2 p, float t) {
	return sin(p.x * 0.37 + p.y * 0.22 - t * 0.62) * cos(p.y * 0.31 - p.x * 0.08 + t * 0.47);
}

// Whitecaps: short crests that drift downwind and each live for a few seconds.
// `ruffle` (0..1) is the local gust strength; windy water carries more of them.
float sea_crests(vec2 p, float t, float ruffle) {
	vec2 drifting = vec2((dot(p, WIND_DIRECTION) - t * 0.6) * 0.62, dot(p, SEA_ACROSS_WIND) * 1.05);
	vec2 cell = floor(drifting);
	vec2 local = fract(drifting);
	float seed = wind_hash(cell);
	float life = sin(t * (0.55 + seed * 0.6) + seed * 40.0) * 0.5 + 0.5;
	float body = 1.0 - smoothstep(0.12, 0.42, abs(local.x - 0.5));
	float crest = 1.0 - smoothstep(0.04, 0.14, abs(local.y - (0.25 + seed * 0.5)));
	float present = smoothstep(0.6 - ruffle * 0.32, 0.9, seed);
	return body * crest * present * smoothstep(0.2, 0.7, life);
}

// Glints: texels that each flash for a moment. They gather on the lit face of
// the swell, so the sparkle travels across the water in patches.
float sea_glints(vec2 p, float t) {
	vec2 cell = floor(p * 2.5);
	float seed = wind_hash(cell + vec2(7.0, 3.0));
	float clock = fract(t * (0.22 + seed * 0.3) + seed * 13.0);
	float lit_face = smoothstep(0.05, 0.7, sea_swell(p, t));
	return step(0.88, seed) * (1.0 - smoothstep(0.0, 0.1, abs(clock - 0.5))) * lit_face;
}

// Surf: a front rolls in from `reach` metres out, brightens as it nears the
// waterline, breaks, and leaves a wash that thins as it runs back. `shore` is
// metres from the waterline and `tangent` metres along it; neighbouring
// stretches arrive at different moments so the line bends like a real wave.
float sea_surf(float shore, float tangent, float t, float reach) {
	if (shore > reach || shore < 0.0) {
		return 0.0;
	}
	float stagger = wind_noise(vec2(tangent * 0.2, 3.0)) * 1.7;
	float cycle = fract(t * 0.21 + stagger);
	float arrive = clamp(cycle / 0.68, 0.0, 1.0);
	float front = reach * (1.0 - arrive) * (1.0 - arrive * 0.35);
	float line = 1.0 - smoothstep(0.0, mix(0.1, 0.24, arrive), abs(shore - front));
	// Gaps along the front change with each wave.
	float gap_seed = wind_hash(vec2(floor(tangent * 2.3), floor(t * 0.21 + stagger)));
	line *= smoothstep(0.0, 0.3, arrive) * mix(0.45, 1.0, smoothstep(0.2, 0.6, gap_seed));
	float ebb = clamp((cycle - 0.68) / 0.32, 0.0, 1.0);
	float wash = (1.0 - smoothstep(0.0, 0.42 * (1.0 - ebb) + 0.03, shore)) * (1.0 - ebb) * step(0.68, cycle);
	return max(line, wash * 0.9);
}

// Ripple rings that rise now and then on calm water and spread out.
float sea_ripples(vec2 p, float t) {
	const float SPACING = 5.5;
	const float LIFE = 2.8;
	vec2 cell = floor(p / SPACING);
	float seed = wind_hash(cell + vec2(11.0, 29.0));
	float period = 5.0 + seed * 6.0;
	float turns = t / period + seed * 9.0;
	float age = fract(turns) * period;
	if (age > LIFE) {
		return 0.0;
	}
	// Each new ripple rises somewhere else inside its cell.
	vec2 place = vec2(wind_hash(cell + floor(turns) + 3.1), wind_hash(cell + floor(turns) + 8.7));
	float spread = distance(p, (cell + 0.2 + 0.6 * place) * SPACING);
	float radius = age * 0.7;
	float ring = 1.0 - smoothstep(0.0, 0.12, abs(spread - radius));
	float inner = 1.0 - smoothstep(0.0, 0.1, abs(spread - radius * 0.55));
	return (ring + inner * 0.6) * (1.0 - age / LIFE);
}

// Rings travelling outward from a centre, for fountains and small pools.
float pool_rings(vec2 p, vec2 center, float t) {
	float spread = distance(p, center);
	float rings = sin(spread * 7.5 - t * 2.6);
	return smoothstep(0.55, 0.95, rings) * (1.0 - smoothstep(0.2, 3.2, spread) * 0.6);
}
