shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never, shadows_disabled;
// A slanted shaft of light with dust drifting in it. UV.y runs from the source
// (0) to the foot (1); `foot_shift` slides the foot sideways so one mesh can
// follow a moving light patch. With motion at 0 the dust holds still.

uniform vec4 shaft_color : source_color = vec4(1.0, 0.86, 0.52, 1.0);
uniform float intensity = 0.3;
uniform float foot_shift = 0.0;
uniform float bars = 0.0;
uniform float motion = 1.0;

float mote_seed(vec2 cell) {
	return fract(sin(dot(cell, vec2(37.17, 19.23))) * 4375.0);
}

void vertex() {
	VERTEX.x += foot_shift * UV.y;
}

void fragment() {
	float across = 1.0 - abs(UV.x - 0.5) * 2.0;
	float body = smoothstep(0.0, 0.35, across) * (1.0 - 0.55 * UV.y) * smoothstep(0.0, 0.3, UV.y);
	if (bars > 0.0) {
		body *= 0.45 + 0.55 * step(0.42, fract(UV.x * bars));
	}
	// Dust: sparse bright grains that sink slowly and twinkle.
	vec2 drift = vec2(UV.x * 26.0, UV.y * 34.0 - TIME * motion * 0.35);
	vec2 cell = floor(drift);
	float mote = step(0.955, mote_seed(cell)) * step(length(fract(drift) - 0.5), 0.33);
	mote *= 0.5 + 0.5 * sin(TIME * motion * 2.0 + mote_seed(cell + 3.0) * 6.28);
	ALBEDO = shaft_color.rgb;
	ALPHA = intensity * (body * 0.55 + mote * smoothstep(0.1, 0.5, across) * 1.6);
}
