shader_type spatial;
render_mode cull_disabled;
// Flags, pennants and drying nets. UV2.x says how free each vertex is (0 pinned,
// 1 loose end); the instance colour tints the cloth. With motion at 0 the cloth
// holds one still pose.

uniform float motion = 1.0;
uniform float strength = 0.16;
uniform float net_cells = 0.0;

varying vec3 tint;

void vertex() {
	vec3 anchor = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float phase = anchor.x * 1.9 + anchor.z * 2.7 + anchor.y;
	float t = TIME * motion;
	float wave = sin(t * 3.4 + phase + UV.x * 4.0) + 0.45 * sin(t * 5.3 + phase * 1.7 + UV.x * 7.0);
	VERTEX += NORMAL * wave * UV2.x * strength;
	tint = COLOR.rgb;
}

void fragment() {
	if (net_cells > 0.0) {
		vec2 strand = fract(UV * net_cells);
		if (min(strand.x, strand.y) > 0.24) {
			discard;
		}
	}
	ALBEDO = tint;
	ROUGHNESS = 0.9;
}
