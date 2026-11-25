shader_type spatial;
render_mode diffuse_burley, cull_disabled;

uniform vec4 velvet : source_color = vec4(0.37, 0.21, 0.30, 1.0);
uniform vec4 hem : source_color = vec4(0.58, 0.39, 0.29, 1.0);

void fragment() {
	float curve = UV.x + 0.021 * sin(UV.y * 3.14);
	float folds = 0.76 + 0.24 * cos(curve * 43.98);
	float thread = 0.983 + 0.017 * sin(UV.x * 294.0) * sin(UV.y * 222.0);
	float hemline = smoothstep(0.918, 0.927, UV.y) * (1.0 - smoothstep(0.951, 0.96, UV.y));
	float sides = smoothstep(0.018, 0.031, min(UV.x, 1.0 - UV.x));
	ALBEDO = mix(velvet.rgb * folds * thread, hem.rgb * 0.70, hemline * sides);
	ROUGHNESS = 0.91;
	SPECULAR = 0.17;
}
