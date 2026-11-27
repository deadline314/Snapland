shader_type spatial;
render_mode diffuse_burley;
// Painted surface for large coloured faces: a pixel-grain speckle, broad
// mottling and faint courses, all in world space so neighbouring pieces line
// up. It replaces single flat colours on any face big enough to read as a blank
// block (scene-building standards, section 2). Buildings keep their see-through
// cutaway: the occlusion uniforms match coastal_material.gdshader.

uniform vec4 tint : source_color = vec4(1.0);
uniform float surface_roughness : hint_range(0.0, 1.0) = 0.92;
// Merged props carry their colours per vertex (linear); multiply them in.
uniform bool vertex_tint = false;
uniform float occlusion_cutaway_enabled = 0.0;
uniform vec2 occlusion_viewport_size_px = vec2(1280.0, 720.0);
uniform vec2 occlusion_body_center_px = vec2(640.0, 360.0);
uniform float occlusion_body_radius_px = 50.0;
uniform float occlusion_player_view_depth = 0.0;
uniform float occlusion_cutaway_weight = 0.0;
uniform float occlusion_edge_feather_px = 2.5;

// Grain cell edge in metres; close to the pixel density of the world sprites.
const float TEXEL = 0.0625;
const float COURSE_HEIGHT = 0.5;

varying vec3 world_position;
varying vec3 world_normal;

float stable_screen_noise(vec2 pixel) {
	return fract(52.9829189 * fract(dot(floor(pixel), vec2(0.06711056, 0.00583715))));
}

float cell_hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float soft_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 blend = fract(p);
	blend = blend * blend * (3.0 - 2.0 * blend);
	return mix(mix(cell_hash(cell), cell_hash(cell + vec2(1.0, 0.0)), blend.x), mix(cell_hash(cell + vec2(0.0, 1.0)), cell_hash(cell + vec2(1.0, 1.0)), blend.x), blend.y);
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
	vec3 facing = abs(normalize(world_normal));
	bool is_top = facing.y >= facing.x && facing.y >= facing.z;
	vec2 surface;
	if (is_top) {
		surface = world_position.xz;
	} else if (facing.x >= facing.z) {
		surface = world_position.zy;
	} else {
		surface = world_position.xy;
	}
	vec2 cell = floor(surface / TEXEL);
	// Posterised mottling keeps the patches flat-toned like the sprite art.
	float mottle = floor(soft_noise(cell * TEXEL * 1.7 + vec2(7.3, 2.1)) * 4.0) / 3.0;
	float shade = 1.0 + (mottle - 0.5) * 0.085 + (cell_hash(cell) - 0.5) * 0.045;
	if (is_top) {
		// Tops catch more sky and stay a touch lighter and plainer.
		shade += 0.03;
	} else {
		// Walls show faint courses: each band has its own tone and a one-texel seam.
		float course = floor(surface.y / COURSE_HEIGHT);
		shade += (cell_hash(vec2(course, 3.0)) - 0.5) * 0.05;
		float seam = step(fract(surface.y / COURSE_HEIGHT), TEXEL / COURSE_HEIGHT);
		shade -= seam * 0.075;
	}
	ALBEDO = tint.rgb * shade * (vertex_tint ? COLOR.rgb : vec3(1.0));
	ROUGHNESS = surface_roughness;
	SPECULAR = 0.14;
}
