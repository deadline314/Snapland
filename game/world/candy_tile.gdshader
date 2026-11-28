shader_type spatial;
render_mode diffuse_burley;
// Two-tone pastel surfaces of the candy factory in world space, so neighbouring
// pieces line up: glazed checker tiles, awning stripes and banded towers. Each
// tile gets a grout line, a one-texel bevel and its own slight tone.

uniform vec4 tone_a : source_color = vec4(1.0, 0.93, 0.86, 1.0);
uniform vec4 tone_b : source_color = vec4(0.96, 0.72, 0.78, 1.0);
uniform vec4 grout : source_color = vec4(0.72, 0.52, 0.56, 1.0);
// 0 checker, 1 stripes across the surface, 2 bands up the surface,
// 3 frosted running-bond bricks, 4 basket weave, 5 candy-button tiles.
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
	if (pattern == 3) {
		// Bricks twice as long as deep; every other course shifts half a brick.
		vec2 brick = surface / vec2(tile_size, tile_size * 0.5);
		brick.x += mod(floor(brick.y), 2.0) * 0.5;
		tile = floor(brick);
		inside = fract(brick);
		pick = step(0.7, cell_hash(tile));
		seam = max(step(inside.x, edge * 0.5), step(inside.y, edge));
	} else if (pattern == 4) {
		// Pairs of planks that turn a quarter each block, like a woven basket.
		vec2 block = floor(surface / (tile_size * 2.0));
		vec2 local = fract(surface / (tile_size * 2.0));
		bool across = mod(block.x + block.y, 2.0) < 1.0;
		float half_index = across ? floor(local.y * 2.0) : floor(local.x * 2.0);
		tile = block * 2.0 + vec2(half_index);
		inside = across ? vec2(local.x, fract(local.y * 2.0)) : vec2(fract(local.x * 2.0), local.y);
		pick = 0.35 * step(0.5, cell_hash(tile));
		seam = across ? max(step(inside.y, edge), step(local.x, edge * 0.5)) : max(step(inside.x, edge), step(local.y, edge * 0.5));
	} else if (pattern == 5) {
		// Cream tiles, most with a glossy candy button set into the middle.
		seam = max(step(inside.x, edge), step(inside.y, edge));
		float reach = length(inside - vec2(0.5));
		float button = step(reach, 0.27) * step(0.18, cell_hash(tile + 7.0));
		float shine = step(length(inside - vec2(0.42, 0.42)), 0.08);
		float rim = step(0.22, reach);
		// Shine lifts toward cream; the rim sinks toward the grout.
		pick = button * (1.0 - 0.6 * shine);
		seam = max(seam, button * rim * 0.5);
		inside = mix(inside, vec2(0.5), button);
	} else if (pattern == 1) {
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
	if (pattern >= 3) {
		// Broad, soft wear patches so a large floor never reads as one flat sheet.
		color *= 0.95 + cell_hash(floor(surface / 3.0) + 3.0) * 0.08;
	}
	ALBEDO = mix(color, grout.rgb, seam);
	ROUGHNESS = surface_roughness;
	SPECULAR = 0.3;
}
