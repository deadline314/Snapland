shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
// Soft additive light cone (lighthouse beam, stage spot). The mesh is an uncapped
// cone along local Y with its narrow source end at +Y.

uniform vec4 beam_color : source_color = vec4(1.0, 0.86, 0.56, 1.0);
uniform float intensity = 0.0;
uniform float beam_length = 10.0;

varying float along;

void vertex() {
	along = 0.5 - VERTEX.y / beam_length;
}

void fragment() {
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	ALBEDO = beam_color.rgb;
	ALPHA = intensity * pow(1.0 - clamp(along, 0.0, 1.0), 1.6) * facing * facing;
}
