shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, shadows_disabled;
// The soft disc a stage spot throws on the ground. The mesh is a flat quad
// with UV 0..1.

uniform vec4 pool_color : source_color = vec4(1.0, 0.86, 0.56, 1.0);
uniform float intensity = 0.0;

void fragment() {
	float edge = 1.0 - smoothstep(0.25, 1.0, length(UV - 0.5) * 2.0);
	ALBEDO = pool_color.rgb;
	ALPHA = intensity * edge;
}
