shader_type spatial;
render_mode cull_disabled;
varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 patch_id = floor(world_position.xz * 0.7);
	float patch = fract(sin(dot(patch_id, vec2(12.9898, 78.233))) * 43758.5453);
	vec2 blade_grid = floor(world_position.xz * vec2(2.4, 3.1));
	float blade_seed = fract(sin(dot(blade_grid, vec2(4.13, 71.7))) * 24634.6);
	float blade = step(0.94, blade_seed) * step(0.32, fract(world_position.z * 0.42 + blade_seed));
	float paper_speckle = fract(sin(dot(floor(world_position.xz * 7.0), vec2(18.1, 3.7))) * 19817.4);
	vec3 meadow = mix(vec3(0.22, 0.42, 0.28), vec3(0.27, 0.47, 0.30), patch);
	meadow += vec3((paper_speckle - 0.5) * 0.026 + blade * 0.035);
	ALBEDO = meadow;
	ROUGHNESS = 0.97;
}
