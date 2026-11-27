shader_type spatial;
// Built surfaces of the moss-light greenhouse, drawn in world space on a
// sixteenth-of-a-metre grain so neighbouring pieces line up: stone pavers with
// moss in the joints (0), timber boards (1), brick courses on every face (3),
// clipped hedge (4) and rough mossy stone (5). Leaf shade drifts across upward faces.

#include "res://game/world/wind.gdshaderinc"

uniform vec4 finish_tone : source_color = vec4(0.68, 0.70, 0.59, 1.0);
uniform vec2 tile_size = vec2(1.30, 0.84);
uniform int finish_style = 0;
uniform float moss : hint_range(0.0, 1.0) = 0.25;
uniform float leaf_shade : hint_range(0.0, 1.0) = 0.0;
varying vec3 surface_position;
varying vec3 surface_normal;

const float GRAIN = 16.0;
const vec3 MOSS_DARK = vec3(0.21, 0.34, 0.17);
const vec3 MOSS_LIGHT = vec3(0.42, 0.56, 0.24);

void vertex() {
	surface_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	surface_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

float tile_tone(vec2 cell) {
	return fract(sin(dot(cell, vec2(37.17, 19.23))) * 4375.0);
}

// Distance to the nearest joint of a running bond, and the id of its unit.
vec3 bond(vec2 at, vec2 unit) {
	vec2 board = at / unit;
	board.x += mod(floor(board.y), 2.0) * 0.5;
	vec2 face = fract(board);
	vec2 edge = min(face, vec2(1.0) - face) * unit;
	return vec3(min(edge.x, edge.y), floor(board));
}

void fragment() {
	vec3 facing = abs(surface_normal);
	bool top = surface_normal.y > 0.55;
	vec2 walk = surface_position.xz;
	if (!top) {
		walk = facing.x > facing.z ? surface_position.zy : surface_position.xy;
	}
	vec2 grain_cell = floor(walk * GRAIN);
	vec2 at = (grain_cell + 0.5) / GRAIN;
	float speck = tile_tone(grain_cell);
	float patches = wind_noise(at * 0.55 + 7.3);
	vec3 tone = finish_tone.rgb;
	if (finish_style == 4) {
		// Clipped hedge: clustered leaves in three tones, lighter on top.
		float cluster = wind_noise(at * 3.1) * 0.6 + speck * 0.5;
		tone *= cluster > 0.74 ? 1.32 : (cluster > 0.42 ? 1.0 : 0.72);
		tone *= top ? 1.12 : 0.8 + 0.2 * smoothstep(0.1, 0.9, surface_position.y);
	} else if (finish_style == 3) {
		vec3 brick = bond(at, vec2(0.5, 0.1875));
		float course = tile_tone(brick.yz) - 0.5;
		tone *= 1.0 + course * 0.3 + (speck - 0.5) * 0.08;
		tone = mix(vec3(0.62, 0.58, 0.5), tone, step(0.03, brick.x));
		// Damp and moss climb from the ground on walls.
		float damp = top ? 0.0 : 1.0 - smoothstep(0.1, 0.75, surface_position.y + (patches - 0.5) * 0.5);
		tone = mix(tone, mix(MOSS_DARK, MOSS_LIGHT, speck), step(1.0 - damp * moss * 1.8, speck * 0.6 + patches * 0.5));
	} else if (finish_style == 5) {
		// Rough stone: copings, boulders and banks, mossy where they face the sky.
		tone *= 1.0 + (speck - 0.5) * 0.12 + (patches - 0.5) * 0.22;
		float grown = step(1.0 - moss, patches * 0.6 + speck * 0.5) * smoothstep(0.3, 0.7, surface_normal.y);
		tone = mix(tone, mix(MOSS_DARK, MOSS_LIGHT, speck), grown);
		tone *= top ? 1.0 : 0.8;
	} else if (top) {
		vec3 paver = bond(at, tile_size);
		float variation = tile_tone(paver.yz) - 0.5;
		if (finish_style == 1) {
			tone *= 1.0 + variation * 0.2 + sin(at.y * 29.0 + sin(at.x * 1.8) * 0.6) * 0.03 + (speck - 0.5) * 0.06;
			tone *= mix(0.72, 1.0, step(0.04, paver.x));
		} else {
			tone *= 1.0 + variation * 0.17 + (speck - 0.5) * 0.07 + (patches - 0.5) * 0.1;
			// Joints are dark; moss fills them and creeps over the damp patches.
			float joint = 1.0 - smoothstep(0.03, 0.05, paver.x);
			float creep = 1.0 - smoothstep(0.0, 0.05 + 0.34 * moss * patches, paver.x + (speck - 0.5) * 0.07);
			tone = mix(tone, tone * 0.62, joint);
			tone = mix(tone, mix(MOSS_DARK, MOSS_LIGHT, speck * patches * 1.6), creep * step(0.001, moss));
		}
	} else {
		tone *= 0.74 + (speck - 0.5) * 0.06;
	}
	if (top && leaf_shade > 0.0) {
		// Canopy shade: soft blotches that drift with the shared wind.
		vec2 drift = WIND_DIRECTION * snapland_wind_time * 0.05;
		float shade = wind_noise(at * 0.85 + drift) * 0.65 + wind_noise(at * 2.3 - drift * 1.7) * 0.35;
		tone *= 1.0 - leaf_shade * 0.42 * smoothstep(0.42, 0.6, shade);
	}
	ALBEDO = tone;
	ROUGHNESS = 0.9;
	SPECULAR = 0.2;
}
