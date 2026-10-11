shader_type spatial;
render_mode cull_disabled;

instance uniform vec4 occluder_tint : source_color = vec4(1.0);
instance uniform float occluder_roughness : hint_range(0.0, 1.0) = 0.92;

uniform vec2 viewport_size_px = vec2(1280.0, 720.0);
uniform vec2 body_center_px = vec2(640.0, 360.0);
uniform float body_radius_px : hint_range(0.0, 160.0) = 50.0;
uniform float cutaway_weight : hint_range(0.0, 1.0) = 0.0;
uniform float player_view_depth = 0.0;

void fragment() {
	vec2 fragment_px = SCREEN_UV * viewport_size_px;
	float radius = body_radius_px * smoothstep(0.0, 1.0, cutaway_weight);
	float fragment_view_depth = -VERTEX.z;
	bool inside_body_mask = distance(fragment_px, body_center_px) <= radius;
	bool in_front_of_player = fragment_view_depth < player_view_depth - 0.025;
	if (cutaway_weight > 0.0001 && inside_body_mask && in_front_of_player) {
		discard;
	}
	ALBEDO = COLOR.rgb * occluder_tint.rgb;
	ROUGHNESS = occluder_roughness;
}
