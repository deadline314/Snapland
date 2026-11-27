shader_type spatial;
// Planked timber for the minigame dioramas. The park wood shader is tuned for
// long decks under a distant camera and reads as one flat colour on a prop a
// metre wide, so this one draws boards at prop scale: each board has its own
// tone, a dark seam, butt joints and short grain strokes on a pixel grid.
// Boards follow the object, so rafts and decks keep their planks when they turn.

uniform vec4 base_color : source_color = vec4(0.62, 0.46, 0.3, 1.0);
uniform float plank_width = 0.22;
// Boards run along local X; set to run them along local Z instead.
uniform bool across = false;
uniform float texels_per_metre = 16.0;

varying vec3 object_position;
varying vec3 object_normal;

float board_hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void vertex() {
	// Scale-aware, so unit meshes stretched by their node still get even boards.
	vec3 stretch = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	object_position = VERTEX * stretch;
	object_normal = NORMAL;
}

void fragment() {
	vec3 facing = abs(object_normal);
	vec2 surface;
	if (facing.y >= facing.x && facing.y >= facing.z) {
		surface = across ? object_position.zx : object_position.xz;
	} else if (facing.x >= facing.z) {
		surface = object_position.zy;
	} else {
		surface = object_position.xy;
	}
	vec2 texel = floor(surface * texels_per_metre);
	float board = floor(surface.y / plank_width);
	float tone = 0.9 + board_hash(vec2(board, 5.0)) * 0.2;
	float texel_width = 1.0 / texels_per_metre;
	float seam = step(fract(surface.y / plank_width) * plank_width, texel_width);
	// Butt joints: each board is cut at its own interval along its length.
	float joint_span = 1.1 + board_hash(vec2(board, 9.0)) * 0.9;
	float joint = step(fract(surface.x / joint_span + board_hash(vec2(board, 2.0))) * joint_span, texel_width);
	float stroke = step(0.82, board_hash(vec2(floor(texel.x / 4.0), texel.y + board * 7.0)));
	float shade = tone - stroke * 0.07 - max(seam, joint) * 0.3;
	ALBEDO = base_color.rgb * shade;
	ROUGHNESS = 0.92;
	SPECULAR = 0.12;
}
