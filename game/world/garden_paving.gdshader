shader_type spatial;

uniform vec4 finish_tone : source_color = vec4(0.68, 0.70, 0.59, 1.0);
uniform vec2 tile_size = vec2(1.30, 0.84);
uniform int finish_style = 0;
varying vec3 surface_position;
varying vec3 surface_normal;

void vertex() {
	surface_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	surface_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

float tile_tone(vec2 cell) {
	return fract(sin(dot(cell, vec2(37.17, 19.23))) * 4375.0);
}

void fragment() {
	vec2 walk = surface_position.xz;
	float broad = sin(walk.x * 0.34 + walk.y * 0.21) * sin(walk.y * 0.31 - walk.x * 0.22);
	float grain = sin(walk.x * 7.1 + sin(walk.y * 5.0) * 0.6) * sin(walk.y * 6.2);
	vec3 pavement = finish_tone.rgb * (1.0 + broad * 0.050 + grain * 0.018);
	if (finish_style == 2) {
		float meadow = 0.5 + 0.5 * sin(walk.x * 0.21 + sin(walk.y * 0.26));
		pavement = mix(pavement, pavement * vec3(0.82, 0.95, 0.87), meadow * 0.61);
	} else if (surface_normal.y > 0.55) {
		vec2 board = walk / tile_size;
		board.x += mod(floor(board.y), 2.0) * 0.5;
		vec2 face = fract(board);
		vec2 edge = min(face, vec2(1.0) - face);
		float width = max(fwidth(board.x), fwidth(board.y));
		float border = smoothstep(0.025 - width, 0.025 + width, min(edge.x, edge.y));
		float variation = tile_tone(floor(board)) - 0.5;
		float seam = finish_style == 1 ? 0.11 : 0.095;
		pavement *= (1.0 + variation * 0.16) * mix(1.0 - seam, 1.0, border);
		if (finish_style == 1) {
			pavement *= 1.0 + sin(walk.y * 29.0 + sin(walk.x * 1.8) * 0.6) * 0.022;
		}
	} else {
		pavement *= 0.79;
	}
	ALBEDO = pavement;
	ROUGHNESS = 0.88;
	SPECULAR = 0.27;
}
