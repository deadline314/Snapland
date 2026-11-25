shader_type spatial;
render_mode cull_disabled, unshaded;

uniform vec4 glass_light : source_color = vec4(0.68, 0.82, 0.76, 1.0);
uniform vec4 glass_dark : source_color = vec4(0.31, 0.48, 0.43, 1.0);

void fragment() {
	float far_greenery = 0.5 + 0.5 * sin(UV.x * 28.0 + sin(UV.x * 61.0) * 1.25);
	float sill_haze = smoothstep(0.43, 0.98, UV.y + 0.13 * far_greenery);
	float diagonal = UV.x * 0.81 - UV.y;
	float reflection = smoothstep(-0.30, -0.26, diagonal) * (1.0 - smoothstep(-0.04, 0.05, diagonal));
	float bevel = smoothstep(0.005, 0.033, min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y)));
	ALBEDO = mix(glass_light.rgb, glass_dark.rgb, sill_haze * 0.83) * (0.79 + 0.21 * bevel);
	ALBEDO += vec3(0.10, 0.14, 0.13) * reflection;
}
