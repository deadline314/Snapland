shader_type spatial;
// Lit, depth-writing pixel critters drawn as one batch. Each instance already
// faces the camera; its custom data picks the atlas cell.
render_mode cull_disabled, depth_draw_opaque;

uniform sampler2D atlas : source_color, filter_nearest, repeat_disable;
uniform vec2 cell_uv = vec2(0.25, 0.25);

void vertex() {
	// INSTANCE_CUSTOM: x = frame column, y = animal row, z > 0.5 mirrors the cell.
	float across = mix(UV.x, 1.0 - UV.x, step(0.5, INSTANCE_CUSTOM.z));
	UV = (INSTANCE_CUSTOM.xy + vec2(across, UV.y)) * cell_uv;
}

void fragment() {
	vec4 texel = texture(atlas, UV);
	ALBEDO = texel.rgb * COLOR.rgb;
	ALPHA = texel.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ROUGHNESS = 0.92;
}
