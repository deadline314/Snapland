shader_type spatial;
render_mode cull_back;

instance uniform vec4 occluder_tint : source_color = vec4(1.0);
instance uniform float occluder_roughness : hint_range(0.0, 1.0) = 0.92;
instance uniform vec4 occluder_emission : source_color = vec4(0.0);
instance uniform float occluder_emission_energy = 1.0;
instance uniform float occluder_metallic : hint_range(0.0, 1.0) = 0.0;

uniform vec2 viewport_size_px = vec2(1280.0, 720.0);
uniform vec2 body_center_px = vec2(640.0, 360.0);
uniform float body_radius_px : hint_range(0.0, 320.0) = 50.0;
uniform float edge_feather_px : hint_range(0.0, 8.0) = 2.5;
uniform float cutaway_weight : hint_range(0.0, 1.0) = 0.0;
uniform float player_view_depth = 0.0;

float stable_screen_noise(vec2 pixel) {
	// Interleaved gradient noise is deterministic in screen space, so this edge
	// softens spatially without adding temporal flicker or a transparent pass.
	return fract(52.9829189 * fract(dot(floor(pixel), vec2(0.06711056, 0.00583715))));
}

void fragment() {
	vec2 fragment_px = SCREEN_UV * viewport_size_px;
	float radius = body_radius_px * smoothstep(0.0, 1.0, cutaway_weight);
	float fragment_view_depth = -VERTEX.z;
	bool in_front_of_player = fragment_view_depth < player_view_depth - 0.025;
	// Preserve the full architecture shadow silhouette. In the camera pass, use
	// a narrow screen-pixel dither band instead of alpha blending: the building
	// stays in the opaque/depth and shadow-casting paths with source shading.
	if (!IN_SHADOW_PASS && cutaway_weight > 0.0001 && in_front_of_player) {
		float edge_width = max(edge_feather_px, 0.001);
		float distance_px = distance(fragment_px, body_center_px);
		float reveal_coverage = 1.0 - smoothstep(radius - edge_width, radius + edge_width, distance_px);
		if (reveal_coverage > stable_screen_noise(FRAGCOORD.xy)) {
			discard;
		}
	}
	ALBEDO = COLOR.rgb * occluder_tint.rgb;
	ROUGHNESS = occluder_roughness;
	EMISSION = occluder_emission.rgb * occluder_emission_energy;
	METALLIC = occluder_metallic;
}
