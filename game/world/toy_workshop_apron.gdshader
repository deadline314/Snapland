shader_type spatial;
render_mode unshaded, shadows_disabled, fog_disabled;

uniform vec4 near_tone : source_color = vec4(0.25, 0.30, 0.31, 1.0);
uniform vec4 far_tone : source_color = vec4(0.15, 0.19, 0.23, 1.0);

void fragment() {
	vec2 position_m = (UV - vec2(0.5)) * 84.0;
	vec2 apron = max(abs(position_m) - vec2(12.8, 10.4), vec2(0.0));
	float distance_to_yard = length(apron);
	float grade = smoothstep(0.5, 19.0, distance_to_yard);
	vec2 panel_size = vec2(5.4, 6.4);
	vec2 panel = abs(fract((position_m + vec2(1.4, 2.2)) / panel_size + vec2(0.5)) - vec2(0.5)) * panel_size;
	float edge = min(panel.x, panel.y);
	float seam = 1.0 - smoothstep(0.018, 0.085 + fwidth(edge), edge);
	ALBEDO = mix(near_tone.rgb, far_tone.rgb, grade) * (1.0 - seam * 0.095 * (1.0 - grade));
}
