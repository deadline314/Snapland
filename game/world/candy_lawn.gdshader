shader_type spatial;
render_mode cull_back;
// Candy factory lawn: the island meadow drifting toward pink. Broad clover-pink
// patches and sugar-sprinkle flecks sit on the same pixel grid, gusts and walker
// brush as the Welcome lawn, so the districts can later share one ground.

#include "res://game/world/wind.gdshaderinc"

uniform vec4 meadow_dark : source_color = vec4(0.40, 0.66, 0.50, 1.0);
uniform vec4 meadow_light : source_color = vec4(0.53, 0.76, 0.56, 1.0);
uniform vec4 blush : source_color = vec4(0.95, 0.64, 0.75, 1.0);

varying vec3 world_position;

const float TEXEL = 0.2;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 cell = floor(world_position.xz / TEXEL) * TEXEL;
	float patches = wind_noise(cell * 0.11 + vec2(3.7, 9.1)) * 0.65 + wind_noise(cell * 0.37 + vec2(21.0, 4.0)) * 0.35;
	float tone = floor(patches * 4.0) / 3.0;
	vec3 meadow = mix(meadow_dark.rgb, meadow_light.rgb, clamp(tone, 0.0, 1.0));
	// Pink clover spreads in irregular drifts, posterised into two flat steps.
	float drift = wind_noise(cell * 0.14 + vec2(40.0, 12.0)) * 0.65 + wind_noise(cell * 0.45 + vec2(9.0, 63.0)) * 0.35;
	float pink = floor(smoothstep(0.5, 0.74, drift) * 2.0 + 0.5) / 2.0;
	meadow = mix(meadow, blush.rgb * (0.92 + tone * 0.12), pink * 0.82);

	float gust = wind_gust(cell);
	vec2 blade_cell = floor((world_position.xz + WIND_DIRECTION * gust * TEXEL * 1.5) * vec2(2.4, 3.1));
	float blade_seed = wind_hash(blade_cell + vec2(4.13, 71.7));
	float blade = step(0.93, blade_seed) * step(0.3, fract(world_position.z * 0.42 + blade_seed));
	meadow *= 1.0 + blade * 0.09 + gust * 0.12;

	// Sugar sprinkles: sparse single-texel flecks in sweet-shop colours.
	vec2 fleck_cell = floor(world_position.xz / (TEXEL * 0.5));
	float fleck = wind_hash(fleck_cell + vec2(77.0, 5.0));
	if (fleck > 0.988) {
		float pick = fract(fleck * 91.7);
		vec3 sprinkle = pick < 0.34 ? vec3(1.0, 0.95, 0.86) : (pick < 0.67 ? vec3(1.0, 0.82, 0.42) : vec3(0.62, 0.86, 0.95));
		meadow = mix(meadow, sprinkle, 0.8);
	}

	float pressed = walker_brush(cell, 0.9);
	meadow *= 1.0 - pressed * 0.1;
	// Sunlit albedo stays near half of the authored tone, like the Welcome lawn.
	ALBEDO = meadow * 0.5;
	ROUGHNESS = 0.97;
}
