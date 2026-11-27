shader_type spatial;
render_mode cull_back;

#include "res://game/world/wind.gdshaderinc"

varying vec3 world_position;

// World detail is snapped to this grid so the lawn keeps a pixel-art grain.
const float TEXEL = 0.2;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 cell = floor(world_position.xz / TEXEL) * TEXEL;
	// Irregular meadow patches instead of a checkerboard: two noise scales,
	// posterised into a few flat tones.
	float patches = wind_noise(cell * 0.11 + vec2(3.7, 9.1)) * 0.65 + wind_noise(cell * 0.37 + vec2(21.0, 4.0)) * 0.35;
	float tone = floor(patches * 4.0) / 3.0;
	vec3 meadow = mix(vec3(0.098, 0.2, 0.128), vec3(0.142, 0.243, 0.152), clamp(tone, 0.0, 1.0));
	// Dry clover drifts where the two scales disagree.
	float clover = step(0.78, wind_noise(cell * 0.23 + vec2(51.0, 17.0))) * step(0.5, patches);
	meadow = mix(meadow, vec3(0.158, 0.236, 0.128), clover * 0.55);

	// A gust lifts the blades: the lawn brightens in travelling fronts and the
	// scattered blade flecks lean over by a texel.
	float gust = wind_gust(cell);
	vec2 blade_cell = floor((world_position.xz + WIND_DIRECTION * gust * TEXEL * 1.5) * vec2(2.4, 3.1));
	float blade_seed = wind_hash(blade_cell + vec2(4.13, 71.7));
	float blade = step(0.93, blade_seed) * step(0.3, fract(world_position.z * 0.42 + blade_seed));
	float speckle = wind_hash(floor(world_position.xz * 7.0) + vec2(18.1, 3.7));
	meadow += vec3((speckle - 0.5) * 0.012 + blade * 0.02);
	meadow += vec3(0.03, 0.042, 0.012) * gust;

	// Grass presses down in a small ring around the walker.
	float pressed = walker_brush(cell, 0.9);
	meadow *= 1.0 - pressed * 0.1;

	// The lawn receives the key light, so its albedo stays about half of an
	// ambient-only value: sunlit grass keeps the authored meadow tone and cast
	// shadows read as shadows instead of disappearing on grass.
	ALBEDO = meadow;
	ROUGHNESS = 0.97;
}
