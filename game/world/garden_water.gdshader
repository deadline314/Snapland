shader_type spatial;
render_mode cull_disabled;

uniform bool reduced_motion = false;

void fragment() {
	float phase = reduced_motion ? 0.0 : TIME * 0.34;
	float ripple = sin(UV.x * 104.0 + sin(UV.y * 40.0 - phase) * 0.75 + phase);
	float wakes = sin(UV.y * 48.0 - UV.x * 10.0 - phase * 0.8);
	float sheen = smoothstep(0.72, 0.98, ripple * 0.62 + wakes * 0.38);
	float coast = smoothstep(0.0, 0.19, min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y)));
	ALBEDO = mix(vec3(0.17, 0.32, 0.29), vec3(0.10, 0.25, 0.25), coast);
	ALBEDO += vec3(0.10, 0.18, 0.17) * sheen;
	ROUGHNESS = 0.35;
	SPECULAR = 0.39;
}
