shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

uniform float lamp_x = -1.2;

void fragment() {
	// Paper stays legible across both lamps and all world time phases.
	vec2 at = UV - vec2(0.5, 0.46);
	at.x -= lamp_x * 0.095;
	float lantern = 1.0 - smoothstep(0.10, 0.59, length(at * vec2(1.0, 1.12)));
	float weave = 0.989 + 0.011 * sin(UV.x * 208.0) * sin(UV.y * 147.0);
	vec3 edge = vec3(0.57, 0.36, 0.32);
	vec3 center = vec3(1.0, 0.79, 0.50);
	ALBEDO = mix(edge, center, lantern) * weave;
}
