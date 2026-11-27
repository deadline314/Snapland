shader_type spatial;
// A rain puddle lying on the ground (island events, the afternoon shower).
// A wobbly-edged pool of dark, glossy water; while it rains small rings open
// where drops land, and a bigger ring runs out when the walker splashes it.
// The script owns the clock, so a paused or reduced-motion shower holds still.
render_mode blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform float clock = 0.0;
// 0 dry (no drops landing) .. 1 heavy rain.
uniform float rain : hint_range(0.0, 1.0) = 1.0;
uniform vec4 water : source_color = vec4(0.16, 0.22, 0.30, 0.82);
uniform vec4 shine : source_color = vec4(0.80, 0.88, 0.97, 1.0);
// Seconds since the walker last splashed this puddle (large when never).
instance uniform float splash_age = 9.0;
instance uniform float seed = 0.0;
// 0..1: the pool grows in as the rain starts and shrinks as it dries.
instance uniform float fill = 1.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float angle = atan(p.y, p.x);
	float r = length(p);
	float edge = (0.80 + 0.10 * sin(angle * 3.0 + seed * 6.3) + 0.06 * sin(angle * 5.0 + seed * 11.0)) * fill;
	float body = 1.0 - smoothstep(edge - 0.07, edge, r);
	if (body <= 0.002) discard;
	float rings = 0.0;
	for (int i = 0; i < 4; i++) {
		float lane = float(i) * 0.29 + seed;
		float cycle = clock * 1.3 + lane;
		float t = fract(cycle);
		float cell = floor(cycle);
		vec2 drop = (vec2(hash(vec2(cell, lane)), hash(vec2(lane, cell + 3.7))) - 0.5) * edge * 1.2;
		float d = length(p - drop);
		rings += (1.0 - smoothstep(0.0, 0.045, abs(d - t * 0.42))) * (1.0 - t);
	}
	rings *= rain;
	float splash = 0.0;
	if (splash_age < 1.1) {
		float age = splash_age / 1.1;
		splash = (1.0 - smoothstep(0.0, 0.07, abs(r - age * 1.05))) * (1.0 - age);
	}
	float rim = smoothstep(edge - 0.28, edge - 0.04, r) * 0.35;
	float lift = clamp(rim + rings * 0.9 + splash, 0.0, 1.0);
	ALBEDO = mix(water.rgb, shine.rgb, lift);
	ROUGHNESS = 0.06;
	SPECULAR = 0.7;
	EMISSION = shine.rgb * (rings * 0.12 + splash * 0.25);
	ALPHA = body * mix(water.a, 1.0, lift * 0.6);
}
