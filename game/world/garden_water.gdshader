shader_type spatial;
render_mode cull_disabled;
// Still pond water, or a narrow channel when `channel_flow` is not zero: then
// UV.x runs along the channel in metres and the ripples travel down it.
// `splashes` are rings that spread from where something just dropped in.

uniform bool reduced_motion = false;
uniform float channel_flow = 0.0;
// 1 darkens towards the middle of a rectangular pool; 0 for basins of any shape.
uniform float bank = 1.0;
uniform vec4 deep_color : source_color = vec4(0.10, 0.25, 0.25, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.19, 0.38, 0.33, 1.0);
uniform vec4 sheen_color : source_color = vec4(0.62, 0.80, 0.74, 1.0);
// x, z, age in seconds (negative when unused), unused.
uniform vec4 splashes[4];
varying vec3 world_position;

float cell_seed(vec2 cell) {
	return fract(sin(dot(cell, vec2(37.17, 19.23))) * 4375.0);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float phase = reduced_motion ? 0.0 : TIME;
	vec2 at = floor(world_position.xz * 16.0) / 16.0;
	vec3 water;
	float sheen;
	if (channel_flow != 0.0) {
		float along = floor(UV.x * 16.0) / 16.0 - phase * channel_flow;
		float streak = sin(along * 9.0 + sin(UV.y * 9.0) * 1.3) * 0.6 + sin(along * 23.0 + UV.y * 5.0) * 0.4;
		sheen = smoothstep(0.55, 0.8, streak) * smoothstep(0.0, 0.25, min(UV.y, 1.0 - UV.y));
		water = mix(deep_color.rgb, shallow_color.rgb, 0.7);
	} else {
		float ripple = sin(at.x * 5.2 + sin(at.y * 2.0 - phase * 0.34) * 0.75 + phase * 0.34);
		float wakes = sin(at.y * 4.1 - at.x * 0.9 - phase * 0.27);
		sheen = smoothstep(0.78, 0.98, ripple * 0.62 + wakes * 0.38);
		float coast = mix(0.55, smoothstep(0.0, 0.19, min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y))), bank);
		water = mix(shallow_color.rgb, deep_color.rgb, coast);
		// Dark weed below the surface.
		water *= 0.86 + 0.14 * step(0.45, cell_seed(floor(at * 1.5)));
	}
	for (int index = 0; index < 4; index++) {
		float age = splashes[index].z;
		if (age >= 0.0) {
			float ring = abs(distance(world_position.xz, splashes[index].xy) - age * 0.75);
			sheen += (1.0 - smoothstep(0.02, 0.07, ring)) * (1.0 - smoothstep(0.6, 1.6, age));
		}
	}
	ALBEDO = water + sheen_color.rgb * clamp(sheen, 0.0, 1.0) * 0.55;
	ROUGHNESS = 0.35;
	SPECULAR = 0.39;
}
