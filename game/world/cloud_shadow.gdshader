shader_type spatial;
// One full-screen multiply pass drawn after the scene. Each pixel's world
// position is rebuilt from depth, so slow world-space cloud shade crosses the
// ground, props and depth-writing sprites alike without touching their
// materials, and never reaches the UI.
render_mode unshaded, blend_mul, depth_test_disabled, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform sampler2D depth_texture : hint_depth_texture, filter_nearest, repeat_disable;
uniform float strength : hint_range(0.0, 1.0) = 0.0;
uniform vec3 shade_color : source_color = vec3(0.66, 0.74, 0.88);
// Metres travelled, accumulated on the CPU so reduced motion can hold it still.
uniform vec2 drift = vec2(0.0);
uniform float cloud_size = 24.0;
uniform float coverage : hint_range(0.0, 1.0) = 0.5;
uniform float softness : hint_range(0.01, 0.5) = 0.15;
// Horizontal shade offset per metre of height, so tall things are shaded by
// the same cloud as the ground the sun reaches them across.
uniform vec2 sun_slope = vec2(0.0);

// Integer hash: a sin()-based one is not bit-stable between neighbouring
// pixels on every GPU, which tears straight seams into the cloud edges.
float hash(vec2 cell) {
	uvec2 mixed = uvec2(ivec2(cell)) * uvec2(1597334673u, 3812015801u);
	uint bits = (mixed.x ^ mixed.y) * 1597334673u;
	return float(bits) * (1.0 / 4294967295.0);
}

// Gradient noise: value noise leaves lattice-aligned creases once thresholded.
vec2 lattice_gradient(vec2 cell) {
	float angle = hash(cell) * 6.2831853;
	return vec2(cos(angle), sin(angle));
}

float gradient_noise(vec2 point) {
	vec2 cell = floor(point);
	vec2 local = fract(point);
	vec2 blend = local * local * local * (local * (local * 6.0 - 15.0) + 10.0);
	float near_left = dot(lattice_gradient(cell), local);
	float near_right = dot(lattice_gradient(cell + vec2(1.0, 0.0)), local - vec2(1.0, 0.0));
	float far_left = dot(lattice_gradient(cell + vec2(0.0, 1.0)), local - vec2(0.0, 1.0));
	float far_right = dot(lattice_gradient(cell + vec2(1.0, 1.0)), local - vec2(1.0, 1.0));
	return mix(mix(near_left, near_right, blend.x), mix(far_left, far_right, blend.x), blend.y) * 0.7071 + 0.5;
}

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	float depth = texture(depth_texture, SCREEN_UV).r;
	// Reverse-Z NDC through the inverse projection is valid for the orthogonal camera too.
	vec4 view = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	vec3 world = (INV_VIEW_MATRIX * vec4(view.xyz / view.w, 1.0)).xyz;
	vec2 ground = (world.xz - sun_slope * world.y + drift) / cloud_size;
	// The second octave is rotated so the two lattices never line up.
	float field = gradient_noise(ground) * 0.66 + gradient_noise(mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * ground * 2.1 + vec2(17.0, 5.0)) * 0.34;
	float cloud = smoothstep(coverage - softness, coverage + softness, field);
	// Depth 0 is the far plane: nothing was drawn there, so the sky stays clean.
	float drawn = step(0.000001, depth);
	ALBEDO = mix(vec3(1.0), shade_color, cloud * strength * drawn);
}
