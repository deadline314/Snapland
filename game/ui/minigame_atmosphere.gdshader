shader_type canvas_item;
// Shared air over every minigame scene: drifting light shafts, a soft vignette
// and an edge glow for score / mistake feedback. `clock` is advanced by the
// owner so pausing or reduced motion freezes the picture.

uniform vec4 shaft_color : source_color = vec4(1.0, 0.95, 0.8, 1.0);
uniform float shaft_strength : hint_range(0.0, 0.3) = 0.07;
uniform float vignette_strength : hint_range(0.0, 0.6) = 0.24;
uniform vec4 flash_color : source_color = vec4(1.0, 0.82, 0.4, 1.0);
uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;
uniform float clock = 0.0;
uniform float aspect = 1.7778;

const vec3 VIGNETTE_INK = vec3(0.02, 0.05, 0.09);

float hash(float n) {
	return fract(sin(n) * 43758.5453);
}

float soft_noise(float x) {
	float cell = floor(x);
	float blend = fract(x);
	blend = blend * blend * (3.0 - 2.0 * blend);
	return mix(hash(cell), hash(cell + 1.0), blend);
}

void fragment() {
	// Shafts are bands along one diagonal; two noise octaves sliding in
	// opposite directions keep them from reading as a moving stripe pattern.
	float band = UV.x * 1.35 + UV.y * 0.55;
	float shafts = soft_noise(band * 5.0 + clock * 0.05) * soft_noise(band * 11.0 - clock * 0.08);
	shafts = smoothstep(0.3, 0.8, shafts) * (1.0 - UV.y * 0.85);

	vec2 centered = (UV - vec2(0.5)) * vec2(aspect, 1.0);
	float distance_out = length(centered);
	float vignette = smoothstep(0.45, 1.05, distance_out) * vignette_strength * (1.0 + 0.06 * sin(clock * 0.6));
	// Hug the frame so the glow never washes over the play area.
	float flash = smoothstep(0.72, 1.12, distance_out) * flash_amount * flash_color.a;
	float shaft_alpha = shafts * shaft_strength;

	vec3 color = VIGNETTE_INK;
	float alpha = vignette;
	color = mix(color, shaft_color.rgb, shaft_alpha / max(alpha + shaft_alpha, 0.0001));
	alpha += shaft_alpha * (1.0 - alpha);
	color = mix(color, flash_color.rgb, flash / max(alpha + flash, 0.0001));
	alpha += flash * (1.0 - alpha);
	COLOR = vec4(color, alpha);
}
