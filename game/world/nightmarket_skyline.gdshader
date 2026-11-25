shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform sampler2D skyline_texture : source_color, filter_nearest, repeat_disable;
uniform vec4 haze : source_color = vec4(0.15, 0.15, 0.27, 1.0);

void fragment() {
	vec3 skyline = texture(skyline_texture, UV).rgb;
	float side_distance = min(UV.x, 1.0 - UV.x);
	float side_fade = smoothstep(0.0, 0.13, side_distance);
	float sky_fade = smoothstep(0.0, 0.19, UV.y);
	float ground_fade = 1.0 - smoothstep(0.63, 1.0, UV.y);
	float coverage = side_fade * sky_fade * ground_fade;
	ALBEDO = mix(haze.rgb, skyline, 0.82 + coverage * 0.18);
	ALPHA = coverage;
}
