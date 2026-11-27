shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
// Self-lit shapes: neon tubes, bulbs, lit windows and paper lanterns. The vertex
// colour (times the instance colour of a batch) is the light colour. An alpha
// below 1 marks a tube that buzzes and gives it its own rhythm; alpha 1 burns
// steadily. A hanging batch swings about each instance's origin. With motion at
// 0 everything holds one still, fully lit pose.

uniform float motion = 1.0;
uniform float energy = 1.0;
// Share of its brightness a buzzing tube may lose.
uniform float flicker = 0.0;
// Radians a hanging instance swings to either side.
uniform float sway = 0.0;

varying vec3 light;

void vertex() {
	float t = TIME * motion;
	if (sway > 0.0) {
		vec3 anchor = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
		float phase = anchor.x * 1.7 + anchor.z * 2.3;
		float angle = (sin(t * 1.5 + phase) + 0.4 * sin(t * 2.6 + phase * 1.9)) * sway;
		VERTEX.xy = mat2(vec2(cos(angle), sin(angle)), vec2(-sin(angle), cos(angle))) * VERTEX.xy;
	}
	float level = 1.0;
	if (COLOR.a < 0.99) {
		float phase = COLOR.a * 61.0;
		float buzz = 0.5 + 0.5 * sin(t * 13.0 + phase);
		// A short dip now and then, like a tired tube.
		float dip = step(0.84, fract(sin(floor(t * 5.0 + phase) * 12.9898) * 43758.5453)) * motion;
		level = 1.0 - flicker * (0.3 * buzz * motion + 0.7 * dip);
	}
	light = COLOR.rgb * energy * level;
}

void fragment() {
	ALBEDO = light;
}
