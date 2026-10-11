shader_type spatial;
uniform vec4 base_color : source_color = vec4(0.43, 0.29, 0.18, 1.0);
uniform float plank_scale = 1.0;
varying vec3 local_position;

void vertex() {
	local_position = VERTEX;
}

void fragment() {
	vec2 grain = local_position.xz * vec2(1.5, 17.0) * plank_scale;
	float fibers = sin(grain.y + sin(grain.x * 1.7) * 0.42) * 0.035;
	float seam = smoothstep(0.018, 0.0, abs(fract(grain.y * 0.11) - 0.5));
	float printed = 0.94 + fibers - seam * 0.09;
	ALBEDO = base_color.rgb * printed;
	ROUGHNESS = 0.94;
}
