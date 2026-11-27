// Shared island wind.
//
// One gust field in world space drives the lawn and every foliage sprite, so a
// gust visibly travels across the grass and then through the trees. The world
// ambience advances `snapland_wind_time` and reports where the walker is; both
// stand still under reduced motion, which freezes every user of this file.

global uniform float snapland_wind_time;
global uniform vec3 snapland_walker;

const vec2 WIND_DIRECTION = vec2(0.86, 0.51);

float wind_hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float wind_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 blend = fract(p);
	blend = blend * blend * (3.0 - 2.0 * blend);
	float bottom = mix(wind_hash(cell), wind_hash(cell + vec2(1.0, 0.0)), blend.x);
	float top = mix(wind_hash(cell + vec2(0.0, 1.0)), wind_hash(cell + vec2(1.0, 1.0)), blend.x);
	return mix(bottom, top, blend.y);
}

// Gust strength from 0 (calm) to 1 at a world position. A broad drifting field
// decides where it is windy; long streaks across the wind give it visible fronts.
float wind_gust(vec2 world_xz) {
	float along = dot(world_xz, WIND_DIRECTION);
	float across = dot(world_xz, vec2(-WIND_DIRECTION.y, WIND_DIRECTION.x));
	float broad = wind_noise(world_xz * 0.05 - WIND_DIRECTION * snapland_wind_time * 0.18);
	float fronts = wind_noise(vec2(along * 0.16 - snapland_wind_time * 0.62, across * 0.045));
	return smoothstep(0.42, 0.92, broad * 0.55 + fronts * 0.6);
}

// How strongly something at `world_xz` is being brushed by the walker (0..1).
float walker_brush(vec2 world_xz, float reach) {
	return 1.0 - smoothstep(reach * 0.35, reach, distance(world_xz, snapland_walker.xz));
}
