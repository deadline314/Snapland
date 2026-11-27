shader_type spatial;
render_mode cull_disabled;
// Striped tent canvas: walls, roofs, valances, awnings and runners share one
// mesh. UV.x counts stripes along the cloth, UV.y runs from the pinned edge (0)
// to the hem (1). The vertex colour is the coloured stripe; UV2.x is the number
// of scallops cut into the hem per stripe (0 keeps it straight) and UV2.y how
// far the hem may billow in the wind. With motion at 0 the cloth holds still.

uniform vec4 pale_stripe : source_color = vec4(0.96, 0.90, 0.76, 1.0);
uniform vec4 hem_trim : source_color = vec4(0.91, 0.72, 0.36, 1.0);
uniform float motion = 1.0;

varying vec3 dye;
varying vec2 cut;

void vertex() {
	dye = COLOR.rgb;
	cut = UV2;
	vec3 anchor = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float sway = sin(TIME * motion * 1.7 + anchor.x * 0.9 + anchor.z * 0.7) + 0.5 * sin(TIME * motion * 2.9 + anchor.x * 1.6);
	VERTEX += NORMAL * sway * UV2.y * UV.y;
}

void fragment() {
	float scallop = 0.0;
	if (cut.x > 0.0) {
		float across = fract(UV.x * cut.x) * 2.0 - 1.0;
		// The hem hangs lowest in the middle of each scallop.
		float hem = 0.45 + 0.55 * sqrt(max(0.0, 1.0 - across * across));
		if (UV.y > hem) {
			discard;
		}
		scallop = smoothstep(hem - 0.16, hem - 0.1, UV.y);
	}
	float coloured = step(0.5, fract(UV.x * 0.5));
	vec3 cloth = mix(pale_stripe.rgb, dye, coloured);
	// A soft fold down the middle of every stripe and a coarse weave grain.
	cloth *= 0.86 + 0.14 * cos((fract(UV.x) - 0.5) * 6.2832);
	vec2 weave = floor(vec2(UV.x * 14.0, UV.y * 40.0));
	cloth *= 0.97 + 0.05 * fract(sin(dot(weave, vec2(12.9898, 78.233))) * 43758.5453);
	cloth *= mix(1.0, 0.82, smoothstep(0.75, 1.0, UV.y) * (1.0 - step(0.001, cut.x)));
	ALBEDO = mix(cloth, hem_trim.rgb, scallop);
	ROUGHNESS = 0.92;
}
