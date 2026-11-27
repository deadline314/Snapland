shader_type spatial;
render_mode cull_disabled;

#include "res://game/world/sea_motion.gdshaderinc"

uniform vec4 water_color : source_color = vec4(0.055, 0.34, 0.42, 1.0);
uniform float motion = 1.0;
varying vec3 world_position;
varying vec2 pool_center;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	pool_center = MODEL_MATRIX[3].xz;
}

void fragment() {
	vec2 p = floor(world_position.xz * 5.0) / 5.0;
	float t = TIME * motion;
	float broad = sin(p.x * 0.57 + p.y * 0.18 + t * 0.7) * cos(p.y * 0.66 - t * 0.42);
	// Rings run outward from the middle of each pool, as if fed from its centre.
	float rings = pool_rings(p, pool_center, t);
	float paper_grain = fract(sin(dot(floor(p * 2.0), vec2(12.9898, 78.233))) * 43758.5453);
	float glints = sea_glints(p, t);
	vec3 deep = water_color.rgb * (0.9 + broad * 0.12);
	vec3 ink = vec3(0.045, 0.16, 0.19) * (1.0 - step(0.62, paper_grain)) * 0.10;
	ALBEDO = deep + ink + vec3(rings * 0.07 + glints * 0.12);
	ROUGHNESS = 0.48;
	METALLIC = 0.04;
}
