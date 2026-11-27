shader_type spatial;
// Woodland floor around the greenhouse: moss in a few flat tones, a worn earth
// path along `path_points`, leaf litter, and canopy shade that deepens away
// from the clearing and drifts with the shared wind.

#include "res://game/world/wind.gdshaderinc"

uniform vec4 moss_color : source_color = vec4(0.25, 0.39, 0.21, 1.0);
uniform vec4 earth_color : source_color = vec4(0.52, 0.44, 0.31, 1.0);
// Centre and half size of the clearing the building stands in.
uniform vec4 clearing = vec4(0.0, 0.0, 16.0, 15.0);
uniform vec2 path_points[8];
uniform int path_count = 0;
uniform float path_width = 1.3;
uniform float leaf_shade : hint_range(0.0, 1.0) = 0.6;
varying vec3 world_position;

const float GRAIN = 16.0;

float grain_seed(vec2 cell) {
	return fract(sin(dot(cell, vec2(37.17, 19.23))) * 4375.0);
}

float segment_distance(vec2 p, vec2 a, vec2 b) {
	vec2 along = b - a;
	return distance(p, a + along * clamp(dot(p - a, along) / dot(along, along), 0.0, 1.0));
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 cell = floor(world_position.xz * GRAIN);
	vec2 at = (cell + 0.5) / GRAIN;
	float speck = grain_seed(cell);
	float broad = wind_noise(at * 0.16 + 3.1);
	float fine = wind_noise(at * 1.3);
	// Four flat moss tones, picked by two scales of noise plus grain.
	float tone_pick = broad * 0.55 + fine * 0.35 + speck * 0.18;
	vec3 ground = moss_color.rgb * (tone_pick > 0.72 ? 1.3 : (tone_pick > 0.5 ? 1.08 : (tone_pick > 0.32 ? 0.9 : 0.74)));
	// Clover and fallen leaves.
	float clover = step(0.965, grain_seed(floor(cell / 2.0) + 11.0)) * step(0.45, fine);
	ground = mix(ground, moss_color.rgb * vec3(1.5, 1.45, 0.9), clover);
	float litter = step(0.985, grain_seed(floor(cell / 2.0) + 47.0));
	ground = mix(ground, vec3(0.62, 0.47, 0.22), litter * (0.35 + 0.65 * broad));
	float path = 10.0;
	for (int index = 0; index + 1 < path_count; index++) {
		path = min(path, segment_distance(at, path_points[index], path_points[index + 1]));
	}
	float worn = 1.0 - smoothstep(path_width * 0.55, path_width, path + (fine - 0.5) * 0.7);
	vec3 earth = earth_color.rgb * (0.9 + speck * 0.14 + (fine - 0.5) * 0.16);
	earth = mix(earth, earth * 0.72, step(0.93, grain_seed(floor(cell / 3.0) + 5.0)));
	ground = mix(ground, earth, worn);
	// Under the trees the floor is darker and bluer than in the clearing.
	vec2 outside = max(abs(at - clearing.xy) - clearing.zw, vec2(0.0));
	float woods = smoothstep(0.0, 9.0, length(outside) + (broad - 0.5) * 6.0);
	ground = mix(ground, ground * vec3(0.42, 0.58, 0.58), woods * 0.9);
	vec2 drift = WIND_DIRECTION * snapland_wind_time * 0.05;
	float shade = wind_noise(at * 0.7 + drift) * 0.65 + wind_noise(at * 2.1 - drift * 1.7) * 0.35;
	ground *= 1.0 - leaf_shade * 0.45 * smoothstep(0.4, 0.58, shade) * (0.7 + 0.3 * woods);
	ALBEDO = ground;
	ROUGHNESS = 0.96;
	SPECULAR = 0.1;
}
