shader_type spatial;
render_mode diffuse_burley;
uniform sampler2D atlas_texture : source_color, filter_nearest;
uniform int tile_index = 0;
uniform float world_tile_size = 2.0;
uniform vec4 tint : source_color = vec4(1.0);
// These per-instance controls are only enabled by OcclusionController for a
// registered building piece. Shared coastal floors keep their default value 0.
instance uniform float occlusion_cutaway_enabled = 0.0;
instance uniform vec2 occlusion_viewport_size_px = vec2(1280.0, 720.0);
instance uniform vec2 occlusion_body_center_px = vec2(640.0, 360.0);
instance uniform float occlusion_body_radius_px = 50.0;
instance uniform float occlusion_player_view_depth = 0.0;
instance uniform float occlusion_cutaway_weight = 0.0;
instance uniform float occlusion_edge_feather_px = 2.5;

varying vec3 world_position;
varying vec3 world_normal;

float stable_screen_noise(vec2 pixel) {
	return fract(52.9829189 * fract(dot(floor(pixel), vec2(0.06711056, 0.00583715))));
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float fragment_view_depth = -VERTEX.z;
	bool in_front_of_player = fragment_view_depth < occlusion_player_view_depth - 0.025;
	if (!IN_SHADOW_PASS && occlusion_cutaway_enabled > 0.5 && occlusion_cutaway_weight > 0.0001 && in_front_of_player) {
		float radius = occlusion_body_radius_px * smoothstep(0.0, 1.0, occlusion_cutaway_weight);
		float edge_width = max(occlusion_edge_feather_px, 0.001);
		vec2 fragment_px = SCREEN_UV * occlusion_viewport_size_px;
		float distance_px = distance(fragment_px, occlusion_body_center_px);
		float reveal_coverage = 1.0 - smoothstep(radius - edge_width, radius + edge_width, distance_px);
		if (reveal_coverage > stable_screen_noise(FRAGCOORD.xy)) {
			discard;
		}
	}
	vec3 n = abs(normalize(world_normal));
	vec2 material_position;
	if (n.y >= n.x && n.y >= n.z) {
		material_position = world_position.xz;
	} else if (n.x >= n.z) {
		material_position = world_position.zy;
	} else {
		material_position = world_position.xy;
	}
	vec2 tile_uv = fract(material_position / max(world_tile_size, 0.01));
	vec2 cell_size = vec2(0.25, 0.5);
	vec2 cell_origin = vec2(float(tile_index % 4) * cell_size.x, float(tile_index / 4) * cell_size.y);
	// The source atlas is 1774x887 (cells are 443.5px square). Leave a two-pixel
	// inset inside each cell so nearest sampling cannot bleed a neighboring tile.
	vec2 inset = vec2(2.0 / (1774.0 * cell_size.x), 2.0 / (887.0 * cell_size.y));
	vec2 safe_uv = inset + tile_uv * (vec2(1.0) - 2.0 * inset);
	ALBEDO = texture(atlas_texture, cell_origin + safe_uv * cell_size).rgb * tint.rgb;
	ROUGHNESS = 0.86;
	SPECULAR = 0.14;
}
