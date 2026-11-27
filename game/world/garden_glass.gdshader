shader_type spatial;
render_mode cull_disabled, unshaded;
// Greenhouse glazing. `clarity` 0 paints a pane that hides what is behind it
// (the back wall); towards 1 only the sky streaks and the sill haze remain, so
// roof and side panes catch the light without hiding the garden.

uniform vec4 glass_light : source_color = vec4(0.68, 0.82, 0.76, 1.0);
uniform vec4 glass_dark : source_color = vec4(0.31, 0.48, 0.43, 1.0);
uniform float clarity : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	float far_greenery = 0.5 + 0.5 * sin(UV.x * 28.0 + sin(UV.x * 61.0) * 1.25);
	float sill_haze = smoothstep(0.43, 0.98, UV.y + 0.13 * far_greenery);
	float diagonal = UV.x * 0.81 - UV.y;
	float reflection = smoothstep(-0.30, -0.26, diagonal) * (1.0 - smoothstep(-0.04, 0.05, diagonal));
	reflection += 0.6 * smoothstep(0.34, 0.37, diagonal) * (1.0 - smoothstep(0.44, 0.47, diagonal));
	float bevel = smoothstep(0.005, 0.033, min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y)));
	ALBEDO = mix(glass_light.rgb, glass_dark.rgb, sill_haze * 0.83) * (0.79 + 0.21 * bevel);
	ALBEDO += vec3(0.10, 0.14, 0.13) * reflection;
	ALPHA = mix(1.0, 0.02 + 0.16 * reflection + 0.03 * sill_haze + 0.1 * (1.0 - bevel), clarity);
}
