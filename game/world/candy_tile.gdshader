shader_type spatial;
render_mode diffuse_burley;
// Two-tone pastel surfaces of the candy factory in world space, so neighbouring
// pieces line up: glazed checker tiles, awning stripes and banded towers. Each
// tile gets a grout line, a one-texel bevel and its own slight tone.

uniform vec4 tone_a : source_color = vec4(1.0, 0.93, 0.86, 1.0);
uniform vec4 tone_b : source_color = vec4(0.96, 0.72, 0.78, 1.0);
uniform vec4 grout : source_color = vec4(0.72, 0.52, 0.56, 1.0);
// 0 checker, 1 stripes across the surface, 2 bands up the surface.
uniform int pattern = 0;
uniform float tile_size = 1.0;
uniform float surface_roughness : hint_range(0.0, 1.0) = 0.55;

const float TEXEL = 0.0625;

varying vec3 world_position;
varying vec3 world_normal;

float cell_hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 facing = abs(normalize(world_normal));
	vec2 surface;
	// Sloped roofs and awnings count as tops, so their pattern follows the ground plan.
	if (facing.y >= 0.5) {
		surface = world_position.xz;
	} else if (facing.x >= facing.z) {
		surface = world_position.zy;
	} else {
		surface = world_position.xy;
	}
	surface = floor(surface / TEXEL) * TEXEL + TEXEL * 0.5;
	vec2 tile = floor(surface / tile_size);
	vec2 inside = fract(surface / tile_size);
	float pick;
	float seam;
	float edge = TEXEL / tile_size;
	if (pattern == 1) {
		pick = mod(tile.x, 2.0);
		seam = 0.0;
		inside.y = 0.5;
	} else if (pattern == 2) {
		pick = mod(tile.y, 2.0);
		seam = 0.0;
		inside.x = 0.5;
	} else {
		pick = mod(tile.x + tile.y, 2.0);
		seam = max(step(inside.x, edge), step(inside.y, edge));
	}
	vec3 color = mix(tone_a.rgb, tone_b.rgb, pick);
	color *= 0.97 + cell_hash(tile) * 0.06;
	// Glazed bevel: light along two edges, shade along the opposite two.
	float lit = max(step(inside.x, edge * 2.0), step(inside.y, edge * 2.0));
	float shaded = max(step(1.0 - edge, inside.x), step(1.0 - edge, inside.y));
	color *= 1.0 + lit * 0.05 - shaded * 0.07;
	color *= 0.985 + cell_hash(surface * 31.0) * 0.03;
	ALBEDO = mix(color, grout.rgb, seam);
	ROUGHNESS = surface_roughness;
	SPECULAR = 0.3;
}
