shader_type spatial;
// Dressed stone and rock for the minigame dioramas. The park paving shader maps
// only the ground plane, so on a wall or a sea stack it smears into stripes;
// this one picks the face it is drawn on and lays staggered courses there: each
// block its own tone, dark joints, a lit upper lip, speckle on a pixel grid,
// and a darker wet band and weed line below `wet_line` (world height).

uniform vec4 base_color : source_color = vec4(0.6, 0.6, 0.56, 1.0);
uniform vec2 block = vec2(0.7, 0.36);
// Rough rock: ragged joints and wider tone swings instead of cut blocks.
uniform float rough = 0.0;
uniform float wet_line = -100.0;
uniform float texels_per_metre = 16.0;

varying vec3 world_position;
varying vec3 world_normal;

float stone_hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 facing = abs(world_normal);
	vec2 surface = facing.y > max(facing.x, facing.z) ? world_position.xz : (facing.x > facing.z ? world_position.zy : world_position.xy);
	surface = floor(surface * texels_per_metre) / texels_per_metre;
	vec2 cell = surface / block;
	cell.x += mod(floor(cell.y), 2.0) * 0.5;
	// Rock: nudge joints by a per-row wobble so courses read as strata.
	cell.x += rough * (stone_hash(vec2(floor(cell.y), 3.0)) - 0.5) * 0.8 + rough * sin(cell.y * 2.3) * 0.2;
	vec2 inside = fract(cell);
	float texel_x = 1.0 / (texels_per_metre * block.x);
	float texel_y = 1.0 / (texels_per_metre * block.y);
	float joint = step(inside.x, texel_x) + step(inside.y, texel_y);
	float lip = step(1.0 - texel_y * 1.5, inside.y);
	float tone = 0.88 + stone_hash(floor(cell)) * (0.18 + rough * 0.16);
	float speckle = stone_hash(floor(surface * texels_per_metre));
	vec3 color = base_color.rgb * tone * (0.96 + speckle * 0.07);
	color *= 1.0 + lip * 0.12;
	color = mix(color, color * 0.55, clamp(joint, 0.0, 1.0));
	if (world_position.y < wet_line) {
		color *= 0.72;
		if (world_position.y > wet_line - 0.14 && speckle > 0.35) {
			color = mix(color, vec3(0.29, 0.42, 0.27), 0.7);
		}
	}
	ALBEDO = color;
	ROUGHNESS = 0.95;
}
